import type { Provider } from "ethers";
import type { Address, Hex } from "../src/generated/contracts.js";
import type { SplitProfile } from "../src/current-split-factory.js";
import { captureSplitFactory, inspectSplitFactoryProfile, prepareSplitFactoryOperation, simulateSplitFactoryOperation, inspectSplitFactoryOperationReceipt } from "../src/current-split-factory-workflow.js";
import type { SplitFactoryDeployment } from "../src/current-split-factory-workflow.js";
declare const provider:Provider,deployment:SplitFactoryDeployment,profile:SplitProfile,caller:Address,transactionHash:Hex;
async function check(){
  const capture=await captureSplitFactory(provider,deployment,{blockTag:10});
  const state=await inspectSplitFactoryProfile(provider,capture,profile,{blockTag:10});
  const operation=prepareSplitFactoryOperation(capture,profile,"create-profile",caller);
  await simulateSplitFactoryOperation(provider,operation,{blockTag:11});
  const receipt=await inspectSplitFactoryOperationReceipt(provider,operation,{transactionHash,execution:"safe"});
  const block:number=receipt.blockNumber;void block;void state;
  // @ts-expect-error Requires a concrete block number.
  await captureSplitFactory(provider,deployment,{blockTag:"latest"});
  // @ts-expect-error The factory-only initializer is not an operator workflow.
  prepareSplitFactoryOperation(capture,profile,"initialize",caller);
  // @ts-expect-error No delegatecall receipt mode.
  await inspectSplitFactoryOperationReceipt(provider,operation,{transactionHash,execution:"delegatecall"});
  // @ts-expect-error Implementation pin is immutable.
  receipt.observed.capture.deployment.implementation.address=caller;
}
void check;
