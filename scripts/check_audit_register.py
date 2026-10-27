#!/usr/bin/env python3
# #############################################################################
# check_audit_register.py — fail when the audit register contradicts its own structure.
#
# WHY. The register is a compliance artifact that asserts counts and identifiers about
# itself ("24 findings in §23", "E1–E46", "three PART headings"). Every one of those is
# machine-checkable, and in one session four separate edits broke them silently: a
# literal `|` inside an inline-code span tore a markdown table row in two, a replacement
# anchored on a heading swallowed the following entry, a numbered evidence item lost its
# heading, and a row gained a sixth cell in a five-column table. Each time the defect was
# found by a throwaway script that then disappeared. A guard that exists permanently and
# is re-run on every edit is the fix for a class of defect that recurred.
#
# CONTRACT (three-way on purpose, matching scripts/check_plan_selfcite.sh):
#   0  every applicable invariant recomputed from the file holds
#   1  at least one invariant is violated
#   2  usage or environment error, or a file where nothing was checkable — because
#      "nothing was checked" must never be reported as a pass
#
# Invariants:
#   I1 table column consistency   every data row matches its header's pipe count
#   I7 inline-code pipe hint      a `|` inside `code` is quoted with the offending line,
#                                 since that is the most common cause of an I1 failure
#   I2 finding sets match          §23 register ids == §25 verification ids, no duplicates
#   I3 evidence contiguity         **E1** .. **En** present with no gap
#   I4 part headings               exactly `# PART I`, `II`, `III`
#   I5 no dangling section refs    every `§N` names a heading that exists in the file
#   I6 front matter                leading `---` block carries a non-empty revisions list
#   I8 prose row counts            "<n> findings" near a §23 mention must equal §23's rows
#
# Register-only invariants (I2, I3, I4, I8) run only when the file looks like the
# register; for a spec they are reported as N/A rather than as failures. I5 is fatal for
# the register and advisory for other documents, whose `§` references may legitimately
# point into the register.
#
# FALSE POSITIVES FOUND BY TESTING THIS SCRIPT (each fixed here, kept as a warning):
#   * the header row of a table was reported as "row outside a recognised table", because
#     the pipe count is only known from the `|---|` separator that follows it — 11 of the
#     register's tables lit up on a clean file;
#   * `FINDING_ID` was compiled without MULTILINE, so `^|` matched only the very first
#     line of the string and I2 found zero findings in a register holding 25;
#   * register-only invariants were applied to a spec, failing it for having no §23 and no
#     evidence index, which a spec legitimately lacks.
# Sensitivity was then proved by mutation: adding a pipe inside an inline-code span,
# renaming an evidence marker, deleting a §25 row and demoting a PART heading each raise
# the failure count by exactly one, and the clean files exit 0.
#
# LIMITATIONS, stated rather than hidden:
#   * This detects structural rot. It cannot tell whether a finding's content is true, nor
#     whether a number quoted in prose matches a measurement taken in another repository.
#   * I2 compares identifier sets; a row can be structurally valid and semantically stale.
#   * A table whose separator row is missing entirely is treated as prose, not as a table.
#
# Usage:  ./scripts/check_audit_register.py docs/security/pre-deployment-independent-audit-2026-10-26.md \
#             docs/superpowers/specs/*.md
# #############################################################################
import re
import sys
from pathlib import Path

FINDING_ID = re.compile(r"^\| (VV-[0-9]{4}-[0-9]{2}-[0-9]{3}) \|", re.M)
SEP_ROW = re.compile(r"\|(\s*:?-{3,}:?\s*\|)+")


def die(msg):
    print(f"ENV/USAGE: {msg}", file=sys.stderr)
    raise SystemExit(2)


def is_table_row(s):
    return s.startswith("|") and s.endswith("|") and len(s) > 1


def front_matter(text):
    if not text.startswith("---"):
        return None, "no leading --- block"
    block = text.split("---", 2)[1]
    if not re.search(r"(?m)^revisions:", block):
        return None, "no revisions: key (spec-style header is allowed)"
    entries = re.findall(r'(?m)^  - "', block)
    if not entries:
        return None, "revisions: present but empty"
    return len(entries), None


def check_tables(text):
    """I1 + I7. A header row is a pipe row followed by a |---| separator."""
    lines = [l.strip() for l in text.splitlines()]
    defects = []
    tables = 0
    hdr = None
    hdr_line = 0
    for i, s in enumerate(lines):
        if not is_table_row(s):
            hdr = None
            continue
        cols = s.count("|") - 1
        nxt = lines[i + 1] if i + 1 < len(lines) else ""
        if SEP_ROW.fullmatch(nxt or "") and not SEP_ROW.fullmatch(s):
            hdr, hdr_line, tables = cols, i + 1, tables + 1
            continue
        if SEP_ROW.fullmatch(s):
            continue
        if hdr is None:
            defects.append((i + 1, "data row with no header above it"))
            continue
        if cols != hdr:
            code = re.findall(r"`[^`]*\|[^`]*`", s)
            hint = f" — inline code containing a pipe: {code[0][:60]}" if code else ""
            defects.append((i + 1, f"{cols} cells but header (line {hdr_line}) has {hdr}{hint}"))
    return defects, tables


def section_headings(text):
    """Section numbers from any heading style: `## 23.` or `# 9.` or `### 3.`."""
    return {int(m) for m in re.findall(r"(?m)^#{1,3} (\d+)\.", text)}


def main():
    files = [a for a in sys.argv[1:] if not a.startswith("-")]
    if not files:
        die("usage: check_audit_register.py <file.md> [...]")
    total = 0
    checked_tables = 0
    for name in files:
        p = Path(name)
        if not p.is_file():
            die(f"not readable: {name}")
        text = p.read_text()
        is_register = bool(re.search(r"(?m)^## 23\.", text)) and \
            bool(re.search(r"\*\*E1\*\*", text))
        print(f"== {name}  [{'register' if is_register else 'other document'}]")
        local = 0

        defects, tables = check_tables(text)
        for line, why in defects:
            print(f"   FAIL I1 line {line}: {why}")
        local += len(defects)
        if tables and not defects:
            print(f"   ok   I1/I7 tables: {tables} table(s), column counts consistent")
        elif tables:
            print(f"   (I1: {tables} table(s) scanned)")
        elif is_register:
            print("   FAIL I1: the register has no table at all — nothing was verified")
            local += 1
        else:
            print("   note I1: no table in this file; column-consistency not applicable "
                  "(a spec may legitimately be prose-only)")
        checked_tables += tables

        if is_register:
            def ids(sec):
                m = re.search(rf"(?m)^## {sec}\..*?(?=^## |\Z)", text, re.S)
                return FINDING_ID.findall(m.group(0)) if m else []
            a, b = ids("23"), ids("25")
            if not a or not b:
                print(f"   FAIL I2: §23 has {len(a)} rows, §25 has {len(b)} — both required")
                local += 1
            else:
                dup = [x for x in set(a + b) if (a + b).count(x) > 2 or a.count(x) > 1 or b.count(x) > 1]
                only23, only25 = set(a) - set(b), set(b) - set(a)
                if dup or only23 or only25:
                    print(f"   FAIL I2: duplicates={sorted(dup)} only-in-23={sorted(only23)} "
                          f"only-in-25={sorted(only25)}")
                    local += 1
                else:
                    print(f"   ok   I2 findings: {len(set(a))} ids, §23 and §25 agree, no duplicates")

            ev = sorted({int(x) for x in re.findall(r"\*\*E(\d+)\*\*", text)})
            gaps = [n for n in range(1, ev[-1] + 1) if n not in ev] if ev else []
            if not ev:
                print("   FAIL I3: no **E<n>** markers found in a register")
                local += 1
            elif gaps:
                print(f"   FAIL I3: evidence gaps at {gaps} (max E{ev[-1]})")
                local += 1
            else:
                print(f"   ok   I3 evidence: E1–E{ev[-1]} contiguous")

            parts = re.findall(r"(?m)^# PART ([IVX]+) —", text)
            if parts != ["I", "II", "III"]:
                print(f"   FAIL I4: PART headings are {parts}, expected ['I', 'II', 'III']")
                local += 1
            else:
                print("   ok   I4 part headings: I, II, III")

            for ln, line in enumerate(text.splitlines(), 1):
                m = re.search(r"(\d+)\s+findings?.{0,60}(§ ?23|section 23)", line, re.I)
                if m:
                    claim, got = int(m.group(1)), len(set(a)) if a else -1
                    if claim != got:
                        print(f"   FAIL I8 line {ln}: prose claims {claim} findings, §23 has {got}")
                        local += 1
                    else:
                        print(f"   ok   I8 line {ln}: {claim} findings matches §23")

        refs = {int(m) for m in re.findall(r"§(\d+)", text)}
        missing = sorted(refs - section_headings(text))
        if missing and is_register:
            print(f"   FAIL I5: references to sections that do not exist: {missing}")
            local += 1
        elif missing:
            print(f"   note I5 (advisory): {len(missing)} §-refs not defined in this file "
                  f"{missing[:8]}{' …' if len(missing) > 8 else ''} — allowed outside the register")
        else:
            print(f"   ok   I5 references: {len(refs)} section refs, none dangling")

        n, err = front_matter(text)
        print(f"   {'ok   I6' if n else 'note I6'}: "
              f"{n if n else 'front matter not applicable'}"
              + (f" revision entries" if n else f" ({err})"))

        total += local
        if local:
            print(f"   -> {local} failure(s) in {name}")

    if checked_tables == 0:
        die("no table was found in any supplied file — nothing was checked, which is not a pass")
    if total:
        print(f"\nREGISTER INTEGRITY FAILED: {total} structural violation(s).", file=sys.stderr)
        print("Fix the document, not this check. A compliance artifact that contradicts its",
              file=sys.stderr)
        print("own numbering is worse than one that is simply incomplete.", file=sys.stderr)
        raise SystemExit(1)
    print("\nOK: every applicable structural invariant recomputed from the files holds.")


if __name__ == "__main__":
    main()
