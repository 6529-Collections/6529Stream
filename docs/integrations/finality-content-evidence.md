# Validate current published content

`StreamFinalityContentReads` joins the Router's authoritative collection-root
publication to the actual complete checkpoint and preserved leaf-list artifact.
It is a library for the developing typed finality provider. The complete
ten-reference provider, discovery and finality execution remain in development.

## Deployment bindings

The consuming host constructs `Dependencies` from fixed deployment bindings.
Never accept this tuple from a transaction caller as proof of the installation.
The ten addresses, in order, are Core, artist facade, Router, Finality registry,
evidence provider, generic metadata host, schema registry, leaf verifier,
checkpoint and archival artifact aggregator. Preserve their original runtime
hashes and deployment chain. The host owns the governed read-gas parameter.

The consumer checks each runtime, the selected Core pointers and reciprocal
bindings. It recomputes the publication's original route commitment using all
ten addresses and runtime hashes. Fixed provider binding getters must remain
callable before a root or ready finality candidate exists; those getters cannot
require the very content whose publication needs them.

## Current facts

`requireCurrentCollection(dependencies, collectionId)` obtains the current
Router head itself. It verifies the complete record hash, approved state hash,
publication authority evidence, route, collection and current accepted artist
association. The root/count/schema getter must agree with the stored record.
The four root/leaf interpretation definitions must still be active and match
their exact registered bytes.

The library then reads `requireCurrentManifest` and
`requireCurrentCheckpoint`. Their collection, artist, root, count and manifest
identity must match the published record; the checkpoint must be complete and
retain the actual inventory and serving-source commitments. A new unindexed
mint, changed artist association, replaced route, or expired archive validation
cannot produce current evidence from a historical root.

The fixed 13-word `StreamFinalityContentEvidence` result contains the published
root record, verified manifest record, checkpoint, leaf artifact and its
coverage, artist identity/binding/generation, inventory and serving-state hashes,
content root, manifest content hash and leaf count. `leafCoverageHash` covers
only the leaf-list artifact. It does not establish full signature-bundle or
render-critical archival coverage. The checkpoint reference likewise does not
replace a complete snapshot, reference-render or other typed record.

An already-authorized publication survives ordinary publisher-grant revocation
or signing-authority rotation with the same accepted association. Reading it
does not repeat publication authorization. Core freeze also leaves the content
commitment unchanged. Historical Router record reads remain available when
current evidence fails.

## Validation boundaries

The focused suite composes actual Router, schema/store, token inventory,
checkpoint, leaf verifier and archival artifact aggregator. It includes actual
threshold Safe reads. Core, governance, artist, provider/Finality bindings and
archive receipts remain explicit boundaries; this is not a complete Finality
deployment or ceremony.

The consuming host must provide enough gas for nested reads. The fixture uses
a 5,000,000-gas forwarding cap above a verifier with its own 2,000,000-gas cap.
A parent with the same 2,000,000 cap fails; it cannot report partial success.
These are fixture values, not a deployment-wide gas recommendation.

See [root publication](content-root-publication.md),
[leaf verification](content-leaf-manifests.md), and
[ADR 0041](../adr/0041-typed-finality-evidence-provider.md).
