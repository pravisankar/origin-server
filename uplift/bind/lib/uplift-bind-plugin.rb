unless defined? StickShift
  module StickShift
    class DnsService
    end
  end
  require "uplift-bind-plugin/uplift/bind_plugin.rb"
else
  require "uplift-bind-plugin/uplift/bind_plugin.rb"
  StickShift::DnsService.provider=Uplift::BindPlugin
end