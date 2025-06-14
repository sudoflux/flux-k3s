# Backblaze B2 Setup for Velero

## Creating the B2 Bucket

1. **Log into Backblaze B2 Console**

2. **Create a New Bucket**:
   - Bucket Name: `fletcherlabs-velero-backups` (or your preferred name)
   - **Files in Bucket**: Private
   - **Default Encryption**: ✅ **Enable** (Server-Side Encryption)
   - **Object Lock**: ✅ **Enable** (for ransomware protection)
     - Retention Mode: Compliance
     - Retention Period: 30 days (adjust based on your needs)

3. **Create Application Key**:
   - Key Name: `velero-backup-key`
   - Type of Access: **Read and Write**
   - Allow List All Bucket Names: **No**
   - Allow Access to Bucket(s): Select only your Velero bucket
   - File Name Prefix: Leave blank
   - Duration: No expiration

4. **Save These Values**:
   - keyID (this is your access key)
   - applicationKey (this is your secret key - shown only once!)
   - S3 Endpoint (found in bucket details, e.g., `s3.us-west-004.backblazeb2.com`)
   - Bucket Region (e.g., `us-west-004`)

## Velero Configuration

### Update Plugin Version (IMPORTANT!)
Due to compatibility issues with B2, we need to downgrade the AWS plugin to v1.8.2:

```yaml
# In helm-release.yaml
initContainers:
- name: velero-plugin-for-aws
  image: velero/velero-plugin-for-aws:v1.8.2  # Changed from v1.10.0
  imagePullPolicy: IfNotPresent
  volumeMounts:
  - mountPath: /target
    name: plugins
```

### Create B2 Credentials Secret

```yaml
# File: b2-secret.yaml
apiVersion: v1
kind: Secret
metadata:
  name: b2-credentials
  namespace: velero
type: Opaque
stringData:
  cloud: |
    [default]
    aws_access_key_id=YOUR_B2_KEY_ID
    aws_secret_access_key=YOUR_B2_APPLICATION_KEY
```

Remember to encrypt this with SOPS before committing!

### Update Backup Storage Location

```yaml
# In backup-storage-locations.yaml
apiVersion: velero.io/v1
kind: BackupStorageLocation
metadata:
  name: b2-offsite
  namespace: velero
spec:
  provider: aws
  objectStorage:
    bucket: fletcherlabs-velero-backups  # Your B2 bucket name
  config:
    region: us-west-004  # Your B2 region
    s3ForcePathStyle: "true"
    s3Url: https://s3.us-west-004.backblazeb2.com  # Your B2 endpoint
    checksumAlgorithm: ""  # CRITICAL: Empty string to avoid B2 compatibility issues
    objectLockEnabled: "true"  # Enable object lock support
  credential:
    name: b2-credentials
    key: cloud
  default: false
```

## Security Best Practices Implemented

1. **Server-Side Encryption**: Enabled by default on the bucket
2. **Object Lock**: Protects against accidental deletion and ransomware
3. **Least Privilege**: Application key restricted to single bucket
4. **No Public Access**: Bucket is private

## Optional: Client-Side Encryption with Restic

For maximum security (data encrypted before leaving cluster):

```yaml
# In your backup or schedule spec
spec:
  defaultVolumesToRestic: true  # Encrypt PV data
  # OR
  defaultVolumesToFsBackup: true  # Use newer File System Backup
```

## Testing the Configuration

```bash
# Create a test backup
velero backup create test-b2-backup \
  --storage-location b2-offsite \
  --include-namespaces default

# Check backup status
velero backup describe test-b2-backup

# List backups in B2
velero backup get --storage-location b2-offsite
```

## Monitoring Considerations

- Set up alerts for backup failures
- Monitor B2 storage costs (especially with Object Lock)
- Regular restore tests to verify backup integrity