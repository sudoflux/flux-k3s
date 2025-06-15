# OAuth2 Implementation Guide for Longhorn and Grafana

## Quick Start

This guide provides step-by-step instructions to enable OAuth2 authentication for Longhorn UI and Grafana using Authentik.

## Prerequisites

- Authentik is deployed and accessible at https://authentik.fletcherlabs.net
- Admin access to Authentik
- SOPS configured for secret encryption

## Implementation Steps

### 1. Add OAuth2-Proxy Helm Repository

```bash
# Add to sources kustomization
cd /home/josh/flux-k3s/clusters/k3s-home/apps/sources
# Edit kustomization.yaml and add:
# - oauth2-proxy.yaml

# Commit and push
git add oauth2-proxy.yaml
git commit -m "Add OAuth2-Proxy helm repository"
git push
```

### 2. Configure Authentik Providers

#### Grafana Provider

1. Log into Authentik at https://authentik.fletcherlabs.net
2. Navigate to Applications → Providers → Create
3. Select "OAuth2/OpenID Provider"
4. Configure:
   - Name: `Grafana`
   - Authorization flow: `implicit-consent`
   - Client type: `Confidential`
   - Client ID: `grafana`
   - Client Secret: Generate and save securely
   - Redirect URIs: `https://grafana.fletcherlabs.net/login/generic_oauth`
   - Signing Key: `authentik Self-signed Certificate`
   - Scopes: Select `openid`, `profile`, `email`, `groups`

5. Create Application:
   - Name: `Grafana`
   - Slug: `grafana`
   - Provider: Select "Grafana" provider
   - Policy engine mode: `any`

6. Create Groups (optional):
   - `grafana-admins` - For admin access
   - `grafana-editors` - For editor access

#### Longhorn Provider

1. Navigate to Applications → Providers → Create
2. Select "OAuth2/OpenID Provider"
3. Configure:
   - Name: `Longhorn`
   - Authorization flow: `implicit-consent`
   - Client type: `Confidential`
   - Client ID: `longhorn`
   - Client Secret: Generate and save securely
   - Redirect URIs: `https://longhorn.fletcherlabs.net/oauth2/callback`
   - Signing Key: `authentik Self-signed Certificate`
   - Scopes: Select `openid`, `profile`, `email`

4. Create Application:
   - Name: `Longhorn UI`
   - Slug: `longhorn`
   - Provider: Select "Longhorn" provider
   - Policy engine mode: `any`
   - Launch URL: `https://longhorn.fletcherlabs.net`

### 3. Prepare Secrets

#### Generate Cookie Secret for Longhorn OAuth2-Proxy

```bash
# Generate a secure cookie secret
openssl rand -base64 32
```

#### Update Secret Files

1. **Grafana OAuth Secret**:
   ```bash
   cd /home/josh/flux-k3s/clusters/k3s-home/apps/monitoring/kube-prometheus-stack
   # Edit grafana-oauth-secret.yaml
   # Replace PLACEHOLDER_TO_BE_REPLACED with the client secret from Authentik
   
   # Encrypt with SOPS
   sops -e -i grafana-oauth-secret.yaml
   ```

2. **Longhorn OAuth2-Proxy Secret**:
   ```bash
   cd /home/josh/flux-k3s/clusters/k3s-home/apps/longhorn/oauth2-proxy
   # Edit secret.yaml
   # Replace LONGHORN_OAUTH_CLIENT_SECRET with the client secret from Authentik
   # Replace LONGHORN_COOKIE_SECRET with the generated cookie secret
   
   # Encrypt with SOPS
   sops -e -i secret.yaml
   ```

### 4. Deploy OAuth2 Components

#### For Longhorn

```bash
# Add OAuth2-Proxy to Longhorn kustomization
cd /home/josh/flux-k3s/clusters/k3s-home/apps/longhorn
# Edit kustomization.yaml (or create overlays/production/kustomization.yaml)
# Add under resources:
# - oauth2-proxy

# Commit changes
git add -A
git commit -m "Add OAuth2-Proxy for Longhorn authentication"
git push

# Wait for reconciliation or force it
flux reconcile kustomization longhorn --with-source
```

#### For Grafana

```bash
# Apply the OAuth2 patch to Grafana
cd /home/josh/flux-k3s/clusters/k3s-home/apps/monitoring/kube-prometheus-stack

# Option 1: Direct patch (temporary)
kubectl patch helmrelease kube-prometheus-stack -n monitoring --type merge --patch-file grafana-oauth2-patch.yaml

# Option 2: Update HelmRelease (permanent)
# Edit helm-release.yaml and add the OAuth2 configuration under spec.values.grafana
# Then commit and push

git add -A
git commit -m "Enable OAuth2 authentication for Grafana"
git push
```

### 5. Update HTTPRoute for Longhorn

```bash
# Apply the new HTTPRoute that uses OAuth2-Proxy
kubectl apply -f /home/josh/flux-k3s/clusters/k3s-home/apps/longhorn/oauth2-proxy/httproute-patch.yaml
```

### 6. Verify Deployments

```bash
# Check OAuth2-Proxy for Longhorn
kubectl get pods -n longhorn-system -l app.kubernetes.io/name=oauth2-proxy
kubectl get svc -n longhorn-system longhorn-oauth2-proxy

# Check Grafana restart
kubectl rollout status deployment/kube-prometheus-stack-grafana -n monitoring

# Check HTTPRoutes
kubectl get httproute -A
```

### 7. Test Authentication

#### Test Grafana
1. Navigate to https://grafana.fletcherlabs.net
2. You should see "Sign in with Authentik" button
3. Click and authenticate with Authentik
4. Verify you're logged into Grafana
5. Check role assignment if using groups

#### Test Longhorn
1. Navigate to https://longhorn.fletcherlabs.net
2. Should automatically redirect to Authentik
3. Authenticate with Authentik
4. Should redirect back to Longhorn UI
5. Verify you can access Longhorn features

### 8. Troubleshooting

#### Check Logs

```bash
# OAuth2-Proxy logs
kubectl logs -n longhorn-system -l app.kubernetes.io/name=oauth2-proxy

# Grafana logs
kubectl logs -n monitoring -l app.kubernetes.io/name=grafana | grep -i oauth

# Check events
kubectl events -n longhorn-system
kubectl events -n monitoring
```

#### Common Issues

1. **"Invalid redirect URI"**
   - Double-check redirect URIs in Authentik match exactly
   - Ensure HTTPS is used
   - Check for trailing slashes

2. **"Cookie not found"**
   - Verify cookie domain in OAuth2-Proxy config
   - Check browser developer tools for cookie issues

3. **"403 Forbidden"**
   - Check OAuth2-Proxy upstream configuration
   - Verify service names and ports

4. **Grafana "Invalid username or password"**
   - Ensure `auth.generic_oauth.enabled: true`
   - Check client ID and secret
   - Verify API URLs are correct

## Rollback Procedure

If issues occur:

### Rollback Longhorn
```bash
# Remove OAuth2-Proxy HTTPRoute
kubectl delete httproute longhorn -n longhorn-system

# Re-apply original HTTPRoute
kubectl apply -f <original-httproute.yaml>

# Remove OAuth2-Proxy
kubectl delete helmrelease longhorn-oauth2-proxy -n longhorn-system
```

### Rollback Grafana
```bash
# Remove OAuth configuration
kubectl patch helmrelease kube-prometheus-stack -n monitoring --type json -p='[{"op": "remove", "path": "/spec/values/grafana/grafana.ini/auth.generic_oauth"}]'

# Or restore original HelmRelease
kubectl apply -f <original-helmrelease.yaml>
```

## Security Notes

1. Always use SOPS encryption for secrets
2. Rotate OAuth2 client secrets regularly
3. Monitor authentication logs in Authentik
4. Use HTTPS for all communications
5. Configure proper RBAC after authentication

## Next Steps

After successful implementation:
1. Document client IDs and provider configurations
2. Create runbooks for common issues
3. Set up monitoring for OAuth2-Proxy
4. Plan for secret rotation schedule
5. Consider implementing more granular authorization policies in Authentik