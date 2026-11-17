#!/usr/bin/env python3
"""Compare the tables generated from the specification with the specification.

`texture_format.mbt`, `vertex_format.mbt` and `features.mbt` are transcriptions:
every member comes from an `enum` in `spec/spec/index.bs`. Transcription drifts
the moment the editor adds a format, so the sets are compared here, in both
directions, on every change and on the half-month refresh.

Comparison is on letters and digits only, lowercased, because the two sides
spell the same member differently: the specification writes `rgba8unorm-srgb`,
MoonBit writes `Rgba8unormSrgb`.

Usage:
  python3 scripts/spec_drift.py          # report, fail on drift
  python3 scripts/spec_drift.py --quiet  # exit status only
"""

from __future__ import annotations

import argparse
import pathlib
import re
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
SPEC = ROOT / "spec" / "spec" / "index.bs"

# (spec enum, the MoonBit file that transcribes it, the MoonBit enum)
TABLES = [
    ("GPUTextureFormat", "src/types/texture_format.mbt", "TextureFormat"),
    ("GPUVertexFormat", "src/types/vertex_format.mbt", "VertexFormat"),
    ("GPUFeatureName", "src/types/features.mbt", "FeatureName"),
]

IDL_ENUM = r"enum\s+{name}\s*\{{(.*?)\}}"
MBT_ENUM = r"enum\s+{name}\s*\{{(.*?)^\}}"
QUOTED = re.compile(r'"([^"]+)"')


def squash(text: str) -> str:
    return re.sub(r"[^a-z0-9]", "", text.lower())


def spec_members(name: str, source: str) -> set[str]:
    block = re.search(IDL_ENUM.format(name=name), source, re.S)
    if not block:
        sys.exit(f"spec: no enum {name} in {SPEC.relative_to(ROOT)}")
    # Comments in the enum body quote feature names, which are not members.
    body = re.sub(r"//[^\n]*", "", block.group(1))
    return {squash(m) for m in QUOTED.findall(body)}


def moonbit_members(enum: str, path: pathlib.Path) -> set[str]:
    source = path.read_text(encoding="utf-8")
    block = re.search(MBT_ENUM.format(name=enum), source, re.S | re.M)
    if not block:
        sys.exit(f"{path.relative_to(ROOT)}: no enum {enum}")
    members = set()
    for line in block.group(1).splitlines():
        line = line.strip()
        if not line or line.startswith("//"):
            continue
        variant = line.split()[0].split("(")[0]
        if variant[:1].isupper():
            members.add(squash(variant))
    return members


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--quiet", action="store_true")
    args = parser.parse_args()

    if not SPEC.is_file():
        sys.exit(
            f"{SPEC.relative_to(ROOT)} is missing: run "
            "`git submodule update --init --depth 1 spec`"
        )
    spec_source = SPEC.read_text(encoding="utf-8")

    drift = 0
    for name, path, enum in TABLES:
        wanted = spec_members(name, spec_source)
        have = moonbit_members(enum, ROOT / path)
        missing = sorted(wanted - have)
        extra = sorted(have - wanted)
        if missing or extra:
            drift += 1
            sys.stderr.write(f"{name} and {enum} disagree\n")
            for member in missing:
                sys.stderr.write(f"  the specification has, {path} lacks: {member}\n")
            for member in extra:
                sys.stderr.write(f"  {path} has, the specification lacks: {member}\n")
        elif not args.quiet:
            print(f"{enum:<14} {len(have):>4} members, as the specification lists them")

    if drift and not args.quiet:
        sys.stderr.write("run the refresh workflow, then update the tables\n")
    return 1 if drift else 0


if __name__ == "__main__":
    raise SystemExit(main())
