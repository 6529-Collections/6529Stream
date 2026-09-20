# Joined Artist facade capacity repair

This source-preserving repair starts at `5310fc7b`, which combines the multiple
record hydration and recovery adjudication interfaces. It changes fixed transport
boundaries, not the accepted authority or history profiles.

The Registry routes four existing tuple getters through its existing auxiliary
encoder. The Coordinator's V2 recovery, collaborator identity acceptance,
guardian-set and rotation-stage entries decode original calldata in fixed linked
workers. Each original `operation` modifier still surrounds the ordinary call and
return. Identity keeps its original admission and commit statements around
operations 55–57, and its original caller check before history synchronization;
the existing history worker decodes their unchanged calldata.

Identity's new typed read overload takes the fifteen declared storage roots and
one owner-context/calldata tuple. It handles adjudication and two ordinary reads,
then calls the preserved original read overload. No storage slot is assigned by
the new transport. Its original baseline and finding hydration exports share the
existing fixed export dispatcher, after the same host timing check. The legacy
export/import bodies, original domains, replay cells, static identity paths and
Owner checks are unchanged. Terminal raw returns occur only in existing view
forwarders.

The three host ABIs are unchanged (Registry 340 entries, Coordinator 111,
Identity 240). Compiler-derived recursive storage layouts are identical to the
base. All old ABI entries in the nine changed products are retained. A 989-source
typecheck includes the existing multiple-record hydration, adjudication, history
import, onboarding and entropy-finding suites; those suites were not executed for
this handoff.

The selected compile uses the exact joined baseline settings: Solidity 0.8.19,
via IR, optimizer 200, Paris, and that capture's default metadata settings. The
final selected result and source hashes are retained in the local handoff. Source
and size evidence do not establish current-stack runtime acceptance. In
particular, added fixed worker calls need the existing governed read budgets and
actual Safe/Archive flows checked by the integrated runtime cohort. No cap, limit,
constructor, held patch or deployment configuration was changed.

The later current-notice recovery change adds a Dormancy root to the adjudication
read. When composed, that argument belongs in this fixed read overload, using its
already supplied `_dormancy` root; restoring the old host reader would discard this
repair. The final composed source requires its own selected size check.
