# M1global SDP Backend

Production deployment of Stellar Disbursement Platform for M1global.

## Overview

This repository contains the production configuration and deployment files for the Stellar Disbursement Platform (SDP) running on AWS EKS.

## Documentation

- **[Production Setup Documentation](./docs/PRODUCTION_SETUP_DOCUMENTATION.md)** - Complete production deployment guide
- **[Project Context](./docs/PROJECT_CONTEXT.md)** - Project overview and role information
- **[CI/CD Improvements](./docs/CI_CD_IMPROVEMENTS.md)** - CI/CD improvement recommendations

## Quick Start

### Prerequisites
- AWS CLI configured with appropriate credentials
- kubectl configured for EKS cluster
- Helm 3.x installed

### Deployment

See [Production Setup Documentation](./docs/PRODUCTION_SETUP_DOCUMENTATION.md) for complete deployment instructions.

### Building Docker Images

**Automated (CI/CD):**
- Push to `main` branch → Automatically builds and pushes to ECR
- See [CI/CD Setup](./.github/workflows/SETUP_OIDC.md) for initial configuration

**Manual:**
Use the provided script for native AMD64 builds:

```bash
./scripts/build-and-push-ecr.sh
```

## Repository Structure

```
.
├── docs/                    # Documentation
├── helmchart/              # Helm charts
│   └── sdp/
│       └── production-values.yaml
├── scripts/               # Utility scripts
└── .github/                # GitHub Actions (CI/CD)
    └── workflows/
```

## Production Environment

- **Environment:** Production (Mainnet)
- **Region:** us-west-2
- **Cluster:** EKS
- **Domain:** sdp.lomalo.app

## Security

- All secrets stored in AWS Secrets Manager
- Access via IRSA (IAM Roles for Service Accounts)
- External Secrets Operator for Kubernetes secret sync
- All access logged in CloudTrail

## Support

For issues or questions, refer to the documentation or contact the DevOps team.
