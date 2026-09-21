/** Complete one-use VIEW source binding at source9381 / ABI146. No publication or finality. */
import { Interface, id, keccak256 } from "ethers";
import type { Address, Hex } from "./generated/contracts.js";
import * as binding from "./current-view-complete-binding.js";
import * as governanceCodec from "./current-scoped-policy-finality-v2.js";
import * as graph from "./current-scoped-policy-graph-v2.js";
import * as inventory from "./current-scoped-policy-inventory-v2.js";
import * as reference from "./current-scoped-policy-reference-v2.js";
import * as bundle from "./current-scoped-policy-bundle-v2.js";
import * as io from "./current-scoped-policy-inventory-archive-workflow-internal.js";

const governanceAbi = new Interface([
  "function owner() view returns (address)",
  "function roleRegistry() view returns (address)",
  "function governanceRootState() view returns (address governanceRoot_, bytes32 codeHash, uint64 revision)",
  "function systemManifestBootstrapState() view returns (bool, bool, address, bytes32, address, bytes32, uint64, bytes32, uint256, bytes32, uint64, address, bytes32, address, bytes32, bytes32, uint256, bytes32, uint256, bytes32, bytes32, uint256, bytes32, uint256, address, address, bytes32, bytes32, uint256)",
  "function governanceActionPolicyState() view returns (bytes32 candidateProfileHash, bytes32 catalogHash, uint256 entryCount, uint64 revision)",
  "function governanceNonce() view returns (uint256)",
  "function isProposer(address account) view returns (bool)",
  "function minimumDelay(uint8 actionClass) pure returns (uint64)",
  "function publishedCallData(bytes32 callDataKey) view returns (address)",
  "function scheduledCallData(bytes32 actionId) view returns (bytes[])",
  "function scheduledCallDataPointer(bytes32 actionId) view returns (address)",
  "function governanceAction(bytes32 actionId) view returns ((uint8 status, uint8 actionClass, address target, uint256 value, bytes4 selector, bytes32 callHash, bytes32 scopeHash, bytes32 oldValueHash, bytes32 newValueHash, uint64 notBefore, uint64 expiresAfter, address proposer, address executor, address canceller, address vetoer, bytes32 reasonHash, string reasonURI, bytes32 manifestHash))",
  "function terminalFreezeGuardianConfigCommitment(bytes32 actionId) view returns (bytes32 commitment)",
  "function terminalFreezeVetoGuardianSet(bytes32 scopeHash) view returns (address roleRegistryAddress, bytes32 scopedRole, uint256 scopedHolderCount, bytes32 globalRole, uint256 globalHolderCount, uint64 vetoDeadline)",
  "function terminalFreezeActionPage(bytes32 scopeHash, uint256 cursor, uint256 limit) view returns (bytes32[] actionIds, uint64[] vetoDeadlines, uint256 nextCursor)",
  "function terminalFreezeLiveActionUsage(bytes32 scopeHash, address proposer) view returns (uint256 totalMemberships, uint256 nonRootMemberships, uint256 proposerMemberships)",
  "function terminalFreezeLiveActionCaps() pure returns (uint256 totalCap, uint256 nonRootCap, uint256 perNonRootProposerCap)",
  "function freezeSelectorConfig(address target, bytes4 selector) view returns (bool freeze, bytes32 targetCodeHash, uint64 revision, bytes32 stateHash)",
  "function isRoleRedundant(bytes32 role) view returns (bool)",
  "function roleMutationState(bytes32 role) view returns (bytes32 chainHash, uint64 revision)",
  "function roleHolderCount(bytes32 role) view returns (uint256)",
  "function roleHolderAt(bytes32 role, uint256 index) view returns (address)",
]);

const { ZERO, ZERO_ADDRESS, coder } = io;
const DAY = 86400n;
const VETO = id("ROLE_TERMINAL_FREEZE_VETO") as Hex;
const MAX_GUARDIANS = 16n, MAX_MEMBERSHIPS = 256n;
type Reader = io.Reader;
type ReceiptReader = io.ReceiptReader;
export type ViewCompleteBindingCodePin = io.CodePin;
export type ViewCompleteBindingReceiptOptions = io.ReceiptOptions;
/** Reviewed deployment/link metadata is a trust input, not established by a supplied hash. */
export interface ViewCompleteBindingDeployment {
  readonly chainId: bigint;
  readonly provider: io.CodePin;
  readonly executor: io.CodePin;
  readonly roles: io.CodePin;
  readonly bindingWorker: io.CodePin;
  /** Snapshot Sources, checkpoint Source, checkpoint Token, manifest Reads, manifest Encoding. */
  readonly workers: readonly [io.CodePin, io.CodePin, io.CodePin, io.CodePin, io.CodePin];
  readonly linkedDependencies: readonly io.CodePin[];
}
export interface ViewCompleteBindingHistoryDeployment {
  readonly chainId: bigint;
  readonly provider: io.CodePin;
  readonly bindingWorker: io.CodePin;
  /** Only the local history-reader closure, not current source dependencies. */
  readonly linkedDependencies: readonly io.CodePin[];
}
function copy<T>(v: T): T { return structuredClone(v); }
function coords(d: ViewCompleteBindingHistoryDeployment) { return { chainId: d.chainId, provider: d.provider.address }; }
function historyDeployment(v: ViewCompleteBindingHistoryDeployment): ViewCompleteBindingHistoryDeployment {
  io.keys(v, ["chainId", "provider", "bindingWorker", "linkedDependencies"]);
  if (!io.uint(v.chainId)) throw Error("Zero chain");
  return io.freeze({ chainId: v.chainId, provider: io.codePin(v.provider), bindingWorker: io.codePin(v.bindingWorker), linkedDependencies: io.pinList(v.linkedDependencies) });
}
function deployment(v: ViewCompleteBindingDeployment): ViewCompleteBindingDeployment {
  io.keys(v, ["chainId", "provider", "executor", "roles", "bindingWorker", "workers", "linkedDependencies"]);
  if (!io.uint(v.chainId) || !Array.isArray(v.workers) || v.workers.length !== 5) throw Error("Deployment shape differs");
  const w = io.pinList(v.workers);
  return io.freeze({ chainId: v.chainId, provider: io.codePin(v.provider), executor: io.codePin(v.executor), roles: io.codePin(v.roles),
    bindingWorker: io.codePin(v.bindingWorker), workers: [w[0]!,w[1]!,w[2]!,w[3]!,w[4]!] as const, linkedDependencies: io.pinList(v.linkedDependencies) });
}
function iface() { return binding.viewCompleteBindingInterface(); }
function observation() { return binding.viewCompleteBindingObservationInterface(); }
// The complete original Executor ABI and hash recipes are unchanged from896899f7 to9381dd99.
function executor() { return governanceCodec.scopedPolicyFinalityV2Interface("executor"); }
function read<T>(p: Reader, target: Address, method: string, args: readonly unknown[], tag: number) {
  return io.read<T>(p, target, governanceAbi, method, args, tag);
}
function rows(p: Reader, target: Address, method: string, args: readonly unknown[], tag: number) {
  return io.rpc(p, target, governanceAbi, method, args, tag);
}

const snapshotAbi = new Interface([`function dependencies() view returns (${binding.VIEW_COMPLETE_BINDING_SNAPSHOT_DEPENDENCIES_TUPLE})`]);
const referenceAbi = new Interface([`function dependencies() view returns (${reference.SCOPED_POLICY_REFERENCE_V2_DEPENDENCIES_TUPLE})`]);
const inventoryAbi = new Interface([`function dependencies() view returns (${inventory.SCOPED_POLICY_INVENTORY_V2_DEPENDENCIES_TUPLE})`]);
const bundleAbi = new Interface([`function dependencies() view returns (${bundle.SCOPED_POLICY_BUNDLE_V2_DEPENDENCIES_TUPLE})`]);
const factoryAbi = new Interface([
  `function scopedPreservationPolicyPublicationBinding() view returns (${graph.SCOPED_POLICY_GRAPH_V2_FACTORY_BINDING_TUPLE})`,
  `function recipe() view returns (${graph.SCOPED_POLICY_GRAPH_V2_RECIPE_TUPLE})`,
  "function recipeHash() view returns (bytes32)", "function sourceFactoryDependenciesHash() view returns (bytes32)",
  "function scopedPreservationPolicyPublicationFactoryProfile() pure returns (bytes32)",
  "function originDependencies() view returns ((address worker,bytes32 workerCodeHash,uint256 originGas,bytes32 profile))",
  "function authorityDependencies() view returns ((address resolver,bytes32 resolverCodeHash,uint256 resolverGas))"
]);
const sourceFactoryAbi = new Interface([`function dependencies() view returns (${graph.SCOPED_POLICY_GRAPH_V2_SOURCE_DEPENDENCIES_TUPLE})`]);
const gettersAbi = new Interface([
  "function sourceWorkerCodeHash() view returns (bytes32)", "function tokenWorkerCodeHash() view returns (bytes32)",
  "function readWorkerCodeHash() view returns (bytes32)", "function encodingWorkerCodeHash() view returns (bytes32)",
  "function governanceAuthority() view returns (address)", "function executorCodeHash() view returns (bytes32)",
  "event ViewPreservationBound(bytes32 indexed recordHash,bytes32 indexed actionId,address indexed snapshotHost,bytes32 proposalHash,bytes32 dependenciesHash)"
]);
function encodedHash(type: string, value: unknown): Hex { return keccak256(coder.encode([type],[value])) as Hex; }
function roster(targets: readonly Address[], hashes: readonly Hex[]): io.CodePin[] {
  if (targets.length !== hashes.length) throw Error("Roster shape differs");
  return targets.map((address,i) => io.codePin({address,codeHash:hashes[i]!}));
}
async function sources(p: Reader, candidate: binding.ViewCompleteBindingCandidate, tag: number) {
  const s = candidate.selection;
  const r = reference.normalizeScopedPolicyReferenceV2Dependencies(await io.read<reference.ScopedPolicyReferenceV2Dependencies>(p,s.referencePublication,referenceAbi,"dependencies",[],tag));
  const i = inventory.normalizeScopedPolicyInventoryV2Dependencies(await io.read<inventory.ScopedPolicyInventoryV2Dependencies>(p,s.renderCriticalInventory,inventoryAbi,"dependencies",[],tag));
  const b = bundle.normalizeScopedPolicyBundleV2Dependencies(await io.read<bundle.ScopedPolicyBundleV2Dependencies>(p,s.bundleArchiveCoverage,bundleAbi,"dependencies",[],tag));
  const pins = [...roster(r.targets,r.codeHashes), ...roster(i.targets,i.codeHashes), ...roster(i.artistTargets,i.artistCodeHashes),
    io.codePin({address:i.artistContentOwner,codeHash:i.artistContentOwnerCodeHash}),...roster(b.targets,b.codeHashes),
    {address:s.referencePublication,codeHash:s.referencePublicationCodeHash},
    {address:s.renderCriticalInventory,codeHash:s.renderCriticalInventoryCodeHash},
    {address:s.bundleArchiveCoverage,codeHash:s.bundleArchiveCoverageCodeHash}];
  await io.runtimes(p,pins,tag);
  return { reference:r,inventory:i,bundle:b,pins };
}
async function factory(p: Reader,d:ViewCompleteBindingDeployment,tag:number) {
  const value = graph.normalizeScopedPolicyGraphV2FactoryBinding(await io.read<graph.ScopedPolicyGraphV2FactoryBinding>(p,d.provider.address,factoryAbi,"scopedPreservationPolicyPublicationBinding",[],tag));
  await io.runtime(p,{address:value.factory,codeHash:value.factoryCodeHash},tag);
  const recipe = graph.normalizeScopedPolicyGraphV2Recipe(await io.read<graph.ScopedPolicyGraphV2Recipe>(p,value.factory,factoryAbi,"recipe",[],tag));
  const profile = io.hash(await io.read(p,value.factory,factoryAbi,"scopedPreservationPolicyPublicationFactoryProfile",[],tag));
  const legacy = id("6529STREAM_SCOPED_PRESERVATION_POLICY_PUBLICATION_FACTORY_V1");
  const current = id("6529STREAM_CURRENT_AUTHORITY_SCOPED_PRESERVATION_POLICY_PUBLICATION_FACTORY_V1");
  let actual:Hex;
  if (profile === legacy) actual = keccak256(coder.encode(["bytes32","uint256",graph.SCOPED_POLICY_GRAPH_V2_RECIPE_TUPLE],[profile,d.chainId,recipe])) as Hex;
  else if (profile === current) {
    const origin = await io.read(p,value.factory,factoryAbi,"originDependencies",[],tag);
    const authority = await io.read(p,value.factory,factoryAbi,"authorityDependencies",[],tag);
    actual = keccak256(coder.encode(["bytes32","uint256",graph.SCOPED_POLICY_GRAPH_V2_RECIPE_TUPLE,
      "(address worker,bytes32 workerCodeHash,uint256 originGas,bytes32 profile)","(address resolver,bytes32 resolverCodeHash,uint256 resolverGas)"],
      [profile,d.chainId,recipe,origin,authority])) as Hex;
  } else throw Error("Unsupported publication factory profile");
  io.equal(value.recipeHash,actual,"Factory recipe differs");
  io.equal(await io.read(p,value.factory,factoryAbi,"recipeHash",[],tag),actual);
  io.equal(await io.read(p,value.factory,factoryAbi,"sourceFactoryDependenciesHash",[],tag),value.sourceFactoryDependenciesHash);
  const source = {address:recipe.targets[2],codeHash:recipe.codeHashes[2]};
  await io.runtime(p,source,tag);
  const dependencies = graph.normalizeScopedPolicyGraphV2SourceDependencies(await io.read<graph.ScopedPolicyGraphV2SourceDependencies>(p,source.address,sourceFactoryAbi,"dependencies",[],tag));
  io.equal(encodedHash(graph.SCOPED_POLICY_GRAPH_V2_SOURCE_DEPENDENCIES_TUPLE,dependencies),value.sourceFactoryDependenciesHash,"Source factory dependencies differ");
  const pins = [{address:value.factory,codeHash:value.factoryCodeHash},source,...roster(dependencies.targets,dependencies.codeHashes)];
  await io.runtimes(p,pins,tag);
  return {value,recipe,profile,dependencies,pins};
}
export interface ViewCompleteBindingPreview {
  readonly deployment: ViewCompleteBindingDeployment;
  readonly candidate: binding.ViewCompleteBindingCandidate;
  readonly observed: io.Block;
  readonly gasLimit: bigint;
  readonly basic: binding.ViewCompleteBindingBasicReceipt;
  readonly complete: binding.ViewCompleteBindingReceipt;
  readonly transition: binding.ViewCompleteBindingTransition;
  readonly runtimePins: readonly io.CodePin[];
  readonly snapshotHash: Hex;
  readonly originalCallAdmissionRequired: true;
}
/** Genuine original preview admission; it neither creates publication records nor executes Governance. */
export async function previewViewCompleteBinding(p:Reader,input:ViewCompleteBindingDeployment,inputCandidate:binding.ViewCompleteBindingCandidate,options:{readonly blockTag:number;readonly gasLimit:bigint}):Promise<ViewCompleteBindingPreview> {
  const d=deployment(input), candidate=binding.normalizeViewCompleteBindingCandidate(inputCandidate);
  const tag=io.number(options.blockTag),gasLimit=io.gas(options.gasLimit);
  const observed=await io.chain(p,d.chainId,tag);
  const fixed=[d.provider,d.executor,d.bindingWorker,...d.workers,...d.linkedDependencies];
  await io.runtimes(p,fixed,tag);
  const original=binding.normalizeViewCompleteBindingNativeConfiguration(await io.read<binding.ViewCompleteBindingNativeConfiguration>(p,d.provider.address,observation(),"nativeConfiguration",[],tag));
  const capability=binding.normalizeViewCompleteBindingCapability(await io.read<binding.ViewCompleteBindingCapability>(p,d.provider.address,observation(),"viewPreservationBindingCapability",[],tag));
  io.equal(capability.authority,d.executor.address,"Constructor-captured governance authority differs");
  io.equal(capability.authorityCodeHash,d.executor.codeHash);
  io.equal(capability.originalHash,encodedHash(binding.VIEW_COMPLETE_BINDING_NATIVE_CONFIGURATION_TUPLE,original));
  io.equal(capability.capabilityHash,binding.viewCompleteBindingCapabilityHash(coords(d),capability));
  io.equal(original.chainId,d.chainId);
  io.equal(await io.read(p,d.provider.address,observation(),"viewPreservationBindingStatus",[],tag),0n,"One-use binding already consumed");
  const before=binding.normalizeViewCompleteBindingBasicReceipt(await io.read<binding.ViewCompleteBindingBasicReceipt>(p,d.provider.address,observation(),"viewPreservationBindingReceipt",[],tag));
  if (!/^0x0+$/.test(binding.encodeViewCompleteBindingBasicReceipt(before))) throw Error("Pending receipt is not empty");
  io.equal(await io.read(p,d.provider.address,iface(),"completeViewPreservationBindingProfile",[],tag),binding.VIEW_COMPLETE_BINDING_PROFILE);
  const c=candidate.configuration;
  const deps=binding.normalizeViewCompleteBindingSnapshotDependencies(await io.read<binding.ViewCompleteBindingSnapshotDependencies>(p,c.snapshotHost,snapshotAbi,"dependencies",[],tag));
  const originInventory=inventory.normalizeScopedPolicyInventoryV2Dependencies(await io.read<inventory.ScopedPolicyInventoryV2Dependencies>(p,original.targets[18]!,inventoryAbi,"dependencies",[],tag));
  io.equal(encodedHash(inventory.SCOPED_POLICY_INVENTORY_V2_DEPENDENCIES_TUPLE,originInventory),original.inventoryDependencyHash);
  const closure=await sources(p,candidate,tag),factoryObservation=await factory(p,d,tag);
  const runtimePins=[...fixed,...closure.pins,...factoryObservation.pins,...roster(deps.targets,deps.codeHashes),
    {address:original.targets[18]!,codeHash:original.codeHashes[18]!},
    {address:c.snapshotHost,codeHash:c.snapshotCodeHash},{address:c.checkpointHost,codeHash:c.checkpointCodeHash},
    {address:c.manifestHost,codeHash:c.manifestCodeHash},
    {address:candidate.declaration.views,codeHash:candidate.declaration.viewsCodeHash},
    {address:candidate.declaration.membership,codeHash:candidate.declaration.membershipCodeHash}];
  await io.runtimes(p,runtimePins,tag);
  for(const [host,name,index] of [[c.checkpointHost,"sourceWorkerCodeHash",1],[c.checkpointHost,"tokenWorkerCodeHash",2],[c.manifestHost,"readWorkerCodeHash",3],[c.manifestHost,"encodingWorkerCodeHash",4]] as const)
    io.equal(await io.read(p,host,gettersAbi,name,[],tag),d.workers[index]!.codeHash,"Reviewed worker differs");
  const basic:binding.ViewCompleteBindingBasicReceipt={capabilityHash:capability.capabilityHash,configuration:c,declaration:candidate.declaration,
    dependencies:deps,dependenciesHash:encodedHash(binding.VIEW_COMPLETE_BINDING_SNAPSHOT_DEPENDENCIES_TUPLE,deps),
    workersHash:binding.viewCompleteBindingWorkersHash(d.workers.map(w=>w.address) as [Address,Address,Address,Address,Address],d.workers.map(w=>w.codeHash) as [Hex,Hex,Hex,Hex,Hex]),actionId:ZERO,boundAt:0n,recordHash:ZERO};
  const complete:binding.ViewCompleteBindingReceipt={selection:candidate.selection,
    referenceDependenciesHash:encodedHash(reference.SCOPED_POLICY_REFERENCE_V2_DEPENDENCIES_TUPLE,closure.reference),
    inventoryDependenciesHash:encodedHash(inventory.SCOPED_POLICY_INVENTORY_V2_DEPENDENCIES_TUPLE,closure.inventory),
    bundleDependenciesHash:encodedHash(bundle.SCOPED_POLICY_BUNDLE_V2_DEPENDENCIES_TUPLE,closure.bundle),
    basicBindingRecordHash:ZERO,actionId:ZERO,boundAt:0n,recordHash:ZERO};
  binding.validateViewCompleteBindingBasicCandidate(coords(d),original,capability,basic);
  const expected=binding.deriveViewCompleteBindingExpected(original,basic,candidate.selection,originInventory);
  binding.validateViewCompleteBindingProducerDependencies(expected,candidate.selection,closure.reference,closure.inventory,closure.bundle);
  const transition=binding.viewCompleteBindingTransition(coords(d),basic,complete);
  const actual=await io.read(p,d.provider.address,iface(),"completeViewPreservationBindingTransition",[candidate.configuration,candidate.declaration,candidate.selection],tag,d.executor.address,gasLimit);
  io.equal(actual,transition,"Original complete transition differs");
  await io.unchanged(p,observed);
  const result={deployment:d,candidate,observed,gasLimit,basic,complete,transition,runtimePins,originalCallAdmissionRequired:true as const};
  return io.freeze({...result,snapshotHash:io.fingerprint(result)});
}

export type ViewCompleteBindingWindow = governanceCodec.ScopedPolicyFinalityV2GovernanceWindow;
export interface ViewCompleteBindingBatch {
  readonly coordinates: binding.ViewCompleteBindingCoordinates;
  readonly executor: Address;
  readonly candidate: binding.ViewCompleteBindingCandidate;
  readonly basic: binding.ViewCompleteBindingBasicReceipt;
  readonly complete: binding.ViewCompleteBindingReceipt;
  readonly transition: binding.ViewCompleteBindingTransition;
  readonly nonce: bigint;
  readonly window: ViewCompleteBindingWindow;
  readonly calls: readonly governanceCodec.ScopedPolicyFinalityV2GovernanceCall[];
  readonly callDatas: readonly Hex[];
  readonly callsHash: Hex;
  readonly scopeHash: Hex;
  readonly oldValueHash: Hex;
  readonly newValueHash: Hex;
  readonly actionId: Hex;
  readonly publicationKey: Hex;
  readonly publicationCall: io.Call;
  readonly scheduleCall: io.Call;
  readonly executionCall: io.Call;
}
function batchFor(coordinates:binding.ViewCompleteBindingCoordinates,authority:Address,candidate:binding.ViewCompleteBindingCandidate,
  basic:binding.ViewCompleteBindingBasicReceipt,complete:binding.ViewCompleteBindingReceipt,nonce:bigint,inputWindow:ViewCompleteBindingWindow):ViewCompleteBindingBatch {
  const n=io.uint(nonce),window=governanceCodec.normalizeScopedPolicyFinalityV2GovernanceWindow(inputWindow);
  const transition=binding.viewCompleteBindingTransition(coordinates,basic,complete);
  const target=binding.prepareViewCompleteBindingCall(coordinates,candidate).call;
  const row={target:target.to,value:0n,selector:target.data.slice(0,10) as Hex,callDataHash:keccak256(target.data) as Hex,...transition};
  const calls=[row],callDatas=[target.data];
  const hash=(types:readonly string[],values:readonly unknown[])=>keccak256(coder.encode(types,values)) as Hex;
  const callsHash=hash(["bytes32",`${governanceCodec.SCOPED_POLICY_FINALITY_V2_GOVERNANCE_CALL_TUPLE}[]`],["0x10f09566fb70f7947b61639c2a53b3aec872069a8b46edd08ba14eb2b5942b70",calls]);
  const aggregate=(domain:Hex,field:"scopeHash"|"oldValueHash"|"newValueHash")=>hash(["bytes32","bytes32","bytes32[]"],[domain,callsHash,[row[field]]]);
  const scopeHash=aggregate("0x6cfd5dfd67f064adac45602c05057edddda810734779c0ebe11b447e6985e31c","scopeHash");
  const oldValueHash=aggregate("0xc5029f937b44065c2ad92d9253e07f06117567480206189fcc1409d5509222b7","oldValueHash");
  const newValueHash=aggregate("0xce958009248d20d9574439fa374bc00c142940af2b496896b5bdbc00b882e98b","newValueHash");
  const actionId=hash(["bytes32","uint256","address",governanceCodec.SCOPED_POLICY_FINALITY_V2_ACTION_IDENTITY_TUPLE],
    ["0x214cd728538bb3775a7106caff5c761bace11866a984d4a4d97a98f51971ac4b",coordinates.chainId,authority,
      {actionClass:2n,callsHash,scopeHash,oldValueHash,newValueHash,nonce:n,notBefore:window.notBefore,expiresAfter:window.expiresAfter,reasonHash:window.reasonHash,manifestHash:window.manifestHash}]);
  const call=(method:string,args:readonly unknown[]):io.Call=>({to:authority,value:0n,data:io.bytes(executor().encodeFunctionData(method,args),io.MAX_CALL)});
  return io.freeze({coordinates,executor:authority,candidate,basic,complete,transition,nonce:n,window,calls,callDatas,callsHash,scopeHash,oldValueHash,newValueHash,actionId,
    publicationKey:keccak256(row.callDataHash) as Hex,publicationCall:call("publishGovernanceCallData",[callDatas]),
    scheduleCall:call("scheduleGovernanceBatch",[2n,calls,scopeHash,oldValueHash,newValueHash,window.notBefore,window.expiresAfter,window.reasonHash,window.reasonURI,window.manifestHash]),
    executionCall:call("executeGovernanceBatch",[actionId,calls,callDatas])});
}
function checkedPreview(input:ViewCompleteBindingPreview) {
  const value=copy(input),{snapshotHash,...rest}=value;
  io.equal(io.fingerprint(rest),io.hash(snapshotHash),"Preview fingerprint differs");
  deployment(value.deployment);binding.normalizeViewCompleteBindingCandidate(value.candidate);
  io.equal(value.transition,binding.viewCompleteBindingTransition(coords(value.deployment),value.basic,value.complete));
  return io.freeze(value);
}
export function prepareViewCompleteBindingBatch(input:ViewCompleteBindingPreview,nonce:bigint,window:ViewCompleteBindingWindow):ViewCompleteBindingBatch {
  const p=checkedPreview(input);
  return batchFor(coords(p.deployment),p.deployment.executor.address,p.candidate,p.basic,p.complete,nonce,window);
}
function normalizeBatch(input:ViewCompleteBindingBatch):ViewCompleteBindingBatch {
  const v=copy(input);
  const result=batchFor({chainId:io.uint(v.coordinates.chainId),provider:io.address(v.coordinates.provider)},io.address(v.executor),
    binding.normalizeViewCompleteBindingCandidate(v.candidate),binding.normalizeViewCompleteBindingBasicReceipt(v.basic),binding.normalizeViewCompleteBindingReceipt(v.complete),v.nonce,v.window);
  io.equal(result,v,"Complete governance batch differs");return result;
}
export type ViewCompleteBindingStage = "publishGovernanceCallData"|"scheduleGovernanceBatch"|"executeGovernanceBatch";
export interface ViewCompleteBindingPrepared {
  readonly caller:Address;
  readonly request:{readonly kind:ViewCompleteBindingStage;readonly batch:ViewCompleteBindingBatch};
  readonly call:io.Call;
}
function prepared(caller:Address,kind:ViewCompleteBindingStage,input:ViewCompleteBindingBatch):ViewCompleteBindingPrepared {
  const batch=normalizeBatch(input),actor=io.address(caller);
  if(!["publishGovernanceCallData","scheduleGovernanceBatch","executeGovernanceBatch"].includes(kind)) throw Error("Unsupported outer stage");
  return io.freeze({caller:actor,request:{kind,batch},call:kind==="publishGovernanceCallData"?batch.publicationCall:kind==="scheduleGovernanceBatch"?batch.scheduleCall:batch.executionCall});
}
type Batch=ViewCompleteBindingBatch;
type Prepared=ViewCompleteBindingPrepared;
export interface ViewCompleteBindingGuardianObservation {
  readonly commitment: Hex;
  readonly targetScope: Hex;
  readonly scopedRole: Hex;
  readonly mutationStates: readonly (readonly [Hex, bigint])[];
  readonly holders: readonly (readonly io.CodePin[])[];
}

async function guardianObservation(
  provider: Reader, d: ViewCompleteBindingDeployment, scope: Hex, tag: number
): Promise<ViewCompleteBindingGuardianObservation> {
  const scopedRole = keccak256(coder.encode(["bytes32", "bytes32"], [VETO, scope])) as Hex;
  const roles = [VETO, scopedRole];
  const mutationStates: [Hex, bigint][] = [];
  const holders: io.CodePin[][] = [];
  io.equal(await read(provider, d.roles.address, "owner", [], tag), d.executor.address, "Role registry owner differs");
  io.equal(await read(provider, d.roles.address, "isRoleRedundant", [VETO], tag), true, "Original global veto redundancy required");
  for (const role of roles) {
    const mutation = await rows(provider, d.roles.address, "roleMutationState", [role], tag);
    mutationStates.push([io.hash(mutation[0], true), io.uint(mutation[1], 64)]);
    const count = io.uint(await read(provider, d.roles.address, "roleHolderCount", [role], tag));
    if (count > MAX_GUARDIANS) throw Error("Guardian count exceeds original bound");
    const group: io.CodePin[] = [];
    for (let i = 0n; i < count; i++) {
      const address = io.address(await read(provider, d.roles.address, "roleHolderAt", [role, i], tag));
      const code = io.bytes(await provider.getCode(address, tag), io.MAX_RUNTIME);
      // This current profile requires live original contract guardians; it does not classify EOAs.
      if (code === "0x" || code.length === 48 && code.startsWith("0xef0100")) throw Error("Guardian runtime unavailable or delegated");
      group.push({ address, codeHash: keccak256(code) as Hex });
    }
    if (new Set(group.map(p => p.address)).size !== group.length) throw Error("Duplicate guardian");
    holders.push(group);
  }
  const domain = id("6529STREAM_TERMINAL_GUARDIAN_CONFIG_V1");
  let commitment = keccak256(coder.encode(
    ["bytes32", "uint256", "address", "address", "bytes32", "bytes32", "uint64"],
    [domain, d.chainId, d.executor.address, d.roles.address, d.roles.codeHash, ...mutationStates[0]!]
  )) as Hex;
  for (let j = 0; j < 2; j++) {
    if (j === 1) commitment = keccak256(coder.encode(
      ["bytes32", "bytes32", "bytes32", "bytes32", "bytes32", "uint64"],
      [id("6529STREAM_TERMINAL_GUARDIAN_SCOPE_V1"), commitment, scope, scopedRole, ...mutationStates[j]!]
    )) as Hex;
    commitment = keccak256(coder.encode(["bytes32", "bytes32", "bytes32", "uint256"],
      [id("6529STREAM_TERMINAL_GUARDIAN_HOLDER_V1"), commitment, roles[j], holders[j]!.length])) as Hex;
    for (let i = 0; i < holders[j]!.length; i++) commitment = keccak256(coder.encode(
      ["bytes32", "bytes32", "bytes32", "uint256", "address", "bytes32"],
      [id("6529STREAM_TERMINAL_GUARDIAN_HOLDER_V1"), commitment, roles[j], i, holders[j]![i]!.address, holders[j]![i]!.codeHash]
    )) as Hex;
  }
  commitment = keccak256(coder.encode(["bytes32", "bytes32", "uint256"], [domain, commitment, 1n])) as Hex;
  const observed = await rows(provider, d.executor.address, "terminalFreezeVetoGuardianSet", [scope], tag);
  io.equal(observed.slice(0, 5), [d.roles.address, scopedRole, BigInt(holders[1]!.length), VETO, BigInt(holders[0]!.length)],
    "Original target-scope guardian set differs");
  return { commitment, targetScope: scope, scopedRole, mutationStates, holders };
}

export interface ViewCompleteBindingGovernanceObservation {
  readonly publication: Address;
  readonly catalog: readonly [Hex, Hex, bigint, bigint] | null;
  readonly root: io.CodePin | null;
  readonly governanceNonce: bigint | null;
  readonly action: governanceCodec.ScopedPolicyFinalityV2GovernanceAction;
  readonly guardian: ViewCompleteBindingGuardianObservation | null;
  readonly membershipIds: readonly Hex[];
  readonly membershipDeadlines: readonly bigint[];
  readonly usesRootCapacity: boolean | null;
}

function windowAt(batch: Batch, now: bigint, stage: "schedule" | "execute") {
  const w = batch.window;
  if (stage === "execute") {
    if (now < w.notBefore || now > w.expiresAfter) throw Error("Execution outside inclusive action window");
  } else if (now + 365n * DAY >= 1n << 64n || w.notBefore < now + 3n * DAY
    || w.expiresAfter - w.notBefore < 7n * DAY || w.expiresAfter > now + 365n * DAY) {
    throw Error("Original class-2 scheduling window differs");
  }
}

async function publicationPointer(provider: Reader, d: ViewCompleteBindingDeployment, batch: Batch, tag: number) {
  const pointer = io.address(await read(provider, d.executor.address, "publishedCallData", [batch.publicationKey], tag), true);
  if (pointer !== ZERO_ADDRESS) io.equal(io.bytes(await provider.getCode(pointer, tag), io.MAX_CALL + 16384),
    `0x00${coder.encode(["bytes[]"], [batch.callDatas]).slice(2)}`, "Published original calldata carrier differs");
  return pointer;
}

function matchAction(action: governanceCodec.ScopedPolicyFinalityV2GovernanceAction, batch: Batch) {
  const target = batch.calls[0]!;
  const expected = {
    actionClass: 2n, target: target.target, value: 0n, selector: target.selector,
    callHash: batch.callsHash, scopeHash: batch.scopeHash, oldValueHash: batch.oldValueHash, newValueHash: batch.newValueHash,
    notBefore: batch.window.notBefore, expiresAfter: batch.window.expiresAfter, reasonHash: batch.window.reasonHash,
    reasonURI: batch.window.reasonURI, manifestHash: batch.window.manifestHash
  };
  for (const [key, value] of Object.entries(expected)) io.equal(action[key as keyof typeof action], value, `Scheduled action ${key} differs`);
}

async function memberships(provider: Reader, d: ViewCompleteBindingDeployment, targetScope: Hex, tag: number) {
  const caps = await rows(provider, d.executor.address, "terminalFreezeLiveActionCaps", [], tag);
  const cap = io.uint(caps[0]);
  if (!cap || cap > MAX_MEMBERSHIPS) throw Error("Client terminal membership bound exceeded");
  const page = await rows(provider, d.executor.address, "terminalFreezeActionPage", [targetScope, 0n, cap], tag);
  const ids = (page[0] as readonly Hex[]).map(h => io.hash(h));
  const deadlines = (page[1] as readonly bigint[]).map(n => io.uint(n, 64));
  if (ids.length !== deadlines.length || page[2] !== BigInt(ids.length) || ids.length > Number(cap)
    || new Set(ids).size !== ids.length) throw Error("Terminal membership page differs");
  return { ids, deadlines };
}

async function governance(
  provider: Reader, d: ViewCompleteBindingDeployment, prepared: Prepared, observed: io.Block
): Promise<ViewCompleteBindingGovernanceObservation> {
  const request = prepared.request;
  const batch = request.batch, tag = observed.blockNumber;
  await io.runtimes(provider, [d.executor, ...d.linkedDependencies], tag);
  const bootstrap = await rows(provider, d.executor.address, "systemManifestBootstrapState", [], tag);
  if (bootstrap[0] !== true) throw Error("Executor bootstrap not bound");
  const publication = await publicationPointer(provider, d, batch, tag);
  const action = governanceCodec.normalizeScopedPolicyFinalityV2GovernanceAction(
    await read<governanceCodec.ScopedPolicyFinalityV2GovernanceAction>(provider, d.executor.address, "governanceAction", [batch.actionId], tag)
  );
  if (request.kind === "publishGovernanceCallData") return {
    publication, action, catalog: null, root: null, governanceNonce: null, guardian: null,
    membershipIds: [], membershipDeadlines: [], usesRootCapacity: null
  };
  if (bootstrap[1] !== true) throw Error("Client requires ordinary sealed Executor");
  const rawCatalog = await rows(provider, d.executor.address, "governanceActionPolicyState", [], tag);
  const catalog = [io.hash(rawCatalog[0]), io.hash(rawCatalog[1]), io.uint(rawCatalog[2]), io.uint(rawCatalog[3], 64)] as const;
  if (!catalog[2] || catalog[2] > 1024n) throw Error("Original catalog bound exceeded");
  const rootState = await rows(provider, d.executor.address, "governanceRootState", [], tag);
  const root = io.codePin({ address: io.address(rootState[0]), codeHash: io.hash(rootState[1]) });
  if (!io.uint(rootState[2], 64)) throw Error("Governance root revision missing");
  await io.runtime(provider, root, tag);
  io.equal(await read(provider, d.executor.address, "owner", [], tag), root.address, "Governance root owner differs");
  await io.runtime(provider, d.roles, tag);
  io.equal(await read(provider, d.executor.address, "roleRegistry", [], tag), d.roles.address, "Executor roles differ");
  const guardian = await guardianObservation(provider, d, batch.transition.scopeHash, tag);
  const member = await memberships(provider, d, batch.transition.scopeHash, tag);
  let governanceNonce: bigint | null = null;
  let usesRootCapacity: boolean | null = null;
  if (request.kind === "scheduleGovernanceBatch") {
    if (action.status !== 0n || publication === ZERO_ADDRESS) throw Error("Schedule requires unused action and retained calldata");
    governanceNonce = io.uint(await read(provider, d.executor.address, "governanceNonce", [], tag));
    io.equal(governanceNonce, batch.nonce, "Governance nonce changed");
    usesRootCapacity = io.same(prepared.caller, root.address);
    if (!usesRootCapacity && await read(provider, d.executor.address, "isProposer", [prepared.caller], tag) !== true) {
      throw Error("Actual scheduling caller lacks proposer authority");
    }
    io.equal(await read(provider, d.executor.address, "minimumDelay", [2n], tag), 3n * DAY, "Original class delay differs");
    windowAt(batch, observed.timestamp, "schedule");
  } else {
    if (action.status !== 1n) throw Error("Action is not scheduled");
    matchAction(action, batch);
    windowAt(batch, observed.timestamp, "execute");
    io.equal(await read(provider, d.executor.address, "scheduledCallData", [batch.actionId], tag), batch.callDatas, "Scheduled exact calldata differs");
    io.equal(await read(provider, d.executor.address, "scheduledCallDataPointer", [batch.actionId], tag), publication, "Scheduled pointer differs");
    if (publication === ZERO_ADDRESS) throw Error("Scheduled carrier missing");
    io.equal(await read(provider, d.executor.address, "terminalFreezeGuardianConfigCommitment", [batch.actionId], tag),
      guardian.commitment, "Scheduled guardian configuration drifted");

  }
  // The catalog has no entry getter; original schedule/execute simulation authenticates its exact selected entry.
  const classifier = await rows(provider, d.executor.address, "freezeSelectorConfig", [d.provider.address, batch.calls[0]!.selector], tag);
  if (classifier[0] === true) io.equal(classifier[1], d.provider.codeHash, "Registered freeze selector runtime differs");
  return { publication, action, catalog, root, governanceNonce, guardian, membershipIds: member.ids,
    membershipDeadlines: member.deadlines, usesRootCapacity };
}


export interface ViewCompleteBindingWorkflowCapture {
  readonly deployment:ViewCompleteBindingDeployment;
  readonly prepared:ViewCompleteBindingPrepared;
  readonly observed:io.Block;
  readonly gasLimit:bigint;
  readonly preview:ViewCompleteBindingPreview;
  readonly governance:ViewCompleteBindingGovernanceObservation;
  readonly captureHash:Hex;
}
/** Every stage carries a fresh pending-source preview; source changes require a new reviewed batch. */
export async function captureViewCompleteBinding(p:Reader,input:ViewCompleteBindingDeployment,caller:Address,kind:ViewCompleteBindingStage,inputBatch:ViewCompleteBindingBatch,options:{readonly blockTag:number;readonly gasLimit:bigint}):Promise<ViewCompleteBindingWorkflowCapture> {
  const d=deployment(input),q=prepared(caller,kind,inputBatch),tag=io.number(options.blockTag),gasLimit=io.gas(options.gasLimit);
  io.equal(q.request.batch.coordinates,coords(d));io.equal(q.request.batch.executor,d.executor.address);
  const preview=await previewViewCompleteBinding(p,d,q.request.batch.candidate,{blockTag:tag,gasLimit});
  io.equal([preview.basic,preview.complete,preview.transition],[q.request.batch.basic,q.request.batch.complete,q.request.batch.transition],"Complete proposal changed; recapture");
  const state=await governance(p,d,q,preview.observed);
  await io.unchanged(p,preview.observed);
  const value={deployment:d,prepared:q,observed:preview.observed,gasLimit,preview,governance:state};
  return io.freeze({...value,captureHash:io.fingerprint(value)});
}
function snapshot(input:ViewCompleteBindingWorkflowCapture) {
  const v=copy(input),{captureHash,...rest}=v;
  io.keys(v,["deployment","prepared","observed","gasLimit","preview","governance","captureHash"]);
  io.equal(io.fingerprint(rest),io.hash(captureHash),"Capture fingerprint differs");
  deployment(v.deployment);checkedPreview(v.preview);io.gas(v.gasLimit);
  io.equal(prepared(v.prepared.caller,v.prepared.request.kind,v.prepared.request.batch),v.prepared);
  return io.freeze(v);
}
function comparable(v:unknown):unknown {
  if(Array.isArray(v)) return v.map(comparable);
  if(v&&typeof v==="object") return Object.fromEntries(Object.entries(v).filter(([key])=>!["observed","captureHash","snapshotHash"].includes(key)).map(([key,x])=>[key,comparable(x)]));
  return v;
}
async function authenticate(p:Reader,saved:ViewCompleteBindingWorkflowCapture) {
  await io.unchanged(p,saved.observed);
  const q=saved.prepared;
  const actual=await captureViewCompleteBinding(p,saved.deployment,q.caller,q.request.kind,q.request.batch,{blockTag:saved.observed.blockNumber,gasLimit:saved.gasLimit});
  io.equal(actual,saved,"Saved capture authentication differs");
}
export async function simulateViewCompleteBinding(p:Reader,input:ViewCompleteBindingWorkflowCapture,options:{readonly blockTag:number}) {
  const saved=snapshot(input),tag=io.number(options.blockTag);
  await authenticate(p,saved);
  const q=saved.prepared;
  const current=await captureViewCompleteBinding(p,saved.deployment,q.caller,q.request.kind,q.request.batch,{blockTag:tag,gasLimit:saved.gasLimit});
  io.equal(comparable(current),comparable(saved),"Reviewed context changed; recapture");
  const result=await io.rpc(p,q.call.to,executor(),q.request.kind,
    executor().decodeFunctionData(q.request.kind,q.call.data),tag,q.caller,saved.gasLimit);
  if(q.request.kind==="scheduleGovernanceBatch") io.equal(result[0],q.request.batch.actionId);
  if(q.request.kind==="publishGovernanceCallData") {
    const pointer=io.address(result[0]);
    if(current.governance.publication!==ZERO_ADDRESS) io.equal(pointer,current.governance.publication);
  }
  await io.unchanged(p,current.observed);
  return io.freeze({capture:current,result,originalCallSimulated:true as const,broadcast:false as const});
}
/** Local retained complete receipt, readable after source retirement. Pending/basic-only reverts. */
export async function inspectViewCompleteBindingHistory(p:Reader,input:ViewCompleteBindingHistoryDeployment,options:{readonly blockTag:number}) {
  const d=historyDeployment(input),tag=io.number(options.blockTag);
  const observed=await io.chain(p,d.chainId,tag);
  await io.runtimes(p,[d.provider,d.bindingWorker,...d.linkedDependencies],tag);
  const basic=binding.normalizeViewCompleteBindingBasicReceipt(await io.read<binding.ViewCompleteBindingBasicReceipt>(p,d.provider.address,observation(),"viewPreservationBindingReceipt",[],tag));
  const complete=binding.normalizeViewCompleteBindingReceipt(await io.read<binding.ViewCompleteBindingReceipt>(p,d.provider.address,iface(),"viewFinalitySourcesReceipt",[],tag));
  binding.authenticateViewCompleteBindingHistory(coords(d),basic,complete);
  if(complete.boundAt>observed.timestamp) throw Error("Retained binding timestamp is in future");
  await io.unchanged(p,observed);
  return io.freeze({deployment:d,observed,basic,complete,immutableReceiptAuthenticated:true as const,currentSourceAdmissionChecked:false as const});
}
/** Operative source identities only; no current publication/root, archive evidence or finality. */
export async function inspectViewCompleteBindingCurrent(p:Reader,input:ViewCompleteBindingDeployment,options:{readonly blockTag:number;readonly gasLimit:bigint}) {
  const d=deployment(input),tag=io.number(options.blockTag),gasLimit=io.gas(options.gasLimit);
  const history=await inspectViewCompleteBindingHistory(p,{chainId:d.chainId,provider:d.provider,bindingWorker:d.bindingWorker,linkedDependencies:d.linkedDependencies},{blockTag:tag});
  const candidate={configuration:history.basic.configuration,declaration:history.basic.declaration,selection:history.complete.selection};
  const dependencies=await sources(p,candidate,tag);
  const original=binding.normalizeViewCompleteBindingNativeConfiguration(await io.read<binding.ViewCompleteBindingNativeConfiguration>(p,d.provider.address,observation(),"nativeConfiguration",[],tag));
  const capability=binding.normalizeViewCompleteBindingCapability(await io.read<binding.ViewCompleteBindingCapability>(p,d.provider.address,observation(),"viewPreservationBindingCapability",[],tag));
  binding.validateViewCompleteBindingCapability(coords(d),original,capability);
  io.equal([capability.authority,capability.authorityCodeHash],[d.executor.address,d.executor.codeHash]);
  await io.runtimes(p,[d.executor,{address:original.targets[18]!,codeHash:original.codeHashes[18]!}],tag);
  const anchor=inventory.normalizeScopedPolicyInventoryV2Dependencies(await io.read<inventory.ScopedPolicyInventoryV2Dependencies>(p,original.targets[18]!,inventoryAbi,"dependencies",[],tag));
  const expected=binding.deriveViewCompleteBindingExpected(original,history.basic,candidate.selection,anchor);
  binding.validateViewCompleteBindingProducerDependencies(expected,candidate.selection,dependencies.reference,dependencies.inventory,dependencies.bundle);
  const actual=await io.read(p,d.provider.address,iface(),"viewFinalitySources",[],tag,undefined,gasLimit);
  io.equal(actual,history.complete.selection,"Operative complete selection differs");
  // Initial reference dependency hashes deliberately remain historical; current governed gas may grow.
  await io.unchanged(p,history.observed);
  return io.freeze({history,dependencies,selection:history.complete.selection,operativeSelectionAuthenticated:true as const,publicationCurrentnessChecked:false as const,finalityChecked:false as const});
}
async function localState(p:Reader,saved:ViewCompleteBindingWorkflowCapture,tag:number) {
  const d=saved.deployment,b=saved.prepared.request.batch;
  await io.runtimes(p,[d.provider,d.executor,d.bindingWorker,...d.linkedDependencies],tag);
  return {status:await io.read(p,d.provider.address,observation(),"viewPreservationBindingStatus",[],tag),
    basic:await io.read(p,d.provider.address,observation(),"viewPreservationBindingReceipt",[],tag),
    action:await read(p,d.executor.address,"governanceAction",[b.actionId],tag),
    publication:await read(p,d.executor.address,"publishedCallData",[b.publicationKey],tag)};
}
export async function observeViewCompleteBindingRefusal(p:Reader,input:ViewCompleteBindingWorkflowCapture,options:{readonly blockTag:number}) {
  const saved=snapshot(input),tag=io.number(options.blockTag);
  await authenticate(p,saved);
  const observed=await io.chain(p,saved.deployment.chainId,tag),before=await localState(p,saved,tag),q=saved.prepared;
  let outcome:"execution-reverted"|"rpc-failed"|"succeeded"="succeeded",error:unknown=null;
  try { await p.call({to:q.call.to,from:q.caller,data:q.call.data,value:0n,gasLimit:saved.gasLimit,blockTag:tag}); }
  catch(cause) {error=cause;outcome=typeof cause==="object"&&cause!==null&&"code" in cause&&cause.code==="CALL_EXCEPTION"?"execution-reverted":"rpc-failed";}
  const after=await localState(p,saved,tag);io.equal(after,before,"Pinned local observation changed");await io.unchanged(p,observed);
  return {observed,outcome,error,retainedStateUnchanged:true as const,nativeRollbackProven:false as const};
}
function eventCount(logs: readonly io.Log[], target: Address, iface: Interface, name: string, expected: number) {
  const values = io.events(logs, target, iface, name);
  if (values.length !== expected) throw Error(`Unexpected ${name} event count`);
  return values;
}

function membershipReceipt(
  logs: readonly io.Log[], d: ViewCompleteBindingDeployment, batch: Batch,
  before: ViewCompleteBindingGovernanceObservation, kind: "scheduleGovernanceBatch" | "executeGovernanceBatch",
  caller: Address, timestamp: bigint
) {
  const sequence = io.events(logs, d.executor.address, executor(), "TerminalFreezeActionMembershipUpdated");
  const ids = [...before.membershipIds], deadlines = [...before.membershipDeadlines];
  let cursor = 0;
  function removal(index: number, cause: bigint) {
    const row = sequence[cursor++];
    if (!row) throw Error("Missing terminal membership removal");
    const f = row.fields;
    io.equal([f.schemaVersion, f.scopeHash, f.actionId, f.present, f.mutationCause, f.vetoDeadline, f.rawIndex, f.remainingCount],
      [1n, batch.transition.scopeHash, ids[index], false, cause, deadlines[index], BigInt(index), BigInt(ids.length - 1)],
      "Terminal membership removal differs");
    io.address(f.proposer);
    if (f.actionId === batch.actionId) io.equal(f.proposer, before.action.proposer, "Pruned action proposer differs");
    ids[index] = ids[ids.length - 1]!;
    deadlines[index] = deadlines[deadlines.length - 1]!;
    ids.pop(); deadlines.pop();
  }
  if (kind === "scheduleGovernanceBatch") {
    let i = 0;
    while (i < ids.length) {
      if (timestamp >= deadlines[i]!) removal(i, 2n); else i++;
    }
    const row = sequence[cursor++];
    if (!row) throw Error("Missing terminal membership append");
    io.equal(row.fields, {
      schemaVersion: 1n, scopeHash: batch.transition.scopeHash, actionId: batch.actionId, proposer: caller,
      present: true, mutationCause: 1n, usesRootCapacity: before.usesRootCapacity,
      vetoDeadline: batch.window.notBefore, rawIndex: BigInt(ids.length), remainingCount: BigInt(ids.length + 1)
    }, "Terminal membership append differs");
    ids.push(batch.actionId); deadlines.push(batch.window.notBefore);
  } else {
    const index = ids.indexOf(batch.actionId);
    if (index >= 0) removal(index, 3n);
  }
  if (sequence.length !== cursor) throw Error("Extra terminal membership event");
  return { ids, deadlines, finalIndex: sequence.at(-1)?.index ?? -1 };
}


export async function reconcileViewCompleteBindingReceipt(p:ReceiptReader,input:ViewCompleteBindingWorkflowCapture,transactionHash:Hex,inputOptions:io.ReceiptOptions) {
  const saved=snapshot(input),options=copy(inputOptions),txHash=io.hash(transactionHash),d=saved.deployment,q=saved.prepared;
  const t=await io.transport(p,{chainId:d.chainId,caller:q.caller,call:q.call,observed:saved.observed},txHash,options);
  await authenticate(p,saved);
  const tag=t.observed.blockNumber;
  const prior=await captureViewCompleteBinding(p,d,q.caller,q.request.kind,q.request.batch,{blockTag:tag-1,gasLimit:saved.gasLimit});
  io.equal(comparable(prior),comparable(saved),"Preceding-block context changed; attribution refused");
  const g=prior.governance,b=q.request.batch,kind=q.request.kind,logs=t.logs;
  await io.runtimes(p,[...prior.preview.runtimePins,d.roles,...(g.guardian?.holders.flat()??[]),...(g.root?[g.root]:[])],tag);
  const pointer=await publicationPointer(p,d,b,tag);
  if(pointer===ZERO_ADDRESS) throw Error("Mined calldata publication missing");
  const published=eventCount(logs,d.executor.address,executor(),"GovernanceCallDataPublished",kind==="publishGovernanceCallData"&&g.publication===ZERO_ADDRESS?1:0);
  if(published.length) io.equal(published[0]!.fields,{schemaVersion:1n,callDataKey:b.publicationKey,pointer,publisher:q.caller});
  if(g.publication!==ZERO_ADDRESS) io.equal(pointer,g.publication);
  const action=governanceCodec.normalizeScopedPolicyFinalityV2GovernanceAction(await read<governanceCodec.ScopedPolicyFinalityV2GovernanceAction>(p,d.executor.address,"governanceAction",[b.actionId],tag));
  const schedule=kind==="scheduleGovernanceBatch",execute=kind==="executeGovernanceBatch";
  eventCount(logs,d.provider.address,gettersAbi,"ViewPreservationBound",0);
  eventCount(logs,d.provider.address,iface(),"ViewPreservationCompleteBound",execute?1:0);
  eventCount(logs,d.executor.address,executor(),"GovernanceActionScheduled",schedule?1:0);
  eventCount(logs,d.executor.address,executor(),"GovernanceActionExecuted",execute?1:0);
  eventCount(logs,d.executor.address,executor(),"GovernanceActionPolicyValidated",schedule||execute?1:0);
  let history:Awaited<ReturnType<typeof inspectViewCompleteBindingHistory>>|null=null;
  if(!schedule&&!execute) {
    io.equal(action,g.action,"Publication changed action");
    eventCount(logs,d.executor.address,executor(),"TerminalFreezeActionMembershipUpdated",0);
    eventCount(logs,d.executor.address,executor(),"TerminalFreezeGuardianConfigCommitted",0);
  } else {
    matchAction(action,b);
    io.equal(action.status,schedule?1n:2n);
    io.equal([action.proposer,action.executor,action.canceller,action.vetoer],[schedule?q.caller:g.action.proposer,execute?q.caller:ZERO_ADDRESS,ZERO_ADDRESS,ZERO_ADDRESS]);
    windowAt(b,t.observed.timestamp,schedule?"schedule":"execute");
    io.equal(await rows(p,d.executor.address,"governanceActionPolicyState",[],tag),g.catalog);
    io.equal(await read(p,d.executor.address,"scheduledCallData",[b.actionId],tag),b.callDatas);
    io.equal(await read(p,d.executor.address,"scheduledCallDataPointer",[b.actionId],tag),pointer);
    io.equal(await read(p,d.executor.address,"terminalFreezeGuardianConfigCommitment",[b.actionId],tag),g.guardian!.commitment);
    const members=membershipReceipt(logs,d,b,g,kind,q.caller,t.observed.timestamp);
    io.equal(await memberships(p,d,b.transition.scopeHash,tag),{ids:members.ids,deadlines:members.deadlines});
    const common=[1n,b.actionId,2n,b.calls[0]!.target,0n,b.calls[0]!.selector,b.callsHash,b.scopeHash,b.oldValueHash,b.newValueHash];
    const policy=io.one(logs,d.executor.address,executor(),"GovernanceActionPolicyValidated",[1n,b.actionId,schedule?1n:2n,g.catalog![0],g.catalog![1]]);
    if(schedule) {
      const appended=io.one(logs,d.executor.address,executor(),"GovernanceActionScheduled",[...common,b.window.notBefore,b.window.expiresAfter,b.nonce,q.caller,b.window.reasonHash,b.window.reasonURI,b.window.manifestHash]);
      const committed=io.one(logs,d.executor.address,executor(),"TerminalFreezeGuardianConfigCommitted",[1n,b.actionId,g.guardian!.commitment]);
      if(!(members.finalIndex<committed.index&&committed.index<appended.index&&appended.index<policy.index)) throw Error("Schedule event order differs");
      io.equal(await read(p,d.executor.address,"governanceNonce",[],tag),b.nonce+1n);
    } else {
      eventCount(logs,d.executor.address,executor(),"TerminalFreezeGuardianConfigCommitted",0);
      history=await inspectViewCompleteBindingHistory(p,{chainId:d.chainId,provider:d.provider,bindingWorker:d.bindingWorker,linkedDependencies:d.linkedDependencies},{blockTag:tag});
      const basic={...b.basic,actionId:b.actionId,boundAt:t.observed.timestamp};
      basic.recordHash=binding.viewCompleteBindingBasicReceiptHash(basic);
      const complete={...b.complete,basicBindingRecordHash:basic.recordHash,actionId:b.actionId,boundAt:t.observed.timestamp};
      complete.recordHash=binding.viewCompleteBindingReceiptHash(coords(d),complete);
      io.equal(history.basic,basic,"Mined basic receipt differs");io.equal(history.complete,complete,"Mined complete receipt differs");
      const bound=io.one(logs,d.provider.address,iface(),"ViewPreservationCompleteBound",[complete.recordHash,basic.recordHash,b.actionId,binding.viewCompleteBindingProposalHash(basic,complete)]);
      const executed=io.one(logs,d.executor.address,executor(),"GovernanceActionExecuted",[...common,q.caller,b.window.manifestHash]);
      if(!(members.finalIndex<bound.index&&bound.index<executed.index&&executed.index<policy.index)) throw Error("Binding execution event order differs");
    }
  }
  io.equal(await io.read(p,d.provider.address,observation(),"viewPreservationBindingStatus",[],tag),execute?1n:0n);
  if(!execute) {
    const before=await io.read(p,d.provider.address,observation(),"viewPreservationBindingReceipt",[],tag-1);
    io.equal(await io.read(p,d.provider.address,observation(),"viewPreservationBindingReceipt",[],tag),before,"Outer preparation changed binding");
  }
  io.finish(logs,[d.provider.address,d.executor.address],t.safeIndex);await io.unchanged(p,t.observed);
  return io.freeze({capture:saved,observed:t.observed,transactionHash:t.transactionHash,kind,history,action,exactCallAuthenticated:true as const,
    receiptAttribution:"unchanged-preceding-block-and-exact-end-block" as const,finalityChecked:false as const});
}
