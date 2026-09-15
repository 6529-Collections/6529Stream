import { TypedDataEncoder, type TypedDataDomain, type TypedDataField } from "ethers";
import { signingFields, type Address, type ContractFunctions, type Hex } from "./generated/contracts.js";

import { buildSigningPayload } from "./signing-payload.js";

export type NativeSaleAuthorization = ContractFunctions["nativeSale"]["authorizationDigest"]["args"][0];
export type ERC20SaleAuthorization = ContractFunctions["erc20Sale"]["authorizationDigest"]["args"][0];
export type PaymentIntent = ContractFunctions["erc20Sale"]["paymentIntentDigest"]["args"][0];
export type PaymentIntentRevocation = { readonly payer: Address; readonly nonce: Hex; readonly deadline: bigint };
export type ArtistAcceptance = { readonly core: Address; readonly collectionId: bigint; readonly nominationHash: Hex; readonly nonce: bigint; readonly deadline: bigint };
export type AuctionAuthorization = ContractFunctions["auction"]["authorizationDigest"]["args"][0];
export type SigningKind = "nativeSale" | "erc20Sale" | "paymentIntent" | "paymentIntentRevocation" | "artistAcceptance" | "auction";
export interface SigningMessages {
  nativeSale: NativeSaleAuthorization; erc20Sale: ERC20SaleAuthorization; paymentIntent: PaymentIntent;
  paymentIntentRevocation: PaymentIntentRevocation; artistAcceptance: ArtistAcceptance; auction: AuctionAuthorization;
}
export interface SigningPayload<T extends object> {
  readonly domain: TypedDataDomain;
  readonly types: Record<string, TypedDataField[]>;
  readonly primaryType: string;
  readonly message: T;
  readonly digest: Hex;
}
const schemes = {
  nativeSale: ["6529StreamFixedPriceSale", "SaleAuthorization"],
  erc20Sale: ["6529StreamPaymentIntentVerifier", "ERC20SaleAuthorization"],
  paymentIntent: ["6529StreamPaymentIntentVerifier", "StreamPaymentIntent"],
  paymentIntentRevocation: ["6529StreamPaymentIntentVerifier", "StreamPaymentIntentRevocation"],
  artistAcceptance: ["6529StreamCollectionArtist", "CollectionArtistAcceptance"],
  auction: ["6529StreamEnglishAuction", "AuctionAuthorization"],
} as const;

/** Pure payload construction. This verifies encoding, not live nonce, consent, balance or policy. */
export function typedData<K extends SigningKind>(kind: K, chainId: bigint, verifyingContract: Address, message: SigningMessages[K]): SigningPayload<SigningMessages[K]> {
  const scheme = schemes[kind];
  if (!scheme) throw new Error("Unknown signing kind");
  const [name, primaryType] = scheme;
  return buildSigningPayload(chainId, verifyingContract, name, primaryType, signingFields[primaryType], message);
}

export const nativeSaleTypedData = (chainId: bigint, adapter: Address, message: NativeSaleAuthorization) => typedData("nativeSale", chainId, adapter, message);
export const erc20SaleTypedData = (chainId: bigint, adapter: Address, message: ERC20SaleAuthorization) => typedData("erc20Sale", chainId, adapter, message);
export const paymentIntentTypedData = (chainId: bigint, adapter: Address, message: PaymentIntent) => typedData("paymentIntent", chainId, adapter, message);
export const paymentIntentRevocationTypedData = (chainId: bigint, adapter: Address, message: PaymentIntentRevocation) => typedData("paymentIntentRevocation", chainId, adapter, message);
export const artistAcceptanceTypedData = (chainId: bigint, registry: Address, message: ArtistAcceptance) => typedData("artistAcceptance", chainId, registry, message);
export const auctionTypedData = (chainId: bigint, house: Address, message: AuctionAuthorization) => typedData("auction", chainId, house, message);

/** JSON boundary: uints are decimal strings, never JSON numbers (which may lose precision). */
export function typedDataFromJSON(input: unknown): SigningPayload<SigningMessages[SigningKind]> {
  if (input === null || typeof input !== "object" || Array.isArray(input)) throw new Error("Expected a signing request object");
  const request = input as Record<string, unknown>;
  if (Object.keys(request).sort().join(",") !== "chainId,kind,message,verifyingContract") throw new Error("Expected kind, chainId, verifyingContract and message only");
  const kind = request.kind as SigningKind;
  if (!Object.hasOwn(schemes, kind)) throw new Error("Unknown signing kind");
  if (typeof request.chainId !== "string" || !/^(0|[1-9][0-9]*)$/.test(request.chainId)) throw new Error("chainId must be a decimal string");
  if (request.message === null || typeof request.message !== "object" || Array.isArray(request.message)) throw new Error("message must be an object");
  const message = { ...request.message } as Record<string, unknown>;
  for (const field of signingFields[schemes[kind][1]]) {
    if (!field.type.startsWith("uint")) continue;
    const value = message[field.name];
    if (typeof value !== "string" || !/^(0|[1-9][0-9]*)$/.test(value)) throw new Error(`${field.name} must be a decimal string`);
    message[field.name] = BigInt(value);
  }
  return typedData(kind, BigInt(request.chainId), request.verifyingContract as Address, message as unknown as SigningMessages[SigningKind]);
}

/** Bigints become decimal strings; compatible with JSON wallet typed-data requests. */
export function toJSON(value: unknown): string {
  return JSON.stringify(value, (_, item: unknown) => typeof item === "bigint" ? item.toString() : item, 2);
}

/** eth_signTypedData_v4 representation, including the EIP712Domain fields required by JSON-RPC wallets. */
export function walletTypedData<T extends object>(payload: SigningPayload<T>): ReturnType<typeof TypedDataEncoder.getPayload> {
  return TypedDataEncoder.getPayload(payload.domain, payload.types, payload.message);
}
