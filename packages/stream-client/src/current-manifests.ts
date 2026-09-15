import { Interface, ZeroAddress, ZeroHash, getAddress, id, isHexString, type ParamType, type Provider, type BlockTag } from "ethers";
import type { Address, Hex } from "./generated/contracts.js";
import type { UnsignedCall } from "./client.js";
import type { PreparedCurrentArtistOperation } from "./current-artist.js";
import { buildSigningPayload } from "./signing-payload.js";

/** Exact Solidity enum values; support for a particular source remains a live contract check. */
export type ManifestSourceType = 0n | 1n | 2n | 3n | 4n | 5n | 6n | 7n | 8n;
export interface CurrentScriptManifest {
  readonly scriptHash: Hex; readonly rendererCompatibility: Hex; readonly sourceType: ManifestSourceType;
  readonly libraryURI: string; readonly scriptURI: string; readonly sourcePointer: string;
  readonly mimeType: string; readonly chunkCount: bigint; readonly executable: boolean;
}
export interface CurrentMediaManifest {
  readonly imageSourceType: ManifestSourceType; readonly imageURI: string; readonly imageHash: Hex; readonly imageMimeType: string;
  readonly animationSourceType: ManifestSourceType; readonly animationURI: string; readonly animationHash: Hex; readonly animationMimeType: string;
  readonly contentSourceType: ManifestSourceType; readonly contentURI: string; readonly contentHash: Hex; readonly contentMimeType: string;
  readonly manifestURI: string; readonly manifestHash: Hex; readonly alternatesURI: string; readonly alternatesHash: Hex;
}
export interface PreparedCollectionManifest {
  readonly collectionId: bigint; readonly familyId: Hex; readonly call: UnsignedCall;
  readonly previewCall: UnsignedCall; readonly previewMethod: string;
}
export interface ManifestContentConsent {
  readonly core: Address; readonly metadataContract: Address; readonly collectionId: bigint;
  readonly familyId: Hex; readonly newStateHash: Hex; readonly nonce: bigint; readonly deadline: bigint;
}
const script = "(bytes32 scriptHash,bytes32 rendererCompatibility,uint8 sourceType,string libraryURI,string scriptURI,string sourcePointer,string mimeType,uint256 chunkCount,bool executable)";
const media = "(uint8 imageSourceType,string imageURI,bytes32 imageHash,string imageMimeType,uint8 animationSourceType,string animationURI,bytes32 animationHash,string animationMimeType,uint8 contentSourceType,string contentURI,bytes32 contentHash,string contentMimeType,string manifestURI,bytes32 manifestHash,string alternatesURI,bytes32 alternatesHash)";
const consent = "(uint256 collectionId,address metadataContract,bytes32 familyId,bytes32 newStateHash)";
const authorization = "(uint256 nonce,uint64 time,bytes signature)";
const abi = new Interface([
  `function setCollectionScriptManifest(uint256 collectionId,${script} value)`,
  `function setCollectionMediaManifest(uint256 collectionId,${media} value)`,
  `function previewArtistScriptManifestState(uint256 collectionId,${script} value) view returns (bytes32)`,
  `function previewArtistMediaManifestState(uint256 collectionId,${media} value) view returns (bytes32)`,
  `function recordContentConsent(${consent} p,${authorization} a) returns (bytes32)`,
  `function contentConsentDigest(${consent} p,${authorization} a) view returns (bytes32)`,
]);
function address(value: Address): Address {
  const normalized = getAddress(value) as Address;
  if (normalized === ZeroAddress) throw new Error("Contract address must be nonzero");
  return normalized;
}
function uint(value: unknown, bits: number): bigint {
  if (typeof value !== "bigint" || value < 0n || value >= 1n << BigInt(bits)) throw new Error(`Expected uint${bits} bigint`);
  return value;
}
function call(target: Address, method: string, args: readonly unknown[]): UnsignedCall {
  return Object.freeze({ to: address(target), data: abi.encodeFunctionData(method, args) as Hex, value: 0n });
}
function validate(value: object, tuple: ParamType): void {
  if (!value || typeof value !== "object" || Array.isArray(value)) throw new Error("Expected manifest object");
  const fields = tuple.components!;
  if (Object.keys(value).sort().join(",") !== fields.map(f => f.name).sort().join(",")) throw new Error("Expected exact manifest fields");
  for (const field of fields) {
    const v = (value as Record<string, unknown>)[field.name];
    if (field.type.startsWith("uint")) {
      const n = uint(v, Number(field.type.slice(4)));
      if (field.type === "uint8" && n > 8n) throw new Error("Unknown manifest source type");
    } else if (field.type === "bytes32") {
      if (typeof v !== "string" || !isHexString(v, 32)) throw new Error(field.name + " must be bytes32");
    } else if (typeof v !== (field.type === "bool" ? "boolean" : "string")) throw new Error("Invalid " + field.name);
  }
}
function prepare(kind: "Script" | "Media", router: Address, collectionId: bigint, value: object): PreparedCollectionManifest {
  if (uint(collectionId, 256) === 0n) throw new Error("collectionId must be positive");
  const method = `setCollection${kind}Manifest`, previewMethod = `previewArtist${kind}ManifestState`;
  validate(value, abi.getFunction(method)!.inputs[1]!);
  return Object.freeze({ collectionId, familyId: id(kind === "Script" ? "SCRIPT" : "MEDIA_MANIFEST") as Hex,
    call: call(router, method, [collectionId, value]), previewCall: call(router, previewMethod, [collectionId, value]), previewMethod });
}
/** Prepare original Router calls; calldata validation does not establish authority or supported execution profile. */
export function prepareScriptManifest(router: Address, collectionId: bigint, value: CurrentScriptManifest): PreparedCollectionManifest {
  return prepare("Script", router, collectionId, value);
}
/** Zero external hashes are retained as absent commitments; no digest is inferred from a URI. */
export function prepareMediaManifest(router: Address, collectionId: bigint, value: CurrentMediaManifest): PreparedCollectionManifest {
  return prepare("Media", router, collectionId, value);
}
/** Read the Router's exact content-family state before Artist consent; this is not the raw manifest hash. */
export async function readManifestContentState(provider: Pick<Provider, "call">, prepared: PreparedCollectionManifest, options: { blockTag?: BlockTag } = {}): Promise<Hex> {
  const raw = await provider.call({ ...prepared.previewCall, ...(options.blockTag === undefined ? {} : { blockTag: options.blockTag }) });
  const [state] = abi.decodeFunctionResult(prepared.previewMethod, raw);
  if (state === ZeroHash) throw new Error("Missing content state");
  return state as Hex;
}
export interface ArtistContentConsentTarget {
  readonly collectionId: bigint; readonly contract: Address; readonly familyId: Hex;
}
/** Original operation 17. Empty signature requires the actual Artist Safe to execute this CALL. */
export function prepareArtistContentConsent(chainId: bigint, registry: Address, core: Address, target: ArtistContentConsentTarget,
  newStateHash: Hex, auth: { readonly nonce: bigint; readonly deadline: bigint; readonly signature: Hex }): PreparedCurrentArtistOperation<ManifestContentConsent> {
  if (uint(target.collectionId, 256) === 0n || !isHexString(target.familyId, 32) || target.familyId === ZeroHash) throw new Error("Expected collection and content family");
  if (!isHexString(newStateHash, 32) || newStateHash === ZeroHash) throw new Error("Expected nonzero content state");
  if (!auth || typeof auth.signature !== "string" || !isHexString(auth.signature, true)) throw new Error("Expected complete signature bytes");
  const message: ManifestContentConsent = { core: address(core), metadataContract: address(target.contract), collectionId: target.collectionId,
    familyId: target.familyId, newStateHash, nonce: auth.nonce, deadline: auth.deadline };
  const fields = "address core,address metadataContract,uint256 collectionId,bytes32 familyId,bytes32 newStateHash,uint256 nonce,uint64 deadline"
    .split(",").map(f => { const [type, name] = f.split(" "); return { type: type!, name: name! }; });
  const payload = buildSigningPayload(chainId, address(registry), "6529StreamArtistRegistry", "StreamArtistContentConsent", fields, message);
  const p = [message.collectionId, message.metadataContract, message.familyId, newStateHash];
  return Object.freeze({ payload, method: "recordContentConsent", digestMethod: "contentConsentDigest",
    call: call(registry, "recordContentConsent", [p, [auth.nonce, auth.deadline, auth.signature]]),
    digestCall: call(registry, "contentConsentDigest", [p, [auth.nonce, auth.deadline, "0x"]]) });
}

/** Original manifest helper retained with its original signing domain and transport. */
export function prepareManifestContentConsent(chainId: bigint, registry: Address, core: Address, prepared: PreparedCollectionManifest,
  newStateHash: Hex, auth: { readonly nonce: bigint; readonly deadline: bigint; readonly signature: Hex }): PreparedCurrentArtistOperation<ManifestContentConsent> {
  return prepareArtistContentConsent(chainId, registry, core,
    { collectionId: prepared.collectionId, contract: prepared.call.to, familyId: prepared.familyId }, newStateHash, auth);
}
