# Native secondary private offers and custody authorization

Status: implementation decision authorized by the integrator on 12 September
2026. Source is integrated with 42 independently reviewed domain tests and
fuzzing; both production compiler profiles fit the runtime limit. Actual-current
Core/royalty composition, full sales conformance and release acceptance remain
separate requirements.

This increment implements buyer-bound `PRIVATE_SALE` (5) and atomic `OFFER_SALE`
(6) over previously delivered Core tokens. It follows SSA-PRIVATE, SSA-OFFER,
SSA-CUSTODY-ENTRY and SSA-CONSIGN in the [sales specification](../stream-sales-and-auctions.md).
It does not introduce a consignment kind. An open inventory listing remains
`CUSTODY_INVENTORY_FIXED_PRICE` (14), outside this increment.

The sale configuration explicitly declares secondary treatment and binds
`expectedPrimaryPolicyHash = 0`. The declaration remains subject to the
transfer-history conformance gate: current owner, collection identity and
`MINTED` lifecycle do not alone prove prior collector delivery. Actual current
rehearsals must first deliver the token to its collector before consigning it.
The transfer executes through Core's sole ERC-721 path. No Manager execution,
primary policy resolution, official revenue receipt, payment-adapter callback
or reveal request occurs. The artist primary sale/economics consent surfaces do
not authorize or restrict this secondary transfer; current Core royalties are
the relevant economic policy.

## Exact signature and configuration authority

All six signature families use the permanent type strings and the domain
`6529Stream Sales`, version `1`, current chain and verifying adapter. The adapter
exposes that domain through ERC-5267. EOA kind 1 and ERC-1271 kind 2 are explicit
presentation fields. EOA recovery never infers its kind from code presence;
ERC-1271 validates exactly the claimed account with the current governed cap.
The three revocation calls present their full original typed payload and either
come directly from its authenticated principal or carry the corresponding
family-specific revocation signature. No bare-digest revocation or
digest-to-signer ownership shortcut exists.

The deployment manifest names the configuration owner and the immutable
platform signer. This is an explicit delegation of collection sale-configuration
authority to that owner. Only that owner may record each collection's signer
authorization; mere module registration is insufficient. Each authorization
records its configuring authority address, evidence commitment, enabled state
and monotonic revision. A registered sale permanently binds the signer,
authority, evidence and revision that admitted it. Subsequent ownership changes,
disablement or replacement of the collection configuration cannot change the
signer set of an existing immutable sale. The current owner may cancel an
unexecuted sale; it cannot seize custody or claim another account's credit.
Custody independently requires the actual token owner's full grant or direct
owner deposit. The platform/configuration owner cannot substitute for it.

The canonical `SaleAuthorization` contains mint fields that have no active mint
meaning on this branch. Their accepted values are explicit and validated:

| Field | Secondary custody value |
| --- | --- |
| `chainId`, `saleAdapter` | Current chain and this adapter |
| `saleId`, `saleKind`, `collectionId` | Exact registered immutable sale |
| `mintManager`, `phaseId`, `policyHash` | Zero; no Manager request exists |
| `revenueClass`, `expectedPrimaryPolicyHash`, `primaryPolicyMode` | Zero; no primary settlement exists |
| `initialRecipientsHash`, `beneficiariesHash` | Canonical ABI-encoded one-address array containing the bound buyer |
| `tokenDataArrayHash` | Hash of the ABI-encoded empty `bytes[]` |
| `mintCommitmentsHash` | Hash of the ABI-encoded empty `bytes32[]` |
| `payer`, `executor` | Bound buyer in this buyer-called native profile |
| `asset`, `contentSelectionHash`, `finalizeBy` | Zero |
| `unitPrice`, `quantity` | Exact configured positive price and one |
| `deadline` | Nonzero signed deadline, no later than the configured absolute expiry |
| `nonce` | Exact opaque nonce in the signed and permanently consumed digest |

The sale configuration binds the actual token ID omitted from this signature
schema; the offer and custody grant also independently bind Core and token.
Inactive fields are checked, never ignored. A private grant references the sale
ID. An offer grant references the full offer digest. Offer acceptance verifies
both signatures and consumes both full digests before custody entry; the grant
uses the same append-only consumed-digest store. Revocation of any one proof
cannot be overcome by a freshly signed opposite-side proof.

The module declares its own `PRIVATE_SALE_ADAPTER` role and native-consignment
version/capability. Registration requires ACTIVE canonical registry admission.
Existing sales retain the ordinary creation-time revision/timestamp rule for
DEPRECATED modules; UNKNOWN, INCIDENT, wrong code and malformed records reject
new custody/payment operations. Claims, revocation and expiry do not read the
module registry. Global/per-sale guardian pause stops new custody/payment and
uses the disjoint unpause role. It cannot stop claims or expiry. These atomic
private/offer deadlines are signed absolute expiries; this branch has no live
bidding, refund or deferred-finalization window to toll.

## Royalty and delivery accounting

Before purchase, `royaltyQuote` returns Core's current receiver/amount for the
exact configured token and price, plus secondary-treatment and external-market
royalty disclosure flags. Settled records return their immutable royalty
snapshot. Outside this consignment rail, royalties remain disclosure-only on
external marketplaces; this rail itself attempts the saved payment.

Execution verifies custody/value, marks sold, records the original authorization,
then obtains the exact 64-byte Core royalty result. A positive royalty requires
a nonzero canonical receiver and amount no greater than price. Missing or
malformed quotes revert before completed settlement. Consignor proceeds and
buyer excess become distinct per-sale pull-credit buckets. A bounded royalty
delivery failure creates only the saved receiver's royalty bucket. NFT delivery
then attempts Core's safe transfer, recording a buyer claim on admitted failure.
Claims never cause another sale or repeat its royalty assessment.

`claimRefund` pays the caller's entire per-sale credit and clears every included
bucket before transfer. Permissionless royalty retry debits only the saved
royalty bucket and targets only its saved receiver. The two routes remain exact
when buyer, consignor and royalty receiver coincide. Direct NFT beneficiaries
may select a receiver; permissionless retries target only the saved beneficiary.
Unsold custody belongs to its original consignor, never the configuration owner.
SSA-CUSTODY-ENTRY rule 4 says "releasing to the owner only" in its revocation
rule. This decision distinguishes that relayed release authority from a later
direct pull: a relayed revocation or permissionless retry can target only the
original owner; the owner may separately authorize a direct pull to another
receiver. This preserves recovery for owners whose receiver rejects safe NFTs
without allowing a relayer to choose their destination.
All consumer mutations share the reentrancy guard; canonical governed gas raises
retain the separate host authority checks.

The new host row `SALE_ROYALTY_DELIVERY_GAS_LIMIT` is distinct from signature and
NFT limits. Its identifier is `keccak256("6529STREAM_GGP_SALE_ROYALTY_DELIVERY_GAS_LIMIT")`.
It uses `FAIL_CLOSED_PRECHECK` class 2, an immutable floor and the ordinary
governed delayed monotonic raise mechanism. Whole parent-gas admission includes
EIP-150 and bookkeeping reserve; value-call stipend is included in the forwarded
cap. Failed admitted delivery is caught. Insufficient parent gas reverts the
whole operation, including custody, proof consumption and money. The current
100,000 candidate and 30,000 floor are planning fixture inputs pending measured
recipient/actual-Core sizing and catalog/manifest integration. The existing
`SALE_ERC1271_GAS_LIMIT` and `SALE_NFT_DELIVERY_GAS_LIMIT` remain separate rows.
Core and canonical registry reads use fixed output buffers with available gas
under their immutable code pins; Core retains its own royalty resolver gas
policy. No arbitrary royalty provider or unbounded copied return data is added.

Primary mint offers still require the separately reviewed same-key
Manager/Ledger revocation surface. ERC-20 consignment, live delegate execution
and `claimRefundFor`, open inventory, surplus sweep and state-export integration
remain explicit follow-ups. Their absence is not implied conformance through
this bounded native secondary path.
