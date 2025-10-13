module ApplicationHelper
  def markdown_to_html(text)
    renderer = Redcarpet::Render::HTML.new
    markdown = Redcarpet::Markdown.new(renderer)
    sanitize(markdown.render(text.to_s))
  end

  def frame_range_to_time(frame_ref)
    if frame_ref =~ /Frame(?:s)? (\d+)(?:-(\d+))?/i
      start_frame = $1.to_i
      end_frame = $2 ? $2.to_i : start_frame
      start_time = Time.at(start_frame - 1).utc.strftime('%-M:%S')
      end_time = Time.at(end_frame - 1).utc.strftime('%-M:%S')
      return start_time == end_time ? start_time : "#{start_time} - #{end_time}"
    end
    nil
  end

  # Generate formatted issue ID (e.g., UXW-042-001)
  def generate_issue_id(audit_id, index)
    "UXW-#{audit_id.to_s.rjust(3, '0')}-#{(index + 1).to_s.rjust(3, '0')}"
  end

  # Extract Nielsen heuristic number from heuristic name
  def extract_heuristic_label(heuristic_violated)
    return "General UX Principle" if heuristic_violated.blank?

    heuristic_map = {
      "Visibility of system status" => "Nielsen #1 Visibility",
      "Match between system and real world" => "Nielsen #2 Match with real world",
      "User control and freedom" => "Nielsen #3 User control and freedom",
      "Consistency and standards" => "Nielsen #4 Consistency and standards",
      "Error prevention" => "Nielsen #5 Error prevention",
      "Recognition rather than recall" => "Nielsen #6 Recognition rather than recall",
      "Flexibility and efficiency of use" => "Nielsen #7 Flexibility and efficiency",
      "Aesthetic and minimalist design" => "Nielsen #8 Aesthetic and minimalist design",
      "Help users recognize, diagnose, and recover from errors" => "Nielsen #9 Error recovery",
      "Help and documentation" => "Nielsen #10 Help and documentation"
    }

    heuristic_map[heuristic_violated] || "Heuristic: #{heuristic_violated}"
  end

  # Calculate severity statistics from issues array
  def calculate_severity_stats(issues)
    return { total: 0, high: 0, medium: 0, low: 0 } if issues.blank?

    stats = { total: issues.length, high: 0, medium: 0, low: 0 }

    issues.each do |issue|
      severity = issue["severity"]&.downcase
      case severity
      when "high"
        stats[:high] += 1
      when "medium"
        stats[:medium] += 1
      when "low"
        stats[:low] += 1
      end
    end

    stats
  end

  # Extract evidence from issue description (full text, no truncation)
  def extract_evidence(issue_description)
    return "" if issue_description.blank?

    # Remove heuristic prefix patterns if present
    text = issue_description
      .gsub(/^This violates.*?\.\s*/i, '')                                    # "This violates the principle of X."
      .gsub(/^This conflicts with Nielsen's Heuristic #\d+.*?\.\s*/i, '')    # "This conflicts with Nielsen's Heuristic #1..."
      .gsub(/^Nielsen's Heuristic #\d+.*?\.\s*/i, '')                        # "Nielsen's Heuristic #1..."
      .gsub(/^Heuristic violated:.*?\.\s*/i, '')                             # "Heuristic violated: X."
      .strip

    # Return full text without truncation
    text
  end

  # Check if we're on localhost (for development)
  def is_localhost?
    request.host == 'localhost' || request.host.start_with?('127.0.0.1')
  end

  # Generate URL for app subdomain
  def app_subdomain_url(path = nil)
    protocol = request.protocol
    port = [80, 443].include?(request.port) ? '' : ":#{request.port}"

    if is_localhost?
      # On localhost, just use localhost without subdomain trickery
      base = "#{protocol}localhost#{port}"
    else
      domain = request.domain
      base = "#{protocol}app.#{domain}#{port}"
    end

    path ? "#{base}#{path}" : base
  end

  # Generate URL for marketing (root) domain
  def marketing_url(path = nil)
    protocol = request.protocol
    port = [80, 443].include?(request.port) ? '' : ":#{request.port}"

    if is_localhost?
      # On localhost, just use localhost
      base = "#{protocol}localhost#{port}"
    else
      domain = request.domain.sub('app.', '')
      base = "#{protocol}#{domain}#{port}"
    end

    path ? "#{base}#{path}" : base
  end

  # Generate sign in URL (always goes to marketing domain)
  def marketing_sign_in_url
    if is_localhost?
      new_user_session_path
    else
      marketing_url(new_user_session_path)
    end
  end

  # Generate sign out redirect URL
  def after_sign_out_url
    if is_localhost?
      root_path
    else
      marketing_url
    end
  end

  # Generate projects URL (after sign in redirect)
  def after_sign_in_url
    if is_localhost?
      projects_path
    else
      app_subdomain_url('/projects')
    end
  end

  # Check if currently on marketing domain
  def on_marketing_domain?
    request.subdomain.blank? || request.subdomain == 'www'
  end

  # Check if currently on app subdomain
  def on_app_subdomain?
    request.subdomain == 'app'
  end

  # Smart root path that returns correct path based on context
  def app_root_path
    on_app_subdomain? ? projects_path : root_path
  end
end
