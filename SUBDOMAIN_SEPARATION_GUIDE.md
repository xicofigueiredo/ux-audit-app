# Subdomain Separation Implementation Guide

## Overview

The UX Audit App has been successfully configured to separate the marketing site from the web application using subdomain routing:

- **Marketing Site**: `uxauditapp.com` and `www.uxauditapp.com`
- **Web Application**: `app.uxauditapp.com`

## What Was Changed

### 1. Routing Configuration

**File**: `config/routes.rb`

- Added subdomain-based routing constraints using `SubdomainConstraint` class
- Marketing routes (landing page, demo, auth, public knowledge base) on root domain
- App routes (video audits, projects, admin features) on `app` subdomain
- Automatic redirects between domains based on authentication state

### 2. Subdomain Constraint Class

**File**: `lib/constraints/subdomain_constraint.rb`

- Custom routing constraint to match subdomains
- Handles `nil` (root domain), `www`, and `app` subdomains

### 3. Layouts

**Files**:
- `app/views/layouts/marketing.html.erb` - Marketing site layout (minimal nav)
- `app/views/layouts/application.html.erb` - App layout (full functionality)

Marketing layout shows:
- Sign in / Sign up buttons (when not authenticated)
- "Go to App" button (when authenticated)
- Links to: How It Works, Benefits, Knowledge Base, FAQ

App layout shows:
- Upload Video, My Projects, Knowledge Base navigation
- User profile and sign out

### 4. Controllers Updated

**PagesController** (`app/controllers/pages_controller.rb`)
- Uses `marketing` layout
- Handles landing page and demo

**UxKnowledgeDocumentsController** (`app/controllers/ux_knowledge_documents_controller.rb`)
- Dynamic layout based on subdomain
- Public access (no auth required) on marketing domain
- Full admin features on app subdomain

**Users::SessionsController** (`app/controllers/users/sessions_controller.rb`)
- Uses `marketing` layout
- Redirects to `app.uxauditapp.com/projects` after sign in

**Users::RegistrationsController** (`app/controllers/users/registrations_controller.rb`)
- Uses `marketing` layout
- Redirects to `app.uxauditapp.com/projects` after sign up

### 5. Session Configuration

**File**: `config/initializers/session_store.rb`

```ruby
Rails.application.config.session_store :cookie_store,
  key: '_ux_audit_app_session',
  domain: :all,
  tld_length: 2
```

This enables session sharing across all subdomains, keeping users authenticated when moving between `uxauditapp.com` and `app.uxauditapp.com`.

### 6. Environment Configuration

**Production** (`config/environments/production.rb`):
```ruby
config.hosts = [
  "uxauditapp.com",
  "www.uxauditapp.com",
  "app.uxauditapp.com",
  /.*\.uxauditapp\.com/
]
```

**Development** (`config/environments/development.rb`):
```ruby
config.hosts << "uxauditapp.local"
config.hosts << "www.uxauditapp.local"
config.hosts << "app.uxauditapp.local"
config.hosts << /.*\.uxauditapp\.local/
```

### 7. Kamal Deployment Configuration

**File**: `config/deploy.yml`

Updated Traefik labels to handle multiple domains:
```yaml
traefik.http.routers.uxauditapp-web.rule: Host(`uxauditapp.com`) || Host(`www.uxauditapp.com`) || Host(`app.uxauditapp.com`)
traefik.http.routers.uxauditapp-web.tls.domains[0].main: uxauditapp.com
traefik.http.routers.uxauditapp-web.tls.domains[0].sans: www.uxauditapp.com,app.uxauditapp.com
```

### 8. Helper Methods

**File**: `app/helpers/application_helper.rb`

Added helper methods:
- `app_subdomain_url(path)` - Generate URLs for app subdomain
- `marketing_url(path)` - Generate URLs for marketing domain
- `on_marketing_domain?` - Check if currently on marketing domain
- `on_app_subdomain?` - Check if currently on app subdomain

## Deployment Steps

### Prerequisites

Before deploying, ensure you have:
1. Access to your DNS provider (where uxauditapp.com is registered)
2. SSH access to your Digital Ocean droplet (143.110.169.251)
3. Kamal CLI installed locally

### Step 1: DNS Configuration

Add an A record for the app subdomain:

```
Type: A
Name: app
Value: 143.110.169.251
TTL: 3600 (or your preferred value)
```

**Note**: DNS propagation can take up to 48 hours, but usually completes within 1-2 hours.

### Step 2: Verify DNS Resolution

Wait for DNS to propagate, then verify:

```bash
nslookup app.uxauditapp.com
# Should return: 143.110.169.251
```

### Step 3: Deploy with Kamal

```bash
# Build and push new Docker image
kamal deploy

# This will:
# - Build the new image with subdomain routing
# - Push to Docker Hub
# - Deploy to server
# - Configure Traefik for all three domains
# - Request SSL certificates from Let's Encrypt
```

### Step 4: Verify SSL Certificates

Check that SSL certificates were issued for all domains:

```bash
kamal proxy logs

# Look for lines indicating successful certificate generation:
# - uxauditapp.com
# - www.uxauditapp.com
# - app.uxauditapp.com
```

### Step 5: Test the Deployment

1. **Test Marketing Site**:
   - Visit `https://uxauditapp.com`
   - Should show landing page
   - Click "Sign in" - should show sign in form
   - Click "Sign up" - should show registration form

2. **Test Authentication Flow**:
   - Sign in or sign up on marketing site
   - Should automatically redirect to `https://app.uxauditapp.com/projects`
   - Verify you're still logged in (session maintained)

3. **Test App Functionality**:
   - Visit `https://app.uxauditapp.com`
   - If not logged in, should redirect to marketing site
   - If logged in, should show projects page
   - Test video upload, projects list, knowledge base

4. **Test Cross-Subdomain Navigation**:
   - From app subdomain, click "Knowledge Base"
   - Should navigate within app subdomain
   - Sign out from app subdomain
   - Should redirect to marketing site

## Local Development Testing

To test subdomain routing locally, add these entries to `/etc/hosts`:

```
127.0.0.1 uxauditapp.local
127.0.0.1 www.uxauditapp.local
127.0.0.1 app.uxauditapp.local
```

Then start the Rails server:

```bash
rails server -p 3001
```

Access the app:
- Marketing: `http://uxauditapp.local:3001`
- App: `http://app.uxauditapp.local:3001`

## Troubleshooting

### Issue: Session Not Maintained Across Subdomains

**Symptoms**: User logs in on marketing site but appears logged out on app subdomain

**Solution**:
1. Check `config/initializers/session_store.rb` is present
2. Verify `domain: :all` is set
3. Restart Rails server
4. Clear browser cookies and try again

### Issue: Routing Not Working

**Symptoms**: 404 errors or routes going to wrong domain

**Solution**:
1. Check `lib/constraints/subdomain_constraint.rb` exists
2. Verify it's being loaded (check `config/application.rb` has `config.autoload_paths << Rails.root.join('lib')`)
3. Check routes with: `rails routes --grep subdomain`

### Issue: SSL Certificate Errors

**Symptoms**: Browser shows SSL warnings for app subdomain

**Solution**:
1. Check Traefik logs: `kamal proxy logs`
2. Verify DNS is resolving correctly: `nslookup app.uxauditapp.com`
3. May need to restart Traefik: `kamal proxy reboot`
4. Let's Encrypt may be rate-limited (wait 1 hour and retry)

### Issue: Host Authorization Error

**Symptoms**: "Blocked host" error message

**Solution**:
1. Check `config/environments/production.rb` has all domains listed
2. Redeploy: `kamal deploy`

## Rollback Procedure

If something goes wrong, you can roll back:

```bash
# Roll back to previous version
kamal rollback

# Or redeploy a specific version
kamal deploy --version=<previous-version>
```

## Architecture Benefits

✅ **SEO Friendly**: Marketing site can be optimized for search engines
✅ **Clean Separation**: Public content separated from authenticated app
✅ **Professional**: Subdomain structure is standard for SaaS apps
✅ **Single Codebase**: No duplication, easier to maintain
✅ **Shared Sessions**: Seamless authentication experience
✅ **Scalable**: Can later separate into different servers if needed

## Future Enhancements

Consider these improvements:
- Add `www` to `app` redirect (standardize on one)
- Implement separate analytics tracking per subdomain
- Add rate limiting per subdomain
- Create subdomain-specific error pages
- Consider separate asset pipelines for marketing vs app

## Support

For issues or questions about the subdomain implementation:
1. Check this guide first
2. Review the git commit history for implementation details
3. Test locally with `/etc/hosts` configuration
4. Check Kamal and Traefik logs for deployment issues
