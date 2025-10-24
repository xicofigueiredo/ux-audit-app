class UxKnowledgeDocument < ApplicationRecord
  belongs_to :category, class_name: "KnowledgeBaseCategory", optional: true

  validates :content, presence: true
  validates :file_name, presence: true
  validates :chunk_index, presence: true

  scope :by_file, ->(file_name) { where(file_name: file_name) }
  scope :by_category, ->(category_id) { where(category_id: category_id) }

  def self.search_similar(query_embedding, limit: 10, category_ids: nil)
    return none if query_embedding.blank?

    # Convert array to PostgreSQL vector format
    embedding_vector = "[#{query_embedding.join(',')}]"

    # Build SQL with optional category filtering
    if category_ids.present?
      sql = <<-SQL
        SELECT *, embedding <-> ? AS distance
        FROM ux_knowledge_documents
        WHERE embedding IS NOT NULL
          AND category_id IN (?)
        ORDER BY distance
        LIMIT ?
      SQL
      find_by_sql([sql, embedding_vector, category_ids, limit])
    else
      sql = <<-SQL
        SELECT *, embedding <-> ? AS distance
        FROM ux_knowledge_documents
        WHERE embedding IS NOT NULL
        ORDER BY distance
        LIMIT ?
      SQL
      find_by_sql([sql, embedding_vector, limit])
    end
  end

  def self.search_by_content(query, limit: 10, category_ids: nil)
    return none if query.blank?

    embedding_service = UxKnowledgeEmbeddingService.new
    query_embedding = embedding_service.generate_embedding(query)

    return none if query_embedding.blank?

    search_similar(query_embedding, limit: limit, category_ids: category_ids)
  end
end
