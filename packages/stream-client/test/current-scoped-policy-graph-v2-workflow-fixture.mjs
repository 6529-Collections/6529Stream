// Compiler-ABI RPC fixtures. They establish client joins, not Solidity CREATE/native admission.
import { AbiCoder, Interface, ZeroAddress, ZeroHash, getAddress, id, keccak256 } from "ethers";
import * as pure from "../dist/current-scoped-policy-graph-v2.js";
import { fixture, compiledInterfaces as c } from "./current-scoped-policy-graph-v2-fixture.mjs";

export const A = n => getAddress(`0x${BigInt(n).toString(16).padStart(40, "0")}`);
export const H = n => `0x${BigInt(n).toString(16).padStart(64, "0")}`;
export const code = target => `0x6000${target.slice(2)}`;
export const pin = target => ({ address: target, codeHash: keccak256(code(target)) });
export const coder = AbiCoder.defaultAbiCoder();
export const safe = new Interface([
  "function execTransaction(address to,uint256 value,bytes data,uint8 operation,uint256 safeTxGas,uint256 baseGas,uint256 gasPrice,address gasToken,address refundReceiver,bytes signatures) returns(bool success)",
  "event ExecutionSuccess(bytes32 txHash,uint256 payment)",
  "event ExecutionFailure(bytes32 txHash,uint256 payment)"
]);
const unique = new Map();
for (const entry of Object.values(fixture.abis).flat()) {
  if (entry.type !== "function") continue;
  const f = new Interface([entry]).fragments[0];
  if (!unique.has(f.format("sighash"))) unique.set(f.format("sighash"), entry);
}
const all = new Interface([...unique.values()]);
function plain(param, value) {
  if (param.baseType === "array") return value.map(item => plain(param.arrayChildren, item));
  if (param.baseType === "tuple") return Object.fromEntries(param.components.map((p, i) => [p.name, plain(p, value[i])]));
  return value;
}
function zero(param) {
  if (param.baseType === "array") return Array.from({ length: Math.max(0, param.arrayLength) }, () => zero(param.arrayChildren));
  if (param.baseType === "tuple") return Object.fromEntries(param.components.map(p => [p.name, zero(p)]));
  if (param.type === "address") return ZeroAddress;
  if (param.type === "bool") return false;
  if (param.type.startsWith("uint")) return 0n;
  if (param.type.startsWith("bytes")) return `0x${"00".repeat(Number(param.type.slice(5)) || 0)}`;
  if (param.type === "string") return "";
  throw Error(param.type);
}

export function setup(options = {}) {
  const chainId = 1n;
  const core = A(1), metadata = A(2), router = A(5), membershipHost = A(6), selection = A(7), coordinatorInventory = A(8);
  const tokenInventory = A(9), executor = A(10), sourceFactory = A(101), publicationFactory = A(102), set = A(103);
  const providerAddress = A(104), discoveryAddress = A(105), registry = A(106), caller = A(30);
  const childAddresses = Array.from({ length: 7 }, (_, i) => A(200 + i));
  const targets = [core, metadata, A(3), A(4), router, ZeroAddress, ZeroAddress, A(11), A(12), A(13), A(14), A(15)];
  const gasRow = (name, failureClass = 2n) => ({ name, genesisValue: 200000n, floor: 50000n, failureClass });
  const recipe = {
    inventory: { targets, codeHashes: targets.map(a => a === ZeroAddress ? ZeroHash : pin(a).codeHash),
      artistTargets: [A(20), A(21), A(22), A(23), A(24)], artistCodeHashes: [20, 21, 22, 23, 24].map(n => pin(A(n)).codeHash),
      artistContentOwner: A(25), artistContentOwnerCodeHash: pin(A(25)).codeHash, chainId,
      readGas: 100000n, sourceGas: 200000n, selectionGas: 200000n, snapshotGas: 200000n, referenceGas: 200000n },
    targets: [membershipHost, selection, sourceFactory, executor], codeHashes: [membershipHost, selection, sourceFactory, executor].map(a => pin(a).codeHash),
    readinessReadGas: 100000n, readinessSourceGas: 200000n, factorySourceGas: 2000000n, bundleReadGas: 100000n, bundleArchiveGas: 200000n,
    checkpointGas: [gasRow("STATIC_CONTENT_READ_GAS"), gasRow("STATIC_CONTENT_RENDER_GAS")], outputGas: gasRow("STATIC_OUTPUT_MANIFEST_READ_GAS"),
    snapshotGas: [gasRow("SCOPED_POLICY_SNAPSHOT_READ_GAS"), gasRow("SCOPED_POLICY_SNAPSHOT_SOURCE_GAS"), gasRow("SCOPED_POLICY_SNAPSHOT_INVENTORY_GAS")],
    referenceGas: [gasRow("SCOPED_POLICY_REFERENCE_READ_GAS", 1n), gasRow("SCOPED_POLICY_REFERENCE_SOURCE_GAS", 1n),
      gasRow("SCOPED_POLICY_REFERENCE_SNAPSHOT_GAS", 1n), gasRow("SCOPED_POLICY_REFERENCE_ARCHIVE_GAS", 1n)]
  };
  const dependencies = { targets: [core, metadata, membershipHost, coordinatorInventory],
    codeHashes: [core, metadata, membershipHost, coordinatorInventory].map(a => pin(a).codeHash), chainId, readGas: 100000n, inventoryGas: 200000n };
  const coordinates = { chainId, sourceFactory, publicationFactory };
  const scope = options.scope ?? { scopeType: 1n, collectionId: 7n, tokenId: 11n, scopeId: ZeroHash };
  const membership = { scopeSubject: pure.scopedPolicyGraphV2ScopeSubject(chainId, core, scope), scopeManifestHash: H(21), sourceRecordHash: H(22),
    tokenCount: options.mixed ? 2n : 1n, tokenListHash: H(24), membershipHash: H(25), inventoryCount: 1n, inventoryPrefixHash: H(26) };
  const plan = pure.scopedPolicyGraphV2InventoryPlan(dependencies, scope, membership);
  const policy = { configured: true, explicitPolicy: true, frozen: true, mode: 0n, securityClass: 0n, renderRequirement: 1n,
    revision: 1n, providerEpoch: 0n, policyHash: H(40), contentStateHash: ZeroHash, lastActionId: H(41), artistConsentRecord: H(42) };
  policy.contentStateHash = keccak256(coder.encode(["bytes32", "bytes32", "bool"], [id("6529STREAM_ENTROPY_CONFIGURATION_V1"), policy.policyHash, true]));
  const makePolicy = (n, index, explicit) => {
    const p = { coordinator: A(n), indexedCodeHash: pin(A(n)).codeHash, firstTokenIndex: BigInt(index), frozen: true,
      moduleVersion: H(51), moduleManifestHash: H(52), moduleSchemaHash: H(53), deploymentManifestHash: H(54), policyHash: explicit ? policy.policyHash : H(55),
      provider: explicit ? ZeroAddress : A(71), epoch: explicit ? 0n : 1n, salt: explicit ? ZeroHash : H(56), componentDataHash: ZeroHash,
      explicitPolicy: explicit, collectionPolicy: explicit ? policy : pure.scopedPolicyGraphV2EmptyPolicy() };
    p.componentDataHash = explicit ? keccak256(coder.encode(["bytes32", "uint256", "address", "address", pure.SCOPED_POLICY_GRAPH_V2_SCOPE_TUPLE,
      pure.SCOPED_POLICY_GRAPH_V2_POLICY_TUPLE], [id("6529STREAM_ENTROPY_COMPONENT_EVIDENCE_V2"), chainId, core, A(n), scope, policy]))
      : keccak256(coder.encode(["bytes32", "uint256", "address", "address", pure.SCOPED_POLICY_GRAPH_V2_SCOPE_TUPLE, "bytes32", "address", "uint32", "bytes32"],
        [id("6529STREAM_ENTROPY_COMPONENT_EVIDENCE_V1"), chainId, core, A(n), scope, p.policyHash, p.provider, p.epoch, p.salt]));
    return p;
  };
  const policies = [makePolicy(70, 0, true), ...(options.mixed ? [makePolicy(72, 1, false)] : [])];
  const originals = policies.map(({ coordinator, indexedCodeHash, firstTokenIndex }) => ({ coordinator, indexedCodeHash, firstTokenIndex }));
  const progress = { exists: true, complete: true, processedTokens: membership.tokenCount, tokenCount: membership.tokenCount,
    coordinatorCount: BigInt(policies.length), tokenChain: H(60), coordinatorChain: pure.scopedPolicyGraphV2CoordinatorChain(plan, originals), commitment: ZeroHash };
  progress.commitment = pure.scopedPolicyGraphV2InventoryCommitment(plan, progress);
  const policyChainHash = pure.scopedPolicyGraphV2PolicyChain(dependencies, scope, plan, progress.commitment, policies);
  const manifestHash = pure.scopedPolicyGraphV2SourceSetManifestHash(dependencies, tokenInventory, pin(tokenInventory).codeHash);
  const dataHash = pure.scopedPolicyGraphV2SourceSetDataHash(scope, plan, progress.commitment, policyChainHash, membership, tokenInventory, pin(tokenInventory).codeHash);
  const deployment = { chainId, sourceFactory: pin(sourceFactory), publicationFactory: pin(publicationFactory),
    recipeHash: pure.scopedPolicyGraphV2RecipeHash(chainId, recipe), sourceFactoryDependenciesHash: pure.scopedPolicyGraphV2DependenciesHash(dependencies),
    linkedDependencies: [pin(A(110)), pin(A(111))] };
  const graphId = pure.scopedPolicyGraphV2GraphId(coordinates, deployment.recipeHash, deployment.sourceFactoryDependenciesHash, scope, plan, set, pin(set).codeHash);
  const emptyGraph = zero(c.publicationFactory.getFunction("graphForPlan").outputs[0]);
  function graphAt(count) {
    if (count === 0) return structuredClone(emptyGraph);
    return { scope, inventoryPlan: plan, sourceSet: set, sourceSetCodeHash: pin(set).codeHash, graphId,
      children: childAddresses.map((a, i) => i < count ? a : ZeroAddress), codeHashes: childAddresses.map((a, i) => i < count ? pin(a).codeHash : ZeroHash),
      preparedChildren: BigInt(count) };
  }
  const full = graphAt(7);
  const beforeCount = options.beforeCount ?? 0, afterCount = options.afterCount ?? Math.min(7, beforeCount + (options.maximumChildren ?? 3));
  const state = { beforeCount, afterCount, sourceBefore: options.sourceBefore ?? true, sourceAfter: options.sourceAfter ?? true, tagged: options.tagged ?? false,
    failCurrent: false, wrongSelection: false, missingCode: new Set(), network: chainId, blockHashes: new Map(), calls: [], hooks: {}, raw: null };
  const oldTargets = Array.from({ length: 22 }, (_, i) => A(400 + i));
  const map = [0, 1, 4, 5, 2, 8, 9, 15, 16, 17, 20, 21];
  targets.forEach((a, i) => { if (i !== 5 && i !== 6) oldTargets[map[i]] = a; });
  oldTargets[3] = membershipHost; oldTargets[11] = A(20);
  const native = { targets: oldTargets, codeHashes: oldTargets.map(a => pin(a).codeHash), chainId,
    readGas: 100000n, sourceGas: 2000000n, componentSourceGas: 10000000n, inventoryDependencyHash: H(500) };
  const binding = { factory: publicationFactory, factoryCodeHash: pin(publicationFactory).codeHash, recipeHash: deployment.recipeHash,
    sourceFactoryDependenciesHash: deployment.sourceFactoryDependenciesHash, graphGas: 2000000n, configurationHash: ZeroHash };
  binding.configurationHash = pure.scopedPolicyGraphV2ProviderConfigurationHash(providerAddress, native, binding);
  const discoveryDeployment = { graph: deployment, provider: pin(providerAddress), discovery: pin(discoveryAddress),
    configurationHash: binding.configurationHash, sourceConfigurationHash: H(501), linkedDependencies: [pin(A(112))] };
  const snapshotProfile = "0x2a9edb22fe6d8eb7105c2964dbcea97284c317242a3ee0c544dc04e6c3a4870b";
  const root = zero(c.router.getFunction("scopedPolicyContentRootBinding").outputs[0]);
  Object.assign(root, { profileId: id("6529STREAM_SCOPED_POLICY_CONTENT_ROOT_V2"), outputManifest: childAddresses[2], outputManifestCodeHash: pin(childAddresses[2]).codeHash,
    checkpoint: childAddresses[1], checkpointCodeHash: pin(childAddresses[1]).codeHash, entropySourceSet: set, entropySourceSetCodeHash: pin(set).codeHash,
    sourceFactory, sourceFactoryCodeHash: pin(sourceFactory).codeHash, factoryDependenciesHash: deployment.sourceFactoryDependenciesHash, snapshotProfileHash: snapshotProfile });
  function pointer(target, kind, iface) { return [target, pin(target).codeHash, false, kind, iface, registry, 1n, H(800), H(801), 1n]; }
  const families = ["METADATA_ROUTER", "RENDERER", "RENDER_CONTEXT", "MEDIA_MANIFEST", "SCRIPT_SOURCE", "DEPENDENCY_SOURCE", "COLLECTION_METADATA", "ENTROPY_COORDINATOR", "REFERENCE_RENDER", "ARTIST_SANCTION"];
  function routes(includeSanction) {
    return families.slice(0, includeSanction ? 10 : 9).map((name, i) => ({ componentType: id(name),
      component: name === "ENTROPY_COORDINATOR" && state.tagged ? set : name === "REFERENCE_RENDER" && state.tagged ? childAddresses[4] : A(600 + i),
      interfaceId: "0x8004d4f5", codeHash: pin(name === "ENTROPY_COORDINATOR" && state.tagged ? set : name === "REFERENCE_RENDER" && state.tagged ? childAddresses[4] : A(600 + i)).codeHash
    })).sort((a, b) => BigInt(a.componentType) < BigInt(b.componentType) ? -1 : 1);
  }
  const provider = {
    getNetwork: async () => { await state.hooks.network?.(); return { chainId: state.network }; },
    getBlock: async tag => ({ number: tag, hash: state.blockHashes.get(tag) ?? H(1000 + tag), timestamp: 1000 + tag }),
    getCode: async (target, tag) => { const changed = await state.hooks.code?.(target, tag); return changed ?? (state.missingCode.has(target) ? "0x" : code(target)); },
    call: async tx => {
      const target = getAddress(tx.to), tag = tx.blockTag;
      const iface = target === sourceFactory ? c.sourceFactory : target === publicationFactory ? c.publicationFactory
        : target === childAddresses[3] ? c.snapshot : target === childAddresses[4] ? c.reference : all;
      const parsed = iface.parseTransaction({ data: tx.data });
      if (!parsed) throw Error("Unknown RPC calldata");
      const method = parsed.name, args = parsed.args;
      state.calls.push({ target, method, args, tag, from: tx.from, value: tx.value, gasLimit: tx.gasLimit });
      const event = { target, method, args, tag, tx, iface };
      const override = await state.hooks.call?.(event);
      if (override !== undefined) return typeof override === "string" ? override : iface.encodeFunctionResult(method, override);
      const count = tag >= 12 ? state.afterCount : state.beforeCount;
      const hasSet = tag >= 12 ? state.sourceAfter : state.sourceBefore;
      const row = policies.find(p => p.coordinator === target);
      let values;
      if (method === "supportsInterface") values = [args[0] !== "0xffffffff" && (args[0] !== "0x4583f7e1" || row?.explicitPolicy !== false)];
      else if (method === "recipe") values = [recipe];
      else if (method === "recipeHash") values = [deployment.recipeHash];
      else if (method === "sourceFactoryDependenciesHash") values = [deployment.sourceFactoryDependenciesHash];
      else if (method === "scopedPolicyPublicationFactoryProfile") values = [pure.SCOPED_POLICY_GRAPH_V2_PROFILE];
      else if (method === "scopedPolicyFactoryProfile") values = [pure.SCOPED_POLICY_GRAPH_V2_SOURCE_FACTORY_PROFILE];
      else if (method === "dependencies") values = [target === sourceFactory ? dependencies : target === childAddresses[3]
        ? pure.scopedPolicyGraphV2SnapshotDependencies(recipe, full) : pure.scopedPolicyGraphV2ReferenceDependencies(recipe, full)];
      else if (method === "core") values = [core];
      else if (method === "metadataHost") values = [metadata];
      else if (method === "metadataRouter") values = [router];
      else if (method === "entropySourceFactory") values = [sourceFactory];
      else if (method === "scopeMembershipHost" || method === "scopeMembership") values = [membershipHost];
      else if (method === "coordinatorInventory") values = [coordinatorInventory];
      else if (method === "coreCodeHash") values = [pin(core).codeHash];
      else if (method === "scopeMembershipCodeHash") values = [pin(membershipHost).codeHash];
      else if (method === "deploymentChainId") values = [chainId];
      else if (method === "currentInventoryPlan") values = [plan];
      else if (method === "requireScopeMembership") values = [membership];
      else if (method === "requireCompleteInventory") values = [progress];
      else if (method === "inventoryScope") values = [scope, membership];
      else if (method === "requireCoordinator") values = [originals[Number(args[1])]];
      else if (method === "streamModuleType") values = [target === metadata ? id("COLLECTION_METADATA") : target === router ? id("METADATA_ROUTER") : id("ENTROPY_COORDINATOR")];
      else if (method === "streamModuleInterfaceId") values = [target === metadata ? "0x7e8260f8" : target === router ? "0x222d4427" : "0x979b977f"];
      else if (method === "streamModuleCodeHash") values = [pin(target).codeHash];
      else if (method === "streamModuleVersion") values = [row.moduleVersion];
      else if (method === "streamModuleManifest") values = ["ipfs://original", row.moduleManifestHash];
      else if (method === "streamModuleSchemaHash") values = [row.moduleSchemaHash];
      else if (method === "streamModuleDeploymentManifestHash") values = [row.deploymentManifestHash];
      else if (method === "collectionEntropyPolicy") values = [row.collectionPolicy];
      else if (method === "entropyPolicyFrozen") values = row.explicitPolicy ? [false, ZeroHash, ZeroAddress, 0n, ZeroHash]
        : [row.frozen, row.policyHash, row.provider, row.epoch, row.salt];
      else if (method === "tokenInventory") values = [tokenInventory];
      else if (method === "sourceSetForPlan") values = hasSet ? [set, pin(set).codeHash] : [ZeroAddress, ZeroHash];
      else if (method === "factory") values = [sourceFactory];
      else if (method === "inventoryPlan") values = [plan];
      else if (method === "originalInventoryHash") values = [progress.commitment];
      else if (method === "originalPolicyChainHash") values = [policyChainHash];
      else if (method === "tokenInventoryCodeHash") values = [pin(tokenInventory).codeHash];
      else if (method === "sourceSetDataHash") values = [dataHash];
      else if (method === "sourceSetManifestHash") values = [manifestHash];
      else if (method === "sourceScope") values = [scope];
      else if (method === "scopeMembershipFacts") values = [membership];
      else if (method === "sourceCount") values = [BigInt(policies.length)];
      else if (method === "sourcePolicyAt") values = [policies[Number(args[0])]];
      else if (method === "requireCurrentSourceSet" || method === "requireCurrentSelection") {
        if (state.failCurrent) throw Object.assign(Error("original source drift"), { code: "CALL_EXCEPTION" });
        values = [];
      } else if (method === "requireCurrentRoute") {
        if (state.failCurrent) throw Object.assign(Error("original route drift"), { code: "CALL_EXCEPTION" });
        values = [{ componentType: id("ENTROPY_COORDINATOR"), component: set, interfaceId: "0x8004d4f5", codeHash: pin(set).codeHash }];
      } else if (method === "graphForPlan") values = [args[0] === plan ? graphAt(count) : emptyGraph];
      else if (method === "prepareGraph") {
        if (state.failCurrent) throw Object.assign(Error("original graph refusal"), { code: "CALL_EXCEPTION" });
        values = [graphAt(Math.min(7, count + Number(args[1])))];
      } else if (method === "prepareSourceSet") {
        if (state.failCurrent) throw Object.assign(Error("original source refusal"), { code: "CALL_EXCEPTION" });
        values = [set];
      } else if (method === "requireCurrentGraph") {
        if (count !== 7 || state.failCurrent) throw Object.assign(Error("original graph incomplete/stale"), { code: "CALL_EXCEPTION" });
        values = [graphAt(count)];
      } else if (method === "getSatellitePointer") values = args[0] === id("MODULE_REGISTRY")
        ? pointer(registry, id("MODULE_REGISTRY"), "0x12345678") : args[0] === id("COLLECTION_METADATA")
          ? pointer(state.wrongSelection ? A(999) : metadata, id("COLLECTION_METADATA"), "0x7e8260f8") : pointer(router, id("METADATA_ROUTER"), "0x222d4427");
      else if (method === "isModuleEligible") values = [true];
      else if (method === "schemaRegistry") values = [A(3)];
      else if (method === "chunkStore") values = [A(4)];
      else if (method === "governanceAuthority") values = [executor];
      else if (method === "executorCodeHash") values = [pin(executor).codeHash];
      else if (method === "dependencyHash") values = [keccak256(coder.encode([target === childAddresses[5]
        ? pure.SCOPED_POLICY_GRAPH_V2_INVENTORY_DEPENDENCIES_TUPLE : pure.SCOPED_POLICY_GRAPH_V2_BUNDLE_DEPENDENCIES_TUPLE],
      [target === childAddresses[5] ? pure.scopedPolicyGraphV2InventoryDependencies(recipe, full) : pure.scopedPolicyGraphV2BundleDependencies(recipe, full)]))];
      else if (method === "nativeConfiguration") values = [native];
      else if (method === "scopedPolicyPublicationBinding") values = [binding];
      else if (method === "finalitySourceConfigurationHash" || method === "sourceConfigurationHash") values = [discoveryDeployment.sourceConfigurationHash];
      else if (method === "scopeEvidenceProvider") values = [providerAddress];
      else if (method === "scopedPolicySnapshotHost") values = [childAddresses[3]];
      else if (method === "scopedPolicySnapshotCodeHash") values = [pin(childAddresses[3]).codeHash];
      else if (method === "scopedPolicySnapshotProfile") values = [id("6529STREAM_SCOPED_POLICY_SNAPSHOT_V2")];
      else if (method === "scopedPolicySnapshotValidationGas") values = [native.componentSourceGas];
      else if (method === "scopedContentRootHead") values = [state.tagged ? H(700) : ZeroHash];
      else if (method === "scopedPolicyContentRootBinding") values = [root];
      else if (method === "finalitySourcesForScope") values = [{ scope, profile: { profileHash: state.tagged ? snapshotProfile : H(702),
        referenceRender: state.tagged ? childAddresses[4] : A(701), referenceRenderCodeHash: pin(state.tagged ? childAddresses[4] : A(701)).codeHash,
        snapshots: state.tagged ? childAddresses[3] : A(702), snapshotsCodeHash: pin(state.tagged ? childAddresses[3] : A(702)).codeHash,
        entropyFactory: state.tagged ? sourceFactory : A(703), entropyFactoryCodeHash: pin(state.tagged ? sourceFactory : A(703)).codeHash,
        configurationHash: state.tagged ? binding.configurationHash : H(704) } }];
      else if (method === "requireCurrentRoutes") values = [routes(args[1])];
      else throw Error(`Unhandled ${method} at ${target}`);
      const changed = await state.hooks.result?.({ ...event, values });
      const encoded = iface.encodeFunctionResult(method, changed ?? values);
      return state.raw ? state.raw(event, encoded) : encoded;
    },
    getTransactionReceipt: async () => state.receipt,
    getTransaction: async () => { await state.hooks.transaction?.(); return state.transaction; }
  };
  function installReceipt(prepared, mode = "direct") {
    const txHash = H(900), blockNumber = 12, blockHash = H(1012), safeHash = H(901), logs = [];
    function event(target, iface, name, values) {
      const encoded = iface.encodeEventLog(iface.getEvent(name), values);
      logs.push({ address: target, topics: [...encoded.topics], data: encoded.data });
    }
    if (prepared.request.kind === "prepareSourceSet") {
      if (!state.sourceBefore) event(sourceFactory, c.sourceFactory, "EntropySourceSetPrepared", [plan, set, membership.scopeSubject, pin(set).codeHash, dataHash]);
    } else {
      for (let i = state.beforeCount; i < state.afterCount; i++) event(publicationFactory, c.publicationFactory, "ScopedPolicyPublicationChildPrepared",
        [2n, graphId, plan, i, childAddresses[i], pin(childAddresses[i]).codeHash]);
    }
    let to = prepared.call.to, from = caller, data = prepared.call.data;
    if (mode !== "direct") {
      to = caller; from = A(31);
      data = safe.encodeFunctionData("execTransaction", [prepared.call.to, 0n, prepared.call.data, 0, 2000000n, 0n, 0n, ZeroAddress, ZeroAddress, "0x1234"]);
      if (mode === "indexed") logs.push({ address: caller, topics: [safe.getEvent("ExecutionSuccess").topicHash, safeHash], data: coder.encode(["uint256"], [0n]) });
      else event(caller, safe, "ExecutionSuccess", [safeHash, 0n]);
    }
    state.receipt = { status: 1, hash: txHash, from, to, blockNumber, blockHash, logs };
    state.transaction = { hash: txHash, from, to, blockNumber, blockHash, chainId, data, value: 0n };
    renumber();
    return { txHash, options: mode === "direct" ? { execution: "direct" } : { execution: "safe", expectedSafeTxHash: safeHash } };
  }
  function renumber() {
    state.receipt.logs.forEach((log, i) => Object.assign(log, { index: i, transactionHash: state.receipt.hash,
      blockNumber: state.receipt.blockNumber, blockHash: state.receipt.blockHash, removed: false }));
  }
  return { provider, state, deployment, coordinates, scope, recipe, dependencies, membership, policies, originals, progress, plan, set, graphId,
    graphAt, full, beforeCount, afterCount, childAddresses, caller, dataHash, manifestHash, policyChainHash, binding, native, root, discoveryDeployment,
    installReceipt, renumber, c, pure };
}
