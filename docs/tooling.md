# Developer commands

Use `python scripts/dev.py` from the repository root. It selects the intended
Foundry profile per command, so a leftover shell variable cannot silently select
a different build. Start with the [setup guide](first-30-minutes.md).

| Command | Purpose |
| --- | --- |
| `python scripts/dev.py doctor` | Check Python, Foundry and compiler configuration |
| `python scripts/dev.py build` | Build the current product profile |
| `python scripts/dev.py test` | Run the current whole-stack tests |
| `python scripts/dev.py campaign --mode quick --seed 0x6529` | Reproducible input fuzzing and handler invariant sequences |
| `python scripts/dev.py check` | Current build/tests and focused interface/layout checks |
| `python scripts/dev.py docs` | Documentation validation |
| `python scripts/dev.py release` | Full release validation, including legacy regressions and artifacts |
| `python scripts/dev.py clean` | Remove build outputs; retain transaction broadcasts |

`make` shows help. `make dev`, `make doctor`, `make docs-check` and
`make release-check` are aliases; `make current-stack-check` and `make check`
remain supported current/full validation entrypoints. PowerShell users can also
run `pwsh -NoProfile -File scripts/check.ps1 -CurrentStack` or omit `-CurrentStack`
for the full aggregate wrapper.

Application integrations have an optional [TypeScript client](integrations/typescript-client.md).
With Node.js 22 or newer, run `npm --prefix packages/stream-client ci --ignore-scripts`
once, then `npm --prefix packages/stream-client test`. Its independent CI job
checks retained ABI freshness, TypeScript types, signing payloads and snapshots
without recompiling Solidity. Solidity development does not require Node.js.

## Pick the relevant tests

The new [artist operation extension](architecture/artist-operation-extension-v1.md)
has a separate design check: `python -m tools.protocol.check_artist_operation_extension`
and `python -m tools.protocol.test_artist_operation_extension`. It preserves the
historical 57-operation packets and derives the additive 58-row inventory.
Its implementation gate remains closed until matching source and execution
evidence exist; it is not a substitute for the current test suite.

```text
python scripts/dev.py test --match-contract StreamCurrentStackTest
python scripts/dev.py test --suite unit --match-test testExample
python scripts/dev.py test --suite legacy
python scripts/dev.py test --suite gas
python scripts/dev.py test --suite all
```

Replace example filters with real test names from the [test map](../test/README.md).
The default suite is `current`. Unit, legacy and gas selections use the default
regression profile; they have a different compilation purpose. A cold via-IR build
can take tens of minutes or longer. Warm targeted tests are the normal edit loop.
Changing compiler inputs can invalidate that cache. Do not run concurrent builders
against the same output/cache directories.

## Reproducible fuzz and invariant campaigns

Input fuzzing varies arguments to the five `StreamCurrentStackFuzzTest`
properties. `StreamCurrentStackInvariantTest` drives dependent operations through
the real stack and checks an independent accounting model after each step.
Its opening sequence and completion assertions require successful operations;
counting attempted calls alone does not establish useful coverage.

```text
python scripts/dev.py campaign --mode quick --seed 0x6529
python scripts/dev.py campaign --mode extended --seed 0x6529 --artifacts tmp/campaigns/extended-first
python scripts/dev.py campaign --mode extended --seed 0x6529 --replay-from tmp/campaigns/extended-first --artifacts tmp/campaigns/extended-replay
```

| Preset | Input cases per property | Invariant sequences | Steps per sequence |
| --- | --- | --- | --- |
| `quick` | 256 | 32 | 64 |
| `extended` | 4096 | 256 | 256 |

Both presets select the `current` profile, Foundry 1.7.1, Solidity 0.8.19,
optimizer 200, Paris and global via-IR. They use the printed uint256 seed,
one test worker, `fail_on_revert=true`, `check_interval=1` and handler metrics.
A counterexample fails the command. Missing suites, inherited test filters or
campaign timeouts, incompatible compiler settings and source changes during
execution also fail it. These budgets are not correctness or security claims.

Ordinary current/default tests use the quick invariant limits in `foundry.toml`.
The campaign overrides runtime fuzz settings without changing compiler inputs.
Each preset/seed normally uses its own `out/campaigns/` and `cache/campaigns/`
pair, protected by an exclusive campaign lock. Different seeds or presets can
run concurrently when resources permit. `--reuse-current` saves a cold build by
using `out/current` and `cache/current`; use it only when no other build, exporter
or campaign accesses those paths. The CLI lock coordinates campaigns, not
independently launched Forge processes.

Every invocation creates a new artifact directory (the printed default is under
`tmp/campaigns`). `campaign.json` retains the command, seed, resolved settings,
source-file hashes, Git commit when available, duration and reported results.
`forge.log` retains raw metrics and failure traces; read it while a build runs.
The handler's per-operation success counters are asserted within the suite;
Foundry's selector metrics report calls to the handler entry point. Failure
corpora remain beside the logs. Working source hashes may differ from the Git
commit when the checkout has edits; a focused copied fixture is not full-repo
or current-export validation.

`--replay-from` copies a prior run's retained failure corpus into a new run before
Foundry replays it and starts the campaign. It never modifies the prior run.
Keep its manifest, log and source revision when sharing a counterexample. If a
host interruption leaves a cache lock, confirm the owner has stopped before
removing that stale lock. See Foundry's
[replay behavior](https://getfoundry.sh/forge/replay-testing) and
[invariant metrics](https://getfoundry.sh/forge/invariant-testing).

PRs and main pushes run the explicit quick campaign in the existing current CI
job after compilation, reusing that job's cache serially. The evidence upload
includes the campaign directory even on failure. To run extended remotely,
manually dispatch **CI** with `extended_campaign` enabled. Manual dispatch runs
the current job only; the historical release and SDK jobs retain their normal
PR/push triggers. There is no recurring campaign schedule.

The release checksum and offline-verifier suites run in a separate CI job against
the committed bundle, concurrently with Solidity compilation. They use the same
pinned toolchain and retain their own logs. Current contract tests, Windows
operator tests, static analysis and the TypeScript client also run independently.

## Compiler and evidence boundaries

Foundry is pinned to **v1.7.1**, Solidity to **0.8.19**, and the supported developer
Python line is **3.12** (CI uses 3.12.13 on Linux and 3.12.10 on Windows). The current
profile uses global via-IR. The default profile combines current and historical
regressions with explicit per-source compiler restrictions. The canonical release
builder and retained deployment compiler exports serve separate provenance goals.
An artifact from one closure/profile must not be presented as another's bytecode.

Passing current tests proves the exercised local behaviors. It does not establish
production readiness or replace the [release gates](release-readiness.md). Stream
remains pre-audit and not production-ready.

## Maintainer references

After adding or removing Solidity files, run
`python -m tools.build.refresh_solidity_source_inventory`, then
`python -m tools.build.check_solidity_source_layout`. The refresh changes only
the active path inventory after validating the layout and imports. It preserves
the original migration manifest, historical receipts and frozen evidence.
Use `--check` to detect a stale inventory without writing files. Moves involving
historical destinations still require an explicit reviewed relocation entry.

| Task | Detailed reference |
| --- | --- |
| Install pins or refresh the Python lock | [Toolchain](reference/tooling/toolchain.md) |
| Locate an individual checker or full-wrapper stage | [Validation catalog](reference/tooling/validation.md) |
| Change time/gas parameters or governance policy | [Governed parameters](reference/tooling/governed-parameters.md) |
| Format Solidity or review a compiler warning | [Formatting](reference/tooling/formatting.md) |
| Regenerate evidence in dependency order | [Release artifacts](reference/tooling/release-artifacts.md) |
| Capture and compare production Slither findings | [Slither](reference/tooling/slither.md) |

Do not hand-edit generated release files. Preserve retained historical deployment
compilations byte-for-byte. Consult the relevant reference before changing tooling,
and validate a focused change before starting the complete release pass.
