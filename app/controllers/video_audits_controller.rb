# app/controllers/video_audits_controller.rb
class VideoAuditsController < ApplicationController
  include AnalyticsHelper
  layout false

  def index
    @audits = current_user.video_audits.order(created_at: :desc)
  end

  def create
    # Clear analytics queue to prevent cookie overflow
    session[:pending_analytics_events] = [] if session[:pending_analytics_events].present?

    @audit = current_user.video_audits.build(video_audit_params)

    # Track upload start
    if params[:video_audit] && params[:video_audit][:video].present?
      video_file = params[:video_audit][:video]
      file_size = video_file.size if video_file.respond_to?(:size)

      begin
        movie = FFMPEG::Movie.new(video_file.path)
        duration = movie.duration

        track_video_upload_start(file_size, duration)

        if duration > 90
          track_video_upload_error('duration_exceeded', "Video duration #{duration.round}s exceeds 90s limit")
          flash.now[:alert] = "Video is too long (#{duration.round}s). Please upload a video of 90 seconds or less."
          @audits = current_user.video_audits.order(created_at: :desc)
          render :index and return
        end
      rescue => e
        track_video_upload_error('ffmpeg_error', e.message)
        flash.now[:alert] = "Error processing video file. Please try a different format."
        @audits = current_user.video_audits.order(created_at: :desc)
        render :index and return
      end
    else
      track_video_upload_error('no_file', 'No video file provided')
    end

    if @audit.save
      # Track successful upload
      video_file = params[:video_audit][:video]
      file_size = video_file.size if video_file.respond_to?(:size)
      duration = nil

      begin
        movie = FFMPEG::Movie.new(video_file.path)
        duration = movie.duration
      rescue
        # Duration already captured above or unavailable
      end

      track_video_upload_success(@audit.id, file_size, duration)

      # Set initial processing stage and kick off processing
      @audit.update!(processing_stage: 'uploaded')
      track_processing_stage(@audit.id, 'uploaded')

      VideoProcessingJob.perform_later(@audit.id)

      # Provide success feedback and redirect
      flash[:notice] = "🎉 Video uploaded successfully! We're analyzing your workflow now."
      redirect_to video_audit_path(@audit)
    else
      track_video_upload_error('validation_failed', @audit.errors.full_messages.join(', '))
      @audits = current_user.video_audits.order(created_at: :desc)
      flash.now[:alert] = "Please select a valid video file to upload."
      render :index
    end
  end

  def show
    @audit = current_user.video_audits.find(params[:id])

    # Track audit completion when user first views completed results
    if @audit.completed? && !@audit.completion_tracked?
      begin
        issues_count = @audit.parsed_llm_response.dig('identifiedIssues')&.length if @audit.parsed_llm_response.is_a?(Hash)
        total_duration = (Time.current - @audit.created_at).to_i
        track_audit_completion(@audit.id, total_duration, issues_count)
        @audit.update_column(:completion_tracked, true)
      rescue => e
        Rails.logger.error "Error tracking audit completion: #{e.message}"
      end
    end

    respond_to do |format|
      format.html
      format.json { render json: {
        status: @audit.status,
        result: @audit.llm_response,
        processing_stage: @audit.processing_stage,
        processing_message: @audit.processing_stage_message,
        estimated_time: @audit.estimated_time_remaining
      } }
    end
  end

  def destroy
    @audit = current_user.video_audits.find(params[:id])
    @audit.destroy
    flash[:notice] = "Project deleted successfully."
    redirect_to projects_path
  end

  private

  def video_audit_params
    params.require(:video_audit).permit(:video)
  end
end
