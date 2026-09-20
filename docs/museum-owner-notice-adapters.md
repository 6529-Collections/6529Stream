# Owner designation, response and notice dossier adapters

The supplementary `STREAM_MUSEUM_OWNER_NOTICE_DOSSIER_V1` component preserves
original `STEWARD_DESIGNATION` and `RECOVERY_RESPONSE` records and projects their
supported meaning. It extends the offchain tooling for
[CMC-OWNER-RECORDS rules 11 and 12](collection-metadata-contract.md) and
[ADR 0014 V8](adr/0014-world-class-pass-round-5.md). Existing catalogue, capture8,
V1/V2 dossier, schema and interpretation-profile bytes remain unchanged.

This implementation has synthetic positive and negative replay controls. Actual
current native capture and institutional acceptance remain separate requirements.
It does not close the broader Museum or whole-v1 delivery gates.

## What is preserved and established

| Evidence | Supported interpretation | Limits |
| --- | --- | --- |
| Original Owner record, hash, receipt, signature bundle and publication | The admitted native host accepted that owner at publication | No legal title, present custody, new signature approval or institutional identity inference |
| Typed designation and `OwnerStewardDesignated` event | Exact per-owner predecessor, original identity reference and ordered notice endpoints | Notice standing only; no write, signing, transfer or veto authority |
| Owner recovery response | That owner's acknowledged/objected statement, grounds, references, action ID and manifest hash | A response itself neither vetoes nor executes recovery |
| Independent response under `INDEPENDENT_PRESERVATION_EVENT` | The original class-5 attestor speaks in its own name | Never owner standing or an entry in the Owner response queue |
| Notice publication and retained delivery chunks | Exact publisher-attributed claims and original ordered endpoint coverage | No external delivery, recipient receipt, institutional assent or web availability proof |
| Companion recovery record and execution events | Matching native stored execution evidence and the historical owner-evidence revision it consumed | Executor `EXECUTED` status alone is insufficient; no complete ordered governance-call witness is reconstructed |

The original [JSON profile](integrations/owner-notice-json.md) and
[notice/action rules](integrations/owner-recovery-notices.md) remain authoritative.
Opaque identity/evidence references retain their algorithm, canonicalization,
digest and URI bytes. They are never fetched or converted into verified identity,
fixity or institutional participation.

## Original definition and carrier authority

`OwnerNoticeSemanticSource` requires a concrete, completely replayable
`OwnerCatalogSource`, not a caller-written summary. It reads the original
registered schema/profile/JCS definitions through their immutable chunk bytes.
Receipt definition hashes mean document **content hashes**, not registry
declaration hashes. The four notice documents and RFC8785 definition must match
their exact existing bytes. Their registry declarations use `RAW_BYTES`; record
payloads use `RFC8785_JCS`. Retired definitions remain interpretable.

The existing `tools.metadata.owner_notice_profile` validator checks complete
original canonical bytes, closed fields, profile/subject identity, UTF-8 limits,
all six reference forms and exact endpoint uniqueness. No normalization, default
response, endpoint sorting, inferred language or new schema is introduced.
Unsupported schema or interpretation bytes remain explicitly unsupported beside
their complete original records. A malformed payload claiming the supported
definition rejects the component rather than being silently repaired.

Designation order comes from the original typed event and
`stewardDesignationFor`, not the generic owner-family latest getter. A generic
record under another schema can share the family without advancing the steward
head. Optional same-block `OwnershipSource` history establishes which author's
retained head is currently selected. Transfer-back reactivates that author's
head; no new custody epoch is invented. Burn preserves attributed history and
has no current owner or designation getter call. Without ownership history,
current designation is explicitly not captured.

## Native notice and execution evidence

`OwnerNoticeEvidenceSource` independently replays the complete bounded receipt
history at the same block. It joins original notice openings and typed response
events, exact snapshot ABI bytes, immutable claim chunks, publication hashes,
complete matching queues, processed revisions, per-author replacement heads and
pending responses. Publication order is distinct from authored `effectiveAt`.
Pre-opening and late responses retain their original labels and order.

The reader retains the saved action binding and same-block governance facts.
Complete ordered `GovernanceCall[]` calldata is explicitly not captured; getter
hashes do not become a reconstructed action ID. Companion execution needs its
explicit runtime pin and original stored record plus matching execution,
lineage and evidence events. Its consumed owner evidence joins the historical
revision at execution, not a later response count. Cancellation, expiry, veto,
pending processing and historical execution remain distinct observations.

These readers refuse inputs exceeding their declared action, response, history,
claim and package bounds; they do not truncate them into a completeness claim.
All RPC reads use the same externally admitted block and runtime pins. Conflicting
answers to the same request across component transcripts reject assembly.
Transcripts are replay consistency evidence, not consensus or state proofs.

## Projection and offline package

The component contains original source anchors, snapshots and transcripts;
semantic definition bytes; notice evidence; a source-preserving dossier; and a
Linked Art projection under the existing pinned offline validator. Supported
statements become `LinguisticObject` resources containing the exact original
payload text. Every projected leaf has a rule and original source selector.
All source fields, including explicit empty evidence arrays, remain in the
coverage/sidecar output. This projection creates no inferred institutional actor,
delivery activity, custody transfer or moral-rights decision.

Python composition:

```python
semantic = OwnerNoticeSemanticSource(owner_catalogue, semantic_transport,
    ownership=ownership_source, independents=independent_sources)
notices = OwnerNoticeEvidenceSource(owner_catalogue, notice_transport,
    provenance=owner_catalogue.provenance)
result = write(semantic, new_output_directory, notices=notices)
```

The classes are in `tools.museum.owner_notice_semantics` and
`tools.museum.owner_notice_evidence`; `write` is in
`tools.museum.owner_notice_dossier`. Ownership, independent sources and notice
evidence may be omitted, with the omission reported explicitly.

For read-only capture, prepare a canonical JSON plan with exactly `profile`,
`owner`, `ownership`, `independents` and `notices`. Set `profile` to
`STREAM_MUSEUM_OWNER_NOTICE_DOSSIER_V1`; `notices` is a boolean, `ownership` is a
source object or null, and `independents` is an array of at most eight source
objects. Each source object has exactly these fields:

```json
{
  "anchorPath": "<absolute path>",
  "anchorHash": "<external keccak256>",
  "transcriptPath": "<absolute path>",
  "transcriptHash": "<external keccak256>",
  "snapshotPath": "<absolute path>",
  "snapshotHash": "<external keccak256>",
  "provenance": "synthetic_fixture"
}
```

Use `trusted_rpc` only for an externally admitted RPC source. Replaying a
synthetic source never changes its provenance. All original source packages are
replayed before additional semantic/notice reads:

```powershell
python -m tools.museum.owner_notice_dossier capture --plan <plan.json> --plan-hash <external-keccak256> --rpc-env STREAM_MUSEUM_RPC --output <new-directory>
python -m tools.museum.owner_notice_dossier verify <directory> --manifest-hash <external-manifest-hash>
```

Save the returned manifest hash outside the package. Verification checks the
closed file inventory, replays every original source and reconstructs every
derived byte with network access disabled. Updating file hashes after changing a
projection, interpretation, authority or original transcript does not bypass
semantic replay. No compiler, transaction, node process or external document
fetch is part of either command.
