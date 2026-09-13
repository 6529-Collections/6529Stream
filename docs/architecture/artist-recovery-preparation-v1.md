# Identity recovery preparation profile v1

This pre-genesis auxiliary profile supports the first counted, guarded
initial-living identity recovery. It supplements canonical operations34 and35;
it does not renumber or extend their permanent semantic and signature preimages.

| Coordinate | Exact rule |
| --- | --- |
| Operation | `uint16(65534)` |
| Configuration profile tag | `keccak256("6529STREAM_ARTIST_RECOVERY_PREPARATION_PROFILE_V1")` |
| State owner | The fixed actual Identity owner, constructor domain `keccak256("domain:identity_authority")` |
| Admission | Complete exact stored SCHEDULED class2 batch, bound/sealed Executor, full remaining terminal minimum delay, one exact zero-value recovery call to the fixed facade |
| Actor | The actual permissionless indexer captured by the facade |
| Semantic primary | None: `bytes32(0)` |
| Owner revision | One successful increment |
| Record delta | `keccak256(abi.encode(bytes32(0)))` |
| Sequence and chain tip | Unchanged |
| Signature and nonce | Stored acceptance commitment only; no consumption |
| Atomicity | Owner association, replay, revision and final Archive append all succeed or all revert |

The association contains, in order, `associationHash`, artist ID, request hash,
complete acceptance hash, scheduled context hash, the full action witness, the
full original guardian record, actual indexer, preparation timestamp and successful
owner revision. The action witness contains action ID, full calls hash, call
index, exact calldata hash, immutable Executor address and runtime hash, original
proposer, registration-time role mutation hash and revision, `notBefore`, expiry,
actual minimum delay and action manifest hash. Integer widths and tuple order are
defined in `StreamArtistRecoveryActionTypes`.

Compute the association hash with its `associationHash` field zero, using
`abi.encode` of the preparation domain, deployment chain, registry, actual owner,
Coordinator, Archive, prior pending action ID and that complete association.
The preparation domain is
`keccak256("6529STREAM_ARTIST_RECOVERY_PREPARATION_V1")`. Store the resulting hash
once, with the immutable association, and select its action as that artist's
pending action. The replay scope is that actual action ID under
`identity_authority.replay.recovery_preparation` in existing owner replay V2.

The state commitment uses the existing owner fourteen-word transition preimage.
Its action component wraps operation65534, actual actor, and the hash of the
operation, completed association and prior action. Its next-state component binds
the completed association and selected pending action. The replay component is
the consumed owner replay key. This explicit zero-record profile is different
from the packet's twenty-word record-delta encoding; neither earlier owner
history nor this auxiliary commit is relabeled as that other encoding.

Operation34 similarly stores no semantic primary. It binds artist, exact pending
action, direct saved guardian and nonzero reason to a permanent local veto,
consumes the action-keyed `identity_authority.replay.recovery_veto_key`, advances
one owner revision and leaves sequence/tip unchanged. Its original
`ArtistIdentityRecoveryVetoed(uint16,bytes32,address,bytes32,bytes32)` event is
emitted by the Identity host before the atomic Archive append. The event uses
schema2, indexed artist and vetoer, reason, then governance action ID.

The preparation event uses schema1 and reports indexed artist/action, association
hash, original guardian record, actual indexer and actual preparation time. These
auxiliary receipts do not create or replace the permanent operation35 primary
and secondary receipts. Successful guarded recovery still uses the original
RotationAcceptance and unchanged recovery/supersession semantic hashes.

The exact selected guardian record, admission count and pre-transition cause
determine the scheduled context before preparation. No owner revision or pending
association enters that context. This avoids a scheduling cycle while the
separate association commits the owner revision and frozen guardian identity.
Count1 can include an empty first set; such a set supplies no eligible local
guardian. Fresh counted deployments are required: this profile does not infer
historical admission counts for an older deployment.
