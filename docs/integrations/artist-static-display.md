# Artist STATIC display transport

`IStreamStaticArtistSource.staticDisplayRead(bytes originalCalldata)` returns the
original ABI result as `bytes`. Its closed selector list is the thirteen Artist
reads in [the metadata source contract](static-artist-source.md). Unknown selectors,
trailing bytes, malformed owner results and missing dependencies fail closed. The
Registry enters the fixed display worker with `STATICCALL`; the worker uses bounded
`STATICCALL` reads of the constructor-bound owners. These paths do not enter the
ordinary delegated read codecs. Original getters and signed operations remain
available with their original selectors, domains and authority rules.

The inner result limit is 640 bytes (704 bytes including the outer `bytes` header).
Fixed owner facts use a 100,000 gas cap; current Core selection uses the original
Artist governed sale-facts cap. The caller still supplies its own bounded display
frame. Metadata must map a failed optional identity frame to its explicit
unavailable object, rather than substituting a previous document.

## Provisional identity maturity

The original live identity getter uses the current timestamp to select a provisional
revision. The STATIC read cannot use that clock. When an identity has a pending
revision it requires an exact stored maturity checkpoint. Before that checkpoint,
including after time has passed, the optional identity read is unavailable.
The original live getter continues to return its original result.

Anyone may call
`IStreamArtistStaticIdentityProjection.checkpointStaticIdentityMaturity(artistId)`
on the Registry. Its fixed forwarder checks the suite and Identity owner's
reciprocal Registry, Coordinator, Core and deployment-chain bindings. The Identity
owner then reads the actual pending revision and association, the canonical
transition and current authority. It records a checkpoint only when the original
phase, execution, window and contest eligibility predicates hold and the current
timestamp reaches the saved window end. Caller-supplied time is never accepted.
The Identity owner is also directly permissionless under the same source checks.

The checkpoint hash is:

```text
keccak256(abi.encode(
  keccak256("6529STREAM_ARTIST_STATIC_IDENTITY_MATURITY_V1"),
  chainId, identityOwner, artistRegistry, Context
))
```

`Context` contains the artist ID, candidate record, document hash, actual latest
execution, current authority address/class/status, complete provisional association
and complete canonical transition. The STATIC path reconstructs that exact context
from current stored facts and requires its marker, with no timestamp read. A new
candidate, association, transition, execution head or authority state cannot reuse
an older marker. An early contested candidate never matures; a later contest that
retains original eligibility requires a new checkpoint of its changed context.
Repeated recording of the same context is idempotent.

The Identity owner emits schema-1 `ArtistStaticIdentityMaturityCheckpointed` with
indexed artist, candidate and checkpoint, plus chain, Registry and the complete
ABI-encoded context. This is a rebuildable display projection in a separate storage
namespace. It changes no signed nonce, owner authority root, historical record,
replay cell or Archive entry. It is not an operation-60 authority proof and is not
imported as one. A successor may rebuild a projection only if its actually imported
history satisfies the same original eligibility checks.

## Validation scope

`StreamArtistStaticDisplay.t.sol` authors parity, malformed-input, missing-codec,
current selection, actual Safe checkpoint/event/idempotence, before/at maturity,
early/late contest, new candidate and later rotation controls. The main fixture uses
actual Artist owners, Safe and Archive with explicit typed Core/governance/finality
boundaries. The packed Platform correction test deliberately treats the Coordinator
caller as a typed boundary and checks original owner writers against both encoders;
it is not an adjudication-authority demonstration.

The fixed Platform, hydration and ordinary-read encoder extractions preserve their
existing guards, state order, original hashes and public ABIs. ABI/type checks and
selected size measurements are separate from executing these cases and from proving
the complete renderer's transitive opcode/readset and current-graph gas behavior.
Those runtime checks remain an integration responsibility; source parity alone is
not a complete STATIC renderer conformance claim.
