import test from "node:test";
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { AbiCoder, Interface, ZeroAddress, ZeroHash, getAddress, hexlify, id, keccak256, toUtf8Bytes } from "ethers";
import * as pure from "../dist/current-artist-personhood.js";
import * as workflow from "../dist/current-artist-personhood-workflow.js";
import { currentArtistTypedData } from "../dist/current-artist.js";
import { createSafeCallPlan, verifySafeCallPlan } from "../dist/safe-plan.js";

const fixture = JSON.parse(readFileSync(new URL("./fixtures/current-artist-personhood-abi.json", import.meta.url), "utf8"));
const abi = new Interface(Object.values(fixture.abis).flat().filter(f => f.type !== "constructor"));
const coder = AbiCoder.defaultAbiCoder();
const A = n => getAddress(`0x${BigInt(n).toString(16).padStart(40, "0")}`);
const H = v => id(String(v));
const hash = (types, values) => keccak256(coder.encode(types, values));
const fmt = param => param.format("full");
const bindingType = fmt(abi.getFunction("binding").outputs[0]);
const snapshotType = fmt(abi.getFunction("ownerStateSnapshotV2").outputs[0]);
const generalTypes = abi.getFunction("attestation(bytes32)").outputs.map(fmt);
const termsType = fmt(abi.getFunction("recordArtistAttestation").inputs[0]);
const authType = fmt(abi.getFunction("recordArtistAttestation").inputs[1]);
const terminalType = fmt(abi.getFunction("dormancyRecord").outputs[2]);
const proofType = "(address signer,bytes32 digest,bool direct)";
const authorityType = "(bytes32 artistId,address authorityAddress,uint8 authorityClass,uint8 status)";
const domains = ["binding_lifecycle", "collaborator_lifecycle", "identity_authority", "acceptance_lifecycle", "attribution_lifecycle", "payout_lifecycle", "consent_finality"].map(v => H(`domain:${v}`));
const safe = new Interface(["function execTransaction(address to,uint256 value,bytes data,uint8 operation,uint256 safeTxGas,uint256 baseGas,uint256 gasPrice,address gasToken,address refundReceiver,bytes signatures) returns(bool)"]);
const safe0 = new Interface(["event ExecutionSuccess(bytes32 txHash,uint256 payment)", "event ExecutionFailure(bytes32 txHash,uint256 payment)"]);
const safe1 = new Interface(["event ExecutionSuccess(bytes32 indexed txHash,uint256 payment)", "event ExecutionFailure(bytes32 indexed txHash,uint256 payment)"]);

function zero(type) {
  if (type.baseType === "array") return Array.from({ length: type.arrayLength }, () => zero(type.arrayChildren));
  if (type.baseType === "tuple") return Object.fromEntries(type.components.map(v => [v.name, zero(v)]));
  if (type.type.startsWith("uint")) return 0n;
  if (type.type === "address") return ZeroAddress;
  if (type.type === "bool") return false;
  if (type.type === "string") return "";
  return type.type === "bytes" ? "0x" : `0x${"00".repeat(Number(type.type.slice(5)))}`;
}

function setup(options = {}) {
  const codes = new Map();
  const codeFor = n => `0x60${Number(n).toString(16).padStart(2, "0")}6000`;
  const pin = n => {
    const address = A(n);
    const code = codeFor(n);
    codes.set(address, code);
    return { address, codeHash: keccak256(code) };
  };
  const components = Array.from({ length: 16 }, (_, i) => pin(i + 1));
  const deployment = {
    artist: { chainId: 1n, registry: components[7], coordinator: pin(20), components, reads: pin(21) },
    general: pin(22), moduleRegistry: pin(23), schemaRegistry: pin(24), chunkStore: pin(25),
  };
  const signer = A(60), caller = options.relay ? A(61) : signer;
  if (options.contractSigner) codes.set(signer, "0x60016000");
  const artistId = H("artist"), identityHash = H("operative");
  const binding = { artistId, artistAddress: A(90), identityRecordHash: H("registration"), bindingHash: H("binding"), generation: 2n,
    consentMode: 1n, saleConsentScope: 0n, registryImmutabilityElection: 0n, proposer: A(90), accepted: true };
  const authorityClass = options.authorityClass ?? 1n;
  const authorityStatus = authorityClass === 1n ? 1n : 3n;
  const module = { status: 1n, moduleType: H("GENERAL_ATTESTATIONS"), moduleVersion: H("6529stream.general-attestations.v2"),
    interfaceId: pure.PERSONHOOD_GENERAL_INTERFACE_ID, moduleGasLimit: 500000n, runtimeCodeHash: deployment.general.codeHash,
    deploymentManifestHash: H("deployment"), moduleManifestHash: H("module"), moduleManifestURI: "ipfs:general", registeredAt: 70n,
    statusUpdatedAt: 70n, revision: 1n };
  const definitions = [
    ["STREAM_IDENTITY_NOTARIZATION_V1", 0n, "schemas/records/STREAM_IDENTITY_NOTARIZATION_V1.json"],
    ["STREAM_IDENTITY_NOTARIZATION_JSON_PROFILE_V1", 2n, "schemas/records/STREAM_IDENTITY_NOTARIZATION_JSON_PROFILE_V1.json"],
    ["RFC8785_JCS", 1n, "schemas/museum/account-profile/RFC8785_JCS.json"],
    ["STREAM_ARTIST_PERSONHOOD_REFERENCE_JSON_PROFILE_V1", 2n, "schemas/records/STREAM_ARTIST_PERSONHOOD_REFERENCE_JSON_PROFILE_V1.json"],
  ].map(([name, kind, path], i) => {
    const bytes = hexlify(toUtf8Bytes(fixture.documents[path].text));
    const contentHash = keccak256(bytes), pointer = A(130 + i);
    codes.set(pointer, `0x00${bytes.slice(2)}`);
    return { id: H(name), bytes, pointer, facts: { exists: true, kind, status: 0n, contentHash, canonicalizationId: H("RAW_BYTES"),
      supersedesId: ZeroHash, totalBytes: BigInt((bytes.length - 2) / 2), chunkCount: 1n, declarationHash: H(name + " declaration") } };
  });
  const subject = { kind: options.subjectKind ?? 0n, collectionId: 8n, tokenId: options.subjectKind === 1n ? 900n : 0n,
    objectId: options.subjectKind === 2n ? H("mediaObject") : ZeroHash };
  const subjectId = subject.kind === 0n
    ? hash(["bytes32", "uint256", "address", "uint256"], ["0x3a882a22dad9915c9193738f63216234155080ed4c4fc9bfae446e90f1df6e16", 1n, components[9].address, 8n])
    : subject.kind === 1n
      ? hash(["bytes32", "uint256", "address", "uint256"], ["0x1e576f27850d12bc1ec9255ca277dbecfbc84fb3a9a34c474640dfca89811d7e", 1n, components[9].address, 900n])
      : hash(["bytes32", "uint256", "address", "uint256", "bytes32"], ["0x030f2701e9035fcb711b3acc44ec0bf14b4f4e344e231cdaadce7d14e590994b", 1n, components[9].address, 8n, H("mediaObject")]);
  const payload = "0x7b7d";
  const generalRecord = { attester: A(71), collectionId: 8n, subjectId, attestationType: H("INSTITUTIONAL_VERIFICATION"), attesterDID: "did:example:issuer",
    schemaId: definitions[0].id, canonicalizationId: definitions[2].id, statementURI: "ipfs:documentary", statementHash: keccak256(payload),
    supersedes: ZeroHash, artistAuthorizationRecordHash: ZeroHash, effectiveAt: 80n };
  const generalReceipt = { recorder: A(71), verificationClass: 1n, authorityQualification: 1n, recordedAt: 90n, recordIndex: 2n,
    recordChainHash: H("general chain"), authorizationDigest: ZeroHash, nonce: 7n, deadline: 95n, signatureScheme: H("ERC1271"),
    signatureBundleHash: ZeroHash, schemaDefinitionHash: definitions[0].facts.contentHash, canonicalizationDefinitionHash: definitions[2].facts.contentHash,
    profileDefinitionHash: definitions[1].facts.contentHash, authorityFamily: ZeroHash, authorizationClass: 0n, grantCollectionId: 0n,
    grantRevision: 0n, identityRegistry: components[7].address, identityRegistryCodeHash: components[7].codeHash, artistId,
    operativeIdentityRecordHash: identityHash, nativeArtistEvidenceHash: ZeroHash, nativeArtistAuthorityClass: 0n };
  const word = (type, value) => coder.encode([type], [value]);
  const words = [H("StreamGeneralAttestation(address attester,uint256 collectionId,bytes32 subjectId,bytes32 attestationType,string attesterDID,bytes32 schemaId,bytes32 canonicalizationId,string statementURI,bytes payload,bytes32 supersedes,bytes32 artistAuthorizationRecordHash,uint64 effectiveAt,uint256 nonce,uint64 deadline)"),
    word("address", generalRecord.attester), word("uint256", 8n), subjectId, generalRecord.attestationType, H(generalRecord.attesterDID),
    generalRecord.schemaId, generalRecord.canonicalizationId, H(generalRecord.statementURI), generalRecord.statementHash, ZeroHash, ZeroHash,
    word("uint256", 80n), word("uint256", 7n), word("uint256", 95n)];
  const domain = hash(["bytes32", "bytes32", "bytes32", "uint256", "address"],
    [H("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"), H("6529StreamGeneralAttestations"), H("1"), 1n, deployment.general.address]);
  const bundle = coder.encode(["bytes32", "bytes32[15]", "bytes"], [domain, words, "0x1234"]);
  generalReceipt.signatureBundleHash = keccak256(bundle);
  generalReceipt.authorizationDigest = keccak256(`0x1901${domain.slice(2)}${hash(["bytes32[15]"], [words]).slice(2)}`);
  const generalHash = hash(["bytes32", "uint256", "address", ...generalTypes], [H("6529STREAM_GENERAL_ATTESTATION_RECORD_V1"), 1n,
    deployment.general.address, generalRecord, { ...generalReceipt, recordIndex: 0n, recordChainHash: ZeroHash }]);
  codes.set(A(128), `0x00${payload.slice(2)}`);
  codes.set(A(129), `0x00${bundle.slice(2)}`);
  const prepared = pure.prepareArtistPersonhoodCall({ chainId: 1n, registry: components[7].address, core: components[9].address, caller,
    collectionId: 8n, reference: { version: 1n, profileHash: pure.PERSONHOOD_PROFILE_HASH, artistRegistry: components[7].address,
      artistId, operativeIdentityRecordHash: identityHash, notarizationHost: deployment.general.address,
      notarizationRuntimeHash: deployment.general.codeHash, notarizationRecordHash: generalHash }, nonce: 3n,
    signedAt: options.relay ? 95n : 0n, signature: options.signature ?? (options.relay ? "0x1234" : "0x"), statementURI: "ipfs:personhood" });
  const snapshots = Array.from({ length: 7 }, (_, i) => ({ domainId: domains[i], revision: 4n, stateRoot: H(`state${i}`), recordChainTip: H(`tip${i}`) }));
  const state = { codes, deployment, prepared, module, binding, signer, authorityClass, authorityStatus, definitions, generalRecord,
    generalReceipt, generalHash, subject, payload, bundle, snapshots, calls: [], hooks: [], receipt: null, tx: null, after: null,
    catalogs: new Map(), baseCatalogs: new Map(), native: new Map(), replay: new Map(), notices: options.notice ? [H("notice"), 1n, ZeroHash] : [ZeroHash, 0n, ZeroHash],
    selection: null, summary: null, summaryHash: ZeroHash, archiveBytes: null, archiveMetadata: null };
  const now = tag => BigInt(tag * 10);
  const encoded = (f, value) => abi.encodeFunctionResult(f, value);
  const suite = { registry: components[7].address, archive: components[8].address, owners: components.slice(0, 7).map(v => v.address),
    core: components[9].address, mintManager: components[10].address, roleRegistry: components[11].address, metadata: components[12].address,
    primaryResolver: components[13].address, royaltyResolver: components[14].address, primaryRevenueClass: H("PRIMARY_SALE"), validator: components[15].address };
  const provider = {
    async getNetwork() { return { chainId: 1n }; },
    async getBlock(tag) { return { number: tag, hash: H(`block${tag}`), timestamp: Number(now(tag)) }; },
    async getCode(address, tag) { if (state.codeHook) { const r = await state.codeHook(getAddress(address), tag); if (r !== undefined) return r; } return codes.get(getAddress(address)) ?? "0x"; },
    async getTransaction() { return state.tx; },
    async getTransactionReceipt() { return state.receipt; },
    async call(tx) {
      const parsed = abi.parseTransaction({ data: tx.data });
      const f = parsed.fragment, args = parsed.args, method = f.name, to = getAddress(tx.to), tag = tx.blockTag;
      state.calls.push({ ...tx, method, args });
      for (const hook of state.hooks) { const result = await hook({ method, args, to, tag, tx, fragment: f }); if (result !== undefined) return typeof result === "string" ? result : encoded(f, result); }
      const mined = state.receipt && tag >= state.receipt.blockNumber;
      const ownerIndex = components.findIndex(v => v.address === to);
      const catalog = (mined ? state.catalogs : state.baseCatalogs).get(to) ?? [];
      switch (method) {
        case "deploymentChainId": return encoded(f, [1n]);
        case "suiteConfiguration": return encoded(f, [suite]);
        case "configurationHash": return encoded(f, [H("configuration")]);
        case "reads": return encoded(f, [deployment.artist.reads.address]);
        case "core": return encoded(f, [components[9].address]);
        case "coreCodeHash": return encoded(f, [components[9].codeHash]);
        case "mintManager": return encoded(f, [components[10].address]);
        case "artistRegistry": return encoded(f, [components[7].address]);
        case "operationCoordinator": return encoded(f, [deployment.artist.coordinator.address]);
        case "archiveV2": return encoded(f, [components[8].address]);
        case "domainId": return encoded(f, [domains[ownerIndex]]);
        case "getSatellitePointer": {
          const pin = args[0] === H("ARTIST_REGISTRY") ? deployment.artist.registry : deployment.moduleRegistry;
          return encoded(f, [pin.address, pin.codeHash, false, ZeroHash, "0x00000000", ZeroAddress, 0n, ZeroHash, ZeroHash, 1n]);
        }
        case "artistRegistryCutover": return encoded(f, [false, ZeroAddress, 0n]);
        case "binding": case "acceptedBinding": return encoded(f, [binding]);
        case "collectionExists": return encoded(f, [true]);
        case "attributionState": return encoded(f, [2n, binding.generation]);
        case "authorityState": return encoded(f, [signer, authorityClass, authorityStatus, H("registration")]);
        case "currentAuthorityCapabilities": return encoded(f, [{ authorityAddress: signer, authorityClass, status: authorityStatus, effectiveCapabilities: 1n, activationRecordHash: H("activation") }]);
        case "operativeIdentityRecord": return encoded(f, [identityHash]);
        case "artistAuthorizationState": return encoded(f, [{ digestObserved: false, digestRevoked: false, nonceConsumed: false, nonceRevoked: false, nextUnusedNonce: 3n }]);
        case "attestationDigest": return encoded(f, [currentArtistTypedData("artistAttestation", 1n, prepared.request.registry, { ...prepared.message, signedAt: args[1].time }).digest]);
        case "gasParameterInfo": if (args[0] === H("6529STREAM_GGP_ARTIST_SALE_FACTS_READ_GAS")) throw Error("Serving cap unavailable"); return encoded(f, [1000000n, 1000000n, 2n, 1n]);
        case "moduleRecord": return encoded(f, [module]);
        case "streamModuleType": return encoded(f, [module.moduleType]);
        case "streamModuleVersion": return encoded(f, [module.moduleVersion]);
        case "schemaRegistry": return encoded(f, [deployment.schemaRegistry.address]);
        case "schemaRegistryCodeHash": return encoded(f, [deployment.schemaRegistry.codeHash]);
        case "chunkStore": return encoded(f, [deployment.chunkStore.address]);
        case "chunkStoreCodeHash": return encoded(f, [deployment.chunkStore.codeHash]);
        case "attestation": return encoded(f, [generalRecord, generalReceipt]);
        case "recordHashAt": return encoded(f, [generalHash]);
        case "recordSubject": return encoded(f, [subject]);
        case "recordPayload": return encoded(f, [A(128), payload]);
        case "recordSignatureBundle": return encoded(f, [A(129), bundle]);
        case "latestAttestationHashFor": return encoded(f, [generalHash]);
        case "documentFacts": return encoded(f, [definitions.find(v => v.id === args[0]).facts]);
        case "documentChunkHashAt": return encoded(f, [definitions.find(v => v.id === args[0]).facts.contentHash]);
        case "chunk": { const v = definitions.find(v => v.facts.contentHash === args[0]); return encoded(f, [v.pointer, v.facts.totalBytes]); }
        case "readChunk": return encoded(f, [definitions.find(v => v.facts.contentHash === args[0]).bytes]);
        case "ownerStateSnapshotV2": return encoded(f, [mined ? state.after[ownerIndex] ?? snapshots[ownerIndex] : snapshots[ownerIndex]]);
        case "artistNativeReceiptCount": return encoded(f, [mined ? BigInt((state.native.get(to) ?? []).length) : 0n]);
        case "artistNativeReceiptAt": return encoded(f, [state.native.get(to)[Number(args[0])]]);
        case "artistNativeReceiptRevisionAt": return encoded(f, [5n]);
        case "storedPayloadCount": return encoded(f, [BigInt(catalog.length)]);
        case "storedPayloadAt": { const r = catalog[Number(args[0])]; return encoded(f, [r.pointer, r.payloadType, r.payloadHash]); }
        case "artistArchiveMaxEvidenceBytesV2": return encoded(f, [24575n]);
        case "dormancyNotice": return encoded(f, state.notices);
        case "dormancyRecord": return encoded(f, [state.noticeRecord, 2n, state.terminal]);
        case "recordArtistAttestation": return encoded(f, [pure.artistPersonhoodNativeRecordHash(prepared, signer, authorityClass, prepared.request.signedAt || now(tag))]);
        case "attestationRecord": return encoded(f, [state.nativeRecord]);
        case "attestationAuthorityClass": return encoded(f, [authorityClass]);
        case "signatureBundle": return encoded(f, [prepared.request.signature]);
        case "statementBytes": return encoded(f, [prepared.statement]);
        case "personhoodProofSummary": return encoded(f, [state.summary ?? zero(f.outputs[0])]);
        case "personhoodProofSummaryHash": return encoded(f, [state.summaryHash]);
        case "personhoodEvidence": return encoded(f, [state.selection ?? zero(f.outputs[0])]);
        case "personhoodEvidenceStatus": return encoded(f, [state.selection?.nativeRecord.recordHash ?? ZeroHash, state.selection?.status ?? 0n]);
        case "auditPersonhoodEvidence": return encoded(f, [state.summary.documentaryHash, { attestationType: state.summary.attestationType,
          recorder: state.summary.recorder, head: state.generalHash, current: true }]);
        case "artistEvidenceMetadataV2": return encoded(f, state.archiveMetadata);
        case "artistEvidenceBytesV2": return encoded(f, [state.archiveBytes]);
        case "replayCell": { const cell = state.replay.get(args[0]); if (!cell) throw Error(`Unknown replay key ${args[0]}`); return encoded(f, [cell]); }
        default: throw Error(`Unhandled ${method}`);
      }
    },
  };
  return { ...state, state, provider, now };
}

const capture = s => workflow.captureArtistPersonhood(s.provider, s.deployment, s.prepared, { blockTag: 10 });
const run = (s, c, execution = "direct") => workflow.reconcileArtistPersonhoodReceipt(s.provider, c, H("tx"),
  execution === "direct" ? { execution } : { execution: "safe", expectedSafeTxHash: H("safeHash") });

function install(s, c, execution = "direct", block = 12) {
  const st = s.state, d = c.deployment, q = c.prepared.request, owners = d.artist.components;
  const authority = c.authority, effectiveTime = q.signedAt || s.now(block);
  const recordHash = pure.artistPersonhoodNativeRecordHash(c.prepared, authority.authorityAddress, authority.authorityClass, effectiveTime);
  const effectiveDigest = currentArtistTypedData("artistAttestation", 1n, q.registry, { ...c.prepared.message, signedAt: effectiveTime }).digest;
  const proof = c.documentary;
  const summary = { version: 1n, chainId: 1n, nativeRecordHash: recordHash, statementHash: c.prepared.message.statementHash,
    artistId: q.reference.artistId, bindingHash: c.binding.bindingHash, generation: c.binding.generation, collectionId: q.collectionId,
    identityRecordHash: q.reference.operativeIdentityRecordHash, evidenceReference: q.reference, originalRegistryCodeHash: d.artist.registry.codeHash,
    core: q.core, coreCodeHash: owners[9].codeHash, moduleRegistry: d.moduleRegistry.address, moduleRegistryCodeHash: d.moduleRegistry.codeHash,
    schemaRegistry: d.schemaRegistry.address, schemaRegistryCodeHash: d.schemaRegistry.codeHash, chunkStore: d.chunkStore.address,
    chunkStoreCodeHash: d.chunkStore.codeHash, definitionFactsHashes: proof.definitionFactsHashes, notarizationCollectionId: proof.record.collectionId,
    attestationType: proof.record.attestationType, subjectId: proof.record.subjectId, recorder: proof.receipt.recorder,
    documentaryHash: proof.documentaryHash, moduleIdentityHash: proof.moduleIdentityHash, carriers: proof.carriers, carrierCodeHashes: proof.carrierCodeHashes };
  st.summary = summary; st.summaryHash = pure.artistPersonhoodSummaryHash(summary);
  st.nativeRecord = { recordHash, subjectStateHash: q.reference.operativeIdentityRecordHash, schemaId: pure.PERSONHOOD_EVIDENCE_SCHEMA,
    statementHash: c.prepared.message.statementHash, generation: c.binding.generation, signedAt: effectiveTime, signer: authority.authorityAddress };
  st.selection = { nativeRecord: st.nativeRecord, sourceRegistry: q.registry, evidenceReference: q.reference, notarizationType: proof.record.attestationType,
    recorder: proof.receipt.recorder, notarizationHead: q.reference.notarizationRecordHash, identityCurrent: true, notarizationCurrent: true, status: 2n };
  const zeroSnapshot = { domainId: ZeroHash, revision: 0n, stateRoot: ZeroHash, recordChainTip: ZeroHash };
  const before = Array.from({ length: 7 }, (_, i) => c.owners.find(v => v.ownerIndex === BigInt(i))?.snapshot ?? zeroSnapshot);
  const after = before.map((v, i) => [2, 4].includes(i) ? { ...v, revision: v.revision + 1n, stateRoot: H(`after${i}`), recordChainTip: i === 2 ? v.recordChainTip : H("aftertip") } : v);
  st.after = after;
  const terms = abi.decodeFunctionData("recordArtistAttestation", c.prepared.call.data)[0];
  const auth = [q.nonce, q.signedAt, q.signature];
  const innerTypes = [bindingType, termsType, authType, "bytes", proofType];
  const inner = [c.binding, terms, auth, c.prepared.statement, [authority.authorityAddress, effectiveDigest, c.direct]];
  if (q.signedAt !== effectiveTime) { innerTypes.push(authType); inner.push([q.nonce, effectiveTime, q.signature]); }
  const payload = coder.encode(["bytes", authorityType], [coder.encode(["bytes", "bytes32"],
    [coder.encode(innerTypes, inner), q.reference.operativeIdentityRecordHash]), authority]);
  st.archiveBytes = coder.encode(["uint16", "bytes32", "uint16", "address", "bytes32", `${snapshotType}[7]`, `${snapshotType}[7]`, "bytes"],
    [1n, c.configurationHash, 24n, q.caller, recordHash, before, after, payload]);
  const evidenceId = hash(["bytes32", "uint256", "address", "address", "uint16", "address", "bytes32"],
    [H("6529STREAM_ARTIST_ONBOARDING_OPERATION_EVIDENCE_V1"), 1n, q.registry, d.artist.coordinator.address, 24n, q.caller, recordHash]);
  st.archiveMetadata = [keccak256(st.archiveBytes), A(180), BigInt((st.archiveBytes.length - 2) / 2), BigInt(block)];
  st.codes.set(A(180), `0x00${st.archiveBytes.slice(2)}`);
  const logs = [];
  const emit = (address, name, args, iface = abi) => {
    const event = iface.encodeEventLog(iface.getEvent(name), args);
    logs.push({ address, ...event, index: logs.length, blockNumber: block, blockHash: H(`block${block}`), transactionHash: H("tx"), removed: false });
  };
  st.catalogs = new Map([...st.baseCatalogs].map(([host, rows]) => [host, structuredClone(rows)]));
  const adds = [];
  const payloadStore = (host, kind, bytes, pointer) => {
    const rows = st.catalogs.get(host) ?? [];
    if (rows.some(v => v.payloadType === kind && v.payloadHash === keccak256(bytes))) return;
    st.codes.set(pointer, `0x00${bytes.slice(2)}`);
    const row = { pointer, payloadType: kind, payloadHash: keccak256(bytes) };
    emit(host, "ArtistStoredPayload", [1n, BigInt(rows.length), kind, row.payloadHash, pointer]);
    rows.push(row); st.catalogs.set(host, rows);
    if (host !== owners[8].address) adds.push({ kind, bytes, pointer });
  };
  const key = (surface, scope) => hash(["bytes32", "uint256", "address", "address", "address", "address", "bytes32", "bytes32", "bytes32"],
    [H("6529STREAM_ARTIST_OWNER_REPLAY_KEY_V2"), 1n, q.registry, d.artist.coordinator.address, owners[8].address,
      owners[2].address, domains[2], H(`identity_authority.replay.${surface}`), scope]);
  const consume = (surface, scope, commitment) => st.replay.set(key(surface, scope), { commitment, touchedRevision: 5n, kind: 1n, status: 2n });
  payloadStore(owners[2].address, H("ARTIST_SIGNATURE_BUNDLE"), q.signature, A(181));
  st.native.set(owners[2].address, []);
  if (c.notice.phase === 1n && authority.authorityClass === 1n) {
    const terminal = { ...zero(abi.getFunction("dormancyRecord").outputs[2]), noticeHash: c.notice.recordHash,
      actor: authority.authorityAddress, authorityClass: 1n, observedAt: s.now(block) };
    terminal.recordHash = hash(["bytes32", "uint256", "address", "address", terminalType, "uint256"],
      [H("6529STREAM_ARTIST_DORMANCY_CANCELLATION_V1"), 1n, q.registry, owners[2].address, terminal, 1n]);
    st.terminal = terminal;
    st.noticeRecord = { ...zero(abi.getFunction("dormancyRecord").outputs[0]), recordHash: c.notice.recordHash };
    emit(owners[2].address, "ArtistDormancyCancelled", [1n, q.reference.artistId, c.notice.recordHash, authority.authorityAddress, 1n, terminal.recordHash]);
    emit(owners[2].address, "ArtistDormancyCancellationContext", [1n, q.reference.artistId, terminal.recordHash,
      [1n, q.registry, owners[2].address, authority.authorityAddress, 1n], terminal, 1n]);
    st.native.set(owners[2].address, [{ operation: 42n, artistId: q.reference.artistId, collectionId: 0n, recordHash: terminal.recordHash }]);
    consume("dormancy_cancellation_key", c.notice.recordHash, terminal.recordHash);
  }
  payloadStore(owners[4].address, H("ARTIST_PUBLICATION_STATEMENT"), c.prepared.statement, A(182));
  emit(owners[4].address, "ArtistAttestationRecorded", [1n, q.collectionId, 10n, authority.authorityAddress, q.reference.artistId,
    q.reference.operativeIdentityRecordHash, pure.PERSONHOOD_EVIDENCE_SCHEMA, c.prepared.message.statementHash,
    c.prepared.message.statementURIHash, authority.authorityClass, q.nonce, effectiveTime, recordHash]);
  payloadStore(owners[4].address, pure.PERSONHOOD_PAYLOAD_TYPE,
    coder.encode(["bytes32", pure.PERSONHOOD_SUMMARY_TUPLE], [pure.PERSONHOOD_SUMMARY_TAG, summary]), A(183));
  emit(owners[4].address, "ArtistPersonhoodProofRetained", [1n, recordHash, q.registry, st.summaryHash, summary]);
  emit(owners[8].address, "ArtistArchiveEvidenceAppendedV2", [evidenceId, 1n, ...st.archiveMetadata.slice(0, 3)]);
  for (const item of adds) payloadStore(owners[8].address, item.kind, item.bytes, item.pointer);
  st.native.set(owners[4].address, [{ operation: 24n, artistId: q.reference.artistId, collectionId: q.collectionId, recordHash }]);
  consume("nonce_allocator", hash(["bytes32", "uint256"], [q.reference.artistId, q.nonce]), effectiveDigest);
  consume("attestation_key", hash(["bytes32"], [recordHash]), recordHash);
  consume("authorization_consumed_digest", hash(["bytes32", "bytes32"], [q.reference.artistId, effectiveDigest]), effectiveDigest);
  st.tx = { hash: H("tx"), chainId: 1n, from: q.caller, to: q.registry, data: c.prepared.call.data, value: 0n,
    blockNumber: block, blockHash: H(`block${block}`) };
  if (execution !== "direct") {
    st.tx.from = A(99); st.tx.to = q.caller;
    st.tx.data = safe.encodeFunctionData("execTransaction", [q.registry, 0n, c.prepared.call.data, 0n, 0n, 0n, 0n, ZeroAddress, ZeroAddress, "0x"]);
    emit(q.caller, "ExecutionSuccess", [H("safeHash"), 0n], execution === "indexed" ? safe1 : safe0);
  }
  st.receipt = { ...st.tx, status: 1, logs };
  return { recordHash, summary, before, after, effectiveDigest, evidenceId, logs, emit, key };
}

function renumber(logs) { logs.forEach((v, i) => { v.index = i; }); }

test("capture authenticates original General receipt, all subjects and exact four retained definitions", async () => {
  for (const subjectKind of [0n, 1n, 2n]) {
    const s = setup({ subjectKind });
    const c = await capture(s);
    assert.equal(c.documentary.definitions.length, 4);
    assert.equal(c.documentary.carriers.length, 6);
    assert.equal(c.direct, true);
    assert.equal(c.effectiveTime, 100n);
    assert.equal(c.binding.artistAddress, A(90));
    assert.equal(c.authority.authorityAddress, A(60));
    const result = await workflow.simulateArtistPersonhood(s.provider, c, { blockTag: 11, gasLimit: 10000000n });
    assert.equal(result.recordHash, pure.artistPersonhoodNativeRecordHash(c.prepared, A(60), 1n, 110n));
    assert.equal(s.state.calls.findLast(v => v.method === "recordArtistAttestation").from, c.prepared.request.caller);
    assert.equal(s.state.calls.some(v => v.method === "gasParameterInfo" && v.args[0] === H("6529STREAM_GGP_ARTIST_SALE_FACTS_READ_GAS")), false);
  }
});

test("principal classes3/4 require CAP_ATTEST; literal relay including empty1271 stays signed", async () => {
  for (const authorityClass of [3n, 4n]) {
    const s = setup({ authorityClass });
    assert.equal((await capture(s)).authority.authorityClass, authorityClass);
    s.state.hooks.push(({ method }) => method === "currentAuthorityCapabilities" ? [{ authorityAddress: A(60), authorityClass, status: 3n, effectiveCapabilities: 0n, activationRecordHash: H("activation") }] : undefined);
    await assert.rejects(capture(s), /CAP_ATTEST/);
  }
  for (const signature of ["0x1234", "0x"]) {
    const s = setup({ relay: true, signature, contractSigner: true });
    const c = await capture(s);
    assert.equal(c.direct, false); assert.equal(c.effectiveTime, 95n);
    await workflow.simulateArtistPersonhood(s.provider, c, { blockTag: 11, gasLimit: 1000000n });
  }
  await assert.rejects(capture(setup({ relay: true, signature: "0x" })), /contract authority/);
});

test("source pins, current selection, nonce/time and exact General head fail closed", async () => {
  for (const [method, answer, pattern] of [
    ["artistRegistryCutover", [true, A(80), 1n], /not current/],
    ["operativeIdentityRecord", [H("later")], /Operative/],
    ["latestAttestationHashFor", [H("later head")], /stale/],
    ["artistAuthorizationState", [{ digestObserved: false, digestRevoked: false, nonceConsumed: true, nonceRevoked: false, nextUnusedNonce: 3n }], /replay/],
    ["collectionExists", [false], /collection/],
  ]) {
    const s = setup(); s.state.hooks.push(v => v.method === method ? answer : undefined);
    await assert.rejects(capture(s), pattern);
  }
  const s = setup(); s.state.module.status = 2n;
  await assert.rejects(capture(s), /ACTIVE/);
  const t = setup(); t.state.codeHook = (address) => address === t.deployment.general.address ? "0x6002" : undefined;
  await assert.rejects(capture(t), /runtime/);
});

test("original receipt, signature words, payload carriers and definition bytes are independently bound", async () => {
  const cases = [
    s => { s.state.generalReceipt.identityRegistry = A(99); },
    s => { s.state.generalReceipt.authorizationDigest = H("changed"); },
    s => { s.state.generalRecord.artistAuthorizationRecordHash = H("native claim"); },
    s => { s.state.hooks.push(v => v.method === "recordHashAt" ? [H("wrong")] : undefined); },
    s => { s.state.codes.set(A(129), "0x00"); },
    s => { s.state.definitions[2].facts.supersedesId = H("old"); },
    s => { s.state.hooks.push(v => v.method === "readChunk" ? ["0x12"] : undefined); },
  ];
  for (const change of cases) { const s = setup(); change(s); await assert.rejects(capture(s)); }
});

test("bounded currentness serves NONE and stale/unresolved heads without full documentary audit", async () => {
  const s = setup(), c = await capture(s); install(s, c);
  const d = { chainId: 1n, attribution: s.deployment.artist.components[4] };
  s.state.hooks.push(({ method }) => { if (["attestation", "recordPayload", "recordSignatureBundle"].includes(method)) throw Error("No full replay allowed"); });
  for (const status of [2n, 3n, 4n]) {
    s.state.selection.status = status;
    s.state.selection.identityCurrent = status === 2n;
    s.state.selection.notarizationCurrent = status === 2n;
    const r = await workflow.inspectArtistPersonhood(s.provider, d, { method: "personhoodEvidenceStatus", collectionId: 8n, artistId: c.authority.artistId }, { blockTag: 13, gasLimit: 2000000n });
    assert.equal(r.selection.status, status); assert.equal(r.audit, null);
  }
  s.state.selection = null;
  assert.equal((await workflow.inspectArtistPersonhood(s.provider, d, { method: "personhoodEvidence", collectionId: 0n, artistId: ZeroHash }, { blockTag: 13, gasLimit: 2000000n })).selection.status, 0n);
});

test("immutable summary/hash survives lost dependencies while full audit remains explicit", async () => {
  const s = setup(), c = await capture(s); const installed = install(s, c);
  const d = { chainId: 1n, attribution: s.deployment.artist.components[4] };
  for (const method of ["personhoodProofSummary", "personhoodProofSummaryHash", "auditPersonhoodEvidence"]) {
    const r = await workflow.inspectArtistPersonhood(s.provider, d, { method, nativeRecordHash: installed.recordHash }, { blockTag: 13, gasLimit: 2000000n });
    assert.equal(r.summaryHash, s.state.summaryHash);
    assert.equal(Boolean(r.audit), method === "auditPersonhoodEvidence");
  }
  s.state.codeHook = address => address === d.attribution.address ? undefined : "0x";
  s.state.hooks.push(({ method }) => { if (method === "auditPersonhoodEvidence") throw Error("Original dependency unavailable"); });
  assert.equal((await workflow.inspectArtistPersonhood(s.provider, d, { method: "personhoodProofSummary", nativeRecordHash: installed.recordHash }, { blockTag: 13, gasLimit: 2000000n })).summary.nativeRecordHash, installed.recordHash);
  await assert.rejects(workflow.inspectArtistPersonhood(s.provider, d, { method: "auditPersonhoodEvidence", nativeRecordHash: installed.recordHash }, { blockTag: 13, gasLimit: 2000000n }), /unavailable/);
});

test("original principal Archive plus summary and both catalogs reconcile direct and both Safe layouts", async () => {
  for (const execution of ["direct", "legacy", "indexed"]) for (const authorityClass of [1n, 3n, 4n]) {
    const s = setup({ authorityClass }), c = await capture(s), installed = install(s, c, execution);
    const r = await run(s, c, execution);
    assert.equal(r.recordHash, installed.recordHash);
    assert.equal(r.effectiveTime, 120n); assert.equal(r.currentnessClaimed, false);
    assert.equal(r.summaryHash, s.state.summaryHash);
    assert.equal(r.events.filter(v => v.event === "ArtistStoredPayload").length, 6);
  }
});

test("phase1 activity retains genuine42 with exact original cancellation_key then native24", async () => {
  const s = setup({ notice: true }), c = await capture(s); install(s, c, "indexed");
  const result = await run(s, c, "indexed");
  assert.equal(result.events.filter(v => v.event === "ArtistDormancyCancelled").length, 1);
  assert.equal(s.state.native.get(s.deployment.artist.components[2].address)[0].operation, 42n);
  const key = [...s.state.replay].find(([, value]) => value.commitment === s.state.terminal.recordHash)[0];
  s.state.replay.delete(key);
  await assert.rejects(run(s, c, "indexed"), /Unknown replay key/);
});

test("durable receipt ignores later current head/identity/general changes and relayed time remains original", async () => {
  const s = setup({ relay: true, signature: "0x", contractSigner: true }), c = await capture(s);
  install(s, c);
  s.state.hooks.push(({ method, tag }) => {
    if (tag >= 12 && ["operativeIdentityRecord", "authorityState", "latestAttestationHashFor", "attestation", "personhoodEvidence"].includes(method)) throw Error("No mutable currentness reread");
  });
  const result = await run(s, c);
  assert.equal(result.effectiveTime, 95n);
});

test("same payloads deduplicate but both summary catalog rows and mandatory summary event remain required", async () => {
  const s = setup();
  const signature = { pointer: A(181), payloadType: H("ARTIST_SIGNATURE_BUNDLE"), payloadHash: keccak256("0x") };
  const statement = { pointer: A(182), payloadType: H("ARTIST_PUBLICATION_STATEMENT"), payloadHash: keccak256(s.prepared.statement) };
  s.state.codes.set(A(181), "0x00"); s.state.codes.set(A(182), `0x00${s.prepared.statement.slice(2)}`);
  s.state.baseCatalogs.set(s.deployment.artist.components[2].address, [signature]);
  s.state.baseCatalogs.set(s.deployment.artist.components[4].address, [statement]);
  s.state.baseCatalogs.set(s.deployment.artist.components[8].address, [signature, statement]);
  const c = await capture(s); install(s, c);
  assert.equal((await run(s, c)).events.filter(v => v.event === "ArtistStoredPayload").length, 2);
  s.state.receipt.logs = s.state.receipt.logs.filter(v => v.topics[0] !== abi.getEvent("ArtistStoredPayload").topicHash);
  renumber(s.state.receipt.logs);
  await assert.rejects(run(s, c), /payload additions/);
});

test("nested payload, mask, immutable summary and native receipt mutations cannot pass", async () => {
  const changes = [
    s => { s.state.summary.bindingHash = H("forged"); s.state.summaryHash = pure.artistPersonhoodSummaryHash(s.state.summary); },
    s => { s.state.nativeRecord.generation = 9n; },
    s => { s.state.after[2].recordChainTip = H("extra semantic receipt"); },
    s => { s.state.native.get(s.deployment.artist.components[4].address)[0].operation = 23n; },
    s => { s.state.receipt.logs[0].removed = true; },
    s => { s.state.receipt.logs = s.state.receipt.logs.filter(v => v.topics[0] !== abi.getEvent("ArtistPersonhoodProofRetained").topicHash); renumber(s.state.receipt.logs); },
  ];
  for (const change of changes) { const s = setup(), c = await capture(s); install(s, c); change(s); await assert.rejects(run(s, c)); }
});

test("Safe exact target/data/value/CALL, independent hash, failure and event ordering reject substitutions", async () => {
  const mutations = [
    s => { s.state.tx.value = 1n; },
    s => { const v = Array.from(safe.decodeFunctionData("execTransaction", s.state.tx.data)); v[3] = 1n; s.state.tx.data = safe.encodeFunctionData("execTransaction", v); },
    s => { const v = Array.from(safe.decodeFunctionData("execTransaction", s.state.tx.data)); v[1] = 1n; s.state.tx.data = safe.encodeFunctionData("execTransaction", v); },
    s => { const v = Array.from(safe.decodeFunctionData("execTransaction", s.state.tx.data)); v[0] = A(77); s.state.tx.data = safe.encodeFunctionData("execTransaction", v); },
    s => { const last = s.state.receipt.logs.at(-1); Object.assign(last, safe0.encodeEventLog(safe0.getEvent("ExecutionSuccess"), [H("wrong"), 0n])); },
    s => { const last = s.state.receipt.logs.at(-1); Object.assign(last, safe0.encodeEventLog(safe0.getEvent("ExecutionFailure"), [H("safeHash"), 0n])); },
    s => { s.state.receipt.logs.unshift(s.state.receipt.logs.pop()); renumber(s.state.receipt.logs); },
  ];
  for (const mutate of mutations) { const s = setup(), c = await capture(s); install(s, c, "legacy"); mutate(s); await assert.rejects(run(s, c, "legacy")); }
});

test("copied receipt logs resist provider mutation after awaited readback", async () => {
  const s = setup(), c = await capture(s); install(s, c, "indexed");
  s.state.hooks.push(({ tag }) => {
    if (tag === 11 && s.state.receipt.logs.at(-1).topics.length === 2) {
      Object.assign(s.state.receipt.logs.at(-1), safe1.encodeEventLog(safe1.getEvent("ExecutionSuccess"), [H("provider mutated"), 0n]));
    }
  });
  assert.equal((await run(s, c, "indexed")).recordHash, s.state.summary.nativeRecordHash);
});

test("mutation before await, canonical RPC bytes, reorg and explicit call limits fail closed", async () => {
  const s = setup(), prepared = structuredClone(s.prepared);
  const originalNetwork = s.provider.getNetwork;
  s.provider.getNetwork = async () => { prepared.request.caller = A(77); return originalNetwork(); };
  assert.equal((await workflow.captureArtistPersonhood(s.provider, s.deployment, prepared, { blockTag: 10 })).prepared.request.caller, A(60));
  const t = setup(); t.state.hooks.push(({ method, fragment }) => method === "moduleRecord" ? abi.encodeFunctionResult(fragment, [t.module]) + "00".repeat(32) : undefined);
  await assert.rejects(capture(t), /Noncanonical/);
  const u = setup(), c = await capture(u);
  await assert.rejects(workflow.simulateArtistPersonhood(u.provider, c, { blockTag: 9, gasLimit: 1000000n }), /bounds/);
  await assert.rejects(workflow.simulateArtistPersonhood(u.provider, c, { blockTag: 11, gasLimit: 0n }), /bounds/);
  const v = setup(); let reads = 0;
  v.provider.getBlock = async tag => ({ number: tag, timestamp: 100, hash: H(++reads === 1 ? "block10" : "reorg") });
  await assert.rejects(capture(v), /Block changed/);
});

test("generic Safe ordinary CALL plan retains original principal calldata and unsigned zero value", async () => {
  const s = setup();
  const plan = createSafeCallPlan(1n, "Record personhood evidence", [{ safe: s.prepared.request.caller,
    intent: "Record the original Artist personhood statement", call: s.prepared.call, abi: fixture.abis.registry }]);
  verifySafeCallPlan(plan, [fixture.abis.registry]);
  assert.equal(plan.steps[0].transaction.operation, 0);
  assert.equal(plan.steps[0].transaction.value, "0");
  assert.equal(plan.steps[0].transaction.data, s.prepared.call.data);
});

test("canonical Archive payload and owner-mask substitutions fail with updated carrier and event hashes", async () => {
  for (const mutation of ["payload", "effective-auth", "mask"]) {
    const s = setup(), c = await capture(s), installed = install(s, c);
    const types = ["uint16", "bytes32", "uint16", "address", "bytes32", `${snapshotType}[7]`, `${snapshotType}[7]`, "bytes"];
    const decoded = coder.decode(types, s.state.archiveBytes);
    const fields = Array.from(decoded);
    if (mutation !== "mask") {
      const [inner, authority] = coder.decode(["bytes", authorityType], fields[7]);
      const [base, operativeIdentity] = coder.decode(["bytes", "bytes32"], inner);
      let nextBase = base;
      if (mutation === "effective-auth") {
        const baseTypes = [bindingType, termsType, authType, "bytes", proofType, authType];
        const baseFields = Array.from(coder.decode(baseTypes, base));
        // The submitted direct-zero authorization must retain its separate mined-time copy.
        nextBase = coder.encode(baseTypes.slice(0, 5), baseFields.slice(0, 5));
      }
      fields[7] = coder.encode(["bytes", authorityType], [coder.encode(["bytes", "bytes32"],
        [nextBase, mutation === "payload" ? H("substituted identity") : operativeIdentity]), authority]);
    } else {
      fields[5] = Array.from(decoded[5], value => Array.from(value));
      fields[6] = Array.from(decoded[6], value => Array.from(value));
      fields[5][5] = [domains[5], 4n, H("payout before"), H("payout tip")];
      fields[6][5] = fields[5][5];
    }
    s.state.archiveBytes = coder.encode(types, fields);
    s.state.archiveMetadata = [keccak256(s.state.archiveBytes), A(180), BigInt((s.state.archiveBytes.length - 2) / 2), 12n];
    s.state.codes.set(A(180), `0x00${s.state.archiveBytes.slice(2)}`);
    const event = s.state.receipt.logs.find(v => v.topics[0] === abi.getEvent("ArtistArchiveEvidenceAppendedV2").topicHash);
    Object.assign(event, abi.encodeEventLog(abi.getEvent("ArtistArchiveEvidenceAppendedV2"), [installed.evidenceId, 1n, ...s.state.archiveMetadata.slice(0, 3)]));
    await assert.rejects(run(s, c), mutation !== "mask" ? /principal Archive payload/ : /Unexpected Archive owner/);
  }
});

test("prior-block facts are explicit and original simulation revert propagates", async () => {
  const s = setup(), c = await capture(s); install(s, c);
  s.state.hooks.push(({ method, tag }) => method === "ownerStateSnapshotV2" && tag === 11
    ? [{ ...s.snapshots[0], domainId: domains[0], revision: 5n }] : undefined);
  await assert.rejects(run(s, c), /snapshot|Prior-block/);
  const t = setup(), tc = await capture(t);
  t.state.hooks.push(({ method }) => { if (method === "recordArtistAttestation") throw Error("Original validator rejected principal proof"); });
  await assert.rejects(workflow.simulateArtistPersonhood(t.provider, tc, { blockTag: 11, gasLimit: 1000000n }), /Original validator rejected/);
});

test("phase2 does not cancel again and retained summary STOP carrier drift rejects", async () => {
  const s = setup(); s.state.notices = [H("old notice"), 2n, H("old terminal")];
  const c = await capture(s); install(s, c);
  const receipt = await run(s, c);
  assert.equal(receipt.events.some(v => v.event === "ArtistDormancyCancelled"), false);
  s.state.codes.set(A(183), "0x0012");
  await assert.rejects(run(s, c), /STOP carrier/);
});
