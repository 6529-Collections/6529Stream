# Publish a verified artwork content root

The Router can adopt a complete, preserved ONCHAIN content manifest with the
artist's exact approval. Use
[IStreamContentRootPublication](../../smart-contracts/interfaces/stream/metadata/IStreamContentRootPublication.sol)
at the deployed Router address. The generic collection metadata host supplies
governed publisher grants and interpretation documents; it remains a separate
contract. The typed evidence provider joins those contracts through fixed
deployment bindings.

This implementation covers collection roots for the existing inline ONCHAIN
profile. Full finality execution, other content profiles and scopes, the
specification's seven-argument `publishTokenContentRoot` facade, larger composed
manifests and complete deployment acceptance remain in the delivery ledger.

## Prepare publication

1. Configure and lock the artwork's serving fields. Complete the
   [token checkpoint](onchain-content-checkpoints.md) and
   [preserved leaf manifest](content-leaf-manifests.md).
2. Through the governance Executor, register the four exact interpretation
   documents returned by
   [StreamContentRootSchemas.document](../../smart-contracts/domains/finality/StreamContentRootSchemas.sol):
   `STREAM_TOKEN_CONTENT_LEAF_MANIFEST_V1`,
   `STREAM_ABI_TOKEN_CONTENT_LEAF_MANIFEST_V1`,
   `STREAM_TOKEN_CONTENT_ROOT_RECORD_V1` and
   `STREAM_ABI_TOKEN_CONTENT_ROOT_RECORD_V1`. Register their definition bytes
   under `RAW_BYTES`, with their respective schema/canonicalization kinds.
   Publication checks each active definition's exact identity, kind, content
   hash and `RAW_BYTES` registration. These definitions describe Stream's exact
   Solidity ABI and JSON byte formats; they do not label Stream JSON as JCS.
3. Grant the intended publisher `SNAPSHOT` family authority in
   `StreamCollectionMetadataV1`: class 7 at the collection, or class 8 at global
   scope zero. If both apply, class 7 is selected. These are existing family
   grants; no numbered genesis role is added. Generic `SNAPSHOT` records remain
   inadmissible as a substitute for typed publication.
4. Construct `Publication(collectionId, expectedPredecessor,
   verifiedManifestRecordHash, manifestURI)`. The predecessor is the current
   `collectionContentRootHead`, initially zero. The URI uses the existing
   content-URI validation and 2,048-byte limit. Its exact bytes are approved;
   the preserved artifact, rather than fetching that URI, establishes content.
5. Call `previewContentRootPublication(publication, publisher)`. Have the artist
   authorize operation 17 for that exact Router, collection, `CONTENT_ROOT`
   family and returned state hash through the existing artist consent flow.
   The preview includes the publisher, selected grant class/revision, current
   accepted artist association and fixed component route.
6. From the approved publisher, call
   `publishVerifiedTokenContentRoot(publication)`. A Safe can be the publisher.
   The Router consumes the exact artist consent, rechecks the complete prepared
   facts and appends the record atomically. A failed transaction retains both
   the prior root and the unconsumed consent for retry.

Writer revocation and regranting, artist generation changes, replaced runtime
bindings, stale coverage, changed content or a different predecessor invalidate
old preparation. A Core-frozen collection rejects new publication. Existing
ratification/evolution continuity also applies; publishing a root does not
silently replace an artist's previously ratified content state.

## Read and index

`tokenContentRoot(collectionId, scopeSubject)` returns the authoritative root,
leaf count and leaf schema for the canonical collection subject. Other subjects
return zero. `contentRootRecord(recordHash)` retains the complete historical
publication, manifest identity, publisher/grant evidence, artist association,
route hash, consent and timestamp. These historical reads remain available
after evidence becomes ineligible for a new publication.

`TokenContentRootPublished` and `ArtistContentConsentApplied` both emit from the
Router. The first contains the complete record and canonical collection subject;
the second joins the consumed artist consent to the resulting aggregate content
state. The approved state excludes its own state-hash field, consent identifier
and publication timestamp, all zeroed in the documented state preimage. The
historical record hash includes the completed record.

The content-root family starts with a nonzero empty-state commitment. Once
published, its state contributes to the artist's aggregate content commitment.
It does not change the serving-source commitment used to verify its own
checkpoint. This avoids a root publication invalidating the evidence that
justified it.

## Gas and tested boundaries

The Finality component-read cap must provide headroom for the manifest
verifier's own governed reads. A 2,000,000-gas parent forwarding to a verifier
that requires that same child cap fails the explicit parent-gas check. The
composition fixture uses a 5,000,000-gas parent with a 2,000,000-gas manifest cap;
it covers that failure, atomic rollback and retry with coherent caps. These
fixture values do not replace the final deployment's gas configuration.

The focused tests use actual Router, schema/store, writer grants, token
inventory, checkpoint, manifest verifier and archival artifact aggregator.
They exercise real threshold Safe calls. Core membership, governance execution,
artist consent, archival receipts/families and Finality/provider facts are
explicit test boundaries. Actual artist and full Finality execution still need
to be composed with this path before complete release acceptance.
