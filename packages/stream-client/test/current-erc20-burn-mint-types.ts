import type { Provider } from "ethers";
import type { Address, Hex } from "../src/generated/contracts.js";
import type { ERC20BurnMintSaleConfig, ERC20BurnMintExecution } from "../src/current-erc20-burn-mint-signing.js";
import type { BurnMintProgramConfig } from "../src/current-burn-mint.js";
import {
  prepareERC20BurnMintExecution, inspectERC20BurnMintExecution,
  prepareERC20BurnMintFunding, simulateERC20BurnMintFunding, inspectERC20BurnMintFundingReceipt,
  prepareERC20BurnMintAction, simulateERC20BurnMintAction, inspectERC20BurnMintActionReceipt,
  type ERC20BurnMintDeployment, type ERC20BurnMintCapture, type ERC20BurnMintFundingRoute,
  type PreparedERC20BurnMintFunding,
} from "../src/current-erc20-burn-mint.js";
import { toSafeCall } from "../src/safe.js";
declare const provider: Provider;
declare const deployment: ERC20BurnMintDeployment;
declare const configuration: ERC20BurnMintSaleConfig;
declare const execution: ERC20BurnMintExecution;
declare const program: BurnMintProgramConfig;
declare const capture: ERC20BurnMintCapture;
declare const address: Address;
declare const hash: Hex;
const prepared = prepareERC20BurnMintExecution(deployment, configuration, execution);
void inspectERC20BurnMintExecution(provider, prepared, { blockTag: 1 });
const routes: readonly ERC20BurnMintFundingRoute[] = [
  { kind: "payer" },
  { kind: "intent", intent: { payer: address, asset: address, maxAmount: 1n, saleRef: hash, expectedPrimaryPolicyHash: hash, nonce: hash, deadline: 1n }, signature: hash },
  { kind: "eip2612", permit: { deadline: 1n, v: 27n, r: hash, s: hash } },
  { kind: "permit2", permit: { nonce: 0n, deadline: 1n, signature: hash } },
];
const funding: PreparedERC20BurnMintFunding = prepareERC20BurnMintFunding(capture, routes[0]!);
for (const route of routes) prepareERC20BurnMintFunding(capture, route);
const operation: 0 = toSafeCall(funding.call).operation;
const caller: Address = funding.caller;
void operation; void caller;
void simulateERC20BurnMintFunding(provider, funding, { blockTag: 1 });
void inspectERC20BurnMintFundingReceipt(provider, funding, { transactionHash: hash, execution: "safe" });
const registration = prepareERC20BurnMintAction(deployment, address, { target: "sale", kind: "registerSale", configuration, expectedNonce: 1n });
const configPlan = prepareERC20BurnMintAction(deployment, address, { target: "gate", kind: "configureProgram", configuration: program });
void simulateERC20BurnMintAction(provider, configPlan, { blockTag: 1 });
void inspectERC20BurnMintActionReceipt(provider, registration, { transactionHash: hash, execution: "direct" });
prepareERC20BurnMintAction(deployment, address, { target: "asset", kind: "approve", spender: address, amount: 1n });
prepareERC20BurnMintAction(deployment, address, { target: "core", kind: "setApprovalForAll", operator: address, approved: true });
// @ts-expect-error The internal callback is never a user action.
prepareERC20BurnMintAction(deployment, address, { target: "sale", kind: "executeBurnMint", execution });
// @ts-expect-error Preview is an eth_call, never an action/transaction plan.
prepareERC20BurnMintAction(deployment, address, { target: "sale", kind: "previewExecution", execution });
// @ts-expect-error Explicit intended spender is required, including for Permit2 prerequisite approval.
prepareERC20BurnMintAction(deployment, address, { target: "asset", kind: "approve", amount: 1n });
// @ts-expect-error Original integer fields require bigint, not JSON numbers.
prepareERC20BurnMintAction(deployment, address, { target: "asset", kind: "approve", spender: address, amount: 1 });
// @ts-expect-error Funding is nonpayable, with no native fee allowance.
prepareERC20BurnMintFunding(capture, { kind: "payer", revealFeeAllowance: 1n });
// @ts-expect-error Intent funding requires a separate payer signature.
prepareERC20BurnMintFunding(capture, { kind: "intent", intent: routes[1] });
// @ts-expect-error Reads require one concrete block.
void inspectERC20BurnMintExecution(provider, prepared, { blockTag: "latest" });
// @ts-expect-error There is no alternate purchase identity.
const purchaseId = funding.purchaseId;
void purchaseId;
// @ts-expect-error Captured source evidence is immutable.
capture.sources[0]!.owner = address;
