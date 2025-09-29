# P0 TODO: Yampram Enhancement Implementation

## Overview

Transform Yampram into a production-ready UX analysis platform with executive summary, filtering, anchored navigation, enhanced issue cards, Jira integration, and export capabilities.

**Current System:** Rails 7.1.5 + PostgreSQL + Bootstrap 5.3.3 + Sidekiq + OpenAI integration

---

## 🚀 PHASE 1: Executive Summary Bar & Issue IDs

### Database & Backend Setup

- [ ] **Create migration for enhanced data tracking**
  ```bash
  rails generate migration AddIssueIdsAndJiraIntegration issue_id_counter:integer jira_epic_key:string share_token:string shared_at:datetime
  ```

- [ ] **Add VideoAudit model enhancements**
  - [ ] Add `issue_id_counter` default: 0
  - [ ] Add indexes for `share_token` (unique) and `jira_epic_key`
  - [ ] Add method `generate_issue_ids` to assign UXW-001, UXW-002, etc.

- [ ] **Update VideoAuditsController#show**
  - [ ] Add `@summary_stats = calculate_summary_stats(@audit)`
  - [ ] Create `calculate_summary_stats` private method with:
    - [ ] `total_issues` count
    - [ ] `high_count`, `medium_count`, `low_count`
    - [ ] `affected_steps` (unique issue titles)
    - [ ] `estimated_effort` (T-shirt sizing: XS/S/M/L/XL)
    - [ ] `top_issues` (first 5 by severity)

- [ ] **Create VideoAuditsHelper methods**
  ```ruby
  # In app/helpers/video_audits_helper.rb
  def severity_icon(severity)       # 🔴🟡🔵 for High/Med/Low
  def extract_component(issue)      # Navigation, Form, Button, etc.
  def estimate_frequency(issue)     # Often/Sometimes/Rarely
  def estimate_confidence(issue)    # High/Medium/Low
  def calculate_tshirt_sizing(issues) # XS/S/M/L/XL based on count & severity
  ```

### Frontend Implementation

- [ ] **Replace existing header in show.html.erb (lines 102-136)**
  - [ ] Keep existing navigation (back link, workflow title)
  - [ ] Add sticky executive summary bar below with:
    - [ ] Total Issues metric
    - [ ] High/Med/Low severity breakdown with colored badges
    - [ ] Affected Steps count
    - [ ] Est. Effort (T-shirt size with styling)
    - [ ] Top 5 Issues preview (hover tooltip)

- [ ] **Add action buttons to summary bar**
  - [ ] "Export PDF" button (data-action="pdf")
  - [ ] "Export CSV" button (data-action="csv")
  - [ ] "Export JSON" button (data-action="json")
  - [ ] "Create Jira Epic (Top 5)" button

- [ ] **Update issue cards (lines 178-208) with enhanced headers**
  - [ ] Add issue ID: `[UXW-001]` format
  - [ ] Add component extraction: `Navigation — Issue Title`
  - [ ] Add anchor link icon for deep linking (#uxw-001)
  - [ ] Add `id="uxw-001"` to each card div

- [ ] **Add CSS for executive summary bar**
  - [ ] Sticky positioning (`position: sticky; top: 0`)
  - [ ] Metric groups with proper spacing
  - [ ] Severity badges with colors (red/yellow/blue)
  - [ ] T-shirt size styling (XS=green, S=yellow, M=orange, L=red, XL=purple)
  - [ ] Responsive design for mobile

**Acceptance Criteria:**
- [ ] Executive summary shows accurate counts and updates in real-time
- [ ] Issue cards have stable UXW-XXX IDs visible in UI
- [ ] Summary bar remains sticky when scrolling
- [ ] T-shirt sizing accurately reflects issue complexity

---

## 🔍 PHASE 2: Filters & View Controls

### Filter Toolbar Implementation

- [ ] **Add filter toolbar HTML after header in show.html.erb**
  - [ ] Severity filter chips: All, High, Medium, Low
  - [ ] Heuristic filter chips (dynamic from issue data)
  - [ ] Component dropdown (Navigation, Form, Button, etc.)
  - [ ] Step/Phase filter (from timeline data)

- [ ] **Add view controls section**
  - [ ] Sort dropdown: Time, Severity, Impact
  - [ ] Search box with placeholder "Search issues..."
  - [ ] Results counter "Showing X of Y issues"

- [ ] **Create filtering.js for client-side filtering**
  ```javascript
  class IssueFilter {
    constructor() {
      this.filters = { severity: 'all', heuristic: 'all', component: 'all', search: '' };
      this.sortBy = 'time';
    }

    applyFilters()     // Show/hide cards based on current filters
    updateResultsCount() // Update "Showing X of Y" text
    updateSummaryStats() // Recalculate summary bar for visible issues
    initializeEventListeners() // Bind click/change events
  }
  ```

- [ ] **Add filter CSS with sticky positioning**
  - [ ] Toolbar sticks below executive summary
  - [ ] Filter chips with active/inactive states
  - [ ] Smooth transitions for filter interactions
  - [ ] Mobile-responsive chip layout

### Dynamic Filter Population

- [ ] **JavaScript to populate filter options from data**
  - [ ] Extract unique heuristics from all issues
  - [ ] Extract unique components from issue titles
  - [ ] Create filter chips dynamically on page load

- [ ] **Implement real-time search**
  - [ ] Search in issue titles and descriptions
  - [ ] Highlight matching text (optional)
  - [ ] Debounced input for performance

**Acceptance Criteria:**
- [ ] Filtering by High severity shows only high issues and updates counts
- [ ] Search works across titles and descriptions
- [ ] Filter combinations work correctly (AND logic)
- [ ] Filter state persists during session

---

## 🔗 PHASE 3: Anchored Timeline Sync

### Timeline Enhancement

- [ ] **Update timeline HTML (lines 142-154)**
  - [ ] Add `data-anchor="uxw-001"` to each timeline step
  - [ ] Add small anchor link icon (🔗) to each step
  - [ ] Ensure step titles are clickable for navigation

- [ ] **Update timeline JavaScript (lines 659-701)**
  - [ ] Modify `highlightCard()` function to:
    - [ ] Scroll to card using `scrollIntoView({ behavior: 'smooth', block: 'center' })`
    - [ ] Add URL hash (window.history.pushState)
    - [ ] Highlight both timeline step AND corresponding card
    - [ ] Update browser URL to include anchor (#uxw-001)

### Deep Linking System

- [ ] **Add URL hash handling**
  - [ ] Listen for `hashchange` events
  - [ ] On page load, check for hash and auto-scroll to card
  - [ ] Highlight card when accessed via direct link

- [ ] **Add copy link functionality**
  - [ ] Anchor link buttons copy full URL with hash
  - [ ] Toast notification "Link copied to clipboard"
  - [ ] Share-friendly URLs that work when sent to others

### Bidirectional Sync

- [ ] **Card-to-timeline highlighting**
  - [ ] When card is in viewport, highlight corresponding timeline step
  - [ ] Use Intersection Observer API for performance
  - [ ] Smooth visual feedback for active section

**Acceptance Criteria:**
- [ ] Clicking timeline step scrolls to card and highlights it
- [ ] Each card has stable anchor link that can be shared
- [ ] URL updates when navigating to different issues
- [ ] Deep links work when page is refreshed or shared

---

## 📋 PHASE 4: Enhanced Issue Cards

### Card Layout & Badge System

- [ ] **Redesign issue card header structure**
  - [ ] Issue ID + Component + Title format: `[UXW-012] Navigation — Menu not accessible`
  - [ ] Add badges row below header with:
    - [ ] Severity badge with icon and color
    - [ ] Frequency badge (Often/Sometimes/Rarely)
    - [ ] Confidence badge (High/Medium/Low)
    - [ ] Heuristic tag (linked to knowledge base)

- [ ] **Add timestamp section with video linking**
  - [ ] Format: "Time: 00:02–00:19 → click to Open clip"
  - [ ] Make timestamp clickable (future: open video at specific time)
  - [ ] Use monospace font for time display

- [ ] **Evidence section enhancement**
  - [ ] 1-2 thumbnails (frame grabs from video)
  - [ ] Optional transcript quote if available
  - [ ] Placeholder for missing evidence

### Recommendation & Action Enhancements

- [ ] **Improve recommendations display**
  - [ ] Format as 2-4 bullet points
  - [ ] Use imperative language ("Fix X", "Add Y", "Remove Z")
  - [ ] Prioritize actionable items

- [ ] **Enhanced action buttons**
  - [ ] "Create Jira" button (pre-mapped data)
  - [ ] "Copy" button (markdown-friendly format)
  - [ ] "Mark as Resolved" button
  - [ ] "View Evidence" button (expand thumbnails)

### Card Data Structure

- [ ] **Ensure issue data completeness**
  - [ ] Validate all issues have required fields
  - [ ] Add fallbacks for missing data
  - [ ] Consistent data formatting across cards

**Acceptance Criteria:**
- [ ] Cards display all badge information clearly
- [ ] Copy function produces clean, markdown-friendly output
- [ ] Timestamp links are properly formatted and clickable
- [ ] Evidence thumbnails display when available

---

## ⚡ PHASE 5: Jira Integration v1

### Backend Integration

- [ ] **Add environment variables**
  ```bash
  # Add to .env
  JIRA_BASE_URL=https://yourcompany.atlassian.net
  JIRA_AUTH_TOKEN=your_jira_api_token
  JIRA_PROJECT_KEY=TALK
  ```

- [ ] **Create JiraController**
  ```ruby
  # app/controllers/jira_controller.rb
  def create_ticket    # Single issue → Jira ticket
  def create_epic      # Top 5 issues → Jira epic
  ```

- [ ] **Create JiraIntegrationService**
  ```ruby
  # app/services/jira_integration_service.rb
  def create_ticket_for_issue(audit, issue, issue_index)
  def create_epic_for_top_issues(audit)
  def attach_evidence_to_ticket(jira_key, audit, issue)
  ```

### Jira Ticket Structure

- [ ] **Implement ticket creation with proper formatting**
  - [ ] Summary: `[UXW-012] Component — Issue`
  - [ ] Description: Card content + deep link + clip URL + attachments
  - [ ] Labels: `product:talk-coach`, `ux-audit`, `heuristic:visibility-status`, `severity:high`
  - [ ] Evidence attachments: thumbnails and timestamp links

- [ ] **Add success feedback**
  - [ ] Show Jira key on card after successful creation
  - [ ] Link to created ticket
  - [ ] Handle and display errors gracefully

### Frontend Integration

- [ ] **Update Jira buttons to be functional**
  - [ ] Single issue "Create Jira" buttons
  - [ ] Bulk "Create Jira Epic (Top 5)" button
  - [ ] Loading states during API calls
  - [ ] Success/error feedback

- [ ] **Add routes for Jira endpoints**
  ```ruby
  # config/routes.rb
  post '/audits/:audit_id/jira/ticket/:issue_index', to: 'jira#create_ticket'
  post '/audits/:audit_id/jira/epic', to: 'jira#create_epic'
  ```

**Acceptance Criteria:**
- [ ] Creating Jira ticket attaches evidence thumbnails and timestamp link
- [ ] Jira key appears on card after successful creation
- [ ] Epic creation includes top 5 issues with proper linking
- [ ] Error handling works for invalid credentials/network issues

---

## 📤 PHASE 6: Export & Share

### PDF Export Implementation

- [ ] **Add Prawn gem for PDF generation**
  ```ruby
  # Gemfile
  gem 'prawn'
  gem 'prawn-table'
  ```

- [ ] **Create ExportsController**
  ```ruby
  # app/controllers/exports_controller.rb
  def pdf     # Executive summary → timeline → findings
  def csv     # One row per issue
  def json    # Full data export for API usage
  ```

- [ ] **Create PdfExportService**
  ```ruby
  # app/services/pdf_export_service.rb
  def generate
    # Executive summary page
    # Timeline overview
    # Detailed findings with evidence
  ```

### CSV & JSON Export

- [ ] **Implement CsvExportService**
  - [ ] Headers: Issue ID, Component, Title, Severity, Description, Recommendations, Timestamp
  - [ ] One row per issue
  - [ ] Proper CSV escaping

- [ ] **Implement JSON export**
  - [ ] Full audit data structure
  - [ ] Include metadata (export timestamp, deep links)
  - [ ] API-friendly format for integrations

### Share Link Generation

- [ ] **Add share functionality**
  - [ ] Generate unique share tokens
  - [ ] View-only access with optional passcode
  - [ ] Expiration dates for shared links
  - [ ] Track share activity

- [ ] **Frontend export buttons**
  - [ ] Wire up export buttons in executive summary
  - [ ] Download file with proper naming convention
  - [ ] Progress indicators for large exports

**Acceptance Criteria:**
- [ ] PDF export includes executive summary, timeline, and findings
- [ ] CSV export has one clean row per issue
- [ ] JSON export is API-ready with all data
- [ ] Share links work for external stakeholders

---

## 🧪 PHASE 7: Testing & Polish

### Functionality Testing

- [ ] **Test all filter combinations**
  - [ ] Severity + Heuristic + Search
  - [ ] Sort order preservation during filtering
  - [ ] URL state management

- [ ] **Test timeline sync**
  - [ ] All timeline clicks work correctly
  - [ ] Deep links load proper cards
  - [ ] Browser back/forward buttons work

- [ ] **Test Jira integration**
  - [ ] Single ticket creation
  - [ ] Epic creation with multiple issues
  - [ ] Error scenarios (network, auth)

### Performance & Mobile

- [ ] **Mobile responsiveness**
  - [ ] Executive summary bar responsive design
  - [ ] Filter toolbar mobile layout
  - [ ] Cards stack properly on small screens
  - [ ] Timeline becomes horizontal chip layout

- [ ] **Performance optimization**
  - [ ] JavaScript filtering performance with large datasets
  - [ ] CSS optimization and minification
  - [ ] Image optimization for evidence thumbnails

### Browser Compatibility

- [ ] **Cross-browser testing**
  - [ ] Chrome, Firefox, Safari, Edge
  - [ ] Sticky positioning fallbacks
  - [ ] JavaScript ES6+ feature support

**Acceptance Criteria:**
- [ ] All features work on mobile devices
- [ ] Page loads in under 3 seconds
- [ ] Filtering responds in under 500ms
- [ ] Export generation completes in under 10 seconds

---

## 📝 Implementation Notes

### Development Environment Setup
```bash
# Install new gems
bundle install

# Run migrations
rails db:migrate

# Add environment variables to .env
echo "JIRA_BASE_URL=https://yourcompany.atlassian.net" >> .env
echo "JIRA_AUTH_TOKEN=your_token_here" >> .env
echo "JIRA_PROJECT_KEY=TALK" >> .env
```

### Key Files to Modify
- `app/views/video_audits/show.html.erb` - Main UI changes
- `app/controllers/video_audits_controller.rb` - Backend logic
- `app/helpers/video_audits_helper.rb` - Helper methods
- `config/routes.rb` - New routes for Jira and exports

### Testing Checklist
- [ ] All P0 acceptance criteria pass
- [ ] Mobile experience is smooth
- [ ] Export files are properly formatted
- [ ] Jira integration works end-to-end
- [ ] Performance meets targets (3s load, 500ms filter)

---

**Last Updated:** 2025-09-29
**Status:** Ready for Development
**Estimated Effort:** 4 weeks (7 phases)

*Teams can pick up any phase independently - each phase has clear inputs/outputs and can be worked on in parallel where dependencies allow.*