#!/bin/bash
# Script to create IAM role for GitHub Actions (run with Security Admin profile)
# This creates the role that GitHub Actions will assume to push to ECR

set -e

AWS_ACCOUNT="084034390838"
AWS_REGION="us-west-2"
GITHUB_REPO="m1global/sdp-backend"
ROLE_NAME="github-actions-ecr-role"
AWS_PROFILE="${AWS_PROFILE:-devops-security-admin}"  # Use security admin profile by default

echo "╔══════════════════════════════════════════════════════════════╗"
echo "║        Creating IAM Role for GitHub Actions                    ║"
echo "║                  (Security Admin)                             ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo ""

# Check AWS credentials
echo "Step 1: Verifying AWS credentials (using profile: $AWS_PROFILE)..."
if ! aws sts get-caller-identity --region "$AWS_REGION" --profile "$AWS_PROFILE" &>/dev/null; then
    echo "❌ AWS credentials not configured for profile: $AWS_PROFILE"
    echo "   Try: export AWS_PROFILE=devops-security-admin"
    echo "   Or: export AWS_PROFILE=SecurityAdmin-760081991559"
    exit 1
fi
echo "✅ AWS credentials verified"
echo ""

# Verify OIDC provider exists first
echo "Step 2: Verifying OIDC provider exists..."
OIDC_PROVIDER=$(aws iam list-open-id-connect-providers --region "$AWS_REGION" --profile "$AWS_PROFILE" --query "OpenIDConnectProviderList[?contains(Arn, 'token.actions.githubusercontent.com')].Arn" --output text 2>/dev/null || echo "")

if [ -z "$OIDC_PROVIDER" ]; then
    echo "⚠️  OIDC provider not found!"
    echo "   The role can be created, but it won't work until the OIDC provider exists."
    echo "   Please create the OIDC provider first (request permissions or manual creation)"
    echo ""
    read -p "Continue creating role anyway? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Aborted. Create OIDC provider first."
        exit 1
    fi
    echo "⚠️  Continuing without OIDC provider verification..."
else
    echo "✅ OIDC provider found: $OIDC_PROVIDER"
fi
echo ""

# Create trust policy
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

# Create IAM role
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
        echo "   Check that your profile has iam:CreateRole permission"
        exit 1
    }
    echo "✅ IAM role created"
fi
echo ""

# Attach ECR policy
echo "Step 5: Attaching ECR permissions..."
aws iam attach-role-policy \
  --role-name "$ROLE_NAME" \
  --policy-arn arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryPowerUser \
  --region "$AWS_REGION" \
  --profile "$AWS_PROFILE" || {
    echo "❌ Failed to attach ECR policy"
    echo "   Check that your profile has iam:AttachRolePolicy permission"
    exit 1
}
echo "✅ ECR permissions attached"
echo ""

# Verify setup
echo "Step 6: Verifying setup..."
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
echo "OIDC provider and IAM role are now configured!"
echo "Next step: Test the workflow manually in GitHub Actions"
echo ""

# Cleanup
rm -f /tmp/github-actions-trust-policy.json

