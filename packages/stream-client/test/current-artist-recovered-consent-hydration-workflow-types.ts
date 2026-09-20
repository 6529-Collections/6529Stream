import type { Provider } from "ethers";
import type { Address, Hex } from "../src/generated/contracts.js";
import type { ArtistRecoveredConsentHydrationInput } from "../src/current-artist-recovered-consent-hydration.js";
import {
  captureArtistRecoveredConsentHydration,
  simulateArtistRecoveredConsentHydration,
  reconcileArtistRecoveredConsentHydrationReceipt,
  type ArtistRecoveredConsentHydrationCapture,
  type ArtistRecoveredConsentHydrationDeployment,
} from "../src/current-artist-recovered-consent-hydration-workflow.js";
import { createSafeCallPlan } from "../src/safe-plan.js";

declare const provider: Provider;
declare const deployment: ArtistRecoveredConsentHydrationDeployment;
declare const request: ArtistRecoveredConsentHydrationInput;
declare const caller: Address;
declare const digest: Hex;
declare const captured: ArtistRecoveredConsentHydrationCapture;

const capture = await captureArtistRecoveredConsentHydration(provider, deployment, caller, request, {
  blockTag: 10,
  gasLimit: 10_000_000n,
});
const observationOnly: false = capture.registrySimulated;
const originalNonceWord: bigint = capture.owners[2]!.payload.nonces[0]!.words[0]!.words[0]!;
const checked = await simulateArtistRecoveredConsentHydration(provider, capture, { blockTag: 11, gasLimit: 10_000_000n });
const simulated: true = checked.registrySimulated;
const promised: false = checked.futureExecutionGuaranteed;
const direct = await reconcileArtistRecoveredConsentHydrationReceipt(provider, checked.capture, digest, { execution: "direct" });
const safe = await reconcileArtistRecoveredConsentHydrationReceipt(provider, checked.capture, digest, {
  execution: "safe",
  expectedSafeTxHash: digest,
});
const historical: true = safe.historicalImportProven;
const authority: false = safe.currentAuthorityClaimed;
const root: Hex = direct.ownerSnapshots[2]!.stateRoot;
const pageHash: Hex = direct.descriptor.pageHashes[0]!;
void [observationOnly, originalNonceWord, simulated, promised, historical, authority, root, pageHash];
void createSafeCallPlan;

// @ts-expect-error An explicit concrete block is mandatory.
captureArtistRecoveredConsentHydration(provider, deployment, caller, request, { blockTag: "latest", gasLimit: 1n });
// @ts-expect-error Original preparation needs an explicit gas bound.
captureArtistRecoveredConsentHydration(provider, deployment, caller, request, { blockTag: 10 });
// @ts-expect-error Gas quantities retain exact bigint semantics.
simulateArtistRecoveredConsentHydration(provider, captured, { blockTag: 11, gasLimit: 1_000_000 });
// @ts-expect-error The library certificate alone is not a reviewed capture.
simulateArtistRecoveredConsentHydration(provider, captured.certificate, { blockTag: 11, gasLimit: 1n });
// @ts-expect-error Safe verification requires an independently supplied transaction hash.
reconcileArtistRecoveredConsentHydrationReceipt(provider, captured, digest, { execution: "safe" });
// @ts-expect-error Delegatecall is not an original recovered Registry transport.
reconcileArtistRecoveredConsentHydrationReceipt(provider, captured, digest, { execution: "delegatecall" });
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

const royaltyHash: Hex = capture.prepared.royaltyFreezes[0]!.expectedAssignmentHash;
void royaltyHash;
// @ts-expect-error The consent workflow requires the explicit ordered royalty array.
captureArtistRecoveredConsentHydration(provider, deployment, caller, request.request, { blockTag: 10, gasLimit: 1n });
// @ts-expect-error The captured royalty scope is immutable.
captured.prepared.royaltyFreezes[0]!.expectedAssignmentHash = digest;
// @ts-expect-error Retained selectors cannot be reordered after capture.
captured.prepared.royaltyFreezes.reverse();
