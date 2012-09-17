ENV["TEST_NAME"] = "CloudUserIntegrationTest"
require "test_helper"
require 'stickshift-controller'
require 'minitest/autorun'

class CloudUserIntegrationTest < MiniTest::Unit::TestCase
  include Rails.application.routes.url_helpers
  
  def create
    login = "user_" + gen_uuid
    orig_cu = CloudUser.new(login: login)
    orig_cu.save
    cu = CloudUser.find_by(login: login)
    assert_equal_users(orig_cu, cu)
  end
  
  def find_by_uuid
    login = "user_" + gen_uuid
    orig_cu = CloudUser.new(login: login)
    orig_cu.save
    cu = CloudUser.find(orig_cu.id)
    assert_equal_users(orig_cu, cu)
  end
  
  def assert_equal_users(user1, user2)
    assert_equal(user1.login, user2.login)
    assert_equal(user1.uuid, user2.uuid)
  end
  
  def teardown
  end
end
