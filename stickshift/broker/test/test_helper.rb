ENV["RAILS_ENV"] = "test"
ENV['COVERAGE'] = 'true'

require File.expand_path('../../config/environment', __FILE__)
require 'rails/test_help'

@engines = Rails.application.railties.engines.map { |e| e.config.root.to_s }
$php_version="5.4"

def gen_uuid
  %x[/usr/bin/uuidgen].gsub('-', '').strip 
end

def create_auth_service_account(username, password)
  if StickShift::AuthService.instance.class.to_s == "Swingshift::MongoAuthService"
    accnt = UserAccount.new(user: username, password: password)
    accnt.save
  end
end

def setup_auth_service
  if StickShift::AuthService.instance.class.to_s == "Swingshift::MongoAuthService"
    `mongo broker_test --eval 'db.auth_user.drop()'`
    `mongo broker_test --eval 'db.auth_user.update({"user":"admin"}, {"user":"admin","password_hash":"2a8462d93a13e51387a5e607cbd1139f"}, true)'`
  end
end