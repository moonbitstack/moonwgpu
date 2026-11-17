#!/usr/bin/env python3
"""Check the conformance ledger against the suite and against the tests.

Two directions are checked, and either one failing is a build failure:

  - every file the ledger names still exists in the indexed suite, so a rename
    upstream is noticed here rather than in a review a year later;
  - every test the ledger names still exists in this repository, so a test that
    is renamed or deleted cannot leave a claim pointing at nothing.

The ledger does not run the suite. The suite drives `navigator.gpu` from
TypeScript; this library is MoonBit over its own `hal`. What is claimed here is
that a rule the suite asserts is asserted here too, in this library's vocabulary.

Usage:
  python3 scripts/cts_check.py            # report and check
  python3 scripts/cts_check.py --quiet    # exit status only
"""

from __future__ import annotations

import argparse
import json
import pathlib
import re
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
INDEX = ROOT / "conformance" / "cts-cases.txt"
CLAIMS = ROOT / "conformance" / "claims.json"
STATUSES = ("mirrored", "partial", "not-applicable")

TEST = re.compile(r'^\s*test\s+"([^"]+)"', re.MULTILINE)


def read_index() -> tuple[str, dict[str, list[str]]]:
    """The suite revision, and each file with the cases it declares."""
    revision = "unknown"
    files: dict[str, list[str]] = {}
    for line in INDEX.read_text(encoding="utf-8").splitlines():
        if line.startswith("# revision: "):
            revision = line[len("# revision: ") :]
        elif line and not line.startswith("#"):
            path, _, case = line.partition("\t")
            files.setdefault(path, []).append(case)
    return revision, files


def read_tests() -> set[str]:
    names: set[str] = set()
    for path in ROOT.glob("src/**/*_wbtest.mbt"):
        names.update(TEST.findall(path.read_text(encoding="utf-8")))
    return names


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--quiet", action="store_true")
    args = parser.parse_args()

    revision, files = read_index()
    tests = read_tests()
    ledger = json.loads(CLAIMS.read_text(encoding="utf-8"))

    errors: list[str] = []
    seen: dict[str, str] = {}
    claimed_files: set[str] = set()
    claimed_cases = 0
    links = 0
    by_status: dict[str, int] = {status: 0 for status in STATUSES}

    for claim in ledger["claims"]:
        path = claim["cts"]
        status = claim["status"]
        if path in seen:
            errors.append(f"{path}: claimed twice")
        seen[path] = status
        if path not in files:
            errors.append(f"{path}: not in the indexed suite")
            continue
        if status not in STATUSES:
            errors.append(f"{path}: unknown status {status!r}")
            continue
        if not claim["tests"] and status != "not-applicable":
            errors.append(f"{path}: {status} but no test is named")
        for name in claim["tests"]:
            if name not in tests:
                errors.append(f"{path}: no test called {name!r}")
            else:
                links += 1
        claimed_files.add(path)
        claimed_cases += len(files[path])
        by_status[status] += 1

    total_cases = sum(len(cases) for cases in files.values())
    share = 100 * claimed_cases / total_cases if total_cases else 0

    if errors:
        sys.stderr.write("conformance ledger:\n")
        for line in errors:
            sys.stderr.write(f"  {line}\n")
        return 1

    if not args.quiet:
        print(f"suite      {ledger['suite']} at {revision}")
        print(f"indexed    {len(files)} files, {total_cases} cases")
        print(f"claimed    {len(claimed_files)} files, {claimed_cases} cases ({share:.1f}%)")
        print(f"status     " + ", ".join(f"{k} {v}" for k, v in by_status.items()))
        print(f"links      {links} test names resolved")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
