# Current Artist contract capacity

The current compromise, notice-recovery, identity-recovery mutation and Onboarding
Coordinator products exceeded the deployment limit in the actual current-source
capture. Fixed Solidity libraries now hold their existing read or forwarding
bodies. The original host contracts retain their ABI entries, selectors and
recursive storage layout; none of the EIP-170/EIP-3860 or governed gas caps changes.

## Preserved boundaries

`StreamArtistCurrentCompromiseReads` keeps its original five entry signatures and
nominal Facts/Environment types. Its fixed kernel receives each original argument
and the same live/notice flags. The estate-compromise helper carries the original
pending-estate read unchanged. Notice recovery keeps its original entry signatures
and Facts type, delegates the cause body, and delegates only the existing recovered
cancellation body and replay helper from that cause worker.

Identity recovery delegates its existing guardian and appeal-witness read bodies
with the same storage references. The original mutation ordering remains in the
host. The Coordinator keeps its caller, reentrancy, chain, sixteen runtime-pin,
history and operation-lock checks in their original positions. Its finality reader
retains the exact route and fallback branches; sanction confirmation retains both
original gas-parameter reads in the anchored branch. Sanction recording retains
the original typed calldata and host pin read. A typed helper receives the same
Pins, actor, Request and Authorization values, constructs the original economic
context from the supplied storage reference and immutables, and calls the existing
sanction operation.

The route read uses a fixed library to return the same ten static ABI words. Its
host function is now external with a calldata return annotation and forwards the
encoded result; the public ABI is unchanged, and there are no remaining internal
host calls or inheriting Coordinator contracts. Formerly private read bodies that
became library entries are public library functions; the compiler's fixed links
preserve the original delegatecall storage, caller and address context. The added
call/encoding boundaries change gas costs and do not add mutable targets, storage,
selectors on the host, or independent mutation authority. Explicit error
declarations retain the original errors that now bubble through linked helpers.

## Selected evidence

Solidity 0.8.19, optimizer 200, via-IR, Paris and metadata disabled match the retained
capture settings. The twelve final selected product measurements are:

| Product (`StreamArtist` prefix) | Runtime bytes | Creation bytes |
| --- | ---: | ---: |
| OnboardingCoordinator | 24,576 | 30,171 |
| CoordinatorFinalityReads | 1,934 | 1,966 |
| CoordinatorSanctionConfirmation | 1,897 | 1,931 |
| CoordinatorSanctionRecord | 2,654 | 2,688 |
| CurrentCompromiseReads | 3,095 | 3,127 |
| CurrentCompromiseReadsKernel | 24,198 | 24,231 |
| CurrentEstateCompromiseReads | 5,764 | 5,796 |
| CurrentNoticeRecoveryReads | 19,198 | 19,230 |
| CurrentNoticeCauseReads | 19,385 | 19,417 |
| CurrentNoticeCancellationReads | 13,071 | 13,103 |
| IdentityRecoveryMutation | 23,765 | 23,800 |
| IdentityRecoveryPreparationReads | 3,671 | 3,703 |

Coordinator is exactly at the runtime limit and has zero headroom. The selected
captures are retained across four checkpoints; the final source bridge records
each product and its input. The notice host capture precedes removal of an
unneeded duplicate error declaration, with no executable-body change. Other
transitive source changes are fixed linked implementations with unchanged typed
interfaces. Failed intermediate captures remain diagnostic evidence.

The final 1,353-source ABI/type check is clean. All 1,546 existing contract ABIs,
including error multiplicity, method identifiers and recursive storage layout,
match the pre-repair checkpoint. Independent source review covers the moved
bodies, argument forwarding, validation order and return transport. No new
behavioral test is authored for these exact-body extractions. Native linked
deployment, execution, transaction-gas and full-current acceptance remain pending;
these source and selected-size checks do not establish those results.
