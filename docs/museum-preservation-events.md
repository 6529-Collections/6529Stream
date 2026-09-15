# Recorded preservation events and agents

The additive `STREAM_MUSEUM_RECORDED_PRESERVATION_EVENTS_V1` adapter exports
explicitly selected recorded preservation reports as PREMIS 3 events with
multiple file and agent links. It composes the unchanged
[recorded fixity profile](museum-recorded-fixity.md) and
[file-only profile](museum-recorded-premis.md). It uses their existing local XSD
dependencies; export and verification do not fetch, register schemas or broadcast.

This is a finite supplemental export profile. It does not claim to be the full
registered `STREAM_PREMIS_V3_PROFILE` or replace canonical
`PreservationObjectRef` and `PreservationRightsRef` implementations.

## Typed evidence

The exact prospective schema bytes and profile are retained under
[schemas/museum/preservation-events](../schemas/museum/preservation-events/profile.json).
A source must actually register those schema bytes and publish canonical JCS
payloads. Defining them in this repository does not register them onchain.

| Schema | Original publication family | Required facts |
| --- | --- | --- |
| STREAM_MUSEUM_PRESERVATION_EVENT_V1 | INDEPENDENT_PRESERVATION_EVENT | Original PreservationEventRef, ordered object IDs/file IRIs/roles, ordered complete agent refs and description selectors, exact report selector |
| STREAM_MUSEUM_PRESERVATION_REPORT_V1 | INDEPENDENT_PRESERVATION_EVENT | Matching event ID/type/outcome/time, explicit status, ordered object/agent IDs, detail, outcome detail, prior hash-bound result records |
| STREAM_MUSEUM_PREMIS_FIXITY_AGENT_V1 | INDEPENDENT_SEMANTIC_ASSERTION | Original agent ID, explicit name and person/organization/software type, software version where applicable |

Selectors identify complete original public records, including subject, family,
schema, account, host and publication position. The report precedes its event
and has the same original reporter and subject. Every result precedes the report
and has that same reporter and subject. Agent descriptions precede the event and
share its subject; their issuers may differ and remain explicit. The exact
report and description payload hashes must match the original event/agent refs.
Result records are retained opaque evidence, not instructions to execute a tool.

The report's object and agent ID arrays must match the event arrays exactly.
Each file IRI must exist in the selected file-only projection. Repeated event
IDs, conflicting object-ID-to-file mappings, conflicting named-agent identities
and duplicated links reject. Event roles can differ for the same unchanged agent.
Zero account values stay absent identifiers; no account, DID, name or timestamp
is invented. Limits are 128 selected events and 32 objects, agents and results
per generic event; original fixity observation bounds remain in force.

## Exported meanings

The adapter follows the labels in
[CMC-PREMIS-PROFILE](collection-metadata-contract.md#premis-data-dictionary-mapping-cmc-premis-profile).
Enum values are Keccak-256 of the exact uppercase Stream labels.

| Event kind | PREMIS eventType |
| --- | --- |
| INGEST | ingestion |
| FIXITY_CHECK | fixity check, through the unchanged typed fixity adapter only |
| REPLICATION | replication |
| MIGRATION | migration |
| NORMALIZATION | normalization |
| VALIDATION | validation |
| MEDIA_DERIVATION | creation |
| C2PA_VALIDATION | digital signature validation |
| SCHEMA_MIGRATION | metadata modification |
| RIGHTS_REVIEW | policy assignment |
| REDACTION | redaction |
| DEACCESSION_REFERENCE | deaccession |
| CONSERVATION_NOTE | conservation note, explicitly local |

Generic reports support `SUCCESS`, `WARNING`, `FAILED`, `INCONCLUSIVE`,
`SUPERSEDED` and `REDACTED`. The last three remain local outcome labels and
require nonempty `eventOutcomeDetail`; their exact original bytes32 values and
detail remain in the export. No unverified external vocabulary URI or equivalence
is asserted. The original fixity adapter keeps its narrower SHA-256,
SUCCESS/FAILED and exact observation-comparison rules. A generic FIXITY_CHECK
record cannot bypass those rules.

Only explicit `completed` generic reports become PREMIS events. Completion
requires at least one selected prior result record and a usable original
uint64 timestamp. `planned`, `cancelled` and `unknown` reports stay complete
source records with explicit per-event dispositions, but create no performed
PREMIS event. An unknown timestamp is never replaced with publication or export
time. Missing selected files, evidence or supported values produces an
unsupported diagnostic and no XML; requested records are never silently dropped.

| Source field | Export and retained correspondence |
| --- | --- |
| eventId, eventTime | Stable event URI and original UTC eventDateTime |
| eventType, outcome | Explicit mapped label; original values retained in event detail and provenance |
| eventURI, eventHash, schemaId | Complete original event ref in event detail and sourceReport evidence |
| object ID, file IRI, role | Original selected file identifier and linkingObjectRole; separate ID mapping retained |
| agent ID, account, DID, URI | Agent identifiers from explicit facts only |
| agentRole | Per-event linkingAgentRole with the original local bytes32 role URI |
| name, type, software version | Original selected agent description, separate from account authorship |
| report and results | Full report, exact record selectors/hashes and original authority retained |

Historical performance, time, agent identity, successful validation, C2PA
signatures, independent review and institutional acceptance remain reporter
claims. A RIGHTS_REVIEW event grants no rights. Current fixity comparison is
separate from these historical claims. The adapter neither creates a Linked Art
performed Activity from a planned report nor claims a complete activity crosswalk.

## Offline package

`recorded_account_preservation_resource_package`, version 1, retains an original
verified recorded v2 package literally under `source/`. It adds exact schema and
profile bytes, plan, observations, report, correspondence, provenance and,
when supported, `premis-preservation/premis.xml`. Existing synthetic, recorded,
file-only and performed-fixity modes retain their original bytes and meaning.
Derivative chains are rejected.

The canonical selection plan has these fields:

```json
{"mode":"recorded_account_preservation_events_projection","version":"1","sourceStateHash":"0x...","profileHash":"0x...","premisPlanHash":"0x...","preservationProfileHash":"0x...","events":[]}
```

Use exact external commitments and complete whole-record selectors from the
verified source. `events` may mix the new generic schema and the original
performed-fixity schema. An empty list produces an explicit unsupported result.
Optional observations contain only original fixity event IDs without `0x`, each
followed by `.bin`; generic reports never accept them as substitute evidence.

```text
python -m tools.museum.preservation_package build SOURCE_PACKAGE PLAN.json OUTPUT --source-manifest-hash HASH --plan-hash HASH --profile-hash HASH --disclosure public
python -m tools.museum.preservation_package verify OUTPUT --manifest-hash PRINTED_HASH
python -m tools.museum.package_v2 verify OUTPUT --manifest-hash PRINTED_HASH
python -m unittest tools.museum.test_preservation_events -v
```

Add `--observations DIRECTORY` when selected fixity records require local bytes.
Explicit public classification covers the retained source and observations;
restricted input refuses before output. Output directories must not exist.
Verification pins the external derivative manifest, replays the unchanged nested
recorded package, rebuilds the projection and compares every output byte. A
rehash of fabricated provenance does not pass reconstruction. Unsupported
packages remain verifiable statements of missing evidence.

## Validation boundary and next actual source

The positive event kinds/outcomes, multi-file/agent links and state controls are
explicitly synthetic typed source tests. The retained real account fixture
exercises missing-evidence diagnostics, literal package retention and CLI/offline
replay; it is not relabelled as a positive event capture. Existing fixity tests
also run unchanged. No new native compilation, capture or public registration
is part of this batch.

A later positive recorded example must publish real result bytes first, then a
registered report selecting them, then its event and original agent descriptions
in the required order, and capture the actual returned records. Report status,
method, outcome and original time must describe what actually happened. The
performed-fixity recipe additionally measures actual selected file bytes against
prior recorded expected facts. Canonical object/rights adapters, full registered
field/vocabulary crosswalk and institutional ingest remain separate implementation
or validation work.
