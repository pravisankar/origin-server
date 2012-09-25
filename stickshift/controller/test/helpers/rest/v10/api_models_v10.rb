require "#{File.dirname(__FILE__)}/../api_common"

class MV10 < TRestCommon

  class TBaseApi < TBaseLinkObj
    attr_accessor :links

    def initialize
      self.links = {
           "API" => MV10::TLink.new("GET", "api"),
           "GET_ENVIRONMENT" => MV10::TLink.new("GET", "environment"),
           "GET_USER" => MV10::TLink.new("GET", "user"),
           "LIST_DOMAINS" => MV10::TLink.new("GET", "domains"),
           "ADD_DOMAIN" => MV10::TLink.new("POST", "domains", [
             MV10::TParam.new("id", "string")
            ]),
           "LIST_CARTRIDGES" => MV10::TLink.new("GET", "cartridges"),
           "LIST_TEMPLATES" => MV10::TLink.new("GET", "application_templates"),
           "LIST_ESTIMATES" => MV10::TLink.new("GET", "estimates")
      } unless $nolinks
    end
  end

  class TRestUser < TBaseLinkObj
    attr_accessor :login, :consumed_gears, :max_gears, :capabilities, :plan_id, :usage_account_id, :links

    def initialize
      self.login = nil
      self.consumed_gears = 0
      self.capabilities = nil
      self.max_gears = 3
      self.plan_id = nil
      self.usage_account_id = nil
      self.links = {
        "LIST_KEYS" => MV10::TLink.new("GET", "user/keys"),                     
        "ADD_KEY" => MV10::TLink.new("POST", "user/keys", [                  
          MV10::TParam.new("name", "string"),                                        
          MV10::TParam.new("type", "string", ["ssh-rsa", "ssh-dss"]),                            
          MV10::TParam.new("content", "string"),      
          ])
      } unless $nolinks 
    end

    def compare(obj)
      raise_ex("User 'login' NOT found") if obj.login.nil?
      super
    end
  end

  class TRestCartridge < TBaseLinkObj
    attr_accessor :type, :name, :links, :properties
    
    def initialize(type=nil, name=nil)
      self.name = name
      self.type = type
      self.properties = {}
      if type == "embedded"
        self.links = {
          "GET" => MV10::TLink.new("GET", "/cartridges/#{name}"),
          "START" => MV10::TLink.new("POST", "/cartridges/#{name}/events", [
            MV10::TParam.new("event", "string", "start")
          ]),
          "STOP" => MV10::TLink.new("POST", "/cartridges/#{name}/events", [
            MV10::TParam.new("event", "string", "stop")                                              
          ]),
          "RESTART" => MV10::TLink.new("POST", "/cartridges/#{name}/events", [
            MV10::TParam.new("event", "string", "restart")                                           
          ]),                                                                                          
          "RELOAD" => MV10::TLink.new("POST", "/cartridges/#{name}/events", [ 
            MV10::TParam.new("event", "string", "reload")                                            
          ]),
          "DELETE" => MV10::TLink.new("DELETE", "/cartridges/#{name}")
        } unless $nolinks
      end
    end

    def valid
      raise_ex("Invalid cartridge type '#{self.type}'") if ((self.type != 'standalone') && (self.type != 'embedded'))
    end
  end

  class TRestEstimates < TBaseLinkObj
    attr_accessor :links

    def initialize
      self.links = {
        "GET_ESTIMATE" => MV10::TLink.new("GET", "estimates/application",
          [ MV10::TParam.new("descriptor", "string") ])
      } unless $nolinks
    end
  end

  class TRestApplicationEstimate < TBaseLinkObj
    attr_accessor :components

    def initialize
      self.components = nil
    end
  end

  class TRestApplicationTemplate < TBaseLinkObj
    attr_accessor :uuid, :display_name, :descriptor_yaml, :git_url, :tags, :gear_cost, :metadata
    attr_accessor :links

    def initialize
      self.uuid, self.display_name, self.descriptor_yaml = nil, nil, nil
      self.git_url, self.tags, self.gear_cost, self.metadata = nil, nil, nil, nil
      self.links = nil
    end
  end

  class TRestDomain < TBaseLinkObj
    attr_accessor :id, :suffix, :links

    def initialize(id=nil)
      self.id = id
      self.suffix = nil
      self.links = {
        "GET" => MV10::TLink.new("GET", "domains/#{id}"),
        "LIST_APPLICATIONS" => MV10::TLink.new("GET", "domains/#{id}/applications"),
        "ADD_APPLICATION" => MV10::TLink.new("POST", "domains/#{id}/applications",
          [MV10::TParam.new("name", "string")],
          [MV10::TOptionalParam.new("cartridge", "string"),
           MV10::TOptionalParam.new("template", "string"),
           MV10::TOptionalParam.new("scale", "boolean", [true, false], false),
           MV10::TOptionalParam.new("gear_profile", "string", ["small"], "small")]),
        "UPDATE" => MV10::TLink.new("PUT", "domains/#{id}",
          [ MV10::TParam.new("id", "string") ]),
        "DELETE" => MV10::TLink.new("DELETE", "domains/#{id}", nil,
          [ MV10::TOptionalParam.new("force", "boolean", [true, false], false) ])
      } unless $nolinks
    end
  end

  class TRestKey < TBaseLinkObj
    attr_accessor :name, :content, :type, :links

    def initialize(name=nil, content=nil, type=nil)
      self.name = name
      self.content = content
      self.type = type
      self.links = {
        "GET" => MV10::TLink.new("GET", "user/keys/#{name}"),
        "UPDATE" => MV10::TLink.new("PUT", "user/keys/#{name}", [
          MV10::TParam.new("type", "string", ["ssh-rsa", "ssh-dss"]),
          MV10::TParam.new("content", "string") ]),
        "DELETE" => MV10::TLink.new("DELETE", "user/keys/#{name}")
      } unless $nolinks
    end
  end

  class TRestApplication < TBaseLinkObj
    attr_accessor :framework, :creation_time, :uuid, :embedded, :aliases, :name, :gear_count, :links, :domain_id, :git_url, :app_url,
     :ssh_url, :gear_profile, :scalable, :health_check_path, :scale_min, :scale_max, :build_job_url, :building_with, :building_app

    def initialize(name=nil, framework=nil, domain_id=nil, scalable=nil)
      self.name = name
      self.framework = framework
      self.creation_time = nil
      self.uuid = nil
      self.embedded = nil
      self.aliases = nil
      self.gear_count = nil
      self.domain_id = domain_id
      self.gear_profile = nil
      self.git_url = nil
      self.app_url = nil
      self.ssh_url = nil
      self.scalable = scalable
      self.scale_min = 1
      self.scale_max = -1
      self.health_check_path = nil
      self.build_job_url = nil
      self.building_with = nil
      self.building_app = nil
      
      self.links = {
        "GET" => MV10::TLink.new("GET", "domains/#{domain_id}/applications/#{name}"),
        "GET_DESCRIPTOR" => MV10::TLink.new("GET", "domains/#{domain_id}/applications/#{name}/descriptor"),
        "GET_GEARS" => MV10::TLink.new("GET", "domains/#{domain_id}/applications/#{name}/gears"),
        "GET_GEAR_GROUPS" => MV10::TLink.new("GET", "domains/#{domain_id}/applications/#{name}/gear_groups"),      
        "START" => MV10::TLink.new("POST", "domains/#{domain_id}/applications/#{name}/events",
          [ MV10::TParam.new("event", "string", "start") ]),
        "STOP" => MV10::TLink.new("POST", "domains/#{domain_id}/applications/#{name}/events",
          [ MV10::TParam.new("event", "string", "stop") ]),
        "RESTART" => MV10::TLink.new("POST", "domains/#{domain_id}/applications/#{name}/events",
          [ MV10::TParam.new("event", "string", "restart") ]),
        "FORCE_STOP" => MV10::TLink.new("POST", "domains/#{domain_id}/applications/#{name}/events",
          [ MV10::TParam.new("event", "string", "force-stop") ]),
        "EXPOSE_PORT" => MV10::TLink.new("POST", "domains/#{domain_id}/applications/#{name}/events",
          [ MV10::TParam.new("event", "string", "expose-port") ]),
        "CONCEAL_PORT" => MV10::TLink.new("POST", "domains/#{domain_id}/applications/#{name}/events",
          [ MV10::TParam.new("event", "string", "conceal-port") ]),
        "SHOW_PORT" => MV10::TLink.new("POST", "domains/#{domain_id}/applications/#{name}/events",
          [ MV10::TParam.new("event", "string", "show-port") ]),
        "ADD_ALIAS" => MV10::TLink.new("POST", "domains/#{domain_id}/applications/#{name}/events",
          [ MV10::TParam.new("event", "string", "add-alias"),                                            
            MV10::TParam.new("alias", "string") ]),
        "REMOVE_ALIAS" => MV10::TLink.new("POST", "domains/#{domain_id}/applications/#{name}/events",
          [ MV10::TParam.new("event", "string", "remove-alias"),                                         
            MV10::TParam.new("alias", "string") ]),
        "SCALE_UP" => MV10::TLink.new("POST", "domains/#{domain_id}/applications/#{name}/events",
          [ MV10::TParam.new("event", "string", "scale-up") ]),
        "SCALE_DOWN" => MV10::TLink.new("POST", "domains/#{domain_id}/applications/#{name}/events",
          [ MV10::TParam.new("event", "string", "scale-down") ]),
        "DELETE" => MV10::TLink.new("DELETE", "domains/#{domain_id}/applications/#{name}"),
        "ADD_CARTRIDGE" => MV10::TLink.new("POST", "domains/#{domain_id}/applications/#{name}/cartridges",
            [ 
              MV10::TParam.new("name", "string") 
            ],[ 
              MV10::TOptionalParam.new("colocate_with", "string"),
              MV10::TOptionalParam.new("scales_from", "integer"),
              MV10::TOptionalParam.new("scales_to", "integer"),
              MV10::TOptionalParam.new("additional_storage", "integer")
            ]),
        "LIST_CARTRIDGES" => MV10::TLink.new("GET", "domains/#{domain_id}/applications/#{name}/cartridges")
      } unless $nolinks
    end
  end

  class TRestGear < TBaseLinkObj
    attr_accessor :uuid, :components

    def initialize(components=nil)
      self.uuid = nil
      self.components = components
    end
  end

  class TRestGearGroup < TBaseLinkObj
    attr_accessor :uuid, :name, :gear_profile, :gears, :cartridges, :links, :scales_from, :scales_to, :base_gear_storage, :additional_gear_storage

    def initialize(name=nil)
      self.uuid = uuid
      self.name = name
      self.gear_profile = nil
      self.gears = nil
      self.cartridges = nil
      self.links = nil
    end
  end
end
