#!/usr/bin/env bash
# #############################################################################
# update_contact_emails.sh — role-address remediation for the Via-Vitae org.
#
# Rewrites published contact addresses to the plus-addressed Gmail streams
# declared in policies/EMAIL_POLICY.md, across every populated repo in the org.
#
# Why: viavitae.com has NO nameserver delegation (dig status: SERVFAIL) and
# viavitae.site has NS/A but NO MX. Every security@/dpo@/legal@viavitae.*
# address published in SECURITY.md, LICENSE, the DPIA templates and the live
# website is therefore undeliverable — a broken vulnerability-reporting channel
# and a broken GDPR Art. 38 DPO contact point.
#
# DRY-RUN BY DEFAULT. Pass --apply to open PRs. Never pushes to main directly.
#
# Usage:
#   ./scripts/update_contact_emails.sh                        # report only
#   ./scripts/update_contact_emails.sh --repos ".github viavitae-web"
#   ./scripts/update_contact_emails.sh --diff                 # patch, no commit
#   ./scripts/update_contact_emails.sh --check-residue        # run every gate, push nothing
#   ./scripts/update_contact_emails.sh --apply                # branch + PR
#
# --check-residue rewrites in the scratch clone, runs the residue and leak gates
# exactly as --apply would, then reverts. It is the only way to exercise the
# residue gate without pushing, so scripts/test_contact_email_gates.sh uses it.
# Both gates run for every repo, including ones with nothing to rewrite: skipping
# them made a repo holding an unmapped address report as "clean".
#
# Exit 0 on success; 1 if the residue gate finds a live-domain role address not
# covered by the table (that means the table needs a rule, not a retry).
# #############################################################################
set -euo pipefail

ORG="${ORG:-Via-Vitae}"
WORKDIR="${WORKDIR:-${TMPDIR:-/tmp}/vv-contact-emails}"
BRANCH="${BRANCH:-chore/contact-email-plus-addresses}"
# Commits must NOT re-publish the base inbox via author/DCO sign-off metadata.
COMMIT_EMAIL="${COMMIT_EMAIL:-journey4oflife+viavitae.github@gmail.com}"
COMMIT_NAME="${COMMIT_NAME:-JourneyOfLife}"
APPLY=0
DIFF=0
CHECK=0
REPOS=""
REPOS_EXPLICIT=0

# --- Mapping table: exact full-address literals only. ------------------------
# Full addresses (never "@domain" patterns) so contributor placeholders such as
# you@viavitae.com and sample tenant data are structurally impossible to match.
MAP=(
  "security@viavitae.com|journey4oflife+viavitae.security@gmail.com"
  "security@viavitae.site|journey4oflife+viavitae.security@gmail.com"
  "security@viavitae.eu|journey4oflife+viavitae.security@gmail.com"
  "dpo@viavitae.com|journey4oflife+viavitae.privacy@gmail.com"
  "privacy@viavitae.com|journey4oflife+viavitae.privacy@gmail.com"
  "legal@viavitae.com|journey4oflife+viavitae.billing@gmail.com"
  "billing@viavitae.com|journey4oflife+viavitae.billing@gmail.com"
  "platform@viavitae.com|journey4oflife+viavitae.github@gmail.com"
  "brand@viavitae.com|journey4oflife+viavitae.dev@gmail.com"
  "info@viavitae.com|journey4oflife+viavitae.dev@gmail.com"
  "support@viavitae.com|journey4oflife+viavitae.dev@gmail.com"
  "hello@viavitae.com|journey4oflife+viavitae.dev@gmail.com"
)

# Whole-sentence rules for claims that cannot survive the address swap: the
# published PGP key is registered under the dead security@viavitae.com UID, so
# pointing researchers at it after the swap would be a false assurance. These are
# matched as literal bytes (no regex), brackets and URLs included.
SENTENCE=(
  "Strongly encouraged. Our PGP public key is published on the [OpenPGP key servers](https://keys.openpgp.org/search?q=security%40viavitae.com); fetch and verify the fingerprint out of band before first use.|Optional. No PGP key is published for this mailbox yet. Use GitHub private vulnerability reporting (*Security* -> *Report a vulnerability*) as the access-controlled channel, or say in your report that you will send proof-of-concept material out of band and we will arrange it."
  "Key published at \`https://viavitae.eu/.well-known/pgp-key.txt\`|Not published yet — use GitHub private vulnerability reporting"
)

# The bare base inbox must never appear in repo content (GDPR Art. 5(1)(c)).
# It is DETECTED, never substituted: silently rewriting it would corrupt
# policies/viavitae-gmail-filters.xml, whose mai:email attribute must equal the
# real account address or Gmail refuses the import.
BASE_INBOX='journey4oflife@gmail.com'

# Paths that NAME an address instead of PUBLISHING it. Applied ONLY inside
# viavitae-control, because there these strings are the tool's own detector, the
# documented role mapping, and the evidence of the finding:
#   - this script (its BASE_INBOX pattern and its MAP table are the detector; a sweep
#     that rewrote them would neuter the tool and still leave the leak)
#   - the policy/README that document the role mapping and the mai:email exception
#   - plans/specs/COMPLIANCE, which record what the dead addresses were
# Scoped per-repo on purpose: another repo's README.md publishes a real contact and
# must still be swept, and a base-inbox leak there must still alarm.
DEFINITION_PATH_RE='scripts/update_contact_emails\.sh$|policies/EMAIL_POLICY\.md$|docs/COMPLIANCE\.md$|docs/superpowers/(plans|specs)/|(^|/)README\.md$|viavitae-gmail-filters\.xml$'

# Applied in every repo: the filter archive's account attribute must stay the real
# address or Gmail refuses the import.
BASE_INBOX_ALLOW='viavitae-gmail-filters\.xml$'

# The control plane is not a published contact surface: in this repo the old
# strings are the mapping table and the audit narrative, so sweeping it would
# rewrite its own rules. It is skipped unless passed explicitly to --repos, and
# even then DEFINITION_PATH_RE above still protects the definitions.
SWEEP_SKIP_REPOS="${SWEEP_SKIP_REPOS:-viavitae-control}"

# Addresses deliberately NOT rewritten (placeholders, sample tenant data, other
# legal entities). Used by the residue gate to separate "intentional" from
# "unmapped".
KEEP_RE='you@viavitae\.(com|site|eu)|author@viavitae\.eu|approver@viavitae\.eu|@(demo|test)\.viavitae\.(com|site|eu)|@parish\.lt|@example-parapija\.lt|@jolarca\.[a-z]+|@example\.(com|org|net|invalid)'

# Append-only evidence is NEVER rewritten. CHANGELOG entries and ADRs record that
# these addresses WERE undeliverable (viavitae-infra ADR-000); substituting the new
# value into that narrative would falsify the audit trail — it is the fix history of
# the very finding being remediated. Follow-up entries are added forward by hand.
EXCLUDE_PATH_RE="(^|/)CHANGELOG\\.md\$|(^|/)docs/adr/|(^|/)node_modules/|(^|/)dist/|(\\.lock|package-lock\\.json|pnpm-lock\\.yaml|yarn\\.lock)\$|viavitae-gmail-filters\\.xml\$"

usage() { sed -n '/^# Usage:/,/^# Exit/p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'; exit 2; }

# Drop grep "path:num:content" lines whose PATH field matches an exclusion regex.
# Anchors like "CHANGELOG\.md$" cannot be applied to the whole line (the line
# continues with :104:text), so the path field must be split off first.
filter_out_paths() {
  local exclude_re="$1" line path
  while IFS= read -r line; do
    path="${line%%:*}"
    if printf '%s' "${line}" | grep -q 'email-allow'; then continue; fi
    if ! printf '%s' "${path}" | grep -qE "${exclude_re}"; then
      printf '%s\n' "${line}"
    fi
  done
}

# Compute the residue gate for the current repo: a live-domain role address that
# no rule maps and no KEEP entry excuses. Echoes the offending lines.
residue_lines() { # $1 = dir, $2 = repo_exclude
  grep -rInIE '(security|dpo|legal|billing|privacy|platform|brand|info|support|hello)@viavitae\.[a-z]+' \
    --exclude-dir=.git "$1" 2>/dev/null | sed "s#^$1/##" \
    | filter_out_paths "$2" | grep -Ev "${KEEP_RE}" || true
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --apply) APPLY=1; shift ;;
    --diff) DIFF=1; shift ;;
    --check-residue) CHECK=1; shift ;;
    --repos) REPOS="${2:?--repos takes a space-separated list}"; REPOS_EXPLICIT=1; shift 2 ;;
    --org) ORG="${2:?--org needs a value}"; shift 2 ;;
    -h|--help) usage ;;
    *) echo "unknown argument: $1" >&2; usage ;;
  esac
done

for cmd in gh git grep python3; do
  command -v "${cmd}" >/dev/null 2>&1 || { echo "${cmd} required" >&2; exit 1; }
done

mkdir -p "${WORKDIR}"
TABLE="${WORKDIR}/contact_emails.map"          # one "old<TAB>new" pair per line
PATTERNS="${WORKDIR}/contact_emails.patterns"  # left-hand sides, fixed strings
REWRITER="${WORKDIR}/contact_emails_rewrite.py"
: > "${TABLE}"; : > "${PATTERNS}"

# Literal byte-for-byte substitution engine. Deliberately NOT sed: the sentence
# rules contain `[`, `(`, `.` and `/`, which a BRE would reinterpret as syntax
# (that silently no-op'd the PGP rule when this ran through sed).
cat > "${REWRITER}" <<'PY'
import sys

table, *paths = sys.argv[1:]
pairs = []
with open(table, "rb") as fh:
    for line in fh:
        if b"\t" in line:
            old, new = line.rstrip(b"\n").split(b"\t", 1)
            pairs.append((old, new))
changed = 0
for path in paths:
    with open(path, "rb") as fh:
        data = fh.read()
    out = data
    for old, new in pairs:
        out = out.replace(old, new)
    if out != data:
        with open(path, "wb") as fh:
            fh.write(out)
        changed += 1
print(f"rewrote {changed}/{len(paths)} file(s)")
PY

# '|' delimits the two sides in the arrays above; neither side may contain one.
emit_rule() {
  local rule="$1" old new
  old="${rule%%|*}"; new="${rule#*|}"
  if [[ "${old}" == "${rule}" || -z "${new}" ]]; then
    echo "malformed rule (no '|'): ${rule}" >&2; exit 1
  fi
  printf '%s\t%s\n' "${old}" "${new}" >> "${TABLE}"
  printf '%s\n' "${old}" >> "${PATTERNS}"
}
for rule in "${MAP[@]}" "${SENTENCE[@]}"; do emit_rule "${rule}"; done

if [[ -z "${REPOS}" ]]; then
  REPOS="$(gh api "orgs/${ORG}/repos?per_page=100" --jq '.[].name' | tr '\n' ' ')"
fi

repos_touched=0; files_touched=0; unmapped=0; leaked=0; skipped=(); skipped_by_policy=()

# Apply the policy skip list only when the repo set was discovered automatically.
# If the operator names repos with --repos, that is an explicit override and is honored.
if [[ ${REPOS_EXPLICIT} -eq 0 && -n "${SWEEP_SKIP_REPOS}" ]]; then
  kept=()
  for candidate in ${REPOS}; do
    if [[ " ${SWEEP_SKIP_REPOS} " == *" ${candidate} "* ]]; then
      skipped_by_policy+=("${candidate} (control plane: holds the mapping table and the audit narrative)")
    else
      kept+=("${candidate}")
    fi
  done
  REPOS="${kept[*]:-}"
fi

printf '\n=== %s: contact-address remediation (%s) ===\n\n' "${ORG}" \
  "$(if [[ ${APPLY} -eq 1 ]]; then echo 'APPLY — PRs will be opened'; else echo 'DRY-RUN — nothing pushed'; fi)"

for repo in ${REPOS}; do
  dir="${WORKDIR}/${repo}"
  # Inside the control plane only, additionally protect the definitions/evidence.
  repo_exclude="${EXCLUDE_PATH_RE}"
  repo_leak_allow="${BASE_INBOX_ALLOW}"
  if [[ "${repo}" == "viavitae-control" ]]; then
    repo_exclude="${EXCLUDE_PATH_RE}|${DEFINITION_PATH_RE}"
    repo_leak_allow="${BASE_INBOX_ALLOW}|${DEFINITION_PATH_RE}"
  fi
  if [[ ! -d "${dir}/.git" ]]; then
    if ! git clone -q --depth 1 --single-branch "https://github.com/${ORG}/${repo}" "${dir}" 2>/dev/null; then
      skipped+=("${repo} (clone failed — empty repo or no access)"); continue
    fi
  fi
  base_branch="$(git -C "${dir}" rev-parse --abbrev-ref HEAD 2>/dev/null || true)"
  if [[ -z "${base_branch}" || "${base_branch}" == "HEAD" ]]; then
    skipped+=("${repo} (no commits on default branch)"); continue
  fi

  hits="$(grep -rlIF -f "${PATTERNS}" \
            --exclude-dir=.git --exclude=.contact-hits.txt "${dir}" 2>/dev/null || true)"
  # Drop append-only evidence and build artefacts before anything else.
  if [[ -n "${hits}" ]]; then
    hits="$(printf '%s\n' "${hits}" | sed "s#^${dir}/##" | grep -vE "${repo_exclude}" || true)"
  fi
  files=()
  if [[ -n "${hits}" ]]; then
    mapfile -t files < <(printf '%s\n' "${hits}" | sort)
  fi

  # --- Gates run for EVERY repo, before the "nothing to rewrite" shortcut. ---------
  # Skipping them when no file matched a rule made a repo containing an unmapped
  # live-domain address report as "clean" — a gate that does not run cannot return OK.
  leak="$(grep -rInIF "${BASE_INBOX}" --exclude-dir=.git "${dir}" 2>/dev/null \
           | sed "s#^${dir}/##" \
           | filter_out_paths "${repo_leak_allow}" || true)"
  if [[ -n "${leak}" ]]; then
    echo "      ! BASE-INBOX LEAK in ${repo} (publishes the personal address):" >&2
    printf '%s\n' "${leak}" | sed 's/^/        /' >&2
    leaked=1
  fi

  # Rewrite in the scratch clone for EVERY mode, so all four modes evaluate the same
  # post-state and cannot disagree. A projection (filtering the pre-state text instead)
  # was tried first and was wrong: dropping any line containing a mapped address also
  # dropped an UNMAPPED address sitting on the same line, so the dry-run stayed silent
  # where --check-residue blocked. Non-apply modes revert below.
  pre_report=""
  if [[ ${#files[@]} -gt 0 && ${APPLY} -eq 0 && ${CHECK} -eq 0 && ${DIFF} -eq 0 ]]; then
    pre_report="$(grep -hInIF -f "${PATTERNS}" -- "${files[@]/#/${dir}/}" \
                   | sed "s#^${dir}/##" | sed 's/^/      was: /' | sort -u | sed -n '1,10p' || true)"
    kept_addrs="$(grep -hIofE "${KEEP_RE}" -- "${files[@]/#/${dir}/}" 2>/dev/null | sort -u | tr '\n' ' ' || true)"
  fi
  if [[ ${#files[@]} -gt 0 ]]; then
    python3 "${REWRITER}" "${TABLE}" "${files[@]/#/${dir}/}" >/dev/null
  fi

  resid="$(residue_lines "${dir}" "${repo_exclude}")"

  if [[ ${#files[@]} -eq 0 ]]; then
    if [[ -n "${resid}" ]]; then
      echo "      ! UNMAPPED residue in ${repo} (no rule matched any address here):" >&2
      printf '%s\n' "${resid}" | sed 's/^/        /' >&2
      unmapped=1
    else
      printf '%-34s clean\n' "${repo}"
      # In rehearsal, say so explicitly: the gates ran here, they did not skip it.
      [[ ${CHECK} -eq 1 ]] && printf '      gates OK for %s (nothing to rewrite)\n' "${repo}"
    fi
    continue
  fi

  printf '%-34s %d file(s)  [base: %s]\n' "${repo}" "${#files[@]}" "${base_branch}"
  printf '      %s\n' "${files[@]}"
  repos_touched=$(( repos_touched + 1 ))
  files_touched=$(( files_touched + ${#files[@]} ))

  if [[ ${APPLY} -eq 0 && ${CHECK} -eq 0 ]]; then
    if [[ ${DIFF} -eq 1 ]]; then
      git -C "${dir}" --no-pager diff --stat | sed -n '1,25p'
      git -C "${dir}" --no-pager diff -U0 | grep -E '^[+-][^+-]' | sed -n '1,12p'
    else
      [[ -n "${pre_report}" ]] && printf '%s\n' "${pre_report}"
      [[ -n "${kept_addrs}" ]] && printf '      kept (placeholder/sample): %s\n' "${kept_addrs}"
    fi
    if [[ -n "${resid}" ]]; then
      echo "      ! UNMAPPED residue in ${repo} (would block --apply):" >&2
      printf '%s\n' "${resid}" | sed 's/^/        /' >&2
      unmapped=1
    fi
    # Nothing was going to be committed: put the scratch clone back as found.
    git -C "${dir}" checkout -q -- .
    echo
    continue
  fi

  if [[ ${CHECK} -eq 1 ]]; then
    # Gate rehearsal: report, revert, and never push.
    if [[ -n "${resid}" ]]; then
      echo "      ! UNMAPPED residue in ${repo} (would block --apply):" >&2
      printf '%s\n' "${resid}" | sed 's/^/        /' >&2
      unmapped=1
    else
      printf '      gates OK for %s\n' "${repo}"
    fi
    git -C "${dir}" checkout -q -- .
    continue
  fi

  if [[ -n "${resid}" ]]; then
    echo "      ! UNMAPPED residue in ${repo}:" >&2
    printf '%s\n' "${resid}" | sed "s#^${dir}/#        #" >&2
    unmapped=1; git -C "${dir}" checkout -q -- . ; continue
  fi

  # --apply reached the gate cleanly: keep the rewrite (it becomes the commit).
  git -C "${dir}" checkout -q -B "${BRANCH}" "${base_branch}"
  git -C "${dir}" add -A -- "${files[@]}"
  git -C "${dir}" -c user.name="${COMMIT_NAME}" -c user.email="${COMMIT_EMAIL}" \
    commit -q -s -F - <<'MSG'
docs(contacts): point role addresses at plus-addressed streams

Replaces security@/dpo@/legal@viavitae.* with the receiving Gmail
plus-addresses declared in viavitae-control policies/EMAIL_POLICY.md,
because those domain addresses have no MX and cannot receive reports.
The PGP claim is removed until a key exists for the security mailbox.

ai:cheap
MSG
  git -C "${dir}" push -q -f origin "${BRANCH}"
  pr_url="$(gh pr create -R "${ORG}/${repo}" --head "${BRANCH}" --base "${base_branch}" \
    --title "docs(contacts): point role addresses at plus-addressed streams" \
    --body "$(cat <<'PRBODY'
Mechanical contact-address remediation run by `scripts/update_contact_emails.sh`
in `viavitae-control`.

**Reason:** `viavitae.com` has no nameserver delegation and `viavitae.site` has no MX,
so the published `security@` / `dpo@` / `legal@` addresses cannot receive anything.
They are mapped to the plus-addressed streams in `policies/EMAIL_POLICY.md`.

- Contributor placeholders (`you@viavitae.com`) and sample tenant data unchanged.
- PGP key-server reference removed — no key is published for the security mailbox.
- Residue gate passed: no unmapped `@viavitae.*` role address remains.

ai:cheap
PRBODY
)")"
  # gh needs the PR number as a positional argument even when -R is given.
  pr_num="${pr_url##*/}"
  # This org has enablePullRequestAutoMerge off, so --auto is refused; the PR then
  # needs a review from a second account and a manual squash merge. Reported, not hidden.
  if ! gh pr merge "${pr_num}" -R "${ORG}/${repo}" --squash --auto 2>/dev/null; then
    printf '      %s: PR %s ready; auto-merge unavailable -> after review run: gh pr merge %s -R %s/%s --squash\n' \
      "${repo}" "${pr_num}" "${pr_num}" "${ORG}" "${repo}" >&2
  fi
  printf '      PR: %s\n' "${pr_url}"
done

printf '\n=== summary: %d repo(s) with changes, %d file(s); %d skipped ===\n' \
  "${repos_touched}" "${files_touched}" "${#skipped[@]}"
if [[ ${#skipped[@]} -gt 0 ]]; then printf '  - no commits: %s\n' "${skipped[*]}"; fi
if [[ ${#skipped_by_policy[@]} -gt 0 ]]; then
  printf '  - skipped by policy (definitions/evidence live here, not published contacts):\n'
  printf '      %s\n' "${skipped_by_policy[@]}"
fi
if [[ ${APPLY} -eq 0 && ${CHECK} -eq 0 ]]; then
  printf 'Dry-run only. Re-run with --diff to preview patches, --check-residue to rehearse\n  every gate without pushing, or --apply to open PRs (squash-merge after peer review).\n'
fi
if [[ ${unmapped} -eq 1 ]]; then
  echo "STOP: add a MAP rule for the residue above and re-run." >&2; exit 1
fi
if [[ ${leaked} -eq 1 ]]; then
  echo "STOP: the bare base inbox is published in tracked content (see leaks above)." >&2
  echo "Fix it by hand — this script will not substitute it (see EMAIL_POLICY.md rule 3)." >&2
  exit 1
fi
exit 0
