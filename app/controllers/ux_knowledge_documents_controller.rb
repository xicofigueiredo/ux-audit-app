class UxKnowledgeDocumentsController < ApplicationController
  def index
    @total_documents = UxKnowledgeDocument.count
    @files_count = UxKnowledgeDocument.distinct.count(:file_name)
    @files_stats = UxKnowledgeDocument.group(:file_name).count.sort_by { |_, count| -count }

    @documents = UxKnowledgeDocument.order(:file_name, :chunk_index)
                                  .limit(20)
                                  .offset((params[:page].to_i - 1) * 20)
  end

  def show
    @document = UxKnowledgeDocument.find(params[:id])
  end

  def search
    @query = params[:query]
    @results = []

    if @query.present?
      @results = UxKnowledgeDocument.search_by_content(@query, limit: 10)
      @retrieval_service = UxKnowledgeRetrievalService.new
      @formatted_context = @retrieval_service.retrieve_relevant_context(@query)
    end
  end

  def reindex
    if request.post?
      UxKnowledgeIndexingService.new.reindex_all(File.expand_path("~/Desktop/UX-huristics"))
      redirect_to ux_knowledge_documents_path, notice: "Knowledge base reindexed successfully!"
    end
  end
end
