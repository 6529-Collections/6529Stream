# VIEW media and sanction worker regression boundary

This separate test batch calls the production `StreamFinalityViewMediaReviewV1`,
`StreamFinalityViewPreservationSanctionReviewV1` and
`StreamFinalityViewSanctionProfileV1` workers. Production source remains the
reviewed `149b695a` version. The 15 cases are authored and typechecked; they have
not run, and neither harness size nor whole-flow gas is accepted by this batch.

The fixture uses the actual SchemaRegistry, SchemaDocumentStore and immutable
payload carriers, plus original ExternalArtifactCoverage, its native checkpoint
verifier, role registry and real Safe threshold signatures. The existing complete
browser-package archive fixture supplies its exact bytes/digests/native data paths.
The optional image slot deliberately references that opaque complete archived
file: these tests prove correspondence, not image decoding or a browser render.
Separately, the reference PNG object records contain a fixed valid one-pixel PNG;
its CRCs and deflated scanline were checked when authoring the fixture.

Provider selection and binding, Metadata Artist facts, the retained declaration
and reference receipt, completed inventory and bundle evidence are typed test
boundaries. Their full canonical preimages are constructed explicitly, but no
Artist/op17, snapshot, inventory sealing, governed provider binding or reference
writer authority is executed here. These tests cannot replace that full recipe.
The declared reference capture coverage remains a boundary; the genuine Archive
pair is exercised for the media occurrence.

Seven media cases cover present/absent image, exact stage and segment ordinal,
every selected admitted-row coordinate, a different canonical raw CID against the
original object, current archive-family invalidation/restoration, and a changed
saved Admission. The original complete content Keccak is compared independently
against the URI hash and SHA256. Unknown CID length becomes the exact full
nonzero length only through original archive evidence.

Eight sanction cases cover complete repeated PNG occurrences, original empty-media
profile2, current/original reference mismatch, independently resealed bad capture
fixity, actual ACTIVE-to-DEPRECATED catalogue transition, actual Store carrier
corruption, adversarial catalogue facts, and current Archive refusal/restoration.
Catalogue retirement is irreversible in production: restoration uses an explicit
test-state snapshot, not a fictional activation transaction. The archive-family
restore uses its actual authorized status transition. Cases retain the identical
request and output hashes across restoration where applicable.

Only backend1 external media is exercised. Backend2/onchain media, HTTPS/Arweave
URI correspondence, full source authority, maximum-scope capacity and a real
sanction ceremony remain distinct required work. Diagnostic fixture read budgets
are not a claim that the composed operation fits the protocol transaction limit.
