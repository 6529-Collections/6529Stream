import { getAddress } from "ethers";
import { createSafeCallPlan, safeCallInventory } from "../dist/safe-plan.js";

const userMethods = Object.freeze({
  sale: Object.freeze(["configureCollectionSigner", "registerPrimaryOffer", "revokeAuthorization",
    "cancelPrimaryOffer", "expirePrimaryOffer", "setPaused", "setSalePaused", "syncCollectionContest",
    "raiseGasParameter", "transferOwnership", "renounceOwnership"]),
  payment: Object.freeze(["settleERC20PrimarySaleByPayer", "settleERC20PrimarySaleWithIntent",
    "settleERC20PrimarySaleWithEIP2612Permit", "settleERC20PrimarySaleWithPermit2",
    "revokePaymentIntent", "revokePaymentIntentWithSignature"]),
  manager: Object.freeze(["voidMintOffer"]),
  token: Object.freeze(["approve"]),
});

/** Inventory user-entry CALLs from exact caller-supplied compiled ABIs. */
export function erc20PrimaryOfferSafeInventory(catalog) {
  return Object.freeze(Object.entries(userMethods).flatMap(([kind, names]) => {
    if (!catalog[kind]) throw Error(`Missing compiled ${kind} ABI`);
    const inventory = safeCallInventory(catalog[kind]).filter(row => names.includes(row.method.split("(")[0]));
    if (inventory.length !== names.length || inventory.some(row => row.payable)) {
      throw Error(`Incomplete or payable ${kind} user CALL inventory`);
    }
    return inventory.map(row => Object.freeze({ kind, ...row }));
  }));
}

/**
 * Review already-prepared actions with their actual Safe callers. Execution order
 * is explicit. This never signs, submits, downloads artifacts or retries a call.
 */
export function createERC20PrimaryOfferSafeReview({ chainId, title, catalog, actions }) {
  const inventory = erc20PrimaryOfferSafeInventory(catalog);
  const plan = createSafeCallPlan(chainId, title, actions.map(({ kind, safe, intent, prepared }) => {
    if (!Object.hasOwn(userMethods, kind)) throw Error("Unknown ERC20 offer action kind");
    if (getAddress(safe) !== getAddress(prepared.caller)) throw Error("Safe differs from the prepared actual caller");
    if (prepared.call.value !== 0n) throw Error("ERC20 primary offer CALLs require zero native value");
    return { safe, intent, call: prepared.call, abi: catalog[kind] };
  }));
  for (const [index, step] of plan.steps.entries()) {
    if (!inventory.some(row => row.kind === actions[index].kind && row.method === step.method)) {
      throw Error("Protocol callback is not a user-entry Safe action");
    }
  }
  return Object.freeze({ plan, abis: Object.freeze(actions.map(action => catalog[action.kind])), inventory });
}
