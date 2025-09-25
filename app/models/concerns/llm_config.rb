# app/models/concerns/llm_config.rb
module LlmConfig
  extend ActiveSupport::Concern
  class ConfigurationError < StandardError; end

  # Default configuration values
  DEFAULTS = {
    model: 'gpt-5o',
    temperature: 0.1,
    max_tokens: 4000,
    batch_size: 50,
    timeout: 300
  }.freeze

  # Supported models with fallbacks
  SUPPORTED_MODELS = {
    'gpt-5o' => 'gpt-5o',
    'gpt-4o' => 'gpt-4o',
    'gpt-4-turbo' => 'gpt-4-turbo-preview'
  }.freeze

  included do
    def llm_model
      model_name = ENV.fetch('GPT_MODEL', DEFAULTS[:model])
      SUPPORTED_MODELS[model_name] || SUPPORTED_MODELS['gpt-4o']
    end

    def llm_temperature
      ENV.fetch('GPT_TEMPERATURE', DEFAULTS[:temperature]).to_f
    end

    def llm_max_tokens
      ENV.fetch('GPT_MAX_TOKENS', DEFAULTS[:max_tokens]).to_i
    end

    def llm_batch_size
      ENV.fetch('GPT_BATCH_SIZE', DEFAULTS[:batch_size]).to_i
    end

    def llm_timeout
      ENV.fetch('GPT_TIMEOUT', DEFAULTS[:timeout]).to_i
    end

    def llm_api_key
      ENV.fetch('OPENAI_API_KEY') { raise ConfigurationError, 'OPENAI_API_KEY is required' }
    end

    def llm_gpt_5?
      llm_model.start_with?('gpt-5')
    end

    def llm_gpt_4?
      llm_model.start_with?('gpt-4')
    end
  end

  class << self
    def model
      model_name = ENV.fetch('GPT_MODEL', DEFAULTS[:model])
      SUPPORTED_MODELS[model_name] || SUPPORTED_MODELS['gpt-4o']
    end

    def temperature
      ENV.fetch('GPT_TEMPERATURE', DEFAULTS[:temperature]).to_f
    end

    def max_tokens
      ENV.fetch('GPT_MAX_TOKENS', DEFAULTS[:max_tokens]).to_i
    end

    def batch_size
      ENV.fetch('GPT_BATCH_SIZE', DEFAULTS[:batch_size]).to_i
    end

    def timeout
      ENV.fetch('GPT_TIMEOUT', DEFAULTS[:timeout]).to_i
    end

    def api_key
      ENV.fetch('OPENAI_API_KEY') { raise ConfigurationError, 'OPENAI_API_KEY is required' }
    end

    def validate!
      validate_api_key!
      validate_model!
      validate_numeric_values!
    end

    def to_hash
      {
        model: model,
        temperature: temperature,
        max_tokens: max_tokens,
        batch_size: batch_size,
        timeout: timeout,
        api_key: api_key
      }
    end

    def gpt_5?
      model.start_with?('gpt-5')
    end

    def gpt_4?
      model.start_with?('gpt-4')
    end

    private

    def validate_api_key!
      return if api_key.present? && api_key != 'your_openai_api_key_here'
      raise ConfigurationError, 'OPENAI_API_KEY must be set to a valid API key'
    end

    def validate_model!
      return if SUPPORTED_MODELS.key?(ENV.fetch('GPT_MODEL', DEFAULTS[:model]))
      raise ConfigurationError, "Unsupported model: #{ENV.fetch('GPT_MODEL', DEFAULTS[:model])}"
    end

    def validate_numeric_values!
      validate_numeric_range(:temperature, 0.0, 2.0)
      validate_numeric_range(:max_tokens, 1, 128000)
      validate_numeric_range(:batch_size, 1, 1000)
      validate_numeric_range(:timeout, 1, 600)
    end

    def validate_numeric_range(attribute, min, max)
      value = send(attribute)
      return if value >= min && value <= max
      raise ConfigurationError, "#{attribute.upcase} must be between #{min} and #{max}, got: #{value}"
    end
  end
end 