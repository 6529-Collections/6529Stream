# Interpretation documents

`StreamSchemaRegistry` retains the bytes needed to interpret Stream records:
schemas, canonicalization definitions, catalogs and their dependencies. Import
[IStreamSchemaRegistry](../smart-contracts/interfaces/stream/metadata/IStreamSchemaRegistry.sol)
for callers. Its implementation and immutable chunk store live in
[`domains/metadata`](../smart-contracts/domains/metadata/StreamSchemaRegistry.sol).

This is the byte and governance foundation for [CMC-SCHEMA-REGISTRY](collection-metadata-contract.md)
and the [museum profile](museum-semantic-mapping.md). Publishing a document
does not validate its JSON, ontology mappings or institutional suitability.
The pinned tooling owns those checks. Current implementation work does not
claim a deployed registry, completed metadata writer integration or museum
conformance. The [delivery ledger](../ops/V1_DELIVERY.md) records accepted tests.

## Publish and approve

1. Produce the exact bytes under an identified canonicalization definition.
2. Split them into ordered chunks of 8,192 bytes, except the final chunk, which
   contains 1–8,192 bytes. Call `publishChunk` on the registry's own `chunkStore`.
   Anyone, including a Safe, can publish bytes. Repeating an upload returns the
   existing content-addressed pointer and grants no record or schema authority.
3. Build `DocumentSpec` and the ordered array of chunk hashes. Call
   `registrationTransition` to verify the complete payload and obtain the exact
   scope, old-state and new-state commitments for the governance call.
4. Propose and execute ordinary class-1 governance through the registry's
   immutable Executor. The selector must first be admitted to that Executor's
   action catalog. A Safe can propose and schedule the action using the
   [saved-stage workflow](../script/current/README.md); calling the registry's
   writer directly from the Safe is rejected.
5. Read back `document(id)` and `documentBytes(id)`. Deployment tooling must
   publish the registry and interpretation inventory in the system manifest.
   That complete deployment/metadata integration is a separate delivery step.

| Field | Meaning |
| --- | --- |
| `name` | Exact versioned ASCII name; `documentId = keccak256(bytes(name))` |
| `kind` | `SCHEMA`, `CANONICALIZATION`, `CATALOG` or `DEPENDENCY` |
| `contentHash` | Keccak-256 of all reconstructed bytes, in order |
| `canonicalizationId` | Exact registered canonicalization definition; never a mutable latest-version pointer |
| `supersedesId` | Optional existing document of the same kind; it creates lineage without changing its predecessor |
| `uri` | Optional transport/discovery hint; the stored bytes remain authoritative |
| `totalBytes` | Exact logical length, checked against every chunk |

Names are case-sensitive and allow only letters, digits, `_`, `-` and `.`;
their length is 1–128 bytes. URIs are at most 2,048 bytes. A logical document
contains at most 64 chunks and 524,288 bytes. Empty documents, missing chunks,
alternate segmentation, wrong lengths and wrong whole-document hashes fail
before a valid transition can be prepared. The declaration commits to the
complete specification and ordered chunk list. These are registry bounds;
an export profile may impose additional aggregate and dependency-depth bounds.

The constructor pins the supplied Executor's code hash and governed-authority
capability and creates its own chunk store. It has no Core constructor input:
the deployment manifest and metadata consumers must select this exact registry
and Executor. A capability beacon alone is not proof of a system-wide binding.

## Bootstrap and version history

The first canonicalization definition is `RAW_BYTES`. Its exact immutable
definition is exposed by `RAW_BYTES_DEFINITION()`:

```json
{"name":"RAW_BYTES","rule":"Do not transform the supplied bytes.","version":1}
```

The definition contains no BOM or trailing newline. Only this exact named,
typed, hashed document may use the self-bootstrap exception; its predecessor
is zero and its canonicalization ID is its own ID. Other documents, including
other canonicalization definitions, require an already registered, active
canonicalization definition. Retaining this bootstrap document does not prove
that JSON or another higher-level format conforms to its rules.

Document identity, bytes, canonicalization and lineage cannot be replaced.
Publish a new versioned name for changed meaning. Ordinary governance may move
status forward from `ACTIVE` to `DEPRECATED` or directly to `ARCHIVED`, and from
`DEPRECATED` to `ARCHIVED`. It cannot reverse or repeat a transition. The old
and new status commitments bind the same immutable declaration; no mutable
revision head can substitute another document. `RAW_BYTES` cannot retire, so
there is always a retained bootstrap for future interpretation definitions.

Retired documents and their predecessors remain readable indefinitely. Retiring
a canonicalization definition prevents **new registry documents** from using
it; it does not invalidate existing references or rewrite historical bytes.
Admission policy for new artwork records using a retired schema belongs to
the relevant metadata writer and is not inferred from this registry alone.

## Reconstruct without logs or a website

Enumerate `documentCount()` and `documentIdAt(index)`, read each `document(id)`,
and resolve its ordered `chunkHashes` through the immutable store. `readChunk`
checks retained bytes against their hash; `documentBytes` also verifies the
whole document. The per-document order preserves repeated chunks.

The storage-backed payload pointer surface uses global `scopeKey = 0`.
`payloadPointerCount(0)` and `payloadPointerAt(0, index)` enumerate accepted
chunks only, deduplicated by document kind and chunk hash. The same bytes may
therefore appear once for each distinct kind, while repeated chunks within one
kind share an entry. Unapproved uploads never enter this inventory. The family
is `keccak256(abi.encode("STREAM_INTERPRETATION_DOCUMENT_CHUNK_V1", kind))`,
where `kind` has the enum's `uint8` ABI representation. Reconstruct logical
documents from their stored ordered lists, not the deduplicated pointer index.

The [current integration tests](../test/current/StreamCurrentSchemaRegistry.t.sol)
exercise actual two-of-three Safe governance and the canonical Executor,
history, rejection paths, exact chunk boundaries and payload fuzzing. Their
large dependency fixtures are synthetic bytes with representative dimensions;
they are not evidence that official museum documents have been registered.
