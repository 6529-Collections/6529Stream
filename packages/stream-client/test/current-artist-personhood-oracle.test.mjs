import test from "node:test";
import assert from "node:assert/strict";
import { createHash } from "node:crypto";
import { readFileSync } from "node:fs";
import ts from "typescript";
import { AbiCoder, Interface, ParamType, getAddress, id, keccak256, toBeHex, toUtf8Bytes, toUtf8String } from "ethers";
import * as p from "../dist/current-artist-personhood.js";
import { createSafeCallPlan, verifySafeCallPlan, safeCallInventory } from "../dist/safe-plan.js";
import { ARTIST_RECOVERY_NOTICE_TUPLE, ARTIST_RECOVERY_TERMINAL_TUPLE } from "../dist/current-artist-recovery-adjudication.js";
const f=JSON.parse(readFileSync(new URL("./fixtures/current-artist-personhood-abi.json",import.meta.url),"utf8"));
const abi=Object.fromEntries(Object.entries(f.abis).map(([k,v])=>[k,new Interface(v)]));
const c=AbiCoder.defaultAbiCoder(), own=new Interface(p.CURRENT_ARTIST_PERSONHOOD_ABI);
const source=name=>Object.entries(f.sourceTexts).find(([path])=>path.endsWith("/"+name))[1];
test("personhood ABI102 fixture has exact source identity and internally authenticated retained witnesses",()=>{
  assert.equal(f.sourceCommit,p.PERSONHOOD_SOURCE);assert.equal(f.sourceCommit,"70c0d9c37f6435c480b87083af8d1cbd4fa7098d");
  assert.equal(f.sourceTree,"6f5e76e63d2ed31fa881aed6983e405b7aa07e89");assert.equal(f.sourceCount,2710);
  assert.equal(f.inputSha256,"cceb85599b712a445de6ecc8235bd7c7673b287926265982cd0bfe5321577dbe");
  assert.equal(f.outputSha256,"101c9b9c30be178034d15548f34aaf2eb87f61f1da8756d3617b8113b4121054");
  assert.match(f.qualification,/Recovered op60 with personhood is excluded/);
  for(const[path,text]of Object.entries(f.sourceTexts))assert.equal(createHash("sha256").update(text).digest("hex"),f.sourceHashes[path],path);
  for(const[path,doc]of Object.entries(f.documents)){assert.equal(createHash("sha256").update(doc.text).digest("hex"),doc.sha256,path);assert.equal(toUtf8Bytes(doc.text).length,doc.byteLength);}
});
test("all public personhood protocol fragments match original full compiler selectors, tuples and outputs",()=>{
  own.forEachFunction(fragment=>{
    const target=fragment.name==="recordArtistAttestation"||fragment.name==="attestationDigest"?abi.registry:abi.personhood;
    const actual=target.getFunction(fragment.format("sighash"));assert.ok(actual);assert.equal(fragment.selector,actual.selector);
    assert.equal(fragment.stateMutability,actual.stateMutability);
    assert.deepEqual(fragment.outputs.map(v=>v.format("sighash")),actual.outputs.map(v=>v.format("sighash")));
  });
  assert.equal(own.getEvent("ArtistPersonhoodProofRetained").format("sighash"),abi.summary.getEvent("ArtistPersonhoodProofRetained").format("sighash"));
  assert.deepEqual(own.getEvent("ArtistPersonhoodProofRetained").inputs.map(p=>Boolean(p.indexed)),abi.summary.getEvent("ArtistPersonhoodProofRetained").inputs.map(p=>Boolean(p.indexed)));
  assert.deepEqual(safeCallInventory(p.CURRENT_ARTIST_PERSONHOOD_ABI).map(x=>x.method),[abi.registry.getFunction("recordArtistAttestation").format("sighash")]);
});
test("complete reference, summary and selection codecs preserve compiler field names and integer widths",()=>{
  const summary=abi.personhood.getFunction("personhoodProofSummary").outputs[0];
  const selection=abi.personhood.getFunction("personhoodEvidence").outputs[0];
  const ref=summary.components.find(x=>x.name==="evidenceReference");
  const strip=p=>p.format("full").replace(/\s+[A-Za-z_][A-Za-z0-9_]*$/,"");
  for(const[actual,client]of[[summary,p.PERSONHOOD_SUMMARY_TUPLE],[selection,p.PERSONHOOD_SELECTION_TUPLE],[ref,p.PERSONHOOD_REFERENCE_TUPLE]])assert.equal(strip(actual),strip(ParamType.from(client)));
});
test("reference JSON profile has original literal keccak, full bytes and exact Solidity key order",()=>{
  const doc=f.documents["schemas/records/STREAM_ARTIST_PERSONHOOD_REFERENCE_JSON_PROFILE_V1.json"];
  assert.equal(doc.byteLength,1837);assert.equal(keccak256(toUtf8Bytes(doc.text)),p.PERSONHOOD_PROFILE_HASH);
  const raw=source("StreamArtistPersonhoodJSON.sol");
  const ordered=["artistId","artistRegistry","notarizationHost","notarizationRecordHash","notarizationRuntimeHash","operativeIdentityRecordHash","profileHash","version"];
  let cursor=0;for(const name of ordered){const at=raw.indexOf('"'+name+'"',cursor);assert.ok(at>=cursor,name);cursor=at+name.length+2;}
  assert.match(raw,/raw\.length != 590/);assert.match(raw,/\[uint256\(15\), 101, 165, 235, 330, 429, 512\]/);
});
test("original General interface identity excludes inherited IERC165 and retains source-defined own selectors",()=>{
  let ownId=0n;abi.general.forEachFunction(fn=>{if(fn.name!=="supportsInterface")ownId^=BigInt(fn.selector);});
  assert.equal(toBeHex(ownId,4),p.PERSONHOOD_GENERAL_INTERFACE_ID);
  assert.match(source("IStreamGeneralAttestations.sol"),/interface IStreamGeneralAttestations is IERC165/);
});
test("original native record is principal op24, with source-owned nested evidence and authority classes",()=>{
  const src=source("StreamArtistHashes.sol");assert.match(src,/words\.domain = keccak256\("6529STREAM_ARTIST_ATTESTATION_RECORD_V1"\)/);
  assert.match(src,/words\.authorityClass = authorityClass/);assert.match(src,/return keccak256\(abi\.encode\(words\)\)/);
  assert.match(source("StreamArtistIdentityOperations.sol"),/attest/);
  assert.match(source("StreamArtistIdentityState.sol"),/4096/);
  assert.match(source("StreamArtistAuthorityPolicy.sol"),/CAP_ATTEST/);
  const summary=source("StreamArtistPersonhoodSummary.sol");assert.match(summary,/abi\.encode\(TAG, summary\)/);
  assert.match(summary,/ARTIST_PERSONHOOD_PROOF_SUMMARY/);assert.match(summary,/emit ArtistPersonhoodProofRetained\(1, record\.recordHash, origin, hash, summary\)/);
  assert.match(source("StreamArtistDormancyState.sol"),/identity_authority\.replay\.dormancy_cancellation_key/);
  assert.match(readFileSync(new URL("../src/current-artist-personhood-workflow.ts",import.meta.url),"utf8"),/"identity_authority\.replay\.dormancy_cancellation_key"/);
});
test("original canonical personhood CALL composes shared Safe planner without changing caller, value or domain",()=>{
  const A=n=>getAddress(toBeHex(n,20)),H=n=>toBeHex(n,32);
  const call=p.prepareArtistPersonhoodCall({chainId:11155111n,registry:A(1),core:A(2),caller:A(3),collectionId:4n,nonce:5n,signedAt:0n,signature:"0x",statementURI:"ipfs://proof",reference:{version:1n,profileHash:p.PERSONHOOD_PROFILE_HASH,artistRegistry:A(1),artistId:H(6),operativeIdentityRecordHash:H(7),notarizationHost:A(8),notarizationRuntimeHash:H(9),notarizationRecordHash:H(10)}});
  const plan=createSafeCallPlan(11155111n,"Record Artist personhood evidence",[{safe:A(3),intent:"Original principal operation 24",call:call.call,abi:f.abis.registry}]);
  assert.deepEqual(verifySafeCallPlan(plan,[p.CURRENT_ARTIST_PERSONHOOD_ABI]),plan);
  assert.equal(plan.steps[0].transaction.operation,0);assert.equal(plan.steps[0].transaction.value,"0");assert.equal(plan.steps[0].transaction.to,A(1));
  const decoded=abi.registry.parseTransaction(call.call);assert.equal(decoded.name,"recordArtistAttestation");assert.equal(decoded.args[0].subjectId,H(6));assert.equal(decoded.args[0].subjectStateHash,H(7));
  assert.equal(decoded.args[0].statementHash,keccak256(decoded.args[2]));assert.equal(toUtf8String(decoded.args[2]).length,590);
  assert.throws(()=>createSafeCallPlan(11155111n,"Invalid funded op24",[{safe:A(3),intent:"Invalid value",call:{...call.call,value:1n},abi:f.abis.registry}]));
  assert.throws(()=>createSafeCallPlan(11155111n,"Read-only call",[{safe:A(3),intent:"Read evidence",call:p.prepareArtistPersonhoodRead(A(20),"personhoodEvidence",[4n,H(6)]),abi:f.abis.personhood}]));
});
test("workflow protocol ABI literals independently match retained compiler fragments",()=>{
  const text=readFileSync(new URL("../src/current-artist-personhood-workflow.ts",import.meta.url),"utf8");
  const tree=ts.createSourceFile("workflow.ts",text,ts.ScriptTarget.Latest,true,ts.ScriptKind.TS);
  const declarations=new Map();
  for(const node of tree.statements)if(ts.isVariableStatement(node))for(const decl of node.declarationList.declarations)if(ts.isIdentifier(decl.name))declarations.set(decl.name.text,decl.initializer);
  const named={ARTIST_RECOVERY_NOTICE_TUPLE,ARTIST_RECOVERY_TERMINAL_TUPLE};
  function literal(node){
    if(ts.isStringLiteral(node)||ts.isNoSubstitutionTemplateLiteral(node))return node.text;
    if(ts.isTemplateExpression(node))return node.head.text+node.templateSpans.map(s=>literal(s.expression)+s.literal.text).join("");
    if(ts.isIdentifier(node))return Object.hasOwn(named,node.text)?named[node.text]:literal(declarations.get(node.text));
    if(ts.isPropertyAccessExpression(node)&&node.expression.getText(tree)==="personhood")return p[node.name.text];
    if(ts.isArrayLiteralExpression(node))return node.elements.flatMap(n=>ts.isSpreadElement(n)?literal(n.expression):[literal(n)]);
    throw Error(`Unexpected ABI expression ${node?.getText(tree)}`);
  }
  const constructor=declarations.get("abi");assert.ok(ts.isNewExpression(constructor));
  const compiled=new Interface(literal(constructor.arguments[0]));
  const witnesses=Object.values(abi).flatMap(v=>v.fragments);
  for(const fragment of compiled.fragments){
    const found=witnesses.filter(v=>v.type===fragment.type&&v.format("sighash")===fragment.format("sighash"));
    assert.ok(found.length,fragment.format("full"));
    if(fragment.type==="function")assert.ok(found.some(v=>v.stateMutability===fragment.stateMutability&&JSON.stringify(v.outputs.map(t=>t.format("sighash")))===JSON.stringify(fragment.outputs.map(t=>t.format("sighash")))),fragment.format("full"));
    if(fragment.type==="event")assert.ok(found.some(v=>JSON.stringify(v.inputs.map(t=>Boolean(t.indexed)))===JSON.stringify(fragment.inputs.map(t=>Boolean(t.indexed)))),fragment.name);
  }
});
