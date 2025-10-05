class PagesController < ApplicationController
  skip_before_action :authenticate_user!, only: [:home, :demo]

  def home
  end

  def demo
    # Show the specific demo audit (ID 5) for non-authenticated users
    @audit = VideoAudit.find(5)
  rescue ActiveRecord::RecordNotFound
    # Fallback if the demo audit doesn't exist
    redirect_to root_path, alert: "Demo not available at the moment."
  end
end 