# app/jobs/llm_analysis_job.rb
require 'csv'
require 'json'

class LlmAnalysisJob < ApplicationJob
  include AnalyticsHelper
  queue_as :default
  retry_on StandardError, wait: :exponentially_longer, attempts: 3

  PROMPT_TEMPLATE = <<-PROMPT

  ### ROLE & GOAL ###
You are a highly sought-after UX/UI Principal Analyst. Your insights are specific, actionable, and grounded in established usability heuristics. You avoid generic advice. Your primary goal is to perform a complete usability audit of a user workflow, represented by a sequence of image frames. You have already analyzed several batches of frames from a user journey video. Now, combine all findings into a single, unified analysis.

### RELEVANT UX KNOWLEDGE BASE ###
You have access to a comprehensive knowledge base of UX/UI design principles, including:
{ux_knowledge_context}

Use this knowledge base to ground your analysis in established principles and cite specific heuristics when identifying issues.

### CRITICAL INSTRUCTION: ANALYZE THE ACTUAL FRAMES PROVIDED ###
The image frames are provided in chronological order and represent a REAL user's journey that you are viewing. You MUST:
1. Look at the ACTUAL screenshots provided and describe what you SEE in those specific frames
2. Reference SPECIFIC frame numbers where issues occur (e.g., "Frame 5", "Frames 12-14")
3. Describe SPECIFIC UI elements visible in the frames (e.g., "the blue 'Submit' button", "the search dropdown menu")
4. NEVER provide generic heuristic evaluations without connecting them to specific frames
5. NEVER describe a hypothetical interface - only analyze what is ACTUALLY in the frames

### WARNING: UNACCEPTABLE RESPONSES ###
DO NOT provide responses like:
- "Lack of visibility of system status" without specifying which frame shows this
- "Inconsistent use of terminology" without showing where this appears in the frames
- Generic lists of heuristic violations that could apply to any interface

EVERY issue must have:
- A SPECIFIC frameReference (required field)
- A SPECIFIC painPointTitle describing what is wrong in those frames (required field)
- An issueDescription that references ACTUAL UI elements you see in the frames

### YOUR STEP-BY-STEP ANALYTICAL PROCESS ###
To ensure a world-class audit, you MUST follow this thinking process:
1.  **Synthesize the Overall Journey:** Review all frames to understand the user's primary goal based on what you SEE in the frames.
2.  **Deconstruct into Key Steps:** Group the frames into the distinct stages of the journey based on VISIBLE changes in the interface.
3.  **Analyze Each Step for Friction:** For each step, meticulously examine the frames. For every issue you find, you must:
     - Note the SPECIFIC frame number(s) where it occurs
     - State the specific usability principle or heuristic being violated
     - Describe the SPECIFIC UI elements and interactions you observe in those frames

### OUTPUT FORMAT: STRICT JSON ###
- Your entire response MUST be a single, valid JSON object.
- Do NOT include any text, notes, or explanations outside of the JSON structure. Your response must begin with '{' and end with '}'.
- NEVER start your output with a non-JSON string like "here is" or "i'm" - start ONLY with '{'

### REQUIRED SCHEMA - EVERY FIELD IS MANDATORY ###
{
  "workflowSummary": {
    "workflowtitle": "A short title of the workflow based on what you see in the frames",
    "userGoal": "A string describing the user's primary objective based on the visible UI.",
    "workflowSteps": [
      "An array of strings listing the distinct workflow steps you identified from the frames."
    ],
    "totalFramesAnalyzed": "The exact number of frames you analyzed (e.g., '25')"
  },
  "identifiedIssues": [
    {
      "frameReference": "REQUIRED: Specific frame number(s) where the issue is visible (e.g., 'Frame 5', 'Frames 12-14'). NEVER omit this field.",
      "painPointTitle": "REQUIRED: A concise, descriptive title for the UX issue you see in the frames. NEVER omit this field.",
      "severity": "A string with one of three exact values: 'High', 'Medium', or 'Low'.",
      "issueDescription": "A detailed explanation referencing the SPECIFIC UI elements you see in the frames. Start with the heuristic being violated, then describe what you observe.",
      "recommendations": [
        "An array of strings, where each string is a concrete, actionable recommendation based on the observed issue."
      ]
    }
  ]
}

### EXAMPLE OF CORRECT OUTPUT ###
{
  "workflowSummary": {
    "workflowtitle": "User Registration Flow",
    "userGoal": "Complete account registration on the website",
    "workflowSteps": ["Landing on registration page", "Filling form fields", "Email verification", "Profile completion"],
    "totalFramesAnalyzed": "15"
  },
  "identifiedIssues": [
    {
      "frameReference": "Frame 3",
      "painPointTitle": "Password field lacks visibility of requirements",
      "severity": "Medium",
      "issueDescription": "Violates Nielsen's Heuristic #5: Error Prevention. In Frame 3, the password input field is visible but provides no indication of password requirements (length, special characters, etc.). Users can only discover requirements after submission failure.",
      "recommendations": ["Add real-time password requirements display next to the input field", "Show checkmarks as requirements are met"]
    }
  ]
}

  Your response must be a single valid JSON object and nothing else. Do not include any text, notes, or explanations outside the JSON structure. Your response must begin with '{' and end with '}'.
  **Every issue MUST have both frameReference and painPointTitle fields. Responses missing these fields will be rejected.**
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
        # Try to add workflowtitle if present
        mapped["workflowSummary"]["workflowtitle"] = parsed["workflowtitle"] if parsed.key?("workflowtitle")
      end

      # Map issues/recommendations with normalization
      issues_array = nil
      if parsed.key?("identifiedIssues")
        issues_array = parsed["identifiedIssues"]
      elsif parsed.key?("commonIssues")
        issues_array = parsed["commonIssues"]
      elsif parsed.key?("holisticRecommendations")
        issues_array = parsed["holisticRecommendations"]
      end

      # Normalize issues to match expected schema
      if issues_array.is_a?(Array)
        mapped["identifiedIssues"] = issues_array.map do |issue|
          normalize_issue(issue)
        end
      end

      # If both mapped, return
      if mapped.key?("workflowSummary") && mapped.key?("identifiedIssues")
        Rails.logger.warn("LLM mapping: mapped alternative keys to expected schema")
        return mapped
      end
    end
    # If not mappable, return original
    parsed
  end

  def normalize_issue(issue)
    return issue unless issue.is_a?(Hash)

    normalized = {}

    # Map frameReference (required field)
    normalized["frameReference"] = issue["frameReference"] || issue["frame"] || "Frame not specified"

    # Map painPointTitle (required field)
    normalized["painPointTitle"] = issue["painPointTitle"] || issue["title"] || issue["issue"] || "Untitled Issue"

    # Map severity
    normalized["severity"] = issue["severity"] || "Medium"

    # Map issueDescription
    description_parts = []
    description_parts << "Violates: #{issue['heuristic']}" if issue["heuristic"]
    description_parts << issue["issueDescription"] if issue["issueDescription"]
    description_parts << issue["description"] if issue["description"]
    normalized["issueDescription"] = description_parts.any? ? description_parts.join(". ") : "No description provided"

    # Map recommendations
    normalized["recommendations"] = issue["recommendations"] || issue["recommendation"] || []
    normalized["recommendations"] = [normalized["recommendations"]] if normalized["recommendations"].is_a?(String)

    normalized
  end

  def perform(video_audit_id)
    audit = VideoAudit.find(video_audit_id)
    frame_paths = Array(audit.frames)
    batch_count = (frame_paths.size / BATCH_SIZE.to_f).ceil
    batch_summaries = []

    # Ensure we're in the correct processing stage
    audit.update!(processing_stage: 'analyzing_ai') if audit.processing_stage != 'analyzing_ai'

    # Initialize UX knowledge retrieval service
    @ux_knowledge_service = UxKnowledgeRetrievalService.new

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
        # Get relevant UX knowledge context for this batch
        ux_context = get_ux_knowledge_context_for_batch(batch, idx)

        # Prepare prompt with UX knowledge context
        prompt_with_context = PROMPT_TEMPLATE.gsub('{ux_knowledge_context}', ux_context)

        prompt = <<~PROMPT
          These are frames #{idx * BATCH_SIZE + 1}-#{[frame_paths.size, (idx + 1) * BATCH_SIZE].min} of #{frame_paths.size} from a single user journey. Please analyze and summarize key UX issues, noting that more frames will follow if this is not the last batch.\n\n#{prompt_with_context}
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

      # Update processing stage to generating report
      audit.update!(processing_stage: 'generating_report')
      track_processing_stage(audit.id, 'generating_report')

      # Get comprehensive UX knowledge context for synthesis
      synthesis_ux_context = get_comprehensive_ux_context(batch_summaries)

      # Synthesize holistic analysis
      synthesis_prompt = <<~PROMPT
        Combine the following batch findings into a single, unified analysis. Use the UX knowledge base provided to ensure all recommendations are grounded in established principles.

        ### UX KNOWLEDGE BASE ###
        #{synthesis_ux_context}

        ### BATCH FINDINGS ###
        #{batch_summaries.join("\n\n")}

        Output only a single valid JSON object matching the schema below, with no extra text:

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
        - Ensure all issues reference specific heuristics from the knowledge base.
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
        Rails.logger.info("LLM Parsed Analysis: #{parsed_analysis.inspect}")

        # Map alternative keys to expected schema if needed
        parsed_analysis = map_llm_output_to_schema(parsed_analysis)

        required_keys = %w[workflowSummary identifiedIssues]
        unless required_keys.all? { |k| parsed_analysis.key?(k) }
          # Fallback: unwrap if single top-level key whose value is a Hash with required keys
          if parsed_analysis.is_a?(Hash) && parsed_analysis.keys.size == 1
            inner = parsed_analysis.values.first
            if inner.is_a?(Hash) && required_keys.all? { |k| inner.key?(k) }
              Rails.logger.warn("LLM fallback: unwrapped inner object from key #{parsed_analysis.keys.first}")
              parsed_analysis = inner
            end
          end
        end

        unless required_keys.all? { |k| parsed_analysis.key?(k) }
          raise "LLM response missing required keys: #{parsed_analysis.keys}"
        end

        # Validate response quality
        validation_errors = validate_llm_response(parsed_analysis)
        if validation_errors.any?
          Rails.logger.error("LLM response validation failed: #{validation_errors.join(', ')}")
          raise "LLM response quality validation failed: #{validation_errors.join(', ')}"
        end

      rescue JSON::ParserError => e
        raise "OpenAI response is not valid JSON: #{e.message}"
      end
      audit.update!(status: 'completed', llm_response: parsed_analysis)

      # Save issue screenshots based on frameReference
      save_issue_screenshots(audit, parsed_analysis, frame_paths)

      CleanupJob.perform_later(audit.id)
    rescue => e
      Rails.logger.error("LLM Analysis Error: #{e.message}")
      Rails.logger.error(e.backtrace.join("\n"))

      # Provide more specific error messages based on the error type
      error_message = case e.message
      when /OpenAI API key is not set/
        "Our AI analysis service is temporarily unavailable. Please try again later."
      when /timeout/i
        "The analysis is taking longer than expected. Please try again with a shorter video."
      when /rate limit/i
        "Too many requests. Please wait a moment and try again."
      when /invalid JSON/i
        "There was an error processing the AI response. Please try again."
      when /missing required keys/i
        "The AI analysis was incomplete. Please try again."
      else
        "We encountered an error while analyzing your video. Please try again or contact support if the problem persists."
      end

      # Track LLM analysis failure
      track_error('llm_analysis_failed', 'llm_analysis_job', e.message)

      audit.update!(
        status: 'failed',
        llm_response: { error: error_message },
        processing_stage: 'failed'
      )
      CleanupJob.perform_later(audit.id)
    end
  end

  private

  def validate_llm_response(parsed_analysis)
    errors = []

    # Check if we have issues
    issues = parsed_analysis.dig('identifiedIssues')
    if issues.nil? || !issues.is_a?(Array) || issues.empty?
      errors << "No issues identified in response"
      return errors
    end

    # Check each issue for required fields and quality
    issues.each_with_index do |issue, idx|
      unless issue.is_a?(Hash)
        errors << "Issue ##{idx} is not a hash"
        next
      end

      # Check for required frameReference field
      frame_ref = issue['frameReference']
      if frame_ref.nil? || frame_ref.to_s.strip.empty?
        errors << "Issue ##{idx} missing frameReference"
      elsif frame_ref.to_s.downcase.include?('not specified') || frame_ref.to_s.strip == ""
        errors << "Issue ##{idx} has placeholder frameReference: '#{frame_ref}'"
      end

      # Check for required painPointTitle field
      title = issue['painPointTitle']
      if title.nil? || title.to_s.strip.empty?
        errors << "Issue ##{idx} missing painPointTitle"
      elsif title.to_s.downcase.include?('untitled') || title.to_s.strip.length < 10
        errors << "Issue ##{idx} has generic/placeholder painPointTitle: '#{title}'"
      end

      # Check for generic heuristic-only responses (likely not frame-specific)
      description = issue['issueDescription'].to_s
      if description.empty?
        errors << "Issue ##{idx} has empty issueDescription"
      elsif is_generic_response?(description, title.to_s)
        errors << "Issue ##{idx} appears to be a generic heuristic evaluation without frame-specific details"
      end
    end

    # Check if ALL issues seem generic (likely a failed analysis)
    if issues.length > 5 && issues.all? { |i| is_generic_issue?(i) }
      errors << "All issues appear to be generic heuristic evaluations rather than frame-specific analysis"
    end

    errors
  end

  def is_generic_response?(description, title)
    # Check if response is just a generic heuristic statement without specific UI details
    generic_patterns = [
      /^(lack of|no|insufficient|inadequate|poor)/i,
      /^(inconsistent|unclear|vague|ambiguous)/i,
      /without (specific|clear|explicit) (reference|mention|detail)/i
    ]

    # If description is very short and matches generic patterns, it's likely generic
    if description.length < 100 && generic_patterns.any? { |pattern| title.match?(pattern) }
      return true
    end

    # Check if description has specific UI element references (expanded list)
    has_ui_specifics = description.match?(/button|field|menu|dropdown|icon|label|form|input|text|image|link|nav|header|footer|modal|dialog|checkbox|radio|toggle|slider|card|panel|section|div|element|bar|indicator|feedback|message|notification|timer|counter|display|screen|page|view/i)

    # Also accept if it mentions workflow/process/interaction patterns
    has_workflow_mentions = description.match?(/progress|selection|cancellation|recording|session|duration|time|endpoint|step|action|requirement|visible|visibility|status|state|indication/i)

    # Only reject if BOTH are missing AND description is short
    !has_ui_specifics && !has_workflow_mentions && description.length < 150
  end

  def is_generic_issue?(issue)
    return true unless issue.is_a?(Hash)

    frame_ref = issue['frameReference'].to_s
    title = issue['painPointTitle'].to_s
    description = issue['issueDescription'].to_s

    # Check for placeholder or missing values
    return true if frame_ref.include?('not specified') || frame_ref.strip.empty?
    return true if title.include?('Untitled') || title.strip.length < 10
    return true if is_generic_response?(description, title)

    false
  end

  def get_ux_knowledge_context_for_batch(batch, batch_index)
    # For now, get general UX principles for each batch
    # In the future, this could be more sophisticated by analyzing frame content

    context_categories = ['usability', 'accessibility', 'design_systems']
    selected_category = context_categories[batch_index % context_categories.length]

    @ux_knowledge_service.search_heuristics_by_category(selected_category)
  end

  def get_comprehensive_ux_context(batch_summaries)
    # Analyze batch summaries to understand what UX concepts are relevant
    combined_summaries = batch_summaries.join(" ")

    # Get relevant context based on the analysis so far
    @ux_knowledge_service.retrieve_for_ux_analysis(combined_summaries)
  end

  def save_issue_screenshots(audit, parsed_analysis, frame_paths)
    return unless parsed_analysis.is_a?(Hash)
    issues = parsed_analysis['identifiedIssues']
    return unless issues.is_a?(Array)

    issues.each_with_index do |issue, index|
      frame_reference = issue['frameReference']
      next unless frame_reference.present?

      begin
        # Extract AI's referenced frames
        ai_frames = extract_frame_range(frame_reference)
        next if ai_frames.empty?

        # Expand with context (±2 frames) and cap at 7 frames max
        all_frames = expand_frame_range(ai_frames, context_frames: 2, max_frames: 7)

        Rails.logger.info "Issue ##{index}: AI frames #{ai_frames.inspect}, expanded to #{all_frames.inspect}"

        # Save all frames in the expanded range
        all_frames.each_with_index do |frame_num, seq|
          frame_file = find_frame_file(frame_paths, frame_num)
          next unless frame_file && File.exist?(frame_file)

          # Read and encode the frame as base64
          image_data = Base64.strict_encode64(File.read(frame_file))

          # Create IssueScreenshot record
          audit.issue_screenshots.create!(
            issue_index: index,
            frame_sequence: seq,
            frame_number: frame_num,
            is_primary: ai_frames.include?(frame_num),
            image_data: image_data
          )

          Rails.logger.info "Saved frame #{frame_num} (seq: #{seq}, primary: #{ai_frames.include?(frame_num)}) for issue ##{index}"
        end
      rescue => e
        Rails.logger.error "Failed to save screenshots for issue ##{index}: #{e.message}"
        Rails.logger.error e.backtrace.join("\n")
      end
    end
  end

  def extract_first_frame_number(frame_reference)
    # Handle various formats: "Frame 5", "Frames 12-14", "Frame 3", etc.
    match = frame_reference.match(/\d+/)
    match ? match[0].to_i : nil
  end

  def extract_frame_range(frame_reference)
    # Extract all frame numbers from reference
    # "Frame 5" → [5]
    # "Frames 12-14" → [12, 13, 14]
    # "Frame 10, 12-14" → [10, 12, 13, 14]
    return [] unless frame_reference.present?

    frames = []

    # Match range patterns like "12-14"
    frame_reference.scan(/(\d+)-(\d+)/).each do |start_frame, end_frame|
      frames.concat((start_frame.to_i..end_frame.to_i).to_a)
    end

    # Match single frame patterns like "Frame 5"
    frame_reference.scan(/\b(\d+)\b/).each do |match|
      frame_num = match[0].to_i
      frames << frame_num unless frames.include?(frame_num)
    end

    frames.uniq.sort
  end

  def expand_frame_range(ai_frames, context_frames: 2, max_frames: 7)
    # Expand AI's referenced frames with context
    # ai_frames: [12] → returns [10, 11, 12, 13, 14]
    # ai_frames: [12, 13, 14] → returns [10, 11, 12, 13, 14, 15, 16]
    return [] if ai_frames.empty?

    expanded = []
    ai_frames.each do |frame|
      range_start = [frame - context_frames, 1].max
      range_end = frame + context_frames
      expanded.concat((range_start..range_end).to_a)
    end

    expanded = expanded.uniq.sort

    # Cap at max_frames to avoid carousel bloat
    if expanded.length > max_frames
      # Find the center point (middle of AI's range)
      mid_point = ai_frames[ai_frames.length / 2]
      half_range = max_frames / 2
      range_start = [mid_point - half_range, 1].max
      range_end = mid_point + half_range
      expanded = (range_start..range_end).to_a
    end

    expanded
  end

  def find_frame_file(frame_paths, frame_number)
    # Frame files are named like: frame_0001.jpg, frame_0002.jpg, etc.
    # Find the file that matches the frame number
    frame_paths.find do |path|
      path.match(/frame_(\d+)\.jpg$/) && $1.to_i == frame_number
    end
  end
end
