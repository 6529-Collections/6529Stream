import type { Provider } from "ethers";
import type { Address, Hex } from "../src/generated/contracts.js";
import type { ScopedPolicyReferenceV2Publication, ScopedPolicyReferenceV2Request } from "../src/current-scoped-policy-reference-v2.js";
import {
  previewScopedPolicyReferenceV2,
  captureScopedPolicyReferenceV2,
  simulateScopedPolicyReferenceV2,
  reconcileScopedPolicyReferenceV2Receipt,
  inspectScopedPolicyReferenceV2History,
  inspectScopedPolicyReferenceV2Current,
  observeScopedPolicyReferenceV2Refusal,
  type ScopedPolicyReferenceV2Deployment,
  type ScopedPolicyReferenceV2HistoryDeployment,
  type ScopedPolicyReferenceV2WorkflowCapture
} from "../src/current-scoped-policy-reference-v2-workflow.js";

declare const provider: Provider;
declare const deployment: ScopedPolicyReferenceV2Deployment;
declare const local: ScopedPolicyReferenceV2HistoryDeployment;
declare const caller: Address;
declare const hash: Hex;
declare const publication: ScopedPolicyReferenceV2Publication;
declare const request: ScopedPolicyReferenceV2Request;
declare const capture: ScopedPolicyReferenceV2WorkflowCapture;

void previewScopedPolicyReferenceV2(provider, deployment, caller, publication, { blockTag: 10 });
void captureScopedPolicyReferenceV2(provider, deployment, caller, request, { blockTag: 10 });
void simulateScopedPolicyReferenceV2(provider, capture, { blockTag: 11, gasLimit: 10000000n });
void reconcileScopedPolicyReferenceV2Receipt(provider, capture, hash, { execution: "direct" });
void reconcileScopedPolicyReferenceV2Receipt(provider, capture, hash, { execution: "safe", expectedSafeTxHash: hash });
void inspectScopedPolicyReferenceV2History(provider, local, hash, { blockTag: 12 });
void inspectScopedPolicyReferenceV2Current(provider, deployment, publication.scope, { blockTag: 12 });
void observeScopedPolicyReferenceV2Refusal(provider, capture, { blockTag: 11, gasLimit: 10000000n });
// @ts-expect-error The Safe transaction hash must be supplied independently.
void reconcileScopedPolicyReferenceV2Receipt(provider, capture, hash, { execution: "safe" });
// @ts-expect-error Calls use a concrete observed block number.
void simulateScopedPolicyReferenceV2(provider, capture, { blockTag: "latest", gasLimit: 10000000n });
// @ts-expect-error Simulation requires a bounded gas limit.
void simulateScopedPolicyReferenceV2(provider, capture, { blockTag: 11 });
// @ts-expect-error Captured deployment pins are immutable.
capture.deployment.reference.codeHash = hash;
// @ts-expect-error Linked runtime inventories cannot be mutated through saved captures.
capture.deployment.linkedDependencies.history.push({ address: caller, codeHash: hash });
if (capture.stage.kind === "publication") {
  // @ts-expect-error Source witnesses remain recursively readonly.
  capture.stage.preview.source.samples[0]!.observation.collectionSerial = 1n;
  // @ts-expect-error A retained source hash cannot be edited in place.
  capture.stage.preview.receipt.observation.sourcesHash = hash;
} else {
  const before: boolean = capture.stage.retainedBefore;
  // @ts-expect-error Preparation evidence is readonly.
  capture.stage.prerequisites.push({ identity: hash, canonical: "0x" });
  void before;
}
async function outputs() {
  const preview = await previewScopedPolicyReferenceV2(provider, deployment, caller, publication, { blockTag: 10 });
  const noAvailability: false = preview.storeAvailabilityChecked;
  const simulation = await simulateScopedPolicyReferenceV2(provider, capture, { blockTag: 11, gasLimit: 10000000n });
  const notPersisted: false = simulation.persisted;
  const history = await inspectScopedPolicyReferenceV2History(provider, local, hash, { blockTag: 12 });
  const notCurrent: false = history.currentnessChecked;
  const current = await inspectScopedPolicyReferenceV2Current(provider, deployment, publication.scope, { blockTag: 12 });
  const checked: true = current.currentnessChecked;
  const receipt = await reconcileScopedPolicyReferenceV2Receipt(provider, capture, hash, { execution: "direct" });
  const noFinality: false = receipt.finalityEstablished;
  const refusal = await observeScopedPolicyReferenceV2Refusal(provider, capture, { blockTag: 11, gasLimit: 10000000n });
  const noRollback: false = refusal.rollbackProven;
  const outcome: "execution-reverted" | "rpc-failed" = refusal.outcome;
  void [noAvailability, notPersisted, notCurrent, checked, noFinality, noRollback, outcome];
}
void outputs;
