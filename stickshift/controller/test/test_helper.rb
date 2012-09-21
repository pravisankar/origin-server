ENV["RAILS_ENV"] = "test"
ENV['COVERAGE'] = 'true'

require File.expand_path("../dummy/config/environment.rb",  __FILE__)
require "rails/test_help"

@engines = Rails.application.railties.engines.map { |e| e.config.root.to_s }

Rails.backtrace_cleaner.remove_silencers!

def gen_uuid
  %x[/usr/bin/uuidgen].gsub('-', '').strip 
end

def gen_uuid
  %x[/usr/bin/uuidgen].gsub('-', '').strip
end
