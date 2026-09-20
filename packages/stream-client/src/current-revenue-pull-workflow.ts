import { Interface, ZeroAddress, getAddress, id, isHexString, keccak256 } from "ethers";
import type { Provider } from "ethers";
import type { Address, Hex } from "./generated/contracts.js";
import { requireSafeExecution } from "./safe.js";
import {
  normalizeSplitProfile, splitWalletDomainSeparator,
  splitWalletReleaseTypedData, splitWalletReleaseRevocationTypedData,
} from "./current-split-factory.js";
import type { SplitProfile } from "./current-split-factory.js";
import { captureSplitFactory, inspectSplitFactoryProfile } from "./current-split-factory-workflow.js";
import type { SplitFactoryDeployment, SplitFactoryCodePin, SplitFactoryProfileInspection } from "./current-split-factory-workflow.js";
import {
  REVENUE_PULL_MAX_BYTES, REVENUE_PULL_MAX_CLAIMS, REVENUE_PULL_WALLET_ABI,
  REVENUE_PULL_ROUTER_ABI, normalizeRevenuePullCall, isRevenuePullRouterRequest,
  revenuePullEntitlement,
} from "./current-revenue-pull.js";
import type { PreparedRevenuePullCall, RevenuePullClaim } from "./current-revenue-pull.js";

export interface RevenuePullWallet {
  readonly factory: SplitFactoryDeployment;
  readonly profile: SplitProfile;
}
export interface RevenuePullDeployment {
  readonly chainId: bigint;
  readonly wallets: readonly RevenuePullWallet[];
  readonly router: SplitFactoryCodePin | null;
  readonly assets: readonly SplitFactoryCodePin[];
}
export interface RevenuePullAssetObservation {
  readonly wallet: Address;
  readonly asset: Address;
  readonly account: Address;
  readonly balance: bigint;
  readonly totalReleased: bigint;
  readonly accountReleased: bigint;
  readonly sharePpm: bigint;
  readonly initialized: boolean;
  readonly lastObservedReceived: bigint;
  readonly observedReceived: bigint;
  readonly releasable: bigint;
  readonly status: bigint | null;
  readonly releaseGraceUntil: bigint | null;
  readonly eligible: boolean;
  readonly highWaterIntact: boolean;
}
export interface RevenuePullNonceObservation {
  readonly account: Address;
  readonly nonce: Hex;
  readonly used: boolean;
  readonly digest: Hex | null;
  readonly deadline: bigint | null;
}
export interface RevenuePullCapture {
  readonly deployment: RevenuePullDeployment;
  readonly prepared: PreparedRevenuePullCall;
  readonly blockNumber: number;
  readonly blockHash: Hex;
  readonly timestamp: bigint;
  readonly wallets: readonly SplitFactoryProfileInspection[];
  readonly assets: readonly RevenuePullAssetObservation[];
  readonly nonce: RevenuePullNonceObservation | null;
  readonly gasParameters: readonly { readonly factory: Address; readonly assetPolicy: bigint; readonly erc1271: bigint }[];
  readonly admission: "observed; original target simulation required";
}
export interface RevenuePullSimulation {
  readonly capture: RevenuePullCapture;
  readonly gasLimit: bigint;
  readonly returnData: Hex;
  /** Router entries are simulated wallet-reported values, never mined payment evidence. */
  readonly amounts: readonly bigint[];
  readonly admission: "exact original call simulated at the recorded block";
}
export interface RevenuePullFailure {
  readonly operation: "syncAsset" | "release";
  readonly returnDataSize: bigint;
  readonly reason: Hex;
}
export interface RevenuePullItemReceipt {
  readonly index: number;
  readonly claim: RevenuePullClaim;
  readonly recipient: Address;
  readonly amount: bigint | null;
  readonly sync: "not-requested" | "retained" | "failed";
  readonly outcome: "released" | "failed";
  readonly failure: RevenuePullFailure | null;
}
export interface RevenuePullEvent {
  readonly address: Address;
  readonly name: string;
  readonly logIndex: number;
}
export interface RevenuePullReceipt {
  readonly capture: RevenuePullCapture;
  readonly transactionHash: Hex;
  readonly blockNumber: number;
  readonly blockHash: Hex;
  readonly prior: RevenuePullCapture;
  readonly observed: RevenuePullCapture;
  readonly items: readonly RevenuePullItemReceipt[];
  readonly events: readonly RevenuePullEvent[];
  readonly synchronization: "not-requested" | "observation-event" | "eventless-with-prior-initialization";
  readonly stateAttribution: "event-local payments; end-block state may include other transactions; ambiguous callback logs rejected";
}
export type RevenuePullReceiptOptions = {
  readonly transactionHash: Hex;
} & (
  | { readonly execution: "direct" }
  | { readonly execution: "safe"; readonly expectedSafeTxHash: Hex }
);
type Reader = Pick<Provider, "getNetwork" | "getCode" | "getBlock" | "getBalance" | "call">;
type ReceiptReader = Reader & Pick<Provider, "getTransaction" | "getTransactionReceipt">;
const walletAbi = new Interface(REVENUE_PULL_WALLET_ABI);
const routerAbi = new Interface(REVENUE_PULL_ROUTER_ABI);
const assetAbi = new Interface([
  "function assetStatus(address) view returns(uint8)",
  "function assetReleaseGraceUntil(address) view returns(uint64)",
]);
const tokenAbi = new Interface(["function balanceOf(address) view returns(uint256)"]);
const gasAbi = new Interface(["function gasParameter(bytes32) view returns(uint256)"]);
const safeAbi = new Interface([
  "function execTransaction(address to,uint256 value,bytes data,uint8 operation,uint256 safeTxGas,uint256 baseGas,uint256 gasPrice,address gasToken,address refundReceiver,bytes signatures) returns(bool)",
]);
const safeEvents = new Interface([
  "event ExecutionSuccess(bytes32 txHash,uint256 payment)",
  "event ExecutionFailure(bytes32 txHash,uint256 payment)",
]);

function exact(value: unknown, keys: readonly string[]): void {
  if (!value || typeof value !== "object" || Array.isArray(value)
    || Object.keys(value).sort().join() !== [...keys].sort().join()) throw Error("Missing or unknown properties");
}
function address(value: unknown, zero = false): Address {
  if (typeof value !== "string") throw Error("Expected address");
  const result = getAddress(value) as Address;
  if (!zero && result === ZeroAddress) throw Error("Zero address");
  return result;
}
function uint(value: unknown, bits = 256): bigint {
  if (typeof value !== "bigint" || value < 0n || value >= 1n << BigInt(bits)) throw Error(`Expected uint${bits} bigint`);
  return value;
}
function bytes(value: unknown, max = REVENUE_PULL_MAX_BYTES): Hex {
  if (typeof value !== "string" || !isHexString(value, true) || (value.length - 2) / 2 > max) throw Error("Malformed or oversized bytes");
  return value.toLowerCase() as Hex;
}
function hash(value: unknown): Hex {
  const result = bytes(value, 32);
  if (result.length !== 66) throw Error("Expected bytes32");
  return result;
}
function integer(value: unknown): number {
  if (typeof value !== "number" || !Number.isSafeInteger(value) || value < 0) throw Error("Expected concrete block or index");
  return value;
}
function boolean(value: unknown): boolean {
  if (typeof value !== "boolean") throw Error("Expected canonical boolean");
  return value;
}
function freeze<T>(value: T): T {
  if (value && typeof value === "object") { Object.values(value).forEach(freeze); Object.freeze(value); }
  return value;
}
function stable(value: unknown): string {
  return JSON.stringify(value, (_, v) => typeof v === "bigint" ? `${v}n`
    : v && typeof v === "object" && !Array.isArray(v) ? Object.fromEntries(Object.entries(v).sort(([a], [b]) => a.localeCompare(b))) : v);
}
function equal(a: unknown, b: unknown, message: string): void {
  if (stable(a) !== stable(b)) throw Error(message);
}
function dense<T>(value: readonly T[], max: number): readonly T[] {
  if (!Array.isArray(value) || value.length > max || Object.keys(value).length !== value.length) throw Error("Expected dense bounded array");
  return value;
}
function pin(value: SplitFactoryCodePin): SplitFactoryCodePin {
  exact(value, ["address", "codeHash"]);
  return { address: address(value.address), codeHash: hash(value.codeHash) };
}
function deployment(value: RevenuePullDeployment): RevenuePullDeployment {
  exact(value, ["chainId", "wallets", "router", "assets"]);
  const chainId = uint(value.chainId);
  if (!chainId) throw Error("Expected positive chain ID");
  const wallets = dense(value.wallets, REVENUE_PULL_MAX_CLAIMS).map(row => {
    exact(row, ["factory", "profile"]);
    exact(row.factory, ["chainId", "factory", "assetPolicy", "implementation"]);
    const factory = {
      chainId: uint(row.factory.chainId), factory: pin(row.factory.factory),
      assetPolicy: pin(row.factory.assetPolicy), implementation: pin(row.factory.implementation),
    };
    const profile = normalizeSplitProfile(row.profile);
    if (factory.chainId !== chainId || profile.context.chainId !== chainId
      || profile.context.factory !== factory.factory.address) throw Error("Profile deployment differs");
    return { factory, profile };
  });
  const assets = dense(value.assets, REVENUE_PULL_MAX_CLAIMS).map(pin);
  if (new Set(wallets.map(x => x.profile.wallet)).size !== wallets.length
    || new Set(assets.map(x => x.address)).size !== assets.length) throw Error("Duplicate deployment pins");
  return freeze({ chainId, wallets, assets, router: value.router === null ? null : pin(value.router) });
}
function claims(prepared: PreparedRevenuePullCall): readonly RevenuePullClaim[] {
  const r = prepared.request;
  if (isRevenuePullRouterRequest(r)) return r.claims;
  if (r.kind === "releaseWithAuthorization") return [{ wallet: prepared.target, asset: r.authorization.asset, account: r.authorization.account }];
  if (r.kind === "release") return [{ wallet: prepared.target, asset: r.asset, account: r.account }];
  if (r.kind === "syncAsset") return [{ wallet: prepared.target, asset: r.asset, account: ZeroAddress as Address }];
  return [];
}
function bind(d: RevenuePullDeployment, prepared: PreparedRevenuePullCall): void {
  const router = isRevenuePullRouterRequest(prepared.request);
  const targets = router ? [...new Set(claims(prepared).map(x => x.wallet))] : [prepared.target];
  equal([...targets].sort(), d.wallets.map(x => x.profile.wallet).sort(), "Required wallet inventory differs");
  const assets = [...new Set(claims(prepared).map(x => x.asset).filter(x => x !== ZeroAddress))].sort();
  equal(assets, d.assets.map(x => x.address).sort(), "Required asset pins differ");
  if (router ? d.router?.address !== prepared.target : d.router !== null) throw Error("Router pin differs from call");
}
async function block(p: Reader, number: number): Promise<{ number: number; hash: Hex; timestamp: bigint }> {
  const b = await p.getBlock(number);
  if (!b || b.number !== number || !b.hash) throw Error("Missing or mismatched concrete block");
  return { number, hash: hash(b.hash), timestamp: BigInt(integer(b.timestamp)) };
}
async function unchanged(p: Reader, h: { number: number; hash: Hex; timestamp: bigint }): Promise<void> {
  equal(await block(p, h.number), h, "Pinned block changed");
}
async function runtime(p: Reader, value: SplitFactoryCodePin, tag: number): Promise<void> {
  const code = bytes(await p.getCode(value.address, tag));
  if (code === "0x" || code.length === 48 && code.startsWith("0xef0100") || keccak256(code) !== value.codeHash) throw Error("Reviewed runtime differs");
}
async function read(p: Reader, to: Address, abi: Interface, name: string, args: readonly unknown[], tag: number): Promise<readonly unknown[]> {
  const raw = bytes(await p.call({ to, value: 0n, data: abi.encodeFunctionData(name, args), blockTag: tag }));
  const result = abi.decodeFunctionResult(name, raw);
  if (abi.encodeFunctionResult(name, result).toLowerCase() !== raw) throw Error(`Noncanonical ${name} response`);
  return result;
}

/** Pins initialized V4 wallets and observes state. This does not authenticate a supplied signature. */
export async function captureRevenuePull(
  p: Reader,
  input: RevenuePullDeployment,
  callInput: PreparedRevenuePullCall,
  options: { readonly blockTag: number },
): Promise<RevenuePullCapture> {
  const d = deployment(input);
  const prepared = normalizeRevenuePullCall(callInput);
  exact(options, ["blockTag"]);
  const tag = integer(options.blockTag);
  bind(d, prepared);
  if ((await p.getNetwork()).chainId !== d.chainId) throw Error("RPC chain differs");
  const h = await block(p, tag);
  await Promise.all([...d.assets, ...(d.router ? [d.router] : [])].map(x => runtime(p, x, tag)));
  const wallets: SplitFactoryProfileInspection[] = [];
  const gasParameters: { factory: Address; assetPolicy: bigint; erc1271: bigint }[] = [];
  for (const row of d.wallets) {
    const captured = await captureSplitFactory(p, row.factory, { blockTag: tag });
    const observed = await inspectSplitFactoryProfile(p, captured, row.profile, { blockTag: tag });
    if (!observed.initialized) throw Error("Pull target must be an initialized original wallet");
    wallets.push(observed);
    if (!gasParameters.some(x => x.factory === row.factory.factory.address)) {
      const target = row.factory.factory.address;
      const [[assetPolicy], [erc1271]] = await Promise.all([
        read(p, target, gasAbi, "gasParameter", [id("6529STREAM_GGP_ASSET_POLICY_GAS_LIMIT")], tag),
        read(p, target, gasAbi, "gasParameter", [id("6529STREAM_GGP_ERC_1271_GAS_LIMIT")], tag),
      ]);
      if (!uint(assetPolicy) || !uint(erc1271)) throw Error("Missing original wallet gas parameter");
      gasParameters.push({ factory: target, assetPolicy: uint(assetPolicy), erc1271: uint(erc1271) });
    }
  }
  const assets: RevenuePullAssetObservation[] = [];
  for (const item of claims(prepared)) {
    if (assets.some(x => x.wallet === item.wallet && x.asset === item.asset && x.account === item.account)) continue;
    const profile = wallets.find(x => x.profile.wallet === item.wallet)!;
    const [[total], [released], [share], [initialized], [last], balance] = await Promise.all([
      read(p, item.wallet, walletAbi, "totalReleased", [item.asset], tag),
      read(p, item.wallet, walletAbi, "accountReleased", [item.asset, item.account], tag),
      read(p, item.wallet, walletAbi, "aggregateSharePpm", [item.account], tag),
      read(p, item.wallet, walletAbi, "assetObservationInitialized", [item.asset], tag),
      read(p, item.wallet, walletAbi, "lastObservedReceived", [item.asset], tag),
      item.asset === ZeroAddress ? p.getBalance(item.wallet, tag)
        : read(p, item.asset, tokenAbi, "balanceOf", [item.wallet], tag).then(x => x[0]),
    ]);
    const expectedShare = profile.profile.aggregateSharePpm[profile.profile.accounts.indexOf(item.account)] ?? 0n;
    if (share !== expectedShare) throw Error("Account share differs from immutable profile");
    const observed = revenuePullEntitlement(uint(balance), uint(total), uint(share, 32), uint(released));
    const initial = boolean(initialized);
    let status: bigint | null = null, grace: bigint | null = null;
    if (item.asset !== ZeroAddress) {
      const [[s], [g]] = await Promise.all([
        read(p, profile.capture.deployment.assetPolicy.address, assetAbi, "assetStatus", [item.asset], tag),
        read(p, profile.capture.deployment.assetPolicy.address, assetAbi, "assetReleaseGraceUntil", [item.asset], tag),
      ]);
      status = uint(s, 8); grace = uint(g, 64);
    }
    const eligible = status === null || status === 1n || status === 3n && (initial || h.timestamp < grace!);
    if (eligible) {
      const [[received], [releasable]] = await Promise.all([
        read(p, item.wallet, walletAbi, "observedReceived", [item.asset], tag),
        read(p, item.wallet, walletAbi, "releasable", [item.asset, item.account], tag),
      ]);
      if (received !== observed.observedReceived || releasable !== observed.releasable) throw Error("Original entitlement views differ");
    }
    assets.push({ ...item, balance: uint(balance), totalReleased: uint(total), accountReleased: uint(released),
      sharePpm: uint(share, 32), initialized: initial, lastObservedReceived: uint(last), ...observed,
      status, releaseGraceUntil: grace, eligible, highWaterIntact: !initial || observed.observedReceived >= uint(last) });
  }
  let nonce: RevenuePullNonceObservation | null = null;
  const r = prepared.request;
  if (r.kind === "revokeReleaseAuthorization" || r.kind === "revokeReleaseAuthorizationBySignature" || r.kind === "releaseWithAuthorization") {
    const account = r.kind === "revokeReleaseAuthorization" ? prepared.caller
      : r.kind === "releaseWithAuthorization" ? r.authorization.account : r.account;
    const n = r.kind === "releaseWithAuthorization" ? r.authorization.nonce : r.nonce;
    const [used] = await read(p, prepared.target, walletAbi, "isReleaseAuthorizationNonceUsed", [account, n], tag);
    let digest: Hex | null = null;
    let deadline: bigint | null = null;
    if (r.kind !== "revokeReleaseAuthorization") {
      const profile = wallets[0]!;
      const [domain] = await read(p, prepared.target, walletAbi, "domainSeparator", [], tag);
      if (domain !== splitWalletDomainSeparator(profile.profile)) throw Error("Individual wallet signing domain differs");
      const signed = r.kind === "releaseWithAuthorization"
        ? splitWalletReleaseTypedData(profile.capture.snapshot, profile.profile, r.authorization)
        : splitWalletReleaseRevocationTypedData(profile.capture.snapshot, profile.profile, { account, nonce: n, deadline: r.deadline });
      const [actual] = await read(p, prepared.target, walletAbi,
        r.kind === "releaseWithAuthorization" ? "releaseAuthorizationDigest" : "releaseRevocationDigest",
        r.kind === "releaseWithAuthorization" ? [r.authorization] : [account, n, r.deadline], tag);
      if (actual !== signed.digest) throw Error("Original wallet digest differs");
      digest = hash(actual); deadline = r.kind === "releaseWithAuthorization" ? r.authorization.deadline : r.deadline;
    }
    nonce = { account, nonce: n, used: boolean(used), digest, deadline };
  }
  await unchanged(p, h);
  return freeze({ deployment: d, prepared, blockNumber: tag, blockHash: h.hash, timestamp: h.timestamp,
    wallets, assets, nonce, gasParameters, admission: "observed; original target simulation required" });
}

async function saved(p: Reader, value: RevenuePullCapture): Promise<RevenuePullCapture> {
  // Snapshot before the first await, then reconstruct every supplied observed fact independently.
  const copy = structuredClone(value);
  exact(copy, ["deployment", "prepared", "blockNumber", "blockHash", "timestamp", "wallets", "assets", "nonce", "gasParameters", "admission"]);
  const rebuilt = await captureRevenuePull(p, copy.deployment, copy.prepared, { blockTag: integer(copy.blockNumber) });
  equal(copy, rebuilt, "Saved capture differs from pinned historical state");
  return rebuilt;
}

/** Same caller, bytes, zero value and explicit gas; no local EOA/ERC1271 classifier replaces the contract. */
export async function simulateRevenuePull(
  p: Reader,
  input: RevenuePullCapture,
  options: { readonly blockTag: number; readonly gasLimit: bigint },
): Promise<RevenuePullSimulation> {
  exact(options, ["blockTag", "gasLimit"]);
  const tag = integer(options.blockTag), gasLimit = uint(options.gasLimit);
  if (!gasLimit) throw Error("Expected positive simulation gas");
  const original = await saved(p, input);
  if (tag < original.blockNumber) throw Error("Simulation predates capture");
  const current = tag === original.blockNumber ? original
    : await captureRevenuePull(p, original.deployment, original.prepared, { blockTag: tag });
  const prepared = current.prepared;
  const raw = bytes(await p.call({ ...prepared.call, from: prepared.caller, gasLimit, blockTag: tag }));
  const router = isRevenuePullRouterRequest(prepared.request);
  const abi = router ? routerAbi : walletAbi;
  const decoded = abi.decodeFunctionResult(prepared.request.kind, raw);
  if (abi.encodeFunctionResult(prepared.request.kind, decoded).toLowerCase() !== raw) throw Error("Noncanonical simulated return");
  const amounts = router ? Array.from(decoded[0], x => uint(x)) : Array.from(decoded, x => uint(x));
  if (router && amounts.length !== (prepared.request as Extract<typeof prepared.request, { claims: unknown }>).claims.length) throw Error("Router return length differs");
  if (!router && amounts.length) {
    const expected = prepared.request.kind === "syncAsset" ? current.assets[0]!.observedReceived : current.assets[0]!.releasable;
    if (amounts[0] !== expected) throw Error("Original simulated amount differs from observation");
  }
  await unchanged(p, { number: tag, hash: current.blockHash, timestamp: current.timestamp });
  return freeze({ capture: current, gasLimit, returnData: raw, amounts,
    admission: "exact original call simulated at the recorded block" });
}

interface EventRow {
  readonly address: Address;
  readonly name: string;
  readonly args: readonly unknown[];
  readonly index: number;
}

/** Event-local reconciliation deliberately rejects extra callback events that make item attribution ambiguous. */
export async function inspectRevenuePullReceipt(
  p: ReceiptReader,
  input: RevenuePullCapture,
  options: RevenuePullReceiptOptions,
): Promise<RevenuePullReceipt> {
  exact(options, options.execution === "safe"
    ? ["transactionHash", "execution", "expectedSafeTxHash"] : ["transactionHash", "execution"]);
  if (options.execution !== "direct" && options.execution !== "safe") throw Error("Unsupported receipt transport");
  const txHash = hash(options.transactionHash);
  const execution = options.execution;
  const safeHash = options.execution === "safe" ? hash(options.expectedSafeTxHash) : null;
  const capture = await saved(p, input);
  const prepared = capture.prepared;
  const [receiptInput, txInput] = await Promise.all([p.getTransactionReceipt(txHash), p.getTransaction(txHash)]);
  if (!receiptInput || !txInput) throw Error("Missing transaction or receipt");
  // Provider objects remain caller-owned. Copy all retained evidence before another await.
  const receipt = {
    hash: receiptInput.hash, status: receiptInput.status, blockNumber: receiptInput.blockNumber,
    blockHash: receiptInput.blockHash, to: receiptInput.to, from: receiptInput.from,
    logs: dense(receiptInput.logs, 4096).map(log => ({
      address: address(log.address), topics: dense(log.topics, 4).map(hash), data: bytes(log.data),
      index: integer(log.index), removed: log.removed, transactionHash: log.transactionHash,
      blockHash: log.blockHash, blockNumber: log.blockNumber,
    })),
  };
  const tx = {
    hash: txInput.hash, chainId: txInput.chainId, blockNumber: txInput.blockNumber,
    blockHash: txInput.blockHash, to: txInput.to, from: txInput.from, value: txInput.value,
    data: bytes(txInput.data, REVENUE_PULL_MAX_BYTES * 2),
  };
  if (receipt.status !== 1 || hash(receipt.hash) !== txHash || hash(tx.hash) !== txHash
    || tx.chainId !== capture.deployment.chainId || receipt.blockNumber <= capture.blockNumber
    || receipt.blockNumber !== tx.blockNumber || tx.blockHash !== receipt.blockHash
    || receipt.to !== tx.to || receipt.from !== tx.from || tx.value !== 0n) throw Error("Receipt identity, success or chronology differs");
  const data = bytes(tx.data, REVENUE_PULL_MAX_BYTES * 2);
  if (execution === "direct") {
    if (address(tx.from) !== prepared.caller || address(tx.to) !== prepared.target || data !== prepared.call.data) throw Error("Direct transaction differs");
  } else {
    if (address(tx.to) !== prepared.caller) throw Error("Safe target differs");
    const values = safeAbi.decodeFunctionData("execTransaction", data);
    if (safeAbi.encodeFunctionData("execTransaction", values).toLowerCase() !== data || values[0] !== prepared.target
      || values[1] !== 0n || values[2] !== prepared.call.data || values[3] !== 0n) throw Error("Safe requires exact ordinary zero-value CALL");
  }
  const tag = integer(receipt.blockNumber);
  const h = await block(p, tag);
  if (h.hash !== hash(receipt.blockHash)) throw Error("Receipt block is not canonical");
  const rawLogs = dense(receipt.logs, 4096).map(log => {
    if (log.removed || log.transactionHash !== txHash || log.blockHash !== h.hash || log.blockNumber !== tag) throw Error("Log identity differs");
    return { address: address(log.address), topics: dense(log.topics, 4).map(hash),
      data: bytes(log.data), index: integer(log.index) };
  });
  if (rawLogs.some((x, i) => i > 0 && x.index <= rawLogs[i - 1]!.index)) throw Error("Log indices must strictly increase");
  let safeIndex: number | null = null;
  if (execution === "safe") {
    const successes = rawLogs.filter(x => x.address === prepared.caller && (
      x.topics[0] === safeEvents.getEvent("ExecutionSuccess")!.topicHash
      || x.topics[0] === safeEvents.getEvent("ExecutionFailure")!.topicHash));
    if (successes.length !== 1) throw Error("Ambiguous Safe execution events");
    requireSafeExecution({ status: 1, logs: rawLogs }, prepared.caller, safeHash!);
    safeIndex = successes[0]!.index;
  }
  const prior = await captureRevenuePull(p, capture.deployment, prepared, { blockTag: tag - 1 });
  const observed = await captureRevenuePull(p, capture.deployment, prepared, { blockTag: tag });
  const walletTargets = new Set(capture.wallets.map(x => x.profile.wallet));
  const rows: EventRow[] = [];
  for (const log of rawLogs) {
    const abi = walletTargets.has(log.address) ? walletAbi
      : capture.deployment.router?.address === log.address ? routerAbi : null;
    if (!abi || !log.topics.length) continue;
    let parsed;
    try { parsed = abi.parseLog({ topics: [...log.topics], data: log.data }); } catch { throw Error("Malformed original event"); }
    if (!parsed) continue;
    const encoded = abi.encodeEventLog(parsed.fragment, parsed.args);
    equal(encoded.topics.map(x => x.toLowerCase()), log.topics, "Noncanonical event topics");
    if (encoded.data.toLowerCase() !== log.data) throw Error("Noncanonical event data");
    if (safeIndex !== null && log.index >= safeIndex) throw Error("Wallet/router event follows Safe execution success");
    rows.push({ address: log.address, name: parsed.name, args: Array.from(parsed.args), index: log.index });
  }
  const events: RevenuePullEvent[] = [];
  const items: RevenuePullItemReceipt[] = [];
  let cursor = 0;
  const seenInitialized = new Set(prior.assets.filter(x => x.initialized).map(x => `${x.wallet}:${x.asset}`));
  const totals = new Map<string, bigint>();
  const accountAmounts = new Map<string, bigint>();
  const lastObserved = new Map<string, bigint>();
  const localObservations = new Set<string>();
  const localReleases = new Set<string>();
  for (const a of prior.assets) {
    totals.set(`${a.wallet}:${a.asset}`, a.totalReleased);
    lastObserved.set(`${a.wallet}:${a.asset}`, a.lastObservedReceived);
  }
  function consume(row: EventRow): void {
    if (rows[cursor] !== row) throw Error("Ambiguous callback event order");
    events.push({ address: row.address, name: row.name, logIndex: row.index });
    cursor++;
  }
  function observation(item: RevenuePullClaim): boolean {
    const row = rows[cursor];
    if (!row || row.address !== item.wallet || !["AssetObservationInitialized", "AssetSynced"].includes(row.name)) return false;
    const profile = capture.wallets.find(x => x.profile.wallet === item.wallet)!.profile;
    if (row.args[0] !== profile.profileId || row.args[1] !== item.asset) throw Error("Observation profile or asset differs");
    const key = `${item.wallet}:${item.asset}`;
    const last = lastObserved.get(key) ?? 0n;
    let next: bigint;
    if (row.name === "AssetObservationInitialized") {
      if (seenInitialized.has(key)) throw Error("Repeated observation initialization");
      next = uint(row.args[2]);
    } else {
      const previous = uint(row.args[2]);
      next = uint(row.args[3]);
      if (previous < last || localObservations.has(key) && previous !== last || next <= previous) {
        throw Error("Observation high-water progression differs");
      }
    }
    seenInitialized.add(key);
    lastObserved.set(key, next);
    localObservations.add(key);
    consume(row);
    return true;
  }
  function failure(item: RevenuePullClaim, index: number): RevenuePullFailure | null {
    const row = rows[cursor];
    if (!row || row.name !== "ClaimFailed") return null;
    const r = prepared.request;
    if (!isRevenuePullRouterRequest(r) || !r.continueOnFailure || row.address !== prepared.target
      || row.args[0] !== item.wallet || row.args[1] !== item.asset || row.args[2] !== item.account
      || row.args[3] !== 1n || row.args[4] !== BigInt(index)) throw Error("Claim failure index or identity differs");
    const operation = row.args[5] === walletAbi.getFunction("syncAsset")!.selector ? "syncAsset"
      : row.args[5] === walletAbi.getFunction("release")!.selector ? "release" : null;
    if (!operation || operation === "syncAsset" && r.kind !== "syncAndClaimMany") throw Error("Unexpected failed operation");
    const returnDataSize = uint(row.args[6]);
    const reason = bytes(row.args[7], 256);
    // Authenticated original wallets only revert on failure. Router-local shape errors indicate
    // an incompatible target/result; a revert prefix is opaque and may be truncated ABI bytes.
    if (BigInt((reason.length - 2) / 2) !== (returnDataSize > 256n ? 256n : returnDataSize)) throw Error("Failure reason length differs from original revert prefix");
    consume(row);
    return { operation, returnDataSize, reason };
  }
  function release(item: RevenuePullClaim, recipient: Address): bigint {
    const row = rows[cursor];
    const native = item.asset === ZeroAddress;
    const profile = capture.wallets.find(x => x.profile.wallet === item.wallet)!.profile;
    if (!row || row.address !== item.wallet || row.name !== (native ? "NativeReleased" : "ERC20Released")) {
      throw Error("Missing release event or ambiguous callback order");
    }
    const a = row.args;
    const offset = native ? 0 : 1;
    if (a[0] !== profile.profileId || !native && a[1] !== item.asset
      || a[1 + offset] !== item.account || a[2 + offset] !== recipient) throw Error("Release event identity differs");
    const amount = uint(a[3 + offset]), total = uint(a[4 + offset]), received = uint(a[5 + offset]);
    const key = `${item.wallet}:${item.asset}`;
    if (!amount || total < (totals.get(key) ?? 0n) + amount || received < (lastObserved.get(key) ?? 0n)) throw Error("Release cumulative accounting differs");
    if (localReleases.has(key) && total !== totals.get(key)! + amount
      || localObservations.has(key) && received !== lastObserved.get(key)) throw Error("In-receipt accounting progression differs");
    if (!seenInitialized.has(key)) throw Error("Release lacks observation initialization history");
    totals.set(key, total); lastObserved.set(key, received);
    localReleases.add(key); localObservations.add(key);
    const accountKey = `${key}:${item.account}`;
    accountAmounts.set(accountKey, (accountAmounts.get(accountKey) ?? 0n) + amount);
    consume(row);
    return amount;
  }
  const request = prepared.request;
  let synchronization: RevenuePullReceipt["synchronization"] = "not-requested";
  if (request.kind === "syncAsset") {
    const item = claims(prepared)[0]!;
    const emitted = observation(item);
    if (!emitted && !seenInitialized.has(`${item.wallet}:${item.asset}`)) throw Error("Eventless sync lacks prior initialized observation");
    synchronization = emitted ? "observation-event" : "eventless-with-prior-initialization";
  } else if (request.kind === "revokeReleaseAuthorization" || request.kind === "revokeReleaseAuthorizationBySignature") {
    const row = rows[cursor];
    const n = observed.nonce!;
    if (!row || row.address !== prepared.target || row.name !== "ReleaseAuthorizationRevoked"
      || row.args[0] !== n.account || row.args[1] !== n.nonce || row.args[2] !== 1n || !n.used || prior.nonce!.used) {
      throw Error("Revocation event or nonce history differs");
    }
    if (request.kind === "revokeReleaseAuthorizationBySignature" && h.timestamp > request.deadline) {
      throw Error("Signed revocation mined after deadline");
    }
    consume(row);
  } else {
    for (const [index, item] of claims(prepared).entries()) {
      const syncing = request.kind === "syncAndClaimMany";
      const firstObservation = observation(item);
      let failed = failure(item, index);
      if (failed?.operation === "syncAsset") {
        if (firstObservation) throw Error("Failed sync cannot retain its reverted observation");
        items.push({ index, claim: item, recipient: item.account, amount: null, sync: "failed", outcome: "failed", failure: failed });
        continue;
      }
      if (syncing && !seenInitialized.has(`${item.wallet}:${item.asset}`)) throw Error("Successful eventless sync lacks initialization history");
      if (failed) {
        if (!syncing && firstObservation) throw Error("Failed release cannot retain its reverted observation");
        items.push({ index, claim: item, recipient: item.account, amount: null,
          sync: syncing ? "retained" : "not-requested", outcome: "failed", failure: failed });
        continue;
      }
      // Sync and release can each observe a new receipt; the latter needs its own event.
      if (syncing) observation(item);
      failed = failure(item, index);
      if (failed) throw Error("Failure after a second observation is incompatible with original rollback");
      const recipient = request.kind === "release" ? request.recipient
        : request.kind === "releaseWithAuthorization" ? request.authorization.recipient : item.account;
      const amount = release(item, recipient);
      if (request.kind === "releaseWithAuthorization" && (amount !== request.authorization.releasableSnapshot
        || !observed.nonce!.used || prior.nonce!.used || h.timestamp > request.authorization.deadline)) throw Error("Signed release amount, nonce or deadline differs");
      items.push({ index, claim: item, recipient, amount, sync: syncing ? "retained" : "not-requested", outcome: "released", failure: null });
    }
  }
  if (cursor !== rows.length) throw Error("Unattributed original events or ambiguous callback activity");
  for (const a of observed.assets) {
    const key = `${a.wallet}:${a.asset}`;
    const previous = prior.assets.find(x => x.wallet === a.wallet && x.asset === a.asset && x.account === a.account)!;
    if (a.totalReleased < (totals.get(key) ?? 0n)
      || a.accountReleased < previous.accountReleased + (accountAmounts.get(`${key}:${a.account}`) ?? 0n)
      || seenInitialized.has(key) && (!a.initialized || a.lastObservedReceived < (lastObserved.get(key) ?? 0n))) {
      throw Error("End-block accounting does not retain receipt effects");
    }
  }
  if (safeIndex !== null) events.push({ address: prepared.caller, name: "ExecutionSuccess", logIndex: safeIndex });
  await unchanged(p, h);
  return freeze({ capture, transactionHash: txHash, blockNumber: tag, blockHash: h.hash, prior, observed,
    items, events, synchronization,
    stateAttribution: "event-local payments; end-block state may include other transactions; ambiguous callback logs rejected" });
}
