class User < ApplicationRecord
  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable, :trackable and :omniauthable
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable

  has_many :video_audits, dependent: :destroy
  has_many :user_knowledge_preferences, dependent: :destroy
  has_many :knowledge_base_categories, through: :user_knowledge_preferences
  has_many :enabled_knowledge_categories,
           -> { where(user_knowledge_preferences: { enabled: true }) },
           through: :user_knowledge_preferences,
           source: :knowledge_base_category

  after_create :initialize_default_knowledge_preferences

  def knowledge_base_enabled?
    enabled_knowledge_categories.any?
  end

  def toggle_knowledge_category(category_slug, enabled)
    category = KnowledgeBaseCategory.find_by!(slug: category_slug)
    pref = user_knowledge_preferences.find_or_initialize_by(
      knowledge_base_category: category
    )
    pref.update!(enabled: enabled)
  end

  def category_enabled?(category_slug)
    enabled_knowledge_categories.exists?(slug: category_slug)
  end

  private

  def initialize_default_knowledge_preferences
    KnowledgeBaseCategory.defaults.find_each do |category|
      user_knowledge_preferences.create!(
        knowledge_base_category: category,
        enabled: true
      )
    end
  end
end
