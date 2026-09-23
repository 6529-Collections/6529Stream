import { readFileSync, writeFileSync } from "node:fs";
import { createHash } from "node:crypto";
export function nativeCreditFixture(input, output) {
 if(output.errors?.some(e=>e.severity==="error"))throw Error("Compiler errors remain");
 const selected = { credits: ["smart-contracts/interfaces/stream/mint/IStreamNativeSaleCredits.sol", "IStreamNativeSaleCredits"], registry: ["smart-contracts/interfaces/stream/modules/IStreamModuleRegistry.sol", "IStreamModuleRegistry"] };
 const abis={}, sources={};
 for(const [key,[path,name]] of Object.entries(selected)){const text=input.sources[path]?.content, abi=output.contracts[path]?.[name]?.abi;if(typeof text!=="string" || !text || !Array.isArray(abi))throw Error("Missing compiler-selected source/ABI: "+path);abis[key]=abi;sources[path]=createHash("sha256").update(text).digest("hex");}
 return {qualification:"Compiler-selected ABI fixture only; no deployed or runtime acceptance.",sources,abis};
}
if(process.argv[1]?.endsWith("generate-current-native-sale-credits-fixture.mjs")){const [,,input,output,target]=process.argv;if(!input || !output || !target)throw Error("Pass explicit standard JSON input/output and fixture path");writeFileSync(target,JSON.stringify(nativeCreditFixture(JSON.parse(readFileSync(input,"utf8")),JSON.parse(readFileSync(output,"utf8"))),null,2)+"\n");}
