import { AbiCoder, Interface, ZeroAddress, getAddress, id, isHexString, keccak256 } from "ethers";
import type { Provider } from "ethers";
import type { Address, Hex } from "./generated/contracts.js";
import type { UnsignedCall } from "./client.js";

export interface MintCounterDefinition { readonly scope: bigint; readonly keyMode: bigint; readonly capRoot: Hex; readonly metadataHash: Hex }
export interface MintCounterImportLeaf {
  readonly collectionId: bigint; readonly phaseId: Hex; readonly counterId: Hex; readonly keyMode: bigint;
  readonly subjectBasis: Hex; readonly predecessorSubjectKey: Hex; readonly value: bigint;
}
export interface MintContinuityCoordinates {
  readonly chainId: bigint; readonly successorLedger: Address; readonly predecessorLedger: Address;
  readonly predecessorManager: Address; readonly successorManager: Address; readonly snapshotBlock: bigint;
}
export interface MintImportCommitment extends MintContinuityCoordinates {
  readonly manifestHash: Hex; readonly importRoot: Hex;
}
export interface MintStateImportBatch {
  readonly importRoot: Hex; readonly counters: readonly MintCounterImportLeaf[];
  readonly counterProofs: readonly (readonly Hex[])[]; readonly nullifiers: readonly Hex[];
  readonly nullifierProofs: readonly (readonly Hex[])[];
}
export interface MintContinuityArtifact {
  readonly schemaVersion: 1; readonly profile: "STREAM_CLIENT_MINT_CONTINUITY_MANIFEST_V1";
  readonly coordinates: MintContinuityCoordinates; readonly inventoryCompletenessReviewed: true;
  readonly manifestBytes: Hex; readonly manifestHash: Hex; readonly counterLeaves: readonly MintCounterImportLeaf[];
  readonly counterLeafHashes: readonly Hex[]; readonly counterProofs: readonly (readonly Hex[])[];
  readonly nullifiers: readonly Hex[]; readonly nullifierLeafHashes: readonly Hex[];
  readonly nullifierProofs: readonly (readonly Hex[])[]; readonly descriptorLeaf: Hex;
  readonly descriptorProof: readonly Hex[]; readonly importRoot: Hex;
}
export interface PreparedMintContinuityCall { readonly caller: Address | null; readonly intent: string; readonly call: UnsignedCall }
export interface PreparedGovernedMintCommit { readonly governed: true; readonly actionClass: 1; readonly scope: Hex; readonly oldHash: Hex; readonly newHash: Hex; readonly targetCall: UnsignedCall; readonly executionBoundary: string }
export interface MintContinuityInspection {
  readonly blockTag: number; readonly commitmentMatches: boolean; readonly definitionProgress: { readonly imported: bigint; readonly required: bigint };
  readonly ancestryProgress: { readonly imported: bigint; readonly required: bigint }; readonly exactDescendant: boolean;
  readonly predecessorRetiredAt: bigint; readonly predecessorWriterActive: boolean;
  readonly successorWriterActive: boolean; readonly ready: boolean;
  readonly checked: readonly string[]; readonly limitations: readonly string[];
}
export interface MintSourceInventoryInspection { readonly blockTag: number; readonly counterLeafHashes: readonly Hex[]; readonly nullifierLeafHashes: readonly Hex[]; readonly checked: readonly string[]; readonly completenessProven: false }

const coder = AbiCoder.defaultAbiCoder(), ZERO32 = `0x${"00".repeat(32)}` as Hex;
const definitionTuple = "tuple(uint8 scope,uint8 keyMode,bytes32 capRoot,bytes32 metadataHash)";
const leafTuple = "tuple(uint256 collectionId,bytes32 phaseId,bytes32 counterId,uint8 keyMode,bytes32 subjectBasis,bytes32 predecessorSubjectKey,uint64 value)";
const commitmentTuple = "tuple(address predecessorLedger,address predecessorManager,address successorManager,uint64 snapshotBlock,bytes32 manifestHash,uint64 importedCounters,uint64 importedNullifiers,bool complete)";
const batchTuple = `tuple(bytes32 importRoot,${leafTuple}[] counters,bytes32[][] counterProofs,bytes32[] nullifiers,bytes32[][] nullifierProofs)`;
const ledgerAbi = new Interface([
  `function registerCounterDefinition(${definitionTuple}) returns (bytes32)`,
  `function counterDefinition(bytes32) view returns (bool,${definitionTuple})`,
  `function counterDefinitionForManager(address,bytes32) view returns (bool,${definitionTuple})`,
  "function managerDefinitionCount(address) view returns (uint256)",
  `function managerDefinitionAt(address,uint256) view returns (bytes32,bool,${definitionTuple})`,
  "function ledgerWriter(address) view returns (bool)", "function ledgerWriterRetiredAt(address) view returns (uint64)",
  "function commitCounterImportRoot(address,address,address,uint64,bytes32,bytes32)",
  "function importCounterDefinitions(bytes32,uint256)", "function mintImportDefinitionProgress(bytes32) view returns (uint256,uint256)",
  "function completeCounterImport(bytes32,uint64,uint64,bytes32[])",
  `function mintImportCommitment(bytes32) view returns (${commitmentTuple})`,
  "function isMintSuccessorReady(address,address,address) view returns (bool)", "function owner() view returns (address)",
  "function deriveCounterValueKey(address,uint256,bytes32,bytes32,bytes32) pure returns (bytes32)", "function counterValue(bytes32) view returns (uint64)", "function isManagerNullifierUsed(address,bytes32) view returns (bool)",
]);
const continuityAbi = new Interface([
  "function mintAncestorCount(address) view returns (uint256)", "function mintAncestorAt(address,uint256) view returns (address,address)",
  "function importMintAncestors(bytes32,uint256)", "function mintImportAncestryProgress(bytes32) view returns (uint256,uint256)",
  "function isCompletedMintDescendant(address,address,address) view returns (bool)",
]);
const managerAbi = new Interface([
  "function importMintState(bytes)", "function mintLedger() view returns (address)", "function core() view returns (address)",
  "function governanceAuthority() view returns (address)", "function owner() view returns (address)",
]);
const domains = {
  definition: id("6529STREAM_MINT_COUNTER_DEFINITION_V1"), counter: id("6529STREAM_MINT_COUNTER_IMPORT_LEAF_V1"),
  nullifier: id("6529STREAM_MINT_NULLIFIER_IMPORT_LEAF_V1"), descriptor: id("6529STREAM_MINT_IMPORT_MANIFEST_LEAF_V1"),
  subject: id("6529STREAM_MINT_COUNTER_SUBJECT_V1"), scope: id("6529STREAM_MINT_IMPORT_SCOPE_V1"),
  commitment: id("6529STREAM_MINT_IMPORT_COMMITMENT_V1"), clientManifest: id("6529STREAM_CLIENT_MINT_CONTINUITY_MANIFEST_V1"),
} as const;

function uint(value: bigint, bits: number, name: string): bigint { if (typeof value !== "bigint" || value < 0n || value >= 1n << BigInt(bits)) throw Error(`${name} must fit uint${bits} bigint`); return value; }
function addr(value: Address, name: string): Address { const out = getAddress(value) as Address; if (out === ZeroAddress) throw Error(`${name} must be nonzero`); return out; }
function b32(value: Hex, name: string, allowZero = false): Hex { if (typeof value !== "string" || !isHexString(value, 32) || (!allowZero && value.toLowerCase() === ZERO32)) throw Error(`${name} must be ${allowZero ? "a" : "a nonzero"} bytes32`); return value; }
function exactKeys(value: object, keys: readonly string[], name: string): void { if (Object.keys(value).sort().join(",") !== [...keys].sort().join(",")) throw Error(`${name} contains missing or unknown properties`); }
function frozenCall(to: Address, iface: Interface, method: string, args: readonly unknown[], value = 0n): UnsignedCall { addr(to, "target"); if (value !== 0n) throw Error("Mint continuity calls are nonpayable"); return Object.freeze({ to, data: iface.encodeFunctionData(method, args) as Hex, value }); }
function doubleHash(encoded: Hex): Hex { return keccak256(keccak256(encoded)) as Hex; }
function concreteBlock(value: number): number { if (!Number.isSafeInteger(value) || value < 0) throw Error("A concrete nonnegative block number is required"); return value; }

function validateDefinition(d: MintCounterDefinition): void {
  exactKeys(d, ["scope", "keyMode", "capRoot", "metadataHash"], "counter definition"); uint(d.scope, 8, "scope"); uint(d.keyMode, 8, "keyMode"); b32(d.capRoot, "capRoot", true); b32(d.metadataHash, "metadataHash", true);
  if (d.scope > 2n || d.keyMode === 0n || d.keyMode > 6n || d.keyMode === 5n || (d.keyMode === 6n && d.scope === 0n) || (d.capRoot !== ZERO32 && (d.scope === 0n || (d.keyMode !== 2n && d.keyMode !== 3n)))) throw Error("Unsupported counter definition");
}
function validateCoordinates(c: MintContinuityCoordinates): void {
  exactKeys(c, ["chainId", "successorLedger", "predecessorLedger", "predecessorManager", "successorManager", "snapshotBlock"], "continuity coordinates");
  uint(c.chainId, 256, "chainId"); if (c.chainId === 0n) throw Error("chainId must be positive"); uint(c.snapshotBlock, 64, "snapshotBlock");
  for (const n of ["successorLedger", "predecessorLedger", "predecessorManager", "successorManager"] as const) addr(c[n], n);
  if (c.predecessorManager.toLowerCase() === c.successorManager.toLowerCase()) throw Error("Predecessor and successor Managers must differ");
}
function validateLeaf(leaf: MintCounterImportLeaf): void {
  exactKeys(leaf, ["collectionId", "phaseId", "counterId", "keyMode", "subjectBasis", "predecessorSubjectKey", "value"], "counter import leaf");
  uint(leaf.collectionId, 256, "collectionId"); b32(leaf.phaseId, "phaseId", true); b32(leaf.counterId, "counterId"); uint(leaf.keyMode, 8, "keyMode"); b32(leaf.subjectBasis, "subjectBasis", true); b32(leaf.predecessorSubjectKey, "predecessorSubjectKey"); uint(leaf.value, 64, "value");
  if (leaf.keyMode === 0n || leaf.keyMode > 6n || (leaf.collectionId === 0n && leaf.phaseId !== ZERO32)) throw Error("Invalid normalized counter namespace or key mode");
  const basis = BigInt(leaf.subjectBasis);
  if (leaf.keyMode === 1n ? basis !== 0n : leaf.keyMode === 6n ? basis === 0n : basis === 0n || basis >= 1n << 160n) throw Error("subjectBasis is not canonical for its key mode");
}

export function mintCounterDefinitionHash(definition: MintCounterDefinition): Hex { validateDefinition(definition); return keccak256(coder.encode(["bytes32", definitionTuple], [domains.definition, definition])) as Hex; }
export function mintCounterSubjectBasis(account: Address): Hex { const value = addr(account, "subject account").slice(2).toLowerCase(); return `0x${"0".repeat(24)}${value}` as Hex; }
export function mintCounterSubjectKey(chainId: bigint, ledger: Address, leaf: MintCounterImportLeaf): Hex {
  uint(chainId, 256, "chainId"); addr(ledger, "ledger"); validateLeaf(leaf);
  if (leaf.keyMode === 1n) return keccak256(coder.encode(["bytes32", "uint256", "address", "uint8", "uint256", "bytes32", "bytes32"], [domains.subject, chainId, ledger, leaf.keyMode, leaf.collectionId, leaf.phaseId, leaf.counterId])) as Hex;
  if (leaf.keyMode === 6n) return keccak256(coder.encode(["bytes32", "uint256", "address", "uint8", "bytes32"], [domains.subject, chainId, ledger, leaf.keyMode, leaf.subjectBasis])) as Hex;
  return keccak256(coder.encode(["bytes32", "uint256", "address", "uint8", "address"], [domains.subject, chainId, ledger, leaf.keyMode, getAddress(`0x${leaf.subjectBasis.slice(26)}`)])) as Hex;
}
export function mintCounterImportLeafHash(coordinates: MintContinuityCoordinates, leaf: MintCounterImportLeaf): Hex { validateCoordinates(coordinates); validateLeaf(leaf); const expected = mintCounterSubjectKey(coordinates.chainId, coordinates.predecessorLedger, leaf); if (expected.toLowerCase() !== leaf.predecessorSubjectKey.toLowerCase()) throw Error("predecessorSubjectKey differs from canonical predecessor Ledger subject"); return doubleHash(coder.encode(["bytes32", "uint256", "address", "address", leafTuple], [domains.counter, coordinates.chainId, coordinates.predecessorLedger, coordinates.predecessorManager, leaf]) as Hex); }
export function mintNullifierImportLeafHash(coordinates: MintContinuityCoordinates, nullifier: Hex): Hex { validateCoordinates(coordinates); b32(nullifier, "nullifier"); return doubleHash(coder.encode(["bytes32", "uint256", "address", "address", "bytes32"], [domains.nullifier, coordinates.chainId, coordinates.predecessorLedger, coordinates.predecessorManager, nullifier]) as Hex); }
export function mintImportDescriptorLeaf(coordinates: MintContinuityCoordinates, manifestHash: Hex, counterCount: bigint, nullifierCount: bigint): Hex { validateCoordinates(coordinates); b32(manifestHash, "manifestHash"); uint(counterCount, 64, "counterCount"); uint(nullifierCount, 64, "nullifierCount"); return doubleHash(coder.encode(["bytes32", "uint256", "address", "address", "address", "address", "uint64", "bytes32", "uint64", "uint64"], [domains.descriptor, coordinates.chainId, coordinates.successorLedger, coordinates.predecessorLedger, coordinates.predecessorManager, coordinates.successorManager, coordinates.snapshotBlock, manifestHash, counterCount, nullifierCount]) as Hex); }
export function mintImportGovernanceTransition(commitment: MintImportCommitment): { readonly scope: Hex; readonly oldHash: Hex; readonly newHash: Hex } { validateCoordinates({ chainId: commitment.chainId, successorLedger: commitment.successorLedger, predecessorLedger: commitment.predecessorLedger, predecessorManager: commitment.predecessorManager, successorManager: commitment.successorManager, snapshotBlock: commitment.snapshotBlock }); b32(commitment.manifestHash, "manifestHash"); b32(commitment.importRoot, "importRoot"); const scope = keccak256(coder.encode(["bytes32", "uint256", "address", "address"], [domains.scope, commitment.chainId, commitment.successorLedger, commitment.successorManager])) as Hex; const newHash = keccak256(coder.encode(["bytes32", "bytes32", "address", "address", "address", "uint64", "bytes32", "bytes32"], [domains.commitment, scope, commitment.predecessorLedger, commitment.predecessorManager, commitment.successorManager, commitment.snapshotBlock, commitment.importRoot, commitment.manifestHash])) as Hex; return Object.freeze({ scope, oldHash: ZERO32, newHash }); }

function pair(a: Hex, b: Hex): Hex { return keccak256(coder.encode(["bytes32", "bytes32"], BigInt(a) < BigInt(b) ? [a, b] : [b, a])) as Hex; }
function tree(items: readonly Hex[]): { root: Hex; proofs: Hex[][] } {
  if (!items.length) throw Error("Merkle tree requires leaves"); const layers: Hex[][] = [Array.from(items)];
  while (layers.at(-1)!.length > 1) { const prior = layers.at(-1)!, next: Hex[] = []; for (let i = 0; i < prior.length; i += 2) next.push(i + 1 < prior.length ? pair(prior[i]!, prior[i + 1]!) : prior[i]!); layers.push(next); }
  const proofs = items.map((_, original) => { let index = original; const proof: Hex[] = []; for (let level = 0; level < layers.length - 1; level++) { const layer = layers[level]!, sibling = index ^ 1; if (sibling < layer.length) proof.push(layer[sibling]!); index = Math.floor(index / 2); } return proof; });
  return { root: layers.at(-1)![0]!, proofs };
}
function inventoryKey(leaf: MintCounterImportLeaf): string { return coder.encode(["uint256", "bytes32", "bytes32", "uint8", "bytes32"], [leaf.collectionId, leaf.phaseId, leaf.counterId, leaf.keyMode, leaf.subjectBasis]).toLowerCase(); }

export function buildMintContinuityArtifact(input: { readonly coordinates: MintContinuityCoordinates; readonly counterLeaves: readonly MintCounterImportLeaf[]; readonly nullifiers: readonly Hex[]; readonly inventoryCompletenessReviewed: boolean }): MintContinuityArtifact {
  if (input.inventoryCompletenessReviewed !== true) throw Error("Caller must explicitly attest that the offchain inventory was reviewed for completeness"); validateCoordinates(input.coordinates);
  if (!Array.isArray(input.counterLeaves) || !Array.isArray(input.nullifiers) || input.counterLeaves.length + input.nullifiers.length > 4096) throw Error("Expected counter and nullifier inventory arrays bounded to 4096 combined entries");
  const counters = input.counterLeaves.map(x => Object.freeze({ ...x })); counters.forEach(validateLeaf); const nullifiers = input.nullifiers.map(x => b32(x, "nullifier"));
  if (new Set(counters.map(inventoryKey)).size !== counters.length) throw Error("Duplicate counter inventory identity"); if (new Set(nullifiers.map(x => x.toLowerCase())).size !== nullifiers.length) throw Error("Duplicate raw nullifier");
  const counterPairs = counters.map((leaf, original) => ({ leaf, hash: mintCounterImportLeafHash(input.coordinates, leaf), original })).sort((a, b) => a.hash.localeCompare(b.hash));
  const nullifierPairs = nullifiers.map((nullifier, original) => ({ nullifier, hash: mintNullifierImportLeafHash(input.coordinates, nullifier), original })).sort((a, b) => a.hash.localeCompare(b.hash));
  const sortedCounters = counterPairs.map(x => x.leaf), sortedNullifiers = nullifierPairs.map(x => x.nullifier), counterHashes = counterPairs.map(x => x.hash), nullifierHashes = nullifierPairs.map(x => x.hash);
  const manifestBytes = coder.encode(["bytes32", "uint256", "address", "address", "address", "address", "uint64", `${leafTuple}[]`, "bytes32[]"], [domains.clientManifest, input.coordinates.chainId, input.coordinates.successorLedger, input.coordinates.predecessorLedger, input.coordinates.predecessorManager, input.coordinates.successorManager, input.coordinates.snapshotBlock, sortedCounters, sortedNullifiers]) as Hex;
  const manifestHash = keccak256(manifestBytes) as Hex, descriptorLeaf = mintImportDescriptorLeaf(input.coordinates, manifestHash, BigInt(sortedCounters.length), BigInt(sortedNullifiers.length));
  const all = [...counterHashes, ...nullifierHashes, descriptorLeaf]; if (new Set(all.map(x => x.toLowerCase())).size !== all.length) throw Error("Duplicate committed Merkle leaf"); const built = tree(all), offset = counterHashes.length;
  return Object.freeze({ schemaVersion: 1, profile: "STREAM_CLIENT_MINT_CONTINUITY_MANIFEST_V1", coordinates: Object.freeze({ ...input.coordinates }), inventoryCompletenessReviewed: true, manifestBytes, manifestHash,
    counterLeaves: Object.freeze(sortedCounters), counterLeafHashes: Object.freeze(counterHashes), counterProofs: Object.freeze(built.proofs.slice(0, offset).map(p => Object.freeze(p))), nullifiers: Object.freeze(sortedNullifiers), nullifierLeafHashes: Object.freeze(nullifierHashes), nullifierProofs: Object.freeze(built.proofs.slice(offset, offset + nullifierHashes.length).map(p => Object.freeze(p))), descriptorLeaf, descriptorProof: Object.freeze(built.proofs.at(-1)!), importRoot: built.root });
}

export function mintContinuityArtifactToJSON(artifact: MintContinuityArtifact): string { verifyMintContinuityArtifact(artifact); const rendered = JSON.stringify(artifact, (_, value) => typeof value === "bigint" ? value.toString() : value, 2); if (rendered.length > 16_777_216) throw Error("Canonical mint continuity artifact JSON exceeds 16 MiB"); return rendered; }
export function mintContinuityArtifactFromJSON(value: string | unknown): MintContinuityArtifact {
  if (typeof value === "string" && value.length > 16_777_216) throw Error("Mint continuity artifact JSON exceeds 16 MiB");
  const raw: unknown = typeof value === "string" ? JSON.parse(value) : value; if (!raw || typeof raw !== "object" || Array.isArray(raw)) throw Error("Expected mint continuity artifact object");
  const a = raw as Record<string, unknown>, c = a.coordinates as Record<string, unknown>; if (!c || typeof c !== "object") throw Error("Missing continuity coordinates");
  if (!Array.isArray(a.counterLeaves) || !Array.isArray(a.nullifiers) || a.counterLeaves.length + a.nullifiers.length > 4096) throw Error("Mint continuity artifact inventory arrays are missing or exceed 4096 combined entries");
  for (const [name, expected] of [["counterLeafHashes", a.counterLeaves.length], ["counterProofs", a.counterLeaves.length], ["nullifierLeafHashes", a.nullifiers.length], ["nullifierProofs", a.nullifiers.length]] as const) { const list = a[name]; if (!Array.isArray(list) || list.length !== expected) throw Error(`${name} length differs from inventory`); if (name.endsWith("Proofs") && list.some(x => !Array.isArray(x) || x.length > 256)) throw Error(`${name} contains an invalid or oversized proof`); }
  if (!Array.isArray(a.descriptorProof) || a.descriptorProof.length > 256) throw Error("descriptorProof is invalid or oversized");
  const bigint = (x: unknown, name: string) => { if (typeof x !== "string" || x.length > 78 || !/^(0|[1-9][0-9]*)$/.test(x)) throw Error(`${name} must be a bounded decimal string`); return BigInt(x); };
  return verifyMintContinuityArtifact({ ...a, coordinates: { ...c, chainId: bigint(c.chainId, "chainId"), snapshotBlock: bigint(c.snapshotBlock, "snapshotBlock") }, counterLeaves: (a.counterLeaves as Record<string, unknown>[]).map(x => { if (!x || typeof x !== "object" || Array.isArray(x)) throw Error("Invalid counter leaf JSON"); return { ...x, collectionId: bigint(x.collectionId, "collectionId"), keyMode: bigint(x.keyMode, "keyMode"), value: bigint(x.value, "value") }; }) } as unknown as MintContinuityArtifact);
}
export function verifyMintContinuityArtifact(artifact: MintContinuityArtifact): MintContinuityArtifact {
  if (artifact.schemaVersion !== 1 || artifact.profile !== "STREAM_CLIENT_MINT_CONTINUITY_MANIFEST_V1" || artifact.inventoryCompletenessReviewed !== true) throw Error("Unsupported or unreviewed continuity artifact");
  const rebuilt = buildMintContinuityArtifact({ coordinates: artifact.coordinates, counterLeaves: artifact.counterLeaves, nullifiers: artifact.nullifiers, inventoryCompletenessReviewed: artifact.inventoryCompletenessReviewed });
  const stringify = (x: unknown) => JSON.stringify(x, (_, v) => typeof v === "bigint" ? v.toString() : v); if (stringify(rebuilt) !== stringify(artifact)) throw Error("Mint continuity artifact differs from canonical reconstruction"); return rebuilt;
}

export function prepareCounterDefinitionRegistration(ledger: Address, definition: MintCounterDefinition): PreparedMintContinuityCall { const hash = mintCounterDefinitionHash(definition); return Object.freeze({ caller: null, intent: `Register immutable counter definition ${hash}`, call: frozenCall(ledger, ledgerAbi, "registerCounterDefinition", [definition]) }); }
export function prepareMintImportCommit(artifact: MintContinuityArtifact): PreparedGovernedMintCommit { const a = verifyMintContinuityArtifact(artifact), c = a.coordinates, transition = mintImportGovernanceTransition({ ...c, importRoot: a.importRoot, manifestHash: a.manifestHash }); return Object.freeze({ governed: true, actionClass: 1, ...transition, targetCall: frozenCall(c.successorLedger, ledgerAbi, "commitCounterImportRoot", [c.predecessorLedger, c.predecessorManager, c.successorManager, c.snapshotBlock, a.importRoot, a.manifestHash]), executionBoundary: "The target call succeeds only inside the Ledger owner's authenticated executing currentAction; this is not an ordinary owner/Safe CALL." }); }
export function prepareCounterDefinitionImport(artifact: MintContinuityArtifact, maxCount: bigint): PreparedMintContinuityCall { const a = verifyMintContinuityArtifact(artifact); uint(maxCount, 256, "maxCount"); if (maxCount < 1n || maxCount > 32n) throw Error("maxCount must be 1 through 32"); return Object.freeze({ caller: null, intent: `Copy at most ${maxCount} frozen predecessor counter definitions`, call: frozenCall(a.coordinates.successorLedger, ledgerAbi, "importCounterDefinitions", [a.importRoot, maxCount]) }); }
export function prepareMintAncestryImport(artifact: MintContinuityArtifact, maxCount: bigint): PreparedMintContinuityCall { const a = verifyMintContinuityArtifact(artifact); uint(maxCount, 256, "maxCount"); if (maxCount < 1n || maxCount > 32n) throw Error("maxCount must be 1 through 32"); return Object.freeze({ caller: null, intent: `Copy at most ${maxCount} frozen older Manager ancestry pairs`, call: frozenCall(a.coordinates.successorLedger, continuityAbi, "importMintAncestors", [a.importRoot, maxCount]) }); }
export function prepareMintStateImport(artifact: MintContinuityArtifact, managerOwner: Address, counterIndexes: readonly number[], nullifierIndexes: readonly number[]): PreparedMintContinuityCall {
  const a = verifyMintContinuityArtifact(artifact); if (!Array.isArray(counterIndexes) || !Array.isArray(nullifierIndexes) || counterIndexes.length + nullifierIndexes.length < 1 || counterIndexes.length + nullifierIndexes.length > 32) throw Error("Mint state batch must contain 1 through 32 leaves");
  const unique = (values: readonly number[], length: number, name: string) => { if (new Set(values).size !== values.length || values.some(x => !Number.isSafeInteger(x) || x < 0 || x >= length)) throw Error(`Invalid or duplicate ${name} index`); };
  unique(counterIndexes, a.counterLeaves.length, "counter"); unique(nullifierIndexes, a.nullifiers.length, "nullifier");
  const batch: MintStateImportBatch = { importRoot: a.importRoot, counters: counterIndexes.map(i => a.counterLeaves[i]!), counterProofs: counterIndexes.map(i => a.counterProofs[i]!), nullifiers: nullifierIndexes.map(i => a.nullifiers[i]!), nullifierProofs: nullifierIndexes.map(i => a.nullifierProofs[i]!) };
  const encoded = coder.encode([batchTuple], [batch]); return Object.freeze({ caller: addr(managerOwner, "Manager owner"), intent: `Import ${counterIndexes.length} counter and ${nullifierIndexes.length} raw-nullifier leaves`, call: frozenCall(a.coordinates.successorManager, managerAbi, "importMintState", [encoded]) });
}
export function prepareMintImportCompletion(artifact: MintContinuityArtifact): PreparedMintContinuityCall { const a = verifyMintContinuityArtifact(artifact); return Object.freeze({ caller: null, intent: "Complete the exact reviewed mint continuity leaf counts after all imports", call: frozenCall(a.coordinates.successorLedger, ledgerAbi, "completeCounterImport", [a.importRoot, BigInt(a.counterLeaves.length), BigInt(a.nullifiers.length), a.descriptorProof]) }); }

async function read(provider: Pick<Provider, "call">, target: Address, iface: Interface, method: string, args: readonly unknown[], blockTag: number): Promise<readonly unknown[]> { const raw = await provider.call({ to: target, data: iface.encodeFunctionData(method, args), blockTag }); if (!isHexString(raw, true)) throw Error(`Malformed ${method} return`); const decoded = iface.decodeFunctionResult(method, raw); if (iface.encodeFunctionResult(method, decoded).toLowerCase() !== raw.toLowerCase()) throw Error(`Noncanonical ${method} return`); return Array.from(decoded); }
export async function inspectMintContinuitySourceInventory(provider: Pick<Provider, "getNetwork" | "call">, artifact: MintContinuityArtifact, counterIndexes: readonly number[], nullifierIndexes: readonly number[], options: { readonly blockTag: number }): Promise<MintSourceInventoryInspection> {
  const a = verifyMintContinuityArtifact(artifact), blockTag = concreteBlock(options.blockTag), c = a.coordinates;
  if (!Array.isArray(counterIndexes) || !Array.isArray(nullifierIndexes) || counterIndexes.length + nullifierIndexes.length < 1 || counterIndexes.length + nullifierIndexes.length > 32 || new Set(counterIndexes).size !== counterIndexes.length || new Set(nullifierIndexes).size !== nullifierIndexes.length || counterIndexes.some(x => !Number.isSafeInteger(x) || x < 0 || x >= a.counterLeaves.length) || nullifierIndexes.some(x => !Number.isSafeInteger(x) || x < 0 || x >= a.nullifiers.length)) throw Error("Source inventory selection must contain 1 through 32 unique valid indexes");
  const selectedCounters = Object.freeze(Array.from(counterIndexes)), selectedNullifiers = Object.freeze(Array.from(nullifierIndexes));
  if ((await provider.getNetwork()).chainId !== c.chainId) throw Error("RPC chain differs from continuity artifact"); if (BigInt(blockTag) !== c.snapshotBlock) throw Error("Source inventory reads must use the exact reviewed snapshot block");
  for (const index of selectedCounters) { const leaf = a.counterLeaves[index]!, [valueKey] = await read(provider, c.predecessorLedger, ledgerAbi, "deriveCounterValueKey", [c.predecessorManager, leaf.collectionId, leaf.phaseId, leaf.counterId, leaf.predecessorSubjectKey], blockTag), [value] = await read(provider, c.predecessorLedger, ledgerAbi, "counterValue", [valueKey], blockTag); if (BigInt(String(value)) !== leaf.value) throw Error("Predecessor counter value differs from reviewed leaf"); }
  for (const index of selectedNullifiers) { const [used] = await read(provider, c.predecessorLedger, ledgerAbi, "isManagerNullifierUsed", [c.predecessorManager, a.nullifiers[index]!], blockTag); if (!used) throw Error("Reviewed raw nullifier is not consumed by predecessor Manager"); }
  return Object.freeze({ blockTag, counterLeafHashes: Object.freeze(selectedCounters.map(i => a.counterLeafHashes[i]!)), nullifierLeafHashes: Object.freeze(selectedNullifiers.map(i => a.nullifierLeafHashes[i]!)), checked: Object.freeze(["canonical predecessor subject keys", "exact predecessor value-key values", "raw predecessor Manager nullifier use"]), completenessProven: false });
}
export async function inspectCounterDefinitionSelection(provider: Pick<Provider, "call">, ledger: Address, manager: Address, definition: MintCounterDefinition, options: { readonly blockTag: number; readonly expectedInterpretation: "defined" | "legacy" }): Promise<{ readonly definitionHash: Hex; readonly globalExists: boolean; readonly managerExists: boolean }> {
  const blockTag = concreteBlock(options.blockTag);
  const expectedInterpretation = options.expectedInterpretation;
  if (expectedInterpretation !== "defined" && expectedInterpretation !== "legacy") {
    throw Error("Expected counter interpretation must be defined or legacy");
  }
  const reviewedDefinition = Object.freeze({ ...definition });
  const definitionHash = mintCounterDefinitionHash(reviewedDefinition);
  const reviewedEncoding = coder.encode([definitionTuple], [reviewedDefinition]).toLowerCase();
  const targetLedger = addr(ledger, "ledger");
  const targetManager = addr(manager, "manager");
  const [globalExists, global] = await read(
    provider, targetLedger, ledgerAbi, "counterDefinition", [definitionHash], blockTag,
  );
  const [managerExists, selected] = await read(
    provider, targetLedger, ledgerAbi, "counterDefinitionForManager", [targetManager, definitionHash], blockTag,
  );
  if (!globalExists || coder.encode([definitionTuple], [global]).toLowerCase() !== reviewedEncoding) {
    throw Error("Global counter definition differs from reviewed preimage");
  }
  const selectionMatches = expectedInterpretation === "defined"
    ? managerExists && coder.encode([definitionTuple], [selected]).toLowerCase() === reviewedEncoding
    : !managerExists && BigInt((selected as { scope: bigint }).scope) === 2n;
  if (!selectionMatches) throw Error("Manager effective definition interpretation differs");
  return Object.freeze({ definitionHash, globalExists: Boolean(globalExists), managerExists: Boolean(managerExists) });
}
export async function inspectMintContinuityReadiness(provider: Pick<Provider, "getNetwork" | "call">, artifact: MintContinuityArtifact, expected: { readonly successorLedgerOwner: Address; readonly successorManagerOwner: Address }, options: { readonly blockTag: number }): Promise<MintContinuityInspection> {
  const a = verifyMintContinuityArtifact(artifact), c = a.coordinates, blockTag = concreteBlock(options.blockTag), expectedLedgerOwner = addr(expected.successorLedgerOwner, "successor Ledger owner"), expectedManagerOwner = addr(expected.successorManagerOwner, "successor Manager owner"); if ((await provider.getNetwork()).chainId !== c.chainId) throw Error("RPC chain differs from continuity artifact");
  const [commitment] = await read(provider, c.successorLedger, ledgerAbi, "mintImportCommitment", [a.importRoot], blockTag) as readonly [Record<string, unknown>];
  const [imported, required] = await read(provider, c.successorLedger, ledgerAbi, "mintImportDefinitionProgress", [a.importRoot], blockTag), [ancestryImported, ancestryRequired] = await read(provider, c.successorLedger, continuityAbi, "mintImportAncestryProgress", [a.importRoot], blockTag), [retired] = await read(provider, c.predecessorLedger, ledgerAbi, "ledgerWriterRetiredAt", [c.predecessorManager], blockTag), [preWriter] = await read(provider, c.predecessorLedger, ledgerAbi, "ledgerWriter", [c.predecessorManager], blockTag), [nextWriter] = await read(provider, c.successorLedger, ledgerAbi, "ledgerWriter", [c.successorManager], blockTag), [ready] = await read(provider, c.successorLedger, ledgerAbi, "isMintSuccessorReady", [c.predecessorLedger, c.predecessorManager, c.successorManager], blockTag), [exactDescendant] = await read(provider, c.successorLedger, continuityAbi, "isCompletedMintDescendant", [c.predecessorLedger, c.predecessorManager, c.successorManager], blockTag);
  const [ledgerOwner] = await read(provider, c.successorLedger, ledgerAbi, "owner", [], blockTag), [managerOwner] = await read(provider, c.successorManager, managerAbi, "owner", [], blockTag), [authority] = await read(provider, c.successorManager, managerAbi, "governanceAuthority", [], blockTag), [predLedger] = await read(provider, c.predecessorManager, managerAbi, "mintLedger", [], blockTag), [nextLedger] = await read(provider, c.successorManager, managerAbi, "mintLedger", [], blockTag), [predCore] = await read(provider, c.predecessorManager, managerAbi, "core", [], blockTag), [nextCore] = await read(provider, c.successorManager, managerAbi, "core", [], blockTag);
  const match = String(commitment.predecessorLedger).toLowerCase() === c.predecessorLedger.toLowerCase() && String(commitment.predecessorManager).toLowerCase() === c.predecessorManager.toLowerCase() && String(commitment.successorManager).toLowerCase() === c.successorManager.toLowerCase() && BigInt(String(commitment.snapshotBlock)) === c.snapshotBlock && String(commitment.manifestHash).toLowerCase() === a.manifestHash.toLowerCase();
  if (!match || String(predLedger).toLowerCase() !== c.predecessorLedger.toLowerCase() || String(nextLedger).toLowerCase() !== c.successorLedger.toLowerCase() || String(predCore).toLowerCase() !== String(nextCore).toLowerCase() || String(ledgerOwner).toLowerCase() !== expectedLedgerOwner.toLowerCase() || String(managerOwner).toLowerCase() !== expectedManagerOwner.toLowerCase() || String(authority).toLowerCase() !== String(ledgerOwner).toLowerCase()) throw Error("Live commitment, Manager/Ledger/Core or owner/authority pair differs from reviewed continuity coordinates");
  const retiredAt = BigInt(String(retired)), importedDefinitions = BigInt(String(imported)), requiredDefinitions = BigInt(String(required)), importedAncestry = BigInt(String(ancestryImported)), requiredAncestry = BigInt(String(ancestryRequired)), importedCounters = BigInt(String(commitment.importedCounters)), importedNullifiers = BigInt(String(commitment.importedNullifiers)), complete = Boolean(commitment.complete);
  if (retiredAt === 0n || retiredAt > c.snapshotBlock || c.snapshotBlock > BigInt(blockTag) || preWriter || importedDefinitions > requiredDefinitions || importedAncestry > requiredAncestry || importedCounters > BigInt(a.counterLeaves.length) || importedNullifiers > BigInt(a.nullifiers.length) || (complete && (importedCounters !== BigInt(a.counterLeaves.length) || importedNullifiers !== BigInt(a.nullifiers.length) || importedDefinitions !== requiredDefinitions || importedAncestry !== requiredAncestry)) || Boolean(exactDescendant) !== Boolean(ready) || (Boolean(ready) && (!complete || !nextWriter || importedDefinitions !== requiredDefinitions || importedAncestry !== requiredAncestry))) throw Error("Retirement, snapshot, import counts, profile/ancestry progress or ready/descendant state is inconsistent");
  return Object.freeze({ blockTag, commitmentMatches: true, definitionProgress: Object.freeze({ imported: importedDefinitions, required: requiredDefinitions }), ancestryProgress: Object.freeze({ imported: importedAncestry, required: requiredAncestry }), exactDescendant: Boolean(exactDescendant), predecessorRetiredAt: retiredAt, predecessorWriterActive: Boolean(preWriter), successorWriterActive: Boolean(nextWriter), ready: Boolean(ready), checked: Object.freeze(["exact commitment coordinates and imported leaf counts", "Manager Ledger/Core pair", "owner and governance authority", "permanent predecessor retirement before snapshot", "definition-copy progress", "older ancestry-copy progress", "exact-pair successor readiness and descendant consistency"]), limitations: Object.freeze(["offchain inventory completeness is a caller-reviewed assertion", "used leaf identities require receipt/event reconciliation; aggregate counts are insufficient", "numeric block pin has no reorg hash check", "readiness does not execute Core activation, record fresh successor policy consent, or prove a Safe threshold"] ) });
}
