# app/services/llm/analysis_service.rb
module Llm
  class AnalysisService < BaseService
    include LlmConfig

    def initialize
      super
      @prompt_generator = PromptGenerator.new
      @response_parser = ResponseParser.new
      @video_processor = VideoProcessor.new
      @function_calling_service = FunctionCallingService.new
      @openai_client = create_openai_client
    end

    # Main analysis workflow
    def analyze_video(audit_id)
      log_info("Starting video analysis", audit_id: audit_id)
      
      audit = VideoAudit.find(audit_id)
      audit.update!(status: 'processing')
      
      begin
        # Step 1: Process video and extract frames
        frame_paths = @video_processor.process_video(audit.video.path, audit_id)
        audit.update!(frames: frame_paths)
        
        # Step 2: Create batches and process each batch
        batches = @video_processor.create_batches(frame_paths)
        batch_results = process_batches(batches, audit_id)
        
        # Step 3: Synthesize results into final analysis
        final_analysis = synthesize_results(batch_results, audit_id)
        
        # Step 4: Update audit with results
        audit.update!(
          status: 'completed',
          llm_response: final_analysis[:data],
          score: final_analysis[:quality_score]
        )
        
        log_info("Analysis completed successfully", 
          audit_id: audit_id,
          quality_score: final_analysis[:quality_score]
        )
        
        # Step 5: Schedule cleanup
        CleanupJob.perform_later(audit_id)
        
        final_analysis
      rescue => error
        log_error("Analysis failed", error: error, audit_id: audit_id)
        audit.update!(
          status: 'failed',
          llm_response: "Analysis failed: #{error.message}"
        )
        raise error
      end
    end

    # Process individual batches
    def process_batches(batches, audit_id)
      log_info("Processing batches", batch_count: batches.length, audit_id: audit_id)
      
      batch_results = []
      
      batches.each_with_index do |batch_frames, batch_index|
        log_info("Processing batch", 
          batch_index: batch_index + 1,
          total_batches: batches.length,
          audit_id: audit_id
        )
        
        # Store partial response for progress tracking
        LlmPartialResponse.create!(
          video_audit_id: audit_id,
          chunk_index: batch_index,
          status: 'processing'
        )
        
        begin
          result = process_single_batch(batch_frames, batch_index, batches.length, audit_id)
          batch_results << result
          
          # Update partial response with result
          LlmPartialResponse.where(
            video_audit_id: audit_id,
            chunk_index: batch_index
          ).update_all(
            result: result[:data].to_json,
            status: 'completed'
          )
          
        rescue => error
          log_error("Batch processing failed", 
            error: error,
            batch_index: batch_index,
            audit_id: audit_id
          )
          
          # Update partial response with error
          LlmPartialResponse.where(
            video_audit_id: audit_id,
            chunk_index: batch_index
          ).update_all(
            result: { error: error.message }.to_json,
            status: 'failed'
          )
          
          raise error
        end
      end
      
      batch_results
    end

    # Process a single batch of frames
    def process_single_batch(batch_frames, batch_index, total_batches, audit_id)
      log_info("Processing single batch", 
        batch_index: batch_index,
        frame_count: batch_frames.length,
        audit_id: audit_id
      )
      
      # Prepare frames for API
      api_frames = @video_processor.prepare_frames_for_api(
        batch_frames, 
        batch_index, 
        batch_frames.length
      )
      
      # Generate prompt
      prompt = @prompt_generator.generate_batch_prompt(
        batch_frames, 
        batch_index, 
        batch_frames.length
      )
      
      # Make API call with retry logic
      response = retry_with_backoff(max_retries: 3) do
        make_api_call(prompt, api_frames)
      end
      
      # Parse and validate response
      if @function_calling_service.function_calling_supported?
        parsed_result = @function_calling_service.process_function_call(
          response,
          context: { batch_index: batch_index, audit_id: audit_id }
        )
      else
        parsed_result = @response_parser.parse_response(
          response.dig("choices", 0, "message", "content"),
          context: { batch_index: batch_index, audit_id: audit_id }
        )
      end
      
      log_info("Batch processed successfully", 
        batch_index: batch_index,
        quality_score: parsed_result[:quality_score],
        audit_id: audit_id
      )
      
      parsed_result
    end

    # Synthesize batch results into final analysis
    def synthesize_results(batch_results, audit_id)
      log_info("Synthesizing results", 
        batch_count: batch_results.length,
        audit_id: audit_id
      )
      
      # Extract batch summaries for synthesis
      batch_summaries = batch_results.map { |result| result[:data].to_json }
      
      # Generate synthesis prompt
      synthesis_prompt = @prompt_generator.generate_synthesis_prompt(batch_summaries)
      
      # Make synthesis API call
      synthesis_response = retry_with_backoff(max_retries: 3) do
        make_api_call(synthesis_prompt, [])
      end
      
      # Parse synthesis result
      if @function_calling_service.function_calling_supported?
        final_result = @function_calling_service.process_function_call(
          synthesis_response,
          context: { synthesis: true, audit_id: audit_id }
        )
      else
        final_result = @response_parser.parse_response(
          synthesis_response.dig("choices", 0, "message", "content"),
          context: { synthesis: true, audit_id: audit_id }
        )
      end
      
      # Calculate overall quality score
      overall_quality = calculate_overall_quality(batch_results, final_result)
      final_result[:quality_score] = overall_quality
      
      log_info("Synthesis completed", 
        quality_score: overall_quality,
        audit_id: audit_id
      )
      
      final_result
    end

    # Make API call to OpenAI
    def make_api_call(prompt, frames)
      log_info("Making API call", 
        model: LlmConfig.model,
        frame_count: frames.length
      )
      
      messages = [
        { role: "system", content: prompt[:system_message] },
        { 
          role: "user", 
          content: [
            { type: "text", text: prompt[:user_message] },
            *frames
          ]
        }
      ]
      
      parameters = {
        model: LlmConfig.model,
        messages: messages,
        max_tokens: prompt[:max_tokens],
        temperature: prompt[:temperature],
        timeout: LlmConfig.timeout
      }
      
      # Add function calling for GPT-5
      function_params = @function_calling_service.api_parameters
      parameters.merge!(function_params) if function_params.any?
      
      response = @openai_client.chat(parameters: parameters)
      
      log_info("API call successful", 
        model: LlmConfig.model,
        tokens_used: response.dig("usage", "total_tokens")
      )
      
      response
    rescue => error
      handle_api_error(error)
    end

    # Calculate overall quality score
    def calculate_overall_quality(batch_results, final_result)
      batch_scores = batch_results.map { |result| result[:quality_score] }
      synthesis_score = final_result[:quality_score]
      
      # Weighted average: 70% synthesis score, 30% batch average
      batch_average = batch_scores.sum / batch_scores.length
      overall_score = (synthesis_score * 0.7) + (batch_average * 0.3)
      
      overall_score.round(2)
    end

    # Get analysis progress
    def get_analysis_progress(audit_id)
      audit = VideoAudit.find(audit_id)
      
      case audit.status
      when 'pending'
        { status: 'pending', progress: 0 }
      when 'processing'
        calculate_processing_progress(audit_id)
      when 'completed'
        { status: 'completed', progress: 100 }
      when 'failed'
        { status: 'failed', progress: 0, error: audit.llm_response }
      else
        { status: 'unknown', progress: 0 }
      end
    end

    private

    def create_openai_client
      OpenAI::Client.new(
        access_token: LlmConfig.api_key,
        uri_base: "https://api.openai.com/v1",
        request_timeout: LlmConfig.timeout
      )
    end

    def calculate_processing_progress(audit_id)
      # Calculate progress based on partial responses
      partial_responses = LlmPartialResponse.where(video_audit_id: audit_id)
      total_batches = partial_responses.count
      completed_batches = partial_responses.where(status: 'completed').count
      
      if total_batches > 0
        progress = (completed_batches.to_f / total_batches * 100).round(2)
      else
        progress = 0
      end
      
      {
        status: 'processing',
        progress: progress,
        completed_batches: completed_batches,
        total_batches: total_batches
      }
    end
  end
end 