# Mint phase freeze callers

These callers prepare and inspect the original one-way phase freeze backed by
the Manager's immutable Ledger. Freezing permanently restricts the phase's
configuration and remaining executor set. It does not grant mint authority.

## Governance sequence

This workflow covers ordinary governance with the system manifest bound and
sealed. The separate committed-genesis scheduling exception is outside this
client profile.

1. Capture the actual Manager, Ledger, Core, ModuleRegistry and Governance
   Executor at a concrete block. Review the complete phase, gate, ordered
   counters, effective counter definitions, royalty terms and executor set.
2. Check the exact Manager `freezePhase(uint256,bytes32)` classifier. If it has
   not been registered, prepare a separate class-0 Executor self-call to
   `registerFreezeSelector(manager,selector,true)`. The registration pins the
   Manager runtime and the next original configuration revision.
3. Prepare the Manager freeze as class 2, `TERMINAL_FREEZE`. Its per-call scope
   binds chain, Core, Manager, Ledger, collection and phase. Old and new state
   hashes bind that scope, the current policy and the false-to-true transition.
4. Publish the exact calldata, then schedule it through the original Governance
   Executor. Ordinary sealed governance requires at least 72 hours before
   execution, an execution window of at least seven days, and expiry no later
   than 365 days after scheduling. Guardian veto and original role, catalog and
   manifest checks still apply.
5. Recheck the original action and current phase before execution. A changed
   policy makes the retained transition stale. Inspect the Ledger and Manager
   events and canonical retained freeze after the actual transaction.

Classifier registration is a separate action. Its class-0 window has no minimum
delay and requires a positive open window; the original 365-day lifetime and
timestamp headroom checks still apply. A Governor Safe's direct Manager call
does not establish the executing class-2 authority required by the Manager.

The client creates unsigned calls. Use the exact operation caller and the
existing [ordered Safe CALL planner](safe-call-plans.md) for steps whose caller
is a Safe. Publish, schedule and execute are separate dependent transactions;
simulation does not apply earlier steps or prove Safe owners and signatures.

```js
const capture = await captureMintPhaseFreeze(
  provider, deployment, { collectionId, phaseId }, { blockTag }
);
const prepared = prepareMintPhaseFreezeGovernance(
  capture, "freeze", proposer, window
);
const publication = prepareMintPhaseFreezeGovernanceOperation(
  prepared, "publish", uploader
);
```

The capture uses the Manager's actual executor inventory, not a caller-supplied
membership list. Its `configurationHash` is reconstructed from the complete
original phase and effective definitions. An inherited unconfigured phase has
no current policy or configuration input to reconstruct; its retained Ledger
record and executor ceiling remain available for review.
This workflow uses an existing collection and a nonzero phase ID as its review
scope. The phase may be absent when registering the classifier; preparing the
freeze itself requires a configured current policy. The pure
`prepareMintPhaseFreezeClassifier` helper is independent of phase coordinates.
The workflow compares the complete captured phase before scheduling or
execution. Changed pause or grace observations require a fresh review even when
they leave the original freeze transition hash unchanged.

## What becomes permanent

The canonical Ledger record contains two commitments:

| Field | Meaning |
| --- | --- |
| `policyHash` | The policy at the first freeze, retained as provenance across successors |
| `configurationHash` | The immutable phase constraints, including exact effective counter and royalty terms |

`phaseFrozen` means the Ledger's `configurationHash` is nonzero. An inherited
freeze can exist before the successor configures that phase. Its current policy
may therefore be zero even though its original freeze provenance is nonzero.

The configuration commitment includes chain, Core, Registry, Ledger, collection,
phase, dates and limits, gate pins, ordered counter configurations, the
`defined` flags and full effective counter definitions, and complete royalty
terms. It excludes the Manager domain and normalizes pause to false.

For configured snapshot royalties, the original Manager-bound royalty wrapper
must first match the actual full royalty policy. Only then is that wrapper
replaced by its application configuration hash for the freeze commitment.
Resolver, runtime, election, assignment and source-policy terms remain exact.
Unconfigured royalties use a distinct branch and retain the original raw phase
configuration hash. These branches cannot substitute for one another.

Freeze preserves the current policy, predecessor grace, recorded consent,
counters, replay state and existing tokens. Executor removal remains possible
with the original resulting Artist consent and
[policy-grace rules](current-mint-policy-grace.md). Each removal shrinks the
Ledger's remaining executor ceiling. An executor cannot be added back later.
Pause and unpause remain available; they grant no new mint rights.

## Successor copying

Use the original [Mint continuity workflow](current-mint-continuity.md) for
import commitment and cutover. A nonempty frozen inventory can move only to a
successor using the same Ledger.
This client inspects already-committed roots and bounded freeze copying using
the same Ledger, including roots with no frozen phases. It does not prepare a
new import commitment or the final completion call.

```js
const capturedImport = await captureMintPhaseFreezeImport(
  provider, successorDeployment, { importRoot, predecessorManager }, { blockTag }
);
const copy = prepareMintPhaseFreezeImportOperation(capturedImport, copier, 32n);
```

`successorDeployment.manager` is the successor; `predecessorManager` supplies
the predecessor's address and reviewed runtime hash. A copy call grants no
permission to complete the rest of the import or activate the successor.

Before `completeCounterImport`, copy the frozen inventory with
`importPhaseFreezes(root,maxCount)`, where `maxCount` is from 1 through 32.
`mintImportFreezeProgress(root)` reports the copied and required counts. This
is an additional completion condition alongside counter, nullifier, definition
and ancestry copying. A completed import rejects further freeze-copy calls.

The capture retains up to 32 upcoming phase pairs; compatibility is checked for
the selected copy count. A later incompatible phase does not prevent an earlier
valid prefix from being copied. Import completeness is separate from current
successor readiness: a completed import remains complete after its successor
loses writer access or retires.

An unconfigured successor receives the immutable constraints and remaining
executor ceiling first. Its first configuration seeds the actual executor set
from those retained rights before computing its new Manager-bound policy and
checking fresh Artist consent. Failed configuration rolls back those writes.
Configured successors must satisfy the retained terms and executor subset when
the freeze is copied.

`MintLedgerPhaseFreezeImported.successorPolicyHash` may be zero for an
unconfigured successor. The event's predecessor policy remains first-freeze
provenance. Neither value is new consent. The restrictions continue through
later replacements, including a Manager that never configures the phase.
If a compatible successor freeze already exists, copying preserves that
successor's own first policy record; it may differ from the event's predecessor
policy. Copying does not duplicate its frozen inventory entry.

## Evidence and retry

The first freeze emits `MintLedgerPhaseFrozen` from the Ledger before
`MintPhaseFrozen` from the Manager. Repeating the Manager freeze reverts.
Historical evidence must retain the first policy and configuration commitments;
it must not rewrite them to a later current policy.

Freeze copying is permissionless while the original import is open and its
successor is not retired. A copy after its cursor has reached the required count
can succeed without emitting another import event, until the original import
is completed. An eventless receipt needs prior-state evidence; an end-of-block
progress value alone cannot attribute multiple same-block transactions.

Runtime pins, exact original calldata, canonical return values, original events
and concrete block hashes form the inspection evidence. The original exact
schedule or execution simulation remains necessary for authority, classifier,
guardian and catalog admission. A prepared action or successful inner call does
not prove actual Safe execution or final release acceptance.

## Inspection bounds

The client inspects at most 256 frozen phase identities per Manager and accepts
governance catalogs with at most 1,024 entries. The original limits of 16
counters and 64 executors per phase remain in force. RPC byte returns are
bounded to 32,768 bytes, pinned runtimes to 65,536 bytes and outer transaction
calldata to 262,144 bytes. Retained calldata-publication runtime is bounded to
24,576 bytes, `reasonURI` to 2,048 UTF-8 bytes and each guardian-role holder
count to 64.
Receipts may contain at most 256 logs, with four topics and 16,384 data bytes
per log.

A receipt must be mined after its capture block. Governance receipt inspection
requires the exact phase state at the end of the receipt block. Import events
identify copied ordinals; observed progress can include later copies in that
block. Import completion or successor retirement in the same receipt block is
outside the copy-receipt profile. Eventless copying additionally requires
prior-block evidence that all required freezes were already copied, with the
full import commitment unchanged at the end of the receipt block. Same-block
counter or nullifier imports therefore prevent eventless attribution here.

## Frozen source

The additive fixture uses `parallel-feature-batch59-20260920` at
`0ab602042dbbb1f141aea0d9cbb37bd9617345cf`. All 2,269 literal compiler inputs
were verified byte-for-byte against Git. Earlier policy-grace and continuity
fixtures retain their original source pins.

```sh
node scripts/generate-current-mint-phase-freeze-fixture.mjs \
  /path/to/abi-input.json /path/to/abi-output.json --check
```

Client, mocked-RPC and source checks do not establish native current-stack,
actual Safe, gas, genesis or deployment acceptance. The integrator owns that
separate execution evidence.
