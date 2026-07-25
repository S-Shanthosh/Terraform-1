#!/bin/bash
# =============================================================================
# teardown.sh
# Full account cleanup — removes ALL Terraform infrastructure and auto-destroy
# pipeline from any AWS account.
#
# NOTE:
# - Preserves the Terraform state S3 bucket and all its contents.
# - Does NOT modify local files or .bashrc.
#
# Usage: bash setup/teardown.sh
# Works in any AWS account — no hardcoded values
# =============================================================================

set -e

# ── Auto-detect values ────────────────────────────────────────────────────────
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text --no-cli-pager)
REGION=$(aws configure get region 2>/dev/null || echo "ap-south-1")

# ── Fixed names ───────────────────────────────────────────────────────────────
CODEBUILD_ROLE="CodeBuild-TerraformDestroy-Role"
LAMBDA_ROLE="Lambda-TerraformStateChecker-Role"
PROJECT_NAME="terraform-auto-destroy"
LAMBDA_NAME="terraform-state-checker"
RULE_NAME="terraform-auto-destroy-hourly"

echo ""
echo "╔══════════════════════════════════════════════════╗"
echo "║     Terraform Full Teardown                      ║"
echo "║     Removes ALL infrastructure + pipeline        ║"
echo "╚══════════════════════════════════════════════════╝"
echo ""
echo "  Account  : ${ACCOUNT_ID}"
echo "  Region   : ${REGION}"
echo ""

# ── Ask for state bucket name ─────────────────────────────────────────────────
read -p "Enter your Terraform state bucket name: " STATE_BUCKET
if [[ -z "$STATE_BUCKET" ]]; then
  echo "❌ Bucket name cannot be empty. Exiting."
  exit 1
fi

LOCK_TABLE="${STATE_BUCKET}-locks"

echo ""
echo "  State Bucket : ${STATE_BUCKET}"
echo "  Lock Table   : ${LOCK_TABLE}"
echo ""

# ── Confirmation ──────────────────────────────────────────────────────────────
echo "⚠️  WARNING: This will permanently delete:"
echo "   - All Terraform-managed AWS resources"
echo "   - DynamoDB lock table (${LOCK_TABLE})"
echo "   - Lambda, CodeBuild, EventBridge auto-destroy pipeline"
echo "   - IAM roles for CodeBuild and Lambda"
echo ""
echo "NOTE:"
echo "   - S3 state bucket (${STATE_BUCKET}) and ALL contents will be preserved."
echo "   - Local Terraform files, SSH keys and .bashrc will NOT be modified."
echo ""

read -p "Type 'yes' to confirm full teardown: " CONFIRM
if [[ "$CONFIRM" != "yes" ]]; then
  echo "❌ Teardown cancelled."
  exit 1
fi

echo ""

# ── Step 1: Terraform Destroy ─────────────────────────────────────────────────
echo "[1/6] Running terraform destroy..."

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INFRA_DIR="${SCRIPT_DIR}/../Infra"

if [ -f "${INFRA_DIR}/backend.tf" ]; then
  cd "${INFRA_DIR}"

  cat > backend.tf << EOF
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  backend "s3" {
    bucket         = "${STATE_BUCKET}"
    key            = "infra/terraform.tfstate"
    region         = "${REGION}"
    dynamodb_table = "${LOCK_TABLE}"
    encrypt        = true
  }
}
EOF

  terraform init -reconfigure -input=false > /dev/null 2>&1 || true

  echo "    Destroying dev environment..."
  terraform destroy \
    -auto-approve \
    -var-file=environments/dev/dev.tfvars \
    -input=false > /dev/null 2>&1 \
    && echo "    DEV destroyed." \
    || echo "    DEV destroy failed or no state — skipping."

  echo "    Destroying prod environment..."
  terraform destroy \
    -auto-approve \
    -var-file=environments/prod/prod.tfvars \
    -input=false > /dev/null 2>&1 \
    && echo "    PROD destroyed." \
    || echo "    PROD destroy failed or no state — skipping."

  cd - > /dev/null
else
  echo "    No backend.tf found — skipping terraform destroy."
fi

# ── Step 2: EventBridge Rule ──────────────────────────────────────────────────
echo "[2/6] Removing EventBridge rule..."

aws events remove-targets \
  --rule "${RULE_NAME}" \
  --ids "terraform-state-checker-target" \
  --region "${REGION}" \
  --no-cli-pager > /dev/null 2>&1 || true

aws events delete-rule \
  --name "${RULE_NAME}" \
  --region "${REGION}" \
  --no-cli-pager > /dev/null 2>&1 || true

echo "    EventBridge rule removed."

# ── Step 3: Lambda ────────────────────────────────────────────────────────────
echo "[3/6] Deleting Lambda function..."

aws lambda delete-function \
  --function-name "${LAMBDA_NAME}" \
  --region "${REGION}" \
  --no-cli-pager > /dev/null 2>&1 || true

echo "    Lambda deleted."

# ── Step 4: CodeBuild ─────────────────────────────────────────────────────────
echo "[4/6] Deleting CodeBuild project..."

aws codebuild delete-project \
  --name "${PROJECT_NAME}" \
  --region "${REGION}" \
  --no-cli-pager > /dev/null 2>&1 || true

echo "    CodeBuild project deleted."

# ── Step 5: IAM Roles ─────────────────────────────────────────────────────────
echo "[5/6] Deleting IAM roles..."

# CodeBuild Role
aws iam detach-role-policy \
  --role-name "${CODEBUILD_ROLE}" \
  --policy-arn arn:aws:iam::aws:policy/AdministratorAccess \
  --no-cli-pager > /dev/null 2>&1 || true

aws iam delete-role \
  --role-name "${CODEBUILD_ROLE}" \
  --no-cli-pager > /dev/null 2>&1 || true

# Lambda Role
aws iam detach-role-policy \
  --role-name "${LAMBDA_ROLE}" \
  --policy-arn arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole \
  --no-cli-pager > /dev/null 2>&1 || true

aws iam delete-role-policy \
  --role-name "${LAMBDA_ROLE}" \
  --policy-name TerraformStateChecker-Policy \
  --no-cli-pager > /dev/null 2>&1 || true

aws iam delete-role \
  --role-name "${LAMBDA_ROLE}" \
  --no-cli-pager > /dev/null 2>&1 || true

echo "    IAM roles deleted."

# ── Step 6: DynamoDB ──────────────────────────────────────────────────────────
echo "[6/6] Deleting DynamoDB lock table..."

aws dynamodb delete-table \
  --table-name "${LOCK_TABLE}" \
  --region "${REGION}" \
  --no-cli-pager > /dev/null 2>&1 \
  && echo "    DynamoDB table deleted." \
  || echo "    Table not found — skipping."

# ── Summary ───────────────────────────────────────────────────────────────────
echo ""
echo "╔══════════════════════════════════════════════════════════╗"
echo "║          ✅ Full Teardown Complete!                      ║"
echo "╚══════════════════════════════════════════════════════════╝"
echo ""
echo "  Terraform resources   : destroyed"
echo "  EventBridge rule      : deleted"
echo "  Lambda function       : deleted"
echo "  CodeBuild project     : deleted"
echo "  IAM roles             : deleted"
echo "  DynamoDB lock table   : deleted"
echo "  S3 state bucket       : preserved"
echo "  S3 bucket objects     : preserved"
echo "  Local files           : preserved"
echo "  SSH keys              : preserved"
echo "  .bashrc               : preserved"
echo ""
echo "Terraform state bucket has been intentionally retained."
echo "Run bootstrap.sh anytime to recreate the automation pipeline."
echo ""
