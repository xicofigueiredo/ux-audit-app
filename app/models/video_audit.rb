class VideoAudit < ApplicationRecord
  mount_uploader :video, VideoAuditUploader
  validates :video, presence: true
  has_many :llm_partial_responses, dependent: :destroy

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
end
