# Knowledge Base Categories Seed Data
# This file populates the initial knowledge base categories

categories = [
  {
    name: "Core Heuristics",
    slug: "core_heuristics",
    description: "Fundamental UX principles and heuristics",
    use_case: "Recommended for all audits to catch core usability issues. " \
              "Includes Nielsen's 10 Usability Heuristics and Shneiderman's Golden Rules.",
    default_enabled: true,
    position: 1
  },
  {
    name: "Accessibility & Inclusive Design",
    slug: "accessibility",
    description: "WCAG standards, ARIA patterns, and inclusive design principles",
    use_case: "Enable for audits requiring WCAG 2.1/2.2 compliance or accessibility-focused " \
              "reviews. Essential for government, healthcare, and enterprise applications.",
    default_enabled: false,
    position: 2
  },
  {
    name: "Design Systems & UI Patterns",
    slug: "design_systems",
    description: "Component libraries, design tokens, and modern UI patterns",
    use_case: "Best for evaluating design consistency, component usage, and design system " \
              "compliance. Useful for brand consistency audits.",
    default_enabled: false,
    position: 3
  },
  {
    name: "AI/LLM Interface Design",
    slug: "ai_interfaces",
    description: "Best practices for conversational UI, AI transparency, and LLM-powered features",
    use_case: "Enable when auditing chatbots, AI assistants, or generative UI experiences. " \
              "Covers prompt design, AI feedback, and conversational flows.",
    default_enabled: false,
    position: 4
  },
  {
    name: "Mobile & Platform-Specific",
    slug: "mobile_platforms",
    description: "Platform-specific guidelines (iOS HIG, Material Design, native patterns)",
    use_case: "Enable for mobile app audits or platform-specific design reviews. " \
              "Covers touch targets, gestures, and native conventions.",
    default_enabled: false,
    position: 5
  }
]

puts "Seeding knowledge base categories..."

categories.each do |cat_data|
  category = KnowledgeBaseCategory.find_or_initialize_by(slug: cat_data[:slug])
  category.assign_attributes(cat_data)

  if category.save
    puts "  ✓ #{category.name} (#{category.slug})"
  else
    puts "  ✗ Failed to create #{cat_data[:name]}: #{category.errors.full_messages.join(', ')}"
  end
end

puts "Finished seeding #{KnowledgeBaseCategory.count} categories."
