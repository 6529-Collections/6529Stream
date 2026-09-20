# Repeated living recovery history

This guide covers a fresh living-class compromise and independently registered
recovery after an earlier operation35. The preceding living recovery remains
the actual latest35, and ordinary operation32 rotations retain its delegation
epoch. Each successful new35 increments the epoch once.

## Historical evidence

The reader starts from the actual current execution and walks every retained
vesting link back to the latest living35. Every32 must retain its original
record, addresses, revision, guardian prefix and preceding commitment. It then
walks the current cause's saved cause/resolution pair back to the exact pair
captured in that35. There is no caller-selected earlier baseline or arbitrary
history-depth limit.

Each dismissed episode belongs to its own actual execution and incumbent:

- An active compromise retains its original operation33 subject, which may be
  zero or an older admitted transition, independently of its captured execution.
  If it also captured and aborted a pending32, that original pending record and
  its separate closure must match the same cause and dismissal.
- A standing veto retains its actual unexecuted rotation and abandoned pending
  closure. Its cause may have zero evidence and zero reason under the original
  producer rules; its governed dismissal still has its original evidence.
- A cancelled notice retains its original phase2 notice, cancellation terminal
  and activity counter. Dismissal before cancellation restored status2; dismissal
  after cancellation while contested restored status1. Those saved statuses
  remain distinct, including when records share a timestamp.

Several cancelled notices and active dismissals may occur between recoveries,
with rotations before or after them. Their canonical record links and original
times prove ordering. A completed phase3 notice belongs to the separate
[designated-dormancy recovery profile](artist-dormancy-recovery.md); it cannot
be relabeled as cancelled history or a living authority transition.

## First closures and later subjects

For each executed35 or32, the first applicable dismissal in the complete chain
must match its immutable closure. Later dismissals cannot replace it, even at
the same timestamp. An early active compromise may be adjudicated and abandoned;
a first closure created during a notice requires the execution to have matured
before that notice began.

Each rotation is checked at its own original staging time. A later historical
subject marker cannot invalidate an earlier mature boundary when its exact
subsequent operation33 proves why the marker exists. It also cannot excuse an
unresolved early compromise or invent a closure. The fresh current compromise
can itself name zero or a historical subject while retaining the actual current
execution in its cause.

A historical pending head requires its real standing-veto or compromise-abort
cause, pending closure and matching executed predecessor. This applies both to
an unrotated living35 and to later rotation stages. An unclosed early current
compromise remains unsupported after waiting; elapsed time does not change its
original contest timing.

## Current compromise with an aborted pending rotation

The current operation33 may itself have captured and aborted a pending32. Direct
recovery can resolve that current compromise without a preliminary dismissal,
as allowed by AA-GUARD 4, 6 and 7 in the
[artist authority specification](../stream-artist-authority.md).

The fixed-owner proof joins the actual current cause and original Contest to
that exact pending record. It must be the last staged transition, with phase3,
no execution or post-execution window, the original compromise timestamp and
captured guardians, an empty live pending slot and an entirely empty dismissal
closure. The record's previous staging head must be authenticated at its own
staging time. Any older aborted predecessor still needs its original dismissal;
the executed predecessor must already have matured or been properly resolved.
The ordered cause chain identifies the exact last staging head, even when
timestamps match, so a saved pointer cannot skip an earlier aborted rotation.

Guardian election and supersession retain the executed35 or32 cutoff. The
aborted32 never becomes an executed authority or a guardian cutoff. Both a zero
and a historical operation33 subject remain distinct from the captured execution,
including when ARBITER or APPEAL supersession is requested.

Successful35 consumes the original current cause, advances the epoch once and
replaces both transition heads. It leaves the aborted32 and its empty closure
intact. The new35 saves that cause/resolution pair as its baseline, so a later
recovery can authenticate it without inventing an intervening dismissal. This
profile applies to repeated living recovery; first35 and class3 profiles retain
their existing admission rules.

## Context compatibility and execution

Histories already supported by the old direct or rotated readers retain their
original context encoding. Selection examines the records those readers
actually consume, so an old cancelled episode between compatible active
endpoints does not by itself change the encoding. The complete chain is still
authenticated. Newly supported histories add one tagged living-history proof.

The original recovery record, registered action, complete guardian prefix,
standing selection, acceptance, veto, permanent exclusions and receipt pair
remain authoritative. Every new35 still needs its own current governance and
acceptance. The read proof does not replay historical authorization, alter
storage, grant capabilities or increment an epoch.

## Authored validation

`StreamArtistLivingHistoryRecoveryActual.t.sol` uses actual Artist owners,
threshold Safes and Archive with the existing typed unit Core/governance
boundaries. Its cases cover direct/rotated baselines, both cancellation orders,
multiple episodes and rotations, standing vetoes, current and historical
subjects, guardian election, repeated epochs, canonical-history corruption and
exact restoration, receipt commitments, Archive rollback and replay.
Additional current-pending cases cover direct and rotated execution, cancelled
history, a previously closed pending predecessor, both supersession modes,
current versus historical cause substitution and later recovery of the saved
baseline. The corruption cases restore exact original records before retry.

Run the authored cohort as part of coordinated runtime validation:

```powershell
python scripts/dev.py test --suite unit --via-ir --code-size-limit 2000000 --gas-limit 1000000000 --memory-limit 1073741824 --match-path test/unit/artist/StreamArtistLivingHistoryRecoveryActual.t.sol --match-test '^testLivingHistory'
```

Native execution, full current-stack acceptance, linked product sizes, gas and
transaction capacity, full CI and release artifacts remain pending. Aggregate
fixture limits are not deployment or capacity evidence.
