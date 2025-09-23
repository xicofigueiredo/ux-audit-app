class HealthController < ApplicationController
  def show
    health_status = check_health

    if health_status[:status] == 'healthy'
      render json: health_status, status: :ok
    else
      render json: health_status, status: :service_unavailable
    end
  end

  private

  def check_health
    status = {
      status: 'healthy',
      timestamp: Time.current.iso8601,
      services: {},
      warnings: []
    }

    # Check database connection
    begin
      ActiveRecord::Base.connection.execute('SELECT 1')
      status[:services][:database] = 'healthy'
    rescue => e
      status[:services][:database] = "unhealthy: #{e.message}"
      status[:status] = 'unhealthy'
    end

    # Check Redis connection
    begin
      redis = Redis.new(url: ENV.fetch('REDIS_URL', 'redis://localhost:6379/0'))
      redis.ping
      status[:services][:redis] = 'healthy'
      redis.close
    rescue => e
      status[:services][:redis] = "unhealthy: #{e.message}"
      status[:status] = 'unhealthy'
    end

    # Check FFmpeg processes (similar to browser process monitoring)
    ffmpeg_count = count_ffmpeg_processes
    status[:services][:ffmpeg_processes] = ffmpeg_count

    if ffmpeg_count > 10
      status[:warnings] << "High number of FFmpeg processes detected: #{ffmpeg_count}"
      status[:status] = 'warning' if status[:status] == 'healthy'
    end

    # Check OpenAI API accessibility
    begin
      if ENV['OPENAI_API_KEY'].present?
        # Just check if we can create a client - don't make actual API calls for health check
        OpenAI::Client.new(access_token: ENV['OPENAI_API_KEY'])
        status[:services][:openai] = 'configured'
      else
        status[:services][:openai] = 'not_configured'
        status[:warnings] << "OpenAI API key not configured"
      end
    rescue => e
      status[:services][:openai] = "error: #{e.message}"
      status[:warnings] << "OpenAI client initialization failed"
    end

    # Check disk space for temp directories
    temp_usage = check_temp_disk_usage
    status[:services][:disk_usage] = temp_usage

    if temp_usage[:usage_percent] > 90
      status[:warnings] << "High disk usage in temp directory: #{temp_usage[:usage_percent]}%"
      status[:status] = 'warning' if status[:status] == 'healthy'
    end

    status
  end

  def count_ffmpeg_processes
    # Count running FFmpeg processes
    `pgrep -cf ffmpeg`.to_i
  rescue
    0
  end

  def check_temp_disk_usage
    temp_dir = Rails.root.join('tmp')

    begin
      # Get disk usage for temp directory
      usage_output = `df -h #{temp_dir} | tail -1`.strip
      usage_parts = usage_output.split

      {
        available: usage_parts[3],
        used: usage_parts[2],
        usage_percent: usage_parts[4].to_i
      }
    rescue
      { available: 'unknown', used: 'unknown', usage_percent: 0 }
    end
  end
end