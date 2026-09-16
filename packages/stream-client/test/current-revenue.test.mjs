import test from "node:test";
import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import { AbiCoder, Interface, ZeroAddress, ZeroHash, id, keccak256, concat, toUtf8Bytes } from "ethers";
import { CurrentRevenueClient, primaryCollaboratorSource, primaryAccountSources, primaryTemplateAssignmentHash, snapshotModeAssignmentHash, toSafeCall } from "../dist/index.js";
import { revenueFixture } from "../scripts/generate-current-revenue-fixture.mjs";

const fixture = JSON.parse(await readFile(new URL("./fixtures/current-revenue-abi.json", import.meta.url), "utf8"));
const abi = Object.fromEntries(Object.entries(fixture.abis).map(([k,v]) => [k,new Interface(v)]));
const A = n => "0x" + BigInt(n).toString(16).padStart(40,"0");
const addresses = { core:A(1),artist:A(2),primary:A(3),royalty:A(4),manager:A(5) };
const artist=A(20),owner=A(21),relayer=A(22),poster=A(23),collaborator=A(24);
const PRIMARY=id("PRIMARY_SALE"),ROYALTY=id("ROYALTY_ERC2981"),chain=31337n,collection=9007199254740993n,token=collection+8n;
const coder=AbiCoder.defaultAbiCoder(),code="0x60006000",codeHash=keccak256(code);
const make = () => new CurrentRevenueClient(chain,addresses,fixture.abis);
const profile=id("profile");
const fixed = {kind:"primary-profile",collectionId:collection,scope:2n,scopeId:token,profileId:profile};
const zero = {kind:"royalty-set",collectionId:collection,scope:1n,scopeId:collection,profileId:ZeroHash,royaltyBps:0n};
const authorization={nonce:9007199254740997n,deadline:9007199254740999n,signature:"0x"};
const primaryHash=(scope,id_,p)=>id(`primary:${scope}:${id_}:${p}`);
const royaltyHash=(scope,id_,p,bps)=>id(`royalty:${scope}:${id_}:${p}:${bps}`);
const F=(key,scope,id_,assignmentHash)=>({resolver:addresses[key],revenueClass:key==="primary"?PRIMARY:ROYALTY,scope,scopeId:id_,assignmentHash});

// Synthetic RPC boundary for client encoding/state-machine tests. Hash helpers below
// independently use literal Solidity preimages; this fixture is not an onchain capture.
class RPC {
  chainId=chain; number=20; calls=[]; mode=1n; election=ZeroHash; approved=false; malformed=null; badPointer=false; reorg=false;
  scope=0n; rawHash=id("original raw default"); rawPolicy=id("original scope0 policy"); currentPrimary=id("old primary"); currentRoyalty=id("old royalty"); corruptCode=false;
  async getNetwork(){return {chainId:this.chainId};}
  async getBlock(tag){return {number:this.number,hash:id(this.reorg && tag!=="latest" ? "reorg" : `block:${this.number}`)};}
  async getCode(address){return this.corruptCode && address===addresses.royalty ? "0x60016000":code;}
  source(){return {collectionId:collection,electionHash:this.election,config:{wallet:ZeroAddress,royaltyBps:0n,configured:true,frozen:this.scope===0n,revision:1n,profileId:ZeroHash},
    sourceAssignmentHash:this.rawHash,sourceRoyaltyPolicyHash:this.rawPolicy,modeAssignmentHash:snapshotModeAssignmentHash(chain,addresses.royalty,addresses.core,collection,this.election,this.rawHash)};}
  async call(tx){
    this.calls.push(tx); const key=Object.keys(addresses).find(k=>addresses[k].toLowerCase()===tx.to.toLowerCase());
    if(!key) throw Error("Unexpected target"); const parsed=abi[key].parseTransaction({data:tx.data,value:tx.value}); assert(parsed); const n=parsed.name,a=parsed.args;
    let result;
    if(n==="getSatellitePointer") result=[this.badPointer?A(99):addresses.artist,codeHash,false,ZeroHash,"0x00000000",ZeroAddress,0n,ZeroHash,ZeroHash,0n];
    else if(n==="core"||n==="boundCore")result=[addresses.core];
    else if(n==="owner")result=[owner];
    else if(n==="acceptedArtist")result=[artist];
    else if(n==="collectionRoyaltyMode")result=[this.mode,this.election];
    else if(n==="previewArtistPrimaryAssignmentForScope")result=[F("primary",a[1],a[2],primaryHash(a[1],a[2],a[3]))];
    else if(n==="previewArtistScopedPrimaryTemplateAssignment")result=[F("primary",a[1],a[2],primaryHash(a[1],a[2],a[3]))];
    else if(n==="previewArtistDefaultPrimaryTemplateAssignment")result=[F("primary",0n,0n,primaryHash(0n,0n,a[1]))];
    else if(n==="previewArtistRoyaltyAssignmentForScope")result=[F("royalty",a[1],a[2],royaltyHash(a[1],a[2],a[3],a[4]))];
    else if(n==="previewArtistSnapshotRoyaltyAssignment")result=[F("royalty",1n,a[0],snapshotModeAssignmentHash(chain,addresses.royalty,addresses.core,a[0],this.election,royaltyHash(1n,a[0],a[1],a[2])))];
    else if(n==="currentArtistSnapshotRoyaltyAssignment")result=[F("royalty",1n,a[0],this.source().modeAssignmentHash)];
    else if(n==="resolveRoyaltyAssignment")result=[F("royalty",this.scope,this.scope===0n?0n:a[0],this.rawHash),this.source().config,this.rawPolicy];
    else if(n==="royaltyEconomicsFacts")result=[F("royalty",a[1],a[2],this.currentRoyalty),{wallet:ZeroAddress,royaltyBps:0n,configured:true,frozen:false,revision:1n,profileId:ZeroHash}];
    else if(n==="primaryEconomicsFacts")result=[{exists:true,scope:a[1],scopeId:a[2],assignmentType:1n,profileId:profile,templateId:ZeroHash,policyHash:ZeroHash,assignmentHash:this.currentPrimary,frozen:false}];
    else if(n==="currentRoyaltySnapshotSource"){if(!this.approved)throw Error("Missing exact current approval");result=[this.source()];}
    else if(n==="requireEconomicsConsent"){assert.equal(tx.from.toLowerCase(),addresses.royalty.toLowerCase());if(!this.approved)throw Error("Missing exact current approval");result=[];}
    else if(n==="phaseRoyaltyConfigHash")result=[id(`phase:${a[1]}`)];
    else if(n.startsWith("preview") && n.endsWith("CollectionPrimaryProfile"))result=[id(`profile:${a[2]}`),A(50),id(`entries:${a[2]}`),...(n.includes("Dynamic")?[id("current beneficiary witness")]:[])];
    else if(n==="recordProspectiveEconomicsConsent"||n==="recordProspectiveTemplateEconomicsConsent"||n==="recordEconomicsConsent")result=[id("simulated record only")];
    else if(n==="economicsConsentDigest")result=[this.digest];
    else if(n.startsWith("configure")||n.startsWith("setPrimary"))result=n.startsWith("setPrimary")?[ZeroHash]:[];
    else throw Error(`Unhandled ${key}.${n}`);
    const encoded=abi[key].encodeFunctionResult(n,result);
    return this.malformed===n?encoded+"00".repeat(32):encoded;
  }
}
function messageHash(prepared){
  const fields=fixture.preimages.economics.match(/\((.*)\)/)[1].split(",").map(x=>{const [type,name]=x.split(" ");return {type,name};});
  const domain=keccak256(coder.encode(["bytes32","bytes32","bytes32","uint256","address"],[id("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"),id("6529StreamArtistRegistry"),id("1"),chain,addresses.artist]));
  const struct=keccak256(coder.encode(["bytes32",...fields.map(f=>f.type)],[id(fixture.preimages.economics),...fields.map(f=>prepared.payload.message[f.name])]));
  return keccak256(concat(["0x1901",domain,struct]));
}

test("token PROFILE quote preserves original op15 fields, Safe CALL and owner installation",async()=>{
  const c=make(),rpc=new RPC(),p=await c.quote(rpc,artist,fixed),a=c.prepareArtistApproval(p,authorization);
  assert.equal(p.fact.scopeId,token);assert.equal(p.approval,"fixed");assert.equal(a.payload.digest,messageHash(a));
  const parsed=abi.artist.parseTransaction({data:a.call.data});assert.equal(parsed.name,"recordProspectiveEconomicsConsent");assert.equal(parsed.args[0].collectionId,collection);assert.equal(parsed.args[0].scopeId,token);assert.equal(parsed.args[1].profileHash,profile);
  assert.equal(a.caller,artist);assert.equal(toSafeCall(a.call).operation,0);assert.equal(toSafeCall(a.call).value,"0");
  assert.equal(p.ownerCall.caller,owner);assert.equal(p.ownerCall.call.value,0n);assert.equal(abi.primary.parseTransaction({data:p.ownerCall.call.data}).args.scopeId,token);
  await c.simulate(rpc,a);assert.equal(rpc.calls.at(-1).from,artist);
  rpc.digest=a.payload.digest;await c.assertApprovalDigest(rpc,a,artist);
  rpc.number++;assert.equal((await c.assertFresh(rpc,p,artist)).fingerprint,p.fingerprint);
  rpc.currentPrimary=p.fact.assignmentHash;await c.assertInstalled(rpc,p,artist);
});

test("configured zero is a nonzero-hash SET, while global defaults have no Artist mutation authority",async()=>{
  const c=make(),rpc=new RPC(),p=await c.quote(rpc,artist,zero),a=c.prepareArtistApproval(p,authorization);
  assert.notEqual(p.fact.assignmentHash,ZeroHash);assert.equal(a.method,"recordProspectiveEconomicsConsent");
  const candidate=abi.artist.parseTransaction({data:a.call.data}).args[1];assert.equal(candidate.profileHash,ZeroHash);assert.equal(candidate.royaltyBps,0n);
  assert.equal(abi.royalty.parseTransaction({data:p.ownerCall.call.data}).name,"configureCollectionRoyalty");
  const d=await c.quote(rpc,artist,{...zero,scope:0n,scopeId:0n});assert.equal(d.approval,null);assert.equal(d.fact.scope,0n);
  assert.throws(()=>c.prepareArtistApproval(d,authorization),/Global/);assert.equal(abi.royalty.parseTransaction({data:d.ownerCall.call.data}).name,"configureDefaultRoyalty");
});

test("inherited frozen configured-zero snapshot retains scope0 source and collection-only mode approval",async()=>{
  const c=make(),rpc=new RPC();rpc.mode=2n;rpc.election=id("elected snapshot");
  const p=await c.quote(rpc,artist,{kind:"snapshot-current",collectionId:collection});
  assert.equal(p.rawSource.scope,0n);assert.equal(p.rawSource.scopeId,0n);assert.equal(p.fact.scope,1n);assert.equal(p.fact.scopeId,collection);assert.equal(p.ownerCall,null);
  const expected=keccak256(coder.encode(["bytes32","uint256","address","address","uint256","bytes32","bytes32"],[id(fixture.preimages.snapshotMode),chain,addresses.royalty,addresses.core,collection,rpc.election,rpc.rawHash]));
  assert.equal(p.fact.assignmentHash,expected);assert.equal(p.sourcePolicyHash,rpc.rawPolicy);assert.notEqual(p.fact.assignmentHash,rpc.rawHash);
  const a=c.prepareArtistApproval(p,authorization);assert.equal(a.method,"recordEconomicsConsent");assert.equal(a.payload.digest,messageHash(a));
  await assert.rejects(c.assertApproved(rpc,p),/Missing exact/);rpc.approved=true;await c.assertApproved(rpc,p);await c.assertInstalled(rpc,p,artist);
  const phase=await c.snapshotPhase(rpc,artist,collection,id("fresh phase"),id("application"));
  assert.equal(phase.policy.expectedSourceRoyaltyPolicyHash,rpc.rawPolicy);assert.equal(phase.policy.expectedModeAssignmentHash,expected);assert.equal(phase.policy.resolverRuntimeHash,codeHash);
  assert.equal(phase.ownerCall.caller,owner);assert.equal(phase.ownerCall.call.value,0n);
  assert.notEqual(snapshotModeAssignmentHash(chain,addresses.royalty,addresses.core,collection+1n,rpc.election,rpc.rawHash),expected);
});

test("snapshot collection SET dispatches to the mode preview and never permits token mutation",async()=>{
  const c=make(),rpc=new RPC();rpc.mode=2n;rpc.election=id("snapshot");const p=await c.quote(rpc,artist,zero);
  assert.equal(abi.royalty.parseTransaction({data:p.previewCall.data}).name,"previewArtistSnapshotRoyaltyAssignment");assert.equal(c.prepareArtistApproval(p,authorization).method,"recordProspectiveEconomicsConsent");
  await assert.rejects(c.quote(rpc,artist,{...zero,scope:2n,scopeId:token}),/token mutation/);
  const elected=c.election(owner,collection,2n);assert.equal(toSafeCall(elected.call).value,"0");assert.equal(abi.royalty.parseTransaction({data:elected.call.data}).args.mode,2n);
});

test("dynamic registration preserves each original collaborator identity including zero role",()=>{
  const c=make(),ref={account:collaborator,role:ZeroHash,shareLabelId:id("collaborator")},other={...ref,account:A(25)};
  const source=primaryCollaboratorSource(ref);assert.equal(source,keccak256(coder.encode(["bytes32","address","bytes32","bytes32"],[id(fixture.preimages.collaboratorSource),ref.account,ref.role,ref.shareLabelId])));
  assert.notEqual(source,primaryCollaboratorSource(other));
  const entries=[{account:ZeroAddress,accountSource:primaryAccountSources.artist,sharePpm:600000n,labelId:id("artist")},{account:ZeroAddress,accountSource:primaryAccountSources.poster,sharePpm:200000n,labelId:id("poster")},
    ...[ref,other].map(r=>({account:ZeroAddress,accountSource:primaryCollaboratorSource(r),sharePpm:100000n,labelId:r.shareLabelId}))];
  const prepared=c.registerTemplate(owner,entries,id("template metadata"),[ref,other]),parsed=abi.primary.parseTransaction({data:prepared.call.data});
  assert.equal(parsed.name,"createDynamicPrimaryTemplate");assert.equal(parsed.args[2][0].account,collaborator);assert.equal(parsed.args[2][0].role,ZeroHash);assert.equal(parsed.args[2].length,2);
  assert.throws(()=>c.registerTemplate(owner,entries,id("m"),[ref]),/Undeclared/);assert.throws(()=>c.registerTemplate(owner,entries,id("m"),[ref,ref]),/Duplicate/);
  assert.throws(()=>c.registerTemplate(owner,[...entries.slice(0,2),{...entries[2],sharePpm:200000n}],id("m"),[ref,other]),/Incomplete/);
  assert.throws(()=>c.registerTemplate(owner,[{...entries[0],accountSource:ZeroHash,account:artist},...entries.slice(1)],id("m"),[ref,other]),/artist source/);
});

test("registered templates support static64 and explicit poster materialization without signing the executor",async()=>{
  const c=make(),rpc=new RPC(),entries=Array.from({length:64},(_,i)=>({account:A(100+i),accountSource:ZeroHash,sharePpm:15625n,labelId:ZeroHash}));
  assert.equal(abi.primary.parseTransaction({data:c.registerTemplate(owner,entries,ZeroHash).call.data}).args[0].length,64);
  const templateId=id("registered template"),p=await c.quote(rpc,artist,{kind:"primary-template",collectionId:collection,scope:0n,scopeId:0n,templateId});
  const a=c.prepareArtistApproval(p,authorization);assert.equal(a.method,"recordProspectiveTemplateEconomicsConsent");assert.equal(a.payload.message.scope,0n);assert.equal(a.payload.digest,messageHash(a));
  assert.equal(Object.hasOwn(a.payload.message,"poster"),false);
  const call=c.materialize(relayer,collection,templateId,poster,true);assert.equal(call.caller,relayer);assert.equal(abi.primary.parseTransaction({data:call.call.data}).args.salePoster,poster);
  const preview=await c.previewMaterialization(rpc,relayer,collection,templateId,poster,true);assert.equal(preview.originalPoster,poster);assert.notEqual(preview.beneficiaryHash,ZeroHash);
  const changed=await c.previewMaterialization(rpc,relayer,collection,templateId,relayer,true);assert.notEqual(preview.profileId,changed.profileId);
});

test("freshness binds original caller, live old key, mode, contract code and actual selected Artist",async()=>{
  const c=make(),rpc=new RPC(),p=await c.quote(rpc,artist,fixed);
  await assert.rejects(c.assertFresh(rpc,p,relayer),/Caller/);rpc.currentPrimary=id("concurrent override");await assert.rejects(c.assertFresh(rpc,p,artist),/proposal changed/);
  rpc.currentPrimary=id("old primary");rpc.corruptCode=true;await assert.rejects(c.assertFresh(rpc,p,artist),/proposal changed/);await assert.rejects(c.assertInstalled(rpc,p,artist),/code changed/);
  rpc.corruptCode=false;rpc.badPointer=true;await assert.rejects(c.quote(rpc,artist,fixed),/selected facade/);
  assert.throws(()=>c.prepareArtistApproval({...p},authorization),/immutable observed plan/);
});

test("wrong networks, malformed/trailing ABI, reorg and mismatched preview scope fail terminally",async()=>{
  const c=make(),rpc=new RPC();rpc.chainId=1n;await assert.rejects(c.quote(rpc,artist,fixed),/chain/);rpc.chainId=chain;
  rpc.malformed="previewArtistPrimaryAssignmentForScope";await assert.rejects(c.quote(rpc,artist,fixed),/Noncanonical/);rpc.malformed=null;
  rpc.reorg=true;await assert.rejects(c.quote(rpc,artist,fixed),/block changed/);rpc.reorg=false;
  const base=rpc.call.bind(rpc);rpc.call=async tx=>{const parsed=tx.to===addresses.primary?abi.primary.parseTransaction({data:tx.data}):null;return parsed?.name==="previewArtistPrimaryAssignmentForScope"?abi.primary.encodeFunctionResult(parsed.name,[F("primary",1n,collection,id("wrong"))]):base(tx);};
  await assert.rejects(c.quote(rpc,artist,fixed),/coordinates/);
});

test("full-width integer and canonical zero semantics reject numeric coercion or scope widening",async()=>{
  const c=make(),rpc=new RPC();
  for(const bad of [{...fixed,scopeId:Number(token)},{...fixed,scope:0n,scopeId:0n},{...fixed,collectionId:0n},{...fixed,profileId:ZeroHash},{...zero,royaltyBps:1n},{...zero,profileId:profile},{...zero,royaltyBps:1001n,profileId:profile},{...fixed,payer:A(88)}])await assert.rejects(c.quote(rpc,artist,bad));
  const p=await c.quote(rpc,relayer,fixed);assert.throws(()=>c.prepareArtistApproval(p,authorization),/actual Artist caller/);
  assert.equal(c.prepareArtistApproval(p,{...authorization,signature:"0x1234"}).caller,relayer);
  assert.throws(()=>new CurrentRevenueClient(chain,addresses,{...fixture.abis,primary:[]}),/Selected compiled ABI/);
});

test("original digest readback rejects extra words and setup simulation rejects native value",async()=>{
  const c=make(),rpc=new RPC(),p=await c.quote(rpc,artist,zero),a=c.prepareArtistApproval(p,authorization);rpc.digest=a.payload.digest;
  await c.assertApprovalDigest(rpc,a,artist);rpc.malformed="economicsConsentDigest";await assert.rejects(c.assertApprovalDigest(rpc,a,artist),/digest differs/);
  await assert.rejects(c.simulate(rpc,{caller:artist,call:{...a.call,value:1n}}),/nonzero/);
});

test("fixture generator requires every selected compiler target and literal source preimage",()=>{
  assert.match(fixture.qualification,/no deployment/);assert.equal(Object.keys(fixture.abis).length,5);
  assert.throws(()=>revenueFixture(Buffer.from(JSON.stringify({language:"Solidity",sources:{}})),Buffer.from(JSON.stringify({contracts:{}}))),/Missing compiler/);
  assert.throws(()=>revenueFixture(Buffer.from(JSON.stringify({language:"Solidity"})),Buffer.from(JSON.stringify({errors:[{severity:"error"}]}))),/successful/);
});


test("template registration joins canonical hash, original owner simulation and every saved row",async()=>{
  const c=make(),rpc=new RPC(),entries=[{account:A(70),accountSource:ZeroHash,sharePpm:200000n,labelId:ZeroHash},{account:A(60),accountSource:ZeroHash,sharePpm:800000n,labelId:id("artist")}],metadata=id("template metadata");
  const ordered=[entries[1],entries[0]],entriesHash=keccak256(coder.encode(["tuple(address account,bytes32 accountSource,uint32 sharePpm,bytes32 labelId)[]"],[ordered]));
  const templateId=keccak256(coder.encode(["bytes32","uint256","address","uint16","uint16","bytes32","bytes32"],[id("6529STREAM_PRIMARY_TEMPLATE_V1"),chain,addresses.primary,1n,1n,entriesHash,metadata]));
  let installed=false,badRow=false,extraResult=false;const base=rpc.call.bind(rpc);
  rpc.call=async tx=>{
    const p=tx.to===addresses.primary?abi.primary.parseTransaction({data:tx.data}):null;
    if(p?.name==="createPrimaryTemplate"){assert.equal(tx.from,owner);return templateId+(extraResult?"00".repeat(32):"");}
    if(p?.name==="primaryTemplate")return abi.primary.encodeFunctionResult(p.name,[installed,entriesHash,metadata]);
    if(p?.name==="primaryTemplateEntryCount")return abi.primary.encodeFunctionResult(p.name,[2n]);
    if(p?.name==="primaryTemplateEntry"){const row=ordered[Number(p.args[1])];return abi.primary.encodeFunctionResult(p.name,[row.account,row.accountSource,badRow?1n:row.sharePpm,row.labelId]);}
    return base(tx);
  };
  const saved=await c.previewTemplateRegistration(rpc,owner,entries,metadata);assert.equal(saved.templateId,templateId);assert.equal(saved.entries[0].account,A(60));
  await assert.rejects(c.assertTemplateRegistered(rpc,saved,artist),/differs/);installed=true;await c.assertTemplateRegistered(rpc,saved,artist);
  badRow=true;await assert.rejects(c.assertTemplateRegistered(rpc,saved,artist),/row differs/);badRow=false;
  await assert.rejects(c.previewTemplateRegistration(rpc,relayer,entries,metadata),/current owner/);
  extraResult=true;await assert.rejects(c.previewTemplateRegistration(rpc,owner,entries,metadata),/template ID differs/);
  await assert.rejects(c.assertTemplateRegistered(rpc,{...saved},artist),/observed registration/);
});


test("runnable Artist Safe recipe retains exact retry call and verifies approval before owner installation",async()=>{
  const {prepareRevenueApproval,retryRevenueApproval,confirmRevenueApproval,confirmRevenueInstallation,revenueRecipeInput}=await import("../examples/current-revenue-safe.mjs");
  const c=make(),rpc=new RPC(),q=await c.quote(rpc,artist,zero),prepared=c.prepareArtistApproval(q,authorization);rpc.digest=prepared.payload.digest;
  const session=await prepareRevenueApproval(c,rpc,artist,zero,authorization);
  assert.deepEqual(session.artistSafeCall,toSafeCall(prepared.call));assert.equal(session.ownerSetup.caller,owner);
  let denied=true;const base=rpc.call.bind(rpc);
  rpc.call=async tx=>{if(denied&&tx.data===prepared.call.data)throw Error("Original current payout prerequisite unavailable");return base(tx);};
  await assert.rejects(retryRevenueApproval(c,rpc,session),/payout prerequisite/);denied=false;
  assert.deepEqual(await retryRevenueApproval(c,rpc,session),session.artistSafeCall);
  const safeEvents=new Interface(["event ExecutionSuccess(bytes32 txHash,uint256 payment)","event ExecutionFailure(bytes32 txHash,uint256 payment)"]),safeHash=id("independently selected Safe tx"),event=safeEvents.encodeEventLog(safeEvents.getEvent("ExecutionSuccess"),[safeHash,0n]);
  const receipt={status:1,logs:[{address:artist,...event}]};
  await assert.rejects(confirmRevenueApproval(c,rpc,session,receipt,artist,safeHash),/Missing exact current approval/);
  rpc.approved=true;assert.deepEqual(await confirmRevenueApproval(c,rpc,session,receipt,artist,safeHash),session.ownerSetup);
  await assert.rejects(confirmRevenueApproval(c,rpc,session,receipt,relayer,safeHash),/Safe differs/);
  await assert.rejects(confirmRevenueApproval(c,rpc,session,receipt,artist,id("wrong tx")),/matching Safe execution/);
  const failed=safeEvents.encodeEventLog(safeEvents.getEvent("ExecutionFailure"),[safeHash,0n]);
  await assert.rejects(confirmRevenueApproval(c,rpc,session,{status:1,logs:[{address:artist,...failed}]},artist,safeHash),/execution failed/);
  rpc.currentRoyalty=session.plan.fact.assignmentHash;await confirmRevenueInstallation(c,rpc,session);
  const input={chainId:String(chain),addresses,caller:artist,intent:{...zero,collectionId:String(collection),scope:"1",scopeId:String(collection),royaltyBps:"0"},authorization:{nonce:String(authorization.nonce),deadline:String(authorization.deadline),signature:"0x"}};
  assert.equal(revenueRecipeInput(input).intent.collectionId,collection);
  assert.throws(()=>revenueRecipeInput({...input,chainId:31337}),/decimal string/);
  assert.throws(()=>revenueRecipeInput({...input,intent:{...input.intent,scopeId:"01"}}),/decimal string/);
});

// The RPC below implements only getter/encoding boundaries, never a mined write.
const templateId=id('reviewed template'), factoryAddress=A(70), factoryAbi=new Interface(fixture.auxiliaryAbis.factory);
const templateContext={factory:factoryAddress,factoryCodeHash:codeHash,assetPolicy:A(71),walletRuntimeCodeHash:id('wallet runtime'),entriesHash:id('template entries'),metadataURIHash:ZeroHash,beneficiaryWitness:ZeroHash};
// Literal Solidity preimage, intentionally independent of the client helper.
function literalTemplateHash(scope,scopeId,frozen,context=templateContext){
  const h=(types,values)=>keccak256(coder.encode(types,values));
  const resolver=h(['bytes32','address','address','address','bytes32'],[id('6529STREAM_PRIMARY_ASSIGNMENT_RESOLVER_CONTEXT_V1'),addresses.primary,context.factory,context.assetPolicy,context.walletRuntimeCodeHash]);
  const scoped=h(['bytes32','bytes32','uint8','uint256','uint8'],[id('6529STREAM_PRIMARY_ASSIGNMENT_SCOPE_CONTEXT_V1'),PRIMARY,scope,scopeId,2n]);
  const template=h(['bytes32','bytes32','bytes32'],[id('6529STREAM_PRIMARY_ASSIGNMENT_TEMPLATE_CONTEXT_V1'),context.entriesHash,context.metadataURIHash]);
  const pointer=h(['bytes32','bytes32','bytes32','bytes32','bytes32'],[id('6529STREAM_PRIMARY_ASSIGNMENT_POINTER_CONTEXT_V1'),ZeroHash,ZeroHash,templateId,template]);
  return h(['bytes32','uint256','bytes32','bytes32','bytes32','bytes32','bool'],[id('6529STREAM_PRIMARY_ASSIGNMENT_V1'),chain,resolver,scoped,pointer,ZeroHash,frozen]);
}
class TemplateRPC extends RPC {
  exists=true; frozen=false; template=templateId; badPrevious=false; badNext=false; dynamic=false; witness=id('original beneficiaries'); factoryMalformed=false; correctedBinding=false;
  async call(tx){
    if(tx.to.toLowerCase()===factoryAddress.toLowerCase()){
      this.calls.push(tx);const p=factoryAbi.parseTransaction(tx);
      const result=factoryAbi.encodeFunctionResult(p.name,[p.name==='assetPolicyRegistry'?templateContext.assetPolicy:templateContext.walletRuntimeCodeHash]);
      return this.factoryMalformed?result+'00'.repeat(32):result;
    }
    if(tx.to.toLowerCase()===addresses.primary.toLowerCase()){
      const p=abi.primary.parseTransaction(tx),a=p.args;let result;
      if(this.correctedBinding && ['dynamicPrimaryTemplateFacts','previewArtistScopedPrimaryTemplateAssignment'].includes(p.name)) throw Error('Old collaborator source no longer matches corrected binding');
      if(p.name==='splitFactory') result=[factoryAddress];
      else if(p.name==='primaryTemplate')result=[true,templateContext.entriesHash,templateContext.metadataURIHash];
      else if(p.name==='isDynamicPrimaryTemplate')result=[this.dynamic];
      else if(p.name==='primaryTemplateConsentFacts')result=[templateContext.entriesHash,templateContext.metadataURIHash,1000000n];
      else if(p.name==='dynamicPrimaryTemplateFacts')result=[templateContext.entriesHash,templateContext.metadataURIHash,1000000n,this.witness];
      else if(p.name==='primaryEconomicsFacts')result=[{exists:this.exists,scope:a[1],scopeId:a[2],assignmentType:this.exists?2n:0n,profileId:ZeroHash,templateId:this.exists?this.template:ZeroHash,policyHash:ZeroHash,assignmentHash:this.exists?literalTemplateHash(a[1],a[2],this.frozen):ZeroHash,frozen:this.frozen}];
      else if(p.name==='previewArtistScopedPrimaryTemplateAssignment')result=[F('primary',a[1],a[2],this.badNext&&a[5]?id('bad frozen result'):literalTemplateHash(a[1],a[2],a[5]))];
      else if(p.name==='previewArtistPrimaryClear')result=[F('primary',a[1],a[2],ZeroHash),this.badPrevious?id('wrong previous'):literalTemplateHash(a[1],a[2],false)];
      if(result){this.calls.push(tx);return abi.primary.encodeFunctionResult(p.name,result);}
    }
    return super.call(tx);
  }
}
const mutation=(kind,scope=2n)=>({kind,collectionId:collection,scope,scopeId:scope===1n?collection:token,templateId});

test('exact TEMPLATE CLEAR binds previous key, signs zero and confirms absence rather than inherited precedence',async()=>{
  const c=make(),rpc=new TemplateRPC(),plan=await c.quote(rpc,artist,mutation('primary-template-clear'));
  assert.equal(plan.previousAssignmentHash,literalTemplateHash(2n,token,false));assert.equal(plan.fact.assignmentHash,ZeroHash);
  assert.equal(plan.templateHashContext.factory,factoryAddress);
  const approval=c.prepareArtistApproval(plan,authorization),parsed=abi.artist.parseTransaction(approval.call);
  assert.equal(parsed.name,'recordProspectiveEconomicsConsent');assert.deepEqual(Array.from(parsed.args[1]),[ZeroHash,ZeroHash,0n,false]);
  assert.equal(approval.payload.digest,messageHash(approval));assert.equal(parsed.args[0].scopeId,token);
  assert.equal(abi.primary.parseTransaction(plan.ownerCall.call).name,'clearPrimaryAssignment');
  assert.equal(toSafeCall(plan.ownerCall.call).value,'0');
  await assert.rejects(c.assertInstalled(rpc,plan,artist),/not cleared/);
  rpc.exists=false;await c.assertInstalled(rpc,plan,artist);
  await assert.rejects(c.assertFresh(rpc,plan,artist),/mutable exact/);
});

test('exact TEMPLATE FREEZE uses separate prospective selector and independently reconstructed flag',async()=>{
  const c=make(),rpc=new TemplateRPC(),plan=await c.quote(rpc,artist,mutation('primary-template-freeze',1n));
  assert.equal(plan.fact.assignmentHash,literalTemplateHash(1n,collection,true));
  assert.notEqual(plan.fact.assignmentHash,plan.previousAssignmentHash);
  assert.equal(primaryTemplateAssignmentHash(chain,addresses.primary,1n,collection,templateId,true,plan.templateHashContext),plan.fact.assignmentHash);
  const approval=c.prepareArtistApproval(plan,authorization),parsed=abi.artist.parseTransaction(approval.call);
  assert.equal(parsed.name,'recordProspectiveTemplateFreezeConsent');assert.equal(parsed.args[0].assignmentHash,plan.fact.assignmentHash);
  assert.equal(approval.payload.digest,messageHash(approval));assert.equal(abi.primary.parseTransaction(plan.ownerCall.call).name,'freezePrimaryAssignment');
  rpc.number++;await c.assertFresh(rpc,plan,artist);assert.equal(c.prepareArtistApproval(plan,authorization).call.data,approval.call.data);
  await assert.rejects(c.assertInstalled(rpc,plan,artist),/not frozen/);rpc.frozen=true;await c.assertInstalled(rpc,plan,artist);
});

test('exact mutation rejects default scope, inherited/missing/frozen/wrong-template keys and changed readbacks',async()=>{
  const c=make(),rpc=new TemplateRPC(),intent=mutation('primary-template-freeze');
  await assert.rejects(c.quote(rpc,artist,{...intent,scope:0n,scopeId:0n}),/collection\/token/);
  for(const [field,value] of [['exists',false],['frozen',true],['template',id('different template')]]){
    const r=new TemplateRPC();r[field]=value;await assert.rejects(c.quote(r,artist,intent),/mutable exact/);
  }
  rpc.badNext=true;await assert.rejects(c.quote(rpc,artist,intent),/Independent frozen/);rpc.badNext=false;
  rpc.badPrevious=true;await assert.rejects(c.quote(rpc,artist,mutation('primary-template-clear')),/exact previous/);rpc.badPrevious=false;
  rpc.factoryMalformed=true;await assert.rejects(c.quote(rpc,artist,intent),/Noncanonical template/);
});

test('dynamic beneficiary witness churn invalidates template freeze even if assignment hash is unchanged',async()=>{
  const c=make(),rpc=new TemplateRPC();rpc.dynamic=true;
  const plan=await c.quote(rpc,artist,mutation('primary-template-freeze'));
  rpc.witness=id('rotated collaborator payout');await assert.rejects(c.assertFresh(rpc,plan,artist),/proposal changed/);
});

test('CLEAR remains available when binding correction invalidates old dynamic template beneficiaries',async()=>{
  const c=make(),rpc=new TemplateRPC();rpc.dynamic=true;rpc.correctedBinding=true;
  const plan=await c.quote(rpc,artist,mutation('primary-template-clear'));
  assert.equal(plan.fact.assignmentHash,ZeroHash);assert.equal(plan.templateHashContext.beneficiaryWitness,ZeroHash);
  assert.equal(c.prepareArtistApproval(plan,authorization).method,'recordProspectiveEconomicsConsent');
  await assert.rejects(c.quote(rpc,artist,mutation('primary-template-freeze')),/corrected binding/);
});

test('accepted factory and freeze ABIs decode exact preparation; older catalogs fail closed',async()=>{
  const c=make(),rpc=new TemplateRPC(),p=await c.quote(rpc,artist,mutation('primary-template-freeze'));
  const auth=c.prepareArtistApproval(p,authorization);assert.equal(abi.artist.parseTransaction(auth.call).args[1].nonce,authorization.nonce);
  const bindings={...fixture.abis,artist:fixture.abis.artist.filter(x=>x.name!=='recordProspectiveTemplateFreezeConsent')};
  const old=new CurrentRevenueClient(chain,addresses,bindings),plan=await old.quote(rpc,artist,mutation('primary-template-freeze'));
  assert.throws(()=>old.prepareArtistApproval(plan,authorization),/Unknown|unknown|function/i);
});
