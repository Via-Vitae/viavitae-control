# Secret Scanning Compensating Controls — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add pre-commit config and gitleaks CI workflow templates to the repo module so they can be deployed to any managed repo as a compensating control for GitHub Free's lack of secret scanning on private repos.

**Architecture:** Extend `modules/repo/files.tf` with two new `github_repository_file` resources (`.pre-commit-config.yaml` and `.github/workflows/gitleaks.yml`), gated by the existing `manage_files` flag. Version pins are module variables with defaults. Root module passes variables through. No existing resources modified.

**Tech Stack:** Terraform 1.16.1, integrations/github provider 6.13.0, gitleaks v8.30.1, pre-commit-hooks v5.0.0

**Spec:** `docs/superpowers/specs/2026-09-26-viavitae-control-secret-scanning-compensating-controls-design.md`

---

## File Structure

| Action | File | Responsibility |
|--------|------|----------------|
| Modify | `modules/repo/variables.tf` | Add `gitleaks_version` and `pre_commit_hooks_version` variables |
| Modify | `modules/repo/files.tf` | Add 2 locals (template content) + 2 resources (pre-commit config, gitleaks workflow) |
| Modify | `variables.tf` | Add 2 root-level pass-through variables |
| Modify | `repos.tf` | Pass new variables to module call |
| Modify | `docs/COMPLIANCE.md` | Add C17/C18 control rows + roadmap update |

---

### Task 1: Module variables

**Files:**
- Modify: `modules/repo/variables.tf:149` (append after last variable)

- [ ] **Step 1: Add gitleaks_version and pre_commit_hooks_version variables**

Append to the end of `modules/repo/variables.tf` (after the `enable_dependabot_security_updates` variable):

```hcl
variable "gitleaks_version" {
  description = "Gitleaks release version for CI workflow and pre-commit hook (e.g. v8.30.1)."
  type        = string
  default     = "v8.30.1"
}

variable "pre_commit_hooks_version" {
  description = "pre-commit/pre-commit-hooks release version (e.g. v5.0.0)."
  type        = string
  default     = "v5.0.0"
}
```

- [ ] **Step 2: Format and validate**

Run:
```bash
terraform fmt -check -recursive
terraform validate
```
Expected: Both pass with no errors.

- [ ] **Step 3: Commit**

```bash
git add modules/repo/variables.tf
git commit -m "feat(module): add gitleaks and pre-commit-hooks version variables"
```

---

### Task 2: Module file templates and resources

**Files:**
- Modify: `modules/repo/files.tf:7-49` (locals block)
- Modify: `modules/repo/files.tf:82` (append after last resource)

- [ ] **Step 1: Add pre_commit_config_content and gitleaks_workflow_content locals**

Inside the existing `locals` block in `modules/repo/files.tf`, add after the `readme_content` local (before the closing `}` of the locals block on line 49):

```hcl
  pre_commit_config_content = <<-EOT
    # Managed by viavitae-control. DO NOT EDIT BY HAND.
    # Pre-commit hooks for secret prevention and basic hygiene.
    # Install: pip install pre-commit && pre-commit install
    repos:
      - repo: https://github.com/gitleaks/gitleaks
        rev: ${var.gitleaks_version}
        hooks:
          - id: gitleaks
      - repo: https://github.com/pre-commit/pre-commit-hooks
        rev: ${var.pre_commit_hooks_version}
        hooks:
          - id: detect-private-key
          - id: check-yaml
          - id: check-merge-conflict
          - id: end-of-file-fixer
          - id: trailing-whitespace
          - id: check-added-large-files
  EOT

  gitleaks_workflow_content = <<-EOT
    # Managed by viavitae-control. DO NOT EDIT BY HAND.
    # License-free secret scanning via gitleaks CLI (no GitHub Advanced Security needed).
    # Compensating control for GitHub Free: private repos lack built-in secret scanning.
    name: gitleaks
    on:
      push:
        branches: [${var.default_branch}]
      pull_request:
        branches: [${var.default_branch}]
    permissions:
      contents: read
    jobs:
      scan:
        runs-on: ubuntu-latest
        steps:
          - uses: actions/checkout@v4
            with:
              fetch-depth: 0
          - name: Run gitleaks
            run: |
              wget -q https://github.com/gitleaks/gitleaks/releases/download/${var.gitleaks_version}/gitleaks_${trimprefix(var.gitleaks_version, "v")}_linux_x64.tar.gz
              tar xzf gitleaks_${trimprefix(var.gitleaks_version, "v")}_linux_x64.tar.gz
              ./gitleaks detect --source . --verbose --redact --exit-code 1
  EOT
```

- [ ] **Step 2: Add pre_commit_config and gitleaks_workflow resources**

Append after the existing `github_repository_file.readme` resource (at the end of the file):

```hcl
resource "github_repository_file" "pre_commit_config" {
  count = var.manage_files ? 1 : 0

  repository          = github_repository.this.name
  file                = ".pre-commit-config.yaml"
  content             = local.pre_commit_config_content
  branch              = var.default_branch
  commit_message      = "chore(viavitae-control): manage pre-commit config [skip ci]"
  overwrite_on_create = true
}

resource "github_repository_file" "gitleaks_workflow" {
  count = var.manage_files ? 1 : 0

  repository          = github_repository.this.name
  file                = ".github/workflows/gitleaks.yml"
  content             = local.gitleaks_workflow_content
  branch              = var.default_branch
  commit_message      = "chore(viavitae-control): manage gitleaks workflow [skip ci]"
  overwrite_on_create = true
}
```

- [ ] **Step 3: Format and validate**

Run:
```bash
terraform fmt -check -recursive
terraform validate
```
Expected: Both pass with no errors.

- [ ] **Step 4: Commit**

```bash
git add modules/repo/files.tf
git commit -m "feat(module): add pre-commit config and gitleaks workflow templates"
```

---

### Task 3: Root variables and module pass-through

**Files:**
- Modify: `variables.tf:255` (append after last variable)
- Modify: `repos.tf:43` (add pass-through lines in module block)

- [ ] **Step 1: Add root-level variables**

Append to the end of `variables.tf` (after the `license_template` variable):

```hcl
###############################################################################
# Secret scanning compensating controls (GitHub Free)
###############################################################################

variable "gitleaks_version" {
  description = "Gitleaks release version for CI workflow and pre-commit hook."
  type        = string
  default     = "v8.30.1"
}

variable "pre_commit_hooks_version" {
  description = "pre-commit/pre-commit-hooks release version."
  type        = string
  default     = "v5.0.0"
}
```

- [ ] **Step 2: Add pass-through to module call**

In `repos.tf`, add the following two lines inside the `module "repo"` block, after the `enable_dependabot_security_updates` line (line 43):

```hcl
  gitleaks_version         = var.gitleaks_version
  pre_commit_hooks_version = var.pre_commit_hooks_version
```

- [ ] **Step 3: Format and validate**

Run:
```bash
terraform fmt -check -recursive
terraform validate
```
Expected: Both pass with no errors.

- [ ] **Step 4: Commit**

```bash
git add variables.tf repos.tf
git commit -m "feat: add root variables and pass-through for gitleaks/pre-commit versions"
```

---

### Task 4: Compliance documentation update

**Files:**
- Modify: `docs/COMPLIANCE.md:13-33` (control matrix table)
- Modify: `docs/COMPLIANCE.md:79-81` (roadmap section)

- [ ] **Step 1: Add C17 and C18 rows to the control matrix**

In `docs/COMPLIANCE.md`, add two new rows to the §1 control matrix table after C16:

```markdown
| C17 | Pre-commit secret scanning (gitleaks + hygiene hooks) | CC7.1 | A.12.6 | Art. 32 | `modules/repo/files.tf` (`.pre-commit-config.yaml`) | `declared-not-applied` |
| C18 | CI-based secret scanning (gitleaks CLI, license-free) | CC7.1 | A.12.6 | Art. 32 | `modules/repo/files.tf` (`.github/workflows/gitleaks.yml`) | `declared-not-applied` |
```

- [ ] **Step 2: Update the staged remediation roadmap**

In `docs/COMPLIANCE.md` §3 "Staged remediation roadmap", update the "Day 0 (now, free)" bullet to include pre-commit activation. Replace the existing Day 0 bullet with:

```markdown
1. **Day 0 (now, free):** Enforce 2FA; enable secret scanning + push protection +
   Dependabot on all public repos; apply the allowed-actions list; begin privatizing
   the compliance-sensitive repos (P0-1) — note private-repo branch protection needs Team+;
   activate `manage_files` per repo to deploy gitleaks CI workflow + pre-commit config;
   install pre-commit hooks on developer machines (`pip install pre-commit && pre-commit install`).
```

- [ ] **Step 3: Commit**

```bash
git add docs/COMPLIANCE.md
git commit -m "docs: add C17/C18 secret scanning compensating controls to compliance matrix"
```

---

### Task 5: Final validation

**Files:** None (validation only)

- [ ] **Step 1: Run full format check**

Run:
```bash
terraform fmt -check -recursive
```
Expected: Pass with no output (all files formatted).

- [ ] **Step 2: Run validation**

Run:
```bash
terraform init -backend=false
terraform validate
```
Expected: `Success! The configuration is valid.`

- [ ] **Step 3: Verify plan shows zero changes**

Run:
```bash
terraform plan -out=/dev/null 2>&1 | tail -5
```
Expected: No resource changes related to the new files (all repos have `manage_files = false`, so new resources have `count = 0`). The plan may show other pending changes from prior work on this branch — that is expected. The key assertion is that the new `github_repository_file.pre_commit_config` and `github_repository_file.gitleaks_workflow` resources do NOT appear in the plan output.

- [ ] **Step 4: Verify gitleaks download URL resolves**

Run:
```bash
curl -sI "https://github.com/gitleaks/gitleaks/releases/download/v8.30.1/gitleaks_8.30.1_linux_x64.tar.gz" | head -1
```
Expected: `HTTP/2 302` (redirect to actual download) or `HTTP/2 200`. Confirms the version-pinned URL is valid.

- [ ] **Step 5: Verify pre-commit config is valid YAML**

Run:
```bash
python3 -c "
import yaml, sys
content = '''
repos:
  - repo: https://github.com/gitleaks/gitleaks
    rev: v8.30.1
    hooks:
      - id: gitleaks
  - repo: https://github.com/pre-commit/pre-commit-hooks
    rev: v5.0.0
    hooks:
      - id: detect-private-key
      - id: check-yaml
      - id: check-merge-conflict
      - id: end-of-file-fixer
      - id: trailing-whitespace
      - id: check-added-large-files
'''
yaml.safe_load(content)
print('Valid YAML')
"
```
Expected: `Valid YAML`

- [ ] **Step 6: Verify git log shows clean commit history**

Run:
```bash
git log --oneline -5
```
Expected: 4 new commits from this plan (module variables, module templates, root variables, compliance docs) plus the design spec commit from earlier.

---

## Summary of changes

| File | Lines added (approx) | Change |
|------|---------------------|--------|
| `modules/repo/variables.tf` | +12 | 2 new variables |
| `modules/repo/files.tf` | +60 | 2 new locals + 2 new resources |
| `variables.tf` | +14 | 2 new root variables with section header |
| `repos.tf` | +2 | Pass-through in module call |
| `docs/COMPLIANCE.md` | +4 | 2 control rows + roadmap update |
| **Total** | **~92** | All additive, zero destructive |
