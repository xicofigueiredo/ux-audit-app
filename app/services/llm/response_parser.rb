# app/services/llm/response_parser.rb
module Llm
  class ResponseParser < BaseService
    include LlmConfig

    # JSON Schema for response validation
    RESPONSE_SCHEMA = {
      type: "object",
      required: ["workflowSummary", "identifiedIssues"],
      properties: {
        workflowSummary: {
          type: "object",
          required: ["workflowtitle", "userGoal", "workflowSteps", "totalFramesAnalyzed"],
          properties: {
            workflowtitle: { type: "string", minLength: 1 },
            userGoal: { type: "string", minLength: 1 },
            workflowSteps: {
              type: "array",
              items: { type: "string", minLength: 1 },
              minItems: 1
            },
            totalFramesAnalyzed: { type: "string", minLength: 1 }
          }
        },
        identifiedIssues: {
          type: "array",
          items: {
            type: "object",
            required: ["frameReference", "painPointTitle", "severity", "issueDescription", "recommendations"],
            properties: {
              frameReference: { type: "string", minLength: 1 },
              painPointTitle: { type: "string", minLength: 1 },
              severity: { type: "string", enum: ["High", "Medium", "Low"] },
              issueDescription: { type: "string", minLength: 10 },
              recommendations: {
                type: "array",
                items: { type: "string", minLength: 1 },
                minItems: 1
              }
            }
          }
        }
      }
    }.freeze

    # Response quality scoring weights
    QUALITY_WEIGHTS = {
      completeness: 0.3,
      specificity: 0.25,
      actionability: 0.25,
      consistency: 0.2
    }.freeze

    def initialize
      super
      @schema_validator = JSON::Validator.new(RESPONSE_SCHEMA)
    end

    # Parse and validate LLM response
    def parse_response(raw_response, context: {})
      log_info("Parsing response", context: context)
      
      parsed_response = extract_json(raw_response)
      validated_response = validate_response(parsed_response)
      quality_score = calculate_quality_score(validated_response)
      
      {
        data: validated_response,
        quality_score: quality_score,
        version: "1.0",
        parsed_at: Time.current
      }
    rescue => error
      log_error("Response parsing failed", error: error, context: context)
      handle_parsing_error(error, raw_response, context)
    end

    # Parse function call response
    def parse_function_call_response(response, context: {})
      log_info("Parsing function call response", context: context)
      
      function_call = response.dig("choices", 0, "message", "function_call")
      return handle_missing_function_call(response, context) unless function_call
      
      arguments = JSON.parse(function_call["arguments"])
      validated_response = validate_response(arguments)
      quality_score = calculate_quality_score(validated_response)
      
      {
        data: validated_response,
        quality_score: quality_score,
        version: "1.0",
        parsed_at: Time.current,
        function_name: function_call["name"]
      }
    rescue => error
      log_error("Function call parsing failed", error: error, context: context)
      handle_parsing_error(error, response, context)
    end

    # Validate response against schema
    def validate_response(response)
      unless @schema_validator.validate(response)
        errors = @schema_validator.validate_with_errors(response)
        raise ValidationError, "Response validation failed: #{errors.join(', ')}"
      end
      
      # Additional business logic validation
      validate_business_rules(response)
      response
    end

    # Calculate response quality score (0-100)
    def calculate_quality_score(response)
      scores = {
        completeness: calculate_completeness_score(response),
        specificity: calculate_specificity_score(response),
        actionability: calculate_actionability_score(response),
        consistency: calculate_consistency_score(response)
      }
      
      weighted_score = scores.map do |metric, score|
        score * QUALITY_WEIGHTS[metric]
      end.sum
      
      (weighted_score * 100).round(2)
    end

    # Handle partial responses
    def handle_partial_response(response, context: {})
      log_warn("Handling partial response", context: context)
      
      # Try to extract what we can from the partial response
      extracted_data = extract_partial_data(response)
      
      {
        data: extracted_data,
        quality_score: 0.0,
        version: "1.0",
        parsed_at: Time.current,
        partial: true,
        recovery_attempted: true
      }
    end

    private

    def extract_json(text)
      return text if text.is_a?(Hash)
      return {} if text.blank?
      
      # Find JSON object in text
      first_brace = text.index('{')
      last_brace = text.rindex('}')
      
      return {} if first_brace.nil? || last_brace.nil?
      
      json_text = text[first_brace..last_brace]
      JSON.parse(json_text)
    rescue JSON::ParserError => e
      log_error("JSON parsing failed", error: e)
      raise ParsingError, "Invalid JSON format: #{e.message}"
    end

    def validate_business_rules(response)
      # Ensure workflow title is not too long
      title = response.dig("workflowSummary", "workflowtitle")
      if title && title.length > 100
        raise ValidationError, "Workflow title too long (max 100 characters)"
      end
      
      # Ensure at least one issue is identified
      issues = response.dig("identifiedIssues")
      if issues.nil? || issues.empty?
        raise ValidationError, "No UX issues identified"
      end
      
      # Validate severity distribution
      severities = issues.map { |issue| issue["severity"] }
      if severities.all? { |s| s == "Low" }
        log_warn("All issues marked as Low severity - may indicate analysis quality issue")
      end
    end

    def calculate_completeness_score(response)
      required_fields = [
        "workflowSummary.workflowtitle",
        "workflowSummary.userGoal", 
        "workflowSummary.workflowSteps",
        "workflowSummary.totalFramesAnalyzed"
      ]
      
      present_fields = required_fields.count do |field|
        response.dig(*field.split('.'))
      end
      
      present_fields.to_f / required_fields.length
    end

    def calculate_specificity_score(response)
      issues = response.dig("identifiedIssues") || []
      return 0.0 if issues.empty?
      
      # Check for specific frame references and detailed descriptions
      specific_issues = issues.count do |issue|
        frame_ref = issue["frameReference"]
        description = issue["issueDescription"]
        
        frame_ref.present? && 
        description.present? && 
        description.length > 50 &&
        description.include?("violates") # Indicates heuristic reference
      end
      
      specific_issues.to_f / issues.length
    end

    def calculate_actionability_score(response)
      issues = response.dig("identifiedIssues") || []
      return 0.0 if issues.empty?
      
      # Check for actionable recommendations
      actionable_issues = issues.count do |issue|
        recommendations = issue["recommendations"]
        recommendations.is_a?(Array) && 
        recommendations.length >= 2 &&
        recommendations.any? { |rec| rec.length > 20 }
      end
      
      actionable_issues.to_f / issues.length
    end

    def calculate_consistency_score(response)
      issues = response.dig("identifiedIssues") || []
      return 1.0 if issues.empty?
      
      # Check for consistent formatting and structure
      consistent_issues = issues.count do |issue|
        issue.keys.sort == ["frameReference", "painPointTitle", "severity", "issueDescription", "recommendations"].sort
      end
      
      consistent_issues.to_f / issues.length
    end

    def handle_parsing_error(error, raw_response, context)
      {
        data: {},
        quality_score: 0.0,
        version: "1.0",
        parsed_at: Time.current,
        error: error.message,
        raw_response: raw_response.to_s[0..500] # Truncate for logging
      }
    end

    def handle_missing_function_call(response, context)
      log_error("Missing function call in response", context: context)
      {
        data: {},
        quality_score: 0.0,
        version: "1.0",
        parsed_at: Time.current,
        error: "No function call found in response"
      }
    end

    def extract_partial_data(response)
      # Try to extract any valid data from partial response
      {
        workflowSummary: {
          workflowtitle: "Partial Analysis",
          userGoal: "Analysis incomplete",
          workflowSteps: ["Analysis in progress"],
          totalFramesAnalyzed: "0"
        },
        identifiedIssues: []
      }
    end

    # Custom error classes
    class ValidationError < StandardError; end
    class ParsingError < StandardError; end
  end
end 