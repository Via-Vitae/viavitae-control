#!/usr/bin/env python3
"""check_dependabot_scope.py — detect Dependabot entries that can never resolve anything.

Why this exists (evidence VV-2026-10-026): `viavitae-template` ships `.github/dependabot.yml`
as a deliberate SUPERSET and tells the reader so in its own header comment —
"Delete the ecosystems that do not apply to the repository type". Repos generated from it
were never trimmed, so they declare ecosystems whose manifest does not exist. That is not
cosmetic: every dead entry is attempted on the declared schedule, and 44 of the 45 measured
dead entries FAILED on the 2026-10-26 weekly cycle (nine landings and the template 4 each,
brand 3, clients 1). The 45th — brand's `pip` at `/` — PASSED while resolving nothing, which
is the worse outcome: a dead entry can be silently vacuous instead of red. An estate that
mutes its own monitoring noise cannot tell a real Dependabot failure from scaffolding.

`--check-runs` exists because a config verdict alone is not sufficient. It says an entry CAN
read a manifest; it does not say the updater works. Measured counter-example: `viavitae-qa`
and `viavitae-web` pass the config check completely while their `npm_and_yarn` updater fails
repeatedly (off-cycle, on security-update attempts). So exit 0 here means "no dead entry and
no unmonitored manifest", never "Dependabot is working in this repo".

The classifier is DIRECTORY-AWARE on purpose. A naive "does any requirements.txt exist
anywhere" test gives the wrong answer for `viavitae-brand`, which holds
`tools/requirements.txt` and `build/package.json` while its config points `pip` and `npm`
at `/`: those entries are dead *and* the real manifests are unmonitored — two defects, not
one. `--selftest` locks that behaviour in offline, without network.

Credential: this needs Contents:read on every org repo, plus Actions:read with --check-runs.
The CI read-only PAT (ORG_READ_TOKEN) carries only Repository Administration + Metadata, so
this is run by an operator (`gh auth token`), NOT wired into audit.yml — adding it to CI would
mean widening a CI credential, which is a privilege increase and the owner's call.

Exit contract follows scripts/check_plan_selfcite.sh:
  0  every entry in every repo scanned resolves to at least one manifest
  1  a dead entry, an unmonitored manifest, or (--check-runs) a failing updater
  2  nothing checkable (no repo readable, config absent) — never reported as a pass

Usage:
  .venv/bin/python scripts/check_dependabot_scope.py [--org Via-Vitae] [--repos a,b]
  .venv/bin/python scripts/check_dependabot_scope.py --check-runs [--window 2026-10-25..2026-10-31]
  .venv/bin/python scripts/check_dependabot_scope.py --selftest
"""
from __future__ import annotations

import argparse
import base64
import json
import re
import subprocess
import sys
from datetime import date, timedelta
from pathlib import PurePosixPath

import yaml

# Manifest each ecosystem must be able to READ, in the entry's own directory.
# Names are matched case-sensitively against the exact directory's file set.
MANIFEST_GLOBS = {
    "pip": ("requirements", "pyproject.toml", "Pipfile", "poetry.lock", "setup.py", "setup.cfg", "environment.yml"),
    "npm": ("package.json", "package-lock.json", "yarn.lock", "pnpm-lock.yaml", "lerna.json"),
    "docker": ("Dockerfile", "containerfile"),
    "terraform": (".tf",),
    "github-actions": None,  # satisfied by any .github/workflows/* anywhere in the repo
}


def gh(*args):
    r = subprocess.run(["gh", "api", *args], capture_output=True, text=True)
    if r.returncode != 0:
        return None, (r.stderr.strip() or r.stdout.strip())[:200]
    return r.stdout, None


def read_contents(repo, path, ref):
    out, err = gh(f"repos/{repo}/contents/{path}", "--method", "GET",
                  "-f", f"ref={ref}", "--jq", ".content")
    if out is None:
        return None, err
    return base64.b64decode(out.strip().replace("\n", "")).decode(), None


def read_tree(repo, ref):
    out, err = gh(f"repos/{repo}/git/trees/{ref}?recursive=1", "--jq",
                  '[.tree[] | select(.type=="blob") | .path] | join("\\n")')
    if out is None:
        return None, err
    return [p for p in out.split("\n") if p.strip()], None


WS_ITEM = re.compile(r'^\s*-\s*["\']?([^"\'#\n]+?)["\']?\s*$', re.M)


def workspace_patterns(pnpm_ws_text, root_pkg_text):
    """Directory globs a package manager treats as one dependency root.

    Why this matters: Dependabot's `npm` ecosystem pointed at "/" covers a pnpm/npm
    workspace through the root lockfile, so a member `package.json` in a subdirectory
    is NOT an unmonitored manifest. Without this, the first run of this guard flagged
    six false positives in viavitae-qa alone (e2e, load, a11y, fixtures, contract,
    performance are all listed in its pnpm-workspace.yaml).
    Limitation: the suppression assumes the root lockfile actually resolves the
    workspace. If it does not, the member is unmonitored and this guard is blind to it.
    """
    pats = set()
    if pnpm_ws_text:
        pats.update(m.strip() for m in WS_ITEM.findall(pnpm_ws_text.split("packages:")[-1]))
    if root_pkg_text:
        try:
            ws = json.loads(root_pkg_text).get("workspaces")
        except Exception:  # noqa: BLE001 - unreadable root package.json is not a violation
            ws = None
        if isinstance(ws, list):
            pats.update(str(p).strip() for p in ws)
        elif isinstance(ws, dict):
            pats.update(str(p).strip() for p in (ws.get("packages") or []))
    return {p for p in pats if p}


def in_workspace(directory, patterns):
    rel = directory.strip("/")
    for pat in (p.strip("/") for p in patterns):
        if pat == rel:
            return True
        if pat.endswith("/**") and rel.startswith(pat[:-2]):   # shared/** -> shared/a/b
            return True
        if pat.endswith("/*") and rel.startswith(pat[:-2]):    # packages/* -> one level
            rest = rel[len(pat) - 1:]
            if rest and "/" not in rest:
                return True
    return False


# Dependabot names its update runs `"<ecosystem> in <directory> ... - Update #<id>"`, using
# its own internal ecosystem ids and a `/.` suffix for the repo root. Graph-update rows
# ("Graph Update: uv") carry no ` in ` and are not a version-update attempt.
ECO_ALIAS = {"npm_and_yarn": "npm", "github_actions": "github-actions", "pip": "pip",
             "docker": "docker", "terraform": "terraform"}
RUN_NAME = re.compile(r"^(?P<eco>[a-z_]+) in (?P<dir>/\S*)\s")


def parse_update_run_name(name):
    """Return (config_ecosystem, normalised_directory) or None if not a version update."""
    m = RUN_NAME.match(name or "")
    if not m:
        return None
    eco = ECO_ALIAS.get(m.group("eco"), m.group("eco"))
    d = m.group("dir")
    if d in ("/.", "/"):
        d = "/"
    else:
        d = "/" + d.strip("/").lstrip(".")
    return eco, d


def declared_entries(config_text):
    """The (ecosystem, normalised directory) pairs a config declares. [] if unparseable."""
    try:
        cfg = yaml.safe_load(config_text)
        updates = (cfg or {}).get("updates") or []
    except Exception:  # noqa: BLE001 - classify() already reports this shape
        return []
    pairs = []
    for u in updates if isinstance(updates, list) else []:
        if not isinstance(u, dict):
            continue
        eco = u.get("package-ecosystem", "?")
        for d in ([u["directory"]] if "directory" in u else u.get("directories") or ["/"]):
            norm = "/" + str(d).strip("/") if str(d).strip("/") not in ("", "/") else "/"
            pairs.append((eco, norm))
    return pairs


def failing_update_targets(repo, window):
    """(ecosystem, dir) pairs whose update attempt FAILED in the window.

    `window` must be a GitHub `created` RANGE (`start..end`). A bare date means "on that one
    day", which is how the first version of this flag reported "no failing updater" for repos
    known to have failed on 2026-10-26 -- a category that can never fire is not a control.

    Returns None on a read failure -- the caller must report UNKNOWN, never zero.
    """
    out, err = gh(f"repos/{repo}/actions/runs?event=dynamic&created={window}&per_page=100",
                  "--jq", '[.workflow_runs[] | select(.conclusion=="failure") | .name] | join("\\n")')
    if out is None:
        return None, err
    targets = set()
    for line in out.split("\n"):
        parsed = parse_update_run_name(line.strip())
        if parsed:
            targets.add(parsed)
    return targets, None


def by_directory(paths):
    """Map '' (repo root) and '/sub/dir' -> set of file names in it.

    Keys use the Dependabot convention: root is '/', everything else is '/a/b'.
    """
    out = {"/": set()}
    for p in paths:
        par = str(PurePosixPath(p).parent)
        key = "/" if par == "." else "/" + par.strip("/")
        out.setdefault(key, set()).add(PurePosixPath(p).name)
    return out


def entry_resolves(eco, directory, dir_files, has_workflows):
    """True if Dependabot can find at least one manifest for this entry."""
    if eco == "github-actions":
        return has_workflows
    needles = MANIFEST_GLOBS.get(eco)
    if needles is None:
        return None  # unknown ecosystem -> cannot judge
    files = dir_files.get(directory, set())
    for needle in needles:
        if needle.startswith("."):                     # extension match (terraform)
            if any(f.endswith(needle) for f in files):
                return True
        else:                                          # prefix-or-exact match
            if any(f == needle or f.startswith(needle) for f in files):
                return True
    return False


def classify(config_text, paths, ws_patterns=()):
    """Return (dead_entries, unmonitored_manifests). Both may be non-empty."""
    try:
        cfg = yaml.safe_load(config_text)
    except Exception as exc:  # noqa: BLE001 - report, do not crash a guard
        return [f"<unparseable dependabot config: {exc}>"], []
    updates = (cfg or {}).get("updates") or []
    if not isinstance(updates, list):
        return [f"<updates: is not a list (parsed as {type(updates).__name__})>"], []
    if not updates:
        return ["<no updates: entries present>"], []
    dirs = by_directory(paths)
    has_workflows = any(p.startswith(".github/workflows/") for p in paths)
    dead, covered_dirs = [], {}
    for u in updates:
        if not isinstance(u, dict):           # malformed entry: never silently skipped
            dead.append(f"<update entry is not a mapping: {u!r}>")
            continue
        eco = u.get("package-ecosystem", "?")
        for d in ([u["directory"]] if "directory" in u else u.get("directories") or ["/"]):
            norm = "/" + str(d).strip("/") if str(d).strip("/") not in ("", "/") else "/"
            ok = entry_resolves(eco, norm, dirs, has_workflows)
            if ok is False:
                dead.append(f"{eco} @ {norm}")
            elif ok:
                covered_dirs.setdefault(eco, set()).add(norm)
    # A readable manifest that NO entry points at is the mirror defect: real deps,
    # no monitoring. Only judge the ecosystems we know how to look for.
    unmonitored = []
    root_npm_covered = "npm" in covered_dirs and "/" in covered_dirs["npm"]
    for d, files in sorted(dirs.items()):
        for eco, needles in MANIFEST_GLOBS.items():
            if needles is None or eco == "terraform":
                continue
            if any(f == n or f.startswith(n) for f in files for n in needles):
                if d in covered_dirs.get(eco, set()):
                    continue
                # a workspace member under a covered npm root is monitored via the
                # root lockfile — reporting it would be a false positive
                if eco == "npm" and root_npm_covered and in_workspace(d, ws_patterns):
                    continue
                unmonitored.append(f"{eco} manifest in {d} has no matching update entry")
    return dead, unmonitored


def selftest():
    """Offline fixtures. Returns 0 when every expectation holds."""
    rc = 0
    cases = [
        # (name, dependabot yaml, tree paths, expect_dead, expect_unmonitored, ws patterns)
        ("superset scaffold (the landing case)",
         'version: 2\nupdates:\n' + "".join(
             f"  - package-ecosystem: \"{e}\"\n    directory: \"/\"\n"
             for e in ("pip", "npm", "github-actions", "terraform", "docker")),
         ["README.md", "main.py", ".github/workflows/ci.yml"], 4, 0, ()),
        # the directory trap: manifests exist, but not where the config looks
        ("subdir manifests, root-pointed config (the brand case)",
         'version: 2\nupdates:\n  - package-ecosystem: "pip"\n    directory: "/"\n'
         '  - package-ecosystem: "npm"\n    directory: "/"\n',
         ["tools/requirements.txt", "build/package.json", ".github/workflows/ci.yml"], 2, 2, ()),
        # correctly scoped config
        ("directory-matched",
         'version: 2\nupdates:\n  - package-ecosystem: "pip"\n    directory: "/tools"\n'
         '  - package-ecosystem: "github-actions"\n    directory: "/"\n',
         ["tools/requirements.txt", ".github/workflows/ci.yml"], 0, 0, ()),
        ("terraform in the pointed dir",
         'version: 2\nupdates:\n  - package-ecosystem: "terraform"\n    directory: "/tf"\n',
         ["tf/main.tf", ".github/workflows/ci.yml"], 0, 0, ()),
        ("no workflows anywhere -> actions entry is dead too",
         'version: 2\nupdates:\n  - package-ecosystem: "github-actions"\n    directory: "/"\n',
         ["README.md"], 1, 0, ()),
        ("requirements-dev.txt satisfies pip by prefix",
         'version: 2\nupdates:\n  - package-ecosystem: "pip"\n    directory: "/"\n',
         ["requirements-dev.txt"], 0, 0, ()),
        # the false-positive trap the first live run produced six of
        ("pnpm workspace members under a covered npm root",
         'version: 2\nupdates:\n  - package-ecosystem: "npm"\n    directory: "/"\n'
         '  - package-ecosystem: "github-actions"\n    directory: "/"\n',
         ["package.json", "pnpm-lock.yaml", "e2e/package.json", "a11y/package.json",
          "packages/brand/package.json", "shared/ui/package.json", "deep/nested/pkg/package.json",
          ".github/workflows/ci.yml"], 0, 1,
         ("e2e", "a11y", "packages/*", "shared/**")),
    ]
    for name, cfg, paths, want_dead, want_unmon, ws in cases:
        dead, unmon = classify(cfg, paths, ws)
        ok = len(dead) == want_dead and len(unmon) == want_unmon
        print(f"  {'ok  ' if ok else 'FAIL'} {name}: dead={dead} unmonitored={unmon}")
        if not ok:
            print(f"       expected dead={want_dead} unmonitored={want_unmon}")
            rc = 1
    # malformed config must be reported, never silently treated as clean
    dead, _ = classify("version: 2\nupdates: notalist\n", ["README.md"])
    if not dead:
        print("  FAIL malformed config classified as clean")
        rc = 1
    else:
        print(f"  ok   malformed config is a violation: {dead[0][:60]}")
    # a list of non-mapping entries must not crash and must not pass
    dead, _ = classify('version: 2\nupdates:\n  - "oops"\n', ["README.md"])
    if not dead:
        print("  FAIL non-mapping update entry classified as clean")
        rc = 1
    else:
        print(f"  ok   non-mapping update entry is a violation: {dead[0][:60]}")
    ws_cases = [
        # (patterns, directory, expected)
        (("e2e", "load", "a11y"), "/e2e", True),
        (("packages/*",), "/packages/brand", True),
        (("packages/*",), "/packages/brand/sub", False),
        (("shared/**",), "/shared/ui", True),
        (("shared/**",), "/shared/ui/deep", True),
        (("config",), "/", False),
    ]
    for pats, d, want in ws_cases:
        got = in_workspace(d, pats)
        print(f"  {'ok  ' if got == want else 'FAIL'} in_workspace({d}, {list(pats)}) = {got}")
        if got != want:
            rc = 1
    # run-name parser: the shapes Dependabot actually emits
    name_cases = [
        ("terraform in /. - Update #1652984220", ("terraform", "/")),
        ("npm_and_yarn in /. - Update #1652981921", ("npm", "/")),
        ("pip in /tools for Pillow - Update #1649387951", ("pip", "/tools")),
        ("pip in / for ruff, mypy - Update #1652982886", ("pip", "/")),
        ("github_actions in /. - Update #1652978444", ("github-actions", "/")),
        ("Graph Update: uv", None),           # not a version-update attempt
        ("CI", None),
    ]
    for raw, want in name_cases:
        got = parse_update_run_name(raw)
        print(f"  {'ok  ' if got == want else 'FAIL'} parse {raw[:46]!r} -> {got}")
        if got != want:
            rc = 1
    # declared_entries must agree with classify() about what the config claims
    pairs = declared_entries('version: 2\nupdates:\n  - package-ecosystem: "pip"\n    directory: "/tools"\n'
                             '  - package-ecosystem: "github-actions"\n    directory: "/"\n')
    if sorted(pairs) != [("github-actions", "/"), ("pip", "/tools")]:
        print(f"  FAIL declared_entries -> {pairs}")
        rc = 1
    else:
        print(f"  ok   declared_entries -> {pairs}")
    print("SELFTEST:", "PASS" if rc == 0 else "FAIL")
    return rc


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--org", default="Via-Vitae")
    ap.add_argument("--repos", help="comma-separated subset (default: whole org)")
    ap.add_argument("--selftest", action="store_true")
    ap.add_argument("--check-runs", action="store_true",
                    help="also report declared entries whose updater run FAILED in the window")
    ap.add_argument("--window", default=None,
                    help="GitHub created range for --check-runs, e.g. 2026-10-25..2026-10-31 "
                         "(default: the last 8 days)")
    args = ap.parse_args()

    if args.window is None:
        today = date.today()
        args.window = f"{today - timedelta(days=8)}..{today}"

    if args.selftest:
        sys.exit(selftest())

    if args.repos:
        repos = [r.strip() for r in args.repos.split(",") if r.strip()]
    else:
        out, err = gh(f"orgs/{args.org}/repos?per_page=100", "--jq",
                      '[.[] | .full_name] | join("\n")')
        if out is None:
            print(f"cannot list repos: {err}", file=sys.stderr)
            sys.exit(2)
        repos = [r for r in out.split("\n") if r.strip()]

    checked = violations = unreadable = run_read_failures = 0
    for repo in sorted(repos):
        default, err = gh(f"repos/{repo}", "--method", "GET", "--jq", ".default_branch")
        if default is None:
            print(f"  {repo}: SKIP (repo read failed: {err})")
            unreadable += 1
            continue
        ref = default.strip()
        cfg, _ = read_contents(repo, ".github/dependabot.yml", ref)
        if cfg is None:
            continue  # no config is not a violation; nothing claims coverage
        paths, terr = read_tree(repo, ref)
        if paths is None:
            print(f"  {repo}: SKIP (tree read failed: {terr})")
            unreadable += 1
            continue
        checked += 1
        ws_text, _ = read_contents(repo, "pnpm-workspace.yaml", ref)
        root_pkg, _ = read_contents(repo, "package.json", ref)
        dead, unmon = classify(cfg, paths, workspace_patterns(ws_text, root_pkg))
        failing, ferr = set(), None
        if args.check_runs:
            failing, ferr = failing_update_targets(repo, args.window)
            if failing is None:                       # unknown is never a pass
                run_read_failures += 1
                print(f"  {repo}: WARN update-run read failed ({ferr}) -> outcome UNDETERMINED")
                failing = set()
        declared = declared_entries(cfg)
        confirmed = sorted(set(declared) & failing) if failing else []
        if dead or unmon or confirmed or ferr:
            violations += 1
            print(f"  {repo} (@{ref}):")
            for d in dead:
                print(f"      DEAD        {d}  <- no manifest here: attempt fails, or passes vacuously")
            for u in unmon:
                print(f"      UNMONITORED {u}  <- real manifest no entry points at")
            for eco, d in confirmed:
                print(f"      FAILING     {eco} @ {d}  <- updater errored within {args.window}")
        else:
            extra = ", no failing updater" if args.check_runs else ""
            print(f"  {repo} (@{ref}): all {len(cfg.splitlines())}-line config resolves{extra}")

    if checked == 0:
        sys.stdout.flush()   # keep the verdict after the per-repo lines in a captured transcript
        print(f"nothing checkable: {len(repos)} repos listed, 0 configs read "
              f"({unreadable} unreadable)", file=sys.stderr)
        sys.exit(2)
    sys.stdout.flush()
    print(f"\nSUMMARY: {checked} repo(s) with a dependabot config, {violations} with "
          f"a dead, unmonitored or failing entry, {unreadable} unreadable, "
          f"{run_read_failures} run-outcome undetermined")
    sys.exit(1 if violations or unreadable or run_read_failures else 0)


if __name__ == "__main__":
    main()
