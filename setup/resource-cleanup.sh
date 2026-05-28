#!/bin/bash
# =============================================================================
# setup-auto-destroy.sh
# One-touch setup for Terraform Auto-Destroy via EventBridge + CodeBuild
# Triggers every 1 hour to destroy all Terraform-managed resources
#
# Usage: bash setup/setup-auto-destroy.sh
# =============================================================================

set -e  # Exit on any error

# ── Config ────────────────────────────────────────────────────────────────────
ACCOUNT_ID="597441489612"
REGION="ap-south-1"
ROLE_NAME="CodeBuild-TerraformDestroy-Role"
PROJECT_NAME="terraform-auto-destroy"
RULE_NAME="terraform-auto-destroy-hourly"
GITHUB_REPO="https://github.com/S-Shanthosh/Terraform-1"
BUILDSPEC_PATH="Infra/buildspec.yml"

echo ""
echo "=============================================="
echo "  Terraform Auto-Destroy Setup"
echo "  Account : ${ACCOUNT_ID}"
echo "  Region  : ${REGION}"
echo "=============================================="
echo ""

# ── Step 1: IAM Role ──────────────────────────────────────────────────────────
echo "[1/4] Creating IAM Role: ${ROLE_NAME}"

cat > /tmp/codebuild-trust.json << 'EOF'
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "codebuild.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF

if aws iam get-role --role-name "${ROLE_NAME}" > /dev/null 2>&1; then
  echo "    Role already exists, skipping creation."
else
  aws iam create-role \
    --role-name "${ROLE_NAME}" \
    --assume-role-policy-document file:///tmp/codebuild-trust.json \
    --no-cli-pager > /dev/null
  echo "    Role created."
fi

# ── Step 2: Attach Policy ─────────────────────────────────────────────────────
echo "[2/4] Attaching AdministratorAccess policy to role"

aws iam attach-role-policy \
  --role-name "${ROLE_NAME}" \
  --policy-arn arn:aws:iam::aws:policy/AdministratorAccess \
  --no-cli-pager > /dev/null 2>&1 || echo "    Policy already attached, skipping."

echo "    Policy attached."

# ── Step 3: CodeBuild Project ─────────────────────────────────────────────────
echo "[3/4] Creating CodeBuild project: ${PROJECT_NAME}"

if aws codebuild batch-get-projects --names "${PROJECT_NAME}" --region "${REGION}" --no-cli-pager \
    --query 'projects[0].name' --output text 2>/dev/null | grep -q "${PROJECT_NAME}"; then
  echo "    Project already exists, skipping creation."
else
  aws codebuild create-project \
    --name "${PROJECT_NAME}" \
    --description "Auto destroy all Terraform resources every 1 hour" \
    --source "{
      \"type\": \"GITHUB\",
      \"location\": \"${GITHUB_REPO}\",
      \"buildspec\": \"${BUILDSPEC_PATH}\",
      \"gitCloneDepth\": 1
    }" \
    --artifacts '{"type": "NO_ARTIFACTS"}' \
    --environment '{
      "type": "LINUX_CONTAINER",
      "image": "aws/codebuild/standard:7.0",
      "computeType": "BUILD_GENERAL1_SMALL",
      "environmentVariables": []
    }' \
    --service-role "arn:aws:iam::${ACCOUNT_ID}:role/${ROLE_NAME}" \
    --region "${REGION}" \
    --no-cli-pager > /dev/null
  echo "    CodeBuild project created."
fi

# ── Step 4: EventBridge Rule ──────────────────────────────────────────────────
echo "[4/4] Creating EventBridge rule: ${RULE_NAME}"

aws events put-rule \
  --name "${RULE_NAME}" \
  --schedule-expression "rate(1 hour)" \
  --state ENABLED \
  --description "Triggers Terraform auto-destroy every 1 hour" \
  --region "${REGION}" \
  --no-cli-pager > /dev/null

aws events put-targets \
  --rule "${RULE_NAME}" \
  --targets "[
    {
      \"Id\": \"terraform-destroy-target\",
      \"Arn\": \"arn:aws:codebuild:${REGION}:${ACCOUNT_ID}:project/${PROJECT_NAME}\",
      \"RoleArn\": \"arn:aws:iam::${ACCOUNT_ID}:role/${ROLE_NAME}\"
    }
  ]" \
  --region "${REGION}" \
  --no-cli-pager > /dev/null

echo "    EventBridge rule created and target attached."

# ── Summary ───────────────────────────────────────────────────────────────────
echo ""
echo "=============================================="
echo "  Setup Complete!"
echo "=============================================="
echo ""
echo "  IAM Role     : arn:aws:iam::${ACCOUNT_ID}:role/${ROLE_NAME}"
echo "  CodeBuild    : ${PROJECT_NAME}"
echo "  EventBridge  : ${RULE_NAME} (every 1 hour)"
echo ""
echo "  To trigger manually:"
echo "  aws codebuild start-build --project-name ${PROJECT_NAME} --region ${REGION} --no-cli-pager"
echo ""
echo "  All Terraform resources will be auto-destroyed every hour."
echo "=============================================="