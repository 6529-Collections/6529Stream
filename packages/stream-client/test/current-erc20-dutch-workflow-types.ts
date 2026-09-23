import type { Provider } from "ethers";
import type { Hex } from "../src/generated/contracts.js";
import type { ERC20DutchCall } from "../src/current-erc20-dutch.js";
import { captureERC20Dutch, simulateERC20Dutch, reconcileERC20DutchReceipt, inspectERC20Dutch,
  type ERC20DutchDeployment, type ERC20DutchCapture } from "../src/current-erc20-dutch-workflow.js";

declare const provider: Provider;
declare const deployment: ERC20DutchDeployment;
declare const prepared: ERC20DutchCall;
declare const capture: ERC20DutchCapture;
declare const hash: Hex;

void captureERC20Dutch(provider, deployment, prepared, { blockTag: 10 });
void simulateERC20Dutch(provider, capture, { blockTag: 11, gasLimit: 5_000_000n });
void inspectERC20Dutch(provider, deployment, { saleId: hash, executionId: hash }, { blockTag: 12 });
void reconcileERC20DutchReceipt(provider, capture, hash, { execution: "direct" });
void reconcileERC20DutchReceipt(provider, capture, hash, { execution: "safe", expectedSafeTxHash: hash, releaseKey: hash });
// @ts-expect-error Safe receipt requires independent transaction hash.
void reconcileERC20DutchReceipt(provider, capture, hash, { execution: "safe" });
// @ts-expect-error Concrete block number is required.
void simulateERC20Dutch(provider, capture, { blockTag: "latest", gasLimit: 1n });
// @ts-expect-error Returned capture is immutable.
capture.refundCredit = 0n;
// @ts-expect-error Ordinary CALL receipt cannot select delegatecall.
void reconcileERC20DutchReceipt(provider, capture, hash, { execution: "delegatecall" });
