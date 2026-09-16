import { Interface, ZeroAddress, ZeroHash, getAddress, id, isHexString, keccak256, toUtf8Bytes, type Provider, type BlockTag } from "ethers";
import type { Address, Hex } from "./generated/contracts.js";
import type { UnsignedCall } from "./client.js";
import { prepareArtistContentConsent } from "./current-manifests.js";

export const ENTROPY_RECOVERY_CONTENT_FAMILY = id("6529STREAM_ENTROPY_RECOVERY_V1") as Hex;
export interface FreshEntropyRecoveryInput {
  readonly oldRequestKey: Hex;
  readonly reasonURI: string;
  readonly providerEvidenceHash: Hex;
}
export interface PreparedFreshEntropyRecovery {
  readonly input: FreshEntropyRecoveryInput;
  readonly call: UnsignedCall;
  readonly previewCall: UnsignedCall;
}
export interface FreshEntropyRecoveryPreview {
  readonly coordinator: Address;
  readonly oldRequestKey: Hex;
  readonly inputHash: Hex;
  readonly requestKey: Hex;
  readonly contentStateHash: Hex;
  readonly providerFee: bigint;
}
const inputTuple = "(bytes32 oldRequestKey,string reasonURI,bytes32 providerEvidenceHash)";
const abi = new Interface([
  `function requestFreshEntropy(${inputTuple} input) payable returns (bytes32 requestKey,uint256 providerRequestId)`,
  `function freshRecoveryTransition(${inputTuple} input) view returns (bytes32 requestKey,bytes32 contentStateHash,uint256 providerFee)`,
  "function markEntropyRequestUnrecoverable(uint256 tokenId,string reasonURI,bytes32 evidenceHash)",
  "function markEntropyScopeRequestUnrecoverable(bytes32 scopeId,string reasonURI,bytes32 evidenceHash)",
  "function claimEntropyFeeCredit(address destination)",
]);
function address(value: Address): Address {
  const a = getAddress(value) as Address;
  if (a === ZeroAddress) throw new Error("Expected nonzero address");
  return a;
}
function hash(value: Hex): Hex {
  if (typeof value !== "string" || !isHexString(value, 32) || value.toLowerCase() === ZeroHash) throw new Error("Expected nonzero bytes32");
  return value;
}
function uint(value: bigint): bigint {
  if (typeof value !== "bigint" || value < 0n || value >= 1n << 256n) throw new Error("Expected uint256 bigint");
  return value;
}
function reason(value: string): string {
  if (typeof value !== "string" || toUtf8Bytes(value).length === 0 || toUtf8Bytes(value).length > 2048) throw new Error("Reason must contain 1 to 2048 UTF-8 bytes");
  return value;
}
function call(target: Address, method: string, args: readonly unknown[], value = 0n): UnsignedCall {
  return Object.freeze({ to: address(target), data: abi.encodeFunctionData(method, args) as Hex, value: uint(value) });
}
/** Exact ordinary CALLs. The contract checks the live incident role, frozen policy, provider and Artist evidence. */
export function prepareFreshEntropyRecovery(coordinator: Address, input: FreshEntropyRecoveryInput, nativeAllowance: bigint): PreparedFreshEntropyRecovery {
  if (!input || Object.keys(input).sort().join(",") !== "oldRequestKey,providerEvidenceHash,reasonURI") throw new Error("Expected exact recovery input fields");
  const saved = Object.freeze({ oldRequestKey: hash(input.oldRequestKey), reasonURI: reason(input.reasonURI), providerEvidenceHash: hash(input.providerEvidenceHash) });
  return Object.freeze({ input: saved, call: call(coordinator, "requestFreshEntropy", [saved], nativeAllowance),
    previewCall: call(coordinator, "freshRecoveryTransition", [saved]) });
}
/** One quote at the requested block. It may become stale; this read does not reserve a draw or an Artist nonce. */
export async function readFreshEntropyRecoveryPreview(provider: Pick<Provider, "call">, prepared: PreparedFreshEntropyRecovery, options: { blockTag?: BlockTag } = {}): Promise<FreshEntropyRecoveryPreview> {
  const raw = await provider.call({ ...prepared.previewCall, ...(options.blockTag === undefined ? {} : { blockTag: options.blockTag }) });
  if (!isHexString(raw, 96)) throw new Error("Expected exact recovery quote");
  const [requestKey, contentStateHash, providerFee] = abi.decodeFunctionResult("freshRecoveryTransition", raw);
  return Object.freeze({ coordinator: prepared.call.to, oldRequestKey: prepared.input.oldRequestKey, inputHash: keccak256(prepared.previewCall.data) as Hex,
    requestKey: hash(requestKey), contentStateHash: hash(contentStateHash), providerFee: uint(providerFee) });
}
/** Original operation17 and EIP-712 domain. An empty signature requires the Artist authority Safe itself to execute the returned CALL. */
export function prepareEntropyRecoveryContentConsent(chainId: bigint, registry: Address, core: Address, collectionId: bigint,
  prepared: PreparedFreshEntropyRecovery, preview: FreshEntropyRecoveryPreview,
  authorization: { readonly nonce: bigint; readonly deadline: bigint; readonly signature: Hex }) {
  if (address(preview.coordinator) !== address(prepared.call.to) || preview.oldRequestKey.toLowerCase() !== prepared.input.oldRequestKey.toLowerCase() || hash(preview.inputHash).toLowerCase() !== keccak256(prepared.previewCall.data)) throw new Error("Quote belongs to another recovery request");
  hash(preview.requestKey);
  return prepareArtistContentConsent(chainId, registry, core,
    { collectionId, contract: prepared.call.to, familyId: ENTROPY_RECOVERY_CONTENT_FAMILY }, hash(preview.contentStateHash), authorization);
}
export type EntropyIncidentSubject = { readonly kind: "token"; readonly tokenId: bigint } | { readonly kind: "scope"; readonly scopeId: Hex };
/** Incident declaration records evidence and terminates the current request; it never authorizes a replacement draw by itself. */
export function prepareEntropyIncident(coordinator: Address, subject: EntropyIncidentSubject, reasonURI: string, evidenceHash: Hex): UnsignedCall {
  if (subject?.kind === "token") {
    if (uint(subject.tokenId) === 0n) throw new Error("Expected positive tokenId");
    return call(coordinator, "markEntropyRequestUnrecoverable", [subject.tokenId, reason(reasonURI), hash(evidenceHash)]);
  }
  if (subject?.kind === "scope") return call(coordinator, "markEntropyScopeRequestUnrecoverable", [hash(subject.scopeId), reason(reasonURI), hash(evidenceHash)]);
  throw new Error("Expected token or scope incident subject");
}
/** The original credited executor, including a Safe, must send this CALL. There is no payer override. */
export function prepareEntropyFeeCreditClaim(coordinator: Address, destination: Address): UnsignedCall {
  return call(coordinator, "claimEntropyFeeCredit", [address(destination)]);
}
