# Knowledge Base Toggles Implementation Plan

**Project**: User-Configurable Knowledge Base Categories for UX Audits
**Version**: 1.0
**Date**: October 23, 2025
**Status**: Planning
**Owner**: Engineering Team
**Stakeholders**: Product, Engineering, UX

---

## Executive Summary

This document outlines the complete implementation plan for adding user-configurable knowledge base categories to our UX audit platform. Users will be able to toggle which reference materials (accessibility standards, AI guidelines, design systems, etc.) inform their audits, enabling specialized audit types like accessibility-focused reviews, mobile app audits, or AI interface evaluations.

**Business Value**:
- Enable specialized audit types (accessibility, mobile, AI/LLM interfaces)
- Improve audit relevance and accuracy through targeted knowledge retrieval
- Reduce noise in audit results by focusing on user-selected domains
- Differentiate our product with customizable audit intelligence

**Technical Approach**: Extend existing RAG (Retrieval-Augmented Generation) system with user preferences, category-based document organization, and dynamic prompt augmentation.

---

## Table of Contents

1. [Current State Analysis](#current-state-analysis)
2. [Proposed Architecture](#proposed-architecture)
3. [Knowledge Base Categories](#knowledge-base-categories)
4. [Implementation Phases](#implementation-phases)
5. [Technical Specifications](#technical-specifications)
6. [Testing Strategy](#testing-strategy)
7. [Deployment Plan](#deployment-plan)
8. [Future Enhancements](#future-enhancements)
9. [Success Metrics](#success-metrics)
10. [Risk Assessment](#risk-assessment)

---

## Current State Analysis

### Existing Infrastructure

**RAG System Components**:
- ✅ Vector database: `ux_knowledge_documents` table with pgvector
- ✅ Embeddings: OpenAI text-embedding-3-small (1536 dimensions)
- ✅ Retrieval service: `UxKnowledgeRetrievalService` with semantic search
- ✅ 26 PDF documents indexed across multiple domains
- ❌ **Not integrated**: Knowledge base retrieval not connected to audit pipeline

**Current Limitations**:
1. All documents treated equally (no categorization)
2. No user control over which knowledge informs audits
3. Knowledge base exists but isn't used during analysis
4. No way to specialize audits for accessibility, mobile, or AI interfaces

### Database Schema (Relevant Tables)

```
users
├── id, email, encrypted_password
└── has_many :video_audits

video_audits
├── id, user_id, status, llm_response
└── belongs_to :user

ux_knowledge_documents
├── id, content, file_name, chunk_index
├── embedding (vector 1536)
└── NO category association currently
```

---

## Proposed Architecture

### System Overview

```
┌─────────────┐     ┌──────────────────┐     ┌─────────────────┐
│   User      │────▶│  Settings Page   │────▶│ User Knowledge  │
│ Preferences │     │  (Toggle UI)     │     │  Preferences    │
└─────────────┘     └──────────────────┘     └─────────────────┘
                                                       │
                                                       ▼
┌─────────────┐     ┌──────────────────┐     ┌─────────────────┐
│ Video Upload│────▶│ Analysis Service │────▶│   RAG Retrieval │
│   + Audit   │     │  (LLM Pipeline)  │     │   (Filtered)    │
└─────────────┘     └──────────────────┘     └─────────────────┘
                              │                        │
                              ▼                        ▼
                    ┌──────────────────┐     ┌─────────────────┐
                    │ Prompt Generator │◀────│ Knowledge Base  │
                    │ (+ KB Context)   │     │  (Categorized)  │
                    └──────────────────┘     └─────────────────┘
                              │
                              ▼
                    ┌──────────────────┐
                    │  OpenAI GPT-5    │
                    │  (Audit Analysis)│
                    └──────────────────┘
```

### Data Flow

1. **User configures preferences** → Settings page → `user_knowledge_preferences` table
2. **User uploads video** → `VideoProcessingJob` → `AnalysisService`
3. **Analysis Service** → Reads user's enabled categories
4. **RAG Retrieval** → Queries only documents in enabled categories
5. **Prompt Generator** → Injects relevant knowledge into system message
6. **LLM Analysis** → GPT-5 uses augmented prompt with domain-specific knowledge
7. **Results** → More targeted, relevant audit findings

---

## Knowledge Base Categories

### Category Definitions

| Category | Documents | Default | Description | Best Use Case |
|----------|-----------|---------|-------------|---------------|
| **Core Heuristics** | 3 PDFs | ✅ ON | Nielsen's 10 Usability Heuristics, Shneiderman's Golden Rules, comprehensive UX fundamentals | All audits - foundational principles |
| **Accessibility & Inclusive Design** | 8 PDFs | ❌ OFF | WCAG 2.1/2.2, ARIA patterns, screen reader compatibility, color contrast, keyboard navigation | WCAG compliance audits, government/healthcare apps |
| **Design Systems & UI Patterns** | 8 PDFs | ❌ OFF | Component libraries, design tokens, spacing systems, typography scales, modern UI patterns | Design system compliance, brand consistency reviews |
| **AI/LLM Interface Design** | 4 PDFs | ❌ OFF | Conversational UI, chatbot best practices, AI transparency, prompt design, generative UI | AI assistants, chatbots, LLM-powered features |
| **Mobile & Platform-Specific** | 0 PDFs* | ❌ OFF | iOS HIG, Material Design, native patterns, gesture controls | Mobile app audits, platform-specific reviews |

*Future: Add Apple HIG, Material Design, mobile-specific documents

### Category Slugs (Database Keys)

- `core_heuristics`
- `accessibility`
- `design_systems`
- `ai_interfaces`
- `mobile_platforms`

---

## Implementation Phases

### Phase 1: Database Schema & Models (Week 1)

**Objective**: Create database structure for categories and user preferences

**Tasks**:
1. Create `knowledge_base_categories` table
2. Create `user_knowledge_preferences` join table
3. Add `category_id` to `ux_knowledge_documents`
4. Seed initial 5 categories with descriptions
5. Create categorization script for existing documents
6. Update models with associations

**Deliverables**:
- 3 migration files
- 2 new model files (`KnowledgeBaseCategory`, `UserKnowledgePreference`)
- Updated `User` model with preference methods
- Seed file with category data
- Rake task to categorize documents

**Acceptance Criteria**:
- ✅ All migrations run without errors
- ✅ Categories seeded with correct descriptions
- ✅ All existing documents assigned to categories
- ✅ User can query `enabled_knowledge_categories`
- ✅ Tests pass for model associations

---

### Phase 2: Settings UI (Week 2)

**Objective**: Build user interface for toggling knowledge categories

**Tasks**:
1. Design settings page section with toggle switches
2. Implement Stimulus controller for toggle interactions
3. Add AJAX endpoint for saving preferences
4. Create visual feedback (loading states, success indicators)
5. Initialize default preferences on user signup
6. Add responsive mobile layout

**Deliverables**:
- Updated `app/views/settings/index.html.erb`
- New Stimulus controller: `knowledge_preference_controller.js`
- Updated `SettingsController` with AJAX actions
- CSS styling for toggle switches
- User registration callback for default preferences

**UI Mockup**:
```
┌─────────────────────────────────────────────────────────┐
│  🧠 Audit Knowledge Base                                │
│  Configure which reference materials inform your audits │
├─────────────────────────────────────────────────────────┤
│                                                          │
│  ✅ Core Heuristics                      [●────── ON]   │
│     📘 3 documents                                       │
│     Fundamental UX principles and heuristics.           │
│     Recommended for all audits to catch core issues.    │
│                                                          │
│  ☐  Accessibility & Inclusive Design    [○────── OFF]  │
│     📗 8 documents                                       │
│     WCAG 2.1/2.2 standards, ARIA patterns, inclusive    │
│     design. Enable for accessibility-focused reviews.   │
│                                                          │
│  ✅ Design Systems & UI Patterns        [●────── ON]   │
│     📙 8 documents                                       │
│     Component libraries, design tokens, modern patterns.│
│     Best for evaluating design consistency.             │
│                                                          │
│  ☐  AI/LLM Interface Design             [○────── OFF]  │
│     📕 4 documents                                       │
│     Best practices for conversational UI and AI.        │
│     Enable for chatbots, AI assistants, generative UI.  │
│                                                          │
│  ☐  Mobile & Platform-Specific          [○────── OFF]  │
│     📓 0 documents (coming soon)                        │
│     iOS HIG, Material Design, native mobile patterns.   │
│     Enable for mobile app audits.                       │
│                                                          │
│  💡 Tip: Categories are saved automatically on toggle   │
└─────────────────────────────────────────────────────────┘
```

**Acceptance Criteria**:
- ✅ Toggles reflect user's current preferences on page load
- ✅ Toggle changes save immediately via AJAX
- ✅ Visual feedback during save (spinner, success checkmark)
- ✅ New users get "Core Heuristics" enabled by default
- ✅ Mobile-responsive layout works on small screens
- ✅ Accessible (keyboard navigation, screen reader labels)

---

### Phase 3: RAG Integration (Week 3)

**Objective**: Connect user preferences to analysis pipeline with knowledge retrieval

**Tasks**:
1. Update `UxKnowledgeRetrievalService` with category filtering
2. Implement user-aware retrieval method
3. Modify `PromptGenerator` to inject knowledge context
4. Update `AnalysisService` to pass user to prompt generator
5. Add token limit management for knowledge context
6. Optimize retrieval performance (caching, query optimization)

**Technical Details**:

#### 3.1 Enhanced Retrieval Service

**File**: `app/services/ux_knowledge_retrieval_service.rb`

```ruby
class UxKnowledgeRetrievalService
  def retrieve_for_user_audit(analysis_context, user)
    enabled_categories = user.enabled_knowledge_categories

    # Return empty if no categories enabled
    return "" if enabled_categories.empty?

    # Extract UX concepts from context
    ux_concepts = extract_ux_concepts(analysis_context)

    # Retrieve relevant chunks from enabled categories only
    merged_docs = ux_concepts.flat_map do |concept|
      UxKnowledgeDocument
        .joins(:category)
        .where(knowledge_base_categories: { id: enabled_categories.pluck(:id) })
        .search_by_content(concept, limit: 5)
    end.uniq(&:id).first(10)

    # Format as condensed context string
    format_as_context(merged_docs)
  end

  private

  def extract_ux_concepts(context)
    # Extract keywords from audit context
    base_concepts = ["usability", "user experience"]

    # Add context-specific concepts
    base_concepts << "navigation" if context.match?(/nav|menu|sidebar/i)
    base_concepts << "forms" if context.match?(/form|input|submit/i)
    base_concepts << "accessibility" if context.match?(/access|wcag|aria/i)
    base_concepts << "mobile" if context.match?(/mobile|ios|android/i)
    base_concepts << "AI interface" if context.match?(/chatbot|ai|assistant/i)

    base_concepts
  end

  def format_as_context(documents)
    return "" if documents.empty?

    formatted = documents.map do |doc|
      # Truncate to 500 chars per chunk
      "#{doc.file_name}: #{doc.content.truncate(500, omission: '...')}"
    end.join("\n\n")

    # Ensure total context stays under ~5000 chars
    formatted.truncate(5000, omission: "\n\n[Additional documents truncated...]")
  end
end
```

#### 3.2 Prompt Generator Enhancement

**File**: `app/services/llm/prompt_generator.rb`

```ruby
class Llm::PromptGenerator
  def initialize(video_audit:, user:, frames:, batch_num: nil, total_batches: nil)
    @video_audit = video_audit
    @user = user
    @frames = frames
    @batch_num = batch_num
    @total_batches = total_batches
    @knowledge_context = fetch_knowledge_context
  end

  def generate
    {
      model: @model,
      messages: messages_with_knowledge,
      # ... rest of configuration
    }
  end

  private

  def fetch_knowledge_context
    return nil unless @user.knowledge_base_enabled?

    analysis_context = build_analysis_context
    UxKnowledgeRetrievalService.new.retrieve_for_user_audit(analysis_context, @user)
  end

  def build_analysis_context
    "UX audit of #{@video_audit.title || 'user interface'} " \
    "#{@video_audit.description}"
  end

  def messages_with_knowledge
    [
      { role: "system", content: system_message_with_knowledge },
      # ... rest of messages
    ]
  end

  def system_message_with_knowledge
    base_message = system_message_for_model(@model)

    if @knowledge_context.present?
      base_message + "\n\n" + knowledge_context_section
    else
      base_message
    end
  end

  def knowledge_context_section
    <<~KNOWLEDGE

      === REFERENCE MATERIALS ===
      The following curated UX knowledge has been selected based on user preferences
      to inform your analysis. Use these as authoritative references, but maintain
      focus on observable issues in the interface.

      #{@knowledge_context}

      ===========================

    KNOWLEDGE
  end
end
```

#### 3.3 Analysis Service Update

**File**: `app/services/llm/analysis_service.rb`

```ruby
def analyze_batch(batch_frames, batch_num)
  prompt_generator = Llm::PromptGenerator.new(
    video_audit: @video_audit,
    user: @video_audit.user, # ADD THIS LINE
    frames: batch_frames,
    batch_num: batch_num,
    total_batches: @total_batches
  )

  # ... rest of method unchanged
end
```

**Deliverables**:
- Updated retrieval service with category filtering
- Enhanced prompt generator with knowledge injection
- Modified analysis service to pass user context
- Performance optimization (query indexes, caching)
- Token usage monitoring

**Acceptance Criteria**:
- ✅ Audits retrieve only from enabled categories
- ✅ Knowledge context appears in LLM prompts
- ✅ Token usage stays within acceptable limits (<8K tokens/batch)
- ✅ Retrieval queries complete in <500ms
- ✅ Audit results show improved relevance for specialized audits

---

### Phase 4: Testing & Quality Assurance (Week 4)

**Objective**: Comprehensive testing and validation

**Tasks**:
1. Unit tests for new models and associations
2. Integration tests for settings controller
3. Service tests for RAG retrieval with categories
4. End-to-end tests: upload video → audit with categories
5. Performance testing (query speed, token usage)
6. User acceptance testing with beta users
7. A/B testing: audits with vs without knowledge context

**Test Scenarios**:

| Scenario | Setup | Expected Result |
|----------|-------|-----------------|
| New user default preferences | Create new user | Core Heuristics enabled, others disabled |
| Toggle category ON | User enables Accessibility | Future audits include accessibility docs |
| Toggle category OFF | User disables Core Heuristics | Future audits exclude those docs |
| All categories disabled | User disables all | Audit runs without knowledge context |
| Accessibility audit | Enable only Accessibility | Finds WCAG issues, ignores AI patterns |
| AI interface audit | Enable only AI/LLM category | Finds conversational UI issues |
| Multi-category audit | Enable Accessibility + AI | Finds issues from both domains |

**Deliverables**:
- Test suite with 50+ test cases
- Performance benchmarks document
- Bug fix backlog
- User testing feedback report

**Acceptance Criteria**:
- ✅ 95%+ test coverage for new code
- ✅ All edge cases handled (no categories, all categories)
- ✅ No performance degradation (audit time increase <15%)
- ✅ Token usage increase acceptable (<20%)
- ✅ Beta users report improved audit relevance

---

### Phase 5: Documentation & Deployment (Week 5)

**Objective**: Prepare for production release

**Tasks**:
1. Write user-facing documentation (help text, tooltips)
2. Create admin documentation for category management
3. Prepare deployment runbook
4. Set up monitoring and alerts
5. Create rollback plan
6. Deploy to staging environment
7. Production deployment
8. Post-deployment monitoring

**Deliverables**:
- User guide: "Customizing Your Audit Knowledge Base"
- Admin guide: "Managing Knowledge Base Categories"
- Deployment runbook with rollback procedures
- Monitoring dashboard for feature adoption
- Release notes for product team

**Deployment Checklist**:
- [ ] Database migrations tested on staging
- [ ] Existing users get default preferences via migration
- [ ] Feature flag enabled for gradual rollout
- [ ] Monitoring alerts configured
- [ ] Rollback script tested
- [ ] Customer support team briefed
- [ ] Product team approval
- [ ] Deploy to production
- [ ] Monitor for 48 hours
- [ ] Send release announcement

**Acceptance Criteria**:
- ✅ Zero-downtime deployment
- ✅ All existing users have default preferences
- ✅ No increase in error rates
- ✅ Documentation published
- ✅ Feature adoption tracking active

---

## Technical Specifications

### Database Schema

#### Table: `knowledge_base_categories`

```sql
CREATE TABLE knowledge_base_categories (
  id BIGSERIAL PRIMARY KEY,
  name VARCHAR(255) NOT NULL,
  slug VARCHAR(255) NOT NULL UNIQUE,
  description TEXT,
  use_case TEXT,
  default_enabled BOOLEAN DEFAULT FALSE,
  position INTEGER DEFAULT 0,
  created_at TIMESTAMP NOT NULL,
  updated_at TIMESTAMP NOT NULL
);

CREATE INDEX index_knowledge_base_categories_on_slug
  ON knowledge_base_categories(slug);
CREATE INDEX index_knowledge_base_categories_on_position
  ON knowledge_base_categories(position);
```

#### Table: `user_knowledge_preferences`

```sql
CREATE TABLE user_knowledge_preferences (
  id BIGSERIAL PRIMARY KEY,
  user_id BIGINT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  knowledge_base_category_id BIGINT NOT NULL
    REFERENCES knowledge_base_categories(id) ON DELETE CASCADE,
  enabled BOOLEAN DEFAULT TRUE,
  created_at TIMESTAMP NOT NULL,
  updated_at TIMESTAMP NOT NULL,

  CONSTRAINT unique_user_category
    UNIQUE(user_id, knowledge_base_category_id)
);

CREATE INDEX index_user_knowledge_prefs_on_user_id
  ON user_knowledge_preferences(user_id);
CREATE INDEX index_user_knowledge_prefs_on_category_id
  ON user_knowledge_preferences(knowledge_base_category_id);
CREATE INDEX index_user_knowledge_prefs_on_enabled
  ON user_knowledge_preferences(enabled) WHERE enabled = TRUE;
```

#### Update: `ux_knowledge_documents`

```sql
ALTER TABLE ux_knowledge_documents
  ADD COLUMN category_id BIGINT REFERENCES knowledge_base_categories(id);

CREATE INDEX index_ux_knowledge_documents_on_category_id
  ON ux_knowledge_documents(category_id);
```

### Seed Data

**File**: `db/seeds/knowledge_categories.rb`

```ruby
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

categories.each do |cat_data|
  KnowledgeBaseCategory.find_or_create_by!(slug: cat_data[:slug]) do |cat|
    cat.assign_attributes(cat_data)
  end
end
```

### Model Implementations

#### `app/models/knowledge_base_category.rb`

```ruby
class KnowledgeBaseCategory < ApplicationRecord
  has_many :ux_knowledge_documents,
           foreign_key: :category_id,
           dependent: :nullify
  has_many :user_knowledge_preferences, dependent: :destroy
  has_many :users, through: :user_knowledge_preferences

  validates :name, :slug, presence: true
  validates :slug, uniqueness: true, format: { with: /\A[a-z_]+\z/ }

  scope :ordered, -> { order(:position) }
  scope :defaults, -> { where(default_enabled: true) }

  def document_count
    ux_knowledge_documents.count
  end
end
```

#### `app/models/user_knowledge_preference.rb`

```ruby
class UserKnowledgePreference < ApplicationRecord
  belongs_to :user
  belongs_to :knowledge_base_category

  validates :user_id, uniqueness: { scope: :knowledge_base_category_id }

  scope :enabled, -> { where(enabled: true) }
  scope :disabled, -> { where(enabled: false) }
end
```

#### `app/models/user.rb` (additions)

```ruby
class User < ApplicationRecord
  # ... existing code ...

  has_many :user_knowledge_preferences, dependent: :destroy
  has_many :knowledge_base_categories, through: :user_knowledge_preferences
  has_many :enabled_knowledge_categories,
           -> { where(user_knowledge_preferences: { enabled: true }) },
           through: :user_knowledge_preferences,
           source: :knowledge_base_category

  after_create :initialize_default_knowledge_preferences

  def knowledge_base_enabled?
    enabled_knowledge_categories.any?
  end

  def toggle_knowledge_category(category_slug, enabled)
    category = KnowledgeBaseCategory.find_by!(slug: category_slug)
    pref = user_knowledge_preferences.find_or_initialize_by(
      knowledge_base_category: category
    )
    pref.update!(enabled: enabled)
  end

  def category_enabled?(category_slug)
    enabled_knowledge_categories.exists?(slug: category_slug)
  end

  private

  def initialize_default_knowledge_preferences
    KnowledgeBaseCategory.defaults.find_each do |category|
      user_knowledge_preferences.create!(
        knowledge_base_category: category,
        enabled: true
      )
    end
  end
end
```

### API Endpoints

#### Routes

```ruby
# config/routes.rb
resources :settings, only: [:index] do
  collection do
    patch :update_knowledge_preference
    post :reset_knowledge_preferences
  end
end
```

#### Controller Actions

```ruby
# app/controllers/settings_controller.rb
def index
  @knowledge_categories = KnowledgeBaseCategory
    .ordered
    .includes(:ux_knowledge_documents)
  @user_preferences = current_user
    .user_knowledge_preferences
    .includes(:knowledge_base_category)
    .index_by(&:knowledge_base_category_id)
end

def update_knowledge_preference
  category = KnowledgeBaseCategory.find_by!(slug: params[:category_slug])
  enabled = ActiveModel::Type::Boolean.new.cast(params[:enabled])

  current_user.toggle_knowledge_category(params[:category_slug], enabled)

  respond_to do |format|
    format.json {
      render json: {
        success: true,
        message: "#{category.name} #{enabled ? 'enabled' : 'disabled'}"
      }
    }
    format.html {
      redirect_to settings_path,
      notice: "Knowledge base preferences updated"
    }
  end
rescue ActiveRecord::RecordNotFound
  render json: { success: false, error: "Category not found" }, status: :not_found
end

def reset_knowledge_preferences
  current_user.user_knowledge_preferences.destroy_all
  current_user.initialize_default_knowledge_preferences

  redirect_to settings_path, notice: "Preferences reset to defaults"
end
```

### Frontend Implementation

#### Stimulus Controller

**File**: `app/javascript/controllers/knowledge_preference_controller.js`

```javascript
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["toggle", "status"]
  static values = { url: String }

  async toggle(event) {
    const toggle = event.currentTarget
    const categorySlug = toggle.dataset.categorySlug
    const enabled = toggle.checked

    // Optimistic UI update
    this.updateStatus(toggle, "saving")

    try {
      const response = await fetch(this.urlValue, {
        method: "PATCH",
        headers: {
          "Content-Type": "application/json",
          "X-CSRF-Token": this.csrfToken
        },
        body: JSON.stringify({
          category_slug: categorySlug,
          enabled: enabled
        })
      })

      const data = await response.json()

      if (data.success) {
        this.updateStatus(toggle, "success")
        setTimeout(() => this.updateStatus(toggle, "idle"), 2000)
      } else {
        throw new Error(data.error)
      }
    } catch (error) {
      console.error("Failed to update preference:", error)
      toggle.checked = !enabled // Revert
      this.updateStatus(toggle, "error")
      setTimeout(() => this.updateStatus(toggle, "idle"), 3000)
    }
  }

  updateStatus(toggle, state) {
    const row = toggle.closest("[data-knowledge-preference-target='row']")
    row.dataset.state = state

    // Update status indicator
    const indicator = row.querySelector(".status-indicator")
    if (indicator) {
      indicator.textContent = {
        saving: "Saving...",
        success: "✓ Saved",
        error: "✗ Error",
        idle: ""
      }[state]
    }
  }

  get csrfToken() {
    return document.querySelector("[name='csrf-token']").content
  }
}
```

#### View Template

**File**: `app/views/settings/index.html.erb`

```erb
<div class="max-w-4xl mx-auto py-8">
  <h1 class="text-3xl font-bold mb-8">Settings</h1>

  <!-- Existing account settings ... -->

  <!-- Knowledge Base Preferences -->
  <section class="bg-white rounded-lg shadow-sm p-6 mb-6">
    <div class="mb-6">
      <h2 class="text-2xl font-semibold mb-2">🧠 Audit Knowledge Base</h2>
      <p class="text-gray-600">
        Configure which reference materials inform your audits.
        Changes apply to all future audits.
      </p>
    </div>

    <div class="space-y-4"
         data-controller="knowledge-preference"
         data-knowledge-preference-url-value="<%= update_knowledge_preference_settings_path %>">

      <% @knowledge_categories.each do |category| %>
        <% preference = @user_preferences[category.id] %>
        <% enabled = preference&.enabled || false %>

        <div class="border rounded-lg p-4 hover:border-blue-300 transition-colors"
             data-knowledge-preference-target="row"
             data-state="idle">

          <div class="flex items-start justify-between mb-2">
            <div class="flex items-center gap-3 flex-1">
              <label class="relative inline-flex items-center cursor-pointer">
                <input type="checkbox"
                       data-knowledge-preference-target="toggle"
                       data-category-slug="<%= category.slug %>"
                       data-action="change->knowledge-preference#toggle"
                       <%= "checked" if enabled %>
                       class="sr-only peer">
                <div class="w-11 h-6 bg-gray-200 peer-focus:outline-none peer-focus:ring-4
                            peer-focus:ring-blue-300 rounded-full peer
                            peer-checked:after:translate-x-full peer-checked:after:border-white
                            after:content-[''] after:absolute after:top-[2px] after:left-[2px]
                            after:bg-white after:border-gray-300 after:border after:rounded-full
                            after:h-5 after:w-5 after:transition-all
                            peer-checked:bg-blue-600"></div>
              </label>

              <div class="flex-1">
                <h3 class="font-semibold text-lg">
                  <%= enabled ? "✅" : "☐" %> <%= category.name %>
                </h3>
                <p class="text-sm text-gray-500">
                  📚 <%= category.document_count %> documents
                </p>
              </div>

              <span class="status-indicator text-sm text-gray-500"></span>
            </div>
          </div>

          <div class="ml-14">
            <p class="text-sm text-gray-700 mb-2">
              <%= category.description %>
            </p>
            <p class="text-xs text-gray-500 italic">
              <strong>Best for:</strong> <%= category.use_case %>
            </p>
          </div>

        </div>
      <% end %>
    </div>

    <div class="mt-6 flex gap-3">
      <%= button_to "Reset to Defaults",
          reset_knowledge_preferences_settings_path,
          method: :post,
          data: { confirm: "Reset all preferences to defaults?" },
          class: "px-4 py-2 text-sm border border-gray-300 rounded-md
                 hover:bg-gray-50 transition-colors" %>

      <div class="flex-1"></div>

      <p class="text-xs text-gray-500 self-center">
        💡 Tip: Categories are saved automatically on toggle
      </p>
    </div>
  </section>
</div>
```

---

## Testing Strategy

### Unit Tests

**File**: `test/models/knowledge_base_category_test.rb`

```ruby
require "test_helper"

class KnowledgeBaseCategoryTest < ActiveSupport::TestCase
  test "should validate presence of name and slug" do
    category = KnowledgeBaseCategory.new
    assert_not category.valid?
    assert_includes category.errors[:name], "can't be blank"
    assert_includes category.errors[:slug], "can't be blank"
  end

  test "should validate uniqueness of slug" do
    KnowledgeBaseCategory.create!(name: "Test", slug: "test")
    duplicate = KnowledgeBaseCategory.new(name: "Test 2", slug: "test")
    assert_not duplicate.valid?
  end

  test "should return documents count" do
    category = knowledge_base_categories(:core_heuristics)
    assert_equal 3, category.document_count
  end
end
```

**File**: `test/models/user_test.rb`

```ruby
require "test_helper"

class UserTest < ActiveSupport::TestCase
  test "should initialize default preferences on creation" do
    user = User.create!(email: "test@example.com", password: "password123")
    assert user.enabled_knowledge_categories.any?
    assert user.category_enabled?("core_heuristics")
  end

  test "should toggle category preference" do
    user = users(:john)
    user.toggle_knowledge_category("accessibility", true)
    assert user.category_enabled?("accessibility")

    user.toggle_knowledge_category("accessibility", false)
    assert_not user.category_enabled?("accessibility")
  end

  test "knowledge_base_enabled? returns true when categories enabled" do
    user = users(:john)
    assert user.knowledge_base_enabled?
  end
end
```

### Integration Tests

**File**: `test/controllers/settings_controller_test.rb`

```ruby
require "test_helper"

class SettingsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:john)
    sign_in @user
  end

  test "should display knowledge categories" do
    get settings_url
    assert_response :success
    assert_select "h2", text: /Audit Knowledge Base/
    assert_select "[data-controller='knowledge-preference']"
  end

  test "should update preference via AJAX" do
    category = knowledge_base_categories(:accessibility)

    patch update_knowledge_preference_settings_url,
          params: { category_slug: "accessibility", enabled: true },
          as: :json

    assert_response :success
    json = JSON.parse(response.body)
    assert json["success"]

    assert @user.category_enabled?("accessibility")
  end

  test "should reset preferences to defaults" do
    @user.user_knowledge_preferences.destroy_all

    post reset_knowledge_preferences_settings_url
    assert_redirected_to settings_path

    @user.reload
    assert @user.category_enabled?("core_heuristics")
  end
end
```

### Service Tests

**File**: `test/services/ux_knowledge_retrieval_service_test.rb`

```ruby
require "test_helper"

class UxKnowledgeRetrievalServiceTest < ActiveSupport::TestCase
  setup do
    @service = UxKnowledgeRetrievalService.new
    @user = users(:john)
  end

  test "should retrieve documents from enabled categories only" do
    @user.toggle_knowledge_category("accessibility", true)
    @user.toggle_knowledge_category("ai_interfaces", false)

    context = "accessibility audit of form inputs"
    result = @service.retrieve_for_user_audit(context, @user)

    assert result.present?
    assert_includes result, "Accessibility Standards"
    assert_not_includes result, "AI/LLM Interface"
  end

  test "should return empty string when no categories enabled" do
    @user.user_knowledge_preferences.destroy_all

    result = @service.retrieve_for_user_audit("test", @user)
    assert_equal "", result
  end

  test "should limit context length to 5000 characters" do
    @user.toggle_knowledge_category("core_heuristics", true)

    result = @service.retrieve_for_user_audit("usability audit", @user)
    assert result.length <= 5000
  end
end
```

### End-to-End Tests

**File**: `test/system/audit_with_knowledge_base_test.rb`

```ruby
require "application_system_test_case"

class AuditWithKnowledgeBaseTest < ApplicationSystemTestCase
  setup do
    @user = users(:john)
    sign_in @user
  end

  test "audit uses selected knowledge categories" do
    # Enable accessibility category
    visit settings_path
    check "Accessibility & Inclusive Design"
    assert_text "✓ Saved"

    # Upload video for audit
    visit video_audits_path
    attach_file "video", file_fixture("sample_form.mp4")
    click_button "Upload"

    # Wait for processing
    assert_text "Analysis Complete", wait: 120

    # Verify audit includes accessibility findings
    within ".audit-results" do
      assert_text "WCAG", count: 1..Float::INFINITY
      assert_text "color contrast", count: 1..Float::INFINITY
    end
  end

  test "audit excludes disabled categories" do
    # Disable all categories except core
    visit settings_path
    uncheck "Accessibility & Inclusive Design"
    uncheck "AI/LLM Interface Design"

    # Run audit
    visit video_audits_path
    attach_file "video", file_fixture("sample_chatbot.mp4")
    click_button "Upload"

    assert_text "Analysis Complete", wait: 120

    # Verify no AI-specific findings
    within ".audit-results" do
      assert_no_text "conversational UI"
      assert_no_text "chatbot pattern"
    end
  end
end
```

### Performance Benchmarks

**Target Metrics**:
- Knowledge retrieval query: **< 500ms**
- Settings page load: **< 1.5s**
- Toggle save (AJAX): **< 300ms**
- Audit time increase: **< 15%** (compared to no knowledge context)
- Token usage increase: **< 20%** (compared to baseline prompts)

**Benchmark Script**: `test/benchmarks/knowledge_retrieval_benchmark.rb`

```ruby
require "benchmark"

user = User.first
service = UxKnowledgeRetrievalService.new

Benchmark.bm(30) do |x|
  x.report("Retrieval (1 category):") do
    100.times { service.retrieve_for_user_audit("test", user) }
  end

  x.report("Retrieval (all categories):") do
    user.enabled_knowledge_categories << KnowledgeBaseCategory.all
    100.times { service.retrieve_for_user_audit("test", user) }
  end
end
```

---

## Deployment Plan

### Pre-Deployment Checklist

- [ ] All Phase 1-4 tasks completed
- [ ] All tests passing (unit, integration, system)
- [ ] Performance benchmarks meet targets
- [ ] Database migrations tested on staging
- [ ] Rollback procedure documented and tested
- [ ] Feature flag configured (if using gradual rollout)
- [ ] Monitoring dashboards created
- [ ] Alert thresholds configured
- [ ] Documentation published (internal + user-facing)
- [ ] Customer support team trained
- [ ] Product team sign-off obtained

### Migration Strategy

#### Staging Deployment

1. **Deploy to staging** (Week 5, Monday)
   ```bash
   git checkout main
   git pull origin main
   kamal deploy --staging
   ```

2. **Run migrations**
   ```bash
   kamal app exec -i --staging "bin/rails db:migrate"
   ```

3. **Seed categories**
   ```bash
   kamal app exec -i --staging "bin/rails db:seed:knowledge_categories"
   ```

4. **Categorize existing documents**
   ```bash
   kamal app exec -i --staging "bin/rails knowledge:categorize_documents"
   ```

5. **Initialize user preferences**
   ```bash
   kamal app exec -i --staging "bin/rails knowledge:initialize_user_preferences"
   ```

6. **QA Testing** (2 days)
   - Manual exploratory testing
   - Automated test suite
   - Performance testing
   - User acceptance testing with beta users

#### Production Deployment

1. **Pre-deployment communication**
   - Notify team in Slack #engineering
   - Brief customer support team
   - Prepare rollback plan

2. **Deploy to production** (Week 5, Thursday 10:00 AM)
   ```bash
   git checkout main
   git pull origin main
   kamal deploy
   ```

3. **Run migrations** (expected: 2-3 minutes downtime)
   ```bash
   kamal app exec -i "bin/rails db:migrate"
   ```

4. **Seed and initialize**
   ```bash
   kamal app exec -i "bin/rails db:seed:knowledge_categories"
   kamal app exec -i "bin/rails knowledge:categorize_documents"
   kamal app exec -i "bin/rails knowledge:initialize_user_preferences"
   ```

5. **Smoke tests**
   - Visit `/settings` page
   - Toggle a category
   - Upload test video
   - Verify audit completes successfully
   - Check monitoring dashboards

6. **Enable feature flag** (if gradual rollout)
   ```ruby
   # In Rails console
   FeatureFlag.enable(:knowledge_base_toggles, percentage: 10)
   # Increase to 50%, then 100% over 3 days
   ```

7. **Monitor for 48 hours**
   - Error rates
   - Audit completion rates
   - Feature adoption metrics
   - User feedback in support tickets

### Rollback Plan

**If issues detected**, execute rollback within 15 minutes:

```bash
# Revert to previous version
kamal app rollback

# If database rollback needed (destructive, last resort):
kamal app exec -i "bin/rails db:rollback STEP=3"
```

**Rollback triggers**:
- Error rate increase > 5%
- Audit failure rate increase > 10%
- Critical bug preventing audits
- Performance degradation > 30%
- Security vulnerability discovered

### Post-Deployment Monitoring

**Metrics to track** (Datadog/New Relic dashboards):

1. **Feature Adoption**
   - % users who customized preferences
   - Most enabled/disabled categories
   - Average categories enabled per user

2. **Performance**
   - Knowledge retrieval query time (p50, p95, p99)
   - Audit completion time before/after
   - Token usage per audit
   - Database query counts

3. **Quality**
   - Audit failure rate
   - LLM API error rate
   - User-reported issues via support tickets

4. **Business Metrics**
   - User satisfaction (NPS surveys)
   - Audit quality ratings
   - Feature usage retention

**Alert thresholds**:
- Knowledge retrieval query p95 > 1s
- Audit failure rate > 5%
- LLM API error rate > 2%
- Token usage increase > 30%

---

## Future Enhancements

### Phase 6: Per-Audit Overrides (Quarter 2, 2026)

**Description**: Allow users to temporarily override their default preferences for a specific audit.

**Implementation**:
- Add modal/dropdown on video upload page: "Customize knowledge for this audit"
- Store overrides in `video_audits.knowledge_preferences` JSONB column
- Update retrieval service to check audit-specific overrides first
- UI shows both default + override preferences

**User Story**:
> "As a user, I want to enable Accessibility category for a single audit without changing my defaults, so I can do one-off accessibility reviews."

**Estimated Effort**: 2 weeks

---

### Phase 7: Smart Category Suggestions (Quarter 2, 2026)

**Description**: Auto-suggest which categories to enable based on video title, description, or initial frame analysis.

**Implementation**:
- NLP analysis of audit title/description for keywords
- Initial frame scan for UI patterns (forms → accessibility, chat bubbles → AI)
- Show suggestion banner: "💡 We recommend enabling Accessibility category for this audit"
- Track suggestion acceptance rate for ML improvement

**Examples**:
- Title contains "mobile app" → Suggest "Mobile & Platform-Specific"
- Description contains "WCAG" → Suggest "Accessibility"
- Frames show chat interface → Suggest "AI/LLM Interface Design"

**Estimated Effort**: 3 weeks

---

### Phase 8: Custom Categories (Quarter 3, 2026)

**Description**: Allow users to create custom document collections.

**Implementation**:
- New UI: "Create Custom Category"
- User uploads PDFs or selects from existing documents
- Custom category shows in preferences alongside system categories
- Share custom categories with team (Enterprise feature)

**User Story**:
> "As a design lead, I want to create a 'Brand Guidelines' category with our company's design docs, so audits check for brand consistency."

**Database Changes**:
- Add `user_id` to `knowledge_base_categories` (NULL = system category)
- Add `visibility` enum: 'public', 'private', 'team'

**Estimated Effort**: 4 weeks

---

### Phase 9: Category Analytics Dashboard (Quarter 3, 2026)

**Description**: Show users which categories led to most valuable findings.

**Metrics**:
- Issues found per category
- Severity distribution by category
- Most common heuristics violated per category
- Category effectiveness score

**UI**: New tab in Settings → "Analytics"

**Example Insight**:
> "Accessibility category found 12 high-severity issues in your last 5 audits. Consider keeping it enabled."

**Estimated Effort**: 3 weeks

---

### Phase 10: Document Versioning (Quarter 4, 2026)

**Description**: Track which version of documents were used for each audit.

**Implementation**:
- Add `version` column to `ux_knowledge_documents`
- Store `knowledge_base_snapshot` JSONB on each `video_audit`
- Allow users to "lock" to specific document versions
- Show "Documents updated" notification when new versions added

**User Story**:
> "As a compliance officer, I need to prove which WCAG standards were used for our Q3 audit report."

**Estimated Effort**: 2 weeks

---

### Phase 11: Mobile-Specific Knowledge Base (Quarter 4, 2026)

**Description**: Add comprehensive mobile design guidelines.

**Documents to Add**:
- Apple Human Interface Guidelines (iOS 17+)
- Material Design 3 Guidelines
- Mobile usability heuristics
- Touch target sizing standards
- Native gesture patterns
- Platform-specific components

**Estimated Effort**: 1 week (document sourcing + indexing)

---

### Phase 12: Collaborative Category Management (2027)

**Description**: Teams can share and manage categories together.

**Features**:
- Team admin creates "Team Categories" visible to all members
- Suggested defaults for new team members
- Category usage statistics across team
- Centralized document management

**Use Case**: Enterprise customers with multiple auditors

**Estimated Effort**: 6 weeks

---

### Phase 13: AI-Powered Document Recommendations (2027)

**Description**: LLM analyzes audit results and recommends additional categories.

**Implementation**:
- After audit completes, analyze findings for knowledge gaps
- If accessibility issues found but category was disabled → Suggest enabling
- Learn from user feedback (accepts/dismisses suggestions)

**Example**:
> "⚠️ We found 5 color contrast issues. Enable 'Accessibility' category for more comprehensive checks?"

**Estimated Effort**: 4 weeks

---

## Success Metrics

### Primary Metrics (Track weekly)

| Metric | Target | Measurement |
|--------|--------|-------------|
| Feature Adoption Rate | 60% of active users | % users who customized preferences in last 30 days |
| Audit Quality Score | +15% improvement | User-rated audit quality (1-5 stars) |
| Issue Relevance | +20% improvement | % of identified issues marked "useful" by users |
| Category Usage | 2.5 avg per user | Average # of enabled categories |

### Secondary Metrics (Track monthly)

| Metric | Target | Measurement |
|--------|--------|-------------|
| Settings Page Engagement | 80% visit rate | % of users who visit settings page |
| Preference Changes | 1.5 changes/user/month | Frequency of toggle changes |
| Accessibility Audits | 3x increase | # of audits with accessibility enabled |
| AI Interface Audits | 2x increase | # of audits with AI category enabled |
| Token Usage | < 20% increase | Average tokens/audit vs baseline |
| Audit Completion Time | < 15% increase | p50 time to complete audit |

### Business Impact (Track quarterly)

| Metric | Target | Measurement |
|--------|--------|-------------|
| User Retention | +10% improvement | 30-day retention rate |
| Paid Conversions | +5% improvement | Free → Paid upgrade rate |
| Customer Satisfaction | NPS > 50 | Net Promoter Score |
| Support Tickets | -10% reduction | Audit-related support volume |

### Data Collection

**Instrumentation**:
```ruby
# Track category toggles
Analytics.track(
  user_id: current_user.id,
  event: "knowledge_category_toggled",
  properties: {
    category: category.slug,
    enabled: enabled,
    total_enabled: current_user.enabled_knowledge_categories.count
  }
)

# Track audit with categories
Analytics.track(
  user_id: current_user.id,
  event: "audit_started",
  properties: {
    enabled_categories: current_user.enabled_knowledge_categories.pluck(:slug),
    category_count: current_user.enabled_knowledge_categories.count,
    knowledge_base_used: current_user.knowledge_base_enabled?
  }
)
```

---

## Risk Assessment

### Technical Risks

| Risk | Impact | Probability | Mitigation |
|------|--------|-------------|------------|
| RAG retrieval slow (> 1s) | High | Medium | Add query optimization, caching layer, monitor query plans |
| Token limit exceeded | High | Low | Implement strict truncation, monitor token usage per batch |
| Category misconfiguration | Medium | Low | Validate in seeds, add database constraints, default to safe state |
| Migration data loss | Critical | Very Low | Backup database before migration, test rollback extensively |
| LLM quality degradation | High | Medium | A/B test with/without KB, monitor audit ratings, user feedback |

### Product Risks

| Risk | Impact | Probability | Mitigation |
|------|--------|-------------|------------|
| Users don't understand categories | Medium | Medium | Clear descriptions, tooltips, onboarding flow, help documentation |
| Feature adoption low (< 30%) | Medium | Medium | In-app prompts, email campaign, showcase benefits with examples |
| Analysis quality worse with KB | High | Low | Extensive testing, gradual rollout, easy disable mechanism |
| Users enable too many categories | Low | Medium | Recommend 2-3 categories, show performance impact warning |
| Support burden increases | Medium | Low | Comprehensive docs, FAQ section, clear error messages |

### Business Risks

| Risk | Impact | Probability | Mitigation |
|------|--------|-------------|------------|
| Development timeline extends | Medium | Medium | Phased approach allows partial releases, prioritize MVP features |
| Competitor launches similar feature | Low | Medium | Our RAG implementation is defensible, focus on quality execution |
| User confusion with settings | Medium | Medium | User testing before launch, iterate on UI based on feedback |
| Increased infrastructure costs | Low | High | Monitor OpenAI API usage, optimize retrieval queries, consider caching |

---

## Team Responsibilities

### Engineering Team

**Backend Lead**:
- Database schema design and migrations
- Service layer integration (RAG + LLM pipeline)
- Performance optimization
- Testing strategy

**Frontend Lead**:
- Settings UI implementation
- Stimulus controller for toggles
- Responsive design
- Accessibility compliance

**Full-Stack Engineers**:
- Model implementations
- Controller actions
- Integration testing
- Documentation

### Product Team

**Product Manager**:
- Requirements validation
- User acceptance criteria
- Release communications
- Success metrics tracking

**UX Designer**:
- Settings page design
- Toggle interaction patterns
- Help text and descriptions
- User testing facilitation

### Operations Team

**DevOps Engineer**:
- Deployment automation
- Monitoring setup
- Alert configuration
- Performance benchmarking

**Support Lead**:
- Documentation review
- Team training
- Launch day coverage
- Feedback collection

---

## Timeline Summary

| Week | Phase | Key Deliverables | Owner |
|------|-------|------------------|-------|
| 1 | Database & Models | Migrations, models, seeds | Backend Lead |
| 2 | Settings UI | Toggle interface, Stimulus controller | Frontend Lead |
| 3 | RAG Integration | Service updates, prompt injection | Backend Lead |
| 4 | Testing & QA | Test suite, performance benchmarks | Full Team |
| 5 | Deployment | Staging → Production launch | DevOps + Team |
| 6+ | Monitoring | Adoption tracking, iteration | Product + Eng |

**Total Duration**: 5 weeks for MVP (Phases 1-5)
**Future Enhancements**: Ongoing (Quarters 2-4, 2026 and beyond)

---

## Conclusion

This implementation plan provides a comprehensive roadmap for adding user-configurable knowledge base categories to our UX audit platform. The phased approach allows for:

1. **Rapid MVP delivery** (5 weeks)
2. **Low-risk deployment** (gradual rollout, feature flags)
3. **Measurable success** (clear metrics and monitoring)
4. **Future extensibility** (12+ enhancement opportunities)

The feature will enable specialized audit types (accessibility, mobile, AI interfaces), improve audit relevance, and differentiate our product in the market. With proper execution, we expect 60% feature adoption and 15% improvement in audit quality scores within 90 days of launch.

**Next Steps**:
1. Product team approval of plan
2. UX review of mockups
3. Engineering team kickoff (Week 1 starts)
4. Daily standups to track progress
5. Weekly stakeholder updates

---

**Document Version**: 1.0
**Last Updated**: October 23, 2025
**Next Review**: November 1, 2025 (post-launch retrospective)

For questions or feedback, contact the engineering team lead or product manager.
