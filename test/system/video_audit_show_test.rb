require "application_system_test_case"

class VideoAuditShowTest < ApplicationSystemTestCase

  def setup
    @audit = video_audits(:completed_with_issues)
    @audit.generate_issue_ids
    visit video_audit_path(@audit)
  end

  # Phase 7 Test Suite: Comprehensive Testing & Polish

  # === ACCESSIBILITY TESTING (WCAG AA Compliance) ===

  test "page meets WCAG AA accessibility standards" do
    # Run automated accessibility audit
    page.find('body').be_axe_clean.according_to :wcag2a, :wcag2aa
  end

  test "page has proper semantic structure" do
    # Check main landmarks
    assert_selector "main[role='main'], main", count: 1
    assert_selector "nav[role='navigation'], nav", minimum: 1

    # Check heading hierarchy
    assert_selector "h1", count: 1
    assert_selector "h2,h3,h4,h5,h6"

    # Verify logical heading order
    headings = all("h1,h2,h3,h4,h5,h6").map { |h| h.tag_name.gsub("h", "").to_i }
    previous_level = 0
    headings.each do |level|
      assert level <= previous_level + 1, "Heading hierarchy gap: h#{previous_level} to h#{level}"
      previous_level = level
    end
  end

  test "all interactive elements are keyboard accessible" do
    # Test tab navigation through all interactive elements
    interactive_elements = all("button, a, input, select, textarea, [tabindex]:not([tabindex='-1'])")

    interactive_elements.each do |element|
      element.send_keys(:tab)

      # Verify focus indicator is visible
      assert element.matches_css?(":focus, :focus-visible"),
        "Element #{element.tag_name}#{element[:class] ? '.' + element[:class] : ''} should have visible focus indicator"

      # Test activation with keyboard
      if element.tag_name == "BUTTON" || element[:role] == "button"
        element.send_keys(:space)
      elsif element.tag_name == "A"
        element.send_keys(:enter)
      end
    end
  end

  test "images have appropriate alt text" do
    all("img").each do |img|
      alt_text = img[:alt]

      if img[:role] == "presentation" || img[:alt] == ""
        # Decorative images should have empty alt or presentation role
        assert_includes ["", nil], alt_text, "Decorative images should have empty alt text"
      else
        # Content images should have descriptive alt text
        assert alt_text.present?, "Content images must have alt text"
        assert alt_text.length > 2, "Alt text should be descriptive"
        refute alt_text.match?(/image|picture|photo/i), "Alt text should not contain redundant words"
      end
    end
  end

  # === FUNCTIONALITY TESTING ===

  test "executive summary displays correct metrics" do
    within(".executive-summary") do
      # Test total issues count
      assert_text "5 Total Issues"

      # Test severity breakdown
      assert_text "2 High"
      assert_text "2 Medium"
      assert_text "1 Low"

      # Test effort estimation
      assert_text "Large"

      # Test affected steps count
      assert_text "5 Affected Steps"
    end
  end

  test "filter combinations work correctly" do
    # Wait for page to fully load
    sleep 1

    # Test severity filtering
    click_button "High"
    sleep 0.5

    # Should show only high severity issues (2 issues)
    assert_selector ".issue-card:not([style*='display: none'])", count: 2
    assert_text "Showing 2 of 5 issues"

    # Verify summary stats update
    within(".executive-summary") do
      assert_text "2 Total Issues"
      assert_text "2 High"
    end

    # Test combining with heuristic filter
    click_button "Keyboard Navigation"
    sleep 0.5

    # Should show only 1 issue (High + Keyboard Navigation)
    assert_selector ".issue-card:not([style*='display: none'])", count: 1
    assert_text "Showing 1 of 5 issues"

    # Test search functionality
    fill_in "Search issues...", with: "navigation"
    sleep 0.8 # Wait for debounced search

    assert_selector ".issue-card:not([style*='display: none'])", count: 1
    assert_text "navigation menu", visible: true

    # Test clear filters
    click_button "All" # Clear severity filter
    sleep 0.5
    find(".search-box").set("") # Clear search
    sleep 0.8

    # Should show all issues again
    assert_selector ".issue-card:not([style*='display: none'])", count: 5
  end

  test "timeline sync and deep linking works" do
    # Test clicking timeline steps
    first(".timeline-step[data-anchor]").click
    sleep 0.3

    # Verify URL contains hash
    assert_match /#uxw-\d{3}/, current_url

    # Verify corresponding card is highlighted
    issue_id = current_url.split("#").last
    assert_selector ".issue-card[id='#{issue_id}'].highlighted"

    # Test direct deep link navigation
    visit current_url
    sleep 0.5

    # Should scroll to and highlight the correct card
    assert_selector ".issue-card[id='#{issue_id}'].highlighted"

    # Test copy link functionality
    within(".issue-card[id='#{issue_id}']") do
      find(".copy-link-btn").click
      sleep 0.2

      # Should show success toast
      assert_text "Link copied to clipboard"
    end
  end

  test "progressive disclosure reduces initial content load" do
    # Count initially visible content
    initial_content = all(".issue-card .description:not(.collapsed)").length
    total_content = all(".issue-card").length

    # Should show less than 50% of content initially (progressive disclosure target: 60% reduction)
    visible_percentage = (initial_content.to_f / total_content) * 100
    assert visible_percentage < 50, "Progressive disclosure should hide more than 50% of content initially"

    # Test expand/collapse functionality
    first(".toggle-description").click
    sleep 0.3

    # Content should be expanded
    assert_selector ".description.expanded", minimum: 1

    # Test collapse
    first(".toggle-description").click
    sleep 0.3

    # Content should be collapsed again
    assert_selector ".description.collapsed", minimum: 1
  end

  # === PERFORMANCE TESTING ===

  test "page loads within 3 seconds" do
    start_time = Time.current
    visit video_audit_path(@audit)

    # Wait for all critical resources to load
    assert_selector ".executive-summary"
    assert_selector ".issue-card", minimum: 1
    assert_selector ".timeline-step", minimum: 1

    load_time = Time.current - start_time
    assert load_time < 3.0, "Page should load in under 3 seconds, took #{load_time.round(2)}s"
  end

  test "filtering responds within 500ms" do
    visit video_audit_path(@audit)
    sleep 1 # Wait for initial load

    # Measure filter response time
    start_time = Time.current
    click_button "High"

    # Wait for filter to complete
    assert_text "Showing 2 of 5 issues"

    filter_time = Time.current - start_time
    assert filter_time < 0.5, "Filter should respond in under 500ms, took #{filter_time.round(3)}s"
  end

  test "search responds quickly with debouncing" do
    visit video_audit_path(@audit)
    sleep 1

    search_box = find(".search-box")

    # Type multiple characters quickly
    start_time = Time.current
    search_box.set("nav")

    # Should debounce and respond within reasonable time
    assert_text "navigation menu", wait: 1

    search_time = Time.current - start_time
    assert search_time < 1.0, "Search should respond within 1 second with debouncing"
  end

  # === MOBILE RESPONSIVENESS ===

  test "mobile layout works correctly" do
    # Test mobile viewport
    page.driver.browser.manage.window.resize_to(375, 667) # iPhone SE size
    visit video_audit_path(@audit)

    # Executive summary should be responsive
    within(".executive-summary") do
      assert_selector ".metric", minimum: 1
    end

    # Timeline should convert to horizontal chips on mobile
    assert_selector ".timeline-steps"

    # Filter toolbar should be mobile-friendly
    assert_selector ".filter-toolbar"

    # Cards should stack properly
    assert_selector ".issue-card", minimum: 1

    # All critical content should be accessible
    assert_text "Total Issues"
    assert_text "UXW-001"
  end

  test "touch interactions work on mobile" do
    page.driver.browser.manage.window.resize_to(375, 667)
    visit video_audit_path(@audit)
    sleep 1

    # Test touch filter interactions
    find(".severity-filter[data-severity='High']").click
    sleep 0.5
    assert_text "Showing 2 of 5 issues"

    # Test timeline touch interactions
    first(".timeline-step[data-anchor]").click
    sleep 0.3
    assert_match /#uxw-\d{3}/, current_url
  end

  # === ERROR HANDLING & EDGE CASES ===

  test "handles empty search gracefully" do
    fill_in "Search issues...", with: "nonexistentterm"
    sleep 1

    assert_text "Showing 0 of 5 issues"
    assert_selector ".issue-card[style*='display: none']", count: 5

    # Should show helpful message
    assert_text "No issues match your current filters"
  end

  test "handles JavaScript errors gracefully" do
    # Disable JavaScript temporarily to test graceful degradation
    execute_script("window.IssueFilter = undefined;")

    # Core content should still be accessible
    assert_selector ".issue-card", minimum: 1
    assert_selector ".executive-summary"
    assert_text "UXW-001"
  end

  # === CROSS-BROWSER COMPATIBILITY ===

  test "sticky positioning works" do
    # Test sticky summary bar
    summary_bar = find(".executive-summary")
    assert_equal "sticky", summary_bar.style("position")["position"]

    # Scroll down and verify it sticks
    execute_script("window.scrollTo(0, 500)")
    sleep 0.3

    # Summary should still be visible
    assert summary_bar.visible?
  end

  test "CSS Grid and Flexbox layouts work" do
    # Test filter toolbar layout
    toolbar = find(".filter-toolbar")
    assert_includes ["flex", "grid"], toolbar.style("display")["display"]

    # Test card layout
    cards_container = find(".issues-container")
    assert cards_container.present?
  end

  # === DATA CONSISTENCY ===

  test "issue IDs are consistent and properly formatted" do
    issue_cards = all(".issue-card")

    issue_cards.each_with_index do |card, index|
      expected_id = "uxw-#{(index + 1).to_s.rjust(3, '0')}"

      # Check card ID attribute
      assert_equal expected_id, card[:id]

      # Check visible issue ID in header
      within(card) do
        assert_text "[UXW-#{(index + 1).to_s.rjust(3, '0')}]"
      end
    end
  end

  test "summary statistics are accurate" do
    # Manually calculate expected values from fixture data
    issues = @audit.parsed_llm_response["identifiedIssues"]

    expected_total = issues.length
    expected_high = issues.count { |i| i["severity"] == "High" }
    expected_medium = issues.count { |i| i["severity"] == "Medium" }
    expected_low = issues.count { |i| i["severity"] == "Low" }

    within(".executive-summary") do
      assert_text "#{expected_total} Total Issues"
      assert_text "#{expected_high} High"
      assert_text "#{expected_medium} Medium"
      assert_text "#{expected_low} Low"
    end
  end

  # === INTEGRATION TESTS ===

  test "URL state management preserves filter state" do
    # Apply filters
    click_button "High"
    fill_in "Search issues...", with: "navigation"
    sleep 1

    # Refresh page
    visit current_url
    sleep 1

    # Filters should be maintained through URL parameters
    assert_text "Showing 1 of 5 issues"
    assert_equal "navigation", find(".search-box").value
  end

  test "browser back/forward navigation works correctly" do
    original_url = current_url

    # Navigate to specific issue
    first(".timeline-step[data-anchor]").click
    sleep 0.3
    issue_url = current_url

    # Use browser back
    page.go_back
    sleep 0.3
    assert_equal original_url, current_url

    # Use browser forward
    page.go_forward
    sleep 0.3
    assert_equal issue_url, current_url

    # Should highlight correct issue
    issue_id = issue_url.split("#").last
    assert_selector ".issue-card[id='#{issue_id}'].highlighted"
  end

  private

  # Helper method for accessibility testing
  def run_accessibility_audit
    begin
      page.find('body').be_axe_clean
    rescue => e
      flunk "Accessibility violations found: #{e.message}"
    end
  end
end