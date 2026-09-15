# Entropy provider lifecycle operator plans

[PrepareEntropyProviderLifecycle.s.sol](../../script/current/PrepareEntropyProviderLifecycle.s.sol)
prepares saved governance stages for the current coordinator. Preparation is
read-only: it returns encoded plans, their independent journal hashes, and the
publication and scheduling CALL coordinates. It creates no signature, schedule,
broadcast or provider-state change.

This is a source/typechecked operator increment. The five new authored cases use
an actual governance foundation, Executor, coordinator and threshold Safe, with
the explicit Anvil development provider. They have not been executed as part of
this increment; a complete operator rehearsal remains pending.

## Prerequisites

Use the intended deployed coordinator and its actual authority Executor. The
script checks the lifecycle capability, rejects the invalid ERC165 interface and
checks that the coordinator's authority equals that Executor. The saved stage
also binds the current governance root/code/revision, Executor code, catalog
hash/revision, chain, timing, exact calls and manifest/reason commitments.

The catalog must already admit these exact deployed target/code/selector rows:

| Class | Target | Selector |
| --- | --- | --- |
| 1 | Executor | setTighteningCall(address,bytes4,bool) |
| 1 | Coordinator | activateEntropyProvider(address,string) |
| 0 | Coordinator | deprecateEntropyProvider(address,string) |
| 0 | Coordinator | revokeEntropyProvider(address,string) |

Catalog admission is a separate delayed stage with the original manifest
publication tail; see [the staged deployment guide](../../script/current/README.md).
This helper does not manufacture catalog entries, choose replacement providers,
change collection configuration or authorize fresh randomness.

## Preparation

Run this Forge script without `--broadcast`, against the intended Anvil or
Sepolia RPC. Retain its complete returned values in the operator journal before
any signing. The public preparation methods also expose the same typed results
to callers that supply arguments directly.

| Environment field | Meaning |
| --- | --- |
| STREAM_EXECUTOR | Actual authority Executor address |
| STREAM_ENTROPY_COORDINATOR | Intended lifecycle-capable coordinator address |
| STREAM_ENTROPY_LIFECYCLE_OPERATION | Operation number from the next table |
| STREAM_ENTROPY_PROVIDER | Provider address; read only for operations 3, 4 and 5 |
| STREAM_STAGE_NOT_BEFORE | uint64 timestamp with the live class delay plus submission headroom |
| STREAM_STAGE_EXPIRES_AFTER | uint64 timestamp strictly later than notBefore |
| STREAM_STAGE_REASON_HASH | Nonzero governance reason commitment |
| STREAM_STAGE_REASON_URI | Governance reason URI; also the exact provider-transition reason URI |
| STREAM_STAGE_MANIFEST_HASH | Nonzero retained manifest commitment |

| Operation | Returned stages |
| --- | --- |
| 0 | Deprecation classifier admission, then revocation classifier admission: two separate plans |
| 1 | Deprecation classifier admission only |
| 2 | Revocation classifier admission only |
| 3 | Provider activation or restoration to ACTIVE, class 1 |
| 4 | ACTIVE to DEPRECATED, class 0 |
| 5 | ACTIVE or DEPRECATED to INCIDENT_REVOKED, class 0 |

Every classifier plan contains exactly one class-1 Executor self-call to
`setTighteningCall(coordinator, selector, true)`. They must remain **two distinct
Executor actions**, with separate hashes and confirmed action IDs. Do not combine
them into one batch or append a provider transition. Each observes its own
classifier revision and binds the coordinator's live runtime code hash.
Operation 0 requires both classifiers to remain unadmitted. If only one is
outstanding, use operation 1 or 2; retain any completed plan as its original
attempt rather than preparing another admission for it.

Provider activation uses the canonical lifecycle planner and ordinary class-1
delay. Deprecation and revocation prepare only after the corresponding live
classifier is enabled for the exact coordinator code. Their scope, old/new state
hashes and class come from the coordinator's canonical transition read. They
retain the provider address and complete reason bytes in the actual call.
Configured class-0 delay is still read by the stage planner; the helper never
shortens an Executor delay.

## Publish, schedule and resume

For each returned PreparedStage, retain its schemaVersion 2, encodedPlan and
savedPlanHash independently. The returned publication has caller zero, meaning
permissionless publication, target Executor, value zero and exact publication
calldata. Publication does not schedule or approve the action.

The returned scheduling CALL has the **actual governance root as caller**. Submit
that target/value/data through the existing root wallet; for a Safe, use its
ordinary CALL transaction and threshold signatures. The script does not replace
the root with the operator, use delegatecall, or sign on a wallet's behalf.
Retain the action ID from the confirmed GovernanceActionScheduled receipt and
verify it against every field of the original saved plan. Never guess the global
Executor nonce or treat the plan hash as the action ID.

After its delay, the existing
[ExecuteSavedGovernanceStage.s.sol](../../script/current/ExecuteSavedGovernanceStage.s.sol)
accepts STREAM_STAGE_PLAN (the exact encodedPlan), STREAM_STAGE_SAVED_HASH (the
original journal hash), STREAM_STAGE_ACTION_ID (the matching receipt) and
STREAM_STAGE_EXECUTION_SENDER. Its existing execution workflow verifies the
receipt and plan, and an already executed exact action resumes as a no-op. This
new preparation script adds no execution or broadcasting path.

Read back each classifier's enabled/codeHash/revision and each provider's full
entropyProviderRecord, including state, runtime hash, revision, reasonHash and
lastActionId. Classifier admission alone does not activate a provider. Provider
restoration preserves the original provider enumeration and history; it does not
migrate a minted token's provider or redraw its result.

Root/catalog changes invalidate the applicable saved stage state. A provider or
classifier transition after preparation can invalidate its expected old value.
Retain failed or stale attempts, observe current state and prepare a separately
approved new plan; never repair a signed attempt by replacing its bytes/hash.
Submission headroom can expire before scheduling, even if execution would later
be allowed. Completed actions remain distinguishable from new attempts.
