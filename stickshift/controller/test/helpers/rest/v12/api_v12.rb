require "#{File.dirname(__FILE__)}/api_models_v12"

class AV12 < MV12

  class TRestApi < TRestCommon::TRestApi

    def initialize(uri=nil, method="GET")
      super(uri, method)
      self.version = '1.2'
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
          obj = AV12::TRestUser.to_obj(data)
          self.response.compare(obj)
        when 'domain'
          obj = AV12::TRestDomain.to_obj(data)
          self.response.compare(obj)
        when 'key'
          obj = AV12::TRestKey.to_obj(data)
          self.response.compare(obj)
        when 'application'
          obj = AV12::TRestApplication.to_obj(data)
          self.response.compare(obj)
        else
          raise_ex("Invalid Response type")
      end
    end
  end

  def self.rest_calls
    user_get = AV12::TRestApi.new("/rest/user")
    user_get.response = AV12::TRestUser.new
    user_get.response_type = "user"

    domain_add_post = AV12::TRestApi.new("/rest/domains", "POST")
    dom_id = gen_uuid[0..9]
    domain_add_post.request['id'] = dom_id
    domain_add_post.response = AV12::TRestDomain.new(dom_id)
    domain_add_post.response_type = "domain"
    domain_add_post.response_status = "created"

    keys_post = AV12::TRestApi.new("/rest/user/keys", "POST")
    kname, ktype, content = 'key1', 'ssh-rsa', 'abcdef'
    keys_post.request.merge!({ 'name' => kname, 'type' => ktype, 'content' => content })
    keys_post.response = AV12::TRestKey.new(kname, content, ktype)
    keys_post.response_type = "key"
    keys_post.response_status = "created"

    app_post = AV12::TRestApi.new("/rest/domains/#{dom_id}/applications", "POST")
    app_name, app_type, app_scale, app_timeout = 'app1', 'php-5.4', true, 180
    app_post.request.merge!({ 'name' => app_name, 'cartridge' => app_type, 'scale' => app_scale })
    app_post.request_timeout = app_timeout
    app_post.response = AV12::TRestApplication.new(app_name, app_type, dom_id, app_scale)
    app_post.response_type = 'application'
    app_post.response_status = 'created'

    app_delete = AV12::TRestApi.new("/rest/domains/#{dom_id}/applications/#{app_name}", "DELETE")

    keys_delete = AV12::TRestApi.new("/rest/user/keys/#{kname}", "DELETE")

    domain_delete = AV12::TRestApi.new("/rest/domains/#{dom_id}", "DELETE")

    rest_api_calls = [
                      user_get,
                      domain_add_post,
                      keys_post,
                      app_post,
                      app_delete,
                      keys_delete,
                      domain_delete
                    ]
    return rest_api_calls
  end
end
