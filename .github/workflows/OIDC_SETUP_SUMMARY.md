# OIDC Setup Summary

## Current Situation

We've split the setup into two scripts, but **neither profile currently has the required permissions**:

### Script 1: `setup-oidc-provider.sh` (DevOps Profile)
- **Needs:** `iam:CreateOpenIDConnectProvider` permission
- **Status:** ❌ devops profile doesn't have this permission
- **What it does:** Creates the OIDC provider for GitHub Actions

### Script 2: `setup-oidc-role.sh` (Security Admin Profile)  
- **Needs:** `iam:CreateRole`, `iam:UpdateAssumeRolePolicy`, `iam:AttachRolePolicy` permissions
- **Status:** ⏳ Not tested yet (needs OIDC provider first)
- **What it does:** Creates the IAM role that GitHub Actions will assume

## Required Permissions

### For DevOps Profile (OIDC Provider):
```json
{
  "Effect": "Allow",
  "Action": [
    "iam:CreateOpenIDConnectProvider",
    "iam:GetOpenIDConnectProvider",
    "iam:ListOpenIDConnectProviders"
  ],
  "Resource": "arn:aws:iam::084034390838:oidc-provider/token.actions.githubusercontent.com"
}
```

### For Security Admin Profile (IAM Role):
```json
{
  "Effect": "Allow",
  "Action": [
    "iam:CreateRole",
    "iam:GetRole",
    "iam:UpdateAssumeRolePolicy",
    "iam:AttachRolePolicy",
    "iam:ListAttachedRolePolicies"
  ],
  "Resource": "arn:aws:iam::084034390838:role/github-actions-ecr-role"
}
```

## Next Steps

1. **Request permissions** for devops profile to create OIDC provider
2. **OR** Have someone with IAM admin create the OIDC provider manually
3. **Then** Run `setup-oidc-role.sh` with Security Admin profile

## Manual OIDC Provider Creation (If Needed)

If you get someone with IAM admin to create it:

```bash
aws iam create-open-id-connect-provider \
  --url https://token.actions.githubusercontent.com \
  --client-id-list sts.amazonaws.com \
  --thumbprint-list 6938fd4d98bab03faadb97b34396831e3780aea1 \
  --region us-west-2
```

Then run: `./setup-oidc-role.sh` with Security Admin profile

