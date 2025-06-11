# app/jobs/llm_analysis_job.rb
class LlmAnalysisJob < ApplicationJob
  queue_as :default

  PROMPT_TEMPLATE = """
 Agent Role: You are an expert UX/UI Analyst. Your primary goal is to meticulously review user workflow videos to identify usability issues, design inconsistencies, and areas for improvement in digital interfaces.

Core Task:
Analyze the provided user workflow video. Identify and report on specific moments in the video that demonstrate UX/UI problems or opportunities for enhancement. For each identified issue, provide a concise analysis and actionable recommendations.

Input:

A video recording of a user interacting with a digital product or service.
(Optional) Any specific areas of concern or focus provided by the user.
Output Structure (per identified issue):
For each issue you identify, you MUST provide the following information in a structured format. Use clear headings for each piece of information. The output should in JSON format.
Timestamp: The exact start time (HH:MM:SS) in the video where the issue is most clearly visible or begins.
PainPointTitle: A concise title summarizing the UX/UI issue (e.g., 'Confusing Navigation Path,' 'Low Contrast CTA,' 'Inefficient Multi-Step Form').
Severity: An assessment of the issue's impact on the user experience. Use one of the following predefined categories:
High: Prevents task completion, causes significant user frustration or errors.
Medium: Causes some difficulty or inefficiency but doesn't block task completion.
Low: Minor inconvenience, or opportunity for optimization, but doesn't significantly hinder the user.
IssueDescription: A detailed explanation of the problem. Describe what the user is trying to do, what happens in the video at this timestamp, and why it constitutes a UX/UI issue. Reference specific visual elements or interactions.
Recommendations: Provide clear, actionable, and specific recommendations to address the identified issue. If multiple recommendations apply, list them as bullet points.
Example Recommendation: 'Increase the font size of the primary call-to-action button to at least 16px to improve readability and contrast.'
Example Recommendation: 'Reduce the checkout process to a single page by combining shipping and payment information sections.'

Key Guidelines for Analysis & Reporting:

Focus on Actionable Insights: Prioritize issues that, if addressed, would tangibly improve the user experience.
Be Specific: Vague descriptions are not helpful. Pinpoint exact elements, interactions, and moments.
Provide Rationale: Briefly explain why something is an issue (e.g., ‘violates established usability heuristics,’ ‘creates cognitive load,’ ‘is inconsistent with platform conventions’).
Maintain Objectivity: Base your analysis on established UX/UI principles and observed user behavior in the frames of the video.
'Escape Hatch’ for Ambiguity: If a particular segment of the frames of the video is unclear, or if you lack sufficient information to make a confident assessment, explicitly state this. Do not guess. You can note it as: DebugInfo: ‘Could not determine [specifics] due to [reason, e.g., frames of the video quality, unclear user intent].’
Consider the Flow Timeline (as per mockup): If possible, group findings by the larger ‘steps’ in the user's workflow (e.g., Landing Page, Product Selection, Checkout Form). If the frames of the video shows distinct phases, try to categorize your findings under these phases.
Example of a Single Issue Output (Conceptual):

Timestamp: 0:47
PainPointTitle: Checkout Form - Multi-Step Confusion
Severity: High
IssueDescription: At 0:47, the user hesitates when moving from the shipping address step to the payment information step in the checkout form. The progress indicators are not clear, and the user seems unsure if their previous information was saved. This multi-step process without clear feedback is causing friction and potential abandonment.
Recommendations:
•⁠  ⁠Reduce the checkout to a single page to display all required fields at once.
•⁠  ⁠If a multi-step process is retained, add clear, prominent progress indicators (e.g., ‘Step 1 of 3: Shipping’).
•⁠  ⁠Improve error message clarity and placement for any mistakes made during form filling.


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
