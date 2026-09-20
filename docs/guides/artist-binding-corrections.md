# Governed Artist binding corrections

`IStreamArtistBindingCorrection.proposeArtistBindingAfterRevocation` is an additive
entry for original Artist operation1. It implements AA-STATE5 and AA-BINDING5/6:
a new generation after REVOKED requires a fresh class2 Attribution Arbiter action.
The ordinary `proposeArtistBinding` entry now admits only the first generation.
Original binding hashes, identity allocation, operation1 receipts and operation2
acceptance signatures retain their original domains.

## Caller recipe

1. Read the actual current Binding and its Attribution state/generation. The
   state must be REVOKED, with no open dispute. Assemble the complete new original
   `BindingProposal`, identity document and display name.
2. For an executed voluntary repudiation, supply its exact original record hash.
   The producer reads the complete stored record and phase4 terminal. For pending
   refusal/withdrawal or class2 arbiter revocation, supply zero. There is no latest
   repudiation pointer, scan or overloaded reason/document field.
3. Read `StreamArtistBindingCorrectionAdmission.context` against the selected
   suite. The scope binds chain, Registry, Core, Manager, collection and revoked
   generation. The old value includes the complete previous Binding and canonical
   terminal cause. The new value includes every proposal/document/name byte and,
   for a new Artist, the original next registration nonce and derived Artist ID.
4. Register the new facade selector in the actual governance action catalog with
   class2 and its exact target runtime/deployment identity. Schedule the exact
   calldata and returned scope/old/new commitments through the canonical Executor.
   The proposer must retain the Attribution Arbiter role at execution; the Executor
   must also hold the original Artist registry-admin role. Ordinary sealed catalog,
   delay and reason checks apply. A proposal or allocator change requires a new
   action; a staged action does not itself authorize writes.
5. Execute the same staged action after its delay. This creates a PENDING next
   generation. The Artist must independently perform original operation2 acceptance
   for that exact generation/hash, using the original next authorization nonce.
   Governance never signs or accepts on the Artist's behalf.

The facade capability has only the additive proposal selector. The Coordinator
has the corresponding actor-prefixed entry. Original interfaces remain intact.
The binding owner additionally exposes `bindingCorrection(bindingHash)`, returning
the exact immutable `Approval` and its record hash. Unknown keys return zero data.
New fixed codecs are closed to these declared selectors; they accept no arbitrary
call target or replay plan. Original Owner checks, proposal/action replay writes,
commit, native receipt and return ordering remain on the host.

## Evidence and state

An `Approval` records the previous full Binding, a closed cause1..4, exact cause
record/documentary tuple, proposed bytes hash, allocated Artist ID/nonce, original
GovernanceWitness and execution time. Causes1/2 retain the original pending
terminal and dispute Head; cause3 retains full original Repudiation Record and
Terminal; cause4 retains full original opening and class2 Resolution. The record
domain is `6529STREAM_ARTIST_BINDING_CORRECTION_RECORD_V1`, followed by chain,
Registry, Core, Manager, collection, new binding hash and the complete Approval.

The owner appends a compiler-declared correction map after its original storage
prefix. It consumes the original proposal key, then the new action replay key,
stores the approval and makes one original op1 commit/native occurrence. The
`ArtistBindingCorrectionApproved` event binds old/new binding, cause and action.
The subsequent original proposal event and all earlier records remain unchanged.

The original Archive outer envelope/version and op1 evidence ID remain unchanged.
Corrective detail uses the explicit tag
`6529STREAM_ARTIST_BINDING_CORRECTION_EVIDENCE_V1` and detail version1, then
collection, full proposal, document, display name, reuse flag, original role hash
and revision, repudiation witness, Context and full Approval. It is not the old
untagged first-proposal detail. A late Archive failure rolls back all seven owner
effects, approval/action replay and the enclosing Safe/action state.

## Evidence scope and required continuation

The focused unit recipes use actual Artist owners/Coordinator/Archive and threshold
Safe, with typed Core/Executor/role boundaries. Separate current recipes author
actual Core/Manager/Artist, sealed delayed governance/catalog and governor Safe
flows. Source/type/selected-product results are recorded in the task handoff;
authored tests do not establish native execution or full-stack acceptance.

Historical operation60 codecs remain unchanged. New correction receipts introduce
an approval map and extra replay guard that current historical profiles cannot
silently omit: their complete journal/guard checks refuse these histories. The
next required batch must import the exact correction evidence and complete later
accepted generations. Older pending-generation fixture captures remain evidence
only for their original source; future fixture reclaims must use this governed
ingress and the forthcoming complete correction-history codec.

The original PLATFORM_WORKS consumed-correction guard is preserved. The additive
[Platform continuation](artist-platform-continuation.md) recipe now appends fresh
class2-approved lineage after a consumed correction is revoked, including an
original refused/withdrawn correction. It never resets the guard or reuses op53.
Complete history import remains required alongside accepted-generation hydration,
followed by multiple Artist/collection composition. Held collaborator,
global-freeze and replay refactors remain unrelated and unchanged.
