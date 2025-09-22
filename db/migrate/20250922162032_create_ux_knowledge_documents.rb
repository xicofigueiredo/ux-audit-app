class CreateUxKnowledgeDocuments < ActiveRecord::Migration[7.1]
  def change
    create_table :ux_knowledge_documents do |t|
      t.text :content
      t.string :file_name
      t.integer :chunk_index

      t.timestamps
    end

    # Add vector column using raw SQL
    execute "ALTER TABLE ux_knowledge_documents ADD COLUMN embedding vector(1536)"

    add_index :ux_knowledge_documents, :embedding, using: :ivfflat, opclass: :vector_cosine_ops
    add_index :ux_knowledge_documents, :file_name
  end
end
