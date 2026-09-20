# Public canonical condition-source capture

`tools.museum.public_condition_capture` retains and replays the complete bounded
condition-source catalogue and record lanes for one original token at one pinned
block. It records the source reader's exact owner and independent selections,
including an unsupported newest record. Acquisition packet item 15 remains
**partial**: original publication and latest selection do not establish the
condition report's protocol or examination claims.

This reader is based on the condition-catalogue source at
`f7a05e0734b95f1e2ff1a038b73511c0d94b6f81` and the Core binding source at
`758572df4e7f3969f549dd58aef0c369202e2b27`. These are source-review pins, not
deployment, compilation, runtime-test or actual-chain acceptance evidence.
The capture keeps the source profile's exact interpretation bytes and source
review commitments. It does not replace the existing
[selected condition projection](museum-condition.md) or change its profile.

## Canonical source population and selection

The new source authenticates the Core's durable catalogue binding and reciprocal
runtime/dependency commitments. A missing, unreadable or changed binding fails
capture; it cannot become an empty source set.

The append-only catalogue includes every admitted host and every replacement
predecessor. Admission does not limit a host's relevant publications to those
after admission, and replacement does not stop later publications from the
predecessor from participating. The consumer retains:

- every admitted source and the complete source-set accumulator;
- each owner host's complete token `CONDITION_REPORT` lane, across authors;
- each independent host's complete collection `INDEPENDENT_CONDITION` lane,
  including intervening records for other subjects;
- original publication receipts, schema/canonicalization documents, payload
  bytes and signature evidence checked by the source profile.

Only matching original token subjects participate in the final token selection.
Each lane selects the greatest authenticated publication position
`(blockNumber, transactionIndex, logIndex)` across its admitted hosts. Effective
dates, receipt timestamps, author addresses, admission order and schema support
do not choose the latest report. Per-author latest getters are not a complete
lane denominator.

| Source selection status | Retained meaning |
| --- | --- |
| `none_recorded` | The complete canonical population has no matching record for this lane and token at the source block. The selected locator and interpretation are null. This makes no statement about unadmitted contracts. |
| `present` | The selected original has a supported typed interpretation. Its declared examination and protocol results still require separate evidence. |
| `selected_unresolved` | The newest original locator remains selected, with its unresolved interpretation reason. An older interpretable report never substitutes for it. |

A supported report with an empty optional capture list remains present. The
[packet V3 schema](museum-acquisition-packet-v3.md) permits the corresponding
empty packet capture list, but this capture does not assemble a packet fragment
or claim canonical packet compatibility.

## Capture inputs and retained files

The caller supplies an externally pinned canonical anchor and exact source
profile hash. The closed anchor fields are:

```text
profile, chainId, blockHash, blockNumber, timestamp, stateRoot,
environment, deploymentEvidenceHash, core, conditionSources, executor,
tokenId, collectionId, codePins
```

The anchor contains no caller-selected hosts, record hashes, source IDs or block
ranges. The source derives its reads from the bound catalogue. The
source/history/RPC profiles and fixed reader implementation impose bounds;
exceeding a bound fails capture without truncation. The public-history reader uses fixed-filter
queries from numeric block zero through the anchor and retains matching receipts
and touched headers. Provider log completeness and canonical block mapping remain
trusted. This is not a genesis walk, all-block-receipt capture, ancestry proof or
consensus verification.

Governance evidence retains the native accepted receipt and exact stored
executed action. It does not reconstruct a complete per-call batch witness or
rederive historical governance-root and scope authorization.

| Path | Contents |
| --- | --- |
| `source/anchor.json`, `source/transcript.json`, `source/snapshot.json` | Exact original source inputs and derived snapshot. |
| `definitions/` | Exact source, history, RPC and capture profiles. |
| `condition/evidence.json` | Source state and bindings, source-review commits, history coverage and source qualifications. |
| `condition/catalogue.json` | Complete retained catalogue membership and commitment evidence. |
| `condition/lanes.json` | Complete retained owner and independent lane evidence, including off-target independent records. |
| `condition/original-records.json` | Every original record row emitted by the source. |
| `condition/documents.json` | Every exact retained definition row. |
| `condition/selections.json` | Both complete selected locators and interpretations, without fallback or rewriting. |
| `capture/report.json` | All 19 packet requirements: item 15 partial, all others unresolved, with missing examination joins explicit. |
| `manifest.json` | Closed file inventory and commitments, profile/provenance pins and qualifications. |

The aggregate package is bounded. It preserves original evidence rather than
claiming that a pointer, capture URI, examiner name or publishing account proves
observed output, identity, independence or condition. References are never
fetched by this wrapper.

## Commands

Inspect the exact current source/capture profile hashes:

```powershell
.\.venv-museum\Scripts\python.exe -m tools.museum.public_condition_capture profiles
```

Capture using an already configured, explicitly named process environment
variable. Public disclosure is required before input or endpoint reads; the
endpoint is neither printed nor retained. The transport is read-only.

```powershell
.\.venv-museum\Scripts\python.exe -m tools.museum.public_condition_capture capture `
  --anchor condition-anchor.json --anchor-hash $anchorHash `
  --source-profile-hash $sourceProfileHash --rpc-env STREAM_READ_RPC `
  --disclosure public --output new-condition-capture
```

Reconstruct retained bytes offline with externally pinned commitments and
explicit provenance:

```powershell
.\.venv-museum\Scripts\python.exe -m tools.museum.public_condition_capture replay `
  --anchor condition-anchor.json --anchor-hash $anchorHash `
  --source-profile-hash $sourceProfileHash `
  --transcript condition-transcript.json --transcript-hash $transcriptHash `
  --provenance trusted_rpc --disclosure public --output new-condition-replay

.\.venv-museum\Scripts\python.exe -m tools.museum.public_condition_capture verify `
  new-condition-capture --manifest-hash $manifestHash
```

Use `synthetic_fixture` provenance for synthetic controls. A caller's
`trusted_rpc` label does not authenticate the provenance of supplied bytes.
Both capture and replay complete offline reconstruction before publishing a new
directory atomically. Existing destinations are refused. Verification replays
the source and reconstructs every derivative file; changing outputs and
recomputing manifest hashes does not pass. The common package verifier dispatches
the distinct `public_condition_capture` mode to this same verifier.

The Python entry points are `capture`, `replay` and `verify`; their pin and
disclosure arguments mirror these commands. `capture` accepts only the concrete
read-only `PublicRpcTransport`; `replay` uses `PublicReplayTransport` internally.

## Remaining item 15 evidence

The capture leaves examination-time state, finality/route checks, latest fixity
coverage over the complete payload population, render execution and acceptance,
executed recovery lineage, capture-byte fixity and examiner identity/independence
unverified. It retains the source's original statements without promoting them
to those facts. `canonicalPacketCompatible`, `completeCanonicalPacket` and
`actualChainAcceptance` remain false, including when either or both lanes have
no matching records.

No contract write, on-chain registration, deployment, schema/profile replacement
or complete packet export is performed by these commands.
