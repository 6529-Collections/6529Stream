# Current metadata work citation

This client plans the separate current-citation admission for an existing
renderer version, checks retained evidence and reads the admitted current output.
The original renderer registration, historical selectors and historical output
bytes retain their own profile. Admission is a one-time Governance V2 class-1
action; a version cannot replace its accepted current-citation record.

## Original work identity

The base citation has this exact form:

```text
eip155:<original chain ID>/erc721:<lowercase original Core address>/<global token ID>
```

Integers retain all 256 bits in decimal. The address has `0x` followed by forty
lowercase hexadecimal digits. Collection serials, Registry or renderer addresses,
and successor addresses do not substitute for the original work identity.
Formatting the citation makes no claim about the work's existence or authority.
The base form adds no snapshot, recovery, record-state or finality qualifier.

Current JSON places it at `properties.stream.citation`. The client does not
rewrite returned JSON, remote OFFCHAIN metadata or historical artifacts.

## Admission and serving

| Stage | Required evidence |
| --- | --- |
| New admission | Existing nondeprecated original version; no prior current admission; ACTIVE retained CATALOG analysis and golden documents; exact declared read roster and runtime bindings |
| Retained serving | Accepted immutable current record, retained original renderer, current declared target runtimes and encoder binding; `requireCurrentCitation` succeeds |

Retiring a catalog document or deprecating an original version does not erase an
accepted current record. Serving therefore does not repeat the ACTIVE-document
admission condition. Renderer or dependency runtime drift still rejects serving.
There is no silent fallback from a missing or invalid current admission to the
old renderer output.

The Registry exposes `registerCurrentCitation`, `currentCitationTransition`,
`currentCitationRecord`, `currentCitationReads` and `requireCurrentCitation`.
The renderer advertises `6529STREAM_CURRENT_BASE_CITATION_V1` through its separate
interface and uses `renderCurrent` and `encodingBinding`.

## Exact declaration and evidence

The registration retains the original version key, current profile and renderer
selector, encoder address and runtime hash, and the two evidence document IDs.
Its declaration hash also binds the chain, Registry, Schema Registry and its
runtime hash, immutable target-set hash, original registration hash and complete
ordered read list. Scope and state hashes use their original current-citation
domains. An absent current record has a hashed empty state, not a zero state hash.

Targets retain the Registry's original ascending-address order and named roles.
Reads are strictly ordered by target index and selector, with exact return-size
and fixed/dynamic declarations. Every old read must be preserved unchanged.
The new encoder read must identify the fixed `METADATA_COMPANION` target and
the encoder library's `renderCurrent` selector. That library selector differs
from the renderer's `renderCurrent` selector; the client keeps them separate.

The two ACTIVE CATALOG documents are canonical ABI bytes, each at most 8,192
bytes. Their document facts, chunk identities, immutable carrier bytes and
complete payload hash must agree.

- `CurrentAnalysis` binds the current output and analysis profiles, renderer and
  encoder runtime pins, declared read hash, original registration, named tool
  and findings commitments, and the passed assertion.
- `CurrentGoldenVector[]` has three to sixteen vectors and covers compact JSON
  mode 0, URI mode 1 and full JSON mode 2. Each contains the original complete
  render request, mode and independently supplied output hash.

The client compares actual renderer outputs to the retained expected hashes.
It never constructs expected hashes from those same observations. Direct RPC
observations do not prove equivalence to the Registry's bounded nested STATICCALL.
The original governance execution simulation checks that admission path.

An accepted analysis document is still an attributed assertion. The finite
read-list join and golden checks do not establish a complete transitive opcode
analysis, full STATIC conformance or an adequate operational gas budget.

## Capture and Safe governance

`captureMetadataCitation` takes explicit code pins for the Registry, Schema
Registry, document store, Governance Executor, renderer and encoder, plus a chain
ID and concrete block number. It retains the complete target list, original
version and reads, current record, gas parameters and governance policy state.
Inputs are copied before asynchronous reads and observations are tied to a
stable block hash.

Capture supports sealed ordinary governance with a bound policy catalog. The
workflow checks all six deployment pins, including on retained reads. This is a
client deployment-audit requirement beyond the contract's narrower serving
checks; the pure citation formatter has no such deployment requirement.

`inspectMetadataCitationRegistration` checks the proposed declaration against
that capture and loads the exact analysis and golden documents. Pure planners
retain `factsVerified: false`; capture and inspection are not authorization to
execute a governance action.

The governance sequence uses the existing publication, scheduling and execution
methods. The class-1 window retains the original minimum 48-hour delay, at least
seven days open for execution and at most 365 days of scheduling headroom.
The exact target call is ordinary CALL with zero value. Compose the returned
calls with the existing [Safe call plans](safe-call-plans.md).

Revalidation and simulation use the actual stage and caller. They retain the
original action ID, calldata publication, nonce, scope/state commitments and
policy checks; they do not silently refresh a stale declaration. Receipt checks
join the original governance events, the Registry registration event and immutable
readback. Safe receipt inspection also requires the exact single inner CALL and
a successful Safe outcome after the relevant events.

No helper signs, submits or changes governance configuration.

```ts
const capture = await captureMetadataCitation(provider, deployment, versionKey, {
  blockTag: reviewedBlock,
});
const inspection = await inspectMetadataCitationRegistration(
  provider, capture, registration, reads,
);
const prepared = prepareMetadataCitationGovernance(inspection, proposer, window);
const publication = prepareMetadataCitationOperation(prepared, "publish", caller);
const simulation = await simulateMetadataCitationOperation(provider, publication, {
  blockTag: simulationBlock,
});
```

After publication is retained, prepare and simulate `"schedule"` with the reviewed
proposer. Once its window opens, prepare and simulate `"execute"` with the intended
caller. `inspectMetadataCitationOperationReceipt` takes the exact operation,
transaction hash and `execution: "direct"` or `"safe"`.

## Bounded workflow profile

These are explicit client limits; some are narrower than the underlying protocol.

| Input or observation | Limit |
| --- | --- |
| Target inventory / declared reads | 1–64 targets / at most 128 ordered reads |
| Governance catalog | 1–1,024 entries |
| Ordinary RPC return / pinned runtime | 32,768 / 65,536 bytes |
| Analysis or golden document | 1–8,192 bytes, 1–64 chunks; each chunk at most 8,192 bytes |
| Immutable byte carriers | Document chunk: 8,193 bytes; published governance calldata: 24,576 bytes, including the STOP prefix |
| Golden vectors | 3–16, covering all three current JSON/URI modes |
| Current output modes 0 / 1 / 2 | 18,000 / 24,576 / 16,777,216 UTF-8 bytes, plus canonical ABI framing |
| Workflow reason URI | 2,048 UTF-8 bytes |
| Receipt transaction calldata | 262,144 bytes |
| Receipt logs | At most 256; at most four topics and 32,768 data bytes per log |

Receipts must be in a block strictly later than the reviewed capture. Publication
receipt checks require the pinned Executor to exist in the preceding block;
eventless repeated publication also needs the same retained pointer there.
Scheduling and execution receipts require the reviewed governance catalog to
match the block-end catalog. A later catalog change in that same block is
therefore rejected even when the operation itself was valid. Events identify the
operation; retained state is observed at block end. Later document retirement and
version deprecation remain valid for accepted citation readback.

## Current output reads

`readMetadataCurrentCitation` uses the retained serving path and the admitted
`renderCurrent` entry. Its current JSON profile covers modes 0, 1 and 2.
It returns the observed text and its byte hash without adding a citation or
changing the rendering. Solidity strings are represented as Unicode text.

Original `tokenURI`, `renderView`, historical JSON and executable HTML remain
separate. The contract's generic mode-3 HTML compatibility surface is outside
this current JSON helper. A metadata snapshot field or configuration hash in a
request does not turn the base citation into a snapshot-qualified citation.

## Frozen source and compiler evidence

The additive fixture is pinned to
`680d5aaa7384438a6e1264bc17eca5a604abcb0f` and the 1,055-source
`default-citation-abi7` capture. Every literal input matches that Git commit.
The fixture retains 248 ABI entries, 198 dependency-source hashes and 39 source
texts. `CurrentAnalysis` and the golden envelope are source-derived internal
schemas; their nested render request has a compiler ABI witness.

The public library selector is separately witnessed by the retained native2
`StreamStaticRenderEncoding` compiler artifact. Its fifteen metadata source
hashes match the same frozen ABI input. Library method identifiers use their
original nominal struct names. The ABI-only capture did not contain those
method identifiers, and generating this client fixture performs no compilation.

```sh
node scripts/generate-current-metadata-citation-fixture.mjs \
  /path/to/abi7-input.json /path/to/abi7-output.json \
  /path/to/StreamStaticRenderEncoding.json --check
```

Client and mocked-RPC tests establish only their recorded client behavior.
The source handoff separately reports ten isolated output-codec native tests;
its seven authored actual-current recipes were unexecuted and used synthetic
analysis with a partial read roster. These are distinct from complete current
graph, actual Safe, STATIC conformance, operational gas and release acceptance.
