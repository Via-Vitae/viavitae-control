# Contributing to viavitae-control

This repository is the Terraform control plane for the `Via-Vitae` organization. A change
here is a **proposed** change to live infrastructure settings, so the contribution rules are
the rules the repository already enforces on itself — not an aspirational style guide.

The authoritative statement of those rules is
[`policies/AI_WORKFLOW_POLICY.md`](policies/AI_WORKFLOW_POLICY.md). This file says how a
change moves through them; it does not restate the 15 levers, and where the two disagree the
policy wins.

## The sequence every change follows

```
plan → execute step by step → verify → commit → PR → review → merge → verify again
```

1. **A plan is the contract.** Write it from
   [`docs/superpowers/plans/TEMPLATE.md`](docs/superpowers/plans/TEMPLATE.md) and commit it
   before executing. Deviating from your own plan — including finding a better approach — is
   a failure, not an improvement: stop and get the plan updated first (policy §3.10).
2. **Plan-only authority.** `terraform apply`, `git push` to `main`, and any live
   organization mutation are prohibited until the owner says so in their own words. A pasted
   "next steps" menu from the assistant is not that sentence (policy §3.13).
3. **Route by tier.** Mechanical edits from a plan, and deterministic gate execution, go to a
   cheap tier; intent, plan authoring, `terraform plan` interpretation, diff review and novel
   failure recovery go to the top tier (policy §6). If a cheap tier fails twice on the same
   step, stop and escalate with the exact error output — do not let it loop (policy §3.7).
4. **Every commit carries a provenance trailer.** `ai:top`, `ai:mid`, `ai:cheap`, `ai:free`
   or `ai:review` (policy §3.11). Two layers check it: the local `commit-msg` hook
   `scripts/check_commit_provenance.sh` for early feedback, and `.github/workflows/provenance.yml`
   server-side, which is the layer an author cannot bypass from their own machine. There is no
   non-AI escape hatch: a purely human commit uses `ai:review`.
5. **Never reason about compliance adequacy.** Whether a control is *sufficient* — visibility
   changes, `manage_files` flips, ruleset edits — is reserved for a human or the top tier.
   Produce the evidence and the options; the owner decides (policy §3.12).
6. **No silent fallback.** If a required value cannot be determined, halt and report rather
   than substituting a plausible one (policy §3.15).

## Gates to run before committing

```bash
terraform fmt -check -recursive
terraform init -backend=false && terraform validate
./scripts/check_toolchain_pins.sh toolchain.yml .github/workflows; echo "TOOLCHAIN=$?"
./scripts/check_plan_selfcite.sh docs/superpowers/plans/*.md; echo "SELFCITE=$?"
.venv/bin/python scripts/check_audit_register.py docs/security/*.md docs/superpowers/specs/*.md; echo "REGISTER=$?"
GITHUB_TOKEN="$(gh auth token)" TF_VAR_billing_email=ci-placeholder-not-applied \
  terraform plan -no-color -input=false
```

`terraform plan` requires `TF_VAR_billing_email` to be set — deliberately, with no default, so
a real address is never committed. Pass a placeholder: the value is ignored, and
`ignore_changes` keeps it from ever reaching GitHub (`docs/COMPLIANCE.md` P1-12, and finding
`VV-2026-10-029` for what happens if that guard is removed). Each guard script uses the same
three-way exit contract: **0** holds, **1** violated, **2** nothing was checkable — and *nothing
checked is never reported as a pass*. See [`policies/README.md`](policies/README.md) for the
full inventory.

## Adding or changing a repository

- Declare it in `repos_data.tf`. `imports.tf` adopts every inventory entry except those
  marked `create_new = true`, so a repository that exists live but is missing from the
  inventory makes `terraform plan` fail structurally — `scripts/check_ci_credential.sh` names
  the repos the credential cannot see before the plan dies on that error.
- Tier defaults resolve in `locals.tf`: `tier_codeowners` maps `control` / `platform` / `app`
  / `site` / `meta` to teams, and per-repo overrides win.
- `manage_files` gates whether the module writes `.github/CODEOWNERS`, the security and
  gitleaks workflows, the README and `.pre-commit-config.yaml` **into** the repository. It is
  `false` for existing repos so Terraform never overwrites content; flipping it is a
  compliance decision (item 5 above), not a convenience.
- A required status check that no workflow reports freezes every merge in that repository.
  `required_status_checks_contexts` is therefore set per repo in `repos_data.tf`, not globally.

## Review

The checklist in policy §5 is the actual control — the thing that distinguishes authorized
automation from uncontrolled automation. Paste command output into the PR; do not summarize
it. A gate that has never been observed failing is not evidence of a control.

## Governance artifacts in this repository

The presence or absence of each conventional governance file is a per-file decision measured
against the sibling control planes, not a template applied wholesale. `docs/DPIA-template.md`
is **absent by design**: a DPIA concerns personal data processed by an application, and this
repository processes none. The reasoning, including why the product-repo `governance` CI job
is not adopted here, is recorded in finding `VV-2026-11-019` and in
[`docs/superpowers/plans/2026-11-03-viavitae-control-governance-artifacts.md`](docs/superpowers/plans/2026-11-03-viavitae-control-governance-artifacts.md).
