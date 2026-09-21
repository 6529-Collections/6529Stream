# Current-authority preservation archive coverage

This client targets source `e93cb09169dd90fe3b63cb32e93fe1a8955a0ee1`
and the [focused ABI155 fixture](../test/fixtures/current-authority-preservation-archive-v1-abi.json). The actual collection and scoped hosts are
`StreamCurrentAuthorityPreservationPolicyBundleArchiveCoverageV1` and
`StreamCurrentAuthorityScopedPreservationPolicyBundleArchiveCoverageV1`.
They accept the sealed current-authority preservation inventories under the
fixed token preservation V2 family.

## Prepare, simulate and reconcile

`CurrentAuthorityPreservationArchiveV1Deployment` supplies the chain, Core,
collection or scoped variant, archive runtime pin, current-authority read worker,
multi-origin read worker and reviewed linked-dependency pins. Each pin contains
the address and expected runtime code hash. Obtain the complete pin set from
reviewed deployment and link evidence.

A capture binds the requested operation, exact inventory segment locators,
current authority, archive environment, progress and gas allowance to a
concrete block. Simulation checks the prepared zero-value CALL; receipt
reconciliation authenticates its direct or Safe envelope and original events
against the saved capture and observed poststate.

The nine read-worker entrypoints use their compiler's nominal selectors
with separate structural value codecs. Their source-qualified reads support
reconstruction; the original archive host remains the operative admission.
These read workers are not transaction destinations.

1. Call `captureCurrentAuthorityPreservationArchiveV1` with the deployment,
   actual caller, requested operation, concrete block, gas limit and complete
   original inventory segment locators. Use the Safe address as caller for a
   Safe transaction.
2. Call `simulateCurrentAuthorityPreservationArchiveV1` at the intended block.
   Changed source facts or progress require a fresh capture.
3. Submit `capture.prepared.call` through the intended wallet, preserving its
   target, zero value, calldata and ordinary CALL operation.
4. Call `reconcileCurrentAuthorityPreservationArchiveV1Receipt` with the mined
   transaction hash and direct or Safe receipt options.

Use `inspectCurrentAuthorityPreservationArchiveV1History` for retained evidence
and `inspectCurrentAuthorityPreservationArchiveV1Current` for current admission.
The current inspection option `fullCurrentCoverage` also runs the original slower
byte diagnostic. `observeCurrentAuthorityPreservationArchiveV1Refusal` reports a
simulation revert separately from a transport failure.

## Coverage and refresh

Each host exposes five permissionless zero-value CALLs:

| Operation | Effect |
| --- | --- |
| `beginCoverage` | Checks the current archive environment and starts coverage of the sealed inventory |
| `coverNext` | Consumes the exact next Item and its original archive proof |
| `coverEmptySegment` | Consumes an authenticated empty segment in order |
| `beginRefresh` | Opens or resumes refresh for the current environment |
| `refreshNext` | Rechecks the exact expected Item index and extends the current observation chain |

A begin retry still checks the environment before returning. The original
inventory evidence includes its captured authority selection and sealed,
ordered origin set. Archive admission authenticates that evidence; it does
not call the inventory's separate current-source admission function.

The fixed resolver's fresh selection must match the inventory's captured
selection exactly. Authority succession can invalidate current archive
coverage while the original recorded evidence remains inspectable.

## Exact ordered items and original archive routes

Coverage follows the inventory's segment chain and each segment's Item links.
The proposed Item, its index and next link must reproduce the saved cursor.
A caller cannot substitute a new Item or reorder a segment. Empty segments
require their original zero count and zero link and still advance the chain.

Proof backend 0 is reserved for the supported intrinsic, absent, platform
and state-bundle cases. Backend 1 supplies an external coverage proof;
backend 2 supplies an onchain whole-byte coverage proof. The original reader
checks the applicable object, digest, size, schema and format relationships.
Retain the complete admitted proof and original evidence.

ABI byte correspondence uses the source's closed eighteen native/original
role-schema-canonicalization combinations and the separate original external
significant-properties reference. Four exact preservation V2 pairs were added
at this source checkpoint. Matching bytes alone does not establish publication
authority, inventory membership or archive coverage.

Artist state bundles use the inventory's authenticated per-Item origin.
The route verifies the original actor, semantic record, receipt operation,
domain, owner position and origin membership. It selects that origin's
Archive and runtime pin. Caller-supplied replacement archive addresses are
not part of this flow. The coverage chain commits each admitted origin hash;
the completed coverage also commits the sealed origin root and count.

## Environment changes and current admission

An environment change during progressive coverage clears the aggregate
environment marker. The coverage may still complete with its historical
commitment, but needs a complete refresh under one current environment.

Refresh progress is keyed by inventory and environment. Another caller
cannot reset it, and `refreshNext` must use the exact next index.
A completed refresh binds the current observation chain for every Item.

`requireCoverage` takes the inventory's original `renderCriticalEvidenceHash`
and checks the matching completed refresh under the current
environment. Its immutable-STOP aggregate profile permits bounded current
admission. `requireFullCurrentCoverage` performs the slower per-Item diagnostic
and rechecks original byte/runtime facts. These archive checks remain separate
from current inventory-source admission and finality.

## Recorded history

Local bundle evidence, progress, admitted Items, original admissions and
per-Item origin hashes remain recorded facts. Historical inspection
authenticates those commitments and distinguishes them from a successful
current-environment check. Collection events omit a schema word; scoped events
use schema version 1.

Automatic refresh at initial coverage completion retains a private observation
chain that public history getters cannot independently reconstruct. The typed
`initialObservationChainAuthenticated: false` result preserves that limit.
Explicit refresh reconciliation can verify the prior public refresh state,
new original worker observation, event and resulting observation chain.

## Evidence boundary

Source-qualified client checks and RPC simulation prepare reviewable calls.
Native contract execution, complete reviewed runtime/link pins, actual Safe
transactions and matching finality/release evidence remain separate acceptance
work.
