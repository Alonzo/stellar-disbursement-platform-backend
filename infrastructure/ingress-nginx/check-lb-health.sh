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

# Get load balancer ARN
echo "Finding load balancer..."
LB_ARN=$(aws elbv2 describe-load-balancers \
  $PROFILE \
  --region "$REGION" \
  --query 'LoadBalancers[?contains(DNSName, `k8s-ingressn`)].LoadBalancerArn' \
  --output text 2>/dev/null)

if [ -z "$LB_ARN" ] || [ "$LB_ARN" == "None" ]; then
  echo "❌ ERROR: Could not find ingress load balancer"
  exit 1
fi

echo "Load balancer ARN: $LB_ARN"
echo ""

# Get load balancer subnets/AZs
LB_AZS=$(aws elbv2 describe-load-balancers \
  $PROFILE \
  --region "$REGION" \
  --load-balancer-arns "$LB_ARN" \
  --query 'LoadBalancers[0].AvailabilityZones[*].ZoneName' \
  --output text 2>/dev/null | tr '\t' '\n' | sort -u)

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

# Check target health for port 443
echo "Checking target health (port 443)..."
TG_443=$(aws elbv2 describe-target-groups \
  $PROFILE \
  --region "$REGION" \
  --load-balancer-arn "$LB_ARN" \
  --query 'TargetGroups[?Port==`443`].TargetGroupArn' \
  --output text 2>/dev/null | head -1)

if [ -n "$TG_443" ] && [ "$TG_443" != "None" ]; then
  TARGET_HEALTH=$(aws elbv2 describe-target-health \
    $PROFILE \
    --region "$REGION" \
    --target-group-arn "$TG_443" \
    --query 'TargetHealthDescriptions[*].{Target:Target.Id,Port:Target.Port,State:TargetHealth.State,Reason:TargetHealth.Reason}' \
    --output json 2>/dev/null)
  
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
  echo "⚠️  WARNING: Could not find target group for port 443"
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

