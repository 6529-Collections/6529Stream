# Artist unavailability for fresh entropy recovery

This explicit operation-23 profile connects the original Artist inability
finding, notice and authenticated activity epoch to the actual entropy recovery
intent. It is additive to [normal operation-17 consent](artist-entropy-recovery-join.md).
The two existing consent and Finality-finding APIs retain their original meaning.

## Caller sequence

1. Complete the existing entropy incident procedure and its block delay.
   `artistEntropyRecoveryIntent(RecoveryInput)` must successfully rebuild the
   actual FAILED token or registered-scope request, negative provider-result
   proof, frozen ordered policy, original inputs and eligible next provider.
2. Preserve the full returned `Intent`. Its hash is
   `keccak256(abi.encode(keccak256("6529STREAM_ENTROPY_ARTIST_RECOVERY_INTENT_V1"),
   chainId, coordinator, core, Intent))`. `Target` contains that coordinator,
   exact `RecoveryInput`, intent hash and a separate nonzero inability-evidence
   commitment. A hash alone does not prove the truth or availability of that
   external corroboration.
3. Set the original `FindingRequest.evidenceHash` to
   `keccak256(abi.encode(keccak256("6529STREAM_ARTIST_ENTROPY_UNAVAILABILITY_V1"),
   chainId, artistRegistry, core, Target, Intent, coordinatorCodeHash))`.
   The original finding reason is nonzero and is separately committed by the
   actual class-2 Arbiter governance action. Quote
   `entropyUnavailabilityFindingContext(request,target)` and execute
   `recordEntropyUnavailabilityFinding(request,target)` through the original
   selected governance authority with its exact scope/old/new context.
4. Read `entropyUnavailabilityFindingRecord(hash)`. Wait until its immutable
   `noticeEndsAt`: the default is 90 days with the original 30-day floor. This
   timestamp notice is additional to the already elapsed entropy block delay.
5. The current incident-role holder calls
   `requestFreshEntropyWithUnavailability(input,findingRecordHash)`. The host
   rebuilds its current intent and obtains the exact current Artist verification.
   The ordinary request submission, quote, escrow, excess pull credit, provider
   callback and replay rules then apply unchanged. A Safe uses CALL and the
   desired ETH value. The existing TypeScript consent helpers do not yet build
   this finding/governance sequence.

## Exact evidence and cancellation

The original ten-word finding hash is unchanged; its existing evidence word
now commits the complete explicit entropy manifest. The separate namespace
therefore cannot reinterpret or retarget an old finding. It stores the target,
full intent, runtime, captured activity epoch and original governance witness
hash in the actual Identity owner. Its `records`, `latest`, activity epoch,
replay cells, native receipt and atomic Archive append remain the ordinary
Artist stores. No external availability registry or invented Finality record
is involved. The new schema-1 `ArtistEntropyUnavailabilityContext` companion
contains chain/registry/finding and full admission; the existing finding event
retains its original signature and fields.

The intent includes actual collection/token/scope identity, old and proposed
request keys, prior/proposed journal heads, current/proposed content-state hashes,
complete next-policy hash, incident/provider evidence and recovery-reason hash.
The policy hash retains the selected provider/runtime/configuration/epoch,
original request inputs and next attempt. The fee quote remains live under the
unchanged submission rules. A changed host, runtime, journal, scope, reason,
evidence, provider policy or binding cannot reuse the original finding.

Successful authenticated current Artist-authority activity cancels unexecuted
use through the original epoch, even after notice and within the same block.
Failed authentication or later Archive failure does not cancel it. Passive
reads, governance finding recording and the incident-role caller's Safe transport
do not manufacture Artist activity. Both Finality and entropy findings use the
same per-association live-head gate. Neither profile can serve as the other, or
replace a live finding without authenticated cancellation or the original
target's actual terminal state. A later ordered request needs a new manifest,
new finding and full notice.

`freshRecoveryReceipt` retains its existing hash and fields; `artistRecordHash`
is the exact finding on this explicit path. `entropyUnavailabilityEvidence`
and the schema-1 event retain finding/intent/notice alongside it. The same
original consumed-evidence map prevents reuse. Provider/fee/request failure
rolls back the new evidence, old receipt/journal, consumption, escrow, counters
and Safe state atomically; a repaired identical retry remains possible.

## History import boundary

Current operation-60 hydration profiles do not import entropy finding supplemental
admissions or the shared live finding/activity state required to use them on a
successor registry. The unchanged ten-word record and native lane receipt alone
are insufficient. A complete later profile must import and authenticate the
original manifest/admission, binding and activity epoch, latest-head/terminal
dependencies and original replay guards together. Existing completeness gates
reject this unsupported history; this batch does not activate successor use or
claim complete imported unavailability history.

## Source and validation boundary

Ten authored cases use actual Artist owners/facade/Archive, entropy coordinator
and workers, and the threshold Safe. They cover original record/event/Archive
preimages, exact notice, token/scope identity, manifest/host drift, current
activity and failed-activity rollback, roles, cross-profile refusal, fresh
ordered notice, and identical Archive/provider retries with refund ownership.
Core token facts, role resolution, governance action execution facts and upstream
randomness are explicit typed boundaries. They do not prove an actual mint,
delayed Executor, full current deployment or transaction gas conformance.
This batch's authored cases and changed ABI are source evidence until executed;
selected codegen size measurements are reported separately. Earlier native
consent/recovery results do not count as execution of this new profile.
