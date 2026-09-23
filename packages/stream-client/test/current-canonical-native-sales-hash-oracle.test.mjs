import test from "node:test";
import assert from "node:assert/strict";
import { AbiCoder, Interface, ZeroAddress, ZeroHash, concat, getAddress, id, keccak256 } from "ethers";
import * as sales from "../dist/current-canonical-native-sales.js";
import { fixture, compiledInterfaces as compiled } from "./current-canonical-native-sales-fixture.mjs";

// Types come from the complete compiler output; all preimages below are the
// original Solidity definitions, independent of client tuple/hash helpers.
const coder = AbiCoder.defaultAbiCoder();
const hash = (types, values) => keccak256(coder.encode(types, values));
const address = value => getAddress(`0x${BigInt(value).toString(16).padStart(40, "0")}`);
const coordinates = { chainId: (1n << 200n) + 6529n, adapter: address(91), manager: address(92), ledger: address(93), recorder: address(94) };
function populated(param, prefix = "native") {
  if (param.baseType === "tuple") return Object.fromEntries(param.components.map(p => [p.name, populated(p, `${prefix}/${p.name}`)]));
  if (param.baseType === "array") return [];
  if (param.type === "address") return address(BigInt(id(prefix)) & ((1n << 160n) - 1n));
  if (param.type === "bytes32") return id(prefix);
  if (param.type === "bytes") return "0x123456";
  if (param.type === "bool") return false;
  return (1n << BigInt(Number(param.type.slice(4)) - 2)) + 3n;
}
const authorizationType = compiled.immediate.getFunction("purchaseSigned").inputs[1];
const authorization = { ...populated(authorizationType), chainId: coordinates.chainId, saleAdapter: coordinates.adapter,
  mintManager: coordinates.manager, saleKind: 13n, primaryPolicyMode: 0n, asset: ZeroAddress,
  unitPrice: 1000n, quantity: 1n, contentSelectionHash: ZeroHash, finalizeBy: 0n };
const domainType = "EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)";
const authorizationTypeText = `SaleAuthorization(${authorizationType.components.map(p => `${p.type} ${p.name}`).join(",")})`;
const revocationTypeText = "MintTicketRevocation(uint256 chainId,address manager,address ledger,bytes32 authorizationId)";
const separator = (name, chain = coordinates.chainId, adapter = coordinates.adapter) => hash(
  ["bytes32", "bytes32", "bytes32", "uint256", "address"], [id(domainType), id(name), id("1"), chain, adapter]);
const eip712 = (domain, body) => keccak256(concat(["0x1901", domain, body]));
const digest = eip712(separator("6529Stream Sales"), hash(["bytes32", authorizationType], [id(authorizationTypeText), authorization]));
const authorizationId = hash(["bytes32", "bytes32"], [id("6529STREAM_MINT_TICKET_AUTHORIZATION_V1"), digest]);
const revocationBody = hash(["bytes32", "uint256", "address", "address", "bytes32"],
  [id(revocationTypeText), coordinates.chainId, coordinates.manager, coordinates.ledger, authorizationId]);

test("all exported host and Manager ABI fragments match full compiler output", () => {
  for (const [key, fragments] of [["immediate", sales.CURRENT_CANONICAL_NATIVE_IMMEDIATE_SALES_ABI],
    ["claim", sales.CURRENT_CANONICAL_NATIVE_CLAIM_SALES_ABI], ["revocation", sales.CURRENT_CANONICAL_NATIVE_SALES_REVOCATION_ABI]]) {
    for (const fragment of new Interface(fragments).fragments) {
      const signature = fragment.format("sighash");
      const expected = fragment.type === "event" ? compiled[key].getEvent(signature)
        : fragment.type === "error" ? compiled[key].getError(signature) : compiled[key].getFunction(signature);
      assert.ok(expected, `${key}/${signature}`);
      assert.equal(fragment.format("minimal"), expected.format("minimal"), `${key}/${signature}`);
      const fields = (actual, original, tuple = false) => {
        assert.equal(actual.length, original.length);
        for (let i = 0; i < original.length; i++) {
          const a = actual[i], e = original[i];
          if (tuple || fragment.type === "event") assert.equal(a.name, e.name, `${key}/${signature}/${e.name}`);
          if (e.baseType === "array") fields([a.arrayChildren], [e.arrayChildren]);
          if (e.baseType === "tuple") fields(a.components, e.components, true);
        }
      };
      fields(fragment.inputs, expected.inputs);
      if (expected.outputs) fields(fragment.outputs, expected.outputs);
    }
  }
});

test("original 24-field Sales-v1 digest and MintTicket revocation retain independent EIP712 preimages", () => {
  assert.ok(fixture.sourceTexts["smart-contracts/domains/mint/StreamPrivateSaleHash.sol"].includes(authorizationTypeText));
  assert.ok(fixture.sourceTexts["smart-contracts/domains/mint/StreamMintTicketHash.sol"].includes(revocationTypeText));
  assert.equal(sales.canonicalNativeSalesAuthorizationPayload(coordinates, authorization).digest, digest);
  assert.equal(sales.canonicalNativeSalesAuthorizationId(coordinates, authorization), authorizationId);
  const revoke = eip712(separator("6529Stream Sales"), revocationBody);
  assert.deepEqual([digest, authorizationId, revoke], [
    "0x408264bf8b1b1ea4b34e1e22ea8c29ef85f7b7c7ce9e614083e3f6e0139adf51",
    "0x8bdea953aceed1a3d3a31b2327bbb705ea3efbb501250da57aacb8980cd424f6",
    "0x6717c0004264bc7b0792907d5f9803ad714f702b514c9ef2bee4bb76ca09ae2f",
  ]);
  assert.equal(sales.canonicalNativeSalesRevocationPayload(coordinates, authorization).digest, revoke);
  assert.notEqual(revoke, eip712(separator("6529Stream Mint Tickets"), revocationBody));
  assert.notEqual(revoke, eip712(separator("6529Stream Sales", coordinates.chainId, coordinates.manager), revocationBody));
  for (const field of authorizationType.components) {
    const old = authorization[field.name];
    const changed = field.type === "address" ? address(700) : field.type === "bytes32" ? id(`changed/${field.name}`) : old + 1n;
    const next = { ...authorization, [field.name]: changed };
    const nextCoordinates = { ...coordinates,
      ...(field.name === "chainId" ? { chainId: changed } : field.name === "saleAdapter" ? { adapter: changed }
        : field.name === "mintManager" ? { manager: changed } : {}) };
    const expected = eip712(separator("6529Stream Sales", nextCoordinates.chainId, nextCoordinates.adapter),
      hash(["bytes32", authorizationType], [id(authorizationTypeText), next]));
    assert.notEqual(expected, digest, field.name);
    assert.equal(sales.canonicalNativeSalesAuthorizationPayload(nextCoordinates, next).digest, expected, field.name);
  }
});

test("expected authorizations retain original one-token array tags and dynamic bytes encoding", () => {
  for (const family of ["immediate", "claim"]) {
    const config = populated(compiled[family].getFunction("saleConfigurationHash").inputs[0]);
    const base = family === "immediate" ? config : config.sale;
    Object.assign(base, { saleKind: family === "immediate" ? 0n : 13n, authorityMode: 1n,
      unitPrice: 7n, startsAt: 1n, endsAt: 100n, primaryPolicyMode: 0n });
    base.signer.kind = 2n;
    const purchase = populated(compiled[family].getFunction("purchasePublic").inputs[0]);
    const mint = family === "immediate" ? purchase : purchase.mint;
    mint.executor = mint.payer;
    mint.tokenData = "0x0001020300ff";
    const terms = { nonce: id("signed nonce"), deadline: 77n, unitPrice: family === "immediate" ? 7n : 1000n };
    const expected = {
      chainId: coordinates.chainId, saleAdapter: coordinates.adapter, mintManager: coordinates.manager,
      collectionId: base.collectionId, phaseId: base.phaseId, saleId: mint.saleId, saleKind: base.saleKind,
      revenueClass: id("PRIMARY_SALE"), expectedPrimaryPolicyHash: base.expectedPrimaryPolicyHash, primaryPolicyMode: 0n,
      initialRecipientsHash: hash(["bytes32", "address[]"], [id("6529STREAM_MINT_BATCH_RECIPIENTS_V1"), [mint.initialRecipient]]),
      beneficiariesHash: hash(["bytes32", "address[]"], [id("6529STREAM_MINT_BATCH_BENEFICIARIES_V1"), [mint.beneficiary]]),
      tokenDataArrayHash: hash(["bytes32", "bytes[]"], [id("6529STREAM_MINT_BATCH_TOKEN_DATA_V1"), [mint.tokenData]]),
      mintCommitmentsHash: hash(["bytes32", "bytes32[]"], [id("6529STREAM_MINT_BATCH_COMMITMENTS_V1"), [mint.mintCommitment]]),
      payer: mint.payer, executor: mint.executor, asset: ZeroAddress, unitPrice: terms.unitPrice, quantity: 1n,
      contentSelectionHash: ZeroHash, policyHash: base.mintPolicyHash, nonce: terms.nonce, deadline: terms.deadline, finalizeBy: 0n,
    };
    assert.deepEqual(sales.canonicalNativeSalesExpectedAuthorization(coordinates, family, config, purchase, terms), expected);
    const prehashedData = hash(["bytes32", "bytes32[]"], [id("6529STREAM_MINT_BATCH_TOKEN_DATA_V1"), [keccak256(mint.tokenData)]]);
    assert.notEqual(expected.tokenDataArrayHash, prehashedData);
  }
});

for (const family of ["immediate", "claim"]) test(`${family} configuration, request and public execution match original domains`, () => {
  const abi = compiled[family], upper = family.toUpperCase();
  const source = fixture.sourceTexts[`smart-contracts/domains/mint/StreamNative${family === "immediate" ? "Immediate" : "Claim"}SalesRuntime.sol`];
  const domain = suffix => {
    const text = `6529STREAM_NATIVE_${upper}_SALES_${suffix}_V1`;
    assert.ok(source.includes(text));
    return id(text);
  };
  const configType = abi.getFunction("saleConfigurationHash").inputs[0];
  const config = populated(configType, family);
  const base = family === "immediate" ? config : config.sale;
  base.saleKind = family === "immediate" ? 1n : 13n;
  base.authorityMode = 2n;
  base.primaryPolicyMode = 0n;
  base.unitPrice = 1000n;
  const configHash = hash(["bytes32", "uint256", "address", configType],
    [domain("CONFIG"), coordinates.chainId, coordinates.adapter, config]);
  assert.equal(sales.canonicalNativeSalesConfigurationHash(coordinates, family, config), configHash);
  const nonce = (1n << 190n) + 7n;
  const saleId = hash(["bytes32", "uint256", "address", "uint256", "bytes32", "uint256"],
    [domain("ID"), coordinates.chainId, coordinates.adapter, base.collectionId, base.phaseId, nonce]);
  assert.equal(sales.canonicalNativeSalesSaleId(coordinates, family, base.collectionId, base.phaseId, nonce), saleId);
  const requestType = abi.getFunction("purchasePublic").inputs[0];
  const purchase = populated(requestType, family);
  const mint = family === "immediate" ? purchase : purchase.mint;
  mint.saleId = saleId;
  mint.executor = mint.payer;
  if (family === "claim") purchase.chosenUnitPrice = 0n;
  const requestHash = hash(["bytes32", "uint256", "address", "bytes32", requestType],
    [domain("REQUEST"), coordinates.chainId, coordinates.adapter, configHash, purchase]);
  assert.equal(sales.canonicalNativeSalesRequestHash(coordinates, family, configHash, purchase), requestHash);
  const publicDomain = `6529STREAM_NATIVE_PUBLIC_${family === "claim" ? "CLAIM_" : ""}MINT_AUTHORIZATION_V1`;
  assert.ok(source.includes(publicDomain));
  const publicId = hash(["bytes32", "uint256", "address", "address", "bytes32", "bytes32"],
    [id(publicDomain), coordinates.chainId, coordinates.adapter, coordinates.manager, configHash, requestHash]);
  assert.equal(sales.canonicalNativeSalesPublicAuthorizationId(coordinates, family, configHash, requestHash), publicId);
  for (const [authDigest, authId] of [[ZeroHash, publicId], [digest, authorizationId]]) {
    const expected = hash(["bytes32", "bytes32", "bytes32", "bytes32"], [domain("EXECUTION"), requestHash, authDigest, authId]);
    assert.equal(sales.canonicalNativeSalesExecutionHash(family, requestHash, authDigest, authId), expected);
  }
  const changed = family === "immediate" ? { ...purchase, beneficiary: address(900) }
    : { ...purchase, chosenUnitPrice: 1n };
  assert.notEqual(sales.canonicalNativeSalesRequestHash(coordinates, family, configHash, changed), requestHash);
});

test("native execution, candidate commitment, settlement key and zero lifecycle accounting retain original widths", () => {
  const candidateType = compiled.nativeSettlement.getFunction("settleNativePrimarySaleFromAdapter").inputs[0];
  const candidate = populated(candidateType);
  candidate.saleAdapter = coordinates.adapter;
  candidate.mintManager = coordinates.manager;
  candidate.executionBinding.authorityMode = 1n;
  candidate.executionBinding.saleAuthorizationDigest = digest;
  candidate.orchestrationOrder = 1n;
  candidate.sale.policyMode = 0n;
  candidate.sale.amount = 0n;
  const executionId = hash(["bytes32", "uint256", "address", "bytes32", "address", "address", "uint256", "uint8",
    "bytes32", "bytes32", "bytes32", "bytes32"], [id("6529STREAM_NATIVE_SALE_EXECUTION_V1"), coordinates.chainId,
    candidate.saleAdapter, candidate.sale.settlementId, candidate.sale.payer, candidate.executor,
    candidate.executionBinding.executionNonce, candidate.executionBinding.authorityMode, digest,
    candidate.currentPolicyHash, candidate.boundPolicyHash, candidate.operationIdentityCommitment]);
  assert.equal(sales.canonicalNativeSalesExecutionId(coordinates.chainId, candidate), executionId);
  candidate.executionBinding.executionId = executionId;
  const commitment = hash(["bytes32", "uint256", "address", candidateType],
    [id("6529STREAM_NATIVE_SETTLEMENT_CANDIDATE_V1"), coordinates.chainId, coordinates.recorder, candidate]);
  assert.equal(sales.canonicalNativeSalesCandidateCommitment(coordinates.chainId, coordinates.recorder, candidate), commitment);
  const key = hash(["bytes32", "uint256", "address", "address", "bytes32"],
    [id("6529STREAM_PRIMARY_SETTLEMENT_KEY_V2"), coordinates.chainId, coordinates.recorder, coordinates.adapter, executionId]);
  assert.equal(sales.canonicalNativeSalesSettlementKey(coordinates.chainId, coordinates.recorder, coordinates.adapter, executionId), key);
  const accounting = { ...candidate, asset: ZeroAddress, lifecycleBinding: { paymentAdapter: ZeroAddress,
    saleCreatedAt: 0n, saleAdapterRegistryRevision: 0n, paymentAdapterRegistryRevision: 0n } };
  const accountingType = compiled.primarySettlement.getFunction("settleERC20PrimarySaleFromAdapter").inputs[1];
  assert.deepEqual(sales.canonicalNativeSalesAccountingContext(candidate), accounting);
  assert.equal(sales.canonicalNativeSalesAccountingContextHash(candidate), hash([accountingType], [accounting]));
  const changed = { ...candidate, lifecycleBinding: { ...candidate.lifecycleBinding, saleCreatedAt: 1n } };
  assert.notEqual(sales.canonicalNativeSalesCandidateCommitment(coordinates.chainId, coordinates.recorder, changed), commitment);
  assert.equal(sales.canonicalNativeSalesAccountingContextHash(changed), hash([accountingType], [accounting]));
  assert.equal(sales.canonicalNativeSalesExecutionId(coordinates.chainId, changed), executionId);
  assert.notEqual(candidate.currentPolicyHash, candidate.boundPolicyHash);
});
