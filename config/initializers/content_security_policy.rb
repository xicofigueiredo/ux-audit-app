# Be sure to restart your server when you modify this file.

# Define an application-wide content security policy.
# See the Securing Rails Applications Guide for more information:
# https://guides.rubyonrails.org/security.html#content-security-policy-header

Rails.application.configure do
  config.content_security_policy do |policy|
    policy.default_src :self, :https
    policy.font_src    :self, :https, :data
    policy.img_src     :self, :https, :data
    policy.object_src  :none

    # Allow Google Analytics, Mixpanel, and Tailwind CDN scripts with specific nonce handling
    policy.script_src  :self, :https,
                       'https://www.googletagmanager.com',
                       'https://www.google-analytics.com',
                       'https://cdn.tailwindcss.com',
                       'https://cdn.mxpnl.com',
                       'http://cdn.mxpnl.com'

    # Allow inline styles for Tailwind and custom styling
    policy.style_src   :self, :https, :unsafe_inline,
                       'https://cdn.tailwindcss.com'

    # Allow Google Analytics and Mixpanel connections
    policy.connect_src :self, :https,
                       'https://www.google-analytics.com',
                       'https://analytics.google.com',
                       'https://region1.google-analytics.com',
                       'https://api-eu.mixpanel.com'

    # Specify URI for violation reports
    # policy.report_uri "/csp-violation-report-endpoint"
  end

  # Generate session nonces for permitted importmap and inline scripts only
  config.content_security_policy_nonce_generator = ->(request) { SecureRandom.base64(16) }
  config.content_security_policy_nonce_directives = %w(script-src)

  # Report violations without enforcing the policy.
  # config.content_security_policy_report_only = true
end
