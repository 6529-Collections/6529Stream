import {
  AbiCoder, Interface, ParamType, ZeroAddress, ZeroHash, getAddress,
  getBytes, id, isHexString, keccak256, toUtf8Bytes, toUtf8String,
} from "ethers";
import type { Address, Hex } from "./generated/contracts.js";
import type { UnsignedCall } from "./binding.js";

/** ABI125 source profile. These codecs do not establish runtime admission or VIEW finality. */
export const TAGGED_POLICY_VIEW_V2_SOURCE = "00686b799ccf60713a0a30e1e81fca0c7281912d";
export const TAGGED_POLICY_VIEW_V2_PROFILE = id("6529STREAM_STATIC_ADOPTED_POLICY_VIEW_V2") as Hex;
export const TAGGED_POLICY_VIEW_V2_CONTEXT = id("STREAM_ADOPTED_POLICY_VIEW_CONTEXT_V2") as Hex;
export const TAGGED_POLICY_VIEW_V1_CONTEXT = id("STREAM_ADOPTED_VIEW_CONTEXT_V1") as Hex;
export const TAGGED_POLICY_VIEW_V2_SCHEMA_ID = id("STREAM_STATIC_POLICY_VIEW_PAYLOAD_V2") as Hex;
export const TAGGED_POLICY_VIEW_V2_FAMILY = id("RENDERER_CONFIG") as Hex;
export const TAGGED_POLICY_VIEW_V2_MAX_PAYLOAD_BYTES = 40960;
export const TAGGED_POLICY_VIEW_V2_MAX_RECORD_BYTES = 8192;
export const TAGGED_POLICY_VIEW_V2_MAX_OUTPUT_BYTES = 262144;

export interface TaggedPolicyViewV2Coordinates {
  readonly chainId: bigint;
  readonly core: Address;
  readonly router: Address;
}

export interface TaggedPolicyViewV2Scope {
  readonly scopeType: 0n | 1n | 2n | 3n | 4n;
  readonly collectionId: bigint;
  readonly tokenId: bigint;
  readonly scopeId: Hex;
}

export interface TaggedPolicyViewV2Input {
  readonly scope: TaggedPolicyViewV2Scope;
  readonly viewId: Hex;
  readonly viewRecordHash: Hex;
  readonly expectedPrevious: Hex;
  readonly rendererRegistry: Address;
  readonly rendererVersionKey: Hex;
  readonly expectedSourceHash: Hex;
}

export interface TaggedPolicyViewV2Payload {
  readonly contextVersion: Hex;
  readonly name: string;
  readonly description: string;
  readonly imageURI: string;
  readonly script: Hex;
}

export interface TaggedPolicyViewV2Binding {
  readonly views: Address;
  readonly viewsCodeHash: Hex;
  readonly membership: Address;
  readonly membershipCodeHash: Hex;
  readonly readGas: bigint;
  readonly sourceGas: bigint;
}

export interface TaggedPolicyViewV2Route {
  readonly core: Address;
  readonly coreCodeHash: Hex;
  readonly router: Address;
  readonly routerCodeHash: Hex;
  readonly artist: Address;
  readonly artistCodeHash: Hex;
  readonly finality: Address;
  readonly finalityCodeHash: Hex;
  readonly provider: Address;
  readonly providerCodeHash: Hex;
  readonly metadata: Address;
  readonly metadataCodeHash: Hex;
  readonly schemas: Address;
  readonly schemasCodeHash: Hex;
  readonly store: Address;
  readonly storeCodeHash: Hex;
  readonly binding: TaggedPolicyViewV2Binding;
}

export interface TaggedPolicyViewV2Membership {
  readonly scopeSubject: Hex;
  readonly scopeManifestHash: Hex;
  readonly sourceRecordHash: Hex;
  readonly tokenCount: bigint;
  readonly tokenListHash: Hex;
  readonly membershipHash: Hex;
  readonly inventoryCount: bigint;
  readonly inventoryPrefixHash: Hex;
}

export interface TaggedPolicyViewV2Selection {
  readonly registry: Address;
  readonly registryCodeHash: Hex;
  readonly versionKey: Hex;
  readonly renderer: Address;
  readonly rendererCodeHash: Hex;
  readonly rendererId: Hex;
  readonly rendererVersion: Hex;
  readonly contextVersion: Hex;
  readonly schemaHash: Hex;
  readonly readSetHash: Hex;
  readonly registrationHash: Hex;
}

export interface TaggedPolicyViewV2Source {
  readonly route: TaggedPolicyViewV2Route;
  readonly membership: TaggedPolicyViewV2Membership;
  readonly renderer: TaggedPolicyViewV2Selection;
  readonly schemaHash: Hex;
  readonly manifestSchemaHash: Hex;
  readonly canonicalizationHash: Hex;
  readonly manifestPayloadHash: Hex;
  readonly viewReceiptHash: Hex;
  readonly payloadHash: Hex;
  readonly payloadBytes: bigint;
  readonly payloadPointers: readonly [Address, Address, Address, Address, Address];
  readonly payloadChunkHashes: readonly [Hex, Hex, Hex, Hex, Hex];
}

export interface TaggedPolicyViewV2Aggregate {
  readonly revision: bigint;
  readonly transitionChain: Hex;
}

export interface TaggedPolicyViewV2Record {
  readonly input: TaggedPolicyViewV2Input;
  readonly source: TaggedPolicyViewV2Source;
  readonly sourceHash: Hex;
  readonly recordHash: Hex;
  readonly revision: bigint;
  readonly actor: Address;
  readonly authorizationClass: bigint;
  readonly grantCollectionId: bigint;
  readonly grantRevision: bigint;
  readonly artistConsent: Hex;
  readonly adoptedAt: bigint;
  readonly aggregate: TaggedPolicyViewV2Aggregate;
}

export interface TaggedPolicyViewV2PolicyBinding {
  readonly core: Address;
  readonly coreCodeHash: Hex;
  readonly factory: Address;
  readonly factoryCodeHash: Hex;
  readonly sourceSet: Address;
  readonly sourceSetCodeHash: Hex;
  readonly chainId: bigint;
  readonly scope: TaggedPolicyViewV2Scope;
  readonly membership: TaggedPolicyViewV2Membership;
  readonly inventoryPlan: Hex;
  readonly inventoryHash: Hex;
  readonly policyChainHash: Hex;
  readonly policyCount: bigint;
}

export interface TaggedPolicyViewV2Policy {
  readonly configured: boolean;
  readonly explicitPolicy: boolean;
  readonly frozen: boolean;
  readonly mode: bigint;
  readonly securityClass: bigint;
  readonly renderRequirement: bigint;
  readonly revision: bigint;
  readonly providerEpoch: bigint;
  readonly policyHash: Hex;
  readonly contentStateHash: Hex;
  readonly lastActionId: Hex;
  readonly artistConsentRecord: Hex;
}

export interface TaggedPolicyViewV2CoordinatorPolicy {
  readonly coordinator: Address;
  readonly indexedCodeHash: Hex;
  readonly firstTokenIndex: bigint;
  readonly frozen: boolean;
  readonly moduleVersion: Hex;
  readonly moduleManifestHash: Hex;
  readonly moduleSchemaHash: Hex;
  readonly deploymentManifestHash: Hex;
  readonly policyHash: Hex;
  readonly provider: Address;
  readonly epoch: bigint;
  readonly salt: Hex;
  readonly componentDataHash: Hex;
  readonly explicitPolicy: boolean;
  readonly collectionPolicy: TaggedPolicyViewV2Policy;
}

export interface TaggedPolicyViewV2Entropy {
  readonly coordinator: Address;
  readonly coordinatorCodeHash: Hex;
  readonly policyHash: Hex;
  readonly explicitPolicy: boolean;
  readonly policy: TaggedPolicyViewV2Policy;
  readonly status: bigint;
  readonly seed: Hex;
  readonly finalized: boolean;
  readonly terminal: boolean;
}

export interface TaggedPolicyViewV2RenderRequest {
  readonly core: Address;
  readonly tokenId: bigint;
  readonly collectionId: bigint;
  readonly collectionSerial: bigint;
  readonly tokenHash: Hex;
  readonly state: 0n | 1n | 2n | 3n;
  readonly mode: 0n | 1n | 2n;
  readonly collectionSupplyMode: bigint;
  readonly collectionStatus: bigint;
  readonly viewId: Hex;
  readonly viewManifestHash: Hex;
  readonly metadataSnapshotHash: Hex;
}

/** Source-only storage-to-memory tuple from StreamMetadataStaticState.Collection. */
export interface TaggedPolicyViewV2StaticCollection {
  readonly activationDefault: Hex;
  readonly collectionOverride: Hex;
  readonly overridesHead: Hex;
  readonly revision: bigint;
}

export interface TaggedPolicyViewV2Carrier {
  readonly pointer: Address;
  readonly contentHash: Hex;
  readonly byteSize: bigint;
}

export const TAGGED_POLICY_VIEW_V2_SCOPE_TUPLE = "tuple(uint8 scopeType,uint256 collectionId,uint256 tokenId,bytes32 scopeId)";
export const TAGGED_POLICY_VIEW_V2_INPUT_TUPLE = `tuple(${TAGGED_POLICY_VIEW_V2_SCOPE_TUPLE} scope,bytes32 viewId,bytes32 viewRecordHash,bytes32 expectedPrevious,address rendererRegistry,bytes32 rendererVersionKey,bytes32 expectedSourceHash)`;
export const TAGGED_POLICY_VIEW_V2_PAYLOAD_TUPLE = "tuple(bytes32 contextVersion,string name,string description,string imageURI,bytes script)";
export const TAGGED_POLICY_VIEW_V2_BINDING_TUPLE = "tuple(address views,bytes32 viewsCodeHash,address membership,bytes32 membershipCodeHash,uint32 readGas,uint32 sourceGas)";
export const TAGGED_POLICY_VIEW_V2_ROUTE_TUPLE = `tuple(address core,bytes32 coreCodeHash,address router,bytes32 routerCodeHash,address artist,bytes32 artistCodeHash,address finality,bytes32 finalityCodeHash,address provider,bytes32 providerCodeHash,address metadata,bytes32 metadataCodeHash,address schemas,bytes32 schemasCodeHash,address store,bytes32 storeCodeHash,${TAGGED_POLICY_VIEW_V2_BINDING_TUPLE} binding)`;
export const TAGGED_POLICY_VIEW_V2_MEMBERSHIP_TUPLE = "tuple(bytes32 scopeSubject,bytes32 scopeManifestHash,bytes32 sourceRecordHash,uint256 tokenCount,bytes32 tokenListHash,bytes32 membershipHash,uint256 inventoryCount,bytes32 inventoryPrefixHash)";
export const TAGGED_POLICY_VIEW_V2_SELECTION_TUPLE = "tuple(address registry,bytes32 registryCodeHash,bytes32 versionKey,address renderer,bytes32 rendererCodeHash,bytes32 rendererId,bytes32 rendererVersion,bytes32 contextVersion,bytes32 schemaHash,bytes32 readSetHash,bytes32 registrationHash)";
export const TAGGED_POLICY_VIEW_V2_SOURCE_TUPLE = `tuple(${TAGGED_POLICY_VIEW_V2_ROUTE_TUPLE} route,${TAGGED_POLICY_VIEW_V2_MEMBERSHIP_TUPLE} membership,${TAGGED_POLICY_VIEW_V2_SELECTION_TUPLE} renderer,bytes32 schemaHash,bytes32 manifestSchemaHash,bytes32 canonicalizationHash,bytes32 manifestPayloadHash,bytes32 viewReceiptHash,bytes32 payloadHash,uint32 payloadBytes,address[5] payloadPointers,bytes32[5] payloadChunkHashes)`;
export const TAGGED_POLICY_VIEW_V2_AGGREGATE_TUPLE = "tuple(uint64 revision,bytes32 transitionChain)";
export const TAGGED_POLICY_VIEW_V2_RECORD_TUPLE = `tuple(${TAGGED_POLICY_VIEW_V2_INPUT_TUPLE} input,${TAGGED_POLICY_VIEW_V2_SOURCE_TUPLE} source,bytes32 sourceHash,bytes32 recordHash,uint64 revision,address actor,uint8 authorizationClass,uint256 grantCollectionId,uint64 grantRevision,bytes32 artistConsent,uint64 adoptedAt,${TAGGED_POLICY_VIEW_V2_AGGREGATE_TUPLE} aggregate)`;
export const TAGGED_POLICY_VIEW_V2_POLICY_BINDING_TUPLE = `tuple(address core,bytes32 coreCodeHash,address factory,bytes32 factoryCodeHash,address sourceSet,bytes32 sourceSetCodeHash,uint256 chainId,${TAGGED_POLICY_VIEW_V2_SCOPE_TUPLE} scope,${TAGGED_POLICY_VIEW_V2_MEMBERSHIP_TUPLE} membership,bytes32 inventoryPlan,bytes32 inventoryHash,bytes32 policyChainHash,uint256 policyCount)`;
export const TAGGED_POLICY_VIEW_V2_POLICY_TUPLE = "tuple(bool configured,bool explicitPolicy,bool frozen,uint8 mode,uint8 securityClass,uint8 renderRequirement,uint64 revision,uint32 providerEpoch,bytes32 policyHash,bytes32 contentStateHash,bytes32 lastActionId,bytes32 artistConsentRecord)";
export const TAGGED_POLICY_VIEW_V2_COORDINATOR_POLICY_TUPLE = `tuple(address coordinator,bytes32 indexedCodeHash,uint256 firstTokenIndex,bool frozen,bytes32 moduleVersion,bytes32 moduleManifestHash,bytes32 moduleSchemaHash,bytes32 deploymentManifestHash,bytes32 policyHash,address provider,uint32 epoch,bytes32 salt,bytes32 componentDataHash,bool explicitPolicy,${TAGGED_POLICY_VIEW_V2_POLICY_TUPLE} collectionPolicy)`;
export const TAGGED_POLICY_VIEW_V2_ENTROPY_TUPLE = `tuple(address coordinator,bytes32 coordinatorCodeHash,bytes32 policyHash,bool explicitPolicy,${TAGGED_POLICY_VIEW_V2_POLICY_TUPLE} policy,uint8 status,bytes32 seed,bool finalized,bool terminal)`;
export const TAGGED_POLICY_VIEW_V2_RENDER_REQUEST_TUPLE = "tuple(address core,uint256 tokenId,uint256 collectionId,uint256 collectionSerial,bytes32 tokenHash,uint8 state,uint8 mode,uint8 collectionSupplyMode,uint8 collectionStatus,bytes32 viewId,bytes32 viewManifestHash,bytes32 metadataSnapshotHash)";
export const TAGGED_POLICY_VIEW_V2_STATIC_COLLECTION_TUPLE = "tuple(bytes32 activationDefault,bytes32 collectionOverride,bytes32 overridesHead,uint64 revision)";
export const TAGGED_POLICY_VIEW_V2_CARRIER_TUPLE = "tuple(address pointer,bytes32 contentHash,uint32 byteSize)";

export const CURRENT_TAGGED_POLICY_VIEW_V2_ROUTER_ABI = Object.freeze([
  `function previewPolicyViewAdoption(${TAGGED_POLICY_VIEW_V2_INPUT_TUPLE} input,address actor) view returns (bytes32 familyState,bytes32 sourceHash)`,
  `function adoptPolicyView(${TAGGED_POLICY_VIEW_V2_INPUT_TUPLE} input) returns (bytes32 recordHash)`,
  "function viewAdoptionProfile(bytes32 recordHash) view returns (bytes32)",
  `function viewAdoptionHead(${TAGGED_POLICY_VIEW_V2_SCOPE_TUPLE} scope) view returns (bytes32)`,
  "function viewAdoptionEncoded(bytes32 recordHash) view returns (bytes)",
  "function viewAdoptionCarrier(bytes32 recordHash) view returns (address pointer,bytes32 contentHash,uint32 byteSize)",
  `function viewAdoptionAggregate(uint256 collectionId) view returns (${TAGGED_POLICY_VIEW_V2_AGGREGATE_TUPLE})`,
  "function tokenJSONForView(uint256 tokenId,bytes32 scopeId) view returns (string)",
  "function tokenHTMLForView(uint256 tokenId,bytes32 scopeId) view returns (string)",
  "function historicalTokenJSONForView(uint256 tokenId,bytes32 recordHash) view returns (string)",
  "function historicalTokenHTMLForView(uint256 tokenId,bytes32 recordHash) view returns (string)",
  `event ViewAdopted(uint16 schemaVersion,bytes32 profile,uint256 indexed collectionId,bytes32 indexed scopeSubject,bytes32 indexed recordHash,${TAGGED_POLICY_VIEW_V2_RECORD_TUPLE} record)`,
  `event ViewAdopted(uint16 schemaVersion,uint256 indexed collectionId,bytes32 indexed scopeSubject,bytes32 indexed recordHash,${TAGGED_POLICY_VIEW_V2_RECORD_TUPLE} record)`,
]);
export const CURRENT_TAGGED_POLICY_VIEW_V2_RENDERER_ABI = Object.freeze([
  "function sourceBindings() view returns (address[4],bytes32[4])",
  "function encodingBinding() view returns (address,bytes32)",
  `function policyViewBinding() view returns (${TAGGED_POLICY_VIEW_V2_POLICY_BINDING_TUPLE})`,
  `function renderPolicyView(${TAGGED_POLICY_VIEW_V2_RENDER_REQUEST_TUPLE} request,uint8 mode) view returns (string)`,
  `function tokenURI(${TAGGED_POLICY_VIEW_V2_RENDER_REQUEST_TUPLE} request) view returns (string)`,
]);

const coder = AbiCoder.defaultAbiCoder();
const routerInterface = new Interface(CURRENT_TAGGED_POLICY_VIEW_V2_ROUTER_ABI);
const rendererInterface = new Interface(CURRENT_TAGGED_POLICY_VIEW_V2_RENDERER_ABI);

export function taggedPolicyViewV2RouterInterface(): Interface {
  return new Interface(CURRENT_TAGGED_POLICY_VIEW_V2_ROUTER_ABI);
}

export function taggedPolicyViewV2RendererInterface(): Interface {
  return new Interface(CURRENT_TAGGED_POLICY_VIEW_V2_RENDERER_ABI);
}

function exact(value: unknown, keys: readonly string[], label: string): asserts value is Record<string, unknown> {
  if (value === null || typeof value !== "object" || Array.isArray(value)
    || Reflect.ownKeys(value).length !== keys.length
    || Reflect.ownKeys(value).some(key => typeof key !== "string" || !keys.includes(key))) {
    throw Error(`${label} has missing or unknown fields`);
  }
}

function uint(value: unknown, bits = 256): bigint {
  if (typeof value !== "bigint" || value < 0n || value >= (1n << BigInt(bits))) {
    throw Error(`Expected uint${bits} bigint`);
  }
  return value;
}

function bytes(value: unknown, size?: number): Hex {
  if (typeof value !== "string" || !isHexString(value, size) || value.length % 2 !== 0) {
    throw Error(`Expected ${size === undefined ? "bytes" : `bytes${size}`}`);
  }
  return value.toLowerCase() as Hex;
}

function address(value: unknown, nonzero = false): Address {
  if (typeof value !== "string") throw Error("Expected address");
  const result = getAddress(value) as Address;
  if (nonzero && result === ZeroAddress) throw Error("Expected nonzero address");
  return result;
}

function nonzero(value: Hex): Hex {
  if (value === ZeroHash) throw Error("Expected nonzero commitment");
  return value;
}

function text(value: unknown, maximum: number, required = false): string {
  if (typeof value !== "string" || /[\uD800-\uDBFF](?![\uDC00-\uDFFF])|(?<![\uD800-\uDBFF])[\uDC00-\uDFFF]/u.test(value)) {
    throw Error("Expected Unicode scalar text");
  }
  const length = toUtf8Bytes(value).length;
  if (length > maximum || (required && length === 0)) throw Error("Text byte bound");
  return value;
}

function normalized(type: ParamType, value: unknown, decoded = false): unknown {
  if (type.baseType === "tuple") {
    const fields = type.components!;
    if (!decoded) exact(value, fields.map(field => field.name), "Tuple");
    return Object.freeze(Object.fromEntries(fields.map((field, index) => [
      field.name,
      normalized(field, decoded ? (value as readonly unknown[])[index]
        : (value as Record<string, unknown>)[field.name], decoded),
    ])));
  }
  if (type.baseType === "array") {
    if (!Array.isArray(value) || value.length !== type.arrayLength
      || (!decoded && Reflect.ownKeys(value).length !== value.length + 1)
      || Array.from({ length: value.length }, (_, i) => i).some(i => !Object.hasOwn(value, i))) {
      throw Error("Expected dense exact-length array");
    }
    return Object.freeze(value.map(item => normalized(type.arrayChildren!, item, decoded)));
  }
  if (type.type.startsWith("uint")) return uint(value, Number(type.type.slice(4)));
  if (type.type === "address") return address(value);
  if (type.type === "bool") {
    if (typeof value !== "boolean") throw Error("Expected boolean");
    return value;
  }
  if (type.type === "string") return text(value, TAGGED_POLICY_VIEW_V2_MAX_PAYLOAD_BYTES);
  if (type.type.startsWith("bytes")) {
    const result = bytes(value, type.type === "bytes" ? undefined : Number(type.type.slice(5)));
    if (result.length > 2 + TAGGED_POLICY_VIEW_V2_MAX_PAYLOAD_BYTES * 2) throw Error("Bytes bound");
    return result;
  }
  throw Error(`Unsupported ABI type ${type.type}`);
}

function normalize<T>(tuple: string, value: unknown): T {
  return normalized(ParamType.from(tuple), value) as T;
}

function encode(tuple: string, value: unknown, maximum = TAGGED_POLICY_VIEW_V2_MAX_RECORD_BYTES): Hex {
  const result = coder.encode([tuple], [normalize(tuple, value)]) as Hex;
  if ((result.length - 2) / 2 > maximum) throw Error("Complete encoded byte bound");
  return result;
}

function decode<T>(tuple: string, input: Hex, maximum = TAGGED_POLICY_VIEW_V2_MAX_RECORD_BYTES): T {
  const raw = bytes(input);
  if (raw.length <= 2 || (raw.length - 2) / 2 > maximum) throw Error("Complete encoded byte bound");
  const value = normalized(ParamType.from(tuple), coder.decode([tuple], raw)[0], true) as T;
  if (encode(tuple, value, maximum) !== raw) throw Error("Noncanonical ABI encoding");
  return value;
}

function hash(types: readonly string[], values: readonly unknown[]): Hex {
  return keccak256(coder.encode(types, values)) as Hex;
}

function same(tuple: string, a: unknown, b: unknown): boolean {
  return encode(tuple, a) === encode(tuple, b);
}

export function normalizeTaggedPolicyViewV2Coordinates(value: TaggedPolicyViewV2Coordinates): TaggedPolicyViewV2Coordinates {
  exact(value, ["chainId", "core", "router"], "Coordinates");
  return Object.freeze({ chainId: uint(value.chainId), core: address(value.core, true), router: address(value.router, true) });
}

export function normalizeTaggedPolicyViewV2Scope(value: TaggedPolicyViewV2Scope): TaggedPolicyViewV2Scope {
  const result = normalize<TaggedPolicyViewV2Scope>(TAGGED_POLICY_VIEW_V2_SCOPE_TUPLE, value);
  if (result.scopeType > 4n) throw Error("Unknown scope type");
  return result;
}

function viewScope(value: TaggedPolicyViewV2Scope): TaggedPolicyViewV2Scope {
  const result = normalizeTaggedPolicyViewV2Scope(value);
  if (result.scopeType !== 4n || result.collectionId === 0n || result.tokenId !== 0n) {
    throw Error("Expected complete VIEW scope");
  }
  nonzero(result.scopeId);
  return result;
}

/** Preview permits an unknown expectedSourceHash; final mutation construction does not. */
export function normalizeTaggedPolicyViewV2Input(value: TaggedPolicyViewV2Input): TaggedPolicyViewV2Input {
  const result = normalize<TaggedPolicyViewV2Input>(TAGGED_POLICY_VIEW_V2_INPUT_TUPLE, value);
  viewScope(result.scope);
  nonzero(result.viewId);
  nonzero(result.viewRecordHash);
  nonzero(result.rendererVersionKey);
  address(result.rendererRegistry, true);
  return result;
}

export function normalizeTaggedPolicyViewV2Payload(value: TaggedPolicyViewV2Payload): TaggedPolicyViewV2Payload {
  const result = normalize<TaggedPolicyViewV2Payload>(TAGGED_POLICY_VIEW_V2_PAYLOAD_TUPLE, value);
  if (result.contextVersion !== TAGGED_POLICY_VIEW_V2_CONTEXT) throw Error("Wrong V2 payload context");
  text(result.name, 128, true);
  text(result.description, 8192);
  text(result.imageURI, 2048);
  const script = getBytes(result.script);
  if (script.length === 0 || script.length > 24576) throw Error("Script byte bound");
  toUtf8String(script);
  encode(TAGGED_POLICY_VIEW_V2_PAYLOAD_TUPLE, result, TAGGED_POLICY_VIEW_V2_MAX_PAYLOAD_BYTES);
  return result;
}

/** The source's publication URI check is separate from canonical retained-payload decoding. */
export function validateTaggedPolicyViewV2PayloadAdmission(value: TaggedPolicyViewV2Payload): TaggedPolicyViewV2Payload {
  const result = normalizeTaggedPolicyViewV2Payload(value);
  const uri = result.imageURI;
  if (uri !== "" && (/[\x00-\x20\x7f]/u.test(uri)
    || !((uri.startsWith("https://") && uri.length > 8 && !"/?#".includes(uri[8]!))
      || (uri.startsWith("ipfs://") && uri.length > 7) || (uri.startsWith("ar://") && uri.length > 5)))) {
    throw Error("Unsafe image URI");
  }
  return result;
}

export function encodeTaggedPolicyViewV2Payload(value: TaggedPolicyViewV2Payload): Hex {
  return encode(TAGGED_POLICY_VIEW_V2_PAYLOAD_TUPLE, normalizeTaggedPolicyViewV2Payload(value), TAGGED_POLICY_VIEW_V2_MAX_PAYLOAD_BYTES);
}

export function decodeTaggedPolicyViewV2Payload(raw: Hex): TaggedPolicyViewV2Payload {
  return normalizeTaggedPolicyViewV2Payload(decode(TAGGED_POLICY_VIEW_V2_PAYLOAD_TUPLE, raw, TAGGED_POLICY_VIEW_V2_MAX_PAYLOAD_BYTES));
}

/** Structural codec only; live source and authorization checks belong to the pinned workflow. */
export function normalizeTaggedPolicyViewV2Binding(value: TaggedPolicyViewV2Binding): TaggedPolicyViewV2Binding {
  return normalize<TaggedPolicyViewV2Binding>(TAGGED_POLICY_VIEW_V2_BINDING_TUPLE, value);
}

export function encodeTaggedPolicyViewV2Binding(value: TaggedPolicyViewV2Binding): Hex {
  return encode(TAGGED_POLICY_VIEW_V2_BINDING_TUPLE, normalizeTaggedPolicyViewV2Binding(value));
}

export function decodeTaggedPolicyViewV2Binding(raw: Hex): TaggedPolicyViewV2Binding {
  return normalizeTaggedPolicyViewV2Binding(decode(TAGGED_POLICY_VIEW_V2_BINDING_TUPLE, raw));
}

/** Structural codec only; live source and authorization checks belong to the pinned workflow. */
export function normalizeTaggedPolicyViewV2Route(value: TaggedPolicyViewV2Route): TaggedPolicyViewV2Route {
  return normalize<TaggedPolicyViewV2Route>(TAGGED_POLICY_VIEW_V2_ROUTE_TUPLE, value);
}

export function encodeTaggedPolicyViewV2Route(value: TaggedPolicyViewV2Route): Hex {
  return encode(TAGGED_POLICY_VIEW_V2_ROUTE_TUPLE, normalizeTaggedPolicyViewV2Route(value));
}

export function decodeTaggedPolicyViewV2Route(raw: Hex): TaggedPolicyViewV2Route {
  return normalizeTaggedPolicyViewV2Route(decode(TAGGED_POLICY_VIEW_V2_ROUTE_TUPLE, raw));
}

/** Structural codec only; live source and authorization checks belong to the pinned workflow. */
export function normalizeTaggedPolicyViewV2Membership(value: TaggedPolicyViewV2Membership): TaggedPolicyViewV2Membership {
  return normalize<TaggedPolicyViewV2Membership>(TAGGED_POLICY_VIEW_V2_MEMBERSHIP_TUPLE, value);
}

export function encodeTaggedPolicyViewV2Membership(value: TaggedPolicyViewV2Membership): Hex {
  return encode(TAGGED_POLICY_VIEW_V2_MEMBERSHIP_TUPLE, normalizeTaggedPolicyViewV2Membership(value));
}

export function decodeTaggedPolicyViewV2Membership(raw: Hex): TaggedPolicyViewV2Membership {
  return normalizeTaggedPolicyViewV2Membership(decode(TAGGED_POLICY_VIEW_V2_MEMBERSHIP_TUPLE, raw));
}

/** Structural codec only; live source and authorization checks belong to the pinned workflow. */
export function normalizeTaggedPolicyViewV2Selection(value: TaggedPolicyViewV2Selection): TaggedPolicyViewV2Selection {
  return normalize<TaggedPolicyViewV2Selection>(TAGGED_POLICY_VIEW_V2_SELECTION_TUPLE, value);
}

export function encodeTaggedPolicyViewV2Selection(value: TaggedPolicyViewV2Selection): Hex {
  return encode(TAGGED_POLICY_VIEW_V2_SELECTION_TUPLE, normalizeTaggedPolicyViewV2Selection(value));
}

export function decodeTaggedPolicyViewV2Selection(raw: Hex): TaggedPolicyViewV2Selection {
  return normalizeTaggedPolicyViewV2Selection(decode(TAGGED_POLICY_VIEW_V2_SELECTION_TUPLE, raw));
}

/** Structural codec only; live source and authorization checks belong to the pinned workflow. */
export function normalizeTaggedPolicyViewV2Source(value: TaggedPolicyViewV2Source): TaggedPolicyViewV2Source {
  return normalize<TaggedPolicyViewV2Source>(TAGGED_POLICY_VIEW_V2_SOURCE_TUPLE, value);
}

export function encodeTaggedPolicyViewV2Source(value: TaggedPolicyViewV2Source): Hex {
  return encode(TAGGED_POLICY_VIEW_V2_SOURCE_TUPLE, normalizeTaggedPolicyViewV2Source(value));
}

export function decodeTaggedPolicyViewV2Source(raw: Hex): TaggedPolicyViewV2Source {
  return normalizeTaggedPolicyViewV2Source(decode(TAGGED_POLICY_VIEW_V2_SOURCE_TUPLE, raw));
}

/** Structural codec only; live source and authorization checks belong to the pinned workflow. */
export function normalizeTaggedPolicyViewV2Record(value: TaggedPolicyViewV2Record): TaggedPolicyViewV2Record {
  const result = normalize<TaggedPolicyViewV2Record>(TAGGED_POLICY_VIEW_V2_RECORD_TUPLE, value);
  normalizeTaggedPolicyViewV2Scope(result.input.scope);
  return result;
}

export function encodeTaggedPolicyViewV2Record(value: TaggedPolicyViewV2Record): Hex {
  return encode(TAGGED_POLICY_VIEW_V2_RECORD_TUPLE, normalizeTaggedPolicyViewV2Record(value));
}

export function decodeTaggedPolicyViewV2Record(raw: Hex): TaggedPolicyViewV2Record {
  return normalizeTaggedPolicyViewV2Record(decode(TAGGED_POLICY_VIEW_V2_RECORD_TUPLE, raw));
}

/** Structural codec only; live source and authorization checks belong to the pinned workflow. */
export function normalizeTaggedPolicyViewV2PolicyBinding(value: TaggedPolicyViewV2PolicyBinding): TaggedPolicyViewV2PolicyBinding {
  const result = normalize<TaggedPolicyViewV2PolicyBinding>(TAGGED_POLICY_VIEW_V2_POLICY_BINDING_TUPLE, value);
  normalizeTaggedPolicyViewV2Scope(result.scope);
  return result;
}

export function encodeTaggedPolicyViewV2PolicyBinding(value: TaggedPolicyViewV2PolicyBinding): Hex {
  return encode(TAGGED_POLICY_VIEW_V2_POLICY_BINDING_TUPLE, normalizeTaggedPolicyViewV2PolicyBinding(value));
}

export function decodeTaggedPolicyViewV2PolicyBinding(raw: Hex): TaggedPolicyViewV2PolicyBinding {
  return normalizeTaggedPolicyViewV2PolicyBinding(decode(TAGGED_POLICY_VIEW_V2_POLICY_BINDING_TUPLE, raw));
}

/** Structural codec only; live source and authorization checks belong to the pinned workflow. */
export function normalizeTaggedPolicyViewV2Policy(value: TaggedPolicyViewV2Policy): TaggedPolicyViewV2Policy {
  return normalize<TaggedPolicyViewV2Policy>(TAGGED_POLICY_VIEW_V2_POLICY_TUPLE, value);
}

export function encodeTaggedPolicyViewV2Policy(value: TaggedPolicyViewV2Policy): Hex {
  return encode(TAGGED_POLICY_VIEW_V2_POLICY_TUPLE, normalizeTaggedPolicyViewV2Policy(value));
}

export function decodeTaggedPolicyViewV2Policy(raw: Hex): TaggedPolicyViewV2Policy {
  return normalizeTaggedPolicyViewV2Policy(decode(TAGGED_POLICY_VIEW_V2_POLICY_TUPLE, raw));
}

/** Structural codec only; live source and authorization checks belong to the pinned workflow. */
export function normalizeTaggedPolicyViewV2CoordinatorPolicy(value: TaggedPolicyViewV2CoordinatorPolicy): TaggedPolicyViewV2CoordinatorPolicy {
  return normalize<TaggedPolicyViewV2CoordinatorPolicy>(TAGGED_POLICY_VIEW_V2_COORDINATOR_POLICY_TUPLE, value);
}

export function encodeTaggedPolicyViewV2CoordinatorPolicy(value: TaggedPolicyViewV2CoordinatorPolicy): Hex {
  return encode(TAGGED_POLICY_VIEW_V2_COORDINATOR_POLICY_TUPLE, normalizeTaggedPolicyViewV2CoordinatorPolicy(value));
}

export function decodeTaggedPolicyViewV2CoordinatorPolicy(raw: Hex): TaggedPolicyViewV2CoordinatorPolicy {
  return normalizeTaggedPolicyViewV2CoordinatorPolicy(decode(TAGGED_POLICY_VIEW_V2_COORDINATOR_POLICY_TUPLE, raw));
}

/** Structural codec only; live source and authorization checks belong to the pinned workflow. */
export function normalizeTaggedPolicyViewV2Entropy(value: TaggedPolicyViewV2Entropy): TaggedPolicyViewV2Entropy {
  return normalize<TaggedPolicyViewV2Entropy>(TAGGED_POLICY_VIEW_V2_ENTROPY_TUPLE, value);
}

export function encodeTaggedPolicyViewV2Entropy(value: TaggedPolicyViewV2Entropy): Hex {
  return encode(TAGGED_POLICY_VIEW_V2_ENTROPY_TUPLE, normalizeTaggedPolicyViewV2Entropy(value));
}

export function decodeTaggedPolicyViewV2Entropy(raw: Hex): TaggedPolicyViewV2Entropy {
  return normalizeTaggedPolicyViewV2Entropy(decode(TAGGED_POLICY_VIEW_V2_ENTROPY_TUPLE, raw));
}

/** Structural codec only; live source and authorization checks belong to the pinned workflow. */
export function normalizeTaggedPolicyViewV2StaticCollection(value: TaggedPolicyViewV2StaticCollection): TaggedPolicyViewV2StaticCollection {
  return normalize<TaggedPolicyViewV2StaticCollection>(TAGGED_POLICY_VIEW_V2_STATIC_COLLECTION_TUPLE, value);
}

export function encodeTaggedPolicyViewV2StaticCollection(value: TaggedPolicyViewV2StaticCollection): Hex {
  return encode(TAGGED_POLICY_VIEW_V2_STATIC_COLLECTION_TUPLE, normalizeTaggedPolicyViewV2StaticCollection(value));
}

export function decodeTaggedPolicyViewV2StaticCollection(raw: Hex): TaggedPolicyViewV2StaticCollection {
  return normalizeTaggedPolicyViewV2StaticCollection(decode(TAGGED_POLICY_VIEW_V2_STATIC_COLLECTION_TUPLE, raw));
}

/** Structural codec only; live source and authorization checks belong to the pinned workflow. */
export function normalizeTaggedPolicyViewV2Carrier(value: TaggedPolicyViewV2Carrier): TaggedPolicyViewV2Carrier {
  return normalize<TaggedPolicyViewV2Carrier>(TAGGED_POLICY_VIEW_V2_CARRIER_TUPLE, value);
}

export function encodeTaggedPolicyViewV2Carrier(value: TaggedPolicyViewV2Carrier): Hex {
  return encode(TAGGED_POLICY_VIEW_V2_CARRIER_TUPLE, normalizeTaggedPolicyViewV2Carrier(value));
}

export function decodeTaggedPolicyViewV2Carrier(raw: Hex): TaggedPolicyViewV2Carrier {
  return normalizeTaggedPolicyViewV2Carrier(decode(TAGGED_POLICY_VIEW_V2_CARRIER_TUPLE, raw));
}

export function normalizeTaggedPolicyViewV2Aggregate(value: TaggedPolicyViewV2Aggregate): TaggedPolicyViewV2Aggregate {
  const result = normalize<TaggedPolicyViewV2Aggregate>(TAGGED_POLICY_VIEW_V2_AGGREGATE_TUPLE, value);
  if ((result.revision === 0n) !== (result.transitionChain === ZeroHash)) {
    throw Error("Inconsistent VIEW aggregate");
  }
  return result;
}

export function encodeTaggedPolicyViewV2Aggregate(value: TaggedPolicyViewV2Aggregate): Hex {
  return encode(TAGGED_POLICY_VIEW_V2_AGGREGATE_TUPLE, normalizeTaggedPolicyViewV2Aggregate(value));
}

export function decodeTaggedPolicyViewV2Aggregate(raw: Hex): TaggedPolicyViewV2Aggregate {
  return normalizeTaggedPolicyViewV2Aggregate(decode(TAGGED_POLICY_VIEW_V2_AGGREGATE_TUPLE, raw));
}

export function normalizeTaggedPolicyViewV2RenderRequest(value: TaggedPolicyViewV2RenderRequest): TaggedPolicyViewV2RenderRequest {
  const result = normalize<TaggedPolicyViewV2RenderRequest>(TAGGED_POLICY_VIEW_V2_RENDER_REQUEST_TUPLE, value);
  if (result.state > 3n || result.mode > 2n) throw Error("Unknown renderer enum");
  return result;
}

export function encodeTaggedPolicyViewV2RenderRequest(value: TaggedPolicyViewV2RenderRequest): Hex {
  return encode(TAGGED_POLICY_VIEW_V2_RENDER_REQUEST_TUPLE, normalizeTaggedPolicyViewV2RenderRequest(value));
}

export function decodeTaggedPolicyViewV2RenderRequest(raw: Hex): TaggedPolicyViewV2RenderRequest {
  return normalizeTaggedPolicyViewV2RenderRequest(decode(TAGGED_POLICY_VIEW_V2_RENDER_REQUEST_TUPLE, raw));
}

export function encodeTaggedPolicyViewV2Input(value: TaggedPolicyViewV2Input): Hex {
  return encode(TAGGED_POLICY_VIEW_V2_INPUT_TUPLE, normalizeTaggedPolicyViewV2Input(value));
}

export function decodeTaggedPolicyViewV2Input(raw: Hex): TaggedPolicyViewV2Input {
  return normalizeTaggedPolicyViewV2Input(decode(TAGGED_POLICY_VIEW_V2_INPUT_TUPLE, raw));
}

/** A zero profile means V1 only when the original record carrier actually exists. */
export function normalizeTaggedPolicyViewV2Profile(profile: Hex, carrier: TaggedPolicyViewV2Carrier): Hex {
  const saved = normalizeTaggedPolicyViewV2Carrier(carrier);
  address(saved.pointer, true);
  nonzero(saved.contentHash);
  if (saved.byteSize === 0n || saved.byteSize > BigInt(TAGGED_POLICY_VIEW_V2_MAX_RECORD_BYTES)) {
    throw Error("Unknown or invalid VIEW record carrier");
  }
  return closedProfile(profile);
}

function closedProfile(value: Hex): Hex {
  const result = bytes(value, 32);
  if (result !== ZeroHash && result !== TAGGED_POLICY_VIEW_V2_PROFILE) throw Error("Unknown VIEW profile");
  return result;
}

export function taggedPolicyViewV2ScopeSubject(
  coordinates: TaggedPolicyViewV2Coordinates,
  scope: TaggedPolicyViewV2Scope,
): Hex {
  const c = normalizeTaggedPolicyViewV2Coordinates(coordinates);
  const s = viewScope(scope);
  return hash(
    ["bytes32", "uint256", "address", "uint256", "uint8", "bytes32"],
    [id("6529STREAM_SUBJECT_SCOPE_V1"), c.chainId, c.core, s.collectionId, s.scopeType, s.scopeId],
  );
}

/** Exact supplied-facts preimage. This hash alone authenticates no RPC source or renderer. */
export function taggedPolicyViewV2SourceHash(
  coordinates: TaggedPolicyViewV2Coordinates,
  input: TaggedPolicyViewV2Input,
  source: TaggedPolicyViewV2Source,
  policyBinding: TaggedPolicyViewV2PolicyBinding,
): Hex {
  const c = normalizeTaggedPolicyViewV2Coordinates(coordinates);
  const p = normalizeTaggedPolicyViewV2Input(input);
  return hash(
    ["bytes32", "bytes32", "uint256", "address", TAGGED_POLICY_VIEW_V2_SCOPE_TUPLE,
      "bytes32", "bytes32", TAGGED_POLICY_VIEW_V2_SOURCE_TUPLE, TAGGED_POLICY_VIEW_V2_POLICY_BINDING_TUPLE],
    [id("6529STREAM_POLICY_VIEW_ADOPTION_SOURCE_V2"), TAGGED_POLICY_VIEW_V2_PROFILE,
      c.chainId, c.router, p.scope, p.viewId, p.viewRecordHash,
      normalizeTaggedPolicyViewV2Source(source), normalizeTaggedPolicyViewV2PolicyBinding(policyBinding)],
  );
}

/** Checks original cross-field joins; dependencies still require actual pinned reads. */
export function validateTaggedPolicyViewV2Source(
  coordinates: TaggedPolicyViewV2Coordinates,
  input: TaggedPolicyViewV2Input,
  source: TaggedPolicyViewV2Source,
  policyBinding: TaggedPolicyViewV2PolicyBinding,
): Readonly<{ source: TaggedPolicyViewV2Source; policyBinding: TaggedPolicyViewV2PolicyBinding; sourceHash: Hex; factsVerified: false }> {
  const c = normalizeTaggedPolicyViewV2Coordinates(coordinates);
  const p = normalizeTaggedPolicyViewV2Input(input);
  const s = normalizeTaggedPolicyViewV2Source(source);
  const b = normalizeTaggedPolicyViewV2PolicyBinding(policyBinding);
  const r = s.route;
  for (const key of ["core", "router", "artist", "finality", "provider", "metadata", "schemas", "store"] as const) {
    address(r[key], true);
    nonzero(r[`${key}CodeHash`]);
  }
  address(r.binding.views, true);
  address(r.binding.membership, true);
  nonzero(r.binding.viewsCodeHash);
  nonzero(r.binding.membershipCodeHash);
  if (r.binding.readGas < 50000n || r.binding.sourceGas < r.binding.readGas) throw Error("Invalid source gas bounds");
  const m = s.membership;
  for (const key of ["scopeManifestHash", "sourceRecordHash", "tokenListHash", "membershipHash"] as const) nonzero(m[key]);
  if (m.scopeSubject !== taggedPolicyViewV2ScopeSubject(c, p.scope) || m.tokenCount === 0n
    || m.inventoryCount !== 0n || m.inventoryPrefixHash !== ZeroHash) throw Error("Invalid VIEW membership");
  if (r.core !== c.core || r.router !== c.router || b.chainId !== c.chainId || b.core !== c.core
    || b.coreCodeHash !== r.coreCodeHash || !same(TAGGED_POLICY_VIEW_V2_SCOPE_TUPLE, p.scope, b.scope)
    || !same(TAGGED_POLICY_VIEW_V2_MEMBERSHIP_TUPLE, m, b.membership)) throw Error("Source coordinates disagree");
  address(b.factory, true);
  address(b.sourceSet, true);
  for (const key of ["factoryCodeHash", "sourceSetCodeHash", "inventoryPlan", "inventoryHash", "policyChainHash"] as const) nonzero(b[key]);
  if (b.policyCount === 0n || b.policyCount > m.tokenCount) throw Error("Invalid policy count");
  const selection = s.renderer;
  address(selection.renderer, true);
  address(selection.registry, true);
  for (const key of ["registryCodeHash", "rendererCodeHash", "rendererId", "rendererVersion", "schemaHash", "readSetHash", "registrationHash"] as const) nonzero(selection[key]);
  if (selection.contextVersion !== TAGGED_POLICY_VIEW_V2_CONTEXT || selection.registry !== p.rendererRegistry
    || selection.versionKey !== p.rendererVersionKey
    || selection.versionKey !== hash(["bytes32", "bytes32", "bytes32"],
      [id("6529STREAM_RENDERER_VERSION_V1"), selection.rendererId, selection.rendererVersion])) {
    throw Error("Wrong admitted renderer selection");
  }
  for (const key of ["schemaHash", "manifestSchemaHash", "canonicalizationHash", "manifestPayloadHash", "viewReceiptHash", "payloadHash"] as const) nonzero(s[key]);
  if (s.payloadBytes === 0n || s.payloadBytes > BigInt(TAGGED_POLICY_VIEW_V2_MAX_PAYLOAD_BYTES)) throw Error("Payload byte bound");
  const count = Number((s.payloadBytes + 8191n) / 8192n);
  for (let i = 0; i < 5; i++) {
    if (i < count) {
      address(s.payloadPointers[i], true);
      nonzero(s.payloadChunkHashes[i]!);
    } else if (s.payloadPointers[i] !== ZeroAddress || s.payloadChunkHashes[i] !== ZeroHash) {
      throw Error("Unused payload slot must be zero");
    }
  }
  const sourceHash = taggedPolicyViewV2SourceHash(c, p, s, b);
  if (p.expectedSourceHash !== ZeroHash && p.expectedSourceHash !== sourceHash) throw Error("Source hash changed");
  return Object.freeze({ source: s, policyBinding: b, sourceHash, factsVerified: false });
}

/** Full ordered chunk equality, including STOP byte; this does not establish on-chain storage. */
export function validateTaggedPolicyViewV2PayloadCarriers(
  source: TaggedPolicyViewV2Source,
  runtimes: readonly Hex[],
): TaggedPolicyViewV2Payload {
  const s = normalizeTaggedPolicyViewV2Source(source);
  const count = Number((s.payloadBytes + 8191n) / 8192n);
  if (s.payloadBytes === 0n || s.payloadBytes > 40960n || !Array.isArray(runtimes)
    || runtimes.length !== count || Reflect.ownKeys(runtimes).length !== count + 1
    || Array.from({ length: count }, (_, i) => i).some(i => !Object.hasOwn(runtimes, i))) {
    throw Error("Payload carriers bound");
  }
  let raw = "0x";
  for (let i = 0; i < 5; i++) {
    if (i >= count) {
      if (s.payloadPointers[i] !== ZeroAddress || s.payloadChunkHashes[i] !== ZeroHash) throw Error("Unused payload slot");
      continue;
    }
    address(s.payloadPointers[i], true);
    const runtime = bytes(runtimes[i]);
    const size = Math.min(8192, Number(s.payloadBytes) - i * 8192);
    if (runtime.length !== 2 + 2 * (size + 1) || runtime.slice(2, 4) !== "00") throw Error("Invalid STOP carrier");
    const body = `0x${runtime.slice(4)}` as Hex;
    if (keccak256(body) !== s.payloadChunkHashes[i]) throw Error("Payload chunk hash mismatch");
    raw += body.slice(2);
  }
  if (keccak256(raw) !== s.payloadHash) throw Error("Payload hash mismatch");
  return decodeTaggedPolicyViewV2Payload(raw as Hex);
}

export function taggedPolicyViewV2PreparedHash(record: TaggedPolicyViewV2Record): Hex {
  const r = normalizeTaggedPolicyViewV2Record(record);
  return hash(
    ["bytes32", "bytes32", TAGGED_POLICY_VIEW_V2_INPUT_TUPLE, "bytes32", "address", "uint8", "uint256", "uint64"],
    [id("6529STREAM_POLICY_VIEW_PREPARED_STATE_V2"), TAGGED_POLICY_VIEW_V2_PROFILE,
      r.input, r.sourceHash, r.actor, r.authorizationClass, r.grantCollectionId, r.grantRevision],
  );
}

export function taggedPolicyViewV2NextAggregate(
  coordinates: TaggedPolicyViewV2Coordinates,
  previous: TaggedPolicyViewV2Aggregate,
  record: TaggedPolicyViewV2Record,
): TaggedPolicyViewV2Aggregate {
  const c = normalizeTaggedPolicyViewV2Coordinates(coordinates);
  const a = normalizeTaggedPolicyViewV2Aggregate(previous);
  const r = normalizeTaggedPolicyViewV2Record(record);
  if (r.source.renderer.contextVersion !== TAGGED_POLICY_VIEW_V2_CONTEXT) throw Error("Wrong V2 context");
  const revision = uint(a.revision + 1n, 64);
  return Object.freeze({
    revision,
    transitionChain: hash(
      ["bytes32", "bytes32", "uint256", "address", "address", "uint256", "bytes32", "uint64", "bytes32", "bytes32", "bytes32"],
      [id("6529STREAM_POLICY_VIEW_AGGREGATE_V2"), TAGGED_POLICY_VIEW_V2_PROFILE, c.chainId, c.router,
        c.core, r.input.scope.collectionId, a.transitionChain, revision,
        taggedPolicyViewV2ScopeSubject(c, r.input.scope), r.input.expectedPrevious, taggedPolicyViewV2PreparedHash(r)],
    ),
  });
}

export function taggedPolicyViewV2LegacyFamilyState(
  coordinates: TaggedPolicyViewV2Coordinates,
  collectionId: bigint,
  collection: TaggedPolicyViewV2StaticCollection,
): Hex {
  const c = normalizeTaggedPolicyViewV2Coordinates(coordinates);
  return hash(
    ["bytes32", "address", "address", "uint256", TAGGED_POLICY_VIEW_V2_STATIC_COLLECTION_TUPLE],
    [id("6529STREAM_STATIC_METADATA_FAMILY_V1"), c.core, c.router,
      uint(collectionId), normalizeTaggedPolicyViewV2StaticCollection(collection)],
  );
}

export function taggedPolicyViewV2FamilyState(
  coordinates: TaggedPolicyViewV2Coordinates,
  collectionId: bigint,
  legacyFamily: Hex,
  aggregate: TaggedPolicyViewV2Aggregate,
): Hex {
  const c = normalizeTaggedPolicyViewV2Coordinates(coordinates);
  const a = normalizeTaggedPolicyViewV2Aggregate(aggregate);
  const legacy = bytes(legacyFamily, 32);
  const cid = uint(collectionId);
  if (a.revision === 0n) return legacy;
  return hash(
    ["bytes32", "uint256", "address", "address", "uint256", "bytes32", TAGGED_POLICY_VIEW_V2_AGGREGATE_TUPLE],
    [id("6529STREAM_RENDERER_CONFIG_WITH_VIEWS_V1"), c.chainId, c.router, c.core, cid, legacy, a],
  );
}

/** Original op17 terms only. No new signature, nonce, signer or authorization is inferred. */
export function taggedPolicyViewV2ConsentTerms(
  coordinates: TaggedPolicyViewV2Coordinates,
  collectionId: bigint,
  newStateHash: Hex,
): Readonly<{ collectionId: bigint; metadataContract: Address; familyId: Hex; newStateHash: Hex }> {
  const c = normalizeTaggedPolicyViewV2Coordinates(coordinates);
  const cid = uint(collectionId);
  if (cid === 0n) throw Error("Expected collection");
  return Object.freeze({ collectionId: cid, metadataContract: c.router,
    familyId: TAGGED_POLICY_VIEW_V2_FAMILY, newStateHash: nonzero(bytes(newStateHash, 32)) });
}

/** Hashes the complete record with its own recordHash set to zero, for either known profile. */
export function taggedPolicyViewV2RecordHash(
  coordinates: TaggedPolicyViewV2Coordinates,
  record: TaggedPolicyViewV2Record,
  profile: Hex = TAGGED_POLICY_VIEW_V2_PROFILE,
): Hex {
  const c = normalizeTaggedPolicyViewV2Coordinates(coordinates);
  const r = normalizeTaggedPolicyViewV2Record(record);
  const tag = closedProfile(profile);
  const types = ["bytes32", "uint256", "address", "address", TAGGED_POLICY_VIEW_V2_RECORD_TUPLE];
  const values: unknown[] = [id("6529STREAM_VIEW_ADOPTION_RECORD_V1"), c.chainId, c.router, c.core, { ...r, recordHash: ZeroHash }];
  if (tag !== ZeroHash) {
    types.splice(1, 0, "bytes32");
    values[0] = id("6529STREAM_POLICY_VIEW_ADOPTION_RECORD_V2");
    values.splice(1, 0, tag);
  }
  return hash(types, values);
}

/** Authenticates supplied immutable carrier bytes, not their existence at any chain address. */
export function authenticateTaggedPolicyViewV2Record(
  coordinates: TaggedPolicyViewV2Coordinates,
  profile: Hex,
  recordHash: Hex,
  raw: Hex,
  carrier: TaggedPolicyViewV2Carrier,
): Readonly<{ profile: Hex; record: TaggedPolicyViewV2Record; canonical: Hex; factsVerified: false }> {
  const c = normalizeTaggedPolicyViewV2Coordinates(coordinates);
  const tag = normalizeTaggedPolicyViewV2Profile(profile, carrier);
  const key = nonzero(bytes(recordHash, 32));
  const canonical = bytes(raw);
  const saved = normalizeTaggedPolicyViewV2Carrier(carrier);
  const r = decodeTaggedPolicyViewV2Record(canonical);
  if (BigInt((canonical.length - 2) / 2) !== saved.byteSize || keccak256(canonical) !== saved.contentHash
    || r.recordHash !== key || r.revision === 0n || r.source.route.core !== c.core
    || r.source.route.router !== c.router || taggedPolicyViewV2RecordHash(c, r, tag) !== key
    || r.source.renderer.contextVersion !== (tag === ZeroHash ? TAGGED_POLICY_VIEW_V1_CONTEXT : TAGGED_POLICY_VIEW_V2_CONTEXT)) {
    throw Error("Invalid original VIEW record");
  }
  normalizeTaggedPolicyViewV2Input(r.input);
  normalizeTaggedPolicyViewV2Aggregate(r.aggregate);
  return Object.freeze({ profile: tag, record: r, canonical, factsVerified: false });
}

/** Exact frozen source definition bytes. */
export const TAGGED_POLICY_VIEW_V2_PAYLOAD_SCHEMA = "{\"name\":\"STREAM_STATIC_POLICY_VIEW_PAYLOAD_V2\",\"encoding\":\"Solidity abi.encode\",\"canonicalization\":\"RAW_BYTES\",\"type\":\"(bytes32,string,string,string,bytes)\",\"fields\":[\"contextVersion\",\"name\",\"description\",\"imageURI\",\"script\"],\"contextVersion\":\"keccak256(STREAM_ADOPTED_POLICY_VIEW_CONTEXT_V2)\",\"limits\":{\"payloadBytes\":40960,\"nameBytes\":128,\"descriptionBytes\":8192,\"imageURIBytes\":2048,\"scriptBytes\":24576},\"source\":\"Complete UTF8 script with explicit full-policy/terminal/finalized context; no invented finalized seed; no external animation URI or library; safe optional image URI\",\"authority\":\"Document publication is not Artist adoption; original Router op17 and admitted view renderer required\"}";
export const TAGGED_POLICY_VIEW_V2_PAYLOAD_SCHEMA_HASH = keccak256(toUtf8Bytes(TAGGED_POLICY_VIEW_V2_PAYLOAD_SCHEMA)) as Hex;

/** Exact frozen source definition bytes. */
export const TAGGED_POLICY_VIEW_V2_MANIFEST_SCHEMA = "{\"name\":\"STREAM_COLLECTION_VIEW_MANIFEST_ABI_V1\",\"encoding\":\"Solidity abi.encode\",\"canonicalization\":\"RAW_BYTES\",\"types\":[\"uint256\",\"uint64\",\"bytes32\",\"(bytes32,bytes32,string,bytes32,string,bool)\"],\"fields\":[\"collectionId\",\"revision\",\"previousRecordHash\",\"manifest\"],\"manifestFields\":[\"viewId\",\"schemaId\",\"uri\",\"contentHash\",\"mimeType\",\"defaultForView\"],\"contentHash\":\"keccak256 over exact retained referenced-view bytes\",\"authority\":\"DISPLAY class 7 or 8; no Artist consent or renderer adoption\"}";
export const TAGGED_POLICY_VIEW_V2_MANIFEST_SCHEMA_HASH = keccak256(toUtf8Bytes(TAGGED_POLICY_VIEW_V2_MANIFEST_SCHEMA)) as Hex;

/** Exact frozen source definition bytes. */
export const TAGGED_POLICY_VIEW_V2_OUTPUT_SCHEMA = "{\"name\":\"STREAM_ADOPTED_POLICY_VIEW_OUTPUT_V2\",\"encoding\":\"UTF8 JSON\",\"fields\":[\"name\",\"description\",\"image\",\"animation_url\",\"view_id\",\"view_record\",\"adoption_record\",\"artist_attribution\"],\"html\":\"Exact adopted UTF8 script plus STREAM_POLICY_VIEW_CONTEXT_V2 original token identity/serial/seed/tokenData and complete original entropy policy/status and full scope/view/adoption/source commitments\",\"entropy\":\"Original constructor-indexed Coordinator; explicit full H direct STATIC facts; statuses 1/2 retain seed=0 and finalized=false, ASYNC status5 retains actual seed; legacy status5 branch remains explicitly separate\",\"historical\":\"Saved adopted payload and renderer; original live Artist attribution remains live\"}";
export const TAGGED_POLICY_VIEW_V2_OUTPUT_SCHEMA_HASH = keccak256(toUtf8Bytes(TAGGED_POLICY_VIEW_V2_OUTPUT_SCHEMA)) as Hex;

export interface TaggedPolicyViewV2TerminalFacts {
  readonly collectionId: bigint;
  readonly policy: TaggedPolicyViewV2Policy;
  readonly status: bigint;
  readonly seed: Hex;
  readonly requestKey: Hex;
}

export const TAGGED_POLICY_VIEW_V2_TERMINAL_FACTS_TUPLE = `tuple(uint256 collectionId,${TAGGED_POLICY_VIEW_V2_POLICY_TUPLE} policy,uint8 status,bytes32 seed,bytes32 requestKey)`;

export function normalizeTaggedPolicyViewV2TerminalFacts(value: TaggedPolicyViewV2TerminalFacts): TaggedPolicyViewV2TerminalFacts {
  return normalize<TaggedPolicyViewV2TerminalFacts>(TAGGED_POLICY_VIEW_V2_TERMINAL_FACTS_TUPLE, value);
}

export function encodeTaggedPolicyViewV2TerminalFacts(value: TaggedPolicyViewV2TerminalFacts): Hex {
  return encode(TAGGED_POLICY_VIEW_V2_TERMINAL_FACTS_TUPLE, normalizeTaggedPolicyViewV2TerminalFacts(value));
}

export function decodeTaggedPolicyViewV2TerminalFacts(raw: Hex): TaggedPolicyViewV2TerminalFacts {
  return normalizeTaggedPolicyViewV2TerminalFacts(decode(TAGGED_POLICY_VIEW_V2_TERMINAL_FACTS_TUPLE, raw));
}

/** Original retained-rule checks; no provider eligibility or runtime observation is inferred. */
export function validateTaggedPolicyViewV2CoordinatorPolicy(value: TaggedPolicyViewV2CoordinatorPolicy): TaggedPolicyViewV2CoordinatorPolicy {
  const r = normalizeTaggedPolicyViewV2CoordinatorPolicy(value);
  address(r.coordinator, true);
  for (const key of ["indexedCodeHash", "policyHash", "componentDataHash", "moduleVersion", "moduleManifestHash", "moduleSchemaHash", "deploymentManifestHash"] as const) nonzero(r[key]);
  if (!r.frozen) throw Error("Unfrozen retained policy rule");
  const p = r.collectionPolicy;
  if (r.explicitPolicy) {
    if (!p.configured || !p.explicitPolicy || !p.frozen || p.mode > 2n || p.securityClass > 1n
      || p.renderRequirement > 1n || p.revision === 0n || p.policyHash !== r.policyHash
      || p.lastActionId === ZeroHash || p.artistConsentRecord === ZeroHash
      || p.contentStateHash !== hash(["bytes32", "bytes32", "bool"], [id("6529STREAM_ENTROPY_CONFIGURATION_V1"), p.policyHash, p.frozen])
      || r.provider !== ZeroAddress || r.epoch !== 0n || r.salt !== ZeroHash) throw Error("Invalid explicit rule");
  } else if (r.provider === ZeroAddress || r.epoch === 0n || r.salt === ZeroHash
    || encodeTaggedPolicyViewV2Policy(p) !== `0x${"00".repeat(12 * 32)}`) {
    throw Error("Invalid legacy rule");
  }
  return r;
}

export type TaggedPolicyViewV2EntropyFacts = Readonly<
  { kind: "explicit"; facts: TaggedPolicyViewV2TerminalFacts }
  | { kind: "legacy"; status: bigint; seed: Hex; provider: Address }
>;

/** Supplied original facts only. Completed token identity, membership and code pins are separate reads. */
export function taggedPolicyViewV2Entropy(
  rule: TaggedPolicyViewV2CoordinatorPolicy,
  collectionId: bigint,
  input: TaggedPolicyViewV2EntropyFacts,
): TaggedPolicyViewV2Entropy {
  const r = validateTaggedPolicyViewV2CoordinatorPolicy(rule);
  const cid = uint(collectionId);
  if (cid === 0n) throw Error("Expected collection");
  let status: bigint;
  let seed: Hex;
  let terminal = false;
  let finalized = false;
  if (input.kind === "explicit") {
    exact(input, ["kind", "facts"], "Explicit entropy facts");
    const f = normalizeTaggedPolicyViewV2TerminalFacts(input.facts);
    if (!r.explicitPolicy || f.collectionId !== cid || !same(TAGGED_POLICY_VIEW_V2_POLICY_TUPLE, f.policy, r.collectionPolicy)) {
      throw Error("Original terminal policy mismatch");
    }
    status = f.status;
    seed = f.seed;
    if (status === 1n || status === 2n) {
      if (seed !== ZeroHash || f.requestKey !== ZeroHash || f.policy.renderRequirement !== 1n
        || f.policy.mode !== (status === 1n ? 0n : 2n)) throw Error("Invalid terminal entropy");
      terminal = true;
    } else {
      if (status !== 5n || f.policy.mode !== 2n || f.policy.renderRequirement !== 0n) throw Error("Entropy not finalized");
      finalized = true;
    }
  } else if (input.kind === "legacy") {
    exact(input, ["kind", "status", "seed", "provider"], "Legacy entropy facts");
    status = uint(input.status, 8);
    seed = bytes(input.seed, 32);
    address(input.provider);
    if (r.explicitPolicy || status !== 5n) throw Error("Invalid legacy finalized branch");
    finalized = true;
  } else throw Error("Unknown entropy branch");
  return normalizeTaggedPolicyViewV2Entropy({ coordinator: r.coordinator,
    coordinatorCodeHash: r.indexedCodeHash, policyHash: r.policyHash,
    explicitPolicy: r.explicitPolicy, policy: r.collectionPolicy, status, seed, finalized, terminal });
}

export type TaggedPolicyViewV2Request = Readonly<{
  kind: "adoptPolicyView";
  input: TaggedPolicyViewV2Input;
}>;

export interface TaggedPolicyViewV2Call {
  readonly coordinates: TaggedPolicyViewV2Coordinates;
  readonly caller: Address;
  readonly request: TaggedPolicyViewV2Request;
  readonly call: UnsignedCall;
  readonly factsVerified: false;
}

function call(target: Address, abi: Interface, method: string, args: readonly unknown[]): UnsignedCall {
  return Object.freeze({ to: address(target, true), value: 0n, data: abi.encodeFunctionData(method, args) as Hex });
}

export function prepareTaggedPolicyViewV2Call(
  coordinates: TaggedPolicyViewV2Coordinates,
  caller: Address,
  request: TaggedPolicyViewV2Request,
): TaggedPolicyViewV2Call {
  const c = normalizeTaggedPolicyViewV2Coordinates(coordinates);
  const actor = address(caller, true);
  exact(request, ["kind", "input"], "Adoption request");
  if (request.kind !== "adoptPolicyView") throw Error("Unknown V2 mutation");
  const input = normalizeTaggedPolicyViewV2Input(request.input);
  nonzero(input.expectedSourceHash);
  return Object.freeze({ coordinates: c, caller: actor,
    request: Object.freeze({ kind: "adoptPolicyView", input }),
    call: call(c.router, routerInterface, "adoptPolicyView", [input]), factsVerified: false });
}

function verifyCall(actual: UnsignedCall, expected: UnsignedCall): void {
  exact(actual, ["to", "data", "value"], "Unsigned CALL");
  if (address(actual.to) !== expected.to || bytes(actual.data) !== expected.data
    || uint(actual.value) !== expected.value) throw Error("Prepared CALL changed");
}

export function normalizeTaggedPolicyViewV2Call(value: TaggedPolicyViewV2Call): TaggedPolicyViewV2Call {
  exact(value, ["coordinates", "caller", "request", "call", "factsVerified"], "Prepared adoption");
  if (value.factsVerified !== false) throw Error("Supplied facts are not verified");
  const prepared = prepareTaggedPolicyViewV2Call(value.coordinates, value.caller, value.request);
  verifyCall(value.call, prepared.call);
  return prepared;
}

export type TaggedPolicyViewV2ReadRequest = Readonly<
  { kind: "previewPolicyViewAdoption"; input: TaggedPolicyViewV2Input; actor: Address }
  | { kind: "viewAdoptionHead"; scope: TaggedPolicyViewV2Scope }
  | { kind: "viewAdoptionEncoded" | "viewAdoptionCarrier" | "viewAdoptionProfile"; recordHash: Hex }
  | { kind: "viewAdoptionAggregate"; collectionId: bigint }
  | { kind: "tokenJSONForView" | "tokenHTMLForView"; tokenId: bigint; scopeId: Hex }
  | { kind: "historicalTokenJSONForView" | "historicalTokenHTMLForView"; tokenId: bigint; recordHash: Hex }
>;

export interface TaggedPolicyViewV2Read {
  readonly coordinates: TaggedPolicyViewV2Coordinates;
  readonly caller: Address;
  readonly request: TaggedPolicyViewV2ReadRequest;
  readonly call: UnsignedCall;
  readonly factsVerified: false;
}

/** The explicit eth_call caller is independent of preview's actor; zero read caller is allowed. */
export function prepareTaggedPolicyViewV2Read(
  coordinates: TaggedPolicyViewV2Coordinates,
  caller: Address,
  request: TaggedPolicyViewV2ReadRequest,
): TaggedPolicyViewV2Read {
  const c = normalizeTaggedPolicyViewV2Coordinates(coordinates);
  const from = address(caller);
  let r: TaggedPolicyViewV2ReadRequest;
  let args: readonly unknown[];
  switch (request.kind) {
    case "previewPolicyViewAdoption": {
      exact(request, ["kind", "input", "actor"], "Preview request");
      const input = normalizeTaggedPolicyViewV2Input(request.input);
      const actor = address(request.actor, true);
      r = Object.freeze({ kind: request.kind, input, actor });
      args = [input, actor];
      break;
    }
    case "viewAdoptionHead": {
      exact(request, ["kind", "scope"], "Head request");
      const scope = viewScope(request.scope);
      r = Object.freeze({ kind: request.kind, scope });
      args = [scope];
      break;
    }
    case "viewAdoptionEncoded":
    case "viewAdoptionCarrier":
    case "viewAdoptionProfile": {
      exact(request, ["kind", "recordHash"], "History request");
      const recordHash = nonzero(bytes(request.recordHash, 32));
      r = Object.freeze({ kind: request.kind, recordHash });
      args = [recordHash];
      break;
    }
    case "viewAdoptionAggregate": {
      exact(request, ["kind", "collectionId"], "Aggregate request");
      const collectionId = uint(request.collectionId);
      r = Object.freeze({ kind: request.kind, collectionId });
      args = [collectionId];
      break;
    }
    case "tokenJSONForView":
    case "tokenHTMLForView": {
      exact(request, ["kind", "tokenId", "scopeId"], "Current VIEW request");
      const tokenId = uint(request.tokenId);
      if (tokenId === 0n) throw Error("Expected original token");
      const scopeId = nonzero(bytes(request.scopeId, 32));
      r = Object.freeze({ kind: request.kind, tokenId, scopeId });
      args = [tokenId, scopeId];
      break;
    }
    case "historicalTokenJSONForView":
    case "historicalTokenHTMLForView": {
      exact(request, ["kind", "tokenId", "recordHash"], "Historical VIEW request");
      const tokenId = uint(request.tokenId);
      if (tokenId === 0n) throw Error("Expected original token");
      const recordHash = nonzero(bytes(request.recordHash, 32));
      r = Object.freeze({ kind: request.kind, tokenId, recordHash });
      args = [tokenId, recordHash];
      break;
    }
    default: throw Error("Unknown Router VIEW read");
  }
  return Object.freeze({ coordinates: c, caller: from, request: r,
    call: call(c.router, routerInterface, r.kind, args), factsVerified: false });
}

export function normalizeTaggedPolicyViewV2Read(value: TaggedPolicyViewV2Read): TaggedPolicyViewV2Read {
  exact(value, ["coordinates", "caller", "request", "call", "factsVerified"], "Prepared read");
  if (value.factsVerified !== false) throw Error("Supplied facts are not verified");
  const result = prepareTaggedPolicyViewV2Read(value.coordinates, value.caller, value.request);
  verifyCall(value.call, result.call);
  return result;
}

export type TaggedPolicyViewV2RendererReadRequest = Readonly<
  { kind: "sourceBindings" | "encodingBinding" | "policyViewBinding" }
  | { kind: "renderPolicyView"; request: TaggedPolicyViewV2RenderRequest; mode: 0n | 1n | 2n | 3n }
  | { kind: "tokenURI"; request: TaggedPolicyViewV2RenderRequest }
>;

export interface TaggedPolicyViewV2RendererRead {
  readonly renderer: Address;
  readonly caller: Address;
  readonly request: TaggedPolicyViewV2RendererReadRequest;
  readonly call: UnsignedCall;
  readonly factsVerified: false;
}

export function prepareTaggedPolicyViewV2RendererRead(
  renderer: Address,
  caller: Address,
  request: TaggedPolicyViewV2RendererReadRequest,
): TaggedPolicyViewV2RendererRead {
  const target = address(renderer, true);
  const from = address(caller);
  let r: TaggedPolicyViewV2RendererReadRequest;
  let args: readonly unknown[];
  if (request.kind === "renderPolicyView" || request.kind === "tokenURI") {
    exact(request, request.kind === "renderPolicyView" ? ["kind", "request", "mode"] : ["kind", "request"], "Renderer request");
    const input = normalizeTaggedPolicyViewV2RenderRequest(request.request);
    if (input.mode !== 1n) throw Error("Policy VIEW renderer requires ONCHAIN mode");
    if (input.tokenId === 0n && (input.collectionId !== 0n || input.collectionSerial !== 0n
      || input.tokenHash !== ZeroHash || input.viewId !== ZeroHash || input.viewManifestHash !== ZeroHash
      || input.metadataSnapshotHash !== ZeroHash || input.collectionSupplyMode !== 0n
      || input.collectionStatus !== 0n || input.state !== 0n)) throw Error("Invalid empty registration vector");
    if (request.kind === "renderPolicyView") {
      const mode = uint(request.mode, 8);
      if (mode > 3n) throw Error("Unknown render mode");
      r = Object.freeze({ kind: request.kind, request: input, mode: mode as 0n | 1n | 2n | 3n });
      args = [input, mode];
    } else {
      r = Object.freeze({ kind: request.kind, request: input });
      args = [input];
    }
  } else if (request.kind === "sourceBindings" || request.kind === "encodingBinding" || request.kind === "policyViewBinding") {
    exact(request, ["kind"], "Renderer binding request");
    r = Object.freeze({ kind: request.kind });
    args = [];
  } else throw Error("Unknown renderer read");
  return Object.freeze({ renderer: target, caller: from, request: r,
    call: call(target, rendererInterface, r.kind, args), factsVerified: false });
}

export function normalizeTaggedPolicyViewV2RendererRead(value: TaggedPolicyViewV2RendererRead): TaggedPolicyViewV2RendererRead {
  exact(value, ["renderer", "caller", "request", "call", "factsVerified"], "Prepared renderer read");
  if (value.factsVerified !== false) throw Error("Supplied facts are not verified");
  const result = prepareTaggedPolicyViewV2RendererRead(value.renderer, value.caller, value.request);
  verifyCall(value.call, result.call);
  return result;
}

export function decodeTaggedPolicyViewV2Output(raw: Hex): string {
  const canonical = bytes(raw);
  if ((canonical.length - 2) / 2 > TAGGED_POLICY_VIEW_V2_MAX_OUTPUT_BYTES + 64) throw Error("Renderer return byte bound");
  const output = text(coder.decode(["string"], canonical)[0], TAGGED_POLICY_VIEW_V2_MAX_OUTPUT_BYTES);
  if (coder.encode(["string"], [output]) !== canonical) throw Error("Noncanonical renderer output");
  return output;
}
