class KnowledgeBaseCategory < ApplicationRecord
  has_many :ux_knowledge_documents,
           foreign_key: :category_id,
           dependent: :nullify
  has_many :user_knowledge_preferences, dependent: :destroy
  has_many :users, through: :user_knowledge_preferences

  validates :name, :slug, presence: true
  validates :slug, uniqueness: true, format: { with: /\A[a-z_]+\z/ }

  scope :ordered, -> { order(:position) }
  scope :defaults, -> { where(default_enabled: true) }

  def document_count
    ux_knowledge_documents.count
  end
end
