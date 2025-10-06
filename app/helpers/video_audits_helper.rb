module VideoAuditsHelper
  # Severity icon mapping: 🔴🟡🔵 for High/Med/Low
  def severity_icon(severity)
    case severity&.downcase
    when 'high'
      '🔴'
    when 'medium', 'med'
      '🟡'
    when 'low'
      '🔵'
    else
      '⚪'
    end
  end

  # Extract component from issue title (Navigation, Form, Button, etc.)
  def extract_component(issue)
    title = issue["painPointTitle"] || issue["title"] || ""

    # Common UI component patterns
    components = [
      'Navigation', 'Menu', 'Navbar', 'Sidebar',
      'Form', 'Input', 'Button', 'Link',
      'Modal', 'Dialog', 'Popup',
      'Search', 'Filter',
      'Table', 'List', 'Grid',
      'Header', 'Footer',
      'Tab', 'Accordion',
      'Dropdown', 'Select',
      'Checkbox', 'Radio',
      'Image', 'Video',
      'Text', 'Label',
      'Icon', 'Badge',
      'Layout', 'Container'
    ]

    # Find the first component mentioned in the title
    detected = components.find { |comp| title.match?(/\b#{comp}\b/i) }
    detected || 'Interface'
  end

  # Estimate frequency based on issue description (Often/Sometimes/Rarely)
  def estimate_frequency(issue)
    description = issue["issueDescription"] || ""
    title = issue["painPointTitle"] || ""
    combined_text = "#{title} #{description}".downcase

    if combined_text.match?(/always|every|all|constantly|frequently|often|common/)
      'Often'
    elsif combined_text.match?(/sometimes|occasionally|intermittent|periodic/)
      'Sometimes'
    else
      'Rarely'
    end
  end

  # Estimate confidence based on issue content (High/Medium/Low)
  def estimate_confidence(issue)
    description = issue["issueDescription"] || ""
    evidence_score = 0

    # Increase confidence based on evidence indicators
    evidence_score += 1 if issue["frameReference"].present?
    evidence_score += 1 if description.length > 50
    evidence_score += 1 if issue["recommendations"]&.length.to_i > 1

    case evidence_score
    when 3
      'High'
    when 2
      'Medium'
    else
      'Low'
    end
  end

  # Calculate T-shirt sizing (XS/S/M/L/XL) based on count & severity
  def calculate_tshirt_sizing(issues)
    return 'XS' if issues.empty?

    # Weight issues by severity
    severity_weights = { 'high' => 3, 'medium' => 2, 'low' => 1 }
    weighted_score = issues.sum do |issue|
      severity = issue["severity"]&.downcase || 'low'
      severity_weights[severity] || 1
    end

    case weighted_score
    when 0..2
      'XS'
    when 3..5
      'S'
    when 6..10
      'M'
    when 11..15
      'L'
    else
      'XL'
    end
  end

  # T-shirt size styling helper
  def tshirt_size_class(size)
    case size
    when 'XS'
      'badge-success'
    when 'S'
      'badge-warning'
    when 'M'
      'badge-orange'
    when 'L'
      'badge-danger'
    when 'XL'
      'badge-purple'
    else
      'badge-secondary'
    end
  end

  # Severity badge class helper
  def severity_badge_class(severity)
    case severity&.downcase
    when 'high'
      'badge-danger'
    when 'medium', 'med'
      'badge-warning'
    when 'low'
      'badge-info'
    else
      'badge-secondary'
    end
  end

  # Generate anchor ID for an issue
  def issue_anchor_id(index)
    "uxw-#{(index + 1).to_s.rjust(3, '0')}"
  end

  # Extract heuristic from issue data for knowledge base linking
  def extract_heuristic(issue)
    # Check if heuristic is explicitly mentioned in the issue
    if issue["heuristic"].present?
      return issue["heuristic"]
    end

    # Extract from description or title using common heuristic patterns
    description = issue["issueDescription"] || ""
    title = issue["painPointTitle"] || ""
    combined_text = "#{title} #{description}".downcase

    heuristics = [
      'Visibility of System Status',
      'Match Between System and Real World',
      'User Control and Freedom',
      'Consistency and Standards',
      'Error Prevention',
      'Recognition Rather Than Recall',
      'Flexibility and Efficiency of Use',
      'Aesthetic and Minimalist Design',
      'Help Users Recognize, Diagnose, and Recover from Errors',
      'Help and Documentation'
    ]

    # Find matching heuristic keywords
    if combined_text.match?(/status|feedback|progress|loading/)
      'Visibility of System Status'
    elsif combined_text.match?(/metaphor|real.world|familiar|convention/)
      'Match Between System and Real World'
    elsif combined_text.match?(/control|freedom|undo|cancel|exit/)
      'User Control and Freedom'
    elsif combined_text.match?(/consistent|standard|pattern|uniform/)
      'Consistency and Standards'
    elsif combined_text.match?(/prevent|validation|error.prevention|confirm/)
      'Error Prevention'
    elsif combined_text.match?(/remember|recognition|memory|recall/)
      'Recognition Rather Than Recall'
    elsif combined_text.match?(/shortcut|efficiency|flexible|power.user/)
      'Flexibility and Efficiency of Use'
    elsif combined_text.match?(/aesthetic|minimal|clutter|simple/)
      'Aesthetic and Minimalist Design'
    elsif combined_text.match?(/error.message|recover|diagnosis|helpful/)
      'Help Users Recognize, Diagnose, and Recover from Errors'
    elsif combined_text.match?(/help|documentation|instruction|guide/)
      'Help and Documentation'
    else
      'General Usability'
    end
  end

  # Extract timestamp from issue data
  def extract_timestamp(issue)
    # Check for explicit timestamp data
    if issue["timestamp"].present?
      return format_timestamp(issue["timestamp"])
    end

    # Check frame reference for timing information
    if issue["frameReference"].present?
      frame_ref = issue["frameReference"]
      # Extract time patterns like "at 2:15" or "00:02:15"
      if frame_ref.match(/(\d{1,2}):(\d{2})(?::(\d{2}))?/)
        return format_time_range($1.to_i, $2.to_i, $3&.to_i || 0)
      end
    end

    # Return placeholder if no timestamp found
    "Time not available"
  end

  # Format timestamp for display
  def format_timestamp(timestamp)
    case timestamp
    when String
      # Handle string timestamps like "00:02:15-00:02:30"
      if timestamp.match(/(\d{2}):(\d{2}):?(\d{2})?[-–](\d{2}):(\d{2}):?(\d{2})?/)
        start_time = "#{$1}:#{$2}" + ($3 ? ":#{$3}" : "")
        end_time = "#{$4}:#{$5}" + ($6 ? ":#{$6}" : "")
        "#{start_time}–#{end_time}"
      else
        timestamp
      end
    when Hash
      # Handle hash with start/end times
      start_time = timestamp["start"] || timestamp[:start]
      end_time = timestamp["end"] || timestamp[:end]
      if start_time && end_time
        "#{start_time}–#{end_time}"
      else
        "Time not available"
      end
    else
      "Time not available"
    end
  end

  # Format time range helper
  def format_time_range(minutes, seconds, end_seconds = nil)
    start_time = sprintf("%02d:%02d", minutes, seconds)
    if end_seconds
      end_time = sprintf("%02d:%02d", minutes, seconds + (end_seconds - seconds).abs)
      "#{start_time}–#{end_time}"
    else
      # Default to 10-second range if no end time
      end_minutes = minutes
      end_secs = seconds + 10
      if end_secs >= 60
        end_minutes += 1
        end_secs -= 60
      end
      end_time = sprintf("%02d:%02d", end_minutes, end_secs)
      "#{start_time}–#{end_time}"
    end
  end

  # Badge class helpers for new badge types
  def frequency_badge_class(frequency)
    case frequency.downcase
    when 'often'
      'badge-danger'
    when 'sometimes'
      'badge-warning'
    when 'rarely'
      'badge-info'
    else
      'badge-secondary'
    end
  end

  def confidence_badge_class(confidence)
    case confidence.downcase
    when 'high'
      'badge-success'
    when 'medium'
      'badge-warning'
    when 'low'
      'badge-secondary'
    else
      'badge-light'
    end
  end

  def heuristic_badge_class
    'badge-outline-primary'
  end

  # Check if issue has evidence (thumbnails or frame references)
  def has_evidence?(issue)
    issue["frameReference"].present? ||
    issue["thumbnail"].present? ||
    issue["evidence"].present? ||
    issue["screenshots"].present?
  end

  # Get evidence count for display
  def evidence_count(issue)
    count = 0
    count += 1 if issue["frameReference"].present?
    count += 1 if issue["thumbnail"].present?
    count += issue["screenshots"]&.length.to_i
    count += issue["evidence"]&.length.to_i if issue["evidence"].is_a?(Array)
    count
  end
end