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
