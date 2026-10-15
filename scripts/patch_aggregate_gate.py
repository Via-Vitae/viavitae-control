#!/usr/bin/env python3
"""Patch a fragile aggregate CI gate: verdict from the needs context, not from
grepping toJSON(needs) text.

The pattern in this org was:

    results='${{ toJSON(needs) }}'
    failed=$(printf '%s' "$results" | grep -o '"result":"failure"' | wc -l || true)

The JSON that runner expands is not guaranteed to be the compact form
{"result":"failure"}; if it carries a space after the colon, every grep matches
zero times and the aggregate job reports success over failing gates. Observed on
Via-Vitae/viavitae-web PR #32: Lint and Unit + contract tests both completed
`failure` at 17:54, and CI status completed `success` at 17:55:03.

The replacement evaluates the expression itself and hands the boolean to the shell
through env, so no text serialization detail can flip the verdict. `skipped` is
still deliberately not a failure: matrix stacks legitimately skip jobs.

Usage:
    ./scripts/patch_aggregate_gate.py <repo-dir> <workflow-path> [--check]
"""
from __future__ import annotations

import argparse
import pathlib
import re
import sys

OLD_RE = re.compile(
    r"( *)- name: Evaluate required gates\n"
    r"\1  id: eval\n"
    r"\1  run: \|\n"
    r"\1    set -euo pipefail\n"
    r".*?"
    r"\1    echo \"(All (?:required|compliance) gates passed[^\"]*|All compliance gates passed\.|All required gates passed[^\"]*)\"\n",
    re.S,
)

OLD_RE_NOID = re.compile(
    r"( *)- name: Evaluate required gates\n"
    r"\1  run: \|\n"
    r"\1    set -euo pipefail\n"
    r".*?"
    r"\1    echo \"[^\"]*gates passed[^\"]*\"\n",
    re.S,
)


def build(indent: str, label: str, with_output: bool) -> str:
    i = indent
    lines = [
        f"{i}- name: Evaluate required gates",
    ]
    if with_output:
        lines.append(f"{i}  id: eval")
    lines += [
        f"{i}  run: |",
        f"{i}    set -euo pipefail",
        f"{i}    # The verdict is computed by the expression engine from the needs",
        f"{i}    # context, then passed in as an env var. Do NOT grep toJSON(needs):",
        f"{i}    # if the serialised JSON carries a space after the colon the pattern",
        f"{i}    # matches nothing and this gate passes over failing jobs (seen on",
        f"{i}    # viavitae-web PR #32: Lint + Unit failed, CI status reported success).",
        f"{i}    printf '%s\\n' '${{{{ toJSON(needs) }}}}'",
    ]
    if with_output:
        lines += [
            f"{i}    if [[ \"${{{{ env.GATE_BAD }}}}\" == \"true\" ]]; then",
            f'{i}      echo "result=fail" >> "$GITHUB_OUTPUT"',
            f'{i}      echo "::error::A required {label} gate failed or was cancelled."',
            f"{i}      exit 1",
            f"{i}    fi",
            f'{i}    echo "result=pass" >> "$GITHUB_OUTPUT"',
            f'{i}    echo "All {label} gates passed or were legitimately skipped."',
            f"{i}  env:",
            f"{i}    GATE_BAD: ${{{{ contains(needs.*.result, 'failure') || contains(needs.*.result, 'cancelled') }}}}",
        ]
    else:
        lines += [
            f"{i}    if [[ \"${{{{ env.GATE_BAD }}}}\" == \"true\" ]]; then",
            f'{i}      echo "::error::A required {label} gate failed or was cancelled."',
            f"{i}      exit 1",
            f"{i}    fi",
            f'{i}    echo "All {label} gates passed or were legitimately skipped."',
            f"{i}  env:",
            f"{i}    GATE_BAD: ${{{{ contains(needs.*.result, 'failure') || contains(needs.*.result, 'cancelled') }}}}",
        ]
    return "\n".join(lines) + "\n"


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("repo_dir", type=pathlib.Path)
    ap.add_argument("workflow", type=str)
    ap.add_argument("--check", action="store_true", help="only report whether it is patchable")
    args = ap.parse_args()

    path = args.repo_dir / args.workflow
    if not path.is_file():
        print(f"not found: {path}", file=sys.stderr)
        return 2
    text = path.read_text()

    label = "compliance" if "Compliance status" in text else "CI"
    matched = OLD_RE.search(text)
    with_output = True
    if not matched:
        matched = OLD_RE_NOID.search(text)
        with_output = False
    if not matched:
        if re.search(r"contains\(needs\.\*\.result", text):
            print(f"  {args.workflow}: already expression-based")
            return 0
        print(f"  {args.workflow}: PATTERN NOT FOUND (manual review needed)", file=sys.stderr)
        return 3

    if args.check:
        print(f"  {args.workflow}: fragile JSON-grep gate found -> patchable (label={label}, outputs={with_output})")
        return 0

    indent = matched.group(1)
    replacement = build(indent, label, with_output)
    patched = text[: matched.start()] + replacement + text[matched.end():]
    path.write_text(patched)
    print(f"  {args.workflow}: patched ({label}, outputs={with_output})")
    return 0


if __name__ == "__main__":
    sys.exit(main())
