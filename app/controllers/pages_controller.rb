class PagesController < ApplicationController
  def home
  end

  def demo
    @audits = VideoAudit.all
  end
end 