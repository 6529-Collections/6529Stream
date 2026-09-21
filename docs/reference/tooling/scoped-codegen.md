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
2. Code generation names exact source/contract outputs and requests AST for
   every literal source in the same native pass. Abstract ancestors and free-struct
   sources need no fictitious contract output. This default ensures inherited
   immutable declarations are present in the bytecode pass's own AST.

Per-file AST still schedules every co-resident definition in that file. With
all-source ASTs, internal compiler work can therefore cover the complete source
universe even though serialized bytecode outputs remain explicitly selected.
Embedded `new`/`type(...).creationCode` dependencies still generate code. The
verification report lists scheduled definitions and their AST dependency closure.
Keep a bounded timeout; do not claim this default reduces compile time.

A prior 416-source/150-product capture completed codegen but correctly failed
verification because three unselected abstract ancestors held inherited immutable
declarations. That failed output remains separate; its analysis AST cannot repair
the native output. New captures include every source AST upfront. The verifier
can still inspect an older explicit partial-AST request without adding declarations
or changing its original output selection.

A bounded campaign may instead use `--selected-source-asts` (or
`allSourceAsts: false` in the forwarding manifest). Its explicit selection must
include every product source, required constructor/library source and every
inherited immutable declaration source, proven from the full analysis before
code generation. Source-only `{ "": ["ast"] }` entries are valid. This policy is
recorded with the capture; same-native immutable checks remain mandatory and
missing declarations still fail. No fallback or automatic retry expands it.

Solidity's import traversal also depends on the requested source roots. In a
circular import graph, a source's `exportedSymbols` snapshot can differ between
the two requests even when every declaration, resolved identifier and other AST
field is identical. [CompilerStack::resolveImports](https://github.com/argotorg/solidity/blob/7dd6d404815651b2341ecae220709a88aaed4038/libsolidity/interface/CompilerStack.cpp#L1197)
cuts DFS cycles; [NameAndTypeResolver::performImports](https://github.com/argotorg/solidity/blob/7dd6d404815651b2341ecae220709a88aaed4038/libsolidity/analysis/NameAndTypeResolver.cpp#L71)
imports each scope once and snapshots its exported table immediately.

When selected ASTs differ only in that root table, verification independently
reproduces every analysis export table from all source roots and every selected
native table from the actual bytecode request's roots. Every table must match
exactly; all remaining selected AST fields must also match exactly. The bounded
model supports contracts, structs, enums, pragmas and named/bare/unit imports.
Other declaration kinds or conflicting declarations refuse this exception.
The report records both root lists and each predicted difference. Neither AST
is changed, and analysis declarations never replace native immutable evidence.

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
immutable-reference ranges. Every source-declared immutable ID must resolve in
the bytecode pass's own AST, even when the analysis output contains the missing declaration.
Analysis ASTs are never spliced into native output. Bytecode selections must emit
both creation/runtime objects, their link references and runtime immutable
references; the abbreviated compound selectors above include those fields.

The compiler also emits `library_deploy_address` for some library runtimes. This
is a generated self-address guard, not an AST variable. The verifier records it
separately, only for the exact selected library's same-native AST and a zero-filled
32-byte runtime site in a decoded `ADDRESS`/`PUSH32`/`EQ` instruction sequence.
Unknown identifiers, ordinary contracts and creation-code references still fail.
Pinned Solidity [Common.cpp](https://github.com/argotorg/solidity/blob/7dd6d404815651b2341ecae220709a88aaed4038/libsolidity/codegen/ir/Common.cpp)
names this field; [IRGenerator.cpp](https://github.com/argotorg/solidity/blob/7dd6d404815651b2341ecae220709a88aaed4038/libsolidity/codegen/ir/IRGenerator.cpp#L956)
assigns the deployed library's address and checks it in the runtime.

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
recognizes and records the observed serialization in pinned Foundry 1.7.1:
added empty AST children/AST objects and documentation objects, omitted empty
immutable-reference maps, method-identifier maps and storage layouts, and
null-to-empty storage-layout type maps in physical artifacts. It also accepts
top-level ABI entry permutations with exact entry contents and duplicate counts;
parameter/output order, nested arrays and JSON types remain exact. Native and
serialized ABI hashes record each permutation without changing either artifact.
Source IDs, nonempty AST content,
layouts, bytecode, links, immutable ranges and all other fields remain exact.

Full analysis supports transitive import/source checks only. Native exports and
projections retain the bytecode pass's own AST and actual input hash; physical
artifacts remain authenticated against their cache-selected owner. The existing
embedded-image, real CREATE, deployed-runtime and production-size checks are
unchanged. This tool does not establish that a selected output inventory includes
every product needed by a particular campaign; retain its existing inventory and
all original assertions.

## Admit a completed legacy capture without recompiling

An early version of this tool rejected generated library self-address fields or
request-dependent import snapshots after both native passes completed. The explicit
recovery path accepts only that exact legacy tool hash and one of those errors,
with both original passes complete at integer
exit code zero. It rechecks every retained file hash, input, output, source ID,
AST and immutable reference under the repaired verifier. Other failures remain
ineligible. The original directory, `FAILED` record and raw outputs stay unchanged.

Write a new receipt outside the original capture:

```text
python -B -m tools.build.scoped_standard_json admit --capture out/original-capture --receipt out/readmission.json
python -B -m tools.build.scoped_standard_json verify --capture out/original-capture --admission out/readmission.json
```

The receipt binds the original record and files, the current verifier bytes and
the fresh verification report. Ordinary verification still refuses the original
failed capture without this explicit receipt. Admission establishes native
evidence only; it does not establish artifact or runtime acceptance.

If the original Forge process received no compiler output, a one-use compiler
launcher can return the retained native stdout without invoking the compiler:

```text
python -B /path/to/tools/build/scoped_standard_json.py replay --capture /path/to/original-capture --admission /path/to/readmission.json --receipt /path/to/new-replay.json -- COMPILER_ARGUMENTS
```

Keep the same project paths, source bytes, Forge command and settings. Replay
requires the exact original compiler arguments and JSON-type-exact Forge request,
and writes an external receipt before forwarding untouched stdout/stderr. Version
probes use the retained version bytes. A standard-JSON replay receipt is single-use,
including when its output stream fails. Preserve the original Forge failure log;
retain fresh replay process evidence, then authenticate the resulting cache and
artifacts before any runtime test.

Pass `--compiler-admission BUILD_ID=/path/to/readmission.json` alongside the
matching `--compiler-capture` during canonical preparation. The native exporter
also accepts `--compiler-admission /path/to/readmission.json`. Both revalidate the
receipt, and reports preserve its hash and the original failed record identity.
Exact native library exports retain the generated reference. The graph projection
format still requires AST-declared immutables and explicitly refuses such library
products; this repair does not change the Solidity graph consumer.

## Validation and limits

```text
python -B -m unittest tools.build.test_scoped_standard_json tools.build.test_scoped_library_address tools.build.test_scoped_export_snapshots tools.build.test_forge_abi_transport tools.build.test_prepare_current_graph tools.build.test_native_artifact_storage tools.development.test_current_acceptance
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
