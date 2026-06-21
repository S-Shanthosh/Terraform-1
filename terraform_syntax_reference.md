# Terraform Syntax Reference
> Quick reference for resource blocks, rules, and components

---

## EC2 — `aws_instance`

```hcl
resource "aws_instance" "my_ec2" {
  ami                    = "ami-0f58b397bc5c1f2e8"   # mandatory
  instance_type          = "t2.micro"
  key_name               = aws_key_pair.my_key.key_name
  subnet_id              = aws_subnet.my_subnet.id
  vpc_security_group_ids = [aws_security_group.my_sg.id]  # list []

  tags = {
    Name  = "my-ec2"       # Name goes in tags for EC2
    Owner = "Shanthosh"
  }
}
```

> ⚠️ No `instance_name` or `vpc_id` as direct arguments.
> Name goes in `tags`. EC2 goes into VPC via `subnet_id`.

---

## S3 — `aws_s3_bucket`

```hcl
resource "aws_s3_bucket" "my_bucket" {
  bucket = "my-bucket-name"   # only required argument

  tags = {
    Name = "my-bucket"
  }
}
```

### S3 Additional Settings (v4+ — separate resources)

```hcl
# Versioning
resource "aws_s3_bucket_versioning" "example" {
  bucket = aws_s3_bucket.my_bucket.id
  versioning_configuration {
    status = "Enabled"
  }
}

# Encryption
resource "aws_s3_bucket_server_side_encryption_configuration" "example" {
  bucket = aws_s3_bucket.my_bucket.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# Block public access
resource "aws_s3_bucket_public_access_block" "example" {
  bucket                  = aws_s3_bucket.my_bucket.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}
```

> ⚠️ In AWS provider v4+, S3 settings are separate resources — not inside bucket block.

---

## IAM

### Step 1 — Create Role (`aws_iam_role`)

```hcl
resource "aws_iam_role" "my_role" {
  name = "my-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}
```

### Step 2 — Create Policy (`aws_iam_policy`)

```hcl
resource "aws_iam_policy" "my_policy" {
  name = "my-policy"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["s3:GetObject", "s3:PutObject"]
      Resource = "*"
    }]
  })
}
```

### Step 3 — Attach Policy to Role (`aws_iam_role_policy_attachment`)

```hcl
resource "aws_iam_role_policy_attachment" "example" {
  role       = aws_iam_role.my_role.name
  policy_arn = aws_iam_policy.my_policy.arn
}
```

### IAM Policy Components — VSEPAR

| Component | Value |
|---|---|
| `Version` | Always `"2012-10-17"` — never changes |
| `Statement` | List of rules `[{...}]` |
| `Effect` | `"Allow"` or `"Deny"` |
| `Principal` | Who → `{ Service = "ec2.amazonaws.com" }` |
| `Action` | What → `"sts:AssumeRole"` or `["s3:GetObject"]` |
| `Resource` | Which → `"*"` means all |

---

## Security Group — `aws_security_group`

```hcl
resource "aws_security_group" "my_sg" {
  name        = "my-sg"              # direct argument
  description = "Allow SSH and HTTP"

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]     # list []
  }

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "my-sg"
  }
}
```

> ⚠️ Two separate `ingress` blocks for port 22 and port 80.
> `cidr_blocks` is plural and a list `[]`.

---

## Naming Rules

| Rule | Correct | Wrong |
|---|---|---|
| Local names | `practice_sg` | `practice-sg` |
| Resource types | `aws_instance` | `AWS_Instance` |

---

## Quotes Rule

| Type | Rule | Example |
|---|---|---|
| Plain text | Use quotes | `instance_type = "t2.micro"` |
| Resource reference | No quotes | `aws_vpc.my_vpc.id` |

---

## `{}` vs `[]` Rule

| Symbol | Use for | Example |
|---|---|---|
| `{}` | Key-value pairs | `tags = { Name = "x" }` |
| `[]` | Lists | `cidr_blocks = ["0.0.0.0/0"]` |

---

## Resource Reference Format

```
resource_type.local_name.attribute
```

| Example | Meaning |
|---|---|
| `aws_vpc.my_vpc.id` | ID of the VPC |
| `aws_security_group.my_sg.id` | ID of the security group |
| `aws_key_pair.my_key.key_name` | Key name of the key pair |
| `aws_iam_role.my_role.name` | Name of the IAM role |
| `aws_iam_policy.my_policy.arn` | ARN of the IAM policy |

---

## `cidr_block` vs `cidr_blocks`

| Resource | Argument | Type |
|---|---|---|
| `aws_vpc` | `cidr_block` | Single value |
| `aws_subnet` | `cidr_block` | Single value |
| `aws_security_group` ingress | `cidr_blocks` | List `[]` |

---

## Name — Direct Argument vs Tags

| Resource | How Name is set |
|---|---|
| `aws_vpc` | `tags = { Name = "..." }` |
| `aws_instance` | `tags = { Name = "..." }` |
| `aws_subnet` | `tags = { Name = "..." }` |
| `aws_security_group` | `name = "..."` direct argument |
| `aws_iam_role` | `name = "..."` direct argument |
| `aws_iam_policy` | `name = "..."` direct argument |
| `aws_s3_bucket` | `bucket = "..."` direct argument |
| `aws_key_pair` | `key_name = "..."` direct argument |

---

## Module Variables

| Where | Rule |
|---|---|
| Raw resource block | Must use exact native argument names |
| Module input variables | Custom names allowed |
| Inside module's main.tf | Custom names must map to native arguments |

```hcl
# Calling module — custom name
module "ec2" {
  instance_name = "my-server"   # custom variable
}

# Inside module — maps to native
tags = {
  Name = var.instance_name      # maps to native tags
}
```

---

*Last updated: June 13, 2026*
