# ADR 0027: executable deferred-sale windows and a bounded refund escape

Status: accepted implementation decision for the new native refund-window schema.

## Context

[SSA-REFUND](../stream-sales-and-auctions.md) derives refund and finalization
deadlines from the purchase transaction's timestamp. SSA-AUTH rule 8 separately
requires a signature's `finalizeBy` to equal the derived deadline. A signature
prepared before inclusion cannot reliably predict that timestamp. In addition,
SSA-PAUSE tolls live windows, while SSA-ENVELOPE promises a bounded buyer
exposure and a refund exit. An indefinite pause must not strand a deposit by
indefinitely postponing its refund escape.

These requirements need an explicit reconciliation. Existing immediate sale
authorization schemas and settlement entry points retain their meanings.

## Decision

The new deferred authorization binds the immutable sale configuration and
window policy, `maximumNominalFinalizeBy`, and `absoluteEscapeDeadline`.
At purchase the adapter computes and stores:

```
nominalRefundDeadline = purchaseTime + refundWindowSeconds
nominalFinalizeBy = nominalRefundDeadline + finalizationWindowSeconds
```

It rejects unless `nominalFinalizeBy <= maximumNominalFinalizeBy` and
`nominalFinalizeBy <= absoluteEscapeDeadline`. The first signed value is an
upper bound before pause toll, rather than a prediction of inclusion time.
The authorization explicitly permits only the canonical pause toll described
below. Exact computed deadlines and the signed bounds are evented. A later
configuration change cannot alter a purchased window.

Refund windows remain in `[3600, 2592000]` seconds and finalization windows in
`[86400, 7776000]` seconds. A finite phase must initially contain the latest
possible sale purchase and both configured windows, as SSA-REFUND requires.
Tolling does not authorize the adapter to ignore the Manager's phase admission.
A phase that ends before a deferred mint can complete gives the corresponding
authenticated refund-unlock path.

Adapter-wide and per-sale pauses toll the union of their intervals. Overlap
counts once. Each purchase stores its initial cumulative pause observation;
its live toll is the change in that union. Effective refund and finalization
deadlines are their nominal values plus the observed toll, each capped by the
purchase's absolute escape. The terminal transition freezes the toll used for
that purchase's historical record.

Finalization remains valid through its effective deadline when unpaused. At
exactly `absoluteEscapeDeadline`, a paused finalization permits refund unlock;
an unpaused finalization remains executable through equality. Strictly after
the absolute escape, unlock is unconditional, including when the adapter is
paused or every external provider is unavailable. Thus an indefinite pause
cannot remove the buyer's exit. This absolute bound takes precedence over an
otherwise unlimited pause extension.

Global/local pause events retain the canonical interval history. Permissionless
purchase-window synchronization and terminal operations publish the resulting
per-purchase toll and deadlines; a global transition does not iterate over an
unbounded set of purchases. Views derive the same live values before such a
synchronization, so event publication cannot change eligibility.

## Money and authority boundaries

A purchase creates refundable adapter liabilities for the full price and the
separately saved live reveal fee; it does not mint or create official revenue.
The buyer receives excess fee allowance as a sale-specific pull credit. Refund or unlock
returns price and saved fee in full. Finalization sends exactly the price
through official recorder 9, forwards `min(savedFee, liveFee)` to the actual
Core-bound coordinator's collection fee escrow, and pull-credits the remainder.
Every refund, unused-fee credit and excess credit retains its originating sale;
the aggregate payer view is a summary, and a claim debits only the chosen sale.
The reveal fee never enters official revenue. A missing or undeclared reveal
policy is an error, not a declared zero fee.

The separate deferred native entry authenticates the active stored purchase,
its immutable envelope, buyer, exact price and current mint operation. It does
not reuse the immediate entry by substituting the finalizer for the payer.
The adapter's per-purchase terminal lane, the recorder's independent
`(adapter, purchaseId)` lane, and its shared official execution key prevent
replay. A changed execution or policy cannot reopen the same recorded purchase.
`ALLOW_CURRENT` selects current primary rights at
finalization; callbacks cannot redirect the concrete rights already selected
for that execution. Failure rolls back mint, revenue and buyer liabilities.
The purchase captures the artist identity, binding generation and binding hash.
New deposits and pending finalization require the composed Identity authority
to be ACTIVE, not merely a still-returned authority address. Finalization
requires that same accepted association and active status before effects and after
callbacks. An authority-address rotation within that association does not
require revalidating the original, already consumed purchase signature.
Identity contest does not become attribution dispute or gate the unconditional
refund escape; already finalized results remain readable without current checks.

Refunds and pull withdrawals do not require current provider, registry or
artist approval. Only the specified independently authenticated current-state
conditions can unlock before the time-based escape; an arbitrary bubbled error
is not proof.
A recipient rejecting a withdrawal preserves the payer's credit and retry.

Public checkout still requires canonical artist sale-parameter consent. The
initial signed profile does not substitute phase or economics consent for
that separate authority. Current-Core composition, all specified early unlock
conditions, reveal attempts, pause-role execution and exact fee behavior need
their own executable acceptance evidence; this decision is not that evidence.

## Consequences

The registration record retains the actual primary-policy baseline in its
configuration commitment and canonical `SaleConfigured` event. Each signed
purchase separately captures its original policy; `ALLOW_CURRENT` finalization
may observe another current policy. These three observations are not aliases,
and no later observation rewrites either earlier record. Registration is a
read-only preview of template rights, never a materialization or paid execution.

Permanent sale identity uses catalog `REFUND_WINDOW = 7`, and accepted purchase
nonces advance exactly once per `(saleId, payer)`, starting at 1. Commercial
signature replay remains an independent lane. All three declared sale gas rows
use `FAIL_CLOSED_PRECHECK` class 2 under SSA-GAS rule 7; the admitted inner
AT_MINT attempt still catches its own failure, while parent-gas shortfall reverts.

Clients must distinguish nominal signed bounds, live pause-adjusted deadlines,
and the absolute refund escape. The new signature type uses new field names
and a separate domain; old signatures are not silently reinterpreted. Tests
must cover boundary equality, overlapping and indefinite pauses, immutable
window records, unknown external failures, exact principal/fee accounting and
actual Safe callers. Default/IR size and compatibility checks remain required.
