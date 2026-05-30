#!/bin/bash
# =============================================================================
# resource-cleanup.sh
# One-touch setup for Terraform Auto-Destroy
# Architecture: EventBridge → Lambda (check S3 state) → CodeBuild (tf destroy)
#
# Usage: bash setup/resource-cleanup.sh
# Works in any AWS account — no hardcoded values
# =============================================================================

set -e

# ── Auto-detect values ────────────────────────────────────────────────────────
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text --no-cli-pager)
REGION=$(aws configure get region 2>/dev/null || echo "ap-south-1")
GITHUB_REPO="https://github.com/S-Shanthosh/Terraform-1"

# ── Fixed names ───────────────────────────────────────────────────────────────
CODEBUILD_ROLE="CodeBuild-TerraformDestroy-Role"
LAMBDA_ROLE="Lambda-TerraformStateChecker-Role"
PROJECT_NAME="terraform-auto-destroy"
LAMBDA_NAME="terraform-state-checker"
RULE_NAME="terraform-auto-destroy-hourly"
BUILDSPEC_PATH="Infra/buildspec.yml"
STATE_KEY="infra/terraform.tfstate"

echo ""
echo "╔══════════════════════════════════════════════════╗"
echo "║     Terraform Auto-Destroy Setup                 ║"
echo "║     EventBridge → Lambda → CodeBuild             ║"
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

# ── Step 1: CodeBuild IAM Role ────────────────────────────────────────────────
echo "[1/7] Creating CodeBuild IAM Role..."

cat > /tmp/codebuild-trust.json << 'EOF'
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": { "Service": "codebuild.amazonaws.com" },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF

if aws iam get-role --role-name "${CODEBUILD_ROLE}" --no-cli-pager > /dev/null 2>&1; then
  echo "    Already exists, skipping."
else
  aws iam create-role \
    --role-name "${CODEBUILD_ROLE}" \
    --assume-role-policy-document file:///tmp/codebuild-trust.json \
    --no-cli-pager > /dev/null
  echo "    Role created."
fi

aws iam attach-role-policy \
  --role-name "${CODEBUILD_ROLE}" \
  --policy-arn arn:aws:iam::aws:policy/AdministratorAccess \
  --no-cli-pager > /dev/null 2>&1 || true
echo "    AdministratorAccess attached."

# ── Step 2: Lambda IAM Role ───────────────────────────────────────────────────
echo "[2/7] Creating Lambda IAM Role..."

cat > /tmp/lambda-trust.json << 'EOF'
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": { "Service": "lambda.amazonaws.com" },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF

if aws iam get-role --role-name "${LAMBDA_ROLE}" --no-cli-pager > /dev/null 2>&1; then
  echo "    Already exists, skipping."
else
  aws iam create-role \
    --role-name "${LAMBDA_ROLE}" \
    --assume-role-policy-document file:///tmp/lambda-trust.json \
    --no-cli-pager > /dev/null
  echo "    Role created."
fi

aws iam attach-role-policy \
  --role-name "${LAMBDA_ROLE}" \
  --policy-arn arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole \
  --no-cli-pager > /dev/null 2>&1 || true

# Inline policy for S3 read + CodeBuild start
cat > /tmp/lambda-policy.json << EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": ["s3:GetObject", "s3:HeadObject"],
      "Resource": "arn:aws:s3:::${STATE_BUCKET}/${STATE_KEY}"
    },
    {
      "Effect": "Allow",
      "Action": ["codebuild:StartBuild"],
      "Resource": "arn:aws:codebuild:${REGION}:${ACCOUNT_ID}:project/${PROJECT_NAME}"
    }
  ]
}
EOF

aws iam put-role-policy \
  --role-name "${LAMBDA_ROLE}" \
  --policy-name TerraformStateChecker-Policy \
  --policy-document file:///tmp/lambda-policy.json \
  --no-cli-pager > /dev/null
echo "    Policies attached."

# ── Step 3: Lambda Function ───────────────────────────────────────────────────
echo "[3/7] Deploying Lambda function..."

cat > /tmp/check_and_destroy.py << PYEOF
import boto3
import json
import logging
import os
from datetime import datetime, timezone, timedelta

logger = logging.getLogger()
logger.setLevel(logging.INFO)

S3_BUCKET         = os.environ["STATE_BUCKET"]
S3_KEY            = os.environ["STATE_KEY"]
CODEBUILD_PROJECT = os.environ["CODEBUILD_PROJECT"]
REGION            = os.environ["AWS_REGION"]
TTL_HOURS         = int(os.environ.get("TTL_HOURS", "1"))

def lambda_handler(event, context):
    s3        = boto3.client("s3", region_name=REGION)
    codebuild = boto3.client("codebuild", region_name=REGION)

    # Step 1: Check if state file exists and get LastModified
    try:
        response      = s3.head_object(Bucket=S3_BUCKET, Key=S3_KEY)
        last_modified = response["LastModified"]
        logger.info(f"tfstate last modified: {last_modified}")
    except Exception as e:
        logger.info(f"No tfstate found or error: {str(e)}. Nothing to destroy.")
        return {"status": "skipped", "reason": "no state file"}

    # Step 2: Check if TTL has passed since last modify
    now     = datetime.now(timezone.utc)
    elapsed = now - last_modified
    logger.info(f"Time elapsed since last apply: {elapsed}")

    if elapsed < timedelta(hours=TTL_HOURS):
        remaining = timedelta(hours=TTL_HOURS) - elapsed
        logger.info(f"Within TTL. {remaining} remaining. Skipping.")
        return {
            "status"   : "skipped",
            "reason"   : "within TTL",
            "elapsed"  : str(elapsed),
            "remaining": str(remaining)
        }

    # Step 3: Trigger CodeBuild
    logger.info(f"TTL exceeded. Triggering CodeBuild destroy...")
    build    = codebuild.start_build(projectName=CODEBUILD_PROJECT)
    build_id = build["build"]["id"]
    logger.info(f"CodeBuild triggered. Build ID: {build_id}")

    return {
        "status"  : "triggered",
        "build_id": build_id,
        "elapsed" : str(elapsed)
    }
PYEOF

cd /tmp && zip -q check_and_destroy.zip check_and_destroy.py

# Check if Lambda already exists
if aws lambda get-function --function-name "${LAMBDA_NAME}" --region "${REGION}" --no-cli-pager > /dev/null 2>&1; then
  echo "    Already exists, updating code..."
  aws lambda update-function-code \
    --function-name "${LAMBDA_NAME}" \
    --zip-file fileb:///tmp/check_and_destroy.zip \
    --region "${REGION}" \
    --no-cli-pager > /dev/null

  aws lambda update-function-configuration \
    --function-name "${LAMBDA_NAME}" \
    --environment "Variables={STATE_BUCKET=${STATE_BUCKET},STATE_KEY=${STATE_KEY},CODEBUILD_PROJECT=${PROJECT_NAME},TTL_HOURS=1}" \
    --region "${REGION}" \
    --no-cli-pager > /dev/null
else
  # Wait for IAM role to propagate
  echo "    Waiting for IAM role to propagate..."
  sleep 10

  aws lambda create-function \
    --function-name "${LAMBDA_NAME}" \
    --runtime python3.12 \
    --role "arn:aws:iam::${ACCOUNT_ID}:role/${LAMBDA_ROLE}" \
    --handler check_and_destroy.lambda_handler \
    --zip-file fileb:///tmp/check_and_destroy.zip \
    --timeout 30 \
    --environment "Variables={STATE_BUCKET=${STATE_BUCKET},STATE_KEY=${STATE_KEY},CODEBUILD_PROJECT=${PROJECT_NAME},TTL_HOURS=1}" \
    --region "${REGION}" \
    --no-cli-pager > /dev/null
fi
echo "    Lambda deployed."

# ── Step 4: CodeBuild Project ─────────────────────────────────────────────────
echo "[4/7] Creating CodeBuild project..."

if aws codebuild batch-get-projects \
    --names "${PROJECT_NAME}" \
    --region "${REGION}" \
    --no-cli-pager \
    --query 'projects[0].name' \
    --output text 2>/dev/null | grep -q "${PROJECT_NAME}"; then
  echo "    Already exists, skipping."
else
  aws codebuild create-project \
    --name "${PROJECT_NAME}" \
    --description "Auto destroy all Terraform resources" \
    --source "{
      \"type\": \"GITHUB\",
      \"location\": \"${GITHUB_REPO}\",
      \"buildspec\": \"${BUILDSPEC_PATH}\",
      \"gitCloneDepth\": 1
    }" \
    --artifacts '{"type": "NO_ARTIFACTS"}' \
    --environment "{
      \"type\": \"LINUX_CONTAINER\",
      \"image\": \"aws/codebuild/standard:7.0\",
      \"computeType\": \"BUILD_GENERAL1_SMALL\",
      \"environmentVariables\": [
        {\"name\": \"STATE_BUCKET\", \"value\": \"${STATE_BUCKET}\"},
        {\"name\": \"LOCK_TABLE\",   \"value\": \"${LOCK_TABLE}\"},
        {\"name\": \"REGION\",       \"value\": \"${REGION}\"}
      ]
    }" \
    --service-role "arn:aws:iam::${ACCOUNT_ID}:role/${CODEBUILD_ROLE}" \
    --region "${REGION}" \
    --no-cli-pager > /dev/null
  echo "    CodeBuild project created."
fi

# ── Step 5: EventBridge Rule ──────────────────────────────────────────────────
echo "[5/7] Creating EventBridge rule..."

aws events put-rule \
  --name "${RULE_NAME}" \
  --schedule-expression "rate(1 hour)" \
  --state ENABLED \
  --description "Triggers Terraform auto-destroy check every 1 hour" \
  --region "${REGION}" \
  --no-cli-pager > /dev/null
echo "    Rule created."

# ── Step 6: Wire EventBridge → Lambda ────────────────────────────────────────
echo "[6/7] Wiring EventBridge to Lambda..."

aws events put-targets \
  --rule "${RULE_NAME}" \
  --targets "[
    {
      \"Id\": \"terraform-state-checker-target\",
      \"Arn\": \"arn:aws:lambda:${REGION}:${ACCOUNT_ID}:function:${LAMBDA_NAME}\"
    }
  ]" \
  --region "${REGION}" \
  --no-cli-pager > /dev/null

# Allow EventBridge to invoke Lambda
aws lambda add-permission \
  --function-name "${LAMBDA_NAME}" \
  --statement-id EventBridgeInvoke \
  --action lambda:InvokeFunction \
  --principal events.amazonaws.com \
  --source-arn "arn:aws:events:${REGION}:${ACCOUNT_ID}:rule/${RULE_NAME}" \
  --region "${REGION}" \
  --no-cli-pager > /dev/null 2>&1 || true
echo "    EventBridge → Lambda wired."

# ── Step 7: Update buildspec.yml with dynamic values ─────────────────────────
echo "[7/7] Updating buildspec.yml with dynamic backend config..."

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BUILDSPEC_FILE="${SCRIPT_DIR}/../Infra/buildspec.yml"

cat > "${BUILDSPEC_FILE}" << BSEOF
version: 0.2

env:
  variables:
    TF_VERSION: "1.7.5"
    TF_DATA_DIR: "/tmp/.terraform"
    AWS_DEFAULT_REGION: "${REGION}"

phases:
  install:
    commands:
      - echo "Installing Terraform \${TF_VERSION}"
      - curl -fsSL https://releases.hashicorp.com/terraform/\${TF_VERSION}/terraform_\${TF_VERSION}_linux_amd64.zip -o /tmp/terraform.zip
      - unzip -o /tmp/terraform.zip -d /usr/local/bin/
      - terraform version

  pre_build:
    commands:
      - terraform init
          -backend-config="bucket=${STATE_BUCKET}"
          -backend-config="key=${STATE_KEY}"
          -backend-config="region=${REGION}"
          -backend-config="dynamodb_table=${LOCK_TABLE}"
          -backend-config="encrypt=true"
          -reconfigure
          -input=false
    working_directory: Infra

  build:
    commands:
      - echo "=========================================="
      - echo "Starting Terraform Auto-Destroy - \$(date)"
      - echo "=========================================="
      - echo "--- Destroying DEV environment ---"
      - terraform destroy -auto-approve -var-file=environments/dev/dev.tfvars -input=false || echo "DEV destroy failed or no state, continuing..."
      - echo "--- Destroying PROD environment ---"
      - terraform destroy -auto-approve -var-file=environments/prod/prod.tfvars -input=false || echo "PROD destroy failed or no state, continuing..."
      - echo "=========================================="
      - echo "Auto-Destroy complete - \$(date)"
      - echo "=========================================="
    working_directory: Infra

  post_build:
    commands:
      - echo "Build status - \${CODEBUILD_BUILD_SUCCEEDING}"
BSEOF

echo "    buildspec.yml updated."

# ── Summary ───────────────────────────────────────────────────────────────────
echo ""
echo "╔══════════════════════════════════════════════════════════╗"
echo "║   ✅ Auto-Destroy Setup Complete!                        ║"
echo "╚══════════════════════════════════════════════════════════╝"
echo ""
echo "  CodeBuild Role  : arn:aws:iam::${ACCOUNT_ID}:role/${CODEBUILD_ROLE}"
echo "  Lambda Role     : arn:aws:iam::${ACCOUNT_ID}:role/${LAMBDA_ROLE}"
echo "  Lambda          : ${LAMBDA_NAME}"
echo "  CodeBuild       : ${PROJECT_NAME}"
echo "  EventBridge     : ${RULE_NAME} (every 1 hour)"
echo ""
echo "  Flow: EventBridge → Lambda (checks S3 state age)"
echo "        → if > 1 hour → CodeBuild (terraform destroy)"
echo ""
echo "  To test manually:"
echo "  aws lambda invoke --function-name ${LAMBDA_NAME} --region ${REGION} --no-cli-pager /tmp/out.json && cat /tmp/out.json"
echo ""
echo "  To trigger destroy immediately:"
echo "  aws codebuild start-build --project-name ${PROJECT_NAME} --region ${REGION} --no-cli-pager"
echo ""