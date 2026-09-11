import { sameHash } from "./hashes.mjs";
import { getAddress, keccak256 } from "ethers";
import { auctionTypedData } from "../dist/index.js";

/** Creates and escrows the NFT; this does not bid, advance time, settle, or claim funds. */
export async function createAuction(client, { submitter, platform, artist }, authorization, tokenData, { onSubmitted = () => {} } = {}) {
  await client.assertChain();
  if (getAddress(await artist.getAddress()) !== getAddress(authorization.artist)) throw Error("Wrong artist wallet");
  if (getAddress(await platform.getAddress()) !== getAddress(await client.read("auction", "platformSigner", []))) throw Error("Platform signer changed");
  if (getAddress(await client.read("artistRegistry", "acceptedArtist", [authorization.collectionId])) !== getAddress(authorization.artist)) throw Error("Artist attribution is not accepted");
  if (!sameHash(keccak256(tokenData), authorization.tokenDataHash)) throw Error("Token bytes differ from the signed commitment");
  if (await client.read("auction", "signerEpoch", []) !== authorization.signerEpoch) throw Error("Signer epoch changed");
  if (!sameHash(await client.read("manager", "phasePolicyHash", [authorization.collectionId, authorization.phaseId]), authorization.mintPolicyHash)) throw Error("Phase policy changed");
  const payload = auctionTypedData(client.config.chainId, client.address("auction"), authorization);
  await client.assertDigest(payload, "auction", "authorizationDigest", [authorization]);
  const platformSignature = await platform.signTypedData(payload.domain, payload.types, payload.message);
  const artistSignature = await artist.signTypedData(payload.domain, payload.types, payload.message);
  const call = client.prepare("auction", "createAuction", [authorization, tokenData, platformSignature, artistSignature]);
  await client.simulate(call, await submitter.getAddress());
  const transaction = await submitter.sendTransaction(client.transaction(call));
  await onSubmitted(transaction.hash);
  const receipt = await transaction.wait();
  if (!receipt) throw Error("No confirmed receipt");
  const created = client.uniqueEvent(receipt, "auction", "AuctionCreated");
  if (!sameHash(created.args.authorizationDigest, payload.digest) || !sameHash(created.args.profileId, authorization.profileId) || getAddress(created.args.artist) !== getAddress(authorization.artist)) throw Error("Auction receipt differs from signed terms");
  if (getAddress(await client.read("core", "ownerOf", [created.args.tokenId])) !== client.address("auction")) throw Error("Auction has not escrowed the NFT");
  return { transactionHash: receipt.hash, tokenId: created.args.tokenId, operationRoot: created.args.operationRoot };
}
