# Events And Indexing

This document is the event and indexer reconstruction spec for 6529Stream
integrations and completes the current `INT-005` local documentation slice. It
is for React, mobile, Electron, operator UI, backend signing service,
marketplace, analytics, and indexer teams that need to reconstruct contract
state from logs plus explicit read-after-event calls.

The repository remains a pre-audit local baseline. It is not production-ready
and this document is not a security claim. Local evidence does not replace
fork/testnet/live evidence required for public beta or production release.

Use this with the integration entrypoint in
[`docs/integrations/README.md`](README.md), the fixed-price flow in
[`docs/integrations/contract-flows.md`](contract-flows.md), the auction flow in
[`docs/integrations/auction-flows.md`](auction-flows.md), the wallet/signature
guide in [`docs/integrations/wallets-and-signatures.md`](wallets-and-signatures.md),
metadata policy in [`docs/metadata.md`](../metadata.md), release policy in
[`docs/release-policy.md`](../release-policy.md), and release readiness in
[`docs/release-readiness.md`](../release-readiness.md). Use
[`docs/integrations/marketplace-indexer-evidence.md`](marketplace-indexer-evidence.md)
for the `ONE-005` retained marketplace/indexer evidence model covering
OpenSea, Reservoir, Blur, Manifold, equivalent collector/indexer tooling,
contract metadata, token metadata refresh, animation rendering, royalty
display, transfer/listing/sale paths, event replay, and cache invalidation.
Use
[`docs/integrations/examples/typescript-event-decoding-and-indexer-ingestion.md`](examples/typescript-event-decoding-and-indexer-ingestion.md)
for INT-015 TypeScript event decoding and indexer ingestion snippets covering
event topic catalog loading, topic0 dispatch, normalized log identity,
idempotent ingestion, read-after-event queue construction, confirmation depth,
and reorg rollback.

## Maturity And Scope

This spec covers the current local event and read model for:

- release artifact and deployment source selection;
- log identity, finality, confirmation depth, and reorg rollback;
- indexed entities and primary keys;
- ERC-721, drop authorization, fixed-price mint, auction, credit, curator,
  dependency, metadata, randomizer, pause, signer, admin, and release-artifact
  reconstruction;
- required read-after-event calls;
- duplicate-log idempotency and full-rescan recovery; and
- known event/read gaps that should become `CON-002` or `CON-003` follow-up
  work where code changes are needed.

This spec does not claim:

- reviewed production deployment addresses;
- reviewed external audit evidence;
- live indexer replay evidence;
- marketplace readiness;
- public-beta approval;
- production signer custody; or
- final frontend, mobile, Electron, or analytics implementation readiness.

The exact public beta and production blockers remain tracked by
[`release-artifacts/latest/risk-register.json`](../../release-artifacts/latest/risk-register.json),
[`release-artifacts/latest/public-beta-evidence.json`](../../release-artifacts/latest/public-beta-evidence.json),
[`docs/public-beta-evidence.md`](../public-beta-evidence.md), and
[`docs/non-local-release-evidence.md`](../non-local-release-evidence.md).

## Source Of Truth

Use tracked generated artifacts and checked docs, not hand-maintained event
copies.

| Need | Source of truth | Indexer note |
| --- | --- | --- |
| Integration entrypoint | [`docs/integrations/README.md`](README.md) | Starts artifact, address, ABI, event, and flow discovery |
| Fixed-price flow | [`docs/integrations/contract-flows.md`](contract-flows.md) | `saleMode = 1`, `DropAuthorizationConsumed`, fixed-price credits, and withdrawal UX |
| Auction flow | [`docs/integrations/auction-flows.md`](auction-flows.md) | Auction states, bids, no-bid settlement, credits, pause domains, and event/read gaps |
| Wallet/signature guide | [`docs/integrations/wallets-and-signatures.md`](wallets-and-signatures.md) | Domain, signer epoch, consumed/cancelled drops, EOA, ERC-1271, Safe, and failure states |
| Metadata policy | [`docs/metadata.md`](../metadata.md) | Token JSON state, contract-level metadata, ERC-4906 behavior, burn, freeze, cache, and browser sandbox semantics |
| Marketplace/indexer evidence | [`docs/integrations/marketplace-indexer-evidence.md`](marketplace-indexer-evidence.md) | `ONE-005` retained marketplace/indexer evidence requirements for event replay, metadata refresh, cache invalidation, royalty display, and platform coverage |
| 1/1 provenance policy | [`docs/provenance-manifests.md`](../provenance-manifests.md) | Artifact-only provenance entity, release binding, and frontend/indexer display boundaries |
| Release policy | [`docs/release-policy.md`](../release-policy.md) | Event signature/indexed-field changes are breaking unless approved |
| Drop signing guide | [`docs/drop-authorization-signing.md`](../drop-authorization-signing.md) | Typed-data schema and fixture expectations |
| Auction custody guide | [`docs/auction-custody.md`](../auction-custody.md) | Custody and no-bid claimant behavior |
| Release readiness | [`docs/release-readiness.md`](../release-readiness.md) | Current launch blocker dashboard |
| Non-local evidence | [`docs/non-local-release-evidence.md`](../non-local-release-evidence.md) | Fork/testnet/live retained evidence requirements |
| Public beta evidence | [`docs/public-beta-evidence.md`](../public-beta-evidence.md) | Public beta evidence status |
| Risk register | [`release-artifacts/latest/risk-register.json`](../../release-artifacts/latest/risk-register.json) | Generated blocker and risk source |
| Release manifest | [`release-artifacts/latest/release-manifest.json`](../../release-artifacts/latest/release-manifest.json) | Generated source-of-truth manifest |
| Release checksums | [`release-artifacts/latest/release-checksums.json`](../../release-artifacts/latest/release-checksums.json), [`release-artifacts/latest/SHA256SUMS`](../../release-artifacts/latest/SHA256SUMS) | Signable checksum bundle |
| 1/1 provenance manifest | [`release-artifacts/latest/one-of-one-provenance-manifest.json`](../../release-artifacts/latest/one-of-one-provenance-manifest.json), [`release-artifacts/schema/one-of-one-provenance-manifest.schema.json`](../../release-artifacts/schema/one-of-one-provenance-manifest.schema.json), [`release-artifacts/provenance/one-of-one-provenance-template.provenance.json`](../../release-artifacts/provenance/one-of-one-provenance-template.provenance.json) | Generated provenance catalog and schemaed descriptor for artifact-only 1/1 provenance |
| ABI review surface | [`release-artifacts/baselines/v0.1.0/abi-surface.json`](../../release-artifacts/baselines/v0.1.0/abi-surface.json) | External production contract and published interface function/event/error baseline |
| ABI checksums | [`release-artifacts/latest/abi-checksums.json`](../../release-artifacts/latest/abi-checksums.json) | ABI and bytecode checksum source |
| Event topic catalog | [`release-artifacts/latest/event-topic-catalog.json`](../../release-artifacts/latest/event-topic-catalog.json) | Canonical committed topic/signature list |
| TypeScript event decoding snippets | [`docs/integrations/examples/typescript-event-decoding-and-indexer-ingestion.md`](examples/typescript-event-decoding-and-indexer-ingestion.md) | `INT-015` checked event topic catalog loading, topic0 dispatch, normalized log identity, decode boundary, idempotent ingestion, read-after-event queue, confirmation depth, and reorg rollback examples |
| Integration conformance fixtures | [`docs/integrations/integration-conformance-fixtures.md`](integration-conformance-fixtures.md), [`docs/integrations/fixtures/integration-conformance-fixtures.json`](fixtures/integration-conformance-fixtures.json) | `INT-016` checked local fixture bundle for event topic dispatch, normalized log identity, read-after-event queues, duplicate log idempotency, unknown emitter, unknown topic, confirmation depth, reorg rollback, and no-secret redaction diagnostics |
| Interface IDs | [`release-artifacts/latest/interface-ids.json`](../../release-artifacts/latest/interface-ids.json) | Interface lookup source |
| Local address book | [`deployments/address-books/anvil-6529stream-v0.1.0-001.json`](../../deployments/address-books/anvil-6529stream-v0.1.0-001.json) | Local development addresses |
| Fork-mainnet address book | [`deployments/address-books/fork-mainnet-6529stream-v0.1.0-001-broadcast.json`](../../deployments/address-books/fork-mainnet-6529stream-v0.1.0-001-broadcast.json) | Retained fork rehearsal addresses |
| Local deployment manifest | [`deployments/examples/anvil-6529stream-v0.1.0-001.json`](../../deployments/examples/anvil-6529stream-v0.1.0-001.json) | Local deployment instance |
| Fork deployment manifest | [`deployments/examples/fork-mainnet-6529stream-v0.1.0-001-broadcast.json`](../../deployments/examples/fork-mainnet-6529stream-v0.1.0-001-broadcast.json) | Retained fork deployment instance |
| Core NFT contract | [`smart-contracts/StreamCore.sol`](../../smart-contracts/StreamCore.sol) | ERC-721, collection, metadata, dependency, burn, freeze, and randomizer events |
| Contract metadata adapter | [`smart-contracts/StreamContractMetadata.sol`](../../smart-contracts/StreamContractMetadata.sol) | ERC-7572-style `contractURI()`, `ContractURIUpdated`, URI hash, core binding, and admin binding |
| Drops contract | [`smart-contracts/StreamDrops.sol`](../../smart-contracts/StreamDrops.sol) | Drop authorization, signer, auction contract, and fixed-price credit events |
| Auction contract | [`smart-contracts/AuctionContract.sol`](../../smart-contracts/AuctionContract.sol) | Auction lifecycle, bid, settlement, and proceeds events |
| Admin contract | [`smart-contracts/StreamAdmins.sol`](../../smart-contracts/StreamAdmins.sol) | Role, pause, emergency recipient, and signer-lifecycle target events |
| Minter bridge | [`smart-contracts/StreamMinter.sol`](../../smart-contracts/StreamMinter.sol) | Phase, fixed-price batch mint, auction mint, auction end-time, contract-reference events, and bridge reads such as original auction end-time values |
| Randomizer lifecycle | [`smart-contracts/StreamRandomizerLifecycle.sol`](../../smart-contracts/StreamRandomizerLifecycle.sol) | Request, fulfillment, stale, failure, retry, and burned-token randomness events |
| Curator pool | [`smart-contracts/StreamCuratorsPool.sol`](../../smart-contracts/StreamCuratorsPool.sol) | Merkle roots, curator credits, and curator withdrawals |
| Dependency registry | [`smart-contracts/DependencyRegistry.sol`](../../smart-contracts/DependencyRegistry.sol) | Dependency version creation/deprecation events |
| ERC-4906 interface | [`smart-contracts/IERC4906.sol`](../../smart-contracts/IERC4906.sol) | Metadata update event interface |
| ERC-7572-style interface | [`smart-contracts/IERC7572.sol`](../../smart-contracts/IERC7572.sol) | Contract-level metadata interface used by the release-tracked adapter |
| Metadata event tests | [`test/StreamMetadataEvents.t.sol`](../../test/StreamMetadataEvents.t.sol) | Current metadata event behavior |
| Contract metadata tests | [`test/StreamContractMetadata.t.sol`](../../test/StreamContractMetadata.t.sol) | Contract URI, URI hash, pause, event, and admin behavior |
| EIP-712 tests | [`test/StreamDropsEIP712.t.sol`](../../test/StreamDropsEIP712.t.sol) | Drop consumed/cancelled/signer event behavior |
| ERC-1271 tests | [`test/StreamDropsERC1271.t.sol`](../../test/StreamDropsERC1271.t.sol) | Contract signer behavior |
| Auction custody tests | [`test/StreamAuctionCustody.t.sol`](../../test/StreamAuctionCustody.t.sol) | Auction custody and no-bid state |
| Auction payment tests | [`test/StreamAuctionPayments.t.sol`](../../test/StreamAuctionPayments.t.sol) | Bidder/proceeds credit behavior |
| Minter event tests | [`test/StreamMinterEvents.t.sol`](../../test/StreamMinterEvents.t.sol) | Minter bridge event fields and read-after-event behavior |
| Event reconstructability tests | [`test/StreamEventReconstructability.t.sol`](../../test/StreamEventReconstructability.t.sol) | Indexer-style log reconstruction for fixed-price, auction, minter bridge, and admin-reference flows |
| Curator tests | [`test/StreamCuratorsPool.t.sol`](../../test/StreamCuratorsPool.t.sol) | Curator credit and root behavior |
| Admin tests | [`test/StreamAdmins.t.sol`](../../test/StreamAdmins.t.sol) | Role event behavior |
| Pause tests | [`test/StreamPauseControls.t.sol`](../../test/StreamPauseControls.t.sol) | Pause-domain behavior |

Raw ABIs under ignored `out/` are local build products. For committed review,
use `release-artifacts/baselines/v0.1.0/abi-surface.json`,
`release-artifacts/latest/abi-checksums.json`,
`release-artifacts/latest/event-topic-catalog.json`, and
`release-artifacts/latest/interface-ids.json`.

## Indexer Inputs

Before starting a replay, an indexer should pin:

- chain ID;
- deployment manifest ID;
- address book hash;
- contract addresses and deployment block range;
- ABI checksum map;
- event topic catalog hash;
- release manifest hash;
- release checksum bundle hash;
- confirmation depth policy;
- reorg rollback horizon;
- parser version; and
- known event/read gaps accepted for the local baseline.

Do not mix events from different deployment manifests or release manifests in
the same indexed namespace. Use a namespace key such as
`chainId:deploymentManifestId:contractAddress`.

## Log Identity And Ordering

Every processed log should be stored with a stable identity:

| Field | Requirement |
| --- | --- |
| `chainId` | Chain where the log was observed |
| `contractAddress` | Emitter address from the selected address book |
| `blockNumber` | Numeric block number |
| `blockHash` | Block hash for reorg detection |
| `transactionHash` | Transaction hash |
| `transactionIndex` | Transaction index in the block |
| `logIndex` | Log index in the block |
| `topic0` | Event topic signature |
| `removed` | RPC removed flag if provided by the client |

Process logs in `(blockNumber, transactionIndex, logIndex)` order. Treat
`(chainId, blockHash, transactionHash, logIndex)` as the immutable confirmed
log identity and `(chainId, transactionHash, logIndex)` as an optimistic
pre-confirmation identity that can be rolled back.

Duplicate logs must be idempotent. A replay should not double-count credits,
bids, supply, or randomness state if the same confirmed log is seen twice.

## Indexed Entities

Minimum local entities:

| Entity | Primary key | Main sources |
| --- | --- | --- |
| `ReleaseArtifactSnapshot` | `releaseManifestSha256` | release manifest, release checksums, ABI checksums, event topic catalog |
| `ContractDeployment` | `chainId:contractAddress` | address book and deployment manifest |
| `Collection` | `chainId:coreAddress:collectionId` | `CollectionCreated`, collection reads, metadata reads |
| `Token` | `chainId:coreAddress:tokenId` | ERC-721 `Transfer`, metadata reads, burn reads |
| `DropExecution` | `chainId:dropsAddress:dropId` | `DropAuthorizationConsumed`, `DropAuthorizationCancelled`, signer reads |
| `Auction` | `chainId:auctionAddress:tokenId` | `AuctionRegistered`, bid/settlement/cancellation events, auction reads |
| `CreditAccount` | `chainId:contractAddress:creditType:account` | fixed-price, auction, curator, and protocol credit events plus reads |
| `RandomnessRequest` | `chainId:randomizerAddress:requestId` | randomizer lifecycle events and reads |
| `MetadataState` | `chainId:coreAddress:tokenId` or `collectionId` | `MetadataUpdate`, `BatchMetadataUpdate`, freeze/dependency events, metadata reads |
| `ContractMetadataState` | `chainId:contractMetadataAddress` | `ContractURIUpdated`, adapter reads, release manifest/address book |
| `ProvenanceManifest` | `chainId:coreAddress:collectionId:tokenId:provenanceId` | `release-artifacts/latest/one-of-one-provenance-manifest.json` and checksum-covered provenance descriptors |
| `AdminRole` | `chainId:adminsAddress:roleKey:account:target:selector` | role update events and admin reads |
| `PauseDomain` | `chainId:adminsAddress:domain` | `PauseUpdated` and pause reads |
| `DependencyVersion` | `chainId:registryAddress:dependencyNameAndVersion:version` | dependency registry events and registry reads |
| `CuratorRoot` | `chainId:curatorsPoolAddress:collectionId:rootEpoch` | `MerkleRootUpdated` |

Token IDs are globally unique inside `StreamCore`; collection membership still
belongs in the token entity because collection-scoped queries are expected.

## Event Processing Rules

Use the generated event topic catalog for event signatures, indexed fields, and
emitter contracts. The current catalog includes these high-value event groups:

| Group | Events | Primary update |
| --- | --- | --- |
| ERC-721 | `Transfer`, `Approval`, `ApprovalForAll` | Token owner, mint, burn, approval, and operator state |
| Metadata | `MetadataUpdate`, `BatchMetadataUpdate`, `CollectionFrozen`, `DependencyVersionPinned`, `TokenBurned`, `ContractURIUpdated` | Token URI refresh, collection freeze, dependency pin, live-token state, contract-level metadata refresh |
| Drop authorization | `DropAuthorizationConsumed`, `DropAuthorizationCancelled`, `SignerEpochChanged`, `DropSignerChanged`, `AuctionContractChanged` | Drop execution, replay/cancellation state, signer lifecycle, auction bridge address |
| Minter bridge | `CollectionPhasesUpdated`, `MinterTokensMinted`, `MinterAuctionMinted`, `MinterAuctionEndTimeUpdated`, `MinterContractReferenceUpdated` | Public phase windows, fixed-price mint ranges, original auction bridge custody/end time, and minter contract references |
| Fixed-price credits | `FixedPriceCreditCreated`, `FixedPriceCreditWithdrawn` | Poster, protocol, curator reserve, and withdrawal views |
| Auction lifecycle | `AuctionRegistered`, `AuctionCustodyConfirmed`, `AuctionStatusChanged`, `AuctionExtended`, `AuctionCancelled`, `ClaimAuction`, `NoBidSettlementPending`, `NoBidTokenClaimed` | Auction state, custody, end time, settlement, no-bid claimant |
| Auction credits | `Participate`, `OutbidCreditCreated`, `BidderCreditWithdrawn`, `AuctionProceedsCreditCreated`, `ProceedsCreditWithdrawn` | Highest bid, bidder refunds, poster/protocol/curator proceeds, withdrawals |
| Curators | `Reward`, `MerkleRootUpdated`, `CuratorCreditCreated`, `CuratorCreditWithdrawn` | Curator roots, rewards, credits, and withdrawals |
| Randomizer | `RandomnessRequested`, `RandomnessFulfilled`, `RandomnessRequestMarkedStale`, `RandomnessPostProcessingFailed`, `RandomnessPostProcessingRetried`, `RandomnessPostProcessingRetryFailed`, `BurnedTokenRandomnessRecorded`, provider `RequestFulfilled` | Request state, derived seed, raw output hash, retry count, stale/failure status |
| Governance | `GlobalAdminUpdated`, `FunctionAdminUpdated`, `PauseGuardianUpdated`, `UnpauseAdminUpdated`, `SignerManagerUpdated`, `SignerLifecycleTargetUpdated`, `PauseUpdated`, `EmergencyRecipientUpdated`, `OwnershipTransferred` | Admin permissions, pause domains, emergency recipient, ownership |
| Dependencies | `DependencyVersionCreated`, `DependencyVersionDeprecated` | Immutable dependency records and deprecation status |
| Emergency accounting | `Withdraw`, `EmergencyWithdrawal` | Legacy withdrawal events and surplus emergency withdrawal audit trail |

`MinterContractReferenceUpdated.option` uses the existing
`StreamMinter.updateContracts` option mapping: `1` is the core contract
reference, `2` is the admin contract reference, and `3` is the drops contract
reference. Indexers can filter by `option`, `newContract`, and `admin`; the
previous reference is retained in event data. Invalid options remain no-ops and
unchanged references do not emit a phantom reference-update event.

When an event is insufficient to derive the full entity, queue a read-after-event
task instead of guessing.

## Read-After-Event Calls

Required read-after-event calls by surface:

| Surface | Trigger | Reads |
| --- | --- | --- |
| Collection | `CollectionCreated`, `CollectionFrozen`, `CollectionRandomizerUpdated`, `DependencyVersionPinned` | collection info views, randomizer address/epoch, freeze manifest hash, dependency version state |
| Contract metadata | `ContractURIUpdated` | `contractURI()`, `contractURIHash()`, `streamCore()`, `adminsContract()` from the adapter address in the selected address book |
| Token | ERC-721 `Transfer`, `TokenBurned`, `MetadataUpdate` | `ownerOf` when minted and not burned, `tokenURI`, token metadata state, collection membership |
| Drop | `DropAuthorizationConsumed`, `DropAuthorizationCancelled`, `SignerEpochChanged`, `DropSignerChanged` | `isDropConsumed(dropId)`, `isDropCancelled(dropId)`, `tdhSigner()`, `signerEpoch()` |
| Minter bridge | `CollectionPhasesUpdated`, `MinterTokensMinted`, `MinterAuctionMinted`, `MinterAuctionEndTimeUpdated`, `MinterContractReferenceUpdated` | `retrieveCollectionPhases(collectionId)`, token ownership/metadata reads after mint, `getAuctionStatus(tokenId)`, `getAuctionEndTime(tokenId)`, minter `gencore()` and `streamDrops()` references |
| Fixed-price credit | `FixedPriceCreditCreated`, `FixedPriceCreditWithdrawn` | poster/protocol/curator reserve credit views, `totalFixedPriceOwed()`, `totalReserved()`, `surplus()` |
| Auction | `AuctionRegistered`, `AuctionStatusChanged`, `AuctionExtended`, `Participate`, `ClaimAuction`, `AuctionCancelled`, `NoBidTokenClaimed` | `auctionRecords(tokenId)`, `retrieveAuctionStatus(tokenId)`, `retrieveAuctionEndTime(tokenId)`, `minimumNextBid(tokenId)` when active, `auctionHighestBid(tokenId)`, `auctionHighestBidder(tokenId)`, `retrieveNoBidAuctionClaimant(tokenId)` |
| Auction credit | `OutbidCreditCreated`, `BidderCreditWithdrawn`, `AuctionProceedsCreditCreated`, `ProceedsCreditWithdrawn` | bidder/poster/protocol/curator credit views, `totalAuctionBidEscrow()`, `totalBidderOwed()`, `totalProceedsOwed()`, `totalOwed()`, `totalReserved()`, `surplus()`, `emergencyWithdrawable()` |
| Randomizer | randomizer lifecycle events | pending/fulfilled/stale/failure request views where available, token metadata state, burned-token randomness state |
| Curator | `MerkleRootUpdated`, `Reward`, `CuratorCreditCreated`, `CuratorCreditWithdrawn` | current root epoch/root, curator credit views, total curator owed/reserved views |
| Admin | role/pause/emergency/ownership events | admin role reads, `isPaused(domain)`, emergency recipient, owner |
| Release artifact | new release checkout | release manifest, release checksums, ABI checksums, event topic catalog, interface IDs, address books, one-of-one provenance manifest |

Reads should happen at the same block as the triggering log when the RPC
supports historical reads. If historical reads are unavailable, store the log
as observed and mark the derived entity as requiring reconciliation from a
trusted full rescan.

## Collection And Token Reconstruction

For collection state:

1. Ingest `CollectionCreated(collectionId)`.
2. Read collection info and final-supply/minting state from `StreamCore`.
3. Ingest `CollectionRandomizerUpdated` and record the randomizer epoch.
4. Ingest `DependencyVersionPinned` and read dependency version state.
5. Ingest `CollectionFrozen` and record manifest hash, schema version, and
   admin.

For token state:

1. Treat ERC-721 `Transfer(address(0), to, tokenId)` as mint.
2. Read token metadata and collection membership after mint.
3. Treat ERC-721 `Transfer(from, address(0), tokenId)` plus `TokenBurned` as
   burn. If only one side is observed during optimistic processing, reconcile
   after confirmation.
4. Treat `MetadataUpdate(tokenId)` and `BatchMetadataUpdate(fromTokenId,
   toTokenId)` as cache invalidation events, not as proof that JSON is valid.
5. Re-read `tokenURI` and metadata state after metadata update events.

`CollectionFrozen` is a collection permanence event. It is not a replacement
for token-level `MetadataUpdate` unless a later contract change explicitly
emits both.

## Drop And Signature Reconstruction

`DropAuthorizationConsumed` is the canonical execution event for signed drops.
Index it by `dropId` and include signer, poster, recipient, payer,
collectionId, saleMode, tokenDataHash, deadline, and signerEpoch.

Use `DropAuthorizationCancelled` to mark cancelled drops before execution.
Use `SignerEpochChanged` and `DropSignerChanged` to invalidate stale signing
payloads in operator dashboards. EIP-712 is encoding/signing only; replay state
comes from consumed/cancelled storage, signer epoch, domain separation, deadline,
and signer-service nonce/salt policy.

For fixed-price drops, combine `DropAuthorizationConsumed`, ERC-721 `Transfer`,
and `FixedPriceCreditCreated` events. For auction drops, combine
`DropAuthorizationConsumed`, ERC-721 `Transfer` to auction custody, and
`AuctionRegistered`.

## Auction Reconstruction

Canonical auction states for indexing:

| State | How to derive |
| --- | --- |
| `None` | No auction record exists |
| `Created` | `AuctionRegistered` observed, before active status/custody confirmation is reconciled |
| `Active` | Auction status/read says active and `block.timestamp <= endTime` |
| `EndedNoBid` | Active auction past end time with no highest bid; view-derived, no event required |
| `EndedWithBid` | Active auction past end time with highest bid; view-derived, no event required |
| `SettledNoBid` | `NoBidTokenClaimed` or direct no-bid settlement plus final owner/custody read |
| `SettledWithBid` | `ClaimAuction`, proceeds credits, and ERC-721 `Transfer` to winner reconciled |
| `Cancelled` | `AuctionCancelled` or cancelled status read |

`MinterAuctionMinted` records the original bridge custody target and end time
at mint. `MinterAuctionEndTimeUpdated` records minter-side end-time edits.
`StreamAuctions.retrieveAuctionEndTime(tokenId)` is authoritative after
`AuctionExtended`. `StreamMinter.getAuctionEndTime(tokenId)` is only the
original or manually edited minter bridge value and can be stale after auction
contract extensions.
For source-file lookup, the deployed auction implementation is
[`smart-contracts/AuctionContract.sol`](../../smart-contracts/AuctionContract.sol)
and the minter bridge is
[`smart-contracts/StreamMinter.sol`](../../smart-contracts/StreamMinter.sol).

Outbid refunds become bidder credits through `OutbidCreditCreated`. Settlement
credits are emitted through `AuctionProceedsCreditCreated`. Withdrawals are
tracked through `BidderCreditWithdrawn` and `ProceedsCreditWithdrawn`, but a
failed withdrawal must not erase credit; read credit state after failures.

Use the auction flow guide for `posterBps`, `protocolBps`, `curatorBps`, and
`highestBid - posterCredit - curatorCredit` proceeds splits.

## Credit And Payment Reconstruction

Credit entities should be category-specific. Do not collapse poster, bidder,
curator, protocol, reserve, and surplus accounting into one generic balance.

Track at least:

- fixed-price poster credits;
- fixed-price protocol credits;
- fixed-price curator reserve credits;
- auction bidder credits;
- auction poster proceeds;
- auction protocol proceeds;
- auction curator proceeds;
- curator pool credits;
- total owed views;
- total reserved views;
- surplus; and
- emergency withdrawable balance.

Forced ETH cannot reliably emit an event at receipt time. Use total owed,
reserved, balance, surplus, and emergency-withdrawable reads to reconcile
surplus rather than assuming every balance change has a log.

## Randomizer Reconstruction

Index randomizer requests by `(randomizerAddress, requestId)` and also store
`collectionId`, `tokenId`, provider, and randomizerEpoch.

Process:

1. `RandomnessRequested` as pending.
2. `RandomnessFulfilled` as fulfilled and metadata-refresh relevant.
3. `RandomnessRequestMarkedStale` as stale.
4. `RandomnessPostProcessingFailed` as fulfillment received but post-processing
   failed.
5. `RandomnessPostProcessingRetried` as retry success with retryCount.
6. `RandomnessPostProcessingRetryFailed` as retry failure with retryCount.
7. `BurnedTokenRandomnessRecorded` as an audit event for burned-token
   randomness without restoring token ownership.
8. Provider-level `RequestFulfilled` as a provider event that must be joined
   back to protocol lifecycle events before product state changes.

The app-facing state should distinguish pending, fulfilled, stale, failed, and
retry-failed rather than exposing a single "randomness error" state.

## Metadata And Dependency Reconstruction

Metadata cache invalidation should be driven by ERC-4906 events plus protocol
events:

- `MetadataUpdate(tokenId)` invalidates one token;
- `BatchMetadataUpdate(fromTokenId, toTokenId)` invalidates a token range;
- `DependencyVersionPinned` changes collection rendering dependencies;
- `DependencyVersionCreated` and `DependencyVersionDeprecated` update the
  dependency registry model;
- `CollectionFrozen` records frozen collection state and manifest hash;
- `ContractURIUpdated` invalidates the contract-level metadata adapter record;
- `TokenBurned` plus ERC-721 transfer-to-zero marks a token as burned.

Re-read token JSON after metadata invalidation. ERC-4906 events expose update
signals; they do not prove marketplace ingestion, cache purge, or JSON validity.
Re-read `contractURI()`, `contractURIHash()`, `streamCore()`, and
`adminsContract()` after `ContractURIUpdated`. `contractURIHash()` is
`keccak256(bytes(contractURI()))` over the exact stored URI bytes, with no URI
normalization. That event is not ERC-4906 and does not imply token-level JSON
changed.

For 1/1 provenance, build a `ProvenanceManifest` entity from the generated
release artifact catalog, not protocol logs. The current model is artifact-only:
it is separate from `tokenURI`, separate from `contractURI()`, and not included
in `collectionFreezeManifestHash(collectionId)`. Treat provenance catalog
changes as release artifact/checksum changes. Do not infer marketplace display,
ownership, royalties, or token finality from provenance records.

## Governance And Pause Reconstruction

Admin and pause state is event-backed but should still be read after event:

- `GlobalAdminUpdated`;
- `FunctionAdminUpdated`;
- `PauseGuardianUpdated`;
- `UnpauseAdminUpdated`;
- `SignerManagerUpdated`;
- `SignerLifecycleTargetUpdated`;
- `PauseUpdated`;
- `EmergencyRecipientUpdated`; and
- `OwnershipTransferred`.

Pause domains should be indexed by bytes32 domain and displayed with the
human-readable domain labels from docs/tests where available, such as
`DROP_EXECUTION`, `AUCTION_BID`, and `AUCTION_SETTLEMENT`.

## Confirmation And Reorg Policy

Use a conservative confirmation depth for product-visible finalized state.
Until the project has retained live chain evidence, the local baseline policy is:

- process new logs as optimistic;
- expose optimistic UI state as pending;
- mark state final only after the configured confirmation depth;
- retain a rollback window longer than the confirmation depth;
- compare stored blockHash for every block in the rollback window;
- on mismatch, roll back all logs at and after the first divergent block;
- replay from the last confirmed ancestor; and
- re-run read-after-event reconciliation for affected entities.

Confirmation depth is chain and deployment specific. This repo does not yet
claim a production confirmation depth for mainnet, testnet, or marketplace
indexing.

## Full Rescan And Recovery

A full rescan should be possible from:

1. selected release manifest;
2. selected address book;
3. selected event topic catalog;
4. deployment start block;
5. current block target;
6. parser version; and
7. accepted known gaps.

During full rescan:

- clear optimistic state for the namespace;
- process confirmed logs in order;
- apply idempotent updates by log identity;
- queue read-after-event reconciliation;
- compare generated entity counts/checksums if available;
- persist the source artifact hashes used; and
- record unresolved read failures as explicit repair tasks.

Do not silently fill missing logs from current reads unless the entity is marked
as read-derived. Current reads cannot reconstruct historical order.

## Event And Read Gaps

Known local-baseline gaps to track as follow-up work:

| Gap | Impact | Follow-up |
| --- | --- | --- |
| Derived `EndedNoBid` and `EndedWithBid` have no event | Indexer must derive from end time and bid reads | `CON-002` added minter bridge events; a later auction-contract slice should decide whether explicit end events are worth adding |
| Some no-bid settlement paths require ERC-721 `Transfer` plus reads | Recipient/custody can be ambiguous from one event alone | Keep read-after-event reconciliation mandatory |
| Forced ETH has no receipt event | Surplus can change without protocol logs | Reconcile from balance/owed/surplus reads |
| Historical reads may be unavailable on some RPC providers | Entity reconstruction can be less precise | Require archive RPC or mark read-derived repair tasks |
| Marketplace ingestion is not proven | Event correctness does not prove marketplace display | Keep marketplace evidence as future public-beta/production evidence |
| Retained marketplace/indexer evidence is missing | Local replay docs do not prove OpenSea, Reservoir, Blur, Manifold, or equivalent collector/indexer tooling behavior | Keep `fork_testnet_marketplace_indexer_evidence` and `live_marketplace_indexer_evidence` missing until reviewed retained evidence is linked |
| Live reorg behavior is not retained | Local tests do not prove chain-specific finality | Keep non-local event replay evidence as future Gate G work |

Missing event fields belong in `CON-002`. Missing public/read-adapter views
identified by this spec belong in `CON-003`.

These gaps are documentation and release-readiness concerns for this PR. They
must not be hidden by frontend assumptions.

## Validation Commands

Run these when editing this guide:

```sh
python scripts/test_events_and_indexing.py
python scripts/check_events_and_indexing.py
python scripts/test_typescript_event_decoding_indexer.py
python scripts/check_typescript_event_decoding_indexer.py
python scripts/test_integration_conformance_fixtures.py
python scripts/check_integration_conformance_fixtures.py
python scripts/test_one_of_one_provenance_manifest.py
python scripts/check_one_of_one_provenance_manifest.py
python scripts/generate_one_of_one_provenance_manifest.py --check
python scripts/test_integrations_readme.py
python scripts/check_integrations_readme.py
python scripts/test_marketplace_indexer_evidence.py
python scripts/check_marketplace_indexer_evidence.py
python scripts/test_release_readiness.py
python scripts/check_release_readiness.py
python scripts/test_release_manifest.py
python scripts/generate_release_manifest.py --check
python scripts/test_bytecode_release_proof.py
python scripts/generate_bytecode_release_proof.py --check
python scripts/test_release_checksums.py
python scripts/generate_release_checksums.py --check
python scripts/check_changelog.py
forge test --match-path test/StreamEventReconstructability.t.sol
forge test --match-path test/StreamMinterEvents.t.sol
```

If release-manifest-tracked docs or scripts changed, regenerate and check the
release manifest, bytecode proof, and checksum bundle.

## Maintenance

Update this guide when any of these change:

- event signature, indexed field, or emitting contract;
- ABI checksum or event topic catalog generation;
- deployment manifest or address book schema;
- drop authorization event fields;
- auction state, custody, bid, settlement, or credit behavior;
- fixed-price payment behavior;
- metadata, ERC-4906, burn, freeze, or dependency behavior;
- 1/1 provenance artifact, descriptor, or indexer entity behavior;
- randomizer request lifecycle behavior;
- admin, pause, signer, or ownership behavior;
- confirmation depth or reorg policy; or
- public-beta, marketplace, or live indexer evidence posture.
