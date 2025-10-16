# app/services/llm/video_processor.rb
module Llm
  class VideoProcessor < BaseService
    include LlmConfig

    def initialize
      super
      @batch_size = llm_batch_size
    end

    # Process video and extract frames
    def process_video(video_path, audit_id)
      log_info("Starting video processing", video_path: video_path, audit_id: audit_id)
      
      frames_dir = create_frames_directory(audit_id)
      frame_paths = extract_frames(video_path, frames_dir)
      
      log_info("Video processing completed", 
        frames_extracted: frame_paths.length,
        audit_id: audit_id
      )
      
      frame_paths
    rescue => error
      log_error("Video processing failed", error: error, audit_id: audit_id)
      raise VideoProcessingError, "Failed to process video: #{error.message}"
    end

    # Create batches of frames for processing
    def create_batches(frame_paths)
      batches = frame_paths.each_slice(@batch_size).to_a
      
      log_info("Created batches", 
        total_frames: frame_paths.length,
        batch_size: @batch_size,
        batch_count: batches.length
      )
      
      batches
    end

    # Prepare frames for API submission
    def prepare_frames_for_api(batch_frames, batch_index, total_frames)
      log_info("Preparing frames for API", 
        batch_index: batch_index,
        frame_count: batch_frames.length,
        total_frames: total_frames
      )
      
      batch_frames.map.with_index do |frame_path, index|
        {
          type: "image_url",
          image_url: {
            url: encode_frame_as_data_url(frame_path),
            detail: determine_detail_level(batch_frames.length)
          }
        }
      end
    end

    # Assess frame quality and filter if needed
    def assess_frame_quality(frame_paths)
      log_info("Assessing frame quality", frame_count: frame_paths.length)
      
      quality_scores = frame_paths.map do |frame_path|
        {
          path: frame_path,
          quality_score: calculate_frame_quality(frame_path),
          size: File.size(frame_path)
        }
      end
      
      # Filter out low-quality frames if we have too many
      if frame_paths.length > 100
        quality_scores.sort_by! { |frame| -frame[:quality_score] }
        quality_scores = quality_scores.first(100)
        log_warn("Filtered frames for quality", 
          original_count: frame_paths.length,
          filtered_count: quality_scores.length
        )
      end
      
      quality_scores.map { |frame| frame[:path] }
    end

    # Get processing progress
    def get_processing_progress(audit_id)
      frames_dir = Rails.root.join('tmp', 'frames', audit_id.to_s)
      return { status: 'not_started', progress: 0 } unless Dir.exist?(frames_dir)
      
      frame_files = Dir.glob("#{frames_dir}/frame_*.jpg")
      total_expected = estimate_total_frames(audit_id)
      
      {
        status: 'processing',
        progress: (frame_files.length.to_f / total_expected * 100).round(2),
        frames_extracted: frame_files.length,
        total_expected: total_expected
      }
    end

    private

    def create_frames_directory(audit_id)
      frames_dir = Rails.root.join('tmp', 'frames', audit_id.to_s)
      FileUtils.mkdir_p(frames_dir)
      frames_dir
    end

    def extract_frames(video_path, frames_dir)
      log_info("Extracting frames", video_path: video_path, frames_dir: frames_dir)

      # Use FFmpeg to extract frames (2 frames per second)
      require 'shellwords'
      output_pattern = "#{frames_dir}/frame_%04d.jpg"

      command = "ffmpeg -i #{Shellwords.escape(video_path)} -vf fps=2 #{Shellwords.escape(output_pattern)}"
      
      log_info("Running FFmpeg command", command: command)
      
      result = system(command)
      unless result
        raise VideoProcessingError, "FFmpeg command failed"
      end
      
      # Get extracted frame paths
      frame_paths = Dir.glob("#{frames_dir}/frame_*.jpg").sort
      
      if frame_paths.empty?
        raise VideoProcessingError, "No frames were extracted from video"
      end
      
      log_info("Frame extraction completed", frames_extracted: frame_paths.length)
      frame_paths
    end

    def encode_frame_as_data_url(frame_path)
      return nil unless File.exist?(frame_path)
      
      image_data = File.read(frame_path)
      base64_data = Base64.strict_encode64(image_data)
      "data:image/jpeg;base64,#{base64_data}"
    end

    def determine_detail_level(frame_count)
      # Use higher detail for smaller batches, lower detail for larger batches
      case frame_count
      when 1..10
        "high"
      when 11..30
        "medium"
      else
        "low"
      end
    end

    def calculate_frame_quality(frame_path)
      return 0.0 unless File.exist?(frame_path)
      
      # Simple quality assessment based on file size
      file_size = File.size(frame_path)
      
      # Normalize file size to a 0-1 quality score
      # Assuming good quality frames are 50KB-500KB
      case file_size
      when 0..1024
        0.1 # Very small, likely poor quality
      when 1025..10240
        0.3 # Small
      when 10241..51200
        0.7 # Good size
      when 51201..512000
        1.0 # Excellent size
      else
        0.8 # Very large, might be overkill
      end
    end

    def estimate_total_frames(audit_id)
      # Try to get video duration and estimate frames
      audit = VideoAudit.find(audit_id)
      return 60 if audit.video.blank? # Default estimate
      
      begin
        require 'ffmpeg'
        movie = FFMPEG::Movie.new(audit.video.path)
        movie.duration.to_i
      rescue
        60 # Fallback estimate
      end
    end

    # Custom error class
    class VideoProcessingError < StandardError; end
  end
end 