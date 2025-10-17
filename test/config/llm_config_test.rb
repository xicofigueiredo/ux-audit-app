# test/config/llm_config_test.rb
require 'test_helper'

class LlmConfigTest < ActiveSupport::TestCase
  def setup
    @original_env = ENV.to_hash
  end

  def teardown
    ENV.clear
    ENV.update(@original_env)
  end

  test "default values are set correctly" do
    assert_equal 'gpt-5', LlmConfig.model
    assert_equal 0.1, LlmConfig.temperature
    assert_equal 4000, LlmConfig.max_tokens
    assert_equal 50, LlmConfig.batch_size
    assert_equal 300, LlmConfig.timeout
  end

  test "environment variables override defaults" do
    ENV['GPT_MODEL'] = 'gpt-4o'
    ENV['GPT_TEMPERATURE'] = '0.5'
    ENV['GPT_MAX_TOKENS'] = '2000'
    ENV['GPT_BATCH_SIZE'] = '25'
    ENV['GPT_TIMEOUT'] = '150'

    assert_equal 'gpt-4o', LlmConfig.model
    assert_equal 0.5, LlmConfig.temperature
    assert_equal 2000, LlmConfig.max_tokens
    assert_equal 25, LlmConfig.batch_size
    assert_equal 150, LlmConfig.timeout
  end

  test "unsupported model falls back to gpt-4o" do
    ENV['GPT_MODEL'] = 'unsupported-model'
    assert_equal 'gpt-4o', LlmConfig.model
  end

  test "gpt_5? returns true for gpt-5 models" do
    ENV['GPT_MODEL'] = 'gpt-5'
    assert LlmConfig.gpt_5?
    refute LlmConfig.gpt_4?
  end

  test "gpt_4? returns true for gpt-4 models" do
    ENV['GPT_MODEL'] = 'gpt-4o'
    assert LlmConfig.gpt_4?
    refute LlmConfig.gpt_5?
  end

  test "validate! raises error for missing API key" do
    ENV.delete('OPENAI_API_KEY')
    assert_raises(LlmConfig::ConfigurationError) do
      LlmConfig.validate!
    end
  end

  test "validate! raises error for invalid temperature" do
    ENV['OPENAI_API_KEY'] = 'test-key'
    ENV['GPT_TEMPERATURE'] = '3.0' # Invalid: > 2.0
    assert_raises(LlmConfig::ConfigurationError) do
      LlmConfig.validate!
    end
  end

  test "validate! raises error for invalid max_tokens" do
    ENV['OPENAI_API_KEY'] = 'test-key'
    ENV['GPT_MAX_TOKENS'] = '200000' # Invalid: > 128000
    assert_raises(LlmConfig::ConfigurationError) do
      LlmConfig.validate!
    end
  end

  test "to_hash returns all configuration values" do
    ENV['OPENAI_API_KEY'] = 'test-key'
    config_hash = LlmConfig.to_hash
    
    assert_equal 'gpt-5', config_hash[:model]
    assert_equal 0.1, config_hash[:temperature]
    assert_equal 4000, config_hash[:max_tokens]
    assert_equal 50, config_hash[:batch_size]
    assert_equal 300, config_hash[:timeout]
    assert_equal 'test-key', config_hash[:api_key]
  end
end 