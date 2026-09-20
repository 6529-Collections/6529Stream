# Typed metadata record definitions

This directory generates closed semantic schemas, interpretation profiles and
independent JSON fixtures for the developing typed record consumers. The
definitions are proposed registration inputs; generated files are not evidence
of onchain registration or accepted finality.

[COLLECTION policy V2 finality and packet V8](../../docs/museum-policy-finality-v8.md)
add original policy, snapshot/reference and STATIC preimage evidence without
changing earlier definition bytes. Generate/check only the new definitions
with `python -m tools.metadata.acquisition_policy_collection_finality_v2` and
`python -m tools.metadata.acquisition_packet_v8`, each supporting `--check`.
Historical authority and complete acquisition coverage remain unresolved.

[Scoped STATIC finality and packet V7](../../docs/museum-scoped-static-finality-v7.md)
add a distinct TOKEN/RELEASE/SEASON branch with original snapshot, complete
membership, selection and output hash rows. Generate/check the new definitions
with `python -m tools.metadata.acquisition_scoped_static_finality_v1` and
`python -m tools.metadata.acquisition_packet_v7`, each supporting `--check`.
Earlier definition bytes remain unchanged; supplied consistency remains
separate from source authenticity and historical execution.

The standalone [original governance transaction fragment](../../docs/museum-governance-transaction-evidence.md)
retains exact transaction/receipt/header observations and reconstructs ordered
call and action-ID preimages. Generate/check only its new definition with
`python -m tools.metadata.acquisition_governance_transactions_v1` and `--check`.
V5/V6 and native finality bytes remain unchanged. Recovered preimages do not
establish complete historical authority.

[Packet V6 and its native finality fragment](../../docs/museum-acquisition-finality-v6.md)
add paired native collection finality and token-content proof branches while
preserving all nineteen groups and the frozen V5 definition. Generate/check
only the new definitions with `python -m tools.metadata.acquisition_native_finality_v1`
and `python -m tools.metadata.acquisition_packet_v6`, each supporting `--check`.
Supplied native commitments and source capture replay remain separate; historical
Core facts and complete batch authority stay explicitly unresolved.

The additive [acquisition packet V2](../../docs/museum-acquisition-packet-v2.md)
supports exact native OwnerRecords authority in accession/title-binding slots.
Generate/check only its three new definitions with
`python -m tools.metadata.acquisition_packet_v2` and `--check`; all V1 dossier
definitions and validators remain unchanged.

The additive [packet V3](../../docs/museum-acquisition-packet-v3.md) changes only
packet identity and optional condition capture cardinality. Generate/check its
two new definitions with `python -m tools.metadata.acquisition_packet_v3` and
`--check`; V1/V2 definitions and native owner authority keep their exact meanings.

The additive [packet V4](../../docs/museum-acquisition-conservation.md) represents
native conservation tier/default, four selection lanes and historical universal
floor receipts. Generate/check its two definitions with
`python -m tools.metadata.acquisition_packet_v4` and `--check`. Validation checks
supplied fields and their relationships; the separate Museum composer replays
the original captures. V1–V3 definitions remain unchanged.

The additive [native personhood fragment](../../docs/museum-personhood-source.md)
retains original Artist and General authority separately, including the General
report's actual subject when its collection differs from the Artist collection.
Generate/check its single definition with
`python -m tools.metadata.acquisition_personhood_v1` and `--check`. It represents
supplied native evidence; source replay remains the Museum assembler's job.
It does not replace V4's personhood field or constitute a complete packet.

The standalone [native DIRECT floor fragment](../../docs/museum-direct-personhood.md)
preserves the original adapter bindings and paid receipt, shared first-sale and
release receipts, source admissions and ledger discovery. Generate/check its
definition with `python -m tools.metadata.acquisition_direct_floor_v1` and
`--check`. Its supplied-data validator does not authenticate the input captures;
the separate Museum assembler replays them. V4 has no DIRECT floor branch.

Use Python 3.12. The schema and RFC8785 tests share the existing pinned offline
dependencies in `tools/museum/requirements-jsonld.txt`; no new dependency is
introduced here.

[Packet V5](../../docs/museum-acquisition-packet-v5.md) keeps all 19 required
packet field groups and embeds the standalone native personhood, DIRECT floor
and conservation context definitions. Check it with
`python -m tools.metadata.acquisition_packet_v5 --check`. Supplied-data
validation does not authenticate source coverage; V1–V4 remain unchanged.

The standalone [native conservation context](../../docs/museum-direct-conservation-composition.md)
represents current tier/default and all four collection/token Artist/estate
selection lanes independently of the sale-floor family. Generate/check it with
`python -m tools.metadata.acquisition_conservation_context_v1` and `--check`.
It reuses the frozen V4 tier/selection semantics without constructing a floor or
claiming full-packet compatibility. The DIRECT composer separately replays six
original sources and checks historical correspondence.

```sh
python -m tools.metadata.rights_profile
python -m tools.metadata.rights_profile --check
python -m tools.metadata.work_profile --check
python -m tools.metadata.rights_definitions --check
python -m unittest tools.metadata.test_rights_profile tools.metadata.test_work_profile -v
```

Generation uses only the standard library. The tests independently compare all
generated bytes with RFC8785 and validate the complete closed schema. Solidity
tests enforce UTF-8 byte limits, Gregorian dates, cross-field constraints and
exact payload identity that a generic JSON Schema engine does not establish.

The [rights profile guide](../../docs/integrations/rights-json-profile.md)
describes the wire format and the remaining authenticated-consumer work.

The [work-description profile](../../docs/work-description-json-profile.md)
covers the complete typed work description and its separately committed format
catalog. Artist or curator authorization comes from the metadata host's
[record authority](../../docs/integrations/work-description-authority.md).

`rights_definitions` generates the Solidity constants for the exact retained
rights schema, interpretation profile and shared JCS definition. Regenerate it
after an intentional definition change. The [current rights selection design](../../docs/adr/0042-current-rights-record-selection.md)
explains how the consumer checks actual registered bytes and retains selected
history separately from current eligibility.
