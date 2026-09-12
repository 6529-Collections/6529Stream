# Museum offline tooling

Run from the repository root with Python 3.11 or later. Dependencies are pinned
in `requirements.txt`; the development host already provides those versions.

```text
python -m tools.museum.schemas --check
python -m tools.museum.fixtures --check
python -m unittest tools.museum.test_foundation tools.museum.test_publication -v
python -m tools.museum export-fixture --schema schemas/museum/fixtures/source.schema.json --source schemas/museum/fixtures/photograph.json --output <empty-output-directory>
python -m tools.museum verify-fixture <output-directory>
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
and recorded-source obligation. The current capture is the exact published
Linked Art context, equal to its pinned upstream Git blob. It is only the
context closure; the complete CRM/Linked Art ontology, validation, crosswalk and
classification closure is still required before profile registration.

`python -m tools.museum.publication <local-file> --name <exact-versioned-name>
--kind DEPENDENCY --canonicalization-id <exact-definition-id>` prints prospective
`DocumentSpec` metadata and ordered keccak chunk hashes. The selected native
registry boundary allows 64 chunks of 8,192 bytes, or 524,288 bytes per logical
document. This differs from the separate offline aggregate limits. It retains
original bytes and whole-document hashes, including the 434,213-byte CRM
document's 54-chunk shape. It never uploads or registers, and does not establish
the referenced canonicalization definition's actual admission or correctness.
Permissionless chunk upload alone would not establish registered inventory.

The first cohort failed because the inventory rejected scalar `enum`/`const`
schemas used by the fixture source. After that correction, independent review
of the preserved 24-test checkpoint found omitted selector fields, review reuse
across identical-byte revisions and identity selection depending on arrival order.
The follow-up binds full selectors/revisions, admits declaration agents and
rejects ambiguous reuse. It also rejects nonfinite/invalid Unicode/deep JSON-LD
while preserving legitimate context numbers. No earlier result is represented as
full museum conformance. Original fixture scenario meanings remain unchanged.
