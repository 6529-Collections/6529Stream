# Platform correction continuation

After an original operation53 correction has consumed its one permitted proposal,
a later REVOKED binding can obtain another generation through
`proposeArtistBindingAfterRevocation`. This is a fresh original operation1 class2
Attribution Arbiter action. Original operation2 acceptance remains independently
Artist-authorized. Supported cases include refusal or withdrawal of the original
correction, revocation after its acceptance, and repeated later continuations.

## Original records and new witness

Original `PW.State`, its twenty-word read ABI, operation53 approval hash, consumed
generation and accepted flag retain their historical meanings. The complete
original `StreamArtistPlatformState` source is unchanged. No approval is reset,
rearmed or reused. The declaration, claims and sustained contest remain visible.

Correction admission wraps its complete original terminal cause in
`abi.encode(PL.WITNESS, PL.Witness(originalCauseData, platformPins, priorStatus))`.
The literal tag is `6529STREAM_PLATFORM_BINDING_CONTINUATION_WITNESS_V1`.
Pins include the full declaration, contest state/claim/record and original
correction. Unrelated permissionless claim count/latest pointers are excluded,
as in original Platform governance contexts. The whole prior supplemental status,
original cause and proposed binding remain in the class2 old/new commitments and
immutable Binding approval. Original operation1 Archive detail retains that full
Approval. No registered schema, signing domain or operation number is replaced.

The actual Attribution owner checks original operation1 context before its fixed
closed worker validates local Platform state, revoked generation, full approval,
prior lineage and next generation. A new namespaced store retains immutable
lineage records. The original owner commit position remains; there is no extra
native occurrence. No arbitrary target or caller-selected state/commit plan is
accepted. Original operation2 appends a derivative acceptance record bound to its
exact original acceptance hash and lineage. Governance cannot set acceptance.
Late Archive failure rolls back original owners, the new namespace and Safe state.

## Historical reads and effective status

The actual Attribution owner exposes `IStreamArtistPlatformCorrectionLineage`:

- `platformCorrectionLineage(recordHash)`: immutable generation record, including
  previous lineage/binding and exact Binding approval/action.
- `platformCorrectionAcceptance(lineageRecord)`: immutable derivative receipt,
  original operation2 acceptance hash and time.
- `platformCorrectionStatus(collectionId)`: six fixed ABI words: original
  correction record, latest lineage record, generation, count, effective accepted
  boolean, latest derivative acceptance record hash.

Effective accepted-lineage becomes true when the original correction or a later
continuation is accepted. It persists through later revocation or a pending
replacement. It does not imply current Binding acceptance: current Attribution
state, Binding and every other admission prerequisite still apply independently.

The current `platformWorksAdmission` projection, display, sanction-source
selection and conservation floor consume that status. Original Platform state
and correction getters stay historical. An executed Platform declaration Finality
component remains that exact component; its original finality restriction is
unchanged. After accepted continuation, the conservation floor requires Artist
evidence, including checkable personhood; the old false flag is no exemption.

No facade selector is added. Existing `staticDisplayRead(bytes)` additionally
admits only `platformCorrectionStatus(uint256)`, returning inner192/outer256
canonical bytes. It uses the already pinned Coordinator and Attribution owner.
The owner getter reads declared fields directly with no DELEGATECALL. No target
roster, gas parameter, return cap or original thirteen result shapes change.
Consumers skip this read when no correction was consumed or original acceptance
is true. Missing/malformed supplemental status fails closed; display uses its
existing unavailable frame.

## Evidence and required continuation

Twelve authored owner recipes use original op53, actual seven Artist owners,
Coordinator, Archive, preservation coverage and threshold Safes. Core, metadata
getters and Executor action admission remain explicit inherited typed boundaries.
Oracles cover fresh authority, repeated history, literal hashes/events/Archive,
current admission/STATIC bytes, stale/foreign refusal, and counted late Archive
failure plus identical Safe retry. Two display and one conservation cases use
real consumers with typed Artist responses. Three small pure cases compare raw
six-word validation to independent typed ABI admission, including arbitrary words,
valid rows and single-field corruptions.

Exact source/type, selected sizes and scoped runtime belong to the handoff.
Authored owner/consumer cases are not native or full-current acceptance. Initial
oversized products remain evidence; compiler settings and limits are unchanged.

Original operation52 import now has a separate
[recovered ratification profile](artist-recovered-ratification-hydration.md), with
native/current migration acceptance recorded independently. Complete operation60
correction-history hydration remains next: every Binding correction approval/action replay, complete original and
supplemental Platform lineage/acceptance, and accepted-generation records must be
retained. Existing codecs are unchanged and cannot silently omit these histories.
Complete multiple-Artist/collection composition follows. Held collaborator,
global-freeze and replay refactors remain unrelated and untouched.
