#!/usr/bin/env bash
# check_secret_inventory.sh — expiry gate for the secret register (metadata only).
#
# Reads the `expires` column of docs/SECRETS_INVENTORY.md and fails CI when any
# dated credential is expired or expires within WARN_DAYS (default 14) days.
#
# exit 0  every dated credential expires more than WARN_DAYS days ahead
# exit 1  a credential is expired, expires within WARN_DAYS, or has expiry=unknown
# exit 2  register missing or unparseable — an unreadable gate is never a pass
#
# Rows with a 2099-* placeholder ("no server-side expiry") and `never` (root keys)
# cannot be enforced by date; they surface as warnings/notices, never as passes.
# No secrets, no network: the step must fail on its own merits, before any
# credential-dependent step can mask it.
set -u

INV="${1:-docs/SECRETS_INVENTORY.md}"
WARN_DAYS="${WARN_DAYS:-14}"

if [ ! -r "$INV" ]; then
  echo "::error::$INV not readable — an unreadable register is not a pass"
  exit 2
fi

# Extract the `expires` column of the register table: find the header cell, then
# emit "<line number>TAB<value>" for every following table row, skipping the |---|
# separator, and STOP at the end of that table. Stopping matters: parsing to EOF let a
# later table join the enforced set with the wrong column index, which is how a
# mis-parsed row could report a date that was never an expiry.
# A row that is too short yields an EMPTY value, not a missing one — the caller must
# treat empty as a finding, because "row truncated so the date vanished" was a silent
# pass. This gate still cannot see a row that was deleted outright; that is what
# scripts/reconcile_secret_register.sh proves against the confidential register.
CELLS=$(awk -F'|' '
  /^[[:space:]]*\|/ {
    if (!hdr) {
      for (i = 1; i <= NF; i++) {
        g = $i; gsub(/^[ \t]+|[ \t]+$/, "", g)
        if (tolower(g) == "expires") { hdr = 1; ci = i }
      }
      next
    }
    if ($0 ~ /^[[:space:]]*\|[ :|-]+$/) next
    v = $ci; gsub(/^[ \t]+|[ \t]+$/, "", v); print FNR "\t" v
    rows++
    next
  }
  hdr && rows > 0 { exit }
' "$INV")

if [ -z "$CELLS" ]; then
  echo "::error::no 'expires' column or no rows found in $INV — unparseable register"
  exit 2
fi

rc=0
now=$(date -u +%s)
while IFS=$'\t' read -r lineno exp; do
  if [ -z "$exp" ]; then
    # was `[ -z "$exp" ] && continue` — a silent pass for any row shortened to hide
    # its expiry. An unreadable cell is a finding, never an absence of one.
    echo "::error::row at line $lineno has no readable 'expires' cell (truncated row is not a passing row)"
    rc=1
    continue
  fi
  case "$exp" in
    never)
      echo "::notice::root-key row (line $lineno): rotation is on-compromise only"
      continue ;;
    unknown)
      echo "::error::expiry unknown for the row at line $lineno of $INV — verify and record it"
      rc=1
      continue ;;
    2099-*)
      echo "::warning::$exp (line $lineno) is a no-server-side-expiry placeholder: enforce by rotation policy (see reconcile_secret_register.sh)"
      continue ;;
    [0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9])
      ;; # fall through to the date math below
    *)
      echo "::error::unparseable expires value '$exp' at line $lineno of $INV"
      rc=2
      break ;;
  esac
  if ! e=$(date -u -d "$exp" +%s 2>/dev/null); then
    echo "::error::invalid date '$exp' at line $lineno of $INV"
    rc=2
    break
  fi
  days=$(( (e - now) / 86400 ))
  if [ "$days" -lt 0 ]; then
    echo "::error::credential EXPIRED $((-days)) days ago ($exp, line $lineno)"
    rc=1
  elif [ "$days" -le "$WARN_DAYS" ]; then
    echo "::error::credential expires in $days days (<= $WARN_DAYS): $exp at line $lineno — rotate now"
    rc=1
  else
    echo "ok: $exp (line $lineno, $days days out)"
  fi
done <<< "$CELLS"

exit "$rc"
