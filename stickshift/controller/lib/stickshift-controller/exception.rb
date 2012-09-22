class StickShift::GearLimitReachedException < StickShift::SSException; end

class StickShift::ScaleConflictException < StickShift::SSException
  attr_accessor :cart, :comp, :requested_min, :requested_max, :comp_min, :comp_max
  
  def initialize(cart, comp, requested_min, requested_max, comp_min, comp_max)
    self.cart = cart
    self.comp = comp
    self.requested_min = requested_min
    self.requested_max = requested_max
    self.comp_min = comp_min
    self.comp_max = comp_max   
    super()
  end
end

class StickShift::UnfulfilledRequirementException < StickShift::SSException
  attr_accessor :feature
  
  def initialize(feature)
    self.feature = feature
    super
  end
end
class StickShift::ApplicationValidationException < StickShift::SSException
  attr_accessor :app
  
  def initialize(app)
    self.app = app
    super()
  end
end