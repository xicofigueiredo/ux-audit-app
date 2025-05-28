# app/controllers/video_audits_controller.rb
class VideoAuditsController < ApplicationController
  def index
    @audits = VideoAudit.all
  end

  def create
    @audit = VideoAudit.new(video_audit_params)

    if @audit.save
      VideoProcessingJob.perform_later(@audit.id)
      render json: { id: @audit.id, redirect_url: video_audit_path(@audit) }
    else
      render json: { errors: @audit.errors }, status: :unprocessable_entity
    end
  end

  def show
    @audit = VideoAudit.find(params[:id])

    respond_to do |format|
      format.html
      format.json { render json: { status: @audit.status, result: @audit.llm_response } }
    end
  end

  private

  def video_audit_params
    params.require(:video_audit).permit(:video)
  end
end
