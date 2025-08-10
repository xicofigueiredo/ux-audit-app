# config/initializers/llm_config.rb

# Load LLM configuration on application startup
Rails.application.config.after_initialize do
  begin
    LlmConfig.validate!
    Rails.logger.info "LLM Configuration validated successfully"
    Rails.logger.info "Using model: #{LlmConfig.model}"
    Rails.logger.info "Batch size: #{LlmConfig.batch_size}"
    Rails.logger.info "Temperature: #{LlmConfig.temperature}"
  rescue LlmConfig::ConfigurationError => e
    Rails.logger.error "LLM Configuration Error: #{e.message}"
    Rails.logger.error "Please check your environment variables and restart the application"
    
    # In development, show a more helpful error
    if Rails.env.development?
      puts "\n" + "="*60
      puts "LLM CONFIGURATION ERROR"
      puts "="*60
      puts e.message
      puts "\nPlease ensure you have set the following environment variables:"
      puts "- OPENAI_API_KEY"
      puts "- GPT_MODEL (optional, defaults to gpt-5o)"
      puts "- GPT_TEMPERATURE (optional, defaults to 0.1)"
      puts "- GPT_MAX_TOKENS (optional, defaults to 4000)"
      puts "- GPT_BATCH_SIZE (optional, defaults to 50)"
      puts "- GPT_TIMEOUT (optional, defaults to 300)"
      puts "\nYou can create a .env file in your project root with these variables."
      puts "="*60
    end
  end
end 