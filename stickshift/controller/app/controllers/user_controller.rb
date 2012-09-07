class UserController < BaseController
  respond_to :json, :xml
  before_filter :authenticate, :check_version
  
  # GET /user
  def show
    return render_error(:not_found, "User '#{@login}' not found", 99, "SHOW_USER") unless @cloud_user
    render_success(:ok, "user", RestUser.new(@cloud_user, get_url, nolinks), "SHOW_USER")
  end

  # DELETE /user
  # NOTE: Only applicable for subaccount users
  def destroy
    force = get_bool(params[:force])

    unless @cloud_user
      log_action(@request_id, 'nil', @login, "DELETE_USER", false, "User '#{@login}' not found")
      return render_error(:not_found, "User '#{@login}' not found", 99)
    end
    return render_error(:forbidden, "User deletion not permitted. Only applicable for subaccount users.",
                        138, "DELETE_USER") unless @cloud_user.parent_user_id
    if !force && (!@cloud_user.domains.empty? || !@cloud_user.applications)
      return render_error(:unprocessable_entity, "User '#{@login}' has valid domains or applications. Either delete domains/applications and retry the operation or use 'force' option.", 139, "DELETE_USER")
    end

    begin
      @cloud_user.delete
      render_success(:no_content, nil, nil, "DELETE_USER", "User #{@login} deleted.", true)
    rescue Exception => e
      return render_exception(e, "DELETE_USER")
    end
  end
end
