#!/bin/bash
set -e

# ─────────────────────────────────────────────
#  Terraform CloudShell Bootstrap
#  Run once in a fresh AWS account CloudShell
#  Assumes: repo already cloned anywhere
# ─────────────────────────────────────────────

# Auto-detect repo root from script location
REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
INFRA_DIR="$REPO_DIR/Infra"
SETUP_DIR="$REPO_DIR/setup"

REGION="ap-south-1"
TF_VERSION="1.7.5"
TF_BINARY="$HOME/bin/terraform"
TF_DATA_DIR="/tmp/.terraform"

echo ""
echo "╔══════════════════════════════════════════╗"
echo "║   Terraform CloudShell Bootstrap v2.0    ║"
echo "╚══════════════════════════════════════════╝"
echo ""
echo "  → Repo detected at : $REPO_DIR"
echo ""

# ── Step 1: Ask for state bucket name ─────────────────────────────────────────
read -p "Enter your Terraform state bucket name: " STATE_BUCKET
if [[ -z "$STATE_BUCKET" ]]; then
  echo "❌ Bucket name cannot be empty. Exiting."
  exit 1
fi
LOCK_TABLE="${STATE_BUCKET}-locks"
STORAGE_BUCKET="$STATE_BUCKET"   # same bucket used for session persistence

echo "  → State bucket     : $STATE_BUCKET"
echo "  → Lock table       : $LOCK_TABLE"
echo "  → Session storage  : $STORAGE_BUCKET"
echo "  → Region           : $REGION"
echo ""

# ── Step 2: Install Terraform binary ──────────────────────────────────────────
echo "⬇️  Installing Terraform $TF_VERSION..."
mkdir -p "$HOME/bin"

if [ -f "$TF_BINARY" ] && "$TF_BINARY" version 2>/dev/null | grep -q "$TF_VERSION"; then
  echo "✅ Terraform $TF_VERSION already installed — skipping."
else
  curl -sSL "https://releases.hashicorp.com/terraform/${TF_VERSION}/terraform_${TF_VERSION}_linux_amd64.zip" \
    -o /tmp/terraform.zip
  unzip -o /tmp/terraform.zip -d "$HOME/bin" > /dev/null
  chmod +x "$TF_BINARY"
  rm -f /tmp/terraform.zip
  echo "✅ Terraform installed at $TF_BINARY"
fi

# ── Step 3: Configure .bashrc (idempotent) ────────────────────────────────────
echo "🔧 Configuring shell environment..."

if grep -q "__TF_BOOTSTRAP_DONE__" "$HOME/.bashrc"; then
  echo "✅ .bashrc already configured — skipping."
else
  cat >> "$HOME/.bashrc" << BASHRCEOF

# __TF_BOOTSTRAP_DONE__
export PATH=\$PATH:~/bin
export TF_DATA_DIR=$TF_DATA_DIR
export TF_STORAGE_BUCKET=$STORAGE_BUCKET
export TF_SETUP_DIR=$SETUP_DIR
echo '⚠️  Remember to run \$TF_SETUP_DIR/tf-save.sh before exiting!'
source \$TF_SETUP_DIR/tf-start.sh
BASHRCEOF
  echo "✅ Shell environment configured"
fi

export PATH=$PATH:$HOME/bin
export TF_DATA_DIR=$TF_DATA_DIR
export TF_STORAGE_BUCKET=$STORAGE_BUCKET
export TF_SETUP_DIR=$SETUP_DIR
mkdir -p "$TF_DATA_DIR"



# ── Step 4: Create S3 state bucket ────────────────────────────────────────────
echo "🪣 Creating S3 state bucket: $STATE_BUCKET..."

if aws s3api head-bucket --bucket "$STATE_BUCKET" 2>/dev/null; then
  echo "✅ Bucket already exists — skipping creation."
else
  aws s3api create-bucket \
    --bucket "$STATE_BUCKET" \
    --region "$REGION" \
    --create-bucket-configuration LocationConstraint="$REGION" \
    --output text > /dev/null

  aws s3api put-bucket-versioning \
    --bucket "$STATE_BUCKET" \
    --versioning-configuration Status=Enabled

  aws s3api put-bucket-encryption \
    --bucket "$STATE_BUCKET" \
    --server-side-encryption-configuration '{
      "Rules":[{"ApplyServerSideEncryptionByDefault":{"SSEAlgorithm":"AES256"}}]
    }'

  aws s3api put-public-access-block \
    --bucket "$STATE_BUCKET" \
    --public-access-block-configuration \
      "BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true"

  echo "✅ S3 bucket created and secured"
fi

# ── Step 5: Create DynamoDB lock table ────────────────────────────────────────
echo "🔒 Creating DynamoDB lock table: $LOCK_TABLE..."

if aws dynamodb describe-table --table-name "$LOCK_TABLE" --region "$REGION" 2>/dev/null | grep -q "TableName"; then
  echo "✅ DynamoDB table already exists — skipping."
else
  aws dynamodb create-table \
    --table-name "$LOCK_TABLE" \
    --attribute-definitions AttributeName=LockID,AttributeType=S \
    --key-schema AttributeName=LockID,KeyType=HASH \
    --billing-mode PAY_PER_REQUEST \
    --region "$REGION" \
    --output text > /dev/null
  echo "✅ DynamoDB lock table created"
fi

# ── Step 6: SSH key generation ────────────────────────────────────────────────
echo "🔑 Setting up SSH key..."
KEY_PATH="$HOME/.ssh/shanthosh-key"

if [ -f "$KEY_PATH" ]; then
  echo "✅ SSH key already exists — skipping."
else
  mkdir -p ~/.ssh
  ssh-keygen -t rsa -b 4096 -f "$KEY_PATH" -N "" -C "shanthosh-cloudshell"
  chmod 600 "$KEY_PATH"
  chmod 644 "${KEY_PATH}.pub"
  echo "✅ SSH key created at $KEY_PATH"
  echo ""
  echo "👉 Add this public key to AWS EC2 Key Pairs (or use it in your Terraform EC2 module):"
  echo "──────────────────────────────────────────"
  cat "${KEY_PATH}.pub"
  echo "──────────────────────────────────────────"
  echo ""
fi

# ── Step 7: Write backend.tf dynamically ──────────────────────────────────────
echo "📝 Writing backend.tf..."
cat > "$INFRA_DIR/backend.tf" <<BACKENDEOF
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  backend "s3" {
    bucket         = "$STATE_BUCKET"
    key            = "infra/terraform.tfstate"
    region         = "$REGION"
    dynamodb_table = "$LOCK_TABLE"
    encrypt        = true
  }
}
BACKENDEOF
echo "✅ backend.tf updated"

# ── Step 8: terraform init ────────────────────────────────────────────────────
echo "🚀 Running terraform init..."
cd "$INFRA_DIR"
terraform init
echo "✅ Terraform initialized"

# ── Step 9: Save environment to S3 immediately ────────────────────────────────
echo "💾 Saving environment to S3..."
STORAGE_BUCKET="$STORAGE_BUCKET" bash "$SETUP_DIR/tf-save.sh"

# ── Done ──────────────────────────────────────────────────────────────────────
echo ""
echo "╔══════════════════════════════════════════════════╗"
echo "║   ✅ Bootstrap complete!                         ║"
echo "║                                                  ║"
echo "║   cd $INFRA_DIR"
echo "║   terraform plan -var-file=environments/dev/dev.tfvars"
echo "╚══════════════════════════════════════════════════╝"
echo ""
