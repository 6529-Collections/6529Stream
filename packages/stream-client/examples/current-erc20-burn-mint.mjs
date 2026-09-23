import { getAddress } from "ethers";
import { createSafeCallPlan, safeCallInventory } from "../dist/safe-plan.js";

const userMethods = Object.freeze({
  sale: Object.freeze(["registerSale", "cancelSale", "cancelAuthorization", "setPaused",
    "raiseGasParameter", "transferOwnership", "renounceOwnership"]),
  gate: Object.freeze(["configureProgram", "raiseGasParameter", "transferOwnership", "renounceOwnership"]),
  payment: Object.freeze(["settleERC20PrimarySaleByPayer", "settleERC20PrimarySaleWithIntent",
    "settleERC20PrimarySaleWithEIP2612Permit", "settleERC20PrimarySaleWithPermit2",
    "revokePaymentIntent", "revokePaymentIntentWithSignature"]),
  core: Object.freeze(["approve", "setApprovalForAll"]),
  token: Object.freeze(["approve"]),
});

/** Exact public user-entry inventory; guarded previews are simulated separately. */
export function erc20BurnMintSafeInventory(catalog) {
  return Object.freeze(Object.entries(userMethods).flatMap(([kind, names]) => {
    if (!catalog[kind]) throw Error(`Missing compiled ${kind} ABI`);
    const inventory = safeCallInventory(catalog[kind]).filter(row => names.includes(row.method.split("(")[0]));
    if (inventory.length !== names.length || inventory.some(row => row.payable)) {
      throw Error(`Incomplete or payable ${kind} user CALL inventory`);
    }
    return inventory.map(row => Object.freeze({ kind, ...row }));
  }));
}

/** Review actual Safe callers and ordered unsigned actions; never signs or sends. */
export function createERC20BurnMintSafeReview({ chainId, title, catalog, actions }) {
  const inventory = erc20BurnMintSafeInventory(catalog);
  const plan = createSafeCallPlan(chainId, title, actions.map(({ kind, safe, intent, prepared }) => {
    if (!Object.hasOwn(userMethods, kind)) throw Error("Unknown ERC20 burn-mint action kind");
    if (getAddress(safe) !== getAddress(prepared.caller)) throw Error("Safe differs from the prepared actual caller");
    if (prepared.call.value !== 0n) throw Error("ERC20 burn-mint CALLs require zero native value");
    return { safe, intent, call: prepared.call, abi: catalog[kind] };
  }));
  for (const [index, step] of plan.steps.entries()) {
    if (!inventory.some(row => row.kind === actions[index].kind && row.method === step.method)) {
      throw Error("Preview or protocol callback is not a user-entry Safe action");
    }
  }
  return Object.freeze({ plan, abis: Object.freeze(actions.map(action => catalog[action.kind])), inventory });
}
