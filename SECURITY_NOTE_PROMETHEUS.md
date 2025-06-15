# SECURITY WARNING: Prometheus Exposed Without Authentication

## Current Status
Prometheus is currently exposed without any authentication mechanism. This poses a security risk as sensitive metrics and system information are accessible without authorization.

## Recommended Action
Once Authentik is configured and operational, Prometheus should be secured using OAuth2-Proxy, similar to the implementation for Longhorn.

## Implementation Steps (To Be Done)
1. Configure OAuth2-Proxy for Prometheus
2. Set up Authentik application for Prometheus access
3. Update Prometheus ingress to route through OAuth2-Proxy
4. Test authentication flow

## Priority
**HIGH** - This should be addressed as soon as Authentik is available to prevent unauthorized access to system metrics.

## Reference
See Longhorn's OAuth2-Proxy configuration as a template for implementation.