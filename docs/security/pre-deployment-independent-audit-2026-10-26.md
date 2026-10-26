---
title: "Via-Vitae Pre-Deployment Independent Audit — Working Report"
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

# Via-Vitae Pre-Deployment Independent Audit — Working Report (2026-10-26)

> **Auditor's recommendation: NO-GO for the proposed release as currently evidenced.**
> This is a recommendation only. It is not an approval, not a SOC 2 report, not a
> certification, and it does not authorize any deployment, merge or configuration
> change. All examination was read-only; nothing in this session modified code,
> infrastructure, permissions or live resources.

---

## 1. Executive summary

- **Inventory reconciled: 31 live = 31 declared, 0 shadow, 0 ghost.** The expected
  count of 31 was verified against the live organization API (private included),
  not adopted. State and local clones are consistent with the declared inventory.
- **The GitHub governance layer is materially healthier than the 2026-09-27
  baseline:** org 2FA enforced; the 20-protection downgrade danger is closed
  (apply landed 2026-10-17; state serial 143 holds 31 repos + 21 branch
  protections + the `protect-main` ruleset); secret scanning and push protection
  on all 26 public repos; scheduled and push CI green on `main` of the main
  application repos as at the reference date.
- **Three independent blockers prevent a defensible GO:**
  1. **No working production deployment path.** `Deploy — viavitae-api` last ran
     red on push to `main` (2026-10-15, failed step "Build and push image");
     every production Kubernetes manifest in `viavitae-infra` is a literal
     `placeholder.yaml`. Operational gate: VERIFIED FAIL (VV-2026-10-001).
  2. **Nine of 31 repositories are empty, including every compliance-artifact
     repository** (`viavitae-policies`, `-compliance`, `-data-governance`,
     `-threat-model`, `-vendor-register`) and every operations repository
     (`viavitae-runbooks`, `-observability`, `-reusable-workflows`, `-training`).
     Application code cites controls (e.g. "DPIA-001 R7" consent recording) whose
     governing documents do not exist. Privacy/ISO/SOC 2 evidence gates: BLOCKED
     (VV-2026-10-002).
  3. **Release contents are undefined.** The brief names no release set; the ten
     `viavitae-landing-*` repositories are verifiably template scaffolds, matching
     the user-provided constraint that they are "not yet fully completed"
     (VV-2026-10-005). Scope gate: UNDETERMINED.
- **Secondary, material:** ~151 open Dependabot alerts concentrated in the release
  candidates with severities not readable from the register view
  (VV-2026-10-004); the sole reviewer account's access status changed unexplained
  (VV-2026-10-006); the control plane is not reproducibly plannable from a clean
  checkout (VV-2026-10-008); QA staging gates cannot run (VV-2026-10-009).
- A completed audit may legitimately produce a NO-GO. Examination was performed
  and limitations are disclosed below — nothing was silently skipped.

---

## 2. Charter, responsibilities, independence (Phase 1)

| Responsibility | Incumbent at reference date | Status |
| --- | --- | --- |
| Audit scope & coordination | `JourneyOfLife` — sole human org member, owner role | VERIFIED (E11) |
| Security & privacy decisions, remediation, risk acceptance, release approval | Same single person | VERIFIED — and itself finding VV-2026-10-003 |
| Independent verification | None identified (see VV-2026-10-006) | **UNASSIGNED** |
| External assurance (SOC 2 Type II / ISO 27001 certification) | No QSA/auditor engaged | PENDING |

**Independence statement.** The reviewer is an AI audit lead operating with
tooling and evidence partly produced by the owner under assessment. A second AI
pass would add perspective but would **not** establish organizational
independence. Every "independent verification" requirement below is therefore
recorded as PENDING, not satisfied.

**Execution boundary.** Authorized inspection only: read-only GitHub API sweeps,
working-copy inspection, one read-only `terraform plan`. No code, scripts,
workflows, infrastructure configuration, migrations, permissions or live
resources were created or modified by this audit; this document is the sole
artifact, created at the owner's explicit request.

**Access limitations (each blocks a named conclusion):**

| Limitation | Conclusion it blocks |
| --- | --- |
| Token lacks `admin:org_hook` scope | Org webhook inventory — unknown, not assumed empty |
| GitHub Free plan: private-repo ruleset/advanced-security reads return HTTP 403; branch protection requires Team+ | Protection posture of the 5 private repos — BLOCKED |
| Dependabot alert `severity` returned `null` in register view | Vulnerability prioritization — alerts counted, not ranked |
| Code-scanning alert sweep used a wrong endpoint path (tool defect) | SARIF/alert counts per repo — NOT RUN, re-run required |

---

## 3. Inventory reconciliation (Phase 2)

**Plain-language:** *live* = what GitHub actually holds; *declared* = the
`repos_data.tf` source-of-truth map in `viavitae-control`; *in state* = what the
applied Terraform state manages. All three must agree before anything else is
concluded.

| Plane | Count | Evidence |
| --- | --- | --- |
| Live (org API, paginated, incl. private) | **31** | E1 |
| Declared (`repos_data.tf`) | **31** | E2 |
| Live-not-declared / declared-not-live | **0 / 0** — no shadow repos, no ghosts | E1+E2 |
| In state | 31 `github_repository`, 21 `github_branch_protection`, 1 `github_repository_ruleset`, 26 dependabot-update, org resources; serial **143**, Terraform 1.16.1 | E3 |
| Local working copies (`/opt/viavitae/repos`) | 30 org clones + `viavitae-control`; September's three non-org strays gone; heads clean and matching live for web/api/clients | E4 |
| Org membership | 1 human (`JourneyOfLife`), 6 teams (architects, compliance, dpo, legal, platform, security), **0 readable outside collaborators** | E11 |
| Count history | 30 (2026-09-27 audit) → 31 now; growth driven by landing-class/template additions since September | E1 |

**Repository coverage matrix.** One row per repository; *head* = the exact commit
fingerprint the conclusions below concern, captured 2026-10-26 UTC.

| # | Repository | Visibility | Content | Head | Tier | Deep audit status this pass |
| --- | --- | --- | --- | --- | --- | --- |
| 1 | .github | public | 16 files | 49cba333 | meta | NOT RUN |
| 2 | viavitae-control | public | 73 | 7c9a1980 | control | ASSESSED (this document) |
| 3 | viavitae-compliance | **private** | **EMPTY** | — | control | BLOCKED (empty + Free-plan 403) |
| 4 | viavitae-data-governance | **private** | **EMPTY** | — | control | BLOCKED |
| 5 | viavitae-policies | **private** | **EMPTY** | — | control | BLOCKED |
| 6 | viavitae-threat-model | **private** | **EMPTY** | — | control | BLOCKED |
| 7 | viavitae-vendor-register | **private** | **EMPTY** | — | control | BLOCKED |
| 8 | viavitae-training | public | **EMPTY** | — | control | NOT RUN (nothing readable) |
| 9 | viavitae-docs | public | 181 | db67d1c3 | control | NOT RUN (12 open alerts) |
| 10 | viavitae-infra | public | 263 | a4145b54 | platform | ASSESSED — prod manifests placeholder (E7) |
| 11 | viavitae-observability | public | **EMPTY** | — | platform | emptiness is the finding (VV-2026-10-002); NOT APPLICABLE — **rejected** |
| 12 | viavitae-runbooks | public | **EMPTY** | — | platform | same |
| 13 | viavitae-reusable-workflows | public | **EMPTY** | — | platform | same |
| 14 | viavitae-template | public | 18 | 9b18a736 | platform | CLASS-VERIFIED (parent of landings, E9) |
| 15 | viavitae-qa | public | 118 | 2d670ecc | platform | PARTIAL — gates cannot run (VV-2026-10-009) |
| 16 | viavitae-api | public | 156 | 63cb4943 | app | ASSESSED (deploy red; 45 alerts) |
| 17 | viavitae-clients | public | 86 | 3a9db5f8 | app | PARTIAL |
| 18 | viavitae-web | public | 195 | ca465637 | app | ASSESSED |
| 19 | viavitae-brand | public | 63 | f1555f9d | app | NOT RUN (41 alerts) |
| 20 | viavitae-demos | public | 228 | 1ec6e2fd | app | NOT RUN |
| 21 | viavitae-hermes-agents | public | 72 | 0e35dccd | app | NOT RUN |
| 22 | viavitae-landing-basilica | public | 19 | 392760d3 | site | CLASS-ASSESSED — scaffold (§6) |
| 23 | viavitae-landing-cathedral | public | 19 | 526dc9cc | site | CLASS-ASSESSED |
| 24 | viavitae-landing-cemetery-services | public | 19 | 85a65368 | site | CLASS-ASSESSED |
| 25 | viavitae-landing-churches-orthodox | public | 19 | 030cc2d6 | site | CLASS-ASSESSED |
| 26 | viavitae-landing-churches-other | public | 19 | c25fed9d | site | CLASS-ASSESSED |
| 27 | viavitae-landing-churches-protestant | public | 19 | 4d785908 | site | CLASS-ASSESSED |
| 28 | viavitae-landing-deaneries | public | 19 | 04e8c1ce | site | CLASS-ASSESSED |
| 29 | viavitae-landing-diocese | public | 19 | ba861678 | site | CLASS-ASSESSED + individually inspected (E9) |
| 30 | viavitae-landing-funeral-services | public | 19 | 9917bd39 | site | CLASS-ASSESSED |
| 31 | viavitae-landing-parish-church | public | 19 | 1e2a7dc2 | site | CLASS-ASSESSED |

Exactly ten repositories match `viavitae-landing-*` — all listed above.

---

## 4. Architecture and data flows (Phase 3)

**What Via-Vitae actually is** (from repository evidence, not from its name): a
commercial IT company operating an EU pilot **in Lithuania** — church-vertical
websites, e-commerce and a marketplace, self-hosted on **Proxmox** with **k3s +
Argo CD (GitOps)**; personal data claimed to remain in the EEA. (E5, E6)

Verified components:

- **viavitae-api** — FastAPI / Python 3.12; multi-tenant Postgres with
  per-tenant schemas and row-level security; Alembic migrations; Bitrix24
  on-prem CRM integration; **Stripe + Paysera payment webhooks**; a **RAG
  pastoral AI assistant**; GIS cemetery mapping; donation management API. (E5)
- **viavitae-web** — Next.js 15 / React 19, next-intl (LT/EN/RU),
  OpenAPI-generated typed contracts against the API, Keycloak identity
  configuration, self-hosted Matomo analytics (env-configured), cookie/legal
  pages, Zod-validated server-side quote proxy. (E6, E8)
- **viavitae-clients** — per-client tenant registry treated as the audit trail;
  the **critical automated journey**: PR → CI + code-owner review → merge to
  `main` → `provision-dispatch.yml` → `POST /v1/tenants/<slug>/provision` on the
  API → staging deploy → Playwright smoke (`viavitae-qa`) → production sync via
  Argo CD → regenerated manifests/lockfiles. (E6)
- **viavitae-infra** — Ansible (96 files), Terraform (65), k8s (31, incl.
  default-deny and cross-tenant-deny network policies), monitoring (10),
  backup (9), SOPS+age secret workflow with **only public recipient keys
  committed** (private-key exclusion verified in `.gitignore`). (E7)

**Trust boundaries to model:** browser → Next.js middleware (CSP present) → API →
tenant-isolated Postgres; web → Bitrix24/Stripe/Paysera (third parties, payment
data); CI → container registry (build-to-production — currently broken, VV-2026-
10-001); Terraform control plane → GitHub org (admin writes).

**Data-flow highlights:** the quote and assessment funnels collect contact name,
organization name and **email**, with **server-enforced consent
(`consent_privacy: true`) and a stored consent-notice version** citing DPIA-001
R7 — a mature privacy-by-design pattern (GDPR Art. 25/7) whose governing DPIA
lives in a **still-empty** repository (Art. 30 record gap). Payment flows route
card data to Stripe/Paysera (processor chain; Art. 28 agreements unevidenced).
Pastoral/assessment content **may constitute Article 9 special-category
(religious) data**; its lawful basis is currently UNDETERMINABLE because the DPIA
corpus does not exist. The RAG assistant's tool permissions and the webhook
signature/origin checks were NOT RUN.

---

## 5. Control plane, GitHub governance, CI/CD (Phase 8)

**VERIFIED PASS (observed 2026-10-26):**

- Org-wide 2FA enforced (`two_factor_requirement_enabled: true`). (E11)
- All 26 public repos: secret scanning + push protection enabled. (E10)
- 21 branches carry classic branch protection with **strict** up-to-date
  enforcement and **admin enforcement**; no force pushes allowed;
  `viavitae-control` protected by the `protect-main` ruleset. (E10)
- Org Actions restricted to a selected allow-list. (E11)
- `main` CI health: web/clients/qa and scheduled compliance/CodeQL runs green
  through the morning of 2026-10-26; control-plane `Audit` + `provenance`
  workflows green since 2026-10-21 (P1-23 repaired). (E12)
- Credential hygiene program exists and is honest: classic PAT retired; register
  with expiry CI gate; two air-gapped, hash-verified backup drives
  (BACKUP-A/B) for state + vault. (E13, ../SECRETS_INVENTORY.md)
- September's P0 protections-downgrade danger is closed: apply landed
  2026-10-17 and state now matches declared protections (20/20 contexts
  reconciled per register P1-24; state counts verified here — E3).

**Findings on this layer:** VV-2026-10-003 (single-person org; **all six teams
hold push on all repos — no least-privilege separation**), VV-2026-10-006
(reviewer access in limbo), VV-2026-10-007 (org `sha_pinning_required=false`
while per-repo "Action SHA pinning" gates compensate), VV-2026-10-008 (plan not
reproducible — fresh plan aborts on missing required input `billing_email`; the
applied tfvars' location could not be verified), and the private-repo blind spot:
the 5 private repos show **no readable branch protection at all** — on Free this
is expected (protection requires Team+), meaning confidential compliance repos
will exist **unprotected** once populated.

**Cross-checks against ../COMPLIANCE.md performed after drafting (corrections
applied):** the `billing_email` plan abort is documented as intentional (P1-12),
so VV-2026-10-008 was scoped down to the custody question only; the separation-
of-duties gap (P1-10: 0 required approvals so the sole member can merge their
own PRs) independently confirms VV-2026-10-003; `sha_pinning_required=false`
(P1-3) confirms VV-2026-10-007; the register's own claim-check rule
(§1.1: "no `enforced-verified` without a cited live observation") is the pattern
this report follows for every VERIFIED status above.

---

## 6. `viavitae-landing-*` assessment (Phase 6)

All ten repositories are the same class (E9; identical 89 KB size, 19 files,
same 2026-10-15 push window; sampled heads listed in §3):

- Two commits each: "initial scaffold from Via-Vitae template" + one governance
  fix (`.gitignore` `*.tfstate`).
- `main.py` is the **PyCharm placeholder** ("This is a sample Python script…
  print_hi('PyCharm')"). No site content, forms, analytics configuration,
  domains or deploy targets.
- README is inherited template text ("single source of truth for how a Via-Vitae
  repository looks") with live CI/CodeQL/Compliance badges — the workflows do
  exist, so the badges are honest *about the scaffold*, not about a landing page.

**Separate conclusions per dimension:** Feature completeness: **VERIFIED FAIL
(class-level)**. Security/privacy today: **NOT APPLICABLE — justified** (a repo
that deploys nothing cannot expose data), *conditional on verified exclusion*:
`has_pages=false` verified on the sampled repo; the other nine inferred from
identical structure — inference flagged. Integration/operational readiness:
**NOT RUN**. **Hazard:** green gates over empty scaffolds create a
false-readiness signal for non-technical stakeholders. Release decision required
from the owner (VV-2026-10-005).

---

## 7. Privacy & compliance readiness (Phase 9)

**Applicability:** GDPR applies (EU/Lithuanian establishment, EEA data
subjects); Lithuanian e-communications rules apply to analytics consent (NOT
RUN). ISO/IEC 27001:2022 and SOC 2 (2017 TSC) are *assurance objectives*, not
attested states; no certification or report exists, and this internal review must
not be described as one.

| Control topic | Evidence at reference date | Status |
| --- | --- | --- |
| GDPR Art. 30 records of processing; DPIAs; retention schedule | `viavitae-data-governance` **empty** | **BLOCKED** |
| GDPR Art. 28 processor register (Stripe, Paysera, Bitrix24, hosting) | `viavitae-vendor-register` **empty** | **BLOCKED** |
| ISMS scope, risk assessment, SOA, policy library | `viavitae-policies` / `-compliance` / `-threat-model` **empty**; gap/SOA registers are stubs in `viavitae-docs` | **BLOCKED** |
| Privacy by design in product (consent-gated funnels, server-side validation, CSP, i18n legal pages, EEA hosting claim) | Code inspection of web/api | VERIFIED PASS (implementation level, those two repos only) |
| Art. 9 lawful basis for pastoral/assessment data | DPIA absent | UNDETERMINED — legal determination required |
| ISO 27001 certification / SOC 2 Type II | No external assurance engaged | PENDING — out of this audit's authority |

Framework clause references are partly inherited from ../COMPLIANCE.md mappings
and are disclosed as such; no clause numbers were invented.

---

## 8. Operational resilience (Phase 10)

Backup/restore of the **control plane** (state + vault): real, air-gapped,
hash-verified, monthly rotation between two drives (E13). Application-data
backup: **unevidenced** (repo-level scripts exist in `viavitae-infra/backup`,
10-file `monitoring/` unexamined — NOT RUN). RPO/RTO: **no targets defined
anywhere** (runbooks empty). Incident response, escalation, capacity and
performance testing: **NOT RUN / NOT EVIDENCED**. Deployment & rollback: pipeline
red (VV-2026-10-001); Argo CD sync path untested. **Operational gate: VERIFIED
FAIL.**

---

## 9. Findings register

Severity, confidence and priority are tracked separately; a suspected issue may
carry high potential impact while awaiting confirmation.

| ID | Title | Class | Severity / Confidence | Owner | Remediation (plain language) & acceptance |
| --- | --- | --- | --- | --- | --- |
| VV-2026-10-001 | Production deploy path non-functional; all prod k8s manifests are `placeholder.yaml` | Confirmed | **High** / High | Infra owner | Repair the image build/push failure; replace each placeholder with real reviewed manifests under Argo CD; acceptance = successful production-candidate deploy of the exact release commit through dev→staging→prod with recorded run links. Independent re-run required. |
| VV-2026-10-002 | Compliance & operations artifact repos empty while product code cites them (DPIA-001 et al.) | Confirmed | **High** (compliance blocker; not exploitable) / High | DPO/compliance role (same human today) | Populate ROPA, DPIA (incl. Art. 9 basis), retention schedule, policy library, vendor register with Art. 28 terms, runbooks, training records; acceptance = every cited ID resolves to a real document; decide Free-plan protection limitation for the private repos (upgrade plan or accept unprotected population risk). |
| VV-2026-10-003 | Single-person org: owner = implementer = approver; all six teams hold push on all repos | Confirmed governance gap | **High** for SOC 2 CC-series / High | Owner | Establish the largest feasible separation of duties (active peer reviewer account or documented compensating controls + independent-assurance engagement); scope team bindings to tiers; acceptance = team permissions match tier policy; review chain demonstrably enforced. |
| VV-2026-10-004 | ~151 open Dependabot alerts concentrated in release candidates (api 45, brand 41, web 38, qa 15, docs 12); severities unreadable | Confirmed, unranked | **Medium pending triage** (may become High/Critical) / Medium | Per-repo owners | Re-pull alerts with severity; triage by reachability on default branch; remediate criticals on api/web/clients; acceptance = fresh zero-critical snapshot dated against the release commit. |
| VV-2026-10-005 | Ten landing repos are scaffolds; release inclusion undecided | Confirmed + decision request | **Medium** / High | Owner | Decide exclude-vs-include per landing page. Exclusion must be evidenced (no deploy target, no domain, no indexing); inclusion requires content, privacy notice, form destination, consent behavior and accessibility verification. |
| VV-2026-10-006 | Sole reviewer `IterVitae` recorded "inactive, admin invite pending" yet absent from live outside-collaborators | Evidence gap / suspected access anomaly | **Medium** / Low — needs confirmation | Owner | Produce the access-review record: current role, membership, review capability of that account; acceptance = API-visible membership matching documented policy. |
| VV-2026-10-007 | Org-level SHA pinning disabled while repos rely on a "Action SHA pinning" check | Confirmed policy/config mismatch | Medium / High | Platform owner | Either require pinning at the org ruleset or document the per-repo gate as the compensating control; acceptance = configuration and policy agree. |
| VV-2026-10-008 | Applied-input custody unverifiable: fresh plan aborts on missing required `billing_email`; the tfvars used for the 2026-10-17 apply is not in this workspace and its storage location is not evidenced | Confirmed, **scoped down after cross-check** | Low–Medium / High | Infra owner | The abort itself is **by design and already documented** (../COMPLIANCE.md P1-12: `TF_VAR_billing_email` deliberately has no default for GDPR minimisation) — the residual gap is custody: record where the applied value lives, how it is protected and restored; acceptance = the documented custody path is exercised once and the clean-checkout plan procedure is reproduced |
| VV-2026-10-009 | QA browser/load gates cannot run — staging tenant not provisioned (register P1-22, still open) | Confirmed | **High** for integration gate / High | QA owner | Provision isolated staging + synthetic data; run the full cross-repo journey (clients merge → provision → staging smoke → sync); acceptance = dated E2E evidence covering the exact release combination. |
| VV-2026-10-010 | Org webhook inventory, private-repo protections, code-scanning alert counts unobtainable | BLOCKED | — | Owner | Grant scoped read (`admin:org_hook`), or GitHub Team for private-repo visibility; re-run the blocked cells of §3/§5. |

**Risk acceptance** is tracked separately from these check results; none has
been accepted, waived or closed by this document.

---

## 10. Release gates and decision (Phase 13)

| Gate | Result | Basis |
| --- | --- | --- |
| 1 Scope | FAIL / UNDETERMINED | Org reconciled 31/31, release contents never named |
| 2 Evidence | UNDETERMINED | 15 repos not yet deep-audited; blocked cells above |
| 3 Functionality | UNDETERMINED | No cross-repo E2E evidence on provisioned staging |
| 4 Security | UNDETERMINED (provisional fail) | 151 untriaged alerts; no Critical *confirmed* yet |
| 5 Privacy | **FAIL** | Art. 28/30 corpus absent while collection runs in code |
| 6 Integration | UNDETERMINED | Provisioning journey unverified |
| 7 Operations | **VERIFIED FAIL** | Deploy red; placeholders; no RPO/RTO; empty runbooks |
| 8 Landing scope | **FAIL** | Unfinished and undocumented either way |
| 9 Independence | NOT SATISFIED | Self-review only |
| 10 Approval | n/a | This report is a recommendation, not a decision |

**Recommendation: NO-GO.** Three mandatory gates fail outright; several others
cannot be decided on available evidence. Remediation sequence to make a decision
possible: (a) written release definition — repos + exact commits; (b) fix
VV-2026-10-001 and -009 so journey evidence becomes producible; (c) triage
VV-2026-10-004 with severities; (d) populate the minimum GDPR corpus (VV-2026-
10-002) covering what the pilot actually collects; (e) resolve VV-2026-10-006
access review; (f) re-run gates and record the decision separately from this
recommendation.

**Recommendation ≠ approval.** The authorized decision-maker (today, the same
sole owner) must record any GO/GO-WITH-CONDITIONS decision separately, including
residual-risk acceptance with named approver, compensating controls and expiry.
GO WITH CONDITIONS must not disguise a failed mandatory gate; risk acceptance
does not override legal obligations.

---

## 11. Coverage statement and evidence index

Discovered **31** · reconciled **31** · accessible **26** (5 private, restricted
reads) · with content **22** · empty **9** · assessed in depth **5** (control,
web, api, infra, landing class via diocese+template) · class-assessed **11** ·
not yet deep-audited **15** · blocked **5**. Percentages deliberately avoided
over the 15 NOT RUN repositories; exclusions: private-repo blind spot, token
scope, tool-path defect in the code-scanning sweep.

Evidence captures taken this session (retain under the same controlled handling
as `audit-evidence/`; no secret values reproduced):

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
- **E11** Org settings (2FA, plan=free), members, teams, outside collaborators, Actions permissions (`sha_pinning_required=false`).
- **E12** CI run listings: web/clients/api/qa/control `main` + failed dependabot lint + failed Deploy run 38797087629 ("Build and push image").
- **E13** `docs/SECRETS_INVENTORY.md` register and backup-media section (as at file state 2026-10-26).
- **E14** Read-only `terraform plan` transcript: `Error: No value for required variable "billing_email"`, exit 1.

---

## 12. Limitations, future-dated work, and change control

1. This is a **working report**, not the final audit: per-repository deep dives
   (Phase 5 §8.1–8.8) for 15 repositories, Phase 7 integration testing, Phase
   12 remediation verification and the re-run of gates are outstanding.
2. Historical conclusions (e.g. "P1-24 apply landed 2026-10-17") rest on the
   register plus today's state observation; the original apply run record itself
   was not re-examined.
3. All observations are dated 2026-10-26 UTC; any later change to the 31 heads
   listed in §3 invalidates conclusions about those versions and requires
   re-verification (Phase 12 step 9).
4. This document must land via the normal gated PR flow (provenance trailer,
   review, status checks) like every other artifact here; its presence is not a
   release control by itself.
