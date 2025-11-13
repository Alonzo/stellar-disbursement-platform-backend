#!/bin/bash
# Validate GitHub Actions workflow before pushing
# This checks for common errors and validates YAML syntax

set -e

WORKFLOW_FILE=".github/workflows/build-and-push-ecr.yml"

echo "╔══════════════════════════════════════════════════════════════╗"
echo "║        Validating GitHub Actions Workflow                     ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo ""

# Check if workflow file exists
if [ ! -f "$WORKFLOW_FILE" ]; then
    echo "❌ Workflow file not found: $WORKFLOW_FILE"
    exit 1
fi

echo "✅ Workflow file found: $WORKFLOW_FILE"
echo ""

# Validate YAML syntax
echo "Step 1: Validating YAML syntax..."
if command -v yamllint &> /dev/null; then
    yamllint "$WORKFLOW_FILE" && echo "✅ YAML syntax is valid"
elif command -v python3 &> /dev/null; then
    python3 -c "import yaml; yaml.safe_load(open('$WORKFLOW_FILE'))" 2>&1 && echo "✅ YAML syntax is valid" || {
        echo "❌ YAML syntax error"
        exit 1
    }
else
    echo "⚠️  No YAML validator found (yamllint or python3). Skipping syntax check."
fi
echo ""

# Check for common issues
echo "Step 2: Checking for common issues..."

# Check for required fields
if ! grep -q "name:" "$WORKFLOW_FILE"; then
    echo "❌ Missing 'name' field"
    exit 1
fi
echo "✅ Has 'name' field"

if ! grep -q "on:" "$WORKFLOW_FILE"; then
    echo "❌ Missing 'on' field (triggers)"
    exit 1
fi
echo "✅ Has 'on' field (triggers)"

if ! grep -q "jobs:" "$WORKFLOW_FILE"; then
    echo "❌ Missing 'jobs' field"
    exit 1
fi
echo "✅ Has 'jobs' field"
echo ""

# Check for AWS configuration
echo "Step 3: Validating AWS configuration..."
if ! grep -q "AWS_ACCOUNT.*084034390838" "$WORKFLOW_FILE"; then
    echo "⚠️  Warning: AWS_ACCOUNT may not be set correctly"
else
    echo "✅ AWS_ACCOUNT configured"
fi

if ! grep -q "AWS_REGION.*us-west-2" "$WORKFLOW_FILE"; then
    echo "⚠️  Warning: AWS_REGION may not be set correctly"
else
    echo "✅ AWS_REGION configured"
fi

if ! grep -q "github-actions-ecr-role" "$WORKFLOW_FILE"; then
    echo "⚠️  Warning: IAM role name not found in workflow"
else
    echo "✅ IAM role referenced"
fi
echo ""

# Check for required actions
echo "Step 4: Validating required GitHub Actions..."
REQUIRED_ACTIONS=(
    "actions/checkout"
    "aws-actions/configure-aws-credentials"
    "aws-actions/amazon-ecr-login"
    "docker/setup-buildx-action"
    "docker/build-push-action"
)

for action in "${REQUIRED_ACTIONS[@]}"; do
    if grep -q "$action" "$WORKFLOW_FILE"; then
        echo "✅ Found: $action"
    else
        echo "⚠️  Warning: $action not found"
    fi
done
echo ""

# Check for security best practices
echo "Step 5: Checking security best practices..."
if grep -q "id-token: write" "$WORKFLOW_FILE"; then
    echo "✅ OIDC authentication configured (id-token: write)"
else
    echo "⚠️  Warning: OIDC may not be configured (missing id-token: write)"
fi

if ! grep -q "AWS_ACCESS_KEY_ID\|AWS_SECRET_ACCESS_KEY" "$WORKFLOW_FILE"; then
    echo "✅ No hardcoded AWS credentials (good!)"
else
    echo "❌ ERROR: Hardcoded AWS credentials found! This is a security risk."
    exit 1
fi
echo ""

# Check Dockerfile exists
echo "Step 6: Validating Dockerfile..."
if [ -f "Dockerfile" ]; then
    echo "✅ Dockerfile exists"
else
    echo "⚠️  Warning: Dockerfile not found in repo root"
fi
echo ""

echo "╔══════════════════════════════════════════════════════════════╗"
echo "║                    ✅ Validation Complete!                     ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo ""
echo "Next steps:"
echo "1. Review any warnings above"
echo "2. Set up OIDC: ./.github/workflows/setup-oidc.sh"
echo "3. Test with a small commit or manual trigger"
echo ""

