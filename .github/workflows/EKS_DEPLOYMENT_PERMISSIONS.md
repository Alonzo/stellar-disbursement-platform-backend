# IAM Permissions for EKS Deployment from GitHub Actions

**Date:** 2025-11-14  
**Purpose:** Enable automated Helm deployments to EKS from GitHub Actions CI/CD

---

## 🎯 **Current Situation**

The GitHub Actions workflow (`build-and-push-ecr.yml`) now includes automated Helm deployment steps. The existing IAM role `github-actions-ecr-role` has ECR permissions, but needs additional permissions to:

1. Access EKS cluster (to configure kubectl)
2. Deploy via Helm (update Kubernetes resources)

---

## 📋 **Required Permissions**

### **Option 1: Add EKS Permissions to Existing Role (Recommended)**

Add these permissions to the `github-actions-ecr-role` IAM role:

```json
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "eks:DescribeCluster",
                "eks:ListClusters"
            ],
            "Resource": "arn:aws:eks:us-west-2:084034390838:cluster/floral-bluegrass-outfit"
        }
    ]
}
```

**Note:** Kubernetes RBAC permissions are handled separately. The GitHub Actions role needs to be able to authenticate to the cluster, but the actual Kubernetes permissions come from the cluster's RBAC configuration.

### **Option 2: Use Existing EKS Access Policy**

If there's an existing managed policy for EKS access, attach it:
- `arn:aws:iam::aws:policy/AmazonEKSClusterPolicy` (read-only, for `update-kubeconfig`)
- Or create a custom policy with the permissions above

---

## 🔐 **Kubernetes RBAC Configuration**

The GitHub Actions workflow uses the AWS IAM role to authenticate to EKS. You need to ensure the IAM role ARN is mapped to a Kubernetes user/role with deployment permissions.

### **Map IAM Role to Kubernetes RBAC**

1. **Create Kubernetes ConfigMap** (if not already done):
```bash
kubectl apply -f - <<EOF
apiVersion: v1
kind: ConfigMap
metadata:
  name: aws-auth
  namespace: kube-system
data:
  mapRoles: |
    - rolearn: arn:aws:iam::084034390838:role/github-actions-ecr-role
      username: github-actions
      groups:
        - system:masters
EOF
```

**OR** (more secure) create a specific ClusterRoleBinding:

```bash
kubectl create clusterrolebinding github-actions-deploy \
  --clusterrole=cluster-admin \
  --user=arn:aws:iam::084034390838:role/github-actions-ecr-role
```

**Note:** `system:masters` or `cluster-admin` is very permissive. For production, consider creating a more restrictive role that only allows Helm deployments in the `default` namespace.

---

## ✅ **Verification Steps**

After adding permissions:

1. **Test EKS access:**
```bash
aws eks describe-cluster --name floral-bluegrass-outfit --region us-west-2 --profile devops
```

2. **Test kubectl configuration:**
```bash
aws eks update-kubeconfig --name floral-bluegrass-outfit --region us-west-2 --profile devops
kubectl get pods -n default
```

3. **Test Helm deployment:**
```bash
helm list -n default
helm upgrade sdp-prod helmchart/sdp --namespace default -f helmchart/sdp/production-values.yaml --dry-run
```

---

## 🔒 **Security Considerations**

- The GitHub Actions role should only have permissions for the specific EKS cluster
- Consider using a more restrictive Kubernetes RBAC role instead of `cluster-admin`
- The workflow only runs on pushes to `main` branch (not on PRs)
- All deployments are logged in CloudTrail

---

## 📝 **Next Steps**

1. Add EKS permissions to `github-actions-ecr-role`
2. Configure Kubernetes RBAC mapping (if not already done)
3. Test the workflow by pushing to `main` branch
4. Monitor CloudTrail logs for deployment activity

