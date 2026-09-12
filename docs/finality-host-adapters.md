# Finality host adapters and content commitments

`StreamFinalityHostAdapter` translates facts from one immutable evidence host
into the existing collection and scoped finality read interfaces. Deploy it
after its Core and host have deployed. Each instance binds one component family,
the host address and runtime hash, and the Core address and runtime hash.

| Component family | Authoritative host pointer |
| --- | --- |
| `COLLECTION_METADATA`, `REFERENCE_RENDER` | `COLLECTION_METADATA` |
| `METADATA_ROUTER`, `RENDERER`, `RENDER_CONTEXT`, `MEDIA_MANIFEST`, `SCRIPT_SOURCE`, `DEPENDENCY_SOURCE` | `METADATA_ROUTER` |
| `ENTROPY_COORDINATOR` | `ENTROPY_COORDINATOR` |

The host must support its primary interface and
`IStreamFinalityComponentFacts`, return the same Core, and derive the requested
family's facts from its actual records and scope. The adapter checks these
bindings on every read. It rejects malformed replies, unknown component
families, invalid scope shapes and empty evidence commitments. A host reporting
`frozen = false` remains false in the translated component state.

Discovery for a new finalization must call `requireCurrentSelection()`. It
checks Core's stored pointer target, runtime hash, family, interface, registry
admission snapshot and manifest commitments. This is a check of Core's stored
admission facts, not a fresh query of the module registry's current status.
The finality registry must also validate its current counterparts and the
complete applicable scope evidence before accepting a new record.

Historical `finalityState` and `finalityStateForScope` reads deliberately do not
require current selection. They continue to validate the exact pinned host,
runtime and scope facts after a permitted pointer replacement. This preserves
verification of old records without making their replaced host eligible for a
new finalization. Deploying or reading an adapter does not itself freeze a host.

The adapter allocates only the exact expected return size. Its caller's
governed finality read allowance must cover the adapter and the host's complete
validation work; the small unit test costs do not set that allowance. An entropy
host must validate every covered token's original coordinator and retained
terminal outcome. The current global entropy pointer alone cannot prove those
historical token facts.

`StreamTokenContentTree` implements the exact leaf and node preimages in
[CMC-CONTENT-ROOT](collection-metadata-contract.md#token-content-root). Leaves
are strictly ordered by token ID. Odd nodes are promoted unchanged; a one-token
tree is its leaf. The library requires nonzero token IDs and metadata hashes,
and does not mutate the supplied leaves. Optional asset hashes remain explicit
zeros where the selected schema allows absence.

`StreamMetadataSubjects` derives collection, token, release, season, view and
media subjects using the pinned domains in
[CMC-SUBJECT-ID](collection-metadata-contract.md#subject-identity-cmc-subject-id).
It rejects ambiguous scope shapes. Actual token-to-collection membership remains
the publishing host's responsibility; the token subject intentionally commits
Core and token identity rather than duplicating the collection mapping.

The [current metadata record host](integrations/metadata-records.md) now retains
actual record bytes and interpretation identities. Its primary interface is
`IStreamCollectionMetadataV1`; it does not yet implement
`IStreamFinalityComponentFacts`, so an adapter cannot treat generic bytes as
finality evidence. Preserved leaf manifests, complete typed render inventory
and their current-contract finality composition remain in development. The
[delivery ledger](../ops/V1_DELIVERY.md) tracks that remaining integration.

The [typed-provider design](adr/0041-typed-finality-evidence-provider.md) keeps
those interpretations in a fixed satellite beside the generic record host.
The [collection token inventory](integrations/collection-token-inventory.md)
enumerates actual completed mints, including burns, as an input to complete
content-root production. Neither surface makes generic records finality-ready.
