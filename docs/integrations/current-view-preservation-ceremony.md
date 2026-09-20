# Actual current-stack VIEW preservation ceremony

This source recipe composes the original current graph with the explicit
non-sanction VIEW profile from [ADR 0054](../adr/0054-explicit-non-sanction-preservation-rendering.md).
It is an authored acceptance fixture. Source review and ABI checks do not prove
execution, browser observations, transaction capacity or completed finality.

## Contracts and authority

The recipe uses the same single combined provider, with its original four
constructor arguments and once-only governed VIEW binding. It deploys the real
CollectionViews and preservation products after original activation. A separate
late RendererRegistry admits the actual VIEW renderer and preservation producer;
the earlier STATIC Registry keeps its original fixed roster.

Artist content authorization uses the original two-signature Safe through
ERC-1271. Registry admissions, grants and locks use the original delayed
governor and root Safe. Snapshot and root publication are calls from the fixture
contract with explicit class-7 Metadata grants. A publisher grant alone does
not supply the separate Artist content consent.

## Publication order

The helpers are split by their actual dependencies:

| Stage | Genuine source and retained assertion |
| --- | --- |
| Declaration and adoption | Locked membership, original policy source set, retained declaration payload, actual admitted V2 renderer and separate RENDERER_CONFIG op17 consent |
| Preservation admission | Complete fixed read roster and explicit preservation golden modes in the late Registry |
| Output checkpoint | Every ordered member's current JSON and HTML, exact byte lengths, full entropy row and independent two-leaf content-root calculation |
| Covered manifest | Exact 64-row part format with the final two-row remainder; independently encoded index, original archive receipts and complete ArtifactCoverage |
| Root-free snapshot | Exact definitions, SNAPSHOT and IDENTITY publisher grants, full current source, retained payload and original class-2 seal |
| Content root | Snapshot-derived preview, a distinct CONTENT_ROOT Artist consent, original consumed-consent book and shared scoped root history |
| Original freeze | STATIC family lock and Core closure/freeze follow publication; the fixture rereads all current outputs and source receipts afterward |
| Reference observation | Explicit supplied environment, runtime package and repeated first/last captures joined to exact complete VIEW input bytes |

The snapshot deliberately has no dependency on a future content root. The root
uses the snapshot's current source. Neither output archival nor a snapshot
grants root authority. First/last reference captures are observations; they do
not replace complete membership or inventory coverage.

## Budgets

The fixture preserves the existing VIEW configuration:

| Call boundary | Gas cap |
| --- | ---: |
| Governed VIEW scalar reads | 2,000,000 |
| Declared VIEW source reads | 4,000,000 |
| Serving live renderer / attribution | 3,000,000 / 4,000,000 |
| Checkpoint serving | 9,000,000 |
| Manifest checkpoint validation | 12,000,000 |
| Snapshot source / inventory | 14,000,000 / 4,000,000 |
| Provider snapshot validation | 16,000,000 |
| Newly constructed late Registry reads | 4,000,000 |

The late Registry explicitly selects 4m at construction: its full producer
binding validation must forward the original Router's 2m read plus the strict
transport reserve. A 2m outer call cannot do that. This choice applies only to
the new Registry; original Registry configurations and all existing C/Router
caps remain unchanged. Checkpoint admission calls this Registry under its
original 9m serving cap. The forwarding inequality is source evidence, not an
execution result or transaction-limit exception.

The reference host uses the existing C component constructor tuple
`read/source/snapshot/archive = 1m/16m/16m/1m`. The COLLECTION reference tuple
is a separate profile and is not substituted. These numbers identify actual
configuration, not measured capacity. Necessary forwarding margins do not prove
that complete nested reads or cold calls fit.

## Source entry points and evidence

- [Adoption fixture](../../test/helpers/StreamCurrentFullPreservationPolicyViewAdoptionFixture.sol)
  supplies the pre-freeze adoption hook and original Registry admission.
- [Publication fixture](../../test/helpers/StreamCurrentFullPreservationPolicyViewPublicationFixture.sol)
  constructs full checkpoint, manifest, snapshot and root evidence.
- [Reference fixture](../../test/helpers/StreamCurrentFullPreservationPolicyViewReferenceFixture.sol)
  derives its seven targets from the same graph and consumes explicit observation inputs.
- [Publication cases](../../test/current/StreamCurrentFullPreservationPolicyViewPublication.t.sol)
  cover publication, missing consent, wrong snapshot revision, stale predecessor
  replay while unfrozen, incomplete output retry, runtime drift and snapshot sealing.

`runSuppliedViewReferenceObservation(environmentJSON, browserJSON, capturesJSON)`
is an explicit observation entry, not a default passing test. Its environment
ABI, ZIP endpoint witnesses, token identities, full JSON/HTML and repeated PNG
hashes must describe this exact graph. The helper checks their joins; it does
not execute a browser or establish the provenance of caller-supplied captures.
Locally signed archival observations and producer-derived admission goldens are
fixture evidence, not independent analysis or public archival retrieval.

Complete VIEW inventory, archive-bundle closure, provider finality dispatch,
sanction archival, original finalization and confirmation remain separate
required work. Preserve the original failed full-output sanction-cycle capture.
Full current-stack, gas, size, fuzz, CI and testnet acceptance remain open.
