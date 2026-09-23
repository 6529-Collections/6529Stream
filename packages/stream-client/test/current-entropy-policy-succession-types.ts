import type { Address, Hex } from "../src/generated/contracts.js";
import type { UnsignedCall } from "../src/binding.js";
import * as s from "../src/current-entropy-policy-succession.js";

declare const configuration: s.EntropyPolicySuccessionConfiguration;
declare const hash: Hex, address: Address, runtime: s.EntropyPolicySuccessionRuntime;
declare const policy: s.EntropyPolicySuccessionPolicyExport, recovery: s.EntropyPolicySuccessionRecoveryExport;
declare const receipt: s.EntropyPolicySuccessionImportReceipt, imported: s.EntropyPolicySuccessionImportedPolicy;
declare const pointer: s.EntropyPolicySuccessionPointer, registration: s.EntropyPolicySuccessionRegistration;
declare const manifestState: s.EntropyPolicySuccessionManifestState, update: s.EntropyPolicySuccessionManifestUpdate;
declare const admission: s.EntropyPolicySuccessionAdmission, relay: s.EntropyPolicySuccessionRelayInput, result: s.EntropyPolicySuccessionRelayResult;
declare const history: s.EntropyPolicySuccessionCatalogHistory, origins: readonly s.EntropyPolicySuccessionRuntime[];
declare const window: s.EntropyPolicySuccessionGovernanceWindow;

const config: s.EntropyPolicySuccessionConfiguration = s.normalizeEntropyPolicySuccessionConfiguration(configuration);
const inventory: s.EntropyPolicySuccessionInventoryHeader = s.entropyPolicySuccessionInventory([1n, 0n, 1n << 230n], 3n);
s.entropyPolicySuccessionInventoryAppend(hash, 0n, 1n << 255n);
const copy = s.prepareEntropyPolicySuccessionPlan(config, { kind: "copy", expectedIndex: 1n });
const confirm = s.prepareEntropyPolicySuccessionPlan(config, { kind: "confirm-route", collectionId: 1n });
const begin = s.prepareEntropyPolicySuccessionPlan(config, { kind: "begin", receipt, predecessorInventory: inventory, candidateInventory: inventory, pointer, manifestHash: hash });
const seal = s.prepareEntropyPolicySuccessionPlan(config, { kind: "seal", receipt, predecessorInventory: inventory, candidateInventory: inventory });
const route = s.prepareEntropyPolicySuccessionPlan(config, { kind: "admit-route", origin: runtime, receipt, policy, recovery, importedPolicy: imported, currentAdmission: admission, predecessorAdmission: null });
const cutover = s.prepareEntropyPolicySuccessionPlan(config, { kind: "cutover", receipt, predecessorInventory: inventory, candidateInventory: inventory, pointer, registration, registrationStatus: 1n, manifestState, payload: address, update });
const saved: s.EntropyPolicySuccessionCatalogInventory = s.entropyPolicySuccessionCatalogInventory(config, hash, hash, history, origins, hash);
const replay = s.entropyPolicySuccessionCatalogHistory(config.chainId, config.executor, hash, history);
const next = s.entropyPolicySuccessionCatalogExtension(config.chainId, config.executor, replay.state, saved.additions.slice(0, 64));
const catalog = s.prepareEntropyPolicySuccessionPlan(config, { kind: "catalog", inventory: saved, baseHistory: history, origins, deploymentHash: hash, completedRows: 0n, catalogState: replay.state, manifestState, payload: address, update });
const plans: readonly s.EntropyPolicySuccessionPlan[] = [copy, confirm, begin, seal, route, cutover, catalog];
for (const plan of plans) {
  s.normalizeEntropyPolicySuccessionPlan(plan);
  const unverified: false = plan.factsVerified;
  const calls: readonly UnsignedCall[] = plan.targetCalls;
  const actionClass: 1n | 3n | null = plan.actionClass;
  if (plan.request.kind === "catalog") { const offset: bigint = plan.request.completedRows; void offset; }
  if (plan.request.kind === "admit-route") { const origin: Address = plan.request.origin.target; void origin; }
  void unverified; void calls; void actionClass;
}
s.normalizeEntropyPolicySuccessionCatalogHistory(history); s.normalizeEntropyPolicySuccessionCatalogState(replay.state);
s.normalizeEntropyPolicySuccessionCatalogInventory(saved); s.entropyPolicySuccessionCatalogInventoryHash(saved);
s.entropyPolicySuccessionCatalogHash(config.chainId, config.executor, hash, history.initialRows);
const rows: readonly s.EntropyPolicySuccessionCatalogRow[] = s.entropyPolicySuccessionCatalogRows(runtime, origins, hash);
const stateHash: Hex = next.transition.newHash;
const batch: s.EntropyPolicySuccessionGovernanceBatch = s.entropyPolicySuccessionGovernanceBatch(catalog, 0n, window);
s.normalizeEntropyPolicySuccessionGovernanceBatch(batch); s.assertEntropyPolicySuccessionGovernanceWindow(window, 100n);
const publications: readonly UnsignedCall[] = [batch.publicationCall, batch.scheduleCall, batch.executionCall];
s.validateEntropyPolicySuccessionPolicy(config.chainId, config.core, policy); s.validateEntropyPolicySuccessionRecovery(config.chainId, config.core, recovery); s.verifyEntropyPolicySuccessionRecoveryBinding(policy, recovery);
const decodedPolicy: s.EntropyPolicySuccessionPolicyExport = s.decodeEntropyPolicySuccessionPolicyExport(s.encodeEntropyPolicySuccessionPolicyExport(policy));
const decodedRecovery: s.EntropyPolicySuccessionRecoveryExport = s.decodeEntropyPolicySuccessionRecoveryExport(s.encodeEntropyPolicySuccessionRecoveryExport(recovery));
const decodedReceipt: s.EntropyPolicySuccessionImportReceipt = s.decodeEntropyPolicySuccessionImportReceipt(s.encodeEntropyPolicySuccessionImportReceipt(receipt));
const decodedResult: s.EntropyPolicySuccessionRelayResult = s.decodeEntropyPolicySuccessionRelayResult(s.encodeEntropyPolicySuccessionRelayResult(result));
s.entropyPolicySuccessionRelayId(config.chainId, config.core, runtime.target, runtime, relay);
s.entropyPolicySuccessionRelayWitnessHash(config.chainId, config.core, runtime, runtime, relay);
s.entropyPolicySuccessionRelayContext(config.core, relay); s.entropyPolicySuccessionRequestKey(config.chainId, config.core, config.candidate, relay);
s.entropyPolicySuccessionImportHash(config, receipt); s.entropyPolicySuccessionImportStateHash(hash, receipt);
s.entropyPolicySuccessionImportReady(receipt, config.predecessor, config.predecessorCodeHash, pointer.revision, inventory);
s.entropyPolicySuccessionBeginReceipt(config, inventory, 1n, hash);
s.entropyPolicySuccessionContentStateHash(hash, true); s.entropyPolicySuccessionPolicyHash(config.chainId, config.core, policy);
s.entropyPolicySuccessionPointerTransition(config, pointer, pointer); s.entropyPolicySuccessionManifestTransition(config, manifestState, address, update);
void rows; void stateHash; void publications; void decodedPolicy; void decodedRecovery; void decodedReceipt; void decodedResult;

// @ts-expect-error original uint256 requires bigint, even for small values
s.prepareEntropyPolicySuccessionPlan(config, { kind: "copy", expectedIndex: 1 });
// @ts-expect-error operational relay submission is outside this closed succession family
s.prepareEntropyPolicySuccessionPlan(config, { kind: "relay-request", input: relay });
// @ts-expect-error an admission requires copied policy evidence, not only a collection ID
s.prepareEntropyPolicySuccessionPlan(config, { kind: "admit-route", collectionId: 1n });
// @ts-expect-error the class3 cutover cannot omit the manifest tail
s.prepareEntropyPolicySuccessionPlan(config, { kind: "cutover", receipt, predecessorInventory: inventory, candidateInventory: inventory, pointer, registration, registrationStatus: 1n });
// @ts-expect-error a flat list is not original bind/extension history
s.entropyPolicySuccessionCatalogHistory(config.chainId, config.executor, hash, { rows });
// @ts-expect-error catalog stage keeps complete source inventory and dependency joins
s.prepareEntropyPolicySuccessionPlan(config, { kind: "catalog", additions: rows });
// @ts-expect-error immutable target call list
cutover.targetCalls.push(batch.executionCall);
// @ts-expect-error immutable original nested reveal
policy.policy.reveal.requestSLOBlocks = 1n;
// @ts-expect-error immutable imported receipt
receipt.state = 3n;
// @ts-expect-error source original enum is closed to 0..3
s.normalizeEntropyPolicySuccessionImportReceipt({ ...receipt, state: 4n });
// @ts-expect-error no authority verification claim from pure facts
const verified: true = batch.factsVerified;
// @ts-expect-error readonly saved addition list
saved.additions[0] = rows[0]!;
// @ts-expect-error readonly nested source history
history.extensions[0]!.push(rows[0]!);
// @ts-expect-error exact uint64 input remains bigint
s.assertEntropyPolicySuccessionGovernanceWindow(window, 100);
// @ts-expect-error unknown original policy profile
s.normalizeEntropyPolicySuccessionPolicyExport({ ...policy, profile: 2n });
void verified;
