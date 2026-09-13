# Authenticated WORK selection

`StreamWorkRecordSelection` maintains an explicit current head for each exact
collection and WORK subject. It consumes the complete supported
`STREAM_WORK_DESCRIPTION_V1` meaning, including the explicit
`description_absent` alternative. The original append-only Metadata dossier is
unchanged. The selector is a separate contract; a per-author latest record is
not an authoritative current head.

This is a bounded implementation profile. The focused fixture executes the
actual Metadata host, Schema Registry and document Store. Its Core, governance
Executor and artist-owner graph are explicit response fixtures. Actual current
Core, governance and artist-owner composition, provider integration,
registration of this selection policy, and full Museum acceptance are separate
evidence boundaries.

## Selection policy

Two methods have different authority semantics:

* `selectCurrent` requires a current Metadata `CURATOR` family writer grant.
  Class 3 precedes class 8; within each class, collection-specific grants
  precede deployment-wide scope 0. It may select an admitted artist or curator
  original. The resulting receipt records the exact selector, class, grant
  scope and revision.
* `adoptArtistRecord` implements the explicitly adopted
  `ARTIST_RECORD_ADOPTION` rule. An authenticated op24 WORK statement authorizes
  adoption only from the exact predecessor committed by its complete payload.
  Anyone may deliver that already-published statement. The receipt identifies
  the submitter separately from its original artist recorder and records no
  invented current selector grant or artist-signature authority.

Both require the exact expected selected head and revision. The payload
predecessor must equal that head, including zero for first selection. Every
successor's original shared WORK-lane index must be greater than the selected
head's original index. A racing selection or curator successor cannot be
bridged by reusing an artist statement signed for an earlier predecessor.
Failed validation leaves the head and revision unchanged.

Permissionless adoption is an explicit selection rule, not a replay of the
consumed signature as a new op24 operation. It never resets or consumes another
artist nonce, changes an original deadline, requests a new current signature,
or labels the relayer as an artist. Previously published statements remain
eligible after key rotation or succession when their original association is
unchanged and accepted or sanctioned. Publication evidence retains the
original signer and original authority class.

## Exact meaning and provenance

The reader checks the exact five retained documents: the WORK schema and JSON
profile, the supported format-catalog schema and JSON profile, and
`RFC8785_JCS`. `python -m tools.metadata.work_definitions --check` independently
checks generated identifier, complete content hash and byte-length constants
against the retained originals. Static definition documents use the registered
`RAW_BYTES` bootstrap; their original bytes are not rewritten. Canonical WORK
payloads use the exact registered `RFC8785_JCS` definition.

Each call supplies `Witness { original, description }`. The complete original
`CollectionRecord` is untrusted input; it is not an alternative source of
authority. The complete typed description must serialize byte-for-byte to the
stored payload.
No title, credit, creator, exact date or range, PRONOM/catalog reference,
dimension, unreduced duration/aspect rational, edition, inscription, alternate
title, language variant or authority reference can be silently ignored.
Inactive unions remain zero or empty. Missing required full fields do not
become an automatic absence declaration. Both source absence reason and date
remain committed. The total WORK payload limit is 8,192 bytes.

A format catalog witness reconstructs every ordered entry, including
unselected entries, and proves the selected identifier's unique mapping. Its
complete bytes must match an actual registered catalog under the exact name
and JCS canonicalization. Neither PRONOM nor catalog correspondence proves
that someone inspected or identified a file's format.

The original generic witness is joined to its actual fixed nine-word receipt,
original 14-word hash, shared-lane index and rolling chain hash. This commits
the exact original URI and both complete HashRefs without asking a capped
getter to copy the URI's storage. An artist original also
requires the actual Metadata consumed-authorization backlink, complete saved
publication tuple and evidence, metadata runtime pin, op24 attestation record,
and exact versioned publication statement bytes. The reader consumes the
original owner's authenticated stored result; it does not independently
reexecute the original signature or reconstruct an absent nonce/deadline from
the reduced historical reader ABI.

A full ARTIST creator must name the current accepted/sanctioned binding's exact
artist ID, generation and hash. The immutable identity-registration hash must
match the selected Identity owner. A NAMED creator is supported only when the
current binding record is entirely empty; it cannot override an existing
artist association. An artist-authored absence retains its author's binding
evidence while leaving creator facts absent. A curator-authored absence does
not invent a creator or require an artist claim.

## Deployment, current use and history

Construction pins the actual Core, Metadata, Schema Registry and Store, plus
the Metadata-selected artist facade, Coordinator and Identity/Binding/
Attribution owners. Metadata and the artist facade must already be selected in
Core at construction. Both new bounded-reader interface capabilities must be
advertised; a missing capability fails at construction. Definition registration may follow deployment, but it
must be complete before selection or current consumption. The selector does
not accept a caller-selected Identity owner.

`currentWork` and `workSelectionAt` are local historical reads. They retain the
complete selection receipt despite later grant revocation, definition
retirement, association change or provider unavailability. `requireCurrent`
additionally requires the exact head/revision, pinned current deployment,
active exact interpretation definitions and the applicable unchanged artist
association/catalog. It does not retroactively reapply today's publisher or
selector grants to an already accepted receipt.

`IStreamSchemaDocumentFacts` supplies a canonical nine-word header and ordered
per-document chunk hashes, including repetitions. The reader reconstructs the
whole content from the actual Store and checks every byte through its length
and complete hash. The Registry derives each document ID from its exact name.
Registration URI is metadata outside document content; the compact
declaration hash retains provenance, without a claim to reconstruct the
omitted registration name/URI preimage.

Every dependency read has a bounded output and uses the actual Metadata
governed dependency-read cap, with parent-gas admission immediately before the
static call. Narrow integers, booleans, addresses and dynamic ABI shapes are
checked canonically. Core's stored selected-pointer status is an installation
fact; this reader does not claim it independently proves every live module
registry or finality eligibility rule.

Full `document()` and `collectionRecord()` convenience getters can exceed the
150,000 cap for valid 2,048-byte URIs. This reader uses compact facts and
receipts, with a complete original record witness, to retain those valid
shapes. Cold maximum-shape controls cover both registration and record URIs
without raising the cap or shortening supported values. The broad deployment
and full current-owner composition qualifications above still apply.
