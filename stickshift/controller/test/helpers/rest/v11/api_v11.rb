require "#{File.dirname(__FILE__)}/api_models_v11"

class AV11 < MV11

  class TRestApi < TRestCommon::TRestApi

    def initialize(uri=nil, method="GET")
      super(uri, method)
      self.version = '1.1'
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
        when 'user'
          obj = AV11::TRestUser.to_obj(data)
          self.response.compare(obj)
        when 'domain'
          obj = AV11::TRestDomain.to_obj(data)
          self.response.compare(obj)
        when 'key'
          obj = AV11::TRestKey.to_obj(data)
          self.response.compare(obj)
        when 'application'
          obj = AV11::TRestApplication.to_obj(data)
          self.response.compare(obj)
        when 'cartridge'
          obj = AV11::TRestCartridge.to_obj(data)
          self.response.compare(obj)
        when 'cartridges'
          data.each do |cart_hash|
            obj = AV11::TRestCartridge.to_obj(cart_hash)
            obj.valid
          end
        else
          raise_ex("Invalid Response type")
      end
    end
  end

  def self.rest_calls
    user_get = AV11::TRestApi.new("/rest/user")
    user_get.response = AV11::TRestUser.new
    user_get.response_type = "user"

    cartridge_list_get = AV11::TRestApi.new("/rest/cartridges")
    cartridge_list_get.response_type = "cartridges"

    domain_add_post = AV11::TRestApi.new("/rest/domains", "POST")
    dom_id = gen_uuid[0..9]
    domain_add_post.request['id'] = dom_id
    domain_add_post.response = AV11::TRestDomain.new(dom_id)
    domain_add_post.response_type = "domain"
    domain_add_post.response_status = "created"

    keys_post = AV11::TRestApi.new("/rest/user/keys", "POST")
    kname, ktype, content = 'key1', 'ssh-rsa', 'abcdef'
    keys_post.request.merge!({ 'name' => kname, 'type' => ktype, 'content' => content })
    keys_post.response = AV11::TRestKey.new(kname, content, ktype)
    keys_post.response_type = "key"
    keys_post.response_status = "created"

    app_post = AV11::TRestApi.new("/rest/domains/#{dom_id}/applications", "POST")
    app_name, app_type, app_scale, app_timeout = 'app1', "php-#{$php_version}", true, 180
    app_post.request.merge!({ 'name' => app_name, 'cartridge' => app_type, 'scale' => app_scale })
    app_post.request_timeout = app_timeout
    app_post.response = AV11::TRestApplication.new(app_name, app_type, dom_id, app_scale)
    app_post.response_type = 'application'
    app_post.response_status = 'created'

    app_add_cart_post = AV11::TRestApi.new("/rest/domains/#{dom_id}/applications/#{app_name}/cartridges", "POST")
    embed_cart = 'mysql-5.1'
    app_add_cart_post.request.merge!({ 'name' => embed_cart, 'colocate_with' => nil })
    app_add_cart_post.response = AV11::TRestCartridge.new('embedded', embed_cart)
    app_add_cart_post.response_type = "cartridge"
    app_add_cart_post.response_status = "created"

    app_cart_list_get = AV11::TRestApi.new("/rest/domains/#{dom_id}/applications/#{app_name}/cartridges")
    app_cart_list_get.response = AV11::TRestCartridge.new('embedded', embed_cart)
    app_cart_list_get.response_type = "cartridges"

    app_cart_get = AV11::TRestApi.new("/rest/domains/#{dom_id}/applications/#{app_name}/cartridges/#{embed_cart}")
    app_cart_get.response = AV11::TRestCartridge.new('embedded', embed_cart)
    app_cart_get.response_type = "cartridge"

    app_cart_delete = AV11::TRestApi.new("/rest/domains/#{dom_id}/applications/#{app_name}/cartridges/#{embed_cart}", "DELETE")
    app_cart_delete.response = AV11::TRestApplication.new(app_name, app_type, dom_id, app_scale)
    app_cart_delete.response_type = "application"

    app_delete = AV11::TRestApi.new("/rest/domains/#{dom_id}/applications/#{app_name}", "DELETE")

    keys_delete = AV11::TRestApi.new("/rest/user/keys/#{kname}", "DELETE")

    domain_delete = AV11::TRestApi.new("/rest/domains/#{dom_id}", "DELETE")

    rest_api_calls = [
                      user_get,
                      cartridge_list_get,
                      domain_add_post,
                      keys_post,
                      app_post,
                      app_add_cart_post, 
                      app_cart_list_get, 
                      app_cart_get,
                      app_cart_delete, 
                      app_delete,
                      keys_delete,
                      domain_delete
                    ]
    return rest_api_calls
  end
end
