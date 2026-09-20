# ADR 0052: Exact entropy policy succession and origin relay

- Status: Accepted integrator decision for the undeployed full-v1 implementation.
- Date: 2026-09-20.
- Scope: Implements complete policy continuity under the existing coordinator
  replacement rules. Source integration and runtime acceptance remain separate.

## Problem and decision

Replacing the live Coordinator must preserve configured collection policies for
future mints without changing historical token authority. A zero pending-request
count alone cannot prove that the replacement has copied every collection. The
original policy hash also commits to the original Coordinator and provider;
rewriting either would change a frozen Artist-approved policy.

Import every configured LEGACY and EXPLICIT collection in authenticated order.
Keep the full original policy, reveal terms, provider/runtime/config, recovery
policy and receipts, ultimate origin and original hash. The import has separate
begin/seal/activation receipts; it creates no new Artist consent or old action.
Incomplete, malformed, changed or unsupported source inventories refuse cutover.
An irreversibly used candidate cannot begin a new import. A stale session needs
another unused candidate; there is no unbounded reset or partial activation.

Core retains the uncovered-pending guard, reads the source's exact three-word
inventory and requires the candidate's exact canonical true readiness response
for source/runtime/pointer revision/count/serial/ordered-ID digest. Every read
uses the full governed cap and parent reserve; no clipped gas, unbounded return
copy or missing-interface-as-empty fallback. Readiness means SEALED, with all
required origin routes confirmed. It does not mutate or activate the candidate.

## Atomic activation and authority

Begin, seal and permanent origin-route admission use their exact class-1
transitions. Importing the next authoritative source row is permissionless only
inside that authorized session. Provider lifecycle admission remains explicit.
After the complete import is sealed, one original class-3 governed batch performs
Core pointer replacement followed by candidate activation at the incremented
pointer revision. A late failure rolls the whole batch back. Catalog/deployment
plans must contain both exact calls and transitions. Initial Core assignment
retains its original rules; this gate applies to replacing a nonzero host.

During staging, ordinary configuration, registration, requester/provider mutation
and funding refuse. Once ACTIVE, the import receipt is permanent; later source
fees/balances cannot invalidate historical imports. Old token/scope subjects,
seeds, escrow and requester credits stay at their original hosts. New tokens
register at the new selected Coordinator. No host rederives an old token seed.

## Original provider calls and callbacks

An authenticated permanent route lets a successor call the ultimate original
Coordinator, which remains the original provider's caller. Successor request
keys, context and seed domains remain unchanged. The origin authenticates the
successor/runtime/import and its prewritten exact request witness; provider ID
and request-key collisions with local or relayed requests reject atomically.
Each ASYNC request forwards the exact original quote. The successor retains
escrow and excess-credit accounting; the origin accumulates no phantom liability.

The origin records one immutable raw result, with a separate received flag so
zero is valid, before bounded delivery to the recorded successor. Failed or
non-success delivery stays retryable from that same stored output; no additional
provider draw is requested. Original provider identity remains in the request
snapshot. Synchronous callbacks during submission reject under the existing lock.
Later Core pointer changes do not invalidate an earlier recorded route.

INSTANT reads use separate outer relay and inner provider budgets, both with
EIP-150 reserve checks and no clipping. The original call-free provider remains
distinct from this authenticated host relay. The successor derives its own seed.
No relay chain grows with successive Coordinator replacements: each route binds
directly to the ultimate origin.

## Alternatives, limits and acceptance

Rehashing a copied policy, retargeting the provider, silently dropping legacy
collections, or registering new tokens back at the old host breaks continuity.
Moving old subject/escrow state creates a second authority and is excluded.
Keeping origin calls means a dead origin is not repaired by this mechanism;
existing frozen recovery terms remain separately necessary. Their original
one-successor coverage must not silently become permission for a later successor.

Required tests include malformed/short/long/overflowing inventory and boolean
responses; exact source/runtime/revision/order binding; missing or partial
imports; complete legacy and explicit modes; real original provider caller and
callback checks; fee conservation and rollback; zero raw output; synchronous,
low-gas and malformed callbacks; retry without redraw; and two successor hops
with late original-token callbacks. Full current Safe/governance execution,
production code size, cold gas and matching release evidence remain acceptance
requirements. The existing RC1 source and deployment are unchanged.
