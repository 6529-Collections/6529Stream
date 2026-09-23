import type { Provider } from "ethers";
import type { Address, Hex } from "../src/generated/contracts.js";
import type { MetadataCitationRegistration, MetadataCitationRead, MetadataCitationRenderRequest, MetadataCitationGovernanceWindow } from "../src/current-metadata-citation.js";
import { captureMetadataCitation, inspectMetadataCitationRegistration, prepareMetadataCitationGovernance, prepareMetadataCitationOperation,
  simulateMetadataCitationOperation, inspectMetadataCitationOperationReceipt, readMetadataCurrentCitation,
  type MetadataCitationDeployment } from "../src/current-metadata-citation-workflow.js";
import { createSafeCallPlan } from "../src/safe-plan.js";
declare const provider: Provider;
declare const deployment: MetadataCitationDeployment;
declare const key: Hex;
declare const actor: Address;
declare const registration: MetadataCitationRegistration;
declare const reads: readonly MetadataCitationRead[];
declare const request: MetadataCitationRenderRequest;
declare const window: MetadataCitationGovernanceWindow;
const capture = await captureMetadataCitation(provider, deployment, key, { blockTag: 10 });
const inspection = await inspectMetadataCitationRegistration(provider, capture, registration, reads);
const prepared = prepareMetadataCitationGovernance(inspection, actor, window);
const op = prepareMetadataCitationOperation(prepared, "schedule", actor);
const simulation = await simulateMetadataCitationOperation(provider, op, { blockTag: 11 });
const receipt = await inspectMetadataCitationOperationReceipt(provider, op, { transactionHash: key, execution: "safe" });
const result = await readMetadataCurrentCitation(provider, deployment, key, request, 2n, { blockTag: 20 });
const rendered: string = result.output;
const hash: Hex = receipt.record!.registrationHash;
const observed: "direct renderer calls; no nested gas equivalence" = inspection.goldenObservation;
const mode: 0n | 1n | 2n = result.mode;
void rendered; void hash; void observed; void mode; void createSafeCallPlan;
// @ts-expect-error An explicit ordinary-governance caller is required.
prepareMetadataCitationOperation(prepared, "execute");
// @ts-expect-error A Registry call is not a reconstructed governance operation.
simulateMetadataCitationOperation(provider, inspection.plan.targetCall, { blockTag: 12 });
// @ts-expect-error Moving block tags are outside this pinned workflow.
captureMetadataCitation(provider, deployment, key, { blockTag: "latest" });
// @ts-expect-error There is no delegatecall receipt path.
inspectMetadataCitationOperationReceipt(provider, op, { transactionHash: key, execution: "delegatecall" });
// @ts-expect-error HTML mode3 is outside the admitted JSON serving helper.
readMetadataCurrentCitation(provider, deployment, key, request, 3n, { blockTag: 20 });
// @ts-expect-error Raw renderer mode values use exact bigint values.
readMetadataCurrentCitation(provider, deployment, key, request, 1, { blockTag: 20 });
// @ts-expect-error Pins are immutable.
deployment.registry.codeHash = key;
// @ts-expect-error Captured evidence is immutable.
inspection.evidence.goldens.push(inspection.evidence.goldens[0]!);
// @ts-expect-error Nested request fields stay immutable.
result.request.core = actor;
// @ts-expect-error Simulation preserves the reviewed caller immutably.
simulation.operation.caller = actor;
