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
.\.venv-tools\museum\Scripts\python.exe -m unittest tools.museum.test_foundation tools.museum.test_publication tools.museum.test_vocabulary tools.museum.test_linked_art -v
```

On Linux or macOS:

```sh
python3 -m venv .venv-tools/museum
.venv-tools/museum/bin/python -m pip install -r tools/museum/requirements-jsonld.txt
.venv-tools/museum/bin/python -m unittest tools.museum.test_foundation tools.museum.test_publication tools.museum.test_vocabulary tools.museum.test_linked_art -v
```

Use that environment's Python for the following commands. Dependency installation
needs package-index access; verification itself uses only retained local bytes.

```text
python -m tools.museum.schemas --check
python -m tools.museum.fixtures --check
python -m tools.museum export-fixture --schema schemas/museum/fixtures/source.schema.json --source schemas/museum/fixtures/photograph.json --output <empty-output-directory>
python -m tools.museum verify-fixture <output-directory>
python -m tools.museum.linked_art schemas/museum/linked-art/examples/digital.json --policy-hash 0xb0fa483a5e25eda775095980c7b677c252568774b3d6b8944c6294cff3a1f54e
```

`schemas` and `fixtures` regenerate their deterministic files when `--check` is
omitted. No command downloads documents, sends a transaction, registers a schema,
or verifies an onchain source. The package command emits an explicit synthetic
fixture manifest, original source/schema bytes and complete source-path coverage.
It does not emit a fabricated `STREAM_SEMANTIC_EXPORT_V1` recorded-state payload.

The executable source interface separates immutable payload/schema bytes and
record selectors from fixture authority evidence. The only concrete adapter is
`FixtureSourceAdapter`. The future authenticated state adapter must establish
host, subject, schema, authority and lane completeness at one exact block. Root
owns that contract integration. A mode field or reviewer name is not evidence.

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

The initial source-schema inventory accepts closed objects, homogeneous arrays,
typed scalars, scalar enums/constants and nullable values. It records container
structure, absent optional fields, nulls, array indices/order and exact scalar
bytes. Unimplemented schema combinators and references fail before validation;
there is no remote schema loader. This limitation is an explicit implementation
backlog, not permission to omit a source family or reduce the coverage denominator.

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
