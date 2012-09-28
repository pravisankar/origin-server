require 'test_helper'
ENV["TEST_NAME"] = "SubUserTest"

class SubUserTest < ActionDispatch::IntegrationTest
  def setup
    @random = rand(1000000)
    @username = "parent#{@random}"
    @password = 'nopass'
    
    setup_auth_service()
    create_auth_service_account(@username, @password)

    @headers = Hash.new
    @headers["HTTP_ACCEPT"] = "application/json"
    @headers["HTTP_AUTHORIZATION"] = ActionController::HttpAuthentication::Basic.encode_credentials(@username, @password)
  end

  def test_normal_auth_success
    get "rest/domains.json", nil, @headers
    assert_equal 200, status
  end

  def test_subaccount_role_failure_parent_user_missing
    @headers["X-Impersonate-User"] = "subuser#{@random}"
    get "rest/domains.json", nil, @headers
    assert_equal 401, status
  end

  def test_subaccount_role_failure
    get "rest/domains.json", nil, @headers
    assert_equal 200, status

    @headers["X-Impersonate-User"] = "subuser#{@random}"
    get "rest/domains.json", nil, @headers
    assert_equal 401, status
  end

  def test_subaccount_role_success
    get "rest/domains.json", nil, @headers
    assert_equal 200, status

    user = CloudUser.find_by(login: @username)
    user.capabilities_will_change!
    user.capabilities['subaccounts'] = true
    user.save

    @headers["X-Impersonate-User"] = "subuser#{@random}"
    get "rest/domains.json", nil, @headers
    assert_equal 200, status
  end

  def test_delete_subaccount
    get "rest/domains.json", nil, @headers
    assert_equal 200, status

    delete "rest/user.json", nil, @headers
    assert_equal 403, status

    user = CloudUser.find_by(login: @username)
    user.capabilities_will_change!
    user.capabilities['subaccounts'] = true
    user.save

    subaccount_user = "subuser#{@random}"
    @headers["X-Impersonate-User"] = subaccount_user
    get "rest/domains.json", nil, @headers
    assert_equal 200, status

    subaccount_password = "pass"
    create_auth_service_account(subaccount_user, subaccount_password)
    
    @headers2 = Hash.new
    @headers2["HTTP_ACCEPT"] = "application/json"
    @headers2["HTTP_AUTHORIZATION"] = ActionController::HttpAuthentication::Basic.encode_credentials(subaccount_user, subaccount_password)
    domain_name = "namespace#{@random}"
    post "rest/domains.json", { :id => domain_name }, @headers2
    assert_equal 201, status

    delete "rest/user.json", nil, @headers2
    assert_equal 422, status

    delete "rest/domains/#{domain_name}.json", nil, @headers2
    assert_equal 204, status

    delete "rest/user.json", nil, @headers2
    assert_equal 204, status
  end

  def test_access_someone_elses_subaccount
    get "rest/domains.json", nil, @headers
    assert_equal 200, status

    user = "#{@username}xyz"
    password = "pass"
    create_auth_service_account(user, password)    
    
    @headers2 = @headers.clone
    @headers2["HTTP_AUTHORIZATION"] = ActionController::HttpAuthentication::Basic.encode_credentials(user, password)
    get "rest/domains.json", nil, @headers2
    assert_equal 200, status

    user1 = CloudUser.find_by(login: @username)
    user1.capabilities_will_change!
    user1.capabilities['subaccounts'] = true
    user1.save
    user2 = CloudUser.find_by(login: user)
    user2.capabilities_will_change!
    user2.capabilities['subaccounts'] = true
    user2.save

    @headers["X-Impersonate-User"] = "subuser#{@random}"
    get "rest/domains.json", nil, @headers
    assert_equal 200, status

    @headers2["X-Impersonate-User"] = "subuser#{@random}"
    get "rest/domains.json", nil, @headers2
    assert_equal 401, status
  end

  def test_subaccount_inherit_gear_sizes
    get "rest/domains.json", nil, @headers
    assert_equal 200, status

    user = CloudUser.find_by(login: @username)
    user.capabilities_will_change!
    user.capabilities['gear_sizes'].push("medium")
    user.capabilities['subaccounts'] = true
    user.capabilities['inherit_on_subaccounts'] = ["gear_sizes"]
    user.save

    @headers["X-Impersonate-User"] = "subuser#{@random}"
    get "rest/domains.json", nil, @headers
    assert_equal 200, status

    subuser = CloudUser.find_by(login: "subuser#{@random}")
    assert_equal 2, subuser.capabilities["gear_sizes"].size
    assert_equal ["medium", "small"], subuser.capabilities["gear_sizes"].sort

    user = CloudUser.find_by(login: @username)
    user.capabilities_will_change!
    user.capabilities['gear_sizes'].delete("medium")
    user.save

    subuser = CloudUser.find_by(login: "subuser#{@random}")
    assert_equal 1, subuser.capabilities["gear_sizes"].size
    assert_equal "small", subuser.capabilities["gear_sizes"][0]
  end

  def teardown
  end
end
