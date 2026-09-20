# Public conservation tier and default evidence

`tools.museum.public_conservation_tier_capture` captures one collection's durable
Core tier declaration and mint-completion evidence at a pinned source block.
It preserves the difference between a declared tier, a default that has become
effective, and a prospective sale-floor rule. Acquisition packet item 13 remains
**partial** until the selected Artist intent/interview evidence and actual
sale-floor receipt are joined.

The source review uses the Metadata facade at
`f7a05e0734b95f1e2ff1a038b73511c0d94b6f81`, Core at
`ff372f80b830b45a6afb30583780414f3abcc4cc`, and ADR 0053, *Durable conservation
and condition-source anchors*. These pins identify reviewed producer semantics;
they are not deployment, compilation, runtime-test or actual-chain acceptance
evidence. The wrapper retains the exact reader profile and review commitments.

## Tier meaning

Core retains an explicit declaration permanently. Metadata replacement cannot
erase it. The native declaration accepts only `MUSEUM_GRADE`,
`MUSEUM_GRADE_LITE` or `CONSERVATION_WAIVED`, and its original Core and facade
events are retained in the same successful transaction receipt. This reader does not
consult a currently selected facade to decide the durable tier.

| Observed Core facts | Effective tier | Basis | Prospective sale tier |
| --- | --- | --- | --- |
| No explicit declaration and no completed mint | None yet | `not_yet_effective` | `MUSEUM_GRADE_LITE`, under `undeclared_lite_floor_rule` |
| No explicit declaration and at least one completed mint | `MUSEUM_GRADE_LITE` | `default` | `MUSEUM_GRADE_LITE`, under `undeclared_lite_floor_rule` |
| Explicit declaration | The declared tier | `declared` | The declared tier, under `declared` |

`rawDeclaredTier` retains Core's bytes32 value. Zero means no explicit
declaration; it never means `CONSERVATION_WAIVED`. A prospective LITE sale tier
before the first completed mint does not turn the public effective tier into
LITE. It also does not prove that a sale occurred or that its required floor
was enforced.

The source discovers the collection's original allocation and reversion events
and zero-from ERC721 mint Transfers. It reconciles that history with the
collection's next-serial denominator, minted-ever count and token lifecycle
views. A prepared allocation or a reverted preparation does not count as a
completed mint. The first completed mint is retained as its own original row;
it need not be the first allocated serial. Later burns do not erase completion
or reopen the declaration boundary.

This is native getter and event evidence. No generic record reference is
manufactured for the tier, and no new canonical packet field or authority class
is introduced.

## Collection anchor and trust boundary

The closed anchor contains exactly:

```text
profile, chainId, blockHash, blockNumber, timestamp, stateRoot,
environment, deploymentEvidenceHash, core, coreRuntimeHash, collectionId
```

There is no token ID, selected Metadata address, host list or caller-selected
history range. A known collection can be examined before any token completes
minting. The source derives all relevant collection and mint reads from the
pinned Core and original events.

The source/history/RPC profiles and fixed reader implementation impose bounds;
exceeding a bound fails capture without truncation. Fixed public-history filters
cover numeric block zero through the anchor and retain matching receipts and
touched headers. Provider log completeness and canonical block mapping remain
trusted. This is not a genesis walk, all-block-receipt capture, ancestry proof or
consensus verification. The original native declaration receipts do not amount
to fresh reauthorization of their historical caller.

## Retained layout

| Path | Contents |
| --- | --- |
| `source/anchor.json`, `source/transcript.json`, `source/snapshot.json` | Exact source inputs and derived snapshot. |
| `definitions/` | Exact source, history, RPC and capture profiles. |
| `conservation-tier/evidence.json` | Source state, review commits, history coverage, source claims and qualification. |
| `conservation-tier/tier.json` | Full tier row: raw and named declaration, effective/prospective tiers and bases, original declaration, first completed mint and completion count. |
| `conservation-tier/allocations.json` | Every source allocation row, retaining preparation and reversion evidence. |
| `conservation-tier/completed-mints.json` | Every completed-mint row emitted by the source. |
| `capture/report.json` | All 19 requirements: item 13 partial, all others unresolved, with remaining joins explicit. |
| `manifest.json` | Closed file inventory, byte commitments, external pins, provenance and qualifications. |

Verification rebuilds every derivative byte from the original source triplet.
Replacing a tier/default conclusion or dropping a mint row and recomputing the
file hashes does not pass reconstruction.

## Commands and Python entry points

Read the current source/capture profile hashes:

```powershell
.\.venv-museum\Scripts\python.exe -m tools.museum.public_conservation_tier_capture profiles
```

Capture with an externally pinned anchor and an already configured process
environment variable containing the read-only RPC endpoint:

```powershell
.\.venv-museum\Scripts\python.exe -m tools.museum.public_conservation_tier_capture capture `
  --anchor collection-tier-anchor.json --anchor-hash $anchorHash `
  --source-profile-hash $sourceProfileHash --rpc-env STREAM_READ_RPC `
  --disclosure public --output new-tier-capture
```

Reconstruct retained bytes offline:

```powershell
.\.venv-museum\Scripts\python.exe -m tools.museum.public_conservation_tier_capture replay `
  --anchor collection-tier-anchor.json --anchor-hash $anchorHash `
  --source-profile-hash $sourceProfileHash `
  --transcript collection-tier-transcript.json --transcript-hash $transcriptHash `
  --provenance trusted_rpc --disclosure public --output new-tier-replay

.\.venv-museum\Scripts\python.exe -m tools.museum.public_conservation_tier_capture verify `
  new-tier-capture --manifest-hash $manifestHash
```

Use `synthetic_fixture` for synthetic controls. A caller-supplied `trusted_rpc`
label does not authenticate the provenance of retained bytes. The Python
`capture` and `replay` entry points require external source pins and public
disclosure. `verify` requires the external manifest hash. `capture` accepts only
the concrete read-only `PublicRpcTransport`.
The distinct `public_conservation_tier_capture` package mode is also supported
by the common package verifier.

Public disclosure is required before input or endpoint reads. Endpoints are
neither printed nor retained. Capture and replay finish offline reconstruction
before atomic publication to a new directory; existing destinations are refused.
No contract write, deployment, schema registration, reference fetch or complete
packet export occurs.

## Remaining conservation joins

Tier/default evidence is one component of item 13. The separately captured
[selected intent/interview evidence](museum-conservation-source.md) has not been
joined by this wrapper, and a genuine sale-floor receipt with its prerequisite
evidence is still required. An explicit conservation waiver addresses the native
sale-floor requirement; it does not waive independent finality or preservation
obligations.

`canonicalPacketCompatible`, `completeCanonicalPacket`, `saleFloorEnforced` and
`actualChainAcceptance` remain false for every tier and mint state. Existing
packet schemas, profiles and producer contracts remain unchanged.
