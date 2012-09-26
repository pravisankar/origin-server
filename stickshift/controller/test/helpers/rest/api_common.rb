$nolinks = false

class TRestCommon
  class TBaseObj
    def self.to_obj(hash)
      obj = self.new
      obj.attributes=hash
      obj
    end

    def attributes=(hash)
      return nil unless hash

      self.instance_variables.each do |var|
        next if $nolinks && (var[1..-1] == 'links')
        raise_ex("Object does NOT contain required variable '#{var[1..-1]}'") unless hash.include?(var[1..-1])
      end
      hash.each do |key,value|
        self.send("#{key}=",value)
      end
      self
    end
  end

  class TRestApi < TBaseObj
    attr_accessor :uri, :method, :request, :request_timeout, :response, :response_type, :response_status, :version

    def initialize(uri=nil, method="GET")
      self.uri = uri
      self.method = method
      self.request = { 'nolinks' => $nolinks }
      self.request_timeout = 120  # 120 secs

      self.response = nil
      self.response_type = nil
      self.response_status = 'ok'
      self.version = nil
    end

    def compare(obj)
      raise_ex("Sub-Classes must implement this method!")
    end
  end

  class TParam < TBaseObj
    attr_accessor :name, :type, :description, :valid_options, :invalid_options

    def initialize(name=nil, type=nil, valid_options=[], invalid_options=[])
      self.name = name
      self.type = type
      self.description = nil
      self.valid_options = valid_options || Array.new
      self.valid_options = [self.valid_options] unless self.valid_options.kind_of?(Array)
      self.invalid_options = invalid_options || Array.new
      self.invalid_options = [self.invalid_options] unless self.invalid_options.kind_of?(Array)
    end

    def compare(obj)
      if (self.name != obj.name) ||
         (self.type != obj.type) ||
         ((self.valid_options.to_s.length > 0) && (self.valid_options.size > obj.valid_options.size)) ||
         ((self.invalid_options.to_s.length > 0) && (self.invalid_options.size > obj.invalid_options.size))
        raise_ex("Link Param '#{self.name}' inconsistent")
      end
      self.valid_options.each do |opt|
        raise_ex("Link Param option '#{opt}' NOT found") unless obj.valid_options.include?(opt)
      end if self.valid_options.to_s.length > 0
    end
  end

  class TOptionalParam < TBaseObj
    attr_accessor :name, :type, :description, :valid_options, :default_value

    def initialize(name=nil, type=nil, valid_options=[], default_value=nil)
      self.name = name
      self.type = type
      self.description = nil
      valid_options = [valid_options] unless valid_options.kind_of?(Array)
      self.valid_options = valid_options || Array.new
      self.default_value = default_value
    end

    def compare(obj)
      if (self.name != obj.name) ||
         (self.type != obj.type) ||
         ((self.valid_options.to_s.length > 0) && (self.valid_options.size > obj.valid_options.size)) ||
         (self.default_value != obj.default_value)
        raise_ex("Link Optional Param '#{self.name}' inconsistent")
      end
      self.valid_options.each do |opt|
        raise_ex("Link Param option '#{opt}' NOT found") unless obj.valid_options.include?(opt)
      end if self.valid_options.to_s.length > 0
    end
  end

  class TLink < TBaseObj
    attr_accessor :rel, :method, :href, :required_params, :optional_params
 
    def initialize(method=nil, href=nil, required_params=nil, optional_params=nil)
      self.rel = nil 
      self.method = method
      self.href = href.to_s
      self.required_params = required_params || Array.new
      self.optional_params = optional_params || Array.new
    end

    def self.to_obj(hash)
      obj = super(hash)
      obj_req_params = []
      obj.required_params.each do |param|
        p = TParam.to_obj(param)
        obj_req_params.push(p)
      end if obj.required_params
      obj.required_params = obj_req_params
      obj_opt_params = []
      obj.optional_params.each do |param|
        p = TOptionalParam.to_obj(param)
        obj_opt_params.push(p)
      end if obj.optional_params
      obj.optional_params = obj_opt_params
      obj
    end

    def compare(obj)
      href_size = self.href.size
      if (self.method != obj.method) || (self.href !=  obj.href[-href_size..-1])
        raise_ex("Link 'method' or 'href' failed to match")
      end

      if self.required_params.empty?
        raise_ex("New 'required_params' found for Link") if !obj.required_params.empty?
      else
        raise_ex("Missing 'required_params' found for Link") if obj.required_params.empty?
        req_params = self.required_params.sort { |a,b| a.name.downcase <=> b.name.downcase }
        obj_req_params = obj.required_params.sort { |a,b| a.name.downcase <=> b.name.downcase }
        for i in 0..req_params.size-1
          req_params[i].compare(obj_req_params[i])
        end
      end

      if self.optional_params.empty?
        raise_ex("New 'optional_params' found for Link") if !obj.optional_params.empty?
      else
        raise_ex("Missing 'optional_params' found for Link") if obj.optional_params.empty?
        opt_params = self.optional_params.sort { |a,b| a.name.downcase <=> b.name.downcase }
        obj_opt_params = obj.optional_params.sort { |a,b| a.name.downcase <=> b.name.downcase }
        for i in 0..opt_params.size-1
          opt_params[i].compare(obj_opt_params[i])
        end
      end
    end
  end

  class TBaseLinkObj < TBaseObj
    def self.to_obj(hash)
      return nil if hash.to_s.length == 0

      obj = super(hash)
      if defined?(obj.links)
        obj_links = {}
        obj.links.each do |lname, link_hash|
          obj_links[lname] = TLink.to_obj(link_hash)
        end if obj.links
        obj.links = obj_links
      end
      obj
    end

    def compare(obj)
      if defined?(obj.links)
        self.links.keys.each do |lname|
          raise_ex("Link '#{lname}' missing") unless obj.links[lname]
          self.links[lname].compare(obj.links[lname])
        end if self.links && self.links.keys
      end
    end
  end
end

def raise_ex(msg, *kw)
  raise Exception.new(msg, *kw)
end

def gen_uuid
  File.open("/proc/sys/kernel/random/uuid", "r") do |file|
    file.gets.strip.gsub("-","")
  end
end

