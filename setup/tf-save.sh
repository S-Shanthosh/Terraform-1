#!/bin/bash
# tf-save.sh — Save Terraform environment to S3 before exiting CloudShell
# STORAGE_BUCKET is set by bootstrap.sh in .bashrc, or pass it explicitly

BUCKET="${STORAGE_BUCKET:-$TF_STORAGE_BUCKET}"

if [[ -z "$BUCKET" ]]; then
  echo "❌ No storage bucket set. Run bootstrap.sh first or set STORAGE_BUCKET."
  exit 1
fi

echo "💾 Saving Terraform environment to S3 → s3://$BUCKET ..."

# Save Terraform binary
if [ -f "$HOME/bin/terraform" ]; then
  tar -czf /tmp/terraform-env.tar.gz -C "$HOME" bin/terraform
  aws s3 cp /tmp/terraform-env.tar.gz s3://$BUCKET/
  echo "✅ Terraform binary saved"
else
  echo "⚠️  Terraform binary not found — skipping."
fi

# Save provider plugins
if [ -d /tmp/.terraform ]; then
  tar -czf /tmp/terraform-providers.tar.gz -C /tmp .terraform
  aws s3 cp /tmp/terraform-providers.tar.gz s3://$BUCKET/
  echo "✅ Providers saved"
else
  echo "⚠️  No provider cache at /tmp/.terraform — skipping."
fi

# Save SSH keys
if [ -d "$HOME/.ssh" ] && [ "$(ls -A $HOME/.ssh 2>/dev/null)" ]; then
  tar -czf /tmp/ssh-keys.tar.gz -C "$HOME" .ssh
  aws s3 cp /tmp/ssh-keys.tar.gz s3://$BUCKET/
  echo "✅ SSH keys saved"
else
  echo "⚠️  No SSH keys found — skipping."
fi

echo "✅ Save complete → s3://$BUCKET"
