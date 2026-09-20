import { getAddress, isHexString, TypedDataEncoder, type TypedDataField } from "ethers";
import type { Address, Hex } from "./generated/contracts.js";
import type { SigningPayload } from "./signing.js";

function uint(value: unknown, bits: number, field: string): bigint {
  if (typeof value !== "bigint" || value < 0n || value >= (1n << BigInt(bits))) {
    throw new Error(`${field} must be a nonnegative bigint fitting uint${bits}`);
  }
  return value;
}

/** Explicit per-field bounds for the supported one-dimensional EIP-712 arrays. */
export type SigningArrayBounds = Readonly<Record<string, { readonly minimum: number; readonly maximum: number }>>;

function scalar(type: string, value: unknown, name: string): unknown {
  if (type === "address") {
    if (typeof value !== "string") throw new Error(`${name} must be an address string`);
    return getAddress(value);
  }
  if (type === "bytes32") {
    if (typeof value !== "string" || !isHexString(value, 32)) throw new Error(`${name} must contain exactly 32 bytes`);
    return value;
  }
  if (type === "bool") {
    if (typeof value !== "boolean") throw new Error(`${name} must be boolean`);
    return value;
  }
  if (/^uint(?:8|16|24|32|40|48|56|64|72|80|88|96|104|112|120|128|136|144|152|160|168|176|184|192|200|208|216|224|232|240|248|256)$/.test(type)) {
    return uint(value, Number(type.slice(4)), name);
  }
  throw new Error(`Unsupported signing field ${type}`);
}

/** Shared strict encoding for explicitly versioned signing schemas. */
export function buildSigningPayload<T extends object>(chainId: bigint, verifyingContract: Address, name: string, primaryType: string, fields: readonly TypedDataField[], message: T, arrayBounds: SigningArrayBounds = {}): SigningPayload<T> {
  uint(chainId, 256, "chainId");
  if (chainId === 0n) throw new Error("chainId must be nonzero");
  if (message === null || typeof message !== "object" || Array.isArray(message)) throw new Error("message must be an object");
  const keys = Object.keys(message);
  if (keys.length !== fields.length || keys.some(key => !fields.some(field => field.name === key))) {
    throw new Error(`Expected exactly the ${primaryType} fields`);
  }
  const normalized: Record<string, unknown> = {};
  if (!arrayBounds || typeof arrayBounds !== "object" || Array.isArray(arrayBounds)) throw new Error("Expected signing array bounds");
  for (const name of Object.keys(arrayBounds)) {
    if (!fields.some(field => field.name === name && (field.type === "address[]" || field.type === "bytes32[]"))) {
      throw new Error(`Unexpected array bounds for ${name}`);
    }
  }
  for (const field of fields) {
    const value = (message as unknown as Record<string, unknown>)[field.name];
    if (field.type === "address[]" || field.type === "bytes32[]") {
      const bounds = Object.hasOwn(arrayBounds, field.name) ? arrayBounds[field.name] : undefined;
      if (!bounds || !Number.isSafeInteger(bounds.minimum) || !Number.isSafeInteger(bounds.maximum)
          || bounds.minimum < 0 || bounds.maximum < bounds.minimum) throw new Error(`${field.name} requires explicit valid array bounds`);
      if (!Array.isArray(value) || value.length < bounds.minimum || value.length > bounds.maximum) throw new Error(`${field.name} array length is outside its bounds`);
      if (Reflect.ownKeys(value).length !== value.length + 1) throw new Error(`${field.name} must be a dense array without extra properties`);
      normalized[field.name] = Object.freeze(Array.from(value, (item, index) => scalar(field.type.slice(0, -2), item, `${field.name}[${index}]`)));
    } else normalized[field.name] = scalar(field.type, value, field.name);
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
