import test from "node:test";
import assert from "node:assert/strict";
import { fixture, compiledABI } from "./current-artist-recovered-hydration-fixture.mjs";
import { AbiCoder, Interface, ParamType, ZeroAddress, ZeroHash, getAddress, id, keccak256 } from "ethers";
import * as rh from "../dist/current-artist-recovered-hydration.js";
import * as workflow from "../dist/current-artist-recovered-hydration-workflow.js";
import { ARTIST_HYDRATION_SUITE_TUPLE } from "../dist/current-artist-authority-hydration.js";
import { createSafeCallPlan, verifySafeCallPlan } from "../dist/safe-plan.js";

const segments = ["registry", "coordinator", "archive", "owner", "checkpoint", "recoveredOwner", "chronology",
  "history", "nativeReceipts", "reconstruction", "timing", "coreHost", "governanceFacts", "finalityRecovery",
  "finalityBinding", "entropyUnavailability", "entropyFreshRecovery", "hydrationOwner", "hydrationCoordinator", "recoveredCoordinator"];
const abi = new Interface(segments.flatMap(name => compiledABI[name]).filter(row => row.type !== "constructor")
  .concat(compiledABI.commit.filter(row => row.type === "event")));
const preparedAbi = new Interface(compiledABI.prepared);
const coder = AbiCoder.defaultAbiCoder();
const A = n => getAddress(`0x${BigInt(n).toString(16).padStart(40, "0")}`);
const H = value => id(String(value));
const hash = (types, values) => keccak256(coder.encode(types, values));
const domains = Array.from({ length: 7 }, (_, i) => rh.artistRecoveredHydrationOwnerDomain(i));
const safe = new Interface(["function execTransaction(address,uint256,bytes,uint8,uint256,uint256,uint256,address,address,bytes) returns(bool)"]);
const safePlain = new Interface(["event ExecutionSuccess(bytes32 txHash,uint256 payment)", "event ExecutionFailure(bytes32 txHash,uint256 payment)"]);
const safeIndexed = new Interface(["event ExecutionSuccess(bytes32 indexed txHash,uint256 payment)", "event ExecutionFailure(bytes32 indexed txHash,uint256 payment)"]);
const zeroCell = () => ({ commitment: ZeroHash, touchedRevision: 0n, kind: 0n, status: 0n });
const zeroValue = type => {
  const p = typeof type === "string" ? ParamType.from(type) : type;
  if (p.baseType === "tuple") return Object.fromEntries(p.components.map(field => [field.name, zeroValue(field)]));
  if (p.baseType === "array") return Array.from({ length: Math.max(0, p.arrayLength) }, () => zeroValue(p.arrayChildren));
  if (p.type === "address") return ZeroAddress;
  if (p.type === "bool") return false;
  if (p.type === "string") return "";
  if (p.type === "bytes") return "0x";
  if (p.type.startsWith("bytes")) return `0x${"00".repeat(Number(p.type.slice(5)))}`;
  return 0n;
};

function setup(options = {}) {
  const codes = new Map();
  const pin = n => {
    const address = A(n), code = `0x61${BigInt(n).toString(16).padStart(4, "0")}6000`;
    codes.set(address, code);
    return { address, codeHash: keccak256(code) };
  };
  const common = Array.from({ length: 7 }, (_, i) => pin(50 + i));
  const sourcePins = Array.from({ length: 9 }, (_, i) => pin(10 + i)).concat(common);
  const destinationPins = Array.from({ length: 9 }, (_, i) => pin(30 + i)).concat(common);
  const deployment = { chainId: 1n,
    source: { registry: sourcePins[7], coordinator: pin(70), components: sourcePins },
    destination: { registry: destinationPins[7], coordinator: pin(71), components: destinationPins },
    preparationLibrary: pin(72), preparationDependencies: [pin(73)] };
  const suite = pins => ({ owners: pins.slice(0, 7).map(v => v.address), registry: pins[7].address, archive: pins[8].address,
    core: pins[9].address, mintManager: pins[10].address, roleRegistry: pins[11].address, metadata: pins[12].address,
    primaryResolver: pins[13].address, royaltyResolver: pins[14].address, validator: pins[15].address,
    primaryRevenueClass: H("PRIMARY_SALE") });
  const source = suite(sourcePins), destination = suite(destinationPins);
  const origin = { chainId: 1n, registry: source.registry, coordinator: deployment.source.coordinator.address,
    archive: source.archive, owners: source.owners, ownerCodeHashes: sourcePins.slice(0, 7).map(v => v.codeHash),
    core: source.core, manager: source.mintManager, suiteConfigurationHash: hash([ARTIST_HYDRATION_SUITE_TUPLE], [source]) };
  const originHash = rh.artistRecoveredHydrationOriginHash(origin);
  const artistId = H("original-artist"), bindingHash = H("binding"), collectionId = 8n;
  const before = domains.map((domainId, i) => ({ domainId, revision: i === 2 ? 3n : 0n,
    stateRoot: H(`destination root ${i}`), recordChainTip: H(`destination tip ${i}`) }));
  const checkpoints = domains.map((domainId, i) => ({ schema: rh.ARTIST_RECOVERED_HYDRATION_CHECKPOINT_SCHEMA,
    ownerState: { domainId, revision: 10n, stateRoot: H(`source root ${i}`), recordChainTip: H(`source tip ${i}`) },
    replayCount: i === 2 ? 4n : 0n, replayRoot: H(`replay ${i}`), nonceIndexCount: i === 2 ? BigInt(options.allNonceKinds ? 5 : 1) : 0n,
    nonceRoot: H(`nonces ${i}`) }));
  const receipts = [
    [{ operation: 1n, artistId, collectionId, recordHash: bindingHash }], [],
    [{ operation: 1n, artistId, collectionId: 0n, recordHash: artistId },
      { operation: 35n, artistId, collectionId: 0n, recordHash: H("recovery35") },
      { operation: 35n, artistId, collectionId: 0n, recordHash: H("supersession35") }],
    [{ operation: 2n, artistId, collectionId, recordHash: H("acceptance") }], [], [], [],
  ];
  if (options.economics) receipts[6].push({ operation: 15n, artistId, collectionId, recordHash: H("economics15") });
  if (options.attestation) receipts[4].push({ operation: 24n, artistId, collectionId, recordHash: H("attestation24") });
  if (options.external) receipts[2].push(
    { operation: 13n, artistId, collectionId, recordHash: H("finality finding") },
    { operation: 23n, artistId, collectionId, recordHash: H("entropy finding") },
  );
  const journals = receipts.map((rows, i) => rows.map((receipt, j) => ({
    position: { point: { environmentHash: originHash, ownerIndex: BigInt(i), ownerRevision: BigInt(j + 1) }, nativeIndex: BigInt(j) }, receipt,
  })));
  const replayOrigins = Array.from({ length: 7 }, () => []);
  replayOrigins[2] = ["one_way_cutover_latch", "verified_lane_key", "import_binding", "nonce_allocator"].map((name, i) => ({
    surface: H(`identity_authority.replay.${name}`), scope: i === 0 ? ZeroHash : H(`scope${i}`),
  }));
  const sourceKeys = replayOrigins.map((rows, i) => rows.map(row => rh.artistRecoveredHydrationReplayKey(origin, i, row)));
  const cells = replayOrigins.map(rows => rows.map((_, i) => ({ commitment: H(`guard${i}`), touchedRevision: 5n, kind: 1n, status: 2n })));
  const aliases = replayOrigins.map((rows, ownerIndex) => rows.map((row, j) => ({ originHash, ownerIndex: BigInt(ownerIndex),
    ...row, originalKey: sourceKeys[ownerIndex][j], cell: cells[ownerIndex][j],
    admittedAt: { environmentHash: originHash, ownerIndex: BigInt(ownerIndex), ownerRevision: 5n } })).sort((a, b) => a.originalKey.localeCompare(b.originalKey)));
  const provenance = { origins: [origin], eras: [{ originHash, checkpoints,
    nativeCounts: journals.map(rows => BigInt(rows.length)), lowerRevisions: Array(7).fill(0n), priorImportCommitment: ZeroHash }], journals, aliases };
  const capability = (i, features = options.capabilities ?? 255n) => ({ profile: rh.ARTIST_RECOVERED_HYDRATION_PROFILE,
    version: 1n, ownerIndex: BigInt(i), ownerDomain: domains[i], checkpointSchema: rh.ARTIST_RECOVERED_HYDRATION_CHECKPOINT_SCHEMA,
    stateSchema: rh.artistRecoveredHydrationOwnerTag(i), supportedFeatures: features });
  const features = 1n | (options.economics ? 32n : 0n) | (options.attestation ? 128n : 0n);
  const artistRecords = journals.flat().map(row => row.receipt.recordHash);
  const collectionRecords = journals.flat().filter(row => row.receipt.collectionId === collectionId).map(row => row.receipt.recordHash);
  const artist = { artistId, collectionId: 0n, bindingHash: ZeroHash, records: artistRecords, policies: [] };
  const collection = { artistId, collectionId, bindingHash, records: collectionRecords, policies: [] };
  const query = { ...collection, records: artistRecords };
  const sourceCatalogs = new Map();
  for (const i of [2, 4, 6]) {
    const payload = i === 2 ? "0x" : i === 4 ? "0x1234" : "0x5678";
    const row = { pointer: A(90 + i), payloadType: H(`original-payload-${i}`), payloadHash: keccak256(payload) };
    codes.set(row.pointer, `0x00${payload.slice(2)}`);
    sourceCatalogs.set(source.owners[i], [row]);
  }
  const nonces = Array.from({ length: options.allNonceKinds ? 5 : 1 }, (_, index) => ({
    index: { kind: BigInt(index + 1), key: index === 0 ? artistId : H(`nonce namespace${index}`), prefixCount: 1n },
    words: [{ prefix: BigInt(index), words: [3n, ...Array(31).fill(0n)], exhausted: false }],
  }));
  const data = Array.from({ length: 7 }, (_, i) => {
    const payload = { provenance: rh.artistRecoveredHydrationOwnerProvenance(provenance, i), nonces: i === 2 ? nonces : [],
      // Opaque fixed-owner bytes model the original producer return; these tests never claim native semantic admission.
      semanticState: `0x${"ab".repeat(options.semanticBytes ?? 32)}`, publications: sourceCatalogs.get(source.owners[i]) ?? [] };
    return { typedState: rh.encodeArtistRecoveredHydrationOwnerPayload(payload, i, features), origins: replayOrigins[i],
      sourceKeys: sourceKeys[i], cells: cells[i], nonces: [] };
  });
  const timing = { schema: H("6529STREAM_ARTIST_RECOVERED_TIMING_INVENTORY_V1"), version: 1n, count: 0n,
    root: ZeroHash, configurationHash: H("original timing configuration") };
  const timingEntries = [];
  if (options.timing) {
    const entry = { chainId: 1n, owner: source.owners[2], index: 0n,
      change: { parameter: H("notice"), actionId: H("timing action"), actionKey: H("timing key"),
        oldHash: H("old timing"), newHash: H("new timing"), oldValue: 2n, newValue: 3n,
        floor: 1n, oldRevision: 0n, newRevision: 1n }, previousCommitment: ZeroHash, commitment: ZeroHash };
    entry.commitment = hash(["bytes32", "uint16", rh.ARTIST_RECOVERED_HYDRATION_TIMING_ENTRY_TUPLE], [timing.schema, 1n, entry]);
    timingEntries.push(entry); timing.count = 1n; timing.root = entry.commitment;
  }
  const externalGuards = { schema: H("6529STREAM_ARTIST_RECOVERED_EXTERNAL_GUARDS_V1"),
    provenanceCommitment: rh.artistRecoveredHydrationProvenanceHash(provenance), artistId, actions: [], finality: [], entropy: [] };
  if (options.action) {
    const executor = pin(175);
    externalGuards.actions.push({ associationHash: H("old association"),
      origin: { environmentHash: originHash, ownerIndex: 2n, ownerRevision: 3n },
      witness: { actionId: H("executed recovery"), callsHash: H("recovery calls"), callIndex: 0n,
        callDataHash: H("recovery calldata"), executor: executor.address, executorCodeHash: executor.codeHash,
        proposer: A(176), roleMutationHash: H("role mutation"), roleRevision: 1n, notBefore: 1n,
        expiresAfter: 2n, minimumDelay: 259200n, manifestHash: H("old manifest") },
      facts: { status: 3n, actionClass: 2n, callHash: H("recovery calls"), notBefore: 1n, expiresAfter: 2n } });
  }
  if (options.external) {
    const registry = pin(178), executor = pin(177), entropy = pin(179);
    const scope = { scopeType: 0n, collectionId, tokenId: 0n, scopeId: ZeroHash };
    const record = zeroValue(rh.ARTIST_RECOVERED_HYDRATION_FINALITY_RECORD_TUPLE);
    Object.assign(record, { executed: true, recoveryId: H("actual later recovery"), scope,
      originalFinalityRecordHash: H("finality original"), generation: 1n, executedAt: 99n });
    externalGuards.finality.push({ findingRecordHash: H("finality finding"), origin: journals[2][3].position,
      core: source.core, target: { recoveryRegistry: registry.address, recoveryActionId: H("finality action"), scope,
        originalFinalityRecordHash: H("finality original"), recoveryManifestHash: H("manifest") },
      registryCodeHash: registry.codeHash, executor: executor.address, executorCodeHash: executor.codeHash,
      action: { status: 3n, actionClass: 2n, callHash: H("finality calls"), notBefore: 1n, expiresAfter: 2n },
      actionTerminal: true, record });
    externalGuards.entropy.push({ findingRecordHash: H("entropy finding"), origin: journals[2][4].position,
      core: source.core, coordinator: entropy.address, coordinatorCodeHash: entropy.codeHash,
      oldRequestKey: H("old entropy request"), newRequestKey: H("new entropy request"), terminal: true,
      receipt: { previousRequestKey: H("old entropy request"), artistRecordHash: H("later actual finding"),
        providerEvidenceHash: H("provider evidence"), incidentEvidenceHash: H("incident"), evidenceHash: H("evidence"),
        contentStateHash: H("content"), journalHead: H("journal"), requestedAtBlock: 5n, acceptLateOriginalFulfillment: false },
      evidence: { findingRecordHash: H("later actual finding"), intentHash: H("intent"), noticeEndsAt: 70n } });
  }
  const certificate = { admission: { prior: source.registry, sourceCoordinator: deployment.source.coordinator.address,
    source, provenance, artists: [artist], collections: [collection], before_: before }, query, data, timing, externalGuards };
  const witness = { collectionId, economics: options.economics ? [{ collectionId, resolver: source.primaryResolver,
    revenueClass: source.primaryRevenueClass, scope: 1n, scopeId: collectionId, assignmentHash: H("assignment") }] : [],
  attestations: options.attestation ? [{ terms: { collectionId, subjectKind: 10n, subjectId: artistId,
    subjectStateHash: H("retained operative"), schemaId: H("6529STREAM_ARTIST_PERSONHOOD_EVIDENCE_V1"),
    statementHash: H("statement"), statementURI: "ipfs:original" }, nonce: 7n }] : [] };
  const request = { records: { authority: { bindingIndex: 0n, artistIds: [artistId], collections: [{ artistId, collectionId, policies: [] }],
    expectedSource: checkpoints, replayOrigins }, witnesses: options.economics || options.attestation ? [witness] : [] },
  expectedCapabilities: Array.from({ length: 7 }, (_, i) => capability(i)), expectedSourceImportCommitment: ZeroHash,
  expectedSemanticInventory: ZeroHash };
  const state = { codes, hooks: [], calls: [], mined: false, captured: null, catalogs: new Map(), metadata: new Map(), evidence: new Map(),
    beforeCatalogs: new Map([destination.owners[2], destination.owners[4], destination.owners[6], destination.archive].map(host => [host, []])),
    capabilities: Array.from({ length: 7 }, (_, i) => capability(i)), certificate, tx: null, receipt: null };
  const suiteFor = host => source.owners.includes(host) || host === source.registry || host === source.archive
    || host === deployment.source.coordinator.address ? source : destination;
  const provider = {
    async getNetwork() { return { chainId: 1n }; },
    async getBlock(tag) { return { number: tag, timestamp: 100 + tag, hash: H(`block${tag}`) }; },
    async getCode(host, tag) {
      for (const hook of state.hooks) { const result = hook({ method: "getCode", host, tag }); if (result !== undefined) return result; }
      return codes.get(getAddress(host)) ?? "0x";
    },
    async call(tx) {
      const host = getAddress(tx.to), tag = tx.blockTag;
      let fragment, args;
      if (tx.data.startsWith("0x72c84763")) {
        fragment = preparedAbi.getFunction("prepare");
        args = preparedAbi.decodeFunctionData(fragment, `${fragment.selector}${tx.data.slice(10)}`);
      } else {
        fragment = abi.getFunction(tx.data.slice(0, 10));
        args = abi.decodeFunctionData(fragment, tx.data);
      }
      const method = fragment.name;
      state.calls.push({ method, host, tag, args, from: tx.from, value: tx.value, gasLimit: tx.gasLimit });
      const selectedAbi = method === "prepare" ? preparedAbi : abi;
      const encode = values => selectedAbi.encodeFunctionResult(fragment, values);
      for (const hook of state.hooks) {
        const result = hook({ method, host, tag, args, fragment, tx });
        if (result !== undefined) return typeof result === "string" ? result : encode(result);
      }
      const selected = suiteFor(host), isSource = selected === source, owner = selected.owners.indexOf(host);
      const post = state.mined && tag >= 12 && !isSource;
      switch (method) {
        case "prepare": assert.equal(host, deployment.preparationLibrary.address); assert.equal(tx.value, 0n); return encode([state.certificate]);
        case "hydrateRecoveredArtistAuthority": assert.equal(tx.value, 0n); return encode([state.captured.commitment]);
        case "authorityHydrationSuite": return encode([selected]);
        case "deploymentChainId": return encode([1n]);
        case "core": return encode([selected.core]);
        case "mintManager": return encode([selected.mintManager]);
        case "artistRegistry": return encode([selected.registry]);
        case "operationCoordinator": return encode([isSource ? deployment.source.coordinator.address : deployment.destination.coordinator.address]);
        case "archiveV2": return encode([selected.archive]);
        case "domainId": return encode([domains[owner]]);
        case "configurationHash": return encode([H("destination configuration")]);
        case "gasParameterInfo": return encode([1000000n, 1n, 2n, 1n]);
        case "getSatellitePointer": return encode([destination.registry, deployment.destination.registry.codeHash, true, H("ARTIST_REGISTRY"), "0x00000000", A(3), 1n, H("deploy"), H("module"), 1n]);
        case "artistRegistryCutover": return encode(isSource ? [true, destination.registry, 90n] : [false, ZeroAddress, 0n]);
        case "importedHistoryBindingCount": return encode([1n]);
        case "importedHistoryBinding": return encode([source.registry, 1n, H("history"), H("binding")]);
        case "artistHistoryPredecessorBinding": return encode([true, deployment.source.registry.codeHash, 90n]);
        case "importedLaneVerified": return encode([true, H(`lane${args[0]}`), BigInt(args[0] === 1n ? artistRecords.length : collectionRecords.length)]);
        case "artistHistoryLane": return encode([H(`lane${args[0]}`), BigInt(args[0] === 1n ? artistRecords.length : collectionRecords.length)]);
        case "ownerStateSnapshotV2": return encode([isSource ? checkpoints[owner].ownerState : post ? state.captured.after[owner] : before[owner]]);
        case "authorityCheckpoint": return encode([isSource ? checkpoints[owner] : { schema: rh.ARTIST_RECOVERED_HYDRATION_CHECKPOINT_SCHEMA,
          ownerState: before[owner], replayCount: owner === 2 ? 6n : 0n, replayRoot: H(`destination replay${owner}`), nonceIndexCount: 0n, nonceRoot: H(`destination nonce${owner}`) }]);
        case "recoveredAuthorityHydrationCapability": return encode([state.capabilities[owner]]);
        case "authorityHydrationCommitment": return encode([post ? state.captured.commitment : ZeroHash]);
        case "recoveredHydrationImportedPrefix": return encode(post ? [state.captured.owners[owner].payload.provenance, state.captured.commitment, state.captured.after[owner].revision]
          : [{ origins: [], eras: [], journal: [], aliases: [] }, ZeroHash, 0n]);
        case "artistNativeReceiptCount": return encode([isSource ? BigInt(journals[owner].length) : 0n]);
        case "artistNativeReceiptAt": return encode([journals[owner][Number(args[0])].receipt]);
        case "artistNativeReceiptRevisionAt": return encode([journals[owner][Number(args[0])].position.point.ownerRevision]);
        case "authorityReplayAt": return encode([sourceKeys[owner][Number(args[0])], cells[owner][Number(args[0])]]);
        case "replayCell": {
          if (isSource) return encode([cells[owner][sourceKeys[owner].indexOf(args[0])]]);
          const targetOrigin = { ...origin, registry: destination.registry, coordinator: deployment.destination.coordinator.address,
            archive: destination.archive, owners: destination.owners, ownerCodeHashes: destinationPins.slice(0, 7).map(v => v.codeHash),
            suiteConfigurationHash: hash([ARTIST_HYDRATION_SUITE_TUPLE], [destination]) };
          const index = replayOrigins[owner].findIndex(logical => rh.artistRecoveredHydrationReplayKey(targetOrigin, owner, logical) === args[0]);
          return encode([index === 0 || index < 0 ? zeroCell() : index < 3 ? { commitment: H(`destination guard${index}`), touchedRevision: 3n, kind: 1n, status: 2n }
            : post ? cells[owner][index] : zeroCell()]);
        }
        case "recoveredHydrationReplayPoint": return encode([aliases[owner].find(row => row.originalKey === args[0]).admittedAt]);
        case "authorityNonceIndexAt": return encode([nonces[Number(args[0])].index]);
        case "authorityNonceWordAt": {
          const word = nonces.find(row => row.index.kind === args[0] && row.index.key === args[1]).words[Number(args[2])];
          return encode([word.prefix, word.words, word.exhausted]);
        }
        case "recoveredTimingCheckpoint": return encode([timing]);
        case "recoveredTimingEntryAt": return encode([timingEntries[Number(args[0])]]);
        case "governanceActionFacts": return encode([host === A(177) ? externalGuards.finality[0].action : externalGuards.actions[0].facts]);
        case "governanceAuthority": return encode([A(177)]);
        case "finalityRecoveryRecord": return encode([externalGuards.finality[0].record]);
        case "entropyRecoveryIntentTerminal": return encode([externalGuards.entropy[0].terminal]);
        case "freshRecoveryReceipt": return encode([externalGuards.entropy[0].receipt]);
        case "entropyUnavailabilityEvidence": {
          const e = externalGuards.entropy[0].evidence;
          return encode([e.findingRecordHash, e.intentHash, e.noticeEndsAt]);
        }
        case "artistArchiveMaxEvidenceBytesV2": return encode([24575n]);
        case "storedPayloadCount": return encode([BigInt((isSource ? sourceCatalogs.get(host) : post ? state.catalogs.get(host) : state.beforeCatalogs.get(host))?.length ?? 0)]);
        case "storedPayloadAt": {
          const row = (isSource ? sourceCatalogs.get(host) : post ? state.catalogs.get(host) : state.beforeCatalogs.get(host))[Number(args[0])];
          return encode([row.pointer, row.payloadType, row.payloadHash]);
        }
        case "artistEvidenceMetadataV2": return encode(state.metadata.get(args[0]));
        case "artistEvidenceBytesV2": return encode([state.evidence.get(args[0])]);
        default: throw Error(`Unexpected original read ${method}`);
      }
    },
    async getTransaction() { return state.tx; },
    async getTransactionReceipt() { return state.receipt; },
  };
  return { deployment, provider, request, certificate, state, source, destination, before, origin, sourceCatalogs };
}

async function capture(s) {
  const result = await workflow.captureArtistRecoveredHydration(s.provider, s.deployment, A(80), s.request, { blockTag: 10, gasLimit: 10000000n });
  s.state.captured = result;
  return result;
}

function install(s, c, execution = "direct") {
  s.state.mined = true;
  s.state.catalogs = structuredClone(s.state.beforeCatalogs);
  const logs = [];
  const emit = (address, name, values, iface = abi) => {
    const event = iface.encodeEventLog(iface.getEvent(name), values);
    logs.push({ address, topics: event.topics, data: event.data, index: logs.length,
      blockNumber: 12, blockHash: H("block12"), transactionHash: H("tx"), removed: false });
  };
  const store = (host, row) => {
    const rows = s.state.catalogs.get(host) ?? [];
    if (rows.some(existing => existing.payloadType === row.payloadType && existing.payloadHash === row.payloadHash)) return;
    emit(host, "ArtistStoredPayload", [1n, BigInt(rows.length), row.payloadType, row.payloadHash, row.pointer]);
    rows.push(row); s.state.catalogs.set(host, rows);
  };
  for (const i of [2, 4, 6]) for (const row of c.owners[i].payload.publications) store(s.destination.owners[i], row);
  const append = (evidenceId, payload, index) => {
    const pointer = A(200 + index), contentHash = keccak256(payload), size = BigInt((payload.length - 2) / 2);
    s.state.codes.set(pointer, `0x00${payload.slice(2)}`);
    s.state.evidence.set(evidenceId, payload);
    s.state.metadata.set(evidenceId, [contentHash, pointer, size, 12n]);
    store(s.destination.archive, { pointer, payloadType: H("ARTIST_OPERATION_EVIDENCE"), payloadHash: contentHash });
    emit(s.destination.archive, "ArtistArchiveEvidenceAppendedV2", [evidenceId, 1n, contentHash, pointer, size]);
  };
  const coordinates = { chainId: 1n, registry: s.destination.registry, coordinator: s.deployment.destination.coordinator.address };
  for (let i = 0; i < c.descriptor.pageHashes.length; i++) {
    const page = `0x${c.profileEvidence.slice(2 + i * 40960, 2 + (i + 1) * 40960)}`;
    append(rh.artistRecoveredHydrationPageId(coordinates, c.commitment, c.descriptor, BigInt(i)), page, i);
  }
  append(c.evidenceId, c.operationEvidence, c.descriptor.pageHashes.length);
  emit(s.deployment.destination.coordinator.address, "RecoveredArtistAuthorityHydrated", [1n, s.source.registry,
    c.commitment, c.prepared.request.expectedSemanticInventory, c.descriptor.payloadHash]);
  for (const i of [2, 4, 6]) for (const row of c.owners[i].payload.publications) store(s.destination.archive, row);
  s.state.tx = { hash: H("tx"), from: c.prepared.caller, to: c.prepared.registry, data: c.prepared.call.data,
    value: 0n, chainId: 1n, blockNumber: 12, blockHash: H("block12") };
  if (execution !== "direct") {
    s.state.tx.from = A(81); s.state.tx.to = c.prepared.caller;
    s.state.tx.data = safe.encodeFunctionData("execTransaction", [c.prepared.registry, 0n, c.prepared.call.data, 0n,
      0n, 0n, 0n, ZeroAddress, ZeroAddress, "0x"]);
    emit(c.prepared.caller, "ExecutionSuccess", [H("safeHash"), 0n], execution === "indexed" ? safeIndexed : safePlain);
  }
  s.state.receipt = { ...s.state.tx, status: 1, logs };
  return { logs, emit };
}

const run = (s, c, execution = "direct") => workflow.reconcileArtistRecoveredHydrationReceipt(s.provider, c, H("tx"),
  execution === "direct" ? { execution: "direct" } : { execution: "safe", expectedSafeTxHash: H("safeHash") });
const renumber = logs => logs.forEach((log, index) => { log.index = index; });

test("complete original library certificate becomes a nonzero request and exact original Registry simulation", async () => {
  const s = setup(), c = await capture(s);
  assert.equal(s.request.expectedSemanticInventory, ZeroHash);
  assert.notEqual(c.prepared.request.expectedSemanticInventory, ZeroHash);
  assert.equal(c.registrySimulated, false);
  assert.equal(c.certificate.admission.provenance.journals[2].length, 3);
  assert.equal(c.owners[2].payload.nonces[0].words[0].words.length, 32);
  const simulation = await workflow.simulateArtistRecoveredHydration(s.provider, c, { blockTag: 11, gasLimit: 10000000n });
  assert.equal(simulation.commitment, c.commitment);
  const call = s.state.calls.findLast(item => item.method === "hydrateRecoveredArtistAuthority");
  assert.equal(call.from, A(80)); assert.equal(call.value, 0n);
  assert.equal(s.state.calls.filter(item => item.method === "prepare").every(item => item.host === s.deployment.preparationLibrary.address), true);
});

test("paged atomic seven-owner completion reconciles direct and both ordinary Safe layouts", async () => {
  for (const execution of ["direct", "legacy", "indexed"]) {
    const s = setup(), c = await capture(s); install(s, c, execution);
    const result = await run(s, c, execution);
    assert.equal(result.commitment, c.commitment);
    assert.equal(result.historicalImportProven, true);
    assert.equal(result.currentAuthorityClaimed, false);
    assert.equal(result.ownerSnapshots.length, 7);
    assert.ok(result.events.some(event => event.event === "ArtistArchiveEvidenceAppendedV2"));
  }
});

test("observed capability labels and supersets retain exact source expectations and complete witness selectors", async () => {
  for (const capabilities of [31n, 63n, 127n, 255n, 511n]) {
    const s = setup({ capabilities, economics: capabilities >= 63n, attestation: capabilities >= 255n });
    const c = await capture(s);
    assert.equal(c.owners[2].sourceCapability.supportedFeatures, capabilities);
    assert.equal(c.prepared.request.records.witnesses.length, capabilities >= 63n ? 1 : 0);
  }
  const missing = setup({ attestation: true, capabilities: 127n });
  await assert.rejects(capture(missing), /capability|features/i);
  const incorrect = setup();
  incorrect.request.expectedCapabilities[0].supportedFeatures = 63n;
  await assert.rejects(capture(incorrect), /capability/i);
  const omitted = setup({ economics: true });
  omitted.request.records.witnesses = [];
  await assert.rejects(capture(omitted), /witness|economics/i);
});

test("the original producer rejects unsupported histories and malformed certificates without fallback", async () => {
  const s = setup();
  s.state.hooks.push(({ method }) => { if (method === "prepare") throw Error("original unsupported content17 history"); });
  await assert.rejects(capture(s), /original unsupported content17/);
  assert.equal(s.state.calls.some(call => call.method === "hydrateRecoveredArtistAuthority"), false);
  const bad = setup();
  bad.state.hooks.push(({ method }) => method === "prepare" ? `${preparedAbi.encodeFunctionResult("prepare", [bad.certificate])}00` : undefined);
  await assert.rejects(capture(bad), /Noncanonical|invalid length/);
  const stale = setup(); stale.request.expectedSourceImportCommitment = H("wrong imported commitment");
  await assert.rejects(capture(stale), /commit the complete certificate/);
});

test("all seven original checkpoints, chronological native rows, replay order and complete nonce words are joined", async () => {
  const complete = await capture(setup({ allNonceKinds: true }));
  assert.deepEqual(complete.owners[2].payload.nonces.map(row => row.index.kind), [1n, 2n, 3n, 4n, 5n]);
  const cases = [
    ["artistNativeReceiptCount", ({ host }, s) => host === s.source.owners[2] ? [2n] : undefined, /native count/i],
    ["artistNativeReceiptRevisionAt", ({ host }, s) => host === s.source.owners[2] ? [99n] : undefined, /chronology/i],
    ["authorityReplayAt", ({ host }, s) => host === s.source.owners[2]
      ? [H("wrong insertion key"), s.certificate.data[2].cells[0]] : undefined, /insertion/i],
    ["authorityNonceWordAt", ({ host }, s) => host === s.source.owners[2]
      ? [0n, [3n, ...Array(30).fill(0n), 1n], false] : undefined, /nonce/i],
    ["authorityNonceWordAt", ({ host }, s) => host === s.source.owners[2]
      ? [0n, [3n, ...Array(31).fill(0n)], true] : undefined, /nonce/i],
    ["storedPayloadCount", ({ host }, s) => host === s.source.owners[4] ? [0n] : undefined, /catalog/i],
  ];
  for (const [method, response, expected] of cases) {
    const s = setup(); s.state.hooks.push(call => call.method === method ? response(call, s) : undefined);
    await assert.rejects(capture(s), expected);
  }
});

test("destination operation55/56/57, current pointer, full runtime and history gas prerequisites stay explicit", async () => {
  const cases = [
    ["importedHistoryBindingCount", () => [2n], /operation55/],
    ["importedLaneVerified", () => [false, H("lane"), 3n], /operation56/],
    ["artistRegistryCutover", ({ host }, s) => host === s.source.registry ? [false, ZeroAddress, 0n] : undefined, /operation57/],
    ["gasParameterInfo", () => [0n, 1n, 2n, 1n], /gas profile/],
    ["authorityHydrationCommitment", ({ host }, s) => host === s.destination.owners[4] ? [H("already applied")] : undefined, /fresh/],
    ["getCode", ({ host }, s) => host === s.deployment.preparationLibrary.address ? "0x" : undefined, /runtime|code/i],
  ];
  for (const [method, response, expected] of cases) {
    const s = setup(); s.state.hooks.push(call => call.method === method ? response(call, s) : undefined);
    await assert.rejects(capture(s), expected);
  }
});

test("retained timing roots and executed recovery actions remain valid after their original window expires", async () => {
  const s = setup({ timing: true, action: true }), c = await capture(s);
  assert.equal(c.timingEntries.length, 1);
  assert.equal(c.certificate.externalGuards.actions[0].facts.expiresAfter, 2n);
  const timing = setup({ timing: true });
  timing.state.hooks.push(({ method }) => method === "recoveredTimingEntryAt" ? [{ chainId: 1n,
    owner: timing.source.owners[2], index: 0n, change: c.timingEntries[0].change,
    previousCommitment: H("wrong predecessor"), commitment: c.timingEntries[0].commitment }] : undefined);
  await assert.rejects(capture(timing), /timing entry chain/);
  const action = setup({ action: true });
  action.state.hooks.push(({ method }) => method === "governanceActionFacts"
    ? [{ ...action.certificate.externalGuards.actions[0].facts, status: 2n }] : undefined);
  await assert.rejects(capture(action), /external action state/);
});

test("capture copies before awaits, rechecks the original certificate, and rejects moving tags or gas bounds", async () => {
  const s = setup();
  let mutated = false;
  const network = s.provider.getNetwork;
  s.provider.getNetwork = async () => {
    if (!mutated) { mutated = true; s.request.expectedSemanticInventory = H("caller mutation"); s.deployment.preparationLibrary.codeHash = H("caller mutation"); }
    return network();
  };
  const c = await capture(s);
  assert.notEqual(c.prepared.request.expectedSemanticInventory, s.request.expectedSemanticInventory);
  const drift = setup(); let preparedReads = 0;
  drift.state.hooks.push(({ method }) => {
    if (method === "prepare" && ++preparedReads === 2) throw Error("original final external guard changed");
  });
  await assert.rejects(capture(drift), /final external guard changed/);
  const bounded = setup();
  for (const options of [{ blockTag: "latest", gasLimit: 1n }, { blockTag: 10, gasLimit: 0n }, { blockTag: 10, gasLimit: 100000001n }]) {
    await assert.rejects(workflow.captureArtistRecoveredHydration(bounded.provider, bounded.deployment, A(80), bounded.request, options));
  }
});

test("simulation is explicit original admission and revalidates reviewed context without guessing a new execution", async () => {
  const s = setup(), c = await capture(s);
  await assert.rejects(workflow.simulateArtistRecoveredHydration(s.provider, c, { blockTag: 9, gasLimit: 10000000n }), /precedes/);
  const changed = structuredClone(c); changed.commitment = H("changed");
  await assert.rejects(workflow.simulateArtistRecoveredHydration(s.provider, changed, { blockTag: 10, gasLimit: 10000000n }), /changed/);
  s.state.hooks.push(({ method }) => { if (method === "hydrateRecoveredArtistAuthority") throw Error("original late rollback"); });
  await assert.rejects(workflow.simulateArtistRecoveredHydration(s.provider, c, { blockTag: 10, gasLimit: 10000000n }), /original late rollback/);
  s.state.hooks.length = 0;
  s.state.hooks.push(({ method }) => method === "hydrateRecoveredArtistAuthority" ? [H("wrong return")] : undefined);
  await assert.rejects(workflow.simulateArtistRecoveredHydration(s.provider, c, { blockTag: 10, gasLimit: 10000000n }), /another commitment/);
});

const namedLogs = (s, name, host) => s.state.receipt.logs.filter(log => (!host || log.address === host)
  && log.topics[0] === abi.getEvent(name).topicHash);

test("receipt transport rejects wrong actors, data, value, failed transactions and non-CALL Safe execution", async () => {
  const s = setup(), c = await capture(s);
  for (const change of [
    () => { s.state.tx.from = A(81); },
    () => { s.state.tx.value = 1n; },
    () => { s.state.tx.data += "00"; },
    () => { s.state.receipt.status = 0; },
  ]) {
    install(s, c); change(); await assert.rejects(run(s, c), /transaction|transport/i);
  }
  for (const change of [
    values => { values[3] = 1n; },
    values => { values[1] = 1n; },
    values => { values[0] = A(99); },
    values => { values[2] += "00"; },
  ]) {
    install(s, c, "legacy");
    const values = [...safe.decodeFunctionData("execTransaction", s.state.tx.data)]; change(values);
    s.state.tx.data = safe.encodeFunctionData("execTransaction", values);
    await assert.rejects(run(s, c, "legacy"), /ordinary Safe CALL/);
  }
  await assert.rejects(workflow.reconcileArtistRecoveredHydrationReceipt(s.provider, c, H("tx"), { execution: "unknown" }), /Unsupported/);
  await assert.rejects(workflow.reconcileArtistRecoveredHydrationReceipt(s.provider, c, H("tx"), { execution: "safe" }));
});

test("receipt log snapshots reject removed, fractional, negative, duplicate and inconsistent indices but retain zero topics", async () => {
  const s = setup(), c = await capture(s);
  for (const value of [NaN, 0.5, -1]) {
    install(s, c); s.state.receipt.logs[0].index = value;
    await assert.rejects(run(s, c), /receipt log/);
  }
  for (const change of [
    logs => { logs[0].removed = true; },
    logs => { logs[1].index = 0; },
    logs => { logs[0].transactionHash = H("another tx"); },
  ]) {
    install(s, c); change(s.state.receipt.logs); await assert.rejects(run(s, c), /receipt log/);
  }
  install(s, c);
  s.state.receipt.logs.push({ ...s.state.receipt.logs[0], address: A(999), topics: [H("unrelated"), ZeroHash], data: "0x" });
  renumber(s.state.receipt.logs);
  assert.equal((await run(s, c)).commitment, c.commitment);
});

test("every original page and header needs its immutable bytes, fresh append and complete catalog event", async () => {
  const s = setup(), c = await capture(s);
  const firstPage = rh.artistRecoveredHydrationPageId({ chainId: 1n, registry: s.destination.registry,
    coordinator: s.deployment.destination.coordinator.address }, c.commitment, c.descriptor, 0n);
  for (const change of [
    () => {
      const removed = namedLogs(s, "ArtistArchiveEvidenceAppendedV2")[0];
      s.state.receipt.logs = s.state.receipt.logs.filter(log => log !== removed);
    },
    () => {
      const removed = namedLogs(s, "ArtistStoredPayload", s.destination.archive)[0];
      s.state.receipt.logs = s.state.receipt.logs.filter(log => log !== removed);
    },
    () => { s.state.evidence.set(c.evidenceId, "0x1234"); },
    () => { s.state.codes.set(s.state.metadata.get(firstPage)[1], "0x6000"); },
  ]) {
    install(s, c); change(); renumber(s.state.receipt.logs);
    await assert.rejects(run(s, c), /Archive|catalog|carrier|payload/i);
  }
});

test("omitting both owner and Archive payload events or reversing owner apply order cannot hide a partial import", async () => {
  const s = setup(), c = await capture(s);
  install(s, c);
  const hashToOmit = c.owners[4].payload.publications[0].payloadHash;
  s.state.receipt.logs = s.state.receipt.logs.filter(log => {
    if (log.topics[0] !== abi.getEvent("ArtistStoredPayload").topicHash) return true;
    return abi.decodeEventLog("ArtistStoredPayload", log.data, log.topics).payloadHash !== hashToOmit;
  });
  renumber(s.state.receipt.logs);
  await assert.rejects(run(s, c), /Complete original payload catalog/);
  install(s, c);
  [s.state.receipt.logs[0], s.state.receipt.logs[1]] = [s.state.receipt.logs[1], s.state.receipt.logs[0]];
  renumber(s.state.receipt.logs);
  await assert.rejects(run(s, c), /owner payload apply ordering/);
  install(s, c);
  const sync = namedLogs(s, "ArtistStoredPayload", s.destination.archive).slice(-3);
  const commit = namedLogs(s, "RecoveredArtistAuthorityHydrated")[0];
  s.state.receipt.logs = s.state.receipt.logs.filter(log => !sync.includes(log));
  s.state.receipt.logs.splice(s.state.receipt.logs.indexOf(commit), 0, ...sync);
  renumber(s.state.receipt.logs);
  await assert.rejects(run(s, c), /catalog ordering/);
});

test("seven-owner completion checks marker, immutable prefix, revision and no synthetic native record", async () => {
  const s = setup(), c = await capture(s);
  for (const [method, response, expected] of [
    ["authorityHydrationCommitment", [H("wrong marker")], /commitment|marker/i],
    ["recoveredHydrationImportedPrefix", [c.owners[5].payload.provenance, c.commitment, c.after[5].revision + 1n], /prefix|revision/i],
    ["ownerStateSnapshotV2", [{ ...c.after[5], stateRoot: H("wrong after root") }], /after-root/i],
    ["artistNativeReceiptCount", [1n], /synthetic/],
  ]) {
    install(s, c); s.state.hooks.length = 0;
    s.state.hooks.push(call => call.tag === 12 && call.host === s.destination.owners[5] && call.method === method ? response : undefined);
    await assert.rejects(run(s, c), expected);
  }
});

test("immutable imported prefix and evidence survive later owner revisions without rereading former source dependencies", async () => {
  const s = setup(), c = await capture(s); install(s, c);
  s.state.hooks.push(({ method, host, tag }) => {
    if (tag !== 12) return;
    if (s.source.owners.includes(host) || host === s.source.registry) throw Error("historical source no longer available");
    const owner = s.destination.owners.indexOf(host);
    if (method === "ownerStateSnapshotV2" && owner >= 0) {
      return [{ ...c.after[owner], revision: c.after[owner].revision + 1n, stateRoot: H(`later state${owner}`), recordChainTip: H(`later tip${owner}`) }];
    }
  });
  const result = await run(s, c);
  assert.equal(result.historicalImportProven, true);
  assert.equal(result.ownerSnapshots[2].revision, c.after[2].revision + 1n);
});

test("content-key dedup retains an old Archive pointer while fresh page metadata has its new STOP carrier", async () => {
  const s = setup(), preliminary = await capture(s);
  const page = `0x${preliminary.profileEvidence.slice(2, 2 + 40960)}`;
  const oldPointer = A(600);
  s.state.codes.set(oldPointer, `0x00${page.slice(2)}`);
  s.state.beforeCatalogs.set(s.destination.archive, [{ pointer: oldPointer,
    payloadType: H("ARTIST_OPERATION_EVIDENCE"), payloadHash: keccak256(page) }]);
  const c = await capture(s); install(s, c);
  assert.equal(c.profileEvidence, preliminary.profileEvidence);
  assert.notEqual(s.state.metadata.values().next().value[1], oldPointer);
  assert.equal((await run(s, c)).commitment, c.commitment);
});

test("both Safe layouts require independent expected hash, success after all evidence, and no failure", async () => {
  const s = setup(), c = await capture(s);
  for (const execution of ["legacy", "indexed"]) {
    install(s, c, execution);
    await assert.rejects(workflow.reconcileArtistRecoveredHydrationReceipt(s.provider, c, H("tx"), {
      execution: "safe", expectedSafeTxHash: H("independent different hash"),
    }), /hash|Safe/i);
  }
  install(s, c, "legacy");
  const success = s.state.receipt.logs.pop(); s.state.receipt.logs.unshift(success); renumber(s.state.receipt.logs);
  await assert.rejects(run(s, c, "legacy"), /Safe success|order/i);
  const installed = install(s, c, "indexed");
  s.state.receipt.logs.pop();
  installed.emit(c.prepared.caller, "ExecutionFailure", [H("safeHash"), 0n], safeIndexed);
  await assert.rejects(run(s, c, "indexed"), /failed|failure/i);
});

test("copied provider logs cannot change the shared Safe verifier during later awaited readbacks", async () => {
  const s = setup(), c = await capture(s); install(s, c, "legacy");
  let mutated = false;
  s.state.hooks.push(({ method }) => {
    if (!mutated && method === "getCode") {
      mutated = true;
      const log = s.state.receipt.logs.at(-1);
      const event = safePlain.encodeEventLog("ExecutionSuccess", [H("mutated provider hash"), 0n]);
      log.data = event.data; log.topics = event.topics;
    }
  });
  assert.equal((await run(s, c, "legacy")).historicalImportProven, true);
  assert.equal(mutated, true);
});

test("historical and immediately prior context must reproduce, and original calls compose with the shared Safe planner", async () => {
  const s = setup(), c = await capture(s); install(s, c);
  s.state.hooks.push(({ method, tag, host }) => method === "getCode" && tag === 11
    && host === s.deployment.preparationLibrary.address ? "0x" : undefined);
  await assert.rejects(run(s, c), /runtime|code/i);
  const plan = createSafeCallPlan(1n, "Original recovered authority hydration", [{ safe: c.prepared.caller,
    intent: "Hydrate all seven original owners", call: c.prepared.call, abi: fixture.abis.registry }]);
  verifySafeCallPlan(plan, [fixture.abis.registry]);
  assert.equal(plan.steps[0].transaction.operation, 0);
  assert.equal(BigInt(plan.steps[0].transaction.value), 0n);
});

test("complete finality and entropy guards preserve actual later outcomes and reject changed state or runtime", async () => {
  const s = setup({ external: true }), c = await capture(s);
  assert.notEqual(c.certificate.externalGuards.entropy[0].findingRecordHash,
    c.certificate.externalGuards.entropy[0].receipt.artistRecordHash);
  assert.equal(c.certificate.externalGuards.finality[0].actionTerminal, true);
  for (const [method, response, expected] of [
    ["finalityRecoveryRecord", [{ ...s.certificate.externalGuards.finality[0].record, executed: false }], /finality recovery record/],
    ["entropyRecoveryIntentTerminal", [false], /entropy terminal/],
    ["freshRecoveryReceipt", [{ ...s.certificate.externalGuards.entropy[0].receipt, artistRecordHash: H("substituted finding") }], /entropy recovery receipt/],
    ["getCode", "0x6001", /runtime|code/i],
  ]) {
    const bad = setup({ external: true });
    bad.state.hooks.push(call => call.method === method && (method !== "getCode" || call.host === A(178)) ? response : undefined);
    await assert.rejects(capture(bad), expected);
  }
});

function repeatedSource(s) {
  const older = structuredClone(s.origin);
  const pins = Array.from({ length: 9 }, (_, i) => {
    const address = A(500 + i), code = `0x6150${i.toString(16).padStart(2, "0")}6000`;
    s.state.codes.set(address, code);
    return { address, codeHash: keccak256(code) };
  });
  older.registry = pins[7].address; older.archive = pins[8].address; older.coordinator = A(570);
  older.owners = pins.slice(0, 7).map(pin => pin.address);
  older.ownerCodeHashes = pins.slice(0, 7).map(pin => pin.codeHash);
  const oldSuite = { ...s.source, registry: older.registry, archive: older.archive, owners: older.owners };
  older.suiteConfigurationHash = hash([ARTIST_HYDRATION_SUITE_TUPLE], [oldSuite]);
  const oldHash = rh.artistRecoveredHydrationOriginHash(older), prior = H("original prior A-to-B import");
  const p = s.certificate.admission.provenance;
  const oldEra = structuredClone(p.eras[0]); oldEra.originHash = oldHash;
  const oldJournal = p.journals.map(rows => rows.map(row => ({ ...row,
    position: { ...row.position, point: { ...row.position.point, environmentHash: oldHash } } })));
  const oldAliases = p.aliases.map((rows, index) => rows.map(row => ({ ...row, originHash: oldHash,
    originalKey: rh.artistRecoveredHydrationReplayKey(older, index, { surface: row.surface, scope: row.scope }),
    admittedAt: { ...row.admittedAt, environmentHash: oldHash },
  })).sort((a, b) => a.originalKey.localeCompare(b.originalKey)));
  const oldProvenance = { origins: [older], eras: [oldEra], journals: oldJournal, aliases: oldAliases };
  p.eras[0].nativeCounts = Array(7).fill(0n);
  // A fresh prior destination had revisions [0,0,3,0,0,0,0]; import adds one per owner.
  const importedRevisions = [1n, 1n, 4n, 1n, 1n, 1n, 1n];
  p.eras[0].lowerRevisions = importedRevisions;
  p.eras[0].priorImportCommitment = prior;
  p.origins.unshift(older); p.eras.unshift(oldEra); p.journals = oldJournal;
  p.aliases = p.aliases.map((rows, index) => [...rows, ...oldAliases[index]].sort((a, b) => a.originalKey.localeCompare(b.originalKey)));
  for (let index = 0; index < 7; index++) {
    const { header, payload } = rh.decodeArtistRecoveredHydrationOwnerPayload(s.certificate.data[index].typedState, index);
    s.certificate.data[index].typedState = rh.encodeArtistRecoveredHydrationOwnerPayload({ ...payload,
      provenance: rh.artistRecoveredHydrationOwnerProvenance(p, index) }, index, header.requiredFeatures | 16n);
  }
  s.certificate.externalGuards.provenanceCommitment = rh.artistRecoveredHydrationProvenanceHash(p);
  s.request.expectedSourceImportCommitment = prior;
  s.state.hooks.push(({ method, host }) => {
    if (host === older.coordinator && method === "authorityHydrationSuite") return [oldSuite];
    const index = older.owners.indexOf(host);
    if (index >= 0) {
      const values = { artistRegistry: older.registry, operationCoordinator: older.coordinator, archiveV2: older.archive,
        core: older.core, mintManager: older.manager, domainId: domains[index], deploymentChainId: 1n };
      if (method in values) return [values[method]];
    }
    const sourceIndex = s.source.owners.indexOf(host);
    if (sourceIndex >= 0) {
      if (method === "artistNativeReceiptCount") return [0n];
      if (method === "authorityHydrationCommitment") return [prior];
      if (method === "recoveredHydrationImportedPrefix") return [rh.artistRecoveredHydrationOwnerProvenance(oldProvenance, sourceIndex), prior, importedRevisions[sourceIndex]];
    }
  });
  return { older, oldHash, prior };
}

test("A-to-B-to-C capture retains original era domains, complete old prefixes and current historical guard exceptions", async () => {
  const s = setup(), prior = repeatedSource(s), c = await capture(s);
  assert.equal(c.certificate.admission.provenance.eras.length, 2);
  assert.equal(c.prepared.request.expectedSourceImportCommitment, prior.prior);
  assert.equal(c.certificate.admission.provenance.journals[2][0].position.point.environmentHash, prior.oldHash);
  assert.equal(c.owners[2].payload.provenance.aliases.length, 8);
  assert.equal(c.owners[2].historicalCells.length, 3);
  install(s, c);
  assert.equal((await run(s, c)).historicalImportProven, true);
  const bad = setup(); repeatedSource(bad);
  bad.state.hooks.unshift(({ method, host }) => method === "recoveredHydrationImportedPrefix" && host === bad.source.owners[2]
    ? [{ origins: [], eras: [], journal: [], aliases: [] }, H("original prior A-to-B import"), 5n] : undefined);
  await assert.rejects(capture(bad), /Source imported prefix differs/);
});

test("block identity is rechecked and receipts require a strictly later mined block", async () => {
  const s = setup(); let reads = 0;
  s.provider.getBlock = async tag => ({ number: tag, timestamp: 100 + tag,
    hash: ++reads === 1 ? H(`block${tag}`) : H("reorganized block") });
  await assert.rejects(capture(s), /block|reorg/i);
  const stable = setup(), c = await capture(stable); install(stable, c);
  stable.state.tx.blockNumber = 10; stable.state.receipt.blockNumber = 10;
  stable.state.tx.blockHash = H("block10"); stable.state.receipt.blockHash = H("block10");
  await assert.rejects(run(stable, c), /follow the reviewed capture/);
});
