import { Interface, isHexString, keccak256 } from "ethers";
import type { BlockTag, Provider } from "ethers";
import type { Address, Hex } from "./generated/contracts.js";
import type { UnsignedCall } from "./client.js";
import type { SigningPayload } from "./signing.js";
import { currentTypedData } from "./current-signing.js";
import type { CurrentSigningMessages } from "./current-signing.js";

export type NativeImmediateSaleKind = "nativeFixedPriceSale" | "nativePriceProgram";
export interface NativeImmediateSaleInput {
  readonly tokenData: Hex;
  readonly platformSignature: Hex;
  readonly artistSignature: Hex;
  /** Fixed price from the selected sale, or the price-program chosen amount (including a tip). */
  readonly saleAmount: bigint;
  /** Maximum native reveal fee. The contract credits unused allowance to its payer. */
  readonly revealFeeAllowance: bigint;
}
export interface PreparedNativeImmediateSale<T extends object> {
  readonly payload: SigningPayload<T>;
  readonly call: UnsignedCall;
  readonly digestCall: UnsignedCall;
  readonly digestMethod: string;
}
const fields = "bytes32 saleId,bytes32 saleConfigHash,address payer,address executor,address recipient,address artist,bytes32 tokenDataHash,bytes32 mintCommitment,uint256 executionNonce,bytes32 nonce,uint64 deadline,bytes32 expectedPrimaryPolicyHash";
const fixed = "(" + fields + ")", program = "(" + fields + ",uint256 unitPrice)";
const signatures = "bytes tokenData,bytes platformSignature,bytes artistSignature";
const abi = new Interface([
  `function purchase((${fixed} authorization,${signatures}) execution) payable`,
  `function executePriceProgram((${program} authorization,uint256 chosenUnitPrice,${signatures}) execution) payable`,
  `function authorizationDigest(${fixed}) view returns (bytes32)`,
  `function priceProgramAuthorizationDigest(${program}) view returns (bytes32)`,
  "function saleRevealQuote(bytes32) view returns ((address coordinator,bytes32 coordinatorCodeHash,(bool declared,uint8 requestMode,bytes32 revealOwnerRole,uint64 requestSLOBlocks,uint256 revealFeePerTokenWei) policy))",
  "function claimRefund(bytes32 saleId,address recipient)",
]);
function uint(value: bigint): bigint {
  if (typeof value !== "bigint" || value < 0n || value >= 1n << 256n) throw new Error("Amount must fit uint256 bigint");
  return value;
}
function call(adapter: Address, method: string, args: readonly unknown[], value = 0n): UnsignedCall {
  if (typeof adapter !== "string" || !/^0x[0-9a-fA-F]{40}$/.test(adapter) || /^0x0{40}$/.test(adapter)) throw new Error("Adapter must be a nonzero address");
  return Object.freeze({ to: adapter, data: abi.encodeFunctionData(method, args) as Hex, value: uint(value) });
}
/** Exact encoding, not live sale eligibility. The actual payer/executor must send the Safe CALL. */
export function prepareNativeImmediateSale<K extends NativeImmediateSaleKind>(
  kind: K, chainId: bigint, adapter: Address, message: CurrentSigningMessages[K], input: NativeImmediateSaleInput,
): PreparedNativeImmediateSale<CurrentSigningMessages[K]> {
  if (kind !== "nativeFixedPriceSale" && kind !== "nativePriceProgram") throw new Error("Unknown immediate sale family");
  const payload = currentTypedData(kind, chainId, adapter, message);
  if (!input || typeof input !== "object") throw new Error("Expected sale input");
  for (const v of [input.tokenData, input.platformSignature, input.artistSignature]) {
    if (typeof v !== "string" || !isHexString(v, true)) throw new Error("Data and signatures must contain complete hex bytes");
  }
  if (keccak256(input.tokenData).toLowerCase() !== payload.message.tokenDataHash.toLowerCase()) throw new Error("Token data differs from signed hash");
  const amount = uint(input.saleAmount), allowance = uint(input.revealFeeAllowance);
  const program = kind === "nativePriceProgram";
  const execution = { authorization: payload.message, ...(program ? { chosenUnitPrice: amount } : {}),
    tokenData: input.tokenData, platformSignature: input.platformSignature, artistSignature: input.artistSignature };
  const digestMethod = program ? "priceProgramAuthorizationDigest" : "authorizationDigest";
  return Object.freeze({ payload, digestMethod,
    call: call(adapter, program ? "executePriceProgram" : "purchase", [execution], amount + allowance),
    digestCall: call(adapter, digestMethod, [payload.message]),
  });
}
/** The credited payer may choose any nonzero destination other than the adapter. */
export function prepareImmediateSaleRefund(adapter: Address, saleId: Hex, recipient: Address): UnsignedCall {
  if (typeof recipient !== "string" || !/^0x[0-9a-fA-F]{40}$/.test(recipient) || /^0x0{40}$/.test(recipient) || recipient.toLowerCase() === adapter.toLowerCase()) throw new Error("Invalid refund destination");
  return call(adapter, "claimRefund", [saleId, recipient]);
}
export interface ImmediateSaleRevealQuote {
  readonly coordinator: Address; readonly coordinatorCodeHash: Hex; readonly requestMode: bigint;
  readonly revealOwnerRole: Hex; readonly requestSLOBlocks: bigint; readonly revealFeePerTokenWei: bigint;
}
/** A quote may change before inclusion; submit an explicit allowance rather than an exact-fee equation. */
export async function readImmediateSaleRevealQuote(
  provider: Pick<Provider, "call">, adapter: Address, saleId: Hex, options: { blockTag?: BlockTag } = {},
): Promise<ImmediateSaleRevealQuote> {
  const raw = await provider.call({ ...call(adapter, "saleRevealQuote", [saleId]), ...(options.blockTag === undefined ? {} : { blockTag: options.blockTag }) });
  const [q] = abi.decodeFunctionResult("saleRevealQuote", raw);
  if (!q.policy.declared || q.policy.requestMode > 1n) throw new Error("Missing or unsupported reveal policy");
  return Object.freeze({ coordinator: q.coordinator, coordinatorCodeHash: q.coordinatorCodeHash,
    requestMode: q.policy.requestMode, revealOwnerRole: q.policy.revealOwnerRole,
    requestSLOBlocks: q.policy.requestSLOBlocks, revealFeePerTokenWei: q.policy.revealFeePerTokenWei });
}
/** Compare with the current host's matching digest getter before signing. */
export async function assertNativeImmediateSaleDigest<T extends object>(
  provider: Pick<Provider, "getNetwork" | "call">, prepared: PreparedNativeImmediateSale<T>, options: { blockTag?: BlockTag } = {},
): Promise<void> {
  const network = await provider.getNetwork();
  if (network.chainId !== BigInt(prepared.payload.domain.chainId ?? 0)) throw new Error("RPC chain differs from immediate-sale signing domain");
  const raw = await provider.call({ ...prepared.digestCall, ...(options.blockTag === undefined ? {} : { blockTag: options.blockTag }) });
  const [digest] = abi.decodeFunctionResult(prepared.digestMethod, raw);
  if (digest.toLowerCase() !== prepared.payload.digest.toLowerCase()) throw new Error("Current sale getter differs from signing payload");
}
