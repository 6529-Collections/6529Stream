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

The local entrypoints stop at bundle evidence. Sanction publication, its separate
archive evidence and terminal Finality acceptance are additional integration
work. ABI validation and source review do not establish any of those outcomes.
