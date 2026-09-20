# Current citation recipe join

This test-only follow-up joins the governed citation change
`680d5aaa7384438a6e1264bc17eca5a604abcb0f` to the existing five STATIC and six
C2PA token lifecycle cases. **Native execution remains pending.** It does not
rewrite the earlier captured source inputs, original empty goldens, production
contracts, acceptance runner, release artifacts or RC1.

## Explicit actual admission

The [shared current helper](../../test/helpers/CurrentStaticTokenRenderingFixture.sol)
retains its unadmitted constructor. B's seven
[admission/refusal cases](../../test/current/StreamCurrentMetadataCitation.t.sol)
therefore retain their missing-admission negative. The five lifecycle callers
explicitly opt in after the real paid mint; the
[C2PA helper](../../test/helpers/CurrentC2PATokenLifecycleFixture.sol) opts in for
its separate Renderer/Registry after the actual token is revealed.

Each opt-in adds the exact class-1 selector policy through the original Safe and
Executor, registers retained Schema documents, and executes the current Registry
admission. The read list preserves every original declaration and adds the fixed
encoder's current selector. The test reconstructs the complete registration and
read-set commitments, checks retained analysis/golden hashes, all declaration
fields, exact readback, selected route and the original admission event.

Three new golden vectors cover compact JSON, URI and full JSON for actual token
1 in collection 2, including its token bytes and selected config. Expected values
come from the historical Renderer entry after checking an independently literal
context, with a test-local literal citation inserted once. No expected hash comes
from `renderCurrent` or the production citation helper. The original version,
registration, empty golden document and historical outputs are checked unchanged.
Analysis remains a **synthetic assertion over a partial read roster**, not an
executed transitive opcode analysis or accepted STATIC conformance.

The first STATIC case admits pending-token vectors without inventing entropy.
Direct Renderer full-mode vectors do not change Router behavior: public full
JSON/HTML still refuse pending entropy. Other cases use finalized vectors. All
current full JSON assertions check the exact historical-output-plus-citation
delta. Literal HTML, executable context, C2PA facts, burn identity and original
receipt/rollback checks remain intact.

## Current checkpoint versus retained history

The additional [actual-current checkpoint case](../../test/current/StreamCurrentCitationCheckpoint.t.sol)
uses the real paid/revealed token, Artist-authorized frozen config, original Core
inventory, membership, selection and content checkpoint producers. Its image is
explicitly absent, an original supported checkpoint profile.

Only the initial renderer capability observation is simulated as false, to model
the original-entry dispatch with the same pinned runtime. This is an explicit
boundary, not deployment evidence for an old renderer. The original renderer
actually produces the initial full JSON and HTML. Restoring its genuine current
capability refuses currentness while admission is missing. After genuine
Schema/Safe/Executor/Registry admission, the old checkpoint still refuses because
its full JSON has changed. Its complete `outputAt` row, plan and roots remain
byte-identical. A fresh checkpoint with a distinct salt captures the current
citation while retaining identical selection/source facts and HTML.

This matches the original live-full producer contract: it observes `tokenJSON`
and `tokenHTML` again when asked whether a checkpoint is current. Immutable
historical hashes remain readable; currentness does not freeze current output.
The new producer uses explicit fixture read/render frames of 4/20 million gas;
inventory/membership/selection frames are 0.1/0.5/2 million. These are unmeasured
fixture settings. Existing gas/capacity checks and EIP-170/EIP-3860 guards remain.

## Typed metadata suites

The [typed fixture](../../test/helpers/StaticMetadataRoutingFixture.sol) separately
models current admission only after a clearly named, one-time caller opt-in. It
checks canonical profile/selector, exact renderer runtime, advertised capability
and encoder pin. Construction defaults to missing admission. This is explicitly
a typed boundary, never genuine Registry governance or retained evidence.

Current routing, formatting, bundle-return and optional C2PA suites opt in. When
they construct a replacement renderer they opt in again for that exact new
instance. The live-full content checkpoint suite also explicitly opts in. The
selection-only and scoped-publication suites retain their original unopted
boundary; they do not serve current rendered output.

Three [boundary regressions](../../test/unit/metadata/StreamStaticCurrentAdmissionBoundary.t.sol)
check missing admission with working historical output, foreign profile/selector/
runtime rejection, and exact admitted routing with preserved historical bytes
and encoder-fault restoration. No historical golden file is rebased.

## Validation boundary

The selected ABI-only check includes all 74 named cases across the affected and
adjacent hosts, including B's unchanged seven cases, the existing selection and
scoped-publication suites, and these four new regressions. ABI compatibility is
not runtime execution. The integrator must freeze the final joined source and
run the original native/size/gas acceptance with all guards retained. Full 37,
genesis publication, transitive STATIC conformance, capacity, broad CI and release
readiness remain separate work.
