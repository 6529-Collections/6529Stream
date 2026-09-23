import {
  type Address, type Hex, type RoleRegistryOperationalCoordinates,
  type RoleRegistryOperationalState, type RoleRegistryOperationalDeployment,
  type RoleRegistryOperationalSafeDeployment, type RoleRegistryOperationalReceiptReader,
  type RoleRegistryOperationalCapture, type RoleRegistryOperationalHistory,
  ROLE_REGISTRY_OPERATIONAL_ROLES, prepareRoleRegistryOperationalCall,
  prepareRoleRegistryOperationalRead, roleRegistryOperationalTransition,
  captureRoleRegistryOperational, simulateRoleRegistryOperational,
  reconcileRoleRegistryOperationalReceipt, inspectRoleRegistryOperationalHistory,
  inspectRoleRegistryOperationalCurrent, probeRoleRegistryOperationalRefusal,
} from "../src/index.js";
declare const c: RoleRegistryOperationalCoordinates;
declare const actor: Address;
declare const holder: Address;
declare const hash: Hex;
declare const state: RoleRegistryOperationalState;
declare const d: RoleRegistryOperationalDeployment;
declare const safe: RoleRegistryOperationalSafeDeployment;
declare const provider: RoleRegistryOperationalReceiptReader;
declare const capture: RoleRegistryOperationalCapture;
declare const history: RoleRegistryOperationalHistory;
const role: Hex = ROLE_REGISTRY_OPERATIONAL_ROLES.ROLE_FIXITY_OPERATOR;
const grant = prepareRoleRegistryOperationalCall(c, actor, { kind: "grantRole", role, holder });
const revoke = prepareRoleRegistryOperationalCall(c, actor, { kind: "revokeRole", role, holder });
const unverified: false = grant.factsVerified;
const transition = roleRegistryOperationalTransition(revoke, state);
const moved: Address | null = transition.movedHolder;
prepareRoleRegistryOperationalRead(c.registry, { kind: "roleHolderAt", role, index: 0n });
const options = { blockTag: 100, gasLimit: 1_000_000n };
void captureRoleRegistryOperational(provider, d, grant, options);
void captureRoleRegistryOperational(provider, d, grant, { ...options, safe });
void simulateRoleRegistryOperational(provider, capture, options);
void reconcileRoleRegistryOperationalReceipt(provider, capture, hash, { execution: "direct" });
void inspectRoleRegistryOperationalHistory(provider, d, grant, hash, { execution: "safe", safe, expectedSafeTxHash: hash });
void inspectRoleRegistryOperationalCurrent(provider, history, { blockTag: 101 });
void probeRoleRegistryOperationalRefusal(provider, capture, options);
void [unverified, moved];
// @ts-expect-error RoleManager registration is not an operational membership mutation.
prepareRoleRegistryOperationalCall(c, actor, { kind: "setRoleManager", account: holder, enabled: true });
// @ts-expect-error Role grant class is derived by the original registry.
prepareRoleRegistryOperationalCall(c, actor, { kind: "grantRole", role, holder, grantClass: 2n });
// @ts-expect-error Governance action context cannot be injected into direct RoleManager calls.
prepareRoleRegistryOperationalCall(c, actor, { kind: "grantRole", role, holder, actionId: hash });
// @ts-expect-error No mutation through the closed read planner.
prepareRoleRegistryOperationalRead(c.registry, { kind: "grantRole", role, holder });
// @ts-expect-error Holder indices use bigint.
prepareRoleRegistryOperationalRead(c.registry, { kind: "roleHolderAt", role, index: 0 });
// @ts-expect-error Captured state is deeply immutable.
capture.before.holders.push(holder);
// @ts-expect-error Capture cannot assert simulation occurred.
const simulated: true = capture.originalCallSimulated;
// @ts-expect-error Historical receipt authentication is separate from current authority.
const current: true = history.currentAuthorityVerified;
// @ts-expect-error Safe receipt evidence requires singleton, runtime and version pins.
void inspectRoleRegistryOperationalHistory(provider, d, grant, hash, { execution: "safe", expectedSafeTxHash: hash });
void [simulated, current];
