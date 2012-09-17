class RestGearGroup < StickShift::Model
  attr_accessor :uuid, :name, :gear_profile, :cartridges, :gears, :links

  def initialize(group_instance, gear_states = {}, url, nolinks)
    self.uuid         = group_instance._id.to_s
    self.name         = self.uuid
    self.gear_profile = group_instance.gear_size
    self.gears        = group_instance.gears.map{ |gear| {:id => gear._id.to_s, :state => gear_states[gear._id.to_s] || 'unknown'} }
    self.cartridges   = group_instance.all_component_instances.map { |c| c.component_properties.merge({:name => c.cartridge_name}) }
    app = group_instance.application

    self.links = {
      "LIST_RESOURCES" => Link.new("List resources", "GET", URI::join(url, "domains/#{app.domain.namespace}/applications/#{app.name}/gear_groups/#{uuid}/resources")),
      "UPDATE_RESOURCES" => Link.new("Update resources", "PUT", URI::join(url, "domains/#{app.domain.namespace}/applications/#{app.name}/gear_groups/#{uuid}/resources"),[
        Param.new("storage", "integer", "The filesystem storage on each gear within the group in gigabytes")
      ])
    } unless nolinks
  end

  def to_xml(options={})
    options[:tag_name] = "gear_group"
    super(options)
  end
end
