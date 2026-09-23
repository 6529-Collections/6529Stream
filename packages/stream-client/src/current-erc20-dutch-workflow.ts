import type { Hex } from "./generated/contracts.js";
import type * as erc20 from "./current-erc20-dutch.js";
import * as engine from "./current-canonical-dutch-workflow-internal.js";

export type ERC20DutchCodePin = engine.DutchCodePin;
export type ERC20DutchDeployment = Omit<engine.DutchDeployment, "family" | "paymentAdapter" | "asset"> & {
  readonly paymentAdapter: engine.DutchCodePin;
  readonly asset: engine.DutchCodePin;
};
export type ERC20DutchBlock = engine.DutchBlock;
export type ERC20DutchReceiptOptions = engine.DutchReceiptOptions;
export type ERC20DutchCapture = Omit<engine.DutchCapture, "prepared" | "record" | "candidate"> & {
  readonly prepared: erc20.ERC20DutchCall;
  readonly record: erc20.ERC20DutchRecord | null;
  readonly candidate: erc20.ERC20DutchCandidate | null;
};
export type ERC20DutchSimulation = Omit<engine.DutchSimulation, "capture"> & {
  readonly capture: ERC20DutchCapture;
};
export type ERC20DutchHistory = Omit<engine.DutchHistory, "record"> & {
  readonly record: erc20.ERC20DutchRecord;
};
export type ERC20DutchReconciliation = Omit<engine.DutchReconciliation, "capture"> & {
  readonly capture: ERC20DutchCapture;
};

function profile(capture: ERC20DutchCapture): void {
  if (capture.deployment.family !== "erc20") throw Error("Wrong Dutch workflow profile");
}

export async function captureERC20Dutch(
  provider: engine.DutchReader,
  deployment: ERC20DutchDeployment,
  prepared: erc20.ERC20DutchCall,
  options: { readonly blockTag: number },
): Promise<ERC20DutchCapture> {
  return await engine.captureDutch(provider, { ...deployment, family: "erc20" }, prepared, options) as ERC20DutchCapture;
}

export async function simulateERC20Dutch(
  provider: engine.DutchReader,
  capture: ERC20DutchCapture,
  options: { readonly blockTag: number; readonly gasLimit: bigint },
): Promise<ERC20DutchSimulation> {
  profile(capture);
  return await engine.simulateDutch(provider, capture, options) as ERC20DutchSimulation;
}

/** Local retained records do not re-admit former commerce dependencies. */
export async function inspectERC20Dutch(
  provider: engine.DutchReader,
  deployment: ERC20DutchDeployment,
  query: { readonly saleId: Hex; readonly executionId?: Hex },
  options: { readonly blockTag: number },
): Promise<ERC20DutchHistory> {
  return await engine.inspectDutch(provider, { ...deployment, family: "erc20" }, query, options) as ERC20DutchHistory;
}

export async function reconcileERC20DutchReceipt(
  provider: engine.DutchReceiptReader,
  capture: ERC20DutchCapture,
  transactionHash: Hex,
  options: ERC20DutchReceiptOptions,
): Promise<ERC20DutchReconciliation> {
  profile(capture);
  return await engine.reconcileDutchReceipt(provider, capture, transactionHash, options) as ERC20DutchReconciliation;
}
