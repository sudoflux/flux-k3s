# Authentik Manual Setup Steps

## Quick Access
- **Authentik URL**: https://authentik.fletcherlabs.net
- **Admin Setup**: First-time access will redirect to initial setup

## Step 1: Initial Admin Setup

1. Open browser to: https://authentik.fletcherlabs.net
2. You'll be redirected to `/if/flow/initial-setup/`
3. Create admin account:
   - Username: `akadmin` (recommended)
   - Email: Your admin email
   - Password: Strong password (save securely!)
4. **IMPORTANT**: DO NOT enable 2FA (per CIO directive)
5. Click "Continue" to complete setup

## Step 2: Create OAuth2 Providers

### Login to Admin Interface
1. Navigate to: https://authentik.fletcherlabs.net/if/admin/
2. Login with admin credentials

### Create Grafana Provider
1. Go to: **Applications** → **Providers** → **Create**
2. Select: **OAuth2/OpenID Provider**
3. Configure:
   ```
   Name: grafana-provider
   Authorization flow: default-provider-authorization-implicit-consent
   Client type: Confidential
   Client ID: grafana
   Client Secret: (copy the generated secret)
   Redirect URIs: https://grafana.fletcherlabs.net/login/generic_oauth
   Scopes: openid profile email
   ```
4. Click **Save**

### Create Jellyfin Provider
1. Go to: **Applications** → **Providers** → **Create**
2. Select: **OAuth2/OpenID Provider**
3. Configure:
   ```
   Name: jellyfin-provider
   Authorization flow: default-provider-authorization-implicit-consent
   Client type: Confidential
   Client ID: jellyfin
   Client Secret: (copy the generated secret)
   Redirect URIs: https://jellyfin.fletcherlabs.net/sso/OID/redirect/authentik
   Scopes: openid profile email
   ```
4. Click **Save**

### Create Open-WebUI Provider
1. Go to: **Applications** → **Providers** → **Create**
2. Select: **OAuth2/OpenID Provider**
3. Configure:
   ```
   Name: open-webui-provider
   Authorization flow: default-provider-authorization-implicit-consent
   Client type: Confidential
   Client ID: open-webui
   Client Secret: (copy the generated secret)
   Redirect URIs: https://open-webui.fletcherlabs.net/auth/oauth/callback
   Scopes: openid profile email
   ```
4. Click **Save**

## Step 3: Create Applications

### Create Grafana Application
1. Go to: **Applications** → **Applications** → **Create**
2. Configure:
   ```
   Name: Grafana
   Slug: grafana
   Provider: grafana-provider
   Launch URL: https://grafana.fletcherlabs.net
   ```
3. Click **Save**

### Create Jellyfin Application
1. Go to: **Applications** → **Applications** → **Create**
2. Configure:
   ```
   Name: Jellyfin
   Slug: jellyfin
   Provider: jellyfin-provider
   Launch URL: https://jellyfin.fletcherlabs.net
   ```
3. Click **Save**

### Create Open-WebUI Application
1. Go to: **Applications** → **Applications** → **Create**
2. Configure:
   ```
   Name: Open WebUI
   Slug: open-webui
   Provider: open-webui-provider
   Launch URL: https://open-webui.fletcherlabs.net
   ```
3. Click **Save**

## Step 4: Apply OAuth2 Configurations

### Update Grafana
```bash
# Create secret with OAuth credentials
kubectl create secret generic grafana-oauth \
  --namespace monitoring \
  --from-literal=client-id=grafana \
  --from-literal=client-secret=YOUR_GRAFANA_SECRET_HERE

# Update Grafana helm values and redeploy
# Add to your Grafana values:
cat <<EOF >> /tmp/grafana-oauth-values.yaml
grafana.ini:
  auth.generic_oauth:
    enabled: true
    name: Authentik
    allow_sign_up: true
    client_id: grafana
    client_secret: \${GRAFANA_OAUTH_CLIENT_SECRET}
    scopes: openid profile email
    auth_url: https://authentik.fletcherlabs.net/application/o/authorize/
    token_url: https://authentik.fletcherlabs.net/application/o/token/
    api_url: https://authentik.fletcherlabs.net/application/o/userinfo/
    role_attribute_path: contains(groups[*], 'Grafana Admins') && 'Admin' || 'Viewer'
EOF

# Apply the update (example, adjust based on your deployment method)
helm upgrade grafana grafana/grafana -n monitoring --reuse-values -f /tmp/grafana-oauth-values.yaml
```

### Configure Jellyfin
1. Login to Jellyfin admin dashboard
2. Navigate to: **Dashboard** → **Plugins** → **SSO Authentication**
3. Add OAuth provider:
   ```
   Provider Name: Authentik
   Client ID: jellyfin
   Client Secret: YOUR_JELLYFIN_SECRET_HERE
   Authorization URL: https://authentik.fletcherlabs.net/application/o/authorize/
   Token URL: https://authentik.fletcherlabs.net/application/o/token/
   User Info URL: https://authentik.fletcherlabs.net/application/o/userinfo/
   ```

### Update Open-WebUI
```bash
# Create secret with OAuth credentials
kubectl create secret generic open-webui-oauth \
  --namespace open-webui \
  --from-literal=client-id=open-webui \
  --from-literal=client-secret=YOUR_OPENWEBUI_SECRET_HERE

# Update deployment with OAuth environment variables
kubectl set env deployment/open-webui -n open-webui \
  OAUTH_ENABLED="true" \
  OAUTH_PROVIDER_NAME="Authentik" \
  OAUTH_CLIENT_ID="open-webui" \
  OAUTH_CLIENT_SECRET="YOUR_OPENWEBUI_SECRET_HERE" \
  OAUTH_AUTHORIZATION_URL="https://authentik.fletcherlabs.net/application/o/authorize/" \
  OAUTH_TOKEN_URL="https://authentik.fletcherlabs.net/application/o/token/" \
  OAUTH_USERINFO_URL="https://authentik.fletcherlabs.net/application/o/userinfo/" \
  OAUTH_SCOPES="openid profile email"
```

## Step 5: Verification

### Test Grafana SSO
1. Navigate to: https://grafana.fletcherlabs.net
2. Click "Sign in with Authentik"
3. Should redirect to Authentik login
4. After login, should return to Grafana authenticated

### Test Jellyfin SSO
1. Navigate to: https://jellyfin.fletcherlabs.net
2. Click SSO login option
3. Should redirect to Authentik
4. After login, should return to Jellyfin

### Test Open-WebUI SSO
1. Navigate to: https://open-webui.fletcherlabs.net
2. Click "Sign in with Authentik"
3. Should redirect to Authentik
4. After login, should return to Open-WebUI

### Verify Authentik Logs
```bash
# Check Authentik logs for any errors
kubectl logs -n authentik -l app.kubernetes.io/name=authentik --tail=50

# Check specific service logs if SSO fails
kubectl logs -n monitoring deployment/grafana --tail=50
```

## Quick Reference URLs

- **Authentik Admin**: https://authentik.fletcherlabs.net/if/admin/
- **Provider List**: https://authentik.fletcherlabs.net/if/admin/#/core/providers
- **Application List**: https://authentik.fletcherlabs.net/if/admin/#/core/applications
- **User List**: https://authentik.fletcherlabs.net/if/admin/#/identity/users
- **Flows**: https://authentik.fletcherlabs.net/if/admin/#/flow/flows

## Troubleshooting

### Can't access Authentik
```bash
kubectl get pods -n authentik
kubectl get httproute -n authentik
kubectl describe httproute authentik -n authentik
```

### OAuth redirect errors
- Verify redirect URIs match exactly (including trailing slashes)
- Check client ID/secret are correctly copied
- Ensure services are restarted after configuration changes

### Users can't login
- Check user exists in Authentik
- Verify application access permissions
- Check Authentik event logs in admin interface

## Notes
- Keep all client secrets secure
- 2FA remains disabled per policy
- For services without native OAuth support, use OAuth2 Proxy