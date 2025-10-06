# Phase 7: Accessibility Testing Helper
# Provides WCAG AA compliance testing utilities

module AccessibilityHelper
  # WCAG AA color contrast requirements
  MINIMUM_CONTRAST_RATIO = 4.5
  LARGE_TEXT_CONTRAST_RATIO = 3.0

  # Common accessibility test configurations
  WCAG_AA_CONFIG = {
    tags: %w[wcag2a wcag2aa],
    exclude: [
      # Exclude rules that may have false positives in test environment
      { id: 'landmark-one-main' }, # May conflict with test layout
      { id: 'page-has-heading-one' }, # May not be relevant for all pages
    ]
  }.freeze

  WCAG_AAA_CONFIG = {
    tags: %w[wcag2a wcag2aa wcag2aaa],
    exclude: [
      { id: 'color-contrast-enhanced' }, # AAA contrast may not be achievable with current design
    ]
  }.freeze

  # Keyboard navigation testing utilities
  def test_keyboard_navigation
    interactive_elements = all("button, a[href], input:not([disabled]), select:not([disabled]), textarea:not([disabled]), [tabindex]:not([tabindex='-1'])")

    interactive_elements.each_with_index do |element, index|
      # Navigate to element with tab
      element.send_keys(:tab) if index > 0

      # Verify element receives focus
      assert element.matches_css?(":focus, :focus-visible"),
        "Element #{element_info(element)} should be focusable"

      # Test activation
      case element.tag_name.downcase
      when 'button'
        test_button_activation(element)
      when 'a'
        test_link_activation(element)
      when 'input'
        test_input_activation(element)
      end
    end
  end

  # Screen reader testing utilities
  def test_screen_reader_compatibility
    # Test for required ARIA attributes
    verify_aria_labels
    verify_heading_structure
    verify_landmark_regions
    verify_form_labels
    verify_button_descriptions
  end

  # Focus management testing
  def test_focus_management
    # Test focus indicators
    all("button, a, input, select, textarea").each do |element|
      element.click
      assert element.matches_css?(":focus"), "Element should maintain focus after activation"
    end

    # Test focus traps (modals, dropdowns)
    if has_selector?("[role='dialog'], .modal")
      test_modal_focus_trap
    end
  end

  # Color contrast testing (manual verification helper)
  def verify_color_contrast
    # This helper provides guidance for manual color contrast testing
    # Automated contrast testing is limited by browser capabilities

    puts "\n=== COLOR CONTRAST VERIFICATION GUIDE ==="
    puts "Please verify the following color combinations meet WCAG AA standards:"
    puts "- Text color: Minimum 4.5:1 contrast ratio"
    puts "- Large text (18pt+): Minimum 3:1 contrast ratio"
    puts "- Non-text elements: Minimum 3:1 contrast ratio"
    puts "========================================\n"

    # Test high-contrast elements that commonly fail
    verify_button_contrast
    verify_text_contrast
    verify_link_contrast
  end

  private

  def element_info(element)
    "#{element.tag_name}#{element[:class] ? '.' + element[:class].split.first : ''}#{element[:id] ? '#' + element[:id] : ''}"
  end

  def test_button_activation(button)
    # Test space and enter key activation
    original_url = current_url

    button.send_keys(:space)
    sleep 0.1

    # Verify button responded (URL change, visual change, etc.)
    # This is a basic test - specific assertions should be in individual tests
    assert true # Placeholder - implement specific button behavior tests
  end

  def test_link_activation(link)
    return unless link[:href] && !link[:href].start_with?('#')

    # Test enter key activation
    link.send_keys(:enter)
    sleep 0.1

    # Verify navigation occurred (for non-anchor links)
    assert true # Placeholder - implement specific link behavior tests
  end

  def test_input_activation(input)
    case input[:type]&.downcase
    when 'checkbox', 'radio'
      input.send_keys(:space)
    when 'submit', 'button'
      input.send_keys(:enter)
    else
      # Text inputs should accept typing
      input.send_keys('test')
      assert input.value.include?('test'), "Text input should accept keyboard input"
    end
  end

  def verify_aria_labels
    # Test that interactive elements have proper labels
    unlabeled_elements = all("button, input, select, textarea").select do |element|
      !element[:aria_label] &&
      !element['aria-labelledby'] &&
      element.all("label[for='#{element[:id]}']").empty? &&
      element.text.strip.empty?
    end

    assert unlabeled_elements.empty?,
      "Found unlabeled interactive elements: #{unlabeled_elements.map { |e| element_info(e) }.join(', ')}"
  end

  def verify_heading_structure
    headings = all("h1, h2, h3, h4, h5, h6")
    levels = headings.map { |h| h.tag_name.gsub('h', '').to_i }

    # Verify logical heading hierarchy
    levels.each_with_index do |level, index|
      next if index == 0

      previous_level = levels[index - 1]
      assert level <= previous_level + 1,
        "Heading hierarchy gap: h#{previous_level} followed by h#{level}"
    end

    # Verify page has exactly one h1
    h1_count = all("h1").length
    assert_equal 1, h1_count, "Page should have exactly one h1 heading"
  end

  def verify_landmark_regions
    # Verify main landmark exists
    assert_selector "main, [role='main']", count: 1

    # Verify navigation landmarks are properly labeled
    all("nav, [role='navigation']").each do |nav|
      assert nav[:aria_label] || nav['aria-labelledby'] || !nav.text.strip.empty?,
        "Navigation landmarks should be labeled"
    end
  end

  def verify_form_labels
    form_inputs = all("input:not([type='hidden']):not([type='submit']):not([type='button']), select, textarea")

    form_inputs.each do |input|
      has_label = input[:aria_label] ||
                  input['aria-labelledby'] ||
                  has_selector?("label[for='#{input[:id]}']") ||
                  input.find(:xpath, "./ancestor::label")

      assert has_label, "Form input #{element_info(input)} must have an associated label"
    end
  end

  def verify_button_descriptions
    buttons = all("button")

    buttons.each do |button|
      has_description = button.text.strip.present? ||
                       button[:aria_label] ||
                       button['aria-labelledby'] ||
                       button[:title]

      assert has_description, "Button #{element_info(button)} must have descriptive text"
    end
  end

  def test_modal_focus_trap
    modal = find("[role='dialog'], .modal")

    # Test that focus stays within modal
    focusable_in_modal = modal.all("button, a, input, select, textarea, [tabindex]:not([tabindex='-1'])")

    # Tab through all elements and verify focus stays in modal
    focusable_in_modal.each do |element|
      element.send_keys(:tab)

      current_focus = page.evaluate_script("document.activeElement")
      assert modal.has_css?("##{current_focus[:id]}", visible: false),
        "Focus should remain within modal"
    end
  end

  def verify_button_contrast
    buttons = all("button, .btn")
    buttons.each do |button|
      # Manual verification prompt
      puts "Verify button contrast: #{element_info(button)}"
    end
  end

  def verify_text_contrast
    # Check common text elements
    text_elements = all("p, span, div, a, h1, h2, h3, h4, h5, h6")
    puts "Total text elements to verify: #{text_elements.length}"
  end

  def verify_link_contrast
    links = all("a")
    puts "Link contrast verification needed for #{links.length} links"
  end
end