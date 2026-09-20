# Preservation after Artist succession: source plan

Status: proposed composition, with characterization tests authored against
`611be306bac07cc264370ed3b27f906b0f14efd6`. Production readers are unchanged.
ABI checks and source review do not establish native execution or complete
inventory, Archive coverage, or Finality acceptance.

## Preserve three distinct identities

The [current record reader](record-artist-succession.md) can authenticate the
Core-selected successor while Metadata retains its immutable original Artist.
Preservation also needs the original producer of each signed record and the
original Artist presentation saved by the Router. These identities can differ.

Let A be the original Artist, CA its Coordinator, and XA its Archive. After
actual history operations 55/56, Core selection, source cutover 57, and complete
recovered operation 60, let B, CB and XB denote the corresponding successor.

| Fact | Identity that must remain authoritative |
| --- | --- |
| New publication and current record consumption | Authenticated current B suite and current policy |
| Metadata record and receipt | Original Metadata host, exact record tuple, recorder, indexed membership and retained bytes |
| A-produced op24 publication | Original A/CA owners, original signature domain, XA evidence ID and bytes |
| Fresh B-produced op24 publication | B/CB original local record and XB evidence ID and bytes |
| Locked Artist presentation | Its saved registry/runtime and association, joined to current authenticated ancestry |
| Existing single-Archive coverage | The one Archive originally pinned by that profile |

The original evidence ID is derived from actual producer coordinates:

```text
keccak256(abi.encode(
  keccak256("6529STREAM_ARTIST_ONBOARDING_OPERATION_EVIDENCE_V1"),
  chainId, producerRegistry, producerCoordinator, operationId, actor, recordHash
))
```

Version 1 selects the original operation envelope. The actor is an Archive
locator and remains distinct from the saved signer. The original Coordinator
configuration, original digest/record hash, submitted and effective authorization,
full publication tuple, Archive receipt and STOP-retained bytes must agree.
Recovered60 retains owner records and its own import evidence; it does not
recreate original op17/op24 envelopes in XB.

## Concrete rejection boundaries

The new
[current preservation recipe](../../test/current/StreamCurrentPreservationSuccession.t.sol)
uses the existing real-Core, real-Executor, real-Safe migration fixture. It
registers actual interpretation documents and an ARTIST_STATEMENT policy,
signs and appends an original publication, performs actual55/56/57/recovered60,
and exercises the original reader and Archive admission components directly.
Its small statement-schema definition proves only generic record admission;
it does not claim a complete statement or conservation semantic profile.

The selected original `recordArtistAttestation` entry point, kind8, routes to
`StreamArtistIdentityOperations._publicationAttestation`. Its nine-field Archive
payload matches the historical loader. Expanded/delegated attestation selectors
have separate recipes and are outside these two cases.

1. An A-produced publication remains readable by
   `StreamPreservationArtistBundleReads.item` with authenticated A dependencies
   after60. Its source remains XA, with the same exact evidence ID and bytes.
   Metadata's original record and payload remain independently readable.
2. Supply actual B dependencies to that original loader: it resolves Metadata's
   original `[A, CA, IdentityA]`, then fails the first comparison with B's pins
   using `InvalidInventoryItem()`. This happens before an Archive lookup.
3. Pass a correct XA item to `StreamBundleArchiveReads.admit` with the Archive
   constraint XB: the `STATE_BUNDLE` branch rejects `item.source != targets[5]`
   with `InvalidInventoryItem()` before reading bytes. The same item passes
   original XA correspondence. A direct XB lookup of the old ID is unavailable.
4. A fresh B publication through the same Metadata host has a B/CB-derived ID
   and actual bytes at XB. Keeping A dependencies derives the wrong A/CA ID and
   queries XA; its unavailable evidence is wrapped as `InventoryRead(XA)`.
   Supplying B dependencies still fails the earlier original-pin comparison.

The component wrappers deliberately do not claim full inventory or coverage
admission. A full inventory first requires current Reference, Snapshot,
description and Conservation selections. With those prerequisites met,
`StreamRenderCriticalSourceReads.requireSameArtistAssociation` additionally
compares a locked A presentation with the configured registry B and can reject
with `InventorySourceChanged()`. The scoped and policy V2 source paths share
that comparison.

Full bundle coverage also checks the actual Artifact environment first. The
new Artifact coverage's immutable Finality must match Core's selected Finality.
An Artist-only pointer migration does not establish this separate prerequisite.

## Proposed bounded implementation

Keep `resolve` and `knownIdentity` historical. Keep the existing operation,
signature, Metadata, item and coverage hash domains unchanged. Add an explicit
preservation composition with separate current and original coordinates:

1. **Current authority.** Authenticate the actual selected suite with the existing
   Metadata succession proof and all seven completion markers. Use current
   owners for current authority, association and publication eligibility.
2. **Presentation ancestry.** Authenticate the retained presentation's exact
   original registry/runtime as an admitted ancestor. Continue comparing the
   stable artist ID, binding generation/hash and registration identity. Preserve
   nominated key, operative authority and acceptance evidence as separate facts.
   A genuine later binding change can still invalidate the old presentation.
3. **Original record membership.** Obtain a bounded producer environment from
   the current owner's authenticated imported origin certificate and original
   journal position, or prove an actual local native occurrence for a fresh
   record. An origin witness is only a locator. Matching self-reported getters
   or an arbitrary runtime hash is insufficient membership evidence.
4. **Original evidence.** Read that producer's original owner and Archive, join
   its full semantic record to the retained record selected by the current
   consumer, and recompute the original domain and evidence ID. Validate the
   envelope, configuration, canonical payload, receipt and retained bytes.
   Do not re-run historical Safe signatures against current Safe owners or
   replace original grants, nonces, deadlines or signer facts with current ones.
5. **Coverage of multiple origins.** Add an explicit bounded profile that admits
   only the Archive certified for each item. Keep the existing single-Archive
   profile exact. A loose Archive allowlist or merely removing the equality
   check does not authenticate an item's producer or its relationship to the
   selected current graph.

`OriginEnvironment`, `recoveredHydrationImportedOriginCertificate`, the retained
original journals and current native receipts supply candidate proof building
blocks. The certificate alone establishes an admitted environment, not that a
particular record belongs to it. The implementation must independently join
record membership, owner index, original occurrence and current retained state.
Bound reads and witness size explicitly; do not replace the current bounded
component reads with unbounded full-prefix scans.

## Acceptance beyond the two characterization cases

Require positive A-original and fresh B-native evidence in the same admitted
inventory, repeated A-to-B-to-C succession, exact op17 and op24 domains, and
collection/scoped/policy V2 consumers. Reject unrelated-but-coherent origin
suites, wrong original actor/op/record/version, another Archive, missing origin
membership, modified runtime, malformed envelopes, altered signature bytes,
wrong current retained semantic records and stale current graphs.

Retain original public getters and original single-Archive behavior. Exercise
the actual locked presentation, current Reference/Snapshot, newly selected
Finality/Artifact environment, late failure rollback and unchanged retry before
claiming complete preservation continuity. Native linked sizes, execution,
bounded gas and release acceptance remain separate validation work.
