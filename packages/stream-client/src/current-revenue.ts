import { AbiCoder, Interface, ZeroAddress, ZeroHash, getAddress, id, isHexString, keccak256, toUtf8Bytes } from "ethers";
import type { InterfaceAbi, Provider, BlockTag } from "ethers";
import type { Address, Hex } from "./generated/contracts.js";
import type { UnsignedCall } from "./binding.js";
import { prepareCurrentArtistOperation } from "./current-artist.js";
import type { CurrentArtistEconomicsConsent, PreparedCurrentArtistOperation } from "./current-artist.js";

export interface CurrentRevenueBindings { readonly primary: InterfaceAbi; readonly royalty: InterfaceAbi; readonly artist: InterfaceAbi; readonly core: InterfaceAbi; readonly manager: InterfaceAbi }
export interface CurrentRevenueAddresses { readonly core: Address; readonly artist: Address; readonly primary: Address; readonly royalty: Address; readonly manager: Address }
export type RevenueScope = 0n | 1n | 2n;
export type RevenueIntent =
  | { readonly kind: "primary-profile"; readonly collectionId: bigint; readonly scope: 1n | 2n; readonly scopeId: bigint; readonly profileId: Hex }
  | { readonly kind: "primary-template"; readonly collectionId: bigint; readonly scope: RevenueScope; readonly scopeId: bigint; readonly templateId: Hex }
  | { readonly kind: "primary-template-clear"; readonly collectionId: bigint; readonly scope: 1n | 2n; readonly scopeId: bigint; readonly templateId: Hex }
  | { readonly kind: "primary-template-freeze"; readonly collectionId: bigint; readonly scope: 1n | 2n; readonly scopeId: bigint; readonly templateId: Hex }
  | { readonly kind: "royalty-set"; readonly collectionId: bigint; readonly scope: RevenueScope; readonly scopeId: bigint; readonly profileId: Hex; readonly royaltyBps: bigint }
  | { readonly kind: "snapshot-current"; readonly collectionId: bigint };
export interface RevenueFact { readonly resolver: Address; readonly revenueClass: Hex; readonly scope: bigint; readonly scopeId: bigint; readonly assignmentHash: Hex }
export interface RevenueActorCall { readonly caller: Address; readonly call: UnsignedCall }
export interface RevenuePlan {
  readonly intent: RevenueIntent; readonly caller: Address; readonly artistAccount: Address;
  readonly blockNumber: bigint; readonly blockHash: Hex; readonly codeHashes: Readonly<Record<keyof CurrentRevenueAddresses, Hex>>;
  readonly fact: RevenueFact; readonly rawSource: RevenueFact | null; readonly sourcePolicyHash: Hex | null;
  readonly mode: bigint | null; readonly electionHash: Hex | null; readonly previewCall: UnsignedCall;
  readonly ownerCall: RevenueActorCall | null; readonly approval: "current" | "fixed" | "template" | "template-clear" | "template-freeze" | null;
  readonly previousAssignmentHash: Hex | null;
  readonly templateHashContext: PrimaryTemplateHashContext | null;
  readonly existingStateHash: Hex; readonly fingerprint: Hex;
}
export interface RevenueAuthorization { readonly nonce: bigint; readonly deadline: bigint; readonly signature: Hex }
export interface PrimaryTemplateEntry { readonly account: Address; readonly accountSource: Hex; readonly sharePpm: bigint; readonly labelId: Hex }
export interface RevenueTemplateRegistration {
  readonly templateId: Hex; readonly entriesHash: Hex; readonly metadataURIHash: Hex;
  readonly entries: readonly PrimaryTemplateEntry[]; readonly ownerCall: RevenueActorCall;
  readonly blockNumber: bigint; readonly blockHash: Hex; readonly resolverRuntimeHash: Hex;
}
export interface PrimaryCollaboratorReference { readonly account: Address; readonly role: Hex; readonly shareLabelId: Hex }
export interface PrimaryTemplateHashContext {
  readonly factory: Address; readonly factoryCodeHash: Hex; readonly assetPolicy: Address;
  readonly walletRuntimeCodeHash: Hex; readonly entriesHash: Hex; readonly metadataURIHash: Hex;
  readonly beneficiaryWitness: Hex;
}
type RPC = Pick<Provider, "call" | "getNetwork" | "getBlock" | "getCode">;
const coder = AbiCoder.defaultAbiCoder();
// Accepted IStreamSplitFactory getters; exact ABI is checked against the compiler fixture.
const templateFactory = new Interface(["function assetPolicyRegistry() view returns(address)", "function splitWalletRuntimeCodeHash() pure returns(bytes32)"]);
const PRIMARY = id("PRIMARY_SALE") as Hex, ROYALTY = id("ROYALTY_ERC2981") as Hex;
export const primaryAccountSources = Object.freeze({ artist: id("COLLECTION_ARTIST") as Hex, poster: id("SALE_POSTER") as Hex });
function uint(v: unknown, bits = 256): bigint { if (typeof v !== "bigint" || v < 0n || v >= 1n << BigInt(bits)) throw Error(`Expected uint${bits} bigint`); return v; }
function addr(v: unknown, zero = false): Address { if (typeof v !== "string") throw Error("Expected address"); const a = getAddress(v); if (!zero && a === ZeroAddress) throw Error("Zero address"); return a as Address; }
function hash(v: unknown, zero = false): Hex { if (typeof v !== "string" || !isHexString(v, 32) || (!zero && v.toLowerCase() === ZeroHash)) throw Error("Expected bytes32"); return v.toLowerCase() as Hex; }
function exact(v: unknown, keys: readonly string[]) {
  if (!v || typeof v !== "object" || Array.isArray(v) || Object.keys(v).sort().join() !== [...keys].sort().join()) throw Error("Unexpected fields");
}
function same(a: string, b: string) { return a.toLowerCase() === b.toLowerCase(); }
function canonical(v: unknown): string {
  if (typeof v === "bigint") return JSON.stringify(v.toString());
  if (Array.isArray(v)) return `[${v.map(canonical).join(",")}]`;
  if (v && typeof v === "object") return `{${Object.keys(v).sort().map(k => `${JSON.stringify(k)}:${canonical((v as Record<string, unknown>)[k])}`).join(",")}}`;
  return JSON.stringify(v);
}
function freeze<T>(v: T): T { if (v && typeof v === "object") { for (const x of Object.values(v)) freeze(x); Object.freeze(v); } return v; }
function scope(i: { collectionId: bigint; scope: bigint; scopeId: bigint }) {
  if (uint(i.collectionId) === 0n || uint(i.scope, 8) > 2n || uint(i.scopeId) < 0n
    || (i.scope === 0n ? i.scopeId !== 0n : i.scope === 1n ? i.scopeId !== i.collectionId : i.scopeId === 0n)) throw Error("Invalid collection/scope coordinates");
}
function fact(v: { resolver: unknown; revenueClass: unknown; scope: unknown; scopeId: unknown; assignmentHash: unknown }, clear = false): RevenueFact {
  return freeze({ resolver: addr(v.resolver), revenueClass: hash(v.revenueClass), scope: uint(v.scope, 8), scopeId: uint(v.scopeId), assignmentHash: hash(v.assignmentHash, clear) });
}
/** Original row identity, including a valid zero role. Never substitute its rotated payout address. */
export function primaryCollaboratorSource(r: PrimaryCollaboratorReference): Hex {
  return keccak256(coder.encode(["bytes32", "address", "bytes32", "bytes32"], [id("6529STREAM_PRIMARY_COLLABORATOR_SOURCE_V1"), addr(r.account), hash(r.role, true), hash(r.shareLabelId)])) as Hex;
}
/** Collection-specific consent wrapper; the selected raw default hash still has scope0/id0. */
export function snapshotModeAssignmentHash(chainId: bigint, resolver: Address, core: Address, collectionId: bigint, election: Hex, sourceAssignment: Hex): Hex {
  if (uint(chainId) === 0n || uint(collectionId) === 0n) throw Error("Expected chain and collection");
  return keccak256(coder.encode(["bytes32", "uint256", "address", "address", "uint256", "bytes32", "bytes32"],
    [id("6529STREAM_SNAPSHOT_ROYALTY_ASSIGNMENT_V1"), chainId, addr(resolver), addr(core), collectionId, hash(election), hash(sourceAssignment)])) as Hex;
}

/** Independent StreamPrimaryAssignmentHash preimage for the exact TEMPLATE key (not resolved precedence). */
export function primaryTemplateAssignmentHash(chainId: bigint, resolver: Address, scope_: RevenueScope, scopeId: bigint, templateId: Hex, frozen: boolean, context: PrimaryTemplateHashContext): Hex {
  if (uint(chainId) === 0n || uint(scope_, 8) > 2n || (scope_ === 0n ? uint(scopeId) !== 0n : uint(scopeId) === 0n) || typeof frozen !== "boolean") throw Error("Invalid template hash coordinates");
  const h = (types: string[], values: unknown[]) => keccak256(coder.encode(types, values));
  const resolverContext = h(["bytes32", "address", "address", "address", "bytes32"], [id("6529STREAM_PRIMARY_ASSIGNMENT_RESOLVER_CONTEXT_V1"), addr(resolver), addr(context.factory), addr(context.assetPolicy), hash(context.walletRuntimeCodeHash)]);
  const scopeContext = h(["bytes32", "bytes32", "uint8", "uint256", "uint8"], [id("6529STREAM_PRIMARY_ASSIGNMENT_SCOPE_CONTEXT_V1"), PRIMARY, scope_, scopeId, 2n]);
  const templateContext = h(["bytes32", "bytes32", "bytes32"], [id("6529STREAM_PRIMARY_ASSIGNMENT_TEMPLATE_CONTEXT_V1"), hash(context.entriesHash), hash(context.metadataURIHash, true)]);
  const pointerContext = h(["bytes32", "bytes32", "bytes32", "bytes32", "bytes32"], [id("6529STREAM_PRIMARY_ASSIGNMENT_POINTER_CONTEXT_V1"), ZeroHash, ZeroHash, hash(templateId), templateContext]);
  return h(["bytes32", "uint256", "bytes32", "bytes32", "bytes32", "bytes32", "bool"], [id("6529STREAM_PRIMARY_ASSIGNMENT_V1"), chainId, resolverContext, scopeContext, pointerContext, ZeroHash, frozen]) as Hex;
}

/** Existing contract workflows only. Caller-selected compiled ABIs; no signer, broadcast or new approval domain. */
export class CurrentRevenueClient {
  readonly chainId: bigint; readonly addresses: CurrentRevenueAddresses;
  readonly #abis: Record<keyof CurrentRevenueBindings, Interface>; readonly #plans = new WeakSet<object>(); readonly #registrations = new WeakSet<object>();
  constructor(chainId: bigint, addresses: CurrentRevenueAddresses, bindings: CurrentRevenueBindings) {
    if (uint(chainId) === 0n) throw Error("Expected chainId"); this.chainId = chainId;
    exact(addresses, ["core", "artist", "primary", "royalty", "manager"]); exact(bindings, ["core", "artist", "primary", "royalty", "manager"]);
    this.addresses = freeze(Object.fromEntries(Object.entries(addresses).map(([k, v]) => [k, addr(v)])) as unknown as CurrentRevenueAddresses);
    for (const key of ["core", "artist", "primary", "royalty", "manager"] as const) if (!this.addresses[key]) throw Error(`Missing ${key}`);
    this.#abis = Object.fromEntries(Object.entries(bindings).map(([k, v]) => [k, new Interface(v)])) as Record<keyof CurrentRevenueBindings, Interface>;
    const required = { primary: ["previewArtistPrimaryAssignmentForScope", "previewArtistScopedPrimaryTemplateAssignment", "previewArtistDefaultPrimaryTemplateAssignment", "createDynamicPrimaryTemplate", "materializeDynamicCollectionPrimaryProfile"],
      royalty: ["previewArtistRoyaltyAssignmentForScope", "previewArtistSnapshotRoyaltyAssignment", "currentArtistSnapshotRoyaltyAssignment", "currentRoyaltySnapshotSource", "resolveRoyaltyAssignment"],
      artist: ["recordEconomicsConsent", "economicsConsentDigest", "recordProspectiveEconomicsConsent", "recordProspectiveTemplateEconomicsConsent", "acceptedArtist"],
      core: ["getSatellitePointer"], manager: ["phaseRoyaltyConfigHash", "registerPhaseRoyaltyPolicy"] };
    for (const [key, names] of Object.entries(required)) for (const name of names) if (!this.#abis[key as keyof CurrentRevenueBindings]?.getFunction(name)) throw Error(`Selected compiled ABI lacks ${key}.${name}`);
  }
  #call(key: keyof CurrentRevenueBindings, method: string, args: readonly unknown[]): UnsignedCall {
    return freeze({ to: this.addresses[key], value: 0n, data: this.#abis[key].encodeFunctionData(method, args) as Hex });
  }
  async #read(provider: RPC, key: keyof CurrentRevenueBindings, method: string, args: readonly unknown[], caller: Address, tag: BlockTag) {
    const raw = await provider.call({ ...this.#call(key, method, args), from: caller, blockTag: tag });
    if (typeof raw !== "string" || !isHexString(raw, true) || raw.length > 2000000) throw Error("Malformed or oversized ABI response");
    const result = this.#abis[key].decodeFunctionResult(method, raw);
    if (!same(this.#abis[key].encodeFunctionResult(method, result), raw)) throw Error("Noncanonical ABI response");
    return result;
  }
  async #observation(provider: RPC, caller: Address, blockTag: BlockTag) {
    if ((await provider.getNetwork()).chainId !== this.chainId) throw Error("RPC chain differs");
    const b = await provider.getBlock(blockTag);
    if (!b || !Number.isSafeInteger(b.number) || b.number < 0 || !b.hash) throw Error("Unavailable pinned block");
    const number = BigInt(b.number), tag = "0x" + number.toString(16), blockHash = hash(b.hash);
    const codes = {} as Record<keyof CurrentRevenueAddresses, Hex>;
    for (const key of ["core", "artist", "primary", "royalty", "manager"] as const) {
      const code = await provider.getCode(this.addresses[key], tag);
      if (!isHexString(code, true) || code === "0x") throw Error(`Missing ${key} code`); codes[key] = keccak256(code) as Hex;
    }
    const pointer = await this.#read(provider, "core", "getSatellitePointer", [id("ARTIST_REGISTRY")], caller, tag);
    if (!same(pointer[0], this.addresses.artist) || !same(pointer[1], codes.artist)) throw Error("Artist is not the actual selected facade");
    for (const [key, method] of [["primary", "core"], ["royalty", "boundCore"], ["artist", "core"], ["manager", "core"]] as const) {
      if (!same((await this.#read(provider, key, method, [], caller, tag))[0], this.addresses.core)) throw Error("Mismatched Core binding");
    }
    return { number, tag, blockHash, codes };
  }
  async #blockStill(provider: RPC, number: bigint, expected: Hex) {
    const b = await provider.getBlock("0x" + number.toString(16));
    if (!b?.hash || !same(b.hash, expected)) throw Error("Pinned block changed");
  }
  #intent(input: RevenueIntent): RevenueIntent {
    if (!input || typeof input !== "object" || uint(input.collectionId) === 0n) throw Error("Expected revenue intent");
    const i = { ...input };
    const keys = i.kind === "snapshot-current" ? ["kind", "collectionId"] : ["kind", "collectionId", "scope", "scopeId", i.kind.startsWith("primary-template") ? "templateId" : "profileId", ...(i.kind === "royalty-set" ? ["royaltyBps"] : [])];
    exact(i, keys); if (i.kind !== "snapshot-current") scope(i);
    if (i.kind === "primary-profile") { if (i.scope !== 1n && i.scope !== 2n) throw Error("Fixed Artist preview supports collection/token"); hash(i.profileId); }
    else if (i.kind === "primary-template") hash(i.templateId);
    else if (i.kind === "primary-template-clear" || i.kind === "primary-template-freeze") {
      hash(i.templateId); if (i.scope !== 1n && i.scope !== 2n) throw Error("Exact template mutation requires collection/token scope");
    }
    else if (i.kind === "royalty-set") { hash(i.profileId, true); uint(i.royaltyBps, 16); if (i.royaltyBps > 1000n || same(i.profileId, ZeroHash) !== (i.royaltyBps === 0n)) throw Error("Use canonical configured-zero or positive royalty terms"); }
    else if (i.kind !== "snapshot-current") throw Error("Unknown revenue intent");
    return freeze(i);
  }
  async quote(provider: RPC, callerInput: Address, input: RevenueIntent, options: { blockTag?: BlockTag } = {}): Promise<RevenuePlan> {
    const caller = addr(callerInput), intent = this.#intent(input), o = await this.#observation(provider, caller, options.blockTag ?? "latest");
    const artistAccount = addr((await this.#read(provider, "artist", "acceptedArtist", [intent.collectionId], caller, o.tag))[0], true);
    let key: "primary" | "royalty", method: string, args: unknown[], approval: RevenuePlan["approval"] = "fixed";
    let ownerCall: RevenueActorCall | null = null, rawSource: RevenueFact | null = null, sourcePolicyHash: Hex | null = null;
    let mode: bigint | null = null, electionHash: Hex | null = null;
    let previousAssignmentHash: Hex | null = null;
    let templateHashContext: PrimaryTemplateHashContext | null = null;
    if (intent.kind === "primary-profile") { key = "primary"; method = "previewArtistPrimaryAssignmentForScope"; args = [intent.collectionId, intent.scope, intent.scopeId, intent.profileId, ZeroHash, false]; }
    else if (intent.kind === "primary-template") { key = "primary"; approval = "template"; method = intent.scope === 0n ? "previewArtistDefaultPrimaryTemplateAssignment" : "previewArtistScopedPrimaryTemplateAssignment";
      args = intent.scope === 0n ? [intent.collectionId, intent.templateId, ZeroHash, false] : [intent.collectionId, intent.scope, intent.scopeId, intent.templateId, ZeroHash, false]; }
    else if (intent.kind === "primary-template-clear" || intent.kind === "primary-template-freeze") {
      key = "primary"; approval = intent.kind === "primary-template-clear" ? "template-clear" : "template-freeze";
      // An inherited result is not an installed exact key. Bind the reviewed template and previous bytes.
      const installed = (await this.#read(provider, key, "primaryEconomicsFacts", [intent.collectionId, intent.scope, intent.scopeId], caller, o.tag))[0];
      if (!installed.exists || installed.frozen || installed.scope !== intent.scope || installed.scopeId !== intent.scopeId
        || installed.assignmentType !== 2n || !same(installed.profileId, ZeroHash) || !same(installed.policyHash, ZeroHash)
        || !same(installed.templateId, intent.templateId)) throw Error("Expected the mutable exact installed template");
      previousAssignmentHash = hash(installed.assignmentHash);
      const factory = addr((await this.#read(provider, key, "splitFactory", [], caller, o.tag))[0]);
      const factoryCode = await provider.getCode(factory, o.tag);
      if (!isHexString(factoryCode, true) || factoryCode === "0x") throw Error("Missing template factory code");
      const factoryRead = async (name: string) => {
        const raw = await provider.call({ to: factory, from: caller, data: templateFactory.encodeFunctionData(name), blockTag: o.tag });
        const decoded = templateFactory.decodeFunctionResult(name, raw);
        if (!same(templateFactory.encodeFunctionResult(name, decoded), raw)) throw Error("Noncanonical template factory return");
        return decoded[0];
      };
      // CLEAR is a recovery path even if an old template no longer matches a corrected binding.
      // Its immutable entry/metadata hashes do not require fresh SET or beneficiary admission.
      const clearing = intent.kind === "primary-template-clear";
      const dynamic = !clearing && (await this.#read(provider, key, "isDynamicPrimaryTemplate", [intent.templateId], caller, o.tag))[0];
      const templateFacts = await this.#read(provider, key, clearing ? "primaryTemplate" : dynamic ? "dynamicPrimaryTemplateFacts" : "primaryTemplateConsentFacts",
        dynamic ? [intent.collectionId, intent.templateId] : [intent.templateId], caller, o.tag);
      if (clearing && !templateFacts[0]) throw Error("Missing immutable template");
      templateHashContext = freeze({ factory, factoryCodeHash: keccak256(factoryCode) as Hex, assetPolicy: addr(await factoryRead("assetPolicyRegistry")),
        walletRuntimeCodeHash: hash(await factoryRead("splitWalletRuntimeCodeHash")), entriesHash: hash(templateFacts[clearing ? 1 : 0]), metadataURIHash: hash(templateFacts[clearing ? 2 : 1], true),
        beneficiaryWitness: dynamic ? hash(templateFacts[3]) : ZeroHash as Hex });
      if (!same(primaryTemplateAssignmentHash(this.chainId, this.addresses.primary, intent.scope, intent.scopeId, intent.templateId, false, templateHashContext), previousAssignmentHash)) throw Error("Independent previous template hash differs");
      if (!clearing) {
        const previous = fact((await this.#read(provider, key, "previewArtistScopedPrimaryTemplateAssignment",
          [intent.collectionId, intent.scope, intent.scopeId, intent.templateId, ZeroHash, false], caller, o.tag))[0]);
        if (!same(previous.resolver, this.addresses.primary) || !same(previous.revenueClass, PRIMARY)
          || previous.scope !== intent.scope || previous.scopeId !== intent.scopeId || !same(previous.assignmentHash, previousAssignmentHash)) throw Error("Previous template preview differs from installed key");
      }
      method = intent.kind === "primary-template-clear" ? "previewArtistPrimaryClear" : "previewArtistScopedPrimaryTemplateAssignment";
      args = intent.kind === "primary-template-clear" ? [intent.collectionId, intent.scope, intent.scopeId]
        : [intent.collectionId, intent.scope, intent.scopeId, intent.templateId, ZeroHash, true];
    }
    else {
      key = "royalty"; const elected = await this.#read(provider, "royalty", "collectionRoyaltyMode", [intent.collectionId], caller, o.tag);
      mode = uint(elected[0], 8); electionHash = hash(elected[1], true);
      if ((mode !== 1n && mode !== 2n) || (mode === 2n && electionHash === ZeroHash)) throw Error("Invalid royalty mode");
      if (intent.kind === "snapshot-current") {
        if (mode !== 2n) throw Error("Snapshot mode is not elected"); method = "currentArtistSnapshotRoyaltyAssignment"; args = [intent.collectionId]; approval = "current";
        const selected = await this.#read(provider, "royalty", "resolveRoyaltyAssignment", [intent.collectionId, 0n], caller, o.tag);
        rawSource = fact(selected[0]); sourcePolicyHash = hash(selected[2]);
        if (!selected[1].configured || rawSource.scope > 1n) throw Error("No configured snapshot source");
      } else {
        if (mode === 2n && intent.scope === 2n) throw Error("Snapshot token mutation is closed");
        if (intent.scope === 0n) approval = null;
        method = mode === 2n && intent.scope === 1n ? "previewArtistSnapshotRoyaltyAssignment" : "previewArtistRoyaltyAssignmentForScope";
        args = mode === 2n && intent.scope === 1n ? [intent.collectionId, intent.profileId, intent.royaltyBps, false]
          : [intent.collectionId, intent.scope, intent.scopeId, intent.profileId, intent.royaltyBps, false];
      }
    }
    const preview = await this.#read(provider, key, method, args, caller, o.tag);
    const f = fact(preview[0], intent.kind === "primary-template-clear");
    if (intent.kind === "primary-template-clear" && (!same(f.assignmentHash, ZeroHash) || !same(hash(preview[1]), previousAssignmentHash!))) throw Error("CLEAR must remove the exact previous key to zero");
    if (intent.kind === "primary-template-freeze" && same(f.assignmentHash, previousAssignmentHash!)) throw Error("FREEZE must change the assignment hash");
    if (intent.kind === "primary-template-freeze" && !same(f.assignmentHash,
      primaryTemplateAssignmentHash(this.chainId, this.addresses.primary, intent.scope, intent.scopeId, intent.templateId, true, templateHashContext!))) throw Error("Independent frozen template hash differs");
    const expectedScope = intent.kind === "snapshot-current" ? 1n : intent.scope;
    const expectedId = intent.kind === "snapshot-current" ? intent.collectionId : intent.scopeId;
    if (!same(f.resolver, this.addresses[key]) || !same(f.revenueClass, key === "primary" ? PRIMARY : ROYALTY) || f.scope !== expectedScope || f.scopeId !== expectedId) throw Error("Preview fact differs from requested coordinates");
    if (rawSource && (!same(rawSource.resolver, this.addresses.royalty) || !same(rawSource.revenueClass, ROYALTY)
      || rawSource.scopeId !== (rawSource.scope === 0n ? 0n : intent.collectionId)
      || !same(snapshotModeAssignmentHash(this.chainId, this.addresses.royalty, this.addresses.core, intent.collectionId, electionHash!, rawSource.assignmentHash), f.assignmentHash))) throw Error("Raw source and collection mode wrapper differ");
    if (intent.kind !== "snapshot-current") {
      const owner = addr((await this.#read(provider, key, "owner", [], caller, o.tag))[0]);
      const mutation = intent.kind === "primary-profile" ? "setPrimaryProfileAssignment" : intent.kind === "primary-template" ? "setPrimaryTemplateAssignment"
        : intent.kind === "primary-template-clear" ? "clearPrimaryAssignment" : intent.kind === "primary-template-freeze" ? "freezePrimaryAssignment"
        : intent.scope === 0n ? "configureDefaultRoyalty" : intent.scope === 1n ? "configureCollectionRoyalty" : "configureTokenRoyalty";
      const values = intent.kind === "primary-profile" ? [PRIMARY, intent.scope, intent.scopeId, intent.profileId, ZeroHash]
        : intent.kind === "primary-template" ? [PRIMARY, intent.scope, intent.scopeId, intent.templateId, ZeroHash]
        : intent.kind === "primary-template-clear" || intent.kind === "primary-template-freeze" ? [PRIMARY, intent.scope, intent.scopeId]
        : intent.scope === 0n ? [intent.profileId, intent.royaltyBps] : [intent.scopeId, intent.profileId, intent.royaltyBps];
      ownerCall = freeze({ caller: owner, call: this.#call(key, mutation, values) });
    }
    const stateMethod = intent.kind === "snapshot-current" ? "resolveRoyaltyAssignment" : key === "primary" ? "primaryEconomicsFacts" : "royaltyEconomicsFacts";
    const stateArgs = intent.kind === "snapshot-current" ? [intent.collectionId, 0n] : [intent.collectionId, intent.scope, intent.scopeId];
    const state = await this.#read(provider, key, stateMethod, stateArgs, caller, o.tag);
    const existingStateHash = keccak256(this.#abis[key].encodeFunctionResult(stateMethod, state)) as Hex;
    await this.#blockStill(provider, o.number, o.blockHash);
    const terms = { existingStateHash, previousAssignmentHash, templateHashContext, intent, caller, artistAccount, codeHashes: o.codes, fact: f, rawSource, sourcePolicyHash, mode, electionHash, previewCall: this.#call(key, method, args), ownerCall, approval };
    const plan = freeze({ ...terms, blockNumber: o.number, blockHash: o.blockHash, fingerprint: keccak256(toUtf8Bytes(canonical(terms))) as Hex });
    this.#plans.add(plan); return plan;
  }
  #plan(p: RevenuePlan) { if (!p || !this.#plans.has(p)) throw Error("Expected this client's immutable observed plan; quote again after restart"); }
  /** Reobserve the exact intent/caller at latest. A stale quote is never silently rewritten. */
  async assertFresh(provider: RPC, plan: RevenuePlan, caller: Address): Promise<RevenuePlan> {
    this.#plan(plan); if (!same(addr(caller), plan.caller)) throw Error("Caller differs from quoted caller");
    const current = await this.quote(provider, caller, plan.intent);
    if (!same(current.fingerprint, plan.fingerprint)) throw Error("Revenue proposal changed; review a fresh quote"); return current;
  }
  prepareArtistApproval(plan: RevenuePlan, auth: RevenueAuthorization): PreparedCurrentArtistOperation<CurrentArtistEconomicsConsent> & { readonly caller: Address } {
    this.#plan(plan); if (plan.approval === null) throw Error("Global default installation has no Artist approval");
    if (plan.artistAccount === ZeroAddress) throw Error("This approval recipe requires an accepted Artist; do not fabricate platform consent");
    if (auth.signature === "0x" && !same(plan.caller, plan.artistAccount)) throw Error("Empty signature requires the actual Artist caller");
    const f = plan.fact;
    const original = prepareCurrentArtistOperation("artistEconomicsConsent", this.chainId, this.addresses.artist,
      { core: this.addresses.core, resolver: f.resolver, revenueClass: f.revenueClass, scope: f.scope, scopeId: f.scopeId, assignmentHash: f.assignmentHash, nonce: auth.nonce, deadline: auth.deadline },
      { collectionId: plan.intent.collectionId, signature: auth.signature });
    const p = [plan.intent.collectionId, f.resolver, f.revenueClass, f.scope, f.scopeId, f.assignmentHash], a = [auth.nonce, auth.deadline, auth.signature];
    let method = "recordEconomicsConsent", args: unknown[] = [p, a];
    if (plan.approval === "fixed") {
      if (plan.intent.kind !== "royalty-set" && plan.intent.kind !== "primary-profile") throw Error("Fixed candidate mismatch");
      method = "recordProspectiveEconomicsConsent"; args = [p, [plan.intent.profileId, ZeroHash, plan.intent.kind === "royalty-set" ? plan.intent.royaltyBps : 0n, false], a];
    } else if (plan.approval === "template") {
      if (plan.intent.kind !== "primary-template") throw Error("Template candidate mismatch"); method = "recordProspectiveTemplateEconomicsConsent"; args = [p, plan.intent.templateId, a];
    } else if (plan.approval === "template-clear") {
      method = "recordProspectiveEconomicsConsent"; args = [p, [ZeroHash, ZeroHash, 0n, false], a];
    } else if (plan.approval === "template-freeze") {
      method = "recordProspectiveTemplateFreezeConsent"; args = [p, a];
    }
    return freeze({ ...original, caller: plan.caller, method, call: this.#call("artist", method, args) });
  }
  /** Check exact original getter bytes; quote/approval preparation alone does not authenticate an RPC. */
  async assertApprovalDigest(provider: RPC, prepared: PreparedCurrentArtistOperation<CurrentArtistEconomicsConsent>, caller: Address, blockTag: BlockTag = "latest") {
    if ((await provider.getNetwork()).chainId !== this.chainId || !same(prepared.digestCall.to, this.addresses.artist)) throw Error("Wrong digest context");
    const raw = await provider.call({ ...prepared.digestCall, from: addr(caller), blockTag });
    if (!isHexString(raw, 32) || !same(raw, prepared.payload.digest)) throw Error("Original Artist digest differs");
  }
  /** Simulate the exact caller and zero-value CALL before the caller's wallet submission. */
  async simulate(provider: RPC, prepared: RevenueActorCall, blockTag: BlockTag = "latest"): Promise<Hex> {
    if ((await provider.getNetwork()).chainId !== this.chainId || prepared.call.value !== 0n) throw Error("Wrong chain or nonzero revenue setup value");
    return await provider.call({ ...prepared.call, from: addr(prepared.caller), blockTag }) as Hex;
  }
  async assertInstalled(provider: RPC, plan: RevenuePlan, caller: Address, options: { blockTag?: BlockTag } = {}): Promise<void> {
    this.#plan(plan); if (!same(addr(caller), plan.caller)) throw Error("Caller differs");
    const o = await this.#observation(provider, caller, options.blockTag ?? "latest"), i = plan.intent;
    for (const key of Object.keys(o.codes) as (keyof CurrentRevenueAddresses)[]) if (!same(o.codes[key], plan.codeHashes[key])) throw Error("Observed contract code changed");
    let actual: Hex;
    if (i.kind === "snapshot-current" || (i.kind === "royalty-set" && i.scope === 1n && plan.mode === 2n)) {
      const s = (await this.#read(provider, "royalty", "currentRoyaltySnapshotSource", [i.collectionId], caller, o.tag))[0]; actual = hash(s.modeAssignmentHash);
      if (plan.rawSource && (!same(s.sourceAssignmentHash, plan.rawSource.assignmentHash) || !same(s.sourceRoyaltyPolicyHash, plan.sourcePolicyHash!))) throw Error("Snapshot source changed");
    } else if (i.kind === "royalty-set") actual = hash((await this.#read(provider, "royalty", "royaltyEconomicsFacts", [i.collectionId, i.scope, i.scopeId], caller, o.tag))[0].assignmentHash);
    else {
      const installed = (await this.#read(provider, "primary", "primaryEconomicsFacts", [i.collectionId, i.scope, i.scopeId], caller, o.tag))[0];
      actual = hash(installed.assignmentHash, i.kind === "primary-template-clear");
      if (i.kind === "primary-template-clear" && (installed.exists || actual !== ZeroHash)) throw Error("Exact key was not cleared");
      if (i.kind === "primary-template-freeze" && (!installed.exists || !installed.frozen || !same(installed.templateId, i.templateId))) throw Error("Exact template was not frozen");
    }
    if (!same(actual, plan.fact.assignmentHash)) throw Error("Installed exact key differs from approved preview");
    await this.#blockStill(provider, o.number, o.blockHash);
  }
  /** Read the existing exact Resolver-caller admission; no transaction or signer impersonation. */
  async assertApproved(provider: RPC, plan: RevenuePlan, options: { blockTag?: BlockTag } = {}): Promise<void> {
    this.#plan(plan); if (plan.approval === null) throw Error("Global configuration has no Artist approval");
    const o = await this.#observation(provider, plan.caller, options.blockTag ?? "latest"), f = plan.fact;
    await this.#read(provider, "artist", "requireEconomicsConsent", [plan.intent.collectionId, f.revenueClass, f.scope, f.scopeId, f.assignmentHash], f.resolver, o.tag);
    await this.#blockStill(provider, o.number, o.blockHash);
  }
  /** Original owner-only, once-before-mint election. Simulation still enforces the current phase/serial conditions. */
  election(owner: Address, collectionId: bigint, mode: 1n | 2n): RevenueActorCall {
    if (uint(collectionId) === 0n || (mode !== 1n && mode !== 2n)) throw Error("Invalid mode election");
    return freeze({ caller: addr(owner), call: this.#call("royalty", "electCollectionRoyaltyMode", [collectionId, mode]) });
  }
  registerTemplate(owner: Address, entries: readonly PrimaryTemplateEntry[], metadataURIHash: Hex, references: readonly PrimaryCollaboratorReference[] = []): RevenueActorCall {
    if (!Array.isArray(entries) || entries.length === 0 || entries.length > 64 || !Array.isArray(references) || references.length > 32) throw Error("Template entry/reference bounds");
    let total = 0n; const sources = new Set(references.map(primaryCollaboratorSource));
    if (sources.size !== references.length) throw Error("Duplicate collaborator reference");
    const used = new Set<string>(), dynamicSources = new Set<string>(), entryKeys = new Set<string>();
    for (const e of entries) {
      addr(e.account, true); hash(e.accountSource, true); hash(e.labelId, true); total += uint(e.sharePpm, 32);
      if (e.sharePpm === 0n || (same(e.account, ZeroAddress) === same(e.accountSource, ZeroHash))) throw Error("Exactly one positive account/source required");
      const source = hash(e.accountSource, true);
      const entryKey = [addr(e.account, true), source, hash(e.labelId, true)].join(":");
      if (entryKeys.has(entryKey)) throw Error("Duplicate template identity"); entryKeys.add(entryKey);
      if (source !== ZeroHash) dynamicSources.add(source);
      if (same(source, primaryAccountSources.artist) && !same(e.labelId, id("artist"))) throw Error("Artist source requires artist label");
      if (sources.has(source)) { const ref = references.find(r => same(primaryCollaboratorSource(r), e.accountSource))!; if (!same(ref.shareLabelId, e.labelId) || used.has(source)) throw Error("Collaborator row/label mismatch"); used.add(source); }
      else if (!same(e.accountSource, ZeroHash) && !same(e.accountSource, primaryAccountSources.artist) && !same(e.accountSource, primaryAccountSources.poster)) throw Error("Undeclared collaborator source");
    }
    if (total !== 1000000n || used.size !== sources.size || dynamicSources.size > 8) throw Error("Incomplete sources or total shares");
    const dynamic = references.length > 0 || (dynamicSources.has(primaryAccountSources.artist) && dynamicSources.has(primaryAccountSources.poster));
    if (dynamic) {
      if (!dynamicSources.has(primaryAccountSources.artist)) throw Error("Collaborator template requires the artist source");
      for (const e of entries) if (same(e.accountSource, ZeroHash) || same(e.accountSource, primaryAccountSources.poster)) {
        if (same(e.labelId, id("artist")) || references.some(r => same(r.shareLabelId, e.labelId))) throw Error("Static/poster entry substitutes a reserved label");
      }
    }
    const args = [entries, hash(metadataURIHash, true), ...(dynamic ? [references] : [])];
    return freeze({ caller: addr(owner), call: this.#call("primary", dynamic ? "createDynamicPrimaryTemplate" : "createPrimaryTemplate", args) });
  }
  /** Simulate the original owner registration and independently reconstruct its canonical template ID. */
  async previewTemplateRegistration(provider: RPC, owner: Address, entries: readonly PrimaryTemplateEntry[], metadataURIHash: Hex, references: readonly PrimaryCollaboratorReference[] = [], options: { blockTag?: BlockTag } = {}): Promise<RevenueTemplateRegistration> {
    const ownerCall = this.registerTemplate(owner, entries, metadataURIHash, references);
    const o = await this.#observation(provider, ownerCall.caller, options.blockTag ?? "latest");
    const actualOwner = addr((await this.#read(provider, "primary", "owner", [], ownerCall.caller, o.tag))[0]);
    if (!same(actualOwner, ownerCall.caller)) throw Error("Template caller is not the current owner");
    const ordered = entries.map(e => ({ account: addr(e.account, true), accountSource: hash(e.accountSource, true), sharePpm: uint(e.sharePpm, 32), labelId: hash(e.labelId, true) }));
    ordered.sort((a, b) => {
      for (const key of ["account", "accountSource", "labelId", "sharePpm"] as const) {
        const x = BigInt(a[key]), y = BigInt(b[key]); if (x !== y) return x < y ? -1 : 1;
      }
      return 0;
    });
    const entriesHash = keccak256(coder.encode(["tuple(address account,bytes32 accountSource,uint32 sharePpm,bytes32 labelId)[]"], [ordered])) as Hex;
    const templateId = keccak256(coder.encode(["bytes32", "uint256", "address", "uint16", "uint16", "bytes32", "bytes32"],
      [id("6529STREAM_PRIMARY_TEMPLATE_V1"), this.chainId, this.addresses.primary, 1n, 1n, entriesHash, hash(metadataURIHash, true)])) as Hex;
    const result = await provider.call({ ...ownerCall.call, from: ownerCall.caller, blockTag: o.tag });
    if (!isHexString(result, 32) || !same(result, templateId)) throw Error("Original registration template ID differs");
    await this.#blockStill(provider, o.number, o.blockHash);
    const registration = freeze({ templateId, entriesHash, metadataURIHash: hash(metadataURIHash, true), entries: ordered, ownerCall, blockNumber: o.number, blockHash: o.blockHash, resolverRuntimeHash: o.codes.primary });
    this.#registrations.add(registration); return registration;
  }
  /** Complete immutable registry readback, also valid when idempotent registration emitted no new event. */
  async assertTemplateRegistered(provider: RPC, registration: RevenueTemplateRegistration, caller: Address, options: { blockTag?: BlockTag } = {}): Promise<void> {
    if (!this.#registrations.has(registration)) throw Error("Expected this client's observed registration; preview again after restart");
    caller = addr(caller); const o = await this.#observation(provider, caller, options.blockTag ?? "latest");
    if (!same(o.codes.primary, registration.resolverRuntimeHash)) throw Error("Template Resolver code changed");
    const saved = await this.#read(provider, "primary", "primaryTemplate", [registration.templateId], caller, o.tag);
    if (saved[0] !== true || !same(saved[1], registration.entriesHash) || !same(saved[2], registration.metadataURIHash)) throw Error("Registered template differs");
    const count = (await this.#read(provider, "primary", "primaryTemplateEntryCount", [registration.templateId], caller, o.tag))[0];
    if (count !== BigInt(registration.entries.length)) throw Error("Registered entry count differs");
    for (let n = 0; n < registration.entries.length; n++) {
      const row = await this.#read(provider, "primary", "primaryTemplateEntry", [registration.templateId, BigInt(n)], caller, o.tag), expected = registration.entries[n]!;
      if (!same(row[0], expected.account) || !same(row[1], expected.accountSource) || row[2] !== expected.sharePpm || !same(row[3], expected.labelId)) throw Error("Registered canonical row differs");
    }
    await this.#blockStill(provider, o.number, o.blockHash);
  }
  /** The original signed auction poster is explicit; no executor/payout substitution. */
  materialize(caller: Address, collectionId: bigint, templateId: Hex, originalPoster: Address, dynamic: boolean, deployWallet = true): RevenueActorCall {
    if (uint(collectionId) === 0n || typeof dynamic !== "boolean" || typeof deployWallet !== "boolean") throw Error("Expected collection/template mode");
    return freeze({ caller: addr(caller), call: this.#call("primary", dynamic ? "materializeDynamicCollectionPrimaryProfile" : "materializeCollectionPrimaryProfile", [hash(templateId), collectionId, addr(originalPoster), deployWallet]) });
  }
  async previewMaterialization(provider: RPC, caller: Address, collectionId: bigint, templateId: Hex, originalPoster: Address, dynamic: boolean, options: { blockTag?: BlockTag } = {}) {
    if (uint(collectionId) === 0n || typeof dynamic !== "boolean") throw Error("Expected collection/template mode"); caller = addr(caller);
    const o = await this.#observation(provider, caller, options.blockTag ?? "latest");
    const method = dynamic ? "previewDynamicCollectionPrimaryProfile" : "previewCollectionPrimaryProfile";
    const result = await this.#read(provider, "primary", method, [hash(templateId), collectionId, addr(originalPoster)], caller, o.tag);
    await this.#blockStill(provider, o.number, o.blockHash);
    return freeze({ blockNumber: o.number, blockHash: o.blockHash, originalPoster: addr(originalPoster), profileId: hash(result[0]), wallet: addr(result[1]), entriesHash: hash(result[2]), beneficiaryHash: dynamic ? hash(result[3]) : null });
  }
  async snapshotPhase(provider: RPC, caller: Address, collectionId: bigint, phaseId: Hex, applicationConfigHash: Hex, options: { blockTag?: BlockTag } = {}) {
    if (uint(collectionId) === 0n) throw Error("Expected collection"); caller = addr(caller); hash(phaseId); hash(applicationConfigHash);
    const o = await this.#observation(provider, caller, options.blockTag ?? "latest");
    const s = (await this.#read(provider, "royalty", "currentRoyaltySnapshotSource", [collectionId], caller, o.tag))[0];
    if (s.collectionId !== collectionId || !same(snapshotModeAssignmentHash(this.chainId, this.addresses.royalty, this.addresses.core, collectionId, hash(s.electionHash), hash(s.sourceAssignmentHash)), s.modeAssignmentHash)) throw Error("Snapshot source coordinates differ");
    const policy = freeze({ configured: true, applicationConfigHash, resolver: this.addresses.royalty, resolverRuntimeHash: o.codes.royalty, electionHash: hash(s.electionHash), expectedModeAssignmentHash: hash(s.modeAssignmentHash), expectedSourceRoyaltyPolicyHash: hash(s.sourceRoyaltyPolicyHash) });
    const configHash = hash((await this.#read(provider, "manager", "phaseRoyaltyConfigHash", [collectionId, phaseId, policy], caller, o.tag))[0]);
    const owner = addr((await this.#read(provider, "manager", "owner", [], caller, o.tag))[0]);
    await this.#blockStill(provider, o.number, o.blockHash);
    return freeze({ blockNumber: o.number, blockHash: o.blockHash, policy, configHash, ownerCall: { caller: owner, call: this.#call("manager", "registerPhaseRoyaltyPolicy", [collectionId, phaseId, policy]) } });
  }
}
