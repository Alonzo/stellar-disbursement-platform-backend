# Setting Up GitHub OIDC for AWS

This guide will help you set up OIDC (OpenID Connect) authentication so GitHub Actions can push to ECR without storing long-lived AWS credentials.

## Prerequisites

- AWS CLI configured with admin access
- GitHub repo: `m1global/sdp-backend`
- AWS Account: `084034390838`
- Region: `us-west-2`

## Step 1: Create OIDC Identity Provider in AWS

First, we need to add GitHub as a trusted identity provider in AWS IAM.

```bash
aws iam create-open-id-connect-provider \
  --url https://token.actions.githubusercontent.com \
  --client-id-list sts.amazonaws.com \
  --thumbprint-list 6938fd4d98bab03faadb97b34396831e3780aea1 \
  --region us-west-2 \
  --profile devops
```

**Note:** The thumbprint may need to be updated. If the command fails, get the current thumbprint:

```bash
# Get GitHub's OIDC thumbprint
openssl s_client -servername token.actions.githubusercontent.com -showcerts -connect token.actions.githubusercontent.com:443 < /dev/null 2>/dev/null | \
  openssl x509 -fingerprint -noout | \
  sed 's/.*=//' | \
  tr -d ':'
```

## Step 2: Create IAM Role for GitHub Actions

Create a trust policy that allows GitHub to assume the role:

```bash
cat > /tmp/github-actions-trust-policy.json << 'EOF'
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

aws iam create-role \
  --role-name github-actions-ecr-role \
  --assume-role-policy-document file:///tmp/github-actions-trust-policy.json \
  --region us-west-2 \
  --profile devops
```

## Step 3: Attach ECR Permissions

Attach the ECR push policy to the role:

```bash
aws iam attach-role-policy \
  --role-name github-actions-ecr-role \
  --policy-arn arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryPowerUser \
  --region us-west-2 \
  --profile devops
```

## Step 4: Verify Setup

Check that everything is configured:

```bash
# Verify OIDC provider exists
aws iam list-open-id-connect-providers --region us-west-2 --profile devops

# Verify role exists
aws iam get-role --role-name github-actions-ecr-role --region us-west-2 --profile devops

# Verify policy is attached
aws iam list-attached-role-policies --role-name github-actions-ecr-role --region us-west-2 --profile devops
```

## Step 5: Test the Workflow

1. Push a commit to the `main` branch
2. Go to GitHub Actions tab
3. Watch the workflow run
4. Check ECR for the new image

## Troubleshooting

### Error: "No OpenIDConnect provider found"

- Make sure Step 1 completed successfully
- Verify the OIDC provider exists: `aws iam list-open-id-connect-providers`

### Error: "Access Denied" when assuming role

- Check the trust policy matches your repo: `repo:m1global/sdp-backend:*`
- Verify the role exists: `aws iam get-role --role-name github-actions-ecr-role`

### Error: "ECR push failed"

- Verify the role has ECR permissions: `aws iam list-attached-role-policies --role-name github-actions-ecr-role`
- Check ECR repository exists: `aws ecr describe-repositories --repository-names stellar-disbursement-platform-backend`

## Security Notes

- ✅ No long-lived AWS keys stored in GitHub
- ✅ Role can only be assumed by your specific repo
- ✅ All actions logged in CloudTrail
- ✅ Least privilege (only ECR push permissions)

## Next Steps

After OIDC is set up:
1. Push a commit to trigger the workflow
2. Verify the build completes
3. Check ECR for the new image
4. Update Helm deployment to use the new image tag

