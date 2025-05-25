class CleanupJob < ApplicationJob
  queue_as :default

  def perform(video_audit_id)
    audit = VideoAudit.find(video_audit_id)

    begin
      # Delete frames
      if audit.frames.present?
        audit.frames.each do |frame_path|
          File.delete(frame_path) if File.exist?(frame_path)
        end
        # Delete frames directory
        frames_dir = Rails.root.join('tmp', 'frames', audit.id.to_s)
        FileUtils.rm_rf(frames_dir) if Dir.exist?(frames_dir)
      end

      # Delete video file
      if audit.video.present? && File.exist?(audit.video.path)
        File.delete(audit.video.path)
      end

      # Clear the video and frames from the record
      audit.update(video: nil, frames: [])

      Rails.logger.info "Cleanup completed for VideoAudit ##{audit.id}"
    rescue => e
      Rails.logger.error "Cleanup failed for VideoAudit ##{audit.id}: #{e.message}"
    end
  end
end
