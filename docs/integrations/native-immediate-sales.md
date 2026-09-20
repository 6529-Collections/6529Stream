# Canonical native fixed and open sales

`StreamNativeImmediateSales` implements the original 24-field
`SaleAuthorization` in the `6529Stream Sales` version `1` domain, plus an
unsigned public sale path. Each purchase mints one ERC721 and settles through
the official native recorder and permanent conservation floor. This is a new
adapter deployment; the existing DIRECT, native fixed-price, price-program,
Universal, private-sale and offer domains and selectors retain their meanings.

## Supported first profile

| Setting | Accepted values |
| --- | --- |
| Sale kind | FIXED (`0`) or OPEN (`1`) |
| Authority mode | SIGNED (`1`) or PUBLIC (`2`) |
| Payment | Positive native price; caller equals explicit payer and executor |
| Quantity | Exactly one token per purchase |
| Recipients | Explicit initial recipient and beneficiary, which may differ |
| Primary rights | Collection PROFILE or static TEMPLATE with exact policy hash |
| Primary policy mode | STRICT (`0`) |
| Mint phase | Existing, unpaused, adapter authorized, single-step capable, no gate |
| Allowlist price | One selected original Merkle price counter, or none |
| Supply | FIXED has a positive sale cap; OPEN has no sale cap |
| Closing | Timed, or explicit manual close with `endsAt = 0` |

The Manager still enforces its own phase bounds, counters and policy rules.
Prepared per-token royalty snapshots, arbitrary gate composition, batches,
ALLOW_CURRENT primary economics, zero-price/PWYW and ERC20 payment are outside
this adapter's first profile.

The separate [canonical native Dutch carrier](canonical-native-dutch-sales.md)
uses the same authorization domain and setup with immutable schedules,
maximum-price funding and optional declared free tiers.

## Configure, register, obtain consent

1. Deploy against the intended current Manager, recorder, Artist registry and
   role registry. The recorder must advertise the additive public-native
   settlement interface. Supply the three governed signature, Artist-read and
   reveal-attempt gas parameters in constructor order. Transfer adapter
   ownership to the intended governance authority before owner configuration.
2. Admit the adapter as `NATIVE_PRIMARY_SALE_ADAPTER`, using
   `IStreamNativeSaleBinding` and the existing universal-settlement capability.
   Authorize it as an executor for the intended Manager phase.
3. For a signed sale, call `configureCollectionSigner`, then read its exact
   `SignerBinding` and include it in the configuration. Kind `1` is explicit
   ECDSA and kind `2` is explicit ERC1271. A public configuration uses an
   entirely zero signer binding. Changing a signer revision invalidates sales
   bound to the older revision for execution.
4. Register the immutable configuration. Registration verifies the live mint
   and primary policies, accepted Artist association, admission, cached stops
   and bounded current registry contest standing. It rejects contested or
   sustained collections even if their local stop has not yet been synced.
5. Obtain actual Artist sale-parameter consent against the registered
   `saleConsentFacts(saleId)`. This happens after registration because the
   consent binds the resulting immutable sale ID and configuration hash.
6. Establish the genuine permanent conservation floor and required Metadata
   declaration before purchase. An explicit WAIVED declaration is still a
   declaration; missing floor or declaration is not an exemption.

Use [sale-parameter consent](sale-parameter-consent.md) and the matching
[native settlement deployment](native-commerce-deployment.md) instructions for
their governed configuration. A source test fixture is not deployment evidence.

## Prepare a purchase

Read `nextExecutionNonce(saleId, payer)`. Construct the exact `Purchase`,
including token data, commitment and original resolver proof bytes. Previews
are public reads; execution must be a CALL from the declared payer/executor.
A threshold Safe can be that caller. The beneficiary used for the Merkle
recipient counter is the same beneficiary passed to Manager.

For SIGNED mode, sign all 24 original `SaleAuthorization` fields. Bind the
actual chain, adapter and Manager, registered sale/phase/kind, explicit roles,
original tagged hashes of the four one-element arrays, immutable baseline
price, quantity `1`, mint policy, nonce and deadline. `contentSelectionHash`
and `finalizeBy` are zero. Discover the domain with `eip712Domain()` and compare
the complete digest with `authorizationDigest()`. The signature must match the
configured address and explicit kind; the Artist's separate consent remains
required.

A proven Merkle leaf can replace that baseline price, including with a higher
price. It takes the fixed-price role only when the authenticated leaf sets its
override flag. A zero effective price is rejected. Supply the same proof bytes
to the adapter and Manager; see [native allowlist prices](native-allowlist-price-programs.md).

Use `previewSignedPurchase` followed by `purchaseSigned`, or
`previewPublicPurchase` followed by `purchasePublic`. PUBLIC mode supplies no
seller signature and retains `saleAuthorizationDigest = 0`. Its Manager
authorization ID has the distinct `6529STREAM_NATIVE_PUBLIC_MINT_AUTHORIZATION_V1`
domain and binds chain, adapter, Manager, configuration and the full request.
SIGNED mode wraps the original Sales digest in the existing MintTicket
authorization-ID domain. Both are consumed by the actual Manager/Ledger.

## Payment, receipt and retry

Without a declared reveal policy, send exactly the effective price. With a
declared policy, use the reveal quote and allowance: the price goes to the
official recorder, the selected fee funds the original reveal path, and
excess becomes payer-owned pull credit. A declared zero-fee policy also retains
excess as credit. Credits can be claimed independently of sale pause or expiry.

The adapter binds a single Manager preview root and operation ID to the native
candidate. For public settlement it exposes a typed in-progress commitment;
the recorder checks that commitment and the immutable public sale record
before and after funding. The recorder stores its original result, official
totals and conservation receipt. The adapter then executes the actual mint,
attempts reveal and rechecks live admission, policies, rights and Artist facts.
It emits no additional DIRECT settlement receipt.

Read `executionReceipt` and `executionStatus` alongside the original recorder
result and Ledger authorization state. Any later mint, receiver, floor or
policy failure reverts the entire purchase, including funds, nonce, sold count,
receipts and authorization consumption. The same transaction inputs may then
be retried if the cause is repaired and their deadline and policy remain valid.

Global pause, sale pause and synced collection stops toll a timed sale's active
duration using their overlapping union. Signature deadlines and independent
Manager bounds remain enforced. Permissionless `syncCollectionContest` updates
the local stop used during purchases; ordinary purchases do not read registry
contest standing. Manual closure and reaching a FIXED cap permanently close
the sale.

## Revoke a signed authorization

Call the Manager's additive `voidMintImmediateSaleAuthorization` with the full
original authorization, claimed historical signer and explicit kind. The
Manager reads the immutable original sale binding and voids the same Ledger ID
that purchase would consume. The historical signer may call directly, or a
relayer may carry its original-domain `MintTicketRevocation` proof. A normal
sale signature or custody proof does not authorize revocation.

Expiry, sale pause, signer disablement and current module/economics availability
do not condition historical revocation. Consumed IDs cannot be voided, and
voided IDs cannot execute. Existing private-sale and offer revocation methods
retain their separate behavior.

## Validation boundary

Dedicated adapter, public-recorder and historical-revocation cases cover this
source batch, including explicit typed fixture boundaries. ABI/type checks,
native runtime, linked deployment sizes, actual current-stack acceptance and
release evidence are separate results. Consult the
[delivery ledger](../../ops/V1_DELIVERY.md) for the integrated acceptance state;
this guide makes no deployment or audit-readiness claim.
