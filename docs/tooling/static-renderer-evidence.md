# STATIC renderer analysis and golden evidence

`tools.metadata.static_renderer_evidence` provides a conservative Paris-bytecode
interpreter and checks the original Renderer Registry ABI documents. It fills an
offchain tooling gap; it does not register a renderer or change a protocol rule.

The requirements remain [MRR-DETERMINISM](../metadata-router-and-renderer.md#renderer-determinism)
and [ADR 0010 D4](../adr/0010-world-class-spec-pass.md#d4-permanence-hardening).
The Registry's `Analysis` document is an attributed assertion. The Registry
checks its exact bindings and runs its golden vectors; neither its `passed`
field nor a successful fixture registration proves transitive opcode closure.

## Run the bounded analysis

Use the repository's existing Python tools environment, which includes
PyCryptodome. No new dependencies, Solidity build, node, RPC or EVM are needed.

```text
python -B -m unittest tools.metadata.test_static_renderer_evidence -v
python -B -m tools.metadata.static_renderer_evidence --analyze-only analysis-input.json
python -B -m tools.metadata.static_renderer_evidence packet.json
```

Exit `1` means malformed or inconsistent supplied evidence. Exit `2` means
the analyzed program is refused or analysis is incomplete. Exit `0` means the
specified-entry opcode/read/copy subset is closed and the supplied golden
recomputations match. **Exit zero is not renderer admission or release approval.**
The command never writes an `Analysis(passed=true)` document or updates expected
golden hashes. Its JSON result always retains the unproved obligations.

`--analyze-only` needs no external `Analysis` document or golden result. Its
input has exactly `runtimes`, `entries`, and `reads`. `runtimes` maps lowercase
addresses to concrete runtime hex. Each entry is
`{address,selector,calldataBytes}`. Each read is
`{target,selector,maxReturnBytes,exact}`, using the original read declaration
with its target index resolved to an address. This is a local analysis input,
not an additional registered protocol artifact. All supplied identities still
need independent deployment/source provenance.

The interpreter starts at bytecode offset zero with the exact entry selector,
fixed calldata length and otherwise unconstrained argument bytes. Calls are
zero-value STATIC serving calls. It keeps constant/partially known 256-bit
stack values, initially zero memory and unknown storage, caller and chain ID.
Known selector bits survive ordinary `CALLDATALOAD`/`SHR` dispatcher patterns.
Every unknown conditional branch is explored; no sample trace or supplied
reachable-PC list removes paths. A known invalid jump or stack error halts
that path as it does in the EVM.

At each `STATICCALL`, target and input selector must resolve and match an exact
declared read. The callee's entire reachable path is analyzed with its actual
pinned runtime and abstract input bytes, including further calls. The callee's
return bytes, return length and success flag remain unknown in its caller.
This avoids assuming that an allowed target obeys its declared return bound.
Fixed automatic output copies and later `RETURNDATACOPY` lengths are checked
against the read cap in aggregate. This is deliberately conservative: copying
the same bytes twice still spends the aggregate bound.

The result contains exact Keccak runtime pins, analyzed entries, resolved
transitive edges, reachable instruction count, state/context counts, limits,
and precise unresolved/forbidden program counters. `CLOSED` establishes only
the named entry inputs' reachable opcode/read closure and supported bounded
returndata copies, under the supplied runtime identities. `REFUSED` identifies
a forbidden opcode/read on a possibly reachable abstract path; correlations
discarded by abstraction can cause conservative refusals. It is not by itself
proof that a transaction reaches that instruction.

Unsupported patterns return `INCOMPLETE`, including dynamic jump/call targets,
unknown memory/copy ranges, and a `GAS` instruction whose permitted bounded-call
precheck is not proved by this implementation. There is no caller-controlled
exception list. Paris-unsupported opcodes also refuse closure. State, context,
per-frame memory and cumulative memory exploration limits are local tool
bounds, not protocol or transaction cap changes. No exhausted bound is a pass.

This first supported subset can close fixed dispatcher and fixed STATIC call
graphs. It does **not** yet close the current complete renderer graph: original
`StreamRendererCalls` uses `GAS` prechecks and size-dependent return copies, and
those patterns require further proof support. Preserve an incomplete result
and its pins; do not remove that code or skip a transitive target to make it pass.

## Original Registry packet

The local packet is a transport for existing bytes, not a new registered schema
or mandatory governance artifact. It has exactly these fields:

| Field | Content |
| --- | --- |
| `version` | Integer `1` |
| `renderer`, `rendererRuntime` | Lowercase address and concrete deployed runtime hex |
| `rendererVersion`, `contextVersion`, `schemaHash` | Original nonzero bytes32 pins |
| `maxJSONBytes` | Original manifest uint32 output bound |
| `targets` | Original sorted target roster, each `{address,runtime,role}` |
| `reads` | Original sorted `{targetIndex,selector,maxReturnBytes,exact}` records |
| `analysisPayload` | Exact 320-byte `abi.encode(IStreamRendererRegistry.Analysis)` |
| `goldenPayload` | Exact `abi.encode(IStreamRendererRegistry.GoldenVector[])` |
| `recomputations` | One or more supplied recomputation sets described below |

All bytes use lowercase `0x` hex. Integers are JSON integers, never booleans or
floats. Duplicate/unknown fields, unresolved link placeholders, conflicting
runtime identities, malformed ABI padding, noncanonical booleans/enums and
out-of-range original bounds are refused. Inputs have a local 128 MiB file
bound. Original runtime EIP-170 bounds are retained.

The target hash is `keccak256(abi.encode(targets))`, using each supplied
runtime's Keccak code hash. The read hash is exactly
`keccak256(abi.encode(keccak256("6529STREAM_RENDERER_READ_SET_V1"), targetSetHash, reads))`.
The checker joins those values and the renderer/runtime/version/context/schema
to the original Analysis payload. Its nonzero tool/findings hashes and `passed`
boolean remain **external assertions**, never proof supplied by this tool.
Role qualification, source/deployment authenticity and governed registration
still belong to their original admission procedure.

Each recomputation has exactly `label`, `stateHash`, and `results`. The label is
a unique local identifier; `stateHash` is the supplied nonzero identity of the
declared-read state. Each result has exactly `calldata` and `returnData`, in the
same order and count as the golden vectors. Calldata must equal the original
`tokenURI(RenderRequest)` selector and all twelve request words, retaining the
full uint256 token ID. Return data must be a canonical single ABI string, within
the Registry's unchanged base64 URI bound. The Keccak of its raw string bytes
must match the original vector's output hash. Expected bytes never come from
the supplied result. All vectors must match in every supplied run.

This comparison authenticates neither an RPC server nor execution. A caller
can fabricate an internally consistent packet, so `executionVerified`,
`deploymentVerified`, `registeredAnalysisClaimVerified`, and `admissionReady`
remain false. Retain genuine native/deployment and recomputation evidence from
the existing ceremony separately. The CLI analyzes the original renderer's
`tokenURI` input family; `routerPathsAnalyzed` remains false. The Python
`analyze(runtimes, entries, reads)` API can name additional fixed-length Router
entries, but its result covers only those explicitly listed input families.

## What remains independent

Even a closed opcode/read graph does not establish semantic determinism,
correct fixed/dynamic ABI failure handling, artwork JavaScript behavior,
Registry authority, source immutability, actual deployment, browser execution,
currentness, transaction gas capacity or complete Router coverage. In
particular, the original opcode allowlist is not a proof that permitted
`CALLER` or `CHAINID` values cannot influence output.

The tests use hand-assembled Paris programs and literal original ABI envelopes.
They exercise successful three-runtime closure, forbidden transitive reads,
dead code/PUSH data, unresolved targets/jumps, partial selector bits, copy
limits, hostile JSON, full-width requests, repeated recomputation drift, and
canonical golden decoding. They are meaningful controls for this tool and
**are not genuine current-renderer golden or deployment evidence**. Existing
metadata-format checks and existing onchain golden tests remain unchanged.
