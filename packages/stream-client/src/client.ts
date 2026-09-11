import { getAddress, Interface, type Provider, type TransactionRequest, type BlockTag, type LogDescription } from "ethers";
import { abis } from "./generated/abis.js";
import type { ContractFunctions, Address, Hex } from "./generated/contracts.js";
import type { SigningPayload } from "./signing.js";

export type ContractName = keyof ContractFunctions;
type Method<C extends ContractName> = keyof ContractFunctions[C] & string;
type Args<C extends ContractName, M extends Method<C>> = ContractFunctions[C][M] extends { args: infer A } ? A : never;
type Output<C extends ContractName, M extends Method<C>> = ContractFunctions[C][M] extends { result: infer R } ? R : never;
type ReadMethod<C extends ContractName> = { [M in Method<C>]: ContractFunctions[C][M] extends { mutability: "view" | "pure" } ? M : never }[Method<C>];
export interface StackConfig {
  readonly schemaVersion: 1;
  readonly chainId: bigint;
  readonly addresses: Readonly<Partial<Record<ContractName, Address>> & { core: Address }>;
}
export interface UnsignedCall { readonly to: Address; readonly data: Hex; readonly value: bigint }
export interface ReceiptLog { readonly address: string; readonly topics: readonly string[]; readonly data: string }
export interface ReceiptLike { readonly status: number | null; readonly logs: readonly ReceiptLog[] }

export function contractInterface(name: ContractName): Interface {
  if (!Object.hasOwn(abis, name)) throw new Error(`Unknown contract ${name}`);
  return new Interface(abis[name]);
}

export function stackConfigFromJSON(value: unknown): StackConfig {
  if (!value || typeof value !== "object" || Array.isArray(value)) throw new Error("Expected stack config object");
  const config = value as Record<string, unknown>;
  if (Object.keys(config).sort().join(",") !== "addresses,chainId,schemaVersion" || config.schemaVersion !== 1) throw new Error("Expected schemaVersion 1, chainId and addresses");
  if (typeof config.chainId !== "string" || !/^[1-9][0-9]*$/.test(config.chainId)) throw new Error("chainId must be a positive decimal string");
  if (!config.addresses || typeof config.addresses !== "object" || Array.isArray(config.addresses)) throw new Error("Expected addresses object");
  const addresses: Partial<Record<ContractName, Address>> = {};
  for (const [key, address] of Object.entries(config.addresses)) {
    if (!Object.hasOwn(abis, key) || typeof address !== "string") throw new Error(`Unknown/invalid contract address: ${key}`);
    addresses[key as ContractName] = getAddress(address) as Address;
  }
  if (!addresses.core) throw new Error("core address is required");
  const chainId = BigInt(config.chainId);
  if (chainId >= 1n << 256n) throw new Error("chainId must fit uint256");
  return Object.freeze({ schemaVersion: 1, chainId, addresses: Object.freeze(addresses) as StackConfig["addresses"] });
}

/** No signer or secret handling. The caller owns provider choice, transaction approval and submission. */
export class StreamClient {
  readonly config: StackConfig;
  constructor(readonly provider: Provider, config: StackConfig) {
    // Reuse the strict external representation validation for JavaScript callers as well.
    this.config = stackConfigFromJSON({ ...config, chainId: config.chainId.toString() });
  }
  async assertChain(): Promise<void> {
    if ((await this.provider.getNetwork()).chainId !== this.config.chainId) throw new Error("RPC chain ID differs from the configured Stream chain");
  }
  address(contract: ContractName): Address {
    const value = this.config.addresses[contract];
    if (!value) throw new Error(`No address configured for ${contract}`);
    return value;
  }
  /** Produce calldata, not a sent transaction; a different address is explicit (e.g. a split wallet). */
  prepare<C extends ContractName, M extends Method<C>>(contract: C, method: M, args: Args<C, M>, options: { value?: bigint; address?: Address } = {}): UnsignedCall {
    const iface = contractInterface(contract);
    const fragment = iface.getFunction(method);
    if (!fragment) throw new Error(`Unknown function ${method}`);
    const value = options.value ?? 0n;
    if (typeof value !== "bigint" || value < 0n || value >= 1n << 256n) throw new Error("value must fit uint256 bigint");
    if (value !== 0n && !fragment.payable) throw new Error("Cannot send native value to a nonpayable function");
    return { to: getAddress(options.address ?? this.address(contract)) as Address, data: iface.encodeFunctionData(fragment, args as readonly unknown[]) as Hex, value };
  }
  async read<C extends ContractName, M extends ReadMethod<C>>(contract: C, method: M, args: Args<C, M>, options: { blockTag?: BlockTag; address?: Address } = {}): Promise<Output<C, M>> {
    await this.assertChain();
    const iface = contractInterface(contract);
    const fragment = iface.getFunction(method);
    if (!fragment?.constant) throw new Error("read only accepts a view or pure function");
    const call = this.prepare(contract, method, args, options);
    const data = await this.provider.call({ ...call, ...(options.blockTag === undefined ? {} : { blockTag: options.blockTag }) });
    const decoded = iface.decodeFunctionResult(fragment, data);
    return (fragment.outputs.length === 1 ? decoded[0] : decoded) as Output<C, M>;
  }
  /** Simulate with the actual sender and value, including payer-caller exemptions and recipient callbacks. */
  async simulate(call: UnsignedCall, sender: Address): Promise<string> {
    await this.assertChain();
    return this.provider.call({ ...call, from: getAddress(sender) });
  }
  async estimateGas(call: UnsignedCall, sender: Address): Promise<bigint> {
    await this.assertChain();
    return this.provider.estimateGas({ ...call, from: getAddress(sender) });
  }
  /** Convert into an ethers wallet request without selecting a sender, fee, nonce or gas policy. */
  transaction(call: UnsignedCall): TransactionRequest { return { ...call, chainId: this.config.chainId }; }
  async assertDigest<T extends object>(payload: SigningPayload<T>, contract: ContractName, method: string, args: readonly unknown[]): Promise<void> {
    await this.assertChain();
    if (BigInt(payload.domain.chainId ?? 0) !== this.config.chainId || getAddress(payload.domain.verifyingContract ?? "") !== this.address(contract)) throw new Error("Signing domain differs from the selected chain/contract");
    const iface = contractInterface(contract);
    const result = await this.provider.call({ to: this.address(contract), data: iface.encodeFunctionData(method, args) });
    if (iface.decodeFunctionResult(method, result)[0].toLowerCase() !== payload.digest.toLowerCase()) throw new Error("Offchain digest differs from the current contract");
  }
  /** Require a successful receipt and filter by exact emitter; unrelated events cannot supply outputs. */
  events(receipt: ReceiptLike, contract: ContractName, eventName: string, address?: Address): LogDescription[] {
    if (receipt.status !== 1) throw new Error("Receipt is not successful");
    const expected = getAddress(address ?? this.address(contract));
    const iface = contractInterface(contract), event = iface.getEvent(eventName);
    if (!event) throw new Error(`Unknown event ${eventName}`);
    return receipt.logs.filter(log => getAddress(log.address) === expected && log.topics[0]?.toLowerCase() === event.topicHash.toLowerCase()).map(log => {
      const parsed = iface.parseLog({ topics: [...log.topics], data: log.data });
      if (!parsed) throw new Error(`Malformed ${eventName} event`);
      return parsed;
    });
  }
  uniqueEvent(receipt: ReceiptLike, contract: ContractName, eventName: string, address?: Address): LogDescription {
    const found = this.events(receipt, contract, eventName, address);
    if (found.length !== 1) throw new Error(`Expected one ${eventName} from ${contract}, got ${found.length}`);
    return found[0]!;
  }
}
