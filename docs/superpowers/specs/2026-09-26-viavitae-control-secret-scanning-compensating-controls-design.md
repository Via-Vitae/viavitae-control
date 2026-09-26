# viavitae-control — Secret Scanning Compensating Controls (Design Spec)

- **Date:** 2026-09-26
- **Owner org:** `Via-Vitae` (GitHub Free plan)
- **Compliance targets:** SOC 2, ISO 27001, GDPR
- **Execution authority:** PLAN-ONLY. No `terraform apply`. No live org mutation. No push to `main`.
- **Status:** Approved design; implementation = extend module + update compliance docs

> Scope boundary: this control plane manages **Via-Vitae only**. It is separate from
> `jol-control`, which manages `journeyoflife-org`. The two are never mixed.

---

## 1. Problem

GitHub Free does not provide secret scanning or branch protection for **private**
repositories. Via-Vitae has 5 private repos (`viavitae-compliance`,
`viavitae-data-governance`, `viavitae-policies`, `viavitae-threat-model`,
`viavitae-vendor-register`) containing audit evidence, DPIAs, threat models, and
sub-processor registers — all within PCI-DSS/GDPR/SOC2 scope.

The control plane already documents this gap honestly in `docs/COMPLIANCE.md`
(`gap-plan-tier`). What is missing is the **compensating control**: a mechanism that
detects secrets before they reach GitHub, regardless of plan tier.

Three organizations (~100 repos total) need this capability. The solution must be
reusable across control planes (`viavitae-control`, `jol-control`, and others) without
org-specific hardcoding.

---

## 2. Decisions

### D1 — Distribution: Terraform module (Approach A)

Three approaches were considered.

- **A — Extend `modules/repo/files.tf` with new resources.** **Chosen.** Follows the
  exact pattern of existing CODEOWNERS + security workflow resources. Declarative,
  auditable, version-controlled. Activated by `manage_files = true` per repo.
- **B — New `security_scanning.tf` in the module.** Rejected: premature separation for
  only 2 new resources. The existing `files.tf` naming already covers "files pushed into
  a repo."
- **C — Per-file-type feature flags.** Rejected: over-engineering for a solo operator
  with 30 repos on Free plan. YAGNI.

### D2 — Workflow: separate gitleaks workflow (not merged into CodeQL)

The gitleaks CI workflow is a **separate file** (`.github/workflows/gitleaks.yml`), not
merged into the existing CodeQL `security.yml`. Clean separation of concerns: secret
scanning vs code analysis. Easier to reason about, toggle, and audit independently.

### D3 — Scope: module only, no repo activation

This spec adds the templates to the module (making them **available**) but does **not**
flip `manage_files = true` on any Via-Vitae repo. Activation is a separate, staged
decision. Lower risk, reviewable in stages. Consistent with the existing non-destructive
baseline (`manage_files = false` everywhere today).

### D4 — Gitleaks CLI, not gitleaks-action

The official `gitleaks/gitleaks-action` wrapper requires a license for org repos. The
gitleaks CLI is free (MIT). The workflow downloads the binary via `wget` in a `run:`
step. No license needed. No GitHub Action dependency beyond `actions/checkout@v4`
(already in the org allow-list).

### D5 — Pre-commit hooks: 7 hooks, conservative set

The `.pre-commit-config.yaml` includes:

| Hook | Purpose |
|------|---------|
| `gitleaks/gitleaks` | Secret detection (API keys, tokens, passwords) |
| `detect-private-key` | RSA/EC/OpenSSH private keys (defense in depth) |
| `check-yaml` | Catches broken YAML that would fail CI |
| `check-merge-conflict` | Catches unresolved `<<<<<<<` markers |
| `end-of-file-fixer` | One-time fix, prevents noisy whitespace diffs |
| `trailing-whitespace` | One-time fix, enforces consistency |
| `check-added-large-files` | Default 500KB limit, prevents accidental state/artifact commits |

`end-of-file-fixer`, `trailing-whitespace`, and `check-added-large-files` are included
by professional judgment: low friction, high value for a solo operator managing ~100
repos. They are set-and-forget — auto-fix once, then silent.

### D6 — No weekly schedule scan

The gitleaks workflow triggers on `push` + `pull_request` to `main` only. No weekly
scheduled scan. Rationale:

- Push + PR triggers cover all critical paths (PR-only merge policy means nothing
  reaches `main` without a scan).
- Weekly full-history scans on ~100 repos would consume 200-500 Actions min/month
  (10-25% of the Free plan budget) for diminishing returns.
- Post-revenue upgrade to GitHub Team activates native secret scanning with full
  historical coverage.

---

## 3. Deliverables

### 3.1 `modules/repo/files.tf` — two new locals + two new resources

**New locals** (appended to existing `locals` block):

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

**New resources:**

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

### 3.2 `modules/repo/variables.tf` — two new variables

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

### 3.3 Root `variables.tf` — two pass-through variables

```hcl
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

### 3.4 `repos.tf` — pass variables to module

Add to the existing `module "repo"` block:

```hcl
  gitleaks_version         = var.gitleaks_version
  pre_commit_hooks_version = var.pre_commit_hooks_version
```

### 3.5 `docs/COMPLIANCE.md` — two new control rows + roadmap update

**§1 Control matrix — add rows:**

| # | Control | SOC 2 | ISO 27001 | GDPR | Implemented by | Free status |
|---|---------|-------|-----------|------|----------------|-------------|
| C17 | Pre-commit secret scanning (gitleaks + hygiene hooks) | CC7.1 | A.12.6 | Art. 32 | `modules/repo/files.tf` (`.pre-commit-config.yaml`) | `declared-not-applied` |
| C18 | CI-based secret scanning (gitleaks CLI, license-free) | CC7.1 | A.12.6 | Art. 32 | `modules/repo/files.tf` (`.github/workflows/gitleaks.yml`) | `declared-not-applied` |

**§3 Staged remediation roadmap — update "Day 0 (now, free)":**

Add: "activate `manage_files` per repo to deploy gitleaks CI workflow + pre-commit
config; install pre-commit hooks on developer machines (`pip install pre-commit &&
pre-commit install`)."

---

## 4. Non-destructive guarantees

- **Zero existing resources modified.** All changes are additive.
- **Zero repos affected.** All 30 Via-Vitae repos have `manage_files = false`. The new
  resources have `count = 0` for every repo. No files are written on next apply.
- **Activation is a separate decision.** Flipping `manage_files = true` on a repo is a
  deliberate, PR-reviewed edit — never automatic.
- **No `terraform apply` run by the implementer.** Owner applies after reviewing the
  plan.
- **No `actions_allowed_patterns` change needed.** The gitleaks workflow downloads the
  binary via `wget` (not a GitHub Action). The only action used is
  `actions/checkout@v4`, already in the allow-list.

---

## 5. Cross-org reusability

The `modules/repo` module is self-contained. Other control planes (`jol-control`, etc.)
can copy or reference the module and pass their own `gitleaks_version` /
`pre_commit_hooks_version`. The template content is parameterized only by:

- `var.default_branch` — branch name (typically `main`)
- `var.gitleaks_version` — gitleaks release version
- `var.pre_commit_hooks_version` — pre-commit-hooks release version

No org-specific values are hardcoded. The module header comment
("Managed by viavitae-control") should be parameterized if the module is adopted by
other control planes with different branding, but this is a cosmetic concern and out of
scope for this spec.

---

## 6. Auditor framing

For an auditor, the compensating control narrative is:

> *"GitHub Free does not provide secret scanning for private repositories. Compensating
> controls: (1) pre-commit hooks (gitleaks + hygiene checks) run locally before any
> commit reaches GitHub, preventing secret leakage at the source; (2) gitleaks CLI runs
> in CI on every push and PR, providing a second detection layer independent of the
> developer's local environment; (3) the gitleaks CLI is license-free (MIT), so the
> control is available on any GitHub plan. Remediation plan: upgrade to GitHub Team
> within 30 days of first production revenue to activate native secret scanning on
> private repos."*

This satisfies SOC 2 CC7.1 (detects and acts on security incidents), ISO 27001 A.12.6
(management of technical vulnerabilities), and GDPR Art. 32 (security of processing).

---

## 7. Validation plan

1. `terraform fmt -check -recursive` — assert formatting
2. `terraform validate` — assert syntax validity
3. `terraform plan` — assert **0 to change** (all repos have `manage_files = false`,
   so the new resources have `count = 0`)
4. Verify the generated `.pre-commit-config.yaml` content is valid YAML by running
   `pre-commit validate-config` against a temporary file
5. Verify the generated gitleaks workflow is valid YAML and the download URL resolves
   (curl -I the gitleaks release URL)

**No `terraform apply`. No `git push` to `main`. No files written to any repo.**

---

## 8. Acceptance criteria

- `modules/repo/files.tf` contains two new `github_repository_file` resources
  (`.pre-commit-config.yaml`, `.github/workflows/gitleaks.yml`) gated by
  `var.manage_files`.
- `modules/repo/variables.tf` contains `gitleaks_version` and
  `pre_commit_hooks_version` with sensible defaults.
- Root `variables.tf` and `repos.tf` pass the variables through.
- `docs/COMPLIANCE.md` includes C17 and C18 with `declared-not-applied` status.
- `terraform plan` shows **0 to change** (no repo activation in this spec).
- The template content is parameterized, contains no org-specific values, and is
  reusable across control planes.
- No existing resources or repo configurations are modified.
