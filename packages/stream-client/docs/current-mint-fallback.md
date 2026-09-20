# Mint Manager fallback ceremony

The current fallback helpers target the production interfaces frozen at
`d1a58e4403cfbb80d921e117e0a7ac9b90ff61c7`. A distinct, pre-admitted fallback
Manager replaces the existing `MINT_MANAGER` pointer and uses the same canonical
Ledger. Each Manager has a separate accounting namespace, so activation still
requires a genuine import of the retired primary's counters and raw nullifiers.

The [frozen contract integration guide](https://github.com/6529-Collections/6529Stream/blob/d1a58e4403cfbb80d921e117e0a7ac9b90ff61c7/docs/integrations/mint-manager-fallback.md)
owns the ceremony's operational sequence. These clients prepare unsigned calls,
reconstruct original commitments and inspect concrete-block evidence.

## Before an incident

Supply all fields of `MintFallbackConfiguration`: chain, Core, Ledger, primary,
fallback, registry and GovernanceExecutor addresses; their runtime hashes;
the reserve's exact module metadata; and the optional prepared-native recorder
address/hash pair. Both Managers must have the same expected owner and immutable
governance authority. Their gate and Artist gas registrations are checked
independently.

The fallback retains the original Manager interface advertisement. Its additive
`recoverPreparedMint` method uses the explicit recovery ABI and reviewed runtime
pin. It does not advertise a new recovery ERC-165 interface.

`inspectMintFallback(provider, configuration, { blockTag, readiness: "configuration" })`
supports the initial configuration stage. The default `readiness: "reserve"`
also requires the ACTIVE fallback's exact catalog record, canonical Ledger,
eligible dependencies and a live, non-retired fallback writer.

A zero recorder address/hash pair explicitly selects ordinary-mint-only
inspection. For prepared native sales, use the actual recorder pair and bind it
to both Managers before exposure. Inspection checks runtime and immutable
Core/registry pins, interface support and the original admitted lifecycle at
each Manager's retained binding. This includes the qualified historical
DEPRECATED case; an arbitrary deprecated or revoked recorder does not qualify.

Install the action policies required by the contract guide. Also execute
`mintFallbackRetirementClassificationCall` as an **isolated class-1 Executor
self-call** with its ordinary delay. It sets the exact Ledger retirement selector
as tightening against the current Ledger runtime. A class-0 catalog entry alone
does not satisfy this independent classification.

## Preserve the action sequence

| Stage | Class | Prepared target calls |
| --- | --- | --- |
| Retirement classification | 1 | Executor `setTighteningCall`, alone |
| Permanent primary retirement | 0 | Ledger `retireLedgerWriter` |
| Import commitment | 1 | Ledger `commitCounterImportRoot` |
| Definition and ancestry copying | 1 when batched | Original bounded Ledger import calls |
| Counter and nullifier import | 1 | Fallback `importMintState` |
| Import completion | 1 when batched | Original descriptor completion call |
| Normal activation | 3 | Core Manager pointer, then SystemManifest publication |
| Incident activation | 3 | Core Manager pointer, exact prepared recovery, then SystemManifest publication |

Definition copying, ancestry copying and descriptor completion retain their
permissionless contract entrypoints. Their inclusion in a governed batch provides
an ordered ceremony; it does not replace the Ledger's checks. Manager imports and
retirement retain their original owner requirements. Governed target calls must
execute through the actual Executor. An ordinary Safe CALL directly to a target
cannot supply its executing action context.

Record the primary's actual `INCIDENT_REVOKED` transition using the original
registry-status governance batch and required manifest tail. Resolve supported
old mint obligations or their cancellation/refund exits, retire the primary
permanently, then freeze and review its real accounting inventory. Merely
disabling its writer is insufficient.

Class-1 import and class-3 activation can be scheduled in parallel. Both keep
their ordinary 48-hour minimum delay. The documented incident objective is to
schedule activation within four hours; the client does not invent a new contract
deadline or bypass the governance delay. Execute the import before activation.

## Use the real import evidence

The artifact-based import composers reuse the
[mint continuity format](current-mint-continuity.md): original counter definitions,
subject keys, counter leaves, raw nullifiers, ancestry and descriptor proof.
The artifact must identify this exact same-Ledger primary-to-fallback pair.
The snapshot must follow permanent retirement and cannot be in the future.

An import root or a zero-count example is not proof of a complete historical
inventory. The caller's completeness review remains explicit. Concrete source
reads can verify the supplied leaves and retained import progress; they cannot
discover omitted historical leaves from an arbitrary supplied manifest.
Each copying call accepts at most 32 entries. A Manager state-import batch has
1–32 combined counter/nullifier leaves with matching proof arrays.

Unknown supplied roots can be planned before commitment. A known root must bind
the exact predecessor Ledger, primary and fallback. Current readiness additionally
checks genuine completion, definition/ancestry progress and successor eligibility.
Retirement and completed imports are not generic idempotent retry operations.

For external inventory producers, the separate `mintFallbackRaw*` composers
accept the original snapshot, import batch or descriptor shapes. Their structural
validation does not establish a complete historical inventory or genuine proofs.
The original Ledger remains the proof verifier.

## Prepare a caller-specific governance operation

Pure call plans carry `factsVerified: false`. Prepare a live operation from a
concrete-block inspection and retain its reconstructible original request:

```js
const inspection = await inspectMintFallback(provider, configuration, {
  blockTag: reviewedBlock,
  importArtifact: reviewedArtifact,
});
const activation = await captureMintFallbackActivation(provider, configuration, {
  blockTag: reviewedBlock, manifest, payloadRoot, update,
});
const plan = mintFallbackActivationCalls(configuration, activation);
const prepared = prepareMintFallbackGovernance(inspection, plan, proposer, window);
const publication = prepareMintFallbackGovernanceOperation(prepared, "publish", publisher);
await simulateMintFallbackOperation(provider, publication, { blockTag: simulationBlock });
```

The `window` contains exact `notBefore`, `expiresAfter`, `reasonHash`, `reasonURI`
and `manifestHash`. Publishing call data, scheduling and execution are distinct
operations. Read each receipt before advancing, and simulate the next operation
at its intended concrete block. The scheduling caller must be the retained
proposer. Execution can use its actual permissionless caller after authorization
and readiness. All prepared outer calls carry zero native value.

`prepareMintFallbackGovernanceOperation` accepts `"publish"`, `"schedule"` or
`"execute"`. `prepareMintFallbackPermissionless` handles the original direct
definition, ancestry and completion entrypoints. Both use
`simulateMintFallbackOperation` and `inspectMintFallbackOperationReceipt`.
Provide the transaction hash and `execution: "direct"` or `"safe"` to the latter.

The [Safe example](../examples/current-mint-fallback.mjs) reviews one concrete
stage at a time. It displays the actual caller, proposer, action ID, delay window,
exact inner target calls and each transition hash. The submitted Safe operation
is an ordinary CALL to the Executor for governed stages. The example retains
full-width integer text and does not sign or submit transactions.

## Keep exact recovery and publication commitments

An incident operation identifies the exact pending token and operation ID.
Recovery hashes bind its collection, actual serial, global allocation frontier,
collection frontier, lifetime minted count, live supply, token bytes and original
coordinator. The pure `mintFallbackRecoveryTransition` retains the original
`6529STREAM_MINT_FALLBACK_RECOVERY_SCOPE_V1` and
`6529STREAM_MINT_FALLBACK_RECOVERY_STATE_V1` preimages with full-width integers.

Pointer replacement retains every original pointer field and increments its
revision. The publication tail retains all prior manifest modules, discovery
hashes, URI, payload pointer and revision; its only module replacement is the
Manager. Each call has its own `scopeHash`, `oldValueHash` and `newValueHash`.
The aggregate governance schedule fields do not substitute for those per-call
commitments.

Recovery's actor is the immutable GovernanceExecutor, also the fallback owner
and selected registry's executor, inside the exact executing class-3 call.
The dedicated facade can abort that prepared record. It has no forwarding API
to prepare, complete or redirect a mint.

A failed activation batch rolls back pointer replacement, recovery and manifest
publication together. The original scheduled action can be retried if its
committed facts remain unchanged and it remains executable. Changed supply,
frontiers, pointer or manifest facts require a newly authorized proposal and the
applicable delay. The client must not silently refresh a scheduled commitment.

## Interpret receipt and poststate evidence

The recovery event comes from the fallback Manager and binds schema version 1,
action ID, token ID, operation ID and collection ID. Its action/token/operation
fields are indexed. Join that event with the actual Executor execution and Core
abort evidence from the same successful transaction.

Recovery clears the abandoned prepared record, identity, token bytes and
coordinator binding. It preserves the allocation frontiers, so the abandoned ID
and serial remain consumed. Completed and burned history and lifetime accounting
remain intact. These are execution-local contract postconditions; later
transactions in the same block can change live supply and allocate new IDs.
End-of-block observations must be labeled separately from events attributed to
the recovery transaction.

The receipt result exposes `observed` and an explicit `stateAttribution` label.
Copying progress is also an end-of-block observation: later calls can advance it,
and ancestry copying can skip duplicate pairs without emitting an entry event.
An event count is not an exact processed-cursor delta. If the pointer or manifest
still has the expected post-operation revision, the helper compares its full
state with the reviewed transition.

After activation, obtain fresh Artist consent and configure successor-bound
phases, executors and sale routes. Old consent and immutable old adapters do not
silently acquire the fallback domain. Existing custody and refund liabilities
retain their original contracts and recovery APIs. Returning to the retired
primary by swapping addresses is unsupported.

## Frozen evidence

The [main ABI fixture](../test/fixtures/current-mint-fallback-abi.json) projects
236 compiler entries from the clean 988-source fallback capture. Every literal
source matches the frozen Git commit byte for byte. The
[paid recorder fixture](../test/fixtures/current-mint-fallback-recorder-abi.json)
retains five getters from the separate integration ABI43 capture at `23e45d78`.
The concrete recorder and its getter-bearing base source match the fallback
commit exactly; the other integrated sources are not asserted identical.

```sh
node scripts/generate-current-mint-fallback-fixture.mjs FALLBACK_INPUT.json FALLBACK_OUTPUT.json --check
node scripts/generate-current-mint-fallback-recorder-fixture.mjs ABI43_INPUT.json ABI43_OUTPUT.json --check
```

Source/ABI fixtures and controlled client tests establish encoding, validation
and evidence handling. They do not replace actual current-stack and Safe
execution, complete genesis composition, gas-capacity or release acceptance.
