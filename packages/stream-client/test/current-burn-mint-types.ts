import type { Address, Hex } from "../src/generated/contracts.js";
import type { MintGateBatch } from "../src/current-mint-gates.js";
import type { NativeFixedPriceSaleAuthorization } from "../src/current-signing.js";
import {
  CurrentBurnMintClient, burnMintNullifier, burnMintProgramConfigHash, normalizeBurnMintSources,
  type BurnMintProgramConfig, type BurnMintProgramPlan,
} from "../src/current-burn-mint.js";

declare const address: Address, hash: Hex, config: BurnMintProgramConfig, plan: BurnMintProgramPlan;
declare const batch: MintGateBatch, authorization: NativeFixedPriceSaleAuthorization;
const client = new CurrentBurnMintClient(1n, { gate: address, core: address, registry: address });
burnMintProgramConfigHash(1n, address, address, address, config);
burnMintNullifier(1n, address, 1n);
normalizeBurnMintSources([1n], 1n, 1n);
client.configureProgram(config, address);
client.captureProgram({} as never, 1n);
client.inspectSources({} as never, plan, address, [1n], 1n);
client.prepareFreeBurnMint({} as never, plan, address, batch, [1n], 0n);
client.prepareNativePurchaseWithBurn({} as never, plan, [1n], authorization,
  { tokenData: "0x", platformSignature: "0x", artistSignature: "0x", saleAmount: 1n, revealFeeAllowance: 0n });
client.freeBurnRefundClaim(hash, address, address);
client.readFreeBurnRefund({} as never, hash, address);
client.readFreeBurnCreditState({} as never);
client.readFreeBurnCreditPage({} as never, 0n, 0n, 64n);
// @ts-expect-error chain identifiers preserve full uint256 width as bigint
new CurrentBurnMintClient(1, { gate: address, core: address, registry: address });
// @ts-expect-error source token IDs cannot be rounded through JS numbers
normalizeBurnMintSources([1], 1n, 1n);
// @ts-expect-error reveal allowance must be bigint
client.prepareFreeBurnMint({} as never, plan, address, batch, [1n], 0);
