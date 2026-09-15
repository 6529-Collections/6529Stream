import { AbiCoder, Interface, ZeroAddress, ZeroHash, concat, getAddress, id, isHexString, keccak256 } from "ethers";
import type { InterfaceAbi } from "ethers";

export const NATIVE_SALE_CREDIT_LEAF = "0x4713509255935af0a6981e3a2eb9948df2dc272218d10db479716667ca9c280b";
export const NATIVE_SALE_CREDIT_EXPORT_PROFILE = "STREAM_NATIVE_SALE_CREDIT_EXPORT_V1";
export const NATIVE_SALE_CREDIT_TREE_PROFILE = "ORDERED_KECCAK256_PROMOTE_ODD_V1";
// Original current-host registration types. Deprecated and incident-revoked records remain included.
export const NATIVE_SALE_CREDIT_MODULE_TYPES = Object.freeze(["NATIVE_PRIMARY_SALE_ADAPTER", "NATIVE_PREPARED_SALE_ADAPTER", "NATIVE_REFUND_WINDOW_SALE_ADAPTER", "PRIVATE_SALE_ADAPTER"].map(id));
const coder=AbiCoder.defaultAbiCoder();
const erc165=new Interface(["function supportsInterface(bytes4) view returns(bool)"]);
const interfaceId="0x"+(BigInt(id("nativeSaleCreditState()").slice(0,10)) ^ BigInt(id("nativeSaleCreditPage(uint256,uint256,uint256)").slice(0,10))).toString(16).padStart(8,"0");
export interface NativeSaleCreditLeaf { readonly adapter:string; readonly saleId:string; readonly account:string; readonly asset:string; readonly owed:bigint }
export interface NativeSaleCreditExportRequest {
  readonly chainId:bigint; readonly blockHash:string; readonly minimumDepth:bigint;
  readonly registry:string; readonly registryRuntimeHash:string;
  /** Explicit compiler-selected interfaces; the retained generated catalog is not changed. */
  readonly registryAbi:InterfaceAbi; readonly creditsAbi:InterfaceAbi;
  readonly pageLimit?:bigint; readonly maximumModules?:bigint; readonly maximumAccounts?:bigint; readonly maximumPages?:bigint;
}
export interface NativeSaleCreditRPC { send(method:string,params:readonly unknown[]):Promise<unknown> }
export interface NativeSaleCreditObservation { readonly method:string; readonly params:readonly unknown[]; readonly result:unknown }
function uint(n:bigint):bigint { if(typeof n!=="bigint" || n<0n || n>=1n<<256n) throw Error("Expected uint256 bigint"); return n; }
function hash(s:string):string { if(!isHexString(s,32)) throw Error("Expected bytes32");return s.toLowerCase(); }
function address(s:string):string { const a=getAddress(s);if(a===ZeroAddress)throw Error("Zero source/account");return a; }
function quantity(v:unknown):bigint { if(typeof v!=="string" || !/^0x(?:0|[1-9a-f][0-9a-f]*)$/i.test(v))throw Error("Invalid RPC quantity");return uint(BigInt(v)); }
function object(v:unknown):Record<string,unknown> { if(!v || typeof v!=="object" || Array.isArray(v))throw Error("Expected RPC object");return v as Record<string,unknown>; }
/** Deterministic JSON for the reconstruction artifact; all protocol integers become decimal strings. */
export function nativeSaleCreditJSON(value:unknown):string {
  if(typeof value==="bigint")return JSON.stringify(value.toString());
  if(value===null || typeof value==="string" || typeof value==="boolean")return JSON.stringify(value);
  if(typeof value==="number" && Number.isSafeInteger(value))return JSON.stringify(value);
  if(Array.isArray(value))return "["+value.map(nativeSaleCreditJSON).join(",")+"]";
  if(value && typeof value==="object")return "{"+Object.keys(value).sort().map(k=>JSON.stringify(k)+":"+nativeSaleCreditJSON((value as Record<string,unknown>)[k])).join(",")+"}";
  throw Error("Noncanonical export JSON value");
}
export function nativeSaleCreditLeaf(row:NativeSaleCreditLeaf):string {
  if(getAddress(row.asset)!==ZeroAddress)throw Error("Native export asset must be zero");
  return keccak256(coder.encode(["bytes32","address","bytes32","address","address","uint256"],[NATIVE_SALE_CREDIT_LEAF,address(row.adapter),hash(row.saleId),address(row.account),ZeroAddress,uint(row.owed)]));
}
export function nativeSaleCreditTree(rows:readonly NativeSaleCreditLeaf[]) {
  const sorted=rows.map(r=>({...r,adapter:address(r.adapter),saleId:hash(r.saleId),account:address(r.account),asset:ZeroAddress,leaf:nativeSaleCreditLeaf(r)}));
  const key=(r:NativeSaleCreditLeaf)=>r.adapter.toLowerCase()+r.saleId.slice(2)+r.account.toLowerCase().slice(2)+r.asset.slice(2);
  sorted.sort((a,b)=>key(a)<key(b)?-1:key(a)>key(b)?1:0);
  for(let i=1;i<sorted.length;i++)if(key(sorted[i-1]!)===key(sorted[i]!))throw Error("Duplicate sale-credit key");
  let level=sorted.map(r=>r.leaf);
  while(level.length>1){const next:string[]=[];for(let i=0;i<level.length;i+=2)next.push(i+1===level.length?level[i]!:keccak256(concat([level[i]!,level[i+1]!])));level=next;}
  return {treeProfile:NATIVE_SALE_CREDIT_TREE_PROFILE,root:level[0]??ZeroHash,leaves:sorted};
}
function requireABI(abi:InterfaceAbi,expected:Record<string,string[]>):Interface {
  const i=new Interface(abi);
  for(const [name,outputs] of Object.entries(expected)){
    const f=i.getFunction(name);if(!f || !f.constant || f.outputs.map(o=>o.format("sighash")).join(";")!==outputs.join(";"))throw Error("Compiler ABI differs: "+name);
  }
  return i;
}
/** Read-only. Enumerates the entire pinned registry, then each retained native host's complete key index.
 * It never filters by ACTIVE status, accepts caller account lists, spends funds, or publishes a root.
 */
export async function exportNativeSaleCredits(provider:NativeSaleCreditRPC,input:NativeSaleCreditExportRequest) {
  const request={registryAbi:input.registryAbi,creditsAbi:input.creditsAbi,chainId:uint(input.chainId),blockHash:hash(input.blockHash),minimumDepth:uint(input.minimumDepth),registry:address(input.registry),registryRuntimeHash:hash(input.registryRuntimeHash),pageLimit:input.pageLimit??64n,maximumModules:input.maximumModules??100000n,maximumAccounts:input.maximumAccounts??1000000n,maximumPages:input.maximumPages??1000000n};
  for(const n of [request.pageLimit,request.maximumModules,request.maximumAccounts,request.maximumPages])uint(n);
  if(request.pageLimit<1n || request.pageLimit>64n)throw Error("Page limit outside 1..64");
  const credits=requireABI(request.creditsAbi,{"nativeSaleCreditState()":["(uint256,uint256,uint256)"],"nativeSaleCreditPage(uint256,uint256,uint256)":["(bytes32,address,uint256,uint256,uint256)"]});
  const registry=requireABI(request.registryAbi,{"moduleCount()":["uint256"],"moduleAt(uint256)":["address"],"moduleRecord(address)":["(uint8,bytes32,bytes32,bytes4,uint32,bytes32,bytes32,bytes32,string,uint64,uint64,uint64)"]});
  const savedRequest=JSON.parse(nativeSaleCreditJSON(request));
  const transcript:NativeSaleCreditObservation[]=[];
  const rpc=async(method:string,params:readonly unknown[])=>{const result=await provider.send(method,params);transcript.push(JSON.parse(nativeSaleCreditJSON({method,params,result})) as NativeSaleCreditObservation);return result;};
  const at={blockHash:request.blockHash,requireCanonical:true};
  const read=async(target:string,abi:Interface,fn:string,args:readonly unknown[]=[])=>{
    const result=await rpc("eth_call",[{to:target,data:abi.encodeFunctionData(fn,args)},at]);
    if(typeof result!=="string" || !isHexString(result))throw Error("Invalid call bytes");
    const decoded=abi.decodeFunctionResult(fn,result);
    if(abi.encodeFunctionResult(fn,decoded).toLowerCase()!==result.toLowerCase())throw Error("Noncanonical or oversized call output");
    return decoded;
  };
  if(quantity(await rpc("eth_chainId",[]))!==request.chainId)throw Error("Chain differs");
  const block=object(await rpc("eth_getBlockByHash",[request.blockHash,false]));
  if(hash(String(block.hash))!==request.blockHash)throw Error("Block differs");
  const number=quantity(block.number),head=quantity(await rpc("eth_blockNumber",[]));
  if(head<number || head-number<request.minimumDepth)throw Error("Insufficient confirmed depth");
  const codeHash=async(target:string)=>{const code=await rpc("eth_getCode",[target,at]);if(typeof code!=="string" || !isHexString(code) || code==="0x")throw Error("Source has no code");return keccak256(code);};
  if(await codeHash(request.registry)!==request.registryRuntimeHash)throw Error("Registry runtime differs");
  const moduleCount=uint((await read(request.registry,registry,"moduleCount"))[0] as bigint);
  if(moduleCount>request.maximumModules)throw Error("Module budget exceeded; no complete export");
  const modules:unknown[]=[],hosts:unknown[]=[],rows:NativeSaleCreditLeaf[]=[],accounts=new Set<string>(),addresses=new Set<string>();let pages=0n,totalAccounts=0n;
  for(let n=0n;n<moduleCount;n++){
    const target=address((await read(request.registry,registry,"moduleAt",[n]))[0] as string);
    if(addresses.has(target))throw Error("Duplicate registry module");addresses.add(target);
    const raw=(await read(request.registry,registry,"moduleRecord",[target]))[0];
    const status=uint(raw[0] as bigint),type=hash(raw[1] as string),runtimeHash=hash(raw[5] as string);
    if(status<1n || status>3n || runtimeHash===ZeroHash)throw Error("Invalid retained module record");
    modules.push({index:n,address:target,record:Array.from(raw)});
    if(!NATIVE_SALE_CREDIT_MODULE_TYPES.includes(type))continue;
    if(await codeHash(target)!==runtimeHash)throw Error("Adapter runtime differs");
    if((await read(target,erc165,"supportsInterface",[interfaceId]))[0]!==true)throw Error("Retained native adapter lacks complete credit index; export incomplete");
    const state=(await read(target,credits,"nativeSaleCreditState"))[0];
    const count=uint(state[0] as bigint),liability=uint(state[1] as bigint),balance=uint(state[2] as bigint);
    totalAccounts+=count;if(totalAccounts>request.maximumAccounts)throw Error("Account budget exceeded; no complete export");
    let owedTotal=0n,claimableTotal=0n;const keys:unknown[]=[];
    for(let index=0n;index<count;index++){
      let cursor=0n,owed=0n,claimable=0n,saleId="",account="";
      do{
        if(++pages>request.maximumPages)throw Error("Page budget exceeded; no complete export");
        const p=(await read(target,credits,"nativeSaleCreditPage",[index,cursor,request.pageLimit]))[0];
        const s=hash(p[0] as string),a=address(p[1] as string),next=uint(p[4] as bigint),partial=uint(p[2] as bigint),available=uint(p[3] as bigint);
        if(s===ZeroHash || (cursor!==0n && (s!==saleId || a!==account)) || available>partial || (cursor!==0n && available!==0n) || (next!==0n && (next<=cursor || next-cursor>request.pageLimit)))throw Error("Invalid credit page");
        saleId=s;account=a;owed=uint(owed+partial);claimable=uint(claimable+available);cursor=next;
      }while(cursor!==0n);
      const key=target+saleId+account;if(accounts.has(key))throw Error("Duplicate producer credit key");accounts.add(key);
      rows.push({adapter:target,saleId,account,asset:ZeroAddress,owed});keys.push({index,saleId,account,owed,claimable});owedTotal+=owed;claimableTotal+=claimable;
    }
    if(owedTotal!==liability || balance<liability)throw Error("Original liabilities do not reconcile");
    hosts.push({adapter:target,status,moduleType:type,runtimeHash,accountCount:count,totalLiabilities:liability,claimableTotal,balance,surplus:balance-liability,keys});
  }
  // All state calls used EIP-1898 requireCanonical. Recheck the block is still canonical at completion.
  const finalBlock=object(await rpc("eth_getBlockByNumber",["0x"+number.toString(16),false]));
  if(hash(String(finalBlock.hash))!==request.blockHash)throw Error("Export block reorged");
  const result={profile:NATIVE_SALE_CREDIT_EXPORT_PROFILE,leafSchema:"STREAM_EXPORT_SALE_CREDIT_LEAF_V1",leafDomain:NATIVE_SALE_CREDIT_LEAF,ordering:["adapter","saleId","account","asset"],qualification:"Complete for retained native module types in this pinned registry and block; RPC authenticity and canonical StateExport publication require independent verification.",chainId:request.chainId,blockHash:request.blockHash,blockNumber:number,observedHead:head,minimumDepth:request.minimumDepth,registry:request.registry,registryRuntimeHash:request.registryRuntimeHash,moduleCount,modules,hosts,...nativeSaleCreditTree(rows)};
  return {request:savedRequest,result:JSON.parse(nativeSaleCreditJSON(result)),transcript,transcriptHash:keccak256(new TextEncoder().encode(nativeSaleCreditJSON(transcript)))};
}
/** Reconstruct every read, key/page, reconciliation and root from saved RPC bytes. This proves self-consistency, not chain authenticity. */
export async function replayNativeSaleCreditExport(artifact:Awaited<ReturnType<typeof exportNativeSaleCredits>>) {
  let n=0;const provider:NativeSaleCreditRPC={async send(method,params){const row=artifact.transcript[n++];if(!row || row.method!==method || nativeSaleCreditJSON(row.params)!==nativeSaleCreditJSON(params))throw Error("Transcript call differs");return row.result;}};
  const r=artifact.request as Record<string,unknown>;
  const request={...r,chainId:BigInt(String(r.chainId)),minimumDepth:BigInt(String(r.minimumDepth)),pageLimit:BigInt(String(r.pageLimit)),maximumModules:BigInt(String(r.maximumModules)),maximumAccounts:BigInt(String(r.maximumAccounts)),maximumPages:BigInt(String(r.maximumPages))} as unknown as NativeSaleCreditExportRequest;
  const rebuilt=await exportNativeSaleCredits(provider,request);
  if(n!==artifact.transcript.length || rebuilt.transcriptHash!==artifact.transcriptHash || nativeSaleCreditJSON(rebuilt.result)!==nativeSaleCreditJSON(artifact.result))throw Error("Export differs from original observations");
  return rebuilt.result;
}
