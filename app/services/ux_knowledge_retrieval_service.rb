class UxKnowledgeRetrievalService
  CACHE_EXPIRES_IN = 15.minutes

  def initialize
    @embedding_service = UxKnowledgeEmbeddingService.new
  end

  def retrieve_relevant_context(query, limit: 8)
    return "" if query.blank?

    relevant_docs = UxKnowledgeDocument.search_by_content(query, limit: limit)

    if relevant_docs.empty?
      Rails.logger.info "No relevant UX knowledge found for query: #{query.truncate(100)}"
      return ""
    end

    format_context(relevant_docs)
  end

  def retrieve_for_ux_analysis(analysis_context)
    # Extract key UX-related terms from the analysis context
    ux_queries = extract_ux_queries(analysis_context)

    all_relevant_docs = []

    ux_queries.each do |query|
      docs = UxKnowledgeDocument.search_by_content(query, limit: 5)
      all_relevant_docs.concat(docs)
    end

    # Remove duplicates and limit total results
    unique_docs = all_relevant_docs.uniq(&:id).first(10)

    format_context(unique_docs)
  end

  def retrieve_for_user_audit(analysis_context, user)
    # Return empty if no categories enabled
    enabled_categories = user.enabled_knowledge_categories
    return "" if enabled_categories.empty?

    # Generate cache key
    category_ids = enabled_categories.pluck(:id).sort
    context_hash = Digest::MD5.hexdigest(analysis_context.to_s)
    cache_key = "knowledge_retrieval/user_#{user.id}/categories_#{category_ids.join('_')}/context_#{context_hash}"

    # Try cache first
    Rails.cache.fetch(cache_key, expires_in: CACHE_EXPIRES_IN) do
      retrieve_for_user_audit_uncached(analysis_context, enabled_categories)
    end
  end

  def search_heuristics_by_category(category)
    category_queries = {
      'usability' => 'Nielsen heuristics usability principles',
      'accessibility' => 'accessibility WCAG standards inclusive design',
      'ai_interface' => 'AI interface design chatbot conversation LLM',
      'design_systems' => 'design system components pattern library',
      'golden_rules' => 'Shneiderman golden rules interface design'
    }

    query = category_queries[category.to_s] || category.to_s
    retrieve_relevant_context(query, limit: 6)
  end

  private

  def retrieve_for_user_audit_uncached(analysis_context, enabled_categories)
    # Extract UX concepts from the analysis context
    ux_concepts = extract_ux_concepts(analysis_context)

    # Get category IDs for filtering
    category_ids = enabled_categories.pluck(:id)

    # Retrieve relevant chunks from enabled categories only
    all_docs = []
    ux_concepts.each do |concept|
      docs = UxKnowledgeDocument.search_by_content(
        concept,
        limit: 5,
        category_ids: category_ids
      )
      all_docs.concat(docs)
    end

    # Remove duplicates and limit total results
    unique_docs = all_docs.uniq(&:id).first(10)

    # Format as condensed context string
    format_context_for_audit(unique_docs)
  end

  def format_context_for_audit(documents)
    return "" if documents.empty?

    formatted = documents.map do |doc|
      # Include file name for citation
      "#{doc.file_name}: #{doc.content}"
    end.join("\n\n")

    formatted
  end

  def format_context(documents)
    return "" if documents.empty?

    context_parts = []

    # Group by file name to avoid redundant citations
    docs_by_file = documents.group_by(&:file_name)

    docs_by_file.each do |file_name, docs|
      file_content = docs.map(&:content).join("\n\n")

      context_parts << "From #{format_file_name(file_name)}:\n#{file_content.strip}"
    end

    context_parts.join("\n\n---\n\n")
  end

  def format_file_name(file_name)
    # Clean up file names for better presentation
    file_name
      .gsub('.pdf', '')
      .gsub('_', ' ')
      .gsub(/\(\d+\)/, '') # Remove (1), (2) etc.
      .strip
      .titleize
  end

  def extract_ux_concepts(analysis_context)
    # Extract relevant UX concepts from the analysis context
    base_concepts = ["usability", "user experience"]

    # Add context-specific concepts
    base_concepts << "navigation" if analysis_context.match?(/nav|menu|sidebar/i)
    base_concepts << "forms" if analysis_context.match?(/form|input|submit/i)
    base_concepts << "accessibility" if analysis_context.match?(/access|wcag|aria/i)
    base_concepts << "mobile" if analysis_context.match?(/mobile|ios|android/i)
    base_concepts << "AI interface" if analysis_context.match?(/chatbot|ai|assistant/i)
    base_concepts << "error handling" if analysis_context.match?(/error|warning|alert/i)
    base_concepts << "design system" if analysis_context.match?(/component|pattern|design system/i)

    base_concepts.uniq
  end

  def extract_ux_queries(analysis_context)
    # Extract relevant UX concepts that might be in the analysis
    # This could be made more sophisticated with NLP, but for now we'll use keywords

    base_queries = []

    # Check for specific UX concepts in the context
    if analysis_context.match?(/navigation|menu|sidebar/i)
      base_queries << "navigation design principles"
    end

    if analysis_context.match?(/form|input|field/i)
      base_queries << "form design usability"
    end

    if analysis_context.match?(/error|warning|alert/i)
      base_queries << "error handling user feedback"
    end

    if analysis_context.match?(/mobile|responsive|touch/i)
      base_queries << "mobile interface design"
    end

    if analysis_context.match?(/accessibility|screen reader|contrast/i)
      base_queries << "accessibility guidelines WCAG"
    end

    if analysis_context.match?(/ai|chatbot|conversation/i)
      base_queries << "AI interface design patterns"
    end

    # Always include core heuristics
    base_queries << "Nielsen heuristics"
    base_queries << "usability principles"

    # Fallback to general UX if no specific matches
    base_queries << "user experience design" if base_queries.size < 3

    base_queries.uniq.first(4) # Limit to avoid too many API calls
  end
end