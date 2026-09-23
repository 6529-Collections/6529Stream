# Artist recovery record rewinds V3

This additive client is pinned to producer
`898669e5c819ae3ac6c5e7f65159b766fb92d299`, tree
`960084faf4eeda849aca6b4837e3d8e2f0732b8f`. Its explicit V3 APIs extend
[V2 adjudication](current-artist-recovery-adjudication.md) with typed exclusions
and restoration across the original Identity and Payout owners. The earlier V2
client and fixture retain their original source profile. Later size factoring
and host bridges are separate source/runtime evidence.

The original recovery Request, new-side acceptance, operation-35 semantic record,
sorted supersession hash and native receipt pair remain unchanged. V3 has new
manifest, selection, preparation and context commitments. This client does not
provide a recovered-history operation-60 hydration profile.

## Immutable evidence and exact typed exclusions

The V3 environment binds chain, Registry, Identity and its runtime hash, Payout
and its runtime hash, Coordinator, Archive, Core and Manager. The fixed helpers
derive Payout from Coordinator owner slot 5. Callers cannot substitute a different
Payout source. Read `recoveryRewindEvidenceBinding()` and
`recoveryRewindSelectionBinding()` on the original Identity owner.

A resolution manifest captures the complete Identity and Payout snapshots and
their native receipt counts, Artist, original cause and resolution, executed
authority head, vesting basis, request commitment, resolution evidence and typed
exclusions. Each typed entry contains a family kind and original record hash.
The list is strictly sorted by record hash across all families and is a one-to-one
partition of the original Request's complete `supersededRecordHashes` list.
Sorting separately within families would produce a different, invalid list.

The request commitment still excludes only `evidenceHash`. The scheduled calldata
and recovery context preserve the actual evidence hash. The V3 manifest, appeal
and payout-original hashes all bind the full V3 environment, including both owner
runtime hashes.

Publication is permissionless, immutable and idempotent. It establishes retained
content, not authority or the semantic validity of the claimed recovery. The
original owners and selection worker perform those checks later. The published
limits are 64 typed exclusions and 64 declared vestings; appeal findings retain
the original limit of eight parties per finding.

## Family selection rules

| Kind | Original operation | Rule after exclusions |
| --- | --- | --- |
| 0: guardian set | 28 | Highest eligible retained nonce; historical veto membership is separate |
| 1: successor designation | 36 | Highest eligible retained nonce |
| 2: estate directive | 37 | Highest eligible retained nonce |
| 3: identity revision | 25 | Follow the actual predecessor branch; zero selects the registration document |
| 4: payout designation | 18 | Follow the actual predecessor branch; zero selects no payout account |
| 5: steward sanction grant | 19 | Highest eligible retained nonce, including a winning `granted=false` record |
| 6: prior-address standing revocation | 51 | Latest retained admission in the exact Artist/address/retirement scope |

A later journal row can carry a lower unused nonce. It does not automatically
replace the winning nonce-based record. Document and payout branches do not
select an abandoned sibling because it has a later nonce or receipt. A retained
ineligible child remains occupied until explicitly resolved or released by the
original dismissal continuation.

Payout's original stored terms omit signer, authority class, nonce and time.
Publish the actual `PayoutOriginalV3` preimage for each selected Artist's
operation-18 record within the captured Payout prefix. The worker joins it to the original
hash, stored terms, native row, Identity nonce digest, admission revision and
provisional/abandonment facts. Publication cannot appoint a replacement payout
or validate an old signature against a Safe's current owners.

Historical operation 25 can retain class 1 in its stored tuple even though its
original hash used class 3. V3 preserves that tuple and authenticates the unique
matching original class/hash/admission. The client must not rewrite the tuple
to make it appear internally uniform. Future source writes store the class
actually used in the record hash. The producer's frozen-writer fixture is a
compatibility test, not evidence of a deployed historical instance.

## Complete dual-owner selection

1. Publish the exact manifest and required original Payout preimages.
2. Call `beginSelectionV3` for that manifest.
3. Continue the returned key in positive bounded chunks until complete.
4. Read `requireSelectionV3` before preparing executable context.

One continuation budget scans Identity first and then Payout. Both captured
native journals are scanned in ascending order, including unrelated Artists.
Unrelated rows contribute to the scan commitment but do not trigger that Artist's
family admission or require unrelated Payout preimages.
Declared exclusions and vestings bound one request; they do not bound lifetime
history. Missing original evidence stops the scan instead of omitting a row.
An empty journal still needs the original completion step.

`selectionV3`, `selectionResultV3`, `selectionRecordV3` and retained membership
expose saved historical evidence. `requireSelectionV3` additionally requires
the live source state. Those purposes remain distinct after another mutation:
historical selection can remain readable while the pending action is stale.

The result commits the captured inventories and every selected family, standing
scope and retained candidate. Zero selection is an explicit result; it is not
an absent or incomplete preparation. The client does not replace the original
worker's admission checks with a caller-supplied record list.

## Directives, guardians and estate capabilities

The V2 vesting, provisional and hostile-guardian APPEAL rules still govern the
guardian partition. Governance adjudicates the non-guardian exclusions; original
records, family, Artist, admission and resulting plan remain authenticated.

For protected guardian history, both the original operative directive and the
restored directive must permit guardian changes. Excluding a banning directive
in the same request cannot bypass that protection. The check also applies to a
retained provisional guardian under NONE when ARBITER otherwise suffices.
APPEAL keeps its original root-authority requirements.

A selected designation's nonzero paired directive must be retained and belong
to the same Artist. An excluded pair rejects the plan; no automatic relinking or
fallback to a lower designation occurs. A retained ineligible candidate is also
checked so its later maturity cannot revive an excluded pair. Future original
36 writes reject a permanently superseded paired directive before consuming
authorization.

Class 3 requires a selected designation and an eligible paired directive when
one is named. Effective capabilities are the designation's grants, intersected
with its paired directive's grants, minus the restored operative directive's
prohibitions, within the original 4095 mask. A missing designation does not
silently convert estate authority to steward authority.

The original operation-40/43 activation remains immutable. A V3 capability
continuation records the restored mask and original activation origin. Later
rotations may change the address; later V2/V3 recovery follows the actual
operation-35 ancestry and frozen selection to authenticate that continuation.

## Registration and the worker-owned preparation seal

Both owner snapshots and both receipt counts must remain exact. An unrelated
Identity or Payout mutation invalidates pending selection/action execution.
The single permitted change is the actual auxiliary operation 65534:

1. Obtain the original V3 context and schedule its exact singleton class-2 call.
2. Register that scheduled action through the original Registry.
3. Identity commits its association and pre-preparation source observations.
4. Under the same Coordinator lock, the worker verifies the actual pending
   action, the one-revision Identity increment, unchanged native count and
   unchanged Payout source, then seals the complete post-preparation snapshot.

The seal belongs to the worker and is outside its own owner-root preimage.
Callers cannot manufacture it by adding one to a revision number. It binds the
action, association, source key, both source prefixes and evidence-state hash.
Execution requires that exact seal and current sources. Archive failure rolls
back preparation and the seal together.

Registration retains the original full minimum delay measured at registration,
so scheduling exactly 72 hours ahead can leave insufficient headroom for a later
registration block. Acceptance must cover `notBefore`; actual execution must
also precede its signature deadline and action expiry. The original governance
window has at least seven days open and at most 365 days total lifetime from
scheduling. Reviewed clocks are not adjusted automatically.

The permanent acceptance signature still signs only Artist, old address, new
address, nonce and deadline at the original Registry. A Safe serving as new
authority must supply proof valid for the actual Executor caller. Empty proof
bytes do not by themselves establish direct mode. Frozen retained guardian veto
membership survives later source drift, even when execution is stale.

## Atomic recovery and continuations

Identity performs original operation 35, consumes its original replay lanes and
advances the delegation epoch once. Its guardian machinery receives only the
guardian partition; the permanent recovery record preserves the entire sorted
exclusion list. Supplemental V3 status and restoration data preserve original
records, signatures, nonces, vestings, dismissal history and delegation uses.

Resolving an occupied document branch opens a fresh recovery-scoped revision
continuation. Resolving operation 51 can open a fresh continuation only for the
exact current retirement. Previously spent keys remain spent. A genuinely later
original 58 revision continuation takes precedence when it reopens the same
branch; per-record pointers authenticate later original writes.

Excluding an old 51 cannot undo a newer retirement. Independent original-58
standing judgments remain effective, including a judgment made after a recovery
restored standing. A later rewind must preserve that judgment.

With payout exclusions, the Coordinator calls Payout's guarded local apply hook
after original 35. Payout authenticates its unchanged source, the actual Identity
recovery and association, and the completed historical selection. It commits
supersession statuses, the selected branch and one-use continuation. It emits no
synthetic payout-18 or second native-35 receipt. Without payout exclusions,
Payout's snapshot stays unchanged.

One final Archive append binds Identity and Payout before/after snapshots at
indices 2 and 5, including preparation and no-Payout-effect cases. The other five
snapshot slots are zero. The original eight-field envelope and evidence-ID
domain remain unchanged. Preparation still has operation 65534 and a zero
semantic record word; execution has operation 35 and its original record hash.
The inner preparation/execution payloads use explicit V3 tags and include their
source, selection, seal or Payout mutation evidence.

Current living notices retain the genuine operation-42 cancellation before the
adjacent operation-35 pair when the notice is open. Already-cancelled notices keep
their terminal. Signature payload retention includes empty bytes. Any Payout or
Archive failure rolls back the entire transaction and its authority, replay,
statuses, continuations and native receipts.

## Client workflow

Import the additive APIs from `@6529/stream-client`. Supply the complete current
Artist deployment, all 16 component runtime pins and the Coordinator pin, plus
separate evidence publisher, selection worker and governance Executor pins.
Capture resolves the original bindings and checks both Identity and Payout.

| API | Purpose |
| --- | --- |
| `prepareArtistRecoveryRewindCall` | Encode an exact original V3 method with its expected publisher hash when applicable |
| `captureArtistRecoveryRewind` | Read source, retained evidence and complete selection observations at an explicit block |
| `simulateArtistRecoveryRewind` | Recheck the saved block and repeat the call at a chosen current block |
| `prepareArtistRecoveryRewindGovernance` | Derive a singleton original class-2 batch from a complete context capture |
| `prepareArtistRecoveryRewindOperation` | Prepare the `publish`, `schedule`, `register` or `execute` stage |
| `simulateArtistRecoveryRewindOperation` | Check current governance, role, time, replay and source requirements and call the original target |
| `inspectArtistRecoveryRewindReceipt` | Verify publication or selection receipts against the captured transaction |
| `inspectArtistRecoveryRewindOperationReceipt` | Verify governance stages and operation-65534/35 evidence, including Safe transport |

Pure tuple codecs and hash helpers establish encoding and commitment equality.
Their `factsVerified: false` results do not establish record admission, ancestry,
signature validity or authority. The workflow uses the original worker and
Registry for those checks and preserves a complete bounded observation of both
native journals. A saved historical selection read does not substitute for a
successful current `requireSelectionV3` or recovery simulation.

The pure call encoder exposes the original worker seal and Payout apply hooks
only for the Coordinator caller and marks them `protocolOnly`. They are internal
protocol steps, not independently executable user actions. Governed recovery
uses the four-stage operation wrapper.

Transaction inspection requires exact zero-value calldata and the expected
caller, deployment, chain, block and event sequence. Safe submission uses the
exact reviewed inner CALL; its successful outer transaction alone is insufficient.
The inspector joins the expected Safe success event to original governance and
owner/Archive evidence. An inner failure, delegatecall, substituted call or
missing/mismatched completion event rejects the receipt.

### Bounded observations

These are client resource limits, not protocol lifetime limits:

- A continuation call reviews at most 64 records. A complete captured native
  journal contains at most 4,096 rows for each owner.
- Each retained payload catalog has at most 1,024 rows.
- A canonical codec value or outer transaction is at most 524,288 bytes; a
  retained Archive payload is at most 24,575 bytes.
- Ordinary read responses are at most 32,768 bytes; retained publisher and
  selection-result responses are at most 65,536 bytes. The original simulated
  call can return up to 524,288 bytes. Stored carrier code includes its leading
  byte within a 24,576-byte limit.
- Text fields are limited to 2,048 UTF-8 bytes and acceptance signatures to
  4,096 bytes. Original identity and directive document reads are limited to
  8,192 bytes.
- Runtime and individual receipt-log data are bounded at 65,536 bytes. Receipts
  contain at most 256 logs, with at most four topics each.

Receipt inspection needs the historical capture and a later receipt block.
All suite, helper and Executor pins must also exist in the block immediately
before the receipt. Begin/continue receipts exclude later progress in the same
block beyond the exact step being inspected.
It reads end-of-block state and is deliberately conservative about intervening
changes. Immutable Identity recovery evidence can remain inspectable after later
Identity revisions. Later Payout native rows, Payout chain/inventory changes or
a subsequently denied acceptance digest can make this inspector reject a valid
earlier transaction in that block. Such rejection is not proof that the original
transaction reverted. Use an isolated receipt block or a separately reviewed
transaction-level reconstruction for those cases.

## Retained evidence and acceptance boundary

The separate fixture projects retained `capture-rewind-v3-final2` compiler input
and output. All 966 literal sources match the frozen commit. The 26 public V3
structs have compiler witnesses. Concrete Executor and Bootstrap are separately
projected from retained ABI65; their complete 35-source dependency set also
matches this producer. Core remains an `IStreamCore` interface witness.

```sh
node scripts/generate-current-artist-recovery-rewind-fixture.mjs \
  /path/to/rewind-v3-input.json /path/to/rewind-v3-output.json \
  /path/to/abi65-input.json /path/to/abi65-output.json --check
```

The generator invokes no compiler. Source/ABI and mock-RPC client tests do not
establish actual Safe/current-stack execution, reconstruct private owner roots
or full ancestry, or establish size, gas, capacity, full CI or release acceptance.
The producer's authored actual-Artist cases retain explicit Core and scheduling
boundaries and separate execution evidence. Class-4 recovery and complete
recovered-history hydration remain separate work.
