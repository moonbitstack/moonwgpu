#!/usr/bin/env python3
# Copyright 2026 Leo Cheng
# SPDX-License-Identifier: Apache-2.0

"""Record what each backend runs, not just what compiles.

One source tree, four backends, and a suite that has to pass on all of them:
`moon check` says a backend builds, which is not the same claim. This runs the
suite on each backend in turn and writes the count to
`conformance/targets.json`, so a backend that loses a test is a diff in review
rather than a surprise after a release.

    python3 scripts/targets.py            # run, then write the file
    python3 scripts/targets.py --check    # fail if the file is stale
"""

from __future__ import annotations

import json
import re
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "conformance" / "targets.json"
BACKENDS = ["wasm", "wasm-gc", "js", "native"]
TOTALS = re.compile(r"Total tests: (\d+), passed: (\d+), failed: (\d+)\.")


def toolchain() -> str:
    result = subprocess.run(
        ["moon", "version"], cwd=ROOT, capture_output=True, text=True
    )
    return result.stdout.strip().splitlines()[0] if result.stdout.strip() else "unknown"


def run(backend: str) -> dict:
    # Twice, because the first `moon test` on a cold `_build` can lose the
    # summary line to a concurrent linker on Windows; the second run reads the
    # cache and always prints it. A real failure fails both times.
    for attempt in range(2):
        result = subprocess.run(
            ["moon", "test", "--target", backend],
            cwd=ROOT,
            capture_output=True,
            text=True,
        )
        match = TOTALS.search(result.stdout)
        if match is not None:
            break
        if attempt == 1:
            sys.stderr.write(result.stdout[-2000:])
            sys.stderr.write(result.stderr[-2000:])
            raise SystemExit(f"no test total for {backend}: moon test failed")
    total, passed, failed = (int(group) for group in match.groups())
    return {
        "backend": backend,
        "total": total,
        "passed": passed,
        "failed": failed,
        "exit": result.returncode,
    }


def collect() -> dict:
    return {
        "toolchain": toolchain(),
        "backends": [run(backend) for backend in BACKENDS],
    }


def render(ledger: dict) -> str:
    return json.dumps(ledger, indent=2) + "\n"


def main(argv: list[str]) -> int:
    ledger = collect()
    body = render(ledger)
    if "--check" in argv:
        # The toolchain line is context for a reader, not a claim: CI installs
        # whatever moon is current, and a version bump is not a regression.
        current = json.loads(OUT.read_text(encoding="utf-8")) if OUT.exists() else {}
        if current.get("backends") != ledger["backends"]:
            sys.stderr.write(
                "conformance/targets.json is stale: run scripts/targets.py\n"
            )
            return 1
        broken = [entry for entry in ledger["backends"] if entry["failed"] > 0]
        if broken:
            for entry in broken:
                sys.stderr.write(
                    f"{entry['backend']}: {entry['failed']} of {entry['total']} failed\n"
                )
            return 1
        print(
            "backends agree: "
            + ", ".join(f"{entry['backend']} {entry['passed']}/{entry['total']}" for entry in ledger["backends"])
        )
        return 0

    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_text(body, encoding="utf-8", newline="\n")
    for entry in ledger["backends"]:
        print(f"{entry['backend']:<8} {entry['passed']}/{entry['total']}")
    return 0 if all(entry["failed"] == 0 for entry in ledger["backends"]) else 1


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
