class RestUser < StickShift::Model
  attr_accessor :login, :consumed_gears, :max_gears, :capabilities, :plan_id, :usage_account_id, :links, :consumed_gear_sizes
  
  def initialize(cloud_user, url, nolinks=false)
    self.login = cloud_user.login
    self.consumed_gears = cloud_user.consumed_gears
    self.max_gears = cloud_user.max_gears
    self.capabilities = cloud_user.capabilities
    self.plan_id = cloud_user.plan_id
    self.usage_account_id = cloud_user.usage_account_id

    consumed_map = {}
    cloud_user.domains.each do |domain|
      domain.applications.each do |application|
        application.group_instances.each do |group_instance|
          consumed_map[group_instance.node_size] ||= 0
          consumed_map[group_instance.node_size] += group_instance.gears.length
        end
      end
    end
    self.consumed_gear_sizes = consumed_map
    
    self.links = {
      "LIST_KEYS" => Link.new("Get SSH keys", "GET", URI::join(url, "user/keys")),
      "ADD_KEY" => Link.new("Add new SSH key", "POST", URI::join(url, "user/keys"), [
        Param.new("name", "string", "Name of the key"),
        Param.new("type", "string", "Type of Key", ["ssh-rsa", "ssh-dss"]),
        Param.new("content", "string", "The key portion of an rsa key (excluding ssh-rsa and comment)"),
      ])
    } unless nolinks
  end
  
  def to_xml(options={})
    options[:tag_name] = "user"
    super(options)
  end
end
