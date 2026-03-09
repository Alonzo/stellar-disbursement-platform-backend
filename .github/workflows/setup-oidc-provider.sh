#!/bin/bash
# Script to create GitHub OIDC provider (run with devops profile)
# This creates the OIDC identity provider that GitHub Actions will use

set -e

AWS_ACCOUNT="084034390838"
AWS_REGION="us-west-2"
AWS_PROFILE="${AWS_PROFILE:-devops}"  # Use devops profile by default

echo "╔══════════════════════════════════════════════════════════════╗"
echo "║        Creating GitHub OIDC Provider (DevOps)                 ║"
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

# Check if OIDC provider already exists
echo "Step 2: Checking for existing OIDC provider..."
OIDC_PROVIDER=$(aws iam list-open-id-connect-providers --region "$AWS_REGION" --profile "$AWS_PROFILE" --query "OpenIDConnectProviderList[?contains(Arn, 'token.actions.githubusercontent.com')].Arn" --output text 2>/dev/null || echo "")

if [ -n "$OIDC_PROVIDER" ]; then
    echo "✅ OIDC provider already exists: $OIDC_PROVIDER"
    echo "   No action needed!"
else
    echo "Creating OIDC provider..."
    
    # Get GitHub's OIDC thumbprint (SHA1, 40 characters)
    echo "   Fetching GitHub OIDC thumbprint..."
    THUMBPRINT=$(echo | openssl s_client -servername token.actions.githubusercontent.com -showcerts -connect token.actions.githubusercontent.com:443 2>/dev/null | \
      openssl x509 -fingerprint -sha1 -noout | \
      sed 's/.*=//' | \
      tr -d ':' | \
      tr '[:upper:]' '[:lower:]')
    
    if [ -z "$THUMBPRINT" ] || [ ${#THUMBPRINT} -ne 40 ]; then
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
        echo "   Check that your profile has iam:CreateOpenIDConnectProvider permission"
        exit 1
    }
    echo "✅ OIDC provider created"
fi

echo ""
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║                    ✅ OIDC Provider Ready!                   ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo ""
echo "Next step: Run setup-oidc-role.sh with Security Admin profile"
echo ""

