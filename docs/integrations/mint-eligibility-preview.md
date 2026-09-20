# Mint eligibility preview

Call `IStreamMintPreview.canMint(batch, executor, gateData)` at the actual Manager
or fallback Manager. The additive ERC165 capability and function selector are
both `0x4466a6fe`. The permanent Manager interface is unchanged.

Any caller may inspect a prospective executor. The Manager still calls the gate
as itself, and the gate and counter keys receive that explicit executor. The
caller of this read does not become the prospective executor.

## Result

The result contains `allowed`, an error selector in `reason`, the current
`policyHash`, validated `gateHash`, requested `quantity`, and ordered counter
rows. Each row contains its counter, subject and value keys, current value,
increment, projected value, effective cap, allowed flag and resolution hash.
Rows keep canonical counter order and token order. A context counter contributes
one row. Up to the original 16 counters and ten tokens produce 160 rows.

Every row's projected value includes **all increments sharing its value key** in
the batch. For example, two entries for the same beneficiary, each incrementing
one, both report `current + 2`. Merkle rows use the validated leaf's cap and
resolution hash; valid different caps for the same key are checked independently.

| Result | Returned facts |
| --- | --- |
| Eligible under shared Manager/Ledger checks | `allowed=true`, zero reason, current policy, gate hash and all rows |
| Aggregate cap exceeded | `allowed=false`, `CounterCapExceeded` selector, current policy, gate hash and all rows |
| Projected value exceeds `uint64` | `CounterValueOverflow` selector, empty rows and zero policy/gate hashes |
| Phase, policy, consent, gate, replay or another evaluation fails | Failure selector, empty rows and zero policy/gate hashes |
| Evaluation runs out of its forwarded gas or cannot return a bounded result | `MintPreviewUnavailable` selector, empty rows and zero policy/gate hashes |

Quantity is retained on diagnostic failures. Overflow never returns a truncated
projected value. Zero caps retain their original uncapped semantics. A valid
predecessor request uses the original inclusive grace expiry and current consent,
gate, counter and executor requirements; the returned policy is the **current**
policy, not the request's predecessor hash.

The read checks Ledger writer/import readiness and Manager-scoped authorization
and nullifier replay. Those answers are independent of the read's caller.

## Execution boundary

This is a frontend/operator diagnostic, not mint authorization or an operation
identity. Every execution repeats its original checks. State can change after
the read. Core admission, payment, receiver callbacks and selected-path royalty
snapshot execution can still fail. Shared royalty-source checks are applied;
a configured snapshot phase still requires a prepared execution path.

Use `previewSingleStepMintOperation` from the eventual executor for the original
caller-sensitive operation transcript. `canMint` neither returns nor reserves an
operation root, token identity or nonce. It performs no writes and emits no logs.

The fixed worker makes one bounded static call to the same Manager selector.
That self-call evaluates directly and does not dispatch again. The caller keeps
100,000 gas for diagnostics, and successful output is bounded to 46,336 bytes.
Revert payloads copy at most four bytes. Gates retain their existing configured
and governed call limits and bounded output validation. As with any ABI call,
malformed outer calldata or insufficient gas to enter/decode the call can revert.

## Validation and remaining reads

See the [batch evidence](../../ops/MINT_PREVIEW_ACCEPTANCE.md) for source, size and
test scope. Focused typed-boundary evidence is separate from actual-current
Safe, full integration, fuzz and gas acceptance.

The other original Read API requirements `rawCounterValue`,
`remainingForCounter` and `resolveCounter` remain a subsequent implementation
slice. This preview does not complete those surfaces or enable the dynamic
resolver profiles excluded from v1.
