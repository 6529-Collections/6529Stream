import type { Address, Hex, UnsignedCall } from "../src/index.js";
import * as inventory from "../src/current-scoped-policy-inventory-v2.js";

declare const coordinates: inventory.ScopedPolicyInventoryV2Coordinates;
declare const caller: Address;
declare const id: Hex;
declare const scope: inventory.ScopedPolicyInventoryV2Scope;
declare const context: inventory.ScopedPolicyInventoryV2Context;
declare const dependencies: inventory.ScopedPolicyInventoryV2Dependencies;
declare const plan: inventory.ScopedPolicyInventoryV2Plan;
declare const tokenProgress: inventory.ScopedPolicyInventoryV2TokenProgress;
declare const evidence: inventory.ScopedPolicyInventoryV2Evidence;
declare const item: inventory.ScopedPolicyInventoryV2Item;
declare const work: inventory.ScopedPolicyInventoryV2Work;
declare const rights: inventory.ScopedPolicyInventoryV2Rights;
declare const intent: inventory.ScopedPolicyInventoryV2Intent;
declare const waiver: inventory.ScopedPolicyInventoryV2IntentWaiver;
declare const interview: inventory.ScopedPolicyInventoryV2Interview;
declare const payload: inventory.ScopedPolicyInventoryV2Payload;
declare const aggregate: inventory.ScopedPolicyInventoryV2Aggregate;
declare const facts: inventory.ScopedPolicyInventoryV2DocumentFacts;
declare const chunks: readonly Hex[];

const requests: readonly inventory.ScopedPolicyInventoryV2Request[] = [
  { kind: "beginInventory", scope },
  { kind: "appendNative", id, maximum: 64n },
  { kind: "appendReference", id, maximum: 1n },
  { kind: "appendWork", id, witness: work, originalActor: caller },
  { kind: "appendRights", id, witness: rights },
  { kind: "appendIntent", id, witness: intent, originalActor: caller },
  { kind: "appendIntentWaiver", id, witness: waiver, originalActor: caller },
  { kind: "appendInterview", id, witness: interview, originalActor: caller },
  { kind: "appendInterviewWaiver", id },
  { kind: "appendRootAuthorization", id, actor: caller, observedAt: 1n, originalAggregate: aggregate, originalLegacyFamilyHash: id },
  { kind: "appendDefinition", id },
  { kind: "appendTokenOutput", id, payload },
  { kind: "appendTokenScript", id },
  { kind: "appendTokenLibrary", id },
  { kind: "appendTokenRenderer", id },
  { kind: "appendTokenCitation", id },
  { kind: "sealInventory", id },
];
for (const request of requests) {
  const prepared = inventory.prepareScopedPolicyInventoryV2Call(coordinates, caller, request);
  const call: UnsignedCall = prepared.call;
  const unverified: false = prepared.factsVerified;
  inventory.normalizeScopedPolicyInventoryV2Call(prepared);
  inventory.validateScopedPolicyInventoryV2Stage(plan, tokenProgress, prepared.request);
  if (prepared.request.kind === "appendRootAuthorization") {
    const observedAt: bigint = prepared.request.observedAt;
    const original: inventory.ScopedPolicyInventoryV2Aggregate = prepared.request.originalAggregate;
    // @ts-expect-error retained event Aggregate is detached immutable input
    original.revision = 0n;
    void observedAt;
  }
  if (prepared.request.kind === "appendWork") {
    const witness: inventory.ScopedPolicyInventoryV2Work = prepared.request.witness;
    // @ts-expect-error a supplied caller cannot be changed after planning
    prepared.caller = caller;
    void witness;
  }
  // @ts-expect-error the exact zero-value CALL is immutable
  prepared.call.value = 1n;
  void call; void unverified;
}

const normalizedContext = inventory.validateScopedPolicyInventoryV2Context(coordinates, context);
const dependencyHash: Hex = inventory.scopedPolicyInventoryV2DependencyHash(dependencies);
const planId: Hex = inventory.scopedPolicyInventoryV2PlanId(coordinates, dependencyHash, normalizedContext);
const evidenceHash: Hex = inventory.scopedPolicyInventoryV2EvidenceHash(coordinates, dependencyHash, evidence);
inventory.validateScopedPolicyInventoryV2Evidence(coordinates, dependencyHash, evidence);
const segment: inventory.ScopedPolicyInventoryV2Segment = inventory.scopedPolicyInventoryV2Segment(id, id, [item, item]);
inventory.scopedPolicyInventoryV2AppendSegment(id, 1n, segment);
inventory.scopedPolicyInventoryV2Link(id, 2n, 0n, item, id);
inventory.scopedPolicyInventoryV2TokenWitness(id, id, 1n, 0n, 0n, 1n);
inventory.scopedPolicyInventoryV2CursorWitness(id, 1n, 2n);
inventory.decodeScopedPolicyInventoryV2Context(inventory.encodeScopedPolicyInventoryV2Context(context));
inventory.decodeScopedPolicyInventoryV2Evidence(inventory.encodeScopedPolicyInventoryV2Evidence(evidence));
inventory.decodeScopedPolicyInventoryV2Work(inventory.encodeScopedPolicyInventoryV2Work(work));
inventory.decodeScopedPolicyInventoryV2Payload(inventory.encodeScopedPolicyInventoryV2Payload(payload));
inventory.validateScopedPolicyInventoryV2OriginalAuthorization(caller, caller, true, "0x");
inventory.validateScopedPolicyInventoryV2WorkActor(caller, id);

const definition: inventory.ScopedPolicyInventoryV2Definition = inventory.SCOPED_POLICY_INVENTORY_V2_DEFINITIONS[0]!;
const byteLength: bigint = definition.byteLength;
inventory.validateScopedPolicyInventoryV2Document(0n, facts, chunks);
const read = inventory.prepareScopedPolicyInventoryV2Read(coordinates, caller, { kind: "inventorySegment", id, index: 1n });
inventory.normalizeScopedPolicyInventoryV2Read(read);
inventory.prepareScopedPolicyInventoryV2Read(coordinates, caller, { kind: "sourceContext", id });
inventory.prepareScopedPolicyInventoryV2Read(coordinates, caller, { kind: "requireCurrent", scope });
inventory.prepareScopedPolicyInventoryV2Read(coordinates, caller, { kind: "requireFullDefinitionBytes", id });

// @ts-expect-error append counts preserve exact uint64 as bigint
inventory.prepareScopedPolicyInventoryV2Call(coordinates, caller, { kind: "appendNative", id, maximum: 1 });
// @ts-expect-error Work and Rights witnesses are distinct original structs
inventory.prepareScopedPolicyInventoryV2Call(coordinates, caller, { kind: "appendWork", id, witness: rights, originalActor: caller });
// @ts-expect-error the original root event Aggregate is required
inventory.prepareScopedPolicyInventoryV2Call(coordinates, caller, { kind: "appendRootAuthorization", id, actor: caller, observedAt: 1n, originalLegacyFamilyHash: id });
// @ts-expect-error no direct governed gas mutation is exposed
inventory.prepareScopedPolicyInventoryV2Call(coordinates, caller, { kind: "raiseGasParameter", parameter: id, value: 1n });
// @ts-expect-error nonpayable native value is not a request input
inventory.prepareScopedPolicyInventoryV2Call(coordinates, caller, { kind: "beginInventory", scope, value: 1n });
// @ts-expect-error there is no public Item getter on the original inventory
inventory.prepareScopedPolicyInventoryV2Read(coordinates, caller, { kind: "item", id, index: 0n });
// @ts-expect-error historical indices retain bigint widths
inventory.prepareScopedPolicyInventoryV2Read(coordinates, caller, { kind: "inventorySegment", id, index: 0 });
// @ts-expect-error supplied source identities cannot be rewritten
normalizedContext.snapshotSource.artist.bindingGeneration = 0n;
// @ts-expect-error original fixed dependencies are a fixed-width readonly tuple
dependencies.targets[0] = caller;
// @ts-expect-error original fixed dependency array cannot be shortened
const invalidDependencies: inventory.ScopedPolicyInventoryV2Dependencies = { ...dependencies, targets: [caller] };
// @ts-expect-error source item cardinality is exact bigint
const invalidPlan: inventory.ScopedPolicyInventoryV2Plan = { ...plan, nativeCount: 1 };
// @ts-expect-error definition evidence is immutable
definition.byteLength = 1n;
// @ts-expect-error preparation never upgrades supplied facts into verified observations
const invalidVerification: true = read.factsVerified;
// @ts-expect-error exact call coordinates exclude arbitrary linked targets
inventory.normalizeScopedPolicyInventoryV2Coordinates({ ...coordinates, metadata: caller });

void planId; void evidenceHash; void byteLength; void invalidDependencies; void invalidPlan; void invalidVerification;
