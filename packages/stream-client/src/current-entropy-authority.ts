import { AbiCoder, Interface, ParamType, ZeroAddress, ZeroHash, getAddress, id, isHexString, keccak256, toQuantity, toUtf8Bytes } from "ethers";
import type { BlockTag, InterfaceAbi, Provider } from "ethers";
import type { Address, Hex } from "./generated/contracts.js";
import type { UnsignedCall } from "./client.js";
import { prepareFreshEntropyRecovery, type FreshEntropyRecoveryInput } from "./current-entropy.js";
import { toSafeCall } from "./safe.js";

export const ENTROPY_FINDING_HYDRATION_PROFILE = id("6529STREAM_ARTIST_ENTROPY_FINDING_HYDRATION_V1") as Hex;
export interface EntropyAuthorityBindings { readonly core: InterfaceAbi; readonly artist: InterfaceAbi; readonly entropy: InterfaceAbi; readonly coordinator: InterfaceAbi; readonly owner: InterfaceAbi }
export interface EntropyAuthorityDeployment { readonly core: Address; readonly artist: Address; readonly entropy: Address; readonly coreCodeHash: Hex; readonly artistCodeHash: Hex; readonly entropyCodeHash: Hex }
export interface ArtistEntropyIntent {
  readonly collectionId: bigint; readonly tokenId: bigint; readonly scopeId: Hex;
  readonly oldRequestKey: Hex; readonly newRequestKey: Hex; readonly priorJournalHead: Hex; readonly journalHead: Hex;
  readonly currentContentStateHash: Hex; readonly contentStateHash: Hex; readonly requestPolicyHash: Hex;
  readonly incidentEvidenceHash: Hex; readonly providerEvidenceHash: Hex; readonly reasonHash: Hex;
}
export interface ArtistEntropyTarget { readonly coordinator: Address; readonly recovery: FreshEntropyRecoveryInput; readonly intentHash: Hex; readonly unavailableEvidenceHash: Hex }
export interface ArtistEntropyFindingTerms { readonly artistId: Hex; readonly collectionId: bigint; readonly evidenceHash: Hex; readonly reasonHash: Hex }
export interface ArtistEntropyFindingRecord {
  readonly recordHash: Hex; readonly terms: ArtistEntropyFindingTerms; readonly governanceActionId: Hex;
  readonly noticeEndsAt: bigint; readonly recordedAt: bigint; readonly noticeSeconds: bigint; readonly timingRevision: bigint;
  readonly bindingGeneration: bigint; readonly bindingHash: Hex;
}
export interface ArtistEntropyAdmission { readonly target: ArtistEntropyTarget; readonly intent: ArtistEntropyIntent; readonly coordinatorCodeHash: Hex; readonly activityEpoch: bigint; readonly governanceWitnessHash: Hex }
export interface ArtistFindingContext { readonly scopeHash: Hex; readonly oldValueHash: Hex; readonly newValueHash: Hex; readonly noticeSeconds: bigint; readonly timingRevision: bigint }
export interface HydrationCheckpoint {
  readonly schema: Hex; readonly ownerState: { readonly domainId: Hex; readonly revision: bigint; readonly stateRoot: Hex; readonly recordChainTip: Hex };
  readonly replayRoot: Hex; readonly replayCount: bigint; readonly nonceRoot: Hex; readonly nonceIndexCount: bigint;
}
export interface HydrationOrigin { readonly surface: Hex; readonly scope: Hex }
export interface HydrationPolicy { readonly phaseId: Hex; readonly policyHash: Hex }
export interface EntropyFindingHydrationRequest {
  readonly authority: { readonly bindingIndex: bigint; readonly artistId: Hex; readonly collectionId: bigint;
    readonly expectedSource: readonly HydrationCheckpoint[]; readonly replayOrigins: readonly (readonly HydrationOrigin[])[]; readonly policies: readonly HydrationPolicy[] };
  readonly includePayout: boolean; readonly publications: boolean;
  readonly economics: readonly { readonly collectionId: bigint; readonly resolver: Address; readonly revenueClass: Hex; readonly scope: bigint; readonly scopeId: bigint; readonly assignmentHash: Hex }[];
  readonly attestations: readonly { readonly terms: { readonly collectionId: bigint; readonly subjectKind: bigint; readonly subjectId: Hex; readonly subjectStateHash: Hex; readonly schemaId: Hex; readonly statementHash: Hex; readonly statementURI: string }; readonly nonce: bigint }[];
}
export interface EntropyAuthorityObservation { readonly blockNumber: bigint; readonly blockHash: Hex; readonly timestamp: bigint; readonly coordinator: Address; readonly owners: readonly Address[] }
export interface QuotedEntropyFinding {
  readonly kind: "finding-context"; readonly terms: ArtistEntropyFindingTerms; readonly target: ArtistEntropyTarget;
  readonly intent: ArtistEntropyIntent; readonly context: ArtistFindingContext; readonly call: UnsignedCall; readonly observation: EntropyAuthorityObservation;
}
export interface QuotedFindingRecovery {
  readonly kind: "finding-recovery"; readonly caller: Address; readonly input: FreshEntropyRecoveryInput; readonly finding: Hex;
  readonly call: UnsignedCall; readonly intent: ArtistEntropyIntent; readonly intentHash: Hex; readonly originalRegistry: Address;
  readonly noticeEndsAt: bigint; readonly providerFee: bigint; readonly observation: EntropyAuthorityObservation; readonly stateHash: Hex;
}
export interface QuotedFindingHydration {
  readonly kind: "finding-hydration"; readonly caller: Address; readonly request: EntropyFindingHydrationRequest;
  readonly call: UnsignedCall; readonly commitment: Hex; readonly observation: EntropyAuthorityObservation;
}
type RPC = Pick<Provider, "call" | "getNetwork" | "getBlock" | "getCode">;
type Plan = QuotedFindingRecovery | QuotedFindingHydration;
const coder = AbiCoder.defaultAbiCoder();
const equal = (a: string, b: string) => a.toLowerCase() === b.toLowerCase();
function address(v: unknown): Address { if (typeof v !== "string") throw Error("Expected address"); const a = getAddress(v); if (a === ZeroAddress) throw Error("Zero address"); return a as Address; }
function uint(v: unknown, bits = 256): bigint { if (typeof v !== "bigint" || v < 0n || v >= 1n << BigInt(bits)) throw Error(`Expected uint${bits} bigint`); return v; }
function hash(v: unknown): Hex { if (typeof v !== "string" || !isHexString(v, 32) || equal(v, ZeroHash)) throw Error("Expected nonzero bytes32"); return v.toLowerCase() as Hex; }
function canonical(p: ParamType, v: unknown): unknown {
  if (p.baseType === "array") {
    if (!Array.isArray(v) || v.length > 4096 || (p.arrayLength !== -1 && v.length !== p.arrayLength)) throw Error("Invalid ABI array length");
    return Object.freeze(v.map(x => canonical(p.arrayChildren!, x)));
  }
  if (p.baseType === "tuple") {
    const c = p.components!;
    if (!v || typeof v !== "object" || Array.isArray(v) || Object.keys(v).sort().join() !== c.map(x => x.name).sort().join()) throw Error("Expected exact ABI tuple fields");
    return Object.freeze(Object.fromEntries(c.map(x => [x.name, canonical(x, (v as Record<string, unknown>)[x.name])])));
  }
  if (/^uint\d+$/.test(p.type)) return uint(v, Number(p.type.slice(4)));
  if (p.type === "address") return address(v);
  if (p.type === "bool") { if (typeof v !== "boolean") throw Error("Expected boolean"); return v; }
  if (p.type === "string") { if (typeof v !== "string" || toUtf8Bytes(v).length > 1_000_000) throw Error("Invalid string"); return v; }
  if (/^bytes(\d+)?$/.test(p.type)) { if (typeof v !== "string" || !isHexString(v, p.type === "bytes" ? true : Number(p.type.slice(5)))) throw Error("Invalid bytes"); return v.toLowerCase(); }
  throw Error("Unsupported selected ABI type");
}
function plain(p: ParamType, v: any): any {
  if (p.baseType === "array") return Object.freeze([...v].map(x => plain(p.arrayChildren!, x)));
  if (p.baseType === "tuple") return Object.freeze(Object.fromEntries(p.components!.map((x, i) => [x.name, plain(x, v[i])])));
  return v;
}

/** Caller-selected compiler ABIs; no signing, broadcast, governance substitution or local authority database. */
export class CurrentEntropyAuthorityClient {
  readonly chainId: bigint; readonly deployment: EntropyAuthorityDeployment;
  readonly #abi: Record<keyof EntropyAuthorityBindings, Interface>;
  readonly #plans = new WeakSet<object>();
  constructor(chainId: bigint, deployment: EntropyAuthorityDeployment, bindings: EntropyAuthorityBindings) {
    this.chainId = uint(chainId); if (chainId === 0n) throw Error("Zero chain");
    this.deployment = Object.freeze({ core: address(deployment.core), artist: address(deployment.artist), entropy: address(deployment.entropy),
      coreCodeHash: hash(deployment.coreCodeHash), artistCodeHash: hash(deployment.artistCodeHash), entropyCodeHash: hash(deployment.entropyCodeHash) });
    this.#abi = Object.fromEntries(Object.entries(bindings).map(([k, a]) => [k, new Interface(a)])) as Record<keyof EntropyAuthorityBindings, Interface>;
    const needed = { core: ["getSatellitePointer"], artist: ["core", "operationCoordinator", "recordEntropyUnavailabilityFinding", "entropyUnavailabilityFindingContext", "entropyUnavailabilityFindingRecord", "verifyEntropyRecoveryUnavailability", "hydrateArtistAuthorityWithEntropyFindings"],
      entropy: ["core", "artistEntropyRecoveryIntent", "freshRecoveryTransition", "requestFreshEntropyWithUnavailability", "entropyUnavailabilityEvidence"], coordinator: ["authorityHydrationSuite"], owner: ["core", "artistRegistry", "operationCoordinator", "authorityHydrationCommitment", "entropyUnavailabilityFindingOrigin"] };
    for (const [k, names] of Object.entries(needed)) for (const name of names) if (!this.#abi[k as keyof EntropyAuthorityBindings]?.getFunction(name)) throw Error(`Selected compiler ABI lacks ${k}.${name}`);
    Object.freeze(this);
  }
  #param(k: keyof EntropyAuthorityBindings, fn: string, index = 0) { return this.#abi[k].getFunction(fn)!.inputs[index]!; }
  #call(k: keyof EntropyAuthorityBindings, to: Address, fn: string, args: readonly unknown[], value = 0n): UnsignedCall {
    const inputs = this.#abi[k].getFunction(fn)!.inputs;
    if (args.length !== inputs.length) throw Error("Wrong argument count");
    return Object.freeze({ to, data: this.#abi[k].encodeFunctionData(fn, args.map((v, i) => canonical(inputs[i]!, v))) as Hex, value: uint(value) });
  }
  async #read(provider: RPC, k: keyof EntropyAuthorityBindings, to: Address, fn: string, args: readonly unknown[], tag: BlockTag, caller?: Address, value = 0n) {
    const call = this.#call(k, to, fn, args, value);
    const raw = await provider.call({ ...call, blockTag: tag, ...(caller ? { from: caller } : {}) });
    if (!isHexString(raw, true) || raw.length > 4_000_002) throw Error("Malformed or excessive return");
    const decoded = this.#abi[k].decodeFunctionResult(fn, raw);
    if (!equal(this.#abi[k].encodeFunctionResult(fn, decoded), raw)) throw Error("Noncanonical return");
    return this.#abi[k].getFunction(fn)!.outputs!.map((p, i) => plain(p, decoded[i]));
  }
  async #observe(provider: RPC, selected: boolean, tag: BlockTag): Promise<EntropyAuthorityObservation> {
    if ((await provider.getNetwork()).chainId !== this.chainId) throw Error("Wrong chain");
    const b = await provider.getBlock(tag);
    if (!b?.hash || !Number.isSafeInteger(b.number) || b.number < 0 || !Number.isSafeInteger(b.timestamp) || b.timestamp < 0) throw Error("Block unavailable");
    const t = toQuantity(b.number), d = this.deployment;
    for (const [a, h] of [[d.core, d.coreCodeHash], [d.artist, d.artistCodeHash], [d.entropy, d.entropyCodeHash]] as const) {
      const code = await provider.getCode(a, t); if (code === "0x" || !equal(keccak256(code), h)) throw Error("Pinned runtime differs");
    }
    for (const [k, a, pointer] of [["artist", d.artist, "ARTIST_REGISTRY"], ["entropy", d.entropy, "ENTROPY_COORDINATOR"]] as const) {
      if (!equal((await this.#read(provider, k, a, "core", [], t))[0], d.core)) throw Error("Reciprocal Core differs");
      if (selected) {
        const p = await this.#read(provider, "core", d.core, "getSatellitePointer", [id(pointer)], t);
        if (!equal(p[0], a) || !equal(p[1], k === "artist" ? d.artistCodeHash : d.entropyCodeHash)) throw Error("Current selection differs");
      }
    }
    const coordinator = address((await this.#read(provider, "artist", d.artist, "operationCoordinator", [], t))[0]);
    if (await provider.getCode(coordinator, t) === "0x") throw Error("Coordinator unavailable");
    const suite = (await this.#read(provider, "coordinator", coordinator, "authorityHydrationSuite", [], t))[0];
    if (!equal(suite.registry, d.artist) || !equal(suite.core, d.core)) throw Error("Artist suite differs");
    const owners: Address[] = suite.owners.map(address);
    if (owners.length !== 7 || new Set(owners).size !== 7) throw Error("Seven distinct owners required");
    for (const owner of owners) {
      if (await provider.getCode(owner, t) === "0x") throw Error("Owner unavailable");
      for (const [fn, expected] of [["core", d.core], ["artistRegistry", d.artist], ["operationCoordinator", coordinator]]) {
        if (!equal((await this.#read(provider, "owner", owner, fn!, [], t))[0], expected!)) throw Error("Owner reciprocal binding differs");
      }
    }
    return Object.freeze({ blockNumber: BigInt(b.number), blockHash: hash(b.hash), timestamp: BigInt(b.timestamp), coordinator, owners: Object.freeze(owners) });
  }
  async #finish(provider: RPC, o: EntropyAuthorityObservation) {
    const b = await provider.getBlock(toQuantity(o.blockNumber));
    if (!b?.hash || !equal(b.hash, o.blockHash)) throw Error("Observed block changed");
  }
  intentHash(intent: ArtistEntropyIntent): Hex {
    const p = this.#abi.entropy.getFunction("artistEntropyRecoveryIntent")!.outputs![0]!;
    return keccak256(coder.encode(["bytes32", "uint256", "address", "address", p], [id("6529STREAM_ENTROPY_ARTIST_RECOVERY_INTENT_V1"), this.chainId, this.deployment.entropy, this.deployment.core, canonical(p, intent)])) as Hex;
  }
  evidenceHash(originalRegistry: Address, target: ArtistEntropyTarget, intent: ArtistEntropyIntent, runtimeHash: Hex): Hex {
    const p = this.#param("artist", "recordEntropyUnavailabilityFinding", 1), ip = this.#abi.entropy.getFunction("artistEntropyRecoveryIntent")!.outputs![0]!;
    return keccak256(coder.encode(["bytes32", "uint256", "address", "address", p, ip, "bytes32"], [id("6529STREAM_ARTIST_ENTROPY_UNAVAILABILITY_V1"), this.chainId, address(originalRegistry), this.deployment.core, canonical(p, target), canonical(ip, intent), hash(runtimeHash)])) as Hex;
  }
  findingRecordHash(originalRegistry: Address, r: ArtistEntropyFindingRecord): Hex {
    canonical(this.#abi.artist.getFunction("entropyUnavailabilityFindingRecord")!.outputs![0]!, r);
    return keccak256(coder.encode(["bytes32", "uint256", "address", "bytes32", "uint256", "bytes32", "bytes32", "bytes32", "uint64", "uint64"], [id("6529STREAM_ARTIST_UNAVAILABILITY_FINDING_RECORD_V1"), this.chainId, address(originalRegistry), r.terms.artistId, r.terms.collectionId, r.terms.evidenceHash, r.terms.reasonHash, r.governanceActionId, r.noticeEndsAt, r.recordedAt])) as Hex;
  }
  #input(input: FreshEntropyRecoveryInput) { return prepareFreshEntropyRecovery(this.deployment.entropy, input, 0n).input; }
  async #intent(provider: RPC, input: FreshEntropyRecoveryInput, tag: BlockTag) {
    const intent = (await this.#read(provider, "entropy", this.deployment.entropy, "artistEntropyRecoveryIntent", [input], tag))[0] as ArtistEntropyIntent;
    const [key, content, fee] = await this.#read(provider, "entropy", this.deployment.entropy, "freshRecoveryTransition", [input], tag);
    if (!equal(intent.oldRequestKey, input.oldRequestKey) || !equal(intent.providerEvidenceHash, input.providerEvidenceHash) || !equal(intent.reasonHash, keccak256(toUtf8Bytes(input.reasonURI)))
      || !equal(intent.newRequestKey, hash(key)) || !equal(intent.contentStateHash, hash(content)) || intent.collectionId === 0n) throw Error("Full recovery intent/quote differs");
    return { intent, fee: uint(fee), intentHash: this.intentHash(intent) };
  }
  /** Context for the original class-2 Arbiter action. This is not a direct Safe/governance authorization. */
  async quoteFinding(provider: RPC, input: { readonly artistId: Hex; readonly recovery: FreshEntropyRecoveryInput; readonly unavailableEvidenceHash: Hex; readonly reasonHash: Hex }, blockTag: BlockTag = "latest"): Promise<QuotedEntropyFinding> {
    const recovery = this.#input(input.recovery), artistId = hash(input.artistId), evidence = hash(input.unavailableEvidenceHash), reason = hash(input.reasonHash);
    const o = await this.#observe(provider, true, blockTag), tag = toQuantity(o.blockNumber), { intent, intentHash } = await this.#intent(provider, recovery, tag);
    const target = Object.freeze({ coordinator: this.deployment.entropy, recovery, intentHash, unavailableEvidenceHash: evidence });
    const terms = Object.freeze({ artistId, collectionId: intent.collectionId, evidenceHash: this.evidenceHash(this.deployment.artist, target, intent, this.deployment.entropyCodeHash), reasonHash: reason });
    const context = (await this.#read(provider, "artist", this.deployment.artist, "entropyUnavailabilityFindingContext", [terms, target], tag))[0] as ArtistFindingContext;
    hash(context.scopeHash); hash(context.newValueHash); if (context.noticeSeconds === 0n || context.timingRevision === 0n) throw Error("Missing finding timing");
    await this.#finish(provider, o);
    return Object.freeze({ kind: "finding-context", terms, target, intent, context, call: this.#call("artist", this.deployment.artist, "recordEntropyUnavailabilityFinding", [terms, target]), observation: o });
  }
  /** Requires current verification, complete historical domain joins and elapsed notice; allowance belongs to caller. */
  async quoteRecovery(provider: RPC, caller: Address, rawInput: FreshEntropyRecoveryInput, expectedFinding: Hex, nativeAllowance: bigint, blockTag: BlockTag = "latest"): Promise<QuotedFindingRecovery> {
    caller = address(caller); const input = this.#input(rawInput), finding = hash(expectedFinding), value = uint(nativeAllowance);
    const o = await this.#observe(provider, true, blockTag), tag = toQuantity(o.blockNumber), q = await this.#intent(provider, input, tag);
    const [r, a] = await this.#read(provider, "artist", this.deployment.artist, "entropyUnavailabilityFindingRecord", [finding], tag) as [ArtistEntropyFindingRecord, ArtistEntropyAdmission];
    const origin = address((await this.#read(provider, "owner", o.owners[2]!, "entropyUnavailabilityFindingOrigin", [finding], tag))[0]);
    if (!equal(r.recordHash, finding) || !equal(this.findingRecordHash(origin, r), finding) || !equal(r.terms.evidenceHash, this.evidenceHash(origin, a.target, a.intent, a.coordinatorCodeHash))
      || !equal(a.coordinatorCodeHash, this.deployment.entropyCodeHash) || !equal(a.target.coordinator, this.deployment.entropy) || !equal(a.target.intentHash, q.intentHash)
      || !equal(this.intentHash(a.intent), q.intentHash) || !equal(this.#call("entropy", this.deployment.entropy, "freshRecoveryTransition", [a.target.recovery]).data, this.#call("entropy", this.deployment.entropy, "freshRecoveryTransition", [input]).data)) throw Error("Finding record/complete admission differs");
    const [valid, actualFinding, artistId, notice] = await this.#read(provider, "artist", this.deployment.artist, "verifyEntropyRecoveryUnavailability", [this.deployment.entropy, input, q.intentHash, finding], tag);
    if (valid !== true || !equal(actualFinding, finding) || !equal(artistId, r.terms.artistId) || notice !== r.noticeEndsAt || o.timestamp < notice) throw Error("Finding unavailable or notice open");
    if (value < q.fee) throw Error("Native allowance below fee");
    const stateHash = keccak256(coder.encode(["bytes32", "bytes32", "uint256", "uint256", "bytes32", "address"], [q.intentHash, finding, q.fee, a.activityEpoch, a.governanceWitnessHash, origin])) as Hex;
    await this.#finish(provider, o);
    const plan: QuotedFindingRecovery = Object.freeze({ kind: "finding-recovery", caller, input, finding, call: this.#call("entropy", this.deployment.entropy, "requestFreshEntropyWithUnavailability", [input, finding], value), intent: q.intent, intentHash: q.intentHash, originalRegistry: origin, noticeEndsAt: notice, providerFee: q.fee, observation: o, stateHash });
    this.#plans.add(plan); return plan;
  }
  #hydration(raw: EntropyFindingHydrationRequest): EntropyFindingHydrationRequest {
    const r = canonical(this.#param("artist", "hydrateArtistAuthorityWithEntropyFindings"), raw) as EntropyFindingHydrationRequest;
    hash(r.authority.artistId); if (r.authority.collectionId === 0n || r.authority.bindingIndex !== 0n || r.authority.policies.length > 128 || r.economics.length > 128 || r.attestations.length > 128
      || (r.economics.length > 0 && !r.includePayout) || (r.attestations.length > 0 && !r.economics.length) || (r.publications && !r.attestations.length)) throw Error("Unsupported hydration dependencies/bounds");
    return r;
  }
  async #markers(provider: RPC, o: EntropyAuthorityObservation) { return Promise.all(o.owners.map(async a => (await this.#read(provider, "owner", a, "authorityHydrationCommitment", [], toQuantity(o.blockNumber)))[0] as Hex)); }
  /** Complete source-owned request is mandatory. Actual permissionless op60 simulation checks every source proof. */
  async quoteHydration(provider: RPC, caller: Address, raw: EntropyFindingHydrationRequest, blockTag: BlockTag = "latest"): Promise<QuotedFindingHydration> {
    caller = address(caller); const request = this.#hydration(raw), o = await this.#observe(provider, false, blockTag);
    if ((await this.#markers(provider, o)).some(h => !equal(h, ZeroHash))) throw Error("Destination already hydrated or partial");
    const [result] = await this.#read(provider, "artist", this.deployment.artist, "hydrateArtistAuthorityWithEntropyFindings", [request], toQuantity(o.blockNumber), caller);
    await this.#finish(provider, o);
    const plan: QuotedFindingHydration = Object.freeze({ kind: "finding-hydration", caller, request, call: this.#call("artist", this.deployment.artist, "hydrateArtistAuthorityWithEntropyFindings", [request]), commitment: hash(result), observation: o });
    this.#plans.add(plan); return plan;
  }
  /** Re-read immediately before signing/submission. No failed call mutates this plan or rewrites the signed bytes. */
  async resume(provider: RPC, plan: Plan): Promise<"pending" | "completed"> {
    if (!this.#plans.has(plan)) throw Error("Plan belongs to another client or was reconstructed without validation");
    if (plan.kind === "finding-recovery") {
      const observed = await this.#observe(provider, false, "latest");
      const evidence = await this.#read(provider, "entropy", this.deployment.entropy, "entropyUnavailabilityEvidence", [plan.intent.newRequestKey], toQuantity(observed.blockNumber));
      if (!equal(evidence[0], ZeroHash)) {
        if (!equal(evidence[0], plan.finding) || !equal(evidence[1], plan.intentHash) || evidence[2] !== plan.noticeEndsAt) throw Error("Recovery receipt conflict");
        await this.#finish(provider, observed); return "completed";
      }
      if (!equal(evidence[1], ZeroHash) || evidence[2] !== 0n) throw Error("Malformed empty recovery receipt");
      const fresh = await this.quoteRecovery(provider, plan.caller, plan.input, plan.finding, plan.call.value);
      if (!equal(fresh.stateHash, plan.stateHash) || !equal(fresh.call.data, plan.call.data)) throw Error("Recovery quote changed; retain original failed attempt and prepare a new plan");
      const [key] = await this.#read(provider, "entropy", this.deployment.entropy, "requestFreshEntropyWithUnavailability", [plan.input, plan.finding], "pending", plan.caller, plan.call.value);
      if (!equal(key, plan.intent.newRequestKey)) throw Error("Pending recovery result differs");
      return "pending";
    }
    const o = await this.#observe(provider, false, "latest"), markers = await this.#markers(provider, o);
    if (markers.every(h => equal(h, plan.commitment))) { await this.#finish(provider, o); return "completed"; }
    if (markers.some(h => !equal(h, ZeroHash))) throw Error("Hydration completion conflict");
    const [result] = await this.#read(provider, "artist", this.deployment.artist, "hydrateArtistAuthorityWithEntropyFindings", [plan.request], "pending", plan.caller);
    if (!equal(result, plan.commitment)) throw Error("Hydration source/commitment changed");
    await this.#finish(provider, o); return "pending";
  }
  safeCall(plan: Plan) { if (!this.#plans.has(plan)) throw Error("Unrecognized plan"); return Object.freeze({ safe: plan.caller, call: toSafeCall(plan.call) }); }
}
