# Native refund delegate claims

The current fixed-price/price-program, Dutch, clearing and refund-window hosts
implement the additive `IStreamNativeRefundDelegatedClaims` capability for
[SSA-DELEGATE rule 9](stream-sales-and-auctions.md). A live delegate can trigger
an existing native refund payment to the credited account itself. The original
account can still choose its recipient through `claimRefund`.

This includes fixed, free, open and pay-what-you-want reveal-excess credit,
Dutch excess, clearing excess/rebate credit, and refund-window canceled or
unlocked-deposit credit. The original code still decides whether and when a
credit exists. Delegation creates no purchase, refund entitlement, payment
allowance, mint authorization or NFT destination.

## Deployment and admission

Each host appends an optional `DelegationDeployment` containing the actual
NFTDelegation registry, usecase, original base manifest hash and the governed
`DELEGATE_REGISTRY_GAS_LIMIT` configuration. The fixed adapter appends this
argument after its reveal gas configuration; the other three hosts append it
to their existing deployment tuple. Existing constructor callsites pass an
explicit entirely zero tuple to preserve their prior deployment mode. A partly
configured zero-registry tuple is rejected. Only enabled deployments advertise
the new interface through ERC165.

An enabled deployment pins chain, Core, registry address/runtime, usecase,
base manifest and original module registry/runtime as immutables. It uses the
existing compact `6529STREAM_NATIVE_AUCTION_NFTDELEGATION_MANIFEST_V1` encoding,
including the actual host address. `refundDelegationManifest()` returns those
complete bytes; their hash is the module record's `moduleManifestHash`.
Registration authenticates that record before consuming a sale nonce. The
host registers the additional gas parameter through its original governed gas
parameter authority, floor and delayed-change mechanism.

## Claim authority and accounting

`claimRefundFor(saleId, account, {walletWide, index})` is a zero-value CALL.
The witness locates an actual retained row; it supplies no authority facts.
The existing fixed NFTDelegation reader checks the exact vault/delegate,
start/expiry, all-token flag and zero token coordinate. The configured Core or
original wallet-wide scope and usecase construct the registry key. Calls use
the governed cap, parent-gas precheck and exact six-word return shape. Revoked,
expired, missing, malformed or reverting rows and changed registry runtime
fail closed. The registry's length-only boolean getter is not sufficient.

The guarded host then runs the original account-specific claim accounting.
Clearing retains rebate announcement/debit ordering; refund-window claims
retain both aggregate and sale-key liability updates. All hosts retain the
original claim events, solvency checks, debit-before-call order and exact
post-payment balance checks. A failed recipient callback reverts the credit,
liabilities and Safe nonce; the identical signed Safe transaction can retry.
There is no alternate delegate destination field.

Earned exits do not re-admit the current module, Artist, sale phase or entropy
provider. A live delegation row remains necessary for a delegate; the account's
original claim does not depend on that registry. The authored unavailable-
provider cases model read failure and do not claim to execute an actual module
retirement transition.

## Fixed worker boundary and compatibility

The new base has only immutable fields and adds no storage slots. Existing
public non-constructor ABI entries and complete recursive storage layouts of
the four hosts remain intact. Original purchase, price-program, signing,
EIP712 domain/type, sale/config identity, replay and receipt encodings remain.
No ERC20 payment surface changes.

To fit the hosts, fixed linked workers encode terminal view returns and handle
fixed/price-program registration and consent reads in the actual host context.
The guarded host owns caller checks, storage references and the sale nonce.
Registration has no external call between its original final admission read,
storage/event writes and the host's immediate nonce increment. Raw returns
occur only in terminal view entrypoints; guarded mutations return normally.
Refund-window record reads use the same original storage references and tuples.

The selected optimized IR measurement fits all eight products. Runtime bytes:
fixed adapter 24,524; Dutch 23,195; clearing 22,392; refund window 23,384;
immediate worker 9,588; read encoder 1,506; clearing execution 19,110; refund
book store 9,556. The fixed adapter has only 52 bytes of remaining runtime space.
These sizes do not establish transaction gas conformance or whole-graph fit.

## Client and validation scope

[The current client guide](../packages/stream-client/docs/current-secondary.md)
describes explicit compiler ABI selection, live-row observations and zero-value
Safe CALL preparation. No helper signs, broadcasts or invents deployment pins.

The focused source cohort authors thirteen new cases using actual current
Core/Manager/Artist/governance/recorder hosts, original NFTDelegation and payer/
delegate Safes. It covers all four ledgers, exact signed Safe retry after missing
grant or post-debit recipient failure, full-row/scope/malformed/revocation
refusals, account-only destinations, unavailable-provider own exits, and
separate free/open/PWYW sale keys. The external entropy service remains the
existing fixture double. Original fixtures retain zero optional deployment.

The 932-source ABI check and selected eight-product compilation pass. All 107
client checks pass, including ten new controlled-RPC/refund cases and strict
TypeScript assertions. The new native cases are authored and typechecked;
their execution, combined-current integration and cold gas acceptance remain
pending the integrator's later native validation. This is a source feature
handoff, not release or deployment acceptance.
