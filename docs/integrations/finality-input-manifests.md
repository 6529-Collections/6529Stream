# Exact independent finality input manifests

[StreamFinalityInputManifestReads](../../smart-contracts/domains/finality/StreamFinalityInputManifestReads.sol)
validates one exact retained document against the complete statement supplied by
the fixed evidence provider. It reads the actual registered interpretation bytes,
the schema Store payload and the original Finality registry's staged payload.
Both payloads must equal the canonical expected document under the same content
hash. Storing bytes alone never establishes source validity or finality authority.

## Profile and original evidence

The first profile is native ONCHAIN, artist-bound COLLECTION. Its
[statement type](../../smart-contracts/interfaces/stream/finality/StreamFinalityInputManifestTypes.sol)
binds the actual Core facts, scope content root and leaf count/schema, original
snapshot and reference-render manifest hashes, all ten independent inputs, and
all nine ordered non-sanction component expectations. Detailed source, media,
renderer, environment and archival identities resolve through the original
referenced records; they are not replaced by newly authored descriptions.

All nine families are mandatory and distinct. Component expectations retain
all seven fields. Exactly one intent or signed-waiver reference is nonzero;
interview evidence remains a nonzero commitment even for an authenticated waiver.
The explicit first-profile policies require terminal entropy for every member,
permit no artwork-byte mutation exception, and require actual artist sanction
and its archive proof separately. Other scopes, metadata modes, deferred entropy
and platform declarations require their own implemented profiles.

The [schema definition](../schemas/finality/input-manifest-v1.definition.json)
and [complete ABI definition](../schemas/finality/input-manifest-abi-v1.definition.json)
contain ordered nested tuple layouts and the expanded envelope signature.
These are interpretation documents for Solidity ABI payloads, not JSON payload
schemas or JCS canonicalization claims. The definitions themselves are registered
under `RAW_BYTES`; their exact bytes are also returned by
[the schema library](../../smart-contracts/domains/finality/StreamFinalityInputManifestSchemas.sol).

`schemaId` and the legacy `manifest.canonicalizationHash` field carry their
name-derived registry IDs. The validator separately checks the content hash and
complete bytes of each registered definition. Definition IDs and document-content
hashes are different values. Current candidate admission requires active definitions;
retired definitions and already-retained bytes remain historically readable.

## Preparing and checking a candidate

1. Independently derive the complete current statement from the provider's fixed
   actual producers. Its root, snapshot, reference, intent/waiver, interview,
   rights, work, render-critical inventory and coverage must all be validated.
   `encode` validates shape; it does not perform those source/authority checks.
2. Register both exact interpretation definitions in the actual Schema registry.
3. Encode the statement with the real chain, Core, generic Metadata and original
   Finality registry addresses. `keccak256(payload)` is the manifest content hash.
4. Retain the same complete payload through `StreamSchemaDocumentStore.publishChunk`
   and `IStreamArtworkFinalityRegistry.stageFinalityManifest`. Both are permissionless
   byte-staging actions; neither signs or finalizes anything.
5. The provider calls `requireCurrent` with its independently rederived statement
   and the selected content hash. Changed evidence, alternate ABI offsets, trailing
   bytes, missing copies, altered dependencies or wrong definitions reject.
6. The existing sanction and finalization paths separately validate their actual
   authority, subject, original signature and required archival evidence. This
   byte validator does not replace those paths or manifest archival coverage.

Dependencies are supplied only from provider-fixed configuration. Every operative
read checks the pinned runtimes, chain and reciprocal Core/Metadata/Schema/Store/
original-Registry bindings. There is no new mutable admission head. Permissionless
retention cannot redirect the provider's choice of evidence.

## Avoiding circular commitments

The permanent scope-input hash remains the existing domain with chain ID, actual
Core, actual generic Metadata, scope and the ten inputs. It never substitutes the
provider address. The manifest excludes its own content hash, the finality record,
and the eventual sanction record/signature. The independent component projection,
including COLLECTION_METADATA, must also exclude this manifest. That component
can commit the independently validated inputs and locks, without hashing itself.

Original object/receipt identities are stable. Later passing fixity observations
are checked for current availability but do not rewrite the original statement.
The separately bound execution witness establishes the actual sanction and its
archive proof after the artist signs, as specified in
[ADR 0039](../adr/0039-canonical-finality-governance-and-evidence.md).

## Evidence and remaining composition

Fifteen cases pass in both compiler modes, including 256 fuzz inputs, actual
threshold-Safe calls, portable definition parity, exact integer precision,
malformed encodings, retirement and low-parent-gas failure with exact retry.
SchemaRegistry, its Store and Safe are actual contracts. Core, generic Metadata,
original Registry staging, governance action context and independently derived
facts are explicit typed boundaries in this cohort. Complete current provider,
source inventory, archival joins and original Registry assembly remain open.

The document is bounded to one 8,192-byte Store chunk. The fixed nine-family
profile is tested; this is not a maximum collection, full ceremony or whole-system
gas-capacity claim. The complete Safe selector/version/nesting matrix remains in
[Safe acceptance](../../ops/SAFE_ACCEPTANCE.md).
