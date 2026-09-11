import { sameHash } from "./hashes.mjs";
import { getAddress, keccak256 } from "ethers";
import { nativeSaleTypedData } from "../dist/index.js";

/** Executable app function. Wallets are caller-supplied ethers Signers, including browser/hardware adapters. */
export async function purchaseNative(client, { payer, platform, artist }, authorization, tokenData, { onSubmitted = () => {} } = {}) {
  await client.assertChain();
  for (const [wallet, expected, role] of [[payer, authorization.payer, "payer"], [artist, authorization.artist, "artist"]]) {
    if (getAddress(await wallet.getAddress()) !== getAddress(expected)) throw Error(`Wrong ${role} wallet`);
  }
  if (getAddress(await platform.getAddress()) !== getAddress(await client.read("nativeSale", "platformSigner", []))) throw Error("Platform signer changed");
  if (getAddress(await client.read("artistRegistry", "acceptedArtist", [authorization.collectionId])) !== getAddress(authorization.artist)) throw Error("Artist attribution is not accepted");
  if (!sameHash(keccak256(tokenData), authorization.tokenDataHash)) throw Error("Token bytes differ from the signed commitment");
  if (await client.read("nativeSale", "signerEpoch", []) !== authorization.signerEpoch) throw Error("Signer epoch changed");
  if (!sameHash(await client.read("manager", "phasePolicyHash", [authorization.collectionId, authorization.phaseId]), authorization.mintPolicyHash)) throw Error("Phase policy changed");
  const payload = nativeSaleTypedData(client.config.chainId, client.address("nativeSale"), authorization);
  await client.assertDigest(payload, "nativeSale", "authorizationDigest", [authorization]);
  const platformSignature = await platform.signTypedData(payload.domain, payload.types, payload.message);
  const artistSignature = await artist.signTypedData(payload.domain, payload.types, payload.message);
  const call = client.prepare("nativeSale", "buy", [authorization, tokenData, platformSignature, artistSignature], { value: authorization.price });
  await client.simulate(call, authorization.payer);
  const transaction = await payer.sendTransaction(client.transaction(call));
  await onSubmitted(transaction.hash);
  const receipt = await transaction.wait();
  if (!receipt) throw Error("No confirmed receipt");
  const settled = client.uniqueEvent(receipt, "nativeSale", "NativeSaleSettled");
  if (!sameHash(settled.args.authorizationDigest, payload.digest) || !sameHash(settled.args.profileId, authorization.profileId) || settled.args.amount !== authorization.price) throw Error("Receipt differs from signed terms");
  if (getAddress(await client.read("core", "ownerOf", [settled.args.tokenId])) !== getAddress(authorization.recipient)) throw Error("Recipient ownership differs after purchase");
  return { transactionHash: receipt.hash, tokenId: settled.args.tokenId, operationRoot: settled.args.operationRoot, wallet: settled.args.wallet };
}
