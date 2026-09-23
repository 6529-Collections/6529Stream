# Consent and root-publication Safe transport

The [packet adapter](../examples/current-preservation-root-interlude-packet.mjs)
and [transport](../examples/current-preservation-root-interlude-transport.mjs)
connect the original unsigned root-publication packets to explicit Safe
submission. They complement the separate
[five-family preservation driver](current-preservation-caller-harness.md).

Only these three inner calls are accepted:

| Phase | Target | Original method |
| --- | --- | --- |
| Consent | Artist Registry | `recordContentConsent` |
| Collection root | Metadata Router | `publishVerifiedPreservationPolicyContentRoot` |
| Scoped root | Metadata Router | `publishScopedPreservationPolicyContentRootPublication` |

Every inner transaction is an ordinary zero-value CALL. The route is the
already-granted normal class-1 principal through its Artist Safe. TOKEN,
RELEASE and SEASON use scoped publication; VIEW is outside this adapter.

## Admit the exact source and packet

The adapter pins caller source `61d0efc5c88db67126a1af2e3ccaa6d1ddecb41d`,
source report `5537434a6b43233bcc2c6f577659c18a045db0144c8dbb2c8d74d9f3ef82f5df`
and the original packet tool. The
[source witness](../test/fixtures/current-preservation-root-interlude-source.json)
retains their exact bytes, 51 source files and 35 selected ordinary ABI entries.
Those entries match ABI157; their selected declaration files also match caller
source61d0. This establishes selected source/ABI correspondence, not a complete
linked runtime or deployment-state admission.

A repaired or changed source requires a reviewed source/ABI rejoin and an
updated adapter profile. Changing a manifest string cannot admit a different
source. Actual runtime, state import, Safe owner and prerequisite evidence
remain required before a real campaign.

The manifest has these fields:

| Fields | Meaning |
| --- | --- |
| `schemaVersion`, `chainId` | Schema `1` and the actual chain ID. |
| `sourceCommit`, `sourceReportSha256`, `toolSha256`, `castSha256` | Exact pinned source/tool identities. |
| `bootstrapManifestSha256`, `clientPrerequisitePacketSha256` | Separately admitted bootstrap and completed prerequisite evidence. |
| `admissionHash` | Canonical SHA-256 of the complete reviewed packet admission. |
| `registry`, `router` | Each original address and `codeHash`. |
| `artistSafe` | Safe address, runtime hash, version `1.3.0` or `1.4.1`, and singleton address/runtime hash. |

SHA-256 fields use 64 lowercase hex characters without `0x`. Ethereum hashes
and addresses retain `0x`. The admission hash binds the remaining original
roles, pointers, suite, Artist identity and grant expectations. Matching a
declared tool hash does not prove that the tool actually produced the packet.
The adapter reports supplied provenance as unverified independently.

Read the original packet file as unchanged UTF-8 text. Pass its independently
reviewed SHA-256 as `expectedPacketSha256`. The parser retains integer literals
as `bigint`, including values beyond JavaScript's safe integer range. It
requires the producer's exact sorted-key canonical JSON and final newline.
Do not first parse or rewrite the document with ordinary `JSON.parse`.

## Prepare, sign and submit separately

```js
import { createPreservationRootInterludeTransport } from
  "../examples/current-preservation-root-interlude-transport.mjs";

const transport = createPreservationRootInterludeTransport({ provider, manifest });
const packet = await transport.capturePacket(packetText, { expectedPacketSha256 });
// Arrange owner signatures separately for packet.packet.transaction.
const saved = await transport.saveSignedEnvelope(packet.id, {
  outerSender,
  data: signedExecTransactionCalldata,
  nonce: packet.packet.transaction.nonce,
  expectedSafeTxHash: packet.packet.expectedSafeTxHash,
});
const simulation = await transport.simulateSavedEnvelope(saved.id, {
  blockTag: preflightBlock, gasLimit: outerGasLimit,
});
```

The adapter preserves all ten Safe transaction fields: target, value, calldata,
operation, `safeTxGas`, `baseGas`, `gasPrice`, `gasToken`, `refundReceiver` and
nonce. Payment fields remain zero. It verifies the local Safe typed-data hash
against the packet and the original Safe getter. The supplied signed bytes must
encode exactly those fields in a direct `execTransaction` call.

Owner signatures remain external. Nonempty signature bytes and a matching
envelope do not prove their validity, ordering or threshold satisfaction; the
original Safe decides those during execution. The outer sender, gas budget,
transaction nonce and fee fields are separate from the signed Safe fields.

Capture checks the actual chain, all admitted runtime pins, Safe singleton,
version, owners, threshold, nonce and original transaction hash. Preflight
rechecks the saved block and current Safe/runtime facts. The producer uses
EIP-1898 block-hash reads; this Provider-compatible transport uses explicit
numeric blocks with block-hash readback before and after observations. Neither
mechanism reserves protocol state until inclusion.

Inspect both `outerCallSucceeded` and `safeInnerSucceeded` after simulation.
A successful outer call can return `false` for its inner execution. Simulation
persists no state. Submission requires an explicit callback:

```js
const attempt = await transport.submitSavedEnvelope(saved.id, {
  sendTransaction: tx => reviewedSigner.sendTransaction(tx),
}, { blockTag: preflightBlock, gasLimit: outerGasLimit });
// Wait for mining separately.
const observed = await transport.inspectSubmission(saved.id, attempt.transactionHash);
```

The transport creates no provider, signer, key, server or default deployment.
Captured packets and saved envelopes belong to one adapter instance; serialized
records do not restore its internal maps after restart.

## Verify the original protocol records

Transport inspection authenticates the exact transaction and receipt, preceding
and mined Safe nonces, and the unique matching Safe success/failure event.
Consent application logs come from the original Consent owner; root logs come
from the Router. Those emitter logs must precede Safe success. Unrelated later
guard logs may remain.

The result always retains `originalProtocolReceiptVerified: false` and
`priorConsentReceiptIndependentlyVerified: false`. Safe success is not a substitute
for the original producer's `prepare-root` consent verification or `verify-root`
record/binding verification. A root packet carries prior hashes and coordinates;
it does not embed an independently authenticated consent history.

Keep the original sequence:

- Collection: completed output → consent → root → snapshot.
- Scoped: completed output → snapshot → consent → root.

Read a fresh original preview after earlier root transitions. Do not reuse the
Scenario's initial empty legacy-family value. The consent and root transactions
are separate: a failed root publication leaves the earlier consent recorded.

An outer Safe revert with unchanged Safe nonce can permit attempting the exact
saved Safe bytes again in a new outer transaction. `ExecutionFailure` consumes
the Safe nonce. Retry eligibility is an observation, not a successful retry or
proof of `GS013`, application rollback or an intra-block trace. The adapter
never retries automatically.

## Limits and evidence

Canonical packet input is capped at 4 MiB, nesting at 64 levels, traversed values
at 65,536 and each array/object at 4,096 entries. Individual strings are bounded;
the original publication URI remains limited to 2,048 UTF-8 bytes. The transport
also bounds calldata, signature bytes, runtime reads, receipt logs and outer gas.
These are client resource limits, not protocol capacity claims.

The source witness and mocked Provider tests do not establish original tool
execution, native contract execution, real signatures, actual RPC/Safe success,
deployment capacity or release readiness. The synthetic inputs in the witness
are test material and cannot supply campaign admission.
