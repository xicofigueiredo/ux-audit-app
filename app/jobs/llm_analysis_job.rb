# app/jobs/llm_analysis_job.rb
require 'csv'
require 'json'

class LlmAnalysisJob < ApplicationJob
  queue_as :default

  PROMPT_TEMPLATE = <<-PROMPT

  ### ROLE & GOAL ###
You are a highly sought-after UX/UI Principal Analyst. Your insights are specific, actionable, and grounded in established usability heuristics. You avoid generic advice. Your primary goal is to perform a complete usability audit of a user workflow, represented by a sequence of image frames. You have already analyzed several batches of frames from a user journey video. Now, combine all findings into a single, unified analysis.

### CRITICAL INSTRUCTION: ANALYZE THE ENTIRE FRAME SEQUENCE ###
The image frames are provided in chronological order and represent a user's journey over time. You MUST analyze the entire sequence and distribute your findings across all relevant frames. A good analysis will reference multiple, different frames.

### YOUR STEP-BY-STEP ANALYTICAL PROCESS ###
To ensure a world-class audit, you MUST follow this thinking process:
1.  **Synthesize the Overall Journey:** Review all frames to understand the user's primary goal (e.g., 'User wants to book a one-way flight from Lisbon to London').
2.  **Deconstruct into Key Steps:** Group the frames into the distinct stages of the journey (e.g., '1. Flight Search', '2. Date Selection', '3. Results Review', '4. Passenger Details').
3.  **Analyze Each Step for Friction:** For each step, meticulously examine the frames. For every issue you find, you must first state the usability principle or heuristic being violated (e.g., 'This violates the principle of Recognition rather than recall...') before describing the problem.

### OUTPUT FORMAT: STRICT JSON ###
- Your entire response MUST be a single, valid JSON object.
- Do NOT include any text, notes, or explanations outside of the JSON structure. Your response must begin with '{' and end with '}'.
- NEVER start you output with a non JSON, like "i'm" or any other thing other than a JSON object.

{
  "workflowSummary": {
    "workflowtitle": "A short title of the workflow"
    "userGoal": "A string describing the user's primary objective.",
    "workflowSteps": [
      "An array of strings listing the distinct workflow steps you identified."
    ],
    "totalFramesAnalyzed": "The total number of frames you analyzed."
  },
  "identifiedIssues": [
    {
      "frameReference": "A string indicating the specific frame number(s) where the issue is most evident (e.g., 'Frame 5', 'Frames 12-14').",
      "painPointTitle": "A concise, descriptive title for the UX issue.",
      "severity": "A string with one of three exact values: 'High', 'Medium', or 'Low'.",
      "issueDescription": "A detailed explanation of the problem. Start with the heuristic being violated. Then describe the issue with specific references to UI elements in the frames.",
      "recommendations": [
        "An array of strings, where each string is a concrete, actionable recommendation."
      ]
    }
  ]
}

  Your response must be a single valid JSON object and nothing else. Do not include any text, notes, or explanations outside the JSON structure. Your response must begin with '{' and end with '}'.
  **Do not use any other top-level keys. Do not include any text, notes, or explanations outside the JSON object. Your response must begin with '{' and end with '}'.**
  PROMPT

  BATCH_SIZE = 20

  def extract_json(text)
    first_brace = text.index('{')
    last_brace = text.rindex('}')
    return text if first_brace.nil? || last_brace.nil?
    text[first_brace..last_brace]
  end

  def map_llm_output_to_schema(parsed)
    # If already in correct format, return as is
    if parsed.is_a?(Hash) && parsed.key?("workflowSummary") && parsed.key?("identifiedIssues")
      return parsed
    end
    # Try to map common alternative keys to expected schema
    mapped = {}
    if parsed.is_a?(Hash)
      # Handle flattened structure
      if parsed.key?("userGoal") && parsed.key?("workflowSteps") && parsed.key?("totalFramesAnalyzed")
        mapped["workflowSummary"] = {
          "userGoal" => parsed["userGoal"],
          "workflowSteps" => parsed["workflowSteps"],
          "totalFramesAnalyzed" => parsed["totalFramesAnalyzed"]
        }
      end
      # Map issues/recommendations
      if parsed.key?("commonIssues")
        mapped["identifiedIssues"] = parsed["commonIssues"]
      elsif parsed.key?("holisticRecommendations")
        mapped["identifiedIssues"] = parsed["holisticRecommendations"]
      end
      # If both mapped, return
      if mapped.key?("workflowSummary") && mapped.key?("identifiedIssues")
        Rails.logger.error("LLM mapping: mapped alternative keys to expected schema")
        return mapped
      end
    end
    # If not mappable, return original
    parsed
  end

  def perform(video_audit_id)
    audit = VideoAudit.find(video_audit_id)
    frame_paths = Array(audit.frames)
    batch_count = (frame_paths.size / BATCH_SIZE.to_f).ceil
    batch_summaries = []
    api_key = ENV['OPENAI_API_KEY']
    if api_key.blank?
      raise "OpenAI API key is not set. Please check your .env file"
    end
    client = OpenAI::Client.new(
      access_token: api_key,
      uri_base: "https://api.openai.com/v1",
      request_timeout: 300
    )
    begin
      frame_paths.each_slice(BATCH_SIZE).with_index do |batch, idx|
        prompt = <<~PROMPT
          These are frames #{idx * BATCH_SIZE + 1}-#{[frame_paths.size, (idx + 1) * BATCH_SIZE].min} of #{frame_paths.size} from a single user journey. Please analyze and summarize key UX issues, noting that more frames will follow if this is not the last batch.\n\n#{PROMPT_TEMPLATE}
        PROMPT
        messages = [
          { role: "user", content: [{ type: "text", text: prompt }] + batch.map { |frame| { type: "image_url", image_url: { url: "data:image/jpeg;base64,#{Base64.strict_encode64(File.read(frame))}", detail: "low" } } } }
        ]
        response = client.chat(parameters: { model: "gpt-4o", messages: messages, max_tokens: 3072 })
        summary = response.dig("choices", 0, "message", "content")
        # Use JSON extraction helper for batch summary
        extracted_summary = extract_json(summary)
        LlmPartialResponse.create!(video_audit: audit, chunk_index: idx, result: extracted_summary, status: "completed")
        batch_summaries << extracted_summary
      end
      # Synthesize holistic analysis
      synthesis_prompt = <<~PROMPT
        Combine the following batch findings into a single, unified analysis. Output only a single valid JSON object matching the schema below, with no extra text.

        Batch Findings:
        #{batch_summaries.join("\n\n")}

        {
          "workflowSummary": {
            "userGoal": "",
            "workflowSteps": [],
            "totalFramesAnalyzed": ""
          },
          "identifiedIssues": []
        }

        Instructions:
        - Fill in the values for each field based on the batch findings.
        - Do not add any other keys or text.
        - Your response must begin with '{' and end with '}'.
      PROMPT
      messages = [
        { role: "user", content: [{ type: "text", text: synthesis_prompt }] }
      ]
      response = client.chat(parameters: { model: "gpt-4o", messages: messages, max_tokens: 3072 })
      holistic_analysis = response.dig("choices", 0, "message", "content")
      begin
        # Use JSON extraction helper for holistic analysis
        parsed_analysis = JSON.parse(extract_json(holistic_analysis))
        Rails.logger.error("LLM Parsed Analysis: #{parsed_analysis.inspect}")
        # Map alternative keys to expected schema if needed
        parsed_analysis = map_llm_output_to_schema(parsed_analysis)
        required_keys = %w[workflowSummary identifiedIssues]
        unless required_keys.all? { |k| parsed_analysis.key?(k) }
          # Fallback: unwrap if single top-level key whose value is a Hash with required keys
          if parsed_analysis.is_a?(Hash) && parsed_analysis.keys.size == 1
            inner = parsed_analysis.values.first
            if inner.is_a?(Hash) && required_keys.all? { |k| inner.key?(k) }
              Rails.logger.error("LLM fallback: unwrapped inner object from key #{parsed_analysis.keys.first}")
              parsed_analysis = inner
            end
          end
        end
        unless required_keys.all? { |k| parsed_analysis.key?(k) }
          raise "LLM response missing required keys: #{parsed_analysis.keys}"
        end
      rescue JSON::ParserError => e
        raise "OpenAI response is not valid JSON: #{e.message}"
      end
      audit.update!(status: 'completed', llm_response: parsed_analysis)
      CleanupJob.perform_later(audit.id)
    rescue => e
      Rails.logger.error("LLM Analysis Error: #{e.message}")
      Rails.logger.error(e.backtrace.join("\n"))
      audit.update!(status: 'failed', llm_response: "Error analyzing frames: #{e.message}")
      CleanupJob.perform_later(audit.id)
    end
  end
end
