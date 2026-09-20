# Actual Artist curated mint acceptance

## Status and scope

Source-authored and independently source-reviewed on integration base
`da44e59403af57621d383cd460a3f83cf912f510`, 20 September 2026.
The seven new cases pass the combined Solidity ABI/type check. Native execution,
runtime size verification and gas acceptance remain pending the coordinated
matched-source freeze. This note is not a runtime pass or deployment-readiness
claim.

This batch adds new tests and helpers only. It does not alter production
contracts, shared deployment fixtures, gas profiles or release artifacts.

| Manager entrypoint | Actual product | Authored cases |
| --- | --- | --- |
| `executePreparedNativeContentMint` | Original native English auction and original auction content gate | 3 |
| `executePreparedNativeContentPurchaseMint` | Separate original curated fixed-price and private-sale products, each with its original curated content gate | 4 |

The helpers reuse the existing
[actual commerce fixture](../test/helpers/CurrentDynamicRoyaltyCommerceFixture.sol).
Core, Artist authority, Manager, Ledger, Registry, governance, recorder, revenue
resolver, split-wallet factory, wallet, escrow and entropy coordinator are real
current contracts. Original artifact construction and production-instance size
assertions are retained. Only the external entropy provider is a service double.
The additional fault boundaries are stated below.

## Authority and construction

- Artist, sale owner/poster, seller/payer, buyer/executor and Governor are
  distinct official threshold Safe addresses. Shared fixture owner keys do not
  make their Safe transaction or SafeMessage domains interchangeable.
- Collection sale-consent scope is `REQUIRED`. Actual Artist-Safe calls record
  phase-policy consent and operation-16 sale consent. Original auction creation
  signatures and private seller signatures remain separately required.
- The Governor Safe admits each exact gate/product through the real Registry.
  Manager phase configuration and executor admission each follow the real
  governance delay and use the corresponding Artist-approved policy hash.
- Each content gate retains the complete original two-row manifest. The tests
  check its chain, Manager, product, sale, collection, phase, root, byte hash and
  counter identity. Content ID zero with empty token bytes is a valid row.
- A `CONTEXT` counter limits each published content identity to one mint. Sale
  creation identity remains separate from each purchase or winner execution.

The new purchase products use the same construction envelope as the existing
actual native commerce fixture: ERC-1271 allowance/floor `400000/350000`, Artist
read `600000/50000`, reveal attempt `200000/50000`, NFT delivery `300000/100000`,
all class 2. Default delegation is unset. Products retain the permanent
`IStreamPreparedNativeSaleBinding` interface, native prepared-sale module type
and version, and Registry module allowance `500000`. Each gate is separately
admitted with allowance `800000`. These fixture inputs do not establish cold
gas sufficiency or replace the full candidate's measured acceptance.

## Purchase cases

[Purchase tests](../test/current/StreamCurrentArtistCuratedPurchase.t.sol) and
[purchase helper](../test/helpers/CurrentArtistCuratedPurchaseFixture.sol):

1. Missing actual Artist sale consent rejects a funded Buyer-Safe call without
   consuming its nonce or purchase. Recording the exact consent enables the
   byte-identical signed call. Two different published works then produce two
   token identities, counter debits and official receipts under one original
   sale; buyer excess is pulled separately and the actual entropy coordinator
   completes a reveal.
2. A deliberately rejecting external ERC-721 recipient causes failure after
   the real official payment receipt, reveal fee and refund credit were reached.
   Post-revert reads show no mint, counter, root, authorization, payment or credit
   consumption. Accepting delivery enables the identical signed Safe transaction
   with the same operation, authorization and settlement identities.
3. Commit/reveal keeps the original paid deposit, committed block, purchase
   identity and liability after the same late recipient failure. The identical
   signed reveal succeeds after delivery repair, consumes the original deposit
   once and funds only the live reveal fee. Terminal replay cannot pay again.
4. Private purchase rejects raw owner signatures, the Artist Safe's otherwise
   same-owner envelope, altered signed content and a different signed executor.
   The original seller-SafeMessage proof and exact Buyer-Safe call succeed once.
   The full original sale authorization type/domain is independently rebuilt.

Reverted trace logs are used only to locate late failure and recover attempted
identities. Committed receipts are read from separate successful-transaction
logs and durable protocol state.

## Auction cases

[Auction tests](../test/current/StreamCurrentArtistCuratedAuction.t.sol) and
[auction helper](../test/helpers/CurrentArtistCuratedAuctionFixture.sol):

1. Actual Artist sale consent repairs the identical funded Collector-Safe bid.
   A different Safe may settle while the original winner's payer, executor and
   recipient remain bound. Empty published content mints, reveals and routes
   the actual Artist share through the original PROFILE wallet.
2. A creation signature from another same-owner Safe and an unpublished proof
   sibling each fail without consuming sale identity. The original Artist
   signature and selection then register and settle normally.
3. A seller/payer Safe signs the original bid while a distinct Buyer Safe funds
   its executor call. A narrow `mockCallRevert` on the exact native wallet
   deposit, combined with actual governance removing recorder escrow admission,
   forces a late payment failure. Actual governance repairs admission while the
   same deposit fault remains. The identical signed settlement succeeds through
   real escrow; removing the fault permits a real escrow flush. This is injected
   failure coverage, not a naturally failing wallet or cold-gas measurement.

Auction checks independently reconstruct the original signature domains,
complete mint/content facts, winner intent, context counter key and all twelve
official settlement-result fields. Root, authorization, settlement and sale
replay stores must agree. Both governance delays fit the original seven-day
settlement horizon; an expired bid-signing deadline is not reused as new bid
authority during settlement.

## Validation record and remaining work

The combined ABI-only capture is retained locally at
`artifacts/native-assembly/counter-scopes/artist-curated-combined-abi-3`.
It contains 1,161 recursively resolved sources and seven test functions, with
zero compiler errors. Settings: Solidity 0.8.19, via IR, optimizer 200, Paris,
no CBOR and no bytecode metadata hash. ABI-only compilation does not generate
or execute production/test bytecode.

The first two combined captures retain the import-collision and missing-import
diagnostics; both were corrected in these new helpers. No production source was
changed to make a test compile. Final capture hashes and exact source comparison
are recorded in the local `result.json` beside the compiler input/output.

Native acceptance must use the integrated original artifacts and verify these
seven cases with all size checks enabled. No parallel broad compiler or duplicate
full 37-role candidate has been started by this task. Testing owns candidate
assembly; the coordinator owns the combined native schedule and release claims.
Actual-Artist native/ERC20 primary-offer joins remain the next mint coverage
batch.
