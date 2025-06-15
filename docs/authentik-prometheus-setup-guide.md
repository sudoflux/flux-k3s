# Authentik Setup Guide for Prometheus OAuth2

## Current Status
- **Date**: June 15, 2025 (Evening)
- **Critical Issue**: Prometheus is exposed without authentication
- **OAuth2-Proxy**: Deployed and ready (pending Authentik config)

## Step-by-Step Instructions

### Step 1: Access Authentik Initial Setup
1. Open browser to: https://authentik.fletcherlabs.net
2. You should be redirected to initial setup page
3. Create admin account:
   - Username: `akadmin`
   - Email: Your admin email
   - Password: Strong password (save it!)
   - **DO NOT enable 2FA** (per CIO directive)

### Step 2: Create Prometheus OAuth2 Provider
1. Login to Authentik admin: https://authentik.fletcherlabs.net/if/admin/
2. Navigate to: **Applications** → **Providers** → **Create**
3. Select: **OAuth2/OpenID Provider**
4. Configure with these exact settings:
   ```
   Name: prometheus-provider
   Authorization flow: default-provider-authorization-implicit-consent
   Client type: Confidential
   Client ID: prometheus
   Client Secret: [COPY THE GENERATED SECRET - YOU'LL NEED IT]
   Redirect URIs: https://prometheus.fletcherlabs.net/oauth2/callback
   Scopes: openid profile email
   ```
5. Click **Save**

### Step 3: Create Prometheus Application
1. Go to: **Applications** → **Applications** → **Create**
2. Configure:
   ```
   Name: Prometheus
   Slug: prometheus
   Provider: prometheus-provider
   Launch URL: https://prometheus.fletcherlabs.net
   ```
3. Click **Save**

### Step 4: Update OAuth2-Proxy Secret
After creating the provider in Authentik, you need to update the OAuth2-Proxy secret with the actual client secret:

```bash
# Decrypt the secret file
sops clusters/k3s-home/apps/monitoring/oauth2-proxy-prometheus/secret.yaml

# Update the OAUTH2_PROXY_CLIENT_SECRET with the value from Authentik
# Save and exit

# The file will be automatically re-encrypted
```

### Step 5: Apply the Configuration
```bash
# Commit and push changes
git add -A
git commit -m "feat: add OAuth2-Proxy for Prometheus security"
git push

# Wait for Flux to reconcile (or force it)
flux reconcile kustomization apps --with-source

# Check OAuth2-Proxy deployment
kubectl get pods -n monitoring -l app.kubernetes.io/name=oauth2-proxy
```

### Step 6: Apply the Updated HTTPRoute
Once OAuth2-Proxy is running:

```bash
# Apply the new HTTPRoute that routes through OAuth2-Proxy
kubectl apply -f clusters/k3s-home/apps/monitoring/oauth2-proxy-prometheus/prometheus-httproute-patch.yaml

# Verify the route was updated
kubectl get httproute prometheus -n monitoring -o yaml
```

### Step 7: Verify Authentication
1. Open incognito/private browser window
2. Navigate to: https://prometheus.fletcherlabs.net
3. You should be redirected to Authentik login
4. Login with your Authentik credentials
5. You should be redirected back to Prometheus

### Troubleshooting

#### OAuth2-Proxy Logs
```bash
kubectl logs -n monitoring -l app.kubernetes.io/name=oauth2-proxy --tail=50
```

#### Common Issues
1. **Redirect loop**: Check that redirect URI in Authentik matches exactly
2. **403 Forbidden**: Verify cookie domain is set to `.fletcherlabs.net`
3. **Connection refused**: Ensure OAuth2-Proxy pods are running

#### Rollback if Needed
If something goes wrong and you need immediate access to Prometheus:
```bash
# Revert to direct access (TEMPORARY ONLY!)
kubectl apply -f clusters/k3s-home/apps/monitoring/kube-prometheus-stack/prometheus-httproute.yaml
```

## Next Steps
After Prometheus is secured:
1. Configure OAuth2 for Longhorn UI
2. Enhance Grafana OAuth2 integration
3. Document all client IDs for future reference