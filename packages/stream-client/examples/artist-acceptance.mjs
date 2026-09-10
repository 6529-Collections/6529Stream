import { getAddress } from "ethers";
import { artistAcceptanceTypedData } from "../dist/index.js";

/** The artist signs; a distinct caller-supplied relayer pays gas. Acceptance is permanent. */
export async function acceptArtist(client, { artist, relayer }, collectionId, deadline, { onSubmitted = () => {} } = {}) {
  await client.assertChain();
  const address = getAddress(await artist.getAddress());
  const nomination = await client.read("artistRegistry", "attribution", [collectionId]);
  if (getAddress(nomination.nominatedArtist) !== address || BigInt(nomination.artist) !== 0n) throw Error("No unaccepted nomination for this artist");
  const nonce = await client.read("artistRegistry", "acceptanceNonces", [address]);
  const message = { core: client.address("core"), collectionId, nominationHash: nomination.nominationHash, nonce, deadline };
  const payload = artistAcceptanceTypedData(client.config.chainId, client.address("artistRegistry"), message);
  await client.assertDigest(payload, "artistRegistry", "acceptanceDigest", [collectionId, message.nominationHash, nonce, deadline]);
  const signature = await artist.signTypedData(payload.domain, payload.types, payload.message);
  const call = client.prepare("artistRegistry", "acceptArtist", [collectionId, message.nominationHash, nonce, deadline, signature]);
  await client.simulate(call, await relayer.getAddress());
  const transaction = await relayer.sendTransaction(client.transaction(call));
  await onSubmitted(transaction.hash);
  const receipt = await transaction.wait();
  if (!receipt) throw Error("No confirmed receipt");
  const accepted = client.uniqueEvent(receipt, "artistRegistry", "CollectionArtistAccepted");
  if (accepted.args.collectionId !== collectionId || getAddress(accepted.args.artist) !== address || accepted.args.acceptanceHash !== payload.digest) throw Error("Acceptance receipt differs from the signed nomination");
  return { transactionHash: receipt.hash, collectionId, artist: address, acceptanceHash: payload.digest };
}
