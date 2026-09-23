import {
  AbiCoder,
  Interface,
  ParamType,
  ZeroAddress,
  ZeroHash,
  getAddress,
  id,
  isHexString,
  keccak256,
} from "ethers";
import type { Provider } from "ethers";
import type { Address, Hex } from "./generated/contracts.js";
import type { UnsignedCall } from "./binding.js";
import * as escrow from "./current-revenue-escrow.js";
import { requireSafeExecution } from "./safe.js";
import type { MintFallbackGovernanceWindow } from "./current-mint-fallback.js";

// Literal original ABI107 fragments; direct reads do not prove nested gas admission.
const abi = new Interface([
  "function owner() view returns (address)",
  "function splitFactory() view returns (address)",
  "function factoryCodeHash() view returns (bytes32)",
  "function walletCodeHash() view returns (bytes32)",
  "function assetPolicyRegistry() view returns (address)",
  "function registryCodeHash() view returns (bytes32)",
  "function governanceAuthority() view returns (address)",
  "function revenueRuntimeRegistry() view returns (address registry)",
  "function revenueRuntimeRegistryCodeHash() view returns (bytes32 codeHash)",
  "function escrowOwed(bytes32 revenueClass, bytes32 profileId, address wallet, address asset) view returns (uint256)",
  "function escrowCreditIdentity(bytes32 revenueClass, bytes32 profileId, address wallet, address asset) view returns (address factory, bytes32 factoryHash, bytes32 runtimeHash)",
  "function totalOwed(address) view returns (uint256)",
  "function surplus(address asset) view returns (uint256)",
  "function gasParameter(bytes32 parameterId) view returns (uint256 value)",
  "function escrowRecoveryManifest(bytes32 contentHash) view returns (bytes canonicalDocument, uint64 publishedAt)",
  "function escrowRecoveryAffectedAccountCount(bytes32 contentHash) view returns (uint256)",
  "function escrowRecoveryAffectedAccountAt(bytes32 contentHash, uint256 index) view returns (address)",
  "function escrowRecoveryRecord(bytes32 recoveryId) view returns ((uint8 status, (bytes32 revenueClass, bytes32 profileId, address wallet, address asset) creditKey, address storedFactory, address successorWallet, bytes32 successorProfileId, bytes32 successorRuntimeCodeHash, uint256 expectedAmount, (string uri, bytes32 uriHash, bytes32 contentHash, bytes32 schemaId, bytes32 canonicalizationHash) recoveryManifest, uint64 executeAfter, bytes32 reasonHash, string reasonURI))",
  "function escrowRecoveryConsentRecorded(bytes32 recoveryId, address account) view returns (bool)",
  "function isEscrowRecoveryConsentNonceUsed(address account, bytes32 nonce) view returns (bool)",
  "function escrowRecoveryConsentDigest(address account, bytes32 recoveryId, bytes32 nonce, uint64 deadline) view returns (bytes32)",
  "function escrowRecoveryTransitionHashes((bytes32 revenueClass, bytes32 profileId, address wallet, address asset) creditKey, address successorWallet, bytes32 successorProfileId, bytes32 successorRuntimeCodeHash, uint256 expectedAmount, (string uri, bytes32 uriHash, bytes32 contentHash, bytes32 schemaId, bytes32 canonicalizationHash) recoveryManifest, uint64 executeAfter, bytes32 reasonHash, string reasonURI) view returns (bytes32 recoveryId, bytes32 scopeHash, bytes32 oldStateHash, bytes32 newStateHash)",
  "function escrowRecoveryCancellationHashes(bytes32 recoveryId, bytes32 reasonHash, string reasonURI) view returns (bytes32 scopeHash, bytes32 oldStateHash, bytes32 newStateHash)",
  "function escrowRecoveryTerminalHashes(bytes32 recoveryId) view returns (bytes32 scopeHash, bytes32 oldStateHash, bytes32 newStateHash)",
  "function factoryRecord(address factory) view returns ((uint8 status, bytes32 codeHash, bytes32 runtimeCodeHash, uint64 revision, bytes32 lastActionId, bytes32 incidentManifestHash))",
  "function runtimeRecord(bytes32 codeHash) view returns ((uint8 status, uint64 revision, bytes32 incidentManifestHash, bytes32 lastActionId))",
  "function profileExists(bytes32 profileId) view returns (bool)",
  "function walletFor(bytes32 profileId) view returns (address)",
  "function profileEntriesHash(bytes32 profileId) view returns (bytes32)",
  "function splitWalletRuntimeCodeHash() view returns (bytes32)",
  "function splitWalletExists(bytes32 profileId) view returns (bool)",
  "function supportsInterface(bytes4 interfaceId) pure returns (bool)",
  "function factory() view returns (address)",
  "function profileId() view returns (bytes32)",
  "function balanceOf(address account) view returns (uint256)",
  "function governanceNonce() view returns (uint256)",
  "function minimumDelay(uint8 actionClass) pure returns (uint64)",
  "function isProposer(address account) view returns (bool)",
  "function publishedCallData(bytes32 callDataKey) view returns (address)",
  "function governanceAction(bytes32 actionId) view returns ((uint8 status, uint8 actionClass, address target, uint256 value, bytes4 selector, bytes32 callHash, bytes32 scopeHash, bytes32 oldValueHash, bytes32 newValueHash, uint64 notBefore, uint64 expiresAfter, address proposer, address executor, address canceller, address vetoer, bytes32 reasonHash, string reasonURI, bytes32 manifestHash))",
  "function scheduledCallData(bytes32 actionId) view returns (bytes[])",
  "function scheduledCallDataPointer(bytes32 actionId) view returns (address)",
  "function governanceActionPolicyState() view returns (bytes32 candidateProfileHash, bytes32 catalogHash, uint256 entryCount, uint64 revision)",
  "function systemManifestBootstrapState() view returns (bool, bool, address, bytes32, address, bytes32, uint64, bytes32, uint256, bytes32, uint64, address, bytes32, address, bytes32, bytes32, uint256, bytes32, uint256, bytes32, bytes32, uint256, bytes32, uint256, address, address, bytes32, bytes32, uint256)",
  "function roleRegistry() view returns (address)",
  "function terminalFreezeGuardianConfigCommitment(bytes32 actionId) view returns (bytes32 commitment)",
  "function terminalFreezeVetoGuardianSet(bytes32 scopeHash) view returns (address roleRegistryAddress, bytes32 scopedRole, uint256 scopedHolderCount, bytes32 globalRole, uint256 globalHolderCount, uint64 vetoDeadline)",
  "function freezeSelectorConfig(address target, bytes4 selector) view returns (bool freeze, bytes32 targetCodeHash, uint64 revision, bytes32 stateHash)",
  "function tighteningCallConfig(address target, bytes4 selector) view returns (bool tightening, bytes32 targetCodeHash, uint64 revision, bytes32 stateHash)",
  "function isRoleRedundant(bytes32 role) view returns (bool)",
  "event EscrowFlushed(bytes32 indexed revenueClass, bytes32 indexed profileId, address indexed wallet, uint16 schemaVersion, address asset, uint256 amount, uint256 remainingOwed)",
  "event EscrowRecoveryCancelled(uint16 schemaVersion, bytes32 indexed recoveryId, bytes32 indexed revenueClass, bytes32 indexed profileId, bytes32 reasonHash, string reasonURI)",
  "event EscrowRecoveryConsentRecorded(uint16 schemaVersion, bytes32 indexed recoveryId, address indexed account, bytes32 nonce)",
  "event EscrowRecoveryConsentRevoked(uint16 schemaVersion, bytes32 indexed recoveryId, address indexed account)",
  "event EscrowRecoveryExecuted(uint16 schemaVersion, bytes32 indexed recoveryId, bytes32 indexed revenueClass, bytes32 indexed profileId, address oldWallet, address successorWallet, uint256 movedAmount, bytes32 recoveryManifestContentHash, bytes32 reasonHash, string reasonURI)",
  "event EscrowRecoveryManifestPublished(uint16 schemaVersion, bytes32 indexed contentHash, address indexed publisher, bytes32 indexed creditKeyHash, bytes32 oldEntriesHash, bytes32 successorEntriesHash, bytes32 affectedAccountsHash, uint8 route, uint64 publishedAt, bytes canonicalDocument)",
  "event EscrowRecoveryScheduled(uint16 schemaVersion, bytes32 indexed recoveryId, bytes32 indexed revenueClass, bytes32 indexed profileId, address wallet, address asset, address successorWallet, bytes32 successorProfileId, uint256 expectedAmount, bytes32 recoveryManifestContentHash, uint64 executeAfter, bytes32 reasonHash, string reasonURI)",
  "event EscrowRecoveryTerminalAuthorized(uint16 schemaVersion, bytes32 indexed recoveryId, bytes32 indexed actionId, bytes32 indexed manifestContentHash, uint64 authorizedAt)",
  "event GovernanceActionExecuted(uint16 schemaVersion, bytes32 indexed actionId, uint8 indexed actionClass, address indexed target, uint256 value, bytes4 selector, bytes32 callHash, bytes32 scopeHash, bytes32 oldValueHash, bytes32 newValueHash, address executor, bytes32 manifestHash)",
  "event GovernanceActionPolicyValidated(uint16 schemaVersion, bytes32 indexed actionId, uint8 indexed phase, bytes32 indexed candidateProfileHash, bytes32 catalogHash)",
  "event GovernanceActionScheduled(uint16 schemaVersion, bytes32 indexed actionId, uint8 indexed actionClass, address indexed target, uint256 value, bytes4 selector, bytes32 callHash, bytes32 scopeHash, bytes32 oldValueHash, bytes32 newValueHash, uint64 notBefore, uint64 expiresAfter, uint256 nonce, address proposer, bytes32 reasonHash, string reasonURI, bytes32 manifestHash)",
  "event GovernanceCallDataPublished(uint16 schemaVersion, bytes32 indexed callDataKey, address pointer, address publisher)",
  "event TerminalFreezeActionMembershipUpdated(uint16 schemaVersion, bytes32 indexed scopeHash, bytes32 indexed actionId, address indexed proposer, bool present, uint8 mutationCause, bool usesRootCapacity, uint64 vetoDeadline, uint256 rawIndex, uint256 remainingCount)",
  "event TerminalFreezeGuardianConfigCommitted(uint16 schemaVersion, bytes32 indexed actionId, bytes32 indexed commitment)",
]);

type Reader = Pick<Provider, "getNetwork" | "getBlock" | "getCode" | "getBalance" | "call">;
type ReceiptReader = Reader & Pick<Provider, "getTransaction" | "getTransactionReceipt">;
const coder = AbiCoder.defaultAbiCoder();
const ZERO = ZeroHash as Hex;
const MAX_BYTES = 2 * 1024 * 1024;
const callAbi = new Interface(escrow.CURRENT_REVENUE_ESCROW_ABI);
const safeAbi = new Interface([
  "function execTransaction(address to,uint256 value,bytes data,uint8 operation,uint256 safeTxGas,uint256 baseGas,uint256 gasPrice,address gasToken,address refundReceiver,bytes signatures) returns(bool success)",
  "event ExecutionSuccess(bytes32 txHash,uint256 payment)",
  "event ExecutionFailure(bytes32 txHash,uint256 payment)",
]);

export interface RevenueEscrowCodePin {
  readonly address: Address;
  readonly codeHash: Hex;
}
/** Original initialization metadata is a reviewed historical input, not a current factory read. */
export interface RevenueEscrowOrigin {
  readonly factory: RevenueEscrowCodePin;
  readonly walletCodeHash: Hex;
  readonly assetRegistry: Address;
  readonly assetRegistryCodeHash: Hex;
  readonly profileDomain: Hex;
  readonly initCodeHash: Hex;
  readonly schemaVersion: bigint;
  readonly walletVersion: bigint;
}
export interface RevenueEscrowDeployment {
  readonly chainId: bigint;
  readonly escrow: RevenueEscrowCodePin;
  readonly executor: RevenueEscrowCodePin;
  readonly origin: RevenueEscrowOrigin;
  readonly runtimeRegistry: RevenueEscrowCodePin | null;
  readonly successorFactories: readonly RevenueEscrowCodePin[];
  readonly roleRegistry: RevenueEscrowCodePin | null;
}
export interface RevenueEscrowBlock {
  readonly blockNumber: number;
  readonly blockHash: Hex;
  readonly timestamp: bigint;
}
export interface RevenueEscrowCredit {
  readonly key: escrow.RevenueEscrowCreditKey;
  readonly amount: bigint;
  readonly totalOwed: bigint;
  readonly escrowBalance: bigint;
  readonly destinationBalance: bigint;
  readonly destination: Address;
  readonly identity: readonly [Address, Hex, Hex];
}
export interface RevenueEscrowManifestObservation {
  readonly contentHash: Hex;
  readonly canonical: Hex;
  readonly publishedAt: bigint;
  readonly document: escrow.RevenueEscrowDocument | null;
  readonly affectedAccounts: readonly Address[];
}
export interface RevenueEscrowConsentObservation {
  readonly account: Address;
  readonly recoveryId: Hex;
  readonly recorded: boolean;
  readonly nonce: Hex | null;
  readonly used: boolean | null;
}
export interface RevenueEscrowCapture {
  readonly deployment: RevenueEscrowDeployment;
  readonly prepared: escrow.RevenueEscrowCall;
  readonly observed: RevenueEscrowBlock;
  readonly record: escrow.RevenueEscrowRecoveryRecord | null;
  readonly manifest: RevenueEscrowManifestObservation | null;
  readonly credit: RevenueEscrowCredit | null;
  readonly consent: RevenueEscrowConsentObservation | null;
  readonly transition: escrow.RevenueEscrowTransition | null;
  readonly dependencies: readonly RevenueEscrowCodePin[];
  readonly noNestedGasEquivalence: true;
}

function frozen<T>(value: T): T {
  if (value && typeof value === "object") {
    Object.values(value).forEach(frozen);
    Object.freeze(value);
  }
  return value;
}
function copy<T>(value: T): T { return structuredClone(value); }
function address(value: string, allowZero = false): Address {
  const result = getAddress(value) as Address;
  if (!allowZero && result === ZeroAddress) throw Error("Zero address");
  return result;
}
function bytes(value: string, max = MAX_BYTES): Hex {
  if (!isHexString(value, true) || (value.length - 2) / 2 > max) throw Error("Malformed or oversized bytes");
  return value.toLowerCase() as Hex;
}
function hash(value: string, allowZero = false): Hex {
  if (!isHexString(value, 32) || !allowZero && value.toLowerCase() === ZERO) throw Error("Invalid hash");
  return value.toLowerCase() as Hex;
}
function uint(value: bigint, bits = 256): bigint {
  if (typeof value !== "bigint" || value < 0n || value >= 1n << BigInt(bits)) throw Error("Invalid unsigned bigint");
  return value;
}
function index(value: number): number {
  if (!Number.isSafeInteger(value) || value < 0) throw Error("Concrete nonnegative block/index required");
  return value;
}
function stable(value: any): string {
  if (typeof value === "bigint") return `bigint:${value}`;
  if (Array.isArray(value)) return `[${value.map(stable).join(",")}]`;
  if (value && typeof value === "object") return `{${Object.keys(value).sort().map(k => `${k}:${stable(value[k])}`).join(",")}}`;
  return JSON.stringify(value);
}
function equal(actual: unknown, expected: unknown, label: string): void {
  if (stable(actual) !== stable(expected)) throw Error(`${label} differs`);
}
function pinInput(value: RevenueEscrowCodePin): RevenueEscrowCodePin {
  return { address: address(value.address), codeHash: hash(value.codeHash) };
}
function deployment(input: RevenueEscrowDeployment): RevenueEscrowDeployment {
  const d = copy(input);
  if (!uint(d.chainId) || !Array.isArray(d.successorFactories) || d.successorFactories.length > 64) throw Error("Deployment bound");
  return frozen({
    chainId: d.chainId,
    escrow: pinInput(d.escrow),
    executor: pinInput(d.executor),
    origin: {
      factory: pinInput(d.origin.factory),
      walletCodeHash: hash(d.origin.walletCodeHash),
      assetRegistry: address(d.origin.assetRegistry),
      assetRegistryCodeHash: hash(d.origin.assetRegistryCodeHash),
      profileDomain: hash(d.origin.profileDomain),
      initCodeHash: hash(d.origin.initCodeHash),
      schemaVersion: uint(d.origin.schemaVersion, 16),
      walletVersion: uint(d.origin.walletVersion, 16),
    },
    runtimeRegistry: d.runtimeRegistry && pinInput(d.runtimeRegistry),
    successorFactories: d.successorFactories.map(pinInput),
    roleRegistry: d.roleRegistry && pinInput(d.roleRegistry),
  });
}
async function block(provider: Reader, tag: number): Promise<RevenueEscrowBlock> {
  const b = await provider.getBlock(index(tag));
  if (!b || b.number !== tag || !b.hash) throw Error("Missing concrete block");
  return { blockNumber: tag, blockHash: hash(b.hash), timestamp: uint(BigInt(b.timestamp), 64) };
}
async function unchanged(provider: Reader, observed: RevenueEscrowBlock): Promise<void> {
  equal(await block(provider, observed.blockNumber), observed, "Block identity");
}
async function pin(provider: Reader, p: RevenueEscrowCodePin, tag: number): Promise<void> {
  const code = bytes(await provider.getCode(p.address, tag), 131072);
  if (code === "0x" || keccak256(code) !== p.codeHash) throw Error("Runtime pin differs");
}
function plain(type: ParamType, value: any): any {
  if (type.baseType === "tuple") return Object.fromEntries(type.components!.map((f, i) => [f.name, plain(f, value[i])]));
  if (type.baseType === "array") return Array.from(value, v => plain(type.arrayChildren!, v));
  return value;
}
async function read(provider: Reader, target: Address, method: string, args: readonly unknown[], tag: number): Promise<any[]> {
  const fragment = abi.getFunction(method)!;
  const raw = bytes(await provider.call({ to: target, data: abi.encodeFunctionData(fragment, args), blockTag: tag }));
  const decoded = abi.decodeFunctionResult(fragment, raw);
  if (abi.encodeFunctionResult(fragment, decoded).toLowerCase() !== raw) throw Error(`Noncanonical ${method} result`);
  return fragment.outputs.map((type, i) => plain(type, decoded[i]));
}
async function balance(provider: Reader, asset: Address, account: Address, tag: number): Promise<bigint> {
  return asset === ZeroAddress ? uint(await provider.getBalance(account, tag)) : uint((await read(provider, asset, "balanceOf", [account], tag))[0]);
}
function keyArgs(key: escrow.RevenueEscrowCreditKey): readonly unknown[] {
  return [key.revenueClass, key.profileId, key.wallet, key.asset];
}
async function bindings(provider: Reader, d: RevenueEscrowDeployment, tag: number): Promise<void> {
  equal((await provider.getNetwork()).chainId, d.chainId, "Chain");
  await pin(provider, d.escrow, tag);
  for (const [method, expected] of [
    ["splitFactory", d.origin.factory.address], ["factoryCodeHash", d.origin.factory.codeHash],
    ["walletCodeHash", d.origin.walletCodeHash], ["assetPolicyRegistry", d.origin.assetRegistry],
    ["registryCodeHash", d.origin.assetRegistryCodeHash], ["governanceAuthority", d.executor.address],
  ] as const) equal((await read(provider, d.escrow.address, method, [], tag))[0], expected, method);
}
async function recoveryContext(provider: Reader, d: RevenueEscrowDeployment, tag: number): Promise<RevenueEscrowCodePin[]> {
  if (!d.runtimeRegistry) throw Error("Bound recovery runtime registry required");
  await pin(provider, d.executor, tag);
  await pin(provider, d.runtimeRegistry, tag);
  equal((await read(provider, d.escrow.address, "revenueRuntimeRegistry", [], tag))[0], d.runtimeRegistry.address, "Recovery registry");
  equal((await read(provider, d.escrow.address, "revenueRuntimeRegistryCodeHash", [], tag))[0], d.runtimeRegistry.codeHash, "Recovery registry hash");
  return [d.executor, d.runtimeRegistry];
}
async function record(provider: Reader, d: RevenueEscrowDeployment, recoveryId: Hex, tag: number) {
  const r = escrow.normalizeRevenueEscrowRecoveryRecord((await read(provider, d.escrow.address, "escrowRecoveryRecord", [recoveryId], tag))[0]);
  if (r.status > 3n) throw Error("Unknown recovery status");
  if (r.status === 0n) {
    equal(r, {
      status: 0n, creditKey: { revenueClass: ZERO, profileId: ZERO, wallet: ZeroAddress, asset: ZeroAddress },
      storedFactory: ZeroAddress, successorWallet: ZeroAddress, successorProfileId: ZERO, successorRuntimeCodeHash: ZERO,
      expectedAmount: 0n, recoveryManifest: { uri: "", uriHash: ZERO, contentHash: ZERO, schemaId: ZERO, canonicalizationHash: ZERO },
      executeAfter: 0n, reasonHash: ZERO, reasonURI: "",
    }, "Canonical absent recovery");
  } else {
    escrow.normalizeRevenueEscrowManifestRef(r.recoveryManifest);
    equal(r.storedFactory, (await read(provider, d.escrow.address, "splitFactory", [], tag))[0], "Stored recovery factory");
  }
  if (r.status !== 0n && escrow.revenueEscrowRecoveryId({ chainId: d.chainId, escrow: d.escrow.address }, {
    creditKey: r.creditKey, successorWallet: r.successorWallet, successorProfileId: r.successorProfileId,
    successorRuntimeCodeHash: r.successorRuntimeCodeHash, expectedAmount: r.expectedAmount,
    recoveryManifest: r.recoveryManifest, executeAfter: r.executeAfter, reasonHash: r.reasonHash, reasonURI: r.reasonURI,
  }) !== recoveryId) throw Error("Recovery identity differs");
  return r;
}
async function manifest(provider: Reader, d: RevenueEscrowDeployment, contentHash: Hex, tag: number): Promise<RevenueEscrowManifestObservation> {
  const [raw, publishedAt] = await read(provider, d.escrow.address, "escrowRecoveryManifest", [contentHash], tag);
  const canonical = bytes(raw);
  if (!publishedAt) {
    if (canonical !== "0x") throw Error("Noncanonical absent manifest");
    return { contentHash, canonical, publishedAt, document: null, affectedAccounts: [] };
  }
  const document = escrow.decodeRevenueEscrowDocument(canonical);
  equal(escrow.revenueEscrowManifestHash({ chainId: d.chainId, escrow: d.escrow.address }, document), contentHash, "Stored manifest hash");
  const affectedAccounts = escrow.revenueEscrowAffectedAccounts(document);
  equal((await read(provider, d.escrow.address, "escrowRecoveryAffectedAccountCount", [contentHash], tag))[0], BigInt(affectedAccounts.length), "Affected count");
  for (let i = 0; i < affectedAccounts.length; i++) {
    equal((await read(provider, d.escrow.address, "escrowRecoveryAffectedAccountAt", [contentHash, i], tag))[0], affectedAccounts[i], "Affected account");
  }
  return { contentHash, canonical, publishedAt, document, affectedAccounts };
}
async function credit(
  provider: Reader,
  d: RevenueEscrowDeployment,
  key: escrow.RevenueEscrowCreditKey,
  destination: Address,
  tag: number,
): Promise<RevenueEscrowCredit> {
  const identity = await read(provider, d.escrow.address, "escrowCreditIdentity", keyArgs(key), tag);
  equal(identity, [d.origin.factory.address, d.origin.factory.codeHash, d.origin.walletCodeHash], "Captured credit identity");
  const amount = (await read(provider, d.escrow.address, "escrowOwed", keyArgs(key), tag))[0];
  const totalOwed = (await read(provider, d.escrow.address, "totalOwed", [key.asset], tag))[0];
  const escrowBalance = await balance(provider, key.asset, d.escrow.address, tag);
  if (totalOwed < amount || escrowBalance < totalOwed) throw Error("Escrow insolvent or contradictory totals");
  return { key, amount, totalOwed, escrowBalance, destination, destinationBalance: await balance(provider, key.asset, destination, tag), identity: identity as [Address, Hex, Hex] };
}
async function wallet(
  provider: Reader,
  factory: Address,
  profileId: Hex,
  target: Address,
  runtime: Hex,
  tag: number,
  requireDeployed = false,
): Promise<void> {
  equal((await read(provider, factory, "profileExists", [profileId], tag))[0], true, "Known profile");
  equal((await read(provider, factory, "walletFor", [profileId], tag))[0], target, "Wallet address");
  const code = bytes(await provider.getCode(target, tag), 131072);
  if (requireDeployed && code === "0x") throw Error("Delivered wallet must be deployed");
  if (code !== "0x") {
    equal(keccak256(code), runtime, "Wallet runtime");
    equal((await read(provider, factory, "splitWalletExists", [profileId], tag))[0], true, "Deployed wallet");
    equal((await read(provider, target, "factory", [], tag))[0], factory, "Wallet factory");
    equal((await read(provider, target, "profileId", [], tag))[0], profileId, "Wallet profile");
  }
}
async function admission(
  provider: Reader,
  registry: RevenueEscrowCodePin,
  factory: RevenueEscrowCodePin,
  active: boolean,
  tag: number,
) {
  await pin(provider, registry, tag);
  await pin(provider, factory, tag);
  const [f] = await read(provider, registry.address, "factoryRecord", [factory.address], tag);
  const [r] = await read(provider, registry.address, "runtimeRecord", [f.runtimeCodeHash], tag);
  if (f.codeHash !== factory.codeHash || !f.revision || !r.revision || f.runtimeCodeHash === ZERO
    || (active ? f.status !== 1n || r.status !== 1n : ![1n, 2n].includes(f.status) || ![1n, 2n].includes(r.status))) throw Error("Runtime admission differs");
  return f;
}
async function proof(
  provider: Reader,
  d: RevenueEscrowDeployment,
  doc: escrow.RevenueEscrowDocument,
  tag: number,
): Promise<RevenueEscrowCodePin[]> {
  const dependencies = await recoveryContext(provider, d, tag);
  const originalId = keccak256(coder.encode(
    ["bytes32", "uint256", "address", "uint16", "uint16", "bytes32", "bytes32", "address", "bytes32", "bytes32"],
    [d.origin.profileDomain, d.chainId, d.origin.factory.address, d.origin.schemaVersion, d.origin.walletVersion,
      d.origin.initCodeHash, d.origin.walletCodeHash, d.origin.assetRegistry, escrow.revenueEscrowEntriesHash(doc.oldEntries), doc.oldMetadataURIHash],
  ));
  equal(originalId, doc.creditKey.profileId, "Retained original profile preimage");
  const oldCode = bytes(await provider.getCode(d.origin.factory.address, tag), 131072);
  if (oldCode !== "0x" && keccak256(oldCode) === d.origin.factory.codeHash) {
    equal((await read(provider, d.origin.factory.address, "profileEntriesHash", [doc.creditKey.profileId], tag))[0], escrow.revenueEscrowEntriesHash(doc.oldEntries), "Original profile entries");
  }
  const [f] = await read(provider, d.runtimeRegistry!.address, "factoryRecord", [d.origin.factory.address], tag);
  const [r] = await read(provider, d.runtimeRegistry!.address, "runtimeRecord", [d.origin.walletCodeHash], tag);
  const oldWallet = bytes(await provider.getCode(doc.creditKey.wallet, tag), 131072);
  const poisoned = oldWallet !== "0x" && keccak256(oldWallet) !== d.origin.walletCodeHash;
  if (f.codeHash !== d.origin.factory.codeHash || f.runtimeCodeHash !== d.origin.walletCodeHash || !f.revision || !r.revision
    || !poisoned && f.status !== 3n && r.status !== 3n || poisoned && doc.creditKey.profileId === doc.successorProfileId) throw Error("Original incident required");
  if (r.status === 3n) equal(r.incidentManifestHash, doc.incidentEvidenceHash, "Runtime incident");
  else if (f.status === 3n) equal(f.incidentManifestHash, doc.incidentEvidenceHash, "Factory incident");
  const successor = d.successorFactories.find(p => p.address === doc.successorFactory);
  if (!successor) throw Error("Reviewed successor factory pin required");
  const next = await admission(provider, d.runtimeRegistry!, successor, true, tag);
  equal(next.runtimeCodeHash, doc.successorRuntimeCodeHash, "Successor admitted wallet");
  equal((await read(provider, successor.address, "revenueRuntimeRegistry", [], tag))[0], d.runtimeRegistry!.address, "Successor registry");
  equal((await read(provider, successor.address, "revenueRuntimeRegistryCodeHash", [], tag))[0], d.runtimeRegistry!.codeHash, "Successor registry hash");
  equal((await read(provider, successor.address, "profileEntriesHash", [doc.successorProfileId], tag))[0], escrow.revenueEscrowEntriesHash(doc.successorEntries), "Successor entries");
  equal((await read(provider, successor.address, "splitWalletRuntimeCodeHash", [], tag))[0], doc.successorRuntimeCodeHash, "Successor runtime");
  await wallet(provider, successor.address, doc.successorProfileId, doc.successorWallet, doc.successorRuntimeCodeHash, tag);
  return [...dependencies, successor];
}

async function flushContext(
  provider: Reader,
  d: RevenueEscrowDeployment,
  prepared: escrow.RevenueEscrowCall,
  key: escrow.RevenueEscrowCreditKey,
  tag: number,
) {
  await pin(provider, d.origin.factory, tag);
  const dependencies = [d.origin.factory];
  let registry = (await read(provider, d.escrow.address, "revenueRuntimeRegistry", [], tag))[0] as Address;
  let codeHash = (await read(provider, d.escrow.address, "revenueRuntimeRegistryCodeHash", [], tag))[0] as Hex;
  if (registry === ZeroAddress) {
    // Optional legacy probe is only a direct observation. The actual flush remains authoritative.
    const interfaceId = ["revenueRuntimeRegistry()", "revenueRuntimeRegistryCodeHash()", "revenueRuntimeBindingTransitionHashes(address)", "initializeRevenueRuntimeRegistry(address)"]
      .reduce((v, signature) => v ^ BigInt(id(signature).slice(0, 10)), 0n);
    let raw: Hex = "0x";
    try {
      raw = bytes(await provider.call({ to: d.origin.factory.address, data: abi.encodeFunctionData("supportsInterface", [`0x${interfaceId.toString(16).padStart(8, "0")}`]), blockTag: tag }), 4096);
    } catch (error) {
      if ((error as { code?: string }).code !== "CALL_EXCEPTION") throw error;
    }
    if (raw !== "0x") {
      if (raw.length !== 66 || ![0n, 1n].includes(BigInt(raw))) throw Error("Malformed optional runtime capability");
      if (BigInt(raw) === 1n) {
        registry = (await read(provider, d.origin.factory.address, "revenueRuntimeRegistry", [], tag))[0];
        codeHash = (await read(provider, d.origin.factory.address, "revenueRuntimeRegistryCodeHash", [], tag))[0];
      }
    }
  }
  if ((registry === ZeroAddress) !== (codeHash === ZERO)) throw Error("Contradictory runtime binding");
  if (registry !== ZeroAddress) {
    if (!d.runtimeRegistry) throw Error("Reviewed runtime registry required");
    equal([registry, codeHash], [d.runtimeRegistry.address, d.runtimeRegistry.codeHash], "Flush runtime binding");
    await admission(provider, d.runtimeRegistry, d.origin.factory, false, tag);
    dependencies.push(d.runtimeRegistry);
  }
  await wallet(provider, d.origin.factory.address, key.profileId, key.wallet, d.origin.walletCodeHash, tag);
  if (prepared.request.kind === "flushToVerifiedWalletBestEffort" && await provider.getCode(key.wallet, tag) === "0x") throw Error("Best effort cannot deploy wallet");
  if (prepared.request.kind === "flushEscrow") {
    if (!(await read(provider, d.escrow.address, "gasParameter", [id("6529STREAM_GGP_FLUSH_GAS_FLOOR")], tag))[0]) throw Error("Missing flush floor");
  }
  if (!(await read(provider, d.origin.factory.address, "gasParameter", [id("6529STREAM_GGP_WALLET_DEPOSIT_GAS_LIMIT")], tag))[0]) throw Error("Missing deposit gas cap");
  return dependencies;
}
function termsMatch(record: escrow.RevenueEscrowRecoveryTerms, doc: escrow.RevenueEscrowDocument): void {
  equal([record.creditKey, record.successorWallet, record.successorProfileId, record.successorRuntimeCodeHash, record.expectedAmount],
    [doc.creditKey, doc.successorWallet, doc.successorProfileId, doc.successorRuntimeCodeHash, doc.expectedAmount], "Manifest recovery terms");
}
async function allConsents(
  provider: Reader,
  d: RevenueEscrowDeployment,
  m: RevenueEscrowManifestObservation,
  recoveryId: Hex,
  tag: number,
): Promise<void> {
  if (m.document?.route === 1n) {
    for (const account of m.affectedAccounts) equal((await read(provider, d.escrow.address, "escrowRecoveryConsentRecorded", [recoveryId, account], tag))[0], true, "Affected consent");
  }
}
function recoveryId(prepared: escrow.RevenueEscrowCall): Hex | null {
  const r = prepared.request;
  if ("recoveryId" in r) return r.recoveryId;
  if (r.kind === "submitEscrowRecoveryConsent") return r.consent.recoveryId;
  if (r.kind === "scheduleEscrowRecovery") return escrow.revenueEscrowRecoveryId(prepared.coordinates, r.terms);
  return null;
}
/** Fixed-block observations. Only simulate performs the original mutating call as eth_call. */
export async function captureRevenueEscrow(
  provider: Reader,
  inputDeployment: RevenueEscrowDeployment,
  inputPrepared: escrow.RevenueEscrowCall,
  options: { readonly blockTag: number },
): Promise<RevenueEscrowCapture> {
  const d = deployment(inputDeployment);
  const prepared = escrow.normalizeRevenueEscrowCall(inputPrepared);
  const tag = index(options.blockTag);
  equal(prepared.coordinates, { chainId: d.chainId, escrow: d.escrow.address }, "Escrow coordinates");
  if (prepared.actionClass !== null && prepared.caller !== d.executor.address) throw Error("Governed target caller must be Executor");
  const observed = await block(provider, tag);
  await bindings(provider, d, tag);
  const r = prepared.request;
  const rid = recoveryId(prepared);
  const savedRecord = rid ? await record(provider, d, rid, tag) : null;
  let savedManifest: RevenueEscrowManifestObservation | null = null;
  let savedCredit: RevenueEscrowCredit | null = null;
  let consent: RevenueEscrowConsentObservation | null = null;
  let transition: escrow.RevenueEscrowTransition | null = null;
  let dependencies: RevenueEscrowCodePin[] = [];
  if (r.kind === "flushEscrow" || r.kind === "flushToVerifiedWalletBestEffort") {
    dependencies = await flushContext(provider, d, prepared, r.creditKey, tag);
    savedCredit = await credit(provider, d, r.creditKey, r.creditKey.wallet, tag);
    if (!savedCredit.amount) throw Error("No escrow credit");
  } else if (r.kind === "publishEscrowRecoveryManifest") {
    dependencies = await recoveryContext(provider, d, tag);
    savedManifest = await manifest(provider, d, r.manifest.contentHash, tag);
    if (savedManifest.publishedAt) {
      equal(savedManifest.canonical, escrow.encodeRevenueEscrowDocument(r.document), "Retained publication");
    } else {
      dependencies = await proof(provider, d, r.document, tag);
      savedCredit = await credit(provider, d, r.document.creditKey, r.document.successorWallet, tag);
      equal(savedCredit.amount, r.document.expectedAmount, "Manifest credit amount");
      for (const notice of [...r.document.recipientNotices, ...r.document.collectionNotices]) {
        if (notice.noticedAt > observed.timestamp) throw Error("Future notice");
      }
      if (r.document.sourceCredits.some(c => c.blockNumber >= BigInt(tag))) throw Error("Credit citation must precede publication block");
    }
  } else if (r.kind === "recordEscrowRecoveryConsent" || r.kind === "submitEscrowRecoveryConsent" || r.kind === "revokeEscrowRecoveryConsent") {
    const account = r.kind === "submitEscrowRecoveryConsent" ? r.consent.account : prepared.caller;
    const nonce = r.kind === "recordEscrowRecoveryConsent" ? r.nonce : r.kind === "submitEscrowRecoveryConsent" ? r.consent.nonce : null;
    const recorded = (await read(provider, d.escrow.address, "escrowRecoveryConsentRecorded", [rid, account], tag))[0];
    const used = nonce === null ? null : (await read(provider, d.escrow.address, "isEscrowRecoveryConsentNonceUsed", [account, nonce], tag))[0];
    if (r.kind === "revokeEscrowRecoveryConsent") {
      if (!recorded || savedRecord!.status === 3n) throw Error("Consent cannot be revoked");
    } else if (used || [2n, 3n].includes(savedRecord!.status)) throw Error("Consent unavailable or nonce consumed");
    if (r.kind === "submitEscrowRecoveryConsent") {
      if (r.consent.deadline < observed.timestamp) throw Error("Consent deadline expired");
      equal((await read(provider, d.escrow.address, "escrowRecoveryConsentDigest", [account, rid, nonce, r.consent.deadline], tag))[0], escrow.revenueEscrowConsentTypedData(prepared.coordinates, r.consent).digest, "Consent digest");
    }
    consent = { account, recoveryId: rid!, recorded, nonce, used };
  } else {
    if (r.kind === "scheduleEscrowRecovery") {
      if (savedRecord!.status !== 0n) throw Error("Recovery already exists");
      savedManifest = await manifest(provider, d, r.terms.recoveryManifest.contentHash, tag);
    } else {
      if (savedRecord!.status !== 1n) throw Error("Recovery is not scheduled");
      savedManifest = await manifest(provider, d, savedRecord!.recoveryManifest.contentHash, tag);
    }
    if (!savedManifest.document) throw Error("Recovery manifest missing");
    if (r.kind !== "cancelEscrowRecovery") {
      const terms = r.kind === "scheduleEscrowRecovery" ? r.terms : savedRecord!;
      termsMatch(terms, savedManifest.document);
      dependencies = await proof(provider, d, savedManifest.document, tag);
      savedCredit = await credit(provider, d, terms.creditKey, terms.successorWallet, tag);
      equal(savedCredit.amount, terms.expectedAmount, "Exact recoverable credit");
      await allConsents(provider, d, savedManifest, rid!, tag);
      if (r.kind === "executeEscrowRecovery" && observed.timestamp < terms.executeAfter) throw Error("Recovery is not mature");
    }
    if (r.kind === "scheduleEscrowRecovery") {
      const v = await read(provider, d.escrow.address, "escrowRecoveryTransitionHashes", Object.values(r.terms), tag);
      equal(v[0], rid, "Transition recovery ID");
      transition = { scopeHash: hash(v[1]), oldValueHash: hash(v[2]), newValueHash: hash(v[3]) };
    } else if (r.kind === "cancelEscrowRecovery" || r.kind === "authorizeTerminalEscrowRecovery") {
      const v = await read(provider, d.escrow.address,
        r.kind === "cancelEscrowRecovery" ? "escrowRecoveryCancellationHashes" : "escrowRecoveryTerminalHashes",
        r.kind === "cancelEscrowRecovery" ? [rid, r.reasonHash, r.reasonURI] : [rid], tag);
      transition = { scopeHash: hash(v[0]), oldValueHash: hash(v[1]), newValueHash: hash(v[2]) };
    }
  }
  await unchanged(provider, observed);
  return frozen({ deployment: d, prepared, observed, record: savedRecord, manifest: savedManifest, credit: savedCredit, consent, transition, dependencies, noNestedGasEquivalence: true });
}
function normalizedCapture(value: RevenueEscrowCapture): RevenueEscrowCapture {
  const c = copy(value);
  const d = deployment(c.deployment);
  const prepared = escrow.normalizeRevenueEscrowCall(c.prepared);
  index(c.observed.blockNumber);
  hash(c.observed.blockHash);
  uint(c.observed.timestamp, 64);
  return frozen({ ...c, deployment: d, prepared });
}
function observations(c: RevenueEscrowCapture): unknown {
  const { observed: _observed, ...rest } = c;
  return rest;
}
async function validateCapture(provider: Reader, saved: RevenueEscrowCapture): Promise<void> {
  const original = await captureRevenueEscrow(provider, saved.deployment, saved.prepared, { blockTag: saved.observed.blockNumber });
  equal(original, saved, "Captured observation");
}
function gas(value: bigint): bigint {
  if (!uint(value) || value > 100_000_000n) throw Error("Gas limit outside client bound");
  return value;
}
export interface RevenueEscrowSimulation {
  readonly capture: RevenueEscrowCapture;
  readonly returnData: Hex;
  readonly gasLimit: bigint;
}
export async function simulateRevenueEscrow(
  provider: Reader,
  input: RevenueEscrowCapture,
  options: { readonly blockTag: number; readonly gasLimit: bigint },
): Promise<RevenueEscrowSimulation> {
  const saved = normalizedCapture(input), tag = index(options.blockTag), gasLimit = gas(options.gasLimit);
  if (saved.prepared.actionClass !== null) throw Error("Governed target requires actual Executor stage");
  if (tag < saved.observed.blockNumber) throw Error("Simulation predates capture");
  await validateCapture(provider, saved);
  const current = await captureRevenueEscrow(provider, saved.deployment, saved.prepared, { blockTag: tag });
  equal(observations(current), observations(saved), "Reviewed state changed; recapture required");
  const raw = bytes(await provider.call({ ...current.prepared.call, from: current.prepared.caller, gasLimit, blockTag: tag }));
  equal(raw, current.prepared.expectedReturn, "Original call return");
  await unchanged(provider, current.observed);
  return frozen({ capture: current, returnData: raw, gasLimit });
}
/** Local retained history deliberately performs no current factory, provider, or governance admission. */
export interface RevenueEscrowHistory {
  readonly observed: RevenueEscrowBlock;
  readonly record: escrow.RevenueEscrowRecoveryRecord | null;
  readonly manifest: RevenueEscrowManifestObservation | null;
}
export async function inspectRevenueEscrowHistory(
  provider: Reader,
  input: { readonly chainId: bigint; readonly escrow: RevenueEscrowCodePin },
  query: { readonly recoveryId: Hex } | { readonly contentHash: Hex },
  options: { readonly blockTag: number },
): Promise<RevenueEscrowHistory> {
  const chainId = uint(input.chainId), host = pinInput(input.escrow), q = copy(query), tag = index(options.blockTag);
  const observed = await block(provider, tag);
  equal((await provider.getNetwork()).chainId, chainId, "Chain");
  await pin(provider, host, tag);
  // The local helpers use only these two fields; no absent dependency is consulted.
  const d = { chainId, escrow: host } as RevenueEscrowDeployment;
  const savedRecord = "recoveryId" in q ? await record(provider, d, hash(q.recoveryId), tag) : null;
  const contentHash = "contentHash" in q ? hash(q.contentHash) : savedRecord!.status ? savedRecord!.recoveryManifest.contentHash : null;
  const savedManifest = contentHash ? await manifest(provider, d, contentHash, tag) : null;
  if (savedRecord?.status) {
    if (!savedManifest?.document) throw Error("Known recovery manifest missing");
    termsMatch(savedRecord, savedManifest.document);
  }
  await unchanged(provider, observed);
  return frozen({ observed, record: savedRecord, manifest: savedManifest });
}

export interface RevenueEscrowGovernanceStage {
  readonly capture: RevenueEscrowCapture;
  readonly batch: escrow.RevenueEscrowGovernanceBatch;
  readonly stage: "publish" | "schedule" | "execute";
  readonly caller: Address;
  readonly call: UnsignedCall;
  readonly observed: RevenueEscrowBlock;
  readonly catalog: readonly [Hex, Hex, bigint, bigint];
  readonly action: Readonly<Record<string, unknown>>;
  readonly publication: Address;
  readonly guardianSet: readonly unknown[] | null;
}
function stageCall(batch: escrow.RevenueEscrowGovernanceBatch, stage: RevenueEscrowGovernanceStage["stage"]): UnsignedCall {
  if (stage === "publish") return batch.publicationCall;
  if (stage === "schedule") return batch.scheduleCall;
  if (stage === "execute") return batch.executionCall;
  throw Error("Unknown governance stage");
}
function checkWindow(batch: escrow.RevenueEscrowGovernanceBatch, now: bigint, minimumDelay: bigint): void {
  const w = batch.window, cls = batch.prepared.actionClass;
  const expected = cls === 4n ? 14n * 86400n : cls === 2n ? 72n * 3600n : 0n;
  equal(minimumDelay, expected, "Original governance delay");
  if (now + minimumDelay > w.notBefore || w.expiresAfter <= w.notBefore
    || w.expiresAfter > now + 365n * 86400n || now + 365n * 86400n >= 1n << 64n
    || cls !== 0n && w.expiresAfter - w.notBefore < 7n * 86400n) throw Error("Original governance window differs");
}
async function publication(
  provider: Reader,
  executor: Address,
  batch: escrow.RevenueEscrowGovernanceBatch,
  tag: number,
): Promise<Address> {
  const [pointer] = await read(provider, executor, "publishedCallData", [batch.publicationKey], tag);
  if (pointer !== ZeroAddress) {
    const payload = coder.encode(["bytes[]"], [[batch.prepared.call.data]]).slice(2);
    equal(bytes(await provider.getCode(pointer, tag), MAX_BYTES + 16384), `0x00${payload}`, "Governance publication bytes");
  }
  return pointer;
}
function matchAction(value: any, batch: escrow.RevenueEscrowGovernanceBatch): void {
  const c = batch.governanceCall, w = batch.window;
  for (const [key, expected] of Object.entries({
    actionClass: batch.prepared.actionClass, target: c.target, value: 0n, selector: c.selector,
    callHash: batch.callsHash, scopeHash: batch.scopeHash, oldValueHash: batch.oldValueHash, newValueHash: batch.newValueHash,
    notBefore: w.notBefore, expiresAfter: w.expiresAfter, reasonHash: w.reasonHash, reasonURI: w.reasonURI, manifestHash: w.manifestHash,
  })) equal(value[key], expected, `Governance action ${key}`);
}
async function governanceState(
  provider: Reader,
  capture: RevenueEscrowCapture,
  batch: escrow.RevenueEscrowGovernanceBatch,
  stage: RevenueEscrowGovernanceStage["stage"],
  caller: Address,
  tag: number,
): Promise<RevenueEscrowGovernanceStage> {
  const d = capture.deployment, executor = d.executor.address;
  const observed = await block(provider, tag);
  await pin(provider, d.executor, tag);
  await pin(provider, d.escrow, tag);
  const bootstrap = await read(provider, executor, "systemManifestBootstrapState", [], tag);
  if (bootstrap[0] !== true || bootstrap[1] !== true) throw Error("Ordinary sealed governance required");
  const catalog = await read(provider, executor, "governanceActionPolicyState", [], tag) as [Hex, Hex, bigint, bigint];
  if (catalog[0] === ZERO || catalog[1] === ZERO || !catalog[2]) throw Error("Bound catalog required");
  const pointer = await publication(provider, executor, batch, tag);
  const [action] = await read(provider, executor, "governanceAction", [batch.actionId], tag);
  let guardianSet: readonly unknown[] | null = null;
  if (stage === "schedule") {
    if (action.status !== 0n || pointer === ZeroAddress) throw Error("Schedule needs unused action and retained publication");
    equal((await read(provider, executor, "governanceNonce", [], tag))[0], batch.nonce, "Governance nonce");
    const owner = (await read(provider, executor, "owner", [], tag))[0];
    if (caller !== owner && (await read(provider, executor, "isProposer", [caller], tag))[0] !== true) throw Error("Original proposer authority differs");
    checkWindow(batch, observed.timestamp, (await read(provider, executor, "minimumDelay", [batch.prepared.actionClass], tag))[0]);
  }
  if (stage === "execute") {
    if (action.status !== 1n || observed.timestamp < batch.window.notBefore || observed.timestamp > batch.window.expiresAfter) throw Error("Action is not executable");
    matchAction(action, batch);
    equal((await read(provider, executor, "scheduledCallData", [batch.actionId], tag))[0], [batch.prepared.call.data], "Scheduled calldata");
    equal((await read(provider, executor, "scheduledCallDataPointer", [batch.actionId], tag))[0], pointer, "Scheduled pointer");
  }
  if (stage !== "publish" && batch.prepared.actionClass === 2n) {
    if (!d.roleRegistry) throw Error("Pinned role registry required for terminal recovery");
    await pin(provider, d.roleRegistry, tag);
    equal((await read(provider, executor, "roleRegistry", [], tag))[0], d.roleRegistry.address, "Governance roles");
    equal((await read(provider, d.roleRegistry.address, "isRoleRedundant", [id("ROLE_TERMINAL_FREEZE_VETO")], tag))[0], true, "Global terminal veto redundancy");
    guardianSet = await read(provider, executor, "terminalFreezeVetoGuardianSet", [batch.transition.scopeHash], tag);
    equal(guardianSet[0], d.roleRegistry.address, "Guardian registry");
  }
  await unchanged(provider, observed);
  return frozen({ capture, batch, stage, caller, call: stageCall(batch, stage), observed, catalog, action, publication: pointer, guardianSet });
}
export async function prepareRevenueEscrowGovernanceStage(
  provider: Reader,
  input: RevenueEscrowCapture,
  options: {
    readonly stage: RevenueEscrowGovernanceStage["stage"];
    readonly caller: Address;
    readonly nonce: bigint;
    readonly window: MintFallbackGovernanceWindow;
    readonly blockTag: number;
  },
): Promise<RevenueEscrowGovernanceStage> {
  const capture = normalizedCapture(input), o = copy(options), tag = index(o.blockTag), caller = address(o.caller);
  if (!capture.transition || capture.prepared.actionClass === null) throw Error("Governed capture required");
  if (tag < capture.observed.blockNumber) throw Error("Governance stage predates capture");
  const batch = escrow.prepareRevenueEscrowGovernanceBatch(capture.prepared, capture.deployment.executor.address, capture.transition, o.nonce, o.window);
  stageCall(batch, o.stage);
  await validateCapture(provider, capture);
  if (o.stage !== "publish") {
    const current = await captureRevenueEscrow(provider, capture.deployment, capture.prepared, { blockTag: tag });
    equal(observations(current), observations(capture), "Governed target state changed");
  }
  return governanceState(provider, capture, batch, o.stage, caller, tag);
}
function normalizedStage(value: RevenueEscrowGovernanceStage): RevenueEscrowGovernanceStage {
  const c = copy(value), capture = normalizedCapture(c.capture), batch = escrow.normalizeRevenueEscrowGovernanceBatch(c.batch);
  equal(batch.prepared, capture.prepared, "Stage target");
  equal(batch.transition, capture.transition, "Stage transition");
  equal(c.call, stageCall(batch, c.stage), "Stage call");
  return frozen({ ...c, capture, batch, caller: address(c.caller) });
}
export interface RevenueEscrowGovernanceSimulation {
  readonly operation: RevenueEscrowGovernanceStage;
  readonly returnData: Hex;
  readonly gasLimit: bigint;
}
export async function simulateRevenueEscrowGovernanceStage(
  provider: Reader,
  input: RevenueEscrowGovernanceStage,
  options: { readonly blockTag: number; readonly gasLimit: bigint },
): Promise<RevenueEscrowGovernanceSimulation> {
  const saved = normalizedStage(input), tag = index(options.blockTag), gasLimit = gas(options.gasLimit);
  if (tag < saved.observed.blockNumber) throw Error("Simulation predates stage");
  const original = await prepareRevenueEscrowGovernanceStage(provider, saved.capture, {
    stage: saved.stage, caller: saved.caller, nonce: saved.batch.nonce, window: saved.batch.window, blockTag: saved.observed.blockNumber,
  });
  equal(original, saved, "Reviewed governance stage");
  const current = await prepareRevenueEscrowGovernanceStage(provider, saved.capture, {
    stage: saved.stage, caller: saved.caller, nonce: saved.batch.nonce, window: saved.batch.window, blockTag: tag,
  });
  equal(current.catalog, saved.catalog, "Governance catalog changed");
  const raw = bytes(await provider.call({ ...current.call, from: current.caller, gasLimit, blockTag: tag }));
  if (current.stage === "publish") {
    const decoded = coder.decode(["address"], raw);
    equal(coder.encode(["address"], decoded), raw, "Publication return encoding");
    address(decoded[0]);
    if (current.publication !== ZeroAddress) equal(decoded[0], current.publication, "Retained publication return");
  } else equal(raw, current.stage === "schedule" ? coder.encode(["bytes32"], [current.batch.actionId]) : "0x", "Executor return");
  await unchanged(provider, current.observed);
  return frozen({ operation: current, returnData: raw, gasLimit });
}

export type RevenueEscrowReceiptOptions =
  | { readonly execution: "direct" }
  | { readonly execution: "safe"; readonly expectedSafeTxHash: Hex };
interface ReceiptLog {
  readonly address: Address;
  readonly topics: readonly Hex[];
  readonly data: Hex;
  readonly index: number;
}
interface Transport {
  readonly transactionHash: Hex;
  readonly observed: RevenueEscrowBlock;
  readonly logs: readonly ReceiptLog[];
  readonly safeIndex: number | null;
}
async function transport(
  provider: ReceiptReader,
  call: UnsignedCall,
  caller: Address,
  transactionHash: Hex,
  inputOptions: RevenueEscrowReceiptOptions,
): Promise<Transport> {
  const txHash = hash(transactionHash), options = copy(inputOptions);
  if (options.execution !== "direct" && options.execution !== "safe") throw Error("Unknown receipt execution transport");
  const expectedSafeTxHash = options.execution === "safe" ? hash(options.expectedSafeTxHash) : null;
  const rawReceipt = await provider.getTransactionReceipt(txHash);
  if (!rawReceipt || rawReceipt.status !== 1 || hash(rawReceipt.hash) !== txHash) throw Error("Successful exact receipt required");
  // Own every byte and identity before the next await; provider receipt objects may be mutable.
  const tag = index(rawReceipt.blockNumber), receiptHash = hash(rawReceipt.blockHash);
  const receiptFrom = address(rawReceipt.from), receiptTo = rawReceipt.to && address(rawReceipt.to);
  if (rawReceipt.logs.length > 4096) throw Error("Receipt log bound");
  let previous = -1, size = 0;
  const logs = rawReceipt.logs.map(raw => {
    const i = index(raw.index);
    if (raw.removed !== false || i <= previous || hash(raw.transactionHash) !== txHash
      || hash(raw.blockHash) !== receiptHash || raw.blockNumber !== tag) throw Error("Receipt log identity/order differs");
    previous = i;
    if (raw.topics.length > 4) throw Error("Topic bound");
    const data = bytes(raw.data);
    size += (data.length - 2) / 2;
    if (size > 4 * MAX_BYTES) throw Error("Aggregate receipt byte bound");
    return frozen({ address: address(raw.address), topics: raw.topics.map(t => hash(t, true)), data, index: i });
  });
  const rawTx = await provider.getTransaction(txHash);
  if (!rawTx) throw Error("Transaction unavailable");
  const tx = {
    to: rawTx.to && address(rawTx.to), from: address(rawTx.from), value: uint(rawTx.value), data: bytes(rawTx.data, MAX_BYTES + 16384),
    hash: hash(rawTx.hash), blockNumber: rawTx.blockNumber, blockHash: rawTx.blockHash && hash(rawTx.blockHash), chainId: rawTx.chainId,
  };
  if (tx.hash !== txHash || tx.blockNumber !== tag || tx.blockHash !== receiptHash || tx.value !== 0n) throw Error("Transaction identity/value differs");
  equal([receiptFrom, receiptTo], [tx.from, tx.to], "Receipt transaction endpoints");
  let safeIndex: number | null = null;
  if (options.execution === "direct") {
    equal([tx.to, tx.from, tx.data], [call.to, caller, call.data], "Direct original call");
  } else {
    equal(tx.to, caller, "Safe caller");
    const decoded = safeAbi.decodeFunctionData("execTransaction", tx.data);
    equal(safeAbi.encodeFunctionData("execTransaction", decoded).toLowerCase(), tx.data, "Canonical Safe calldata");
    equal([decoded[0], decoded[1], decoded[2], decoded[3]], [call.to, call.value, call.data, 0n], "Exact Safe CALL");
    const executionLogs = logs.filter(log => log.address === caller && [id("ExecutionSuccess(bytes32,uint256)"), id("ExecutionFailure(bytes32,uint256)")].includes(log.topics[0]!));
    if (executionLogs.length !== 1) throw Error("Expected one Safe terminal event");
    requireSafeExecution({ status: 1, logs: logs.map(log => ({ address: log.address, topics: [...log.topics], data: log.data })) }, caller, expectedSafeTxHash!);
    safeIndex = executionLogs[0]!.index;
  }
  const observed = await block(provider, tag);
  equal(observed.blockHash, receiptHash, "Mined block");
  equal((await provider.getNetwork()).chainId, tx.chainId, "Transaction chain");
  return frozen({ transactionHash: txHash, observed, logs, safeIndex });
}
function events(t: Transport, target: Address, name: string) {
  const event = abi.getEvent(name)!;
  return t.logs.filter(log => log.address === target && log.topics[0] === event.topicHash).map(log => {
    const result = abi.decodeEventLog(event, log.data, [...log.topics]);
    const canonical = abi.encodeEventLog(event, result);
    equal([canonical.data.toLowerCase(), canonical.topics.map(topic => topic.toLowerCase())], [log.data, log.topics], "Canonical event");
    return { index: log.index, args: Object.fromEntries(event.inputs.map((field, i) => [field.name, plain(field, result[i])])) };
  });
}
function one(t: Transport, target: Address, name: string, expected: Record<string, unknown>) {
  const matches = events(t, target, name);
  if (matches.length !== 1) throw Error(`Expected one ${name}`);
  for (const [key, value] of Object.entries(expected)) equal(matches[0]!.args[key], value, `${name}.${key}`);
  return matches[0]!;
}
function finish(t: Transport, last: number): void {
  if (t.safeIndex !== null && t.safeIndex <= last) throw Error("Safe success precedes required evidence");
}
async function priorCapture(provider: Reader, saved: RevenueEscrowCapture, t: Transport): Promise<RevenueEscrowCapture> {
  if (t.observed.blockNumber <= saved.observed.blockNumber) throw Error("Receipt must be strictly later than capture");
  await validateCapture(provider, saved);
  const prior = await captureRevenueEscrow(provider, saved.deployment, saved.prepared, { blockTag: t.observed.blockNumber - 1 });
  equal(observations(prior), observations(saved), "Prior-block state changed; recapture required");
  await bindings(provider, saved.deployment, t.observed.blockNumber);
  for (const dependency of saved.dependencies) await pin(provider, dependency, t.observed.blockNumber);
  return prior;
}
async function moved(provider: Reader, saved: RevenueEscrowCapture, t: Transport): Promise<RevenueEscrowCredit> {
  const before = saved.credit!, d = saved.deployment, tag = t.observed.blockNumber;
  const after = await credit(provider, d, before.key, before.destination, tag);
  if (after.amount !== 0n || after.totalOwed !== before.totalOwed - before.amount) throw Error("Credit debit differs");
  const recovery = saved.prepared.request.kind === "executeEscrowRecovery";
  const expectedEscrow = before.escrowBalance - before.amount, expectedWallet = before.destinationBalance + before.amount;
  if (recovery && before.key.asset === ZeroAddress) {
    if (after.escrowBalance < expectedEscrow || after.destinationBalance < expectedWallet) throw Error("Recovery transfer delta differs");
  } else equal([after.escrowBalance, after.destinationBalance], [expectedEscrow, expectedWallet], "Exact transfer deltas");
  if (recovery) {
    const doc = saved.manifest!.document!;
    await wallet(provider, doc.successorFactory, doc.successorProfileId, doc.successorWallet, doc.successorRuntimeCodeHash, tag, true);
  } else await wallet(provider, d.origin.factory.address, before.key.profileId, before.key.wallet, d.origin.walletCodeHash, tag, true);
  return after;
}
async function targetReceipt(provider: Reader, saved: RevenueEscrowCapture, t: Transport, actionId?: Hex) {
  const d = saved.deployment, r = saved.prepared.request, host = d.escrow.address, tag = t.observed.blockNumber;
  let last = -1;
  let outcome = "";
  if (r.kind === "flushEscrow" || r.kind === "flushToVerifiedWalletBestEffort") {
    const c = saved.credit!;
    last = one(t, host, "EscrowFlushed", { schemaVersion: 1n, ...c.key, amount: c.amount, remainingOwed: 0n }).index;
    await moved(provider, saved, t);
    outcome = "flushed";
  } else if (r.kind === "publishEscrowRecoveryManifest") {
    const after = await manifest(provider, d, r.manifest.contentHash, tag);
    equal(after.canonical, escrow.encodeRevenueEscrowDocument(r.document), "Published document");
    if (saved.manifest!.publishedAt) {
      equal(after, saved.manifest, "Retained publication");
      if (events(t, host, "EscrowRecoveryManifestPublished").length) throw Error("Retained publication must be eventless");
      outcome = "publication-retained";
    } else {
      equal(after.publishedAt, t.observed.timestamp, "First publication clock");
      last = one(t, host, "EscrowRecoveryManifestPublished", {
        schemaVersion: 1n, contentHash: after.contentHash, publisher: saved.prepared.caller,
        creditKeyHash: keccak256(coder.encode([escrow.REVENUE_ESCROW_KEY_TUPLE], [r.document.creditKey])),
        oldEntriesHash: escrow.revenueEscrowEntriesHash(r.document.oldEntries),
        successorEntriesHash: escrow.revenueEscrowEntriesHash(r.document.successorEntries),
        affectedAccountsHash: keccak256(coder.encode(["address[]"], [after.affectedAccounts])),
        route: r.document.route, publishedAt: after.publishedAt, canonicalDocument: after.canonical,
      }).index;
      outcome = "published";
    }
  } else if (r.kind === "recordEscrowRecoveryConsent" || r.kind === "submitEscrowRecoveryConsent" || r.kind === "revokeEscrowRecoveryConsent") {
    const c = saved.consent!, revoked = r.kind === "revokeEscrowRecoveryConsent";
    last = one(t, host, revoked ? "EscrowRecoveryConsentRevoked" : "EscrowRecoveryConsentRecorded", {
      schemaVersion: 1n, recoveryId: c.recoveryId, account: c.account, ...(!revoked ? { nonce: c.nonce } : {}),
    }).index;
    equal((await read(provider, host, "escrowRecoveryConsentRecorded", [c.recoveryId, c.account], tag))[0], !revoked, "Consent poststate");
    if (!revoked) equal((await read(provider, host, "isEscrowRecoveryConsentNonceUsed", [c.account, c.nonce], tag))[0], true, "Consumed consent nonce");
    equal(await record(provider, d, c.recoveryId, tag), saved.record, "Consent recovery status");
    if (r.kind === "submitEscrowRecoveryConsent" && r.consent.deadline < t.observed.timestamp) throw Error("Mined consent expired");
    outcome = revoked ? "consent-revoked" : "consent-recorded";
  } else {
    const rid = recoveryId(saved.prepared)!;
    const before = saved.record!, after = await record(provider, d, rid, tag);
    if (r.kind === "scheduleEscrowRecovery") {
      if (!actionId || t.observed.timestamp < saved.manifest!.publishedAt + 14n * 86400n) throw Error("Governed schedule notice period incomplete");
      equal(after, { status: 1n, creditKey: r.terms.creditKey, storedFactory: d.origin.factory.address,
        successorWallet: r.terms.successorWallet, successorProfileId: r.terms.successorProfileId,
        successorRuntimeCodeHash: r.terms.successorRuntimeCodeHash, expectedAmount: r.terms.expectedAmount,
        recoveryManifest: r.terms.recoveryManifest, executeAfter: r.terms.executeAfter,
        reasonHash: r.terms.reasonHash, reasonURI: r.terms.reasonURI }, "Scheduled recovery");
      last = one(t, host, "EscrowRecoveryScheduled", { schemaVersion: 1n, recoveryId: rid, ...r.terms.creditKey,
        successorWallet: r.terms.successorWallet, successorProfileId: r.terms.successorProfileId,
        expectedAmount: r.terms.expectedAmount, recoveryManifestContentHash: r.terms.recoveryManifest.contentHash,
        executeAfter: r.terms.executeAfter, reasonHash: r.terms.reasonHash, reasonURI: r.terms.reasonURI }).index;
      outcome = "recovery-scheduled";
    } else if (r.kind === "cancelEscrowRecovery") {
      if (!actionId) throw Error("Governed cancellation evidence required");
      equal(after, { ...before, status: 2n }, "Cancelled recovery");
      last = one(t, host, "EscrowRecoveryCancelled", { schemaVersion: 1n, recoveryId: rid, revenueClass: before.creditKey.revenueClass,
        profileId: before.creditKey.profileId, reasonHash: r.reasonHash, reasonURI: r.reasonURI }).index;
      outcome = "recovery-cancelled";
    } else if (r.kind === "authorizeTerminalEscrowRecovery") {
      if (!actionId) throw Error("Governed terminal evidence required");
      equal(after, before, "Terminal retained recovery");
      last = one(t, host, "EscrowRecoveryTerminalAuthorized", { schemaVersion: 1n, recoveryId: rid, actionId,
        manifestContentHash: before.recoveryManifest.contentHash, authorizedAt: t.observed.timestamp }).index;
      outcome = "terminal-authorized";
    } else {
      equal(after, { ...before, status: 3n }, "Executed recovery");
      if (t.observed.timestamp < before.executeAfter) throw Error("Recovery receipt predates execution window");
      last = one(t, host, "EscrowRecoveryExecuted", { schemaVersion: 1n, recoveryId: rid,
        revenueClass: before.creditKey.revenueClass, profileId: before.creditKey.profileId,
        oldWallet: before.creditKey.wallet, successorWallet: before.successorWallet, movedAmount: before.expectedAmount,
        recoveryManifestContentHash: before.recoveryManifest.contentHash, reasonHash: before.reasonHash, reasonURI: before.reasonURI }).index;
      await moved(provider, saved, t);
      await allConsents(provider, d, saved.manifest!, rid, tag);
      outcome = "recovered";
    }
  }
  return { last, outcome };
}
export interface RevenueEscrowReceipt {
  readonly transactionHash: Hex;
  readonly observed: RevenueEscrowBlock;
  readonly outcome: string;
  readonly priorBlock: RevenueEscrowBlock;
  readonly attribution: "exact-prior-and-end-block";
}
export async function reconcileRevenueEscrowReceipt(
  provider: ReceiptReader,
  input: RevenueEscrowCapture,
  transactionHash: Hex,
  options: RevenueEscrowReceiptOptions,
): Promise<RevenueEscrowReceipt> {
  const saved = normalizedCapture(input), opts = copy(options), txHash = hash(transactionHash);
  if (saved.prepared.actionClass !== null) throw Error("Governed target requires Executor receipt route");
  const t = await transport(provider, saved.prepared.call, saved.prepared.caller, txHash, opts);
  const prior = await priorCapture(provider, saved, t);
  const result = await targetReceipt(provider, prior, t);
  finish(t, result.last);
  await unchanged(provider, t.observed);
  return frozen({ transactionHash: t.transactionHash, observed: t.observed, outcome: result.outcome, priorBlock: prior.observed, attribution: "exact-prior-and-end-block" as const });
}

export interface RevenueEscrowGovernanceReceipt {
  readonly transactionHash: Hex;
  readonly observed: RevenueEscrowBlock;
  readonly actionId: Hex;
  readonly stage: RevenueEscrowGovernanceStage["stage"];
  readonly outcome: string;
  readonly attribution: "exact-prior-and-end-block";
}
export async function reconcileRevenueEscrowGovernanceReceipt(
  provider: ReceiptReader,
  input: RevenueEscrowGovernanceStage,
  transactionHash: Hex,
  options: RevenueEscrowReceiptOptions,
): Promise<RevenueEscrowGovernanceReceipt> {
  const saved = normalizedStage(input), opts = copy(options), txHash = hash(transactionHash);
  const t = await transport(provider, saved.call, saved.caller, txHash, opts);
  if (t.observed.blockNumber <= saved.observed.blockNumber) throw Error("Governance receipt must follow stage capture");
  const original = await prepareRevenueEscrowGovernanceStage(provider, saved.capture, {
    stage: saved.stage, caller: saved.caller, nonce: saved.batch.nonce, window: saved.batch.window, blockTag: saved.observed.blockNumber,
  });
  equal(original, saved, "Reviewed governance stage");
  const d = saved.capture.deployment, batch = saved.batch, host = d.executor.address, tag = t.observed.blockNumber;
  const prior = await governanceState(provider, saved.capture, batch, saved.stage, saved.caller, tag - 1);
  equal(prior.catalog, saved.catalog, "Prior governance catalog");
  await pin(provider, d.executor, tag);
  await pin(provider, d.escrow, tag);
  let last = -1;
  let outcome = "";
  if (saved.stage === "publish") {
    const pointer = await publication(provider, host, batch, tag);
    if (pointer === ZeroAddress) throw Error("Missing retained publication");
    if (prior.publication !== ZeroAddress) {
      equal(pointer, prior.publication, "Eventless publication pointer");
      if (events(t, host, "GovernanceCallDataPublished").length) throw Error("Retained publication must be eventless");
      outcome = "publication-retained";
    } else {
      last = one(t, host, "GovernanceCallDataPublished", { schemaVersion: 1n, callDataKey: batch.publicationKey, pointer, publisher: saved.caller }).index;
      outcome = "published";
    }
  } else {
    const [action] = await read(provider, host, "governanceAction", [batch.actionId], tag);
    matchAction(action, batch);
    const policy = one(t, host, "GovernanceActionPolicyValidated", { schemaVersion: 1n, actionId: batch.actionId,
      phase: saved.stage === "schedule" ? 1n : 2n, candidateProfileHash: prior.catalog[0], catalogHash: prior.catalog[1] });
    const common = { schemaVersion: 1n, actionId: batch.actionId, actionClass: batch.prepared.actionClass,
      target: batch.governanceCall.target, value: 0n, selector: batch.governanceCall.selector,
      callHash: batch.callsHash, scopeHash: batch.scopeHash, oldValueHash: batch.oldValueHash, newValueHash: batch.newValueHash,
      manifestHash: batch.window.manifestHash };
    if (saved.stage === "schedule") {
      checkWindow(batch, t.observed.timestamp, (await read(provider, host, "minimumDelay", [batch.prepared.actionClass], tag))[0]);
      const allowed = batch.prepared.actionClass === 2n ? [1n, 2n, 5n] : batch.prepared.actionClass === 0n ? [1n, 2n, 3n] : [1n, 2n];
      if (!allowed.includes(action.status)) throw Error("Scheduled action status differs");
      equal(action.proposer, saved.caller, "Scheduled proposer");
      const scheduled = one(t, host, "GovernanceActionScheduled", { ...common, notBefore: batch.window.notBefore,
        expiresAfter: batch.window.expiresAfter, nonce: batch.nonce, proposer: saved.caller,
        reasonHash: batch.window.reasonHash, reasonURI: batch.window.reasonURI });
      equal((await read(provider, host, "scheduledCallData", [batch.actionId], tag))[0], [batch.prepared.call.data], "Scheduled original calldata");
      equal((await read(provider, host, "scheduledCallDataPointer", [batch.actionId], tag))[0], await publication(provider, host, batch, tag), "Scheduled publication");
      if (scheduled.index >= policy.index) throw Error("Schedule policy event order");
      if (batch.prepared.actionClass === 2n) {
        const [commitment] = await read(provider, host, "terminalFreezeGuardianConfigCommitment", [batch.actionId], tag);
        hash(commitment);
        const committed = one(t, host, "TerminalFreezeGuardianConfigCommitted", { schemaVersion: 1n, actionId: batch.actionId, commitment });
        const membership = events(t, host, "TerminalFreezeActionMembershipUpdated").filter(e => e.args.actionId === batch.actionId);
        if (membership.length !== 1) throw Error("Expected one terminal membership append");
        const m = membership[0]!;
        equal([m.args.schemaVersion, m.args.scopeHash, m.args.proposer, m.args.present, m.args.mutationCause, m.args.vetoDeadline],
          [1n, batch.transition.scopeHash, saved.caller, true, 1n, batch.window.notBefore], "Terminal membership");
        if (m.args.remainingCount !== m.args.rawIndex + 1n || m.args.remainingCount > 64n
          || !(m.index < committed.index && committed.index < scheduled.index)) throw Error("Terminal membership order/count");
      }
      outcome = "scheduled";
    } else {
      equal(action.status, 3n, "Executed governance action");
      equal(action.executor, saved.caller, "Execution actor");
      const targetPrior = await priorCapture(provider, saved.capture, t);
      const target = await targetReceipt(provider, targetPrior, t, batch.actionId);
      const executed = one(t, host, "GovernanceActionExecuted", { ...common, executor: saved.caller });
      if (!(target.last < executed.index && executed.index < policy.index)) throw Error("Target/Executor/policy event order");
      const memberships = events(t, host, "TerminalFreezeActionMembershipUpdated").filter(e => e.args.actionId === batch.actionId);
      if (batch.prepared.actionClass !== 2n && memberships.length) throw Error("Unexpected terminal membership");
      if (memberships.length > 1) throw Error("Duplicate terminal removal");
      if (memberships.length) {
        const m = memberships[0]!;
        equal([m.args.schemaVersion, m.args.scopeHash, m.args.proposer, m.args.present, m.args.mutationCause, m.args.vetoDeadline],
          [1n, batch.transition.scopeHash, action.proposer, false, 3n, batch.window.notBefore], "Terminal cleanup");
        const firstTarget = t.logs.find(log => log.address === d.escrow.address)?.index ?? target.last;
        if (m.index >= firstTarget || m.args.remainingCount > 64n) throw Error("Terminal cleanup order/count");
      }
      outcome = target.outcome;
    }
    last = policy.index;
  }
  finish(t, last);
  await unchanged(provider, prior.observed);
  await unchanged(provider, t.observed);
  return frozen({ transactionHash: t.transactionHash, observed: t.observed, actionId: batch.actionId, stage: saved.stage,
    outcome, attribution: "exact-prior-and-end-block" as const });
}
