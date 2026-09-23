import type { Address, Hex } from "../src/generated/contracts.js";
import type { BurnMintProgramConfig } from "../src/current-burn-mint.js";
import type { ERC20SettlementCandidate } from "../src/current-erc20-primary-offer.js";
import type { PaymentIntent } from "../src/signing.js";
import {
  encodeERC20BurnMintExecution, erc20BurnMintAuthorizationPayload, erc20BurnMintCandidateCommitment,
  erc20BurnMintPaymentIntentPayload, erc20BurnMintSigningSnapshot, normalizeERC20BurnMintExecution,
  normalizeERC20BurnMintSaleAuthorization, validateERC20BurnMintProgram,
  type ERC20BurnMintExecution, type ERC20BurnMintSaleAuthorization, type ERC20BurnMintSaleConfig,
} from "../src/current-erc20-burn-mint-signing.js";
declare const a: Address;
declare const h: Hex;
declare const config: ERC20BurnMintSaleConfig;
declare const auth: ERC20BurnMintSaleAuthorization;
declare const execution: ERC20BurnMintExecution;
declare const candidate: ERC20SettlementCandidate;
declare const program: BurnMintProgramConfig;
declare const intent: PaymentIntent;
erc20BurnMintAuthorizationPayload(1n, a, auth);
erc20BurnMintCandidateCommitment(1n, a, a, candidate);
erc20BurnMintPaymentIntentPayload(1n, config, auth, intent);
const saved = erc20BurnMintSigningSnapshot(1n, a, config, h, execution);
encodeERC20BurnMintExecution(saved.execution);
validateERC20BurnMintProgram(config, program, [1n, 2n]);
// @ts-expect-error source token IDs use exact bigint values
normalizeERC20BurnMintExecution({ ...execution, sourceTokenIds: [1] });
// @ts-expect-error source IDs belong to Execution, never the signed original authorization
normalizeERC20BurnMintSaleAuthorization({ ...auth, sourceTokenIds: [1n] });
// @ts-expect-error no native fee allowance is part of this execution
normalizeERC20BurnMintExecution({ ...execution, revealFeeAllowance: 1n });
// @ts-expect-error reviewed sources are immutable
saved.execution.sourceTokenIds.push(2n);
