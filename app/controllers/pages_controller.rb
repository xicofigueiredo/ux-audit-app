class PagesController < ApplicationController
  layout 'marketing'
  skip_before_action :authenticate_user!, only: [:home, :demo]

  def home
  end

  def demo
    # Fetch screenshots from VideoAudit #5 for demo
    @demo_audit = VideoAudit.find(5)
    @demo_screenshots = @demo_audit.issue_screenshots.order(:issue_index).index_by(&:issue_index)
    render layout: false
  rescue ActiveRecord::RecordNotFound
    # Fallback if VideoAudit #5 doesn't exist
    @demo_audit = nil
    @demo_screenshots = {}
    render layout: false
  end
end 