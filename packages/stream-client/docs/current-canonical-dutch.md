# Canonical native and ERC20 Dutch purchases

This additive client profile targets ABI121 source
`6536c25895ae12eb9d702da9361f067152060d9b`, tree
`d4b524e8125570855880f96fe42da5b3fa9c55ba`. It covers the plural
`StreamNativeDutchSales` carrier and `StreamERC20DutchSale` through its actual
Payment adapter. Both use standard Dutch pricing and original canonical
Sales-v1 authorization. They have no clearing rebate.

The [earlier native Dutch client](current-native-allowlist-dutch.md),
[canonical fixed/open and claim clients](current-canonical-native-sales.md),
and [ERC20 primary-offer client](current-erc20-primary-offer.md) retain their
own profiles, fixtures and signing evidence. Their similar tuple shapes do not
make family-specific domains or validation interchangeable.

## Supported operations

| Principal | Original entry point | Funding |
| --- | --- | --- |
| Native payer and executor | Carrier `purchaseSigned` or `purchasePublic` | Native price plus a native reveal allowance |
| ERC20 payer | Payment `settleERC20DutchSaleByPayer` | Existing token allowance; separate native reveal allowance |
| ERC20 intent executor | Payment `settleERC20DutchSaleWithIntent` | Payer's signed token intent; executor's native reveal allowance |
| ERC20 payer with EIP2612 | Payment `settleERC20DutchSaleWithEIP2612Permit` | Maximum token permit; separate native reveal allowance |
| ERC20 payer with Permit2 | Payment `settleERC20DutchSaleWithPermit2` | Maximum Permit2 permission; separate native reveal allowance |
| Credited account | Carrier `claimRefund` | Zero call value; selects the refund recipient |
| Original authorizer or authorized relayer | Manager full-payload kind-3 revocation | Zero call value; original historical replay domain |

Carrier execution and funding callbacks remain protocol-only. Sale creation,
closing, signer installation, pauses, ownership and gas administration are
outside these operational plans. The client may describe their immutable
configuration inputs without authorizing an administrative transaction.

A Safe CALL makes the Safe the actual executor. Its individual signers are not
substitutes for that caller. Public purchases require the token payer and
executor to be the Payment caller. Signed ERC20 intent execution can use a
different payer; that distinction does not transfer native refund ownership.

## Prepare, observe, simulate and reconcile

The package root exports separate native and ERC20 modules. Prepare unsigned
calls with `prepareCanonicalNativeDutchCall` or `prepareERC20DutchCall`; these
helpers do not submit transactions. Preserve the returned caller, destination,
calldata and native value together.

| Step | Native API | ERC20 API |
| --- | --- | --- |
| Capture at a concrete block | `captureCanonicalNativeDutch` | `captureERC20Dutch` |
| Simulate the complete call | `simulateCanonicalNativeDutch` | `simulateERC20Dutch` |
| Read retained history | `inspectCanonicalNativeDutch` | `inspectERC20Dutch` |
| Reconcile a mined transaction | `reconcileCanonicalNativeDutchReceipt` | `reconcileERC20DutchReceipt` |

Capture and inspection take `{ blockTag }` with a nonnegative safe integer.
Simulation takes `{ blockTag, gasLimit }`, reconstructs the saved observation,
then captures the requested current block before calling the original entry
point from its actual executor. Review the returned capture because current
admission, pricing and funding facts may differ. Block hashes are checked again
after observations to reject detected reorgs. A successful simulation is an
observation at that block, not a guarantee of later inclusion.

Supply reviewed address/code-hash pins for the carrier, Core, Manager, Ledger
and Recorder; ERC20 also requires Payment and asset pins, with a Permit2 pin
where applicable. The deployment requires four explicit library inventories:

- `linkedDependencies`: fixed helpers used by the purchase route.
- `refundLinkedDependencies`: fixed helpers used by local refund execution.
- `historyLinkedDependencies`: fixed helpers used by retained record reads.
- `revocationLinkedDependencies`: fixed helpers used by historical binding,
  Manager revocation and Ledger replay handling.

For example, both carriers call the public linked
`StreamNativeImmediateSalesRefunds` library when claiming a refund. Pin that
route's complete transitive fixed-library set without requiring unrelated
commerce libraries to remain admitted. An explicitly empty list is accepted
only as supplied metadata; the client cannot prove inventory completeness or
derive link addresses from a runtime hash. Each route verifies its listed pins,
and reconciliation rechecks the dependencies relevant to the executed route.

Receipt options are `{ execution: "direct" }` or
`{ execution: "safe", expectedSafeTxHash }`, with an optional `releaseKey` for
the corresponding conservation release. The receipt must be strictly later
than capture. Reconciliation reconstructs the previous block, compares reviewed
nonprice facts and derives the mined price. It checks selected end-of-block
state as well as the transaction's own events. Other transactions or receiver
callbacks that change those selected observations can cause a conservative
refusal even after a successful transaction; this is not a transaction-level
state trace. Investigate such a refusal instead of treating it as proof of an
on-chain revert.

## Client resource bounds

Integer protocol fields use `bigint`. The pure call helpers cap encoded calldata
at 262,144 bytes, signatures at 65,536 bytes and original token data at 8,192
bytes. Their allowlist profile permits at most 16 groups, one leaf per group and
64 proof siblings per leaf. These client limits do not broaden contract rules.

Workflow observations cap each RPC return or log payload at 2 MiB, runtime code
at 131,072 bytes, each explicit linked-library list at 256 entries and receipts
at 4,096 logs with at most four topics each. Aggregate log bytes are capped at
8 MiB; outer transaction calldata at 8 MiB plus 16 KiB. The larger outer bound
allows envelope processing without increasing the pure inner-call limit.
Simulation requires a positive gas limit no greater than 100,000,000; that is a
client ceiling, not deployment gas-capacity evidence.

## Immutable schedule and current price

The original seven-field schedule retains `uint96` prices, `uint64` start/end,
an explicit decay kind, `uint32` step seconds and `uint96` step amount. LINEAR
prices round upward between endpoints. STEPPED pricing subtracts completed
steps. Both reach the resting price at the schedule end.

The schedule hash uses the original `6529STREAM_DUTCH_SCHEDULE_V1` domain with
chain, carrier and sale ID. Full configuration hashes also bind the explicit
free declaration. Native configuration retains the starting price in the
common sale configuration; ERC20 configuration stores zero there and separately
binds its asset and actual Payment adapter.

Native registration must precede the start, and a timed native close can equal
the schedule end. The ERC20 timed close must be strictly later than the schedule
end; its original registration predicate does not impose the native pre-start
restriction. Manual closing uses the original zero end-time profile.

Pauses and contests can extend the sale's closing window by their union
duration. The price curve continues decaying during those pauses. The exposed
record does not reveal every private clock accumulator, so the original preview
and complete-call simulation remain authoritative for current sale admission.
Authorization deadlines and Manager phase limits remain independent.

A captured quote is tied to its observation timestamp. Reconciliation must
derive the price again at the mined timestamp using the same immutable schedule
and proven leaf. A changed price changes the candidate amount and commitment.
Recompute execution and settlement identities from their original preimages;
do not add a price field to those domains. Treating the quoted candidate as
permanently fixed would reject valid later purchases or misidentify their
settlement evidence.
With the other identity inputs unchanged, price-only drift retains the operation
root and execution ID. A free receipt still reports its original zero settlement
key instead of a paid settlement.

## Original authorization and proven overrides

Signed purchases retain all 24 original `SaleAuthorization` fields and the
`6529Stream Sales` / `1` EIP-712 domain at the actual carrier. The original digest
binds Manager, collection, phase, sale, kind `3`, revenue and policy facts,
tagged singleton array hashes, explicit parties, asset, signed price, quantity,
content, nonce and deadlines. EOA and ERC1271 remain explicit signature kinds.
The signature and digest do not change when the schedule price falls.

Without a proven price override, the signed `unitPrice` is a ceiling on the
current schedule price. A valid enabled override replaces that signed word's
pricing role:

```text
charge = min(current schedule price, proven leaf price)
```

For example, a schedule price of 1,000 and a proven ceiling of 600 charge 600,
even if the unchanged signed price word is 599. The independent transaction,
request and payment-intent maxima must still cover the charge. An enabled zero
override requires the registered free declaration. Preserve the same original
proof bytes through the adapter, Manager and Ledger, including the selected
price counter and the actual payer/beneficiary domain.

Public purchases use their original family-specific replay commitment and a
zero Sales digest. ERC20 public execution contains a literal-zero seller
authorization and signature. A PaymentIntent cannot grant an unrelated caller
public execution authority or redirect the committed recipient.

## Keep token and native amounts separate

For native purchases, the host captures the live reveal fee and subtracts it
from `msg.value` before checking price coverage. It funds exactly the fee and
credits excess native value to the payer. There is no redundant calldata price
maximum. Underfunding either fee or price refuses the purchase.

For ERC20 purchases, `Request.maxAmount`, `PaymentIntent.maxAmount` and permit
permissions are token amounts. Attached native value is the executor's separate
reveal allowance. It must never be added to the token price or token maximum.
The carrier credits unused native value to the executor, including when the
token payer is a different account. Only that credited account chooses the
pull-refund recipient.

EIP2612 permits may authorize a maximum larger than the current charge. Validate
the original post-permit and post-pull allowance rules instead of demanding an
exact-charge permit. Permit2 likewise keeps `TokenPermissions.amount` at its
authorized maximum while requesting only the current charge. Its exact nonce
bitmap and attested upstream allowance behavior remain part of verification.
Existing fixed-price entry points retain their separate exact-amount profile.

The reveal policy applies to paid and free purchases. A zero fee, undeclared
policy or explicit DISABLED/INSTANT posture does not discard excess value.
Bounded provider failure can coexist with successful mint and funding; failure
of funding, payment, mint or retained-state checks reverts the original call.
Local client evidence alone does not prove all of that EVM rollback behavior.

## Free outcomes and local exits

A permitted zero charge still consumes canonical sale and Manager replay,
allocates mint identities and follows the original reveal rules. It creates no
official zero-value revenue settlement or conservation settlement receipt.
Native execution emits `FreeDutchExecuted` and retains a zero settlement key.
ERC20 identifies the free outcome in its original carrier/payment result and
returns the literal-zero 12-word settlement tuple.

Free ERC20 allowance and permit routes skip permit execution, token pulls and
upstream permit nonce consumption. The Intent route still authenticates its
matching fields, signature, deadline and unused nonce when free, but consumes
no PaymentIntent nonce and emits no consumption event. These route differences
must survive simulation and receipt verification.

For a paid quote that becomes free at inclusion, receipt reconstruction uses
the independently derived mined charge for payment requirements. An expired
permit, spent permit nonce or retired permit capability in the preceding block
must not become a requirement of the eventual free mint. The original prior
carrier quote, immutable configuration, proof and nonprice identity still need
to match; the free path does not waive seller or PaymentIntent authorization.

Native free candidates retain zero rights fields. ERC20 free preparation still
resolves and validates its original rights and policy facts. Paid rights and
conservation checks remain separate requirements; an earlier free mint grants
no exemption to a later paid mint.

Refunds and historical kind-3 revocation remain available independently of
current sale admission. Historical revocation supplies the original complete
authorization and immutable binding; it is not a generic nonce cancellation.
A relayer needs the original revocation signature, while the original
authorizer can use the direct path. Current phase, signer, Artist or module
eligibility must not be reapplied to these local historical exits.

## Source and runtime evidence

The fixture contains 74 complete compiler ABIs and their 466-source import
closure, plus 15 frozen interpretation documents. The generator compares all
3,033 ABI121 input literals with the exact committed Git blobs and bridge
hashes. It does not invoke Solidity or establish deployed runtime identity.
Foreign token permit behavior still requires the actual token and permit
capability checks; no invented native compiler ABI substitutes for them.

Use reviewed deployment and fixed-library pins. Retained deprecated sales may
remain eligible under the original creation-time and registry-revision rules;
an ACTIVE-only replacement check changes that behavior. Current previews,
signer/Artist admission, exact native funding, token balances and allowances,
operation identities and retained receipts need their own observations.

Direct and Safe reconciliation must join the exact original call, canonical
transaction/block identity, emitter and event order, replay, payment and refund
effects, and permanent token identity. Obtain the expected Safe transaction hash
independently. Successful historical delivery does not establish current owner
after receiver callbacks or later transfers.

Compiler/source checks and mocked RPC/Safe-envelope tests establish client
encoding and reconciliation behavior. Actual contract/Safe execution, complete
atomic rollback, linked runtime/gas capacity and release acceptance remain with
combined integration validation.
