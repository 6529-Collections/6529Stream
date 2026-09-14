import { prepareCurrentArtistOperation, assertCurrentArtistDigest, toSafeCall } from "../dist/index.js";

/**
 * Prepare direct authority execution by the actual Artist/collaborator Safe.
 * The caller supplies current binding/nonce/assignment facts and selects the Safe.
 * Returns calldata only; signature collection and submission remain with the Safe.
 */
export async function prepareArtistSafeCall(provider, kind, chainId, registry, message, details = {}, options = {}) {
  if (Object.hasOwn(details, "signature")) throw new Error("Direct Safe preparation does not accept a relayed signature");
  const prepared = prepareCurrentArtistOperation(kind, chainId, registry, message, { ...details, signature: "0x" });
  await assertCurrentArtistDigest(provider, prepared, options);
  return Object.freeze({ payload: prepared.payload, transaction: toSafeCall(prepared.call) });
}
