import type { Provider } from "ethers";
import type { Address, Hex } from "../src/generated/contracts.js";
import {
  captureEntropyCollectionPolicy, inspectEntropyCollectionPolicy, captureEntropyCollectionPolicyConsent,
  simulateEntropyCollectionPolicyConsent, inspectEntropyCollectionPolicyConsentReceipt,
  prepareEntropyCollectionPolicyGovernance, prepareEntropyCollectionPolicyOperation,
  simulateEntropyCollectionPolicyOperation, inspectEntropyCollectionPolicyReceipt,
  type EntropyCollectionPolicyDeployment, type EntropyCollectionPolicyCapture,
  type EntropyCollectionPolicyInspection, type EntropyCollectionPolicyConsentCapture,
  type EntropyCollectionPolicyOperation, type EntropyCollectionPolicyReceipt
} from "../src/current-entropy-collection-policy-workflow.js";
import { prepareEntropyCollectionPolicyArtistConsent, type EntropyCollectionPolicyInput,
  type EntropyCollectionPolicyGovernanceWindow } from "../src/current-entropy-collection-policy.js";
import { createSafeCallPlan } from "../src/safe-plan.js";
import { CURRENT_ENTROPY_COLLECTION_POLICY_GOVERNANCE_ABI } from "../src/current-entropy-collection-policy.js";

declare const provider: Provider;
declare const deployment: EntropyCollectionPolicyDeployment;
declare const input: EntropyCollectionPolicyInput;
declare const window: EntropyCollectionPolicyGovernanceWindow;
declare const caller: Address;
declare const signer: Address;
declare const transactionHash: Hex;
declare const capture: EntropyCollectionPolicyCapture;
declare const inspection: EntropyCollectionPolicyInspection;
declare const consentCapture: EntropyCollectionPolicyConsentCapture;
declare const operation: EntropyCollectionPolicyOperation;
declare const receipt: EntropyCollectionPolicyReceipt;

async function examples(): Promise<void> {
  const c = await captureEntropyCollectionPolicy(provider, deployment, 1n, { blockTag: 10 });
  const i = await inspectEntropyCollectionPolicy(provider, c, { kind: "configure", input });
  await inspectEntropyCollectionPolicy(provider, c, { kind: "freeze" });
  const consent = prepareEntropyCollectionPolicyArtistConsent(i.plan, deployment.artist.registry.address, caller, signer,
    { nonce: 1n, deadline: 1000n, signature: "0x" });
  const cc = await captureEntropyCollectionPolicyConsent(provider, i, consent);
  const simulation = await simulateEntropyCollectionPolicyConsent(provider, cc, { blockTag: 10 });
  const record: Hex = simulation.recordHash;
  const cr = await inspectEntropyCollectionPolicyConsentReceipt(provider, cc, { transactionHash, execution: "safe" });
  const bytes: Hex = cr.archiveBytes;
  const gov = prepareEntropyCollectionPolicyGovernance(i, caller, window);
  for (const stage of ["publish", "schedule", "execute"] as const) {
    const op = prepareEntropyCollectionPolicyOperation(gov, stage, caller);
    await simulateEntropyCollectionPolicyOperation(provider, op, { blockTag: 10 });
    const r = await inspectEntropyCollectionPolicyReceipt(provider, op, { transactionHash, execution: "direct" });
    const mode: 0n | 1n | 2n | undefined = r.observed?.record.mode;
    createSafeCallPlan(1n, "Reviewed policy", [{ safe: caller, intent: stage, call: op.call, abi: CURRENT_ENTROPY_COLLECTION_POLICY_GOVERNANCE_ABI }]);
    void mode;
  }
  void record; void bytes;
  // @ts-expect-error returned simulations are readonly
  simulation.recordHash = transactionHash;
}
void examples;
// @ts-expect-error moving block tags are outside the pinned workflow
captureEntropyCollectionPolicy(provider, deployment, 1n, { blockTag: "latest" });
// @ts-expect-error collection IDs are bigint
captureEntropyCollectionPolicy(provider, deployment, 1, { blockTag: 10 });
// @ts-expect-error unsupported new policy route
inspectEntropyCollectionPolicy(provider, capture, { kind: "instant" });
// @ts-expect-error configure requires complete original PolicyInput
inspectEntropyCollectionPolicy(provider, capture, { kind: "configure" });
// @ts-expect-error actual caller is required
prepareEntropyCollectionPolicyOperation(prepareEntropyCollectionPolicyGovernance(inspection, caller, window), "execute");
// @ts-expect-error consent simulation requires consent capture, not a policy inspection
simulateEntropyCollectionPolicyConsent(provider, inspection, { blockTag: 10 });
// @ts-expect-error no transaction signing/broadcast stage
prepareEntropyCollectionPolicyOperation(prepareEntropyCollectionPolicyGovernance(inspection, caller, window), "broadcast", caller);
// @ts-expect-error delegatecall is outside supported receipt transport
inspectEntropyCollectionPolicyReceipt(provider, operation, { transactionHash, execution: "delegatecall" });
// @ts-expect-error retained nested runtime pins are immutable
deployment.artist.components[0]!.codeHash = transactionHash;
// @ts-expect-error full policy records are immutable
capture.record.providerEpoch = 9n;
// @ts-expect-error consent authority evidence is immutable
consentCapture.authority.authorityClass = 3n;
// @ts-expect-error receipts are immutable
receipt.observed = capture;
