# Current-authority scoped preservation ceremony recipe

This local recipe composes the [V2 preservation family](current-authority-preservation-graphs.md)
for TOKEN, RELEASE and SEASON. Its combined ABI-only compilation passes; native
execution, linked sizes, transaction gas, fresh browser observations, complete
archive coverage and terminal Finality acceptance remain pending. The existing
[full-output STATIC recipe](current-authority-scoped-static-ceremony.md) retains
its original behavior and evidence boundaries.

## Original graph and actual admission

The [graph](../../script/current/StreamCurrentAuthorityPreservationPolicyGraph.sol)
constructs both current-authority preservation factories and the matching
provider and Discovery. The [assembly](../../test/helpers/StreamCurrentAuthorityPreservationPolicyAssemblyFixture.sol)
supplies the real linked creation templates, constructor arguments and expected
runtime pins. Original Metadata, Router, Finality, archive and authority resolver
anchors stay fixed. Simulation gas parameters are authored inputs, not measured
deployment limits.

The [migration recipe](../../test/helpers/StreamCurrentAuthorityPreservationMigrationRecipe.sol)
predeploys genuine B and C suites before original Artist onboarding. Their three
coordinators form the immutable lineage catalogue. Catalogue membership grants
no authority: actual A-to-B and B-to-C migrations still require complete exports,
imports, terminal seals and Core selection. C has no immutable predecessor-A
binding. This finite known-successor fixture does not prove an unpredicted
successor can enter an already frozen STATIC read catalogue.

The [STATIC prefix](../../test/helpers/StreamCurrentAuthorityPreservationStaticPrefixFixture.sol)
deploys the current-Artist lineage companion, preservation attribution and
preservation producer before the original Registry freezes its target list.
After the first genuine paid token receives finalized entropy, it separately
admits CurrentCitation and then the actual preservation producer through the
Safe and Executor. It retains every original declared read, adds the concrete
preservation reads, and verifies the complete binding, governed admission,
registration action and retained record. Two freshly rendered JSON/HTML goldens
exercise target-side repeatability. The fresh graph's original renderer version,
citation evidence and serving bytes must remain unchanged by that admission.

The inherited schema, source analysis and partial read roster are explicitly
synthetic fixture evidence. Repeating actual outputs does not establish
independently expected artwork bytes or transitive opcode conformance. A finite
lineage catalogue also does not admit every transitive read to the Registry.

## Publication and succession

The [publisher](../../test/helpers/StreamCurrentAuthorityScopedPreservationPolicyPublicationFixture.sol)
uses the actual selected producer for every token, the fixed V2 family for the
complete checkpoint and output manifest, and exact V2 snapshot/root definitions.
Each output row keeps its own producer marker and all 288 binding bytes plus
224 admission bytes. A family marker never replaces that per-token identity.
The original Artist authorizes the genuine op17 Router root before succession.

The [three authored tests](../../test/current/StreamCurrentAuthorityScopedPreservationPolicy.t.sol)
cover TOKEN, RELEASE and SEASON independently. They rejoin the real producer
admission and exact V2 snapshot, migrate A to B, publish B scope records and
Rights, migrate B to C, append C WORK/Interview/Intent, and seal the selected
heads. They compare original root/snapshot history, provider identity and actual
lineage selection across both transitions. These cases do not fabricate a
Reference or claim browser, bundle or Finality acceptance.

## Fresh export and exact resume

Use the [local recipe](../../test/helpers/StreamCurrentAuthorityScopedPreservationPolicyLocalRecipe.sol)
in an explicitly controlled local Foundry simulation. It is not a broadcast
script. `exportScopedSources(kind, outputDirectory, runLabel)` creates original
A and passes its publication to the [preservation exporter](../../test/helpers/StreamCurrentAuthorityScopedPreservationPolicyExportFixture.sol).
The run directory must not already exist. Foundry filesystem permissions still
apply. The exporter writes actual `preservationTokenHTML` and
`preservationTokenJSON` bytes and checks them against the complete current
checkpoint and original selected Registry admission.

The packet contains `source-identity.json`, `source-identity.abi.hex`,
`capture-inputs.json`, per-token HTML/JSON and capture instructions. Its canonical
ABI is `abi.encode(domain, context, publication, tokens)`, using the structs in
the new exporter. The domain is the Keccak-256 hash of
`6529STREAM_CURRENT_AUTHORITY_SCOPED_PRESERVATION_SOURCE_EXPORT_V2`. Context starts
with schema version 2 and `6529STREAM_TOKEN_PRESERVATION_FAMILY_V2`, followed by
chain/block/time, exporter, thirteen source addresses/runtime hashes and actual
authority. Token rows include the full preservation output and actual endpoint
bytes. The old live STATIC packet has a different domain and types.

Capture the exported first/last authoritative HTML with the
[reference capture tool](../../tools/preservation/reference_capture.py), an
explicit engine and viewport, and a fresh output directory. Supply complete
environment, browser-package and repeated PNG observations to the
[reference helper](../../test/helpers/StreamCurrentAuthorityScopedPreservationPolicyReferenceFixture.sol).
The exporter itself creates no browser observation or archival attestation.
Earlier native or full-output capture files cannot stand in for this packet.

After capture, call `coverExportedScopedSources(sourceABI, era, files,
largeByteProofs)` on the same fixture. Decode the hex packet to raw bytes.
The entrypoint requires its saved export hash, canonical re-encoding, exact
domain/schema/family, original instance, chain and Core, and a single unconsumed
export. `era` selects A (0), B (1) or C (2). It publishes the original A Reference
before migration, then performs actual record publication, sealing, inventory,
byte collection and bundle coverage. C preserves B Rights and appends C records.

A failed call rolls back its consumption marker and protocol writes; exact retry
also needs the appropriate local VM clock and environment. Filesystem/browser
state is separate. `coverScopedSources` is an alternative clean replay only when
fixture address, deployer nonce, linked artifacts, chain and initial EVM state
match the export. Another deployment in the same EVM is not an exact replay.

The [collector](../../test/helpers/StreamCurrentAuthorityScopedPreservationPolicyBytesFixture.sol)
authenticates all ordered occurrences before deduplicating complete bytes. It
dispatches native, reference and definition reads from the authenticated V2 Plan
and uses `itemForPlan` for the mandatory preservation phase. The
[bundle helper](../../test/helpers/StreamCurrentAuthorityScopedPreservationPolicyBundleFixture.sol)
keeps complete origin witnesses and per-occurrence schema/canonicalization
identities. Package proofs can use the existing streaming file path API and
[endpoint generator](../../tools/preservation/inventory_package_objects.py).
Large non-package proofs remain explicit inputs. No missing row or sample can
substitute for complete coverage.

These original local entrypoints stop at bundle evidence. The separate recipe
below adds sanction and Finality calls; neither recipe has executed acceptance
evidence yet.

## Scoped sanction, archive and Finality source

The [Finality local recipe](../../test/helpers/StreamCurrentAuthorityScopedPreservationPolicyFinalityLocalRecipe.sol)
extends the same export and exact-resume entrypoints. Export from that contract
instance, capture its actual bytes, then resume that instance with the supplied
observations and complete byte proofs described above. Its pre-inventory hook
registers the manifest definitions and prepares the existing governed role and
Artist callback budget. Its post-bundle hook calls the
[scoped Finality fixture](../../test/helpers/StreamCurrentAuthorityScopedPreservationPolicyFinalityFixture.sol).
The original bundle-only contract's hooks remain empty.

The selected A, B or C era must be final before sanction. The current recovered
owner codecs do not admit operation12 or operation13 history; this recipe does
not establish sanction-before-migration support. Operation12 signs the exact
scoped manifest and nine ordered non-sanction components with the current
Artist's Safe and nonce. The archive retains the actual sanction record,
canonical ceremony and signature bytes, and receives separate complete archive
coverage. Missing archive evidence must fail before scoped execution.

The original Finality Registry then executes `finalizeArtworkScopeWithArchive`
under its real class2 governance action. Readback checks the exact scoped
record, manifest, archive witness, action and EXACT freeze mode. Preservation
producer bytes, current inventory and full bundle coverage, authority capture
and independent component facts are compared before and after sanction and
Finality. Live covered-token JSON must expose the actual current Artist
sanction; RELEASE and SEASON use genuine complete reverse membership, and the
TOKEN fixture preserves token2 as an uncovered control. The collection record
stays absent. Operation13 remains the separate permissionless COLLECTION-only
confirmation and is never called here; scoped Finality does not close or freeze
the entire collection.

`scopedFinalityEvidence()` returns evidence only after this local flow completes;
it rejects an uncompleted instance. Combined ABI checks and source review pass,
but this is authored source, not an executed ceremony. Native linked sizes,
transaction gas, fresh browser capture and end-to-end acceptance remain pending.
The inherited archive fixture uses synthetic checkpoint/observer evidence and
does not prove retrieval from an external archive network. Existing governed
callback budgets are preserved, not measured as deployment limits.

One applicability gap remains explicit: the immutable native sanction profile
catalogue text describes ONCHAIN COLLECTION, while these separately reviewed
preservation readers compose scoped sanctions. This source work does not revise
those immutable bytes or claim that catalogue wording covers the extension.

## Executable contract-composition cases

The distinct [scoped Finality tests](../../test/current/StreamCurrentAuthorityScopedPreservationFinality.t.sol)
drive the [test fixture](../../test/helpers/StreamCurrentAuthorityScopedPreservationPolicyFinalityTestFixture.sol)
through actual A-to-B-to-C migration, current-Artist producer reads, Reference
publication, complete inventory and bundle coverage, operation12, its separate
archive and governed scoped finalization. TOKEN, RELEASE and SEASON have
separate positive cases. The earlier publication tests remain unchanged.

These cases deliberately supply deterministic PNG, runtime-package and
environment fixture objects with actual preserved HTML/JSON. Their archive
checkpoint and observer attestations are synthetic inputs to genuine contract
verification, receipts and fixity checks. They test contract composition without
browser execution or a claim of external archive retrieval. Fresh observation
acceptance still uses the supplied-file local recipe above. Missing external
capture files cannot make a default test silently pass or skip.

Negative cases exercise a rejected scheduled finalization with missing archive
coverage and a mismatched sanction subject followed by the exact intended
authorization retry. They check retained protocol state and distinguish a
rejected scheduled action from the separate successful action. A narrow empty
hook in the shared Finality fixture permits these late failure checks before
the canonical positive finalization; the supplied-observation recipe leaves it
empty. The current Foundry profile has read access to
`docs/schemas/preservation` for the exact V2 definition documents. These cases
are authored source until their native campaign is recorded.
