# Recorded physical acquisition and custody statements

`tools.museum.recorded_physical_transfer_v1` exports qualified physical
`Acquisition` and `TransferOfCustody` activities from exact selected original
General statements. It first replays the complete
[General semantic dossier](museum-general-semantic-v1.md), including both native
source catalogues, registered interpretation definitions, source selection and
documentary evidence. No later export input can supply the event's meaning,
status, parties or instrument.

This is an additive consumer of the adopted
[MSM-RELATIONS](museum-semantic-mapping.md#8-relationships-evidence-and-authority-boundaries-msm-relations)
scope. It changes no contract, schema, native source profile, pinned model or
ownership rule. The export profile is prospective and unregistered. A qualified
recorded statement is not independent proof of physical performance or legal
effect.

## Source authority and separate facts

An institutional or estate General receipt retains its original account signer
authority. A curatorial receipt retains its actual recorder and historical
configured grant, separately from its unsigned asserted attester and DID. This
consumer preserves those distinctions and never treats them as proof of a named
institution's standing or an account's legal capacity.

The existing [token accession/title adapters](museum-acquisition-title-v5.md)
describe OwnerRecords instruments and their correspondence to Core token
transfers. They do not identify physical title or custody events. A custodian
name, accession identifier, loan, exhibition, CC0 term, uploaded file or NFT
transfer cannot supply a physical transfer for this consumer.

Physical production, acquisition of title, transfer of custody, and museum
accession remain separate assertions or events. `physical_acquisition` maps only
an explicitly recorded title-transfer claim. `physical_custody_transfer` maps
only an explicitly recorded custody-transfer claim. Neither creates a current
holder, museum accession, rights grant or the other transfer kind.

## Exact original statement convention

The unchanged `STREAM_SEMANTIC_ASSERTION_V1` carries the following convention in
an original selected direct assertion:

| Field | Required value |
| --- | --- |
| `relation` | `urn:6529stream:museum:physical-transfer:v1` |
| `mappingRule` | `urn:6529stream:museum:physical-transfer:v1:original-general-statement` |
| `subject` | The physical object's original entity IRI |
| `object.literal.datatype` | `urn:6529stream:museum:physical-transfer:v1:body` |
| `object.literal.language`, `unit`, `precision` | `null` |
| `object.literal.lexicalValue` | Exact JCS JSON, at most 16,384 UTF-8 bytes |

The body has exactly these fields:

| Body field | Meaning |
| --- | --- |
| `version` | `"1"` |
| `kind` | `physical_acquisition` or `physical_custody_transfer` |
| `status` | `planned`, `completed`, `cancelled` or `unknown` |
| `physicalObject` | Original `physical_object` declaration pin |
| `transferEvent` | Original `event` declaration pin for the particular transfer |
| `activity` | Distinct original `event` declaration pin for the enclosing activity |
| `fromParty` | Original `person` or `group` declaration pin, or `null` |
| `toParty` | Original `person` or `group` declaration pin, or `null` |
| `instrumentEvidence` | Exact original documentary occurrence and evidence item |

Each declaration pin has exactly `id`, `pointer` and `hash`. The pointer must be
a canonical `/entities/N` path in the same original General payload; the hash is
Keccak-256 of that exact declaration's JCS bytes. The enclosing record supplies
the declaration's occurrence identity. The object, transfer event and enclosing
activity must have distinct IRIs. Ambiguous duplicate declarations reject.

The body explicitly states that the transfer event is part of the enclosing
activity. The exporter does not manufacture another performed event to satisfy
the model. Party pins name only original source-declared people or groups. A
`null` party remains absent; the recorder, signer, DID and institutional label do
not fill it. No party's identity, consent, countersignature or standing is proven
by its declaration.

`instrumentEvidence` has exactly `sourceRecord` and `evidenceIndex`:

- `sourceRecord` is one exact Metadata selector already present in the original
  payload's top-level `sourceRecords`.
- `evidenceIndex` is a canonical unsigned decimal string naming an item in this
  same assertion's original `evidence` array.

The selected record must be present in the replayed Metadata catalogue. Its
original complete payload hash and canonicalization must match the documentary
evidence. The Metadata selector's pointer must be empty, meaning the complete
original payload, or equal the evidence selector. Whole-document evidence has
an empty selector; JSON-pointer evidence must resolve. The package retains the
exact selected bytes and their hash as well as the complete original payload
commitment and occurrence. Equal bytes in another record do not substitute that
record's author or authority.

These are the exact bytes described as an instrument by the original statement.
A reference or URL inside those bytes does not supply its external target. No
network retrieval or determination of instrument validity occurs. The inherited
General source requires the Metadata record's timestamp to be strictly earlier
than the General record's; equal timestamps do not establish cross-host order.

## Selection, conflicts and graph

The original General selection remains authoritative for this dossier view.
Only selected direct assertions with the exact convention above are interpreted.
Disputed, withdrawn, mapping, unselected and unsupported originals retain their
dispositions and bytes. A selected malformed body claiming this convention
rejects the export.

Only an eligible `completed` statement emits graph resources. Planned,
cancelled and unknown statements retain their body, evidence and status in the
sidecar. Publication time, `createdAt` and `effectiveAt` never become event time.

The graph contains a `HumanMadeObject` with its original IRI and an `Activity`
with the distinct original enclosing activity IRI. The activity's `part` embeds
the appropriate specialized transfer, with `transferred_title_of` or
`transferred_custody_of` pointing to the physical object. Explicit party pins
can populate the corresponding `from` and `to` references. The activity's local
classification is the declared crosswalk for the body's kind, not an external
authority match.

The pinned model admits specialized transfers only as embedded components and
does not admit an `id` on those components. The exact original transfer-event IRI
therefore remains in `transfer/index.json` and the sidecar, with its declaration
pin and exact resource path and `/part/N` pointer. This preserves the source
identity without adding an unsupported graph property. Instrument evidence
remains explicit in the sidecar and per-leaf provenance; it is not converted to
a physical object used by the activity.

Different selected declarations cannot merge through reuse of an IRI.
Conflicting claims about the same transfer event are withheld without a recency
winner. The same physical object can have several distinct recorded events;
those are not inherently contradictory. Identical claims over the same original
declarations can retain multiple assertion sources. Unselected claims cannot
veto a selected original.

Completed activity containment must be acyclic. If eligible completed statements
form a cycle, the cycle's internal transfer edges remain withheld with their
original evidence. Acyclic nested activities remain supported. Planned,
unsupported and already-withheld statements do not create edges in this check
and cannot veto an otherwise eligible completed event.

## Retention, reconstruction and commands

The package retains the complete original General dossier under
`sources/general-dossier/`, exact original selection, supported and unsupported
statements, body and declaration pins, resolved instrument bytes, source coverage,
graph provenance and pinned offline model closure. `source/locations.json`
defines pointer bases. `verify` replays the nested native sources and regenerates
every derived byte; editing outputs and recomputing the manifest does not pass.

```powershell
.\.venv-museum\Scripts\python.exe -m tools.museum.recorded_physical_transfer_v1 profiles

.\.venv-museum\Scripts\python.exe -m tools.museum.recorded_physical_transfer_v1 build `
  general-semantic-dossier physical-transfer-export `
  --source-hash $sourceManifestHash --disclosure public

.\.venv-museum\Scripts\python.exe -m tools.museum.recorded_physical_transfer_v1 verify `
  physical-transfer-export --manifest-hash $manifestHash

.\.venv-museum\Scripts\python.exe -m unittest tools.museum.test_recorded_physical_transfer_v1
```

The Python APIs are `build(source_files, source_hash, *, disclosure, model_root)`
and `verify(files, manifest_hash)`, returning an `Assembly`; `model_root` defaults
to the repository's pinned model. Public disclosure is required before reads and
output directories must be new. No command publishes a record or performs a
transaction.

Synthetic source replay proves consumer consistency, not deployed acceptance,
independent institutional validation, instrument validity or physical custody.
This supplement does not complete all MSM-RELATIONS5 requirements, the nineteen
acquisition-packet groups or forty-nine dossier assessments.
