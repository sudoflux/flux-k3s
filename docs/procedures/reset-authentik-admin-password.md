# Authentik Admin Password Reset Procedure

**CRITICAL**: This procedure is required to secure Prometheus which is currently exposed without authentication.

## Prerequisites

- kubectl access to the cluster
- PostgreSQL password: `TOtREQVNTNc4149HvuM6GQxrNK7s7ftv`
- Database pod: `authentik-postgresql-0`
- Namespace: `authentik`

## Method 1: Reset akadmin Password via Django Shell

### Step 1: Access the Authentik Worker Pod

```bash
# Get the authentik worker pod name
kubectl get pods -n authentik | grep worker

# Access the worker pod (replace with actual pod name)
kubectl exec -it -n authentik authentik-worker-<hash> -- /bin/bash
```

### Step 2: Reset Password via Django Shell

```bash
# Inside the pod, run the Django shell
ak shell

# In the Python shell, execute:
from authentik.core.models import User
akadmin = User.objects.get(username="akadmin")
akadmin.set_password("YourNewSecurePassword123!")
akadmin.save()
exit()
```

### Step 3: Exit the Pod

```bash
exit
```

## Method 2: Direct Database Password Reset

### Step 1: Access PostgreSQL Pod

```bash
kubectl exec -it -n authentik authentik-postgresql-0 -- /bin/bash
```

### Step 2: Connect to PostgreSQL

```bash
# Connect as postgres user
PGPASSWORD=TOtREQVNTNc4149HvuM6GQxrNK7s7ftv psql -U postgres -d authentik
```

### Step 3: Find and Update akadmin User

```sql
-- First, verify the user exists
SELECT pk, username, email, is_active, is_superuser FROM authentik_core_user WHERE username = 'akadmin';

-- If the user doesn't exist, check all admin users
SELECT pk, username, email, is_active, is_superuser FROM authentik_core_user WHERE is_superuser = true;

-- Note the pk (primary key) of the akadmin user for the next steps
```

### Step 4: Create Temporary Admin User (Alternative)

If you cannot reset the akadmin password directly, create a temporary admin:

```sql
-- Insert a new superuser (adjust email as needed)
INSERT INTO authentik_core_user (
    username, 
    email, 
    is_active, 
    is_superuser, 
    is_staff,
    name,
    uuid,
    date_joined
) VALUES (
    'temp-admin', 
    'temp-admin@fletcherlabs.net', 
    true, 
    true, 
    true,
    'Temporary Admin',
    gen_random_uuid(),
    NOW()
) RETURNING pk;

-- Note the returned pk value for password setting
```

### Step 5: Exit PostgreSQL

```sql
\q
exit
```

## Method 3: Using Authentik CLI (ak) Command

### Step 1: Access Server Pod

```bash
# Get the authentik server pod name
kubectl get pods -n authentik | grep server

# Access the server pod
kubectl exec -it -n authentik authentik-server-<hash> -- /bin/bash
```

### Step 2: Create Recovery Token

```bash
# Generate a recovery token
ak create_recovery_link akadmin

# This will output a recovery URL like:
# https://authentik.fletcherlabs.net/if/flow/initial-setup/?token=<recovery-token>
```

### Step 3: Use Recovery Link

1. Copy the recovery link
2. Open in a web browser
3. Set a new password for akadmin

## Post-Reset Actions

### 1. Verify Login

```bash
# Test the new credentials by accessing Authentik
curl -I https://authentik.fletcherlabs.net
```

### 2. Secure Prometheus Immediately

Once you have admin access:

1. Log into Authentik at https://authentik.fletcherlabs.net
2. Navigate to Applications
3. Create or verify the Prometheus OAuth2 application
4. Ensure OAuth2-Proxy is properly configured

### 3. Update Secrets (if needed)

If you created a temporary admin, remember to:
- Use it to reset the akadmin password through the UI
- Delete the temporary admin account
- Update any stored credentials in your password manager

## Troubleshooting

### If pods are not running:

```bash
# Check pod status
kubectl get pods -n authentik

# Check logs
kubectl logs -n authentik authentik-server-<hash>
kubectl logs -n authentik authentik-worker-<hash>
kubectl logs -n authentik authentik-postgresql-0
```

### If database connection fails:

```bash
# Verify PostgreSQL service
kubectl get svc -n authentik | grep postgresql

# Check PostgreSQL pod logs
kubectl logs -n authentik authentik-postgresql-0
```

### If Authentik won't start after password reset:

```bash
# Restart Authentik pods
kubectl rollout restart deployment -n authentik authentik-server
kubectl rollout restart deployment -n authentik authentik-worker
```

## Security Notes

- Choose a strong password (minimum 12 characters, mixed case, numbers, symbols)
- Document the new password in your secure password manager
- Consider enabling MFA on the akadmin account immediately after reset
- Review all OAuth2 applications and their configurations
- Check audit logs for any unauthorized access

## Quick Emergency Script

For absolute emergency, here's a one-liner to create a recovery link:

```bash
kubectl exec -it -n authentik $(kubectl get pods -n authentik -l app.kubernetes.io/component=server -o jsonpath='{.items[0].metadata.name}') -- ak create_recovery_link akadmin
```

This will output a recovery URL you can use immediately.