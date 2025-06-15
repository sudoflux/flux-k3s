# OAuth2/OIDC Integration Templates for Longhorn and Grafana

## Overview
This document provides template configurations for integrating Longhorn UI and Grafana with Authentik using OAuth2/OIDC authentication.

## 1. Grafana OAuth2 Integration

### Grafana HelmRelease Configuration
Add the following to the Grafana section in `kube-prometheus-stack` HelmRelease:

```yaml
# File: /home/josh/flux-k3s/clusters/k3s-home/apps/monitoring/kube-prometheus-stack/helm-release.yaml
# Add under spec.values.grafana:

grafana:
  # ... existing configuration ...
  
  # OAuth2 configuration for Authentik
  grafana.ini:
    server:
      domain: grafana.fletcherlabs.net
      root_url: "%(protocol)s://%(domain)s/"
    auth:
      disable_login_form: false
      oauth_auto_login: true
      oauth_allow_insecure_email_lookup: true
    auth.generic_oauth:
      enabled: true
      name: Authentik
      icon: signin
      allow_sign_up: true
      auto_login: false
      client_id: grafana
      client_secret: "${GRAFANA_OAUTH_CLIENT_SECRET}"  # From SOPS secret
      scopes: openid profile email groups
      empty_scopes: false
      auth_url: https://authentik.fletcherlabs.net/application/o/authorize/
      token_url: https://authentik.fletcherlabs.net/application/o/token/
      api_url: https://authentik.fletcherlabs.net/application/o/userinfo/
      signout_redirect_url: https://authentik.fletcherlabs.net/application/o/grafana/end-session/
      # Map user attributes
      login_attribute_path: preferred_username
      name_attribute_path: name
      email_attribute_path: email
      # Role mapping based on Authentik groups
      role_attribute_path: "contains(groups[*], 'grafana-admins') && 'Admin' || contains(groups[*], 'grafana-editors') && 'Editor' || 'Viewer'"
      allow_assign_grafana_admin: true
    security:
      allow_embedding: true
```

### Grafana OAuth2 Secret
Create a SOPS-encrypted secret for the OAuth2 client secret:

```yaml
# File: /home/josh/flux-k3s/clusters/k3s-home/apps/monitoring/kube-prometheus-stack/grafana-oauth-secret.yaml
apiVersion: v1
kind: Secret
metadata:
  name: grafana-oauth-credentials
  namespace: monitoring
type: Opaque
stringData:
  GRAFANA_OAUTH_CLIENT_SECRET: "<client-secret-from-authentik>"  # To be encrypted with SOPS
```

## 2. Longhorn UI OAuth2 Integration

Since Longhorn doesn't support native OAuth2, we'll use OAuth2-Proxy as a middleware.

### OAuth2-Proxy Deployment for Longhorn

```yaml
# File: /home/josh/flux-k3s/clusters/k3s-home/apps/longhorn/oauth2-proxy/helmrelease.yaml
apiVersion: helm.toolkit.fluxcd.io/v2beta1
kind: HelmRelease
metadata:
  name: longhorn-oauth2-proxy
  namespace: longhorn-system
spec:
  interval: 15m
  chart:
    spec:
      chart: oauth2-proxy
      version: "7.7.1"
      sourceRef:
        kind: HelmRepository
        name: oauth2-proxy
        namespace: flux-system
  values:
    config:
      clientID: longhorn
      clientSecret: "${LONGHORN_OAUTH_CLIENT_SECRET}"  # From SOPS secret
      cookieSecret: "${LONGHORN_COOKIE_SECRET}"  # Random 32-byte base64 string
      configFile: |-
        email_domains = [ "*" ]
        upstreams = [ "http://longhorn-frontend:80" ]
        provider = "oidc"
        oidc_issuer_url = "https://authentik.fletcherlabs.net/application/o/longhorn/"
        redirect_url = "https://longhorn.fletcherlabs.net/oauth2/callback"
        cookie_secure = true
        cookie_domains = [".fletcherlabs.net"]
        skip_provider_button = true
        pass_authorization_header = true
        pass_access_token = true
        pass_user_headers = true
        set_authorization_header = true
        set_xauthrequest = true
        
    ingress:
      enabled: false  # We'll use Gateway API
      
    resources:
      requests:
        cpu: 10m
        memory: 32Mi
      limits:
        cpu: 100m
        memory: 128Mi
        
    replicaCount: 2
    
    affinity:
      podAntiAffinity:
        preferredDuringSchedulingIgnoredDuringExecution:
          - weight: 100
            podAffinityTerm:
              labelSelector:
                matchExpressions:
                  - key: app.kubernetes.io/name
                    operator: In
                    values:
                      - oauth2-proxy
              topologyKey: kubernetes.io/hostname
```

### OAuth2-Proxy Secret for Longhorn

```yaml
# File: /home/josh/flux-k3s/clusters/k3s-home/apps/longhorn/oauth2-proxy/secret.yaml
apiVersion: v1
kind: Secret
metadata:
  name: longhorn-oauth2-proxy-secret
  namespace: longhorn-system
type: Opaque
stringData:
  LONGHORN_OAUTH_CLIENT_SECRET: "<client-secret-from-authentik>"  # To be encrypted with SOPS
  LONGHORN_COOKIE_SECRET: "<random-32-byte-base64>"  # Generate with: openssl rand -base64 32
```

### Updated Longhorn HTTPRoute with OAuth2-Proxy

```yaml
# File: /home/josh/flux-k3s/clusters/k3s-home/apps/longhorn/httproute.yaml
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: longhorn
  namespace: longhorn-system
spec:
  parentRefs:
    - name: cilium-gateway
      namespace: gateway
      sectionName: https-web
  hostnames:
    - "longhorn.fletcherlabs.net"
  rules:
    - matches:
        - path:
            type: PathPrefix
            value: /oauth2
      backendRefs:
        - name: longhorn-oauth2-proxy
          port: 80
    - matches:
        - path:
            type: PathPrefix
            value: /
      backendRefs:
        - name: longhorn-oauth2-proxy
          port: 80
```

### OAuth2-Proxy Service

```yaml
# File: /home/josh/flux-k3s/clusters/k3s-home/apps/longhorn/oauth2-proxy/service.yaml
apiVersion: v1
kind: Service
metadata:
  name: longhorn-oauth2-proxy
  namespace: longhorn-system
spec:
  selector:
    app.kubernetes.io/name: oauth2-proxy
    app.kubernetes.io/instance: longhorn-oauth2-proxy
  ports:
    - name: http
      port: 80
      targetPort: 4180
      protocol: TCP
```

## 3. Authentik Provider Configuration

### Grafana OAuth2 Provider in Authentik

1. Create a new OAuth2/OpenID Provider:
   - Name: `Grafana`
   - Client ID: `grafana`
   - Client Secret: Generate secure secret
   - Redirect URIs:
     ```
     https://grafana.fletcherlabs.net/login/generic_oauth
     ```
   - Signing Key: Use Authentik's default
   - Scopes: `openid`, `profile`, `email`, `groups`

2. Create an Application:
   - Name: `Grafana`
   - Slug: `grafana`
   - Provider: Select the Grafana provider created above
   - Policy engine mode: `any`

3. Create Groups for Role Mapping:
   - `grafana-admins` - Members get Admin role in Grafana
   - `grafana-editors` - Members get Editor role in Grafana
   - Default users get Viewer role

### Longhorn OAuth2 Provider in Authentik

1. Create a new OAuth2/OpenID Provider:
   - Name: `Longhorn`
   - Client ID: `longhorn`
   - Client Secret: Generate secure secret
   - Redirect URIs:
     ```
     https://longhorn.fletcherlabs.net/oauth2/callback
     ```
   - Signing Key: Use Authentik's default
   - Scopes: `openid`, `profile`, `email`

2. Create an Application:
   - Name: `Longhorn UI`
   - Slug: `longhorn`
   - Provider: Select the Longhorn provider created above
   - Policy engine mode: `any`
   - Launch URL: `https://longhorn.fletcherlabs.net`

## 4. Implementation Steps

### Prerequisites
1. Authentik must be deployed and accessible
2. DNS records configured for all domains
3. TLS certificates available (via cert-manager or Gateway API)

### Deployment Order

1. **Deploy OAuth2-Proxy HelmRepository** (if not exists):
   ```yaml
   # File: /home/josh/flux-k3s/clusters/k3s-home/apps/sources/oauth2-proxy.yaml
   apiVersion: source.toolkit.fluxcd.io/v1beta2
   kind: HelmRepository
   metadata:
     name: oauth2-proxy
     namespace: flux-system
   spec:
     interval: 1h
     url: https://oauth2-proxy.github.io/manifests
   ```

2. **Create Secrets**:
   - Encrypt OAuth2 secrets with SOPS
   - Apply to respective namespaces

3. **Update HelmReleases**:
   - Patch Grafana configuration in kube-prometheus-stack
   - Deploy OAuth2-Proxy for Longhorn

4. **Configure Authentik**:
   - Create OAuth2 providers
   - Create applications
   - Set up groups for role mapping

5. **Update HTTPRoutes**:
   - Ensure routes point to OAuth2-Proxy for Longhorn
   - Grafana routes remain unchanged

## 5. Testing

### Grafana OAuth2 Testing
1. Navigate to https://grafana.fletcherlabs.net
2. Click "Sign in with Authentik"
3. Authenticate with Authentik
4. Verify role assignment based on group membership
5. Test logout flow

### Longhorn OAuth2 Testing
1. Navigate to https://longhorn.fletcherlabs.net
2. Should redirect to Authentik automatically
3. Authenticate with Authentik
4. Should redirect back to Longhorn UI
5. Verify access to Longhorn features
6. Test logout flow

## 6. Troubleshooting

### Common Issues

1. **Redirect URI Mismatch**:
   - Ensure redirect URIs in Authentik match exactly
   - Check for trailing slashes
   - Verify HTTPS vs HTTP

2. **Cookie Issues**:
   - Ensure cookie domain matches
   - Check cookie security settings
   - Verify same-site settings

3. **Role Mapping Issues (Grafana)**:
   - Check group membership in Authentik
   - Verify role_attribute_path expression
   - Enable debug logging in Grafana

4. **OAuth2-Proxy Issues**:
   - Check logs: `kubectl logs -n longhorn-system -l app.kubernetes.io/name=oauth2-proxy`
   - Verify upstream URL is correct
   - Check network policies

### Debug Commands

```bash
# Check OAuth2-Proxy logs
kubectl logs -n longhorn-system -l app.kubernetes.io/name=oauth2-proxy

# Check Grafana OAuth2 logs
kubectl logs -n monitoring -l app.kubernetes.io/name=grafana | grep -i oauth

# Test Authentik connectivity
curl -I https://authentik.fletcherlabs.net/.well-known/openid-configuration

# Verify services
kubectl get svc -n longhorn-system
kubectl get httproute -n longhorn-system
```

## 7. Security Considerations

1. **Client Secrets**:
   - Always use SOPS encryption for secrets
   - Rotate secrets regularly
   - Use strong, randomly generated secrets

2. **Cookie Security**:
   - Always use secure cookies in production
   - Set appropriate same-site policies
   - Use HTTP-only cookies

3. **Network Policies**:
   - Restrict OAuth2-Proxy to only communicate with Authentik and upstream
   - Limit ingress to Gateway API only

4. **Session Management**:
   - Configure appropriate session timeouts
   - Implement proper logout flows
   - Consider refresh token rotation

## 8. Maintenance

### Regular Tasks
1. Review and rotate OAuth2 client secrets quarterly
2. Monitor OAuth2-Proxy resource usage
3. Check for OAuth2-Proxy helm chart updates
4. Review Authentik audit logs for suspicious activity
5. Update role mappings as organizational structure changes

### Backup Considerations
1. Backup Authentik provider configurations
2. Document all client IDs and redirect URIs
3. Keep encrypted backup of client secrets
4. Document group-to-role mappings