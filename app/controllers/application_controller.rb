class ApplicationController < ActionController::Base
  include AnalyticsHelper
  before_action :authenticate_user!

  rescue_from StandardError, with: :handle_standard_error
  rescue_from ActiveRecord::RecordNotFound, with: :handle_not_found
  rescue_from ActionController::ParameterMissing, with: :handle_parameter_missing

  private

  def handle_standard_error(exception)
    Rails.logger.error "Application Error: #{exception.message}"
    Rails.logger.error exception.backtrace.join("\n")

    # Track the error in analytics
    track_error('application_error', controller_name, exception.message)

    # Show user-friendly error message
    if Rails.env.production?
      redirect_to root_path, alert: "Something went wrong. Please try again."
    else
      raise exception
    end
  end

  def handle_not_found(exception)
    track_error('record_not_found', controller_name, exception.message)
    redirect_to root_path, alert: "The requested resource was not found."
  end

  def handle_parameter_missing(exception)
    track_error('parameter_missing', controller_name, exception.message)
    redirect_to root_path, alert: "Missing required information. Please try again."
  end
end
