import type { Address, Hex } from "../src/generated/contracts.js";
import type { MintAllowlistProof } from "../src/current-mint-gates.js";
import {
  CurrentNativeAllowlistClearingClient,
  nativeAllowlistClearingConfigHash,
  nativeAllowlistClearingResolverData,
  nativeClearingAuthorizationTypedData,
  nativeClearingOriginalConfigHash,
  nativeClearingPurchaseId,
  nativeClearingSaleId,
  nativeClearingScheduleHash,
  nativeClearingSchedulePrice,
  nativeClearingWindowPolicyHash,
  type NativeAllowlistClearingConfig,
  type NativeClearingAuthorization,
} from "../src/current-native-allowlist-clearing.js";

declare const address: Address, hash: Hex, config: NativeAllowlistClearingConfig;
declare const authorization: NativeClearingAuthorization, proof: MintAllowlistProof;
const client = new CurrentNativeAllowlistClearingClient(1n, address);
nativeClearingSaleId(1n, address, 1n, hash, 1n);
nativeClearingPurchaseId(1n, address, hash, address, 1n);
nativeClearingScheduleHash(1n, address, hash, config.schedule);
nativeClearingWindowPolicyHash(config);
nativeClearingOriginalConfigHash(1n, address, hash, config, hash);
nativeAllowlistClearingConfigHash(hash, hash);
nativeClearingSchedulePrice(config.schedule, 1n);
nativeClearingAuthorizationTypedData(1n, address, authorization);
nativeAllowlistClearingResolverData([{ counterId: hash, proof }], hash, authorization);
client.prepareRegistration({} as never, config, hash, hash, address);
client.inspectSale({} as never, hash, address);
client.readRefund({} as never, hash, address);
client.claimRefund(hash, address, address);
client.fixClearingPrice(hash, address);
client.settlePurchaseSupplement(hash, address);
client.synchronizeRebate(hash, address, address);
// @ts-expect-error chain IDs retain uint256 precision as bigint
new CurrentNativeAllowlistClearingClient(1, address);
// @ts-expect-error timestamps are bigint
nativeClearingSchedulePrice(config.schedule, 1);
