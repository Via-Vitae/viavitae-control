# mise Toolchain, Environment and Task Management — Reusable Prompt (v1)

| Field | Value |
| --- | --- |
| Created | 2026-11-03 |
| Revision | 1 |
| Repo | viavitae-control |
| Type | Prompt asset (not a policy, not a plan — ungated by CI) |
| Scope | Via-Vitae (31 repos), journeyoflife-org, jolarca-dev — three planes, **one workstation** |
| Frameworks | SOC 2 Type II, ISO/IEC 27001:2022, GDPR, PCI-DSS 4.0 (jolarca-dev only) |
| Operator model | Single owner, single programmer, no teams, no separation of duties |
| Verdict space | **OPEN** — "do not adopt mise" is a legal, expected and fully-scored answer |
| Baseline verified | 2026-11-03: host `jol` probes (`command -v`, `apt-mark showhold`, `dpkg-query`, `--version`), manifest and `uses:` censuses across **all three** local clone trees (`/opt/viavitae/repos`, `/opt/jol/repos`, `/opt/jolarca/repos`), live `gh api` for the org Actions allow-list and the `protect-main` ruleset, and upstream mise documentation (`getting-started`, `security`, `dev-tools/mise-lock`, `continuous-integration`) |

## What this file is

A copy-paste-ready prompt that asks a model for a compliance-grade professional opinion on
five coupled questions: whether this estate actually has a toolchain-pinning problem, whether
`mise` is the right instrument for it, whether configuration belongs per repository or in one
shared place, what the supply-chain and CI consequences are, and how a rollout would be
gated, guarded and reversed.

It exists because the naive version of this question — *"the project needs mise, add it to all
31 repositories"* — produces a naive answer: a hand-written config file per repo, a
`curl | sh` install, a second copy of every binary on `PATH`, and a new unpinned third-party
dependency inside every CI pipeline. This version pins the environment facts, forbids hedging,
demands evidence, and requires the model to **prove the problem exists before it is permitted
to choose an instrument**.

Two premises in the naive request are already known to be wrong, and §4 records the evidence:

1. *"31 repositories"* — 19 of the 31 Via-Vitae repos declare no language runtime at all.
   A toolchain manager written into a repo with no toolchain is a vacuous control.
2. *"separately for each repository?"* — `mise` resolves configuration per directory, so files
   do live per repo, but **versions must not be authored per repo**. The estate already
   demonstrates both the right pattern (`viavitae-api`: SHA-pinned actions reading
   `${{ env.PYTHON_VERSION }}`) and the wrong one (`viavitae-control`: floating `@v4` tags).
   The answer must reconcile those, not ignore them.

## Terminology correction (read before sending)

The tool is **`mise`**, pronounced *"meez"* — <https://mise.jdx.dev/>, repository `jdx/mise`,
MIT-licensed, written in Rust, formerly named `rtx`. Its configuration file is `mise.toml`
(it also reads `.mise.toml`).

**"mise-en-place"** is the French culinary phrase (*"putting in place"*) that the project
borrows as its documentation-site title. It is **not** the tool's name. Unrelated Python
packages and Rust crates exist under that spelling. An artifact that says "install
mise-en-place" invites an answer about the wrong software. Say `mise`.

## How to use

a. Re-verify §4 against the live trees and the live org API before sending. Facts drift; use
   the refresh commands below. Correct any line the live tree contradicts and note the change.
b. Copy everything between the `~~~~` fences.
c. Send to a model with shell and file access if available — §5 lets it self-correct stale
   facts instead of reasoning from them.
d. If the model has no file access, run the refresh commands yourself and paste the output
   into §4 in place of the recorded values. Never send §4 unverified to a model that cannot
   check it.
e. **Do not act on the reply.** It is an opinion. Execution is a separate plan under
   [`AI_WORKFLOW_POLICY.md`](../../../policies/AI_WORKFLOW_POLICY.md), subject to plan-only
   authority (§3.5 below), the §5 review checklist, and an `ai:<tier>` provenance trailer.

### Refresh commands

```bash
# Run from anywhere. Read-only: no writes, no network mutation.
for b in mise asdf tfenv nvm uv direnv nix python3 node jq terraform gh; do
  printf '%-10s %s\n' "$b" "$(command -v $b || echo ABSENT)"
done
apt-mark showhold | grep -i terraform || echo "terraform NOT-HELD"
dpkg-query -W terraform 2>/dev/null; terraform version -json | jq -r '.terraform_version'
for d in /opt/viavitae/repos/viavitae-control /opt/jol/repos/jol-control /opt/jolarca/repos/jolarca-control; do
  printf '%-45s .terraform-version=%s\n' "$d" "$(cat "$d/.terraform-version" 2>/dev/null || echo ABSENT)"
done
# Runtime census: which repos actually have a toolchain to manage?
cd /opt/viavitae/repos && for d in */ .github/; do n=${d%/}
  printf '%-38s pkg=%s py=%s tf=%s sh=%s\n' "$n" \
    "$(ls "$d"package.json 2>/dev/null | wc -l)" \
    "$(find "$d" -maxdepth 2 \( -name 'requirements*.txt' -o -name 'pyproject.toml' \) 2>/dev/null | wc -l)" \
    "$(find "$d" -maxdepth 1 -name '*.tf' 2>/dev/null | wc -l)" \
    "$(find "$d" -maxdepth 2 -name '*.sh' 2>/dev/null | wc -l)"; done
# Idiomatic version files anywhere in the estate
find /opt/viavitae/repos /opt/jol/repos /opt/jolarca/repos -maxdepth 2 \
  \( -name '.tool-versions' -o -name 'mise.toml' -o -name '.mise.toml' -o -name '.python-version' \
     -o -name '.nvmrc' -o -name '.node-version' -o -name '.terraform-version' \) -printf '%p\n' 2>/dev/null | sort
# Live supply-chain posture
gh api orgs/Via-Vitae/actions/permissions/selected-actions | jq .
gh api orgs/Via-Vitae/actions/permissions | jq '.allowed_actions, .enabled_repositories'
grep -rn --include='*.yml' -E 'setup-(node|python|terraform)|node-version|python-version|terraform_version' \
  /opt/viavitae/repos/*/.github/workflows/ | sed 's|/opt/viavitae/repos/||'
# Is jdx a verified creator? (decides whether mise-action needs an explicit allow-list pattern)
gh api users/jdx --jq '.login, .type, .followers'
```

---

## THE PROMPT

~~~~
# 1. ROLE AND STANCE

You are a paranoid, compliance-driven build-systems and infrastructure architect with 30+
years of operational experience. You have personally cleaned up after a CI pipeline that
silently changed behaviour because a floating tag moved, after a `curl | sh` installer that
served a different binary than the one reviewed, and after a "developer productivity" tool
that became an unauditable dependency in a regulated estate. You are retained to give a
**binding professional opinion**, not a survey of options and not an implementation.

You are a sceptical advocate here, not a cheerleader. The operator arrived with a preferred
tool. Your first duty is to test whether the problem justifies any tool, then whether this
tool, then whether this rollout shape. If the honest verdict is "do not adopt", say so
plainly and score it as a first-class answer with the same rigour you would give "adopt".

Explain everything so that a competent student can follow it: assume the reader is fluent
with Linux, git, Terraform and GitHub Actions, but has never operated a polyglot toolchain
manager under an audit regime. Decompose every paragraph into numbered steps and lettered
sub-paragraphs. Define every term at first use. Never skip a "why".

# 2. COMPLIANCE TARGETS

Map every recommendation onto these frameworks, **citing the clause by name each time**:

- **SOC 2 Type II** — Trust Services Criteria, especially CC6.1 (logical access), CC6.6
  (external threats), CC7.1 (configuration and vulnerability management), CC7.2
  (monitoring for anomalies), CC8.1 (change management — authorisation, testing, approval,
  implementation), CC9.2 (vendor and third-party risk).
- **ISO/IEC 27001:2022 Annex A** — especially A.5.19–A.5.22 (supplier relationships, ICT
  supply chain, agreements with suppliers, monitoring of supplier services), A.8.4 (source
  code), A.8.9 (configuration management, including configuration of *development*
  tooling), A.8.15 (logging), A.8.19 (installation of software on operational systems),
  A.8.24 (cryptography — provenance/integrity of downloaded artifacts), A.8.25–A.8.34
  (secure development lifecycle, development environment, development and acceptance
  testing, protection of the build pipeline), A.8.32 (change management).
- **GDPR** — Art. 5(1)(f) integrity and confidentiality, Art. 25 data protection by design,
  Art. 28 processor contracts (any third-party service that receives estate data or telemetry),
  Art. 32 security of processing (including "the ability to restore the availability and
  access to personal data"), Art. 44–50 international transfer, Art. 33/34 breach
  notification within 72 hours — a compromised build tool is a *processor-boundary* incident,
  not a tidy-up task.
- **PCI-DSS 4.0** — applies to `jolarca-dev` only. Req. 2 (secure system configuration),
  Req. 6.2–6.3 (secure software development and vulnerability management), Req. 6.5
  (changes to software are tested, approved and documented), Req. 10 (logging), Req. 11.3
  (integrity monitoring), Req. 12.10 (incident response).

Where a framework names no clause that fits, say so rather than forcing a citation.

# 3. HARD CONSTRAINTS

1. **The operator is one human being.** No teams, no second approver, no on-call rotation, no
   separation of duties. Every control you propose that normally requires two people must be
   replaced by a *named compensating control* one person can actually execute — or you must
   state explicitly that the control is unachievable and record the residual risk.
2. **Three legal entities are three controllers.** Via-Vitae is a commercial IT company;
   `journeyoflife-org` is a Catholic charity whose stated operating principle is "built and
   operated in-house on hardware it owns"; `jolarca-dev` is a marketplace platform in
   PCI-DSS scope. The isolation model defines **boundary 1**: no shared membership, tokens,
   secrets, CI configuration, or Terraform state between the orgs — a *structural* boundary,
   not a naming convention. Any design in which one shared configuration file, one shared
   lockfile, one shared tool cache, or one shared CI action governs more than one entity is a
   boundary-1 violation and must be flagged as such, even if it is technically elegant.
   Note the aggravating fact: **one workstation serves all three planes.** Local tool caches
   are therefore shared by default. Decide explicitly whether a shared *binary cache*
   (`~/.local/share/mise`) breaches boundary 1, or whether boundary 1 governs configuration
   and credentials only. Give a reasoned verdict, not an assumption.
3. **Paranoia is the default.** Assume: the installer endpoint serves a different binary than
   the one you reviewed; a floating tag moves between review and execution; a "several times
   a week" release cadence means your pin is stale within days; a public-repo pull request
   can edit any committed config file; a GitHub API rate limit breaks an otherwise-correct
   pipeline at 03:00; the workstation disk fails without warning; the operator is
   incapacitated for 90 days and a successor must rebuild the estate from the repositories
   alone.
4. **No hedging.** Never write "consider using", "you might want to", "one option is",
   "it depends". Every question ends in a single verdict, a rationale, and an explicit
   rejection record for each alternative you discarded and *why*.
5. **Plan-only execution authority.** Read-only and plan-only commands (`cat`, `find`,
   `grep`, `command -v`, `mise ls`, `mise config ls`, `mise doctor`, `mise bootstrap
   --dry-run`, `terraform plan`, `gh api` GETs) may appear freely in your runbooks. Any step
   that mutates the machine, a repository, Terraform state, or live org configuration —
   `mise install`, `mise use`, `mise trust`, writing a `mise.toml`, `terraform apply`,
   `git push`, `gh api -X PATCH/PUT`, allow-list edits, secret writes, `apt install` — must
   carry a printed gate line: `STOP — human approval required before this step`. A runbook
   with ungated mutating steps is a contract violation.
6. **Provenance and plan-as-contract.** Any commit produced from your advice must carry the
   tier-provenance trailer required by the operator's AI workflow policy (exactly one of
   `ai:top`, `ai:mid`, `ai:cheap`, `ai:free`, `ai:review`), and the written plan is a
   contract: if execution deviates from it, work halts for review instead of improvising.
   Design your runbooks so each step is individually committable and individually reversible.
7. **Halt on destroy/replace.** Any recommendation whose execution would produce a
   `terraform destroy`, a resource `replace`, a removed binary, or an un-installable prior
   state must stop at the plan output and escalate to the human, with the blast radius stated.
8. **Never weaken an existing control to adopt a new tool.** If adopting `mise` would
   displace, shadow, or bypass a control already in force — the `commit-msg` provenance hook,
   the SHA-pinned Actions in `viavitae-api`, the `.terraform-version` CI assertion, the
   gitleaks pre-commit hook, the Actions allow-list — that is a **regression**, and it must be
   reported as a finding against the recommendation, not absorbed into it.

# 4. VERIFIED ENVIRONMENT BASELINE (2026-11-03, host `jol`, Ubuntu 24.04)

Correct any line below that the live tree or live API contradicts, and say so loudly. Do not
silently accept a stale fact. Mark each row `CONFIRMED`, `STALE — actual value is X`,
`CANNOT VERIFY — reason`, or `INFERRED — not directly observed`.

## 4.1 The three planes

| GitHub org | Legal entity | Control-plane repo | Local path | Terraform state |
| --- | --- | --- | --- | --- |
| `Via-Vitae` | Commercial IT company | viavitae-control | `/opt/viavitae/repos/viavitae-control` | local, git-ignored |
| `journeyoflife-org` | Catholic charity, owns its hardware | jol-control | `/opt/jol/repos/jol-control` | local, git-ignored |
| `jolarca-dev` | Marketplace platform, PCI-DSS 4.0 | jolarca-control | `/opt/jolarca/repos/jolarca-control` | HCP Terraform (cloud backend) |

## 4.2 What `mise` is — and the properties that matter here

- `mise` installs a project's tools, sets its environment variables, and runs its tasks from
  one `mise.toml` that works in the shell, the editor, and CI. MIT-licensed, written in Rust,
  **released several times a week**. Registry covers 1,000+ tools including `node`, `python`,
  `terraform`, `gh`, `jq`, `ripgrep`, `uv`.
- Config sections: `[tools]` (version pins), `[env]` (environment variables, `.env` loading),
  `[tasks]` (runnable commands with dependencies and parallelism). Also `mise bootstrap` for
  whole-machine setup: system packages, dotfiles, repo checkouts, services.
- Commands relevant to this assessment: `mise use`, `mise set`, `mise install`, `mise exec`,
  `mise run`, `mise tasks ls`, `mise config ls`, `mise ls --current`, `mise doctor`,
  `mise trust`, `mise lock`, `mise activate`, `mise bootstrap --dry-run`.
The following are **verified from upstream documentation on 2026-11-03** (pages cited), not
inferred. `mise` is not installed on this host, so none of it is confirmable by `--help`; where
a fact still needs a live check it is marked `NEEDS LIVE CHECK`.

- **Version strings are prefixes, not exact versions** (`getting-started.html`). `"24"`
  resolves to whatever is current at install time; two machines can resolve the same
  `mise.toml` differently.
- **Lockfile = `mise.lock`** (`dev-tools/mise-lock.html`). Records exact resolved versions plus
  download URLs and checksums per platform. `mise lock` writes it without installing;
  `mise install --locked` (or `MISE_LOCKED=1`) installs exactly what it records and **fails
  closed** when an entry is missing or a URL has no checksum. `[settings] lockfile = true`
  auto-creates and updates it; unset only maintains an existing one; `false` + `locked = true`
  is an error. `locked_scopes` and `[tool_config] locked` are **global-only**, "so a project
  cannot weaken your locked-mode policy".
- **`.tool-versions` entries are NOT lockable.** "Tools listed only in `.tool-versions` are not
  locked. Move them to `mise.toml` first." An idiomatic file such as `.nvmrc` is locked into
  "the lockfile of the nearest `mise.toml` whose directory contains it".
- **Trust model, and the CI hole** (`security.html#configuration-trust`). A `mise.toml` loads
  *without* trust only if it has no template syntax (`{{`, `{%`, `{#`) and contains solely
  `min_version`, plain-string `[tools]`, and `[tasks]` that list no `secrets`. **Anything else
  needs trust** — `[env]`, `[hooks]`, `[settings]`, tool option tables, `include`. Critically:
  *"When mise detects CI, for example because `CI` is set, it treats every config as trusted
  and records nothing."* GitHub Actions always sets `CI`. **Trust therefore provides zero
  protection in CI.** Paranoid mode "turns off both the CI exemption and `--yes` for trust".
- **Safe mode** `MISE_SAFE=1` (`security.html#safe-mode`). Loads untrusted config but refuses
  tasks, template `exec()`, plugin installs, hooks, `_.source`, project `[env]`/`[vars]`/
  `[settings]`/`[bootstrap]`/`[dotfiles]`, `postinstall`/`install_env`, and mise secrets. The
  `safe` setting is global-only, "so a project cannot turn it off for itself". **WARNING (upstream
  wording):** "Safe mode does not make other commands safe to run on config you have not
  reviewed. `mise install` can build a tool from source, which runs the tool's build scripts."
  Safe mode is scoped to resolution/metadata commands (`mise lock`, `mise ls`, `mise env`,
  `mise outdated`) — so `MISE_SAFE=1 mise install` is **not** a safe way to build a PR branch.
- **Paranoid mode** (`paranoid.html`) removes the trust exemptions, disables the CI trust
  exemption and `--yes`, turns on `locked_verify_provenance`, and does **not** share trust
  between git worktrees. A global `.miserc.toml` "never needs trust" and can protect settings
  project config cannot set, "such as `paranoid`" — this is the mechanism for enforcing it
  estate-wide.
- **Minimum release age** — default **24 hours for every backend**; `minimum_release_age = "7d"`
  raises it. Does not apply to exact versions or to entries already in `mise.lock`.
- **Download verification is on by default** where the backend supports it (`security.html#
  download-verification`): `aqua:` (checksums, Cosign, Minisign, SLSA, GitHub artifact
  attestations), `github:` (attestations, SLSA), `packslip:` (signed manifest + **pinned
  signer**, policy checked at install), **Node.js** (`SHASUMS256.txt` + its OpenPGP signature,
  which *must* be present), Zig (Minisign, always), precompiled **Python and Ruby** (GitHub
  artifact attestations), `npm:` (opt-in Sigstore). mise verifies OpenPGP/Cosign/Minisign/SLSA
  itself — no `gpg`, `cosign` or `gh` binary needed. **Terraform appears in no row of that
  table** and is not among the archive-downloading core tools (Bun, Deno, Elixir, Erlang, Go,
  Java, Node.js, Python, Ruby, Zig). `NEEDS LIVE CHECK`: which backend serves `terraform`, and
  what `mise tool terraform` prints on its `Security:` line. The estate's most
  credential-adjacent tool may install with no signature verification.
- **`mise.lock` verifies downloads, not disk.** Upstream WARNING: "A restored CI cache or a
  shared extraction store is trusted as is… mise can't validate an installed tree against the
  lockfile." Mitigation: cache `~/.cache/mise/downloads-cas` keyed on `hashFiles('mise.lock')`
  with `cache: false` on the action, because `--locked` "only reuses a download that has a
  checksum to check it against".
- **A third-party host is in the trust path.** `mise lock` reads release metadata and asset
  checksums from **mise-versions** (`mise-versions.jdx.dev`), recording `checksum_source =
  "mise-versions"` without downloading the asset. Assess this as a supplier relationship.
- **CI adoption** (`continuous-integration.html`): `jdx/mise-action@v5`; "When the repository has
  a `mise.lock`, the action runs `mise install --locked` automatically"; the `version` input
  pins mise itself. "The action gives mise the workflow's GitHub token while it installs tools,
  but does not export it to later steps" — later steps that install tools or hit rate limits
  need a token passed explicitly. Upstream's own example uses **floating** `actions/checkout@v7`
  and `jdx/mise-action@v5`.
- **The `curl | sh`-free path exists**: `mise generate install-script --localize --write`
  writes a committed `bin/mise` wrapper that "downloads a pinned mise release on first use",
  keeps everything under `.mise/`, **trusts the project's config and ignores the user's global
  config**. It pins "the newest stable release older than `self_update.minimum_release_age`,
  24h by default", or `--version`. Runner needs `bash`, `curl`, CA certs, `tar`, `sha256sum`.
  `mise self-update` verifies each release's signature. This materially changes the §9.1
  provenance question — assess it before rejecting `mise` on installer grounds.
- **Worktrees**: "A config in a linked git worktree is trusted when the same path in the main
  checkout is trusted"; paranoid mode does not share trust between worktrees. Directly relevant
  to §4.5.b.
- Shims exist for editors and scripts that never read shell startup files, with documented
  limits versus `PATH` activation. CI uses `mise exec` / `mise run`, not activation.

## 4.3 Host tooling (verified 2026-11-03)

| Tool | State | Path / version | Consequence |
| --- | --- | --- | --- |
| `mise` | **ABSENT** | — | Greenfield install, not a migration |
| `asdf` | ABSENT | — | No legacy `.tool-versions` estate to inherit |
| `tfenv` | ABSENT | — | No PATH-shadowing conflict today |
| `nvm` | ABSENT | — | Node versions currently come from CI actions only |
| `nix` | ABSENT | — | Not an available alternative without a large install |
| `uv` | **PRESENT** | `~/.local/bin/uv`, `0.12.17` | Already solves Python interpreter + venv management |
| `direnv` | **PRESENT** | `/usr/bin/direnv`, `2.32.1` | Already solves per-directory environment loading |
| `terraform` | **PRESENT, apt-managed** | `/usr/bin/terraform`, dpkg `1.16.1-1`, HashiCorp apt repo | Single system binary serving **all three planes** |
| `terraform` apt hold | **NOT HELD** | `apt-mark showhold` does not list it | A routine `apt upgrade` can silently move terraform off the `1.16.1` pin |
| `node` | PRESENT, **distro** | `/usr/bin/node`, **v20.20.2** | **Contradicts every repo's declared `NODE_VERSION: "22"` and `viavitae-web/.nvmrc` = `22`** — a live, proven local/CI divergence |
| `python3` | PRESENT, distro | `/usr/bin/python3`, 3.12.3 | Agrees with CI `PYTHON_VERSION: "3.12"` by coincidence, not by control |
| `pre-commit` | **ABSENT from `PATH`** | `command -v pre-commit` → nothing; `.venv/bin/pre-commit` → **4.7.0** | Exists only inside a git-ignored venv; not reproducible from the repo |
| `jq` | PRESENT, distro | `/usr/bin/jq`, jq-1.7 | Unpinned in CI too — runner-image default |
| `gh` | PRESENT, distro | `/usr/bin/gh`, 2.100.0 | Unpinned |
| `uv` usage | **PRESENT and USED** | `uv.lock` committed in 8 repos incl. `viavitae-api`, `viavitae-hermes-agents`; CI uses `astral-sh/setup-uv@<sha>` | Python *dependency* locking is already solved, and already SHA-pinned in CI |
| `direnv` usage | PRESENT, barely used | `.envrc` in exactly **2** places estate-wide: `jol-hub/data/`, `jolarca/` — **none in Via-Vitae** | The overlap with `mise [env]` is theoretical in this org, real in the other two |
| Task runner | **`make` is the estate convention** | 20+ `Makefile`s; `jolarca-control` and `jol-control` both have one; `jol-control`'s has `plan-gate`, `state-gate`, `fmt-check`, `agents-gate`, `doc-gate`, `backup-*`, `retire-key` | `mise [tasks]` would compete with an established, **gate-aware** Make convention. `viavitae-control` has no Makefile — it is the outlier |

Four consequences you must address explicitly:

- The **`node` v20 vs declared `22` divergence is already real and already observable.** This is
  the single strongest piece of evidence that a local-toolchain problem exists — and note that
  it is a problem in the *operator's shell*, not in CI, where `actions/setup-node@<sha>` already
  installs the declared version correctly.
- `uv` is **already installed, already used, and already SHA-pinned in CI** with committed
  `uv.lock` files. Python dependency management is solved. A `mise` recommendation must state
  what it adds beyond `uv`, not assume `uv` is absent.
- `direnv` is installed but used in **two** directories, neither in Via-Vitae. Do not overstate
  the overlap for this org.
- **`make` is the existing task-runner convention** in two of the three planes, and jol-control's
  Makefile already encodes STOP-gate semantics. Replacing or bypassing it with `mise [tasks]`
  is a governance regression risk, not a neutral swap.
- Prior operator guidance already **discouraged** adding `tfenv` alongside the apt binary,
  because it PATH-shadows `/usr/bin/terraform` and creates two sources of truth. That reasoning
  applies with equal or greater force to a `mise`-managed `terraform`. Either refute it with
  evidence or inherit it as a constraint.

## 4.4 Version pinning today — the actual problem statement

| Artifact | Pinned where | Exact? | Enforced by | Drift risk |
| --- | --- | --- | --- | --- |
| Terraform (Via-Vitae) | `viavitae-control/.terraform-version` = `1.16.1` | yes | `audit.yml` step **"Assert toolchain pin"**: compares the file against `terraform version -json` and exits 1 on mismatch | file vs installed |
| Terraform (CI) | `audit.yml` → `hashicorp/setup-terraform@v4` with `terraform_version: 1.16.1` | yes | the same assertion | **third copy of the same number** |
| Terraform (jol, jolarca) | **no `.terraform-version` file** | no | nothing | unbounded |
| Terraform (host) | dpkg `1.16.1-1` | yes, but **not held** | nothing | `apt upgrade` |
| Node | `NODE_VERSION: "22"` re-declared **per workflow file per repo** (ci.yml, compliance-check.yml, codeql.yml, pr-smoke.yml, nightly-e2e.yml, openapi-diff.yml …); `viavitae-web/.nvmrc` = `22`; **host `/usr/bin/node` = v20.20.2** | partial | nothing reconciles them | **proven live divergence**: host 20 vs declared 22 |
| Python | `PYTHON_VERSION: "3.12"` re-declared per workflow file per repo; host `python3` 3.12.3; `viavitae-control` uses a hand-made git-ignored `.venv` | partial | nothing | CI/local agree by coincidence |
| Python deps | `uv.lock` committed in `viavitae-api`, `viavitae-hermes-agents` (+6 in other planes) | **yes** | `astral-sh/setup-uv@<sha>` in CI | solved already |
| `jq`, `python3` (control-plane CI) | **runner image default** | no | nothing | image refresh silently changes behaviour |
| `pre-commit` | only in git-ignored `.venv`; absent from `PATH`; version 4.7.0 | no | nothing | not reproducible from the repo |
| GitHub Actions refs | 29 of 31 Via-Vitae repos **fully SHA-pinned**; see §4.6 | yes, per repo | nothing cross-repo | **same action pinned to different SHAs in different repos** |

Across the whole three-plane estate there are exactly **three** idiomatic version files:
`viavitae-control/.terraform-version` (`1.16.1`), `viavitae-web/.nvmrc` (`22`) and
`jol-ecommerce-engine/.nvmrc`. No `.tool-versions`, no `mise.toml`, no `.python-version`, no
`.node-version` anywhere. There are **eight** committed `uv.lock` files and **two** `.envrc`
files — the estate already uses per-tool lockfiles where a tool provides them.

**This table is the problem statement.** Your §6 answer must confirm, correct, or extend it
from the live trees before you are allowed to argue about instruments.

## 4.5 Repository runtime distribution (Via-Vitae, 31 repos)

Census of the local clone tree `/opt/viavitae/repos` (34 directories: 31 org repos including
the hidden `.github`, plus git worktrees — see §4.5.b).

| Class | Repos | Count | Has a toolchain to manage? |
| --- | --- | --- | --- |
| Terraform control plane | viavitae-control (12 `.tf`, 18 `.sh`) | 1 | yes |
| Python | viavitae-api, viavitae-brand, viavitae-hermes-agents | 3 | yes |
| Node (`package.json`) | viavitae-web, viavitae-demos, viavitae-docs, viavitae-qa | 4 | yes |
| Shell only | viavitae-infra (6 `.sh`), viavitae-clients (1 `.sh`) | 2 | marginal |
| Landing scaffolds | viavitae-landing-{basilica, cathedral, cemetery-services, churches-orthodox, churches-other, churches-protestant, deaneries, diocese, funeral-services, parish-church} | 10 | **no** |
| Governance / support | viavitae-{compliance, data-governance, observability, policies, reusable-workflows, runbooks, template, threat-model, training, vendor-register} | 10 | **no** |
| Org meta | `.github` | 1 | verify |

- **4.5.a** **21 of 31** Via-Vitae repos declare **no language-runtime manifest** (10 landing
  scaffolds, 10 governance/support, `.github`). Nine of those are empty at the default branch
  (the five private governance repos plus `runbooks`, `observability`, `reusable-workflows`,
  `training`). Writing a toolchain config into a repo with no toolchain is a vacuous control: it
  produces an artifact that looks like coverage and proves nothing. Per the estate's
  audit-snapshot semantics, an empty repo has no code snapshot at all, so its controls are
  reported as *unobserved*, never as *passed*.
- **4.5.a-i  Census limitation — do not over-read 4.5.a.** The census counted *manifests*
  (`package.json`, `requirements*.txt`, `pyproject.toml`), not source files. Yet all ten landing
  scaffolds and `viavitae-template` carry a **32-reference, fully SHA-pinned CI** that declares
  `PYTHON_VERSION: "3.12"` **and** `NODE_VERSION: "22"` and invokes `astral-sh/setup-uv`,
  `aquasecurity/trivy-action` and `trufflesecurity/trufflehog`. So these repos install a Python
  and a Node toolchain for code the manifest census cannot see. Determine what they actually
  build before declaring them out of scope — "no manifest" is not "no runtime".
- **4.5.b** The local tree also contains **git worktrees** (`viavitae-api-wt-deps`,
  `viavitae-api-wt-vv011`, `viavitae-template-wt-ci`, `viavitae-template-wt-install`, and
  `jol-infrastructure-f14f21` in the charity plane). `mise` resolves configuration by walking up
  from the working directory, and §4.2 records that worktrees inherit trust from the main
  checkout but not under paranoid mode. Determine what a worktree resolves to for *config*,
  and what that does to reproducibility of a CI job that checks out a branch.
- **4.5.c** Reconcile this census against `viavitae-control/repos_data.tf`, which is the
  declared inventory and the input to drift detection. Report any repo present locally but
  absent from the declaration, or declared but absent locally, as a finding — do not silently
  pick one list.
- **4.5.d  The other two planes are not small.** Local trees hold **43** directories under
  `/opt/jol/repos` (41 `jol-*` repos plus a non-org `obsidian/` and a worktree) and **16** under
  `/opt/jolarca/repos`. Runtime density is far higher there: ten `jol-site-*` repos with
  `package.json`, `jol-ecommerce-engine` with both Node and Python, `jol-analytics-ai`,
  `jol-hub` and `jol-rag-server` with three Python manifests each, `jol-infrastructure` with 68
  shell scripts, `jol-deploy` with 21, and **`jolarca` with 89 shell scripts**.
  `jolarca-control` is the most polyglot repo in the estate: 9 `.tf` + 35 `.sh` +
  `pyproject.toml` + `requirements.txt` + `requirements-dev.txt` + a `Makefile`. Its
  `pyproject.toml` is **configuration-only** (ruff settings, `target-version = "py312"`) and its
  own comment cites *ISO 27001 A.8.9 / A.8.25* and notes that `ruff` and `mypy` versions are
  unpinned, so "the standard meant whatever the ambient ruff version defaults to". That is an
  already-recognised, already-documented instance of the exact problem this assessment is about.

## 4.6 CI supply-chain posture — measured per repo, all three planes

Census of every `uses:` reference under `*/.github/workflows/*.yml` in all three local trees,
classified as SHA-pinned (`@` + 40 hex chars) or floating.

**Via-Vitae — 29 of 31 repos are 100% SHA-pinned.** The only exceptions:

| Repo | SHA refs | Floating refs | Floating references |
| --- | --- | --- | --- |
| `viavitae-control` | **0** | **2** | `actions/checkout@v4`, `hashicorp/setup-terraform@v4` |
| `viavitae-hermes-agents` | **0** | **3** | verify which |

Fully pinned, for scale: `viavitae-qa` 57, `viavitae-infra` 47, `viavitae-web` 44,
`viavitae-demos` 43, `viavitae-api` 42, `viavitae-clients` 34, `viavitae-template` 33,
`viavitae-brand` 32, `viavitae-docs` 27, and each of the ten landing scaffolds 32.

**jolarca-dev (PCI-DSS 4.0) — the flagship repo is the worst in the entire estate:**

| Repo | SHA | Floating |
| --- | --- | --- |
| `jolarca` | 2 | **45** |
| `jolarca-infrastructure` | 14 | 3 |
| `jolarca-data` | 11 | 1 |
| all other 13 jolarca repos | pinned | 0 |

Floating refs observed in `jolarca`: `actions/checkout@v7`, `actions/setup-python@v7`,
`actions/setup-node@v7`, `actions/upload-artifact@v7`, `actions/download-artifact@v4`,
`actions/github-script@v9`, `github/codeql-action/{init,analyze,upload-sarif}@v3`,
`docker/setup-buildx-action@v3`, `docker/login-action@v4`, `docker/build-push-action@v6`,
`terraform-linters/setup-tflint@v6`, and a local composite `./.github/actions/terraform-setup`.

**journeyoflife-org (charity) — mostly unpinned:** `jol-control` 0/16, `jol-ecommerce-engine`
0/23, `jol-link-registry` 0/21, `jol-auth` 0/20, `jol-bitrix24-integration` 0/14, `jol-dr` 1/12,
`jol-llm` 0/12, `jol-deploy` 4/11, `jol-analytics-ai` 0/11, `jol-security` 0/11,
`jol-devops` 0/10, `jol-scripts` 0/10, `jol-rag-server` 0/9, each `jol-site-*` ≈1/6–19.
The pinned exceptions: `jol-hub` 112/15, `jol-infrastructure` 38/3, `jol-mcp-servers` 21/0,
`jol-repo-template` 15/0, `jol-hermes-agents` 5/0.

**The drift that actually exists — same action, different commits, across Via-Vitae repos:**

| Action | Distinct refs in Via-Vitae | Total references |
| --- | --- | --- |
| `trufflesecurity/trufflehog` | **4** | 4 |
| `github/codeql-action/init` | **4** | 23 |
| `github/codeql-action/analyze` | **4** | 23 |
| `aquasecurity/trivy-action` | **4** | 41 |
| `actions/upload-artifact` | 3 | 134 |
| `actions/checkout` | 3 | 315 |
| `hashicorp/setup-terraform` | 2 | 4 |
| `actions/setup-node` | 2 | 124 |
| `actions/setup-python` | 2 | 109 |
| `astral-sh/setup-uv` | 2 | 4 |
| `pnpm/action-setup`, `docker/*` (4 actions), `codeql-action/autobuild` | 2 each | 30 / 15 / 2 |

≈**40 distinct action references for ~19 action names.** SHA-pinning is correct *per repo* and
completely uncoordinated *across* repos: `actions/checkout` resolves to three different commits
depending on which repository you are standing in.

- **4.6.a** `aquasecurity/trivy-action` is used 41 times across Via-Vitae but does **not**
  appear in the org allow-list (§4.7). It is therefore admitted by `verified_allowed: true`.
  This is directly decision-relevant: a third-party action published by a **verified creator**
  may need no explicit pattern. Determine whether `jdx` is a verified creator before assuming an
  allow-list edit is required — and note that relying on `verified_allowed` is itself a
  delegated trust decision worth a finding. `gh api repos/jdx/mise-action` confirms the repo
  exists, MIT-licensed, not archived, 401 stars, last pushed 2026-11-02; it does **not** expose
  verified-creator status, so that specific fact remains `CANNOT VERIFY` from the shell.
- **4.6.b  Read this carefully before recommending anything.** The estate's real supply-chain
  drift is in **GitHub Actions references and in per-workflow `env:` version variables** — not in
  local binaries. `mise` manages local and CI *tools*; it does not manage `uses:` lines. A
  `mise` rollout would leave all 40 distinct action references exactly where they are. Your §7
  comparison must therefore score `mise` against **"single-source the version manifest and
  propagate it"** (the shape of `scripts/propagate_landing_scaffold.py`), and §6 must say
  plainly how much of the measured drift each instrument actually touches.
- **4.6.c** `PYTHON_VERSION: "3.12"` and `NODE_VERSION: "22"` are re-declared **per workflow file
  per repo** — in `viavitae-template`, all ten landings, `qa`, `web`, `api`, `brand`, across
  `ci.yml`, `compliance-check.yml`, `codeql.yml`, `pr-smoke.yml`, `nightly-e2e.yml` and
  `openapi-diff.yml`. Moving Node from 22 to 24 is a hand edit to dozens of files with no gate
  that detects a missed one. That is the estate's actual single-source-of-truth gap.

## 4.7 GitHub Actions org allow-list (live API, 2026-11-03)

`gh api orgs/Via-Vitae/actions/permissions/selected-actions` returned:

```
github_owned_allowed: true
verified_allowed:     true
patterns_allowed:     actions/checkout@*            actions/setup-node@*
                      actions/setup-python@*        actions/cache@*
                      actions/upload-artifact@*     actions/download-artifact@*
                      hashicorp/setup-terraform@*   github/codeql-action@*
                      dependabot/*
                      pnpm/action-setup@b906affcce14559ad1aafd4ab0e942779e9f58b1
                      pnpm/action-setup@ea17c68df8912ef543352723c149a84f56e3d413
```

- Nine **floating** `@*` / `/*` patterns and two SHA-pinned `pnpm/action-setup` entries.
  `sha_pinning_required` is **false** at org level, so the nine floating patterns can move
  without approval. This is already a recorded finding; do not re-report it as new, but do
  state whether adopting `mise` in CI makes it worse (an additional floating pattern) or is an
  opportunity to make it better (SHA-pinned from day one).
- The allow-list is **Terraform-managed**: `org_actions_policy.tf` →
  `github_actions_organization_permissions.this` → `var.actions_allowed_patterns`,
  `var.actions_sha_pinning_required`. Changing it is a `terraform apply` against a live org →
  §3.5 gate, §3.7 halt-on-replace, and a compliance rationale per the AI workflow policy
  (`enforce_admins` / ruleset / org-setting class change).
- `jdx/mise-action` is **not** in the list today.

### 4.7.a `protect-main` ruleset on viavitae-control (live API, 2026-11-03)

`gh api repos/Via-Vitae/viavitae-control/rulesets/23943250` → `enforcement: "active"`,
`bypass_actors: []`, and rules:

```
deletion · non_fast_forward · required_linear_history
pull_request: required_approving_review_count = 0
              dismiss_stale_reviews_on_push = true
              require_code_owner_review = false
              require_extra_approval_for_unattributed_changes = true
              allowed_merge_methods = [merge, squash, rebase]
required_status_checks: strict_required_status_checks_policy = true
                        do_not_enforce_on_create = false
                        contexts = [ "provenance" ]
```

- **This contradicts `policies/AI_WORKFLOW_POLICY.md` §8**, which states that the live
  `protect-main` ruleset lists *no* required status checks and that "an admin can still merge".
  As measured today the `provenance` context **is** required, strict mode is on, and
  `bypass_actors` is empty — so the trailer gate blocks and nobody, including the owner, can
  bypass it. Report the policy text as **stale** and name the exact sentence to correct. Do not
  repeat the stale claim in your answer.
- Consequence for `mise`: the `ai:<tier>` trail is now a **blocking** control. Anything that
  stops the local `commit-msg` hook from firing (§4.8) degrades early feedback but no longer
  breaks the gate — CI still refuses the merge. Score that accurately rather than catastrophically.
- Consequence for path protection: adding `mise.toml` / `mise.lock` protection means editing
  this ruleset, which is Terraform-declared in `repo_rulesets.tf` and therefore an
  `apply`-gated live-org mutation requiring a compliance rationale (§3.5, §3.12 of the policy).

## 4.8 Governance conventions the answer must respect

- **Guard-script contract.** Every invariant-checking script in `scripts/` obeys: exit `0` =
  clean, exit `1` = violation found, exit `2` = unable to execute / nothing checkable.
  Unknown, null and empty are **never** treated as pass; a run that inspected nothing must
  exit `2`, because an unchecked invariant otherwise looks identical to a satisfied one.
  A new guard must be **proved sensitive by mutation**: inject at least one defect per
  invariant into a scratch copy and require each to flip the exit code to `1`, then confirm the
  real files exit `0`. A guard never observed failing is not yet a control.
- **Guard placement.** Guards must need no secrets and no network, so they run *before*
  credential-dependent steps. A docs or config gate parked behind a credential failure proves
  nothing — a skipped check is indistinguishable from a passing one in the check list.
- **Registration.** A new guard script goes in `scripts/` and must be registered as a row in
  the table in `policies/README.md` (columns: `File | Purpose | Plan tier | Automatable?`),
  not in `docs/COMPLIANCE.md`.
- **Dry-run by default.** Every mutating script in this estate defaults to dry-run and requires
  an explicit `--apply`. `scripts/propagate_landing_scaffold.py` previews a multi-repo sweep
  without writing anything. Any rollout you design must follow the same shape: preview, review,
  then apply per repo.
- **Pre-commit hooks bind to a repo-local `.venv`.** `.pre-commit-config.yaml` wires both
  `pre-commit` and `commit-msg` hook types; the generated `.git/hooks/*` shims hardcode
  `INSTALL_PYTHON=/opt/viavitae/repos/viavitae-control/.venv/bin/python3` and fall back to it.
  `.venv` is git-ignored and `.git/hooks` is never tracked, so the wiring must be redone on
  every clone. Hooks in force: gitleaks `v8.30.1`, pre-commit-hooks `v5.0.0`,
  pre-commit-terraform `v1.96.3`, plus local `commit-provenance` and secret-register guards.
  **Determine what happens to that hardcoded interpreter path if `mise` starts managing
  `python`.** If the `commit-msg` provenance hook stops firing, the `ai:<tier>` audit trail
  silently stops being produced — that is a compliance regression, and per §3.8 it counts
  against the recommendation.
- **`make` is the task-runner convention in two of the three planes.** `jol-control` and
  `jolarca-control` both ship a `Makefile`, as do 20+ repos across `jol` and `jolarca`.
  `jol-control`'s targets already encode the estate's gate vocabulary: `fmt-check`, `lint`,
  `plan` (depends on `validate`), `state-gate`, `plan-gate` (depends on `state-gate`), `apply`
  (depends on `plan-gate`), `agents-gate`, `doc-gate`, `backup-state`, `backup-status`,
  `backup-pack`, `backup-attest`, `retire-key`, `test`. Its own comments mark mutating targets
  ("`fmt`: MUTATES the working tree — never a verification step") and STOP gates. Any
  `mise [tasks]` design must state its relationship to these Makefiles: wrap, replace, or
  coexist — and must not weaken a gate that already exists.
- **Findings identifiers** follow the estate scheme (`VV-YYYY-MM-NNN` for Via-Vitae). Reuse
  the scheme of the entity you are writing about; never invent an ID that collides with the
  register in `docs/COMPLIANCE.md` or the audit at
  `docs/security/pre-deployment-independent-audit-2026-10-26.md`. IDs `VV-2026-10-018` through
  `VV-2026-10-029` are confirmed in use; `VV-2026-11-*` is unallocated as of 2026-11-03.

# 5. VERIFICATION CONTRACT

Before answering:

1. Read the three control-plane trees and the local clone census. Confirm or correct every row
   of §4.1–§4.8.
2. State, per fact: `CONFIRMED`, `STALE — actual value is X`, `CANNOT VERIFY — reason`, or
   `INFERRED — not directly observed`.
3. If a fact in §4 is contradicted, **halt and report the contradiction** before continuing.
   Do not build a recommendation on a fact you know to be false.
4. Never invent a version number, commit SHA, action slug, file size, lockfile name, config
   setting, finding ID, or framework clause that you have not read or cannot cite.
5. Reconcile §4.5 (local census) against `repos_data.tf` (declared inventory) and against the
   live org API. Unexplained differences are findings, not footnotes.
6. For every `mise` capability you rely on — lockfiles, trust, idiomatic version files,
   backends, the CI action, `bootstrap` — cite the documentation page or the `mise --help`
   output you actually read. "mise supports X" without a source is a guess.

# 6. QUESTION 1 — Does the problem exist, and is it worth solving?

Before any tool is discussed: prove or disprove that this estate has a toolchain-reproducibility
problem worth a new dependency.

Answer must cover:

- **6.1 Evidence table.** One row per pinned artifact from §4.4, extended from the live trees,
  with columns: `artifact | declared where | exact? | enforced by what | observed drift |
  blast radius if it moves | framework clause`.
- **6.2 The three-copies problem.** `.terraform-version`, the `setup-terraform` input, and the
  runtime assertion are three expressions of one number. Is that a defect or a compensating
  control? Give a verdict. Note that the assertion *detects* drift but does not *prevent* it,
  and that detection-after-the-fact in CI is a different control class from pinning-at-source.
- **6.3 The unpinned host.** Terraform is apt-installed, **not held**, and shared by all three
  planes. Score the cheapest available fix (`sudo apt-mark hold terraform`) against adopting a
  version manager. If a one-line hold closes 80% of the risk, say so and say what the remaining
  20% is.
- **6.4 CI/local divergence.** Python and Node versions are declared in CI `env:` blocks but
  locally come from a hand-made `.venv` and the runner image. Quantify how often that has
  actually bitten this estate, from evidence in the trees — or state plainly that there is no
  recorded incident, which weakens the case for change.
- **6.5 The nine empty and ten runtime-less repos.** What does "toolchain management" even mean
  for them? Verdict on whether they are in scope at all.
- **6.6 Verdict.** One sentence: is there a problem worth a new dependency, yes or no, and at
  what severity.

# 7. QUESTION 2 — Is `mise` the right instrument?

Answer must cover:

- **7.1 Capability-to-need mapping.** For each need identified in §6, state whether `mise`
  addresses it, partially addresses it, or does not. No marketing language; name the mechanism
  (`[tools]`, lockfile, `[env]`, `[tasks]`, backend).
- **7.2 Scored comparison.** Score, in a table not prose, at minimum these options:
  (a) **status quo plus targeted fixes** (`apt-mark hold`, extend `.terraform-version` to jol
  and jolarca, pin `jq`/`python3` in CI);
  (b) **extend the `viavitae-api` pattern** — SHA-pinned actions + workflow `env:` version
  variables, propagated to every repo by the existing scaffold-propagation guard;
  (c) **`mise`**, local only;
  (d) **`mise`**, local and CI;
  (e) **`.tool-versions` + native readers** (`setup-node`/`setup-python` `node-version-file`
  / `python-version-file`) with no new binary;
  (f) **`uv` + `direnv`**, both already installed;
  (g) **`asdf`** (the compatibility baseline `mise` claims to replace);
  (h) **devcontainer / Nix** (state why they are or are not viable for one operator on
  Ubuntu 24.04 with `nix` absent);
  (i) **OpenTofu** (licensing and BSL considerations for a charity and a PCI estate).
  Columns: reproducibility exactness, supply-chain surface added, CI compatibility, per-entity
  isolation (boundary 1), solo-operator burden, bus-factor recoverability, reversibility,
  auditability/evidence quality, PCI-DSS acceptability, framework clauses satisfied, and cost.
- **7.3 The `uv` + `direnv` overlap.** Both are already installed. Decide precisely what
  `mise` would own that they do not, and whether running all three is defensible under A.8.9
  (configuration management). If `mise` would only add Terraform and Node, say whether that is
  worth a new dependency.
- **7.4 The `tfenv` precedent.** Prior operator guidance rejected `tfenv` because it
  PATH-shadows `/usr/bin/terraform` and creates two sources of truth. Either refute that for
  `mise` with evidence about `mise`'s shims-vs-PATH behaviour and precedence, or inherit it as
  binding and conclude that terraform must stay apt-managed.
- **7.5 Release cadence.** `mise` ships several times a week. Assess what that means for
  pinning, for evidence retention ("which version produced this build?"), and for a
  single-operator estate that cannot track upstream weekly.
- **7.6 Verdict.** Exactly one of: **adopt fully** / **adopt partially (name the repos and the
  capabilities)** / **do not adopt (name the alternative from §7.2)**. With rationale and a
  rejection record for every option you discarded. "Do not adopt" must be argued as
  thoroughly as "adopt" — it is not a failure state.

# 8. QUESTION 3 — Per repository, or shared?

The operator's literal question: *"does mise need to be configured separately for each
repository?"* Answer it definitively.

Answer must cover:

- **8.1 Resolution semantics.** How `mise` actually resolves configuration: the walk-up order,
  global `~/.config/mise/config.toml` vs project `mise.toml` vs `.mise.toml` vs
  `.tool-versions`, which wins, and how `mise config ls` proves it. Cite the source you read.
- **8.2 The two-layer verdict.** Separate two things the naive question conflates: **where the
  file lives** (necessarily per directory, because that is how resolution works) from **where
  the version decisions are authored** (necessarily in one place, because 31 independently
  hand-written configs is 31 opportunities to drift). Give the concrete two-layer design, or
  reject it with reasons.
- **8.3 Scope: which repos get a file at all.** Produce a table of all 31 Via-Vitae repos with
  a verdict per repo: `in scope — runtime X` / `out of scope — no runtime` / `out of scope —
  empty` / `deferred — reason`. Justify the in-scope count. A blanket "all 31" is a contract
  violation unless you can defend it row by row.
- **8.4 Boundary 1 across the three entities.** Decide explicitly, with a reasoned verdict:
  (a) may one `mise.toml` be shared by repos in different orgs? (b) may one *global* config on
  the workstation govern all three planes? (c) does a shared tool cache
  (`~/.local/share/mise`) breach boundary 1, or does boundary 1 govern configuration and
  credentials only? (d) if a shared "toolchain policy" repo is proposed, which entity owns it,
  and does the charity's in-house-hardware principle permit it?
- **8.5 Generation vs authoring.** If files are per repo but versions are single-sourced, the
  files must be **generated and propagated**, not edited. Design that against the existing
  pattern (`scripts/propagate_landing_scaffold.py`, dry-run by default, `--apply` to write,
  per-repo PRs) and state where the generator lives and which entity owns it.
- **8.6 Worktrees and clones.** §4.5.b: what a worktree resolves to, what a fresh clone
  resolves to before `mise install`, and what CI resolves to on a clean runner.
- **8.7 Empty and private repos.** Nine repos are empty and five private repos are unreadable
  for advanced-security posture on the GitHub Free plan. State what "rolled out" can honestly
  mean for them, and refuse to report them as covered.
- **8.8 Verdict.** One paragraph, unambiguous, answering the operator's literal question first
  and then qualifying it.

# 9. QUESTION 4 — Supply chain, trust, and CI adoption

Answer must cover:

- **9.1 Install provenance.** `curl -fsSL https://mise.run | sh` executes an unpinned remote
  script as the operator. Assess against CC9.2, A.5.19–A.5.22 and A.8.19. §4.2 records that a
  `curl | sh`-free path exists (`mise generate install-script --localize --write` → a committed
  `bin/mise` that downloads a pinned release, honours `self_update.minimum_release_age`, and
  ignores global config) and that `mise self-update` verifies release signatures. Weigh that
  against apt/dnf packaging and a vendored binary with a recorded hash, and state which one you
  mandate and why. Note the bootstrap paradox: generating the wrapper requires `mise` to be
  installed first, so decide how the *initial* install is authenticated.
- **9.2 Backend provenance per tool.** `terraform`, `node`, `python`, `gh`, `jq` each arrive
  through a different backend with a different integrity story. Produce a table:
  `tool | backend | artifact source | integrity mechanism | who signs it | what a compromise
  looks like | detection`. §4.2 already records which backends verify by default — Node.js
  (OpenPGP-signed `SHASUMS256.txt`, signature **must** be present), precompiled Python and Ruby
  (GitHub artifact attestations), `aqua:`/`github:`/`packslip:` — and that **`terraform` appears
  in none of them**. Resolve the `terraform` backend before recommending `mise` manage it.
- **9.3 Lockfile.** §4.2 records the verified mechanics (`mise.lock`; `mise install --locked`
  fails closed on a missing entry or a URL with no checksum; `jdx/mise-action` adds `--locked`
  automatically when a lockfile is present; `.tool-versions` entries cannot be locked;
  `locked_scopes` and `[tool_config] locked` are global-only). Your job is the *consequence*:
  what the estate must commit, per platform, for the lock to actually cover the runner and the
  workstation; what happens when `mise.toml` and `mise.lock` disagree in a PR; and whether the
  upstream warning that "`mise.lock` verifies what mise downloads, not what is already on disk"
  makes a restored Actions cache an unverified trust input. Specify the cache design.
- **9.4 Trust model and the public-repo attack path.** 26 of 31 Via-Vitae repos are **public**.
  A `mise.toml` can execute code via `[env]`, hooks, templates and `[tasks]`. Walk the attack:
  an external contributor opens a PR that edits `mise.toml`; CI runs `mise install` /
  `mise run`. **§4.2 records the decisive fact: mise treats every config as trusted when `CI` is
  set, so the trust prompt provides zero protection in GitHub Actions.** Assess the two
  documented countermeasures on their actual terms: `MISE_PARANOID=1` (removes the CI exemption,
  turns on `locked_verify_provenance`, does not share trust across worktrees) and `MISE_SAFE=1`
  (refuses code execution but, per upstream's own warning, does **not** make `mise install`
  safe). Then give the residual controls: restricting `mise.toml` to the trust-free subset
  (plain-string `[tools]` + `[tasks]` with no `secrets`, no `[env]`, no hooks, no templates),
  ruleset path protection for `mise.toml` and `mise.lock`, CODEOWNERS, `pull_request` from forks
  running with no secrets, `permissions:` minimisation, and a CI step that diffs the PR's config
  against `main`. Per §4.7.a the `provenance` context **is** a required check with strict mode
  and `bypass_actors: []`, so a failing gate does block — but adding a *new* required context is
  an `apply`-gated ruleset change needing a compliance rationale.
- **9.5 The CI action and the allow-list.** Determine whether `jdx/mise-action` is admitted by
  `verified_allowed: true` (§4.6.a) or needs an explicit pattern. If a pattern is needed, give
  the exact `var.actions_allowed_patterns` change, note that it is a Terraform-managed live-org
  mutation (§3.5 gate), and state whether it should be SHA-pinned given
  `sha_pinning_required = false`. Also decide whether adopting `mise` in CI is the moment to
  turn SHA-pinning **on** org-wide, and what breaks if you do.
- **9.6 GitHub API rate limits and the token question.** GitHub-release-backed installs hit API
  rate limits; the documented mitigation is to give `mise` a GitHub token. §4.2 records that
  `jdx/mise-action` already passes the workflow's GitHub token to mise during install but does
  **not** export it to later steps, so a job that installs tools in a later step needs its own
  token. That means a potential **new secret in every repo's CI**. Assess against the
  least-privilege credential work already done (a read-only fine-grained PAT, a CI pre-flight
  gate that rejects write-capable tokens, and an explicit instruction never to mint a classic
  PAT to make CI green). Also weigh the lockfile answer: §4.2 records that with a `mise.lock`,
  mise takes versions from the lock and skips the lookup entirely, and that `mise-versions`
  supplies checksums without downloading — which may remove most of the rate-limit pressure and
  therefore most of the need for a token. Verdict: acceptable with a named token shape, avoidable
  by lockfile discipline, or a reason to keep `mise` out of CI entirely.
- **9.7 Telemetry and data flows.** Does `mise` phone home, report errors, or send anything to
  a third party? If yes, that is a processor relationship requiring GDPR Art. 28 assessment
  and an entry in `viavitae-vendor-register`. Verify from documentation or source; do not
  assume either way.
- **9.8 Regression check against §3.8.** Enumerate every existing control `mise` could
  displace or shadow — the `commit-msg` provenance hook and its hardcoded `.venv` interpreter,
  the `.terraform-version` CI assertion, gitleaks, the apt-managed terraform shared by three
  planes, the SHA-pinned `viavitae-api` actions — and for each state: unaffected / degraded /
  broken, with the evidence.
- **9.9 Verdict.** May `mise` be used locally? May it be used in CI? One sentence each, plus
  the non-negotiable conditions.

# 10. QUESTION 5 — Rollout, guard, and reversal

Only answer this if §7.6 is not "do not adopt". If it is, replace this section with the
rollout for the alternative you recommended, to the same depth.

Answer must cover:

- **10.1 Tiering.** Sequence by risk and value, not alphabetically. A defensible first tier is
  the repo with the demonstrated drift (`viavitae-control`), then the Python trio, then the
  Node quartet, then the shell repos. Justify your tiers and state the entry and exit criteria
  for each.
- **10.2 Per-repo change set.** The exact files added or modified per tier, the exact commands,
  the directory each runs from, and the expected output of each. Every mutating step carries
  the §3.5 gate line.
- **10.3 Dry-run-first propagation.** Follow the estate convention: preview without writing,
  human review, then `--apply` per repo, one PR per repo, small diffs (<100 lines mechanical),
  `ai:<tier>` trailer on every commit, squash-merge so the PR description becomes the
  provenance record on `main`.
- **10.4 The guard script.** Design a `scripts/` guard that makes the pinning invariant
  permanent, to the §4.8 contract: exit `0`/`1`/`2` with `2` for "nothing checkable"; no
  secrets; no network; placed **before** credential-dependent steps in `audit.yml`; registered
  as a row in `policies/README.md`. It must assert at minimum: every declared tool version
  resolves to exactly one value across all its declaration sites; a lockfile exists wherever a
  `mise.toml` exists; no in-scope repo has a config declaring a tool it does not use; no
  out-of-scope repo has a config at all. **Prove it sensitive by mutation** — list the injected
  defects and the exit code each must produce.
- **10.5 Verification, not assertion.** For each tier, the commands whose *output* proves
  success (`mise ls --current`, `mise config ls`, `mise doctor`, `mise run <task>`,
  `terraform version -json | jq -r .terraform_version`, `.venv/bin/pre-commit run --files …`,
  a commit that must be rejected without an `ai:` trailer). Agent claims are not evidence.
- **10.6 Reversal.** Per repo and estate-wide: what is deleted, what is uninstalled, what
  returns to apt, how the pre-commit `.venv` wiring is restored, and how you prove the estate
  is back to the §4.4 baseline. A rollout with no tested reversal is not a plan.
- **10.7 Bus factor.** The operator is incapacitated for 90 days. A successor with repo access
  and no tribal knowledge must rebuild a working development environment from the repositories
  alone. State exactly which commands they run, in order, and what in §4.4 is *not* currently
  recoverable that way — then say whether your design fixes that.
- **10.8 Cost.** Realistic elapsed time for one person working part-time, per tier, plus the
  recurring maintenance cost per quarter (pin bumps, lock refreshes, `mise` upstream releases
  several times a week). If the recurring cost exceeds the drift it prevents, say so.
- **10.9 Roadmap.** An ordered, prerequisite-marked sequence. Realistic for one human, not a
  parallel fantasy.

# 11. OUTPUT CONTRACT

Structure the entire reply as follows. Do not deviate.

- **§0 Verification results.** The `CONFIRMED` / `STALE` / `CANNOT VERIFY` / `INFERRED` table
  from §5, including the §4.5 local-vs-declared-vs-live reconciliation and the §4.6.a
  verified-creator determination for `jdx`.
- **§1 Executive verdict.** Ten lines maximum: the five answers, one line each, plus the three
  highest-risk findings. If the verdict on Question 2 is "do not adopt", the first line must
  say so.
- **§2 Question 1** … **§6 Question 5**, each following its own sub-numbering. Every
  paragraph making a claim must be broken into lettered or numbered sub-points. Each step must
  be executable: name the file, the command, or the UI path. Mutating steps carry the §3.5
  gate line.
- **§7 Control mapping table.** Columns: `framework clause (SOC 2 / ISO 27001 Annex A / GDPR /
  PCI-DSS) → implemented control → which question it came from → evidence artifact that proves
  it → status (implemented / gap / compensating / regression)`.
- **§8 Findings register.** Each finding: `ID` (existing entity scheme, e.g. `VV-2026-11-NNN`,
  verified non-colliding) `| severity (P0/P1/P2) | entity affected | root cause | compensating
  control in place today | remediation | effort estimate`.
- **§9 Ordered remediation roadmap.** Sequenced for one person working part-time, with
  prerequisites marked.
- **§10 What I could not determine.** Explicit list. This section **may not be empty and may
  not be omitted.** If you believe you determined everything, you did not verify enough.
- **§11 Residual risk accepted.** What remains unmitigated after the full roadmap, and why that
  is tolerable for a single-operator charity, a free-tier commercial entity, and a PCI-scoped
  marketplace.
- **§12 Self-audit checklist.** A table with one row per numbered sub-requirement in §6–§10 of
  this prompt (6.1 … 10.9) plus the formatting rules below. Columns:
  `requirement | section of your reply that answers it | verdict given (yes/no/N-A + reason)`.
  Every row must be filled. An unfilled row is a contract violation.

Formatting rules:

- Define every acronym and technical term at first use.
- Prefer a table over a paragraph wherever there are three or more comparable items.
- Every command must be copy-pasteable and must state the directory it runs from.
- Every "should" or "must" must be accompanied by the framework clause it satisfies.
- Every `mise` capability claim must cite the documentation page or `--help` output you read.
- Length is not a virtue. Completeness and correctness are.

**WORKED EXAMPLE of the expected depth** (illustrative form only, not a recommendation):

> 9.4.c A pull request that edits `mise.toml` executes code in CI before any human reads it.
> c.1. Mechanism: `[env]` values, entry hooks and `[tasks]` bodies are interpreted by `mise`
> when the workflow runs `mise install` or `mise run`. The workflow file itself is unchanged,
> so a reviewer scanning the diff for `uses:` and `run:` lines sees nothing suspicious in the
> YAML — the payload is in the TOML.
> c.2. Control failure: A.8.4 (source code protection) and A.8.28 (secure coding) — code
> execution was introduced through a configuration file that no path-protection rule covers;
> SOC CC8.1 — the change reached an execution environment without authorisation.
> c.3. Aggravating facts: 26 of 31 Via-Vitae repos are public, so the contributor pool is the
> internet; mise treats every config as trusted when `CI` is set, so the trust prompt never
> fires in a runner; and `MISE_SAFE=1` is not a fix for `mise install`, which upstream warns can
> still build a tool from source. The one gate that does block is `provenance` (§4.7.a) — and it
> checks the commit trailer, not the TOML payload.
> c.4. Verify today: `gh api repos/Via-Vitae/viavitae-control/rulesets/23943250 | jq '.rules'`
> (read-only; run from anywhere) and confirm which contexts are actually required.
> c.5. Control required: restrict `mise.toml` to the trust-free subset, set `MISE_PARANOID=1` in
> the runner environment, add path protection for `mise.toml` and `mise.lock` to the ruleset,
> plus a CI step diffing the PR's config against `main` before any `mise` command runs.
> c.6. Rejection consequence: if path protection cannot be enforced on the Free plan for the
> private repos, `mise` must not be adopted in those repos' CI at all — the control is
> unavailable, so the risk is unmitigable there.

# 12. STOP CONDITIONS

Halt and report instead of answering if:

1. A baseline fact in §4 is contradicted by the live tree or API and the contradiction changes
   the recommendation.
2. You are asked to state a `mise` capability, version, SHA, config setting, lockfile name, or
   CLI flag you have not read in documentation or `--help`.
3. A recommendation would require a second human being to operate. Say so, and propose the
   compensating control instead.
4. A recommendation depends on a paid GitHub tier, a vendor contract, an AWS Organizations
   change, or an upstream `mise` feature that does not exist. Flag the dependency *before* the
   recommendation.
5. The correct answer is "do not do this" — say it plainly rather than softening it. This is
   an expected outcome, not a failure.
6. Two frameworks conflict (e.g. PCI-DSS Req. 11.3 integrity monitoring versus GDPR Art. 5(1)(c)
   data minimisation on build telemetry). Surface the conflict and resolve it explicitly; never
   silently pick one.
7. You cannot determine something. Write it into §10 of the output. Never fill the gap with a
   plausible guess.
8. A step you are about to emit mutates the machine, a repository, Terraform state, or live org
   configuration and lacks the §3.5 approval gate. Halt, add the gate, continue.
9. Adopting `mise` would degrade an existing control (§3.8). Report the regression against the
   recommendation; do not bury it in the rollout plan.
10. Your design would share configuration, tokens, secrets, CI files, or state across two of
    the three entities. Stop — that is boundary 1, and no convenience justifies it.
11. The estate census you observe differs materially from §4.5 (for example a repo gains or
    loses a runtime). Reconcile before scoping; a rollout scoped against a stale census misses
    repos or writes config into empty ones.

# 13. ANTI-PATTERNS — reject these in your own output

- Recommending `mise` without first proving, from the live trees, that a pinning problem exists.
- Recommending `mise` as the fix for the **GitHub Actions reference drift** measured in §4.6.
  `mise` does not manage `uses:` lines; claiming otherwise is a category error.
- Assuming `mise`'s trust prompt protects CI. It does not: `CI` being set makes mise trust
  every config silently (§4.2).
- Proposing `MISE_SAFE=1 mise install` on untrusted branches as a mitigation, against upstream's
  explicit warning that safe mode does not make `mise install` safe.
- Writing a `mise.toml` into all 31 repos because "consistency", including the nine empty and
  the 21 with no runtime manifest.
- Emitting `curl -fsSL https://mise.run | sh` as the install method without a provenance
  verdict, when a pinned committed `bin/mise` wrapper is documented (§4.2).
- Recommending a floating tool version (`"1.16"`, `"22"`) with no `mise.lock`, then claiming
  reproducibility.
- Adding `jdx/mise-action@*` to the allow-list — a new floating pattern in an org that already
  has nine — without addressing `sha_pinning_required`, and without noting that upstream's own
  documented example uses floating `@v5`.
- Recommending CI adoption without answering the GitHub-token-rate-limit question (§9.6).
- Ignoring that `uv` is already installed **and already used**, with eight committed `uv.lock`
  files and `astral-sh/setup-uv` SHA-pinned in CI.
- Ignoring that `make` is the established task-runner convention in two of the three planes,
  with gate semantics already encoded in `jol-control`'s Makefile.
- Ignoring the prior `tfenv` rejection (PATH-shadowing `/usr/bin/terraform`, two sources of
  truth) instead of refuting or inheriting it.
- Letting a `mise`-managed `python` silently break the hardcoded `.venv` interpreter in
  `.git/hooks/commit-msg`, degrading the `ai:<tier>` provenance trail.
- Repeating the stale claim from `AI_WORKFLOW_POLICY.md` §8 that `protect-main` has no required
  status checks. §4.7.a measured `provenance` as required, strict, with no bypass actors.
- Sharing one config, one lockfile, or one policy repo across Via-Vitae, `journeyoflife-org`
  and `jolarca-dev` because all three sit on one workstation.
- Sharing a restored Actions tool cache across untrusted refs, against upstream's warning that
  an installed tree is never validated against `mise.lock`.
- Reporting an empty or private repo as "covered" when its posture is unobserved or unreadable
  on the Free plan.
- Presenting a comparison with no verdict, or citing a framework clause without naming it.
- Proposing a rollout with no tested reversal path and no per-tier exit criteria.
- Proposing a guard script that exits `0` when it inspected nothing.
- Treating "no team" as a reason to weaken controls rather than to add compensating ones.
- Recommending any tool absent from the host without giving the install command and its
  provenance.
- Answering with a rollout when the honest answer is that `sudo apt-mark hold terraform`, a
  Node 22 install to match the declared `NODE_VERSION`, extending `.terraform-version` to jol
  and jolarca, and a propagated single-source version manifest close most of the measured risk
  without a new dependency.
~~~~

---

## Provenance

Baseline facts recorded from, on 2026-11-03:

- Host probes on `jol`: `command -v` over `mise asdf tfenv nvm uv direnv nix python3 node jq
  terraform gh`; `apt-mark showhold`; `dpkg-query -W terraform` → `1.16.1-1`;
  `terraform version -json`; `uv --version` → `0.12.17`; `direnv version` → `2.32.1`
- `.terraform-version` presence check across the three control planes → present only in
  `viavitae-control` (`1.16.1`)
- Runtime census over `/opt/viavitae/repos` (34 directories; `package.json`,
  `requirements*.txt` / `pyproject.toml`, `*.tf`, `*.sh` per repo)
- Idiomatic-version-file `find` across all three trees → exactly two hits:
  `viavitae-control/.terraform-version`, `viavitae-web/.nvmrc` (`22`)
- `viavitae-control/.github/workflows/audit.yml` (the `setup-terraform@v4` +
  `terraform_version: 1.16.1` + `Assert toolchain pin` triple),
  `.pre-commit-config.yaml`, `org_actions_policy.tf`, `policies/README.md`,
  `policies/AI_WORKFLOW_POLICY.md`
- `grep -rn` over `/opt/viavitae/repos/*/.github/workflows/*.yml` → SHA-pinned actions and
  `env:`-sourced runtime versions in `viavitae-api`
- Live API: `gh api orgs/Via-Vitae/actions/permissions/selected-actions`
- Upstream documentation read: <https://mise.jdx.dev/> and
  <https://mise.jdx.dev/getting-started.html> (install, `mise.toml` sections, prefix-vs-exact
  versions and lockfiles, the trust model, idiomatic version files, backends and GitHub API
  rate limits, shell activation vs shims, `mise bootstrap`, CI action, MIT licence, Rust,
  release cadence)

Revision history:

- v1 (2026-11-03): initial prompt asset. Authored from the operator's rough request
  ("the project needs mise-en-place; add it to Via-Vitae's 31 repositories; does each repo need
  its own?") after correcting the tool's name, verifying that `mise` is absent from the host,
  establishing the real pinning baseline (§4.4), censusing which repos have a runtime at all
  (§4.5), and recording the two contradictory CI supply-chain patterns already in the estate
  (§4.6). Verdict space deliberately left open (§7.6) so "do not adopt" is a scored answer.
- v1.1 (2026-11-03, same day): baseline re-verified before first use, which **falsified four
  v1 claims** and they are corrected in place. (i) §4.6 said "two contradictory patterns"
  (`viavitae-api` good, `viavitae-control` bad); the full census shows **29 of 31** Via-Vitae
  repos are 100% SHA-pinned and only `viavitae-control` (2 refs) and `viavitae-hermes-agents`
  (3 refs) float — while `jolarca`, the PCI-DSS repo, is the estate's worst at 45 floating refs
  and `jol-control` at 16. (ii) §4.4 said "exactly two idiomatic version files"; there are
  three (`jol-ecommerce-engine/.nvmrc` was missed) plus eight committed `uv.lock` files.
  (iii) §4.5.a said 19 of 31 repos have no runtime; the manifest census gives **21**, and §4.5.a-i
  now records that manifest-absence is not runtime-absence because all ten landing scaffolds run
  a 32-reference SHA-pinned CI declaring Node 22 and Python 3.12. (iv) §9.4 and the worked
  example repeated the `AI_WORKFLOW_POLICY.md` §8 claim that `protect-main` has no required
  status checks; the live ruleset requires the `provenance` context in strict mode with
  `bypass_actors: []` (§4.7.a). Also added: verified mise security mechanics to §4.2 (the CI
  trust exemption, safe-mode limits, paranoid mode, `mise.lock` fail-closed behaviour,
  `minimum_release_age`, per-backend download verification, the `mise-versions` supplier, and
  the committed `bin/mise` wrapper), the proven **host `node` v20 vs declared 22 divergence**,
  the `make` task-runner convention, and the measured cross-repo action-SHA drift (~40 distinct
  refs for ~19 action names).

Related artifacts: [AI_WORKFLOW_POLICY.md](../../../policies/AI_WORKFLOW_POLICY.md) ·
[AUDIT_PROMPT.md](../../../policies/AUDIT_PROMPT.md) ·
[allowed_actions.md](../../../policies/allowed_actions.md) ·
[COMPLIANCE.md](../../COMPLIANCE.md) ·
[2026-10-19 multi-org secrets and state architecture prompt](2026-10-19-multi-org-secrets-and-state-architecture-prompt.md) ·
[plans/TEMPLATE.md](../plans/TEMPLATE.md)
