# Constraint for subdomain-based routing
# Allows routing based on subdomain presence
module Constraints
  class SubdomainConstraint
    def initialize(*subdomains)
      @subdomains = subdomains.map(&:to_s)
    end

    def matches?(request)
      # Extract subdomain from request
      # Note: request.subdomain returns empty string "" on localhost, not nil
      subdomain = request.subdomain
      subdomain = nil if subdomain.blank?

      # Determine if we're in a local development environment
      is_localhost = request.host == 'localhost' || request.host.start_with?('127.0.0.1')
      is_local_domain = request.host.end_with?('.local')

      if Rails.env.development? && (is_localhost || is_local_domain)
        # Development behavior:
        # Plain localhost (no subdomain) should ONLY match marketing routes
        # app.localhost (with 'app' subdomain) should ONLY match app routes

        @subdomains.any? do |s|
          case s
          when nil, 'www'
            # Match marketing domain: ONLY when there's no subdomain
            # This prevents matching app.localhost
            subdomain.nil?
          when 'app'
            # Match app subdomain: ONLY when subdomain is explicitly 'app'
            subdomain == 'app'
          else
            # Match any other specific subdomain
            s == subdomain
          end
        end
      else
        # Production behavior: strict subdomain matching
        @subdomains.any? do |s|
          case s
          when nil, 'www'
            # Match root domain or www
            subdomain.nil? || subdomain == 'www'
          else
            # Match specific subdomain
            s == subdomain
          end
        end
      end
    end
  end
end
