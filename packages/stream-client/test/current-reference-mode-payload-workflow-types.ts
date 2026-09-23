import type { Provider } from "ethers";
import type { Address, Hex } from "../src/generated/contracts.js";
import type { ReferenceModePublication, ReferenceModeEvidence, ReferenceModePayloadSnapshot } from "../src/current-reference-mode-payload.js";
import type { ReferenceInventoryDeployment, ReferenceInventoryGasProvider } from "../src/current-reference-inventory-workflow.js";
import {
  captureReferenceModePreview, prepareReferenceModePayloadPlan, inspectReferenceModePayloadPreparation,
  simulateReferenceModePayloadStep, quoteReferenceModePayloadStepGas, inspectReferenceModePayloadStepReceipt
} from "../src/current-reference-mode-payload-workflow.js";
import type {
  ReferenceModePreview, PreparedReferenceModePayloadPlan, ReferenceModePayloadInspection,
  ReferenceModePayloadGasQuote, ReferenceModePayloadStepReceipt
} from "../src/current-reference-mode-payload-workflow.js";

declare const provider: Provider;
declare const gasProvider: ReferenceInventoryGasProvider;
declare const deployment: ReferenceInventoryDeployment;
declare const recorder: Address;
declare const uploader: Address;
declare const publication: ReferenceModePublication;
declare const evidence: ReferenceModeEvidence;
declare const snapshot: ReferenceModePayloadSnapshot;
declare const hash: Hex;
declare const observed: ReferenceModePreview;
declare const receipt: ReferenceModePayloadStepReceipt;

const preview: Promise<ReferenceModePreview> = captureReferenceModePreview(provider, deployment, recorder, publication, evidence, { blockTag: 100 });
const plan: PreparedReferenceModePayloadPlan = prepareReferenceModePayloadPlan(deployment, recorder, snapshot, { uploader });
const inspection: Promise<ReferenceModePayloadInspection> = inspectReferenceModePayloadPreparation(provider, plan, { blockTag: 100 });
const simulation: Promise<{ readonly identity: Hex; readonly pointer: Address | null }> = simulateReferenceModePayloadStep(provider, plan, 0, { blockTag: 100 });
const quote: Promise<ReferenceModePayloadGasQuote> = quoteReferenceModePayloadStepGas(gasProvider, plan, 0, { blockTag: 100, maximumGas: 100000n });
const mined: Promise<ReferenceModePayloadStepReceipt> = inspectReferenceModePayloadStepReceipt(provider, plan, 0, { transactionHash: hash, execution: "safe" });
const requiresPublicationSimulation: true = observed.publicationSimulationRequired;
const actualRecorder: Address = observed.snapshot.input.receipt.recorder;
const retention: "created" | "reused" = receipt.retention;
void preview; void inspection; void simulation; void quote; void mined; void requiresPublicationSimulation; void actualRecorder; void retention;

// @ts-expect-error preview requires the complete original Publication, not a preparation ID
captureReferenceModePreview(provider, deployment, recorder, hash, evidence, { blockTag: 100 });
// @ts-expect-error preview block must be concrete
captureReferenceModePreview(provider, deployment, recorder, publication, evidence, { blockTag: "latest" });
// @ts-expect-error preparation retains full normalized payload input, not just an identity
prepareReferenceModePayloadPlan(deployment, recorder, hash);
// @ts-expect-error observation is not signing or a successful final publication
const published: false = observed.publicationSimulationRequired;
// @ts-expect-error observed full publication is immutable
observed.snapshot.publication.publication.expectedSourcesHash = hash;
// @ts-expect-error original evidence fields are immutable
observed.submitted.evidence.mode = 2n;
// @ts-expect-error fixed dependency arrays are immutable
observed.dependencies.targets.push(recorder);
// @ts-expect-error uploader and preparer belong to typed planning options, not an unreviewed target override
prepareReferenceModePayloadPlan(deployment, recorder, snapshot, { target: uploader });
// @ts-expect-error steps are upload/preparation only; final publication is separate
const kind: "publish" = plan.steps[0]!.kind;
// @ts-expect-error receipt supports exact ordinary direct or Safe CALL, not delegatecall
inspectReferenceModePayloadStepReceipt(provider, plan, 0, { transactionHash: hash, execution: "delegatecall" });
// @ts-expect-error source-dependent receipt material is retained and immutable
receipt.plan.snapshot.input.receipt.grantRevision = 0n;
void published; void kind;
