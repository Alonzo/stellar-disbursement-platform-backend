## Executive Summary

This document serves as both operational documentation and an audit trail of the SDP Production deployment process. All security-sensitive operations are documented for transparency and compliance purposes. Below we will summarize the SDP Production setup for distributions on the Stellar Network.

- Environment: Production (Mainnet)
- Infrastructure: AWS EKS (Kubernetes) in `us-west-2`
- Database: RDS PostgreSQL (`sdp_prod_database`)
- Network: Stellar Mainnet (Public Global Stellar Network)
- Domain: `sdp.lomalo.app`
- Status: Operational

Key Security Features:
- IRSA (IAM Roles for Service Accounts) for secure AWS access
- All secrets stored in AWS Secrets Manager (encrypted)
- No hardcoded credentials in code or configuration
- Multi-account AWS architecture for security isolation
- OIDC provider configured for IRSA

## Setup

### Secrets & Key Management

Secrets Generation:
- Generated 15 production secrets in AWS CloudShell using `generate_prod_secrets.sh`
- Stellar Keys: Mainnet keypairs for distribution account (`GBVKJVVNICHHOD6G7JNAGOZKP2LQI2KGICEVVRKXN37LQKYGMCAK72VY`) and SEP-10 signing (`GBQURZZN7W5SWLEVIB3GSVSQ6OXHEAVY5WJHPIXM6SSTFUPMI6CLXWJ7`) using `Keypair.random` Go library
- Application Secrets: JWT secrets, EC256 private key, admin credentials, encryption passphrases
- All secrets stored in AWS Secrets Manager with naming convention `sdp/prod/{category}/{name}`

Secrets Access:
- Kubernetes secret `sdp-prod-backend-secrets` synced automatically via External Secrets Operator
- Secrets accessible to pods via environment variables

### Database

Production Database:
- Created fresh database `sdp_prod_database` on RDS PostgreSQL
- Created database user `sdp_prod_user` with appropriate permissions
- Connection string stored in Secrets Manager: `sdp/prod/db/url`
- Database in private subnet (not publicly accessible)

### Kubernetes Deployment

Helm Release:
- Deployed `sdp-prod` Helm release on EKS cluster
- Configured for Stellar Mainnet (network passphrase, Horizon URL)
- All pods running: `sdp-prod` (backend), `sdp-prod-dashboard` (frontend), `sdp-prod-tss` (transaction service)

Service Accounts & IRSA:
- Service account `sdp-core` created with IRSA annotation
- IAM role `sdp-core-irsa` allows pods to access AWS services (SES, Secrets Manager)
- OIDC provider configured: `arn:aws:iam::084034390838:oidc-provider/oidc.eks.us-west-2.amazonaws.com/id/1005116216DB2D42959106BD312B02DA`
- Purpose: Enables secure AWS access without storing credentials in pods

### Networking & Ingress

Ingress Configuration:
- Ingress `sdp-prod-dashboard` routes traffic to dashboard and API
- TLS certificates configured via Let's Encrypt (auto-renewal)
- Domain: `https://sdp.lomalo.app`
- Health check endpoint: `https://sdp.lomalo.app/health`

### Stellar Network Configuration

Distribution Accounts:

Main/Host Distribution Account (`GBVKJVVNICHHOD6G7JNAGOZKP2LQI2KGICEVVRKXN37LQKYGMCAK72VY`):
- Funded with 14.41 XLM on Stellar Mainnet (funded by Jim)
- Platform/host account used to fund tenant accounts
- Account verified and operational
- Stored in environment variable `DISTRIBUTION_PUBLIC_KEY`

Tenant Distribution Account (`GCRWA2XZSXK66W4YAMJ2MVMZB3CRQZRNFBVF326RG2CSHJSQOACRLE5O`):
- Automatically created for the default tenant during provisioning
- Funded with 5 XLM from the main distribution account
- This is the account shown in the SDP UI dashboard
- Each tenant gets its own distribution account, funded from the main account


Important Note: The UI displays the tenant's distribution account, not the main platform account. The main account is used behind the scenes to fund tenant accounts and operations. Also, channel accounts created automatically by application.

### Application Configuration

Tenant & User Setup:
- Default tenant created: `2f0a1a63-08b7-4e0a-90fa-63d1f068f9f4`
- Admin user created: `SDP@m1global.xyz`
- Password set via direct database update (bcrypt hash)

Security Features Enabled:
- MFA: Enabled and operational (emails sent via SES using IRSA)
- reCAPTCHA: Enabled for login protection
- TSS: Transaction Submission Service enabled and operational

### AWS Services Integration

SES (Simple Email Service):
- Configured for sending MFA codes and password reset emails
- Access via IRSA role (no static credentials)
- Sender ID: `noreply@sdp.lomalo.app`
- Production access: Approved and operational
- Production access granted with limits: 50,000 emails per day, 14 emails per second

Secrets Manager:
- 15 production secrets stored and encrypted
- Access via IRSA for pods, IAM policies for admin access
- All access logged in CloudTrail

## Secrets & Key Management

### Generation Process

Environment: AWS CloudShell (secure, ephemeral, isolated from local machines, auto-cleanup)  
Script: `generate_prod_secrets.sh`

Key Generation Methods:
- Stellar Keypairs: `create_and_fund.go` using `Keypair.random` Go library (Ed25519 keypairs for mainnet)
- Random Secrets: `openssl rand -hex` for hex strings, Python `secrets` module for passwords
- EC256 Private Key: `openssl ecparam` and `openssl ec` (PEM-encoded)

Storage: AWS Secrets Manager (`us-west-2`, account 084034390838)
- All secrets encrypted at rest (AWS KMS)
- Encryption in transit via TLS
- Naming: `sdp/prod/{category}/{name}`
- Categories: `admin/`, `db/`, `distribution/`, `sep10/`, `sep24/`, `ec256/`, `channel/`, `recaptcha/`, `ses/`

### Complete Secrets Inventory (15 total)

Mainnet Stellar Keys (4):
- `sdp/prod/distribution/seed` (Stellar Private Key, Distribution account mainnet, CloudShell)
- `sdp/prod/distribution/public` (Stellar Public Key, Distribution account mainnet, CloudShell) - Public: `GBVKJVVNICHHOD6G7JNAGOZKP2LQI2KGICEVVRKXN37LQKYGMCAK72VY`
- `sdp/prod/sep10/private` (Stellar Private Key, SEP-10 authentication mainnet, CloudShell)
- `sdp/prod/sep10/public` (Stellar Public Key, SEP-10 authentication mainnet, CloudShell) - Public: `GBQURZZN7W5SWLEVIB3GSVSQ6OXHEAVY5WJHPIXM6SSTFUPMI6CLXWJ7`

Application Secrets (7):
- `sdp/prod/sep24/jwtSecret` (Hex String 64 chars, SEP-24 JWT token signing, CloudShell)
- `sdp/prod/ec256/private` (PEM Format, EC256 private key for token signing, CloudShell)
- `sdp/prod/admin/account` (Hex String 32 chars, Admin API Basic Auth account ID, CloudShell)
- `sdp/prod/admin/apiKey` (Hex String 64 chars, Admin API Basic Auth key, CloudShell)
- `sdp/prod/admin/password` (Complex String 15 chars, Admin user password for SDP@m1global.xyz, CloudShell)
- `sdp/prod/distribution/encryptionPassphrase` (Stellar Seed, Encryption key for tenant distribution accounts, CloudShell)
- `sdp/prod/channel/encryptionPassphrase` (Stellar Seed, Encryption key for channel accounts, CloudShell)

Infrastructure Secrets (4):
- `sdp/prod/db/url` (Connection String, PostgreSQL database connection, Created with database)
- `sdp/prod/recaptcha/siteKey` (String, Google reCAPTCHA site key, Pre-configured)
- `sdp/prod/recaptcha/secretKey` (String, Google reCAPTCHA secret key, Pre-configured)
- `sdp/prod/ses/senderId` (Email Address, SES sender email address, Pre-configured)

### Access & Security

Access Methods:
- IRSA (Recommended): Pods use IRSA to access Secrets Manager (no credentials, automatic rotation)
- External Secrets Operator: Automatically syncing secrets from Secrets Manager to Kubernetes (operational)
- Manual Access: AWS CLI with `devops` profile or AWS Console (all access logged in CloudTrail)

Security:
- Encryption: At rest (AWS KMS), in transit (TLS)
- Access Control: IAM policies, IRSA roles (read-only, least privilege), admin via `devops` profile (MFA required)
- Audit: All access logged in CloudTrail, rotation events logged
- Rotation: Stellar keys (only if compromised), Admin credentials (quarterly), JWT secrets (annually), Database passwords (quarterly)

---

## IRSA Architecture

### Overview

IRSA (IAM Roles for Service Accounts) allows Kubernetes pods to assume IAM roles without storing AWS credentials. This is the recommended and most secure way for Kubernetes workloads to access AWS services.

### How It Works

1. OIDC Provider: EKS cluster OIDC issuer URL (`https://oidc.eks.us-west-2.amazonaws.com/id/1005116216DB2D42959106BD312B02DA`) trusted by IAM OIDC provider
2. Service Account Annotation: Kubernetes Service Account annotated with IAM role ARN (`arn:aws:iam::084034390838:role/sdp-core-irsa`)
3. Pod Identity: Kubernetes injects token into pod, pod uses token to assume IAM role via AWS STS
4. Temporary Credentials: AWS STS validates token, issues temporary credentials (auto-rotated, expire after 1 hour)

### Why It's Secure

- No Static Credentials: Temporary credentials generated on-demand (vs. storing access keys in environment variables)
- Automatic Rotation: Credentials auto-expire and refresh (no manual management)
- Least Privilege: Each service account has minimal IAM role permissions
- Audit Trail: All credential requests logged in CloudTrail
- Isolation: Compromised pod only exposes that pod's role permissions
- No Key Management: No keys to store, rotate, or manage

### Production Configuration

Service Account: `sdp-core` (namespace: `default`, IAM role: `arn:aws:iam::084034390838:role/sdp-core-irsa`)

IAM Role Permissions:
- `ses:SendEmail` (MFA codes, password reset emails)
- `ses:SendRawEmail` (formatted emails)
- `secretsmanager:GetSecretValue` (reading secrets if needed)

OIDC Provider:
- ARN: `arn:aws:iam::084034390838:oidc-provider/oidc.eks.us-west-2.amazonaws.com/id/1005116216DB2D42959106BD312B02DA`
- URL: `https://oidc.eks.us-west-2.amazonaws.com/id/1005116216DB2D42959106BD312B02DA`
- Client ID: `sts.amazonaws.com`
- Thumbprint: `9e99a48a9960b14926bb7f3b02e22da2b0ab7280`

Trust Policy: Allows `system:serviceaccount:default:sdp-core` to assume role via `sts:AssumeRoleWithWebIdentity` (validated by OIDC provider)

---

## Infrastructure & Configuration

### Compute

EKS Cluster: `us-west-2`, Kubernetes 1.27+, managed node group, 1 replica (cost-optimized, no autoscaling)

Pods:
- `sdp-prod`: Main backend application
- `sdp-prod-dashboard`: Frontend React application
- `sdp-prod-tss`: Transaction Submission Service (enabled)

### Database

RDS PostgreSQL: Instance `sdp-prod`, database `sdp_prod_database`, user `sdp_prod_user`
- Access: Private subnet only (not publicly accessible)
- Backup: Automated backups enabled
- Encryption: At rest and in transit
- Connection: `postgresql://sdp_prod_user:PASSWORD@sdp-prod.czaa4oi2ev4m.us-west-2.rds.amazonaws.com:5432/sdp_prod_database?sslmode=require` (stored in `sdp/prod/db/url`)

### Networking
- Ingress: Nginx Ingress Controller, domain `sdp.lomalo.app`, TLS via Let's Encrypt (auto-renewal), path-based routing (dashboard vs API), SPA support
- Load Balancing: AWS Application Load Balancer (via EKS ingress), health checks configured, SSL/TLS termination

### Configuration Files

Helm Values (`production-values.yaml`):
- Network: Mainnet enabled (`isPubnet: true`), Horizon URL `https://horizon.stellar.org`, distribution and SEP-10 public keys
- IRSA: Service account `sdp-core` with role ARN annotation
- Email: AWS SES (`noreply@sdp.lomalo.app`, region `us-west-2`)
- Security: MFA and reCAPTCHA enabled

Ingress (`dashboard-ingress-with-api-routing.yaml`): Routes dashboard/API, SPA routing, TLS termination, CORS
Service Account (`sdp-core-serviceaccount.yaml`): Defines Kubernetes Service Account with IRSA role ARN annotation

### Storage
Secrets: AWS Secrets Manager (15 production secrets, encrypted with AWS KMS)
Logs: CloudWatch Logs (30 day retention, configurable, structured JSON logging)

---

## Security

### Multi-Account Strategy

Account Separation:
- DevOps Account (084034390838): Application infrastructure, EKS cluster, RDS, Secrets Manager
- Security Admin Account (760081991559): Security services, IAM role creation, security monitoring
- Security Audit Account (457200661370): Aggregate security monitoring, read-only access

Rationale: Separation of concerns, least privilege, audit trail, security isolation

### Network Security
VPC: EKS cluster in private subnets, RDS in private subnets (not publicly accessible), ingress controller in public subnet
Security Groups: RDS allows access only from EKS cluster, EKS restricted to necessary ports, no public SSH access
TLS/SSL: All external traffic via HTTPS (TLS 1.2+), Let's Encrypt certificates (auto-renewal), database connections require SSL

### Access Control
Kubernetes: Service accounts with IRSA for AWS access, RBAC policies, no service account tokens in environment variables
AWS: IRSA for pod-level access (no static credentials), IAM roles with least-privilege policies, MFA required for admin access, SSO-based access for human users
Application: MFA enabled for all users, reCAPTCHA enabled for login, password complexity requirements, JWT token-based authentication

### Security Best Practices
- No Secrets in Version Control: All secrets in AWS Secrets Manager, none in Git or Helm values  
- Least Privilege Access: IRSA roles have minimal permissions, IAM policies follow least privilege  
- Encryption: Secrets encrypted at rest (AWS KMS), database encrypted at rest, all traffic encrypted in transit (TLS)  
- Audit Trail: CloudTrail logging for all AWS API calls, application logs for operations, secret access logged  
- Network Security: Private subnets for compute and database, security groups with minimal rules, no public SSH access  
- Authentication: MFA enabled, reCAPTCHA for login, JWT tokens for API authentication

### Security Considerations
- Temporary RDS Public Access: Enabled for password update (~5 minutes, restricted to IP 73.34.153.81/32, immediately disabled after, low risk)
- External Secrets Operator: Operational - Automatically syncing secrets from AWS Secrets Manager to Kubernetes via IRSA
- Admin Password Update: Direct database update using bcrypt hash (user created by `ensure-default` with unknown password, database access temporary)

### Security Monitoring

Active Monitoring:
- GuardDuty: Threat detection (us-west-2, us-east-2)
- Security Hub: Centralized security findings
- CloudTrail: API audit logging
- AWS Config: Compliance monitoring (8 rules active: access-keys-rotated, cloudtrail-enabled, ebs-encrypted-volumes, guardduty-enabled, iam-password-policy, rds-instance-public-access, s3-public-access-blocked, security-group-ssh-open)

Application Logging: CloudWatch Logs, structured logging with log levels, no sensitive data in logs

Audit Trail: All secret access logged, all IAM role assumptions logged, all database access logged (via application logs), all API calls logged (CloudTrail)


## Deployment & Operations

### Initial Deployment Steps
1. Generate Secrets: `./generate_prod_secrets.sh` (in AWS CloudShell)
2. Create Database: `./create_prod_database.sh`
3. Deploy Helm Chart: `helm install sdp-prod . --namespace default -f production-values.yaml`
4. Create Tenant: `kubectl exec -n default <pod-name> -- /app/stellar-disbursement-platform tenants ensure-default --default-tenant-owner-email SDP@m1global.xyz --default-tenant-owner-first-name "SDP" --default-tenant-owner-last-name "Admin"`
5. Update Password (if needed): Connect to database, update password hash using bcrypt, disconnect immediately
6. Configure OIDC Provider: `aws iam create-open-id-connect-provider --url https://oidc.eks.us-west-2.amazonaws.com/id/1005116216DB2D42959106BD312B02DA --client-id-list sts.amazonaws.com --thumbprint-list 9e99a48a9960b14926bb7f3b02e22da2b0ab7280 --region us-west-2 --profile devops`
7. Verify Deployment: `kubectl get pods -n default -l app.kubernetes.io/name=sdp-prod` and `curl https://sdp.lomalo.app/health`

### Update Process
- Helm Upgrade: `helm upgrade sdp-prod . --namespace default -f production-values.yaml`
- Rollback: `helm rollback sdp-prod <revision-number> --namespace default`

### Key Commands
- Check Deployment Status: `kubectl get pods,svc,ingress -n default -l app.kubernetes.io/instance=sdp-prod`
- View Logs: `kubectl logs -n default -l app.kubernetes.io/name=sdp-prod --tail=100`
- Access Secrets: `aws secretsmanager get-secret-value --secret-id sdp/prod/admin/password --region us-west-2 --profile devops --query SecretString --output text`
- Verify OIDC Provider: `aws iam list-open-id-connect-providers --region us-west-2 --profile devops`
- Check Health: `curl https://sdp.lomalo.app/health`


## Troubleshooting

### Known Issues

_No known issues at this time._

### Common Troubleshooting Steps

Pod Not Starting:
1. Check pod logs: `kubectl logs -n default <pod-name>`
2. Check pod events: `kubectl describe pod -n default <pod-name>`
3. Verify secrets exist: `kubectl get secret -n default sdp-prod-backend-secrets`
4. Check database connectivity

IRSA Not Working:
1. Verify OIDC provider exists: `aws iam list-open-id-connect-providers`
2. Check service account annotation: `kubectl get sa -n default sdp-core -o yaml`
3. Verify IAM role trust policy
4. Check pod logs for IRSA errors

Database Connection Issues:
1. Verify database is running: `aws rds describe-db-instances`
2. Check security group rules
3. Verify connection string in Secrets Manager
4. Test connection from pod: `kubectl exec -n default <pod-name> -- psql $DB_URL`

Email Sending Issues:
1. Verify SES domain verification
2. Check IRSA role has SES permissions
3. Verify OIDC provider is configured
4. Check SES sending limits (50,000/day, 14/second)
5. Review application logs for SES errors


## Post-Setup Configuration

### Trustlines Added

The following trustlines were added to the tenant distribution account (`GCRWA2XZSXK66W4YAMJ2MVMZB3CRQZRNFBVF326RG2CSHJSQOACRLE5O`):

- USDM0
  - Symbol: USDM0
  - Issuer: GDM5QWWXCMDTQMZAKMYTCI52LA7FWBHAZMU5NJLMIFHDJISJRP2ZWPKC
- USDM1
  - Symbol: USDM1
  - Issuer: GDM5QWWXCMDTQMZAKMYTCI52LA7FWBHAZMU5NJLMIFHDJISJRP2ZWPKC

Both assets share the same issuer address.

### Users Invited

The following users were invited to the platform with Owner role:

- Jim@m1global.xyz (Owner)
- Ken@m1global.xyz (Owner)
- Alonzo@starlingsdata.com (Owner)


