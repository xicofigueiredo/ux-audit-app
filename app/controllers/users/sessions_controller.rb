class Users::SessionsController < Devise::SessionsController
  include AnalyticsHelper
  layout 'marketing'

  def create
    super do |resource|
      if resource.persisted?
        track_user_login
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
end