#!/usr/bin/env python3
"""Repair an aggregate CI gate that decides its verdict by grepping JSON TEXT.

The generated pattern in this org is:

    results='${{ toJSON(needs) }}'
    failed=$(printf '%s' "$results" | grep -o '"result":"failure"' | wc -l || true)
    if [ "$failed" -ne 0 ] || ...; then exit 1; fi

`toJSON(needs)` is not guaranteed to serialise compactly. If it carries a space
after the colon, the grep matches nothing, the count is 0 and the aggregate job
reports SUCCESS while jobs it depends on failed. Observed on viavitae-web PR #32:
`Lint` and `Unit + contract tests` completed `failure`, `CI status` completed
`success` 66 seconds later.

The fix computes the verdict in the Actions expression layer, where no
serialisation detail can change the answer:

    env:
      GATE_BAD: ${{ contains(needs.*.result, 'failure') || contains(needs.*.result, 'cancelled') }}

`skipped` is deliberately NOT a failure: matrix legs that do not apply to a repo
are skipped, and treating that as a failure would freeze unrelated changes.

The step is matched by CONTENT, not by name: aggregate steps in this org appear
as `Evaluate required gates` (ci.yml, compliance-check.yml) and
`Evaluate CodeQL gates` (codeql.yml) with different job names, and a name-anchored
patch silently skips the ones it was supposed to fix.

Read-only by default: --check reports, --dry-run prints the patch, only --write
modifies the file. This tool never touches git; the caller opens the PR.

Usage:
    patch_aggregate_gate.py <repo-dir> <workflow-path> [--check|--dry-run|--write]
Exit: 0 = handled/no-op, 3 = pattern present but not understood (human needed).
"""
from __future__ import annotations

import argparse
import pathlib
import re
import sys

import yaml

FRAGILE = re.compile(r"""grep -o ['"]"result":"(failure|cancelled)"['"]""")
STEP_START = re.compile(r"^(\s*)- name:\s*(.+?)\s*$")


def step_bounds(lines: list[str], hit: int) -> tuple[int, int, int]:
    """Return (start, end, indent) of the step containing line index `hit`.

    end is exclusive and stops before the next sibling step or a dedented key.
    """
    start = hit
    while start > 0:
        m = STEP_START.match(lines[start])
        if m:
            break
        start -= 1
    m = STEP_START.match(lines[start])
    if not m:
        raise ValueError("no enclosing `- name:` step found")
    indent = len(m.group(1))
    end = len(lines)
    for i in range(hit + 1, len(lines)):
        line = lines[i]
        if not line.strip():
            continue
        cur = len(line) - len(line.lstrip())
        if cur <= indent and (STEP_START.match(line) or not line.lstrip().startswith("-")):
            end = i
            break
    return start, end, indent


def rebuild(block: list[str], indent: int) -> tuple[list[str], dict]:
    """Return the canonical step block plus the metadata preserved from the original."""
    name = "Evaluate required gates"
    step_id = None
    runs_output = False
    label = "CI"
    for line in block:
        m = STEP_START.match(line)
        if m:
            name = m.group(2)
        s = line.strip()
        if s.startswith("id:"):
            step_id = s.split("id:", 1)[1].strip()
        if "GITHUB_OUTPUT" in s and "result=" in s:
            runs_output = True
        for cand, words in (("CodeQL", ("CodeQL", "codeql")),
                            ("compliance", ("compliance", "Compliance")),
                            ("CI", ("required gates", "CI status"))):
            if any(w in line for w in words):
                label = label if label != "CI" and cand == "CI" else cand
                break
    i = " " * indent
    j = " " * (indent + 2)
    k = " " * (indent + 4)
    out = [f"{i}- name: {name}"]
    if step_id:
        out.append(f"{j}id: {step_id}")
    out.append(f"{j}run: |")
    out.append(f"{k}set -euo pipefail")
    out.append(f"{k}# The verdict is computed by the Actions expression engine from the")
    out.append(f"{k}# needs context and passed in as GATE_BAD. Never decide a gate by")
    out.append(f"{k}# grepping toJSON(needs): the serialisation is not contractual, and a")
    out.append(f"{k}# space after the colon makes the old matcher count 0 failures and")
    out.append(f"{k}# report success over failed jobs (viavitae-web PR #32).")
    out.append(f"{k}results='${{{{ toJSON(needs) }}}}'")
    out.append(f"""{k}printf '%s' "$results" | grep -o '"[a-z-]*":\\{{"result":"[a-z]*"' || true""")
    if runs_output:
        out.append(f'{k}if [[ "${{{{ env.GATE_BAD }}}}" == "true" ]]; then')
        out.append(f'{k}  echo "result=fail" >> "$GITHUB_OUTPUT"')
        out.append(f'{k}  echo "::error::A required {label} gate failed or was cancelled."')
        out.append(f"{k}  exit 1")
        out.append(f"{k}fi")
        out.append(f'{k}echo "result=pass" >> "$GITHUB_OUTPUT"')
        out.append(f'{k}echo "All {label} gates passed or were legitimately skipped."')
    else:
        out.append(f'{k}if [[ "${{{{ env.GATE_BAD }}}}" == "true" ]]; then')
        out.append(f'{k}  echo "::error::A required {label} gate failed or was cancelled."')
        out.append(f"{k}  exit 1")
        out.append(f"{k}fi")
        out.append(f'{k}echo "All {label} gates passed or were legitimately skipped."')
    out.append(f"{j}env:")
    out.append(f"{k}GATE_BAD: ${{{{ contains(needs.*.result, 'failure') || contains(needs.*.result, 'cancelled') }}}}")
    return out, {"name": name, "id": step_id, "label": label, "outputs": runs_output}


def process(path: pathlib.Path, write: bool) -> int:
    text = path.read_text()
    lines = text.splitlines()
    hits = [i for i, l in enumerate(lines) if FRAGILE.search(l)]
    if not hits:
        if re.search(r"contains\(needs\.\*\.result", text):
            print(f"  {path.name}: already expression-based")
            return 0
        print(f"  {path.name}: no aggregate matcher found (nothing to do)")
        return 0

    done: list[dict] = []
    # Rebuild from the last step backwards so earlier splices keep their indices.
    for hit in sorted({step_bounds(lines, h)[0] for h in hits}, reverse=True):
        start, end, indent = step_bounds(lines, hit)
        new_block, meta = rebuild(lines[start:end], indent)
        lines[start:end] = new_block
        done.append(meta)

    new_text = "\n".join(lines) + ("\n" if text.endswith("\n") else "")

    # Never ship a patch that does not parse, or that loses a step other blocks
    # depend on via needs.<job>.outputs.<step_id>.
    try:
        parsed = yaml.safe_load(new_text)
        assert isinstance(parsed.get("jobs"), dict) and parsed["jobs"]
    except Exception as exc:  # noqa: BLE001
        print(f"  {path.name}: REFUSED - patched YAML does not parse: {exc}", file=sys.stderr)
        return 3

    ids = {m["id"] for m in done if m["id"]}
    outs = {m["id"] for m in done if m["id"] and m["outputs"]}
    if outs != ids:
        print(f"  {path.name}: REFUSED - step id/output bookkeeping unclear", file=sys.stderr)
        return 3

    label = ", ".join(f"{m['name']}(id={m['id'] or '-'},out={m['outputs']})" for m in done)
    if FRAGILE.search(new_text):
        print(f"  {path.name}: REFUSED - fragile matcher still present after patch", file=sys.stderr)
        return 3
    if write:
        path.write_text(new_text)
        print(f"  {path.name}: patched [{label}]")
    else:
        print(f"  {path.name}: patchable [{label}]")
    return 0


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("repo_dir", type=pathlib.Path)
    ap.add_argument("workflow", nargs="?", type=str)
    ap.add_argument("--check", action="store_true")
    ap.add_argument("--dry-run", action="store_true")
    ap.add_argument("--write", action="store_true")
    args = ap.parse_args()

    targets: list[pathlib.Path] = []
    if args.workflow:
        targets = [args.repo_dir / args.workflow]
    else:
        targets = sorted((args.repo_dir / ".github" / "workflows").glob("*.yml"))

    rc = 0
    for t in targets:
        if not t.is_file():
            print(f"  {t}: not found", file=sys.stderr)
            rc = 2
            continue
        rc = max(rc, process(t, write=args.write))
    return rc


if __name__ == "__main__":
    sys.exit(main())
