# Actual Artist primary-offer acceptance

## Status

Seven source-authored cases join the remaining native and ERC20 primary-offer
Manager entrypoints to the actual Artist graph. This batch is based on current
integration `6398d8b819932d19fe5140bbf70568b1e27bafa4`, 20 September 2026.
Independent source review and ABI/type compilation pass. Native execution,
production/test bytecode generation, runtime size checks and gas acceptance
remain pending the coordinated matched-source freeze.

This batch adds two helpers, two test files and this note. Production contracts,
shared fixtures, candidate assembly and release artifacts are unchanged.

| Entrypoint | Original product | Authored cases |
| --- | --- | --- |
| `executePreparedNativeOfferMint` | `StreamNativePrimaryOfferSale`, optional original native offer content gate, prepared recorder | 3 |
| `executeERC20OfferMint` | `StreamERC20PrimaryOfferSale`, optional original ERC20 offer gate, original sole-puller payment adapter and recorder | 4 |

Together with the
[curated cases](MINT_CURATED_CURRENT_ACCEPTANCE.md), these supply actual-Artist
source recipes for the four gaps identified in the
[mint entrypoint map](MINT_CURRENT_ACCEPTANCE.md). They do not turn authored
coverage into a native pass or complete the full 37-role candidate's acceptance.

## Common construction and authority

Both helpers extend the unchanged
[actual commerce fixture](../test/helpers/CurrentDynamicRoyaltyCommerceFixture.sol).
The original Core, Artist suite, Manager, Ledger, Registry, Governor Safe,
recorder, resolver, factory, PROFILE wallet, escrow and entropy coordinator
remain intact. New products use original artifact construction and retain the
production-instance runtime-size assertions for eventual native execution.

Artist, owner/poster, seller, buyer and Governor are distinct threshold Safe
addresses. Seller and buyer authorizations use their original SafeMessage
domains; funded execution uses the Safe transaction domain. Actual Artist-Safe
calls record phase consent and required operation-16 sale consent with fresh
onchain authorization nonces. Registry admission and both Manager phase
transitions use actual delayed Governor-Safe governance.

Selected offers retain a complete one-row manifest containing valid content ID
zero and empty bytes, with a cap-one context counter. Collection offers retain
raw signed artwork, no invented content leaf/gate and an ordinary recipient
counter. The full seller authorization and buyer offer EIP-712 preimages are
independently reconstructed. Seller consumption stays in the sale adapter;
the buyer's original offer digest, wrapped by the ticket authorization domain,
stays in the canonical Manager-scoped Ledger.

The additional product gas inputs match the actual commerce fixture's existing
envelope: ERC-1271 `400000/350000`, Artist read `600000/50000`, reveal attempt
`200000/50000`, and native delivery `300000/100000`, all class 2. Gates are
separately admitted with allowance `800000`; product Registry allowance is
`500000`. No fixture allowance is presented as a measured cold-gas result.

## Native offer cases

[Native helper](../test/helpers/CurrentArtistNativeOfferFixture.sol) and
[native tests](../test/current/StreamCurrentArtistNativeOffer.t.sol):

1. Missing actual Artist sale consent rejects the complete funded Buyer-Safe
   transaction. Recording the original consent permits the byte-identical
   signed call. The selected token, exact official receipt, buyer excess refund,
   actual entropy reveal and Artist PROFILE withdrawal preserve their original
   identities and accounting. Terminal replay cannot mint or pay again.
2. A collection offer rejects raw owner signatures, wrong same-owner Safe
   domains and altered artwork. The original seller and buyer proofs then mint
   the signed raw bytes without a content reservation.
3. A narrow injected failure of the exact native wallet-deposit call, together
   with actual governance removing recorder escrow admission, forces late
   settlement failure. Original seller consumption, buyer Ledger key, root,
   prepared token, receipt, fee and credit all roll back. Real governance repairs
   escrow admission within the original seven-day terms. The identical signed
   Buyer-Safe call succeeds through real escrow while the deposit fault remains;
   removing that fault permits the actual escrow flush and excess refund.

The native helper independently checks full prepared intent, facts, selected or
collection content facts, original purchase tuple, candidate and all twelve
official result fields. It also checks exact seller-consumption, offer-acceptance
and offer-specific receipt events. The host retains permanent
`NATIVE_PREPARED_SALE_ADAPTER` / `6529STREAM_PREPARED_NATIVE_SETTLEMENT_V1`
admission, explicitly read through the actual admission library after governance.

## ERC20 offer cases

[ERC20 helper](../test/helpers/CurrentArtistERC20OfferFixture.sol) and
[ERC20 tests](../test/current/StreamCurrentArtistERC20Offer.t.sol):

1. A selected offer requires actual Artist sale consent and the original seller
   and buyer SafeMessage proofs. Raw signatures, another same-owner Safe and
   unpublished artwork fail. The Buyer Safe approves the original payment
   adapter and calls it directly; the actual token mint, receipt, entropy reveal
   and terminal replay checks retain the original selected identity.
2. A collection offer's complete signed Buyer-Safe payment call fails if the
   real entropy policy's future reveal fee becomes nonzero. The genuinely
   activated entropy administrator restores zero; the identical call succeeds
   with the original raw artwork and ordinary recipient counter.
3. The Buyer Safe grants the owner/poster Safe execution authority through the
   original NFTDelegation contract. That distinct executor still cannot use the
   payer-only entrypoint or authorize spending with its own PaymentIntent proof.
   The original Buyer-Safe PaymentIntent is independently domain-checked. An
   explicit receiver-call fault at the Buyer Safe then forces failure after
   real payment recording. Removing only that fault permits the identical signed
   executor-Safe transaction, using the same seller proof, buyer proof, payer
   intent, execution commitment and replay identities.
4. An actual Buyer-Safe call voids the original offer key in Ledger. The original
   acceptance then fails without consuming the seller digest, mint identity,
   counter, token balance or allowance.

The ERC20 token is an explicit external asset fixture. The actual asset-policy
registry admits it through Governor-Safe governance. The inherited, genuinely
activated entropy administrator updates the live reveal fee to zero; no authority
is impersonated. The original NFTDelegation runtime is constructed with its
immutable manifest pinned to the sale's actual Registry admission, use case 2
and class-2 allowance/floor `150000/50000`.

Late receiver fault injection matches only `onERC721Received` at the original
Buyer Safe, leaving its original ERC-1271 signatures and transaction execution
intact. Post-failure checks include all three authorization stores, Ledger root
and counter, Core allocation, execution status, official receipt, payment phase,
token transfer count, balances and finite allowance. Successful settlement checks
all twelve result fields, three original token transfers and no retained token
custody in the payment adapter, recorder or sale.

## Validation boundary

The final ABI-only capture is local at
`artifacts/native-assembly/counter-scopes/artist-offer-combined-abi-final`.
It checks 1,178 recursively resolved sources and seven test functions with zero
compiler errors. Solidity settings remain 0.8.19, via IR, optimizer 200, Paris,
no CBOR and no bytecode metadata hash. Exact input/output hashes, source
comparison and test inventory are retained in its `result.json`.

Preliminary captures retain import-collision/missing-import diagnostics. Source
review also corrected the new native helper's initially mismatched admission
constants before handoff. No production implementation was changed to accommodate
these tests. Formatter, Windows-aware whitespace, documentation-link tests,
link validation and changelog checks are recorded with the batch.

Reverted trace events locate late failure and identify attempted operations;
they are not committed receipts. Successful-transaction logs and durable state
are checked separately. The wallet/receiver faults are explicit test injections,
not claims about naturally failing wallets or measured cold execution.

Testing owns full candidate composition and the coordinator owns native freeze,
combined acceptance and release decisions. No broad native compiler or duplicate
candidate was launched for this source batch.
