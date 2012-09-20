class District
  include Mongoid::Document
  include Mongoid::Timestamps

  field :name, type: String
  field :uuid, type: String
  field :gear_size, type: String
  field :externally_reserved_uids_size, type: Integer
  field :max_capacity, type: Integer
  field :max_uid, type: Integer
  field :available_uids, type: Array, default: []
  field :available_capacity, type: Integer
  field :active_server_identities_size, type: Integer
  field :server_identities, type: Array

#  attr_accessor :server_identities, :active_server_identities_size, :uuid, :creation_time, :available_capacity, :available_uids, :max_uid, :max_capacity, :externally_reserved_uids_size, :node_profile, :name

  def self.create_district(name, gear_size=nil)
    profile = gear_size ? gear_size : "small"
    if District.where(name: name).count > 0
      raise StickShift::SSException.new("District by name #{name} already exists")
    end
    dist = District.new(name: name, gear_size: profile)
  end

  def initialize(attrs = nil, options = nil)
    super
    self.server_identities = {}
    self.uuid = StickShift::Model.gen_uuid
    self.available_capacity = Rails.configuration.gearchanger[:districts][:max_capacity]
    self.available_uids = []
    self.available_uids.fill(0, Rails.configuration.gearchanger[:districts][:max_capacity]) {|i| i+Rails.configuration.gearchanger[:districts][:first_uid]}
    self.max_uid = Rails.configuration.gearchanger[:districts][:max_capacity] + Rails.configuration.gearchanger[:districts][:first_uid] - 1
    self.max_capacity = Rails.configuration.gearchanger[:districts][:max_capacity]
    self.externally_reserved_uids_size = 0
    self.active_server_identities_size = 0
    save
  end
  
  def self.find_available(gear_size=nil)
    valid_districts = District.where(:available_capacity.gt => 0, :gear_size => gear_size, :active_server_identities_size.gt => 0)
    valid_districts.sort(["available_capacity", "descending"]).limit(1).next
  end
  
  def delete()
    if not server_identities.empty?
      raise StickShift::SSException.new("Couldn't destroy district '#{uuid}' because it still contains nodes")
    end
    super
  end
  
  def add_node(server_identity)
    if server_identity
      found = District.in("server_identities.name" => [server_identity]).exists?
      unless found
        container = StickShift::ApplicationContainerProxy.instance(server_identity)
        begin
          capacity = container.get_capacity
          if capacity == 0
            container_node_profile = container.get_node_profile
            if container_node_profile == node_profile 
              container.set_district(@uuid, true)
              # StickShift::DataStore.instance.add_district_node(@uuid, server_identity)
              self.active_server_identities_size += 1
              self.server_identities << [{ "name" => server_identity, "active" => true}]
              self.save
            else
              raise StickShift::SSException.new("Node with server identity: #{server_identity} is of node profile '#{container_node_profile}' and needs to be '#{node_profile}' to add to district '#{name}'")  
            end
          else
            raise StickShift::SSException.new("Node with server identity: #{server_identity} already has apps on it")
          end
        rescue StickShift::NodeException => e
          raise StickShift::SSException.new("Node with server identity: #{server_identity} could not be found")
        end
      else
        raise StickShift::SSException.new("Node with server identity: #{server_identity} already belongs to another district: #{hash["uuid"]}")
      end
    else
      raise StickShift::UserException.new("server_identity is required")
    end
  end

  def server_identities_hash
    sih = {}
    server_identities.each { |server_identity_info| sih[server_identity_info["name"]] = { "active" => server_identity_info["active"]} }
    sih
  end
  
  def remove_node(server_identity)
    server_map = server_identities_hash
    if server_map.has_key?(server_identity)
      unless server_map[server_identity]["active"]
        container = StickShift::ApplicationContainerProxy.instance(server_identity)
        capacity = container.get_capacity
        if capacity == 0
          container.set_district('NONE', false)
          server_identities.delete({ "name" => server_identity, "active" => false} )
          if not self.save
            raise StickShift::SSException.new("Node with server identity: #{server_identity} could not be removed from district: #{@uuid}")
          end
        else
          raise StickShift::SSException.new("Node with server identity: #{server_identity} could not be removed from district: #{@uuid} because it still has apps on it")
        end
      else
        raise StickShift::SSException.new("Node with server identity: #{server_identity} from district: #{@uuid} must be deactivated before it can be removed")
      end
    else
      raise StickShift::SSException.new("Node with server identity: #{server_identity} doesn't belong to district: #{@uuid}")
    end
  end
  
  def deactivate_node(server_identity)
    server_map = server_identities_hash
    if server_map.has_key?(server_identity)
      if server_map[server_identity]["active"]
        server_identities[server_identity] = {"active" => false}
        District.where("_id" => self._id, "server_identities.name" => server_identity ).find_and_modify({ "$set" => { "server_identities.$.active" => false } }, new: true)
        self.reload
        container = StickShift::ApplicationContainerProxy.instance(server_identity)
        container.set_district(@uuid, false)
      else
        raise StickShift::SSException.new("Node with server identity: #{server_identity} is already deactivated")
      end
    else
      raise StickShift::SSException.new("Node with server identity: #{server_identity} doesn't belong to district: #{@uuid}")
    end
  end
  
  def activate_node(server_identity)
    server_map = server_identities_hash
    if server_map.has_key?(server_identity)
      unless server_map[server_identity]["active"]
        StickShift::DataStore.instance.activate_district_node(@uuid, server_identity)
        District.where("_id" => self._id, "server_identities.name" => server_identity ).find_and_modify({ "$set" => { "server_identities.$.active" => true} }, new: true)
        self.reload
        container = StickShift::ApplicationContainerProxy.instance(server_identity)
        container.set_district(@uuid, true)
      else
        raise StickShift::SSException.new("Node with server identity: #{server_identity} is already active")
      end
    else
      raise StickShift::SSException.new("Node with server identity: #{server_identity} doesn't belong to district: #{@uuid}")
    end
  end

  def reserve_uid
    raise StickShift::SSException.new("The district #{@name} has no available uid to reserve.") if self.available_capacity <= 0
    uid = self.available_uids.pop
    self.available_capacity -= 1
    self.save
    uid
  end

  def unreserve_uid(uid)
    raise StickShift::SSException.new("The district '#{@name}' already has the uid '#{uid}' unreserved") if self.available_uids.include? uid
    @available_capacity += 1
    @available_uids << uid
    self.save
  end
  
  def add_capacity(num_uids)
    if num_uids > 0
      additions = []
      additions.fill(0, num_uids) {|i| i+max_uid+1}
      @available_capacity += num_uids
      @max_uid += num_uids
      @max_capacity += num_uids
      @available_uids += additions
      self.save
    else
      raise StickShift::SSException.new("You must supply a positive number of uids to remove")
    end
  end
  
  def remove_capacity(num_uids)
    if num_uids > 0
      subtractions = []
      subtractions.fill(0, num_uids) {|i| i+max_uid-num_uids+1}
      pos = 0
      found_first_pos = false
      available_uids.each do |available_uid|
        if !found_first_pos && available_uid == subtractions[pos]
          found_first_pos = true
        elsif found_first_pos
          unless available_uid == subtractions[pos]
            raise StickShift::SSException.new("Uid: #{subtractions[pos]} not found in order in available_uids.  Can not continue!")
          end
        end
        pos += 1 if found_first_pos
        break if pos == subtractions.length
      end
      if !found_first_pos
        raise StickShift::SSException.new("Missing uid: #{subtractions[0]} in existing available_uids.  Can not continue!")
      end
      # StickShift::DataStore.instance.remove_district_uids(uuid, subtractions)
      @available_capacity -= num_uids
      @max_uid -= num_uids
      @max_capacity -= num_uids
      @available_uids -= subtractions
      self.save
    else
      raise StickShift::SSException.new("You must supply a positive number of uids to remove")
    end
  end
  
end
