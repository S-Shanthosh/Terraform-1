# Terraform Certification Planner
**Name:** Shanthosh  
**Target Exam:** HashiCorp Terraform Associate (003)  
**Start Date:** June 13, 2026  
**Exam Date:** July 20, 2026  
**Days Remaining:** 29  
**Last Updated:** June 21, 2026  

---

## Overall Progress: 95% (21 / 22 topics done)

---

## Phase 1 — Core Concepts ✅ DONE

| Topic | Status |
|---|---|
| State file & remote backend | ✅ Done |
| Variables & priority order | ✅ Done |
| depends_on | ✅ Done |
| count vs for_each | ✅ Done |
| lifecycle meta-arguments | ✅ Done |

---

## Phase 2 — Building Blocks ✅ DONE

| Topic | Status |
|---|---|
| Data sources | ✅ Done |
| Output blocks | ✅ Done |
| Local values | ✅ Done |
| Provisioners | ✅ Done |

---

## Phase 3 — Real World Usage ✅ DONE

| Topic | Status |
|---|---|
| Workspaces | ✅ Done |
| Terraform import | ✅ Done |
| Modules deep dive | ✅ Done |
| Resource syntax practice | ✅ Done |

---

## Phase 4 — Commands & CLI ✅ DONE

| Topic | Status |
|---|---|
| init, plan, apply, destroy | ✅ Done |
| terraform taint | ✅ Done |
| terraform state commands | ✅ Done |
| terraform fmt, validate | ✅ Done |
| terraform output | ✅ Done |

---

## Phase 5 — Hands-on Lab ✅ DONE

| Topic | Status |
|---|---|
| VPC + EC2 + SG + Key pair | ✅ Done |
| S3 + IAM syntax | ✅ Done |
| Modules hands-on | ✅ Done |
| Full infra deployment end-to-end | ✅ Done |

---

## Phase 6 — Mock Exam ⏳ NEXT
> Target: July 13, 2026

| Topic | Status |
|---|---|
| Full mock interview round 1 | ⏳ Next session |
| Full mock interview round 2 | ⏳ Pending |
| Exam practice questions | ⏳ Pending |
| Weak area revision | ⏳ Pending |

---

## Timeline

```
Jun 13 -----> Jun 20 -----> Jun 27 -----> Jul 7 -----> Jul 13 -----> Jul 20
  Start       Phase 3       Phase 4      Phase 5       Phase 6        EXAM
  ✅ Done      ✅ Done       ✅ Done      ✅ Done        ⏳ Next         🎯
```

---

## Daily Commitment
- 45 mins — theory with Claude
- 30 mins — hands-on in AWS lab (ap-south-1)

---

## Key Weak Areas (as of June 21)
- [ ] Mock exam — not yet attempted
- [x] Resource block syntax — covered
- [x] Terraform CLI commands — covered
- [x] Modules deep dive — covered
- [x] S3 + IAM syntax — covered

---

## Quick Reference — Command Workflow
```
terraform init → terraform validate → terraform fmt → terraform plan → terraform apply
```

## Quick Reference — Key Commands
| Command | Purpose |
|---|---|
| `terraform init` | Initialize workspace |
| `terraform validate` | Check configuration |
| `terraform fmt` | Format code |
| `terraform plan` | Preview changes |
| `terraform apply` | Deploy resources |
| `terraform destroy` | Destroy all resources |
| `terraform state list` | List tracked resources |
| `terraform state rm` | Remove from state (resource stays in AWS) |
| `terraform taint` | Mark resource for recreation |
| `terraform output` | Print output values |
| `terraform workspace new` | Create new workspace |
| `terraform workspace select` | Switch workspace |
| `terraform workspace show` | Show current workspace |
| `terraform import` | Import existing resource into state |

---

## Variable Priority Order (highest to lowest)
1. CLI flag → `-var="region=ap-south-1"`
2. terraform.tfvars
3. Environment variables → `TF_VAR_region`
4. Default value in variables.tf

---

## Lifecycle Meta-Arguments
| Argument | Purpose |
|---|---|
| `prevent_destroy = true` | Prevents resource deletion |
| `create_before_destroy = true` | Creates new before deleting old |
| `ignore_changes = [tags]` | Ignores manual changes to specified attribute |

---

*"A goal without a deadline is just a dream."*
*Exam Date: July 20, 2026 — 29 days remaining*
