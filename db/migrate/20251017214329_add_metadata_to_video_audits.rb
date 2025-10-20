class AddMetadataToVideoAudits < ActiveRecord::Migration[7.1]
  def change
    add_column :video_audits, :title, :string
    add_column :video_audits, :description, :text
  end
end
