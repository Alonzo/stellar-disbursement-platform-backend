# Ingress NLB Health Check - CI/CD Integration

## Overview

This GitHub Actions workflow automatically monitors the ingress NLB health and configuration to prevent the issue we experienced where the load balancer was missing subnets in availability zones where pods were running.

## Workflow Details

**File:** `.github/workflows/ingress-health-check.yml`

**Triggers:**
- **Scheduled:** Every 6 hours (cron: `0 */6 * * *`)
- **Manual:** Can be triggered via GitHub Actions UI
- **On Push:** Runs when infrastructure files change

**What It Checks:**
1. ✅ Load balancer has subnets in all AZs where ingress pods are running
2. ✅ All targets are healthy
3. ✅ External connectivity to `sdp.lomalo.app`

## Required IAM Permissions

The workflow uses the same IAM role as the ECR build workflow: `github-actions-ecr-role`

**Additional permissions needed:**
- `elbv2:DescribeLoadBalancers`
- `elbv2:DescribeTargetGroups`
- `elbv2:DescribeTargetHealth`
- `eks:DescribeCluster`
- `eks:ListClusters`

**Note:** If the role doesn't have these permissions, you'll need to add them. See below.

## Setup

### 1. Verify IAM Role Permissions

The role `arn:aws:iam::084034390838:role/github-actions-ecr-role` needs these additional permissions:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "elbv2:DescribeLoadBalancers",
        "elbv2:DescribeTargetGroups",
        "elbv2:DescribeTargetHealth",
        "eks:DescribeCluster",
        "eks:ListClusters"
      ],
      "Resource": "*"
    }
  ]
}
```

### 2. Add Permissions (if needed)

```bash
# Attach AWS managed policy (includes ELB and EKS read permissions)
aws iam attach-role-policy \
  --role-name github-actions-ecr-role \
  --policy-arn arn:aws:iam::aws:policy/AmazonEKSReadOnlyAccess

# Or create a custom policy with minimal permissions
aws iam put-role-policy \
  --role-name github-actions-ecr-role \
  --policy-name IngressHealthCheckPermissions \
  --policy-document file://ingress-health-check-policy.json
```

### 3. Test the Workflow

1. **Manual trigger:**
   - Go to GitHub Actions tab
   - Select "Ingress NLB Health Check"
   - Click "Run workflow"

2. **Verify it works:**
   - Check the workflow logs
   - Should see "✅ All checks passed" if everything is healthy

## What Happens on Failure

If the health check fails:

1. **Workflow fails** (red X in GitHub Actions)
2. **GitHub Issue created** (if enabled):
   - Title: "🚨 Ingress NLB Health Check Failed"
   - Labels: `ingress-health-check`, `infrastructure`, `urgent`
   - Includes troubleshooting steps and quick fix commands

3. **Notifications:**
   - GitHub Actions sends email notifications (if configured)
   - Issue appears in repository issues list

## Manual Testing

You can also run the health check script locally:

```bash
# With AWS profile
export AWS_PROFILE=devops
./infrastructure/ingress-nginx/check-lb-health.sh

# Or in CI/CD environment (uses OIDC)
unset AWS_PROFILE
export AWS_REGION=us-west-2
./infrastructure/ingress-nginx/check-lb-health.sh
```

## Troubleshooting

### Workflow fails with "Access Denied"

**Issue:** IAM role missing permissions

**Fix:**
```bash
# Add ELB and EKS read permissions
aws iam attach-role-policy \
  --role-name github-actions-ecr-role \
  --policy-arn arn:aws:iam::aws:policy/AmazonEKSReadOnlyAccess
```

### Workflow fails with "kubectl: command not found"

**Issue:** kubectl not installed in workflow

**Fix:** Already handled in workflow - uses `azure/setup-kubectl@v4`

### Workflow fails with "Could not find ingress load balancer"

**Issue:** Load balancer DNS name changed or doesn't match pattern

**Fix:** Update the query in `check-lb-health.sh`:
```bash
# Find the actual load balancer DNS name
aws elbv2 describe-load-balancers --region us-west-2 --query 'LoadBalancers[*].DNSName'
```

### Health check script not found

**Issue:** Script not in repository

**Fix:** Ensure `infrastructure/ingress-nginx/check-lb-health.sh` is committed to the repository

## Customization

### Change Schedule

Edit the cron expression in `.github/workflows/ingress-health-check.yml`:

```yaml
on:
  schedule:
    - cron: '0 */6 * * *'  # Every 6 hours
    # - cron: '0 */4 * * *'  # Every 4 hours
    # - cron: '0 0 * * *'    # Daily at midnight
```

### Disable Issue Creation

Comment out the "Create issue on failure" step in the workflow file.

### Add Slack Notifications

Add a step after the health check:

```yaml
- name: Notify Slack on failure
  if: failure()
  uses: slackapi/slack-github-action@v1
  with:
    payload: |
      {
        "text": "🚨 Ingress NLB Health Check Failed",
        "blocks": [
          {
            "type": "section",
            "text": {
              "type": "mrkdwn",
              "text": "*Ingress NLB Health Check Failed*\n<https://github.com/${{ github.repository }}/actions/runs/${{ github.run_id }}|View Workflow>"
            }
          }
        ]
      }
  env:
    SLACK_WEBHOOK_URL: ${{ secrets.SLACK_WEBHOOK_URL }}
```

## Related Documentation

- `INGRESS_NLB_PREVENTION_GUIDE.md` - Prevention measures and best practices
- `SDP_TROUBLESHOOTING_REPORT.md` - Original issue and resolution
- `infrastructure/ingress-nginx/check-lb-health.sh` - Health check script




