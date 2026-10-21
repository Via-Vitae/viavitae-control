#!/usr/bin/env bash
# vault.sh — age-backed secret store that reuses the existing state-backup identity.
#
# One root of trust: the recipient is derived from ~/.config/age/state-backup-key.txt
# (the same key already protected by BACKUP-A/B and the break-glass envelopes), so the
# vault adds no new key material to guard. Ciphertext lives under ~/.vault, is
# versioned by a LOCAL-ONLY git repo (no remote), and every file is mode 600 (umask 077).
#
# This supersedes `pass` + ~/.password-store, which was never `pass init`'d and whose
# only GPG key is signing-only ([SC], no encryption subkey) and therefore cannot encrypt.
#
# USAGE
#   scripts/vault.sh put <entity>/<category>/<name>   # read secret from stdin, encrypt
#   scripts/vault.sh get <entity>/<category>/<name>   # decrypt to stdout (never logs)
#   scripts/vault.sh list [prefix]                    # show stored names (no values)
#   scripts/vault.sh rm   <entity>/<category>/<name>  # delete + commit
#   scripts/vault.sh cp   <entity>/<category>/<name>  # decrypt to clipboard (45s clear) if xclip
#
# EXIT  0 ok · 1 usage/not-found · 2 backend missing (no age, no key, or key unreadable)
set -euo pipefail

VAULT_DIR="${VAULT_DIR:-$HOME/.vault}"
KEY="${VAULT_KEY:-$HOME/.config/age/state-backup-key.txt}"

command -v age >/dev/null 2>&1 || { echo "age not installed" >&2; exit 2; }
[ -r "$KEY" ] || { echo "age identity not readable: $KEY" >&2; exit 2; }
umask 077
mkdir -p "$VAULT_DIR"
git -C "$VAULT_DIR" rev-parse -q --is-inside-work-tree >/dev/null 2>&1 || git -C "$VAULT_DIR" init -q
git -C "$VAULT_DIR" config user.name vault >/dev/null 2>&1 || true
RECIPIENT="$(age-keygen -y "$KEY")"

commit() { git -C "$VAULT_DIR" add -A && git -C "$VAULT_DIR" commit -qm "$1"; }

cmd="${1:-}"; shift || true
case "$cmd" in
  put)
    name="${1:?usage: vault put <path>}"; [[ "$name" == /* || "$name" == *..* ]] && { echo "bad path" >&2; exit 1; }
    mkdir -p "$VAULT_DIR/$(dirname "$name")"
    echo "Reading secret from stdin (multi-line ok). End with Ctrl-D." >&2
    age -r "$RECIPIENT" -o "$VAULT_DIR/$name.age"
    commit "vault: put $name"; echo "stored: $name" >&2 ;;
  get)
    name="${1:?usage: vault get <path>}"
    f="$VAULT_DIR/$name.age"; [ -r "$f" ] || { echo "not found: $name" >&2; exit 1; }
    age -d -i "$KEY" "$f" ;;
  list)
    pre="${1:-}"
    ( cd "$VAULT_DIR" && find . -name '*.age' -type f 2>/dev/null | sed 's|^\./||; s|\.age$||' | sort | { [ -n "$pre" ] && grep "^$pre" || cat; } ) ;;
  rm)
    name="${1:?usage: vault rm <path>}"; f="$VAULT_DIR/$name.age"; [ -e "$f" ] || { echo "not found: $name" >&2; exit 1; }
    rm -f "$f"; commit "vault: rm $name"; echo "removed: $name" >&2 ;;
  cp)
    name="${1:?usage: vault cp <path>}"; command -v xclip >/dev/null 2>&1 || { echo "xclip not installed" >&2; exit 2; }
    age -d -i "$KEY" "$VAULT_DIR/$name.age" | head -1 | xclip -selection clipboard
    echo "first line on clipboard (clears in 45s)" >&2 ;;
  *) echo "usage: vault.sh {put|get|list|rm|cp} <path>" >&2; exit 1 ;;
esac
