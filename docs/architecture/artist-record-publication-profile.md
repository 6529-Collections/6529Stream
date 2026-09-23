# Artist record publication through operation 24

This is the bounded metadata publication profile implemented alongside the
existing artist attestation operation. Runtime and current-stack acceptance are
recorded separately. It preserves the operation's signature tuple, nonce and
digest revocation lanes, permanent attestation record, event and Archive domain.
It does not replace the generic metadata record's permanent preimage.

The unchanged attestation statement contains exactly
`abi.encode(uint16(1), Publication)`: 416 bytes. The outer attestation schema is
`keccak256("6529STREAM_ARTIST_RECORD_PUBLICATION_V1")`. `Publication` contains,
in order, metadata host, recorder, collection ID, subject ID, record type,
payload schema ID, canonicalization ID, payload hash algorithm, payload hash,
URI hash, effective time and candidate record hash. The supported payload hash
algorithm is 1, Keccak256. The URI hash equals the hash of the attestation URI.

The metadata host independently derives the candidate record from these terms,
the actual immutable bytes and registered schema/family/scope. This profile uses
zero signature scheme and empty signature reference in that generic record;
the exact existing hash-reference encoding is retained. The authorizing
attestation is stored as separate evidence after publication. Neither the
payload nor candidate record embeds its own authorizing attestation. Shared
permissionless byte publication makes a pending-candidate queue unnecessary.

| Metadata family and schema | Attestation subject | Required capability |
| --- | --- | --- |
| ARTIST_INTENT / STREAM_ARTIST_INTENT_V1 | 7, exact candidate record hash | CAP_INTENT_RECORDS, 64 |
| ARTIST_INTENT_WAIVER / STREAM_ARTIST_INTENT_WAIVER_V1 | 7, exact candidate record hash | CAP_INTENT_RECORDS, 64 |
| ARTIST_SEMANTIC_ASSERTION / STREAM_SEMANTIC_ASSERTION_V1 | 8, zero subject-state hash | CAP_ATTEST, 1 |
| ARTIST_STATEMENT / a host-admitted statement schema other than the two intent schemas | 8, zero subject-state hash | CAP_ATTEST, 1 |

Subject 7 follows the specific AA-INTENT capability rule: capability 64 alone
suffices; capability 1 is not an additional requirement. Subject 8 remains a
freeform assertion and makes no state-staleness claim. Its publication envelope
still binds the exact target, family and bytes. The host independently enforces
its narrower registered schema/family map; an intent capability cannot authorize
an arbitrary statement or interview family.

The supported authority path uses the current principal of a PRIMARY_ONLY
binding, with its accepted collaborators and immutable binding terms checked.
ACTIVE/class 1 and SUCCEEDED/class 3 are distinct admitted Identity pairs; an
estate successor also needs the exact current family capability. The separate
Attribution state must be ACCEPTED (2) or SANCTIONED (3), with the exact current
binding generation. Identity contest status 4 does not count as sanction.
Threshold co-signatures, delegated publication and steward publication require
their own typed admission paths and remain explicit work.

The Coordinator validates the selected canonical metadata host, its current
runtime hash, reciprocal Core and canonical active module admission. It obtains
the exact candidate through `requireArtistRecordCandidate(Publication)`, a
64-byte validating result. The candidate read cannot itself grant artist
authority. The signature authenticates the current principal, which must equal
the recorder; the external relayer remains separate.

Identity consumes the existing operation-24 authorization and replay once.
Attribution retains the original attestation and statement bytes and appends
immutable detached publication evidence: record hash, artist ID, binding hash,
binding generation, signer, authority class, required capability, signed time
and `publicationHash`. This last value is exactly
`keccak256(abi.encode(Publication))`; the outer statement hash separately commits
the version word. The captured metadata runtime hash is stored beside it. All
of these facts enter the same Attribution state commit and Coordinator Archive
evidence. A failed final append reverts both owners and nonce consumption.

`requireRecordPublication(recordHash, Publication)` returns exactly those nine
evidence words after checking the current binding, principal/class/capability,
host code and candidate again. It is a public validating read, including for
direct Safe CALL; it consumes no authority. The actual metadata publisher
consumes the exact detached authorization once and rolls its consumption back
if publication fails. An unused attestation by a rotated or deceased principal
does not authorize a new publication by that old principal. Already published
records keep their original signer/class and use historical evidence without
rejoining current authority.

The facade forwards this caller-independent read only to its existing fixed
read child, which rejects direct calls. The Attribution callback keeps its
Coordinator guard and one semantic commit; its linked publication mechanics
operate on the owner's exact storage references. The original subject-9 and
subject-10 attestation paths remain unchanged.

The independent `ARTIST_RECORD_PUBLICATION_READ_GAS` parameter starts at 400,000
with floor 150,000 and failure class 2. These are planning bounds until measured
with the actual schema/byte host, maximum payload and cold dependencies. The
metadata host's outer artist-read budget must cover this inner cap, EIP-150 and
the full composed read. Equal outer and inner caps cannot establish sufficient
gas. The first owner tests use an explicit candidate-host boundary; they do not
prove the current canonical metadata writer or all metadata-family authorities.
