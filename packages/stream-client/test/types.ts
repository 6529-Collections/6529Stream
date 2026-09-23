// Compile-time usage examples: the public method/tuple types must reject mismatched calls.
import { StreamClient, nativeSaleTypedData, type NativeSaleAuthorization } from "../src/index.js";
declare const client: StreamClient;
declare const sale: NativeSaleAuthorization;
client.prepare("nativeSale", "buy", [sale, "0x", "0x", "0x"], { value: 1n });
client.read("core", "ownerOf", [1n]).then(address => address.toLowerCase());
// @ts-expect-error bigint required, not an imprecise JavaScript number
client.read("core", "ownerOf", [1]);
// @ts-expect-error write functions cannot go through the read API
client.read("nativeSale", "buy", [sale, "0x", "0x", "0x"]);
// @ts-expect-error missing the artist signature argument
client.prepare("nativeSale", "buy", [sale, "0x", "0x"]);
// @ts-expect-error exact SaleAuthorization fields are required
nativeSaleTypedData(31337n, "0x1", { collectionId: 1n });

import { nativeAuctionBidTypedData, type NativeAuctionBidAuthorization } from "../src/index.js";
declare const nativeBid: NativeAuctionBidAuthorization;
nativeAuctionBidTypedData(31337n, "0x1", nativeBid);
// @ts-expect-error native bids require bigint amounts
nativeAuctionBidTypedData(31337n, "0x1", { ...nativeBid, amount: 1 });
// @ts-expect-error current bid fields cannot be replaced by a creation authorization
nativeAuctionBidTypedData(31337n, "0x1", { configHash: "0x1", artist: "0x1", nonce: "0x1", deadline: 1n });

import { prepareScriptManifest, type CurrentScriptManifest } from "../src/index.js";
declare const scriptManifest: CurrentScriptManifest;
prepareScriptManifest("0x1", 1n, scriptManifest);
// @ts-expect-error collection IDs use exact bigint values
prepareScriptManifest("0x1", 1, scriptManifest);
// @ts-expect-error source type is the closed Solidity enum
prepareScriptManifest("0x1", 1n, { ...scriptManifest, sourceType: 9n });
