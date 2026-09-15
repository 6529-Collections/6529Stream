import { CurrentSecondaryClient, type SecondaryOfferInput, type SecondaryInventoryConfig } from "../src/index.js";
declare const client: CurrentSecondaryClient;
declare const offer: SecondaryOfferInput;
declare const config: SecondaryInventoryConfig;
client.registerInventory("0x1", config, [1n]);
client.acceptOffer("0x1", offer, { mode: "delegate", witness: { walletWide: true, index: 1n } });
// @ts-expect-error explicit registry index is full-width bigint
client.claimNftFor("0x1", "0x2", "0x3", { walletWide: false, index: 1 });
// @ts-expect-error inventory payment values cannot be JavaScript numbers
client.purchaseInventory("0x1", "0x2", 1n, "0x3", 12n, 15);
// @ts-expect-error delegate offer requires an explicit retained-row locator
client.acceptOffer("0x1", offer, { mode: "delegate" });
// @ts-expect-error maker route does not take a delegate witness
client.acceptOffer("0x1", offer, { mode: "maker", witness: { walletWide: false, index: 0n } });
// @ts-expect-error delegated claims have no receiver override
client.claimNftFor("0x1", "0x2", "0x3", { walletWide: true, index: 1n, receiver: "0x4" });

import { CurrentNativeRefundClaimsClient } from "../src/index.js";
declare const refunds: CurrentNativeRefundClaimsClient;
refunds.claimFor("0x1", "0x2", "0x3", { walletWide: false, index: 1n });
// @ts-expect-error registry row coordinates remain full-width bigint
refunds.claimFor("0x1", "0x2", "0x3", { walletWide: false, index: 1 });
// @ts-expect-error delegated refund has no destination override
refunds.claimFor("0x1", "0x2", "0x3", { walletWide: false, index: 1n, recipient: "0x4" });
