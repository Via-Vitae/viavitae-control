---
title: viavitae-landing-* repositories — purpose, coverage-gate and CI-red decision package
date: 2026-10-27
status: Proposed
classification: internal-audit-working-document
author: AI architect review session (read-only discovery plus scoped remote edits)
audience: Via-Vitae sole owner, acting as platform owner, DPO and approver
decision-required-by: before any of the ten landing propagation PRs merges
document-id: spec-2026-10-27-landing-repos
revisions:
  - "2026-10-27 first edition, from live measurements taken the same day"
---

# Why this document exists

Ten `viavitae-landing-*` repositories have an open propagation PR that fixes their CI matrix
(VV-2026-10-017) and their dependency install (VV-2026-10-020). Merging any of them today turns
that repository's `main` red — already demonstrated, not predicted: `viavitae-landing-basilica`
PR #6 head `10991037` run 40576614237 fails `Lint (python)`, `Test (python)`,
`Typecheck (python)` and the required `CI status`.

The question looks like "add tests or lower the coverage gate". It is not. Measured below, these
repos contain **no application code at all** — one IDE sample file. So the real decision is
**what these ten repositories are for**, and the CI state falls out of that answer.

# 1. Evidence (2026-10-27, all reads from the live API by ref)

Repo list taken from `orgs/Via-Vitae/repos` (31 repos), filtered to the `viavitae-landing-`
prefix, cross-checked against `repos_data.tf` — never typed from memory (see audit register
§28 item 17, where exactly that shortcut nearly produced a false finding).

| measurement | value | how |
|---|---|---|
| landing repos | 10 | API filter |
| files per repo | 19, identical count in all 10 | `git/trees/main?recursive=1`, blobs only |
| Python files per repo | **1** | tree census |
| that file | `main.py`, 528 bytes, PyCharm sample: `This is a sample Python script`, `def print_hi(name)`, `print_hi('PyCharm')` | contents API at `ref=main` |
| markdown files | 8 · toml/yaml 6 · js/ts/jsx/vue **0** | tree census |
| deployable web artifacts | **none** — no `index.html`, no `package.json`, no `hugo.toml`, no `netlify.toml`, no `Dockerfile` | tree census |
| declared coverage floor | `COVERAGE_MIN: 80` in all 10 | `ci.yml` at the PR branch |
| Dependabot | declares **five** ecosystems all pointed at `/`: `pip`, `npm`, `github-actions`, `terraform`, `docker` — and the repo contains **0** files any of them can read except the Actions workflow, so **four of five are decorative** | `.github/dependabot.yml` + tree census (0 `.tf`, 0 `Dockerfile`, 0 `package.json`, 0 `requirements*`) |
| Terraform | 10 blocks, `tier = "site"`, `manage_files = false` in **all** 10 | `repos_data.tf` |
| README | 12.9–13.0 KB, 10 distinct hashes (individually parameterised), and **all 10** contain "single source of truth for how a ViaVitae repository looks" and "Enterprise-grade repository template for regulated, EU-hosted software delivery" | contents API |
| the real template | `viavitae-template` makes the same two claims, has **no** `main.py` — and is the only repo where the claim is true | contents API |
| basilica CI now | `Lint (python)`, `Test (python)`, `Typecheck (python)`, `CI status` **fail**; `Detect stack`, `Trivy`, `Semgrep`, `Compliance status`, `Action SHA pinning`, `Governance files`, `CodeQL` **pass** | run 40576614237 |
| ADR registry | `viavitae-docs/content/architecture/adr-NNNN-*.md`, 12 files, numbers 0–11, next free **0012** | tree census |
| where landing-page content actually is | `viavitae-demos/templates` (Next.js, 135 files) — established 2026-10-26 | prior census, unchanged |

Three consequences follow directly from the table, and none of them is a coverage question:

1. **The gate is objecting to a sample file.** ruff and mypy fail because `print_hi` is untyped;
   pytest exits 1 because there is no test. The repos are behaving correctly.
2. **All ten READMEs assert something false.** They claim to be the org's repository template and
   the source of truth for new repos. `viavitae-template` is. This is VV-2026-10-014's defect class
   (documentation asserting what the code does not do), replicated across ten repos — registered
   as **VV-2026-10-024**.
3. **Dependabot is pointed at four ecosystems that contain nothing.** `pip` scans a 528-byte IDE
   sample, `npm` scans a repo with no `package.json`, `terraform` a repo with no `.tf`, `docker` a
   repo with no `Dockerfile`. Only `github-actions` can actually find a dependency — in the
   workflows themselves. This is sharper than "a stub ecosystem": four of five entries advertise
   protection that cannot fire.

# 2. Options

Each option is scored against: does it make the CI honest, does it weaken any control, cost,
reversibility, and what it implies for compliance evidence.

### A. Remove the PyCharm stub from all ten repos (recommended, with B)

Delete `main.py`. Stack detection then finds no Python: `ci.yml` emits empty matrices, the
python legs skip, and `CI status` aggregates only the legs that genuinely run.

- **Proven safe, not assumed — twice.** The detection rule itself was read from the workflow on
  the branch: Python is added to `lint`, `typecheck` and `test` when `pyproject.toml` exists **or**
  `requirements*.txt` matches **or** `find . -name '*.py'` returns anything. These repos have no
  manifest and exactly one `.py`, so deleting `main.py` removes the last trigger; no other Python
  file exists in any of the ten (verified per repo). And `viavitae-template` main is already in
  that shape: run 40572423651 logs `detected lint=none typecheck=none test=none build=none
  has_source=false`, has 0 `.py` files, and CI is **success**. Empty matrices are therefore the
  template's *correct* behaviour, distinguishable from VV-2026-10-017's bug only by *why* they are
  empty.
- **Honesty test:** after A, a green `CI status` means "no code to test", not "code tested". That
  is why A must not ship without B — otherwise we recreate the decorative-gate complaint we just
  fixed. The difference is that here the claim ("this repo has no source") is verifiable: one
  `git ls-files '*.py'` returns nothing.
- Weakens nothing: `main.py` is not a test, not a gate, not a control. No test is deleted or
  relaxed. If real Python ever returns, detection re-arms the legs automatically — desired.
- Cost: ten single-file deletions; no CI minutes; no spend.
- Rollback: restore the file. One commit.
- Caveat to state in the ADR: `COVERAGE_MIN: 80` stays declared while unenforced for these repos.
  That is the VV-2026-10-021 smell (documented floor not enforced), so the ADR must say so
  explicitly rather than leave it implicit.

### B. Record the exemption as ADR-0012 in `viavitae-docs` (required, whichever option is chosen)

The template's own CI message offers exactly two routes: *"add tests or record an ADR explaining
why this repository is exempt"*. So the exemption is the sanctioned path, and B is what makes A
auditable instead of silent.

- Target: `viavitae-docs/content/architecture/adr-0012-<slug>.md`, following the existing corpus
  (numbers 0–11 present). Index/CI conventions in that repo must be read **before** writing —
  an ADR that is not indexed fails its own document-control gate.
- Scope: one ADR covering the class ("markdown-and-governance scaffold repos with no source
  code"), listing the ten repos by name, not ten near-identical ADRs.
- Must record: measured evidence (section 1), the fact that `COVERAGE_MIN` remains declared but
  unenforced for these repos, the re-arm condition (adding source re-enables the gate), and the
  release-scope decision from D.
- Authority: `viavitae-docs` is another repository — writing there needs explicit owner
  authorization; it is not covered by the scoped-edit authority used so far in this audit.

### C. Add tests to reach 80 % coverage — **rejected**

Writing tests for `print_hi` would satisfy a number while producing precisely the artifact this
audit exists to remove: a green gate that proves nothing (VV-2026-10-017, VV-2026-10-014). It also
costs ongoing maintenance in ten repos. Rejected on integrity grounds, not effort grounds.

### D. Decide the release scope of these ten repos (VV-2026-10-005) — the actual product question

Given the content lives in `viavitae-demos/templates`, the ten repos are today *governance
containers*, not landing pages. Three sub-choices:

- **D1 keep as per-vertical governance containers** → do A + B, and fix the READMEs (E below).
  Cost: near zero. These repos then ship nothing; `main` green means "scaffold is consistent".
- **D2 turn them into real landing sites** → they inherit the Node stack from
  `viavitae-demos/templates`, real tests become meaningful, and the python legs stop mattering.
  Cost: the largest item in this package (ten sites, content, CI stack switch, hosting).
- **D3 archive / delete the redundant ones** → cheapest estate, but Terraform currently *creates*
  them, so archiving requires changing `repos_data.tf` and running an apply — explicitly outside
  this session's authority (plan-only, never apply without the owner).

Recommendation: **D1 now, and write that down as the decision**, revisiting per repo only when a
vertical actually needs its own site. D1 costs one deletion per repo plus one ADR; choosing D1
without recording it is how "temporary" scaffolds become permanent false claims.

### E. Correct the ten READMEs (independent of A–D, and required either way)

Rewrite the two false sentences (source-of-truth, enterprise-grade template — each occurs exactly
once in each of the ten READMEs, which is what makes a scripted exact-match substitution safe), and
reduce Dependabot to the one ecosystem that can actually read a dependency: keep `github-actions`,
drop `pip`, `npm`, `terraform` and `docker`. Replaces "the claim is inherited from the template"
with "the claim is true for this repo": e.g. *"Governance scaffold for the `<vertical>` surface.
Repository standards live in `viavitae-template`; landing-page content lives in
`viavitae-demos/templates`."* This closes VV-2026-10-024.

# 3. Recommended package and ordering

1. **E** — README truthfulness (10 edits) and Dependabot scope. No CI consequence.
2. **A** — remove `main.py` (10 deletions) on the same open branches, so each propagation PR
   becomes: matrix fix + install fix + scaffold removal. Each PR body updated to say all three.
3. **B** — ADR-0012 in `viavitae-docs` recording the exemption and the D1 scope decision. Needs
   authorization to write that repo.
4. Then merge the ten PRs. Expected post-merge state per repo: `Detect stack`, `Trivy`,
   `Semgrep`, `Compliance status`, pinning, governance, `CodeQL` run and pass; python legs absent
   because there is no Python. `CI status` green **and** explainable.
5. Verify per repo by ref, not by badge: read the run's jobs and step counts, confirming no
   python job is silently skipped-but-expected.

Ordering rule that stays in force: **do not merge before step 2**, or the repo's `main` turns red
on the first push after merge (already demonstrated on the PR heads).

# 4. Security, privacy and compliance implications

- **GDPR / DPIA:** nothing in scope touches personal data; the repos hold markdown governance
  templates (one is `docs/DPIA-template.md`, 72 KB). No Article 9 processing is introduced or
  removed by A/B/E. The privacy claim in the READMEs ("Personal data stays in the EEA") is a
  hosting statement about the wider estate, not something these empty repos can evidence — leave
  it only if the ADR notes it as an estate-level claim.
- **SOC 2 / ISO 27001 control-evidence framing (no certification claim is made here):** a coverage
  gate on a repo with no code is *not* evidence of operating effectiveness. After A + B the
  evidence set is cleaner: either a leg runs and has results, or an approved exemption names the
  repos and the reason. Silent green is the outcome this package must avoid producing.
- **Change control:** `manage_files = false` in Terraform means these file edits are **not**
  reconciled or destroyed by any future apply — safe to do out-of-band, but they are also not
  guarded by the control plane, so drift between the ten repos will not be detected. Note it as a
  known limitation rather than pretending Terraform owns these files.
- **Supply chain:** `main.py` deletion has no dependency effect. Trimming Dependabot to
  `github-actions` *lowers* apparent coverage in a way that must be stated plainly: four ecosystems
  were listed and none of the four could ever resolve a dependency here, so the removal deletes
  decoration, not protection. The org-level Dependabot alerts and security updates remain enabled
  for these repos regardless (they follow the repo's manifests, of which there are none).

# 5. Cost and operational risk

| item | cost | risk if done | risk if not done |
|---|---|---|---|
| A + E (20 file ops across 10 repos) | minutes; no CI minutes; £0 | python legs disappear — must be explained by B, else it reads as a weakened gate | the 10 PRs stay red, `main` breaks on merge |
| B (one ADR) | one document, needs write access to `viavitae-docs` | none material | the exemption is undocumented; audit finding stays open |
| D2 (real landing sites) | the largest engineering item in the estate roadmap | scope explosion | ten repos remain placeholders asserting they are production surfaces |
| merge without A–E | 0 | **breaks `main` in ten repos today** | — |

Rollback for every item is a single `git revert` / one file restore; nothing here touches
credentials, org settings, DNS, hosting or Terraform state.

# 6. STOP conditions (do not proceed past these without the owner)

- Writing to `viavitae-docs` (the ADR) — different repo, not yet authorized.
- Merging any of the ten PRs — the owner merges; nothing in this package authorises a merge.
- Choosing **D2** or **D3** — product/portfolio decisions with cost and deletion consequences;
  D3 additionally requires a Terraform apply, which is out of scope for this session entirely.
- Any option that would delete, skip or relax a **test** or a **required status check**. None of
  A/B/E does; C would have been the wrong kind of "fix" and is rejected.

# 7. Student walkthrough (what each step does and how to check it)

1. *What you are doing:* removing an IDE-generated sample script from ten scaffold repos so that
   CI stops treating them as Python projects. *Why:* the only thing failing the gate is debris.
   Command per repo: delete `main.py` on the existing `fix/ci-matrix-args` branch.
2. *Expected output:* the propagation PR gains one commit; `Test (python)`, `Lint (python)` and
   `Typecheck (python)` disappear from the run and `CI status` reports **success** with the
   security/compliance legs still present.
3. *If it fails:* if a python job still appears, the repo has more Python than the census found —
   re-run `gh api .../git/trees/main?recursive=1` and count `.py` paths again before touching
   anything else. If `CI status` stays red with no python jobs, read which job fails; do not
   assume it is the same cause.
4. *Rollback:* restore the file; the leg returns automatically because detection is content-driven.
5. *Evidence to keep:* the run id, per-job conclusions and step counts *after* the change, plus the
   ADR number. A screenshot of a green badge is not evidence; a run id is.

# 8. Acceptance criteria for this package

- Each of the ten repos: `gh api .../contents/main.py?ref=main` returns 404 **and** the README no
  longer claims to be the org's repository template or the source of truth for new repos.
- One approved ADR (proposed number 0012, verify free at write time) naming all ten repos, the
  evidence, the re-arm condition, and the fact that `COVERAGE_MIN: 80` is declared-but-unenforced
  for them.
- Ten propagation PRs green and mergeable, each body describing all three changes it carries.
- Register: VV-2026-10-024 closed only after the ten READMEs are re-read **by ref**, not from a
  local clone; VV-2026-10-005 moves from PENDING to a recorded D1/D2/D3 choice.
