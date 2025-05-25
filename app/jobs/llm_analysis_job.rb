# app/jobs/llm_analysis_job.rb
class LlmAnalysisJob < ApplicationJob
  queue_as :default

  PROMPT_TEMPLATE = """
  You are a UX expert analyzing a screen recording. Please analyze the frames from this screen recording and provide:
  1. A summary of what you observe in the user interface
  2. Any potential UX issues or areas for improvement
  3. Specific recommendations for enhancing the user experience

  Please be detailed but concise in your analysis.
  """

  def perform(video_audit_id)
    audit = VideoAudit.find(video_audit_id)

    begin
      # Debug API key presence
      api_key = ENV['OPENAI_API_KEY']
      if api_key.blank?
        raise "OpenAI API key is not set. Please check your .env file"
      end
      Rails.logger.info "OpenAI API Key is present"

      frame_paths = audit.frames.is_a?(String) ? [audit.frames.gsub(/[{}]/, '')] : audit.frames
      Rails.logger.info "Processing frames: #{frame_paths}"

      # Verify frames exist
      frame_paths.each do |frame|
        unless File.exist?(frame)
          raise "Frame file not found: #{frame}"
        end
      end

      messages = [
        {
          role: "user",
          content: [
            { type: "text", text: PROMPT_TEMPLATE },
            *frame_paths.map { |frame|
              {
                type: "image_url",
                image_url: {
                  url: "data:image/jpeg;base64,#{Base64.strict_encode64(File.read(frame))}"
                }
              }
            }
          ]
        }
      ]

      client = OpenAI::Client.new(
        access_token: api_key,
        uri_base: "https://api.openai.com/v1",  # Make sure we use v1
        request_timeout: 300
      )

      Rails.logger.info "Sending request to OpenAI..."
      response = client.chat(
        parameters: {
          model: "gpt-4o",
          messages: messages,
          max_tokens: 1000
        }
      )

      Rails.logger.info "OpenAI Response: #{response.inspect}"

      if response.dig("error", "message")
        raise "OpenAI API Error: #{response['error']['message']}"
      end

      # Extract the response content
      analysis = response.dig("choices", 0, "message", "content")

      if analysis.blank?
        raise "No analysis content in OpenAI response"
      end

      # Update the audit with the analysis
      audit.update!(
        status: 'completed',
        llm_response: analysis
      )

      # Schedule cleanup
      CleanupJob.perform_later(audit.id)

    rescue => e
      Rails.logger.error("LLM Analysis Error: #{e.message}")
      Rails.logger.error(e.backtrace.join("\n"))

      audit.update!(
        status: 'failed',
        llm_response: "Error analyzing frames: #{e.message}"
      )

      # Schedule cleanup even if analysis fails
      CleanupJob.perform_later(audit.id)
    end
  end
end
