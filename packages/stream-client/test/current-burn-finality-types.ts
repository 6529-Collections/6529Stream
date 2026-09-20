import type { Provider } from "ethers";
import type { Address, Hex } from "../src/generated/contracts.js";
import { inspectBurnFinalityImpact, type BurnFinalityRequest, type BurnFinalityImpact } from "../src/current-burn-finality.js";

declare const provider: Provider;
declare const address: Address;
declare const hash: Hex;
const pin = { address, codeHash: hash };
const request: BurnFinalityRequest = {
  chainId: 1n, core: pin, moduleRegistry: pin, finality: pin,
  burnMintDeployments: [{ ...pin, fromBlock: 1 }], redemptionDeployments: [],
  action: { kind: "freeze", collectionId: 1n }, blockNumber: 100, blockHash: hash,
  limits: { maxBlockSpan: 100, maxLogs: 10, maxPrograms: 10, maxCollections: 10 },
};
const result: Promise<BurnFinalityImpact> = inspectBurnFinalityImpact(provider, request);
void result;
// @ts-expect-error This inspection deliberately does not interpret token finality as collection closure.
inspectBurnFinalityImpact(provider, { ...request, action: { kind: "token-finality", collectionId: 1n } });
// @ts-expect-error Fixed read block must be numeric; latest is not a stable block identity.
inspectBurnFinalityImpact(provider, { ...request, blockNumber: "latest" });
// @ts-expect-error Collection IDs cannot be rounded JSON numbers.
inspectBurnFinalityImpact(provider, { ...request, action: { kind: "block-burns", collectionId: 1 } });
declare const impact: BurnFinalityImpact;
const inventoryComplete: false = impact.coverage.inventoryComplete;
void inventoryComplete;
// @ts-expect-error Read-only warning helpers do not prepare action transactions.
void impact.call;
