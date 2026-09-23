# Current native primary offer workflow

`current-primary-offer.ts` prepares and checks the native primary
`OFFER_SALE` workflow from frozen carrier source
`6d69483cc7eeee748271f531821ed2bf7643a787`. It produces unsigned calls and
performs bounded reads or `eth_call` simulations. It does not sign, send,
deploy, establish canonical deployment identity, or prove future transaction
inclusion.

Use the [primary offer signing helpers](current-primary-offer-signing.md) for
the exact buyer and seller payloads. A selected offer also uses the
[selected-work offer content helpers](current-primary-offer-content.md).

## Roles and replay identities

Keep these addresses distinct in the operator record:

| Role | Meaning |
| --- | --- |
| carrier owner | Configures a collection signer and registers the sale. |
| buyer | Owns the permanent 12-field `SaleOffer`, the Manager TICKET and any excess refund. |
| buyer authorizer | The buyer or a currently admitted delegate that signs the offer. |
| collection signer | The registration-pinned seller signer that signs the 24-field `SaleAuthorization`. |
| executor | The authorization's actual caller; funds the full native call. |

`kind = 1` means ECDSA and `kind = 2` means ERC-1271. Code presence does not
select a kind. For ERC-1271, obtain the contract wallet's signature artifact
and let exact payable simulation exercise its live validation path. A delegated
buyer signature carries `signerDelegation`; a delegated executor carries the
separate `executorDelegation`. Do not reuse one witness as evidence for the
other role.

The buyer offer becomes a Manager/Ledger TICKET ID. The seller authorization's
EIP-712 digest is stored in the carrier's independent replay mappings. Neither
ID is the sale ID, purchase ID, Manager operation ID, or prepared-native
execution ID.

## 1. Configure the seller signer

Call `preparePrimaryOfferSignerConfiguration` with the current carrier owner,
collection, signer, explicit kind, evidence hash and enabled flag. At a
reviewed numeric block:

1. `inspectPrimaryOfferSignerConfiguration` checks the owner and current row.
2. `simulatePrimaryOfferSignerConfiguration` executes the exact owner CALL by
   `eth_call`.
3. After mining, `readPrimaryOfferCollectionSigner` confirms the new evidence,
   revision, enabled flag and authority.

Record the new revision. Registration pins the signer, kind, evidence,
revision and authority rather than silently following later membership edits.

## 2. Register selected or collection-level terms

Build `PrimaryOfferConfiguration` with a positive native price, a strictly
future `startsAt`, and the permanent buyer and seller-signing coordinates.
`preparePrimaryOfferRegistration` predicts the kind-6 sale ID from the exact
next nonce and returns the owner CALL.

For a selected work, publish the manifest first and pass the proof for the
configured content ID and token-data hash. The nonzero manifest root,
configured content fields and proof must all describe the same leaf.

For a genuinely collection-level offer, set the manifest root, content ID and
configured token-data hash to zero and pass an empty proof. The live phase gate
must also be absent. Do not create a synthetic zero-content manifest. The later
raw token bytes remain part of the signed one-token array even on this path.

Use one concrete block for `inspectPrimaryOfferRegistration` and
`simulatePrimaryOfferRegistration`. They check the owner, next nonce, predicted
sale ID, local/onchain configuration hash, pinned signer, dependencies and
future start. After the registration transaction is confirmed, call
`inspectRegisteredPrimaryOffer` at a new concrete block to verify the stored
immutable record.

## 3. Collect the original two signatures

`primaryOfferSigningSnapshot` reconstructs and cross-checks the complete
packet before signing:

- the buyer's original 12-field `SaleOffer`;
- the seller's original 24-field `SaleAuthorization`;
- the four exact one-token Manager array hashes;
- the selected leaf or the genuine zero selection;
- the buyer TICKET ID and independent seller replay digest.

Both payloads use `6529Stream Sales` version `1`. The seller deadline cannot
exceed the sale end. The buyer deadline may extend beyond it, but acceptance
still requires the live sale window. The carrier accepts at `endsAt` itself;
this boundary is inclusive. Both messages keep `finalizeBy = 0`.

The initial recipient array contains the carrier, while the beneficiary is the
buyer. The native asset and primary-offer token ID are zero. Sign the returned
typed payloads outside the client. Preserve the full messages and proofs for
acceptance and possible historical revocation.

## 4. Inspect and simulate acceptance

Pass the two original messages, their explicit-kind proofs, the full selection,
both delegation witnesses and a `revealFeeAllowance` to
`preparePrimaryOfferAcceptance`. The prepared caller is the seller
authorization's executor. Its native value is exactly:

```text
immutable positive sale price + revealFeeAllowance
```

`inspectPrimaryOfferAcceptance` rereads the stored active sale, signer row,
purchase nonce and ID, both digest getters and replay lanes, historical
authorization binding, original EIP-712 domain, dependencies, inclusive time
windows and live reveal fee at one numeric block. The allowance must cover that
fee. `simulatePrimaryOfferAcceptance` then executes the exact payable call from
the executor and checks the returned buyer, leaf, token bytes hash, mint
commitment, price and operation coordinates.

The executor supplies all attached native value even when it is a delegate.
After the live reveal fee and fixed price are used, any excess is credited to
the immutable buyer. Simulation does not reserve the nonce or balance.

After mining, always run `inspectCompletedPrimaryOffer` at a confirmed numeric
block. It requires the stored sale status and execution record to match, the
Manager buyer TICKET to be consumed, the carrier seller digest to be consumed,
and that seller digest to remain unrevoked. A receipt or one replay read alone
does not establish this dual completion.

## 5. Claim buyer excess

`readPrimaryOfferRefundCredit` reads the credit for the original buyer and
sale. `preparePrimaryOfferRefundClaim` lets that buyer choose a non-carrier
recipient. `preparePrimaryOfferDelegatedRefundClaim` lets an admitted delegate
trigger the claim, but the recipient remains the buyer. These owed-credit calls
do not reapply current offer admission or signing checks.

## 6. Historical revocation

Before acceptance, either permanent authorization can be disabled through its
own replay store:

- `preparePrimaryOfferBuyerRevocation` calls Manager `voidMintOffer` with the
  full original offer. A direct call by the original buyer uses an empty
  revocation signature. A relayer supplies the buyer's original Sales-domain
  `MintTicketRevocation` signature. `buyerKind` remains explicitly ECDSA or
  ERC-1271. A delegated offer signer is not the revocation authority.
- `preparePrimaryOfferSellerRevocation` calls the carrier with the full original
  24-field authorization. The historical configured signer can call directly
  with an empty proof signature; a relayer supplies that signer's original
  Sales-domain `SaleAuthorizationRevocation` proof.

Inspect and simulate the matching prepared revocation at a concrete block.
These paths use the saved historical binding and remain useful after expiry,
pause or changes to current admission. They do not void the other replay lane.

## Safe review

Every prepared call is an ordinary CALL. Convert it with `toSafeCall`; the
result has Safe `operation: 0`. Use `createSafeCallPlan` with the exact target
ABI selected from your compiler output and require the plan's `safe` to equal
the prepared `caller`. The registration and seller-revocation targets use the
carrier ABI; buyer revocation uses the Manager ABI. Do not import a package test
fixture into a runtime application.

Follow the [Safe CALL plan guide](safe-call-plans.md): independently verify the
plan, simulate each target call from the actual Safe, execute through the Safe,
and check the Safe execution result plus protocol readback. A target-level
`eth_call` does not establish Safe owners, threshold, signatures or inclusion.

## Evidence boundary

All inspections require a numeric block number. They do not fetch and bind its
block hash, so callers must apply their own reorg policy. Dependency and runtime
observations are not comparisons with canonical deployed-code hashes. The
helpers validate source-derived encodings, stored facts and synthetic RPC
responses; they do not prove current Artist consent, phase or gate authority,
remaining capacity, signature validity before simulation, or full-stack Safe
acceptance.
