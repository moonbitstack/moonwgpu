# Conformance

The WebGPU conformance suite is a TypeScript program that drives `navigator.gpu`
inside a browser or Deno. This library is MoonBit over its own `hal`, so the
suite is not executed as written; what this directory holds is its shape, the
ledger of rules it led to, and — on the `js` backend — a WebGPU-shaped facade
that a case of the same shape can actually be written against.

| File | What it holds |
|:--|:--|
| `cts-cases.txt` | every `*.spec.ts` in the suite and the cases each one declares, generated from the pinned `cts/` submodule |
| `claims.json` | the rules this repository mirrors, file by file, with the tests that assert them |
| `targets.json` | what each of the four backends ran, so "it builds" is never mistaken for "it passes" |
| `js/webgpu.mjs` | the objects, promises and error classes a suite expects, over `src/bindings/js` |
| `js/run.mjs` | a dozen cases in the suite's shape, driven from JavaScript |

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
python3 scripts/targets.py                         # the suite on all four backends
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

## The four backends

One source tree, four backends, and a case that passes on one of them is not a
case that passes on the others. `targets.json` records what each backend ran;
`scripts/targets.py --check` re-runs the suite and fails on a difference, so a
backend that quietly loses a test is a red build rather than a footnote.

The `js` backend is the only one a JavaScript host can reach, and `js/webgpu.mjs`
is what makes it reachable in the suite's own terms:

```bash
moon build --target js
node conformance/js/run.mjs
```

`src/bindings/js` publishes three functions on `globalThis.__moonwgpu`; the
facade turns them into `navigator.gpu`, with `mapAsync` returning a promise,
`popErrorScope` resolving to a `GPUValidationError` or to null, and an invalid
resource behaving like one — calls return, and no state changes.

Two things it cannot carry, both of them the backend's limits rather than the
binding's: there is no rasterizer, so a case that compares pixels has nothing to
compare, and there is no WGSL front end, so a case that runs a shader has
nothing to run. Command buffers are left out for a third reason — encoding is
written in MoonBit, where `core` can validate it, and a facade that accepted
JavaScript-side encoding would be a second, weaker implementation of the same
rules.

`wasm` and `wasm-gc` are in the opposite position: an artifact of either exports
`_start` and nothing else, and neither accepts `extern "js"`, so no host can
call in. They are driven by the suite running inside them, which is what
`targets.json` records.
