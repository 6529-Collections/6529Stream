import type { Address, Hex } from "../src/generated/contracts.js";
import type { UnsignedCall } from "../src/binding.js";
import * as view from "../src/current-tagged-policy-view-v2.js";

declare const coordinates: view.TaggedPolicyViewV2Coordinates;
declare const caller: Address;
declare const renderer: Address;
declare const input: view.TaggedPolicyViewV2Input;
declare const payload: view.TaggedPolicyViewV2Payload;
declare const source: view.TaggedPolicyViewV2Source;
declare const binding: view.TaggedPolicyViewV2PolicyBinding;
declare const record: view.TaggedPolicyViewV2Record;
declare const carrier: view.TaggedPolicyViewV2Carrier;
declare const aggregate: view.TaggedPolicyViewV2Aggregate;
declare const renderRequest: view.TaggedPolicyViewV2RenderRequest;
declare const rule: view.TaggedPolicyViewV2CoordinatorPolicy;
declare const facts: view.TaggedPolicyViewV2TerminalFacts;
declare const hash: Hex;
declare const raw: Hex;

const action = view.prepareTaggedPolicyViewV2Call(coordinates, caller, { kind: "adoptPolicyView", input });
const reconstructed: view.TaggedPolicyViewV2Call = view.normalizeTaggedPolicyViewV2Call(action);
const safeCall: UnsignedCall = action.call;
const supplied: false = action.factsVerified;
const sourceHash: Hex = view.taggedPolicyViewV2SourceHash(coordinates, input, source, binding);
const checked = view.validateTaggedPolicyViewV2Source(coordinates, input, source, binding);
const pins: readonly [Address, Address, Address, Address, Address] = checked.source.payloadPointers;
const saved = view.authenticateTaggedPolicyViewV2Record(coordinates, hash, hash, raw, carrier);
const revision: bigint = saved.record.revision;
const oldFamily = view.taggedPolicyViewV2LegacyFamilyState(coordinates, input.scope.collectionId, {
  activationDefault: hash, collectionOverride: hash, overridesHead: hash, revision: 1n,
});
const next = view.taggedPolicyViewV2NextAggregate(coordinates, aggregate, record);
const family = view.taggedPolicyViewV2FamilyState(coordinates, input.scope.collectionId, oldFamily, next);
const terms = view.taggedPolicyViewV2ConsentTerms(coordinates, input.scope.collectionId, family);
const metadata: Address = terms.metadataContract;

view.prepareTaggedPolicyViewV2Read(coordinates, caller, { kind: "previewPolicyViewAdoption", input, actor: caller });
view.prepareTaggedPolicyViewV2Read(coordinates, caller, { kind: "viewAdoptionHead", scope: input.scope });
view.prepareTaggedPolicyViewV2Read(coordinates, caller, { kind: "viewAdoptionEncoded", recordHash: hash });
view.prepareTaggedPolicyViewV2Read(coordinates, caller, { kind: "viewAdoptionCarrier", recordHash: hash });
view.prepareTaggedPolicyViewV2Read(coordinates, caller, { kind: "viewAdoptionProfile", recordHash: hash });
view.prepareTaggedPolicyViewV2Read(coordinates, caller, { kind: "viewAdoptionAggregate", collectionId: 1n });
view.prepareTaggedPolicyViewV2Read(coordinates, caller, { kind: "tokenJSONForView", tokenId: 1n, scopeId: hash });
view.prepareTaggedPolicyViewV2Read(coordinates, caller, { kind: "tokenHTMLForView", tokenId: 1n, scopeId: hash });
view.prepareTaggedPolicyViewV2Read(coordinates, caller, { kind: "historicalTokenJSONForView", tokenId: 1n, recordHash: hash });
view.prepareTaggedPolicyViewV2Read(coordinates, caller, { kind: "historicalTokenHTMLForView", tokenId: 1n, recordHash: hash });
const rendering = view.prepareTaggedPolicyViewV2RendererRead(renderer, caller, {
  kind: "renderPolicyView", request: renderRequest, mode: 0n,
});
view.normalizeTaggedPolicyViewV2RendererRead(rendering);
view.prepareTaggedPolicyViewV2RendererRead(renderer, caller, { kind: "tokenURI", request: renderRequest });
view.prepareTaggedPolicyViewV2RendererRead(renderer, caller, { kind: "sourceBindings" });
view.prepareTaggedPolicyViewV2RendererRead(renderer, caller, { kind: "encodingBinding" });
view.prepareTaggedPolicyViewV2RendererRead(renderer, caller, { kind: "policyViewBinding" });
const finality: boolean = view.taggedPolicyViewV2Entropy(rule, 1n, { kind: "explicit", facts }).finalized;
view.taggedPolicyViewV2Entropy(rule, 1n, { kind: "legacy", status: 5n, seed: hash, provider: caller });
const canonical: Hex = view.encodeTaggedPolicyViewV2Payload(payload);
view.validateTaggedPolicyViewV2PayloadAdmission(view.decodeTaggedPolicyViewV2Payload(canonical));
view.validateTaggedPolicyViewV2PayloadCarriers(source, [raw]);

// @ts-expect-error no arbitrary supplied source reaches Router mutation calldata
view.prepareTaggedPolicyViewV2Call(coordinates, caller, { kind: "adoptPolicyView", input, source });
// @ts-expect-error V1 authoring is outside this explicit V2 profile
view.prepareTaggedPolicyViewV2Call(coordinates, caller, { kind: "adoptView", input });
// @ts-expect-error adoption is nonpayable; no arbitrary native funding field
view.prepareTaggedPolicyViewV2Call(coordinates, caller, { kind: "adoptPolicyView", input, value: 1n });
// @ts-expect-error nonce/signature are not original adoptPolicyView arguments
view.prepareTaggedPolicyViewV2Call(coordinates, caller, { kind: "adoptPolicyView", input, signature: raw });
// @ts-expect-error finality/checkpoint is not a provider API in this profile
view.prepareTaggedPolicyViewV2Read(coordinates, caller, { kind: "requireCurrent", input });
// @ts-expect-error exact uint256 token identity is bigint
view.prepareTaggedPolicyViewV2Read(coordinates, caller, { kind: "tokenJSONForView", tokenId: 1, scopeId: hash });
// @ts-expect-error output mode has exactly four source-admitted values
view.prepareTaggedPolicyViewV2RendererRead(renderer, caller, { kind: "renderPolicyView", request: renderRequest, mode: 4n });
// @ts-expect-error collection input retains uint256, not rounded number
const rounded: view.TaggedPolicyViewV2Scope = { ...input.scope, collectionId: 1 };
// @ts-expect-error scope enum retains original closed values
const invalidScope: view.TaggedPolicyViewV2Scope = { ...input.scope, scopeType: 5n };
// @ts-expect-error caller is an immutable reviewed value
reconstructed.caller = caller;
// @ts-expect-error nested original source fixed array is readonly
pins[0] = caller;
// @ts-expect-error original scope fields are immutable
action.request.input.scope.collectionId = 2n;
// @ts-expect-error hash/codec evidence does not become source or authority verification
const verified: true = checked.factsVerified;
// @ts-expect-error canonical policy and terminal fact branches cannot be conflated
view.taggedPolicyViewV2Entropy(rule, 1n, { kind: "legacy", facts });

void [safeCall, supplied, sourceHash, revision, metadata, finality, rounded, invalidScope, verified];
