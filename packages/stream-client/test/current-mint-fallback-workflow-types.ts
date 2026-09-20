import type { Provider } from "ethers";
import type { Address, Hex } from "../src/generated/contracts.js";
import type { MintFallbackConfiguration, MintFallbackCallPlan, MintFallbackGovernanceWindow } from "../src/current-mint-fallback.js";
import { inspectMintFallback, prepareMintFallbackGovernance, prepareMintFallbackGovernanceOperation, prepareMintFallbackPermissionless, simulateMintFallbackOperation, inspectMintFallbackOperationReceipt } from "../src/current-mint-fallback-workflow.js";
declare const provider: Provider, configuration: MintFallbackConfiguration, plan: MintFallbackCallPlan, caller: Address, window: MintFallbackGovernanceWindow, transactionHash: Hex;
async function check() {
  const inspection = await inspectMintFallback(provider, configuration, { blockTag: 100, readiness: "reserve" });
  const prepared = prepareMintFallbackGovernance(inspection, plan, caller, window);
  const operation = prepareMintFallbackGovernanceOperation(prepared, "execute", caller);
  await simulateMintFallbackOperation(provider, operation, { blockTag: 200 });
  const result = await inspectMintFallbackOperationReceipt(provider, operation, { transactionHash, execution: "safe" });
  const block: number = result.blockNumber; void block;
  const permissionless = prepareMintFallbackPermissionless(inspection, plan, caller); void permissionless;
  // @ts-expect-error Concrete numeric block required.
  await inspectMintFallback(provider, configuration, { blockTag: "latest" });
  // @ts-expect-error There is no direct recovery forwarding stage.
  prepareMintFallbackGovernanceOperation(prepared, "recover", caller);
  // @ts-expect-error Delegatecall is not a receipt mode.
  await inspectMintFallbackOperationReceipt(provider, operation, { transactionHash, execution: "delegatecall" });
  // @ts-expect-error Retained configuration is immutable.
  result.observed.configuration.primary = caller;
}
void check;
