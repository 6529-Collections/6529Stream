# Preparing native surplus recovery

The six current native sale hosts expose the original governed
`sweepNativeSurplus(amount, reasonHash)` capability. This operator workflow
prepares its admission and delayed action without signing, broadcasting or
moving funds. It implements the operator side of SSA-ADAPTER rule 15; the
host remains responsible for canonical authority, solvency and transfer.

Supported hosts are the native fixed-price/price-program adapter, Dutch
adapter, clearing adapter, refund-window sale, English auction and private
sale/inventory adapter. Amounts are full-width integer wei. This workflow has
no token, NFT, arbitrary recipient, payment-intent or fee-conversion field.

## Select and retain the source

Use `script/current/PrepareNativeSurplusRecovery.s.sol` and its fixed
`StreamNativeSurplusRecoveryPlan` library. Supply all eight `Pins` fields:
adapter/address code hash, Core/address code hash, ModuleRegistry/address code
hash and Executor/address code hash. Obtain these from the retained deployment
and current code reads. Matching a supplied hash does not authenticate that
deployment by itself.

Preparation checks code and the adapter's original Core, Registry and
governance getters, then reads its real surplus quote. It independently rebuilds
the unchanged host scope and state preimages, retaining the actual current
liabilities, sweep revision, cumulative swept amount and emergency-role tuple.
There is no recipient argument: the quote resolves ROLE_EMERGENCY_RECIPIENT
through the original canonical governance graph.

## Admit a missing selector

First inspect the retained current governance catalog history. Its onchain
read exposes the aggregate commitment, not enumerable admission entries.
The helper does not infer that a selector is absent.

If missing, call `prepareAdmissionInventory(pins, targetProfileHash)`. Retain
the full inventory bytes and returned inventory hash. It contains exactly one
class-1, zero-value CALL row for the selected adapter's original sweep selector.
The target profile must identify the operator's actual deployment/admission
profile. Existing or conflicting entries must not be silently replaced.

Create the genuine manifest payload and original `StreamSystemManifestUpdate`
through the existing manifest tooling. Call `prepareAdmissionStage` with that
payload, update and the retained inventory/hash. It returns a separate class-3
saved stage: the exact Executor catalog extension followed by the mandatory
SystemManifest publication. It creates no payload or governance action.
The amount field in these admission parameters is unused; use zero.

Publish and schedule the returned calls through the existing saved-stage
workflow. The scheduling caller is the actual current governance root,
including a threshold Safe, and every call has value zero. After the delayed
admission executes, confirm the catalog/manifest readback and prepare a fresh
sweep. A sweep prepared under the prior catalog cannot be reused.

## Prepare and execute the sweep

Call `prepare(pins, parameters)`, where parameters contain amount,
notBefore, expiresAfter, reasonHash, reasonURI and manifestHash. The original
Executor's class-1 delay and submission window apply. Retain all returned
bytes/hashes before signing:

- `encodedRecovery` and `savedRecoveryHash` bind the source pins, quote and plan.
- `encodedPlan` and `savedPlanHash` are the original version-2 saved-stage format.
- `publication` is a permissionless zero-value CALL to publish exact calldata.
- `scheduling` is a zero-value CALL from the named governance root.

The recovery envelope has schema version 1. The per-call scope/old/new values
are the host's original commitments. The saved stage's scope/old/new values
are the separately derived aggregate batch commitments. They are not
interchangeable, even for one call.

The read-only `run()` entry supports engineering chains 31337 and 11155111
and reads:

```text
STREAM_SURPLUS_PINS          abi.encode(Pins), eight static ABI words
STREAM_SURPLUS_AMOUNT        integer wei
STREAM_STAGE_NOT_BEFORE      uint64
STREAM_STAGE_EXPIRES_AFTER   uint64
STREAM_STAGE_REASON_HASH     nonzero bytes32
STREAM_STAGE_REASON_URI      original governance reason URI
STREAM_STAGE_MANIFEST_HASH   nonzero bytes32
```

After scheduling, take the action ID from its confirmed matching receipt.
`execution(encodedRecovery, savedRecoveryHash, actionId)` verifies that
action against the original journal and returns the exact permissionless
Executor CALL. Check the saved time window before submitting; the actual
Executor enforces it. A Safe uses ordinary CALL, operation 0, value 0.
The transfer value comes from the adapter's surplus, never from the Safe call.

The existing `ExecuteSavedGovernanceStage` can also execute the retained
`encodedPlan`/`savedPlanHash` and receipt action ID. No new broadcaster,
signing domain or governance exception is introduced.

A changed liability balance, sweep revision, canonical role witness, root or
catalog requires a separately prepared and authorized action. The original
failed action remains in history. Donations alone do not change the host
transition preimage; they are additional surplus. If the named recipient
rejects transfer and the relevant source state remains unchanged, the same
complete signed Safe transaction can be retried after that callback is repaired.

## Read completion and owed funds

`completion(encodedRecovery, savedRecoveryHash, actionId)` joins the exact
executed action to the adapter's original used-action flag and monotonic sweep
state. It returns the saved recipient/amount, current accounting, solvency and
whether this is still the latest sweep. It does not reconstruct event logs.

The same read remains valid after original creditor claims, donations and later
sweeps. It does not require that current balances equal the historical quote.
If `execution` observes an already completed action, it returns
`alreadyExecuted=true` and an empty next call. It never proposes a new sweep
to repeat the old effect. Verify source pins and retain the original receipt
and event evidence independently.

The original account/self-claim and delegated claim routes stay unchanged.
[Native sale-credit export](native-sale-credit-export.md) remains the separate
complete ledger enumeration/reconciliation workflow. Neither export nor this
read grants authority over an owed balance.

## Validation boundary

Six new authored cases use actual current Core, Artist, Manager, Registry,
Executor, RoleRegistry and threshold Safes through the original fixed-sale
fixture, retaining its external entropy-service double. They cover a nonzero
prior sweep revision; original per-call versus aggregate hashes; delay,
donations, claims and later-history reads; exact two-call late-recipient
failure and byte-identical Safe retry; liability drift; role round trips;
journal/runtime/authority rejection; and actual missing-selector admission
with its SystemManifest tail and fresh post-admission sweep.

The new files pass ABI/type checking. Native test execution and joined runtime
acceptance remain with the integrator. The generic six-host capability is
preserved without editing any deployed host; these new operator recipes do
not claim six independently executed sale scenarios.
