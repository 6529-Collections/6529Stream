# Condition and conservation documentation

The museum condition adapter interprets complete, prospective
`STREAM_CONDITION_REPORT_V1` bytes and the separately named
`STREAM_MUSEUM_CONSERVATION_TREATMENT_V1` specialization. The latter describes
PREMIS-aligned treatment documentation; it does not change a registered PREMIS
schema or create a new onchain family. Candidate documents are generated under
[schemas/museum/condition](../schemas/museum/condition).

## What is retained

A condition report contains the examination date and examiner, original work
citation with its typed state qualifier, examination block/hash/state root,
finality and route observations, fixity-cycle status and payload coverage,
render-verification method and pinned acceptance mode, ordered recovery lineage,
optional observed-rendering captures and the exact condition narrative.
Explicit not-verified and no-recovery statements are preserved.

Capture entries retain their stable identity, `still`, `frame_sequence`,
`av_container` or `scripted_session` class, URI/HashRef, format registry reference
and display-hardware/installation note. A reference alone does not prove that
the bytes were received, the format was registered or a capture was observed.

Treatment documentation retains named agents and roles, distinct source/outcome
artifacts, method, evidence, Artist intent/authorization references, before/after
condition references and migration observations. Only explicitly completed
interventions produce an attributed Activity. Conservation notes are statements;
planned, cancelled and unknown interventions do not become performed activities.
Named examiners remain distinct from the accounts that published their records.

The outbound/return comparator requires the same original chain/Core/token.
It reports exact changes, chronology qualifications, recovery-prefix differences
and capture identity conflicts. It does not conclude that the work is undamaged,
the render is equivalent or a recovery was lawful. All original source values,
nulls, empty collections, byte hashes and ordering remain in the dossier.

## Public Python entry points

```python
from tools.museum.condition import (
    PROFILE_HASH, SCHEMA_BYTES, admit_payload, compare_conditions,
    project_owner_conditions, project_independent_conditions, render,
)

# Submitted bytes have explicit draft/synthetic qualification.
draft_row = admit_payload(canonical_payload_bytes, schema_bytes=SCHEMA_BYTES)
draft_files = render([draft_row], pinned_linked_art_validator)

# Historical OwnerRecords, reconstructed from original retained RPC evidence.
files = project_owner_conditions(
    owner_source, selected_record_hashes,
    source_hash=externally_pinned_owner_snapshot_hash,
    profile_hash=PROFILE_HASH, model=pinned_linked_art_validator,
)

# Historical independent account records from their immutable captured state.
files = project_independent_conditions(
    recorded_semantic_source, exact_record_selectors,
    source_hash=externally_pinned_bound_state_commitment,
    profile_hash=PROFILE_HASH, model=pinned_linked_art_validator,
)
```

The owner wrapper accepts original `CONDITION_REPORT` records and rebuilds the
source from the original anchor/transcript before checking the external snapshot
hash. The independent wrapper accepts `INDEPENDENT_CONDITION` and
`INDEPENDENT_CONSERVATION_TREATMENT`; it checks the external
`source.state.commitment`, frozen records and capture/publication/interpretation
bytes. Mutable convenience maps cannot redefine those inputs. Both verify
original token subject/citation and exact registered schema/JCS bindings.

The earlier local owner-capture fixture has an opaque schema with the same
`STREAM_CONDITION_REPORT_V1` name. Its bytes remain unsupported and retained
unchanged; a matching name does not reinterpret that historical record as a
complete condition report.

## Reproducible condition packages

`tools.museum.condition_package` retains the complete verified recorded account
package, exact selected source evidence, schemas, profile, selection plan and
condition output. Its verifier replays the original sources and reconstructs
every derivative byte; replacing output and recomputing checksums does not pass.

The canonical plan has exactly `version: "1"`, `sourceKind`, `sourceHash` and
`records`. Use `sourceKind: "owner_records"` with the externally pinned owner
snapshot hash and original record hashes. Supply `--owner-inputs` containing
`anchor.json`, `transcript.json` and `deployment-evidence.json`, plus an
`--owner-pins` object with `anchorHash`, `transcriptHash` and `sourceHash`.
The owner and recorded account anchors must agree on the original chain, Core,
block number/hash, state root, timestamp and environment.

For `sourceKind: "independent_records"`, use the original recorded source's
`state.commitment` and exact whole-record selectors; owner inputs are prohibited.
Each plan selects between one and 64 records from one source kind. A private or
restricted package is unsupported: the explicit public classification applies
to all retained source evidence, including rows outside the display selection.

```text
python -m tools.museum.condition_package build SOURCE PLAN OUTPUT --source-manifest-hash HASH --plan-hash HASH --profile-hash HASH --disclosure public --owner-inputs OWNER_INPUTS --owner-pins OWNER_PINS
python -m tools.museum.condition_package verify OUTPUT --manifest-hash HASH
python -m unittest tools.museum.test_condition_package -v
```

Omit the two owner arguments for independent-source plans. The build never
fetches captures or instruments, publishes records, or upgrades the unproven
examination/treatment claims. Positive package tests use synthetic owner wire
evidence alongside the retained recorded account fixture. The existing actual
independent fixture verifies rejection of an unrelated family; a genuine typed
independent condition/treatment package remains untested.

## Verification and remaining joins

```text
python -m tools.museum.condition --check
python -m unittest tools.museum.test_condition -v
```

Use the pinned environment in the [museum tooling guide](../tools/museum/README.md).
Tests include invalid commitments/dates, exact decimal thresholds, incompatible
identities, changed recovery lineage, nonperformed treatment, legacy opaque
schema retention and mutations of cached source views. Positive owner controls
use synthetic original-wire transcripts. The retained actual independent fixture
contains no complete typed condition report; its test establishes explicit
absence and rejects unrelated families. These are separate evidence boundaries.

The wrappers check original account publication at the externally pinned trusted
RPC boundary. They do not independently execute examination-time `verifyFinality`,
route/fixity/render checks, resolve every executed recovery, retrieve capture
bytes, establish examiner credentials or institutional independence, or prove
treatment performance/authorization. Every such join has an explicit unproven
reason in the report. Actual current-chain typed captures and those joined
observations remain required for full adopted-profile acceptance.

Normative homes: [Genesis Museum Schema Set](collection-metadata-contract.md#genesis-museum-schema-set-cmc-genesis-schemas),
[conservation selection](architecture/conservation-record-selection-profile.md)
and [museum semantic mapping](museum-semantic-mapping.md).
