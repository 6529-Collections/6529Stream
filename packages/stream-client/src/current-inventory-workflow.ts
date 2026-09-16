import { AbiCoder, Interface, ZeroAddress, ZeroHash, getAddress, id, isHexString, keccak256, toUtf8Bytes } from "ethers";
import type { BlockTag, InterfaceAbi, Provider } from "ethers";
import type { Address, Hex } from "./generated/contracts.js";
import type { ReceiptLike } from "./client.js";
import { CurrentSecondaryClient } from "./current-secondary.js";
import type { SecondaryActorCall, SecondaryCustodyGrant, SecondaryInventoryConfig } from "./current-secondary.js";
import { requireSafeExecution, toSafeCall } from "./safe.js";

export interface InventoryWorkflowBindings { readonly adapter: InterfaceAbi; readonly inventory: InterfaceAbi; readonly moduleRegistry: InterfaceAbi }
export interface InventoryWorkflowPins { readonly adapterCodeHash: Hex; readonly core: Address; readonly coreCodeHash: Hex }
export interface InventoryWorkflowDeposit { readonly caller: Address; readonly grant: SecondaryCustodyGrant; readonly ownerKind: bigint; readonly signature: Hex }
export interface InventoryWorkflowStart {
  readonly receipt: ReceiptLike; readonly config: SecondaryInventoryConfig; readonly tokenIds: readonly bigint[];
  readonly deposits: readonly InventoryWorkflowDeposit[]; readonly opener: Address; readonly pins: InventoryWorkflowPins;
  /** Independently verified Safe transaction hash, if the registration was executed by a Safe. */
  readonly registrationSafe?: { readonly address: Address; readonly transactionHash: Hex };
}
export interface SavedInventoryWorkflow { readonly json: string; readonly hash: Hex }
export interface InventoryWorkflowStep {
  readonly status: "deposit" | "open" | "opened" | "cancelled" | "expired";
  readonly tokenId: bigint | null; readonly prepared: SecondaryActorCall | null;
  readonly blockNumber: bigint; readonly blockHash: Hex;
}
type RPC = Pick<Provider, "call" | "getNetwork" | "getBlock" | "getCode">;
type Deposit = { caller: Address; tokenId: string; data: Hex; digest: Hex };
type Journal = { schema: string; chainId: string; adapter: Address; bindingsHash: Hex; pins: InventoryWorkflowPins;
  saleId: Hex; configHash: Hex; inventoryHash: Hex; registrationData: Hex; saleNonce: string; createdAt: string;
  registryRevision: string; platformSigner: Address; originNumber: string; originHash: Hex; opener: Address; deposits: Deposit[] };
const coder = AbiCoder.defaultAbiCoder();
const schema = "6529STREAM_NATIVE_INVENTORY_OPENING_JOURNAL_V1";
const same = (a: string, b: string) => a.toLowerCase() === b.toLowerCase();
function uint(v: unknown): bigint { if (typeof v !== "bigint" || v < 0n || v >= 1n << 256n) throw Error("Expected uint256 bigint"); return v; }
function decimal(v: unknown): bigint { if (typeof v !== "string" || !/^(0|[1-9][0-9]*)$/.test(v)) throw Error("Noncanonical decimal string"); return uint(BigInt(v)); }
function address(v: unknown): Address { if (typeof v !== "string") throw Error("Expected address"); const a = getAddress(v); if (a === ZeroAddress) throw Error("Zero address"); return a as Address; }
function hash(v: unknown): Hex { if (typeof v !== "string" || !isHexString(v, 32) || same(v, ZeroHash)) throw Error("Expected nonzero bytes32"); return v.toLowerCase() as Hex; }
function keys(v: unknown, expected: readonly string[]): asserts v is Record<string, unknown> {
  if (!v || typeof v !== "object" || Array.isArray(v) || Object.keys(v).sort().join() !== [...expected].sort().join()) throw Error("Unexpected journal fields");
}
function canonical(v: unknown): string {
  if (Array.isArray(v)) return `[${v.map(canonical).join(",")}]`;
  if (v !== null && typeof v === "object") return `{${Object.keys(v).sort().map(k => `${JSON.stringify(k)}:${canonical((v as Record<string, unknown>)[k])}`).join(",")}}`;
  if (typeof v !== "string") throw Error("Journal values must be exact strings"); return JSON.stringify(v);
}

/** Saved, unsigned original inventory calls. This helper never signs, transfers, broadcasts or updates a journal in place. */
export class CurrentInventoryWorkflow {
  readonly sales: CurrentSecondaryClient;
  readonly #abi: Interface; readonly #inventory: Interface; readonly #bindingHash: Hex;
  constructor(chainId: bigint, adapter: Address, bindings: InventoryWorkflowBindings) {
    this.sales = new CurrentSecondaryClient(chainId, adapter, bindings);
    this.#abi = new Interface(bindings.adapter); this.#inventory = new Interface(bindings.inventory);
    for (const name of ["inventoryDetails", "inventoryToken", "core", "coreCodeHash", "platformSigner", "digestConsumed", "digestRevoked"]) {
      if (!this.#abi.getFunction(name)?.constant) throw Error(`Selected compiled ABI lacks ${name}`);
    }
    this.#bindingHash = keccak256(toUtf8Bytes(canonical({ adapter: this.#abi.fragments.map(x => x.format("json")).sort(),
      inventory: this.#inventory.fragments.map(x => x.format("json")).sort() }))) as Hex;
    Object.freeze(this);
  }
  #pins(v: InventoryWorkflowPins): InventoryWorkflowPins {
    keys(v, ["adapterCodeHash", "core", "coreCodeHash"]);
    return Object.freeze({ adapterCodeHash: hash(v.adapterCodeHash), core: address(v.core), coreCodeHash: hash(v.coreCodeHash) });
  }
  #registration(data: Hex) {
    const fn = this.#abi.getFunction("registerInventory")!;
    const [c, ids] = this.#abi.decodeFunctionData(fn, data);
    const config = c.toObject() as SecondaryInventoryConfig, tokenIds = [...ids] as bigint[];
    const encoded = this.sales.registerInventory(this.sales.adapter, config, tokenIds).call.data;
    if (!same(encoded, data)) throw Error("Noncanonical registration calldata");
    return { config, tokenIds };
  }
  #deposit(j: Journal, d: Deposit) {
    const [saleId, raw, ownerKind, signature] = this.#abi.decodeFunctionData("depositInventoryCustody", d.data);
    const grant = raw.toObject() as SecondaryCustodyGrant;
    const prepared = this.sales.depositInventory(d.caller, saleId as Hex, grant, ownerKind as bigint, signature as Hex);
    const { config } = this.#registration(j.registrationData);
    if (!same(prepared.call.data, d.data) || !same(saleId, j.saleId) || grant.tokenId !== decimal(d.tokenId)
      || !same(grant.core, j.pins.core) || !same(grant.owner, config.consignor)
      || !same(this.sales.signing("SaleCustodyGrant", grant).payload.digest, d.digest)) throw Error("Saved custody coordinates differ");
    return { grant, prepared };
  }
  #load(saved: SavedInventoryWorkflow): Journal {
    keys(saved, ["json", "hash"]);
    if (typeof saved.json !== "string" || saved.json.length > 4_000_000 || !same(keccak256(toUtf8Bytes(saved.json)), hash(saved.hash))) throw Error("Saved journal commitment differs");
    const j = JSON.parse(saved.json) as Journal;
    keys(j, ["schema", "chainId", "adapter", "bindingsHash", "pins", "saleId", "configHash", "inventoryHash", "registrationData", "saleNonce", "createdAt", "registryRevision", "platformSigner", "originNumber", "originHash", "opener", "deposits"]);
    if (canonical(j) !== saved.json || j.schema !== schema || decimal(j.chainId) !== this.sales.chainId
      || !same(address(j.adapter), this.sales.adapter) || hash(j.bindingsHash) !== this.#bindingHash) throw Error("Journal schema/chain/adapter/bindings differ");
    this.#pins(j.pins); hash(j.saleId); hash(j.configHash); hash(j.inventoryHash); hash(j.originHash);
    address(j.platformSigner); address(j.opener); if (decimal(j.originNumber) > BigInt(Number.MAX_SAFE_INTEGER)) throw Error("Origin block exceeds exact provider number range");
    if (decimal(j.saleNonce) === 0n || decimal(j.createdAt) === 0n || decimal(j.registryRevision) === 0n) throw Error("Missing registered inventory coordinates");
    const { tokenIds } = this.#registration(j.registrationData);
    if (!Array.isArray(j.deposits) || j.deposits.length !== tokenIds.length) throw Error("Exact grant inventory required");
    for (let i = 0; i < tokenIds.length; i++) {
      const d = j.deposits[i]!; keys(d, ["caller", "tokenId", "data", "digest"]); address(d.caller); hash(d.digest);
      if (decimal(d.tokenId) !== tokenIds[i]) throw Error("Grant/token ordering differs"); this.#deposit(j, d);
    }
    return j;
  }
  /** Restoring requires the separately retained original hash, not a hash recalculated from an edited file. */
  restore(json: string, originalHash: Hex): SavedInventoryWorkflow {
    const saved = Object.freeze({ json, hash: originalHash }); this.#load(saved); return saved;
  }
  async #read(provider: RPC, method: string, args: readonly unknown[], block: number) {
    const fn = this.#abi.getFunction(method)!;
    const raw = await provider.call({ to: this.sales.adapter, data: this.#abi.encodeFunctionData(fn, args), blockTag: block });
    const result = this.#abi.decodeFunctionResult(fn, raw);
    if (!same(this.#abi.encodeFunctionResult(fn, result), raw)) throw Error("Noncanonical contract read"); return result;
  }
  async #block(provider: RPC, blockTag: BlockTag) {
    if ((await provider.getNetwork()).chainId !== this.sales.chainId) throw Error("RPC chain differs");
    const b = await provider.getBlock(blockTag);
    if (!b?.hash || !Number.isSafeInteger(b.number) || b.number < 0 || !Number.isSafeInteger(b.timestamp) || b.timestamp < 0) throw Error("Observed block unavailable");
    return Object.freeze({ number: b.number, timestamp: b.timestamp, hash: hash(b.hash) });
  }
  async #pin(provider: RPC, pins: InventoryWorkflowPins, block: number) {
    for (const [a, h] of [[this.sales.adapter, pins.adapterCodeHash], [pins.core, pins.coreCodeHash]] as const) {
      const code = await provider.getCode(a, block); if (code === "0x" || !same(keccak256(code), h)) throw Error("Pinned runtime differs");
    }
    const [core] = await this.#read(provider, "core", [], block), [codeHash] = await this.#read(provider, "coreCodeHash", [], block);
    if (!same(core, pins.core) || !same(codeHash, pins.coreCodeHash)) throw Error("Pinned Core differs");
  }
  #record(j: Journal, sale: Awaited<ReturnType<CurrentSecondaryClient["readInventory"]>>) {
    const { config, tokenIds } = this.#registration(j.registrationData);
    const actualData = this.sales.registerInventory(this.sales.adapter, sale.config, sale.tokenIds).call.data;
    const manifest = keccak256(coder.encode(["uint256[]"], [tokenIds]));
    const configType = this.#abi.getFunction("registerInventory")!.inputs[0]!;
    const expected = keccak256(coder.encode(["bytes32", "uint256", "address", "uint256", "address", configType, "bytes32"],
      [id("6529STREAM_NATIVE_SECONDARY_INVENTORY_CONFIG_V1"), this.sales.chainId, this.sales.adapter, decimal(j.saleNonce), j.platformSigner, config, manifest]));
    const saleId = keccak256(coder.encode(["bytes32", "uint256", "address", "uint8", "uint256", "bytes32", "uint256"],
      [id("6529STREAM_SALE_V1"), this.sales.chainId, this.sales.adapter, 14n, config.collectionId, ZeroHash, decimal(j.saleNonce)]));
    if (!same(actualData, j.registrationData) || !same(manifest, j.inventoryHash) || !same(sale.inventoryHash, manifest)
      || !same(expected, j.configHash) || !same(sale.configHash, expected) || !same(saleId, j.saleId)
      || sale.saleNonce !== decimal(j.saleNonce) || sale.createdAt !== decimal(j.createdAt) || sale.registryRevision !== decimal(j.registryRevision)) throw Error("Registered inventory identity differs");
    return { config, tokenIds };
  }
  /** Starts from an actual InventoryConfigured receipt plus independently reviewed configuration/grants. */
  async start(provider: RPC, input: InventoryWorkflowStart, blockTag: BlockTag = "latest"): Promise<SavedInventoryWorkflow> {
    // Snapshot every caller-controlled object before the first await.
    if (input.registrationSafe) requireSafeExecution(input.receipt, input.registrationSafe.address, input.registrationSafe.transactionHash);
    const event = this.sales.inventoryRegistration(input.receipt);
    const registration = this.sales.registerInventory(this.sales.adapter, input.config, [...input.tokenIds]);
    const pins = this.#pins(input.pins), opener = address(input.opener);
    if (event.tokenIds.length !== input.tokenIds.length || event.tokenIds.some((x, i) => x !== input.tokenIds[i])
      || !same(event.consignor, input.config.consignor) || input.deposits.length !== input.tokenIds.length) throw Error("Registration receipt/configuration differs");
    const deposits: Deposit[] = input.deposits.map((x, i) => {
      const prepared = this.sales.depositInventory(x.caller, event.saleId, x.grant, x.ownerKind, x.signature);
      if (x.grant.tokenId !== input.tokenIds[i]) throw Error("Exact sorted grant inventory required");
      return { caller: prepared.caller, tokenId: x.grant.tokenId.toString(), data: prepared.call.data,
        digest: this.sales.signing("SaleCustodyGrant", x.grant).payload.digest };
    });
    const block = await this.#block(provider, blockTag); await this.#pin(provider, pins, block.number);
    const sale = await this.sales.readInventory(provider, event.saleId, block.number);
    const [platformSigner] = await this.#read(provider, "platformSigner", [], block.number);
    const j: Journal = { schema, chainId: this.sales.chainId.toString(), adapter: this.sales.adapter, bindingsHash: this.#bindingHash,
      pins, saleId: event.saleId, configHash: event.configHash, inventoryHash: event.inventoryHash,
      registrationData: registration.call.data, saleNonce: sale.saleNonce.toString(), createdAt: sale.createdAt.toString(),
      registryRevision: sale.registryRevision.toString(), platformSigner: address(platformSigner), originNumber: block.number.toString(),
      originHash: hash(block.hash), opener, deposits };
    this.#record(j, sale); const json = canonical(j); const saved = this.restore(json, keccak256(toUtf8Bytes(json)) as Hex);
    await this.#stable(provider, block.number, block.hash); return saved;
  }
  async #stable(provider: RPC, number: number, expected: string) {
    if ((await provider.getBlock(number))?.hash !== expected) throw Error("Observed block changed; repeat reads");
  }
  /** Reconstructs progress from original ledgers; simulation failure leaves the saved journal and retry bytes unchanged. */
  async resume(provider: RPC, saved: SavedInventoryWorkflow, blockTag: BlockTag = "latest"): Promise<InventoryWorkflowStep> {
    const j = this.#load(saved), block = await this.#block(provider, blockTag);
    if (BigInt(block.number) < decimal(j.originNumber)) throw Error("Observation predates saved inventory");
    if ((await provider.getBlock(Number(decimal(j.originNumber))))?.hash !== j.originHash) throw Error("Saved origin block changed");
    await this.#pin(provider, j.pins, block.number);
    const [platformSigner] = await this.#read(provider, "platformSigner", [], block.number);
    if (!same(platformSigner, j.platformSigner)) throw Error("Original platform signer differs");
    const sale = await this.sales.readInventory(provider, j.saleId, block.number), { config } = this.#record(j, sale);
    const result = (status: InventoryWorkflowStep["status"], prepared: SecondaryActorCall | null, tokenId: bigint | null): InventoryWorkflowStep =>
      Object.freeze({ status, prepared, tokenId, blockNumber: BigInt(block.number), blockHash: hash(block.hash) });
    if (sale.status === 4n || sale.status === 5n) { await this.#stable(provider, block.number, block.hash); return result(sale.status === 4n ? "cancelled" : "expired", null, null); }
    if (sale.status !== 1n && sale.status !== 2n) throw Error("Unsupported inventory state");
    let next: { prepared: SecondaryActorCall; tokenId: bigint } | undefined;
    for (const d of j.deposits) {
      const { grant, prepared } = this.#deposit(j, d), tokenId = decimal(d.tokenId);
      await this.sales.assertDigest(provider, this.sales.signing("SaleCustodyGrant", grant), block.number);
      const [item] = await this.#read(provider, "inventoryToken", [j.saleId, tokenId], block.number);
      const c = item.config;
      const expected = [14n, config.collectionId, tokenId, config.consignor, config.unitPrice, config.startTime, config.deadline,
        ZeroHash, config.signerEvidenceHash, config.signerRevision, config.signerAuthority, true, ZeroHash];
      const actual = [c.saleKind, c.collectionId, c.tokenId, c.consignor, c.price, c.startTime, c.deadline,
        c.offerDigest, c.signerEvidenceHash, c.signerRevision, c.signerAuthority, c.secondaryConsignment, c.expectedPrimaryPolicyHash];
      if (actual.some((x, i) => !same(String(x), String(expected[i]))) || !same(item.configHash, j.configHash)
        || item.saleNonce !== sale.saleNonce || item.createdAt !== sale.createdAt || item.registryRevision !== sale.registryRevision) throw Error("Inventory token identity differs");
      const [consumed] = await this.#read(provider, "digestConsumed", [d.digest], block.number);
      const [revoked] = await this.#read(provider, "digestRevoked", [d.digest], block.number);
      if (revoked) throw Error("Saved custody grant was revoked");
      if (item.status === 1n) {
        if (sale.status !== 1n || consumed || item.custodyGrantDigest !== ZeroHash || item.nftClaim !== 0n
          || c.buyer !== ZeroAddress || item.authorizationDigest !== ZeroHash || item.royaltyAmount !== 0n || item.royaltyReceiver !== ZeroAddress) throw Error("Conflicting uncollected token state");
        if (grant.deadline < BigInt(block.timestamp)) throw Error("Saved custody grant expired; prepare a new journal");
        next ??= { prepared, tokenId };
      } else if (item.status === 2n || (item.status === 3n && sale.status === 2n)) {
        if (!consumed || !same(item.custodyGrantDigest, d.digest)) throw Error("Custody used a different grant");
        if (item.status === 2n && (item.nftClaim !== 0n || c.buyer !== ZeroAddress || item.authorizationDigest !== ZeroHash
          || item.royaltyAmount !== 0n || item.royaltyReceiver !== ZeroAddress)) throw Error("Conflicting held token state");
        if (item.status === 3n && (c.buyer === ZeroAddress || same(c.buyer, this.sales.adapter)
          || item.nftClaim > 1n || item.authorizationDigest !== ZeroHash || item.royaltyAmount > c.price)) throw Error("Conflicting sold token state");
      } else throw Error("Inventory token is terminal or conflicted");
    }
    if (sale.status === 2n) { await this.#stable(provider, block.number, block.hash); return result("opened", null, null); }
    if (config.deadline < BigInt(block.timestamp)) throw Error("Inventory deadline elapsed; use original expiry/claim exits");
    const prepared = next?.prepared ?? this.sales.openInventory(j.opener, j.saleId);
    const simulated = await this.sales.simulate(provider, prepared, block.number);
    if (simulated !== "0x") throw Error("Unexpected return from original void inventory method");
    await this.#stable(provider, block.number, block.hash);
    return result(next ? "deposit" : "open", prepared, next?.tokenId ?? null);
  }
  /** Receipt evidence for an original deposit/open CALL. Safe hashes must independently bind that exact CALL, not a module or batch. */
  verifyStepReceipt(saved: SavedInventoryWorkflow, step: "deposit" | "open", tokenId: bigint | null,
    receipt: ReceiptLike, safeTransactionHash?: Hex): void {
    const j = this.#load(saved); if (receipt.status !== 1) throw Error("Receipt is not successful");
    if (step !== "deposit" && step !== "open") throw Error("Unknown workflow receipt step");
    const deposit = step === "deposit" ? j.deposits.find(x => decimal(x.tokenId) === tokenId) : undefined;
    if (step === "deposit" ? !deposit : tokenId !== null) throw Error("Receipt token differs from journal");
    const caller = deposit?.caller ?? j.opener;
    if (safeTransactionHash !== undefined) requireSafeExecution(receipt, caller, safeTransactionHash);
    const event = (abi: Interface, name: string, expected: readonly unknown[]) => {
      const f = abi.getEvent(name)!; const logs = receipt.logs.filter(x => same(x.address, this.sales.adapter) && same(x.topics[0] ?? "", f.topicHash));
      if (logs.length !== 1) throw Error(`Expected one original ${name} event`);
      const log = logs[0]!, values = abi.decodeEventLog(f, log.data, [...log.topics]);
      const encoded = abi.encodeEventLog(f, values);
      if (!same(encoded.data, log.data) || encoded.topics.length !== log.topics.length || encoded.topics.some((x, i) => !same(x, log.topics[i]!))
        || values.length !== expected.length || values.some((x, i) => !same(String(x), String(expected[i])))) throw Error("Receipt fields differ from saved CALL");
    };
    if (deposit) {
      const { grant } = this.#deposit(j, deposit);
      event(this.#abi, "SaleAuthorizationConsumed", [1n, j.saleId, deposit.digest, grant.owner]);
      event(this.#abi, "SaleCustodyDeposited", [1n, j.saleId, grant.tokenId, grant.owner]);
    } else event(this.#inventory, "InventoryOpened", [1n, j.saleId]);
  }
  safeCall(step: InventoryWorkflowStep) { if (!step.prepared) throw Error("No pending workflow CALL"); return Object.freeze({ safe: step.prepared.caller, call: toSafeCall(step.prepared.call) }); }
}
