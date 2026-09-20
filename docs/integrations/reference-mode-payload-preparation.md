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

## Authenticated carrier adoption

Native9 completed five cases and failed the four publication-dependent cases.
The actual host's publication and payload preparation calls fit their bounded
envelopes at 13,014,534 and 13,677,086 gas including intrinsic gas. Final
publication still exhausted its call budget while reading the already prepared
443,648-byte payload after fresh source and evidence validation. The trace's
selector decoration was an out-of-gas failure, not a missing interface. The
failed capture remains evidence of that unresolved complete-flow boundary.

The successor preserves the unchanged public workflow above. A fixed write
worker performs the original current source and evidence checks, then derives
the preparation IDs from the actual full Publication and newly validated
receipt, source, evidence and mode facts. A match yields an internal descriptor;
the external publication call still accepts no descriptor or preparation ID.
The old preview, currentness and complete-byte readers remain unchanged. A miss
still uses the original monolithic formatter and retention path.

For a match, the mutation path verifies the saved publication, environment and
payload in that order. It checks every ordered pointer's exact byte length,
STOP prefix and chunk hash, and recomputes each complete byte commitment. Both
adopted manifests additionally require the original pinned Store's exact
pointer and length for each chunk. Only then are the original pointers and
chunk hashes copied into the original record's compiler-owned manifests. The
payload bytes are never returned through the worker/host ABI or retained a
second time. Original public getters still reconstruct the same complete
bytes; receipt, record, chain, history and event preimages remain unchanged.

The carrier verifier performs all checks before copying a destination manifest,
instead of interleaving each original Store check with a pointer push. The
Store lookup is read-only, and the publication guard remains held throughout.
A later failure rolls back both manifests and every record mutation. Existing
destinations cannot be replaced. No authority, live dependency or currentness
fact is cached, and neither a claimed ID nor a whole-byte hash alone suffices.

The 132-source ABI check preserves all 98 public host ABI entries and all 16
recursive storage rows exactly, with no appended state. The original complete
Preparation worker is byte-identical to the preceding commit. Five selected
production products fit: manifest adoption 1,793 bytes, payload preparation
17,854, original preparation 23,760, write preparation 18,925 and publication
24,562. The publisher has only 14 bytes of measured runtime headroom; this is
not an allowance for further unmeasured host features. The first experiment
placed both output codecs in one worker and exceeded its size limit; it was
retained as a failed measurement and replaced by the separate fixed writer.

The frozen focused successor passes 14 tests, including two 256-input fuzz
cases. The four new tests cover exact original payload/publication bytes,
changed source/recorder/report/host/chain inputs, ordered chunk and whole-hash
substitution, length/STOP/byte corruption, and late failure followed by the
identical retry. For the 1,048/102 corpus plus a 13,000-byte URI used to exercise
full and short carriers, minimal-host adoption consumes 11,284,045 gas including
calldata and transaction intrinsic gas under the unchanged 16,777,216 envelope.
The retained original stage tests also pass at 12,915,523 and 13,461,574 gas.

Those measurements cool the named host, Store and payload carriers. They do not
prove every transitive dependency is cold. Actual-publisher successor results
remain separate: minimal-host adoption does not itself establish the complete
writer/source, supplement, Safe retry, lock or inventory flow, nor current-head
deployment capacity. The large aggregate harness gas includes many individual
uploads and preparatory calls; it is not a single proposed transaction.

## Immutable carrier bindings

Native10 preserved the genuine native5 context and the exact predecessor graph,
with only the reviewed manifest-adoption overlays. Five cases passed and four
publication-dependent cases failed. Both actual-host preparation stages fit at
13,014,541 and 13,677,066 gas including intrinsic gas. The first publication
still exhausted its budget inside manifest adoption after all 55 Store lookups
for its 443,648-byte payload. The second, 254,464-byte publication manifest had
not yet been adopted. This call-level trace does not identify the final opcode;
the complete operation still required copying every pointer/hash pair into
fresh storage. The failed capture is retained, not replaced by the smaller
worker's passing result.

The successor appends one compiler-owned mapping from the accepted record hash
to its immutable publication and payload preparation IDs. It writes those two
IDs only inside the original authorized publication transition. It first
performs the unchanged fresh input/source/evidence validation and the same
publication, environment and payload integrity checks. The payload and original
publication must both retain the pinned Store's exact pointers and lengths,
STOP prefixes, ordered chunk hashes and complete byte hashes. A claimed ID is
never an external publication argument. Existing bindings and mixed binding /
legacy destinations reject instead of replacing a prior record.

Preparation cannot mutate a bound carrier: an existing publication ID checks
its exact descriptor and bytes, while an existing payload ID checks its bytes
and returns without writing. The original chain/host/full-component identities
remain unchanged. A new preparation under different inputs has a different ID;
it cannot redirect an accepted record's binding. Only the actual validated
publisher can create the binding, receipt and history entry atomically.

Every original record, payload, currentness and metric-supplement reader uses
the same private typed storage-reference selectors. A completely zero binding
selects the original monolithic maps. A complete binding selects the original
prepared manifests. Partial bindings and mixed legacy/bound manifests reject.
Receipt/head/lock guards and byte-integrity reads stay at their original call
sites; there is no caller-provided root or external routing target. All earlier
storage rows and the public ABI are preserved; the new mapping is appended.

The host's three complete Publication encoders move to its existing fixed
StateReads worker: original record hashing, the original mode-context getter,
and the monolithic publication retention branch. Each accepts only its exact
original selector and decodes the same original Publication. Record hashing
uses the actual delegate host, original chain/Core/Metadata and complete
receipt. Fallback retention still uses the original Store and byte manifest
reader/writer. No output, domain, authority, currentness or gas cap changes.
The original complete preparation and live write-validation workers are
unchanged.

Focused regressions compare mixed legacy and bound records, reject changed
scope/source/recorder/report/host/chain inputs, prove idempotent preparation
cannot replace accepted bytes, and cover partial/mixed bindings, chunk order,
whole hash, code length, STOP and data corruption. A failure after binding must
roll back both IDs and record acceptance before an identical retry. Independent
literal record/context preimages cover empty and nonempty dynamic rows; the
fallback test compares exact bytes after a missing-chunk failure and retry.
The 1,048-row corpus is measured separately with named host/Store/carrier
cooling and calldata/intrinsic accounting. These worker recipes do not establish
actual publisher authority, supplement/lock/inventory capacity or an RPC anchor.
The final selected gate fits all four affected products: publisher 22,688 bytes
(runtime) / 27,083 bytes (creation), fixed StateReads 8,457 / 8,492, payload
preparation 18,469 / 18,503 and manifest verifier 2,085 / 2,120. The 132-source
ABI check preserves all 98 host entries and all 16 earlier recursive storage
rows; the new binding mapping starts at slot 42. The original complete
Preparation and live WritePreparation workers are byte-identical to the prior
adoption commit. Two earlier over-limit host size gates are preserved. The
focused frozen runtime capture is separate from these source and size results;
actual publisher/Safe/supplement/lock/inventory acceptance remains pending.
