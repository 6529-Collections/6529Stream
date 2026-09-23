# Native attribution and sanction evidence

The public attribution capture reads the native Artist suite at one pinned
collection and block. It records current attribution, identity authority,
provider-observed state transitions and original sanction records. The source
review is pinned to `905bbe2a3f33f5e7fca436a987d8cba532149e8e` and uses the
actual APIs listed in the [producer map](museum-packet-v5-producer-map.md).

## Separate native facts

Attribution state and identity authority status use different enums. The
capture retains both original values. Native attribution state 0 means NONE;
it does not establish a platform work. Platform declarations are read and
checked separately.

Three sanction-related observations must stay separate:

| Observation | Source and meaning |
| --- | --- |
| Original sanction confirmation | The current binding generation's original Attribution-owner transition from accepted (2) to sanctioned (3). Its `recordHash` identifies the confirmed sanction, and its `reasonHash` identifies the finality record. |
| Latest association sanction | The Sanction owner's current `sanctionForAssociation` value. A later sanction can replace this value without changing attribution state. |
| Later dispute restoration | A transition from disputed (4) back to sanctioned (3). Its record identifies the dispute resolution or withdrawal; it does not identify a new sanction. |

The reader retains original sanction records, their publication positions,
native archive bytes and archive facts. It checks their original hash domains
and retained correspondence. These checks do not reauthorize a signature or
reexecute historical finality.

This source profile supports the principal operation-12 sanction archive and
native operation-13 confirmation archive. Other original operation layouts fail
capture. Its event, archive, ABI and reason-URI size limits are reader
availability limits; failure at a limit is not evidence that a native record
does not exist.

A hydrated current suite can contain an accepted binding without local
attribution transition events. The reader reports a missing historical baseline
explicitly. It does not treat missing events as an empty attribution history.
The supplied RPC provider remains responsible for complete log results;
offline replay does not establish consensus or authenticate the runtime
admission artifact.

## Join with a full V5 packet

`tools.museum.acquisition_attribution_v5` accepts an externally pinned
[V5 packet assembly](museum-acquisition-packet-v5.md) and an externally pinned
attribution capture. It reconstructs both inputs and reconciles all seven
source captures. Shared runtime hashes, source blocks, RPC responses, headers,
receipts and overlapping log observations must agree.

The original packet payloads retain their paths and exact bytes. Its original
manifest is retained at `inputs/packet-v5-manifest.json`; the added native
capture is under `captures/attribution/`. The existing RIGHTS snapshot reference
therefore continues to resolve to the same preserved bytes.

The join checks the packet's current Artist, binding generation and attribution
state against the native observations. It also checks the current personhood
binding, registration identity, operative identity and source suite against the
new capture. Registration and operative identities remain separate.

V5's generic binding and sanction references do not expose the same structure
as the native records. Their supported joins are deliberately explicit:

| V5 field | Checked native correspondence | Remaining supplied fields |
| --- | --- | --- |
| Binding record | `recordHash` equals the current retained binding hash. | Original host, signer, authority class, publication block, record type, schema and subject. Hydration can retain a predecessor-domain binding. |
| Sanction record | Original confirmed sanction, when available; otherwise the exact retained latest sanction, labeled `latest_unconfirmed`. Hash, original owner, signer, authority class and publication block must match. | Generic record type, schema and subject. |

A present sanction reference with no exact retained source record fails the
join. An absent binding or sanction that contradicts retained evidence also
fails. When native attribution is NONE, V5 can join only its `platform_works`
branch with a separately retained declaration; V5 has no branch for a generic
NONE observation.

The complete native records remain in the added capture even when V5 cannot
represent their fields. All 19 packet requirements stay visible, and item 6
remains partial. Full binding and attestation authority, unobserved historical
baselines, historical execution and the other unresolved source requirements
remain explicit. No institutional or complete acquisition conformance follows
from this join.

## Commands

```powershell
.\.venv-museum\Scripts\python.exe -m tools.museum.public_attribution_capture profiles

.\.venv-museum\Scripts\python.exe -m tools.museum.public_attribution_capture replay `
  --anchor attribution-anchor.json --anchor-hash $anchorHash `
  --source-profile-hash $sourceProfileHash `
  --transcript attribution-transcript.json --transcript-hash $transcriptHash `
  --provenance synthetic_fixture --disclosure public --output attribution-capture

.\.venv-museum\Scripts\python.exe -m tools.museum.acquisition_attribution_v5 assemble `
  --packet packet-v5-assembly --packet-hash $packetManifestHash `
  --attribution attribution-capture --attribution-hash $attributionManifestHash `
  --disclosure public --output packet-v5-attribution

.\.venv-museum\Scripts\python.exe -m tools.museum.acquisition_attribution_v5 verify `
  packet-v5-attribution --manifest-hash $manifestHash

.\.venv-museum\Scripts\python.exe -m tools.museum.acquisition_attribution_v5 export-supplied-packet `
  packet-v5-attribution --manifest-hash $manifestHash
```

For an explicitly configured public RPC endpoint, the capture command accepts
`--rpc-env` with a process environment variable name. The endpoint is never
retained in the output. Public disclosure is required before source or path
reads. Output directories must be new. `complete-packet` verifies the assembly
and refuses a source-complete export while requirements remain unresolved.
