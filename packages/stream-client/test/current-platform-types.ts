import type { Address, Hex } from "../src/generated/contracts.js";
import { platformRightsConfigurationHash, preparePlatformTokenCustodyBid } from "../src/current-platform.js";
import type { PlatformAuctionConfiguration, PlatformOriginalPolicy } from "../src/current-platform.js";
declare const house: Address, config: PlatformAuctionConfiguration, original: PlatformOriginalPolicy, hash: Hex;
platformRightsConfigurationHash(1n, house, config, original, hash);
preparePlatformTokenCustodyBid(house, hash, house, 1n, 0n);
// @ts-expect-error chain IDs are exact bigints
platformRightsConfigurationHash(1, house, config, original, hash);
// @ts-expect-error native values are exact bigints
preparePlatformTokenCustodyBid(house, hash, house, 1, 0n);
