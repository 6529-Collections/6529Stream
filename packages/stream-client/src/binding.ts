import { getAddress, Interface, type Provider, type TransactionRequest, type BlockTag, type LogDescription, type InterfaceAbi } from "ethers";
import type { Address, Hex } from "./generated/contracts.js";
import type { SigningPayload } from "./signing.js";

export type BindingName<F extends object> = keyof F & string;
export type AbiCatalog<F extends object> = Readonly<Record<BindingName<F>, InterfaceAbi>>;
type Method<F extends object, C extends BindingName<F>> = keyof F[C] & string;
type Args<F extends object, C extends BindingName<F>, M extends Method<F, C>> = F[C][M] extends { args: infer A } ? A : never;
type Output<F extends object, C extends BindingName<F>, M extends Method<F, C>> = F[C][M] extends { result: infer R } ? R : never;
type ReadMethod<F extends object, C extends BindingName<F>> = { [M in Method<F, C>]: F[C][M] extends { mutability: "view" | "pure" } ? M : never }[Method<F, C>];
export interface BoundStackConfig<F extends object> {
  readonly schemaVersion: 1;
  readonly chainId: bigint;
  readonly addresses: Readonly<Partial<Record<BindingName<F>, Address>> & { core: Address }>;
}
export interface UnsignedCall { readonly to: Address; readonly data: Hex; readonly value: bigint }
export interface ReceiptLog { readonly address: string; readonly topics: readonly string[]; readonly data: string }
export interface ReceiptLike { readonly status: number | null; readonly logs: readonly ReceiptLog[] }

export function bindingInterface<F extends object>(catalog: AbiCatalog<F>, name: BindingName<F>): Interface {
  if (!Object.hasOwn(catalog, name)) throw new Error(`Unknown contract ${name}`);
  return new Interface(catalog[name]);
}

export function boundStackConfigFromJSON<F extends object>(value: unknown, catalog: AbiCatalog<F>): BoundStackConfig<F> {
  if (!value || typeof value !== "object" || Array.isArray(value)) throw new Error("Expected stack config object");
  const config = value as Record<string, unknown>;
  if (Object.keys(config).sort().join(",") !== "addresses,chainId,schemaVersion" || config.schemaVersion !== 1) throw new Error("Expected schemaVersion 1, chainId and addresses");
  if (typeof config.chainId !== "string" || !/^[1-9][0-9]*$/.test(config.chainId)) throw new Error("chainId must be a positive decimal string");
  if (!config.addresses || typeof config.addresses !== "object" || Array.isArray(config.addresses)) throw new Error("Expected addresses object");
  const addresses: Partial<Record<BindingName<F>, Address>> = Object.create(null);
  for (const [key, address] of Object.entries(config.addresses)) {
    if (!Object.hasOwn(catalog, key) || typeof address !== "string") throw new Error(`Unknown/invalid contract address: ${key}`);
    addresses[key as BindingName<F>] = getAddress(address) as Address;
  }
  if (!(addresses as Record<string, Address>).core) throw new Error("core address is required");
  const chainId = BigInt(config.chainId);
  if (chainId >= 1n << 256n) throw new Error("chainId must fit uint256");
  return Object.freeze({ schemaVersion: 1, chainId, addresses: Object.freeze(addresses) as BoundStackConfig<F>["addresses"] });
}

/** No signer or secret handling. The caller owns provider choice, transaction approval and submission. */
export class BoundStreamClient<F extends object> {
  readonly config: BoundStackConfig<F>;
  private readonly interfaces = new Map<string, Interface>();
  constructor(readonly provider: Provider, config: BoundStackConfig<F>, catalog: AbiCatalog<F>) {
    for (const name of Object.keys(catalog) as BindingName<F>[]) this.interfaces.set(name, bindingInterface(catalog, name));
    // Reuse the strict external representation validation for JavaScript callers as well.
    this.config = boundStackConfigFromJSON({ ...config, chainId: config.chainId.toString() }, catalog);
  }
  async assertChain(): Promise<void> {
    if ((await this.provider.getNetwork()).chainId !== this.config.chainId) throw new Error("RPC chain ID differs from the configured Stream chain");
  }
  address(contract: BindingName<F>): Address {
    const value = this.config.addresses[contract];
    if (!value) throw new Error(`No address configured for ${contract}`);
    return value;
  }
  interface(contract: BindingName<F>): Interface {
    const value = this.interfaces.get(contract);
    if (!value) throw new Error(`Unknown contract ${contract}`);
    return value;
  }
  /** Produce calldata, not a sent transaction; a different address is explicit (e.g. a split wallet). */
  prepare<C extends BindingName<F>, M extends Method<F, C>>(contract: C, method: M, args: Args<F, C, M>, options: { value?: bigint; address?: Address } = {}): UnsignedCall {
    const iface = this.interface(contract);
    const fragment = iface.getFunction(method);
    if (!fragment) throw new Error(`Unknown function ${method}`);
    const value = options.value ?? 0n;
    if (typeof value !== "bigint" || value < 0n || value >= 1n << 256n) throw new Error("value must fit uint256 bigint");
    if (value !== 0n && !fragment.payable) throw new Error("Cannot send native value to a nonpayable function");
    return { to: getAddress(options.address ?? this.address(contract)) as Address, data: iface.encodeFunctionData(fragment, args as readonly unknown[]) as Hex, value };
  }
  async read<C extends BindingName<F>, M extends ReadMethod<F, C>>(contract: C, method: M, args: Args<F, C, M>, options: { blockTag?: BlockTag; address?: Address } = {}): Promise<Output<F, C, M>> {
    await this.assertChain();
    const iface = this.interface(contract);
    const fragment = iface.getFunction(method);
    if (!fragment?.constant) throw new Error("read only accepts a view or pure function");
    const call = this.prepare(contract, method, args, options);
    const data = await this.provider.call({ ...call, ...(options.blockTag === undefined ? {} : { blockTag: options.blockTag }) });
    const decoded = iface.decodeFunctionResult(fragment, data);
    return (fragment.outputs.length === 1 ? decoded[0] : decoded) as Output<F, C, M>;
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
  async assertDigest<T extends object>(payload: SigningPayload<T>, contract: BindingName<F>, method: string, args: readonly unknown[]): Promise<void> {
    await this.assertChain();
    if (BigInt(payload.domain.chainId ?? 0) !== this.config.chainId || getAddress(payload.domain.verifyingContract ?? "") !== this.address(contract)) throw new Error("Signing domain differs from the selected chain/contract");
    const iface = this.interface(contract);
    const result = await this.provider.call({ to: this.address(contract), data: iface.encodeFunctionData(method, args) });
    if (iface.decodeFunctionResult(method, result)[0].toLowerCase() !== payload.digest.toLowerCase()) throw new Error("Offchain digest differs from the current contract");
  }
  /** Require a successful receipt and filter by exact emitter; unrelated events cannot supply outputs. */
  events(receipt: ReceiptLike, contract: BindingName<F>, eventName: string, address?: Address): LogDescription[] {
    if (receipt.status !== 1) throw new Error("Receipt is not successful");
    const expected = getAddress(address ?? this.address(contract));
    const iface = this.interface(contract), event = iface.getEvent(eventName);
    if (!event) throw new Error(`Unknown event ${eventName}`);
    return receipt.logs.filter(log => getAddress(log.address) === expected && log.topics[0]?.toLowerCase() === event.topicHash.toLowerCase()).map(log => {
      const parsed = iface.parseLog({ topics: [...log.topics], data: log.data });
      if (!parsed) throw new Error(`Malformed ${eventName} event`);
      return parsed;
    });
  }
  uniqueEvent(receipt: ReceiptLike, contract: BindingName<F>, eventName: string, address?: Address): LogDescription {
    const found = this.events(receipt, contract, eventName, address);
    if (found.length !== 1) throw new Error(`Expected one ${eventName} from ${contract}, got ${found.length}`);
    return found[0]!;
  }
}
