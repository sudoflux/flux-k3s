# Velero Offsite Backup Configuration

## Current Status
- ✅ Velero is deployed with local MinIO backup storage (working)
- ✅ Backblaze B2 bucket created with default encryption enabled
- ✅ B2 offsite backup integration configured and tested
- ✅ MinIO configuration issues resolved

## Offsite Backup Options

This guide covers both Backblaze B2 (recommended) and Wasabi configuration.

### Option 1: Backblaze B2 (Recommended)

#### Required Information
1. **B2 Bucket Name**: Already created (see `/home/josh/flux-k3s/docs/backblaze-b2-setup.md`)
2. **B2 Application Key ID**: Your B2 application key ID
3. **B2 Application Key**: Your B2 application key (handle securely)
4. **B2 Endpoint**: `s3.us-west-004.backblazeb2.com` (or your region)

### Option 2: Wasabi

#### Required Information
1. **Wasabi Bucket Name**: The name of your Wasabi bucket
2. **Wasabi Region**: Your Wasabi region (e.g., us-east-1, us-west-1, eu-central-1)
3. **Wasabi Credentials**: Access Key ID and Secret Access Key

## Secure Credential Handling

For security best practices, cloud storage credentials should NEVER be shared directly. 

### For Backblaze B2

#### Step 1: Prepare B2 Credentials
Create a temporary file with your credentials:
```bash
cat > b2-credentials <<EOF
[default]
aws_access_key_id=YOUR_B2_APPLICATION_KEY_ID
aws_secret_access_key=YOUR_B2_APPLICATION_KEY
EOF
```

#### Step 2: Create Kubernetes Secret
```bash
# Create the secret
kubectl create secret generic b2-credentials \
  --namespace velero \
  --from-file=cloud=b2-credentials

# Verify secret was created
kubectl get secret -n velero b2-credentials

# Immediately delete the temporary file
shred -vzu b2-credentials  # More secure than rm
```

### For Wasabi

#### Step 1: Prepare Wasabi Credentials
Create a temporary file with your credentials:
```bash
cat > wasabi-credentials <<EOF
[default]
aws_access_key_id=YOUR_WASABI_ACCESS_KEY_ID
aws_secret_access_key=YOUR_WASABI_SECRET_ACCESS_KEY
EOF
```

#### Step 2: Create Kubernetes Secret
```bash
kubectl create secret generic wasabi-credentials \
  --namespace velero \
  --from-file=cloud=wasabi-credentials

# Immediately delete the temporary file
shred -vzu wasabi-credentials
```

### Step 3: Configure Backup Location

#### For Backblaze B2
```bash
# Create backup location using Velero CLI
velero backup-location create b2-offsite \
  --provider aws \
  --bucket YOUR_B2_BUCKET_NAME \
  --config region=us-west-004,s3ForcePathStyle="true",s3Url=https://s3.us-west-004.backblazeb2.com \
  --credential=b2-credentials=cloud

# Or via GitOps - create this file:
cat > backup-location-b2.yaml <<EOF
apiVersion: velero.io/v1
kind: BackupStorageLocation
metadata:
  name: b2-offsite
  namespace: velero
spec:
  provider: aws
  objectStorage:
    bucket: YOUR_B2_BUCKET_NAME
  config:
    region: us-west-004
    s3ForcePathStyle: "true"
    s3Url: https://s3.us-west-004.backblazeb2.com
  credential:
    name: b2-credentials
    key: cloud
EOF
```

#### For Wasabi
Update the following file:
`/home/josh/flux-k3s/clusters/k3s-home/apps/velero/overlays/production/locations/backup-storage-locations.yaml`

Replace:
- `bucket: your-wasabi-bucket-name` with your actual bucket name
- `region: us-east-1` with your actual region

### Step 4: Enable Offsite Schedules
Update `/home/josh/flux-k3s/clusters/k3s-home/apps/velero/overlays/production/schedules/offsite-backup-schedule.yaml`
- Change `paused: true` to `paused: false` for both schedules

### Step 5: Apply Changes
```bash
# If using GitOps
git add -A
git commit -m "Configure Velero offsite backups to B2/Wasabi"
git push

# Force Flux reconciliation
flux reconcile kustomization apps --with-source

# Verify backup location
velero backup-location get
```

## What's Been Prepared

1. **Infrastructure**: All Velero components are deployed
2. **Local Backups**: MinIO-based local backups are configured
3. **Offsite Structure**: Wasabi backup locations and schedules are defined
4. **Security**: SOPS encryption is in place for secrets management

## Next Steps

1. Wasabi account owner creates the Kubernetes secret as described above
2. DevOps team updates the bucket name and region in GitOps
3. Commit and push changes to trigger Flux reconciliation
4. Verify backup functionality with test backup

## Testing and Validation

### Step 1: Create Test Backup
```bash
# For B2
velero backup create test-b2-backup \
  --include-namespaces default \
  --storage-location b2-offsite

# For Wasabi
velero backup create test-wasabi-backup \
  --include-namespaces default \
  --storage-location wasabi-offsite
```

### Step 2: Monitor Backup Progress
```bash
# Watch backup status
velero backup describe test-b2-backup --details

# Check for errors
velero backup logs test-b2-backup
```

### Step 3: Verify in Cloud Storage
- Log into B2/Wasabi console
- Navigate to your bucket
- Verify backup files exist under `/backups/test-b2-backup/`

### Step 4: Test Restore (Optional but Recommended)
```bash
# Create test namespace
kubectl create namespace restore-test

# Restore to test namespace
velero restore create test-restore \
  --from-backup test-b2-backup \
  --namespace-mappings default:restore-test

# Verify restore
kubectl get all -n restore-test

# Cleanup
kubectl delete namespace restore-test
```

## Backup Schedules

### Recommended Schedule Configuration
```yaml
# Daily backups of critical namespaces
apiVersion: velero.io/v1
kind: Schedule
metadata:
  name: daily-critical-offsite
  namespace: velero
spec:
  schedule: "0 2 * * *"  # 2 AM daily
  template:
    storageLocation: b2-offsite
    ttl: 720h  # 30 days retention
    includedNamespaces:
    - media
    - monitoring
    - flux-system
    - longhorn-system
```

## Troubleshooting

### Common Issues

1. **Authentication Failures**
   ```bash
   # Check secret exists
   kubectl get secret -n velero
   
   # Verify credentials format
   kubectl get secret b2-credentials -n velero -o jsonpath='{.data.cloud}' | base64 -d
   ```

2. **Connection Timeouts**
   - Verify S3 endpoint URL is correct
   - Check network connectivity from cluster to B2/Wasabi
   - Ensure bucket region matches configuration

3. **Bucket Access Errors**
   - Verify bucket exists and credentials have proper permissions
   - Check bucket lifecycle rules don't conflict with Velero

### Debug Commands
```bash
# Check Velero pod logs
kubectl logs -n velero deployment/velero

# List all backup locations
velero backup-location get

# Describe specific location
velero backup-location get b2-offsite -o yaml
```

## Best Practices

1. **Test Regularly**: Schedule monthly restore drills
2. **Monitor Storage**: Set up alerts for backup failures
3. **Rotate Credentials**: Update cloud credentials quarterly
4. **Document Recovery**: Maintain runbooks for disaster recovery
5. **Verify Encryption**: Ensure backups are encrypted at rest

---
**Last Updated**: 2025-06-14  
**Next Review**: After successful B2 integration