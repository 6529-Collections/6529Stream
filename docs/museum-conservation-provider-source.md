# Public conservation provider configuration

`tools.museum.public_conservation_provider_capture` retains a provider's original
configuration tuple and hash, named dependency observations, original and current
gas values, and registration evidence at an externally pinned block. This is
provider configuration evidence. It does not assign item 13 a completion status,
bind the provider to a historical paid floor receipt, prove personhood acceptance,
or assemble a canonical acquisition packet.

The source profile targets the additive getter at
`36c871f44636837bdc5504e6aaeafe54e14dcb98`. It requires an explicit runtime
admission for that source. It does not reinterpret an older provider or establish
compatibility with the older `8bb6dfe2` floor-source review. Native behavioral
validation remains separate; replay is not evidence of native execution or paid
acceptance.

## Source identity and runtime admission

The closed anchor contains:

```text
profile, chainId, core, collectionId, blockHash, blockNumber, timestamp,
stateRoot, environment, deploymentEvidenceHash, provider, codePins,
configurationHash, runtimeAdmission
```

`runtimeAdmission` contains exactly `sourceCommit`, `kind` and `artifactHash`.
The source commit is the exact reviewed commit above; the artifact hash is a
nonzero external commitment. A synthetic source uses `kind=synthetic_fixture`.
A source captured under `trusted_rpc` uses `kind=externally_admitted_runtime`.
Those labels must agree with the supplied provenance. The source snapshot's
`runtimeAdmissionStatus` retains this actual kind. Runtime identity is bound in
both cases; a synthetic capture is not labeled externally admitted.

Core and provider runtime pins are explicit in `codePins`. The retained artifact
hash records the caller's admission; this wrapper does not verify a compiler
artifact or independently establish a correspondence between runtime code and
reviewed source. A `trusted_rpc` label does not authenticate provenance or turn
a synthetic control into actual-chain evidence.

## Configuration and gas observations

The full original configuration tuple and its configuration hash remain intact.
Named dependency observations keep their source qualifications. Original gas
settings remain separate from current gas settings: a later change does not
rewrite the original configuration. Registration observations and their complete
retained receipts remain available for subsequent joins.

Unused configuration slots remain original values, without invented runtime
checks. An optional zero reference stays explicitly absent; a configured optional
reference retains its original address and runtime commitment. Current code is
checked for Core, the provider and any extra explicit anchor pins; other saved
dependency hashes do not require those dependencies to remain unchanged today.
These distinctions do not establish documentary authority or eligibility for a
paid sale.

The source/history/RPC profiles and fixed reader implementation impose bounds;
exceeding a bound fails capture without truncation. Provider log completeness
and canonical block mapping remain trusted. This is not a genesis walk,
all-block-receipt capture, ancestry proof or consensus verification.

## Retained package

The standalone capture contains exactly 12 files:

| Path | Contents |
| --- | --- |
| `source/anchor.json`, `source/transcript.json`, `source/snapshot.json` | Exact original source triplet. |
| `definitions/` | Exact source, history, RPC and capture profiles. |
| `provider/configuration.json` | Full configuration, configuration hash and dependencies. |
| `provider/gas.json` | Separate original and current gas observations. |
| `provider/evidence.json` | Original source anchor, review commit, source state, registration events, history coverage and qualifications. |
| `capture/report.json` | Provider evidence summary and explicit unsupported claims. |
| `manifest.json` | Closed file inventory, byte commitments, external pins and qualifications. |

Verification reconstructs every derivative byte from the original source
triplet. Rehashing a changed configuration, gas value or report does not bypass
that reconstruction. The report keeps `providerFloorBindingEstablished`,
`paidSaleAcceptanceEstablished`, `canonicalPacketCompatible`,
`completeCanonicalPacket` and `actualChainAcceptance` false.

## Commands and API

Read the current source and capture profile hashes:

```powershell
.\.venv-museum\Scripts\python.exe -m tools.museum.public_conservation_provider_capture profiles
```

Capture using an externally admitted anchor and an already configured process
environment variable containing a read-only RPC endpoint:

```powershell
.\.venv-museum\Scripts\python.exe -m tools.museum.public_conservation_provider_capture capture `
  --anchor provider-anchor.json --anchor-hash $anchorHash `
  --source-profile-hash $sourceProfileHash --rpc-env STREAM_READ_RPC `
  --disclosure public --output new-provider-capture
```

Replay retained evidence and verify the external manifest hash offline:

```powershell
.\.venv-museum\Scripts\python.exe -m tools.museum.public_conservation_provider_capture replay `
  --anchor provider-anchor.json --anchor-hash $anchorHash `
  --source-profile-hash $sourceProfileHash `
  --transcript provider-transcript.json --transcript-hash $transcriptHash `
  --provenance trusted_rpc --disclosure public --output new-provider-replay

.\.venv-museum\Scripts\python.exe -m tools.museum.public_conservation_provider_capture verify `
  new-provider-capture --manifest-hash $manifestHash
```

Use `--provenance synthetic_fixture` when replaying a synthetic anchor. Python
`capture` and `replay` require external source pins and public disclosure;
`capture` accepts the concrete `PublicRpcTransport`. `verify(files, expected_hash)`
requires the external manifest pin and reconstructs offline.

Capture and replay check public disclosure before input or endpoint reads.
Endpoints and remote error details are not retained. Offline reconstruction
finishes before atomic publication into a new directory. Existing destinations
are refused. No contract write, registration, deployment or reference fetch occurs.

## Bind the original provider to historical RIGHTS

`tools.museum.conservation_provider_binding` performs the separate configuration
join. Its inputs are one unchanged [historical RIGHTS assembly](museum-conservation-rights.md)
and one provider capture, each with its external manifest hash. It fully replays
both packages, requires equal provenance and source anchors, and reconciles their
real RIGHTS, floor and provider observations. Shared code pins, RPC outcomes,
headers, complete receipts and matching log pages must agree.

The first-sale receipt must be present and non-waived. Its original `sourceId`
selects the saved source admission, rather than a current replacement provider.
The provider address, runtime hash and configuration hash must match that
admission. Its Metadata address and runtime hash must also match the original
configuration. Configuration targets and hashes at indices 0 through 4 then
join the captured RIGHTS dependencies exactly:

| Configuration index | Captured RIGHTS anchor field |
| --- | --- |
| 0: Core | `core` |
| 1: Metadata | `host` |
| 2: schema registry | `schemas` |
| 3: Store | `store` |
| 4: RIGHTS selector | `rightsSelector` |

The original gas registration events must precede the source admission, which
must precede the first-sale publication, using exact block, transaction and log
positions. Other original configuration fields remain retained, including the
`artistFacade` target at index 8. They do not acquire an additional historical
execution or current-eligibility claim through this join.

The resulting `original_provider_configuration_joined` status establishes these
configuration correspondences. It leaves the prior historical RIGHTS status
unchanged, including missing or superseded records; it does not substitute a
current selected record. It does not prove historical `requireCurrent` execution,
personhood, paid Artist acceptance, legal permission or complete packet readiness.

```powershell
.\.venv-museum\Scripts\python.exe -m tools.museum.conservation_provider_binding profiles

.\.venv-museum\Scripts\python.exe -m tools.museum.conservation_provider_binding assemble `
  --rights historical-rights-assembly --rights-hash $rightsAssemblyHash `
  --provider provider-capture --provider-hash $providerCaptureHash `
  --disclosure public --output new-provider-binding

.\.venv-museum\Scripts\python.exe -m tools.museum.conservation_provider_binding verify `
  new-provider-binding --manifest-hash $bindingManifestHash
```

The Python API is
`compose(rights_files, rights_hash, provider_files, provider_hash, *, disclosure)`
and `verify(files, expected_hash)`. Both inputs remain byte-for-byte intact under
`rights-assembly/` and `provider-capture/`. The new `provider-binding/` directory
contains the binding, reconciliation, report and examination note; the profile
and outer manifest commit the complete output. Assembly requires public disclosure
and publishes only after successful reconstruction to a new directory.

`complete_packet(files, expected_hash)` and the `complete-packet` CLI command
verify the package, then reject completion with its unresolved item list. This
assembly adds evidence to the existing report and does not export a full packet.
Provider runtime admission remains explicit caller trust, not artifact authenticity
or historical provider execution proof. All commands in this binding stage operate
offline; they do not modify either input package or an older profile.

## Offline controls

```powershell
.\.venv-museum\Scripts\python.exe -m unittest tools.museum.test_public_conservation_provider_source tools.museum.test_public_conservation_provider_capture tools.museum.test_conservation_provider_binding -q
```

These controls use synthetic observations and concrete offline replay. They do
not execute the native contracts or establish actual-chain acceptance.
