# Metadata publication after an Artist registry cutover

`StreamCollectionMetadataV1` retains its original Artist address and runtime hash
as birth anchors. Its existing candidate and detached-publication entry points
can also use one current, completely hydrated successor. This consumer bridge
does not import Artist authority or create publication consent.

The original selected Artist path needs no history or hydration read. The fixed
[selection worker](../../smart-contracts/domains/metadata/StreamMetadataArtistSelection.sol)
requires the following for a successor:

- Core still selects this collection-record host and the successor Artist, with
  their actual runtime hashes. The original Artist retains its saved runtime.
- The original operation-57 seal names that exact successor. The successor has
  one immediate, nonempty history binding to the original, its exact runtime pin,
  and a snapshot no later than the seal.
- The current Coordinator's saved suite, deployment chain and all sixteen live
  target runtime hashes match its original immutable configuration commitment.
- All seven current owners expose the same nonzero hydration commitment. One
  owner's completion, an imported lane, or an accepted binding is insufficient.

The [configuration reader](../../smart-contracts/domains/metadata/StreamMetadataArtistConfiguration.sol)
uses the existing `suiteConfiguration`, `configurationHash`, `finalityRegistry`
and `finalityEvidenceProvider` getters. It reconstructs the exact original
Coordinator constructor preimage, including all sixteen current target code
hashes and both finality code hashes. This retains the original runtime pins
without reading duplicate stored target/hash arrays. A different constructor
commitment recipe is rejected; no new Artist API or gas parameter is introduced.

Completed operation 60 supplies the immutable source relationship. Every current
profile checks equal Core, Manager, RoleRegistry, MetadataRouter, PrimaryResolver,
RoyaltyResolver, PrimaryRevenueClass and Validator, plus each source owner's
reciprocal binding and domain. It rechecks source headers and the exact source
suite before its atomic Archive append. Both suites and owner bindings are
constructor-only. The one-time marker has a single writer behind the fixed
Coordinator's operation-60/context/snapshot guards. The consumer relies on this
admitted relationship instead of repeating the old Coordinator suite read.

This is a committed-state provenance invariant, not a generic in-flight barrier:
markers are assigned before remaining imports and Archive work. Future hydration
profiles must preserve the source invariant. Original publication consent and
Metadata's authorization-use guard remain mandatory.

Artist's suite `metadata` dependency is the rendering **MetadataRouter**, distinct
from this collection-record host. The preserved router must remain the current
Core `METADATA_ROUTER`, with matching runtime and reciprocal Core. The record
host remains separately selected under `COLLECTION_METADATA`.

Publication calls the captured selected Artist's original
`requireRecordPublication(authorization, publication)` entry. Candidate schema,
subject, retained bytes and canonical record preimages remain Metadata's
responsibility. After append, Metadata rechecks selection and lineage before
emitting the original consumption event. The same host's
`consumedArtistAuthorization` map remains authoritative: cutover cannot revive an
already consumed authorization. Historical reads and record domains are unchanged.

The original publication projection, candidate validation and subject preimage
execute in a fixed linked worker. Host selection and collection/subject checks
remain first; schema/code checks, chunk reads and candidate hashes retain their
order. Existing receipt/payload reads use the existing manifest worker with the
same storage references and original pointer-lookup-before-code-check order.
The original host ABI and recursive storage layout are preserved.

## Validation boundary

Eight successor cases plus all fifteen original Metadata cases are run against
real Metadata, schema registry, byte store and Safe 1.4.1 contracts. They cover
all-seven completion, original consumption after cutover, exact seal/predecessor,
suite/runtime substitutions, unavailable reads, append rollback and an identical
signed Safe retry. The original payload property runs 256 inputs. The callback
case uses the actual `StreamArtistRecordPublicationReads.candidate` worker at
its unchanged 400,000-gas limit, both warm and with explicitly cooled dependencies.

The independent fixture configuration-hash oracle is copied literally from the
actual Coordinator constructor and compared against the current constructor
source. Core governance, Artist history/completion and Coordinator construction
remain explicit typed boundaries; this is not execution of operations 55–57/60.
Actual imported publication history and the full genuine Artist/Metadata join
remain separate integration work. Earlier failed warm/cold captures are retained.
No broadcast, institutional conformance or full-system acceptance is claimed.

The final frozen 110-source cohort passed all 23 tests, including the 256-input
property. A compilation-skipped trace measured the actual candidate callback at
145,951 gas warm and 207,951 gas cold within its unchanged 400,000 limit. These
measurements apply to the explicit typed graph above. All 43 production products
in this closure fit the runtime/creation limits; Metadata runtime is 24,239 bytes
(337 bytes of headroom). All 119 original ABI entries and 15 recursive storage
roots remain exact. Whole-project linked size and genuine Artist integration
must still be checked against the joined source.
