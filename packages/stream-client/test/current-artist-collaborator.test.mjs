import assert from "node:assert/strict";
import { createHash } from "node:crypto";
import { readFileSync } from "node:fs";
import test from "node:test";
import { AbiCoder, Interface, ParamType, ZeroAddress, ZeroHash, concat, getAddress, id, keccak256 } from "ethers";
import * as client from "../dist/current-artist-collaborator.js";
import { createSafeCallPlan, verifySafeCallPlan } from "../dist/safe-plan.js";
import { fixture, compiledInterfaces, compiledABI } from "./current-artist-recovered-multiple-attestation-hydration-source-fixture.mjs";

const coder = AbiCoder.defaultAbiCoder();
const registryABI = compiledInterfaces.registry;
const codecABI = new Interface(client.CURRENT_ARTIST_COLLABORATOR_ABI);
const A = n => getAddress(`0x${BigInt(n).toString(16).padStart(40, "0")}`);
const H = n => `0x${BigInt(n).toString(16).padStart(64, "0")}`;
const U256 = (1n << 256n) - 1n, U64 = (1n << 64n) - 1n;
const context = { chainId: 31337n, registry: A(100), caller: A(10) };
const core = A(101), document = "0x1234abcd", documentHash = keccak256(document);
const proposal = { account: A(10), identityRecordHash: documentHash, identityRecordURI: "ipfs://identity", reasonHash: H(2), reasonURI: "ipfs://reason" };
const authorization = { nonce: 9n, time: 2000000000n, signature: "0x1234" };
const terms = { collectionId: 7n, generation: 3n, bindingHash: H(3), account: A(10), role: H(4), shareLabelId: H(5) };
const rows = [{ account: A(10), role: ZeroHash, shareLabelId: ZeroHash }, { account: A(10), role: H(4), shareLabelId: H(5) }, { account: A(11), role: ZeroHash, shareLabelId: H(6) }];
const binding = { artistId: H(20), artistAddress: A(21), identityRecordHash: H(22), bindingHash: ZeroHash, generation: 3n, consentMode: 1n, saleConsentScope: 0n, registryImmutabilityElection: 1n, proposer: A(23), accepted: false };
const requests = () => [
  { ...context, kind: "proposeIdentity", proposal: { ...proposal } },
  { ...context, kind: "acceptIdentity", account: proposal.account, identityRecordHash: documentHash, authorization: { ...authorization }, document, displayName: "Collaborator" },
  { ...context, kind: "acceptRow", core, terms: { ...terms }, authorization: { ...authorization } },
];
const source = name => fixture.sourceTexts[`smart-contracts/domains/artist/${name}.sol`];
const hashesSource = source("StreamArtistCollaboratorHashes"), baseHashesSource = source("StreamArtistHashes");
function domain(text, literal) {
  assert.ok(text.includes(`keccak256("${literal}")`), `missing source domain ${literal}`);
  return id(literal);
}
function shape(p, named = true) {
  return { ...(named ? { name: p.name } : {}), type: p.format("sighash"),
    ...(p.components ? { components: p.components.map(c => shape(c)) } : {}),
    ...(p.arrayChildren ? { element: shape(p.arrayChildren) } : {}) };
}
const proposalType = registryABI.getFunction("proposeCollaboratorIdentity").inputs[0];
const termType = compiledInterfaces.binding.getFunction("collaboratorTerm").outputs[0];
function sourceSetHash(values) {
  return keccak256(coder.encode(["bytes32", `${termType.format("full")}[]`], [domain(hashesSource, "6529STREAM_ARTIST_COLLABORATOR_SET_V1"), values]));
}
function sourceTypedHash(typeName, values, ctx = context) {
  // The schemas come from captured Solidity literals, not the client's signing table.
  const declaration = hashesSource.match(new RegExp(`"(${typeName}\\([^"\\n]+\\))"`))?.[1];
  assert.ok(declaration);
  const fields = declaration.slice(declaration.indexOf("(") + 1, -1).split(",").map(field => field.split(" "));
  const structHash = keccak256(coder.encode(["bytes32", ...fields.map(([type]) => type)], [id(declaration), ...fields.map(([, name]) => values[name])]));
  const domainDeclaration = baseHashesSource.match(/"(EIP712Domain\([^"]+\))"/)?.[1];
  assert.equal(domainDeclaration, "EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)");
  const separator = keccak256(coder.encode(["bytes32", "bytes32", "bytes32", "uint256", "address"], [id(domainDeclaration), domain(baseHashesSource, "6529StreamArtistRegistry"), domain(baseHashesSource, "1"), ctx.chainId, ctx.registry]));
  return keccak256(concat(["0x1901", separator, structHash]));
}
function withWord(raw, index, value) {
  return raw.slice(0, 2 + index * 64) + BigInt(value).toString(16).padStart(64, "0") + raw.slice(2 + (index + 1) * 64);
}

test("full original compiler fixture and relevant Solidity texts remain pinned", () => {
  const raw = readFileSync(new URL("./fixtures/current-artist-recovered-multiple-attestation-hydration-abi.json", import.meta.url));
  assert.equal(createHash("sha256").update(raw).digest("hex"), "2cd33a780cfd61c9d338a917ce029596b2b0a9c62542e7ab1b502a29ea19c6e9");
  assert.equal(client.COLLABORATOR_FIXTURE_SHA256, "2cd33a780cfd61c9d338a917ce029596b2b0a9c62542e7ab1b502a29ea19c6e9");
  assert.equal(fixture.sourceCommit, "bd4a291e9e159cbbb5079a9a2a418fb151a8c01b");
  assert.equal(client.COLLABORATOR_SOURCE, fixture.sourceCommit);
  assert.equal(client.COLLABORATOR_INTEGRATION, "4fd8017505c979da6d8545900b8d6cf5b42003fa");
  for (const name of ["StreamArtistCollaboratorHashes", "StreamArtistHashes", "StreamArtistBindingLifecycle", "StreamArtistCollaboratorOperations", "StreamArtistCollaboratorIdentityState"]) {
    const path = `smart-contracts/domains/artist/${name}.sol`;
    assert.equal(createHash("sha256").update(fixture.sourceTexts[path], "utf8").digest("hex"), fixture.sourceHashes[path], path);
  }
});

test("all ten ordinary functions retain compiler selectors, mutability, value types and nested names", () => {
  const functions = codecABI.fragments.filter(f => f.type === "function");
  assert.equal(functions.length, 10);
  for (const actual of functions) {
    const expected = registryABI.getFunction(actual.name);
    assert.equal(actual.selector, `0x${fixture.methodIdentifiers.StreamArtistOnboardingRegistry[expected.format("sighash")]}`);
    assert.equal(actual.stateMutability, expected.stateMutability);
    // Top-level tuple argument names are ergonomic aliases; all nested names are exact.
    assert.deepEqual(actual.inputs.map(p => shape(p, false)), expected.inputs.map(p => shape(p, false)), actual.name);
    assert.deepEqual(actual.outputs.map(p => shape(p, false)), expected.outputs.map(p => shape(p, false)), actual.name);
  }
  // The compiler facade leaves these top-level outputs unnamed; the client adds result labels.
  assert.deepEqual(codecABI.getFunction("collaboratorPayoutAccount").outputs.map(p => p.name), ["payoutAccount", "designationRecordHash"]);
  assert.deepEqual(codecABI.getFunction("collaboratorRegistrationNonceState").outputs.map(p => p.name), ["used", "firstUnused"]);
});

test("all exported tuples match independently compiled nested ABI fields", () => {
  const witnesses = [
    [client.COLLABORATOR_PROPOSAL_TUPLE, proposalType],
    [client.COLLABORATOR_PROPOSAL_STATE_TUPLE, registryABI.getFunction("collaboratorIdentityProposal").outputs[0]],
    [client.COLLABORATOR_AUTHORIZATION_TUPLE, registryABI.getFunction("acceptCollaborator").inputs[1]],
    [client.COLLABORATOR_TERM_TUPLE, termType],
    [client.COLLABORATOR_ACCEPTANCE_TUPLE, registryABI.getFunction("acceptCollaborator").inputs[0]],
    [client.COLLABORATOR_ROW_TUPLE, registryABI.getFunction("collaboratorAt").outputs[0]],
    [client.COLLABORATOR_BINDING_TERMS_TUPLE, compiledInterfaces.binding.getFunction("bindingTerms").outputs[0]],
    [client.COLLABORATOR_BINDING_TUPLE, compiledInterfaces.binding.getFunction("binding").outputs[0]],
  ];
  for (const [tuple, expected] of witnesses) assert.deepEqual(shape(ParamType.from(tuple), false), shape(expected, false));
});

test("proposal event topic, indexing and data match the actual Collaborator owner event", () => {
  const expected = compiledInterfaces.collaborator.getEvent("CollaboratorIdentityProposed");
  const actual = codecABI.getEvent("CollaboratorIdentityProposed");
  assert.equal(actual.topicHash, expected.topicHash);
  assert.deepEqual(actual.inputs.map(p => [p.name, p.type, Boolean(p.indexed)]), expected.inputs.map(p => [p.name, p.type, Boolean(p.indexed)]));
  const values = [1, proposal.account, documentHash, proposal.identityRecordURI, context.caller, proposal.reasonHash, proposal.reasonURI];
  assert.deepEqual(codecABI.encodeEventLog(actual, values), compiledInterfaces.collaborator.encodeEventLog(expected, values));
  assert.equal(registryABI.getEvent("CollaboratorIdentityProposed"), null, "event owner is not misrepresented as the facade");
});

test("operations 5, 6 and 7 produce exact compiler-derived CALLs and digest reads", () => {
  const [p, i, r] = requests().map(client.prepareCollaboratorCall);
  for (const [prepared, operation, method, args] of [
    [p, 5, "proposeCollaboratorIdentity", [proposal]],
    [i, 6, "acceptCollaboratorIdentity", [proposal.account, documentHash, authorization, document, "Collaborator"]],
    [r, 7, "acceptCollaborator", [terms, authorization]],
  ]) {
    assert.equal(prepared.operation, operation);
    assert.equal(prepared.factsVerified, false);
    assert.deepEqual(prepared.call, { to: context.registry, value: 0n, data: registryABI.encodeFunctionData(method, args) });
  }
  assert.equal(p.signing, null);
  const unsigned = { ...authorization, signature: "0x" };
  assert.equal(i.signing.digestCall.data, registryABI.encodeFunctionData("collaboratorIdentityDigest", [proposal.account, documentHash, unsigned]));
  assert.equal(r.signing.digestCall.data, registryABI.encodeFunctionData("collaboratorAcceptanceDigest", [terms, unsigned]));
  assert.equal(r.signing.payload.message.core, core, "core is signed even though the CALL tuple excludes it");
});

test("identity and row signatures reproduce permanent Solidity EIP-712 preimages", () => {
  const [, identityRequest, rowRequest] = requests();
  for (const request of [identityRequest, rowRequest]) {
    const prepared = client.prepareCollaboratorCall(request);
    const name = request.kind === "acceptIdentity" ? "StreamCollaboratorIdentityAcceptance" : "StreamCollaboratorAcceptance";
    const values = request.kind === "acceptIdentity"
      ? { account: request.account, identityRecordHash: documentHash, nonce: authorization.nonce, deadline: authorization.time }
      : { core, collectionId: terms.collectionId, bindingGeneration: terms.generation, bindingHash: terms.bindingHash, collaborator: terms.account, role: terms.role, shareLabelId: terms.shareLabelId, nonce: authorization.nonce, deadline: authorization.time };
    assert.equal(prepared.signing.payload.primaryType, name);
    assert.equal(prepared.signing.payload.digest, sourceTypedHash(name, values));
    for (const change of [{ chainId: context.chainId + 1n }, { registry: A(102) }]) {
      assert.notEqual(client.prepareCollaboratorCall({ ...request, ...change }).signing.payload.digest, prepared.signing.payload.digest);
    }
    // Opaque proof bytes are transport, not part of the permanent typed preimage.
    assert.equal(client.prepareCollaboratorCall({ ...request, authorization: { ...authorization, signature: "0xff" } }).signing.payload.digest, prepared.signing.payload.digest);
    for (const field of ["nonce", "time"]) assert.notEqual(client.prepareCollaboratorCall({ ...request, authorization: { ...authorization, [field]: authorization[field] + 1n } }).signing.payload.digest, prepared.signing.payload.digest);
  }
  const original = client.prepareCollaboratorCall(rowRequest).signing.payload.digest;
  for (const key of ["role", "shareLabelId", "bindingHash"]) assert.notEqual(client.prepareCollaboratorCall({ ...rowRequest, terms: { ...terms, [key]: H(90) } }).signing.payload.digest, original);
  assert.notEqual(client.prepareCollaboratorCall({ ...rowRequest, core: A(102) }).signing.payload.digest, original);
});

test("proposal hash and identity ID use their distinct original source preimages and nonce domains", () => {
  const expectedProposal = keccak256(coder.encode(["bytes32", "uint256", "address", proposalType, "address"], [domain(hashesSource, "6529STREAM_COLLABORATOR_IDENTITY_PROPOSAL_V1"), context.chainId, context.registry, proposal, context.caller]));
  assert.equal(client.collaboratorProposalHash(context.chainId, context.registry, proposal, context.caller), expectedProposal);
  assert.notEqual(client.collaboratorProposalHash(context.chainId, context.registry, { ...proposal, reasonURI: "changed" }, context.caller), expectedProposal);
  assert.notEqual(client.collaboratorProposalHash(context.chainId, context.registry, proposal, A(11)), expectedProposal);
  for (const allocationNonce of [0n, 100n, U256]) {
    const expected = keccak256(coder.encode(["bytes32", "uint256", "address", "address", "bytes32", "uint256"], [domain(baseHashesSource, "6529STREAM_ARTIST_ID_V1"), context.chainId, context.registry, proposal.account, documentHash, allocationNonce]));
    assert.equal(client.collaboratorIdentityId(context.chainId, context.registry, proposal.account, documentHash, allocationNonce), expected);
  }
  assert.notEqual(client.collaboratorIdentityId(context.chainId, context.registry, proposal.account, documentHash, 100n), client.collaboratorIdentityId(context.chainId, context.registry, proposal.account, documentHash, authorization.nonce));
  assert.match(source("StreamArtistCollaboratorIdentityState"), /proof\.direct && a\.nonce != hint/);
  assert.match(source("StreamArtistCollaboratorIdentityState"), /identity_authority\.replay\.collaborator_account_nonce/);
  // This pure codec never claims that either nonce is unused or that the caller is authorized.
  assert.equal(client.prepareCollaboratorCall({ ...requests()[1], caller: A(99), authorization: { ...authorization, signature: "0x" } }).factsVerified, false);
});

test("acceptance record binds the collaborator principal class and observed time, not role lookup fields", () => {
  for (const authority of [1n, 3n, 4n]) {
    const expected = keccak256(coder.encode(["bytes32", "uint256", "address", "address", "uint256", "uint64", "bytes32", "uint8", "address", "uint8", "uint256", "uint64"], [domain(hashesSource, "6529STREAM_ARTIST_ACCEPTANCE_RECORD_V1"), context.chainId, context.registry, core, terms.collectionId, terms.generation, terms.bindingHash, 2, terms.account, authority, U256, U64]));
    const actual = client.collaboratorAcceptanceRecordHash(context.chainId, context.registry, core, terms, authority, U256, U64);
    assert.equal(actual, expected);
    assert.equal(client.collaboratorAcceptanceRecordHash(context.chainId, context.registry, core, { ...terms, role: ZeroHash, shareLabelId: ZeroHash }, authority, U256, U64), actual);
    assert.notEqual(client.collaboratorAcceptanceRecordHash(context.chainId, context.registry, core, { ...terms, account: A(12) }, authority, U256, U64), actual);
  }
  for (const bad of [0n, 2n, 5n, 256n, 1]) assert.throws(() => client.collaboratorAcceptanceRecordHash(context.chainId, context.registry, core, terms, bad, 0n, 1n));
  for (const bad of [0n, -1n, U64 + 1n]) assert.throws(() => client.collaboratorAcceptanceRecordHash(context.chainId, context.registry, core, terms, 1n, 0n, bad));
});

test("PRIMARY_ONLY binding uses the source's sixteen static words, zero mode/threshold and empty capabilities", () => {
  const declaration = hashesSource.match(/struct BindingPreimage \{([\s\S]*?)\}/)[1];
  const fields = [...declaration.matchAll(/(bytes32|uint256|uint64|uint32|uint8|address) (\w+);/g)].map(([, type, name]) => [type, name]);
  assert.equal(fields.length, 16);
  const capabilityType = compiledInterfaces.binding.getFunction("propose").inputs
    .find(p => p.components?.some(c => c.name === "capabilityPolicyOverrides"))
    .components.find(c => c.name === "capabilityPolicyOverrides");
  assert.equal(capabilityType.format("sighash"), "(uint32,uint8,uint32)[]");
  const capabilities = keccak256(coder.encode(["bytes32", capabilityType], [domain(baseHashesSource, "6529STREAM_ARTIST_CAPABILITY_POLICY_SET_V1"), []]));
  const preimage = { domain: domain(hashesSource, "6529STREAM_ARTIST_BINDING_V1"), chainId: context.chainId, registry: context.registry, core, collectionId: terms.collectionId, generation: binding.generation, artistId: binding.artistId, artistAddress: binding.artistAddress, identityRecordHash: binding.identityRecordHash, consentMode: binding.consentMode, saleConsentScope: binding.saleConsentScope, registryImmutabilityElection: binding.registryImmutabilityElection, collabPolicyMode: 0n, collabThreshold: 0n, collaboratorSetHash: sourceSetHash(rows), capabilityPolicySetHash: capabilities };
  const expected = keccak256(coder.encode(fields.map(([type]) => type), fields.map(([, name]) => preimage[name])));
  assert.equal(client.collaboratorSetHash(rows), sourceSetHash(rows));
  assert.equal(client.collaboratorSetHash([]), sourceSetHash([]));
  assert.equal(client.primaryOnlyCollaboratorBindingHash(context.chainId, context.registry, core, terms.collectionId, binding, rows), expected);
  assert.equal(client.primaryOnlyCollaboratorBindingHash(context.chainId, context.registry, core, terms.collectionId, { ...binding, bindingHash: H(99), proposer: A(99), accepted: true }, rows), expected);
  const changed = rows.map((r, i) => i === 0 ? { ...r, shareLabelId: H(99) } : r);
  assert.notEqual(client.primaryOnlyCollaboratorBindingHash(context.chainId, context.registry, core, terms.collectionId, binding, changed), expected);
  assert.throws(() => client.primaryOnlyCollaboratorBindingHash(context.chainId, context.registry, core, terms.collectionId, { ...binding, collabPolicyMode: 1n }, rows));
});

test("terms allow zero role/label but require dense, at-most-32 strict account/role order", () => {
  assert.deepEqual(client.normalizeCollaboratorTerms(rows), rows);
  assert.deepEqual(client.normalizeCollaboratorTerms([]), []);
  const maximum = Array.from({ length: 32 }, (_, i) => ({ account: A(i + 1), role: ZeroHash, shareLabelId: ZeroHash }));
  assert.equal(client.normalizeCollaboratorTerms(maximum).length, 32);
  for (const bad of [
    [...maximum, { account: A(33), role: ZeroHash, shareLabelId: ZeroHash }],
    [rows[1], rows[0]], [rows[2], rows[0]],
    [rows[0], { ...rows[0], shareLabelId: H(999) }],
    [{ ...rows[0], account: ZeroAddress }],
    Object.assign([...rows], { extra: true }), new Array(2),
    [{ ...rows[0], [Symbol("extra")]: true }],
  ]) assert.throws(() => client.normalizeCollaboratorTerms(bad));
});

test("protocol integer widths use bigint and accept exact uint64/uint256 maxima", () => {
  const maxAuth = { nonce: U256, time: U64, signature: "0x" };
  assert.deepEqual(client.normalizeCollaboratorAuthorization(maxAuth), maxAuth);
  assert.equal(client.normalizeCollaboratorAuthorization({ ...maxAuth, nonce: 0n }).nonce, 0n);
  const maxTerms = { ...terms, collectionId: U256, generation: U64, role: ZeroHash, shareLabelId: ZeroHash };
  assert.deepEqual(client.normalizeCollaboratorAcceptance(maxTerms), maxTerms);
  const prepared = client.prepareCollaboratorCall({ ...requests()[2], chainId: U256, terms: maxTerms, authorization: maxAuth });
  assert.equal(prepared.call.data, registryABI.encodeFunctionData("acceptCollaborator", [maxTerms, maxAuth]));
  for (const value of [-1n, U256 + 1n, 0, "0", Number.MAX_SAFE_INTEGER]) assert.throws(() => client.normalizeCollaboratorAuthorization({ ...authorization, nonce: value }));
  for (const value of [0n, -1n, U64 + 1n, 1, "1"]) assert.throws(() => client.normalizeCollaboratorAuthorization({ ...authorization, time: value }));
  for (const [key, values] of [["collectionId", [0n, -1n, U256 + 1n, 1]], ["generation", [0n, -1n, U64 + 1n, 1]]]) for (const value of values) assert.throws(() => client.normalizeCollaboratorAcceptance({ ...terms, [key]: value }));
  for (const chainId of [0n, U256 + 1n, 1]) assert.throws(() => client.prepareCollaboratorCall({ ...requests()[0], chainId }));
});

test("URI and display-name limits count UTF-8 bytes rather than characters", () => {
  assert.equal(client.normalizeCollaboratorProposal({ ...proposal, identityRecordURI: "é".repeat(1024), reasonURI: "" }).identityRecordURI.length, 1024);
  for (const key of ["identityRecordURI", "reasonURI"]) for (const value of ["é".repeat(1024) + "a", "a".repeat(2049), "\ud800", 123]) assert.throws(() => client.normalizeCollaboratorProposal({ ...proposal, [key]: value }));
  assert.equal(client.prepareCollaboratorCall({ ...requests()[1], displayName: "😀".repeat(64) }).request.displayName.length, 128);
  for (const displayName of ["", "😀".repeat(64) + "a", "a".repeat(257), "\ud800"]) assert.throws(() => client.prepareCollaboratorCall({ ...requests()[1], displayName }));
});

test("documents and opaque signatures enforce complete bytes and their independent size/hash bounds", () => {
  for (const size of [1, 8192]) {
    const bytes = `0x${"aB".repeat(size)}`;
    assert.equal(client.prepareCollaboratorCall({ ...requests()[1], document: bytes, identityRecordHash: keccak256(bytes) }).request.document, bytes.toLowerCase());
  }
  for (const bytes of ["0x", "0x1", "xyz", "0xgg", `0x${"ab".repeat(8193)}`]) assert.throws(() => client.prepareCollaboratorCall({ ...requests()[1], document: bytes }));
  const oversized = `0x${"ab".repeat(8193)}`;
  assert.throws(() => client.prepareCollaboratorCall({ ...requests()[1], document: oversized, identityRecordHash: keccak256(oversized) }));
  assert.throws(() => client.prepareCollaboratorCall({ ...requests()[1], identityRecordHash: H(50) }));
  for (const signature of ["0x", "0xAB", `0x${"ab".repeat(4096)}`]) assert.equal(client.normalizeCollaboratorAuthorization({ ...authorization, signature }).signature, signature.toLowerCase());
  for (const signature of ["0x1", "0x123", "0xgg", "", new Uint8Array([1]), `0x${"ab".repeat(4097)}`]) assert.throws(() => client.normalizeCollaboratorAuthorization({ ...authorization, signature }));
});

test("request shapes reject unknown keys and invalid addresses/hashes without aliasing inputs", () => {
  for (const request of requests()) {
    assert.throws(() => client.prepareCollaboratorCall({ ...request, extra: true }));
    assert.throws(() => client.prepareCollaboratorCall({ ...request, [Symbol("extra")]: true }));
    for (const key of ["registry", "caller"]) assert.throws(() => client.prepareCollaboratorCall({ ...request, [key]: ZeroAddress }));
  }
  for (const key of ["identityRecordHash", "reasonHash"]) for (const value of [ZeroHash, "0x1234", 123]) assert.throws(() => client.normalizeCollaboratorProposal({ ...proposal, [key]: value }));
  assert.throws(() => client.prepareCollaboratorCall({ ...requests()[2], core: ZeroAddress }));
  assert.throws(() => client.prepareCollaboratorCall({ ...requests()[0], kind: "collaboratorPayout" }));
  const input = requests()[2], prepared = client.prepareCollaboratorCall(input);
  input.terms.role = H(999); input.authorization.nonce = 999n;
  assert.equal(prepared.request.terms.role, terms.role);
  assert.equal(prepared.request.authorization.nonce, authorization.nonce);
  for (const value of [prepared, prepared.request, prepared.request.terms, prepared.request.authorization, prepared.call, prepared.signing, prepared.signing.payload.message]) assert.ok(Object.isFrozen(value));
});

test("normalization rejects changed prepared request, operation, CALL, signing and verified-fact claims", () => {
  for (const request of requests()) {
    const original = client.prepareCollaboratorCall(request);
    assert.deepEqual(client.normalizeCollaboratorCall(structuredClone(original)), original);
    const mutations = [
      v => { v.operation = 24; }, v => { v.factsVerified = true; },
      v => { v.request.registry = A(99); }, v => { v.call.to = A(99); },
      v => { v.call.value = 1n; }, v => { v.call.data += "00"; },
      v => { v.call.data = "0x1"; }, v => { v.call.extra = true; },
    ];
    if (original.signing) mutations.push(v => { v.signing.payload.digest = H(99); }, v => { v.signing.digestCall.data = "0x"; });
    else mutations.push(v => { v.signing = {}; });
    for (const mutate of mutations) { const changed = structuredClone(original); mutate(changed); assert.throws(() => client.normalizeCollaboratorCall(changed)); }
  }
});

const readCases = [
  ["collaboratorIdentityProposal", [proposal.account, documentHash], [{ proposal, proposer: context.caller, proposalHash: H(30), acceptedArtistId: H(31) }], { proposal, proposer: context.caller, proposalHash: H(30), acceptedArtistId: H(31) }],
  ["collaboratorRegistrationNonceState", [proposal.account, U256], [true, U256], { used: true, firstUnused: U256 }],
  ["collaboratorCount", [U256, U64], [32n], 32n],
  ["collaboratorAt", [U256, U64, U256], [{ ...rows[0], collaboratorArtistId: H(31), acceptanceRecordHash: H(32), accepted: true }], { ...rows[0], collaboratorArtistId: H(31), acceptanceRecordHash: H(32), accepted: true }],
  ["collaboratorPayoutAccount", [H(31), proposal.account], [A(33), H(34)], { payoutAccount: A(33), designationRecordHash: H(34) }],
];
test("all five reads encode and decode independently compiled canonical results", () => {
  for (const [method, args, values, expected] of readCases) {
    assert.deepEqual(client.prepareCollaboratorRead(context.registry, method, args), { to: context.registry, value: 0n, data: registryABI.encodeFunctionData(method, args) });
    const raw = registryABI.encodeFunctionResult(method, values);
    const actual = client.decodeCollaboratorRead(method, raw);
    assert.deepEqual(actual, expected);
    assert.deepEqual(client.decodeCollaboratorRead(method, `0x${raw.slice(2).toUpperCase()}`), expected);
    if (typeof actual === "object") assert.ok(Object.isFrozen(actual));
  }
});

test("canonical absence rows and zero nonce/payout facts remain representable", () => {
  const missing = { proposal: { account: ZeroAddress, identityRecordHash: ZeroHash, identityRecordURI: "", reasonHash: ZeroHash, reasonURI: "" }, proposer: ZeroAddress, proposalHash: ZeroHash, acceptedArtistId: ZeroHash };
  assert.deepEqual(client.decodeCollaboratorRead("collaboratorIdentityProposal", registryABI.encodeFunctionResult("collaboratorIdentityProposal", [missing])), missing);
  assert.deepEqual(client.decodeCollaboratorRead("collaboratorRegistrationNonceState", registryABI.encodeFunctionResult("collaboratorRegistrationNonceState", [false, 0n])), { used: false, firstUnused: 0n });
  assert.deepEqual(client.decodeCollaboratorRead("collaboratorPayoutAccount", registryABI.encodeFunctionResult("collaboratorPayoutAccount", [ZeroAddress, ZeroHash])), { payoutAccount: ZeroAddress, designationRecordHash: ZeroHash });
  assert.equal(client.prepareCollaboratorRead(context.registry, "collaboratorRegistrationNonceState", [proposal.account, 0n]).data, registryABI.encodeFunctionData("collaboratorRegistrationNonceState", [proposal.account, 0n]));
});

test("read methods and argument widths are closed and reject unsafe input values", () => {
  for (const method of ["toString", "acceptCollaborator", "unknown"]) {
    assert.throws(() => client.prepareCollaboratorRead(context.registry, method, []));
    assert.throws(() => client.decodeCollaboratorRead(method, "0x"));
  }
  for (const [method, args] of readCases) {
    assert.throws(() => client.prepareCollaboratorRead(context.registry, method, args.slice(0, -1)));
    assert.throws(() => client.prepareCollaboratorRead(context.registry, method, [...args, 0n]));
    assert.throws(() => client.prepareCollaboratorRead(ZeroAddress, method, args));
  }
  for (const args of [[0n, 1n], [1n, 0n], [1n, U64 + 1n], [1, 1n], [U256 + 1n, 1n]]) assert.throws(() => client.prepareCollaboratorRead(context.registry, "collaboratorCount", args));
  for (const index of [-1n, U256 + 1n, 0]) assert.throws(() => client.prepareCollaboratorRead(context.registry, "collaboratorAt", [1n, 1n, index]));
});

test("result decoding rejects trailing bytes, truncated or oversized data, dirty words and padding", () => {
  for (const [method, , values] of readCases) {
    const raw = registryABI.encodeFunctionResult(method, values);
    for (const bad of [raw + "00", raw + "00".repeat(32), raw.slice(0, -2), "0x1", "0xgg", `0x${"00".repeat(16385)}`]) assert.throws(() => client.decodeCollaboratorRead(method, bad), method);
  }
  const nonce = registryABI.encodeFunctionResult("collaboratorRegistrationNonceState", [true, 1n]);
  assert.throws(() => client.decodeCollaboratorRead("collaboratorRegistrationNonceState", withWord(nonce, 0, 2n)));
  const row = registryABI.encodeFunctionResult("collaboratorAt", readCases[3][2]);
  assert.throws(() => client.decodeCollaboratorRead("collaboratorAt", withWord(row, 0, (1n << 160n) + 10n)));
  assert.throws(() => client.decodeCollaboratorRead("collaboratorAt", withWord(row, 5, 2n)));
  const dynamic = registryABI.encodeFunctionResult("collaboratorIdentityProposal", readCases[0][2]);
  assert.throws(() => client.decodeCollaboratorRead("collaboratorIdentityProposal", dynamic.slice(0, -2) + "01"));
  assert.throws(() => client.decodeCollaboratorRead("collaboratorIdentityProposal", withWord(dynamic, 0, 64n)));
});

test("prepared operations form ordinary zero-value Safe CALL plans using the compiled facade ABI", () => {
  const prepared = requests().map(client.prepareCollaboratorCall);
  const plan = createSafeCallPlan(context.chainId, "Original collaborator operations", prepared.map(p => ({ safe: p.request.caller, intent: `Review operation ${p.operation}`, call: p.call, abi: compiledABI("registry") })));
  assert.deepEqual(verifySafeCallPlan(plan, prepared.map(() => compiledABI("registry"))), plan);
  for (const [i, step] of plan.steps.entries()) {
    assert.equal(step.transaction.operation, 0);
    assert.equal(step.transaction.value, "0");
    assert.equal(step.transaction.data, prepared[i].call.data);
    assert.equal(step.transaction.to, context.registry);
  }
  for (const data of [prepared[0].call.data + "00", "0x1"]) assert.throws(() => createSafeCallPlan(context.chainId, "Malformed", [{ safe: context.caller, intent: "Review", call: { ...prepared[0].call, data }, abi: compiledABI("registry") }]));
});
