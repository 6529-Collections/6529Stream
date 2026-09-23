# Recorded PREMIS performed fixity checks

The additive `STREAM_MUSEUM_PREMIS_FIXITY_RECORDED_EXPORT_V1` profile exports
explicit recorded preservation events and agents beside the unchanged
[file-only PREMIS projection](museum-recorded-premis.md). It accepts a verified
`RecordedSemanticSource`, selected typed source records, and locally supplied
observation bytes. It never creates an event merely because a file has a digest.

This finite profile supports `FIXITY_CHECK`, SHA-256, and the `SUCCESS` and
`FAILED` outcomes. Other event kinds, algorithms and outcomes yield a precise
unsupported result. XML uses the original pinned PREMIS 3 XSD. No additional
Python dependency, network access, schema registration or capture runs during
export or verification.

## Recorded inputs

The three closed schema documents and the separate export profile are under
[schemas/museum/premis-fixity](../schemas/museum/premis-fixity/profile.json).
Schema names determine `schemaId`; they do not create new record families. The
actual original publication families are:

| Typed schema | Existing record family | Contents |
| --- | --- | --- |
| STREAM_MUSEUM_PREMIS_FIXITY_AGENT_V1 | INDEPENDENT_SEMANTIC_ASSERTION | Explicit agent ID, name, person/organization/software type, and software version |
| STREAM_MUSEUM_PREMIS_FIXITY_REPORT_V1 | INDEPENDENT_FIXITY | Performed-check claim, event/object/agent IDs, original check time, algorithm, expected and observed digests/sizes, outcome and detail |
| STREAM_MUSEUM_PREMIS_FIXITY_EVENT_V1 | INDEPENDENT_PRESERVATION_EVENT | Complete PreservationEventRef, PreservationAgentRef and FixityCheckRef, selected file IRI, exact prior report and agent-document selectors |

Each schema must actually be registered with its exact retained bytes. All
selected payloads require registered RFC 8785 JCS canonicalization. Selectors
must select whole records, including the original host, family, schema, subject,
account, index and chain commitment. The report and agent description precede
the event in authenticated publication order and share its subject. The event
and performed report have the same original reporter. An agent description may
have another recorded issuer; neither account is silently promoted to the named
preservation agent.

Enum-like bytes32 values are Keccak-256 of the exact UTF-8 labels `FIXITY_CHECK`,
`SHA256`, `SUCCESS` and `FAILED`. Agent roles retain their original bytes32 as a
local URI; the adapter does not guess a standard role or institution.

`event.eventHash` and `check.reportHash` must equal the exact report payload
hash. `agent.agentHash` equals the exact agent-description payload hash. The
report URI, event/check time, algorithm, IDs and outcomes must join without
coercion. `event.schemaId` identifies the report schema.

For this version, `FixityCheckRef.digest` and `byteSize` describe the recorded
observation. The report separately retains expected values. The expected pair
must equal the selected file-only PREMIS facts. The supplied bytes must equal
the observed size and SHA-256. A success requires equal expected/observed pairs;
a failure requires a difference. A failed check preserves the original expected
file fixity in the object and records the contrary observation in the event.

Event and agent identifiers use
`urn:6529stream:preservation:event:0x...` and
`urn:6529stream:preservation:agent:0x...`. The file IRI remains the original
selected DigitalObject identifier; its separately recorded bytes32 object ID is
retained in correspondence and full source evidence. Repeated checks need
separate event IDs, and selecting the same ID twice rejects. Conflicting agent
ref/description values under one selected agent ID also reject.

## Claims and missing evidence

The report distinguishes **current offline agreement with recorded observation
bytes** from a reporter's **historical performed-check claim**. A captured account
signature does not prove physical execution, the truth of the named agent, the
historical check time, independent review, detected format or institutional
acceptance. No current export timestamp, file mtime, reporter name or tool
version is inserted as historical metadata.

Original uint64 Unix seconds render in UTC. Values outside the supported XML
date range are retained in evidence with an unsupported result, never truncated.
Missing events, selected file facts or observation bytes produce diagnostics and
no XML. Malformed present records, broken links, differing bytes, duplicate IDs
and contradictory outcomes reject. The exporter does not omit a requested event
to make the rest of the package pass. The full selected record/report/agent
values and their original record authority are retained in provenance.

## Offline package and CLI

The derivative mode `recorded_account_fixity_resource_package`, version 1,
retains a verified recorded v2 package literally under `source/`, including its
original manifest and file-only XML. It adds the new profile, typed schemas,
plan, supplied observation bytes, report, correspondence, provenance and, when
supported, `premis-fixity/premis.xml`. The existing synthetic and recorded
package modes keep their original meanings and bytes. Derivative chains are
not supported by this profile.

The canonical plan has these exact fields:

```json
{"mode":"recorded_account_premis_fixity_projection","version":"1","sourceStateHash":"0x...","profileHash":"0x...","premisPlanHash":"0x...","fixityProfileHash":"0x...","events":[]}
```

Replace commitments with exact original values. `events` contains complete
whole-record selectors from the actual captured source. The empty list is an
explicit unsupported selection, not an instruction to invent or discover events.
Supply observations in a directory containing only lowercase event IDs without
`0x`, each followed by `.bin`. They are local bytes, never fetch instructions.
Explicit public classification covers both the original package and observations;
restricted export refuses before output.

```text
python -m tools.museum.fixity_package build SOURCE_PACKAGE FIXITY_PLAN.json OUTPUT --source-manifest-hash HASH --plan-hash HASH --profile-hash HASH --observations OBSERVATIONS --disclosure public
python -m tools.museum.package_v2 verify OUTPUT --manifest-hash PRINTED_HASH
python -m unittest tools.museum.test_recorded_fixity -v
```

Verification authenticates the external derivative manifest, replays the original
recorded package entirely offline, regenerates the typed projection, and compares
the complete output inventory and bytes. Rehashing a forged report or adding an
unselected observation does not bypass source reconstruction. Output directories
must not exist; missing evidence still produces a reviewable unsupported package.

## Validation and later actual capture

This increment includes positive and negative **synthetic typed controls** for
source joins and XML rendering, plus the real retained account capture for
missing-evidence and offline package replay. It does not promote those controls
to a recorded source. The earlier complete-media capture has declared file facts
but no performed-check report, so no positive historical check capture is claimed.

The smallest later current-stack recipe reuses the actual foundation/Safe/schema
capture. Prepare and read the real local test file before publication, retain
its earlier declared expected size/digest, and perform a SHA-256 comparison over
those bytes. Preserve the actual observation, check time and explicitly supplied
tool description in the closed report. Register the three schema documents,
publish the agent document and performed report, then publish the typed event
using their returned exact selectors and hashes. The existing capture helper's
publication method needs an explicit existing record-family parameter, and its
anchor must include all three relevant lanes. Anchor after publication and export
only the actual captured records. A mutated-file control should publish and
export a failed comparison. This is a later capture, not evidence delivered here.

Rights, other event families/outcomes, canonical PreservationObjectRef adapters,
full PREMIS crosswalk and institutional conformance remain separate scope.
