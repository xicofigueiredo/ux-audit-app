class ProjectsController < ApplicationController
  layout false

  def index
    @audits = current_user.video_audits.order(created_at: :desc)
  end
end 