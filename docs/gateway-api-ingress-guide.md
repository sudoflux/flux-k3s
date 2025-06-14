# Gateway API Ingress Guide

## CRITICAL: No nginx ingress controller

This cluster uses **Cilium Gateway API** exclusively. There is NO nginx ingress controller deployed.

## Architecture

```yaml
GatewayClass (cilium)
    └── Gateway (main-gateway)
            └── HTTPRoute (your-service)
```

## Exposing a New Service

### 1. Create HTTPRoute

```yaml
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: my-service
  namespace: my-namespace
spec:
  parentRefs:
    - name: main-gateway
      namespace: networking
      sectionName: https  # Use 'http' for port 80
  hostnames:
    - "myapp.fletcherlabs.net"
  rules:
    - matches:
        - path:
            type: PathPrefix
            value: /
      backendRefs:
        - name: my-service
          port: 80
          weight: 1
```

### 2. Automatic HTTPS

- HTTP→HTTPS redirect is automatic for *.fletcherlabs.net
- Certificates are provisioned by cert-manager
- No additional annotations needed

### 3. Authentication (if needed)

Currently, authentication must be handled at the application level. Gateway API filters for auth are being investigated.

## Common Patterns

### Basic Service Exposure
See: `/clusters/k3s-home/apps/media/plex/httproute.yaml`

### Multiple Path Routing
```yaml
rules:
  - matches:
      - path:
          type: PathPrefix
          value: /api
    backendRefs:
      - name: api-service
        port: 8080
  - matches:
      - path:
          type: PathPrefix
          value: /
    backendRefs:
      - name: frontend-service
        port: 80
```

## Debugging

### Check HTTPRoute Status
```bash
kubectl get httproute -n <namespace> <name>
kubectl describe httproute -n <namespace> <name>
```

### Verify Gateway
```bash
kubectl get gateway -n networking main-gateway
kubectl describe gateway -n networking main-gateway
```

### Test Connectivity
```bash
# From inside cluster
curl -H "Host: myapp.fletcherlabs.net" http://192.168.10.224
```

## Migration from Ingress

If you see traditional Ingress resources:
1. Convert to HTTPRoute using the template above
2. Delete the old Ingress
3. Update kustomization.yaml to reference the HTTPRoute

## DO NOT

- Do not create nginx Ingress resources
- Do not look for ingress-nginx namespace (it doesn't exist)
- Do not use Ingress annotations (they won't work)