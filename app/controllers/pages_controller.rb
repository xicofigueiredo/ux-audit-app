class PagesController < ApplicationController
  layout 'marketing'
  skip_before_action :authenticate_user!, only: [:home, :demo]

  def home
  end

  def demo
    # Static demo page - no database dependency
  end
end 