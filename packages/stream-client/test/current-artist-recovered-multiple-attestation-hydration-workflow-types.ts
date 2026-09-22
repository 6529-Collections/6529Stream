import type { Provider } from "ethers";
import type { Address, Hex } from "../src/generated/contracts.js";
import type { ArtistRecoveredMultipleAttestationHydrationInput } from "../src/current-artist-recovered-multiple-attestation-hydration.js";
import {
  captureArtistRecoveredMultipleAttestationHydration,
  simulateArtistRecoveredMultipleAttestationHydration,
  reconcileArtistRecoveredMultipleAttestationHydrationReceipt,
  inspectArtistRecoveredMultipleAttestationHydrationHistory,
  inspectArtistRecoveredMultipleAttestationHydrationCurrent,
  type ArtistRecoveredMultipleAttestationHydrationCapture,
  type ArtistRecoveredMultipleAttestationHydrationDeployment,
} from "../src/current-artist-recovered-multiple-attestation-hydration-workflow.js";
import { createSafeCallPlan } from "../src/safe-plan.js";

declare const provider: Provider;
declare const deployment: ArtistRecoveredMultipleAttestationHydrationDeployment;
declare const input: ArtistRecoveredMultipleAttestationHydrationInput;
declare const caller: Address;
declare const digest: Hex;
declare const captured: ArtistRecoveredMultipleAttestationHydrationCapture;

const capture = await captureArtistRecoveredMultipleAttestationHydration(provider, deployment, caller, input, {
  blockTag: 10,
  gasLimit: 10_000_000n,
});
const observationOnly: false = capture.registrySimulated;
const originalNonceWord: bigint = capture.owners[2]!.payload.nonces[0]!.words[0]!.words[0]!;
const checked = await simulateArtistRecoveredMultipleAttestationHydration(provider, capture, { blockTag: 11, gasLimit: 10_000_000n });
const simulated: true = checked.registrySimulated;
const promised: false = checked.futureExecutionGuaranteed;
const direct = await reconcileArtistRecoveredMultipleAttestationHydrationReceipt(provider, checked.capture, digest, { execution: "direct" });
const safe = await reconcileArtistRecoveredMultipleAttestationHydrationReceipt(provider, checked.capture, digest, {
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
const originalClocks: true = safe.originalArchiveClockReadbackVerifiedAtReceipt;
const immutableAttestations: true = safe.retainedAttestationRowsReadBack;
const history = await inspectArtistRecoveredMultipleAttestationHydrationHistory(provider, captured, digest, { execution: "direct" });
const current = await inspectArtistRecoveredMultipleAttestationHydrationCurrent(provider, deployment, caller, input, { blockTag: 12, gasLimit: 10_000_000n });
const freshImportSimulation: true = current.registrySimulated;
void [observationOnly, originalNonceWord, simulated, promised, historical, authority, root, pageHash];
void createSafeCallPlan;
void [privateLanes, privateState, safeImplementation, signatures, history, freshImportSimulation, originalClocks, immutableAttestations];

// @ts-expect-error An explicit concrete block is mandatory.
captureArtistRecoveredMultipleAttestationHydration(provider, deployment, caller, input, { blockTag: "latest", gasLimit: 1n });
// @ts-expect-error Original preparation needs an explicit gas bound.
captureArtistRecoveredMultipleAttestationHydration(provider, deployment, caller, input, { blockTag: 10 });
// @ts-expect-error Gas quantities retain exact bigint semantics.
simulateArtistRecoveredMultipleAttestationHydration(provider, captured, { blockTag: 11, gasLimit: 1_000_000 });
// @ts-expect-error The library certificate alone is not a reviewed capture.
simulateArtistRecoveredMultipleAttestationHydration(provider, captured.certificate, { blockTag: 11, gasLimit: 1n });
// @ts-expect-error Safe verification requires an independently supplied transaction hash.
reconcileArtistRecoveredMultipleAttestationHydrationReceipt(provider, captured, digest, { execution: "safe" });
// @ts-expect-error A Safe digest alone omits the reviewed nonce and runtime pin.
reconcileArtistRecoveredMultipleAttestationHydrationReceipt(provider, captured, digest, { execution: "safe", expectedSafeTxHash: digest });
// @ts-expect-error Delegatecall is not an original recovered Registry transport.
reconcileArtistRecoveredMultipleAttestationHydrationReceipt(provider, captured, digest, { execution: "delegatecall" });
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
// @ts-expect-error Readback is fixed to original Archive evidence, not caller-selected clock bytes.
capture.originalClockOverrides;
// @ts-expect-error Retained attestation terms cannot be reordered after capture.
requestWitnesses[0]!.attestations.reverse();
