# ADR 0017: Raise-Only Parameter Governance

## Status

Accepted for the pre-genesis production target on 2026-07-24 under explicit
protocol-owner direction.

This ADR supersedes the probe-dependent, lowering, emergency-restoration, and
permissionless parameter-mutation decisions in:

- ADR 0004 `[GOV-EMERGENCY-RESTORATION]` and the class-`6` portions of
  `[GOV-WINDOWS]`;
- ADR 0008's probe-gated royalty-parameter lowering and emergency-raise
  requirements;
- ADR 0010 decision D1 where it requires parameter probes, lowering, or an
  emergency path;
- ADR 0011 decision R5's health-probe-gated emergency raise and lowering path;
- ADR 0012 decision T1's Permanent probe contracts, conditional raises, and
  zero-signer parameter-repair drill;
- ADR 0013 decision U2's probe-bearing GGP/GTP introspection tuples; and
- ADR 0014 decision V7's permissionless conditional re-lower and cadence-probe
  binding.

Their retained decisions remain in force: storage-backed parameter values,
immutable floors and classifications, the 2x per-action raise bound, stable
parameter identifiers, wall-clock intent for time parameters, repricing and
cadence review, and canonical change events.

## Problem

The prior design attempted to preserve parameter repair after total governance
loss. It added one Permanent probe contract per gas parameter, cadence probes
for time parameters, authenticated registry bindings, rebind flows, probe-age
state, conditional action IDs, permissionless raise and re-lower paths, and a
zero-delay governance action class. Those mechanisms multiplied the genesis
inventory and the permanent audit surface while keeping complicated mutable
logic on or adjacent to byte-constrained hosts.

Probe success also could not make lowering safe for the full integration
population. A candidate that passes a pinned scenario can still strand an
unknown caller, future repricing schedule, or fixed-stipend integration.
Emergency and permissionless raises introduced a separate authorization model
precisely where gas and time changes can become denial-of-service levers.

The launch target needs one auditable rule that is safe for every parameter
class and avoids adding the superseded permanent machinery to `StreamCore`.

## Decision

1. Every launch GGP and GTP mutation is an authority-only Governance V2 action
   of class `DELAYED_LOOSENING` (`1`). Its minimum delay is 48 hours. The host
   accepts only its immutable Governance V2 executor, independently verifies
   the executing action ID, class, scope hash, old-state hash, and new-state
   hash, and emits the verified action ID.
2. Parameter values are monotonic for the life of the deployment. A mutation
   must strictly increase the live value and may increase it by at most 2x per
   action. A larger increase requires multiple separately delayed actions.
3. There is no lowering, emergency raise, probe rebind, conditional raise, or
   conditional re-lower entry. No permissionless caller can mutate a parameter.
   A zero governance authority makes the host immutable after construction.
4. Gas-parameter hosts retain immutable `floor` and `failureClass` facts.
   Time-parameter hosts retain immutable `floorBlocks` and
   `wallClockFloorSeconds` facts. These are introspection, audit, genesis-sizing,
   and repricing-review facts; they are not gates for a lowering path.
5. Stable parameter IDs and their numeric failure-class IDs do not change.
   GGP failure classes remain `NONE = 0`, `FORWARDING_CAP = 1`,
   `FAIL_CLOSED_PRECHECK = 2`, and `MIN_GAS_GATE = 3`. `NONE = 0` is only
   the unregistered-ID sentinel returned in the all-zero info tuple; a
   registered GGP must use exactly class `1`, `2`, or `3`.
6. The compact host reads are:

   ```solidity
   function gasParameterInfo(bytes32 parameterId)
       external
       view
       returns (
           uint256 value,
           uint256 floor,
           uint8 failureClass,
           uint64 revision
       );

   function timeParameterInfo(bytes32 parameterId)
       external
       view
       returns (
           uint256 value,
           uint256 floorBlocks,
           uint64 wallClockFloorSeconds,
           uint64 revision
       );
   ```

   Rich standalone stores may additionally expose current-value, identifier
   enumeration, immutable-governance-authority, schema, and failure-class
   reads. `StreamCore` keeps only the smallest launch-required surface. Every
   successful gas raise emits
   the canonical `GasParameterUpdated` event with `schemaVersion = 2`; every
   successful time raise likewise emits `TimeParameterUpdated` with
   `schemaVersion = 2`. The complete schema-v2 event fields are pinned by
   [LTA-GGP] and [LTA-GTP].
7. The complete state commitments use V2 domains because their tuple shapes
   remove probe and conditional-action fields:

   - `STREAM_GAS_PARAMETER_SCOPE_V2` =
     `0x9533611d402c2b44cf950a4a8900d25f6829bfac541dc4d5353094f966bb1a71`;
   - `STREAM_GAS_PARAMETER_STATE_V2` =
     `0x5059a253d3f7dd63b5d9fd1f0568caf72967f501a3db678b31cefe911334159c`;
   - `STREAM_TIME_PARAMETER_SCOPE_V2` =
     `0xd14cc3d71aa1ccb50b6f723d516042b10a7ef31958f86ccb049a09dbcfefff24`;
   - `STREAM_TIME_PARAMETER_STATE_V2` =
     `0x26290762a61f3dda3fad05a62e5a95dcb1c59db2eaf506cb363c2aa2ab7b8384`.

   The GGP state tuple is `(domain, scopeHash, value, floor, failureClass,
   revision)`. The GTP state tuple is `(domain, scopeHash, value, floorBlocks,
   wallClockFloorSeconds, revision)`. Genesis revision is `1`; every successful
   raise increments it exactly once; overflow reverts. This prevents
   `A -> B -> A` replay because the deployment cannot return to `A`.
8. GGP and GTP probe interfaces and implementations, probe bindings, probe
   manifest rows, probe execution records, probe recency bounds, conditional
   action IDs, and probe-rebind manifest-tail triggers are removed from the
   launch source, genesis profile, system-manifest payload, deployment
   rehearsal, release catalogs, and audit scope.
9. Governance action-class ID `6`, formerly
   `EMERGENCY_RESTORATION`, is retired before genesis. Numeric action-class IDs
   are append-only: catalog row `6` remains reserved as
   `retired_pre_genesis`, forbidden for scheduling and execution, and never
   reusable. The active launch classes are exactly `0` through `5`.
10. Read-only museum mode contains no parameter mutation promise. It preserves
    state reads, export, event replay, frozen-route discovery, and other
    explicitly read-only mechanisms. If governance is permanently lost, live
    parameter values remain readable but cannot change.
11. A parameter that must be tightened after launch requires a reviewed
    successor host or deployment line. The release manifest and operator
    procedures must make this one-way posture explicit before genesis.

## Security And Bytecode Impact

The decision removes a second authorization system, zero-delay parameter
mutation, probe spoofing and staleness questions, registry-dependent recovery,
lowering risk, and the permanent probe fleet. It also removes five GGP mutation
entries and one event from the **planned target** Core surface and reduces each
parameter's planned stored and committed state. Those probe/emergency entries
were not present in today's measured `StreamCore`; this ADR prevents their
addition and simplifies the target implementation, but does not itself shrink
the last 24,152-byte measured Core artifact.

The remaining raise path is intentionally conservative: 48 hours of public
notice, cancellation, an exact Governance V2 transition commitment, and a
bounded monotonic step. The change is expected to reduce Core and system audit
surface materially. Production size claims still require deterministic
release-bytecode evidence; target-spec subtraction and source deletion are not
size evidence.

## Release Impact

This is an intentional pre-genesis MAJOR cutover. No production deployment used
the superseded selectors, events, domains, class, or probes.

The permanent-interface lock, numeric-ID catalog, domain catalog, event and
error catalogs, genesis deployment profile and schema, system-manifest vector,
governance rehearsal, external-call gas inventory, Slither baseline, release
notes, manifest, bytecode proof, lockfile, and checksum bundle must all be
regenerated or reconciled. Historical release notes remain historical; current
target and readiness language must cite this ADR.

## Test Plan

- Every host rejects an unregistered ID, same-value write, lower value, value
  above the 2x step bound, non-authority caller, zero or non-executing action
  context, wrong class, forged scope, forged old state, forged new state, and
  revision overflow.
- Successful raises prove exact event fields and exactly-once revision
  increments. A second raise proves stale and ABA transition commitments fail.
- Constructor tests reject empty names, duplicate derived IDs, zero floors,
  genesis values below floors, invalid GGP failure classes, zero GTP
  wall-clock floors, and invalid nonzero authority contracts.
- ABI and selector goldens prove removed functions, probe interfaces, probe
  events, and class-`6` machinery are absent.
- Genesis-profile and system-manifest tests prove there are no probe rows or
  bindings and preserve the reserved empty payload field only where payload-v1
  compatibility requires it.
- Governance tests prove class `6` is rejected at schedule and execution
  boundaries and can never be registered or reused.
- Full Foundry, static-analysis, deterministic release-artifact, Markdown,
  release-currentness, and production blocker gates pass on the final candidate.

## Rollout

Apply the source and interface cutover before refreshing launch artifacts.
Reconcile the live tracker acceptance criteria that still require probes or
class `6` before merging the implementation PR. Re-run independent review on
the reduced surface, then publish the new deterministic size and release
evidence. This ADR changes the target; it does not by itself make the protocol
production-ready.

## Non-Goals

- No promise that a governance-loss deployment can repair parameters.
- No facility to lower a value after accidental or obsolete over-sizing.
- No change to the 22 GGP identifiers, three GTP identifiers, or their owning
  subsystem semantics.
- No claim that a 48-hour raise is fast enough for every incident.
- No production deployment or readiness claim.

## Accepted Risks

- A needed raise cannot execute sooner than 48 hours.
- An accidentally excessive value cannot be lowered.
- GTP windows can lengthen but cannot be shortened on this deployment line.
- Permanent governance loss freezes parameter values.
- Tightening requires a reviewed successor or redeployment.

These risks are accepted in exchange for a smaller, monotonic, single-authority
launch surface.
