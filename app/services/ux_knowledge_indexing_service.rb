class UxKnowledgeIndexingService
  def initialize
    @embedding_service = UxKnowledgeEmbeddingService.new
  end

  def index_pdf_directory(directory_path)
    return unless Dir.exist?(directory_path)

    pdf_files = Dir.glob(File.join(directory_path, "*.pdf"))
    Rails.logger.info "Found #{pdf_files.size} PDF files to process"

    results = {
      processed: 0,
      failed: 0,
      total_chunks: 0
    }

    pdf_files.each do |file_path|
      begin
        index_pdf_file(file_path)
        results[:processed] += 1
        Rails.logger.info "Successfully processed: #{File.basename(file_path)}"
      rescue => e
        Rails.logger.error "Failed to process #{file_path}: #{e.message}"
        results[:failed] += 1
      end
    end

    results[:total_chunks] = UxKnowledgeDocument.count
    results
  end

  def index_pdf_file(file_path)
    file_name = File.basename(file_path)

    # Remove existing documents for this file
    UxKnowledgeDocument.where(file_name: file_name).destroy_all

    # Process PDF into chunks
    chunks = @embedding_service.process_pdf_file(file_path)

    return if chunks.empty?

    Rails.logger.info "Processing #{chunks.size} chunks for #{file_name}"

    chunks.each_with_index do |chunk_content, index|
      # Generate embedding for the chunk
      embedding = @embedding_service.generate_embedding(chunk_content)

      if embedding
        # Convert embedding array to PostgreSQL vector format
        embedding_vector = "[#{embedding.join(',')}]"

        UxKnowledgeDocument.create!(
          content: chunk_content,
          file_name: file_name,
          chunk_index: index,
          embedding: embedding_vector
        )
      else
        Rails.logger.warn "Failed to generate embedding for chunk #{index} in #{file_name}"
      end

      # Add small delay to avoid rate limiting
      sleep(0.1) if index % 10 == 0
    end

    Rails.logger.info "Indexed #{chunks.size} chunks from #{file_name}"
  end

  def clear_knowledge_base
    count = UxKnowledgeDocument.count
    UxKnowledgeDocument.delete_all
    Rails.logger.info "Cleared #{count} documents from knowledge base"
  end

  def reindex_all(directory_path)
    clear_knowledge_base
    index_pdf_directory(directory_path)
  end
end