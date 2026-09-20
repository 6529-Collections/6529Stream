import test from "node:test";
import assert from "node:assert/strict";
import { AbiCoder, Interface, ZeroAddress, ZeroHash, getAddress, id, keccak256 } from "ethers";
import * as m from "../dist/current-distribution-merkle.js";
import * as w from "../dist/current-distribution-merkle-workflow.js";
import * as a from "../dist/current-mint-counter-reads.js";
import { buildOperatorDistributionManifest } from "../dist/current-distribution.js";
import { createSafeCallPlan, verifySafeCallPlan } from "../dist/safe-plan.js";
import { fixture, compiledInterfaces as c } from "./current-distribution-merkle-fixture.mjs";

// These are compiler-ABI RPC fixtures, not native EVM admission or rollback evidence.
const coder = AbiCoder.defaultAbiCoder();
const A = n => getAddress(`0x${BigInt(n).toString(16).padStart(40, "0")}`);
const H = n => id(`distribution test ${n}`);
const code = "0x6001600055";
const pin = n => ({ address: A(n), codeHash: keccak256(code) });
const zero = ZeroHash;
const emptyClaim = { collectionId: 0n, phaseId: zero, beneficiary: ZeroAddress };
const safe = new Interface([
  "function execTransaction(address to,uint256 value,bytes data,uint8 operation,uint256 safeTxGas,uint256 baseGas,uint256 gasPrice,address gasToken,address refundReceiver,bytes signatures) returns(bool)",
  "event ExecutionSuccess(bytes32 txHash,uint256 payment)",
  "event ExecutionFailure(bytes32 txHash,uint256 payment)",
]);
const indexedSafe = new Interface(["event ExecutionSuccess(bytes32 indexed txHash,uint256 payment)"]);
const functions = new Map();
for (const contract of Object.values(c)) {
  for (const fragment of contract.fragments.filter(f => f.type === "function")) {
    if (!functions.has(fragment.selector)) functions.set(fragment.selector, { contract, fragment });
  }
}
function plain(type, value) {
  if (type.baseType === "array") return Array.from(value, v => plain(type.arrayChildren, v));
  if (type.baseType === "tuple") return Object.fromEntries(type.components.map((t, i) => [t.name, plain(t, value[i])]));
  return value;
}

function setup(options = {}) {
  const quantity = options.quantity ?? 2;
  const caller = options.caller ?? A(30);
  const d = {
    chainId: 31337n, distributor: pin(1), core: pin(2), manager: pin(3), ledger: pin(4),
    moduleRegistry: pin(5), delegateRegistry: pin(6), linkedDependencies: [pin(8)],
    delegationLinkedDependencies: [pin(9)],
  };
  const context = { chainId: d.chainId, distributor: A(1), core: A(2), manager: A(3), ledger: A(4) };
  const original = { chainId: d.chainId, distributor: A(1), core: A(2), manager: A(3) };
  const collectionId = 7n, phaseId = H("phase"), supplyId = H("supply"), recipientId = H("recipient");
  const beneficiaries = options.beneficiaries ?? Array(quantity).fill(A(40));
  const manifest = buildOperatorDistributionManifest({
    context: original, collectionId, phaseId, operator: caller, supplyCounterId: supplyId,
    recipientCounterId: recipientId, perRecipientCap: BigInt(quantity), deliveryMode: options.deliveryMode ?? 1n,
    prepared: options.prepared ?? false, sliceQuantity: quantity,
    tokens: beneficiaries.map((beneficiary, i) => ({ beneficiary, tokenData: `0x${(i + 1).toString(16).padStart(2, "0")}`, mintCommitment: H(`mint${i}`) })),
    manifestCompletenessReviewed: true,
  });
  const makeMerkle = (counterId, scope, metadata) => {
    const tree = m.buildDistributionMerkleAllowanceTree(context, collectionId, phaseId, counterId, BigInt(quantity),
      [...new Set(beneficiaries)].map(beneficiary => ({ beneficiary, maxCount: BigInt(quantity) })));
    const definition = { scope, keyMode: 3n, capRoot: tree.root, metadataHash: metadata };
    return { tree, row: { counterId, config: { enabled: true, keyMode: 3n, capMode: 3n,
      deltaMode: 0n, staticCap: BigInt(quantity), staticIncrement: 1n, counterConfigHash: m.distributionMerkleDefinitionHash(definition) },
      definitionExists: true, definition } };
  };
  const selected = makeMerkle(recipientId, options.scope ?? 1n, H("published complete recipient list"));
  const extras = options.extra ? [makeMerkle(H("extra"), 2n, zero)] : [];
  const supply = { counterId: supplyId, config: { enabled: true, keyMode: 1n, capMode: 1n, deltaMode: 0n,
    staticCap: BigInt(quantity), staticIncrement: 1n, counterConfigHash: H("latched absent supply") },
    definitionExists: false, definition: { scope: 2n, keyMode: 0n, capRoot: zero, metadataHash: zero } };
  const counters = [...extras.map(e => e.row), supply, selected.row];
  const program = m.prepareDistributionMerkleProgram(manifest, { counterConfigHash: selected.row.config.counterConfigHash,
    exists: true, definition: selected.row.definition });
  const proofs = [...extras, selected].map(e => beneficiaries.map(b => e.tree.entries.find(row => row.beneficiary === b).proof));
  const fee = options.fee ?? 0n;
  const input = { program, sliceIndex: 0, counters, proofs, expectedPolicyHash: H("bound policy"), gateData: "0x",
    revealFeePerTokenWei: fee };
  const prepared = m.prepareDistributionMerkleCall(context, caller, input);
  const batch = prepared.batch;
  const root = H("operation root"), firstNonce = 5n;
  const ids = batch.tokenData.map((data, i) => keccak256(coder.encode(
    ["bytes32", "bytes32", "uint256", "uint256", "bytes32", "bytes32"],
    [id("6529STREAM_MINT_TOKEN_OPERATION_ID_V1"), root, firstNonce + BigInt(i), BigInt(i), keccak256(data), batch.mintCommitments[i]],
  )));
  const resolutions = new Map();
  const rows = [];
  let proofIndex = 0;
  for (const row of counters) {
    for (let i = 0; i < quantity; i++) {
      const x = { collectionId, phaseId, counterId: row.counterId, payer: ZeroAddress,
        initialRecipient: batch.initialRecipients[i], beneficiary: beneficiaries[i], executor: A(1), authorizer: ZeroAddress,
        tokenIndex: BigInt(i), contextHash: batch.contextHash,
        resolverData: row.config.capMode === 3n ? a.encodeMintCounterAllowlistProof(proofs[proofIndex][i]) : "0x" };
      const resolved = a.resolveMintCounterRead({ chainId: d.chainId, manager: A(3), ledger: A(4) },
        { phaseExists: true, config: row.config, definitionExists: row.definitionExists, definition: row.definition }, x);
      resolutions.set(`${row.counterId}:${i}`, resolved);
      rows.push({ counterId: row.counterId, subjectKey: resolved.resolution.subjectKey, valueKey: resolved.valueKey,
        current: 0n, increment: 1n, projected: 0n, cap: resolved.resolution.effectiveCap, allowed: true,
        resolutionHash: resolved.resolution.resolutionHash });
    }
    if (row.config.capMode === 3n) proofIndex++;
  }
  for (const row of rows) row.projected = BigInt(rows.filter(other => other.valueKey === row.valueKey).length);
  const currentPolicy = H("current policy differs within grace");
  const preview = { allowed: true, reason: "0x00000000", policyHash: currentPolicy, gateHash: zero,
    quantity: BigInt(quantity), counters: rows };
  const royalty = { configured: options.royalty ?? false, applicationConfigHash: program.applicationConfigHash,
    resolver: A(11), resolverRuntimeHash: keccak256(code), electionHash: H("election"),
    expectedModeAssignmentHash: H("mode"), expectedSourceRoyaltyPolicyHash: H("source royalty") };
  if (!royalty.configured) Object.assign(royalty, { applicationConfigHash: zero, resolver: ZeroAddress,
    resolverRuntimeHash: zero, electionHash: zero, expectedModeAssignmentHash: zero, expectedSourceRoyaltyPolicyHash: zero });
  const reveal = options.reveal ?? "instant";
  const revealPolicy = reveal === "instant" || reveal === "disabled"
    ? { declared: false, requestMode: 0n, revealOwnerRole: zero, requestSLOBlocks: 0n, revealFeePerTokenWei: 0n }
    : { declared: true, requestMode: options.requestMode ?? 0n, revealOwnerRole: zero, requestSLOBlocks: 9n, revealFeePerTokenWei: fee };
  const collectionPolicy = { configured: true, explicitPolicy: true, frozen: false,
    mode: reveal === "instant" ? 1n : reveal === "disabled" ? 0n : 2n,
    securityClass: 1n, renderRequirement: reveal === "not-required" ? 1n : 0n,
    revision: 1n, providerEpoch: 1n, policyHash: H("entropy policy"), contentStateHash: H("content"), lastActionId: zero, artistConsentRecord: zero };
  const baseManifest = H("base manifest");
  const moduleManifest = coder.encode(["bytes32", "uint256", "address", "bytes32", "address", "address", "bytes32", "uint256"],
    [id("6529STREAM_NATIVE_AUCTION_NFTDELEGATION_MANIFEST_V1"), d.chainId, A(1), baseManifest, A(2), A(6), keccak256(code), 5n]);
  const e = { options, d, context, original, manifest, program, input, prepared, batch, counters, proofs, rows, resolutions,
    selected, root, ids, firstNonce, currentPolicy, preview, royalty, revealPolicy, collectionPolicy,
    calls: [], codes: [], intercept: null, codeIntercept: null, blockIntercept: null, receipt: null, tx: null,
    mined: 12, claim: null, claimCompleted: true, diverted: new Set(options.diverted ?? []), escrowAfter: 20n,
    tokenIds: Array.from({ length: quantity }, (_, i) => 100n + BigInt(i)),
  };
  const pointer = p => [p.address, p.codeHash, false, H("type"), "0x12345678", A(5), 1n, H("manifest"), H("deployment"), 1n];
  e.provider = {
    getNetwork: async () => ({ chainId: d.chainId }),
    getBlock: async tag => e.blockIntercept?.(tag) ?? ({ number: tag, hash: H(`block${tag}`), timestamp: 1000 + tag }),
    getCode: async (target, tag) => { e.codes.push([target, tag]); return e.codeIntercept?.(target, tag) ?? code; },
    getTransactionReceipt: async () => e.receipt,
    getTransaction: async () => e.tx,
    call: async tx => {
      const found = functions.get(tx.data.slice(0, 10));
      assert.ok(found, `unknown RPC selector ${tx.data.slice(0, 10)}`);
      const { contract, fragment } = found;
      const values = contract.decodeFunctionData(fragment, tx.data);
      const args = fragment.inputs.map((type, i) => plain(type, values[i]));
      const name = fragment.name, tag = Number(tx.blockTag), post = tag >= e.mined;
      const call = { name, args, tx, post, tag }; e.calls.push(call);
      let result = e.intercept ? await e.intercept(call) : undefined;
      if (result === undefined) {
        switch (name) {
          case "core": result = [A(2)]; break;
          case "coreCodeHash": case "managerCodeHash": case "registryCodeHash": case "delegateRegistryCodeHash": result = [keccak256(code)]; break;
          case "manager": result = [A(3)]; break;
          case "mintLedger": result = [A(4)]; break;
          case "moduleRegistry": result = [A(5)]; break;
          case "delegateRegistry": result = [A(6)]; break;
          case "delegationUsecase": result = [5n]; break;
          case "baseManifestHash": result = [baseManifest]; break;
          case "moduleManifestBytes": result = [moduleManifest]; break;
          case "supportsInterface": case "isModuleEligible": case "phaseExecutor": result = [true]; break;
          case "moduleRecord": result = [{ status: 1n, moduleType: id("OPERATOR_DISTRIBUTION"), moduleVersion: H("version"),
            interfaceId: "0xe1ceb09a", moduleGasLimit: 1000000n, runtimeCodeHash: keccak256(code), deploymentManifestHash: H("deployment"),
            moduleManifestHash: keccak256(moduleManifest), moduleManifestURI: "ipfs://module", registeredAt: 1n, statusUpdatedAt: 1n, revision: 1n }]; break;
          case "getSatellitePointer": result = pointer(args[0] === id("MINT_MANAGER") ? d.manager
            : args[0] === id("MODULE_REGISTRY") ? d.moduleRegistry : pin(10)); break;
          case "gasParameter": result = [400000n]; break;
          case "phase": result = [true, { paused: false, startTime: 0n, endTime: 0n, maxBatchQuantity: 10n,
            configHash: royalty.configured ? H("royalty config") : program.applicationConfigHash, metadataHash: H("phase metadata") }]; break;
          case "phaseGate": result = [{ gate: ZeroAddress, gateConfigHash: zero, gateCodehash: zero, gateMetadataHash: zero, gateSemanticVersion: 0n, gateGasLimit: 0n }]; break;
          case "phaseCounterIds": result = [counters.map(row => row.counterId)]; break;
          case "counterConfig": result = [counters.find(row => row.counterId === args[2]).config]; break;
          case "counterDefinitionForManager": {
            assert.equal(args[0], A(3));
            const row = counters.find(row => row.config.counterConfigHash === args[1]);
            result = [row.definitionExists, row.definition]; break;
          }
          case "merkleProgramHash": result = [program.applicationConfigHash]; break;
          case "phaseRoyaltyPolicy": result = [royalty]; break;
          case "phaseRoyaltyConfigHash": result = [H("royalty config")]; break;
          case "sliceHash": result = [batch.contextHash]; break;
          case "sliceAuthorization": result = [batch.authorizationId]; break;
          case "sliceUsed": case "isManagerAuthorizationUsed": case "isManagerOperationRootUsed": result = [post]; break;
          case "canMint": assert.equal(tx.from, A(1)); assert.equal(args[1], A(1)); result = [preview]; break;
          case "phasePolicyHash": result = [currentPolicy]; break;
          case "policyGrace": result = [batch.expectedPolicyHash, 1n, 10000n]; break;
          case "remainingForResolvedCounter": {
            assert.equal(tx.from, A(1)); const row = resolutions.get(`${args[0].counterId}:${args[0].tokenIndex}`);
            result = [row.resolution, 0n, row.resolution.effectiveCap]; break;
          }
          case "counterValue": result = [post ? rows.find(row => row.valueKey === args[0]).projected : 0n]; break;
          case "nextOperationNonce": result = [firstNonce + (post ? BigInt(quantity) : 0n)]; break;
          case "previewSingleStepMintOperation": case "previewPreparedNativeMintOperation":
            assert.equal(tx.from, A(1));
            if (name === "previewPreparedNativeMintOperation") assert.equal(quantity, 1, "original getter rejects prepared multi-token");
            result = [root, ids]; break;
          case "collectionRevealPolicy": result = [revealPolicy]; break;
          case "collectionEntropyPolicy": result = [collectionPolicy]; break;
          case "revealFeeEscrow": result = [post ? e.escrowAfter : 20n]; break;
          case "nftClaim": result = [e.claim
            ? (post && e.claimCompleted ? emptyClaim : e.claim)
            : (post && e.diverted.has(Number(args[0] - 100n)) ? { collectionId, phaseId, beneficiary: beneficiaries[Number(args[0] - 100n)] } : emptyClaim)]; break;
          case "ownerOf": result = [A(1)]; break;
          case "globalDelegationHashes": result = [e.claim.beneficiary, e.prepared.caller, 1n, 10000n, true, 0n]; break;
          case "distribute": assert.equal(tx.from, caller); assert.equal(tx.value, prepared.call.value); assert.equal(tx.gasLimit, 9000000n); result = [e.tokenIds, root]; break;
          case "claimNft": case "claimNftFor": assert.equal(tx.from, e.prepared.caller); assert.equal(tx.value, 0n); result = [e.claimCompleted]; break;
          case "tokenCollectionIdentity": result = [true, collectionId, args[0] - 99n, options.burned ?? false]; break;
          case "tokenLifecycle": result = [options.burned ? 3n : 2n]; break;
          case "coordinatorAtMint": result = [A(10)]; break;
          case "royaltySnapshot": {
            const i = Number(args[0] - 100n);
            result = [{ exists: true, collectionId, tokenId: args[0], manager: A(3), operationRoot: root, operationId: ids[i],
              preparedProofHash: H(`proof${i}`), electionHash: royalty.electionHash, sourceAssignmentHash: H("source assignment"),
              modeAssignmentHash: royalty.expectedModeAssignmentHash, sourceRoyaltyPolicyHash: royalty.expectedSourceRoyaltyPolicyHash,
              tokenAssignmentHash: H("token assignment"), tokenRoyaltyPolicyHash: H("token royalty"), tokenConfigHash: H("token config") }]; break;
          }
          default: throw Error(`unhandled original ${name}`);
        }
      }
      return typeof result === "string" ? result : contract.encodeFunctionResult(fragment, result);
    },
  };
  return e;
}

function event(contract, target, name, values) {
  const emitterABI = contract.getEvent(name) ? contract : Object.values(c).find(value => value.getEvent(name));
  assert.ok(emitterABI, `missing compiled event ${name}`);
  const encoded = emitterABI.encodeEventLog(emitterABI.getEvent(name), values);
  return { address: target, ...encoded };
}
function stamp(e, logs, mode = "direct") {
  const p = e.prepared;
  if (mode !== "direct") logs.push(event(mode === "indexed" ? indexedSafe : safe, p.caller, "ExecutionSuccess", [H("safe transaction"), 0n]));
  e.receipt = { hash: H("tx"), blockNumber: e.mined, blockHash: H(`block${e.mined}`), status: 1,
    from: mode === "direct" ? p.caller : A(99), to: mode === "direct" ? p.call.to : p.caller,
    logs: logs.map((log, index) => ({ ...log, index, removed: false, transactionHash: H("tx"), blockHash: H(`block${e.mined}`), blockNumber: e.mined })) };
  e.tx = { hash: H("tx"), blockNumber: e.mined, blockHash: H(`block${e.mined}`), chainId: e.d.chainId,
    from: e.receipt.from, to: e.receipt.to, value: mode === "direct" ? p.call.value : 0n,
    data: mode === "direct" ? p.call.data : safe.encodeFunctionData("execTransaction", [p.call.to, p.call.value, p.call.data, 0, 0n, 0n, 0n, ZeroAddress, ZeroAddress, "0x1234"]) };
  return mode === "direct" ? { execution: "direct" } : { execution: "safe", expectedSafeTxHash: H("safe transaction") };
}
function distributionLogs(e, mode = "direct") {
  const b = e.batch, qty = BigInt(b.beneficiaries.length), logs = [];
  const add = (key, target, name, values) => logs.push(event(c[key], target, name, values));
  add("ledger", A(4), "MintLedgerAuthorizationConsumed", [1n, b.authorizationId, e.root, A(3), b.expectedPolicyHash]);
  add("ledger", A(4), "MintLedgerOperationRootConsumed", [1n, e.root, A(3), e.currentPolicy, b.expectedPolicyHash, b.authorizationId]);
  e.tokenIds.forEach((tokenId, i) => {
    if (e.manifest.program.prepared) {
      add("manager", A(3), "PreparedMintStarted", [1n, e.ids[i], tokenId, b.collectionId, e.root, BigInt(i + 1), b.beneficiaries[i], keccak256(b.tokenData[i]), b.mintCommitments[i]]);
      add("manager", A(3), "PreparedMintCompleted", [1n, e.ids[i], tokenId, b.collectionId, e.root, b.initialRecipients[i]]);
    } else add("manager", A(3), "MintTokenExecuted", [1n, e.ids[i], tokenId, e.root, b.collectionId, b.phaseId, BigInt(i), b.initialRecipients[i], b.beneficiaries[i], keccak256(b.tokenData[i]), b.mintCommitments[i]]);
  });
  add("manager", A(3), "MintAuthorizationConsumed", [1n, b.collectionId, b.phaseId, b.authorizationId, b.expectedPolicyHash, e.root]);
  add("manager", A(3), "MintBatchExecuted", [1n, e.root, b.collectionId, b.phaseId, A(1), ZeroAddress, ZeroAddress, e.tokenIds[0], qty, b.contextHash, zero, e.currentPolicy, b.expectedPolicyHash]);
  let escrow = 20n;
  e.tokenIds.forEach((tokenId, i) => {
    const fee = e.revealPolicy.revealFeePerTokenWei;
    if (fee !== 0n) {
      escrow += fee;
      add("entropy", A(10), "RevealFeeEscrowFunded", [1n, b.collectionId, A(1), fee, escrow]);
    }
    if (e.collectionPolicy.mode === 2n && e.collectionPolicy.renderRequirement !== 1n && e.revealPolicy.requestMode === 0n) {
      if (e.options.revealSuccess) {
        const spent = e.options.spent ?? 0n;
        if (spent) { escrow -= spent; add("entropy", A(10), "RevealFeeEscrowSpent", [1n, b.collectionId, tokenId, spent, escrow]); }
        add("distributor", A(1), "ImmediateRevealAttempt", [1n, b.collectionId, tokenId, true, H(`request${i}`), 0n, 64n, "0x"]);
      } else add("distributor", A(1), "ImmediateRevealAttempt", [1n, b.collectionId, tokenId, false, zero, 0n, 300n, `0x${"aa".repeat(256)}`]);
    }
    if (e.manifest.program.deliveryMode === 1n) {
      if (e.diverted.has(i)) add("distributor", A(1), "AirdropDeliveryDiverted", [1n, b.collectionId, b.phaseId, tokenId, b.beneficiaries[i]]);
      else add("core", A(2), "Transfer", [A(1), b.beneficiaries[i], tokenId]);
    }
  });
  e.escrowAfter = escrow;
  add("distributor", A(1), "DistributionSliceExecuted", [1n, b.collectionId, b.phaseId, 0n, b.contextHash, e.root, qty]);
  return stamp(e, logs, mode);
}
function claimSetup(kind = "claimNft", options = {}) {
  const e = setup(options);
  const beneficiary = options.beneficiary ?? A(40);
  const caller = options.self ? beneficiary : options.caller ?? (kind === "claimNft" ? beneficiary : A(41));
  e.claim = { collectionId: 7n, phaseId: H("phase"), beneficiary };
  e.claimCompleted = options.completed ?? true;
  e.prepared = m.prepareDistributionMerkleClaim(e.context, caller, kind === "claimNft"
    ? { kind, tokenId: 100n, receiver: A(42) }
    : { kind, tokenId: 100n, walletWide: options.walletWide ?? false, delegationIndex: 0n });
  return e;
}
function claimLogs(e, mode = "direct") {
  const receiver = e.prepared.input.kind === "claimNft" ? e.prepared.input.receiver : e.claim.beneficiary;
  const logs = e.claimCompleted ? [event(c.core, A(2), "Transfer", [A(1), receiver, 100n]),
    event(c.distributor, A(1), "AirdropNftClaimCompleted", [1n, 7n, 100n, receiver])] : [];
  return stamp(e, logs, mode);
}
const capture = e => w.captureDistributionMerkle(e.provider, e.d, e.prepared, { blockTag: 10 });
const simulate = (e, saved) => w.simulateDistributionMerkle(e.provider, saved, { blockTag: 11, gasLimit: 9000000n });
const receipt = (e, saved, options) => w.reconcileDistributionMerkleReceipt(e.provider, saved, H("tx"), options);
function renumber(e) { e.receipt.logs.forEach((log, index) => { log.index = index; }); }
function eventIndex(e, key, name) { return e.receipt.logs.findIndex(log => log.topics[0] === c[key].getEvent(name).topicHash); }

test("preconfiguration getter uses actual Manager-selected definition and keeps admission separate", async () => {
  const e = setup();
  e.intercept = ({ name }) => { if (name === "phase") throw Error("phase does not exist yet"); };
  const found = await w.inspectDistributionMerkleProgram(e.provider, e.d, e.manifest, e.selected.row.config.counterConfigHash, { blockTag: 10 });
  assert.equal(found.phaseAdmissionChecked, false);
  assert.equal(found.program.applicationConfigHash, e.program.applicationConfigHash);
  e.intercept = ({ name }) => name === "counterDefinitionForManager" ? [false, e.selected.row.definition] : undefined;
  await assert.rejects(w.inspectDistributionMerkleProgram(e.provider, e.d, e.manifest, e.selected.row.config.counterConfigHash, { blockTag: 10 }), /exist|selected|definition/i);
});

test("complete ordered extra Merkle proofs, duplicate recipients and direct/both Safe transports", async () => {
  for (const mode of ["direct", "legacy", "indexed"]) for (const deliveryMode of [0n, 1n]) {
    const e = setup({ extra: true, deliveryMode, scope: 2n });
    const saved = await capture(e);
    assert.notEqual(saved.preview.policyHash, e.batch.expectedPolicyHash);
    assert.equal(saved.preview.counters.length, 6);
    const checked = await simulate(e, saved);
    assert.deepEqual(checked.tokenIds, e.tokenIds);
    const result = await receipt(e, saved, distributionLogs(e, mode));
    assert.equal(result.tokens.length, 2);
    assert.equal(result.tokens[0].delivery, deliveryMode === 0n ? "direct" : "delivered");
    assert.equal(result.functionReturnObserved, false);
  }
});

test("prepared single and multi-token paths preserve original preview limitation and royalty snapshots", async () => {
  for (const quantity of [1, 2]) {
    const e = setup({ prepared: true, quantity, royalty: true });
    const saved = await capture(e);
    assert.equal(saved.operationRoot, quantity === 1 ? e.root : null);
    assert.equal(e.calls.some(row => row.name === "previewPreparedNativeMintOperation"), quantity === 1);
    assert.equal((await simulate(e, saved)).operationRoot, e.root);
    assert.equal((await receipt(e, saved, distributionLogs(e, "indexed"))).tokens.length, quantity);
  }
});

test("failure-isolated delivery retains claim while successful callback may onward transfer or burn", async () => {
  const e = setup({ diverted: [0], burned: true });
  // The first diverted token remains in custody; the successful second can burn.
  e.intercept = ({ name, args }) => name === "tokenCollectionIdentity" && args[0] === 100n ? [true, 7n, 1n, false]
    : name === "tokenLifecycle" && args[0] === 100n ? [2n] : undefined;
  const saved = await capture(e);
  const result = await receipt(e, saved, distributionLogs(e));
  assert.deepEqual(result.tokens.map(token => token.delivery), ["diverted", "delivered"]);
  assert.equal(result.tokens[0].claim.beneficiary, A(40));
});

test("exact reveal fee, zero-fee request, NOT_REQUIRED funding, bounded failure and zero provider ID", async () => {
  for (const options of [
    { reveal: "async", fee: 0n }, { reveal: "async", fee: 3n, revealSuccess: true, spent: 2n },
    { reveal: "not-required", fee: 3n }, { reveal: "disabled" }, { reveal: "instant" },
  ]) {
    const e = setup(options), saved = await capture(e);
    const result = await receipt(e, saved, distributionLogs(e, "legacy"));
    if (options.reveal === "async") assert.equal(result.tokens[0].revealAttempt.succeeded, options.revealSuccess ?? false);
    else assert.equal(result.tokens[0].revealAttempt, null);
  }
  const e = setup({ reveal: "async", fee: 3n });
  e.revealPolicy.revealFeePerTokenWei = 4n;
  await assert.rejects(capture(e), /Exact pre-mint/);
  e.revealPolicy.declared = false;
  await assert.rejects(capture(e), /ASYNC declaration/);
});

test("fresh observations reject changed definitions, currentness, replay and delegated infrastructure code", async () => {
  const e = setup(), saved = await capture(e);
  e.intercept = ({ name, tag }) => name === "nextOperationNonce" && tag === 11 ? [6n] : undefined;
  await assert.rejects(w.revalidateDistributionMerkle(e.provider, saved, { blockTag: 11 }), /operation ID|currentness/);
  e.intercept = ({ name }) => name === "sliceUsed" ? [true] : undefined;
  await assert.rejects(capture(e), /Unused distribution slice/);
  e.intercept = null;
  e.codeIntercept = target => target === A(3) ? `0xef0100${A(55).slice(2)}` : undefined;
  const next = structuredClone(e.d); next.manager.codeHash = keccak256(`0xef0100${A(55).slice(2)}`);
  await assert.rejects(w.captureDistributionMerkle(e.provider, next, e.prepared, { blockTag: 10 }), /runtime pin/);
});

test("saved capture owns inputs, rejects proof/current RPC contradictions and explicit simulation bounds", async () => {
  const e = setup(), request = structuredClone(e.prepared), d = structuredClone(e.d);
  const originalBlock = e.provider.getBlock;
  e.provider.getBlock = async tag => { request.call.value = 999n; d.core.address = A(99); return originalBlock(tag); };
  const saved = await w.captureDistributionMerkle(e.provider, d, request, { blockTag: 10 });
  assert.equal(saved.prepared.call.value, 0n);
  assert.equal(saved.deployment.core.address, A(2));
  e.provider.getBlock = originalBlock;
  await assert.rejects(w.simulateDistributionMerkle(e.provider, saved, { blockTag: 9, gasLimit: 1n }), /predates/);
  await assert.rejects(w.simulateDistributionMerkle(e.provider, saved, { blockTag: 11, gasLimit: 0n }), /gas/);
  const changed = structuredClone(saved); changed.prepared.input.proofs[0][0].maxCount = 0n;
  await assert.rejects(w.revalidateDistributionMerkle(e.provider, changed, { blockTag: 11 }));
  e.intercept = ({ name }) => name === "canMint" ? [{ ...e.preview, counters: e.rows.slice(1) }] : undefined;
  await assert.rejects(capture(e), /row ordering|preview\/read joins/);
});

test("original late failure propagates and unchanged readback permits review retry without rollback claim", async () => {
  const e = setup(), saved = await capture(e);
  e.intercept = ({ name }) => { if (name === "distribute") throw Object.assign(Error("late reveal funding failure"), { code: "CALL_EXCEPTION" }); };
  await assert.rejects(simulate(e, saved), /late reveal/);
  assert.equal((await w.revalidateDistributionMerkle(e.provider, saved, { blockTag: 11 })).operationRoot, e.root);
  e.intercept = null;
  assert.equal((await simulate(e, saved)).operationRoot, e.root);
});

test("own/delegated/self-alias claims direct and both Safe layouts distinguish retained false from delivery", async () => {
  for (const mode of ["direct", "legacy", "indexed"]) for (const kind of ["claimNft", "claimNftFor"]) for (const completed of [false, true]) {
    const e = claimSetup(kind, { completed, walletWide: mode === "indexed" }), saved = await capture(e);
    assert.equal((await simulate(e, saved)).delivered, completed);
    const result = await receipt(e, saved, claimLogs(e, mode));
    assert.equal(result.claimOutcome, completed ? "completed" : "retained");
    assert.equal(result.functionReturnObserved, false);
  }
  const alias = claimSetup("claimNftFor", { self: true });
  alias.intercept = ({ name }) => { if (name === "globalDelegationHashes") throw Error("self alias must ignore witness"); };
  await capture(alias);
  assert.ok(alias.codes.some(([target]) => target === A(9)));
});

test("claim exits survive commerce outages but delegated helper and original six-word witness remain pinned", async () => {
  for (const kind of ["claimNft", "claimNftFor"]) {
    const e = claimSetup(kind);
    e.codeIntercept = target => [A(3), A(4), A(5), A(8)].includes(target) ? "0x" : undefined;
    const saved = await capture(e);
    assert.equal((await receipt(e, saved, claimLogs(e))).claimOutcome, "completed");
  }
  const e = claimSetup("claimNftFor", { self: true });
  e.codeIntercept = target => target === A(9) ? "0x" : undefined;
  await assert.rejects(capture(e), /runtime pin/);
  for (const row of [[A(40), A(41), 9999n, 10000n, true, 0n], [A(40), A(41), 1n, 1010n, true, 0n],
    [A(40), A(41), 1n, 10000n, false, 0n], [A(40), A(41), 1n, 10000n, true, 1n]]) {
    const invalid = claimSetup("claimNftFor");
    invalid.intercept = ({ name }) => name === "globalDelegationHashes" ? row : undefined;
    await assert.rejects(capture(invalid), /delegation row/);
  }
});

test("claim read is local and claim authority is original beneficiary, not an unrelated wallet", async () => {
  const e = claimSetup();
  e.codeIntercept = target => target === A(1) ? code : "0x";
  assert.equal((await w.inspectDistributionMerkleClaim(e.provider, e.d, 100n, { blockTag: 10 })).claim.beneficiary, A(40));
  const invalid = claimSetup("claimNft", { caller: A(77) });
  await assert.rejects(capture(invalid), /Own claim principal/);
  const absent = setup();
  assert.deepEqual((await w.inspectDistributionMerkleClaim(absent.provider, absent.d, 0n, { blockTag: 10 })).claim, emptyClaim);
});

test("receipt rejects missing/reordered mint, Ledger, slice and counter outcome evidence", async () => {
  for (const action of [
    e => e.receipt.logs.splice(eventIndex(e, "manager", "MintAuthorizationConsumed"), 1),
    e => e.receipt.logs.reverse(),
    e => { e.intercept = ({ name, post }) => name === "counterValue" && post ? [0n] : undefined; },
    e => { e.intercept = ({ name, post }) => name === "nextOperationNonce" && post ? [99n] : undefined; },
  ]) {
    const e = setup(), saved = await capture(e), options = distributionLogs(e);
    action(e); renumber(e);
    await assert.rejects(receipt(e, saved, options));
  }
  const e = setup({ prepared: true, royalty: true }), saved = await capture(e), options = distributionLogs(e);
  e.intercept = ({ name }) => name === "royaltySnapshot" ? [{ exists: false, collectionId: 7n, tokenId: 100n,
    manager: A(3), operationRoot: e.root, operationId: e.ids[0], preparedProofHash: H("p"), electionHash: H("e"),
    sourceAssignmentHash: H("s"), modeAssignmentHash: H("m"), sourceRoyaltyPolicyHash: H("r"),
    tokenAssignmentHash: H("a"), tokenRoyaltyPolicyHash: H("b"), tokenConfigHash: H("c") }] : undefined;
  await assert.rejects(receipt(e, saved, options), /royalty snapshot/);
});

test("Safe exact CALL/value/calldata/hash/order and complete immutable receipt metadata", async () => {
  for (const mutate of [
    (e, options) => { options.expectedSafeTxHash = H("wrong"); },
    e => { const args = Array.from(safe.decodeFunctionData("execTransaction", e.tx.data)); args[3] = 1n; e.tx.data = safe.encodeFunctionData("execTransaction", args); },
    e => { const args = Array.from(safe.decodeFunctionData("execTransaction", e.tx.data)); args[1] = 1n; e.tx.data = safe.encodeFunctionData("execTransaction", args); },
    e => { e.receipt.logs.unshift(e.receipt.logs.pop()); renumber(e); },
    e => { const last = e.receipt.logs.at(-1); Object.assign(last, safe.encodeEventLog(safe.getEvent("ExecutionFailure"), [H("safe transaction"), 0n])); },
    e => { e.receipt.logs[0].removed = true; },
    e => { e.receipt.logs[0].index = NaN; },
    e => { delete e.receipt.logs[0].transactionHash; },
    e => { e.receipt.to = A(99); },
  ]) {
    const e = setup(), saved = await capture(e), options = distributionLogs(e, "legacy");
    mutate(e, options);
    await assert.rejects(receipt(e, saved, options));
  }
  const e = setup(), saved = await capture(e), options = distributionLogs(e, "indexed");
  const originalGetBlock = e.provider.getBlock;
  e.provider.getBlock = async tag => { e.receipt.logs.length = 0; return originalGetBlock(tag); };
  assert.equal((await receipt(e, saved, options)).tokens.length, 2);
});

test("real shared Safe planner round trip preserves original distributor selector and positive reveal value", async () => {
  const e = setup({ reveal: "async", fee: 3n });
  const plan = createSafeCallPlan(e.d.chainId, "Merkle distribution", [{ safe: e.prepared.caller,
    intent: "Execute the reviewed recipient slice", call: e.prepared.call, abi: fixture.abis.distributor }]);
  const checked = verifySafeCallPlan(plan, [fixture.abis.distributor]);
  assert.equal(checked.steps[0].transaction.value, "6");
  assert.equal(checked.steps[0].transaction.operation, 0);
  const bad = structuredClone(plan); bad.steps[0].transaction.operation = 1;
  assert.throws(() => verifySafeCallPlan(bad, [fixture.abis.distributor]));
});

test("gate event retains bound policy while Ledger and batch preserve distinct current policy", async () => {
  const e = setup();
  e.preview.gateHash = H("gate result");
  e.intercept = ({ name }) => name === "phaseGate" ? [{ gate: A(12), gateConfigHash: H("gate configuration"),
    gateCodehash: keccak256(code), gateMetadataHash: H("gate metadata"), gateSemanticVersion: 1n, gateGasLimit: 200000n }] : undefined;
  const saved = await capture(e), options = distributionLogs(e);
  const gate = event(c.manager, A(3), "MintGateValidated", [7n, e.batch.phaseId, A(12), e.batch.authorizationId,
    ZeroAddress, 2n, e.batch.contextHash, e.preview.gateHash, e.batch.expectedPolicyHash]);
  e.receipt.logs.splice(2, 0, { ...e.receipt.logs[0], ...gate });
  const batchIndex = eventIndex(e, "manager", "MintBatchExecuted");
  const parsed = c.manager.parseLog(e.receipt.logs[batchIndex]);
  const batchArgs = Array.from(parsed.args); batchArgs[10] = e.preview.gateHash;
  Object.assign(e.receipt.logs[batchIndex], c.manager.encodeEventLog(c.manager.getEvent("MintBatchExecuted"), batchArgs));
  renumber(e);
  assert.equal((await receipt(e, saved, options)).operationRoot, e.root);
  const bad = c.manager.encodeEventLog(c.manager.getEvent("MintGateValidated"), [7n, e.batch.phaseId, A(12),
    e.batch.authorizationId, ZeroAddress, 2n, e.batch.contextHash, e.preview.gateHash, e.currentPolicy]);
  Object.assign(e.receipt.logs[2], bad);
  await assert.rejects(receipt(e, saved, options), /MintGateValidated|event policyHash/);
});

test("mined phase and previous-policy grace are inclusive while delegation expiry is strict", async () => {
  for (const boundary of ["phase", "grace"]) for (const deadline of [1012n, 1011n]) {
    const e = setup();
    e.intercept = ({ name }) => {
      if (boundary === "phase" && name === "phase") return [true, { paused: false, startTime: 0n,
        endTime: deadline, maxBatchQuantity: 10n, configHash: e.program.applicationConfigHash, metadataHash: H("phase metadata") }];
      if (boundary === "grace" && name === "policyGrace") return [e.batch.expectedPolicyHash, 1n, deadline];
    };
    const saved = await capture(e), options = distributionLogs(e);
    if (deadline === 1012n) assert.equal((await receipt(e, saved, options)).tokens.length, 2);
    else await assert.rejects(receipt(e, saved, options), /expired at mined/);
  }
  for (const completed of [false, true]) for (const expiry of [1012n, 1013n]) {
    const e = claimSetup("claimNftFor", { completed });
    e.intercept = ({ name }) => name === "globalDelegationHashes" ? [A(40), A(41), 1010n, expiry, true, 0n] : undefined;
    const saved = await capture(e), options = claimLogs(e);
    if (expiry === 1013n) assert.equal((await receipt(e, saved, options)).claimOutcome, completed ? "completed" : "retained");
    else await assert.rejects(receipt(e, saved, options), /delegation expired at mined/);
  }
});

test("receipt complete reveal accounting rejects omitted funding, mutated bounded failure and order", async () => {
  for (const mutation of [
    e => e.receipt.logs.splice(eventIndex(e, "entropy", "RevealFeeEscrowFunded"), 1),
    e => { e.escrowAfter++; },
    e => {
      const fragment = Object.values(c).map(value => value.getEvent("ImmediateRevealAttempt")).find(Boolean);
      const ix = e.receipt.logs.findIndex(log => log.topics[0] === fragment.topicHash);
      const changed = event(c.distributor, A(1), "ImmediateRevealAttempt", [1n, 7n, 100n, false, zero, 0n, 300n, "0xaa"]);
      Object.assign(e.receipt.logs[ix], changed);
    },
    e => {
      const ix = eventIndex(e, "entropy", "RevealFeeEscrowFunded");
      const row = e.receipt.logs.splice(ix, 1)[0]; e.receipt.logs.splice(-1, 0, row);
    },
  ]) {
    const e = setup({ reveal: "async", fee: 3n }), saved = await capture(e), options = distributionLogs(e);
    mutation(e); renumber(e);
    await assert.rejects(receipt(e, saved, options));
  }
});

test("retained claims require unchanged local custody and completion requires original receiver transfer", async () => {
  const retained = claimSetup("claimNftFor", { completed: false }), saved = await capture(retained), options = claimLogs(retained, "indexed");
  retained.intercept = ({ name, post }) => name === "ownerOf" && post ? [A(99)] : undefined;
  await assert.rejects(receipt(retained, saved, options), /Retained claim custody/);
  const completed = claimSetup(), before = await capture(completed), opts = claimLogs(completed);
  completed.receipt.logs[0] = { ...completed.receipt.logs[0], ...event(c.core, A(2), "Transfer", [A(1), A(43), 100n]) };
  await assert.rejects(receipt(completed, before, opts), /Claim delivery transfer/);
});

test("receipt outer calldata uses bounded allocation and rejects unknown transport or inconsistent block", async () => {
  const e = setup(), saved = await capture(e), options = distributionLogs(e);
  await assert.rejects(receipt(e, saved, { execution: "delegatecall" }), /transport|execution/i);
  e.tx.data = `0x${"00".repeat(4 * 1024 * 1024 + 16385)}`;
  await assert.rejects(receipt(e, saved, options), /Bounded canonical bytes/);
  distributionLogs(e);
  e.blockIntercept = tag => ({ number: tag, hash: H("different canonical block"), timestamp: 1000 + tag });
  await assert.rejects(receipt(e, saved, options), /block|Reorg/i);
});
