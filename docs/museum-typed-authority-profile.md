# Typed museum authority profile V2

This version adds a recorded `Type` entity, including Getty AAT alignments,
and exact declaration reuse to the bounded independent-account museum profile.
It preserves every V1 schema and profile byte. It does not establish a named
human, qualified reviewer, artist, curator or institution.

## Immutable versions and retained interpretation

`tools.museum.typed_authority_profile.TypedAuthorityProfile` introduces:

- `STREAM_MUSEUM_SEMANTIC_PROFILE_V2`
- `STREAM_SEMANTIC_ASSERTION_V2`
- `STREAM_SEMANTIC_EXPORT_V2`
- `STREAM_MUSEUM_INDEPENDENT_ACCOUNT_PROFILE_V2`
- `STREAM_MUSEUM_AUTHORITY_ALIGNMENT_BODY_V2`
- `STREAM_MUSEUM_AUTHORITY_RECONCILIATION_V2`

The separate V2 policy, crosswalk and dependency index are interpretation
documents. The registry predecessor map is committed in that index and checked
against each captured document's `supersedesId`. Earlier documents are retained
and registered before their successors. Registration is checked against each
capture; generating prospective files does not register them.

The V2 profile retains the exact pinned Linked Art context, model validation
schemas and vocabulary source bytes as registry dependency documents. Its index
records their original URIs, revisions, retrieval dates, media types, dependency
edges and content commitments. Every document uses the existing chunk store and
registry, with no external lookup during replay. Raw upstream bytes use
`RAW_BYTES`; generated canonical JSON uses the registered `RFC8785_JCS`.

Preflight enforces 512 documents, 4,096 chunks, 16 MiB aggregate bytes and the
registry's per-document limit of 64 chunks of 8,192 bytes. The pinned dependency
loader also checks dependency depth and cycles. Selected account payloads retain
the narrower existing 8,192-byte tool bound.

V1 records retain their original schema, profile and review commitments in a
mixed V2 source. A V1 review is checked against its original assertion's V1
profile hash. **New V2 authority mappings must originate in a V2 assertion
record.** Placing a V2 literal in a V1 record does not confer V2 interpretation.
Old packages continue to replay under their original hashes and definitions.

## Declaration references and continuation

Every V2 alignment body chooses one declaration reference:

- `same_record`: an exact `/entities/N` pointer in the original assertion
  record, avoiding a circular reference to that record's own hash; or
- `prior_record`: a complete earlier record selector and the canonical hash
  of the exact declaration, also explicitly cited in the assertion payload's
  `sourceRecords`.

The declaration must have the same identity, kind and declaring account as the
alignment's subject, requested kind and authenticated asserting account. An
earlier V1 declaration may be referenced without changing its original meaning.

Every V2 entity also has `continuation`, either `null` for an original declaration
or an exact predecessor selector, declaration hash and nonempty rationale.
Continuation preserves identity, kind and account. Each predecessor must occur
earlier in authenticated publication order and appear in the entity's
`sourceRecords`. At most eight links are admitted. This is an ordinary
same-identity continuation, not an entity merge or split.

An alignment attached to an existing dossier must reference its exact selected
declaration or an explicitly validated continuation of it. An external reference
cannot become a local identity through redeclaration. Competing selected
continuation branches withhold equivalence; an unselected branch has no veto.
Every admitted declaration and its full validated lineage remains in the sidecar
and emitted-claim provenance.

## Selection and reconciliation

The V2 package entrypoints are in `tools.museum.authority_package_v2`. Their
arguments match the [original authority package](museum-authority-reconciliation.md)
but require the V2 reconciliation profile hash and a source package whose typed
profile registration replays successfully.

The existing reviewed/unreviewed, ambiguity, weaker-match, snapshot-integrity,
type, focus and deprecation rules remain. Only a later explicitly selected
same-account `SELF` review qualifies a mapped assertion. A named or independent
human reviewer is not inferred from that review. Drafts cannot emit equivalence.

```powershell
.\.venv-museum\Scripts\python.exe -m tools.museum.typed_authority_profile --check
.\.venv-museum\Scripts\python.exe -m tools.museum.authority_v2 --check
.\.venv-museum\Scripts\python.exe -m tools.museum.authority_package_v2 verify PACKAGE --manifest-hash HASH
```

## Current-stack capture

`tools.museum.current_authority_capture` uses the existing isolated Anvil runner,
SHA-256-pinned native artifacts and official Safe fixture. It registers the
typed closure and publishes separate original documentary, Type declaration,
alignment and later SELF-review records through the real attestation contract.
The alignment references the earlier declaration rather than redeclaring it.
The output retains source and publication transcripts, exact registration bytes,
authority inputs, selection policies and reconstructed packages.

Snapshot provenance is independent of record authenticity. Without explicitly
supplied compatible bytes, the capture uses a labeled synthetic RDF/JSON
snapshot. A real Safe publication of that snapshot's alignment proves the
local account workflow; it does not turn synthetic facts into Getty evidence.
An incompatible publisher response may be retained separately and must never
be presented as the snapshot used by the reconciler.

The runner uses only its own ephemeral Anvil process and an unused local port.
It does not modify another node, use a production signer, or publish to a public
chain. Native artifacts prove their pinned source/build, not the latest entire
integration graph.

### Retained positive from 16 September 2026

The checked-in
[fixture manifest](../schemas/museum/typed-account-profile/local-fixture/manifest.json)
pins a compressed bundle of 23 exact original input files. Replay reconstructs
the original base package and V2 authority package without a running node or a
network connection. It verifies 15 original source records, the 42-document
typed interpretation set and its registry predecessors, the prior Type
declaration, the automated alignment and its later selected Safe SELF review.
The original and reconstructed authority manifests match:
`0x4ac6c959e4e98c3f9fb90691022049ec534edc247125a1b89daa59caf015c383`.

```powershell
.\.venv-museum\Scripts\python.exe -m tools.museum.typed_authority_fixture verify schemas/museum/typed-account-profile/local-fixture --manifest-hash 0x2fe792608f9c37fe9615d9a54a555c4af9dc8fe30c65b60d98f3200fc22bf343
```

The native artifact manifest is retained inside the bundle. The runtime run
verified all 19 artifact hashes and the official Safe fixture before deployment.
The reusable capture command accepts that pinned native manifest with
`--native-manifest`, `--native-manifest-sha256`, `--output` and
`--disclosure public`. It does not rebuild contracts.

This positive uses the explicitly synthetic RDF/JSON snapshot. The exact
542,200-byte Getty response is retained separately as SPARQL-results JSON and
was not passed to the RDF/JSON reconciler. Omitting the actual selected review
from the same retained records yields an unresolved result with no equivalence.
Declaration continuation has focused positive/negative unit coverage; this
native capture demonstrates later reference to an unchanged earlier declaration.

The [V2 requirement map](../schemas/museum/authority-v2/coverage.json) separates
these completed mechanisms from remaining adopted-profile acceptance.

## Remaining acceptance

This completes a bounded typed-account interpretation and reconciliation path.
The new export schema allocation does not implement the full semantic archival
export lifecycle. Qualified external review, artist/curator/institution lanes,
full adopted crosswalk coverage, independent institutional ingests and public
testnet acceptance remain separate requirements. The actual source and snapshot
classification must accompany every retained positive.
