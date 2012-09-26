require "#{File.dirname(__FILE__)}/api_models_v10"

class AV10 < MV10

  class TRestApi < TRestCommon::TRestApi

    def initialize(uri=nil, method="GET")
      super(uri, method)
      self.version = '1.0'
    end

    def compare(hash)
      raise_ex("Response 'type' Not found") if !defined?(hash['type'])
      raise_ex("Response 'type' mismatch " +
               "expected:#{self.response_type}, got:#{hash['type']}") if hash['type'] != self.response_type
      raise_ex("Response 'version' mismatch " +
               "expected:#{self.version}, got:#{hash['version']}") if hash['version'] != self.version
      raise_ex("Response 'status' incorrect " +
               "expected:#{self.response_status}, got:#{hash['status']}") if hash['status'] != self.response_status

      data = hash['data']
      case hash['type']
        when 'links'
          links_hash = { 'links' => data }
          obj = AV10::TBaseApi.to_obj(links_hash)
          self.response.compare(obj)
        when 'user'
          obj = AV10::TRestUser.to_obj(data)
          self.response.compare(obj)
        when 'environment'
          raise_ex("Environment response not a hash") unless data.kind_of?(Hash)
        when 'estimates'
          obj = AV10::TRestEstimates.to_obj(data)
          self.response.compare(obj)
        when 'application_estimates'
          data.each do |gear_hash|
            obj = AV10::TRestApplicationEstimate.to_obj(gear_hash)
          end
        when 'application_templates'
          data.each do |template_hash|
            obj = AV10::TRestApplicationTemplate.to_obj(template_hash)
          end
        when 'descriptor'
          # no-op
        when 'domain'
          obj = AV10::TRestDomain.to_obj(data)
          self.response.compare(obj)
        when 'domains'
          data.each do |dom_hash|
            obj = AV10::TRestDomain.to_obj(dom_hash)
          end
        when 'key'
          obj = AV10::TRestKey.to_obj(data)
          self.response.compare(obj)
        when 'keys'
          obj = AV10::TRestKey.to_obj(data[0])
          self.response.compare(obj)
        when 'application'
          obj = AV10::TRestApplication.to_obj(data)
          self.response.compare(obj)
        when 'applications'
          obj = AV10::TRestApplication.to_obj(data[0])
          self.response.compare(obj)
        when 'cartridge'
          obj = AV10::TRestCartridge.to_obj(data)
          self.response.compare(obj)
        when 'cartridges'
          data.each do |cart_hash|
            obj = AV10::TRestCartridge.to_obj(cart_hash)
            obj.valid
          end
        when 'gear'
          obj = AV10::TRestGear.to_obj(data)
          self.response.compare(obj)
        when 'gear_groups'
          data.each do |gear_group_hash|
            obj = AV10::TRestGearGroup.to_obj(gear_group_hash)
          end
        when 'gears'
          data.each do |gear_hash|
            obj = AV10::TRestGear.to_obj(gear_hash)
          end
        else
          raise_ex("Invalid Response type")
      end
    end
  end

  def self.rest_calls
    api_get = AV10::TRestApi.new("/rest/api")
    api_get.response = TBaseApi.new
    api_get.response_type = "links"

    environment_get = AV10::TRestApi.new("/rest/environment")
    environment_get.response_type = "environment"

    user_get = AV10::TRestApi.new("/rest/user")
    user_get.response = AV10::TRestUser.new
    user_get.response_type = "user"

    cartridge_list_get = AV10::TRestApi.new("/rest/cartridges")
    cartridge_list_get.response_type = "cartridges"

    estimates_list_get = AV10::TRestApi.new("/rest/estimates")
    estimates_list_get.response = AV10::TRestEstimates.new
    estimates_list_get.response_type = "estimates" 

    estimates_app_get = AV10::TRestApi.new("/rest/estimates/application")
    estimates_app_get.request.merge!({ 'id' => 'application', 'descriptor' => "--- \nName: TestApp1\nRequires: \n- php-5.4\n" })
    estimates_app_get.response = AV10::TRestApplicationEstimate.new
    estimates_app_get.response_type = "application_estimates"
     
    template_list_get = AV10::TRestApi.new("/rest/application_templates")
    template_list_get.response_type = "application_templates"

    domain_add_post = AV10::TRestApi.new("/rest/domains", "POST")
    dom_id = gen_uuid[0..9]
    domain_add_post.request['id'] = dom_id
    domain_add_post.response = AV10::TRestDomain.new(dom_id)
    domain_add_post.response_type = "domain"
    domain_add_post.response_status = "created"

    domains_list_get = AV10::TRestApi.new("/rest/domains")
    domains_list_get.response_type = "domains"

    domain_get = AV10::TRestApi.new("/rest/domains/#{dom_id}")
    domain_get.response = AV10::TRestDomain.new(dom_id)
    domain_get.response_type = "domain"

    domain_put = AV10::TRestApi.new("/rest/domains/#{dom_id}", "PUT")
    dom_id = gen_uuid[0..9]
    domain_put.request['id'] = dom_id
    domain_put.response = AV10::TRestDomain.new(dom_id)
    domain_put.response_type = "domain"

    keys_post = AV10::TRestApi.new("/rest/user/keys", "POST")
    kname, ktype, content = 'key1', 'ssh-rsa', 'abcdef'
    keys_post.request.merge!({ 'name' => kname, 'type' => ktype, 'content' => content })
    keys_post.response = AV10::TRestKey.new(kname, content, ktype)
    keys_post.response_type = "key"
    keys_post.response_status = "created"

    keys_list_get = AV10::TRestApi.new("/rest/user/keys")
    keys_list_get.response = AV10::TRestKey.new(kname, content, ktype)
    keys_list_get.response_type = "keys"

    keys_get = AV10::TRestApi.new("/rest/user/keys/#{kname}")
    keys_get.response = AV10::TRestKey.new(kname, content, ktype)
    keys_get.response_type = "key"

    keys_put = AV10::TRestApi.new("/rest/user/keys/#{kname}", "PUT")
    nktype, ncontent = 'ssh-dss', '12345'
    keys_put.request.merge!({ 'content' => ncontent, 'type' => nktype })
    keys_put.response = AV10::TRestKey.new(kname, ncontent, nktype) 
    keys_put.response_type = "key"

    app_post = AV10::TRestApi.new("/rest/domains/#{dom_id}/applications", "POST")
    app_name, app_type, app_scale, app_timeout = 'app1', 'php-5.4', true, 180
    app_post.request.merge!({ 'name' => app_name, 'cartridge' => app_type, 'scale' => app_scale })
    app_post.request_timeout = app_timeout
    app_post.response = AV10::TRestApplication.new(app_name, app_type, dom_id, app_scale)
    app_post.response_type = 'application'
    app_post.response_status = 'created'

    app_list_get = AV10::TRestApi.new("/rest/domains/#{dom_id}/applications")
    app_list_get.response = AV10::TRestApplication.new(app_name, app_type, dom_id, app_scale)
    app_list_get.response_type = 'applications'

    app_get = AV10::TRestApi.new("/rest/domains/#{dom_id}/applications/#{app_name}")
    app_get.response = AV10::TRestApplication.new(app_name, app_type, dom_id, app_scale)
    app_get.response_type = 'application'

    app_descriptor_get = AV10::TRestApi.new("/rest/domains/#{dom_id}/applications/#{app_name}/descriptor")
    app_descriptor_get.response_type = 'descriptor'

    app_start_post = AV10::TRestApi.new("/rest/domains/#{dom_id}/applications/#{app_name}/events", "POST")
    app_start_post.request['event'] = 'start'
    app_start_post.response = AV10::TRestApplication.new(app_name, app_type, dom_id, app_scale)
    app_start_post.response_type = "application"

    app_restart_post = AV10::TRestApi.new("/rest/domains/#{dom_id}/applications/#{app_name}/events", "POST")
    app_restart_post.request['event'] = 'restart'
    app_restart_post.response = AV10::TRestApplication.new(app_name, app_type, dom_id, app_scale)
    app_restart_post.response_type = "application"

    app_stop_post = AV10::TRestApi.new("/rest/domains/#{dom_id}/applications/#{app_name}/events", "POST")
    app_stop_post.request['event'] = 'stop'
    app_stop_post.response = AV10::TRestApplication.new(app_name, app_type, dom_id, app_scale)
    app_stop_post.response_type = "application"

    app_force_stop_post = AV10::TRestApi.new("/rest/domains/#{dom_id}/applications/#{app_name}/events", "POST")
    app_force_stop_post.request['event'] = 'force-stop'
    app_force_stop_post.response = AV10::TRestApplication.new(app_name, app_type, dom_id, app_scale)
    app_force_stop_post.response_type = "application"

    app_add_alias_post = AV10::TRestApi.new("/rest/domains/#{dom_id}/applications/#{app_name}/events", "POST")
    app_alias = 'myApp'
    app_add_alias_post.request.merge!({ 'event' => 'add-alias' , 'alias' => app_alias })
    app_add_alias_post.response = AV10::TRestApplication.new(app_name, app_type, dom_id, app_scale)
    app_add_alias_post.response_type = "application"

    app_remove_alias_post = AV10::TRestApi.new("/rest/domains/#{dom_id}/applications/#{app_name}/events", "POST")
    app_remove_alias_post.request.merge!({ 'event' => 'remove-alias' , 'alias' => app_alias })
    app_remove_alias_post.response = AV10::TRestApplication.new(app_name, app_type, dom_id, app_scale)
    app_remove_alias_post.response_type = "application"

    app_scale_up_post = AV10::TRestApi.new("/rest/domains/#{dom_id}/applications/#{app_name}/events", "POST")
    app_scale_up_post.request['event'] = 'scale-up'
    app_scale_up_post.response = AV10::TRestApplication.new(app_name, app_type, dom_id, app_scale)
    app_scale_up_post.response_type = "application"

    app_scale_down_post = AV10::TRestApi.new("/rest/domains/#{dom_id}/applications/#{app_name}/events", "POST")
    app_scale_down_post.request['event'] = 'scale-down'
    app_scale_down_post.response = AV10::TRestApplication.new(app_name, app_type, dom_id, app_scale)
    app_scale_down_post.response_type = "application"

    app_add_cart_post = AV10::TRestApi.new("/rest/domains/#{dom_id}/applications/#{app_name}/cartridges", "POST")
    embed_cart = 'mysql-5.1'
    app_add_cart_post.request.merge!({ 'name' => embed_cart, 'colocate_with' => nil })
    app_add_cart_post.response = AV10::TRestCartridge.new('embedded', embed_cart)
    app_add_cart_post.response_type = "cartridge"
    app_add_cart_post.response_status = "created"

    app_expose_port_post = AV10::TRestApi.new("/rest/domains/#{dom_id}/applications/#{app_name}/events", "POST")
    app_expose_port_post.request['event'] = 'expose-port'
    app_expose_port_post.response = AV10::TRestApplication.new(app_name, app_type, dom_id, app_scale)
    app_expose_port_post.response_type = "application"

    app_show_port_post = AV10::TRestApi.new("/rest/domains/#{dom_id}/applications/#{app_name}/events", "POST")
    app_show_port_post.request['event'] = 'show-port'
    app_show_port_post.response = AV10::TRestApplication.new(app_name, app_type, dom_id, app_scale)
    app_show_port_post.response_type = "application"

    app_gear_get = AV10::TRestApi.new("/rest/domains/#{dom_id}/applications/#{app_name}/gears")
    app_gear_get.response_type = 'gears'

    app_gear_groups_get = AV10::TRestApi.new("/rest/domains/#{dom_id}/applications/#{app_name}/gear_groups")
    app_gear_groups_get.response_type = 'gear_groups'

    app_conceal_port_post = AV10::TRestApi.new("/rest/domains/#{dom_id}/applications/#{app_name}/events", "POST")
    app_conceal_port_post.request['event'] = 'conceal-port'
    app_conceal_port_post.response = AV10::TRestApplication.new(app_name, app_type, dom_id, app_scale)
    app_conceal_port_post.response_type = "application"

    app_cart_list_get = AV10::TRestApi.new("/rest/domains/#{dom_id}/applications/#{app_name}/cartridges")
    app_cart_list_get.response = AV10::TRestCartridge.new('embedded', embed_cart)
    app_cart_list_get.response_type = "cartridges"

    app_cart_get = AV10::TRestApi.new("/rest/domains/#{dom_id}/applications/#{app_name}/cartridges/#{embed_cart}")
    app_cart_get.response = AV10::TRestCartridge.new('embedded', embed_cart)
    app_cart_get.response_type = "cartridge"

    app_cart_start_post = AV10::TRestApi.new("/rest/domains/#{dom_id}/applications/#{app_name}/cartridges/#{embed_cart}/events", "POST")
    app_cart_start_post.request['event'] = 'start'
    app_cart_start_post.response = AV10::TRestApplication.new(app_name, app_type, dom_id, app_scale)
    app_cart_start_post.response_type = "application"

    app_cart_restart_post = AV10::TRestApi.new("/rest/domains/#{dom_id}/applications/#{app_name}/cartridges/#{embed_cart}/events", "POST")
    app_cart_restart_post.request['event'] = 'restart'
    app_cart_restart_post.response = AV10::TRestApplication.new(app_name, app_type, dom_id, app_scale)
    app_cart_restart_post.response_type = "application"

    app_cart_reload_post = AV10::TRestApi.new("/rest/domains/#{dom_id}/applications/#{app_name}/cartridges/#{embed_cart}/events", "POST")
    app_cart_reload_post.request['event'] = 'reload'
    app_cart_reload_post.response = AV10::TRestApplication.new(app_name, app_type, dom_id, app_scale)
    app_cart_reload_post.response_type = "application"

    app_cart_stop_post = AV10::TRestApi.new("/rest/domains/#{dom_id}/applications/#{app_name}/cartridges/#{embed_cart}/events", "POST")
    app_cart_stop_post.request['event'] = 'stop'
    app_cart_stop_post.response = AV10::TRestApplication.new(app_name, app_type, dom_id, app_scale)
    app_cart_stop_post.response_type = "application"

    app_cart_delete = AV10::TRestApi.new("/rest/domains/#{dom_id}/applications/#{app_name}/cartridges/#{embed_cart}", "DELETE")
    app_cart_delete.response = AV10::TRestApplication.new(app_name, app_type, dom_id, app_scale)
    app_cart_delete.response_type = "application"

    app_delete = AV10::TRestApi.new("/rest/domains/#{dom_id}/applications/#{app_name}", "DELETE")

    keys_delete = AV10::TRestApi.new("/rest/user/keys/#{kname}", "DELETE")

    domain_delete = AV10::TRestApi.new("/rest/domains/#{dom_id}", "DELETE")

    rest_api_calls = [
                      api_get,
                      #environment_get,
                      user_get,
                      cartridge_list_get,
                      #estimates_list_get,
                      #estimates_app_get,
                      #template_list_get,
                      domain_add_post,
                      domains_list_get,
                      domain_get,
                      domain_put,
                      keys_post,
                      keys_list_get,
                      keys_get,
                      #keys_put,
                      app_post,
                      app_list_get,
                      app_get,
                      app_descriptor_get,
                      app_start_post,
                      app_restart_post,
                      app_stop_post,               
                      app_force_stop_post,
                      app_add_alias_post, 
                      app_remove_alias_post, 
                      app_scale_up_post, 
                      app_scale_down_post,
                      app_add_cart_post, 
                      app_expose_port_post, 
                      #app_show_port_post,
                      #app_gear_get, 
                      app_gear_groups_get,
                      app_conceal_port_post,
                      app_cart_list_get, 
                      app_cart_get,
                      app_cart_start_post, 
                      app_cart_restart_post, 
                      app_cart_reload_post, 
                      app_cart_stop_post, 
                      app_cart_delete, 
                      app_delete,
                      keys_delete,
                      domain_delete
                    ]
    return rest_api_calls
  end
end
