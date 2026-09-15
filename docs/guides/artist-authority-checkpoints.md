# Artist authority checkpoint producers

`IStreamArtistAuthorityCheckpoint` is a fixed-owner read capability. Every actual
owner constructor initializes the new schema. It exposes the owner's original
snapshot, a unique replay-key inventory with current actual cells, and the
Identity owner's typed nonce-index/prefix inventories. It does not itself grant
authority, install imported state, or authorize a successor write.

All 29 actual replay assignments append or update the auxiliary inventory after
the original write. This includes consumed digests, explicit revocations,
governance actions, mutable payout-chain heads and the original terminal replay
cells. Each key has one inventory position even when its actual chain cell
changes. Its update root changes atomically with each mutation. Original replay
keys, cells, owner roots, record hashes, events and authority checks retain their
recipes. The additional state uses its own fixed namespace.

All six production nonce consumers call the original consumption mechanics and
then inventory the actual leaf prefix. The original `Index` layout and original
availability delta are unchanged. Exported kinds select exactly five declared
trees: Artist identity, delegate lane, collaborator account, rotation acceptance
lane and estate acceptance lane. The read returns the actual leaf word and its
31 ancestors, plus exhaustion, from that tree. It accepts no raw storage slot.
No supplied list is allowed to certify that omitted guards are absent.

The schema marks this implementation's producer completeness. An older deployed
binary without the capability cannot fabricate this inventory retrospectively.
A migration must authenticate the actual predecessor and its fixed owners,
their runtime/immutable bindings and schema, then require the predecessor's
one-way op57 cutover latch before pinning the checkpoint. The pointer move alone
fixes ordinary record lanes, but op57 itself still changes its original replay
cell and owner revision. Checkpoint counts and full headers must remain exact
through every import page and completion.

The importer remains a separate implementation step: verify every inventory
entry and typed authority/association dependency, preserve original record and
signature domains, hydrate complete state, then mark the lane usable. Original
op56 has an Identity-only semantic owner mask; it must not silently become a
multi-owner hydration write. Until the separately specified completion recipe
and consumers are present, the existing imported-authority gate remains closed.
This producer package does not claim AA-IMPORT conformance or real successor
forward-write acceptance.

Four authored tests use actual Artist/Safe/owners/Archive with typed unit Core
and governance. They check sparse maximum-value nonce/revocation guards, mutable
replay cells at stable indices, independent delegate/rotation nonce namespaces,
and whole-checkpoint rollback followed by byte-identical Safe retry. ABI/type
checks are source evidence; native execution, linked product size and current
graph import validation remain pending.

## Additive complete baseline

[Operation60 authority hydration](artist-authority-hydration.md) now supplies the
complete original living/no-collaborator baseline and forward-lane consumer.
The original proof/checkpoint-only behavior above remains the unhydrated gate.
Other typed history profiles remain implementation obligations; native and
current-stack validation are separate from this source addition.
