class UxKnowledgeEmbeddingService
  EMBEDDING_MODEL = "text-embedding-3-small".freeze
  CHUNK_SIZE = 1500
  OVERLAP_SIZE = 200

  def initialize
    @client = OpenAI::Client.new(
      access_token: ENV['OPENAI_API_KEY'],
      uri_base: "https://api.openai.com/v1",
      request_timeout: 60
    )
  end

  def generate_embedding(text)
    return nil if text.blank?

    begin
      response = @client.embeddings(
        parameters: {
          model: EMBEDDING_MODEL,
          input: text
        }
      )

      response.dig("data", 0, "embedding")
    rescue => e
      Rails.logger.error "Failed to generate embedding: #{e.message}"
      nil
    end
  end

  def chunk_text(text)
    return [] if text.blank?

    chunks = []
    words = text.split(/\s+/)

    current_chunk = []
    current_size = 0

    words.each do |word|
      word_size = word.length + 1 # +1 for space

      if current_size + word_size > CHUNK_SIZE && current_chunk.any?
        # Add current chunk
        chunks << current_chunk.join(' ')

        # Start new chunk with overlap
        overlap_words = current_chunk.last([OVERLAP_SIZE / 10, current_chunk.size].min)
        current_chunk = overlap_words + [word]
        current_size = current_chunk.join(' ').length
      else
        current_chunk << word
        current_size += word_size
      end
    end

    # Add the last chunk if it has content
    chunks << current_chunk.join(' ') if current_chunk.any?

    chunks
  end

  def process_pdf_file(file_path)
    return [] unless File.exist?(file_path)

    begin
      reader = PDF::Reader.new(file_path)
      text_content = ""

      reader.pages.each do |page|
        text_content += page.text + "\n\n"
      end

      # Clean up the text
      cleaned_text = clean_text(text_content)

      # Split into chunks
      chunk_text(cleaned_text)
    rescue => e
      Rails.logger.error "Failed to process PDF #{file_path}: #{e.message}"
      []
    end
  end

  private

  def clean_text(text)
    text
      .gsub(/\s+/, ' ')           # Normalize whitespace
      .gsub(/[^\x00-\x7F]/, '')   # Remove non-ASCII characters
      .strip                      # Remove leading/trailing whitespace
  end
end