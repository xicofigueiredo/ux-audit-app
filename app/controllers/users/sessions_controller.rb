class Users::SessionsController < Devise::SessionsController
  include AnalyticsHelper
  layout 'marketing'

  def create
    super do |resource|
      if resource.persisted?
        track_user_login
        # Redirect to app subdomain after sign in, allowing cross-host redirect
        return redirect_to after_sign_in_path_for(resource), allow_other_host: true
      end
    end
  end

  def destroy
    track_user_logout
    super
  end

  protected

  # Redirect to app subdomain after sign in
  def after_sign_in_path_for(resource)
    helpers.after_sign_in_url
  end

  # Redirect to marketing domain after sign out
  def after_sign_out_path_for(resource_or_scope)
    helpers.after_sign_out_url
  end

  # Override Devise's redirect to allow cross-subdomain redirects
  def require_no_authentication
    assert_is_devise_resource!
    return unless is_navigational_format?

    no_input = devise_mapping.no_input_strategies

    authenticated = if no_input.present?
      args = no_input.dup.push scope: resource_name
      warden.authenticate?(*args)
    else
      warden.authenticated?(resource_name)
    end

    if authenticated && resource = warden.user(resource_name)
      set_flash_message(:alert, 'already_authenticated', scope: 'devise.failure') if is_flashing_format?
      redirect_to after_sign_in_path_for(resource), allow_other_host: true
    end
  end
end