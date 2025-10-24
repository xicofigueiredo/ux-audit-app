class UxKnowledgeDocumentsController < ApplicationController
  include AnalyticsHelper
  layout :determine_layout
  skip_before_action :authenticate_user!, only: [:index, :show, :search]

  def index
    @total_documents = UxKnowledgeDocument.count
    @files_count = UxKnowledgeDocument.distinct.count(:file_name)
    @files_stats = UxKnowledgeDocument.group(:file_name).count.sort_by { |_, count| -count }

    @documents = UxKnowledgeDocument.order(:file_name, :chunk_index)
                                  .limit(20)
                                  .offset((params[:page].to_i - 1) * 20)

    # Load knowledge base categories and user preferences for logged-in users
    if user_signed_in?
      @knowledge_categories = KnowledgeBaseCategory
        .ordered
        .includes(:ux_knowledge_documents)
      @user_preferences = current_user
        .user_knowledge_preferences
        .includes(:knowledge_base_category)
        .index_by(&:knowledge_base_category_id)
    end
  end

  def show
    @document = UxKnowledgeDocument.find(params[:id])
    track_knowledge_document_view(@document.id, @document.file_name)
  end

  def search
    @query = params[:query]
    @results = []

    if @query.present?
      @results = UxKnowledgeDocument.search_by_content(@query, limit: 10)
      track_knowledge_search(@query, @results.length)
      @retrieval_service = UxKnowledgeRetrievalService.new
      @formatted_context = @retrieval_service.retrieve_relevant_context(@query)
    end
  end

  def reindex
    if request.post?
      UxKnowledgeIndexingService.new.reindex_all(Rails.root.join('lib/ux_knowledge/pdfs').to_s)
      redirect_to ux_knowledge_documents_path, notice: "Knowledge base reindexed successfully!"
    end
  end

  private

  def determine_layout
    # Use marketing layout if on marketing domain, otherwise use application layout
    if request.subdomain.blank? || request.subdomain == 'www'
      'marketing'
    else
      'application'
    end
  end
end
