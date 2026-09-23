import { createSafeCallPlan, simulateSafePlanStep } from "../src/index.js";
import type { Address, Hex, SafePlanInput, SafePlanRoute } from "../src/index.js";
declare const input: SafePlanInput;
const plan = createSafeCallPlan(31337n, "Call", [input]);
const receiveRouteName: SafePlanRoute = "receive";
const receiveRoute: SafePlanInput = { ...input, route: "receive", call: { ...input.call, data: "0x", value: 1n } };
const fallbackRoute: SafePlanInput = { ...input, route: "fallback" };
// @ts-expect-error raw dispatch routes are explicit and limited to Solidity receive/fallback
const invalidRoute: SafePlanInput = { ...input, route: "function" };
// @ts-expect-error chainId must not be an unsafe JavaScript number
createSafeCallPlan(31337, "Call", [input]);
// @ts-expect-error native value must be a bigint
createSafeCallPlan(31337n, "Call", [{ ...input, call: { to: "0x01" as Address, data: "0x1234" as Hex, value: 1 } }]);
// @ts-expect-error immutable plan does not permit replacing its executable bytes
plan.steps[0]!.transaction.data = "0x";
// @ts-expect-error exact caller is required on every input step
const noCaller: SafePlanInput = { intent: "Missing Safe", call: input.call, abi: input.abi };
void noCaller; void simulateSafePlanStep; void receiveRoute; void fallbackRoute; void invalidRoute; void receiveRouteName;
