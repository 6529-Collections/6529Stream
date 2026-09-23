# Artist recovery adjudication and current notices

This separate client follows current-notice producer
`3ac39b556f17e938c5de2b7401429a2f8903ceb3`, including the adjudication V2 base
`674b96f93edafb60d652fc02e0e270f4434377da`. It targets the actual V2 publisher,
selection worker and operation-35 Registry calls. Earlier Artist callers and
fixtures retain their original source profiles. Unfinished rewind V3 interfaces
are outside this client.

The supported producer handles current living/class-1 and estate/class-3
compromise or standing-veto causes, including declared vestings, an explicit
absence of contested vestings and current living notices. Class-4 recovery,
non-guardian record rewinds and broader hydration are separate domains.

## Evidence publication is a separate step

Identity's `recoveryEvidenceBinding()` supplies the fixed publisher address and
runtime hash. Its constructor bindings include Identity, Registry, Coordinator,
Archive, Core, Manager and chain. Publication is permissionless and preserves
immutable content; it grants no recovery authority or replay right.

A resolution manifest retains:

- Artist ID and the owner revision before registration preparation.
- Exact native cause, resolution head and actual executed authority head.
- Request commitment and opaque resolution-evidence hash.
- Explicit contested-vesting basis and original vesting references.
- Exact sorted guardian record exclusions.

The request commitment excludes only `Request.evidenceHash`. It preserves the
new address, vested class, cause, resolution, reason and exclusions. The actual
evidence hash is still bound by the V2 context and scheduled calldata. The
manifest hash also binds the original environment and Identity runtime hash.

`DECLARED_VESTINGS` requires one or more genuine executed references, in original
execution order from oldest to newest. Do not sort their hashes to manufacture
chronology. `NO_CONTESTED_VESTING` requires an empty declared list; authenticated
execution ancestry may still exist. The original owner checks that complete
ancestry. A client-supplied list does not replace it.

Publisher limits are 64 declared vestings and 64 excluded guardian records.
Exclusions must already be nonzero and strictly sorted. These limits bound the
published declaration, not the length of actual authority history.

Ordinary recovery uses the manifest's resolution-evidence hash as the request's
evidence hash. APPEAL uses a separate V2 appeal document hash. That document names
the exact manifest, opaque hostile-findings commitment and complete expected
guardian findings. Findings are sorted by guardian record; each has 1–8 strictly
sorted, nonzero parties. There are at most 64 findings. The owner authenticates
the expected records, parties, role and protected directive; publishing a
well-formed appeal does not prove those conditions.

Governance attests that the declaration covers the opaque evidence's contested
set. Neither the contract nor these codecs can interpret an offchain document's
meaning.

## Complete guardian selection

Identity's `recoverySelectionPreparationBinding()` identifies the fixed worker.
The owner supplies its authenticated basis: manifest, Artist, owner runtime,
original guardian-history head and source commitment.

1. Begin the exact manifest with `beginSelectionV2`.
2. Continue its returned source key with positive bounded chunks.
3. Require a completed result through `requireSelectionV2` before preparing
   executable recovery context.

Even a genuinely empty history needs a continuation call to persist completion.
A complete election may select zero with a nonzero result commitment. That is
different from an absent or incomplete preparation. The worker authenticates
the entire original admission prefix and never accepts a caller-invented history.

The operative selected guardian and retained veto membership are distinct.
Members of an ineligible historical admission can retain independent veto
standing. Records permanently superseded by an earlier recovery cannot regain
that standing merely because the new exclusion list is empty. Retained membership
is read from the saved completed selection, so a later owner revision does not
rewrite the earlier action's cohort.

## Original acceptance signature

Recovery preserves the original new-address rotation-acceptance signature.
Its signed fields are only Artist ID, old address, new address, nonce and
deadline. The signing host is the original Artist Registry, using its existing
EIP-712 name and version. The manifest, reason, evidence and guardian exclusions
are reviewed calldata/context commitments; they are not added to this permanent
signature.

The replay lane is the original rotation-acceptance lane for the Artist and new
address, not the ordinary global Artist nonce lane. Signature bytes are limited
to 4,096. Direct execution requires the actual caller to equal the new address
and supply empty bytes. An empty proof from a distinct caller may still be an
ERC-1271 signature; emptiness alone cannot select direct mode.

Normal governed execution calls through the Executor. A recovering Safe must
therefore supply acceptance that its original signature validator admits for
that actual caller. Using the Safe to publish or register evidence does not
turn a later Executor call into direct acceptance.

## Governance, registration and execution

Read `identityRecoveryContextV2` only after publication and complete selection.
The original owner derives whether ARBITER or APPEAL is required. It authenticates
the cause, chronology, guardian policy and timing; a locally constructed plan is
not an independent proof of those facts.

The scheduled action is class 2 and contains exactly one matching
`recoverArtistIdentityV2` call: Registry target, zero value, exact manifest,
request and acceptance bytes, and exact context hashes. The original selector
cannot stand in for the V2 selector.

After scheduling, call `registerIdentityRecoveryActionV2` with that exact action
and call list. Registration is auxiliary operation 65534. It requires the action
to remain SCHEDULED and the full minimum delay to remain before `notBefore`,
measured at registration itself. The source requires at least 72 hours. Scheduling
exactly 72 hours ahead and registering in a later block can therefore fail;
choose a window with explicit registration headroom. Acceptance must remain
valid through `notBefore`. The client does not move reviewed clocks automatically.
The original class-2 action also requires an execution window of at least seven
days and expiry no more than 365 days after scheduling. Acceptance may expire
earlier than the action, so actual execution must satisfy both deadlines.

Registration advances the owner revision once and stores the evidence and action
association. The manifest stays anchored to the earlier revision. Execution
admits exactly this authenticated preparation increment; another owner mutation
requires a new manifest and action. Reusing an earlier manifest for a later
preparation is not supported.

Execution still requires the registered action, current governance authorization,
new-side acceptance, unconsumed cause and absence of the independent retained
guardian veto. Operation 35 installs the recovered authority, preserves original
history and capability origin, and advances the delegation epoch once.

## Current living notice cases

The additive notice profile admits an original living/class-1 operation-33
compromise with prior status 2, its exact operation-41 notice, no pending
transition and authenticated living history. Passing a notice deadline does not
complete the notice or resolve the compromise.

| Original notice state | Successful recovery behavior |
| --- | --- |
| Phase 1, open | The accepted new principal causes one genuine operation-42 cancellation before the operation-35 pair |
| Phase 2, already cancelled | The original terminal is retained; no second cancellation or counter increment |
| Completed operation 43 | Different authority origin, outside this current living-notice path |

The reader authenticates captured notice terms, timing revision, durations,
deadline, incumbent, activity counter, original cause/receipt and historical
staging/execution boundaries. Earlier challenges dismissed back to notice status
retain their exact notice association and first closure.

In phase 1, cancellation and recovery share the new owner revision. The native
operation-42 receipt immediately precedes the adjacent operation-35 primary and
secondary pair. Native journal entries and the owner's semantic sequence count
are separate coordinates; an extra journal entry does not add another semantic
operation to the original pair. Notice cancellation increments its captured
activity counter once. The original notice and deadline stay immutable.

Later V2 recovery authenticates that new-side cancellation through its admitted
operation 35, consumed cause, notice association, vesting and receipt order.
Ordinary incumbent cancellations retain their own rules. A cancellation between
registration and execution changes the owner revision and invalidates that
prepared action.

## Original records and Archive evidence

V2 preserves the original recovery Request, Context return type, new-side
signature, operation-35 semantic record, sorted supersession domain and native
receipt pair. It introduces explicit manifest/context/selection commitments;
these do not relabel the original V1 paths.

Preparation and execution retain the original eight-field Archive envelope.
Only Identity's owner snapshot at index 2 is populated. Preparation's envelope
operation is 65534 and its semantic record word is zero, while its evidence ID
commits to the action association. Execution's operation is 35 and its record
word is the original recovery record.

Without current-notice evidence, the original V2 payload bytes remain unchanged.
With it, preparation wraps the original payload with the preparation tag and
exact cause/notice/phase/terminal bytes. Execution wraps its original payload
with the execution tag and both before/after notice evidence. These internal
source-derived encodings are distinguished from compiler public ABI witnesses.

The signature payload is retained even when empty. Receipt verification must
join stored payloads, native records, original semantic hashes, owner snapshots
and Archive bytes; an event alone cannot establish the complete recovery.
The original receipt getter returns primary and secondary commitments, plus
their occurrence key. These commitments are not the owner's final chain tip.
The client checks the getter and native pair without reconstructing the owner's
private semantic sequence or complete state-root preimage.
Archive failure rolls back acceptance, notice cancellation, replay, receipts
and owner state together.

## Client entry points and bounds

The package exports the pure `current-artist-recovery-adjudication` module and
its separate workflow module. Coordinates identify the original chain, Registry,
Identity and its runtime hash, Coordinator, Archive, Core, Manager, evidence
publisher and selection worker. A workflow deployment adds reviewed runtime pins
for the complete 16-component Artist suite, Coordinator, optional Reads, both
recovery helpers and governance Executor.

```ts
const prepared = prepareArtistRecoveryAdjudicationCall(coordinates, caller, {
  kind: "publishResolutionManifest",
  manifest,
});
const captured = await captureArtistRecoveryAdjudication(provider, deployment,
  prepared, { blockTag });
const simulated = await simulateArtistRecoveryAdjudication(provider, captured,
  { blockTag });
```

`kind` is the exact original method name. The same entry point prepares appeal
publication, publisher reads, selection beginning/continuation/result/membership,
the Registry's V2 context and evidence-state reads. Capture pins one numbered
block and validates its hash, chain, runtime code and reciprocal suite/helper
bindings. Simulation repeats the relevant reads and executes the exact call with
its actual caller and zero value. Neither function sends a transaction.

For recovery governance, capture `identityRecoveryContextV2` after publication and
selection. Pass that capture to `prepareArtistRecoveryAdjudicationGovernance`
with the proposer, original governance nonce and reviewed window. Then use
`prepareArtistRecoveryAdjudicationOperation` for each stage: `publish`, `schedule`,
`register` and `execute`. `simulateArtistRecoveryAdjudicationOperation` checks the
stage's original state and caller. Governed execution uses the Executor's exact
singleton batch; a raw Registry call is not a substitute for this stage.

After an externally submitted transaction, use
`inspectArtistRecoveryAdjudicationReceipt` for publisher/selection writes or
`inspectArtistRecoveryAdjudicationOperationReceipt` for governance stages. Supply
the transaction hash and `execution: "direct"` or `"safe"`. Inspection joins the
mined transaction and receipt, exact calldata and value, expected original logs,
stored evidence and historical state. A Safe receipt must contain a successful
ordinary `CALL` to the reviewed target with the reviewed inner data and value.
It does not authenticate a Safe's ownership policy or establish that a deployed
Safe implementation has been audited.

These limits are explicit:

- The pure continuation encoder preserves the source's positive `uint64` input;
  workflow continuation chunks are limited to 64 records.
- Payload catalog inspection is limited to 1,024 rows per host. Larger histories
  need a separately reviewed caller; this client does not silently truncate them.
- Governance workflows support sealed ordinary class-2 execution. The original
  owner validates ancestry and required authority; client context reads do not
  independently replay private ancestry logic.
- Historical capture and receipt inspection require numbered-block code and
  state reads, including the block before the transaction. Contradictory or
  unavailable historical observations fail inspection.

| Observation | Client limit |
| --- | --- |
| Complete codec envelope, tagged wrapper, original call result or outer transaction data | 524,288 bytes |
| Ordinary RPC read result | 32,768 bytes; publisher reads allow 65,536 |
| Pinned runtime code | 65,536 bytes |
| Archive evidence / its code carrier | 24,575 / 24,576 bytes |
| Receipt logs | 256 |
| Each log's data / topics | 65,536 bytes / 4 topics |
| Notice text in pure codecs | 2,048 UTF-8 bytes |

The 4,096-byte original acceptance limit applies to the inner recovery proof.
Outer Safe signatures instead count toward the complete transaction-data limit;
the client does not apply the recovery limit to that separate signature bundle.

Receipts must be in a strictly later block than their capture. Evidence tied to
the prior block cannot prove arbitrary intervening operations in the transaction
block. Inspection permits later owner observations where it has immutable
operation evidence, but current deny state, notice state and required live reads
can still cause a valid earlier transaction to fail inspection after another
same-block mutation. A failed inspection is not proof that the mined transaction
reverted.

## Source and validation boundary

The additive fixture projects the retained `capture-current-notice-final`
compiler input/output. All 931 literal sources match the frozen commit. Concrete
Executor and Bootstrap evidence is separately identified from retained ABI65;
its entire selected 35-source dependency set also matches the frozen producer.
The Core ABI segment is the compiled `IStreamCore` interface, not a concrete
Core runtime witness.

```sh
node scripts/generate-current-artist-recovery-adjudication-fixture.mjs \
  /path/to/current-notice-input.json /path/to/current-notice-output.json \
  /path/to/abi65-input.json /path/to/abi65-output.json --check
```

The generator performs no compilation and does not refresh earlier fixtures.
Pure codecs and mock-RPC workflow tests establish client behavior, not original
onchain ancestry, actual Safe execution, full current-stack composition, gas
capacity or release acceptance. The producer handoff records authored actual
Artist/Safe/Archive cases with explicitly typed Core and scheduling boundaries;
those tests retain their separate source and execution evidence.
