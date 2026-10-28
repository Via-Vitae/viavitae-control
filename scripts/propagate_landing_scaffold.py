"""propagate_landing_scaffold.py — option A plus the Dependabot trim, nine landing repos.

Replaces the one-repo pilot script, which is single-repo and ABORTS if either item is
already done (`assert py_text is not None`). That is fatal for a multi-repo sweep: a
partial run could not be resumed, because the pending item sat behind a completed one.
Here every (repo, item) pair is an independent state machine: DONE -> skip, EXPECTED ->
apply, ANYTHING ELSE -> abort that repo without writing it.

Safety order per item: read(branch) -> assert -> build payload -> validate payload ->
write -> re-read branch -> verify. Nothing is written before its own payload has been
parsed, and the run is dry by default. The trim is validated against a known-good oracle,
not only against its own assertions: its output for an untrimmed repo is byte-identical
(beyond the per-repo title comment) to the file already merged and green on
`viavitae-landing-basilica` main `6e9d18fd`.

Authority: writes to nine OTHER repositories via the contents API on the existing
`fix/ci-matrix-args` branches. That is the scoped-edit class the owner authorised for ONE
pilot repo, so this stays dry-run until the owner says apply. It never touches `main`,
never merges, and never opens a PR.

Usage:
  python3 scripts/propagate_landing_scaffold.py --selftest     # offline trim fixtures
  python3 scripts/propagate_landing_scaffold.py                # dry-run all nine
  python3 scripts/propagate_landing_scaffold.py --apply --repos viavitae-landing-diocese
"""
import argparse
import base64
import json
import re
import subprocess
import sys

import yaml

ORG = "Via-Vitae"
BR = "fix/ci-matrix-args"
DROP = ("pip", "npm", "terraform", "docker")
KEEP = "github-actions"
STUB_MARKERS = ("This is a sample Python script", "print_hi")
TRAILER = "ai:review"          # policies/AI_WORKFLOW_POLICY.md §3.11; CI gate binds on it


def gh(*args):
    r = subprocess.run(["gh", "api", *args], capture_output=True, text=True)
    if r.returncode != 0:
        return None, (r.stderr.strip() or r.stdout.strip())[:200]
    return r.stdout, None


def read_file(repo, path, ref):
    """Content AND blob sha from ONE response -- two reads would allow a write to land
    against a sha that has already moved on (409 at best, silent clobber at worst).

    Parsed as JSON, not as `@tsv`: that filter escapes the newlines GitHub embeds in the
    base64 payload as literal backslash-n, and the result decodes to garbage (observed:
    UnicodeDecodeError 0x9d at byte 45 on a 528-byte main.py).
    """
    out, err = gh(f"repos/{ORG}/{repo}/contents/{path}", "--method", "GET",
                  "-f", f"ref={ref}", "--jq", "{c:.content, s:.sha}")
    if out is None:
        return None, None, err
    try:
        obj = json.loads(out)
        text = base64.b64decode(str(obj["c"]).replace("\n", "")).decode()
    except Exception as exc:  # noqa: BLE001 - a corrupt read must abort, never guess
        return None, None, f"decode failed: {exc}"
    return text, str(obj["s"]), None


def put(repo, path, sha, text, message):
    out, err = gh(f"repos/{ORG}/{repo}/contents/{path}", "--method", "PUT",
                  "-f", f"sha={sha}", "-f", f"branch={BR}",
                  "-f", f"message={message}",
                  "-f", f"content={base64.b64encode(text.encode()).decode()}")
    return (err or out or "")[:200]


def delete(repo, path, sha, message):
    out, err = gh(f"repos/{ORG}/{repo}/contents/{path}", "--method", "DELETE",
                  "-f", f"sha={sha}", "-f", f"branch={BR}", "-f", f"message={message}")
    return (err or out or "")[:200]


def blob_paths(repo, ref):
    out, err = gh(f"repos/{ORG}/{repo}/git/trees/{ref}?recursive=1", "--jq",
                  '[.tree[] | select(.type=="blob") | .path] | join("\n")')
    if out is None:
        return None, err
    return [p for p in out.split("\n") if p.strip()], None


# --------------------------------------------------------------------- trim ---
def trim_dependabot(text):
    """Drop every ecosystem in DROP together with ITS OWN comment header.

    Returns (new_text, ecosystems_after). Raises AssertionError on any state that is not
    the expected five-entry superset -- an abort, never a partial guess.
    """
    lines = text.split("\n")
    starts = [i for i, l in enumerate(lines) if re.match(r"^  - package-ecosystem:", l)]
    before = [re.search(r'package-ecosystem:\s*"?([a-zA-Z_-]+)"?', lines[s]).group(1) for s in starts]
    assert sorted(before) == sorted(list(DROP) + [KEEP]), f"unexpected ecosystems {before}"

    units = []
    for s in starts:
        cstart = s
        while cstart - 1 >= 0 and lines[cstart - 1].startswith("  #"):
            cstart -= 1          # the header belongs to the entry above it
        units.append([cstart, None, lines[s]])
    for i in range(len(units) - 1):
        units[i][1] = units[i + 1][0]
    end = starts[-1] + 1
    while end < len(lines) and (not lines[end].strip() or lines[end].startswith("    ")):
        end += 1
    units[-1][1] = end

    drop = set()
    kept_unit = None
    for cstart, uend, entry_line in units:
        eco = re.search(r'package-ecosystem:\s*"?([a-zA-Z_-]+)"?', entry_line).group(1)
        if eco in DROP:
            drop.update(range(cstart, uend))
        else:
            assert eco == KEEP, f"unexpected kept ecosystem {eco}"
            kept_unit = (cstart, uend)

    new_text = "\n".join(l for i, l in enumerate(lines) if i not in drop)
    parsed = yaml.safe_load(new_text)
    after = [u["package-ecosystem"] for u in parsed["updates"]]
    # assertions on the RESULT, not on the intent
    assert after == [KEEP], after
    assert parsed["version"] == yaml.safe_load(text)["version"], "version key changed"
    assert len(parsed["updates"]) == 1
    assert parsed["updates"][0].get("schedule", {}).get("interval"), "kept entry lost its schedule"
    assert parsed["updates"][0].get("directory") == "/", "kept entry changed directory"
    for eco in DROP:                                  # no orphan prose may survive
        assert eco not in new_text.lower().replace("github-actions", ""), f"orphan mention of {eco}"
    assert "--- Terraform" not in new_text and "--- Docker" not in new_text, "orphan header survived"
    # the surviving block must be byte-identical to the original, not re-rendered
    block = "\n".join(lines[kept_unit[0]:kept_unit[1]])
    assert block in new_text, "kept entry was altered rather than merely relocated"
    assert new_text.count(block) == 1, "kept entry duplicated"
    return new_text, after


def selftest():
    """Offline fixtures for trim_dependabot. No network."""
    cfg = ('# Dependabot configuration — x\n#\n# header says: delete the ecosystems that do not apply\n'
           '\nversion: 2\n\nupdates:\n\n'
           '  # --- Python (pip) ------\n  - package-ecosystem: "pip"\n    directory: "/"\n'
           '    schedule:\n      interval: "weekly"\n\n'
           '  # --- Node (npm) --------\n  - package-ecosystem: "npm"\n    directory: "/"\n'
           '    schedule:\n      interval: "weekly"\n\n'
           '  # --- GitHub Actions ----\n  - package-ecosystem: "github-actions"\n    directory: "/"\n'
           '    schedule:\n      interval: "weekly"\n    open-pull-requests-limit: 10\n\n'
           '  # --- Terraform ---------\n  - package-ecosystem: "terraform"\n    directory: "/"\n'
           '    schedule:\n      interval: "weekly"\n\n'
           '  # --- Docker ------------\n  - package-ecosystem: "docker"\n    directory: "/"\n'
           '    schedule:\n      interval: "weekly"\n')
    rc = 0
    out, after = trim_dependabot(cfg)
    ok = after == [KEEP] and "Terraform" not in out and "Docker" not in out and "pip" not in out.replace("github-actions", "")
    print(f"  {'ok  ' if ok else 'FAIL'} trim -> {after}; lines {len(cfg.splitlines())} -> {len(out.splitlines())}")
    rc = 0 if ok else 1
    # idempotency: trimming an already-trimmed file must ABORT, not silently double-apply
    try:
        trim_dependabot(out)
        print("  FAIL already-trimmed config accepted a second trim")
        rc = 1
    except AssertionError as e:
        print(f"  ok   re-trim aborts as expected: {str(e)[:60]}")
    # a foreign ecosystem must abort
    try:
        trim_dependabot(cfg.replace('package-ecosystem: "pip"', 'package-ecosystem: "gradle"'))
        print("  FAIL unknown ecosystem accepted")
        rc = 1
    except AssertionError as e:
        print(f"  ok   unknown ecosystem aborts: {str(e)[:60]}")
    # the kept block must survive intact
    if "open-pull-requests-limit: 10" not in out:
        print("  FAIL kept entry lost its settings")
        rc = 1
    else:
        print("  ok   kept entry retains its settings")
    print("SELFTEST:", "PASS" if rc == 0 else "FAIL")
    return rc


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--apply", action="store_true")
    ap.add_argument("--repos", help="comma-separated subset of the nine")
    ap.add_argument("--selftest", action="store_true")
    args = ap.parse_args()

    if args.selftest:
        sys.exit(selftest())

    # enumerate from the API, never from memory (E42: six invented names -> empty results)
    lst, err = gh(f"orgs/{ORG}/repos?per_page=100", "--jq",
                  '[.[] | select(.name|startswith("viavitae-landing-")) | .name] | join("\n")')
    if lst is None:
        print(f"FATAL cannot enumerate repos: {err}", file=sys.stderr)
        sys.exit(2)
    landings = sorted(p for p in lst.split("\n") if p.strip())
    assert len(landings) == 10, f"expected 10 landing repos, API returned {len(landings)}: {landings}"
    if args.repos:
        want = {r.strip() for r in args.repos.split(",") if r.strip()}
        unknown = want - set(landings)
        assert not unknown, f"requested repos are not landing repos: {sorted(unknown)}"
        targets = sorted(want)
    else:
        targets = [r for r in landings if r != "viavitae-landing-basilica"]

    mode = "APPLY" if args.apply else "DRY-RUN"
    print(f"mode={mode} targets={len(targets)} branch={BR}")
    counts = {"applied": 0, "skipped_done": 0, "abort": 0}

    for repo in targets:
        paths, terr = blob_paths(repo, BR)
        if paths is None:
            print(f"{repo}: ABORT branch unreadable ({terr})")
            counts["abort"] += 1
            continue
        pys = [p for p in paths if p.endswith(".py")]

        # --- item 1: the PyCharm stub --------------------------------------
        if "main.py" not in paths:
            assert not pys, f"{repo}: main.py gone but other python remains: {pys}"
            print(f"{repo}: item1 main.py ALREADY ABSENT (0 .py on branch) -> skip")
            counts["skipped_done"] += 1
        else:
            text, sha, rerr = read_file(repo, "main.py", BR)
            if text is None:
                print(f"{repo}: item1 ABORT read failed ({rerr})")
                counts["abort"] += 1
                continue
            if not all(m in text for m in STUB_MARKERS):
                print(f"{repo}: item1 ABORT main.py is not the PyCharm sample -- premise wrong")
                counts["abort"] += 1
                continue
            if pys != ["main.py"]:
                print(f"{repo}: item1 ABORT unexpected python set {pys}")
                counts["abort"] += 1
                continue
            if args.apply:
                info = delete(repo, "main.py", sha,
                              "chore(scaffold): remove the PyCharm sample script (no source in landing repos)\n\n" + TRAILER)
                after, _ = blob_paths(repo, BR)
                left = [p for p in (after or []) if p.endswith(".py")]
                ok = "main.py" not in (after or []) and not left
                print(f"{repo}: item1 DELETED verified={ok} remaining_py={left} {info}")
            else:
                print(f"{repo}: item1 WOULD DELETE main.py ({len(text)} bytes, sha={sha[:10]}, only .py on branch)")
            counts["applied"] += 1

        # --- item 2: Dependabot scope --------------------------------------
        text, sha, rerr = read_file(repo, ".github/dependabot.yml", BR)
        if text is None:
            print(f"{repo}: item2 ABORT config unreadable ({rerr})")
            counts["abort"] += 1
            continue
        eco_now = [u["package-ecosystem"] for u in yaml.safe_load(text)["updates"]]
        if eco_now == [KEEP]:
            print(f"{repo}: item2 ALREADY TRIMMED -> skip")
            counts["skipped_done"] += 1
            continue
        try:
            new_text, eco_after = trim_dependabot(text)
        except AssertionError as e:
            print(f"{repo}: item2 ABORT {e}")
            counts["abort"] += 1
            continue
        if args.apply:
            info = put(repo, ".github/dependabot.yml", sha, new_text,
                       "chore(dependabot): keep only github-actions; pip/npm/terraform/docker have no manifest here\n\n" + TRAILER)
            check, _, _ = read_file(repo, ".github/dependabot.yml", BR)
            eco_v = [u["package-ecosystem"] for u in yaml.safe_load(check)["updates"]] if check else None
            print(f"{repo}: item2 PUT {len(text)}->{len(new_text)} lines verified={eco_v == [KEEP]} ({eco_v}) {info}")
        else:
            print(f"{repo}: item2 WOULD TRIM {len(text.splitlines())} -> {len(new_text.splitlines())} lines, "
                  f"eco {eco_now} -> {eco_after}")
        counts["applied"] += 1

    print(f"\nRESULT: {mode} applied={counts['applied']} already_done={counts['skipped_done']} "
          f"aborted={counts['abort']} targets={len(targets)}")
    if counts["abort"]:
        print("aborted repos received NO writes; fix the premise and re-run -- they are resumable.")
    sys.exit(1 if counts["abort"] else 0)


if __name__ == "__main__":
    main()
