# Access Summary: GitHub Actions → EKS Deployment

## 🎯 **What You're Granting Access To**

**Who:** GitHub Actions (CI/CD system)  
**What IAM Role:** `github-actions-ecr-role`  
**What They Can Do:** Deploy new Docker images to production EKS cluster

---

## 📋 **Current Access (Already Has)**

The `github-actions-ecr-role` currently has:
- ✅ **ECR (Docker Registry) Access**
  - Push Docker images to: `084034390838.dkr.ecr.us-west-2.amazonaws.com/stellar-disbursement-platform-backend`
  - Pull images (for builds)
  - **What this means:** Can upload new code/images, but can't deploy them

---

## 🔓 **New Access Being Requested**

### **1. AWS IAM Permissions (EKS Read Access)**

**Permissions:**
- `eks:DescribeCluster` - Read cluster configuration
- `eks:ListClusters` - List available clusters

**Scope:**
- **Only** the `floral-bluegrass-outfit` cluster
- **Only** read access (can't create/delete clusters)

**What this enables:**
- Configure `kubectl` to connect to the cluster
- **Cannot:** Create/delete clusters, modify cluster settings

### **2. Kubernetes RBAC Permissions**

**What's needed:**
- Map the IAM role to a Kubernetes user with deployment permissions

**Options:**

**Option A: Full Cluster Admin (Easiest, Less Secure)**
```yaml
- Can deploy to ANY namespace
- Can modify ANY Kubernetes resource
- Can delete resources
- Can access secrets (but not AWS Secrets Manager secrets)
```

**Option B: Restricted to `default` Namespace (More Secure)**
```yaml
- Can only deploy to `default` namespace
- Can only update existing Helm releases
- Cannot create new namespaces
- Cannot access other namespaces
```

**What this enables:**
- Run `helm upgrade` to update the `sdp-prod` deployment
- Update pod images, configurations
- **Cannot:** Access AWS Secrets Manager (secrets are injected via IRSA to pods, not to GitHub Actions)
- **Cannot:** Modify other AWS resources (RDS, SES, etc.)

---

## 🔒 **What They CANNOT Do**

Even with these permissions, GitHub Actions **cannot**:

1. ❌ **Access AWS Secrets Manager**
   - Secrets are accessed by pods via IRSA, not by GitHub Actions
   - GitHub Actions never sees secret values

2. ❌ **Modify AWS Infrastructure**
   - Cannot modify RDS, SES, VPC, Security Groups, etc.
   - Only Kubernetes resources in the cluster

3. ❌ **Access Production Database**
   - No database credentials
   - Database is only accessible from within the cluster

4. ❌ **Deploy on Pull Requests**
   - Workflow only runs on pushes to `main` branch
   - PRs only build (don't push or deploy)

5. ❌ **Modify Other Kubernetes Resources**
   - Only the `sdp-prod` Helm release in `default` namespace
   - Cannot modify ingress, secrets, or other deployments

---

## 🎯 **What They CAN Do**

With these permissions, GitHub Actions **can**:

1. ✅ **Deploy New Docker Images**
   - When you push to `main`, it builds a new image
   - Pushes image to ECR
   - Updates the `sdp-prod` deployment to use the new image

2. ✅ **Update Helm Configuration**
   - Can change image tags
   - Can update Helm values (via `--set` flags in workflow)
   - **Cannot** modify `production-values.yaml` file itself (that's in git)

3. ✅ **Roll Out Updates**
   - Kubernetes rolling update (zero-downtime)
   - Waits for deployment to complete

---

## 🔐 **Security Boundaries**

**GitHub Actions Workflow:**
- Only runs on pushes to `main` branch
- All actions are logged in CloudTrail
- Uses OIDC (no long-lived credentials)
- Role is scoped to specific cluster

**Kubernetes RBAC:**
- Can be restricted to specific namespace
- Can be restricted to specific resources (only Helm releases)
- All actions logged in Kubernetes audit logs

**What's Protected:**
- AWS Secrets Manager (not accessible to GitHub Actions)
- RDS Database (only accessible from pods)
- Other AWS services (no permissions)
- Other Kubernetes namespaces (if RBAC is restricted)

---

## 📝 **Summary**

**You're giving GitHub Actions:**
- Ability to deploy new code to production automatically
- Read-only access to EKS cluster info
- Kubernetes deployment permissions (can be restricted)

**You're NOT giving:**
- Access to secrets
- Access to databases
- Ability to modify AWS infrastructure
- Ability to modify other Kubernetes resources

**Risk Level:** Low-Medium (depends on RBAC configuration)
- **Low risk:** If RBAC is restricted to `default` namespace and Helm releases only
- **Medium risk:** If RBAC is `cluster-admin` (full access to cluster)

---

## ✅ **Recommendation**

Start with **restricted RBAC** (Option B):
- Only allow Helm deployments in `default` namespace
- Monitor the first few deployments
- Can always expand permissions later if needed

