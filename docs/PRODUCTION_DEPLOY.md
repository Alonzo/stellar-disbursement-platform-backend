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

---

## Custom dashboard ingress (API routing)

Production uses a **custom** ingress file instead of the chart’s dashboard ingress: `helmchart/sdp/dashboard-ingress-with-api-routing.yaml`. The chart’s dashboard ingress is disabled in `production-values.yaml`.

This ingress routes API paths to the backend and the SPA to the dashboard. For `GET /disbursements/<uuid>` it sends:

- **With `Authorization` header** → backend (API call for draft/details).
- **Without** → dashboard (browser load or refresh of the detail URL).

If you change `dashboard-ingress-with-api-routing.yaml`, apply it manually (Helm does not apply this file):

```bash
# From repo root
kubectl apply -f helmchart/sdp/dashboard-ingress-with-api-routing.yaml
```

**Troubleshooting:** If the draft detail page shows "Could not load draft" or "Something went wrong" and the backend logs show no `GET /disbursements/<id>` request, the ingress is likely sending that API call to the dashboard (HTML) instead of the backend. Ensure the custom ingress routes `GET /disbursements/<uuid>` **with** `Authorization` to the backend (see the `if ($http_authorization != "")` block in the server-snippet).

---

## Adding a new tenant (multi-tenant)

When you want to add another tenant (e.g. a new subdomain like `newtenant.sdp.lomalo.app`) to the same deployment:

### 1. DNS

Add a concrete DNS record for the new subdomain pointing to the same target as the existing ingress load balancer (e.g. CNAME or A record for `newtenant.sdp.lomalo.app`).

### 2. Ingress

Edit `helmchart/sdp/dashboard-ingress-with-api-routing.yaml`:

- Add the new host to `spec.tls[0].hosts`.
- Add a new `spec.rules` entry with `host: newtenant.sdp.lomalo.app` and the same `http.paths` as the other tenant hosts (backend API and dashboard).
- Update the `nginx.ingress.kubernetes.io/cors-allow-origin` annotation to include the new origin (e.g. `https://newtenant.sdp.lomalo.app`).

Then apply:

```bash
kubectl apply -f helmchart/sdp/dashboard-ingress-with-api-routing.yaml
```

Cert-manager will issue/renew the TLS certificate for the new host. If TLS is not updated, see troubleshooting (e.g. delete the TLS secret so cert-manager re-issues).

### 3. Create the tenant (CLI, in-cluster)

Run from inside the cluster (e.g. `kubectl exec` into the backend pod). Use the same host distribution account and DB/env as the rest of the deployment.

```bash
kubectl exec -it deployment/sdp-prod -n default -c stellar-disbursement-platform -- \
  /app/stellar-disbursement-platform tenants create \
  --name newtenant \
  --owner-email "owner@example.com" \
  --owner-first-name "First" \
  --owner-last-name "Last" \
  --org-name "Display Name" \
  --base-url "https://newtenant.sdp.lomalo.app" \
  --ui-base-url "https://newtenant.sdp.lomalo.app" \
  --distribution-account-type "DISTRIBUTION_ACCOUNT.STELLAR.DB_VAULT" \
  --distribution-public-key "<HOST_DISTRIBUTION_PUBLIC_KEY>"
```

- `--name`: subdomain segment (e.g. `newtenant` → `newtenant.sdp.lomalo.app`).
- `--base-url` / `--ui-base-url`: must match the new subdomain; invitation emails use the tenant’s UI base URL for the forgot-password link.
- `--distribution-public-key`: host distribution account public key (from cluster secrets/env).

The tenant owner will receive an invitation email (if email is configured). If they don’t, they can set a password via `https://newtenant.sdp.lomalo.app/forgot-password`.

### 4. Add more users to a tenant

To add another user (e.g. Owner) to an existing tenant you need the **tenant ID** (UUID).

**Option A — List tenants (CLI, in-cluster)**

```bash
kubectl exec deployment/sdp-prod -n default -c stellar-disbursement-platform -- \
  /app/stellar-disbursement-platform tenants list
```

Use the `id` column for the tenant you want.

**Option B — Admin API (port-forward + Basic auth)**

Port-forward to the admin port (8003), then:

```bash
curl -s -u "ADMIN_ACCOUNT:ADMIN_API_KEY" "http://127.0.0.1:18003/tenants"
```

Use the `id` from the JSON for the desired tenant.

**Add the user (CLI, in-cluster)**

With password (interactive prompt):

```bash
kubectl exec -it deployment/sdp-prod -n default -c stellar-disbursement-platform -- \
  /app/stellar-disbursement-platform auth add-user "user@example.com" "First" "Last" \
  --tenant-id "<TENANT_UUID>" \
  --owner --roles owner --password
```

Non-interactive (set password via env; requires backend image that supports `SDP_ADD_USER_PASSWORD`):

```bash
kubectl exec deployment/sdp-prod -n default -c stellar-disbursement-platform -- \
  env SDP_ADD_USER_PASSWORD="YourSecurePassword12!" \
  /app/stellar-disbursement-platform auth add-user "user@example.com" "First" "Last" \
  --tenant-id "<TENANT_UUID>" --owner --roles owner --password
```

Without `--password`, the CLI generates a temporary password and sends an invitation email; the link in that email uses the tenant’s `sdp_ui_base_url` (correct subdomain).

### 5. Existing tenant URLs (e.g. MISSA / default)

If an existing tenant (e.g. the original “default” tenant used for MISSA) still has `base_url` / `sdp_ui_base_url` set to an old host (e.g. `https://sdp.lomalo.app`), invitation emails will contain the wrong link. Update the tenant to the correct subdomain via Admin API:

```bash
curl -X PATCH "http://127.0.0.1:18003/tenants/<TENANT_UUID>" \
  -u "ADMIN_ACCOUNT:ADMIN_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{"base_url": "https://missa.sdp.lomalo.app", "sdp_ui_base_url": "https://missa.sdp.lomalo.app"}"
```

(Use the tenant’s UUID and correct subdomain.)
