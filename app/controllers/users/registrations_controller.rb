class Users::RegistrationsController < Devise::RegistrationsController
  include AnalyticsHelper
  layout 'marketing'

  def create
    super do |resource|
      if resource.persisted?
        track_user_signup
        # Identify user in Mixpanel
        identify_user(resource.id, {
          '$email': resource.email,
          '$created': resource.created_at.iso8601,
          'User ID': resource.id
        })
      end
    end
  end

  protected

  # Redirect to app subdomain after sign up
  def after_sign_up_path_for(resource)
    helpers.after_sign_in_url
  end
end