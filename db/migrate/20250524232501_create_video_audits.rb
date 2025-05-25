class CreateVideoAudits < ActiveRecord::Migration[7.1]
  def change
    create_table :video_audits do |t|
      t.string :video
      t.string :status, default: 'pending'
      t.text :llm_response
      t.timestamps
    end
  end
end
