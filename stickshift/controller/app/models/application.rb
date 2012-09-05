require 'matrix'
class Matrix
  def []=(i, j, x)
    @rows[i][j] = x
  end
end

# Class to represent an OpenShift Application
# @!attribute [r] name
#   @return [String] The name of the application
# @!attribute [rw] domain_requires
#   @return [Array[String]] Array of IDs of the applications that this application is dependenct on. 
#     If the parent application is destroyed, this application also needs to be destroyed.
# @!attribute [rw] group_overrides
#   @return [Array[Array[String]]] Array of Array of components that need to be co-located
# @!attribute [r] domain
#   @return [Domain] Domain that this application is part of.
# @!attribute [r] user_ids
#   @return [Array[Moped::BSON::ObjectId]] Array of IDs of users that have access to this application.
# @!attribute [r] aliases
#   @return [Array[String]] Array of DNS aliases registered with this application.
#     @see {Application#add_alias} and {Application#remove_alias}
# @!attribute [rw] component_start_order
#   @return [Array[String]] Normally start order computed based on order specified by each component's manufest. This attribute is used to overrides the start order.
# @!attribute [rw] component_stop_order
#   @return [Array[String]] Normally stop order computed based on order specified by each component's manufest. This attribute is used to overrides the stop order.
# @!attribute [r] connections
#   @return [Array[ConnectionInstance]] Array of connections between components of this application
# @!attribute [r] component_instances
#   @return [Array[ComponentInstance]] Array of components in this application
# @!attribute [r] group_instances
#   @return [Array[GroupInstance]] Array of gear groups in the application
# @!attribute [r] app_ssh_keys
#   @return [Array[ApplicationSshKey]] Array of auto-generated SSH keys used by components of the application to connect to other gears.
# @!attribute [r] usage_records
#   @return [Array[UsageRecord]] Array of usage records used to storage gear and filesystem usage for the application.
class Application
  include Mongoid::Document
  include Mongoid::Timestamps
  APP_NAME_MAX_LENGTH = 32
  MAX_SCALE = -1

  field :name, type: String
  field :domain_requires, type: Array, default: []
  field :group_overrides, type: Array, default: []
  embeds_many :pending_op_groups, class_name: PendingAppOpGroup.name
  
  belongs_to :domain
  field :user_ids, type: Array, default: []
  field :aliases, type: Array, default: []
  field :component_start_order, type: Array, default: []
  field :component_stop_order, type: Array, default: []
  field :component_configure_order, type: Array, default: []
  embeds_many :connections, class_name: ConnectionInstance.name
  embeds_many :component_instances, class_name: ComponentInstance.name
  embeds_many :group_instances, class_name: GroupInstance.name
  embeds_many :app_ssh_keys, class_name: ApplicationSshKey.name
  embeds_many :usage_records, class_name: UsageRecord.name  
  
  validates :name,
    presence: {message: "Application name is required and cannot be blank."},
    format:   {with: /\A[A-Za-z0-9]+\z/, message: "Invalid application name. Name must only contain alphanumeric characters."},
    length:   {maximum: APP_NAME_MAX_LENGTH, minimum: 1, message: "Application name must be a minimum of 1 and maximum of #{APP_NAME_MAX_LENGTH} characters."},
    blacklisted: {message: "Application name is not allowed.  Please choose another."}
  validate :extended_validator

  # Returns a map of field to error code for validation failures.
  def self.validation_map
    {name: 105}
  end
  
  before_destroy do |app|
    raise "Please call destroy_app to delete all gears before deleting this application" if num_gears > 0
  end
  
  # Observer hook for extending the validation of the application in an ActiveRecord::Observer
  # @see http://api.rubyonrails.org/classes/ActiveRecord/Observer.html
  def extended_validator
    notify_observers(:validate_application)
  end
    
  # Initializes the application
  #
  # == Parameters:
  # features::
  #   List of runtime feature requirements. Each entry in the list can be a cartridge name or a feature supported by one of the profiles within the cartridge.
  #
  # domain::
  #   The Domain that this application is part of.
  #
  # name::
  #   The name of this application.
  def initialize(attrs = nil, options = nil)
    features = attrs[:features] unless (attrs.nil? or attrs[:features].nil?)
    attrs.delete(:features)
    super
    self.app_ssh_keys = []    
    self.usage_records = []
    self.pending_op_groups = []
    self.save
    begin 
      add_components(features)
    rescue Exception => e
      self.delete
      raise e
    end
  end
  
  # Adds an additional namespace to the application. This function supports the first step of the update namespace workflow.
  #
  # == Parameters:
  # new_namespace::
  #   The new namespace to add to the application
  #
  # parent_op::
  #   The pending domain operation that this update is part of.
  #
  # == Returns:
  # {PendingAppOps} object which tracks the progess of the operation.  
  def update_namespace(new_namespace, parent_op=nil)
    op_group = PendingAppOpGroup.new(op_name: :add_namespace, args: {"new_namespace" => new_namespace}, parent_op: parent_op)
    self.pending_op_groups.push op_group
    op_group
  end
  
  # Removes an existing namespace to the application. This function supports the second step of the update namespace workflow.
  #
  # == Parameters:
  # old_namespace::
  #   The old namespace to remove from the application
  #
  # parent_op::
  #   The pending domain operation that this update is part of.
  #
  # == Returns:
  # {PendingAppOps} object which tracks the progess of the operation.  
  def remove_namespace(old_namespace, parent_op=nil)
    op_group = PendingAppOpGroup.new(op_name: :remove_namespace, args: {"old_namespace" => old_namespace}, parent_op: parent_op)
    self.pending_op_groups.push op_group
    op_group
  end

  # Adds the given ssh key to the application.
  #
  # == Parameters:
  # user_id::
  #   The ID of the user assoicated with the keys. If the user ID is nil, then the key is assumed to be a system generated key.
  # keys::
  #   Array of keys to add to the application.
  # parent_op::
  #   {PendingDomainOps} object used to track this operation at a domain level.
  #
  # == Returns:
  # {PendingAppOps} object which tracks the progess of the operation.  
  def add_ssh_keys(user_id, keys, parent_op)
    return if keys.empty?
    key_attrs = keys.map { |k|
      if user_id.nil?
        k["name"] = "domain-" + k["name"]
      else
        k["name"] = user_id.to_s + "-" + k["name"]
      end
      k
    }
    op_group = PendingAppOpGroup.new(op_name: :update_configuration,  args: {"add_keys_attrs" => key_attrs}, parent_op: parent_op)
    self.pending_op_groups.push op_group
    return pending_op
  end
  
  # Updates the given ssh key on the application. It uses the user+key name to identify the key to update.
  #
  # == Parameters:
  # user_id::
  #   The ID of the user assoicated with the keys. Update to system keys is not supported.
  # keys_attrs::
  #   Array of keys attributes to update on the application. The name of the key is used to match existing keys.
  # parent_op::
  #   {PendingDomainOps} object used to track this operation at a domain level.
  #
  # == Returns:
  # {PendingAppOps} object which tracks the progess of the operation.
  def update_ssh_keys(user_id, keys_attrs, parent_op=nil)
    return if keys_attrs.empty?    
    keys_attrs = keys_attrs.map { |k|
      k["name"] = user_id.to_s + "-" + k["name"]
      k
    }
    op_group = PendingAppOpGroup.new(op_name: :update_ssh_keys, args: {"keys" => keys_attrs}, parent_op: parent_op)
    self.pending_op_groups.push op_group
    op_group
  end
  
  # Removes the given ssh key from the application. If multiple users share the same key, only the specified users key is removed
  # but application access will still be possible.
  #
  # == Parameters:
  # user_id::
  #   The ID of the user assoicated with the keys. Update to system keys is not supported.
  # keys_attrs::
  #   Array of keys attributes to remove from the application. The name of the key is used to match existing keys.
  # parent_op::
  #   {PendingDomainOps} object used to track this operation at a domain level.
  #
  # == Returns:
  # {PendingAppOps} object which tracks the progess of the operation.
  def remove_ssh_keys(user_id, keys_attrs, parent_op=nil)
    return if keys.empty?    
    key_attrs = keys_attrs.map { |k|
      if user.nil?
        k["name"] = "domain-" + k["name"]
      else
        k["name"] = user._id.to_s + "-" + k["name"]
      end
      k
    }
    op_group = PendingAppOpGroup.new(op_name: :update_configuration, args: {"remove_keys_attrs" => key_attrs}, parent_op: parent_op)
    self.pending_op_groups.push op_group
    op_group
  end
  
  def add_env_variables(vars, parent_op=nil)
    op_group = PendingAppOpGroup.new(op_name: :update_configuration, args: {"add_env_variables" => vars}, parent_op: parent_op)
    self.pending_op_groups.push op_group
    op_group
  end
  
  def remove_env_variables(vars, parent_op=nil)
    op_group = PendingAppOpGroup.new(op_name: :update_configuration, args: {"remove_env_variables" => vars}, parent_op: parent_op)
    self.pending_op_groups.push op_group
    op_group
  end
  
  # Returns the total number of gears currently used by this application
  def num_gears
    num = 0
    group_instances.each { |g| num += g.gears.count}
    num
  end
  
  # Returns the feature requirements of the application
  # 
  # == Parameters:
  # include_pending::
  #   Include the pending changes when calulcating the list of features
  #
  # == Returns:
  #   List of features
  def requires(include_pending=false)
    features = component_instances.map {|ci| get_feature(ci.cartridge_name, ci.component_name)}
    
    if include_pending
      self.pending_op_groups.each do |op_group|
        case op_group.op_type
        when :add_components
          features += op[:args]["components"]
        when :remove_components
          features -= op[:args]["components"]
        end
      end
    end
    
    features || []
  end
  
  # Adds components to the application
  # @note {#run_jobs} must be called in order to perform the updates
  def add_components(features, group_overrides=nil)
    unless group_overrides.nil?
      self.set(:group_overrides, group_overrides)
    end
    
    self.pending_op_groups.push PendingAppOpGroup.new(op_type: :add_components, args: {"features" => features, "group_overrides" => group_overrides})
  end

  # Adds components to the application
  # @note {#run_jobs} must be called in order to perform the updates  
  def remove_components(features, group_overrides=nil)
    unless group_overrides.nil?
      self.set(:group_overrides, group_overrides)
    end
    self.pending_op_groups.push PendingAppOpGroup.new(op_type: :remove_components, args: {"features" => features, "group_overrides" => group_overrides})
  end
  
  # Destroys all gears on the application.
  # @note {#run_jobs} must be called in order to perform the updates
  def destroy_app
    self.remove_components(self.requires)
    self.pending_op_groups.push PendingAppOpGroup.new(op_type: :delete_app)
  end
  
  # Updates the component grouping overrides of the application and create tasks to perform the update.
  # @note {#run_jobs} must be called in order to perform the updates
  # 
  # == Parameters:
  # group_overrides::
  #   A list of component grouping overrides to use while creating gears
  def group_overrides=(group_overrides)
    super
    self.pending_op_groups.push PendingAppOpGroup.new(op_type: :add_components, args: {"components" => [], "group_overrides" => group_overrides})
  end
  
  # Scales the group instance that runs this component
  #
  # == Parameters:
  # component::
  #   Component to scale
  #
  # scale_by::
  #   Number of gears to add (+ve) or remove (-ve)
  def scale_by(group_instance_id, scale_by)
    self.pending_op_groups.push PendingAppOpGroup.new(op_type: :scale_by, args: {"group_instance_id" => group_instance_id, "scale_by" => scale_by})
  end
  
  # Returns the fully qualified domain name where the application can be accessed
  def fqdn
    "#{self.name}-#{self.domain.namespace}.#{Rails.configuration.ss[:domain_suffix]}"
  end

  # Returns the ssh URL to access the gear hosting the web_proxy component 
  def ssh_uri
    web_proxy_ginst = group_instances.find_by(app_dns: true)
    unless web_proxy_ginst.nil?
      "#{web_proxy_ginst.gears[0]._id}@#{fqdn}"
    else
      ""
    end
  end

  # Retrieves the gear state for all gears within the application.
  #
  # == Returns:
  #  Hash of gear id to gear state mappings
  def get_gear_states
    Gear.get_gear_states(group_instances.map{|g| g.gears}.flatten)
  end

  def to_descriptor
    h = {
      "Name" => self.name,
      "Requires" => self.requires(true)
    }
    
    h["Start-Order"] = @start_order unless @start_order.nil? || @start_order.empty?
    h["Stop-Order"] = @stop_order unless @stop_order.nil? || @stop_order.empty?
    h["Group-Overrides"] = self.group_overrides unless self.group_overrides.empty?
    
    h
  end

  def start(feature=nil)
  end
  
  def stop(feature=nil, force=false)
  end
  
  def restart(feature=nil)
  end
  
  def reload(feature=nil)
  end
  
  def status
  end
  
  def tidy
  end
  
  # Register a DNS alias for the application.
  #
  # == Parameters:
  # fqdn::
  #   Fully qualified domain name of the alias to associate with this application
  #
  # == Returns:
  # {PendingAppOps} object which tracks the progess of the operation.
  #
  # == Raises:
  # StickShift::UserException if the alias is already been associated with an application.
  def add_alias(fqdn)
    raise StickShift::UserException.new("Alias #{fqdn} is already registered") if Application.where(aliases: fqdn).count > 0
    aliases.push(fqdn)
    op_group = PendingAppOpGroup.with_single_op(:add_alias, {"fqdn" => fqdn})
    self.pending_op_groups.push op_group
    op_group
  end
  
  # Removes a DNS alias for the application.
  #
  # == Parameters:
  # fqdn::
  #   Fully qualified domain name of the alias to remove from this application
  #
  # == Returns:
  # {PendingAppOps} object which tracks the progess of the operation.
  def remove_alias(fqdn)
    return unless aliases.include? fqdn
    aliases.delete(fqdn)
    op_group = PendingAppOpGroup.with_single_op(:remove_alias, {"fqdn" => fqdn})
    self.pending_op_groups.push op_group
    op_group
  end
  
  def expose_port
  end
  
  def conceal_port
  end
  
  def show_port
  end
  
  def system_messages
  end
  
  def set_connections(connections)
    conns = []
    connections.each do |conn_info|
      from_comp_inst = self.component_instances.find_by(cartridge_name: conn_info["from_comp_inst"]["cart"], component_name: conn_info["from_comp_inst"]["comp"])
      to_comp_inst = self.component_instances.find_by(cartridge_name: conn_info["to_comp_inst"]["cart"], component_name: conn_info["to_comp_inst"]["comp"])
      conns.push(ConnectionInstance.new(
        from_comp_inst_id: from_comp_inst._id, to_comp_inst_id: to_comp_inst._id, 
        from_connector_name: conn_info["from_connector_name"], to_connector_name: conn_info["to_connector_name"],
        connection_type: conn_info["connection_type"]))
    end
    self.connections = conns
  end
  
  def execute_connections
    handle = RemoteJob.create_parallel_job
    #expose port
    self.group_instances.each do |group_instance|
      component_instances = group_instance.all_component_instances
      group_instance.gears.each do |gear|
        component_instances.each do |component_instance|
          job = gear.get_expose_port_job(component_instance.cartridge_name)
          RemoteJob.add_parallel_job(handle, "expose-ports::#{component_instance._id.to_s}", gear, job)
        end
      end
    end
    
    #publishers
    sub_jobs = []
    self.connections.each do |conn|
      pub_inst = self.component_instances.find(conn.from_comp_inst_id)
      pub_ginst = self.group_instances.find(pub_inst.group_instance_id)
      tag = conn._id.to_s
      
      pub_ginst.gears.each_index do |idx|
        break if (pub_inst.is_singleton? && idx > 0)
        gear = pub_ginst.gears[idx]
        input_args = [gear.name, self.domain.namespace, gear._id.to_s]
        job = gear.get_execute_connector_job(pub_inst.cartridge_name, conn.from_connector_name, input_args)
        RemoteJob.add_parallel_job(handle, tag, gear, job)
      end
    end
    pub_out = {}            
    RemoteJob.execute_parallel_jobs(handle)
    RemoteJob.get_parallel_run_results(handle) do |tag, gear, output, status|
      if status==0
        if tag.start_with?("expose-ports::")
          component_instance_id = tag[14..-1]
          self.component_instances.find(component_instance_id).process_properties(output)
        else
          pub_out[tag] = [] if pub_out[tag].nil?
          pub_out[tag].push("'#{gear}'='#{output}'")
        end
      end
    end
    
    #subscribers
    handle = RemoteJob.create_parallel_job
    self.connections.each do |conn|            
      sub_inst = self.component_instances.find(conn.to_comp_inst_id)
      sub_ginst = self.group_instances.find(sub_inst.group_instance_id)
      tag = ""
      
      unless pub_out[conn._id.to_s].nil?
        input_to_subscriber = Shellwords::shellescape(pub_out[conn._id.to_s].join(' '))
    
        Rails.logger.debug "Output of publisher - '#{pub_out}'"
        sub_ginst.gears.each_index do |idx|
          break if (sub_inst.is_singleton? && idx > 0)
          gear = sub_ginst.gears[idx]
          
          input_args = [gear.name, self.domain.namespace, gear._id.to_s, input_to_subscriber]
          job = gear.get_execute_connector_job(sub_inst.cartridge_name, conn.to_connector_name, input_args)
          RemoteJob.add_parallel_job(handle, tag, gear, job)
        end
      end
    end
    RemoteJob.execute_parallel_jobs(handle)
  end
  
  #private

  # Processes directives returned by component hooks to add/remove domain ssh keys, app ssh keys, env variables, broker keys etc
  # @note {#run_jobs} must be called in order to perform the updates
  # 
  # == Parameters:
  # result_io::
  #   {ResultIO} object with directives from cartridge hooks
  def process_commands(result_io)
    commands = result_io.cart_commands
    add_ssh_keys = []
    remove_ssh_keys = []
    
    domain_keys_to_add = []
    domain_keys_to_rm = []
    
    env_vars_to_add = []
    env_vars_to_rm = []
    
    commands.each do |command_item|
      case command_item[:command]
      when "SYSTEM_SSH_KEY_ADD"
        domain_keys_to_add.push({"name" => self.name, "content" => command_item[:args][0], "type" => "ssh-rsa"})
      when "SYSTEM_SSH_KEY_REMOVE"
        domain_keys_to_rm.push({"name" => self.name})
      when "APP_SSH_KEY_ADD"
        add_ssh_keys << ApplicationSshKey.new(name: "applicaiton-" + command_item[:args][0], type: "ssh-rsa", content: command_item[:args][1], created_at: Time.now)
      when "APP_SSH_KEY_REMOVE"
        begin
          remove_ssh_keys << self.app_ssh_keys.find_by(name: "applicaiton-" + command_item[:args][0])
        rescue Mongoid::Errors::DocumentNotFound
          #ignore
        end
      when "ENV_VAR_ADD"
        env_vars_to_add.push({"key" => command_item[:args][0], "value" => command_item[:args][1]})
      when "ENV_VAR_REMOVE"
        env_vars_to_rm.push({"key" => command_item[:args][0]})
      when "BROKER_KEY_ADD"
        iv, token = StickShift::AuthService.instance.generate_broker_key(self)
        #add_broker_auth_key(iv,token)
        #TODO
      when "BROKER_KEY_REMOVE"
        #remove_broker_auth_key
        #TODO        
      end
    end
    
    if add_ssh_keys.length > 0
      keys_attrs = add_ssh_keys.map{|k| k.attributes.dup}
      pending_op = PendingAppOpGroup.new(op_type: :update_configuration, args: {"add_keys_attrs" => keys_attrs})
      Application.where(_id: self._id).update_all({ "$push" => { pending_ops: pending_op.serializable_hash } , "$pushAll" => { app_ssh_keys: keys_attrs }})
    end
    if remove_ssh_keys.length > 0
      keys_attrs = add_ssh_keys.map{|k| k.attributes.dup}
      pending_op = PendingAppOpGroup.new(op_type: :update_configuration, args: {"remove_keys_attrs" => keys_attrs})
      Application.where(_id: self._id).update_all({ "$push" => { pending_ops: pending_op.serializable_hash } , "$pullAll" => { app_ssh_keys: keys_attrs }})
    end
    pending_ops.push(PendingAppOpGroup.new(op_type: :update_configuration, args: {
      "add_keys_attrs" => domain_keys_to_add.map{|k| k.attributes.dup},
      "remove_keys_attrs" => domain_keys_to_rm.map{|k| k.attributes.dup},
      "add_env_vars" => env_vars_to_add,
      "remove_env_vars" => env_vars_to_rm,
    })) if ((domain_keys_to_add.length + domain_keys_to_rm.length + env_vars_to_add.length + env_vars_to_rm.length) > 0)
    nil
  end
  
  # Acquires an application level lock and runs all pending jobs and stops at the first failure.
  #
  # == Returns:
  # True on success or False if unable to acquire the lock or no pending jobs.
  def run_jobs(result_io=nil)
    result_io = ResultIO.new if result_io.nil?
    self.reload    
    return true if(self.pending_op_groups.count == 0)
    if(Lock.lock_application(self))
      begin
        while self.pending_op_groups.count > 0
          op_group = self.pending_op_groups.first
          if op_group.pending_ops.count == 0
            case op_group.op_type
            when :add_namespace
            when :remove_namespace
            when :update_configuration
              ops = calculate_update_existing_configurtion_ops(op_group.args)
              op_group.push(*ops)
            when :update_ssh_keys
            when :add_components
              features = self.requires + op_group.args["features"]
              group_overrides = op_group.args["group_overrides"] || []
              ops, add_gear_count, rm_gear_count = update_requirements(features, group_overrides)
              try_reserve_gears(add_gear_count, op_group, ops)
            when :remove_components
              features = self.requires - op_group.args["features"]
              group_overrides = op_group.args["group_overrides"] || []
              ops, add_gear_count, rm_gear_count = update_requirements(features, group_overrides)
              try_reserve_gears(add_gear_count, op_group, ops)
            when :delete_app
              self.pending_op_groups.clear
              self.delete
            when :scale_by
              ops, add_gear_count, rm_gear_count = calculate_scale_by(op_group.args["group_instance_id"], op_group.args["scale_by"])
              try_reserve_gears(add_gear_count, op_group, ops)
            when :add_alias
            when :remove_alias
            end
          end

          if op_group.op_type != :delete_app
            op_group.execute
            op_group.delete
          end
        end
        true
      ensure
        Lock.unlock_application(self)
      end
    else
      false
    end
  end
  
  def update_requirements(features, group_overrides)
    connections, new_group_instances = elaborate(features, group_overrides)
    current_group_instance = self.group_instances.map { |gi| gi.to_hash }
    changes, moves = compute_diffs(current_group_instance, new_group_instances)
    calculate_ops(changes, moves, connections)
  end
  
  def calculate_update_existing_configurtion_ops(args, prereqs={})
    ops = []
    
    if (args.has_key?("add_keys_attrs") or args.has_key?("remove_keys_attrs") or args.has_key?("add_env_vars") or args.has_key?("remove_env_vars"))
      self.group_instances.each do |group_instance|
        args["group_instance_id"] = group_instance._id.to_s
        group_instance.gears.each do |gear|
          prereq = prereqs[gear._id.to_s].nil? ? [] : [prereqs[gear._id.to_s]]
          args["gear_id"] = gear._id.to_s
          ops.push(PendingAppOp.new(op_type: :update_configuration, args: args.dup, prereq: prereq))
        end
      end
    end
    ops
  end
  
  def calculate_update_new_configurtion_ops(args, group_instance_id, gear_id_prereqs)
    ops = []
    
    if (args.has_key?("add_keys_attrs") or args.has_key?("remove_keys_attrs") or args.has_key?("add_env_vars") or args.has_key?("remove_env_vars"))
      args["group_instance_id"] = group_instance_id
      gear_id_prereqs.each_key do |gear_id|
        args["gear_id"] = gear_id
        prereq = gear_id_prereqs[gear_id].nil? ? [] : [gear_id_prereqs[gear_id]]
        ops.push(PendingAppOp.new(op_type: :update_configuration, args: args.dup, prereq: prereq))
      end
    end
    ops
  end
  
  def calculate_scale_by(ginst_id, scale_by)
    current_group_instances = self.group_instances.map { |gi| gi.to_hash }
    changes = []
    current_group_instances.each do |ginst|
      if ginst[:_id].to_s == ginst_id
        min = ginst[:scale][:min] > ginst[:scale][:user_min] ? ginst[:scale][:min] : ginst[:scale][:user_min]
        max = ginst[:scale][:max]
        max = ginst[:scale][:user_max] if (ginst[:scale][:user_max] != ginst[:scale][:max]) && ginst[:scale][:max] == -1
        final_scale = ginst[:scale][:current] + scale_by
        final_scale = min if final_scale < min
        final_scale = max if ((final_scale > max) && (max != -1))
        
        changes << {
          :from=>ginst_id, :to=>ginst_id,
          :added=>[], :removed=>[], :from_scale=>ginst[:scale],
          :to_scale=>{:min=>ginst[:scale][:min], :max=>ginst[:scale][:max], :current=>final_scale}
        }
      end
    end
    calculate_ops(changes)
  end
  
  def calculate_gear_create_ops(ginst_id, gear_ids, comp_specs, component_ops, ginst_op_id=nil, is_scale_up=false)
    pending_ops = []
    ssh_keys = (self.app_ssh_keys + self.domain.system_ssh_keys + self.domain.owner.ssh_keys + CloudUser.find(self.domain.user_ids).map{|u| u.ssh_keys}.flatten)
    ssh_keys = ssh_keys.map{|k| k.attributes}
    env_vars = self.domain.env_vars
    
    gear_id_prereqs = {}
    gear_ids.each do |gear_id|
      create_gear_op  = PendingAppOp.new(op_type: :init_gear,    args: {"group_instance_id"=> ginst_id, "gear_id" => gear_id})
      create_gear_op.prereq = [ginst_op_id] unless ginst_op_id.nil?
      reserve_uid_op  = PendingAppOp.new(op_type: :reserve_uid,  args: {"group_instance_id"=> ginst_id, "gear_id" => gear_id}, prereq: [create_gear_op._id.to_s])
      init_gear_op    = PendingAppOp.new(op_type: :create_gear,  args: {"group_instance_id"=> ginst_id, "gear_id" => gear_id}, prereq: [reserve_uid_op._id.to_s], retry_rollback_op: reserve_uid_op._id.to_s)
      register_dns_op = PendingAppOp.new(op_type: :register_dns, args: {"group_instance_id"=> ginst_id, "gear_id" => gear_id}, prereq: [init_gear_op._id.to_s])
      pending_ops.push(create_gear_op)
      pending_ops.push(reserve_uid_op)
      pending_ops.push(init_gear_op)
      pending_ops.push(register_dns_op)
      gear_id_prereqs[gear_id] = register_dns_op._id.to_s
    end
    
    ops = calculate_update_new_configurtion_ops({"add_keys_attrs" => ssh_keys, "add_env_vars" => env_vars}, ginst_id, gear_id_prereqs)
    pending_ops.push(*ops)
    
    ops = calculate_add_component_ops(comp_specs, ginst_id, gear_id_prereqs, component_ops, is_scale_up, ginst_op_id)
    pending_ops.push(*ops)
    pending_ops
  end
  
  def calculate_gear_destroy_ops(ginst_id, gear_ids)
    pending_ops = []
    gear_ids.each do |gear_id|
      destroy_gear_op   = PendingAppOp.new(op_type: :destroy_gear,  args: {"group_instance_id"=> ginst_id, "gear_id" => gear_id})
      unreserve_uid_op  = PendingAppOp.new(op_type: :unreserve_uid, args: {"group_instance_id"=> ginst_id, "gear_id" => gear_id}, prereq: [destroy_gear_op._id.to_s])
      delete_gear_op    = PendingAppOp.new(op_type: :delete_gear,   args: {"group_instance_id"=> ginst_id, "gear_id" => gear_id}, prereq: [unreserve_uid_op._id.to_s])
      ops = [destroy_gear_op, unreserve_uid_op, delete_gear_op]
      pending_ops.push *ops
    end
    pending_ops
  end
  
  def calculate_add_component_ops(comp_specs, group_instance_id, gear_id_prereqs, component_ops, is_scale_up, new_group_instance_op_id)
    ops = []
    
    configure_order = calculate_configure_order(comp_specs)
    comp_specs.each do |comp_spec|
      component_ops[comp_spec] = [] if component_ops[comp_spec].nil?
      
      new_component_op_id = []
      unless is_scale_up
        new_component_op = PendingAppOp.new(op_type: :new_component, args: {"group_instance_id"=> group_instance_id, "comp_spec" => comp_spec}, prereq: [new_group_instance_op_id])
        new_component_op_id = [new_component_op._id.to_s]
        ops.push new_component_op
      end
      
      gear_id_prereqs.each do |gear_id, prereq_id|
        ops.push(PendingAppOp.new(op_type: :add_component, args: {"group_instance_id"=> group_instance_id, "gear_id" => gear_id, "comp_spec" => comp_spec}, prereq: new_component_op_id + [prereq_id]))
      end
    end
    ops
  end
  
  def calculate_remove_component_ops(comp_specs, group_instance_id)
    ops = []
    comp_specs.each do |comp_spec|
      ginst = self.group_instances.find(group_instance_id)
      ginst.gears.each do |gear|
        ops.push(PendingAppOp.new(op_type: :remove_component, args: {"group_instance_id"=> group_instance_id, "gear_id" => gear_id, "comp_spec" => comp_spec}))
      end
      ops.push(PendingAppOp.new(op_type: :del_component, args: {"group_instance_id"=> group_instance_id, "comp_spec" => comp_spec}, prereq: ops.map{|o| o._id.to_s}))
    end
    ops
  end
  
  # Given a set of changes, moves and connections, calculates all the operations required to update the application.
  #
  # == Parameters:
  # changes::
  #   Changes needed to the current_group_instances to make it match the new_group_instances. (Includes all adds/removes). (Output of {#compute_diffs} or {#scale_by})
  #
  # moves::
  #   A list of components which need to move from one group instance to another. (Output of {#compute_diffs})
  #   
  # connections::
  #   An array of connections. (Output of {#elaborate})
  def calculate_ops(changes,moves=[],connections=nil)
    app_dns_ginst_found = false
    add_gears = 0
    remove_gears = 0
    pending_ops = []
    start_order, stop_order = calculate_component_orders
    
    component_ops = {}
    # Create group instances and gears in preperation formove or add component operations
    create_ginst_changes = changes.select{ |change| change[:from].nil? }
    create_ginst_changes.each do |change|
      ginst_scale = change[:to_scale][:current]
      ginst_id    = change[:to]
      add_gears   += ginst_scale if ginst_scale > 0
      
      ginst_op = PendingAppOp.new(op_type: :create_group_instance, args: {"group_instance_id"=> ginst_id})
      pending_ops.push(ginst_op)
      gear_ids = (1..ginst_scale).map {|idx| Moped::BSON::ObjectId.new.to_s}
      ops = calculate_gear_create_ops(ginst_id, gear_ids, change[:added], component_ops, ginst_op._id.to_s)
      pending_ops.push *ops
    end
    
    moves.each do |move|
      #ops.push(PendingAppOps.new(op_type: :move_component, args: move, flag_req_change: true))
    end
    
    changes.each do |change|
      unless change[:from].nil?
        if change[:to].nil?
          remove_gears += change[:from_scale][:current]
          ginst = self.group_instances.find(change[:from])
          
          ops=calculate_gear_destroy_ops(ginst._id.to_s, ginst.gears.map{|g| g._id.to_s})
          pending_ops.push(*ops)
          op_ids = ops.map{|op| op._id.to_s}
          destroy_ginst_op  = PendingAppOp.new(op_type: :destroy_group_instance, args: {"group_instance_id"=> ginst._id.to_s}, prereq: op_ids)
          pending_ops.push(destroy_ginst_op)
        else
          scale_change = 0
          if change[:to_scale][:current].nil?
            if change[:from_scale][:current] < change[:to_scale][:min]
              scale_change += change[:to_scale][:min] - change[:from_scale][:current]
            end
            if((change[:from_scale][:current] > change[:to_scale][:max]) && (change[:to_scale][:max] != -1))
              scale_change -= change[:from_scale][:current] - change[:to_scale][:max]
            end
          else
            scale_change += (change[:to_scale][:current] - change[:from_scale][:current])
          end
          num_gears += scale_change
          
          ginst = self.group_instance.find(_id: change[:from])
          ops = calculate_remove_component_ops(change[:removed], change[:from])
          pending_ops.push(*ops)
          
          gear_id_prereqs = {}
          ginst.gears.each{|g| gear_id_prereqs[g._id.to_s] = []}
          
          ops = calculate_add_component_ops(change[:added], change[:from], gear_id_prereqs, component_ops)
          pending_ops.push(*ops)
    
          if scale_change > 0
            add_gears += scale_change
            comp_specs = self.component_instances.find_by(group_instance_id: change[:from]).map{|c| c.to_hash}
            gear_ids = (1..scale_change).map {|idx| Moped::BSON::ObjectId.new.to_s}
            ops = calculate_gear_create_ops(change[:from], gear_ids, comp_specs, component_ops, true)
            pending_ops.push *ops
          end
          
          if scale_change < 0
            remove_gears += -scale_change
            ginst = self.group_instance.find(_id: change[:from])
            gears = ginst.gears[-scale_change..-1]
            remove_ids = gears.map{|g| g._id.to_s}
            ops = calculate_gear_destroy_ops(ginst._id.to_s, remove_ids)
            pending_ops.push(*ops)
          end
        end
      end
    end
    
    all_ops_ids = pending_ops.map{ |op| op._id.to_s }
    unless connections.nil?
      #needs to be set and run after all the gears are in place
      set_connections_op = PendingAppOp.new(op_type: :set_connections, args: {"connections"=> connections}, prereq: all_ops_ids)
      execute_connection_op = PendingAppOp.new(op_type: :execute_connections, prereq: [set_connections_op._id.to_s])
      pending_ops.push set_connections_op
      pending_ops.push execute_connection_op
    else
      execute_connection_op = PendingAppOp.new(op_type: :execute_connections, prereq: all_ops_ids)
      pending_ops.push execute_connection_op      
    end

    [pending_ops, add_gears, remove_gears]
  end
  
  # Computes the changes (moves, additions, deletions) required to move from the current set of group instances/components to
  # a new set.
  #
  # == Parameters:
  # current_group_instances::
  #   Group instance list containing information about current group instances. Expected format:
  #     [ {component_instances: [{cart: <cart name>, comp: <comp name>}...], _id: <uuid>, scale: {min: <min scale>, max: <max scale>, current: <current scale>}}...]
  # new_group_instances::
  #   New set of group instances as computed by the elaborate function
  #
  # == Returns:
  # changes::
  #   Changes needed to the current_group_instances to make it match the new_group_instances. (Includes all adds/removes)
  # moves::
  #   A list of components which need to move from one group instance to another
  def compute_diffs(current_group_instances, new_group_instances)
    axis_size = current_group_instances.length + new_group_instances.length
    cost_matrix = Matrix.build(axis_size,axis_size){0}
    #compute cost of moves
    (0..axis_size-1).each do |from|
      (0..axis_size-1).each do |to|
        gi_from = current_group_instances[from].nil? ? [] : current_group_instances[from][:component_instances]
        gi_to   = new_group_instances[to].nil? ? [] : new_group_instances[to][:component_instances]
        
        move_away = gi_from - gi_to
        move_in   = gi_to - gi_from
        cost_matrix[from,to] = move_away.length + move_in.length
      end
    end

    #compute changes
    changes = []
    (0..axis_size-1).each do |from|
      best_to = cost_matrix.row_vectors[from].to_a.index(cost_matrix.row_vectors[from].min)        
      from_id = nil
      from_comp_insts = []
      to_comp_insts   = []
      from_scale      = {min: 1, max: MAX_SCALE, user_min: 1, user_max: MAX_SCALE, current: 0}
      to_scale        = {min: 1, max: MAX_SCALE}
      
      unless current_group_instances[from].nil?
        from_comp_insts = current_group_instances[from][:component_instances]
        from_id         = current_group_instances[from][:_id]
        from_scale      = current_group_instances[from][:scale]
      end
      
      unless new_group_instances[best_to].nil?
        to_comp_insts = new_group_instances[best_to][:component_instances]
        to_scale      = new_group_instances[best_to][:scale]        
        to_id         = from_id || new_group_instances[best_to][:_id]
      end
      unless from_comp_insts.empty? and to_comp_insts.empty?
        added = to_comp_insts - from_comp_insts
        removed = from_comp_insts - to_comp_insts
        changes << {from: from_id, to: to_id, added: added, removed: removed, from_scale: from_scale, to_scale: to_scale}
      end
      (0..axis_size-1).each {|i| cost_matrix[i,best_to] = 1000}
    end
    
    moves = []
    changes.each do |c1|
      c1[:removed].each do |comp_spec|
        changes.each do |c2| 
          if c2[:added].include?(comp_spec)
            from_id = c1[:from].nil? ? nil : c1[:from]
            to_id = c2[:to].nil? ? nil : c2[:to]
            moves << {component: comp_spec, from_group_instance_id: from_id, to_group_instance_id: to_id}
            c1[:removed].delete comp_spec
            c2[:added].delete comp_spec
            break
          end
        end
      end
    end
    
    [changes, moves]
  end
  
  # Persists change operation only if the additonal number of gears requested are available on the domain owner
  #
  # == Parameters:
  # num_gears::
  #   Number of gears to add or remove
  #
  # ops::
  #   Array of pending operations. 
  #   @see {PendingAppOps}
  def try_reserve_gears(num_gears, op_group, ops)
    owner = self.domain.owner
    begin
      until Lock.lock_user(owner)
        sleep 1
      end
      if owner.consumed_gears + num_gears > owner.capabilities["max_gears"]
        raise StickShift::GearLimitReachedException.new("#{owner.login} is currently using #{owner.consumed_gears} out of #{owner.capabilities["max_gears"]} limit and this application requires #{num_gears} additional gears.")
      end
      owner.consumed_gears += num_gears
      op_group.pending_ops.push ops
      op_group.save
      owner.save
    ensure
      Lock.unlock_user(owner)
    end
  end

  # Computes the group instances, component instances and connections required to support a given set of features
  #
  # == Parameters:
  # feature::
  #   A list of features
  # group_overrides::
  #   A list of group-overrides which specify which components must be placed on the same group. 
  #   Components can be specified as Hash{cart: <cart name> [, comp: <component name>]}
  #
  # == Returns:
  # connections::
  #   An array of connections
  # group instances::
  #   An array of hash values representing a group instances.
  def elaborate(features, group_overrides = [])
    profiles = []
    added_cartridges = []

    #calculate initial list based on user provided dependencies
    features.each do |feature|
      cart = CartridgeCache.find_cartridge(feature)
      raise StickShift::UserException.new("No cartridge found that provides #{feature}") if cart.nil?
      prof = cart.profile_for_feature(feature)
      added_cartridges << cart
      profiles << {cartridge: cart, profile: prof}
    end

    #solve for transitive dependencies
    until added_cartridges.length == 0 do
      carts_to_process = added_cartridges
      added_cartridges = []
      carts_to_process.each do |cart|
        cart.requires.each do |feature|
          next if profiles.count{|d| d[:cartridge].features.include?(feature)} > 0

          cart = CartridgeCache.find_cartridge(feature)
          raise StickShift::UserException.new("No cartridge found that provides #{feature} (transitive dependency)") if cart.nil?
          prof = cart.profile_for_feature(feature)
          added_cartridges << cart
          profiles << {cartridge: cart, profile: prof}
        end
      end
    end

    #calculate component instances
    component_instances = []
    profiles.each do |data|
      data[:profile].components.each do |component|
        component_instances << {
          cartridge: data[:cartridge],
          component: component
        }
      end
      group_overrides += data[:profile].group_overrides
    end

    #calculate connections
    publishers = {}
    connections = []
    component_instances.each do |ci|
      ci[:component].publishes.each do |connector|
        type = connector.type
        name = connector.name
        publishers[type] = [] if publishers[type].nil?
        publishers[type] << { cartridge: ci[:cartridge].name , component: ci[:component].name, connector: name }
      end
    end

    component_instances.each do |ci|
      ci[:component].subscribes.each do |connector|
        stype = connector.type
        sname = connector.name

        if publishers.has_key? stype
          publishers[stype].each do |cinfo|
            connections << {
              "from_comp_inst" => {"cart"=> cinfo[:cartridge], "comp"=> cinfo[:component]},
              "to_comp_inst" =>   {"cart"=> ci[:cartridge].name, "comp"=> ci[:component].name},
              "from_connector_name" => cinfo[:connector],
              "to_connector_name" =>   sname,
              "connection_type" =>     stype}
            if stype.starts_with?("FILESYSTEM") or stype.starts_with?("SHMEM")
              group_overrides << [{"cart"=> cinfo[:cartridge], "comp"=> cinfo[:component]}, {"cart"=> ci[:cartridge].name, "comp"=> ci[:component].name}]
            end
          end
        end
      end
    end
    
    #calculate group overrides
    group_overrides.map! do |override_spec|
      processed_spec = []
      override_spec.each do |component_spec|
        component_spec = {"cart" => component_spec} if component_spec.class == String
        if component_spec["comp"].nil?
          feature = component_spec["cart"]
          profiles.each do |prof_spec|
            if prof_spec[:cartridge].features.include?(feature) ||  prof_spec[:cartridge].name == feature
              prof_spec[:profile].components.each do |comp|
                processed_spec << {"cart"=> prof_spec[:cartridge].name, "comp"=> comp.name}
              end
            end
          end
        else
          processed_spec << component_spec
        end
      end
      processed_spec
    end
    
    component_instances.map! do |comp_spec|
      {"comp"=> comp_spec[:component].name, "cart"=> comp_spec[:cartridge].name}
    end
    
    #build group_instances
    group_instances = []
    component_instances.each do |comp_spec|
      #look to see if already accounted for
      next if group_instances.reject{ |g| !g[:component_instances].include?(comp_spec) }.count > 0

      #look for any group_overrides for this component
      grouped_components = group_overrides.reject {|o_spec| !o_spec.include?(comp_spec) }.flatten
      
      #no group overrides, component can sit in its own group
      if grouped_components.length == 0
        group_instances << { component_instances: [comp_spec] , _id: Moped::BSON::ObjectId.new}
      else
        #found group overrides, component must sit with other components. 
        #Will possibly require merging exisitng group_instances
        
        existing_g_insts = []
        grouped_components.each do |g_comp_spec|
          existing_g_insts += group_instances.reject{ |g_inst| !g_inst[:component_instances].include?(g_comp_spec) }
        end
        
        existing_g_inst_components = []
        existing_g_insts.each do |g_comp_spec|
          existing_g_inst_components += g_comp_spec[:component_instances]
        end
              
        existing_g_insts.each {|g_inst| group_instances.delete(g_inst)}
        group_instances  << { component_instances: existing_g_inst_components + [comp_spec] , _id: Moped::BSON::ObjectId.new}
      end
    end
    
    #calculate scale factor
    proc_g_insts = group_instances
    group_instances = []
    proc_g_insts.each do |proc_g_inst|
      scale = {min:1, max: MAX_SCALE, current: 1}
      num_singletons = 0
      proc_g_inst[:component_instances].each do |comp_spec|
        comp = CartridgeCache.find_cartridge(comp_spec["cart"]).get_component(comp_spec["comp"])
        if comp.is_singleton?
          num_singletons += 1
        else
          scale[:min] = comp.scaling.min if comp.scaling.min > scale[:min]
          scale[:max] = comp.scaling.max if (comp.scaling.max != MAX_SCALE) && (scale[:max] == MAX_SCALE || comp.scaling.max < scale[:max])
          scale[:current] = scale[:min]
        end
      end
      scale[:max] = 1 if proc_g_inst[:component_instances].length == num_singletons
      proc_g_inst[:scale] = scale
      group_instances << proc_g_inst
    end
    
    [connections, group_instances]
  end
  
  # Returns the configure order specified in the application descriptor or processes the configure
  # orders for each component and returns the final order (topological sort).
  # @note This is calculates seperately from start/stop order as this function is usually used to 
  #   compute the {PendingAppOps} while start/stop order applies to already configured components.
  #
  # == Parameters:
  # comp_specs::
  #   Array of components specs to order.
  # 
  # == Returns:
  # {ComponentInstance} objects ordered by calculated configure order
  def calculate_configure_order(comp_specs)
    configure_order = ComponentOrder.new
    comps = []
    categories = {}
        
    comp_specs.each do |comp_inst|
      cart = CartridgeCache.find_cartridge(comp_inst["cart"])
      prof = cart.get_profile_for_component(comp_inst["comp"])
      
      comps << {cart: cart, prof: prof}
      [[comp_inst["cart"]],cart.categories,cart.provides,prof.provides].flatten.each do |cat|
        categories[cat] = [] if categories[cat].nil?
        categories[cat] << comp_inst
      end
      configure_order.add_component_order([comp_inst])
    end
    
    #use the map to build DAG for order calculation
    comps.each do |comp_spec|
      configure_order.add_component_order(comp_spec[:prof].configure_order.map{|c| categories[c]}.flatten)
    end
    
    #calculate configure order using tsort
    if self.component_configure_order.empty?
      computed_configure_order = configure_order.tsort
    else
      computed_configure_order = self.component_configure_order.map{|c| categories[c]}.flatten
    end
    computed_configure_order
  end

  # Returns the start/stop order specified in the application descriptor or processes the stat and stop
  # orders for each component and returns the final order (topological sort).
  # 
  # == Returns:
  # start_order::
  #   {ComponentInstance} objects ordered by calculated start order
  # stop_order::
  #   {ComponentInstance} objects ordered by calculated stop order  
  def calculate_component_orders
    start_order = ComponentOrder.new
    stop_order = ComponentOrder.new
    comps = []
    categories = {}
    
    #build a map of [categories, features, cart name] => component_instance
    component_instances.each do |comp_inst|
      cart = CartridgeCache.find_cartridge(comp_inst.cartridge_name)
      prof = cart.get_profile_for_component(comp_inst.component_name)
      
      comps << {cart: cart, prof: prof}
      [[comp_inst.cartridge_name],cart.categories,cart.provides,prof.provides].flatten.each do |cat|
        categories[cat] = [] if categories[cat].nil?
        categories[cat] << comp_inst
      end
      start_order.add_component_order([comp_inst])
      stop_order.add_component_order([comp_inst])
    end
    
    #use the map to build DAG for order calculation
    comps.each do |comp_spec|
      start_order.add_component_order(comp_spec[:prof].start_order.map{|c| categories[c]}.flatten)
      stop_order.add_component_order(comp_spec[:prof].stop_order.map{|c| categories[c]}.flatten)
    end
    
    #calculate start order using tsort
    if self.component_start_order.empty?
      computed_start_order = start_order.tsort
    else
      computed_start_order = self.component_start_order.map{|c| categories[c]}.flatten
    end
    
    #calculate stop order using tsort
    if self.component_stop_order.empty?
      computed_stop_order = stop_order.tsort
    else
      computed_stop_order = self.component_stop_order.map{|c| categories[c]}.flatten
    end
    
    [computed_start_order, computed_stop_order]
  end
  
  # Gets a feature name for the cartridge/component combination
  #
  # == Parameters:
  # cartridge_name::
  #   Name of cartridge
  # component_name::
  #   Name of component
  #
  # == Returns:
  # Feature name provided by the cartridge that includes the component
  def get_feature(cartridge_name,component_name)
    cart = CartridgeCache.find_cartridge cartridge_name
    prof = cart.get_profile_for_component component_name
    (prof.provides.length > 0 && prof.name != cart.default_profile) ? prof.provides.first : cart.provides.first
  end
end