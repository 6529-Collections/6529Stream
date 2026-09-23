# Native Artist personhood source and partial acquisition join

This additive workflow retains the fixed native Artist personhood read surface and
compares its current evidence commitment with the immutable commitment saved in a
native conservation first-sale receipt. It preserves every earlier capture and
schema byte. It does not change the V4 conservation fragment.

The implementation is prospective and source reviewed against native revision
`68498f8d8fc95d9a96324426bf7c1e50976b8405`. Synthetic fixtures exercise the
same ABI and replay checks but are not deployed-chain evidence.

## Evidence boundaries

The personhood source targets one collection and the Artist ID obtained from the
current native binding. It retains:

- the exact Core, Metadata, Artist facade, Coordinator, owner-suite and
  Attribution graph at one block;
- the current binding and current operative identity;
- the exact current `personhoodEvidence` selection and compact status;
- the original operation-24 native record, statement, signature and publication
  evidence when one exists;
- the current owner's latest matching native-head event, while an imported
  original Registry keeps its own immutable publication and retention
  transaction;
- the immutable proof summary and its independent tagged hash for resolved
  evidence; and
- the complete original General attestation documentary evidence exposed by the
  fixed source helper.

`NONE`, `WAIVER`, `RESOLVED`, `STALE` and `UNRESOLVED` are distinct native
statuses. The capture is a targeted current read, not a denominator of every
historical personhood head.

Three identity values remain separate:

1. the conservation registration identity saved in the first-sale facts;
2. the operative identity bound into the original personhood operation-24
   record; and
3. the operative identity observed at the source block.

Identity rotation may change the third without rewriting either historical
value.

For a current waiver, the evidence commitment domain is the original native
operation-24 record hash. For resolved evidence, it is the retained proof-summary
hash:

```text
keccak256(abi.encode(
  keccak256("6529STREAM_ARTIST_PERSONHOOD_PROOF_SUMMARY_V1"),
  Summary
))
```

A changed current head cannot be reverse looked up from a saved summary hash.
The join reports that historical commitment as currently unidentified instead
of treating it as absent or invalid.

A General record must have been current in its recorder lane when the original
operation-24 record was published. A later General successor is retained as a
supersession observation and cannot replace the original selected evidence.

## Capture API and CLI

`tools.museum.public_personhood_capture` exposes:

```python
capture(anchor_bytes, anchor_hash, source_profile_hash, transport, disclosure="public")
replay(anchor_bytes, anchor_hash, source_profile_hash, transcript, transcript_hash,
       provenance="synthetic_fixture", disclosure="public")
verify(files, manifest_hash)
```

Capture requires an explicit read-only `PublicRpcTransport`. Replay is offline
and accepts only `trusted_rpc` or `synthetic_fixture` provenance already bound by
the anchor. The endpoint and remote error details are not retained. Every output
contains the exact anchor, transcript and snapshot plus current, native,
documentary and graph sidecars. Verification reconstructs every byte.

```powershell
.\.venv-museum\Scripts\python.exe -m tools.museum.public_personhood_capture profiles

.\.venv-museum\Scripts\python.exe -m tools.museum.public_personhood_capture replay `
  --anchor personhood-anchor.json --anchor-hash $anchorHash `
  --source-profile-hash $sourceProfileHash `
  --transcript personhood-transcript.json --transcript-hash $transcriptHash `
  --provenance synthetic_fixture --disclosure public --output personhood-capture
```

Live capture replaces `replay` with `capture` and supplies the name of a process
environment variable through `--rpc-env`. The output directory must be new.
Offline reconstruction finishes before atomic publication.

## Additive acquisition assembly

`tools.museum.acquisition_personhood` composes three unchanged packages:

1. one native V4 conservation assembly;
2. one original provider-configuration binding; and
3. one native personhood capture.

Each package must pass its original verifier and external manifest pin. The
conservation and provider packages must contain byte-identical copies of the
same floor capture. All packages must share provenance and exact source state.
The assembler reconciles the real tier, conservation-selection, floor, RIGHTS,
provider and personhood transcripts, shared runtime pins, headers, receipts and
matching log pages without projecting a new anchor.

The bound provider configuration must match the personhood source's exact Core,
Metadata and Artist facade at configuration indices 0, 1 and 8. The first-sale
commitment then receives one of these qualified statuses:

- `not_required_platform_floor`;
- `current_waiver_matches_saved`;
- `current_resolved_summary_matches_saved`; or
- `saved_commitment_not_currently_identifiable`.

A provider-binding input already requires a non-waived first sale. A match
establishes commitment correspondence under the explicitly admitted
runtime and source evidence. It does not independently prove that the evidence
was current at the historical sale, that the provider binary corresponds to a
published artifact, or that the runtime executed successfully on a consensus
chain.

```python
compose(conservation_files, conservation_hash,
        provider_binding_files, provider_binding_hash,
        personhood_files, personhood_hash,
        disclosure="public")
verify(files, manifest_hash)
```

```powershell
.\.venv-museum\Scripts\python.exe -m tools.museum.acquisition_personhood assemble `
  --conservation native-conservation --conservation-hash $conservationHash `
  --provider-binding provider-binding --provider-binding-hash $providerBindingHash `
  --personhood personhood-capture --personhood-hash $personhoodHash `
  --disclosure public --output native-personhood-assembly
```

The V4 conservation package remains byte exact beneath
`conservation-assembly/`. The provider binding and personhood capture remain
byte exact beneath their own directories. New files contain only the personhood
correspondence, the validated `STREAM_ACQUISITION_PERSONHOOD_V1` supplied-data
fragment at `packet/native-personhood.json`, cross-source reconciliation,
partial report and examination note. The fragment source reference commits the
personhood capture manifest, anchor, transcript and snapshot plus both source
and capture profile hashes.

## Qualification

The assembly leaves acquisition items 6 and 13 partial. `RESOLVED` means the
exact native documentary proof summary remains current under the bounded source
joins. It does not prove legal personhood, institutional standing, an
instrument's validity, the attestation's factual truth or present signer
authority. `WAIVER` is an explicit native waiver and is never personhood proof.

The source retains the exact typed General notarization payload, including its
legal-person reference, when the selected summary names an available supported
record. `STREAM_ACQUISITION_PERSONHOOD_V1` preserves that General authority and
its original subject as a standalone supplied-data representation. The General
authority fields differ from the legacy V4 packet authority shape, and the
General record's collection may legitimately differ from the Artist collection.
The assembly therefore does not convert it into the V4 canonical personhood
field. The other packet dependencies remain necessary. This assembly reports
native correspondence as an additive sidecar and does not claim a complete
packet. `complete_packet` always verifies first and then refuses completion
with the unresolved item list.
