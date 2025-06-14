# SSO Configuration - Pending Authentik Deployment

## Current Status
- Authentik deployment blocked by infrastructure dependencies
- Target applications (Grafana, Jellyfin, Open-WebUI) are running and accessible
- SSO configuration will be applied once Authentik is operational

## Temporary Workaround
Until Authentik is deployed, applications continue using their native authentication:
- **Grafana**: Default admin credentials at https://grafana.fletcherlabs.net
- **Jellyfin**: Local user accounts at https://jellyfin.fletcherlabs.net  
- **Open-WebUI**: Local authentication at https://ai.fletcherlabs.net

## Dependency Resolution Path
The blocking dependency chain is:
```
auth → infra-runtime → infra-intel-gpu → infra-nfd
```

To resolve:
1. Fix Node Feature Discovery (infra-nfd) deployment
2. This will cascade fix intel-gpu, runtime, and finally auth

## Next Steps
Once Authentik is deployed:
1. Access https://authentik.fletcherlabs.net
2. Create admin account (NO 2FA per directive)
3. Configure OAuth2 providers for each application
4. Update application configurations with OAuth2 settings
5. Test SSO flow for each application

## Configuration Templates Ready
All OAuth2 configuration templates are documented in `/docs/authentik-setup.md` and ready to apply once Authentik is operational.