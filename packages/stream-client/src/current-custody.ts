import { Interface, isHexString } from "ethers";
import type { BlockTag, Provider } from "ethers";
import type { Address, Hex } from "./generated/contracts.js";
import type { UnsignedCall } from "./client.js";
import type { SigningPayload } from "./signing.js";
import { currentTypedData } from "./current-signing.js";
import type { CurrentSigningMessages } from "./current-signing.js";

export type CustodyActivationKind = "tokenProfileCustodyActivation" | "custodyRightsActivation";
export interface CustodyActivationSignatures { readonly platformSignature: Hex; readonly artistSignature: Hex }
export interface PreparedCustodyActivation<T extends object> {
  readonly payload: SigningPayload<T>;
  readonly call: UnsignedCall;
  readonly digestCall: UnsignedCall;
  readonly digestMethod: string;
}
const prefix = "bytes32 auctionId,bytes32 baseConfigHash,bytes32 originHash,uint256 tokenId,";
const suffix = "bytes32 assignmentHash,bytes32 primaryPolicyHash,uint8 primaryPolicyMode,address artist,bytes32 nonce,uint64 deadline";
const families = {
  tokenProfileCustodyActivation: { stem: "TokenProfileCustody", getter: "tokenProfileCustodyDigest", tuple: "(" + prefix + suffix + ")" },
  custodyRightsActivation: { stem: "CustodyRights", getter: "custodyRightsDigest", tuple: "(" + prefix + "uint8 rightsMode," + suffix + ")" },
} as const;
const abi = new Interface(Object.values(families).flatMap(f => [
  `function activate${f.stem}(${f.tuple},bytes platformSignature,bytes artistSignature)`,
  `function ${f.getter}(${f.tuple}) view returns (bytes32)`,
  `function bid${f.stem}(bytes32 auctionId,address deliverTo) payable`,
  `function settle${f.stem}(bytes32 auctionId) returns (uint256 tokenId,bytes32 settlementKey)`,
]));
function family(kind: CustodyActivationKind) {
  if (typeof kind !== "string" || !Object.hasOwn(families, kind)) throw new Error("Unknown custody activation family");
  return families[kind];
}
function call(house: Address, method: string, args: readonly unknown[], value = 0n): UnsignedCall {
  if (typeof house !== "string" || !/^0x[0-9a-fA-F]{40}$/.test(house) || /^0x0{40}$/.test(house)) throw new Error("House must be a nonzero address");
  if (typeof value !== "bigint" || value < 0n || value >= 1n << 256n) throw new Error("Value must fit uint256 bigint");
  return Object.freeze({ to: house, data: abi.encodeFunctionData(method, args) as Hex, value });
}
/**
 * Prepare the poster's activation CALL with both approval signatures. Safe/EOA signature bytes
 * are opaque; an empty value does not select direct-authority approval. The contract verifies
 * both signers and requires the actual caller to be the configured poster.
 */
export function prepareCustodyActivation<K extends CustodyActivationKind>(
  kind: K, chainId: bigint, house: Address, message: CurrentSigningMessages[K], signatures: CustodyActivationSignatures,
): PreparedCustodyActivation<CurrentSigningMessages[K]> {
  const f = family(kind), payload = currentTypedData(kind, chainId, house, message);
  if (!signatures || typeof signatures !== "object") throw new Error("Expected both approval signatures");
  for (const value of [signatures.platformSignature, signatures.artistSignature]) {
    if (typeof value !== "string" || !isHexString(value, true)) throw new Error("Signature must contain complete hex bytes");
  }
  return Object.freeze({ payload, digestMethod: f.getter,
    call: call(house, "activate" + f.stem, [payload.message, signatures.platformSignature, signatures.artistSignature]),
    digestCall: call(house, f.getter, [payload.message]),
  });
}
/** Preserve the explicit activated family; a direct bid carries the payer's exact native value. */
export function prepareCustodyBid(kind: CustodyActivationKind, house: Address, auctionId: Hex, deliverTo: Address, amount: bigint): UnsignedCall {
  return call(house, "bid" + family(kind).stem, [auctionId, deliverTo], amount);
}
export function prepareCustodySettlement(kind: CustodyActivationKind, house: Address, auctionId: Hex): UnsignedCall {
  return call(house, "settle" + family(kind).stem, [auctionId]);
}
/** Verify encoding against the actual house before signing; live auction eligibility is separate. */
export async function assertCustodyActivationDigest<T extends object>(
  provider: Pick<Provider, "getNetwork" | "call">, prepared: PreparedCustodyActivation<T>, options: { blockTag?: BlockTag } = {},
): Promise<void> {
  const network = await provider.getNetwork();
  if (network.chainId !== BigInt(prepared.payload.domain.chainId ?? 0)) throw new Error("RPC chain differs from custody signing domain");
  const raw = await provider.call({ ...prepared.digestCall, ...(options.blockTag === undefined ? {} : { blockTag: options.blockTag }) });
  const [actual] = abi.decodeFunctionResult(prepared.digestMethod, raw);
  if (actual.toLowerCase() !== prepared.payload.digest.toLowerCase()) throw new Error("Current custody getter differs from signing payload");
}
