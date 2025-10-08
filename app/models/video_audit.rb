class VideoAudit < ApplicationRecord
  belongs_to :user
  mount_uploader :video, VideoAuditUploader
  validates :video, presence: true
  has_many :llm_partial_responses, dependent: :destroy
  has_many :issue_screenshots, dependent: :destroy

  # Define possible statuses
  STATUSES = %w[pending completed failed]

  # Define possible processing stages
  PROCESSING_STAGES = %w[uploaded extracting_frames analyzing_ai generating_report]

  # Add status check methods
  def completed?
    status == 'completed'
  end

  def failed?
    status == 'failed'
  end

  def pending?
    status == 'pending'
  end

  # Processing stage helpers
  def processing_stage_message
    case processing_stage
    when 'uploaded'
      'Video uploaded successfully'
    when 'extracting_frames'
      'Extracting frames from video...'
    when 'analyzing_ai'
      'Analyzing workflow with AI...'
    when 'generating_report'
      'Generating your UX report...'
    else
      'Processing your video...'
    end
  end

  def estimated_time_remaining
    case processing_stage
    when 'uploaded', 'extracting_frames'
      '1-2 minutes remaining'
    when 'analyzing_ai'
      '30-60 seconds remaining'
    when 'generating_report'
      'Almost done!'
    else
      'Processing...'
    end
  end

  # Parse llm_response as JSON or Ruby hash if it's a string
  def parsed_llm_response
    return {} if llm_response.blank?

    if llm_response.is_a?(String)
      # Try parsing as JSON first
      begin
        JSON.parse(llm_response)
      rescue JSON::ParserError
        # If JSON parsing fails, try evaluating as Ruby hash (unsafe but necessary for legacy data)
        begin
          eval(llm_response)
        rescue => e
          Rails.logger.error("Failed to parse llm_response: #{e.message}")
          {}
        end
      end
    else
      llm_response
    end
  end
end
