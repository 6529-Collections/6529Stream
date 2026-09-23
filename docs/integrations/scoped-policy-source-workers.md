# Scoped policy source workers

The scoped reference and render-critical readers use five facade libraries and
seventeen fixed compiler-linked workers to fit the production bytecode limits.
Callers keep the original facade entrypoints and nominal types. The workers
divide decoding and validation work without introducing configurable dispatch.
The `V1` library suffix does not choose a publication family: the existing
family argument and its original default still select the supported profile.

Names below omit the common `StreamScopedPreservation` prefix. Every link names
the complete source file in the preservation domain.

## Facade responsibilities

| Facade | Responsibility and boundary |
| --- | --- |
| [PolicyReferenceRecordsV1](../../smart-contracts/domains/preservation/StreamScopedPreservationPolicyReferenceRecordsV1.sol) | Prepare and revalidate reference records; delegate retained payload, original publication bytes and interpretation-document checks. |
| [PolicyReferenceSourceReadsV1](../../smart-contracts/domains/preservation/StreamScopedPreservationPolicyReferenceSourceReadsV1.sol) | Assemble complete `SourceFacts` through dependency graph, snapshot, Router root and observation reads; retain the original source-hash preimage. |
| [PolicyRenderCriticalSourceReadsV1](../../smart-contracts/domains/preservation/StreamScopedPreservationPolicyRenderCriticalSourceReadsV1.sol) | Retain source-fact and dependency reads; delegate construction of the complete current `Context`. |
| [PolicyRenderCriticalTokenReadsV1](../../smart-contracts/domains/preservation/StreamScopedPreservationPolicyRenderCriticalTokenReadsV1.sol) | Retain token traversal entrypoints and the nominal `Original` return type; delegate original token and preservation-policy validation. |
| [PolicyRenderCriticalNativeReadsV1](../../smart-contracts/domains/preservation/StreamScopedPreservationPolicyRenderCriticalNativeReadsV1.sol) | Retain both `items` overloads and native append; delegate segment construction and typed storage mutation. |

## Fixed worker map

| Worker | Work it owns |
| --- | --- |
| [ReferencePayloadWorkerV1](../../smart-contracts/domains/preservation/StreamScopedPreservationReferencePayloadWorkerV1.sol) | Canonical retained reference payload decoding for the closed families. |
| [ReferenceRecordsHistoryV1](../../smart-contracts/domains/preservation/StreamScopedPreservationReferenceRecordsHistoryV1.sol) | Read and canonically decode the retained original publication; encode publication then receipt. |
| [ReferenceRecordsDefinitionsV1](../../smart-contracts/domains/preservation/StreamScopedPreservationReferenceRecordsDefinitionsV1.sol) | Validate the original seven interpretation documents in order. |
| [ReferenceGraphWorkerV1](../../smart-contracts/domains/preservation/StreamScopedPreservationReferenceGraphWorkerV1.sol) | Validate family, gas budgets, runtime pins, capabilities and reciprocal dependency bindings. |
| [ReferenceSnapshotWorkerV1](../../smart-contracts/domains/preservation/StreamScopedPreservationReferenceSnapshotWorkerV1.sol) | Run currentness, original-record and payload reads; return the untouched receipt, complete snapshot source and actual output-manifest record key. |
| [ReferenceRootWorkerV1](../../smart-contracts/domains/preservation/StreamScopedPreservationReferenceRootWorkerV1.sol) | Authenticate the Router root and binding; return all three fields: record hash, record and binding. |
| [ReferenceObservationWorkerV1](../../smart-contracts/domains/preservation/StreamScopedPreservationReferenceObservationWorkerV1.sol) | Enforce sample count before archive reads; validate runtime objects and return complete coverage and first/last samples. |
| [PolicyRenderCriticalCurrentReadsV1](../../smart-contracts/domains/preservation/StreamScopedPreservationPolicyRenderCriticalCurrentReadsV1.sol) | Construct the complete current scoped context, including WORK, RIGHTS and conservation joins. |
| [PolicyRenderCriticalOriginalReadsV1](../../smart-contracts/domains/preservation/StreamScopedPreservationPolicyRenderCriticalOriginalReadsV1.sol) | Validate original token identity, lifecycle, output and preservation-policy facts. |
| [PolicyNativeStageV1](../../smart-contracts/domains/preservation/StreamScopedPreservationPolicyNativeStageV1.sol) | Run the original `State.stage(state, id, 0)` currentness and stage check. |
| [PolicyNativeAppendV1](../../smart-contracts/domains/preservation/StreamScopedPreservationPolicyNativeAppendV1.sol) | Run stage validation first, obtain the next segment, check count consistency, append and advance the native cursor. |
| [PolicyNativeSegmentV1](../../smart-contracts/domains/preservation/StreamScopedPreservationPolicyNativeSegmentV1.sol) | Enforce segment bounds, authenticate sources and factory, derive total count and dispatch each ordered row. |
| [PolicyNativeSourceV1](../../smart-contracts/domains/preservation/StreamScopedPreservationPolicyNativeSourceV1.sol) | Authenticate complete `SourceFacts` before returning the consumed snapshot source, root record and binding. |
| [PolicyNativeReceiptRowsV1](../../smart-contracts/domains/preservation/StreamScopedPreservationPolicyNativeReceiptRowsV1.sol) | Construct complete original snapshot record and payload items. |
| [PolicyNativeFactRowsV1](../../smart-contracts/domains/preservation/StreamScopedPreservationPolicyNativeFactRowsV1.sol) | Construct complete snapshot-source and root items. |
| [PolicyNativePlanRowsV1](../../smart-contracts/domains/preservation/StreamScopedPreservationPolicyNativePlanRowsV1.sol) | Construct selection, content, output-manifest, output-row and entropy items. |
| [PolicyNativeRuntimeRowsV1](../../smart-contracts/domains/preservation/StreamScopedPreservationPolicyNativeRuntimeRowsV1.sol) | Construct the remaining ordered dependency, factory, runtime and policy-occurrence items. |

## Semantics to preserve when extending these paths

- Calls remain fixed linked library calls in the host's delegate context. Keep
  typed storage references, caller/host identity, runtime pins and dependency
  reciprocity; do not replace them with a caller-supplied target or raw slot.
- Preserve complete canonical decoding and validation before projecting fields.
  A smaller return tuple never authorizes skipping the rest of `SourceFacts`.
  Every row worker returns the complete inventory `Item`.
- Snapshot hashing normalizes its publication locally and deep-copies the
  receipt before clearing hash fields. The caller retains the original receipt
  and output record key. Reassign every returned root field at the facade.
- Keep family, scope, canonical-byte, count and external-read checks in their
  existing order. Source and item hash domains, encoding order, gas arguments
  and return-size bounds stay unchanged.
- Native append performs stage/currentness validation before segment reads.
  Keep its original default family, count check, witness hash, `State.append`,
  event emission, cursor increment and stage completion order. The facade's
  ABI has no segment-event declaration; the original State path emits it.
- Preserve the complete original facade ABI, including errors and nominal
  types. Added delegate frames and tuple copies require measured gas evidence;
  source equivalence does not establish gas equivalence.

## Regression and execution boundary

The focused group contains four suites with eight cases each:

- [Reference workers](../../test/unit/preservation/StreamScopedPreservationReferenceWorkersV1.t.sol): retained bytes, snapshot/root fields and document failure order.
- [Reference source](../../test/unit/preservation/StreamScopedPreservationReferenceSourceCapacity.t.sol): complete facts, graph/capture/observation boundaries and restoration.
- [Native workers](../../test/unit/preservation/StreamScopedPreservationPolicyNativeWorkers.t.sol): ordered full rows, segment boundaries and append stage refusals.
- [Current/token parity](../../test/unit/preservation/StreamScopedPreservationPolicyRenderCriticalWorkerParity.t.sol): original token parity and early current-context refusals.

At source `6f2beaf23c3fc8a0ed1b070f2308e960b861d271`, all 22 selected libraries
passed native runtime/full-init limits and original facade ABI comparisons;
the 32 cases were ABI/typechecked only. Current-context and append refusal cases
do not establish successful complete current-context or append execution.
Frozen helpers and typed external fixtures have explicit shared-source and
ceremony boundaries.

For execution, bind each selected host and its literal creations and linked
owners to the exact current source using the [scoped codegen workflow](../reference/tooling/scoped-codegen.md).
Retain separate compiler, deployment/linking, EVM and transaction-gas evidence.
A prior source's size capture does not admit the current execution graph or
establish a complete publication/finality ceremony.
