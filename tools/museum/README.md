# Museum offline tooling

Run from the repository root with Python 3.11 or later. Create an isolated
environment and install the Museum dependency set; the repository's general
tools lock alone does not include `rfc8785` or the JSON-LD processor. The full
set, including transitive dependencies and explicit URI/date-time validators,
is pinned in `requirements-jsonld.txt` (which includes `requirements.txt`).

On Windows PowerShell, no activation or execution-policy change is needed:

```powershell
python -m venv .venv-tools/museum
.\.venv-tools\museum\Scripts\python.exe -m pip install -r tools/museum/requirements-jsonld.txt
.\.venv-tools\museum\Scripts\python.exe -m unittest tools.museum.test_foundation tools.museum.test_publication tools.museum.test_vocabulary tools.museum.test_linked_art tools.museum.test_schema_inventory tools.museum.test_review tools.museum.test_semantic_selection tools.museum.test_projection tools.museum.test_package tools.museum.test_linked_art_v2 tools.museum.test_projection_v2 tools.museum.test_premis tools.museum.test_iiif_numbers tools.museum.test_iiif_uri tools.museum.test_iiif -v
```

On Linux or macOS:

```sh
python3 -m venv .venv-tools/museum
.venv-tools/museum/bin/python -m pip install -r tools/museum/requirements-jsonld.txt
.venv-tools/museum/bin/python -m unittest tools.museum.test_foundation tools.museum.test_publication tools.museum.test_vocabulary tools.museum.test_linked_art tools.museum.test_schema_inventory tools.museum.test_review tools.museum.test_semantic_selection tools.museum.test_projection tools.museum.test_package tools.museum.test_linked_art_v2 tools.museum.test_projection_v2 tools.museum.test_premis tools.museum.test_iiif_numbers tools.museum.test_iiif_uri tools.museum.test_iiif -v
```

Use that environment's Python for the following commands. Dependency installation
needs package-index access; verification itself uses only retained local bytes.

```text
python -m tools.museum.schemas --check
python -m tools.museum.fixtures --check
python -m tools.museum.review --check
python -m tools.museum export-fixture --schema schemas/museum/fixtures/source.schema.json --source schemas/museum/fixtures/photograph.json --output <empty-output-directory>
python -m tools.museum verify-fixture <output-directory>
python -m tools.museum.linked_art schemas/museum/linked-art/examples/digital.json --policy-hash 0xb0fa483a5e25eda775095980c7b677c252568774b3d6b8944c6294cff3a1f54e
```

`schemas` and `fixtures` regenerate their deterministic files when `--check` is
omitted. The commands above do not download documents, send a transaction,
register a schema or verify an onchain source. The package command emits an explicit synthetic
fixture manifest, original source/schema bytes and complete source-path coverage.
It does not emit a fabricated `STREAM_SEMANTIC_EXPORT_V1` recorded-state payload.

The executable source interface separates immutable payload/schema bytes and
record selectors from fixture authority evidence. `FixtureSourceAdapter` retains
that synthetic boundary. The additive [independent source capture](../../docs/museum-independent-source.md)
reads actual INDEPENDENT history at one externally anchored block, retaining
exact payload, signature, schema and pointer bytes with explicit trusted-RPC
provenance. Its local-EVM rehearsal is separate from the fixture projections and
packages above. Other authority lanes and semantic recorded-state composition
remain open. A mode field or reviewer name is not evidence.

The additive [publication-order capture](../../docs/museum-independent-publications.md)
joins those records to exact events, successful receipts and parent-linked block
headers. It preserves cross-lane publication order without inferring semantic
issuer identity. The guide includes the offline replay command and the separate
local rehearsal; no new Python dependency is needed.

The synthetic selection harness uses a separate review test wire
(`assertionSelector`, `assertionHash`, `disposition`) to exercise authenticated
input relationships. It is not the canonical family write payload. Every policy
selector field is compared to the immutable source tuple, including family,
schema, host, chain position and pointer; reviews additionally bind the exact
assertion selector, bytes, profile and rule. The canonical schema's review
reference carries `assertionRecord` plus `assertionRevisionHash` and its separate
`reviewRecord`. Root's record adapter must resolve those references using the
actual family authority rules before canonical records can use this mechanism.

Selected entity declarations require the source adapter's admitted agent.
Ambiguous reuse of one IRI by two selected declarations rejects even when kinds
match. An explicit compatible-reuse/continuation policy remains required before
that case is supported; arrival order never selects an owner or declaration.

The original fixture-package inventory accepts closed objects, homogeneous arrays,
typed scalars, scalar enums/constants and nullable values. It records container
structure, absent optional fields, nulls, array indices/order and exact scalar
bytes. Unimplemented schema combinators and references fail before validation in
that original package path. The additive `schema_inventory` engine supports exact
local references and applicable `allOf`/`oneOf`/`anyOf` branches, including the
three candidate Museum schemas. It requires independent schema/source/evaluation
hashes, validates the whole source first and emits every applicable branch and
coverage row. See [the inventory boundary and command](../../docs/museum-schema-inventory.md).
Both engines fail closed on unsupported constructs and have no remote schema
loader. Remaining profiles are an implementation backlog, not permission to omit
a source family or reduce its coverage denominator.

The additive [canonical review and selection layer](../../docs/museum-review-literal.md)
uses the actual assertion/backlink schema with a versioned review-literal body.
It binds exact selectors and revisions, derives self-review from fixture issuer
facts, and applies an explicit source/reviewer policy. Unselected reviews cannot
admit or veto a claim. Selected conflicting claims retain their provenance and
are withheld from unqualified projection. Actual chain/family authentication and
the complete resource package remain separate; `recorded_state` is rejected.

New Stream JSON values are a JCS-compatible restricted profile: protocol integers
and exact decimals use typed strings; floats are rejected. This restriction is
not a replacement definition of RFC 8785. An existing schema using JSON numbers
needs a separately faithful parser/adapter; its original bytes must not be
converted to this new representation. Raw upstream JSON-LD context bytes retain
their legitimate numeric `@version` and are not reserialized.

The dependency reader checks exact SHA-256 transport fixity, provenance,
deterministic 8,192-byte chunks, complete encoded candidate-carrier size,
acyclic bounded dependency edges, and local paths. Protocol `HashRef` numeric
algorithm/canonicalization catalog resolution remains a separate registration
and recorded-source obligation. Captures include the exact published Linked Art
context, three vocabulary documents and thirteen original Linked Art schemas.
Their pinned interpretation policies remain candidates. Complete selected-term,
crosswalk and classification closure is still required before profile registration.

`PinnedLinkedArt` performs actual offline expansion using PyLD 3.3.0, with a fresh
context cache for each operation and explicit URI/date-time validators. It first
checks shape using a pinned derived interpretation of the upstream schemas.
One legacy `items` syntax repair and two exact rights-reference repairs are documented in
[the validation boundary](../../docs/museum-linked-art-validation.md); original
schema bytes remain untouched. Shape and expansion do not establish source
authority or complete model semantics. The vocabulary checker separately tests
explicit class/domain/range relations under
[its pinned interpretation](../../docs/museum-vocabulary-interpretation.md).
These checks are exercised by focused tests; `export-fixture` still emits the
source/coverage diagnostic package, not a complete Linked Art museum export.
The `linked_art` command prints expanded data, original/derived hashes and an
explicit candidate/unregistered report. Its policy hash is a required caller
pin; changing the versioned interpretation requires changing that pin as well.
Every retained derived-schema reference must resolve locally at construction,
including unused definitions. The exact format profile rejects trailing
whitespace and does not support leap seconds; it never trims original values.

`python -m tools.museum.publication <local-file> --name <exact-versioned-name>
--kind DEPENDENCY --canonicalization-id <exact-definition-id>` prints prospective
`DocumentSpec` metadata and ordered keccak chunk hashes. The selected native
registry boundary allows 64 chunks of 8,192 bytes, or 524,288 bytes per logical
document. This differs from the separate offline aggregate limits. It retains
original bytes and whole-document hashes, including the 434,213-byte CRM
document's 54-chunk shape. It never uploads or registers, and does not establish
the referenced canonicalization definition's actual admission or correctness.
Permissionless chunk upload alone would not establish registered inventory.


The [resource projection](../../docs/museum-resource-projection.md) composes
canonical source/review selection with explicit entity declarations, source
coverage and pinned model validation. The [offline package guide](../../docs/museum-offline-resource-package.md)
provides exact example inputs and commands to build and verify a candidate
resource archive. Verification checks the external manifest hash, all copied
source/dependency bytes, and a complete recomputation of the projection. These
commands currently require wholly public synthetic fixtures; actual chain
admission and complete Museum/dossier conformance remain separate work.

```text
python -m tools.museum.projection --check
python -m unittest tools.museum.test_projection tools.museum.test_package tools.museum.test_linked_art_v2 tools.museum.test_projection_v2 tools.museum.test_premis tools.museum.test_iiif_numbers tools.museum.test_iiif_uri tools.museum.test_iiif -v
```

The separate [abstract/nonvisual v2 projection](../../docs/museum-abstract-nonvisual-projection.md)
adds explicit E89 and linguistic-content resources while retaining sound/software
E73 content and original technical relationships in the sidecar. It selects a
new crosswalk and fourteen-schema interpretation closure; the thirteen-schema
v1 policy and package CLI remain unchanged. No additional Python dependency is
needed. Check its definition with `python -m tools.museum.projection_v2 --check`.

The [PREMIS file/fixity increment](../../docs/museum-premis-file-projection.md)
adds a same-source XML projection and correspondence check using the already
pinned lxml validator. It retains the exact standalone LoC PREMIS 3 schema,
requires explicit selected file facts and does not claim a fixity check or
complete preservation export. Check its profile with
`python -m tools.museum.premis --check`.

The [IIIF Presentation 3 correspondence](../../docs/museum-iiif-correspondence.md)
adds one explicit four-media Manifest from the same selected Linked Art/PREMIS
source. Check its profile and complete offline context closure with
`python -m tools.museum.iiif_model --check`. It uses the existing pinned Python
dependencies. Exact target decimals use a separate encoder; Stream source
canonicalization stays unchanged. The visible named Sound supplement and
content-addressed media require a compatible resolver; no viewer, media
availability or chain-authentication claim follows from offline validation.

The [LIDO correspondence](../../docs/museum-lido-correspondence.md) adds an
explicit work/creation/creator description and the same media resources under
the original LIDO1.1 XSD and its complete pinned import closure. Check it with
`python -m tools.museum.lido_model --check`; no new dependencies are needed.
Exact source attribution, export-language assertions and final XML path evidence
remain separate from creator truth, chain authority and institutional acceptance.

The separate [recorded account projection](../../docs/museum-recorded-account.md)
checks actual registered schema/profile bytes and historical independent-account
authorship before entering the same finite v2 model. Run
`python -m tools.museum.account_profile --check` and
`python -m unittest tools.museum.test_recorded_account -v` for its pinned offline
example. Same-account SELF reviews are explicit and never establish independent
human review. The local-EVM example is distinct from public-chain acceptance;
existing synthetic packages and format commands keep their prior input boundary.


The additive [multi-format resource package](../../docs/museum-multiformat-package.md)
archives the same selected public fixture as Linked Art v2, PREMIS, IIIF and LIDO,
with complete local validation dependencies and per-format correspondence,
attribution and source-field coverage. Its verifier rebuilds all four formats
from only the archive and an external manifest hash. Run
`python -m tools.museum.package_v2 --help` for the build/verify CLI and
`python -m unittest tools.museum.test_package_v2 -v` for its focused checks.
Original v1 packages keep their existing boundary. The separate `build-recorded`
entrypoint packages the existing verified account capture, registered definitions
and Linked Art output without converting a synthetic source. It retains exact
transcript/deployment/captured-result bytes and requires explicit public input
classification; restricted exports reject before writing. An explicit
[recorded PREMIS plan](../../docs/museum-recorded-premis.md) now enables the
versioned selected-file adapter. Complete facts produce XML; missing facts
produce exact unsupported diagnostics. The separately pinned
[recorded IIIF adapter](../../docs/museum-recorded-iiif.md) consumes those file facts
and selected presentation evidence, or reports the exact missing inputs without a Manifest.
The [recorded LIDO adapter](../../docs/museum-recorded-lido.md) additionally requires
explicit work/creation facts and selected publisher statements from every
contributing account; account issuers stay separate from named legal bodies. `verify`
replays archived evidence offline. Run
`python -m unittest tools.museum.test_package_recorded -v` for this path. The
recorded package preserves the source environment and trusted-RPC limitations;
it does not claim institutional conformance.


The [actual current foundation capture](../../docs/museum-current-media-capture.md)
adds a positive recorded complete-media example using prebuilt native contracts,
real delayed governance and two-owner Safe calls on an owned loopback Anvil. It
retains the actual PNG and recorded facts, reconstructs all four formats offline,
and checks that missing publisher selection withholds LIDO only. It does not run
a Solidity compiler or claim whole-product deployment or institutional acceptance.

The additive [BagIt and OCFL transport](../../docs/museum-bagit-ocfl.md) packages
explicit public dossier/export inputs with exact payload/tag fixity and immutable
version history. It preserves nested v2 package evidence and qualifications.
Fetch-dependent bags remain incomplete until the separate
[offline hydration derivative](../../docs/museum-bagit-hydration.md) verifies the
complete locally supplied missing set against the original commitments. Original
fetch instructions remain inert provenance. Source authority, full render
inventory, genesis registration and institutional ingest stay separate.


The [recorded PREMIS performed-check profile](../../docs/museum-recorded-fixity.md)
adds explicitly selected typed event/report/agent records and local observation
comparison without changing file-only PREMIS meaning. Its distinct derivative
package retains the original recorded package literally and regenerates offline.
Historical execution, time and named-agent identity remain recorded claims.
Run `python -m unittest tools.museum.test_recorded_fixity -v` for focused checks.

The [recorded preservation event adapter](../../docs/museum-preservation-events.md)
adds twelve general event kinds, six reported outcomes and multi-file/agent links
beside the unchanged performed-fixity path. Explicit planned, cancelled and unknown
reports retain source evidence without becoming performed PREMIS events. Its
versioned offline derivative rebuilds the literal recorded source package and
all outputs. Run `python -m unittest tools.museum.test_preservation_events -v`;
positive typed controls remain distinct from actual recorded evidence.

The [canonical object and historical rights adapter](../../docs/museum-preservation-resources.md)
exports full PreservationObjectRef facts and exact STREAM_RIGHTS_V1 grants.
A separate pinned Metadata receipt reader preserves class-7/8 RIGHTS authority;
independent account links do not become grants. Canonical media subjects,
explicit properties/relationships and all six use classes remain source-backed.
Its offline derivative keeps both original evidence families and reports missing
facts without inventing a current rights selection or detected file format.
