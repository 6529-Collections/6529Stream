import type {Provider} from "ethers";
import type {Address,Hex} from "../src/generated/contracts.js";
import type {ViewCompleteBindingCandidate} from "../src/current-view-complete-binding.js";
import {previewViewCompleteBinding,prepareViewCompleteBindingBatch,captureViewCompleteBinding,simulateViewCompleteBinding,reconcileViewCompleteBindingReceipt,inspectViewCompleteBindingHistory,inspectViewCompleteBindingCurrent,observeViewCompleteBindingRefusal,type ViewCompleteBindingDeployment,type ViewCompleteBindingHistoryDeployment,type ViewCompleteBindingWorkflowCapture,type ViewCompleteBindingWindow} from "../src/current-view-complete-binding-workflow.js";
declare const provider:Provider,d:ViewCompleteBindingDeployment,h:ViewCompleteBindingHistoryDeployment,candidate:ViewCompleteBindingCandidate,caller:Address,hash:Hex,saved:ViewCompleteBindingWorkflowCapture,window:ViewCompleteBindingWindow;
async function shape(){
  const preview=await previewViewCompleteBinding(provider,d,candidate,{blockTag:10,gasLimit:50000000n});
  const batch=prepareViewCompleteBindingBatch(preview,0n,window);
  await captureViewCompleteBinding(provider,d,caller,"publishGovernanceCallData",batch,{blockTag:10,gasLimit:50000000n});
  await captureViewCompleteBinding(provider,d,caller,"scheduleGovernanceBatch",batch,{blockTag:11,gasLimit:50000000n});
  await captureViewCompleteBinding(provider,d,caller,"executeGovernanceBatch",batch,{blockTag:12,gasLimit:50000000n});
  await simulateViewCompleteBinding(provider,saved,{blockTag:11});
  await reconcileViewCompleteBindingReceipt(provider,saved,hash,{execution:"direct"});
  await reconcileViewCompleteBindingReceipt(provider,saved,hash,{execution:"safe",expectedSafeTxHash:hash});
  await inspectViewCompleteBindingHistory(provider,h,{blockTag:12});
  await inspectViewCompleteBindingCurrent(provider,d,{blockTag:12,gasLimit:50000000n});
  await observeViewCompleteBindingRefusal(provider,saved,{blockTag:11});
  // @ts-expect-error Direct provider bind is not an outer governance stage.
  await captureViewCompleteBinding(provider,d,caller,"bindCompleteViewPreservation",batch,{blockTag:10,gasLimit:50000000n});
  // @ts-expect-error Independent Safe transaction hash is mandatory.
  await reconcileViewCompleteBindingReceipt(provider,saved,hash,{execution:"safe"});
  // @ts-expect-error Captured candidate is deeply readonly.
  saved.prepared.request.batch.candidate.configuration.snapshotHost=caller;
  // @ts-expect-error Block tags are concrete numbers.
  await inspectViewCompleteBindingHistory(provider,h,{blockTag:"latest"});
  // @ts-expect-error Reviewed worker roster has exactly five entries.
  const wrong:ViewCompleteBindingDeployment={...d,workers:[]};
  void wrong;
}
void shape;
