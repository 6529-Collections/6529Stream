import * as rh from "./current-artist-recovered-hydration.js";
import { createRecoveredHydrationWorkflow } from "./internal/artist-recovered-hydration-workflow.js";

export type {
  ArtistRecoveredHydrationCodePin,
  ArtistRecoveredHydrationSuitePins,
  ArtistRecoveredHydrationDeployment,
  ArtistRecoveredHydrationReader,
  ArtistRecoveredHydrationReceiptReader,
  ArtistRecoveredHydrationObservation,
  ArtistRecoveredHydrationPayloadRow,
  ArtistRecoveredHydrationPayloadCatalog,
  ArtistRecoveredHydrationReceiptOptions,
  ArtistRecoveredHydrationOwnerObservation,
  ArtistRecoveredHydrationCapture,
  ArtistRecoveredHydrationSimulation,
  ArtistRecoveredHydrationReceipt,
} from "./internal/artist-recovered-hydration-workflow.js";

// The ABI104 adapter remains closed to feature256 and always uses the original
// two-argument preparation and one-argument Registry transport.
const original = createRecoveredHydrationWorkflow<rh.ArtistRecoveredHydrationRequest, rh.ArtistRecoveredHydrationCall>({
  normalizeInputDraft: rh.normalizeArtistRecoveredHydrationRequestDraft,
  request: input => input,
  finalizeInput: (input, inventory) => rh.normalizeArtistRecoveredHydrationRequest({
    ...input,
    expectedSemanticInventory: inventory,
  }),
  inputFromCall: call => call.request,
  prepareCall: rh.prepareArtistRecoveredHydrationCall,
  normalizeCall: rh.normalizeArtistRecoveredHydrationCall,
  preparationCalldata: rh.artistRecoveredHydrationPreparationCalldata,
  normalizePrepared: rh.normalizeArtistRecoveredHydrationPrepared,
  decodeOwnerPayload: rh.decodeArtistRecoveredHydrationOwnerPayload,
  semanticInventory: rh.artistRecoveredHydrationSemanticInventory,
  commitment: rh.artistRecoveredHydrationCommitment,
  ownerAfter: rh.artistRecoveredHydrationOwnerAfter,
  profileEvidence: rh.encodeArtistRecoveredHydrationProfileEvidence,
});

export const captureArtistRecoveredHydration = original.capture;
export const simulateArtistRecoveredHydration = original.simulate;
export const reconcileArtistRecoveredHydrationReceipt = original.reconcile;
