# Artist recovery record rewinds V3

The explicit V3 API adds typed record rewinds to the original class 1/class 3
recovery flow. Governance supplies one immutable manifest and one complete
selection over the original Identity and Payout journals. The fixed Coordinator
executes both owner effects and Archive evidence atomically. Original records,
signatures, consumed nonces, vestings, dismissals and delegation uses remain
historical facts.

This is implementation documentation for the developing pre-audit system.
Source review and ABI/type checks do not establish runtime, deployment or
release acceptance. Class 4 recovery and complete advanced authority hydration
remain separate required work.

## Explicit interfaces

| Surface | Interface and methods |
| --- | --- |
| Evidence | [V3 publisher](../../smart-contracts/interfaces/stream/artist/IStreamArtistRecoveryRewindEvidence.sol): `publishResolutionManifestV3`, `publishAppealV3`, `publishPayoutOriginalV3` and their immutable getters |
| Complete selection | [V3 worker](../../smart-contracts/interfaces/stream/artist/IStreamArtistRecoveryRewindSelection.sol): `beginSelectionV3`, `continueSelectionV3`, `requireSelectionV3`, historical result/record/membership getters and the Coordinator-only preparation seal |
| Registry and Identity | [V3 recovery](../../smart-contracts/interfaces/stream/artist/IStreamArtistIdentityRecoveryV3.sol): explicit context, action registration, execution, inventory, status and continuation reads |
| Payout | [V3 Payout owner](../../smart-contracts/interfaces/stream/artist/IStreamArtistRecoveryPayoutOwnerV3.sol): inventory/status/continuation reads and a fixed Coordinator apply hook |

Read the constructor-bound `recoveryRewindEvidenceBinding()` and
`recoveryRewindSelectionBinding()` on the original Identity owner. The helpers
derive Payout from slot 5 of the fixed Coordinator suite after initialization;
callers cannot choose a replacement source. Both owner runtime hashes and the
complete chain/registry/Coordinator/Archive/Core/Manager environment are bound.

The original recovery `Request`, acceptance `Authorization`, permanent
operation 35 record, sorted supersession hash and native primary/secondary pair
retain their existing formats. V3 has its own manifest, appeal, selection,
context, preparation and evidence domains. The typed list is strictly sorted
by record hash and must be a one-to-one partition of the full original
`Request.supersededRecordHashes` array.

## Family selection

| Original family | Selection after prior and current exclusions |
| --- | --- |
| Guardian28 | Highest eligible retained nonce; veto membership retains every nonsuperseded historical membership independently of operative eligibility |
| Successor designation36 | Highest eligible retained nonce |
| Estate directive37 | Highest eligible retained nonce |
| Identity revision25 | Follow the actual branch's predecessor links; zero revision selects the registration document |
| Payout designation18 | Follow the actual branch's predecessor links; zero selects no payout account |
| Steward sanction grant19 | Highest eligible retained nonce, including a retained `granted=false` record |
| Prior-address standing revocation51 | Latest retained original admission within the exact artist/address/retirement scope |

Nonce ordering is distinct from journal order. A valid lower unused nonce can
be admitted after a higher nonce without replacing that family's operative
winner. Document and payout chains never select an abandoned sibling merely
because it has a later nonce or receipt. A retained ineligible child remains
occupied until that child is explicitly resolved or its original dismissal
continuation permits another branch.

The manifest has a maximum of 64 exclusions and 64 declared vestings; an appeal
finding has at most 8 parties. These bound each request, not lifetime history.
The resumable worker scans every native receipt in both captured journal
prefixes in ascending order, including unrelated artists. Missing original
evidence stops that scan; it cannot silently omit a row. Historical completed
results remain readable after current state changes.

Payout's original storage omits signer/class/nonce/time. Publish the actual
original preimage for each scanned 18. The reader joins the canonical record
hash, exact retained terms, native row, original Identity nonce digest and
admission revision, provisional association and abandonment facts. Publication
does not authorize a new payout and does not recheck historical signatures
against a Safe's present owners.

Historical operation 25 could hash class 3 but retain literal class 1 in its
record tuple. V3 preserves that tuple and independently authenticates the
unique canonical class 1/class 3 hash against its original admission. Future25
writes store the actual class already used by the record hash. A separate
frozen-original-writer fixture documents this compatibility boundary; it is
not evidence of a deployed historical instance.

The fixed [record reader](../../smart-contracts/domains/artist/StreamArtistRecoveryRewindRecordReads.sol)
retains environment and receipt admission, the original `Source`/`Facts` types,
and final record-facts proof wrapping. Its revision and standing branches call
the compiler-linked [revision reader](../../smart-contracts/domains/artist/StreamArtistRecoveryRewindRevisionReads.sol)
and [standing reader](../../smart-contracts/domains/artist/StreamArtistRecoveryRewindStandingReads.sol).
These helpers contain the original complete read/validation bodies, including
native and recovered continuation checks. Revision association updates remain
private memory mutations inside the revision helper before it returns the
complete facts tuple. The standing helper preserves retirement terms, original
nonce admission and vesting chronology checks in their original order.

Neither helper owns state or accepts a replacement implementation. Direct helper
reads are fragments of admission; they do not perform the outer reader's
environment/receipt checks or final proof wrapping. Deployment tooling must
include their fixed compiler links. The additional library calls require their
own runtime and gas validation; source parity and size measurements do not
establish that acceptance.

## Shared policy and source freshness

The declared earliest vesting, NONE, provisional and hostile-guardian APPEAL
rules from [V2 adjudication](artist-recovery-adjudication-v2.md) still govern
guardian exclusions. These restrictions are guardian-specific. Governance
attests the non-guardian attacker-era adjudication; the contract authenticates
each original record, family, artist, admission and exact resulting plan.

For every protected guardian prefix, both the original operative directive and
the restored directive must allow guardian changes. Excluding a banning
directive in the same plan cannot bypass that protection. This also applies
to a still-provisional guardian under NONE when the ordinary ARBITER role
otherwise suffices. APPEAL retains the original root authority requirements.

A selected designation's nonzero paired directive must be retained and belong
to the same artist. An excluded pair rejects the plan; the contract neither
relinks it nor falls back to a lower designation. For class 3, the pair must also
be eligible. Effective capabilities are the selected designation's grants,
intersected with its paired directive's grants when present, minus the restored
operative directive's prohibitions, within the original 4095 mask. Class 3 with
no selected designation rejects instead of silently becoming a steward.

This dependency check also covers a retained ineligible candidate designation:
later maturity cannot reactivate its excluded pair. Fresh original 36 writes
reject a permanently superseded paired directive before consuming authorization.

Original40/43 activation evidence remains immutable. A canonical V3 capability
continuation records the restored mask and original origin. Later rotations
can change the current address; later V2/V3 recoveries authenticate the
continuation through its actual35 ancestry and frozen selection.

Both complete owner snapshots and native receipt counts are strict. An
unrelated Identity or Payout mutation invalidates a pending selection/action.
The only permitted change is the exact auxiliary 65534 preparation commit:

1. Publish the manifest and required original payout preimages. Complete the
   worker scan and obtain the V3 context.
2. Schedule the exact V3 calldata and context through the required delayed
   governance role. Register that scheduled action through the Registry.
3. Identity commits its preparation association and pre-preparation sources.
   While the same Coordinator lock is held, the worker verifies the actual
   pending action, exact revision increment, unchanged native count and Payout
   prefix, then seals the full observed post-preparation Identity snapshot.
4. Execution requires that exact seal and current source state. The seal is
   stored outside the owner-root preimage, avoiding a self-referential hash.

Archive failure rolls preparation and the worker seal back together. A veto
uses the frozen retained guardian membership even after another owner
revision; stale execution does not remove the scheduled action's veto rights.

## Mutation and continuation

Identity installs the accepted Safe through original 35, consumes the original
cause/action/acceptance replay and advances the delegation epoch once. It
applies only the guardian partition to the original guardian machinery while
the permanent recovery record retains the complete sorted list. Other typed
supersession status and restoration facts live in appended supplemental state.

Resolving an occupied document branch opens a fresh recovery-scoped revision
key. Resolving 51 can open a fresh key only for its exact current retirement.
The original spent keys remain spent. A later original 58 revision continuation
takes precedence over an older consumed V3 continuation when it genuinely
reopens the same branch. Per-record continuation pointers authenticate later
original writes without rewriting their record formats.

An old 51 exclusion cannot undo a newer retirement of that address. Original58
standing judgments remain independent and unchanged, including when 51 is
restored. The originally valid sequence can be 51, recovery restoring standing,
then a later 58 removing it again; another rewind must preserve that judgment.

When payout exclusions exist, the Coordinator invokes Payout's guarded local
apply hook after original 35. Payout checks its unchanged pre-state, the actual
Identity recovery/association, and the historical completed plan. It commits
its statuses, selected branch and one-use continuation without emitting a
synthetic 18 or duplicate 35 native receipt. With no payout exclusions, its
snapshot stays unchanged. One final Archive append binds both owners' before
and after snapshots. A Payout or Archive failure rolls the entire transaction
back, including accepted authority, replay, statuses, pointers and receipts.

Current living notices retain the original V2 cancellation behavior: successful
new-side acceptance can produce original 42 before the adjacent 35 pair; existing
terminals remain unchanged. V3 adds its own evidence wrapper around those
original lifecycle facts.

## Hydration and validation boundaries

This batch adds no operation 60 profile. A complete later hydration profile must
inventory typed supersession status, selection/manifests and helper pins,
preparation seals, capability origins, every continuation and per-record link,
original receipts, historical replay keys and current owner pointers. Legacy
profiles must reject unsupported rewind history instead of assuming these
facts are empty. See [ADR 0047](../adr/0047-complete-artist-authority-hydration.md).

Authored tests include 24 actual-producer cases in
[the V3 flow host](../../test/unit/artist/StreamArtistRecoveryRewindsActual.t.sol),
15 [publisher cases](../../test/unit/artist/StreamArtistRecoveryRewindEvidence.t.sol),
10 [bounded worker cases](../../test/unit/artist/StreamArtistRecoveryRewindSelection.t.sol)
and 6 [frozen original 25 cases](../../test/unit/artist/StreamArtistRecoveryRewindLegacyRevision.t.sol).
The actual host uses original Artist owners, Safe authorization and Archive;
Core and action scheduling retain explicit unit boundaries. The frozen 25 host
uses an explicitly seeded authority boundary and the retained original writer,
not a claim of full original 40/43 integration.

Native execution, combined current-stack/Safe tests, fuzz/invariants, linked
sizes, gas/capacity, full CI and regenerated release artifacts remain assigned
to the integrator's stabilized batch. No readiness or audit claim follows
from these authored tests.
