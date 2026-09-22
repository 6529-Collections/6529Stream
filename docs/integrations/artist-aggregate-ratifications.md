# Aggregate original ratification history

The developing operation-60 implementation can carry original operation-52
ratifications within the bounded multiple-generation, multiple-dispute and
PRIMARY_ONLY collaborator profiles. This is a source implementation extension;
native capacity, complete owner execution, Safe execution and release acceptance
remain separate requirements. The [complete authority decision](../adr/0047-complete-artist-authority-hydration.md)
continues to govern all seven owners and their complete conditional dependencies.

The extension uses the existing `RATIFICATIONS` capability, bit 1024, only when
the complete original owner-6 journal contains ratifications. It does not select
a different top-level profile. Generation, dispute, collaborator, authority and
source-cutover admission retain their existing boundaries. An otherwise
unsupported source cannot become supported merely by adding this feature bit.

## Original records and conservation

The original `RatificationRecord` stores exactly its record hash, content-state
hash and metadata contract. It does not store a generation, signer, nonce or
timestamp. The fixed source worker retrieves every original record in full
owner-6 journal order, requires a zero delegation association, and compares each
collection's actual current head with its last original record or an exact empty
head. The proof also joins every original occurrence and subject to the saved
Identity signature and original provenance point.

Complete Identity source checks retain the original authority state, consumed
nonces, replay guards, signatures and owner-local clocks. Hydration does not
repeat current authorization, query current metadata as a substitute for the
historical record, infer missing signed fields or charge a delegation use.
Original operation 52 writes Identity and Consent; its Attribution snapshot is
a read dependency. This extension creates no Attribution mutation or synthetic
owner-4 occurrence.

The shared consent validator accounts for ratifications alongside all admitted
policy, economics, sale, content and freeze records over the complete owner
certificate. It checks the original ratification replay scope, every journal
occurrence, era clock and replay alias. No per-collection filtered provenance is
constructed. Grant conservation uses a separate explicit ratified entry after
the ratification facts have been authenticated; the prior entry remains strict.

## Transport and destination

Collections without ratifications retain their exact prior `G.Consents` bytes.
A collection with ratifications uses the canonical
`6529STREAM_ARTIST_AGGREGATE_CONSENT_SUPPLEMENT_V1` row wrapper, containing the
original consent tuple, original ratification records and a sanction-inventory
byte field. This batch rejects every nonempty sanction field; future sanction
work must decode and validate its canonical global inventory in a fixed typed
worker. A wrapper never licenses an ignored family. Empty wrappers,
noncanonical encodings, missing required capability and capability assertions
without actual rows are rejected.

The fixed Consent owner hook installs the existing per-collection head and
per-record maps, then continues through the existing aggregate Consent import
in the same guarded operation. The latter validates the complete combined
journal before owner completion. A later validation, owner or Archive failure
rolls back all these writes. This adds no storage root, public source getter,
Coordinator recipe, signer type or separate import transaction.

## Remaining scope and evidence

The existing bounded profiles still require their accepted latest binding and
same-Artist generation histories. Full sanction operations 12/13, broader
Platform/collaborator/dispute compositions, changed-Artist or pending-head
chronology, and class-4/steward history remain independent source work. Current
attribution state 3 is not admitted without its actual sanction history. The
dedicated ratification workers can be reused by future complete profiles only
with those profiles' authentic subject and history joins.

The authored common-worker cases use a complete synthetic journal/replay
certificate and explicit source-authentication boundary mocks. Separate
aggregate owner scenarios exercise original operation 52 and seven-owner
hydration with the existing fixture boundaries. Neither source authorship nor
ABI checking establishes that those scenarios have executed or that genuine
current-Core integration, deployment size or gas requirements have passed.
