# Public conservation sale-floor evidence

`tools.museum.public_conservation_floor_capture` retains one collection's
original native conservation floor history at a pinned source block. It includes
the first-sale receipt, semantic-release receipts and paid settlement receipts,
with their original publication evidence. Acquisition packet item 13 remains
**partial**: this capture does not assemble the separate tier/default,
selected Artist intent/interview and remaining packet evidence.

The source review uses implementation
`7d9040dc700575027067b0cc4d822d06b7dff5f2` and the Core/interface surface at
`ff372f80b830b45a6afb30583780414f3abcc4cc`. These identify reviewed source
semantics. They do not establish deployment, native runtime acceptance, gas
results or actual-chain acceptance.

## Paid receipts and optional preparation

The native ledger is durably bound to Core. Its historical receipts preserve
their original identities and commitments across subsequent provider or recorder
changes. The capture retains the complete source rows, including static receipt
tuples, hashes, effective tiers and publication coordinates. Settlement rows also
retain the original settlement result and the four original events supplied by
the reader.

Preparation is optional. A successful paid call can persist its authenticated
evidence inline or reuse an exact matching prior preparation. Both routes retain
the original paid receipt. A preparation event alone does not establish payment,
a first successful sale, or an executed settlement. The capture neither requires
prior preparation nor promotes preparation into paid evidence.

Candidate commitments remain commitments. The source cannot recover the original
candidate payload from these getters; the retained accounting projection is not
its preimage. Historical native acceptance is not a fresh execution of the
original payment or documentary checks. Personhood proof and coverage of every
paid purchase route are not claimed.

`floor.status` is `present` or `none_recorded`. The latter describes this pinned
native ledger's retained collection history. It does not prove that no payment
occurred through another route. Neither status completes a canonical packet.

## Collection anchor and trust boundary

The closed anchor contains exactly:

```text
profile, chainId, blockHash, blockNumber, timestamp, stateRoot,
environment, deploymentEvidenceHash, core, conservationFloor,
executor, collectionId, codePins
```

There is no token ID or caller-selected history range. Source-derived filters
cover numeric block zero through the anchor and retain matching receipts and
touched headers. The source/history/RPC profiles and fixed reader implementation
impose bounds; exceeding a bound fails capture without truncation.

This profile admits at most 64 source rows, 512 ledger receipt events and 256
code pins. First-sale, release and settlement events from other collections stay
in the discovery evidence; target collection filtering happens afterward.
Historical Metadata/provider code hashes remain saved source facts. Their current
code or eligibility is not needed unless the caller explicitly adds those hosts
to the anchor's independently checked runtime pins. Original target recorders
must remain readable at their saved runtime hashes.

Provider log completeness and canonical block mapping remain trusted. This is
not a genesis walk, all-block-receipt capture, ancestry proof or consensus
verification. A caller-supplied `trusted_rpc` label does not authenticate the
provenance of retained bytes. Use `synthetic_fixture` for synthetic controls.
Governance evidence retains original native acceptance and stored executed
actions; it does not reconstruct every call in a governance batch or rederive
historical root-scope authority.

## Retained layout

| Path | Contents |
| --- | --- |
| `source/anchor.json`, `source/transcript.json`, `source/snapshot.json` | Exact source triplet. |
| `definitions/` | Exact source, history, RPC and capture profiles. |
| `conservation-floor/evidence.json` | Source state, review commits, history coverage, source claims and qualification. |
| `conservation-floor/binding.json` | Complete original source binding evidence. |
| `conservation-floor/catalogue.json` | Complete source catalogue. |
| `conservation-floor/floor.json` | Exact status, first-sale row, releases and settlements. |
| `capture/report.json` | All 19 requirements: item 13 partial, all others unresolved. |
| `manifest.json` | Closed inventory, byte commitments, external pins, provenance and qualifications. |

Verification rebuilds every derivative byte from the original source triplet.
Deleting a receipt, changing its interpretation or adding a candidate preimage
and recomputing file hashes does not pass reconstruction.

## Commands and Python entry points

Read the current source and capture profile hashes:

```powershell
.\.venv-museum\Scripts\python.exe -m tools.museum.public_conservation_floor_capture profiles
```

Capture with an externally pinned anchor and an already configured process
environment variable containing the read-only RPC endpoint:

```powershell
.\.venv-museum\Scripts\python.exe -m tools.museum.public_conservation_floor_capture capture `
  --anchor collection-floor-anchor.json --anchor-hash $anchorHash `
  --source-profile-hash $sourceProfileHash --rpc-env STREAM_READ_RPC `
  --disclosure public --output new-floor-capture
```

Reconstruct retained bytes offline:

```powershell
.\.venv-museum\Scripts\python.exe -m tools.museum.public_conservation_floor_capture replay `
  --anchor collection-floor-anchor.json --anchor-hash $anchorHash `
  --source-profile-hash $sourceProfileHash `
  --transcript collection-floor-transcript.json --transcript-hash $transcriptHash `
  --provenance trusted_rpc --disclosure public --output new-floor-replay

.\.venv-museum\Scripts\python.exe -m tools.museum.public_conservation_floor_capture verify `
  new-floor-capture --manifest-hash $manifestHash
```

The Python `capture` and `replay` entry points require external source pins and
public disclosure. `capture` accepts only the concrete read-only
`PublicRpcTransport`. `verify` requires the external manifest hash. The distinct
`public_conservation_floor_capture` mode also supports common package verification.

Capture and replay require public disclosure before input or endpoint reads.
Endpoints are neither printed nor retained. Offline reconstruction completes
before atomic publication to a new directory; existing destinations are refused.
No contract write, deployment, schema registration or reference fetch occurs.

## Remaining conservation joins

The separate [tier/default capture](museum-conservation-tier-source.md) and
[selected intent/interview capture](museum-conservation-source.md) are not joined
by this wrapper. Their original evidence and the remaining canonical packet
context are still needed. Receipt retention does not override a native provider's
unsupported documentary-personhood or release-membership boundary.

`canonicalPacketCompatible`, `completeCanonicalPacket`, `allPaidRoutesCovered`,
`candidatePreimageRecovered`, `nativeRuntimeAcceptance` and
`actualChainAcceptance` remain false. Existing packet schemas, profiles and
producer contracts remain unchanged.

## Offline controls

```powershell
.\.venv-museum\Scripts\python.exe -m unittest tools.museum.test_public_conservation_floor_source tools.museum.test_public_conservation_floor_capture -q
```

Synthetic controls exercise inline and optionally prepared payment, explicit
waiver, empty scope, recorder/source replacement and reuse of an older release
without a new release event. Mutation controls reject mismatched source heads,
getters, result hashes, original paid events and impossible emission order or
operation fields. These Python controls do not execute the native contracts.
