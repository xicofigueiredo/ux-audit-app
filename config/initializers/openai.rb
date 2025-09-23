# config/initializers/openai.rb
require 'openai'

# Only configure OpenAI if we're not precompiling assets
unless Rails.env.production? && ENV['SECRET_KEY_BASE_DUMMY']
  OpenAI.configure do |config|
    config.access_token = ENV.fetch('OPENAI_API_KEY')
    config.organization_id = ENV.fetch('OPENAI_ORGANIZATION_ID', nil) # optional
    config.request_timeout = 240 # Optional for video processing
  end

  LLM_CLIENT = OpenAI::Client.new
end
