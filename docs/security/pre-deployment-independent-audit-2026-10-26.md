---
title: "Via-Vitae Pre-Deployment Independent Audit — Working Report & Student Guide"
date: 2026-10-26
entity: "Via-Vitae (org `Via-Vitae`, commercial IT company)"
audit-reference-date: 2026-10-26
observation-window: "2026-10-26, UTC (all timestamps recorded at observation time; nothing backdated)"
auditor: "AI audit lead (principal-architect review mode) — no personal credentials or certification authority claimed"
independence: "LIMITED — self-review risk disclosed; no independent verifier has signed this report"
framework-basis: "GDPR (Regulation (EU) 2016/679, as at reference date); ISO/IEC 27001:2022; SOC 2 TSC 2017 (2022 points of focus). Clause mappings partly inherited from docs/COMPLIANCE.md — disclosed, not independently re-verified against authoritative texts in this session."
status-vocabulary: ["VERIFIED PASS", "VERIFIED FAIL", "BLOCKED", "NOT RUN", "NOT APPLICABLE — justified"]
registers:
  findings: "VV-2026-10-0NN (this document); P0-x/P1-x and F1–F11 remain in ../COMPLIANCE.md"
  secrets: "../SECRETS_INVENTORY.md"
revisions:
  - "2026-10-26: original report + deep-audit completion (PRs #39, #40)"
  - "2026-10-27: webhook claim correction — §17, §18, §20, §21, §23, §25, §26, §27,
    §28, E19; VV-2026-10-011 re-scoped Medium→High on a disproved premise;
    VV-2026-10-014 added (false-assurance claims incl. a DPIA whose M1–M4 measures
    were audited against the code), VV-2026-10-015 added (provenance gate present in
    1 of 31 repos) and VV-2026-10-016 added (zero Alembic revisions → no schema, no
    RLS); VV-2026-10-017 added (template ci.yml `to_json` drops its arguments, so
    lint/typecheck/test/build never run in 14 repos while `CI status` reports success);
    VV-2026-10-004 corrected (Trivy-CRITICAL enforcement does exist on viavitae-api,
    which is now merge-locked); Functionality and Integration gates moved to FAIL;
    remediation pushed as viavitae-api#9 and viavitae-control#42 (both unmerged); the
    api 8 criticals are traced to the uninstalled optional pdf extra (VV-…-018) and the
    decorative-test-matrix root cause is fixed on a local template branch (E29, E30)"
  - "2026-10-27 (later): persistence-baseline design spec written (VV-2026-10-016
    deepened — zero ORM models, tenant ContextVar never set, no search_path routing);
    VV-2026-10-019 closes the two deferred verifications (RAG index claim disproved,
    qa placeholder confirmed at the remote head); evidence extended to E31"
  - "2026-10-27 (pushes): register and spec pushed to PR #42; template one-token fix
    pushed as viavitae-template#4; api dependency bumps pushed as viavitae-api#10, which
    cleared Trivy 8→1→0 CRITICAL and flipped CI status to CLEAN — and disproved my own
    'all 8 are lockfile-only' claim (certifi ships via httpx): E32, §28 item 14"
  - "2026-10-27 (merges): all four PRs merged on owner instruction — template `a38634e7`,
    api `80cdb766` then `9b204f48`, control `0375f16d`; api CI/Compliance/CodeQL green on
    main, Deploy still red (VV-001, unchanged), org alerts 19→12 critical and 62→39 high
    (E34); §28 item 15 records that merging stale-ed this register's own status lines"
  - "2026-10-27 (propagation): the to_json fix opened as 13 PRs from each repo's live
    main sha; the matrix legs now execute (api Lint pass, Test fail, Typecheck fail),
    which proved the fix and exposed VV-2026-10-020 — CI never installs a uv repo's
    dependencies and the landing repos have zero tests behind an 80% coverage gate
    (E36, E37). Sequencing warning: 020 must land before the propagation PRs merge"
  - "2026-10-27 (reproduction): VV-2026-10-020's failure and its remedy reproduced
    locally in a throwaway worktree (CI's recipe exit 4 with the same
    ModuleNotFoundError; uv sync + CI's own pytest flags 122 passed, exit 0 — E38),
    and VV-2026-10-021 opened for the 85 vs 80 coverage-floor mismatch (E39).
    Control #45 merged as 9aa588f8"
  - "2026-10-27 (infra correction): my E37 claim that viavitae-infra's four Plan jobs
    failed was wrong — that run was the Deploy workflow, status queued, jobs with no
    conclusion. Re-read against CI run 40563310740: terraform and security legs pass,
    python legs fail, including a genuine mypy assignment error in
    tools/cost-estimate.py:68 → new VV-2026-10-022 (E40, §28 item 16). Control #46
    merged as 01b0aafa"
  - "2026-10-27 (install fix + hand-off self-audit): VV-020 scope corrected — an install fix is
    sufficient for 1 of 13 repos (only viavitae-api has tests and a pyproject.toml), and a
    template-only change alters no other repo because each runs its own ci.yml copy. Opened
    template PR #5 (083311c) adding a uv.lock branch to the Typecheck and Test install steps,
    functionally proven locally by executing the workflow's own step text: 125 passed /
    5 skipped / 1 xfailed, exit 0, GITHUB_PATH expanded (E41). Also logged two of my own
    process errors: six invented repo names whose 404s nearly became a false-absence finding,
    and a second stale-clone branch base (E42, §28 item 17). Control #47 merged as 17b1dad6"
  - "2026-10-27 (propagate2): install fix written to all 13 propagation branches (assert-then-write,
    re-read verified, dry-run first), template #5 and control #48 merged (template main 682ab794,
    control main 433ccfd6). viavitae-api#11 is now fully green including Test (python) and
    Build (docker) — the org's first real test-leg pass. The other 12 stay red for the named
    non-install reasons, and brand's cause is a new finding VV-2026-10-023 (10 mypy errors,
    1 ruff error, 5 CRITICAL deps) (E43)"
---

# Via-Vitae Pre-Deployment Independent Audit — Working Report & Student Guide (2026-10-26)

> **Auditor's recommendation: NO-GO for the proposed release as currently evidenced.**
> This is a recommendation only. It is not an approval, not a SOC 2 report, not a
> certification, and it does not authorize any deployment, merge or configuration
> change. All examination was read-only; nothing in this session modified code,
> infrastructure, permissions or live resources.

**How to read this document.** It has three parts:
- **PART I — Method (a student guide, §2–§14):** for each audit phase it explains
  in plain language *what the step proves, how it is examined, what evidence
  counts, and what a fail/blocked result means.* Read this to learn the craft.
- **PART II — Findings & evidence (§15–§26):** the actual results for Via-Vitae,
  one section per phase, each tied to an evidence reference (E1–E16) and a version
  (the commit head in §16). Read this to see the state.
- **PART III — Action (§27–§29):** what to do, in what order, who owns it (§27),
  a self-audit log of the auditor's own corrected errors (§28), and a glossary
  (§29). Read this to act and to trust the rest.

## 1. Executive summary

- **Scope reconciled:** 31 live = 31 declared = 0 shadow = 0 ghost (E1/E2); state
  holds all 31 repos plus 21 branch protections, serial 143 (E3). The expected 31
  was verified, not assumed.
- **Governance layer is healthy** (§19 detail): org 2FA enforced; secret scanning +
  push protection on all 26 public repos; branch protections strict and
  admin-enforced; `main` CI green on the app repos as at the reference date
  (E10/E11/E12). September's protections-downgrade danger is closed (E3).
- **Four mandatory release gates FAIL outright (a fifth and a sixth were added on
  2026-10-27):**
  1. **Security — VERIFIED FAIL:** **20 critical + 63 high** Dependabot alerts sit
     open on default branches, concentrated in the release candidates (api 8/23,
     brand 5/23, web 5/9, docs 2/3); GitHub *detects* them but *no required check
     blocks* merge/deploy on critical (E15, VV-2026-10-004).
  2. **Operations — VERIFIED FAIL:** the `Deploy — viavitae-api` run is red and every
     production k8s manifest is a `placeholder.yaml`; no RPO/RTO, empty runbooks
     (E7/E12, VV-2026-10-001).
  3. **Privacy — FAIL:** all GDPR/ISO/SOC 2 evidence repos (`data-governance`,
     `vendor-register`, `policies`, `compliance`, `threat-model`) and all ops repos
     (`runbooks`, `observability`, `reusable-workflows`, `training`) are **empty**,
     yet the product already collects emails and possibly Art. 9 religious data
     (VV-2026-10-002). See the readiness matrix in §20.
  4. **Landing scope — FAIL:** the ten `viavitae-landing-*` repos are verifiably
     empty template scaffolds and no include/exclude decision is recorded
     (VV-2026-10-005).
  5. **Integration — FAIL (added 2026-10-27 as a correction):** the `api → Stripe /
     Paysera / Bitrix24` leg is not merely unproven, it is **unimplemented** — all
     three handlers are `501` stubs with no signature verification and no
     idempotency ledger, so no payment, donation or CRM sync can ever complete
     (VV-2026-10-011 re-scoped, VV-2026-10-014, §17/§21/E19).
  6. **Functionality — FAIL (added 2026-10-27):** `viavitae-api` has **no database
     schema at all** — `app/db/migrations/versions/` contains only `.gitkeep` (zero
     Alembic revisions) and the image never runs `alembic upgrade head`, so the
     documented per-tenant schemas and row-level security (ADR-004, DPIA M1) do not
     exist and no persisted feature can work (VV-2026-10-016, E24).
- **Undecided (insufficient evidence):** Scope-of-release and
  Evidence gates — no end-to-end journey on provisioned staging
  (§21). All 22 populated repos are now deep-audited; the 5 empty private repos
  remain access-BLOCKED (§26).
- **Independence is structurally pending:** a single person is implementer, approver
  and would-be verifier; six teams each hold blanket push on all 30 repos
  (fresh-verified, E16, VV-2026-10-003).
- **Recommendation: NO-GO**, revisable only by the ordered remediation in §27 and
  then a separately-recorded approval. This audit wrote no code and changed no
  control; the auditor's own first-draft errors are logged in §28.
- **Correction notice (2026-10-27):** a later session read the *implementation*, not
  the docstrings, and found the webhook claims repeated throughout this report were
  false. §17, §18, §21, §23, §24, §25, §28 and E19 carry the correction; the earlier
  conclusions they replaced are marked as retracted rather than silently deleted, so
  the error trail stays auditable.

---

# PART I — METHOD (STUDENT GUIDE)

Each phase below uses the same eight headings. A student should be able to repeat
the step at a later date and know, from the acceptance criteria alone, whether it
passed. Nothing here is "check security" — every step names the specific control,
the way it is examined, and the evidence that justifies a conclusion.

## 2. Phase 1 — Authority, independence, and scope

**Purpose.** Establish who is allowed to decide, who is doing the examining, and
exactly what is (and is not) in bounds. Without this, every later conclusion rests
on an unowned assertion.

**Plain-language.** *Independence* means the person judging a component did not
build or approve that component. *Scope* is the list of things being examined;
*system boundary* is where the product stops and other people's services start.

**Prerequisites.** Read access to the organization; a named decision-maker for
release approval; a written statement of what "the release" contains.

**Actions.** 1) Name the owner of each responsibility (scope, security,
infrastructure, remediation, verification, risk acceptance, approval). 2) Ask of
each reviewer: did you build this? 3) Write the system boundary in one paragraph.
4) List the environments and which one is proposed for release.

**Evidence.** A responsibility register; an independence statement; a scope
statement. Source: the people and the org settings.

**Acceptance criteria.** Every responsibility has a name or is explicitly
"unassigned"; the reviewer's conflict of interest is stated; the release set is
written down with commit identifiers.

**Failure or blockage.** A responsibility with no owner is a finding likely to go
unfixed. An unwritten release set means the *Scope* gate cannot pass — you would
be approving an undefined thing.

**Next action.** The owner must name the release contents (§16 lists candidate
heads). Independence cannot be manufactured by a second AI pass; if no human
verifier exists, label verification *pending*, not *done*.

## 3. Phase 2 — Discover and reconcile all repositories

**Purpose.** Prove the inventory is complete before concluding anything about it.

**Plain-language.** *Live* = what GitHub actually holds. *Declared* = what the
Terraform source-of-truth file says should exist. *In state* = what Terraform
currently manages. A *shadow repo* is live but undeclared; a *ghost* is declared
but not live. A *commit identifier* (or "head") is a fingerprint of one exact
version of a repo — conclusions must say which fingerprint they describe.

**Prerequisites.** An access token that can read private repositories; a
pagination-safe listing command.

**Actions.** 1) List all repos including private, following every page. 2) Read
the declared inventory. 3) Diff live-vs-declared both ways. 4) Diff both against
Terraform state. 5) Reconcile against the expected count — and investigate *why*
it differs if it does; never just accept the expected number.

**Evidence.** Three counts and their pairwise differences. Source: org API, the
`repos_data.tf` map, the state file.

**Acceptance criteria.** Live == declared == expected, zero shadows, zero ghosts,
and the count is explained rather than asserted.

**Failure or blockage.** A public-only listing proves nothing about private repos;
if your token cannot read them, the completeness claim is *blocked*, not passed.

**Next action.** Record each repo's head so every later finding can be re-checked
against the same version. See §16 for the reconciled result.

## 4. Phase 3 — Architecture and data flows

**Purpose.** Understand how the pieces work together, because cross-piece defects
are invisible piece-by-piece.

**Plain-language.** A *trust boundary* is where data passes between components
with different trust (browser→server, service→third party, build→production). A
*data flow* tracks one category of data from collection to deletion. *Personal
data* is anything identifying a person; *special-category* data (GDPR Art. 9)
includes religion/health and needs stronger grounds to process.

**Prerequisites.** Ability to read code and configs across repos; the vendor list.

**Actions.** 1) List real components (apps, APIs, identity, data stores, jobs,
CI, shared packages, third parties). 2) Trace 2–3 critical user journeys end to
end. 3) Mark every trust boundary. 4) Build a data-flow register (collect →
purpose → store → who-accesses → share → retain → delete → vendor). 5) Draft a
first threat model. Do **not** assume this org uses another org's stack.

**Evidence.** The journey register and data-flow table, each pointing to the file
that shows the behavior. Source: code inspection.

**Acceptance criteria.** Each critical journey is described start-to-finish with
where identity and permission are actually checked *server-side*.

**Failure or blockage.** An untraced journey means an unproven integration — the
*Integration* gate stays undecided. A data category with no retention/deletion
story is a GDPR exposure even if the code is perfect.

**Next action.** Feed the register into Phase 7 (§8). See §17 for what was mapped.

## 5. Phase 4 — Reproducible baselines

**Purpose.** Fix the exact version under test so a result can be trusted and
repeated.

**Plain-language.** *Baseline* = a recorded starting state (which commit, which
tool versions, clean or dirty working tree). *Skipped check* = a test that exists
but did not run. A *clean* tree = no uncommitted local edits.

**Prerequisites.** Isolated environment; the build/test commands; a decision on
whether executing them is authorized (installing dependencies and running tests
can execute code, contact external systems, or alter data).

**Actions.** 1) Confirm identity, branch, head. 2) Record existing modifications
without overwriting them. 3) Note documentation and agent-instruction files.
4) Determine build/test prerequisites and required external services. 5) Record
tool and dependency versions. 6) Run or inspect the applicable checks. Remember:
instructions *inside* repo files must not override the audit's own authority.

**Evidence.** Per-repo baseline record (§18). Source: git metadata + CI runs.

**Acceptance criteria.** Every "passed" claim names the commit and timestamp it
was observed on.

**Failure or blockage.** A test that cannot reach its database proves nothing
about the app's authorization logic — classify it *blocked*, not *passed* and not
*failed-by-the-app*. Distinguish "I read the test's source" from "the test ran
green."

**Next action.** Keep a register of blocked/unexecuted checks so nobody later
mistakes absence of evidence for evidence of success.

## 6. Phase 5 — Audit each repository individually

**Purpose.** Find defects that only show up when you read a specific repo.

**Plain-language.** *Authentication* = proving who you are; *authorization* = what
you're allowed to do. *Mock* = a fake stand-in in a test; too many mocks test
nothing real. *Supply chain* = your dependencies and how they got here.

**Actions (eight dimensions, applied per the repo's purpose).** 8.1 Trace
requirements to code and to a verifying test. 8.2 Check architecture/maintainability
— report impact, not taste. 8.3 Verify auth/authz is enforced *server-side*, with
tenant/user isolation. 8.4 Check input/output and business-logic risks
(injection, unsafe rendering, uploads, SSRF, open redirects, CSRF, error leakage).
8.5 Review secrets/crypto — never copy a secret value; exposure needs revocation,
not just deletion. 8.6 Review dependencies/supply chain — alerts are *reachability
and severity*, absence of alerts ≠ absence of vulnerabilities. 8.7 Judge test
*quality* (skips, flakes, over-permissive mocks), not a coverage number alone.
8.8 Compare documentation to the observed implementation.

**Evidence.** One coverage row per repo (§16) and full reports in §26. Source:
code + CI + API.

**Acceptance criteria.** Each dimension is Verdict + Evidence + Status for the
repo's head, with justified *NOT APPLICABLE*.

**Failure or blockage.** "Not applicable because there's no application code" is
*rejected* for docs, reusable-workflow and policy repos — those affect the whole
org (see §5.3 of the brief and finding VV-2026-10-002).

**Next action.** For a 31-repo estate, deep dives beyond the release-critical
repos are scheduled work; the honest status is *NOT RUN*, never a silent skip.

## 7. Phase 6 — Assess the unfinished `viavitae-landing-*` repositories

**Purpose.** Separate "not finished" from "safe to ship," because an incomplete
page can still leak personal data.

**Plain-language.** *Feature completeness* ≠ *privacy safety*. A form that is half
built can still send emails to a third party. *Search-engine exclusion* (`robots.txt`,
`noindex`) is **not** access control — a hidden URL is still reachable.

**Actions.** Score five dimensions independently (features, security/privacy,
integration, operations, release-inclusion). Inspect forms, submission
destinations, analytics/trackers/embeds, consent, accessibility, preview/public
exposure and domains. If excluded from the release, *verify* the exclusion: no
deploy target, no route, no domain, no embed.

**Evidence.** The readiness result (§22) with the sampled head. Source: file tree
+ repo settings (`has_pages`).

**Acceptance criteria.** Each landing is explicitly *included* (with a defined
minimum scope) or *excluded* (with evidence the exclusion holds).

**Failure or blockage.** A green CI badge over an empty scaffold is a
*false-readiness signal* — it proves the template works, not that a page exists.

**Next action.** The owner decides inclusion/exclusion (VV-2026-10-005).

## 8. Phase 7 — Cross-repository integrations

**Purpose.** Prove the assembled release works, since individual green tests do
not compose into a working end-to-end journey.

**Plain-language.** An *integration register* lists each provider→consumer pair,
the contract, auth, data, version assumptions, owner and failure behavior.
*Idempotency* = calling the same operation twice must not double the business
effect (no duplicate confirmation email, no duplicate charge).

**Actions.** 1) Build the register (§21). 2) Test compatibility/failure cases:
schema change, mixed versions, expired credentials, timeouts, duplicate/out-of-
order events, partial transactions, retries, shared-package bumps. 3) Verify the
full journey on the exact version combination.

**Evidence.** Dated end-to-end run covering all components at pinned heads.
Source: integration/E2E pipeline logs.

**Acceptance criteria.** Each material integration has a demonstrated success
*and* a defined failure behavior.

**Failure or blockage.** With staging unprovisioned (VV-2026-10-009) the whole
provisioning journey is *UNDETERMINED* — the *Integration* and *Functionality*
gates cannot pass.

**Next action.** Provision isolated staging + synthetic data, then run the
clients-merge → provision → smoke → sync journey once.

## 9. Phase 8 — GitHub, CI/CD, and infrastructure

**Purpose.** Confirm the controls that protect *how code becomes production* are
real, not just written down.

**Plain-language.** *Documented policy* says a rule exists; *enforced configuration*
makes it impossible to break. They differ often. *SHA pinning* = locking a third-party
action to an exact immutable version. A *required status check* blocks merge until it
passes. *Separation of duties* = the person who writes code is not the only person who
can approve and ship it.

**Actions.** 1) Inspect membership, privileged access, branch protections/rulesets,
required reviews, required checks and bypass rights, automation identities, and
access-review records. 2) Inspect workflow permissions, secret exposure, untrusted
`pull_request_target` handling, third-party actions, runner isolation, artifact
provenance, environment approvals. 3) Confirm the green checks belong to the *release
candidate's* commit — a check on an older commit does not bless a newer artifact.
4) If AI agents/MCP exist, examine tool permissions, credential access, isolation and
untrusted-content handling; a prompt is **not** a permission boundary.

**Evidence.** Governance/pipeline findings with cited API observations (§19).
Source: org + repo settings, Actions runs.

**Acceptance criteria.** Policy and configuration agree; no unmanaged bypass.

**Failure or blockage.** A detection control (alerts turn red) that is not wired to
an enforcement gate (blocks merge/deploy) is advisory only.

**Next action.** Close the detection→enforcement gaps and the team-scope gap
(VV-2026-10-003, -004).

## 10. Phase 9 — Privacy and compliance readiness

**Purpose.** Establish what actually applies before claiming conformance, and keep
technical findings separate from legal determinations.

**Plain-language.** *Controller* decides why/how data is processed; *processor*
does it on the controller's behalf. *Lawful basis* is the legal permission to
process — consent is only one of six; do not assume consent for everything. An
*ISMS* (ISO 27001) is the organization's whole method for managing security risk;
a *Statement of Applicability* lists which controls it claims. A *SOC 2* report is
issued by an independent practitioner over an evidence *period* — an internal
review is not one.

**Actions (GDPR 14-point walk).** Controller/processor roles; purposes & bases;
transparency; minimization/by-design; retention & deletion; data-subject rights;
processor/sub-processor agreements (Art. 28); international transfers; security &
breach response (Art. 32/33); records of processing (Art. 30); DPIA need (Art. 35);
DPO need (Art. 37); special-category/children data (Art. 8/9); e-communications/
tracking rules. Record framework *editions and source dates*; never invent clause
numbers; disclose when the authoritative text was not re-verified.

**Evidence.** Control-to-evidence matrix (§20): requirement → boundary → owner →
expected evidence → observed evidence & date → gap → remediation.

**Acceptance criteria.** Each applicable control has observed evidence, not a plan.

**Failure or blockage.** An empty governance repository means Art. 28/30/DPIA
controls are *BLOCKED* — you cannot evidence a register that does not exist, and
the product already collects data (see §17/§22).

**Next action.** Populate the minimum corpus for what the pilot actually collects;
route the Art. 9 lawful-basis question to a person qualified to make a legal call.

## 11. Phase 10 — Operational resilience

**Purpose.** Show you can run and recover the service, not just deploy it.

**Plain-language.** *RPO* (recovery point objective) = the most data you accept
losing. *RTO* (recovery time objective) = the most time you accept being down.
A *successful backup job* proves data left the source; only a *restore test*
proves it can come back.

**Actions.** 1) Assess detect/investigate/respond: alert ownership, escalation,
logging, evidence preservation, response exercises. 2) Review backup scope,
protection, access, retention, and restoration *evidence*. 3) Evaluate deploy
sequencing, health checks, DB compatibility, rollback, and forward recovery —
irreversible changes need a real recovery plan, not an assumed rollback.
4) Assess capacity/performance against representative load; do not invent
universal thresholds.

**Evidence.** Recovery tests with before/after and dates (§21). Source: runbooks,
backup tooling, load tests.

**Acceptance criteria.** A dated restore test meets stated RPO/RTO.

**Failure or blockage.** No defined RPO/RTO and no application-data restore test =
*operations gate fail*, regardless of a tidy control-plane backup.

**Next action.** Write the runbooks, define RPO/RTO, test an app-data restore.

## 12. Phase 11 — Consolidate findings and remediation

**Purpose.** Turn observations into owned, verifiable work items.

**Plain-language.** *Severity* = how bad it is if real. *Confidence* = how sure we
the finding is real. *Priority* = when to fix. They are deliberately separate: a
high-impact suspicion with low confidence is still worth investigating but not
necessarily first.

**Actions.** 1) Give every finding the full record (§23 table): id, type
(confirmed/suspected/evidence-gap), affected repos+versions, criterion, expected
vs observed, evidence, how to reproduce, impact/likelihood/severity rationale,
root-cause status, plain-language remediation, owner, dependencies, target date,
acceptance criteria, independent verification method, release impact. 2) Apply the
severity model below. 3) Order remediation, grouping common root causes while
keeping every repo traceable.

**Severity model (criteria used here).**
- **Critical** — exploitable now with material data/permission impact, or a legal
  blocker; ship-stop.
- **High** — confirmed material control failure or easily-reachable risk; ship-stop
  under default policy.
- **Medium** — real gap with compensating controls or limited exposure; fix soon.
- **Low** — hygiene/consistency; fix in the normal cycle.
- **Informational** — no direct risk; recorded for completeness.

**Acceptance criteria.** No finding is "resolved" because a plan exists; resolution
needs independently verified evidence (§13).

**Next action.** Use the checklist in §27.

## 13. Phase 12 — Independently verify remediation

**Purpose.** Confirm fixes actually fixed the original defect and broke nothing.

**Plain-language.** Three separate states: *fix proposed* (a plan), *fix
implemented* (code merged), *fix independently verified* (a second party reproduced
the original test and it now passes, with no regression). Most audits fail by
collapsing these into one.

**Actions.** 1) Re-read the original finding and its acceptance criteria. 2) Pin the
corrected version. 3) Read the actual change. 4) Reproduce the original failure
where practical. 5) Check regression + security tests. 6) Check affected integrations.
7) Check for unauthorized side effects. 8) Record verifier identity, independence,
date, conclusion. 9) Reassess the final release artifact; if a material change
post-dates verification, decide which evidence must be refreshed.

**Evidence.** Verification register (§25): accepted / rejected / pending, per fix.

**Acceptance criteria.** Only a row signed by an *independent* verifier with a date
counts as closed.

**Failure or blockage.** Because this org is single-person (§15), independent
verification is *structurally pending* — self-acceptance must never be recorded as
independent closure.

**Next action.** Obtain a second human verifier or a documented compensating
control before any gate relies on a "verified" fix.

## 14. Phase 13 — Apply release gates

**Purpose.** Convert everything into a defensible yes/no/undecided, without moving
the goalposts to get a pass.

**Plain-language.** A *gate* is a must-pass condition. *GO WITH CONDITIONS* is only
legitimate when every *mandatory* gate passed and the conditions are permitted
residual risks with owners and expiry — it must never mask a failed mandatory gate.
Risk acceptance can accept a *business* risk; it cannot make a failed control pass,
and cannot override a legal obligation.

**Actions.** Define acceptance criteria *first* (§24 uses the ten gates of the
brief), then evaluate. State the auditor's *recommendation* and the approver's
*decision* separately; the audit must not itself trigger deployment.

**Evidence.** The gate table with per-gate basis links (§24).

**Decision categories.** GO / GO WITH CONDITIONS / NO-GO / UNDETERMINED.

**Next action.** The named approver records the decision with residual risks (§27).

---

# PART II — FINDINGS & EVIDENCE

## 15. Charter, responsibilities, independence (Phase 1 result)

| Responsibility | Incumbent at reference date | Status |
| --- | --- | --- |
| Audit scope & coordination | `JourneyOfLife` — sole human org member, owner role | VERIFIED (E11) |
| Security & privacy decisions, remediation, risk acceptance, release approval | Same single person | VERIFIED — and itself finding VV-2026-10-003 |
| Independent verification | None identified (see VV-2026-10-006) | **UNASSIGNED** |
| External assurance (SOC 2 Type II / ISO 27001 certification) | No QSA/auditor engaged | PENDING |

**Independence statement.** The reviewer is an AI audit lead operating with tooling
and evidence partly produced by the owner under assessment. A second AI pass adds
perspective but does **not** establish organizational independence. Every
"independent verification" requirement is recorded **PENDING**, not satisfied.

**Execution boundary.** Authorized inspection only: read-only GitHub API sweeps,
working-copy inspection, and read-only `terraform plan`. This document is the sole
artifact, created and revised at the owner's explicit request; no code, config,
permission or live resource was modified by the audit.

**Access limitations (each blocks a named conclusion):**

| Limitation | Conclusion it blocks |
| --- | --- |
| Token lacks `admin:org_hook` scope | Org webhook inventory — unknown, not assumed empty |
| GitHub Free plan: private-repo ruleset / advanced-security reads return HTTP 403; branch protection requires Team+ | Protection posture of the 5 private repos — BLOCKED |

> **Corrections to earlier draft (2026-10-26):** two rows previously listed here
> as access blocks — "Dependabot severity unreadable" and "code-scanning sweep
> wrong endpoint" — were **the auditor's own query bugs, not access limits.** With
> the correct fields the severities are fully readable; see §28 and E15. The
> *Security* gate is therefore decided on evidence, not left undecided.

## 16. Inventory reconciliation and coverage matrix (Phase 2 result)

| Plane | Count | Evidence |
| --- | --- | --- |
| Live (org API, paginated, incl. private) | **31** | E1 |
| Declared (`repos_data.tf`) | **31** | E2 |
| Live-not-declared / declared-not-live | **0 / 0** — no shadow repos, no ghosts | E1+E2 |
| In state | 31 `github_repository`, 21 `github_branch_protection`, 1 `github_repository_ruleset`, 26 dependabot-update, org resources; serial **143**, Terraform 1.16.1 | E3 |
| Local working copies (`/opt/viavitae/repos`) | 30 org clones + `viavitae-control`; September's three non-org strays gone; heads clean & matching live for web/api/clients | E4 |
| Org membership | 1 human (`JourneyOfLife`); 6 teams each bound to 30 repos (fresh-verified); 0 readable outside collaborators | E11, E16 |
| Count history | 30 (2026-09-27) → 31 now; growth from landing-class/template additions | E1 |

| # | Repository | Vis | Content | Head @2026-10-26 | Tier | Deep-audit status | Dependabot (crit/high) |
| --- | --- | --- | --- | --- | --- | --- | --- |
| 1 | .github | pub | 16 | 49cba333 | meta | ASSESSED — org reusable CI/CodeQL/compliance workflows + CODEOWNERS/SECURITY (E17); CI green | 0/0 |
| 2 | viavitae-control | pub | 73 | 7c9a1980 | control | ASSESSED (this doc) | 0/0 |
| 3 | viavitae-compliance | **priv** | **skeleton only** — `docs/security/` directories, 0 files (E28) | — | control | BLOCKED (no files + 403) | n/a |
| 4 | viavitae-data-governance | **priv** | **EMPTY** | — | control | BLOCKED | n/a |
| 5 | viavitae-policies | **priv** | **EMPTY** | — | control | BLOCKED | n/a |
| 6 | viavitae-threat-model | **priv** | **EMPTY** | — | control | BLOCKED | n/a |
| 7 | viavitae-vendor-register | **priv** | **EMPTY** | — | control | BLOCKED | n/a |
| 8 | viavitae-training | pub | **EMPTY** | — | control | EMPTY — confirmed 0 blobs; nothing to audit (ISO A.6.3 training-records gap) | 0/0 |
| 9 | viavitae-docs | pub | 181 | db67d1c3 | control | ASSESSED — public Hugo site; pentest/ROPA/ADRs as **empty stubs**; `noindex=false` + `Publish` green (VV-…-012) | **2/3** |
| 10 | viavitae-infra | pub | 263 | a4145b54 | platform | ASSESSED — prod placeholders (E7) | 0/0 |
| 11 | viavitae-observability | pub | **EMPTY** | — | platform | emptiness **is** the finding | 0/0 |
| 12 | viavitae-runbooks | pub | **EMPTY** | — | platform | same | 0/0 |
| 13 | viavitae-reusable-workflows | pub | **EMPTY** | — | platform | same | 0/0 |
| 14 | viavitae-template | pub | 18 | 9b18a736 | platform | CLASS-VERIFIED (parent of landings, E9) | 0/0 |
| 15 | viavitae-qa | pub | 118 | 2d670ecc | platform | ASSESSED — full harness (e2e/load/a11y/contract); **contract specs are placeholders** (VV-…-011); CI green | 0/5 |
| 16 | viavitae-api | pub | 156 | 63cb4943 | app | ASSESSED (deploy red) | **0/0** (was 7/23; cleared by PR #10 on 2026-10-27 — 1 medium alert remains. E34) |
| 17 | viavitae-clients | pub | 86 | 3a9db5f8 | app | ASSESSED — tenant registry + validate/provision/diff-guard workflows; CI green | 0/0 |
| 18 | viavitae-web | pub | 195 | ca465637 | app | ASSESSED | **5/9** |
| 19 | viavitae-brand | pub | 63 | f1555f9d | app | ASSESSED — design assets/tokens; no test suite; CI green but 5 crit/23 high deps | **5/23** |
| 20 | viavitae-demos | pub | 228 | 1ec6e2fd | app | ASSESSED — **real landing templates live here** (135 files), not in landing repos; `.npmrc`/`.env.example` clean; CI green | 0/0 |
| 21 | viavitae-hermes-agents | pub | 72 | 0e35dccd | app | ASSESSED — RAG agents with **fail-closed boundary tests** + gitleaks; CI green (positive) | 0/0 |
| 22 | viavitae-landing-basilica | pub | 19 | 392760d3 | site | CLASS-ASSESSED — scaffold (§7) | 0/0 |
| 23 | viavitae-landing-cathedral | pub | 19 | 526dc9cc | site | CLASS-ASSESSED | 0/0 |
| 24 | viavitae-landing-cemetery-services | pub | 19 | 85a65368 | site | CLASS-ASSESSED | 0/0 |
| 25 | viavitae-landing-churches-orthodox | pub | 19 | 030cc2d6 | site | CLASS-ASSESSED | 0/0 |
| 26 | viavitae-landing-churches-other | pub | 19 | c25fed9d | site | CLASS-ASSESSED | 0/0 |
| 27 | viavitae-landing-churches-protestant | pub | 19 | 4d785908 | site | CLASS-ASSESSED | 0/0 |
| 28 | viavitae-landing-deaneries | pub | 19 | 04e8c1ce | site | CLASS-ASSESSED | 0/0 |
| 29 | viavitae-landing-diocese | pub | 19 | ba861678 | site | CLASS-ASSESSED + inspected (E9) | 0/0 |
| 30 | viavitae-landing-funeral-services | pub | 19 | 9917bd39 | site | CLASS-ASSESSED | 0/0 |
| 31 | viavitae-landing-parish-church | pub | 19 | 1e2a7dc2 | site | CLASS-ASSESSED | 0/0 |

Exactly ten repos match `viavitae-landing-*` — all listed. Dependabot totals:
**20 critical / 63 high** open across the estate (E15), concentrated in the
release candidates. **Re-measured 2026-10-27 (E33): 19 critical / 62 high / 61 medium /
8 low** by paging `repos/<r>/dependabot/alerts?state=open` over all 31 repos and
grouping by `security_advisory.severity` — one critical and one high fewer than the
reference-date figures, i.e. alert counts drift and must carry a date and an instrument. Code-scanning open alerts (E15): api 1, web 1, demos 1,
clients/brand/qa 0.

## 17. Architecture and data flows (Phase 3 result)

**What Via-Vitae actually is** (from repository evidence, not its name): a
commercial IT company operating an EU pilot **in Lithuania** — church-vertical
websites, e-commerce and a marketplace, self-hosted on **Proxmox** with **k3s +
Argo CD (GitOps)**; personal data claimed to stay in the EEA. (E5, E6)

Verified components: **viavitae-api** (FastAPI/Python 3.12; Bitrix24 on-prem CRM;
**Stripe + Paysera** payment webhooks; a **RAG pastoral AI assistant**; GIS
cemetery mapping; donations). **Corrected 2026-10-27:** this line first read
"multi-tenant Postgres with per-tenant schemas + row-level security; Alembic".
That is the **design** (ADR-004 / `docs/data-model.md`), not the state of the
code: `app/db/migrations/versions/` holds only `.gitkeep` — **zero Alembic
revisions exist** — and `Dockerfile` never runs `alembic upgrade head`, so the
image starts against an empty schema (VV-2026-10-016).

Other verified components: **viavitae-web** (Next.js 15/React 19, next-intl
LT/EN/RU, OpenAPI typed contracts, Keycloak identity config, self-hosted Matomo,
cookie/legal pages, Zod-validated server-side quote proxy). **viavitae-clients**
(per-client tenant registry as the audit trail). **viavitae-infra** (Ansible 96,
Terraform 65, k8s 31 incl. default-deny + cross-tenant-deny network policies,
monitoring 10, backup 9; SOPS+age with **only public recipient keys committed** —
private-key exclusion verified in `.gitignore`). (E5–E8)

**Critical journey (unverified end-to-end — see VV-2026-10-009):** clients PR →
CI + review → merge `main` → `provision-dispatch.yml` → `POST /v1/tenants/<slug>/
provision` on the API → staging deploy → Playwright smoke (`viavitae-qa`) →
production sync via Argo CD → regenerated manifests/lockfiles. (E6)

**Trust boundaries:** browser → Next.js middleware (CSP present) → API →
tenant-isolated Postgres; web → Bitrix24/Stripe/Paysera (third parties, payment
data); CI → container registry (build-to-production — currently broken,
VV-2026-10-001); Terraform control plane → GitHub org (admin writes).

**Data-flow / privacy-by-design note:** the quote and assessment funnels collect
contact name, organization name and **email**, with **server-enforced consent**
(`consent_privacy: true`) and a **stored consent-notice version** citing DPIA-001
R7 — a mature GDPR Art. 25 pattern whose governing DPIA lives in a **still-empty**
repo (Art. 30 gap). Payment card data routes to Stripe/Paysera (Art. 28 agreements
unevidenced). Pastoral/assessment content **may be Art. 9 special-category
(religious) data**; lawful basis is UNDETERMINABLE with no DPIA. **Corrected
2026-10-27 — the sentence this replaced ("the webhook integrity controls are
real: Stripe `construct_event` signature check, Paysera `ss2` HMAC fail-closed,
a `webhook_event` idempotency ledger") was false.** The `viavitae-api` webhook
handlers are **fail-closed stubs, not implemented controls**: Stripe, Paysera
and Bitrix24 each check only that a signature/token is *present* and that a
secret is *configured*, then raise `501 not_implemented` behind a `# TODO(api)`
block. No signature is ever verified, no `webhook_event` ledger exists (the ORM
file is a TODO comment with no model and no migration) and the `stripe` SDK is
not a declared dependency (E19 corrected, VV-…-011 re-scoped, VV-…-014). The
**RAG/agent boundary** is enforced by a
fail-closed `BoundarySettings` requiring a separate KMS key + vault ref + audit
stream (E20). The webhook residual gap is therefore **an unimplemented
money path plus documentation that asserts it exists** — not, as first written,
"test quality only".

## 18. Baseline and test-evidence register (Phase 4 result)

| Repo @head | Build/tests defined? | Observed result this pass | Status |
| --- | --- | --- | --- |
| viavitae-web @ca465637 | Yes — lint, typecheck, unit+contract, e2e, a11y, lighthouse | Scheduled CI on `main` green 2026-10-26; one Dependabot PR `Lint` red 2026-10-26T04:19Z | VERIFIED PASS (main), VERIFIED FAIL (open PR #51 lint) |
| viavitae-api @63cb4943 | Yes — pytest, nightly E2E | Nightly E2E green 2026-10-26; **`Deploy` push run red** (E12). **Clarified 2026-10-27:** the "E2E" job is `deployments/k6/smoke.js` against `docker compose up postgres redis api` and asserts only health/version plus that scaffolded endpoints answer **501** with the right error envelope (`checks: rate>0.99`, `p(95)<800`). It is honest about the scaffold — but it is **not** a business journey and cannot be, because no migration creates any table (VV-…-016) | Mixed: tests PASS, deploy FAIL; E2E label overstates scope (VV-…-016) |
| viavitae-clients @3a9db5f8 | Yes — CI + provision-dispatch | CI green; dispatch journey never observed end-to-end | Tests PASS, integration UNDETERMINED |
| viavitae-qa @2d670ecc | Yes — Playwright @smoke, axe, Trivy, load | Unit/contract/lint CI green on `main` 2026-10-26; browser/load still gated on unprovisioned staging (P1-22) | CI PASS (unit/contract), BLOCKED (browser/load env) |
| .github, docs, brand, demos, hermes-agents, clients @heads in §16 | Yes — CI/CodeQL/Compliance; hermes adds gitleaks | All have a **green `main` push run** 2026-10-26; docs also `Publish docs site` green | VERIFIED PASS (build/CI) per repo (E17) |
| viavitae-api @63cb4943 (webhooks) | Yes — `tests/webhooks/test_stripe_idempotency.py` | Input-guard rejection (400 / 503) asserted & green. **Corrected 2026-10-27:** the 501 stub branch had *no* test at all — replacing the `raise ApiError(501)` with `return {"status": "received"}` still passed 9/9, because every request died earlier at the 503 "secret unconfigured" guard; **idempotent-replay test is `pytest.skip(TODO)`** | VERIFIED PASS (input guards only) / **NOT RUN → now covered by a pin test** (signature verification, processing, idempotency) (E19 corrected, VV-…-014) |

Blocked/unexecuted checks register now: browser/load E2E (staging), the skipped
idempotent-replay assertion, and the trivial-pass qa contract specs — plus
per-repo deep dives for the 5 empty private repos (access-BLOCKED). The 15 earlier
"NOT RUN deep dives" have been executed; empties remain unevaluable.

## 19. GitHub, CI/CD and infrastructure assessment (Phase 8 result)

**VERIFIED PASS (observed 2026-10-26):**
- Org-wide 2FA enforced (`two_factor_requirement_enabled: true`). (E11)
- All 26 public repos: secret scanning + push protection enabled. (E10)
- 21 branches carry classic branch protection with **strict** up-to-date
  enforcement and **admin enforcement**; no force pushes; `viavitae-control`
  protected by the `protect-main` ruleset. (E10)
- Org Actions restricted to a selected allow-list; provenance gate wired
  (`ai:<tier>` trailer enforced by a commit-msg hook + `provenance.yml`). (E11)
- `main` CI health: **all 22 populated repos have a green `main` push run**
  2026-10-26 (web/clients/qa/.github/docs/brand/demos/hermes-agents confirmed, E17);
  control-plane `Audit` + `provenance` green since 2026-10-21. (E12)
  **Corrected 2026-10-27 (E27, VV-…-017): this is weaker than it reads.** For 14 repos
  (`api`, `brand`, `infra`, `template`, all ten `landing-*`) the green `CI status` is
  produced while the `Lint` / `Typecheck` / `Test` / `Build` legs are `skipped` with an
  empty matrix, so those runs never demonstrated unit tests, type checks or the
  coverage floor. What stays verified for those repos is `Compliance status`
  (gitleaks / licence / action-pinning / governance), Semgrep SAST, Trivy dependency
  scan and CodeQL — all of which run outside the broken matrix.
- September's protections-downgrade danger closed: apply landed 2026-10-17; state
  now matches declared protections (E3).

**Finds on this layer:**
- **Team bindings are blanket, not tier-scoped** — each of the 6 teams
  (architects/compliance/dpo/legal/platform/security) is attached to **30 repos**
  (fresh-verified, E16), so tier-based CODEOWNERS cannot segregate duties
  (VV-2026-10-003).
- Org-level SHA pinning is **off** while repos rely on a per-repo check
  (VV-2026-10-007).
- **Private-repo blind spot:** the 5 private repos return HTTP 403 for
  ruleset/advanced-security reads on Free and show no readable branch protection
  — meaning confidential compliance repos will exist **unprotected** once populated
  (VV-2026-10-002 / -010).
- Webhook inventory unobtainable (no `admin:org_hook` scope) — NOT RUN (re-confirmed
  2026-10-26: 404 + "needs admin:org_hook", E18). Org Actions allow-list floats **7
  patterns to mutable `@*`** (checkout/setup-node/setup-python/cache/upload+download-artifact/setup-terraform)
  while sha-pinning is off, incl. an unused `hashicorp/setup-terraform@*` (VV-…-013).

## 20. Privacy & compliance readiness matrix (Phase 9 result)

**Applicability:** GDPR applies (EU/Lithuanian establishment, EEA data subjects);
Lithuanian e-communications rules apply to analytics consent (NOT RUN). ISO/IEC
27001:2022 and SOC 2 (2017 TSC) are *assurance objectives*, not attested states —
no certification or report exists, and this internal review is not one.

| Requirement (plain language) | Framework ref | Owner | Expected evidence | Observed @2026-10-26 | Status |
| --- | --- | --- | --- | --- | --- |
| Record why/how each data type is processed | GDPR Art. 30 | DPO | ROPA document | `data-governance` empty | **BLOCKED** |
| Impact assessment for high-risk processing | GDPR Art. 35 | DPO | DPIA (incl. Art. 9 basis) | DPIA-001 cited in code, doc absent | **BLOCKED** |
| Written terms with every processor | GDPR Art. 28 | Legal/DPO | Vendor/sub-processor register | `vendor-register` empty (Stripe/Paysera/Bitrix24 unlisted) | **BLOCKED** |
| Lawful basis for religious/pastoral data | GDPR Art. 9 | DPO + legal | DPIA basis section | none | UNDETERMINED — legal call needed |
| Data minimisation of the org's own telemetry | GDPR Art. 5 | Infra | billing/contact address handling | plus-address + no-default-var pattern evidenced (../COMPLIANCE.md P1-7/P1-12) | VERIFIED PASS (partial) |
| ISMS scope, risk assessment, SOA, policies | ISO 27001 cl. 4–6, 13, App. A | Security | policy library, risk register, SoA | `policies`/`compliance`/`threat-model` empty; stubs in docs | **BLOCKED** |
| Confidential compliance/security corpus kept non-public | GDPR Art. 5(1)(f) / ISO A.8 | DPO/Security | pentest/ROPA/DPIA in the **private** repos, not published | `viavitae-docs` is **public + `noindex=false`** and hosts pentest findings + ROPA/ADRs as **currently-empty stubs**, with a green `Publish` job | **FAIL on population** (VV-…-012); `netlify.toml` EU-self-host guard is a positive (E20) |
| Access control & segregation of duties | ISO A.5.15–5.18 / SOC2 CC6 | Owner | role-scoped permissions | blanket team push; 2FA on | PARTIAL (VV-…-003) |
| Change control & release evidence | SOC2 CC8 | Platform | gated PRs + branch protection | PR workflow + 2 required contexts enforced on public repos, **but 0 approving reviews and the provenance gate exists in only 1 of 31 repos (E21, VV-…-015)** | **PARTIAL** (was "VERIFIED PASS (public only)"; corrected 2026-10-27) |
| Security monitoring & incident response | ISO A.8.16 / SOC2 CC7 | Ops | runbooks, alerting, IR plan | `runbooks`/`observability` empty | **BLOCKED** |
| SOC 2 operating effectiveness over a period | SOC2 all TSC | QSA (external) | Type II window evidence | none engaged | PENDING — out of this audit |

Technical findings are separated from legal determinations; the Art. 9 basis row is
explicitly a legal question, not an engineering one.

## 21. Integration register and operational resilience (Phases 7 & 10 result)

**Integration register** (provider → consumer; contract / auth / data / failure
behavior / status). End-to-end success is **NOT RUN** on all rows because staging
is unprovisioned (VV-2026-10-009):

| Provider → consumer | Contract | Auth | Data | Failure behavior | Status |
| --- | --- | --- | --- | --- | --- |
| web → api | OpenAPI typed (`generated/`) | `API_SERVICE_TOKEN` | quote/assessment (email, org) | undefined in audit | NOT RUN |
| clients → api | `provision-dispatch.yml` → `POST /v1/tenants/<slug>/provision` | dispatch token | tenant config | idempotency unverified (no ledger exists — see VV-…-014) | NOT RUN (UNDETERMINED) |
| api → Stripe / Paysera / Bitrix24 | payment/CRM webhooks | **Not implemented** (corrected 2026-10-27): handlers are `501` stubs; only presence-of-signature and secret-configured are checked; no ledger; `stripe` SDK absent from dependencies | payment events | every event refused (fail-closed), so no payment or CRM change can ever be applied — the provider keeps retrying forever | **VERIFIED FAIL (integration absent)**; the prior cell "VERIFIED PASS (sig reject)" is **retracted** (VV-…-011 re-scoped, -014, E19) |
| api → Bitrix24 (on-prem CRM) | REST | creds | CRM records | creds expiry path unknown | NOT RUN |
| api → Postgres | per-tenant schema + RLS (**design only** — zero Alembic revisions, so no tables/policies exist, VV-…-016) | service creds | would hold all tenant PII | cross-tenant isolation cannot be tested because there is no schema; `tests/isolation/*` are skipped TODOs | **VERIFIED FAIL (layer absent)**, was "NOT RUN" (E24) |
| CI → container registry | Docker build/push | CI token | image artifact | **build-to-production currently RED** | **VERIFIED FAIL** (VV-…-001) |
| Terraform control plane → GitHub org | provider 6.x | GITHUB_TOKEN | repo/policy config | applied 2026-10-17, works | VERIFIED PASS |

**Operational resilience result:** control-plane state+vault backup is real,
air-gapped and hash-verified with monthly A↔B rotation (E13). Application-data
backup: scripts exist in `viavitae-infra/backup` but no dated restore test —
NOT RUN. **RPO/RTO: none defined** anywhere (runbooks empty). Incident response,
escalation, capacity/performance testing: NOT RUN. Deployment & rollback: pipeline
red; Argo CD sync untested. **Operations gate: VERIFIED FAIL.**

## 22. Landing assessment and per-repo deep-audit gaps (Phase 6 result)

**Landing class (all ten, one class — §7 method):** two commits each (template
scaffold + a `.gitignore` fix); `main.py` is the PyCharm placeholder
(`print_hi('PyCharm')`); 19 files; no content, forms, analytics config, domains or
deploy targets; README inherited from the template with live CI/CodeQL/Compliance
badges (the workflows exist, so badges are honest *about the scaffold*). **Feature
completeness VERIFIED FAIL (class-level); security/privacy NOT APPLICABLE —
justified** (deploys nothing), conditional on verified exclusion (`has_pages=false`
on the sample, inferred for the nine identical — inference flagged);
**integration/operational NOT RUN**. **Hazard: green gates over empty scaffolds are
a false-readiness signal.** Decision owner: release manager (VV-2026-10-005).

**Deep-audit status (updated 2026-10-26 session 2):** the 8 populated public deferred
repos — `.github, docs, brand, demos, hermes-agents, qa, clients, template` — are now
**deep-audited** (all green `main` builds; results in §16–§21). Remaining honest
non-coverage: the **5 private repos** (empty + Free-plan 403 → BLOCKED) and the
**4 public empties** (`runbooks/observability/reusable-workflows/training`, nothing
to audit). **New insight:** the real per-vertical landing content lives in
`viavitae-demos/templates` (135 files), not in the `viavitae-landing-*` scaffolds —
feeds the VV-…-005 inclusion decision.

## 23. Findings register (Phase 11 result)

Severity, confidence and priority are tracked separately.

| ID | Title | Class | Severity / Confidence | Owner | Remediation (plain language) & acceptance |
| --- | --- | --- | --- | --- | --- |
| VV-2026-10-001 | Production deploy path non-functional; all prod k8s manifests are `placeholder.yaml`. **Root cause now named (read from the failing run 40558832572 on api main, E35): `ERROR: failed to build: failed to solve: failed to push ghcr.io/via-vitae/viavitae-api:main: denied: installation not allowed to Create organization package`.** Every preceding step succeeded (checkout, QEMU, Buildx, **Login to GHCR**, metadata); only `Build and push` fails, so the staging and production jobs are skipped, not broken | Confirmed, root-caused | **High** / High | Infra owner | Two candidate causes, to be separated by test rather than assumption: (1) `.github/workflows/deploy.yml` declares `permissions: { contents: read, id-token: write }` with **no `packages: write`**, so the `GITHUB_TOKEN` cannot create the package — a one-line repo fix; (2) an org-level restriction on the Actions app publishing packages into the `Via-Vitae` namespace, which is an org-settings change only the owner can make (I do not touch org settings). Sequence: apply (1) in an isolated PR, then re-run the workflow; if the same denial persists, the cause is (2). Then replace every `prod/**/placeholder.yaml` with real reviewed Argo CD manifests; acceptance = successful prod-candidate deploy of the exact release commit through dev→staging→prod with recorded run links, plus an independent re-run |
| VV-2026-10-002 | Compliance & operations artifact repos empty while product code cites them (DPIA-001 et al.) | Confirmed | **High** (compliance blocker; not exploitable) / High | DPO/compliance role (same human today) | Populate ROPA, DPIA (incl. Art. 9 basis), retention schedule, policy library, vendor register with Art. 28 terms, runbooks, training records; acceptance = every cited ID resolves to a real document; decide the Free-plan protection limitation for the private repos (upgrade, or accept the unprotected-population risk explicitly). |
| VV-2026-10-003 | Single-person org: owner = implementer = approver; all six teams hold blanket push on all 30 repos (no tier scoping, so tier-based CODEOWNERS cannot segregate) | Confirmed governance gap | **High** for SOC 2 CC-series / High (fresh-verified E16) | Owner | Establish the largest feasible separation of duties (active peer-reviewer account, or documented compensating controls + independent-assurance engagement); scope team bindings to tiers; acceptance = team permissions match tier policy and the review chain is demonstrably enforced. |
| VV-2026-10-004 | **20 critical + 63 high** open Dependabot alerts on default branches, concentrated in release candidates (api 8/23, brand 5/23, web 5/9, docs 2/3, qa 0/5 — E15). GitHub alerts are *detected* (Dependabot updates on) but **no required status check blocks merge/deploy on critical**, so detection is not enforced | Confirmed, **severity-ranked**; **partly disproved for `viavitae-api` on 2026-10-27 (see the correction cell)** | **High** / High | Per-repo owners | Triage by reachability on `main`; remediate criticals on api/web/clients/brand before release; add a Dependabot-critical gate (fail CI when `main` carries critical/high on reachable deps) wired into the ruleset so detection becomes enforcement; acceptance = fresh zero-critical snapshot dated against the release commit + a green blocking check. **Correction (2026-10-27, E26): for `viavitae-api` this claim is wrong in the org's favour — enforcement exists.** Trivy runs with `severity: CRITICAL` and exit-code 1, `CI status` records `"dependency-scan": {"result": "failure"}`, and `CI status` is a required context, so a PR genuinely cannot merge: PR #9 is blocked today by **8 pre-existing** criticals while its own diff touches no dependency file. Two consequences the owner must decide on: (a) all 7 alerts have published fixes (pillow to 13.0.0 ×5, brotli to 1.2.1, brotlicffi to 1.2.1.0, all resolved in `uv.lock`), as does the 8th, Trivy-only certifi finding, **yet zero Dependabot PRs are open**, so the bumps must be authored by hand; (b) the gate has therefore **merge-locked the repo** — nothing has merged into `viavitae-api` since 2026-10-15 (PR #4), which is precisely the freeze the org deliberately avoided elsewhere by not requiring `CI status` while Trivy was red. Clearing the criticals is now the prerequisite for every other api remediation, including VV-…-011 and -014. **Landed 2026-10-27:** merged as `viavitae-api#10` → main `80cdb766`, then PR #9 rebased onto it and merged → main `9b204f48` where **CI, Compliance check and CodeQL all pass** (the red `Deploy — viavitae-api` run on the same head is the pre-existing VV-…-001 failure, unrelated to dependencies). Measured effect on the estate: api's open alerts fell from 7 critical / 23 high / 14 medium to **1 medium**, and org-wide totals moved 19→**12** critical and 62→**39** high — exactly api's 7 and 23, so the arithmetic closes (E34). Dependabot has since opened its own update runs (pillow, brotli, brotlicffi, mako) against the new baseline |
| VV-2026-10-005 | Ten landing repos are scaffolds; release inclusion undecided | Confirmed + decision request | **Medium** / High | Owner | Decide exclude-vs-include per landing page. Exclusion must be evidenced (no deploy target, no domain, no indexing); inclusion requires content, privacy notice, form destination, consent behavior and accessibility verification. |
| VV-2026-10-006 | Sole reviewer `IterVitae` recorded "inactive, admin invite pending" yet absent from live outside-collaborators | Evidence gap / suspected access anomaly | **Medium** / Low — needs confirmation | Owner | Produce the access-review record: current role, membership, review capability of that account; acceptance = API-visible membership matching documented policy. |
| VV-2026-10-007 | Org-level SHA pinning disabled (`sha_pinning_required=false`) while repos rely on a per-repo "Action SHA pinning" check | Confirmed policy/config mismatch | Medium / High | Platform owner | Either require pinning at the org ruleset or formally document the per-repo gate as the compensating control; acceptance = configuration and policy agree. |
| VV-2026-10-008 | Applied-input custody unverifiable: fresh plan aborts on missing required `billing_email`; the tfvars used for the 2026-10-17 apply is not in this workspace and its storage location is not evidenced | Confirmed, **scoped down after cross-check** | Low–Medium / High | Infra owner | The abort is **by design and documented** (../COMPLIANCE.md P1-12: `TF_VAR_billing_email` has no default for GDPR minimisation) — the residual gap is *custody*: record where the applied value lives and how it is protected/restored; acceptance = the custody path is exercised once and a clean-checkout plan procedure is reproduced. |
| VV-2026-10-009 | QA browser/load gates cannot run — staging tenant not provisioned (register P1-22, still open) | Confirmed | **High** for integration gate / High | QA owner | Provision isolated staging + synthetic data; run the full cross-repo journey (clients merge → provision → staging smoke → sync); acceptance = dated E2E evidence covering the exact release version combination. |
| VV-2026-10-010 | Org webhook inventory and private-repo protections unobtainable | BLOCKED (re-confirmed) | — | Owner | Grant scoped read (`admin:org_hook`) and/or GitHub Team for private-repo visibility; re-run the blocked cells of §15/§19. |
| VV-2026-10-011 | **(re-scoped 2026-10-27 — the original wording was disproved by reading the handlers)** Money-path webhook processing is **unimplemented**: Stripe/Paysera/Bitrix24 handlers raise `501 not_implemented`, no signature verification exists, no `webhook_event` ledger model or migration exists, and `stripe` is not a declared dependency. On top of that, `test_replayed_event_is_idempotent` is `pytest.skip(TODO)` and qa `contract/stripe/webhook-contract.spec.ts` is a trivial `assert.ok(true)` that reports green. The original text ("the signature-verification control itself is real and fail-closed-tested — a test-quality gap, not a missing control") asserted a control that is not in the code | Confirmed | **High** (payments cannot function; release-blocking) / High | API + QA owners | Implement, in this order: signature verification (constant-time / provider SDK) → `webhook_event` ledger model + migration with RLS → async processing → re-read amounts from the provider API. Then replace the skipped test with the positive 200-once replay assertion and rewrite the placeholder contract spec so it fails if the guard is removed. Acceptance = payments path functional end-to-end on staging, a non-skipped test proven to go red under mutation, independent run. |
| VV-2026-10-012 | `viavitae-docs` is **public and indexable** (`noindex=false`, green `Publish` job) yet hosts the pentest findings-register, ROPA/DPIA and security ADRs as currently-**empty stubs** with only a non-enforced `sensitivity:` front-matter | Confirmed (latent) | **High on population** / High | DPO/Security | Move the confidential corpus into the private repos (or gate the published site); make `sensitivity` an enforced build filter, not metadata; acceptance = published site carries no internal-artifact content and a CI check fails the build if it does |
| VV-2026-10-013 | Org Actions allow-list floats **7 patterns to mutable `@*`** with `sha_pinning_required=false`, incl. an unused `hashicorp/setup-terraform@*` (attack surface for a feature no workflow uses) | Confirmed | **Medium** / High | Platform owner | Pin used actions to commit SHAs (two pinned pnpm SHAs already prove it works), drop the unused setup-terraform pattern, enable org sha-pinning; acceptance = no `@*` for third-party/privileged actions and pinning enforced |
| VV-2026-10-014 | **False assurance about an unimplemented control, spanning 14 files / 28 claim-rewording diff hunks.** Size measured reproducibly, not asserted: `git diff --unified=0` on the fix branch reports **39 hunks** in 14 files, of which 5 are the generated `docs/api/v1-openapi.json` and 6 the new test file (E21, E25). At `viavitae-api @63cb4943` the three webhook module docstrings ("signature verified, idempotent on event id (ADR-005)"), their three route docstrings ("Receive, verify and acknowledge …"), `app/models/webhook_event.py` ("Stores every verified provider event …"), `docs/data-model.md` ("Two tables back the idempotency surface … a replayed delivery returns the stored result"), `docs/runbooks/webhook-replay.md` ("All webhook handlers are idempotent … a replay never double-applies a payment"), `docs/runbooks/bitrix24-outage-mode.md` ("All CRM writes are idempotent"), `scripts/replay_webhook.py`, `docs/architecture.md` ADR-005 ("Status: accepted" with no implementation line), `app/api/v1/gis.py` (the **user-visible** OpenAPI summary "Reserve a parcel (idempotent)", which propagates into the committed `docs/api/v1-openapi.json`) and `QODER.md` ("idempotent payment/CRM webhooks") all describe **design intent as present behavior**, while every handler returns `501`. `QODER.md` is the **agent-instruction file**, and is the mechanism by which this report inherited the false claim. **Privacy dimension (found on re-review, second draft of this finding):** `docs/DPIA-004-donations.md` listed the unimplemented ledger as an in-place mitigation (M2), rated R2 residual risk **Low** because of it, stated idempotency was "already in place", and concluded **Art. 36 prior consultation is not required** because "measures reduce residual risk to low for all identified risks" — a legal conclusion resting on a control that does not exist (GDPR Art. 35(7)(d)). Operational harm: an operator following the runbook would believe a replay is safe to repeat; a reviewer reading a docstring would believe the money path is guarded; a DPO reading the DPIA would believe R2 is mitigated | Confirmed | **High** (evidence/governance integrity; misleads operators, reviewers, this report and a DPIA) / High | API owner + audit lead + DPO | (1) Reword every claim as target design, never as behavior, while the stub stands; (2) add a pin test that reaches the 501 branch (not the 503 guard) and proves itself by mutation; (3) convert the invisible `pytest.skip` on the design contract into `xfail(strict=True)` so it self-flags as XPASS when the path is implemented; (4) annotate **every** DPIA measure row (M1–M4, not just M2 — see §28 item 11) against what the code actually does and mark the Art. 36 conclusion for DPO re-assessment without inventing a new risk rating; (5) correct this report and the stored working note. Acceptance = no unqualified "verified / idempotent / already in place" claim survives while the code returns 501.  **Status: MERGED, INDEPENDENT VERIFICATION STILL PENDING** — landed 2026-10-27 as `viavitae-api` **9b204f48** (PR #9, all required checks green on head `d3255de8`) and `viavitae-control` **0375f16d** (PR #42, `provenance` + `audit` pass). The agent performed the merges on the owner's explicit instruction, so author, approver and merger were the same session plus one person: **no independent reviewer has inspected the diff** and this row must not be read as closed (see §25). Caveat found while verifying the merge: on `viavitae-api` the `Lint`/`Typecheck`/`Test` legs are still `skipping` (VV-…-017 is fixed in the template only, not yet propagated), so the new pin test is **locally** proven by mutation but **not yet executed by CI**. Considered and deliberately **not** changed: `app/api/deps.py:52` ("Extract the client idempotency key" — literally true, it does extract a header) and `docs/api/versioning-policy.md:12` (a normative contract table, and the GIS schema does enforce `min_length=8`) |
| VV-2026-10-015 | **AI-workflow provenance is enforced in 1 of 31 repos — including not in the repos where AI agents actually write code.** `policies/AI_WORKFLOW_POLICY.md` requires every AI-authored commit to carry an `ai:<tier>` trailer, gated by `scripts/check_commit_provenance.sh` (local) and `.github/workflows/provenance.yml` (server). A per-repo file-existence sweep over all 31 repos (E21) finds `provenance.yml` in **exactly one** repo (`viavitae-control`) and `.pre-commit-config.yaml` in **two** (`viavitae-control`, `viavitae-hermes-agents`); `viavitae-api` has none of these, its `.git/hooks` carries no `commit-msg`, and its two required contexts are only `CI status` + `Compliance status` (`variables.tf:168`) with `required_approving_review_count = 0` (`variables.tf:128`, live-verified for api). Consequence: in 29 of 31 repos an AI-authored change can reach `main` with **no provenance record and no review**, so the org cannot produce the SOC 2 CC8.1 / ISO A.8.32 change-attribution evidence its own policy claims | Confirmed policy/config mismatch | **High** for SOC 2 CC8.1 / A.8.32 change control / High (file existence verified org-wide) | Platform owner + audit lead | Decide per repo: copy `provenance.yml` (run-only steps, no secrets, so the Actions allow-list is not involved) into the populated app repos and add its check name to `branch_required_status_checks_contexts`, or amend the policy scope to state honestly that provenance is control-plane-only. Acceptance = policy text and enforced configuration agree for every repo the policy claims to cover, with a live 404/200 file check per repo attached. Depends on the same owner decision as VV-…-003 (reviews) — adding the context without wiring it into protection leaves it advisory |
| VV-2026-10-016 | **`viavitae-api` has no database schema: the Alembic migration tree is empty.** `app/db/migrations/versions/` contains exactly one file, `.gitkeep` (whose own text reads "Migration revisions live here"), so **zero revisions exist**; `alembic.ini` + `env.py` implement a schema-per-tenant runner (ADR-004) with nothing to run, the `Dockerfile` `CMD` is `uvicorn` only (no `alembic upgrade head` at boot), and `scripts/create_migration.sh` / `provision_tenant.py` exist as the intended workflow. **Deeper than first written (measured 2026-10-27 while planning the fix, E31):** `grep -rn '__tablename__' app/models/*.py` returns **nothing** — every domain file (`donation.py`, `assessment.py`, `gis.py`, `quote.py`, `notification.py`, `ai_document.py`, `ai_interaction.py`) is a docstring plus a `TODO(api)` comment, so `Base.metadata` is empty and `alembic revision --autogenerate` would emit a **no-op** migration; and `tenant_id_ctx` is **never set** anywhere in `app/` (only its definition in `app/core/logging.py:22` and two read sites), which makes the `set_config('app.tenant_id', …)` call in `app/db/session.py:66-71` **unreachable**, while no `search_path` is ever assigned — so DPIA-004 M1's "enforced by middleware" fails on three counts, not one. What is genuinely real: slug validation and hostile-input rejection in `app/core/tenancy.py`, transaction-local `set_config`, `pool_pre_ping`, statement timeout, and PostgreSQL 17 with pgvector (`docker-compose.yml:15`), so `gen_random_uuid()` needs no `pgcrypto` | Confirmed | **High** (release-blocking: no persisted functionality is possible, and the RLS/tenant-isolation control claim is void) / High (directory listing, Dockerfile and workflow read directly, E24) | Infra + API owners | Establish the migration baseline: a first Alembic revision creating the control schema and one tenant schema with RLS policies, wired into deploy as an explicit ordered step (not an image side effect); then the ADR-005 `webhook_event` + `idempotency_key` tables, expand–contract, each migration carrying its policy change and an un-skipped isolation test. **Design spec of record: `docs/superpowers/specs/2026-10-27-viavitae-api-persistence-baseline-design.md`** (milestones M0–M5, decisions D1–D8, STOP conditions, rollback, cost; it also records the two-layer role requirement D2 — RLS is bypassed by the table owner, so an unprivileged `viavitae_app` role is mandatory for the control to mean anything). Acceptance = a dated `alembic upgrade head` against a fresh ephemeral database producing tables + policies, the isolation tests executing (not skipped) in a DB-enabled CI job, **and** the isolation test observed to fail after deliberately dropping one `CREATE POLICY`. **Blocks VV-…-011** — the ledger has nowhere to live until revisions exist |
| VV-2026-10-017 | **A CI gate that cannot fail: in 14 of 31 repos the lint / typecheck / test / build legs never run, while the required `CI status` context reports success.** `viavitae-template`'s `ci.yml` builds its matrix lists with `to_json() { jq -cn --args '$ARGS.positional'; }` — the function **never forwards its arguments to `jq`** (no `"$@"`), so every list is `[]` regardless of what detection found. Reproduced locally: the same step logs `detected lint=python` while emitting `lint_stacks=[]`; adding `"$@"` emits `["python"]`, and the empty case still emits `[]`, so the fix is one token and cannot break the empty path. Live confirmation: on `viavitae-api` main run 38797087654 (`63cb494`) and on `viavitae-template` 38784899494 and `viavitae-brand` 38797074870, `Lint` / `Test` / `Typecheck` show conclusion `skipped` with the **unexpanded** job name `Test (${{ matrix.stack }})` and `matrix: null`, `steps: 0` — while `CI status` is `success`. Enumeration by reading each repo's workflow file (E27) finds the defective line in **14** repos: `viavitae-api`, `viavitae-brand`, `viavitae-infra`, `viavitae-template` and all ten `viavitae-landing-*`; `viavitae-web`, `viavitae-demos`, `viavitae-qa`, `viavitae-clients`, `viavitae-docs`, `viavitae-hermes-agents`, `.github` and `viavitae-control` do not contain it. Consequence for this audit: every "green `main` CI run" cited for those repos (§18, §19, E12/E17) is evidence of the compliance / Semgrep / Trivy / CodeQL legs **only** — it never demonstrated that unit tests, type checks or the coverage floor passed, and `CI status` being a required context means the org's release gate for those repos is decorative | Confirmed (reproduced + enumerated) | **High** (false assurance at the release gate; compliance-evidence integrity) / High | Platform owner + audit lead | Fix at the source first: add `"$@"` to `to_json` in `viavitae-template`, then propagate to the 13 other repos. **Progress 2026-10-27:** the template fix is **merged** (main `a38634e7`, all checks green) and the remaining 13 were pre-checked for shape — every one has exactly 1 defective line, 0 `has-source` outputs and 9 jobs, so a uniform single-line edit is safe while copying the template file wholesale is not. **Propagated 2026-10-27** as 13 single-line PRs — `viavitae-api#11`, `viavitae-brand#18`, `viavitae-infra#15` and `#6` in each of the ten landing repos — each opened from that repo's **live** `main` sha (not a local clone) after asserting the anchor occurs exactly once and that the byte-identical defective line (`md5 ec5646e2`) is shared by all 13; none merged. **The fix is proven to work**: on api#11 the jobs now report expanded names and execute — `Lint (python)` pass 8s, `Test (python)` **fail** 10s, `Typecheck (python)` **fail** 21s — where before they were `skipping` with `matrix: null`, `steps: 0`. That is also what uncovered VV-…-020: the legs fail because CI never installs the repo's dependencies, and on the landing repos there are no tests at all. api `main` still skips these legs until the propagation PR merges. Acceptance = on a fresh push per repo, the `Test` job reports with an **expanded** name (`Test (python)`), executes steps, and the aggregate is proven reactive by planting a deliberately failing test and watching `CI status` go red — a gate is only evidence once it has been seen to react |
| VV-2026-10-018 | **The advertised "PDF quotes" feature is unimplemented AND unshippable, and that fact also re-scores VV-…-004 for `viavitae-api`.** `QODER.md:8` lists "PDF quotes" as a delivered capability, while every consumer is a stub: `app/api/v1/quotes.py:43` raises `NotImplementedError` for `render_quote_pdf`, and `app/services/payments/receipts.py:52` is a `TODO(api)`. `app/services/pdf.py` imports WeasyPrint lazily and raises `PdfRenderingError` when the optional `pdf` extra is absent — and **nothing installs that extra**: tracked-file searches for `--extra pdf` and `.[pdf]` each return **0** matches, and the image build runs `uv sync --frozen --no-dev` (Dockerfile lines 22-25), so `pillow`, `weasyprint`, `fonttools`, `brotli` and `brotlicffi` are provably **not installed** (verified with `find_spec` → `PIL: False`, `weasyprint: False`, `brotli: False`) | Confirmed (claim-vs-build, plus reachability measurement) | **Medium** (feature claim false; the 7 pdf-extra criticals were lockfile-only, but see E32: the 8th, certifi, was live in the image and is fixed on the same branch) / High | API owner + audit lead | Either remove the `pdf` extra from `pyproject.toml` until the path is built — which also deletes all 8 CRITICAL lockfile findings at once, since the tree is unused — or install it deliberately (`--extra pdf`) with the Cairo/Pango base deps in the image and a real test for `render_quote_pdf`. Decide, then make `QODER.md` state the chosen truth. Acceptance = no present-tense feature claim survives for a path that either raises `NotImplementedError` or cannot be imported in the shipped image |
| VV-2026-10-019 | **Two deferred verifications closed — one claim disproved, one placeholder confirmed at the live head (E31).** (a) `app/workers/index_worker.py:4-6` states "Re-indexing is idempotent at the document level: the worker replaces the document's chunks rather than appending" — a **false present-tense claim of the same class as VV-…-014**: the function it delegates to, `ingest_document` in `app/services/rag/ingest.py:48-60`, performs **no persistence at all** (it chunks the text and returns counts, with `# TODO(api): … upsert into document_chunk under the tenant filter`), so there is nothing to replace and nothing to append. This item was recorded as SUSPECTED on 2026-10-27 and is now **CONFIRMED** by reading both bodies. (b) `viavitae-qa/contract/stripe/webhook-contract.spec.ts` contains two `assert.ok(true, "placeholder …")` cases under `node:test` — verified to be the file **as it exists at the remote head** `2d670ecc`, not merely in a stale local clone: the qa working copy is behind (local `3ace7525`, 2026-09-17), so the file's md5 was compared against `git show origin/main:…` and matched exactly | Confirmed (was SUSPECTED / NOT RUN) | **Medium** for (a) (RAG index correctness is unproven and the claim is false; no live data exposure because nothing writes) / **Medium** for (b) (a green contract test that cannot fail on the payment path) — confidence High for both | API + QA owners | (a) Reword `index_worker.py` as target behavior and let the ingest TODO own the claim; the replace-not-append assertion becomes testable only once `document_chunk` exists (VV-…-016 M5). (b) Replace the qa placeholders with assertions that call the real verification path and go red when the guard is removed — the same mutation-proof standard applied to the api pin test (E22) |
| VV-2026-10-020 | **Once the test legs actually run, they fail — because this org's CI never installs the dependencies a uv-based Python repo needs, and several repos have no tests at all.** Observed on the propagation branches (E36, E37): `viavitae-api` `Test (python)` → `ImportError while loading conftest … ModuleNotFoundError: No module named 'pytest_asyncio'`, exit 4, and `Typecheck (python)` → `Error importing plugin "pydantic.mypy": No module named 'pydantic'`; cause is the template install step, which runs `pip install pytest pytest-cov`, then `[ -f requirements.txt ] && pip install -r requirements.txt` (this repo has **none** — it is `pyproject.toml` + `uv.lock`), then `pip install -e . --no-deps`, so the application's own dependencies are never installed. The ten landing repos fail differently: `Typecheck (python)` on the PyCharm scaffold (`main.py:7 error: Function is missing a type annotation`, `main.py:14 …`), and `Test (python)` emits the template's own warning `No tests found. A repository with no tests cannot meet the 80% coverage gate` and exits 1 — i.e. those repos have **zero tests behind a declared 80 % coverage gate**. `viavitae-infra` also fails on the python legs, for its own reasons (VV-…-022, E40) | Confirmed for api/brand/landings; infra partially confirmed | **High** (the required `CI status` gate is not achievable as configured, so "green" was never evidence of tests — and making tests run turns every repo red) / High for api and the landings, **TBD** for infra | Platform owner | **Corrected scope (2026-10-27, E41): my earlier hand-off said a template install fix would make api#11 green, and that is wrong on both halves.** Measured per repo from live `main`: `viavitae-api` is the **only** repo with tests (36 test-ish paths) and a `pyproject.toml`; `viavitae-brand`, `viavitae-infra` and all ten landing repos have **0** tests and **no** `pyproject.toml`. And because every repo runs **its own copy** of `ci.yml`, a template-only change alters nothing elsewhere — the same hunk must be propagated. So an install fix is sufficient for **1 of 13** repos; the other 12 stay red for the *other* half of this finding (no tests behind a declared `COVERAGE_MIN: 80`, PyCharm scaffold mypy errors) or, for infra, for real code defects (VV-…-022). Order of work therefore: install fix in the template (opened as template #5, E41), prove api green, propagate, and take the landing-repo tests-or-exemption decision separately. The remedy sequence, unchanged: fix the install first (`uv sync --frozen --extra dev` in the lint/typecheck/test jobs, or generate pinned requirement files), then give each landing repo either real tests or an explicit ADR exemption **and** remove or lower its declared coverage gate deliberately — never by relaxing a test to pass. Only then merge the VV-…-017 propagation PRs, because the moment they land, the newly-running legs turn `CI status` red on those repos' default branches. Acceptance = per repo, `Test (python)` and `Typecheck (python)` execute and pass on `main`, and a planted failing test turns `CI status` red. **Remedy now proven, not assumed (E38):** a throwaway detached worktree at `/tmp/ci-repro-wt` (so no build artifacts entered any repo) reproduced CI's recipe verbatim and exited **4** with the same `ModuleNotFoundError: No module named 'pytest_asyncio'`, then `uv sync --frozen --extra dev` followed by pytest with CI's own flags (`--cov --cov-fail-under=80 --junitxml`) passed **122 passed / 6 skipped**, exit 0. The worktree was removed and `git worktree prune` run afterwards; no repo state changed |
| VV-2026-10-021 | **The coverage floor the repo documents is not the floor it enforces.** `pyproject.toml:88-92` sets `fail_under = 85` under the comment `# Ratchet: the floor only moves up. Measured on the offline suite … 85 matches the CI gate in the spec and leaves a small buffer`, but `.github/workflows/ci.yml:43` sets `COVERAGE_MIN: "80"` and the test job passes `--cov-fail-under="${COVERAGE_MIN}"`, so CI enforces **80 %** while the config and its comment claim 85 % matches. Consequence: a change dropping coverage to 80–84.9 % passes CI while violating the documented ratchet, and the comment asserts a correspondence that does not hold (a claim-vs-configuration mismatch of the same family as VV-…-007 and VV-…-014) | Confirmed by reading both files | **Low** (no direct exposure; weakens a stated quality gate and misleads via its comment) / High | API owner | Make one number authoritative: either set `COVERAGE_MIN` to the current measured floor and correct the comment, or raise it to 85 deliberately after measuring. Measured today: local run reports 86.85 % on the PR #9 branch and the offline main baseline is 85.67 %, so 85 is achievable — choosing 85 also keeps the "floor only moves up" promise honest. Acceptance = the two files agree and the comment describes the value actually enforced |
| VV-2026-10-022 | **`viavitae-infra` carries real python defects that were invisible for 12 days because the matrix legs never ran.** Its CI run on the propagation branch (40563310740) ends `failure`, but the split is informative: `Detect stack`, `Lint (terraform)`, `Dependency scan (Trivy)` and `SAST (Semgrep)` all **success**, while `Test (python)`, `Lint (python)` and `Typecheck (python)` all **fail**. The typecheck failure is a genuine code defect, not an install problem: `tools/cost-estimate.py:68: error: Incompatible types in assignment (expression has type "float", variable has type "int") [assignment]`, and `Lint (python)` reports one further error in the same file (its rule text was not captured in the log I read). The `Test (python)` leg exits 1; its precise reason is **not separately confirmed** here. Note that `Lint (terraform)` passing is itself evidence the repo's IaC leg is fine | Confirmed for the typecheck and lint findings; Test-leg cause open | **Medium** (a real type defect in a cost-estimation tool that never surfaced; no runtime exposure proven either way) / High for the type error, Low confidence on the test leg | Infra owner | Fix `tools/cost-estimate.py:68` (declare the variable as `float`, or narrow the expression), resolve the single ruff finding, then re-run the leg to see whether `Test (python)` still fails once the other two are clean. Acceptance = infra's `Lint (python)` and `Typecheck (python)` pass on a fresh push, and `Test (python)` either passes or its remaining cause is named with evidence |
| VV-2026-10-023 | **`viavitae-brand` has ten real type errors, one lint error and five live CRITICAL dependencies — none of it was ever visible, because its CI legs skipped.** Finishing the diagnosis I had left as "brand #18 FAILURE" without a cause (E37), run 40576600976 on the propagation branch reports: `Typecheck (python)` fails with mypy `Found 10 errors in 3 files (checked 4 source files)` — the individual lines include `tools/validate_tokens.py:66: error: Unused "type: ignore" comment`, `tools/validate_tokens.py:731: Argument 1 to "get" of "dict" has incompatible type "Any or None"; expected "str"`, `tools/validate_tokens.py:769: Item "None" of "Match[str] or None" has no attribute "group"` and `tools/cyrillic_check.py:73: Unused "type: ignore" comment` (the log renders both union types with a pipe character; it is written as "or" here so this table stays valid — quote from the run, not from this row); `Lint (python)` fails with `Found 1 error`; and `Dependency scan (Trivy)` fails with `Total: 5 (CRITICAL: 5)`. Note this is **not** caused by the install fix: brand has no `uv.lock`, so it runs the unchanged pip `else` arm — the errors were always there and simply had no executing leg to report them (VV-…-017's cost, second instance after VV-…-022). The two `Unused "type: ignore"` findings also mean the file was previously type-checked under a different mypy, so at least some suppression comments are now stale | Confirmed (read from the failing run log, counts taken from mypy's and Trivy's own summary lines) | **Medium** for the type errors (a token-validation tool that does not type-check; no runtime failure demonstrated) and **High** for the five CRITICAL dependencies (same class as VV-…-004, and here the gate is genuinely blocking) / High | Brand owner | Bump the five CRITICALs in brand's manifest the way api's were bumped (E32), then fix the ten mypy errors file by file and re-run so the two `unused-ignore` comments are removed rather than papered over. Do not add new `type: ignore` to silence them. Acceptance = brand's `Lint (python)`, `Typecheck (python)`, `Dependency scan (Trivy)` and the required `CI status` all pass on a fresh push, and `Test (python)` either passes or is explicitly exempted under the VV-…-020 landing decision |

**Risk acceptance** is tracked separately from these check results; none has been
accepted, waived or closed by this document.

## 24. Release gates and decision (Phase 13 result)

| Gate | Result | Basis |
| --- | --- | --- |
| 1 Scope | FAIL / UNDETERMINED | Org reconciled 31/31, but release contents never named |
| 2 Evidence | UNDETERMINED | 22 populated repos now deep-audited; 5 private empty BLOCKED; staging E2E absent. **Weakened 2026-10-27 (E27, VV-…-017):** for 14 of those repos the "green `main` CI run" cited as evidence never executed lint, typecheck, tests or the coverage gate; where they now do run, they fail for the VV-…-020 reason (E36, E37) |
| 3 Functionality | **FAIL** (was UNDETERMINED; corrected 2026-10-27) | No cross-repo E2E evidence (VV-…-009); payment/donation journeys cannot function — webhook handlers are 501 stubs (VV-…-011) — and **no database schema exists at all** (zero Alembic revisions, VV-…-016), so no persisted functionality in the API can work |
| 4 Security | **VERIFIED FAIL** | 20 critical + 63 high open on default branches incl. release candidates as at the reference date (VV-…-004; re-measured 2026-10-27: **19 critical / 62 high**, E33; after merging the api dependency PRs, **12 critical / 39 high**, E34). **Refined 2026-10-27:** detection→enforcement is uneven, not uniformly absent — on `viavitae-api` a CRITICAL dependency genuinely blocks merge (E26, PR #9 is locked by it), while on the 14 repos of VV-…-017 the aggregate passes without ever running the test legs. **Reachability re-scored 2026-10-27 (E30→E32, VV-…-018):** of api's 8 Trivy CRITICAL findings, **7 sit in the optional `pdf` extra tree that the image never installs** (lockfile-only), but **the 8th — certifi — ships through `httpx` and was live**; both facts were measured per package, and the first draft's claim that all 8 were lockfile-only is retracted (E32, §28 item 14). Fixed on PR #10, which turned `CI status` green |
| 5 Privacy | **FAIL** | Art. 28/30 corpus absent while collection runs in code (§20, VV-…-002) |
| 6 Integration | **FAIL** (was UNDETERMINED; corrected 2026-10-27) | `api → Stripe/Paysera/Bitrix24` is unimplemented (501 stubs, no signature check, no ledger) so it can never integrate (VV-…-011/-014); the remaining legs stay NOT RUN because provisioning is unverified (§21, VV-…-009) |
| 7 Operations | **VERIFIED FAIL** | Deploy red; prod manifests placeholder; no RPO/RTO; empty runbooks (§21, VV-…-001) |
| 8 Landing scope | **FAIL** | Unfinished and undocumented either way (§22, VV-…-005) |
| 9 Independence | NOT SATISFIED | Self-review only (VV-…-003/-006) |
| 10 Approval | n/a | This report is a recommendation, not a decision |

**Recommendation: NO-GO.** Six mandatory gates fail outright (Security, Privacy,
Operations, Landing scope, Integration, Functionality); others cannot be decided on available evidence.
Remediation to make a decision possible: (a) written release definition — repos +
exact heads from §16; (b) fix VV-…-001 and -009 so journey evidence becomes
producible; (c) remediate the 20 criticals and add the Dependabot enforcement gate
(VV-…-004); (d) populate the minimum GDPR corpus (VV-…-002); (e) resolve the
access-review gap (VV-…-006); (f) implement the money-path webhook processing
(VV-…-011) and remove the false claims that conceal it (VV-…-014); (g) re-run
gates and record the decision separately.

**Recommendation ≠ approval.** The authorized decision-maker (today, the same sole
owner) must record any GO/GO-WITH-CONDITIONS decision separately, with residual
risks, named approver, compensating controls and expiry. GO WITH CONDITIONS must
not mask a failed mandatory gate; risk acceptance does not override legal obligations.

## 25. Verification register (Phase 12)

Remediation began on 2026-10-27 for one finding (-014, with the -011 wording
correction it implies) inside an isolated `viavitae-api` worktree and in this
document. Nothing has been committed, pushed or independently reviewed, so the
status stops at **FIX IN PROGRESS / REVIEW PENDING** — an implemented fix is not
a verified fix. Self-corrections of the *audit document itself* are logged in §28
and are not org fixes.

| Finding | Fix proposed | Fix implemented | Independently verified | Verifier / date |
| --- | --- | --- | --- | --- |
| VV-2026-10-001 | no | no | **PENDING** | — (independence structurally pending, §13/§15) |
| VV-2026-10-002 | no | no | **PENDING** | — |
| VV-2026-10-003 | no | no | **PENDING** | — |
| VV-2026-10-004 | no | no | **PENDING** | — |
| VV-2026-10-005 | decision requested | no | **PENDING** | owner |
| VV-2026-10-006 | no | no | **PENDING** | — |
| VV-2026-10-007 | no | no | **PENDING** | — |
| VV-2026-10-008 | scoped down in-report | n/a | **N/A** (documentation) | — |
| VV-2026-10-009 | no | no | **PENDING** | — |
| VV-2026-10-010 | access request | no | **BLOCKED** | — |
| VV-2026-10-011 | re-scoped 2026-10-27 (was scored on a false premise) | no — the implementation gap remains open | **PENDING** | — |
| VV-2026-10-014 | yes | **merged** — `viavitae-api` `9b204f48` (PR #9), `viavitae-control` `0375f16d` (PR #42); checks green on the exact heads | **NOT independently verified** — same session authored, the owner instructed and performed no separate review; status stays REVIEW PENDING for verification purposes | — |
| VV-2026-10-012 | no | no | **PENDING** | — |
| VV-2026-10-013 | no | no | **PENDING** | — |
| VV-2026-10-015 | yes (evidence gathered org-wide, E21) | no — adding the workflow/hook to 29 repos writes to other repositories and needs owner authorization | **PENDING** | — |
| VV-2026-10-016 | yes (diagnosis + remediation plan in §23) | no — building the schema is feature work with a live DB, outside this session's authority | **PENDING** | — |
| VV-2026-10-017 | yes (one-token root cause identified, reproduced locally, 14 repos enumerated) | **template merged (`a38634e7`); 13 propagation PRs opened, none merged** — api#11, brand#18, infra#15, landing-*#6 | **PENDING** — legs now run everywhere; with the install fix also propagated (E43), **api#11 is fully green including `Test (python)`**, while the other 12 are red for the non-install reasons in VV-…-020, -022 and -023. None merged | — |
| VV-2026-10-018 | yes (two routes: drop the unused extra, or install it and implement the path) | no — owner decision on the feature, then code | **PENDING** | — |
| VV-2026-10-019 | yes (wording + real contract assertions) | no — the api wording sits on the pushed PR #9 scope, which did not include this file; qa placeholder rewrite is another repo and needs authorization | **PENDING** | — |
| VV-2026-10-020 | yes — **install half done**: template merged (`682ab794`) and the hunk is on all 13 branches (E43) | no — the remaining half is a **decision**, not a command: 12 repos have no tests behind a declared `COVERAGE_MIN: 80`; merging their propagation PRs now turns their `main` red | **PENDING** — api#11 fully green (E43); landings, brand and infra red for the named non-install reasons. Owner must decide tests-or-exemption per landing repo before those 10 merge | — |
| VV-2026-10-021 | yes (align the two numbers and fix the comment) | no — a one-value config change in `viavitae-api`, needs owner choice of the floor | **PENDING** | — |
| VV-2026-10-022 | yes (fix the assignment and lint finding, then re-test) | no — different repo; needs owner authorization to write to `viavitae-infra` | **PENDING** — Test-leg cause still unnamed | — |
| VV-2026-10-023 | yes (five dependency bumps + ten type fixes, both mechanical) | no — writes to `viavitae-brand`; and its `Test (python)` leg needs the VV-…-020 tests-or-exemption decision first | **PENDING** — causes now named (E43); previously recorded only as "FAILURE" | — |

## 26. Coverage statement and evidence index

Mutually-exclusive partition of **31**: **12 deep-assessed** (control, web, api,
infra, template, .github, docs, brand, demos, hermes-agents, qa, clients) ·
**10 landing class-assessed** · **9 empty-confirmed** (of which **5 private are also
access-BLOCKED** for protection/security metadata; 4 public empties have no content
to audit). 12 + 10 + 9 = 31. Dependabot: **20 crit / 63 high** open; code-scanning:
3 open (api/web/demos); CI: a green `main` run on all 22 populated repos (E17).
Exclusions from any completeness claim: the 5 private-repo blind spot and
`admin:org_hook`. (Corrects the prior partition, which double-counted the empties and
summed to 36 — see §28 item 7.)

Evidence captures this session (retain under the same controlled handling as
`audit-evidence/`; no secret values reproduced):

- **E1** Live inventory JSON (31 rows: visibility, size, heads, dates), org API, paginated.
- **E2** Declared inventory reconciliation (`repos_data.tf` keys vs live; 0/0 diff).
- **E3** Terraform state structure: type counts, serial 143, TF 1.16.1.
- **E4** Local clone heads/dirty status for 29 working copies.
- **E5** `viavitae-api` README/structure — FastAPI, multi-tenant RLS Postgres, Stripe/Paysera/Bitrix24, RAG, k3s+ArgoCD.
- **E6** `viavitae-web` and `viavitae-clients` READMEs, package.json, provisioning journey.
- **E7** `viavitae-infra` tree census (ansible/terraform/k8s/monitoring/backup), prod placeholder manifests, SOPS config + pub-only age keys, `.gitignore` key exclusions.
- **E8** `viavitae-web` quote-route consent validation (DPIA-001 R7), middleware CSP, env keys (Keycloak, Matomo).
- **E9** Landing sample (`viavitae-landing-diocese`) file tree, README, PyCharm `main.py`, workflow list.
- **E10** Branch-protection detail sweep (21 repos: appr/ctxs/strict/admins/force) + rulesets + secret-scan status per repo.
- **E11** Org settings (2FA=true, plan=free), members, teams, outside collaborators, Actions permissions (`sha_pinning_required=false`).
- **E12** CI run listings: web/clients/api/qa/control `main` + failed Dependabot lint + failed Deploy run 38797087629 ("Build and push image").
- **E13** `docs/SECRETS_INVENTORY.md` register and backup-media section (as at file state 2026-10-26).
- **E14** Read-only `terraform plan` transcript: `Error: No value for required variable "billing_email"`, exit 1.
- **E15** Dependabot open alerts by `security_advisory.severity` across all 31 repos (20 crit / 63 high) + `code-scanning/alerts` open counts (api/web/demos = 1 each).
- **E16** Team→repo bindings, freshly read: each of architects/compliance/dpo/legal/platform/security returns 30 repos.
- **E17** Per-repo live tree census (blob counts, top dirs, keyfiles, workflows, tests) for .github/docs/brand/demos/hermes-agents/qa/clients at the §16 heads; green `main` CI runs for all.
- **E18** Blocked-cell re-read: 5 private repos → "Upgrade to GitHub Pro…" 403 for protection/rulesets; org webhooks → 404 "needs admin:org_hook"; org Actions allow-list patterns.
- **E19** `viavitae-api` webhook handlers (stripe/paysera/bitrix24/router + `webhook_event` ledger, ADR-005) and `tests/webhooks/test_stripe_idempotency.py` (reject/503 asserted; replay `pytest.skip`).
  **E19-CORRECTED (2026-10-27, re-read at @63cb4943, local worktree not the API):**
  all three handlers finish with `raise ApiError("not_implemented", …, status_code=501)`
  behind a `# TODO(api)` block; `app/models/webhook_event.py` is a docstring plus a
  TODO comment (no ORM model, no migration); `pyproject.toml` declares no `stripe`
  dependency, so `stripe.Webhook.construct_event` could not be called even if the
  code had claimed to. The original E19 wording ("the control exists and is
  code-tested") was read off the **docstrings and a stored working note**, not the
  handler bodies, and is retracted. Only the input guards (400 / 503) were ever
  tested — and the guard test itself hid the fact that the 501 branch was
  unexercised (see VV-…-014).
- **E20** Config content reads: docs pentest stub + `config/production/hugo.toml` (`noindex=false`) + `netlify.toml` EU-self-host guard; demos `.npmrc`/`.env.example` (no literals); hermes-agents `tests/test_boundary.py` (fail-closed `BoundarySettings`) + `.gitleaks.toml`.
- **E21** (2026-10-27) Provenance/hook coverage sweep: for each of the 31 repos, `gh api repos/Via-Vitae/<r>/contents/.github/workflows/provenance.yml` and `.../contents/.pre-commit-config.yaml` → HAS_PROVENANCE = 1 (`viavitae-control`), HAS_PRECOMMIT = 2 (`viavitae-control`, `viavitae-hermes-agents`). Plus `variables.tf:128` / `:168` defaults and `viavitae-api` live protection JSON (`required_approving_review_count: 0`, contexts `CI status`/`Compliance status`), and its empty `.git/hooks` (no `commit-msg`) — basis for VV-…-015.
- **E22** (2026-10-27) Mutation evidence for the -014 fix, in the isolated `viavitae-api` worktree @ `63cb494`: replacing each handler's 501 with a 200 acknowledgment made the pin test fail (stripe/paysera/bitrix each **exit 1**), all files restored byte-identical, suite green afterwards. A second mutation implementing the full design contract (`200` + `Idempotent-Replayed: true`) turned the converted `xfail(strict=True)` into a hard **XPASS** failure, proving the design test self-flags when the money path lands.
- **E23** (2026-10-27) Baseline-vs-fix delta for the same repo: `pytest` baseline **122 passed / 6 skipped / cov 85.67%** → fixed **125 passed / 5 skipped / 1 xfailed / cov 86.85%** (skip count reduced by converting one invisible skip into an executable xfail — no test was weakened); `ruff check` 0, `ruff format --check` 120 files clean, `mypy --strict app` success/75 files, committed `docs/api/v1-openapi.json` == regenerated (`fresh: True`). Control plane at `d0251b6`: `detect_drift.sh` exit 0 (31==31), `test_control_guards.sh` exit 0 (42 PASS), `pre-commit run` exit 0.
- **E24** (2026-10-27) DPIA-004 measures audited row-by-row against the code, with positive existence markers (empty shell output was re-probed, never read as absence): `app/db/migrations/versions/` = `ls -la` → **only `.gitkeep`**, i.e. zero Alembic revisions (→ VV-…-016); `app/workers/retention_worker.py` (cited by M4) → **ABSENT**, the directory holds `demo_reset`, `followups`, `index_worker`, `queue`, `reconciliation_worker`; M1's tenant GUC is real (`app/db/session.py` sets `app.tenant_id`) but no tables/policies can exist without revisions; M3's redaction is real (`_redact` over secret-named keys in `app/core/logging.py`) and CI SAST exists but runs **Semgrep** (`sast: name: SAST (Semgrep)`, configs `p/security-audit`, `p/secrets`, `p/owasp-top-ten`) plus **Trivy** in `dependency-scan` — **not** bandit, which is only a dev dependency; `Dockerfile` `CMD` = uvicorn only; `deployments/k6/smoke.js` thresholds `http_req_duration p(95)<800`, `checks rate>0.99` and asserts `501 not_implemented` for scaffolded paths (honest, but not a business journey).
- **E25** (2026-10-27) Mechanical sizing of the -014 fix and of the merge gate the landing depends on. Change volume: `git diff --unified=0 | grep -c '^@@'` = **39 hunks / 14 files** in `viavitae-api` (218 insertions, 61 deletions) and **33 hunks / 1 file** in this repo (178 insertions, 44 deletions); per-file hunk distribution retained in the session log. Gate check, read live rather than from a note: `gh api repos/Via-Vitae/viavitae-control/rulesets/23943250 --jq '.rules[].type'` → `deletion, non_fast_forward, required_linear_history, pull_request, required_status_checks`, and the status rule is `{required_status_checks:[{context:"provenance"}], strict_required_status_checks_policy:true}` — so the `provenance` check **is** blocking on this repo (an older working note said it was declared-but-not-applied; that is now superseded by this live read).
- **E26** (2026-10-27) Dependency and merge-state facts behind the VV-…-004 correction, read from the REST API for `viavitae-api`. **Counting basis stated, because the two instruments disagree:** open **Dependabot** critical alerts = **7** — pillow → 13.0.0 (alerts 4, 13, 30, 35, 46), brotlicffi → 1.2.1.0 (44), brotli → 1.2.1 (43), all `eco=pip manifest=uv.lock` — while **Trivy** reported **8** CRITICAL findings on the same commit; the extra one is **certifi**, which is **not a Dependabot alert at any severity** (`select(.dependency.package.name=="certifi")` over all open alerts returns nothing). Totals by severity: 7 critical / 23 high / 14 medium; **open Dependabot PRs = 0**; last merged PR = #4 at 2026-10-15T19:50Z; PR #9 rollup = `CI status` FAILURE and `Dependency scan (Trivy)` FAILURE while `Compliance status`, Semgrep, CodeQL (python + js), licence, action-pinning, governance, secret-scanning and drift-detection all SUCCESS; the Trivy step log ends `Total: 8 (CRITICAL: 8)` then `##[error]Process completed with exit code 1`, and the aggregate evaluator recorded `"dependency-scan": {"result": "failure"}`.
- **E27** (2026-10-27) Root cause of VV-…-017. Defective line read verbatim from each repo's workflow: `to_json() { jq -cn --args '$ARGS.positional'; }` — no `"$@"`, so jq receives no positional arguments. Local reproduction under `set -euo pipefail`: with `lint=("python")` the same step prints `detected lint=python` yet yields `lint_stacks=[]`; the corrected function yields `["python"]`; both still yield `[]` when the array is empty, so the one-token fix cannot break the no-stack path. Live: `gh api repos/Via-Vitae/viavitae-api/actions/jobs/122345782966` → conclusion `skipped`, `matrix: null`, `steps: 0`, name `Test (${{ matrix.stack }})`; main push runs 38797087654 (api), 38784899494 (template) and 38797074870 (brand) all show Test/Lint skipped with the unexpanded name while `CI status` = success; web (40017382631), demos (38781543242) and qa (39028161804) show a real `Lint` success. Enumeration of the populated repos: the line is present in **14** (api, brand, infra, template, ten landing-*) and absent in 8.
- **E28** (2026-10-27) Private-repo population re-check behind the §16 "EMPTY" rows and VV-…-002: `viavitae-policies`, `viavitae-data-governance`, `viavitae-threat-model` and `viavitae-vendor-register` still return "This repository is empty."; `viavitae-compliance` now reports content (7KB, updated 2026-10-26T14:24Z) but **zero files** — its tree is `docs/` then `docs/security/`, two directories only — so it remains unevaluable and **VV-…-002 stays open**. Org totals unchanged: 31 repos, 26 public / 5 private.
- **E29** (2026-10-27) A/B of the VV-…-017 fix executed as the workflow's **own** script body, extracted from `viavitae-template/.github/workflows/ci.yml` (job `setup`, step `Detect present stacks`) and run with `bash -euo pipefail` inside the `viavitae-api` tree where python genuinely exists. Pre-fix: `lint_stacks=[]`, `typecheck_stacks=[]`, `test_stacks=[]`, `build_stacks=[]`, `has_source=true`. Post-fix (adding `"$@"`): `lint_stacks=["python"]`, `typecheck_stacks=["python"]`, `test_stacks=["python"]`, `build_stacks=["docker"]`, `has_source=true`. The one-line change is the only diff; the template file also declares a fifth output (`has-source`) that `viavitae-api`'s copy does not, so the 13 downstream repos have **drifted** from the template and cannot be fixed by a blind copy.
- **E30** (2026-10-27) Dependency bump prepared on `viavitae-api` branch `fix/deps-pdf-extra-criticals` (base `63cb494`, worktree `viavitae-api-wt-deps`): `uv lock --upgrade-package pillow --upgrade-package brotli --upgrade-package brotlicffi` moved **exactly three** versions — pillow 12.3.0→13.0.0, brotli 1.2.0→1.2.1, brotlicffi 1.2.0.2→1.2.1.0 — with package count 78 before and after, nothing added or removed (compared as parsed `(name, version)` sets, not by eye); `uv lock --check` exit 0 so `uv sync --frozen` in CI stays valid; offline suite **122 passed / 6 skipped**, `ruff check` clean, `mypy --strict app` clean on 75 files. Reachability was measured rather than assumed: the Dockerfile installs with `uv sync --frozen --no-dev` (no `--extra pdf`), and `find_spec` confirms `PIL`, `weasyprint` and `brotli` are absent from the resolved environment, so these 8 CRITICAL findings are lockfile-only today (see VV-…-018). **CORRECTED by
measurement, not reasoning (E32): the "8 are lockfile-only" conclusion was WRONG.**
After this branch merged nothing, api#10's first run still failed Trivy with **1**
CRITICAL left, and the log named it: `certifi GHSA-6q48-6c7w-9gw2`, installed
2026.7.22, fixed 2026.10.18 — **certifi is a live runtime dependency via `httpx`**,
confirmed by `uv sync --frozen --no-dev` then `find_spec`: `certifi: installed=True`,
`httpx: installed=True`, while `PIL`, `weasyprint` and `brotli` are all `False`. So
**7** of the 8 were lockfile-only (the uninstalled `pdf` extra tree) and **1 was
shipped and reachable on every outbound TLS call**. Bumping certifi to 2026.10.23 took
Trivy from 8 → 1 → 0 CRITICAL and flipped `CI status` from FAILURE to SUCCESS; the
rollup on head `b1839ce` is `mergeStateStatus: CLEAN`, which lifts the merge lock.
Also recorded: my first E26 draft said "8 alerts" and listed 7 rows, then my "correction" claimed the missing row was certifi — **both wrong**. There are 7 Dependabot alerts and 8 Trivy findings; certifi exists only in the latter. A count must name its instrument (E32)
- **E31** (2026-10-27) Measurements taken while writing the persistence-baseline spec, each with the command that produced it: `grep -rn '__tablename__' app/models/*.py` → **no matches** (only 5 `mapped_column` hits, all in `base.py`'s mixins), so `Base.metadata` is empty and `--autogenerate` would emit a no-op revision; `grep -rn 'tenant_id_ctx' app/` → definition plus two reads, **no `.set(` writer**, so `app/db/session.py:66-71` never issues `set_config`; no `search_path` assignment anywhere in `app/`; `app/services/rag/ingest.py:48-60` performs no persistence (chunk + count only) while `app/workers/index_worker.py:4-6` claims chunk replacement → VV-…-019(a); `viavitae-qa/contract/stripe/webhook-contract.spec.ts` placeholders confirmed at the **remote** head by md5-comparing the working copy against `git show origin/main:…` (the local clone is behind: `3ace7525` vs remote `2d670ecc`) → VV-…-019(b); `docker-compose.yml:15` pins `pgvector/pgvector:pg17`, so `gen_random_uuid()` is built in and `IdMixin` needs no `pgcrypto`. Spec of record: `docs/superpowers/specs/2026-10-27-viavitae-api-persistence-baseline-design.md`.
- **E32** (2026-10-27) Empirical test of the dependency remedy on `viavitae-api` PR **#10**, which falsified part of E30. First run after the pillow/brotli/brotlicffi bump (run 40554534148): `Dependency scan (Trivy)` **fail** with `Total: 1 (CRITICAL: 1)` and the row `certifi GHSA-6q48-6c7w-9gw2 fixed 2026.7.22 → 2026.10.18`, so `CI status` stayed **fail**. Reachability re-measured per package with `uv sync --frozen --no-dev` then `importlib.util.find_spec`: `certifi: installed=True`, `httpx: installed=True`, `PIL: installed=False`, `weasyprint: installed=False`, `brotli: installed=False` → certifi ships (through `httpx`), the other seven do not. After `uv lock --upgrade-package certifi` (→ 2026.10.23; 78 packages before/after, `uv lock --check` 0, local suite 122 passed / 6 skipped), head `b1839ce` reports `Dependency scan (Trivy)` **SUCCESS**, `CI status` **SUCCESS**, `Compliance status` **SUCCESS**, `mergeStateStatus: CLEAN`. Consequence: the api merge lock is liftable by merging #10; then #9 needs `gh pr update-branch` (strict up-to-date) before it can merge.
- **E33** (2026-10-27) Org-wide Dependabot recount, grouped by `security_advisory.severity` over `state=open` alerts for all 31 repos: **19 critical, 62 high, 61 medium, 8 low**. The report's reference-date totals were 20 critical / 63 high (E15), so the estate improved by one critical and one high in the interim. Recorded to establish the rule used from now on in this register: **every alert count states its date and its instrument**, because Dependabot and Trivy disagree on the same commit (api: 7 Dependabot critical alerts vs 8 Trivy CRITICAL findings, E26/E32) and neither is stable over time.
- **E34** (2026-10-27) Post-merge verification of this session's own landings, read from the API rather than from the tool that made them. Merged: template #4 → `a38634e7` (line 90 of `ci.yml` on main carries `"$@"`); api #10 → `80cdb766`; api #9 → `9b204f48`; control #42 → `0375f16d`. On api main `9b204f48`: `CI` **success**, `Compliance check` **success**, `CodeQL` **success**, `OpenAPI diff` **success**, and `Deploy — viavitae-api` **failure** at `Build and push image` — the pre-existing VV-…-001 condition, unchanged by these merges. Alert recount after merging: org-wide **12 critical / 39 high / 48 medium / 8 low** versus **19 / 62 / 61 / 8** immediately before, and **api alone went from 7 critical + 23 high + 14 medium to 1 medium** — the deltas match api exactly, which is the arithmetic check that the fix did what it claimed. Caveat retained: api's `Test`/`Lint`/`Typecheck` jobs are still `skipping` (VV-…-017 unpropagated), so the new pin test is proven by local mutation, not yet by CI.
- **E35** (2026-10-27) VV-…-001 root cause, read from the failing job rather than inferred: `gh run view 40558832572 -R Via-Vitae/viavitae-api --log-failed` → `ERROR: failed to build: failed to solve: failed to push ghcr.io/via-vitae/viavitae-api:main: denied: installation not allowed to Create organization package`. Step sequence in that job: `Set up job`, `checkout`, `Set up QEMU`, `Set up Docker Buildx`, **`Login to GHCR` all success**, `Extract metadata` success, **`Build and push` failure**, and `Deploy to staging` / `Deploy to production` `skipped` as a consequence. `.github/workflows/deploy.yml` lines 18-20 declare `permissions: { contents: read, id-token: write }` — **`packages: write` is absent** — while line 27 pushes to `IMAGE: ghcr.io/Via-Vitae/viavitae-api`, i.e. an **organization** namespace. So the failure is an authorization boundary at first push, not a Dockerfile or build-context defect, and the login succeeding proves the credentials themselves are valid.
- **E36** (2026-10-27) Why the newly-running legs fail on `viavitae-api` PR #11 (run 40563218973): `Test (python)` → `ImportError while loading conftest '/home/runner/work/viavitae-api/viavitae-api/tests/conftest.py'. E ModuleNotFoundError: No module named 'pytest_asyncio'`, `##[error]Process completed with exit code 4`; `Typecheck (python)` → `pyproject.toml:1: error: Error importing plugin "pydantic.mypy": No module named 'pydantic'`, exit 2. Cause read from `.github/workflows/ci.yml`: the jobs run `pip install pytest pytest-cov`, then conditionally `pip install -r requirements.txt` / `requirements-dev.txt` (this repo has **neither**; it is `pyproject.toml` + `uv.lock`), then `pip install -e . --no-deps`. So the application's own dependencies are never installed in CI. The same repo's tests pass locally under `uv sync --extra dev` (125 passed / 5 skipped / 1 xfailed), which is what proves the failure is an install defect, not a broken test.
- **E37** (2026-10-27) Rollout state of the 13 propagation PRs and the landing-repo cause. Per-PR `CI status` after the fix: api #11 FAILURE, brand #18 FAILURE, infra #15 FAILURE, basilica / cemetery-services / churches-orthodox / churches-other #6 FAILURE (others still `pending` at read time; three reported `none` because the aggregate had not yet been created) — every repo whose checks finished is red, and **no repo is mergeable yet** (all gates `BLOCKED`). Landing cause, read from basilica run log rather than inferred: `Typecheck (python)` fails on the PyCharm scaffold (`main.py:7: error: Function is missing a type annotation [no-untyped-def]`, `main.py:14: error: Call to untyped function "print_hi" …`), and `Test (python)` prints the template's own warning `No tests found. A repository with no tests cannot meet the 80% coverage gate; add tests or record an ADR explaining why this repository is exempt.` then exits 1 — so these repos declare an 80 % coverage gate with zero tests. `viavitae-infra` fails in `Plan (dev)`, `Plan (staging)`, `Plan (prod)`, `Plan (global)`; its cause is **UNDETERMINED** and deliberately not attributed. **CORRECTION (same day, E40): that infra sentence was wrong.** The run I cited (40563311046) is the **Deploy** workflow, its `status` was `queued` and the four `Plan` jobs had **no conclusion at all** — they had not started, so they were not failing. Reading a blank conclusion as a failure is the same error family as reading empty command output as absence. Infra's real signal is its CI run 40563310740 (see VV-…-022, E40): the terraform and security legs pass and the python legs fail, including a genuine mypy assignment error.
- **E38** (2026-10-27) Differential reproduction of VV-…-020 and its remedy, run locally so the claim does not rest on reading a YAML file. A detached throwaway worktree (`git worktree add --detach /tmp/ci-repro-wt origin/main`) was used so that `pip install -e .` build artifacts could not enter any working repo. **A (CI's recipe verbatim):** `python3 -m venv`, `pip install pytest pytest-cov`, `[ -f requirements.txt ]` (absent), `pip install -e . --no-deps`, then `python -m pytest -q --cov --cov-fail-under=80` → **exit 4**, `ImportError while loading conftest '/tmp/ci-repro-wt/tests/conftest.py' … ModuleNotFoundError: No module named 'pytest_asyncio'` — matching the CI failure numerically and textually. **B (remedy):** `uv sync --frozen --extra dev` (exit 0) then the same pytest command with CI's own flags → **122 passed / 6 skipped, exit 0**. The 122/6 baseline (rather than 125/5/1) is correct here because this reproduction ran on `origin/main`, where PR #9's pin test and strict xfail are not yet merged… they are merged as of `9b204f48`, and the local figures for that state are in E23. Afterwards: `git worktree remove --force /tmp/ci-repro-wt` + `git worktree prune`, verified gone; no repository state was altered by the experiment.
- **E39** (2026-10-27) Coverage-floor discrepancy behind VV-…-021, read directly from the two files: `pyproject.toml:92` `fail_under = 85` with the comment claiming `85 matches the CI gate in the spec`, versus `.github/workflows/ci.yml:43` `COVERAGE_MIN: "80"` consumed at line 277 as `--cov-fail-under="${COVERAGE_MIN}"`. Also measured: the landing repos inherit the same `COVERAGE_MIN: 80` while containing no tests at all, which is the other half of VV-…-020.
- **E40** (2026-10-27) `viavitae-infra` read properly after my own misattribution. `gh run view 40563311046 --json name,headBranch,status,conclusion` → workflow **Deploy**, branch `fix/ci-matrix-args`, `status: queued`, `conclusion: ""` with `Plan (dev)`, `Plan (staging)`, `Plan (prod)` and `Plan (global)` carrying no conclusion — queued, never started, therefore **not** failures. The correct target is the CI workflow on the same branch, run 40563310740, `conclusion: failure`, with per-job results: `Detect stack` success, `Lint (terraform)` success, `Dependency scan (Trivy)` success, `SAST (Semgrep)` success, `Test (python)` failure, `Lint (python)` failure, `Typecheck (python)` failure, `CI status` failure, `Build (${{ matrix.stack }})` skipped. `--log-failed` yields `tools/cost-estimate.py:68: error: Incompatible types in assignment (expression has type "float", variable has type "int") [assignment]` and a single ruff error whose rule text did not appear in the log excerpt examined.
- **E41** (2026-10-27) The install fix implemented and functionally proven before any propagation. Patch adds a `uv.lock` branch to the **Typecheck** and **Test** install steps of `viavitae-template/.github/workflows/ci.yml` (40 insertions, 10 deletions); requirement-file repos keep the previous text verbatim in the `else` arm. Two design points: the dev-extra choice is made by **testing the precondition** (`tomllib` read of `project.optional-dependencies`) rather than by `uv sync … || uv sync …`, so a genuine lockfile error cannot be swallowed; and `.venv/bin` is appended to `GITHUB_PATH`, without which the later `pytest` / `mypy` steps would still resolve the runner's global copies and the fix would be inert. Proof method: the workflow's **own step text was extracted from the YAML and executed** (not retyped) in a throwaway detached worktree of `viavitae-api` at main `9b204f4`, with a local venv standing in for `actions/setup-python` — install exit **0**, `GITHUB_PATH` received the expanded `/tmp/api-ci-wt/.venv/bin`, `command -v python|mypy|pytest` all resolved **from that venv**, and pytest with the job's own flags (`--cov --cov-report=xml --cov-report=term-missing --cov-fail-under=80 --junitxml`) reported **125 passed / 5 skipped / 1 xfailed**, exit **0**, junit written. Static checks: YAML parses (8 jobs), all **24** `run:` blocks pass `bash -n`. Two earlier local attempts produced invalid results and were discarded rather than reported: first my emulation lacked a `python` alias (exit 127 `python: command not found` — an artifact of the harness, since CI's `setup-python` provides it, which is why the pre-existing `python -m pip install --upgrade pip` works there), then I accidentally escaped `$PWD` in the test, which wrote the literal string and made `command -v mypy` resolve a global binary. Non-regression evidence from CI itself: on template #5 the template's own run 40572423651 logs `detected lint=none typecheck=none test=none build=none has_source=false` and the repo contains **0** `.py` files, so its empty matrices are **correct behaviour**, proving the fix does not break the empty path; api#11 already proved the non-empty path. Pushed as `083311c` after a rebase (see E42), opened as template **PR #5**, with `CI`, `CodeQL`, `Compliance check` and `CI status` all **pass** and gate **CLEAN / MERGEABLE** — **not merged**.
- **E42** (2026-10-27) Two process errors found by verifying my own hand-off instead of trusting it. (a) **Invented repository names.** For a per-repo sweep I typed a landing-repo list from memory; six of those names do not exist (`viavitae-landing-cemetery`, `-monastery`, `-moscow-patriarchate`, `-news`, `-paris-community`, `-rusz`), and the API's HTTP 404 surfaced in my driver as *empty results*, which I was about to read as "0 tests, no install step" — a false-absence finding. The real ten, read from `orgs/Via-Vitae/repos` and matching `repos_data.tf` exactly, are `basilica`, `cathedral`, `cemetery-services`, `churches-orthodox`, `churches-other`, `churches-protestant`, `deaneries`, `diocese`, `funeral-services`, `parish-church`. Re-checking from the API also confirmed the propagation wave itself was always correct: **13 of 13** open PRs exist on real repos (landing `#6` in each of the ten, api `#11`, brand `#18`, infra `#15`). (b) **Stale local ref as a branch base.** The template worktree was created from the local clone's `origin/main`, which was stale (`9b18a73`) while real main was `a38634e7`, so PR #5 came up **BEHIND** and its diff lacked the merged `to_json` fix. Fixed by `git fetch origin` + `git rebase origin/main` (clean, my hunks do not touch line 90), then re-verified: head `083311c` with parent `a38634e`, line 90 = `to_json() { jq -cn --args '$ARGS.positional' "$@"; }`, 2 uv branches, 24 run blocks still `bash -n` clean, force-pushed with `--force-with-lease`. This is the **second** occurrence of the stale-clone trap in one session (template #4 earlier), so the pre-flight rule now is: fetch the base ref from the remote *before* creating a branch or worktree. **Editorial note:** this entry first landed malformed — I anchored a replacement on E40's heading sentence only, which glued E40's body to the end of this one. Repaired by restoring E40 above and deleting the trailing fragment. Lesson: when replacing a numbered entry in a long document, anchor on text that identifies the *boundary*, not a heading that also has to be re-emitted.
- **E43** (2026-10-27) `propagate2`: the install fix carried onto all 13 open propagation branches, and the org's first genuinely green test leg. The driver enumerated targets from the live API rather than from memory — `orgs/Via-Vitae/repos` (31) intersected with `gh pr list --head fix/ci-matrix-args --state open` — and found **13**, confirming the wave rather than assuming it. Per repo it read `ci.yml` **from the branch** (idempotent), asserted the two pre-fix install bodies occur exactly once each, replaced them with text taken verbatim from template main `682ab794`, re-parsed the YAML, ran `bash -n` over every `run:` block, and only then PUT; after each write it re-read the branch and counted the uv branches. Dry-run first: 13 targets, anchors `typecheck=1 test=1` for all, `bash_n_fail=0`, `uv_branches=2`, run blocks 24 (25 for infra, which has one extra step). Apply: **13 wrote, 13 re-read VERIFIED, 0 skipped**. Result, read per PR: `viavitae-api` #11 run 40576593101 at head `bc0e9c8e` — `Detect stack`, `Lint (python)`, `Typecheck (python)`, **`Test (python)`**, `Dependency scan (Trivy)`, `SAST (Semgrep)`, `Build (docker)` (first time it has ever executed) and the required `CI status` all **success**, gate **CLEAN**. The other **12 remain FAILURE / BLOCKED**, exactly as the corrected scope in E41 predicted, and for named reasons unrelated to the install step: the landing repos fail `Typecheck (python)` on the PyCharm scaffold (`main.py:7` missing annotation, `main.py:14` untyped call) and `Test (python)` on the template's own `No tests found … cannot meet the 80% coverage gate` warning then exit 1; infra still fails on the VV-…-022 mypy assignment error; brand fails with ten mypy errors, one ruff error and five CRITICAL dependencies (new finding VV-…-023). All 13 install hunks are **inert at runtime** for repos without a `uv.lock` — they keep the previous pip text in the `else` arm — so those 12 PRs now match the template without changing behaviour. Every PR body was annotated to say it carries **two** fixes, not one, and retitled accordingly (13/13, 0 failures), because a PR whose description understates its diff is the VV-…-014 error in miniature. Process note: one status sweep of mine returned empty strings because I embedded literal quote characters inside the `--jq` program; caught by noticing that *every* field was blank (real CI always has some value), and re-read with plain `--jq .mergeStateStatus`. Nothing merged by me.

---

# PART III — ACTION

## 27. Student action checklist

Work top-to-bottom; each item names the person who must act.

1. **Define the release** (owner): write which repos ship and the exact §16 heads.
   Until this exists, no gate can truly pass.
2. **Fix the deploy path** (infra owner): make `Deploy — viavitae-api` green and
   replace every `prod/**/placeholder.yaml` with a real manifest under Argo CD
   (VV-…-001).
3. **Build the money path** (API owner — this blocks step 4, and no payment or
   donation can work until it is done): implement Stripe/Paysera/Bitrix24
   signature verification → the `webhook_event` + `idempotency_key` ledger with
   its migration and RLS → async processing → re-reading amounts from the
   provider (VV-…-011). Note the dependency discovered on 2026-10-27: the ledger
   has nowhere to live yet, because **the repo contains zero Alembic revisions**
   — establish the migration baseline first (VV-…-016). Keep every claim about
   replay safety in the future tense until it lands, and prove each new test by
   mutation before citing it as evidence (VV-…-014).
4. **Provision isolated staging + run the journey once** (QA owner): clients merge →
   provision → Playwright smoke → sync, with synthetic data (VV-…-009).
5. **Remediate criticals and add the enforcement gate** (per-repo owners): clear the
   20 criticals on api/web/brand/docs, then wire a Dependabot-critical required check
   so detection actually blocks (VV-…-004).
6. **Populate the minimum GDPR corpus** (DPO role): ROPA, DPIA with the Art. 9
   religious-data basis, retention, vendor/Art. 28 register, policies, runbooks
   (VV-…-002, matrix §20). Decide Free-plan protection for the private repos.
7. **Strengthen separation of duties** (owner): a real second reviewer, or documented
   compensating controls before claiming SOC 2 CC1.4/CC8.1 (VV-…-003, -006).
8. **Close the config/policy mismatches** (platform owner): org SHA-pinning vs
   per-repo gate (VV-…-007); input-custody documentation (VV-…-008); decide landing
   include/exclude with evidence (VV-…-005).
9. **Obtain the blocked reads** (owner): scoped `admin:org_hook` and/or GitHub Team
   for the private repos; re-run §15/§19 (VV-…-010).
10. **Re-run gates and record the decision separately** (approver): never let the
   auditor's recommendation be read as the approval (§24/§25).

## 28. Self-audit correction log (paranoid review of this auditor's own work)

Recorded so the reader can trust the remaining conclusions and see the method
auditing itself:

1. **Dependabot "severities unreadable" was WRONG (mine, not the org's).** My first
   query read a nonexistent top-level `severity` field and got `null`, so I blamed
   the API. Correct path is `security_advisory.severity`; it returns cleanly —
   **20 critical / 63 high**. Consequence: the *Security* gate moved from
   "UNDETERMINED (provisional)" to **VERIFIED FAIL**. Lesson: re-test your own tool
   before recording a limitation.
2. **Code-scanning "wrong endpoint" was also my bug.** `/code-scanning/alerts` works;
   open counts are api 1 / web 1 / demos 1. The access-limitation row was retracted.
3. **"all six teams push on all repos" was carried from memory (2026-09-27), now
   fresh-verified** against the live API (each team → 30 repos, E16). It holds — but
   I re-tested rather than shipping an unverified recollection, per §1.1 of
   ../COMPLIANCE.md ("no `enforced-verified` without a cited live observation").
4. **`billing_email` plan abort was initially mis-scoped as a defect (VV-…-008);** on
   reading COMPLIANCE.md P1-12 it is intentional (GDPR minimisation). The finding was
   narrowed to *input custody* and downgraded.
5. **Total "~151 alerts" was an untriaged count** (it mixed all severities). The
   actionable figure is the 20-critical/63-high split now in §16/§23.
6. **My own restructuring regression, caught on final read before merge:** when I
   split the report into Method vs Findings, I dropped two required result sections
   (the Phase-8 governance/CI-CD assessment and the Phase-9 GDPR/ISO/SOC 2 readiness
   matrix) and left several internal cross-references pointing at numbers that no
   longer existed. The executive summary asserted "governance is healthy" with no
   supporting results table behind it. I restored §19 and §20, added an integration
   register + operational result (§21) and a verification register (§25), renumbered
   PART II/III cleanly, and re-pointed every reference. Lesson: a "cleaner" rewrite
   can silently delete substance — re-verify deliverable coverage, not just prose.
7. **§26 coverage arithmetic was wrong (self-caught on re-run).** The prior line
   "assessed 5 · class 11 · not-deep 15 · blocked 5" double-counted the empties and
   summed to **36**, not 31. Replaced with a mutually-exclusive partition summing to
   31 (§26). Lesson: verify a coverage table's buckets are disjoint and total the
   population.
8. **Two suspicions I raised, then disproved by reading — in the org's favour.** I
   flagged `viavitae-demos/.npmrc` as a likely token leak and treated webhook
   signature/idempotency as a possible "missing control." Verification showed the
   `.npmrc` uses `${NODE_AUTH_TOKEN}` indirection (clean) and `.env.example` holds
   only test-key placeholders. **The webhook half of this item was itself wrong and
   is retracted — see item 9.** I recorded the demos findings as VERIFIED PASS and
   scoped VV-…-011 down to the *skipped idempotency test + placeholder contract
   spec* (Medium), not a High "unprotected payments" claim. Lesson: run the check
   before writing the finding — and check the *implementation*, not the prose.
9. **My "the webhook control is real and unit-tested" conclusion was false, and the
   retraction in item 8 was the error, not a correction (found 2026-10-27 by reading
   the handler bodies in a local checkout).** All three handlers end in
   `raise ApiError("not_implemented", …, 501)` behind a `# TODO(api)` block; there is
   no signature verification, no `webhook_event` ORM model or migration, and no
   `stripe` dependency in `pyproject.toml`. Three compounding causes: (a) I read the
   module **docstrings** and a **stored working note** that repeated them instead of
   the function bodies; (b) the repo's own docs (`data-model.md`, the replay runbook,
   `replay_webhook.py`) make the same present-tense claim, so the code appeared to
   corroborate itself; (c) the green guard tests looked like evidence of a working
   control, but a **mutation proved otherwise** — replacing the 501 with
   `return {"status": "received"}` still passed 9/9, because every request died at
   the earlier 503 "secret unconfigured" guard and no test reached the stub branch.
   Consequences: VV-…-011 re-scoped (Medium → **High**, it is a missing control and
   an unimplemented money path, not test quality), §17/§18/§21/E19 corrected, and
   VV-…-014 opened for the false-assurance defect itself. Lesson for students: a
   test that passes when you delete the control is not evidence the control exists;
   **mutation-test your own evidence before you cite it**, and never accept a
   docstring, a runbook or your own earlier note as a substitute for reading the
   implementation.
10. **Two errors in my own remediation round, both caught by re-testing rather than
   trusting my first pass (2026-10-27).** (a) After fixing the webhook claims I wrote
   into §23 that the defect lived in "eight places" and that the fix left "no
   unqualified claim" standing — while `docs/data-model.md` and
   `docs/DPIA-004-donations.md` were still unedited and my change set was 12 files,
   not the 14 the acceptance required. The count had been typed from recollection of
   the edits I made, not from a sweep of the repo. Re-running the enumeration first
   (`grep -rn -i 'idempoten|ADR-005'` across `app`, `docs`, `scripts`, `tests`,
   `QODER.md`) produced the real set and exposed the DPIA as the most serious site,
   because its Art. 36 conclusion depends on the missing control. Lesson: derive a
   count from a command, never from memory of the work, and re-run the discovery
   query *after* the fix to prove completeness. (b) In the hand-off I asserted that
   `viavitae-api` "requires the standalone `ai:<tier>` provenance trailer, PR-only
   merge" — true of `viavitae-control`, false of `viavitae-api`, which has no
   `.pre-commit-config.yaml`, no installed `commit-msg` hook and no `provenance.yml`.
   Chasing that discrepancy to ground produced VV-…-015 (provenance enforced in 1 of
   31 repos). Lesson: a policy written in one repo does not travel; verify the
   enforcement artifact exists in the repo you are actually standing in, and treat
   your own hand-off text as a claim to be tested, not a fact to be reused.
11. **Reviewing my own diff found an inconsistency I had introduced one round earlier
    (2026-10-27).** I annotated DPIA-004's **M2** row as "not implemented" and left
    **M1, M3 and M4** untouched in the same table — a half-applied correction that
    would itself read as assurance. Verifying each row against the code produced
    three new facts: M1 cites row-level security that cannot exist because
    `migrations/versions/` holds only `.gitkeep` (**zero revisions** → VV-…-016);
    M4 cites `app/workers/retention_worker.py`, which is **absent**; M3's substance
    is real but names the wrong tool (CI runs **Semgrep + Trivy**, not bandit). Two
    process lessons: (a) when fixing a claim, enumerate the *whole* artifact, not the
    sentence that happened to be quoted at you — a partial correction can be worse
    than none because it lends credibility to the untouched rows; (b) three of my
    probe sections returned **empty output**, which in this workspace is never
    evidence of absence — re-probing with explicit PRESENT/ABSENT markers is what
    produced the finding. Also recorded positively: `deployments/k6/smoke.js` is
    honest about the 501 scaffolds, so the org's own test design was better than the
    documentation around it.
12. **The count I criticized myself for inventing was still in the register two drafts
    later (caught on the third pass, 2026-10-27).** Item 10(a) records that I typed
    "eight places" from memory; I then "corrected" it to "14 files / 18 claim
    strings", which was *also* a remembered number, not a measured one — and it went
    into §23 twice before anyone tested it. The reproducible measure is hunk count
    (`git diff --unified=0 | grep -c '^@@'` = 39 hunks, 14 files, of which 5 are the
    generated OpenAPI snapshot and 6 the new test file → 28 claim-rewording hunks),
    now recorded as E25. Lesson: fixing a fabricated number by recollection just
    relocates the error — replace the number with the command that produces it, so
    the next reader can re-derive it instead of trusting me.
13. **Three defects in the hand-off I wrote last round, each caught by testing the
    instruction instead of repeating it (2026-10-27).** (a) I told the owner to
    "merge the open Dependabot PRs on `viavitae-api`" — `gh pr list --state open`
    filtered to dependabot returns **zero**; the eight criticals need hand-authored
    bumps, so my instruction was unexecutable. (b) I said to then "`gh run rerun` #9's
    CI" — wrong mechanism twice over: a rerun replays the original `pull_request`
    payload, and with `strict` required checks the branch must first be brought up to
    date with `main`, so the correct action is `gh pr update-branch` (or a new push).
    (c) My *first* local proof of the `to_json` bug was itself broken — I wrapped the
    jq filter in double quotes so the shell expanded `$ARGS` and bash failed with
    "unbound variable", which I nearly read as a pass. Rewritten as a file with the
    filter single-quoted, it reproduced `[]` vs `["python"]` correctly (E27). A related
    mislabel I also corrected in-place: a `|| echo READ_DENIED` fallback printed
    "permission denied" where GitHub had actually said "This repository is empty" —
    the same derived-column-vs-measured-value error logged in item 5. Lesson:
    an instruction in a hand-off is a claim; run it or its cheap equivalent before
    writing it down.
14. **A wrong security conclusion of mine, corrected by a red pipeline rather than by
    reasoning (2026-10-27).** I wrote in E30 and VV-…-018 that all 8 api CRITICALs were
    "lockfile-only" because the `pdf` extra is not installed. The claim was over-
    generalised from a correct partial observation: 7 of 8 were in that uninstalled tree,
    but the 8th — certifi — arrives through `httpx`, which the image **does** install, so
    a compromised-root-CA finding was genuinely shipped. What caught it was empirical
    feedback: after pushing the bump, Trivy still exited 1 with `Total: 1 (CRITICAL: 1)`
    and named the package. Had I merged on my reasoning, the gate would have gone green
    later with a live finding re-opened. Two lessons: (a) a reachability conclusion
    applies to the packages you actually inspected, not to the group they were counted
    in; (b) verify by the gate's own verdict, not by the argument that predicted it —
    the same rule that made me re-run `find_spec` per package instead of per extra.
15. **Merging my own PRs made this register stale in three places within minutes, and I
    fixed it in the same session (2026-10-27).** The `Status:` cells written before the
    merge said "not committed, not pushed" and later "pushed, not merged"; after the
    owner directed the merges they became wrong a third time, and §16's per-repo alert
    column plus the Security gate basis still carried pre-merge counts. Corrected against
    live reads (E34), not against my memory of what I had just done. Two lessons: a status
    line is a claim with an expiry date, so re-read it after every state change; and the
    merge that *clears* a blocker is not the same event as the merge that *proves* a
    fix — api's `Test` legs still skip until VV-…-017 is propagated, so the pin test from
    PR #9 is locally proven but CI-unenforced, and calling it "verified in CI" would have
    been exactly the error this whole session exists to remove.
16. **I recorded a queued run as a failure, and corrected it the same day (2026-10-27).**
    In E37 I wrote that `viavitae-infra`'s four `Plan` jobs "also fail" with the cause
    undetermined. They were not failing: run 40563311046 is the **Deploy** workflow, its
    status was `queued`, and those jobs had **no conclusion field at all** — never
    started. I had read an empty conclusion as a verdict. The fix was to name the
    workflow and read `status` before `conclusion`, which then produced the correct
    target (CI run 40563310740) and a real new finding, VV-…-022: a genuine mypy
    assignment error in `tools/cost-estimate.py:68` that had been invisible for twelve
    days because the matrix legs never ran. Lesson: a blank status field is absence of
    evidence, not evidence of failure — the same discipline that makes an empty command
    output untrustworthy applies to job and check records.

17. **I invented six repository names, and the API's silence nearly became a finding (2026-10-27).**
    Writing a per-repo sweep from memory, I listed landing repos including
    `viavitae-landing-cemetery`, `-monastery`, `-moscow-patriarchate`, `-news`,
    `-paris-community` and `-rusz`. None exist. My driver swallowed the HTTP 404s into
    empty results, so the table read "0 tests, no install step" for six repos — which is
    exactly how a false absence becomes a false finding. Caught by noticing that "no
    install step" contradicted the byte-identical `to_json` line I had verified across all
    13 files a day earlier; probing one repo directly returned
    `Could not resolve to a Repository`, and `orgs/Via-Vitae/repos` gave the real names
    (E42). The same check confirmed the propagation wave was always correct — 13 of 13 PRs
    on real repos. In the same round a stale local `origin/main` (`9b18a73` vs live
    `a38634e7`) made my new template branch `BEHIND` for the second time in this session.
    Lessons: enumerate targets from the API or from `repos_data.tf`, never from recall;
    treat a 404 as *unknown*, not as *empty*, so a driver must distinguish "no rows" from
    "request failed"; and fetch the base ref from the remote before branching.

None of these corrections changed the NO-GO recommendation — it is still NO-GO,
after the 2026-10-27 corrections with **two more** failed mandatory gates than the
original draft reported (Integration and Functionality were added, §24). Items 1–2 made the report *more* strict; items 7–8 made it *more*
accurate — one finding upgraded (docs exposure, VV-…-012) and one instinct downgraded
(webhooks) on evidence, which is the correct direction for a compliance gate.
**Item 9 then reversed that downgrade**: the webhook finding went back up to High
when the implementation was actually read, and a new High finding (-014) was opened
for the false assurance this report had itself published. A finding is only as
trustworthy as the deepest artifact the auditor read.

## 29. Glossary (student quick-reference)

| Term | Plain-language meaning |
| --- | --- |
| **Audit reference date** | The fixed day the conclusions describe (here 2026-10-26). Anything after it is "later evidence", never backdated. |
| **Head / commit identifier** | A fingerprint (e.g. `ca465637`) of one exact version of a repo. Findings must say which fingerprint they describe. |
| **Live / declared / in-state** | What GitHub holds / what the Terraform source-of-truth file says / what Terraform currently manages. They must agree. |
| **Shadow repo / ghost** | A repo that exists but isn't declared / is declared but doesn't exist. Both are inventory defects. |
| **Trust boundary** | Where data crosses between components with different trust (browser→server, service→third party, build→production). |
| **Authentication / authorization** | Proving who you are / deciding what you may do. Both must be enforced **server-side**. |
| **Personal data / special-category (Art. 9)** | Anything identifying a person / the high-risk subset (religion, health…) needing stronger legal grounds. |
| **Lawful basis** | The legal permission to process data. Consent is only one of six — don't assume it. |
| **Controller / processor** | Who decides why/how data is used / who processes it on their behalf. |
| **DPIA / ROPA** | Data Protection Impact Assessment / Record Of Processing activities — core GDPR documents (Art. 35 / Art. 30). |
| **ISMS / SOA** | The org's whole security-management method (ISO 27001) / its Statement of Applicability listing claimed controls. |
| **SOC 2 / QSA** | An attestation by an **independent** practitioner over an evidence period / the licensed auditor who issues it. An internal review is neither. |
| **Branch protection / ruleset** | Server rules that block unsafe merges; a ruleset is the newer, scriptable form. |
| **Required status check** | A CI job that must pass before merge. If nothing emits it, merges freeze; if it isn't wired to block, it's advisory only. |
| **SHA pinning** | Locking a third-party CI action to an exact immutable version, so it can't be silently swapped. |
| **Detection vs enforcement** | An alert turning red (detection) only protects you if something also *stops* the bad action (enforcement). |
| **Dependabot / code-scanning alert** | A flagged vulnerable dependency / a flagged code flaw (CodeQL). Counts ≠ exploitability; triage reachability. |
| **RPO / RTO** | Max acceptable data loss / max acceptable downtime. Must be defined, then proven by a restore test. |
| **Idempotency** | Doing the same operation twice must not double the effect (no second charge, no duplicate email). |
| **Severity / confidence / priority** | How bad / how sure / when to fix. Kept separate on purpose. |
| **GO-WITH-CONDITIONS / NO-GO / UNDETERMINED** | Passed gates with tracked residual risk / a mandatory gate failed / not enough evidence to decide. |
| **BLOCKED vs NOT RUN** | Couldn't be examined for a named reason / simply hasn't been examined yet. Neither means "passed". |
