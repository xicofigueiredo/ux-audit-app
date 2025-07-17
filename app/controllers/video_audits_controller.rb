# app/controllers/video_audits_controller.rb
class VideoAuditsController < ApplicationController
  def index
    @audits = VideoAudit.all
  end

  def create
    @audit = VideoAudit.new(video_audit_params)
    if params[:video_audit] && params[:video_audit][:video].present?
      movie = FFMPEG::Movie.new(params[:video_audit][:video].path)
      if movie.duration > 60
        flash.now[:alert] = "Video is too long (#{movie.duration.round}s). Please upload a video of 1 minute or less."
        @audits = VideoAudit.all
        render :index and return
      end
    end

    if @audit.save
      VideoProcessingJob.perform_later(@audit.id)
      redirect_to video_audit_path(@audit)
    else
      @audits = VideoAudit.all
      render :index
    end
  end

  def show
    @audit = VideoAudit.find(params[:id])

    respond_to do |format|
      format.html
      format.json { render json: { status: @audit.status, result: @audit.llm_response } }
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
