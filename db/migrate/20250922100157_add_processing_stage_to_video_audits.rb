class AddProcessingStageToVideoAudits < ActiveRecord::Migration[7.1]
  def change
    add_column :video_audits, :processing_stage, :string, default: 'uploaded'
  end
end
