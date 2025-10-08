class FeedbackMailer < ApplicationMailer
  default from: ENV.fetch('SMTP_USERNAME', 'noreply@uxauditapp.com')

  def new_feedback(feedback_text:, user_name:, user_email:, images: [])
    @feedback_text = feedback_text
    @user_name = user_name
    @user_email = user_email
    @timestamp = Time.current.strftime('%B %d, %Y at %I:%M %p %Z')

    # Attach images if present
    if images.is_a?(Array)
      images.each_with_index do |image, index|
        next unless image.respond_to?(:read)
        attachments["feedback_image_#{index + 1}#{File.extname(image.original_filename)}"] = image.read
      end
    end

    mail(
      to: 'zsottomayor@gmail.com',
      reply_to: user_email == 'anonymous@uxauditapp.com' ? 'noreply@uxauditapp.com' : user_email,
      subject: "New Feedback from #{user_name}"
    )
  end
end
