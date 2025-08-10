# app/services/llm/function_calling_service.rb
module Llm
  class FunctionCallingService < BaseService

    # Enhanced function schema for GPT-5
    FUNCTION_SCHEMA = {
      name: "analyze_ux_workflow",
      description: "Analyze a user workflow video and identify UX issues with detailed recommendations",
      parameters: {
        type: "object",
        properties: {
          workflowSummary: {
            type: "object",
            description: "Summary of the user workflow and goals",
            properties: {
              workflowtitle: {
                type: "string",
                description: "A short, descriptive title for the workflow (e.g., 'Gift recommendation flow', 'Checkout process', 'User onboarding')",
                maxLength: 100
              },
              userGoal: {
                type: "string",
                description: "A clear description of what the user is trying to accomplish in this workflow",
                maxLength: 500
              },
              workflowSteps: {
                type: "array",
                description: "The distinct steps the user takes to complete their goal",
                items: {
                  type: "string",
                  description: "A single step in the workflow",
                  maxLength: 200
                },
                minItems: 1,
                maxItems: 20
              },
              totalFramesAnalyzed: {
                type: "string",
                description: "The total number of frames analyzed in this batch or complete analysis"
              }
            },
            required: ["workflowtitle", "userGoal", "workflowSteps", "totalFramesAnalyzed"]
          },
          identifiedIssues: {
            type: "array",
            description: "UX issues identified in the workflow",
            items: {
              type: "object",
              description: "A specific UX issue with recommendations",
              properties: {
                frameReference: {
                  type: "string",
                  description: "Specific frame numbers where the issue is evident (e.g., 'Frame 5', 'Frames 12-14', '00:15-00:20')",
                  maxLength: 50
                },
                painPointTitle: {
                  type: "string",
                  description: "A concise, descriptive title for the UX issue",
                  maxLength: 150
                },
                severity: {
                  type: "string",
                  enum: ["High", "Medium", "Low"],
                  description: "The severity level of the issue based on user impact and frequency"
                },
                issueDescription: {
                  type: "string",
                  description: "Detailed explanation starting with the usability principle being violated, then describing the specific issue with references to UI elements",
                  maxLength: 1000
                },
                recommendations: {
                  type: "array",
                  description: "Concrete, actionable recommendations to fix the issue",
                  items: {
                    type: "string",
                    description: "A specific recommendation that can be implemented",
                    maxLength: 300
                  },
                  minItems: 1,
                  maxItems: 5
                },
                heuristicViolated: {
                  type: "string",
                  description: "The specific usability heuristic or principle being violated",
                  enum: [
                    "Visibility of system status",
                    "Match between system and real world",
                    "User control and freedom",
                    "Consistency and standards",
                    "Error prevention",
                    "Recognition rather than recall",
                    "Flexibility and efficiency of use",
                    "Aesthetic and minimalist design",
                    "Help users recognize, diagnose, and recover from errors",
                    "Help and documentation"
                  ]
                },
                impactScore: {
                  type: "number",
                  description: "Impact score from 1-10 (10 being highest impact)",
                  minimum: 1,
                  maximum: 10
                }
              },
              required: ["frameReference", "painPointTitle", "severity", "issueDescription", "recommendations", "heuristicViolated", "impactScore"]
            },
            minItems: 0,
            maxItems: 20
          },
          analysisMetadata: {
            type: "object",
            description: "Metadata about the analysis",
            properties: {
              analysisType: {
                type: "string",
                enum: ["batch", "synthesis", "complete"],
                description: "Type of analysis performed"
              },
              confidenceScore: {
                type: "number",
                description: "Confidence in the analysis (0-1)",
                minimum: 0,
                maximum: 1
              },
              processingTime: {
                type: "number",
                description: "Time taken to process this analysis in seconds"
              }
            },
            required: ["analysisType", "confidenceScore"]
          }
        },
        required: ["workflowSummary", "identifiedIssues", "analysisMetadata"]
      }
    }.freeze

    def initialize
      super
      @function_schema = FUNCTION_SCHEMA
    end

    # Generate function calling parameters for API
    def generate_function_parameters
      @function_schema
    end

    # Process function call response
    def process_function_call(response, context: {})
      log_info("Processing function call", context: context)
      
      function_call = extract_function_call(response)
      return handle_missing_function_call(response, context) unless function_call
      
      arguments = parse_function_arguments(function_call["arguments"])
      validated_data = validate_function_data(arguments)
      
      {
        data: validated_data,
        function_name: function_call["name"],
        confidence_score: validated_data.dig("analysisMetadata", "confidenceScore"),
        processing_time: validated_data.dig("analysisMetadata", "processingTime"),
        version: "2.0",
        parsed_at: Time.current
      }
    rescue => error
      log_error("Function call processing failed", error: error, context: context)
      handle_function_call_error(error, response, context)
    end

    # Validate function call data against schema
    def validate_function_data(data)
      # Validate required fields
      validate_required_fields(data)
      
      # Validate data types and constraints
      validate_data_constraints(data)
      
      # Validate business rules
      validate_business_rules(data)
      
      data
    end

    # Check if function calling is supported and enabled
    def function_calling_supported?
      LlmConfig.gpt_5? && ENV.fetch('ENABLE_FUNCTION_CALLING', 'true') == 'true'
    end

    # Generate function calling parameters for API call
    def api_parameters
      return {} unless function_calling_supported?
      
      {
        functions: [generate_function_parameters],
        function_call: { name: "analyze_ux_workflow" }
      }
    end

    private

    def extract_function_call(response)
      # Handle both string and symbol keys
      choices = response["choices"] || response[:choices]
      return nil unless choices&.any?
      
      message = choices[0]["message"] || choices[0][:message]
      return nil unless message
      
      message["function_call"] || message[:function_call]
    end

    def parse_function_arguments(arguments_json)
      JSON.parse(arguments_json)
    rescue JSON::ParserError => e
      log_error("Failed to parse function arguments", error: e)
      raise FunctionCallingError, "Invalid function arguments JSON: #{e.message}"
    end

    def validate_required_fields(data)
      required_fields = [
        "workflowSummary",
        "identifiedIssues", 
        "analysisMetadata"
      ]
      
      missing_fields = required_fields.select { |field| data[field].nil? }
      
      if missing_fields.any?
        raise ValidationError, "Missing required fields: #{missing_fields.join(', ')}"
      end
      
      # Validate workflow summary fields
      workflow_required = ["workflowtitle", "userGoal", "workflowSteps", "totalFramesAnalyzed"]
      missing_workflow = workflow_required.select { |field| data["workflowSummary"][field].blank? }
      
      if missing_workflow.any?
        raise ValidationError, "Missing workflow summary fields: #{missing_workflow.join(', ')}"
      end
    end

    def validate_data_constraints(data)
      # Validate workflow title length
      title = data.dig("workflowSummary", "workflowtitle")
      if title && title.length > 100
        raise ValidationError, "Workflow title too long (max 100 characters)"
      end
      
      # Validate workflow steps
      steps = data.dig("workflowSummary", "workflowSteps")
      if steps && steps.length > 20
        raise ValidationError, "Too many workflow steps (max 20)"
      end
      
      # Validate issues
      issues = data["identifiedIssues"]
      if issues && issues.length > 20
        raise ValidationError, "Too many issues identified (max 20)"
      end
      
      # Validate each issue
      issues&.each_with_index do |issue, index|
        validate_issue(issue, index)
      end
    end

    def validate_issue(issue, index)
      # Validate severity
      unless ["High", "Medium", "Low"].include?(issue["severity"])
        raise ValidationError, "Invalid severity for issue #{index}: #{issue['severity']}"
      end
      
      # Validate impact score
      impact_score = issue["impactScore"]
      if impact_score && (impact_score < 1 || impact_score > 10)
        raise ValidationError, "Invalid impact score for issue #{index}: #{impact_score}"
      end
      
      # Validate heuristic
      valid_heuristics = FUNCTION_SCHEMA.dig(:parameters, :properties, :identifiedIssues, :items, :properties, :heuristicViolated, :enum)
      unless valid_heuristics.include?(issue["heuristicViolated"])
        raise ValidationError, "Invalid heuristic for issue #{index}: #{issue['heuristicViolated']}"
      end
      
      # Validate recommendations
      recommendations = issue["recommendations"]
      if recommendations && recommendations.length > 5
        raise ValidationError, "Too many recommendations for issue #{index} (max 5)"
      end
    end

    def validate_business_rules(data)
      # Ensure at least one issue is identified for complete analysis
      issues = data["identifiedIssues"]
      analysis_type = data.dig("analysisMetadata", "analysisType")
      
      if analysis_type == "complete" && (issues.nil? || issues.empty?)
        log_warn("Complete analysis with no issues identified - may indicate analysis quality issue")
      end
      
      # Validate confidence score
      confidence = data.dig("analysisMetadata", "confidenceScore")
      if confidence && (confidence < 0 || confidence > 1)
        raise ValidationError, "Invalid confidence score: #{confidence}"
      end
    end

    def handle_missing_function_call(response, context)
      log_error("Missing function call in response", context: context)
      {
        data: {},
        function_name: nil,
        confidence_score: 0.0,
        processing_time: 0,
        version: "2.0",
        parsed_at: Time.current,
        error: "No function call found in response"
      }
    end

    def handle_function_call_error(error, response, context)
      {
        data: {},
        function_name: nil,
        confidence_score: 0.0,
        processing_time: 0,
        version: "2.0",
        parsed_at: Time.current,
        error: error.message,
        raw_response: response.to_s[0..500]
      }
    end

    # Custom error classes
    class FunctionCallingError < StandardError; end
    class ValidationError < StandardError; end
  end
end 