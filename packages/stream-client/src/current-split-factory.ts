import { AbiCoder, Interface, TypedDataEncoder, ZeroAddress, getAddress, getCreate2Address, id, isHexString, keccak256 } from "ethers";
import type { Address, Hex } from "./generated/contracts.js";
import type { UnsignedCall } from "./client.js";
import { buildSigningPayload } from "./signing-payload.js";
import type { SigningPayload } from "./signing.js";

export interface SplitEntry { readonly account: Address; readonly sharePpm: bigint; readonly labelId: Hex }
/** Complete original profile preimage context. Code hashes belong to the actual factory. */
export interface SplitFactoryContext {
  readonly chainId: bigint; readonly factory: Address; readonly profileDomain: Hex; readonly schemaVersion: bigint;
  readonly walletVersion: bigint; readonly initCodeHash: Hex; readonly runtimeCodeHash: Hex; readonly assetPolicyRegistry: Address;
}
export interface SplitWalletImplementationPin { readonly address: Address; readonly codeHash: Hex }
/** Supplied runtime pins. Normalization does not authenticate RPC reads or deployed code. */
export interface SplitFactorySnapshot {
  readonly context: SplitFactoryContext; readonly factoryCodeHash: Hex; readonly assetPolicyCodeHash: Hex;
  readonly implementation: SplitWalletImplementationPin | null;
}
/** A canonical profile and predicted wallet; neither registration nor deployment is asserted. */
export interface SplitProfile {
  readonly context: SplitFactoryContext; readonly entries: readonly SplitEntry[]; readonly metadataURIHash: Hex;
  readonly entriesHash: Hex; readonly accounts: readonly Address[]; readonly aggregateSharePpm: readonly bigint[];
  readonly profileId: Hex; readonly wallet: Address;
}
export interface SplitFactoryRequest {
  readonly kind: "register-profile" | "create-profile" | "deploy-wallet";
  readonly profile: SplitProfile;
}
export interface PreparedSplitFactoryCall {
  readonly snapshot: SplitFactorySnapshot; readonly caller: Address; readonly request: SplitFactoryRequest;
  readonly call: UnsignedCall; readonly predictionOnly: true;
}
export interface SplitWalletSigningDomain {
  readonly name: "6529StreamSplitWallet"; readonly version: "1"; readonly chainId: bigint; readonly verifyingContract: Address;
}
export interface SplitWalletReleaseAuthorization {
  readonly asset: Address; readonly account: Address; readonly recipient: Address;
  readonly releasableSnapshot: bigint; readonly nonce: Hex; readonly deadline: bigint;
}
export interface SplitWalletReleaseRevocation { readonly account: Address; readonly nonce: Hex; readonly deadline: bigint }

export const SPLIT_WALLET_IMPLEMENTATION_INTERFACE_ID = "0x507ff672" as Hex;
export const SPLIT_PROFILE_DOMAIN = id("6529STREAM_SPLIT_PROFILE_V1") as Hex;
export const SPLIT_MAX_ENTRIES = 64;
export const SPLIT_SHARE_DENOMINATOR_PPM = 1_000_000n;
const coder = AbiCoder.defaultAbiCoder(), entryTuple = "tuple(address account,uint32 sharePpm,bytes32 labelId)[]";
const factoryAbi = new Interface([
  `function registerProfile(${entryTuple},bytes32) returns(bytes32,address)`,
  `function createProfile(${entryTuple},bytes32) returns(bytes32,address)`,
  "function deployWallet(bytes32) returns(address)",
]);
const contextKeys = ["chainId", "factory", "profileDomain", "schemaVersion", "walletVersion", "initCodeHash", "runtimeCodeHash", "assetPolicyRegistry"];
function exact(value: unknown, keys: readonly string[], label: string): void {
  if (value === null || typeof value !== "object" || Array.isArray(value)
    || Object.keys(value).sort().join(",") !== [...keys].sort().join(",")) throw Error(`${label} contains missing or unknown properties`);
}
function uint(value: unknown, bits: number, label: string, positive = false): bigint {
  if (typeof value !== "bigint" || value < (positive ? 1n : 0n) || value >= (1n << BigInt(bits))) throw Error(`${label} must be ${positive ? "positive " : ""}uint${bits} bigint`);
  return value;
}
function address(value: unknown): Address {
  if (typeof value !== "string") throw Error("Expected address"); const result = getAddress(value) as Address;
  if (result === ZeroAddress) throw Error("Expected nonzero address"); return result;
}
function hash(value: unknown, nonzero = false): Hex {
  if (typeof value !== "string" || !isHexString(value, 32) || (nonzero && BigInt(value) === 0n)) throw Error(`Expected ${nonzero ? "nonzero " : ""}bytes32`);
  return value.toLowerCase() as Hex;
}
function canonical(value: unknown): string {
  return JSON.stringify(value, (_, item: unknown) => typeof item === "bigint" ? { uint: item.toString() }
    : item !== null && typeof item === "object" && !Array.isArray(item) ? Object.fromEntries(Object.entries(item).sort(([a], [b]) => a.localeCompare(b))) : item);
}
/** Exact source-defined 52-byte variant; this is not the standard 45-byte ERC-1167 runtime. */
export function splitWalletCloneRuntime(implementation: Address): Hex {
  const target = address(implementation).slice(2).toLowerCase();
  return `0x3615603257363d3d373d3d3d363d73${target}5af43d82803e903d91603057fd5bf35b00`;
}
/** Ten-byte copy/return prefix followed by the exact 52-byte runtime. */
export function splitWalletCloneInitCode(implementation: Address): Hex {
  return `0x3d603480600a3d3981f3${splitWalletCloneRuntime(implementation).slice(2)}`;
}
export function splitWalletCloneHashes(implementation: Address): { readonly initCodeHash: Hex; readonly runtimeCodeHash: Hex } {
  return Object.freeze({ initCodeHash: keccak256(splitWalletCloneInitCode(implementation)) as Hex, runtimeCodeHash: keccak256(splitWalletCloneRuntime(implementation)) as Hex });
}
/** Caller supplies observed bytes; no code is fetched or implementation runtime authenticated here. */
export function verifySplitWalletCloneRuntime(implementation: Address, runtime: Hex): Hex {
  if (!isHexString(runtime, 52) || runtime.toLowerCase() !== splitWalletCloneRuntime(implementation)) throw Error("Wallet runtime differs from the exact pinned 52-byte clone");
  return keccak256(runtime) as Hex;
}
export function normalizeSplitFactoryContext(input: SplitFactoryContext): SplitFactoryContext {
  exact(input, contextKeys, "Split factory context");
  const out = { chainId: uint(input.chainId, 256, "Chain ID", true), factory: address(input.factory), profileDomain: hash(input.profileDomain),
    schemaVersion: uint(input.schemaVersion, 16, "Schema version", true), walletVersion: uint(input.walletVersion, 16, "Wallet version", true),
    initCodeHash: hash(input.initCodeHash, true), runtimeCodeHash: hash(input.runtimeCodeHash, true), assetPolicyRegistry: address(input.assetPolicyRegistry) };
  if (out.profileDomain !== SPLIT_PROFILE_DOMAIN || out.schemaVersion !== 1n) throw Error("Unsupported original split profile domain or schema");
  return Object.freeze(out);
}
export function normalizeSplitFactorySnapshot(input: SplitFactorySnapshot): SplitFactorySnapshot {
  exact(input, ["context", "factoryCodeHash", "assetPolicyCodeHash", "implementation"], "Split factory snapshot");
  const context = normalizeSplitFactoryContext(input.context);
  let implementation: SplitWalletImplementationPin | null = null;
  if (context.walletVersion === 4n) {
    exact(input.implementation, ["address", "codeHash"], "Version-4 implementation pin");
    implementation = Object.freeze({ address: address(input.implementation!.address), codeHash: hash(input.implementation!.codeHash, true) });
    const expected = splitWalletCloneHashes(implementation.address);
    if (context.initCodeHash !== expected.initCodeHash || context.runtimeCodeHash !== expected.runtimeCodeHash) throw Error("Factory code hashes differ from its pinned version-4 implementation");
  } else if (context.walletVersion !== 3n || input.implementation !== null) {
    throw Error("Factory snapshot supports original version3 or pinned version4 only");
  }
  return Object.freeze({ context, factoryCodeHash: hash(input.factoryCodeHash, true), assetPolicyCodeHash: hash(input.assetPolicyCodeHash, true), implementation });
}
/** Original sorting by account, label, then share; duplicates by account+label always reject. */
export function canonicalizeSplitEntries(input: readonly SplitEntry[]): readonly SplitEntry[] {
  if (!Array.isArray(input) || input.length === 0 || input.length > SPLIT_MAX_ENTRIES) throw Error("Split profiles require 1..64 entries");
  const rows = input.map(row => {
    exact(row, ["account", "sharePpm", "labelId"], "Split entry");
    const sharePpm = uint(row.sharePpm, 32, "Split share", true);
    if (sharePpm > SPLIT_SHARE_DENOMINATOR_PPM) throw Error("Split share exceeds 1000000ppm");
    return Object.freeze({ account: address(row.account), sharePpm, labelId: hash(row.labelId) });
  });
  rows.sort((a, b) => {
    for (const key of ["account", "labelId", "sharePpm"] as const) { const x = BigInt(a[key]), y = BigInt(b[key]); if (x !== y) return x < y ? -1 : 1; }
    return 0;
  });
  let total = 0n;
  for (let index = 0; index < rows.length; index++) {
    const row = rows[index]!, previous = rows[index - 1];
    if (previous && row.account === previous.account && row.labelId === previous.labelId) throw Error("Duplicate split account and label");
    total += row.sharePpm;
  }
  if (total !== SPLIT_SHARE_DENOMINATOR_PPM) throw Error("Split shares must total exactly 1000000ppm");
  return Object.freeze(rows);
}
export function splitEntriesHash(entries: readonly SplitEntry[]): Hex {
  return keccak256(coder.encode([entryTuple], [canonicalizeSplitEntries(entries)])) as Hex;
}
function profileIdentity(c: SplitFactoryContext, entriesHash: Hex, metadataURIHash: Hex): Hex {
  return keccak256(coder.encode(["bytes32", "uint256", "address", "uint16", "uint16", "bytes32", "bytes32", "address", "bytes32", "bytes32"],
    [c.profileDomain, c.chainId, c.factory, c.schemaVersion, c.walletVersion, c.initCodeHash, c.runtimeCodeHash, c.assetPolicyRegistry, entriesHash, metadataURIHash])) as Hex;
}
/** The complete unchanged profile preimage; no hardcoded global wallet-version/code-hash substitution. */
export function splitProfileId(context: SplitFactoryContext, entries: readonly SplitEntry[], metadataURIHash: Hex): Hex {
  return profileIdentity(normalizeSplitFactoryContext(context), splitEntriesHash(entries), hash(metadataURIHash));
}
/** Original CREATE2 formula. A predicted address does not prove registration or wallet initialization. */
export function predictSplitWallet(context: SplitFactoryContext, profileId: Hex): Address {
  const c = normalizeSplitFactoryContext(context); return getCreate2Address(c.factory, hash(profileId), c.initCodeHash) as Address;
}
export function prepareSplitProfile(context: SplitFactoryContext, input: readonly SplitEntry[], metadataURIHash: Hex): SplitProfile {
  const c = normalizeSplitFactoryContext(context), entries = canonicalizeSplitEntries(input), metadata = hash(metadataURIHash);
  const entriesHash = keccak256(coder.encode([entryTuple], [entries])) as Hex, profileId = profileIdentity(c, entriesHash, metadata);
  const accounts: Address[] = [], aggregateSharePpm: bigint[] = [];
  for (const row of entries) {
    if (accounts.at(-1) !== row.account) { accounts.push(row.account); aggregateSharePpm.push(row.sharePpm); }
    else aggregateSharePpm[aggregateSharePpm.length - 1] = aggregateSharePpm.at(-1)! + row.sharePpm;
  }
  return Object.freeze({ context: c, entries, metadataURIHash: metadata, entriesHash, accounts: Object.freeze(accounts),
    aggregateSharePpm: Object.freeze(aggregateSharePpm), profileId, wallet: predictSplitWallet(c, profileId) });
}
export function normalizeSplitProfile(input: SplitProfile): SplitProfile {
  exact(input, ["context", "entries", "metadataURIHash", "entriesHash", "accounts", "aggregateSharePpm", "profileId", "wallet"], "Split profile");
  const rebuilt = prepareSplitProfile(input.context, input.entries, input.metadataURIHash);
  if (canonical(input) !== canonical(rebuilt)) throw Error("Split profile differs from canonical entries, aggregates or prediction"); return rebuilt;
}
export function prepareSplitFactoryCall(snapshot: SplitFactorySnapshot, caller: Address, request: SplitFactoryRequest): PreparedSplitFactoryCall {
  const saved = normalizeSplitFactorySnapshot(snapshot), actor = address(caller);
  exact(request, ["kind", "profile"], "Split factory request");
  if (!["register-profile", "create-profile", "deploy-wallet"].includes(request.kind)) throw Error("Unsupported split factory request");
  const profile = normalizeSplitProfile(request.profile);
  if (canonical(profile.context) !== canonical(saved.context)) throw Error("Profile context differs from the reviewed factory snapshot");
  const method = request.kind === "register-profile" ? "registerProfile" : request.kind === "create-profile" ? "createProfile" : "deployWallet";
  const args = request.kind === "deploy-wallet" ? [profile.profileId] : [profile.entries, profile.metadataURIHash];
  return Object.freeze({ snapshot: saved, caller: actor, request: Object.freeze({ kind: request.kind, profile }),
    call: Object.freeze({ to: saved.context.factory, value: 0n, data: factoryAbi.encodeFunctionData(method, args) as Hex }), predictionOnly: true });
}
export function normalizeSplitFactoryCall(input: PreparedSplitFactoryCall): PreparedSplitFactoryCall {
  exact(input, ["snapshot", "caller", "request", "call", "predictionOnly"], "Prepared split factory call");
  const rebuilt = prepareSplitFactoryCall(input.snapshot, input.caller, input.request);
  if (canonical(input) !== canonical(rebuilt)) throw Error("Split factory call differs from exact request reconstruction"); return rebuilt;
}
/** Original release/revocation domain version1 at the individual predicted wallet, even for wallet version4. */
export function splitWalletSigningDomain(profile: SplitProfile): SplitWalletSigningDomain {
  const p = normalizeSplitProfile(profile);
  return Object.freeze({ name: "6529StreamSplitWallet", version: "1", chainId: p.context.chainId, verifyingContract: p.wallet });
}
export function splitWalletDomainSeparator(profile: SplitProfile): Hex {
  return TypedDataEncoder.hashDomain(splitWalletSigningDomain(profile)) as Hex;
}
function signingProfile(snapshot: SplitFactorySnapshot, input: SplitProfile): SplitProfile {
  const saved = normalizeSplitFactorySnapshot(snapshot), profile = normalizeSplitProfile(input);
  if (canonical(saved.context) !== canonical(profile.context)) throw Error("Signing profile differs from the reviewed factory context");
  return profile;
}
/** Original wallet-domain release fields. This prepares no transfer, signature or live amount claim. */
export function splitWalletReleaseTypedData(snapshot: SplitFactorySnapshot, profile: SplitProfile, message: SplitWalletReleaseAuthorization): SigningPayload<SplitWalletReleaseAuthorization> {
  const saved = signingProfile(snapshot, profile);
  exact(message, ["asset", "account", "recipient", "releasableSnapshot", "nonce", "deadline"], "Release authorization");
  address(message.account); address(message.recipient);
  return buildSigningPayload(saved.context.chainId, saved.wallet, "6529StreamSplitWallet", "StreamReleaseAuthorization", [
    { name: "asset", type: "address" }, { name: "account", type: "address" }, { name: "recipient", type: "address" },
    { name: "releasableSnapshot", type: "uint256" }, { name: "nonce", type: "bytes32" }, { name: "deadline", type: "uint64" },
  ], message);
}
/** Original signer-scoped revocation; zero bytes32 nonce remains valid and no balance is invented. */
export function splitWalletReleaseRevocationTypedData(snapshot: SplitFactorySnapshot, profile: SplitProfile, message: SplitWalletReleaseRevocation): SigningPayload<SplitWalletReleaseRevocation> {
  const saved = signingProfile(snapshot, profile);
  exact(message, ["account", "nonce", "deadline"], "Release revocation"); address(message.account);
  return buildSigningPayload(saved.context.chainId, saved.wallet, "6529StreamSplitWallet", "StreamReleaseAuthorizationRevocation", [
    { name: "account", type: "address" }, { name: "nonce", type: "bytes32" }, { name: "deadline", type: "uint64" },
  ], message);
}
