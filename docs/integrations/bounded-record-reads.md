# Read record evidence within the governed gas budget

Stream permits long registration and record URIs. Fetching their entire stored
tuples in one cold call can exceed the 150,000-gas dependency budget. New
consumers use additive fixed-size readers, preserving the full supported data
and existing APIs.

| Interface | Return | Use |
| --- | --- | --- |
| `IStreamSchemaDocumentFacts.documentFacts` | Nine ABI words | Document identity, kind, status, content hash, canonicalization, predecessor, length, chunk count and declaration hash |
| `IStreamSchemaDocumentFacts.documentChunkHashAt` | One ABI word | Original ordered chunk hash, including repetitions |
| `IStreamCollectionRecordReceipts.collectionRecordReceipt` | Nine ABI words | Original receipt without copying the record URI |

The [schema interface](../../smart-contracts/interfaces/stream/metadata/IStreamSchemaDocumentFacts.sol)
returns `exists=false` for an unknown document. An unknown document's chunk
lookup and an out-of-range chunk index revert. The
[receipt interface](../../smart-contracts/interfaces/stream/metadata/IStreamCollectionRecordReceipts.sol)
preserves unknown-record rejection. Discovery of both interfaces is additive;
the original registry and metadata interface IDs remain unchanged. New metadata
deployments require the compact schema capability at construction.

For a typed document, verify all required header facts, fetch each ordered
chunk through the actual registry and immutable store, and verify the complete
length and content hash. Registration name and URI are omitted from this
reader. The registry establishes the name-derived key; the declaration hash
retains provenance. A consumer must not claim it reconstructed the complete
registration declaration from this header alone.

For an original record, accept its complete tuple as an untrusted witness.
Recompute the original 14-word record hash, including both hash references,
exact URI bytes, recorder, scope, host, Core and chain. Join the requested hash
to the actual receipt and its indexed family history before using its payload
or authority. The witness itself grants no authority.

The old full-document and full-record getters remain useful for offchain
clients with adequate gas. Do not place them inside a 150,000-gas onchain read
and assume every valid URI fits. The focused tests exercise actual maximum
registration and record shapes, preserve all receipt fields and show bounded
reads and record ingress succeeding under the existing cap.
