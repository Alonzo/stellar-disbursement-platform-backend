# IAM Permission Request: GitHub Actions EKS Deployment

**Date:** 2025-11-14  
**Requestor:** Alonzo Benavides  
**Account:** 084034390838 (DevOps Account)  
**Purpose:** Enable automated production deployments from GitHub Actions CI/CD

---

## 🎯 **Request Summary**

I need to add EKS read permissions to the existing `github-actions-ecr-role` IAM role so that GitHub Actions can automatically deploy new Docker images to our production EKS cluster after building them.

**Current Status:**
- ✅ Role exists: `github-actions-ecr-role`
- ✅ Has ECR permissions (can push Docker images)
- ❌ Missing EKS permissions (cannot deploy to cluster)

---

## 📋 **Required IAM Permissions**

Add the following policy to the `github-actions-ecr-role` IAM role:

**Policy Name:** `GitHubActionsEKSDeploy` (or similar)

**Policy Document:**
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

**What this enables:**
- Allows GitHub Actions to read EKS cluster configuration (needed to configure `kubectl`)
- **Read-only access** - cannot create/delete/modify clusters
- Scoped to **only** the `floral-bluegrass-outfit` cluster

---

## 🔐 **Kubernetes RBAC Configuration**

After IAM permissions are added, I also need to configure Kubernetes RBAC to allow the IAM role to deploy via Helm.

**Option 1: Restricted Access (Recommended)**
- Only allow Helm deployments in `default` namespace
- Cannot modify other resources or namespaces

**Option 2: Full Cluster Admin**
- Full access to cluster (for simplicity)
- Can deploy anywhere, modify any resource

**I'll handle the Kubernetes RBAC configuration after IAM permissions are granted.**

---

## ✅ **What This Enables**

Once permissions are granted, when code is pushed to the `main` branch:
1. GitHub Actions builds a new Docker image
2. Pushes image to ECR (already works)
3. **NEW:** Automatically deploys to production EKS cluster using Helm
4. No manual intervention needed

**Security:**
- Only runs on `main` branch pushes (not on PRs)
- All actions logged in CloudTrail
- Cannot access secrets, databases, or other AWS resources
- Only updates the `sdp-prod` Helm release

---

## 📝 **Action Required**

Please add the IAM policy above to the `github-actions-ecr-role` role.

**Role ARN:** `arn:aws:iam::084034390838:role/github-actions-ecr-role`

**Verification:**
After adding permissions, I'll test with:
```bash
aws eks describe-cluster --name floral-bluegrass-outfit --region us-west-2
```

---

## ❓ **Questions?**

If you have any questions about:
- Why these specific permissions are needed
- Security implications
- Alternative approaches

Please let me know!

