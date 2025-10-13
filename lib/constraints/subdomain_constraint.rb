# Constraint for subdomain-based routing
# Allows routing based on subdomain presence
class SubdomainConstraint
  def initialize(*subdomains)
    @subdomains = subdomains.map(&:to_s)
  end

  def matches?(request)
    # Extract subdomain from request
    subdomain = request.subdomain.presence

    # Determine if we're in a local development environment
    is_localhost = request.host == 'localhost' || request.host.start_with?('127.0.0.1')
    is_local_domain = request.host.end_with?('.local')

    if Rails.env.development? && (is_localhost || is_local_domain)
      # Development behavior: localhost with no subdomain is treated as marketing (nil)
      # For localhost or .local domains:
      # - nil/www subdomain matches root marketing site
      # - 'app' subdomain matches app site
      @subdomains.any? do |s|
        case s
        when nil, 'www'
          # Match marketing domain: no subdomain or 'www'
          subdomain.nil? || subdomain == 'www'
        else
          # Match specific subdomain (e.g., 'app')
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
