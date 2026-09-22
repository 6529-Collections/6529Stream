# Current-authority inventory capacity repair

The current-authority native, scoped native, and policy V2 inventory hosts use
fixed linked libraries for their existing lifecycle operations. Their public
interfaces, storage layouts, constructor checks, source profiles, receipt
preimages, and transaction limits are unchanged.

The lifecycle workers receive the original compiler-declared storage roots.
Library calls execute in the inventory host's context, retaining the original
caller, event emitter, and `address(this)` in plan and evidence hashes. The
policy root worker preserves the different guard orders of root authorization
and origin-runtime append. The scoped host reuses the existing fixed stage
guard; it does not introduce a new mutable dispatcher or authority.

The extraction retains complete current-source checks. Permissionless staging
still confers no publication, Artist, archive, or finality authority. Historical
completed evidence does not become current merely because it remains stored.
The stronger full-definition diagnostic still requests full bytes after the
same completion and currentness checks.

## Source and capacity evidence

The original three files at `68b76dd653f7ba4ab66a9513f069183f58064389` are
byte-identical to the affected sources in the retained `aa2` native capture.
That capture measured their runtime sizes at 42,414, 29,052, and 27,632 bytes.
The repair's selected native capture uses Solidity 0.8.19, via IR, optimizer
200 runs, Paris, and no CBOR metadata. All seven selected products fit:

| Product | Runtime bytes | Creation bytes |
| --- | ---: | ---: |
| CurrentAuthorityPolicyRenderCriticalInventoryV2 | 12,913 | 15,876 |
| CurrentAuthorityRenderCriticalInventory | 19,816 | 22,774 |
| CurrentAuthorityScopedRenderCriticalInventory | 19,464 | 22,428 |
| CurrentAuthorityPolicyInventoryLifecycleV2 | 23,267 | 23,303 |
| CurrentAuthorityPolicyInventoryRootStagesV2 | 16,591 | 16,625 |
| CurrentAuthorityInventoryLifecycle | 13,476 | 13,510 |
| CurrentAuthorityScopedInventoryLifecycle | 14,018 | 14,052 |

Each name in the table has the `Stream` prefix. The host constructors retain
their original fixed dependency tuples, adding 1,568 argument bytes to each
creation size. Those complete initcodes remain below 49,152 bytes. Every
library is constructor-free. The runtime limit remains 24,576 bytes.

The source comparison retains all three original ABIs, method identifiers,
recursive storage layouts, and constructors. Sixteen moved bodies match their
originals after only explicit storage-argument forwarding and helper names.
No existing shared guard, state, selection, or source reader was edited.

## Focused regression scope

`test/unit/preservation/StreamCurrentAuthorityInventoryLifecycle.t.sol` contains
eight focused cases, including one fuzz case. They call the real fixed workers
and original typed state/origin-seal code. Explicit doubles stand in for the
currentness, authority, source, and definition readers. Their replies bind the
actual delegate host, original caller, selector, and full typed argument frame.

The tests check independently constructed complete evidence and hash preimages,
host event coordinates, storage canaries, intent versus waiver receipts,
completion and stage error order, full-definition mode, scoped source drift,
and rollback of an origin seal when a later definition read fails. The policy
root and origin-runtime controls retain their distinct first guards.

These cases are authored and type-checked; execution is a separate acceptance
step. They do not prove actual authority migration, complete source admission,
the full inventory ceremony, or cold transaction capacity. The linked calls
add call overhead, which must be measured in the corresponding current-stack
integration campaign. The selected size capture establishes capacity only for
the seven named products, not the complete deployment graph.
