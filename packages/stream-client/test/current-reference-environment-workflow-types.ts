import type { Provider } from "ethers";
import type { Address,Hex } from "../src/generated/contracts.js";
import type { ReferenceEnvironmentSnapshot } from "../src/current-reference-environment.js";
import type { ReferenceInventoryDeployment,ReferenceInventoryGasProvider } from "../src/current-reference-inventory-workflow.js";
import {prepareReferenceEnvironmentPlan,inspectReferenceEnvironmentPreparation,simulateReferenceEnvironmentStep,quoteReferenceEnvironmentStepGas,inspectReferenceEnvironmentStepReceipt} from "../src/current-reference-environment-workflow.js";
declare const provider:Provider,gasProvider:ReferenceInventoryGasProvider,deployment:ReferenceInventoryDeployment,snapshot:ReferenceEnvironmentSnapshot,caller:Address,transactionHash:Hex;
async function check(){const plan=prepareReferenceEnvironmentPlan(deployment,caller,snapshot,{uploader:caller});await inspectReferenceEnvironmentPreparation(provider,plan,{blockTag:10});await simulateReferenceEnvironmentStep(provider,plan,0,{blockTag:10});await quoteReferenceEnvironmentStepGas(gasProvider,plan,0,{blockTag:10,maximumGas:100000n});const receipt=await inspectReferenceEnvironmentStepReceipt(provider,plan,0,{transactionHash,execution:"safe"});const prior:boolean=receipt.priorBlock.retained;void prior;
  // @ts-expect-error Full typed snapshot is required; cached identity is not a replacement input.
  prepareReferenceEnvironmentPlan(deployment,caller,snapshot.environmentId);
  // @ts-expect-error Concrete numeric block required.
  await inspectReferenceEnvironmentPreparation(provider,plan,{blockTag:"latest"});
  // @ts-expect-error Delegatecall receipt unsupported.
  await inspectReferenceEnvironmentStepReceipt(provider,plan,0,{transactionHash,execution:"delegatecall"});
  // @ts-expect-error Immutable complete environment tuple.
  receipt.plan.snapshot.environment.coverageHash=transactionHash;
}void check;
