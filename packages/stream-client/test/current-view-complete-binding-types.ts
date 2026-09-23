import type { Address, Hex } from "../src/generated/contracts.js";
import type { UnsignedCall } from "../src/binding.js";
import {
  type ViewCompleteBindingArray,
  type ViewCompleteBindingHost,
  type ViewCompleteBindingCoordinates,
  type ViewCompleteBindingCandidate,
  type ViewCompleteBindingNativeConfiguration,
  type ViewCompleteBindingCapability,
  type ViewCompleteBindingBasicReceipt,
  type ViewCompleteBindingReceipt,
  type ViewCompleteBindingSourceConfiguration,
  type ViewCompleteBindingReferenceDependencies,
  type ViewCompleteBindingInventoryDependencies,
  type ViewCompleteBindingBundleDependencies,
  type ViewCompleteBindingReadRequest,
  type ViewCompleteBindingCall,
  prepareViewCompleteBindingCall,
  normalizeViewCompleteBindingCall,
  prepareViewCompleteBindingRead,
  normalizeViewCompleteBindingRead,
  normalizeViewCompleteBindingCandidate,
  encodeViewCompleteBindingReceipt,
  decodeViewCompleteBindingReceipt,
  encodeViewCompleteBindingBasicReceipt,
  decodeViewCompleteBindingBasicReceipt,
  viewCompleteBindingCapabilityHash,
  viewCompleteBindingBasicProposalHash,
  viewCompleteBindingBasicReceiptHash,
  viewCompleteBindingProposalHash,
  viewCompleteBindingReceiptHash,
  viewCompleteBindingTransition,
  viewCompleteBindingSourceConfigurationHash,
  viewCompleteBindingWorkersHash,
  validateViewCompleteBindingCapability,
  validateViewCompleteBindingBasicCandidate,
  deriveViewCompleteBindingExpected,
  validateViewCompleteBindingProducerDependencies,
  authenticateViewCompleteBindingHistory,
} from "../src/current-view-complete-binding.js";

declare const coordinates: ViewCompleteBindingCoordinates;
declare const candidate: ViewCompleteBindingCandidate;
declare const original: ViewCompleteBindingNativeConfiguration;
declare const capability: ViewCompleteBindingCapability;
declare const basic: ViewCompleteBindingBasicReceipt;
declare const complete: ViewCompleteBindingReceipt;
declare const source: ViewCompleteBindingSourceConfiguration;
declare const reference: ViewCompleteBindingReferenceDependencies;
declare const originalInventory: ViewCompleteBindingInventoryDependencies;
declare const inventory: ViewCompleteBindingInventoryDependencies;
declare const bundle: ViewCompleteBindingBundleDependencies;
declare const workers: ViewCompleteBindingArray<Address, 5>;
declare const workerHashes: ViewCompleteBindingArray<Hex, 5>;
declare const address: Address;
declare const hash: Hex;

const prepared: ViewCompleteBindingCall = normalizeViewCompleteBindingCall(
  prepareViewCompleteBindingCall(coordinates, candidate),
);
const inner: UnsignedCall = prepared.call;
const governanceOnly: true = prepared.governanceTargetOnly;
const originalClass: 2n = prepared.requiredActionClass;
const cloned = normalizeViewCompleteBindingCandidate(candidate);
const receipt: ViewCompleteBindingReceipt = decodeViewCompleteBindingReceipt(encodeViewCompleteBindingReceipt(complete));
const basicReceipt: ViewCompleteBindingBasicReceipt = decodeViewCompleteBindingBasicReceipt(encodeViewCompleteBindingBasicReceipt(basic));
const basicTime: bigint = basicReceipt.boundAt;
const hashes: readonly Hex[] = [
  viewCompleteBindingCapabilityHash(coordinates, capability),
  viewCompleteBindingBasicProposalHash(basic),
  viewCompleteBindingBasicReceiptHash(basic),
  viewCompleteBindingProposalHash(basic, complete),
  viewCompleteBindingReceiptHash(coordinates, complete),
  viewCompleteBindingWorkersHash(workers, workerHashes),
];
const hosts: readonly ViewCompleteBindingHost[] = ["preservation", "current-authority-preservation"];
for (const host of hosts) {
  const sourceHash: Hex = viewCompleteBindingSourceConfigurationHash(host, coordinates, source);
  void sourceHash;
}
const transition = viewCompleteBindingTransition(coordinates, basic, complete);
const newValueHash: Hex = transition.newValueHash;
const cap = validateViewCompleteBindingCapability(coordinates, original, capability);
const capUnverified: false = cap.factsVerified;
validateViewCompleteBindingBasicCandidate(coordinates, original, capability, basic);
const expected = deriveViewCompleteBindingExpected(original, basic, candidate.selection, originalInventory);
const dependencies = validateViewCompleteBindingProducerDependencies(expected, candidate.selection, reference, inventory, bundle);
const dependenciesUnverified: false = dependencies.factsVerified;
const local = authenticateViewCompleteBindingHistory(coordinates, basic, complete);
const localUnverified: false = local.factsVerified;
const noCurrentness: false = local.currentnessChecked;
const noTransaction: false = local.transactionAuthenticated;

const reads: readonly ViewCompleteBindingReadRequest[] = [
  { kind: "completeViewPreservationBindingProfile" },
  { kind: "completeViewPreservationBindingTransition", candidate },
  { kind: "viewFinalitySources" },
  { kind: "viewFinalitySourcesReceipt" },
];
for (const request of reads) {
  const plan = normalizeViewCompleteBindingRead(prepareViewCompleteBindingRead(coordinates, request));
  const call: UnsignedCall = plan.call;
  // @ts-expect-error Prepared read coordinates are detached and immutable.
  plan.coordinates.provider = address;
  void call;
}

// @ts-expect-error No direct wallet authority is present on an inner governance target plan.
prepared.caller;
// @ts-expect-error Original singleton action class is fixed to class 2.
const wrongClass: 1n = prepared.requiredActionClass;
// @ts-expect-error Original provider family is a closed union.
viewCompleteBindingSourceConfigurationHash("arbitrary-provider", coordinates, source);
// @ts-expect-error Numeric JavaScript chain IDs are not accepted.
prepareViewCompleteBindingCall({ chainId: 1, provider: address }, candidate);
// @ts-expect-error No outer governance execution is exposed as a provider read.
const writeAsRead: ViewCompleteBindingReadRequest = { kind: "bindCompleteViewPreservation", candidate };
// @ts-expect-error The older basic-only mutation is excluded.
const basicWrite: ViewCompleteBindingReadRequest = { kind: "bindViewPreservation", candidate };
// @ts-expect-error Only the actual preview method accepts a candidate.
const extraCandidate: ViewCompleteBindingReadRequest = { kind: "viewFinalitySources", candidate };
// @ts-expect-error The exact worker roster has five members.
viewCompleteBindingWorkersHash([address], workerHashes);
// @ts-expect-error The exact snapshot roster has ten members.
const wrongRoster: ViewCompleteBindingArray<Address, 10> = workers;
// @ts-expect-error Candidate subobjects are readonly.
cloned.selection.referencePublication = address;
// @ts-expect-error Original uint32 declaration inputs are bigint.
prepareViewCompleteBindingCall(coordinates, { ...candidate, declaration: { ...candidate.declaration, readGas: 1 } });
// @ts-expect-error Receipt timestamp is immutable.
receipt.boundAt = 1n;
// @ts-expect-error Nested historical snapshot pins are immutable.
local.basic.dependencies.codeHashes[0] = hash;
// @ts-expect-error Expected fixed roster has no mutable push method.
expected.targets.push(address);
// @ts-expect-error Unsigned target calldata cannot be substituted after normalization.
prepared.call.data = hash;

void [inner, governanceOnly, originalClass, basicTime, hashes, newValueHash, capUnverified,
  dependenciesUnverified, localUnverified, noCurrentness, noTransaction, wrongClass,
  writeAsRead, basicWrite, extraCandidate, wrongRoster];
