import { Interface, ZeroAddress, getAddress, isHexString } from "ethers";
import type { Address, Hex } from "./generated/contracts.js";
import type { UnsignedCall } from "./binding.js";
import { createSafeCallPlan } from "./safe-plan.js";
import type { SafeCallPlan } from "./safe-plan.js";
import type { SplitWalletReleaseAuthorization } from "./current-split-factory.js";

export const REVENUE_PULL_SOURCE = "d88ee108080ba1e66f1b8a9b49e3fd9a59d35c4a";
/** Client allocation limits. The original router has no fixed batch limit. */
export const REVENUE_PULL_MAX_CLAIMS = 64;
export const REVENUE_PULL_MAX_BYTES = 65_536;

export interface RevenuePullClaim {
  readonly wallet: Address;
  readonly asset: Address;
  readonly account: Address;
}

export type RevenuePullRequest =
  | { readonly kind: "syncAsset"; readonly asset: Address }
  | { readonly kind: "release"; readonly asset: Address; readonly account: Address; readonly recipient: Address }
  | { readonly kind: "releaseWithAuthorization"; readonly authorization: SplitWalletReleaseAuthorization; readonly signature: Hex }
  | { readonly kind: "revokeReleaseAuthorization"; readonly nonce: Hex }
  | { readonly kind: "revokeReleaseAuthorizationBySignature"; readonly account: Address; readonly nonce: Hex; readonly deadline: bigint; readonly signature: Hex }
  | { readonly kind: "claimMany" | "syncAndClaimMany"; readonly claims: readonly RevenuePullClaim[]; readonly continueOnFailure: boolean };

export interface PreparedRevenuePullCall {
  readonly target: Address;
  readonly caller: Address;
  readonly request: RevenuePullRequest;
  readonly call: UnsignedCall;
  readonly factsVerified: false;
}

export const REVENUE_PULL_AUTHORIZATION_TUPLE = "tuple(address asset,address account,address recipient,uint256 releasableSnapshot,bytes32 nonce,uint64 deadline)";
export const REVENUE_PULL_CLAIM_TUPLE = "tuple(address wallet,address asset,address account)";
export const REVENUE_PULL_WALLET_ABI = Object.freeze([
  "function syncAsset(address asset) returns(uint256 observed)",
  "function release(address asset,address account,address recipient) returns(uint256 amount)",
  `function releaseWithAuthorization(${REVENUE_PULL_AUTHORIZATION_TUPLE} authorization,bytes signature) returns(uint256 amount)`,
  "function revokeReleaseAuthorization(bytes32 nonce)",
  "function revokeReleaseAuthorizationBySignature(address account,bytes32 nonce,uint64 deadline,bytes signature)",
  "function aggregateSharePpm(address account) view returns(uint32)",
  "function accountReleased(address asset,address account) view returns(uint256)",
  "function totalReleased(address asset) view returns(uint256)",
  "function assetObservationInitialized(address asset) view returns(bool)",
  "function lastObservedReceived(address asset) view returns(uint256)",
  "function observedReceived(address asset) view returns(uint256)",
  "function releasable(address asset,address account) view returns(uint256)",
  "function isReleaseAuthorizationNonceUsed(address account,bytes32 nonce) view returns(bool)",
  `function releaseAuthorizationDigest(${REVENUE_PULL_AUTHORIZATION_TUPLE} authorization) view returns(bytes32)`,
  "function releaseRevocationDigest(address account,bytes32 nonce,uint64 deadline) view returns(bytes32)",
  "function domainSeparator() view returns(bytes32)",
  "event AssetObservationInitialized(bytes32 indexed profileId,address indexed asset,uint256 observedReceived)",
  "event AssetSynced(bytes32 indexed profileId,address indexed asset,uint256 previousObservedReceived,uint256 observedReceived)",
  "event NativeReleased(bytes32 indexed profileId,address indexed account,address indexed recipient,uint256 amount,uint256 totalReleased,uint256 observedReceived)",
  "event ERC20Released(bytes32 indexed profileId,address indexed asset,address indexed account,address recipient,uint256 amount,uint256 totalReleased,uint256 observedReceived)",
  "event ReleaseAuthorizationRevoked(address indexed account,bytes32 indexed nonce,uint16 schemaVersion)",
]);
export const REVENUE_PULL_ROUTER_ABI = Object.freeze([
  `function claimMany(${REVENUE_PULL_CLAIM_TUPLE}[] claims,bool continueOnFailure) returns(uint256[] releasedAmounts)`,
  `function syncAndClaimMany(${REVENUE_PULL_CLAIM_TUPLE}[] claims,bool continueOnFailure) returns(uint256[] releasedAmounts)`,
  "event ClaimFailed(address indexed wallet,address indexed asset,address indexed account,uint16 schemaVersion,uint256 claimIndex,bytes4 operation,uint256 returnDataSize,bytes reason)",
  "error ClaimTargetHasNoCode(address wallet)",
  "error InvalidClaimReturnData(uint256 returnDataSize)",
  "error ClaimCallFailed(uint256 claimIndex,address wallet,bytes4 operation,uint256 returnDataSize,bytes reason)",
]);
const wallet = new Interface(REVENUE_PULL_WALLET_ABI);
const router = new Interface(REVENUE_PULL_ROUTER_ABI);

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
function bytes(value: unknown, size?: number): Hex {
  if (typeof value !== "string" || !isHexString(value, size ?? true)
    || (value.length - 2) / 2 > REVENUE_PULL_MAX_BYTES) throw Error("Malformed or oversized bytes");
  return value.toLowerCase() as Hex;
}
function freeze<T>(value: T): T {
  if (value && typeof value === "object") {
    Object.values(value).forEach(freeze);
    Object.freeze(value);
  }
  return value;
}
function authorization(value: SplitWalletReleaseAuthorization): SplitWalletReleaseAuthorization {
  exact(value, ["asset", "account", "recipient", "releasableSnapshot", "nonce", "deadline"]);
  return freeze({
    asset: address(value.asset, true), account: address(value.account), recipient: address(value.recipient),
    releasableSnapshot: uint(value.releasableSnapshot), nonce: bytes(value.nonce, 32), deadline: uint(value.deadline, 64),
  });
}

/** Snapshot transport fields without inventing current balance, signature validity or asset eligibility. */
export function normalizeRevenuePullRequest(value: RevenuePullRequest): RevenuePullRequest {
  if (!value || typeof value !== "object") throw Error("Expected pull request");
  switch (value.kind) {
    case "syncAsset":
      exact(value, ["kind", "asset"]);
      return freeze({ kind: value.kind, asset: address(value.asset, true) });
    case "release":
      exact(value, ["kind", "asset", "account", "recipient"]);
      return freeze({ kind: value.kind, asset: address(value.asset, true), account: address(value.account), recipient: address(value.recipient) });
    case "releaseWithAuthorization":
      exact(value, ["kind", "authorization", "signature"]);
      return freeze({ kind: value.kind, authorization: authorization(value.authorization), signature: bytes(value.signature) });
    case "revokeReleaseAuthorization":
      exact(value, ["kind", "nonce"]);
      return freeze({ kind: value.kind, nonce: bytes(value.nonce, 32) });
    case "revokeReleaseAuthorizationBySignature":
      exact(value, ["kind", "account", "nonce", "deadline", "signature"]);
      return freeze({ kind: value.kind, account: address(value.account), nonce: bytes(value.nonce, 32), deadline: uint(value.deadline, 64), signature: bytes(value.signature) });
    case "claimMany":
    case "syncAndClaimMany": {
      exact(value, ["kind", "claims", "continueOnFailure"]);
      if (!Array.isArray(value.claims) || value.claims.length > REVENUE_PULL_MAX_CLAIMS
        || Object.keys(value.claims).length !== value.claims.length || typeof value.continueOnFailure !== "boolean") {
        throw Error("Expected dense bounded claims and boolean mode");
      }
      const claims = value.claims.map(row => {
        exact(row, ["wallet", "asset", "account"]);
        // Raw router transport allows zero/no-code targets and accounts; verified workflow pins targets.
        return { wallet: address(row.wallet, true), asset: address(row.asset, true), account: address(row.account, true) };
      });
      return freeze({ kind: value.kind, claims, continueOnFailure: value.continueOnFailure });
    }
    default: throw Error("Unsupported revenue pull method");
  }
}

export function isRevenuePullRouterRequest(
  value: RevenuePullRequest,
): value is Extract<RevenuePullRequest, { readonly kind: "claimMany" | "syncAndClaimMany" }> {
  return value.kind === "claimMany" || value.kind === "syncAndClaimMany";
}

export function prepareRevenuePullCall(
  target: Address,
  caller: Address,
  input: RevenuePullRequest,
): PreparedRevenuePullCall {
  const to = address(target);
  const actor = address(caller);
  const request = normalizeRevenuePullRequest(input);
  let args: readonly unknown[];
  switch (request.kind) {
    case "syncAsset": args = [request.asset]; break;
    case "release":
      if (request.recipient !== request.account && actor !== request.account) throw Error("Alternate recipient requires actual account caller");
      args = [request.asset, request.account, request.recipient]; break;
    case "releaseWithAuthorization": args = [request.authorization, request.signature]; break;
    case "revokeReleaseAuthorization": args = [request.nonce]; break;
    case "revokeReleaseAuthorizationBySignature": args = [request.account, request.nonce, request.deadline, request.signature]; break;
    default: args = [request.claims, request.continueOnFailure];
  }
  const abi = isRevenuePullRouterRequest(request) ? router : wallet;
  const data = bytes(abi.encodeFunctionData(request.kind, args));
  return freeze({ target: to, caller: actor, request, call: { to, value: 0n, data }, factsVerified: false });
}

export function normalizeRevenuePullCall(value: PreparedRevenuePullCall): PreparedRevenuePullCall {
  exact(value, ["target", "caller", "request", "call", "factsVerified"]);
  exact(value.call, ["to", "value", "data"]);
  const result = prepareRevenuePullCall(value.target, value.caller, value.request);
  if (value.factsVerified !== false || address(value.call.to) !== result.target
    || value.call.value !== 0n || bytes(value.call.data) !== result.call.data) throw Error("Prepared pull call differs");
  return result;
}

export function revenuePullSafePlan(
  chainId: bigint,
  input: PreparedRevenuePullCall,
  title: string,
): SafeCallPlan {
  const prepared = normalizeRevenuePullCall(input);
  return createSafeCallPlan(chainId, title, [{
    safe: prepared.caller, intent: prepared.request.kind, call: prepared.call,
    abi: isRevenuePullRouterRequest(prepared.request) ? REVENUE_PULL_ROUTER_ABI : REVENUE_PULL_WALLET_ABI,
  }]);
}

/** Original saturating full entitlement. Inputs are supplied facts, not an onchain observation. */
export function revenuePullEntitlement(
  balance: bigint,
  totalReleased: bigint,
  sharePpm: bigint,
  accountReleased: bigint,
): { readonly observedReceived: bigint; readonly releasable: bigint } {
  const observedReceived = uint(uint(balance) + uint(totalReleased));
  const share = uint(sharePpm, 32);
  if (share > 1_000_000n) throw Error("Share exceeds initialized profile denominator");
  const entitlement = observedReceived * share / 1_000_000n;
  const released = uint(accountReleased);
  return freeze({ observedReceived, releasable: entitlement > released ? entitlement - released : 0n });
}
