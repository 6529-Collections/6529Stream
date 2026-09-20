import type { Address, Hex } from "../src/generated/contracts.js";
import type { UnsignedCall } from "../src/binding.js";
import * as graph from "../src/current-scoped-policy-graph-v2.js";

declare const coordinates: graph.ScopedPolicyGraphV2Coordinates;
declare const caller: Address;
declare const scope: graph.ScopedPolicyGraphV2Scope;
declare const recipe: graph.ScopedPolicyGraphV2Recipe;
declare const dependencies: graph.ScopedPolicyGraphV2SourceDependencies;
declare const saved: graph.ScopedPolicyGraphV2Graph;
declare const membership: graph.ScopedPolicyGraphV2Membership;
declare const progress: graph.ScopedPolicyGraphV2InventoryProgress;
declare const rows: readonly graph.ScopedPolicyGraphV2CoordinatorPolicy[];
declare const binding: graph.ScopedPolicyGraphV2FactoryBinding;
declare const original: graph.ScopedPolicyGraphV2NativeConfiguration;
declare const provider: Address;
declare const hash: Hex;

const prepared = graph.prepareScopedPolicyGraphV2Call(coordinates, caller, {
  kind: "prepareGraph", scope, maximumChildren: 7n,
});
const action: graph.ScopedPolicyGraphV2Call = graph.normalizeScopedPolicyGraphV2Call(prepared);
const call: UnsignedCall = action.call;
const unverified: false = action.factsVerified;
graph.prepareScopedPolicyGraphV2Call(coordinates, caller, { kind: "prepareSourceSet", scope });
const stored = graph.validateScopedPolicyGraphV2Graph(coordinates, recipe, dependencies, saved, {
  expectedPlan: hash, expectedScope: scope,
});
const status: "missing" | "partial" | "complete" = stored.status;
const childCount: bigint = stored.graph.preparedChildren;
const targets: readonly [Address, Address, Address, Address, Address, Address, Address] = stored.graph.children;
const constructor = graph.scopedPolicyGraphV2ChildConstructor(recipe, saved, 3n);
if (constructor.kind === "snapshot") {
  const snapshot: graph.ScopedPolicyGraphV2SnapshotDependencies = constructor.dependencies;
  graph.validateScopedPolicyGraphV2SnapshotDependencies(recipe, saved, snapshot);
}
const reference = graph.scopedPolicyGraphV2ReferenceDependencies(recipe, saved);
graph.validateScopedPolicyGraphV2ReferenceDependencies(recipe, saved, reference);
graph.scopedPolicyGraphV2InventoryDependencies(recipe, saved);
graph.scopedPolicyGraphV2BundleDependencies(recipe, saved);
const plan: Hex = graph.scopedPolicyGraphV2InventoryPlan(dependencies, scope, membership);
const evidence = graph.validateScopedPolicyGraphV2PolicyEvidence(dependencies, scope, membership, progress, rows);
const sourceHash: Hex = graph.scopedPolicyGraphV2SourceSetDataHash(scope, plan, evidence.inventoryHash,
  evidence.policyChainHash, membership, caller, hash);
const frozen: boolean = evidence.allFrozen;
graph.scopedPolicyGraphV2SourceSetManifestHash(dependencies, caller, hash);
graph.scopedPolicyGraphV2ProviderConfigurationHash(provider, original, binding);
graph.validateScopedPolicyGraphV2FactoryBinding(coordinates, provider, original, recipe, dependencies, binding);
graph.decodeScopedPolicyGraphV2Recipe(graph.encodeScopedPolicyGraphV2Recipe(recipe));
graph.decodeScopedPolicyGraphV2Graph(graph.encodeScopedPolicyGraphV2Graph(saved));
graph.decodeScopedPolicyGraphV2PolicyEvidence(graph.encodeScopedPolicyGraphV2PolicyEvidence(evidence));
graph.prepareScopedPolicyGraphV2Read(coordinates, caller, { host: "sourceFactory", kind: "dependencies" });
graph.prepareScopedPolicyGraphV2Read(coordinates, caller, { host: "sourceFactory", kind: "currentInventoryPlan", scope });
graph.prepareScopedPolicyGraphV2Read(coordinates, caller, { host: "sourceFactory", kind: "sourceSetForPlan", plan });
graph.prepareScopedPolicyGraphV2Read(coordinates, caller, { host: "sourceFactory", kind: "supportsInterface", interfaceId: hash });
const read = graph.prepareScopedPolicyGraphV2Read(coordinates, caller, { host: "publicationFactory", kind: "graphForPlan", plan });
graph.normalizeScopedPolicyGraphV2Read(read);
graph.prepareScopedPolicyGraphV2Read(coordinates, caller, { host: "publicationFactory", kind: "requireCurrentGraph", scope });

// @ts-expect-error preparation never accepts arbitrary child implementation addresses
graph.prepareScopedPolicyGraphV2Call(coordinates, caller, { kind: "prepareGraph", scope, maximumChildren: 1n, children: targets });
// @ts-expect-error uint8 is still an exact bigint input
graph.prepareScopedPolicyGraphV2Call(coordinates, caller, { kind: "prepareGraph", scope, maximumChildren: 1 });
// @ts-expect-error no payment field in these original nonpayable methods
graph.prepareScopedPolicyGraphV2Call(coordinates, caller, { kind: "prepareSourceSet", scope, value: 1n });
// @ts-expect-error child publication is a different workflow
graph.prepareScopedPolicyGraphV2Call(coordinates, caller, { kind: "publishSnapshot", scope });
// @ts-expect-error finality is not a preparation operation
graph.prepareScopedPolicyGraphV2Call(coordinates, caller, { kind: "finalizeScope", scope });
// @ts-expect-error no arbitrary library methods exposed as wallet endpoints
graph.prepareScopedPolicyGraphV2Read(coordinates, caller, { host: "publicationFactory", kind: "children", scope });
// @ts-expect-error source reads are not publication factory methods
graph.prepareScopedPolicyGraphV2Read(coordinates, caller, { host: "publicationFactory", kind: "currentInventoryPlan", scope });
// @ts-expect-error writes cannot be disguised as reads
graph.prepareScopedPolicyGraphV2Read(coordinates, caller, { host: "sourceFactory", kind: "prepareSourceSet", scope });
// @ts-expect-error scope enums retain only original values
graph.normalizeScopedPolicyGraphV2Scope({ ...scope, scopeType: 5n });
// @ts-expect-error no numeric chain coercion
graph.prepareScopedPolicyGraphV2Call({ ...coordinates, chainId: 1 }, caller, { kind: "prepareSourceSet", scope });
// @ts-expect-error immutable child prefix
saved.children[0] = caller;
// @ts-expect-error immutable recipe GGP tuple
recipe.snapshotGas[0].genesisValue = 1n;
// @ts-expect-error immutable source policy inventory
evidence.policies.push(rows[0]!);
// @ts-expect-error immutable reconstructed CALL
action.call.value = 1n;
// @ts-expect-error no provenance upgrade through structural normalization
const verified: true = action.factsVerified;

void [call, unverified, status, childCount, sourceHash, frozen];
