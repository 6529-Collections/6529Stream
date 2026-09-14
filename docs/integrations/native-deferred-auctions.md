# Native deferred English auctions

`StreamNativeEnglishAuction` runs an English auction whose winning token is
minted and paid for atomically at settlement. Its implemented profile is a
singleton collection PROFILE, exact `tokenData`, and a disabled mint gate.
Optional NFTDelegation delivery is supported. Custody-start auctions, curated
leaves, additional rights modes and enabled gates remain separate required work.

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

## Tested behavior

Fifteen actual auction cases pass, including a 256-input configuration property,
signed bids, no-bid completion, pause/deadline behavior, settlement, receiver
claims and original delegation. Named Safe 1.4.1 cases cover settlement failure
and identical signed retry, and delegated refund failure/nonce rollback/retry.
The fixture uses the actual Core, Manager, ledger, revenue contracts and
NFTDelegation, with typed governance, Artist and entropy boundaries.

The reviewed via-IR house runtime is 19,453 bytes, with fixed linked registration
and settlement libraries; every production product in that capture fits the
runtime limit. Whole-transaction capacity, complete operator wiring, additional
auction profiles and a matching full-v1 candidate remain open in the
[delivery ledger](../../ops/V1_DELIVERY.md).
