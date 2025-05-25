class AddFramesToVideoAudits < ActiveRecord::Migration[7.1]
  def change
    add_column :video_audits, :frames, :text, array: true, default: []
  end
end
