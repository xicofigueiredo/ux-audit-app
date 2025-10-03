class Users::RegistrationsController < Devise::RegistrationsController
  include AnalyticsHelper

  def create
    super do |resource|
      if resource.persisted?
        track_user_signup
      end
    end
  end
end