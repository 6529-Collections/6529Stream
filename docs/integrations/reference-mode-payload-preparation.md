# Staged reference-mode payload bytes

`IStreamReferenceModePayloadPreparation` adds immutable byte preparation to
`StreamReferenceModePublication`. It preserves the original mode record,
context, source, payload and chain domains. Preparation accepts no Artist,
writer, archival coverage, metric execution, or finality authority.

The motivating retained workload has 1,048 package files, 102 platform
prerequisites, a 252,096-byte Environment ABI and 179,418 canonical environment
bytes. Native8 still failed real publication within its transaction envelope.
An isolated exact-byte projection experiment passed four parity cases and 256
fuzz inputs, but its formatter transport still used 22,099,303 gas and its
inlined preparation worker was 27,999 bytes. Those results remain failed
capacity evidence, independently of this successor.

## Ordered workflow

1. Prepare the original file inventories and exact Environment using the
   existing staged inventory/environment interfaces. Uploads remain individual
   original Store chunks of at most 8,192 bytes.
2. Read `previewModeReference` for the intended original writer. This is an
   `eth_call`, not a claim that preview computation fits an onchain transaction.
   Canonically decode the original seven-field mode payload and retain every
   returned field. In particular, its complete Publication contains the newly
   computed `expectedSourcesHash`; use that same full Publication for subsequent
   preparation and publication.
3. Upload all chunks of `abi.encode(publication)`, then call
   `prepareModePublication(publication)`. The producer independently encodes
   the full typed input and requires its exact, previously authenticated
   Environment. It returns a publication preparation ID.
4. Upload all chunks of the original canonical payload, then call
   `prepareModePayload(publicationPreparationId, receipt, source, evidence, facts)`.
   These are the original typed components from the preview. The producer uses
   its immutable original publication and environment bytes to assemble the
   complete original ABI payload. Every final chunk must exist and match.
5. Use the unchanged `publishModeReference(publication, evidence)` entrypoint.
   It does not accept a preparation ID. It checks the original candidate,
   current writer, definitions, live source, evidence and expected source hash,
   and independently derives the expected byte preparation identity. A staged
   payload is used only when all those original components match exactly.

Both preparation calls are permissionless and guarded against reentry. A late
missing or altered chunk reverts the entire preparation transaction. An intact
repeat returns the same ID and emits no new event. Existing entries cannot be
replaced. The original monolithic path remains available on a cache miss; its
large-workload capacity limitation remains explicit.

## Exact identities and encoding

All hashes below use `keccak256(abi.encode(...))`. `chain` is `block.chainid`
and `host` is the actual original publication host in delegate context.

The publication ID contains, in order:

- `keccak256("6529STREAM_REFERENCE_MODE_PUBLICATION_PREPARATION_V1")`
- `chain`, `host`
- `keccak256(abi.encode(publication))`, `uint32(abi.encode(publication).length)`

Its compiler-owned descriptor retains that hash and length, the original
input-derived Environment preparation ID, and its canonical hash and length.
The descriptor is constructed only after the exact Environment entry is
authenticated. It cannot be submitted independently by a caller.

For the payload identity, normalize exactly the five receipt fields normalized
by the original payload encoder: `recordHash`, `recordChainHash`, `payloadHash`,
`payloadBytes` and `recordedAt` become zero. All other receipt fields, including
the recorder and authorization class/grant revision, remain unchanged.

The payload ID contains the domain
`keccak256("6529STREAM_REFERENCE_MODE_PAYLOAD_PREPARATION_V1")`, then `chain`,
`host`, and a static `Components` tuple. That tuple contains a `bytes32` hash
followed by a `uint32` length for each of these six components, in this order:

1. `abi.encode(publication)`
2. `abi.encode(normalizedReceipt)` — exactly 640 bytes
3. `abi.encode(sourceFacts)`
4. `abi.encode(modeEvidence)`
5. `abi.encode(modeFacts)`
6. the original canonical Environment bytes

The complete output is still exactly
`abi.encode(REFERENCE_MODE_PAYLOAD_V1, publication, normalizedReceipt, sourceFacts,
modeEvidence, modeFacts, environmentBytes)`, using the original hashed domain.
The fixed assembler copies authenticated compiler encodings into its original
26-word head and ordered tails. It does not introduce a new payload schema,
exclude fields, or change padding. The original maximum is 524,288 bytes.

Schema-version-1 events are `ReferenceModePublicationPrepared` and
`ReferenceModePayloadPrepared`. Historical byte readers are
`preparedModePublication(id)` and `preparedModePayload(id)`. These readers prove
retained bytes, not current source acceptance or a completed reference record.

## Validation boundary

The staged draft has a clean 131-source ABI/type check. Its second selected size
pass fits the five affected nonempty production products: publication host
23,969 bytes, mode preparation 23,760, payload preparation 16,092, proof 17,209
and curated proof 16,327. All 92 original host ABI entries and 15 recursive
storage rows remain exact; one compiler-owned preparation State is appended.

The first focused capture passed seven cases and failed two. The full-inventory
payload finalizer exhausted its bounded call while retaining the already
assembled bytes; publication preparation's 10,802,236 execution gas was not a
complete transaction-envelope result. The other failure was a test-only
`vm.chainId` restoration error, corrected by retaining the original chain ID
in fixture storage. Both original failures remain recorded. The successor
retains the original chunk length, STOP, hash, error and write ordering while
using one local 8,193-byte scratch buffer. It avoids passing the complete
payload through another public-library ABI. Shared chunk storage and its
existing readers are unchanged.

The frozen successor passes ten focused tests, including two 256-input fuzz
cases. It covers original context and payload parity, immutable IDs, eventless
repeats, cross-host/chain refusal, missing Environment, missing final chunks,
and exact length/STOP/hash corruption rollback followed by identical retry.

For the 1,048-file and 102-prerequisite corpus, the small host's publication
preparation uses 12,915,482 gas and payload finalization uses 13,461,538 gas,
including each call's calldata and transaction intrinsic gas. Both calls are
bounded below 16,777,216. The complete original payload is 439,872 bytes. These
measurements use the real Store and fixed preparation workers with
compiler-owned mappings and named host/Store/output-carrier cooling. They do
not prove every transitive access is cold or measure the actual publication
host's complete writer/source checks. The high aggregate test gas also covers
many distinct uploads and setup operations; it is not one proposed transaction.

Actual publisher, current writer/source, Safe retry, supplement, lock and
inventory acceptance remain a distinct real-host capture. Its authored recipe
prepares both stages through the real host and preserves the original bounded
publication and final supplement calls. That retry retains the exact native8
dependency graph and genuine metric context, overlaying only this reviewed Mode
batch. It is not current-head or full-genesis acceptance. No passing formatter
or preparation test alone establishes that full flow.
