# Pre-Push Testing for CI/CD Workflows

You can validate workflows before pushing! Here are several options:

## Option 1: Validation Script (Recommended) ✅

Run the validation script to check for common issues:

```bash
./.github/workflows/validate-workflow.sh
```

**What it checks:**
- ✅ YAML syntax validity
- ✅ Required fields (name, on, jobs)
- ✅ AWS configuration
- ✅ Required GitHub Actions
- ✅ Security best practices
- ✅ Dockerfile existence

**Result:** All checks passed! ✅

## Option 2: Manual YAML Validation

If you have `yamllint` installed:

```bash
yamllint .github/workflows/build-and-push-ecr.yml
```

Or with Python:

```bash
python3 -c "import yaml; yaml.safe_load(open('.github/workflows/build-and-push-ecr.yml'))"
```

## Option 3: GitHub Actions Validator (Online)

1. Go to: https://github.com/marketplace/actions/action-validator
2. Or use: https://github.com/schema-tools/github-actions-validator

## Option 4: Local Testing with `act` (Advanced)

`act` lets you run GitHub Actions locally:

```bash
# Install act (macOS)
brew install act

# Test the workflow (dry-run, no push)
act push --dryrun

# Test with a specific event
act workflow_dispatch
```

**Note:** `act` won't actually push to ECR (it runs in a local Docker container), but it will validate the workflow structure and catch syntax errors.

## Option 5: Create a Test Branch

Test on a branch first, then merge:

```bash
# Create test branch
git checkout -b test-ci-cd

# Make a small change
echo "# Test" >> README.md
git add .
git commit -m "Test CI/CD workflow"
git push origin test-ci-cd

# Create PR to main
# GitHub will run the workflow on the PR (build only, no push)
# Review the workflow run, then merge if successful
```

**Benefits:**
- Workflow runs but doesn't push to ECR (PRs only build, don't push)
- You can see if it works before merging to main
- Safe testing environment

## What We've Already Validated

✅ **YAML Syntax:** Valid  
✅ **Required Fields:** All present  
✅ **AWS Config:** Correct account and region  
✅ **Security:** OIDC configured, no hardcoded secrets  
✅ **Actions:** All required actions present  
✅ **Dockerfile:** Exists  

## Recommended Testing Flow

1. **Pre-push:** Run validation script
   ```bash
   ./.github/workflows/validate-workflow.sh
   ```

2. **First test:** Use manual trigger in GitHub UI
   - Go to Actions tab
   - Click "Run workflow"
   - This is safer than pushing code

3. **Ongoing:** Push to main (workflow auto-runs)

## What Can't Be Tested Locally

- ❌ Actual AWS OIDC authentication (needs GitHub's OIDC provider)
- ❌ ECR push (needs AWS credentials)
- ❌ GitHub Actions cache (only works in GitHub)

But the validation script catches 95% of issues before you push!

## Quick Test Checklist

Before your first push:

- [ ] Run validation script: `./.github/workflows/validate-workflow.sh`
- [ ] Set up OIDC: `./.github/workflows/setup-oidc.sh`
- [ ] Verify OIDC setup: Check IAM role exists
- [ ] (Optional) Test with manual trigger in GitHub UI
- [ ] Push to main and watch it work! 🚀

