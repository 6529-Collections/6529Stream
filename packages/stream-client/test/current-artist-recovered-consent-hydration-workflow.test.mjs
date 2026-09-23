import test from "node:test";
import assert from "node:assert/strict";
import { fixture, compiledABI } from "./current-artist-recovered-consent-hydration-fixture.mjs";
import { AbiCoder, Interface, ParamType, ZeroAddress, ZeroHash, getAddress, id, keccak256 } from "ethers";
import * as consent from "../dist/current-artist-recovered-consent-hydration.js";
import * as original from "../dist/current-artist-recovered-hydration.js";
import * as originalWorkflow from "../dist/current-artist-recovered-hydration-workflow.js";
// Test-only name adapter lets unchanged seven-owner mock scaffolding serve both profiles.
const rh = Object.fromEntries(Object.entries(consent).map(([name, value]) => [
  name.replaceAll("RECOVERED_CONSENT_HYDRATION", "RECOVERED_HYDRATION").replaceAll("RecoveredConsentHydration", "RecoveredHydration"), value,
]));
import * as workflow from "../dist/current-artist-recovered-consent-hydration-workflow.js";
import { ARTIST_HYDRATION_SUITE_TUPLE } from "../dist/current-artist-authority-hydration.js";
import { createSafeCallPlan, verifySafeCallPlan } from "../dist/safe-plan.js";

const segments = ["registry", "coordinator", "archive", "owner", "checkpoint", "recoveredOwner", "chronology",
  "history", "nativeReceipts", "reconstruction", "timing", "coreHost", "governanceFacts", "finalityRecovery",
  "finalityBinding", "entropyUnavailability", "entropyFreshRecovery", "hydrationOwner", "hydrationCoordinator", "recoveredCoordinator", "recoveredConsents", "contentRecords", "consentOwner"];
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
  const capability = (i, features = options.capabilities ?? 511n) => ({ profile: rh.ARTIST_RECOVERED_HYDRATION_PROFILE,
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
      if (["0x72c84763", "0x4925300f"].includes(tx.data.slice(0, 10))) {
        fragment = preparedAbi.fragments.find(f => f.type === "function" && f.name === "prepare" && f.inputs.length === (tx.data.startsWith("0x4925300f") ? 3 : 2));
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
        case "hydrateRecoveredArtistAuthorityWithConsents":
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
          return encode([index < 0 ? zeroCell() : owner !== 2 ? (post ? cells[owner][index] : zeroCell()) : index === 0 ? zeroCell() : index < 3 ? { commitment: H(`destination guard${index}`), touchedRevision: 3n, kind: 1n, status: 2n }
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
  const result = await workflow.captureArtistRecoveredConsentHydration(s.provider, s.deployment, A(80), { request: s.request, royaltyFreezes: s.royaltyFreezes ?? [] }, { blockTag: 10, gasLimit: 10000000n });
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

const run = (s, c, execution = "direct") => workflow.reconcileArtistRecoveredConsentHydrationReceipt(s.provider, c, H("tx"),
  execution === "direct" ? { execution: "direct" } : { execution: "safe", expectedSafeTxHash: H("safeHash") });
const renumber = logs => logs.forEach((log, index) => { log.index = index; });

function withContent(s, options = {}) {
  const p = s.certificate.admission.provenance;
  const artistId = s.certificate.query.artistId;
  const collectionId = s.certificate.query.collectionId;
  const bindingHash = s.certificate.query.bindingHash;
  const environmentHash = rh.artistRecoveredHydrationOriginHash(s.origin);
  const terms = { collectionId, metadataContract: A(500), familyId: H("historical content family"), newStateHash: H("same terms") };
  const consents = options.no17 ? [] : [0, 1].map(i => ({ recordHash: H(`original content${i}`), artistId,
    bindingGeneration: 1n, terms: { ...terms }, authorityClass: options.authorityClass ?? 1n }));
  const royalties = options.no20 ? [] : [0, 1].map(i => ({
    terms: { resolver: A(501 + i), collectionId, revenueClass: H("ROYALTY_ERC2981"), expectedAssignmentHash: H(`old assignment${i}`) },
    item: { recordHash: H(`original royalty${i}`), artistId, bindingGeneration: 1n },
    grant: i === 0 && options.delegated ? H("retained expired grant") : ZeroHash,
  }));
  const locks = [H("lock A"), H("lock B"), H("lock C")].sort();
  const freezes = options.no21 ? [] : [0, 1].map(i => ({ recordHash: H(`original freeze${i}`), artistId,
    bindingGeneration: 1n, metadataContract: A(503), lockClasses: locks.slice(i, i + 2),
    expectedStateHash: H(`historical state${i}`), authorityClass: options.authorityClass ?? 1n }));
  const rows = [...consents.map(row => [17n, row.recordHash, hash(["bytes32", "bytes32"], [
    consent.artistRecoveredConsentHydrationContentScope(row.terms), row.recordHash])]),
  ...royalties.map(row => [20n, row.item.recordHash, consent.artistRecoveredConsentHydrationRoyaltyScope(row.terms, artistId)]),
  ...freezes.map(row => [21n, row.recordHash, hash(["bytes32", "uint256", "uint64", "bytes32"], [H("CONTENT"), collectionId, 1n, row.recordHash])])];
  p.journals[6] = rows.map(([operation, recordHash], i) => ({
    position: { point: { environmentHash, ownerIndex: 6n, ownerRevision: BigInt(i + 1) }, nativeIndex: BigInt(i) },
    receipt: { operation, artistId, collectionId, recordHash },
  }));
  p.eras[0].nativeCounts[6] = BigInt(rows.length);
  const cp = p.eras[0].checkpoints[6];
  cp.ownerState.revision = BigInt(rows.length);
  cp.replayCount = BigInt(rows.length);
  cp.nonceRoot = ZeroHash;
  const data = s.certificate.data[6];
  for (const [operation, recordHash, scope] of rows) {
    const logical = { surface: H(`consent_finality.replay.${operation === 17n ? "content_consent_key" : "freeze_key"}`), scope };
    data.origins.push(logical);
    data.sourceKeys.push(rh.artistRecoveredHydrationReplayKey(s.origin, 6, logical));
    data.cells.push({ commitment: recordHash, touchedRevision: BigInt(data.cells.length + 1), kind: 1n, status: 2n });
  }
  p.aliases[6] = rows.map((_, i) => ({ originHash: environmentHash, ownerIndex: 6n, ...data.origins[i],
    originalKey: data.sourceKeys[i], cell: data.cells[i], admittedAt: p.journals[6][i].position.point }))
    .sort((a, b) => a.originalKey.localeCompare(b.originalKey));
  const artistRecords = p.journals.flat().map(row => row.receipt.recordHash);
  s.certificate.query.records.splice(0, s.certificate.query.records.length, ...artistRecords);
  const collectionRecords = p.journals.flat().filter(row => row.receipt.collectionId === collectionId).map(row => row.receipt.recordHash);
  s.certificate.admission.collections[0].records.splice(0, s.certificate.admission.collections[0].records.length, ...collectionRecords);
  s.certificate.externalGuards.provenanceCommitment = rh.artistRecoveredHydrationProvenanceHash(p);
  const local = rh.artistRecoveredHydrationOwnerProvenance(p, 6);
  s.content = { original: { provenance: rh.artistRecoveredHydrationOwnerProvenanceHash(local, 6), artistId, collectionId,
    bindingHash, keys: [], policies: [], economics: [], sales: [] }, consents, royalties, freezes };
  for (let i = 0; i < 7; i++) {
    const { payload } = rh.decodeArtistRecoveredHydrationOwnerPayload(s.certificate.data[i].typedState, i);
    s.certificate.data[i].typedState = rh.encodeArtistRecoveredHydrationOwnerPayload({ ...payload,
      provenance: rh.artistRecoveredHydrationOwnerProvenance(p, i),
      semanticState: i === 6 ? consent.encodeArtistRecoveredConsentHydrationContentBundle(s.content, s.certificate.query, local) : payload.semanticState,
    }, i, 257n);
  }
  s.royaltyFreezes = royalties.map(row => ({ ...row.terms }));
  s.state.hooks.push(({ method, host, args }) => {
    if (![s.source.owners[6], s.destination.owners[6]].includes(host)) return;
    if (method === "contentConsentRecord") return [consents.find(row => row.recordHash === args[0])];
    if (method === "contentConsentAt") return [consents.at(-1)];
    if (method === "royaltyFreezeRecord") return [royalties.find(row => row.terms.expectedAssignmentHash === args[0].expectedAssignmentHash).item];
    if (method === "contentFreezeRecord") return [freezes.find(row => row.recordHash === args[0])];
    if (method === "contentFreezeAt") return [freezes.findLast(row => row.lockClasses.includes(args[3]))];
    if (method === "recordDelegation") return [royalties.find(row => row.item.recordHash === args[0])?.grant ?? ZeroHash];
  });
  return s;
}

test("511 captures complete repeated17, ordered20 and overlapping21 with exact original simulation", async () => {
  const s = withContent(setup(), { delegated: true }), c = await capture(s);
  assert.equal(rh.decodeArtistRecoveredHydrationOwnerPayload(c.certificate.data[6].typedState, 6).header.requiredFeatures, 257n);
  assert.equal(c.prepared.call.data.slice(0, 10), "0x1e2d2f62");
  assert.deepEqual(c.prepared.royaltyFreezes, s.royaltyFreezes);
  const simulation = await workflow.simulateArtistRecoveredConsentHydration(s.provider, c, { blockTag: 11, gasLimit: 10000000n });
  assert.equal(simulation.commitment, c.commitment);
  const actual = s.state.calls.findLast(row => row.method === "hydrateRecoveredArtistAuthorityWithConsents");
  assert.equal(actual.from, A(80));
  assert.equal(actual.value, 0n);
  assert.equal(actual.args[1].length, 2);
  assert.equal(s.state.calls.filter(row => row.method === "prepare").every(row => row.args.length === 3), true);
  assert.equal(s.state.calls.some(row => [A(500), A(501), A(502), A(503)].includes(row.host)), false);
});

test("no-content old and new routes retain byte-identical original certificate and Archive preimages", async () => {
  const s = setup(), c = await capture(s);
  const old = await originalWorkflow.captureArtistRecoveredHydration(s.provider, s.deployment, A(80), s.request,
    { blockTag: 10, gasLimit: 10000000n });
  assert.deepEqual(old.certificate, c.certificate);
  assert.equal(old.commitment, c.commitment);
  assert.equal(old.profileEvidence, c.profileEvidence);
  assert.equal(old.operationEvidence, c.operationEvidence);
  assert.deepEqual(old.after, c.after);
  assert.notEqual(old.prepared.call.data.slice(0, 10), c.prepared.call.data.slice(0, 10));
  assert.equal(original.normalizeArtistRecoveredHydrationPrepared(old.certificate).query.artistId, c.certificate.query.artistId);
});

test("old255 rejects content and capture profiles cannot be substituted", async () => {
  const s = withContent(setup()), c = await capture(s);
  assert.throws(() => original.normalizeArtistRecoveredHydrationPrepared(s.certificate), /feature|header/i);
  await assert.rejects(originalWorkflow.simulateArtistRecoveredHydration(s.provider, c, { blockTag: 11, gasLimit: 10000000n }), /call|key|field|feature/i);
  const oldState = setup();
  const old = await originalWorkflow.captureArtistRecoveredHydration(oldState.provider, oldState.deployment, A(80), oldState.request,
    { blockTag: 10, gasLimit: 10000000n });
  await assert.rejects(workflow.simulateArtistRecoveredConsentHydration(oldState.provider, old, { blockTag: 11, gasLimit: 10000000n }), /call|key|field|royalty/i);
});

test("content without20 permits an empty selector array while missing, extra, and reordered20 reject", async () => {
  for (const opts of [{ no20: true, no21: true }, { no20: true, no17: true }]) {
    const s = withContent(setup(), opts), c = await capture(s);
    assert.equal(c.prepared.royaltyFreezes.length, 0);
  }
  for (const change of [rows => rows.pop(), rows => rows.reverse(), rows => rows.push({ ...rows[0], expectedAssignmentHash: H("extra") })]) {
    const s = withContent(setup()); change(s.royaltyFreezes);
    await assert.rejects(capture(s), /royalty|selector/i);
  }
  const empty = setup();
  empty.royaltyFreezes = [{ resolver: A(500), collectionId: 8n, revenueClass: H("ROYALTY_ERC2981"), expectedAssignmentHash: H("extra") }];
  await assert.rejects(capture(empty), /royalty|selector/i);
});

test("content source readback authenticates each record, principal association and latest per-scope heads", async () => {
  const bad = [
    ["contentConsentRecord", s => ({ ...s.content.consents[0], authorityClass: 3n })],
    ["contentConsentAt", s => s.content.consents[0]],
    ["recordDelegation", () => H("invented grant")],
    ["royaltyFreezeRecord", s => ({ ...s.content.royalties[0].item, recordHash: H("different") })],
    ["contentFreezeRecord", s => ({ ...s.content.freezes[0], expectedStateHash: H("different") })],
    ["contentFreezeAt", s => s.content.freezes[0]],
  ];
  for (const [method, changed] of bad) {
    const s = withContent(setup());
    s.state.hooks.unshift(row => row.method === method ? [changed(s)] : undefined);
    await assert.rejects(capture(s), /record|association|head/i);
  }
});

test("seven-owner paged completion and content maps reconcile direct and both Safe layouts", async () => {
  for (const execution of ["direct", "legacy", "indexed"]) {
    const s = withContent(setup(), { authorityClass: 3n, delegated: true }), c = await capture(s);
    install(s, c, execution);
    const result = await run(s, c, execution);
    assert.equal(result.historicalImportProven, true);
    assert.equal(result.currentAuthorityClaimed, false);
    assert.equal(result.ownerSnapshots.length, 7);
    assert.ok(result.events.some(row => row.event === "RecoveredArtistAuthorityHydrated"));
  }
});

test("capture copies ordered royalty selectors before awaiting and simulations reject altered prepared transport", async () => {
  const s = withContent(setup()), expected = structuredClone(s.royaltyFreezes);
  const originalNetwork = s.provider.getNetwork;
  s.provider.getNetwork = async () => {
    s.royaltyFreezes.reverse();
    s.provider.getNetwork = originalNetwork;
    return { chainId: 1n };
  };
  const c = await capture(s);
  assert.deepEqual(c.prepared.royaltyFreezes, expected);
  const changed = structuredClone(c);
  changed.prepared.royaltyFreezes.reverse();
  await assert.rejects(workflow.simulateArtistRecoveredConsentHydration(s.provider, changed,
    { blockTag: 11, gasLimit: 10000000n }), /call|capture|royalty/i);
  const wrongCall = structuredClone(c);
  wrongCall.prepared.call.data = original.prepareArtistRecoveredHydrationCall(c.prepared.registry,
    c.prepared.caller, c.prepared.request).call.data;
  await assert.rejects(workflow.simulateArtistRecoveredConsentHydration(s.provider, wrongCall,
    { blockTag: 11, gasLimit: 10000000n }), /call|capture/i);
});

test("source511 and future512 feature boundaries remain separate from advertised capability supersets", async () => {
  const missing = withContent(setup({ capabilities: 255n }));
  await assert.rejects(capture(missing), /capability|feature/i);
  const unknown = withContent(setup());
  for (let i = 0; i < 7; i++) {
    const decoded = rh.decodeArtistRecoveredHydrationOwnerPayload(unknown.certificate.data[i].typedState, i);
    const raw = coder.decode(["bytes32", "uint16", rh.ARTIST_RECOVERED_HYDRATION_ENVELOPE_TUPLE], unknown.certificate.data[i].typedState);
    unknown.certificate.data[i].typedState = coder.encode(
      ["bytes32", "uint16", rh.ARTIST_RECOVERED_HYDRATION_ENVELOPE_TUPLE],
      [raw[0], raw[1], { header: { ...decoded.header, requiredFeatures: 769n }, payload: raw[2].payload }]);
  }
  await assert.rejects(capture(unknown), /feature|header/i);
});

test("later Consent revision preserves immutable content evidence without rereading mutable heads", async () => {
  const s = withContent(setup()), c = await capture(s);
  install(s, c);
  s.state.hooks.unshift(({ method, host, tag }) => {
    if (host !== s.destination.owners[6] || tag !== 12) return;
    if (method === "ownerStateSnapshotV2") return [{ ...c.after[6], revision: c.after[6].revision + 2n,
      stateRoot: H("later content state"), recordChainTip: H("later semantic tip") }];
    if (["contentConsentAt", "contentFreezeAt"].includes(method)) throw Error("Later current heads are unrelated");
  });
  assert.equal((await run(s, c)).historicalImportProven, true);
  s.state.hooks.unshift(({ method, host, tag }) => host === s.destination.owners[6] && tag === 12 && method === "contentConsentRecord"
    ? [{ ...s.content.consents[0], terms: { ...s.content.consents[0].terms, newStateHash: H("corrupt old record") } }] : undefined);
  await assert.rejects(run(s, c), /content record/i);
});

test("Registry simulation preserves late rollback errors and retries the same immutable WithConsents call", async () => {
  const s = withContent(setup()), c = await capture(s);
  const revert = ({ method }) => {
    if (method === "hydrateRecoveredArtistAuthorityWithConsents") throw Error("original late final guard rollback");
  };
  s.state.hooks.unshift(revert);
  await assert.rejects(workflow.simulateArtistRecoveredConsentHydration(s.provider, c,
    { blockTag: 11, gasLimit: 10000000n }), /original late final guard rollback/);
  s.state.hooks.shift();
  const retried = await workflow.simulateArtistRecoveredConsentHydration(s.provider, c,
    { blockTag: 11, gasLimit: 10000000n });
  assert.equal(retried.capture.prepared.call.data, c.prepared.call.data);
  assert.equal(retried.futureExecutionGuaranteed, false);
});

test("exact Safe transport rejects old selector, altered royalty order, value and operation1", async () => {
  const s = withContent(setup()), c = await capture(s);
  for (const changed of [
    { data: original.prepareArtistRecoveredHydrationCall(c.prepared.registry, c.prepared.caller, c.prepared.request).call.data },
    { data: consent.prepareArtistRecoveredConsentHydrationCall(c.prepared.registry, c.prepared.caller,
      { request: c.prepared.request, royaltyFreezes: [...c.prepared.royaltyFreezes].reverse() }).call.data },
    { value: 1n }, { operation: 1n },
  ]) {
    install(s, c, "legacy");
    s.state.tx.data = safe.encodeFunctionData("execTransaction", [c.prepared.registry, changed.value ?? 0n,
      changed.data ?? c.prepared.call.data, changed.operation ?? 0n, 0n, 0n, 0n, ZeroAddress, ZeroAddress, "0x"]);
    await assert.rejects(run(s, c, "legacy"), /call|calldata|value|operation|transport/i);
  }
  install(s, c, "indexed");
  await assert.rejects(workflow.reconcileArtistRecoveredConsentHydrationReceipt(s.provider, c, H("tx"),
    { execution: "safe", expectedSafeTxHash: H("wrong independent hash") }), /Safe|hash|event/i);
});

test("all pages, header and ordered payload catalogs are mandatory before Safe success", async () => {
  const s = withContent(setup()), c = await capture(s);
  install(s, c, "legacy");
  const summary = s.state.receipt.logs.find(log => log.topics[0] === abi.getEvent("RecoveredArtistAuthorityHydrated").topicHash);
  s.state.receipt.logs = s.state.receipt.logs.filter(log => log !== summary);
  await assert.rejects(run(s, c, "legacy"), /event|commit/i);
  install(s, c, "legacy");
  const append = s.state.receipt.logs.find(log => log.topics[0] === abi.getEvent("ArtistArchiveEvidenceAppendedV2").topicHash);
  const parsed = abi.decodeEventLog("ArtistArchiveEvidenceAppendedV2", append.data, append.topics);
  s.state.receipt.logs = s.state.receipt.logs.filter(log => log !== append
    && !(log.address === s.destination.archive && log.topics[0] === abi.getEvent("ArtistStoredPayload").topicHash
      && abi.decodeEventLog("ArtistStoredPayload", log.data, log.topics).payloadHash === parsed.contentHash));
  renumber(s.state.receipt.logs);
  await assert.rejects(run(s, c, "legacy"), /event|catalog|page/i);
  install(s, c, "indexed");
  const logs = s.state.receipt.logs;
  const owner2 = logs.findIndex(log => log.address === s.destination.owners[2]);
  const owner6 = logs.findIndex(log => log.address === s.destination.owners[6]);
  [logs[owner2], logs[owner6]] = [logs[owner6], logs[owner2]];
  renumber(logs);
  await assert.rejects(run(s, c, "indexed"), /ordering/i);
  install(s, c, "indexed");
  const first = s.state.receipt.logs.pop();
  s.state.receipt.logs.unshift(first); renumber(s.state.receipt.logs);
  await assert.rejects(run(s, c, "indexed"), /Safe success precedes/i);
});

test("captured WithConsents ordinary CALL composes through the shared verified Safe planner", async () => {
  const s = withContent(setup()), c = await capture(s);
  const plan = createSafeCallPlan(1n, "Original recovered content hydration", [{
    safe: c.prepared.caller, intent: "Hydrate retained original content history", call: c.prepared.call,
    abi: compiledABI.registry,
  }]);
  assert.equal(verifySafeCallPlan(plan, [compiledABI.registry]).steps[0].transaction.operation, 0);
  const changed = structuredClone(plan);
  changed.steps[0].transaction.operation = 1;
  assert.throws(() => verifySafeCallPlan(changed, [compiledABI.registry]), /operation|CALL/i);
});

function repeatedContentSource(s) {
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
  p.aliases = p.aliases.map((rows, index) => [...rows.map(row => ({ ...row,
    admittedAt: { ...row.admittedAt, environmentHash: oldHash },
  })), ...oldAliases[index]].sort((a, b) => a.originalKey.localeCompare(b.originalKey)));
  for (let i = 0; i < 7; i++) p.eras[1].checkpoints[i].ownerState.revision = importedRevisions[i];
  const contentLocal = rh.artistRecoveredHydrationOwnerProvenance(p, 6);
  s.content.original.provenance = rh.artistRecoveredHydrationOwnerProvenanceHash(contentLocal, 6);
  for (let index = 0; index < 7; index++) {
    const { header, payload } = rh.decodeArtistRecoveredHydrationOwnerPayload(s.certificate.data[index].typedState, index);
    s.certificate.data[index].typedState = rh.encodeArtistRecoveredHydrationOwnerPayload({ ...payload,
      provenance: rh.artistRecoveredHydrationOwnerProvenance(p, index),
      semanticState: index === 6 ? consent.encodeArtistRecoveredConsentHydrationContentBundle(s.content, s.certificate.query, contentLocal) : payload.semanticState,
    }, index, header.requiredFeatures | 16n);
  }
  s.certificate.externalGuards.provenanceCommitment = rh.artistRecoveredHydrationProvenanceHash(p);
  s.request.expectedSourceImportCommitment = prior;
  s.state.hooks.push(({ method, host, args }) => {
    if (host === older.coordinator && method === "authorityHydrationSuite") return [oldSuite];
    const index = older.owners.indexOf(host);
    if (index >= 0) {
      const values = { artistRegistry: older.registry, operationCoordinator: older.coordinator, archiveV2: older.archive,
        core: older.core, mintManager: older.manager, domainId: domains[index], deploymentChainId: 1n };
      if (method in values) return [values[method]];
    }
    const sourceIndex = s.source.owners.indexOf(host);
    if (sourceIndex >= 0) {
      if (method === "recoveredHydrationReplayPoint") return [p.aliases[sourceIndex].find(row => row.originalKey === args[0]).admittedAt];
      if (method === "artistNativeReceiptCount") return [0n];
      if (method === "authorityHydrationCommitment") return [prior];
      if (method === "recoveredHydrationImportedPrefix") return [rh.artistRecoveredHydrationOwnerProvenance(oldProvenance, sourceIndex), prior, importedRevisions[sourceIndex]];
    }
  });
  return { older, oldHash, prior };
}


test("second-era content retains original admission points, import revision1 and historical royalty selectors", async () => {
  const s = withContent(setup()), prior = repeatedContentSource(s), c = await capture(s);
  const local = c.owners[6].payload.provenance;
  assert.equal(local.eras[1].lowerRevision, 1n);
  assert.equal(local.eras[1].checkpoint.ownerState.revision, 1n);
  assert.equal(local.eras[1].nativeCount, 0n);
  assert.equal(local.aliases.length, 12);
  assert.equal(local.aliases.every(row => row.admittedAt.environmentHash === prior.oldHash), true);
  assert.equal(c.prepared.request.expectedSourceImportCommitment, prior.prior);
  install(s, c);
  assert.equal((await run(s, c)).historicalImportProven, true);
  s.state.hooks.unshift(({ method, host }) => method === "recoveredHydrationImportedPrefix" && host === s.source.owners[6]
    ? [{ origins: [], eras: [], journal: [], aliases: [] }, prior.prior, 1n] : undefined);
  await assert.rejects(capture(s), /Source imported prefix differs/);
});
