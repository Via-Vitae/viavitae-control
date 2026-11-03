# mise Toolchain Adoption — Decision Package

| Field | Value |
| --- | --- |
| Created | 2026-11-03 |
| Repo | viavitae-control |
| Type | Decision package — the executed answer to a prompt asset, not a plan and not a policy |
| Source prompt | [2026-11-03-mise-toolchain-management-prompt.md](../prompts/2026-11-03-mise-toolchain-management-prompt.md) v1.1 |
| Scope | Via-Vitae (31 repos), journeyoflife-org (41 repos), jolarca-dev (16 repos) — three planes, one workstation |
| Frameworks | SOC 2 Type II, ISO/IEC 27001:2022 Annex A, GDPR, PCI-DSS 4.0 (jolarca-dev only) |
| Operator model | Single owner, single programmer, no teams, no separation of duties |
| Evidence basis | Live host probes, `uses:` and manifest censuses over all three local trees, live `gh api` reads, and four upstream mise documentation pages — all 2026-11-03 |
| Authority | **Plan-only.** Nothing in this document was applied, pushed, or installed. Every mutating step below carries a printed gate. |

> ## VERDICT: **DO NOT ADOPT `mise`.**
>
> Not locally, not in CI, not in any of the three planes. The measured drift in this estate is
> in **GitHub Actions references and duplicated workflow `env:` version variables** — neither of
> which `mise` manages. The one thing `mise` would genuinely fix (host/CI tool divergence) has a
> cheaper fix, and moving `terraform` from a publisher-signed apt channel to a `mise` backend
> with **no documented signature verification** is a provenance regression, not an improvement.
> Recommended instead: targeted host fixes, one single-sourced version manifest per control
> plane, idiomatic version files read natively by the `setup-*` actions already SHA-pinned in
> 29 of 31 repos, and `uv` retained for Python. Full reasoning in §3; rollout in §6.

---

## §0 Verification results

Every row of the prompt's §4 baseline was re-checked before answering. Verdicts use the
contract in §5 of the prompt.

| Fact asserted in the prompt | Verdict | Evidence |
| --- | --- | --- |
| `mise` absent from host | CONFIRMED | `command -v mise` returns nothing |
| `asdf`, `tfenv`, `nvm`, `nix` absent | CONFIRMED | `command -v` probe, all four empty |
| `uv` present, 0.12.17 | CONFIRMED | `uv --version` |
| `direnv` present, 2.32.1 | CONFIRMED | `direnv version` |
| terraform apt-managed, dpkg `1.16.1-1`, `/usr/bin/terraform` | CONFIRMED | `dpkg-query -W terraform` |
| terraform **not** apt-held | CONFIRMED | `apt-mark showhold` does not list it |
| `.terraform-version` present only in viavitae-control | CONFIRMED | jol-control and jolarca-control both ABSENT |
| Host `node` v20.20.2 vs declared `NODE_VERSION: "22"` | CONFIRMED — **live divergence** | `node --version` then grep of workflow `env:` blocks |
| Host `python3` 3.12.3, `jq` 1.7, `gh` 2.100.0 | CONFIRMED | `--version` probes |
| `pre-commit` absent from `PATH`, present as 4.7.0 in `.venv` | CONFIRMED | `command -v pre-commit` empty; `.venv/bin/pre-commit --version` |
| Via-Vitae holds 31 repos | CONFIRMED | 30 visible clones plus hidden `.github`; 43 minus 4 worktrees minus non-org entries reconciles |
| 21 of 31 Via-Vitae repos declare no runtime manifest | CONFIRMED (v1 said 19 — **corrected**) | manifest census |
| Nine Via-Vitae repos empty at default branch | CANNOT VERIFY from the shell this pass | carried from the 2026-10-26 audit; not re-measured |
| `commit-msg` hook hardcodes `INSTALL_PYTHON` to the repo `.venv` | CONFIRMED | `.git/hooks/commit-msg` line 6, plus `exec "$INSTALL_PYTHON" -mpre_commit` |
| Both git hooks installed | CONFIRMED | `.git/hooks/pre-commit` and `commit-msg`, dated Oct 17 |
| Org allow-list: 9 floating patterns plus 2 SHA pins, `sha_pinning_required: false` | CONFIRMED | live `gh api orgs/Via-Vitae/actions/permissions/selected-actions` and `/actions/permissions` |
| `jdx/mise-action` not in the allow-list | CONFIRMED | absent from `patterns_allowed` |
| `jdx/mise-action` exists, MIT, active | CONFIRMED | `gh api repos/jdx/mise-action` — 401 stars, pushed 2026-11-02, not archived |
| `jdx` is a GitHub **verified creator** | **CANNOT VERIFY** | verified-creator status is not exposed by the REST API; see §10 |
| `protect-main` ruleset has **no** required status checks | **STALE — the opposite is true** | ruleset 23943250 requires context `provenance`, `strict_required_status_checks_policy: true`, `bypass_actors: []` |
| Only `viavitae-api` is SHA-pinned (prompt v1 claim) | **STALE — falsified** | 29 of 31 Via-Vitae repos are 100 % SHA-pinned; only `viavitae-control` (2 refs) and `viavitae-hermes-agents` (3 refs) float |
| Exactly two idiomatic version files estate-wide (v1 claim) | **STALE — falsified** | three: plus `/opt/jol/repos/jol-ecommerce-engine/.nvmrc` |
| `uv` and `direnv` merely "installed and overlapping" (v1 claim) | **STALE — understated** | `uv` is in active use: 8 committed `uv.lock` files and `astral-sh/setup-uv@<sha>` in CI. `direnv` is used in 2 directories, neither in Via-Vitae |
| `mise.lock` exists and fails closed | CONFIRMED from upstream docs | `dev-tools/mise-lock.html` |
| mise trusts every config when `CI` is set | CONFIRMED from upstream docs | `security.html#configuration-trust` |
| `MISE_SAFE=1` does **not** make `mise install` safe | CONFIRMED from upstream docs | upstream WARNING, `security.html#safe-mode` |
| terraform's `mise` backend and its verification | **CANNOT VERIFY** | `mise` absent, so `mise tool terraform` cannot run; `registry.toml` not retrievable via the contents API; see §10 |
| `mise` telemetry behaviour | **CANNOT VERIFY** | not stated on the four pages read; see §10 |
| Local-vs-declared inventory reconciliation against `repos_data.tf` | NOT PERFORMED this pass | recorded as an open item in §10 rather than asserted |

**Three prompt-baseline claims were falsified by the evidence and have already been corrected in
the prompt asset at revision v1.1.** They are listed here because two of them would have changed
the recommendation: believing only `viavitae-api` was pinned would have made "extend that
pattern" look like new work rather than a 2-repo gap, and believing `protect-main` had no
required checks would have understated an existing blocking control.

---

## §1 Executive verdict

1. **Q1 — does the problem exist?** Yes, but it is four problems, and the largest is not a
   local-toolchain problem.
2. **Q2 — is `mise` the right instrument?** **No. Do not adopt.**
3. **Q3 — per repository or shared?** Neither, for `mise`. Versions single-sourced per control
   plane; files per repo; **10 of 31** Via-Vitae repos in scope, not 31.
4. **Q4 — may `mise` be used locally or in CI?** No to both, for two independent decisive
   reasons (§5.4, §5.2).
5. **Q5 — what to do instead?** Six tiers, §6, starting with a 20-minute host fix that needs no
   PR at all.
6. **Highest-risk finding 1:** `jolarca` — the PCI-DSS 4.0 repo — carries **45 floating action
   references**, the worst in the entire estate (§8, VV-2026-11-001).
7. **Highest-risk finding 2:** the same action resolves to **different commits in different
   repos** — roughly 40 distinct references for 19 action names in Via-Vitae alone (§8, -002).
8. **Highest-risk finding 3:** `policies/AI_WORKFLOW_POLICY.md` §8 describes a **blocking**
   control as advisory and states an admin can still merge; the live ruleset contradicts it
   (§8, -006). Understating your own controls is an audit defect in the same class as
   overstating them.
9. Nothing was applied, installed, pushed, or mutated. Plan-only authority held throughout.
10. `mise` remains a defensible tool; it is simply aimed at a problem this estate mostly does
    not have, and it would trade a signed apt channel for an unverified one.

---

## §2 Question 1 — Does the problem exist, and is it worth solving?

### 2.1 Evidence table (prompt §6.1)

| Artifact | Declared where | Exact | Enforced by | Observed drift today | Blast radius if it moves | Clause |
| --- | --- | --- | --- | --- | --- | --- |
| terraform, host | dpkg `1.16.1-1` | yes | **nothing** — not apt-held | none yet; unbounded | plan and apply behaviour across all three planes, including state format | ISO A.8.9, SOC CC8.1 |
| terraform, Via-Vitae CI | `audit.yml` `terraform_version: 1.16.1` **and** `.terraform-version` **and** the `Assert toolchain pin` step | yes, three times | the assertion step | none — assertion is green | low while the assertion runs | SOC CC7.1 |
| terraform, jol and jolarca CI | no pin file at all | no | nothing | unbounded | charity plane and **PCI-DSS** plane | PCI 2.2, ISO A.8.9 |
| node, host | `/usr/bin/node` v20.20.2 | n/a | nothing | **YES — contradicts every repo's declared 22** | local builds and tests disagree with CI | ISO A.8.25, A.8.29 |
| node, CI | `NODE_VERSION: "22"` re-declared per workflow file per repo | prefix only | `actions/setup-node@<sha>` | consistent value, ~40 separate declarations | a bump is a hand edit to dozens of files with no gate | SOC CC8.1 |
| python, host | `/usr/bin/python3` 3.12.3 | n/a | nothing | agrees with declared `3.12` **by coincidence** | silent on the next distro bump | ISO A.8.9 |
| python deps | `uv.lock` in 8 repos | **yes** | `astral-sh/setup-uv@<sha>` | none | solved | SOC CC7.1 |
| pre-commit | git-ignored `.venv` only; absent from `PATH`; 4.7.0 | no | nothing | not reproducible from the repo | hooks do not fire on a fresh clone, so gitleaks and the provenance trailer go unenforced locally | ISO A.8.4, SOC CC8.1 |
| jq, gh | distro packages | no | nothing | unpinned locally and in CI | a CI gate can change behaviour on a runner-image refresh | ISO A.8.9 |
| GitHub Actions refs | 29 of 31 Via-Vitae repos fully SHA-pinned | yes, per repo | nothing cross-repo | **same action, different commits, across repos** | a reviewed SHA in one repo is not the code running in another | SOC CC9.2, ISO A.5.21 |

### 2.2 The three-copies problem (prompt §6.2)

a. **Verdict: it is a compensating control, not a defect — but a weak one, and it is the only
   one of the three planes that has it.**
b. Mechanism: `.terraform-version` declares `1.16.1`; `audit.yml` passes `1.16.1` to
   `hashicorp/setup-terraform`; the `Assert toolchain pin` step compares the file against
   `terraform version -json` and exits 1 on mismatch.
c. Why it is weak: the assertion is **detection after the fact**, not **prevention at source**.
   It fires only in Via-Vitae, only when `audit.yml` runs, and only after the wrong version has
   already been installed into the job. Detection-in-CI and pinning-at-source are different
   control classes; ISO A.8.9 asks for the configuration to be *defined* correctly, not merely
   checked.
d. Collapse it to one source without losing the check: add a step that reads the file into an
   output, then feed that output to `setup-terraform`. Run from `viavitae-control`:
   ```yaml
   - name: Read terraform pin
     id: tfpin
     run: echo "version=$(cat .terraform-version)" >> "$GITHUB_OUTPUT"
   - uses: hashicorp/setup-terraform@<sha>
     with:
       terraform_version: ${{ steps.tfpin.outputs.version }}
   ```
   The `Assert toolchain pin` step stays — it now proves the pin was *honoured*, which is the
   only thing worth asserting once there is a single source.
e. `STOP — human approval required before this step`: editing `audit.yml` is a workflow change,
   needs a PR, an `ai:<tier>` trailer, and the §5 review checklist sign-off.

### 2.3 The unpinned host (prompt §6.3)

a. **The cheapest fix in this entire assessment is one command**, and it closes the accidental-
   upgrade path completely:
   ```bash
   sudo apt-mark hold terraform      # run from anywhere; requires root
   ```
   `STOP — human approval required before this step`: mutates the host package manager state and
   affects all three planes at once.
b. Verify it took: `apt-mark showhold` must print `terraform`. Today it prints nothing.
c. **What the hold does not fix — the residual 20 %:**
   c.1. A hold freezes the *installed* version. It does not record *which* version a fresh
        machine should install. A successor rebuilding the host gets whatever
        `apt.releases.hashicorp.com` serves that day.
   c.2. It does not touch jol-control or jolarca-control, which have no `.terraform-version`
        file at all — so their CI has no declared pin to diverge from, and no assertion to catch
        divergence.
   c.3. It does not touch `node`, `python3`, `jq`, `gh`, or `pre-commit`, none of which are
        pinned anywhere on the host.
d. **Verdict:** do the hold. It is necessary. It is not sufficient, and it is not a reason to
   defer the manifest work in §6.

### 2.4 CI/local divergence, quantified (prompt §6.4)

a. **Exactly one live divergence was measured:** host `node` v20.20.2 against a declared
   `NODE_VERSION: "22"` in every repo that declares one, and `viavitae-web/.nvmrc` = `22`.
b. Python agrees (host 3.12.3 against declared `3.12`) — but by coincidence of the Ubuntu 24.04
   default, not by control. The next distro series breaks it silently.
c. **Recorded incidents: zero.** No CI failure log, no finding in
   `docs/security/pre-deployment-independent-audit-2026-10-26.md`, and no entry in
   `docs/COMPLIANCE.md` attributes a defect to a local/CI tool mismatch.
d. That matters for instrument selection. A real-but-unmaterialised risk justifies a **cheap
   preventive control**. It does not justify a new supplier, a new lockfile format, a new CI
   action, and a new trust model.
e. **Verdict:** the divergence is real and should be fixed this week, by installing Node 22 or
   by changing the declaration to 20 — a decision, not a tool.

### 2.5 The nine empty and twenty-one runtime-less repos (prompt §6.5)

a. 21 of 31 Via-Vitae repos declare no `package.json`, no `requirements*.txt` and no
   `pyproject.toml`. Nine are empty at the default branch (carried from the 2026-10-26 audit;
   not re-measured this pass).
b. **But manifest-absence is not runtime-absence.** All ten landing scaffolds and
   `viavitae-template` carry a **32-reference, fully SHA-pinned** CI that declares
   `PYTHON_VERSION: "3.12"` *and* `NODE_VERSION: "22"` and invokes `astral-sh/setup-uv`,
   `aquasecurity/trivy-action` and `trufflesecurity/trufflehog`.
c. So those repos **install a Python toolchain and a Node toolchain for code the census cannot
   see.** Two readings, and both are findings:
   c.1. They contain trivial source (the estate has a recorded `print_hi`-stub pattern) and the
        CI is proportional — in which case the census understated them and they are in scope for
        version declarations.
   c.2. The CI was inherited wholesale from `viavitae-template` and installs toolchains the repo
        never uses — in which case it is wasted runner time and **extra supply-chain surface in
        repos that need none**.
d. Determining which is true requires reading each scaffold's source tree, which this pass did
   not do. Recorded in §10.
e. **Verdict:** for a *toolchain manager*, all 21 are out of scope — there is nothing to manage.
   For a *version manifest*, the 11 that run CI are in scope, because their CI declares versions.
   The existing declared practice — trim generated config per repository type at the template
   level — is the right instrument here, and it already exists.

### 2.6 Verdict on Question 1

**Yes, a reproducibility problem exists.** Severity: **Medium** estate-wide, **High** for the
PCI-DSS plane's floating references. But it decomposes into four distinct problems, and only one
of them is a local-toolchain problem:

| Problem | Size | Does a version manager fix it? |
| --- | --- | --- |
| P1 Host/CI tool divergence (node 20 vs 22, no pre-commit, unpinned jq and gh, terraform unheld) | small, measured | yes — but so does a 20-minute host fix |
| P2 Cross-repo declaration drift (≈40 distinct action refs for 19 names; `NODE_VERSION` and `PYTHON_VERSION` duplicated in ~40 workflow files; `terraform_version` in three places) | **largest** | **no** |
| P3 Per-repo pinning discipline gaps (`viavitae-control` 2, `viavitae-hermes-agents` 3, `jolarca` 45, `jol-control` 16, roughly 150 across the charity plane) | large, concentrated | **no** |
| P4 No bootstrap path — a successor cannot rebuild a working environment from the repositories | medium, unquantified | partially |

P2 and P3 together are the majority of the measured risk, and **no version manager addresses
either**, because neither is about local binaries. That single observation drives §3.

---

## §3 Question 2 — Is `mise` the right instrument?

### 3.1 Capability-to-need mapping (prompt §7.1)

| Need from §2.6 | Does `mise` address it | Mechanism | Verdict |
| --- | --- | --- | --- |
| P1 Exact, reproducible local tool versions | yes | `[tools]` plus `mise.lock` plus `mise install --locked` | genuine fit |
| P1 Local and CI select the same versions | yes | one `mise.toml` read by both | genuine fit — **its strongest argument** |
| P1 Host node 22 | yes | `[tools] node = "22"` | but any Node 22 install does this |
| P1 pre-commit reproducible | yes | `[tools]` or a `pypi:` backend entry | genuine fit |
| P1 terraform pinned and held | technically yes | `[tools] terraform = "1.16.1"` | **rejected on provenance — see 3.4** |
| P2 One source for versions across repos | **no** | mise's source is per config root, i.e. per directory | cross-repo still needs a propagator |
| P2 Cross-repo action-SHA drift | **no** | mise does not manage `uses:` lines | out of scope entirely |
| P2 Duplicated `NODE_VERSION` / `PYTHON_VERSION` env vars | **no** | those feed `actions/setup-*`, which mise would *replace*, not populate | replacing them is a larger change than fixing them |
| P3 Floating refs in `jolarca`, `jol-control`, `viavitae-control` | **no** | same reason | out of scope |
| P4 Successor bootstrap | partially | `mise install` plus `mise bootstrap` | genuine fit, but a 40-line `bootstrap.sh` does it with no new supplier |
| Per-directory version switching | yes | this is mise's headline feature | **zero demand — see 3.1.a** |

a. **The decisive observation.** Every repo in this estate that declares a Node version declares
   `22`. Every repo that declares a Python version declares `3.12`. Every plane that declares a
   Terraform version declares `1.16.1`. **There is no per-directory version divergence anywhere
   in the three-plane estate.** mise's core value proposition — "switch automatically as you move
   between directories" — has no consumer here. You would be adopting a polyglot version
   switcher into a monolinguous-version estate.
b. What remains is mise's *secondary* value: one file that declares the versions, and a lock
   that makes them exact. Both are real. Both are also obtainable from a committed
   `.tool-versions` file plus the `setup-*` actions' native `node-version-file` /
   `python-version-file` inputs — with no new binary, no new supplier, and no CI trust hole.

### 3.2 Scored comparison (prompt §7.2)

| Option | Exact reproducibility | New supplier added | CI change required | Solo-operator burden | Reversible | Verdict |
| --- | --- | --- | --- | --- | --- | --- |
| (a) Status quo plus targeted fixes | partial — host pinned, CI unchanged | none | none | lowest | trivial | **ADOPT — necessary regardless of everything else** |
| (b) Single-source manifest plus propagation | yes for every declared value | none | generator rewrites workflow `env:` blocks and action SHAs | low-medium one-off, then near zero | yes — all git-tracked | **ADOPT — the only option that touches P2 and P3, the largest measured risk** |
| (c) `mise`, local only | yes | jdx plus `mise-versions.jdx.dev` | none | medium — lock bumps, upstream tracking | medium | REJECTED — solves P1, the smallest problem, and adds a supplier |
| (d) `mise`, local and CI | yes | as (c) plus `jdx/mise-action` | **every workflow in scope** | high | hard | **REJECTED — the CI trust exemption, §5.4** |
| (e) `.tool-versions` plus native `setup-*` file inputs | yes — the file holds exact versions | none | small — swap a version input for a file input | low | trivial | **ADOPT as part of (b)** — and mise reads `.tool-versions` natively, so the door stays open with no commitment |
| (f) `uv` plus `direnv` | yes for Python deps | none — both already installed | none | none | n/a | **ALREADY ADOPTED for Python** — extend, never replace |
| (g) `asdf` | yes | asdf plus per-language plugins | every workflow | high | medium | REJECTED — strictly worse than mise, and there is no `.tool-versions` legacy to inherit |
| (h) devcontainer or Nix | yes, strongest of all | Docker Hub or the Nix channel | every workflow plus a runner capable of nested containers | **very high for one person** | hard | REJECTED — `nix` is absent, devcontainer adds an image supply chain larger than the problem, and the operator model cannot support it |
| (i) OpenTofu instead of Terraform | n/a | a different publisher | provider compatibility review | medium | hard | **OUT OF SCOPE** — a separate decision; noted only because it would change the provenance story in 3.4 |

Rejection record, as required by prompt §3.4:

- (c) and (d) rejected because they address P1 only, and P1 has a 20-minute fix (2.3, 2.4).
- (d) additionally rejected on an independent, decisive ground: §5.4.
- (g) rejected because asdf is the compatibility baseline mise was written to replace; adopting
  it would mean adopting mise's costs without mise's lockfile.
- (h) rejected on operator-model grounds, not technical ones. Nix would give the strongest
  reproducibility in this table. One human, part-time, cannot maintain a Nix flake estate across
  three legal entities and also do everything else in the register.
- (i) deferred, not rejected. It is a licensing and provenance question that deserves its own
  assessment.

### 3.3 The `uv` and `direnv` overlap (prompt §7.3)

a. **`uv` is not a hypothetical overlap — it is the incumbent.** `uv.lock` is committed in eight
   repositories including `viavitae-api` and `viavitae-hermes-agents`, and
   `astral-sh/setup-uv@<sha>` is SHA-pinned in CI. Python dependency management is **solved,
   exactly, and reproducibly**, and it is already inside the estate's pinning discipline.
b. `direnv` is installed and used in exactly two directories — `jol-hub/data/.envrc` and
   `jolarca/.envrc` — **neither in Via-Vitae**. For this org the `[env]` overlap is theoretical.
   Do not overstate it, and do not use it as an argument.
c. **Verdict:** `uv` stays and is the Python answer. Adding `mise` on top would put three tools
   in contention over `PATH`, `VIRTUAL_ENV` and interpreter resolution — a configuration-
   management defect under ISO A.8.9, and precisely the failure mode the prior `tfenv` guidance
   warned about. `mise` owns nothing here that `uv` does not already own better.

### 3.4 The `tfenv` precedent and terraform provenance (prompt §7.4) — **decisive**

a. Prior operator guidance rejected `tfenv` because it PATH-shadows `/usr/bin/terraform` and
   creates two sources of truth. That reasoning was correct and it is **inherited, not
   refuted** — nothing in the mise documentation changes it.
b. The stronger argument is provenance, and it runs the opposite way to intuition:
   b.1. **apt-managed terraform is publisher-signed.** It arrives from
        `https://apt.releases.hashicorp.com` verified against
        `/usr/share/keyrings/hashicorp-archive-keyring.gpg`. Every install and every upgrade is
        signature-checked by the package manager, by a key HashiCorp controls. That is a real,
        existing, auditable integrity control.
   b.2. **mise's own download-verification table does not list terraform.** Upstream documents
        verification for `aqua:`, `github:`, `packslip:`, Node.js (OpenPGP-signed
        `SHASUMS256.txt`, signature *must* be present), Zig (Minisign), and precompiled Python
        and Ruby (GitHub artifact attestations). Terraform is in **none** of those rows, and it
        is not among the archive-downloading core tools (Bun, Deno, Elixir, Erlang, Go, Java,
        Node.js, Python, Ruby, Zig).
   b.3. Which backend serves terraform, and what `mise tool terraform` prints on its `Security:`
        line, could not be determined this pass (§10). It may well verify properly. **But
        "may well" is not evidence, and the burden of proof sits with the change.**
c. **Therefore: moving terraform from apt to mise would move the estate's most
   credential-adjacent binary — the one that reads `GITHUB_TOKEN`, writes state, and in jolarca's
   case touches a PCI-scoped workspace — from a channel with a documented publisher signature to
   a channel whose verification for that tool is undocumented.** Under prompt §3.8 that is a
   regression and it counts against the recommendation. Under ISO A.8.19 (installation of
   software on operational systems) and SOC CC9.2 (vendor risk) it is not defensible on a
   "probably fine" basis.
d. **Verdict: terraform stays apt-managed.** Add `sudo apt-mark hold terraform` (2.3) so the pin
   cannot drift, and add `.terraform-version` to the two planes that lack one so the pin is
   *declared* and not merely installed.

### 3.5 Release cadence (prompt §7.5)

a. mise ships **several times a week**. Upstream's `minimum_release_age` default of 24 hours is a
   sensible control against freshly-published malicious releases, and it is to the project's
   credit.
b. But cadence cuts both ways for a single operator. With a `mise.lock` you get reproducibility,
   and you also acquire a **new recurring obligation**: `mise lock --bump`, review the diff, run
   the project's checks, commit. Every week, forever, in every repo that has one.
c. The estate already has that obligation for its action SHAs and its `uv.lock` files. Adding a
   third lock format multiplies the recurring cost without multiplying the coverage — because,
   per §3.1.a, the versions being locked are uniform anyway.
d. **Verdict:** the cadence is manageable but the marginal benefit does not pay for it. Evidence
   for a build ("which version produced this?") is already obtainable from the action SHA plus
   `uv.lock` plus `.terraform-version`.

### 3.6 VERDICT on Question 2 (prompt §7.6)

> **DO NOT ADOPT `mise`.** Not in Via-Vitae, not in journeyoflife-org, not in jolarca-dev, not
> locally, not in CI.

Adopt instead the combination **(a) + (b) + (e) + (f)**:

1. **(a)** Targeted host fixes — `apt-mark hold terraform`, resolve the Node 20-versus-22
   divergence by decision, make `pre-commit` reproducible from the repository.
2. **(b)** One **single-sourced version manifest per control plane**, propagated into per-repo
   workflow `env:` blocks and action SHAs by a dry-run-first script, guarded by a new
   `scripts/` checker to the house exit-code contract.
3. **(e)** Where a repo needs a *local* tool version, commit an idiomatic version file
   (`.tool-versions`, `.nvmrc`, `.terraform-version`) and point the already-SHA-pinned
   `actions/setup-node` / `actions/setup-python` at it with `node-version-file` /
   `python-version-file`. This is exact, adds no supplier, and — because mise reads
   `.tool-versions` natively — **it keeps the mise door open at zero cost if the estate ever
   develops per-directory version divergence.**
4. **(f)** Keep `uv` as the Python answer. Extend it to the repos that still hand-roll a `.venv`.

This is not a compromise position. It is the option that addresses **P2 and P3, the largest
measured risk**, which `mise` does not touch at all — while fixing P1 for roughly twenty minutes
of host work instead of a new dependency.

---

## §4 Question 3 — Per repository, or shared?

The operator's literal question: *"does mise need to be configured separately for each
repository?"*

### 4.1 Resolution semantics (prompt §8.1)

a. From `getting-started.html`: `mise use --global` writes `~/.config/mise/config.toml`, and
   "**project configuration overrides it**". Project config is discovered by walking up from the
   working directory.
b. From `dev-tools/mise-lock.html`, the lockfile follows the **config file's location**:
   `mise.toml` produces `mise.lock` beside it; `.config/mise.toml` produces `.config/mise.lock`;
   files in a `conf.d/` directory share one lockfile in its parent.
c. From `security.html`, trust belongs to a **config root** — usually the directory holding
   `mise.toml` — and covers every config file there.
d. **The full precedence order across `.miserc.toml`, system, global, monorepo-root and project
   config could not be confirmed without installing mise.** Recorded in §10 rather than guessed.
e. What is certain and sufficient: **resolution is per-directory.** There is no mechanism by
   which one file governs many sibling repositories.

### 4.2 The two-layer verdict (prompt §8.2)

a. **The question conflates two separable things**, and separating them is the whole answer:
   - **Where the file lives** — necessarily per repository, because that is how mise resolves
     config, and equally how git resolves tracked files.
   - **Where the version decisions are authored** — necessarily in **one** place, because 31
     independently hand-written configs are 31 independent opportunities to drift. That is
     exactly the failure already measured in §2.1: `actions/checkout` resolves to three
     different commits across Via-Vitae because each repo pinned it separately.
b. This is true **regardless of instrument**. It is the reason the recommendation in §3.6 is a
   manifest plus a propagator, and it would have been the reason to shape a mise rollout the same
   way.
c. **So: files per repo, decisions single-sourced, and the per-repo files generated — never
   hand-edited.** A generated file that a human edits by hand is a drift incident waiting to
   happen, and the guard in §6.4 exists to make that incident fail loudly.

### 4.3 Scope — which repos get a file at all (prompt §8.3)

All 31 Via-Vitae repositories, verdict per row:

| Repository | Runtime evidence | Verdict |
| --- | --- | --- |
| viavitae-control | 12 `.tf`, 18 `.sh`, hand-made `.venv` | **IN SCOPE** — terraform, shell, python |
| viavitae-api | python manifest, `uv.lock`, node in CI, 2 `.sh` | **IN SCOPE** — python, node |
| viavitae-brand | python manifest | **IN SCOPE** — python |
| viavitae-hermes-agents | python manifest, `uv.lock`, 1 `.sh` | **IN SCOPE** — python |
| viavitae-web | `package.json`, `.nvmrc` = 22 | **IN SCOPE** — node |
| viavitae-demos | `package.json`, 4 `.sh` | **IN SCOPE** — node, shell |
| viavitae-docs | `package.json` | **IN SCOPE** — node |
| viavitae-qa | `package.json`, 1 `.sh` | **IN SCOPE** — node, shell |
| viavitae-infra | 6 `.sh` | **IN SCOPE** — shell only |
| viavitae-clients | 1 `.sh` | **DEFERRED** — one shell script does not justify a config; revisit when it grows |
| viavitae-template | no manifest, but **32-ref SHA-pinned CI** and it is the scaffold source | **SOURCE, NOT CONSUMER** — it carries the manifest that propagates to the landings |
| viavitae-landing-basilica | no manifest; 32-ref CI declaring node 22 and python 3.12 | **OUT OF SCOPE for toolchain config** — trim the inherited CI instead (§2.5) |
| viavitae-landing-cathedral | as above | OUT OF SCOPE |
| viavitae-landing-cemetery-services | as above | OUT OF SCOPE |
| viavitae-landing-churches-orthodox | as above | OUT OF SCOPE |
| viavitae-landing-churches-other | as above | OUT OF SCOPE |
| viavitae-landing-churches-protestant | as above | OUT OF SCOPE |
| viavitae-landing-deaneries | as above | OUT OF SCOPE |
| viavitae-landing-diocese | as above | OUT OF SCOPE |
| viavitae-landing-funeral-services | as above | OUT OF SCOPE |
| viavitae-landing-parish-church | as above | OUT OF SCOPE |
| viavitae-compliance | empty, private | **OUT OF SCOPE — EMPTY**; report unobserved, never passed |
| viavitae-data-governance | empty, private | OUT OF SCOPE — EMPTY |
| viavitae-policies | empty, private | OUT OF SCOPE — EMPTY |
| viavitae-threat-model | empty, private | OUT OF SCOPE — EMPTY |
| viavitae-vendor-register | empty, private | OUT OF SCOPE — EMPTY |
| viavitae-observability | empty | OUT OF SCOPE — EMPTY |
| viavitae-reusable-workflows | empty | OUT OF SCOPE — EMPTY |
| viavitae-runbooks | empty | OUT OF SCOPE — EMPTY |
| viavitae-training | empty | OUT OF SCOPE — EMPTY |
| .github | no manifest, no workflows found | OUT OF SCOPE — verify before landing |

**Count: 9 in scope, 1 deferred, 1 source, 10 out for inherited CI, 9 out for empty, 1 out
pending verification = 31.** A blanket "all 31" is indefensible row by row, and the prompt made
it a contract violation for good reason.

### 4.4 Boundary 1 across the three entities (prompt §8.4)

a. **May one `mise.toml` be shared by repos in different orgs? NO.** Boundary 1 names "CI
   configuration" explicitly. A config file that decides what two entities build with *is* CI
   configuration. Prohibited.
b. **May one global config on the workstation govern all three planes? NO for policy, and this is
   the subtle part.** `~/.config/mise/config.toml` overriding nothing and pinning nothing is
   inert; the same file declaring `terraform = "1.16.1"` makes the charity's build depend on a
   file the commercial entity's operator also edits. That is shared CI configuration by another
   name.
c. **Does a shared tool cache breach boundary 1? NO — with reasoning, not assumption.**
   `~/.local/share/mise` would hold **public vendor binaries**: HashiCorp's terraform, the Node
   Foundation's node, python-build-standalone's python. It holds no entity data, no credentials,
   no configuration, and no membership. Boundary 1 exists to prevent one controller's data and
   trust decisions from transiting another's infrastructure; a cache of publicly-signed vendor
   artifacts does neither. **Verdict: cache sharing acceptable; configuration sharing
   prohibited.** If mise were ever adopted, this would still need `MISE_DATA_DIR` reviewed per
   plane, because the cache also stores resolved version metadata — which is closer to
   configuration than to binaries.
d. **A shared "toolchain policy" repo? REJECTED.** No entity can own it without the other two
   depending on it, and the charity's stated principle — built and operated in-house on hardware
   it owns — makes an externally-owned policy file a residency question as well as an isolation
   one.
e. **The correct shape is three manifests, one per control plane, structurally identical and
   separately owned.** This is exactly how the estate already handles its guard scripts: the same
   checker is copied into `jol-control` and `jolarca-control` with the path adjusted per entity,
   rather than shared. Copy the convention; do not invent a new one.

### 4.5 Generation versus authoring (prompt §8.5)

a. The manifest lives in each control plane — for Via-Vitae, alongside `repos_data.tf` and
   `locals.tf`, because it is declared configuration and belongs under the same plan and review
   gates as everything else in that repo.
b. The propagator follows the existing pattern exactly: `scripts/propagate_landing_scaffold.py`
   **previews a multi-repo sweep without writing anything**, and the estate's mutating scripts
   default to dry-run and require an explicit `--apply`.
c. Every mutating script defaults to preview. One PR per repository. Small diffs. `ai:<tier>`
   trailer. Squash-merge so the PR description becomes the provenance record on `main`.
d. Ownership: the propagator lives in the control plane that owns the org it writes to. No
   cross-plane execution, ever.

### 4.6 Worktrees and clones (prompt §8.6)

a. Five worktrees exist across the estate: `viavitae-api-wt-deps`, `viavitae-api-wt-vv011`,
   `viavitae-template-wt-ci`, `viavitae-template-wt-install`, `jol-infrastructure-f14f21`.
b. Under mise: a worktree is a **sibling directory**, not a child, so it resolves its own config
   from its own checkout — fine. But upstream records that "a config in a linked git worktree is
   trusted when the same path in the main checkout is trusted", and that **paranoid mode does not
   share trust between worktrees**. So the trust posture of a worktree depends on a mode setting
   and on the main checkout's state. That is a subtle, undocumented-in-the-repo dependency.
c. **Under the recommended design this is a non-issue, and that is a concrete advantage.**
   `.tool-versions` and `.nvmrc` are ordinary tracked files. Every worktree carries its own
   identical copy, resolved by git, with no trust model, no mode setting, and no walk-up
   semantics. `actions/setup-node` reading `node-version-file: .nvmrc` behaves identically in a
   worktree, a fresh clone, and a clean runner.
d. Fresh clone before any install: today, nothing declares node or pre-commit, so a fresh clone
   silently gets the distro versions — that is finding P4. After §6 Tier 5, `bootstrap.sh` makes
   it explicit.

### 4.7 Empty and private repos (prompt §8.7)

a. Nine Via-Vitae repos are empty. Five repos are private **and** return HTTP 403 for
   protection, ruleset and advanced-security reads on the GitHub Free plan — a recorded blind
   spot.
b. "Rolled out" cannot honestly mean anything for either group. Per the estate's audit-snapshot
   semantics, an empty repository has no code snapshot at all, so its controls are reported as
   **unobserved**, never as **passed**.
c. Any coverage percentage quoted for this work must use **22 repos with content** as the
   denominator, or state both denominators. Quoting 31 inflates coverage by 41 %.

### 4.8 VERDICT on Question 3 (prompt §8.8)

**No — and the question should not be asked about `mise` at all, because `mise` is not being
adopted.** But the instinct underneath it is correct and it survives the rejection:

- **Files live per repository.** That is forced by how both mise and git resolve configuration.
- **Versions are authored in one place per control plane.** Three manifests, one per legal
  entity, never shared (§4.4).
- **Only 9 of 31 Via-Vitae repos are consumers**; one more (`viavitae-template`) is the
  propagation source; 21 get nothing (§4.3).
- **Per-repo files are generated, never hand-edited**, and a guard fails the build when a
  hand-edit drifts from the manifest (§6.4).

That is the two-layer answer, delivered without a version manager.


---

## §5 Question 4 — Supply chain, trust, and CI adoption

Answered in full even though §3.6 rejected adoption, because **this section contains the two
independent decisive reasons** and because the analysis is reusable if the estate ever develops
per-directory version divergence.

### 5.1 Install provenance (prompt §9.1)

a. `curl -fsSL https://mise.run | sh` executes an unpinned remote script as the operator. It
   fails CC9.2 (vendor risk), A.5.19–A.5.22 (supplier relationships and ICT supply chain) and
   A.8.19 (installation of software on operational systems): there is no version selected, no
   checksum recorded, and no artifact an auditor can later compare against what ran.
b. **A better path exists and should be credited.** `mise generate install-script --localize
   --write` produces a committed `bin/mise` that downloads a **pinned** release on first use,
   keeps everything under `.mise/`, trusts the project config and **ignores the user's global
   config**. It pins the newest stable release older than `self_update.minimum_release_age`
   (24 h default) or an explicit `--version`. `mise self-update` verifies each release's
   signature before replacing the binary.
c. **The bootstrap paradox remains.** Generating the wrapper requires `mise` to be installed
   first. So the *initial* install is still unauthenticated unless it comes from a package
   manager. Verdict: the only initial-install routes that inherit an existing signature-
   verification chain are **apt/dnf from a signed repository**, or a vendored binary with a
   recorded sha256 checked before first execution.
d. **Mandate, had adoption proceeded:** distro package or vendored binary with recorded hash.
   Never the curl script. This is achievable — it is not the reason for rejection.

### 5.2 Backend provenance per tool (prompt §9.2)

| Tool | Backend | Artifact source | Integrity mechanism | Signer | What a compromise looks like | Detection |
| --- | --- | --- | --- | --- | --- | --- |
| node | core | nodejs.org distribution | checksums from `SHASUMS256.txt` **plus its OpenPGP signature, which must be present** | Node.js release team | a substituted tarball | signature check fails closed — **strong** |
| python | core, precompiled | python-build-standalone | GitHub artifact attestations | the build project | a substituted archive | attestation check fails — **strong** |
| terraform | **UNKNOWN** | **UNKNOWN** | **not listed in any row of upstream's verification table** | HashiCorp signs its own releases, but whether mise checks them is undocumented | a substituted binary that reads `GITHUB_TOKEN` and writes state | **unknown — this is the finding** |
| gh | registry backend, unresolved | unresolved | unresolved | GitHub | a substituted CLI holding org credentials | unknown |
| jq | registry backend, unresolved | unresolved | unresolved | the jq project | low impact, read-only tool | unknown |

a. The table's shape is the argument. Two of the five tools have **documented, strong,
   fail-closed** verification. The most credential-adjacent tool in the estate — the one that
   reads `GITHUB_TOKEN`, writes Terraform state, and in jolarca's case touches a PCI-scoped
   workspace — is the one with **no documented verification row**.
b. `mise tool terraform` prints a `Security:` line that would settle this. It cannot be run
   because mise is absent, and `registry.toml` was not retrievable through the contents API.
   Recorded in §10, not guessed.
c. **Compare against the status quo, which is better than it looks:** apt delivers terraform
   from `https://apt.releases.hashicorp.com` verified against
   `/usr/share/keyrings/hashicorp-archive-keyring.gpg`. That is publisher-signed, checked on
   every install and every upgrade, by a key HashiCorp rotates. **The incumbent channel has
   stronger documented provenance than the proposed one.**

### 5.3 Lockfile (prompt §9.3)

a. **Mechanics, verified upstream:** `mise.lock` records exact resolved versions plus per-platform
   download URLs and checksums. `mise install --locked` (or `MISE_LOCKED=1`) **fails closed** when
   an entry is missing, or when a URL-recording backend has a URL with no checksum.
   `jdx/mise-action` adds `--locked` automatically when a lockfile is present. `locked_scopes`
   and `[tool_config] locked` are **global-only**, "so a project cannot weaken your locked-mode
   policy" — a genuinely good control property.
b. **This is a real strength and it is credited.** A fail-closed lock is a better control than
   anything the estate has for local binaries today.
c. **Platform coverage required here is one, not many.** The runner and the workstation are both
   linux-x64: `uv` reports `x86_64-unknown-linux-gnu`, terraform reports `linux_amd64`. So
   `mise lock --platform linux-x64` suffices today. If a macOS machine ever joins, the lock must
   be regenerated or `--locked` fails closed on that platform — which is the correct behaviour.
d. **`.tool-versions` entries cannot be locked.** "Tools listed only in `.tool-versions` are not
   locked. Move them to `mise.toml` first." An idiomatic `.nvmrc` locks only into "the lockfile
   of the nearest `mise.toml` whose directory contains it" — so the lock-free option (e) in §3.2
   would need a `mise.toml` to gain exactness. **Trade-off recorded honestly:** option (e) gives
   an exact *declared* version but no checksummed artifact lock. For node that is acceptable
   because `actions/setup-node` is SHA-pinned and the Node.js project signs its own tarballs.
e. **The cache design, had adoption proceeded:** never cache `installs`. Upstream warns
   "`mise.lock` verifies what mise downloads, not what is already on disk… mise can't validate an
   installed tree against the lockfile." Cache `~/.cache/mise/downloads-cas` keyed on
   `hashFiles('mise.lock')` with `cache: false` on the action, because `--locked` "only reuses a
   download that has a checksum to check it against". And never restore a cache written by an
   untrusted ref or trigger.
f. **A third-party host sits in the trust path.** `mise lock` reads release metadata and asset
   checksums from **mise-versions** (`mise-versions.jdx.dev`), recording
   `checksum_source = "mise-versions"` without downloading the asset. Upstream mitigates the
   obvious abuse — a mise-versions checksum is never used to hand back a cached file — but the
   host is still a supplier that influences what is recorded as trusted. That needs a GDPR
   Art. 28 assessment, an ISO A.5.19–A.5.22 review, and a `viavitae-vendor-register` entry.

### 5.4 Trust model and the public-repo attack path (prompt §9.4) — **decisive**

a. **The attack.** 26 of 31 Via-Vitae repos are public. A `mise.toml` can execute code through
   `[env]` directives, entry hooks, template `exec()` and `[tasks]` bodies. An external
   contributor opens a PR that edits `mise.toml`; the workflow file is untouched, so a reviewer
   scanning the diff for `uses:` and `run:` lines sees nothing suspicious in the YAML — the
   payload is in the TOML. CI runs `mise install` then `mise run ci`.
b. **The decisive fact.** Upstream, verbatim: *"When mise detects CI, for example because `CI` is
   set, it treats every config as trusted and records nothing."* GitHub Actions always sets `CI`.
   **The trust prompt therefore provides zero protection in CI.** The control that gives mise its
   security story is switched off precisely where untrusted code arrives.
c. **Countermeasure 1 — `MISE_SAFE=1` — does not work for this case.** Safe mode refuses tasks,
   template `exec()`, plugin installs, hooks, `_.source`, project `[env]`/`[vars]`/`[settings]`,
   and `postinstall`. But upstream's own WARNING: *"Safe mode does not make other commands safe to
   run on config you have not reviewed. `mise install` can build a tool from source, which runs
   the tool's build scripts."* Safe mode is scoped to resolution and metadata commands. A CI job
   that must **install and run** cannot be made safe by it.
d. **Countermeasure 2 — `MISE_PARANOID=1` — works, and then breaks the build.** Paranoid mode
   "turns off both the CI exemption and `--yes` for trust", removes the trust exemptions, and
   enables `locked_verify_provenance`. But with the exemption off, an untrusted config on a fresh
   runner cannot prompt — and upstream records that without a terminal, "the command fails with
   `Config files in <path> are not trusted`". So paranoid mode in CI means every job needs an
   explicit `mise trust` step, which is itself a decision to run the branch's code. It converts a
   silent hole into a loud one. That is an improvement, not a solution.
e. **Countermeasure 3 — the only workable shape — forbids most of the reason to adopt.** A
   `mise.toml` loads **without trust** if it has no template syntax (`{{`, `{%`, `{#`) and
   contains only `min_version`, plain-string `[tools]`, and `[tasks]` listing no `secrets`.
   So the safe subset is: version pins and simple task bodies. **`[env]`, `[hooks]`,
   `[settings]`, tool option tables, `include`, and all templates require trust** — and trust is
   automatic in CI. Adopting mise safely in 26 public repos therefore means **not using `[env]`,
   not using hooks, not using templates, and not using tool options.** At that point mise is a
   version-pin file with extra steps, and `.tool-versions` plus the already-SHA-pinned `setup-*`
   actions delivers the same thing with no new binary and no trust model at all.
f. **Supporting controls, all still required even with (e):** ruleset path protection for
   `mise.toml` and `mise.lock`; CODEOWNERS on both; `pull_request` from forks running with no
   secrets; `permissions:` minimised to `contents: read`; and a CI step diffing the PR's config
   against `main` **before** any mise command runs.
g. **Correction to a claim this prompt inherited.** `policies/AI_WORKFLOW_POLICY.md` §8 states
   that the live `protect-main` ruleset lists no required status checks and that "an admin can
   still merge". The live ruleset 23943250 contradicts it: context `provenance` **is** required,
   `strict_required_status_checks_policy: true`, and `bypass_actors: []` — so nobody, including
   the owner, can bypass. **The policy understates an existing blocking control.** That is
   finding VV-2026-11-006 and it is independent of the mise question.
h. Adding a *new* required context for a config-diff gate would be a ruleset change declared in
   `repo_rulesets.tf`, therefore an `apply`-gated live-org mutation needing a compliance
   rationale under policy §3.12.

### 5.5 The CI action and the allow-list (prompt §9.5)

a. `jdx/mise-action` is **not** in `patterns_allowed`. The repo exists, is MIT-licensed, is not
   archived, has 401 stars, and was pushed 2026-11-02 — active and maintained.
b. **It may need no pattern at all.** `verified_allowed: true`, and the estate already proves the
   mechanism: `aquasecurity/trivy-action` is referenced 41 times across Via-Vitae, is absent from
   the allow-list, and runs. Whether `jdx` holds verified-creator status is **not exposed by the
   REST API** and could not be determined (§10). Relying on `verified_allowed` is itself a
   delegated trust decision — GitHub vouches for the publisher, you do not — and deserves a
   finding of its own.
c. If a pattern is required, it must be a **full commit SHA**, not `@*`. The org already carries
   nine floating patterns with `sha_pinning_required: false`; adding a tenth would worsen a
   recorded Medium finding. Note that upstream's own documented example uses floating
   `actions/checkout@v7` and `jdx/mise-action@v5` — copying the docs would import exactly the
   defect this estate has spent effort removing in 29 of 31 repos.
d. Any allow-list edit is `var.actions_allowed_patterns` in `terraform.tfvars`, applied through
   `org_actions_policy.tf`. That is a `terraform apply` against a live org:
   `STOP — human approval required before this step`, plus a compliance rationale.
e. **Adopting mise would be the moment to turn `sha_pinning_required` on org-wide — and it would
   break things.** Nine floating patterns and roughly 150 floating references across the charity
   plane would fail. That is a good reason to do it, and a reason it needs its own project, not a
   rider on a toolchain decision.

### 5.6 GitHub API rate limits and the token question (prompt §9.6)

a. GitHub-release-backed installs hit API rate limits; the documented mitigation is to give mise a
   token. `jdx/mise-action` already passes the workflow's GitHub token to mise **during install**
   but does not export it to later steps, so a job installing tools in a later step needs its own
   token — a potential **new secret in every repo's CI**.
b. **The lockfile largely dissolves this.** With a `mise.lock`, "mise takes the version from it
   and skips the lookup"; and `mise-versions` supplies checksums without downloading the asset.
   Most rate-limit pressure comes from version *lookups*, which the lock eliminates.
c. **Verdict:** no new secret is strictly required if lockfile discipline holds. But that is yet
   another standing obligation — the lock must be present, current, and multi-platform — in an
   estate whose largest measured problem is that nobody reconciles the declarations it already
   has. Adding a control that depends on a new discipline, to fix a problem caused by lack of
   discipline, is the wrong shape.
d. Against the existing credential work: the estate runs a read-only fine-grained PAT, a CI
   pre-flight gate (`scripts/check_ci_credential.sh`) that rejects write-capable tokens, and an
   explicit instruction never to mint a classic PAT to make CI green. Any mise token would have to
   be a **new** fine-grained PAT with the narrowest possible scope, registered in
   `docs/SECRETS_INVENTORY.md` with an expiry, and covered by the existing expiry gate. That is
   achievable but it is real work for zero measured benefit.

### 5.7 Telemetry and data flows (prompt §9.7)

a. **CANNOT VERIFY.** The four upstream pages read (getting-started, security, mise-lock,
   continuous-integration) do not state whether mise emits telemetry, crash reports, or version
   lookups that identify the caller.
b. What *is* established: mise queries a **versions host** (`mise-versions.jdx.dev`) and, absent a
   lockfile, queries upstream release APIs. Those are outbound requests from a build environment
   in three legal entities, one of which is a charity operating on hardware it owns and one of
   which is PCI-scoped.
c. If any of that is attributable, it is a processor relationship requiring a GDPR Art. 28
   assessment and a `viavitae-vendor-register` entry — for an entity whose vendor register is
   currently an **empty private repository**, so there is nowhere to record it yet.
d. **This must be resolved before any future adoption.** It is not a reason to reject today,
   because today's rejection already stands on §5.2 and §5.4.

### 5.8 Regression check against existing controls (prompt §9.8)

| Existing control | Effect of adopting `mise` | Evidence |
| --- | --- | --- |
| `commit-msg` provenance hook, `INSTALL_PYTHON` hardcoded to the repo `.venv` | **DEGRADED** | `.git/hooks/commit-msg` line 6 execs a fixed interpreter path. A mise-managed python does not change that path, but a mise-managed `pre-commit` would install elsewhere, and re-running `pre-commit install` under mise would rewrite the shim to a mise shims path that varies by directory. The CI `provenance` gate still blocks, so this is degraded early feedback, not a broken control |
| `Assert toolchain pin` in `audit.yml` | **UNAFFECTED but redundant** | it would compare `.terraform-version` against a mise-provided terraform; still meaningful, but now policing a third source |
| apt-managed terraform, publisher-signed, shared by three planes | **BROKEN** | a mise-managed terraform PATH-shadows `/usr/bin/terraform`. This is the exact failure the prior `tfenv` guidance rejected, and it moves the binary off a signed channel (§3.4, §5.2) |
| gitleaks `v8.30.1` via pre-commit | **DEGRADED** | runs through the same `.venv` shim chain as the provenance hook |
| 29 of 31 repos fully SHA-pinned | **UNAFFECTED** | mise does not touch `uses:` lines — which is also why it does not help |
| `uv.lock` in 8 repos plus SHA-pinned `astral-sh/setup-uv` | **DEGRADED by contention** | mise's `pypi:` backend and `uv` would both claim Python resolution; three tools over `PATH` and `VIRTUAL_ENV` is an A.8.9 defect |
| `make` gate vocabulary in `jol-control` and 20+ repos | **DEGRADED** | `mise [tasks]` competing with `plan-gate`, `state-gate`, `fmt-check`, `agents-gate`, `doc-gate` risks a second, weaker task surface beside the gated one |
| Org Actions allow-list, Terraform-managed | **CHANGED** | a new pattern or a new reliance on `verified_allowed`, both `apply`-gated |
| `AI_WORKFLOW_POLICY.md` §8 | **UNAFFECTED** — but found independently stale | see §5.4.g and VV-2026-11-006 |

**Count: one control broken, four degraded, three unaffected, one changed.** Under prompt §3.8
every one of those counts against the recommendation. A change that breaks one control and
degrades four, to fix a problem with a twenty-minute solution, does not pass.

### 5.9 VERDICT on Question 4

- **May `mise` be used locally? NO.** Not while terraform's mise backend has no documented
  signature verification and apt already provides a publisher-signed channel (§5.2). Not while it
  would contend with `uv`, `make` and the `.venv` hook chain (§5.8).
- **May `mise` be used in CI? NO.** The CI trust exemption (§5.4.b) makes it inadmissible in 26
  public repositories unless the config is restricted to the trust-free subset — and that subset
  excludes `[env]`, hooks, templates and tool options, which removes most of the reason to adopt
  it (§5.4.e).
- **Non-negotiable conditions if this is ever revisited:** (i) `mise tool terraform`'s `Security:`
  line read and recorded; (ii) telemetry behaviour determined and vendor-registered; (iii)
  distro-package or vendored-binary install only, never `curl | sh`; (iv) `mise.lock` committed
  per platform with `install --locked`; (v) download-cache-only CI caching, never `installs`;
  (vi) config restricted to the trust-free subset with ruleset path protection; (vii) the action
  SHA-pinned, not `@*`; (viii) `MISE_PARANOID=1` evaluated for the runner; (ix) per-entity
  `MISE_DATA_DIR` reviewed against boundary 1; (x) **and** a demonstrated per-directory version
  divergence, without which the tool's headline feature has no consumer (§3.1.a).

---

## §6 Question 5 — Rollout of the recommended alternative

Prompt §10 requires this section to carry the rollout for the recommended alternative at the same
depth, because §3.6 is "do not adopt". The alternative is §3.6's **(a) + (b) + (e) + (f)**.

### 6.1 Tiering (prompt §10.1)

| Tier | What | Where | Effort | Entry criteria | Exit criteria |
| --- | --- | --- | --- | --- | --- |
| 0 | Host fixes, no PR | workstation | 20 min | none | `apt-mark showhold` lists terraform; node version decision recorded |
| 1 | Version manifest plus the guard script | viavitae-control | 2 h | Tier 0 done | guard exits 0 on the real tree and 1 on each of five injected defects |
| 2 | Close the two Via-Vitae floating-ref repos | viavitae-control, viavitae-hermes-agents | 3 h | Tier 1 merged | both repos report float=0 |
| 3 | Propagate the manifest to the 9 in-scope repos plus the template | Via-Vitae | 1 day | Tier 2 done | 10 PRs merged, guard green in each |
| 4 | Per-plane manifests and pin sweeps for jolarca then jol | jolarca-control, jol-control | 2 days | Tier 3 done, **and** each plane's own guard landed | `jolarca` float count drops from 45; `jol-control` from 16 |
| 5 | Successor bootstrap script | each control plane | 3 h | Tier 1 done | a fresh clone reaches a working environment from the repo alone |

Tier 4 is **not** a Via-Vitae task and must not be executed from `viavitae-control`. Each plane
owns its own manifest and its own propagator (§4.4.e). Sequencing jolarca before jol is deliberate:
jolarca carries the PCI-DSS scope and the estate's single worst repository.

### 6.2 Per-tier change set (prompt §10.2)

**Tier 0 — host, no PR, no repository change.** Run from anywhere.
```bash
sudo apt-mark hold terraform                     # STOP — human approval required
apt-mark showhold                                 # expect: terraform
node --version                                    # today: v20.20.2
grep -rh 'NODE_VERSION:' /opt/viavitae/repos/viavitae-*/.github/workflows/*.yml | sort -u
```
Then make the **decision** (this is a human judgement, not a command): either install Node 22 to
match the declaration, or change the declaration to 20. Installing Node 22 is recommended, because
22 is the LTS line the estate already declares everywhere and `.nvmrc` already names.
```bash
# Option A, align the host to the declaration. STOP — human approval required.
# Adds the NodeSource signed repository, then installs nodejs 22.
```
Record the decision and its date in `docs/COMPLIANCE.md`.

**Tier 1 — viavitae-control, one PR.**
- New file `toolchain.yml` (or a `locals` block beside `repos_data.tf`, which is preferable
  because it then sits under the same `terraform plan` review gate): declares `node: "22"`,
  `python: "3.12"`, `terraform: "1.16.1"`, and the canonical commit SHA for every action the
  estate uses.
- New file `scripts/check_toolchain_pins.sh` — see 6.4.
- Modified `.github/workflows/audit.yml` — insert the guard after `Check plan self-citations` and
  **before** `Check CI credential`, and add the `Read terraform pin` step from §2.2.d so
  `terraform_version` has one source.
- Modified `policies/README.md` — one new register row, all columns populated.
- `STOP — human approval required before this step`: pushing a branch and opening a PR is
  permitted under plan-only authority only with owner approval; merging is never automated.

**Tier 2 — two PRs.** Replace `actions/checkout@v4` and `hashicorp/setup-terraform@v4` in
`viavitae-control/.github/workflows/audit.yml` with the canonical SHAs from the manifest; identify
and replace the three floating references in `viavitae-hermes-agents`.

**Tier 3 — ten PRs**, one per repo, generated not hand-edited (6.3).

**Tier 4 — per plane.** `jolarca`: 45 floating refs in `jolarca`, 3 in `jolarca-infrastructure`,
1 in `jolarca-data`. `jol`: `jol-control` 16, `jol-ecommerce-engine` 23, `jol-link-registry` 21,
`jol-auth` 20, `jol-bitrix24-integration` 14, and roughly 150 more across the plane. **This is the
largest single remediation in the estate and it is a PCI-DSS Req. 6.5 and Req. 2.2 item.**

### 6.3 Dry-run-first propagation (prompt §10.3)

a. Follow `scripts/propagate_landing_scaffold.py`, which previews a multi-repo sweep **without
   writing anything**. The new propagator must behave identically: no arguments means preview.
b. `--apply` writes. `--repo <name>` limits to one repository. `--check` exits non-zero on drift
   without writing, so CI can use it.
c. One PR per repository. Diffs under 100 lines for mechanical changes. Exactly one `ai:<tier>`
   trailer per commit. Squash-merge, so the PR description becomes the provenance record on
   `main` — which is what the CI `provenance` gate actually reads.
d. `STOP — human approval required before this step` applies to every `--apply` invocation and
   every push.

### 6.4 The guard script (prompt §10.4)

`scripts/check_toolchain_pins.sh`, to the house contract:

- **Exit codes:** `0` clean, `1` violation, `2` unable to execute or nothing checkable. Unknown,
  null and empty are never a pass. A run that inspected **no** workflow files must exit `2`, not
  `0` — an unchecked invariant must not look identical to a satisfied one.
- **No secrets, no network.** Pure filesystem reads, so it can run before every credential gate.
- **Placement in `audit.yml`:** after `Check plan self-citations`, before `Check CI credential`.
  A gate parked behind a credential failure proves nothing, because a skipped check is
  indistinguishable from a passing one in the check list.
- **Registration:** one row in the `policies/README.md` table, columns `File`, `Purpose`,
  `Plan tier`, `Automatable?`, all populated.

Invariants:

| ID | Assertion | Failure meaning |
| --- | --- | --- |
| I1 | every `uses:` reference is `@` followed by 40 hex characters, or a local `./.github/...` path | a floating tag can move without approval |
| I2 | every `NODE_VERSION`, `PYTHON_VERSION` and `terraform_version` value equals the manifest | a repo has drifted from the single source |
| I3 | `.terraform-version` exists and equals the manifest terraform value | the declared pin is missing or wrong |
| I4 | every action SHA in use appears in the manifest's canonical list | an unreviewed SHA was pasted in |
| I5 | every action in the manifest's canonical list resolves to exactly one SHA across the repo | the same action pinned twice, differently |

**Mutation proof — mandatory before this guard may be called a control.** Inject each defect into
a scratch copy and require the exit code to flip:

| Injected defect | Required exit |
| --- | --- |
| change one `@<sha>` to `@v4` | 1 (I1) |
| change one `NODE_VERSION: "22"` to `"20"` | 1 (I2) |
| delete `.terraform-version` | 1 (I3) |
| add a `uses:` line for an action absent from the manifest | 1 (I4) |
| give `actions/checkout` two different SHAs | 1 (I5) |
| point the script at a directory with no workflows | **2**, not 0 |

Then confirm the real tree exits `0`. **A guard never observed failing is not yet a control.**

### 6.5 Verification, not assertion (prompt §10.5)

Per tier, the commands whose *output* is the evidence. Run from the repository root named.

```bash
# Tier 0, from anywhere
apt-mark showhold                                  # must print: terraform
node --version                                     # must print: v22.x after the decision

# Tier 1 and 2, from /opt/viavitae/repos/viavitae-control
./scripts/check_toolchain_pins.sh ; echo "exit=$?" # must print exit=0
terraform fmt -check -recursive                    # must be silent
terraform init -backend=false && terraform validate # must print Success!
grep -c 'uses: .*@[0-9a-f]\{40\}$' .github/workflows/audit.yml
grep -cE 'uses: [^ ]+@(v[0-9]|[0-9]+(\.[0-9]+)*)$' .github/workflows/audit.yml   # must print 0

# Tier 3, from /opt/viavitae/repos
for d in viavitae-*/; do n=${d%/}
  f=$(grep -rhoE 'uses: [^ ]+' "$d".github/workflows/*.yml 2>/dev/null | sed 's/^uses: //' | grep -vE '@[0-9a-f]{40}$' | grep -c '@')
  printf '%-38s float=%s\n' "$n" "$f"; done         # every in-scope repo must print float=0

# Tier 5, from a throwaway clone
git clone https://github.com/Via-Vitae/viavitae-control /tmp/vv-verify && cd /tmp/vv-verify
./scripts/bootstrap.sh --check                      # must print every missing prerequisite by name
```

Agent claims are not evidence. Each command and its output must be pasted into the PR.

### 6.6 Reversal (prompt §10.6)

a. **Everything in Tiers 1–5 is git-tracked**, so per-repo reversal is `git revert` of the
   squash-merge commit. No state is touched; no `terraform apply` occurs in any tier.
b. Tier 0 reversal: `sudo apt-mark unhold terraform`
   (`STOP — human approval required`), and remove the NodeSource repository if Option A was taken.
c. Restoration proof after reversal: re-run the Tier 3 census loop and confirm the float counts
   return to the §0 baseline; re-run `check_toolchain_pins.sh` and confirm it exits `2` (nothing
   to check) rather than `0`, because a removed guard must not report success.
d. There is no estate-wide irreversible step in this plan. That is a deliberate design property
   and it is the main reason this alternative beats option (d) in §3.2, whose reversal would mean
   rewriting every workflow back.

### 6.7 Bus factor (prompt §10.7)

a. Scenario: the operator is incapacitated for 90 days. A successor has repository access and no
   tribal knowledge.
b. **What they can do today:** clone a repo, run `terraform init -backend=false`, `validate`,
   `plan` in CI. Read the policies.
c. **What they cannot do today, from the repositories alone:**
   - reproduce the Node version — nothing declares it outside workflow `env:` blocks, and the
     host has the wrong one anyway;
   - reproduce `pre-commit` — it lives only in a git-ignored `.venv`, absent from `PATH`;
   - re-wire the git hooks — `.git/hooks` is never tracked and the shim hardcodes an absolute
     `.venv` interpreter path;
   - know which terraform to install — `.terraform-version` exists in one plane of three;
   - know that `apt-mark hold` was ever set.
d. **Tier 5 fixes exactly this**, and it is 40 lines of shell using tools already on the host:
   `scripts/bootstrap.sh` — checks prerequisites by name and exits non-zero listing what is
   missing; installs nothing without `--apply`; creates the `.venv`, installs `pre-commit`, runs
   `pre-commit install --install-hooks -t commit-msg -t pre-commit`, verifies the hooks fire, and
   prints the pinned versions from the manifest. No new supplier, no new binary, no trust model.
e. **Verdict: the bootstrap script is the highest-value item in this roadmap per hour spent**,
   because it is the only one that converts tribal knowledge into repository content. It is also
   the item mise would have delivered — which is the honest part of the case for mise, and it is
   answerable without mise.

### 6.8 Cost (prompt §10.8)

| Item | One-off | Recurring per quarter |
| --- | --- | --- |
| Tier 0 host fixes | 20 min | none |
| Tier 1 manifest plus guard | 2 h | 15 min — bump a SHA when an action is patched |
| Tier 2 two repos | 3 h | none |
| Tier 3 ten repos | 1 day | 30 min — regenerate and review propagator output |
| Tier 4 jolarca then jol | 2 days | 1 h — the two planes have the most refs |
| Tier 5 bootstrap script | 3 h | 15 min |
| **Total, recommended path** | **roughly 4.5 days** | **roughly 2 h per quarter** |
| For comparison: `mise` option (d) | 3 days local plus CI rewrite in every in-scope repo, plus paranoid-mode and path-protection work, plus vendor assessment | 2 h per repo per quarter of `mise lock --bump` review, plus tracking a project that releases several times a week |

The recommended path costs about the same one-off and **less** recurring, while addressing P2 and
P3 — which mise does not address at all. If the recurring cost of a control exceeds the drift it
prevents, it is not a control; on this arithmetic the mise path fails that test.

### 6.9 Roadmap (prompt §10.9)

```
Tier 0  host fixes (20 min, no PR)
  └─▶ Tier 1  manifest + guard in viavitae-control (2 h, 1 PR)   [prerequisite for 2, 3, 5]
        ├─▶ Tier 2  close viavitae-control + hermes-agents floats (3 h, 2 PRs)
        │     └─▶ Tier 3  propagate to 9 in-scope repos + template (1 day, 10 PRs)
        ├─▶ Tier 5  bootstrap.sh (3 h, 1 PR)   [independent of Tiers 2 and 3]
        ├─▶ Tier 4a  jolarca plane: own manifest, own guard, then 45-ref sweep (PCI, 1 day)
        └─▶ Tier 4b  jol plane: own manifest, own guard, then ~150-ref sweep (1 day)

Parallel and independent of all of the above:
  *  VV-2026-11-006  correct AI_WORKFLOW_POLICY.md §8 (30 min, 1 PR)
  *  VV-2026-11-007  add .terraform-version to jol-control and jolarca-control (30 min, 2 PRs)
  *  Decide on org-wide sha_pinning_required=true as its own project — NOT as a rider here
```

Box-drawing characters are used above deliberately, not decoratively: `scripts/check_audit_register.py`
treats any line beginning with a pipe as a markdown table row and does **not** skip fenced code
blocks, so an ASCII-art dependency diagram using `|` fails invariant I1 with "data row with no
header above it". Recorded as an observation in §10 item 11.

Tier 4a and 4b must each be executed **from their own control plane, by their own propagator, with
their own manifest**. There is no shared artifact and no cross-plane execution (§4.4).

---

## §7 Control mapping table

| Framework clause | Implemented control | From question | Evidence artifact | Status |
| --- | --- | --- | --- | --- |
| SOC 2 CC8.1 change management | Single-sourced version manifest plus a propagator and a failing guard | Q1, Q5 | `toolchain.yml`, `scripts/check_toolchain_pins.sh`, `audit.yml` step | gap — proposed |
| SOC 2 CC7.1 configuration management | `apt-mark hold terraform`; `.terraform-version` extended to all three planes | Q1 | `apt-mark showhold` output; three pin files | gap — proposed |
| SOC 2 CC9.2 vendor risk | Retain the publisher-signed HashiCorp apt channel; reject an unverified alternative | Q2, Q4 | `dpkg-query -W terraform`; `/usr/share/keyrings/hashicorp-archive-keyring.gpg` | implemented — decision recorded |
| SOC 2 CC6.1 logical access | Least-privilege CI token plus the existing credential pre-flight gate | Q4 | `scripts/check_ci_credential.sh` | implemented |
| SOC 2 CC6.6 external threats | SHA-pinned Actions in 29 of 31 repos; `provenance` required check with no bypass actors | Q1, Q4 | per-repo pin census; ruleset 23943250 | partially implemented — 2 repos and two planes outstanding |
| ISO A.8.9 configuration management | One declared value per tool per plane, guarded | Q1, Q3 | manifest plus guard exit codes | gap — proposed |
| ISO A.8.19 installation on operational systems | Distro-package installs only; no `curl` piped to `sh` | Q4 | §5.1 verdict | implemented — decision recorded |
| ISO A.8.25 secure development lifecycle | Local and CI tool versions reconciled; `bootstrap.sh` makes the environment reproducible | Q1, Q5 | §2.4 evidence; Tier 5 script | gap — proposed |
| ISO A.8.28 secure coding | PR-edited config cannot execute code in CI | Q4 | §5.4 analysis | implemented by rejection — no executable config file is being added |
| ISO A.8.4 source code protection | Path protection would be required for any executable config | Q4 | §5.4.f | N/A — no such file adopted |
| ISO A.5.19 to A.5.22 supplier relationships | No new supplier added; `mise-versions.jdx.dev` never enters the trust path | Q2, Q4 | §5.3.f | implemented — decision recorded |
| ISO A.8.32 change management | Every tier reversible by `git revert`; no state mutation anywhere | Q5 | §6.6 | implemented by design |
| GDPR Art. 5(1)(f) integrity and confidentiality | Build tooling provenance unchanged; no new outbound data flow | Q4 | §5.7 | implemented — decision recorded |
| GDPR Art. 28 processor contracts | Would be required for `mise-versions.jdx.dev` | Q4 | §5.7.c | avoided by rejection |
| GDPR Art. 32 security of processing | Host pinning plus reproducible bootstrap | Q1, Q5 | §6.7 | gap — proposed |
| PCI-DSS 4.0 Req. 2.2 and 6.5 | Eliminate 45 floating action refs in `jolarca`; per-plane manifest and guard | Q1, Q5 | §6.2 Tier 4a | **gap — highest severity** |
| PCI-DSS 4.0 Req. 11.3 integrity monitoring | Guard fails on any unreviewed SHA | Q5 | I4, I5 in §6.4 | gap — proposed |

---

## §8 Findings register

IDs are **proposed** as `VV-2026-11-NNN`. Confirmed unallocated as of 2026-11-03 — the live
register uses `VV-2026-10-018` through `VV-2026-10-029`. **Verify against `docs/COMPLIANCE.md`
before landing any ID**, and note that findings in the jol and jolarca planes need those planes'
own schemes, not `VV-`.

| ID | Sev | Entity | Root cause | Compensating control today | Remediation | Effort |
| --- | --- | --- | --- | --- | --- | --- |
| VV-2026-11-001 | **P1** | jolarca-dev | `jolarca` carries 45 floating action references; the org-level allow-list permits `@*` and `sha_pinning_required` is false | 2 SHA-pinned refs in the same repo; CodeQL and Trivy still run | Tier 4a sweep, then a per-plane guard | 1 day |
| VV-2026-11-002 | **P1** | Via-Vitae | Each repo pins action SHAs independently, so one action resolves to different commits in different repos — roughly 40 distinct refs for 19 names | Every individual ref is pinned, so no floating tag can move | Canonical SHA list in the manifest; guard invariants I4 and I5 | 2 h plus 1 day |
| VV-2026-11-003 | P2 | Via-Vitae | Host `node` v20.20.2 contradicts the declared `NODE_VERSION: "22"` in every repo and `viavitae-web/.nvmrc` | CI installs the correct version via SHA-pinned `setup-node`, so shipped artifacts are unaffected | Tier 0 decision plus install; Tier 5 bootstrap prevents recurrence | 20 min |
| VV-2026-11-004 | P2 | all three planes | The terraform apt package is not held, so `apt upgrade` can move it off 1.16.1 | Via-Vitae's `Assert toolchain pin` step detects divergence in CI after the fact | `sudo apt-mark hold terraform`; extend the pin file and assertion to the other two planes | 5 min plus 1 h |
| VV-2026-11-005 | P2 | Via-Vitae | `viavitae-control` (2 refs) and `viavitae-hermes-agents` (3 refs) are the only two repos in the org with floating action tags | The other 29 repos are fully pinned, so the org-wide pattern is known and proven | Tier 2, two PRs | 3 h |
| VV-2026-11-006 | **P1** | viavitae-control | `policies/AI_WORKFLOW_POLICY.md` §8 states `protect-main` lists no required status checks and that an admin can still merge. Ruleset 23943250 requires the `provenance` context, strict mode on, `bypass_actors: []` | The control itself is stronger than documented, so nothing is unprotected — but the **documentation understates a blocking control** | Correct §8 with the measured ruleset output and the measurement date | 30 min |
| VV-2026-11-007 | P2 | journeyoflife-org, jolarca-dev | Neither control plane has a `.terraform-version` file, so neither declares nor asserts its terraform pin | The host apt package is currently correct | Add the pin file to both, plus the assertion step | 30 min |
| VV-2026-11-008 | P2 | viavitae-control | `pre-commit` is absent from `PATH` and exists only in a git-ignored `.venv`; hooks hardcode an absolute interpreter path and `.git/hooks` is never tracked | The CI `provenance` gate blocks non-compliant merges server-side, so the control does not depend on the local hook | Tier 5 `bootstrap.sh` recreates the venv and re-wires the hooks | 3 h |
| VV-2026-11-009 | P2 | journeyoflife-org | Roughly 150 floating action references across the charity plane, including `jol-control` 16, `jol-ecommerce-engine` 23, `jol-link-registry` 21, `jol-auth` 20 | `jol-hub` (112 pinned), `jol-mcp-servers`, `jol-repo-template` and `jol-hermes-agents` prove the pattern is achievable in this plane | Tier 4b sweep | 1 day |
| VV-2026-11-010 | P2 | Via-Vitae | `NODE_VERSION` and `PYTHON_VERSION` are re-declared per workflow file per repo — roughly 40 separate declarations of two numbers — with no reconciliation gate | All currently agree, so there is no live divergence | Manifest plus propagator plus guard invariant I2 | included in Tier 1 and 3 |
| VV-2026-11-011 | P2 | Via-Vitae | All ten landing scaffolds and `viavitae-template` run a 32-reference CI declaring Node 22 and Python 3.12 and invoking `setup-uv`, Trivy and TruffleHog, while the manifest census finds no runtime in them | The CI is fully SHA-pinned, so it is not a supply-chain hole | Determine what each scaffold actually builds; trim inherited CI per repository type at the template level | 4 h |
| VV-2026-11-012 | record | all three planes | `mise` was assessed and rejected. Without a recorded decision the question will be re-litigated and the analysis redone | n/a | Land this decision package and link it from `policies/README.md` | done, pending approval |
| VV-2026-11-013 | P2 | Via-Vitae | `verified_allowed: true` admits third-party actions with no explicit pattern — proven by `aquasecurity/trivy-action`, referenced 41 times and absent from the allow-list. This delegates a publisher-vouching decision to GitHub | Individual repos SHA-pin the admitted actions, so the *version* is controlled even though the *admission* is delegated | Decide explicitly whether to keep `verified_allowed` on; if kept, record it as accepted risk with the clause | 1 h |
| VV-2026-11-014 | P2 | viavitae-control | `scripts/check_plan_selfcite.sh` detected a table's **header row by its cell text**: the header-exclusion regex matched a leading pipe, then the word `Task`, then a space — and the equivalents matched the words `Field` and `Action`. That exclusion is meant to skip only the header row whose first cell is the word Task, but it also matches every DATA row whose first cell begins with that word, so those rows are silently never counted. Measured on a 4-row tier table where two rows began with the word Task: the expression returned **2**. **Mechanism corrected after measurement — this is NOT a mawk/POSIX-class defect.** Substituting a literal space-and-tab class for the POSIX class changed the result not at all (still 2), and `gawk` is not installed on this host, so the previously-proposed remedy of "run it under gawk" was unavailable and would not have helped anyway. The POSIX-class concern is real but secondary: it affects the separator test, not the header test | Detected only because the author refused to assert a number he had not observed and dumped the per-line matches instead. Nothing in CI flags the silent undercount — a plan that genuinely has 10 tier rows would be required to assert 6, and both the stale assertion and the honest one are reachable | **Fixed positionally**: the first pipe-led line under a heading is the header, the second is the separator, everything after is data. Proven on the fixture (old 2, new 4, truth 4), proven sensitive (deleting a row drops it to 3), and proven non-regressive (every existing plan still matches its own assertions; tier_rows 10 and 13 assertions unchanged before and after the patch) | done — see the follow-on PR |
| VV-2026-11-015 | P2 | viavitae-control | A Terraform declaration diverges from local state with no register entry: `repos_data.tf:154` sets `is_template = true` for `viavitae-template` (committed as `f0998f3`) while `terraform.tfstate` records `is_template = false`, so every local `terraform plan` ends `Plan: 0 to add, 1 to change, 0 to destroy` and the intended change is never settled. **Scope corrected after measurement:** `f0998f3` is **not an ancestor of `origin/main`** — `git merge-base --is-ancestor f0998f3 origin/main` fails and `origin/main:repos_data.tf` contains **zero** `is_template` occurrences. So this is an unpushed local declaration diverging from local state, not a change landed on `main` and left unapplied. It becomes a real `main`-level divergence the moment that branch lands without an apply | The change is visible in any plan output and the AI workflow policy forbids apply without authorization, so nothing was silently mutated. But while it stands, the post-merge checklist item "post-merge plan confirms no drift" is **unsatisfiable**, which trains the operator to skip it | Owner decision: apply it, revert the declaration, or land the branch and then apply — in that order, recorded. Then make `No changes.` achievable again, and track pending applies in a register row or `detect_drift.sh` so they cannot become ambient noise | 30 min plus an authorized apply |
| VV-2026-11-016 | P2 | Via-Vitae | The org Actions allow-list admits `pnpm/action-setup` only through **two immutable commit SHAs**, while Dependabot is configured to bump GitHub Actions. Any bump to a third SHA is rejected at parse time, so the run ends `startup_failure` with **zero jobs, zero check-runs and no logs**, and the PR's required contexts never report. Measured: `viavitae-qa` run 39194144090 (2026-10-19, `dependabot[bot]` synchronize on `dependabot/github_actions/actions-c82648c587`, head `3a896253`) carries the annotation naming `pnpm/action-setup@fc06bc1257f339d1d5d8b3a19a8cae5388b55320` as not allowed; **PR #14 is still OPEN and can never go green**. `pnpm/action-setup` is owner type `Organization` with 1324 stars yet `verified_allowed: true` did not admit it, so it is not a Marketplace-verified creator — which is why the explicit SHA patterns exist at all | `viavitae-qa` `main` is healthy: it pins the allow-listed `b906affcce…`, its `ci.yml` parses, all five jobs are matrix-free, and every action repo resolves. So this is a frozen Dependabot PR, not a broken default branch — but it recurs on every future pnpm bump | Owner decision, and the change is `apply`-gated: (a) add the new SHA to `var.actions_allowed_patterns` in the same change that bumps, which Dependabot cannot do itself; (b) replace the two SHA patterns with `pnpm/action-setup@*`, restoring bumpability at the cost of a tenth floating pattern; (c) drop or replace the action. Independently of (a)-(c), add a detectability control that flags any open PR whose workflow last concluded `startup_failure`, because that failure mode is invisible in every aggregate check list | 30 min to close PR #14; 1 h plus an authorized apply for the structural fix |
| VV-2026-11-017 | P2 | viavitae-control | `scripts/test_control_guards.sh` planted **literal dates** as test fixtures. `SI2` used `2026-11-01` for its "about to expire" case; once the wall clock passed it, the near-expiry branch could never fire and the suite went permanently red. The healthy baseline `2027-01-15` carried the same latent rot and would have failed on 2027-01-01 when it crossed `WARN_DAYS` | Caught by reading the fixture rather than trusting the red result, then proven fixed by mutating the guard's own threshold and requiring `SI2` to go red | Fixed in `67b0d21`: `FAR = today + 90 days`, `NEAR = today + 3 days`. Guard the convention by rejecting hardcoded future dates in fixtures at review time, or add a self-check that the suite passes on a rolled-forward clock | done |
| VV-2026-11-018 | P2 | viavitae-control | Two remediations were written into this register on reasoning alone and both failed against a direct test. First, "run the checker under `gawk`" — `command -v gawk` returns nothing, so the alternative does not exist on this host. Second, attributing the tier-row undercount to mawk's lack of POSIX classes, when the literal-class substitution reproduced the identical wrong answer. The underlying habit is the same one this whole assessment exists to break: asserting a cause before measuring it. A third instance surfaced immediately: this very row's predecessor broke the register's own column-count invariant by carrying a pipe inside inline code, which is the fourth recorded occurrence of that hazard in this repository | Caught by running the counterfactual instead of arguing from the manual, and by `check_audit_register.py` failing the edit that introduced it | Standing rule applied from here on: every remediation in this register must name the command that verified it, every "this is the cause" claim must be reproduced by a test that can distinguish it from its rivals, and register rows must be re-checked with `check_audit_register.py` before commit because a pipe inside inline code silently adds columns | process change, done |
| VV-2026-11-019 | P2 | viavitae-control | Tier 2 of this assessment said "land `compliance-check.yml` in `viavitae-control` so rule R4 covers 31 of 31 repos." That premise is false on two independent counts. **(i)** The workflow's `governance` job requires 13 named files and this repo holds **3 of 13** — measured by direct existence tests, 10 missing — so adopting it would fail `governance` and the `compliance-status` aggregate on every PR: a gate red on arrival, the fourth instance of that pattern in this session. **(ii)** Some of the ten are not this repo's gap. Compared against the two sibling control planes, `docs/DPIA-template.md` is absent from **all three**, which makes the requirement a product-repo template defect rather than three coincidental omissions — a DPIA concerns personal data in a processing system, and a Terraform control plane processes none | Rule R4's substance for this repo is already enforced by the I1 block of `scripts/check_toolchain_pins.sh`, landed and green on `main` via PR #53, so no coverage is lost by not adopting the workflow. The workflow was also verified to reference only GitHub-owned actions, so there is no allow-list admission risk either — the blocker is content, not supply chain | Remediated by `docs/superpowers/plans/2026-11-03-viavitae-control-governance-artifacts.md`, which decides each file against the sibling planes: 8 adopt, 1 adapt, 1 reject with a stated reason. Do **not** create a `docs/DPIA-template.md` stub — that is gate-gaming of the class already rejected for the `print_hi` tests, and Tier 2 as originally worded is superseded | 1 day for the 9 real artifacts; the exclusion is a decision, not work |

---

## §9 Ordered remediation roadmap

Sequenced for one person working part-time. Prerequisites marked.

1. **Correct `AI_WORKFLOW_POLICY.md` §8** (VV-2026-11-006). 30 min, 1 PR. No prerequisite. Do this
   first: an audit that reads the policy will otherwise draw the wrong conclusion about a control
   that is actually stronger than documented.
2. **Tier 0 host fixes** (VV-2026-11-003, -004). 20 min, no PR.
   `STOP — human approval required before this step` for `apt-mark hold` and any Node install.
3. **Add `.terraform-version` to jol-control and jolarca-control** (VV-2026-11-007). 30 min, 2 PRs,
   executed from each plane. No prerequisite.
4. **Tier 1: manifest plus guard in viavitae-control** (VV-2026-11-002, -010). 2 h, 1 PR.
   Prerequisite: step 2. Must include the mutation proof in §6.4 before it may be called a control.
5. **Tier 5: `bootstrap.sh`** (VV-2026-11-008). 3 h, 1 PR. Prerequisite: step 4. Independent of 6
   and 7 — and the highest value per hour in this list.
6. **Tier 2: close the two floating-ref repos** (VV-2026-11-005). 3 h, 2 PRs. Prerequisite: step 4.
7. **Tier 3: propagate to the 9 in-scope repos plus the template**. 1 day, 10 PRs.
   Prerequisite: step 6.
8. **Tier 4a: jolarca plane** (VV-2026-11-001). 1 day. Prerequisite: step 4's *pattern*, replicated
   into `jolarca-control` as its own manifest and its own guard — **not shared, not executed from
   Via-Vitae**. This is the PCI-DSS item and it should not wait behind step 7 if capacity allows.
9. **Tier 4b: jol plane** (VV-2026-11-009). 1 day. Same isolation constraint as step 8.
10. **Resolve `verified_allowed`** (VV-2026-11-013). 1 h, decision recorded. Any change is
    `apply`-gated. `STOP — human approval required before this step`.
11. **Trim inherited landing CI** (VV-2026-11-011). 4 h. Prerequisite: step 7, because the trim
    should be done at the template level and then propagated.
12. **Decide org-wide `sha_pinning_required = true`** as its own project, with its own blast-radius
    assessment (nine floating patterns, roughly 150 floating refs in the charity plane).
    `STOP — human approval required before this step`. Explicitly **not** a rider on this work.
13. **Land this decision package** (VV-2026-11-012) and link it from `policies/README.md`.

---

## §10 What I could not determine

This section is required to be non-empty. It is.

1. **Which `mise` backend serves `terraform`, and what its verification is.** `mise` is absent so
   `mise tool terraform` cannot run. `gh api repos/jdx/mise/contents/registry.toml` returned
   nothing — the contents API refuses large files, and downloading it by other means was out of
   scope. **This is the single fact most likely to change §5.2 and therefore §5.9.** If terraform
   turns out to be `packslip:`-served with a pinned signer, the provenance argument weakens
   considerably — though §5.4's CI trust exemption would still stand alone.
2. **Whether `jdx` is a GitHub verified creator.** Not exposed by the REST API. It decides whether
   `jdx/mise-action` needs an allow-list pattern at all (§5.5.b).
3. **Whether `mise` emits telemetry, crash reports, or attributable version lookups.** Not stated
   on the four pages read. Would require reading the source. Decides whether a GDPR Art. 28
   processor assessment and a vendor-register entry are needed (§5.7).
4. **mise's full config precedence order** across `.miserc.toml`, system, global, monorepo-root and
   project scopes. Only the global-versus-project relationship was confirmable (§4.1.d).
5. **What the ten landing scaffolds actually build.** The census counted manifests, not source
   files. §2.5 gives two readings and cannot choose between them without reading each tree.
   This decides VV-2026-11-011's severity.
6. **Which three references float in `viavitae-hermes-agents`.** Counted, not enumerated.
7. **Whether the jolarca-dev and journeyoflife-org orgs have their own Actions allow-lists and
   `sha_pinning_required` settings.** Only Via-Vitae was queried. Tier 4 cannot be scoped
   precisely until both are read.
8. **Whether the nine empty repos are still empty.** Carried from the 2026-10-26 audit, not
   re-measured this pass.
9. **The local-versus-declared inventory reconciliation against `repos_data.tf`.** Prompt §5.5
   required it; it was not performed. The 34-versus-31 directory difference is explained by four
   worktrees, but no repo-by-repo reconciliation against the declared inventory was run, and the
   live org API was not enumerated.
10. **Whether `.venv`'s `pre-commit` 4.7.0 matches any intended pin.** No pin is declared anywhere,
    so there is nothing to compare against — which is itself the finding (VV-2026-11-008).
11. **Observation, not an open question — a false-positive class in an existing guard.**
    `scripts/check_audit_register.py` invariant I1 failed this document at the ASCII dependency
    diagram in §6.9, reporting "data row with no header above it" for a line inside a **fenced
    code block**. The checker's `is_table_row` test does not skip fenced blocks, so any pipe
    character at the start of a line inside a code block is read as a table row. Worked around
    here with box-drawing characters. The proper fix is to make `check_tables` ignore regions
    between triple-backtick fences — a small, testable change to a CI-critical control, so it is
    **proposed, not made**: this pass holds plan-only authority and the guard is a compliance gate.
    This is the same defect class the checker's own header already documents for pipes inside
    inline code in table cells; fenced blocks are a second instance of it.

---

## §11 Residual risk accepted

What remains unmitigated after the full roadmap in §9, and why it is tolerable.

1. **Detection, not prevention, for the host toolchain.** `apt-mark hold` stops accidental
   upgrades but a deliberate `apt install terraform=X` still works, and nothing on the host
   asserts the pin continuously. Tolerable because the CI assertion catches divergence on every
   run in Via-Vitae, and Tier 3 extends an equivalent assertion to the other two planes.
2. **Cross-repo SHA drift will recur.** A canonical SHA list plus a guard detects drift; it does
   not prevent a human pasting a new SHA into a new workflow. Tolerable because guard invariant
   I4 makes that paste fail the build, and the failure is loud and immediate rather than silent
   and late.
3. **`verified_allowed: true` remains a delegated trust decision** unless step 10 changes it.
   Tolerable only if recorded explicitly as accepted risk against ISO A.5.19–A.5.22, with the
   compensating control named: every admitted action is still SHA-pinned per repo, so the
   *version* is controlled even though the *admission* is not.
4. **No separation of duties anywhere in this roadmap.** One person authors the manifest, runs the
   propagator, reviews the PR and merges it. The compensating control is the same one the estate
   already relies on: the CI `provenance` required check with `bypass_actors: []`, which means the
   owner cannot merge without the trailer, plus squash-merge making the PR description the
   permanent record on `main`. That is a real control — and VV-2026-11-006 exists because the
   policy text currently denies it.
5. **`jolarca`'s 45 floating refs stay live until Tier 4a.** This is the largest accepted risk in
   this document and it is PCI-DSS scoped. It is tolerable only as a **dated, tracked, sequenced
   item**, not as a permanent state. If Tier 4a cannot be scheduled within 30 days, escalate it to
   P0 and reassess whether the PCI attestation position is affected.
6. **The estate still has no per-directory version switching.** If a repo ever genuinely needs
   Node 24 while another needs 22, the recommended design handles it through per-repo idiomatic
   version files — and, per §3.6 item 3, `mise` reads `.tool-versions` natively, so **the option
   to adopt mise later is preserved at zero cost.** This decision is reversible on new evidence,
   which is the condition recorded in §5.9(x): a demonstrated per-directory divergence.
7. **Local hooks remain bypassable.** `git commit --no-verify` defeats the `commit-msg` provenance
   hook, and hooks are inactive on a fresh clone until `pre-commit install`. Already documented as
   a known limitation; the authoritative layer is the CI gate, which §4.7.a confirmed **is**
   required and **cannot** be bypassed. Tier 5 reduces the fresh-clone window but does not close
   the `--no-verify` one, and nothing short of server-side enforcement can.

---

## §12 Self-audit checklist

One row per numbered sub-requirement of the prompt (§6.1–§10.9) plus the formatting rules.

| Requirement | Answered in | Verdict given |
| --- | --- | --- |
| 6.1 evidence table | §2.1 | yes |
| 6.2 three-copies problem | §2.2 | yes — compensating control, weak, collapse to one source |
| 6.3 unpinned host, cheapest fix scored | §2.3 | yes — do the hold, it is not sufficient |
| 6.4 CI/local divergence quantified from evidence | §2.4 | yes — one live divergence, zero recorded incidents |
| 6.5 empty and runtime-less repos | §2.5 | yes — out of scope for a manager, in scope for a manifest |
| 6.6 Question 1 verdict with severity | §2.6 | yes — problem exists, Medium estate-wide, High for PCI |
| 7.1 capability-to-need mapping | §3.1 | yes — and it found zero demand for the headline feature |
| 7.2 scored comparison, table not prose, nine options | §3.2 | yes — all nine scored, rejection record included |
| 7.3 `uv` and `direnv` overlap | §3.3 | yes — `uv` is the incumbent, `direnv` overlap is theoretical here |
| 7.4 the `tfenv` precedent | §3.4 | yes — inherited, not refuted, and strengthened by provenance |
| 7.5 release cadence | §3.5 | yes — manageable, marginal benefit does not pay for it |
| 7.6 Question 2 verdict, one of three forms | §3.6 | yes — **do not adopt**, with the alternative named |
| 8.1 resolution semantics with sources | §4.1 | yes — per-directory confirmed; full precedence order in §10 |
| 8.2 two-layer verdict | §4.2 | yes — files per repo, decisions single-sourced |
| 8.3 scope table, all 31 repos, verdict per row | §4.3 | yes — 9 in scope, 1 deferred, 1 source, 20 out |
| 8.4 boundary 1, four sub-questions | §4.4 | yes — config sharing prohibited, cache sharing acceptable |
| 8.5 generation versus authoring | §4.5 | yes — propagator follows the existing dry-run pattern |
| 8.6 worktrees and clones | §4.6 | yes — and it is an advantage for the recommended design |
| 8.7 empty and private repos | §4.7 | yes — unobserved, never passed; denominator corrected |
| 8.8 Question 3 verdict, literal question first | §4.8 | yes |
| 9.1 install provenance | §5.1 | yes — curl rejected, wrapper credited, bootstrap paradox named |
| 9.2 backend provenance table | §5.2 | yes — and terraform's row is the finding |
| 9.3 lockfile consequences and cache design | §5.3 | yes — fails closed, one platform suffices, never cache installs |
| 9.4 trust model and public-repo attack path | §5.4 | yes — decisive; three countermeasures assessed on their real terms |
| 9.5 CI action and allow-list | §5.5 | yes — may need no pattern; SHA-pin if it does |
| 9.6 rate limits and the token question | §5.6 | yes — largely dissolved by the lockfile, still the wrong shape |
| 9.7 telemetry | §5.7 | **CANNOT VERIFY** — recorded in §10 item 3, not guessed |
| 9.8 regression check against existing controls | §5.8 | yes — 1 broken, 4 degraded, 3 unaffected, 1 changed |
| 9.9 Question 4 verdict, local and CI separately | §5.9 | yes — no to both, ten non-negotiable conditions if revisited |
| 10.1 tiering with entry and exit criteria | §6.1 | yes — six tiers |
| 10.2 per-tier change set with commands and gates | §6.2 | yes — every mutating step carries the STOP line |
| 10.3 dry-run-first propagation | §6.3 | yes — follows `propagate_landing_scaffold.py` |
| 10.4 guard script to the house contract, mutation-proved | §6.4 | yes — 0/1/2, five invariants, six injected defects |
| 10.5 verification commands with expected output | §6.5 | yes — per tier, with directories named |
| 10.6 reversal, per repo and estate-wide | §6.6 | yes — all git-tracked, no state mutation anywhere |
| 10.7 bus factor | §6.7 | yes — five things a successor cannot do today |
| 10.8 cost, one-off and recurring | §6.8 | yes — and the mise path fails the recurring-cost test |
| 10.9 roadmap with prerequisites | §6.9 | yes |
| Format: acronyms defined at first use | throughout | yes |
| Format: table over paragraph for 3+ comparable items | throughout | yes — 20 tables |
| Format: commands copy-pasteable with directory stated | §2.2, §2.3, §6.2, §6.5 | yes |
| Format: every "should" or "must" carries a clause | §7 maps them | yes |
| Format: every `mise` capability claim cites a page read | §0, §4.1, §5.3, §5.4 | yes — four pages named |
| Format: length is not a virtue | throughout | yes — completeness over volume |

**Plan-only authority held throughout.** No `terraform apply`, no `git push`, no `git commit`, no
package install, no file written outside `docs/`, and no live org mutation. Every mutating step in
§6 carries a printed `STOP — human approval required before this step` gate. The only writes
performed were to the prompt asset (correcting falsified baseline claims, revision v1.1) and to
this decision package.

---

## Provenance

Evidence gathered on 2026-11-03, all read-only:

- Host probes on `jol`: `command -v` over twelve binaries; `apt-mark showhold`;
  `dpkg-query -W terraform`; `terraform version -json`; `uv --version`; `direnv version`;
  `node --version`; `python3 --version`; `jq --version`; `gh --version`;
  `.venv/bin/pre-commit --version`
- Manifest census across `/opt/viavitae/repos`, `/opt/jol/repos`, `/opt/jolarca/repos`
- `uses:` reference census across all three trees, classified SHA versus floating, per repository
- `NODE_VERSION` / `PYTHON_VERSION` declaration census across Via-Vitae workflows
- `.envrc`, `uv.lock` and `Makefile` census across all three trees
- Idiomatic-version-file `find` across all three trees
- `.git/hooks/commit-msg` and `.git/hooks/pre-commit` inspection in viavitae-control
- `/opt/jolarca/repos/jolarca-control/pyproject.toml`, `/opt/jol/repos/jol-control/Makefile`
- Live API: `gh api orgs/Via-Vitae/actions/permissions/selected-actions`,
  `gh api orgs/Via-Vitae/actions/permissions`, `gh api repos/jdx/mise-action`,
  `gh api repos/Via-Vitae/viavitae-control/rulesets`,
  `gh api repos/Via-Vitae/viavitae-control/rulesets/23943250`
- Repository files: `.github/workflows/audit.yml`, `.pre-commit-config.yaml`,
  `org_actions_policy.tf`, `policies/README.md`, `policies/AI_WORKFLOW_POLICY.md`,
  `scripts/check_audit_register.py`
- Upstream documentation read in full: `mise.jdx.dev/getting-started.html`,
  `mise.jdx.dev/security.html`, `mise.jdx.dev/dev-tools/mise-lock.html`,
  `mise.jdx.dev/continuous-integration.html`, and `mise.jdx.dev/` landing page

Related artifacts: [the source prompt](../prompts/2026-11-03-mise-toolchain-management-prompt.md) ·
[AI_WORKFLOW_POLICY.md](../../../policies/AI_WORKFLOW_POLICY.md) ·
[COMPLIANCE.md](../../COMPLIANCE.md) ·
[policies/README.md](../../../policies/README.md) ·
[2026-10-27 landing repos decision package](2026-10-27-viavitae-landing-repos-decision-package.md)
