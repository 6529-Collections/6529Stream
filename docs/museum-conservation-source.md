# Selected conservation evidence capture

`tools.museum.public_conservation_capture` captures and replays the existing
native conservation selector's evidence for one collection and token. It reads
the supported producer ABI, including original op24 publication evidence,
selected histories, exact interview references, catalogs and Artist intent locks.
No transaction is sent. A synthetic transcript remains a synthetic fixture.

This is a partial item-13 source package. Tier declaration, default-tier basis
and tier-dependent sale-floor evidence are separate required inputs. The report
keeps all 19 acquisition requirements visible and cannot export a complete packet.

## Source identity and scope

The source profile is `STREAM_MUSEUM_PUBLIC_CONSERVATION_SOURCE_V1`. Source review
is pinned to integration `dffb8daa315114a7b26b4cff67df5747834f7ff9`.
The conservation producer and interfaces were unchanged from `60a38477` at that
review. The capture profile is `STREAM_MUSEUM_PUBLIC_CONSERVATION_CAPTURE_V1`.

The external anchor fixes chain, Core, collection/token identity, block
hash/number/time/state root, deployment evidence and runtime hashes. The reader
checks the installed ACTIVE Core router, its original finality anchor, that
registry's immutable evidence provider, and `nativeConfiguration.targets[17]`.
That configuration binds the conservation selector; a caller cannot substitute
an arbitrary otherwise compatible selector. Core's Metadata and Artist facade
pointers, selector dependencies and Artist owner relationships must agree.

Both collection and token subjects have separate Artist and estate lineages.
Every revision from 1 through each native selected head is read. The reader
checks native selection hashes, exact signed predecessors, original publication
times and increasing original indices separately for intent and intent-waiver
lanes. It retains every ordered catalog occurrence, including duplicates.
An entirely zero head means no selected head on this exact bound selector. It
does not prove absence of generic publications, a tier default or a waiver.

## Original authority and interview evidence

Each selected original retains its complete Metadata record and nine-field
receipt, native record hash, lane index and chain, consumed authorization,
saved Artist publication/evidence, exact 416-byte versioned publication statement
and original signature-bundle bytes. The historical Artist operation class is
1 for Artist intent and 3 for estate statements. Metadata receipt class 1 is the
Artist publication branch and is not interchangeable with those operation classes.

The checks reproduce the conservation producer's original op24 correspondence.
They do not replay an archived operation or revalidate its signature. In
particular, a hydrated historical publication must not be rehashed using today's
Artist facade as its original signing domain. Each historical association stays
attached to its own record; later association or authority changes do not rewrite it.

PRESENT interviews follow the parent's exact chain/Core/host/record/schema/profile
locator. Their complete original JSON bytes and ordered external format-catalog
documents are checked. Known JCS Keccak/SHA references receive exact local digest
correspondence; other full references remain attributed claims. WAIVED requires
its own explicit statement and canonical empty interview evidence. An intent
waiver does not manufacture an interview waiver.

Referenced `preparedInterview` values are also retained. A zero value is valid
for ordinary full-witness adoption. A nonzero preparation has its own native hash
and event; its existence does not prove that an earlier adoption used it.
Unused preparations are outside this package's enumeration scope.

The original selector still consumes a single Store payload of at most 8,192
bytes. Newer Metadata support for larger chunked payloads does not expand this
producer's supported selection capacity.

## Historical evidence and current use

All nine fixed interpretation documents and all referenced catalog bytes remain
exact, including when a document is now inactive. Current definition or accepted
association failures preserve the selected history and set current-use eligibility
to false with an explicit reason. When those prerequisites hold, native
`requireCurrent` must return the exact selected head. A missing, contradictory or
unsupported selected original fails capture; the reader never chooses an older
interpretable record instead.

The one-way Artist intent lock is joined to its exact historical selected head
and event. The reader does not apply today's signer capabilities to a past lock.

## Capture and replay

Use the museum Python environment described in [the tooling guide](tooling.md).
Print exact profile pins first:

```powershell
python -m tools.museum.public_conservation_capture profiles
```

Prepare an externally reviewed source anchor and use a named process environment
variable for the RPC endpoint. The endpoint is not retained in the package.

```powershell
python -m tools.museum.public_conservation_capture capture --anchor out/conservation-anchor.json --anchor-hash 0xANCHOR --source-profile-hash 0xPROFILE --rpc-env STREAM_READONLY_RPC --disclosure public --output out/conservation-capture
python -m tools.museum.public_conservation_capture verify out/conservation-capture --manifest-hash 0xMANIFEST
```

For retained source bytes, `replay` accepts `--anchor`, `--anchor-hash`,
`--source-profile-hash`, `--transcript`, `--transcript-hash`, an explicit
`--provenance synthetic_fixture` or `trusted_rpc`, `--disclosure public` and a
new `--output` directory. Replay is offline and verifies deterministic
reconstruction before publication. The common package verifier also recognizes
this capture mode. Existing output directories are never overwritten.

Fixed filters cover block zero through the external anchor. Native selected
revision counts provide the selected-history denominator. Returned logs are
matched to complete successful receipts and canonical block headers, including
original publication before selection, lock and preparation order. Provider log
completeness and canonical mapping remain trusted; no consensus or receipt-trie
proof is claimed.

The [producer dependency ledger](museum-packet-producer-dependencies.md) retains
the required tier and canonical condition-source work. The separate
[packet V3 change](museum-acquisition-packet-v3.md) permits zero optional condition
captures; it does not select a latest report or prove no report exists.
