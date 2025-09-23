# app/controllers/video_audits_controller.rb
class VideoAuditsController < ApplicationController
  def index
    @audits = VideoAudit.all
  end

  def create
    @audit = VideoAudit.new(video_audit_params)
    if params[:video_audit] && params[:video_audit][:video].present?
      movie = FFMPEG::Movie.new(params[:video_audit][:video].path)
      if movie.duration > 90
        flash.now[:alert] = "Video is too long (#{movie.duration.round}s). Please upload a video of 90 seconds or less."
        @audits = VideoAudit.all
        render :index and return
      end
    end

    if @audit.save
      # Set initial processing stage and kick off processing
      @audit.update!(processing_stage: 'uploaded')
      VideoProcessingJob.perform_later(@audit.id)

      # Provide success feedback and redirect
      flash[:notice] = "🎉 Video uploaded successfully! We're analyzing your workflow now."
      redirect_to video_audit_path(@audit)
    else
      @audits = VideoAudit.all
      flash.now[:alert] = "Please select a valid video file to upload."
      render :index
    end
  end

  def show
    @audit = VideoAudit.find(params[:id])

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
    @audit = VideoAudit.find(params[:id])
    @audit.destroy
    redirect_to video_audits_path
  end

  private

  def video_audit_params
    params.require(:video_audit).permit(:video)
  end
end
