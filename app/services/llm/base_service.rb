# app/services/llm/base_service.rb
module Llm
  class BaseService

    attr_reader :logger

    def initialize
      @logger = Rails.logger
      validate_configuration!
    end

    private

    def validate_configuration!
      LlmConfig.validate!
    rescue LlmConfig::ConfigurationError => e
      logger.error "LLM Configuration Error: #{e.message}"
      raise e
    end

    def log_info(message, **context)
      logger.info "[#{self.class.name}] #{message} #{context}"
    end

    def log_error(message, error: nil, **context)
      logger.error "[#{self.class.name}] #{message} #{context}"
      logger.error "[#{self.class.name}] Error: #{error.message}" if error
      logger.error "[#{self.class.name}] Backtrace: #{error.backtrace.join("\n")}" if error&.backtrace
    end

    def log_warn(message, **context)
      logger.warn "[#{self.class.name}] #{message} #{context}"
    end

    def handle_api_error(error, context: {})
      case error
      when OpenAI::Error::RateLimitError
        log_error("Rate limit exceeded", error: error, **context)
        raise error
      when OpenAI::Error::TimeoutError
        log_error("Request timeout", error: error, **context)
        raise error
      when OpenAI::Error::AuthenticationError
        log_error("Authentication failed", error: error, **context)
        raise error
      else
        log_error("Unexpected API error", error: error, **context)
        raise error
      end
    end

    def retry_with_backoff(max_retries: 3, base_delay: 1)
      retries = 0
      begin
        yield
      rescue => error
        retries += 1
        if retries <= max_retries
          delay = base_delay * (2 ** (retries - 1)) # Exponential backoff
          log_warn("Retrying after #{delay}s (attempt #{retries}/#{max_retries})", error: error)
          sleep delay
          retry
        else
          log_error("Max retries exceeded", error: error)
          raise error
        end
      end
    end
  end
end 