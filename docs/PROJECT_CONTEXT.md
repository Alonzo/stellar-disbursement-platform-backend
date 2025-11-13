# M1global - Stellar Disbursement Platform Project Context

**Document Created:** 2025-01-XX  
**Purpose:** Preserve important project context and role information  
**Classification:** Internal Documentation

---

## Project Overview

### What We're Building

M1global is deploying and operating the **Stellar Disbursement Platform (SDP)**, an open-source platform that enables organizations to disburse bulk payments to recipients using the Stellar blockchain network.

**Key Capabilities:**
- Bulk payment disbursements to Stellar wallets
- Multi-tenant architecture (currently configured for single-tenant)
- Recipient wallet registration and verification
- Payment tracking and retry mechanisms
- Integration with Stellar network (SEP-10, SEP-24 protocols)
- Email and SMS notifications via AWS SES and Twilio
- Web dashboard for managing disbursements

**Domain:** `sdp.lomalo.app`  
**Organization Email Domain:** `m1global.xyz`

---

## Your Role & Responsibilities

### Primary Role: DevOps / Infrastructure Engineer

You are responsible for:

1. **Infrastructure Deployment & Management**
   - AWS EKS (Kubernetes) cluster management
   - RDS PostgreSQL database setup and migrations
   - Helm chart configuration and deployment
   - Ingress and TLS certificate management
   - IRSA (IAM Roles for Service Accounts) configuration

2. **Security & Compliance**
   - AWS GuardDuty monitoring setup
   - Security Hub configuration and standards
   - CloudTrail logging and audit trails
   - IAM policy management and least-privilege access
   - Secrets management via AWS Secrets Manager
   - Security incident response and documentation

3. **Application Configuration**
   - Stellar network configuration (testnet → mainnet migration)
   - Email service setup (AWS SES)
   - Database migrations and schema management
   - Environment variable and ConfigMap management
   - External Secrets Operator integration

4. **Production Readiness**
   - Mainnet deployment preparation
   - Secret migration and key generation
   - Production checklist and validation
   - Deployment automation and documentation

5. **Troubleshooting & Support**
   - Frontend/backend integration issues
   - Payment processing and retry mechanisms
   - Database connection and migration issues
   - User management and authentication flows

### Secondary Role: Security Lead

As the **Security Lead** for M1global, you are responsible for:

1. **Security Architecture & Strategy**
   - Designing and implementing multi-account security architecture
   - Establishing security monitoring and compliance frameworks
   - Defining security policies and procedures
   - Security incident response and documentation

2. **Security Monitoring & Auditing**
   - Comprehensive security audits across all AWS accounts
   - CCSS Level 2 compliance reviews
   - Multi-region security assessments
   - Security posture analysis and reporting

3. **IAM & Access Management**
   - Role-based access control (RBAC) design
   - IAM policy creation and management
   - Least-privilege access enforcement
   - Cross-account access configuration

4. **Security Service Configuration**
   - GuardDuty detector setup and management
   - Security Hub standards and compliance rules
   - CloudTrail logging and audit trails
   - AWS Config rules and compliance monitoring

5. **Security Automation**
   - Security audit script development
   - Automated security verification
   - Security event forwarding and aggregation
   - Log retention and compliance automation

---

## AWS Account Structure & Profiles

### Multi-Account Architecture

M1global uses a **multi-account AWS architecture** with role-based access control. You work across multiple accounts with different permission levels:

### Account 1: DevOps Account (084034390838)
**Purpose:** Primary application infrastructure and operations

**Profile:** `devops`
- **Role:** DevOps Engineer / Infrastructure Operations
- **Permissions:** Full access to application infrastructure
- **Use Cases:**
  - EKS cluster management
  - RDS database operations
  - Helm deployments
  - Secrets Manager operations
  - Application configuration
  - Kubernetes operations
  - SES email service management
  - IRSA role management

**Key Responsibilities:**
- Deploying and managing the SDP application
- Database migrations and management
- Kubernetes pod and service management
- Application secret management
- Infrastructure provisioning and updates

### Account 2: Security Admin Account (760081991559)
**Purpose:** Security operations, monitoring, and compliance

**Profile:** `SecurityAdmin-760081991559`
- **Role:** Security Administrator / Security Lead
- **Permissions:** Security service management + role creation
- **Use Cases:**
  - GuardDuty configuration and management
  - Security Hub setup and standards configuration
  - CloudTrail restoration and management
  - AWS Config rule management
  - IAM role and policy creation
  - Security incident response
  - Cross-account security monitoring
  - Lambda function creation for security automation
  - CloudWatch Log Groups for security events

**Key Responsibilities:**
- Security service configuration and management
- IAM role creation and policy management
- Security monitoring setup
- Compliance rule configuration
- Security incident investigation
- Cross-account security event aggregation

**Permission Evolution:**
- **Initially:** Read-only access (SecurityAudit policy only)
- **Upgraded:** Write permissions for security services (Security Hub, GuardDuty, CloudTrail, AWS Config)
- **Current:** Can create IAM roles, Lambda functions, and manage security services

### Account 3: Security Audit Account (457200661370)
**Purpose:** Aggregate security monitoring and read-only audit access

**Profile:** `SecurityAudit-457200661370` (or `PowerUserAccess-457200661370`)
- **Role:** Security Auditor / Aggregate Monitoring
- **Permissions:** Read-only security monitoring across accounts
- **Use Cases:**
  - Aggregate security findings from multiple accounts
  - Centralized security dashboard
  - Cross-account security event monitoring
  - Security compliance reporting
  - Read-only access to security services

**Key Responsibilities:**
- Aggregate monitoring of security events
- Centralized security reporting
- Cross-account security visibility
- Compliance and audit reporting

**Note:** This account is used for **aggregate monitoring** - it receives security events from other accounts but typically has read-only access.

### Account 4: Management Account (457200661370)
**Purpose:** AWS Organizations management and governance

**Profile:** `PowerUserAccess-457200661370`
- **Role:** Management Account Administrator
- **Permissions:** Organization-wide management
- **Use Cases:**
  - AWS Organizations configuration
  - Service Control Policies (SCPs)
  - Cross-account resource management
  - Organization-wide security policies

---

## Security Profile Usage Patterns

### When to Use Each Profile

**Use `devops` profile when:**
- Deploying application updates
- Managing Kubernetes resources
- Creating or updating secrets
- Database operations
- Application configuration changes
- Infrastructure provisioning
- SES email service management

**Use `SecurityAdmin-760081991559` profile when:**
- Configuring security services (GuardDuty, Security Hub, CloudTrail)
- Creating IAM roles and policies
- Setting up security monitoring
- Investigating security incidents
- Configuring compliance rules
- Creating Lambda functions for security automation
- Managing security event forwarding
- Cross-account security setup

**Use `SecurityAudit-457200661370` profile when:**
- Viewing aggregate security findings
- Generating security compliance reports
- Monitoring security events across accounts
- Read-only security audits
- Security posture assessment

**Use `PowerUserAccess-457200661370` profile when:**
- Organization-wide configuration
- Service Control Policy management
- Cross-account governance
- Management account operations

---

## Security Work Completed

### 1. Security Audit Framework

**Comprehensive Security Audit Scripts:**
- `aws_security_audit.sh`: Multi-region security data collection
- `security_analysis_helper.sh`: Analysis and issue identification
- `security_verification.sh`: Security service verification
- `focused_security_check.sh`: Targeted security checks

**Coverage:**
- **CCSS Level 2 Compliance**: Comprehensive checks for CCSS Level 2 requirements
- **Multi-Region**: Automatically discovers and audits all AWS regions
- **Security Domains**: IAM, KMS, Secrets Manager, Data Protection, Monitoring, Threat Detection, Network Security, Resilience, Compliance

**Output:**
- Structured audit reports by region and service
- Security findings summary
- Compliance status reports
- Detailed logs for analysis

### 2. Security Service Configuration

**GuardDuty:**
- Enabled in production (`us-west-2`) and development (`us-east-2`) regions
- Detectors configured and active
- Findings monitoring and investigation
- Publishing destinations configured

**Security Hub:**
- Enabled in both regions
- Standards enabled:
  - AWS Foundational Security Best Practices v1.0.0
  - CIS AWS Foundations Benchmark v1.2.0
  - AWS Resource Tagging Standard v1.0.0
- GuardDuty integration configured
- Centralized security findings dashboard

**CloudTrail:**
- Restored after deletion incident
- Multi-region logging configured
- S3 bucket logging active
- Event selectors configured
- Audit trail operational

**AWS Config:**
- Configuration recorders enabled
- 8 compliance rules active:
  1. `access-keys-rotated` - Access key rotation (90 days)
  2. `cloudtrail-enabled` - CloudTrail verification
  3. `ebs-encrypted-volumes` - EBS encryption check
  4. `guardduty-enabled` - GuardDuty verification
  5. `iam-password-policy` - Password policy compliance
  6. `rds-instance-public-access` - RDS public access check
  7. `s3-public-access-blocked` - S3 public access blocking
  8. `security-group-ssh-open` - SSH port exposure check

### 3. Security Automation

**Lambda Functions:**
- SES event forwarder: Forwards SES events to CloudWatch Logs for Security Hub
- Cross-account SNS subscription for security monitoring
- Security event aggregation

**Scripts:**
- `configure_guardduty_cloudwatch.sh`: GuardDuty CloudWatch integration
- `configure_security_hub_standards.sh`: Security Hub standards automation
- `restore_cloudtrail.sh`: CloudTrail restoration automation
- `apply_password_policy_all_accounts.sh`: Organization-wide password policy
- `review_log_retention.sh`: Log retention compliance
- `setup_ses_lambda_forwarder.sh`: SES security event forwarding

### 4. Security Incident Response

**CloudTrail Deletion Incident:**
- **Incident:** CloudTrail trail `org-trail` deleted in `us-east-2`
- **Detection:** GuardDuty alert (HIGH severity)
- **Response:** 
  - Investigated deletion event
  - Restored CloudTrail logging
  - Documented incident and response
  - Verified audit trail restoration

**Documentation:**
- `SECURITY_STATUS_REPORT_20251008.md`: Comprehensive security status
- `Security_Hub_Permission_Request.md`: Permission escalation documentation
- `SECURITY_AUDIT_README.md`: Security audit framework documentation

### 5. Cross-Account Security Setup

**SES Security Event Forwarding:**
- **Flow:** SES (devops account) → SNS (devops account) → Lambda (SecurityAdmin account) → CloudWatch Logs (SecurityAdmin account)
- **Purpose:** Aggregate SES security events for Security Hub monitoring
- **Implementation:** Cross-account SNS subscription and Lambda function

**Security Event Aggregation:**
- Centralized security monitoring across accounts
- Cross-account event forwarding configured
- Security Hub integration for unified view

### 6. Compliance & Governance

**Password Policies:**
- Organization-wide password policy applied
- Multi-account password policy enforcement
- Compliance verification

**Log Retention:**
- CloudWatch Log Groups retention policies
- Compliance with retention requirements
- Automated log retention configuration

**Security Standards:**
- CCSS Level 2 compliance framework
- Security best practices implementation
- Compliance rule automation

---

## Security Architecture Decisions

### Multi-Account Strategy

**Rationale:**
- **Separation of Concerns**: DevOps operations separate from security operations
- **Least Privilege**: Each account has only necessary permissions
- **Audit Trail**: Clear separation for compliance and auditing
- **Security Isolation**: Security operations isolated from application operations

**Account Separation:**
- **DevOps Account**: Application infrastructure (can be compromised without affecting security)
- **Security Admin Account**: Security services (isolated from application)
- **Security Audit Account**: Read-only monitoring (cannot modify anything)
- **Management Account**: Governance and organization-wide policies

### Role-Based Access Control

**Profile Naming Convention:**
- `{RoleName}-{AccountID}` format
- Clear indication of role and account
- Easy identification of permission level

**Permission Levels:**
1. **Read-Only (SecurityAudit)**: Aggregate monitoring, no modifications
2. **Security Admin**: Security service management, role creation
3. **DevOps**: Application infrastructure management
4. **PowerUser**: Organization-wide management

### Security Service Integration

**Centralized Monitoring:**
- Security Hub aggregates findings from GuardDuty, AWS Config, and other services
- Cross-account security event forwarding
- Unified security dashboard

**Automated Compliance:**
- AWS Config rules for continuous compliance monitoring
- Security Hub standards for compliance frameworks
- Automated security verification scripts

---

## Security Tools & Scripts

### Audit Scripts

**`aws_security_audit.sh`:**
- Comprehensive multi-region security audit
- CCSS Level 2 focused
- Structured output by region and service
- Usage: `./aws_security_audit.sh -p SecurityAdmin-760081991559`

**`security_analysis_helper.sh`:**
- Analyzes audit output
- Highlights security issues
- Generates summary reports

**`security_verification.sh`:**
- Verifies security services are operational
- Checks GuardDuty, CloudTrail, Security Hub, AWS Config
- Generates verification reports

### Configuration Scripts

**`configure_security_hub_standards.sh`:**
- Enables security standards in Security Hub
- Configures compliance frameworks
- Sets up GuardDuty integration

**`configure_guardduty_cloudwatch.sh`:**
- Configures GuardDuty CloudWatch integration
- Sets up publishing destinations

**`restore_cloudtrail.sh`:**
- Restores CloudTrail after incidents
- Configures multi-region logging

### Automation Scripts

**`setup_ses_lambda_forwarder.sh`:**
- Creates Lambda function for SES event forwarding
- Sets up cross-account SNS subscription
- Configures CloudWatch Logs integration

**`apply_password_policy_all_accounts.sh`:**
- Applies password policies across organization
- Multi-account policy enforcement

**`review_log_retention.sh`:**
- Reviews CloudWatch Log Groups retention
- Applies retention policies
- Compliance verification

---

## Infrastructure Architecture

### AWS Services

**Compute:**
- **EKS (Elastic Kubernetes Service)**: Container orchestration
- **EC2**: Underlying nodes for EKS cluster
- **Region**: Primary `us-west-2`, Secondary `us-east-2`

**Database:**
- **RDS PostgreSQL**: Multi-database setup
  - Testnet database: `sdp_database`
  - Production database: `sdp_prod_database`
- **Connection pooling**: Per-tenant connection management

**Networking:**
- **VPC**: Isolated network environment
- **Ingress Controller**: Nginx-based ingress with TLS
- **TLS Certificates**: Let's Encrypt (auto-renewal)

**Security & Monitoring:**
- **GuardDuty**: Threat detection
- **Security Hub**: Centralized security findings
- **CloudTrail**: API audit logging
- **AWS Config**: Compliance monitoring
- **CloudWatch Logs**: Application and security logging

**Secrets & Configuration:**
- **AWS Secrets Manager**: Encrypted secret storage
  - Naming convention: `sdp/{environment}/{category}/{name}`
  - Examples: `sdp/test/admin/password`, `sdp/prod/distribution/seed`
- **External Secrets Operator**: Kubernetes integration
- **IRSA (IAM Roles for Service Accounts)**: Pod-level AWS permissions

**Email Service:**
- **AWS SES**: Email sending service
- **Domain verification**: `sdp.lomalo.app` verified
- **IRSA integration**: `sdp-core-irsa` role with SES permissions
- **Status**: Sandbox mode (production access pending)

### Kubernetes Architecture

**Namespaces:**
- `default`: Primary namespace for SDP deployment

**Deployments:**
- **SDP Core Service**: Main backend application
  - Admin API (port 8003)
  - Dashboard API (port 8001)
  - Message Service
  - Wallet Registration UI
  - SEP-10/SEP24 endpoints
- **SDP Dashboard**: Frontend React application
- **TSS (Transaction Submission Service)**: Stellar transaction processing

**Services:**
- Service accounts with IRSA annotations
- ConfigMaps for environment configuration
- Secrets (synced from AWS Secrets Manager)

**Ingress:**
- Nginx-based ingress controller
- Path-based routing (dashboard vs API)
- TLS termination
- SPA routing support for frontend

### Stellar Network Integration

**Current Network:** Testnet  
**Target Network:** Mainnet (Public Global Stellar Network)

**Key Components:**
- **Distribution Account**: Hot wallet for disbursements
- **SEP-10 Signing Keys**: Authentication challenge signing
- **SEP-24 JWT Secret**: Interactive deposit flow tokens
- **Channel Accounts**: For transaction submission
- **Horizon API**: Stellar network interaction

**Network Configuration:**
- Testnet: `Test SDF Network ; September 2015`
- Mainnet: `Public Global Stellar Network ; September 2015`
- Horizon URLs configured per environment

---

## Current Project Status

### Deployment Status

**Testnet Environment:**
- ✅ Fully deployed and operational
- ✅ All services running
- ✅ Database migrations complete
- ✅ User management functional
- ✅ Payment processing working

**Production/Mainnet Environment:**
- ⚠️ Deployment created but waiting for distribution account funding
- ✅ All secrets created in AWS Secrets Manager
- ✅ Database created (`sdp_prod_database`)
- ✅ Helm release created (`sdp-prod`)
- ⏳ TSS temporarily disabled (will re-enable after funding)

### Key Work Completed

1. **Security Infrastructure**
   - GuardDuty enabled in both regions
   - Security Hub configured with compliance standards
   - CloudTrail logging restored and configured
   - AWS Config rules implemented (8 compliance rules)
   - Security incident documentation and response procedures

2. **Email Service Setup**
   - SES domain verification (`sdp.lomalo.app`)
   - IRSA role permissions configured
   - Lambda forwarder for SES events to CloudWatch
   - Cross-account SNS subscription for security monitoring
   - Production access requested (pending AWS approval)

3. **Database Management**
   - Testnet database operational
   - Production database created
   - Migration strategy documented
   - Connection pooling configured

4. **Secrets Management**
   - 15 production secrets created in AWS Secrets Manager
   - Secret naming convention established
   - External Secrets Operator configured
   - Manual secret creation documented (OIDC workaround)

5. **Frontend/Backend Integration**
   - Ingress routing configured for SPA support
   - API endpoint routing working
   - Browser refresh handling implemented
   - Token refresh mechanism documented

6. **Production Readiness**
   - Mainnet checklist created
   - Secret migration plan documented
   - Deployment procedures documented
   - Break glass account procedures established

---

## Key Workflows & Processes

### User Management

**Admin Account:**
- Email: `SDP@m1global.xyz` (break glass account)
- Role: Owner (full administrative access)
- Password: Stored in AWS Secrets Manager
- Creation: Via CLI command in Kubernetes pod

**User Roles:**
- **Owner**: Full permissions, user management
- **Financial Controller**: All permissions except user management
- **Developer**: Configuration permissions, statistics access
- **Business**: Read-only permissions
- **Initiator**: Create/save disbursements (cannot submit)
- **Approver**: Submit disbursements (cannot create)

**User Creation:**
```bash
# Via Kubernetes CLI
kubectl exec -n default <pod-name> -- \
  /app/stellar-disbursement-platform auth add-user \
  <email> <first-name> <last-name> \
  --tenant-id default \
  --roles owner \
  --password <password>
```

### Payment Processing

**Payment States:**
- `DRAFT` → `READY` → `PENDING` → `SUCCESS` or `FAILED`
- `FAILED` → `READY` (via manual retry)

**Retry Mechanism:**
- **Manual only** - No automatic retries
- API endpoint: `PATCH /payments/retry`
- Requires `WritePayments` permission
- Resets payment to `READY` status for scheduler pickup

**Payment Scheduler:**
- Runs every `SCHEDULER_PAYMENT_JOB_SECONDS` (default: 10 seconds)
- Picks up `READY` payments
- Submits to Transaction Submission Service (TSS)
- TSS processes on Stellar network

### Secret Management

**Naming Convention:**
```
sdp/{environment}/{category}/{name}
```

**Environments:**
- `test`: Testnet environment
- `prod`: Production/mainnet environment

**Categories:**
- `admin`: Admin account credentials
- `db`: Database connection strings
- `distribution`: Distribution account keys
- `sep10`: SEP-10 authentication keys
- `sep24`: SEP-24 JWT secrets
- `ec256`: EC256 private keys
- `channel`: Channel account encryption
- `recaptcha`: reCAPTCHA keys
- `ses`: SES configuration

**Access:**
- Via AWS Secrets Manager console
- Via AWS CLI with `devops` profile
- Synced to Kubernetes via External Secrets Operator
- Manual creation documented for OIDC workaround

### Deployment Process

**Helm Chart Location:**
```
stellar-disbursement-platform-backend/helmchart/sdp/
```

**Key Files:**
- `production-values.yaml`: Production configuration
- `dashboard-ingress-with-api-routing.yaml`: Ingress configuration

**Deployment Command:**
```bash
helm upgrade sdp-prod \
  ./stellar-disbursement-platform-backend/helmchart/sdp \
  --namespace default \
  -f ./stellar-disbursement-platform-backend/helmchart/sdp/production-values.yaml
```

**Configuration Areas:**
- Network settings (testnet vs mainnet)
- Resource limits and replicas
- Environment variables
- Secret references
- Service account annotations
- Ingress rules

---

## Important Decisions & Configurations

### Database Strategy

**Decision:** Fresh production database (clean separation from testnet)

**Rationale:**
- Clean production environment
- Clear separation of testnet vs mainnet data
- Best practice for production deployments
- Avoids data confusion

**Implementation:**
- New database: `sdp_prod_database`
- New database user: `sdp_prod_user`
- Fresh migrations on production database
- Testnet database (`sdp_database`) remains intact

### Secret Migration Strategy

**Decision:** Generate new values for all secrets (except database URL which is new)

**Rationale:**
- Security best practice
- Mainnet keys must be new (cannot reuse testnet keys)
- Fresh start for production environment
- Reduces risk of key leakage

**Key Secrets:**
- **Must Generate New:** Distribution keys, SEP-10 keys (mainnet keypairs)
- **Should Generate New:** JWT secrets, EC256 keys, admin credentials
- **Create New:** Database connection string (new database)

### Ingress Routing Strategy

**Decision:** Path-based routing with SPA support

**Implementation:**
- Disbursement detail pages (`/disbursements/{uuid}`) → Dashboard (SPA)
- API endpoints (`/disbursements/{uuid}/receivers`, etc.) → Backend API
- Browser refresh on detail pages handled gracefully
- All API calls route correctly to backend

### Security Monitoring Strategy

**Decision:** Multi-layer security monitoring

**Implementation:**
- GuardDuty: Threat detection
- Security Hub: Centralized findings
- CloudTrail: Audit logging
- AWS Config: Compliance monitoring
- CloudWatch: Application logs
- SES event forwarding: Email security monitoring

### Email Service Strategy

**Decision:** AWS SES with IRSA (no static credentials)

**Rationale:**
- No secrets to manage
- Automatic credential rotation
- More secure than static credentials
- Leverages existing IRSA infrastructure

**Configuration:**
- IRSA role: `sdp-core-irsa`
- Permissions: `ses:SendEmail`, `ses:SendRawEmail`
- Domain verified: `sdp.lomalo.app`
- Status: Sandbox mode (production access pending)

---

## Technology Stack

### Backend
- **Language:** Go (Golang)
- **Framework:** Custom HTTP server
- **Database:** PostgreSQL (RDS)
- **ORM/Migrations:** Custom migration system
- **Stellar SDK:** Stellar Go SDK

### Frontend
- **Framework:** React with TypeScript
- **Build Tool:** Webpack/Vite
- **Styling:** SCSS
- **State Management:** React Context/Redux

### Infrastructure
- **Container Orchestration:** Kubernetes (EKS)
- **Package Management:** Helm
- **Container Registry:** Docker Hub / AWS ECR
- **Ingress:** Nginx Ingress Controller
- **TLS:** Let's Encrypt (cert-manager)

### Cloud Services
- **Compute:** AWS EKS
- **Database:** AWS RDS (PostgreSQL)
- **Secrets:** AWS Secrets Manager
- **Email:** AWS SES
- **Monitoring:** AWS CloudWatch, GuardDuty, Security Hub
- **Logging:** AWS CloudWatch Logs

### Development Tools
- **Version Control:** Git
- **CLI Tools:** AWS CLI, kubectl, helm, stellar CLI
- **Scripting:** Bash, Go (for key generation)

---

## Key Files & Locations

### Configuration Files

**Helm Charts:**
- `stellar-disbursement-platform-backend/helmchart/sdp/production-values.yaml`
- `stellar-disbursement-platform-backend/helmchart/sdp/dashboard-ingress-with-api-routing.yaml`

**Documentation:**
- `DEPLOYMENT_STATUS.md`: Current deployment status
- `MAINNET_PRODUCTION_CHECKLIST.md`: Mainnet readiness checklist
- `SECRETS_MIGRATION_SUMMARY.md`: Secret migration details
- `BREAK_GLASS_ACCOUNT.md`: Emergency access procedures
- `TODAY_SUMMARY.md`: Recent work summary
- `PAYMENT_RETRY_MECHANISM.md`: Payment retry documentation

**Scripts:**
- `deploy_production.sh`: Production deployment script
- `create_prod_database.sh`: Database creation script
- `generate_prod_secrets.sh`: Secret generation script
- `create_first_user.sh`: User creation script

### Source Code

**Backend:**
- `stellar-disbursement-platform-backend/`: Main backend repository
- `internal/`: Internal application code
- `cmd/`: CLI commands
- `db/`: Database migrations

**Frontend:**
- `stellar-disbursement-platform-frontend/`: Frontend React application

---

## Common Tasks & Commands

### Check Pod Status
```bash
kubectl get pods -n default -l app.kubernetes.io/name=sdp-prod
```

### View Logs
```bash
kubectl logs -n default -l app.kubernetes.io/name=sdp-prod --tail=100
```

### Access Secrets
```bash
aws secretsmanager get-secret-value \
  --secret-id sdp/prod/admin/password \
  --region us-west-2 \
  --profile devops \
  --query SecretString --output text
```

### Database Connection
```bash
# Connection string stored in: sdp/prod/db/url
# Format: postgresql://user:password@host:port/database
```

### Helm Upgrade
```bash
cd stellar-disbursement-platform-backend/helmchart/sdp
helm upgrade sdp-prod . \
  --namespace default \
  -f production-values.yaml
```

### Create User
```bash
POD_NAME=$(kubectl get pods -n default -l app.kubernetes.io/name=sdp-prod -o jsonpath='{.items[0].metadata.name}')
PASSWORD=$(aws secretsmanager get-secret-value --secret-id sdp/prod/admin/password --region us-west-2 --profile devops --query SecretString --output text)

kubectl exec -n default $POD_NAME -- \
  /app/stellar-disbursement-platform auth add-user \
  SDP@m1global.xyz "SDP" "Admin" \
  --tenant-id default \
  --owner \
  --password <<< "$PASSWORD"
```

---

## Important Notes

### Security
- All secrets stored in AWS Secrets Manager (encrypted)
- IRSA used for pod-level AWS permissions (no static credentials)
- Break glass account for emergency access only
- All security events logged to CloudTrail
- GuardDuty and Security Hub monitoring active

### Network Configuration
- Currently on Stellar **testnet**
- Mainnet migration requires:
  - New Stellar keypairs (mainnet accounts)
  - Network passphrase update
  - Horizon URL update
  - Distribution account funding

### Database
- Separate databases for testnet and production
- Fresh production database (no testnet data)
- Migrations run automatically on pod startup
- Connection pooling configured per tenant

### Email Service
- SES configured and domain verified
- IRSA permissions attached
- Currently in sandbox mode (can only send to verified emails)
- Production access requested (pending AWS approval)

### Payment Processing
- Manual retry only (no automatic retries)
- Payment scheduler runs every 10 seconds (configurable)
- TSS handles Stellar network transactions
- Failed payments require manual intervention

---

## Next Steps (When Returning)

1. **Production Deployment:**
   - Fund distribution account on mainnet
   - Verify pod initialization completes
   - Create first admin user
   - Re-enable TSS
   - Verify all services running

2. **Mainnet Migration (When Ready):**
   - Update network configuration in `production-values.yaml`
   - Verify all mainnet keys are in Secrets Manager
   - Test with small disbursement
   - Monitor logs closely

3. **SES Production Access:**
   - Wait for AWS approval email
   - No code changes needed (already configured)
   - Test email sending after approval

4. **Monitoring:**
   - Set up CloudWatch alarms
   - Review Security Hub findings
   - Monitor payment success rates
   - Review application logs

---

## Contact & Resources

**Project Repository:**
- Backend: `stellar-disbursement-platform-backend/`
- Frontend: `stellar-disbursement-platform-frontend/`

**Documentation:**
- Stellar SDP Docs: https://developers.stellar.org/platforms/stellar-disbursement-platform
- AWS Profile: `devops` (SSO-based)
- Kubernetes Context: EKS cluster in `us-west-2`

**Key URLs:**
- Dashboard: `https://sdp.lomalo.app`
- Health Check: `https://sdp.lomalo.app/health`
- Admin API: Port 8003 (internal)

---

**This document preserves project context without exposing sensitive credentials or keys. All secrets are stored in AWS Secrets Manager and should be accessed through proper authentication channels.**

