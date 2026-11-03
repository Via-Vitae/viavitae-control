# Changelog

All notable changes to this repository are documented here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/); this project does not tag releases,
because its deliverable is live organization configuration rather than a versioned artifact —
`terraform plan` output and the state serial are the version markers.

Every entry below is a squash-merged commit subject read from `origin/main`, not a recollection.
Reproduce the list with:

```bash
git log --date=short --format='%ad %h %s' --grep='(#5[0-9])' origin/main
```

Work that is still on an unmerged branch is **deliberately absent** from this file, and no line
here states a merge status. That is not caution for its own sake: a sentence recording that a
branch is open, unmerged, or awaiting a pull request goes stale the moment the merge lands, and it
then sits on `main` asserting something false about itself - including, in the case this rule
replaces, a claim that no pull request existed inside the pull request that carried it. A change
earns its line only once the command above prints it, at which point the line is added with the
squash SHA and PR number as recorded facts rather than predictions.

## [Unreleased] — 2026-11-03

### Added

- Single-source toolchain version and canonical-pin manifest (`toolchain.yml`) plus the
  pin-drift guard `scripts/check_toolchain_pins.sh`, wired into `audit.yml` ahead of every
  credential-dependent step; the two floating workflow refs were SHA-pinned in the same
  change — `7055f21` (#53), 2026-11-03.
- Register-integrity guard `scripts/check_audit_register.py` enforcing eight structural
  invariants (I1–I8) over the audit register and the specs, wired into `audit.yml`, and
  sensitivity proven by mutation rather than by reading the code; the throwaway checkers it
  replaces had already caught the same class of defect four times in one session —
  `b1b2e32` (#51), 2026-10-28.
- Landing-repos decision package (finding `VV-2026-10-024`) and the corrected estate evidence —
  `55cc28d` (#50), 2026-10-27.
- Plan for the `pnpm/action-setup` pin convergence, recording the frozen Dependabot PR behind
  finding `VV-2026-11-016` — `aac0d79` (#55), 2026-11-03.
- Finding `VV-2026-11-019` and the governance-artifacts implementation plan that remediates it —
  `0708945` (#56), 2026-11-03.

### Changed

- The mise toolchain adoption decision package and its management prompt were committed with
  #53, so the Tier 1/Tier 2/Tier 3 sequencing is now a tracked artifact rather than a
  conversation — `7055f21` (#53), 2026-11-03.

### Fixed

- `scripts/check_plan_selfcite.sh` detected table headers by cell text; it now detects them
  positionally, which stops a legitimate header row being reported as a malformed one —
  `1ff8240` (#54), 2026-11-03.
