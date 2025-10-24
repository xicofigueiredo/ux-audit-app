class CreateUserKnowledgePreferences < ActiveRecord::Migration[7.1]
  def change
    create_table :user_knowledge_preferences do |t|
      t.references :user, null: false, foreign_key: { on_delete: :cascade }
      t.references :knowledge_base_category, null: false, foreign_key: { on_delete: :cascade }
      t.boolean :enabled, default: true

      t.timestamps
    end

    add_index :user_knowledge_preferences, [:user_id, :knowledge_base_category_id],
              unique: true, name: 'index_user_knowledge_prefs_on_user_and_category'
    add_index :user_knowledge_preferences, :enabled, where: "enabled = true"
  end
end
