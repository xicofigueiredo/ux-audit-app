# app/services/llm/prompt_generator.rb
module Llm
  class PromptGenerator < BaseService
    include LlmConfig

    # Enhanced system message templates for different models
    SYSTEM_MESSAGES = {
      'gpt-5o' => <<~SYSTEM,
        You are a highly sought-after UX/UI Principal Analyst with 15+ years of experience in user experience design and usability testing. Your insights are specific, actionable, and grounded in established usability heuristics like Nielsen's 10 Usability Heuristics and Norman's Design Principles.

        Your expertise includes:
        - Identifying friction points in user workflows
        - Analyzing visual hierarchy and information architecture
        - Evaluating accessibility and inclusive design
        - Understanding user psychology and behavior patterns
        - Providing concrete, implementable recommendations
        - Quantifying impact and prioritizing issues
        - Applying cognitive psychology principles

        ANALYSIS APPROACH:
        1. **Frame-by-frame observation**: Analyze each frame for user interactions, visual elements, and potential friction points
        2. **Heuristic evaluation**: Apply Nielsen's 10 Usability Heuristics systematically
        3. **Impact assessment**: Consider user frustration, task completion time, and conversion impact
        4. **Actionable recommendations**: Provide specific, implementable solutions with clear rationale

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

    # Enhanced few-shot examples for GPT-5
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
              ],
              heuristicViolated: "Error prevention",
              impactScore: 8
            }
          ],
          analysisMetadata: {
            analysisType: "batch",
            confidenceScore: 0.92,
            processingTime: 2.3
          }
        }
      },
      {
        input: "User navigating through a mobile app onboarding",
        output: {
          workflowSummary: {
            workflowtitle: "Mobile app onboarding flow",
            userGoal: "Complete initial app setup and account creation",
            workflowSteps: [
              "Welcome screen and permissions",
              "Account creation form",
              "Profile setup",
              "Tutorial walkthrough",
              "Dashboard introduction"
            ],
            totalFramesAnalyzed: "12"
          },
          identifiedIssues: [
            {
              frameReference: "Frames 3-5",
              painPointTitle: "Permission requests too aggressive",
              severity: "Medium",
              issueDescription: "This violates the principle of User control and freedom. The app requests multiple permissions simultaneously without clear explanation of why each is needed.",
              recommendations: [
                "Request permissions one at a time with clear explanations",
                "Add 'Skip for now' options for non-critical permissions",
                "Show permission benefits before requesting access"
              ],
              heuristicViolated: "User control and freedom",
              impactScore: 6
            }
          ],
          analysisMetadata: {
            analysisType: "batch",
            confidenceScore: 0.88,
            processingTime: 1.8
          }
        }
      }
    ].freeze

    def initialize
      super
      @system_message = SYSTEM_MESSAGES[llm_model] || SYSTEM_MESSAGES['gpt-4o']
    end

    # Generate prompts for batch analysis
    def generate_batch_prompt(batch_frames, batch_index, total_frames)
      {
        system_message: @system_message,
        user_message: build_batch_user_message(batch_frames, batch_index, total_frames),
        temperature: llm_temperature,
        max_tokens: llm_max_tokens
      }
    end

    # Generate prompts for synthesis/combining results
    def generate_synthesis_prompt(batch_summaries)
      {
        system_message: @system_message,
        user_message: build_synthesis_user_message(batch_summaries),
        temperature: llm_temperature,
        max_tokens: llm_max_tokens
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
      frame_range = "#{batch_index * llm_batch_size + 1}-#{[total_frames, (batch_index + 1) * llm_batch_size].min}"
      
      if llm_gpt_5?
        build_gpt5_batch_message(frame_range, total_frames)
      else
        build_standard_batch_message(frame_range, total_frames)
      end
    end

    def build_gpt5_batch_message(frame_range, total_frames)
      <<~PROMPT
        Analyze frames #{frame_range} of #{total_frames} from a user workflow video.

        ### THINKING PROCESS (Chain-of-Thought) ###
        Let me analyze this step by step:

        1. **Frame Sequence Analysis**: I'll examine each frame chronologically to understand the user's journey
        2. **Interaction Mapping**: I'll identify all user interactions, clicks, scrolls, and form inputs
        3. **Visual Element Assessment**: I'll evaluate the visual hierarchy, layout, and information architecture
        4. **Heuristic Evaluation**: I'll systematically apply Nielsen's 10 Usability Heuristics to each interaction
        5. **Impact Quantification**: I'll assess the severity and impact of each issue on user experience
        6. **Solution Generation**: I'll provide specific, actionable recommendations for each issue

        ### CRITICAL INSTRUCTIONS ###
        1. **Analyze the entire frame sequence** - These frames represent a user's journey over time
        2. **Identify specific UX issues** - Look for friction points, confusion, or inefficiencies
        3. **Reference usability principles** - Start each issue description with the specific heuristic being violated
        4. **Provide actionable recommendations** - Give concrete, implementable suggestions
        5. **Quantify impact** - Assign impact scores (1-10) based on user frustration and conversion impact

        ### ANALYSIS FOCUS ###
        - User interaction patterns and micro-interactions
        - Interface clarity and usability
        - Information architecture and navigation
        - Visual hierarchy and cognitive load
        - Accessibility considerations
        - Conversion optimization opportunities
        - Error prevention and recovery
        - User control and freedom

        ### OUTPUT FORMAT ###
        Use the provided function to return structured analysis with:
        - `workflowSummary`: Overall workflow analysis
        - `identifiedIssues`: Array of specific UX issues with impact scores
        - `analysisMetadata`: Confidence score and processing information

        #{few_shot_example_text}
      PROMPT
    end

    def build_standard_batch_message(frame_range, total_frames)
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
      return "" unless llm_gpt_5? # Only use examples for GPT-5 for now
      
      example = FEW_SHOT_EXAMPLES.first
      <<~EXAMPLE
        ### EXAMPLE OUTPUT ###
        Input: #{example[:input]}
        Output: #{JSON.pretty_generate(example[:output])}
      EXAMPLE
    end

    def log_prompt_generation(context)
      log_info("Generated prompt", 
        model: llm_model,
        temperature: llm_temperature,
        max_tokens: llm_max_tokens,
        **context
      )
    end
  end
end 