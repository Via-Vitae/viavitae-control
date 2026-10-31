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
  - "2026-10-27 pilot addendum (§9): option E is 25 README references plus 23 in
    docs/architecture.md, not two sentences; is_template is true for 0 of 31 repos including
    viavitae-template, which asserts otherwise in its own README → new finding VV-2026-10-025;
    option A confirmed on basilica (run 40587988368, head f73ee589, gate CLEAN)"
  - "2026-10-27 pre-pilot correction: §1 Dependabot row sharpened from one stub ecosystem to
    four decorative ones, and option A's detection rule quoted from the workflow itself"
  - "2026-10-28 independent review (register E48): the basilica pilot has **merged** (`main`
    `6e9d18fd`, CI success), so nine repos remain, not ten; the Dependabot defect is mis-framed
    here — the config file instructs per-repo trimming and each untrimmed entry is a **weekly
    failing check run**, not decoration, and it spans **12** repos (45 dead entries), not 10;
    required status contexts measured on all ten landings (the safety argument §2A was missing);
    post-merge legs are **skipped, not absent**; §3's ordering rule and §5's `git revert`
    rollback claim are both wrong as written — see §10"
  - "2026-10-31 re-validation of §10 (register E49): two of §10's own quantifiers were over-stated
    — **44** of the 45 dead entries fail weekly, brand's `pip @ /` **passes vacuously** — and
    VV-2026-10-027 is narrowed, because Dependabot's security-update path does reach undeclared
    directories. The outcome check added to the guard found a defect §10 could not see: failing
    npm updaters in `viavitae-qa` and `viavitae-web` on valid configs (VV-2026-10-028). All nine
    PRs re-confirmed current against `main` and still blocked on `CI status`; 0012 still free."
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
| landing repos | 10 open propagation PRs at the time of writing; **nine** now — basilica's #6 merged as `main` `6e9d18fd` on 2026-10-28 (E48) | API filter + `pulls?state=open` |
| files per repo | 19 in each of the nine; 18 in basilica after its stub deletion | `git/trees/main?recursive=1`, blobs only |
| Python files per repo | **1** in each of the nine (`main.py`, identical blob `5596b447…` in all nine); **0** in basilica | tree census |
| that file | `main.py`, 528 bytes, PyCharm sample: `This is a sample Python script`, `def print_hi(name)`, `print_hi('PyCharm')` | contents API at `ref=main` |
| markdown files | 8 · toml/yaml 6 · js/ts/jsx/vue **0** | tree census |
| deployable web artifacts | **none** — no `index.html`, no `package.json`, no `hugo.toml`, no `netlify.toml`, no `Dockerfile` | tree census |
| declared coverage floor | `COVERAGE_MIN: 80` in all 10 | `ci.yml` at the PR branch |
| Dependabot | declares **five** ecosystems all pointed at `/`: `pip`, `npm`, `github-actions`, `terraform`, `docker` — and the repo contains **0** files any of them can read except the Actions workflow. **Corrected framing (E48): the file's own header orders this** — `Delete the ecosystems that do not apply to the repository type`, and the Terraform and Docker blocks each say `Delete this block elsewhere`. So the defect is an **unfinished, documented step**, and the four stale entries are not harmless: each is attempted weekly and reported as a **failing check run** on `main`. Measured, not inferred | `.github/dependabot.yml` header at `ref=main` + `actions/runs?event=dynamic`: cathedral 4 failures × 3 Mondays (10-12/10-19/10-26), basilica's stopped the week after its trim merged |
| Terraform | 10 blocks, `tier = "site"`, `manage_files = false` in **all** 10 | `repos_data.tf` |
| README | 12.9–13.0 KB, 10 distinct hashes (individually parameterised), and **all 10** contain "single source of truth for how a ViaVitae repository looks" and "Enterprise-grade repository template for regulated, EU-hosted software delivery" | contents API |
| the real template | `viavitae-template` makes the same two claims, has **no** `main.py` — and is the only repo where the claim is true | contents API |
| basilica CI now | **merged and green**: `main` `6e9d18fd` CI success. The nine remaining PR heads still fail `Lint (python)`, `Test (python)`, `Typecheck (python)` and the required `CI status`, while `Detect stack`, `Trivy`, `Semgrep`, `Compliance status`, `Action SHA pinning`, `Governance files`, `CodeQL` pass | check-runs per head + run list on `main` (E48) |
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
- **Second safety pillar, measured on all ten (E48) and missing from the first edition:** the
  removal is safe only if no *required* status check names a python leg. Measured live on every
  one of the ten landings: classic branch protection (no rulesets anywhere) with
  `required_status_checks.contexts = ["CI status", "Compliance status"]` and `strict = true`.
  Both aggregates survive the deletion, so merges cannot freeze with an "expected" check that no
  workflow reports. Stack detection alone was not sufficient evidence — in a repo whose contexts
  name `Test (python)` byte-for-byte, option A would block every later merge instead of cleaning it.
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
once in each of the ten READMEs, which is what makes a scripted exact-match substitution safe) and
reduce Dependabot to the one ecosystem that can actually read a dependency: keep `github-actions`,
drop `pip`, `npm`, `terraform` and `docker`. **Split out (E48): the Dependabot half is not a
prose-truthfulness item and it is not confined to the ten.** It is a live integration failing
weekly in **12** repos — see register VV-2026-10-026, whose remedy set also includes
`viavitae-brand` and `viavitae-clients`, and whose brand case is the *opposite* defect (real
manifests in `tools/` and `build/` that no entry points at, so those dependencies are unmonitored)
and needs `directory:` re-pointing, not deletion. Replaces "the claim is inherited from the
template" with "the claim is true for this repo": e.g. *"Governance scaffold for the `<vertical>`
surface. Repository standards live in `viavitae-template`; landing-page content lives in
`viavitae-demos/templates`."* This closes VV-2026-10-024.

# 3. Recommended package and ordering

1. **E-README** — truthfulness prose (owner wording, currently blocked on VV-2026-10-025). No CI
   consequence. The Dependabot half moved out to VV-2026-10-026 (12 repos) and is executable now.
2. **A** — remove `main.py` (nine deletions) on the same open branches, so each propagation PR
   becomes: matrix fix + install fix + scaffold removal + Dependabot trim. Each PR body updated to
   say all four, and it must keep a standalone `ai:review` trailer — the `provenance.yml` gate
   re-runs on `edited` and a body without the trailer turns the gate BLOCKED (§28 item 18).
3. **B** — ADR-0012 in `viavitae-docs` recording the exemption and the D1 scope decision. Needs
   authorization to write that repo.
4. Then merge the nine PRs. Expected post-merge state per repo, measured on basilica `main` rather
   than predicted (E48): `Detect stack`, `Trivy`, `Semgrep`, `Compliance status`, pinning,
   governance, `CodeQL`, `Licence compliance`, `Secret scanning` run and pass, **and the python and
   build legs still appear — as `skipped` check runs with `steps: 0`, not absent**. Their displayed
   names stay literally `Lint (${{ matrix.stack }})`, `Test (${{ matrix.stack }})` etc., because an
   empty matrix never expands the `name:` expression; `CI status` green **and** explainable.

Ordering rule, **corrected (E48)**: the first edition said "do not merge before step 2", which
permits merging after A but before B — and A-without-B is precisely the *silent green* §4 says this
package must avoid. The rule is now: **A and B land together, or the exemption's absence is
registered as an open finding until the ADR exists.** Basilica already violated this sequencing in
the order the first edition recommended: it is CI-green on `main` with **no ADR written**, so its
green state currently has no documented justification. That is the cost of the ordering error, and
it is why VV-2026-10-024 cannot be closed on basilica yet.

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

Rollback, **corrected against the measured merge shape (E48)**: the first edition promised "a
single `git revert` / one file restore" per item. This org squash-merges, so the three concerns
arrive on `main` as **one commit touching three files** — basilica `6e9d18fd` carries
`.github/dependabot.yml`, `.github/workflows/ci.yml` and `main.py` with a single parent. `git
revert` of it therefore re-adds the stub, re-breaks `CI status` and un-trims Dependabot at once.
Per-item rollback is a **new commit** restoring one file (`gh api .../contents/<path> --method
PUT`, or `git checkout <old-sha> -- <path>`), not a revert; the one exempt case is that a
`Revert ` subject skips the provenance trailer rule. Nothing here touches credentials, org
settings, DNS, hosting or Terraform state.

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

Split (E48) so that the executable work is not gated on the blocked work. The first edition
bundled "`main.py` gone" with "README no longer claims template status" into one criterion, which
made nine repos' CI-honesty depend on an owner editorial decision about governance prose and could
have kept `main` red indefinitely while nobody owed anything.

**Gate A+B — closes VV-2026-10-020's landing half, executable today:**
- Each of the nine remaining repos: `main.py` absent at `ref=main` after its PR merges (basilica
  already satisfies this — verified 0 `.py` blobs at `ref=main`).
- One approved ADR (proposed number 0012, verify free at write time) that names the ten repos
  **and states the predicate that admits a repo to the class**, not only the list — otherwise an
  eleventh scaffold created later sits outside the exemption while being equally untested.
  Must record: the evidence, the re-arm condition, `COVERAGE_MIN: 80` declared-but-unenforced, and
  the D1 scope choice.
- Nine propagation PRs green on their heads and mergeable; `CI status` and `Compliance status`
  both passing, since those are the only required contexts.

**Gate E — closes VV-2026-10-024, blocked on the owner:**
- README, `docs/architecture.md` and `CONTRIBUTING.md` re-read **by ref** (never from a local
  clone) showing no template-status claim, with wording the owner chose — and that wording depends
  on VV-2026-10-025 route (a) or (b), which is still unchosen.
- VV-2026-10-005 moves from PENDING to a recorded D1/D2/D3 choice.

# 9. Addendum after the basilica pilot (2026-10-27) — this package was partly wrong

The owner chose to pilot one repo before the sweep. That decision falsified two claims in this
document, which is the reason pilots exist.

1. **Option E is not "two sentences".** `viavitae-landing-basilica/README.md` carries **25**
   `template` references, including binding governance rule **R1 - Template-first** ("Every
   ViaVitae repository is generated from `viavitae-landing-basilica`"), a working
   `gh repo create --template Via-Vitae/viavitae-landing-basilica` command, and a §4 sync policy
   ("Template improvements flow outward only … Never edit the template inside a" generated repo).
   The same corpus appears in `docs/architecture.md` (**23** mentions) and `CONTRIBUTING.md` (4).
   So E is a prose decision across three documents in ten repos, not a scripted substitution, and
   it was deliberately **not** executed in the pilot. Anyone applying this package should treat §2
   option E as needing owner-drafted wording, and should not let a bulk script invent it.
2. **A new finding, VV-2026-10-025, sits underneath option E.** `is_template` is `true` for **0 of
   31** repos in the organisation — including `viavitae-template`, whose own README line 37 states
   "This repository is marked **Use this template** on GitHub" and line 50 gives the browser path.
   Meanwhile the control plane never names any repo as a template source. So the documented
   creation procedure cannot be executed anywhere, and fixing the landing READMEs without deciding
   this leaves the org describing a mechanism that does not exist in either place. Route (a) enable
   templating on `viavitae-template`, or route (b) document the Terraform-declared path — pick one
   first, because the wording of option E depends on which is true.
3. **Option A is confirmed.** Pilot on basilica: `main.py` deleted and Dependabot trimmed 186 → 46
   lines, keeping `github-actions` only. CI run 40587988368 at head `f73ee589` logs
   `detected lint=none typecheck=none test=none build=none`; python and build legs skip with
   `steps: 0`; `Detect stack` (5), `SAST (Semgrep)` (9), `Dependency scan (Trivy)` (9) and the
   required `CI status` (3) all **success**; gate **CLEAN**. Two implementation traps worth
   repeating: my first trim left **orphan comment headers** for the removed ecosystems (valid YAML,
   newly misleading) — fixed by treating each comment header plus its entry as one unit and
   asserting no dropped ecosystem name survives in the output; and the `updates` list must be
   re-parsed and each remaining entry checked for its `schedule`, not just counted.
4. **What the pilot does not prove.** It does not prove the other nine repos behave identically —
   it proves the mechanism. Per-repo assertions remain mandatory before each write, and the
   Dependabot file in each repo must be re-read rather than assumed identical (the READMEs already
   proved to be individually parameterised, ten distinct hashes).

# 10. Independent review of this package (2026-10-28) — seven defects, all measured

Every claim above was re-derived from the live API rather than trusted. Verdict on each component:

| component | necessary? | appropriate? | what the review changed |
|---|---|---|---|
| A, delete `main.py` in nine repos | **yes** — the sole cause of red on all nine heads | yes; verified per repo: exactly one `.py`, identical blob `5596b447…`, no `tests` dir, no `test_*.py` | added the missing second safety pillar (required contexts) and corrected "legs absent" to "legs skipped" |
| B, ADR-0012 | **yes** | yes, but must state a class predicate, not only a list | must now land *with* A, not after it; basilica is already out of compliance with that rule |
| C, tests for `print_hi` | correctly **rejected** | rejection correct | unchanged |
| D, scope decision (D1 recommended) | yes | D1 correct on the evidence | unchanged |
| E, README prose | yes | correctly **not executed** by script | Dependabot half split out into VV-2026-10-026 with a wider scope and different remedies |

**1. The Dependabot defect was mis-framed and under-scoped.** The config file is not advertising
protection it lacks — it *orders* the reader to trim: `Delete the ecosystems that do not apply to
the repository type`, and the Terraform and Docker blocks say `Delete this block elsewhere`. The
step was simply never executed. And the dead entries are not harmless: each is attempted on the
declared weekly Monday schedule. Measured per repo on the 2026-10-26 cycle, **44 of the 45 dead
entries produced a FAILING check run** on `main` (nine landings and the template 4 each, brand 3,
clients 1) — cathedral shows three consecutive Mondays each with `github_actions` **success** and
`pip`, `npm_and_yarn`, `terraform`, `docker` **failure**, annotated `Dependabot encountered an error
performing the update`. The exception is the more alarming half, corrected in E49: **brand's
`pip @ /` PASSED on 10-12, 10-19 and 10-26 while resolving nothing** — a dead entry can be silently
green, so "is it red?" is not a test for "does it work?". Basilica is the control on the other side:
its four failures stopped the week its trim merged. A new read-only guard,
`scripts/check_dependabot_scope.py`, measures the whole estate: **45 dead entries across 12
repos** (nine landings `4` each, `viavitae-template` `4`, `viavitae-brand` `4`,
`viavitae-clients` `1`) and **5 real manifests that no entry points at**. So the template must not
be trimmed as part of a sweep — the superset is its purpose — but it is *not* exempt from the cost:
the template's own repo fails four updates every week too.

**2. The mirror defect, finding VV-2026-10-027 (narrowed by E49).** `viavitae-brand` holds
`tools/requirements.txt` and `build/package.json` while its `pip` and `npm` entries point at `/`, and
`api` and `docs` ship a root `Dockerfile` with no `docker` entry at all. The first edition of §10 said
those dependencies get "no version updates and no Dependabot alerts", i.e. total blindness — that was
too strong. Dependabot's **security-update and dependency-graph** paths do reach undeclared
directories, proven by brand's own run names (`pip in /tools for Pillow - Update`, 2026-10-24) and
api's `Graph Update: uv`. What is actually missing is **version currency**: routine bumps and their
grouped PRs. The remedy is unchanged — re-point `directory:`, do not delete — because a blanket trim
across "repos with dead entries" would still have made brand worse.

**3. A necessary safety argument was missing.** Option A's case rested on stack detection. The
load-bearing fact is that on all ten landings the required contexts are exactly
`CI status` and `Compliance status` (classic protection, no rulesets), so a removed leg can never
leave a merge waiting on a check that no longer exists. Verified, not assumed.

**4. The expected post-merge state was wrong.** Legs do not disappear; they remain as `skipped`
check runs whose names are the unexpanded expressions `Lint (${{ matrix.stack }})`,
`Test (${{ matrix.stack }})`, `Build (${{ matrix.stack }})`. Cosmetic in the code, unhelpful to an
auditor reading a checks page, and worth naming so nobody mistakes a skipped leg for a missing gate.

**5. The ordering rule contradicted §4.** "Do not merge before step 2" permits A-without-B, i.e.
the silent green this package says it exists to prevent — and basilica is in exactly that state now
(CI green, no ADR). §3 corrected; §8 split into a Gate A+B and a Gate E so blocked prose cannot
hold nine repos red.

**6. The rollback promise was false as written.** See §5: squash merges collapse three concerns
into one commit, so `git revert` is all-or-nothing. Per-item rollback needs a new single-file
commit.

**7. Numbers stated without their counting rule are not reproducible.** §9.1 reports "25" README
references and "23" architecture references. Measured under one rule (case-insensitive
occurrences): README 25, `docs/architecture.md` **26**, `CONTRIBUTING.md` 4 — the 23 is *lines*
containing a match, not mentions. Likewise "186 → 46 lines" is **185 → 45** under
`splitlines()`; the earlier figures counted the trailing newline. Each number in a compliance
artifact must name its instrument, as E33 requires for alert counts.

**8. A defect the review round's own tool could not see (VV-2026-10-028).** After adding an outcome
cross-check to the guard (`--check-runs`), `viavitae-qa` and `viavitae-web` — both fully clean on the
config check, both with real root manifests — turn out to **fail their `npm_and_yarn` updater**
(measured failing runs targeting `fast-uri` and `markdown-it`, whose alerts are still open as at
2026-10-31). Detection works; auto-remediation does not. Cause is undetermined: the per-update log
requires write access. This is the strongest argument in the package for measuring outcomes rather
than configurations — a green config audit is not evidence that monitoring functions.

**Instrument defects found in the reviewer's own tooling** (recorded because they are the reason
the first pass could have been published wrong): `gh api <path> -f ref=main` silently switches the
verb to **POST**, so every contents read returned 404 and looked like absent files — the pilot
script's explicit `--method GET` was the tell; `--jq '[.content,.sha] | @tsv'` escapes the newlines
inside the base64 payload and decodes to garbage (`UnicodeDecodeError 0x9d`), so one JSON read is
required; a first-pass "does this manifest exist anywhere" test ignored `directory:` and would have
filed `viavitae-brand` as *having* python coverage; and the same test flagged 12 pnpm workspace
members (qa, demos, web) as unmonitored until `pnpm-workspace.yaml` was read — all six qa entries
were false positives. The pilot script also **aborted** if an item was already done, which in a
nine-repo sweep makes a partial run unresumable; the replacement driver treats DONE as skip and
only an unexpected state as abort, and its trim output was checked byte-for-byte against the
already-merged, CI-green basilica artifact rather than against its own assertions.
