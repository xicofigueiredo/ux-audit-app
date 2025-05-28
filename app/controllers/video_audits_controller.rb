# app/controllers/video_audits_controller.rb
class VideoAuditsController < ApplicationController
  def index
    @audits = VideoAudit.all
  end

  def create
    @audit = VideoAudit.new(video_audit_params)

    if @audit.save
      VideoProcessingJob.perform_later(@audit.id)
      respond_to do |format|
        format.html { redirect_to video_audit_path(@audit) }
        format.json { render json: { id: @audit.id, redirect_url: video_audit_path(@audit) } }
      end
    else
      respond_to do |format|
        format.html { render :index }
        format.json { render json: { errors: @audit.errors }, status: :unprocessable_entity }
      end
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
