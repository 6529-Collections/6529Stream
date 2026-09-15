import {readFile,writeFile} from "node:fs/promises";
import {JsonRpcProvider} from "ethers";
import {exportNativeSaleCredits,replayNativeSaleCreditExport,nativeSaleCreditJSON} from "../dist/index.js";
const [mode,inputPath,compilerPath,outputPath]=process.argv.slice(2);
if(mode==="replay"){
 const artifact=JSON.parse(await readFile(inputPath,"utf8"));await replayNativeSaleCreditExport(artifact);
 console.log("Original observations reconstruct the complete selected-registry credit export; chain authenticity is not established by replay.");
}else if(mode==="export" && inputPath && compilerPath && outputPath){
 const input=JSON.parse(await readFile(inputPath,"utf8")),compiled=JSON.parse(await readFile(compilerPath,"utf8"));
 const registryAbi=compiled.contracts["smart-contracts/interfaces/stream/modules/IStreamModuleRegistry.sol"].IStreamModuleRegistry.abi;
 const creditsAbi=compiled.contracts["smart-contracts/interfaces/stream/mint/IStreamNativeSaleCredits.sol"].IStreamNativeSaleCredits.abi;
 if(!process.env.STREAM_READ_RPC_URL)throw Error("Set STREAM_READ_RPC_URL for the read-only capture");
 for(const key of ["chainId","minimumDepth","pageLimit","maximumModules","maximumAccounts","maximumPages"]){if(input[key]!==undefined){if(typeof input[key]!=="string" || !/^(0|[1-9][0-9]*)$/.test(input[key]))throw Error("Request integers must be canonical decimal strings");input[key]=BigInt(input[key]);}}
 const provider=new JsonRpcProvider(process.env.STREAM_READ_RPC_URL);
 try{const artifact=await exportNativeSaleCredits(provider,{...input,chainId:BigInt(input.chainId),minimumDepth:BigInt(input.minimumDepth),registryAbi,creditsAbi});await writeFile(outputPath,nativeSaleCreditJSON(artifact)+"\n");}
 finally{provider.destroy();}
}else throw Error("Usage: replay <artifact.json>, or export <request.json> <compiler-output.json> <artifact.json>");
