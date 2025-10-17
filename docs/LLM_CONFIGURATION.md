# LLM Configuration Guide

This document describes how to configure the LLM analysis system for the UX Audit App.

## Environment Variables

### Required Variables

- `OPENAI_API_KEY`: Your OpenAI API key (required)

### Optional Variables (with defaults)

- `GPT_MODEL`: The GPT model to use (default: `gpt-5`)
- `GPT_TEMPERATURE`: Controls randomness in responses (default: `0.1`)
- `GPT_MAX_TOKENS`: Maximum tokens for responses (default: `4000`)
- `GPT_BATCH_SIZE`: Number of frames to process per batch (default: `50`)
- `GPT_TIMEOUT`: Request timeout in seconds (default: `300`)

## Supported Models

- `gpt-5`: Latest GPT-5 model (recommended)

## Configuration Validation

The application validates configuration on startup. If validation fails, you'll see helpful error messages in development mode.

### Validation Rules

- `OPENAI_API_KEY` must be set and not empty
- `GPT_MODEL` must be one of the supported models
- `GPT_TEMPERATURE` must be between 0.0 and 2.0
- `GPT_MAX_TOKENS` must be between 1 and 128000
- `GPT_BATCH_SIZE` must be between 1 and 1000
- `GPT_TIMEOUT` must be between 1 and 600

## Usage in Code

```ruby
# Get configuration values
model = LlmConfig.model
temperature = LlmConfig.temperature
max_tokens = LlmConfig.max_tokens

# Check model type
if LlmConfig.gpt_5?
  # Use GPT-5 specific features
end

# Validate configuration
LlmConfig.validate!

# Get all configuration as hash
config = LlmConfig.to_hash
```

## Example .env File

```bash
# OpenAI Configuration
OPENAI_API_KEY=your_openai_api_key_here

# Model Configuration
GPT_MODEL=gpt-5
GPT_TEMPERATURE=0.1
GPT_MAX_TOKENS=4000
GPT_BATCH_SIZE=50
GPT_TIMEOUT=300
```

## Troubleshooting

### Common Issues

1. **"OPENAI_API_KEY is required"**
   - Make sure you've set the `OPENAI_API_KEY` environment variable
   - Check that the key is valid and has sufficient credits

2. **"Unsupported model"**
   - Use one of the supported models listed above
   - Check for typos in the model name

3. **"Invalid temperature/max_tokens/etc"**
   - Ensure values are within the specified ranges
   - Check for typos or invalid characters

### Development Setup

1. Copy `.env.example` to `.env`
2. Add your OpenAI API key
3. Restart your Rails server
4. Check the logs for configuration validation messages 