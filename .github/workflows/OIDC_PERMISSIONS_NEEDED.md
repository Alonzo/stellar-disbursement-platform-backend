# OIDC Setup - Permissions Needed

## Current Situation

The `devops` profile doesn't have IAM permissions to:
- Create OIDC providers (`iam:CreateOpenIDConnectProvider`)
- Create IAM roles (`iam:CreateRole`)
- Update IAM roles (`iam:UpdateAssumeRolePolicy`)

## Options

### Option 1: Use Security Admin Profile (If Available)

If you have a `security-admin` profile with IAM permissions:

```bash
export AWS_PROFILE=security-admin
./.github/workflows/setup-oidc.sh
```

### Option 2: Request Permissions for DevOps Profile

Request these IAM permissions be added to the `devops` role:

**Required Permissions:**
```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "iam:CreateOpenIDConnectProvider",
        "iam:DeleteOpenIDConnectProvider",
        "iam:ListOpenIDConnectProviders",
        "iam:GetOpenIDConnectProvider",
        "iam:TagOpenIDConnectProvider",
        "iam:CreateRole",
        "iam:GetRole",
        "iam:UpdateAssumeRolePolicy",
        "iam:AttachRolePolicy",
        "iam:ListAttachedRolePolicies"
      ],
      "Resource": [
        "arn:aws:iam::084034390838:oidc-provider/token.actions.githubusercontent.com",
        "arn:aws:iam::084034390838:role/github-actions-ecr-role"
      ]
    }
  ]
}
```

### Option 3: Manual Setup (One-Time)

Have someone with IAM admin access run:

```bash
# 1. Create OIDC provider
aws iam create-open-id-connect-provider \
  --url https://token.actions.githubusercontent.com \
  --client-id-list sts.amazonaws.com \
  --thumbprint-list 6938fd4d98bab03faadb97b34396831e3780aea1 \
  --region us-west-2

# 2. Create trust policy file
cat > /tmp/github-trust-policy.json << 'EOF'
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Federated": "arn:aws:iam::084034390838:oidc-provider/token.actions.githubusercontent.com"
      },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringEquals": {
          "token.actions.githubusercontent.com:aud": "sts.amazonaws.com"
        },
        "StringLike": {
          "token.actions.githubusercontent.com:sub": "repo:m1global/sdp-backend:*"
        }
      }
    }
  ]
}
EOF

# 3. Create role
aws iam create-role \
  --role-name github-actions-ecr-role \
  --assume-role-policy-document file:///tmp/github-trust-policy.json \
  --region us-west-2

# 4. Attach ECR policy
aws iam attach-role-policy \
  --role-name github-actions-ecr-role \
  --policy-arn arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryPowerUser \
  --region us-west-2
```

## What We Need

1. **OIDC Provider:** `token.actions.githubusercontent.com` (for GitHub Actions)
2. **IAM Role:** `github-actions-ecr-role` (for GitHub to assume)
3. **Trust Policy:** Allows `repo:m1global/sdp-backend:*` to assume the role
4. **ECR Permissions:** `AmazonEC2ContainerRegistryPowerUser` policy attached

## Verification

After setup, verify:

```bash
# Check OIDC provider exists
aws iam list-open-id-connect-providers --region us-west-2

# Check role exists
aws iam get-role --role-name github-actions-ecr-role --region us-west-2

# Check permissions
aws iam list-attached-role-policies --role-name github-actions-ecr-role --region us-west-2
```

