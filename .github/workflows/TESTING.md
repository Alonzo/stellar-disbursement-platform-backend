# Testing the CI/CD Pipeline

## Quick Start

### Step 1: Set Up OIDC (One-Time Setup)

Run the setup script:

```bash
cd /Users/alonzobenavides/Projects/m1global/m1global-sdp-backend
./.github/workflows/setup-oidc.sh
```

Or follow the manual steps in [SETUP_OIDC.md](./SETUP_OIDC.md)

### Step 2: Test the Workflow

**Option A: Manual Trigger (Recommended for first test)**

1. Go to GitHub: https://github.com/m1global/sdp-backend/actions
2. Click "Build and Push to ECR" workflow
3. Click "Run workflow" → Select "main" branch → Click "Run workflow"
4. Watch it run!

**Option B: Push a Test Commit**

```bash
cd /Users/alonzobenavides/Projects/m1global/m1global-sdp-backend
# Make a small change
echo "# Test" >> README.md
git add README.md
git commit -m "Test CI/CD pipeline"
git push origin main
```

### Step 3: Verify Build

1. **Check GitHub Actions:**
   - Go to: https://github.com/m1global/sdp-backend/actions
   - Click on the latest workflow run
   - Verify all steps complete successfully (green checkmarks)

2. **Check ECR:**
   ```bash
   aws ecr list-images \
     --repository-name stellar-disbursement-platform-backend \
     --region us-west-2 \
     --profile devops \
     --query 'imageIds[*].imageTag' \
     --output table
   ```
   
   You should see:
   - `latest` (updated)
   - A commit SHA tag (e.g., `abc1234...`)

3. **Check Security Scan:**
   - Go to GitHub repo → Security tab
   - Look for Trivy scan results

## Expected Workflow Duration

- **First build:** ~10-15 minutes (no cache)
- **Subsequent builds:** ~5-8 minutes (with Docker layer cache)

## Troubleshooting

### Workflow Fails: "No OpenIDConnect provider found"

**Solution:** Run the OIDC setup script:
```bash
./.github/workflows/setup-oidc.sh
```

### Workflow Fails: "Access Denied" when assuming role

**Check:**
1. OIDC provider exists: `aws iam list-open-id-connect-providers`
2. Role exists: `aws iam get-role --role-name github-actions-ecr-role`
3. Trust policy matches repo: Check `.github/workflows/setup-oidc.sh` has correct repo name

### Workflow Fails: "ECR push failed"

**Check:**
1. Role has ECR permissions: `aws iam list-attached-role-policies --role-name github-actions-ecr-role`
2. ECR repo exists: `aws ecr describe-repositories --repository-names stellar-disbursement-platform-backend`

### Build is Slow

**First build is always slow** (no cache). Subsequent builds will be faster thanks to Docker layer caching.

## What Happens on Each Push

1. ✅ Code is checked out
2. ✅ AWS credentials configured (via OIDC)
3. ✅ Docker Buildx set up with caching
4. ✅ Security scan (Trivy) runs
5. ✅ Docker image built (native AMD64)
6. ✅ Image pushed to ECR with two tags:
   - `latest`
   - Commit SHA (e.g., `abc1234...`)
7. ✅ Security scan results uploaded to GitHub

## Next Steps After Successful Test

1. ✅ Verify image in ECR
2. ✅ Update Helm deployment to use new image tag
3. ✅ Deploy to production (when ready)

## Manual Deployment After Build

After a successful build, update your Helm deployment:

```bash
# Get the latest commit SHA from GitHub Actions
COMMIT_SHA="abc1234..."  # Replace with actual SHA

# Update Helm values
cd helmchart/sdp
# Edit production-values.yaml:
#   image.tag: "abc1234..."

# Deploy
helm upgrade sdp-prod . --namespace default -f production-values.yaml
```

Or use the commit SHA directly:
```bash
helm upgrade sdp-prod . \
  --namespace default \
  -f production-values.yaml \
  --set image.tag="abc1234..."
```

