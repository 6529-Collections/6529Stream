# One-way mint phase freeze

The additive `IStreamMintPhaseFreeze` capability freezes an existing phase through
its immutable Ledger. It implements the [Freeze Policy](../mint-policy-and-accounting.md#freeze-policy)
restrictions. The permanent Manager and Ledger interfaces remain unchanged.
This is an implementation batch with authored regression tests; complete current-stack
native execution and release acceptance remain pending.

## Governance ceremony

1. Read the actual Manager phase, gate, counter configurations, effective Ledger
   definitions and `phaseExecutors(collectionId, phaseId)`. Freeze is irreversible.
2. Ensure the exact Manager selector is admitted as class 2 (`TERMINAL_FREEZE`).
   The current deployment and activation catalogs include this additive row.
   `StreamMintPhaseFreezePlan.classifier` prepares the separate original class-0
   Executor self-call registering this exact codehash-pinned freeze selector.
3. Obtain `phaseFreezeTransitionHashes(collectionId, phaseId)`, or use
   `StreamMintPhaseFreezePlan.freeze` to prepare the exact class-2 call.
   The scope binds chain, Core, Manager, Ledger, collection and phase. The old/new
   state hashes bind the current policy and the false-to-true transition.
4. Schedule and execute through the original Governor/Executor flow. Its original
   72-hour terminal-freeze veto floor and guardian veto apply. A changed current
   policy makes a scheduled freeze stale; prepare a new exact action.
5. Verify `phaseFrozen`, the canonical Ledger `phaseFreeze` record and the Manager
   event `MintPhaseFrozen(1, collectionId, phaseId, true, policyHash)`.
   Failure rolls back both state and events. Repeated freezing is rejected.

Manager remains owner-only, guarded against reentrancy, and independently checks
its immutable governance authority's executing class, action ID and exact state
commitments. Direct Governor Safe calls do not grant Manager-owner authority.

| Manager call | Selector |
| --- | --- |
| `freezePhase(uint256,bytes32)` | `0xaf55aad7` |
| `phaseFrozen(uint256,bytes32)` | `0x7ac39ad4` |
| `phaseExecutors(uint256,bytes32)` | `0xd15ce698` |
| `phaseFreezeTransitionHashes(uint256,bytes32)` | `0x718a5d2b` |

The Manager capability ID is `0x75408bb0`; the separate Ledger freeze capability
ID is `0x364317e1`.

## Retained behavior

Freeze does not change the active policy hash, immediate predecessor grace,
recorded consent, counters, replay state or existing tokens. Phase dates, gate
pins, counters and configuration are already initial-only in this Manager.
Freeze additionally forbids adding an executor, including one removed earlier.

Removing an executor still requires the exact resulting Artist consent. The
original [grace rules](mint-policy-grace.md) apply: only the immediate predecessor
may remain live, the execution-relative maximum is 30 days, and a real change
with zero grace clears the predecessor. An unchanged executor operation with
zero grace is a no-op; nonzero grace on a no-op is rejected. Removed executors
cannot use a retained predecessor policy. Pause and unpause remain available.
Current Artist authority and every mint eligibility check still apply.

## Successor continuity

Follow the original [import and cutover sequence](mint-continuity.md). Before
`completeCounterImport`, call `importPhaseFreezes(root, maxCount)` with 1 through
32 until `mintImportFreezeProgress(root)` reports every captured freeze copied.
This requirement is independent of leaf counts, counter definitions and ancestry.
Partial copying cannot authorize consumption or Core cutover. Repeating completed
copy work before sealing does not duplicate or expand its executor ceiling.

A frozen phase cannot move to a different Ledger. A same-Ledger successor inherits
the complete frozen inventory, including phases it has not yet configured. Its
first configuration seeds actual executor storage from `frozenPhaseExecutors`
before calculating a fresh successor-bound policy and checking fresh Artist
consent. Failed configuration rolls all seeded executor writes back. Subsequent
registration must preserve the frozen terms and can only shrink the executor set.
A preconfigured candidate is checked when the freeze is copied.

The Ledger retains exact Core/Registry/Ledger bindings, phase terms excluding
pause, gate pins, ordered counter configurations and effective counter-definition
selections. Snapshot royalty configuration has a Manager-bound wrapper hash:
the Ledger first verifies that original hash against the actual royalty policy,
then compares the full retained economic terms under an explicitly tagged
configuration branch. Only the Manager domain may change; resolver, runtime,
election, assignment, source policy and application terms remain exact. Raw
unconfigured royalty terms use a distinct branch and retain their original hash.

`phaseFreeze.policyHash` is the original first-frozen policy provenance. It is not
the successor's current policy or consent. The import receipt reports successor
policy zero when that phase is not configured; the inherited configuration hash
still marks it frozen. Inventory and constraints persist through later replacements,
even when an intermediate Manager never configures that phase.
