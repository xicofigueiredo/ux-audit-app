Sidekiq.configure_server do |config|
  config.redis = { url: ENV.fetch('REDIS_URL', 'redis://localhost:6379/0') }
end

Sidekiq.configure_client do |config|
  config.redis = { url: ENV.fetch('REDIS_URL', 'redis://localhost:6379/0') }
end

# Configure job timeouts to handle long-running AI analysis
Sidekiq.default_job_options = {
  'backtrace' => true,
  'retry' => 2,
  'timeout' => 300 # 5 minutes for LLM processing jobs
}