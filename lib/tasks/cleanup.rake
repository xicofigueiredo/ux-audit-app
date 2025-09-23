namespace :uxauditapp do
  desc "Clean up orphaned FFmpeg processes"
  task cleanup_ffmpeg: :environment do
    puts "Starting FFmpeg process cleanup..."

    # Kill all headless FFmpeg processes that have been running too long
    begin
      # Find FFmpeg processes older than 10 minutes
      pids = `pgrep -f ffmpeg`.split("\n").map(&:to_i)

      if pids.any?
        puts "Found #{pids.length} FFmpeg process(es)"

        pids.each do |pid|
          begin
            # Check process age - kill if older than 10 minutes (600 seconds)
            process_age = `ps -o etimes= -p #{pid}`.strip.to_i

            if process_age > 600
              puts "Killing old FFmpeg process #{pid} (age: #{process_age}s)"
              Process.kill('TERM', pid)
              sleep 2

              # Force kill if still running
              if process_running?(pid)
                puts "Force killing FFmpeg process #{pid}"
                Process.kill('KILL', pid)
              end
            end
          rescue Errno::ESRCH
            # Process already dead
          rescue => e
            puts "Error killing process #{pid}: #{e.message}"
          end
        end
      else
        puts "No FFmpeg processes found"
      end
    rescue => e
      puts "Error during FFmpeg cleanup: #{e.message}"
    end

    puts "FFmpeg cleanup completed"
  end

  desc "Monitor FFmpeg processes"
  task monitor_ffmpeg: :environment do
    pids = `pgrep -f ffmpeg`.split("\n").map(&:to_i)
    puts "Current FFmpeg processes: #{pids.length}"

    if pids.length > 10
      puts "WARNING: High number of FFmpeg processes detected!"

      pids.each do |pid|
        begin
          process_age = `ps -o etimes= -p #{pid}`.strip.to_i
          command = `ps -o command= -p #{pid}`.strip
          puts "PID #{pid}: #{process_age}s - #{command[0..80]}..."
        rescue
          # Process might have died between pgrep and ps
        end
      end
    end
  end

  desc "Clean up old temporary files"
  task cleanup_temp_files: :environment do
    puts "Cleaning up temporary files..."

    temp_dirs = [
      Rails.root.join('tmp', 'frames'),
      Rails.root.join('tmp', 'uploads')
    ]

    temp_dirs.each do |dir|
      next unless Dir.exist?(dir)

      # Remove directories older than 1 hour
      Dir.glob("#{dir}/*").each do |path|
        begin
          if File.directory?(path) && (Time.current - File.mtime(path)) > 1.hour
            puts "Removing old temp directory: #{path}"
            FileUtils.rm_rf(path)
          end
        rescue => e
          puts "Error removing #{path}: #{e.message}"
        end
      end
    end

    puts "Temporary file cleanup completed"
  end

  desc "Clean up failed video audits"
  task cleanup_failed_audits: :environment do
    puts "Cleaning up failed video audits..."

    # Clean up audits that have been in 'failed' state for more than 24 hours
    failed_audits = VideoAudit.where(status: 'failed')
                              .where('updated_at < ?', 24.hours.ago)

    puts "Found #{failed_audits.count} old failed audits to clean up"

    failed_audits.find_each do |audit|
      begin
        CleanupJob.perform_now(audit.id)
        puts "Cleaned up failed audit ##{audit.id}"
      rescue => e
        puts "Error cleaning up audit ##{audit.id}: #{e.message}"
      end
    end

    puts "Failed audit cleanup completed"
  end

  desc "Full system cleanup"
  task full_cleanup: :environment do
    puts "Starting full system cleanup..."

    Rake::Task['uxauditapp:cleanup_ffmpeg'].invoke
    Rake::Task['uxauditapp:cleanup_temp_files'].invoke
    Rake::Task['uxauditapp:cleanup_failed_audits'].invoke

    puts "Full system cleanup completed"
  end

  desc "System health check"
  task health_check: :environment do
    puts "=== UX Audit App Health Check ==="

    # Database check
    begin
      ActiveRecord::Base.connection.execute('SELECT 1')
      puts "✓ Database: Connected"
    rescue => e
      puts "✗ Database: #{e.message}"
    end

    # Redis check
    begin
      redis = Redis.new(url: ENV.fetch('REDIS_URL', 'redis://localhost:6379/0'))
      redis.ping
      puts "✓ Redis: Connected"
      redis.close
    rescue => e
      puts "✗ Redis: #{e.message}"
    end

    # FFmpeg processes
    ffmpeg_count = `pgrep -cf ffmpeg`.to_i
    puts "FFmpeg processes: #{ffmpeg_count}"
    puts "  WARNING: High process count!" if ffmpeg_count > 10

    # Disk usage
    temp_usage = `df -h #{Rails.root.join('tmp')} | tail -1`.split[4] rescue 'unknown'
    puts "Temp disk usage: #{temp_usage}"

    # Recent audits
    recent_audits = VideoAudit.where('created_at > ?', 1.hour.ago).count
    failed_audits = VideoAudit.where(status: 'failed').where('created_at > ?', 1.hour.ago).count
    puts "Recent audits (1h): #{recent_audits} total, #{failed_audits} failed"

    puts "=== Health Check Complete ==="
  end

  private

  def process_running?(pid)
    Process.kill(0, pid)
    true
  rescue Errno::ESRCH
    false
  end
end