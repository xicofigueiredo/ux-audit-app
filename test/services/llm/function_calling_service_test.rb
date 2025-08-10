# test/services/llm/function_calling_service_test.rb
require 'test_helper'

class Llm::FunctionCallingServiceTest < ActiveSupport::TestCase
  def setup
    @service = Llm::FunctionCallingService.new
  end

  test "generates function parameters correctly" do
    params = @service.generate_function_parameters
    
    assert_equal "analyze_ux_workflow", params[:name]
    assert_includes params[:parameters][:properties].keys, :workflowSummary
    assert_includes params[:parameters][:properties].keys, :identifiedIssues
    assert_includes params[:parameters][:properties].keys, :analysisMetadata
  end

  test "function calling supported for gpt-5" do
    ENV['GPT_MODEL'] = 'gpt-5o'
    ENV['ENABLE_FUNCTION_CALLING'] = 'true'
    
    assert @service.function_calling_supported?
  end

  test "function calling not supported for gpt-4" do
    ENV['GPT_MODEL'] = 'gpt-4o'
    ENV['ENABLE_FUNCTION_CALLING'] = 'true'
    
    refute @service.function_calling_supported?
  end

  test "function calling disabled by environment variable" do
    ENV['GPT_MODEL'] = 'gpt-5o'
    ENV['ENABLE_FUNCTION_CALLING'] = 'false'
    
    refute @service.function_calling_supported?
  end

  test "api parameters returns function calling config for gpt-5" do
    ENV['GPT_MODEL'] = 'gpt-5o'
    ENV['ENABLE_FUNCTION_CALLING'] = 'true'
    
    params = @service.api_parameters
    
    assert_includes params.keys, :functions
    assert_includes params.keys, :function_call
    assert_equal "analyze_ux_workflow", params[:function_call][:name]
  end

  test "api parameters returns empty hash for gpt-4" do
    ENV['GPT_MODEL'] = 'gpt-4o'
    ENV['ENABLE_FUNCTION_CALLING'] = 'true'
    
    params = @service.api_parameters
    
    assert_empty params
  end

  test "validates function data correctly" do
    valid_data = {
      "workflowSummary" => {
        "workflowtitle" => "Test workflow",
        "userGoal" => "Test goal",
        "workflowSteps" => ["Step 1", "Step 2"],
        "totalFramesAnalyzed" => "10"
      },
      "identifiedIssues" => [
        {
          "frameReference" => "Frames 1-3",
          "painPointTitle" => "Test issue",
          "severity" => "High",
          "issueDescription" => "This violates the principle of Error prevention.",
          "recommendations" => ["Fix 1", "Fix 2"],
          "heuristicViolated" => "Error prevention",
          "impactScore" => 8
        }
      ],
      "analysisMetadata" => {
        "analysisType" => "batch",
        "confidenceScore" => 0.9
      }
    }
    
    result = @service.validate_function_data(valid_data)
    assert_equal valid_data, result
  end

  test "raises error for missing required fields" do
    invalid_data = {
      workflowSummary: {
        workflowtitle: "Test workflow"
        # Missing other required fields
      }
    }
    
    assert_raises(Llm::FunctionCallingService::ValidationError) do
      @service.validate_function_data(invalid_data)
    end
  end

  test "raises error for invalid severity" do
    invalid_data = {
      workflowSummary: {
        workflowtitle: "Test workflow",
        userGoal: "Test goal",
        workflowSteps: ["Step 1"],
        totalFramesAnalyzed: "10"
      },
      identifiedIssues: [
        {
          frameReference: "Frames 1-3",
          painPointTitle: "Test issue",
          severity: "Invalid", # Invalid severity
          issueDescription: "Test description",
          recommendations: ["Fix 1"],
          heuristicViolated: "Error prevention",
          impactScore: 8
        }
      ],
      analysisMetadata: {
        analysisType: "batch",
        confidenceScore: 0.9
      }
    }
    
    assert_raises(Llm::FunctionCallingService::ValidationError) do
      @service.validate_function_data(invalid_data)
    end
  end

  test "processes function call response correctly" do
    mock_response = {
      "choices" => [
        {
          "message" => {
            "function_call" => {
              "name" => "analyze_ux_workflow",
              "arguments" => {
                "workflowSummary" => {
                  "workflowtitle" => "Test workflow",
                  "userGoal" => "Test goal",
                  "workflowSteps" => ["Step 1"],
                  "totalFramesAnalyzed" => "10"
                },
                "identifiedIssues" => [],
                "analysisMetadata" => {
                  "analysisType" => "batch",
                  "confidenceScore" => 0.9
                }
              }.to_json
            }
          }
        }
      ]
    }
    
    result = @service.process_function_call(mock_response)
    
    assert_equal "analyze_ux_workflow", result[:function_name]
    assert_equal 0.9, result[:confidence_score]
    assert_equal "2.0", result[:version]
  end

  test "handles missing function call gracefully" do
    mock_response = {
      choices: [
        {
          message: {
            content: "Some text response"
          }
        }
      ]
    }
    
    result = @service.process_function_call(mock_response)
    
    assert_nil result[:function_name]
    assert_equal 0.0, result[:confidence_score]
    assert_includes result[:error], "No function call found"
  end
end 