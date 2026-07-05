# Stream Sales And Auctions

Specification status: Draft. This document follows
[`docs/spec-policy.md`](spec-policy.md) and implements
[ADR 0010](adr/0010-world-class-spec-pass.md) decision D5, amended by
[ADR 0011](adr/0011-world-class-pass-round-2.md) decisions R6, R8, and
R9, by [ADR 0012](adr/0012-world-class-pass-round-3.md) decisions T4,
T6, and T7, by
[ADR 0013](adr/0013-world-class-pass-round-4.md) decisions U6, U7, and
U9, and by
[ADR 0014](adr/0014-world-class-pass-round-5.md) decisions V5 and V6.
It is a new protocol v1 specification: the sale and auction layer enters
the genesis inventory at the same EIP-grade depth as the mint, ledger, and
revenue specifications instead of remaining an integration sketch.

This document is the normative home for primary-sale mechanics: the sale
adapter conformance profile and its registry governance, sale identity,
signed sale authorizations, English auctions, Dutch auctions with the
uniform-clearing rebate mode, private and direct sales, offer acceptance,
zero-price claims, pay-what-you-want sales, custody-inventory fixed-price
sales, the editions posture, airdrop operator distributions, owner
custody grants and the consignment boundary, refund-window sales,
deferred-settlement drift envelopes,
burn-to-mint and burn-to-redeem gate modules, the external-collection
burn recipe, the delegated-mint gate and delegated sale participation,
pick-your-piece content selection and the cross-sale content-uniqueness
recipe, sale-layer emergency pause, the contested-attribution sale stop,
the adapter-side reveal-fee obligation, the raffle extension recipe, the
network-eligibility gate profile, the time-varying content-selection
profile, the sealed-bid, ranked-auction,
and ERC-20-bidding extension profiles, and the pattern coverage matrix.
Other documents cite these
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
5. [`docs/stream-entropy-coordinator.md`](stream-entropy-coordinator.md)
   owns the entropy request lifecycle, reveal policy declaration, the
   reveal-fee escrow and its top-up path, the permissionless reveal
   fallback ([EC-REVEAL]),
   and the sale/collection-scoped request kind ([EC-SCOPE]). This
   document owns the adapter-side call shape and the priced reveal-fee
   line item ([Reveal Fees And Post-Mint Entropy](#reveal-fees-and-post-mint-entropy)).
6. Dynamic/evolving works are a rendering, satellite, and consent
   composition, never a sale mechanic: the consolidated evolving-works
   extension recipe is owned by
   [`docs/metadata-router-and-renderer.md`](metadata-router-and-renderer.md)
   [MRR-EVOLVING-RECIPE] (ADR 0012 decision T6). The sale kinds in this
   document sell evolving works unchanged and add no rule of their own.

## Design Summary

```text
Sale adapters (Replaceable, registry-governed)
  StreamFixedPriceSaleAdapter   fixed price, open edition, zero-price claim,
                                pay-what-you-want, refund-window mode,
                                pick-your-piece content selection
                                (PUBLIC and COMMIT_REVEAL modes)
  StreamEnglishAuctionHouse     reserve auctions with anti-snipe extension
  StreamDutchAuctionAdapter     descending price, optional clearing rebates
  StreamPrivateSaleAdapter      allowlist-of-one direct sale, offer
                                acceptance, custody-inventory fixed price

Gate modules (Replaceable, registry-governed)
  StreamBurnMintGate            burn-to-mint and burn-to-redeem
  StreamDelegateRegistryGate    delegate-registry eligibility checks

Extension profiles (Permanent interfaces, no genesis implementation)
  IStreamSealedBidAuction       commit/reveal sealed-bid auctions
  IStreamRankedAuction          multi-unit ranked/uniform-price auctions
  IStreamERC20AuctionBidding    ERC-20 bid escrow for live auctions
  IStreamNetworkEligibilityGate TDH-class network-eligibility gates

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
   `IStreamSealedBidAuction`, `IStreamRankedAuction`,
   `IStreamERC20AuctionBidding`, and `IStreamNetworkEligibilityGate`
   interfaces, the [SSA-ENGLISH] rule 16 `auctionConfig` read, every
   hash preimage and
   EIP-712 typehash in
   [Domain Constants And Typehashes](#domain-constants-and-typehashes), the
   sale/auction event schemas, the drift-envelope and refund-unlock rules
   of [Deferred Settlement Drift Envelopes](#deferred-settlement-drift-envelopes),
   and the settlement orderings named in this document.
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
one durable `auctionId`; every escrow-holding purchase has one durable
`purchaseId`. All three are Permanent preimages, each under its own
versioned domain constant — no domain constant is reused across preimage
shapes (ADR 0011 decision R9).

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

bytes32 purchaseId = keccak256(abi.encode(
    STREAM_SALE_PURCHASE_V1,
    uint256(block.chainid),
    address(saleAdapter),
    bytes32(saleId),
    address(buyer),
    uint256(purchaseNonce)
));
```

```solidity
enum SaleKind {
    FIXED_PRICE,                  // 0
    OPEN_EDITION,                 // 1
    ENGLISH_AUCTION,              // 2
    DUTCH_AUCTION,                // 3
    DUTCH_AUCTION_CLEARING,       // 4
    PRIVATE_SALE,                 // 5
    OFFER_SALE,                   // 6
    REFUND_WINDOW,                // 7
    BURN_TO_MINT,                 // 8
    BURN_TO_REDEEM,               // 9
    SEALED_BID,                   // 10 reserved: extension profile
    RANKED_AUCTION,               // 11 reserved: extension profile
    ZERO_PRICE_CLAIM,             // 12
    PAY_WHAT_YOU_WANT,            // 13
    CUSTODY_INVENTORY_FIXED_PRICE // 14
}
```

Requirements [SSA-IDENTITY]:

1. `saleNonce` and `localAuctionNonce` must be adapter-local monotonic
   counters; an adapter must never reuse a nonce. `purchaseNonce` is an
   adapter-local monotonic counter per `(saleId, buyer)`; escrow-holding
   purchase records (refund-window deposits, Dutch clearing overage) key
   escrow, refunds, and finalization by `purchaseId`.
2. `SEALED_BID` and `RANKED_AUCTION` are reserved enum values for the
   extension profiles below. Genesis adapters must reject configuration of
   reserved kinds; reserved values exist so sale records and event consumers
   never renumber (same posture as reserved counter modes in the mint spec).
3. Every sale record must bind: `saleId`, `saleKind`, `collectionId`,
   `phaseId`, accepted asset, price commitment (fixed price, price band,
   reserve, or price schedule hash), sale time bounds,
   `expectedPrimaryPolicyHash`, `primaryPolicyMode`, the drift-envelope
   windows required by
   [Deferred Settlement Drift Envelopes](#deferred-settlement-drift-envelopes)
   for escrow-holding kinds, the [SSA-ENGLISH] rule 8 artwork commitment
   where mint-at-settlement applies (ADR 0012 decision T6), and the
   mint-policy `policyHash` the adapter
   will bind at execution. The adapter computes `saleConfigHash` over the
   full record and emits it in `SaleConfigured`.
4. Sale records are append-only history: cancellation and exhaustion are
   status transitions, never record deletion.
5. Governed Gas Parameter values are excluded from `saleConfigHash` and from
   every sale, auction, and schedule preimage (ADR 0010 decision D1.3), so
   gas retuning never changes sale identity.
6. `SaleKind` is an append-only numeric-catalog vocabulary (ADR 0011
   decision R9): the values above are pinned in the Numeric ID Catalog
   ([`docs/launch-conformance-matrix.md`](launch-conformance-matrix.md)),
   are never renumbered or reused, and new kinds (values `15` and up) are
   allocated append-only by future accepted adapter specs through that
   catalog. A mechanic that needs identity gets a new kind value; it never
   overloads an existing one.
7. Settlement-identity mapping (ADR 0011 decision R9): for every official
   settlement of a sale under this specification, the revenue spec's
   `settlementKey` preimage
   ([`docs/revenue-splits-and-royalties.md`](revenue-splits-and-royalties.md))
   binds `settlementId` equal to this document's bytes32 `saleId`
   exactly, binds its `uint256 saleNonce` field equal to this record's
   adapter-local `saleNonce`, and a `PaymentIntent.saleRef` for the sale
   must equal this `saleId`. No other derivation of the settlement
   reference is conformant; adapters must reject settlement calls whose
   identity fields do not match this mapping.
8. Artist sale-parameter consent (ADR 0012 decision T4): where an
   artist-bound collection's consent scope pins sale-parameter approval
   — the `SaleConsentScope` election is owned by
   [`docs/stream-artist-authority.md`](stream-artist-authority.md)
   `[AA-BINDING]`, and the consent payload, reads, and ceremony by
   `[AA-SALE-CONSENT]` (same document) — a sale record for that
   collection must not accept
   buyer funds, bids, or commits until verifiable artist authorization
   over the exact `saleConfigHash` exists under that home. The adapter
   verifies through a bounded artist-authority registry read under the
   `SALE_ARTIST_AUTHORITY_GAS_LIMIT` Governed Gas Parameter
   ([SSA-GAS]) with returndata copied only to the read's exact ABI
   shape — longer or shorter returndata is a failed read (ADR 0013
   decision U7) — failing closed for consent-scoped configuration, and
   emits `SaleConsentRecorded` binding the `saleId`, `saleConfigHash`,
   and consent evidence hash. Collections whose consent scope does not
   pin sale-parameter approval are unaffected: for them the sale record
   plus phase-policy consent remain the complete authority, and that
   boundary is disclosed in the artist-authority onboarding surface
   (same home). This rule governs primary sale records; consignment
   sales are outside primary economics per [SSA-CONSIGN].
9. Identity-mode configuration gate (ADR 0015 decision W3). The
   custody and burn shapes of this document execute native Core
   ERC-721 mutation entries on already-minted tokens — custody entry
   `transferFrom` ([SSA-CUSTODY-ENTRY] rule 2), the bounded
   custody-to-recipient delivery, custody release, and pull NFT claim
   ([SSA-ENGLISH] rules 7(d), 10, and 11; [SSA-INVENTORY] rules 3
   and 5; [SSA-AIRDROP] rule 2 failure-isolated shape) — or
   `Core.burn` on burn-program sources ([SSA-BURN] rule 1;
   [SSA-REDEEM] rule 1), and every one of those entries reverts
   `NativeTransferPathClosed` for an `EXTERNAL_FACADE` collection
   ([PV1-TRANSFER-CONTROLLER] requirement 8 in
   [`docs/launch-v1-target-architecture.md`](launch-v1-target-architecture.md)).
   The combination is excluded at configuration, never discovered at
   settlement: sale, gate, and distribution configuration must
   resolve `collectionIdentityMode` for every collection whose
   already-minted tokens the configured flow would custody, deliver,
   release, or burn through a native Core entry, and must revert with
   `SaleFlowClosedForFacadeCollection` when any resolved mode is
   `EXTERNAL_FACADE`. Concretely: `ENGLISH_AUCTION` (every variant
   runs a custody-and-native-delivery leg — custody-held tokens,
   `AUCTION_START_CUSTODY`, and mint-at-settlement's
   custody-then-deliver shape alike), `CUSTODY_INVENTORY_FIXED_PRICE`
   and its consignment form, `PRIVATE_SALE` and `OFFER_SALE` records
   binding a custody-held token (for offer acceptance of an
   owner-held token the check runs before any signature consumption
   or custody effect of the acceptance transaction; a custody-entry
   attempt outside a configured sale fail-fasts atomically at Core
   with no funds at risk), the [SSA-AIRDROP] rule 2 failure-isolated
   shape, and `BURN_TO_MINT` and `BURN_TO_REDEEM` programs whose
   Stream source set ([SSA-BURN] rule 3) or redeemed collection
   includes an `EXTERNAL_FACADE` collection. Kinds whose only Core
   mutation is mint delivery are unaffected in both modes — minting
   routes the manager path and the terminal controller callback
   mode-independently ([PV1-TRANSFER-CONTROLLER] requirement 12) —
   so `FIXED_PRICE`, `OPEN_EDITION`, the Dutch kinds,
   `REFUND_WINDOW`, `ZERO_PRICE_CLAIM`, `PAY_WHAT_YOU_WANT`,
   direct-shape airdrops, and mint-settling private sales and offers
   configure and settle identically for `EXTERNAL_FACADE`
   collections. Facade-aware adapter profiles that route custody
   mutation through the facade's ERC-721 entries are the only path
   that lifts this exclusion; their acceptance is a mandatory scope
   item of the facade tripwire review ([FCP-DEPLOYMENT] rule 2 in
   [`docs/stream-collection-facade-profile.md`](stream-collection-facade-profile.md);
   ADR 0015 decision W3), and until such a profile is accepted this
   gate is the complete sale-layer posture for `EXTERNAL_FACADE`
   collections, verified by the [SSA-GATES] item 22 suite.

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

    function claimRefundFor(bytes32 saleId, address account) external;
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
   deposits, sealed-bid deposits, content-selection commit deposits).
   Adapter escrow is not official revenue;
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
13. `claimRefund` semantics are Permanent and uniform (ADR 0012 decision
    T7): the debit account is `msg.sender`, which must be the credited
    account written by the named orders of this document; the call pays
    the caller's full outstanding credit for `saleId` to the
    caller-chosen nonzero `to` (a contract creditor thereby directs
    delivery, mirroring the pull NFT claim), zeroes the credit before
    the transfer under checks-effects-interactions with a reentrancy
    guard, and emits the claim. `claimRefundFor(saleId, account)` is
    the delegate-triggered form (ADR 0013 decision U6): the caller must
    be a live registered delegate of `account` per [SSA-DELEGATE]
    rule 9, and the call pays `account`'s full credit to `account`
    itself — a delegate can trigger a claim, never redirect it — under
    the same CEI, guard, and event rules. No operator, governance, or
    third-party
    path may claim, reduce, or expire another account's credit;
    `refundableBalance(saleId, account)` reports exactly the amount the
    next claim would pay.
14. Adapter escrow conservation (ADR 0012 decision T7): for every asset
    an adapter holds, at every observation point outside an executing
    transaction:

    ```text
    adapterBalance(asset) >=
        sum over sales of ( refundable credits        // refunds, rebates,
                                                      // excess, unlocked
                          + live bid escrow
                          + pending purchase deposits // refund-window,
                                                      // commit, sealed-bid
                          + unfinalized clearing overage
                          + owed consignor and royalty credits )
    ```

    Escrowed reveal-fee line items held for deferred kinds
    ([SSA-REVEAL] rule 7) are pending-deposit liabilities under this
    inequality until forwarded or refunded.
    Liability accounting is per-sale isolated: every credit is recorded
    against exactly one `(saleId, account, asset)` and no path may
    satisfy one sale's liabilities by reducing another sale's recorded
    escrow. This instantiates the revenue layer's conservation
    discipline — the Split Wallet Conservation Proof and the
    wallet-plus-escrow system conservation inequality
    ([`docs/revenue-splits-and-royalties.md`](revenue-splits-and-royalties.md))
    — at the adapter boundary; the accounting model home stays in the
    revenue spec and this rule adds the adapter instantiation, verified
    by the [SSA-GATES] item 16 conservation suite.
15. Forced and direct value posture (ADR 0012 decision T7): genesis
    adapters must expose no payable `receive`/`fallback` surface, so
    value enters only through named entry points; ETH forced past that
    (selfdestruct, coinbase) and unsolicited ERC-20 transfers are
    untracked surplus — they never create, satisfy, or reduce a rule 14
    liability and are excluded from every credit, rebate, clearing, and
    official-revenue computation. Surplus is recoverable only through a
    governed sweep (ADR 0004 action classes) that computes
    `surplus = balance - trackedLiabilities`, reverts with
    `AdapterSurplusUnderfunded` if the sweep would leave any tracked
    liability unfunded, and emits `AdapterSurplusSwept` binding the
    authorizing governance `actionId` (ADR 0014 decision V6); owed
    credits,
    escrow, and custody NFTs are untouchable by every sweep path
    ([SSA-ENGLISH] rule 12 restated adapter-wide).
16. Owed-funds state export (ADR 0012 decision T3): every rule 14
    liability class is long-lived owed-funds state. Adapters must keep
    it state-readable per `(saleId, account, asset)` — through
    `refundableBalance` and the per-class claim views — and the
    `STATE_EXPORT` profile carries a sale-credit leaf family binding
    exactly `(saleAdapter, saleId, account, asset, owedAmount)` per
    outstanding credit, sorted and gated like the escrow-credit leaves.
    The leaf preimage, domain row, and export mechanics are owned by
    [`docs/stream-long-term-architecture.md`](stream-long-term-architecture.md)
    `[LTA-EXPORT]`; this rule is the field inventory it exports, so a
    post-expiry replica can prove who is still owed what from exports
    alone.

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
| Fixed price | `FIXED_PRICE`, `OPEN_EDITION` | yes | nonzero unit price, per-sale supply bound or open-edition declaration |
| Zero price | `ZERO_PRICE_CLAIM` | yes | free-claim declaration, fairness counters or allowlist |
| Pay what you want | `PAY_WHAT_YOU_WANT` | yes | pinned `[minUnitPrice, maxUnitPrice]` band |
| English auction | `ENGLISH_AUCTION` | yes | reserve, `minIncrementBps`, anti-snipe window/extension/cap, optional `startOnFirstBid` |
| Dutch auction | `DUTCH_AUCTION`, `DUTCH_AUCTION_CLEARING` | yes | committed price schedule; clearing mode adds escrowed rebates and the drift envelope |
| Private/direct | `PRIVATE_SALE`, `OFFER_SALE` | yes | bound buyer, price, deadline; offer digest for `OFFER_SALE` |
| Custody inventory | `CUSTODY_INVENTORY_FIXED_PRICE` | yes | committed inventory manifest, unit price, custody of every listed token |
| Refund window | `REFUND_WINDOW` | yes | window lengths, escrow custody, finalize/refund/unlock rules, drift envelope |
| Burn programs | `BURN_TO_MINT`, `BURN_TO_REDEEM` | yes | source-collection set, burn proof, nullifier domain |
| Content selection | mode on `FIXED_PRICE`, `PRIVATE_SALE` | yes (carrier: `StreamFixedPriceSaleAdapter`) | content manifest root, selection mode, commit/reveal windows, cap-1 context counter ([SSA-CONTENT]; ADR 0013 decision U6) |
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
    "bytes32 saleId,uint8 saleKind,bytes32 revenueClass,"
    "bytes32 expectedPrimaryPolicyHash,uint8 primaryPolicyMode,"
    "bytes32 initialRecipientsHash,bytes32 beneficiariesHash,"
    "address payer,address executor,address asset,uint256 unitPrice,"
    "uint256 quantity,bytes32 contentSelectionHash,bytes32 policyHash,"
    "bytes32 nonce,uint64 deadline,uint64 finalizeBy)"
);
```

`revenueClass` is typed `bytes32` because revenue classes are an open
keccak-derived vocabulary, never a numeric enum (ADR 0011 decision R10;
home: [`docs/revenue-splits-and-royalties.md`](revenue-splits-and-royalties.md)
Assignment Semantics). `finalizeBy` binds the drift envelope of
[Deferred Settlement Drift Envelopes](#deferred-settlement-drift-envelopes)
(ADR 0011 decision R6).

Requirements [SSA-AUTH]:

1. The EIP-712 domain is
   `(name = "6529Stream Sales", version = "1", chainId, verifyingContract =
   saleAdapter)`, exposed through ERC-5267. Signatures are EOA ECDSA or
   ERC-1271; the mint spec's `[MPA-AUTHZ]` verification rules apply:
   recovered addresses must be nonzero and match, non-canonical `s` values
   are invalid, and the authorizer kind is explicit. Because the
   `SaleAuthorization` struct deliberately carries no authorizer field
   (one struct can be served by any signer in the authorized set),
   every execution and revocation presentation supplies the claimed
   authorizer address and `authorizerKind` in calldata (ADR 0013
   decision U6). The adapter first verifies the claimed authorizer is a
   member of the collection's authorized sale-signer set bound in the
   sale record's configuration (the authority [SSA-OFFER] rule 2
   names), then verifies the signature for exactly that account —
   ECDSA recovery equal to it, or a bounded ERC-1271
   `isValidSignature` call to it under `SALE_ERC1271_GAS_LIMIT`.
   Accepting a 1271 magic value from an account outside the authorized
   set is an authorization bypass and nonconformant; recovery-only
   verification that cannot serve contract signers is equally
   nonconformant.
2. State-changing execution must recompute every hash from calldata and
   chain state and reject the authorization if any field differs, if
   `deadline` has passed, or if the nonce was consumed or voided.
3. `unitPrice` is denominated in the base units of `asset`
   (`asset = address(0)` for native ETH). For fixed-price kinds it is the
   exact charged price; for time-varying kinds (`DUTCH_AUCTION`,
   `DUTCH_AUCTION_CLEARING`) it is the signer's binding maximum unit
   price, with the schedule price charged at execution per [SSA-DUTCH];
   for `PAY_WHAT_YOU_WANT` it is the minimum unit price the authorization
   accepts. A Merkle allowlist `priceOverride` (mint spec `[MPA-MERKLE]`)
   replaces `unitPrice` only when the proven leaf sets it, and the adapter
   must verify the same leaf it charges by. The override assumes
   exactly `unitPrice`'s role for the sale kind (ADR 0013 decision U6):
   the exact charged price on fixed-price kinds; the authorization
   minimum on `PAY_WHAT_YOU_WANT`; and on time-varying kinds a
   per-subject charging ceiling — the charged unit price is
   `min(currentSchedulePrice, priceOverride)`, never an exact
   replacement of the schedule. In `DUTCH_AUCTION_CLEARING` a proven
   leaf whose `priceOverride` is below `restingPrice` is invalid and
   execution reverts (the override can never take a charged price
   below the clearing floor), and overridden purchases interact with
   clearing-price fixing and rebates per [SSA-DUTCH-CLEARING] rules 3
   and 4. A proven leaf with `hasPriceOverride = true` and
   `priceOverride = 0` is a declared free tier, pinned (ADR 0014
   decision V5). On the kinds where the override is the exact charged
   price or a charging ceiling — every paid kind except
   `PAY_WHAT_YOU_WANT` — it is valid only when the sale record
   carries an explicit creation-time free-claim declaration, bound
   into `saleConfigHash` and disclosed on buyer surfaces (the
   [SSA-DUTCH] rule 1 declared free-mint class generalized beyond
   Dutch kinds), and an execution whose charged price is zero under
   the declaration executes [SSA-ZERO] rule 1 semantics — a free mint
   with no settlement-boundary deposit and no official-revenue
   record. Without the declaration, a zero override reverts with
   `SalePriceOverrideZeroUndeclared`, so the forbidden amount-0
   official settlement ([SSA-DUTCH] rule 1) can never reappear
   through an allowlist leaf and a free tier is always a declared
   mechanic, never a configuration accident ([SSA-FIXED] rule 3);
   clearing mode is stricter still — the clearing-floor rule above
   rejects a zero override regardless of any declaration. On
   `PAY_WHAT_YOU_WANT`, a zero override merely lowers the
   authorization minimum to the band floor: the pinned band and
   [SSA-PWYW] rule 3 already govern a zero chosen price, and no
   separate declaration applies. Two implementations of one sale
   record therefore charge
   identical amounts for the same proof on every kind.
4. `contentSelectionHash` is zero except for (a) pick-your-piece sales,
   where it binds the selected content per
   [Pick-Your-Piece Content Selection](#pick-your-piece-content-selection),
   and (b) mint-at-settlement auction sales, where it must equal the
   auction's committed `artworkCommitment` ([SSA-ENGLISH] rule 8;
   ADR 0012 decision T6), so a signed authorization participating in
   auction settlement binds the same artwork the auction committed.
5. Replay protection: the adapter must derive the mint-ledger
   `authorizationId` from the full EIP-712 digest per the mint spec
   `[MPA-TICKET]` derivation, so consuming the sale authorization and
   consuming the ledger replay key are the same fact. One carve exists
   (ADR 0013 decision U6): for mint-executing offer acceptance the
   ledger key derives from the buyer's offer digest and the
   authorization digest is consumed adapter-side in the same
   transaction, per the dual-digest locus of [SSA-OFFER] rule 4.
6. Authorizers may revoke unused sale authorizations through the same
   store that would consume them (ADR 0013 decision U6): an
   authorization whose consumption locus is the mint ledger revokes
   through the mint-ledger revocation surface (mint spec `[MPA-LEDGER]`
   rule 3, `[MPA-TICKET]` rule 5); an authorization whose consumption
   locus is the adapter's consumed-digest store — custody-transfer
   acceptance and mint-executing offer acceptance ([SSA-OFFER] rule 4)
   — revokes through the adapter presentation shape of [SSA-OFFER]
   rule 5.
7. `expectedPrimaryPolicyHash` and `primaryPolicyMode`
   (`STRICT_MATCH`/`ALLOW_CURRENT`) follow the revenue spec's primary-sale
   authority rules; settlement events must expose observed drift.
8. `finalizeBy` must be zero for kinds with no deferred-settlement leg.
   For escrow-holding kinds it must be nonzero and must equal the
   finalize-by deadline the sale record derives under
   [Deferred Settlement Drift Envelopes](#deferred-settlement-drift-envelopes);
   execution recomputes and rejects a mismatch exactly as rule 2 requires
   for every other field.

## Fixed-Price Sales And Open Editions

Requirements [SSA-FIXED]:

1. A fixed-price purchase executes, in one transaction, the revenue spec's
   `PRE_REVENUE_SINGLE_STEP` or `PREPARED_MINT` path with the sale
   authorization (or public-sale record) bound per [SSA-AUTH].
2. Exact payment is a fixed-price-kind rule for the price component:
   native `FIXED_PRICE`, `OPEN_EDITION`, and
   `CUSTODY_INVENTORY_FIXED_PRICE` purchases revert unless `msg.value`
   equals `unitPrice * quantity` — plus, where a reveal-fee line item
   applies, the buyer's reveal-fee allowance bound by [SSA-REVEAL]
   rule 2 (the allowance is `msg.value` above the price component; the
   live declared fee is charged and the unspent allowance is
   pull-credited, so fee drift never reverts a funded purchase;
   ADR 0013 decision U6). ERC-20 purchases follow
   the revenue spec's exact-delta rule. Overpayment of the price
   component on kinds with no fee line item
   is rejected, not credited. Exact payment is never applied to
   time-varying prices: Dutch kinds bind `msg.value` as a maximum per
   [SSA-DUTCH] rule 3 (ADR 0011 decision R6).
3. `unitPrice` must be nonzero for `FIXED_PRICE` and `OPEN_EDITION`; free
   claims must use the explicit `ZERO_PRICE_CLAIM` kind ([SSA-ZERO]) —
   or, inside a paid sale, the declared zero-override free tier of
   [SSA-AUTH] rule 3 (ADR 0014 decision V5) — so a
   zero price is always a declared mechanic, never a configuration
   accident.
4. `OPEN_EDITION` is `FIXED_PRICE` whose sale record declares no per-sale
   supply bound; collection supply mode and mint-ledger counters still
   bind. The sale record must state the close rule (end time or manual
   close), and close is one-way per sale.
5. Public sales (no per-buyer authorization) are supported: the adapter is
   the phase executor, the sale record is the authority, and per-wallet
   fairness comes from mint-ledger counters, the Merkle allowlist cap mode,
   or gates. The public path must still bind `payer`, recipients, and
   beneficiaries explicitly.
6. The genesis public fixed-price adapter is the account-abstraction
   reference path and must satisfy [SSA-AA].

### Editions Posture

[SSA-EDITIONS]

The platform's answer to editioned work is stated so absence of ERC-1155
is provably intentional (ADR 0012 decision T6). An edition of N is N
sequential ERC-721 serials: one collection whose supply is bounded to N
(`FIXED` of size N, `CAPPED_OPEN`, or an `OPEN_EDITION` close under
[SSA-FIXED] rule 4; supply modes and supply facts are owned by
[`docs/collection-metadata-contract.md`](collection-metadata-contract.md)),
each edition unit a full ERC-721 token with its own `collectionSerial`
and provenance, sold through the fixed-price, open-edition, claim, or
pay-what-you-want kinds of this document with identical or
per-serial-varied `tokenData` as the artist declares. Edition-size
display derives from the collection's supply facts and metadata, never
from a token-standard balance. ERC-1155 and every semi-fungible token
semantic are successor-line-only and never exist on this Core line
([PV1-EXCL] item 11 in
[`docs/launch-v1-target-architecture.md`](launch-v1-target-architecture.md)):
a "500-edition drop" on Stream is 500 ERC-721 serials in one
collection, by design and not by omission.

Edition-size envelope (non-normative sizing guidance, ADR 0014
decision V5). The economic envelope is set by the measured mint
ceilings of
[`docs/mint-policy-and-accounting.md`](mint-policy-and-accounting.md)
[MPA-GAS-BUDGET] — about `150_000` gas marginal per serial in a batch
of 10 (`MAX_COLLECTOR_GAS_BATCH_MARGINAL`) and up to `500_000` for a
single paid mint — permanently on L1. Editions in the tens to low
hundreds of serials are the intended envelope; a thousands-of-mints
timed open edition is mechanically expressible but consumes tens of
full L1 blocks of gas across its minters, and the sanctioned home for
beyond-envelope mass editions is a successor line or L2 deployment,
never a semantics change on this one. Serial assignment inside an
edition is strictly mint-order — buyer serial selection never exists
on this line (reservation posture home:
[`docs/mint-policy-and-accounting.md`](mint-policy-and-accounting.md)
Core Contract Changes; onboarding disclosure duty: [SSA-CONTENT]
rule 4).

### Zero-Price Claims

`ZERO_PRICE_CLAIM` makes free mints — community claims, artist gifts,
charity editions — a first-class declared mechanic (ADR 0011 decision R9).

Requirements [SSA-ZERO]:

1. A zero-price claim is a free mint under the standard manager path: no
   settlement-boundary deposit, escrow, or official-revenue record exists
   or is emitted for the claim, and the revenue spec's paid orchestration
   paths do not apply because no token is minted against payment.
2. Native `msg.value` must equal zero when no reveal-fee line item
   applies; when one applies, the entire `msg.value` is the buyer's
   reveal-fee allowance under [SSA-REVEAL] rule 2 — it must cover the
   live declared fee, the live fee is charged, and the unspent
   allowance is pull-credited (ADR 0013 decision U6). Any value below
   the required fee reverts.
3. Both public and allowlisted zero-price claims are supported; per-wallet
   fairness comes from mint-ledger counters, the Merkle allowlist cap
   mode, or gates, exactly as for paid public sales.
4. The genesis fixed-price adapter serves this kind; the sale record's
   free-claim declaration is bound into `saleConfigHash`.

### Pay-What-You-Want Sales

`PAY_WHAT_YOU_WANT` prices a mint inside a pinned band and lets the buyer
choose — covering tip-at-mint (band floor at the list price) and
name-your-price charity or experimental drops (ADR 0011 decision R9).

Requirements [SSA-PWYW]:

1. The sale record pins a band `[minUnitPrice, maxUnitPrice]` with
   `maxUnitPrice >= max(minUnitPrice, 1)`, committed in `saleConfigHash`.
   `minUnitPrice` may be zero (free-or-tip claims).
2. The buyer supplies `chosenUnitPrice` in calldata; the purchase reverts
   unless `minUnitPrice <= chosenUnitPrice <= maxUnitPrice` and native
   `msg.value` equals `chosenUnitPrice * quantity` — plus, where a
   reveal-fee line item applies, the buyer's reveal-fee allowance
   bound by [SSA-REVEAL] rule 2 (live fee charged, unspent allowance
   pull-credited; ADR 0013 decision U6). The chosen price is
   buyer-supplied, so no
   price drift exists and no price excess credit is needed; only the
   fee allowance carries the rule 2 excess credit.
3. The full charged amount is official primary revenue and settles through
   a standard paid path per [SSA-FIXED] rule 1 (a zero `chosenUnitPrice`
   executes as a free mint per [SSA-ZERO] rule 1). Tips are never a
   separate untracked transfer: the band is the only tip mechanism.
4. When a signed sale authorization is used, `unitPrice` binds the minimum
   the authorization accepts ([SSA-AUTH] rule 3) and the sale record's
   band still bounds the buyer's choice.

## Airdrops And Operator Distributions

Airdrops — curator rewards, holder gifts, restitution mints,
collaborator allocations — are operator-initiated push distributions of
free mints to explicit recipients. The mint subsystem expresses them
natively (distinct per-token recipients, free phases, retired legacy
Core airdrop counters), and this section names the shape so every
deployment runs the same provably intentional pattern instead of
reinventing it (ADR 0012 decision T6).

Requirements [SSA-AIRDROP]:

1. An airdrop is a free batch mint under the standard manager path
   ([`docs/mint-policy-and-accounting.md`](mint-policy-and-accounting.md)
   Mint Requests), never a sale: no sale record, `saleId`, deposit,
   escrow, or official-revenue record exists or is emitted, and the
   phase policy is the complete authority. `ZERO_PRICE_CLAIM` remains
   the pull-based free mechanic (the claimant executes); an airdrop is
   the push-based one (the operator executes).
2. Shape: a dedicated phase ID; one `MintBatch` per distribution slice
   with explicit per-token `beneficiaries` (the committed recipients),
   `payer = address(0)` (executor-only flow, mint spec
   `MintBatch` rule 8), and batch size bounded by the phase
   `maxBatchQuantity`. Delivery takes one of two declared shapes:
   - Direct: `initialRecipients[i] == beneficiaries[i]` (no custody
     leg). A rejecting receiver reverts the whole committed batch, so
     this shape is valid only where the operator accepts that risk —
     and account code is a mutable per-execution property (EIP-7702),
     so "all recipients are EOAs" is never verifiable at commitment.
   - Failure-isolated (ADR 0013 decision U6): the executor is a
     registered adapter, the batch mints with
     `initialRecipients[i] = executing adapter` (a custody leg existing
     solely for delivery) and `beneficiaries[i]` the committed
     recipient, and the adapter attempts a bounded delivery to each
     beneficiary in the same transaction under
     `SALE_NFT_DELIVERY_GAS_LIMIT` ([SSA-GAS]). A failed or rejecting
     delivery diverts exactly that element to a pull NFT claim (the
     beneficiary directs delivery, [SSA-ENGLISH] rule 7 item (d)
     machinery; delegate-triggered per [SSA-DELEGATE] rule 9), evented
     `AirdropDeliveryDiverted` per element — the batch and its sibling
     deliveries never revert, and excluding a stale recipient never
     requires changing the committed set. `RECIPIENT`-keyed counters
     key the beneficiaries in both shapes (mint spec `[MPA-COUNTERS]`),
     so the custody leg changes delivery mechanics, never accounting.
     Distributions whose recipient set may contain contract accounts
     must use this shape. The failure-isolated shape configures only
     for `CORE_NATIVE` collections — its custody leg exits through a
     native Core entry that facade mode closes ([SSA-IDENTITY]
     rule 9; ADR 0015 decision W3); for an `EXTERNAL_FACADE`
     collection the direct shape is the conformant shape and carries
     no rejecting-receiver risk, because facade-mode mint delivery
     performs no receiver callback ([PV1-TRANSFER-CONTROLLER]
     requirement 12).
3. Executor: the phase declares no payment settlement, so the executor
   may be an operator EOA or a registered adapter — the [SSA-REGISTRY]
   rule 2 EOA prohibition binds paid phases only. Operator-key hygiene
   follows the governance spec's operational-grant rules.
4. Counters: a `PHASE`-scoped `CONSTANT` supply counter must bound the
   total distribution. Per-recipient fairness uses `RECIPIENT`-keyed
   counters, which key each element's beneficiary and aggregate
   duplicate recipients across the batch (mint spec `[MPA-COUNTERS]`);
   `MERKLE_STATIC` applies when the recipient set should be
   offline-verifiable per wallet.
5. Recipient-set commitment: the intended recipient set (or its
   selection rule) must be hash-committed in the phase `configHash`
   before execution, mirroring the `[MPA-MERKLE]` rule 7 publication
   posture, so a distribution is auditable against a declared list and
   never an unaccountable operator mint.
6. Reveal fees: for an `ASYNC` collection the [SSA-REVEAL] rule 2
   obligation falls on the operator — the distribution must be covered
   by reveal-fee escrow funding for the batch under [EC-REVEAL]
   ([`docs/stream-entropy-coordinator.md`](stream-entropy-coordinator.md)),
   so airdropped tokens meet the same reveal SLO as purchased ones.
7. Gate coverage: the [SSA-GATES] item 13 suite includes the airdrop
   distribution test (one batch to N distinct recipients on a free
   phase under a supply counter, no settlement record), and the mint
   spec's integration tests mirror it.

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
    bytes32 artworkCommitment;  // required nonzero iff mintAtSettlement,
                                // see [SSA-ENGLISH] 8
    address poster;             // no-bid NFT recipient (ADR 0001 lineage)
    uint96 reservePrice;        // may be zero (no reserve)
    uint16 minIncrementBps;     // floor-or-waiver, see [SSA-ENGLISH] 3
    bool incrementFloorWaived;  // explicit waiver, see [SSA-ENGLISH] 3
    bool hardClose;             // explicit anti-snipe waiver,
                                // see [SSA-ENGLISH] 4
    bool startOnFirstBid;       // reserve-met clock, see [SSA-ENGLISH] 14
    uint32 firstBidDuration;    // seconds, startOnFirstBid mode only
    uint64 startTime;
    uint64 endTime;             // zero in startOnFirstBid mode
    uint32 antiSnipeWindow;     // seconds, see [SSA-ENGLISH] 4
    uint32 antiSnipeExtension;  // seconds
    uint32 maxTotalExtension;   // seconds, cap over original endTime
    bytes32 expectedPrimaryPolicyHash;
    uint8 primaryPolicyMode;
    uint64 settlementWindow;    // seconds, mintAtSettlement drift envelope
}
```

### State Machine

```text
None -> Created            auction record written, custody expected
Created -> Active          custody confirmed (token held or mint deferred)
Active -> Active           valid bid; possible clock start or anti-snipe
                           extension
Active -> Cancelled        only before the first valid bid
Active -> EndedNoBid       endTime passed, no valid bid
Active -> EndedWithBid     endTime passed, valid highest bid
EndedNoBid -> SettledNoBid NFT left escrow via poster transfer or claim
EndedWithBid -> SettledWithBid   settlement executed (terminal)
EndedWithBid -> SettledNoMint    mint-at-settlement unsatisfiable; winner
                                 refund unlocked ([SSA-ENGLISH] 8)
Cancelled, SettledNoBid, SettledWithBid, SettledNoMint are terminal
```

Requirements [SSA-ENGLISH]:

1. Custody: an auctioned pre-minted token must be held by the auction
   contract (or a dedicated custody contract preserving these invariants)
   from `Created` until settlement, cancellation, or no-bid claim.
   `Created -> Active` fires only when custody is confirmed; bids before
   custody confirmation revert. `payOutAddress`-style payment identities
   are never custody. English auctions configure only for `CORE_NATIVE`
   collections: every variant runs a custody-and-native-delivery leg
   that Core closes for `EXTERNAL_FACADE` collections, so configuration
   reverts per the [SSA-IDENTITY] rule 9 identity-mode gate (ADR 0015
   decision W3).
2. Bid validity: bids are native ETH in protocol v1 (ERC-20 bidding has no
   genesis implementation; its frozen extension profile is
   [SSA-ERC20-BID]); a bid is valid only while `Active` and
   `block.timestamp < endTime` (in `startOnFirstBid` mode, only while no
   derived `endTime` exists yet or `block.timestamp < endTime`); the first
   valid bid must be `>= max(reservePrice, 1 wei)`. Where a
   mint-at-settlement reveal-fee line item applies ([SSA-REVEAL]
   rule 7), the recorded bid amount is `msg.value` net of that line
   item; the fee rides the bid escrow and never enters reserve,
   increment, or bid-comparison math.
3. Minimum increment: the floor is the per-sale-kind default, waivable
   only by an explicit recorded creation-time declaration (ADR 0013
   decision U6). With `incrementFloorWaived = false` (the default),
   `minIncrementBps` must be configured in
   `[100, 10_000]` (1% to 100%) and should be at least `500`; with the
   waiver declared, any value in `[0, 10_000]` is valid and a zero
   value accepts any strictly higher bid. A
   non-first bid must satisfy
   `bid >= highestBid + ceil(highestBid * minIncrementBps / 10_000)`.
   Increment configuration — including the waiver flag — is bound into
   `saleConfigHash` and emitted at
   creation, and bidder surfaces for a waived-floor auction must
   disclose the 1-wei-outbid exposure before bidding (the [SSA-CONTENT]
   rule 6 disclose-or-mitigate posture). Without the declared waiver,
   1-wei outbid griefing stays structurally impossible; with it, the
   exposure is a recorded, displayed curatorial choice, never a silent
   configuration accident.
4. Anti-snipe extension: the nonzero window is the per-sale-kind
   default, waivable only by the explicit `hardClose` creation-time
   declaration (ADR 0013 decision U6). With `hardClose = false` (the
   default), `antiSnipeWindow` and `antiSnipeExtension` must be
   configured in `[60, 86_400]` seconds and should default to `600`;
   when a
   valid bid arrives with `endTime - block.timestamp < antiSnipeWindow`,
   the auction must extend:
   `endTime = max(endTime, block.timestamp + antiSnipeExtension)`, bounded
   so `endTime` never exceeds `originalEndTime + maxTotalExtension`.
   `maxTotalExtension` must be configured in
   `[antiSnipeExtension, 604_800]` seconds. Every extension emits
   `AuctionExtended`. With `hardClose = true`, `antiSnipeWindow`,
   `antiSnipeExtension`, and `maxTotalExtension` must all be zero, the
   deadline never extends, and the declaration is bound into
   `saleConfigHash`, emitted through the zero window in
   `AuctionCreated`, and disclosed on bidder surfaces as snipe
   exposure before bidding. Any other mixture of waiver flag and
   window values reverts at configuration. Extension-budget
   exhaustion is a declared state, never a silent one (ADR 0014
   decision V5): once cumulative extensions consume
   `maxTotalExtension`, the deadline is fixed and the auction is in a
   budget-exhausted hard close — bidder surfaces must display the
   fixed deadline as snipe exposure exactly as they display a declared
   `hardClose` waiver, and must expose the remaining extension budget
   (`maxTotalExtension - totalExtensionUsed`, read per rule 16 or
   derived from `AuctionExtended` against `AuctionCreated`) while any
   remains. The extension whose result first consumes half or more of
   `maxTotalExtension` additionally emits
   `AuctionExtensionBudgetWarning` — at most once per auction — with
   the used and remaining seconds, so a long bidding war approaches
   its boundary announced, never discovered. Because a rule 3 waived
   increment floor makes budget burn by 1-wei self-outbids cheap, the
   rule 3 waiver disclosure must state that composition when both
   waived increments and anti-snipe extension are configured
   together. Accepting snipe exposure is
   therefore a recorded, displayed choice — hard-deadline auction
   formats exist without a new adapter, and the safe defaults bind
   everyone who does not explicitly opt out.
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
   the NFT: attempt the transfer to the winner as a bounded call under
   the `SALE_NFT_DELIVERY_GAS_LIMIT` Governed Gas Parameter with the
   63/64 parent-gas precheck and capped returndata copying (ADR 0013
   decision U6, closing the one unbounded adapter external call), and
   if the delivery attempt fails — a rejecting receiver, an
   out-of-stipend callback, or malformed returndata —
   record a pull NFT claim (winner directs
   delivery to any receiver; a live registered delegate of the winner
   may trigger the claim per [SSA-DELEGATE] rule 9) rather than
   blocking settlement. No delivery path classifies the winner by code
   presence; the attempt-then-claim shape is account-type-free. Failed
   split-recipient hooks divert to owed escrow per the revenue spec and
   cannot revert settlement.
8. Mint-at-settlement variant (`mintAtSettlement = true`): settlement is a
   paid mint and must execute the revenue spec's `PREPARED_MINT` path in
   the settlement transaction with `beneficiaries = [winner]`, where the
   winner's delivery identity is their rule 15 `deliverTo` binding
   (the winning bidder itself absent a binding).
   Artwork commitment (ADR 0012 decision T6): configuration must bind a
   nonzero `artworkCommitment` when `mintAtSettlement = true` and a zero
   one otherwise, committed in `saleConfigHash` and emitted in
   `AuctionCreated`, so what is being auctioned is an onchain fact from
   creation, not an offchain preview. The commitment is either (a) the
   exact per-token `tokenDataHash` — `keccak256(tokenData)` of the work
   to be minted — or (b) a `contentLeaf` per [SSA-CONTENT] rule 1 where
   the auction record also pins the content manifest root (curated
   pick-from-manifest auctions). Settlement recomputes
   `keccak256(tokenData)` for the minted work — and, in the leaf form,
   verifies the presented `(contentId, tokenDataHash, proof)` against
   the pinned root and the recomputed hash against the leaf — and
   reverts with `AuctionArtworkMismatch` on any mismatch, so the winner
   provably receives exactly the auctioned work and the mint spec's
   content-swap claim (`[MPA-CONSENT]` rule 5) holds on this path. A
   signed sale authorization participating in the settlement binds the
   same value through `contentSelectionHash` ([SSA-AUTH] rule 4). The
   delivery shape is account-type-free (ADR 0013 decision U6,
   superseding the ADR 0011 decision R9 account-type branch):
   settlement always mints with `initialRecipients = [adapter custody]`
   and `beneficiaries = [winner]`, then attempts the bounded
   custody-to-winner delivery of rule 7 item (d) under
   `SALE_NFT_DELIVERY_GAS_LIMIT` in the same transaction, recording the
   pull NFT claim on a failed attempt. No settlement path branches on
   winner code presence — under EIP-7702 code presence is a mutable
   per-transaction property, never an account type — so a code-free
   winner is delivered by the succeeding attempt, an EIP-7702-delegated
   or contract winner is delivered exactly when its receiver accepts
   within the bound, and a rejecting or hostile receiver diverts to
   the claim and can never
   revert or replay-grief the settlement. If the bound mint is
   unsatisfiable at settlement for a typed non-transient reason, or no
   settlement has executed by `endTime + settlementWindow` (the auction's
   finalize-by deadline under
   [Deferred Settlement Drift Envelopes](#deferred-settlement-drift-envelopes)),
   a permissionless transition records the terminal `SettledNoMint`
   state, emits `AuctionSettledNoMint` with the reason hash, and unlocks
   the winner's full escrowed funds as a pull refund (ADR 0011 decision
   R6). `settlementWindow` must be pinned in `[86_400, 7_776_000]`
   seconds (1 to 90 days) and committed in `saleConfigHash`.
9. Auction-start custody mint (`AUCTION_START_CUSTODY`): a token minted
   into auction custody before bidding is an unpaid custody mint, not a
   paid mint. The custody mint phase must set
   `initialRecipients[i] = beneficiaries[i] = auction custody` and must
   configure only `CONSTANT`, `EXECUTOR`, or `CONTEXT` keyed counters;
   `RECIPIENT`/`PAYER`-keyed counters are invalid on custody-mint phases
   because no final owner exists yet. Configuration must revert otherwise.
   Per-collector accounting for the auction lives in the sale record, and
   the custody-to-winner transfer at settlement is the economic delivery.
10. No-bid outcome: `EndedNoBid` settles the NFT to `poster` through the
    rule 7 item (d) shape — a bounded delivery attempt under
    `SALE_NFT_DELIVERY_GAS_LIMIT`, diverting to a pull NFT claim on a
    failed attempt, with no code-presence branching (ADR 0013 decision
    U6) — and `SettledNoBid` is recorded only after the NFT leaves
    escrow through the delivered attempt or the claim is recorded.
    Reserve-not-met expiry is a no-bid outcome.
11. Cancellation exists only before the first valid bid and before
    `endTime`; it is terminal, evented with a reason hash, and releases
    custody to `poster`. After the first bid, the only emergency control
    is the pause surface of [Emergency Pause](#emergency-pause), which
    preserves bidder credits, tolls the bidding clock, and never
    confiscates funds or strands the NFT. Pre-bid cancellation is also
    a seller-side race a bidder cannot see (ADR 0014 decision V5): a
    poster watching the mempool can front-run an incoming
    reserve-meeting first bid with a cancellation (or a custody-grant
    revocation, [SSA-CUSTODY-ENTRY] rule 4), revert the bid, harvest
    the free price discovery, and relist higher. The exposure is
    disclosed, not silently carried: bidder surfaces for an unbid
    auction must state, before bidding, that the listing is
    poster-cancellable until the first valid bid lands (the
    [SSA-CONTENT] rule 6 disclose-or-mitigate posture), and must
    display the poster's historical pre-bid cancellation and
    custody-revocation counts — derivable entirely from
    `AuctionCancelled`, `SaleCustodyReleased`, and
    `SaleCustodyGrantRevoked` history joined to poster identity
    through `AuctionCreated` and `SaleCustodyDeposited`, so serial
    price-discovery harvesting is visible with no new onchain field.
    The disclosure fields are release evidence under [SSA-GATES]
    item 21.
12. Refund, proceeds, and NFT claims remain claimable forever; emergency or
    surplus withdrawals must never touch owed bidder credits, owed
    proceeds, or escrowed NFTs.
13. `auctionId` and `saleId` bind every bid, extension, settlement, and
    claim event, and settlement rejects if the signed policy hash, payer,
    recipient, executor, or amount does not match the auction state.
14. First-bid-starts mode (`startOnFirstBid = true`, ADR 0011 decision
    R9): configuration must set `endTime = 0`, a nonzero `reservePrice`,
    and `firstBidDuration` in `[3_600, 2_592_000]` seconds (1 hour to 30
    days). Bids are accepted from `startTime` with no upper time bound
    while no valid bid exists. The first valid bid — which must meet the
    reserve per rule 2 — sets `endTime = block.timestamp +
    firstBidDuration` in the same transaction and emits `AuctionExtended`
    with `previousEndTime = 0`, so indexers see the derived clock from
    the bid that started it. From that point rules 3 through 13 apply
    unchanged, with the derived `endTime` serving as `originalEndTime`
    for the anti-snipe cap. While no valid bid exists there is no
    `endTime`: the rule 11 cancellation path stays available for the
    whole unbid period (the poster can always withdraw an unstarted
    auction), and the `EndedNoBid` outcome is unreachable in this mode —
    an auction that never starts is cancelled, never expired.
    Preset-window auctions (`startOnFirstBid = false`) must set
    `firstBidDuration = 0` and a nonzero `endTime`; any other
    combination reverts at configuration.
15. Deliver-to binding (ADR 0013 decision U6): bid placement accepts an
    optional `deliverTo` account, bound at that bidder's first bid for
    the auction and immutable thereafter, evented
    `AuctionBidDeliveryBound`; absent the binding,
    `deliverTo = bidder`. When `deliverTo` differs from the bidder, the
    adapter verifies the delegation at binding time per [SSA-DELEGATE]
    rule 7 and fails closed. Delivery surfaces target `deliverTo`: the
    rule 7 item (d) attempt and pull NFT claim, and — for
    mint-at-settlement — `beneficiaries = [deliverTo]`, so
    `RECIPIENT`-keyed counters key the vault exactly as deliver-to-vault
    minting does. Escrowed-fund credits — outbid refunds, the rule 8
    `SettledNoMint` unlock, and reveal-fee returns — stay keyed to the
    bidding wallet, which escrowed them: the delegate route moves the
    artwork to the vault, never the vault's funds through the hot
    wallet. Settlement performs no delegation read; the binding is
    bid-time-verified authority, exactly like signer-verified tickets
    ([SSA-DELEGATE] rule 4), so a delegation revoked after binding
    never unbinds a placed bid.
16. Integrator-readable protection surface (ADR 0014 decision V5):
    bidder-protection state must be renderable from one state read,
    not from decoding creation events, because over decades most bids
    will not originate from the operator's frontend. The auction
    house exposes the Permanent read

    ```solidity
    function auctionConfig(bytes32 auctionId)
        external
        view
        returns (
            uint16 minIncrementBps,
            bool incrementFloorWaived,
            bool hardClose,
            uint32 antiSnipeWindow,
            uint32 antiSnipeExtension,
            uint32 maxTotalExtension,
            uint32 totalExtensionUsed,
            uint64 endTime
        );
    ```

    reporting exactly the created configuration plus live extension
    accounting and the live deadline, so any third-party marketplace,
    bot, or wallet bidding directly onchain can render the
    1-wei-outbid exposure (rule 3), the snipe exposure (rule 4,
    including the remaining extension budget), and the current close
    before bidding. Marketplace integration guidance must name this
    read, and the [SSA-GATES] item 1 suite proves it matches the
    `saleConfigHash`-committed configuration and the live extension
    state.

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
   `startPrice >= restingPrice`, `startPrice >= 1`,
   `endTime > startTime`, and for `STEPPED`,
   `stepSeconds > 0` and `stepAmount > 0`. `restingPrice >= 1` is
   required for both Dutch kinds (ADR 0013 decision U6) unless the sale
   record carries an explicit declared free-mint class — a
   creation-time declaration bound into `saleConfigHash`, disclosed on
   buyer surfaces, and valid only in standard mode (clearing mode
   always requires `restingPrice > 0`,
   [SSA-DUTCH-CLEARING] rule 1). Under the declaration, a purchase at
   price zero executes [SSA-ZERO] rule 1 semantics — a free mint with
   no settlement-boundary deposit and no official-revenue record — so
   an amount-0 official settlement can never exist: without the
   declaration a decay-to-zero schedule reverts at configuration
   (`DutchScheduleInvalid`), and with it the zero boundary is the
   declared `ZERO_PRICE_CLAIM` mechanic, never a paid path emitting
   zero-value settlement evidence. A schedule that is free from the
   start is not a Dutch sale: `startPrice = 0` always reverts (use
   `ZERO_PRICE_CLAIM`).
2. Current price is deterministic from the schedule and `block.timestamp`:
   `LINEAR` interpolates from `startPrice` to `restingPrice` over
   `[startTime, endTime]`; `STEPPED` subtracts `stepAmount` every
   `stepSeconds`; both floor at `restingPrice`, and the price after
   `endTime` is `restingPrice`.
3. Maximum-price purchases (ADR 0011 decision R6): a time-varying price
   must never demand exact payment, mirroring the entropy fee binding
   ([`docs/stream-entropy-coordinator.md`](stream-entropy-coordinator.md)
   [EC-FEEBIND]). For native purchases, `msg.value` (net of the
   [SSA-REVEAL] line item) is the buyer's binding maximum: the purchase
   reverts with `DutchPaymentBelowPrice` only if that maximum is below
   `currentPrice * quantity`, charges exactly the schedule price at
   execution, and credits the excess to the payer as a pull refund from
   adapter escrow in the same transaction, emitting
   `SalePaymentExcessCredited`. For ERC-20 purchases, the `PaymentIntent`
   `maxAmount` is the ceiling and the adapter pulls exactly
   `currentPrice * quantity` under the revenue spec's exact-delta rule,
   so no excess exists. A signed sale authorization binds `unitPrice` as
   the maximum per [SSA-AUTH] rule 3. Block-timing drift, `STEPPED`
   boundaries, and builder-delayed inclusion therefore never revert a
   funded purchase and never grant anyone a griefing lever.
4. Standard mode (`DUTCH_AUCTION`): each purchase pays the current schedule
   price and executes a standard paid mint path in the purchase
   transaction ([SSA-FIXED] rule 1, with the rule 3 maximum-price binding
   in place of exact payment). No rebates beyond the rule 3 excess credit
   exist in standard mode and the sale record must say so.
5. `DutchDecayKind` is an append-only numeric-catalog vocabulary under
   `[LCM-IDS]`, exactly as `SaleKind` is under [SSA-IDENTITY] rule 6
   (ADR 0012 decision T6): `LINEAR = 0` and `STEPPED = 1` are pinned in
   the Numeric ID Catalog
   ([`docs/launch-conformance-matrix.md`](launch-conformance-matrix.md)),
   never renumbered or reused, and new decay kinds (values `2` and up)
   are allocated append-only by future accepted adapter specs through
   that catalog. The `STREAM_DUTCH_SCHEDULE_V1` preimage carries the
   kind as `uint8`, so an appended kind extends the existing schedule
   domain unchanged; only a schedule whose field shape changes (new
   curve parameters beyond the struct above) takes a new versioned
   schedule domain. At genesis, `STEPPED` is the sanctioned
   approximation for exponential and half-life curves; a native
   exponential kind is a future appended kind, not a reinterpretation
   of an existing value.

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
   escrow tagged to the purchase record (`purchaseId` per
   [SSA-IDENTITY]). The token mints at purchase time, and the [SSA-DUTCH]
   rule 3 maximum-price binding applies to `p`.
3. The clearing price is fixed at finalization: if the sale sold out, the
   clearing price is the schedule price at the last accepted purchase;
   otherwise it is the
   schedule price at the close (`restingPrice` when the schedule has fully
   decayed). Clearing-price fixing reads only schedule prices: a
   purchase executed under a Merkle `priceOverride` ceiling
   ([SSA-AUTH] rule 3) enters at its schedule price at execution,
   never its discounted charge, so per-subject discounts can never
   drag the uniform price fixed for everyone else (ADR 0013 decision
   U6). Finalization is permissionless once the sale is sold out or
   closed, happens exactly once, and emits `DutchClearingFinalized`. The
   sale's finalize-by deadline is the sold-out or close time plus the
   sale record's finalization window
   ([Deferred Settlement Drift Envelopes](#deferred-settlement-drift-envelopes)).
4. Rebates are decoupled from supplemental settlement (ADR 0011 decision
   R6): at finalization, `p - clearing` per token becomes a pull rebate
   credit for the payer immediately and unconditionally, claimable
   forever. For a purchase executed under a `priceOverride` ceiling
   (ADR 0013 decision U6), the buyer's uniform price is
   `min(clearing, priceOverride)`: the rebate is the charged price
   minus that value and the supplemental leg is that value minus
   `restingPrice`, so a discount ceiling never charges above itself.
   In the same finalization, `clearing - restingPrice` per token
   (per-purchase, the buyer's uniform price minus `restingPrice`)
   flows from adapter escrow to official settlement as supplemental
   primary revenue under the same `saleId`, executed `ALLOW_CURRENT`
   against the then-current resolved primary policy with observed drift
   evented; a clearing sale record must bind `ALLOW_CURRENT` for this
   deferred leg ([SSA-ENVELOPE] rule 3), so an assignment change or
   freeze between purchase and finalization can never block rebates or
   deadlock the sale.
5. Escrowed overage is refundable-class funds until finalization: it must
   never be counted, flushed, or released as official revenue before
   finalization, and after finalization only the supplemental-revenue part
   moves; rebates never touch official settlement. Post-finalization price
   changes, retroactive rebates from settled revenue, and rebate
   expiration are all invalid.
6. Refund unlock (ADR 0011 decision R6): if finalization has not executed
   by the finalize-by deadline, or finalization fails for a typed
   non-transient reason, a permissionless unlock marks the sale's
   escrowed overage refundable, emits `DutchClearingRefundUnlocked` with
   the reason hash, and converts every purchase's full overage
   (`p - restingPrice` per token) into a pull refund. The floor revenue
   settled conformantly at purchase is untouched; the unlocked state is
   terminal and no supplemental revenue settles afterward. Buyer funds
   can never strand in clearing escrow.

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
    "uint64 deadline,uint64 finalizeBy)"
);
```

Requirements [SSA-OFFER]:

1. A buyer signs a `SaleOffer` (EIP-712, domain per [SSA-AUTH] 1).
   `tokenId` is zero for collection-level mint offers;
   `contentSelectionHash` may bind a specific unminted work. The signer
   may instead be a live registered delegate of `buyer` per
   [SSA-DELEGATE] rule 8 (ADR 0013 decision U6): the execution
   presentation then carries the claimed signer, the adapter verifies
   the delegation live and the signature against that signer under the
   mint spec's `[MPA-AUTHZ]` rules, and the offer's economics still
   bind `buyer` as beneficiary and delivery target. A delegate-signed
   offer never satisfies the rule 3 payer-intent role — spending the
   vault's ERC-20 funds always requires the payer's own signed
   `PaymentIntent` ([SSA-DELEGATE] rule 8).
2. Acceptance authority is the seller side: an authorized sale signer for
   the collection countersigns a `SaleAuthorization` whose economic fields
   exactly match the offer, subject to the artist-consent requirements the
   mint spec pins for artist-bound collections.
3. Execution verifies both signatures, consumes both nonces per rule 4,
   requires `block.timestamp <= min(offer.deadline,
   authorization.deadline)`, and settles per [SSA-PRIVATE] 2. For ERC-20
   offers, the `SaleOffer` also satisfies the payer-intent role only if
   it meets every `[RSR-PAYMENT-INTENT]` field requirement; otherwise a
   separate `PaymentIntent` is required.
4. Nonce-consumption locus (ADR 0011 decision R9). The durable replay
   store is pinned per settlement shape, never left to implementation
   choice:
   - Mint-executing acceptance (dual-digest consumption, ADR 0013
     decision U6): the two digests are consumed atomically in the
     acceptance transaction, each in its own durable store. The offer
     digest is the mint-ledger replay fact: the ledger
     `authorizationId` is derived from the offer's full EIP-712 digest
     under the mint spec's `[MPA-TICKET]` rule 4 derivation — the
     `TICKET_AUTHORIZATION_DOMAIN` wrapping of the offer digest, never
     the raw digest and never a combination of the two digests — and
     the manager consumes it, so a consumed offer can never re-execute
     under a freshly signed authorization (a fresh authorization nonce
     changes nothing the ledger keys on). The matching
     `SaleAuthorization` digest is consumed in the same transaction
     through the adapter's append-only consumed-digest store (the
     custody-path store below), written before any external
     interaction and evented `SaleAuthorizationConsumed`, so one
     authorization can never serve a second offer.
   - Custody-transfer acceptance and every other non-mint settlement
     (`[RSR-SETTLEMENT-BOUNDARY]` rule 7 paths, where no mint-ledger
     consumption occurs): the adapter owns a durable, append-only
     consumed-digest store written in the settlement transaction before
     any external interaction, covering both the offer digest and the
     matching authorization digest, and emits
     `SaleAuthorizationConsumed` for each. The EIP-712 domain binds
     `verifyingContract = saleAdapter`, so consumption state is
     adapter-scoped by construction: a digest can never replay against a
     successor adapter, successor adapters never import or revive
     predecessor digests, and authorizations die with their adapter
     (re-sign under the successor).
5. Offer revocation follows the same locus split, with the call
   mechanics pinned (ADR 0012 decision T6): mint-path offers revoke
   through the mint-ledger revocation surface (mint spec `[MPA-LEDGER]`
   rule 3, `[MPA-TICKET]` rule 5), voiding exactly the rule 4
   ledger replay key — the `[MPA-TICKET]` rule 4 derivation over the
   offer digest, the same value acceptance would consume, never the
   raw digest (ADR 0013 decision U6) — with the mint spec's
   full-payload presentation shape. Custody-path
   offers revoke through the adapter's consumed-digest store: the
   revocation call presents the full `SaleOffer` struct, the adapter
   recomputes the EIP-712 digest under its [SSA-AUTH] rule 1 domain and
   voids it into the store when `msg.sender == offer.buyer` (buyer-sent)
   or when the call carries the buyer's valid signature over the pinned
   payload

   ```text
   SALE_OFFER_REVOCATION_TYPEHASH = keccak256(
       "SaleOfferRevocation(uint256 chainId,address saleAdapter,"
       "bytes32 offerDigest)"
   );
   ```

   verified under the same domain and the mint spec's `[MPA-AUTHZ]`
   rules (`offer.buyer` is the claimed 1271 account for a
   contract-wallet buyer), evented `SaleOfferRevoked`. Sale
   authorizations consumed adapter-side — custody-path acceptance and
   mint-executing offer acceptance (rule 4; [SSA-AUTH] rule 6) —
   revoke through the same store with an implementable contract-signer
   path (ADR 0013 decision U6): the caller presents the full
   `SaleAuthorization` plus the claimed authorizer address and
   `authorizerKind` ([SSA-AUTH] rule 1 presentation; the struct
   carries no authorizer field, so the claimed account is calldata,
   never a recovery), the adapter recomputes the authorization digest
   and verifies the claimed authorizer against the collection's
   authorized sale-signer set, and voids the digest when `msg.sender`
   is the claimed-and-verified authorizer (the direct path a Safe
   executes as a normal transaction) or when the call carries that
   authorizer's valid signature — ECDSA or bounded ERC-1271 under
   `SALE_ERC1271_GAS_LIMIT`, per `[MPA-AUTHZ]` — over

   ```text
   SALE_AUTHORIZATION_REVOCATION_TYPEHASH = keccak256(
       "SaleAuthorizationRevocation(uint256 chainId,address saleAdapter,"
       "address authorizer,bytes32 authorizationDigest)"
   );
   ```

   whose `authorizer` field must equal the claimed account and whose
   `authorizationDigest` must equal the recomputed digest, evented
   `SaleAuthorizationRevoked`. Because the digest binds the struct and
   not the signer, authorizations over one struct share one digest and
   one consumption/revocation fate across every signer in the
   authorized set; intentionally distinct authorizations differ by
   `nonce`. Implementations must not invent a
   digest-to-signer storage mapping or accept bare digests; the
   presentation shape is the conformant one. Revealing an unleaked
   payload in revocation calldata is safe by construction: the payload
   authorizes only its bound parties and terms, and the void writes the
   consumed-digest store in the same transaction, so nothing executes
   after it lands; where the bound counterparty is actively racing,
   revocation is a mempool race the revoker should close with private
   submission. Both revocations are one-way and permanent.
6. Genesis offer acceptance is atomic: no buyer funds are escrowed before
   the acceptance-execution transaction, so no deferred-settlement leg
   exists and `finalizeBy` is zero. A future offer kind that escrows
   funds at offer time requires its own accepted spec and must bind the
   full drift envelope of
   [Deferred Settlement Drift Envelopes](#deferred-settlement-drift-envelopes),
   for which the signed `finalizeBy` field is reserved.
7. Standing orderbooks, collection-wide floor offers, and offer matching
   are excluded from protocol v1; a genesis offer targets one collection,
   token, or content selection at a time.

### Custody Entry And Owner Custody Grants

Offer acceptance and consignment listings settle custody-held tokens,
and until now no rule said how a seller-held minted token enters
custody outside auction creation. This section pins that step — the
owner-signed custody grant, revocable until sale (ADR 0012 decision
T6) — so implementers never invent the escrow-entry ordering the
ADR 0002 lineage exists to protect.

```text
SALE_CUSTODY_GRANT_TYPEHASH = keccak256(
    "SaleCustodyGrant(uint256 chainId,address saleAdapter,address core,"
    "uint256 tokenId,address owner,bytes32 saleRef,bytes32 nonce,"
    "uint64 deadline)"
);
```

Requirements [SSA-CUSTODY-ENTRY]:

1. Custody of an owner-held minted token enters an adapter only under a
   live owner custody grant: owner-sent (the token owner calls the
   adapter's deposit entrypoint directly) or owner-signed (the
   `SaleCustodyGrant` above, EIP-712/ERC-1271 under the [SSA-AUTH]
   rule 1 domain and the mint spec's `[MPA-AUTHZ]` verification rules).
   The grant binds `core`, `tokenId`, `owner`, and the sale reference
   it serves: `saleRef` is the `saleId` for auction and inventory
   consignment, or the offer digest for offer acceptance. A grant whose
   `owner` is not `ownerOf(tokenId)` at execution is invalid
   (`CustodyGrantInvalid`).
2. Custody entry is a same-transaction
   `transferFrom(owner, adapter, tokenId)` executed by the adapter
   after grant verification and before any settlement effect that
   presumes custody; entering custody establishes the [SSA-ENGLISH]
   rule 1 custody invariants. For offer acceptance of a seller-held
   token, custody entry executes inside the acceptance transaction —
   after both signatures verify and both digests are consumed
   ([SSA-OFFER] rules 3 and 4), before the `AUCTION_SETTLEMENT_TRANSFER`
   ordering runs — so custody entry, settlement, and delivery are one
   transaction with no interim custody state. Custody entry exists
   only for `CORE_NATIVE` collections: the [SSA-IDENTITY] rule 9
   identity-mode gate excludes every custody flow for
   `EXTERNAL_FACADE` collections at configuration (ADR 0015 decision
   W3).
3. Consignment deposits — custody entered ahead of a sale opening
   (custody-inventory listings, pre-listed auction pieces) — are
   evented `SaleCustodyDeposited` and recorded against the sale
   record's `poster`/consignor identity.
4. Revocable until sale: before the sale executes against the token —
   first valid bid for auctions ([SSA-ENGLISH] rule 11's pre-bid
   boundary), purchase for inventory sales, acceptance execution for
   offers — the consignor may revoke the grant and reclaim custody
   through a pull release under the [SSA-ENGLISH] rule 10 claim rules,
   evented `SaleCustodyReleased` with a reason hash. After the sale
   executes, the grant is spent and custody follows settlement. Grant
   digests consume through the adapter's append-only consumed-digest
   store ([SSA-OFFER] rule 4) at custody entry, so a grant executes at
   most once, and revocation follows the [SSA-OFFER] rule 5
   presentation mechanics with its own pinned payload (ADR 0014
   decision V6) — reusing `SALE_OFFER_REVOCATION_TYPEHASH` would put
   a grant digest into a field named `offerDigest`, a cross-family
   digest injection under a mismatched type string:

   ```text
   SALE_CUSTODY_GRANT_REVOCATION_TYPEHASH = keccak256(
       "SaleCustodyGrantRevocation(uint256 chainId,address saleAdapter,"
       "address owner,bytes32 grantDigest)"
   );
   ```

   The revocation call presents the full `SaleCustodyGrant` struct;
   the adapter recomputes the grant digest under its [SSA-AUTH]
   rule 1 domain and voids it into the consumed-digest store when
   `msg.sender == grant.owner` (owner-sent) or when the call carries
   the owner's valid signature — EIP-712 or bounded ERC-1271 under
   `SALE_ERC1271_GAS_LIMIT`, per the mint spec's `[MPA-AUTHZ]` rules
   — over the payload above, whose `owner` field must equal the
   grant's owner and whose `grantDigest` must equal the recomputed
   digest. The void is evented `SaleCustodyGrantRevoked` and is
   one-way; where custody already entered under the grant, the same
   call stages the custody reclaim through this rule's pull-release
   path, releasing to the owner only — a relayer can trigger the
   reclaim, never redirect it. Bare digests and digest-to-owner
   storage mappings are nonconformant, exactly as [SSA-OFFER] rule 5
   pins for offers. Pre-sale revocation is also the seller-side race
   [SSA-ENGLISH] rule 11 discloses; consignment and auction bidder
   surfaces carry that duty (ADR 0014 decision V5).
5. Single-token consignment is a one-entry `CUSTODY_INVENTORY_FIXED_PRICE`
   manifest — the sanctioned shape; no separate consignment kind
   exists. Auction consignment binds the consignor as `poster`. The
   economic boundary for consigned, previously-delivered tokens is
   [SSA-CONSIGN].

## Custody-Inventory Fixed-Price Sales

`CUSTODY_INVENTORY_FIXED_PRICE` sells already-minted, adapter-custodied
tokens first-come-first-served at a fixed price — gallery inventory,
physical-first drops, and relisted no-bid auction pieces — closing the gap
between one-buyer private sales and mint-at-purchase fixed price
(ADR 0011 decision R9).

Requirements [SSA-INVENTORY]:

1. The sale record commits an inventory manifest — the exact token ID set
   offered, hash-committed into `saleConfigHash` before the sale opens —
   and binds a `poster` (the consignor address unsold custody returns
   to). Every listed token must be held in adapter custody under the
   [SSA-ENGLISH] rule 1 custody invariants from sale opening until it is
   sold, released, or the sale is cancelled.
2. A purchase binds the buyer at execution, not at configuration: any
   eligible caller may buy any unsold listed token at the fixed
   `unitPrice` ([SSA-FIXED] rule 2 exact payment). Per-buyer fairness may
   use the sale record's per-buyer cap; no mint-ledger counters apply
   because the tokens are already minted.
3. Each purchase executes the revenue spec's `CUSTODY_SETTLEMENT_TRANSFER`
   order realized as [SSA-ENGLISH] rule 7 with the buyer as winner:
   official revenue settles before the custody-to-buyer transfer, a
   contract buyer whose receiver rejects gets the pull NFT claim, and
   settlement is idempotent per token.
4. Double-sale prevention is adapter-local: the sale record tracks a
   one-way per-token sold status written before any external interaction
   in the purchase transaction; a second purchase of the same token
   reverts with `InventoryTokenUnavailable`.
5. Unsold tokens are released, not stranded: cancellation or close
   releases remaining custody to the sale's poster through the no-bid
   claim rules ([SSA-ENGLISH] rule 10), and the release is evented per
   token.

### Consignment Boundary

The custody machinery of this document — English auctions of
custody-held tokens, custody-inventory sales, private sales, and offer
acceptance — can express the sale of a previously-sold, collector- or
estate-consigned token. Whether that is conformant, and on which side
of the primary/secondary line it settles, is a spec fact, not an
inference (ADR 0012 decision T6).

Requirements [SSA-CONSIGN]:

1. Consigned resales are permitted through the custody adapters:
   estate pieces, museum deaccessions, artist-retained proofs, and
   collector consignments enter custody per [SSA-CUSTODY-ENTRY] and
   sell through the existing custody kinds. This is the single carved
   exception to Protocol v1 Exclusions item 5, and it exists only under
   the rules below — orderbooks, floor offers, marketplace aggregation,
   and listing services remain excluded.
2. The primary/secondary line is first delivery to a collector: a token
   whose history includes a paid settlement to a buyer or a claim
   delivery to a beneficiary settles as consignment when resold through
   this layer; a token only ever held as unsold operator inventory
   (no-bid poster returns, unsold inventory releases, custody mints
   never delivered) remains primary inventory. The sale record must
   declare its side of the line; the declaration is checkable from the
   token's transfer history, and a misdeclared record is nonconformant
   ([SSA-GATES] item 18).
3. A consignment sale settles as a secondary transfer, never as primary
   revenue (ADR 0012 decision T6): its sale record binds the
   consignment declaration with `expectedPrimaryPolicyHash = 0`, no
   primary policy, split template, or `[RSR-TEMPLATES]` artist-take
   floor applies, and its proceeds never enter the revenue spec's
   primary settlement boundary or any official-revenue counter.
   Consignor proceeds are recorded as adapter pull credits
   ([SSA-ADAPTER] rules 4 and 14), claimable forever.
4. Royalty disclosure and delivery: consignment settlement must read
   `royaltyInfo(tokenId, price)` (royalty semantics home:
   [`docs/revenue-splits-and-royalties.md`](revenue-splits-and-royalties.md)
   Royalties) and itemize the royalty amount and receiver in the sale
   record surfaces and the `ConsignmentSettled` event. The royalty
   amount is deducted from consignor proceeds and delivered to the
   recorded receiver by a bounded attempt in the settlement
   transaction; a failed delivery diverts it to an adapter pull credit
   owed to exactly that receiver, with a permissionless bounded retry
   to the recorded receiver — the platform's own consignment rail
   honors the collection's royalty policy by construction and a
   reverting receiver can never block settlement.
5. Consignment settlement order (the `CUSTODY_SETTLEMENT_TRANSFER`
   shape with the primary-revenue step replaced by consignor
   accounting): (a) verify sale state, custody, and payment; (b) mark
   the token sold and write the settlement record; (c) compute
   `royaltyInfo`; (d) credit consignor proceeds (`price - royalty`) as
   a pull claim; (e) attempt the rule 4 royalty delivery; (f) deliver
   the NFT per [SSA-ENGLISH] rule 7 item (d). Effects precede every
   external interaction and settlement is idempotent per token.
6. Artist economics on a consignment sale are the collection's royalty
   policy — the secondary-market instrument — never a primary template;
   the [SSA-IDENTITY] rule 8 sale-parameter consent scope governs
   primary sale records only.
7. Collector disclosure (ADR 0013 decision U6): consignment sale
   records and buyer surfaces must disclose, before any purchase or
   bid, (a) that the sale settles as a secondary transfer outside
   primary economics — no primary policy, split template, or
   artist-take floor applies; (b) the rule 4 royalty itemization
   (amount and receiver) for the quoted price; and (c) the platform's
   secondary posture: resale outside this consignment rail happens on
   external marketplaces where royalty payment is disclosure-only
   (home:
   [`docs/revenue-splits-and-royalties.md`](revenue-splits-and-royalties.md)
   [RSR-MARKETPLACE-ROYALTY]), and the royalty-honoring consignment
   rail exists. The radical-honesty term artists acknowledge is thereby
   shown to buyers of the same economic fact; the disclosure fields are
   rehearsal/release evidence under [SSA-GATES] item 18.

## Deferred Settlement Drift Envelopes

Every escrow-holding sale mode defers some settlement to a later
transaction, and every deferred settlement can meet drift: policy hashes
rotate, phases end, supply exhausts, disputes open, modules get revoked.
The round-1 model left those legs exact-match-forever, which is a
fund-stranding deadlock. Protocol v1 instead binds a drift envelope at
purchase and guarantees a refund exit past it (ADR 0011 decision R6).

Requirements [SSA-ENVELOPE]:

1. The escrow-holding deferred-settlement modes are `REFUND_WINDOW`
   finalization, `DUTCH_AUCTION_CLEARING` supplemental settlement,
   `mintAtSettlement` English auction settlement, and any future kind
   whose accepted spec escrows buyer funds ahead of official settlement
   (including escrowed offers, [SSA-OFFER] rule 6). Atomic
   purchase-and-settle paths have no deferred leg and no envelope.
2. Envelope binding at purchase: every escrowed purchase or winning bid
   binds (a) the buyer's maximum price — native `msg.value` (net of any
   [SSA-REVEAL] line item) under the
   [SSA-DUTCH] rule 3 maximum-price rule, `PaymentIntent.maxAmount` for
   ERC-20, or the signed `unitPrice`/`price`; (b) the sale reference
   (`saleId`, and `purchaseId` or `auctionId` where one exists); and
   (c) a finalize-by deadline derived from a finalization window pinned
   in the sale record and committed in `saleConfigHash`. Where a signed
   authorization or offer participates, its `finalizeBy` field binds the
   same deadline ([SSA-AUTH] rule 8). A deferred settlement must never
   charge above the bound maximum.
3. Deferred legs settle `ALLOW_CURRENT`: a sale record configuring an
   escrow-holding kind must bind `primaryPolicyMode = ALLOW_CURRENT` for
   the deferred settlement leg, and configuration binding `STRICT_MATCH`
   to a deferred leg reverts with `SaleEnvelopeModeInvalid` (ADR 0011
   decision R6). Within the envelope, finalization executes under the
   then-current resolved primary policy with observed drift evented, so
   a resolver assignment change or freeze between purchase and
   finalization can never permanently block settlement. The signer's
   drift exposure is bounded by the envelope: at most the bound maximum
   price, at latest the finalize-by deadline.
4. Refund unlock: when the finalize-by deadline passes without the
   deferred settlement executing, or the settlement fails for a typed
   non-transient reason, a permissionless, idempotent unlock converts
   the escrowed funds into pull refund credits, evented with a reason
   hash. The non-transient reasons are pinned: phase ended, phase or
   counter supply exhausted, mint `policyHash` unmatchable beyond the
   `[MPA-GRACE]` bound, consent-bound mint blocked by a registry
   `DISPUTED`/`REVOKED` state, and a referenced module or adapter
   `INCIDENT_REVOKED`. Unlocked refunds are claimable forever from
   adapter escrow ([SSA-ADAPTER] rules 4 and 5); unlock states are
   terminal for the affected deferred leg.
5. Escrowed buyer funds therefore always have exactly one of three
   outcomes — refunded by the buyer, settled within the envelope, or
   unlocked for pull refund — and no mode, drift, or governance action
   can produce a fourth. This is the enforcement mechanism behind
   acceptance criterion 9, and the [SSA-GATES] suites test each mode's
   unlock branch.
6. By-construction envelopes for public purchases (ADR 0012 decision
   T6): a buyer-initiated public purchase or bid on an escrow-holding
   kind — the buyer is the caller and the payer, with no per-buyer
   authorization — requires no separate typed drift-envelope signature.
   The purchase transaction itself binds the rule 2 envelope: native
   `msg.value` (net of the [SSA-REVEAL] line item) or
   `PaymentIntent.maxAmount` binds the maximum price, calldata binds
   the sale reference, and the sale record's pinned finalization window
   — the adapter-published standing envelope, committed in
   `saleConfigHash` and surfaced to buyers before purchase — derives
   the finalize-by deadline. This mirrors the revenue spec's
   payer-is-caller by-construction consent
   ([`docs/revenue-splits-and-royalties.md`](revenue-splits-and-royalties.md)
   `[RSR-PAYMENT-INTENT]` rule 5) and keeps at-price escrow-mode
   checkout signature-free, exactly like a Dutch purchase. Signed
   envelopes — the `finalizeBy` fields of [SSA-AUTH] rule 8 and
   [SSA-OFFER] — remain mandatory exactly where a per-buyer
   authorization, offer, relayer, or executor-initiated flow
   participates; there the signature exists anyway and the envelope
   rides in it.

## Refund-Window Sales

Refund-window sales hold buyer funds in adapter escrow for a bounded
window; the sale becomes official — and the token mints — only at
finalization (ADR 0010 decision D5.4; drift envelope per ADR 0011
decision R6).

Requirements [SSA-REFUND]:

1. Purchase: the buyer deposits the full price — plus the reveal-fee
   line item of [SSA-REVEAL] rule 7 where one applies — into adapter
   escrow; the
   adapter records a purchase record with `purchaseId` (the
   `STREAM_SALE_PURCHASE_V1` preimage pinned in
   [Sale Identity And Records](#sale-identity-and-records)), quantity,
   amount, the escrowed fee component,
   `refundDeadline = purchaseTime + refundWindowSeconds`, and
   `finalizeBy = refundDeadline + finalizationWindowSeconds`. No mint
   occurs at purchase.
2. `refundWindowSeconds` is pinned per sale in `[3_600, 2_592_000]`
   (1 hour to 30 days) and `finalizationWindowSeconds` in
   `[86_400, 7_776_000]` (1 to 90 days); both are committed in
   `saleConfigHash`. Configuration must revert unless every possible
   purchase can finalize inside its bindings: when the phase `endTime` is
   nonzero, `saleEnd + refundWindowSeconds + finalizationWindowSeconds`
   must not exceed it, and the sale record must bind
   `ALLOW_CURRENT` for the finalization leg per [SSA-ENVELOPE] rule 3.
3. Refund: before `refundDeadline`, the buyer may claim a full refund of
   that purchase (pull, checks-effects-interactions); a refunded purchase
   is terminal and can never finalize.
4. Finalization: from `refundDeadline` through `finalizeBy`, finalization
   of an unrefunded purchase is permissionless and executes the official
   paid mint through a standard paid path, moving exactly the escrowed
   price to official settlement and reconciling the escrowed fee
   component to the coordinator escrow per [SSA-REVEAL] rule 7 (the
   fee never enters official settlement). Finalization is idempotent
   per purchase.
5. Refund unlock ([SSA-ENVELOPE] rule 4): if finalization fails for a
   pinned non-transient reason, or `finalizeBy` passes with the purchase
   neither refunded nor finalized, the purchase reverts to
   refundable-forever status — a permissionless, idempotent unlock emits
   `RefundWindowRefundUnlocked` with the reason hash, and the buyer's
   full deposit becomes a pull refund with no deadline. `RefundWindowClosed`
   refusals apply only between `refundDeadline` and `finalizeBy` while
   finalization remains possible; a time-barred refund with a dead
   forward path cannot exist by construction.
6. Funds in adapter escrow before finalization are never official revenue;
   after finalization no refund path exists. The sale record and buyer
   surfaces must state both boundaries and the unlock rule.

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
   frozen mint policy. A source set containing an `EXTERNAL_FACADE`
   collection reverts at configuration — Core's native burn entry is
   closed for facade-mode sources — per the [SSA-IDENTITY] rule 9
   identity-mode gate (ADR 0015 decision W3).
4. Claiming credit for tokens burned outside the executing transaction
   (pre-burned claims) is excluded from protocol v1: retained identity does
   not attribute the burner, so an attributable burn-claim registry
   requires its own accepted spec. External-collection (non-Stream) burn
   sources likewise require their own accepted adapter spec, which must
   satisfy the frozen recipe of [SSA-BURN-EXTERNAL] (ADR 0013 decision
   U6).
5. A burn-to-mint mint is a paid or free mint like any other: paid burn
   programs use the revenue spec's paid paths; free programs use the
   standard manager path. The burn changes eligibility, never settlement
   ordering.

### External-Collection Burn Recipe

External-collection burn-to-mint — burn a token from a non-Stream
contract (a Memes card, a legacy 6529 piece) to mint a Stream work — is
the most predictable day-one extension for this network, and external
burn observation is replay- and custody-tricky, so the safety recipe is
frozen now in the [SSA-HOLDER]/[SSA-RAFFLE] style instead of leaving a
future adapter author to reconstruct intent (ADR 0013 decision U6). No
genesis implementation ships; Protocol v1 Exclusions item 7 stands
until an adapter spec meeting this recipe is accepted. Until then, an
external-burn-style program runs only as an operator-attested ticket
phase — the ticket signer, not the chain, attests the burn — and that
posture is the disclosed launch configuration (ADR 0014 decision V5):
sale records and buyer surfaces must disclose the signer trust exactly
as rule 3 discloses the `ATTESTED_TICKET` class ([SSA-GATES] item 21).

```solidity
bytes32 externalBurnNullifier = keccak256(abi.encode(
    STREAM_EXTERNAL_BURN_NULLIFIER_V1,
    uint256(block.chainid),
    address(sourceContract),
    uint256(sourceTokenId)
));
```

Requirements [SSA-BURN-EXTERNAL]:

1. Replay protection: for every claimed external source token, the gate
   returns the `externalBurnNullifier` above in `GateResult.nullifiers`,
   consumed manager-scoped through the mint ledger exactly like
   `STREAM_BURN_NULLIFIER_V1`. `STREAM_EXTERNAL_BURN_NULLIFIER_V1` is
   the accepted nullifier domain such a gate spec declares under the
   mint spec's nullifier-domain rule (mint spec Protocol v1 Scope,
   exclusion 3). The domain binds the source contract address and the
   execution chain id: external sources must live on the deployment
   chain — cross-chain burn sources remain excluded (Protocol v1
   Exclusions item 8) — and one nullifier space can never alias across
   source contracts.
2. Proof shapes: exactly two are acceptable, declared per source
   contract. (a) Same-transaction custody burn — the trust-minimized
   shape: the burn executor verifies the caller is the source token's
   owner or approved operator, executes the source contract's own
   `burn` where one exists or otherwise
   `transferFrom(owner, BURN_ADDRESS, sourceTokenId)` with
   `BURN_ADDRESS = 0x000000000000000000000000000000000000dEaD`, and the
   gate re-verifies post-state before the manager mint call: `ownerOf`
   reverts or reports `BURN_ADDRESS`, read as a bounded `staticcall`
   under a Governed Gas Parameter the adapter spec names, with
   returndata capped to the read's exact ABI shape, failing closed.
   (b) Attested burn — for sources whose burn cannot be executed or
   observed in-transaction: a signed `MintTicket` (mint spec
   `[MPA-TICKET]`) attesting the historical burn, with the ticket
   signer's trust explicitly carried by the declaration below. Pre-burn
   credit under shape (a) stays excluded exactly as [SSA-BURN] rule 4
   excludes it for Stream sources.
3. Per-collection trust declaration: the gate config hash (and
   therefore the phase `policyHash`) pins, per source contract, the
   source address, the proof shape, and the trust class —
   `TRUSTLESS_SAME_TX` (trusts only the source contract's ERC-721
   conformance: honest `ownerOf` and transfer semantics) or
   `ATTESTED_TICKET` (additionally trusts the named ticket signer) —
   and sale-record buyer surfaces must disclose the declared class.
   External contracts are arbitrary third-party code: the declaration
   makes that trust a recorded fact, never an implicit assumption.
4. Source-set, ratio, and window pinning follow [SSA-BURN] rule 3
   unchanged; the mint settles per [SSA-BURN] rule 5. A dead-address
   transfer leaves the source token existent but unreachable, so the
   nullifier — not token nonexistence — is the replay stop, and the
   gate must never accept a source token whose owner is already
   `BURN_ADDRESS`.

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
4. Redemption without burning — claim the print or sculpture once
   while keeping the token — is a declared composition, not a gap
   (ADR 0014 decision V5). Exactly-once claim protection is the
   [SSA-HOLDER] shape with `entitlementId` identifying the redemption
   program: the holder-entitlement nullifier already gives
   exactly-once per token, and the future hold-to-claim gate spec
   explicitly covers keep-the-token physical claims. The durable
   claim record is the owner-records redemption-claim family owned by
   [`docs/collection-metadata-contract.md`](collection-metadata-contract.md)
   [CMC-OWNER-RECORDS] — an append-only record in the token's object
   dossier with no transfer semantics: recording a redemption never
   restricts, locks, or simulates restrictions on the token (the
   Mementos rule 3 posture). Until an accepted hold-to-claim gate
   spec exists, the disclosed launch posture is signed tickets plus
   the owner-record claim entry ([SSA-HOLDER] rule 3; [SSA-GATES]
   item 21).

### Mementos And Attendance Artifacts

Soulbound and lockable tokens are successor-line-only (protocol v1
exclusions,
[`docs/launch-v1-target-architecture.md`](launch-v1-target-architecture.md)),
so exhibition mementos, attendance proofs, and wallet-bound artist proofs
are served by an attestation-based pattern inside the existing satellites
rather than by transfer-restricted tokens (ADR 0011 decision R9). This is
a documented Operational-layer pattern, not a new contract surface:

1. Exhibition and attendance mementos are recorded as append-only
   attestation records — `StreamCollectionAttestations` entries or
   owner-record `EXHIBITION` family records — keyed by the pinned
   `STREAM_SUBJECT_TOKEN_V1` subject identity
   ([`docs/collection-metadata-contract.md`](collection-metadata-contract.md)).
   The attestation, not token custody, is the durable proof of presence
   or participation, and it inherits the event-catalog, export, and
   preservation guarantees of its satellite.
2. A memento program that also wants a collectible object mints an
   ordinary transferable token through a normal sale kind (typically
   `ZERO_PRICE_CLAIM` gated by a snapshot allowlist or, as an extension,
   the [SSA-HOLDER] recipe); transferability is a feature, and
   wallet-boundness, where wanted, lives in the attestation layer.
3. No memento pattern may abuse `BURN_TO_REDEEM` fulfillment records or
   any other surface to simulate transfer restrictions on this Core line.

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

These profiles pin interfaces and safety invariants only, never auction
economics (ADR 0011 decision R9): pricing rules, tie-breaking, and unit
counts are per-implementation choices each future accepted spec pins in
its own sale records, so Vickrey, pay-as-bid, and uniform-price mechanics
all remain reachable behind the frozen interfaces.

Requirements [SSA-SEALED]:

1. Sealed-bid commitments must be
   `keccak256(abi.encode(STREAM_SEALED_BID_V1, block.chainid,
   auctionContract, auctionId, bidder, amount, salt))`; reveals recompute
   and match.
2. Deposit bonding is uniform (ADR 0011 decision R9): the auction record
   pins one `depositAmount`, every `commitBid` must send exactly it, and
   the deposit therefore reveals nothing about the sealed amount beyond
   eligibility. Deposit-equals-bid and deposit-above-bid schemes leak bid
   ceilings and are nonconformant. `depositAmount` itself is a
   per-auction declared parameter — sized by the implementing spec's
   pinned sizing rule, normally against the reserve or expected
   clearing value — never a protocol-frozen constant, so deterrence
   sizing stays governable per sale while uniformity, the leakage
   protection, stays Permanent (ADR 0014 decision V5).
3. Reveal completes funding: a valid reveal supplies the difference
   between the committed `amount` and `depositAmount` into adapter escrow
   in the reveal transaction, so every revealed bid is fully escrowed.
   Losing revealed bids become pull refunds in full at settlement; a
   winner's overage above the settlement price becomes a pull refund at
   settlement.
4. Abort slashing (ADR 0011 decision R9): commit and reveal windows are
   pinned in the auction record, and a commitment that is never validly
   revealed forfeits its deposit — selective abstention after observing
   others' reveals is never free. The forfeiture policy (full deposit is
   the default; any lesser pinned fraction is an explicit auction-record
   declaration) is committed at creation, every forfeiture emits
   `SealedBidDepositForfeited`, and forfeited deposits flow to official
   settlement as supplemental revenue under the auction's `saleId` —
   never to operator discretion. The abstention-versus-leakage
   tradeoff is inherent and must be a declared, sized choice (ADR 0014
   decision V5): bid-proportional bonding leaks bid ceilings (rule 2),
   while a uniform deposit bounds the deterrent at exactly
   `depositAmount` — under pay-as-bid pricing, a bidder who observes
   rivals' reveals and would win far above the runner-up rationally
   abstains whenever the expected overpayment exceeds the forfeited
   deposit. An implementing spec must therefore either adopt
   second-price or uniform-clearing pricing (removing the abstention
   motive) or pin a `depositAmount` sizing rule against that calculus
   in its sale records, and must state which it chose alongside its
   rule 5 pricing declaration.
5. Settlement economics are not pinned here: the pricing rule (uniform
   clearing, pay-as-bid, second-price), the winner count `K`, and the
   tie-breaking rule are pinned by each implementation's accepted spec in
   its sale record and `saleConfigHash`. Two safety constraints are
   Permanent: tie-breaking must be deterministic from onchain order, and
   no winner may ever be charged above their revealed committed amount.
   `winningBids().clearingPrice` reports the implementation's marginal
   settlement price as its spec defines.
6. Settlement follows the [SSA-ENGLISH] custody, CEI, idempotence, and
   pull-refund rules, and official revenue flows through the same
   settlement boundaries. ERC-20 deposits have no genesis implementation
   and follow the [SSA-ERC20-BID] profile when added.

## ERC-20 Bidding Extension Profile

Live-auction ERC-20 bidding (WETH and stablecoin treasuries, custody
setups that cannot push native ETH) is excluded from genesis
implementations, but its interface and escrowed-funds invariants are
frozen now so a reviewed adapter can add it without new interface design
(ADR 0011 decision R9).

```solidity
interface IStreamERC20AuctionBidding {
    function bidAsset(bytes32 auctionId) external view returns (address);

    function placeBidERC20(bytes32 auctionId, uint256 amount) external;

    function refundableAssetBalance(
        bytes32 auctionId,
        address bidder
    ) external view returns (address asset, uint256 amount);
}
```

Requirements [SSA-ERC20-BID]:

1. Eligible assets follow the revenue spec's approved-asset policy and
   exclusions (no fee-on-transfer, rebasing, or non-standard assets); the
   auction record binds exactly one bid asset.
2. Full escrow at bid: `placeBidERC20` must move the entire bid amount
   into adapter escrow in the bid transaction, verified by the adapter's
   own balance delta. Allowance-backed unfunded bids are nonconformant —
   a standing allowance is never a bid (ADR 0010 decision D8.2 posture).
3. Every escrow pull requires a payer-signed `PaymentIntent` verified at
   the adapter boundary per `[RSR-PAYMENT-INTENT]`, with `maxAmount`
   bounding cumulative pulls for the auction and `saleRef` equal to the
   `saleId` ([SSA-IDENTITY] rule 7).
4. Outbid, losing, cancellation, and no-settlement funds become pull
   refund credits in the bid asset, claimable forever through the
   [SSA-ADAPTER] rule 4 claim surfaces; the adapter never pushes tokens
   in bid or settlement paths.
5. Settlement moves exactly the winning escrowed amount through the
   revenue spec's ERC-20 settlement boundary; all [SSA-ENGLISH] custody,
   CEI, idempotence, anti-snipe, and increment rules apply unchanged, and
   the drift envelope of [SSA-ENVELOPE] applies to any deferred leg.

## Raffle And Random-Allocation Extension Recipe

Raffles, random winner selection, and random assignment stay excluded
from genesis implementations (Protocol v1 Exclusions item 11), but
fair allocation for oversubscribed drops is the industry-standard
mechanic this platform will eventually want, so the safety recipe is
frozen now — the same pre-freezing the sealed-bid profile received —
instead of leaving a future adapter author to reconstruct intent
(ADR 0012 decision T6).

```solidity
bytes32 raffleDraw = keccak256(abi.encode(
    STREAM_RAFFLE_DRAW_V1,
    uint256(block.chainid),
    address(saleAdapter),
    bytes32(saleId),
    bytes32(scopeSeed),   // finalized scope entropy ([EC-SCOPE])
    bytes32(entryRoot),
    uint256(drawIndex)
));
```

Requirements [SSA-RAFFLE]:

1. Randomness source: a raffle or random-allocation adapter must
   consume the entropy coordinator's sale/collection-scoped request
   kind — the anti-reroll lifecycle, request identity, and seed
   finality are owned by
   [`docs/stream-entropy-coordinator.md`](stream-entropy-coordinator.md)
   `[EC-SCOPE]` — and must never integrate an external randomness
   provider directly ([SSA-REVEAL] rule 5).
2. Entry-set closure before randomness: entries close, and the sorted
   entry set's Merkle root (`entryRoot`, sorted-pair keccak over
   double-hashed entry leaves the adapter spec pins) is committed
   onchain, before the scope entropy request is made; the request's
   `scopeInputsHash` must bind `entryRoot`, so the seed provably
   postdates the closed entry set and no entry can be added, dropped,
   or reordered once a draw is requestable. `[EC-SCOPE]`'s
   inputs-commitment immutability is the enforcement home.
3. Entry deposits: escrowed entry funds follow [SSA-ADAPTER] rules 4,
   5, 14, and 15 and the [SSA-ENVELOPE] drift envelope. Losing entries
   become pull refunds in full at allocation — entry deposits are never
   forfeited — winning entries settle through a standard paid path, and
   an allocation that has not executed by the sale's finalize-by
   deadline unlocks every deposit ([SSA-ENVELOPE] rule 4).
4. Deterministic allocation: winners and assignments derive
   deterministically and publicly recomputably from
   `(scopeSeed, entryRoot)` alone. The canonical ranking is owned by
   the coordinator recipe — entries rank by the
   `STREAM_ENTROPY_SCOPE_RANKING_V1` rank key of their committed
   0-based entry index, applied verbatim
   ([`docs/stream-entropy-coordinator.md`](stream-entropy-coordinator.md)
   `[EC-SCOPE-RAFFLE]` rule 3) — and the `STREAM_RAFFLE_DRAW_V1` value
   above is the sale-side per-draw binding commitment (sale record,
   entry root, draw index) recorded with each executed draw, never an
   alternative ranking. The adapter spec pins the entry-leaf schema and
   the entry ordering behind `entryRoot`, and two implementations of
   one sale record must compute identical winners. No operator input,
   gas shaping, or caller ordering may influence the outcome after the
   seed finalizes.
5. One draw per sale: the scope seed is requested once per `saleId`,
   recovery re-requests reuse the stored `scopeInputsHash`
   (coordinator home), and no reroll or re-draw surface exists.
6. No genesis implementation ships. This recipe plus `[EC-SCOPE]` is
   the conformance bar a future accepted raffle adapter spec must
   meet; Protocol v1 Exclusions item 11 stands until one is accepted,
   and its adapter bytecode tests ship with that spec, while the
   worked example below is executable-verified at genesis through the
   [SSA-GATES] item 20 recipe-vector suite (ADR 0014 decision V5).
   Until a raffle adapter spec is accepted, the sanctioned launch-era
   substitutes for oversubscribed demand are Dutch clearing (which
   price-discovers demand at a uniform price) and allowlist tiers
   (which ration demand by declared allocation); a drop using neither
   resolves demand by gas-priority first-come-first-served, and
   operator surfaces must present that as the drop's declared
   allocation mechanic ([SSA-GATES] item 21).

Worked example (normative fixture, ADR 0014 decision V5). An edition
of 3 raffled among 8 escrowed entries runs exactly this way:

1. Entries 0 through 7 are recorded with escrowed deposits; the entry
   window closes; the adapter commits `entryRoot` over the 8 sorted,
   double-hashed entry leaves and registers the `SALE`-kind scope
   whose `scopeInputsHash` binds `entryRoot` ([EC-SCOPE-RAFFLE]
   rules 1 and 2), so the seed provably postdates the closed entry
   set.
2. The coordinator finalizes `scopeSeed`. For each committed 0-based
   entry index, the rank key derives under
   `STREAM_ENTROPY_SCOPE_RANKING_V1` exactly as [EC-SCOPE-RAFFLE]
   rule 3 pins, and the 3 lowest-ranked entries win — no operator
   input, gas shaping, or caller ordering can change the set (rule 4).
3. The adapter records the executed draw with the
   `STREAM_RAFFLE_DRAW_V1` commitment above (`drawIndex = 0`), settles
   the 3 winners at the entry price through a standard paid path, and
   converts the 5 losing deposits into pull refunds in full (rule 3).
   A draw that has not executed by the sale's finalize-by deadline
   unlocks all 8 deposits ([SSA-ENVELOPE] rule 4).

Every outcome above is recomputable offchain from
`(scopeSeed, entryRoot)` alone, which is what makes the fixture a
genesis-testable vector set: the [SSA-GATES] item 20 suite replays it
against the coordinator's fair-allocation golden vectors
([EC-SCOPE-RAFFLE]) with no adapter bytecode required.

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
   parent-gas precheck and returndata copied only to the read's exact
   ABI shape — the delegate registry is third-party code, and
   returndata longer or shorter than the declared return tuple is a
   failed read (ADR 0013 decision U7); an unavailable registry fails
   closed (the gated mint reverts).
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
6. Delegated sale participation (ADR 0013 decision U6): the
   delegate-registry authority class extends beyond mint eligibility to
   bidding, offers, and claims. A genesis adapter implementing a
   surface below pins its delegate registry exactly as rule 1 pins the
   gate's — one registry by address and codehash in the adapter's
   module-registry record — and performs the rule 2 live acceptance
   checks as bounded reads under the rule 3 discipline
   (`DELEGATE_REGISTRY_GAS_LIMIT`, exact-shape returndata, fail
   closed). Vault-security-conscious collectors therefore participate
   in every genesis mechanic from a hot wallet without bringing the
   vault key online.
7. Bid-for-vault: English auction bid placement accepts the optional
   `deliverTo` binding of [SSA-ENGLISH] rule 15. When `deliverTo`
   differs from the bidder, the adapter verifies at binding time — the
   bidder's first bid — that the bidder is a live delegate of
   `deliverTo` under the rule 2 scopes, failing closed
   (`DelegationNotFound`). The binding is bid-time-verified authority,
   exactly like the rule 4 signer-verified tickets: NFT delivery binds
   the vault, funds and refunds stay with the bidding wallet, and a
   later delegation revocation never unbinds a placed bid.
8. Delegate-signed offers: a `SaleOffer` signature is acceptable from a
   live delegate of `offer.buyer` ([SSA-OFFER] rule 1). Delegation
   confers signing authority only: the offer's economics bind `buyer`,
   and payment always follows the normal payer bindings — a delegate
   can never spend the vault's funds through this path.
9. Delegate-triggered claims: `claimRefundFor` ([SSA-ADAPTER] rule 13)
   and every pull-NFT-claim completion surface accept a caller that is
   a live delegate of the credited or claimant account, verified per
   rules 2 and 3 at claim time, delivering only to the credited
   account itself. A delegate can trigger a claim, never redirect it;
   the credited account's own claim call keeps its caller-chosen `to`.

## Hold-To-Claim Entitlements

Companion and derivative claims where each held source token entitles one
new mint — without burning the source — are a staple cross-collection
pattern. This section pins the sanctioned shape so future gate authors do
not reverse-engineer it (ADR 0011 decision R9).

```solidity
bytes32 holderEntitlementNullifier = keccak256(abi.encode(
    STREAM_HOLDER_ENTITLEMENT_V1,
    uint256(block.chainid),
    address(sourceCore),
    bytes32(entitlementId),
    uint256(sourceTokenId)
));
```

Requirements [SSA-HOLDER]:

1. The trustless shape is a hold-to-claim extension gate: an
   `IStreamMintGate` that verifies live source-token ownership at
   `validateMint` time (for Stream sources, `ownerOf` plus
   `tokenCollectionIdentity`; never a cached snapshot) and returns the
   `holderEntitlementNullifier` above in `GateResult.nullifiers` for each
   claimed source token. The manager consumes the nullifier through the
   mint ledger under the normal manager-scoped rules, so each
   `(entitlementId, source token)` pair claims exactly once
   ("manager-scoped nullifier keyed by entitlement and held token",
   ADR 0011 decision R9).
2. `entitlementId` is a program-chosen `bytes32` identifying the claim
   program, pinned in the gate config hash (and therefore the phase
   `policyHash`), so one source token can serve future distinct programs
   without nullifier collisions. `STREAM_HOLDER_ENTITLEMENT_V1` is the
   accepted nullifier domain a hold-to-claim gate spec declares under the
   mint spec's nullifier-domain rule (mint spec Protocol v1 Scope,
   exclusion 3).
3. No hold-to-claim gate ships at genesis: the shape above requires its
   own accepted gate module spec against the frozen `IStreamMintGate`
   interface. The genesis-available fallbacks are the snapshot Merkle
   allowlist (`MERKLE_STATIC` over a holder snapshot) and signed mint
   tickets — both fully specified today; the fallbacks trust the snapshot
   or signer where the gate verifies live ownership. That trust
   difference is the disclosed launch posture, never a footnote
   (ADR 0014 decision V5): sale records and buyer/artist surfaces for
   a fallback-served holder program must disclose the snapshot block
   and allowlist content hash, or the ticket signer identity
   ([SSA-GATES] item 21), and the same posture governs every
   network-eligibility fallback ([SSA-NETWORK-ELIGIBILITY] rule 5).
4. A phase that instead wants per-source-token accounting without a
   nullifier may configure a `CONTEXT`-keyed, `PER_BATCH`, cap-1 counter
   whose `contextHash` derives from the source token, but the nullifier
   recipe of rule 1 is the sanctioned default because it composes with
   other counters without occupying the batch context slot.

## Network Eligibility Gate Extension Profile

The 6529 network's native drop grammar — TDH thresholds, profile
classes, consolidated-identity allowances — is eligibility computed
from network state, and at genesis it is served only by trust-based
fallbacks (snapshot allowlists and signed tickets). This section
freezes the gate-interface profile a future accepted TDH-class gate
spec must meet, so the network's most distinctive patterns have a
declared trust-minimizing replacement path instead of an undesigned
one (ADR 0014 decision V5).

```solidity
interface IStreamNetworkEligibilityGate /* also implements IStreamMintGate */ {
    function eligibilitySource() external view returns (address);

    function eligibilityClass() external view returns (bytes32);

    function subjectEligibility(address subject, uint256 collectionId)
        external
        view
        returns (bool eligible, uint64 maxQuantity);
}
```

Requirements [SSA-NETWORK-ELIGIBILITY]:

1. Pinned source: the gate pins exactly one eligibility source — a TDH
   accounting contract, profile registry, or consolidation registry —
   by address and codehash in its module-registry record, and every
   eligibility parameter (thresholds, weights, snapshot references)
   binds into the gate config hash and therefore the phase
   `policyHash`, so eligibility policy is frozen mint policy exactly
   as a burn program is ([SSA-BURN] rule 3).
2. Declared trust class, per source (the [SSA-BURN-EXTERNAL] rule 3
   posture): `LIVE_ONCHAIN` — eligibility reads live onchain state and
   trusts only the pinned source contract's read semantics — or
   `ATTESTED_ORACLE` — the source republishes offchain-computed
   network state (TDH is computed offchain), additionally trusting the
   named writer set that posts it. The class is pinned in the gate
   config hash and disclosed on sale-record buyer surfaces.
3. Read discipline: eligibility reads are live at `validateMint` time
   — never cached across transactions — as bounded `staticcall`s under
   a Governed Gas Parameter the gate spec names, with the 63/64
   parent-gas precheck and returndata copied only to the read's exact
   ABI shape, failing closed ([SSA-DELEGATE] rules 2 and 3 applied to
   the eligibility source).
4. Eligibility, never accounting identity: the gate validates
   eligibility and may bound quantity (`GateResult.maxQuantity`);
   durable allowance still consumes through configured counters under
   the mint spec's genesis key modes. Counting a consolidated identity
   as one subject across wallets is the excluded delegation/profile
   counter-resolver extension
   ([`docs/mint-policy-and-accounting.md`](mint-policy-and-accounting.md)
   Protocol v1 Scope, exclusion 6), and a gate must never emulate it
   through a side channel.
5. Disclosed launch posture: no gate implementation ships at genesis.
   The genesis fallbacks are the snapshot Merkle allowlist
   (`MERKLE_STATIC` over a network-state snapshot) and signed mint
   tickets ([SSA-HOLDER] rule 3), which trust the snapshot generator
   or ticket signer where this profile verifies at mint time. Sale
   records and buyer/artist surfaces for network-gated phases served
   by a fallback must disclose the snapshot block and content hash, or
   the ticket signer identity, so the trust difference stays a
   recorded fact until an accepted gate spec replaces it ([SSA-GATES]
   item 21).
6. This profile plus the mint spec's gate and registry rules
   (`[MPA-GATES]`, `[MPA-REGISTRY]`) is the conformance bar a future
   accepted network-eligibility gate spec must meet; Protocol v1
   Exclusions item 18 stands until one is accepted, and its tests ship
   with that spec.

## Pick-Your-Piece Content Selection

Curated drops where the collector chooses a specific unminted work are
supported without reservations or serial choice (ADR 0010 decision D5.7).
The genesis carrier is named (ADR 0013 decision U6):
`StreamFixedPriceSaleAdapter` implements this section in full — both
selection modes, the commit-deposit escrow, the reveal windows, and the
manifest verification — so the genesis-gated capability has a
deployable owner the audit plan can scope. `StreamPrivateSaleAdapter`
additionally verifies a bound `contentSelectionHash` for
allowlist-of-one sales and offers ([SSA-PRIVATE] rule 1, [SSA-OFFER]
rule 1); with one bound buyer there is no selection race, so the
commit-reveal machinery lives only on the fixed-price carrier.

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

// commit-reveal selection commitment (COMMIT_REVEAL mode):
bytes32 selectionCommitment = keccak256(abi.encode(
    STREAM_CONTENT_COMMIT_V1,
    uint256(block.chainid),
    address(saleAdapter),
    bytes32(saleId),
    address(buyer),
    bytes32(contentLeaf),
    bytes32(salt)
));
```

Requirements [SSA-CONTENT]:

1. The full content manifest — every `(contentId, tokenDataHash)` pair,
   with preview references — is published before the sale opens, and its
   Merkle root (`contentManifestRoot`, sorted-pair keccak over the
   double-hashed leaves above) is pinned in the sale record and in the
   phase's gate config hash.
2. A selection execution names one `contentId` with a Merkle proof; the
   adapter must verify the proof and bind the exact `tokenData` whose
   per-token hash equals the leaf's `tokenDataHash` into the mint
   commitment, so the minted work is provably the selected one.
   `contentSelectionHash = contentLeaf` in the sale authorization.
3. Double-sale prevention: the phase must configure a `CONTEXT`-keyed,
   `PER_BATCH`, cap-1 counter whose `contextHash` is
   `contentContextHash`, so each content ID is sellable exactly once, and
   concurrent buyers race safely at the ledger.
4. Serials stay sequential: content selection binds artwork content, never
   the token ID or collection serial. Serial-number and token-ID
   selection are excluded on this Core line: v1 Core has no durable
   reservation state, and the mint spec pins durable reservations as
   successor-line-only
   ([`docs/mint-policy-and-accounting.md`](mint-policy-and-accounting.md)
   Core Contract Changes; sequential allocation per ADR 0009 decision 1;
   ADR 0011 decision R9). That mint-spec statement is the single home for
   the reservation posture. Its collector-facing consequence — serial
   assignment is strictly mint-order, never buyer-selected, for every
   drop this platform ever runs — silently shapes series design
   forever, so it gets the same disclosure treatment as the editions
   posture and the royalty acknowledgment (ADR 0014 decision V5):
   artist onboarding and drop-design surfaces must disclose it
   alongside [SSA-EDITIONS] and the revenue spec's
   [RSR-MARKETPLACE-ROYALTY] acknowledgment, so series designers learn
   it at onboarding, never at drop design ([SSA-GATES] item 21).
5. Unsold content simply expires with the sale; manifest publication does
   not obligate minting.
6. Selection mode is a pinned sale-record field (ADR 0011 decision R9):
   `COMMIT_REVEAL` is the default and the required mode for
   differentiated content — any manifest whose pieces are not
   substantially interchangeable at the sale price. `PUBLIC` (naked
   mempool selection) is valid only as an explicit sale-record
   declaration, and public selection is structurally front-runnable: a
   pending selection exposes its `contentId` and proof, and a searcher or
   rival can take the piece first at the same price. Sale records and
   buyer surfaces for `PUBLIC` mode must disclose this exposure (same
   disclose-or-mitigate posture as the entropy spec's instant-provider
   timing disclosure).
7. `COMMIT_REVEAL` mechanics: the buyer first commits
   `selectionCommitment` (preimage above; the domained hash binds buyer,
   sale, and the selected leaf) while depositing the full purchase price
   into adapter escrow, evented `ContentSelectionCommitted`. The reveal —
   supplying `(contentId, proof, salt)` — is valid only in a strictly
   later block than its commit, only from the committing buyer, and only
   inside the sale record's pinned commit and reveal windows. A valid
   reveal executes the purchase per rules 2 and 3 in the reveal
   transaction; the ledger's cap-1 context counter resolves races, and
   observing a pending reveal is useless to an attacker because a fresh
   commit cannot reveal in the same block.
8. Commit escrow follows [SSA-ADAPTER] rules 4 and 5: a commit that loses
   its content race or is never revealed becomes a pull refund in full
   once the reveal window closes; commit deposits are never forfeited and
   never touch official settlement.

### Content Selection On Time-Varying Kinds

Curated choice at a descending price — Dutch-with-selection — is a
declared extension profile, not an undesigned composition (ADR 0014
decision V5): both halves exist at genesis and the frozen domains
already compose, so a future accepted adapter spec adds a `SaleKind`
value and pins the invariants below, never new cryptographic surface.

Requirements [SSA-CONTENT-TIME]:

1. Reuse, not redesign: `STREAM_CONTENT_LEAF_V1`,
   `STREAM_CONTENT_CONTEXT_V1`, and `STREAM_CONTENT_COMMIT_V1` bind
   `saleId` generically and are reused unchanged; the new kind appends
   through the [SSA-IDENTITY] rule 6 catalog, and [SSA-CONTENT]
   rules 1 through 8 apply unchanged except where a rule below
   refines them.
2. Execution-time pricing: the charged unit price is the schedule
   price of the executing transaction under the [SSA-DUTCH] rule 3
   maximum-price binding. A commit binds the selected content and the
   buyer's maximum (the commit deposit), never a price: the reveal
   executes the purchase at the reveal-time schedule price and the
   deposit excess pull-credits per [SSA-DUTCH] rule 3.
   Price-at-commit charging is nonconformant — it would turn commits
   into free price options against the committed schedule and make
   settlement diverge from the deterministic rule 2 price.
3. Windows bound the timing option: on a decaying schedule a
   commit-holder gains by revealing late, so the accepted spec must
   pin its commit and reveal windows against the schedule's decay —
   reveal windows end at or before the schedule `endTime`, and the
   window-versus-decay interaction is stated in the sale record — with
   the [SSA-CONTENT] rule 7 strictly-later-block reveal rule
   unchanged.
4. Selection-mode discipline is unchanged and sharper: [SSA-CONTENT]
   rule 6 applies verbatim, and a descending price strengthens the
   front-running incentive, so a `PUBLIC`-mode declaration on a
   time-varying kind carries the same disclosure duty with the price
   drift noted on the same surface.
5. Clearing interaction: composed with `DUTCH_AUCTION_CLEARING`
   semantics, selection changes nothing in [SSA-DUTCH-CLEARING]
   rules 3 and 4 — clearing fixes from schedule prices at execution,
   the [SSA-CONTENT] rule 3 cap-1 content counter resolves piece
   races, and per-purchase rebates and `priceOverride` ceilings
   interact per [SSA-AUTH] rule 3.
6. Auction-for-choice needs no new profile for 1/1s: a curated
   pick-from-manifest auction already exists at genesis through the
   [SSA-ENGLISH] rule 8 leaf-form artwork commitment; multi-lot choice
   auctions are Protocol v1 Exclusions items 15 and 16 territory.
7. No genesis implementation ships; Protocol v1 Exclusions item 19
   stands until an adapter spec meeting this profile is accepted, and
   its tests ship with that spec.

### Cross-Sale Content Uniqueness

The [SSA-CONTENT] rule 3 counter derives its context over `saleId`, so
its double-sale protection is per-sale by design (re-drops of unsold
work depend on that). Collection-lifetime uniqueness of a curated work
across sales is a separate property with an optional onchain
enforcement recipe and a mandatory operational check (ADR 0012
decision T6).

```solidity
bytes32 contentConsumedNullifier = keccak256(abi.encode(
    STREAM_CONTENT_CONSUMED_V1,
    uint256(block.chainid),
    address(core),
    uint256(collectionId),
    bytes32(contentId)
));
```

Requirements [SSA-CONTENT-UNIQUE]:

1. The optional enforcement shape is a per-collection
   content-consumption registry gate: an `IStreamMintGate` that returns
   the nullifier above for each `contentId` a batch mints, consumed
   manager-scoped through the mint ledger exactly like the burn and
   hold-to-claim domains, so each `(collection, contentId)` mints at
   most once across every sale, phase, and adapter under that manager.
   `STREAM_CONTENT_CONSUMED_V1` is the accepted nullifier domain such a
   gate spec declares under the mint spec's nullifier-domain rule (mint
   spec Protocol v1 Scope, exclusion 3). No genesis implementation
   ships; the gate requires its own accepted module spec, the
   [SSA-HOLDER] posture.
2. `contentId` assignment must be stable per work: operators assign
   each distinct work one durable `contentId` across every manifest and
   sale of a collection, or the registry protects nothing. An
   intentional re-edition of the same artwork bytes is a declared
   choice carried by a distinct `contentId` under the collection's
   edition declaration ([SSA-EDITIONS]) — never an accident of manifest
   reuse.
3. Operational check regardless of gate use: before a sale opens on a
   collection with prior content sales, rehearsal tooling must verify
   that the new manifest's `(contentId, tokenDataHash)` pairs intersect
   previously sold content only where a declared re-edition says so,
   and the check result is rehearsal/release evidence. Manifest hygiene
   is the genesis posture; this rule makes it a checked property
   instead of an assumption, and the artist consent chain benefits the
   same way (the artist gains a tool proving non-overlap).

## Reveal Fees And Post-Mint Entropy

A collector who mints from an `ASYNC`-entropy collection must never stare
at unowned pending metadata: reveal operations are owned, funded, and
deadline-bound (ADR 0011 decision R8). The coordinator owns the reveal
policy, the reveal-fee escrow, the SLO, and the permissionless fallback
([`docs/stream-entropy-coordinator.md`](stream-entropy-coordinator.md)
[Reveal Ownership And Funding](stream-entropy-coordinator.md#reveal-ownership-and-funding));
this section owns the adapter-side obligations that coordinator spec
delegates here.

Requirements [SSA-REVEAL]:

1. Attempt-and-catch at mint (`AT_MINT` mode): for a collection whose
   declared reveal policy is `AT_MINT`, the sale adapter must attempt
   `requestEntropy(tokenId)` for each minted token in the purchase
   transaction, after the manager mint call returns. The attempt is
   failure-isolated with a named bound (ADR 0013 decision U7): the
   adapter forwards at most the `REVEAL_ATTEMPT_GAS_LIMIT` Governed
   Gas Parameter ([SSA-GAS]) with the 63/64 parent-gas precheck and
   try/catch isolation, because the call chain — adapter to
   coordinator to provider adapter to upstream source — reaches
   third-party provider code inside the collector's purchase
   transaction ([EC-REVEAL] rule 2 guarantees the coordinator side:
   the measured `requestEntropy` envelope is published per genesis
   provider so the bound is sized with stated margin). A failed,
   underfunded, or out-of-stipend request must not revert the
   purchase — the token stays
   `REGISTERED`, enters the SLO window, and the reveal owner or the
   permissionless fallback completes the request. Mint success never
   depends on provider uptime.
2. Priced reveal-fee line item, drift-safe (ADR 0013 decision U6):
   when the collection's declared
   `revealFeePerTokenWei` is nonzero, every priced purchase and claim
   that mints in its entry transaction charges the live declared value
   — `revealFeePerTokenWei * quantity`, read from the coordinator's
   reveal policy in the purchase transaction, because the fee is
   Operational and updatable after the policy freeze ([EC-REVEAL]
   rule 9; ADR 0012 decision T7) — in addition to the sale price,
   itemized in the sale record and buyer surfaces. The mutable fee
   never sits inside an exact-match `msg.value` equation: the buyer's
   supplied value above the charged sale price is the reveal-fee
   allowance — their binding maximum for the line item, mirroring
   [SSA-DUTCH] rule 3 and [EC-FEEBIND] — and the purchase reverts with
   `SaleRevealFeeBelowRequired` only if the allowance is below the
   live fee, charges exactly the live fee, and credits the unspent
   allowance to the payer as a pull refund from adapter escrow in the
   same transaction, emitting `SalePaymentExcessCredited`. A fee
   retune landing between a buyer's offchain quote and inclusion
   therefore never reverts a purchase whose payment still covers the
   live value, and EOAs quote with margin instead of computing a live
   storage value in-transaction ([SSA-FIXED] rule 2, [SSA-ZERO]
   rule 2, [SSA-PWYW] rule 2). Maximum-price kinds charge the live fee
   and bind the remainder as the price maximum ([SSA-DUTCH] rule 3);
   ERC-20 purchases bound the fee inside `PaymentIntent.maxAmount`
   under the revenue spec's exact-delta rule. Deferred-mint kinds
   escrow and reconcile the line item per rule 7.
3. The reveal fee is never official revenue: the adapter must forward
   the collected line item to the coordinator's per-collection
   reveal-fee escrow (`fundRevealFeeEscrow`) in the transaction in
   which the token mints — the entry transaction itself for
   mint-at-purchase kinds; the finalization or settlement transaction
   for the deferred kinds of rule 7 — exclude it from every
   official-revenue counter and settlement record, and never hold it
   beyond that transaction. Before the deferred mint, a collected fee
   is refundable-class adapter escrow under [SSA-ADAPTER] rules 4, 5,
   and 14, never official revenue. The coordinator's escrow event is
   the single funding fact; adapters emit no mirror.
4. Sale configuration for an `ASYNC` collection must revert unless the
   collection's reveal policy is declared ([EC-REVEAL] requires it before
   public mint); the sale record surfaces the reveal SLO so buyers see
   the reveal commitment before purchase.
5. Raffles, random winner selection, random assignment, and
   collection-wide reveal offsets are not sale-adapter-improvised
   randomness: the blessed pattern is the coordinator's sale/collection-
   scoped request kind
   ([`docs/stream-entropy-coordinator.md`](stream-entropy-coordinator.md)
   [Scope Entropy Requests](stream-entropy-coordinator.md#scope-entropy-requests)),
   which a future raffle or random-allocation adapter spec must consume
   instead of integrating an external randomness provider directly
   (Protocol v1 Exclusions item 11; ADR 0011 decision R8; the frozen
   safety recipe is [SSA-RAFFLE]).
6. Provider fee drift is never an adapter concern (ADR 0012 decision
   T7): `revealFeePerTokenWei` is an Operational funding parameter
   owned by the coordinator — never frozen entropy identity — and when
   a provider's live fee drifts above it on a long-lived collection,
   the remedy is the coordinator's reveal funding surface: the
   [EC-REVEAL] rule 9 fee update for future mints, the escrow top-up
   path, and the monitored escrow-versus-quoted-fee margin
   ([Reveal Ownership And Funding](stream-entropy-coordinator.md#reveal-ownership-and-funding),
   the home). Adapters keep charging exactly the live declared line
   item (rule 2) and must never improvise a fee adjustment away from
   the declared value; a drift shortfall is a monitored, funded
   condition at the coordinator, not a silent fallback failure at the
   sale layer.
7. Per-kind fee timing (ADR 0013 decision U6). The line item attaches
   to the transaction in which a token mints, and every genesis kind
   has a pinned answer — the two homes ([EC-REVEAL] rule 5 and this
   section) are satisfiable simultaneously on all of them:
   - Mint-at-purchase kinds — `FIXED_PRICE`, `OPEN_EDITION`,
     `ZERO_PRICE_CLAIM`, `PAY_WHAT_YOU_WANT`, `DUTCH_AUCTION`, the
     `DUTCH_AUCTION_CLEARING` purchase leg, `BURN_TO_MINT`, and
     mint-executing `PRIVATE_SALE`/`OFFER_SALE` acceptance — charge
     and forward at entry per rules 2 and 3.
   - `REFUND_WINDOW`: the live fee at purchase time is escrowed with
     the deposit as a further [SSA-REFUND] rule 1 purchase-record
     component (refundable-class, rule 3 of this section). A refund or
     [SSA-ENVELOPE] rule 4 unlock returns it in full with the deposit.
     Finalization reconciles: it forwards
     `min(escrowedFee, liveFeeAtFinalization)` to the coordinator
     escrow in the finalization transaction, credits any remainder to
     the payer as a pull refund, and a live fee above the escrowed
     amount never charges the buyer more, never blocks finalization,
     and is the coordinator's monitored funding condition (rule 6).
   - Mint-at-settlement `ENGLISH_AUCTION`: every bid escrows the live
     declared fee as a separate line item on top of the bid amount
     ([SSA-ENGLISH] rule 2); outbid credits return bid plus fee, and
     the `SettledNoMint` unlock returns the winner's fee with the
     refund. Settlement reconciles the winner's escrowed fee exactly
     as the refund-window finalization does. The fee is bound at bid
     time, so settlement never charges above the buyer's bound
     maximum ([SSA-ENVELOPE] rule 2).
   - `DUTCH_AUCTION_CLEARING` supplemental leg: carries no line item —
     the token minted, and the fee forwarded, in the purchase
     transaction.
   - `CUSTODY_INVENTORY_FIXED_PRICE` and custody-transfer settlement
     (`AUCTION_SETTLEMENT_TRANSFER` of a pre-minted token,
     custody-path offer acceptance, consignment): no line item — the
     tokens are already minted, and their reveal funding attached at
     the custody mint below. `BURN_TO_REDEEM` mints nothing and
     carries no line item.
   - Custody mints (`AUCTION_START_CUSTODY`, inventory custody mints)
     and airdrops: unpaid operator mints with no buyer to charge; the
     operator funds the coordinator escrow for the batch ([EC-REVEAL]
     rule 6 posture, [SSA-AIRDROP] rule 6), so custody-minted and
     airdropped tokens meet the same reveal SLO as purchased ones.

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
5. EIP-7702 posture (ADR 0013 decision U6): delegated EOAs are
   ordinary participants. No sale path classifies an account by code
   presence — delivery is the account-type-free attempt-then-claim
   shape ([SSA-ENGLISH] rules 7, 8, and 10) — and signature
   verification selects its path by the declared `authorizerKind`
   (mint spec `[MPA-AUTHZ]` rule 6), never by `extcodesize`: a
   7702-delegated EOA remains a valid ECDSA signer under its own key
   alongside any ERC-1271 code it exposes, classified per the
   wallet-class home
   ([`docs/adr/0004-admin-governance.md`](adr/0004-admin-governance.md)
   [GOV-1271-CLASS]). The rule 3 end-to-end validation run additionally
   includes a purchase, a bid with settlement delivery, and a claim
   from an EIP-7702-delegated wallet.

## Emergency Pause

Rule [SSA-ENGLISH] 11 promises that emergency handling "pauses new
actions and preserves bidder credits"; this section is that surface,
fully specified so no implementer invents the most incident-critical
control on the flagship mechanic (ADR 0011 decision R9).

Requirements [SSA-PAUSE]:

1. Scope and authority: every genesis adapter exposes adapter-wide pause
   and per-sale pause. Pausing is `IMMEDIATE_TIGHTENING` under the
   ADR 0004 action classes and is executable by the pause guardian role
   (`ROLE_PAUSE_GUARDIAN`, resolved through the admin registry);
   unpausing uses the dedicated no-timelock `ROLE_UNPAUSE` — disjoint
   from pause guardians — with an evented reason
   ([`docs/adr/0004-admin-governance.md`](adr/0004-admin-governance.md)
   [GOV-ROLES]; ADR 0012 decision T5).
2. What pauses: state-changing entry actions — purchases, bids,
   commits, reveals-as-purchases, offer acceptance, finalizations, and
   settlement initiation. What never pauses: `claimRefund` and every
   refund, rebate, excess-credit, proceeds, and NFT claim surface, and
   the [SSA-ENVELOPE] rule 4 refund unlock. A pause can stop money from
   entering; it can never stop owed money from leaving.
3. Clock tolling: when a pause overlaps a live timing window — an
   auction's bidding window, an anti-snipe window, a commit or reveal
   window, a refund window, or a finalization window — the affected
   deadlines extend by the paused duration when the pause lifts, evented
   per affected sale or auction. Tolling extensions are accounted
   separately from anti-snipe extensions and do not consume
   `maxTotalExtension`. A pause can therefore never silently convert
   active bidding into a settled outcome or eat a buyer's refund or
   reveal window; insiders gain no freeze-out lever because nobody can
   bid while paused and the clock resumes with the same time remaining.
4. Events: `AdapterPaused`/`AdapterUnpaused` for adapter-wide
   transitions and `SalePaused`/`SaleUnpaused` per sale, each carrying a
   reason hash. Pause state is operational: it is excluded from
   `saleConfigHash` and every sale identity preimage, mirroring the mint
   layer's pause-out-of-policy rule (ADR 0011 decision R6).
5. Pause never confiscates: escrowed funds, custody NFTs, and owed
   credits are untouched by any pause/unpause transition, and
   `INCIDENT_REVOKED` module status ([SSA-REGISTRY] rule 3) remains the
   stop for compromised adapters — pause is the reversible operational
   stop, revocation the terminal one.
6. The conformance matrix carries a pause suite: pause-over-endTime
   tolling, claim surfaces live while paused, unpause-role separation,
   and no-confiscation invariants ([SSA-GATES] item 12).

## Contested-Attribution Sale Stop

A `PLATFORM_WORKS` collection under an arbiter-elevated misappropriation
contest must stop selling while the contest is open: misappropriated art
must not keep converting into revenue while governance deliberates
(ADR 0012 decision T4). The contest lifecycle — claims, arbiter
elevation, the `CONTESTED`/`CONTEST_SUSTAINED`/`CONTEST_DISMISSED`
states, display, and finality effects — is owned by
[`docs/stream-artist-authority.md`](stream-artist-authority.md)
`[AA-PLATFORM]`; this section owns the sale-layer stop that home's
remedies invoke. Artist-bound collections need no equivalent here: their
`DISPUTED`/`REVOKED` states already fail the mint path closed (mint spec
`[MPA-CONSENT]` rule 6, [SSA-ENVELOPE] rule 4).

Requirements [SSA-CONTEST-STOP]:

1. Every genesis adapter exposes a per-collection contested-attribution
   stop with pause-equivalent semantics: while the stop is set for a
   `collectionId`, state-changing entry actions for that collection's
   sales (the [SSA-PAUSE] rule 2 inventory) revert with
   `SaleAttributionContested`; every claim, refund, rebate, proceeds,
   NFT-claim, and [SSA-ENVELOPE] rule 4 unlock surface stays live; and
   overlapped timing windows toll per [SSA-PAUSE] rule 3. The stop can
   halt money entering a contested collection; it can never confiscate
   or strand what is already owed.
2. The stop is set and cleared by a permissionless sync entrypoint that
   reads the collection's platform-works contest standing from the
   artist-authority registry (`[AA-PLATFORM]` rules 5 through 7) via a
   bounded `staticcall` under the `SALE_ARTIST_AUTHORITY_GAS_LIMIT`
   Governed Gas Parameter ([SSA-GAS]), with returndata copied only to
   the read's exact ABI shape — longer or shorter returndata is a
   failed read (ADR 0013 decision U7). After a successful sync, the
   stop flag must equal the registry's reading — set while the contest
   state is `CONTESTED` or `CONTEST_SUSTAINED`, clear otherwise — and
   every transition is evented `CollectionSaleStopSynced` with the
   observed state. A failed or out-of-gas read leaves the flag
   unchanged (the sync reverts; entry actions never perform this read
   themselves, so registry availability never gates ordinary sales).
3. The hook: the artist-authority home binds its arbiter elevation and
   resolution ceremonies to execute this sync in the same governance
   execution, and the monitoring baseline alarms on any divergence
   between registry contest state and adapter stop flags — the sync is
   permissionless precisely so anyone can close a gap the ceremony
   missed.
4. New sales: sale configuration for a collection whose stop flag is
   set (or whose registry contest standing reads stopped at
   configuration time) must revert. A contested collection can neither
   keep selling nor open new sales.
5. Stop state is Operational: excluded from `saleConfigHash` and every
   sale identity preimage, exactly like pause ([SSA-PAUSE] rule 4), and
   clearing it after `CONTEST_DISMISSED` restores serving with no
   identity rotation.

## Governed Gas Parameters

Requirements [SSA-GAS]:

1. `SALE_ERC1271_GAS_LIMIT` (genesis value `400_000`) bounds ERC-1271
   verification of sale authorizations and offers at adapter boundaries.
2. `DELEGATE_REGISTRY_GAS_LIMIT` (genesis value `150_000`) bounds delegate
   registry reads in the delegate gate and the adapter-side delegated
   sale-participation reads ([SSA-DELEGATE] rules 6 through 9; ADR 0013
   decision U6).
3. `SALE_ARTIST_AUTHORITY_GAS_LIMIT` (genesis value `150_000`) bounds
   artist-authority registry reads at adapter boundaries: the
   [SSA-CONTEST-STOP] contest-standing sync and the [SSA-IDENTITY]
   rule 8 sale-parameter consent verification (ADR 0012 decision T4).
4. `REVEAL_ATTEMPT_GAS_LIMIT` (genesis value `400_000`) bounds the
   adapter-held `AT_MINT` `requestEntropy` attempt ([SSA-REVEAL]
   rule 1; ADR 0013 decision U7). This document is the parameter's
   normative home; its floor is sized, with stated margin, from the
   coordinator's published measured `requestEntropy` envelope per
   genesis provider ([EC-REVEAL] rule 2,
   [`docs/stream-entropy-coordinator.md`](stream-entropy-coordinator.md)),
   re-verified at every release.
5. `SALE_NFT_DELIVERY_GAS_LIMIT` (genesis value `300_000`) bounds
   settlement-path NFT delivery attempts — the [SSA-ENGLISH] rule 7
   item (d) transfer, the rule 8 custody-to-winner delivery, the
   rule 10 poster delivery, and the [SSA-AIRDROP] rule 2
   failure-isolated deliveries — with capped returndata copying; a
   failed attempt diverts to the pull NFT claim (ADR 0013 decision U6),
   so every adapter external call is now GGP-bounded and the
   permissionless settlement caller cannot be gas- or
   returndata-bombed by a hostile receiver. Its floor is sized from
   the measured all-cold Core transfer (`MAX_TRANSFER_GAS`, mint spec
   `[MPA-GAS-BUDGET]`) plus receiver headroom.
6. All five are Governed Gas Parameters under the model home,
   [`docs/stream-long-term-architecture.md`](stream-long-term-architecture.md)
   [LTA-GGP] (ADR 0010 decision D1): floors, governance classes, probes,
   change events, manifest recording, and repricing-checklist membership
   follow the home unchanged, and the Operational-layer exclusion covers
   sale identity in this layer. This document adds no pattern rules of
   its own.
7. Failure-direction classes and probe discipline (ADR 0012 decision
   T1; ADR 0013 decisions U6 and U7; ADR 0014 decision V7). All five
   parameters carry the release-manifest failure-direction class
   `FAIL_CLOSED_PRECHECK` ([LTA-GGP] requirement 10). Parameters 1
   through 3 fail closed directly: authorization verification,
   delegate resolution, and artist-authority reads halt the guarded
   entry or configuration action on shortfall. Parameters 4 and 5
   bound failure-isolated attempts whose caught failure is safe — a
   caught entropy request leaves the token `REGISTERED` in the SLO
   window; a failed delivery records the pull NFT claim — but both
   keep the [SSA-ADAPTER] rule 9 63/64 parent-gas precheck, and
   insufficient parent gas reverts the entry or settlement call, so
   no caller can gas-shape a false failure onto someone else's
   outcome. Classification follows that observed failure direction
   on the guarded call, never read-path association ([LTA-GGP]
   requirement 10; ADR 0014 decision V7): raising either parameter
   raises every purchaser's revert threshold, so raises for all five
   are governance-only, and registering a permissionless conditional
   raise or conditional re-lower for any of them is nonconformant —
   the matrix scope-rejection test proves the absence. Each parameter's
   named probe is a Permanent-class probe contract ([LTA-GGP-PROBES])
   proving the guarded operation itself succeeds at the probed value
   over pinned caller-independent fixture inputs, with run records
   hosted on the probe and `evidenceHash` committing to the measurement
   artifact: for `SALE_ERC1271_GAS_LIMIT`, a maximum-supported-class
   ([GOV-1271-CLASS]) `isValidSignature` verification completing with
   the magic value under exactly the probed cap; for
   `DELEGATE_REGISTRY_GAS_LIMIT`, an all-cold delegate-registry
   resolution for a pinned fixture delegation completing with
   well-formed returndata; for `SALE_ARTIST_AUTHORITY_GAS_LIMIT`, an
   all-cold contest-standing read ([AA-PLATFORM]) and consent
   verification read ([AA-SALE-CONSENT]) for pinned fixture records
   completing with well-formed returndata under exactly the probed cap;
   for `REVEAL_ATTEMPT_GAS_LIMIT`, an all-cold representative
   `requestEntropy` attempt through the coordinator and a
   production-depth reference provider fixture completing under
   exactly the probed cap; for `SALE_NFT_DELIVERY_GAS_LIMIT`, an
   all-cold Core `safeTransferFrom` to a pinned accepting-receiver
   fixture completing under exactly the probed cap.

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

event SaleConsentRecorded(
    uint16 schemaVersion,
    bytes32 indexed saleId,
    uint256 indexed collectionId,
    bytes32 saleConfigHash,
    bytes32 consentEvidenceHash
);

event AuctionCreated(
    uint16 schemaVersion,
    bytes32 indexed auctionId,
    bytes32 indexed saleId,
    uint256 indexed collectionId,
    uint256 tokenId,
    bytes32 artworkCommitment,
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

event AuctionBidDeliveryBound(
    uint16 schemaVersion,
    bytes32 indexed auctionId,
    address indexed bidder,
    address indexed deliverTo
);

event AuctionExtended(
    uint16 schemaVersion,
    bytes32 indexed auctionId,
    uint64 previousEndTime,
    uint64 newEndTime,
    uint32 totalExtensionUsed
);

event AuctionExtensionBudgetWarning(
    uint16 schemaVersion,
    bytes32 indexed auctionId,
    uint32 totalExtensionUsed,
    uint32 remainingExtension
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

event AuctionSettledNoMint(
    uint16 schemaVersion,
    bytes32 indexed auctionId,
    address indexed winner,
    uint256 amount,
    bytes32 reasonHash
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

event DutchClearingRefundUnlocked(
    uint16 schemaVersion,
    bytes32 indexed saleId,
    bytes32 reasonHash
);

event SalePaymentExcessCredited(
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

event RefundWindowRefundUnlocked(
    uint16 schemaVersion,
    bytes32 indexed saleId,
    bytes32 indexed purchaseId,
    bytes32 reasonHash
);

event PrivateSaleExecuted(
    uint16 schemaVersion,
    bytes32 indexed saleId,
    address indexed buyer,
    uint256 tokenId,
    uint256 price,
    address asset
);

event InventorySaleExecuted(
    uint16 schemaVersion,
    bytes32 indexed saleId,
    address indexed buyer,
    uint256 indexed tokenId,
    uint256 price,
    address asset
);

event InventoryTokenReleased(
    uint16 schemaVersion,
    bytes32 indexed saleId,
    uint256 indexed tokenId,
    address receiver
);

event SaleCustodyDeposited(
    uint16 schemaVersion,
    bytes32 indexed saleId,
    uint256 indexed tokenId,
    address indexed owner
);

event SaleCustodyReleased(
    uint16 schemaVersion,
    bytes32 indexed saleId,
    uint256 indexed tokenId,
    address receiver,
    bytes32 reasonHash
);

event SaleCustodyGrantRevoked(
    uint16 schemaVersion,
    bytes32 indexed grantDigest,
    address indexed owner
);

event ConsignmentSettled(
    uint16 schemaVersion,
    bytes32 indexed saleId,
    uint256 indexed tokenId,
    address indexed buyer,
    uint256 price,
    uint256 royaltyAmount,
    address royaltyReceiver,
    address consignor
);

event OfferAccepted(
    uint16 schemaVersion,
    bytes32 indexed saleId,
    address indexed buyer,
    bytes32 offerDigest,
    uint256 price,
    address asset
);

event SaleAuthorizationConsumed(
    uint16 schemaVersion,
    bytes32 indexed saleId,
    bytes32 indexed digest,
    address authorizer
);

event SaleOfferRevoked(
    uint16 schemaVersion,
    bytes32 indexed offerDigest,
    address indexed buyer
);

event SaleAuthorizationRevoked(
    uint16 schemaVersion,
    bytes32 indexed saleId,
    bytes32 indexed digest,
    address authorizer
);

event AirdropDeliveryDiverted(
    uint16 schemaVersion,
    uint256 indexed collectionId,
    bytes32 indexed phaseId,
    uint256 indexed tokenId,
    address beneficiary
);

event AirdropNftClaimCompleted(
    uint16 schemaVersion,
    uint256 indexed collectionId,
    uint256 indexed tokenId,
    address indexed receiver
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

event ContentSelectionCommitted(
    uint16 schemaVersion,
    bytes32 indexed saleId,
    address indexed buyer,
    bytes32 selectionCommitment,
    uint256 amount
);

event ContentSelected(
    uint16 schemaVersion,
    bytes32 indexed saleId,
    bytes32 indexed contentId,
    address indexed payer,
    bytes32 tokenDataHash,
    uint256 tokenId
);

event SealedBidDepositForfeited(
    uint16 schemaVersion,
    bytes32 indexed auctionId,
    address indexed bidder,
    uint256 amount
);

event AdapterPaused(
    uint16 schemaVersion,
    address indexed guardian,
    bytes32 reasonHash
);

event AdapterUnpaused(
    uint16 schemaVersion,
    address indexed unpauser,
    bytes32 reasonHash
);

event SalePaused(
    uint16 schemaVersion,
    bytes32 indexed saleId,
    address indexed guardian,
    bytes32 reasonHash
);

event SaleUnpaused(
    uint16 schemaVersion,
    bytes32 indexed saleId,
    address indexed unpauser,
    bytes32 reasonHash
);

event CollectionSaleStopSynced(
    uint16 schemaVersion,
    uint256 indexed collectionId,
    bool stopped,
    uint8 contestState
);

event AdapterSurplusSwept(
    uint16 schemaVersion,
    address indexed to,
    address asset,
    uint256 amount,
    bytes32 actionId
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
error DutchPaymentBelowPrice(uint256 required, uint256 supplied);
error SaleRevealFeeBelowRequired(uint256 required, uint256 supplied);
error SaleFinalizeByExpired(uint64 finalizeBy);
error SaleEnvelopeModeInvalid();
error SaleRefundNotUnlocked(bytes32 purchaseId);
error SalePriceOutsideBand(uint256 minUnitPrice, uint256 maxUnitPrice, uint256 supplied);
error InventoryTokenUnavailable(uint256 tokenId);
error ContentCommitmentInvalid(bytes32 selectionCommitment);
error ContentRevealWindowInvalid(bytes32 selectionCommitment);
error SaleEntryPaused();
error BurnSourceNotOwned(uint256 sourceTokenId, address caller);
error BurnSourceCollectionNotAllowed(uint256 sourceCollectionId);
error BurnProofInvalid(uint256 sourceTokenId);
error ContentProofInvalid(bytes32 contentId);
error ContentAlreadySold(bytes32 contentId);
error DelegationNotFound(address vault, address delegate);
error OfferInvalid();
error SalePriceOverrideZeroUndeclared(bytes32 saleId);
error NothingClaimable(bytes32 saleId, address account);
error AuctionArtworkMismatch(bytes32 expected, bytes32 actual);
error CustodyGrantInvalid();
error SaleAttributionContested(uint256 collectionId);
error SaleFlowClosedForFacadeCollection(uint256 collectionId);
error SaleArtistConsentMissing(bytes32 saleConfigHash);
error SaleConsignmentDeclarationInvalid(uint256 tokenId);
error AdapterSurplusUnderfunded(address asset);
```

## Domain Constants And Typehashes

This table is the normative home for the sale-layer domain constants
(ADR 0010 decisions D3.1 and D3.5). The protocol v1 domain-constants table
mirrors these rows for the CI recomputation test; every hash value is
pinned from its string preimage and recomputed by CI.

| Constant name | String preimage | Hash value | Owner | Schema version | Inputs |
| --- | --- | --- | --- | --- | --- |
| `STREAM_SALE_V1` | `6529STREAM_SALE_V1` | 0x1167dd961e7616f9b2d1ebaa10110b8970558783a3c1b03e031c28fc3ed185d0 | sale adapters | `1` | `domain; chainid; saleAdapter; saleKind; collectionId; phaseId; saleNonce` |
| `STREAM_SALE_PURCHASE_V1` | `6529STREAM_SALE_PURCHASE_V1` | 0x47c000df4b149f6f8f2ecb12a836c6fc38b7e5379a3a433ad3d20a83eda821b1 | sale adapters | `1` | `domain; chainid; saleAdapter; saleId; buyer; purchaseNonce` |
| `STREAM_AUCTION_V1` | `6529STREAM_AUCTION_V1` | 0x747a8af1003df51f6ec4340fba0c00dcacb2f277d75387d56e4a811b90ffa645 | auction adapters | `1` | `domain; chainid; auctionContract; collectionId; localAuctionNonce; tokenId; tokenIdKnown` |
| `STREAM_DUTCH_SCHEDULE_V1` | `6529STREAM_DUTCH_SCHEDULE_V1` | 0xf22d2e97f1de4a74f3f96b4bd6c3dc8bd6a378980328e92785afa57f0c3957ad | Dutch adapter | `1` | `domain; chainid; saleAdapter; saleId; startPrice; restingPrice; startTime; endTime; decayKind; stepSeconds; stepAmount` |
| `STREAM_BURN_NULLIFIER_V1` | `6529STREAM_BURN_NULLIFIER_V1` | 0x678dd864ff303f21860e7aa38ee53d87e022b7bd7355b933e19d75019bba9d32 | burn gate | `1` | `domain; chainid; core; sourceTokenId` |
| `STREAM_EXTERNAL_BURN_NULLIFIER_V1` | `6529STREAM_EXTERNAL_BURN_NULLIFIER_V1` | 0x2006bdd49aec002acb0c643da251ae60d42b5d5214a833559fe5d58d90e34f95 | external-burn extension | `1` | `domain; chainid; sourceContract; sourceTokenId` ([SSA-BURN-EXTERNAL]; ADR 0013 decision U6) |
| `STREAM_HOLDER_ENTITLEMENT_V1` | `6529STREAM_HOLDER_ENTITLEMENT_V1` | 0x19dbbfcae28a5b8eac83eed3c9053dd7ab7af833cc61cfa94fe866d6a9e256f4 | hold-to-claim extension | `1` | `domain; chainid; sourceCore; entitlementId; sourceTokenId` |
| `STREAM_REDEMPTION_V1` | `6529STREAM_REDEMPTION_V1` | 0xe816b2cd9b695f515fad3c02582641b600d22416fe39f7c071eae91eda5d20df | redeem adapter | `1` | `domain; chainid; saleAdapter; core; burnedTokenId` |
| `STREAM_CONTENT_LEAF_V1` | `6529STREAM_CONTENT_LEAF_V1` | 0xfb3574a94e8672231a1ca6961a82ed077548322500d152474645664cb781b3e3 | content-selection adapters | `1` | double-hashed leaf: `domain; chainid; saleAdapter; saleId; contentId; tokenDataHash` |
| `STREAM_CONTENT_CONTEXT_V1` | `6529STREAM_CONTENT_CONTEXT_V1` | 0xc8ed10e43ef466bc9a26cbf502bbe6560cc53fc75b5f48650849304775459c68 | content-selection adapters | `1` | `domain; chainid; saleAdapter; saleId; contentId` |
| `STREAM_CONTENT_COMMIT_V1` | `6529STREAM_CONTENT_COMMIT_V1` | 0xd88e9c12d31ba2cd7a471bef88ad88216822842af7e38c0aef854486de420941 | content-selection adapters | `1` | `domain; chainid; saleAdapter; saleId; buyer; contentLeaf; salt` |
| `STREAM_CONTENT_CONSUMED_V1` | `6529STREAM_CONTENT_CONSUMED_V1` | 0x4a1bb00019fd08daa7e378b30312e4fdceb2c209f31effa024f891745f97f84a | content-consumption extension | `1` | `domain; chainid; core; collectionId; contentId` |
| `STREAM_SEALED_BID_V1` | `6529STREAM_SEALED_BID_V1` | 0x3f5199758c189f6205a065046fe5778bc3e349f7c373fa5c9f419b0718e3e3c6 | sealed-bid extension | `1` | `domain; chainid; auctionContract; auctionId; bidder; amount; salt` |
| `STREAM_RAFFLE_DRAW_V1` | `6529STREAM_RAFFLE_DRAW_V1` | 0x7bac77537b9b49e1c88e29e0fac9da7b983e54a03de6f7327c4eed66b617622c | raffle extension | `1` | `domain; chainid; saleAdapter; saleId; scopeSeed; entryRoot; drawIndex` |
| `SALE_AUTHORIZATION_TYPEHASH` | struct type string pinned in [SSA-AUTH] | 0xffd150d67de6a2619775f6cb884eadc8802d3d37fbd584d32ad0ff83ceddb098 | sale adapters | `1` | EIP-712 struct fields per [SSA-AUTH] (`bytes32 revenueClass`, trailing `uint64 finalizeBy`; ADR 0011 decisions R6 and R10) |
| `SALE_OFFER_TYPEHASH` | struct type string pinned in [SSA-OFFER] | 0x5befc984e6ca9dc13fb8238b12d2d8c7f77bcfbe46489470a66bbdda2b482d1b | sale adapters | `1` | EIP-712 struct fields per [SSA-OFFER] (trailing `uint64 finalizeBy`; ADR 0011 decision R6) |
| `SALE_CUSTODY_GRANT_TYPEHASH` | struct type string pinned in [SSA-CUSTODY-ENTRY] | 0xb829ff4936e00a75578357cfc3d855c59e780debb698eb3e8c8e9aff1b013041 | sale adapters | `1` | EIP-712 struct fields per [SSA-CUSTODY-ENTRY] (ADR 0012 decision T6) |
| `SALE_OFFER_REVOCATION_TYPEHASH` | struct type string pinned in [SSA-OFFER] rule 5 | 0xb80f6e5d7ac663ccfb28bbcfae73c4b3111804ebe80d7ac845e1eb88a44d191c | sale adapters | `1` | `chainId; saleAdapter; offerDigest` (ADR 0012 decision T6) |
| `SALE_AUTHORIZATION_REVOCATION_TYPEHASH` | struct type string pinned in [SSA-OFFER] rule 5 | 0x41d0d127fea4cbca0630f242fe7375e83ff775d8215636ae1fdd92b3d481a455 | sale adapters | `1` | `chainId; saleAdapter; authorizer; authorizationDigest` (ADR 0012 decision T6; authorizer field added by ADR 0013 decision U6) |
| `SALE_CUSTODY_GRANT_REVOCATION_TYPEHASH` | struct type string pinned in [SSA-CUSTODY-ENTRY] rule 4 | 0x56747c6d524c5e2b5568c382f06c2f3c787067868f362f65933656e7a67e8344 | sale adapters | `1` | `chainId; saleAdapter; owner; grantDigest` (ADR 0014 decision V6) |
| `GGP_SALE_ERC1271_GAS_LIMIT` | `6529STREAM_GGP_SALE_ERC1271_GAS_LIMIT` | 0x17b207440a43ce0136b5ee0bc3becf37652825825d88c68e1e0750bf59ec914c | sale adapters | `1` | Governed Gas Parameter identifier per [LTA-GGP] rule 5; [SSA-GAS] |
| `GGP_DELEGATE_REGISTRY_GAS_LIMIT` | `6529STREAM_GGP_DELEGATE_REGISTRY_GAS_LIMIT` | 0xd75b7f96fae550dd69de8ac7536a203e30ec57da63811df1559129479b5ef185 | delegate gate | `1` | Governed Gas Parameter identifier per [LTA-GGP] rule 5; [SSA-GAS] |
| `GGP_SALE_ARTIST_AUTHORITY_GAS_LIMIT` | `6529STREAM_GGP_SALE_ARTIST_AUTHORITY_GAS_LIMIT` | 0xe8a88819edeabf6e6327f815980331deea6ed50c446b74f1a24055fbc65ad4d0 | sale adapters | `1` | Governed Gas Parameter identifier per [LTA-GGP] rule 5; [SSA-GAS]; ADR 0012 decision T4 |
| `GGP_REVEAL_ATTEMPT_GAS_LIMIT` | `6529STREAM_GGP_REVEAL_ATTEMPT_GAS_LIMIT` | 0xd96deb8f5aad0fd19d6d79b209801e838cb0342c6967312895db5450ba01f01b | sale adapters | `1` | Governed Gas Parameter identifier per [LTA-GGP] rule 5; [SSA-GAS]; ADR 0013 decision U7 |
| `GGP_SALE_NFT_DELIVERY_GAS_LIMIT` | `6529STREAM_GGP_SALE_NFT_DELIVERY_GAS_LIMIT` | 0xaccd7fad510e0ff312662187cf184397c8d9baaf0a6bb18dc3b804cc3ae3b372 | sale adapters | `1` | Governed Gas Parameter identifier per [LTA-GGP] rule 5; [SSA-GAS]; ADR 0013 decision U6 |

One domain constant, one preimage shape: purchase IDs moved from the
round-1 `STREAM_SALE_V1` reuse to their own `STREAM_SALE_PURCHASE_V1`
domain (ADR 0011 decision R9), and the retired uint8-`revenueClass`
authorization typehash (`0x4d5722102337c13f9eba7b02dbdf7f716ab0ff4ef71d1c35a4bc2864461f64bc`),
pre-envelope offer typehash
(`0x76d0c5e2d6bb4b74d8cbfcb3cb7228fa182deee45e6053f070eced61b486b8eb`),
and authorizer-less sale-authorization revocation typehash
(`0x0a9eabaf9eb814b3a008ea8508065dabeb0055b317d7085aa7a7e9a11fb08850`,
superseded by the ADR 0013 decision U6 shape carrying the explicit
`authorizer`)
are superseded and must not be deployed. Every 0x hash value above —
the rows introduced by ADR 0013 included — is
pinned from
its adjacent string preimage and recomputed by CI, and drift fails the
matrix Review-entry condition; the protocol v1 mirror
rows carry the same values (ADR 0013 decision U9, retiring the stale
ADR 0012 transitional note). A future amendment that adds a row may
carry an unpinned placeholder only under the [PV1-MIRROR] rule 2
transitional discipline — exact string preimage adjacent at home and
mirror alike, pinned by the CI recomputation before this document
leaves Draft. The `SALE_CUSTODY_GRANT_REVOCATION_TYPEHASH` row
(ADR 0014 decision V6) entered under that discipline and is now
pinned like every other row: its full EIP-712 type string is pinned
in [SSA-CUSTODY-ENTRY] rule 4, its hash value is recorded above, and
the protocol v1 mirror carries the same preimage and value.

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
   settlement, contract-winner and contract-poster claim paths (the
   account-type-free custody-and-bounded-attempt delivery for a hostile
   contract winner that tries to gas-bomb, returndata-bomb, revert, or
   replay settlement, plus a golden settlement to an EIP-7702-delegated
   winner delivered when its receiver accepts and diverted to the claim
   when it rejects; ADR 0013 decision U6), first-bid-starts clock
   derivation and its anti-snipe interaction, mint-at-settlement
   `SettledNoMint` unlock with winner refund, mint-at-settlement
   artwork-commitment binding (zero-commitment configuration reverts;
   settlement whose minted `tokenData` hash mismatches the committed
   `artworkCommitment` reverts `AuctionArtworkMismatch`; ADR 0012
   decision T6), recorded floor waivers (a `hardClose` auction never
   extends; sub-floor increment or zero window without the declared
   waiver reverts at configuration; waiver flags bind into
   `saleConfigHash`; ADR 0013 decision U6), deliver-to binding
   (delegated first-bid binding verified and immutable; non-delegate
   `deliverTo` refused; delivery to the vault with refunds to the
   bidder), budget-exhaustion hard close (extensions stop exactly at
   `originalEndTime + maxTotalExtension`, a final-window bid after
   exhaustion never extends, and `AuctionExtensionBudgetWarning`
   emits exactly once when half the budget is first consumed;
   ADR 0014 decision V5), `auctionConfig` read consistency (creation
   configuration and live `totalExtensionUsed`/`endTime` match events
   and `saleConfigHash`; ADR 0014 decision V5), pre-bid cancellation,
   emergency preservation of owed credits.
2. Dutch suite: schedule determinism (linear and stepped), commitment
   verification, maximum-price purchase (excess credited as pull refund;
   below-price revert; no exact-payment revert under one-slot drift),
   schedule floor enforcement (`restingPrice = 0` or `startPrice = 0`
   without the declared free-mint class reverts
   `DutchScheduleInvalid`; a declared free-mint-class sale executes
   its price-0 boundary as [SSA-ZERO] semantics with no settlement
   record; ADR 0013 decision U6), Merkle `priceOverride` ceiling on
   time-varying kinds (charged equals `min(schedule, override)`;
   override below the clearing floor reverts; overridden purchases fix
   clearing at schedule price and rebate against
   `min(clearing, override)`; ADR 0013 decision U6),
   clearing-price fixing (sold-out and resting cases), floor-settlement
   conformance at purchase, rebate crediting independent of supplemental
   settlement, supplemental settlement `ALLOW_CURRENT` under
   purchase-to-finalization policy drift (drift evented, no deadlock),
   supplemental-revenue and rebate accounting conservation (escrow in =
   supplemental revenue + rebates + unlocked refunds), rebate claims,
   refusal to finalize twice, clearing refund unlock at finalize-by
   lapse.
3. Refund-window suite: escrow custody, refund before deadline, refusal
   between deadline and finalize-by, permissionless idempotent
   finalization, official settlement exactly once, configuration-fit
   refusal (windows exceeding the phase `endTime`), refund unlock on
   each pinned non-transient failure reason and on finalize-by lapse,
   unlocked refunds claimable with no deadline, and the by-construction
   envelope: a public refund-window purchase executes with no typed
   signature, with `msg.value`, calldata, and the standing finalization
   window binding the full [SSA-ENVELOPE] rule 2 envelope
   ([SSA-ENVELOPE] rule 6).
4. Burn suite: same-transaction burn proof, retained-identity checks,
   nullifier consumption and cross-manager scoping, source-collection
   allowlist, finality interaction refusals, redemption record and
   fulfillment append-only behavior.
5. Delegate gate suite: pinned registry codehash, scope acceptance matrix,
   revocation honored, gas-bounded reads with exact-shape returndata
   (oversized returndata fails the read; ADR 0013 decision U7),
   fail-closed on registry
   failure, deliver-to-vault counter correctness, and the delegated
   participation surfaces (ADR 0013 decision U6): delegate-signed offer
   accepted and non-delegate signer refused, `claimRefundFor` by a live
   delegate pays only the credited account and a non-delegate caller
   reverts, delegate-triggered NFT claim delivers only to the claimant.
6. Content-selection suite: proof verification, double-sale race at the
   ledger, tokenData hash binding, serial-selection refusal,
   commit-reveal mode (same-block reveal refusal, non-committer reveal
   refusal, losing and unrevealed commit refunds, `PUBLIC`-mode
   declaration requirement).
7. Account-abstraction run: the release evidence must include the
   ERC-4337 smart-account plus paymaster end-to-end mint against the
   genesis public adapter ([SSA-AA] 3) and the EIP-7702-delegated
   wallet purchase, bid-with-delivery, and claim cases ([SSA-AA] 5;
   ADR 0013 decision U6).
8. Registry governance: every genesis adapter/gate registered `ACTIVE`
   with codehash pins; paid-phase executor grant refused for unregistered
   contracts; `INCIDENT_REVOKED` adapter execution reverts.
9. Static analysis: no `tx.origin`, no push ETH in bid/settlement paths,
   reentrancy guards on every claim surface.
10. Gas budget: the end-to-end collector mint gas budget artifact defined
    in the mint spec (`[MPA-GAS-BUDGET]`) must include the genesis
    fixed-price purchase and the Dutch standard purchase paths, measured
    against the mint spec's normative ceilings.
11. Event reconstruction: sale, auction, refund, rebate, unlock, burn,
    and redemption state must be rebuildable from events alone, matching
    direct reads (protocol v1 event reconstruction rule).
12. Pause suite: pause-over-endTime tolling (bidding, reveal, refund, and
    finalization windows resume with time remaining), claim and unlock
    surfaces live while paused, pause-guardian versus `ROLE_UNPAUSE`
    separation, no-confiscation invariants, pause state excluded from
    sale identity.
13. Price-kind suite: zero-price claim (zero `msg.value`, no settlement
    record), pay-what-you-want band enforcement (below/above band
    reverts, exact chosen payment, full amount settled), custody-
    inventory purchase (custody invariants, per-token one-shot status,
    `CUSTODY_SETTLEMENT_TRANSFER` ordering, unsold-token release), and
    airdrop distribution (one free-phase batch to N distinct recipients
    under a phase-supply counter and per-recipient caps, EOA executor
    on the unpaid phase, no settlement record; [SSA-AIRDROP]) —
    including the failure-isolated shape: an adapter-executed slice
    containing a rejecting contract recipient completes with exactly
    that element diverted to a pull NFT claim, every sibling
    delivered, and per-element divert events emitted (ADR 0013
    decision U6). The suite also covers the declared zero-override
    free tier ([SSA-AUTH] rule 3; ADR 0014 decision V5): a proven
    zero-`priceOverride` leaf on a fixed-price or time-varying kind
    without the sale record's free-claim declaration reverts
    `SalePriceOverrideZeroUndeclared`; with the declaration it
    executes [SSA-ZERO] semantics with no settlement record; and on
    `PAY_WHAT_YOU_WANT` it binds a zero authorization minimum with
    the band still enforced.
14. Reveal-fee suite: allowance binding (allowance below the live fee
    reverts `SaleRevealFeeBelowRequired`; a fee retune between quote
    and inclusion lands with the live fee charged and the unspent
    allowance pull-credited; ADR 0013 decision U6), mint-transaction
    `fundRevealFeeEscrow` forwarding, official-revenue exclusion,
    attempt-and-catch mint isolation (provider failure never reverts
    the purchase, and the attempt forwards at most
    `REVEAL_ATTEMPT_GAS_LIMIT`; ADR 0013 decision U7), configuration
    refusal for undeclared `ASYNC` reveal
    policy, and the per-kind timing cases ([SSA-REVEAL] rule 7): a
    refund-window refund and unlock return the escrowed fee; a
    refund-window finalization forwards `min(escrowed, live)` and
    credits the remainder; an auction outbid returns bid plus fee and
    settlement reconciles the winner's fee; `SettledNoMint` returns
    the winner's fee; custody-inventory purchases and clearing
    supplemental legs carry no line item.
15. Replay-locus suite: custody-path authorization and offer digests
    consumed in the adapter store before external interactions, repeat
    acceptance refused after seller reacquisition, custody-path offer
    and authorization revocation through the pinned presentation shapes
    (non-signer revocation refused; revoked digests never execute),
    mint-path offer digests consumed through the ledger under the
    dual-digest locus (ADR 0013 decision U6): a consumed offer
    presented with a freshly signed authorization reverts at the
    ledger, a consumed authorization presented with a second offer
    reverts at the adapter store, and both digests consume atomically
    in one acceptance. Authorizer-presentation cases (ADR 0013
    decision U6): a Safe-class contract signer's relayed revocation
    executes through the ERC-1271 path against the claimed authorizer;
    a claimed authorizer outside the authorized sale-signer set is
    refused for execution and revocation; 1271 acceptance verifies the
    claimed authorizer against the signer set before
    `isValidSignature`.
16. Adapter escrow conservation suite (ADR 0012 decision T7): the
    [SSA-ADAPTER] rule 14 per-asset solvency invariant holds under
    randomized cross-mode sequences (purchases, bids, outbids, refunds,
    finalizations, unlocks, claims) with forced-ETH injection; one
    sale's credits are never satisfied by another sale's escrow;
    forced/direct value never enters credits or official revenue; the
    surplus sweep pays only above tracked liabilities and reverts
    `AdapterSurplusUnderfunded` otherwise; plain ETH transfers to the
    adapter revert. This is the sale-layer mirror of the split-wallet
    "conservation fuzz, forced ETH" gate.
17. Contest-stop suite (ADR 0012 decision T4): sync sets and clears the
    per-collection stop to match registry contest standing; entry
    actions revert `SaleAttributionContested` while stopped; claim and
    unlock surfaces stay live; overlapped windows toll; new-sale
    configuration refused while stopped; stop state excluded from sale
    identity.
18. Consignment and custody-grant suite (ADR 0012 decision T6):
    owner-sent and owner-signed custody entry; non-owner grant refused;
    grant single-use and revocable-until-sale with custody reclaim;
    the pinned `SaleCustodyGrantRevocation` shape (ADR 0014 decision
    V6): owner-sent and owner-signed (ERC-1271 relayed) revocation
    both void the digest and event `SaleCustodyGrantRevoked`, a
    non-owner revocation is refused, a revoked grant never enters
    custody, and a relayed reclaim releases only to the owner;
    consignment declaration required and misdeclaration refused
    (previously-delivered token sold as primary, or primary inventory
    sold as consignment); royalty computed, itemized, and delivered
    (divert-and-retry on a reverting receiver); consignor proceeds
    pull-claimable; no consignment value in any official-revenue
    counter; and the [SSA-CONSIGN] rule 7 collector-disclosure fields
    present in the sale-record surfaces (rehearsal evidence; ADR 0013
    decision U6).
19. Artist sale-parameter consent (ADR 0012 decision T4): for a
    collection whose consent scope pins sale-parameter approval, sale
    opening without verified consent over the exact `saleConfigHash`
    reverts `SaleArtistConsentMissing`; consent evidence is evented;
    unpinned-scope collections configure without it.
20. Raffle recipe vectors (ADR 0014 decision V5): the [SSA-RAFFLE]
    worked example runs at genesis as an offchain-recomputable vector
    suite — pinned fixture entries and a fixture seed reproduce the
    [EC-SCOPE-RAFFLE] rule 3 winner order, the `STREAM_RAFFLE_DRAW_V1`
    draw commitment recomputes from the fixture, and the
    entry-root-before-seed ordering is asserted — shared with the
    coordinator's fair-allocation golden vectors. Adapter bytecode
    tests still ship with the future accepted raffle spec.
21. Sale-surface disclosure evidence (ADR 0014 decision V5): the
    rehearsal/release evidence checklist covers the round-5
    disclosure duties — network-gate and holder fallback trust
    ([SSA-NETWORK-ELIGIBILITY] rule 5, [SSA-HOLDER] rule 3,
    [SSA-BURN-EXTERNAL] launch posture), keep-the-token redemption
    posture ([SSA-REDEEM] rule 4), the sequential-serial consequence
    ([SSA-CONTENT] rule 4), the pre-bid cancellation race and poster
    history display ([SSA-ENGLISH] rule 11, [SSA-CUSTODY-ENTRY]
    rule 4), the budget-exhausted hard-close display ([SSA-ENGLISH]
    rule 4), and the FCFS default statement ([SSA-RAFFLE] rule 6) —
    exactly as item 18 covers the consignment disclosure fields.
22. Identity-mode configuration gate (ADR 0015 decision W3): the
    [SSA-IDENTITY] rule 9 suite — configuration of each excluded
    custody or burn flow against an `EXTERNAL_FACADE` collection
    reverts `SaleFlowClosedForFacadeCollection` (English auction in
    every variant, custody-inventory and consignment, custody-held
    private sale and offer acceptance, the failure-isolated airdrop
    shape, and burn programs with a facade-mode Stream source or
    redeemed collection); identical configurations succeed for
    `CORE_NATIVE` collections; and a mint-delivery kind configures
    and settles identically in both modes.

## Protocol v1 Exclusions

Exclusion is intentional absence, not deferral (spec policy). Adding any
item requires its own accepted spec through the frozen extension
mechanisms:

1. Sealed-bid and ranked auction implementations (interfaces are frozen
   above).
2. ERC-20 auction bidding and ERC-20 sealed-bid deposit implementations
   (the interface and invariants are frozen in [SSA-ERC20-BID]).
3. Bonding curves, VRGDA-style issuance, and AMM-priced sales.
4. Standing orderbooks, collection-wide floor offers, and offer matching.
5. Secondary-market listings, wash-trade surveillance, and marketplace
   aggregation (this layer is primary-sale only). The single carved
   exception is declared consignment of custody-held owner tokens per
   [SSA-CONSIGN], which settles as a secondary transfer with royalty
   disclosure and never as primary revenue (ADR 0012 decision T6);
   listing services, orderbooks, and aggregation remain excluded.
6. Post-settlement refunds of officially settled revenue, in any mechanic.
7. Pre-burned claim credit and external-collection burn sources. The
   external-burn safety recipe and nullifier domain are frozen in
   [SSA-BURN-EXTERNAL] (ADR 0013 decision U6); a future adapter spec
   must satisfy them.
8. Cross-chain or bridged sale execution.
9. Fiat/credit-card rails (Operational integrations may front conformant
   onchain sales but are outside protocol surface).
10. ERC-2771 trusted forwarders in sale paths.
11. Onchain raffles, lotteries, verifiable random winner selection, and
    random assignment adapters. A future adapter spec must consume the
    entropy coordinator's sale/collection-scoped request kind
    ([SSA-REVEAL] rule 5) so it inherits the reviewed anti-reroll
    lifecycle instead of integrating external randomness directly, and
    must satisfy the frozen safety recipe of [SSA-RAFFLE] (ADR 0012
    decision T6).
12. Hold-to-claim gate implementations (the recipe and nullifier domain
    are pinned in [SSA-HOLDER]).
13. Escrowed-offer kinds that hold buyer funds before acceptance
    ([SSA-OFFER] rule 6).
14. Content-consumption registry gate implementations (the cross-sale
    uniqueness recipe and nullifier domain are pinned in
    [SSA-CONTENT-UNIQUE]).
15. Multi-unit (edition) auctions — auctioning an edition of N to the
    top N bidders (ADR 0013 decision U6). The frozen extension profile
    is `IStreamRankedAuction` with the [SSA-SEALED] rule 5 safety
    invariants and the reserved `RANKED_AUCTION` kind; pricing, winner
    count, and tie-breaking are pinned by the future accepted spec,
    which should adopt uniform-price top-N with deterministic
    entry-order tie-breaking as the first implementation profile. At
    genesis, small-edition price discovery runs on Dutch clearing or
    sequential 1/1 auctions.
16. Multi-token lot and bundle sales — one atomic purchase of a curated
    set of N specific works (gallery sets, estate lots; ADR 0013
    decision U6). The extension path is a future accepted adapter spec
    with an appended `SaleKind` value through the [SSA-IDENTITY] rule 6
    catalog.
17. Reserve-auction buy-now hybrids — a fixed-price instant purchase
    that terminates a live auction (ADR 0013 decision U6). The
    extension path is an appended `SaleKind` through the same catalog,
    and any accepted hybrid must respect the [SSA-ENGLISH] rule 11
    boundary: after the first valid bid, no purchase path may cancel or
    bypass the auction.
18. Network-eligibility (TDH-class) gate implementations — live
    TDH/profile/consolidation eligibility computed from network state
    (ADR 0014 decision V5). The frozen profile is
    [SSA-NETWORK-ELIGIBILITY]; the disclosed genesis fallbacks are
    snapshot Merkle allowlists and signed tickets.
19. Content selection on time-varying kinds — Dutch-with-selection and
    every choice-at-a-moving-price composition (ADR 0014 decision V5).
    The frozen interaction profile is [SSA-CONTENT-TIME]; the appended
    kind arrives through the [SSA-IDENTITY] rule 6 catalog.

Format-gap honesty (ADR 0014 decision V5): items 1, 2, 11, and 15
through 17 are sale formats in routine weekly use on incumbent venues
— ranked small-edition auctions, buy-now hybrids, lots, WETH bidding,
sealed bids, raffles. Their absence at genesis is a disclosed product
posture, not an oversight: each carries a frozen interface, profile,
or recipe above so it arrives as a reviewed Replaceable adapter, the
[Pattern Coverage Matrix](#pattern-coverage-matrix) names the
sanctioned genesis substitute per pattern, and the post-genesis
adapter wave — which specs land first, with target review dates — is
owned by the audit plan's critical-path schedule, not by this
document.

## Pattern Coverage Matrix

[SSA-PATTERNS]

One question dominates long-horizon curation: can this platform do X,
and through which mechanism? The answer was previously spread across
the `SaleKind` catalog, the mechanic-families table, four exclusion
lists, and six recipe sections in four documents; this matrix
consolidates it (ADR 0014 decision V5). It is a mirror, never a
second home (spec policy, Normative Precedence And Single Sourcing):
every row cites its owning anchor and restates no semantics, and a
row conflicting with its home is a defect in the row. Status
vocabulary: `genesis` (deployed genesis capability), `profile`
(frozen Permanent interface or recipe, no genesis implementation; an
accepted spec is the extension path), `operational` (documented
pattern over genesis surfaces, no new contract), `excluded`
(intentional absence with the stated extension path), and
`successor-line` (never on this Core line).

| Pattern | Status | Mechanism and owning anchor | Genesis substitute / notes |
| --- | --- | --- | --- |
| Fixed-price sale, open edition | genesis | `FIXED_PRICE`/`OPEN_EDITION`, [SSA-FIXED] | — |
| Free claim | genesis | `ZERO_PRICE_CLAIM`, [SSA-ZERO] | — |
| Free tier inside a paid drop | genesis | zero `priceOverride` under a declared free tier, [SSA-AUTH] rule 3 | declaration required, else revert |
| Pay-what-you-want / tip-at-mint | genesis | `PAY_WHAT_YOU_WANT`, [SSA-PWYW] | — |
| Reserve English auction (1/1) | genesis | `ENGLISH_AUCTION`, [SSA-ENGLISH] | — |
| First-bid-starts auction | genesis | [SSA-ENGLISH] rule 14 | — |
| Auction of a chosen curated work | genesis | [SSA-ENGLISH] rule 8 leaf commitment | one work per auction |
| Dutch auction | genesis | `DUTCH_AUCTION`, [SSA-DUTCH] | — |
| Uniform-clearing Dutch with rebates | genesis | `DUTCH_AUCTION_CLEARING`, [SSA-DUTCH-CLEARING] | — |
| Private/direct sale | genesis | `PRIVATE_SALE`, [SSA-PRIVATE] | — |
| Offer / accept-offer | genesis | `OFFER_SALE`, [SSA-OFFER] | atomic only (exclusion 13) |
| Gallery inventory at fixed price | genesis | `CUSTODY_INVENTORY_FIXED_PRICE`, [SSA-INVENTORY] | — |
| Consigned resale (estate, deaccession) | genesis | [SSA-CONSIGN] | secondary transfer, royalty-itemized |
| Refund-window sale | genesis | `REFUND_WINDOW`, [SSA-REFUND] | — |
| Burn-to-mint (Stream sources) | genesis | `BURN_TO_MINT`, [SSA-BURN] | — |
| Burn-to-redeem (burn for physical) | genesis | `BURN_TO_REDEEM`, [SSA-REDEEM] | — |
| Keep-the-token physical redemption | profile | [SSA-REDEEM] rule 4 over [SSA-HOLDER] | signed tickets + owner-record claim, disclosed |
| External-collection burn (Memes card) | profile | [SSA-BURN-EXTERNAL], exclusion 7 | attested-ticket phases, disclosed |
| Hold-to-claim companion/derivative | profile | [SSA-HOLDER], exclusion 12 | snapshot Merkle / tickets, disclosed |
| TDH / network eligibility | profile | [SSA-NETWORK-ELIGIBILITY], exclusion 18 | snapshot Merkle / tickets, disclosed |
| Airdrop / operator distribution | genesis | [SSA-AIRDROP] | — |
| Pick-your-piece (fixed/private price) | genesis | [SSA-CONTENT] | — |
| Pick-your-piece at a moving price | profile | [SSA-CONTENT-TIME], exclusion 19 | fixed-price selection, or Dutch without selection |
| Cross-sale content uniqueness | profile + operational | [SSA-CONTENT-UNIQUE], exclusion 14 | mandatory rehearsal check at genesis |
| Small editions (N ERC-721 serials) | genesis | [SSA-EDITIONS] | envelope note in that section |
| Mass timed open editions | genesis mechanics, out of envelope | [SSA-EDITIONS] sizing note | successor line / L2 posture |
| Ranked multi-unit edition auction | profile | `RANKED_AUCTION` (reserved kind), `IStreamRankedAuction`, exclusion 15 | Dutch clearing or sequential 1/1 auctions |
| Sealed-bid auction | profile | `SEALED_BID` (reserved kind), [SSA-SEALED], exclusion 1 | — |
| ERC-20 / WETH bidding | profile | [SSA-ERC20-BID], exclusion 2 | native ETH bids |
| Raffle / random allocation | profile | [SSA-RAFFLE] + [EC-SCOPE-RAFFLE], exclusion 11 | Dutch clearing; allowlist tiers |
| Buy-now terminating a live auction | excluded | exclusion 17 (append path) | fixed-price sale beside the auction |
| Multi-token lots and bundles | excluded | exclusion 16 (append path) | per-token sales |
| Bonding curves / VRGDA / AMM pricing | excluded | exclusion 3 | stepped Dutch approximation ([SSA-DUTCH] rule 5) |
| Standing orderbooks / floor offers | excluded | exclusion 4 | single-subject offers |
| Secondary marketplace / aggregation | excluded | exclusion 5 | [SSA-CONSIGN] carve only |
| Escrowed offers | excluded | exclusion 13, [SSA-OFFER] rule 6 | atomic offers |
| Post-settlement refunds of settled revenue | excluded | exclusion 6; [SSA-ADAPTER] rule 5 | refund-window mode before finalization |
| Cross-chain sale execution | excluded | exclusion 8 | — |
| ERC-2771 meta-transaction sale entry | excluded | exclusion 10; [SSA-AA] rule 4 | ERC-4337 smart accounts ([SSA-AA]) |
| Fiat / card rails | operational | exclusion 9 | fronts a conformant onchain sale |
| Mementos / attendance artifacts | operational | Mementos And Attendance Artifacts; [CMC-MEMENTO] | attestations; transferable token optional |
| Evolving / dynamic works sale | genesis | sale kinds unchanged; recipe home [MRR-EVOLVING-RECIPE] | rendering/consent composition, no sale rule |
| Serial / vanity number selection | successor-line | reservation posture home: mint spec Core Contract Changes; [SSA-CONTENT] rule 4 | content selection binds artwork, never serial |
| Soulbound / transfer-locked tokens | successor-line | [PV1-EXCL] (protocol v1 specification) | attestation pattern above |
| ERC-1155 / semi-fungible editions | successor-line | [SSA-EDITIONS]; [PV1-EXCL] item 11 | N ERC-721 serials |

Row-set completeness is a checkable property: every `SaleKind` value,
every extension profile and recipe anchor in this document, and every
Protocol v1 Exclusions item above must appear in exactly one owning
row (a notes-column cross-reference in another row does not count). A
release checker enforcing that completeness is a Review-entry
condition tracked by the conformance matrix's verification-tooling
backlog (ADR 0014 decision V9); until it exists, the check runs as
review discipline on every amendment touching a pattern home.

## Test Requirements

1. Every numbered requirement in [SSA-IDENTITY], [SSA-ADAPTER],
   [SSA-REGISTRY],
   [SSA-AUTH], [SSA-FIXED], [SSA-ZERO], [SSA-PWYW], [SSA-AIRDROP],
   [SSA-ENGLISH],
   [SSA-DUTCH], [SSA-DUTCH-CLEARING], [SSA-PRIVATE], [SSA-OFFER],
   [SSA-CUSTODY-ENTRY],
   [SSA-INVENTORY], [SSA-CONSIGN], [SSA-ENVELOPE], [SSA-REFUND],
   [SSA-BURN],
   [SSA-BURN-FINALITY], [SSA-REDEEM], [SSA-DELEGATE], [SSA-CONTENT],
   [SSA-REVEAL], [SSA-GRACE], [SSA-AA], [SSA-PAUSE],
   [SSA-CONTEST-STOP], and [SSA-GAS] maps
   to at least one test named in the conformance gates above.
   ([SSA-HOLDER], [SSA-SEALED], [SSA-ERC20-BID], [SSA-RAFFLE],
   [SSA-BURN-EXTERNAL], [SSA-NETWORK-ELIGIBILITY],
   [SSA-CONTENT-TIME], and [SSA-CONTENT-UNIQUE] rule 1 are extension
   profiles and recipes: their tests ship with the future
   implementation specs, except the [SSA-RAFFLE] recipe vectors,
   which run at genesis under [SSA-GATES] item 20 (ADR 0014 decision
   V5). [SSA-CONTENT-UNIQUE] rules 2 and 3 and the [SSA-GATES]
   item 21 disclosure duties map to the rehearsal-evidence
   checklist.)
2. Negative tests: below-reserve and below-increment bids; bid at exactly
   `endTime`; extension beyond `maxTotalExtension`; settlement before end;
   double settlement; refund after finalization; finalize during window;
   finalize after `finalizeBy`; claim before unlock; unlock while
   finalization is still possible; Dutch payment below current price;
   pay-what-you-want price outside band; custody-inventory double sale;
   `STRICT_MATCH` configured on a deferred leg; same-block commit-reveal;
   clearing finalize twice; burn of non-owned token; burn source not in
   allowlist; content double-sale race; stale/revoked delegation; expired
   and replayed authorizations and offers (both ledger and adapter-store
   loci); a consumed mint-path offer under a freshly signed
   authorization; zero-address and non-canonical signature rejection
   (shared with
   mint spec `[MPA-AUTHZ]`); mint-at-settlement `tokenData` mismatch
   against the committed `artworkCommitment`; zero `artworkCommitment`
   with `mintAtSettlement = true`; Dutch `restingPrice = 0` or
   `startPrice = 0` without the declared free-mint class; reveal-fee
   allowance below the live fee; sub-floor increment or zero anti-snipe
   window without the declared waiver; a zero `priceOverride` leaf on
   a paid kind without the declared free tier; a claimed authorizer
   outside the
   sale-signer set; `claimRefundFor` by a non-delegate; custody grant
   by a non-owner; custody grant revocation by a non-owner signature;
   custody entry under a revoked grant; custody
   grant replay; custody reclaim after sale execution; consignment
   misdeclaration in both directions; entry action on a contest-stopped
   collection; surplus sweep exceeding surplus; sale opening without
   pinned sale-parameter consent where the scope requires it.
3. Conservation fuzz: for each escrow-holding mode, adapter escrow in
   equals refunds + rebates + excess credits + unlocked refunds +
   reveal-fee forwarding out + official settlement out, under randomized
   purchase/refund/outbid/unlock sequences with forced-ETH injection —
   and cross-mode, the [SSA-ADAPTER] rule 14 per-asset solvency
   invariant and rule 15 forced-value exclusion hold throughout
   ([SSA-GATES] item 16).
4. Reconstruction harness: rebuild sale and auction state from events and
   compare to reads (gate 11).

## Acceptance Criteria

1. Every genesis adapter and gate in the Design Summary is specified here,
   registered under [SSA-REGISTRY], and listed in the conformance-matrix
   genesis profile.
2. English auctions enforce reserve, minimum increment, and anti-snipe
   extension with caps — in both preset-window and first-bid-starts modes
   — all bound into sale identity and events; the increment and
   anti-snipe floors are waivable only by explicit recorded
   creation-time declarations, disclosed on bidder surfaces (ADR 0013
   decision U6), and extension-budget exhaustion is itself an evented,
   displayed hard-close state with remaining budget readable onchain
   (ADR 0014 decision V5).
3. Dutch auctions support linear and stepped decay with committed
   schedules, purchases bind `msg.value` as a maximum with excess
   credited, and the clearing mode pays uniform prices with escrowed,
   pull-claimable rebates while every official settlement remains
   path-conformant.
4. Private sales, offers, custody-inventory sales, and refund-window
   sales execute with full signed bindings including price, asset,
   deadline, and — for deferred legs — the drift envelope.
5. Burn-to-mint and burn-to-redeem work through the registry-governed gate
   with manager-scoped nullifiers and the finality interaction rule
   enforced and surfaced.
6. Sealed-bid, ranked, ERC-20-bidding, and network-eligibility
   interfaces are frozen with
   safety invariants — never auction economics — and no genesis bytecode.
7. Delegated minting and pick-your-piece selection follow the documented
   patterns without new trust assumptions, and differentiated-content
   selection defaults to commit-reveal.
8. A collector can mint from an ERC-4337 smart account with a sponsoring
   paymaster against the genesis public adapter.
9. No sale path can strand funds, custody, or NFTs without a pull-claim
   recovery, and no path can refund officially settled revenue. Every
   escrow-holding mode carries the [SSA-ENVELOPE] finalize-by deadline
   and refund unlock, so the recovery holds under policy drift, phase
   exhaustion, disputes, and module revocation — not only on the happy
   path.
10. Zero-price claims and pay-what-you-want bands execute as declared
    first-class kinds with the reveal-fee line item where one applies.
11. Emergency pause stops entries without touching claims, tolls every
    overlapped window, and never appears in sale identity.
12. Airdrops run as the named operator-distribution pattern — committed
    recipient sets, counter-bounded, no settlement records — and the
    editions posture (N ERC-721 serials, never ERC-1155) is stated and
    cited.
13. Mint-at-settlement auction winners provably receive exactly the
    committed work: the artwork commitment binds at creation and
    settlement re-verifies it onchain.
14. Owner-held tokens enter custody only under owner custody grants,
    revocable until sale, and consigned previously-delivered tokens
    settle as declared secondary transfers with royalty itemization,
    never as primary revenue.
15. Adapter escrow satisfies the per-asset conservation invariant with
    per-sale isolation; forced and direct value never enters credits or
    revenue and is recoverable only above tracked liabilities; owed
    funds are exportable through the `STATE_EXPORT` sale-credit leaves.
16. A contested-attribution collection stops selling — entries revert,
    new sales refuse configuration — while every owed-funds surface
    stays live, and public escrow-mode buyers purchase at price with no
    typed signature under the standing drift envelope.
17. The pattern coverage matrix answers pattern, status, mechanism,
    and genesis substitute from one table, with every `SaleKind`
    value, extension profile, recipe, and exclusion item in exactly
    one row (ADR 0014 decision V5).
