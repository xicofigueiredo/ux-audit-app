# app/services/llm/prompt_generator.rb
module Llm
  class PromptGenerator < BaseService
    include LlmConfig

    # System message templates for different models
    SYSTEM_MESSAGES = {
      'gpt-5o' => <<~SYSTEM,
        You are a highly sought-after UX/UI Principal Analyst with 15+ years of experience in user experience design and usability testing. Your insights are specific, actionable, and grounded in established usability heuristics like Nielsen's 10 Usability Heuristics and Norman's Design Principles.

        Your expertise includes:
        - Identifying friction points in user workflows
        - Analyzing visual hierarchy and information architecture
        - Evaluating accessibility and inclusive design
        - Understanding user psychology and behavior patterns
        - Providing concrete, implementable recommendations

        You avoid generic advice and focus on specific, actionable insights that can be immediately implemented by design and development teams.
      SYSTEM
      'gpt-4o' => <<~SYSTEM,
        You are a UX/UI Principal Analyst with expertise in usability testing and user experience design. Your insights are specific, actionable, and grounded in established usability heuristics.

        You focus on:
        - Identifying user workflow friction points
        - Analyzing interface design issues
        - Providing concrete recommendations
        - Understanding user behavior patterns
      SYSTEM
    }.freeze

    # Few-shot examples for better consistency
    FEW_SHOT_EXAMPLES = [
      {
        input: "User clicking through a checkout form",
        output: {
          workflowSummary: {
            workflowtitle: "E-commerce checkout flow",
            userGoal: "Complete a purchase transaction",
            workflowSteps: [
              "Add items to cart",
              "Proceed to checkout",
              "Enter shipping information",
              "Enter payment details",
              "Review and confirm order"
            ],
            totalFramesAnalyzed: "15"
          },
          identifiedIssues: [
            {
              frameReference: "Frames 8-10",
              painPointTitle: "Form validation errors unclear",
              severity: "High",
              issueDescription: "This violates the principle of Error prevention. Form validation errors appear in red text but don't clearly indicate which field needs attention or how to fix the issue.",
              recommendations: [
                "Add field-specific error messages with clear instructions",
                "Use visual indicators (borders, icons) to highlight problematic fields",
                "Provide real-time validation feedback as user types"
              ]
            }
          ]
        }
      }
    ].freeze

    def initialize
      super
      @system_message = SYSTEM_MESSAGES[LlmConfig.model] || SYSTEM_MESSAGES['gpt-4o']
    end

    # Generate prompts for batch analysis
    def generate_batch_prompt(batch_frames, batch_index, total_frames)
      {
        system_message: @system_message,
        user_message: build_batch_user_message(batch_frames, batch_index, total_frames),
        temperature: LlmConfig.temperature,
        max_tokens: LlmConfig.max_tokens
      }
    end

    # Generate prompts for synthesis/combining results
    def generate_synthesis_prompt(batch_summaries)
      {
        system_message: @system_message,
        user_message: build_synthesis_user_message(batch_summaries),
        temperature: LlmConfig.temperature,
        max_tokens: LlmConfig.max_tokens
      }
    end

    # Generate function calling parameters for structured output
    def generate_function_parameters
      {
        name: "analyze_ux_workflow",
        description: "Analyze a user workflow and identify UX issues",
        parameters: {
          type: "object",
          properties: {
            workflowSummary: {
              type: "object",
              properties: {
                workflowtitle: {
                  type: "string",
                  description: "A short, descriptive title for the workflow (e.g., 'Gift recommendation flow', 'Checkout process')"
                },
                userGoal: {
                  type: "string",
                  description: "A clear description of what the user is trying to accomplish"
                },
                workflowSteps: {
                  type: "array",
                  items: { type: "string" },
                  description: "The distinct steps the user takes to complete their goal"
                },
                totalFramesAnalyzed: {
                  type: "string",
                  description: "The total number of frames analyzed"
                }
              },
              required: ["workflowtitle", "userGoal", "workflowSteps", "totalFramesAnalyzed"]
            },
            identifiedIssues: {
              type: "array",
              items: {
                type: "object",
                properties: {
                  frameReference: {
                    type: "string",
                    description: "Specific frame numbers where the issue is evident (e.g., 'Frame 5', 'Frames 12-14')"
                  },
                  painPointTitle: {
                    type: "string",
                    description: "A concise, descriptive title for the UX issue"
                  },
                  severity: {
                    type: "string",
                    enum: ["High", "Medium", "Low"],
                    description: "The severity level of the issue"
                  },
                  issueDescription: {
                    type: "string",
                    description: "Detailed explanation starting with the usability principle being violated, then describing the specific issue"
                  },
                  recommendations: {
                    type: "array",
                    items: { type: "string" },
                    description: "Concrete, actionable recommendations to fix the issue"
                  }
                },
                required: ["frameReference", "painPointTitle", "severity", "issueDescription", "recommendations"]
              }
            }
          },
          required: ["workflowSummary", "identifiedIssues"]
        }
      }
    end

    private

    def build_batch_user_message(batch_frames, batch_index, total_frames)
      frame_range = "#{batch_index * LlmConfig.batch_size + 1}-#{[total_frames, (batch_index + 1) * LlmConfig.batch_size].min}"
      
      <<~PROMPT
        Analyze frames #{frame_range} of #{total_frames} from a user workflow video.

        ### CRITICAL INSTRUCTIONS ###
        1. **Analyze the entire frame sequence** - These frames represent a user's journey over time
        2. **Identify specific UX issues** - Look for friction points, confusion, or inefficiencies
        3. **Reference usability principles** - Start each issue description with the specific heuristic being violated
        4. **Provide actionable recommendations** - Give concrete, implementable suggestions

        ### OUTPUT FORMAT ###
        Respond with a valid JSON object containing:
        - `workflowSummary`: Overall workflow analysis
        - `identifiedIssues`: Array of specific UX issues found

        ### ANALYSIS FOCUS ###
        - User interaction patterns
        - Interface clarity and usability
        - Information architecture
        - Visual hierarchy
        - Accessibility considerations
        - Conversion optimization opportunities

        #{few_shot_example_text}
      PROMPT
    end

    def build_synthesis_user_message(batch_summaries)
      <<~PROMPT
        Combine the following batch analyses into a single, unified UX audit report.

        ### BATCH ANALYSES ###
        #{batch_summaries.join("\n\n---\n\n")}

        ### SYNTHESIS INSTRUCTIONS ###
        1. **Merge workflow summaries** - Create a unified workflow description
        2. **Consolidate issues** - Combine similar issues and remove duplicates
        3. **Prioritize by severity** - Order issues by impact and frequency
        4. **Maintain specificity** - Keep frame references and detailed descriptions
        5. **Ensure consistency** - Use consistent terminology and formatting

        ### OUTPUT FORMAT ###
        Respond with a single valid JSON object containing the unified analysis.

        #{few_shot_example_text}
      PROMPT
    end

    def few_shot_example_text
      return "" unless LlmConfig.gpt_5? # Only use examples for GPT-5 for now
      
      example = FEW_SHOT_EXAMPLES.first
      <<~EXAMPLE
        ### EXAMPLE OUTPUT ###
        Input: #{example[:input]}
        Output: #{JSON.pretty_generate(example[:output])}
      EXAMPLE
    end

    def log_prompt_generation(context)
      log_info("Generated prompt", 
        model: LlmConfig.model,
        temperature: LlmConfig.temperature,
        max_tokens: LlmConfig.max_tokens,
        **context
      )
    end
  end
end 