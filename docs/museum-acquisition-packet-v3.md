# Canonical acquisition packet V3 optional condition captures

`STREAM_ACQUISITION_PACKET_V3` uses numeric packet version `3` and permits a
present condition report to carry `examinationCaptures: []`. The field remains
required. Existing nonempty arrays retain their reference shape, maximum and
order. Every other V2 definition and semantic join is unchanged, including the
exact [native owner authority interpretation](museum-acquisition-packet-v2.md).

The change follows [CMC-GENESIS-SCHEMAS rule 3](collection-metadata-contract.md#genesis-museum-schema-set-cmc-genesis-schemas):
examination-capture entries are optional. The existing condition payload
schema already accepts `captures: []`; V1 and V2 packet definitions required
at least one packet-level capture reference. This additive version makes the
packet cardinality consistent without changing historical schema bytes or
reinterpreting an original condition payload.

## Exact definitions and API

The new deterministic definitions are:

- [STREAM_ACQUISITION_PACKET_V3.json](../schemas/records/STREAM_ACQUISITION_PACKET_V3.json):
  the complete packet with numeric version `3`.
- [STREAM_ACQUISITION_CONDITION_REPORTS_V3.json](../schemas/records/STREAM_ACQUISITION_CONDITION_REPORTS_V3.json):
  the exact item 15 object containing `owner` and `independent`, with no new
  wrapper or embedded version field.

```python
from tools.metadata.acquisition_packet_v3 import (
    validate,
    validate_condition_reports,
    PACKET_SCHEMA_BYTES,
    PACKET_SCHEMA_HASH,
    CONDITION_REPORTS_SCHEMA_BYTES,
    CONDITION_REPORTS_SCHEMA_HASH,
)

packet = validate(canonical_packet_bytes)
condition_reports = validate_condition_reports(canonical_item15_bytes, source_state)
```

The fragment validator checks canonical bytes, the closed lane branches,
reference bounds, record subject/source context and lane/type correspondence.
The full validator additionally applies the existing packet joins. Both
condition lanes keep the original classed record shape. V2's native owner
variant is still limited to accession and title-binding references.

Generate or check only the two new definitions:

```powershell
.\.venv-museum\Scripts\python.exe -m tools.metadata.acquisition_packet_v3
.\.venv-museum\Scripts\python.exe -m tools.metadata.acquisition_packet_v3 --check
.\.venv-museum\Scripts\python.exe -m unittest tools.metadata.test_acquisition_packet_v3
```

The generator checks frozen V1/V2 schema commitments and the unchanged native
owner interpretation profile before writing V3 files. No schema registration,
contract change or new authority profile is performed.

## Evidence boundary

A present record with zero optional captures remains a present record.
`none_recorded` retains its existing separate branch and supplied evidence
reference. Neither validation result proves latest selection, native absence,
capture completeness, retrieved bytes, examination quality or actual-chain
acceptance. A valid supplied full packet does not establish that its evidence
was authenticated or that the complete acquisition process conformed.

The [condition reader](museum-condition.md) retains unsupported selected
original schema/payload bytes and reports them as unsupported. A malformed
payload under a supported exact definition fails validation. Synthetic
regressions explicitly select the newest supplied native lane index while an
older supported report exists: neither case substitutes the older report.
Those controls exercise selection supplied to the reader; they do not prove
global latest-record selection or complete source history. This schema change
does not add a source reader or resolve those evidence requirements.
