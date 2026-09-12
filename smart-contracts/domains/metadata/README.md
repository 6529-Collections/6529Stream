# Metadata contracts

Start with the caller interface for the operation you need.

| Capability | Implementation | Caller API |
| --- | --- | --- |
| Current full-byte records and attributed history | `StreamCollectionMetadataV1` | [IStreamCollectionMetadataV1](../../interfaces/stream/metadata/IStreamCollectionMetadataV1.sol) |
| Immutable interpretation documents | `StreamSchemaRegistry`, `StreamSchemaDocumentStore` | [IStreamSchemaRegistry](../../interfaces/stream/metadata/IStreamSchemaRegistry.sol) |
| Metadata route selection | `StreamMetadataRouter` | [IStreamMetadataRouter](../../interfaces/stream/metadata/IStreamMetadataRouter.sol) |
| Contract-level metadata | `StreamContractMetadata` | [IStreamContractMetadata](../../interfaces/stream/metadata/IStreamContractMetadata.sol) |
| Earlier collection metadata API | `StreamCollectionMetadata` | [IStreamCollectionMetadata](../../interfaces/stream/metadata/IStreamCollectionMetadata.sol) |

The earlier and current collection hosts have different discovery IDs and
capabilities. The earlier files remain at their existing paths for compatible
callers and historical evidence. New full-byte integrations use the V1 host;
the [integration guide](../../../docs/integrations/metadata-records.md) explains
configuration, publication and historical recovery.

`StreamMetadataSubjects` and `StreamTokenContentTree` own canonical subject and
content-root preimages. `StreamMetadataGovernance` owns bounded root-proposer
witnesses for the new host. Shared record hashing, family masks and document
reads live in `../records/`. `StreamMetadataRenderer` supplies the existing
rendering and content-URI validation primitives.

Generic records do not imply a completed renderer or finality producer. The
[finality adapter guide](../../../docs/finality-host-adapters.md) describes
the additional typed facts and current-selection checks those paths require.
