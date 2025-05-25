class VideoAudit < ApplicationRecord
  mount_uploader :video, VideoAuditUploader
  validates :video, presence: true

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
