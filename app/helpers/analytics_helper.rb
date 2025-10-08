module AnalyticsHelper
  def track_event(event_name, parameters = {})
    return unless Rails.env.production? || Rails.env.development?

    sanitized_params = sanitize_parameters(parameters)

    # Add user context if available
    if defined?(current_user) && current_user&.persisted?
      sanitized_params.merge!(get_user_context)
    end

    # Check if we're in a view context or controller context
    if respond_to?(:content_for, true) && !is_a?(ActionController::Base)
      # We're in a view - use content_for directly
      content_for :analytics_events do
        javascript_tag nonce: true do
          raw "gtag('event', '#{event_name}', #{sanitized_params.to_json});"
        end
      end
    elsif defined?(session) && respond_to?(:session)
      # We're in a controller - store event in session for next render
      # Use string keys to avoid session serialization issues
      session[:pending_analytics_events] ||= []
      session[:pending_analytics_events] << { 'event' => event_name, 'params' => sanitized_params }
      Rails.logger.debug "[Analytics] Queued event: #{event_name}, Parameters: #{sanitized_params.to_json}"
    else
      # Background job or other context - just log it
      Rails.logger.info "[Analytics] Event: #{event_name}, Parameters: #{sanitized_params.to_json}"
    end
  end

  def track_page_view(page_title = nil, page_location = nil)
    return unless Rails.env.production? || Rails.env.development?

    params = {}
    params[:page_title] = page_title if page_title.present?
    params[:page_location] = page_location if page_location.present?

    content_for :analytics_events do
      javascript_tag nonce: true do
        if params.any?
          raw "gtag('config', 'G-JYRMQDB1V4', #{params.to_json});"
        end
      end
    end
  end

  def track_custom_event(event_category, event_action, event_label = nil, value = nil)
    return unless Rails.env.production? || Rails.env.development?

    params = {
      event_category: event_category,
      event_action: event_action
    }
    params[:event_label] = event_label if event_label.present?
    params[:value] = value if value.present?

    track_event('custom_event', params)
  end

  # Authentication Events
  def track_user_signup(method = 'email')
    track_event('sign_up', {
      method: method
    })
  end

  def track_user_login(method = 'email')
    track_event('login', {
      method: method
    })
  end

  def track_user_logout
    track_event('logout')
  end

  # Video Audit Events
  def track_video_upload_start(file_size = nil, duration = nil)
    params = { event_category: 'video_audit', event_action: 'upload_start' }
    params[:file_size_mb] = (file_size.to_f / 1.megabyte).round(2) if file_size.present?
    params[:duration_seconds] = duration.to_i if duration.present?

    track_event('video_upload_start', params)
  end

  def track_video_upload_success(audit_id, file_size = nil, duration = nil)
    params = {
      event_category: 'video_audit',
      event_action: 'upload_success',
      audit_id: audit_id
    }
    params[:file_size_mb] = (file_size.to_f / 1.megabyte).round(2) if file_size.present?
    params[:duration_seconds] = duration.to_i if duration.present?

    track_event('video_upload_success', params)
  end

  def track_video_upload_error(error_type, message = nil)
    params = {
      event_category: 'video_audit',
      event_action: 'upload_error',
      error_type: error_type
    }
    params[:error_message] = truncate_string(message, length: 100) if message.present?

    track_event('video_upload_error', params)
  end

  def track_processing_stage(audit_id, stage, duration = nil)
    params = {
      event_category: 'video_processing',
      event_action: stage,
      audit_id: audit_id
    }
    params[:duration_seconds] = duration.to_i if duration.present?

    track_event('processing_stage', params)
  end

  def track_audit_completion(audit_id, total_duration, issues_count = nil)
    params = {
      event_category: 'video_audit',
      event_action: 'completion',
      audit_id: audit_id,
      total_duration_seconds: total_duration.to_i
    }
    params[:issues_found] = issues_count.to_i if issues_count.present?

    track_event('audit_completion', params)
  end

  # User Engagement Events
  def track_issue_copy(audit_id, issue_index)
    track_event('issue_copy', {
      event_category: 'engagement',
      audit_id: audit_id,
      issue_index: issue_index
    })
  end

  def track_jira_integration(audit_id, issue_index)
    track_event('jira_integration', {
      event_category: 'engagement',
      audit_id: audit_id,
      issue_index: issue_index
    })
  end

  def track_timeline_navigation(audit_id, issue_index)
    track_event('timeline_navigation', {
      event_category: 'engagement',
      audit_id: audit_id,
      issue_index: issue_index
    })
  end

  # Knowledge Base Events
  def track_knowledge_search(query, results_count = nil)
    params = {
      event_category: 'knowledge_base',
      event_action: 'search',
      search_term: truncate_string(query, length: 50)
    }
    params[:results_count] = results_count.to_i if results_count.present?

    track_event('knowledge_search', params)
  end

  def track_knowledge_document_view(document_id, document_title = nil)
    params = {
      event_category: 'knowledge_base',
      event_action: 'document_view',
      document_id: document_id
    }
    params[:document_title] = truncate_string(document_title, length: 50) if document_title.present?

    track_event('knowledge_document_view', params)
  end

  # Error Tracking
  def track_error(error_type, page, message = nil)
    params = {
      event_category: 'error',
      event_action: error_type,
      page: page
    }
    params[:error_message] = truncate_string(message, length: 100) if message.present?

    track_event('application_error', params)
  end

  # Performance Tracking
  def track_page_load_time(page_name, load_time_ms)
    track_event('page_performance', {
      event_category: 'performance',
      page_name: page_name,
      load_time_ms: load_time_ms
    })
  end

  # Render queued analytics events from session
  def render_queued_analytics_events
    return unless defined?(session) && session[:pending_analytics_events].present?

    events = session[:pending_analytics_events]
    session.delete(:pending_analytics_events) # Clear the queue

    javascript_tag nonce: content_security_policy_nonce do
      events.map do |event_data|
        # Handle both symbol and string keys (Rails session serialization may convert symbols to strings)
        event_name = event_data[:event] || event_data['event']
        params = event_data[:params] || event_data['params'] || {}
        "gtag('event', '#{event_name}', #{params.to_json});"
      end.join("\n")
    end
  end

  # Page Performance Tracking
  def track_core_web_vitals
    content_for :analytics_events do
      javascript_tag nonce: true do
        raw <<~JAVASCRIPT
          // Track Core Web Vitals
          function trackWebVitals() {
            if ('performance' in window) {
              const navigation = performance.getEntriesByType('navigation')[0];
              if (navigation) {
                gtag('event', 'page_performance', {
                  event_category: 'performance',
                  load_time: Math.round(navigation.loadEventEnd - navigation.loadEventStart),
                  dom_content_loaded: Math.round(navigation.domContentLoadedEventEnd - navigation.domContentLoadedEventStart),
                  page_url: window.location.href
                });
              }
            }
          }

          // Track after page is fully loaded
          if (document.readyState === 'complete') {
            trackWebVitals();
          } else {
            window.addEventListener('load', trackWebVitals);
          }
        JAVASCRIPT
      end
    end
  end

  # User Journey Tracking
  def track_user_session_start
    return unless defined?(current_user) && current_user&.persisted?

    track_event('session_start', {
      event_category: 'user_journey',
      user_role: 'standard', # Can be enhanced with actual user roles
      session_count: session[:session_count] || 1,
      is_returning_user: current_user.created_at < 1.day.ago
    })
  end

  def track_feature_usage(feature_name, context = {})
    track_event('feature_usage', {
      event_category: 'engagement',
      feature_name: feature_name,
      **context
    })
  end

  private

  # Custom truncate method that works in all contexts (views, controllers, and jobs)
  def truncate_string(text, length:, separator: ' ', omission: '...')
    return text if text.nil? || text.length <= length

    stop = length - omission.length
    if separator
      text[0, stop].rstrip + omission
    else
      text[0, stop] + omission
    end
  end

  def get_user_context
    return {} unless defined?(current_user) && current_user&.persisted?

    {
      user_role: 'standard', # Can be enhanced with actual user role system
      user_tenure_days: (Date.current - current_user.created_at.to_date).to_i,
      audit_count: current_user.respond_to?(:video_audits) ? current_user.video_audits.count : 0
    }
  end

  def sanitize_parameters(params)
    # Remove any potentially sensitive data and ensure proper types
    sanitized = {}

    params.each do |key, value|
      next if key.to_s.include?('password') || key.to_s.include?('token') || key.to_s.include?('secret')

      case value
      when String
        sanitized[key] = value.present? ? value : nil
      when Numeric
        sanitized[key] = value
      when TrueClass, FalseClass
        sanitized[key] = value
      when nil
        sanitized[key] = nil
      else
        sanitized[key] = value.to_s
      end
    end

    sanitized.compact
  end
end