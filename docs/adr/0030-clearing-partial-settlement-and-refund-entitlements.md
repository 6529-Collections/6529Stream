# ADR 0030: Clearing partial settlement and refund entitlements

Status: accepted implementation direction for the new native clearing consumer;
consumer execution and current-stack acceptance are still pending.

## Context

[SSA-DUTCH-CLEARING](../stream-sales-and-auctions.md#uniform-clearing-rebate-mode)
requires a single immutable schedule-price fixing, rebates independent of failed
supplemental settlement, current-policy financial legs, and terminal refund
unlock. An unbounded loop over every purchase cannot safely implement those
outcomes in one transaction. A global price flag also cannot stand in for proof
that all per-purchase financial legs have executed.

## Decision

Price fixing is one permissionless operation bounded independently of buyer
count after sold-out or close. The
price uses the timestamp of the actual last accepted sold-out purchase, or the
immutable close reference (configured close or an earlier recorded close). It
never uses the later keeper call time. It fixes the global schedule price once
and emits `DutchClearingFinalized`. That event
identifies immutable price finalization; individual supplemental completion is
identified by each official settlement receipt. This clarifies rule4's phrase
“in the same finalization”: all buyer rebate entitlements arise at price fixing,
while positive financial legs execute through separate permissionless calls, one
purchase per call. The event's `supplementalRevenue` field is the exact fixed
scheduled total, computed from a sale-wide ceiling aggregate. It is still
refundable-class custody until each official receipt, not revenue already settled.
No operator or buyer enumeration is required. Failed financial
execution cannot reverse an earlier price fixing or any rebate entitlement.

Each purchase paid price p, already settled positive resting floor f, and has
buyer uniform price u=min(clearing, authenticated override) or clearing without
an override. Fixing creates permanent rebate entitlement p-u immediately. The
remaining u-f stays refundable-class custody until that purchase's official
supplement succeeds. The consumer distinguishes price fixed with pending financial
legs from all financial legs terminal. Zero supplements do not call the recorder
or fabricate a zero-valued success receipt.

Global terminal unlock prohibits every remaining supplemental call. Before price
fixing it refunds full held overage p-f. After partial financial execution it
refunds only remaining unsettled overage, retaining every original rebate and
never refunding revenue already officially settled. This clarifies rule6's full
overage conversion as applying to unexecuted financial legs. A successful floor
or supplemental settlement is never reversed by this unlock. Repeated terminal
operations cannot reopen payment or reduce existing claims.

## One common escape envelope

The immutable sale configuration binds one sale-wide absolute escape deadline and
its finalization window. Every purchase authorization must cover that same escape
and the finite configured nominal closing/finalization horizon. Different buyer
signatures cannot supply different deadlines that let an early buyer globally
unlock another buyer's still-valid financial leg. Exact nominal times and
observed pause toll remain separate from this absolute bound, as in
[ADR0027](0027-deferred-sale-window-envelope.md).

The effective financial deadline is the earlier of nominal finalize-by plus the
canonical global/local pause-union toll and the common absolute escape. Unpaused
finalization remains executable at equality. At equality while paused, refund
unlock is executable. Strictly after escape, unlock is unconditional and runs
before every external dependency read. An expired window cannot be revived by a
later pause. Refund and claim surfaces remain live while paused or dependencies
are unavailable. Typed non-transient unlock predicates must describe a failure
of this remaining financial leg; closure of a mint phase alone cannot block a
financial payment for an already-minted token.

The clearing clock retains historical global and per-sale pause transitions so
an unattended configured close can be evaluated later without counting earlier
pauses. It binary-searches the last transition at or before the reference,
including the last transition when several share one timestamp. Global changes
never iterate over sales. The elapsed toll is the increase in the union of
global and local pauses from the immutable close/sold-out reference to the
current time. These history reads are logarithmic in transition count, not O(1).
The accepted terminal timestamp and toll are frozen in sale state.

## Exact aggregate credits without enumeration

The consumer exposes the exact per-(sale,buyer) refundable balance, including
immediately available entitlement that has not yet been claimed. The immutable
purchase basis records total paid and an ordered aggregate of authenticated
ceiling values. Querying prefix counts and sums gives
`uniformSum = sumBelow + clearing * (count - countBelow)`.

The retained first representation uses fixed96-depth radix paths. Each node packs a
checked uint64 count and uint192 sum into one storage word. All intermediate
arithmetic remains uint256. A sale-wide maximum quantity bounded by uint64 and
prices bounded by uint96 imply the largest sum is strictly below2^160. The actual
consumer enforces the global quantity bound; a per-buyer count check alone is
insufficient. Nodes are added only as part of accepted atomic purchases and never
removed by claims or settlement. Insertion uses97 nodes including the root;
query uses at most96 child-node reads. A second sale-wide tree supplies the exact
scheduled total at fixing; each accepted purchase updates both trees atomically.
Fixing is bounded independently of buyer count, including its96-step query, rather
than literally a few reads. The cost of both insertion paths, authentication, mint
and reveal is measured in actual consumer acceptance.

The optimized representation compresses paths without changing the ordered
count/sum semantics. A root pointer at `nodes[0]` identifies it; a nonzero old
aggregate at `nodes[1]` with no pointer identifies the prior fixed-depth encoding.
Old trees remain readable and append through their original algorithm. A new
empty tree writes one leaf aggregate and its root pointer. Each new distinct
ceiling inserts one leaf and one branch, updating only real ancestors; duplicate
ceilings reuse that path. Canonical heap-prefix keys preserve skipped-bit query
bounds, and branches have at most96 decisions. A worst-case deep tree remains
expensive. Compression alone does not establish the collector gas gate.

No-override purchases index startPrice. An authenticated raw override indexes
`min(rawOverride,startPrice)` while retaining the original signed value unchanged.
For every valid clearing<=startPrice this preserves the exact buyer price:
`min(clearing,rawOverride) = min(clearing,min(rawOverride,startPrice))`.
This is a mathematical normalization, never a narrowing cast or a new signature.

While OPEN, only separately credited excess is claimable. Once PRICE_FIXED,
total rebate entitlement is `paidSum - uniformSum`. After terminal unlock,
it is `paidSum - count*floor - settledSupplement`. Subtract previously claimed
entitlement and add any separate per-sale excess credit to derive the currently
refundable balance. Claims and successful supplements update their own counters;
they never rewrite the immutable tree. These formulas preserve partial claims and
partially settled revenue through global unlock without iterating purchases.

The canonical `DutchRebateCredited` event is emitted through a bounded,
permissionless per-buyer synchronization call, and automatically when that buyer
claims. This idempotent seam announces only rebate entitlement not already
announced; it never gates `refundableBalance` or claims. Price fixing makes all
entitlements immediately effective without iterating buyers. A later terminal
unlock is separately identified by `DutchClearingRefundUnlocked`; newly unlocked
supplements are refunds, not relabeled original rebates.

## Scope and validation

The shared recorder's supplemental capability is the financial prerequisite, not
the clearing consumer. The consumer must still authenticate purchase proofs,
canonical sale consent and discounts, perform the original floor mint/reveal,
hold exact overage, bind the original operation/token record, implement pause and
terminal handling, and expose actual Safe call paths. Current token-aware rights
must propagate the provider's artist consent restrictions. Estate and authority
continuation use their canonical typed facts; no broad status allowance follows
from this ADR.

Acceptance includes independent sum-of-minima and packing oracles; partial rebate
claims followed by successful/failed supplements and terminal unlock; immutable
overrides and sold-out versus close pricing; pause-union and equality boundaries;
exact payment/custody/revenue conservation; and real Safe execution. A standalone
aggregate proof or recorder money test does not establish full clearing behavior.
