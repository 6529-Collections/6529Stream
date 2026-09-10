import { getAddress, keccak256 } from "ethers";
import { erc20SaleTypedData, paymentIntentTypedData } from "../dist/index.js";

/** Uses an already-approved standard ERC20. The caller chooses allowance amount and approval policy. */
export async function purchaseERC20(client, { submitter, payer, platform, artist }, authorization, intent, tokenData, { onSubmitted = () => {} } = {}) {
  await client.assertChain();
  for (const [wallet, expected, role] of [[payer, authorization.payer, "payer"], [artist, authorization.artist, "artist"]]) {
    if (getAddress(await wallet.getAddress()) !== getAddress(expected)) throw Error(`Wrong ${role} wallet`);
  }
  if (getAddress(await platform.getAddress()) !== getAddress(await client.read("erc20Sale", "platformSigner", []))) throw Error("Platform signer changed");
  const record = await client.read("erc20Sale", "saleRecord", [authorization.saleId]);
  if (record.saleNonce === 0n || record.cancelled || record.configHash !== authorization.saleConfigHash) throw Error("Sale configuration is unavailable or changed");
  if (getAddress(await client.read("artistRegistry", "acceptedArtist", [record.config.collectionId])) !== getAddress(authorization.artist)) throw Error("Artist attribution is not accepted");
  if (keccak256(tokenData) !== authorization.tokenDataHash) throw Error("Token bytes differ from the signed commitment");
  if (await client.read("erc20Sale", "signerEpoch", []) !== authorization.signerEpoch) throw Error("Signer epoch changed");
  const policy = await client.read("erc20Sale", "primaryPolicy", [record.config.collectionId, record.config.revenueClass]);
  if (policy.policyHash !== record.config.expectedPrimaryPolicyHash) throw Error("Primary policy changed");
  if (getAddress(intent.payer) !== getAddress(authorization.payer) || getAddress(intent.asset) !== getAddress(record.config.asset) || intent.maxAmount < record.config.price || intent.saleRef !== authorization.saleId || intent.expectedPrimaryPolicyHash !== policy.policyHash) throw Error("Payer intent differs from this sale");
  if (await client.read("erc20Sale", "isPaymentIntentNonceUsed", [intent.payer, intent.nonce])) throw Error("Payer nonce was used or revoked");
  const salePayload = erc20SaleTypedData(client.config.chainId, client.address("erc20Sale"), authorization);
  const payerPayload = paymentIntentTypedData(client.config.chainId, client.address("erc20Sale"), intent);
  await client.assertDigest(salePayload, "erc20Sale", "authorizationDigest", [authorization]);
  await client.assertDigest(payerPayload, "erc20Sale", "paymentIntentDigest", [intent]);
  const platformSignature = await platform.signTypedData(salePayload.domain, salePayload.types, salePayload.message);
  const artistSignature = await artist.signTypedData(salePayload.domain, salePayload.types, salePayload.message);
  // Always obtain payer consent in this example, including when the payer submits directly.
  const payerSignature = await payer.signTypedData(payerPayload.domain, payerPayload.types, payerPayload.message);
  const call = client.prepare("erc20Sale", "buy", [authorization, tokenData, platformSignature, artistSignature, intent, payerSignature]);
  await client.simulate(call, await submitter.getAddress());
  const transaction = await submitter.sendTransaction(client.transaction(call));
  await onSubmitted(transaction.hash);
  const receipt = await transaction.wait();
  if (!receipt) throw Error("No confirmed receipt");
  const settled = client.uniqueEvent(receipt, "erc20Sale", "ERC20SaleSettled");
  if (settled.args.saleId !== authorization.saleId || settled.args.authorizationDigest !== salePayload.digest || settled.args.profileId !== policy.profileId || getAddress(settled.args.wallet) !== getAddress(policy.wallet) || getAddress(settled.args.asset) !== getAddress(intent.asset) || settled.args.amount !== record.config.price) throw Error("Receipt differs from the approved sale");
  if (getAddress(await client.read("core", "ownerOf", [settled.args.tokenId])) !== getAddress(authorization.recipient)) throw Error("Recipient ownership differs after purchase");
  return { transactionHash: receipt.hash, tokenId: settled.args.tokenId, operationRoot: settled.args.operationRoot, wallet: settled.args.wallet };
}
