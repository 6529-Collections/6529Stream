# Current curated private caller

`current-curated-private.ts` prepares the original buyer-bound `PRIVATE_SALE`
carrier flow. It produces unsigned calls and EIP-712 payloads. It never signs,
sends, deploys, or claims that a current-stack deployment has been accepted.

The source boundary is the curated carrier joined tree at commit
`5605d019bc9cb933398f626df77b84d1cd2a51ba`. The selected private-carrier ABI
comes from the 128-source compiler capture whose input and output SHA-256 values
are `d1db6188f922acc490973cae67fbfecdd4fcfb31df18b909901acb57bb6a8101`
and `a2783ea8778a84012c7c9b96d9983b434fdb75e6ceade1dbbe2bf8a26aa14ca7`.
Manager and Ledger revocation fragments are source-exact and have separate
compiler-capture provenance in the package fixture.

## Identities that remain separate

- `saleId` is the original `6529STREAM_SALE_V1` identity with sale kind `5`.
- `purchaseId` is the buyer and purchase-nonce identity emitted by the carrier.
- The Sales EIP-712 digest signs the complete 24-field `SaleAuthorization`.
- `authorizationId` is `TICKET(Sales digest)`. Manager and Ledger durable replay
  use this value.
- The returned settlement key and Manager operation root and ID are receipt
  coordinates. They do not replace the purchase or authorization identities;
  the recorder's prepared-native execution ID also remains separate.

The original Sales domain is name `6529Stream Sales`, version `1`, the selected
chain, and the private carrier address. A relayed `MintTicketRevocation` uses
that same Sales domain. It does not use the ordinary Mint Tickets domain.

## Owner preparation

`prepareCollectionSignerConfiguration` reads the current owner and signer
membership at one concrete block, simulates the owner call, and returns a CALL
that increments the membership revision. Registration then pins the exact
signer address, kind, evidence hash, revision, and admitting authority.

`prepareRegistration` independently reconstructs:

- the kind-`5` sale ID from the current next sale nonce;
- the double-hashed declared content leaf and its bounded Merkle proof;
- the complete nested private configuration hash; and
- current signer membership.

It requires a future `startsAt`, strict primary policy mode `0`, a positive
price, and the original source bounds. Its owner-context simulation is the
contract check for current publication, Manager phase, content gate, Artist,
resolver, and deployment dependencies. A successful simulation is local to
that pinned block and is not an admission guarantee for a later transaction.

## Purchase packet

Build the one-token selection with the shared curated-content helpers. The
private path requires the configured buyer as payer and final beneficiary. The
carrier itself is the sole initial recipient while the prepared callback runs.
The authorization commits all four full arrays independently:

- initial recipients `[carrier]`;
- beneficiaries `[buyer]`;
- raw token data `[tokenData]`; and
- mint commitments `[mintCommitment]`.

`curatedPrivateBatchHashes` computes these exact hashes. Do not substitute the
token-data hash for the hash of the complete `bytes[]` array.

`preparePurchase` snapshots every input before its first RPC read. At one
concrete block it verifies the stored immutable configuration, live signer
membership, ERC-5267 Sales domain, next buyer nonce, selected proof, original
digest-derived TICKET, Manager/Ledger replay state, and live reveal quote. It
then simulates `purchasePrivateContent` from the actual executor with value:

```text
immutable positive price + caller-selected reveal fee allowance
```

The allowance must cover the live per-token reveal fee. The difference becomes
buyer-owned pull credit. The signed `executor` is the actual CALL sender. A
different sender may act only when the contract accepts the separate native
delegation witness for the configured buyer. Delegation does not change payer,
beneficiary, signer, or authorization identity.

Private purchase permits the inclusive endpoint `block.timestamp == endsAt`.
The authorization deadline must also be current and no later than `endsAt`.
`finalizeBy` is exactly zero and primary policy mode is exactly zero.

## Historical revocation

`inspectHistoricalAuthorization` uses only the full original authorization,
the carrier's immutable five-word binding, and Manager/Ledger replay reads. It
does not require the sale to remain active, unpaused, admitted, or inside its
purchase window.

`prepareVoidAuthorization` supports the two source paths:

- the historical configured signer calls Manager directly with empty bytes; or
- a relayer supplies that signer's original Sales-domain
  `MintTicketRevocation` signature.

The caller must submit the full original authorization. A bare digest is not a
revocation authority. An already consumed or voided TICKET is rejected.

## Existing credits and expiry

`refundableBalance`, `claimRefundCall`, and `claimRefundForCall` operate on
already accrued excess. They do not reapply current purchase admission. The
direct buyer may choose a non-carrier recipient. A live native delegate can
claim only to the credited buyer. `expirePrivateSaleCall` is permissionless but
the transaction succeeds only after `endsAt` and while the sale is active.

## Safe review

The example converts the owner registration and executor purchase into
`SafeCall` objects with `toSafeCall`. Follow the package's
[Safe CALL plan guide](safe-call-plans.md): confirm that the Safe is exactly the
prepared `caller`, compare target, calldata, native value and operation `0`,
then independently calculate and approve the Safe transaction. For the
purchase, the Safe must also be the signed `executor`; using a buyer Safe does
not make another executor valid. Review and sign the Sales payload separately
from the Safe transaction.

## Evidence boundary

Each stateful preparation checks a concrete block hash before returning. The
runtime hash records the observed carrier bytecode for caller comparison; the
client does not compare it with a canonical deployment hash. RPC simulation can
still become stale before broadcast. This module covers the private positive
native carrier only: no public offers, templates, free sales, ERC-20 payment,
signature production, broadcast, or whole-stack runtime acceptance.
