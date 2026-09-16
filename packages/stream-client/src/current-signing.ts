import type { Address, Hex } from "./generated/contracts.js";
import type { SigningPayload } from "./signing.js";
import { buildSigningPayload } from "./signing-payload.js";

/** Current native-auction domains. Retained RC1 auction helpers remain separate. */
export interface NativeAuctionCreationAuthorization {
  readonly configHash: Hex; readonly artist: Address; readonly nonce: Hex; readonly deadline: bigint;
}
export interface NativeAuctionBidAuthorization {
  readonly auctionId: Hex; readonly configHash: Hex; readonly payer: Address;
  readonly executor: Address; readonly deliverTo: Address; readonly amount: bigint;
  readonly maxRevealFee: bigint; readonly nonce: Hex; readonly deadline: bigint; readonly finalizeBy: bigint;
}
export interface NativeCustodyAcquisitionAuthorization {
  readonly configHash: Hex; readonly tokenDataHash: Hex; readonly expectedSaleNonce: bigint;
  readonly expectedTokenId: bigint; readonly expectedCollectionSerial: bigint;
  readonly expectedOperationNonce: bigint; readonly contextHash: Hex; readonly executor: Address;
  readonly revealFeeDeposit: bigint; readonly artist: Address; readonly nonce: Hex; readonly deadline: bigint;
}
export type PreparedNativeCustodyAcquisitionAuthorization = NativeCustodyAcquisitionAuthorization;
export interface TokenProfileCustodyActivationAuthorization {
  readonly auctionId: Hex; readonly baseConfigHash: Hex; readonly originHash: Hex;
  readonly tokenId: bigint; readonly assignmentHash: Hex; readonly primaryPolicyHash: Hex;
  readonly primaryPolicyMode: bigint; readonly artist: Address; readonly nonce: Hex; readonly deadline: bigint;
}
export interface CustodyRightsActivationAuthorization extends TokenProfileCustodyActivationAuthorization {
  /** 1: default PROFILE; 2/3/4: strict/consented/dynamic token TEMPLATE; 5/6/7: default TEMPLATE. */
  readonly rightsMode: bigint;
}
export interface NativeFixedPriceSaleAuthorization {
  readonly saleId: Hex; readonly saleConfigHash: Hex; readonly payer: Address; readonly executor: Address;
  readonly recipient: Address; readonly artist: Address; readonly tokenDataHash: Hex; readonly mintCommitment: Hex;
  readonly executionNonce: bigint; readonly nonce: Hex; readonly deadline: bigint; readonly expectedPrimaryPolicyHash: Hex;
}
export interface NativePriceProgramAuthorization extends NativeFixedPriceSaleAuthorization { readonly unitPrice: bigint }
export interface CurrentSigningMessages {
  nativeFixedPriceSale: NativeFixedPriceSaleAuthorization;
  nativePriceProgram: NativePriceProgramAuthorization;
  tokenProfileCustodyActivation: TokenProfileCustodyActivationAuthorization;
  custodyRightsActivation: CustodyRightsActivationAuthorization;
  nativeAuctionCreation: NativeAuctionCreationAuthorization;
  nativeAuctionBid: NativeAuctionBidAuthorization;
  nativeCustodyAcquisition: NativeCustodyAcquisitionAuthorization;
  preparedNativeCustodyAcquisition: PreparedNativeCustodyAcquisitionAuthorization;
}
export type CurrentSigningKind = keyof CurrentSigningMessages;

const custodyFields = [
  ["configHash", "bytes32"], ["tokenDataHash", "bytes32"], ["expectedSaleNonce", "uint256"],
  ["expectedTokenId", "uint256"], ["expectedCollectionSerial", "uint256"],
  ["expectedOperationNonce", "uint256"], ["contextHash", "bytes32"], ["executor", "address"],
  ["revealFeeDeposit", "uint256"], ["artist", "address"], ["nonce", "bytes32"], ["deadline", "uint64"],
] as const;
const activationPrefix = [["auctionId", "bytes32"], ["baseConfigHash", "bytes32"], ["originHash", "bytes32"], ["tokenId", "uint256"]] as const;
const activationSuffix = [["assignmentHash", "bytes32"], ["primaryPolicyHash", "bytes32"], ["primaryPolicyMode", "uint8"], ["artist", "address"], ["nonce", "bytes32"], ["deadline", "uint64"]] as const;
const immediateFields = [
  ["saleId", "bytes32"], ["saleConfigHash", "bytes32"], ["payer", "address"], ["executor", "address"],
  ["recipient", "address"], ["artist", "address"], ["tokenDataHash", "bytes32"], ["mintCommitment", "bytes32"],
  ["executionNonce", "uint256"], ["nonce", "bytes32"], ["deadline", "uint64"], ["expectedPrimaryPolicyHash", "bytes32"],
] as const;
const schemes = {
  nativeFixedPriceSale: { name: "6529StreamNativeFixedPriceSaleAdapter", primaryType: "NativeSaleAuthorization", fields: immediateFields },
  nativePriceProgram: { name: "6529StreamNativePricePrograms", primaryType: "NativePriceProgramAuthorization", fields: [...immediateFields, ["unitPrice", "uint256"]] },
  tokenProfileCustodyActivation: { name: "6529StreamTokenProfileCustodyAllowCurrent", primaryType: "TokenProfileCustodyActivation", fields: [...activationPrefix, ...activationSuffix] },
  custodyRightsActivation: { name: "6529StreamCustodyRightsAllowCurrent", primaryType: "CustodyRightsActivation", fields: [...activationPrefix, ["rightsMode", "uint8"], ...activationSuffix] },
  nativeAuctionCreation: { name: "6529StreamNativeEnglishAuction", primaryType: "NativeAuctionCreation", fields: [
    ["configHash", "bytes32"], ["artist", "address"], ["nonce", "bytes32"], ["deadline", "uint64"],
  ] },
  nativeAuctionBid: { name: "6529StreamNativeEnglishAuction", primaryType: "NativeAuctionBid", fields: [
    ["auctionId", "bytes32"], ["configHash", "bytes32"], ["payer", "address"],
    ["executor", "address"], ["deliverTo", "address"], ["amount", "uint256"],
    ["maxRevealFee", "uint256"], ["nonce", "bytes32"], ["deadline", "uint64"], ["finalizeBy", "uint64"],
  ] },
  nativeCustodyAcquisition: { name: "6529StreamNativeCustodyAuction", primaryType: "NativeCustodyAcquisition", fields: custodyFields },
  preparedNativeCustodyAcquisition: { name: "6529StreamPreparedNativeCustodyAuction", primaryType: "PreparedNativeCustodyAcquisition", fields: custodyFields },
} as const;

/** Encoding only: check the selected current house getter and live coordinates before signing. */
export function currentTypedData<K extends CurrentSigningKind>(kind: K, chainId: bigint, house: Address, message: CurrentSigningMessages[K]): SigningPayload<CurrentSigningMessages[K]> {
  if (typeof kind !== "string" || !Object.hasOwn(schemes, kind)) throw new Error("Unknown current signing kind");
  const scheme = schemes[kind];
  return buildSigningPayload(chainId, house, scheme.name, scheme.primaryType,
    scheme.fields.map(([name, type]) => ({ name, type })), message);
}

export const nativeAuctionCreationTypedData = (chainId: bigint, house: Address, message: NativeAuctionCreationAuthorization) => currentTypedData("nativeAuctionCreation", chainId, house, message);
export const nativeAuctionBidTypedData = (chainId: bigint, house: Address, message: NativeAuctionBidAuthorization) => currentTypedData("nativeAuctionBid", chainId, house, message);
export const nativeCustodyAcquisitionTypedData = (chainId: bigint, house: Address, message: NativeCustodyAcquisitionAuthorization) => currentTypedData("nativeCustodyAcquisition", chainId, house, message);
export const preparedNativeCustodyAcquisitionTypedData = (chainId: bigint, house: Address, message: PreparedNativeCustodyAcquisitionAuthorization) => currentTypedData("preparedNativeCustodyAcquisition", chainId, house, message);

export const tokenProfileCustodyActivationTypedData = (chainId: bigint, house: Address, message: TokenProfileCustodyActivationAuthorization) => currentTypedData("tokenProfileCustodyActivation", chainId, house, message);
export const custodyRightsActivationTypedData = (chainId: bigint, house: Address, message: CustodyRightsActivationAuthorization) => currentTypedData("custodyRightsActivation", chainId, house, message);

export const nativeFixedPriceSaleTypedData = (chainId: bigint, adapter: Address, message: NativeFixedPriceSaleAuthorization) => currentTypedData("nativeFixedPriceSale", chainId, adapter, message);
export const nativePriceProgramTypedData = (chainId: bigint, adapter: Address, message: NativePriceProgramAuthorization) => currentTypedData("nativePriceProgram", chainId, adapter, message);

/** Explicit current JSON boundary; uints are canonical decimal strings, never JSON numbers. */
export function currentTypedDataFromJSON(input: unknown): SigningPayload<CurrentSigningMessages[CurrentSigningKind]> {
  if (input === null || typeof input !== "object" || Array.isArray(input)) throw new Error("Expected a current signing request object");
  const request = input as Record<string, unknown>;
  if (Object.keys(request).sort().join(",") !== "chainId,kind,message,verifyingContract") throw new Error("Expected kind, chainId, verifyingContract and message only");
  const kind = request.kind as CurrentSigningKind;
  if (typeof kind !== "string" || !Object.hasOwn(schemes, kind)) throw new Error("Unknown current signing kind");
  if (typeof request.chainId !== "string" || !/^(0|[1-9][0-9]*)$/.test(request.chainId)) throw new Error("chainId must be a decimal string");
  if (request.message === null || typeof request.message !== "object" || Array.isArray(request.message)) throw new Error("message must be an object");
  const message = { ...request.message } as Record<string, unknown>;
  for (const [field, type] of schemes[kind].fields) {
    if (!type.startsWith("uint")) continue;
    const value = message[field];
    if (typeof value !== "string" || !/^(0|[1-9][0-9]*)$/.test(value)) throw new Error(`${field} must be a decimal string`);
    message[field] = BigInt(value);
  }
  return currentTypedData(kind, BigInt(request.chainId), request.verifyingContract as Address, message as unknown as CurrentSigningMessages[CurrentSigningKind]);
}
