# Record selectors after Artist succession

Generic collection Metadata keeps its original Artist address and runtime as an
immutable provenance anchor. The selected Artist can change through the real
history import, cutover and complete authority-hydration ceremony. A new WORK,
CONSERVATION or RIGHTS selector must resolve that authenticated current Artist
without changing the original Metadata deployment or its saved records.

`StreamRecordArtistIdentityReads.resolveCurrent` uses the existing
`StreamMetadataArtistSelection.selected` proof. The selected Core pointer,
original runtime, sealed predecessor, imported history and all seven matching
authority-hydration commitments remain mandatory. Repeated succession uses the
same existing ancestry proof. The selected Coordinator and Identity owner still
pass the original fixed-length suite, reciprocal Core/registry/Coordinator,
chain and runtime checks. No caller supplies a replacement owner or signer.

`knownCurrentIdentity` re-resolves that graph before comparing all three saved
pins and reading the immutable registration hash. Current signer, status and
authority class remain separate facts. Changing them does not change what the
registration hash means. Changing the selected graph invalidates an old pinned
selector for new consumption; its historical records remain available.

The current WORK, CONSERVATION and RIGHTS selector paths and current personhood
reader use these additive functions. The original `resolve` and `knownIdentity`
continue to read the original Metadata-bound graph. Historical preservation and
archive loaders retain that original behavior; migrating their provenance is a
separate exact-evidence join, not a blanket substitution of today's Artist.

Successor selector construction follows actual operation60 completion. The
successor Finality Registry and Coordinator can be constructed earlier, with
their real counterpart pins; the reusable successor deployment helper must keep
the final selector phase separate from the earlier history/pointer ceremony.

Dependency read caps, authority, record domains, storage and original public
interfaces are unchanged. Combined ABI/type checks establish source consistency.
Focused malformed/succession tests and the actual-current Safe migration recipe
have separate source and runtime acceptance; this guide does not claim a tested
complete migration or finality graph.
