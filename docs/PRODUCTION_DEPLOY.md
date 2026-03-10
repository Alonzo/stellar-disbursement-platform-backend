# Production Deployment (sdp.lomalo.app)

How backend and frontend are deployed to EKS and how to verify or run a manual upgrade.

---

## Consolidation: one source of truth

- **Production deploys only from:** `m1global/sdp-backend` (branch `main`) and `m1global/sdp-frontend` (branch `main`). Do not use other forks or branches for release.
- **Backend repo (m1global/sdp-backend):** Holds the Helm chart, `production-values.yaml`, and backend code. Workflow on push to `main` builds the backend image and runs `helm upgrade` with `--set sdp.image.tag=$SHA`.
- **Frontend repo (m1global/sdp-frontend):** Holds the dashboard UI. Workflow on push to `main` builds the frontend image, checks out the backend repo for the chart, and runs `helm upgrade` with `--set dashboard.image.fullName=ECR:$SHA`.
- **Manual upgrades:** Always pass both `--set sdp.image.tag=<current-backend-sha>` and (if changing dashboard) `--set dashboard.image.fullName=...` when needed so one upgrade doesn’t revert the other. See “Manual Helm upgrade” below.

---

## Repositories and workflows

| Repo | Purpose | Trigger | What gets deployed |
|------|---------|---------|--------------------|
| **m1global/sdp-backend** | Backend + Helm chart + production values | Push to `main` | Backend image (ECR tag = commit SHA). Helm upgrade with `sdp.image.tag=$SHA`. Dashboard image is **not** changed (uses value from `production-values.yaml`). |
| **m1global/sdp-frontend** | Frontend (dashboard) UI | Push to `main` | Frontend image to ECR (`:sha` and `:latest`). Workflow checks out this repo for the chart, runs Helm upgrade with `dashboard.image.fullName=ECR:$SHA`. |

---

## Image sources

- **Backend (sdp-prod, sdp-prod-tss):** `084034390838.dkr.ecr.us-west-2.amazonaws.com/stellar-disbursement-platform-backend:<commit-sha>`  
  - Tag is set by the backend workflow on deploy.

- **Dashboard (sdp-prod-dashboard):** `084034390838.dkr.ecr.us-west-2.amazonaws.com/stellar-disbursement-platform-frontend:latest` (default in `production-values.yaml`).  
  - When the **frontend** workflow runs, it overrides with `dashboard.image.fullName=ECR:$SHA` so the new build is deployed.  
  - Using ECR (and `:latest` in values) ensures backend-only deploys do **not** revert the dashboard to the upstream Docker Hub image.

---

## Verifying what is running

From a machine with `kubectl` and AWS access (e.g. SSO: `aws sso login --profile devops`):

```bash
# List deployments and images
kubectl get deployment -n default -l app.kubernetes.io/instance=sdp-prod -o wide

# Backend image (commit SHA in tag)
kubectl get deployment sdp-prod -n default -o jsonpath='{.spec.template.spec.containers[0].image}'

# Dashboard image (should be ECR, not stellar/...:5.0.0)
kubectl get deployment sdp-prod-dashboard -n default -o jsonpath='{.spec.template.spec.containers[0].image}'

# Helm release values (what’s actually applied)
helm get values sdp-prod -n default
```

Check the dashboard image before assuming a frontend fix is live; if it still shows `stellar/stellar-disbursement-platform-frontend:5.0.0`, the UI is the upstream image, not the ECR build.

---

## Manual Helm upgrade

If you need to apply chart or value changes without a full CI run (e.g. after editing `production-values.yaml` or the chart):

```bash
# From this repo (m1global/sdp-backend)
helm upgrade sdp-prod helmchart/sdp \
  --namespace default \
  -f helmchart/sdp/production-values.yaml \
  --wait \
  --timeout 5m
```

To deploy a **specific** frontend image (e.g. after a frontend build):

```bash
helm upgrade sdp-prod helmchart/sdp \
  --namespace default \
  -f helmchart/sdp/production-values.yaml \
  --set dashboard.image.fullName=084034390838.dkr.ecr.us-west-2.amazonaws.com/stellar-disbursement-platform-frontend:<TAG> \
  --wait \
  --timeout 5m
```

Use `<TAG>` = git commit SHA from the frontend build (e.g. `b820f23`) or `latest`.

**Important:** If you run a manual upgrade with only `-f production-values.yaml` and no `--set` overrides, the backend will use `sdp.image.tag` from the values file (e.g. `latest-csp-fix-amd64`), which can revert the backend to an older image. To keep the current backend image, add `--set sdp.image.tag=<current-backend-sha>` (get the current tag from `kubectl get deployment sdp-prod -n default -o jsonpath='{.spec.template.spec.containers[0].image}'`).

---

## production-values.yaml

- **Dashboard image:** `dashboard.image.fullName` is set to the ECR frontend image with tag `latest`. Do not change this back to `stellar/stellar-disbursement-platform-frontend:5.0.0` or backend-only deploys will overwrite the custom dashboard with the upstream image.
- **Backend image:** `sdp.image.repository` and tag are in the SDP section; the backend workflow overrides the tag with the commit SHA on deploy.

For other production settings (CORS, ReCAPTCHA, single-tenant, etc.), see the comments in `helmchart/sdp/production-values.yaml`.
