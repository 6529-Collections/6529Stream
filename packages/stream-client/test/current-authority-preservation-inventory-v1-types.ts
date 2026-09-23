import type { Address, Hex } from "../src/generated/contracts.js";
import {
  type CurrentAuthorityPreservationInventoryV1Coordinates,
  type CurrentAuthorityPreservationInventoryV1CollectionRequest,
  type CurrentAuthorityPreservationInventoryV1ScopedRequest,
  type CurrentAuthorityPreservationInventoryV1Capture,
  type CurrentAuthorityPreservationInventoryV1Context,
  type CurrentAuthorityPreservationInventoryV1Evidence,
  type CurrentAuthorityPreservationInventoryV1Origin,
  type CurrentAuthorityPreservationInventoryV1Work,
  type CurrentAuthorityPreservationInventoryV1Rights,
  type CurrentAuthorityPreservationInventoryV1Intent,
  type CurrentAuthorityPreservationInventoryV1IntentWaiver,
  type CurrentAuthorityPreservationInventoryV1Interview,
  type CurrentAuthorityPreservationInventoryV1HistoryInput,
  prepareCurrentAuthorityPreservationInventoryV1Call,
  prepareCurrentAuthorityPreservationInventoryV1Read,
  normalizeCurrentAuthorityPreservationInventoryV1Context,
  normalizeCurrentAuthorityPreservationInventoryV1Capture,
  authenticateCurrentAuthorityPreservationInventoryV1History,
  currentAuthorityPreservationInventoryV1OriginSetHash,
} from "../src/current-authority-preservation-inventory-v1.js";
declare const address: Address;
declare const hash: Hex;
declare const coordinates: CurrentAuthorityPreservationInventoryV1Coordinates;
declare const capture: CurrentAuthorityPreservationInventoryV1Capture;
declare const context: CurrentAuthorityPreservationInventoryV1Context;
declare const evidence: CurrentAuthorityPreservationInventoryV1Evidence;
declare const history: CurrentAuthorityPreservationInventoryV1HistoryInput;
declare const origins: readonly CurrentAuthorityPreservationInventoryV1Origin[];
declare const work: CurrentAuthorityPreservationInventoryV1Work;
declare const rights: CurrentAuthorityPreservationInventoryV1Rights;
declare const intent: CurrentAuthorityPreservationInventoryV1Intent;
declare const waiver: CurrentAuthorityPreservationInventoryV1IntentWaiver;
declare const interview: CurrentAuthorityPreservationInventoryV1Interview;
const planId = hash;
const receipt = { lane: 0n, index: 0n } as const;
const aggregate = { revision: 0n, transitionChain: hash } as const;
const payload = { tokenId: 1n, producer: address, image: "0x" as Hex, animation: "0x01" as Hex } as const;
const scope = { scopeType: 1n, collectionId: 3n, tokenId: 4n, scopeId: hash } as const;
const collection: readonly CurrentAuthorityPreservationInventoryV1CollectionRequest[] = [
  { kind: "beginInventory", collectionId: 3n }, { kind: "appendNative", planId }, { kind: "appendReference", planId },
  { kind: "appendWork", planId, witness: work, originalActor: address, receipt }, { kind: "appendRights", planId, witness: rights },
  { kind: "appendIntent", planId, witness: intent, originalActor: address, receipt },
  { kind: "appendIntentWaiver", planId, witness: waiver, originalActor: address, receipt },
  { kind: "appendInterview", planId, witness: interview, originalActor: address, receipt }, { kind: "appendInterviewWaiver", planId },
  { kind: "appendRootAuthorization", planId, originalActor: address, observedAt: 1n, aggregate, receipt },
  { kind: "appendDefinition", planId }, { kind: "appendToken", planId, payload }, { kind: "appendScript", planId },
  { kind: "appendLibrary", planId }, { kind: "appendRenderer", planId }, { kind: "appendCurrentProfile", planId },
  { kind: "appendTokenPreservation", planId }, { kind: "appendOriginRuntime", planId }, { kind: "sealInventory", planId },
];
const scoped: readonly CurrentAuthorityPreservationInventoryV1ScopedRequest[] = [
  { kind: "beginInventory", scope }, { kind: "appendNative", planId, maxChunks: 64n }, { kind: "appendReference", planId, maxChunks: 64n },
  { kind: "appendWork", planId, witness: work, originalActor: address, receipt }, { kind: "appendRights", planId, witness: rights },
  { kind: "appendIntent", planId, witness: intent, originalActor: address, receipt },
  { kind: "appendIntentWaiver", planId, witness: waiver, originalActor: address, receipt },
  { kind: "appendInterview", planId, witness: interview, originalActor: address, receipt }, { kind: "appendInterviewWaiver", planId },
  { kind: "appendRootAuthorization", planId, originalActor: address, observedAt: 1n, aggregate, receipt, originalLegacyFamilyHash: hash },
  { kind: "appendDefinition", planId }, { kind: "appendTokenOutput", planId, payload }, { kind: "appendTokenScript", planId },
  { kind: "appendTokenLibrary", planId }, { kind: "appendTokenRenderer", planId }, { kind: "appendTokenCitation", planId },
  { kind: "appendTokenPreservation", planId }, { kind: "appendOriginRuntime", planId }, { kind: "sealInventory", planId },
];
for (const request of [...collection, ...scoped]) {
  const call = prepareCurrentAuthorityPreservationInventoryV1Call(coordinates, address, request);
  const data: Hex = call.call.data;
  void data;
  // @ts-expect-error immutable plan
  call.request.kind = "sealInventory";
}
const read = prepareCurrentAuthorityPreservationInventoryV1Read(coordinates, { kind: "authoritySelection", planId });
const current = prepareCurrentAuthorityPreservationInventoryV1Read(coordinates, { kind: "requireCurrent", scope });
const flag: boolean = current.requiresCurrentSources;
const normalized = normalizeCurrentAuthorityPreservationInventoryV1Capture(capture);
const normalizedContext = normalizeCurrentAuthorityPreservationInventoryV1Context("collection", context);
const root: Hex = currentAuthorityPreservationInventoryV1OriginSetHash(origins);
const authenticated = authenticateCurrentAuthorityPreservationInventoryV1History(history);
const result: Hex = authenticated.evidenceHash;
// @ts-expect-error captured anchors are immutable
normalized.dependencies.targets[0] = address;
// @ts-expect-error nested selected origin is immutable
normalized.selection.origin.environment.owners[0] = address;
// @ts-expect-error exact owner roster has seven values
const badOrigin: CurrentAuthorityPreservationInventoryV1Origin = { ...origins[0]!, environment: { ...origins[0]!.environment, owners: [address] } };
// @ts-expect-error scope enum remains closed
const wrongScope: CurrentAuthorityPreservationInventoryV1ScopedRequest = { kind: "beginInventory", scope: { ...scope, scopeType: 5n } };
// @ts-expect-error collection root has no legacy-family field
const wrongCollection: CurrentAuthorityPreservationInventoryV1CollectionRequest = { kind: "appendRootAuthorization", planId, originalActor: address, observedAt: 1n, aggregate, receipt, originalLegacyFamilyHash: hash };
// @ts-expect-error scoped native requires explicit maximum
const missingMaximum: CurrentAuthorityPreservationInventoryV1ScopedRequest = { kind: "appendNative", planId };
// @ts-expect-error collection spelling is not scoped spelling
const wrongMethod: CurrentAuthorityPreservationInventoryV1ScopedRequest = { kind: "appendCurrentProfile", planId };
// @ts-expect-error original receipt locator cannot be omitted
const missingReceipt: CurrentAuthorityPreservationInventoryV1CollectionRequest = { kind: "appendWork", planId, witness: work, originalActor: address };
// @ts-expect-error no archive writes
prepareCurrentAuthorityPreservationInventoryV1Call(coordinates, address, { kind: "beginCoverage", planId });
// @ts-expect-error all numeric fields use bigint
prepareCurrentAuthorityPreservationInventoryV1Call(coordinates, address, { kind: "beginInventory", collectionId: 3 });
void [evidence, read, flag, normalizedContext, root, result, badOrigin, wrongScope, wrongCollection, missingMaximum, wrongMethod, missingReceipt];
