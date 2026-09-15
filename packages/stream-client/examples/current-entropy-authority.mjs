// Read-only RPC recipe. No wallet, signing key, sendTransaction or broadcast is created.
import { readFileSync } from "node:fs";
import { pathToFileURL } from "node:url";
import { Interface, JsonRpcProvider, isHexString, keccak256, toUtf8Bytes } from "ethers";
import { CurrentEntropyAuthorityClient } from "../dist/index.js";
function decimal(v){if(typeof v!=="string"||!/^(0|[1-9][0-9]*)$/.test(v))throw Error("Expected canonical decimal string");return BigInt(v);}
const safeABI=new Interface(["function nonce() view returns(uint256)"]);
const canonical=v=>Array.isArray(v)?`[${v.map(canonical).join(",")}]`:v!==null&&typeof v==="object"?`{${Object.keys(v).sort().map(k=>`${JSON.stringify(k)}:${canonical(v[k])}`).join(",")}}`:JSON.stringify(v);
const print=v=>JSON.stringify(v,(_,x)=>typeof x==="bigint"?{$bigint:x.toString()}:x,2);
export function readAuthorityJSON(path){return JSON.parse(readFileSync(path,"utf8"),(_,v)=>{
 if(v&&typeof v==="object"&&Object.keys(v).length===1&&Object.hasOwn(v,"$bigint")){
  if(typeof v.$bigint!=="string"||!/^(0|[1-9][0-9]*)$/.test(v.$bigint))throw Error("Invalid tagged bigint");return BigInt(v.$bigint);
 }return v;
});}
async function nonce(provider,safe){const raw=await provider.call({to:safe,data:safeABI.encodeFunctionData("nonce"),blockTag:"pending"});if(!isHexString(raw,32))throw Error("Exact Safe nonce response required");return safeABI.decodeFunctionResult("nonce",raw)[0];}
export async function prepareAuthorityRecipe(provider,config,bindings){
 const client=new CurrentEntropyAuthorityClient(decimal(config.chainId),config.deployment,bindings);
 if(config.operation==="finding-context")return {qualification:"Context/calldata only. Admit and execute the original class-2 Arbiter governance action using this full target; a direct Safe call is not authorized by this quote.",finding:await client.quoteFinding(provider,config.input)};
 const caller=config.caller,before=await nonce(provider,caller),safeCode=await provider.getCode(caller,"latest");
 if(safeCode==="0x")throw Error("Safe runtime unavailable");
 const plan=config.operation==="recovery"?await client.quoteRecovery(provider,caller,config.recovery,config.finding,decimal(config.nativeAllowance)):
  config.operation==="hydration"?await client.quoteHydration(provider,caller,config.request):null;
 if(!plan)throw Error("Choose finding-context, recovery or hydration");
 const status=await client.resume(provider,plan);
 if(await nonce(provider,caller)!==before)throw Error("Safe nonce changed during preparation");
 const safe=client.safeCall(plan);
 const execution={schema:"6529STREAM_ENTROPY_AUTHORITY_SAFE_RECIPE_V1",chainId:client.chainId.toString(),deployment:client.deployment,
  safe:safe.safe,safeCodeHash:keccak256(safeCode),safeNonce:before.toString(),call:safe.call,
  observedCommitment:plan.kind==="finding-recovery"?plan.stateHash:plan.commitment};
 return {qualification:"Unsigned single Safe CALL only. Simulated as the Safe address; owner signatures, Safe gas/refund fields and the complete signed execTransaction still require independent verification and pending simulation.",
  status,execution,executionHash:keccak256(toUtf8Bytes(canonical(execution))),observation:plan.observation,
  retry:"Keep this original hash separately. Retry the identical signed transaction only if the Safe nonce, complete signed fields and current checks remain unchanged. ExecutionFailure may consume a Safe nonce; an outer success is not target success."};
}
export function requireSameAuthorityRecipe(current,original,externallySavedHash){
 if(!isHexString(externallySavedHash,32)||!original.execution||keccak256(toUtf8Bytes(canonical(original.execution)))!==externallySavedHash.toLowerCase()
  ||original.executionHash!==externallySavedHash.toLowerCase()||current.executionHash!==externallySavedHash.toLowerCase())throw Error("Original Safe recipe differs; do not rewrite or reuse its signatures");
 return current;
}
if(process.argv[1]&&import.meta.url===pathToFileURL(process.argv[1]).href){
 const [, , path, retryPath, originalHash]=process.argv;
 if(!path){console.log("Usage: node examples/current-entropy-authority.mjs CONFIG.json [ORIGINAL_RECIPE.json EXTERNALLY_SAVED_HASH]\nExplicit compilerFixture selects the ABI; config supplies RPC/deployment pins and exact request. This command performs reads/simulations only.");}
 else{
  const config=readAuthorityJSON(path),fixture=readAuthorityJSON(config.compilerFixture);
  const provider=new JsonRpcProvider(config.rpcURL,undefined,{cacheTimeout:-1});
  try{const result=await prepareAuthorityRecipe(provider,config,fixture.abis);if(retryPath){if(!originalHash)throw Error("Original hash required separately");requireSameAuthorityRecipe(result,readAuthorityJSON(retryPath),originalHash);}console.log(print(result));}
  finally{provider.destroy();}
 }
}
