import {
  captureCurrentArtistCeremony,
  inspectCurrentArtistCeremony,
  prepareCurrentArtistCeremonySubmission,
} from "../dist/current-artist-ceremony.js";
import { walletTypedData } from "../dist/signing.js";

/**
 * Build and pin a human-reviewed Artist packet before the caller presents it to a wallet.
 * The caller supplies resolved facts and hash preimages; this helper performs no write or signature request.
 */
export async function reviewCurrentArtistCeremony(provider, request, blockTag = "latest") {
  const ceremony = captureCurrentArtistCeremony(
    request.kind,
    BigInt(request.chainId),
    request.registry,
    request.message,
    request.details ?? {},
    request.context,
  );
  const observation = await inspectCurrentArtistCeremony(provider, ceremony, blockTag);
  return Object.freeze({ ceremony, observation, walletPayload: walletTypedData(ceremony.payload) });
}

/** Attach the wallet result only after review; the exact reviewed payload and calldata are rebuilt. */
export function attachReviewedArtistSignature(ceremony, signature) {
  return prepareCurrentArtistCeremonySubmission(ceremony, signature);
}
