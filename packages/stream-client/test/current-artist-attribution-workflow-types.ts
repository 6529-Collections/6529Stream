import {
  captureArtistAttribution, simulateArtistAttribution, reconcileArtistAttributionReceipt,
  inspectArtistAttributionHistory, inspectArtistAttributionCurrent, observeArtistAttributionRefusal,
  type ArtistAttributionDeployment, type ArtistAttributionHistoryDeployment,
  type ArtistAttributionReceiptReader, type ArtistAttributionReceiptOptions,
  type ArtistAttributionCapture, type ArtistAttributionWorkflowOptions
} from "../src/current-artist-attribution-workflow.js";
import type { ArtistAttributionRequest } from "../src/current-artist-attribution.js";
import type { GovernanceExecutorV2Capture } from "../src/current-governance-executor-v2-workflow.js";
import type { Address, Hex } from "../src/generated/contracts.js";
declare const provider: ArtistAttributionReceiptReader;
declare const deployment: ArtistAttributionDeployment;
declare const historyDeployment: ArtistAttributionHistoryDeployment;
declare const actor: Address;
declare const request: ArtistAttributionRequest;
declare const hash: Hex;
declare const capture: ArtistAttributionCapture;
declare const governance: GovernanceExecutorV2Capture;
const options: ArtistAttributionWorkflowOptions = { blockTag: 100, gasLimit: 9000000n, governance };
const receiptOptions: ArtistAttributionReceiptOptions = { execution: "safe", expectedSafeTxHash: hash, nonce: 1n, safeCodeHash: hash };
void captureArtistAttribution(provider, deployment, actor, request, options);
void simulateArtistAttribution(provider, capture, { blockTag: 100, gasLimit: 9000000n });
void reconcileArtistAttributionReceipt(provider, capture, hash, receiptOptions);
void inspectArtistAttributionCurrent(provider, deployment, actor, request, options);
void observeArtistAttributionRefusal(provider, capture, { blockTag: 101, gasLimit: 9000000n });
void inspectArtistAttributionHistory(provider, historyDeployment, { operationId: 61n, actor, value: hash }, { blockTag: 101, gasLimit: 9000000n, retainedPayload: hash });
const admission: false = capture.originalCallAdmissionChecked;
const privateEffects: false = capture.privateAuxiliaryEffectsIndependentlyReconstructed;
void admission; void privateEffects;
// @ts-expect-error Real fixed block is required.
void captureArtistAttribution(provider, deployment, actor, request, { blockTag: "latest", gasLimit: 9000000n });
// @ts-expect-error Safe hash/nonce/runtime witness cannot be omitted.
void reconcileArtistAttributionReceipt(provider, capture, hash, { execution: "safe" });
// @ts-expect-error Governed route consumes original Executor capture, not an arbitrary actor override.
void captureArtistAttribution(provider, deployment, actor, request, { ...options, governance: { executor: actor } });
// @ts-expect-error Captured owner snapshots are immutable.
capture.observation.before[0]!.revision = 1n;
// @ts-expect-error Capture's public facts map is immutable.
capture.observation.facts.binding = null;
// @ts-expect-error Private admission is explicitly unproved.
const independentlyAdmitted: true = capture.originalCallAdmissionChecked;
void independentlyAdmitted;
