# Native deferred English auctions

`StreamNativeEnglishAuction` runs an English auction whose winning token is
minted and paid for atomically at settlement. Its implemented profile is a
singleton collection PROFILE with exact `tokenData`. A disabled gate and the
original published curated-content gate are supported, with optional NFTDelegation
delivery. The separate custody-start API mints before bidding, then sells that
original token. Additional rights modes and other gate profiles remain required
work.

Use [IStreamNativeEnglishAuction](../../smart-contracts/interfaces/stream/auctions/IStreamNativeEnglishAuction.sol)
for lifecycle calls and
[IStreamNativeAuctionDelegatedDelivery](../../smart-contracts/interfaces/stream/auctions/IStreamNativeAuctionDelegatedDelivery.sol)
for the optional delivery and claims extension. The historical V2 house and
signatures remain separate. Build signing payloads from this house's exact ABI
and domain; old V2 signatures cannot be reused.

## Configure and fund a sale

Deploy with the real Core, Manager, official primary-sale recorder, revenue
products, Artist authority, reveal-fee escrow and governance dependencies.
The Manager owner must complete the one-time
[prepared recorder binding](prepared-native-settlement.md#bind-the-official-recorder).
Register the house under `NATIVE_PREPARED_SALE_ADAPTER` with its required
interface/version, and install it as the appropriate phase executor. Preserve
original artist sale consent and phase policy when registering an auction.

`registerAuction` fixes the configuration, artwork bytes, original artist
association and lifecycle. `bid` accepts a public payer transaction;
`bidSigned` accepts the distinct signed bid authorization with its payer,
executor, delivery address, amount, fee limit and absolute settlement ceiling.
Permissionless settlement retains the saved winning executor.

Preset and first-bid clocks follow [ADR 0043](../adr/0043-deferred-auction-clocks-and-no-bid.md).
The first accepted bid starts a first-bid clock once. Anti-snipe extensions are
capped; overlapping global and local pauses contribute their union, not duplicate
time. `auctionDeadlines` exposes the current end, finalize deadline, signed
ceiling and pause toll. A signed absolute ceiling is not extended by a pause.

## Settle, deliver and claim

`settle` invokes the actual Manager's prepared operation. The fixed official
recorder settles payment during its authenticated callback. The house takes
custody of the completed NFT, then attempts a bounded safe transfer. A failed
receiver creates an NFT claim instead of losing the completed sale. Read
`auction` and the settlement/delivery events to distinguish those outcomes.

Outbid amounts and applicable retained reveal fees become pull credits. Read
`refundableBalance(saleId, account)`, then call `claimRefund`. Original own claims
retain their documented escape from current-dependency checks. Delegated claims
require the declared original registry's current grant and cannot redirect the
original credited account. A delivery binding already established for a bid is
retained without requiring a new grant on every later bid.

An eligible expiry or accepted nontransient unlock refunds the bid and retained
reveal fee. Preset no-bid completion produces no NFT, revenue or NFT claim.
Terminal clock snapshots remain stable. Use the explicit status and events;
a completed call does not imply that an NFT was minted.

## Publish and sell curated works

Use [IStreamNativeCuratedAuction](../../smart-contracts/interfaces/stream/auctions/IStreamNativeCuratedAuction.sol)
for the curated entrypoint. Each declared work has a `contentId`, the hash of its
exact `tokenData` bytes, and a preview URI. Content IDs identify published works;
Core still assigns sequential token IDs at settlement.

1. Read `nextCuratedSaleId(collectionId, phaseId)` to obtain the expected sale
   nonce and sale ID. This is an optimistic coordinate, not a reservation.
2. Deploy `StreamNativeAuctionContentGate` for that Manager, house, sale,
   collection, phase and context counter. Supply the complete rows in strictly
   increasing content-ID order. The gate retains their canonical bytes, count,
   manifest hash and Merkle root. A zero content ID and empty artwork bytes are
   valid when explicitly published with their correct hash and a preview URI.
3. Register the exact gate as `6529STREAM_MINT_GATE_V1`, version
   `NATIVE_CURATED_GATE_V1`, with `IStreamMintGate`, its runtime hash and
   `gateConfigHash`. Configure the phase with `maxBatchQuantity=1`, the same gate
   and an enabled CONTEXT counter with STATIC cap one, STATIC increment one and
   a nonzero counter-configuration hash. Authorize the original house as phase
   executor. Preserve the required Artist consent for the resulting policy.
4. Build the selected work's proof and the original platform/artist creation
   authorizations. Call `registerCuratedAuction` with the exact artwork bytes,
   selection and expected sale nonce. If another registration has consumed that
   nonce, rebuild the sale-bound publication and authorizations; retrying an old
   immutable gate cannot change its sale ID.
5. Bid and settle through the ordinary house lifecycle. Manager independently
   verifies the retained publication, selected bytes and counter admission before
   its original prepared mint. The official recorder retains the exact content
   evidence alongside payment; failed completion rolls back the operation.

A claimed root or count without the matching complete retained manifest cannot
open a sale. The ordinary Manager entrypoints cannot bypass the selected curated
content admission. Preview URIs are declarations; publication does not prove that
an external service will continue serving their contents. The
[current fixture](../../test/helpers/NativeCuratedAuctionFixture.sol) gives the
complete ordering, proof construction and signing example.

## Mint into custody before bidding

Use [IStreamNativeCustodyAuction](../../smart-contracts/interfaces/stream/auctions/IStreamNativeCustodyAuction.sol)
for this versioned acquisition path. Before opening a sale, the original Executor
must bind the ACTIVE house once through
[IStreamNativeCustodyPrimarySettlement](../../smart-contracts/interfaces/stream/revenue/IStreamNativeCustodyPrimarySettlement.sol).
`custodyHouseTransition(house)` supplies the exact scope and old/new commitments
for a class-one, zero-value `bindCanonicalCustodyHouse(house)` governance action.
Read back `canonicalCustodyHouse()` and its event after delayed execution.

`registerCustodyAuction` requires the exact configuration and artwork hashes,
expected sale nonce, token ID, collection serial, Manager operation nonce,
context, executor, fee deposit, artist and signed nonce/deadline. Build both
platform and artist signatures from `custodyAcquisitionDigest`. These coordinates
are optimistic; registration checks them against the actual original mint and
reverts atomically if they have changed. The ordinary creation signature is not
a custody-acquisition authorization.

Registration mints one token into the house without recording sale revenue.
Read `custodyOrigin(auctionId)` and `NativeAuctionCustodyAcquired` for the retained
Manager, operation and original mint evidence. Bidding uses the normal house
calls. At paid settlement the recorder authenticates this origin, records the
payment and delivers the same NFT. It does not mint again or consume the mint
phase again. Payment evidence and original acquisition evidence remain distinct.

A failed receiver leaves a claim for the original token. No-bid, cancellation
and accepted terminal escape paths preserve the poster's NFT claim and applicable
payer refunds; releasing custody invalidates its sale origin. The current
[fixture](../../test/helpers/NativeCustodyAuctionFixture.sol) demonstrates the
complete sequence and signed Safe failure/repair/retry.

## Tested behavior

Fifteen actual auction cases pass, including a 256-input configuration property,
signed bids, no-bid completion, pause/deadline behavior, settlement, receiver
claims and original delegation. Named Safe 1.4.1 cases cover settlement failure
and identical signed retry, and delegated refund failure/nonce rollback/retry.
The fixture uses the actual Core, Manager, ledger, revenue contracts and
NFTDelegation, with typed governance, Artist and entropy boundaries.

The curated increment passes 42 cases across the curated, existing auction,
prepared settlement and companion suites, including three 256-input properties.
Its nine curated cases include complete retained publication, wrong proofs and
bytes, ordinary-entry bypass rejection, gate incidents, sequential Core tokens
and identical signed Safe retry. That pre-custody capture fits the runtime limit for every production product. Whole-transaction capacity, complete operator wiring,
additional
auction profiles and a matching full-v1 candidate remain open in the
[delivery ledger](../../ops/V1_DELIVERY.md).

The custody increment retains 42 unchanged cases and passes nine corrected
custody cases: 51 unique cases with four 256-input properties, independently
reviewed. The accepted house is 24,220 bytes, Manager 21,504 and recorder 24,510;
all production products in that capture fit. This covers the described original
mint, paid transfer, incident claims and Safe retries; broader rights and complete
Safe/operator activation remain separately tracked.
