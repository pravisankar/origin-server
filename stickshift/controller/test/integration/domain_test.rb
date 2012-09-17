ENV["TEST_NAME"] = "DomainTest"
require "test_helper"
require 'stickshift-controller'

class DomainTest < ActiveSupport::TestCase

  test "create" do
    login = "user_" + gen_uuid
    cu = CloudUser.new(login: login)
    assert cu.valid?
    cu.with(safe: true).save
    
    ns = "namespace_" + gen_uuid
    orig_d = Domain.new(namespace: ns[1..15], owner: cu)
    assert orig_d.valid?
    orig_d.with(safe: true).save
    
    d = Domain.find(orig_d.id)
    assert_equal_domains(orig_d, d)
  end
  
  def assert_equal_domains(domain1, domain2)
    assert_equal(domain1.namespace, domain2.namespace)
    assert_equal(domain1.id, domain2.id)
    assert_equal(domain1.owner.login, domain2.owner.login)
  end

end
