class UxKnowledgeDocument < ApplicationRecord
  validates :content, presence: true
  validates :file_name, presence: true
  validates :chunk_index, presence: true

  scope :by_file, ->(file_name) { where(file_name: file_name) }

  def self.search_similar(query_embedding, limit: 10)
    return none if query_embedding.blank?

    # Convert array to PostgreSQL vector format
    embedding_vector = "[#{query_embedding.join(',')}]"

    # Use raw SQL for vector similarity search
    sql = <<-SQL
      SELECT *, embedding <-> ? AS distance
      FROM ux_knowledge_documents
      WHERE embedding IS NOT NULL
      ORDER BY distance
      LIMIT ?
    SQL

    find_by_sql([sql, embedding_vector, limit])
  end

  def self.search_by_content(query, limit: 10)
    return none if query.blank?

    embedding_service = UxKnowledgeEmbeddingService.new
    query_embedding = embedding_service.generate_embedding(query)

    return none if query_embedding.blank?

    search_similar(query_embedding, limit: limit)
  end
end
