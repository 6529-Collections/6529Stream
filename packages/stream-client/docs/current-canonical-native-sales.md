# Canonical native purchases and claims

This client profile covers `StreamNativeImmediateSales` and
`StreamNativeClaimSales` at ABI113 source
`4fa32ae1c9206b05be848c7553c6492f516a7bfe`, tree
`36bc632478b81ca929ab0eebec379f0e696f18c5`.

It prepares purchases, native excess refunds and historical Manager revocation.
The fixture retains complete ABIs and their source dependencies. Earlier native
fixed-price and price-program helpers keep their original domains, request
shapes and evidence. Their shorter authorizations do not describe these two
canonical sale adapters.

## Choose the registered family and mode

| Adapter family | Sale kind | Price and supply |
| --- | --- | --- |
| Immediate | FIXED (`0`) | Positive effective native price; positive immutable sale cap. |
| Immediate | OPEN (`1`) | Positive effective native price; no adapter sale cap. |
| Claim | ZERO_PRICE_CLAIM (`12`) | Configured and chosen price zero; positive immutable sale cap. |
| Claim | PAY_WHAT_YOU_WANT (`13`) | Chosen price within the registered band; positive immutable sale cap. |

Each family supports SIGNED (`1`) and PUBLIC (`2`) authority. Each purchase mints
exactly one token. SIGNED uses the complete original 24-field `SaleAuthorization`
under `6529Stream Sales`, version `1`, at that adapter's own address. PUBLIC has
no seller proof and retains a zero Sales digest.

Purchase methods are `purchaseSigned` and `purchasePublic`; the matching preview
method must be selected explicitly. Claim wraps the original mint request and
adds `chosenUnitPrice`. The two families have distinct configuration, request,
execution and public authorization-ID domains. Their unsigned public IDs cannot
be substituted for each other or for the signed Manager authorization ID.

Registration, signer configuration, closure, pauses, contest synchronization,
ownership and governed gas changes remain separate lifecycle operations. Reading
their retained facts does not perform those operations.

## Exact parties and signatures

The actual purchase caller must equal both the explicit payer and executor. A
Safe may fill all three roles through an ordinary payable CALL. Its individual
owners do not become the purchase caller. The initial token recipient and
beneficiary are explicit and may differ from each other and from the payer.

SIGNED binds the actual chain, adapter and Manager; sale, phase and kind;
revenue class and primary policy; all four tagged one-token array hashes;
parties; native asset; price, quantity, mint policy, nonce and deadline. Quantity
is one. Asset, primary policy mode, selected-content hash and finalize-by are
zero. The authorization nonce must be nonzero. The separate per-sale/per-payer
execution nonce starts at one. The signature deadline is inclusive.

Discover the exact `eip712Domain`, compare the complete `authorizationDigest`,
and use the registered explicit signature kind: ECDSA (`1`) or ERC-1271 (`2`).
Code presence does not choose the kind. Signature acceptance, current signer
revision and separate Artist consent remain original-contract checks. A changed
signer revision can invalidate a previously registered execution binding.

The bound mint policy and the current Manager policy can differ during an
originally admitted grace period. Retain both hashes from the actual preview;
do not replace the bound hash or impose unconditional equality between them.

## Price proofs and literal zero

Keep the complete original `AllowlistProof[][]` bytes. The source supports up to
16 ordered Merkle counters, with exactly one selected `priceCounterId` when a
price counter is configured. Other counters remain in their configured order
and may not carry a price override. The adapter and Manager receive the same
proofs and beneficiary.

The authenticated leaf's override flag distinguishes an explicit zero from an
absent override. For Immediate sales, a selected override replaces the signed or
configured baseline, including when it increases the price. A resulting zero
price is rejected.

For PWYW, the seller signs a minimum; the registered configuration fixes the band
floor and maximum. A selected override replaces the signed/public minimum, then
the configured floor applies:

```text
minimum = max(configured floor, proven override or authority minimum)
minimum <= chosenUnitPrice <= configured maximum
```

A proven zero can replace a signed minimum of 1,000 in a `[0, 2,000]` band. It
cannot permit zero in a band whose floor is 1,000. The chosen amount belongs to
the complete mint request and operation identities, while the signature binds
its minimum. ZERO_PRICE_CLAIM requires all original free-price constraints and
rejects a positive override.

A literal zero Claim purchase consumes the original Manager authorization and
operation identities, mints and follows the original reveal path. Its receipt
has zero charged amount and zero settlement key, with `FreeClaimExecuted`
evidence. It creates no official primary settlement or conservation receipt.
PWYW can take this path even when its configuration retains a nonzero expected
primary policy hash.

A positive Claim purchase settles the entire chosen amount as official revenue.
There is no separate tip transfer. A previous free mint provides no exemption
from the permanent conservation floor required by a later positive purchase.

## Capture, preview and simulation

Use reviewed deployment metadata for the exact source and chain. Arbitrary
address/hash pairs do not prove correspondence with this source. Retain a
concrete block and its hash, the immutable sale record, current execution nonce,
the original domain, proof inputs, relevant dependencies and the actual preview.

The preview is authoritative for admission that cannot be reconstructed from
public getters. In particular, the adapter's overlapping pause clocks are
private. `saleRecord` alone cannot establish its current adjusted end time.
Original Manager policies, Artist standing and callback-sensitive state also
remain subject to original execution checks.

Simulation must call the exact selected purchase method with the actual
payer/executor, explicit native value, concrete block and explicit gas limit.
Successful reads or a preview do not guarantee that the purchase will succeed.
A later policy, admission, fee, nonce or supply change can require a new capture.

The pure entry point is `prepareCanonicalNativeSalesCall(coordinates, caller,
request)`. Its request discriminants are `family: "immediate" | "claim"` and
`kind: "purchaseSigned" | "purchasePublic" | "claimRefund" |
"voidMintImmediateSaleAuthorization"`. Coordinates contain `chainId`, `adapter`,
`manager`, `ledger` and `recorder`. Preparation marks `factsVerified: false`;
canonical calldata and local shape validation do not establish chain facts.

For a reviewed request and deployment, the workflow is:

```typescript
const prepared = prepareCanonicalNativeSalesCall(coordinates, caller, request);
const capture = await captureCanonicalNativeSales(provider, deployment, prepared, {
  blockTag: reviewedBlock,
});
const simulation = await simulateCanonicalNativeSales(provider, capture, {
  blockTag: reviewedBlock,
  gasLimit: 8_000_000n,
});
// simulation.capture is the refreshed observation; simulation.receipt is the
// typed purchase return, or null for a refund or authorization revocation.
```

The gas value above is illustrative. Use a reviewed limit for the intended call;
it is not a measured protocol requirement. `deployment` specifies the chain and
family, code pins for adapter/Core/Manager/Ledger/recorder, and reviewed linked
dependencies. A pin consists of `address` and `codeHash`.

`inspectCanonicalNativeSales(provider, deployment, { saleId, executionId },
{ blockTag })` reads the retained local record, receipt and status. Omit
`executionId` for configuration history alone. This narrower read does not
re-establish current purchase eligibility or provide receipt reconciliation.

## Native reveal value and refunds

Without a declared reveal-fee policy, supply exactly the effective or chosen
price, including zero for a free claim. An undeclared quote is valid only where
the original explicit entropy policy admits its no-reveal path; it is not a
generic exemption for a missing or malformed coordinator.

Explicit DISABLED and INSTANT policies can skip `AT_MINT`. An INSTANT token can
still require a later entropy request; skipping the mint-time request does not
establish terminal or finalized entropy.

With a declared policy, the value includes the original reveal fee allowance.
The quoted fee funds the original coordinator path, and unused allowance becomes
the payer's pull credit. A declared zero fee can still create excess credit.
Keep the distinction between undeclared policy and declared zero fee.

An isolated failed `AT_MINT` reveal attempt can coexist with a successful mint.
Interpret `ImmediateRevealAttempt` and its bounded failure prefix separately
from the purchase receipt. A successful purchase does not establish finalized
entropy. Funding, token identity and policy inconsistencies can still cause an
atomic purchase failure.

`claimRefund(saleId, recipient)` pays the caller's full current native credit.
Only that credited payer, including its Safe, chooses the nonzero destination,
which cannot be the adapter. The call carries zero value. Refunds remain
available independently of current sale pause, expiry or admission. A failed
transfer or accounting check restores the credit and liability.

Refund discovery is append-only: `refundAccountCount` and `refundAccountAt` can
continue to enumerate accounts whose balance is now zero. Enumeration does not
prove an outstanding claim.

## Historical signed-authorization revocation

The Manager's `voidMintImmediateSaleAuthorization` accepts the complete original
authorization, claimed historical signer, explicit kind and separate revocation
proof. This profile limits the sale kinds to `0`, `1`, `12` and `13`.

The Manager reads the adapter's original immutable SIGNED binding and voids the
same manager-scoped Ledger authorization ID that purchase would consume:

```text
authorizationId = keccak256(abi.encode(original ticket domain, Sales digest))
```

The historical signer may call directly. A relayer needs the original-domain
`MintTicketRevocation`, which binds chain, Manager, Ledger and authorization ID.
An ordinary sale signature and a custody revocation are different proofs.

Historical expiration, closure, current signer disablement and current sale or
module admission do not determine this revocation's eligibility. The immutable
binding, exact replay state and original signature checks still apply. Revocation
does not mint or allocate an operation identity. Consumed and already-voided IDs
cannot be voided again.

## Direct and Safe receipt evidence

Reconcile the exact mined transaction, canonical block, adapter events and
retained receipt. A purchase has original in-progress and completed execution
evidence; the final receipt also joins the Manager/Ledger replay and operation
state. A final capped purchase can emit `ImmediateSaleClosed` in the same
transaction. That event is consistent with its successful final mint.

Positive purchases retain the original native recorder result and conservation
evidence. A completed public purchase normally leaves its transient active
candidate commitment at zero; that is not a missing historical receipt. Free
claims require their distinct zero-settlement evidence.

Use Core's permanent token collection identity for historical joins. Current
ownership can change after mint and does not establish the initial recipient.
Safe reconciliation also requires an independently obtained Safe transaction
hash and matching success evidence for the exact inner CALL and value. Both
indexed and non-indexed success layouts are supported.

Call `reconcileCanonicalNativeSalesReceipt(provider, capture, transactionHash,
{ execution: "direct" })` for a direct transaction. For a Safe CALL use
`{ execution: "safe", expectedSafeTxHash }`, with its independently obtained Safe
hash. The outer transaction carries zero value; its exact inner CALL carries the
prepared native value. The result exposes `purchaseReceipt`, `settlement`,
`revealAttempt`, `refundedAmount` and `revokedAuthorizationId` as applicable.

This reconciliation profile requires a receipt strictly later than the capture,
matching reviewed state in the block immediately before execution, and exact
relevant changes at the end of the receipt block. Other transactions affecting
the same observations within either interval can make reconciliation reject a
valid transaction. Obtain a new suitable capture or use a separately reviewed
transaction-level evidence process; do not silently relax those comparisons.

An already retained conservation release may need the optional `releaseKey`
locator. It is a lookup hint: the full original release receipt and hash joins
must still match. The client does not infer this key from an unrelated direct
purchase or substitute a different conservation receipt family.

## Client limits

The source permits at most 16 phase counters and token data of 8,192 bytes.
This client additionally bounds encoded input and codec bytes to 262,144,
inner sale and revocation signature proofs to 65,536 bytes, each Merkle proof to
64 siblings, and generic codec arrays to 1,024 entries. Merkle proof rows remain
singleton entries and respect the tighter 16-counter limit.

Workflow limits are 2 MiB per RPC result or event payload, 8 MiB of aggregate log
data, 4,096 logs, 131,072 bytes per runtime, 256 linked dependencies and a
100,000,000 gas simulation ceiling. Each log permits at most four topics. Outer
transaction calldata, including aggregate Safe signatures, is bounded to 2 MiB
plus 16 KiB. These allocation and transport limits are client restrictions,
not new on-chain protocol guarantees. Use exact bigints
for ABI integers; structural getter codecs preserve empty zero-valued records,
while purchase preparation applies its separate eligibility checks.

These checks are source/ABI and mocked client evidence. Actual deployed runtime
correspondence, native contract/Safe execution, gas capacity and release
acceptance remain separate validation work.
