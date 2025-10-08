class AddThumbnailImageToVideoAudits < ActiveRecord::Migration[7.1]
  def change
    add_column :video_audits, :thumbnail_image, :text
  end
end
