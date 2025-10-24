class AddCategoryToUxKnowledgeDocuments < ActiveRecord::Migration[7.1]
  def change
    add_reference :ux_knowledge_documents, :category, null: true,
                  foreign_key: { to_table: :knowledge_base_categories }, index: true
  end
end
