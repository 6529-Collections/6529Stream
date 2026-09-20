import test from "node:test";
import assert from "node:assert/strict";
import { AbiCoder, Interface, ZeroAddress, ZeroHash, getAddress, hexlify, id, keccak256, toUtf8Bytes, toUtf8String } from "ethers";
import * as p from "../dist/current-artist-personhood.js";
import { currentArtistTypedData, prepareCurrentArtistOperation } from "../dist/current-artist.js";
const coder = AbiCoder.defaultAbiCoder(), abi = new Interface(p.CURRENT_ARTIST_PERSONHOOD_ABI);
const A = n => getAddress("0x" + n.toString(16).padStart(40, "0"));
const H = n => "0x" + n.toString(16).padStart(64, "0");
const ref = () => ({version:1n,profileHash:p.PERSONHOOD_PROFILE_HASH,artistRegistry:A(10),artistId:H(1),operativeIdentityRecordHash:H(2),notarizationHost:A(20),notarizationRuntimeHash:H(3),notarizationRecordHash:H(4)});
const request = () => ({chainId:11155111n,registry:A(10),core:A(11),caller:A(12),collectionId:7n,reference:ref(),nonce:3n,signedAt:0n,signature:"0x",statementURI:"ipfs://proof"});
const summary = () => ({version:1n,chainId:11155111n,nativeRecordHash:H(10),statementHash:keccak256(p.encodeArtistPersonhoodReference(ref())),artistId:H(1),bindingHash:H(11),generation:2n,collectionId:7n,identityRecordHash:H(2),evidenceReference:ref(),originalRegistryCodeHash:H(12),core:A(11),coreCodeHash:H(13),moduleRegistry:A(30),moduleRegistryCodeHash:H(14),schemaRegistry:A(31),schemaRegistryCodeHash:H(15),chunkStore:A(32),chunkStoreCodeHash:H(16),definitionFactsHashes:[H(20),H(21),H(22),H(23)],notarizationCollectionId:9n,attestationType:id("INSTITUTIONAL_VERIFICATION"),subjectId:H(24),recorder:A(33),documentaryHash:H(25),moduleIdentityHash:H(26),carriers:[40,41,42,43,44,45].map(A),carrierCodeHashes:[40,41,42,43,44,45].map(H)});
const selection = () => ({nativeRecord:{recordHash:H(10),subjectStateHash:H(2),schemaId:p.PERSONHOOD_EVIDENCE_SCHEMA,statementHash:keccak256(p.encodeArtistPersonhoodReference(ref())),generation:2n,signedAt:100n,signer:A(12)},sourceRegistry:A(10),evidenceReference:ref(),notarizationType:id("INSTITUTIONAL_VERIFICATION"),recorder:A(33),notarizationHead:H(4),identityCurrent:true,notarizationCurrent:true,status:2n});
const rawSelection = s => coder.encode([p.PERSONHOOD_SELECTION_TUPLE],[s]);
test("personhood reference retains fixed lowercase JSON bytes, not registration identity",()=>{
  const r=ref(), raw=p.encodeArtistPersonhoodReference(r), obj=JSON.parse(toUtf8String(raw));
  assert.equal((raw.length-2)/2,590); assert.deepEqual(Object.keys(obj),["artistId","artistRegistry","notarizationHost","notarizationRecordHash","notarizationRuntimeHash","operativeIdentityRecordHash","profileHash","version"]);
  assert.deepEqual(p.decodeArtistPersonhoodReference(raw),r); assert.equal(obj.operativeIdentityRecordHash,H(2));
  assert.ok(Object.isFrozen(p.normalizeArtistPersonhoodReference(r)));
});
test("canonical reference rejects alternate JSON encodings, shape, zero facts and profiles",()=>{
  const raw=p.encodeArtistPersonhoodReference(ref()), obj=JSON.parse(toUtf8String(raw));
  const encode=o=>hexlify(toUtf8Bytes(JSON.stringify(o)));
  assert.throws(()=>p.decodeArtistPersonhoodReference(encode(Object.fromEntries(Object.entries(obj).reverse()))));
  assert.throws(()=>p.decodeArtistPersonhoodReference(encode({...obj,version:1.0,artistId:obj.artistId.replace("1","A")})));
  for(const [key,v] of [["version",2n],["profileHash",H(99)],["artistRegistry",ZeroAddress],["artistId",ZeroHash],["operativeIdentityRecordHash",ZeroHash],["notarizationRecordHash",ZeroHash]]) assert.throws(()=>p.encodeArtistPersonhoodReference({...ref(),[key]:v}));
  assert.throws(()=>p.encodeArtistPersonhoodReference({...ref(),extra:1}));
  assert.throws(()=>p.decodeArtistPersonhoodReference(raw+"00"));
});
test("prepared canonical personhood uses original principal operation, signature domain and zero value",()=>{
  const q=request(), c=p.prepareArtistPersonhoodCall(q);
  const original=prepareCurrentArtistOperation("artistAttestation",q.chainId,q.registry,c.message,{signature:q.signature,statement:c.statement,statementURI:q.statementURI});
  assert.deepEqual(c.operation,original); assert.deepEqual(c.call,original.call); assert.equal(c.call.value,0n); assert.equal(c.message.subjectKind,10n);
  assert.equal(c.operation.payload.domain.name,"6529StreamArtistRegistry"); assert.equal(c.operation.payload.domain.verifyingContract,A(10));
  assert.equal(abi.parseTransaction(c.call).name,"recordArtistAttestation"); assert.equal(c.factsVerified,false);
  assert.deepEqual(p.normalizeArtistPersonhoodCall(c),c);
  q.reference.artistId=H(100); assert.equal(c.request.reference.artistId,H(1));
});
test("call normalization refuses substitutions, foreign-domain evidence and invalid protocol integers",()=>{
  const c=p.prepareArtistPersonhoodCall(request());
  for(const altered of [{...c,factsVerified:true},{...c,call:{...c.call,value:1n}},{...c,statement:"0x"}]) assert.throws(()=>p.normalizeArtistPersonhoodCall(altered));
  assert.throws(()=>p.prepareArtistPersonhoodCall({...request(),registry:A(99)}));
  for(const [key,value] of [["nonce",1],["chainId",0n],["signedAt",1n<<64n],["collectionId",-1n]]) assert.throws(()=>p.prepareArtistPersonhoodCall({...request(),[key]:value}));
  assert.throws(()=>p.prepareArtistPersonhoodCall({...request(),signature:"0x11"}));
  assert.throws(()=>p.prepareArtistPersonhoodCall({...request(),statementURI:"x".repeat(2049)}));
  assert.throws(()=>p.prepareArtistPersonhoodCall({...request(),signedAt:99n,signature:"0x"+"11".repeat(4097)}));
  assert.equal(p.prepareArtistPersonhoodCall({...request(),signedAt:99n,signature:"0x"+"11".repeat(4096)}).request.signature.length,8194);
  for(const uri of ["x\ud800","x\udc00","x\udc00\ud800"]) assert.throws(()=>p.prepareArtistPersonhoodCall({...request(),statementURI:uri}));
});
test("relay signing retains exact chain/domain/nonce and opaque ERC1271 proof",()=>{
  const c=p.prepareArtistPersonhoodCall({...request(),signedAt:99n,signature:"0xaabb"});
  assert.equal(c.operation.payload.digest,currentArtistTypedData("artistAttestation",11155111n,A(10),c.message).digest);
  const tx=abi.parseTransaction(c.call); assert.equal(tx.args[1].signature,"0xaabb"); assert.equal(tx.args[1].time,99n);
  assert.notEqual(c.operation.payload.digest,p.prepareArtistPersonhoodCall({...request(),chainId:1n,signedAt:99n,signature:"0xaabb"}).operation.payload.digest);
});
test("summary uses all 48 original words and tagged payload hash, preserving immutable reference",()=>{
  const s=summary(), raw=p.encodeArtistPersonhoodSummary(s);
  assert.equal((raw.length-2)/2,1536); assert.deepEqual(p.decodeArtistPersonhoodSummary(raw),s);
  const tagged=coder.encode(["bytes32",p.PERSONHOOD_SUMMARY_TUPLE],[id("6529STREAM_ARTIST_PERSONHOOD_PROOF_SUMMARY_V1"),s]);
  assert.equal((tagged.length-2)/2,1568); assert.equal(p.artistPersonhoodSummaryHash(s),keccak256(tagged));
  const changed={...s,carrierCodeHashes:[...s.carrierCodeHashes.slice(0,5),H(777)]}; assert.notEqual(p.artistPersonhoodSummaryHash(changed),p.artistPersonhoodSummaryHash(s));
});
test("summary rejects semantic substitution and malformed raw ABI",()=>{
  const s=summary();
  for(const bad of [{...s,artistId:H(99)},{...s,identityRecordHash:H(99)},{...s,statementHash:H(99)},{...s,carriers:s.carriers.slice(1)},{...s,definitionFactsHashes:[ZeroHash,...s.definitionFactsHashes.slice(1)]},{...s,chainId:11155111},{...s,evidenceReference:{...s.evidenceReference,extra:1}}]) assert.throws(()=>p.normalizeArtistPersonhoodSummary(bad));
  assert.throws(()=>p.decodeArtistPersonhoodSummary(p.encodeArtistPersonhoodSummary(s)+"00"));
  assert.throws(()=>p.decodeArtistPersonhoodSummary("0x"+"00".repeat(1535)));
});
test("absent summary is exact zero and carries no documentary evidence",()=>{
  const zero=p.decodeArtistPersonhoodSummary("0x"+"00".repeat(1536)); assert.equal(zero.version,0n); assert.equal(p.artistPersonhoodSummaryHash(zero),ZeroHash);
  assert.throws(()=>p.normalizeArtistPersonhoodSummary({...zero,chainId:1n}));
});
test("selection preserves all five statuses without promoting stale or unresolved evidence",()=>{
  const s=selection(); assert.equal((rawSelection(s).length-2)/2,704); assert.deepEqual(p.decodeArtistPersonhoodSelection(rawSelection(s)),s);
  assert.equal(p.decodeArtistPersonhoodSelection(rawSelection({...s,status:3n,notarizationCurrent:false,notarizationHead:H(900)})).status,3n);
  assert.equal(p.decodeArtistPersonhoodSelection(rawSelection({...s,status:4n,notarizationCurrent:false})).status,4n);
  const none=p.decodeArtistPersonhoodSelection("0x"+"00".repeat(704)); assert.equal(none.status,0n);
  const waiver={...s,nativeRecord:{...s.nativeRecord,schemaId:p.PERSONHOOD_WAIVER_SCHEMA},evidenceReference:none.evidenceReference,status:1n,notarizationCurrent:false,notarizationType:ZeroHash,notarizationHead:ZeroHash,recorder:ZeroAddress};
  assert.equal(p.decodeArtistPersonhoodSelection(rawSelection(waiver)).status,1n);
});
test("selection refuses inconsistent resolved, NONE, waiver and unknown status facts",()=>{
  const s=selection();
  for(const bad of [{...s,status:0n},{...s,status:5n},{...s,status:1n},{...s,identityCurrent:false},{...s,notarizationCurrent:false},{...s,notarizationHead:H(99)},{...s,sourceRegistry:A(99)}]) assert.throws(()=>p.decodeArtistPersonhoodSelection(rawSelection(bad)));
  for(const status of [2n,3n,4n])assert.throws(()=>p.decodeArtistPersonhoodSelection(rawSelection({...s,status,nativeRecord:{...s.nativeRecord,statementHash:H(777)}})));
});
test("native record hashes preserve actual principal class, signer and mined timestamp",()=>{
  const c=p.prepareArtistPersonhoodCall(request());
  const original=keccak256(coder.encode(["bytes32","uint256","address","address","uint256","uint8","bytes32","bytes32","bytes32","bytes32","bytes32","bytes32","address","uint8","uint256","uint64"],[id("6529STREAM_ARTIST_ATTESTATION_RECORD_V1"),11155111n,A(10),A(11),7n,10n,H(1),H(2),p.PERSONHOOD_EVIDENCE_SCHEMA,c.message.statementHash,c.message.statementURIHash,H(1),A(12),1n,3n,101n]));
  assert.equal(p.artistPersonhoodNativeRecordHash(c,A(12),1n,101n),original);
  assert.notEqual(p.artistPersonhoodNativeRecordHash(c,A(12),3n,101n),original); assert.notEqual(p.artistPersonhoodNativeRecordHash(c,A(12),1n,102n),original);
  assert.throws(()=>p.artistPersonhoodNativeRecordHash(c,A(12),2n,101n));
});
test("all five evidence reads retain owner target, zero value and exact query",()=>{
  for(const method of ["personhoodEvidence","personhoodEvidenceStatus","personhoodProofSummary","personhoodProofSummaryHash","auditPersonhoodEvidence"]){
    const args=method==="personhoodEvidence"||method==="personhoodEvidenceStatus"?[7n,H(1)]:[H(10)];
    const call=p.prepareArtistPersonhoodRead(A(50),method,args);assert.equal(call.to,A(50));assert.equal(call.value,0n);assert.equal(abi.parseTransaction(call).name,method);
  }
  assert.throws(()=>p.prepareArtistPersonhoodRead(A(50),"recordArtistAttestation",[]));
  assert.throws(()=>p.prepareArtistPersonhoodRead(A(50),"personhoodEvidence",[7,H(1)]));
});
