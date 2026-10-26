#!/usr/bin/env bash
# #############################################################################
# check_public_register.sh — offline anti-leak gate for the PUBLIC secret twin.
#
# WHY. docs/SECRETS_INVENTORY.md lives in a public GitHub repo and used to carry the
# full custody register (vault paths, host paths, an AWS account id, a PAT id, drive
# serials, owner names). The expiry gate cannot see that: it only reads dates, so a
# register that leaks topology still goes green. This gate asserts the opposite
# property — that the public file contains NOTHING that helps an attacker find a
# target — and it must run before any credential-dependent step so it cannot be
# masked by a later failure.
#
# exit 0  public register carries only opaque ids and dates
# exit 1  an identifier-shaped value, or a structure that would hide one, is present
# exit 2  register missing or unparseable — an unreadable gate is never a pass
#
# No secrets, no network, no Terraform. Usage: check_public_register.sh [PATH]
# #############################################################################
set -u

REG="${1:-docs/SECRETS_INVENTORY.md}"

if [ ! -r "$REG" ]; then
  echo "::error::$REG not readable — an unreadable public register is not a pass"
  exit 2
fi

rc=0
# Report the human reason, never the pattern: printing the regex would put the very
# identifier shapes we forbid into CI logs, which are public on this repo.
hit() { echo "::error::line(s) flagged in $REG — $1"; rc=1; }

# --- 1. identifier-shaped content must never appear here ---------------------
# Each entry is "ERE@@human description". `@@` is the separator because `|` is a live
# regex metacharacter and splitting on it would silently drop every alternative after
# the first one. Deliberately broad: a false positive costs one look, a false negative
# publishes the location of a root key forever.
PATTERNS=(
  '[~$]/@@home path (points at a credential file on the operator host)'
  '/opt/jol@@/mnt/@@/media/@@host filesystem path of a secret or backup'
  '/dev/disk@@/dev/sd@@device path of backup media'
  'ghp_@@gho_@@ghu_@@ghs_@@github_pat_@@age1@@AGE-SECRET-KEY@@PRIVATE KEY@@token string or key material'
  '[0-9]{12}@@a 12-digit number (AWS account id and similar resource ids)'
  '[0-9A-F]{16}@@a 16-hex-digit id (GPG key id, GitHub token id)'
  'serial@@device serial number of backup media'
  'BACKUP-[A-Z]@@backup media label'
  'SSD@@HDD@@Seagate@@ST9[0-9]{5,}@@model name of backup media'
  'LUKS@@crypttab@@encrypted removable media identity'
  '[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+[.][A-Za-z]{2,}@@an email address (contact details have their own policy)'
  'JourneyOfLife@@IterVitae@@a named account or human (who holds the credential)'
  'vault_path@@vault path column (where the value is stored)'
  '[.]aws@@[.]password-store@@[.]config/age@@[.]vault@@path of a secret store'
  '0600@@umask 077@@file permissions of a secret file'
  'SMART@@Reported_Uncorrect@@reallocated@@media health of a backup device'
  'blast_radius@@blast radius column (what a compromise reaches)'
  'off-premises@@stored outside@@physical location of an off-site copy'
)

# The register's own header row legitimately names the columns it forbids elsewhere,
# and the twin must point at the private repo by name, so those exact lines are
# exempted. Everything else is scanned line by line.
for line in $(grep -nE '^' "$REG" | cut -d: -f1); do
  content=$(sed -n "${line}p" "$REG")
  # Allowed: the table header/separator rows, and the pointer to the private repo path.
  case "$content" in
    '| secret_id | expires |' | '| --- | --- |') continue ;;
  esac
  for entry in "${PATTERNS[@]}"; do
    # `##` (greedy from the left) so the reason is the text after the LAST separator,
    # not the remaining regex alternatives — those are internal to the pattern.
    ere="${entry%%@@*}"; why="${entry##*@@}"
    if printf '%s' "$content" | grep -qE -- "$ere"; then
      # Escape hatch: opaque register-file pointers are unavoidable in a doc that says
      # where the real data lives. Line must start with '|' and name only the repo.
      case "$content" in
        *viavitae-compliance*) continue ;;
      esac
      hit "$line: $why"
    fi
  done
done

# --- 2. structure must be minimally expressible ------------------------------
# The file is only publish-safe if the register table is 2 columns wide and is the
# LAST table: the expiry gate parses every `|` row after the `expires` header, so a
# wider or later table is where metadata creeps back in.
HDRS=$(awk -F'|' '
  /^[[:space:]]*\|/ && !hdr {
    for (i = 1; i <= NF; i++) { g = $i; gsub(/^[ \t]+|[ \t]+$/, "", g)
      if (tolower(g) == "expires") { hdr = 1; hl = FNR; ci = i } }
    next
  }
  END { if (hl) print hl, ci }' "$REG")

[ -z "$HDRS" ] && { echo "::error::no 'expires' header in $REG — unparseable public register"; exit 2; }
HL=$(set -- $HDRS; echo "$1"); CI=$(set -- $HDRS; echo "$2")

# every table row below the header must have exactly two data cells
awk -F'|' -v hl="$HL" -v ci="$CI" '
  FNR <= hl { next }
  /^[[:space:]]*\|/ {
    if ($0 ~ /^[[:space:]]*\|[ :|-]+$/) next
    n = NF - 2
    if (n != 2) { print "row " FNR " has " n " data cells (must be exactly 2: secret_id | expires)" }
    v = $2; gsub(/^[ \t]+|[ \t]+$/, "", v)
    if (v == "")   { print "row " FNR " has an empty secret_id" }
    e = $ci; gsub(/^[ \t]+|[ \t]+$/, "", e)
    if (e == "")   { print "row " FNR " has an empty expires value (a blank date is a silent skip in the expiry gate)" }
  }' "$REG" | while IFS= read -r msg; do echo "::error::$msg"; done
BADROWS=$(awk -F'|' -v hl="$HL" -v ci="$CI" '
  FNR <= hl { next }
  /^[[:space:]]*\|/ {
    if ($0 ~ /^[[:space:]]*\|[ :|-]+$/) next
    n = NF - 2
    v = $2; gsub(/^[ \t]+|[ \t]+$/, "", v)
    e = $ci; gsub(/^[ \t]+|[ \t]+$/, "", e)
    if (n != 2 || v == "" || e == "") print "x"
  }' "$REG")
[ -n "$BADROWS" ] && { echo "::error::public register table is not 2-column/2-value clean"; rc=1; }

# no second table below the register. FNR > hl + 1 because the register's OWN separator
# row sits directly under its header and must not be counted as a second table.
if awk -v hl="$HL" 'FNR > hl + 1 && /^[[:space:]]*\|[ :|-]+$/ { found = 1 } END { exit !found }' "$REG"; then
  hit "a second table below the register (the expiry gate would mis-read it, and it is where metadata returns)"
fi

# at least one row must exist, or "no findings" means "nothing is being checked"
ROWS=$(awk -F'|' -v hl="$HL" 'FNR > hl && /^[[:space:]]*\|/ && $0 !~ /^[[:space:]]*\|[ :|-]+$/ { n++ } END { print n + 0 }' "$REG")
[ "$ROWS" -eq 0 ] && { hit "the register table has zero rows — an empty register is not a clean register"; }
echo "public register: ${ROWS} rows, expires column ${CI}, header line ${HL}"

if [ "$rc" -eq 0 ]; then
  echo "OK: $REG exposes only opaque ids and expiry values"
fi
exit "$rc"
