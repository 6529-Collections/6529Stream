# Selected media preservation masters

`StreamMediaMasterSelection` is an additive producer for the three shared payload
slots of the native kind-3 `MediaManifest`: image, animation and content. It
authenticates original records and selects a retained lineage of master
associations or original artist waivers. It does not establish sale settlement,
display-payload archive coverage, finality, or a complete acquisition packet.

The exact prospective interpretation document is
[`STREAM_MEDIA_MASTER_SELECTED_SLOTS_PROFILE_V1`](../schemas/records/STREAM_MEDIA_MASTER_SELECTED_SLOTS_PROFILE_V1.json).
Its full bytes, the applicable schema, and the original RFC8785 canonicalization
definition must be active in the bound native Schema Registry. These checked-in
documents do not claim deployment or registration.

## Original record authority

A master association uses the existing `MEDIA_RELATIONSHIP` record type and
MEDIA family, authorization class 6 or 7, under the new
[`STREAM_MEDIA_MASTER_ASSOCIATION_V1`](../schemas/records/STREAM_MEDIA_MASTER_ASSOCIATION_V1.json)
schema. The association commits the collection subject, selected manifest,
slot, display hash, master role, native master object and coverage hashes, and
predecessor. It does not require artist authorship. An authorized archivist or
metadata administrator may record the association.

A waiver uses `ARTIST_STATEMENT` with the existing
[`STREAM_MASTER_WAIVER_V1`](../schemas/records/STREAM_MASTER_WAIVER_V1.json) schema.
The consumer checks the original Metadata receipt, exact record preimage,
native record-lane entry and chain link, stored complete payload bytes, consumed
artist authorization, original publication evidence, original attestation and
full original op24 statement. Only original artist authority class 1 with
capability 1 qualifies; estate publication does not. The original artist ID and
binding generation/hash must match the current accepted collection association.
The current signer is never substituted for the original signer.

Metadata's publication candidate encoder admits the exact `ARTIST_STATEMENT` /
`STREAM_MASTER_WAIVER_V1` pair through the existing statement operation. Original
artist authorization remains required; admitting the schema does not grant a new
signer or publication capability.

Permissionless adoption materializes these authenticated originals. It grants
no record-writing authority. Each collection subject and slot has append-only
selection history, with an exact predecessor and expected revision. An older
selection remains readable after replacement.

## Exact scope and denominator

In this narrower versioned profile, each waiver `mediaObjects.objectId` means:

```solidity
keccak256(abi.encode(
    keccak256("6529STREAM_MEDIA_MASTER_SLOT_V1"),
    uint256(chainId), address(core), address(metadata), uint256(collectionId),
    bytes32(subjectId), bytes32(selectedManifestHash), uint8(slot), bytes32(displayHash)
))
```

The slot values are 1, 2 and 3. This interpretation does not silently reinterpret
all generic master-waiver object IDs as file hashes. The original waiver signs
the full scope, and changing either the manifest, slot or display hash makes
that waiver inapplicable. The serializer preserves every original row and role;
duplicate object IDs and duplicate roles are rejected. The payload limit is
8,192 bytes. Media class remains the artist's original claim, with no MIME-based
inference.

`collectionMediaContext(collectionId)` returns the canonical collection subject,
current selected manifest hash, inventory hash and occupied-slot mask. It works
before any master has been selected. The inventory hash is:

```solidity
keccak256(abi.encode(
    keccak256("6529STREAM_MEDIA_MASTER_INVENTORY_V1"),
    manifest
))
```

Here `manifest` is the complete decoded `StreamCollectionManifestTypes.MediaManifest`
struct. The digest includes every source kind, URI, hash and MIME
declaration and excludes host addresses. The separately returned native manifest
hash retains its original deployment binding. Mask bits 0 through 2 represent
the occupied image, animation and content slots.

Native Metadata reads authenticate the current Core-selected Router, its runtime
pin, selected Metadata host/runtime, and the original manifest's collection and
Router association. The producer additionally compares the current serving image
URI to the manifest and rejects token-derived animation recipes. A complete
explicitly selected empty native manifest produces a nonzero inventory hash and
zero mask. An absent manifest does not become an empty inventory.

Opaque `manifestURI`/`manifestHash`, `alternatesURI`/`alternatesHash`, any occupied
slot lacking a content hash, and token-specific animation recipes remain
unsupported. They cannot pass by selecting only a convenient subset.

## Actual archive coverage

A present master must have a different full-object content hash from the display
payload. The same-Core, runtime-pinned native external coverage host must return
the exact original master identity and successfully revalidate its original
coverage through `requireCoverage`. The result includes the current original
dual-family receipts, independent passing full-object fixity observations and
native checkpoint evidence. A role label, URI, payload digest or arbitrary
object registration alone never fills the master slot. The caller must bind the
actual native coverage deployment; ERC-165 and a runtime pin identify a selected
dependency, rather than independently certify arbitrary supplied code.

Every `requireCollectionMasters` call rereads the full supported denominator,
current artist association and selected records, and revalidates each present
master's archive coverage. Changed manifests, new occupied slots, changed artist
bindings or failing archive evidence make the old floor unavailable. Historical
selection records are retained.

The current native external-object producer rejects `artistId == 0`. Platform
media therefore require a genuine additional archive producer before they can
complete a master requirement. This producer does not invent an artist ID or
permit a platform waiver. Artist-free collections with a complete explicitly
empty media denominator have no occupied media-master slot to fill.

## Verification boundary

The selector has separate governed `MEDIA_MASTER_MANIFEST_READ_GAS` and
`MEDIA_MASTER_COVERAGE_READ_GAS` parameters, each with a 500,000 floor and failure
class 2. Their genesis values are explicit constructor inputs. Nested native
manifest and coverage reads need a separate budget from flat Metadata reads;
forwarding Metadata's own dependency cap into its nested getter cannot meet
that getter's parent-gas precheck.

Authored tests cover exact schema/example bytes, actual Metadata/Schema/Store
publication, original receipt authority, original waiver publication joins,
stale manifests, new occupied slots, opaque references, missing digests,
display/master distinction, archive failure, retained lineage, platform refusal,
an official Safe 1.4.1 publication and rollback/retry, and scope-binding fuzzing.
The test fixture explicitly uses typed Router/manifest, Artist-owner and archive
boundaries. It does not prove native archive signature/checkpoint execution or
actual Artist op24/Safe execution. ABI/type checks are distinct from pending
native runtime, deployment-size and integrated settlement acceptance.
