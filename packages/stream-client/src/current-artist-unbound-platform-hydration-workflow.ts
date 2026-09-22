/** UNBOUND_PLATFORM operation60 adapter. Original Registry simulation remains semantic admission. */
import { Interface, TypedDataEncoder, id, keccak256 } from "ethers";
import type { Address, Hex } from "./generated/contracts.js";
import type { ArtistHydrationSuite, ArtistHydrationSnapshot } from "./current-artist-authority-hydration.js";
import { ARTIST_HYDRATION_CHECKPOINT_TUPLE, ARTIST_HYDRATION_SUITE_TUPLE } from "./current-artist-authority-hydration.js";
import * as multiple from "./current-artist-unbound-platform-hydration.js";
import * as io from "./current-scoped-policy-inventory-archive-workflow-internal.js";
import {
  createRecoveredHydrationWorkflow,
  type ArtistRecoveredHydrationCapture,
  type ArtistRecoveredHydrationSimulation,
  type ArtistRecoveredHydrationReader,
  type ArtistRecoveredHydrationReceiptReader,
  type ArtistRecoveredHydrationDeployment,
} from "./internal/artist-recovered-hydration-workflow.js";

export type {
  ArtistRecoveredHydrationCodePin as ArtistUnboundPlatformHydrationCodePin,
  ArtistRecoveredHydrationSuitePins as ArtistUnboundPlatformHydrationSuitePins,
  ArtistRecoveredHydrationDeployment as ArtistUnboundPlatformHydrationDeployment,
  ArtistRecoveredHydrationReader as ArtistUnboundPlatformHydrationReader,
  ArtistRecoveredHydrationReceiptReader as ArtistUnboundPlatformHydrationReceiptReader,
  ArtistRecoveredHydrationObservation as ArtistUnboundPlatformHydrationObservation,
  ArtistRecoveredHydrationOwnerObservation as ArtistUnboundPlatformHydrationOwnerObservation,
} from "./internal/artist-recovered-hydration-workflow.js";
export type ArtistUnboundPlatformHydrationCapture = ArtistRecoveredHydrationCapture<multiple.ArtistUnboundPlatformHydrationCall>;
export type ArtistUnboundPlatformHydrationSimulation = ArtistRecoveredHydrationSimulation<multiple.ArtistUnboundPlatformHydrationCall>;
export type ArtistUnboundPlatformHydrationReceiptOptions = Readonly<
  { execution: "direct" } | { execution: "safe"; expectedSafeTxHash: Hex; nonce: bigint; safeCodeHash: Hex }
>;
const abi = new Interface([
  "function nextRegistrationNonce() view returns(uint256)",
  `function authorityCheckpoint() view returns(${ARTIST_HYDRATION_CHECKPOINT_TUPLE})`,
  "function authorityNonceIndexAt(uint256) view returns((uint8 kind,bytes32 key,uint256 prefixCount))",
]);

const BINDING = "tuple(bytes32 artistId,address artistAddress,bytes32 identityRecordHash,bytes32 bindingHash,uint64 generation,uint8 consentMode,uint8 saleConsentScope,uint8 registryImmutabilityElection,address proposer,bool accepted)";
const BINDING_TERMS = "tuple(bytes32 collaboratorSetHash,bytes32 capabilityPolicySetHash,uint8 mode,uint32 threshold,uint32 count)";
const BINDING_TERMINAL = "tuple(uint8 kind,bytes32 reasonHash,bytes32 recordHash)";
const PLATFORM_STATE = "tuple(tuple(bytes32 recordHash,bytes32 statementHash,address actor,uint64 declaredAt) declaration,uint8 contestState,bytes32 contestClaim,bytes32 contestRecord,uint256 claimCount,bytes32 latestClaim,tuple(uint256 collectionId,address proposedArtist,bytes32 claimRecordHash,bytes32 sustainedContestRecordHash,bytes32 evidenceHash,bytes32 reasonHash,bytes32 approvalActionId,uint64 approvedAt,uint64 correctiveGeneration,bool accepted,bytes32 recordHash) correction)";
const PLATFORM_CLAIM = "tuple(uint256 collectionId,address claimant,address proposedArtist,bytes32 evidenceHash,bytes32 reasonHash,uint64 filedAt,bytes32 recordHash)";
const PLATFORM_CONTEST = "tuple(uint256 collectionId,address adjudicatedArtist,uint8 state,bytes32 claimRecordHash,bytes32 evidenceHash,bytes32 reasonHash,bytes32 actionId,bytes32 previousRecordHash,uint64 changedAt,bytes32 recordHash)";
const ATTRIBUTION_CLAIM = "tuple(bytes32 recordHash,uint256 collectionId,address claimant,bytes32 evidenceHash,bytes32 reasonHash,string reasonURI,uint64 filedAt,address proposedArtist,bytes32 previousRecordHash,uint256 index)";
const PLATFORM_STATUS = "tuple(bytes32 originalCorrectionRecord,bytes32 latestLineageRecord,uint64 generation,uint64 count,bool effectiveAccepted,bytes32 latestAcceptanceRecord)";
const collectionAbi = new Interface([
  `function binding(uint256 collectionId) view returns(${BINDING})`,
  `function bindingAt(uint256 collectionId,uint64 generation) view returns(${BINDING})`,
  `function bindingTerms(uint256 collectionId,uint64 generation) view returns(${BINDING_TERMS})`,
  `function bindingTermination(uint256 collectionId,uint64 generation) view returns(${BINDING_TERMINAL})`,
  "function acceptedAt(bytes32 bindingHash) view returns(uint64)",
  "function acceptanceRecord(bytes32 bindingHash) view returns(bytes32)",
  "function attributionState(uint256 collectionId) view returns(uint8 state,uint64 generation)",
  `function platformWorksState(uint256 collectionId) view returns(${PLATFORM_STATE})`,
  `function platformWorksClaimRecord(bytes32 recordHash) view returns(${PLATFORM_CLAIM})`,
  `function platformWorksContestRecord(bytes32 recordHash) view returns(${PLATFORM_CONTEST})`,
  `function attributionClaimRecord(bytes32 recordHash) view returns(${ATTRIBUTION_CLAIM})`,
  `function platformCorrectionStatus(uint256 collectionId) view returns(${PLATFORM_STATUS})`,
  "function attributionClaims(uint256 collectionId) view returns(uint256,bytes32)",
  "function staticAttributionClaims(uint256 collectionId) view returns(uint256,bytes32)",
  "function policyRecord(uint256 collectionId,bytes32 phaseId,bytes32 policyHash) view returns(bytes32)",
  "function recordDelegation(bytes32 recordHash) view returns(bytes32)",
]);
const clockAbi = new Interface([
  `function authorityHydrationSuite() view returns(${ARTIST_HYDRATION_SUITE_TUPLE})`,
  "function configurationHash() view returns(bytes32)",
  "function storedPayloadCount() view returns(uint256)",
  "function storedPayloadAt(uint256 index) view returns(address pointer,bytes32 kind,bytes32 hash)",
  "function artistRegistry() view returns(address)",
  "function operationCoordinator() view returns(address)",
  "function artistArchiveMarkerV2() pure returns(bytes32)",
  "function artistArchiveSchemaV2() pure returns(uint16)",
  "function artistArchiveMaxEvidenceBytesV2() pure returns(uint256)",
  "function artistArchiveBindingHashV2() view returns(bytes32)",
  "function artistEvidenceMetadataV2(bytes32 evidenceId,uint64 evidenceVersion) view returns(bytes32 contentHash,address pointer,uint32 payloadSize,uint64 appendedAtBlock)",
  "function artistEvidenceBytesV2(bytes32 evidenceId,uint64 evidenceVersion) view returns(bytes evidence)",
]);
// Original own Archive methods, including append only as an interface-ID witness.
const archiveInterfaceId = (() => {
  const names = ["artistArchiveMarkerV2", "artistArchiveSchemaV2", "artistArchiveMaxEvidenceBytesV2", "artistRegistry", "operationCoordinator", "artistArchiveBindingHashV2", "artistEvidenceMetadataV2", "artistEvidenceBytesV2"];
  let result = BigInt(id("appendArtistEvidenceV2(bytes32,uint64,bytes)").slice(0, 10));
  for (const name of names) result ^= BigInt(clockAbi.getFunction(name)!.selector);
  return `0x${result.toString(16).padStart(8, "0")}` as Hex;
})();
const clockHash = (types: readonly string[], values: readonly unknown[]) => keccak256(io.coder.encode(types, values)) as Hex;
function emptyTuple<T>(tuple: string): T {
  return io.decode([tuple], io.coder.encode([tuple], io.coder.getDefaultValue([tuple])) as Hex)[0] as T;
}
function ownerState(certificate: multiple.ArtistUnboundPlatformHydrationPrepared, index: 0 | 2 | 3 | 4 | 6) {
  const { payload } = multiple.decodeArtistUnboundPlatformHydrationOwnerPayload(certificate.data[index].typedState, index);
  return { payload, state: multiple.decodeArtistUnboundPlatformHydrationState(payload.semanticState, index, payload.provenance) };
}

/** Immutable Platform records are separate from mutable current display/state heads. */
async function collectionRows(reader: ArtistRecoveredHydrationReader, suite: ArtistHydrationSuite,
  certificate: multiple.ArtistUnboundPlatformHydrationPrepared, tag: number,
  current: Readonly<{ binding: boolean; attribution: boolean; policy: boolean }>) {
  const binding = ownerState(certificate, 0).state, acceptance = ownerState(certificate, 3).state;
  const attribution = ownerState(certificate, 4).state, policy = ownerState(certificate, 6).state;
  for (let index = 0; index < attribution.collections.length; index++) {
    const q = attribution.collections[index]!, cid = q.collectionId;
    if (q.artistId === io.ZERO) {
      const platform = multiple.decodeArtistUnboundPlatformHydrationPlatform(attribution.rows[index]!);
      if (current.binding) io.equal(await io.read(reader, suite.owners[0], collectionAbi, "binding", [cid], tag), emptyTuple(BINDING), "Unbound original Binding must remain empty");
      io.equal(await io.read(reader, suite.owners[3], collectionAbi, "acceptedAt", [io.ZERO], tag), 0n, "Unbound collection must not invent acceptance time");
      io.equal(await io.read(reader, suite.owners[3], collectionAbi, "acceptanceRecord", [io.ZERO], tag), io.ZERO, "Unbound collection must not invent acceptance record");
      const actual = await io.read<multiple.ArtistUnboundPlatformHydrationPlatform["state"]>(reader, suite.owners[4], collectionAbi, "platformWorksState", [cid], tag);
      io.equal(actual.declaration, platform.state.declaration, "Original Platform declaration differs");
      if (platform.state.correction.recordHash !== io.ZERO) {
        // Original approval is immutable. Later consumption changes only these
        // two lifecycle fields; a later first approval is allowed when none was imported.
        io.equal({ ...actual.correction, correctiveGeneration: platform.state.correction.correctiveGeneration, accepted: platform.state.correction.accepted },
          platform.state.correction, "Original retained correction approval differs");
      }
      if (current.attribution) {
        io.equal(actual, platform.state, "Complete original Platform state differs");
        io.equal(await io.rpc(reader, suite.owners[4], collectionAbi, "attributionState", [cid], tag), [0n, 0n], "Unbound collection must not invent Attribution generation");
        io.equal(await io.read(reader, suite.owners[4], collectionAbi, "platformCorrectionStatus", [cid], tag), platform.status, "Original unused correction status differs");
        const display = [BigInt(platform.claims.length) + platform.allegationCount, platform.latestDisplayClaim];
        io.equal(await io.rpc(reader, suite.owners[4], collectionAbi, "attributionClaims", [cid], tag), display, "Original Platform display count or latest differs");
        io.equal(await io.rpc(reader, suite.owners[4], collectionAbi, "staticAttributionClaims", [cid], tag), display, "Original STATIC Platform display count or latest differs");
      }
      for (const row of platform.claims) io.equal(await io.read(reader, suite.owners[4], collectionAbi, "platformWorksClaimRecord", [row.record.recordHash], tag), row.record, "Original complete Platform claim differs");
      for (const row of platform.contests) io.equal(await io.read(reader, suite.owners[4], collectionAbi, "platformWorksContestRecord", [row.record.recordHash], tag), row.record, "Original complete Platform contest differs");
      for (const row of platform.allegations) io.equal(await io.read(reader, suite.owners[4], collectionAbi, "attributionClaimRecord", [row.record.recordHash], tag), row.record, "Original complete attribution allegation differs");
      continue;
    }
    const b = multiple.decodeArtistUnboundPlatformHydrationBinding(binding.rows[index]!);
    const a = multiple.decodeArtistUnboundPlatformHydrationAcceptance(acceptance.rows[index]!);
    const s = multiple.decodeArtistUnboundPlatformHydrationAttributionRow(attribution.rows[index]!);
    const policies = multiple.decodeArtistUnboundPlatformHydrationPolicyBundle(policy.rows[index]!);
    if (current.binding) {
      io.equal(await io.read(reader, suite.owners[0], collectionAbi, "binding", [cid], tag), b.item, "Original mixed current Binding differs");
      io.equal(await io.read(reader, suite.owners[0], collectionAbi, "bindingTermination", [cid, 1n], tag), b.terminal, "Original mixed Binding termination differs");
    }
    io.equal(await io.read(reader, suite.owners[0], collectionAbi, "bindingAt", [cid, 1n], tag), b.history, "Original mixed retained Binding differs");
    io.equal(await io.read(reader, suite.owners[0], collectionAbi, "bindingTerms", [cid, 1n], tag), b.terms, "Original mixed Binding terms differ");
    io.equal(await io.read(reader, suite.owners[3], collectionAbi, "acceptedAt", [q.bindingHash], tag), a.acceptedAt, "Original mixed acceptance time differs");
    io.equal(await io.read(reader, suite.owners[3], collectionAbi, "acceptanceRecord", [q.bindingHash], tag), a.record, "Original mixed acceptance record differs");
    if (current.attribution) {
      io.equal(await io.rpc(reader, suite.owners[4], collectionAbi, "attributionState", [cid], tag), [s.state.item.state, s.state.item.generation], "Original mixed Attribution state differs");
      io.equal(await io.read(reader, suite.owners[4], collectionAbi, "platformWorksState", [cid], tag), emptyTuple(PLATFORM_STATE), "Ordinary mixed collection cannot have Platform history");
    }
    for (let k = 0; k < policies.records.length; k++) {
      const key = policies.policies[k]!, record = policies.records[k]!;
      if (current.policy) io.equal(await io.read(reader, suite.owners[6], collectionAbi, "policyRecord", [cid, key.phaseId, key.policyHash], tag), record, "Original mixed direct policy head differs");
      io.equal(await io.read(reader, suite.owners[6], collectionAbi, "recordDelegation", [record], tag), io.ZERO, "Original mixed policy must remain direct");
    }
  }
}

/** Full original catalogue readback, including unrelated rows and all seven frozen cutoffs. */
async function platformArchive(reader: ArtistRecoveredHydrationReader,
  certificate: multiple.ArtistUnboundPlatformHydrationPrepared, tag: number) {
  const p = certificate.admission.provenance, { payload, state } = ownerState(certificate, 4);
  const platforms = state.collections.flatMap((q, index) => q.artistId === io.ZERO
    ? [multiple.decodeArtistUnboundPlatformHydrationPlatform(state.rows[index]!)] : []);
  if (platforms.length === 0) throw Error("At least one original unbound Platform collection is required");
  const inventory = platforms[0]!;
  for (const platform of platforms) io.equal([platform.catalogues, platform.operations], [inventory.catalogues, inventory.operations], "Every Platform slice must retain the same complete Archive inventory");
  const selected: multiple.ArtistUnboundPlatformHydrationPlatformOperationEvidence[] = [], envelopes: Hex[] = [];
  let rowsRead = 0n, bytesRead = 0;
  for (let era = 0; era < p.origins.length; era++) {
    const origin = p.origins[era]!, expected = inventory.catalogues[era]!;
    io.equal([expected.originHash, expected.lower, expected.upper], [p.eras[era]!.originHash, p.eras[era]!.lowerRevisions, p.eras[era]!.checkpoints.map(row => row.ownerState.revision)], "Complete original seven-owner clock cutoffs differ");
    await io.runtime(reader, { address: origin.archive, codeHash: expected.archiveCodeHash }, tag);
    const suite = await io.read<ArtistHydrationSuite>(reader, origin.coordinator, clockAbi, "authorityHydrationSuite", [], tag);
    io.equal(clockHash([ARTIST_HYDRATION_SUITE_TUPLE], [suite]), origin.suiteConfigurationHash, "Original clock suite hash differs");
    io.equal([suite.registry, suite.archive, suite.core, suite.mintManager, suite.owners], [origin.registry, origin.archive, origin.core, origin.manager, origin.owners], "Original clock suite bindings differ");
    io.equal(await io.read(reader, origin.archive, clockAbi, "artistRegistry", [], tag), origin.registry, "Original Archive Registry differs");
    io.equal(await io.read(reader, origin.archive, clockAbi, "operationCoordinator", [], tag), origin.coordinator, "Original Archive Coordinator differs");
    const marker = id("6529STREAM_ARTIST_ARCHIVE_V2");
    io.equal(await io.read(reader, origin.archive, clockAbi, "artistArchiveMarkerV2", [], tag), marker, "Original Archive marker differs");
    io.equal(await io.read(reader, origin.archive, clockAbi, "artistArchiveSchemaV2", [], tag), 2n, "Original Archive schema differs");
    io.equal(await io.read(reader, origin.archive, clockAbi, "artistArchiveMaxEvidenceBytesV2", [], tag), 24575n, "Original Archive payload bound differs");
    io.equal(await io.read(reader, origin.archive, clockAbi, "artistArchiveBindingHashV2", [], tag),
      clockHash(["bytes32", "uint256", "address", "address", "bytes4", "bytes32", "uint16", "uint256"], [id("6529STREAM_ARTIST_ARCHIVE_BINDING_V2"), origin.chainId, origin.registry, origin.coordinator, archiveInterfaceId, marker, 2n, 24575n]), "Original Archive binding differs");
    io.equal(await io.read(reader, origin.coordinator, clockAbi, "configurationHash", [], tag), expected.configurationHash, "Original clock configuration differs");
    const count = await io.read<bigint>(reader, origin.archive, clockAbi, "storedPayloadCount", [], tag);
    rowsRead += count;
    if (count !== expected.count || rowsRead > 16384n) throw Error("Original Platform catalogue count differs or exceeds source collector bound");
    let chain = clockHash(["bytes32", "bytes32", "address", "bytes32", "bytes32", "uint256"], [id("6529STREAM_ARTIST_RECOVERED_PLATFORM_CATALOGUE_V1"), expected.originHash, origin.archive, expected.archiveCodeHash, expected.configurationHash, count]);
    for (let index = 0n; index < count; index++) {
      const values = await io.rpc(reader, origin.archive, clockAbi, "storedPayloadAt", [index], tag);
      const pointer = io.address(values[0], true), kind = io.hash(values[1], true), contentHash = io.hash(values[2], true);
      chain = clockHash(["bytes32", "uint256", "address", "bytes32", "bytes32"], [chain, index, pointer, kind, contentHash]);
      if (kind !== id("ARTIST_OPERATION_EVIDENCE")) continue;
      const code = io.bytes(await reader.getCode(pointer, tag), 24576);
      if (code.length <= 4 || !code.startsWith("0x00")) throw Error("Original operation carrier must be complete STOP bytes");
      const raw = `0x${code.slice(4)}` as Hex;
      bytesRead += (raw.length - 2) / 2;
      if (bytesRead > 67108864 || raw.length < 194 || keccak256(raw) !== contentHash) throw Error("Original operation carrier hash or byte bound differs");
      const operation = BigInt(`0x${raw.slice(130, 194)}`);
      if (![1n, 2n, 3n, 4n, 8n, 9n, 10n, 11n, 53n].includes(operation)) continue;
      const envelope = multiple.decodeArtistUnboundPlatformHydrationArchiveEnvelope(raw);
      if (envelope.version !== 1n || envelope.configurationHash !== expected.configurationHash || envelope.actor === io.ZERO_ADDRESS || envelope.value === io.ZERO) throw Error("Original operation envelope identity differs");
      const evidenceId = clockHash(["bytes32", "uint256", "address", "address", "uint16", "address", "bytes32"], [id("6529STREAM_ARTIST_ONBOARDING_OPERATION_EVIDENCE_V1"), origin.chainId, origin.registry, origin.coordinator, envelope.operation, envelope.actor, envelope.value]);
      const meta = await io.rpc(reader, origin.archive, clockAbi, "artistEvidenceMetadataV2", [evidenceId, 1n], tag);
      io.equal(meta.slice(0, 3), [contentHash, pointer, BigInt((raw.length - 2) / 2)], "Original operation metadata differs");
      if ((meta[3] as bigint) > BigInt(tag)) throw Error("Original operation evidence is from a future block");
      io.equal(await io.read(reader, origin.archive, clockAbi, "artistEvidenceBytesV2", [evidenceId, 1n], tag), raw, "Original operation evidence bytes differ");
      if (envelope.after_[4].revision <= expected.lower[4] || envelope.after_[4].revision > expected.upper[4]) continue;
      selected.push({ originHash: expected.originHash, operation, evidence: { catalogueIndex: index, pointer, payloadHash: contentHash, evidenceId } });
      envelopes.push(raw);
    }
    io.equal(chain, expected.rowsHash, "Complete original Platform catalogue commitment differs");
    io.equal(await io.read(reader, origin.archive, clockAbi, "storedPayloadCount", [], tag), count, "Original catalogue changed during readback");
  }
  io.equal(selected, inventory.operations, "Original selected Platform evidence differs");
  for (const platform of platforms) multiple.validateArtistUnboundPlatformHydrationPlatformTimeline(platform, payload.provenance, { envelopes });
}

const safeABI = new Interface([
  "function nonce() view returns(uint256)",
  "function getTransactionHash(address to,uint256 value,bytes data,uint8 operation,uint256 safeTxGas,uint256 baseGas,uint256 gasPrice,address gasToken,address refundReceiver,uint256 _nonce) view returns(bytes32)",
  "function execTransaction(address to,uint256 value,bytes data,uint8 operation,uint256 safeTxGas,uint256 baseGas,uint256 gasPrice,address gasToken,address refundReceiver,bytes signatures) payable returns(bool)",
]);
const safeTypes = { SafeTx: ["to:address", "value:uint256", "data:bytes", "operation:uint8", "safeTxGas:uint256", "baseGas:uint256", "gasPrice:uint256", "gasToken:address", "refundReceiver:address", "nonce:uint256"].map(entry => {
  const [name, type] = entry.split(":"); return { name: name!, type: type! };
}) };

async function sourceCounter(reader: ArtistRecoveredHydrationReader, source: ArtistHydrationSuite,
  _input: multiple.ArtistUnboundPlatformHydrationInput, certificate: multiple.ArtistUnboundPlatformHydrationPrepared, tag: number) {
  io.equal(await io.read(reader, source.owners[2], abi, "nextRegistrationNonce", [], tag),
    BigInt(certificate.admission.artists.length), "Original complete registration counter differs");
  if (certificate.admission.artists.length === 0) {
    const { payload, state } = ownerState(certificate, 2);
    // This is the distinct zero-principal timing row, never an Identity bundle for bytes32(0).
    multiple.decodeArtistUnboundPlatformHydrationEmptyIdentity(state.rows[0]!);
    const checkpoint = await io.read<{ nonceIndexCount: bigint }>(reader, source.owners[2], abi, "authorityCheckpoint", [], tag);
    io.equal([checkpoint.nonceIndexCount, payload.nonces.length], [0n, 0], "Zero-principal source cannot contain a nonce inventory");
  }
  await collectionRows(reader, source, certificate, tag, { binding: true, attribution: true, policy: true });
  await platformArchive(reader, certificate, tag);
}
async function destinationCounter(reader: ArtistRecoveredHydrationReader, capture: ArtistUnboundPlatformHydrationCapture,
  snapshots: readonly ArtistHydrationSnapshot[], tag: number) {
  if (snapshots[2]!.revision === capture.after[2]!.revision) {
    const owner = capture.destinationSuite.owners[2], nonces = capture.owners[2]!.payload.nonces;
    io.equal(await io.read(reader, owner, abi, "nextRegistrationNonce", [], tag), BigInt(capture.certificate.admission.artists.length), "Imported registration counter differs");
    const checkpoint = await io.read<{ nonceIndexCount: bigint }>(reader, owner, abi, "authorityCheckpoint", [], tag);
    io.equal(checkpoint.nonceIndexCount, BigInt(nonces.length), "Imported global nonce index count differs");
    for (let index = 0; index < nonces.length; index++) io.equal(await io.read(reader, owner, abi, "authorityNonceIndexAt", [BigInt(index)], tag), nonces[index]!.index, "Imported global nonce insertion order differs");
  }
  await collectionRows(reader, capture.destinationSuite, capture.certificate, tag, {
    binding: snapshots[0]!.revision === capture.after[0]!.revision,
    attribution: snapshots[4]!.revision === capture.after[4]!.revision,
    policy: snapshots[6]!.revision === capture.after[6]!.revision,
  });
  // Original op60 rechecks this catalogue after writes. A later append to the
  // source Archive within the mined block needs separate transaction attribution.
  await platformArchive(reader, capture.certificate, tag);
}
const original = createRecoveredHydrationWorkflow<multiple.ArtistUnboundPlatformHydrationInput, multiple.ArtistUnboundPlatformHydrationCall>({
  normalizeInputDraft: multiple.normalizeArtistUnboundPlatformHydrationInputDraft,
  request: input => input.request,
  finalizeInput: (input, inventory) => multiple.normalizeArtistUnboundPlatformHydrationInput({ request: { ...input.request, expectedSemanticInventory: inventory }, royaltyFreezes: input.royaltyFreezes }),
  inputFromCall: call => ({ request: call.request, royaltyFreezes: call.royaltyFreezes }),
  prepareCall: multiple.prepareArtistUnboundPlatformHydrationCall,
  normalizeCall: multiple.normalizeArtistUnboundPlatformHydrationCall,
  preparationCalldata: multiple.artistUnboundPlatformHydrationPreparationCalldata,
  normalizePrepared: multiple.normalizeArtistUnboundPlatformHydrationPrepared,
  decodeOwnerPayload: multiple.decodeArtistUnboundPlatformHydrationOwnerPayload,
  semanticInventory: multiple.artistUnboundPlatformHydrationSemanticInventory,
  commitment: multiple.artistUnboundPlatformHydrationCommitment,
  ownerAfter: multiple.artistUnboundPlatformHydrationOwnerAfter,
  profileEvidence: multiple.encodeArtistUnboundPlatformHydrationProfileEvidence,
  validateInput: multiple.validateArtistUnboundPlatformHydrationInput,
  freshIdentity: input => {
    const lanes = BigInt(input.request.records.authority.artistIds.length + input.request.records.authority.collections.length);
    return { revision: 1n + lanes, replayCount: 2n + 2n * lanes };
  },
  validateSource: sourceCounter,
  validateReceipt: destinationCounter,
});
const capturedHere = new WeakSet<object>();
export async function captureArtistUnboundPlatformHydration(reader: ArtistRecoveredHydrationReader, deployment: ArtistRecoveredHydrationDeployment,
  caller: Address, input: multiple.ArtistUnboundPlatformHydrationInput, options: { readonly blockTag: number; readonly gasLimit: bigint }) {
  const result = await original.capture(reader, deployment, caller, input, options);
  capturedHere.add(result); return result;
}
export async function simulateArtistUnboundPlatformHydration(reader: ArtistRecoveredHydrationReader, capture: ArtistUnboundPlatformHydrationCapture,
  options: { readonly blockTag: number; readonly gasLimit: bigint }) {
  const result = await original.simulate(reader, capture, options);
  capturedHere.add(result.capture); return result;
}

/** Observes the unchanged actual Registry call after source drift; this is not a fresh capture or a prediction check. */
export async function observeArtistUnboundPlatformHydrationRefusal(reader: ArtistRecoveredHydrationReader, input: ArtistUnboundPlatformHydrationCapture,
  options: { readonly blockTag: number; readonly gasLimit: bigint }) {
  if (!capturedHere.has(input)) throw Error("Refusal requires a capture from this workflow instance");
  io.keys(options, ["blockTag", "gasLimit"]);
  const capture = io.freeze(structuredClone(input)), tag = io.number(options.blockTag), gasLimit = io.gas(options.gasLimit), d = capture.deployment;
  if (tag < capture.observed.blockNumber) throw Error("Refusal observation precedes capture");
  await io.unchanged(reader, capture.observed);
  const observed = await io.chain(reader, d.chainId, tag);
  await io.runtimes(reader, [d.source.registry, d.source.coordinator, ...d.source.components,
    d.destination.registry, d.destination.coordinator, ...d.destination.components, d.preparationLibrary, ...d.preparationDependencies], tag);
  let result;
  try {
    const raw = io.bytes(await reader.call({ ...capture.prepared.call, from: capture.prepared.caller, blockTag: tag, gasLimit }), 32);
    const returnedCommitment = io.hash(io.decode(["bytes32"], raw)[0]);
    result = { status: "succeeded" as const, returnData: raw, returnedCommitment, capturePredictionChecked: false as const };
  } catch (failure) {
    const e = failure && typeof failure === "object" ? failure as { code?: unknown; data?: unknown } : {};
    const data = typeof e.data === "string" && /^0x[0-9a-fA-F]*$/.test(e.data) && e.data.length % 2 === 0 && e.data.length <= 131074 ? e.data as Hex : null;
    result = { status: e.code === "CALL_EXCEPTION" ? "reverted" as const : "rpc-failed" as const, data, capturePredictionChecked: false as const };
  }
  await io.unchanged(reader, observed); await io.unchanged(reader, capture.observed);
  return io.freeze({ ...result, observed, futureExecutionGuaranteed: false as const });
}

function transportOptions(input: ArtistUnboundPlatformHydrationReceiptOptions): ArtistUnboundPlatformHydrationReceiptOptions {
  if (input.execution === "direct") { io.keys(input, ["execution"]); return { execution: "direct" }; }
  io.keys(input, ["execution", "expectedSafeTxHash", "nonce", "safeCodeHash"]);
  if (input.execution !== "safe") throw Error("Unsupported hydration transport");
  return io.freeze({ execution: "safe", expectedSafeTxHash: io.hash(input.expectedSafeTxHash), nonce: io.uint(input.nonce), safeCodeHash: io.hash(input.safeCodeHash) });
}
async function retainedTransport(reader: ArtistRecoveredHydrationReceiptReader, capture: ArtistUnboundPlatformHydrationCapture,
  hash: Hex, options: ArtistUnboundPlatformHydrationReceiptOptions) {
  const m = await io.mined(reader, capture.deployment.chainId, hash), tx = m.transaction;
  if (m.observed.blockNumber <= capture.observed.blockNumber) throw Error("Receipt must follow captured block");
  if (tx.value !== 0n || capture.prepared.call.value !== 0n) throw Error("Original hydration requires zero outer and inner value");
  if (options.execution === "safe") {
    if (!io.same(tx.to, capture.prepared.caller)) throw Error("Safe caller differs");
    const decoded = safeABI.decodeFunctionData("execTransaction", tx.data);
    if (!io.same(safeABI.encodeFunctionData("execTransaction", decoded), tx.data) || !io.same(decoded.to, capture.prepared.registry)
      || decoded.value !== 0n || !io.same(decoded.data, capture.prepared.call.data) || decoded.operation !== 0n) throw Error("Exact recovered ordinary Safe CALL required");
    if (io.bytes(decoded.signatures, 16_384) === "0x") throw Error("Supplied Safe signatures required");
    const prior = m.observed.blockNumber - 1, pin = { address: capture.prepared.caller, codeHash: options.safeCodeHash };
    await io.runtime(reader, pin, prior); await io.runtime(reader, pin, m.observed.blockNumber);
    io.equal(await io.read(reader, pin.address, safeABI, "nonce", [], prior), options.nonce, "Safe prior nonce differs");
    io.equal(await io.read(reader, pin.address, safeABI, "nonce", [], m.observed.blockNumber), options.nonce + 1n, "Safe ending nonce differs");
    const values = [...Array.from(decoded).slice(0, 9), options.nonce];
    const calculated = TypedDataEncoder.hash({ chainId: capture.deployment.chainId, verifyingContract: pin.address }, safeTypes,
      Object.fromEntries(safeTypes.SafeTx.map((field, index) => [field.name, values[index]])));
    io.equal(calculated, options.expectedSafeTxHash, "Independent Safe transaction hash differs");
    io.equal(await io.read(reader, pin.address, safeABI, "getTransactionHash", values, prior), options.expectedSafeTxHash, "Original Safe transaction hash differs");
  }
  // The mined write is attributed to the reviewed whole source/worker closure. No current authorization is repeated.
  const d = capture.deployment;
  await io.runtimes(reader, [d.source.coordinator, ...d.source.components, d.preparationLibrary, ...d.preparationDependencies], m.observed.blockNumber);
  const transaction = io.freeze({ hash, ...tx, chainId: d.chainId, blockNumber: m.observed.blockNumber, blockHash: m.observed.blockHash });
  const receipt = io.freeze({ hash, from: tx.from, to: tx.to, status: 1, blockNumber: m.observed.blockNumber, blockHash: m.observed.blockHash,
    logs: m.logs.map(log => ({ ...log, removed: false, transactionHash: hash, blockNumber: m.observed.blockNumber, blockHash: m.observed.blockHash })) });
  // Both envelopes are detached before further provider reads, including reads inside the shared adapter.
  const proxy: ArtistRecoveredHydrationReceiptReader = {
    getNetwork: reader.getNetwork.bind(reader), getCode: reader.getCode.bind(reader), getBlock: reader.getBlock.bind(reader), call: reader.call.bind(reader),
    getTransaction: (async requested => { if (typeof requested !== "string" || !io.same(requested, hash)) throw Error("Unexpected receipt subject"); return transaction; }) as ArtistRecoveredHydrationReceiptReader["getTransaction"],
    // The shared adapter consumes the detached envelope fields, never ethers receipt methods.
    getTransactionReceipt: (async (requested: string) => { if (!io.same(requested, hash)) throw Error("Unexpected receipt subject"); return receipt; }) as unknown as ArtistRecoveredHydrationReceiptReader["getTransactionReceipt"],
  };
  return { proxy, observed: m.observed };
}
/** Historical import evidence at the mined block; future authority and private activation maps are separate. */
export async function reconcileArtistUnboundPlatformHydrationReceipt(reader: ArtistRecoveredHydrationReceiptReader,
  input: ArtistUnboundPlatformHydrationCapture, transactionHash: Hex, inputOptions: ArtistUnboundPlatformHydrationReceiptOptions) {
  const capture = io.freeze(structuredClone(input)), hash = io.hash(transactionHash), options = transportOptions(inputOptions);
  multiple.normalizeArtistUnboundPlatformHydrationCall(capture.prepared);
  const transport = await retainedTransport(reader, capture, hash, options);
  const result = await original.reconcile(transport.proxy, capture, hash, options.execution === "direct" ? options : { execution: "safe", expectedSafeTxHash: options.expectedSafeTxHash });
  await io.unchanged(reader, transport.observed);
  return io.freeze({ ...result, originalPlatformArchiveReadbackVerifiedAtReceipt: true as const,
    completePlatformInventoryReadBack: true as const,
    retainedPlatformRowsReadBack: true as const,
    laneActivationIndependentlyVerified: false as const, privateSemanticInstallationIndependentlyVerified: false as const,
    ownerSignaturesIndependentlyVerified: false as const, safeImplementationIndependentlyVerified: false as const });
}
export const inspectArtistUnboundPlatformHydrationHistory = reconcileArtistUnboundPlatformHydrationReceipt;
/** Checks eligibility for a fresh import. A completed import is not eligible for replay. */
export async function inspectArtistUnboundPlatformHydrationCurrent(reader: ArtistRecoveredHydrationReader, deployment: ArtistRecoveredHydrationDeployment,
  caller: Address, input: multiple.ArtistUnboundPlatformHydrationInput, options: { readonly blockTag: number; readonly gasLimit: bigint }) {
  const capture = await captureArtistUnboundPlatformHydration(reader, deployment, caller, input, options);
  return simulateArtistUnboundPlatformHydration(reader, capture, { blockTag: capture.observed.blockNumber, gasLimit: capture.preparationGasLimit });
}
