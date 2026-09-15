import { AbiCoder, Interface, ParamType, ZeroAddress, ZeroHash, getAddress, id, isHexString, keccak256, solidityPackedKeccak256 } from "ethers";
import type { BlockTag, InterfaceAbi, Provider, TypedDataField } from "ethers";
import type { Address, Hex } from "./generated/contracts.js";
import type { ReceiptLike, UnsignedCall } from "./client.js";
import type { SigningPayload } from "./signing.js";
import { buildSigningPayload } from "./signing-payload.js";

export interface SecondarySaleAuthorization {
  readonly chainId: bigint; readonly saleAdapter: Address; readonly mintManager: Address;
  readonly collectionId: bigint; readonly phaseId: Hex; readonly saleId: Hex; readonly saleKind: bigint;
  readonly revenueClass: Hex; readonly expectedPrimaryPolicyHash: Hex; readonly primaryPolicyMode: bigint;
  readonly initialRecipientsHash: Hex; readonly beneficiariesHash: Hex; readonly tokenDataArrayHash: Hex;
  readonly mintCommitmentsHash: Hex; readonly payer: Address; readonly executor: Address; readonly asset: Address;
  readonly unitPrice: bigint; readonly quantity: bigint; readonly contentSelectionHash: Hex; readonly policyHash: Hex;
  readonly nonce: Hex; readonly deadline: bigint; readonly finalizeBy: bigint;
}
export interface SecondarySaleOffer {
  readonly chainId: bigint; readonly saleAdapter: Address; readonly core: Address; readonly collectionId: bigint;
  readonly tokenId: bigint; readonly contentSelectionHash: Hex; readonly buyer: Address; readonly asset: Address;
  readonly price: bigint; readonly nonce: Hex; readonly deadline: bigint; readonly finalizeBy: bigint;
}
export interface SecondaryCustodyGrant {
  readonly chainId: bigint; readonly saleAdapter: Address; readonly core: Address; readonly tokenId: bigint;
  readonly owner: Address; readonly saleRef: Hex; readonly nonce: Hex; readonly deadline: bigint;
}
export interface SecondarySigningMessages {
  SaleAuthorization: SecondarySaleAuthorization; SaleOffer: SecondarySaleOffer; SaleCustodyGrant: SecondaryCustodyGrant;
}
export interface SecondarySignature { readonly authorizer: Address; readonly kind: bigint; readonly signature: Hex }
export interface SecondaryDelegationWitness { readonly walletWide: boolean; readonly index: bigint }
export interface SecondaryInventoryConfig {
  readonly collectionId: bigint; readonly consignor: Address; readonly unitPrice: bigint;
  readonly startTime: bigint; readonly deadline: bigint; readonly perBuyerCap: bigint;
  readonly signerEvidenceHash: Hex; readonly signerRevision: bigint; readonly signerAuthority: Address;
  readonly secondaryConsignment: boolean; readonly expectedPrimaryPolicyHash: Hex;
}
/** The caller is an EOA or Safe address, never an offer delegate's spending authority. */
export interface SecondaryActorCall { readonly caller: Address; readonly call: UnsignedCall }
export interface SecondarySigningRequest<T extends object> {
  readonly payload: SigningPayload<T>; readonly digestCall: UnsignedCall; readonly digestMethod: string;
}
export interface SecondaryOfferInput {
  readonly authorization: SecondarySaleAuthorization; readonly sellerProof: SecondarySignature;
  readonly offer: SecondarySaleOffer; readonly offerProof: SecondarySignature; readonly ownerGrant: SecondaryCustodyGrant;
  readonly ownerKind: bigint; readonly ownerSignature: Hex; readonly value: bigint;
}
export type SecondaryOfferMode = { readonly mode: "maker" } | { readonly mode: "delegate"; readonly witness: SecondaryDelegationWitness };
export interface SecondaryDelegationPins {
  readonly core: Address; readonly adapterCodeHash: Hex; readonly moduleRegistry: Address; readonly moduleRegistryCodeHash: Hex;
  readonly delegateRegistry: Address; readonly delegateRegistryCodeHash: Hex; readonly usecase: bigint; readonly baseManifestHash: Hex;
}
const coder = AbiCoder.defaultAbiCoder();
const zeroAddress = ZeroAddress as Address, zeroHash = ZeroHash as Hex;
const allCollections = "0x8888888888888888888888888888888888888888";
const schemes = {
  SaleAuthorization: ["authorizationDigest", "uint256 chainId,address saleAdapter,address mintManager,uint256 collectionId,bytes32 phaseId,bytes32 saleId,uint8 saleKind,bytes32 revenueClass,bytes32 expectedPrimaryPolicyHash,uint8 primaryPolicyMode,bytes32 initialRecipientsHash,bytes32 beneficiariesHash,bytes32 tokenDataArrayHash,bytes32 mintCommitmentsHash,address payer,address executor,address asset,uint256 unitPrice,uint256 quantity,bytes32 contentSelectionHash,bytes32 policyHash,bytes32 nonce,uint64 deadline,uint64 finalizeBy"],
  SaleOffer: ["offerDigest", "uint256 chainId,address saleAdapter,address core,uint256 collectionId,uint256 tokenId,bytes32 contentSelectionHash,address buyer,address asset,uint256 price,bytes32 nonce,uint64 deadline,uint64 finalizeBy"],
  SaleCustodyGrant: ["custodyGrantDigest", "uint256 chainId,address saleAdapter,address core,uint256 tokenId,address owner,bytes32 saleRef,bytes32 nonce,uint64 deadline"],
} as const;
const fields = (text: string): TypedDataField[] => text.split(",").map(x => { const [type, name] = x.split(" "); return { type: type!, name: name! }; });
function uint(v: unknown, bits = 256): bigint {
  if (typeof v !== "bigint" || v < 0n || v >= 1n << BigInt(bits)) throw Error(`Expected uint${bits} bigint`);
  return v;
}
function address(v: string, nonzero = false): Address {
  const a = getAddress(v) as Address;
  if (nonzero && a === ZeroAddress) throw Error("Nonzero address required");
  return a;
}
function hash(v: string, nonzero = false): Hex {
  if (!isHexString(v, 32) || (nonzero && v.toLowerCase() === ZeroHash)) throw Error("Expected bytes32 commitment");
  return v as Hex;
}
const same = (a: string, b: string) => a.toLowerCase() === b.toLowerCase();
function keys(v: unknown, expected: readonly string[]): asserts v is Record<string, unknown> {
  if (!v || typeof v !== "object" || Array.isArray(v) || Object.keys(v).sort().join(",") !== [...expected].sort().join(",")) throw Error("Unexpected or missing fields");
}
/** ABI-guided strict values: ethers' permissive number coercion is deliberately unavailable. */
function normalize(p: ParamType, value: unknown): unknown {
  if (p.baseType === "array") {
    if (!Array.isArray(value) || (p.arrayLength !== -1 && value.length !== p.arrayLength)) throw Error("Expected exact ABI array");
    return value.map(v => normalize(p.arrayChildren!, v));
  }
  if (p.baseType === "tuple") {
    const components = p.components!; keys(value, components.map(x => x.name));
    return Object.fromEntries(components.map(x => [x.name, normalize(x, value[x.name])]));
  }
  if (/^uint\d+$/.test(p.type)) return uint(value, Number(p.type.slice(4)));
  if (p.type === "address") { if (typeof value !== "string") throw Error("Expected address"); return address(value); }
  if (p.type === "bool") { if (typeof value !== "boolean") throw Error("Expected boolean"); return value; }
  if (p.type.startsWith("bytes")) {
    const size = p.type === "bytes" ? true : Number(p.type.slice(5));
    if (typeof value !== "string" || !isHexString(value, size)) throw Error("Expected exact complete hex bytes");
    return value;
  }
  if (p.type === "string" && typeof value === "string") return value;
  throw Error(`Unsupported ABI input ${p.type}`);
}

/** Uses caller-selected compiled ABIs. These helpers do not replace the retained release catalog. */
export class CurrentSecondaryClient {
  readonly chainId: bigint;
  readonly adapter: Address;
  readonly #abi: Interface;
  readonly #registry: Interface;
  readonly #inventory: Interface;
  constructor(chainId: bigint, adapter: Address, bindings: { readonly adapter: InterfaceAbi; readonly moduleRegistry: InterfaceAbi; readonly inventory: InterfaceAbi }) {
    this.chainId = uint(chainId); if (chainId === 0n) throw Error("Nonzero chain required");
    this.adapter = address(adapter, true);
    this.#abi = new Interface(bindings.adapter); this.#registry = new Interface(bindings.moduleRegistry); this.#inventory = new Interface(bindings.inventory);
    for (const [method, text] of Object.values(schemes)) {
      const fragment = this.#abi.getFunction(method), compiled = fragment?.inputs[0]?.components;
      if (fragment?.inputs.length !== 1 || !fragment.constant || fragment.outputs.length !== 1 || fragment.outputs[0]?.type !== "bytes32"
        || !compiled || compiled.map(x => `${x.type} ${x.name}`).join(",") !== text) throw Error("Selected ABI differs from original Sales signing tuples");
    }
    Object.freeze(this);
  }
  #call(method: string, args: readonly unknown[], value = 0n): UnsignedCall {
    const fn = this.#abi.getFunction(method);
    if (!fn || fn.inputs.length !== args.length) throw Error(`Selected ABI lacks ${method}`);
    uint(value); if (value !== 0n && !fn.payable) throw Error("Cannot fund nonpayable call");
    return Object.freeze({ to: this.adapter, data: this.#abi.encodeFunctionData(fn, args.map((v, i) => normalize(fn.inputs[i]!, v))) as Hex, value });
  }
  #actor(caller: Address, method: string, args: readonly unknown[], value = 0n): SecondaryActorCall {
    return Object.freeze({ caller: address(caller, true), call: this.#call(method, args, value) });
  }
  signing<K extends keyof SecondarySigningMessages>(kind: K, message: SecondarySigningMessages[K]): SecondarySigningRequest<SecondarySigningMessages[K]> {
    if (!Object.hasOwn(schemes, kind)) throw Error("Unknown Sales signing kind");
    const [method, schema] = schemes[kind];
    const payload = buildSigningPayload(this.chainId, this.adapter, "6529Stream Sales", kind, fields(schema), message);
    if (payload.message.chainId !== this.chainId || !same(payload.message.saleAdapter, this.adapter)) throw Error("Embedded chain/adapter differs from signing domain");
    return Object.freeze({ payload, digestMethod: method, digestCall: this.#call(method, [payload.message]) });
  }
  signingFromJSON(value: unknown): SecondarySigningRequest<SecondarySigningMessages[keyof SecondarySigningMessages]> {
    keys(value, ["kind", "message"]);
    const kind = value.kind as keyof SecondarySigningMessages;
    if (typeof kind !== "string" || !Object.hasOwn(schemes, kind)) throw Error("Unknown Sales signing kind");
    const schema = fields(schemes[kind][1]); keys(value.message, schema.map(x => x.name));
    const message = { ...value.message };
    for (const f of schema) if (f.type.startsWith("uint")) {
      const v = message[f.name];
      if (typeof v !== "string" || !/^(0|[1-9][0-9]*)$/.test(v)) throw Error("JSON integers must be canonical decimal strings");
      message[f.name] = BigInt(v);
    }
    return this.signing(kind, message as unknown as SecondarySigningMessages[typeof kind]);
  }
  /** Build the original native secondary offer authorization; no mint/primary/reveal fields are invented. */
  authorizationForOffer(offer: SecondarySaleOffer, saleId: Hex, nonce: Hex, deadline: bigint): SecondarySaleAuthorization {
    const o = this.signing("SaleOffer", offer).payload.message;
    const recipientHash = keccak256(coder.encode(["address[]"], [[o.buyer]])) as Hex;
    const result: SecondarySaleAuthorization = { chainId: this.chainId, saleAdapter: this.adapter, mintManager: zeroAddress,
      collectionId: o.collectionId, phaseId: zeroHash, saleId: hash(saleId, true), saleKind: 6n, revenueClass: zeroHash,
      expectedPrimaryPolicyHash: zeroHash, primaryPolicyMode: 0n, initialRecipientsHash: recipientHash, beneficiariesHash: recipientHash,
      tokenDataArrayHash: keccak256(coder.encode(["bytes[]"], [[]])) as Hex, mintCommitmentsHash: keccak256(coder.encode(["bytes32[]"], [[]])) as Hex,
      payer: o.buyer, executor: o.buyer, asset: zeroAddress, unitPrice: o.price, quantity: 1n, contentSelectionHash: zeroHash, policyHash: zeroHash,
      nonce: hash(nonce), deadline: uint(deadline, 64), finalizeBy: 0n };
    return this.signing("SaleAuthorization", result).payload.message;
  }
  registerInventory(caller: Address, config: SecondaryInventoryConfig, tokenIds: readonly bigint[]): SecondaryActorCall {
    if (!Array.isArray(tokenIds) || !tokenIds.length || tokenIds.length > 64) throw Error("Inventory requires 1..64 tokens");
    let prior = 0n; for (const token of tokenIds) { uint(token); if (token <= prior) throw Error("Inventory must be positive, unique and sorted"); prior = token; }
    if (config.secondaryConsignment !== true || !same(config.expectedPrimaryPolicyHash, ZeroHash)
      || uint(config.collectionId) === 0n || uint(config.unitPrice) === 0n || uint(config.startTime, 64) >= uint(config.deadline, 64)
      || uint(config.signerRevision, 64) === 0n || same(address(config.consignor, true), this.adapter)) throw Error("Unsupported inventory configuration");
    return this.#actor(caller, "registerInventory", [config, tokenIds]);
  }
  depositInventory(caller: Address, saleId: Hex, grant: SecondaryCustodyGrant, ownerKind: bigint, signature: Hex): SecondaryActorCall {
    const g = this.signing("SaleCustodyGrant", grant).payload.message;
    if (!same(g.saleRef, hash(saleId, true)) || uint(g.tokenId) === 0n) throw Error("Inventory grant must reference its exact sale and token");
    this.#signature({ authorizer: g.owner, kind: ownerKind, signature });
    return this.#actor(caller, "depositInventoryCustody", [saleId, g, ownerKind, signature]);
  }
  openInventory(caller: Address, saleId: Hex): SecondaryActorCall { return this.#actor(caller, "openInventory", [hash(saleId, true)]); }
  purchaseInventory(buyer: Address, saleId: Hex, tokenId: bigint, configHash: Hex, unitPrice: bigint, value = unitPrice): SecondaryActorCall {
    if (uint(tokenId) === 0n || uint(unitPrice) === 0n || uint(value) < unitPrice) throw Error("Positive token/price and sufficient native value required");
    return this.#actor(buyer, "purchaseInventory", [hash(saleId, true), tokenId, hash(configHash, true)], value);
  }
  closeInventory(caller: Address, saleId: Hex, mode: "cancel" | "expire"): SecondaryActorCall {
    if (mode !== "cancel" && mode !== "expire") throw Error("Unknown inventory exit");
    return this.#actor(caller, mode === "cancel" ? "cancelSale" : "expireSale", [hash(saleId, true)]);
  }
  claimRefund(account: Address, saleId: Hex, receiver: Address): SecondaryActorCall { return this.#actor(account, "claimRefund", [hash(saleId, true), this.#receiver(receiver)]); }
  claimNft(account: Address, saleId: Hex, receiver: Address): SecondaryActorCall { return this.#actor(account, "claimNft", [hash(saleId, true), this.#receiver(receiver)]); }
  claimInventoryNft(account: Address, saleId: Hex, tokenId: bigint, receiver: Address): SecondaryActorCall { return this.#actor(account, "claimInventoryNft", [hash(saleId, true), uint(tokenId), this.#receiver(receiver)]); }
  claimRefundFor(delegate: Address, saleId: Hex, account: Address, witness: SecondaryDelegationWitness): SecondaryActorCall { return this.#delegatedClaim(delegate, "claimRefundFor", [hash(saleId, true)], account, witness); }
  claimNftFor(delegate: Address, saleId: Hex, account: Address, witness: SecondaryDelegationWitness): SecondaryActorCall { return this.#delegatedClaim(delegate, "claimNftFor", [hash(saleId, true)], account, witness); }
  claimInventoryNftFor(delegate: Address, saleId: Hex, tokenId: bigint, account: Address, witness: SecondaryDelegationWitness): SecondaryActorCall { return this.#delegatedClaim(delegate, "claimInventoryNftFor", [hash(saleId, true), uint(tokenId)], account, witness); }
  retryInventoryNft(caller: Address, saleId: Hex, tokenId: bigint): SecondaryActorCall { return this.#actor(caller, "retryInventoryNft", [hash(saleId, true), uint(tokenId)]); }
  retryInventoryRoyalty(caller: Address, saleId: Hex, receiver: Address): SecondaryActorCall { return this.#actor(caller, "retryInventoryRoyalty", [hash(saleId, true), this.#receiver(receiver)]); }
  #receiver(receiver: Address): Address { const r = address(receiver, true); if (same(r, this.adapter)) throw Error("Adapter cannot receive its own claim"); return r; }
  #witness(witness: SecondaryDelegationWitness): SecondaryDelegationWitness {
    keys(witness, ["walletWide", "index"]); if (typeof witness.walletWide !== "boolean") throw Error("Expected walletWide boolean");
    return Object.freeze({ walletWide: witness.walletWide, index: uint(witness.index) });
  }
  #signature(proof: SecondarySignature): SecondarySignature {
    keys(proof, ["authorizer", "kind", "signature"]);
    if (proof.kind !== 1n && proof.kind !== 2n) throw Error("Explicit EOA=1 or ERC1271=2 kind required");
    if (!isHexString(proof.signature, true)) throw Error("Signature must contain complete bytes");
    return Object.freeze({ authorizer: address(proof.authorizer, true), kind: proof.kind, signature: proof.signature });
  }
  #delegatedClaim(delegate: Address, method: string, prefix: readonly unknown[], account: Address, witness: SecondaryDelegationWitness): SecondaryActorCall {
    if (same(address(delegate, true), address(account, true))) throw Error("Use original own-account claim");
    return this.#actor(delegate, method, [...prefix, this.#receiver(account), this.#witness(witness)]);
  }
  /** The maker/delegate signs the original offer. Buyer alone funds and executes; owner grant stays independent. */
  acceptOffer(buyer: Address, input: SecondaryOfferInput, mode: SecondaryOfferMode): SecondaryActorCall {
    keys(input, ["authorization", "sellerProof", "offer", "offerProof", "ownerGrant", "ownerKind", "ownerSignature", "value"]);
    keys(mode, mode.mode === "delegate" ? ["mode", "witness"] : ["mode"]);
    if (mode.mode !== "maker" && mode.mode !== "delegate") throw Error("Unknown offer signer mode");
    const a = this.signing("SaleAuthorization", input.authorization).payload.message;
    const signedOffer = this.signing("SaleOffer", input.offer), o = signedOffer.payload.message;
    const g = this.signing("SaleCustodyGrant", input.ownerGrant).payload.message;
    const seller = this.#signature(input.sellerProof), signer = this.#signature(input.offerProof);
    this.#signature({ authorizer: g.owner, kind: input.ownerKind, signature: input.ownerSignature });
    const expected = this.authorizationForOffer(o, a.saleId, a.nonce, a.deadline);
    if (this.signing("SaleAuthorization", expected).payload.digest !== this.signing("SaleAuthorization", a).payload.digest
      || !same(address(buyer, true), o.buyer) || o.asset !== ZeroAddress || o.contentSelectionHash !== ZeroHash || o.finalizeBy !== 0n
      || o.price === 0n || o.tokenId === 0n || a.deadline === 0n || uint(input.value) < o.price
      || !same(g.saleRef, signedOffer.payload.digest) || g.tokenId !== o.tokenId || !same(g.core, o.core)) throw Error("Offer principal, native terms or owner grant mismatch");
    if (mode.mode === "maker" ? !same(signer.authorizer, o.buyer) : same(signer.authorizer, o.buyer)) throw Error("Signer does not match explicit offer mode");
    const args: unknown[] = [a, seller, o, signer, g, input.ownerKind, input.ownerSignature];
    if (mode.mode === "delegate") args.push(this.#witness(mode.witness));
    return this.#actor(buyer, mode.mode === "maker" ? "acceptOffer" : "acceptDelegatedOffer", args, input.value);
  }
  async #read(provider: Pick<Provider, "call">, method: string, args: readonly unknown[], blockTag: BlockTag) {
    const fn = this.#abi.getFunction(method); if (!fn?.constant) throw Error("Expected compiled read method");
    const raw = await provider.call({ ...this.#call(method, args), blockTag });
    const result = this.#abi.decodeFunctionResult(fn, raw);
    if (!same(this.#abi.encodeFunctionResult(fn, result), raw)) throw Error("Noncanonical contract read");
    return result;
  }
  async readInventory(provider: Pick<Provider, "call" | "getNetwork">, saleId: Hex, blockTag: BlockTag = "latest") {
    if ((await provider.getNetwork()).chainId !== this.chainId) throw Error("RPC chain differs");
    const [record] = await this.#read(provider, "inventoryDetails", [hash(saleId, true)], blockTag);
    return Object.freeze({ config: Object.freeze(record.config.toObject()) as unknown as SecondaryInventoryConfig,
      configHash: record.configHash as Hex, inventoryHash: record.inventoryHash as Hex,
      saleNonce: record.saleNonce as bigint, createdAt: record.createdAt as bigint, registryRevision: record.registryRevision as bigint,
      status: record.status as bigint, tokenIds: Object.freeze([...record.tokenIds]) as readonly bigint[] });
  }
  async readInventoryRoyalty(provider: Pick<Provider, "call" | "getNetwork">, saleId: Hex, tokenId: bigint, blockTag: BlockTag = "latest") {
    if ((await provider.getNetwork()).chainId !== this.chainId) throw Error("RPC chain differs");
    const q = await this.#read(provider, "inventoryRoyaltyQuote", [hash(saleId, true), uint(tokenId)], blockTag);
    return Object.freeze({ receiver: q[0] as Address, amount: q[1] as bigint,
      secondaryConsignment: q[2] as boolean, externalRoyaltiesDisclosureOnly: q[3] as boolean });
  }
  /** A successful outer Safe receipt is insufficient: also use requireSafeExecution for its exact Safe hash. */
  inventoryRegistration(receipt: ReceiptLike): { readonly saleId: Hex; readonly configHash: Hex; readonly inventoryHash: Hex; readonly consignor: Address; readonly tokenIds: readonly bigint[] } {
    if (receipt.status !== 1) throw Error("Receipt is not successful");
    const event = this.#inventory.getEvent("InventoryConfigured"); if (!event) throw Error("Selected ABI lacks InventoryConfigured");
    const matching = receipt.logs.filter(log => same(log.address, this.adapter) && same(log.topics[0] ?? "", event.topicHash));
    if (matching.length !== 1) throw Error("Expected one inventory configuration from the actual adapter");
    const log = matching[0]!, parsed = this.#inventory.parseLog({ topics: [...log.topics], data: log.data });
    if (!parsed || parsed.args.schemaVersion !== 1n) throw Error("Unknown inventory receipt schema");
    const a = parsed.args;
    return Object.freeze({ saleId: a.saleId as Hex, configHash: a.configHash as Hex, inventoryHash: a.inventoryHash as Hex,
      consignor: a.consignor as Address, tokenIds: Object.freeze([...a.tokenIds]) as readonly bigint[] });
  }
  async assertDigest<T extends object>(provider: Pick<Provider, "call" | "getNetwork">, request: SecondarySigningRequest<T>, blockTag: BlockTag = "latest"): Promise<void> {
    if ((await provider.getNetwork()).chainId !== this.chainId || request.payload.domain.chainId !== this.chainId
      || !same(request.digestCall.to, this.adapter) || !same(request.payload.domain.verifyingContract ?? "", this.adapter)) throw Error("Signing chain/adapter mismatch");
    const [actual] = await this.#read(provider, request.digestMethod, [request.payload.message], blockTag);
    if (!same(actual, request.payload.digest)) throw Error("Current host digest differs from signing payload");
  }
  /** Use the actual caller to simulate callback/value/authority behavior; no signing or broadcasting. */
  async simulate(provider: Pick<Provider, "call" | "getNetwork">, prepared: SecondaryActorCall, blockTag: BlockTag = "latest"): Promise<string> {
    if ((await provider.getNetwork()).chainId !== this.chainId || !same(prepared.call.to, this.adapter)) throw Error("Simulation chain/adapter mismatch");
    return provider.call({ ...prepared.call, from: address(prepared.caller, true), blockTag });
  }
  /** A block-bound observation, not transaction admission. Claims deliberately skip ACTIVE module gating. */
  async observeDelegation(provider: Pick<Provider, "getNetwork" | "getBlock" | "call" | "getCode">,
    pins: SecondaryDelegationPins, account: Address, delegate: Address, witness: SecondaryDelegationWitness,
    purpose: "offer" | "claim", blockTag: BlockTag = "latest") {
    if (purpose !== "offer" && purpose !== "claim") throw Error("Unknown delegation purpose");
    keys(pins, ["core", "adapterCodeHash", "moduleRegistry", "moduleRegistryCodeHash", "delegateRegistry", "delegateRegistryCodeHash", "usecase", "baseManifestHash"]);
    pins = Object.freeze({ core: address(pins.core, true), adapterCodeHash: hash(pins.adapterCodeHash, true),
      moduleRegistry: address(pins.moduleRegistry, true), moduleRegistryCodeHash: hash(pins.moduleRegistryCodeHash, true),
      delegateRegistry: address(pins.delegateRegistry, true), delegateRegistryCodeHash: hash(pins.delegateRegistryCodeHash, true),
      usecase: uint(pins.usecase), baseManifestHash: hash(pins.baseManifestHash, true) });
    const vault = this.#receiver(account), signer = address(delegate, true), w = this.#witness(witness);
    if (same(vault, signer) || pins.usecase === 0n || pins.usecase === 998n || pins.usecase === 999n
      || same(address(pins.core, true), allCollections)) throw Error("Invalid delegation coordinates");
    if ((await provider.getNetwork()).chainId !== this.chainId) throw Error("RPC chain differs");
    const block = await provider.getBlock(blockTag); if (!block?.hash) throw Error("Observed block unavailable");
    const at = block.number, timestamp = BigInt(block.timestamp);
    const expectedManifest = coder.encode(["bytes32", "uint256", "address", "bytes32", "address", "address", "bytes32", "uint256"],
      [id("6529STREAM_NATIVE_AUCTION_NFTDELEGATION_MANIFEST_V1"), this.chainId, this.adapter, hash(pins.baseManifestHash, true),
        address(pins.core, true), address(pins.delegateRegistry, true), hash(pins.delegateRegistryCodeHash, true), uint(pins.usecase)]);
    const names = ["core", "moduleRegistry", "registryCodeHash", "delegateRegistry", "delegateRegistryCodeHash", "delegationUsecase", "delegationManifest"];
    const observed = await Promise.all(names.map(n => this.#read(provider, n, [], at)));
    const expected = [pins.core, pins.moduleRegistry, pins.moduleRegistryCodeHash, pins.delegateRegistry, pins.delegateRegistryCodeHash, pins.usecase, expectedManifest];
    for (let i = 0; i < names.length; ++i) if (!same(String(observed[i]![0]), String(expected[i]))) throw Error(`Pinned ${names[i]} differs`);
    for (const [target, codeHash] of [[this.adapter, pins.adapterCodeHash], [pins.delegateRegistry, pins.delegateRegistryCodeHash],
      ...(purpose === "offer" ? [[pins.moduleRegistry, pins.moduleRegistryCodeHash]] : [])] as const) {
      const code = await provider.getCode(address(target!, true), at);
      if (code === "0x" || !same(keccak256(code), hash(codeHash!, true))) throw Error("Pinned runtime differs");
    }
    if (purpose === "offer") {
      const fn = this.#registry.getFunction("moduleRecord"); if (!fn?.constant) throw Error("Selected registry ABI lacks moduleRecord");
      const raw = await provider.call({ to: pins.moduleRegistry, data: this.#registry.encodeFunctionData(fn, [this.adapter]), blockTag: at });
      const result = this.#registry.decodeFunctionResult(fn, raw);
      if (!same(this.#registry.encodeFunctionResult(fn, result), raw)) throw Error("Noncanonical module record");
      const m = result[0];
      if (m.status !== 1n || !same(m.runtimeCodeHash, pins.adapterCodeHash) || m.deploymentManifestHash === ZeroHash
        || !same(m.moduleManifestHash, keccak256(expectedManifest)) || m.registeredAt === 0n || m.registeredAt > timestamp
        || m.statusUpdatedAt < m.registeredAt || m.statusUpdatedAt > timestamp || m.revision === 0n) throw Error("Current delegation manifest not admitted");
    }
    const scope = w.walletWide ? allCollections : pins.core;
    const key = solidityPackedKeccak256(["address", "address", "address", "uint256"], [vault, scope, signer, pins.usecase]);
    const data = id("globalDelegationHashes(bytes32,uint256)").slice(0, 10) + coder.encode(["bytes32", "uint256"], [key, w.index]).slice(2);
    const raw = await provider.call({ to: pins.delegateRegistry, data, blockTag: at });
    if (!isHexString(raw, 192)) throw Error("Delegation row must contain exactly six words");
    const row = coder.decode(["uint256", "uint256", "uint256", "uint256", "uint256", "uint256"], raw);
    if (row[0] !== BigInt(vault) || row[1] !== BigInt(signer) || row[2] > timestamp || row[3] <= timestamp || row[4] !== 1n || row[5] !== 0n) throw Error("Exact live retained delegation row is absent");
    if ((await provider.getBlock(at))?.hash !== block.hash) throw Error("Observed block changed; repeat reads");
    return Object.freeze({ blockNumber: at, blockHash: block.hash, manifestHash: keccak256(expectedManifest) as Hex,
      account: vault, delegate: signer, scope: address(scope), witness: w, startDate: row[2] as bigint, expiryDate: row[3] as bigint, purpose });
  }
}


/** Explicit caller-selected current native refund ABI; no new signature or spending authority. */
export class CurrentNativeRefundClaimsClient {
  readonly chainId: bigint;
  readonly adapter: Address;
  readonly #abi: Interface;
  constructor(chainId: bigint, adapter: Address, compiledAdapterAbi: InterfaceAbi) {
    this.chainId = uint(chainId); if (chainId === 0n) throw Error("Nonzero chain required");
    this.adapter = address(adapter, true); this.#abi = new Interface(compiledAdapterAbi);
    const expected = ["uint256 chainId", "address core", "address registry", "bytes32 registryCodeHash", "uint256 usecase", "bytes32 baseManifestHash", "address moduleRegistry", "bytes32 moduleRegistryCodeHash"];
    const read = this.#abi.getFunction("refundDelegationConfiguration");
    const claim = this.#abi.getFunction("claimRefundFor");
    if (!read?.constant || read.inputs.length !== 0 || read.outputs.length !== 1
      || read.outputs[0]?.components?.map(x => `${x.type} ${x.name}`).join(",") !== expected.join(",")
      || !claim || claim.stateMutability !== "nonpayable" || claim.inputs.map(x => x.format("sighash")).join(",") !== "bytes32,address,(bool,uint256)"
      || claim.inputs[2]?.components?.map(x => x.name).join(",") !== "walletWide,index"
      || claim.outputs.length !== 1 || claim.outputs[0]?.type !== "uint256") throw Error("Selected ABI lacks exact native refund capability");
    Object.freeze(this);
  }
  #call(method: string, args: readonly unknown[]): UnsignedCall {
    const fn = this.#abi.getFunction(method); if (!fn || fn.inputs.length !== args.length) throw Error(`Selected ABI lacks ${method}`);
    return Object.freeze({ to: this.adapter, value: 0n, data: this.#abi.encodeFunctionData(fn, args.map((v, i) => normalize(fn.inputs[i]!, v))) as Hex });
  }
  #recipient(account: Address): Address {
    const a = address(account, true); if (same(a, this.adapter)) throw Error("Refund cannot target its host"); return a;
  }
  claim(account: Address, saleId: Hex, recipient: Address = account): SecondaryActorCall {
    return Object.freeze({ caller: this.#recipient(account), call: this.#call("claimRefund", [hash(saleId, true), this.#recipient(recipient)]) });
  }
  claimFor(delegate: Address, saleId: Hex, account: Address, witness: SecondaryDelegationWitness): SecondaryActorCall {
    const caller = this.#recipient(delegate), vault = this.#recipient(account);
    if (same(caller, vault)) throw Error("Use original own-account claim");
    keys(witness, ["walletWide", "index"]);
    if (typeof witness.walletWide !== "boolean") throw Error("Expected boolean witness scope");
    return Object.freeze({ caller, call: this.#call("claimRefundFor", [hash(saleId, true), vault, { walletWide: witness.walletWide, index: uint(witness.index) }]) });
  }
  async #read(provider: Pick<Provider, "call">, method: string, args: readonly unknown[], blockTag: BlockTag) {
    const fn = this.#abi.getFunction(method); if (!fn?.constant) throw Error("Expected compiled read method");
    const raw = await provider.call({ ...this.#call(method, args), blockTag });
    const result = this.#abi.decodeFunctionResult(fn, raw);
    if (!same(this.#abi.encodeFunctionResult(fn, result), raw)) throw Error("Noncanonical contract read");
    return result;
  }
  /** Only retained deployment/grant facts are checked; earned claims have no current module/Artist gate. */
  async observeDelegation(provider: Pick<Provider, "getNetwork" | "getBlock" | "call" | "getCode">,
    pins: SecondaryDelegationPins, account: Address, delegate: Address, witness: SecondaryDelegationWitness,
    blockTag: BlockTag = "latest") {
    keys(pins, ["core", "adapterCodeHash", "moduleRegistry", "moduleRegistryCodeHash", "delegateRegistry", "delegateRegistryCodeHash", "usecase", "baseManifestHash"]);
    pins = Object.freeze({ core: address(pins.core, true), adapterCodeHash: hash(pins.adapterCodeHash, true),
      moduleRegistry: address(pins.moduleRegistry, true), moduleRegistryCodeHash: hash(pins.moduleRegistryCodeHash, true),
      delegateRegistry: address(pins.delegateRegistry, true), delegateRegistryCodeHash: hash(pins.delegateRegistryCodeHash, true),
      usecase: uint(pins.usecase), baseManifestHash: hash(pins.baseManifestHash, true) });
    keys(witness, ["walletWide", "index"]);
    if (typeof witness.walletWide !== "boolean") throw Error("Expected boolean witness scope");
    const w = Object.freeze({ walletWide: witness.walletWide, index: uint(witness.index) });
    const vault = this.#recipient(account), caller = this.#recipient(delegate);
    if (same(vault, caller) || same(pins.core, allCollections) || pins.usecase === 0n || pins.usecase === 998n || pins.usecase === 999n) throw Error("Invalid delegation coordinates");
    if ((await provider.getNetwork()).chainId !== this.chainId) throw Error("RPC chain differs");
    const block = await provider.getBlock(blockTag); if (!block?.hash) throw Error("Observed block unavailable");
    const at = block.number, timestamp = BigInt(block.timestamp);
    const [configuration] = await this.#read(provider, "refundDelegationConfiguration", [], at);
    const expected = [this.chainId, pins.core, pins.delegateRegistry, pins.delegateRegistryCodeHash, pins.usecase,
      pins.baseManifestHash, pins.moduleRegistry, pins.moduleRegistryCodeHash];
    for (let i = 0; i < expected.length; ++i) if (!same(String(configuration[i]), String(expected[i]))) throw Error("Pinned refund deployment differs");
    const manifest = coder.encode(["bytes32", "uint256", "address", "bytes32", "address", "address", "bytes32", "uint256"],
      [id("6529STREAM_NATIVE_AUCTION_NFTDELEGATION_MANIFEST_V1"), this.chainId, this.adapter, pins.baseManifestHash, pins.core,
        pins.delegateRegistry, pins.delegateRegistryCodeHash, pins.usecase]);
    const [actualManifest] = await this.#read(provider, "refundDelegationManifest", [], at);
    if (!same(actualManifest, manifest)) throw Error("Pinned refund manifest differs");
    for (const [target, codeHash] of [[this.adapter, pins.adapterCodeHash], [pins.delegateRegistry, pins.delegateRegistryCodeHash]] as const) {
      const code = await provider.getCode(target, at);
      if (code === "0x" || !same(keccak256(code), codeHash)) throw Error("Pinned runtime differs");
    }
    const scope = w.walletWide ? allCollections : pins.core;
    const key = solidityPackedKeccak256(["address", "address", "address", "uint256"], [vault, scope, caller, pins.usecase]);
    const data = id("globalDelegationHashes(bytes32,uint256)").slice(0, 10) + coder.encode(["bytes32", "uint256"], [key, w.index]).slice(2);
    const raw = await provider.call({ to: pins.delegateRegistry, data, blockTag: at });
    if (!isHexString(raw, 192)) throw Error("Delegation row must contain exactly six words");
    const row = coder.decode(["uint256", "uint256", "uint256", "uint256", "uint256", "uint256"], raw);
    if (row[0] !== BigInt(vault) || row[1] !== BigInt(caller) || row[2] > timestamp || row[3] <= timestamp || row[4] !== 1n || row[5] !== 0n) throw Error("Exact live retained delegation row is absent");
    if ((await provider.getBlock(at))?.hash !== block.hash) throw Error("Observed block changed; repeat reads");
    return Object.freeze({ blockNumber: at, blockHash: block.hash, account: vault, delegate: caller,
      witness: w, manifestHash: keccak256(manifest) as Hex, startDate: row[2] as bigint, expiryDate: row[3] as bigint });
  }
  async readCredit(provider: Pick<Provider, "getNetwork" | "call">, saleId: Hex, account: Address, blockTag: BlockTag = "latest"): Promise<bigint> {
    if ((await provider.getNetwork()).chainId !== this.chainId) throw Error("RPC chain differs");
    const [value] = await this.#read(provider, "refundableBalance", [hash(saleId, true), this.#recipient(account)], blockTag);
    return value as bigint;
  }
  async simulate(provider: Pick<Provider, "call" | "getNetwork">, prepared: SecondaryActorCall, blockTag: BlockTag = "latest"): Promise<string> {
    if ((await provider.getNetwork()).chainId !== this.chainId || !same(prepared.call.to, this.adapter) || prepared.call.value !== 0n) throw Error("Refund simulation chain/adapter/value mismatch");
    return provider.call({ ...prepared.call, from: this.#recipient(prepared.caller), blockTag });
  }
}
