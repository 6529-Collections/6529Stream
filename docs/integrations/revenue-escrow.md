# Revenue escrow: first-line delivery

`StreamRevenueEscrow` retains owed native or ERC-20 revenue for an exact split
wallet, then permits anyone to deliver that credit to the wallet. This is the
single-factory primitive for the [v1 revenue specification](../revenue-splits-and-royalties.md).
Production sale-adapter adoption, template materialization, incident recovery,
successor-factory support, and release gas sizing remain separate work. This
contract is not wired into the previously published supported release candidate.

Deploy with the actual `IStreamSplitFactory`, its canonical Governance-V2
executor, and an explicit `FLUSH_GAS_FLOOR` gas configuration with failure class
`MIN_GAS_GATE` (3). The factory and asset-policy registry must have the same
executor. Their runtime hashes and the factory's wallet runtime hash are captured
immutably; delegation designators cannot stand in for these protocol contracts.
The factory supplies the current `WALLET_DEPOSIT_GAS_LIMIT` and
`ASSET_POLICY_GAS_LIMIT`. There is no emergency lower or immutable fallback cap.

## Credit admission

Governance admits each producer address and its actual runtime through an exact
delayed class-1 action. Use `creditProducerTransitionHashes(producer, enabled)`
to obtain that action's scope and old/new commitments. The transition includes
a monotonic revision; re-enabling or replacing a producer runtime requires a new
action. Revocation or later producer code drift blocks new credits and preserves
the funds already owed. EIP-7702 producer designators are rejected. Safe proxies
can call the API when admitted, but producer admission remains a protocol trust
decision, not permission for arbitrary accounts to label deposits as official
sale revenue.

An admitted producer calls:

```solidity
escrow.creditNative{value: amount}(revenueClass, profileId, wallet, templateOrigin);
escrow.creditERC20(revenueClass, profileId, wallet, asset, amount, templateOrigin);
```

Both require a positive amount, nonzero revenue class, registered profile, and
the exact factory-predicted address. Existing wallet code must match the captured
runtime, factory, and profile. An undeployed wallet is accepted only when
`templateOrigin` is true. That boolean is evidence supplied by the admitted
producer; escrow does not independently resolve sale assignment kinds. A fixed
profile resolving to an empty wallet is rejected.

For ERC-20, the producer approves escrow and escrow pulls **from that producer**.
There is no arbitrary payer argument. An adapter that first pulls a buyer's
allowance must keep its own PaymentIntent domain bound to that first puller.
Escrow checks `ACTIVE` both before the transfer and after any callback. Exact
32-byte reads, an exact `true` return, and both balance deltas must agree. Empty,
false, malformed, fee-on-transfer, no-op, and rebasing transfer results fail.

## Delivery and accounting

`escrowOwed(revenueClass, profileId, wallet, asset)` reports the exact key's owed
amount; `totalOwed(asset)` reports all keys for that asset. `escrowCreditIdentity`
returns the captured factory and factory/wallet runtime hashes. Direct native
receipts, forced ETH, and token donations are surplus, not new official credits.
`surplus(asset)` exposes the positive balance above aggregate owed. This first
line has no surplus withdrawal or emergency sweep.

`flushEscrow` checks its current minimum gas requirement and can deploy the
registered wallet through the captured factory. `flushToVerifiedWalletBestEffort`
requires an already deployed wallet and never calls deployment or applies the
normal undeployed-wallet gas floor. Both deliver only to the captured wallet,
zero the key and decrement aggregate owed before deployment or transfer, then
revert the entire operation if any subsequent check or transfer fails. They do
not pay individual recipients; recipients use the wallet's release methods.

Every external token read/transfer is bounded by the factory's current deposit
cap. Native delivery includes the EVM value stipend within that same cap. The
caller must supply enough outer gas to forward the full cap and retain return
handling gas. Normal deployment dynamically uses the remaining gas after
reserving deposit/read work; it has no fixed deployment stipend. External errors
retain the full returned-data length and at most the first 256 bytes. An
underfunded call can fail, but cannot silently erase credit or report a failed
transfer as delivery.

Retained credits do not reapply new-credit `ACTIVE` admission when flushed. In
particular, deprecation alone cannot erase or block delivery of existing owed
funds. Delivery does not override the wallet's asset observation and release
policy: a previously unobserved deprecated asset flushed at or after its grace
deadline may still be unavailable for recipient release. Existing observed
assets retain their wallet exit rights.

Both credit methods, both flush methods, and producer administration share a
reentrancy guard. The inherited `raiseGasParameter` method instead requires its
separate exact canonical governance action. An independently authorized
raise-only action may execute during a token callback; it cannot change that
call's cached transfer destination or duplicate owed funds.

`EscrowCreditCreated` records the credited amount, new **per-key** total, and
captured **wallet** runtime hash in the normative `escrowRuntimeCodeHash` field.
`EscrowFlushed` records the delivered amount and zero remaining key credit.
These events distinguish official deposits from counterfactual wallet balances
and passive donations. Zero credits are rejected; repeated completed flushes
revert `NoEscrowCredit`.

## Validation boundary

The focused suite uses actual factory deployment and split-wallet money flows,
including the 64-entry wallet, native/ERC-20 credits, prefunding, deprecation,
rollback, and Safe 1.4.1 threshold execution. All escrow views and financial
entry points are exercised from a real Safe; direct Safe attempts to bypass
executor-only governance are rejected with both the exact protocol error and
Safe's failed-execution result. Target-side governance fixtures do not prove the
full Safe-to-Executor timelock route.

Fault-injection wallet/factory seams separately test native deposit gas and
return-data behavior; they are not official deployment evidence. The 16-million
gas maximum-entry calls and test constructor budgets are fixture measurements,
not fully cold transaction sizing or final deployment recommendations. Recovery
from a poisoned address or factory/runtime incident needs the separately
specified recovery protocol; this first line fails closed and retains owed funds.
