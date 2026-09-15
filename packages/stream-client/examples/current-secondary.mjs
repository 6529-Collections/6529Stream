/** Read-only examples. The caller supplies independently selected compiler ABIs and deployment pins. */
import { CurrentSecondaryClient, toSafeCall, requireSafeExecution } from "../dist/index.js";

export function secondaryClient(chainId, adapter, compiledBindings) {
  return new CurrentSecondaryClient(chainId, adapter, compiledBindings);
}

/** Listing requires actual prior collector delivery and the configuration owner's ordinary CALL. */
export function prepareInventoryListing(client, configurationOwner, config, sortedTokenIds) {
  const prepared = client.registerInventory(configurationOwner, config, sortedTokenIds);
  return { caller: prepared.caller, safeCall: toSafeCall(prepared.call) };
}

/** Receipt association is exact; custody grants use this observed saleId, never a predicted nonce. */
export function inventoryFromSafeReceipt(client, receipt, ownerSafe, originalSafeTxHash) {
  requireSafeExecution(receipt, ownerSafe, originalSafeTxHash);
  return client.inventoryRegistration(receipt);
}

/** Review a buyer-funded purchase against observed immutable config and the current token royalty. */
export async function reviewInventoryPurchase(client, provider, buyer, saleId, tokenId, excessWei = 0n, blockTag = "latest") {
  const inventory = await client.readInventory(provider, saleId, blockTag);
  if (inventory.status !== 2n || !inventory.tokenIds.includes(tokenId)) throw Error("Inventory is not open for that token");
  const royalty = await client.readInventoryRoyalty(provider, saleId, tokenId, blockTag);
  const prepared = client.purchaseInventory(buyer, saleId, tokenId, inventory.configHash, inventory.config.unitPrice,
    inventory.config.unitPrice + excessWei);
  await client.simulate(provider, prepared, blockTag);
  return { caller: prepared.caller, safeCall: toSafeCall(prepared.call), royalty };
}

/** Existing seller authorization, original offer signature and owner grant remain separate approvals. */
export async function reviewDelegatedOffer(client, provider, buyer, input, witness, pins, blockTag = "latest") {
  await client.observeDelegation(provider, pins, input.offer.buyer, input.offerProof.authorizer, witness, "offer", blockTag);
  for (const [kind, message] of [["SaleAuthorization", input.authorization], ["SaleOffer", input.offer], ["SaleCustodyGrant", input.ownerGrant]]) {
    await client.assertDigest(provider, client.signing(kind, message), blockTag);
  }
  const prepared = client.acceptOffer(buyer, input, { mode: "delegate", witness });
  await client.simulate(provider, prepared, blockTag);
  return { caller: prepared.caller, safeCall: toSafeCall(prepared.call) };
}

/** No receiver field exists on this delegate-triggered claim. Failed NFT delivery can remain a claim. */
export async function reviewInventoryClaim(client, provider, delegate, account, saleId, tokenId, witness, pins, blockTag = "latest") {
  await client.observeDelegation(provider, pins, account, delegate, witness, "claim", blockTag);
  const prepared = client.claimInventoryNftFor(delegate, saleId, tokenId, account, witness);
  await client.simulate(provider, prepared, blockTag);
  return { caller: prepared.caller, safeCall: toSafeCall(prepared.call) };
}
