# app/services/llm/workflow_classifier.rb
module Llm
  class WorkflowClassifier
    BUSINESS_CRITICAL_KEYWORDS = [
      'checkout', 'payment', 'pay', 'purchase', 'buy', 'order',
      'signup', 'sign up', 'register', 'registration', 'login', 'sign in', 'auth',
      'cart', 'billing', 'subscription', 'credit card', 'confirm order'
    ].freeze

    HIGH_IMPACT_KEYWORDS = [
      'onboarding', 'search', 'filter', 'core feature',
      'dashboard', 'upload', 'create', 'new', 'main flow',
      'navigation', 'browse', 'discover', 'recommendation'
    ].freeze

    LOW_IMPACT_KEYWORDS = [
      'help', 'about', 'faq', 'footer', 'privacy',
      'terms', 'contact', 'support', 'documentation',
      'settings page', 'profile page', 'about us'
    ].freeze

    STANDARD_KEYWORDS = [
      'settings', 'profile', 'preferences', 'account',
      'notification', 'edit profile', 'manage', 'update'
    ].freeze

    # Classify workflow based on video audit title and description
    # Returns: "Business-Critical", "High-Impact", "Standard", or "Low-Impact"
    def self.classify(video_audit)
      return "Standard" unless video_audit

      title = video_audit.title.to_s.downcase
      description = video_audit.description.to_s.downcase
      text = "#{title} #{description}"

      # Check in order of priority (most critical first)
      if contains_keywords?(text, BUSINESS_CRITICAL_KEYWORDS)
        "Business-Critical"
      elsif contains_keywords?(text, HIGH_IMPACT_KEYWORDS)
        "High-Impact"
      elsif contains_keywords?(text, LOW_IMPACT_KEYWORDS)
        "Low-Impact"
      elsif contains_keywords?(text, STANDARD_KEYWORDS)
        "Standard"
      else
        # Default to Standard for unknown workflows
        "Standard"
      end
    end

    # Get severity guidelines for a given workflow criticality
    def self.severity_guidelines(criticality)
      case criticality
      when "Business-Critical"
        {
          blocking: "High",
          confusing: "High",
          minor_friction: "Medium",
          cosmetic: "Low-Medium"
        }
      when "High-Impact"
        {
          blocking: "High",
          confusing: "Medium-High",
          minor_friction: "Medium",
          cosmetic: "Low"
        }
      when "Standard"
        {
          blocking: "Medium-High",
          confusing: "Medium",
          minor_friction: "Low-Medium",
          cosmetic: "Low"
        }
      when "Low-Impact"
        {
          blocking: "Medium",
          confusing: "Low-Medium",
          minor_friction: "Low",
          cosmetic: "Low"
        }
      else
        severity_guidelines("Standard")
      end
    end

    private

    def self.contains_keywords?(text, keywords)
      keywords.any? { |keyword| text.include?(keyword) }
    end
  end
end
