# viavitae-api — Persistence Baseline Design Spec (VV-2026-10-016)

- **Date:** 2026-10-27
- **Owner org:** `Via-Vitae` (GitHub Free plan)
- **Target repo:** `Via-Vitae/viavitae-api` (public; classic branch protection, required contexts `CI status` + `Compliance status`, `strict=true`, `required_approving_review_count=0`, squash-merge only)
- **Local worktrees:** `/opt/viavitae/repos/viavitae-api` (main checkout, untouched), `/opt/viavitae/repos/viavitae-api-wt-vv011` (PR #9), `/opt/viavitae/repos/viavitae-api-wt-deps` (lock bump, uncommitted)
- **Compliance targets:** GDPR Art. 5(1)(f), Art. 25, Art. 32, DPIA-004 M1; SOC 2 CC6.1, CC8.1; ISO/IEC 27001:2022 A.8.2, A.9.4
- **Execution authority:** **PLAN-ONLY.** No `terraform apply`. No `alembic upgrade` against any non-ephemeral database. No push or merge without explicit owner authorization. No secret/DSN values in any committed artifact.
- **Status:** Draft for owner review. Written from measured repository state on 2026-10-27, not from the repo's own documentation.

> Scope boundary: this spec covers `viavitae-api` persistence only. The Via-Vitae
> control plane (`viavitae-control`) manages the GitHub organization; it does not
> own application schema and must not be conflated with it.

## 1. Problem

VV-2026-10-016 recorded that `viavitae-api` has no database schema. On building this
spec the condition proved **deeper in two ways that change the plan**, so both are
stated here with the command that measured them:

1. **No ORM models exist either.** `grep -rn '__tablename__' app/models/*.py` returns
   **nothing**; the five `mapped_column` matches are all in `app/models/base.py`
   (the mixins). Every domain file is a docstring plus a `TODO(api)` comment — e.g.
   `app/models/donation.py:9-14`. Consequence: `Base.metadata` is empty, so
   `alembic revision --autogenerate` would emit a **no-op migration**, not a schema.
   The baseline therefore starts with model authoring, not with `alembic init`-style
   scaffolding (Alembic is already configured: `alembic.ini`, `env.py`, `script.py.mako`).
2. **Nothing sets the tenant context.** `tenant_id_ctx` appears only at its definition
   (`app/core/logging.py:22`) and at two read sites (`logging.py:43`,
   `db/session.py:66`); there is **no `.set(` call anywhere in `app/`**. Because
   `get_session()` only issues `set_config('app.tenant_id', …)` when the value differs
   from the default `"-"`, the statement is **unreachable in practice**. So DPIA-004 M1's
   "enforced by middleware" is false twice over: no middleware sets the variable, and
   no policy exists to read it.
3. **No runtime schema routing.** `env.py` scopes *migrations* to a tenant schema via
   `-x tenant_schema=…`, but `session.py` never sets `search_path`. Query traffic would
   all land on the default path, so the schema-per-tenant model (ADR-004) is a
   migration-side concept only.

Measured state that is *not* a gap (so the plan does not re-do it): slug validation and
schema-name derivation are implemented and hostile-input-tested in `app/core/tenancy.py`
(`schema_for`, `_SLUG_RE`, 63-byte identifier cap, reserved labels); the engine uses
`pool_pre_ping`, a statement timeout, transaction-local `set_config(..., true)`, and
rollback-on-exception in `get_session()`; PostgreSQL is **17** with pgvector
(`docker-compose.yml:15 image: pgvector/pgvector:pg17`), so `gen_random_uuid()` is
built in and no `pgcrypto` extension is required for `IdMixin`.

## 2. Goals

- G1: one reviewable Alembic baseline that creates the roles, the control schema objects
  and exactly the tables the money path needs, with RLS enforced on each.
- G2: make tenant isolation *executable* rather than descriptive: a set GUC, a policy that
  reads it, and a test that proves cross-tenant reads return zero rows.
- G3: unblock VV-2026-10-011 (Stripe/Paysera/Bitrix24 verification + replay idempotency)
  by giving `webhook_event` and `idempotency_key` a real home.
- G4: leave no document claiming more than the code does (the VV-2026-10-014 discipline).

## 3. Non-goals

- No migration of production data (there is none). No backfill. No performance tuning.
- No change to the payment providers' contracts, and no enablement of the optional `pdf`
  extra (separate owner decision, VV-2026-10-018).
- No attempt to reach zero Dependabot alerts beyond the criticals that block merging.

## 4. Design decisions

**D1 — Two-layer tenancy, explicitly.** Keep ADR-004's schema-per-tenant, and add RLS
*inside* each tenant schema as defense-in-depth against a `search_path` mistake.
Control-plane tables (`tenant`, `webhook_event` ledger, `idempotency_key`) live in
`public`; per-tenant business tables live in `tenant_<slug>`. Rationale: the ledger must
be globally addressable by `(provider, provider_event_id)`, while donor data must not be
visible across schemas even if application code is wrong. **Rejected:** shared schema with
RLS only — cheaper, but contradicts ADR-004 which is already the documented decision, and
would make the docs wrong again; per-tenant databases — far heavier ops for a single-owner
org. **Owner must confirm D1** because it fixes the shape of every later migration.

**D2 — Application role, not the table owner.** RLS is bypassed by table owners and by
roles with `BYPASSRLS`, so a policy on a table owned by the migration role protects
nothing when the app connects as that same role. Create `viavitae_app` (LOGIN,
`NOSUPERUSER`, `NOBYPASSRLS`), grant `USAGE`/`SELECT`/`INSERT`/`UPDATE`/`DELETE` on the
tenant schemas, keep DDL rights with the migration role, and set
`ALTER TABLE … ENABLE ROW LEVEL SECURITY` plus `FORCE ROW LEVEL SECURITY`. The app DSN in
runtime secrets must use `viavitae_app`. **This is the decision that makes M1 evidence
honest.** Cost: one role and a DSN change; nothing in the repo stores credentials
(`docs/SECRETS_INVENTORY.md` governs them), so the DSN edit is an owner action outside git.

**D3 — Set both GUCs in one place, fail closed.** Extend `get_session()` to resolve a
`TenantContext` (via `app.core.tenancy.resolve_tenant`) and then, per connection:
`SELECT set_config('search_path', :schema || ',public', false)` and
`SELECT set_config('app.tenant_id', :tenant_id, true)`. If no tenant resolves, **raise**
`400 invalid_tenant` (the error type already exists) instead of silently proceeding with
the `"-"` default. The schema name comes only from `schema_for()` output, never from raw
input, so no identifier injection is possible; the values are bound parameters. A request
that legitimately spans tenants (the control-plane provisioning endpoint) must use a
separate, explicitly audited dependency rather than a wildcard `search_path`.

**D4 — Policy template, one shape for every tenant table.**
`CREATE POLICY tenant_isolation ON <table> AS PERMISSIVE FOR ALL TO viavitae_app USING
(tenant_id = current_setting('app.tenant_id', true)::uuid) WITH CHECK (tenant_id =
current_setting('app.tenant_id', true)::uuid)`. Using the two-argument `current_setting`
avoids a hard error when the GUC is unset — which is why `WITH CHECK` is mandatory: a
missing GUC then evaluates to NULL and **denies** writes rather than allowing them.
Each `CREATE POLICY` ships in the same revision as its `CREATE TABLE`, and every
`drop_policy`/`downgrade` reverses it (the repo's own rule in `app/models/*.py` comments
and `data-model.md`).

**D5 — Autogenerate is a draft, never a commit.** Because metadata is empty today,
M1 creates models by hand and *then* uses `alembic revision --autogenerate` only to diff.
Every generated revision is reviewed for: unintended `DROP`, missing `tenant_id`, missing
policy, and `compare_server_default` noise from `func.gen_random_uuid()`. CI runs the
offline render (`alembic upgrade head --sql`) so the DDL is reviewable as text.

**D6 — Expand–contract, and never in the same release as the removal.** No column or
table drops in a revision that also adds its replacement; the contract half is a separate
revision merged at least one release later. This matches `versions/.gitkeep`'s own
instruction ("expand-contract, always reversible") and keeps a rollback possible without
data loss.

**D7 — Vertical slice, not the whole domain.** Milestone M2 builds only:
`public.tenant`, `public.webhook_event`, `public.idempotency_key` (the ADR-005 ledger),
and one representative tenant-schema table with RLS — enough to prove the pattern and to
unblock the webhook money path. `assessment`, `quote`, `donation`, `gis`, `notification`,
`ai_*` models follow as M5 in a later plan, each with its retention annotation
(`donation.py` rule: "personal data columns are annotated with their retention rule").

**D8 — Isolation tests become the acceptance gate, not coverage.** The two skipped
`tests/isolation/` TODOs are rewritten to insert a row as tenant A, then assert tenant B
reads zero rows and cannot update A's row, in a DB-enabled CI job. Until VV-2026-10-017 is
fixed those legs never run in CI at all, so this spec's verification is **local +
deliberately planted failure proof** (see §7).

## 5. Milestones

| # | Deliverable | Files | Acceptance |
| --- | --- | --- | --- |
| M0 | Confirm D1/D2 with the owner; record the tenancy decision in ADR-004 with an implementation-status line | `docs/architecture.md` | written decision, dated, no forward-looking wording |
| M1 | ORM models for the slice, mixins only from `base.py` | `app/models/tenant.py`, `webhook_event.py`, `idempotency.py` | `alembic check` reports no unexpected diff against hand-written intent; `Base.metadata.tables` lists the slice |
| M2 | Baseline revision: roles, schemas, tables, indexes, RLS policies | `app/db/migrations/versions/<rev>_baseline.py` | fresh ephemeral PG17 → `alembic upgrade head` exits 0; `\dt+` shows tables; `SELECT polname FROM pg_policy` shows one policy per tenant table |
| M3 | Runtime tenancy plumbing: GUC + `search_path`, fail-closed resolution, ContextVar set/reset | `app/db/session.py`, `app/api/deps.py`, `app/core/tenancy.py` | unit test asserts `set_config` is called with the resolved schema and that an unresolvable tenant yields 400, not a session |
| M4 | Un-skip isolation tests, DB-enabled CI job, prove the gate reacts | `tests/isolation/*`, `.github/workflows/ci.yml` | tests pass against a real PG; a planted wrong `tenant_id` makes them fail; `CI status` red on that run |
| M5 | Later: remaining domain models + Alembic invocation in deploy (explicit ordered step, not an image side effect) | separate plan | each table arrives with a policy and a retention annotation |

## 6. Dependency and ordering constraints

1. **`viavitae-api` is currently merge-locked** by the eight CRITICAL lockfile findings
   (VV-2026-10-004 correction, E26): `CI status` is a required context and Trivy exits 1.
   No revision PR can merge until the owner resolves the `pdf` extra decision
   (VV-2026-10-018) or the prepared lock bump lands. **This is step zero of this spec.**
2. VV-2026-10-017 (matrix `to_json`) must land before M4's CI evidence is meaningful;
   otherwise "tests passed in CI" would be a false claim — the exact defect class this
   audit exists to remove.
3. VV-2026-10-011 sits behind M2+M3: signature verification needs the ledger table, and
   the ledger needs a schema.
4. VV-2026-10-009 (staging) is unaffected: M2–M4 run against an **ephemeral** local
   PostgreSQL from `docker-compose`, not a provisioned environment.

## 7. Verification

```bash
# ephemeral database only — never a production DSN
docker compose up -d postgres
DATABASE_URL=postgresql+psycopg://ci:ci@localhost:5432/viavitae_test \
  uv run alembic upgrade head                     # expect exit 0
DATABASE_URL=... uv run alembic downgrade -1      # expect exit 0 (reversibility proof)
DATABASE_URL=... uv run alembic upgrade head --sql > /tmp/baseline.sql   # reviewable DDL
uv run python -m pytest tests/isolation -m isolation   # expect 2 passed, 0 skipped
uv run python -m pytest -q --cov                        # coverage floor must still pass
```

A migration is only "verified" when the isolation tests have been observed to **fail**
after a deliberate policy removal (drop one `CREATE POLICY`, re-run, watch tenant B read
rows), then restored. Reporting the green run without the planted failure is exactly the
decorative-gate error recorded in VV-2026-10-017.

## 8. STOP conditions

- STOP and escalate on any planned `DROP TABLE`, `DROP COLUMN`, `DROP POLICY`, data
  backfill, or `alembic stamp` in a diff — these are contract operations and belong in a
  later, separate revision.
- STOP if the target server reports anything other than PostgreSQL 17.x (the baseline
  assumes built-in `gen_random_uuid()` and pgvector semantics).
- STOP if the owner's D1 answer differs from this spec's assumption; every revision
  depends on it.
- STOP rather than "fix" a failing isolation test by weakening it; report the failure.
- No `terraform apply`, no branch protection change, no live credential rotation, no
  push, no merge — those are owner actions.

## 9. Rollback and fallback

- M1/M2 rollback is `alembic downgrade -1` plus `git revert` of the single revision commit;
  on an ephemeral database, `docker compose down -v` discards everything.
- M3 is the riskiest step (it changes the request path for every tenant). Mitigation:
  feature-flag the fail-closed raise, land it dark, enable after the isolation tests pass,
  and keep a one-revert rollback. Fallback if `search_path` routing breaks an existing
  integration: single-schema + RLS only (D1 alternative), which is a **decision reversal**,
  not an emergency patch — so it goes back to the owner.
- No production data exists, so no restore test can be performed against real rows; that
  remains an open operations gap (VV-2026-10-001/-002, RPO/RTO undefined).

## 10. Cost and effort

Rough, for one engineer with AI assistance, excluding owner-side secret/DSN work:
M0 half a day (decision + ADR edit); M1 one day (models for the slice); M2 one day
(revision, roles, policies, offline render review); M3 half a day plus integration fixes;
M4 half a day (CI job with a service container) and it inherits VV-2026-10-017; M5 out of
scope. Money cost: 0 — self-hosted Postgres on existing hardware, ephemeral CI runners
only. Free-plan limits are unaffected: RLS is a PostgreSQL feature, not a GitHub one.

## 11. Open items for the owner

1. Confirm or revise **D1** (schema-per-tenant + RLS) and **D2** (dedicated `viavitae_app`
   role, DSN change outside git).
2. Resolve the `pdf` extra / merge-lock in §6.1 — nothing in this spec can land before it.
3. Authorize the pushes for the three prepared changes (control register PR #42 follow-up,
   template matrix fix, api lock bump) so the dependency chain can start moving.
4. Name the DPO action for DPIA-004: M1 and M2 rows are annotated "not evidenced" here;
   the Art. 36 re-assessment is a legal determination, not an engineering one.

## 12. Appendix — D2 role runbook (owner-executed; no credential value in git)

Run as the PostgreSQL superuser against the **ephemeral/dev** database first, and only
then against a real instance. Nothing here is executed by the agent.

```sql
-- 1. least-privilege application role; cannot bypass RLS, cannot create schemas
CREATE ROLE viavitae_app NOLOGIN NOSUPERUSER NOCREATEDB NOBYPASSRLS
  CONNECTION LIMIT 20;
ALTER ROLE viavitae_app WITH PASSWORD '<from the secret store, never a file>';
GRANT CONNECT ON DATABASE viavitae TO viavitae_app;

-- 2. usage on every tenant schema plus the control schema
GRANT USAGE ON SCHEMA public, tenant_anne TO viavitae_app;
-- repeat per tenant schema; provision_tenant.py must grant this as step of creation

-- 3. DML only; DDL stays with the migration role
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA tenant_anne TO viavitae_app;
ALTER DEFAULT PRIVILEGES IN SCHEMA tenant_anne
  GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO viavitae_app;
GRANT USAGE ON ALL SEQUENCES IN SCHEMA tenant_anne TO viavitae_app;
```

Then in every tenant-table migration, after `CREATE POLICY`:
`ALTER TABLE <t> ENABLE ROW LEVEL SECURITY; ALTER TABLE <t> FORCE ROW LEVEL SECURITY;`
— `FORCE` matters only if the app ever connects as the owner, which D2 avoids; keep it as
belt-and-braces and record why in the revision docstring.

**Verification that the role, not just the policy, is doing the work:**

```sql
SET ROLE viavitae_app; SELECT current_setting('is_superuser');   -- expect f
SET ROLE viavitae_app; SELECT rolbypassrls FROM pg_roles WHERE rolname='viavitae_app';  -- expect f
SET ROLE viavitae_app; SELECT count(*) FROM tenant_anne.donation;      -- with app.tenant_id unset
RESET ROLE;
```

The third query is the real test: with `app.tenant_id` unset, `current_setting(..., true)`
yields NULL, so `USING`/`WITH CHECK` must return **zero rows** and refuse the insert. A
non-zero count means the policy is decorative — fix the policy before writing any data.

**DSN change checklist (owner action, outside git):**

1. Store the new password in the age/SOPS secret store; never in a commit or an issue.
2. Update the runtime secret consumed by `viavitae-api` (the `DATABASE_URL` the
   deployment injects) to use the `viavitae_app` user; keep the migration DSN separate.
3. Re-deploy and confirm `/v1/ready` is 200, then confirm the app cannot `CREATE TABLE`
   (positive proof of least privilege).
4. Record the date and the role name in `docs/SECRETS_INVENTORY.md`-style custody, per the
   existing Via-Vitae secret-register convention.
5. Only after this appendix is done can DPIA-004 M1 move from "Not evidenced" toward a
   rated residual risk, and that rating belongs to the DPO.
