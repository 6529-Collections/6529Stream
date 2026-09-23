# Bounded multi-origin Artist Archive implementation plan

Status: proposed source design, not an implemented capability or runtime result.
Reviewed integration source: `32ae0361a63279d3e578063300effa618b10952a`.
The earlier [succession characterization](preservation-artist-succession-plan.md)
and its two authored cases retain their own source and validation boundaries.
No production contract, original record domain, Archive or release artifact is
changed by this plan.

## Decision and supported boundary

Add a preservation profile that authenticates the original producer of every
Artist state bundle. Keep the existing historical loaders, single-Archive
coverage profile and permanent signing/record domains exact. Use current Artist
authority to select current records, a record's original suite to interpret its
signature and Archive, and authenticated ancestry to join a locked presentation.

Implement the initial profile for local native operation 17 and original
publication operation 24, and their exact records in the complete recovered
operation 60 imported journal. It includes repeated recovered succession.
An older import profile without bounded per-record provenance is unsupported
by this new route; failure must not fall back to a guessed local origin or a
full-prefix scan. Its existing historical route remains available.
An older original producer does not need the new getter: its existing native
receipt/revision and semantic reads suffice when the upgraded current owner
retains its authenticated recovered-profile journal. Missing stored provenance,
not the age of the original producer's interface, defines this limitation.

The original `recordArtistAttestation` kind 8 route produces the nine-field
publication payload decoded by the current historical reader. The earlier
payload-mismatch inference for that route was retracted. Expanded/delegated
operation 24 has a distinct payload and needs a separate exact-selector recipe,
decoder and coverage proof. Operation number 24 alone cannot choose that codec.

This follows [ADR 0040](../adr/0040-current-metadata-record-host.md),
[ADR 0041](../adr/0041-typed-finality-evidence-provider.md) and
[ADR 0047](../adr/0047-complete-artist-authority-hydration.md).

## Fixed authority selections

| Read or assertion | Authoritative source |
| --- | --- |
| Current Artist registry/Identity | `resolveCurrent`, rooted in Metadata's immutable original registry/runtime and actual Core selection |
| Current suite and completion | Actual configured Coordinator, runtime pins, Router relationship and all seven equal nonzero operation 60 completion markers |
| WORK, RIGHTS and Conservation selections | Existing current selectors and their original Metadata record/receipt joins |
| Retained publication or content-consent tuple | Current selected owner 4 or owner 6, compared to the exact original producer record |
| Original producer and occurrence | Authenticated imported journal row, or actual local native receipt and revision |
| Original signature and record hash | Original registry/Core/manager domain and retained signer, class, grant, nonce, time and bytes |
| Original Archive | Producer environment and reciprocal original Coordinator/Archive configuration; never current Archive by default |
| Locked presentation | Exact Router-saved registry/runtime and presentation tuple, authenticated as current or an admitted ancestor |
| New Finality use | Current inventory plus exact bundle coverage, actual selected Finality/Artifact environment and original provider reciprocal pins |

`resolve` and `knownIdentity` retain their historical meaning. There is no global
replacement with `resolveCurrent`. Historical validation does not call a Safe's
current owner set, reconsume an authorization, or apply today's grant, deadline
or signer eligibility to an earlier record.

## Minimal new owner read

Introduce a separate capability interface, provisionally
`IStreamArtistImportedReceiptRead`, with this fixed return:

```solidity
function recoveredHydrationImportedReceiptAt(uint256 index)
    external view
    returns (
        RH.JournalEntry memory entry,
        bytes32 importCommitment,
        uint64 importedAtRevision
    );
```

The result is ten static ABI words (320 bytes): the eight-word journal entry,
the actual import commitment and the actual local import revision. It reads
`StreamArtistRecoveredHydrationState.State.journal[index]` directly. Reject an
absent import, wrong owner/profile, zero commitment/revision and out-of-range
index. It must not manufacture a native row for a missing imported index.
Use the existing `originIndexPlusOne` mapping to check its referenced era in
constant time: matching owner/origin, nonzero operation/record,
`nativeIndex < era.nativeCount`, and
`era.lowerRevision < point.ownerRevision <= era.checkpoint.ownerState.revision`.

Implement this through the existing owner read dispatch and fixed storage
library. No new storage layout, index mapping, import mutation, replay key or
semantic-record writer is required. Use a separate typed ABI and exact fixed-call
response, with no fallback on a missing capability. Concrete owners do not
currently expose ERC165, so adding
`supportsInterface` is unnecessary. Leave the old hydration ABIs and selector
meanings unchanged. Source and capacity review must cover every concrete owner's
resulting runtime.

The imported-origin certificate currently proves only membership of an entire
environment. The new indexed receipt read supplies the missing per-record
membership proof without returning up to 4,096 journal entries and 8,192 aliases.
Local production already has `artistNativeReceiptAt(index)` and
`artistNativeReceiptRevisionAt(index)`; it requires no new journal getter.

## New types and fixed preservation worker

Use a separate `StreamArtistArchiveOriginTypes` library. Reuse existing
`RH.JournalEntry`, `RH.OriginEnvironment`, `T.Item` and `B.Admission` shapes.
The following are proposed new types, not deployed ABI:

| Type | Minimal purpose and fields |
| --- | --- |
| `ReceiptWitness` | Closed lane discriminator: native or imported; one receipt index. Actor and original observed time remain explicit existing stage inputs. |
| `Origin` | Existing producer `RH.OriginEnvironment` plus original registry/Coordinator/Archive runtime pins, 768 fixed bytes. |
| `RecordOrigin` | Authenticated journal entry and `Origin`; current import commitment/local import revision where applicable; retained semantic-record hash; semantic role and admission source-context hash. |
| `OriginDependencies` | Fixed worker address/runtime, distinct bounded worker gas budget and explicit profile ID. Existing source dependencies are retained separately. |

Operation and expected record identity come from the selected typed record,
not the witness. Publication 24 selects owner 4; content 17 selects owner 6. A
generic owner index, target address, calldata or callback cannot be supplied.

Add a fixed `StreamArtistArchiveOriginReads` worker with explicit typed
publication and content entry points. The inventory authenticates its worker
runtime and uses a finite STATICCALL frame. Within that frame, dependencies,
return sizes and canonical encodings remain bounded. A public worker return
is not a transferable authority certificate: the pinned inventory admits it
only against its own dependency set, selected context and original inputs.

Ordered admission is as follows:

1. Authenticate current selection with the existing Metadata succession path;
   compare the full expected current inventory pins. Check all seven current
   completion markers for a successor. Operation 55/56, a Core pointer, a source
   cutover, or an origin certificate alone is insufficient.
2. Read the selected current owner's exact semantic record. For publication,
   join its full `publicationAttestation` tuple to the actual Metadata candidate,
   recorder, code hash, consumed authorization and selected record/receipt.
   For content, retain the exact collection/scoped root and owner 6 consent joins.
3. For an imported witness, read the new indexed entry from that current owner.
   Compare receipt operation, Artist, collection and record hash to step2.
   Compare owner index to the operation-derived index. Require the returned
   import commitment to equal the authenticated seven-owner completion. Read
   the imported-only origin certificate for the entry's environment hash and
   require the same commitment, local import revision and owner index.
   Require that local import revision to be nonzero and no greater than the
   actual current owner's revision.
4. Obtain the original environment from that same authenticated owner, require
   `RH.originHash(environment)` to match the row, and pin its owner runtimes.
   Reconstruct the exact original suite/configuration, check original facade
   and Coordinator reciprocity, Core/manager/chain, owner positions, Archive
   registry/Coordinator getters and the preserved non-Artist dependencies.
   Configuration validation supplies original runtime commitments; a caller's
   self-reported address/code hash is never an admission root.
5. Re-read the original owner's native receipt at the authenticated
   `position.nativeIndex` and its revision. Both must equal the stored original
   journal entry, including local revision. Compare its full retained semantic
   record to step2. This also rejects a record from another certified era or a
   same-hash occurrence at a different original journal coordinate.
   Compare the entire 704-byte publication `Record` or 256-byte `ConsentRecord`,
   not only the hash or selected summary. Preserve publication kinds 7/8,
   Metadata host/candidate/recorder, and content scope/generation/binding/class/
   terms/prior-state/observed-time checks from the original typed decoder.
6. For a native witness, take the environment from the authenticated current
   suite, read the actual local receipt/revision and compare step2. The original
   record hash must reproduce under that current producer domain. A missing
   imported certificate or an apparently large retained revision cannot select
   this branch. The witness chooses a read location, not production authority.
7. Derive the unchanged original evidence ID from chain, producer registry,
   producer Coordinator, operation, original actor and original record hash.
   Use version 1 at that producer's Archive. Retain the full canonical envelope,
   configuration, saved approvals, statements, effective/submitted values,
   record/digest recomputation, Archive metadata and exact STOP-retained bytes.
8. Return the original state item and `RecordOrigin`. Hash the new origin fact
   under a distinct profile domain; include it together with every existing
   original provenance component in the new item's `provenanceHash`.

Use the authenticated imported row as the ultimate producer even after
A-to-B-to-C succession. Do not follow an unbounded predecessor chain or mistake
B's copied semantic record for a B-native envelope. Recovered import does not
copy an A operation 17/24 envelope into Archive B or Archive C.

## Additive inventory profile and presentation lineage

Introduce `StreamMultiOriginRenderCriticalInventory` with the existing
`IStreamRenderCriticalInventory` reads, plus a separate origin capability.
Keep `dependencies()` returning exactly the original `S.Dependencies` tuple:
all three Finality reader families require its fixed 1,344-byte encoding and
compare `artistTargets[0]` to configured Artist slot 11. That comparison alone
does not establish Core currentness: the new profile must authenticate current
selection independently. Those five Artist targets remain the selected current
suite. New origin dependencies use a separate getter and enter a distinct
dependency/profile hash.

Add typed stage selectors accepting `ReceiptWitness` for WORK publication,
intent/waiver, interview and root authorization. Rights has no separate Artist
bundle stage in the existing collection implementation; preserve its existing
original-record semantics. Unchanged non-Artist item stages remain unchanged.
The new profile's stages invoke the fixed origin worker and store its immutable
fact under `(planId, Chains.itemHash(item))` as they append that exact item.

Expose `artistArchiveOrigin(planId, itemHash)` and fixed origin dependency/profile
reads through `IStreamArtistArchiveOriginInventory`. Reject unknown plans/items,
non-Artist state items and unadmitted facts. Its origin hash is computed before
the final item hash; the origin fact must not include that final item hash and
create a circular preimage. Existing items and segment links are unchanged ABI;
new profile/evidence domains explicitly identify the additional semantics.

Keep a per-plan ordered origin table inside the new inventory. Seed the
authenticated current and locked-presentation origins at `beginInventory`, then
add only worker-authenticated original producers when their exact record stages
append. Deduplicate by environment hash in deterministic first-use order. There
is no public origin-enrollment or replace/remove operation. Before sealing,
append bounded runtime/provenance segments for each used origin and require
that cursor to reach the exact origin count. Preserve current-suite dependencies
and all original producer/Archive/owner pins as separately named item roles;
do not label the current suite as every record's original producer. This also
corrects that ambiguity in the new scoped/PolicyV2 native-runtime stages.
Expose fixed `originCount(planId)`, `originAt(planId,index)` and sealed
`originSetHash(planId)` reads through the additive inventory interface.
The begin-time plan ID commits the fixed configuration and initial source
context; it cannot include a not-yet-discovered origin set. Completion commits
the final origin root/count and complete runtime-item segment chain. No origin
or item certificate can change after sealing.
Every append and seal retains the same authenticated current suite and source
context; merely rechecking code pins is insufficient. A later Core selection
cannot let one plan mix different current owners or import completions.

Replace the strict same-registry predicate only in this new profile with an
explicit ancestry join. Obtain the actual Router presentation through the
unchanged Snapshot/source readers. Pin its saved registry/runtime. If it equals
the current suite, require exact current pins. Otherwise prove that exact
presentation environment is in the current complete recovered ancestry through
the imported-only certificate and original configuration, rooted in actual
Metadata/Core selection. Do not infer ancestry from matching Artist IDs.

After ancestry, preserve exact equality of Artist ID, binding generation,
binding hash and immutable registration identity with the authenticated current
Conservation association. Preserve the complete original presentation, including
nominated Artist and acceptance evidence, in the source commitment. Do not
replace these with operative authority or require nominated Artist to equal a
later signer. A genuine changed association still invalidates the old source.

Make acceptance preservation explicit using existing bounded reads: compare
`bindingAt(collectionId, presented.bindingGeneration)` on both authenticated
presentation and current Binding owners, including accepted=true, Artist ID,
`artistAddress`/nominated Artist, identity and binding hash/generation. Compare
both Acceptance owners' `acceptanceRecord(bindingHash)` and
`acceptedAt(bindingHash)` to the Router's saved values. Preserve the original
Router-domain presentation snapshot hash. A presentation graph need not be the
original producer of every retained binding/acceptance record; do not invent a
requirement for a native operations 1/2 in that graph. The authenticated locked
snapshot and retained tuple joins suffice without another journal scan.
The actual supported same-Router recipe locks A before operation 55, then
preserves that A presentation through A-to-B-to-C. Router's Artist is immutable;
the current graph cannot create a new B lock on Router A after import. This plan
does not add a Router migration or claim that hypothetical lock path works.

Additive scoped and PolicyV2 adapters must retain their own exact scope/root
types and current membership checks. They share the provenance and lineage
worker, not a conversion of non-COLLECTION scopes into COLLECTION records.

The same lineage join is also required in the additive Finality review route.
`StreamFinalityNativeSanctionReview._artist`,
`StreamFinalityScopedSanctionReview._artist` and
`StreamFinalityPolicySanctionReviewV2._artist` each independently compare the
locked presentation registry/runtime to configured slot 11. Fixing only the
inventory would leave this later rejection intact. Select the new lineage-aware
review only through a fixed, explicitly pinned additive provider profile; retain
all original lock, presentation, capture and current-input checks. The original
review routes keep their strict same-registry behavior.

`StreamFinalityRouterEvidenceProvider` separately authenticates the Router's
original Artist and original Finality anchor, including its sanction-read
relationship. Preserve that historical serving/lock anchor. It is not a mutable
current-authority selector and must not be redirected to the successor.

## Additive bundle coverage profile

Introduce `StreamMultiOriginBundleArchive Coverage`, retaining the existing
`IStreamBundleArchive Coverage` consumer methods and a distinct profile constant.
Keep the old `StreamBundleArchive Coverage`, `StreamBundleArchiveReads` and their
single-Archive dependency equality intact. Scoped coverage retains its scoped
interface and scope tuple through a corresponding additive adapter.

For a STATE_BUNDLE, verify the exact segment/link/item position first. Read its
admitted origin from the constructor-pinned inventory and bind the fact to that
plan, item hash, role, original record and evidence ID. Pin the certified original
Archive/runtime and reject a merely allowlisted address. Only then construct a
temporary `B.Dependencies` frame whose slot 5 is that exact Archive and invoke
the existing `Reads.admit` state-bundle checks. This preserves version 1, RAW,
algorithm 1, no-proof applicability, payload/digest/size, receipt and immutable
STOP-code correspondence. Slot 5 never comes directly from caller input.
Set both `targets[5]` and `codeHashes[5]`, and explicitly pin the Archive before
calling `admit`: its state branch does not itself perform that runtime check.
Use the identical origin-routing rule for admission, refresh and full diagnostics.

Keep non-state external/onchain/applicability branches and their proof semantics.
Bind the origin fact hash into the new covered-item chain alongside the original
`B.Admission`; also retain it for refresh and full diagnostics. Covering the same
bytes in another role remains a separate ordered occurrence.

The new environment function retains all original Core/Metadata/inventory/
Artifact/external reciprocal checks. It additionally pins the fixed origin
worker and every distinct original Archive used by the sealed inventory. The
ordered used-origin set is derived from admitted facts, never a caller allowlist.
Freeze that ordered, deduplicated set at inventory sealing and include its root
in every environment and refresh cache key.
Bound it to `RH.MAX_ERAS + 1` (currently 17): at most 16 imported environments plus
the current native environment. The bound enters the fixed profile/dependency
commitment. The discovered source-set root/count enter completed inventory
evidence and bundle environment/coverage commitments, not the constructor's
fixed dependency hash. No operation scans the full journal.

Admission and refresh fully check each original Archive item. The ordinary
bounded coverage read retains the existing immutable-STOP aggregate assumptions;
the full diagnostic remains explicit. Preserve the distinction between Archive
liveness and source currentness: `requireCoverage` checks the exact completed
inventory/coverage and its environment, while the caller separately invokes
`inventory.requireCurrent`. A current Core switch must not rewrite historical
Archive evidence or be hidden by a cached coverage result.

## Deployment and implementation slices

| Slice | Concrete changes and completion condition |
| --- | --- |
| 1. Bounded owner capability | New interface, owner read dispatch, direct immutable-prefix indexed read; exact 320-byte output and malformed/out-of-range tests, no storage writes. |
| 2. Original-record worker | New types and fixed worker; genuine native/imported operation 17 and original publication24 record/Archive cases, A-to-B-to-C and negative provenance cases. |
| 3. Current inventory composition | Additive inventory/stages and lineage worker; exact existing dependency ABI; retain original payload/receipt and all role-qualified items. |
| 4. Multi-origin coverage | Additive collection/scoped coverage; exact per-item origin read, finite origin-set environment, original byte checks and refresh semantics. |
| 5. Actual graph recipes | Additive lineage-aware sanction review, constructor/storage runtime predictions and reciprocal provider pins, selected Finality/Artifact graph, collection/scoped/PolicyV2 end-to-end cases. |

Keep late Artist/Coordinator/profile bindings in constructor-only storage where
the existing deployment graph relies on runtime independence. Derive hashes
from the exact new compiler products, libraries and earlier immutables. New
worker/profile addresses must not create a provider/Coordinator/runtime cycle.
The provider's inventory/bundle reads can retain their current ABI, but all new
products and reciprocal pins still need explicit construction and interface
checks. No capability can be assumed solely because an interface ID matches.

The existing three provider readers also require
`keccak256(abi.encode(baseDependencies)) == inventoryDependencyHash`. A new
profile's complete dependency commitment must not masquerade as that base-only
hash. Add explicit provider configuration readers that retain the exact
1,344-byte base read, read/canonicalize the separate fixed origin dependencies,
and recompute the new profile's full hash against the configured pin. Verify
inventory/bundle worker/profile reciprocity as well. Old provider readers must
fail closed for this profile. Preserve all 12 common source mappings and all 22
configured runtime pins; retaining the public ABI does not eliminate this
required provider implementation change.

Artist-only 55/56/Core selection/57/60 is insufficient for slice 5. Actual Artifact
coverage also requires its original immutable Finality to equal the selected
Core Finality. Snapshot/Reference/Conservation, complete inventory, finality
manifest, sanction and Archive acceptance each keep their own real prerequisites.

## Required acceptance and remaining evidence

Positive cases must cover original A and fresh B records together; mixed 17/24;
repeated A-to-B-to-C with A- and B-original Archives; a locked A presentation
under current C; real Metadata retention/consumption; and exact collection,
scoped and PolicyV2 routes. Local/imported reads must leave all owner snapshots,
journals and replay guards unchanged.

Reject unrelated coherent suites, origin-certificate-only witnesses, wrong
owner/operation/Artist/collection/record/index/revision, wrong source domain,
altered source runtime, wrong Archive/actor/version, malformed ABI/envelope,
missing bytes, changed signature bytes, mismatched current retained tuple,
partial seven-owner import, unsealed or stale ancestry, changed binding or
registration identity, unknown profiles and unsupported operation 24 codecs.

Exercise the 17-origin boundary, fixed return/read budgets, refresh after an
external epoch change, artificial Archive/runtime corruption in full diagnostics,
same bytes in different roles, rollback and identical retry after a late failure.
Keep legacy reader/single-Archive golden results unchanged. Native execution,
linked sizes, gas ceilings, actual complete graph tests and release acceptance
remain pending; this source plan proves none of them.
