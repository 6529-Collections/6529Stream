# Public DIRECT conservation evidence

`tools.museum.public_direct_conservation_capture` retains one collection's
original DIRECT conservation floor receipts at an externally pinned block.
The saved DIRECT sale, deployment bindings and floor receipt remain typed
originals. They are not converted to universal settlement candidates or results.
Acquisition packet item 13 remains **partial**; this capture does not produce a
V4 conservation fragment or a complete canonical packet.

The reader reviews source and Core interfaces at
`8bb6dfe2957542f641b0d558e1cfd48e1b39ae98`. This source pin identifies the
reviewed semantics. It does not establish deployment, historical execution,
native runtime acceptance, gas results or actual-chain acceptance.

## Original DIRECT evidence

The native DIRECT route saves the original adapter's paid sale receipt and
bindings, its authorization ID and receipt hash, the floor's own receipt hash,
effective tier, first-sale hash and release hash. Native currency, ERC-20 and
English auction products retain their distinct product identifiers. The reader
checks the original typed getters and events under the pinned source rules;
offline replay reconstructs that interpretation from the retained observations.

This profile requires the original adapter and manager to remain readable at
their pinned runtime hashes; unavailable original getters prevent capture and
do not erase the immutable floor receipt. It joins the manager's used authorization and
operation root with Core's completed token identity at the source block,
including a later-burned token. Core has no token-to-operation getter, so the
adapter's original validation of mint returns remains trusted. Current registry
or provider eligibility is not reexecuted. Fixed-price creation time equals
the paid timestamp. Auction creation time can precede paid publication and is
not substituted for the payment timestamp.
The original ERC-20 receipt retains the asset address without an asset runtime
hash; historical asset contract admission remains trusted, and no current asset
code read or asset runtime pin is required.

The floor's DIRECT receipt is separate from its universal settlement getter.
A universal paid receipt or mixed paid receipt families for the target
collection fail this source profile. Foreign collection receipts from both
families remain in discovery evidence. A scoped `none_recorded` result does not
prove that no payment occurred through another ledger or route. It means no
recorded paid DIRECT sale was observed for this scope, not proof of a free,
unpaid, cancelled or no-bid outcome. Supplemental DIRECT evidence is unsupported.

First-sale and release rows retain their original recorder or DIRECT adapter
identity. Reusing an earlier release does not invent a new release event. A
saved waiver remains explicit; it is not inferred from a missing release.
Authorization hashes remain commitments and do not recover unavailable signed
preimages. Reading a historical receipt does not execute the original payment,
reprove personhood or establish coverage of every paid route.

## Anchor and evidence limits

The closed collection anchor contains exactly:

```text
profile, chainId, blockHash, blockNumber, timestamp, stateRoot,
environment, deploymentEvidenceHash, core, conservationFloor,
executor, collectionId, codePins
```

There is no token ID or caller-selected history range. Fixed source filters
cover numeric block zero through the anchor, retaining matching receipts and
touched headers. The source/history/RPC profiles and fixed reader implementation
impose bounds; exceeding a bound fails capture without truncation.

Provider log completeness and canonical block mapping remain trusted. This is
not a genesis walk, all-block-receipt capture, ancestry proof or consensus
verification. The `trusted_rpc` label records the supplied provenance and does
not authenticate it. Synthetic examples must retain `synthetic_fixture`.
Governance observations retain native acceptance and stored executed actions;
they do not reconstruct every call in a governance batch or rederive historical
root-scope authority.

## Retained package

| Path | Contents |
| --- | --- |
| `source/anchor.json`, `source/transcript.json`, `source/snapshot.json` | Exact source triplet. |
| `definitions/` | Exact source, history, RPC and capture profiles. |
| `direct-conservation/evidence.json` | Source state, review commits, history coverage, source claims and qualification. |
| `direct-conservation/binding.json` | Full binding evidence. |
| `direct-conservation/catalogue.json` | Full source catalogue. |
| `direct-conservation/floor.json` | Exact status, first-sale row, releases and `directSales`. |
| `capture/report.json` | All 19 requirements: item 13 partial, all others unresolved. |
| `manifest.json` | Closed inventory, byte commitments, external pins and qualifications. |

Verification replays the source and rebuilds every derivative byte. Rehashing a
changed receipt, substituting a universal result or adding an authorization
preimage does not pass reconstruction.

## Commands and Python API

Read the current profile hashes:

```powershell
.\.venv-museum\Scripts\python.exe -m tools.museum.public_direct_conservation_capture profiles
```

Capture with an externally pinned anchor and an already configured process
environment variable containing the read-only RPC endpoint:

```powershell
.\.venv-museum\Scripts\python.exe -m tools.museum.public_direct_conservation_capture capture `
  --anchor direct-floor-anchor.json --anchor-hash $anchorHash `
  --source-profile-hash $sourceProfileHash --rpc-env STREAM_READ_RPC `
  --disclosure public --output new-direct-capture
```

Reconstruct retained evidence offline and verify its external manifest pin:

```powershell
.\.venv-museum\Scripts\python.exe -m tools.museum.public_direct_conservation_capture replay `
  --anchor direct-floor-anchor.json --anchor-hash $anchorHash `
  --source-profile-hash $sourceProfileHash `
  --transcript direct-floor-transcript.json --transcript-hash $transcriptHash `
  --provenance trusted_rpc --disclosure public --output new-direct-replay

.\.venv-museum\Scripts\python.exe -m tools.museum.public_direct_conservation_capture verify `
  new-direct-capture --manifest-hash $manifestHash
```

The Python `capture` and `replay` entry points require external source pins and
public disclosure. `capture` accepts the concrete read-only `PublicRpcTransport`.
`verify(files, expected_hash)` requires the external manifest hash and performs
offline reconstruction. Capture and replay require public disclosure before
input or endpoint reads. Endpoints and remote error details are not retained.
Publication follows successful replay and writes atomically to a new directory;
existing destinations are refused. No contract write or reference fetch occurs.

## Remaining work and controls

The separate [tier/default source](museum-conservation-tier-source.md) and
[selected intent/interview source](museum-conservation-source.md) are not joined
by this wrapper. A DIRECT canonical packet representation and the remaining
original conservation prerequisites are still needed. The existing
[universal conservation assembly](museum-acquisition-conservation.md) has its
own frozen family boundary; this capture does not change it.

`canonicalPacketCompatible`, `completeCanonicalPacket`,
`universalSettlementProjection`, `allPaidRoutesCovered`,
`authorizationPreimageRecovered`, `nativeRuntimeAcceptance` and
`actualChainAcceptance` remain false. Existing schemas and profiles are unchanged.

```powershell
.\.venv-museum\Scripts\python.exe -m unittest tools.museum.test_public_direct_conservation_source tools.museum.test_public_direct_conservation_capture -q
```

The controls use synthetic original receipts and concrete offline source replay.
They do not execute native contracts or establish actual-chain acceptance.
