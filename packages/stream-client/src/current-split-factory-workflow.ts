import { Interface, ZeroAddress, id, getAddress, isHexString, keccak256 } from "ethers";
import type { Provider } from "ethers";
import type { Address, Hex } from "./generated/contracts.js";
import type { UnsignedCall } from "./client.js";
import { normalizeSplitFactorySnapshot, normalizeSplitProfile, prepareSplitFactoryCall, normalizeSplitFactoryCall, verifySplitWalletCloneRuntime } from "./current-split-factory.js";
import type { SplitFactorySnapshot, SplitProfile } from "./current-split-factory.js";

export interface SplitFactoryCodePin { readonly address: Address; readonly codeHash: Hex }
export interface SplitFactoryDeployment { readonly chainId: bigint; readonly factory: SplitFactoryCodePin; readonly assetPolicy: SplitFactoryCodePin; readonly implementation: SplitFactoryCodePin }
export interface SplitFactoryCapture { readonly deployment: SplitFactoryDeployment; readonly snapshot: SplitFactorySnapshot; readonly blockNumber: number; readonly blockHash: Hex }
export interface SplitFactoryProfileInspection {
  readonly capture: SplitFactoryCapture; readonly profile: SplitProfile;
  readonly registered: boolean; readonly deployed: boolean; readonly initialized: boolean;
  readonly status: "unregistered" | "registered" | "initialized";
}
export type SplitFactoryOperationKind = "register-profile" | "create-profile" | "deploy-wallet";
export interface PreparedSplitFactoryOperation {
  readonly capture: SplitFactoryCapture; readonly prepared: ReturnType<typeof prepareSplitFactoryCall>;
  readonly kind: SplitFactoryOperationKind; readonly caller: Address; readonly call: UnsignedCall;
}
export interface SplitFactorySimulation { readonly operation: PreparedSplitFactoryOperation; readonly observed: SplitFactoryProfileInspection; readonly returnData: Hex }
export interface SplitFactoryEventReference { readonly address: Address; readonly event: string; readonly logIndex: number; readonly transactionHash: Hex; readonly blockHash: Hex }
export interface SplitFactoryOperationReceipt {
  readonly operation: PreparedSplitFactoryOperation; readonly transactionHash: Hex; readonly blockNumber: number; readonly blockHash: Hex;
  readonly prior: SplitFactoryProfileInspection; readonly observed: SplitFactoryProfileInspection; readonly events: readonly SplitFactoryEventReference[];
  readonly registration: "created" | "reused"; readonly deployment: "deployed" | "discovered" | "reused" | "not-requested";
  readonly stateAttribution: "receipt-block observation; lifecycle changes attributed only by matching events";
}
type Reader = Pick<Provider, "getNetwork" | "getCode" | "getBlock" | "call">;
type ReceiptReader = Reader & Pick<Provider, "getTransaction" | "getTransactionReceipt">;
const ZERO = `0x${"00".repeat(32)}` as Hex;
function addr(v: unknown): Address { if (typeof v !== "string") throw Error("Expected address"); const a = getAddress(v) as Address; if (a === ZeroAddress) throw Error("Zero address"); return a; }
function hash(v: unknown, zero = false): Hex { if (typeof v !== "string" || !isHexString(v, 32) || (!zero && v.toLowerCase() === ZERO)) throw Error("Expected bytes32"); return v.toLowerCase() as Hex; }
function bytes(v: unknown, max = 16384): Hex { if (typeof v !== "string" || !isHexString(v, true) || (v.length - 2) / 2 > max) throw Error("Malformed or oversized bytes"); return v.toLowerCase() as Hex; }
function integer(v: number): number { if (!Number.isSafeInteger(v) || v < 0) throw Error("Expected concrete block/index"); return v; }
function uint(v: unknown, positive = false): bigint { if (typeof v !== "bigint" || v < (positive ? 1n : 0n) || v >= 1n << 256n) throw Error("Expected uint256 bigint"); return v; }
function same(a: unknown, b: unknown): boolean { return typeof a === "string" && typeof b === "string" && a.toLowerCase() === b.toLowerCase(); }
function stable(v: unknown): string { return JSON.stringify(v, (_, x: unknown) => typeof x === "bigint" ? `${x}n` : x && typeof x === "object" && !Array.isArray(x) ? Object.fromEntries(Object.entries(x).sort(([a],[b]) => a.localeCompare(b))) : x); }
function equal(a: unknown, b: unknown, message = "Prepared inputs differ from canonical reconstruction"): void { if (stable(a) !== stable(b)) throw Error(message); }
function exact(v: unknown, keys: readonly string[]): void { if (!v || typeof v !== "object" || Array.isArray(v) || Object.keys(v).sort().join() !== [...keys].sort().join()) throw Error("Missing/unknown properties"); }
function freeze<T>(v: T): T { if (v && typeof v === "object") { Object.values(v).forEach(freeze); Object.freeze(v); } return v; }
function pin(v: SplitFactoryCodePin): SplitFactoryCodePin { exact(v,["address","codeHash"]); return freeze({ address: addr(v.address), codeHash: hash(v.codeHash) }); }
function deployment(v: SplitFactoryDeployment): SplitFactoryDeployment { exact(v,["chainId","factory","assetPolicy","implementation"]); const d = { chainId:uint(v.chainId,true),factory:pin(v.factory),assetPolicy:pin(v.assetPolicy),implementation:pin(v.implementation) }; if (new Set([d.factory.address,d.assetPolicy.address,d.implementation.address]).size !== 3) throw Error("Factory, policy and implementation must differ"); return freeze(d); }
function capture(v: SplitFactoryCapture): SplitFactoryCapture { exact(v,["deployment","snapshot","blockNumber","blockHash"]); const d = deployment(v.deployment), s = normalizeSplitFactorySnapshot(v.snapshot); if (s.context.walletVersion !== 4n || s.context.chainId !== d.chainId || !same(s.context.factory,d.factory.address) || !same(s.factoryCodeHash,d.factory.codeHash) || !same(s.context.assetPolicyRegistry,d.assetPolicy.address) || !same(s.assetPolicyCodeHash,d.assetPolicy.codeHash) || !s.implementation || !same(s.implementation.address,d.implementation.address) || !same(s.implementation.codeHash,d.implementation.codeHash)) throw Error("Capture pins differ"); return freeze({deployment:d,snapshot:s,blockNumber:integer(v.blockNumber),blockHash:hash(v.blockHash)}); }
function call(to: Address, abi: Interface, name: string, args: readonly unknown[]): UnsignedCall { return freeze({ to,value:0n,data:abi.encodeFunctionData(name,args) as Hex }); }
async function rpc(p: Pick<Provider,"call">, to: Address, abi: Interface, name: string, args: readonly unknown[], tag: number): Promise<readonly unknown[]> { const raw = bytes(await p.call({...call(to,abi,name,args),blockTag:tag})), decoded = abi.decodeFunctionResult(name,raw); if (!same(abi.encodeFunctionResult(name,decoded),raw)) throw Error(`Noncanonical ${name} return`); return decoded; }
async function header(p: Pick<Provider,"getBlock">, tag: number): Promise<{number:number;hash:Hex}> { const b = await p.getBlock(tag); if (!b || b.number !== tag) throw Error("Missing/mismatched block"); return {number:tag,hash:hash(b.hash)}; }
async function unchanged(p: Pick<Provider,"getBlock">, h: {number:number;hash:Hex}): Promise<void> { equal(await header(p,h.number),h,"Pinned block changed"); }
async function runtime(p: Pick<Provider,"getCode">, pin: SplitFactoryCodePin, tag: number): Promise<void> { const code = bytes(await p.getCode(pin.address,tag),65536); if (code === "0x" || (code.length === 48 && code.startsWith("0xef0100")) || !same(keccak256(code),pin.codeHash)) throw Error("Pinned runtime differs"); }
const companionId = `0x${(BigInt(new Interface(["function splitWalletImplementation() view returns(address)"]).getFunction("splitWalletImplementation")!.selector) ^ BigInt(new Interface(["function splitWalletImplementationCodeHash() view returns(bytes32)"]).getFunction("splitWalletImplementationCodeHash")!.selector)).toString(16).padStart(8,"0")}`;
/** V4 only. Captures exact immutable dependencies; this does not assert runtime-registry ACTIVE admission. */
export async function captureSplitFactory(p: Reader, input: SplitFactoryDeployment, options: {readonly blockTag:number}): Promise<SplitFactoryCapture> {
  const d = deployment(input), tag = integer(options.blockTag); if ((await p.getNetwork()).chainId !== d.chainId) throw Error("RPC chain differs"); const h = await header(p,tag); await Promise.all([d.factory,d.assetPolicy,d.implementation].map(x=>runtime(p,x,tag)));
  const get = (name:string) => rpc(p,d.factory.address,factoryAbi,name,[],tag);
  const [[profileDomain],[schemaVersion],[walletVersion],[maximum],[uniqueMaximum],[denominator],[assetPolicy],[implementation],[implementationHash],[initCodeHash],[runtimeCodeHash]] = await Promise.all([get("PROFILE_DOMAIN"),get("SCHEMA_VERSION"),get("WALLET_VERSION"),get("MAX_ENTRIES"),get("MAX_UNIQUE_ACCOUNTS"),get("SHARE_DENOMINATOR_PPM"),get("assetPolicyRegistry"),get("splitWalletImplementation"),get("splitWalletImplementationCodeHash"),get("splitWalletInitCodeHash"),get("splitWalletRuntimeCodeHash")]);
  if (!same(profileDomain,id("6529STREAM_SPLIT_PROFILE_V1")) || schemaVersion !== 1n || walletVersion !== 4n || maximum !== 64n || uniqueMaximum !== 64n || denominator !== 1000000n || !same(assetPolicy,d.assetPolicy.address) || !same(implementation,d.implementation.address) || !same(implementationHash,d.implementation.codeHash)) throw Error("Factory version/constants/dependencies differ");
  for (const [iface,expected] of [["0x01ffc9a7",true],["0xffffffff",false],["0x620f84aa",true],[companionId,true]] as const) { const [actual] = await rpc(p,d.factory.address,factoryAbi,"supportsInterface",[iface],tag); if (actual !== expected) throw Error("Factory companion ERC165 differs"); }
  const [[marker],[active]] = await Promise.all([rpc(p,d.assetPolicy.address,assetAbi,"isStreamAssetPolicyRegistry",[],tag),rpc(p,d.assetPolicy.address,assetAbi,"ASSET_STATUS_ACTIVE",[],tag)]); if (marker !== true || active !== 1n) throw Error("Asset policy marker differs");
  for (const [name,expected] of [["factory",d.factory.address],["initialized",true],["profileId",ZERO],["entriesHash",ZERO],["metadataURIHash",ZERO],["entryCount",0n],["uniqueAccountCount",0n],["SHARE_DENOMINATOR_PPM",1000000n]] as const) { const [actual] = await rpc(p,d.implementation.address,walletAbi,name,[],tag); if (actual !== expected && !same(actual,expected)) throw Error(`Singleton locked ${name} differs`); }
  const snapshot = normalizeSplitFactorySnapshot({ context:{chainId:d.chainId,factory:d.factory.address,profileDomain:hash(profileDomain),schemaVersion:uint(schemaVersion),walletVersion:uint(walletVersion),initCodeHash:hash(initCodeHash),runtimeCodeHash:hash(runtimeCodeHash),assetPolicyRegistry:d.assetPolicy.address},factoryCodeHash:d.factory.codeHash,assetPolicyCodeHash:d.assetPolicy.codeHash,implementation:d.implementation });
  const out = capture({deployment:d,snapshot,blockNumber:tag,blockHash:h.hash}); await unchanged(p,h); return out;
}
async function saved(p: Reader, c: SplitFactoryCapture): Promise<void> { equal(await captureSplitFactory(p,c.deployment,{blockTag:c.blockNumber}),c,"Saved factory capture differs from pinned historical block"); }
function bindProfile(c: SplitFactoryCapture, input: SplitProfile): SplitProfile { const profile = normalizeSplitProfile(input); equal(profile.context,c.snapshot.context,"Profile belongs to a different factory context"); return profile; }
async function profileState(p: Reader, c: SplitFactoryCapture, profile: SplitProfile): Promise<SplitFactoryProfileInspection> {
  const tag = c.blockNumber, factory = c.deployment.factory.address, pid = profile.profileId;
  const [[prediction],[predictedId],[registered],[recognized],[entriesHash],[metadataHash],[entryCount],[uniqueCount], codeValue] = await Promise.all([rpc(p,factory,factoryAbi,"walletFor",[pid],tag),rpc(p,factory,factoryAbi,"profileIdFor",[profile.entries,profile.metadataURIHash],tag),rpc(p,factory,factoryAbi,"profileExists",[pid],tag),rpc(p,factory,factoryAbi,"splitWalletExists",[pid],tag),rpc(p,factory,factoryAbi,"profileEntriesHash",[pid],tag),rpc(p,factory,factoryAbi,"profileMetadataURIHash",[pid],tag),rpc(p,factory,factoryAbi,"profileEntryCount",[pid],tag),rpc(p,factory,factoryAbi,"profileUniqueAccountCount",[pid],tag),p.getCode(profile.wallet,tag)]);
  if (!same(prediction,profile.wallet) || !same(predictedId,pid)) throw Error("Onchain profile/CREATE2 prediction differs"); const code = bytes(codeValue,65536), deployed = code !== "0x";
  if (registered === false) { if (recognized !== false || deployed || entriesHash !== ZERO || metadataHash !== ZERO || entryCount !== 0n || uniqueCount !== 0n) throw Error("Unregistered profile has contradictory state"); return freeze({capture:c,profile,registered:false,deployed:false,initialized:false,status:"unregistered"}); }
  if (registered !== true || !same(entriesHash,profile.entriesHash) || !same(metadataHash,profile.metadataURIHash) || entryCount !== BigInt(profile.entries.length) || uniqueCount !== BigInt(profile.accounts.length)) throw Error("Registered profile metadata/counts differ");
  for (let n=0;n<profile.entries.length;n++) { const row = await rpc(p,factory,factoryAbi,"profileEntry",[pid,n],tag), expected = profile.entries[n]!; equal(Array.from(row),[expected.account,expected.sharePpm,expected.labelId],"Factory canonical entry differs"); }
  for (let n=0;n<profile.accounts.length;n++) { const row = await rpc(p,factory,factoryAbi,"profileUniqueAccount",[pid,n],tag); equal(Array.from(row),[profile.accounts[n],profile.aggregateSharePpm[n]],"Factory aggregate differs"); }
  if (!deployed) { if (recognized !== false) throw Error("Factory recognizes an absent wallet"); return freeze({capture:c,profile,registered:true,deployed:false,initialized:false,status:"registered"}); }
  verifySplitWalletCloneRuntime(c.deployment.implementation.address,code);
  if (!same(keccak256(code),c.snapshot.context.runtimeCodeHash) || recognized !== true) throw Error("Wallet is not the recognized exact factory clone");
  for (const [name,expected] of [["factory",factory],["initialized",true],["profileId",pid],["entriesHash",profile.entriesHash],["metadataURIHash",profile.metadataURIHash],["assetPolicyRegistry",c.deployment.assetPolicy.address],["entryCount",BigInt(profile.entries.length)],["uniqueAccountCount",BigInt(profile.accounts.length)],["SHARE_DENOMINATOR_PPM",1000000n]] as const) { const [actual] = await rpc(p,profile.wallet,walletAbi,name,[],tag); if (actual !== expected && !same(actual,expected)) throw Error(`Wallet initialized ${name} differs`); }
  for (let n=0;n<profile.entries.length;n++) { const row = await rpc(p,profile.wallet,walletAbi,"entry",[n],tag), expected = profile.entries[n]!; equal(Array.from(row),[expected.account,expected.sharePpm,expected.labelId],"Wallet canonical entry differs"); }
  for (let n=0;n<profile.accounts.length;n++) { const row = await rpc(p,profile.wallet,walletAbi,"uniqueAccount",[n],tag), [aggregate] = await rpc(p,profile.wallet,walletAbi,"aggregateSharePpm",[profile.accounts[n]],tag); equal(Array.from(row),[profile.accounts[n],profile.aggregateSharePpm[n]],"Wallet aggregate differs"); if (aggregate !== profile.aggregateSharePpm[n]) throw Error("Wallet aggregate mapping differs"); }
  return freeze({capture:c,profile,registered:true,deployed:true,initialized:true,status:"initialized"});
}
/** Reads all bounded canonical rows and aggregates; a prediction never establishes deployment. */
export async function inspectSplitFactoryProfile(p: Reader, input: SplitFactoryCapture, profileInput: SplitProfile, options: {readonly blockTag:number}): Promise<SplitFactoryProfileInspection> { const c=capture(input),profile=bindProfile(c,profileInput),tag=integer(options.blockTag); if(tag<c.blockNumber)throw Error("Inspection predates captured factory"); await saved(p,c); const current=await captureSplitFactory(p,c.deployment,{blockTag:tag}); equal(current.snapshot,c.snapshot,"Immutable factory context changed"); const out=await profileState(p,current,profile); await unchanged(p,{number:tag,hash:current.blockHash}); return out; }
export function prepareSplitFactoryOperation(input: SplitFactoryCapture, profileInput: SplitProfile, kind: SplitFactoryOperationKind, caller: Address): PreparedSplitFactoryOperation { const c=capture(input),profile=bindProfile(c,profileInput),prepared=prepareSplitFactoryCall(c.snapshot,addr(caller),{kind,profile}); return freeze({capture:c,prepared,kind,caller:prepared.caller,call:prepared.call}); }
function operation(v: PreparedSplitFactoryOperation): PreparedSplitFactoryOperation { exact(v,["capture","prepared","kind","caller","call"]); const base=normalizeSplitFactoryCall(v.prepared),out=prepareSplitFactoryOperation(v.capture,base.request.profile,v.kind,v.caller); equal(out,v); return out; }
/** Actual-caller eth_call preserves register/create admission and deployment's distinct lazy path. */
export async function simulateSplitFactoryOperation(p: Reader, input: PreparedSplitFactoryOperation, options: {readonly blockTag:number}): Promise<SplitFactorySimulation> { const o=operation(input),tag=integer(options.blockTag),observed=await inspectSplitFactoryProfile(p,o.capture,o.prepared.request.profile,{blockTag:tag}); if(o.kind==="deploy-wallet"&&!observed.registered)throw Error("Cannot deploy an unknown profile"); const raw=bytes(await p.call({...o.call,from:o.caller,blockTag:tag})),method=o.kind==="register-profile"?"registerProfile":o.kind==="create-profile"?"createProfile":"deployWallet",decoded=factoryAbi.decodeFunctionResult(method,raw); if(!same(factoryAbi.encodeFunctionResult(method,decoded),raw))throw Error("Noncanonical simulation return"); equal(Array.from(decoded),o.kind==="deploy-wallet"?[observed.profile.wallet]:[observed.profile.profileId,observed.profile.wallet],"Simulated profile/wallet differs"); await unchanged(p,{number:tag,hash:observed.capture.blockHash}); return freeze({operation:o,observed,returnData:raw}); }

interface ReceiptLog { readonly address: Address; readonly topics: readonly Hex[]; readonly data: Hex; readonly index: number }
interface ReceiptContext { readonly hash: Hex; readonly blockNumber: number; readonly blockHash: Hex; readonly logs: readonly ReceiptLog[]; readonly refs: SplitFactoryEventReference[] }
const safeAbi=new Interface(["function execTransaction(address to,uint256 value,bytes data,uint8 operation,uint256 safeTxGas,uint256 baseGas,uint256 gasPrice,address gasToken,address refundReceiver,bytes signatures) returns(bool)"]);
const safeLegacy=new Interface(["event ExecutionSuccess(bytes32 txHash,uint256 payment)","event ExecutionFailure(bytes32 txHash,uint256 payment)"]),safeIndexed=new Interface(["event ExecutionSuccess(bytes32 indexed txHash,uint256 payment)","event ExecutionFailure(bytes32 indexed txHash,uint256 payment)"]);
function events(r:ReceiptContext,target:Address,abi:Interface,name:string): {args:readonly unknown[];log:ReceiptLog}[] { const event=abi.getEvent(name)!; return r.logs.filter(x=>same(x.address,target)&&same(x.topics[0],event.topicHash)).map(log=>{const args=abi.decodeEventLog(event,log.data,log.topics),encoded=abi.encodeEventLog(event,args);equal(encoded.topics.map(x=>x.toLowerCase()),log.topics,"Noncanonical event topics");if(!same(encoded.data,log.data))throw Error("Noncanonical event data");return {args,log};}); }
function ref(r:ReceiptContext,log:ReceiptLog,event:string):void { r.refs.push({address:log.address,event,logIndex:log.index,transactionHash:r.hash,blockHash:r.blockHash}); }
async function mined(p:ReceiptReader,o:PreparedSplitFactoryOperation,txHash:Hex,execution:"direct"|"safe"):Promise<ReceiptContext> {
  const [receipt,tx]=await Promise.all([p.getTransactionReceipt(txHash),p.getTransaction(txHash)]);if(!receipt||!tx||receipt.status!==1||!same(receipt.hash,txHash)||!same(tx.hash,txHash)||tx.chainId!==o.capture.deployment.chainId||receipt.blockNumber<=o.capture.blockNumber||tx.blockNumber!==receipt.blockNumber||!same(tx.blockHash,receipt.blockHash)||!same(receipt.to,tx.to)||!same(receipt.from,tx.from)||tx.value!==0n)throw Error("Receipt/transaction identity or chronology differs");
  const data=bytes(tx.data,131072);if(execution==="direct"){if(!same(tx.from,o.caller)||!same(tx.to,o.call.to)||!same(data,o.call.data))throw Error("Direct operation differs");}else if(execution==="safe"){if(!same(tx.to,o.caller))throw Error("Safe address differs");const decoded=safeAbi.decodeFunctionData("execTransaction",data);if(!same(safeAbi.encodeFunctionData("execTransaction",decoded),data)||!same(decoded[0],o.call.to)||decoded[1]!==0n||!same(decoded[2],o.call.data)||decoded[3]!==0n)throw Error("Safe requires exact ordinary zero-value CALL");}else throw Error("Unsupported receipt execution mode");
  if(!Array.isArray(receipt.logs)||receipt.logs.length>256)throw Error("Receipt log count exceeds client bound");const logs=receipt.logs.map(log=>{if(log.removed||!same(log.transactionHash,txHash)||log.blockNumber!==receipt.blockNumber||!same(log.blockHash,receipt.blockHash)||!Array.isArray(log.topics)||log.topics.length>4)throw Error("Malformed receipt log identity");return {address:addr(log.address),topics:log.topics.map((x:string)=>hash(x,true)),data:bytes(log.data,16384),index:integer(log.index)};});if(new Set(logs.map(x=>x.index)).size!==logs.length||logs.some((x,n)=>n>0&&x.index<=logs[n-1]!.index))throw Error("Duplicate/unordered log indices");
  const r:ReceiptContext={hash:txHash,blockNumber:integer(receipt.blockNumber),blockHash:hash(receipt.blockHash),logs,refs:[]},h=await header(p,r.blockNumber);if(!same(h.hash,r.blockHash))throw Error("Receipt block is not canonical");
  if(execution==="safe"){const relevant=logs.filter(x=>same(x.address,o.caller)&&(same(x.topics[0],safeLegacy.getEvent("ExecutionSuccess")!.topicHash)||same(x.topics[0],safeLegacy.getEvent("ExecutionFailure")!.topicHash)));if(relevant.length!==1||!same(relevant[0]!.topics[0],safeLegacy.getEvent("ExecutionSuccess")!.topicHash))throw Error("Safe requires exactly one success and no failure");const log=relevant[0]!,abi=log.topics.length===2?safeIndexed:safeLegacy;if(events(r,o.caller,abi,"ExecutionSuccess").length!==1)throw Error("Invalid Safe success");ref(r,log,"ExecutionSuccess");}
  return r;
}
/** Successful repeats may be eventless. Later same-block deployment is observed, never attributed to registration. */
export async function inspectSplitFactoryOperationReceipt(p:ReceiptReader,input:PreparedSplitFactoryOperation,options:{readonly transactionHash:Hex;readonly execution:"direct"|"safe"}):Promise<SplitFactoryOperationReceipt>{
  const o=operation(input),txHash=hash(options.transactionHash),execution=options.execution;await saved(p,o.capture);const r=await mined(p,o,txHash,execution),profile=o.prepared.request.profile,factory=o.capture.deployment.factory.address,prior=await inspectSplitFactoryProfile(p,o.capture,profile,{blockTag:r.blockNumber-1}),observed=await inspectSplitFactoryProfile(p,o.capture,profile,{blockTag:r.blockNumber});if(!same(observed.capture.blockHash,r.blockHash)||!observed.registered||(o.kind!=="register-profile"&&!observed.initialized))throw Error("Successful operation readback is absent");
  const created=events(r,factory,factoryAbi,"SplitProfileCreated"),entries=events(r,factory,factoryAbi,"SplitProfileEntry"),deployed=events(r,factory,factoryAbi,"SplitWalletDeployed"),discovered=events(r,factory,factoryAbi,"SplitWalletDiscovered");
  if(created.length>1||deployed.length+discovered.length>1||(o.kind==="deploy-wallet"&&(created.length||entries.length))||(o.kind==="register-profile"&&(deployed.length||discovered.length)))throw Error("Unexpected lifecycle event composition");
  if(created.length){const item=created[0]!;equal(Array.from(item.args),[profile.profileId,profile.entriesHash,profile.metadataURIHash,1n,4n,profile.wallet],"Created profile event differs");if(entries.length!==profile.entries.length)throw Error("Canonical entry event count differs");ref(r,item.log,"SplitProfileCreated");for(let n=0;n<entries.length;n++){const e=entries[n]!,row=profile.entries[n]!;equal(Array.from(e.args),[profile.profileId,BigInt(n),row.account,1n,row.sharePpm,row.labelId],"Canonical entry event differs");if(e.log.index<=item.log.index)throw Error("Entry event precedes creation");ref(r,e.log,"SplitProfileEntry");}}
  else if(entries.length)throw Error("Entry events without profile creation");
  const walletEvent=deployed[0]??discovered[0];if(walletEvent){equal(Array.from(walletEvent.args),[profile.profileId,profile.wallet,4n,1n,profile.context.initCodeHash,profile.context.runtimeCodeHash],"Wallet deployment event differs");if(entries.length&&walletEvent.log.index<=entries.at(-1)!.log.index)throw Error("Wallet deployment precedes registration entries");ref(r,walletEvent.log,deployed.length?"SplitWalletDeployed":"SplitWalletDiscovered");}
  if(!created.length&&!prior.registered)throw Error("Eventless registration requires prior-block registration evidence; same-block history is not proven");
  if(!walletEvent&&o.kind!=="register-profile"&&!prior.initialized)throw Error("Eventless wallet retry requires prior-block initialization evidence; same-block history is not proven");
  if((created.length&&prior.registered)||(deployed.length&&prior.deployed))throw Error("Lifecycle event contradicts immutable prior-block state");
  const success=r.refs.find(x=>x.event==="ExecutionSuccess");if(success&&r.refs.some(x=>x.event!=="ExecutionSuccess"&&x.logIndex>=success.logIndex))throw Error("Safe success must follow target lifecycle events");
  await unchanged(p,{number:prior.capture.blockNumber,hash:prior.capture.blockHash});await unchanged(p,{number:r.blockNumber,hash:r.blockHash});return freeze({operation:o,transactionHash:txHash,blockNumber:r.blockNumber,blockHash:r.blockHash,prior,observed,events:r.refs.sort((a,b)=>a.logIndex-b.logIndex),registration:created.length?"created":"reused",deployment:o.kind==="register-profile"?"not-requested":deployed.length?"deployed":discovered.length?"discovered":"reused",stateAttribution:"receipt-block observation; lifecycle changes attributed only by matching events"});
}

const factoryAbi = new Interface([
  "event SplitProfileCreated(bytes32 indexed profileId, bytes32 indexed entriesHash, bytes32 indexed metadataURIHash, uint16 schemaVersion, uint16 walletVersion, address wallet)",
  "event SplitProfileEntry(bytes32 indexed profileId, uint16 indexed index, address indexed account, uint16 schemaVersion, uint32 sharePpm, bytes32 labelId)",
  "event SplitWalletDeployed(bytes32 indexed profileId, address indexed wallet, uint16 indexed walletVersion, uint16 schemaVersion, bytes32 initCodeHash, bytes32 runtimeCodeHash)",
  "event SplitWalletDiscovered(bytes32 indexed profileId, address indexed wallet, uint16 indexed walletVersion, uint16 schemaVersion, bytes32 initCodeHash, bytes32 runtimeCodeHash)",
  "function MAX_ENTRIES() view returns (uint16)",
  "function MAX_UNIQUE_ACCOUNTS() view returns (uint16)",
  "function PROFILE_DOMAIN() view returns (bytes32)",
  "function SCHEMA_VERSION() view returns (uint16)",
  "function SHARE_DENOMINATOR_PPM() view returns (uint32)",
  "function WALLET_VERSION() view returns (uint16)",
  "function assetPolicyRegistry() view returns (address)",
  "function createProfile((address account, uint32 sharePpm, bytes32 labelId)[] entries, bytes32 metadataURIHash) returns (bytes32 profileId, address wallet)",
  "function deployWallet(bytes32 profileId) returns (address wallet)",
  "function profileEntriesHash(bytes32 profileId) view returns (bytes32)",
  "function profileEntry(bytes32 profileId, uint256 index) view returns (address account, uint32 sharePpm, bytes32 labelId)",
  "function profileEntryCount(bytes32 profileId) view returns (uint256)",
  "function profileExists(bytes32 profileId) view returns (bool)",
  "function profileIdFor((address account, uint32 sharePpm, bytes32 labelId)[] entries, bytes32 metadataURIHash) view returns (bytes32)",
  "function profileMetadataURIHash(bytes32 profileId) view returns (bytes32)",
  "function profileUniqueAccount(bytes32 profileId, uint256 index) view returns (address account, uint32 sharePpm)",
  "function profileUniqueAccountCount(bytes32 profileId) view returns (uint256)",
  "function registerProfile((address account, uint32 sharePpm, bytes32 labelId)[] entries, bytes32 metadataURIHash) returns (bytes32 profileId, address wallet)",
  "function splitWalletExists(bytes32 profileId) view returns (bool)",
  "function splitWalletImplementation() view returns (address)",
  "function splitWalletImplementationCodeHash() view returns (bytes32)",
  "function splitWalletInitCodeHash() view returns (bytes32)",
  "function splitWalletRuntimeCodeHash() view returns (bytes32)",
  "function supportsInterface(bytes4 interfaceId) pure returns (bool)",
  "function walletFor(bytes32 profileId) view returns (address)"
]);
const walletAbi = new Interface([
  "function SHARE_DENOMINATOR_PPM() view returns (uint32)",
  "function aggregateSharePpm(address) view returns (uint32)",
  "function assetPolicyRegistry() view returns (address registry)",
  "function entriesHash() view returns (bytes32)",
  "function entry(uint256 index) view returns (address account, uint32 sharePpm, bytes32 labelId)",
  "function entryCount() view returns (uint256)",
  "function factory() view returns (address)",
  "function initialized() view returns (bool)",
  "function metadataURIHash() view returns (bytes32)",
  "function profileId() view returns (bytes32)",
  "function uniqueAccount(uint256 index) view returns (address account, uint32 sharePpm)",
  "function uniqueAccountCount() view returns (uint256)"
]);
const assetAbi = new Interface([
  "function ASSET_STATUS_ACTIVE() pure returns (uint8)",
  "function isStreamAssetPolicyRegistry() pure returns (bool)"
]);
