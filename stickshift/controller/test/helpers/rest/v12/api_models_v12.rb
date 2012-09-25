require "#{File.dirname(__FILE__)}/../v11/api_models_v11"

class MV12 < MV11

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
