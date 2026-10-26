#!/usr/bin/env bash
# #############################################################################
# reconcile_secret_register.sh — prove the public twin matches the confidential
# register, and enforce the rotation policy the expiry gate cannot express.
#
# WHY. Splitting the register in two (public `secret_id | expires` twin in
# viavitae-control, confidential full register in viavitae-compliance) creates a new
# failure mode: the two copies disagree and CI stays green, because the expiry gate
# reads only the twin. This script is the sync control. It also carries the rotation
# check (`last_verified` + `rotation`), which is the only way to enforce the
# `2099-*`/`never` rows — a date that never expires cannot be caught by an expiry gate.
#
# It runs LOCALLY (pre-commit / monthly operator sweep), never in CI: the CI role is
# read-only and provider.tf forbids Contents on those tokens, so a job here could not
# read the private repo even if we wanted it to.
#
# exit 0  twin matches register, no rotation overdue
# exit 1  divergence (missing/extra/duplicate id, mismatched date) or overdue rotation
# exit 2  either file unreadable or a register parses to zero rows — never a pass
#
# Usage: [PRIVATE_REGISTER=/path] ./scripts/reconcile_secret_register.sh [PUBLIC]
# #############################################################################
set -u

PUBLIC="${1:-docs/SECRETS_INVENTORY.md}"
PRIVATE="${PRIVATE_REGISTER:-/opt/viavitae/repos/viavitae-compliance/docs/security/SECRETS_INVENTORY.md}"

for f in "$PUBLIC" "$PRIVATE"; do
  if [ ! -r "$f" ]; then
    echo "::error::$f not readable — cannot verify the register is in sync (PRIVATE_REGISTER= overrides the path)"
    exit 2
  fi
done

# Emit "<secret_id><TAB><expires>" for the FIRST table of a register file, stopping at
# the end of that table. Stopping matters: parsing every `|` row to EOF is how a later
# table silently joins the enforced set.
extract() {
  awk -F'|' '
    /^[[:space:]]*\|/ {
      if (!hdr) {
        ei = 0; si = 0
        for (i = 1; i <= NF; i++) {
          g = $i; gsub(/^[ \t]+|[ \t]+$/, "", g); gl = tolower(g)
          if (gl == "expires") ei = i
          if (gl == "secret_id") si = i
        }
        if (ei && si) hdr = 1
        next
      }
      if ($0 ~ /^[[:space:]]*\|[ :|-]+$/) next
      v = $si; gsub(/^[ \t]+|[ \t]+$/, "", v)
      e = $ei; gsub(/^[ \t]+|[ \t]+$/, "", e)
      print v "\t" e
      rows++
      next
    }
    hdr && rows > 0 { exit }
  ' "$1"
}

P="$(extract "$PUBLIC")";  [ -z "$P" ] && { echo "::error::$PUBLIC parsed to zero rows — unparseable twin"; exit 2; }
R="$(extract "$PRIVATE")"; [ -z "$R" ] && { echo "::error::$PRIVATE parsed to zero rows — unparseable register"; exit 2; }

D="$(mktemp -d)"; trap 'rm -rf "$D"' EXIT
printf '%s\n' "$P" | sort -t$'\t' -k1,1 > "$D/pub"
printf '%s\n' "$R" | sort -t$'\t' -k1,1 > "$D/priv"
cut -f1 "$D/pub"  | sort > "$D/pub.ids"
cut -f1 "$D/priv" | sort > "$D/priv.ids"

rc=0
say() { echo "::error::$1"; rc=1; }

# 1. duplicate ids inside either file (a primary key that repeats is a broken register)
for pair in "twin:$D/pub.ids" "register:$D/priv.ids"; do
  name="${pair%%:*}"; file="${pair#*:}"
  dups=$(uniq -d "$file")
  [ -n "$dups" ] && say "duplicate secret_id in the $name: $(tr '\n' ' ' <<<"$dups")"
done

# 2. set equality — the hole the expiry gate cannot see (a deleted row was a silent pass)
while IFS= read -r id; do
  [ -n "$id" ] && say "[$id] is in the public twin but NOT in the confidential register — undocumented credential"
done < <(comm -23 "$D/pub.ids" "$D/priv.ids")
while IFS= read -r id; do
  [ -n "$id" ] && say "[$id] is in the confidential register but MISSING from the public twin — the CI expiry gate cannot see it"
done < <(comm -13 "$D/pub.ids" "$D/priv.ids")

# 3. value equality for the ids both files claim
join -t$'\t' "$D/pub" "$D/priv" | while IFS=$'\t' read -r id pe re; do
  if [ "$pe" != "$re" ]; then
    echo "::error::[$id] expiry disagrees: twin='$pe' register='$re' — the register is authoritative; re-derive the twin"
  fi
done | { cat; } > "$D/dateconf"
grep -q '::error' "$D/dateconf" && { cat "$D/dateconf"; rc=1; }

# 4. rotation policy on the confidential register: the only control that can catch a
#    row whose expiry is `2099-*` / `never` / `unknown`.
now=$(date -u +%s)
awk -F'|' '
  /^[[:space:]]*\|/ {
    if (!hdr) {
      for (i = 1; i <= NF; i++) {
        g = $i; gsub(/^[ \t]+|[ \t]+$/, "", g); gl = tolower(g)
        if (gl == "secret_id") si = i
        if (gl == "rotation") ri = i
        if (gl == "last_verified") li = i
      }
      if (si && ri && li) hdr = 1
      next
    }
    if ($0 ~ /^[[:space:]]*\|[ :|-]+$/) next
    v = $si; gsub(/^[ \t]+|[ \t]+$/, "", v)
    r = $ri; gsub(/^[ \t]+|[ \t]+$/, "", r)
    l = $li; gsub(/^[ \t]+|[ \t]+$/, "", l)
    if (v != "") print v "\t" r "\t" l
  }
  hdr && NF > 0 && $0 !~ /^[[:space:]]*\|/ { exit }
' "$PRIVATE" > "$D/rot"

if [ ! -s "$D/rot" ]; then
  echo "::error::no rotation/last_verified columns found in $PRIVATE — cannot enforce rotation policy"
  exit 2
fi

n_notice=0
while IFS=$'\t' read -r id rot lastv; do
  case "$rot" in
    *[0-9]d)
      days="${rot%d}"
      if ! lv=$(date -u -d "$lastv" +%s 2>/dev/null); then
        say "[$id] last_verified='$lastv' is not a date — rotation cannot be evaluated"
        continue
      fi
      due=$((lv + days * 86400))
      overdue=$(( (now - due) / 86400 ))
      if [ "$overdue" -gt 0 ]; then
        say "[$id] rotation OVERDUE by ${overdue} days (policy ${rot}, last verified ${lastv})"
      else
        echo "ok: [$id] rotation due in $(( -overdue )) days (${rot} from ${lastv})"
      fi ;;
    never|manual|on-compromise|on-role-change)
      n_notice=$((n_notice + 1))
      echo "::notice::[$id] rotation='$rot' — no date can enforce it; it is in the F-06 backlog" ;;
    "")
      say "[$id] has no rotation policy recorded" ;;
    *)
      say "[$id] rotation='$rot' is not parseable (expected Nd, never, manual, on-compromise, on-role-change)" ;;
  esac
done < "$D/rot"
[ "$n_notice" -gt 0 ] && echo "::notice::${n_notice} credential(s) rely on policy, not on a date"

if [ "$rc" -eq 0 ]; then
  echo "OK: twin and register agree on $(wc -l < "$D/pub.ids") credential(s) and no rotation is overdue"
else
  echo "Register out of sync or rotation overdue. The confidential register is authoritative: fix it, then re-derive the twin."
fi
exit "$rc"
