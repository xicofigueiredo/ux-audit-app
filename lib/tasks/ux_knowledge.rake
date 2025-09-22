namespace :ux_knowledge do
  desc "Index UX heuristics PDF files from the specified directory"
  task :index, [:directory_path] => :environment do |task, args|
    directory_path = args[:directory_path] || File.expand_path("~/Desktop/UX-huristics")

    unless Dir.exist?(directory_path)
      puts "Error: Directory #{directory_path} does not exist."
      puts "Usage: rails ux_knowledge:index[/path/to/pdfs]"
      exit 1
    end

    puts "Indexing UX knowledge base from: #{directory_path}"
    puts "This may take several minutes depending on the number of PDFs..."

    indexing_service = UxKnowledgeIndexingService.new
    results = indexing_service.index_pdf_directory(directory_path)

    puts "\n=== Indexing Complete ==="
    puts "Successfully processed: #{results[:processed]} files"
    puts "Failed to process: #{results[:failed]} files"
    puts "Total chunks indexed: #{results[:total_chunks]}"
    puts "Knowledge base is ready for use!"
  end

  desc "Reindex all UX knowledge documents (clears existing data)"
  task :reindex, [:directory_path] => :environment do |task, args|
    directory_path = args[:directory_path] || File.expand_path("~/Desktop/UX-huristics")

    unless Dir.exist?(directory_path)
      puts "Error: Directory #{directory_path} does not exist."
      exit 1
    end

    puts "Clearing existing knowledge base and reindexing..."
    puts "Directory: #{directory_path}"

    indexing_service = UxKnowledgeIndexingService.new
    results = indexing_service.reindex_all(directory_path)

    puts "\n=== Reindexing Complete ==="
    puts "Successfully processed: #{results[:processed]} files"
    puts "Failed to process: #{results[:failed]} files"
    puts "Total chunks indexed: #{results[:total_chunks]}"
  end

  desc "Clear the UX knowledge base"
  task clear: :environment do
    puts "Clearing UX knowledge base..."

    indexing_service = UxKnowledgeIndexingService.new
    indexing_service.clear_knowledge_base

    puts "Knowledge base cleared!"
  end

  desc "Show UX knowledge base statistics"
  task stats: :environment do
    total_docs = UxKnowledgeDocument.count
    files = UxKnowledgeDocument.distinct.count(:file_name)

    puts "=== UX Knowledge Base Statistics ==="
    puts "Total document chunks: #{total_docs}"
    puts "Unique files indexed: #{files}"

    if total_docs > 0
      puts "\nFiles in knowledge base:"
      UxKnowledgeDocument.group(:file_name).count.each do |file_name, count|
        puts "  - #{file_name}: #{count} chunks"
      end
    end
  end

  desc "Test search functionality"
  task :test_search, [:query] => :environment do |task, args|
    query = args[:query] || "Nielsen heuristics"

    puts "Testing search with query: '#{query}'"

    results = UxKnowledgeDocument.search_by_content(query, limit: 3)

    if results.any?
      puts "\nFound #{results.size} relevant documents:"
      results.each_with_index do |doc, index|
        puts "\n#{index + 1}. #{doc.file_name} (chunk #{doc.chunk_index})"
        puts "   Content preview: #{doc.content.truncate(200)}"
      end
    else
      puts "No results found. Make sure the knowledge base is indexed."
    end
  end
end