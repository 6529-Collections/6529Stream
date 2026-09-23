import type { Address, Hex } from "../src/generated/contracts.js";
import {
  prepareCurrentViewPreservationInventoryV1Call,
  prepareCurrentViewPreservationInventoryV1Read,
  normalizeCurrentViewPreservationInventoryV1Context,
  currentViewPreservationInventoryV1Evidence,
  currentViewPreservationInventoryV1Obligation,
  validateCurrentViewPreservationInventoryV1Stage,
  authenticateCurrentViewPreservationInventoryV1History,
  type CurrentViewPreservationInventoryV1Coordinates,
  type CurrentViewPreservationInventoryV1Dependencies,
  type CurrentViewPreservationInventoryV1Context,
  type CurrentViewPreservationInventoryV1Plan,
  type CurrentViewPreservationInventoryV1TokenProgress,
  type CurrentViewPreservationInventoryV1Evidence,
  type CurrentViewPreservationInventoryV1Scope,
  type CurrentViewPreservationInventoryV1Segment,
  type CurrentViewPreservationInventoryV1Item,
  type CurrentViewPreservationInventoryV1Request,
  type CurrentViewPreservationInventoryV1Description,
  type CurrentViewPreservationInventoryV1Statement,
  type CurrentViewPreservationInventoryV1Intent,
  type CurrentViewPreservationInventoryV1IntentWaiver,
  type CurrentViewPreservationInventoryV1Interview,
} from "../src/current-view-preservation-inventory-v1.js";
import type { CurrentViewRetrievalV1Source } from "../src/current-view-retrieval-v1.js";

declare const coordinates: CurrentViewPreservationInventoryV1Coordinates;
declare const caller: Address;
declare const record: Hex;
declare const scope: CurrentViewPreservationInventoryV1Scope;
declare const dependencies: CurrentViewPreservationInventoryV1Dependencies;
declare const context: CurrentViewPreservationInventoryV1Context;
declare const plan: CurrentViewPreservationInventoryV1Plan;
declare const tokenProgress: CurrentViewPreservationInventoryV1TokenProgress;
declare const evidence: CurrentViewPreservationInventoryV1Evidence;
declare const source: CurrentViewRetrievalV1Source;
declare const description: CurrentViewPreservationInventoryV1Description;
declare const statement: CurrentViewPreservationInventoryV1Statement;
declare const intent: CurrentViewPreservationInventoryV1Intent;
declare const waiver: CurrentViewPreservationInventoryV1IntentWaiver;
declare const interview: CurrentViewPreservationInventoryV1Interview;
declare const segments: readonly Readonly<{ segment: CurrentViewPreservationInventoryV1Segment; items: readonly CurrentViewPreservationInventoryV1Item[] }>[];

const requests: readonly CurrentViewPreservationInventoryV1Request[] = [
  { method: "beginInventory", scope },
  { method: "appendNative", id: record, maximum: 64n },
  { method: "appendReference", id: record, maximum: 1n },
  { method: "appendWork", id: record, witness: description, originalActor: caller },
  { method: "appendRights", id: record, witness: statement },
  { method: "appendIntent", id: record, witness: intent, originalActor: caller },
  { method: "appendIntentWaiver", id: record, witness: waiver, originalActor: caller },
  { method: "appendInterview", id: record, witness: interview, originalActor: caller },
  { method: "appendInterviewWaiver", id: record },
  { method: "appendRootAuthorization", id: record, actor: caller, observedAt: 1n,
    originalAggregate: { revision: 1n, transitionChain: record }, originalLegacyFamilyHash: record },
  { method: "appendDefinition", id: record },
  { method: "appendArtwork", id: record },
  { method: "appendRenderer", id: record },
  { method: "appendPreservationAdmission", id: record },
  { method: "appendTokenOutput", id: record },
  { method: "sealInventory", id: record },
];
for (const request of requests) {
  const call = prepareCurrentViewPreservationInventoryV1Call(coordinates, caller, request);
  const zeroValue: bigint = call.call.value;
  validateCurrentViewPreservationInventoryV1Stage(request, plan, tokenProgress);
  void zeroValue;
}
prepareCurrentViewPreservationInventoryV1Read(coordinates, { method: "retrievalWitnessBinding" });
prepareCurrentViewPreservationInventoryV1Read(coordinates, { method: "inventorySegment", id: record, index: 0n });
const normalized = normalizeCurrentViewPreservationInventoryV1Context(context);
const calculated = currentViewPreservationInventoryV1Evidence(coordinates, record, normalized, plan.progress);
const item = currentViewPreservationInventoryV1Obligation(source);
const historical = authenticateCurrentViewPreservationInventoryV1History(coordinates, dependencies, context, plan, evidence, segments);
const noCurrent: false = historical.current;
const noProducer: false = historical.itemProductionIndependentlyReconstructed;
void [calculated, item, noCurrent, noProducer];

// @ts-expect-error Nested context facts are immutable.
normalized.referenceRender.observation.revision = 3n;
// @ts-expect-error Fixed dependency arrays are immutable.
dependencies.targets[0] = caller;
// @ts-expect-error Witness step is not an inventory operation.
prepareCurrentViewPreservationInventoryV1Call(coordinates, caller, { method: "publish", request: source, signature: record });
// @ts-expect-error Operational counters require exact bigint values.
prepareCurrentViewPreservationInventoryV1Call(coordinates, caller, { method: "appendNative", id: record, maximum: 64 });
// @ts-expect-error Root authorization requires the retained aggregate and original family.
prepareCurrentViewPreservationInventoryV1Call(coordinates, caller, { method: "appendRootAuthorization", id: record, actor: caller, observedAt: 1n });
// @ts-expect-error Original Actor is required even when its value is the legacy zero address.
prepareCurrentViewPreservationInventoryV1Call(coordinates, caller, { method: "appendWork", id: record, witness: description });
// @ts-expect-error Runtime wrapper has no arbitrary storage or worker target coordinate.
prepareCurrentViewPreservationInventoryV1Read(coordinates, { method: "worker", target: caller });
