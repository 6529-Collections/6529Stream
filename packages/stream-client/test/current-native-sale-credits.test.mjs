import test from "node:test";
import assert from "node:assert/strict";
import {readFile} from "node:fs/promises";
import {AbiCoder,Interface,ZeroAddress,ZeroHash,concat,id,keccak256} from "ethers";
import {exportNativeSaleCredits,replayNativeSaleCreditExport,nativeSaleCreditTree,nativeSaleCreditLeaf,nativeSaleCreditJSON,NATIVE_SALE_CREDIT_LEAF} from "../dist/index.js";
const f=JSON.parse(await readFile(new URL("./fixtures/current-native-sale-credits-abi.json",import.meta.url),"utf8"));
const cr=new Interface(f.abis.credits),reg=new Interface(f.abis.registry),erc=new Interface(["function supportsInterface(bytes4) view returns(bool)"]);
const registry="0x0000000000000000000000000000000000000001",adapter="0x0000000000000000000000000000000000000002",other="0x0000000000000000000000000000000000000003",account="0x0000000000000000000000000000000000000004";
const blockHash=id("complete recorded block"),sale=id("original sale"),oldSale=id("claimed sale"),runtime=keccak256("0x6001"),coder=AbiCoder.defaultAbiCoder();
function fixture(options={}){
 const calls=[];
 const req={chainId:31337n,blockHash,minimumDepth:6n,registry,registryRuntimeHash:keccak256("0x6000"),registryAbi:f.abis.registry,creditsAbi:f.abis.credits,pageLimit:1n};
 const r={async send(method,params){calls.push({method,params});let out;
  if(method==="eth_chainId")return options.chain??"0x7a69";
  if(method==="eth_blockNumber")return options.head??"0x70";
  if(method==="eth_getBlockByHash")return {hash:blockHash,number:"0x64"};
  if(method==="eth_getBlockByNumber")return {hash:options.reorg?id("reorg"):blockHash,number:"0x64"};
  assert.deepEqual(params.at(-1),{blockHash,requireCanonical:true});
  if(method==="eth_getCode")return params[0]===registry?"0x6000":options.code??"0x6001";
  assert.equal(method,"eth_call");const {to,data}=params[0];
  if(to===registry){const tx=reg.parseTransaction({data});
   if(tx.name==="moduleCount")out=reg.encodeFunctionResult(tx.name,[2]);
   else if(tx.name==="moduleAt")out=reg.encodeFunctionResult(tx.name,[tx.args[0]===0n?other:adapter]);
   else out=reg.encodeFunctionResult(tx.name,[[tx.args[0]===adapter?(options.status??3n):1n,tx.args[0]===adapter?id("NATIVE_REFUND_WINDOW_SALE_ADAPTER"):id("UNRELATED_MODULE"),id("version"),"0x12345678",50000,runtime,id("deployment"),id("manifest"),"urn:fixture",1,2,2]]);
  }else if(data.startsWith(erc.getFunction("supportsInterface").selector))out=erc.encodeFunctionResult("supportsInterface",[options.capable??true]);
  else {const tx=cr.parseTransaction({data});
   if(tx.name==="nativeSaleCreditState")out=cr.encodeFunctionResult(tx.name,[[options.count??2n,options.total??8n,options.balance??15n]]);
   else {const [index,cursor]=tx.args;const old=index===1n;
    const p=old?[options.duplicate?sale:oldSale,account,0n,0n,0n]:cursor===0n?[sale,account,options.first??3n,2n,options.next??1n]:[options.drift?id("wrong sale"):sale,account,5n,options.extraClaim??0n,options.stall?1n:0n];
    out=cr.encodeFunctionResult(tx.name,[p]);
   }
  }
  return options.tail?out+"00":out;
 }};return {r,req,calls};
}
test("complete retained registry export includes retired original deposits and zeroed historical key",async()=>{const {r,req,calls}=fixture();const a=await exportNativeSaleCredits(r,req);
 assert.equal(a.result.moduleCount,"2");assert.equal(a.result.hosts.length,1);const h=a.result.hosts[0];assert.equal(h.status,"3");assert.equal(h.accountCount,"2");assert.equal(h.totalLiabilities,"8");assert.equal(h.claimableTotal,"2");assert.equal(h.surplus,"7");assert.equal(a.result.leaves.length,2);assert.ok(a.result.leaves.some(x=>x.owed==="0"));assert.deepEqual(await replayNativeSaleCreditExport(a),a.result);assert.ok(calls.filter(x=>x.method==="eth_call").every(x=>x.params[1].requireCanonical));});
test("exact canonical leaf uses six ABI words including only original domain and five coordinates",()=>{const row={adapter,saleId:sale,account,asset:ZeroAddress,owed:(1n<<240n)+13n};assert.equal(nativeSaleCreditLeaf(row),keccak256(coder.encode(["bytes32","address","bytes32","address","address","uint256"],[NATIVE_SALE_CREDIT_LEAF,adapter,sale,account,ZeroAddress,row.owed])));assert.throws(()=>nativeSaleCreditLeaf({...row,asset:other}));assert.throws(()=>nativeSaleCreditLeaf({...row,owed:13}));});
test("sorted ordered tree has explicit odd promotion and empty root",()=>{const rows=[3,1,2].map(n=>({adapter,saleId:"0x"+n.toString(16).padStart(64,"0"),account,asset:ZeroAddress,owed:BigInt(n)}));const t=nativeSaleCreditTree(rows);assert.equal(t.root,keccak256(concat([keccak256(concat([t.leaves[0].leaf,t.leaves[1].leaf])),t.leaves[2].leaf])));assert.equal(nativeSaleCreditTree([]).root,ZeroHash);assert.throws(()=>nativeSaleCreditTree([rows[0],rows[0]]),/Duplicate/);});
for(const [label,options,reason] of [
 ["omitted producer key",{count:1n,total:9n},/reconcile/],["duplicate historical key",{duplicate:true},/Duplicate/],["page identity drift",{drift:true},/page/],["page cursor stalls",{stall:true},/page/],["repeated claim credit",{extraClaim:1n},/page/],["insolvent original ledger",{balance:7n},/reconcile/],["wrong runtime",{code:"0x6002"},/runtime/],["wrong chain",{chain:"0x1"},/Chain/],["unconfirmed block",{head:"0x65"},/depth/],["reorg at end",{reorg:true},/reorged/],["legacy host without complete index",{capable:false},/incomplete/],["noncanonical call returndata",{tail:true},/canonical|decode|data|length/]
])test(label+" fails without publishing partial export",async()=>{const {r,req}=fixture(options);await assert.rejects(exportNativeSaleCredits(r,req),reason);});
test("full uint256 owed survives export and JSON without Number conversion",async()=>{const huge=1n<<200n;const {r,req}=fixture({first:huge,total:huge+5n,balance:huge+12n});const a=await exportNativeSaleCredits(r,req);assert.equal(a.result.hosts[0].totalLiabilities,(huge+5n).toString());assert.deepEqual(await replayNativeSaleCreditExport(a),a.result);});
test("bounded budgets refuse an incomplete result",async()=>{for(const budget of [{maximumModules:1n},{maximumAccounts:1n},{maximumPages:1n}]){const {r,req}=fixture();await assert.rejects(exportNativeSaleCredits(r,{...req,...budget}),/budget/);} });
test("replay rejects altered amounts, roots, observations and unconsumed RPC bytes",async()=>{const {r,req}=fixture();const a=await exportNativeSaleCredits(r,req);for(const change of [b=>b.result.hosts[0].totalLiabilities="9",b=>b.result.root=ZeroHash,b=>b.transcript.push(b.transcript[0]),b=>b.transcript[0].result="0x1"]){const b=structuredClone(a);change(b);await assert.rejects(replayNativeSaleCreditExport(b));}});
test("zero liabilities retain every original account after claims and exclude forced surplus",async()=>{const {r,req}=fixture({first:0n,total:0n,balance:99n});const original=r.send;r.send=async(method,params)=>{const out=await original(method,params);if(method==="eth_call" && params[0].to===adapter && params[0].data.startsWith(cr.getFunction("nativeSaleCreditPage").selector)){const p=cr.decodeFunctionResult("nativeSaleCreditPage",out)[0];return cr.encodeFunctionResult("nativeSaleCreditPage",[[p[0],p[1],0n,0n,p[4]]]);}return out;};const a=await exportNativeSaleCredits(r,req);assert.equal(a.result.hosts[0].surplus,"99");assert.equal(a.result.leaves.length,2);assert.ok(a.result.leaves.every(x=>x.owed==="0"));});
test("caller must supply the selected compiler interface",async()=>{const {r,req}=fixture();await assert.rejects(exportNativeSaleCredits(r,{...req,creditsAbi:["function nativeSaleCreditState() view returns(uint256)"]}),/ABI/);});
test("artifact canonical JSON never silently loses integer width or unsupported values",()=>{assert.equal(nativeSaleCreditJSON({z:1n,a:2n}),'{"a":"2","z":"1"}');assert.throws(()=>nativeSaleCreditJSON({bad:undefined}));assert.throws(()=>nativeSaleCreditJSON(Number.MAX_SAFE_INTEGER+1));});

test("explicit generator preserves original registry plus final current credit source hashes",async()=>{
 const {createHash}=await import("node:crypto");const {nativeCreditFixture}=await import("../scripts/generate-current-native-sale-credits-fixture.mjs");
 for(const [path,expected] of Object.entries(f.sources)){const bytes=await readFile(new URL("../../../"+path,import.meta.url));assert.equal(createHash("sha256").update(bytes).digest("hex"),expected);}
 assert.throws(()=>nativeCreditFixture({}, {errors:[{severity:"error"}]}),/Compiler/);
});
test("read-only example replays actual saved test observations without fetching",async()=>{
 const {mkdtemp,writeFile,rm}=await import("node:fs/promises"),{tmpdir}=await import("node:os"),{join,resolve,dirname,basename}=await import("node:path"),{fileURLToPath}=await import("node:url"),{execFileSync}=await import("node:child_process");
 const {r,req}=fixture();const artifact=await exportNativeSaleCredits(r,req),dir=await mkdtemp(join(tmpdir(),"native-credit-export-"));
 try{const path=join(dir,"export.json");await writeFile(path,nativeSaleCreditJSON(artifact));const output=execFileSync(process.execPath,[fileURLToPath(new URL("../examples/export-native-sale-credits.mjs",import.meta.url)),"replay",path],{encoding:"utf8"});assert.match(output,/chain authenticity is not established/);}finally{const target=resolve(dir);assert.equal(dirname(target),resolve(tmpdir()));assert.match(basename(target),/^native-credit-export-/);await rm(target,{recursive:true,force:true});}
});

test("capture records only declared request coordinates",async()=>{const {r,req}=fixture();const a=await exportNativeSaleCredits(r,{...req,unrelatedLocalSetting:"not an export coordinate"});assert.equal(Object.hasOwn(a.request,"unrelatedLocalSetting"),false);assert.deepEqual(await replayNativeSaleCreditExport(a),a.result);});
