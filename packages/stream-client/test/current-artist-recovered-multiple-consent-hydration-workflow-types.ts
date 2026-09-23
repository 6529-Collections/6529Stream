import type { Provider } from "ethers";
import type { Address, Hex } from "../src/generated/contracts.js";
import type { ArtistRecoveredMultipleConsentHydrationInput } from "../src/current-artist-recovered-multiple-consent-hydration.js";
import {
  captureArtistRecoveredMultipleConsentHydration,
  simulateArtistRecoveredMultipleConsentHydration,
  reconcileArtistRecoveredMultipleConsentHydrationReceipt,
  inspectArtistRecoveredMultipleConsentHydrationHistory,
  inspectArtistRecoveredMultipleConsentHydrationCurrent,
  type ArtistRecoveredMultipleConsentHydrationCapture,
  type ArtistRecoveredMultipleConsentHydrationDeployment,
} from "../src/current-artist-recovered-multiple-consent-hydration-workflow.js";
import { createSafeCallPlan } from "../src/safe-plan.js";

declare const provider: Provider;
declare const deployment: ArtistRecoveredMultipleConsentHydrationDeployment;
declare const input: ArtistRecoveredMultipleConsentHydrationInput;
declare const caller: Address;
declare const digest: Hex;
declare const captured: ArtistRecoveredMultipleConsentHydrationCapture;

const capture = await captureArtistRecoveredMultipleConsentHydration(provider, deployment, caller, input, {
  blockTag: 10,
  gasLimit: 10_000_000n,
});
const observationOnly: false = capture.registrySimulated;
const originalNonceWord: bigint = capture.owners[2]!.payload.nonces[0]!.words[0]!.words[0]!;
const checked = await simulateArtistRecoveredMultipleConsentHydration(provider, capture, { blockTag: 11, gasLimit: 10_000_000n });
const simulated: true = checked.registrySimulated;
const promised: false = checked.futureExecutionGuaranteed;
const direct = await reconcileArtistRecoveredMultipleConsentHydrationReceipt(provider, checked.capture, digest, { execution: "direct" });
const safe = await reconcileArtistRecoveredMultipleConsentHydrationReceipt(provider, checked.capture, digest, {
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
const history = await inspectArtistRecoveredMultipleConsentHydrationHistory(provider, captured, digest, { execution: "direct" });
const current = await inspectArtistRecoveredMultipleConsentHydrationCurrent(provider, deployment, caller, input, { blockTag: 12, gasLimit: 10_000_000n });
const freshImportSimulation: true = current.registrySimulated;
void [observationOnly, originalNonceWord, simulated, promised, historical, authority, root, pageHash];
void createSafeCallPlan;
void [privateLanes, privateState, safeImplementation, signatures, history, freshImportSimulation];

// @ts-expect-error An explicit concrete block is mandatory.
captureArtistRecoveredMultipleConsentHydration(provider, deployment, caller, input, { blockTag: "latest", gasLimit: 1n });
// @ts-expect-error Original preparation needs an explicit gas bound.
captureArtistRecoveredMultipleConsentHydration(provider, deployment, caller, input, { blockTag: 10 });
// @ts-expect-error Gas quantities retain exact bigint semantics.
simulateArtistRecoveredMultipleConsentHydration(provider, captured, { blockTag: 11, gasLimit: 1_000_000 });
// @ts-expect-error The library certificate alone is not a reviewed capture.
simulateArtistRecoveredMultipleConsentHydration(provider, captured.certificate, { blockTag: 11, gasLimit: 1n });
// @ts-expect-error Safe verification requires an independently supplied transaction hash.
reconcileArtistRecoveredMultipleConsentHydrationReceipt(provider, captured, digest, { execution: "safe" });
// @ts-expect-error A Safe digest alone omits the reviewed nonce and runtime pin.
reconcileArtistRecoveredMultipleConsentHydrationReceipt(provider, captured, digest, { execution: "safe", expectedSafeTxHash: digest });
// @ts-expect-error Delegatecall is not an original recovered Registry transport.
reconcileArtistRecoveredMultipleConsentHydrationReceipt(provider, captured, digest, { execution: "delegatecall" });
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

const suppliedRoyaltyTerms = capture.prepared.royaltyFreezes;
const requestWitnesses = capture.prepared.request.records.witnesses;
// @ts-expect-error Complete ordered royalty inputs cannot be mutated after capture.
suppliedRoyaltyTerms.push(suppliedRoyaltyTerms[0]!);
// @ts-expect-error Economics witnesses remain a readonly source-order inventory.
requestWitnesses[0]!.economics.push(requestWitnesses[0]!.economics[0]!);
// @ts-expect-error No new Artist signature request is introduced by hydration.
capture.prepared.signingPayload;
