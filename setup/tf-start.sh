#!/bin/bash
# tf-start.sh — Restore Terraform environment from S3 on new CloudShell session
# Run: source ~/path-to-repo/setup/tf-start.sh

BUCKET="${STORAGE_BUCKET:-$TF_STORAGE_BUCKET}"

if [[ -z "$BUCKET" ]]; then
  echo "❌ No storage bucket set. Run bootstrap.sh first or export STORAGE_BUCKET=your-bucket-name"
  exit 1
fi

echo "🔄 Restoring Terraform environment from s3://$BUCKET ..."

# Set session environment (no .bashrc append — already done by bootstrap)
export PATH=$PATH:$HOME/bin
export TF_DATA_DIR=/tmp/.terraform
mkdir -p /tmp/.terraform

# Restore Terraform binary
if aws s3 cp s3://$BUCKET/terraform-env.tar.gz /tmp/ 2>/dev/null; then
  tar -xzf /tmp/terraform-env.tar.gz -C "$HOME"
  chmod +x "$HOME/bin/terraform"
  echo "✅ Terraform binary restored"
else
  echo "❌ Binary not found in S3 — run bootstrap.sh"
fi

# Restore provider plugins
if aws s3 cp s3://$BUCKET/terraform-providers.tar.gz /tmp/ 2>/dev/null; then
  tar -xzf /tmp/terraform-providers.tar.gz -C /tmp
  echo "✅ Providers restored — no terraform init needed!"
else
  echo "⚠️  No providers in S3 — you may need to run terraform init"
fi

# Restore SSH keys
if aws s3 cp s3://$BUCKET/ssh-keys.tar.gz /tmp/ 2>/dev/null; then
  tar -xzf /tmp/ssh-keys.tar.gz -C "$HOME"
  chmod 700 "$HOME/.ssh"
  chmod 600 "$HOME/.ssh/"* 2>/dev/null || true
  chmod 644 "$HOME/.ssh/"*.pub 2>/dev/null || true
  echo "✅ SSH keys restored"
else
  echo "⚠️  No SSH keys in S3 — skipping"
fi

# Auto-destroy wrapper
terraform() {
  if [[ "$*" == *"apply"* ]]; then
    command terraform "$@"
    echo "⏰ Auto-destroy scheduled in 1 hour..."
    nohup bash -c "sleep 3600 && cd $(pwd) && command terraform destroy -auto-approve" \
      > "$HOME/destroy.log" 2>&1 &
    echo "✅ Auto-destroy job started. Check ~/destroy.log to confirm."
  else
    command terraform "$@"
  fi
}
export -f terraform

echo ""
echo "✅ Restore complete! Terraform is ready."