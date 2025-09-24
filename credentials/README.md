# Credentials Setup

This directory contains sensitive credential files that are required for the CPAL Evictions project but should NOT be committed to the repository.

## Required Files

### SFTP Access

**File**: `sftp/evictionsuser`
**Purpose**: SSH private key for accessing AWS SFTP server
**Source**: Copy from your local credentials directory

#### Setup Instructions

1. **Copy the SSH key file:**
   ```bash
   # Copy from your local credentials directory
   cp /path/to/your/keyfile credentials/sftp/evictionsuser
   ```

2. **Set proper permissions:**
   ```bash
   chmod 600 credentials/sftp/evictionsuser
   ```

3. **Verify the file exists:**
   ```bash
   ls -la credentials/sftp/evictionsuser
   ```

## Security Notes

- **Never commit these files** to the repository
- **Keep credentials secure** and don't share them
- **Use proper file permissions** (600 for SSH keys)
- **Rotate credentials regularly** as per security policy

## Troubleshooting

### SSH Key Not Found
```bash
# Check if file exists
ls -la credentials/sftp/evictionsuser

# Check file permissions
ls -la credentials/sftp/evictionsuser
# Should show: -rw------- (600 permissions)
```

### Permission Denied
```bash
# Fix file permissions
chmod 600 credentials/sftp/evictionsuser
```

### SFTP Connection Failed
```bash
# Test SFTP connection
./docker/docker-dev.sh sftp-mount
```

## File Structure

```
credentials/
├── README.md                    # This file
└── sftp/
    └── evictionsuser           # SSH private key for SFTP access
```

## Getting Credentials

If you don't have the required credentials:

1. **Contact the project administrator** for access
2. **Request credentials** through proper channels
3. **Follow security protocols** for credential distribution
4. **Set up credentials** as described above

## Alternative Setup

If you prefer to use your own credentials directory structure, you can modify the Docker Compose files to point to your local path:

```yaml
# In docker-compose.yml, change:
- ../credentials/sftp/evictionsuser:/root/.ssh/evictionsuser:ro
# To:
- /path/to/your/credentials/SFTP_keys/evictions/evictionsuser:/root/.ssh/evictionsuser:ro
```

However, using the repository structure is recommended for consistency across development environments.
