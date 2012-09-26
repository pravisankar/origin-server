require "#{File.dirname(__FILE__)}/../v10/api_models_v10"

class MV11 < MV10

  class TRestCartridge < TBaseLinkObj
    attr_accessor :type, :name, :version, :license, :license_url, :tags, :website,
      :suggests, :requires, :conflicts, :provides, :help_topics, :links, :properties,
      :display_name, :description, :scales_from, :scales_to, :current_scale, 
      :supported_scales_from, :supported_scales_to, :scales_with, :base_gear_storage, 
      :additional_gear_storage, :gear_size, :collocated_with
    
    def initialize(type=nil, name=nil)
      self.name = name
      self.type = type
      self.properties = {}
      if type == "embedded"
        self.links = {
          "GET" => MV11::TLink.new("GET", "/cartridges/#{name}"),
          "START" => MV11::TLink.new("POST", "/cartridges/#{name}/events", [
            MV11::TParam.new("event", "string", "start")
          ]),
          "STOP" => MV11::TLink.new("POST", "/cartridges/#{name}/events", [
            MV11::TParam.new("event", "string", "stop")                                              
          ]),
          "RESTART" => MV11::TLink.new("POST", "/cartridges/#{name}/events", [
            MV11::TParam.new("event", "string", "restart")                                           
          ]),                                                                                          
          "RELOAD" => MV11::TLink.new("POST", "/cartridges/#{name}/events", [ 
            MV11::TParam.new("event", "string", "reload")                                            
          ]),
          "DELETE" => MV11::TLink.new("DELETE", "/cartridges/#{name}")
        } unless $nolinks
      end
    end

    def valid
      raise_ex("Invalid cartridge type '#{self.type}'") if ((self.type != 'standalone') && (self.type != 'embedded'))
    end
  end
end
