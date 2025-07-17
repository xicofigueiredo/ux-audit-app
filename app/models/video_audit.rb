class VideoAudit < ApplicationRecord
  mount_uploader :video, VideoAuditUploader
  validates :video, presence: true
  has_many :llm_partial_responses, dependent: :destroy

  # Define possible statuses
  STATUSES = %w[pending completed failed]

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
end
