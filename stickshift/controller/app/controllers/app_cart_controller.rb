class AppCartController < BaseController
  respond_to :xml, :json
  before_filter :authenticate, :check_version

  # GET /domains/[domain_id]/applications/[application_id]/cartridges
  def index
    domain_id = params[:domain_id]
    id = params[:application_id]
    
    begin
      domain = Domain.find_by(owner: @cloud_user, namespace: domain_id)
    rescue Mongoid::Errors::DocumentNotFound
      return render_error(:not_found, "Domain #{domain_id} not found", 127, "LIST_APP_CARTRIDGES")
    end
    
    begin
      application = Application.find_by(domain: domain, name: id)
      group_instances = application.group_instances_with_scale

      cartridges = []
      group_instances.each do |group_instance|
        component_instances = group_instance.all_component_instances
        component_instances.each do |component_instance|
          cartridges << get_rest_cartridge(application, component_instance, group_instances, application.group_overrides)
        end
      end
      
      render_success(:ok, "cartridges", cartridges, "LIST_APP_CARTRIDGES", "Listing cartridges for application #{id} under domain #{domain_id}")
    rescue Mongoid::Errors::DocumentNotFound
      return render_error(:not_found, "Application '#{id}' not found for domain '#{domain_id}'", 101, "LIST_APP_CARTRIDGES")
    end
  end
  
  def update_scale
    domain_id = params[:domain_id]
    application_id = params[:application_id]
    id = params[:id]
    
    scales_from = Integer(params[:scales_from]) rescue nil
    scales_to = Integer(params[:scales_to]) rescue nil
    additional_storage = Integer(params[:additional_storage]) rescue nil
    
    begin
      domain = Domain.find_by(owner: @cloud_user, namespace: domain_id)
    rescue Mongoid::Errors::DocumentNotFound
      return render_error(:not_found, "Domain #{domain_id} not found", 127, "SHOW_APP_CARTRIDGE")
    end
    
    begin
      application = Application.find_by(domain: domain, name: application_id)
      component_instance = application.component_instances.find_by(cartridge_name: id)
      
      application.update_component_limits(component_instance, scale_from, scale_to, additional_storage)
      cartridge = RestCartridge11.new(nil,CartridgeCache.find_cartridge(comp.cartridge_name),application,comp,get_url,nolinks)
    
      return render_success(:ok, "cartridge", cartridge, "SHOW_APP_CARTRIDGE", "Showing cartridge #{id} for application #{application_id} under domain #{domain_id}")
    rescue Mongoid::Errors::DocumentNotFound
      return render_error(:not_found, "Application '#{application_id}' not found for domain '#{domain_id}'", 101, "SHOW_APP_CARTRIDGE")
    end
    
    return render_success(:ok, "cartridge", [], "PATCH_APP_CARTRIDGE", "")  
  end
  
  # GET /domains/[domain_id]/applications/[application_id]/cartridges/[cartridge_id]
  def show
    domain_id = params[:domain_id]
    application_id = params[:application_id]
    id = params[:id]
    
    begin
      domain = Domain.find_by(owner: @cloud_user, namespace: domain_id)
    rescue Mongoid::Errors::DocumentNotFound
      return render_error(:not_found, "Domain #{domain_id} not found", 127, "SHOW_APP_CARTRIDGE")
    end
    
    begin
      application = Application.find_by(domain: domain, name: application_id)
      component_instance = application.component_instances.find_by(cartridge_name: id)
      cartridge = get_rest_cartridge(application, component_instance, application.group_instances_with_scale, application.group_overrides)
      return render_success(:ok, "cartridge", cartridge, "SHOW_APP_CARTRIDGE", "Showing cartridge #{id} for application #{application_id} under domain #{domain_id}")
    rescue Mongoid::Errors::DocumentNotFound
      return render_error(:not_found, "Application '#{application_id}' not found for domain '#{domain_id}'", 101, "SHOW_APP_CARTRIDGE")
    end
  end

  # POST /domains/[domain_id]/applications/[application_id]/cartridges
  def create
    domain_id = params[:domain_id]
    id = params[:application_id]
    name = params[:name]
    
    # :cartridge param is deprecated because it isn't consistent with
    # the rest of the apis which take :name. Leave it here because
    # some tools may still use it
    name = params[:cartridge] if name.nil?
    colocate_with = params[:colocate_with]
    scales_from = Integer(params[:scales_from]) rescue nil
    scales_to = Integer(params[:scales_to]) rescue nil
    additional_storage = Integer(params[:additional_storage]) rescue nil

    begin
      domain = Domain.find_by(owner: @cloud_user, namespace: domain_id)
    rescue Mongoid::Errors::DocumentNotFound
      return render_error(:not_found, "Domain #{domain_id} not found", 127, "EMBED_CARTRIDGE")
    end
    
    begin
      application = Application.find_by(domain: domain, name: id)
    rescue Mongoid::Errors::DocumentNotFound
      return render_error(:not_found, "Application '#{id}' not found for domain '#{domain_id}'", 101, "EMBED_CARTRIDGE")
    end

    begin
      colocate_component_instance = application.component_instances.find_by(cartridge_name: colocate_with)
      colocate_component_instance = colocate_component_instance.first if colocate_component_instance.class == Array
    rescue Mongoid::Errors::DocumentNotFound
      return render_error(:bad_request, "Invalid colocation specified. No component matches #{colocate_with}", 109, "EMBED_CARTRIDGE", "cartridge")      
    end
    
    begin
      group_overrides = []
      # Todo: REST API assumes cartridge only has one component
      cart = CartridgeCache.find_cartridge(name)
      prof = cart.profile_for_feature(name)
      comp = prof.components.first
      comp_spec = {"cart" => cart.name, "comp" => comp.name}
      
      unless colocate_component_instance.nil?
        group_overrides << {"components" => [colocate_component_instance.to_hash, comp_spec]}
      end
      if !scales_to.nil? or !scales_from.nil? or !additional_storage.nil?
        group_override = {"components" => [comp_spec]}
        group_override["min_gears"] = scales_from unless scales_from.nil?
        group_override["max_gears"] = scales_to unless scales_to.nil?
        group_override["additional_filesystem_gb"] = additional_storage unless additional_storage.nil?
        group_overrides << group_override
      end
      
      application.add_features([name], group_overrides)
      
      
      component_instance = application.component_instances.find_by(cartridge_name: cart.name, component_name: comp.name)
      cartridge = get_rest_cartridge(application, component_instance, application.group_instances_with_scale, application.group_overrides)
      return render_success(:created, "cartridge", cartridge, "EMBED_CARTRIDGE", nil, nil, nil, nil)
    rescue StickShift::UserException => e
      return render_error(:bad_request, "Invalid cartridge. #{e.message}", 109, "EMBED_CARTRIDGE", "cartridge")
    end
  end

  # DELETE /domains/[domain_id]/applications/[application_id]/cartridges/[cartridge_id]
  def destroy
    domain_id = params[:domain_id]
    id = params[:application_id]
    cartridge = params[:id]
    
    begin
      domain = Domain.find_by(owner: @cloud_user, namespace: domain_id)
    rescue Mongoid::Errors::DocumentNotFound
      return render_error(:not_found, "Domain #{domain_id} not found", 127, "REMOVE_CARTRIDGE")
    end
    
    begin
      application = Application.find_by(domain: domain, name: id)
    rescue Mongoid::Errors::DocumentNotFound
      return render_error(:not_found, "Application '#{id}' not found for domain '#{domain_id}'", 101, "REMOVE_CARTRIDGE")
    end
    
    begin
      comp = application.component_instances.find_by(cartridge_name: cartridge)
      feature = application.get_feature(comp.cartridge_name, comp.component_name)
      if CartridgeCache.find_cartridge(cartridge).categories.include?("web_framework")
        raise StickShift::UserException.new("Invalid cartridge #{id}")
      end
      
      application.remove_features([feature])
      render_success(:ok, "application", RestApplication.new(application, get_url, nolinks), "REMOVE_CARTRIDGE", "Removed #{cartridge} from application #{id}", true)
    rescue StickShift::UserException => e
      return render_error(:bad_request, "Application is currently busy performing another operation. Please try again in a minute.", 129, "REMOVE_CARTRIDGE")
    rescue Mongoid::Errors::DocumentNotFound
      return render_error(:bad_request, "Cartridge #{cartridge} not embedded within application #{id}", 129, "REMOVE_CARTRIDGE")
    end
  end
  
  private
  
  def get_rest_cartridge(application, component_instance, group_instances_with_scale, group_overrides)
    group_instance = group_instances_with_scale.select{ |go| go.all_component_instances.include? component_instance }[0]
    group_component_instances = group_instance.all_component_instances
    colocated_instances = group_component_instances - [component_instance]
          
    additional_storage = 0
    group_override = group_overrides.select{ |go| go["components"] == [component_instance.to_hash] }.first
    additional_storage = group_override["additional_filesystem_gb"] if !group_override.nil? and group_override.has_key?("additional_filesystem_gb")

    scale = {min: group_instance.min, max: group_instance.max, gear_size: group_instance.gear_size, additional_storage: additional_storage, current: group_instance.gears.count}
    
    cart = CartridgeCache.find_cartridge(component_instance.cartridge_name)
    comp = cart.get_component(component_instance.component_name)
    RestCartridge11.new(nil, cart, comp, application, component_instance, colocated_instances, scale, get_url, nolinks)
  end
end
