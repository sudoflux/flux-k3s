# Velero Offsite Backup Configuration

## Current Status
- Velero is deployed with local MinIO backup storage (working)
- Wasabi offsite backup infrastructure is prepared but awaiting credentials
- Fixed MinIO deployment to use correct secret references

## Required Information for Offsite Backups

To complete the offsite backup configuration to Wasabi, the following information is needed:

1. **Wasabi Bucket Name**: The name of your Wasabi bucket
2. **Wasabi Region**: Your Wasabi region (e.g., us-east-1, us-west-1, eu-central-1)
3. **Wasabi Credentials**: Access Key ID and Secret Access Key (see secure handling below)

## Secure Credential Handling

For security best practices, the Wasabi credentials should NEVER be shared directly. Instead:

### Step 1: Prepare Credentials (Wasabi Account Owner)
Create a temporary file with your credentials:
```bash
cat > wasabi-credentials <<EOF
[default]
aws_access_key_id=YOUR_WASABI_ACCESS_KEY_ID
aws_secret_access_key=YOUR_WASABI_SECRET_ACCESS_KEY
EOF
```

### Step 2: Create Kubernetes Secret (Wasabi Account Owner)
```bash
kubectl create secret generic wasabi-credentials \
  --namespace velero \
  --from-file=cloud=wasabi-credentials

# Immediately delete the temporary file
rm wasabi-credentials
```

### Step 3: Update Configuration (DevOps Team)
Once the secret is created, update the following file:
`/home/josh/flux-k3s/clusters/k3s-home/apps/velero/overlays/production/locations/backup-storage-locations.yaml`

Replace:
- `bucket: your-wasabi-bucket-name` with your actual bucket name
- `region: us-east-1` with your actual region

### Step 4: Enable Offsite Schedules
Update `/home/josh/flux-k3s/clusters/k3s-home/apps/velero/overlays/production/schedules/offsite-backup-schedule.yaml`
- Change `paused: true` to `paused: false` for both schedules

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

## Testing

Once configured, test with:
```bash
velero backup create test-wasabi-backup \
  --include-namespaces default \
  --storage-location wasabi-offsite

velero backup describe test-wasabi-backup
```