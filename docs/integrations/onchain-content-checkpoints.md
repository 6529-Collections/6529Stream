# Onchain content checkpoints

`StreamOnchainContentCheckpoint` computes and retains a complete collection
content root from actual Core membership and the metadata router's served
bytes. Anyone can do the computation, including a Safe. Publishing an
authoritative root record and accepting finality are separate operations still
being integrated. The [leaf manifest verifier](content-leaf-manifests.md)
checks complete preserved leaf-list bytes against the checkpoint.

Use the [caller interface](../../smart-contracts/interfaces/stream/finality/IStreamOnchainContentCheckpoint.sol).
The constructor pins Core, router, token inventory, their runtime hashes and
the deployment chain. The router and inventory must identify the same Core.
Every new batch checks that the actual Core-selected metadata router still
matches that binding. Historical checkpoint reads survive dependency or chain
changes; current-validity checks reject them.

## The inline ONCHAIN profile

The profile identifier is
`keccak256("6529STREAM_CONTENT_INLINE_ONCHAIN_V1")`. It requires a configured,
nonempty onchain script and the router's
[stable presentation profile](stable-router-presentation.md). Script, media,
base URI, dependencies, artist identity and display metadata must all be locked.
Core's collection freeze is diagnostic and does not replace those locks.

Each token's leaf contains the following six values:

| Field | Exact meaning |
| --- | --- |
| `tokenId` | Permanent Core token ID, including completed tokens subsequently burned |
| `metadataHash` | Keccak-256 of the complete JSON returned by the pinned router's historical renderer |
| `imageHash` | Keccak-256 of the supplied decoded inline image bytes; zero when the image is absent |
| `animationHash` | Keccak-256 of the supplied complete HTML bytes |
| `contentHash` | Zero: this profile has no separate content asset beyond its image and animation |
| `tokenDataHash` | Keccak-256 of Core's exact token data, including empty bytes |

The governing registered profile/schema must explicitly declare these absence
rules before authoritative publication. Its registration is still a delivery
step. The Stream JSON serializer preserves exact field order and full-width
integer literals; these bytes are not RFC 8785/JCS.

The verifier re-encodes the supplied animation bytes and compares the exact
final `animation_url` field, including the JSON document terminator. It compares
the actual JSON image field with the stored source URI and the supplied image
bytes. URI text is never substituted for the image's content hash. Each token
must have finalized entropy from the coordinator Core recorded at its mint.
An unresolved token makes the entire submitted batch fail atomically.

The current router admits empty images, its existing HTTPS/IPFS/Arweave URIs,
and canonical Base64 inline PNG, JPEG, GIF and WebP images within the existing
2,048-byte URI limit. Only absent or inline images qualify for this checkpoint
profile. Raster signature checks validate admission; they do not decode an
entire image or establish that it will render. External-image, OFFCHAIN, HYBRID,
TOKEN, RELEASE, SEASON and VIEW support remain separate required work.

## Build and read a checkpoint

1. Complete the [token inventory](collection-token-inventory.md), including
   burned tokens, and apply the exact content and presentation locks.
2. Call `beginCollectionCheckpoint(collectionId)`. Repeating it for identical
   inputs returns the same plan ID without replacing existing progress.
3. Read the plan's `nextIndex`; obtain that next token from the inventory.
4. Submit the next one to eight `TokenPayload` entries to
   `appendCheckpointTokens`, in inventory order, with their exact image and
   animation bytes. A skipped, repeated, altered or unresolved token reverts
   the whole batch. Refresh progress if another submitter advanced it first.
5. Call `requireCurrentCheckpoint(planId)` when consuming the completed result.
   An incomplete plan, later mint or changed source/binding fails this check.

The plan ID binds the chain, producer, profile, Core, router, inventory,
collection, token count, inventory commitment and serving-state commitment.
`ContentCheckpointStarted` publishes those inputs. Each verified leaf is
retained onchain and emitted with its index and hash. The final event publishes
the root and count. `checkpoint` and `checkpointLeaf` expose retained history.

Leaves use the permanent `[CMC-CONTENT-ROOT]` domains, ascending token order,
ordered left/right pairs and promotion of an unpaired last node. Pairs are
never sorted and odd nodes are never duplicated. The incremental frontier
produces the same root regardless of valid batch partitioning. A separate
`leafChainHash` commits each successive index and leaf; it is not the tree root.
The [implementation](../../smart-contracts/domains/finality/StreamOnchainContentCheckpoint.sol)
and [content-tree specification](../collection-metadata-contract.md) define the
exact ABI preimages.

## Gas and validation boundaries

The two forwarding parameters are `CONTENT_CHECKPOINT_READ_GAS` and
`CONTENT_CHECKPOINT_RENDER_GAS`. They use the existing governed gas host, or
fixed allowances when its authority is zero. The actual composition fixture
uses 2,000,000 and 14,000,000 gas respectively. The earlier boundary-only tests
use smaller allowances; those are not deployment recommendations. Batch count
limits do not establish that eight maximum-sized payloads fit one block.
Operators must estimate each transaction against the intended deployment.
An onchain script can still refer to remote resources; this computation alone
does not establish dependency availability or archival coverage.

The independently reviewed computation suite covers canonical preimages,
odd-sized trees, batch partition fuzzing, exact bytes, atomic rejection,
historical reads and actual threshold Safe calls to all 24 public reads and
both computation operations. Its Core/router/entropy reads use explicit test
boundaries. The separate composition suite uses actual Core, router, inventory
and checkpoint contracts, with explicit governance, module registry, Manager,
artist and entropy boundaries. It exercises burns, interleaved collections,
maximum script/token data, retry and Safe custody. Complete finality,
authoritative publication, archival coverage and deployment gas acceptance
remain separately tracked in the [delivery ledger](../../ops/V1_DELIVERY.md).
