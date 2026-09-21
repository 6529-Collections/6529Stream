/** Closed direct RoleManager profile at the original ABI164 source. No RPC or signing. */
import { Interface, id, keccak256 } from "ethers";
import type { Address, Hex } from "./generated/contracts.js";
import type { UnsignedCall } from "./client.js";
import * as io from "./current-scoped-policy-inventory-archive-workflow-internal.js";

export const ROLE_REGISTRY_OPERATIONAL_SOURCE_COMMIT = "eda052c75dc9fd5c4e2e658bdf453ab01f5b7c0e";
/** Allocation limits of this client, not limits on the original role set. */
export const ROLE_REGISTRY_OPERATIONAL_MAX_HOLDERS = 1024;
export const ROLE_REGISTRY_OPERATIONAL_ROLES = Object.freeze({
  ROLE_ENTROPY_INCIDENT_DECLARER: id("ROLE_ENTROPY_INCIDENT_DECLARER") as Hex,
  ROLE_ENTROPY_REVEAL_OWNER: id("ROLE_ENTROPY_REVEAL_OWNER") as Hex,
  ROLE_ARTIST_REGISTRY_ADMIN: id("ROLE_ARTIST_REGISTRY_ADMIN") as Hex,
  ROLE_FIXITY_OPERATOR: id("ROLE_FIXITY_OPERATOR") as Hex,
  ROLE_EXPORT_PUBLISHER: id("ROLE_EXPORT_PUBLISHER") as Hex,
  ROLE_CLAIM_ROUTER_OPERATOR: id("ROLE_CLAIM_ROUTER_OPERATOR") as Hex,
  ROLE_ENTROPY_ADMIN: id("ROLE_ENTROPY_ADMIN") as Hex,
});
export const ROLE_REGISTRY_OPERATIONAL_ABI = Object.freeze([
  "function grantRole(bytes32 role,address holder)",
  "function revokeRole(bytes32 role,address holder)",
  "function owner() view returns (address)",
  "function SCHEMA_VERSION() view returns (uint16)",
  "function supportsInterface(bytes4 interfaceId) pure returns (bool)",
  "function isRoleManager(address account) view returns (bool)",
  "function roleManagerConfigMutationState(address account) view returns (bytes32 chainHash,uint64 revision)",
  "function hasRole(bytes32 role,address account) view returns (bool)",
  "function roleGrantClass(bytes32 role) pure returns (uint8)",
  "function roleHolderCount(bytes32 role) view returns (uint256)",
  "function roleHolderAt(bytes32 role,uint256 index) view returns (address)",
  "function roleMutationState(bytes32 role) view returns (bytes32 chainHash,uint64 revision)",
  "function globalRoleMutationState() view returns (bytes32 chainHash,uint64 revision)",
  "event StreamRoleGranted(uint16 schemaVersion,bytes32 indexed role,address indexed holder,uint8 grantClass,address actor,bytes32 indexed actionId)",
  "event StreamRoleRevoked(uint16 schemaVersion,bytes32 indexed role,address indexed holder,uint8 grantClass,address actor,bytes32 indexed actionId)",
  "event RoleMutationCommitted(uint16 schemaVersion,bytes32 indexed role,address indexed holder,bool granted,bytes32 roleChainHash,uint64 roleRevision,bytes32 globalChainHash,uint64 globalRevision,bytes32 indexed actionId)",
] as const);
const abi = new Interface(ROLE_REGISTRY_OPERATIONAL_ABI);
export function roleRegistryOperationalInterface(): Interface { return new Interface(ROLE_REGISTRY_OPERATIONAL_ABI); }

export interface RoleRegistryOperationalCoordinates { readonly chainId: bigint; readonly registry: Address; readonly executor: Address }
export interface RoleRegistryOperationalRequest { readonly kind: "grantRole" | "revokeRole"; readonly role: Hex; readonly holder: Address }
export interface RoleRegistryOperationalCall {
  readonly coordinates: RoleRegistryOperationalCoordinates;
  readonly caller: Address;
  readonly request: RoleRegistryOperationalRequest;
  readonly call: UnsignedCall;
  readonly factsVerified: false;
}
export interface RoleRegistryOperationalChain { readonly chainHash: Hex; readonly revision: bigint }
export interface RoleRegistryOperationalState {
  readonly holders: readonly Address[];
  readonly roleState: RoleRegistryOperationalChain;
  readonly globalState: RoleRegistryOperationalChain;
  readonly managerEnabled: boolean;
  readonly managerState: RoleRegistryOperationalChain;
}
export interface RoleRegistryOperationalTransition {
  readonly before: RoleRegistryOperationalState;
  readonly after: RoleRegistryOperationalState;
  readonly granted: boolean;
  readonly removedIndex: number | null;
  readonly movedHolder: Address | null;
  readonly factsVerified: false;
}
export function normalizeRoleRegistryOperationalCoordinates(v: RoleRegistryOperationalCoordinates): RoleRegistryOperationalCoordinates {
  io.keys(v, ["chainId", "registry", "executor"]);
  const chainId = io.uint(v.chainId), registry = io.address(v.registry), executor = io.address(v.executor);
  if (chainId === 0n || registry === executor) throw Error("Invalid role registry coordinates");
  return io.freeze({ chainId, registry, executor });
}
export function normalizeRoleRegistryOperationalRole(v: unknown): Hex {
  const role = io.hash(v);
  if (!Object.values(ROLE_REGISTRY_OPERATIONAL_ROLES).includes(role)) throw Error("Only seven operational roles are supported");
  return role;
}
export function normalizeRoleRegistryOperationalRequest(v: RoleRegistryOperationalRequest): RoleRegistryOperationalRequest {
  io.keys(v, ["kind", "role", "holder"]);
  if (v.kind !== "grantRole" && v.kind !== "revokeRole") throw Error("Unsupported operational write");
  return io.freeze({ kind: v.kind, role: normalizeRoleRegistryOperationalRole(v.role), holder: io.address(v.holder) });
}
export function normalizeRoleRegistryOperationalChain(v: RoleRegistryOperationalChain): RoleRegistryOperationalChain {
  io.keys(v, ["chainHash", "revision"]);
  return io.freeze({ chainHash: io.hash(v.chainHash, true), revision: io.uint(v.revision, 64) });
}
export function normalizeRoleRegistryOperationalState(v: RoleRegistryOperationalState): RoleRegistryOperationalState {
  io.keys(v, ["holders", "roleState", "globalState", "managerEnabled", "managerState"]);
  if (!Array.isArray(v.holders) || v.holders.length > ROLE_REGISTRY_OPERATIONAL_MAX_HOLDERS
    || Reflect.ownKeys(v.holders).length !== v.holders.length + 1) throw Error("Client holder list limit or shape");
  const holders: Address[] = [];
  for (let i = 0; i < v.holders.length; i++) {
    if (!Object.hasOwn(v.holders, i)) throw Error("Sparse holder list");
    holders.push(io.address(v.holders[i]));
  }
  if (new Set(holders).size !== holders.length) throw Error("Duplicate holder");
  if (typeof v.managerEnabled !== "boolean") throw Error("Expected manager flag");
  return io.freeze({ holders, roleState: normalizeRoleRegistryOperationalChain(v.roleState),
    globalState: normalizeRoleRegistryOperationalChain(v.globalState), managerEnabled: v.managerEnabled,
    managerState: normalizeRoleRegistryOperationalChain(v.managerState) });
}
/** Validate supplied source invariants. This does not prove a registry observation. */
export function validateRoleRegistryOperationalState(value: RoleRegistryOperationalState): RoleRegistryOperationalState {
  const v = normalizeRoleRegistryOperationalState(value);
  for (const row of [v.roleState, v.globalState, v.managerState]) {
    if ((row.revision === 0n) !== (row.chainHash === io.ZERO)) throw Error("Mutation chain/revision mismatch");
  }
  if (v.globalState.revision < v.roleState.revision || v.globalState.revision < v.managerState.revision
    || v.roleState.revision < BigInt(v.holders.length)
    || (v.managerEnabled && v.managerState.revision === 0n)) throw Error("Impossible supplied registry state");
  return v;
}
export function prepareRoleRegistryOperationalCall(
  coordinates: RoleRegistryOperationalCoordinates, caller: Address, request: RoleRegistryOperationalRequest,
): RoleRegistryOperationalCall {
  const c = normalizeRoleRegistryOperationalCoordinates(coordinates), actor = io.address(caller);
  if (actor === c.executor) throw Error("Executor-owned governance path is outside the direct RoleManager profile");
  const r = normalizeRoleRegistryOperationalRequest(request);
  return io.freeze({ coordinates: c, caller: actor, request: r,
    call: { to: c.registry, value: 0n, data: abi.encodeFunctionData(r.kind, [r.role, r.holder]) as Hex }, factsVerified: false });
}
export function normalizeRoleRegistryOperationalCall(v: RoleRegistryOperationalCall): RoleRegistryOperationalCall {
  io.keys(v, ["coordinates", "caller", "request", "call", "factsVerified"]);
  io.keys(v.call, ["to", "value", "data"]);
  if (v.factsVerified !== false) throw Error("Supplied facts cannot be promoted");
  const result = prepareRoleRegistryOperationalCall(v.coordinates, v.caller, v.request);
  if (!io.same(v.call.to, result.call.to) || io.uint(v.call.value) !== 0n
    || !io.same(io.bytes(v.call.data, 68), result.call.data)) throw Error("Prepared operational call differs");
  return result;
}
export function roleRegistryOperationalMutationHash(
  coordinates: RoleRegistryOperationalCoordinates, previous: RoleRegistryOperationalChain,
  request: RoleRegistryOperationalRequest, global: boolean,
): RoleRegistryOperationalChain {
  const c = normalizeRoleRegistryOperationalCoordinates(coordinates), p = normalizeRoleRegistryOperationalChain(previous), r = normalizeRoleRegistryOperationalRequest(request);
  if (typeof global !== "boolean" || p.revision === (1n << 64n) - 1n) throw Error("Role mutation revision overflow");
  const revision = p.revision + 1n;
  const domain = id(global ? "6529STREAM_GLOBAL_ROLE_MUTATION_V1" : "6529STREAM_ROLE_MUTATION_V1");
  return io.freeze({ chainHash: keccak256(io.coder.encode(
    ["bytes32", "bytes32", "uint256", "address", "bytes32", "address", "bool", "uint64"],
    [domain, p.chainHash, c.chainId, c.registry, r.role, r.holder, r.kind === "grantRole", revision],
  )) as Hex, revision });
}
export function roleRegistryOperationalTransition(
  call: RoleRegistryOperationalCall, supplied: RoleRegistryOperationalState,
): RoleRegistryOperationalTransition {
  const p = normalizeRoleRegistryOperationalCall(call), before = validateRoleRegistryOperationalState(supplied);
  if (!before.managerEnabled) throw Error("Caller is not a registered RoleManager");
  const granted = p.request.kind === "grantRole", holders = [...before.holders];
  const index = holders.indexOf(p.request.holder);
  if (granted ? index !== -1 : index === -1) throw Error(granted ? "Role already granted" : "Role not granted");
  let movedHolder: Address | null = null;
  if (granted) {
    if (holders.length === ROLE_REGISTRY_OPERATIONAL_MAX_HOLDERS) throw Error("Client holder list limit");
    holders.push(p.request.holder);
  } else {
    if (index !== holders.length - 1) { movedHolder = holders[holders.length - 1]!; holders[index] = movedHolder; }
    holders.pop();
  }
  const after = normalizeRoleRegistryOperationalState({ ...before, holders,
    roleState: roleRegistryOperationalMutationHash(p.coordinates, before.roleState, p.request, false),
    globalState: roleRegistryOperationalMutationHash(p.coordinates, before.globalState, p.request, true) });
  return io.freeze({ before, after, granted, removedIndex: granted ? null : index, movedHolder, factsVerified: false });
}

export type RoleRegistryOperationalRead =
  | Readonly<{ kind: "owner" | "SCHEMA_VERSION" | "globalRoleMutationState" }>
  | Readonly<{ kind: "isRoleManager" | "roleManagerConfigMutationState"; account: Address }>
  | Readonly<{ kind: "roleGrantClass" | "roleHolderCount" | "roleMutationState"; role: Hex }>
  | Readonly<{ kind: "hasRole"; role: Hex; account: Address }>
  | Readonly<{ kind: "roleHolderAt"; role: Hex; index: bigint }>;
export function prepareRoleRegistryOperationalRead(registry: Address, request: RoleRegistryOperationalRead): UnsignedCall {
  const target = io.address(registry); let args: readonly unknown[];
  switch (request.kind) {
    case "owner": case "SCHEMA_VERSION": case "globalRoleMutationState": io.keys(request, ["kind"]); args = []; break;
    case "isRoleManager": case "roleManagerConfigMutationState": io.keys(request, ["kind", "account"]); args = [io.address(request.account)]; break;
    case "roleGrantClass": case "roleHolderCount": case "roleMutationState": io.keys(request, ["kind", "role"]); args = [normalizeRoleRegistryOperationalRole(request.role)]; break;
    case "hasRole": io.keys(request, ["kind", "role", "account"]); args = [normalizeRoleRegistryOperationalRole(request.role), io.address(request.account)]; break;
    case "roleHolderAt": io.keys(request, ["kind", "role", "index"]); args = [normalizeRoleRegistryOperationalRole(request.role), io.uint(request.index)]; break;
    default: throw Error("Unsupported operational read");
  }
  return io.freeze({ to: target, value: 0n, data: abi.encodeFunctionData(request.kind, args) as Hex });
}
