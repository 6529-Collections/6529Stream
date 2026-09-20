# Selected code generation with Solidity 0.8.19

This maintainer tool separates whole-source analysis from selected bytecode
generation. It is opt-in; ordinary builds and small complete-source leaf tests
can keep their normal Forge path. It does not change contracts, test cases,
compiler optimization, deployment limits or transaction budgets.

## Why separate the requests

Solidity 0.8.19 interprets `"*": {"": ["ast"]}` as an all-contract selection
when another output requests binary compilation. Restricting the serialized
contract outputs alone therefore does not restrict the code-generation work.
The relevant pinned source is Solidity commit
`7dd6d404815651b2341ecae220709a88aaed4038`:

- [StandardCompiler.cpp, requestedContractNames](https://github.com/argotorg/solidity/blob/7dd6d404815651b2341ecae220709a88aaed4038/libsolidity/interface/StandardCompiler.cpp#L152)
  maps source/contract selectors without filtering their requested fields.
- [CompilerStack.cpp, isRequestedContract and compile](https://github.com/argotorg/solidity/blob/7dd6d404815651b2341ecae220709a88aaed4038/libsolidity/interface/CompilerStack.cpp#L643)
  interprets the empty contract key as a wildcard.
- [CompilerStack.cpp, generateIR](https://github.com/argotorg/solidity/blob/7dd6d404815651b2341ecae220709a88aaed4038/libsolidity/interface/CompilerStack.cpp#L1357)
  also follows actual creation-code dependencies.

The repaired requests retain the complete identical literal source universe and
all settings except `outputSelection`:

1. Analysis requests only `{"*":{"": ["ast"]}}`; it produces no bytecode.
2. Code generation names exact source/contract outputs and requests AST only in
   those selected source files. An explicit output for an immutable declaration's
   source is required, including inherited bases.

Per-file AST still schedules every co-resident definition in that file. Embedded
`new`/`type(...).creationCode` dependencies still generate code. The verification
report lists both the scheduled definitions and their AST dependency closure.
These are scheduling facts, not a measurement of elapsed-time savings.

## Standalone retained pair

Prepare a standard JSON input and a separate selection file. For example:

```json
{
  "smart-contracts/Example.sol": {
    "Example": ["abi", "metadata", "storageLayout", "evm.bytecode", "evm.deployedBytecode", "evm.methodIdentifiers"]
  }
}
```

Use the actual installed compiler's SHA-256 and a new task-owned directory:

```text
python -B -m tools.build.scoped_standard_json capture --input input.json --selection selection.json --solc /path/to/solc-0.8.19 --compiler-sha256 ACTUAL_SHA256 --output out/selected-capture --timeout 60
python -B -m tools.build.scoped_standard_json verify --capture out/selected-capture
```

The timeout applies separately to each native pass. The tool records the exact
requested input, both native inputs, unmodified compiler stdout/stderr, executable
hash, version output, process IDs, exit statuses and durations. A directory is
single-use; timeout, interruption, compiler error or evidence mismatch refuses
acceptance. The native process is killed and reaped on exceptional exit.

Verification checks all source IDs, selected ASTs, requested output fields and
immutable-reference ranges. Every immutable ID must resolve in the bytecode
pass's own AST, even when the analysis output contains the missing declaration.
Analysis ASTs are never spliced into native output. Bytecode selections must emit
both creation/runtime objects, their link references and runtime immutable
references; the abbreviated compound selectors above include those fields.

## Forge forwarding and canonical preparation

For an isolated captured project, make its compiler launcher invoke:

```text
python -B /path/to/tools/build/scoped_standard_json.py forward --manifest /path/to/manifest.json -- COMPILER_ARGUMENTS
```

The launcher forwards Forge's arguments verbatim. Its manifest must contain:

| Field | Required binding |
| --- | --- |
| `compiler`, `compilerSha256` | Exact native executable and SHA-256 |
| `compilerArguments` | Exact argument array, including project paths and `--standard-json` |
| `sources` | Every requested source name mapped to SHA-256 of its UTF-8 compiler content |
| `settingsWithoutOutputSelection` | Exact requested compiler settings other than selection |
| `expectedOutputSelection` | Exact selection sent by Forge |
| `actualOutputSelection` | Explicit source/contract output map for the bytecode pass |
| `captureDirectory` | New task-owned directory |
| `timeoutSeconds` | Bound for each native pass |

Version probes do not consume the single native capture. A second standard JSON
invocation refuses to overwrite it. The shim returns only the bytecode pass's
unchanged native stdout. Preserve the original Forge build-info and cache: Forge
records the request it sent, while the capture records the actual native request.
Those are intentionally distinct and individually hashed.

After that build completes, identify its actual cache-selected build ID and bind
the capture explicitly during preparation:

```text
python -B -m tools.build.prepare_current_graph --project /path/to/project --host test/current/Example.t.sol:ExampleTest --compiler-capture BUILD_ID=/path/to/capture
```

Repeat `--compiler-capture` for separately captured selected compiler contexts.
Unknown IDs, stale sources, changed captures or unbound outputs fail. The adapter
recognizes and records only the observed empty-field serialization in pinned
Foundry 1.7.1: added empty AST children/AST objects and documentation objects,
omitted empty immutable-reference maps and storage layouts, and null-to-empty
storage-layout type maps in physical artifacts. Source IDs, nonempty AST content,
layouts, bytecode, links, immutable ranges and all other fields remain exact.

Full analysis supports transitive import/source checks only. Native exports and
projections retain the bytecode pass's own AST and actual input hash; physical
artifacts remain authenticated against their cache-selected owner. The existing
embedded-image, real CREATE, deployed-runtime and production-size checks are
unchanged. This tool does not establish that a selected output inventory includes
every product needed by a particular campaign; retain its existing inventory and
all original assertions.

## Validation and limits

```text
python -B -m unittest tools.build.test_scoped_standard_json tools.build.test_prepare_current_graph tools.build.test_native_artifact_storage tools.development.test_current_acceptance
```

Synthetic tests exercise refusal and process cleanup. A separate bounded native
proof used six sources and four contract outputs with an inherited immutable,
embedded child creation code, public-library linking, an unselected co-resident
sibling and an imported source with analysis-only AST. Broad/scoped bytecode
requests produced identical complete selected contract outputs; canonical Forge
preparation succeeded without changing original build-info/cache/artifacts.
This small proof does not validate a full current graph, establish a speed ratio,
or authorize repeating a previously timed-out large capture. Freeze and approve
one coherent current campaign separately before its native run.
