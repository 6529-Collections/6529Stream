import type { Address, Hex } from "../src/generated/contracts.js";
import type { UnsignedCall } from "../src/binding.js";
import { toSafeCall } from "../src/safe.js";
import {
  type TokenPreservationOutputV2Coordinates,
  type TokenPreservationOutputV2Scope,
  type TokenPreservationOutputV2CheckpointIdentity,
  type TokenPreservationOutputV2SourceFacts,
  type TokenPreservationOutputV2ContentPlan,
  type TokenPreservationOutputV2Output,
  type TokenPreservationOutputV2OutputPlan,
  type TokenPreservationOutputV2Binding,
  type TokenPreservationOutputV2RegistryBinding,
  type TokenPreservationOutputV2Admission,
  type TokenPreservationOutputV2TokenSelection,
  type TokenPreservationOutputV2Coverage,
  type TokenPreservationOutputV2Request,
  type TokenPreservationOutputV2ReadRequest,
  prepareTokenPreservationOutputV2Call,
  normalizeTokenPreservationOutputV2Call,
  prepareTokenPreservationOutputV2Read,
  normalizeTokenPreservationOutputV2Read,
  normalizeTokenPreservationOutputV2ContentPlan,
  normalizeTokenPreservationOutputV2Output,
  encodeTokenPreservationOutputV2Output,
  decodeTokenPreservationOutputV2Output,
  encodeTokenPreservationOutputV2RegistryAdmission,
  decodeTokenPreservationOutputV2RegistryAdmission,
  validateTokenPreservationOutputV2Scope,
  validateTokenPreservationOutputV2Admission,
  tokenPreservationOutputV2CheckpointId,
  tokenPreservationOutputV2InitialContentPlan,
  tokenPreservationOutputV2SourceFactsHash,
  tokenPreservationOutputV2SelectionRowHash,
  tokenPreservationOutputV2ManifestBytes,
  decodeTokenPreservationOutputV2ManifestBytes,
  tokenPreservationOutputV2Manifest,
  tokenPreservationOutputV2ManifestPlanHash,
  tokenPreservationOutputV2RecordHash,
  authenticateTokenPreservationOutputV2History,
} from "../src/current-token-preservation-output-v2.js";

declare const coordinates: TokenPreservationOutputV2Coordinates;
declare const scope: TokenPreservationOutputV2Scope;
declare const identity: TokenPreservationOutputV2CheckpointIdentity;
declare const facts: TokenPreservationOutputV2SourceFacts;
declare const content: TokenPreservationOutputV2ContentPlan;
declare const outputs: readonly TokenPreservationOutputV2Output[];
declare const outputPlan: TokenPreservationOutputV2OutputPlan;
declare const binding: TokenPreservationOutputV2Binding;
declare const registryBinding: TokenPreservationOutputV2RegistryBinding;
declare const admission: TokenPreservationOutputV2Admission;
declare const selection: TokenPreservationOutputV2TokenSelection;
declare const coverage: TokenPreservationOutputV2Coverage;
declare const hash: Hex;
declare const address: Address;

const scope0: TokenPreservationOutputV2Scope = { scopeType: 0n, collectionId: 1n, tokenId: 0n, scopeId: hash };
validateTokenPreservationOutputV2Scope("collection", scope0);
validateTokenPreservationOutputV2Scope("scoped", scope);
const plan = normalizeTokenPreservationOutputV2ContentPlan(content);
const initial = tokenPreservationOutputV2InitialContentPlan(coordinates.scopeKind, identity);
const originalCount: bigint = initial.tokenCount;
const checkpointHash: Hex = tokenPreservationOutputV2CheckpointId(coordinates, identity);
const sourceHash: Hex = tokenPreservationOutputV2SourceFactsHash(coordinates.scopeKind, facts);
const rowHash: Hex = tokenPreservationOutputV2SelectionRowHash(coordinates.chainId, coordinates.core, coordinates.metadataRouter, selection);
const observed = validateTokenPreservationOutputV2Admission(binding, admission, selection, registryBinding);
const unverified: false = observed.factsVerified;
const admitted = decodeTokenPreservationOutputV2RegistryAdmission(encodeTokenPreservationOutputV2RegistryAdmission(registryBinding, admission));
const actualRouter: Address = admitted.binding.router;
const decoded = decodeTokenPreservationOutputV2Output(encodeTokenPreservationOutputV2Output(outputs[0]!));
const normalized = normalizeTokenPreservationOutputV2Output(decoded);
const bytes: Hex = tokenPreservationOutputV2ManifestBytes(coordinates, checkpointHash, content, address, outputs);
const manifestPayload = decodeTokenPreservationOutputV2ManifestBytes(bytes);
const manifest = tokenPreservationOutputV2Manifest(coordinates, checkpointHash, content, address, coverage);
const manifestPlanHash: Hex = tokenPreservationOutputV2ManifestPlanHash(coordinates, address, manifest);
const recordHash: Hex = tokenPreservationOutputV2RecordHash(manifestPlanHash);
const history = authenticateTokenPreservationOutputV2History(coordinates, address, manifestPlanHash, outputPlan);
const historicalOnly: false = history.currentnessChecked;

const requests: readonly TokenPreservationOutputV2Request[] = [
  { kind: "begin", selectionId: hash, salt: hash },
  { kind: "append", id: hash, payloads: [{ tokenId: 1n, producer: address, image: "0x", animation: "0x01" }] },
  { kind: "beginManifest", checkpointHash: hash, artifactHash: hash, coverageHash: hash, artistId: hash },
  { kind: "verifyNextOutputs", planHash: hash, count: 16n },
];
for (const request of requests) {
  const prepared = normalizeTokenPreservationOutputV2Call(prepareTokenPreservationOutputV2Call(coordinates, address, request));
  const call: UnsignedCall = prepared.call;
  const factsVerified: false = prepared.factsVerified;
  const safeCall = toSafeCall(call);
  // @ts-expect-error Prepared transport is immutable.
  prepared.call.value = 1n;
  // @ts-expect-error Detached caller is immutable.
  prepared.caller = address;
  void [factsVerified, safeCall];
}
const reads: readonly TokenPreservationOutputV2ReadRequest[] = [
  { host: "checkpoint", kind: "checkpoint", id: hash },
  { host: "checkpoint", kind: "outputAt", id: hash, index: 0n },
  { host: "checkpoint", kind: "requireCurrentCheckpoint", id: hash },
  { host: "checkpoint", kind: "sourceFactory" },
  { host: "output", kind: "manifestPlan", planHash: hash },
  { host: "output", kind: "manifestRecord", recordHash: hash },
  { host: "output", kind: "requireCurrentManifest", recordHash: hash, artistId: hash },
  { host: "producer", target: address, kind: "preservationProfile" },
  { host: "producer", target: address, kind: "preservationBinding" },
  { host: "producer", target: address, kind: "preservationTokenJSON", tokenId: 1n },
  { host: "producer", target: address, kind: "preservationTokenHTML", tokenId: 1n },
  { host: "registry", target: address, kind: "preservationKey", versionKey: hash, producer: address, profile: hash },
  { host: "registry", target: address, kind: "preservationRecord", key: hash },
  { host: "registry", target: address, kind: "preservationReads", key: hash },
  { host: "registry", target: address, kind: "requirePreservation", versionKey: hash, producer: address, profile: hash },
];
for (const request of reads) {
  const read = normalizeTokenPreservationOutputV2Read(prepareTokenPreservationOutputV2Read(coordinates, request));
  const target: Address = read.call.to;
  void target;
}

// @ts-expect-error Unknown future scope is outside the original enum.
const badScope: TokenPreservationOutputV2Scope = { ...scope, scopeType: 5n };
// @ts-expect-error Family is fixed by the V2 endpoint, never supplied on coordinates.
prepareTokenPreservationOutputV2Call({ ...coordinates, family: hash }, address, requests[0]!);
// @ts-expect-error One producer is required for every append payload.
const missingProducer: TokenPreservationOutputV2Request = { kind: "append", id: hash, payloads: [{ tokenId: 1n, image: "0x", animation: "0x01" }] };
// @ts-expect-error No snapshot publishing is exposed by this seam.
const snapshot: TokenPreservationOutputV2Request = { kind: "publishSnapshot", p: {} };
// @ts-expect-error Governed gas changes are excluded.
const gas: TokenPreservationOutputV2Request = { kind: "raiseGasParameter", parameterId: hash, newValue: 1n };
// @ts-expect-error Registry admission mutations are excluded.
const registration: TokenPreservationOutputV2ReadRequest = { host: "registry", target: address, kind: "registerPreservation" };
// @ts-expect-error Original fields use bigint, not JS numbers.
const badCount: TokenPreservationOutputV2Request = { kind: "verifyNextOutputs", planHash: hash, count: 1 };
// @ts-expect-error Original registry field name is router, not metadataRouter.
const wrongBinding: TokenPreservationOutputV2RegistryBinding = binding;
// @ts-expect-error Producer selectors cannot use a checkpoint host.
const wrongHost: TokenPreservationOutputV2ReadRequest = { host: "checkpoint", kind: "preservationTokenHTML", tokenId: 1n };
// @ts-expect-error Completed plan snapshot is immutable.
plan.nextIndex = 1n;
// @ts-expect-error Full producer identity is immutable.
normalized.preservation.profile = hash;
// @ts-expect-error Manifest array and nested evidence are immutable.
manifestPayload.rows[0]!.preservationAdmission.registry = address;
// @ts-expect-error Historical verification cannot be upgraded to current evidence.
history.currentnessChecked = true;

void [originalCount, sourceHash, rowHash, unverified, actualRouter, recordHash, historicalOnly,
  badScope, missingProducer, snapshot, gas, registration, badCount, wrongBinding, wrongHost];
