import type { Address, Hex } from "../src/generated/contracts.js";
import type { UnsignedCall } from "../src/binding.js";
import { toSafeCall } from "../src/safe.js";
import {
  type ScopedPolicyFinalityV2Coordinates,
  type ScopedPolicyFinalityV2Scope,
  type ScopedPolicyFinalityV2Statement,
  type ScopedPolicyFinalityV2Component,
  type ScopedPolicyFinalityV2ArchiveProof,
  type ScopedPolicyFinalityV2ScopedRecord,
  type ScopedPolicyFinalityV2NativeConfiguration,
  type ScopedPolicyFinalityV2SourceConfiguration,
  type ScopedPolicyFinalityV2FactoryBinding,
  type ScopedPolicyFinalityV2Sources,
  type ScopedPolicyFinalityV2GovernanceWindow,
  type ScopedPolicyFinalityV2Request,
  type ScopedPolicyFinalityV2ReadRequest,
  type ScopedPolicyFinalityV2ReadTargets,
  type ScopedPolicyFinalityV2Finalization,
  prepareScopedPolicyFinalityV2Finalization,
  normalizeScopedPolicyFinalityV2Finalization,
  scopedPolicyFinalityV2ManifestBytes,
  decodeScopedPolicyFinalityV2Manifest,
  scopedPolicyFinalityV2GovernanceBatch,
  normalizeScopedPolicyFinalityV2GovernanceBatch,
  assertScopedPolicyFinalityV2GovernanceWindow,
  prepareScopedPolicyFinalityV2Call,
  normalizeScopedPolicyFinalityV2Call,
  prepareScopedPolicyFinalityV2Read,
  normalizeScopedPolicyFinalityV2Read,
  authenticateScopedPolicyFinalityV2History,
  validateScopedPolicyFinalityV2NativeConfiguration,
  validateScopedPolicyFinalityV2Sources,
  scopedPolicyFinalityV2ProviderConfigurationHash,
  scopedPolicyFinalityV2SourceConfigurationHash,
  encodeScopedPolicyFinalityV2ExecutionContext,
  decodeScopedPolicyFinalityV2ExecutionContext,
} from "../src/current-scoped-policy-finality-v2.js";

declare const coordinates: ScopedPolicyFinalityV2Coordinates;
declare const caller: Address;
declare const uri: string;
declare const hash: Hex;
declare const scope: ScopedPolicyFinalityV2Scope;
declare const statement: ScopedPolicyFinalityV2Statement;
declare const components: readonly ScopedPolicyFinalityV2Component[];
declare const proof: ScopedPolicyFinalityV2ArchiveProof;
declare const record: ScopedPolicyFinalityV2ScopedRecord;
declare const native: ScopedPolicyFinalityV2NativeConfiguration;
declare const source: ScopedPolicyFinalityV2SourceConfiguration;
declare const binding: ScopedPolicyFinalityV2FactoryBinding;
declare const sources: ScopedPolicyFinalityV2Sources;
declare const window: ScopedPolicyFinalityV2GovernanceWindow;
declare const targets: ScopedPolicyFinalityV2ReadTargets;

const manifestBytes: Hex = scopedPolicyFinalityV2ManifestBytes(coordinates, statement);
const manifest = decodeScopedPolicyFinalityV2Manifest(manifestBytes);
const chain: bigint = manifest.chainId;
const nonce: bigint = 0n;
const plan: ScopedPolicyFinalityV2Finalization = prepareScopedPolicyFinalityV2Finalization(coordinates, {
  manifestBytes, manifestURI: uri, components, proof,
});
const targetCall: UnsignedCall = plan.targetCall;
const normalized = normalizeScopedPolicyFinalityV2Finalization(plan);
const execution = decodeScopedPolicyFinalityV2ExecutionContext(encodeScopedPolicyFinalityV2ExecutionContext(normalized.execution));
const contextHash: Hex = execution.newValueHash;
const planUnverified: false = plan.factsVerified;
const batch = normalizeScopedPolicyFinalityV2GovernanceBatch(scopedPolicyFinalityV2GovernanceBatch(plan, nonce, window));
assertScopedPolicyFinalityV2GovernanceWindow(window, 100n);

const requests: readonly ScopedPolicyFinalityV2Request[] = [
  { kind: "stageFinalityManifest", manifestBytes },
  { kind: "publishGovernanceCallData", batch },
  { kind: "scheduleGovernanceBatch", batch },
  { kind: "executeGovernanceBatch", batch },
];
for (const request of requests) {
  const prepared = normalizeScopedPolicyFinalityV2Call(prepareScopedPolicyFinalityV2Call(coordinates, caller, request));
  const call: UnsignedCall = prepared.call;
  const unverified: false = prepared.factsVerified;
  const actor: Address = prepared.caller;
  toSafeCall(call);
  // @ts-expect-error Detached caller is immutable.
  prepared.caller = caller;
  // @ts-expect-error CALL value cannot be edited after preparation.
  prepared.call.value = 1n;
  void [unverified, actor];
}

const reads: readonly ScopedPolicyFinalityV2ReadRequest[] = [
  { host: "registry", kind: "artworkScopeFinalityRecord", scope },
  { host: "registry", kind: "finalityComponentsForScope", scope, start: 0n, limit: 10n },
  { host: "registry", kind: "finalityManifestBytes", hash },
  { host: "registry", kind: "finalityExecutionContextWithArchive", plan },
  { host: "registry", kind: "prepareSanctionWithReview", manifestBytes, manifestURI: uri },
  { host: "provider", kind: "requireFinalityScopeInputs", scope, manifestHash: hash },
  { host: "provider", kind: "requirePreparedFinalityScopeInputs", plan },
  { host: "provider", kind: "finalitySourcesForScope", scope },
  { host: "provider", kind: "nativeConfiguration" },
  { host: "provider", kind: "finalitySourceProfile", index: 2n },
  { host: "discovery", kind: "configuration" },
  { host: "discovery", kind: "nonSanctionDiscoveryFacts", scope },
  { host: "discovery", kind: "nonSanctionComponentAt", scope, index: 0n },
  { host: "discovery", kind: "requireCurrentRoutes", scope, includeSanction: true },
  { host: "executor", kind: "governanceAction", actionId: hash },
  { host: "executor", kind: "publishedCallData", publicationKey: hash },
  { host: "executor", kind: "currentAction" },
];
for (const request of reads) {
  const prepared = normalizeScopedPolicyFinalityV2Read(prepareScopedPolicyFinalityV2Read(coordinates, targets, caller, request));
  const boundary: "public-read" | "registry-only-read" = prepared.callerBoundary;
  const unverified: false = prepared.factsVerified;
  void [boundary, unverified];
}

const historical = authenticateScopedPolicyFinalityV2History(coordinates, { manifestBytes, record, components });
const oldCoreFacts: Hex = historical.statement.coreFactsHash;
const historicalUnverified: false = historical.factsVerified;
validateScopedPolicyFinalityV2NativeConfiguration(native);
validateScopedPolicyFinalityV2Sources(sources, scope);
const providerHash: Hex = scopedPolicyFinalityV2ProviderConfigurationHash(targets.provider, native, binding);
const sourceHash: Hex = scopedPolicyFinalityV2SourceConfigurationHash(targets.provider, source, binding);

// @ts-expect-error Source fields use exact uint256 bigint values.
const badScope: ScopedPolicyFinalityV2Scope = { scopeType: 1n, collectionId: 1, tokenId: 2n, scopeId: hash };
// @ts-expect-error Unknown scope enum is not represented.
const futureScope: ScopedPolicyFinalityV2Scope = { scopeType: 5n, collectionId: 1n, tokenId: 2n, scopeId: hash };
// @ts-expect-error Inner Executor-only call is not a wallet stage.
const badRequest: ScopedPolicyFinalityV2Request = { kind: "finalizeArtworkScopeWithArchive", batch };
// @ts-expect-error Retired local lifecycle cannot be prepared.
const retired: ScopedPolicyFinalityV2Request = { kind: "scheduleArtworkTerminalFreeze", batch };
// @ts-expect-error Discovery has no mutating plan.
const mutation: ScopedPolicyFinalityV2ReadRequest = { host: "discovery", kind: "stageFinalityManifest", manifestBytes };
// @ts-expect-error Provider catalogue index is bigint, not a JS number.
const badIndex: ScopedPolicyFinalityV2ReadRequest = { host: "provider", kind: "finalitySourceProfile", index: 0 };
// @ts-expect-error A currentness read cannot target the Registry under the provider name.
const wrongHost: ScopedPolicyFinalityV2ReadRequest = { host: "registry", kind: "finalitySourcesForScope", scope };
// @ts-expect-error Historical source is immutable and independent of future source reads.
historical.statement.coreFactsHash = hash;
// @ts-expect-error Component inventory is immutable.
plan.components.push(components[0]!);
// @ts-expect-error The original manifest carries its complete typed Inputs.
plan.statement.inputs.rootRecordHash = hash;
// @ts-expect-error No added user-supplied action class exists in the closed singleton batch.
scopedPolicyFinalityV2GovernanceBatch(plan, nonce, { ...window, actionClass: 3n });
// @ts-expect-error No fresh source override is accepted in retained history.
authenticateScopedPolicyFinalityV2History(coordinates, { manifestBytes, record, components, currentCoreFactsHash: hash });

void [chain, targetCall, contextHash, planUnverified, oldCoreFacts, historicalUnverified, providerHash, sourceHash,
  badScope, futureScope, badRequest, retired, mutation, badIndex, wrongHost];
