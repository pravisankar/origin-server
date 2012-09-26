ENV["TEST_NAME"] = "RestApiNolinksTest"
require 'test_helper'
require "#{File.dirname(__FILE__)}/../helpers/rest/api_common"
$nolinks = true
require "#{File.dirname(__FILE__)}/../helpers/rest/v10/api_v10"
require "#{File.dirname(__FILE__)}/../helpers/rest/v11/api_v11"
require "#{File.dirname(__FILE__)}/../helpers/rest/v12/api_v12"
require 'json'

class RestApiNolinksTest < ActionController::IntegrationTest
  REST_CALLS = [ 
    AV10.rest_calls,
    AV11.rest_calls,
    AV12.rest_calls
  ]

  $user = 'test-user' + gen_uuid[0..9]
  $password = 'nopass'
  
  def setup
    `mongo broker_test --eval 'db.auth_user.drop()'`
    `mongo broker_test --eval 'db.auth_user.update({"user":"admin"}, {"user":"admin","password_hash":"2a8462d93a13e51387a5e607cbd1139f"}, true)'`
    accnt = UserAccount.new(user: $user, password: $password)
    accnt.save
    @env=Hash.new
    @env["HTTP_ACCEPT"] = "application/json; version=1.0"
    @env["HTTP_AUTHORIZATION"] = ActionController::HttpAuthentication::Basic.encode_credentials($user, $password)
  end
  
  test "rest noapi api" do
    #register_user if registration_required?
    REST_CALLS.each do |rest_version|
      rest_version.each do |rest_api|
        puts "#{rest_api.method}  #{rest_api.uri}  #{rest_api.request}"
        
        if rest_api.version
          @env["HTTP_ACCEPT"] = "application/json; version=#{rest_api.version}"
        else
          @env["HTTP_ACCEPT"] = "application/json"
        end
        
        rest_api.request["nolinks"] = true
        case rest_api.method
        when "GET"
          get rest_api.uri, rest_api.request, @env
        when "POST"
          post rest_api.uri, rest_api.request, @env
        when "PUT"
          put rest_api.uri, rest_api.request, @env
        when "DELETE"
          delete rest_api.uri, rest_api.request, @env
        end
        
        response = @response.body
        # puts "RSP => #{response}"
        if response.to_s.length != 0
          response_json = JSON.parse(response)
          rest_api.compare(response_json)
        end
      end
    end
  end
end
