#!/bin/bash
# Script to set up GitHub OIDC for AWS ECR access
# Run this with AWS credentials that have IAM admin access

set -e

AWS_ACCOUNT="084034390838"
AWS_REGION="us-west-2"
GITHUB_REPO="m1global/sdp-backend"
ROLE_NAME="github-actions-ecr-role"
AWS_PROFILE="${AWS_PROFILE:-devops}"  # Use devops profile by default

echo "╔══════════════════════════════════════════════════════════════╗"
echo "║        Setting Up GitHub OIDC for AWS ECR                     ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo ""

# Check AWS credentials
echo "Step 1: Verifying AWS credentials (using profile: $AWS_PROFILE)..."
if ! aws sts get-caller-identity --region "$AWS_REGION" --profile "$AWS_PROFILE" &>/dev/null; then
    echo "❌ AWS credentials not configured for profile: $AWS_PROFILE"
    echo "   Try: export AWS_PROFILE=devops"
    exit 1
fi
echo "✅ AWS credentials verified"
echo ""

# Step 2: Check if OIDC provider already exists
echo "Step 2: Checking for existing OIDC provider..."
OIDC_PROVIDER=$(aws iam list-open-id-connect-providers --region "$AWS_REGION" --profile "$AWS_PROFILE" --query "OpenIDConnectProviderList[?contains(Arn, 'token.actions.githubusercontent.com')].Arn" --output text 2>/dev/null || echo "")

if [ -n "$OIDC_PROVIDER" ]; then
    echo "✅ OIDC provider already exists: $OIDC_PROVIDER"
else
    echo "Creating OIDC provider..."
    
    # Get GitHub's OIDC thumbprint (SHA1, 40 characters)
    echo "   Fetching GitHub OIDC thumbprint..."
    THUMBPRINT=$(echo | openssl s_client -servername token.actions.githubusercontent.com -showcerts -connect token.actions.githubusercontent.com:443 2>/dev/null | \
      openssl x509 -fingerprint -sha1 -noout | \
      sed 's/.*=//' | \
      tr -d ':' | \
      tr '[:upper:]' '[:lower:]')
    
    if [ -z "$THUMBPRINT" ]; then
        echo "⚠️  Could not fetch thumbprint automatically. Using known thumbprint:"
        THUMBPRINT="6938fd4d98bab03faadb97b34396831e3780aea1"
    fi
    
    echo "   Using thumbprint: $THUMBPRINT"
    
    aws iam create-open-id-connect-provider \
      --url https://token.actions.githubusercontent.com \
      --client-id-list sts.amazonaws.com \
      --thumbprint-list "$THUMBPRINT" \
      --region "$AWS_REGION" \
      --profile "$AWS_PROFILE" || {
        echo "❌ Failed to create OIDC provider"
        exit 1
    }
    echo "✅ OIDC provider created"
fi
echo ""

# Step 3: Create trust policy
echo "Step 3: Creating IAM role trust policy..."
cat > /tmp/github-actions-trust-policy.json << EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Federated": "arn:aws:iam::${AWS_ACCOUNT}:oidc-provider/token.actions.githubusercontent.com"
      },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringEquals": {
          "token.actions.githubusercontent.com:aud": "sts.amazonaws.com"
        },
        "StringLike": {
          "token.actions.githubusercontent.com:sub": "repo:${GITHUB_REPO}:*"
        }
      }
    }
  ]
}
EOF
echo "✅ Trust policy created"
echo ""

# Step 4: Create IAM role
echo "Step 4: Creating IAM role..."
if aws iam get-role --role-name "$ROLE_NAME" --region "$AWS_REGION" --profile "$AWS_PROFILE" &>/dev/null; then
    echo "⚠️  Role $ROLE_NAME already exists. Updating trust policy..."
    aws iam update-assume-role-policy \
      --role-name "$ROLE_NAME" \
      --policy-document file:///tmp/github-actions-trust-policy.json \
      --region "$AWS_REGION" \
      --profile "$AWS_PROFILE"
    echo "✅ Trust policy updated"
else
    aws iam create-role \
      --role-name "$ROLE_NAME" \
      --assume-role-policy-document file:///tmp/github-actions-trust-policy.json \
      --region "$AWS_REGION" \
      --profile "$AWS_PROFILE" || {
        echo "❌ Failed to create IAM role"
        exit 1
    }
    echo "✅ IAM role created"
fi
echo ""

# Step 5: Attach ECR policy
echo "Step 5: Attaching ECR permissions..."
aws iam attach-role-policy \
  --role-name "$ROLE_NAME" \
  --policy-arn arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryPowerUser \
  --region "$AWS_REGION" \
  --profile "$AWS_PROFILE" || {
    echo "❌ Failed to attach ECR policy"
    exit 1
}
echo "✅ ECR permissions attached"
echo ""

# Step 6: Verify setup
echo "Step 6: Verifying setup..."
echo ""
echo "OIDC Provider:"
aws iam list-open-id-connect-providers --region "$AWS_REGION" --profile "$AWS_PROFILE" --query "OpenIDConnectProviderList[?contains(Arn, 'token.actions.githubusercontent.com')]" --output table

echo ""
echo "IAM Role:"
aws iam get-role --role-name "$ROLE_NAME" --region "$AWS_REGION" --profile "$AWS_PROFILE" --query "Role.{RoleName:RoleName,Arn:Arn}" --output table

echo ""
echo "Attached Policies:"
aws iam list-attached-role-policies --role-name "$ROLE_NAME" --region "$AWS_REGION" --profile "$AWS_PROFILE" --output table

echo ""
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║                    ✅ Setup Complete!                         ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo ""
echo "Next steps:"
echo "1. Push a commit to trigger the workflow"
echo "2. Check GitHub Actions tab for build status"
echo "3. Verify image in ECR:"
echo "   aws ecr list-images --repository-name stellar-disbursement-platform-backend --region $AWS_REGION"
echo ""

# Cleanup
rm -f /tmp/github-actions-trust-policy.json

