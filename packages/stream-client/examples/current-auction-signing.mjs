/** Read-only review of an ordinary current native-auction creation payload. */
import { nativeAuctionCreationTypedData } from "../dist/index.js";
export async function reviewNativeAuctionCreation(client, configuration, authorization) {
  const payload = nativeAuctionCreationTypedData(client.config.chainId, client.address("nativeAuction"), authorization);
  const configHash = await client.read("nativeAuction", "auctionConfigurationHash", [configuration]);
  if (configHash.toLowerCase() !== payload.message.configHash.toLowerCase()) throw new Error("Current auction configuration differs from the signed commitment");
  await client.assertDigest(payload, "nativeAuction", "creationAuthorizationDigest", [payload.message]);
  return payload;
}
