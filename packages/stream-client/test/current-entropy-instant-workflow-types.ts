import type { Provider } from "ethers";
import type { Address, Hex } from "../src/generated/contracts.js";
import {
  captureEntropyInstantPolicy, inspectEntropyInstantPolicy, captureEntropyInstantPolicyConsent,
  simulateEntropyInstantPolicyConsent, inspectEntropyInstantPolicyConsentReceipt,
  prepareEntropyInstantPolicyGovernance, prepareEntropyInstantPolicyOperation,
  simulateEntropyInstantPolicyOperation, inspectEntropyInstantPolicyReceipt,
  type EntropyInstantPolicyDeployment, type EntropyInstantPolicyCapture,
  type EntropyInstantPolicyInspection, type EntropyInstantPolicyConsentCapture,
  type EntropyInstantPolicyOperation, type EntropyInstantPolicyReceipt
} from "../src/current-entropy-instant-workflow.js";
import { prepareEntropyInstantPolicyArtistConsent, type EntropyInstantPolicyInput,
  type EntropyInstantPolicyGovernanceWindow } from "../src/current-entropy-instant.js";
import { createSafeCallPlan } from "../src/safe-plan.js";
import { CURRENT_ENTROPY_INSTANT_GOVERNANCE_ABI } from "../src/current-entropy-instant.js";

declare const provider: Provider;
declare const deployment: EntropyInstantPolicyDeployment;
declare const input: EntropyInstantPolicyInput;
declare const window: EntropyInstantPolicyGovernanceWindow;
declare const caller: Address;
declare const signer: Address;
declare const transactionHash: Hex;
declare const capture: EntropyInstantPolicyCapture;
declare const inspection: EntropyInstantPolicyInspection;
declare const consentCapture: EntropyInstantPolicyConsentCapture;
declare const operation: EntropyInstantPolicyOperation;
declare const receipt: EntropyInstantPolicyReceipt;

async function examples(): Promise<void> {
  const c = await captureEntropyInstantPolicy(provider, deployment, 1n, { blockTag: 10 });
  const i = await inspectEntropyInstantPolicy(provider, c, { kind: "configure", input });
  await inspectEntropyInstantPolicy(provider, c, { kind: "freeze" });
  const consent = prepareEntropyInstantPolicyArtistConsent(i.plan, deployment.artist.registry.address, caller, signer,
    { nonce: 1n, deadline: 1000n, signature: "0x" });
  const cc = await captureEntropyInstantPolicyConsent(provider, i, consent);
  const simulation = await simulateEntropyInstantPolicyConsent(provider, cc, { blockTag: 10 });
  const record: Hex = simulation.recordHash;
  const cr = await inspectEntropyInstantPolicyConsentReceipt(provider, cc, { transactionHash, execution: "safe" });
  const bytes: Hex = cr.archiveBytes;
  const gov = prepareEntropyInstantPolicyGovernance(i, caller, window);
  for (const stage of ["publish", "schedule", "execute"] as const) {
    const op = prepareEntropyInstantPolicyOperation(gov, stage, caller);
    await simulateEntropyInstantPolicyOperation(provider, op, { blockTag: 10 });
    const r = await inspectEntropyInstantPolicyReceipt(provider, op, { transactionHash, execution: "direct" });
    const mode: 0n | 1n | 2n | undefined = r.observed?.record.mode;
    createSafeCallPlan(1n, "Reviewed policy", [{ safe: caller, intent: stage, call: op.call, abi: CURRENT_ENTROPY_INSTANT_GOVERNANCE_ABI }]);
    void mode;
  }
  void record; void bytes;
  // @ts-expect-error returned simulations are readonly
  simulation.recordHash = transactionHash;
}
void examples;
// @ts-expect-error moving block tags are outside the pinned workflow
captureEntropyInstantPolicy(provider, deployment, 1n, { blockTag: "latest" });
// @ts-expect-error collection IDs are bigint
captureEntropyInstantPolicy(provider, deployment, 1, { blockTag: 10 });
// @ts-expect-error unsupported new policy route
inspectEntropyInstantPolicy(provider, capture, { kind: "instant" });
// @ts-expect-error configure requires complete original PolicyInput
inspectEntropyInstantPolicy(provider, capture, { kind: "configure" });
// @ts-expect-error actual caller is required
prepareEntropyInstantPolicyOperation(prepareEntropyInstantPolicyGovernance(inspection, caller, window), "execute");
// @ts-expect-error consent simulation requires consent capture, not a policy inspection
simulateEntropyInstantPolicyConsent(provider, inspection, { blockTag: 10 });
// @ts-expect-error no transaction signing/broadcast stage
prepareEntropyInstantPolicyOperation(prepareEntropyInstantPolicyGovernance(inspection, caller, window), "broadcast", caller);
// @ts-expect-error delegatecall is outside supported receipt transport
inspectEntropyInstantPolicyReceipt(provider, operation, { transactionHash, execution: "delegatecall" });
// @ts-expect-error retained nested runtime pins are immutable
deployment.artist.components[0]!.codeHash = transactionHash;
// @ts-expect-error full policy records are immutable
capture.record.providerEpoch = 9n;
// @ts-expect-error consent authority evidence is immutable
consentCapture.authority.authorityClass = 3n;
// @ts-expect-error receipts are immutable
receipt.observed = capture;

import {
  captureEntropyInstantRequest, simulateEntropyInstantRequest, inspectEntropyInstantRequestReceipt,
  readEntropyInstantTerminalFacts, type EntropyInstantRequestDeployment, type EntropyInstantRequestCapture,
  type EntropyInstantRequestSimulation, type EntropyInstantFactsCapture, type EntropyInstantRequestReceipt
} from "../src/current-entropy-instant-workflow.js";
import { CURRENT_ENTROPY_INSTANT_ABI } from "../src/current-entropy-instant.js";
declare const requestDeployment: EntropyInstantRequestDeployment;
declare const requestCapture: EntropyInstantRequestCapture;
declare const requestSimulation: EntropyInstantRequestSimulation;
declare const directFacts: EntropyInstantFactsCapture;
declare const requestReceipt: EntropyInstantRequestReceipt;
async function requestExamples(): Promise<void> {
  const c = await captureEntropyInstantRequest(provider, requestDeployment, 7n, caller, 12n, { blockTag: 10 });
  const simulation = await simulateEntropyInstantRequest(provider, c, { blockTag: 11 });
  const unknownOrRaw: Hex | undefined = simulation.providerResult?.rawRandomness;
  const receipt = await inspectEntropyInstantRequestReceipt(provider, c, { transactionHash, execution: "safe" });
  const credited: bigint = receipt.credited;
  const observed: bigint = receipt.accounting.callerCredit;
  const pending: boolean = receipt.metadataNotificationPending;
  const facts = await readEntropyInstantTerminalFacts(provider, requestDeployment, 7n, { blockTag: 11 });
  const actualStatus: bigint = facts.facts.status;
  createSafeCallPlan(1n, "Original request", [{ safe: caller, intent: "Request delayed entropy", call: c.plan.call, abi: CURRENT_ENTROPY_INSTANT_ABI }]);
  void unknownOrRaw; void credited; void observed; void pending; void actualStatus;
}
void requestExamples;
// @ts-expect-error no ordinary current-policy deployment is required, but original Coordinator pin is mandatory
captureEntropyInstantRequest(provider, { chainId: 1n, core: requestDeployment.core }, 7n, caller, 0n, { blockTag: 10 });
// @ts-expect-error request value is bigint, not a lossy number
captureEntropyInstantRequest(provider, requestDeployment, 7n, caller, 1, { blockTag: 10 });
// @ts-expect-error no moving block tag
readEntropyInstantTerminalFacts(provider, requestDeployment, 7n, { blockTag: "latest" });
// @ts-expect-error a policy capture is not a request capture
simulateEntropyInstantRequest(provider, capture, { blockTag: 10 });
// @ts-expect-error request receipt accepts ordinary CALL only
inspectEntropyInstantRequestReceipt(provider, requestCapture, { transactionHash, execution: "delegatecall" });
// @ts-expect-error this profile does not claim callback or VRF entropy
captureEntropyInstantRequest(provider, { ...requestDeployment, providerProfile: "vrf" }, 7n, caller, 0n, { blockTag: 10 });
// @ts-expect-error request snapshot and nested original mint commitment are immutable
requestCapture.plan.snapshot.subject.inputsHash = transactionHash;
// @ts-expect-error generic simulation result is nullable, not a guaranteed nested provider result
const raw: Hex = requestSimulation.providerResult.rawRandomness;
// @ts-expect-error actual direct facts do not invent terminality by method name
const terminal: boolean = directFacts.terminal;
// @ts-expect-error receipt accounting observations are immutable
requestReceipt.accounting.callerCredit = 0n;
// @ts-expect-error explicit INSTANT input only admits LOW_SECURITY
const wrongSecurity: EntropyInstantPolicyInput = { ...input, securityClass: 0n };
// @ts-expect-error new module's mutation input does not admit ASYNC
const wrongMode: EntropyInstantPolicyInput = { ...input, mode: 2n };
