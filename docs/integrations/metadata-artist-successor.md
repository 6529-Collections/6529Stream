# Metadata publication after an Artist registry cutover

`StreamCollectionMetadataV1` retains its original Artist address and runtime hash
as birth anchors. Its existing candidate and detached-publication entry points
can also use one current, completely hydrated successor. This is a consumer
bridge: it neither imports Artist authority nor creates publication consent.

The original selected Artist path needs no new history or hydration read. The
successor path uses the fixed
[selection worker](../../smart-contracts/domains/metadata/StreamMetadataArtistSelection.sol)
to require all of the following:

- Core still selects this collection-record host, and selects the successor
  Artist address with its actual runtime hash. The original Artist runtime still
  matches the saved birth anchor.
- The original Artist's operation-57 seal names that exact successor. The
  successor has one immediate, nonempty history binding to the original, with
  the original runtime pin and a snapshot no later than the seal.
- The two Coordinator suites identify their respective registries and distinct
  archives, preserve all eight non-Artist dependencies, and have reciprocal
  owner bindings with matching owner domains and the current deployment chain.
- All seven successor owners expose the same nonzero completion commitment.
  A lane proof, an accepted binding, or one owner's completion is insufficient.

Artist's suite `metadata` dependency is the rendering **MetadataRouter**. It is
distinct from the collection-record host. Both suites must preserve that router,
which must remain the current Core `METADATA_ROUTER` with matching runtime and
reciprocal Core. The record host remains separately selected under
`COLLECTION_METADATA`.

Publication calls the captured selected Artist's original
`requireRecordPublication(authorization, publication)` entry. Candidate schema,
subject, retained bytes and canonical record preimages remain Metadata's
responsibility. After append, Metadata rechecks selection and lineage before
emitting its original consumption event. The same host's
`consumedArtistAuthorization` map remains authoritative across cutover: an
already consumed authorization cannot be revived by imported Artist history.
Historical record reads and their original domains remain unchanged.

The bridge uses this Metadata host's governed `DEPENDENCY_READ_GAS` for fixed
lineage and owner reads. The original `ARTIST_READ_GAS` still bounds publication
consent. Artist's own publication worker separately limits its candidate
callback; this feature does not raise any of those budgets.

## Validation boundary

Eight authored cases in
[StreamMetadataArtistSuccessor.t.sol](../../test/unit/metadata/StreamMetadataArtistSuccessor.t.sol)
type-check with the real Metadata, schema registry, byte store and Safe 1.4.1.
They cover original consumption across cutover, every owner's missing/mismatched
completion, seal/source/runtime pins, distinct router selection, suite and owner
substitution, missing reads, late append rollback, and byte-identical Safe
transaction retry. One case invokes the actual fixed
`StreamArtistRecordPublicationReads.candidate` worker using the original
400,000-gas publication budget and unchanged Metadata defaults.

These are authored, ABI-checked cases, not executed runtime results. Artist
history, Coordinator/owner completion and Core governance are explicitly typed
test boundaries. Actual operations 55–57/60, imported publication history and
full genuine Artist/Metadata composition remain separate integration work. Gas
sufficiency, linked-product sizes and full-system runtime acceptance are not
claimed by this source handoff. No broadcast or release evidence is produced.
