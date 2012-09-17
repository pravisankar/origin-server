ENV["RAILS_ENV"] = "test"
ENV['COVERAGE'] = 'true'

require File.expand_path('../../config/environment', __FILE__)
require 'rails/test_help'

@engines = Rails.application.railties.engines.map { |e| e.config.root.to_s }

def gen_uuid
  %x[/usr/bin/uuidgen].gsub('-', '').strip 
end
