import {
  captureCurrentArtistOperation, simulateCurrentArtistCall, createCurrentArtistSafePlan,
} from "../dist/current-artist-workflow.js";
import { walletTypedData } from "../dist/signing.js";

/** Request already includes the intended direct or signed authorization and actual caller. */
export async function createCurrentArtistReview(provider, { deployment, request, blockTag }) {
  const capture = await captureCurrentArtistOperation(provider, deployment, request, { blockTag });
  const simulation = await simulateCurrentArtistCall(provider, capture, { blockTag });
  return Object.freeze({
    capture, simulation,
    typedData: walletTypedData(capture.action.payload),
    safePlan: createCurrentArtistSafePlan([capture], `Artist ${capture.action.method}`),
  });
}
