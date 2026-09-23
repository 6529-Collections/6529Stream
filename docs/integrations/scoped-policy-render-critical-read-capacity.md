# Scoped policy render-critical read capacity

The scoped V2 inventory uses fixed linked workers for its complete native-item,
historical root-authorization and current-source reads. This reduces code in
the original libraries while preserving their public entrypoints and storage
layout. It does not change the original 24,576-byte runtime or 49,152-byte
complete-initcode limits.

| Original entrypoint | Fixed worker | Preserved result |
| --- | --- | --- |
| `NativeReadsV2.items` | `NativeItemsV2.items` | Every original item field, order and complete row count |
| `RootAuthorizationV2.contentItem` | `RootAuthorizationReadV2.contentItem` | Complete archived op17 evidence item and original provenance hash |
| `SourceReadsV2.current` | `CurrentReadsV2.current` | Entire original context, including dynamic policy arrays, descriptions and conservation |

All names above share the `StreamScopedPolicyRenderCritical` prefix. The old
append functions keep their stage checks, storage updates, event emission and
rollback behavior. The linked library calls execute in the original host's
context. They do not select a worker supplied by the caller or create mutable
dependency bindings.

Native item production retains the complete original snapshot and payload,
23-word root binding, source-factory tuple, all dependency runtimes and every
ordered coordinator policy. Segments retain their original cursor, maximum and
total-count rules. The output-manifest hash inventory remains separate from
per-token complete-byte observations.

Root authorization retains its exact original record and historical aggregate
preimages, operation-17 envelope, saved Artist consent and immutable archive
bytes. The original library's public struct declarations remain available for
source compatibility; the worker uses the same complete wire layouts. A later
aggregate, current nonce, changed actor or substituted archive cannot replace
the original authorization.

The current-source worker keeps the original validation and external-read order.
Its private dependency-construction bodies preserve the original roster and gas
budgets without calling back into the original source library. Its full return
value carries every memory field into the existing consumer. No live eligibility,
scope, frozen-policy, membership or conservation check is omitted or cached.

Focused regressions cover native segment bounds and the factory/policy boundary,
the full root-authorization provenance, and complete current-context return and
refusal behavior. Source/body and ABI correspondence checks supplement those
cases. Type checking or a selected native size result does not establish their
EVM execution, complete inventory construction, added-call gas conformance or
full finality ceremony acceptance. Those remain part of the coordinated current
stack validation described in [tooling](../tooling.md).
