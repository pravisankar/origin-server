ENV["TEST_NAME"] = "CloudUserUnitTest"
require "test_helper"
require 'stickshift-controller'

class CloudUserUnitTest < ActiveSupport::TestCase
  def setup
    system "/usr/bin/mongo localhost/broker_test --eval 'db.addUser(\"stickshift\", \"mooo\")' 2>&1 > /dev/null"
  end

  test "validation of login" do
    invalid_chars = '"$^<>|%/;:,\*=~'
    invalid_chars.length.times do |i|
      user = CloudUser.new(login: "test#{invalid_chars[i].chr}login")
      assert user.invalid?
    end
    
    user = CloudUser.new(login: "kraman@redhat.com")
    assert user.valid?
  end
  
  test "validation of ssh key" do
    invalid_chars = '"$^<>|%;:,\*~'
    invalid_chars.length.times do |i|
      key = SshKey.new(name: "ssh#{invalid_chars[i].chr}key", type: "ssh-rsa", content: "abcd")
      assert key.invalid?
    end
    
    key = SshKey.new(name: "sshkey", type: "ssh-rsa", content: "abcd")
    assert key.valid?
  end
  
  def teardown
  end
end
