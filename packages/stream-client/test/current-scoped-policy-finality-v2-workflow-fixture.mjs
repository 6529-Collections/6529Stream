// Compiler-shaped RPC evidence only. Graph, sanction and Executor admission are mocked,
// not an independently executed Solidity/Safe lifecycle or native gas measurement.
import { Interface, ZeroAddress as Z, ZeroHash as H0, getAddress, id, keccak256, toUtf8Bytes, hexlify } from "ethers";
import * as p from "../dist/current-scoped-policy-finality-v2.js";
import * as inv from "../dist/current-scoped-policy-inventory-v2.js";
import * as bun from "../dist/current-scoped-policy-bundle-v2.js";
import * as g from "../dist/current-scoped-policy-graph-v2.js";
import { setup as graphSetup, A, H, pin, code, coder, safe } from "./current-scoped-policy-graph-v2-workflow-fixture.mjs";
import { fixture, compiledInterfaces as c } from "./current-scoped-policy-finality-v2-fixture.mjs";
export { A, H, pin, code, coder, safe, c, p, fixture };

export function zero(param) {
  if (param.baseType === "array") return Array.from({ length: Math.max(0, param.arrayLength) }, () => zero(param.arrayChildren));
  if (param.baseType === "tuple") return Object.fromEntries(param.components.map(v => [v.name, zero(v)]));
  if (param.type === "address") return Z;
  if (param.type === "bool") return false;
  if (param.type.startsWith("uint")) return 0n;
  if (param.type.startsWith("bytes")) return `0x${"00".repeat(Number(param.type.slice(5)) || 0)}`;
  if (param.type === "string") return "";
  throw Error(param.type);
}
const unique = new Map();
for (const entry of Object.values(fixture.abis).flat()) {
  if (entry.type !== "function") continue;
  const f = new Interface([entry]).fragments[0];
  if (!unique.has(f.format("sighash"))) unique.set(f.format("sighash"), entry);
}
const all = new Interface([...unique.values()]);
const families = ["METADATA_ROUTER", "RENDERER", "RENDER_CONTEXT", "MEDIA_MANIFEST", "SCRIPT_SOURCE", "DEPENDENCY_SOURCE",
  "COLLECTION_METADATA", "ENTROPY_COORDINATOR", "REFERENCE_RENDER", "ARTIST_SANCTION"];
const DAY = 86400n;
const ADMIN = id("ROLE_COLLECTION_FINALITY_ADMIN"), VETO = id("ROLE_TERMINAL_FREEZE_VETO");

export function setup(options = {}) {
  const base = graphSetup({ beforeCount: 7, afterCount: 7, tagged: true, scope: options.scope });
  const { scope, native } = base;
  native.targets[13] = base.discoveryDeployment.discovery.address;
  native.codeHashes[13] = base.discoveryDeployment.discovery.codeHash;
  base.binding.configurationHash = g.scopedPolicyGraphV2ProviderConfigurationHash(base.discoveryDeployment.provider.address, native, base.binding);
  base.discoveryDeployment.configurationHash = base.binding.configurationHash;
  const coords = { chainId: 1n, core: native.targets[0], metadata: native.targets[1], registry: native.targets[12],
    executor: A(10), artist: native.targets[11], artifactCoverage: native.targets[20] };
  const deployment = { chainId: 1n, core: pin(coords.core), metadata: pin(coords.metadata), registry: pin(coords.registry),
    executor: pin(coords.executor), roles: pin(A(801)), artist: pin(coords.artist), artifactCoverage: pin(coords.artifactCoverage),
    source: base.discoveryDeployment, linkedDependencies: [pin(A(802)), pin(A(803))] };
  const historyDeployment = { coordinates: coords, registry: deployment.registry };
  const diagnosticDeployment = { ...historyDeployment, linkedDependencies: deployment.linkedDependencies };
  const caller = options.caller ?? A(30), proposer = options.proposer ?? caller, root = pin(A(805)), carrier = A(806);
  const proof = { sanctionRecordHash: H(900), artifactHash: H(901), completionHash: H(902) };
  const components = families.map((name, i) => {
    const target = name === "ARTIST_SANCTION" ? coords.artist : name === "ENTROPY_COORDINATOR" ? base.set
      : name === "REFERENCE_RENDER" ? base.childAddresses[4] : A(600 + i);
    return { componentType: id(name), component: target, interfaceId: "0x8004d4f5", codeHash: pin(target).codeHash,
      moduleVersion: H(100 + i), manifestHash: H(200 + i), dataHash: name === "ARTIST_SANCTION" ? proof.sanctionRecordHash : H(300 + i) };
  }).sort((a, b) => a.componentType.localeCompare(b.componentType));
  const profileHashes = ["StreamSnapshotDefinitions.sol", "StreamScopedSnapshotDefinitions.sol", "StreamPolicySnapshotDefinitionsV2.sol"]
    .map(name => {
      const text = fixture.sourceTexts[`smart-contracts/domains/records/${name}`];
      return (typeof text === "string" ? text : text.text).match(/PROFILE_HASH\s*=\s*(0x[0-9a-f]{64})/)[1];
    });
  const profiles = [0, 1, 2].map(i => ({ profileHash: profileHashes[i], referenceRender: A(1120 + i),
    referenceRenderCodeHash: pin(A(1120 + i)).codeHash, snapshots: A(1130 + i), snapshotsCodeHash: pin(A(1130 + i)).codeHash,
    entropyFactory: A(1140 + i), entropyFactoryCodeHash: pin(A(1140 + i)).codeHash, configurationHash: H(1150 + i) }));
  const sourceConfiguration = { core: coords.core, router: native.targets[2], routerCodeHash: native.codeHashes[2],
    chainId: 1n, readGas: native.readGas, policyOutput: A(1110), policyOutputCodeHash: pin(A(1110)).codeHash, profiles };
  base.discoveryDeployment.sourceConfigurationHash = p.scopedPolicyFinalityV2SourceConfigurationHash(
    base.discoveryDeployment.provider.address, sourceConfiguration, base.binding);
  const discoveryConfiguration = { core: coords.core, metadata: coords.metadata, router: native.targets[2],
    provider: base.discoveryDeployment.provider.address, membership: native.targets[3], entropyFactory: native.targets[10],
    metadataAdapter: A(606), referenceRender: native.targets[9], artist: coords.artist, finalityRegistry: coords.registry,
    finalityRegistryCodeHash: pin(coords.registry).codeHash, routerAdapters: [0, 1, 2, 3, 4, 5].map(i => A(600 + i)),
    readGas: 100000n, componentGas: 10000000n, entropyGas: 1000000n };
  const originalInputs = { rootRecordHash: H(700), snapshotRecordHash: H(702), referenceRenderRecordHash: H(703),
    intentRecordHash: H(704), intentWaiverRecordHash: H0, interviewEvidenceHash: H(705), rightsStatementRecordHash: H(706), workDescriptionRecordHash: H(707) };
  const inventory = { scope, inventory: { planId: H(710), collectionId: scope.collectionId,
    scopeSubject: g.scopedPolicyGraphV2ScopeSubject(1n, coords.core, scope), artistId: H(711), originals: originalInputs,
    sourceContextHash: H(712), tokenInventoryHash: H(713), tokenCount: 1n, segmentCount: 20n, itemCount: 50n,
    segmentChainHash: H(714), renderCriticalEvidenceHash: H0 } };
  const inventoryDependencies = g.scopedPolicyGraphV2InventoryDependencies(base.recipe, base.full);
  const bundleDependencies = g.scopedPolicyGraphV2BundleDependencies(base.recipe, base.full);
  const inventoryHash = keccak256(coder.encode([g.SCOPED_POLICY_GRAPH_V2_INVENTORY_DEPENDENCIES_TUPLE], [inventoryDependencies]));
  const bundleHash = keccak256(coder.encode([g.SCOPED_POLICY_GRAPH_V2_BUNDLE_DEPENDENCIES_TUPLE], [bundleDependencies]));
  inventory.inventory.renderCriticalEvidenceHash = inv.scopedPolicyInventoryV2EvidenceHash(
    { chainId: 1n, core: coords.core, inventory: base.childAddresses[5] }, inventoryHash, inventory);
  const bundle = { scope, coverage: { inventoryPlan: inventory.inventory.planId,
    renderCriticalEvidenceHash: inventory.inventory.renderCriticalEvidenceHash, itemCount: inventory.inventory.itemCount,
    evidenceChainHash: H(715), bundleCoverageHash: H0 } };
  bundle.coverage.bundleCoverageHash = bun.scopedPolicyBundleV2CoverageHash(
    { chainId: 1n, core: coords.core, bundle: base.childAddresses[6] }, bundleHash, inventory, bundle);
  const coreFacts = { scopeExists: true, ...scope, tokenMappingExists: scope.scopeType === 1n,
    collectionSerial: scope.scopeType === 1n ? 1n : 0n, tokenLifecycle: scope.scopeType === 1n ? 2n : 0n,
    burned: false, collectionStatus: 2n, collectionSupplyMode: 1n, collectionConfigHash: H(720), scopeManifestHash: H(721) };
  const statement = { scope, coreFactsHash: p.scopedPolicyFinalityV2ScopedCoreFactsHash(coords, scope, coreFacts),
    contentRoot: H(722), leafCount: 1n, contentRootSchemaId: H(723), snapshotManifestHash: H(724), referenceRenderManifestHash: H(725),
    inputs: { ...originalInputs, renderCriticalEvidenceHash: inventory.inventory.renderCriticalEvidenceHash,
      bundleCoverageHash: bundle.coverage.bundleCoverageHash }, nonSanctionComponents: components.filter(v => v.componentType !== id("ARTIST_SANCTION")),
    entropyPolicy: 1n, postFreezePolicy: 1n, sanctionPolicy: 1n };
  const manifestBytes = p.scopedPolicyFinalityV2ManifestBytes(coords, statement);
  const plan = p.prepareScopedPolicyFinalityV2Finalization(coords, { manifestBytes, manifestURI: "ipfs://scoped-finality", components, proof });
  const batch = p.scopedPolicyFinalityV2GovernanceBatch(plan, 4n, { notBefore: 3n * DAY + 2000n,
    expiresAfter: 10n * DAY + 2000n, reasonHash: H(730), reasonURI: "ipfs://reason", manifestHash: H(731) });
  const kind = options.kind ?? "scheduleGovernanceBatch";
  const prepared = p.prepareScopedPolicyFinalityV2Call(coords, caller, kind === "stageFinalityManifest"
    ? { kind, manifestBytes } : { kind, batch });
  const state = { hooks: {}, calls: [], receipt: null, transaction: null, sealed: true, bound: true, isProposer: true,
    hasAdmin: true, stagedBefore: options.stagedBefore ?? kind !== "stageFinalityManifest",
    publishedBefore: options.publishedBefore ?? kind !== "publishGovernanceCallData", finalized: options.finalized ?? false,
    originalFailure: null, diagnosticMatches: true, guardianCommitment: H0, coreFacts, catalog: [H(740), H(741), 1n, 1n],
    network: 1n, missingCode: new Set(), blockHashes: new Map(), root, kind };
  function time(tag) { return Number((kind === "executeGovernanceBatch" || state.finalized ? batch.window.notBefore : 1000n) + BigInt(tag)); }
  function post(tag) { return tag >= 12 && state.receipt !== null; }
  const emptyAction = zero(c.executor.getFunction("governanceAction").outputs[0]);
  const emptyRecord = zero(c.finality.getFunction("artworkScopeFinalityRecord").outputs[0]);
  function action(tag) {
    const status = kind === "executeGovernanceBatch" ? post(tag) ? 2n : 1n : kind === "scheduleGovernanceBatch" && post(tag) ? 1n : 0n;
    if (!status) return structuredClone(emptyAction);
    return { ...emptyAction, status, actionClass: 2n, target: coords.registry, value: 0n, selector: batch.calls[0].selector,
      callHash: batch.callsHash, scopeHash: batch.scopeHash, oldValueHash: batch.oldValueHash, newValueHash: batch.newValueHash,
      notBefore: batch.window.notBefore, expiresAfter: batch.window.expiresAfter, proposer, executor: status === 2n ? caller : Z,
      reasonHash: batch.window.reasonHash, reasonURI: batch.window.reasonURI, manifestHash: batch.window.manifestHash };
  }
  function record(tag) {
    if (!state.finalized && !(kind === "executeGovernanceBatch" && post(tag))) return structuredClone(emptyRecord);
    return { finalized: true, scope, finalityRecordHash: plan.execution.finalityRecordHash, manifestContentHash: plan.manifest.contentHash,
      manifestURIHash: plan.manifest.uriHash, componentsHash: p.scopedPolicyFinalityV2ComponentsHash(components),
      finalityManifestURI: plan.manifest.uri, manifestPointer: coords.registry, finalizedAt: BigInt(time(12)) };
  }
  const executionWitness = { actionId: batch.actionId, proposer, reasonHash: batch.window.reasonHash, roleMutationHash: H(750), roleRevision: 2n };
  const archiveWitness = { evidenceHash: p.scopedPolicyFinalityV2ArchiveEvidenceHash(coords, proof), proof };
  const scopedRole = keccak256(coder.encode(["bytes32", "bytes32"], [VETO, plan.execution.scopeHash]));
  const guardianHolders = [[pin(A(810)), pin(A(811))], []];
  const mutations = [[H(751), 3n], [H(752), 1n]];
  const domain = id("6529STREAM_TERMINAL_GUARDIAN_CONFIG_V1"), holderDomain = id("6529STREAM_TERMINAL_GUARDIAN_HOLDER_V1");
  let commitment = keccak256(coder.encode(["bytes32", "uint256", "address", "address", "bytes32", "bytes32", "uint64"],
    [domain, 1n, coords.executor, deployment.roles.address, deployment.roles.codeHash, ...mutations[0]]));
  for (let j = 0; j < 2; j++) {
    const role = j ? scopedRole : VETO;
    if (j) commitment = keccak256(coder.encode(["bytes32", "bytes32", "bytes32", "bytes32", "bytes32", "uint64"],
      [id("6529STREAM_TERMINAL_GUARDIAN_SCOPE_V1"), commitment, plan.execution.scopeHash, scopedRole, ...mutations[j]]));
    commitment = keccak256(coder.encode(["bytes32", "bytes32", "bytes32", "uint256"], [holderDomain, commitment, role, guardianHolders[j].length]));
    for (let i = 0; i < guardianHolders[j].length; i++) commitment = keccak256(coder.encode(
      ["bytes32", "bytes32", "bytes32", "uint256", "address", "bytes32"],
      [holderDomain, commitment, role, i, guardianHolders[j][i].address, guardianHolders[j][i].codeHash]));
  }
  state.guardianCommitment = keccak256(coder.encode(["bytes32", "bytes32", "uint256"], [domain, commitment, 1n]));
  const documents = new Map();
  const definitions = [
    ["6529STREAM_SCOPED_FINALITY_INPUT_MANIFEST_V1", 0n, p.SCOPED_POLICY_FINALITY_V2_SCHEMA_DOCUMENT],
    ["6529STREAM_SCOPED_FINALITY_INPUT_MANIFEST_ABI_V1", 1n, p.SCOPED_POLICY_FINALITY_V2_CANONICALIZATION_DOCUMENT],
    ["6529STREAM_ARTIST_SANCTION_ARCHIVE_V1", 0n, fixture.documents["docs/schemas/finality/sanction-archive-v1.schema.json"].text],
    ["6529STREAM_ARTIST_SANCTION_ARCHIVE_ABI_V1", 1n, fixture.documents["docs/schemas/finality/sanction-archive-abi-v1.json"].text],
    ["6529STREAM_ARTIST_SANCTION_CEREMONY_V1", 0n, fixture.documents["docs/schemas/finality/sanction-ceremony-v1.schema.json"]?.text],
    ["6529STREAM_ARTIST_SANCTION_CEREMONY_JCS_V1", 1n, fixture.documents["docs/schemas/finality/sanction-ceremony-jcs-v1.json"]?.text]
  ];
  for (const [name, docKind, text] of definitions) {
    if (text === undefined) throw Error(`Missing original definition ${name}`);
    const raw = hexlify(toUtf8Bytes(text)), contentHash = keccak256(raw), length = BigInt((raw.length - 2) / 2);
    documents.set(id(name), { raw, facts: { exists: true, kind: docKind, status: 0n, contentHash, canonicalizationId: id("RAW_BYTES"),
      supersedesId: H0, totalBytes: length, chunkCount: 1n, declarationHash: H(760) },
    doc: { exists: true, status: 1n, declarationHash: H(760), specification: { name, kind: docKind, contentHash,
      canonicalizationId: id("RAW_BYTES"), supersedesId: H0, uri: "", totalBytes: length }, chunkHashes: [contentHash] } });
  }
  const baseCall = base.provider.call;
  base.state.hooks.call = ({ method, args, target, iface }) => {
    if (method === "requireCurrentRoutes") return [components.map(({ componentType, component, interfaceId, codeHash }) =>
      ({ componentType, component, interfaceId, codeHash }))];
    if (method === "getSatellitePointer" && [id("ARTWORK_FINALITY_REGISTRY"), id("ARTIST_REGISTRY")].includes(args[0])) {
      const a = args[0] === id("ARTIST_REGISTRY") ? coords.artist : coords.registry;
      return [a, pin(a).codeHash, false, args[0], "0x12345678", A(106), 1n, H(800), H(801), 1n];
    }
  };
  const provider = {
    ...base.provider,
    getNetwork: async () => { await state.hooks.network?.(); return { chainId: state.network }; },
    getBlock: async tag => ({ number: tag, hash: state.blockHashes.get(tag) ?? H(1000 + tag), timestamp: time(tag) }),
    getCode: async (target, tag) => {
      const changed = await state.hooks.code?.(target, tag);
      if (changed !== undefined) return changed;
      if (state.missingCode.has(target)) return "0x";
      if (target === carrier) return `0x00${coder.encode(["bytes[]"], [batch.callDatas]).slice(2)}`;
      return code(target);
    },
    call: async tx => {
      const target = getAddress(tx.to), tag = tx.blockTag;
      const iface = target === coords.registry ? c.finality : target === coords.executor ? c.executor : all;
      let parsed;
      try { parsed = iface.parseTransaction({ data: tx.data }); } catch { parsed = null; }
      if (!parsed) return baseCall(tx);
      const method = parsed.name, args = parsed.args, event = { target, tag, method, args, tx, iface };
      state.calls.push(event);
      const override = await state.hooks.call?.(event);
      if (override !== undefined) return typeof override === "string" ? override : iface.encodeFunctionResult(parsed.fragment, override);
      let values;
      const staged = state.stagedBefore || post(tag) && kind === "stageFinalityManifest" || state.finalized;
      const published = state.publishedBefore || post(tag) && kind === "publishGovernanceCallData";
      const members = kind === "executeGovernanceBatch" ? post(tag) ? [] : [batch.actionId]
        : kind === "scheduleGovernanceBatch" && post(tag) ? [batch.actionId] : [];
      if (["stageFinalityManifest", "publishGovernanceCallData", "scheduleGovernanceBatch", "executeGovernanceBatch"].includes(method)) {
        if (state.originalFailure) throw state.originalFailure;
        values = method === "stageFinalityManifest" ? [plan.manifest.contentHash] : method === "publishGovernanceCallData" ? [carrier]
          : method === "scheduleGovernanceBatch" ? [batch.actionId] : [];
      } else if (method === "finalityManifestStored") values = [staged];
      else if (method === "finalityManifestBytes") values = [staged ? plan.manifestBytes : "0x"];
      else if (method === "finalityExecutionContextWithArchive") values = [plan.execution];
      else if (method === "configuration" && target === deployment.source.discovery.address) values = [discoveryConfiguration];
      else if (method === "finalitySourceProfile") values = [profiles[Number(args[0])]];
      else if (method === "policyOutputManifestV2") values = [sourceConfiguration.policyOutput];
      else if (method === "policyOutputManifestV2CodeHash") values = [sourceConfiguration.policyOutputCodeHash];
      else if (method === "artworkScopeFinalityRecord") values = [record(tag)];
      else if (method === "finalityComponentCountForScope") values = [record(tag).finalized ? 10n : 0n];
      else if (method === "finalityComponentsForScope") values = [record(tag).finalized ? components : []];
      else if (method === "finalityExecutionWitness") values = [executionWitness];
      else if (method === "finalitySanctionArchiveWitness") values = [archiveWitness];
      else if (method === "verifyArtworkScopeFinality") values = [state.diagnosticMatches, record(tag).finalityRecordHash, record(tag).componentsHash];
      else if (method === "verifyArtworkScopeFinalityRange") values = [state.diagnosticMatches, record(tag).finalityRecordHash, H(990), H(991), args[1] + args[2]];
      else if (method === "systemManifestBootstrapState") {
        values = c.executor.getFunction(method).outputs.map(zero); values[0] = state.bound; values[1] = state.sealed;
      } else if (method === "publishedCallData" || method === "scheduledCallDataPointer") values = [published ? carrier : Z];
      else if (method === "scheduledCallData") values = [batch.callDatas];
      else if (method === "governanceAction") values = [action(tag)];
      else if (method === "governanceActionPolicyState") values = state.catalog;
      else if (method === "governanceRootState") values = [root.address, root.codeHash, 1n];
      else if (method === "owner" && target === coords.executor) values = [root.address];
      else if (method === "owner" && target === deployment.roles.address) values = [coords.executor];
      else if (method === "roleRegistry" || method === "finalityRoleRegistry") values = [deployment.roles.address];
      else if (method === "isProposer") values = [state.isProposer];
      else if (method === "governanceNonce") values = [batch.nonce + (kind === "scheduleGovernanceBatch" && post(tag) ? 1n : 0n)];
      else if (method === "minimumDelay") values = [3n * DAY];
      else if (method === "hasRole") values = [args[0] === ADMIN && args[1] === proposer && state.hasAdmin];
      else if (method === "isRoleRedundant") values = [true];
      else if (method === "roleMutationState") values = args[0] === ADMIN ? [executionWitness.roleMutationHash, executionWitness.roleRevision]
        : mutations[args[0] === VETO ? 0 : 1];
      else if (method === "roleHolderCount") values = [BigInt(guardianHolders[args[0] === VETO ? 0 : 1].length)];
      else if (method === "roleHolderAt") values = [guardianHolders[args[0] === VETO ? 0 : 1][Number(args[1])].address];
      else if (method === "terminalFreezeVetoGuardianSet") {
        if (args[0] !== plan.execution.scopeHash) throw Error("Target guardian scope substituted by batch aggregate");
        values = [deployment.roles.address, scopedRole, 0n, VETO, 2n, 0n];
      } else if (method === "terminalFreezeGuardianConfigCommitment") values = [state.guardianCommitment];
      else if (method === "terminalFreezeLiveActionCaps") values = [64n, 48n, 8n];
      else if (method === "terminalFreezeActionPage") values = [members, members.map(() => batch.window.notBefore), BigInt(members.length)];
      else if (method === "freezeSelectorConfig") values = [true, deployment.registry.codeHash, 1n, H(770)];
      else if (method === "coreReads" || method === "core" && target === native.targets[14]) values = [coords.core];
      else if (method === "metadataReads" || method === "collectionMetadata" && target === native.targets[14]) values = [coords.metadata];
      else if (method === "sanctionReads") values = [coords.artist];
      else if (method === "scopeEvidenceProvider" || method === "evidenceProvider") values = [base.discoveryDeployment.provider.address];
      else if (method === "scopeEvidenceProviderCodeHash") values = [base.discoveryDeployment.provider.codeHash];
      else if (method === "coreFinalityAdapter") values = [native.targets[14]];
      else if (method === "finalityDiscovery") values = [base.discoveryDeployment.discovery.address];
      else if (method === "artifactCoverage") values = [coords.artifactCoverage];
      else if (method === "governanceAuthority" && target === coords.registry) values = [coords.executor];
      else if (method === "finalityRegistry") values = [coords.registry];
      else if (method === "finalityRegistryCodeHash") values = [deployment.registry.codeHash];
      else if (method === "gasParameter") values = [1000000n];
      else if (method === "GGP_FINALITY_COMPONENT_READ_GAS_KEY") values = [id("FINALITY_COMPONENT_READ_GAS")];
      else if (method === "scopedCoreFinalityFacts") values = [state.coreFacts];
      else if (method === "finalityStateForScope") values = [{ frozen: true, ...components.find(v => v.component === target) }];
      else if (method === "requireCurrent" && target === base.childAddresses[5]) values = [inventory];
      else if (method === "requireCoverage" && target === base.childAddresses[6]) {
        if (args[2] !== inventory.inventory.renderCriticalEvidenceHash) throw Error("Wrong bundle expected inventory hash");
        values = [bundle];
      } else if (method === "inputManifestBytes") values = [plan.manifestBytes];
      else if (method === "readChunk") values = [plan.manifestBytes];
      else if (method === "documentFacts") values = [documents.get(args[0]).facts];
      else if (method === "documentBytes") values = [documents.get(args[0]).raw];
      else if (method === "document") values = [documents.get(args[0]).doc];
      else if (method === "sanctionArchiveFacts") values = [{ sanctionRecordHash: proof.sanctionRecordHash, artistId: inventory.inventory.artistId,
        schemaId: id("6529STREAM_ARTIST_SANCTION_ARCHIVE_V1"), canonicalizationId: id("6529STREAM_ARTIST_SANCTION_ARCHIVE_ABI_V1"),
        contentHash: H(780), byteLength: 10000n }];
      else if (method === "requireArtifactCoverage") values = [{ completionHash: proof.completionHash, artifactHash: proof.artifactHash,
        artistId: inventory.inventory.artistId, schemaId: id("6529STREAM_ARTIST_SANCTION_ARCHIVE_V1"),
        canonicalizationId: id("6529STREAM_ARTIST_SANCTION_ARCHIVE_ABI_V1"), contentHash: H(780), byteLength: 10000n, chunkCount: 2n,
        firstFamilyRecordHash: H(781), secondFamilyRecordHash: H(782), validationEpoch: 1n, evidenceChainHash: H(783) }];
      else return baseCall(tx);
      const changed = await state.hooks.result?.({ ...event, values });
      return iface.encodeFunctionResult(parsed.fragment, changed ?? values);
    },
    getTransactionReceipt: async () => { await state.hooks.receipt?.(); return state.receipt; },
    getTransaction: async () => { await state.hooks.transaction?.(); return state.transaction; }
  };
  function installReceipt(mode = "direct") {
    const txHash = H(950), blockNumber = 12, blockHash = H(1012), safeHash = H(951), logs = [];
    function event(target, iface, name, args) {
      const row = iface.encodeEventLog(iface.getEvent(name), args);
      logs.push({ address: target, topics: [...row.topics], data: row.data });
    }
    const e = (name, args) => event(coords.executor, c.executor, name, args);
    const r = (name, args) => event(coords.registry, c.finality, name, args);
    if (kind === "stageFinalityManifest" && !state.stagedBefore) r("FinalityManifestStaged", [1n, plan.manifest.contentHash, BigInt((manifestBytes.length - 2) / 2), caller]);
    if (kind === "publishGovernanceCallData" && !state.publishedBefore) e("GovernanceCallDataPublished", [1n, batch.publicationKey, carrier, caller]);
    const common = [1n, batch.actionId, 2n, coords.registry, 0n, batch.calls[0].selector, batch.callsHash,
      batch.scopeHash, batch.oldValueHash, batch.newValueHash];
    if (kind === "scheduleGovernanceBatch") {
      e("TerminalFreezeActionMembershipUpdated", [1n, plan.execution.scopeHash, batch.actionId, caller, true, 1n,
        caller === root.address, batch.window.notBefore, 0n, 1n]);
      e("TerminalFreezeGuardianConfigCommitted", [1n, batch.actionId, state.guardianCommitment]);
      e("GovernanceActionScheduled", [...common, batch.window.notBefore, batch.window.expiresAfter, batch.nonce, caller,
        batch.window.reasonHash, batch.window.reasonURI, batch.window.manifestHash]);
      e("GovernanceActionPolicyValidated", [1n, batch.actionId, 1n, state.catalog[0], state.catalog[1]]);
    }
    if (kind === "executeGovernanceBatch") {
      e("TerminalFreezeActionMembershipUpdated", [1n, plan.execution.scopeHash, batch.actionId, proposer, false, 3n,
        proposer === root.address, batch.window.notBefore, 0n, 0n]);
      r("ArtworkScopeFinalized", [1n, scope.scopeType, scope.collectionId, plan.execution.finalityRecordHash, scope.tokenId, scope.scopeId,
        p.scopedPolicyFinalityV2ComponentsHash(components), plan.manifest.contentHash, plan.manifest.uri]);
      r("FinalityManifestPointerRecorded", [1n, plan.execution.finalityRecordHash, coords.registry, plan.manifest.contentHash]);
      r("ArtworkTerminalFreezeExecuted", [1n, p.scopedPolicyFinalityV2ScopeKey(scope), plan.execution.finalityRecordHash, coords.executor]);
      r("FinalityExecutionWitnessRecorded", [1n, plan.execution.finalityRecordHash, batch.actionId, proposer, batch.window.reasonHash,
        executionWitness.roleMutationHash, executionWitness.roleRevision, plan.execution.inputsHash]);
      r("FinalitySanctionArchiveWitnessRecorded", [1n, plan.execution.finalityRecordHash, archiveWitness.evidenceHash,
        proof.sanctionRecordHash, proof.artifactHash, proof.completionHash]);
      e("GovernanceActionExecuted", [...common, caller, batch.window.manifestHash]);
      e("GovernanceActionPolicyValidated", [1n, batch.actionId, 2n, state.catalog[0], state.catalog[1]]);
    }
    let to = prepared.call.to, from = caller, data = prepared.call.data;
    if (mode !== "direct") {
      to = caller; from = A(31);
      data = safe.encodeFunctionData("execTransaction", [prepared.call.to, 0n, prepared.call.data, 0, 90000000n, 0n, 0n, Z, Z, "0x1234"]);
      if (mode === "indexed") logs.push({ address: caller, topics: [safe.getEvent("ExecutionSuccess").topicHash, safeHash], data: coder.encode(["uint256"], [0n]) });
      else event(caller, safe, "ExecutionSuccess", [safeHash, 0n]);
    }
    state.receipt = { status: 1, hash: txHash, from, to, blockNumber, blockHash, logs };
    state.transaction = { hash: txHash, from, to, blockNumber, blockHash, chainId: 1n, data, value: 0n };
    renumber();
    return { txHash, options: mode === "direct" ? { execution: "direct" } : { execution: "safe", expectedSafeTxHash: safeHash } };
  }
  function renumber() {
    state.receipt.logs.forEach((log, i) => Object.assign(log, { index: i, transactionHash: state.receipt.hash,
      blockNumber: state.receipt.blockNumber, blockHash: state.receipt.blockHash, removed: false }));
  }
  return { base, provider, state, deployment, historyDeployment, diagnosticDeployment, coords, caller, proposer, plan, batch, prepared,
    scope, components, coreFacts, inventory, bundle, inventoryHash, bundleHash, documents, proof, record, action,
    executionWitness, archiveWitness, guardianHolders, carrier, sourceConfiguration, discoveryConfiguration,
    installReceipt, renumber, time };
}
