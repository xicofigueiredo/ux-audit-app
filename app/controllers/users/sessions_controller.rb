class Users::SessionsController < Devise::SessionsController
  include AnalyticsHelper

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
end