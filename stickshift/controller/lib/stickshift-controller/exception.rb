class StickShift::GearLimitReachedException < StickShift::SSException; end
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