require 'action_dispatch/http/mime_types'
module Mime
  class Type
    class << self
      def lookup(string)
         LOOKUP[string.split(';').first]
       end
    end
  end
end

# See https://github.com/rails/rails/issues/348
module ActionDispatch
  class Request < Rack::Request
    def patch?
      HTTP_METHOD_LOOKUP[request_method] == :patch
    end
    
    delegate :patch, :to => :request
  end
  
  module Routing  
    HTTP_METHODS = [:get, :head, :post, :put, :delete, :options, :patch]
    
    class Mapper
      def patch(*args, &block)
        map_method(:patch, *args, &block)
      end
    end
  end
end

class StickShift::Responder < ::ActionController::Responder
  ACTIONS_FOR_VERBS	=	{ :post => :new, :put => :edit, :patch => :update }
  def api_behavior(error)
    raise error unless resourceful?
    status = resource.each{ |r| break(r[:status]) if r.class == Hash && r.has_key?(:status) }
    display resource[0], status: status
  end
end

module StickShift
  class Engine < ::Rails::Engine
  end
end
