class CreateLlmPartialResponses < ActiveRecord::Migration[7.1]
  def change
    create_table :llm_partial_responses do |t|
      t.references :video_audit, null: false, foreign_key: true
      t.integer :chunk_index
      t.jsonb :result
      t.string :status

      t.timestamps
    end
  end
end
