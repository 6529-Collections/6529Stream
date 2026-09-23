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
const erc20Deployments: NonNullable<BurnFinalityRequest["erc20BurnMintDeployments"]> = [
  { ...pin, fromBlock: 1, saleAdapter: pin },
  { ...pin, fromBlock: 2, saleAdapter: pin },
];
const erc20Request: BurnFinalityRequest = { ...request, erc20BurnMintDeployments: erc20Deployments };
const erc20Result: Promise<BurnFinalityImpact> = inspectBurnFinalityImpact(provider, erc20Request);
void erc20Result;
// @ts-expect-error The dedicated ERC20 profile requires its independently code-pinned carrier.
const noCarrier: NonNullable<BurnFinalityRequest["erc20BurnMintDeployments"]>[number] = { ...pin, fromBlock: 1 };
// @ts-expect-error ERC20 discovery retains numeric, bounded block ranges.
const wrongBlock: NonNullable<BurnFinalityRequest["erc20BurnMintDeployments"]>[number] = { ...pin, fromBlock: 1n, saleAdapter: pin };
// @ts-expect-error A carrier address alone is not a deployment code pin.
const unpinnedCarrier: NonNullable<BurnFinalityRequest["erc20BurnMintDeployments"]>[number] = { ...pin, fromBlock: 1, saleAdapter: address };
void noCarrier; void wrongBlock; void unpinnedCarrier;
// @ts-expect-error Supplied deployment arrays are readonly.
erc20Deployments.push({ ...pin, fromBlock: 3, saleAdapter: pin });
// @ts-expect-error The nested carrier binding is readonly too.
erc20Deployments[0]!.saleAdapter.codeHash = hash;
// @ts-expect-error This inspection deliberately does not interpret token finality as collection closure.
inspectBurnFinalityImpact(provider, { ...request, action: { kind: "token-finality", collectionId: 1n } });
// @ts-expect-error Fixed read block must be numeric; latest is not a stable block identity.
inspectBurnFinalityImpact(provider, { ...request, blockNumber: "latest" });
// @ts-expect-error Collection IDs cannot be rounded JSON numbers.
inspectBurnFinalityImpact(provider, { ...request, action: { kind: "block-burns", collectionId: 1 } });
declare const impact: BurnFinalityImpact;
const inventoryComplete: false = impact.coverage.inventoryComplete;
void inventoryComplete;
const erc20Kind: BurnFinalityImpact["programs"][number]["kind"] = "erc20-burn-mint";
const erc20CoverageKind: BurnFinalityImpact["coverage"]["deployments"][number]["kind"] = erc20Kind;
const returnedCarrier: Address | undefined = impact.request.erc20BurnMintDeployments?.[0]?.saleAdapter.address;
void erc20CoverageKind; void returnedCarrier;
// @ts-expect-error Read-only warning helpers do not prepare action transactions.
void impact.call;
