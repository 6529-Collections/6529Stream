import {
  type Address, type Hex, type GovernanceExecutorV2Coordinates,
  type GovernanceExecutorV2CallDescriptor, type GovernanceExecutorV2ScheduleAction,
  type GovernanceExecutorV2ScheduleBatch, type GovernanceExecutorV2Request,
  type GovernanceExecutorV2Deployment, type GovernanceExecutorV2HistoryDeployment,
  type GovernanceExecutorV2ReceiptReader, type GovernanceExecutorV2Capture,
  type GovernanceExecutorV2ScheduleLocator,
  prepareGovernanceExecutorV2Call, prepareGovernanceExecutorV2Read,
  governanceExecutorV2CallsHash, governanceExecutorV2BatchHashes,
  governanceExecutorV2ScheduleIdentity, governanceExecutorV2ActionId,
  captureGovernanceExecutorV2, simulateGovernanceExecutorV2,
  inspectGovernanceExecutorV2History, inspectGovernanceExecutorV2Current,
  observeGovernanceExecutorV2Refusal, reconcileGovernanceExecutorV2Receipt,
  toSafeCall,
} from "../src/index.js";

declare const c: GovernanceExecutorV2Coordinates;
declare const caller: Address;
declare const hash: Hex;
declare const data: Hex;
declare const call: GovernanceExecutorV2CallDescriptor;
declare const single: GovernanceExecutorV2ScheduleAction;
declare const batch: GovernanceExecutorV2ScheduleBatch;
declare const d: GovernanceExecutorV2Deployment;
declare const hd: GovernanceExecutorV2HistoryDeployment;
declare const provider: GovernanceExecutorV2ReceiptReader;
declare const capture: GovernanceExecutorV2Capture;
declare const schedule: GovernanceExecutorV2ScheduleLocator;
const writes: readonly GovernanceExecutorV2Request[] = [
  { method: "publishGovernanceCallData", callDatas: [data] },
  { method: "scheduleGovernanceAction", request: single },
  { method: "scheduleGovernanceBatch", ...batch },
  { method: "executeGovernanceAction", actionId: hash, call, callData: data },
  { method: "executeGovernanceBatch", actionId: hash, calls: [call], callDatas: [data] },
  { method: "cancelGovernanceAction", actionId: hash, reasonHash: hash },
  { method: "vetoTerminalFreeze", actionId: hash, reasonHash: hash },
  { method: "materializeExpiredAction", actionId: hash },
  { method: "pruneElapsedTerminalFreezeActions", scopeHash: hash },
];
for (const request of writes) {
  const plan = prepareGovernanceExecutorV2Call(c, caller, request);
  const unverified: false = plan.authorityIndependentlyVerified;
  const effects: false = plan.targetEffectsIndependentlyVerified;
  const payable: bigint = plan.call.value;
  const operation: 0 = plan.call.operation;
  toSafeCall(plan.call);
  void [unverified, effects, payable, operation];
}
const identity = governanceExecutorV2ScheduleIdentity({ method: "scheduleGovernanceAction", request: single }, 0n);
const actionId: Hex = governanceExecutorV2ActionId(c, identity);
governanceExecutorV2CallsHash([call]); governanceExecutorV2BatchHashes([call]);
prepareGovernanceExecutorV2Read(c, { method: "governanceAction", args: [actionId] });
prepareGovernanceExecutorV2Read(c, { method: "terminalFreezeActionPage", args: [hash, 0n, 64n] });
const options = { blockTag: 100, gasLimit: 1_000_000n, schedule };
void captureGovernanceExecutorV2(provider, d, caller, writes[0]!, options);
void simulateGovernanceExecutorV2(provider, capture, { blockTag: 101, gasLimit: 1_000_000n });
void inspectGovernanceExecutorV2History(provider, hd, hash, options);
void inspectGovernanceExecutorV2Current(provider, d, caller, writes[0]!, options);
void observeGovernanceExecutorV2Refusal(provider, capture, { blockTag: 101, gasLimit: 1_000_000n });
void reconcileGovernanceExecutorV2Receipt(provider, capture, hash, { execution: "direct" });
void reconcileGovernanceExecutorV2Receipt(provider, capture, hash,
  { execution: "safe", expectedSafeTxHash: hash, nonce: 0n, outerValue: 0n, safeCodeHash: hash });

// @ts-expect-error There is no guessed public scheduled nonce getter.
prepareGovernanceExecutorV2Read(c, { method: "actionNonce", args: [hash] });
// @ts-expect-error Configuration writes are outside the nine lifecycle calls.
prepareGovernanceExecutorV2Call(c, caller, { method: "registerProposer", account: caller, enabled: true });
// @ts-expect-error Single execution needs a descriptor witness to determine native value.
prepareGovernanceExecutorV2Call(c, caller, { method: "executeGovernanceAction", actionId: hash, callData: data });
// @ts-expect-error Cancellation reasons are hashes, not a substituted URI.
prepareGovernanceExecutorV2Call(c, caller, { method: "cancelGovernanceAction", actionId: hash, reasonURI: "reason" });
// @ts-expect-error Reads and writes have separate closed request types.
prepareGovernanceExecutorV2Read(c, { method: "executeGovernanceBatch", args: [] });
// @ts-expect-error Numeric ABI fields use bigint.
governanceExecutorV2ScheduleIdentity({ method: "scheduleGovernanceAction", request: single }, 0);
// @ts-expect-error Frozen nested call data cannot be mutated.
capture.prepared.call.value = 1n;
// @ts-expect-error Caller-reviewed code pins are immutable.
capture.deployment.linkedDependencies.push({ address: caller, codeHash: hash });
// @ts-expect-error RPC observations use concrete block numbers.
void simulateGovernanceExecutorV2(provider, capture, { blockTag: "latest", gasLimit: 1_000_000n });
// @ts-expect-error Safe outer native value is explicit, independent of inner value.
void reconcileGovernanceExecutorV2Receipt(provider, capture, hash, { execution: "safe", expectedSafeTxHash: hash, nonce: 0n, safeCodeHash: hash });
