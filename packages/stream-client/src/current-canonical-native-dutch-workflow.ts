import type { Hex } from "./generated/contracts.js";
import type * as native from "./current-canonical-native-dutch.js";
import * as engine from "./current-canonical-dutch-workflow-internal.js";

export type CanonicalNativeDutchCodePin = engine.DutchCodePin;
export type CanonicalNativeDutchDeployment = Omit<engine.DutchDeployment, "family" | "paymentAdapter" | "asset" | "permit2">;
export type CanonicalNativeDutchBlock = engine.DutchBlock;
export type CanonicalNativeDutchReceiptOptions = engine.DutchReceiptOptions;
export type CanonicalNativeDutchCapture = Omit<engine.DutchCapture, "prepared" | "record" | "candidate"> & {
  readonly prepared: native.CanonicalNativeDutchCall;
  readonly record: native.CanonicalNativeDutchRecord | null;
  readonly candidate: native.CanonicalNativeDutchCandidate | null;
};
export type CanonicalNativeDutchSimulation = Omit<engine.DutchSimulation, "capture"> & {
  readonly capture: CanonicalNativeDutchCapture;
};
export type CanonicalNativeDutchHistory = Omit<engine.DutchHistory, "record"> & {
  readonly record: native.CanonicalNativeDutchRecord;
};
export type CanonicalNativeDutchReconciliation = Omit<engine.DutchReconciliation, "capture"> & {
  readonly capture: CanonicalNativeDutchCapture;
};

function profile(capture: CanonicalNativeDutchCapture): void {
  if (capture.deployment.family !== "native") throw Error("Wrong Dutch workflow profile");
}

export async function captureCanonicalNativeDutch(
  provider: engine.DutchReader,
  deployment: CanonicalNativeDutchDeployment,
  prepared: native.CanonicalNativeDutchCall,
  options: { readonly blockTag: number },
): Promise<CanonicalNativeDutchCapture> {
  return await engine.captureDutch(provider, { ...deployment, family: "native" }, prepared, options) as CanonicalNativeDutchCapture;
}

export async function simulateCanonicalNativeDutch(
  provider: engine.DutchReader,
  capture: CanonicalNativeDutchCapture,
  options: { readonly blockTag: number; readonly gasLimit: bigint },
): Promise<CanonicalNativeDutchSimulation> {
  profile(capture);
  return await engine.simulateDutch(provider, capture, options) as CanonicalNativeDutchSimulation;
}

/** Local retained records do not re-admit former commerce dependencies. */
export async function inspectCanonicalNativeDutch(
  provider: engine.DutchReader,
  deployment: CanonicalNativeDutchDeployment,
  query: { readonly saleId: Hex; readonly executionId?: Hex },
  options: { readonly blockTag: number },
): Promise<CanonicalNativeDutchHistory> {
  return await engine.inspectDutch(provider, { ...deployment, family: "native" }, query, options) as CanonicalNativeDutchHistory;
}

export async function reconcileCanonicalNativeDutchReceipt(
  provider: engine.DutchReceiptReader,
  capture: CanonicalNativeDutchCapture,
  transactionHash: Hex,
  options: CanonicalNativeDutchReceiptOptions,
): Promise<CanonicalNativeDutchReconciliation> {
  profile(capture);
  return await engine.reconcileDutchReceipt(provider, capture, transactionHash, options) as CanonicalNativeDutchReconciliation;
}
