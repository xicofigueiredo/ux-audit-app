# app/services/llm/prompt_generator.rb
module Llm
  class PromptGenerator < BaseService
    include LlmConfig

    # Enhanced system message templates for different models
    SYSTEM_MESSAGES = {
      'gpt-5' => <<~SYSTEM,
        You are a highly sought-after UX/UI Principal Analyst with 15+ years of experience in user experience design and usability testing. Your insights are specific, actionable, and grounded in established usability heuristics like Nielsen's 10 Usability Heuristics and Norman's Design Principles.

        Your expertise includes:
        - Identifying friction points in user workflows
        - Analyzing visual hierarchy and information architecture
        - Evaluating accessibility and inclusive design
        - Understanding user psychology and behavior patterns
        - Providing concrete, implementable recommendations
        - Quantifying impact and prioritizing issues
        - Applying cognitive psychology principles
        - Context-aware severity assessment based on workflow criticality

        ANALYSIS APPROACH:
        1. **Frame-by-frame observation**: Analyze each frame for user interactions, visual elements, and potential friction points
        2. **Heuristic evaluation**: Apply Nielsen's 10 Usability Heuristics systematically
        3. **Context-aware impact assessment**: Consider user frustration, task completion time, conversion impact, AND workflow criticality (e.g., checkout flows vs settings pages)
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
        - Context-aware severity assessment based on workflow criticality (e.g., checkout vs settings)
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
            summary: "Most friction occurred during payment information entry (00:05-00:13). The main issues concern unclear form validation and lack of visual feedback. Addressing these will likely improve checkout completion rates and reduce user frustration.",
            workflowSteps: [
              "Add items to cart",
              "Proceed to checkout",
              "Enter shipping information",
              "Enter payment details",
              "Review and confirm order"
            ],
            totalFramesAnalyzed: "15",
            workflowCriticality: "Business-Critical"
          },
          identifiedIssues: [
            {
              frameReference: "Frames 8-10",
              painPointTitle: "Form validation errors unclear",
              severity: "High",
              issueDescription: "Form validation errors appear in red text but don't clearly indicate which field needs attention or how to fix the issue.",
              heuristicViolated: "Error prevention",
              recommendations: [
                "Add field-specific error messages with clear instructions",
                "Use visual indicators (borders, icons) to highlight problematic fields",
                "Provide real-time validation feedback as user types"
              ],
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
            summary: "Most friction occurred during permission requests and account creation (00:00-00:08). The main issues concern aggressive permission dialogs and lack of context. Addressing these will likely improve onboarding completion rates and first-time user experience.",
            workflowSteps: [
              "Welcome screen and permissions",
              "Account creation form",
              "Profile setup",
              "Tutorial walkthrough",
              "Dashboard introduction"
            ],
            totalFramesAnalyzed: "12",
            workflowCriticality: "High-Impact"
          },
          identifiedIssues: [
            {
              frameReference: "Frames 3-5",
              painPointTitle: "Permission requests too aggressive",
              severity: "Medium",
              issueDescription: "The app requests multiple permissions simultaneously without clear explanation of why each is needed.",
              heuristicViolated: "User control and freedom",
              recommendations: [
                "Request permissions one at a time with clear explanations",
                "Add 'Skip for now' options for non-critical permissions",
                "Show permission benefits before requesting access"
              ],
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

    def initialize(user: nil, video_audit: nil)
      super()
      @system_message = SYSTEM_MESSAGES[llm_model] || SYSTEM_MESSAGES['gpt-4o']
      @user = user
      @video_audit = video_audit
      @knowledge_context = fetch_knowledge_context if @user && @video_audit
    end

    # Generate prompts for batch analysis
    def generate_batch_prompt(batch_frames, batch_index, total_frames)
      {
        system_message: system_message_with_knowledge,
        user_message: build_batch_user_message(batch_frames, batch_index, total_frames),
        temperature: llm_temperature,
        max_tokens: llm_max_tokens
      }
    end

    # Generate prompts for synthesis/combining results
    def generate_synthesis_prompt(batch_summaries)
      {
        system_message: system_message_with_knowledge,
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
                summary: {
                  type: "string",
                  description: "A 2-3 sentence executive summary of the UX analysis. Format: 'Most friction occurred during [stage] ([time range]). The main issues concern [key topics like visibility, feedback, clarity]. Addressing these will likely improve [expected outcome like conversion rates, user confidence, task completion].'"
                },
                workflowSteps: {
                  type: "array",
                  items: { type: "string" },
                  description: "The distinct steps the user takes to complete their goal"
                },
                totalFramesAnalyzed: {
                  type: "string",
                  description: "The total number of frames analyzed"
                },
                workflowCriticality: {
                  type: "string",
                  enum: ["Business-Critical", "High-Impact", "Standard", "Low-Impact"],
                  description: "The business criticality of this workflow. Business-Critical: checkout, payment, signup, login. High-Impact: onboarding, core features, search. Standard: settings, profile, preferences. Low-Impact: help pages, about pages"
                }
              },
              required: ["workflowtitle", "userGoal", "summary", "workflowSteps", "totalFramesAnalyzed", "workflowCriticality"]
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
                    description: "Context-aware severity level considering: (1) user impact and frequency, (2) workflow criticality. Business-Critical flows (checkout, payment, signup) should receive higher severity for similar issues compared to Low-Impact flows (settings, help pages)"
                  },
                  issueDescription: {
                    type: "string",
                    description: "Clear description of the specific issue observed - what is actually happening that creates the problem (e.g., 'No clear feedback if recording is active', 'Label 0/60s below start button is ambiguous')"
                  },
                  heuristicViolated: {
                    type: "string",
                    description: "The specific Nielsen usability heuristic being violated (e.g., 'Visibility of system status', 'Match between system and real world', 'User control and freedom', 'Consistency and standards', 'Error prevention', 'Recognition rather than recall', 'Flexibility and efficiency of use', 'Aesthetic and minimalist design', 'Help users recognize, diagnose, and recover from errors', 'Help and documentation')"
                  },
                  recommendations: {
                    type: "array",
                    items: { type: "string" },
                    description: "Concrete, actionable recommendations to fix the issue"
                  }
                },
                required: ["frameReference", "painPointTitle", "severity", "issueDescription", "heuristicViolated", "recommendations"]
              }
            }
          },
          required: ["workflowSummary", "identifiedIssues"]
        }
      }
    end

    private

    def fetch_knowledge_context
      return nil unless @user&.knowledge_base_enabled?

      analysis_context = build_analysis_context
      UxKnowledgeRetrievalService.new.retrieve_for_user_audit(analysis_context, @user)
    rescue => e
      Rails.logger.error("Failed to fetch knowledge context: #{e.message}")
      nil
    end

    def build_analysis_context
      context_parts = []
      context_parts << "UX audit"
      context_parts << "of #{@video_audit.title}" if @video_audit.title.present?
      context_parts << @video_audit.description if @video_audit.description.present?
      context_parts.join(" ")
    end

    def system_message_with_knowledge
      base_message = @system_message

      if @knowledge_context.present?
        base_message + "\n\n" + knowledge_context_section
      else
        base_message
      end
    end

    def knowledge_context_section
      <<~KNOWLEDGE

        === REFERENCE MATERIALS ===
        The following curated UX knowledge has been selected based on user preferences
        to inform your analysis. Use these as authoritative references, but maintain
        focus on observable issues in the interface.

        #{@knowledge_context}

        ===========================

      KNOWLEDGE
    end

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
        6. **Context-Aware Severity Assessment**: I'll adjust severity ratings based on workflow criticality
        7. **Solution Generation**: I'll provide specific, actionable recommendations for each issue

        ### CONTEXT-AWARE SEVERITY GUIDELINES ###
        Consider workflow criticality when assigning severity:

        **Business-Critical Flows** (checkout, payment, signup, login):
        - Blocking/confusing issues → High severity
        - Unclear feedback/validation → High severity
        - Minor friction points → Medium severity
        - Cosmetic issues → Low-Medium severity

        **High-Impact Flows** (onboarding, core features, search):
        - Blocking issues → High severity
        - Confusing elements → Medium-High severity
        - Minor friction → Medium severity
        - Cosmetic issues → Low severity

        **Standard Flows** (settings, profile, preferences):
        - Blocking issues → Medium-High severity
        - Confusing elements → Medium severity
        - Minor friction → Low-Medium severity
        - Cosmetic issues → Low severity

        **Low-Impact Flows** (help pages, about pages, footer links):
        - Blocking issues → Medium severity
        - Confusing elements → Low-Medium severity
        - Minor friction → Low severity
        - Cosmetic issues → Low severity

        Examples:
        - "Checkout button not visible" in e-commerce → HIGH
        - "Save button unclear" in settings → MEDIUM
        - "No loading indicator during payment" → HIGH
        - "No loading indicator on profile save" → MEDIUM
        - "Inconsistent spacing in footer" → LOW

        ### CRITICAL INSTRUCTIONS ###
        1. **Analyze the entire frame sequence** - These frames represent a user's journey over time
        2. **Identify specific UX issues** - Look for friction points, confusion, or inefficiencies
        3. **Reference usability principles** - Identify which Nielsen heuristic is violated (use separate heuristicViolated field)
        4. **Describe the actual problem** - In issueDescription, focus on what's actually happening (e.g., "No clear feedback if recording is active") NOT on which heuristic is violated
        5. **Provide actionable recommendations** - Give concrete, implementable suggestions
        6. **Quantify impact** - Assign impact scores (1-10) based on user frustration and conversion impact

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
        - `workflowSummary`: Overall workflow analysis including a 2-3 sentence executive summary
        - `identifiedIssues`: Array of specific UX issues with impact scores
        - `analysisMetadata`: Confidence score and processing information

        **IMPORTANT**: The `summary` field in `workflowSummary` should be a concise 2-3 sentence overview following this format:
        "Most friction occurred during [stage/action] ([time range like 00:05-00:13]). The main issues concern [key themes like visibility, feedback clarity, error handling]. Addressing these will likely improve [outcome like user confidence, task completion, conversion rates]."

        #{few_shot_example_text}
      PROMPT
    end

    def build_standard_batch_message(frame_range, total_frames)
      <<~PROMPT
        Analyze frames #{frame_range} of #{total_frames} from a user workflow video.

        ### CONTEXT-AWARE SEVERITY GUIDELINES ###
        Assign severity based on workflow criticality:

        **Business-Critical Flows** (checkout, payment, signup, login):
        - Blocking/confusing issues → High severity
        - Unclear feedback → High severity
        - Minor friction → Medium severity

        **High-Impact Flows** (onboarding, core features, search):
        - Blocking issues → High severity
        - Confusing elements → Medium-High severity
        - Minor friction → Medium severity

        **Standard Flows** (settings, profile, preferences):
        - Blocking issues → Medium-High severity
        - Confusing elements → Medium severity
        - Minor friction → Low-Medium severity

        **Low-Impact Flows** (help pages, about pages):
        - Blocking issues → Medium severity
        - Confusing elements → Low-Medium severity
        - Minor friction → Low severity

        ### CRITICAL INSTRUCTIONS ###
        1. **Analyze the entire frame sequence** - These frames represent a user's journey over time
        2. **Identify specific UX issues** - Look for friction points, confusion, or inefficiencies
        3. **Reference usability principles** - Identify which Nielsen heuristic is violated (use separate heuristicViolated field)
        4. **Describe the actual problem** - In issueDescription, focus on what's actually happening, NOT on which heuristic is violated
        5. **Provide actionable recommendations** - Give concrete, implementable suggestions
        6. **Apply context-aware severity** - Consider workflow criticality when rating severity

        ### OUTPUT FORMAT ###
        Respond with a valid JSON object containing:
        - `workflowSummary`: Overall workflow analysis including a 2-3 sentence executive summary
        - `identifiedIssues`: Array of specific UX issues found

        **IMPORTANT**: Include a `summary` field in `workflowSummary` with this format:
        "Most friction occurred during [stage] ([time range]). The main issues concern [key themes]. Addressing these will likely improve [outcome]."

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