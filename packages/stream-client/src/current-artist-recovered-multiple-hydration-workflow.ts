/** MULTIPLE_BASE operation60 adapter. Original Registry simulation remains semantic admission. */
import { Interface, TypedDataEncoder } from "ethers";
import type { Address, Hex } from "./generated/contracts.js";
import type { ArtistHydrationSuite, ArtistHydrationSnapshot } from "./current-artist-authority-hydration.js";
import { ARTIST_HYDRATION_CHECKPOINT_TUPLE } from "./current-artist-authority-hydration.js";
import * as multiple from "./current-artist-recovered-multiple-hydration.js";
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
  ArtistRecoveredHydrationCodePin as ArtistRecoveredMultipleHydrationCodePin,
  ArtistRecoveredHydrationSuitePins as ArtistRecoveredMultipleHydrationSuitePins,
  ArtistRecoveredHydrationDeployment as ArtistRecoveredMultipleHydrationDeployment,
  ArtistRecoveredHydrationReader as ArtistRecoveredMultipleHydrationReader,
  ArtistRecoveredHydrationReceiptReader as ArtistRecoveredMultipleHydrationReceiptReader,
  ArtistRecoveredHydrationObservation as ArtistRecoveredMultipleHydrationObservation,
  ArtistRecoveredHydrationOwnerObservation as ArtistRecoveredMultipleHydrationOwnerObservation,
} from "./internal/artist-recovered-hydration-workflow.js";
export type ArtistRecoveredMultipleHydrationCapture = ArtistRecoveredHydrationCapture<multiple.ArtistRecoveredMultipleHydrationCall>;
export type ArtistRecoveredMultipleHydrationSimulation = ArtistRecoveredHydrationSimulation<multiple.ArtistRecoveredMultipleHydrationCall>;
export type ArtistRecoveredMultipleHydrationReceiptOptions = Readonly<
  { execution: "direct" } | { execution: "safe"; expectedSafeTxHash: Hex; nonce: bigint; safeCodeHash: Hex }
>;
const abi = new Interface([
  "function nextRegistrationNonce() view returns(uint256)",
  `function authorityCheckpoint() view returns(${ARTIST_HYDRATION_CHECKPOINT_TUPLE})`,
  "function authorityNonceIndexAt(uint256) view returns((uint8 kind,bytes32 key,uint256 prefixCount))",
]);
const safeABI = new Interface([
  "function nonce() view returns(uint256)",
  "function getTransactionHash(address to,uint256 value,bytes data,uint8 operation,uint256 safeTxGas,uint256 baseGas,uint256 gasPrice,address gasToken,address refundReceiver,uint256 _nonce) view returns(bytes32)",
  "function execTransaction(address to,uint256 value,bytes data,uint8 operation,uint256 safeTxGas,uint256 baseGas,uint256 gasPrice,address gasToken,address refundReceiver,bytes signatures) payable returns(bool)",
]);
const safeTypes = { SafeTx: ["to:address", "value:uint256", "data:bytes", "operation:uint8", "safeTxGas:uint256", "baseGas:uint256", "gasPrice:uint256", "gasToken:address", "refundReceiver:address", "nonce:uint256"].map(entry => {
  const [name, type] = entry.split(":"); return { name: name!, type: type! };
}) };
async function sourceCounter(reader: ArtistRecoveredHydrationReader, source: ArtistHydrationSuite,
  _request: multiple.ArtistRecoveredMultipleHydrationRequest, certificate: multiple.ArtistRecoveredMultipleHydrationPrepared, tag: number) {
  io.equal(await io.read(reader, source.owners[2], abi, "nextRegistrationNonce", [], tag),
    BigInt(certificate.admission.artists.length), "Original aggregate registration counter differs");
}
async function destinationCounter(reader: ArtistRecoveredHydrationReader, capture: ArtistRecoveredMultipleHydrationCapture,
  snapshots: readonly ArtistHydrationSnapshot[], tag: number) {
  // Later genuine native writes may advance counters. Immutable provenance still proves the import.
  if (snapshots[2]!.revision !== capture.after[2]!.revision) return;
  const owner = capture.destinationSuite.owners[2], nonces = capture.owners[2]!.payload.nonces;
  io.equal(await io.read(reader, owner, abi, "nextRegistrationNonce", [], tag), BigInt(capture.certificate.admission.artists.length), "Imported aggregate registration counter differs");
  const checkpoint = await io.read<{ nonceIndexCount: bigint }>(reader, owner, abi, "authorityCheckpoint", [], tag);
  io.equal(checkpoint.nonceIndexCount, BigInt(nonces.length), "Imported global nonce index count differs");
  for (let index = 0; index < nonces.length; index++) io.equal(await io.read(reader, owner, abi, "authorityNonceIndexAt", [BigInt(index)], tag), nonces[index]!.index, "Imported global nonce insertion order differs");
}
const original = createRecoveredHydrationWorkflow<multiple.ArtistRecoveredMultipleHydrationRequest, multiple.ArtistRecoveredMultipleHydrationCall>({
  normalizeInputDraft: multiple.normalizeArtistRecoveredMultipleHydrationRequestDraft,
  request: input => input,
  finalizeInput: (input, inventory) => multiple.normalizeArtistRecoveredMultipleHydrationRequest({ ...input, expectedSemanticInventory: inventory }),
  inputFromCall: call => call.request,
  prepareCall: multiple.prepareArtistRecoveredMultipleHydrationCall,
  normalizeCall: multiple.normalizeArtistRecoveredMultipleHydrationCall,
  preparationCalldata: multiple.artistRecoveredMultipleHydrationPreparationCalldata,
  normalizePrepared: multiple.normalizeArtistRecoveredMultipleHydrationPrepared,
  decodeOwnerPayload: multiple.decodeArtistRecoveredMultipleHydrationOwnerPayload,
  semanticInventory: multiple.artistRecoveredMultipleHydrationSemanticInventory,
  commitment: multiple.artistRecoveredMultipleHydrationCommitment,
  ownerAfter: multiple.artistRecoveredMultipleHydrationOwnerAfter,
  profileEvidence: multiple.encodeArtistRecoveredMultipleHydrationProfileEvidence,
  freshIdentity: input => {
    const lanes = BigInt(input.records.authority.artistIds.length + input.records.authority.collections.length);
    return { revision: 1n + lanes, replayCount: 2n + 2n * lanes };
  },
  validateSource: sourceCounter,
  validateReceipt: destinationCounter,
});
export const captureArtistRecoveredMultipleHydration = original.capture;
export const simulateArtistRecoveredMultipleHydration = original.simulate;

function transportOptions(input: ArtistRecoveredMultipleHydrationReceiptOptions): ArtistRecoveredMultipleHydrationReceiptOptions {
  if (input.execution === "direct") { io.keys(input, ["execution"]); return { execution: "direct" }; }
  io.keys(input, ["execution", "expectedSafeTxHash", "nonce", "safeCodeHash"]);
  if (input.execution !== "safe") throw Error("Unsupported hydration transport");
  return io.freeze({ execution: "safe", expectedSafeTxHash: io.hash(input.expectedSafeTxHash), nonce: io.uint(input.nonce), safeCodeHash: io.hash(input.safeCodeHash) });
}
async function retainedTransport(reader: ArtistRecoveredHydrationReceiptReader, capture: ArtistRecoveredMultipleHydrationCapture,
  hash: Hex, options: ArtistRecoveredMultipleHydrationReceiptOptions) {
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
export async function reconcileArtistRecoveredMultipleHydrationReceipt(reader: ArtistRecoveredHydrationReceiptReader,
  input: ArtistRecoveredMultipleHydrationCapture, transactionHash: Hex, inputOptions: ArtistRecoveredMultipleHydrationReceiptOptions) {
  const capture = io.freeze(structuredClone(input)), hash = io.hash(transactionHash), options = transportOptions(inputOptions);
  multiple.normalizeArtistRecoveredMultipleHydrationCall(capture.prepared);
  const transport = await retainedTransport(reader, capture, hash, options);
  const result = await original.reconcile(transport.proxy, capture, hash, options.execution === "direct" ? options : { execution: "safe", expectedSafeTxHash: options.expectedSafeTxHash });
  await io.unchanged(reader, transport.observed);
  return io.freeze({ ...result, laneActivationIndependentlyVerified: false as const, privateSemanticInstallationIndependentlyVerified: false as const,
    ownerSignaturesIndependentlyVerified: false as const, safeImplementationIndependentlyVerified: false as const });
}
export const inspectArtistRecoveredMultipleHydrationHistory = reconcileArtistRecoveredMultipleHydrationReceipt;
/** Checks eligibility for a fresh import. A completed import is not eligible for replay. */
export async function inspectArtistRecoveredMultipleHydrationCurrent(reader: ArtistRecoveredHydrationReader, deployment: ArtistRecoveredHydrationDeployment,
  caller: Address, request: multiple.ArtistRecoveredMultipleHydrationRequest, options: { readonly blockTag: number; readonly gasLimit: bigint }) {
  const capture = await original.capture(reader, deployment, caller, request, options);
  return original.simulate(reader, capture, { blockTag: capture.observed.blockNumber, gasLimit: capture.preparationGasLimit });
}
