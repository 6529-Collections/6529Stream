# Native primary mint offers

`StreamNativePrimaryOfferSale` accepts a buyer's original `SaleOffer` and a
matching seller `SaleAuthorization` for one new token. This additive carrier
implements native, positive-price, atomic `OFFER_SALE` (kind 6). Both
collection-level offers and offers for a selected unminted work use `tokenId = 0`.
Existing custody offers and kind-5 private sales retain their own entry points.

This is pre-audit source. The delivery ledger records validation for each
captured revision; source, ABI checks and focused proof tests do not establish
current-stack runtime, deployment or release readiness.

## Profile and setup

The primary assignment must be a collection PROFILE with `STRICT_MATCH`
(`primaryPolicyMode = 0`). The immutable sale has one buyer, one positive native
price, one original offer digest, a nominal start/end window and a historical
seller membership record. Both signatures require `finalizeBy = 0`; there is
no escrowed-offer or deferred finalization path. ERC20 offers use the separate
[ERC20 primary-offer carrier](erc20-primary-offers.md) and payer-intent boundary.

1. Deploy and link the carrier and its fixed libraries against the actual
   Manager, recorder, Artist facade, governance RoleRegistry and revenue graph.
   Use the same four governed gas rows as the
   [native selected-work carriers](native-curated-selected-sales.md).
   Optional delegation uses the pinned NFTDelegation deployment declaration.
2. Admit the carrier under the prepared native sale role and configure its
   collection phase with the carrier as executor and batch limit one.
3. Predict `saleIdFor(6, collectionId, phaseId, nextSaleNonce())`. Configure an
   explicit collection seller using `configureCollectionSigner`. Copy that
   signer's address, kind, evidence hash, revision and admitting authority into
   the immutable offer configuration.
4. Prepare the branch described below, then build the full buyer offer under
   this carrier's original Sales domain. Store its full EIP-712 digest in
   `Configuration.offerDigest`. It is not a nonce-only or struct-body hash.
5. Call `registerPrimaryOffer(config, selectedProof)` before `startsAt`.
   The finite phase must contain the nominal sale window. Obtain the Artist's
   consent for the resulting sale ID and exact configuration hash before
   attempting acceptance.

### Collection-level offers

Set `contentManifestRoot`, configured `contentId` and configured `tokenDataHash`
to zero, with no registration proof and genuinely no phase gate. Set both
signed `contentSelectionHash` fields to zero. The acceptance's nested
`selection.content` is entirely zero/empty.

The seller still signs the exact raw token bytes and mint commitment through
the permanent batch-array hashes. No content manifest, artwork leaf,
reservation or serial choice is fabricated. The Manager derives its ordinary
prepared mint context from Manager, carrier and intent hash; this execution
context is distinct from a selected artwork's content context.

### Selected unminted work

Deploy and admit `StreamNativePrimaryOfferGate` for the predicted sale, phase
and carrier, publishing every sorted `(contentId, tokenDataHash, previewURI)`
manifest row. Its explicit offer capability and gate config domain are
`6529STREAM_NATIVE_PRIMARY_OFFER_GATE_V1`; a kind-5 content-purchase gate cannot
substitute for it.

Configure the enabled CONTEXT/static/static counter with cap one and increment
one. Pin the published root and selected content ID/hash in the offer
configuration. Both signatures bind the original double-hashed content leaf;
acceptance supplies its proof and raw bytes with the declared hash. The
original leaf and context domains are unchanged. Ledger consumption prevents a
second mint of the same content within that sale context. Serial allocation
remains sequential.

## Signing and acceptance

The domain is `6529Stream Sales`, version `1`, the current chain and this
carrier's address. `eip712Domain()` exposes it. Use the permanent full
`StreamPrivateSaleTypes.SaleOffer` and `SaleAuthorization` types unchanged.

`acceptPrimaryOffer(Acceptance)` presents both full payloads, both explicit
`Signature` records, token selection/data, a purchase nonce and separate
delegation witnesses for offer signing and transaction execution.

- The buyer signs the offer, or an explicitly named live delegate signs it.
  Kind 1 means ECDSA; kind 2 means bounded ERC-1271. Code presence never chooses
  the signature family.
- The admitted seller countersigns matching collection, buyer, asset, positive
  price and content selection, plus the actual phase, sale ID, policies, batch
  hashes and executor. The initial recipient is the carrier; the economic
  beneficiary and final NFT recipient are the buyer.
- Only the buyer or a live delegate executes. `authorization.executor` must
  equal that actual caller, and that caller supplies all native `msg.value`.
  A signature cannot withdraw ETH from another account. Delegation is checked
  live and retained across the external execution boundaries.
- Acceptance must satisfy both signature deadlines and the sale window.
  The seller deadline cannot extend the immutable sale end.
- Supply price plus a maximum reveal-fee allowance. The live fee is funded
  after official settlement; excess becomes the original buyer's pull credit,
  including when a delegate supplied the transaction value. The buyer claims
  to its chosen recipient; a delegate may trigger delivery only to the buyer.

The carrier verifies both signatures, then uses the explicit
`executePreparedNativeOfferMint` Manager entry. Manager allocates and prepares
the actual token, consumes the offer key and configured counters, and invokes
the exact active offer callback. The official recorder validates those active
facts before receiving native proceeds. The token completes, reveal funding is
reconciled and bounded final delivery goes to the buyer. A failed final NFT
delivery reverts the entire acceptance; the same valid payload can be retried.

## Replay and historical revocation

| Fact | Durable store | Exact key |
| --- | --- | --- |
| Buyer offer | Manager's Ledger lane | `TICKET_AUTHORIZATION_DOMAIN` wrapping the full original offer EIP-712 digest |
| Seller authorization | Carrier `digestConsumed` | Full original seller authorization EIP-712 digest |
| Recorded purchase | Official native recorder | Carrier and original purchase ID |

The carrier marks the seller digest and emits `SaleAuthorizationConsumed`
before any outbound call, including signature checks. All validation failures
revert that write and event. Manager consumes the offer key in the same
transaction; neither digest is combined with or substituted for the other.
A fresh seller nonce cannot revive a consumed or voided offer.

Buyers revoke with Manager's existing full-payload `voidMintOffer`, which uses
the exact same ticket-wrapped offer digest. A direct buyer call or the original
`MintTicketRevocation` signing path works independently of the carrier's live
status. See [ADR 0037](../adr/0037-full-payload-mint-authorization-revocation.md).
The custody-path `SaleOfferRevocation` signature is not this mint revocation.

Sellers revoke with the carrier's `revokeAuthorization(fullAuthorization,
claimedSignerProof)`. The direct historical signer may call, including an
actual Safe. A relayer needs that signer's signature over the original
`SaleAuthorizationRevocation(chainId,saleAdapter,authorizer,authorizationDigest)`
under the Sales domain. An ordinary sale signature is insufficient.

`primaryOfferAuthorizationBinding(saleId)` retains the original collection,
phase, signer, explicit kind and configuration hash after expiry, cancellation
or signer disablement. Seller revocation reads this historical configuration;
it does not require live Artist consent, an active phase, current signer
membership, module admission or a working payment/reveal provider. Revocation
sets the same consumed store and `digestRevoked`, then emits
`SaleAuthorizationRevoked`. A consumed digest cannot be revoked again.

## Reads and recovery

Use `primaryOfferConfiguration`, `saleRecord`, `executionRecord`,
`nextPurchaseNonce`, `digestConsumed`, `digestRevoked`, `refundableBalance` and
`refundLiability` for transaction preparation and indexing. Active prepared
offer getters are callback evidence and reject outside the current operation.

Global/sale pause and collection contest synchronization share the existing
guarded sale controls. `cancelSale` and `expirePrimaryOffer` prevent future
acceptance. Earned credits remain claimable after those transitions and after
provider failure. Forced native surplus is separate from buyer liabilities and
uses the existing governed recovery boundary.
