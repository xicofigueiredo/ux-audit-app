class FeedbackController < ApplicationController
  skip_before_action :verify_authenticity_token, only: [:create]

  def create
    feedback_text = params[:feedback]
    images = params[:images] || []

    # Validation
    if feedback_text.blank?
      render json: { error: 'Feedback text is required' }, status: :unprocessable_entity
      return
    end

    if feedback_text.length > 5000
      render json: { error: 'Feedback must be less than 5000 characters' }, status: :unprocessable_entity
      return
    end

    if images.is_a?(Array) && images.length > 5
      render json: { error: 'Maximum 5 images allowed' }, status: :unprocessable_entity
      return
    end

    # Get user info
    user_name = user_signed_in? ? current_user.email.split('@').first : 'Anonymous'
    user_email = user_signed_in? ? current_user.email : 'anonymous@uxauditapp.com'

    # Send email
    begin
      FeedbackMailer.new_feedback(
        feedback_text: feedback_text,
        user_name: user_name,
        user_email: user_email,
        images: images
      ).deliver_now

      render json: { success: true, message: 'Feedback sent successfully' }, status: :ok
    rescue => e
      Rails.logger.error "Failed to send feedback email: #{e.message}"
      render json: { error: 'Failed to send feedback. Please try again.' }, status: :internal_server_error
    end
  end
end
