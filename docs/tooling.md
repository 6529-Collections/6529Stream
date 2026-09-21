# Developer commands

Use `python scripts/dev.py` from the repository root. It selects the intended
Foundry profile per command, so a leftover shell variable cannot silently select
a different build. Start with the [setup guide](first-30-minutes.md).

| Command | Purpose |
| --- | --- |
| `python scripts/dev.py doctor` | Check Python, Foundry and compiler configuration |
| `python scripts/dev.py build` | Build the current product profile |
| `python scripts/dev.py prepare-graph` | Prepare graph test inputs from the completed native build |
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

The [museum tooling](../tools/museum/README.md) has its own pinned Python
dependencies and independent Windows/Linux CI workflow. Its tests and
deterministic schema/fixture checks run without compiling Solidity. Use the
documented isolated environment; the general tools lock does not include the
JSON-LD dependencies. These tests cover the implemented offline tools and do
not establish complete museum conformance. The same CI job runs the offline
preservation package, image-metric and replay-receipt controls on both platforms:

```bash
python -B -m unittest discover -s tools/preservation -t . -p "test_*.py" -v
```

The copied Windows runtime execution test is opt-in; follow the
[retained metric package guide](integrations/reference-metric-package.md) for
that separately retained acceptance run. Ordinary CI does not execute archives.

The [typed record tools](../tools/metadata/README.md) share that isolated Python
environment for independent JSON Schema and canonical-byte tests. Run
`python -m unittest tools.metadata.test_rights_profile -v` and
`python -m tools.metadata.rights_profile --check` for the rights profile.
Both commands are included in museum CI; they do not register anything onchain.

Release checksum validation accepts the exact Git diagnostic override
`whitespace=-blank-at-eol` used by the preserved W3C license notice. This does not
change its inherited text/LF policy or remove trailing spaces from the upstream
bytes. The complete `.gitattributes` file remains part of the checksum inputs;
other unsupported attributes still fail validation.

CI schedules each job independently. Draft pull requests retain their running
current/default native jobs so their completed compiler caches survive integration
pushes; only the newest pending revision waits for each native job. Repository,
client, Windows, Slither and release-verification jobs cancel superseded PR work
and can check a new revision while an older native job finishes. Ready pull
requests cancel superseded native jobs too. Push and manual runs keep separate
concurrency groups and are not canceled by PR updates. Always associate every
result with its tested commit; an earlier pass does not validate a new revision.
This uses [GitHub's job concurrency behavior](https://docs.github.com/en/actions/how-tos/write-workflows/choose-when-workflows-run/control-workflow-concurrency).

Repository hygiene, historical design checks and wrapper checks run independently
of the default compiler. The existing required `Foundry smoke` status succeeds
only when both jobs from that revision succeed; failed, canceled or skipped
dependencies fail that status. Every PR/main revision still schedules all CI jobs;
there are no changed-path exemptions from native, Safe, fuzz, gas or release
gates. Compiler caches remain accelerators: Forge checks current inputs after
restore, graph preparation authenticates the selected native hosts, and export
checks bind the current candidate. CI generates that candidate once after the
build and checks it again after tests without rewriting it. Release Mode and the
full local release command keep their complete validation sequence.

The Python toolchain policy checks the independent museum workflow's reviewed
Windows/Linux matrix, action pins, dependency setup and complete offline test
commands. Its separate requirement files use exact version pins; they do not
use the release tools' hash lock. Museum workflow and requirement inputs are
included in release checksum coverage when the frozen bundle is regenerated.

## Current graph fixture preparation

After a current native build, prepare its compact graph inputs before running
current tests or a campaign:

```text
python scripts/dev.py build
python scripts/dev.py prepare-graph
python scripts/dev.py test
```

For an embedded-creation fixture, the command selects the actual cached literal
creation library, whose compiler context owns the embedded creation bytes and
immutable references for the required products. Each selected graph or campaign test host is authenticated
against its own cache-selected native compiler output. Unrelated test changes
can therefore reuse an unchanged creation library without forcing a full build.
The selected helpers and their transitive imports must still match current source
bytes; stale dependencies, ambiguous cache entries or changed executables fail.

For a custom cache, use `python -m tools.build.prepare_current_graph --out
<output-directory> --cache-path <cache-directory>`; the paths must identify the
same completed Forge build/cache pair. Campaigns bind both executed fuzz/invariant
hosts. Complete exports remain under ignored `artifacts/current-graph/native`,
with each compiler context recorded separately; original Forge outputs stay
unchanged. CRLF-to-LF compiler transport is recorded explicitly. Preparation
never substitutes an unadopted dependency emission for the cached creation owner.

For a selected cohort, repeat `--host test/path.t.sol:ContractName` to bind
every executed host explicitly. Missing selected hosts fail preparation; the
presence of another cached suite cannot stand in for them. `--host` and
`--campaign` are mutually exclusive. A build without full build-info or ASTs
must be rebuilt with the current profile before preparation; granting file
permissions alone cannot recover that compiler evidence. Selected code-generation
captures may instead bind their separate full-source analysis and native AST
outputs with `--compiler-capture BUILD_ID=PATH`; follow the
[selected compilation procedure](reference/tooling/scoped-codegen.md). The adapter
retains the actual native input identity and leaves Forge artifacts unchanged.

This requires no machine-specific snapshot directory. Re-run preparation after
rebuilding changed contracts or graph fixtures. Its command lock protects the
projection write; finish other builds before preparing or testing the same
output directory. The current profile's large aggregate fixture limits cover
many deployments and calls. Native product checks still enforce the 24,576-byte
runtime limit, and the fixture checks constructor and deployed products; these
local allowances do not establish a shipping transaction's gas capacity.

### Explicit native product owners

A fixture that obtains creation bytes through `vm.getCode` can keep the default
command after a normal full build when every projection product and literal
artifact target is physically cache-owned by the creation library's context.
The command detects actual `getCode` calls in the native creation-library AST,
requires exact physical/current executable equality, and authenticates the added
source/import closures. Differently owned products require an explicit owner
manifest. Use a completed, unchanged out/cache pair for each owner:

```text
python -m tools.build.prepare_current_graph --project PATH --products PRODUCTS.json --host test/current/Suite.t.sol:SuiteTest --owners OWNERS.json
```

The version-1 manifest has exactly `version`, `contexts`, and `owners` fields.
`contexts` maps local labels to these required strings: `out`, `cache`, `buildId`,
`compilerCapture`, `buildInfoSha256`, `nativeInputSha256`, and
`nativeOutputSha256`. An optional `compilerAdmission` binds an existing explicit
readmission receipt for the default `scoped-paired` capture kind. For a retained
native partition, set `captureKind: partition-native` and `partitionProvenance`
to an explicit provenance descriptor; `compilerAdmission` is forbidden. The
descriptor pins the original partition plan/index/record and its exact original
parent analysis. This intake validates the partition's own raw `input.json` and
`output.json`, own native AST and exact Forge envelope transport. Analysis ASTs
remain separate. It does not rename original captures, create scoped records,
merge outputs, or infer current-source acceptance. The loader, exporter and
projector use this explicit discriminator throughout. Paths resolve relative to the manifest. The three digests
are SHA-256 of the original raw full build-info file, `codegen-input.json`, and
`codegen-output.json` (or `input.json`/`output.json` for a native partition);
they are not hashes of reserialized JSON. `owners` maps
exact `smart-contracts/path.sol:Name` or `test/path.sol:Name` coordinates to labels.
Each selected host, creation helper, projection product, linked library, concrete
embedded-construction dependency, and literal artifact coordinate in their
transitive source closures needs an owner. All literal catalog entries are
included conservatively, even if one selected test does not execute that entry.
Abbreviated artifact paths and duplicate JSON keys are refused.

Each context binds the genuine paired compiler capture, original Forge envelope,
cache-selected physical artifacts, source/import closure, metadata, ABI, storage,
bytecode, links, and native immutable declarations. Contexts require the current
via-IR Paris optimizer-200 profile, metadata without CBOR/hash, no prelinked
libraries, and identical remaining settings except `outputSelection`. Identities
include absolute evidence paths and raw hashes: equal short Forge build IDs do
not make two contexts interchangeable. The original capture, out and cache files
are rechecked and remain unchanged; managed destinations cannot overlap them.

Flat projections require every referenced immutable declaration and projected
inheritance ancestor, including intermediate bases, to have the same owner as
the product. Embedded concrete constructor dependencies also require that owner;
`getCode` targets may have their own owners. Bound analysis ASTs may discover
source paths and unprojected ancestors, but never supply runtime fields or
immutable projections. Missing native declarations and conflicting shared parent
owners fail before projection. Keep any additional declaration files passed to
the runtime reader in the same context; its existing compilation-hash check
still rejects unrelated mixed-context files.

The resulting manifest records `artifactInputKind: current-native-export`, full
owner identities, per-context reports and per-product projection bytes/hashes.
It deliberately has no synthetic single compiler identity. Every emitted
production runtime in each selected context still faces the original 24,576-byte
limit, including outputs outside the projection list. This command does not
construct a merged Forge cache or execution view, compile Solidity, deploy
contracts, check constructor argument capacity, or establish runtime/release
acceptance. A separate execution harness must preserve and bind the actual
physical owner used by every `getCode` lookup. Python assertions must be enabled.

### Native execution views

The canonical preparer accepts explicit non-test roots with repeatable
`--entrypoint test/helpers/Scenario.sol:Scenario` or `script/current/Run.sol:Run`.
These roots receive the same native ownership, source, import, executable and size
checks as hosts. They are not test cases. For an ordinary suite without the graph
creation helper, use `--owners-only`, explicit hosts/entrypoints, and an empty
`--products` JSON object. This exports and checks every assigned owner through the
same exporter/projector, but does not require `StreamNativeAssemblyCreation` or
write flat graph projections.

Prepare a separate execution cache after canonical preparation:

```text
python -m tools.build.current_native_execution_view --project PROJECT --products PRODUCTS.json --owners OWNERS.json --preparation PREPARATION.json --preparation-sha256 SHA256 --destination NEW_VIEW --host test/current/Suite.t.sol:SuiteTest
```

The view reauthenticates the original captures and physical/cache ownership and
checks the pinned canonical preparation, native exports and projections. It
requires the complete literal artifact inventory, actual native library links
(including address-only library references) and embedded construction owners.
Sources, standard fixture directories, configuration, tools and original native
evidence are hashed and rechecked. Add other input files/directories with
`--input PATH`. No source or original native output is rewritten.

Each physical artifact and original full build-info file is copied byte for byte.
Only cache routing is derived. Unassigned source-only cache rows are retained only when their original literal
source bytes and full transitive import closures match the current project. Their
artifact maps remain empty, and their current raw source hashes are sealed with
all other inputs. Stale/unknown rows stay absent, so the deny-compiler gate refuses
a rebuild rather than inventing an artifact.
Build-info filenames and cache `build_id` values
use full owner identities so colliding short Forge IDs cannot combine source-ID
maps. Forge reads these files as separate build contexts; their original embedded
IDs and compiler fields remain untouched. The derived cache is never compiler
evidence. Case-insensitive artifact path collisions are refused. Rechecks allow
only JSON representation and known path-separator transport in the derived cache;
all routing values, profiles, source hashes and artifact inventories remain exact.
Forge output intake also permits omission of native `generatedSources: []` and
`functionDebugData: {}` only when empty. Nonempty/changed debug fields, code,
links, immutables and source IDs still fail.

By default cache profiles and source layouts must match. An explicit
`--routing-context LABEL --routing-profile PROFILE` uses that original context's
cache profiles and test/script paths. Every selected artifact's original profile
and actual native input must match the target Solidity settings apart from
`outputSelection`; source paths and cache format must still agree. Library search
roots may differ only with a recorded proof that no original native input source
lies beneath a changed root and every import in every authenticated source is
literal relative syntax resolving to the same pinned source path and SourceUnit
ID. Missing ASTs, external/package imports, unresolved imports and used changed
roots refuse the transport. The proof is recorded outside the derived cache;
original sources, native outputs and caches remain untouched. This
is execution routing only, not replacement compiler output or proof of cache use.
A cached listing with the compiler disabled must succeed before runtime use.

```text
python -m tools.development.run_native_execution_view --view NEW_VIEW/execution-view.json --view-sha256 SHA256 --forge FORGE --forge-sha256 SHA256 --chain-id 31337 --destination NEW_LISTING
```

Omitting `--execute` only lists the exact complete native ABI case roster. The
runner rejects compilation, inherited environment filters, missing/extra cases,
artifact/source/cache mutations, RPC/fork configuration and unsupported
helper-only execution. The caller explicitly pins local chain 31337; the runner
records and verifies Forge's effective numeric or `anvil-hardhat` representation
and requires the original non-isolated mode. With
`--execute`, it runs each complete test host with 256 fuzz inputs and seed
`0x6529`, retains process and result evidence, and checks the original current
profile's 10-billion gas, 1-GiB memory and 2-million test-code limits. Production
runtime/base-init limits remain 24,576/49,152 bytes; constructor arguments,
actual CREATE/runtime/link values and protocol acceptance need separate trace
validation. An explicit `--verbosity 4` or `--verbosity 5` retains successful
setup/test traces for an independently checked campaign. This is not enabled by
default. Fuzz traces represent retained executions, not every generated input.
A listing is not EVM or `getCode` runtime evidence.

Forge script dispatch is deliberately unsupported. Its dependency-only linker
can leave dynamically obtained products unlinked even when the same cached test
works. Authenticating a helper/script entrypoint does not establish an RPC
execution view or deployed library prestate.

### Scoped acceptance captures

To test a coherent graph increment while other work continues, capture a fresh
import closure and run selected suites in its isolated project:

```text
python -m tools.development.run_current_acceptance --artifacts artifacts/current-graph/my-acceptance --host test/current/StreamCurrentStack.t.sol:StreamCurrentStackTest --host test/current/StreamCurrentSafe.t.sol:StreamCurrentSafeTest
```

The runner copies exact working-source bytes and data fixtures, records their
hashes and source commit, then compiles with the current via-IR profile. It
authenticates every named host with canonical graph preparation before running
tests. `--solc` can select an already-installed native Solidity 0.8.19 executable.
The source/configuration capture, full native compiler output, preparation log,
production size inventory and actual test results remain in the new directory.
Existing capture directories are never reused or overwritten. Unrelated Solidity
data fixtures are excluded from the selected import closure.

The run uses one Forge worker, seed `0x6529`, 256 input-fuzz runs and 32 invariant
sequences of depth 64. It fails on missing suites, empty results, failed or skipped
tests, incomplete property budgets, altered captured inputs/native artifacts
and oversized production products. Expected cases come from each authenticated
host ABI; configured test/path filters are rejected. Select the
separate [campaign](#reproducible-fuzz-and-invariant-campaigns) command for extended
budgets and retained-counterexample replay. A captured source may contain local
edits; its file hashes identify the tested source more precisely than Git HEAD.
This scoped run does not establish full-v1, collector-gas or release acceptance.

## Pick the relevant tests

The new [artist operation extension](architecture/artist-operation-extension-v1.md)
has a separate design check: `python -m tools.protocol.check_artist_operation_extension`
and `python -m tools.protocol.test_artist_operation_extension`. It preserves the
historical 57-operation packets and derives the additive 58-row inventory.
Its implementation gate remains closed until matching source and execution
evidence exist; it is not a substitute for the current test suite.

The adopted recovery continuity extension has its own current check:
`python -m tools.protocol.check_artist_owner_record_continuity_extension` and
`python -m tools.protocol.test_artist_owner_record_continuity_extension`. It pins
the four historical packet/schema/checker/test files and verifies the current
operation-35 occurrence and owner vectors. These checks do not accept a release.

The three frozen artist-57 design gates use the accepted RC1 Git tree
`569bf87f1fa808787d324f6e1582924b5ccf1d40`. Run them with
`python -m tools.protocol.run_frozen_artist_checks matrix`, `reconstruction`,
or `continuity`. The runner first verifies that the frozen packets, schemas,
checkers and tests in this checkout still match that baseline. It then runs
the historical tests and checker in a temporary Git archive and removes it.
This preserves historical evidence while allowing the current specification
to evolve. A missing baseline Git object is an error; use a full clone or fetch
the published `testnet/current-rc-1` tag before running these gates.

Make, both aggregate shell wrappers and CI label these checks as historical.
Current contracts, the effective 58-operation design, source layout, ABI,
admission, provenance and release checks continue to use the active checkout.
A historical pass provides no current implementation or release acceptance.

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

Input fuzzing varies arguments to the `StreamCurrentStackFuzzTest`
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
pair. Before execution, the command compiles/lists the exact two campaign hosts
and prepares their graph inputs from that cache. `compile.log` and
`prepare-graph.log` retain those steps; a failed preparation executes no properties.
The report binds the resulting projection manifest and checks it again afterward.
A checkout-wide campaign lock protects the shared graph fixture paths, so run
parallel campaigns in separate worktrees. Do not rebuild or prepare graph inputs
in a checkout while its campaign is running. `--reuse-current` saves a cold build by
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

The [current sale conservation campaign](testing/current-sale-conservation.md)
documents the handler's required opening sequence, independent payer and
Ledger counter models, cancellation transitions and late-mint rollback checks.
Its expanded source remains native-pending until the frozen current-graph run.

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
