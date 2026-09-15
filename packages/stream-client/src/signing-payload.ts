import { getAddress, isHexString, TypedDataEncoder, type TypedDataField } from "ethers";
import type { Address, Hex } from "./generated/contracts.js";
import type { SigningPayload } from "./signing.js";

function uint(value: unknown, bits: number, field: string): bigint {
  if (typeof value !== "bigint" || value < 0n || value >= (1n << BigInt(bits))) {
    throw new Error(`${field} must be a nonnegative bigint fitting uint${bits}`);
  }
  return value;
}

/** Shared strict encoding for explicitly versioned signing schemas. */
export function buildSigningPayload<T extends object>(chainId: bigint, verifyingContract: Address, name: string, primaryType: string, fields: readonly TypedDataField[], message: T): SigningPayload<T> {
  uint(chainId, 256, "chainId");
  if (chainId === 0n) throw new Error("chainId must be nonzero");
  if (message === null || typeof message !== "object" || Array.isArray(message)) throw new Error("message must be an object");
  const keys = Object.keys(message);
  if (keys.length !== fields.length || keys.some(key => !fields.some(field => field.name === key))) {
    throw new Error(`Expected exactly the ${primaryType} fields`);
  }
  const normalized: Record<string, unknown> = {};
  for (const field of fields) {
    const value = (message as unknown as Record<string, unknown>)[field.name];
    if (field.type === "address") {
      if (typeof value !== "string") throw new Error(`${field.name} must be an address string`);
      normalized[field.name] = getAddress(value);
    }
    else if (field.type === "bytes32") {
      if (typeof value !== "string" || !isHexString(value, 32)) throw new Error(`${field.name} must contain exactly 32 bytes`);
      normalized[field.name] = value;
    } else if (field.type.startsWith("uint")) normalized[field.name] = uint(value, Number(field.type.slice(4)), field.name);
    else throw new Error(`Unsupported signing field ${field.type}`);
  }
  const domain = { name, version: "1", chainId, verifyingContract: getAddress(verifyingContract) };
  const types = { [primaryType]: fields.map(field => ({ ...field })) };
  for (const field of types[primaryType]!) Object.freeze(field);
  Object.freeze(types[primaryType]);
  Object.freeze(types);
  // Copy caller fields so later mutations of the input cannot silently alter the reviewed payload.
  const copy = Object.freeze(normalized) as unknown as T;
  return Object.freeze({ domain: Object.freeze(domain), types, primaryType, message: copy, digest: TypedDataEncoder.hash(domain, types, copy) as Hex });
}
