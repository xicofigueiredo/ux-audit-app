class CreateKnowledgeBaseCategories < ActiveRecord::Migration[7.1]
  def change
    create_table :knowledge_base_categories do |t|
      t.string :name, null: false
      t.string :slug, null: false
      t.text :description
      t.text :use_case
      t.boolean :default_enabled, default: false
      t.integer :position, default: 0

      t.timestamps
    end

    add_index :knowledge_base_categories, :slug, unique: true
    add_index :knowledge_base_categories, :position
  end
end
