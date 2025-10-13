# Configure session store to share cookies across subdomains
# This allows users to stay logged in when moving between uxauditapp.com and app.uxauditapp.com

if Rails.env.development?
  # In development, support both localhost and .local domains
  # Using :all to share cookies across all subdomains regardless of the domain
  Rails.application.config.session_store :cookie_store,
    key: '_ux_audit_app_session',
    domain: :all  # Works for both localhost and *.uxauditapp.local
else
  # In production with .com domains
  Rails.application.config.session_store :cookie_store,
    key: '_ux_audit_app_session',
    domain: :all,  # Share cookies across all subdomains
    tld_length: 2  # For uxauditapp.com (2 parts: uxauditapp + com)
end
