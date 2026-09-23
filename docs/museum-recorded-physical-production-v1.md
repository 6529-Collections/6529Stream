# Recorded physical-production statements

`tools.museum.recorded_physical_production_v1` adds an offline, qualified
`HumanMadeObject.produced_by -> Production` export from an explicit original
Artist statement. It concretely replays a complete
[native attribution dossier](museum-native-attribution.md), including the
original Metadata publication, historical Artist authorization, registered
semantic definitions, documentary evidence and exact source selection.

This implements a missing physical-production source join within the adopted
[MSM-RELATIONS](museum-semantic-mapping.md#8-relationships-evidence-and-authority-boundaries-msm-relations)
scope. It is a supplementary export profile, not a new onchain record schema or
registration. Existing source profiles and schema bytes remain unchanged.
Synthetic replay demonstrates the implemented mapping; it does not establish an
observed physical event, institutional acceptance or full Museum conformance.

## Existing source coverage and the remaining boundary

| Meaning | Existing authoritative source and consumer | Physical-event limit |
| --- | --- | --- |
| Physical object and content | Generic original `physical_object` declaration; `projection.py` and `projection_v2.py` map `HumanMadeObject`, `shows` and `carries`. | Generic events had no recorded Production mapping. This supplement adds the explicit join below. |
| Historical token ownership and title correspondence | `acquisition_accession.py` replays OwnerRecords and Core transfers; `native_title_v5.py` consumes original ACCESSION/DEACCESSION instrument references and exact prior transfers. | These instruments and transfer bindings are token-scoped. They do not identify completed physical custody or physical title events. |
| Accession, custodian and disposition statements | `owner_family_semantics_v1.py` and `canonical_semantic_projection_v2.py` retain separate original accession, title-instrument and custodian predicates. | A named custodian is not a physical `TransferOfCustody`; an accession identifier is not an `Acquisition`. |
| Loans and exhibitions | Existing original owner-family statements and their exact evidence. | No physical possession, ownership or legal effect follows from an exhibition or loan label. |

Physical custody, acquisition/title and museum accession remain separate
assertions or events. This supplement cannot construct them from the existing
token transfer bindings. It neither duplicates those adapters nor marks
MSM-RELATIONS5 complete. An actual authoritative source must identify the
physical subject, relevant event and instrument before such a join is possible.

## Original statement convention

The unchanged `STREAM_SEMANTIC_ASSERTION_V1` schema already carries generic
entity declarations, attributed assertions and evidence references. This export
interprets only a **selected direct Artist statement** with all of these exact
values:

| Original assertion field | Required value |
| --- | --- |
| `relation` | `urn:6529stream:museum:physical-production:v1` |
| `mappingRule` | `urn:6529stream:museum:physical-production:v1:original-artist-statement` |
| `subject` | The physical object's original entity IRI |
| `object.literal.datatype` | `urn:6529stream:museum:physical-production:v1:body` |
| `object.literal.language`, `unit`, `precision` | `null` |
| `object.literal.lexicalValue` | Exact JCS JSON for the closed body below, at most 16,384 UTF-8 bytes |

The body has exactly `version`, `kind`, `status`, `physicalObject` and
`productionEvent`. Version is `"1"`; kind is `"physical_production"`; status is
`planned`, `completed`, `cancelled` or `unknown`. Each declaration pin has exactly
`id`, `pointer` and `hash`:

- `id` is the original entity IRI.
- `pointer` is a canonical `/entities/N` path in the **same original payload**.
- `hash` is Keccak-256 of that exact entity's JCS bytes.

The two kinds must be `physical_object` and `event`, respectively, with distinct
IRIs. The native source checks their declaring account and prior documentary
source selectors. The enclosing original record supplies their full occurrence
identity, avoiding a circular self-reference to its own record hash. Duplicate
local declarations of one IRI reject; a different declaration cannot substitute
through a shared name or IRI.

Evidence stays in the original assertion's `evidence` and `sourceRecords` fields.
The existing native source checks each original hash, selector, prior publication
and retained bytes. No new export input can manufacture status, production
meaning, evidence or an instrument. An instrument's bytes do not establish its
legal validity. Other relations, rules or datatypes remain unsupported originals.
Malformed selected statements claiming this exact convention reject.

Collection and token anchor scopes remain explicit. A physical object is a
separate declared entity; neither anchor turns the token into that object.

## Projection and preservation

Only an eligible `completed` statement emits the original physical-object IRI
as `HumanMadeObject` and its original event IRI as `Production`, connected by
`produced_by`. The complete Production is embedded under its physical object;
the pinned model accepts that form but does not admit a standalone Production
root. The index retains the event's original IRI and exact `/produced_by` pointer.
Both entities carry the source qualification. Original preferred
names, or the first available name, supply descriptive labels. Other names and
languages remain in the original source.

Planned, cancelled and unknown statements remain sidecars without a Production
graph. Disputed, withdrawn and unselected assertions retain the original
selection disposition. Conflicting selected statuses or object/event bindings
are withheld together. Selected declarations from different occurrences cannot
merge through an IRI; this version does not implement declaration continuation.
Unselected assertions cannot veto a selected original.

Publication time, `createdAt` and `effectiveDate` do not become event time.
Historical signer and native `artistId` do not become a `Person`, `Group` or
`carried_out_by` relation. Later rotation or dispute remains a current
qualification; it does not rewrite historical authorization. The output does not
infer custody, legal title, museum accession, physical ownership or rights from
NFT activity, uploads, exhibitions, print-output roles or CC0 terms.

The package retains the entire original dossier under `sources/attribution/`,
the exact semantic selection, original statement fields, parsed literal bodies,
declaration pins, status/conflict reasons, per-leaf graph provenance and pinned
offline model dependencies. `source/locations.json` documents pointer bases.
`verify` replays the nested source and reconstructs every derived byte, including
JSON-LD expansion; recomputing the outer manifest cannot legitimize edited output.
The unchanged nineteen packet groups and forty-nine dossier assessments remain
outside this supplementary conformance claim.

## Commands

Use the existing Museum Python environment. Inputs must be explicitly public;
output directories must be new. No command fetches a URI or publishes a record.

```powershell
.\.venv-museum\Scripts\python.exe -m tools.museum.recorded_physical_production_v1 profiles

.\.venv-museum\Scripts\python.exe -m tools.museum.recorded_physical_production_v1 build `
  native-attribution-dossier physical-production-export `
  --source-hash $sourceManifestHash --disclosure public

.\.venv-museum\Scripts\python.exe -m tools.museum.recorded_physical_production_v1 verify `
  physical-production-export --manifest-hash $manifestHash

.\.venv-museum\Scripts\python.exe -m unittest tools.museum.test_recorded_physical_production_v1
```

The Python API is `build(source_files, source_hash, *, disclosure="public")`
and `verify(files, manifest_hash)`, both returning an `Assembly`. The complete
source dossier must contain its semantic capture and exact selection component.
The supplement preserves the source's `synthetic_fixture` or `trusted_rpc`
provenance; neither label proves consensus or authenticates the source operator.
