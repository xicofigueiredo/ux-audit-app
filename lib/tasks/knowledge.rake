namespace :knowledge do
  desc "Categorize existing UX knowledge documents"
  task categorize_documents: :environment do
    puts "Categorizing existing UX knowledge documents..."

    # Define categorization rules based on file names
    categorization_rules = {
      "core_heuristics" => [
        /nielsen.*heuristic/i,
        /shneiderman/i,
        /golden.*rules/i,
        /ux.*fundamental/i,
        /usability.*principles/i
      ],
      "accessibility" => [
        /wcag/i,
        /accessibility/i,
        /aria/i,
        /inclusive.*design/i,
        /screen.*reader/i,
        /color.*contrast/i,
        /keyboard.*navigation/i,
        /a11y/i
      ],
      "design_systems" => [
        /design.*system/i,
        /component.*library/i,
        /design.*token/i,
        /ui.*pattern/i,
        /style.*guide/i,
        /brand.*guidelines/i
      ],
      "ai_interfaces" => [
        /ai.*interface/i,
        /llm/i,
        /chatbot/i,
        /conversational.*ui/i,
        /generative.*ui/i,
        /prompt.*design/i,
        /ai.*transparency/i
      ],
      "mobile_platforms" => [
        /ios.*hig/i,
        /human.*interface.*guidelines/i,
        /material.*design/i,
        /mobile/i,
        /android/i,
        /touch.*target/i,
        /gesture/i
      ]
    }

    # Get all categories
    categories = KnowledgeBaseCategory.all.index_by(&:slug)

    # Process each document
    uncategorized_count = 0
    categorized_count = 0

    UxKnowledgeDocument.where(category_id: nil).find_each do |doc|
      category_slug = nil

      # Try to match document filename against rules
      categorization_rules.each do |slug, patterns|
        if patterns.any? { |pattern| doc.file_name =~ pattern }
          category_slug = slug
          break
        end
      end

      # If no match found, try matching against content (first 1000 chars)
      unless category_slug
        content_sample = doc.content.to_s.first(1000).downcase
        categorization_rules.each do |slug, patterns|
          if patterns.any? { |pattern| content_sample =~ pattern }
            category_slug = slug
            break
          end
        end
      end

      # Assign category or default to core_heuristics
      if category_slug && categories[category_slug]
        doc.update!(category: categories[category_slug])
        puts "  ✓ #{doc.file_name} → #{categories[category_slug].name}"
        categorized_count += 1
      else
        # Default to core_heuristics if no match found
        doc.update!(category: categories["core_heuristics"])
        puts "  ⚠ #{doc.file_name} → Core Heuristics (default)"
        uncategorized_count += 1
      end
    end

    puts "\nCategorization complete!"
    puts "  Categorized: #{categorized_count} documents"
    puts "  Defaulted: #{uncategorized_count} documents"
    puts "  Total: #{categorized_count + uncategorized_count} documents"
  end

  desc "Initialize knowledge preferences for existing users"
  task initialize_user_preferences: :environment do
    puts "Initializing knowledge preferences for existing users..."

    users_updated = 0
    users_skipped = 0

    User.find_each do |user|
      if user.user_knowledge_preferences.any?
        puts "  ⊘ Skipping #{user.email} (already has preferences)"
        users_skipped += 1
      else
        KnowledgeBaseCategory.defaults.find_each do |category|
          user.user_knowledge_preferences.create!(
            knowledge_base_category: category,
            enabled: true
          )
        end
        puts "  ✓ Initialized preferences for #{user.email}"
        users_updated += 1
      end
    end

    puts "\nInitialization complete!"
    puts "  Updated: #{users_updated} users"
    puts "  Skipped: #{users_skipped} users"
  end

  desc "Show knowledge base statistics"
  task stats: :environment do
    puts "\n=== Knowledge Base Statistics ==="
    puts "\nCategories:"
    KnowledgeBaseCategory.ordered.each do |category|
      enabled_count = category.user_knowledge_preferences.enabled.count
      total_users = User.count
      percentage = total_users > 0 ? (enabled_count.to_f / total_users * 100).round(1) : 0

      puts "  #{category.name}"
      puts "    Documents: #{category.document_count}"
      puts "    Enabled by: #{enabled_count}/#{total_users} users (#{percentage}%)"
      puts "    Default: #{category.default_enabled? ? 'Yes' : 'No'}"
      puts ""
    end

    puts "Total Documents: #{UxKnowledgeDocument.count}"
    puts "Uncategorized: #{UxKnowledgeDocument.where(category_id: nil).count}"
    puts ""
  end
end
