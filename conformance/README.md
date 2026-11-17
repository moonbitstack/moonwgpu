# Conformance

The WebGPU conformance suite is a TypeScript program that drives `navigator.gpu`
inside a browser or Deno. This library is MoonBit over its own `hal`, with no
JavaScript binding and no GPU underneath the reference backend, so the suite
cannot be executed against it. What can be imported is its shape, and that is
what this directory holds.

| File | What it holds |
|:--|:--|
| `cts-cases.txt` | every `*.spec.ts` in the suite and the cases each one declares, generated from the pinned `cts/` submodule |
| `claims.json` | the rules this repository mirrors, file by file, with the tests that assert them |

`claims.json` is a claim about rules, not about passing: a file the suite runs
against a real device is a file whose *validation* this library can reproduce,
and the ledger names the test that does it. `status` is one of

- `mirrored` — every rule the file tests has a test here;
- `partial` — some of them do, and the file is expected to grow towards
  `mirrored`;
- `not-applicable` — the file needs a device, a shader compiler or a swap chain,
  which is another library's question.

At the pin recorded in `cts-cases.txt`, the ledger covers 25 of 694 files, 184 of
3277 cases, and resolves 68 test names. Those numbers are printed by the checker
below rather than maintained here; the point of the directory is that they can
only move deliberately.

## Checking it

```bash
git submodule update --init --depth 1 cts
git -C cts sparse-checkout set --cone src/webgpu   # 11 MB instead of 55
python3 scripts/cts_index.py                       # rewrite cts-cases.txt
python3 scripts/cts_check.py                       # both directions
python3 scripts/spec_drift.py                      # tables against the spec
```

`cts_index.py` reads `g.test('...')` declarations, so a case name changing
upstream is visible in a diff. `cts_check.py` fails when a claimed file is no
longer in the index or a claimed test no longer exists here, which is what keeps
the ledger from decaying into prose. `spec_drift.py` compares `TextureFormat`,
`VertexFormat` and `FeatureName` with the `enum`s in `spec/spec/index.bs`, in
both directions, so a format the editor adds is noticed on the next refresh
instead of years later.

## Adding a claim

1. Read the case in `cts/`, in this order: the descriptor it builds, the error
   it expects, the rule it cites in the specification.
2. Write the test here with a name that says the rule, not the case.
3. Add `{"cts": ..., "status": ..., "tests": [...]}` to `claims.json`, and run
   `scripts/cts_check.py`.

A claim that names a test which does not exist is a build failure, deliberately:
the ledger is only worth reading if it is true.

## The half-month refresh

`.github/workflows/refresh.yml` runs on the 1st and the 15th: it moves the
`spec` and `cts` pins to upstream head, regenerates `cts-cases.txt`, and opens a
pull request with whatever moved. The checks run after the pull request is
opened, so the new pin is visible even when a rename upstream needs a human to
update a claim.
