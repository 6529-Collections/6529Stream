# Archival semantic exports

The archival exporter builds a bounded, offline semantic manifest from a
replayed [typed-account authority package](museum-typed-authority-profile.md).
The separate publication helper records that manifest as
`ARCHIVE_SEMANTIC_EXPORT` through the current Metadata host's ARCHIVE family.
Recording an export preserves the archivist's derivation and commitments. It
does not transfer authorship of the source claims to that archivist.

## Compact immutable successor

`STREAM_SEMANTIC_EXPORT_V3` supersedes the V2 export schema. V1 and V2 remain
byte-identical. The existing schemas inline full source/reviewer selectors and
resource references; the retained media example has 25 selected assertions and
cannot fit that representation within the current host's 8,192-byte payload
limit.

V3 retains the original source-state, component, completeness and conformance
fields. It replaces the inline selector arrays with `authoritySelection` and
the resource array with `resourceIndex`, each an exact child document reference.
It also commits `exportPolicy`, the separately registered
`STREAM_MUSEUM_ARCHIVAL_EXPORT_PROFILE_V1` interpretation document. The schema
and policy are generated under
[`schemas/museum/archival-export`](../schemas/museum/archival-export/).

The selection document retains the original base selection, authority selection
and entity plan separately. Its JCS hash is `selectionPolicyHash`. This preserves
their exact selectors and distinct review/conflict rules. The resource index
commits each emitted resource and its offline JSON-LD expansion. No source
selector or resource commitment is discarded to meet the carrier limit.

## Source scope and representation

The exporter first reconstructs the source block, registered interpretation and
historical independent-account records. It requires explicit public disclosure
and a single captured subject and record lane. All embedded inputs, sidecars,
snapshots, reports and dependencies are covered by that scope. Mixed subjects,
empty lanes and restricted disclosure are rejected.

Collection exports have `tokenId: null` and an empty `canonicalCitation`, with
their exact canonical collection subject retained. They do not invent a token
or a work citation. A token export keeps the original chain/Core/token identity
and uses the captured chain head as its typed citation qualifier. The finality
qualifier remains `unfinalized_trusted_rpc_block`: this adapter supplies neither
consensus proof nor a finality record.

The entity index explicitly distinguishes:

- `linked_art`: one bounded resource per unchanged entity IRI;
- `stream_extension`: the exact typed entry in the assertion sidecar; and
- `external`: an explicit reference without a locally authored resource.

Base resources retain their source text and ordering. Only admitted authority
equivalence values are added, in deterministic order. Authority-only entities
retain their emitted declaration and continuation lineage in provenance.
Superseded or non-emitting mappings cannot create a new identity conflict.
Resource filenames derive from the original IRI; export-run identifiers and
timestamps are absent from those resources.

The assertion sidecar retains the original public records, selected and withheld
claims, extension facts, and authority alternatives. Snapshot bytes and their
attribution stay separate from source authenticity. The retained typed-account
example uses an explicitly synthetic RDF/JSON snapshot, even though its local
Safe records and later SELF review are real. Its separately retained Getty
response is not the reconciled snapshot.

## Hash graph and offline verification

The semantic manifest commits its source state and child documents. The outer
package manifest commits the semantic manifest and every original input file.
The subsequent archive record is separate publication evidence and is never
inserted into its own source capture. This version accepts only a first export
with `previousExport: null`; later export lineage needs a separately implemented
bounded replay policy.

New JSON is canonicalized with the registered RFC 8785 JCS definition and fixed
Keccak256 payload hashes. Retained input bytes keep their original interpretation
and are committed without rewriting. JSON-LD expansion uses the pinned offline
context/model closure. These byte checks make no RDF canonicalization claim.

```powershell
.\.venv-museum\Scripts\python.exe -m tools.museum.semantic_export definitions --check
.\.venv-museum\Scripts\python.exe -m tools.museum.semantic_export build AUTHORITY_PACKAGE EXPORT_PACKAGE --manifest-hash AUTHORITY_MANIFEST_HASH --disclosure public
.\.venv-museum\Scripts\python.exe -m tools.museum.semantic_export verify EXPORT_PACKAGE --manifest-hash EXPORT_MANIFEST_HASH
```

The common `tools.museum.package_v2` verifier also dispatches this package mode.
Verification rebuilds every derived file from the original retained source
package. Rehashing a modified manifest or resource does not bypass that replay.

## ARCHIVE publication

`tools.museum.archive_publication` uses `StreamCollectionMetadataV1` and the
governed `ARCHIVE_SEMANTIC_EXPORT` admission. Its mask permits only class 6
(`PRESERVATION_ADMIN`) and class 8 (`GLOBAL_ADMIN`). The writer needs the exact
family grant. Publication uses `recordCollectionRecordWithPayload`, retaining
the complete manifest with the registered schema and JCS definition.

The helper checks the pinned source block and subject, exact registered
definitions, governance policy/grant, record hash, original payload, event,
receipt, append-only index and chain head. Publication must follow the source
block. Neither `publishCollectionSnapshot` nor independent-attestor publication
is an alternative archival authority route.

## Retained local publication

The 16 September 2026 capture uses the previously SHA-256-pinned 114-product
native manifest and official Safe fixture. It performs actual governed type
admission, grants an ARCHIVE writer class 6, registers V3 with V2 as its
predecessor, and publishes a 5,043-byte manifest on the selected current
Metadata host. The URI is empty, as supported by that host; no retrieval
location or archival redundancy is claimed.

Source block 851 precedes publication block 854. Four retained headers bind
their parent hashes, heights and strictly increasing timestamps. The original
receipt and event join the publication block's transaction hash/index. The
stored receipt, record/chain preimages, payload-pointer bytes, registered
schema/policy bytes and predecessor/chunk commitments all verify offline.
These are consistency checks on externally pinned trusted-RPC evidence, not
receipt-trie or consensus proofs.

The [fixture manifest](../schemas/museum/archival-export/local-fixture/manifest.json)
pins the compressed original inputs. It rebuilds the base, authority and export
packages without a node or network and verifies the separate archive evidence.
The new archive record is absent from the 15-record source inventory.

- Export package manifest:
  `0x66a5d3a1acc1a8f3f38355091759a45516c63f426379ee2a7f1778e83f2f2749`
- Semantic payload hash:
  `0x2fec7ad91116268cf012ac89fe8f4ca6f99679a13bd26d7f1f75a5bf93ce71cc`
- Archive record:
  `0x57344bd2d0b1d4dd07ab591a5b0f2bedd7ae690bc12be974ebcdbf75c9d4a3b0`

```powershell
.\.venv-museum\Scripts\python.exe -m tools.museum.archive_fixture verify schemas/museum/archival-export/local-fixture --manifest-hash 0x92d26a64ba30e5b5827a323668e29a2f76264b286b8068615334b48781c2e518
```

The reusable `tools.museum.current_archive_capture` runner takes
`--native-manifest`, `--native-manifest-sha256`, a new `--output` directory and
`--disclosure public`. It starts and terminates only its own isolated Anvil
process. It does not rebuild native artifacts or change shared services. Native
evidence remains pinned to that manifest, not the latest entire integration
graph. The authority snapshot remains explicitly synthetic; the archive writer
does not authenticate its publisher or establish a qualified human reviewer.

## Acceptance boundaries

The package reports `completeness: incomplete`, Stream-profile conformance
`not_evaluated`, emitted Linked Art model validation `pass`, and API conformance
`not_claimed`. This is a working bounded export mechanism, not full adopted
Museum-profile acceptance. It does not establish qualified human identity,
publisher authentication, institutional ingest, archival redundancy, or a
public deployment.

BagIt/OCFL object-dossier integration, media embedding/fetch policy, complete
typed institutional joins, mixed scopes/lanes, subsequent-export lineage and
full Museum conformance remain separate acceptance work. The original
[packaging tools](museum-bagit-ocfl.md) keep their own profiles and claims.
