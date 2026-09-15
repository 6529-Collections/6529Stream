# Live Artist attribution display

The Router’s `6529STREAM_LIVE_ARTIST_DISPLAY_V1` profile adds
`properties.provenance.attribution` to ordinary current token JSON and the
collection data URI. It reads the selected fixed Artist facade and actual
binding, operative identity names, accepted collaborators, Platform history,
permissionless claim totals, deployment references, attestation status and
covering sanctions. An Artist display lock does not hide current dispute or
revocation. The explicit historical endpoint and finality-selected renderer
continue using their original saved presentation and renderer bytes.

The source profile uses the durable original Finality’s pinned native provider.
Its `snapshotHost()` must equal `nativeConfiguration.targets[8]` with the saved
code hash and matching Core, metadata and Router identities. `SNAPSHOTS` is a
lock ID, not a Core pointer. That host supplies `currentSnapshot` and
`latestSnapshotHash`. The subject ID is the receipt’s `snapshotId`; the current
state hash is its `manifestHash`, independently joined to both manifest reads.
The snapshot record hash is a different value. An actual absent selected
snapshot produces attestation `none`; an unavailable owning host produces the
degraded object. This read path does not itself create a kind-1 approval.

All required Artist reads run inside one 8,000,000-gas self-call, with an
EIP-150 forwarding check and 300,000 gas retained by the caller. Individual
fixed reads allow 250,000 gas; authenticated membership reads allow up to
2,000,000 gas. Names are bounded to 256 UTF-8 bytes, accepted collaborators to
32 rows, reverse scope candidates to 64, and the attribution object to 32 KiB.
Malformed, oversized, missing-code, reverted or insufficient-budget reads yield
exactly `{"state":"attribution_unavailable"}`. No substitute name, authority
class or claimed state is fabricated. These are explicit serving limits, not
measurements of gas conformance. Very large valid source sets can require the
degraded posture under this bounded profile.

The fixed original Finality registry is captured once by
`initializeOriginalFinalityAnchor()`, callable only by the Router authority.
The current fixture and deployment configuration schedule it through the
existing delayed Executor path after the cyclic Artist/Finality graph is
complete and before serving/mint activation. A separate initialized flag
prevents a missing saved pair from reopening initialization. Serving rejects
missing or corrupted anchors; after a valid initialization, later Artist
facade failure can reach the exact attribution fallback without bypassing
original history, companion route or current route-status checks. Existing
per-collection historical anchors must still match the admitted original.

`IStreamFinalityTokenScopeInventory` is additive. The original membership owner
appends each reverse token/scope entry only after validating that token during
ordinary incremental indexing. Pending prefixes are explicitly incomplete;
only the original completed membership and its pinned source bytes qualify for
sanction coverage. Repeated begin calls add no entries. The renderer inspects
all bounded completed scopes, plus collection and exact-token scope, retaining
`revoked > disputed > artist_sanctioned > artist_accepted > claimed` precedence.
The first covering scope in that deterministic order supplies the linked
sanction record; all covering candidates are still validated.

The [object schema](schemas/artist/live-attribution-v1.schema.json) validates the
selected shape and exact degraded object; it does not authenticate source facts.
The nested fields follow [AA-DISPLAY](stream-artist-authority.md) and the
[metadata renderer home](metadata-router-and-renderer.md). The source cases
cover all five states, four saved authority classes, scoped coverage, names,
claims, stale/disputed attestations, failures, saved-anchor corruption and a
real threshold Safe initializer. Current Core/Artist authority admission and
full native runtime/size acceptance are deferred to combined integration.
The read boundaries in the new display tests are explicitly typed fixtures.
Broader attestation writers and stored C2PA-authorship reduction remain separate
work; this batch is not a full institutional or renderer conformance claim.
