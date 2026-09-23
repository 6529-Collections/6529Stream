import test from "node:test";
import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import { execFileSync } from "node:child_process";
import { fileURLToPath } from "node:url";
import { AbiCoder, Interface, TypedDataEncoder, ZeroAddress, ZeroHash, concat, id, keccak256 } from "ethers";
import { CurrentSecondaryClient, toSafeCall } from "../dist/index.js";
import { secondaryFixture } from "../scripts/generate-current-secondary-fixture.mjs";
const fixture = JSON.parse(await readFile(new URL("./fixtures/current-secondary-abi.json", import.meta.url), "utf8"));
const inventoryAbi = new Interface(fixture.abis.inventory);
const iface = new Interface(fixture.abis.adapter), registryAbi = new Interface(fixture.abis.moduleRegistry), coder = AbiCoder.defaultAbiCoder();
const adapter = "0x0000000000000000000000000000000000006529", buyer = "0x0000000000000000000000000000000000000042";
const owner = "0x0000000000000000000000000000000000000007", delegate = "0x0000000000000000000000000000000000000008";
const core = "0x0000000000000000000000000000000000000009", moduleRegistry = "0x0000000000000000000000000000000000000010", delegateRegistry = "0x0000000000000000000000000000000000000011";
const client = () => new CurrentSecondaryClient(31337n, adapter, fixture.abis);
const saleId = id("inventory sale"), configHash = id("inventory config");
const proof = (authorizer, kind = 2n) => ({ authorizer, kind, signature: "0x1234" });
const witness = () => ({ walletWide: false, index: (1n << 200n) + 3n });
const config = () => ({ collectionId: 7n, consignor: owner, unitPrice: 1000n, startTime: 1n, deadline: (1n << 63n) + 1n,
  perBuyerCap: 2n, signerEvidenceHash: id("accepted signer evidence"), signerRevision: (1n << 63n) + 2n, signerAuthority: owner,
  secondaryConsignment: true, expectedPrimaryPolicyHash: ZeroHash });
const offer = () => ({ chainId: 31337n, saleAdapter: adapter, core, collectionId: 7n, tokenId: (1n << 255n) + 9n,
  contentSelectionHash: ZeroHash, buyer, asset: ZeroAddress, price: 1000n, nonce: id("offer nonce"), deadline: (1n << 63n) + 1n, finalizeBy: 0n });
function input(c = client()) {
  const o = offer(), payload = c.signing("SaleOffer", o).payload;
  return { authorization: c.authorizationForOffer(o, saleId, id("sale nonce"), o.deadline), sellerProof: proof(owner), offer: o,
    offerProof: proof(delegate), ownerGrant: { chainId: 31337n, saleAdapter: adapter, core, tokenId: o.tokenId, owner,
      saleRef: payload.digest, nonce: id("grant nonce"), deadline: o.deadline }, ownerKind: 2n, ownerSignature: "0xabcd", value: 1007n };
}
function assertCall(prepared, method, args, caller, value = 0n) {
  assert.equal(prepared.caller, caller); assert.equal(prepared.call.data, iface.encodeFunctionData(method, args));
  assert.equal(prepared.call.to, adapter); assert.equal(prepared.call.value, value);
  assert.deepEqual(toSafeCall(prepared.call), { to: adapter, value: value.toString(), data: prepared.call.data, operation: 0 });
}

test("three original Sales families match independent compiler-source preimages at full widths", () => {
  const c = client(), i = input(c), messages = { SaleAuthorization: i.authorization, SaleOffer: i.offer, SaleCustodyGrant: i.ownerGrant };
  for (const [kind, message] of Object.entries(messages)) {
    const request = c.signing(kind, message), preimage = fixture.types[kind];
    const fields = preimage.slice(preimage.indexOf("(") + 1, -1).split(",").map(x => x.split(" "));
    const body = keccak256(coder.encode(["bytes32", ...fields.map(x => x[0])], [id(preimage), ...fields.map(x => message[x[1]])]));
    const domain = keccak256(coder.encode(["bytes32", "bytes32", "bytes32", "uint256", "address"], [id("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"), id(fixture.domain), id(fixture.version), 31337n, adapter]));
    assert.equal(request.payload.digest, keccak256(concat(["0x1901", domain, body])));
    assert.equal(TypedDataEncoder.from(request.payload.types).encodeType(kind), preimage);
    assert.equal(request.digestCall.data, iface.encodeFunctionData(request.digestMethod, [message]));
    const json = { kind, message: Object.fromEntries(Object.entries(message).map(([k,v]) => [k, typeof v === "bigint" ? v.toString() : v])) };
    assert.equal(c.signingFromJSON(json).payload.digest, request.payload.digest);
    for (const [type, field] of fields.filter(x => x[0].startsWith("uint"))) {
      for (const bad of [1, "01", "-1", (1n << BigInt(type.slice(4))).toString()]) assert.throws(() => c.signingFromJSON({ ...json, message: { ...json.message, [field]: bad } }));
    }
    assert.throws(() => c.signing(kind, { ...message, chainId: 1n }), /chain/);
    assert.throws(() => c.signing(kind, { ...message, saleAdapter: owner }), /adapter/);
    assert(Object.isFrozen(request.payload.message));
  }
});

test("inventory registration, grants and purchase preserve compiled tuples, exact IDs and Safe value", () => {
  const c = client(), cfg = config(), ids = [1n, (1n << 255n) + 9n];
  assertCall(c.registerInventory(owner, cfg, ids), "registerInventory", [cfg, ids], owner);
  const grant = { ...input(c).ownerGrant, saleRef: saleId };
  assertCall(c.depositInventory(owner, saleId, grant, 2n, "0x"), "depositInventoryCustody", [saleId, grant, 2n, "0x"], owner);
  assertCall(c.openInventory(owner, saleId), "openInventory", [saleId], owner);
  const price = (1n << 200n) + 3n, value = price + 77n;
  assertCall(c.purchaseInventory(buyer, saleId, ids[1], configHash, price, value), "purchaseInventory", [saleId, ids[1], configHash], buyer, value);
  assertCall(c.closeInventory(owner, saleId, "cancel"), "cancelSale", [saleId], owner);
  assertCall(c.closeInventory(delegate, saleId, "expire"), "expireSale", [saleId], delegate);
  for (const bad of [[], [1n, 1n], [2n, 1n], [0n], [1], Array.from({length:65}, (_,i) => BigInt(i+1))]) assert.throws(() => c.registerInventory(owner, cfg, bad));
  for (const mutation of [{ secondaryConsignment: false }, { expectedPrimaryPolicyHash: id("primary") }, { unitPrice: 0n }, { startTime: cfg.deadline }, { perBuyerCap: 1 }, { perBuyerCap: 1n << 32n }]) assert.throws(() => c.registerInventory(owner, {...cfg,...mutation}, ids));
  assert.throws(() => c.depositInventory(owner, saleId, input(c).ownerGrant, 2n, "0x"), /exact sale/);
  for (const bad of [1, -1n, 1n << 256n, price - 1n]) assert.throws(() => c.purchaseInventory(buyer, saleId, 1n, configHash, price, bad));
});

test("delegated claim destinations are fixed accounts while original claims remain independent", () => {
  const c = client(), w = witness();
  assertCall(c.claimRefundFor(delegate, saleId, buyer, w), "claimRefundFor", [saleId,buyer,w], delegate);
  assertCall(c.claimNftFor(delegate, saleId, buyer, w), "claimNftFor", [saleId,buyer,w], delegate);
  assertCall(c.claimInventoryNftFor(delegate, saleId, 9n, buyer, w), "claimInventoryNftFor", [saleId,9n,buyer,w], delegate);
  assertCall(c.claimRefund(buyer, saleId, owner), "claimRefund", [saleId,owner], buyer);
  assertCall(c.claimNft(buyer, saleId, owner), "claimNft", [saleId,owner], buyer);
  assertCall(c.claimInventoryNft(buyer, saleId, 9n, owner), "claimInventoryNft", [saleId,9n,owner], buyer);
  assertCall(c.retryInventoryNft(delegate, saleId, 9n), "retryInventoryNft", [saleId,9n], delegate);
  assertCall(c.retryInventoryRoyalty(delegate, saleId, owner), "retryInventoryRoyalty", [saleId,owner], delegate);
  for (const bad of [{...w,receiver:delegate}, {...w,walletWide:1}, {...w,index:1}, {...w,index:-1n}]) assert.throws(() => c.claimNftFor(delegate,saleId,buyer,bad));
  assert.throws(() => c.claimNftFor(buyer,saleId,buyer,w), /own-account/);
  assert.throws(() => c.claimInventoryNftFor(delegate,saleId,9n,adapter,w), /own claim/);
});

test("maker and delegate offers share original fields but preserve explicit signer and principal CALL", () => {
  const c = client(), i = input(c), w = witness();
  assertCall(c.acceptOffer(buyer,i,{mode:"delegate",witness:w}), "acceptDelegatedOffer",
    [i.authorization,i.sellerProof,i.offer,i.offerProof,i.ownerGrant,i.ownerKind,i.ownerSignature,w], buyer, i.value);
  const direct = {...i,offerProof:proof(buyer)};
  assertCall(c.acceptOffer(buyer,direct,{mode:"maker"}), "acceptOffer",
    [direct.authorization,direct.sellerProof,direct.offer,direct.offerProof,direct.ownerGrant,direct.ownerKind,direct.ownerSignature], buyer, direct.value);
  assert.throws(() => c.acceptOffer(delegate,i,{mode:"delegate",witness:w}), /principal/);
  assert.throws(() => c.acceptOffer(buyer,i,{mode:"maker"}), /Signer/);
  assert.throws(() => c.acceptOffer(buyer,direct,{mode:"delegate",witness:w}), /Signer/);
  assert.throws(() => c.acceptOffer(buyer,i,{mode:"maker",witness:w}));
  for (const mutation of [{ownerGrant:{...i.ownerGrant,saleRef:saleId}}, {authorization:{...i.authorization,payer:delegate}},
    {authorization:{...i.authorization,executor:delegate}}, {authorization:{...i.authorization,mintManager:core}},
    {authorization:{...i.authorization,quantity:2n}}, {value:999n}, {offerProof:{...i.offerProof,kind:0n}}]) assert.throws(() => c.acceptOffer(buyer,{...i,...mutation},{mode:"delegate",witness:w}));
  const prepared = c.acceptOffer(buyer,i,{mode:"delegate",witness:w}); i.offerProof.signature="0x00"; w.index=0n;
  assert.notEqual(prepared.call.data, c.acceptOffer(buyer,i,{mode:"delegate",witness:w}).call.data); assert(Object.isFrozen(prepared.call));
});

test("digest readback and simulation use exact host, chain, principal and value", async () => {
  const c=client(), i=input(c), request=c.signing("SaleOffer",i.offer); let calls=0;
  const provider={getNetwork:async()=>({chainId:31337n}),call:async tx=>{calls++;assert.equal(tx.to,adapter);assert.equal(tx.blockTag,77);return iface.encodeFunctionResult(request.digestMethod,[request.payload.digest]);}};
  await c.assertDigest(provider,request,77); assert.equal(calls,1);
  await assert.rejects(c.assertDigest({...provider,getNetwork:async()=>({chainId:1n})},request,77),/chain/);assert.equal(calls,1);
  await assert.rejects(c.assertDigest({...provider,call:async()=>iface.encodeFunctionResult(request.digestMethod,[ZeroHash])},request),/differs/);
  const prepared=c.acceptOffer(buyer,i,{mode:"delegate",witness:witness()});
  assert.equal(await c.simulate({...provider,call:async tx=>{assert.equal(tx.from,buyer);assert.equal(tx.value,1007n);assert.equal(tx.data,prepared.call.data);return "0x";}},prepared),"0x");
});

function delegationRPC() {
  const code="0x60016000", codeHash=keccak256(code);
  const pins={core,adapterCodeHash:codeHash,moduleRegistry,moduleRegistryCodeHash:codeHash,delegateRegistry,delegateRegistryCodeHash:codeHash,usecase:77n,baseManifestHash:id("original base")};
  const manifest=coder.encode(["bytes32","uint256","address","bytes32","address","address","bytes32","uint256"],
    [id("6529STREAM_NATIVE_AUCTION_NFTDELEGATION_MANIFEST_V1"),31337n,adapter,pins.baseManifestHash,core,delegateRegistry,codeHash,77n]);
  const state={row:[BigInt(buyer),BigInt(delegate),900n,1100n,1n,0n],raw:undefined,status:1n,manifest,code,key:undefined,reads:0,blockHash:id("block 7")};
  const record=()=>[state.status,id("PRIVATE_SALE_ADAPTER"),id("version"),"0x12345678",500000n,codeHash,id("deployment"),keccak256(manifest),"urn:fixture",900n,900n,1n];
  const values={core,moduleRegistry,registryCodeHash:codeHash,delegateRegistry,delegateRegistryCodeHash:codeHash,delegationUsecase:77n};
  const provider={getNetwork:async()=>({chainId:31337n}),getBlock:async()=>({number:7,timestamp:1000,hash:state.blockHash}),getCode:async(_,block)=>{assert.equal(block,7);return state.code;},
    call:async tx=>{assert.equal(tx.blockTag,7);state.reads++;
      if(tx.to===moduleRegistry)return registryAbi.encodeFunctionResult("moduleRecord",[record()]);
      if(tx.to===delegateRegistry){const [key,index]=coder.decode(["bytes32","uint256"],"0x"+tx.data.slice(10));state.key=key;assert.equal(index,witness().index);return state.raw??coder.encode(Array(6).fill("uint256"),state.row);}
      const name=iface.parseTransaction(tx).name;return iface.encodeFunctionResult(name,[name==="delegationManifest"?state.manifest:values[name]]);}};
  return {pins,state,provider,manifest};
}
test("delegation observation binds exact manifest/code and full retained row at one block", async () => {
  const c=client(), {pins,state,provider}=delegationRPC();
  for(const walletWide of [false,true]) {
    const observed=await c.observeDelegation(provider,pins,buyer,delegate,{...witness(),walletWide},"offer");
    assert.equal(observed.blockNumber,7);assert.equal(observed.expiryDate,1100n);
    const scope=walletWide?"0x8888888888888888888888888888888888888888":core;
    const packed=concat([buyer,scope,delegate,coder.encode(["uint256"],[pins.usecase])]);
    assert.equal(state.key,keccak256(packed));assert.equal(observed.scope,scope);assert(Object.isFrozen(observed));
  }
});
test("revoked, expired, partial, malformed, mismatched or missing delegation fails terminally", async () => {
  const c=client();
  for(const mutation of [s=>s.row[0]=BigInt(owner),s=>s.row[1]=BigInt(owner),s=>s.row[2]=1001n,s=>s.row[3]=1000n,
    s=>s.row[4]=0n,s=>s.row[5]=1n,s=>s.raw="0x",s=>s.raw="0x"+"00".repeat(193),s=>s.code="0x",s=>s.manifest="0x",s=>s.status=2n]) {
    const {pins,state,provider}=delegationRPC();mutation(state);await assert.rejects(c.observeDelegation(provider,pins,buyer,delegate,witness(),"offer"));
  }
  const {pins,provider}=delegationRPC();
  await assert.rejects(c.observeDelegation({...provider,call:async()=>{throw Error("unavailable");}},pins,buyer,delegate,witness(),"offer"),/unavailable/);
  for(const usecase of [0n,998n,999n,1]) await assert.rejects(c.observeDelegation(provider,{...pins,usecase},buyer,delegate,witness(),"offer"));
  let blocks=0;await assert.rejects(c.observeDelegation({...provider,getBlock:async()=>({number:7,timestamp:1000,hash:++blocks===1?id("first"):id("changed")})},pins,buyer,delegate,witness(),"offer"),/block changed/);
});
test("earned delegated claims skip active-module admission and originals need no live registry", async () => {
  const c=client(), {pins,state,provider}=delegationRPC();state.status=3n;
  const wrapped={...provider,call:async tx=>{assert.notEqual(tx.to,moduleRegistry,"claims do not re-admit module");return provider.call(tx);}};
  assert.equal((await c.observeDelegation(wrapped,pins,buyer,delegate,witness(),"claim")).purpose,"claim");
  state.row[3]=1000n;await assert.rejects(c.observeDelegation(wrapped,pins,buyer,delegate,witness(),"claim"));
  assert.equal(c.claimRefund(buyer,saleId,owner).caller,buyer);
  assert.equal(c.claimInventoryNft(buyer,saleId,9n,owner).caller,buyer);
});

test("inventory reads and receipt extraction preserve real token/config coordinates and reject foreign logs", async () => {
  const c=client(), cfg=config(), ids=[9n,(1n<<200n)+1n], invHash=keccak256(coder.encode(["uint256[]"],[ids]));
  const inventory=[cfg,configHash,invHash,1n,5n,1n,2n,ids];
  const provider={getNetwork:async()=>({chainId:31337n}),call:async tx=>{assert.equal(tx.blockTag,7);const method=iface.parseTransaction(tx).name;
    return method==="inventoryDetails"?iface.encodeFunctionResult(method,[inventory]):iface.encodeFunctionResult(method,[owner,70n,true,true]);}};
  const got=await c.readInventory(provider,saleId,7);assert.equal(got.config.unitPrice,1000n);assert.deepEqual(got.tokenIds,ids);assert(Object.isFrozen(got.config));
  const q=await c.readInventoryRoyalty(provider,saleId,9n,7);assert.equal(q.amount,70n);assert.equal(q.externalRoyaltiesDisclosureOnly,true);
  const encoded=inventoryAbi.encodeEventLog(inventoryAbi.getEvent("InventoryConfigured"),[1n,saleId,invHash,owner,configHash,ids]);
  const log={address:adapter,...encoded}, receipt={status:1,logs:[{...log,address:owner},log]};
  assert.deepEqual(c.inventoryRegistration(receipt),{saleId,configHash,inventoryHash:invHash,consignor:owner,tokenIds:ids});
  for(const bad of [{status:0,logs:[log]},{status:1,logs:[{...log,address:owner}]},{status:1,logs:[log,log]}])assert.throws(()=>c.inventoryRegistration(bad));
});

test("selected ABIs must match original signing tuples and actual new entrypoints", () => {
  const bad=structuredClone(fixture.abis);bad.adapter.find(x=>x.name==="offerDigest").inputs[0].components[0].type="uint64";
  assert.throws(()=>new CurrentSecondaryClient(31337n,adapter,bad),/original Sales/);
  const absent={...fixture.abis,adapter:fixture.abis.adapter.filter(x=>x.name!=="claimNftFor")};
  assert.throws(()=>new CurrentSecondaryClient(31337n,adapter,absent).claimNftFor(delegate,saleId,buyer,witness()),/lacks/);
  for(const chain of [0n,1,-1n,1n<<256n])assert.throws(()=>new CurrentSecondaryClient(chain,adapter,fixture.abis));
});
test("fixture generator rejects errors, absent source or absent selected compiler ABI", () => {
  assert.throws(()=>secondaryFixture(Buffer.from('{"language":"Solidity"}'),Buffer.from('{"errors":[{"severity":"error"}]}')));
  assert.throws(()=>secondaryFixture(Buffer.from('{"language":"Solidity","sources":{}}'),Buffer.from('{"contracts":{}}')));
});
test("new compile-time examples enforce bigint and explicit offer mode", () => {
  execFileSync(process.execPath,[fileURLToPath(new URL("../node_modules/typescript/bin/tsc",import.meta.url)),"--noEmit","--strict","--skipLibCheck","--target","ES2022","--module","NodeNext","--moduleResolution","NodeNext",fileURLToPath(new URL("./current-secondary-types.ts",import.meta.url))],{stdio:"pipe"});
});


test("client identity and observation pins cannot change across asynchronous reads", async () => {
  const c=client(), {pins,provider}=delegationRPC(), w=witness();
  assert.throws(()=>{c.chainId=1n;}); assert.throws(()=>{c.adapter=owner;});
  const changing={...provider,getNetwork:async()=>{pins.usecase=999n;w.index=0n;return {chainId:31337n};}};
  const result=await c.observeDelegation(changing,pins,buyer,delegate,w,"claim");
  assert.equal(result.witness.index,(1n<<200n)+3n);assert.equal(result.expiryDate,1100n);
});

test("read-only examples preserve explicit caller and simulate only exact prepared CALLs", async () => {
  const examples=await import("../examples/current-secondary.mjs");
  const c=examples.secondaryClient(31337n,adapter,fixture.abis), cfg=config();
  const listing=examples.prepareInventoryListing(c,owner,cfg,[9n]);
  assert.equal(listing.caller,owner);assert.equal(listing.safeCall.operation,0);
  assert.equal(listing.safeCall.data,iface.encodeFunctionData("registerInventory",[cfg,[9n]]));
  const {pins,provider}=delegationRPC(), i=input(c);let executions=0;
  const combined={...provider,call:async tx=>{
    if(tx.to===adapter){const parsed=iface.parseTransaction(tx);
      const kinds={authorizationDigest:"SaleAuthorization",offerDigest:"SaleOffer",custodyGrantDigest:"SaleCustodyGrant"};
      if(kinds[parsed.name])return iface.encodeFunctionResult(parsed.name,[c.signing(kinds[parsed.name],parsed.args[0].toObject()).payload.digest]);
      if(parsed.name==="acceptDelegatedOffer" || parsed.name==="claimInventoryNftFor"){
        executions++;assert.equal(tx.from,parsed.name==="acceptDelegatedOffer"?buyer:delegate);return "0x";
      }
    }return provider.call(tx);}};
  const reviewed=await examples.reviewDelegatedOffer(c,combined,buyer,i,witness(),pins,7);
  assert.equal(reviewed.caller,buyer);assert.equal(reviewed.safeCall.value,"1007");
  const claim=await examples.reviewInventoryClaim(c,combined,delegate,buyer,saleId,9n,witness(),pins,7);
  assert.equal(claim.caller,delegate);assert.equal(claim.safeCall.value,"0");assert.equal(executions,2);
});
