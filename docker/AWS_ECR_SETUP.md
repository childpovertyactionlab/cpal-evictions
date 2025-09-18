# AWS ECR Access Setup for Developers

This guide explains how to set up AWS IAM users with minimal permissions to access the tumblR Docker images from your ECR repository.

## Overview

The policy allows developers to:
- ✅ Pull Docker images from your ECR repository
- ✅ Authenticate with ECR
- ❌ Push images (read-only access)
- ❌ Delete images or repositories
- ❌ Access other AWS services

## IAM Policy

The policy is defined in `aws-ecr-policy.json` and includes:

1. **ECR Login**: `ecr:GetAuthorizationToken` - Required for Docker login
2. **Pull Images**: `ecr:BatchCheckLayerAvailability`, `ecr:GetDownloadUrlForLayer`, `ecr:BatchGetImage` - Required to download images
3. **List Repositories**: `ecr:DescribeRepositories`, `ecr:ListImages` - Helpful for discovering available images

## Setup Instructions

### Option 1: AWS Console (Recommended for non-technical users)

1. **Create IAM User**:
   - Go to AWS Console → IAM → Users → Create user
   - Username: `cpal-evictions-developer` (or similar)
   - Access type: Programmatic access (for AWS CLI/API)

2. **Attach Policy**:
   - Choose "Attach policies directly"
   - Click "Create policy"
   - Switch to JSON tab
   - Copy the contents of `aws-ecr-policy.json`
   - Name: `CPAL-Evictions-ECR-ReadOnly`
   - Create policy and attach to user

3. **Save Credentials**:
   - Download the CSV file with Access Key ID and Secret Access Key
   - Share securely with developers

### Option 2: AWS CLI (For technical users)

```bash
# Create the policy
aws iam create-policy \
    --policy-name CPAL-Evictions-ECR-ReadOnly \
    --policy-document file://aws-ecr-policy.json

# Create user
aws iam create-user \
    --user-name cpal-evictions-developer

# Attach policy to user
aws iam attach-user-policy \
    --user-name cpal-evictions-developer \
    --policy-arn arn:aws:iam::678154373696:policy/CPAL-Evictions-ECR-ReadOnly

# Create access keys
aws iam create-access-key \
    --user-name cpal-evictions-developer
```

### Option 3: Terraform (For infrastructure as code)

```hcl
# Create IAM policy
resource "aws_iam_policy" "ecr_readonly" {
  name        = "CPAL-Evictions-ECR-ReadOnly"
  description = "Allow read-only access to CPAL Evictions ECR repository"
  policy      = file("${path.module}/aws-ecr-policy.json")
}

# Create IAM user
resource "aws_iam_user" "developer" {
  name = "cpal-evictions-developer"
}

# Attach policy to user
resource "aws_iam_user_policy_attachment" "ecr_readonly" {
  user       = aws_iam_user.developer.name
  policy_arn = aws_iam_policy.ecr_readonly.arn
}

# Create access keys
resource "aws_iam_access_key" "developer" {
  user = aws_iam_user.developer.name
}
```

## Developer Setup

Once developers receive their AWS credentials, they need to:

### 1. Install AWS CLI

```bash
# macOS
brew install awscli

# Ubuntu/Debian
sudo apt-get install awscli

# Windows
# Download from https://aws.amazon.com/cli/
```

### 2. Configure AWS CLI

```bash
aws configure
# Enter Access Key ID
# Enter Secret Access Key
# Region: us-east-1
# Output format: json
```

### 3. Test ECR Access

```bash
# Login to ECR
aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin 678154373696.dkr.ecr.us-east-1.amazonaws.com

# Pull the image
docker pull 678154373696.dkr.ecr.us-east-1.amazonaws.com/tumblr/rbase:Ubu22.04_R4.4.1_renv1.1.4_rsc1.4.1-20250609

# Tag for local use
docker tag 678154373696.dkr.ecr.us-east-1.amazonaws.com/tumblr/rbase:Ubu22.04_R4.4.1_renv1.1.4_rsc1.4.1-20250609 tumblr/rbase:Ubu22.04_R4.4.1_renv1.1.4_rsc1.4.1-20250609
```

### 4. Use with Docker Development

```bash
# Now developers can use the Docker environment
./docker-dev.sh dev
```

## Security Best Practices

1. **Rotate Keys Regularly**: Set up key rotation every 90 days
2. **Use IAM Roles**: For production environments, consider using IAM roles instead of access keys
3. **Monitor Usage**: Enable CloudTrail to monitor ECR access
4. **Least Privilege**: This policy follows the principle of least privilege
5. **Secure Sharing**: Share credentials through secure channels (password managers, encrypted email)

## Troubleshooting

### Common Issues

1. **"Access Denied" Error**:
   - Verify the policy is attached to the user
   - Check that the repository ARN matches exactly
   - Ensure the user has the correct region (us-east-1)

2. **"Repository Not Found"**:
   - Verify the repository exists in ECR
   - Check the repository name and tag

3. **"Invalid Credentials"**:
   - Verify AWS CLI configuration
   - Check that access keys are correct
   - Ensure the user has the `ecr:GetAuthorizationToken` permission

### Verification Commands

```bash
# Test AWS CLI configuration
aws sts get-caller-identity

# List available repositories
aws ecr describe-repositories --region us-east-1

# List images in repository
aws ecr list-images --repository-name tumblr/rbase --region us-east-1
```

## Cost Considerations

- **ECR Storage**: You pay for image storage (~$0.10/GB/month)
- **Data Transfer**: Free for first 1GB/month, then ~$0.09/GB
- **API Calls**: Free for first 1,000 calls/month, then ~$0.10/1,000 calls

## Alternative: Pre-pulled Images

If you want to avoid ECR access entirely, you could:

1. **Export the image** from a machine that has access
2. **Share the image file** with developers
3. **Load the image** on their machines

```bash
# Export image (on machine with ECR access)
docker save tumblr/rbase:Ubu22.04_R4.4.1_renv1.1.4_rsc1.4.1-20250609 | gzip > tumblr-rbase.tar.gz

# Load image (on developer machine)
gunzip -c tumblr-rbase.tar.gz | docker load
```

## Support

For issues with this setup, contact your AWS administrator or DevOps team.
