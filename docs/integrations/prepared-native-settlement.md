# Atomic prepared native settlement

The current Manager can prepare one token, settle its native payment through the
fixed official recorder, and complete the mint in one transaction. This is an
additive API for registered sale modules. A failed payment, callback, completion
or NFT receiver call rolls back the complete operation.

The implemented rights profile is a singleton collection PROFILE with exact
`tokenData`. DEFAULT, token-scope overrides, snapshot, template, follow-beneficiary and
curated-leaf profiles
remain separate work, as does the new auction's complete execution. This API is
not part of the immutable RC1 deployment.

## Caller interfaces

| Caller | Interface | Purpose |
| --- | --- | --- |
| Manager owner and registered sale | [IStreamPreparedNativeMint](../../smart-contracts/interfaces/stream/mint/IStreamPreparedNativeMint.sol) | Bind the recorder, preview and execute, read the active operation |
| Manager and official recorder | [IStreamPreparedNativeSaleBinding](../../smart-contracts/interfaces/stream/revenue/IStreamPreparedNativeSaleBinding.sol) | Authenticate the sale's dependencies, original lifecycle, active intent and callback |
| Registered sale | [IStreamPreparedNativePrimarySaleSettlement](../../smart-contracts/interfaces/stream/revenue/IStreamPreparedNativePrimarySaleSettlement.sol) | Settle the native payment and read retained official evidence |

[StreamPreparedNativeSettlementTypes](../../smart-contracts/interfaces/stream/revenue/StreamPreparedNativeSettlementTypes.sol)
owns the distinct `Intent` and `Facts` types. The result remains
`StreamPrimarySettlementTypes.PrimarySettlementResult`. Existing Manager, native
and deferred settlement selectors and signed domains are retained.

## Bind the official recorder

Deploy and bind the original Core, Manager, module registry and
`StreamPrimarySaleSettlement`. Register that recorder as ACTIVE under
`PRIMARY_SALE_SETTLEMENT`, advertising its prepared-settlement interface and
required version. Then the Manager owner calls:

```solidity
IStreamPreparedNativeMint(manager).bindPreparedNativeRecorder(recorder);
```

This owner-only binding succeeds once. Read `preparedNativeRecorder()` and the
`PreparedNativeRecorderBound` event to retain the address, runtime hash, binding
time and module revision. The constructors are unchanged; this explicit step
breaks the construction dependency cycle. Each execution still checks the
original binding and applicable module lifecycle, including incident revocation.
A sale cannot choose a replacement recorder for an individual payment.

The sale itself needs the registered `NATIVE_PREPARED_SALE_ADAPTER` role, its
required interface/version and the appropriate original lifecycle admission.
Registration alone does not grant phase-executor authority or artist consent.

## Execute the complete operation

1. The sale authenticates and locks its complete `Intent`, including the original
   executor, payer, beneficiary, amount, authorization and execution hashes.
2. The registered sale adapter, installed as the phase's executor, calls
   `executePreparedNativeMint(batch, gateData, intentHash)`. The separately
   recorded `Intent.executor` can be the sale's payer or relayer. Manager checks phase authority, policy, consent, gate and replay
   state, records the original operation and prepares the actual Core token.
3. Manager derives the complete `Facts` and calls the same sale's
   `onPreparedNativeMint(facts)`. The sale verifies its fixed Manager and active
   operation; it then pays the fixed recorder's
   `settlePreparedNativePrimarySale(facts, intent)` with the native amount.
4. Manager verifies the callback selector and exact official result against the
   recorder's saved evidence, completes the mint and returns the token ID,
   operation root, operation ID and settlement result.

`activePreparedNativeMint()` and `activePreparedNativeIntent()` describe the
currently executing operation. They are not persistent tickets that can be
redeemed later. A preview is also not a reservation: derive the final operation
from execution, its returned values and retained events.

After completion, use `preparedNativeFactsHash(settlementKey)`,
`preparedNativeSaleConsumed(saleKey)` and `PreparedNativeRevenueRecorded` for
original settlement evidence. Derive the sale key through
`preparedNativeSaleKey(saleAdapter, saleId, saleNonce)`. Consuming the original
sale remains independent of a fresh operation root or buyer authorization.

## Safe integration and rollback

A Safe can act through the same role-authorized calls. The callback remains a
protocol call from the installed Manager to the registered sale. Keep owner
binding, sale authorization and buyer/payer signatures distinct; a contract
wallet does not bypass phase authority, consent or payment checks.

The actual integration test uses a Safe 1.4.1 payer, a registered fixture sale
and the actual Manager, official recorder and Core, with typed governance,
Artist and entropy boundaries. Its NFT receiver fails after payment; execution
restores payment, counters, replay, token state and the Safe nonce. The same
original signed call succeeds after that receiver is repaired. Preserve
those exact signed bytes when retrying; changing a deadline or another intent
field creates a different authorization.

## Validation and remaining integration

[StreamCurrentPreparedNativeSettlementTest](../../test/current/StreamCurrentPreparedNativeSettlement.t.sol)
has fourteen actual-contract cases, including a 256-input property. Four retained
native/deferred companion controls also pass in the reviewed via-IR run. The
reviewed compiler output fits the runtime size limit for every production
product. The final source has a separately reviewed formatting-only bridge.

These results cover the described paid handoff and rollback behavior. Complete
auction execution, additional rights/content profiles, deployment wiring,
transaction capacity and the new full-v1 candidate remain open. See the
[delivery ledger](../../ops/V1_DELIVERY.md).
