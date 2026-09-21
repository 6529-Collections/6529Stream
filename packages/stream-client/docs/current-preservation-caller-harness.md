# Preservation RPC and Safe caller driver

Import [current-preservation-caller-harness.mjs](../examples/current-preservation-caller-harness.mjs)
from a built local client package. It accepts an existing ethers-compatible
provider and reviewed deployment data, then dispatches to the original output,
snapshot, reference, inventory and archive clients. It creates no provider and
contains no signing keys, deployment defaults or automatic submissions.

Consent and root-publication interludes use the separate
[closed root transport](current-preservation-root-interlude.md). They are not
additional capture families in this driver.

## Supply admitted deployment data

The manifest has the following fields:

| Field | Required value |
| --- | --- |
| `schemaVersion` | `1` |
| `chainId` | Positive `bigint` for the actual chain |
| `sourceCommit`, `clientCommit` | Exact lowercase 40-character Git commit IDs |
| `deployments` | Named entries with `family` and the original client's complete `deployment` object |
| `safes` | Reviewed Safe address/runtime hash, version `1.3.0` or `1.4.1`, and singleton address/runtime hash; an empty array permits direct calls |

The closed family names are `output`, `snapshot`, `reference`, `inventory` and
`archive`. Each deployment retains its own client type and source qualification:
[output](current-token-preservation-output-v2.md),
[snapshot](current-token-preservation-snapshot-v2.md),
[reference](current-token-preservation-reference-v2.md),
[inventory](current-authority-preservation-inventory-v1.md) and
[archive](current-authority-preservation-archive-v1.md).
The manifest records an admission decision supplied by the caller. It does not
prove compiler, linked runtime or deployment provenance; captures explicitly
report `deploymentProvenanceIndependentlyVerified: false`.

## Capture and simulate

A scenario supplies `deploymentId`, the actual `caller`, the original family's
`request`, an explicit numeric `blockTag`, and a positive `bigint` `gasLimit`.
Inventory and archive scenarios also supply the original authenticated
`segments` locators. The driver does not manufacture plans, grants, objects,
receipts or coverage proofs.

```js
import { createPreservationCallerHarness } from
  "../examples/current-preservation-caller-harness.mjs";

const driver = createPreservationCallerHarness({ provider, manifest });
const plan = await driver.captureScenario(scenario);
await driver.simulateScenario(plan.id, { blockTag: preflightBlock });
```

Captures and simulations use fixed blocks and the original family clients.
Review their results before arranging any signatures. A Safe scenario uses the
Safe address as the captured caller.

## Retain one exact envelope

For a direct call, use `saveSignedEnvelope(plan.id, { execution: "direct" })`.
For a Safe call, supply `execution: "safe"`, `outerSender`, the complete signed
`execTransaction` calldata in `data`, the Safe `nonce`, and the independently
reviewed `expectedSafeTxHash`.

The driver checks the exact inner ordinary CALL, original Safe hash getter,
local Safe typed-data hash, proxy/singleton runtime pins and version. It saves
one immutable envelope per captured plan. A saved Safe envelope contains Safe
signatures; it is not a signed outer Ethereum transaction.

```js
const saved = await driver.saveSignedEnvelope(plan.id, reviewedEnvelope);
const simulation = await driver.simulateSavedEnvelope(saved.id, {
  blockTag: preflightBlock, gasLimit: outerGasLimit,
});
```

For Safe simulation, inspect both `originalCallSucceeded` and
`safeInnerSucceeded`: the outer call can return successfully with an inner
`false` result. An `eth_call` simulation persists no state changes.

## Submit explicitly and reconcile

Only `submitSavedEnvelope` can submit, through the caller's explicit transport:

```js
const attempt = await driver.submitSavedEnvelope(saved.id, {
  sendTransaction: tx => reviewedSigner.sendTransaction(tx),
}, { blockTag: preflightBlock, gasLimit: outerGasLimit });
// Wait for mining outside the driver before inspection.
const result = await driver.inspectSubmission(saved.id, attempt.transactionHash);
```

Optional submission fields are outer `nonce`, `gasPrice`, `maxFeePerGas` and
`maxPriorityFeePerGas`. These cannot replace the saved target, calldata or value.
Inspection requires a mined block later than capture, authenticates transaction
and log identity, reads the preceding and mined blocks, and invokes the original
family receipt reconciler on success.

A Safe outer revert with an unchanged Safe nonce can permit an explicit retry
of the same saved calldata and signatures using a new outer transaction. A
successful outer transaction with `ExecutionFailure` consumes the Safe nonce
and cannot retry those old signatures. The driver never retries automatically.
An all-zero gas envelope and reverted receipt alone do not prove `GS013` or
application rollback; those result fields remain explicitly unproven.

## Evidence and limits

`preservationHarnessJSON` and `parsePreservationHarnessJSON` preserve public
bigint evidence. They do not restore a driver's in-memory plans or envelopes;
keep that driver instance for the campaign. Provider and signer objects, raw
errors and connection metadata are excluded. Transport failures expose only a
bounded code, revert data and the specific recognized `GS013` reason.

The focused tests use compiler-backed mock RPC fixtures. They check dispatch,
fixed-block reads, exact envelopes, failure classification and original client
reconciliation. Actual deployed Safe execution, real signatures, state rollback,
linked runtime provenance and transaction capacity require the separate admitted
runtime campaign.
