class CreateIssueScreenshots < ActiveRecord::Migration[7.1]
  def change
    create_table :issue_screenshots do |t|
      t.references :video_audit, null: false, foreign_key: true
      t.integer :issue_index
      t.text :image_data

      t.timestamps
    end
  end
end
