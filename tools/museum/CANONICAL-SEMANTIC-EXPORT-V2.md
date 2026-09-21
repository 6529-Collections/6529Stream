# Complete owner-family semantic export

V2 interprets all ten named token-owner families from the complete owner
catalogue retained by a [canonical object dossier V3](CANONICAL-COMPOSITION-V10.md).
It also keeps WORK, condition and the separately verified conservation family.
The [V1 export](CANONICAL-SEMANTIC-EXPORT-V1.md) and its profiles remain unchanged.

Every retained owner row enters the inventory before selection. Empty lanes,
per-author latest observations, unknown admitted types, unsupported schemas and
historical alternatives remain visible. Completeness is scoped to the captured
host and provider-admitted catalogue; it does not establish all historical hosts
or independently discover an omitted empty admitted type.

## Exact family coverage

| Native family | Exact schema | Interpretation boundary |
| --- | --- | --- |
| ACCESSION | STREAM_ACCESSION_V1 | Accession identifier, declared acquiring institution and documentary title binding. |
| DEACCESSION | STREAM_DEACCESSION_V1 | Declared disposition/reason and documentary title binding. |
| CONDITION_REPORT | STREAM_CONDITION_REPORT_V1 | Attributed condition examination, observations and references. |
| EXHIBITION | STREAM_EXHIBITION_V1 | Declared exhibition events, roles, venues, dates and status. |
| LOAN | STREAM_LOAN_V1 | Declared parties, loan terms, dates, status and evidence references. |
| CITATION | STREAM_CITATION_RECORD_V1 | Exact state-qualified cited work, citing reference and context. |
| VALUATION | STREAM_VALUATION_V1 | Effective date, basis, instrument commitment and confidentiality. No financial figure is inferred. |
| STEWARD_DESIGNATION | STREAM_STEWARD_DESIGNATION_V1 | Declared notice stewardship. A typed statement alone does not establish an operative native designation. |
| RECOVERY_RESPONSE | STREAM_RECOVERY_RESPONSE_V1 | Declared recovery response, grounds and evidence. Processing, timing and effect need separate native evidence. |
| REDEMPTION_CLAIM | STREAM_REDEMPTION_CLAIM_V1 | Program, entitlement and fulfillment reference. Lane-local first-claim qualification remains separate from fulfillment. |

`TITLE_BINDING` is the embedded `titleBinding` of ACCESSION/DEACCESSION; it is
not an eleventh record type. Its instrument, custodian and ERC721 Transfer
reference retain distinct meanings. A matching observed token transfer does
not establish legal title, physical custody or institutional acceptance.

The exact frozen [51-definition plan](GENESIS-REGISTRY-COVERAGE-V1.md) supplies
interpretation bytes. Admission compares each original receipt's schema and
canonicalization definition hashes with those bytes. The plan contains 29
canonical schema documents and 22 supporting documents. Its prospective
registration declarations remain unchanged; this export does not perform a new
Registry capture or infer live registration. The new adapter and export profiles
are prospective and unregistered.

Named interpretation requires the exact record type, schema, definition
commitments, supported embedded payload hash, canonical JSON, complete schema
validation and family-specific semantic checks. Subject fields must agree with
the dossier's chain, Core, collection and token where the schema expresses
them. Unknown encodings and invalid semantic payloads remain opaque originals;
they cannot be selected as interpreted statements. Corrupt source commitments
are rejected by replay before semantic interpretation.

Embedded Keccak-256 and SHA-256 payloads are supported. Native payload hash
algorithms 3–6 and URI-only payload commitments remain opaque. This does not
restrict the reference HashRefs allowed inside a supported schema: their exact
algorithm, digest, canonicalization and URI remain declared references, without
retrieval or invented byte verification.

## Attribution, selection and unresolved state

Each interpreted family retains exact field occurrences, source pointers,
subject and native receipt attribution. Party names, identity references,
dates, instruments and relationship roles remain declarations by the original
owner. They do not establish people or institutions, actual examinations,
performed exhibitions, legal agreements, custody, title or financial facts.

The default selection preserves existing native WORK, explicit original
accession and receipt-ordered condition selections. Other owner-family rows
remain historical unless explicitly selected for review. Per-author latest
records and effective dates do not replace native selection evidence. Explicit
historical selection cannot change the authority or currentness of a row.
Foreign WORK and condition subjects remain inventoried and unselectable.

Steward and recovery payloads do not establish specialized native transitions.
In particular, a generic same-family record with a different admitted schema
does not replace a typed designation, and a recovery response does not prove
that an action is scheduled, processed, counted, vetoed or executed.

Redemption qualification examines the entire captured family lane in native
record-index order. An earlier opaque row can conceal the same program and
leaves a later claim's primacy unresolved. The result remains local to the
captured host and does not prove delivery, burn, transfer or exactly-once
execution. Opaque history is never silently skipped to declare a later claim
operative.

## Prepare, build and verify

Use the existing Museum Python environment and new output directories with
existing parents. Both source and export must be explicitly public.

```powershell
python -m tools.museum.canonical_semantic_export_v2 prepare-selection `
  --dossier DOSSIER --dossier-hash DOSSIER_HASH `
  --disclosure public --output POLICY
python -m tools.museum.canonical_semantic_export_v2 build `
  --dossier DOSSIER --dossier-hash DOSSIER_HASH `
  --selection POLICY/selection.json --selection-hash SELECTION_HASH `
  --disclosure public --output EXPORT
python -m tools.museum.canonical_semantic_export_v2 verify EXPORT `
  --manifest-hash EXPORT_HASH
```

Creation uses the frozen definition plan by default. To supply its retained
package explicitly, add both `--owner-definitions PLAN` and
`--owner-definitions-hash PLAN_HASH` to prepare-selection and build. The Python
API accepts the equivalent `plan_files` and `plan_hash` pair.

For an explicit historical family selection, use the admitted occurrence IDs:

```python
from tools.museum import canonical_semantic_sources_v2 as sources
from tools.museum import canonical_semantic_projection_v2 as projection

checked, inventory = sources.admit(dossier_files, dossier_hash)
loan_ids = [row["occurrenceId"] for row in inventory["rows"]
            if row["family"] == "LOAN"
            and row["interpretation"]["status"] == "interpreted"]
selection = projection.historical_selection(inventory, loan_ids)
```

Pass the returned selection bytes and their Keccak hash to `build`. This
selection must be nonempty; inspect opaque dispositions when no usable record
exists. Selecting a historical statement does not make it current.

Verification uses the plan below `definitions/owner-genesis-plan/` and the
retained Linked Art model closure. It replays V3, rebuilds the complete source
inventory and family meanings, reapplies the pinned selection, expands the
selected resources and compares every output byte. No network or external URI
retrieval is needed. Rehashing a changed schema, field mapping, authority,
selection, report or source pointer does not bypass reconstruction.

The original V3 stays byte-for-byte under `input/`. The original 19 packet
groups and all 49 dossier assessments remain unchanged, including unresolved
institutional and source-evidence requirements. Children commit only to earlier
inputs and other children, never to their enclosing manifest. Structural model
validation and exact offline reconstruction do not establish full Museum
conformance, an audit, production readiness or institutional acceptance.

## Focused verification

The new cohort exercises every named family, opaque/future alternatives,
definition and subject mismatches, semantic contradictions, complete lane
analysis, field provenance, selection and retained-definition reconstruction:

```powershell
python -m unittest tools.museum.test_owner_family_semantics_v1 `
  tools.museum.test_canonical_semantic_sources_v2 `
  tools.museum.test_canonical_semantic_projection_v2 `
  tools.museum.test_canonical_semantic_export_v2 -v
```

The integration fixture uses synthetic native RPC transcripts replayed through
the concrete owner, ownership, acquisition and dossier readers. It provides
offline integration evidence; actual-chain capture and institutional review
remain separate acceptance work.
