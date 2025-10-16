class AddCompletionTrackedToVideoAudits < ActiveRecord::Migration[7.1]
  def change
    add_column :video_audits, :completion_tracked, :boolean, default: false, null: false
  end
end
