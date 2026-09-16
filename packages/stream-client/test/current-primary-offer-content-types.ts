import type { Provider } from "ethers";
import type { Address } from "../src/generated/contracts.js";
import { buildCuratedManifest } from "../src/current-curated-content.js";
import { inspectPrimaryOfferManifest, primaryOfferGateConfigHash } from "../src/current-primary-offer-content.js";
declare const provider: Provider;
declare const gate: Address;
declare const manifest: ReturnType<typeof buildCuratedManifest>;
primaryOfferGateConfigHash(manifest, `0x${"11".repeat(32)}`, `0x${"22".repeat(32)}`);
void inspectPrimaryOfferManifest(provider, gate, manifest, { blockTag: 1 });
// @ts-expect-error latest is not a concrete numeric block pin
void inspectPrimaryOfferManifest(provider, gate, manifest, { blockTag: "latest" });
