import type { Provider } from "ethers";
import { abis } from "./generated/abis.js";
import type { ContractFunctions } from "./generated/contracts.js";
import { BoundStreamClient, bindingInterface, boundStackConfigFromJSON, type BoundStackConfig } from "./binding.js";

export { BoundStreamClient, bindingInterface, boundStackConfigFromJSON } from "./binding.js";
export type { AbiCatalog, BindingName, BoundStackConfig, UnsignedCall, ReceiptLog, ReceiptLike } from "./binding.js";
export type ContractName = keyof ContractFunctions;
export interface StackConfig extends BoundStackConfig<ContractFunctions> {}

/** Retained RC1 ABI surface. New compiler-derived bindings use their own explicit catalog. */
export function contractInterface(name: ContractName) { return bindingInterface<ContractFunctions>(abis, name); }
export function stackConfigFromJSON(value: unknown): StackConfig { return boundStackConfigFromJSON<ContractFunctions>(value, abis); }

/** Retained RC1 client; its method types, signing helpers and configuration remain unchanged. */
export class StreamClient extends BoundStreamClient<ContractFunctions> {
  constructor(provider: Provider, config: StackConfig) { super(provider, config, abis); }
}
