# Source-driven token examination and citation export

The gatherer exports one replayed actual token fixture, its unchanged scoped
semantic bag, and explicitly admitted native evidence into a single offline
package. It extracts usable record envelopes, payload bytes, signature bundles,
lane heads, ownership hops and selected citation manifests. A registrar-facing
examination view accounts for all **19** acquisition-packet requirements.

This batch implements MUSEUM-17 evidence gathering. It does not emit a complete
`STREAM_ACQUISITION_PACKET_V1` or `STREAM_OBJECT_DOSSIER_V1`. Missing evidence
remains unresolved; it never becomes a fabricated absence, waiver or complete
history. Native renderer citation generation is a separate integration.

## Inputs and authority

The original token fixture must pass its external manifest pin and complete
offline reconstruction. It supplies permanent Core/token/collection/serial
identity, the examination block, and the scoped semantic package. Its original
authority and completeness qualifications remain unchanged.

Additional captures use these concrete readers:

| Kind | Original reader | Gathered output |
| --- | --- | --- |
| `owner` | `OwnerCatalogSource` | Every admitted family, occurrence, original owner receipt and signature bundle |
| `independent` | `IndependentCatalogSource` | All eight native families and mixed-subject history in one collection or deployment scope |
| `metadata` | `MetadataCatalogSource` | Complete admitted type catalog, generic records, payload pointers and lane heads |
| `general` | `GeneralAttestationSource` or `GeneralAttestationSourceV2` | Exact version dispatch, native attestation receipts, payloads, signatures, Artist evidence and registered definitions |
| `ownership` | `OwnershipSource` | Complete bounded Core Transfer stream, including mint and terminal burn |
| `hosts` | `DossierHostsSource` | Current registered host roster and unresolved or missing admitted scopes |
| `inventory` | `NativeInventorySource` | Every original producer segment/item and its token membership |
| `citation` | `CanonicalCitationSource` | Original finality, selected native snapshots and executed recovery citation evidence |

Each capture retains `anchor.json`, `transcript.json` and `snapshot.json`.
Source provenance is explicitly `synthetic_fixture` or `trusted_rpc`; a replay
does not authenticate its own origin. Every source is replayed by its concrete
reader. A changed snapshot cannot be accepted by merely updating its file hash.

The join checks original chain/Core/token/collection, block hash and number,
timestamp, state root, declared environment/deployment evidence, shared runtime
pins and repeated RPC results. Explicit Core serial/lifecycle/burn comparisons
also prevent differences hidden by gas-qualified request keys.

The older inventory profile does **not** declare environment or deployment
evidence. Its exact block, decoded Core, collection/token membership and shared
code/read facts are checked. `undeclaredAnchorFields` preserves the two missing
fields; the enclosing package does not supply them on the source's behalf.

## V2 canonical citations

[ADR 0051](adr/0051-recovered-citation-namespace.md) defines the additive
`STREAM_CANONICAL_CITATION_PROFILE_V2` and `STREAM_CANONICAL_CITATION_V2`.

| Qualifier | Exact commitment |
| --- | --- |
| `fin` | Original native finality record hash |
| `snap` | Native snapshot manifest content hash |
| `chain` | Original native record-chain head; retain host, scope and type beside it |
| `rec` | **Executed** recovery manifest content hash |

The original `eip155:<chain>/erc721:<lowercaseCore>/<globalToken>` identity
survives burn, recovery and successor routes. Recovery ID, route hash,
predecessor and original finality remain separate facts. Prepared, scheduled or
unexecuted recovery cannot produce `rec`. Current route diagnostics do not erase
historical execution. The reader distinguishes exact heads from per-family
overrides and captures collection/token scopes; it does not claim every scope
or every scheduled recovery in the protocol.

V1 remains restricted to `fin`, `snap`, `chain`. Existing citation parsing,
original 29 definitions and broader V1 packet schemas remain unchanged. The new
candidate profile is not retrospectively registered. A V1 consumer must reject
`rec`, not strip or rename it.

Snapshot readers distinguish native inline and chunked profiles. All bounded
receipt history is retained; complete manifest bytes are exported for explicitly
selected records. Ordered immutable segments reconstruct manifests up to the
native profile bound. The whole-manifest RPC getter is additionally compared
when its response fits the existing transport limit. A current snapshot head
does not assert that the snapshot is the currently served artwork.

`citations_v2.persistent_identifier_crosswalk` preserves the full original
citation, including the selected qualifier, in a DOI/ARK metadata fragment.
The proposed DataCite placement is `alternateIdentifiers[].alternateIdentifier`
with its required `alternateIdentifierType`; see
[DataCite schema 4.6](https://schema.datacite.org/meta/kernel-4.6/).
This is not a complete deposit, registration or resolution check.

## Prepare, build and verify

Use the isolated Python environment from the
[Museum tooling guide](../tools/museum/README.md). No RPC, native compiler or
network fetch is needed to reconstruct retained inputs.

Place only the selected capture triplets in a directory:

```text
captures/
  owner-main/anchor.json
  owner-main/transcript.json
  owner-main/snapshot.json
  citation-main/anchor.json
  citation-main/transcript.json
  citation-main/snapshot.json
```

All sources must describe the original fixture block. Fresh sources from a
later block require a newly verified token fixture; editing its labels is not
an update. The prepare command records one explicit provenance class for its
captures. API users can supply mixed, explicitly pinned source rows.

```text
python -m tools.museum.dossier_gather prepare-inputs --fixture FIXTURE --fixture-hash FIXTURE_HASH --captures CAPTURES --provenance trusted_rpc --disclosure public --output INPUTS
python -m tools.museum.dossier_gather build --fixture FIXTURE --fixture-hash FIXTURE_HASH --sources INPUTS --sources-hash SOURCES_HASH --disclosure public --output EXAMINATION
python -m tools.museum.dossier_gather verify EXAMINATION --manifest-hash EXAMINATION_HASH
```

`prepare-inputs` returns `sourcesHash`; `build` returns `manifestHash`. The
prepare step pins selected files and replays the original fixture; additional
source replay happens in `build`. Outputs must be new directories with existing
parents, outside their inputs. Publication uses staged byte readback and an
atomic no-replace rename. Public disclosure is checked before input reads.

The retained worked fixture is `schemas/museum/dossier/token-local-fixture`,
externally pinned by
`0x62ad190d7baa57290c72d22a98fb2249bc043b632597fc4454e77178af883425`.
An empty `CAPTURES` directory provides a reproducible baseline: the original
actual token and scoped bag are still verified and exported, while every
missing native source remains visible. It is not new deployed citation or
complete-packet acceptance evidence.

The 20 September 2026 local baseline completed prepare, build and exact offline
verify: 527 files, 30,638,348 bytes, examination manifest
`0x3bd04c14b2f93994380c93c24982aa82645c7d538be654e6c4fe733e96498c2c`.
All four retained inert implementation files matched the source used for this
batch. New native citation/catalog positive vectors remain explicitly synthetic;
this baseline does not replace a coordinated native capture of those readers.

The Python APIs are:

```python
prepare_inputs(source_state, capture_files, disclosure="public", provenance="trusted_rpc")
gather(retained_files, retained_hash, plan_bytes, plan_hash, source_files,
       disclosure="public")
verify(package_files, package_manifest_hash)
```

The closed `package_v2.verify_package` dispatcher also recognizes this new
examination mode. The retained scoped bag continues to use the existing
[repository exchange](museum-repository-exchange.md) workflow.

## Read the result

| Path | Meaning |
| --- | --- |
| `packet/examination.md` | Human-readable 19-item examination |
| `packet/fields.json` | Derived identity, source provenance and exact missing item numbers |
| `gathered/index.json` | Full admitted occurrences, heads, subject relationships and extracted-file paths |
| `gathered/sources/` | Original envelope, payload, signature and available chunk bytes per occurrence |
| `citation/choices.json` | Source-derived choices and concrete retained manifest/chunk paths |
| `citation/sources/` | Full finality/snapshot/recovery manifest bytes and original native records |
| `sources/` | Exact original capture triplets |
| `source/retained/`, `source/scoped-bag/` | Unchanged token fixture and semantic bag |
| `definitions/`, `tool/` | Exact reader/profile bytes and inert implementation provenance |

Repeated payload bytes retain distinct occurrence paths. Collection lanes retain
other-token records; those are not relabeled as target-token records. Supported
RIGHTS, CONDITION and ACCESSION/DEACCESSION payloads require exact original
schema/canonicalization commitments before interpretation. Meaning checks do
not create current selection, statement truth, institution identity or legal
title. Same-transaction owner records are distinguished from exact matching
TITLE_BINDING statements. Inventory descriptors remain distinct from the
artwork and dependency bytes they reference.

## Exact remaining complete-packet queue

The current profile derives items 1, 2 and 19. It gathers supporting evidence
for other items when the corresponding sources are present. Full canonical
export still requires these readers and joins:

- 3–4: all applicable finality scopes, token content-root proof and native
  coordinator-at-mint entropy leaf/events.
- 5–7: applicable historical/unregistered host coverage, canonical
  attribution/personhood and selected token-over-collection rights.
- 8–9: mode-total coverage/master status and selected accession instrument.
- 10–15: covering protocol event archive/title continuity; latest applicable
  drill; selected tombstone; conservation tier/intent/interview; C2PA report;
  and condition selection with examination capture bytes.
- 16–18: complete accompanying object-dossier packaging; every scheduled and
  executed applicable recovery with owner responses; and funding/floor,
  state-export age and zero-signer drill evidence.

The full object dossier additionally needs complete component bytes/archival
coverage, adopted semantic joins, pinned preserved tooling and drill evidence,
two independent repository ingests and external practitioner reviews.

```text
python -m tools.museum.dossier_gather complete-packet EXAMINATION --manifest-hash EXAMINATION_HASH
```

This command currently rejects with the exact unresolved item numbers after
verifying the package. It leaves the useful examination export intact. It does
not coerce unsupported fields into schema-valid absence branches.
