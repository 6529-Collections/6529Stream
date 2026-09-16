# ERC20 primary mint offers

`StreamERC20PrimaryOfferSale` accepts the original full buyer `SaleOffer` and
seller `SaleAuthorization` for one new token, using atomic `OFFER_SALE` (kind 6).
The buyer is the token payer, initial recipient and final beneficiary. Both
collection-level and selected-work offers use `tokenId = 0`.

This is pre-audit source. The delivery ledger records validation against each
captured revision; this guide does not establish deployment or release readiness.

## Supported funding

The sale has a positive price in one ACTIVE ERC20 asset and a collection PROFILE
primary assignment with `STRICT_MATCH` (`primaryPolicyMode = 0`). Both original
signatures require `finalizeBy = 0`. The selected coordinator must declare a
**zero native reveal fee** at admission and execution.

The existing `StreamERC20PrimarySettlementAdapter` (contract 20) is the sole
payer authorization and token-pulling boundary. The offer carrier never pulls
tokens or receives standing allowances. Its entry and contract 20's existing
entries are nonpayable. The native-fee allowance design in
[ADR 0045](../adr/0045-native-reveal-fees-for-token-sales.md) remains held and is
not implemented by this offer profile. A nonzero declared native fee fails
before token funding; no token surcharge, conversion, retained ETH balance or
alternate payment route substitutes for that fee.

| Contract 20 route | Required caller and authorization |
| --- | --- |
| `settleERC20PrimarySaleByPayer` | Actual top-level caller is the buyer/payer; the signed sale bounds asset and price |
| `settleERC20PrimarySaleWithIntent` | Buyer's separate original `PaymentIntent`; a nonpayer executor must also be the buyer's live delegate |
| `settleERC20PrimarySaleWithEIP2612Permit` | Buyer/payer calls directly with the existing exact-amount permit |
| `settleERC20PrimarySaleWithPermit2` | Buyer/payer calls directly through the existing pinned Permit2 route |

Only `payer == msg.sender` in contract 20's own call frame qualifies for the
direct-caller exemption. A call to the offer carrier cannot create that fact.
A delegate-signed offer grants offer-signing authority; it cannot spend the
buyer's allowance. Every nonpayer executor uses the buyer's own PaymentIntent
signature, including an ERC-1271 signature when the buyer is a Safe.

The PaymentIntent keeps its original type and domain:
`6529StreamPaymentIntentVerifier`, version `1`, chain ID and the actual contract
20 address. `payer` is the buyer, `asset` is the configured token, `maxAmount`
bounds the price, `saleRef` is the original `saleId`, and
`expectedPrimaryPolicyHash` matches the sale. Nonce and deadline remain
payer-owned. A SaleOffer signature never substitutes for these fields.

## Setup and content

1. Deploy and link the carrier against the current Manager, official recorder,
   Artist facade, governance RoleRegistry and revenue graph. Configure the
   governed sale-signature, Artist-read and reveal-attempt gas rows. Optional
   delegation pins the NFTDelegation registry, runtime and usecase in the
   carrier's module manifest.
2. Register the carrier's existing universal payment transport capability:
   `FIXED_PRICE_SALE_ADAPTER`, `IStreamERC20SaleExecution`, version
   `6529STREAM_UNIVERSAL_SETTLEMENT_V1`. Contract 20 keeps its existing registry
   admission. The Manager must expose the new `IStreamERC20OfferMint` capability.
3. Configure an explicit collection seller using `configureCollectionSigner`.
   Record its address, explicit kind, evidence hash, revision and configuring
   authority in the immutable `Configuration`.
4. Predict `saleIdFor(collectionId, phaseId, nextSaleNonce())`. Configure a phase
   with the carrier as executor and a singleton batch. Its time bounds must
   contain the nominal sale window.
5. Prepare the selected or collection branch, sign the original buyer offer,
   and include its full EIP-712 digest in `Configuration.offerDigest`.
   Register with `registerPrimaryOffer(config, selectedProof)` before `startsAt`.
   Obtain required Artist consent over the exact sale ID/configuration hash.

For a collection-level offer, the manifest root, configured content ID and
configured token-data hash are zero. Registration proof and the acceptance's
entire `selection.content` are empty/zero. The phase has a genuinely zero gate
configuration. The seller still binds the exact raw token-data array and mint
commitment. The ordinary nonzero batch context is the full seller authorization
digest; no content identity or selected-work counter is invented.

For a selected work, deploy the dedicated `StreamERC20OfferGate` and
publish the complete sorted content manifest. Pin its original leaf, root,
gate code/configuration and enabled CONTEXT/static/static cap-one counter.
Both signatures bind the same original content leaf. Acceptance supplies the
selected raw bytes and proof; the Manager verifies their correspondence and
consumes the original content context. Original content leaf/context domains
and sequential token allocation remain unchanged. The ordinary gate entry
rejects this profile; the dedicated offer path requires its settlement receipt.

## Signing and transaction preparation

Both sale signatures use `6529Stream Sales`, version `1`, chain ID and this
carrier address. Use the permanent `StreamPrivateSaleTypes.SaleOffer` and
`SaleAuthorization` fields unchanged. Explicit kind 1 selects ECDSA; kind 2
selects bounded ERC-1271. Code presence does not choose a signature family.

Construct `Acceptance` with both complete payloads and claimed signature
records, nested content/raw-data/mint-commitment selection, the next execution
nonce, and separate offer-signer/executor delegation witnesses. The seller
binds singleton initial recipients and beneficiaries to the buyer, the exact
raw token-data/mint-commitment arrays, asset, price, phase, sale ID, policies,
content selection and actual top-level executor. Both signature deadlines and
the sale window must remain valid; the seller deadline cannot exceed sale end.

Call `previewExecution(acceptance)` to obtain the original
`ERC20SettlementCandidate`. Encode the same acceptance canonically with
`abi.encode(acceptance)` and pass both to the chosen contract 20 route. A changed
operation nonce, policy, gate or other bound state can invalidate the preview;
recompute it before submitting a fresh transaction.

The carrier uses the existing order-one `PRE_REVENUE_SINGLE_STEP` candidate,
execution and settlement domains. Its execution nonce is monotonic per
`(saleId, buyer)`. This atomic sale creates no escrow-holding purchase record
and no alternate `purchaseId`.

## Atomic execution and replay

The carrier consumes the full seller digest before its first outbound call.
It validates original signatures, live delegates, immutable sale terms,
Artist consent, asset policy, primary rights, exact content and the Manager's
mint preview before invoking the recorder. Contract 20 authenticates payment
separately and performs the exact token pull only during that recorder call.

The Manager checks the official recorder's exact stored ERC20 receipt and
candidate, then consumes the offer's original TICKET key and mints to the buyer.
The carrier checks the returned operation root and token operation ID. A zero-fee
`AT_MINT` entropy request uses the existing bounded attempt; provider request
failure is evented and does not undo the purchase. Invalid settlement, mint or
NFT receipt reverts the entire transaction, including payment intent, permits,
allowances, token transfers, revenue and both offer replay stores.

| Fact | Durable owner | Key |
| --- | --- | --- |
| Buyer offer | Manager/Ledger | Original TICKET wrapping of the full offer EIP-712 digest |
| Seller authorization | Carrier | Full seller authorization EIP-712 digest |
| Signed token payment | Contract 20 | Original `(payer, nonce)` |
| Official revenue | Recorder | Existing universal settlement key for the execution |

Buyers revoke through Manager's existing full-payload `voidMintOffer`, using a
direct buyer call or the original `MintTicketRevocation` family. Sellers use
`revokeAuthorization(fullAuthorization, claimedSignerProof)`: the historical
admitted signer calls directly or signs the original
`SaleAuthorizationRevocation` family. Historical seller membership remains
readable after cancellation, expiry or disablement, and revocation needs no live
Artist, phase, module, payment or reveal provider. PaymentIntent revocation
remains contract 20's payer-owned operation. These three revocation surfaces are
independent; an ordinary offer or authorization signature cannot replace a
revocation signature.

Safe calls use ordinary CALL with zero native value. A Safe buyer approves
contract 20 and executes its direct funding call, or supplies its valid ERC-1271
PaymentIntent to a live delegated executor. A Safe seller signs the full Sales
payload and may directly revoke it. Failed transactions preserve the exact
unconsumed authorization payload for retry after the failed dependency is repaired.
