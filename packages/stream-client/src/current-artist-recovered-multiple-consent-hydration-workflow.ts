/** MULTIPLE_CONSENTS operation60 adapter. Original Registry simulation remains semantic admission. */
import { Interface, TypedDataEncoder } from "ethers";
import type { Address, Hex } from "./generated/contracts.js";
import type { ArtistHydrationSuite, ArtistHydrationSnapshot } from "./current-artist-authority-hydration.js";
import { ARTIST_HYDRATION_CHECKPOINT_TUPLE } from "./current-artist-authority-hydration.js";
import * as multiple from "./current-artist-recovered-multiple-consent-hydration.js";
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
  ArtistRecoveredHydrationCodePin as ArtistRecoveredMultipleConsentHydrationCodePin,
  ArtistRecoveredHydrationSuitePins as ArtistRecoveredMultipleConsentHydrationSuitePins,
  ArtistRecoveredHydrationDeployment as ArtistRecoveredMultipleConsentHydrationDeployment,
  ArtistRecoveredHydrationReader as ArtistRecoveredMultipleConsentHydrationReader,
  ArtistRecoveredHydrationReceiptReader as ArtistRecoveredMultipleConsentHydrationReceiptReader,
  ArtistRecoveredHydrationObservation as ArtistRecoveredMultipleConsentHydrationObservation,
  ArtistRecoveredHydrationOwnerObservation as ArtistRecoveredMultipleConsentHydrationOwnerObservation,
} from "./internal/artist-recovered-hydration-workflow.js";
export type ArtistRecoveredMultipleConsentHydrationCapture = ArtistRecoveredHydrationCapture<multiple.ArtistRecoveredMultipleConsentHydrationCall>;
export type ArtistRecoveredMultipleConsentHydrationSimulation = ArtistRecoveredHydrationSimulation<multiple.ArtistRecoveredMultipleConsentHydrationCall>;
export type ArtistRecoveredMultipleConsentHydrationReceiptOptions = Readonly<
  { execution: "direct" } | { execution: "safe"; expectedSafeTxHash: Hex; nonce: bigint; safeCodeHash: Hex }
>;
const abi = new Interface([
  "function nextRegistrationNonce() view returns(uint256)",
  `function authorityCheckpoint() view returns(${ARTIST_HYDRATION_CHECKPOINT_TUPLE})`,
  "function authorityNonceIndexAt(uint256) view returns((uint8 kind,bytes32 key,uint256 prefixCount))",
]);
const CONTENT_TERMS = "tuple(uint256 collectionId,address metadataContract,bytes32 familyId,bytes32 newStateHash)";
const CONTENT_RECORD = `tuple(bytes32 recordHash,bytes32 artistId,uint64 bindingGeneration,${CONTENT_TERMS} terms,uint8 authorityClass)`;
const ROYALTY_TERMS = "tuple(address resolver,uint256 collectionId,bytes32 revenueClass,bytes32 expectedAssignmentHash)";
const ROYALTY_RECORD = "tuple(bytes32 recordHash,bytes32 artistId,uint64 bindingGeneration)";
const FREEZE_RECORD = "tuple(bytes32 recordHash,bytes32 artistId,uint64 bindingGeneration,address metadataContract,bytes32[] lockClasses,bytes32 expectedStateHash,uint8 authorityClass)";
const ECONOMICS_TERMS = "tuple(uint256 collectionId,address resolver,bytes32 revenueClass,uint8 scope,uint256 scopeId,bytes32 assignmentHash)";
const ECONOMICS_ASSOCIATION = "tuple(bytes32 artistId,uint64 bindingGeneration,bytes32 bindingHash,bytes32 payloadHash,bytes32 originalRecord)";
const SALE_RECORD = "tuple(bytes32 recordHash,tuple(uint256 collectionId,address saleAdapter,bytes32 saleId,bytes32 saleConfigHash) terms,bytes32 artistId,address signer,uint8 authorityClass,uint256 nonce,uint64 signedAt,uint64 bindingGeneration,bytes32 bindingHash)";
const GRANT = "tuple(bytes32 artistId,address delegate,uint256 collectionId,uint32 capabilities,uint64 notBefore,uint64 expiresAt,uint64 maxUses,bytes32 constraintsHash)";
const DELEGATION_RECORD = `tuple(${GRANT} grant,address grantor,uint256 nonce,uint256 uses,bool revoked,bytes32 revocationRecordHash)`;
const consentAbi = new Interface([
  "function policyRecord(uint256 collectionId,bytes32 phaseId,bytes32 policyHash) view returns(bytes32)",
  `function economicsRecord(${ECONOMICS_TERMS} payload) view returns(bytes32)`,
  `function economicsRecordForBinding(${ECONOMICS_TERMS} payload,bytes32 artistId,uint64 bindingGeneration,bytes32 bindingHash) view returns(bytes32)`,
  `function economicsRecordAssociation(bytes32 recordHash) view returns(${ECONOMICS_ASSOCIATION})`,
  `function saleConsentRecord(bytes32 recordHash) view returns(${SALE_RECORD})`,
  "function saleConsentAt(uint256 collectionId,bytes32 saleId,bytes32 saleConfigHash) view returns(bytes32)",
  `function contentConsentRecord(bytes32 recordHash) view returns(${CONTENT_RECORD})`,
  `function contentConsentAt(${CONTENT_TERMS} p,uint64 generation) view returns(${CONTENT_RECORD})`,
  `function royaltyFreezeRecord(${ROYALTY_TERMS} p,bytes32 artistId,uint64 bindingGeneration) view returns(${ROYALTY_RECORD})`,
  `function contentFreezeRecord(bytes32 recordHash) view returns(${FREEZE_RECORD})`,
  `function contentFreezeAt(uint256 collectionId,uint64 generation,address metadata,bytes32 lockClass) view returns(${FREEZE_RECORD})`,
  "function recordDelegation(bytes32 recordHash) view returns(bytes32)",
]);
const identityAbi = new Interface([`function delegationRecord(bytes32 grant) view returns(${DELEGATION_RECORD})`]);
const safeABI = new Interface([
  "function nonce() view returns(uint256)",
  "function getTransactionHash(address to,uint256 value,bytes data,uint8 operation,uint256 safeTxGas,uint256 baseGas,uint256 gasPrice,address gasToken,address refundReceiver,uint256 _nonce) view returns(bytes32)",
  "function execTransaction(address to,uint256 value,bytes data,uint8 operation,uint256 safeTxGas,uint256 baseGas,uint256 gasPrice,address gasToken,address refundReceiver,bytes signatures) payable returns(bool)",
]);
const safeTypes = { SafeTx: ["to:address", "value:uint256", "data:bytes", "operation:uint8", "safeTxGas:uint256", "baseGas:uint256", "gasPrice:uint256", "gasToken:address", "refundReceiver:address", "nonce:uint256"].map(entry => {
  const [name, type] = entry.split(":"); return { name: name!, type: type! };
}) };
async function sourceCounter(reader: ArtistRecoveredHydrationReader, source: ArtistHydrationSuite,
  _input: multiple.ArtistRecoveredMultipleConsentHydrationInput, certificate: multiple.ArtistRecoveredMultipleConsentHydrationPrepared, tag: number) {
  io.equal(await io.read(reader, source.owners[2], abi, "nextRegistrationNonce", [], tag),
    BigInt(certificate.admission.artists.length), "Original aggregate registration counter differs");
  await delegationRows(reader, source.owners[2], certificate, tag);
  await consentRows(reader, source.owners[6], certificate, tag, true);
}
async function destinationCounter(reader: ArtistRecoveredHydrationReader, capture: ArtistRecoveredMultipleConsentHydrationCapture,
  snapshots: readonly ArtistHydrationSnapshot[], tag: number) {
  // Later genuine native writes may advance counters. Immutable provenance still proves the import.
  if (snapshots[2]!.revision === capture.after[2]!.revision) {
    const owner = capture.destinationSuite.owners[2], nonces = capture.owners[2]!.payload.nonces;
    io.equal(await io.read(reader, owner, abi, "nextRegistrationNonce", [], tag), BigInt(capture.certificate.admission.artists.length), "Imported aggregate registration counter differs");
    const checkpoint = await io.read<{ nonceIndexCount: bigint }>(reader, owner, abi, "authorityCheckpoint", [], tag);
    io.equal(checkpoint.nonceIndexCount, BigInt(nonces.length), "Imported global nonce index count differs");
    for (let index = 0; index < nonces.length; index++) io.equal(await io.read(reader, owner, abi, "authorityNonceIndexAt", [BigInt(index)], tag), nonces[index]!.index, "Imported global nonce insertion order differs");
    await delegationRows(reader, owner, capture.certificate, tag);
  }
  await consentRows(reader, capture.destinationSuite.owners[6], capture.certificate, tag,
    snapshots[6]!.revision === capture.after[6]!.revision);
}
/** Retained mutable grant records are read only at the exact source/import revision. No new grant authorization. */
async function delegationRows(reader: ArtistRecoveredHydrationReader, owner: Address,
  certificate: multiple.ArtistRecoveredMultipleConsentHydrationPrepared, tag: number) {
  const { payload } = multiple.decodeArtistRecoveredMultipleConsentHydrationOwnerPayload(certificate.data[2].typedState, 2);
  const state = multiple.decodeArtistRecoveredMultipleConsentHydrationState(payload.semanticState, 2, payload.provenance);
  for (const raw of state.rows) {
    const identity = multiple.decodeArtistRecoveredMultipleConsentHydrationIdentity(raw);
    for (const row of identity.delegations) {
      io.equal(await io.read(reader, owner, identityAbi, "delegationRecord", [row.recordHash], tag), row.record,
        "Original complete grant version, usage or revocation differs");
    }
  }
}
/** Reads each collection in selector order; the original producer remains full source admission. */
async function consentRows(reader: ArtistRecoveredHydrationReader, owner: Address,
  certificate: multiple.ArtistRecoveredMultipleConsentHydrationPrepared, tag: number, requireLatest: boolean) {
  const { payload } = multiple.decodeArtistRecoveredMultipleConsentHydrationOwnerPayload(certificate.data[6].typedState, 6);
  const state = multiple.decodeArtistRecoveredMultipleConsentHydrationState(payload.semanticState, 6, payload.provenance);
  for (const raw of state.rows) {
    const b = multiple.decodeArtistRecoveredMultipleConsentHydrationContentBundle(raw);
    const q = b.original;
    for (let i = 0; i < q.policies.length; i++) {
      const row = q.policies[i]!, key = q.keys[i]!;
      if (requireLatest) io.equal(await io.read(reader, owner, consentAbi, "policyRecord", [q.collectionId, key.phaseId, key.policyHash], tag), row.recordHash, "Original policy head differs");
      io.equal(await io.read(reader, owner, consentAbi, "recordDelegation", [row.recordHash], tag), row.grant, "Original policy grant association differs");
    }
    for (const row of q.economics) {
      if (requireLatest) io.equal(await io.read(reader, owner, consentAbi, "economicsRecord", [row.item.terms], tag), row.item.recordHash, "Original economics head differs");
      io.equal(await io.read(reader, owner, consentAbi, "economicsRecordForBinding", [row.item.terms, q.artistId, 1n, q.bindingHash], tag), row.item.recordHash, "Original economics binding association differs");
      io.equal(await io.read(reader, owner, consentAbi, "economicsRecordAssociation", [row.item.recordHash], tag), row.item.association, "Original economics record association differs");
      io.equal(await io.read(reader, owner, consentAbi, "recordDelegation", [row.item.recordHash], tag), row.grant, "Original economics grant association differs");
    }
    for (const row of q.sales) {
      io.equal(await io.read(reader, owner, consentAbi, "saleConsentRecord", [row.item.recordHash], tag), row.item, "Original sale record differs");
      io.equal(await io.read(reader, owner, consentAbi, "recordDelegation", [row.item.recordHash], tag), row.grant, "Original sale grant association differs");
      if (requireLatest) io.equal(await io.read(reader, owner, consentAbi, "saleConsentAt", [q.collectionId, row.item.terms.saleId, row.item.terms.saleConfigHash], tag), row.current, "Original sale head differs");
    }
    let consentIndex = 0, royaltyIndex = 0, freezeIndex = 0;
    // Keep the original collectRows journal order across operations 17, 20 and 21.
    for (const entry of payload.provenance.journal) {
      if (entry.receipt.artistId !== q.artistId || entry.receipt.collectionId !== q.collectionId) continue;
      if (entry.receipt.operation === 17n) {
        const row = b.consents[consentIndex++]!;
        io.equal(await io.read(reader, owner, consentAbi, "contentConsentRecord", [entry.receipt.recordHash], tag), row, "Original operation17 record differs");
        io.equal(await io.read(reader, owner, consentAbi, "recordDelegation", [entry.receipt.recordHash], tag), io.ZERO, "Original operation17 must remain undelegated");
      } else if (entry.receipt.operation === 20n) {
        const row = b.royalties[royaltyIndex++]!;
        io.equal(await io.read(reader, owner, consentAbi, "royaltyFreezeRecord", [row.terms, q.artistId, 1n], tag), row.item, "Original royalty record differs");
        io.equal(await io.read(reader, owner, consentAbi, "recordDelegation", [row.item.recordHash], tag), row.grant, "Original royalty grant association differs");
      } else if (entry.receipt.operation === 21n) {
        const row = b.freezes[freezeIndex++]!;
        io.equal(await io.read(reader, owner, consentAbi, "contentFreezeRecord", [entry.receipt.recordHash], tag), row, "Original operation21 record differs");
        io.equal(await io.read(reader, owner, consentAbi, "recordDelegation", [entry.receipt.recordHash], tag), io.ZERO, "Original operation21 must remain undelegated");
      }
    }
    // Original Reads.collectRows authenticates all retained rows before requireHeads.
    if (!requireLatest) continue;
    for (const row of b.consents) {
      const latest = b.consents.filter(value => io.stable(value.terms) === io.stable(row.terms)).at(-1)!;
      io.equal(await io.read(reader, owner, consentAbi, "contentConsentAt", [row.terms, 1n], tag), latest, "Original content scope head differs");
    }
    for (const row of b.freezes) for (const lock of row.lockClasses) {
      const latest = b.freezes.filter(value => io.same(value.metadataContract, row.metadataContract) && value.lockClasses.includes(lock)).at(-1)!;
      io.equal(await io.read(reader, owner, consentAbi, "contentFreezeAt", [q.collectionId, 1n, row.metadataContract, lock], tag), latest, "Original per-lock freeze head differs");
    }
  }
}
const original = createRecoveredHydrationWorkflow<multiple.ArtistRecoveredMultipleConsentHydrationInput, multiple.ArtistRecoveredMultipleConsentHydrationCall>({
  normalizeInputDraft: multiple.normalizeArtistRecoveredMultipleConsentHydrationInputDraft,
  request: input => input.request,
  finalizeInput: (input, inventory) => multiple.normalizeArtistRecoveredMultipleConsentHydrationInput({ request: { ...input.request, expectedSemanticInventory: inventory }, royaltyFreezes: input.royaltyFreezes }),
  inputFromCall: call => ({ request: call.request, royaltyFreezes: call.royaltyFreezes }),
  prepareCall: multiple.prepareArtistRecoveredMultipleConsentHydrationCall,
  normalizeCall: multiple.normalizeArtistRecoveredMultipleConsentHydrationCall,
  preparationCalldata: multiple.artistRecoveredMultipleConsentHydrationPreparationCalldata,
  normalizePrepared: multiple.normalizeArtistRecoveredMultipleConsentHydrationPrepared,
  decodeOwnerPayload: multiple.decodeArtistRecoveredMultipleConsentHydrationOwnerPayload,
  semanticInventory: multiple.artistRecoveredMultipleConsentHydrationSemanticInventory,
  commitment: multiple.artistRecoveredMultipleConsentHydrationCommitment,
  ownerAfter: multiple.artistRecoveredMultipleConsentHydrationOwnerAfter,
  profileEvidence: multiple.encodeArtistRecoveredMultipleConsentHydrationProfileEvidence,
  validateInput: multiple.validateArtistRecoveredMultipleConsentHydrationInput,
  freshIdentity: input => {
    const lanes = BigInt(input.request.records.authority.artistIds.length + input.request.records.authority.collections.length);
    return { revision: 1n + lanes, replayCount: 2n + 2n * lanes };
  },
  validateSource: sourceCounter,
  validateReceipt: destinationCounter,
});
export const captureArtistRecoveredMultipleConsentHydration = original.capture;
export const simulateArtistRecoveredMultipleConsentHydration = original.simulate;

function transportOptions(input: ArtistRecoveredMultipleConsentHydrationReceiptOptions): ArtistRecoveredMultipleConsentHydrationReceiptOptions {
  if (input.execution === "direct") { io.keys(input, ["execution"]); return { execution: "direct" }; }
  io.keys(input, ["execution", "expectedSafeTxHash", "nonce", "safeCodeHash"]);
  if (input.execution !== "safe") throw Error("Unsupported hydration transport");
  return io.freeze({ execution: "safe", expectedSafeTxHash: io.hash(input.expectedSafeTxHash), nonce: io.uint(input.nonce), safeCodeHash: io.hash(input.safeCodeHash) });
}
async function retainedTransport(reader: ArtistRecoveredHydrationReceiptReader, capture: ArtistRecoveredMultipleConsentHydrationCapture,
  hash: Hex, options: ArtistRecoveredMultipleConsentHydrationReceiptOptions) {
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
export async function reconcileArtistRecoveredMultipleConsentHydrationReceipt(reader: ArtistRecoveredHydrationReceiptReader,
  input: ArtistRecoveredMultipleConsentHydrationCapture, transactionHash: Hex, inputOptions: ArtistRecoveredMultipleConsentHydrationReceiptOptions) {
  const capture = io.freeze(structuredClone(input)), hash = io.hash(transactionHash), options = transportOptions(inputOptions);
  multiple.normalizeArtistRecoveredMultipleConsentHydrationCall(capture.prepared);
  const transport = await retainedTransport(reader, capture, hash, options);
  const result = await original.reconcile(transport.proxy, capture, hash, options.execution === "direct" ? options : { execution: "safe", expectedSafeTxHash: options.expectedSafeTxHash });
  await io.unchanged(reader, transport.observed);
  return io.freeze({ ...result, laneActivationIndependentlyVerified: false as const, privateSemanticInstallationIndependentlyVerified: false as const,
    ownerSignaturesIndependentlyVerified: false as const, safeImplementationIndependentlyVerified: false as const });
}
export const inspectArtistRecoveredMultipleConsentHydrationHistory = reconcileArtistRecoveredMultipleConsentHydrationReceipt;
/** Checks eligibility for a fresh import. A completed import is not eligible for replay. */
export async function inspectArtistRecoveredMultipleConsentHydrationCurrent(reader: ArtistRecoveredHydrationReader, deployment: ArtistRecoveredHydrationDeployment,
  caller: Address, input: multiple.ArtistRecoveredMultipleConsentHydrationInput, options: { readonly blockTag: number; readonly gasLimit: bigint }) {
  const capture = await original.capture(reader, deployment, caller, input, options);
  return original.simulate(reader, capture, { blockTag: capture.observed.blockNumber, gasLimit: capture.preparationGasLimit });
}
