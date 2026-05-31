<div align="center">

```
╔══════════════════════════════════════════════════════════════════════╗
║                                                                      ║
║      ⚡ TERRAFORM × AWS CLOUDSHELL — ZERO FRICTION INFRASTRUCTURE ⚡  ║
║                                                                      ║
║   One clone. One command. Auto-deploy. Auto-destroy. Zero surprises. ║
║                                                                      ║
╚══════════════════════════════════════════════════════════════════════╝
```

![Terraform](https://img.shields.io/badge/Terraform-1.7.5-7B42BC?style=for-the-badge&logo=terraform&logoColor=white)
![AWS](https://img.shields.io/badge/AWS-CloudShell-FF9900?style=for-the-badge&logo=amazonaws&logoColor=white)
![Lambda](https://img.shields.io/badge/Auto--Destroy-Lambda%20%2B%20CodeBuild-00C853?style=for-the-badge&logo=awslambda&logoColor=white)
![Region](https://img.shields.io/badge/Region-ap--south--1-0078D4?style=for-the-badge&logo=amazonwebservices&logoColor=white)
![Status](https://img.shields.io/badge/Status-Production%20Ready-00C853?style=for-the-badge)
![Cost](https://img.shields.io/badge/Auto--Destroy%20Cost-~%240.15%2Fmonth-FFD700?style=for-the-badge)

</div>

---

## 🚀 Quickstart — Fresh AWS Account

```bash
# 1. Clone
git clone https://github.com/S-Shanthosh/Terraform-1.git workspace
cd workspace

# 2. Bootstrap (run ONCE per account — asks ONE question)
chmod +x setup/bootstrap.sh
bash setup/bootstrap.sh

# 3. Set up Auto-Destroy (run ONCE per account)
bash setup/resource-cleanup.sh

# 4. Deploy infrastructure
cd Infra
terraform apply -var-file=environments/dev/dev.tfvars -auto-approve
```

> 💬 Both scripts ask **one question each** — your state bucket name. Everything else is fully automatic.

---

## 🏗️ Architecture — Two Pillars

### Pillar 1 — CloudShell Session Management

```
New CloudShell Session
        │
        ▼
  tf-start.sh (auto via .bashrc)
        │
        ├── ⬇️  Restore Terraform binary from S3
        ├── 📦  Restore provider plugins (skip terraform init!)
        └── 🔑  Restore SSH keys
        │
        ▼
  Ready to terraform apply in seconds
```

### Pillar 2 — Auto-Destroy Pipeline (prevents surprise bills)

```
  ┌─────────────────────────────────────────────────────────┐
  │                                                         │
  │   ⏰ EventBridge          🔍 Lambda           🏗️ CodeBuild  │
  │   (every 1 hour)    →   (TTL check)    →    (tf destroy) │
  │                                                         │
  └─────────────────────────────────────────────────────────┘

  Every hour:
  ┌──────────────────────────────────────────────────────────────┐
  │                                                              │
  │  Lambda reads S3 tfstate → checks LastModified timestamp     │
  │                                                              │
  │  ┌─────────────────────┐     ┌────────────────────────────┐  │
  │  │ < 1 hour since apply│     │ > 1 hour since apply       │  │
  │  │                     │     │                            │  │
  │  │  ✅ SKIP            │     │  🔥 TRIGGER CodeBuild      │  │
  │  │  Resources safe     │     │  terraform destroy runs    │  │
  │  │  $0 cost            │     │  ALL resources destroyed   │  │
  │  └─────────────────────┘     └────────────────────────────┘  │
  │                                                              │
  └──────────────────────────────────────────────────────────────┘
```

> 💡 **How it detects resources**: Every `terraform apply` updates the S3 state file. Lambda checks the `LastModified` timestamp of that file — no tagging, no null_resource, no extra commands needed. Just `terraform apply` as usual.

---

## 🧠 What Each Script Does

### `bootstrap.sh` — One-time account setup

```
bootstrap.sh  (run ONCE)
│
├── 📍 Auto-detects repo path
├── ⬇️  Installs Terraform 1.7.5        (skips if already present)
├── 🔧  Configures .bashrc              (idempotent — safe to re-run)
├── 🪣  Creates S3 state bucket         (versioned, encrypted, private)
├── 🔒  Creates DynamoDB lock table     (prevents state corruption)
├── 🔑  Generates SSH key pair          (for EC2 access)
├── 📝  Generates backend.tf            (wired to YOUR bucket automatically)
├── 🔐  Sets script permissions
├── 🚀  Runs terraform init
└── 💾  Saves session to S3
```

> ⚠️ **`backend.tf` is auto-generated** — it is NOT stored in this repo intentionally.
> It contains account-specific values (bucket name, region) that differ per account.
> `bootstrap.sh` generates it fresh every time with your exact bucket details.
> Never create or commit `backend.tf` manually.

### `resource-cleanup.sh` — Auto-destroy infrastructure setup

```
resource-cleanup.sh  (run ONCE)
│
├── [1/6] 🔐 CodeBuild IAM Role         (AdministratorAccess for destroy)
├── [2/6] 🔐 Lambda IAM Role            (S3 read + CodeBuild trigger)
├── [3/6] λ  Lambda function            (checks S3 state age)
├── [4/6] 🏗️  CodeBuild project          (runs terraform destroy)
├── [5/6] ⏰  EventBridge rule           (fires every 1 hour)
└── [6/6] 🔗 Wire EventBridge → Lambda  (connects the pipeline)
```

> ✅ **Idempotent** — safe to re-run. Existing resources are updated, not duplicated.
> ✅ **Works in any AWS account** — no hardcoded values. Account ID auto-detected, bucket name asked once.

---

## 🔄 Every New CloudShell Session

```
Session starts
     │
     ▼ (automatic via .bashrc)
tf-start.sh runs
     │
     ├── Terraform binary restored ✅
     ├── Provider plugins restored ✅  (no terraform init needed!)
     └── SSH keys restored ✅
     │
     ▼
cd workspace/Infra
terraform apply -var-file=environments/dev/dev.tfvars -auto-approve
```

| When | Command |
|------|---------|
| 🟢 Session starts | **Automatic** — nothing to run |
| 🔴 Before exiting | `bash $TF_SETUP_DIR/tf-save.sh` |

---

## ☁️ Remote Backend

| Setting | Value |
|---|---|
| 🪣 S3 Bucket | Your bucket name (entered during bootstrap) |
| 🔒 DynamoDB Table | `<your-bucket>-locks` |
| 🌏 Region | `ap-south-1` (Mumbai) |
| 🔐 Encryption | AES-256 server-side |
| 🚫 Public Access | Fully blocked |
| 📋 Versioning | Enabled |
| 📄 State Key | `infra/terraform.tfstate` |

---

## 💰 Auto-Destroy Cost

| Scenario | Monthly Cost |
|---|---|
| No resources deployed | **$0** |
| Deploy + forget ~10 times | **~$0.15** |
| Deploy every day (1 session/day) | **~$0.45** |
| Worst case (resources up all month) | **~$10.80** |

> Lambda (2880 invocations/month) = **$0** — free tier covers it.
> CodeBuild only charges when it actually runs a destroy (~$0.015 per run).

---

## 🛠️ Deploy Infrastructure

```bash
cd ~/workspace/Infra

# Initialize (first time or after bootstrap)
terraform init -reconfigure

# Plan (dry run — see what will be created)
terraform plan -var-file=environments/dev/dev.tfvars

# Apply dev environment
terraform apply -var-file=environments/dev/dev.tfvars -auto-approve

# Apply prod environment
terraform apply -var-file=environments/prod/prod.tfvars -auto-approve

# Manual destroy (if needed before auto-destroy kicks in)
terraform destroy -var-file=environments/dev/dev.tfvars -auto-approve
```

> ⏰ **Auto-destroy** kicks in ~1 hour after `terraform apply`. Resources are safe for the full hour.

---

## 🚨 Manual Trigger — Emergency Destroy

If the auto-destroy pipeline fails or you need to force destroy immediately:

### Option 1 — Trigger CodeBuild directly and watch logs

```bash
# Step 1: Trigger the destroy build
BUILD_ID=$(aws codebuild start-build \
  --project-name "terraform-auto-destroy" \
  --region ap-south-1 \
  --query 'build.id' \
  --output text \
  --no-cli-pager)

echo "Build started: $BUILD_ID"

# Step 2: Wait ~3 minutes, then fetch logs
LOG_STREAM=$(echo $BUILD_ID | cut -d: -f2)

aws logs get-log-events \
  --log-group-name "/aws/codebuild/terraform-auto-destroy" \
  --log-stream-name "$LOG_STREAM" \
  --region ap-south-1 \
  --no-cli-pager \
  --query 'events[*].message' \
  --output text | tail -60
```

### Option 2 — Invoke Lambda to check state and auto-trigger if needed

```bash
aws lambda invoke \
  --function-name terraform-state-checker \
  --region ap-south-1 \
  --no-cli-pager \
  --log-type Tail \
  --query 'LogResult' \
  --output text \
  /tmp/out.json | base64 --decode

echo "--- Lambda Response ---"
cat /tmp/out.json
```

Lambda will return one of:
- `{"status": "skipped", "reason": "no state file"}` — nothing deployed
- `{"status": "skipped", "reason": "within TTL", "remaining": "0:45:00"}` — resources safe, time remaining shown
- `{"status": "triggered", "build_id": "terraform-auto-destroy:xxx"}` — CodeBuild destroy started

### Option 3 — Direct terraform destroy from CloudShell

```bash
cd ~/workspace/Infra
terraform destroy -var-file=environments/dev/dev.tfvars -auto-approve
```

---

## 📁 Repository Structure

```
Terraform-1/
│
├── 📂 setup/
│   ├── 🚀 bootstrap.sh          ← Run ONCE per new AWS account
│   ├── 🧹 resource-cleanup.sh   ← Run ONCE — sets up auto-destroy pipeline
│   ├── 🔄 tf-start.sh           ← Auto-runs on every session start
│   └── 💾 tf-save.sh            ← Run before exiting CloudShell
│
├── 📂 Infra/
│   ├── backend.tf               ← ⚠️ Auto-generated by bootstrap.sh (not in repo)
│   ├── buildspec.yml            ← CodeBuild destroy instructions
│   ├── main.tf
│   ├── provider.tf
│   ├── variables.tf
│   ├── outputs.tf
│   ├── terraform.tfvars
│   ├── 📂 environments/
│   │   ├── dev/dev.tfvars
│   │   └── prod/prod.tfvars
│   └── 📂 modules/
│       ├── vpc/
│       ├── ec2/
│       ├── s3/
│       └── lambda/
│
├── 📂 bootstrap/
│   └── main.tf                  ← Reference only (S3 + DynamoDB bootstrap)
│
└── .gitattributes               ← Enforces LF line endings across all OS
```

---

## 🔑 SSH Key

Bootstrap auto-generates an RSA 4096-bit key at:

```
~/.ssh/shanthosh-key       ← private key
~/.ssh/shanthosh-key.pub   ← public key (used by EC2 module automatically)
```

Keys are backed up to S3 and restored every CloudShell session automatically.

---

## 🔁 Idempotency — Safe to Run Multiple Times

| Script | Protection |
|--------|-----------|
| `bootstrap.sh` | Version check, `head-bucket`, `describe-table`, file existence checks |
| `resource-cleanup.sh` | Checks existence before create, updates env vars if already exists |
| `.bashrc` config | Sentinel `# __TF_BOOTSTRAP_DONE__` prevents duplicate entries |

---

## 🧹 Full Teardown

```bash
# Delete all Terraform resources first
cd ~/workspace/Infra
terraform destroy -var-file=environments/dev/dev.tfvars -auto-approve

# Delete auto-destroy pipeline
aws events remove-targets --rule "terraform-auto-destroy-hourly" --ids "terraform-state-checker-target" --region ap-south-1
aws events delete-rule --name "terraform-auto-destroy-hourly" --region ap-south-1
aws lambda delete-function --function-name terraform-state-checker --region ap-south-1
aws codebuild delete-project --name terraform-auto-destroy --region ap-south-1
aws iam detach-role-policy --role-name CodeBuild-TerraformDestroy-Role --policy-arn arn:aws:iam::aws:policy/AdministratorAccess
aws iam delete-role --role-name CodeBuild-TerraformDestroy-Role
aws iam detach-role-policy --role-name Lambda-TerraformStateChecker-Role --policy-arn arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole
aws iam delete-role-policy --role-name Lambda-TerraformStateChecker-Role --policy-name TerraformStateChecker-Policy
aws iam delete-role --role-name Lambda-TerraformStateChecker-Role

# Delete state bucket
aws s3 rm s3://<your-bucket> --recursive
aws s3api delete-bucket --bucket <your-bucket> --region ap-south-1

# Delete DynamoDB lock table
aws dynamodb delete-table --table-name <your-bucket>-locks --region ap-south-1

# Clean local environment
rm -rf ~/workspace ~/bin/terraform /tmp/.terraform
rm -f ~/.ssh/shanthosh-key ~/.ssh/shanthosh-key.pub
sed -i '/# __TF_BOOTSTRAP_DONE__/,$ d' ~/.bashrc
```

---

## ⚠️ Important Notes

- 🔐 **IAM Permissions** — Terraform inherits your CloudShell IAM role. Verify with `aws sts get-caller-identity`
- 🌏 **Region** — Defaults to `ap-south-1`. Change `REGION` in `bootstrap.sh` if needed
- 💰 **Cost Safety** — Auto-destroy kicks in ~1 hour after every `terraform apply`. Max exposure: 1 hour of resource costs
- 🔄 **Multi-account** — Run both `bootstrap.sh` and `resource-cleanup.sh` once per AWS account
- 📄 **backend.tf** — Never commit this file. It is auto-generated by `bootstrap.sh` per account
- 🔒 **State Locking** — DynamoDB prevents concurrent state corruption automatically

---

<div align="center">

```
Built for AWS CloudShell · Terraform 1.7.5 · ap-south-1
EventBridge → Lambda → CodeBuild · Auto-destroy in ~1 hour · ~$0.15/month
```

![Made with](https://img.shields.io/badge/Made%20with-%E2%9D%A4%EF%B8%8F%20%26%20CloudShell-FF9900?style=flat-square)

</div>
