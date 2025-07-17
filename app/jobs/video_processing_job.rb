# app/jobs/video_processing_job.rb
class VideoProcessingJob < ApplicationJob
  def perform(video_audit_id)
    audit = VideoAudit.find(video_audit_id)
    video_path = audit.video.path

    begin
      # Create frames directory if it doesn't exist
      frames_dir = Rails.root.join('tmp', 'frames', audit.id.to_s)
      FileUtils.mkdir_p(frames_dir)

      # Extract frames using FFmpeg directly (1 frame per second)
      require 'shellwords'
      system("ffmpeg -i #{Shellwords.escape(video_path)} -vf fps=1 #{Shellwords.escape(frames_dir)}/frame_%04d.jpg")

      # Store frame paths as an array
      frame_paths = Dir.glob("#{frames_dir}/frame_*.jpg")
      Rails.logger.info "Extracted frames: \n#{frame_paths.inspect} (count: #{frame_paths.size})"
      audit.update!(frames: frame_paths)

      LlmAnalysisJob.perform_later(audit.id)
    rescue => e
      Rails.logger.error("Video Processing Error: #{e.message}")
      Rails.logger.error(e.backtrace.join("\n"))

      audit.update!(
        status: 'failed',
        llm_response: "Error processing video: #{e.message}"
      )
    end
  end
end
