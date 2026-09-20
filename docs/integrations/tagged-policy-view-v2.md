# Tagged policy VIEW adoption and serving

This additive profile retains the existing Router's VIEW head, immutable record
history, RENDERER_CONFIG aggregate, and original Artist operation 17 consent
book. It adds full-policy terminal and finalized rendering. It does not yet
provide the distinct VIEW output checkpoint, snapshot, reference, archive
inventory, or complete finality ceremony. The combined provider still refuses
VIEW finality until those components are implemented and admitted.

## Two profiles, one history

The original `STREAM_ADOPTED_VIEW_CONTEXT_V1` document, renderer and record
domains remain unchanged. The new payload is
`STREAM_STATIC_POLICY_VIEW_PAYLOAD_V2`, with context
`keccak256("STREAM_ADOPTED_POLICY_VIEW_CONTEXT_V2")`. Its record tag is
`keccak256("6529STREAM_STATIC_ADOPTED_POLICY_VIEW_V2")`.

The Router appends one compiler-owned `recordHash => profile` mapping to the
original namespaced VIEW State. `viewAdoptionProfile(recordHash)` first requires
an existing carrier. Zero then means V1; the closed nonzero tag means V2. An
unknown record is never an implicit V1 record. Unknown nonzero tags refuse.

Both writers update the same scope head and collection aggregate. V2 source,
prepared-state, aggregate-transition and record preimages explicitly include
the tag and their distinct V2 domains. The enclosing original
RENDERER_CONFIG family domain is unchanged. Before the first VIEW write, the
aggregate wrapper returns the exact original family hash.

The common predecessor reader authenticates the complete canonical outer
record under its saved profile before reading its revision. Thus V1 -> V2 -> V1
is one history; replacing a V2 head with V1 never decodes its executable payload
as V1. Each accepted original V1 record and output keeps its original bytes.

## Deployment and admission

Deploy the scoped policy factory from
[the scoped factory recipe](scoped-policy-source-factory-v2.md), using actual
Core, selected Metadata, scope membership and CoordinatorInventory pins. It is
a supplemental product beside the canonical genesis roles, not a replacement
for the original COLLECTION factory. Complete the genuine VIEW membership and
ordered coordinator inventory, then call the actual factory's `prepareSourceSet`.

Deploy `StreamFinalityPolicyViewEvidenceProvider` with the existing complete
combined configurations, original view declaration/membership binding, and
the actual scoped factory and runtime hash. This adds the immutable
`IStreamViewPolicySourceBindingV2` companion. It does not create another
selected provider. Existing COLLECTION and non-VIEW dispatch remains inherited.

Deploy `StreamViewRendererV2` for the full VIEW scope and that actual factory's
source set. Constructor targets are Core, Router, the scoped policy set, and
the original live attribution companion. The constructor verifies the complete
current factory/set relationship, membership and full ordered policy roster.
`policyViewBinding()` returns the exact 23-word binding. The Renderer keeps
each original coordinator rule in its own constructor-only
state; there is no setter or serving-time delegated policy-source call.
`encodingBinding()` returns the fixed compiler-linked formatter and its
constructor-retained runtime hash. Deploy/link `StreamViewRendererEncodingV2`
before constructing the renderer; the original four source targets keep their
order and meaning.

The renderer must separately receive the original governed STATIC Registry
admission, including exact code, manifest, source/read-set and output evidence.
An ERC165 response, constructor success or empty registration golden does not
establish that admission. Serving uses internal token/payload validation, two
fixed formatter STATIC calls, and bounded STATIC reads of original token facts.
The formatter has only pure HTML and output encoders and cannot call back or
write. Both calls consume the enclosing original render budget; no cap is
raised. HTML and its size check remain before the original live Artist read;
JSON/URI formatting follows that read. The renderer rechecks the immutable
formatter runtime before each call and bounds/canonicalizes its return.
The transitive read roster
must include every admitted actual Core, Router, Coordinator, membership and
live-attribution dependency, plus the exact formatter runtime and both
`html`/`output` selectors with maximum 262208-byte ABI returns. The original
governed analysis/read-set gate remains required; the getter alone is not
admission. Factory/current-selection calls belong to
constructor/adoption validation, not executable rendering.

Publish the complete V2 payload under its exact schema, retain its original
declaration, and use these additive Router calls:

- `previewPolicyViewAdoption(Input, actor)` returns the exact prospective
  original consent-family transition and authenticated source hash.
- `adoptPolicyView(Input)` consumes original operation 17 authority, repeats
  source and family checks, and atomically retains the record/tag/head/aggregate.
- `viewAdoptionProfile(recordHash)` identifies the retained record's closed
  decoder/rendering profile.

The `Input` outer shape remains original. `scope.scopeId` identifies complete
sealed membership; `viewId` identifies the declared view. They are not aliases.
The provider-owned factory, renderer binding and actual input scope must all
agree. A caller cannot supply an unrelated policy set or projected facts.

## Token and entropy meaning

Rendering requires an existing original token with a permanent collection
serial and a completed or burned lifecycle. Prepared, unknown and foreign
tokens refuse. The coordinator is always the token's original `coordinatorAtMint`,
with the constructor-retained runtime and policy; changing the collection's
current coordinator does not rewrite that token's source.

The explicit-policy branch reads the exact direct 512-byte tuple: collection,
all twelve original policy words, status, seed and request key. Every policy
word must match the retained rule. Status 1 requires disabled mode; status 2
requires optional asynchronous mode. Both require NOT_REQUIRED rendering,
zero seed and zero request, and emit `terminal: true, finalized: false`.
Required asynchronous status 5 emits the original seed and
`terminal: false, finalized: true`. Pending state cannot be promoted by a frozen
policy. The separate legacy branch requires original direct status 5 and emits
`LEGACY_FINALIZED_V1` with `policy: null`; it never fabricates a full policy.

The JSON/HTML context retains actual token ID, serial, all tokenData bytes,
scope/view/declaration/adoption/source identities, full policy fields and honest
entropy status. Historical burned rendering retains the original identity and
source. Current Router serving continues to enforce its burned-token policy.
Original live Artist attribution remains live in both profiles.

## History, export and migration

Read/export the exact original record bytes together with
`viewAdoptionProfile(recordHash)`. Authenticate the matching record and source
domains before interpreting the payload. V2 readers reject zero/V1 tags and
old V1 readers reject the V2 context/domain. The four existing Router VIEW
output methods use a closed tag dispatch; neither arbitrary targets nor caller
chosen decoders are accepted.

Artist operation 60 changes Artist owners while the selected Router normally
remains the same. Its VIEW tag mapping therefore survives in place. This
profile adds no unrelated requirement to copy Router storage through Artist
import. A genuine Router replacement/recovery must transport and authenticate
the record bytes and their closed tags under its separate authorized recipe;
this batch supplies no replacement/import endpoint and does not claim that
such a ceremony has run. Original op17 terms and record identities remain the
actual Artist authority evidence.

## Validation boundary

The source batch has an ABI-only 329-source check and thirty-three focused
regressions. Eight use actual Store and State to verify original V1 bytes,
V1/V2/V1 lineage, independent tag domains, two scopes, substitution, late
rollback and exact retry. Eleven use the actual V2 Renderer/Store/State with
explicit typed Core/factory/set/Coordinator/Artist replies to check full policy,
terminal/finalized/legacy separation, all twelve policy-word mutations,
prepared/burned identities, original coordinator, carrier corruption and
constructor binding refusal, exact fixed historical dispatch, exact early
burned-current refusal and formatter-runtime corruption/restore. Six formatter
oracles retain the former literal encoding bodies and check escaped bytes,
full policy/legacy output, limits, fuzz and actual STATIC write denial. Four
configuration-hash oracles cover the original complete context, distinct
compiler storage roots, host domains, all-word mutations and semantic-invalid
contexts that remain hashable under the original getter. Four complete source-projection
oracles compare literal 384-byte results, two storage roots, V1/V2/scoped
selection, original error ordering and non-COLLECTION early refusal. These
are not an actual governed Registry or
Artist op17 adoption ceremony.

Original Router ABI/storage and unchanged-body proofs are retained separately.
The first selected gate found RendererV2 at 26116 bytes and the new combined
provider at 24613 bytes, both over the unchanged 24576-byte runtime limit.
The second gate fitted the Renderer at 20988 bytes but found the inherited
VIEW provider at 24585 and new policy VIEW provider at 24856. Both failed
captures remain retained.

The final affected gate fits the inherited VIEW provider at 23681 bytes and
the policy VIEW provider at 24518. Together with the unchanged source products
from the second gate, all sixteen selected products fit both original runtime
and creation limits. This is selected bytecode evidence, not a native test or
transaction-cap result.

The first genuine native capture passed thirty cases and failed two pure
formatter-bound fixtures. One exhausted the 100m aggregate test budget while
the unchanged original encoder escaped an oversized NUL-filled name; the
other combined JSON parity and both URI refusals in one aggregate frame.
The test-only successor uses an oversized Base64 HTML carrier for the same
JSON bound and separates URI parity from the dual exact-error checks.
All thirty-three cases pass, including two 256-run fuzz oracles, with unchanged
production and test gas limits.

The cached successor recompiles only the changed test/probe closure. Every
production artifact remains byte-identical to the original genuine 104-source
capture. The smaller compiler context also emitted a different formatter
candidate; that output is retained as unused, with no equivalence claim.
Saved EVM deployment traces verify the original 7822-byte formatter creation,
runtime and actual address, both new test/probe link references, and the
embedded probe constructor. Test execution invokes no compiler and changes
no artifacts. These component tests do not establish cold transaction
capacity, governed admission or full current-stack/finality readiness.

The provider codec uses the fixed compiler-linked
`StreamFinalityProfileSourceReads` library with the actual compiler-owned
Context storage reference. Its original complete source-selection body and
validation order are unchanged. The original source getter returns all twelve
words; only its encoding crosses the fixed worker boundary. The policy branch
keeps its original non-COLLECTION early return. There is no persistent cache,
new authority, or caller-supplied source descriptor. Deployments must link the
new library runtime and use the resulting actual provider runtime pins; old
provider identity or receipt continuity is not implied.
