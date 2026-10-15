#!/usr/bin/env python3
"""Give a repository's CodeQL workflow a language matrix that is detected, not asserted.

Why: the landing repositories carry a hard-coded `matrix.language:
["python", "javascript-typescript"]` while containing no JavaScript or TypeScript at
all. CodeQL then fails the `Analyze (javascript-typescript)` leg on every push, pull
request and weekly scan (tracked as P1-19). A required check that can never pass is
worse than no check, and a permanently red leg trains people to ignore the dashboard.

The shape copied here already exists in viavitae-template: a `detect` job lists the
languages actually present, `analyze` builds its matrix from that output with
fromJson(), and a repository with no scannable source completes as a no-op instead of
failing. Detection is preferred over deleting the language from the list, because
deleting it silently loses coverage the day someone adds a script.

Safety rules enforced before anything is written:
  * the patched file must still parse as YAML;
  * no hard-coded `language: [...]` literal may survive;
  * the workflow-level CODEQL_LANGUAGES env is only removed when nothing in the
    repository's workflows reads it, so this script cannot orphan another job;
  * running it twice changes nothing (idempotent).

Usage: patch_codeql_detect.py <repo-dir> [--write]
"""
import re
import sys
from pathlib import Path

try:
    import yaml
except ImportError:  # refactoring tooling is not optional here
    sys.exit("PyYAML is required: pip install pyyaml")

CHECKOUT_PIN = "actions/checkout@11d5960a326750d5838078e36cf38b85af677262"

DETECT_JOB = """  detect:
    name: Detect languages
    runs-on: ubuntu-latest
    timeout-minutes: 5
    outputs:
      languages: ${{ steps.detect.outputs.languages }}
    steps:
      - name: Check out repository
        uses: %s
      - name: Detect present languages
        id: detect
        run: |
          set -euo pipefail
          langs=()
          if find . -type f \\( -name '*.py' -o -name '*.pyi' \\) \\
             -not -path './.venv/*' -not -path './.github/*' -print -quit | grep -q .; then
            langs+=("python")
            echo "Python files found"
          else
            echo "No Python files"
          fi
          if find . -type f \\( -name '*.js' -o -name '*.jsx' -o -name '*.ts' -o -name '*.tsx' \\) \\
             -not -path './node_modules/*' -not -path './.github/*' -print -quit | grep -q .; then
            langs+=("javascript-typescript")
            echo "JavaScript/TypeScript files found"
          else
            echo "No JavaScript/TypeScript files"
          fi
          if [ ${#langs[@]} -eq 0 ]; then
            echo "No scannable source files — CodeQL will complete with a no-op."
            langs=("none")
          fi
          printf 'languages=%%s\\n' "$(jq -cn --args '$ARGS.positional' "${langs[@]}")" >> "$GITHUB_OUTPUT"

""" % CHECKOUT_PIN

OLD_HEADER = """# CodeQL static application security testing for Python and TypeScript/JavaScript,
# the two languages present across ViaVitae repositories."""

NEW_HEADER = """# CodeQL static application security testing. The languages analysed are detected
# from the files present in the repository (see the `detect` job), so a repository
# never fails a scan for a language it does not contain, and adding a language needs
# no edit to this file."""

OLD_ENV = """env:
  # Language matrix. Add a language here and the rest of the pipeline follows.
  # Supported: python, javascript-typescript, go, java-kotlin, csharp, ruby,
  # swift, cpp, actions.
  CODEQL_LANGUAGES: "python,javascript-typescript"

"""

ANALYZE_HEAD = "jobs:\n  analyze:\n    name: Analyze (${{ matrix.language }})\n"
ANALYZE_HEAD_NEW = (
    "jobs:\n" + DETECT_JOB + "  analyze:\n"
    "    name: Analyze (${{ matrix.language }})\n"
    "    needs: detect\n"
    "    if: needs.detect.outputs.languages != '[\"none\"]'\n"
)


def env_is_unused(root: Path, text: str) -> bool:
    """True when no workflow in this repo reads the workflow-level env key."""
    if "env.CODEQL_LANGUAGES" in text:
        return False
    for f in (root / ".github" / "workflows").glob("*.yml"):
        if f.name != "codeql.yml" and "CODEQL_LANGUAGES" in f.read_text():
            return False
    return True


def patch(root: Path):
    """Return (new_text, notes). Raises ValueError when the file is not recognised."""
    wf = root / ".github" / "workflows" / "codeql.yml"
    if not wf.is_file():
        raise ValueError("no .github/workflows/codeql.yml")
    text = original = wf.read_text()
    notes = []

    if "needs.detect.outputs.languages" in text:
        return original, ["already detected (no change)"]

    if ANALYZE_HEAD not in text:
        raise ValueError("unexpected `jobs:`/`analyze:` header; refusing to guess")

    text = text.replace(ANALYZE_HEAD, ANALYZE_HEAD_NEW, 1)
    notes.append("added detect job + needs/if on analyze")

    # language: ["python", "javascript-typescript"]  (any literal list) -> detected
    literal = re.search(r"^\s*language:\s*\[[^\]]*\]\s*$", text, re.M)
    if not literal:
        raise ValueError("no hard-coded `language: [...]` matrix found")
    text = text[: literal.start()] + "        language: ${{ fromJson(needs.detect.outputs.languages) }}" + text[literal.end():]
    notes.append("matrix built from detect output")

    if OLD_HEADER in text:
        text = text.replace(OLD_HEADER, NEW_HEADER, 1)
        notes.append("corrected the language claim in the header comment")

    if OLD_ENV in text:
        if env_is_unused(root, text):
            text = text.replace(OLD_ENV, "", 1)
            notes.append("removed dead CODEQL_LANGUAGES env")
        else:
            notes.append("CODEQL_LANGUAGES still referenced elsewhere - left in place")

    return text, notes


def main(argv):
    root = Path(argv[1]) if len(argv) > 1 and not argv[1].startswith("-") else Path(".")
    write = "--write" in argv
    try:
        new_text, notes = patch(root)
    except ValueError as exc:
        print(f"  {root.name}: REFUSED - {exc}")
        return 1

    # A patched workflow that does not parse must never leave this machine.
    try:
        doc = yaml.safe_load(new_text)
    except yaml.YAMLError as exc:
        print(f"  {root.name}: REFUSED - patched YAML does not parse: {exc}")
        return 1

    jobs = doc.get("jobs", {})
    if "detect" not in jobs or "needs" not in jobs.get("analyze", {}):
        print("  REFUSED - patched document lacks the detect job or its dependency")
        return 1
    if re.search(r"^\s*language:\s*\[[^\]]{2,}\]\s*$", new_text, re.M):
        print("  REFUSED - a hard-coded language literal survived")
        return 1

    print(f"  {root.name}: " + "; ".join(notes))
    if write:
        (root / ".github" / "workflows" / "codeql.yml").write_text(new_text)
        print(f"  {root.name}: written")
    else:
        print(f"  {root.name}: dry-run (pass --write)")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
