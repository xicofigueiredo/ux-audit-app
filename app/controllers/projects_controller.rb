class ProjectsController < ApplicationController
  def index
    @audits = VideoAudit.all.order(created_at: :desc) # Assuming VideoAudit model exists
  end
end 