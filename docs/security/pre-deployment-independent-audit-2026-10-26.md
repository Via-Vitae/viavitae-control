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
- **Four mandatory release gates FAIL outright:**
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
- **Undecided (insufficient evidence):** Scope-of-release, Functionality,
  Integration and Evidence gates — no end-to-end journey on provisioned staging
  (§21), and 15 repos not yet deep-audited (§26).
- **Independence is structurally pending:** a single person is implementer, approver
  and would-be verifier; six teams each hold blanket push on all 30 repos
  (fresh-verified, E16, VV-2026-10-003).
- **Recommendation: NO-GO**, revisable only by the ordered remediation in §27 and
  then a separately-recorded approval. This audit wrote no code and changed no
  control; the auditor's own first-draft errors are logged in §28.

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
| 1 | .github | pub | 16 | 49cba333 | meta | NOT RUN | 0/0 |
| 2 | viavitae-control | pub | 73 | 7c9a1980 | control | ASSESSED (this doc) | 0/0 |
| 3 | viavitae-compliance | **priv** | **EMPTY** | — | control | BLOCKED (empty + 403) | n/a |
| 4 | viavitae-data-governance | **priv** | **EMPTY** | — | control | BLOCKED | n/a |
| 5 | viavitae-policies | **priv** | **EMPTY** | — | control | BLOCKED | n/a |
| 6 | viavitae-threat-model | **priv** | **EMPTY** | — | control | BLOCKED | n/a |
| 7 | viavitae-vendor-register | **priv** | **EMPTY** | — | control | BLOCKED | n/a |
| 8 | viavitae-training | pub | **EMPTY** | — | control | NOT RUN (nothing readable) | 0/0 |
| 9 | viavitae-docs | pub | 181 | db67d1c3 | control | NOT RUN | **2/3** |
| 10 | viavitae-infra | pub | 263 | a4145b54 | platform | ASSESSED — prod placeholders (E7) | 0/0 |
| 11 | viavitae-observability | pub | **EMPTY** | — | platform | emptiness **is** the finding | 0/0 |
| 12 | viavitae-runbooks | pub | **EMPTY** | — | platform | same | 0/0 |
| 13 | viavitae-reusable-workflows | pub | **EMPTY** | — | platform | same | 0/0 |
| 14 | viavitae-template | pub | 18 | 9b18a736 | platform | CLASS-VERIFIED (parent of landings, E9) | 0/0 |
| 15 | viavitae-qa | pub | 118 | 2d670ecc | platform | PARTIAL — gates can't run (VV-…-009) | 0/5 |
| 16 | viavitae-api | pub | 156 | 63cb4943 | app | ASSESSED (deploy red) | **8/23** |
| 17 | viavitae-clients | pub | 86 | 3a9db5f8 | app | PARTIAL | 0/0 |
| 18 | viavitae-web | pub | 195 | ca465637 | app | ASSESSED | **5/9** |
| 19 | viavitae-brand | pub | 63 | f1555f9d | app | NOT RUN | **5/23** |
| 20 | viavitae-demos | pub | 228 | 1ec6e2fd | app | NOT RUN | 0/0 |
| 21 | viavitae-hermes-agents | pub | 72 | 0e35dccd | app | NOT RUN | 0/0 |
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
release candidates. Code-scanning open alerts (E15): api 1, web 1, demos 1,
clients/brand/qa 0.

## 17. Architecture and data flows (Phase 3 result)

**What Via-Vitae actually is** (from repository evidence, not its name): a
commercial IT company operating an EU pilot **in Lithuania** — church-vertical
websites, e-commerce and a marketplace, self-hosted on **Proxmox** with **k3s +
Argo CD (GitOps)**; personal data claimed to stay in the EEA. (E5, E6)

Verified components: **viavitae-api** (FastAPI/Python 3.12; multi-tenant Postgres
with per-tenant schemas + row-level security; Alembic; Bitrix24 on-prem CRM;
**Stripe + Paysera** payment webhooks; a **RAG pastoral AI assistant**; GIS
cemetery mapping; donations). **viavitae-web** (Next.js 15/React 19, next-intl
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
(religious) data**; lawful basis is UNDETERMINABLE with no DPIA. RAG tool
permissions and webhook signature/origin checks were NOT RUN.

## 18. Baseline and test-evidence register (Phase 4 result)

| Repo @head | Build/tests defined? | Observed result this pass | Status |
| --- | --- | --- | --- |
| viavitae-web @ca465637 | Yes — lint, typecheck, unit+contract, e2e, a11y, lighthouse | Scheduled CI on `main` green 2026-10-26; one Dependabot PR `Lint` red 2026-10-26T04:19Z | VERIFIED PASS (main), VERIFIED FAIL (open PR #51 lint) |
| viavitae-api @63cb4943 | Yes — pytest, nightly E2E | Nightly E2E green 2026-10-26; **`Deploy` push run red** (E12) | Mixed: tests PASS, deploy FAIL |
| viavitae-clients @3a9db5f8 | Yes — CI + provision-dispatch | CI green; dispatch journey never observed end-to-end | Tests PASS, integration UNDETERMINED |
| viavitae-qa @2d670ecc | Yes — Playwright @smoke, axe, Trivy | Gates "cannot run — staging not provisioned" (register P1-22) | BLOCKED (environment) |

Blocked/unexecuted checks register: browser/load E2E (staging), webhook signature
verification, RAG tool-permission tests, per-repo deep dives for 15 repos — all
**NOT RUN**, not **PASSED**.

## 19. GitHub, CI/CD and infrastructure assessment (Phase 8 result)

**VERIFIED PASS (observed 2026-10-26):**
- Org-wide 2FA enforced (`two_factor_requirement_enabled: true`). (E11)
- All 26 public repos: secret scanning + push protection enabled. (E10)
- 21 branches carry classic branch protection with **strict** up-to-date
  enforcement and **admin enforcement**; no force pushes; `viavitae-control`
  protected by the `protect-main` ruleset. (E10)
- Org Actions restricted to a selected allow-list; provenance gate wired
  (`ai:<tier>` trailer enforced by a commit-msg hook + `provenance.yml`). (E11)
- `main` CI health: web/clients/qa and scheduled compliance/CodeQL green through
  the reference morning; control-plane `Audit` + `provenance` green since
  2026-10-21. (E12)
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
- Webhook inventory unobtainable (no `admin:org_hook` scope) — NOT RUN.

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
| Access control & segregation of duties | ISO A.5.15–5.18 / SOC2 CC6 | Owner | role-scoped permissions | blanket team push; 2FA on | PARTIAL (VV-…-003) |
| Change control & release evidence | SOC2 CC8 | Platform | gated PRs + branch protection | enforced on public repos | VERIFIED PASS (public only) |
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
| clients → api | `provision-dispatch.yml` → `POST /v1/tenants/<slug>/provision` | dispatch token | tenant config | idempotency unverified | NOT RUN (UNDETERMINED) |
| api → Stripe / Paysera | payment webhooks/callbacks | API keys + signatures | payment events | signature/origin check NOT RUN | BLOCKED |
| api → Bitrix24 (on-prem CRM) | REST | creds | CRM records | creds expiry path unknown | NOT RUN |
| api → Postgres | per-tenant schema + RLS | service creds | all tenant PII | cross-tenant isolation asserted in code, not tested | NOT RUN |
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

**Deep-audit gaps (honest non-coverage):** full Phase-5 eight-dimension reviews for
`.github`, `viavitae-docs`, `viavitae-brand`, `viavitae-demos`,
`viavitae-hermes-agents`, `viavitae-training`, and the private set remain **NOT
RUN**; `viavitae-web/api/clients/infra/control` were assessed; landings + template
were class-assessed. These are scheduled work, not silent skips.

## 23. Findings register (Phase 11 result)

Severity, confidence and priority are tracked separately.

| ID | Title | Class | Severity / Confidence | Owner | Remediation (plain language) & acceptance |
| --- | --- | --- | --- | --- | --- |
| VV-2026-10-001 | Production deploy path non-functional; all prod k8s manifests are `placeholder.yaml` | Confirmed | **High** / High | Infra owner | Repair the image build/push failure; replace each placeholder with real reviewed Argo CD manifests; acceptance = successful prod-candidate deploy of the exact release commit through dev→staging→prod with recorded run links; independent re-run required. |
| VV-2026-10-002 | Compliance & operations artifact repos empty while product code cites them (DPIA-001 et al.) | Confirmed | **High** (compliance blocker; not exploitable) / High | DPO/compliance role (same human today) | Populate ROPA, DPIA (incl. Art. 9 basis), retention schedule, policy library, vendor register with Art. 28 terms, runbooks, training records; acceptance = every cited ID resolves to a real document; decide the Free-plan protection limitation for the private repos (upgrade, or accept the unprotected-population risk explicitly). |
| VV-2026-10-003 | Single-person org: owner = implementer = approver; all six teams hold blanket push on all 30 repos (no tier scoping, so tier-based CODEOWNERS cannot segregate) | Confirmed governance gap | **High** for SOC 2 CC-series / High (fresh-verified E16) | Owner | Establish the largest feasible separation of duties (active peer-reviewer account, or documented compensating controls + independent-assurance engagement); scope team bindings to tiers; acceptance = team permissions match tier policy and the review chain is demonstrably enforced. |
| VV-2026-10-004 | **20 critical + 63 high** open Dependabot alerts on default branches, concentrated in release candidates (api 8/23, brand 5/23, web 5/9, docs 2/3, qa 0/5 — E15). GitHub alerts are *detected* (Dependabot updates on) but **no required status check blocks merge/deploy on critical**, so detection is not enforced | Confirmed, **severity-ranked** | **High** / High | Per-repo owners | Triage by reachability on `main`; remediate criticals on api/web/clients/brand before release; add a Dependabot-critical gate (fail CI when `main` carries critical/high on reachable deps) wired into the ruleset so detection becomes enforcement; acceptance = fresh zero-critical snapshot dated against the release commit + a green blocking check. |
| VV-2026-10-005 | Ten landing repos are scaffolds; release inclusion undecided | Confirmed + decision request | **Medium** / High | Owner | Decide exclude-vs-include per landing page. Exclusion must be evidenced (no deploy target, no domain, no indexing); inclusion requires content, privacy notice, form destination, consent behavior and accessibility verification. |
| VV-2026-10-006 | Sole reviewer `IterVitae` recorded "inactive, admin invite pending" yet absent from live outside-collaborators | Evidence gap / suspected access anomaly | **Medium** / Low — needs confirmation | Owner | Produce the access-review record: current role, membership, review capability of that account; acceptance = API-visible membership matching documented policy. |
| VV-2026-10-007 | Org-level SHA pinning disabled (`sha_pinning_required=false`) while repos rely on a per-repo "Action SHA pinning" check | Confirmed policy/config mismatch | Medium / High | Platform owner | Either require pinning at the org ruleset or formally document the per-repo gate as the compensating control; acceptance = configuration and policy agree. |
| VV-2026-10-008 | Applied-input custody unverifiable: fresh plan aborts on missing required `billing_email`; the tfvars used for the 2026-10-17 apply is not in this workspace and its storage location is not evidenced | Confirmed, **scoped down after cross-check** | Low–Medium / High | Infra owner | The abort is **by design and documented** (../COMPLIANCE.md P1-12: `TF_VAR_billing_email` has no default for GDPR minimisation) — the residual gap is *custody*: record where the applied value lives and how it is protected/restored; acceptance = the custody path is exercised once and a clean-checkout plan procedure is reproduced. |
| VV-2026-10-009 | QA browser/load gates cannot run — staging tenant not provisioned (register P1-22, still open) | Confirmed | **High** for integration gate / High | QA owner | Provision isolated staging + synthetic data; run the full cross-repo journey (clients merge → provision → staging smoke → sync); acceptance = dated E2E evidence covering the exact release version combination. |
| VV-2026-10-010 | Org webhook inventory and private-repo protections unobtainable | BLOCKED | — | Owner | Grant scoped read (`admin:org_hook`) and/or GitHub Team for private-repo visibility; re-run the blocked cells of §15/§19. |

**Risk acceptance** is tracked separately from these check results; none has been
accepted, waived or closed by this document.

## 24. Release gates and decision (Phase 13 result)

| Gate | Result | Basis |
| --- | --- | --- |
| 1 Scope | FAIL / UNDETERMINED | Org reconciled 31/31, but release contents never named |
| 2 Evidence | UNDETERMINED | 15 repos not deep-audited; blocked cells above |
| 3 Functionality | UNDETERMINED | No cross-repo E2E evidence on provisioned staging (VV-…-009) |
| 4 Security | **VERIFIED FAIL** | 20 critical + 63 high open on default branches incl. release candidates (VV-…-004); detection not wired to enforcement |
| 5 Privacy | **FAIL** | Art. 28/30 corpus absent while collection runs in code (§20, VV-…-002) |
| 6 Integration | UNDETERMINED | Provisioning journey unverified (§21, VV-…-009) |
| 7 Operations | **VERIFIED FAIL** | Deploy red; prod manifests placeholder; no RPO/RTO; empty runbooks (§21, VV-…-001) |
| 8 Landing scope | **FAIL** | Unfinished and undocumented either way (§22, VV-…-005) |
| 9 Independence | NOT SATISFIED | Self-review only (VV-…-003/-006) |
| 10 Approval | n/a | This report is a recommendation, not a decision |

**Recommendation: NO-GO.** Four mandatory gates fail outright (Security, Privacy,
Operations, Landing scope); several others cannot be decided on available evidence.
Remediation to make a decision possible: (a) written release definition — repos +
exact heads from §16; (b) fix VV-…-001 and -009 so journey evidence becomes
producible; (c) remediate the 20 criticals and add the Dependabot enforcement gate
(VV-…-004); (d) populate the minimum GDPR corpus (VV-…-002); (e) resolve the
access-review gap (VV-…-006); (f) re-run gates and record the decision separately.

**Recommendation ≠ approval.** The authorized decision-maker (today, the same sole
owner) must record any GO/GO-WITH-CONDITIONS decision separately, with residual
risks, named approver, compensating controls and expiry. GO WITH CONDITIONS must
not mask a failed mandatory gate; risk acceptance does not override legal obligations.

## 25. Verification register (Phase 12)

No org-side remediation has been submitted for verification yet; every finding
below is at **fix proposed = no**, because the audit was performed against the
current state and remediation has not begun. Self-corrections of the *audit
document itself* are logged separately in §28 and are not org fixes.

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

## 26. Coverage statement and evidence index

Discovered **31** · reconciled **31** · accessible **26** (5 private, restricted
reads) · with content **22** · empty **9** · assessed in depth **5** (control, web,
api, infra, landing class via diocese+template) · class-assessed **11** · not yet
deep-audited **15** · blocked **5**. Dependabot: **20 crit / 63 high** open;
code-scanning: 3 open (api/web/demos). Exclusions from any completeness claim:
private-repo blind spot, `admin:org_hook` scope, and the 15 NOT-RUN deep dives.

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

---

# PART III — ACTION

## 27. Student action checklist

Work top-to-bottom; each item names the person who must act.

1. **Define the release** (owner): write which repos ship and the exact §16 heads.
   Until this exists, no gate can truly pass.
2. **Fix the deploy path** (infra owner): make `Deploy — viavitae-api` green and
   replace every `prod/**/placeholder.yaml` with a real manifest under Argo CD
   (VV-…-001).
3. **Provision isolated staging + run the journey once** (QA owner): clients merge →
   provision → Playwright smoke → sync, with synthetic data (VV-…-009).
4. **Remediate criticals and add the enforcement gate** (per-repo owners): clear the
   20 criticals on api/web/brand/docs, then wire a Dependabot-critical required check
   so detection actually blocks (VV-…-004).
5. **Populate the minimum GDPR corpus** (DPO role): ROPA, DPIA with the Art. 9
   religious-data basis, retention, vendor/Art. 28 register, policies, runbooks
   (VV-…-002, matrix §20). Decide Free-plan protection for the private repos.
6. **Strengthen separation of duties** (owner): a real second reviewer, or documented
   compensating controls before claiming SOC 2 CC1.4/CC8.1 (VV-…-003, -006).
7. **Close the config/policy mismatches** (platform owner): org SHA-pinning vs
   per-repo gate (VV-…-007); input-custody documentation (VV-…-008); decide landing
   include/exclude with evidence (VV-…-005).
8. **Obtain the blocked reads** (owner): scoped `admin:org_hook` and/or GitHub Team
   for the private repos; re-run §15/§19 (VV-…-010).
9. **Re-run gates and record the decision separately** (approver): never let the
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

None of these corrections changed the NO-GO recommendation; they made the report
*more* strict and *more* complete, which is the correct direction for a compliance
gate.

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
