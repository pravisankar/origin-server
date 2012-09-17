class RestCartridge11 < StickShift::Model
  attr_accessor :type, :name, :version, :license, :license_url, :tags, :website, :suggests, :requires, :conflicts, :provides,
    :help_topics, :links, :properties, :display_name, :description, :scales_with

  def initialize(type, cart, app, cinst, url, nolinks=false)
    self.name = cart.name
    self.version = cart.version
    self.display_name = cart.display_name
    self.description = cart.description
    self.license = cart.license
    self.license_url = cart.license_url
    self.tags = cart.categories
    self.website = cart.website
    self.suggests = cart.suggests
    self.requires = cart.requires
    self.conflicts = cart.conflicts
    self.type = "standalone"
    self.type = "embedded" if cart.categories.include? "embedded"

    if app.nil?
      self.provides = cart.features
    else
      self.provides = app.get_feature(cinst.cartridge_name, cinst.component_name)
    end
    self.help_topics = cart.help_topics

    self.properties = []
    prop_values = cinst.component_properties
    cart.cart_data_def.each do |data_def|
      property = {}
      property["name"] = data_def["Key"]
      property["type"] = data_def["Type"]
      property["description"] = data_def["Description"]
      property["value"] = prop_values[data_def["Key"]] unless prop_values.nil? or prop_values[data_def["Key"]].nil?
      self.properties << property
    end

    self.scales_with = nil
    app.component_instances.each do |component_instance|
      cart = CartridgeCache::find_cartridge(component_instance.cartridge_name)
      if cart.categories.include?("scales")
        self.scales_with = component_instance.cartridge_name
        break
      end
    end

    if app and !nolinks
      domain_id = app.domain.namespace
      app_id = app.name
      if self.type == "embedded" and not app_id.nil? and not domain_id.nil?
        self.links = {
            "GET" => Link.new("Get embedded cartridge", "GET", URI::join(url, "domains/#{domain_id}/applications/#{app_id}/cartridges/#{name}")),
            "START" => Link.new("Start embedded cartridge", "POST", URI::join(url, "domains/#{domain_id}/applications/#{app_id}/cartridges/#{name}/events"), [
              Param.new("event", "string", "event", "start")
            ]),
            "STOP" => Link.new("Stop embedded cartridge", "POST", URI::join(url, "domains/#{domain_id}/applications/#{app_id}/cartridges/#{name}/events"), [
              Param.new("event", "string", "event", "stop")
            ]),
            "RESTART" => Link.new("Restart embedded cartridge", "POST", URI::join(url, "domains/#{domain_id}/applications/#{app_id}/cartridges/#{name}/events"), [
              Param.new("event", "string", "event", "restart")
            ]),
            "RELOAD" => Link.new("Reload embedded cartridge", "POST", URI::join(url, "domains/#{domain_id}/applications/#{app_id}/cartridges/#{name}/events"), [
              Param.new("event", "string", "event", "reload")
            ]),
            "DELETE" => Link.new("Delete embedded cartridge", "DELETE", URI::join(url, "domains/#{domain_id}/applications/#{app_id}/cartridges/#{name}"))
          }
      end
    end
  end

  def to_xml(options={})
    options[:tag_name] = "cartridge"
    super(options)
  end
end
