# Original coordinator inventory

StreamFinalityCoordinatorInventory discovers every coordinator retained by Core
for an authenticated scope. It handles collections minted through several
coordinators without replacing older sources with today's pointer. All five
scope families use the same fixed [membership host](../scope-membership.md).

This is a source inventory, not entropy-policy, token-output or finality
readiness. The [entropy policy reader](entropy-finality-evidence.md) validates
a separately named original coordinator's policy.

## Index the actual scope

Construct the host with the actual Core, membership host and explicit small-read
and membership-read gas budgets. Construction checks live code, reciprocal Core
binding and ERC-165 capabilities. Chain and both source runtime identities are
fixed. No mutable binding phase or already-live Finality registry is required.

1. Call beginInventory(scope). The plan ID binds the full scope, all eight
   authoritative membership facts, captured chain, this host, Core and membership
   host/runtime identities. Repeating the same plan is idempotent.
2. Call appendInventory(planId, maximumTokens) with 1 to 256 tokens per call until
   the saved cursor reaches the count. This is a per-call bound, not a collection
   or coordinator limit. Anyone, including a Safe, can advance a plan. There is
   no caller-supplied token list, coordinator list or readiness assertion.
3. Call requireCompleteInventory(planId), then requireCoordinator(planId, index)
   for each source before interpreting its actual module and policy.

Every member comes from scopeTokenAt in authoritative order. Core must identify
it as a completed or burned token of the requested collection, with nonzero
serial and consistent lifecycle/burn flag. Its coordinatorAtMint supplies the
source. Prepared, unknown and foreign tokens cannot enter the plan.

The distinct source list follows first occurrence. One rolling commitment binds
every index/token/coordinator association, including repeat sources; another
binds every first-occurrence source/index/runtime. The completion hash binds
both chains and exact counts. Failed batches roll back entries, deduplication
positions, progress and events together.

An empty known scope has a complete empty inventory and nonzero commitment.
This does not establish that the mandatory entropy component may be omitted.

## Runtime identity and current validation

Core retains the coordinator address, not its mint-time code hash.
indexedCodeHash explicitly means runtime observed at first indexing. Repeated
sightings cannot replace it. Never present this as mint-time code evidence or
substitute it for original module-registration evidence.

requireCoordinator validates one source against that indexing-time pin. It does
not require today's selected coordinator. Proxy runtime equality also says
nothing about its implementation or mutable configuration; actual module and
policy verification must establish those facts.

requireCompleteInventory checks the fixed source graph, current full membership
and exact completed cursor. It deliberately does not loop over live code for
every entry. Consumers must validate every used entry separately. Neither read
proves token-output readiness or oracle service.

inventoryProgress, inventoryScope and coordinatorAt are historical reads. They
preserve the original plan after later mints, pointer replacement or dependency
unavailability. Unknown progress has exists=false; unknown scope and
out-of-range source reads revert.

Later collection mints change its membership snapshot. Current validation then
rejects the old plan, while a new beginInventory creates a different plan.
Published subset plans remain valid after unrelated parent mints. Burns do not
remove tokens or their retained coordinators.

Only exact fixed-size dependency results are copied. Parent-gas admission occurs
after allocating the bounded output and immediately before the static call.
Use smaller batches where needed. Supporting 256 tokens per call does not
promise that every such call fits an arbitrary wallet or network gas cap.

## Verification boundaries

The [focused tests](../../test/unit/finality/StreamFinalityCoordinatorInventory.t.sol)
use actual Metadata, Schema, Store, collection inventory and published membership.
Core provenance and governance are explicit response fixtures. Coverage includes
all scope families, burns, every saved fact, invalid identities, malformed return
sizes, runtime changes, atomic retry, empty scopes, a 256-token batch and
independent commitment reconstruction with fuzz inputs.

Two real threshold-Safe 1.4.1 cases invoke all sixteen public ABI selectors:
seven operative/history methods, eight binding/constant getters and
supportsInterface. Successful invocation and separate state/fact assertions do
not capture returned bytes inside Safe or complete the version/nesting matrix.

The [Core composition tests](../../test/unit/finality/StreamFinalityCoordinatorInventoryCurrentCore.t.sol)
use actual Core, Executor, Safe, module registration, pointer replacement,
Metadata and membership. Mint admission, entropy policy/output and inherited
artist/original-Finality evidence remain explicit boundaries.
