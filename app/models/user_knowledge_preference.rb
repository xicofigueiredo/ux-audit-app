class UserKnowledgePreference < ApplicationRecord
  belongs_to :user
  belongs_to :knowledge_base_category

  validates :user_id, uniqueness: { scope: :knowledge_base_category_id }

  scope :enabled, -> { where(enabled: true) }
  scope :disabled, -> { where(enabled: false) }
end
