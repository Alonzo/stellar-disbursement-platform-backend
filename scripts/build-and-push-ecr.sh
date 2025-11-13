#!/bin/bash
# Automated ECR Build Script
# Run this from AWS CloudShell or an EC2 instance with Docker
# Much faster than local cross-compilation!

set -e

REGION="us-west-2"
AWS_ACCOUNT="084034390838"
IMAGE_NAME="stellar-disbursement-platform-backend"
GIT_COMMIT=$(git rev-parse --short HEAD 2>/dev/null || echo "local")
VERSION_TAG="${GIT_COMMIT}-$(date +%Y%m%d-%H%M%S)"
ECR_REPO="${AWS_ACCOUNT}.dkr.ecr.${REGION}.amazonaws.com/${IMAGE_NAME}"

echo "╔══════════════════════════════════════════════════════════════╗"
echo "║        Automated ECR Build (Native AMD64)                     ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo ""
echo "Repository: ${ECR_REPO}"
echo "Version Tag: ${VERSION_TAG}"
echo "Git Commit: ${GIT_COMMIT}"
echo ""

# Ensure we're in the right directory
if [ ! -f "Dockerfile" ]; then
    echo "❌ Error: Dockerfile not found. Are you in the backend directory?"
    exit 1
fi

# Login to ECR
echo "Step 1: Logging into ECR..."
aws ecr get-login-password --region "${REGION}" | \
    docker login --username AWS --password-stdin "${ECR_REPO}" || {
    echo "❌ ECR login failed. Check AWS credentials."
    exit 1
}

# Check if repository exists
echo ""
echo "Step 2: Verifying ECR repository..."
if ! aws ecr describe-repositories --repository-names "${IMAGE_NAME}" --region "${REGION}" &>/dev/null; then
    echo "Creating ECR repository..."
    aws ecr create-repository \
        --repository-name "${IMAGE_NAME}" \
        --region "${REGION}" \
        --image-scanning-configuration scanOnPush=true || {
        echo "❌ Failed to create repository"
        exit 1
    }
fi

# Build and push (native AMD64 - fast!)
echo ""
echo "Step 3: Building Docker image (native AMD64)..."
echo "This will be much faster than cross-compilation!"
docker build \
    -f Dockerfile \
    --build-arg GIT_COMMIT="${GIT_COMMIT}" \
    -t "${ECR_REPO}:${VERSION_TAG}" \
    -t "${ECR_REPO}:latest" \
    . || {
    echo "❌ Build failed"
    exit 1
}

echo ""
echo "Step 4: Pushing to ECR..."
docker push "${ECR_REPO}:${VERSION_TAG}"
docker push "${ECR_REPO}:latest"

echo ""
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║                    ✅ Build Complete!                          ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo ""
echo "Image: ${ECR_REPO}:${VERSION_TAG}"
echo "Latest: ${ECR_REPO}:latest"
echo ""
echo "Next step: Update Helm deployment with new image tag"
echo "  kubectl set image deployment/sdp-prod -n default sdp-prod=${ECR_REPO}:${VERSION_TAG}"
echo ""

