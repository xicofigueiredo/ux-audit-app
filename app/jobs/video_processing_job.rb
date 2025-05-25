# app/jobs/video_processing_job.rb
class VideoProcessingJob < ApplicationJob
  def perform(video_audit_id)
    audit = VideoAudit.find(video_audit_id)
    video_path = audit.video.path

    begin
      # Create frames directory if it doesn't exist
      frames_dir = Rails.root.join('tmp', 'frames', audit.id.to_s)
      FileUtils.mkdir_p(frames_dir)

      # Extract key frames using FFmpeg
      movie = FFMPEG::Movie.new(video_path)
      movie.screenshot(
        "#{frames_dir}/frame_%d.jpg",
        { quality: 3, frame_rate: '1/5' }, # 1 frame every 5 seconds
        validate: false
      )

      # Store frame paths as an array
      frame_paths = Dir.glob("#{frames_dir}/frame_*.jpg")
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
