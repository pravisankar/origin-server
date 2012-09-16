class CartridgesController < BaseController
  respond_to :xml, :json
  before_filter :check_version
  
  def show
    index
  end
  
  # GET /cartridges
  def index
    type = params[:id]
    log_action(@request_id, @cloud_user._id, @cloud_user.login, "LIST_CARTRIDGES", true, "List #{type.nil? ? 'all' : type} cartridges")
    
    if type.nil?
      cartridges = CartridgeCache.cartridges
    else
      cartridges = CartridgeCache.cartridges.keep_if{ |c| c.categories.include?(type) }
    end
    
    render_success(:ok, "cartridges", cartridges.map{|c| RestCartridge11.new(nil,c,nil,nil,get_url,nolinks)}, "LIST_CARTRIDGES", "List #{type.nil? ? 'all' : type} cartridges") 
  end
end
