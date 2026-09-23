import type { Provider } from "ethers";
import type { Address, Hex } from "../src/generated/contracts.js";
import type { ArtistUnboundPlatformHydrationInput } from "../src/current-artist-unbound-platform-hydration.js";
import {
  captureArtistUnboundPlatformHydration,
  simulateArtistUnboundPlatformHydration,
  reconcileArtistUnboundPlatformHydrationReceipt,
  inspectArtistUnboundPlatformHydrationHistory,
  inspectArtistUnboundPlatformHydrationCurrent,
  observeArtistUnboundPlatformHydrationRefusal,
  type ArtistUnboundPlatformHydrationCapture,
  type ArtistUnboundPlatformHydrationDeployment,
} from "../src/current-artist-unbound-platform-hydration-workflow.js";
import { createSafeCallPlan } from "../src/safe-plan.js";

declare const provider: Provider;
declare const deployment: ArtistUnboundPlatformHydrationDeployment;
declare const input: ArtistUnboundPlatformHydrationInput;
declare const caller: Address;
declare const digest: Hex;
declare const captured: ArtistUnboundPlatformHydrationCapture;

const capture = await captureArtistUnboundPlatformHydration(provider, deployment, caller, input, {
  blockTag: 10,
  gasLimit: 10_000_000n,
});
const observationOnly: false = capture.registrySimulated;
const originalNonceWord: bigint | undefined = capture.owners[2]!.payload.nonces[0]?.words[0]?.words[0];
const checked = await simulateArtistUnboundPlatformHydration(provider, capture, { blockTag: 11, gasLimit: 10_000_000n });
const simulated: true = checked.registrySimulated;
const promised: false = checked.futureExecutionGuaranteed;
const direct = await reconcileArtistUnboundPlatformHydrationReceipt(provider, checked.capture, digest, { execution: "direct" });
const safe = await reconcileArtistUnboundPlatformHydrationReceipt(provider, checked.capture, digest, {
  execution: "safe",
  expectedSafeTxHash: digest,
  nonce: 0n,
  safeCodeHash: digest,
});
const historical: true = safe.historicalImportProven;
const authority: false = safe.currentAuthorityClaimed;
const root: Hex = direct.ownerSnapshots[2]!.stateRoot;
const pageHash: Hex = direct.descriptor.pageHashes[0]!;
const privateLanes: false = safe.laneActivationIndependentlyVerified;
const privateState: false = safe.privateSemanticInstallationIndependentlyVerified;
const safeImplementation: false = safe.safeImplementationIndependentlyVerified;
const signatures: false = safe.ownerSignaturesIndependentlyVerified;
const originalClocks: true = safe.originalPlatformArchiveReadbackVerifiedAtReceipt;
const immutablePlatform: true = safe.retainedPlatformRowsReadBack;
const completePlatform: true = safe.completePlatformInventoryReadBack;
const history = await inspectArtistUnboundPlatformHydrationHistory(provider, captured, digest, { execution: "direct" });
const current = await inspectArtistUnboundPlatformHydrationCurrent(provider, deployment, caller, input, { blockTag: 12, gasLimit: 10_000_000n });
const freshImportSimulation: true = current.registrySimulated;
void [observationOnly, originalNonceWord, simulated, promised, historical, authority, root, pageHash];
void createSafeCallPlan;
void completePlatform;
const refusal = await observeArtistUnboundPlatformHydrationRefusal(provider, captured, { blockTag: 12, gasLimit: 10_000_000n });
const notPrediction: false = refusal.capturePredictionChecked;
const notFuture: false = refusal.futureExecutionGuaranteed;
if (refusal.status === "succeeded") { const actual: Hex = refusal.returnedCommitment; void actual; }
void [notPrediction, notFuture];
void [privateLanes, privateState, safeImplementation, signatures, history, freshImportSimulation, originalClocks, immutablePlatform];

// @ts-expect-error An explicit concrete block is mandatory.
captureArtistUnboundPlatformHydration(provider, deployment, caller, input, { blockTag: "latest", gasLimit: 1n });
// @ts-expect-error Original preparation needs an explicit gas bound.
captureArtistUnboundPlatformHydration(provider, deployment, caller, input, { blockTag: 10 });
// @ts-expect-error Gas quantities retain exact bigint semantics.
simulateArtistUnboundPlatformHydration(provider, captured, { blockTag: 11, gasLimit: 1_000_000 });
// @ts-expect-error The library certificate alone is not a reviewed capture.
simulateArtistUnboundPlatformHydration(provider, captured.certificate, { blockTag: 11, gasLimit: 1n });
// @ts-expect-error Safe verification requires an independently supplied transaction hash.
reconcileArtistUnboundPlatformHydrationReceipt(provider, captured, digest, { execution: "safe" });
// @ts-expect-error A Safe digest alone omits the reviewed nonce and runtime pin.
reconcileArtistUnboundPlatformHydrationReceipt(provider, captured, digest, { execution: "safe", expectedSafeTxHash: digest });
// @ts-expect-error Delegatecall is not an original recovered Registry transport.
reconcileArtistUnboundPlatformHydrationReceipt(provider, captured, digest, { execution: "delegatecall" });
// @ts-expect-error Trusted source/runtime pins remain immutable.
deployment.preparationLibrary.codeHash = digest;
// @ts-expect-error Retained complete provenance remains immutable.
captured.certificate.admission.provenance.origins.push(captured.certificate.admission.provenance.origins[0]!);
// @ts-expect-error Recovered nonce words cannot be modified after capture.
captured.owners[2]!.payload.nonces[0]!.words[0]!.words[0] = 0n;
// @ts-expect-error The permissionless actor is still an exact immutable transport input.
captured.prepared.caller = caller;
// @ts-expect-error No source capability is inferred from a mutable label.
captured.owners[0]!.sourceCapability.supportedFeatures = 511n;
// @ts-expect-error Readback cannot become a current authority assertion.
safe.currentAuthorityClaimed = true;

const suppliedRoyaltyTerms: readonly never[] = capture.prepared.royaltyFreezes;
const requestWitnesses = capture.prepared.request.records.witnesses;
// @ts-expect-error The original unbound profile forbids royalty terms and retains an empty immutable list.
suppliedRoyaltyTerms.push(suppliedRoyaltyTerms[0]!);
// @ts-expect-error Economics witnesses remain a readonly source-order inventory.
requestWitnesses[0]!.economics.push(requestWitnesses[0]!.economics[0]!);
// @ts-expect-error No new Artist signature request is introduced by hydration.
capture.prepared.signingPayload;
// @ts-expect-error Readback is fixed to original Archive evidence, not caller-selected clock bytes.
capture.originalClockOverrides;
// @ts-expect-error Retained attestation terms cannot be reordered after capture.
requestWitnesses[0]!.attestations.reverse();

// @ts-expect-error No zero-Artist signing schema is invented by the workflow.
capture.prepared.zeroArtistAuthorization;
// @ts-expect-error Archive cutoffs cannot be caller-overridden after capture.
captured.owners[4]!.payload.provenance.eras[0]!.checkpoint.ownerState.revision = 3n;
// @ts-expect-error Refusal observation also requires a concrete numeric block.
observeArtistUnboundPlatformHydrationRefusal(provider, captured, { blockTag: "latest", gasLimit: 1_000_000n });
