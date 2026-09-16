# ADR 0048: Original repudiation Identity effects

Status: implementation decision under the authorized full Artist feature queue;
source/native acceptance remains separate. Date: 2026-09-15.

## Requirement and old matrix gap

[AA-DISPUTE 5](../stream-artist-authority.md#disputed-and-revoked-attribution-aa-dispute)
requires original operation 48 (`vetoAttributionRepudiation`) to terminate a staged
exit, set the Artist identity contested and void pending vesting. Original
operation 49 (`cancelAttributionRepudiation`) is direct authenticated activity by
the staging principal and must cancel genuine dormancy/unavailability through the
existing activity hooks. The historical proposed
[semantic owner matrix](../architecture/artist-semantic-owner-matrix-v2.json)
already snapshots and reads Identity+Attribution for 48/49 but lists only Attribution
writes. Implementing that write list literally omits required protocol effects.

## Current implementation amendment

Keep the original 57-operation prefix and adopted 58/59/60. No operation ID, external
signed payload, authority class, old record hash, or original replay surface is
renamed. The current semantic recipe is:

| Operation | Original name | Snapshot/read mask | Write mask | Immutable primary record |
| --- | --- | --- | --- | --- |
|47|revokeAttribution|`0x17`|`0x14`|Original repudiation record in Attribution|
|48|vetoAttributionRepudiation|`0x14`|`0x14`|Existing47 reference; actual canonical contest+cause auxiliary records in Identity|
|49|cancelAttributionRepudiation|`0x14`|`0x14`|Existing47 reference; no invented signed record|
|50|executeAttributionRepudiation|`0x15`|`0x10`|Existing47 reference|

Archive is the unchanged atomic append outside the seven-owner mask. The frozen
historical matrix remains historical evidence; this is its explicit implementation
amendment for these two necessary write effects. All original recipe names remain
`coordinateRevokeAttribution`, `coordinateVetoAttributionRepudiation`,
`coordinateCancelAttributionRepudiation`, `coordinateExecuteAttributionRepudiation`.

Operation 48 first terminates the actual Attribution row, then the fixed Identity
owner validates that exact terminal, still-current principal/history/generation,
and actual captured/current guardian set. It builds the existing canonical
`IDENTITY_CONTEST_RECORD_DOMAIN` record and kind 1 Cause with subject 0 and the 47
record as evidence. Existing pending rotation/estate/recovery/dormancy composition
runs unchanged. Original operation33 keeps its old empty supplemental-standing
branch and preimages. The new branch is restricted to 48 and does not impersonate
a successor, prior signer, living artist or governance actor.

The actual Contest and Cause are appended as 48 native receipts in order. Their
hashes retain their original Registry/Identity domains. The complete48 Archive
payload additionally commits the original staged row, captured/current guardian
proof, actor/reason/time and generated contest. Original58 dismissal consumes the
same canonical kind 1 facts; restoration cannot revive the terminal 47 row.

Operation 49 first records the original cancellation, then Identity validates the
exact terminal and current staging signer before recording activity. It advances
no signed nonce and creates no replacement authorization scheme. The original
activity state/replay delta and one Identity commit are atomic with Attribution
and Archive. Authenticated activity invalidates findings even though cancellation
has no fresh signed payload.

All storage additions are explicit namespaces in the existing fixed owners.
Current generation/head reads, single owner commits, original events, replay
surface names and complete rollback remain required. Historical operation 60
profiles remain closed to the new state until a separately complete typed import
profile exists. Lane proof or record presence is never authorization.

## Validation scope

The focused suite authors actual Artist/Archive/threshold-Safe positives,
authority/timing/history negatives and identical-call rollback retries. Typed
Core/governance boundaries and source-only ABI checks do not establish current
Executor or native runtime acceptance. See the
[caller guide](../artist-attribution-repudiation.md) for those explicit limits.
