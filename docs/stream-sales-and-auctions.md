# Stream Sales And Auctions

Specification status: Draft. This document follows
[`docs/spec-policy.md`](spec-policy.md) and implements
[ADR 0010](adr/0010-world-class-spec-pass.md) decision D5. It is a new
protocol v1 specification: the sale and auction layer enters the genesis
inventory at the same EIP-grade depth as the mint, ledger, and revenue
specifications instead of remaining an integration sketch.

This document is the normative home for primary-sale mechanics: the sale
adapter conformance profile and its registry governance, sale identity,
signed sale authorizations, English auctions, Dutch auctions with the
uniform-clearing rebate mode, private and direct sales, offer acceptance,
refund-window sales, burn-to-mint and burn-to-redeem gate modules, the
delegated-mint gate, pick-your-piece content selection, and the sealed-bid
and ranked-auction extension profiles. Other documents cite these
definitions and must not restate them (ADR 0010 decision D3.1).

Boundaries with the neighboring homes:

1. [`docs/revenue-splits-and-royalties.md`](revenue-splits-and-royalties.md)
   owns settlement semantics: split profiles, split wallets, revenue escrow,
   official settlement evidence, the `PRE_REVENUE_SINGLE_STEP` and
   `PREPARED_MINT` paid-mint orchestration paths, the ERC-20
   `PaymentIntent` boundary, and primary policy hashes. This document
   defines when and in what order adapters invoke those surfaces, never how
   settlement itself works.
2. [`docs/mint-policy-and-accounting.md`](mint-policy-and-accounting.md)
   owns mint policy, counters, the durable mint ledger, signed mint
   tickets, gates, the module registry, policy grace windows, and the
   prepared-mint operation identity. Adapters are mint executors under that
   specification.
3. The artist identity, consent, and sanction model lives in
   [`docs/stream-artist-authority.md`](stream-artist-authority.md) (ADR 0010 decision D2). Sale
   configuration for artist-bound collections inherits the consent
   requirements stated in
   [`docs/mint-policy-and-accounting.md`](mint-policy-and-accounting.md#artist-consent-modes).
4. The Governed Gas Parameter model (ADR 0010 decision D1) lives in
   [`docs/stream-long-term-architecture.md`](stream-long-term-architecture.md).
   Every external-call gas bound in this document is a Governed Gas
   Parameter under that model.

## Design Summary

```text
Sale adapters (Replaceable, registry-governed)
  StreamFixedPriceSaleAdapter   fixed price, open edition, refund-window mode
  StreamEnglishAuctionHouse     reserve auctions with anti-snipe extension
  StreamDutchAuctionAdapter     descending price, optional clearing rebates
  StreamPrivateSaleAdapter      allowlist-of-one direct sale, offer acceptance

Gate modules (Replaceable, registry-governed)
  StreamBurnMintGate            burn-to-mint and burn-to-redeem
  StreamDelegateRegistryGate    delegate-registry eligibility checks

Extension profiles (Permanent interfaces, no genesis implementation)
  IStreamSealedBidAuction       commit/reveal sealed-bid auctions
  IStreamRankedAuction          multi-unit ranked/uniform-price auctions

Flow for every paid mint sale:
  buyer or executor
    -> sale adapter (price, asset, custody, sale authorization)
    -> revenue settlement (split wallet deposit or escrow; revenue spec)
    -> StreamMintManager.mint(...) or prepared-mint pair (mint spec)
    -> StreamMintLedger.consume(...)
    -> StreamCore mint hooks
```

Sale adapters are the protocol's price and mechanic layer. They are the only
contracts that hold buyer funds before official settlement, and they are
deliberately kept out of Core, the manager, and the ledger so that new sale
mechanics over the next decades are new Replaceable adapters behind frozen
interfaces, never Core changes.

## Scope And Permanence

Requirements [SSA-SCOPE]:

1. Permanent surfaces defined by this document must be final before
   deployment: the sale adapter conformance profile, the
   `IStreamSaleAdapter`, `IStreamBurnMintGate`, `IStreamDelegateRegistryGate`,
   `IStreamSealedBidAuction`, and `IStreamRankedAuction` interfaces, every
   hash preimage and EIP-712 typehash in
   [Domain Constants And Typehashes](#domain-constants-and-typehashes), the
   sale/auction event schemas, and the settlement orderings named in this
   document.
2. Every genesis adapter and gate implementation is Replaceable: immutable
   once deployed, retired or superseded only through module-registry
   lifecycle and pointer governance. New mechanics require their own
   accepted specs against the frozen interfaces.
3. Price schedules, sale calendars, allowlist and content manifests, and
   rehearsal evidence are Operational artifacts; where load-bearing they are
   hash-committed onchain by the rules below.
4. A sale mechanic not specified here and not covered by
   [Protocol v1 Exclusions](#protocol-v1-exclusions) does not exist in
   protocol v1; absence is prohibition for Permanent surfaces.

## Sale Identity And Records

Every sale program has one durable `saleId`; every auction additionally has
one durable `auctionId`. Both are Permanent preimages.

```solidity
bytes32 saleId = keccak256(abi.encode(
    STREAM_SALE_V1,
    uint256(block.chainid),
    address(saleAdapter),
    uint8(saleKind),
    uint256(collectionId),
    bytes32(phaseId),
    uint256(saleNonce)
));

bytes32 auctionId = keccak256(abi.encode(
    STREAM_AUCTION_V1,
    uint256(block.chainid),
    address(auctionContract),
    uint256(collectionId),
    uint256(localAuctionNonce),
    uint256(tokenId),
    bool(tokenIdKnown)
));
```

```solidity
enum SaleKind {
    FIXED_PRICE,
    OPEN_EDITION,
    ENGLISH_AUCTION,
    DUTCH_AUCTION,
    DUTCH_AUCTION_CLEARING,
    PRIVATE_SALE,
    OFFER_SALE,
    REFUND_WINDOW,
    BURN_TO_MINT,
    BURN_TO_REDEEM,
    SEALED_BID,
    RANKED_AUCTION
}
```

Requirements [SSA-IDENTITY]:

1. `saleNonce` and `localAuctionNonce` must be adapter-local monotonic
   counters; an adapter must never reuse a nonce.
2. `SEALED_BID` and `RANKED_AUCTION` are reserved enum values for the
   extension profiles below. Genesis adapters must reject configuration of
   reserved kinds; reserved values exist so sale records and event consumers
   never renumber (same posture as reserved counter modes in the mint spec).
3. Every sale record must bind: `saleId`, `saleKind`, `collectionId`,
   `phaseId`, accepted asset, price commitment (fixed price, reserve, or
   price schedule hash), sale time bounds, `expectedPrimaryPolicyHash`,
   `primaryPolicyMode`, and the mint-policy `policyHash` the adapter will
   bind at execution. The adapter computes `saleConfigHash` over the full
   record and emits it in `SaleConfigured`.
4. Sale records are append-only history: cancellation and exhaustion are
   status transitions, never record deletion.
5. Governed Gas Parameter values are excluded from `saleConfigHash` and from
   every sale, auction, and schedule preimage (ADR 0010 decision D1.3), so
   gas retuning never changes sale identity.

## Sale Adapter Conformance Profile

A sale adapter is any contract that (a) receives buyer funds or holds sale
custody, and (b) is granted mint-executor rights or settlement-caller
rights. This profile is the conformance bar every adapter — genesis or
future — must meet before it can be registered and granted those rights.

```solidity
interface IStreamSaleAdapter {
    function saleRecord(bytes32 saleId)
        external
        view
        returns (
            uint8 saleKind,
            uint256 collectionId,
            bytes32 phaseId,
            address asset,
            bytes32 saleConfigHash,
            bytes32 expectedPrimaryPolicyHash,
            uint8 primaryPolicyMode,
            uint8 status
        );

    function refundableBalance(bytes32 saleId, address account)
        external
        view
        returns (uint256);

    function claimRefund(bytes32 saleId, address to) external;
}
```

Requirements [SSA-ADAPTER]:

1. An adapter must bind, before accepting any buyer funds: the accepted
   asset, the price or committed price schedule, the sale deadline or time
   bounds, `expectedPrimaryPolicyHash` with `primaryPolicyMode`, and the
   mint-policy `policyHash` (or the grace-window predecessor hash permitted
   by the mint spec) that its manager call will carry.
2. An adapter must settle official revenue only through the revenue spec's
   settlement surfaces, and must mint only through `StreamMintManager`
   using exactly one of the revenue spec's paid orchestration paths for the
   transaction in which a token is minted against payment. Adapters never
   call Core mint hooks directly.
3. Custody rule: an adapter may hold buyer funds in adapter escrow before
   official settlement (bids, Dutch clearing overage, refund-window
   deposits, sealed-bid deposits). Adapter escrow is not official revenue;
   it must be excluded from every official-revenue counter, and it becomes
   official revenue only at the settlement step of a named order in this
   document. Holding funds in adapter escrow is not a third paid-mint
   order; the revenue spec's two-path rule governs only the transaction in
   which a token is minted against payment.
4. Every refund, rebate, outbid credit, and no-bid NFT claim must be
   pull-based through `claimRefund`/claim surfaces with
   checks-effects-interactions and a reentrancy guard. Adapters must never
   push ETH in bid, purchase, settlement, or cancellation paths.
5. Refunds and rebates are payable only from adapter escrow. Funds that
   have reached official settlement (split wallet deposit or protocol
   escrow credit) are never refundable by this layer; post-flush refunds
   are impossible by design (ADR 0010 decision D5.4), and adapters must
   document this boundary in their sale records and user surfaces.
6. No sale path may read `tx.origin` (static-analysis gate). `payer`,
   `initialRecipients`, `beneficiaries`, `executor`, and `authorizer` are
   explicit per the mint spec role model.
7. ERC-20 purchases additionally require the payer-signed `PaymentIntent`
   verified at the adapter boundary under the revenue spec's
   `[RSR-PAYMENT-INTENT]` rules; standing allowances alone are never
   spendable as official revenue (ADR 0010 decision D8.2). Fee-on-transfer,
   rebasing, and non-standard assets follow the revenue spec's exclusions.
8. Adapters that verify signatures must support EIP-712 and ERC-1271 with
   ERC-5267 domain exposure; contract-wallet verification gas is bounded by
   the `SALE_ERC1271_GAS_LIMIT` Governed Gas Parameter.
9. Every adapter external call that could brick a sale path (delegate
   registry reads, asset-policy reads, ERC-1271 verification) must use a
   Governed Gas Parameter bound with the EIP-150 63/64 parent-gas precheck
   pattern.
10. Adapter events follow the schemas in [Events](#events); every event
    carries `schemaVersion` and at most three indexed fields.
11. Adapters must expose the module identity surface
    (`streamModuleType()` family) defined in
    [`docs/stream-long-term-architecture.md`](stream-long-term-architecture.md)
    and register per [Registry Governance](#registry-governance).
12. An adapter must be deployable and executable without any offchain
    dependency for its onchain guarantees: manifests and schedules are
    hash-committed, and every commitment must be verifiable from calldata
    and chain state alone.

### Registry Governance

Sale adapters were the least-governed extension surface in earlier drafts:
gates and resolvers were registry-checked while executors were plain
allowlisted addresses. Protocol v1 closes that asymmetry (ADR 0010 decision
D5.1).

Requirements [SSA-REGISTRY]:

1. Every contract granted phase-executor rights that settles payment,
   consumes signed sale authorizations, or holds sale custody must be
   registered `ACTIVE` in the canonical module registry
   ([`docs/stream-long-term-architecture.md`](stream-long-term-architecture.md)
   `[LTA-REGISTRY]`) with the sale-adapter module type and interface ID, a
   pinned `runtimeCodeHash`, and a `moduleVersion`, under the consumption
   rules of the mint spec
   ([`docs/mint-policy-and-accounting.md`](mint-policy-and-accounting.md)
   `[MPA-REGISTRY]`).
2. The manager must refuse `setPhaseExecutor(..., allowed = true)` for a
   contract executor on any phase whose policy declares payment settlement
   unless that executor satisfies requirement 1. EOA executors must never
   be granted executor rights on paid phases.
3. `DEPRECATED` adapters keep serving already-configured sales but must not
   be configured for new sales; `INCIDENT_REVOKED` adapters cause
   state-changing sale execution to revert, exactly as incident-revoked
   gates do in the mint spec ([MPA-REGISTRY] rule 4).
4. Adapter registration, deprecation, and blocking are governed actions
   under ADR 0004 action classes; adding an adapter or loosening its status
   is `DELAYED_LOOSENING`, blocking is `IMMEDIATE_TIGHTENING`.
5. The genesis adapter and gate set (Design Summary) must appear in the
   conformance-matrix genesis deployment profile, each with its named gate
   in [Conformance Gates](#conformance-gates) (ADR 0010 decision D5.10).

### Mechanic Families

| Family | Kind values | Genesis | Required bindings beyond [SSA-ADAPTER] |
| --- | --- | --- | --- |
| Fixed price | `FIXED_PRICE`, `OPEN_EDITION` | yes | unit price, per-sale supply bound or open-edition declaration |
| English auction | `ENGLISH_AUCTION` | yes | reserve, `minIncrementBps`, anti-snipe window/extension/cap |
| Dutch auction | `DUTCH_AUCTION`, `DUTCH_AUCTION_CLEARING` | yes | committed price schedule; clearing mode adds escrowed rebates |
| Private/direct | `PRIVATE_SALE`, `OFFER_SALE` | yes | bound buyer, price, deadline; offer digest for `OFFER_SALE` |
| Refund window | `REFUND_WINDOW` | yes | window length, escrow custody, finalize/refund rules |
| Burn programs | `BURN_TO_MINT`, `BURN_TO_REDEEM` | yes | source-collection set, burn proof, nullifier domain |
| Sealed/ranked | `SEALED_BID`, `RANKED_AUCTION` | interfaces only | extension profiles below |

## Signed Sale Authorization

Signed sale authority binds the economic policy of a sale to an explicit
signer. The payload completes the field inventory the review found
underspecified: price, asset, and deadline are bound, and the typehash is
pinned (ADR 0010 decision D3.5).

```text
SALE_AUTHORIZATION_TYPEHASH = keccak256(
    "SaleAuthorization(uint256 chainId,address saleAdapter,"
    "address mintManager,uint256 collectionId,bytes32 phaseId,"
    "bytes32 saleId,uint8 saleKind,uint8 revenueClass,"
    "bytes32 expectedPrimaryPolicyHash,uint8 primaryPolicyMode,"
    "bytes32 initialRecipientsHash,bytes32 beneficiariesHash,"
    "address payer,address executor,address asset,uint256 unitPrice,"
    "uint256 quantity,bytes32 contentSelectionHash,bytes32 policyHash,"
    "bytes32 nonce,uint64 deadline)"
);
```

Requirements [SSA-AUTH]:

1. The EIP-712 domain is
   `(name = "6529Stream Sales", version = "1", chainId, verifyingContract =
   saleAdapter)`, exposed through ERC-5267. Signatures are EOA ECDSA or
   ERC-1271; the mint spec's `[MPA-AUTHZ]` verification rules apply:
   recovered addresses must be nonzero and match, non-canonical `s` values
   are invalid, and the authorizer kind is explicit.
2. State-changing execution must recompute every hash from calldata and
   chain state and reject the authorization if any field differs, if
   `deadline` has passed, or if the nonce was consumed or voided.
3. `unitPrice` is denominated in the base units of `asset`
   (`asset = address(0)` for native ETH). A Merkle allowlist
   `priceOverride` (mint spec `[MPA-MERKLE]`) replaces `unitPrice` only
   when the proven leaf sets it, and the adapter must verify the same leaf
   it charges by.
4. `contentSelectionHash` is zero except for pick-your-piece sales, where
   it binds the selected content per
   [Pick-Your-Piece Content Selection](#pick-your-piece-content-selection).
5. Replay protection: the adapter must derive the mint-ledger
   `authorizationId` from the full EIP-712 digest per the mint spec
   `[MPA-TICKET]` derivation, so consuming the sale authorization and
   consuming the ledger replay key are the same fact.
6. Authorizers may revoke unused sale authorizations through the
   mint-ledger revocation surface (mint spec `[MPA-LEDGER]` rule 3,
   `[MPA-TICKET]` rule 5).
7. `expectedPrimaryPolicyHash` and `primaryPolicyMode`
   (`STRICT_MATCH`/`ALLOW_CURRENT`) follow the revenue spec's primary-sale
   authority rules; settlement events must expose observed drift.

## Fixed-Price Sales And Open Editions

Requirements [SSA-FIXED]:

1. A fixed-price purchase executes, in one transaction, the revenue spec's
   `PRE_REVENUE_SINGLE_STEP` or `PREPARED_MINT` path with the sale
   authorization (or public-sale record) bound per [SSA-AUTH].
2. Exact payment is required: native purchases revert unless
   `msg.value == unitPrice * quantity`; ERC-20 purchases follow the revenue
   spec's exact-delta rule. Overpayment is rejected, not credited.
3. `OPEN_EDITION` is `FIXED_PRICE` whose sale record declares no per-sale
   supply bound; collection supply mode and mint-ledger counters still
   bind. The sale record must state the close rule (end time or manual
   close), and close is one-way per sale.
4. Public sales (no per-buyer authorization) are supported: the adapter is
   the phase executor, the sale record is the authority, and per-wallet
   fairness comes from mint-ledger counters, the Merkle allowlist cap mode,
   or gates. The public path must still bind `payer`, recipients, and
   beneficiaries explicitly.
5. The genesis public fixed-price adapter is the account-abstraction
   reference path and must satisfy [SSA-AA].

## English Auctions

The English auction is the flagship 1/1 mechanic. This section ports the
hardening lessons of [ADR 0002](adr/0002-auction-custody.md) — explicit
escrow custody, pull refunds, idempotent terminal settlement,
contract-poster claim paths, pre-bid cancellation — onto the protocol v1
revenue and mint boundaries, and adds the two requirements the review found
missing everywhere: minimum bid increments and anti-snipe extension
(ADR 0010 decisions D5.1 and D8.10).

### Auction Configuration

```solidity
struct EnglishAuctionConfig {
    uint256 collectionId;
    bytes32 phaseId;
    uint256 tokenId;            // nonzero only for custody-held tokens
    bool mintAtSettlement;      // PREPARED_MINT at settlement when true
    address poster;             // no-bid NFT recipient (ADR 0001 lineage)
    uint96 reservePrice;        // may be zero (no reserve)
    uint16 minIncrementBps;     // required, see [SSA-ENGLISH] 3
    uint64 startTime;
    uint64 endTime;
    uint32 antiSnipeWindow;     // seconds, see [SSA-ENGLISH] 4
    uint32 antiSnipeExtension;  // seconds
    uint32 maxTotalExtension;   // seconds, cap over original endTime
    bytes32 expectedPrimaryPolicyHash;
    uint8 primaryPolicyMode;
}
```

### State Machine

```text
None -> Created            auction record written, custody expected
Created -> Active          custody confirmed (token held or mint deferred)
Active -> Active           valid bid; possible anti-snipe extension
Active -> Cancelled        only before the first valid bid
Active -> EndedNoBid       endTime passed, no valid bid
Active -> EndedWithBid     endTime passed, valid highest bid
EndedNoBid -> SettledNoBid NFT left escrow via poster transfer or claim
EndedWithBid -> SettledWithBid   settlement executed (terminal)
Cancelled, SettledNoBid, SettledWithBid are terminal
```

Requirements [SSA-ENGLISH]:

1. Custody: an auctioned pre-minted token must be held by the auction
   contract (or a dedicated custody contract preserving these invariants)
   from `Created` until settlement, cancellation, or no-bid claim.
   `Created -> Active` fires only when custody is confirmed; bids before
   custody confirmation revert. `payOutAddress`-style payment identities
   are never custody.
2. Bid validity: bids are native ETH in protocol v1 (ERC-20 bidding is
   excluded); a bid is valid only while `Active` and
   `block.timestamp < endTime`; the first valid bid must be
   `>= max(reservePrice, 1 wei)`.
3. Minimum increment: `minIncrementBps` must be configured in
   `[100, 10_000]` (1% to 100%) and should be at least `500`. A
   non-first bid must satisfy
   `bid >= highestBid + ceil(highestBid * minIncrementBps / 10_000)`.
   Increment configuration is bound into `saleConfigHash` and emitted at
   creation, making 1-wei outbid griefing structurally impossible.
4. Anti-snipe extension: `antiSnipeWindow` and `antiSnipeExtension` must be
   configured in `[60, 86_400]` seconds and should default to `600`. When a
   valid bid arrives with `endTime - block.timestamp < antiSnipeWindow`,
   the auction must extend:
   `endTime = max(endTime, block.timestamp + antiSnipeExtension)`, bounded
   so `endTime` never exceeds `originalEndTime + maxTotalExtension`.
   `maxTotalExtension` must be configured in
   `[antiSnipeExtension, 604_800]` seconds. Every extension emits
   `AuctionExtended`. A conformant English auction must configure a nonzero
   window; accepting snipe exposure is not configurable in protocol v1.
5. Outbid custody: when a bid is accepted, the previous highest bidder's
   funds must become a pull refund credit in the same transaction, and a
   reverting previous bidder must not block the new bid (no push refunds).
6. Settlement is permissionless once `block.timestamp >= endTime`, follows
   checks-effects-interactions, and is idempotent: repeated settlement
   attempts must not duplicate transfers, credits, state changes, or
   events.
7. With-bid settlement order (`AUCTION_SETTLEMENT_TRANSFER`, custody-held
   token): (a) verify ended, unsettled, winner exists and auction state
   matches the signed policy hash, payer, and amount; (b) mark
   `SettledWithBid` and write the winner, amount, `saleId`, and policy
   hash; (c) record the winning amount as official primary revenue through
   the revenue spec's deposit-or-escrow settlement boundary; (d) deliver
   the NFT: attempt the transfer to the winner, and if the winner is a
   contract whose receiver rejects, record a pull NFT claim (winner directs
   delivery to any receiver) rather than blocking settlement. Failed
   split-recipient hooks divert to owed escrow per the revenue spec and
   cannot revert settlement.
8. Mint-at-settlement variant (`mintAtSettlement = true`): settlement is a
   paid mint and must execute the revenue spec's `PREPARED_MINT` path in
   the settlement transaction, with `initialRecipients = [winner]` (or
   custody plus the rule 7 item (d) pull NFT claim path) and
   `beneficiaries = [winner]`.
9. Auction-start custody mint (`AUCTION_START_CUSTODY`): a token minted
   into auction custody before bidding is an unpaid custody mint, not a
   paid mint. The custody mint phase must set
   `initialRecipients[i] = beneficiaries[i] = auction custody` and must
   configure only `CONSTANT`, `EXECUTOR`, or `CONTEXT` keyed counters;
   `RECIPIENT`/`PAYER`-keyed counters are invalid on custody-mint phases
   because no final owner exists yet. Configuration must revert otherwise.
   Per-collector accounting for the auction lives in the sale record, and
   the custody-to-winner transfer at settlement is the economic delivery.
10. No-bid outcome: `EndedNoBid` settles the NFT to `poster`; an EOA poster
    receives a direct transfer, a contract poster receives a pull NFT
    claim, and `SettledNoBid` is recorded only after the NFT leaves escrow
    through either path. Reserve-not-met expiry is a no-bid outcome.
11. Cancellation exists only before the first valid bid and before
    `endTime`; it is terminal, evented with a reason hash, and releases
    custody to `poster`. After the first bid, emergency handling pauses new
    actions and preserves bidder credits; it never confiscates funds or
    strands the NFT.
12. Refund, proceeds, and NFT claims remain claimable forever; emergency or
    surplus withdrawals must never touch owed bidder credits, owed
    proceeds, or escrowed NFTs.
13. `auctionId` and `saleId` bind every bid, extension, settlement, and
    claim event, and settlement rejects if the signed policy hash, payer,
    recipient, executor, or amount does not match the auction state.

## Dutch Auctions

### Price Schedules

```solidity
enum DutchDecayKind {
    LINEAR,
    STEPPED
}

struct DutchPriceSchedule {
    uint96 startPrice;
    uint96 restingPrice;    // final price; > 0 in clearing mode
    uint64 startTime;
    uint64 endTime;         // schedule reaches restingPrice at endTime
    DutchDecayKind decayKind;
    uint32 stepSeconds;     // STEPPED only
    uint96 stepAmount;      // STEPPED only
}

bytes32 priceScheduleHash = keccak256(abi.encode(
    STREAM_DUTCH_SCHEDULE_V1,
    uint256(block.chainid),
    address(saleAdapter),
    bytes32(saleId),
    uint96(startPrice),
    uint96(restingPrice),
    uint64(startTime),
    uint64(endTime),
    uint8(decayKind),
    uint32(stepSeconds),
    uint96(stepAmount)
));
```

Requirements [SSA-DUTCH]:

1. The full schedule must be committed via `priceScheduleHash` in the sale
   record before the sale opens and is immutable for the sale's life.
   `startPrice >= restingPrice`, `endTime > startTime`, and for `STEPPED`,
   `stepSeconds > 0` and `stepAmount > 0`.
2. Current price is deterministic from the schedule and `block.timestamp`:
   `LINEAR` interpolates from `startPrice` to `restingPrice` over
   `[startTime, endTime]`; `STEPPED` subtracts `stepAmount` every
   `stepSeconds`; both floor at `restingPrice`, and the price after
   `endTime` is `restingPrice`.
3. Standard mode (`DUTCH_AUCTION`): each purchase pays the current schedule
   price and executes a standard paid mint path in the purchase
   transaction ([SSA-FIXED] rules 1 and 2 apply with
   `unitPrice = currentPrice`). No rebates exist in standard mode and the
   sale record must say so.

### Uniform-Clearing Rebate Mode

`DUTCH_AUCTION_CLEARING` gives every buyer the same clearing price while
keeping official settlement conformant: the guaranteed floor settles
immediately, and only the refundable overage waits in adapter escrow
(ADR 0010 decisions D5.1 and D5.4).

Requirements [SSA-DUTCH-CLEARING]:

1. Clearing mode requires `restingPrice > 0`.
2. Purchase at current price `p`: the adapter officially settles
   `restingPrice` per token through a standard paid mint path in the
   purchase transaction, and holds `p - restingPrice` per token in adapter
   escrow tagged to the purchase record. The token mints at purchase time.
3. The clearing price is fixed at finalization: if the sale sold out, the
   clearing price is the last accepted purchase price; otherwise it is the
   schedule price at the close (`restingPrice` when the schedule has fully
   decayed). Finalization is permissionless once the sale is sold out or
   closed, happens exactly once, and emits `DutchClearingFinalized`.
4. At finalization, for every purchase at price `p`:
   `clearing - restingPrice` per token flows from adapter escrow to
   official settlement as supplemental primary revenue under the same
   `saleId` and primary policy hash (`STRICT_MATCH` against the hash bound
   at sale creation), and `p - clearing` per token becomes a pull rebate
   credit for the payer, claimable forever.
5. Escrowed overage is refundable-class funds until finalization: it must
   never be counted, flushed, or released as official revenue before
   finalization, and after finalization only the supplemental-revenue part
   moves; rebates never touch official settlement. Post-finalization price
   changes, retroactive rebates from settled revenue, and rebate
   expiration are all invalid.

## Private And Direct Sales

Requirements [SSA-PRIVATE]:

1. A private sale is an allowlist-of-one: the sale record and the signed
   sale authorization bind exactly one buyer as payer and beneficiary, a
   price, an asset, a deadline, and optionally a `contentSelectionHash` or
   custody-held `tokenId`. Only the bound buyer (or their delegate under
   [Delegated Minting](#delegated-minting), delivering to the buyer) may
   execute.
2. Execution is a standard paid path per [SSA-FIXED] for mints, or
   `AUCTION_SETTLEMENT_TRANSFER` ordering ([SSA-ENGLISH] 7) for a
   custody-held token.
3. Expiry: an unexecuted private sale expires at `deadline`; expiry is
   evented and releases any custody per the no-bid claim rules.

### Offer Acceptance

Offer/accept-offer is the buyer-initiated form of a private sale.

```text
SALE_OFFER_TYPEHASH = keccak256(
    "SaleOffer(uint256 chainId,address saleAdapter,address core,"
    "uint256 collectionId,uint256 tokenId,bytes32 contentSelectionHash,"
    "address buyer,address asset,uint256 price,bytes32 nonce,"
    "uint64 deadline)"
);
```

Requirements [SSA-OFFER]:

1. A buyer signs a `SaleOffer` (EIP-712, domain per [SSA-AUTH] 1).
   `tokenId` is zero for collection-level mint offers;
   `contentSelectionHash` may bind a specific unminted work.
2. Acceptance authority is the seller side: an authorized sale signer for
   the collection countersigns a `SaleAuthorization` whose economic fields
   exactly match the offer, subject to the artist-consent requirements the
   mint spec pins for artist-bound collections.
3. Execution verifies both signatures, consumes both nonces, requires
   `block.timestamp <= min(offer.deadline, authorization.deadline)`, and
   settles per [SSA-PRIVATE] 2. For ERC-20 offers, the `SaleOffer` also
   satisfies the payer-intent role only if it meets every
   `[RSR-PAYMENT-INTENT]` field requirement; otherwise a separate
   `PaymentIntent` is required.
4. Offers are revocable before acceptance-execution through the
   authorization revocation surface (mint spec `[MPA-LEDGER]` rule 3,
   `[MPA-TICKET]` rule 5) using the offer digest as the replay key.
5. Standing orderbooks, collection-wide floor offers, and offer matching
   are excluded from protocol v1; a genesis offer targets one collection,
   token, or content selection at a time.

## Refund-Window Sales

Refund-window sales hold buyer funds in adapter escrow for a bounded
window; the sale becomes official — and the token mints — only at
finalization (ADR 0010 decision D5.4).

Requirements [SSA-REFUND]:

1. Purchase: the buyer deposits the full price into adapter escrow; the
   adapter records a purchase record with `purchaseId`
   (`keccak256(abi.encode(STREAM_SALE_V1, block.chainid, saleAdapter,
   saleId, buyer, purchaseNonce))`), quantity, amount, and
   `refundDeadline = purchaseTime + refundWindowSeconds`. No mint occurs at
   purchase.
2. `refundWindowSeconds` is pinned per sale in `[3_600, 2_592_000]`
   (1 hour to 30 days) and committed in `saleConfigHash`.
3. Refund: before `refundDeadline`, the buyer may claim a full refund of
   that purchase (pull, checks-effects-interactions); a refunded purchase
   is terminal and can never finalize.
4. Finalization: at or after `refundDeadline`, finalization of an
   unrefunded purchase is permissionless and executes the official paid
   mint through a standard paid path, moving exactly the escrowed amount to
   official settlement. Finalization is idempotent per purchase.
5. Funds in adapter escrow before finalization are never official revenue;
   after finalization no refund path exists. The sale record and buyer
   surfaces must state both boundaries.

## Burn-To-Mint And Burn-To-Redeem

Burn programs let holders convert existing Stream tokens into new works or
recorded redemptions. They compose the frozen primitives — owner/approved
burn with retained identity, gates, and manager-scoped nullifiers — into a
registry-governed gate module (ADR 0010 decision D5.1).

### Burn Proof And Nullifiers

```solidity
interface IStreamBurnMintGate /* also implements IStreamMintGate */ {
    function allowedSourceCollections(uint256 targetCollectionId)
        external
        view
        returns (uint256[] memory sourceCollectionIds);

    function burnNullifier(uint256 sourceTokenId)
        external
        view
        returns (bytes32);
}

bytes32 burnNullifier = keccak256(abi.encode(
    STREAM_BURN_NULLIFIER_V1,
    uint256(block.chainid),
    address(core),
    uint256(sourceTokenId)
));
```

Requirements [SSA-BURN]:

1. Genesis burn-to-mint requires a same-transaction burn executed by the
   burn executor: the executor must verify the caller is the source
   token's owner or approved operator, execute `Core.burn(sourceTokenId)`,
   and then verify through `tokenCollectionIdentity(sourceTokenId)` that
   the retained identity reports `burned = true` with the expected source
   collection, all before the manager mint call. Retained identity is the
   burn proof; because it is not transaction-scoped, replay is killed by
   the nullifier in requirement 2.
2. For every burned source token, the gate returns
   `burnNullifier(sourceTokenId)` in `GateResult.nullifiers`, and the
   manager consumes it through the mint ledger. Nullifier consumption is
   manager-scoped per the mint spec's ledger rules, and the burn gate's
   accepted nullifier domain is `STREAM_BURN_NULLIFIER_V1`.
3. The source-collection set, conversion ratio (sources burned per token
   minted), and any burn-window bounds must be pinned in the gate config
   hash inside the phase policy hash, so the burn program is part of the
   frozen mint policy.
4. Claiming credit for tokens burned outside the executing transaction
   (pre-burned claims) is excluded from protocol v1: retained identity does
   not attribute the burner, so an attributable burn-claim registry
   requires its own accepted spec. External-collection (non-Stream) burn
   sources likewise require their own accepted adapter spec.
5. A burn-to-mint mint is a paid or free mint like any other: paid burn
   programs use the revenue spec's paid paths; free programs use the
   standard manager path. The burn changes eligibility, never settlement
   ordering.

### Finality Interaction Rule

Burn programs interact with artwork finality in both directions, and the
choice is permanent (ADR 0010 decision D5.1):

Requirements [SSA-BURN-FINALITY]:

1. Source side: burning requires a live burn path. A frozen collection is
   non-burnable by default, and collection-scope artwork finality is always
   non-burnable (see the burn rules in
   [`docs/collection-metadata-contract.md`](collection-metadata-contract.md)
   and the finality requirements in
   [`docs/stream-long-term-architecture.md`](stream-long-term-architecture.md)).
   A collection intended as a future burn source must preserve an explicit
   burn path before freeze and must use scoped (token/release/season/view)
   finality, never collection-scope finality.
2. Target side: a burn-to-mint collection's supply grows as sources burn.
   It must either remain open under a declared burn-compatible supply mode
   (`CAPPED_OPEN` or `UNCAPPED_OPEN`) or use scoped finality for finalized
   works; collection-scope finality on a target ends its burn program
   permanently.
3. Operator tooling must surface both rules before any freeze or finality
   action on a collection referenced by a configured burn program
   (pre-freeze warning requirement).

### Burn-To-Redeem

Burn-to-redeem burns a token against a recorded offchain or physical
redemption, with no mint.

```solidity
bytes32 redemptionId = keccak256(abi.encode(
    STREAM_REDEMPTION_V1,
    uint256(block.chainid),
    address(saleAdapter),
    address(core),
    uint256(burnedTokenId)
));
```

Requirements [SSA-REDEEM]:

1. The redeem executor verifies owner/approved, burns the token, verifies
   retained identity per [SSA-BURN] 1, and emits `RedemptionRecorded` with
   `redemptionId`, the burned token identity, the redeemer, and a
   hash-committed fulfillment reference. No nullifier is needed: a burned
   token cannot burn again, and `redemptionId` is unique per token.
2. Fulfillment updates (`RedemptionFulfilled`) are append-only operator
   records; they never modify the original redemption record.
3. Redemption terms (what the burn redeems for) are hash-committed in the
   sale record before the program opens.

## Sealed-Bid And Ranked Auction Extension Profiles

Sealed-bid and ranked auctions are specified as extension profiles: the
interfaces and conformance requirements below are Permanent and frozen now,
and no genesis implementation exists (ADR 0010 decision D5.2). A future
implementation requires its own accepted module spec against these
interfaces.

```solidity
interface IStreamSealedBidAuction {
    function commitBid(bytes32 auctionId, bytes32 bidCommitment)
        external
        payable;

    function revealBid(
        bytes32 auctionId,
        uint256 amount,
        bytes32 salt
    ) external;

    function settleSealed(bytes32 auctionId) external;

    function bidCommitmentOf(bytes32 auctionId, address bidder)
        external
        view
        returns (bytes32 commitment, uint256 deposit, bool revealed);
}

interface IStreamRankedAuction {
    function placeRankedBid(bytes32 auctionId, uint256 amount)
        external
        payable;

    function settleRanked(bytes32 auctionId) external;

    function winningBids(bytes32 auctionId)
        external
        view
        returns (address[] memory bidders, uint256 clearingPrice);
}
```

Requirements [SSA-SEALED]:

1. Sealed-bid commitments must be
   `keccak256(abi.encode(STREAM_SEALED_BID_V1, block.chainid,
   auctionContract, auctionId, bidder, amount, salt))`; reveals recompute
   and match.
2. Deposits must equal or exceed the committed amount
   (overcollateralization hides the bid); the excess and every losing
   deposit become pull refunds at reveal or settlement.
3. Commit and reveal windows are pinned in the auction record; a deposit
   whose bid is never revealed must become refundable after the reveal
   window closes — unrevealed deposits are never confiscated unless the
   auction record declared an explicit, evented forfeiture policy at
   creation.
4. Ranked (multi-unit) settlement is uniform-price: the top `K` revealed or
   ranked bids win and every winner pays the lowest winning bid; the
   overage above the clearing price becomes a pull refund. Tie-breaking at
   the margin is first-committed-wins and must be deterministic from
   onchain order.
5. Settlement follows the [SSA-ENGLISH] custody, CEI, idempotence, and
   pull-refund rules, and official revenue flows through the same
   settlement boundaries. ERC-20 deposits are excluded exactly as ERC-20
   bids are.

## Delegated Minting

Delegated minting lets a hot wallet act while allowance and delivery bind a
vault. The delegate-registry gate is named at genesis (ADR 0010 decision
D5.6).

```solidity
interface IStreamDelegateRegistryGate /* also implements IStreamMintGate */ {
    function delegateRegistry() external view returns (address);

    function delegationUsecase() external view returns (bytes32);

    function isDelegated(
        address vault,
        address delegate,
        uint256 collectionId
    ) external view returns (bool);
}
```

Requirements [SSA-DELEGATE]:

1. The gate pins one delegate registry (a delegate.xyz-class
   `IDelegateRegistry` or the 6529 `NFTDelegation` contract) by address and
   codehash in its module-registry record. The registry is part of the gate
   config hash and therefore of the phase policy hash.
2. Delegation checks are live reads at `validateMint` time — never cached
   across transactions — accepting wallet-wide, contract-scoped (Core), or
   collection/usecase-scoped delegations per the pinned
   `delegationUsecase`. A revoked delegation must fail the next mint.
3. Registry reads are bounded `staticcall`s under the
   `DELEGATE_REGISTRY_GAS_LIMIT` Governed Gas Parameter with the 63/64
   parent-gas precheck; an unavailable registry fails closed (the gated
   mint reverts).
4. Genesis delegated-mint patterns:
   deliver-to-vault — `payer` is the hot wallet,
   `initialRecipients[i] = beneficiaries[i] = vault`, and
   `RECIPIENT`-keyed counters key the vault, so per-holder caps count the
   vault correctly; or signer-verified tickets — a `MintTicket` binds the
   vault as beneficiary after the ticket signer verified delegation.
5. Counting a vault's allowance while delivering to a different address
   requires the delegation counter-resolver extension
   (`CUSTOM_RESOLVER`, excluded from protocol v1 by the mint spec); it is
   not expressible with genesis counters. Keying per-holder counters to
   the acting hot wallet is non-conformant for per-holder limits, because
   one vault could multiply allowance across delegates (mint spec
   `[MPA-ACCOUNTS]`).

## Pick-Your-Piece Content Selection

Curated drops where the collector chooses a specific unminted work are
supported without reservations or serial choice (ADR 0010 decision D5.7).

```solidity
// leaf, double-hashed against second-preimage attacks:
bytes32 contentLeaf = keccak256(bytes.concat(keccak256(abi.encode(
    STREAM_CONTENT_LEAF_V1,
    uint256(block.chainid),
    address(saleAdapter),
    bytes32(saleId),
    bytes32(contentId),
    bytes32(tokenDataHash)
))));

bytes32 contentContextHash = keccak256(abi.encode(
    STREAM_CONTENT_CONTEXT_V1,
    uint256(block.chainid),
    address(saleAdapter),
    bytes32(saleId),
    bytes32(contentId)
));
```

Requirements [SSA-CONTENT]:

1. The full content manifest — every `(contentId, tokenDataHash)` pair,
   with preview references — is published before the sale opens, and its
   Merkle root (`contentManifestRoot`, sorted-pair keccak over the
   double-hashed leaves above) is pinned in the sale record and in the
   phase's gate config hash.
2. A purchase selects one `contentId` with a Merkle proof; the adapter must
   verify the proof and bind the exact `tokenData` whose per-token hash
   equals the leaf's `tokenDataHash` into the mint commitment, so the
   minted work is provably the selected one.
   `contentSelectionHash = contentLeaf` in the sale authorization.
3. Double-sale prevention: the phase must configure a `CONTEXT`-keyed,
   `PER_BATCH`, cap-1 counter whose `contextHash` is
   `contentContextHash`, so each content ID is sellable exactly once, and
   concurrent buyers race safely at the ledger.
4. Serials stay sequential: content selection binds artwork content, never
   the token ID or collection serial. Serial-number or token-ID selection
   is excluded on this Core line (no persistent reservations; sequential
   allocation per ADR 0009 decision 1).
5. Unsold content simply expires with the sale; manifest publication does
   not obligate minting.

## Authorization Continuity And Grace Windows

Signed tickets, sale authorizations, and offers bind the mint-policy
`policyHash`. Policy re-registration may set a bounded `graceUntil`
honoring the previous policy hash (ADR 0010 decision D5.5), so an
operational config fix does not strand every outstanding signed
authorization.

Requirements [SSA-GRACE]:

1. The grace mechanism is owned by the mint spec (`[MPA-GRACE]`): one
   previous hash, bounded by `MAX_POLICY_GRACE_SECONDS`, with current
   counter policies still binding. Adapters must not implement a second
   continuity mechanism.
2. An adapter executing under a grace window must pass the authorization's
   original (previous) policy hash to the manager and must emit it in the
   sale/settlement event, so indexers see which policy the sale actually
   bound.
3. Adapters should issue long-lived authorizations bound to the current
   policy hash as late as practical and must document to operators that
   any loosening change still invalidates outstanding authorizations
   beyond the grace bound.

## Account Abstraction And Sponsored Mints

Protocol v1 states its account-abstraction posture explicitly (ADR 0010
decision D5.11).

Requirements [SSA-AA]:

1. Executor/payer/recipient/authorizer separation is ERC-4337-compatible:
   a smart-account buyer, a bundler-submitted transaction, and a
   paymaster-sponsored fee payer are all supported without any adapter
   change, because no sale, mint, or settlement path reads `tx.origin`
   (static-analysis gate) and signatures accept ERC-1271.
2. Paymaster-sponsored mints are a supported executor pattern: the sponsor
   pays gas, the `payer` role remains the funds source bound in the sale
   record or authorization, and counters key the configured subject —
   sponsorship never changes accounting identity.
3. The genesis public fixed-price adapter must be validated end-to-end
   from an ERC-4337 smart account with a sponsoring paymaster on the
   deployment rehearsal network; the run is a named release-evidence
   artifact ([Conformance Gates](#conformance-gates)).
4. ERC-2771 meta-transactions are excluded from genesis sale paths: no
   trusted-forwarder code path exists in the genesis adapters, matching
   the mint subsystem's forwarder exclusion. A future forwarder class
   requires its own accepted spec.

## Governed Gas Parameters

Requirements [SSA-GAS]:

1. `SALE_ERC1271_GAS_LIMIT` (genesis value `400_000`) bounds ERC-1271
   verification of sale authorizations and offers at adapter boundaries.
2. `DELEGATE_REGISTRY_GAS_LIMIT` (genesis value `150_000`) bounds delegate
   registry reads in the delegate gate.
3. Both are Governed Gas Parameters under the model home,
   [`docs/stream-long-term-architecture.md`](stream-long-term-architecture.md)
   [LTA-GGP] (ADR 0010 decision D1): floors, governance classes, probes,
   change events, manifest recording, and repricing-checklist membership
   follow the home unchanged, and the Operational-layer exclusion covers
   sale identity in this layer. This document adds no pattern rules of
   its own.

## Events

Every event carries `uint16 schemaVersion` and at most three indexed
fields. Event catalog registration and indexed-field classification follow
[`docs/launch-conformance-matrix.md`](launch-conformance-matrix.md).

```solidity
event SaleConfigured(
    uint16 schemaVersion,
    bytes32 indexed saleId,
    uint256 indexed collectionId,
    bytes32 indexed phaseId,
    uint8 saleKind,
    address asset,
    bytes32 saleConfigHash,
    bytes32 expectedPrimaryPolicyHash,
    uint8 primaryPolicyMode
);

event SaleStatusChanged(
    uint16 schemaVersion,
    bytes32 indexed saleId,
    uint8 previousStatus,
    uint8 newStatus,
    bytes32 reasonHash
);

event AuctionCreated(
    uint16 schemaVersion,
    bytes32 indexed auctionId,
    bytes32 indexed saleId,
    uint256 indexed collectionId,
    uint256 tokenId,
    address poster,
    uint96 reservePrice,
    uint16 minIncrementBps,
    uint64 startTime,
    uint64 endTime,
    uint32 antiSnipeWindow,
    uint32 antiSnipeExtension,
    uint32 maxTotalExtension
);

event AuctionCustodyConfirmed(
    uint16 schemaVersion,
    bytes32 indexed auctionId,
    uint256 indexed tokenId,
    address custody
);

event AuctionBidPlaced(
    uint16 schemaVersion,
    bytes32 indexed auctionId,
    address indexed bidder,
    uint256 amount,
    uint64 endTime
);

event AuctionExtended(
    uint16 schemaVersion,
    bytes32 indexed auctionId,
    uint64 previousEndTime,
    uint64 newEndTime,
    uint32 totalExtensionUsed
);

event AuctionBidRefundCredited(
    uint16 schemaVersion,
    bytes32 indexed auctionId,
    address indexed bidder,
    uint256 amount
);

event AuctionSettled(
    uint16 schemaVersion,
    bytes32 indexed auctionId,
    bytes32 indexed saleId,
    address indexed winner,
    uint256 amount,
    bytes32 policyHash,
    bool policyDriftObserved
);

event AuctionSettledNoBid(
    uint16 schemaVersion,
    bytes32 indexed auctionId,
    address indexed poster,
    bool viaPendingClaim
);

event AuctionNftClaimPending(
    uint16 schemaVersion,
    bytes32 indexed auctionId,
    uint256 indexed tokenId,
    address indexed claimant
);

event AuctionNftClaimCompleted(
    uint16 schemaVersion,
    bytes32 indexed auctionId,
    uint256 indexed tokenId,
    address indexed receiver
);

event AuctionCancelled(
    uint16 schemaVersion,
    bytes32 indexed auctionId,
    bytes32 reasonHash
);

event DutchPurchaseExecuted(
    uint16 schemaVersion,
    bytes32 indexed saleId,
    address indexed payer,
    uint256 quantity,
    uint256 unitPrice,
    bytes32 priceScheduleHash
);

event DutchClearingFinalized(
    uint16 schemaVersion,
    bytes32 indexed saleId,
    uint256 clearingPrice,
    uint256 soldCount,
    uint256 supplementalRevenue
);

event DutchRebateCredited(
    uint16 schemaVersion,
    bytes32 indexed saleId,
    address indexed payer,
    uint256 amount
);

event RefundWindowPurchase(
    uint16 schemaVersion,
    bytes32 indexed saleId,
    bytes32 indexed purchaseId,
    address indexed payer,
    uint256 quantity,
    uint256 amount,
    uint64 refundDeadline
);

event RefundWindowRefunded(
    uint16 schemaVersion,
    bytes32 indexed saleId,
    bytes32 indexed purchaseId,
    address indexed payer,
    uint256 amount
);

event RefundWindowFinalized(
    uint16 schemaVersion,
    bytes32 indexed saleId,
    bytes32 indexed purchaseId,
    uint256 firstTokenId,
    uint256 quantity
);

event PrivateSaleExecuted(
    uint16 schemaVersion,
    bytes32 indexed saleId,
    address indexed buyer,
    uint256 tokenId,
    uint256 price,
    address asset
);

event OfferAccepted(
    uint16 schemaVersion,
    bytes32 indexed saleId,
    address indexed buyer,
    bytes32 offerDigest,
    uint256 price,
    address asset
);

event BurnMintExecuted(
    uint16 schemaVersion,
    uint256 indexed sourceTokenId,
    uint256 indexed mintedTokenId,
    uint256 indexed targetCollectionId,
    bytes32 burnNullifier,
    address redeemer
);

event RedemptionRecorded(
    uint16 schemaVersion,
    bytes32 indexed redemptionId,
    uint256 indexed burnedTokenId,
    uint256 indexed collectionId,
    address redeemer,
    bytes32 fulfillmentHash,
    string fulfillmentURI
);

event RedemptionFulfilled(
    uint16 schemaVersion,
    bytes32 indexed redemptionId,
    bytes32 fulfillmentHash,
    string fulfillmentURI
);

event ContentSelected(
    uint16 schemaVersion,
    bytes32 indexed saleId,
    bytes32 indexed contentId,
    address indexed payer,
    bytes32 tokenDataHash,
    uint256 tokenId
);
```

## Errors

```solidity
error SaleUnknown(bytes32 saleId);
error SaleNotActive(bytes32 saleId, uint8 status);
error SaleKindInvalid(uint8 saleKind);
error SaleAssetMismatch(address expected, address supplied);
error SalePaymentMismatch(uint256 expected, uint256 supplied);
error SaleAuthorizationExpired(uint64 deadline);
error SaleAuthorizationInvalid();
error SaleBuyerNotBound(address expected, address supplied);
error AuctionNotActive(bytes32 auctionId);
error AuctionCustodyUnconfirmed(bytes32 auctionId);
error AuctionBidBelowReserve(uint256 reserve, uint256 bid);
error AuctionBidBelowMinIncrement(uint256 required, uint256 bid);
error AuctionEnded(bytes32 auctionId, uint64 endTime);
error AuctionNotEnded(bytes32 auctionId, uint64 endTime);
error AuctionAlreadySettled(bytes32 auctionId);
error AuctionCancelBlockedByBid(bytes32 auctionId);
error AuctionConfigInvalid();
error DutchScheduleInvalid();
error DutchClearingNotFinalizable(bytes32 saleId);
error DutchClearingAlreadyFinalized(bytes32 saleId);
error RefundWindowClosed(bytes32 purchaseId, uint64 refundDeadline);
error RefundWindowStillOpen(bytes32 purchaseId, uint64 refundDeadline);
error RefundWindowPurchaseTerminal(bytes32 purchaseId);
error BurnSourceNotOwned(uint256 sourceTokenId, address caller);
error BurnSourceCollectionNotAllowed(uint256 sourceCollectionId);
error BurnProofInvalid(uint256 sourceTokenId);
error ContentProofInvalid(bytes32 contentId);
error ContentAlreadySold(bytes32 contentId);
error DelegationNotFound(address vault, address delegate);
error OfferInvalid();
error NothingClaimable(bytes32 saleId, address account);
```

## Domain Constants And Typehashes

This table is the normative home for the sale-layer domain constants
(ADR 0010 decisions D3.1 and D3.5). The protocol v1 domain-constants table
mirrors these rows for the CI recomputation test; every hash value is
pinned from its string preimage and recomputed by CI.

| Constant name | String preimage | Hash value | Owner | Schema version | Inputs |
| --- | --- | --- | --- | --- | --- |
| `STREAM_SALE_V1` | `6529STREAM_SALE_V1` | 0x1167dd961e7616f9b2d1ebaa10110b8970558783a3c1b03e031c28fc3ed185d0 | sale adapters | `1` | `domain; chainid; saleAdapter; saleKind; collectionId; phaseId; saleNonce` (purchase IDs append `buyer; purchaseNonce`) |
| `STREAM_AUCTION_V1` | `6529STREAM_AUCTION_V1` | 0x747a8af1003df51f6ec4340fba0c00dcacb2f277d75387d56e4a811b90ffa645 | auction adapters | `1` | `domain; chainid; auctionContract; collectionId; localAuctionNonce; tokenId; tokenIdKnown` |
| `STREAM_DUTCH_SCHEDULE_V1` | `6529STREAM_DUTCH_SCHEDULE_V1` | 0xf22d2e97f1de4a74f3f96b4bd6c3dc8bd6a378980328e92785afa57f0c3957ad | Dutch adapter | `1` | `domain; chainid; saleAdapter; saleId; startPrice; restingPrice; startTime; endTime; decayKind; stepSeconds; stepAmount` |
| `STREAM_BURN_NULLIFIER_V1` | `6529STREAM_BURN_NULLIFIER_V1` | 0x678dd864ff303f21860e7aa38ee53d87e022b7bd7355b933e19d75019bba9d32 | burn gate | `1` | `domain; chainid; core; sourceTokenId` |
| `STREAM_REDEMPTION_V1` | `6529STREAM_REDEMPTION_V1` | 0xe816b2cd9b695f515fad3c02582641b600d22416fe39f7c071eae91eda5d20df | redeem adapter | `1` | `domain; chainid; saleAdapter; core; burnedTokenId` |
| `STREAM_CONTENT_LEAF_V1` | `6529STREAM_CONTENT_LEAF_V1` | 0xfb3574a94e8672231a1ca6961a82ed077548322500d152474645664cb781b3e3 | content-selection adapters | `1` | double-hashed leaf: `domain; chainid; saleAdapter; saleId; contentId; tokenDataHash` |
| `STREAM_CONTENT_CONTEXT_V1` | `6529STREAM_CONTENT_CONTEXT_V1` | 0xc8ed10e43ef466bc9a26cbf502bbe6560cc53fc75b5f48650849304775459c68 | content-selection adapters | `1` | `domain; chainid; saleAdapter; saleId; contentId` |
| `STREAM_SEALED_BID_V1` | `6529STREAM_SEALED_BID_V1` | 0x3f5199758c189f6205a065046fe5778bc3e349f7c373fa5c9f419b0718e3e3c6 | sealed-bid extension | `1` | `domain; chainid; auctionContract; auctionId; bidder; amount; salt` |
| `SALE_AUTHORIZATION_TYPEHASH` | struct type string pinned in [SSA-AUTH] | 0x4d5722102337c13f9eba7b02dbdf7f716ab0ff4ef71d1c35a4bc2864461f64bc | sale adapters | `1` | EIP-712 struct fields per [SSA-AUTH] |
| `SALE_OFFER_TYPEHASH` | struct type string pinned in [SSA-OFFER] | 0x76d0c5e2d6bb4b74d8cbfcb3cb7228fa182deee45e6053f070eced61b486b8eb | sale adapters | `1` | EIP-712 struct fields per [SSA-OFFER] |

The shared EIP-712 domain for adapter-owned signatures is
`(name = "6529Stream Sales", version = "1", chainId, verifyingContract)`
with ERC-5267 exposure; every hash above uses domain-separated
`abi.encode` preimages (packed encoding is invalid for authority hashes).

## Conformance Gates

Each gate below must map into the
[conformance matrix](launch-conformance-matrix.md) before this document
reaches Review; a failed or unmapped gate blocks deployment.
Requirements [SSA-GATES]:

1. English auction suite: reserve, increment floor/rejection, anti-snipe
   extension and cap, boundary bids at `endTime`, outbid pull credits,
   reverting-bidder non-blocking, CEI settlement ordering, idempotent
   settlement, contract-winner and contract-poster claim paths, pre-bid
   cancellation, emergency preservation of owed credits.
2. Dutch suite: schedule determinism (linear and stepped), commitment
   verification, clearing-price fixing (sold-out and resting cases),
   floor-settlement conformance at purchase, supplemental-revenue and
   rebate accounting conservation (escrow in = supplemental revenue +
   rebates), rebate claims, refusal to finalize twice.
3. Refund-window suite: escrow custody, refund before deadline, refusal
   after, permissionless idempotent finalization, official settlement
   exactly once.
4. Burn suite: same-transaction burn proof, retained-identity checks,
   nullifier consumption and cross-manager scoping, source-collection
   allowlist, finality interaction refusals, redemption record and
   fulfillment append-only behavior.
5. Delegate gate suite: pinned registry codehash, scope acceptance matrix,
   revocation honored, gas-bounded reads, fail-closed on registry
   failure, deliver-to-vault counter correctness.
6. Content-selection suite: proof verification, double-sale race at the
   ledger, tokenData hash binding, serial-selection refusal.
7. Account-abstraction run: the release evidence must include the
   ERC-4337 smart-account plus paymaster end-to-end mint against the
   genesis public adapter ([SSA-AA] 3).
8. Registry governance: every genesis adapter/gate registered `ACTIVE`
   with codehash pins; paid-phase executor grant refused for unregistered
   contracts; `INCIDENT_REVOKED` adapter execution reverts.
9. Static analysis: no `tx.origin`, no push ETH in bid/settlement paths,
   reentrancy guards on every claim surface.
10. Gas budget: the end-to-end collector mint gas budget artifact defined
    in the mint spec (`[MPA-GAS-BUDGET]`) must include the genesis
    fixed-price purchase and the Dutch standard purchase paths.
11. Event reconstruction: sale, auction, refund, rebate, burn, and
    redemption state must be rebuildable from events alone, matching
    direct reads (protocol v1 event reconstruction rule).

## Protocol v1 Exclusions

Exclusion is intentional absence, not deferral (spec policy). Adding any
item requires its own accepted spec through the frozen extension
mechanisms:

1. Sealed-bid and ranked auction implementations (interfaces are frozen
   above).
2. ERC-20 auction bidding and ERC-20 sealed-bid deposits.
3. Bonding curves, VRGDA-style issuance, and AMM-priced sales.
4. Standing orderbooks, collection-wide floor offers, and offer matching.
5. Secondary-market listings, wash-trade surveillance, and marketplace
   aggregation (this layer is primary-sale only).
6. Post-settlement refunds of officially settled revenue, in any mechanic.
7. Pre-burned claim credit and external-collection burn sources.
8. Cross-chain or bridged sale execution.
9. Fiat/credit-card rails (Operational integrations may front conformant
   onchain sales but are outside protocol surface).
10. ERC-2771 trusted forwarders in sale paths.

## Test Requirements

1. Every numbered requirement in [SSA-ADAPTER], [SSA-REGISTRY],
   [SSA-AUTH], [SSA-FIXED], [SSA-ENGLISH], [SSA-DUTCH],
   [SSA-DUTCH-CLEARING], [SSA-PRIVATE], [SSA-OFFER], [SSA-REFUND],
   [SSA-BURN], [SSA-BURN-FINALITY], [SSA-REDEEM], [SSA-DELEGATE],
   [SSA-CONTENT], [SSA-GRACE], [SSA-AA], and [SSA-GAS] maps to at least
   one test named in the conformance gates above.
2. Negative tests: below-reserve and below-increment bids; bid at exactly
   `endTime`; extension beyond `maxTotalExtension`; settlement before end;
   double settlement; refund after finalization; finalize during window;
   clearing finalize twice; burn of non-owned token; burn source not in
   allowlist; content double-sale race; stale/revoked delegation; expired
   and replayed authorizations and offers; zero-address and non-canonical
   signature rejection (shared with mint spec `[MPA-AUTHZ]`).
3. Conservation fuzz: for each escrow-holding mode, adapter escrow in
   equals refunds + rebates + official settlement out, under randomized
   purchase/refund/outbid sequences with forced-ETH injection.
4. Reconstruction harness: rebuild sale and auction state from events and
   compare to reads (gate 11).

## Acceptance Criteria

1. Every genesis adapter and gate in the Design Summary is specified here,
   registered under [SSA-REGISTRY], and listed in the conformance-matrix
   genesis profile.
2. English auctions enforce reserve, minimum increment, and anti-snipe
   extension with caps, all bound into sale identity and events.
3. Dutch auctions support linear and stepped decay with committed
   schedules, and the clearing mode pays uniform prices with escrowed,
   pull-claimable rebates while every official settlement remains
   path-conformant.
4. Private sales, offers, and refund-window sales execute with full signed
   bindings including price, asset, and deadline.
5. Burn-to-mint and burn-to-redeem work through the registry-governed gate
   with manager-scoped nullifiers and the finality interaction rule
   enforced and surfaced.
6. Sealed-bid and ranked interfaces are frozen with conformance
   requirements and no genesis bytecode.
7. Delegated minting and pick-your-piece selection follow the documented
   patterns without new trust assumptions.
8. A collector can mint from an ERC-4337 smart account with a sponsoring
   paymaster against the genesis public adapter.
9. No sale path can strand funds, custody, or NFTs without a pull-claim
   recovery, and no path can refund officially settled revenue.
