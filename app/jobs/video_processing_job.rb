# app/jobs/video_processing_job.rb
class VideoProcessingJob < ApplicationJob
  include AnalyticsHelper
  queue_as :default
  retry_on StandardError, wait: :exponentially_longer, attempts: 3
  def perform(video_audit_id)
    audit = VideoAudit.find(video_audit_id)
    video_path = audit.video.path
    stage_start_time = Time.current

    begin
      # Update status to extracting frames
      audit.update!(processing_stage: 'extracting_frames')
      track_processing_stage(audit.id, 'extracting_frames')

      # Create frames directory if it doesn't exist
      frames_dir = Rails.root.join('tmp', 'frames', audit.id.to_s)
      FileUtils.mkdir_p(frames_dir)

      # Extract frames using FFmpeg directly (2 frames per second)
      require 'shellwords'

      # Use full path to ffmpeg to ensure it's found in Sidekiq environment
      ffmpeg_path = `which ffmpeg`.strip
      ffmpeg_path = 'ffmpeg' if ffmpeg_path.empty? # Fallback to PATH

      ffmpeg_command = "#{ffmpeg_path} -i #{Shellwords.escape(video_path)} -vf fps=2 #{Shellwords.escape(frames_dir)}/frame_%04d.jpg"

      unless system(ffmpeg_command)
        raise "FFmpeg failed to extract frames from video"
      end

      # Store frame paths as an array
      frame_paths = Dir.glob("#{frames_dir}/frame_*.jpg").sort

      if frame_paths.empty?
        raise "No frames were extracted from the video. Please check if the video file is valid."
      end

      Rails.logger.info "Extracted frames: \n#{frame_paths.inspect} (count: #{frame_paths.size})"

      # Save the first frame as thumbnail (base64 encoded)
      thumbnail_base64 = nil
      if frame_paths.any?
        first_frame_path = frame_paths.first
        thumbnail_base64 = Base64.strict_encode64(File.read(first_frame_path))
        Rails.logger.info "Encoded thumbnail from #{first_frame_path}, length: #{thumbnail_base64.length}"
      end

      # Track frame extraction completion and transition to AI analysis
      extraction_duration = (Time.current - stage_start_time).to_i
      track_processing_stage(audit.id, 'extraction_completed', extraction_duration)

      # Update audit with frames, thumbnail, and processing stage in one call
      audit.update!(
        frames: frame_paths,
        thumbnail_image: thumbnail_base64,
        processing_stage: 'analyzing_ai'
      )
      Rails.logger.info "Updated audit with #{frame_paths.size} frames and thumbnail"
      track_processing_stage(audit.id, 'analyzing_ai')

      LlmAnalysisJob.perform_later(audit.id)
    rescue => e
      Rails.logger.error("Video Processing Error: #{e.message}")
      Rails.logger.error(e.backtrace.join("\n"))

      # Provide more specific error messages
      error_message = case e.message
      when /FFmpeg failed/
        "We couldn't process your video file. Please make sure it's a valid video format (MP4, MOV, AVI) and try again."
      when /No frames were extracted/
        "Your video appears to be corrupted or in an unsupported format. Please try uploading a different video file."
      when /Errno::ENOENT/
        "Video file not found. Please try uploading your video again."
      else
        "There was an error processing your video. Please try again or contact support if the problem persists."
      end

      # Track processing failure
      track_error('video_processing_failed', 'video_processing_job', e.message)

      audit.update!(
        status: 'failed',
        llm_response: { error: error_message },
        processing_stage: 'failed'
      )
    end
  end
end
