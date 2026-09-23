import type { Provider } from "ethers";
import type { Address, Hex } from "../src/generated/contracts.js";
import type { ArtistRecoveredMultipleHydrationRequest } from "../src/current-artist-recovered-multiple-hydration.js";
import {
  captureArtistRecoveredMultipleHydration,
  simulateArtistRecoveredMultipleHydration,
  reconcileArtistRecoveredMultipleHydrationReceipt,
  inspectArtistRecoveredMultipleHydrationHistory,
  inspectArtistRecoveredMultipleHydrationCurrent,
  type ArtistRecoveredMultipleHydrationCapture,
  type ArtistRecoveredMultipleHydrationDeployment,
} from "../src/current-artist-recovered-multiple-hydration-workflow.js";
import { createSafeCallPlan } from "../src/safe-plan.js";

declare const provider: Provider;
declare const deployment: ArtistRecoveredMultipleHydrationDeployment;
declare const request: ArtistRecoveredMultipleHydrationRequest;
declare const caller: Address;
declare const digest: Hex;
declare const captured: ArtistRecoveredMultipleHydrationCapture;

const capture = await captureArtistRecoveredMultipleHydration(provider, deployment, caller, request, {
  blockTag: 10,
  gasLimit: 10_000_000n,
});
const observationOnly: false = capture.registrySimulated;
const originalNonceWord: bigint = capture.owners[2]!.payload.nonces[0]!.words[0]!.words[0]!;
const checked = await simulateArtistRecoveredMultipleHydration(provider, capture, { blockTag: 11, gasLimit: 10_000_000n });
const simulated: true = checked.registrySimulated;
const promised: false = checked.futureExecutionGuaranteed;
const direct = await reconcileArtistRecoveredMultipleHydrationReceipt(provider, checked.capture, digest, { execution: "direct" });
const safe = await reconcileArtistRecoveredMultipleHydrationReceipt(provider, checked.capture, digest, {
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
const history = await inspectArtistRecoveredMultipleHydrationHistory(provider, captured, digest, { execution: "direct" });
const current = await inspectArtistRecoveredMultipleHydrationCurrent(provider, deployment, caller, request, { blockTag: 12, gasLimit: 10_000_000n });
const freshImportSimulation: true = current.registrySimulated;
void [observationOnly, originalNonceWord, simulated, promised, historical, authority, root, pageHash];
void createSafeCallPlan;
void [privateLanes, privateState, safeImplementation, signatures, history, freshImportSimulation];

// @ts-expect-error An explicit concrete block is mandatory.
captureArtistRecoveredMultipleHydration(provider, deployment, caller, request, { blockTag: "latest", gasLimit: 1n });
// @ts-expect-error Original preparation needs an explicit gas bound.
captureArtistRecoveredMultipleHydration(provider, deployment, caller, request, { blockTag: 10 });
// @ts-expect-error Gas quantities retain exact bigint semantics.
simulateArtistRecoveredMultipleHydration(provider, captured, { blockTag: 11, gasLimit: 1_000_000 });
// @ts-expect-error The library certificate alone is not a reviewed capture.
simulateArtistRecoveredMultipleHydration(provider, captured.certificate, { blockTag: 11, gasLimit: 1n });
// @ts-expect-error Safe verification requires an independently supplied transaction hash.
reconcileArtistRecoveredMultipleHydrationReceipt(provider, captured, digest, { execution: "safe" });
// @ts-expect-error A Safe digest alone omits the reviewed nonce and runtime pin.
reconcileArtistRecoveredMultipleHydrationReceipt(provider, captured, digest, { execution: "safe", expectedSafeTxHash: digest });
// @ts-expect-error Delegatecall is not an original recovered Registry transport.
reconcileArtistRecoveredMultipleHydrationReceipt(provider, captured, digest, { execution: "delegatecall" });
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
