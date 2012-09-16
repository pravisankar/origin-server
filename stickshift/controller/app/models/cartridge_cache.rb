# Cache of cartridge manifest metadata. Used to reduce the number of calls 
# to the Node to retrieve cartridge information.
class CartridgeCache
  # Helper method to maintain cached informtaion
  # 
  # == Parameters:
  # key::
  #   Cache key
  # opts::
  #   Cache options
  # block::
  #   Code block to run and cache output
  #
  # == Returns:
  # Cached output of code block
  def self.get_cached(key, opts={})
    unless Rails.configuration.action_controller.perform_caching
      if block_given?
        return yield
      end
    end

    val = Rails.cache.read(key)
    unless val
      if block_given?
        val = yield
        if val
          Rails.cache.write(key, val, opts)
        end
      end
    end

    return val
  end

  # Returns an Array of Cartridge objects
  def self.cartridges
    get_cached("all_cartridges", :expires_in => 1.day) {ApplicationContainerProxy.find_one().get_available_cartridges}
  end

  # Returns an Array of cartridge names.
  #
  # == Parameters:
  # cart_type::
  #   Specify to return only names of cartridges which have specified cartridge categories
  def self.cartridge_names(cart_type=nil)
    cartridges.dup.delete_if{ |cart| !cart_type.nil? and !cart.categories.include?(cart_type) }.map{ |cart| cart.name }
  end
  
  def self.find_cartridge_by_category(cat)
    get_cached("cartridges_by_cat_#{cat}", :expires_in => 1.day) {cartridges.delete_if{|cart| !cart.categories.include?(cat) }}
  end

  # Returns the first cartridge that provides the specified feature.
  # @note This method matches both features provided by the cartridge as well as the cartridge name.
  #
  # == Parameters:
  # feature::
  #   Name of feature to look for.
  def self.find_cartridge(feature)
    carts = self.cartridges
    carts.each do |cart|
      return cart if cart.features.include?(feature)
      return cart if cart.name == feature
    end
    return nil
  end
end
