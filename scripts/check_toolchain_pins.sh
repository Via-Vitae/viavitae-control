#!/usr/bin/env bash
# #############################################################################
# check_toolchain_pins.sh — fail when this repo drifts from toolchain.yml.
#
# WHY THIS EXISTS AND RULE R4 DOES NOT COVER IT. R4 (compliance-check.yml
# `action-pinning`) asserts a reference IS a 40-char SHA. It cannot assert the
# SHA is the one the rest of the org runs. Measured 2026-11-03, actions/checkout
# is pinned to three distinct commits and trivy-action to four, every one of them
# R4-green. And NODE_VERSION / PYTHON_VERSION are declared per workflow file with
# no gate at all. This script checks identity against a declared value, which is
# a different assertion from "is it long enough".
#
# It is NOT a full R4 replacement. Its floating-reference check exists because
# viavitae-control has no compliance-check.yml and so no R4 coverage at all.
# When Tier 2 lands compliance-check.yml here, DELETE the I1 floating-ref block
# and keep I2/I3 — that is stated inline below, not left to memory.
#
# CONTRACT (house guard contract, same as check_audit_register.py):
#   0  every applicable invariant holds
#   1  at least one violation found
#   2  unable to execute / nothing checkable — an unchecked invariant must never
#      look identical to a satisfied one
#
# No secrets. No network. Therefore it can and must run BEFORE credential gates:
# a step after a failure is skipped, and a skipped check reads as a pass.
# #############################################################################
set -uo pipefail

MANIFEST="${1:-toolchain.yml}"
WF_DIR="${2:-.github/workflows}"
# Repo root is derived from the MANIFEST path, not from cwd. Without this, the
# .terraform-version check below silently reads whatever file happens to sit in
# the working directory and reports a false pass when the guard is pointed at
# another tree. Found by mutation test D4/D5, not by reading.
ROOT="$(dirname "$MANIFEST")"   # "." when the manifest is given as a bare filename

command -v awk >/dev/null 2>&1 || { echo "awk required" >&2; exit 2; }
[[ -r "$MANIFEST" ]] || { echo "::error::manifest '$MANIFEST' unreadable — nothing verified" >&2; exit 2; }
[[ -d "$WF_DIR" ]] || { echo "::error::workflows dir '$WF_DIR' absent — nothing verified" >&2; exit 2; }

manifest_value() { # $1 = key; prints the value, or nothing if the key is absent
  awk -v k="$1" 'BEGIN{FS=": *"} $1==k {
    v=$2; sub(/[[:space:]]+#.*$/,"",v); gsub(/"/,"",v);
    gsub(/^[[:space:]]+|[[:space:]]+$/,"",v); print v; exit
  }' "$MANIFEST"
}

violations=0
notices=0
checked=0

# Count of `uses:` lines that actually carry a reference, so a workflows
# directory full of comments cannot masquerade as a clean run.
total_refs=$(grep -rhoE 'uses:[[:space:]]*[^[:space:]]+' "$WF_DIR" 2>/dev/null | wc -l | tr -d ' ')
if [[ "$total_refs" == "0" ]]; then
  echo "::error::no action references found under $WF_DIR — nothing was checked" >&2
  exit 2
fi

echo "== toolchain manifest: $MANIFEST"
echo "== workflows: $WF_DIR ($total_refs reference(s) found)"
echo

# --- I1: every action reference is pinned ----------------------------------
# NOTE: overlaps rule R4 by design while viavitae-control has no
# compliance-check.yml. Delete this block when Tier 2 lands that workflow.
echo "-- I1 references must be 40-char SHAs"
while IFS=: read -r file lineno content; do
  ref=$(printf '%s' "$content" | sed -E 's/^[[:space:]]*-?[[:space:]]*uses:[[:space:]]*//; s/[[:space:]]*#.*$//; s/[[:space:]]*$//')
  case "$ref" in ./*|docker://*) continue ;; esac
  checked=$((checked + 1))
  if [[ ! "$ref" =~ @[0-9a-f]{40}$ ]]; then
    echo "::error file=${file},line=${lineno}::floating action reference '${ref}' — must be pinned to a 40-char commit"
    violations=$((violations + 1))
  fi
done < <(grep -rnE 'uses:[[:space:]]*[^[:space:]]+' "$WF_DIR" 2>/dev/null)
echo

# --- I2: every pinned reference matches the manifest's canonical commit ------
echo "-- I2 pinned references must match the canonical commit in the manifest"
while IFS= read -r ref; do
  name="${ref%@*}"
  sha="${ref##*@}"
  [[ "$sha" =~ ^[0-9a-f]{40}$ ]] || continue
  canon="$(manifest_value "pin.$name")"
  if [[ -z "$canon" ]]; then
    echo "   notice: '$name' is pinned but not declared in $MANIFEST — not verified"
    notices=$((notices + 1))
    continue
  fi
  checked=$((checked + 1))
  if [[ "$canon" == "any" ]]; then
    echo "   ok: '$name' pinned; manifest declares 'any' (canonical commit unverified — see manifest comment)"
    continue
  fi
  if [[ "$sha" != "$canon" ]]; then
    echo "::error::'$name' is pinned to ${sha:0:12} but $MANIFEST declares ${canon:0:12} — same action, different commit across the estate"
    violations=$((violations + 1))
  fi
done < <(grep -rhoE 'uses:[[:space:]]*[^[:space:]]+' "$WF_DIR" 2>/dev/null \
          | sed -E 's/^uses:[[:space:]]*//; s/[[:space:]]*#.*$//' | sort -u)
echo

# --- I3: declared tool versions in workflows match the manifest --------------
# Deliberately uppercase-only. The lowercase `terraform_version:` input to
# hashicorp/setup-terraform is set to a steps expression by Task 4, so there is
# no literal left to reconcile; the installed-versus-declared loop is closed by
# I4 plus the existing `Assert toolchain pin` step. Do not add a lowercase rule.
echo "-- I3 declared tool versions must match the manifest"
for pair in "NODE_VERSION:tool.node" "PYTHON_VERSION:tool.python" "TERRAFORM_VERSION:tool.terraform"; do
  var="${pair%%:*}"; key="${pair##*:}"
  want="$(manifest_value "$key")"
  [[ -z "$want" ]] && continue
  while IFS=: read -r file lineno content; do
    got=$(printf '%s' "$content" | sed -E "s/^[[:space:]]*${var}:[[:space:]]*//; s/[[:space:]]*(#.*)?$//; s/\"//g")
    case "$got" in *'${{ '*) continue ;; esac   # expression, not a literal declaration
    [[ -z "$got" ]] && continue
    checked=$((checked + 1))
    if [[ "$got" != "$want" ]]; then
      echo "::error file=${file},line=${lineno}::${var} is '${got}' but $MANIFEST declares '${want}'"
      violations=$((violations + 1))
    fi
  done < <(grep -rnE "^[[:space:]]*${var}:" "$WF_DIR" 2>/dev/null)
done
echo

# --- I4: the Terraform pin file matches the manifest ------------------------
echo "-- I4 .terraform-version must match the manifest"
want_tf="$(manifest_value tool.terraform)"
if [[ -n "$want_tf" ]]; then
  if [[ -r "$ROOT/.terraform-version" ]]; then
    got_tf=$(tr -d '[:space:]' < "$ROOT/.terraform-version")
    checked=$((checked + 1))
    if [[ "$got_tf" != "$want_tf" ]]; then
      echo "::error::$ROOT/.terraform-version is '$got_tf' but $MANIFEST declares '$want_tf'"
      violations=$((violations + 1))
    fi
  else
    echo "::error::$ROOT/.terraform-version is absent but the manifest declares tool.terraform — cannot verify"
    violations=$((violations + 1))
  fi
fi
echo

# --- verdict ----------------------------------------------------------------
echo "== assertions evaluated: $checked · undeclared-action notices: $notices · violations: $violations"
if [[ "$checked" == "0" ]]; then
  echo "::error::nothing was checkable — every invariant found no subject. This is NOT a pass." >&2
  exit 2
fi
if [[ "$violations" -ne 0 ]]; then
  echo "TOOLCHAIN PIN CHECK FAILED: $violations violation(s)." >&2
  exit 1
fi
echo "OK: every declared tool version and canonical pin matches $MANIFEST."
exit 0
