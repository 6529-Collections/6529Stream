import type { Address, Hex } from "../src/generated/contracts.js";
import { normalizeEntropyCollectionPolicyCoordinates, normalizeEntropyCollectionPolicyInput,
  normalizeEntropyCollectionPolicyReveal, normalizeEntropyCollectionPolicyConfig, normalizeEntropyCollectionPolicyRecovery,
  normalizeEntropyCollectionPolicyEntry, normalizeEntropyCollectionPolicyRecord, normalizeEntropyCollectionPolicyState,
  normalizeEntropyCollectionPolicySnapshot, normalizeEntropyCollectionPolicyResolution, encodeEntropyCollectionPolicyInput,
  decodeEntropyCollectionPolicyInput, encodeEntropyCollectionPolicyRecord, decodeEntropyCollectionPolicyRecord,
  entropyCollectionPolicyContentStateHash, entropyCollectionPolicyEntryFromRecord, entropyCollectionPolicyHash,
  entropyCollectionPolicyLegacyHash, entropyCollectionPolicyRecord, entropyCollectionPolicyScopeHash, entropyCollectionPolicyStateHash,
  prepareEntropyCollectionPolicyConfigure, prepareEntropyCollectionPolicyFreeze, normalizeEntropyCollectionPolicyPlan,
  prepareEntropyCollectionPolicyArtistConsent, normalizeEntropyCollectionPolicyArtistConsent, entropyCollectionPolicyArtistRecordHash,
  normalizeEntropyCollectionPolicyGovernanceWindow, assertEntropyCollectionPolicyGovernanceWindow,
  entropyCollectionPolicyGovernanceBatch, normalizeEntropyCollectionPolicyGovernanceBatch,
  type EntropyCollectionPolicySnapshot, type EntropyCollectionPolicyInput, type EntropyCollectionPolicyResolution,
  type EntropyCollectionPolicyCoordinates, type EntropyCollectionPolicyState, type EntropyCollectionPolicyRecord,
  type EntropyCollectionPolicyPlan, type EntropyCollectionPolicyArtistConsent, type EntropyCollectionPolicyAuthorization,
  type EntropyCollectionPolicyArtistRecordInput, type EntropyCollectionPolicyGovernanceWindow,
  type EntropyCollectionPolicyGovernanceBatch } from "../src/current-entropy-collection-policy.js";

declare const snapshot: EntropyCollectionPolicySnapshot, input: EntropyCollectionPolicyInput, resolution: EntropyCollectionPolicyResolution;
declare const coordinates: EntropyCollectionPolicyCoordinates, state: EntropyCollectionPolicyState, record: EntropyCollectionPolicyRecord;
declare const authorization: EntropyCollectionPolicyAuthorization, recordFacts: EntropyCollectionPolicyArtistRecordInput;
declare const window: EntropyCollectionPolicyGovernanceWindow, registry: Address, caller: Address, signer: Address, hash: Hex;
normalizeEntropyCollectionPolicyCoordinates(coordinates); normalizeEntropyCollectionPolicyInput(input);
normalizeEntropyCollectionPolicyReveal(input.reveal); normalizeEntropyCollectionPolicyConfig(snapshot.config);
normalizeEntropyCollectionPolicyRecovery(snapshot.recovery); normalizeEntropyCollectionPolicyEntry(snapshot.entry);
normalizeEntropyCollectionPolicyRecord(record); normalizeEntropyCollectionPolicyState(state);
normalizeEntropyCollectionPolicySnapshot(snapshot); normalizeEntropyCollectionPolicyResolution(resolution);
const decodedInput: EntropyCollectionPolicyInput = decodeEntropyCollectionPolicyInput(encodeEntropyCollectionPolicyInput(input));
const decodedRecord: EntropyCollectionPolicyRecord = decodeEntropyCollectionPolicyRecord(encodeEntropyCollectionPolicyRecord(record));
entropyCollectionPolicyContentStateHash(hash, false); entropyCollectionPolicyEntryFromRecord(record);
entropyCollectionPolicyHash(coordinates, state); entropyCollectionPolicyLegacyHash(coordinates, state);
entropyCollectionPolicyRecord(snapshot); entropyCollectionPolicyScopeHash(coordinates, "configure"); entropyCollectionPolicyScopeHash(coordinates, "freeze");
entropyCollectionPolicyStateHash(hash, state);
const configure = prepareEntropyCollectionPolicyConfigure(snapshot, input, resolution), freeze = prepareEntropyCollectionPolicyFreeze(snapshot);
const configureClass: 1n = configure.actionClass, freezeClass: 2n = freeze.actionClass;
const plans: readonly EntropyCollectionPolicyPlan[] = [configure, freeze];
for (const plan of plans) {
  normalizeEntropyCollectionPolicyPlan(plan);
  if (plan.kind === "configure") { const suppliedHashes: Hex = plan.resolution.providerConfigHash; void suppliedHashes; }
  const consent: EntropyCollectionPolicyArtistConsent = prepareEntropyCollectionPolicyArtistConsent(plan, registry, caller, signer, authorization);
  normalizeEntropyCollectionPolicyArtistConsent(consent); entropyCollectionPolicyArtistRecordHash(plan, recordFacts);
  const unverified: false = consent.factsVerified; void unverified;
  normalizeEntropyCollectionPolicyGovernanceWindow(window); assertEntropyCollectionPolicyGovernanceWindow(plan.actionClass, window, 0n);
  const batch: EntropyCollectionPolicyGovernanceBatch = entropyCollectionPolicyGovernanceBatch(plan, 0n, window);
  normalizeEntropyCollectionPolicyGovernanceBatch(batch);
}
void decodedInput; void decodedRecord; void configureClass; void freezeClass;

// @ts-expect-error uint256 chain coordinate remains bigint
normalizeEntropyCollectionPolicyCoordinates({ ...coordinates, chainId: 1 });
// @ts-expect-error original input is closed to the three original modes
normalizeEntropyCollectionPolicyInput({ ...input, mode: 3n });
// @ts-expect-error only original security classes0/1 exist
normalizeEntropyCollectionPolicyInput({ ...input, securityClass: 2n });
// @ts-expect-error render requirement is explicit, not inferred from a renderer label
normalizeEntropyCollectionPolicyInput({ ...input, renderRequirement: "STATIC" });
// @ts-expect-error nested reveal fee retains full uint256 bigint
normalizeEntropyCollectionPolicyInput({ ...input, reveal: { ...input.reveal, revealFeePerTokenWei: 0 } });
// @ts-expect-error reveal declaration boolean is not a truthy integer
normalizeEntropyCollectionPolicyInput({ ...input, reveal: { ...input.reveal, declared: 1n } });
// @ts-expect-error runtime/config hashes are resolved source facts, not appended original PolicyInput fields
normalizeEntropyCollectionPolicyInput({ ...input, providerCodeHash: hash });
// @ts-expect-error snapshot includes exact Core lifetime mint fact
normalizeEntropyCollectionPolicySnapshot({ ...snapshot, collectionMintedEver: "0" });
// @ts-expect-error supplied facts never establish protocol authority
normalizeEntropyCollectionPolicySnapshot({ ...snapshot, factsVerified: true });
// @ts-expect-error epoch is uint32 bigint
normalizeEntropyCollectionPolicyState({ ...state, providerEpoch: 1 });
// @ts-expect-error raw Entry has no synthetic explicitPolicy read field
normalizeEntropyCollectionPolicyEntry({ ...state.entry, explicitPolicy: false });
// @ts-expect-error public12word record needs its frozen/content/evidence facts
normalizeEntropyCollectionPolicyRecord(state.entry);
// @ts-expect-error collection policy has no unfreeze transition
entropyCollectionPolicyScopeHash(coordinates, "unfreeze");
// @ts-expect-error configuring requires explicitly supplied source dependency hashes
prepareEntropyCollectionPolicyConfigure(snapshot, input);
// @ts-expect-error code hash, config hash and recovery hash cannot be abbreviated
prepareEntropyCollectionPolicyConfigure(snapshot, input, { providerCodeHash: hash });
// @ts-expect-error freeze does not carry a replacement input
normalizeEntropyCollectionPolicyPlan({ ...freeze, input });
// @ts-expect-error class2 is fixed for freeze, not chosen by caller
normalizeEntropyCollectionPolicyPlan({ ...freeze, actionClass: 1n });
// @ts-expect-error actualcaller and signer must both remain explicit
prepareEntropyCollectionPolicyArtistConsent(configure, registry, caller, authorization);
// @ts-expect-error nonce is uint256 bigint, not JS number
prepareEntropyCollectionPolicyArtistConsent(configure, registry, caller, signer, { ...authorization, nonce: 0 });
// @ts-expect-error deadline is uint64 bigint
prepareEntropyCollectionPolicyArtistConsent(configure, registry, caller, signer, { ...authorization, deadline: 100 });
// @ts-expect-error consent signing host cannot be selected with a boolean flag
prepareEntropyCollectionPolicyArtistConsent(configure, registry, caller, signer, { ...authorization, contractWallet: true });
// @ts-expect-error record timestamp is the execution fact, not signed deadline
entropyCollectionPolicyArtistRecordHash(configure, { ...recordFacts, deadline: 100n });
// @ts-expect-error only original class1/class2 is supported
assertEntropyCollectionPolicyGovernanceWindow(3n, window, 0n);
// @ts-expect-error scheduling timestamp remains explicit bigint
assertEntropyCollectionPolicyGovernanceWindow(1n, window, 0);
// @ts-expect-error governance nonce remains uint256 bigint
entropyCollectionPolicyGovernanceBatch(configure, 0, window);
// @ts-expect-error planned operational fee is immutable
configure.next.reveal.revealFeePerTokenWei = 0n;
// @ts-expect-error nested source snapshot cannot mutate after prepare
configure.snapshot.config.providerConfigHash = hash;
// @ts-expect-error governance calldata cannot mutate after review
freeze.targetCall.data = hash;
