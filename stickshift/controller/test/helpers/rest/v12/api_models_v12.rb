require "#{File.dirname(__FILE__)}/../v11/api_models_v11"

class MV12 < MV11

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
      self.health_check_path = nil
      self.build_job_url = nil
      self.building_with = nil
      self.building_app = nil
      
      self.links = {
        "GET" => MV12::TLink.new("GET", "domains/#{domain_id}/applications/#{name}"),
        "GET_DESCRIPTOR" => MV12::TLink.new("GET", "domains/#{domain_id}/applications/#{name}/descriptor"),
        "GET_GEARS" => MV12::TLink.new("GET", "domains/#{domain_id}/applications/#{name}/gears"),
        "GET_GEAR_GROUPS" => MV12::TLink.new("GET", "domains/#{domain_id}/applications/#{name}/gear_groups"),      
        "START" => MV12::TLink.new("POST", "domains/#{domain_id}/applications/#{name}/events",
          [ MV12::TParam.new("event", "string", "start") ]),
        "STOP" => MV12::TLink.new("POST", "domains/#{domain_id}/applications/#{name}/events",
          [ MV12::TParam.new("event", "string", "stop") ]),
        "RESTART" => MV12::TLink.new("POST", "domains/#{domain_id}/applications/#{name}/events",
          [ MV12::TParam.new("event", "string", "restart") ]),
        "FORCE_STOP" => MV12::TLink.new("POST", "domains/#{domain_id}/applications/#{name}/events",
          [ MV12::TParam.new("event", "string", "force-stop") ]),
        "EXPOSE_PORT" => MV12::TLink.new("POST", "domains/#{domain_id}/applications/#{name}/events",
          [ MV12::TParam.new("event", "string", "expose-port") ]),
        "CONCEAL_PORT" => MV12::TLink.new("POST", "domains/#{domain_id}/applications/#{name}/events",
          [ MV12::TParam.new("event", "string", "conceal-port") ]),
        "SHOW_PORT" => MV12::TLink.new("POST", "domains/#{domain_id}/applications/#{name}/events",
          [ MV12::TParam.new("event", "string", "show-port") ]),
        "ADD_ALIAS" => MV12::TLink.new("POST", "domains/#{domain_id}/applications/#{name}/events",
          [ MV12::TParam.new("event", "string", "add-alias"),                                            
            MV12::TParam.new("alias", "string") ]),
        "REMOVE_ALIAS" => MV12::TLink.new("POST", "domains/#{domain_id}/applications/#{name}/events",
          [ MV12::TParam.new("event", "string", "remove-alias"),                                         
            MV12::TParam.new("alias", "string") ]),
        "SCALE_UP" => MV12::TLink.new("POST", "domains/#{domain_id}/applications/#{name}/events",
          [ MV12::TParam.new("event", "string", "scale-up") ]),
        "SCALE_DOWN" => MV12::TLink.new("POST", "domains/#{domain_id}/applications/#{name}/events",
          [ MV12::TParam.new("event", "string", "scale-down") ]),
        "DELETE" => MV12::TLink.new("DELETE", "domains/#{domain_id}/applications/#{name}"),
        "ADD_CARTRIDGE" => MV12::TLink.new("POST", "domains/#{domain_id}/applications/#{name}/cartridges",
            [ 
              MV12::TParam.new("name", "string") 
            ],[ 
              MV12::TOptionalParam.new("colocate_with", "string"),
              MV12::TOptionalParam.new("scales_from", "integer"),
              MV12::TOptionalParam.new("scales_to", "integer"),
              MV12::TOptionalParam.new("additional_storage", "integer")
            ]),
        "LIST_CARTRIDGES" => MV12::TLink.new("GET", "domains/#{domain_id}/applications/#{name}/cartridges")
      } unless $nolinks
    end
  end

  class TRestUser < TBaseLinkObj
    attr_accessor :login, :consumed_gears, :capabilities, :plan_id, :usage_account_id, :links
             
    def initialize
      self.login = nil
      self.consumed_gears = 0
      self.capabilities = {"subaccounts" => false, "gear_sizes" => ["small"], "max_gears" => 3}
      self.plan_id = nil
      self.usage_account_id = nil
      self.links = {
        "LIST_KEYS" => MV12::TLink.new("GET", "user/keys"),                     
        "ADD_KEY" => MV12::TLink.new("POST", "user/keys", [                  
          MV12::TParam.new("name", "string"),                                        
          MV12::TParam.new("type", "string", ["ssh-rsa", "ssh-dss"]),                            
          MV12::TParam.new("content", "string"),      
          ])
      } unless $nolinks 
    end

    def compare(obj)
      raise_ex("User 'login' NOT found") if obj.login.nil?
      super
    end
  end
end
