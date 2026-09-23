import test from "node:test";
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { AbiCoder, Interface, ZeroAddress, ZeroHash, getAddress, id, keccak256, toBeHex } from "ethers";
import * as pure from "../dist/current-artist-personhood.js";
import { inspectArtistPersonhood } from "../dist/current-artist-personhood-workflow.js";
const f=JSON.parse(readFileSync(new URL("./fixtures/current-artist-personhood-abi.json",import.meta.url),"utf8"));
const actual=new Interface(f.abis.attribution), reads=new Interface(f.abis.personhood), coder=AbiCoder.defaultAbiCoder();
const A=n=>getAddress(toBeHex(n,20)),H=n=>toBeHex(n,32), owner=A(200), runtime="0x6001600055", chainId=31337n;
const options=()=>({blockTag:50,gasLimit:500000n});
const deployment=()=>({chainId,attribution:{address:owner,codeHash:keccak256(runtime)}});
function empty(type){if(type.baseType==="tuple")return Object.fromEntries(type.components.map(x=>[x.name,empty(x)]));if(type.baseType==="array")return Array.from({length:type.arrayLength},()=>empty(type.arrayChildren));if(type.type==="address")return ZeroAddress;if(type.type==="bool")return false;if(type.type.startsWith("uint"))return 0n;if(type.type==="bytes32")return ZeroHash;throw Error(type.type);}
function data(){
  const reference={version:1n,profileHash:pure.PERSONHOOD_PROFILE_HASH,artistRegistry:A(1),artistId:H(2),operativeIdentityRecordHash:H(3),notarizationHost:A(4),notarizationRuntimeHash:H(5),notarizationRecordHash:H(6)};
  const statement=pure.encodeArtistPersonhoodReference(reference);
  const nativeRecord={recordHash:H(7),subjectStateHash:H(3),schemaId:pure.PERSONHOOD_EVIDENCE_SCHEMA,statementHash:keccak256(statement),generation:1n,signedAt:123n,signer:A(8)};
  const summary={version:1n,chainId,nativeRecordHash:H(7),statementHash:keccak256(statement),artistId:H(2),bindingHash:H(9),generation:1n,collectionId:11n,identityRecordHash:H(3),evidenceReference:reference,originalRegistryCodeHash:H(10),core:A(11),coreCodeHash:H(12),moduleRegistry:A(13),moduleRegistryCodeHash:H(14),schemaRegistry:A(15),schemaRegistryCodeHash:H(16),chunkStore:A(17),chunkStoreCodeHash:H(18),definitionFactsHashes:[H(20),H(21),H(22),H(23)],notarizationCollectionId:11n,attestationType:id("INSTITUTIONAL_VERIFICATION"),subjectId:H(24),recorder:A(25),documentaryHash:H(26),moduleIdentityHash:H(27),carriers:[30,31,32,33,34,35].map(A),carrierCodeHashes:[30,31,32,33,34,35].map(H)};
  const selection={nativeRecord,sourceRegistry:A(1),evidenceReference:reference,notarizationType:summary.attestationType,recorder:A(25),notarizationHead:H(6),identityCurrent:true,notarizationCurrent:true,status:2n};
  return {reference,statement,nativeRecord,summary,selection,summaryHash:keccak256(coder.encode(["bytes32",reads.getFunction("personhoodProofSummary").outputs[0]],[id("6529STREAM_ARTIST_PERSONHOOD_PROOF_SUMMARY_V1"),summary]))};
}
function harness(edit={}){
  const d=data(); const calls=[];let blocks=0;
  const provider={
    async getNetwork(){edit.onNetwork?.();return {chainId:edit.chainId??chainId};},
    async getBlock(tag){blocks++;return {number:tag,hash:edit.reorg&&blocks>1?H(999):H(tag),timestamp:1000+tag};},
    async getCode(address,tag){assert.equal(address,owner);assert.equal(tag,50);return edit.runtime??runtime;},
    async call(tx){
      assert.equal(tx.to,owner,"retained reads never require former documentary hosts");assert.equal(tx.blockTag,50);
      const method=actual.parseTransaction(tx);calls.push(method.name);
      if(edit.fail===method.name)throw Error("original read failed");
      let out;
      switch(method.name){
        case"deploymentChainId":out=[chainId];break;
        case"personhoodEvidence":out=[edit.selection??d.selection];break;
        case"personhoodEvidenceStatus":{const s=edit.selection??d.selection;out=edit.compact??[s.nativeRecord.recordHash,s.status];break;}
        case"personhoodProofSummary":out=[edit.summary??d.summary];break;
        case"personhoodProofSummaryHash":out=[edit.summaryHash??d.summaryHash];break;
        case"attestationRecord":out=[edit.nativeRecord??d.nativeRecord];break;
        case"statementBytes":out=[edit.statement??d.statement];break;
        case"auditPersonhoodEvidence":out=edit.audit??[d.summary.documentaryHash,[d.summary.attestationType,d.summary.recorder,d.reference.notarizationRecordHash,true]];break;
        default:throw Error("Unexpected read "+method.name);
      }
      const raw=actual.encodeFunctionResult(method.name,out);return edit.trailing===method.name?raw+"00":raw;
    },
  };return {provider,calls,d};
}
const subject=()=>({method:"personhoodEvidence",collectionId:11n,artistId:H(2)});
const record=method=>({method,nativeRecordHash:H(7)});
test("current evidence and compact status use original fixed owner only",async()=>{
  for(const method of ["personhoodEvidence","personhoodEvidenceStatus"]){const h=harness();const result=await inspectArtistPersonhood(h.provider,deployment(),{...subject(),method},options());assert.deepEqual(result.selection,h.d.selection);assert.equal(result.summary,null);assert.equal(result.audit,null);assert.deepEqual(h.calls,["deploymentChainId","personhoodEvidence","personhoodEvidenceStatus"]);assert.ok(Object.isFrozen(result.selection.nativeRecord));}
});
test("retained summary and hash join immutable local native statement without former dependencies",async()=>{
  for(const method of ["personhoodProofSummary","personhoodProofSummaryHash"]){const h=harness();const result=await inspectArtistPersonhood(h.provider,deployment(),record(method),options());assert.deepEqual(result.summary,h.d.summary);assert.equal(result.summaryHash,h.d.summaryHash);assert.equal(result.audit,null);assert.equal(result.selection,null);assert.deepEqual(h.calls,["deploymentChainId","personhoodProofSummary","personhoodProofSummaryHash","attestationRecord","statementBytes"]);}
});
test("explicit audit preserves original recorder/hash while disclosing a superseded documentary head",async()=>{
  const d=data(),h=harness({audit:[d.summary.documentaryHash,[d.summary.attestationType,d.summary.recorder,H(999),false]]});
  const result=await inspectArtistPersonhood(h.provider,deployment(),record("auditPersonhoodEvidence"),options());assert.equal(result.audit.current,false);assert.equal(result.audit.head,H(999));assert.equal(result.summary.evidenceReference.notarizationRecordHash,H(6));assert.equal(h.calls.at(-1),"auditPersonhoodEvidence");
  const bad=harness({audit:[d.summary.documentaryHash,[d.summary.attestationType,A(777),H(6),true]]});await assert.rejects(inspectArtistPersonhood(bad.provider,deployment(),record("auditPersonhoodEvidence"),options()),/audit differs/);
});
test("all five status values preserve the original native selection",async()=>{
  const base=data(),none=empty(reads.getFunction("personhoodEvidence").outputs[0]);
  const rows=[none,{...base.selection,status:1n,nativeRecord:{...base.nativeRecord,schemaId:pure.PERSONHOOD_WAIVER_SCHEMA},evidenceReference:none.evidenceReference,notarizationType:ZeroHash,recorder:ZeroAddress,notarizationHead:ZeroHash,notarizationCurrent:false},base.selection,{...base.selection,status:3n,notarizationCurrent:false,notarizationHead:H(999)},{...base.selection,status:4n,identityCurrent:false,notarizationCurrent:false}];
  for(const selection of rows){const h=harness({selection});const got=await inspectArtistPersonhood(h.provider,deployment(),subject(),options());assert.equal(got.selection.status,selection.status);assert.equal(got.audit,null);assert.equal(got.summary,null);}
});
test("opaque legacy evidence and absent summaries stay unresolved/empty without invented proof",async()=>{
  const d=data(),none=empty(reads.getFunction("personhoodEvidence").outputs[0]),zero=empty(reads.getFunction("personhoodProofSummary").outputs[0]);
  const selection={...d.selection,nativeRecord:{...d.nativeRecord,statementHash:H(888)},evidenceReference:none.evidenceReference,notarizationType:ZeroHash,notarizationHead:ZeroHash,recorder:ZeroAddress,notarizationCurrent:false,status:4n};
  const h=harness({selection});assert.equal((await inspectArtistPersonhood(h.provider,deployment(),subject(),options())).selection.status,4n);
  const z=harness({summary:zero,summaryHash:ZeroHash});const got=await inspectArtistPersonhood(z.provider,deployment(),record("personhoodProofSummary"),options());assert.equal(got.summary,null);assert.equal(got.summaryHash,ZeroHash);assert.ok(!z.calls.includes("statementBytes"));
});
test("consistent full/compact results still reject a canonical reference for a different Artist",async()=>{
  const d=data(),reference={...d.reference,artistId:H(999)},selection={...d.selection,evidenceReference:reference,nativeRecord:{...d.nativeRecord,statementHash:keccak256(pure.encodeArtistPersonhoodReference(reference))}};
  const h=harness({selection});await assert.rejects(inspectArtistPersonhood(h.provider,deployment(),subject(),options()),/Artist|artist|reference/i);
});
test("subject joins compare bytes while accepting equivalent uppercase Artist input",async()=>{
  const d=data(),artist=H(0xabc),reference={...d.reference,artistId:artist};
  const selection={...d.selection,evidenceReference:reference,nativeRecord:{...d.nativeRecord,statementHash:keccak256(pure.encodeArtistPersonhoodReference(reference))}};
  const h=harness({selection});const result=await inspectArtistPersonhood(h.provider,deployment(),{...subject(),artistId:"0x"+artist.slice(2).toUpperCase()},options());
  assert.equal(result.selection.evidenceReference.artistId,artist);
});
test("compact mismatch, malformed ABI, changed chain/code/block are refused",async()=>{
  for(const edit of [{compact:[H(999),2n]},{trailing:"personhoodEvidence"},{runtime:"0x6002600055"},{chainId:1n},{reorg:true}]){const h=harness(edit);await assert.rejects(inspectArtistPersonhood(h.provider,deployment(),subject(),options()));}
});
test("summary cannot substitute retained hash, native identity, canonical statement or chain",async()=>{
  const d=data();
  for(const edit of [{summaryHash:H(999)},{nativeRecord:{...d.nativeRecord,subjectStateHash:H(999)}},{statement:"0x11"}]){const h=harness(edit);await assert.rejects(inspectArtistPersonhood(h.provider,deployment(),record("personhoodProofSummary"),options()));}
  const wrong={...d.summary,chainId:1n};const h=harness({summary:wrong,summaryHash:pure.artistPersonhoodSummaryHash(wrong)});await assert.rejects(inspectArtistPersonhood(h.provider,deployment(),record("personhoodProofSummary"),options()),/chain differs/);
});
test("inspection owns input before awaiting and enforces finite gas/strict keys",async()=>{
  const q=subject(),d=deployment(),h=harness({onNetwork:()=>{q.artistId=H(999);d.attribution.address=A(999);}});
  const got=await inspectArtistPersonhood(h.provider,d,q,options());assert.equal(got.request.artistId,H(2));
  for(const gasLimit of [0n,100000001n,500000])await assert.rejects(inspectArtistPersonhood(harness().provider,deployment(),subject(),{blockTag:50,gasLimit}));
  await assert.rejects(inspectArtistPersonhood(harness().provider,deployment(),{...subject(),ignored:1},options()));
});
