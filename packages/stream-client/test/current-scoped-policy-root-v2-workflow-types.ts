import type { Provider } from "ethers";
import type { Address, Hex } from "../src/generated/contracts.js";
import type { ScopedPolicyRootV2Publication } from "../src/current-scoped-policy-root-v2.js";
import {
  previewScopedPolicyRootV2, captureScopedPolicyRootV2Consent, captureScopedPolicyRootV2,
  simulateScopedPolicyRootV2, reconcileScopedPolicyRootV2Receipt,
  inspectScopedPolicyRootV2History, inspectScopedPolicyRootV2Current, observeScopedPolicyRootV2Refusal,
  type ScopedPolicyRootV2Deployment, type ScopedPolicyRootV2HistoryDeployment,
  type ScopedPolicyRootV2Preview, type ScopedPolicyRootV2WorkflowCapture
} from "../src/current-scoped-policy-root-v2-workflow.js";

declare const provider: Provider;
declare const deployment: ScopedPolicyRootV2Deployment;
declare const local: ScopedPolicyRootV2HistoryDeployment;
declare const caller: Address;
declare const hash: Hex;
declare const publication: ScopedPolicyRootV2Publication;
declare const preview: ScopedPolicyRootV2Preview;
declare const capture: ScopedPolicyRootV2WorkflowCapture;
void previewScopedPolicyRootV2(provider, deployment, caller, publication, { blockTag: 10 });
void captureScopedPolicyRootV2Consent(provider, preview, caller, { signer: caller, nonce: 0n, deadline: 2000n, signature: "0x" });
void captureScopedPolicyRootV2(provider, deployment, caller, publication, { blockTag: 10 });
void simulateScopedPolicyRootV2(provider, capture, { blockTag: 11, gasLimit: 10000000n });
void reconcileScopedPolicyRootV2Receipt(provider, capture, hash, { execution: "direct" });
void reconcileScopedPolicyRootV2Receipt(provider, capture, hash, { execution: "safe", expectedSafeTxHash: hash });
void inspectScopedPolicyRootV2History(provider, local, hash, { transactionHash: hash, logIndex: 0 }, { blockTag: 12 });
void inspectScopedPolicyRootV2Current(provider, deployment, publication.scope, { blockTag: 12 });
void observeScopedPolicyRootV2Refusal(provider, capture, { blockTag: 11, gasLimit: 10000000n });
// @ts-expect-error Caller must provide an independent Safe transaction hash.
void reconcileScopedPolicyRootV2Receipt(provider, capture, hash, { execution: "safe" });
// @ts-expect-error Historical aggregate needs an original event locator.
void inspectScopedPolicyRootV2History(provider, local, hash, { blockTag: 12 });
// @ts-expect-error Exact concrete block only.
void simulateScopedPolicyRootV2(provider, capture, { blockTag: "latest", gasLimit: 10000000n });
// @ts-expect-error Nonce is bigint, including zero.
void captureScopedPolicyRootV2Consent(provider, preview, caller, { signer: caller, nonce: 0, deadline: 2000n, signature: "0x" });
// @ts-expect-error Reviewed route cannot be changed through captured facts.
capture.preview.deployment.provider.address = caller;
// @ts-expect-error Linked runtime inventory is readonly.
capture.preview.deployment.linkedDependencies.artist.push({ address: caller, codeHash: hash });
// @ts-expect-error Original next collection-family state is immutable.
capture.preview.nextFamily = hash;
if (capture.kind === "consent") {
  // @ts-expect-error Immutable native prefix count.
  capture.owners[0]!.nativeCount = 10n;
  const pending: Hex = capture.pendingEstateActivation;
  void pending;
} else {
  const original: Hex = capture.consent.recordHash;
  // @ts-expect-error Original consumed evidence is immutable.
  capture.consent.terms.newStateHash = hash;
  void original;
}
async function outputs() {
  const history = await inspectScopedPolicyRootV2History(provider, local, hash, { transactionHash: hash, logIndex: 0 }, { blockTag: 12 });
  const notCurrent: false = history.currentnessChecked;
  const profile: "v1" | "v2" = history.profile;
  const current = await inspectScopedPolicyRootV2Current(provider, deployment, publication.scope, { blockTag: 12 });
  const noEventAggregate: false = current.historicalAggregateAuthenticated;
  const receipt = await reconcileScopedPolicyRootV2Receipt(provider, capture, hash, { execution: "direct" });
  const noPrivateProof: false = receipt.privateIdentityActivityIndependentlyReconstructed;
  const noFinality: false = receipt.finalityEstablished;
  const refusal = await observeScopedPolicyRootV2Refusal(provider, capture, { blockTag: 11, gasLimit: 10000000n });
  const noRollbackProof: false = refusal.rollbackProven;
  void [notCurrent, profile, noEventAggregate, noPrivateProof, noFinality, noRollbackProof];
}
void outputs;
