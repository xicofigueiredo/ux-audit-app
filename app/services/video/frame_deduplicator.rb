# app/services/video/frame_deduplicator.rb
module Video
  class FrameDeduplicator
    # Similarity threshold for considering frames as duplicates (95% similar)
    SIMILARITY_THRESHOLD = 0.95

    # Minimum interval between kept frames (keep every 5th frame minimum)
    MIN_FRAME_INTERVAL = 5

    # Deduplicate frames to reduce redundancy
    # Keeps first and last frames, and frames that are significantly different
    # Returns array of deduplicated frame paths
    def self.deduplicate(frame_paths, keep_ratio: 0.7)
      # For very short videos (<=10 frames), keep all frames
      return frame_paths if frame_paths.size <= 10

      key_frames = []
      key_frames << frame_paths.first  # Always keep first frame

      last_kept = frame_paths.first
      last_kept_index = 0

      frame_paths[1..-2].each_with_index do |frame, idx|
        actual_index = idx + 1  # Account for skipping first frame

        # Calculate similarity based on file size (proxy for content similarity)
        # This is a simple heuristic; more sophisticated approaches would use
        # image hashing or computer vision, but this is fast and effective
        last_size = File.size(last_kept)
        current_size = File.size(frame)

        # Calculate relative size difference
        size_diff = (current_size - last_size).abs.to_f / [last_size, 1].max

        # Keep frame if:
        # 1. Significantly different from last kept frame (size difference > threshold)
        # 2. OR at regular intervals to ensure temporal coverage
        # 3. OR enough frames have passed since last kept frame
        should_keep = size_diff > (1 - SIMILARITY_THRESHOLD) ||
                      (actual_index % MIN_FRAME_INTERVAL == 0) ||
                      (actual_index - last_kept_index) >= MIN_FRAME_INTERVAL

        if should_keep
          key_frames << frame
          last_kept = frame
          last_kept_index = actual_index
        end
      end

      # Always keep last frame
      key_frames << frame_paths.last unless key_frames.last == frame_paths.last

      reduction_percentage = ((1 - key_frames.size.to_f / frame_paths.size) * 100).round
      Rails.logger.info(
        "Frame deduplication: #{frame_paths.size} → #{key_frames.size} frames " \
        "(#{reduction_percentage}% reduction)"
      )

      key_frames
    end

    # Advanced deduplication using perceptual hashing (requires 'dhash-vips' gem)
    # This method is more accurate but slower and requires additional dependencies
    # Uncomment if you install dhash-vips gem: gem 'dhash-vips'
    #
    # def self.deduplicate_advanced(frame_paths, hamming_distance_threshold: 10)
    #   require 'dhash'
    #
    #   return frame_paths if frame_paths.size <= 10
    #
    #   key_frames = [frame_paths.first]
    #   last_hash = DHash.calculate(frame_paths.first)
    #
    #   frame_paths[1..-1].each do |frame|
    #     current_hash = DHash.calculate(frame)
    #     distance = DHash.hamming(last_hash, current_hash)
    #
    #     if distance > hamming_distance_threshold
    #       key_frames << frame
    #       last_hash = current_hash
    #     end
    #   end
    #
    #   Rails.logger.info("Advanced deduplication: #{frame_paths.size} → #{key_frames.size} frames")
    #   key_frames
    # end
  end
end
