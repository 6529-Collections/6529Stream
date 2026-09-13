# ADR 0042: Explicit current rights-record selection

Status: Accepted implementation design, 12 September 2026. Current selection
is being integrated under [ADR 0041](0041-typed-finality-evidence-provider.md);
complete scope/provider/snapshot/Finality acceptance remains open.

## Authority and ownership

`StreamCollectionMetadataV1` retains every original record and receipt. Its
latest-for-recorder getter is an author's dossier index; it is not a cross-author
current-rights decision. The fixed `StreamRightsRecordSelection` auxiliary owns
that decision without adding a Core role or another grant registry. The finality
provider must bind its exact deployment and runtime identity.

The auxiliary binds one Core, metadata host, schema registry and byte store.
Their original metadata runtime pins and reciprocal addresses are checked.
New selection and consuming operations require the currently selected Core
metadata pointer. Dependency reads use the metadata host's existing governed
`METADATA_DEPENDENCY_READ_GAS` parameter. Full definition bytes are reconstructed
from individually bounded Store reads, avoiding nested aggregate read budgets.
The Core pointer's status word is its stored installation status. This read does
not establish live ModuleRegistry eligibility after retirement or incident
changes; that separate join remains part of actual provider/candidate admission.

Selection uses exactly the metadata host's RIGHTS-family grants. Class 7 is
checked before class 8; within each class the collection grant precedes scope
zero. The admitted record policy must permit that class. The chosen selector,
class, grant scope and grant revision are saved. A SNAPSHOT or other-family
grant cannot select rights. The original record's recorder and authority class
remain distinct from the later selector.

## Exact meaning and history

The selected original must be a `RIGHTS_STATEMENT` under `STREAM_RIGHTS_V1`,
with an original class-7/8 receipt and zero embedded signature/artist backlink.
Its complete fourteen-word record hash uses the original metadata host address.
The receipt's collection and actual `recordHashAt` membership authenticate its
subject through that host's existing admission rules.

The complete semantic schema, separate `STREAM_RIGHTS_JSON_PROFILE_V1` profile
and shared `RFC8785_JCS` definition must be registered, active and byte-exact.
All three definitions declare `RAW_BYTES` for their own retained bytes. Their
identities, kinds, immutable declaration, ordered chunks, lengths and hashes
are checked. The semantic schema exceeds one 8192-byte chunk. The original
record receipt must name the same schema and canonicalization definition
hashes, and its typed witness must reproduce every stored payload byte.

An artist licensor reference proves a known immutable identity registration
through the actual metadata artist facade, its Coordinator and Identity owner.
It does not require current active status, signer equality or equality with
the collection artist. The registration hash is retained with the selection.
Other licensor identities, dates, grants and legal instruments remain explicit
notices and commitments; they do not prove legal ownership or preservation.

The first selection requires an explicit predecessor-zero record. The current
RIGHTS authority may choose that valid original even if a later generic append
exists in its recorder's dossier. Subsequent selections require the exact old
selected hash and revision, the payload's predecessor equal to that selected
hash, and a strictly greater original record index in the same collection/type
lane. Competing successors cannot consume the same selected revision. An
unselected or malformed generic append cannot silently replace or veto a head.

Selection revision is a separate monotonically increasing `uint64`; the rights
JSON's literal version 1 is not a revision. Every selection remains addressable.
Its commitment is `keccak256(abi.encode(keccak256("6529STREAM_RIGHTS_SELECTION_V1"),
deploymentChainId, selectionAuxiliary, core, metadata, schemaRegistry, chunkStore,
collectionId, subjectId, selection))`, with the tuple's `selectionHash` field
zero during hashing. The final provider/snapshot reference must bind the exact
record, revision and selection hash.

Later publisher/selector grant revocation does not erase the selected evidence.
Raw current/history getters remain readable after definition retirement or
pointer changes. `requireCurrent` applies current dependency/active-definition
eligibility for new consumption. Historical finality verification must retain
its original evidence rather than rerunning today's eligibility.

## Scope and remaining composition

The current generic host admits collection and registered minted/burned token
subjects. These have separate selected heads. Token variance supplements the
collection record and does not remove the finality scope's own rights-record
requirement; consumers must preserve both for per-use-class precedence.
RELEASE, SEASON and VIEW subject admission, complete provider/snapshot binding,
instrument coverage and finality execution remain required full-v1 work.
