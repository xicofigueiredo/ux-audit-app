# test/services/llm/prompt_generator_test.rb
require 'test_helper'

class Llm::PromptGeneratorTest < ActiveSupport::TestCase
  def setup
    @generator = Llm::PromptGenerator.new
  end

  test "initializes with correct system message for gpt-5" do
    ENV['GPT_MODEL'] = 'gpt-5'
    generator = Llm::PromptGenerator.new
    
    assert_includes generator.send(:instance_variable_get, :@system_message), "15+ years of experience"
    assert_includes generator.send(:instance_variable_get, :@system_message), "Nielsen's 10 Usability Heuristics"
  end

  test "initializes with correct system message for gpt-4o" do
    ENV['GPT_MODEL'] = 'gpt-4o'
    generator = Llm::PromptGenerator.new
    
    assert_includes generator.send(:instance_variable_get, :@system_message), "UX/UI Principal Analyst"
    refute_includes generator.send(:instance_variable_get, :@system_message), "15+ years of experience"
  end

  test "generates batch prompt with correct structure" do
    batch_frames = ['frame1.jpg', 'frame2.jpg']
    prompt = @generator.generate_batch_prompt(batch_frames, 0, 10)
    
    assert_includes prompt.keys, :system_message
    assert_includes prompt.keys, :user_message
    assert_includes prompt.keys, :temperature
    assert_includes prompt.keys, :max_tokens
    
    assert_includes prompt[:user_message], "Analyze frames 1-2 of 10"
  end

  test "generates synthesis prompt" do
    batch_summaries = ['{"summary": "test1"}', '{"summary": "test2"}']
    prompt = @generator.generate_synthesis_prompt(batch_summaries)
    
    assert_includes prompt.keys, :system_message
    assert_includes prompt.keys, :user_message
    assert_includes prompt[:user_message], "Combine the following batch analyses"
  end

  test "generates function parameters for gpt-5" do
    ENV['GPT_MODEL'] = 'gpt-5'
    generator = Llm::PromptGenerator.new
    
    params = generator.generate_function_parameters
    
    assert_equal "analyze_ux_workflow", params[:name]
    assert_includes params[:parameters][:properties].keys, :workflowSummary
    assert_includes params[:parameters][:properties].keys, :identifiedIssues
  end
end 