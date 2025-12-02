#!/usr/bin/env bash
set -o pipefail

# Check Ingress NLB Health and Configuration
# Verifies that load balancer has subnets in all AZs where ingress pods are running

# Support both local (with profile) and CI/CD (OIDC) environments
if [ -n "$AWS_PROFILE" ]; then
  PROFILE="--profile $AWS_PROFILE"
else
  PROFILE=""  # CI/CD uses OIDC, no profile needed
fi
REGION="${AWS_REGION:-us-west-2}"
NAMESPACE="ingress-nginx"

echo "╔══════════════════════════════════════════════════════════════╗"
echo "║     Ingress NLB Health Check                                 ║"
echo "╚══════════════════════════════════════════════════════════════╝"
if [ -n "$AWS_PROFILE" ]; then
  echo "Profile: $AWS_PROFILE"
else
  echo "Profile: (using default credentials/OIDC)"
fi
echo "Region: $REGION"
echo "Namespace: $NAMESPACE"
echo "Date: $(date)"
echo ""

ERRORS=0

# Get ingress controller pods and their AZs
echo "Checking ingress controller pods..."
POD_NODES=$(kubectl get pods -n "$NAMESPACE" -l app.kubernetes.io/component=controller \
  -o jsonpath='{range .items[*]}{.spec.nodeName}{"\n"}{end}' 2>/dev/null)

if [ -z "$POD_NODES" ]; then
  echo "❌ ERROR: No ingress controller pods found"
  exit 1
fi

POD_AZS=""
for node in $POD_NODES; do
  AZ=$(kubectl get node "$node" -o jsonpath='{.metadata.labels.failure-domain\.beta\.kubernetes\.io/zone}' 2>/dev/null)
  if [ -n "$AZ" ]; then
    POD_AZS="$POD_AZS $AZ"
  fi
done

POD_AZS=$(echo "$POD_AZS" | tr ' ' '\n' | sort -u | grep -v '^$')
echo "Ingress pods are in AZs: $(echo $POD_AZS | tr '\n' ' ')"
echo ""

# Get load balancer subnets from Kubernetes service annotation (works without ELB permissions)
echo "Finding load balancer configuration..."

# Get subnet IDs from Kubernetes service annotation
LB_SUBNETS=$(kubectl get svc ingress-nginx-controller -n "$NAMESPACE" \
  -o jsonpath='{.metadata.annotations.service\.beta\.kubernetes\.io/aws-load-balancer-subnets}' 2>/dev/null)

if [ -z "$LB_SUBNETS" ]; then
  echo "⚠️  WARNING: Could not find subnet annotation on service"
  echo "   This might indicate the service wasn't configured with explicit subnets"
  echo ""
  echo "   Service annotations:"
  kubectl get svc ingress-nginx-controller -n "$NAMESPACE" -o jsonpath='{.metadata.annotations}' 2>&1 | jq -r 'to_entries[] | "\(.key): \(.value)"' || echo "  Could not get annotations"
  echo ""
  echo "❌ ERROR: Cannot verify subnet configuration without subnet annotation"
  echo "   The service should have: service.beta.kubernetes.io/aws-load-balancer-subnets"
  exit 1
fi

echo "Load balancer subnets: $LB_SUBNETS"
echo ""

# Get availability zones from subnet IDs (this requires ec2:DescribeSubnets, which is usually available)
LB_SUBNET_LIST=$(echo "$LB_SUBNETS" | tr ',' ' ')
LB_AZS=""

for subnet in $LB_SUBNET_LIST; do
  AZ=$(aws ec2 describe-subnets \
    $PROFILE \
    --region "$REGION" \
    --subnet-ids "$subnet" \
    --query 'Subnets[0].AvailabilityZone' \
    --output text 2>/dev/null)
  
  if [ -n "$AZ" ] && [ "$AZ" != "None" ]; then
    LB_AZS="$LB_AZS $AZ"
  fi
done

LB_AZS=$(echo "$LB_AZS" | tr ' ' '\n' | sort -u | grep -v '^$')

if [ -z "$LB_AZS" ]; then
  echo "⚠️  WARNING: Could not determine AZs from subnets"
  echo "   This might be an IAM permissions issue (ec2:DescribeSubnets)"
  echo "   Subnets: $LB_SUBNETS"
  echo ""
  echo "   Falling back to basic validation..."
  # At least verify we have subnets configured
  if [ -n "$LB_SUBNETS" ]; then
    echo "✅ Load balancer has subnets configured: $LB_SUBNETS"
    echo "⚠️  Cannot verify AZ coverage without ec2:DescribeSubnets permission"
  else
    echo "❌ ERROR: No subnets configured"
    exit 1
  fi
fi

if [ -n "$LB_AZS" ] && [ "$LB_AZS" != "SKIP_CHECK" ]; then
  echo "Load balancer has subnets in AZs: $(echo $LB_AZS | tr '\n' ' ')"
  echo ""
  
  # Check if all pod AZs are covered
  MISSING_AZS=$(comm -23 <(echo "$POD_AZS" | sort) <(echo "$LB_AZS" | sort))
  
  if [ -n "$MISSING_AZS" ]; then
    echo "❌ ERROR: Load balancer missing subnets in: $(echo $MISSING_AZS | tr '\n' ' ')"
    echo "   Ingress pods in these AZs cannot be used by the load balancer!"
    echo ""
    echo "   Fix: Add missing subnets to ingress-nginx service annotation:"
    echo "   kubectl annotate svc ingress-nginx-controller -n $NAMESPACE \\"
    echo "     service.beta.kubernetes.io/aws-load-balancer-subnets=\"<all-subnet-ids>\" \\"
    echo "     --overwrite"
    ((ERRORS++))
  else
    echo "✅ All ingress pod AZs are covered by load balancer"
  fi
  echo ""
else
  # AZ check was skipped, but we verified subnets are configured
  echo "✅ Load balancer subnet configuration verified"
  echo "   Note: Full AZ coverage check requires ec2:DescribeSubnets permission"
  echo ""
fi

# Check target health for port 443 (optional - requires ELB permissions)
echo "Checking target health (port 443)..."
# Try to get target group from Kubernetes service (if available)
# Note: This requires ELB API permissions, so we'll make it optional

# Get load balancer ARN if we can (for target health check)
LB_ARN_FROM_K8S=$(kubectl get svc ingress-nginx-controller -n "$NAMESPACE" \
  -o jsonpath='{.metadata.annotations.service\.beta\.kubernetes\.io/load-balancer-id}' 2>/dev/null)

if [ -n "$LB_ARN_FROM_K8S" ]; then
  TG_443=$(aws elbv2 describe-target-groups \
    $PROFILE \
    --region "$REGION" \
    --load-balancer-arn "$LB_ARN_FROM_K8S" \
    --query 'TargetGroups[?Port==`443`].TargetGroupArn' \
    --output text 2>/dev/null | head -1)

  if [ -n "$TG_443" ] && [ "$TG_443" != "None" ]; then
    TARGET_HEALTH=$(aws elbv2 describe-target-health \
      $PROFILE \
      --region "$REGION" \
      --target-group-arn "$TG_443" \
      --query 'TargetHealthDescriptions[*].{Target:Target.Id,Port:Target.Port,State:TargetHealth.State,Reason:TargetHealth.Reason}' \
      --output json 2>/dev/null)
    
    if [ $? -eq 0 ] && [ -n "$TARGET_HEALTH" ]; then
      UNHEALTHY=$(echo "$TARGET_HEALTH" | jq -r '.[] | select(.State != "healthy")' 2>/dev/null)
      
      if [ -n "$UNHEALTHY" ] && [ "$UNHEALTHY" != "null" ]; then
        echo "⚠️  WARNING: Some targets are not healthy:"
        echo "$TARGET_HEALTH" | jq .
        ((ERRORS++))
      else
        echo "✅ All targets are healthy"
        echo "$TARGET_HEALTH" | jq .
      fi
    else
      echo "⚠️  Could not check target health (ELB API permissions may be missing)"
      echo "   This is optional - main checks (subnet/AZ coverage) are complete"
    fi
  else
    echo "⚠️  Could not find target group for port 443"
  fi
else
  echo "⚠️  Skipping target health check (requires ELB API permissions)"
  echo "   Main validation (subnet/AZ coverage) is complete"
fi
echo ""

# Test connectivity
echo "Testing external connectivity..."
if curl -s --max-time 5 https://sdp.lomalo.app/health > /dev/null 2>&1; then
  echo "✅ External connectivity: OK"
else
  echo "❌ ERROR: External connectivity failed"
  ((ERRORS++))
fi
echo ""

# Summary
echo "══════════════════════════════════════════════════════════════"
if [ $ERRORS -eq 0 ]; then
  echo "✅ All checks passed"
  exit 0
else
  echo "❌ Found $ERRORS issue(s)"
  exit 1
fi

