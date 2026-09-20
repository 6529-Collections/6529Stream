# Mint executor policy grace

Manager's additive `IStreamMintPolicyGrace` capability lets governance change
one phase executor while retaining the immediately preceding policy hash for a
bounded period. It implements the producer for
[MPA-GRACE](../mint-policy-and-accounting.md#policy-grace-windows). It does not
reconfigure the phase's dates, gate, counter set or limits; those remain
initial-only in this Manager.

```solidity
setPhaseExecutorWithGrace(
    uint256 collectionId,
    bytes32 phaseId,
    address executor,
    bool allowed,
    uint64 graceUntil
)
```

The selector and additive ERC-165 interface ID are `0xdef72e30`. The permanent
`IStreamMintManager` ID and original `setPhaseExecutor` ABI are unchanged.
The original method still supplies zero grace on a real executor change.

## Prepare and execute

1. Read the exact current phase, gate, counter definitions and executor set.
   Build the prospective executor set and call `previewPhasePolicyHash` with
   those original phase inputs. The grace deadline is continuity metadata and
   does not enter the deterministic policy hash.
2. Obtain actual Artist consent for that resulting hash through the original
   Artist policy-consent ceremony. A previously recorded consent for the same
   hash can remain valid; an old hash's consent cannot authorize a different
   new hash. The Manager checks current Artist authority again during minting.
3. Schedule this exact Manager selector through the configured governance
   Executor as class 1 (`DELAYED_LOOSENING`), retaining the original exact-target
   code/profile pins and zero-value CALL policy. The current deployment's
   catalog must include this additive row. A Safe Governor schedules the
   ordinary governance action; the Governor is not the Manager owner.
4. After the required delay, execute and verify the Manager executor/policy
   reads and Ledger `policyGrace` tuple. `MintPhaseConsentRecorded`,
   `MintLedgerPolicyGraceSet` and `MintPhaseExecutorUpdated` retain their
   original emitters and meanings. Failure rolls back the executor set,
   Manager hash, Ledger registration and events together.

For mode-2 bindings, the original
[delegated policy-consent ceremony](artist-delegated-consent.md) can supply the
exact record. Revoking or exhausting that grant stops new records; it does not
erase an already-recorded exact consent. Manager still checks current Artist
mint authority at registration and execution. Modes 1 and 2 use recorded
consent; mode 3 retains its separate platform declaration checks.

Supply an absolute Unix timestamp in seconds. Ledger enforces
`graceUntil <= block.timestamp + 2_592_000` at execution. Account for the
governance delay when choosing it. A nonzero deadline in the past is accepted
as an already expired window; equality with the execution timestamp is valid
through that timestamp. Zero gives no predecessor continuity on a real change.

## Authorization and expiry

The batch keeps its original `expectedPolicyHash`, ticket digest, signature
and authorization ID. Only the current hash or the exact immediate predecessor
is accepted. The boundary is inclusive: a predecessor remains usable at
`block.timestamp == graceUntil`, and rejects one second later. A further
rotation replaces the predecessor tuple even if its former deadline has not
passed.

Grace relaxes only policy-hash matching. Current executor admission, Artist
authority, gate checks, phase pause/timing, beneficiary counters and replay
protection still apply. Removing an executor stops that executor immediately.
The ticket's own deadline also remains independently binding. Ledger receipts
retain the caller-bound hash; its operation-root receipt additionally records
the current hash. Token delivery failure rolls back the whole batch and its
counter, authorization and operation-root debits.

Policy hashes remain deterministic. Returning from executor set A to B and
back to A restores hash A. An unused A authorization may then be current again;
a consumed or revoked authorization stays unusable. Use the original full
payload revocation surface when durable cancellation is required.

## Unchanged requests

Calling the additive method with an unchanged executor authorization and
nonzero grace reverts with Ledger's `InvalidPolicyGrace`. It cannot extend an
existing window without rotating policy. With zero grace, an unchanged request
is the original no-op: it preserves any existing grace tuple. To clear grace,
make a real supported policy rotation with zero grace; pause and durable
authorization revocation remain separately available controls.

Initial phase registration always uses zero grace. This capability cannot
create grace before a phase exists and cannot bypass initial-only configuration.

## Acceptance boundary

[Focused cases](../../test/unit/mint/StreamMintPolicyGrace.t.sol) exercise the
actual Manager, Ledger and ticket gate with explicit typed Core, Artist and
governance boundaries. [Current Safe cases](../../test/current/StreamCurrentMintPolicyGrace.t.sol)
join the original Core, Artist, Ledger, gate and governance products, including
two delayed Governor updates, old ticket expiry and exact failed-batch retry.
These cases are authored and ABI/type checked. The bounded size repair and its
exact source are recorded in the [batch evidence note](../../ops/MINT_POLICY_GRACE_ACCEPTANCE.md).
The separate [mode-2 batch](../../ops/MINT_MODE2_CONSENT_ACCEPTANCE.md) adds actual
delegated registration/grace, stale-policy rejection and durable-consent retry
cases. Native test execution, gas measurements and complete candidate acceptance
remain pending the coordinator's matched-source run.
