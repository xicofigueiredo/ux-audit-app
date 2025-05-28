class AddScoreToVideoAudits < ActiveRecord::Migration[7.1]
  def change
    add_column :video_audits, :score, :integer
  end
end
