# Prepare complete reference environments

Environment preparation retains the original canonical environment bytes before
a reference publication needs them. The client preserves the complete 24-field
`Environment`, its two full file inventories and the actual publication host's
identity. Both the original and Mode publication hosts support the additive
`prepareEnvironment(Environment)` call.

Contract source is frozen at
[`dfe75d52`](https://github.com/6529-Collections/6529Stream/tree/dfe75d52a2baa3fc394b0a94140565cd3ce850f4).
Preparation grants no publication authority and authenticates no live source,
coverage, dependency-selection or finality facts. The publication flow continues
to check those facts when it runs.

## Preserve the original typed input

```ts
import {
  prepareReferenceEnvironment, prepareReferenceEnvironmentPlan,
  prepareReferenceInventoryPlan, inspectReferenceEnvironmentPreparation,
  simulateReferenceEnvironmentStep, quoteReferenceEnvironmentStepGas,
  inspectReferenceEnvironmentStepReceipt,
} from "@6529/stream-client";

const snapshot = prepareReferenceEnvironment(chainId, publicationHost, environment);
```

`environment` contains every original field, with integer fields expressed as
`bigint`:

```text
objectHash, coverageHash, manifestHash, manifestBytes,
engineName, engineVersion, engineExecutableSha256,
toolchainName, toolchainVersion, toolchainSha256,
engineExecutablePath, toolchainPath, packageFiles, platformPrerequisites,
operatingSystem, operatingSystemVersion, architecture,
viewportWidth, viewportHeight, devicePixelRatio, colorSpace,
softwareRasterization, captureProfile, licenseNote
```

The codec enforces the original Windows/AMD64 still-capture profile, sRGB,
software rasterization, device-pixel ratio 1 and dimensions from 1 to 4,096.
Strings retain their UTF-8 bytes, original quoting and nonempty length limits.
Engine and toolchain paths must each identify a nonempty package member with
the supplied SHA-256 digest. File arrays must already be in their original
strict UTF-8 path order; the client does not sort or shorten them.

`prepareReferenceEnvironment` reconstructs the canonical JSON and requires its
hash and byte length to match the supplied `manifestHash` and `manifestBytes`.
It rejects a manifest larger than 524,288 bytes. When constructing a new input,
`referenceEnvironmentCanonicalBytes` can compute those bytes before the
manifest declarations are known. It width-checks declarations without replacing
them; supply the resulting hash and length before preparing the snapshot.

The preparation ID is:

```text
keccak256(abi.encode(
  keccak256("6529STREAM_REFERENCE_ENVIRONMENT_PREPARATION_V1"),
  chainId, actualPublicationHost, completeOriginalEnvironment
))
```

`coverageHash`, `manifestHash` and `manifestBytes` remain in that typed identity
although they are absent from the canonical JSON itself. The same JSON bytes
with different coverage declarations have different preparation IDs. The
identity never uses the uploader, preparer or linked worker as its host.

## Prepare inventories, upload bytes, retain the environment

Use trusted chain, host and Store runtime pins. The same deployment object is
accepted by the existing file-inventory workflow:

```ts
const deployment = {
  chainId,
  publicationHost: { address: publicationHost, codeHash: hostRuntimeHash },
  store: { address: storeAddress, codeHash: storeRuntimeHash },
};

const packagePlan = prepareReferenceInventoryPlan(
  deployment, preparer, snapshot.packageInventory, { mode: "staged", uploader },
);
const platformPlan = prepareReferenceInventoryPlan(
  deployment, preparer, snapshot.platformInventory, { mode: "staged", uploader },
);
const plan = prepareReferenceEnvironmentPlan(deployment, preparer, snapshot, { uploader });
```

First complete both original full inventories using the
[file-inventory workflow](current-reference-inventory.md). Individual prepared
parts do not substitute for either full inventory. The environment plan then
uploads its complete canonical bytes in ordered 8,192-byte Store chunks and
prepares the original typed environment from the selected preparer.

```ts
const blockTag = await provider.getBlockNumber();
const inspection = await inspectReferenceEnvironmentPreparation(provider, plan, { blockTag });
// Choose a ready step after inspecting its prerequisites and exact caller.
await simulateReferenceEnvironmentStep(provider, plan, stepIndex, { blockTag });
const gas = await quoteReferenceEnvironmentStepGas(provider, plan, stepIndex, {
  blockTag, maximumGas,
});
```

Pinned reads verify host and Store runtime hashes, the host's chain and Store
binding, the additive capability, full retained inventory bytes and exact Store
chunk contents. Missing prerequisites block preparation. A failed or malformed
read is not treated as successful preparation. If the full environment is
already retained intact, the inspector reports completion without inventing
the history of its prerequisite calls.

Simulation uses the actual caller, target, calldata and zero value. Uploads and
retention are independent transactions; simulating the final step does not
execute earlier uploads. Gas quotes apply to the pinned inner call only. They
do not establish a complete Safe or publisher transaction's gas envelope.

## Safe review and receipt evidence

The [Safe example](../examples/current-reference-environment.mjs) accepts
`deployment`, the complete `environment`, separate `uploaderSafe` and
`preparerSafe`, plus the selected compiled Store and publication-host ABIs.
It returns exact ordinary CALLs, decoded arguments, prerequisite identities and
a review table. It never signs, submits or publishes a reference.

```ts
const result = await inspectReferenceEnvironmentStepReceipt(provider, plan, stepIndex, {
  transactionHash, execution: "safe", // or "direct"
});
```

First preparation emits schema-1 `ReferenceEnvironmentPrepared` with the exact
environment ID, content hash and byte length. Retained bytes remain readable
through the original `preparedFileInventory(environmentId)` getter. Intact
retries are eventless; receipt checks require prior-block evidence for those
retries, alongside exact calldata and current retained-byte checks. Missing
chunks, corrupted retained data, changed code or contradictory events fail
closed. Safe receipts additionally require the matching success event after
the target's events and reject failed or substituted calls.

The host and Store must also satisfy their pins in the preceding block. Receipt
reconciliation for deployment and preparation within one block requires
separate transaction-level history.

Receipt inspection accepts up to 256 logs, 16,384 bytes per log and 2,000,000
bytes of outer transaction calldata. These are client inspection bounds, not
new protocol limits.

## Frozen evidence

The [ABI fixture](../test/fixtures/current-reference-environment-abi.json)
projects 33 entries from the clean 127-source `reference-modes-abi40` capture.
Every literal source matches the frozen Git commit byte for byte. The separate
[corpus projection](../test/fixtures/current-reference-environment-corpus.json)
reuses the original 1,048 package rows and 102 platform rows, and pins all
179,418 bytes of the retained canonical environment by SHA-256 and Keccak-256.
Its test coverage identity is explicitly synthetic.

```sh
node scripts/generate-current-reference-environment-fixture.mjs INPUT.json OUTPUT.json --check
node scripts/generate-current-reference-environment-corpus.mjs ENVIRONMENT.json --check
```

These source, ABI, canonical-byte and controlled client checks do not replace
whole publisher execution, actual Safe transactions, complete gas-envelope or
release acceptance. No authority or currentness claim is inferred from a
successful preparation receipt.
