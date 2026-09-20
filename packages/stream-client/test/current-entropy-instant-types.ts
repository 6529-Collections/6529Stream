import type { Address, Hex } from "../src/generated/contracts.js";
import {
  normalizeEntropyInstantPolicySnapshot, normalizeEntropyInstantPolicyState, normalizeEntropyInstantPolicyRecord,
  normalizeEntropyInstantPolicyInput, normalizeEntropyInstantPolicyResolution, normalizeEntropyInstantProviderProfile,
  entropyInstantPolicyRecord, entropyInstantPolicyEntryFromRecord, entropyInstantPolicyHash, entropyInstantPolicyContentStateHash,
  prepareEntropyInstantPolicyConfigure, prepareEntropyInstantPolicyFreeze, normalizeEntropyInstantPolicyPlan,
  prepareEntropyInstantPolicyArtistConsent, normalizeEntropyInstantPolicyArtistConsent, entropyInstantPolicyArtistRecordHash,
  normalizeEntropyInstantPolicyGovernanceWindow, assertEntropyInstantPolicyGovernanceWindow,
  entropyInstantPolicyGovernanceBatch, normalizeEntropyInstantPolicyGovernanceBatch,
  normalizeEntropyInstantRequestCoordinates, normalizeEntropyInstantRequestPolicySnapshot, normalizeEntropyInstantSubject,
  encodeEntropyInstantRequestPolicySnapshot, decodeEntropyInstantRequestPolicySnapshot, normalizeEntropyInstantRequestSnapshot,
  entropyInstantContext, entropyInstantRequestKey, entropyInstantProviderRequestId, entropyInstantSubjectKey,
  prepareEntropyInstantRequest, normalizeEntropyInstantRequestPlan, entropyInstantProviderConfigHash, entropyInstantRawResult,
  entropyInstantSeed, normalizeEntropyInstantTerminalFacts, encodeEntropyInstantTerminalFacts, decodeEntropyInstantTerminalFacts,
  type EntropyInstantPolicySnapshot, type EntropyInstantPolicyState, type EntropyInstantPolicyRecord,
  type EntropyInstantPolicyCoordinates, type EntropyInstantPolicyInput, type EntropyInstantPolicyResolution,
  type EntropyInstantPolicyPlan, type EntropyInstantPolicyAuthorization, type EntropyInstantPolicyArtistRecordInput,
  type EntropyInstantPolicyArtistConsent, type EntropyInstantPolicyGovernanceBatch, type EntropyInstantPolicyGovernanceWindow,
  type EntropyInstantRequestCoordinates, type EntropyInstantRequestPolicySnapshot, type EntropyInstantSubject,
  type EntropyInstantRequestSnapshot, type EntropyInstantRequestPlan, type EntropyInstantTerminalFacts,
} from "../src/current-entropy-instant.js";

declare const snapshot: EntropyInstantPolicySnapshot, state: EntropyInstantPolicyState, record: EntropyInstantPolicyRecord;
declare const coordinates: EntropyInstantPolicyCoordinates, input: EntropyInstantPolicyInput, resolution: EntropyInstantPolicyResolution;
declare const caller: Address, signer: Address, registry: Address, hash: Hex, bytes: Hex;
declare const authorization: EntropyInstantPolicyAuthorization, recordInput: EntropyInstantPolicyArtistRecordInput, window: EntropyInstantPolicyGovernanceWindow;
normalizeEntropyInstantPolicySnapshot(snapshot); normalizeEntropyInstantPolicyState(state); normalizeEntropyInstantPolicyRecord(record);
normalizeEntropyInstantPolicyInput(input); normalizeEntropyInstantPolicyResolution(resolution);
normalizeEntropyInstantProviderProfile({ mode: 1n, assumptionsHash: hash });
entropyInstantPolicyRecord(snapshot); entropyInstantPolicyEntryFromRecord(record); entropyInstantPolicyHash(coordinates, state); entropyInstantPolicyContentStateHash(hash, true);
const configure = prepareEntropyInstantPolicyConfigure(snapshot, input, resolution), freeze = prepareEntropyInstantPolicyFreeze(snapshot);
const configureClass: 1n = configure.actionClass, freezeClass: 2n = freeze.actionClass;
const delayedMode: 1n = configure.resolution.instantMode, lowSecurity: 1n = configure.input.securityClass;
const plans: readonly EntropyInstantPolicyPlan[] = [configure, freeze];
for (const plan of plans) {
  normalizeEntropyInstantPolicyPlan(plan);
  if (plan.kind === "configure") { const suppliedProfile: Hex = plan.resolution.assumptionsHash; void suppliedProfile; }
  const consent: EntropyInstantPolicyArtistConsent = prepareEntropyInstantPolicyArtistConsent(plan, registry, caller, signer, authorization);
  normalizeEntropyInstantPolicyArtistConsent(consent); entropyInstantPolicyArtistRecordHash(plan, recordInput);
  const unverified: false = consent.factsVerified; void unverified;
  normalizeEntropyInstantPolicyGovernanceWindow(window); assertEntropyInstantPolicyGovernanceWindow(plan.actionClass, window, 0n);
  const batch: EntropyInstantPolicyGovernanceBatch = entropyInstantPolicyGovernanceBatch(plan, 0n, window);
  normalizeEntropyInstantPolicyGovernanceBatch(batch);
}
declare const requestCoordinates: EntropyInstantRequestCoordinates, requestPolicy: EntropyInstantRequestPolicySnapshot;
declare const subject: EntropyInstantSubject, requestSnapshot: EntropyInstantRequestSnapshot, facts: EntropyInstantTerminalFacts;
normalizeEntropyInstantRequestCoordinates(requestCoordinates); normalizeEntropyInstantRequestPolicySnapshot(requestPolicy); normalizeEntropyInstantSubject(subject);
const decodedPolicy: EntropyInstantRequestPolicySnapshot = decodeEntropyInstantRequestPolicySnapshot(encodeEntropyInstantRequestPolicySnapshot(requestPolicy));
normalizeEntropyInstantRequestSnapshot(requestSnapshot);
entropyInstantContext(requestCoordinates, requestPolicy); entropyInstantRequestKey(requestCoordinates, requestPolicy); entropyInstantProviderRequestId(hash, requestPolicy); entropyInstantSubjectKey(1n);
const request: EntropyInstantRequestPlan = prepareEntropyInstantRequest(requestSnapshot, caller, 100n);
const noProviderPayment: 0n = request.providerFee, suppliedFacts: false = request.factsVerified, refundCredit: bigint = request.callerCredit;
normalizeEntropyInstantRequestPlan(request); entropyInstantProviderConfigHash(caller); entropyInstantProviderConfigHash(caller, hash);
const raw = entropyInstantRawResult(request.requestKey, request.context, 10n, hash, requestPolicy.providerConfigHash, hash);
const seed: Hex = entropyInstantSeed(request, raw.rawRandomness), provenance: Hex = raw.provenanceHash;
const decodedFacts: EntropyInstantTerminalFacts = decodeEntropyInstantTerminalFacts(encodeEntropyInstantTerminalFacts(facts));
normalizeEntropyInstantTerminalFacts(facts);
void configureClass; void freezeClass; void delayedMode; void lowSecurity; void decodedPolicy; void decodedFacts; void noProviderPayment; void suppliedFacts; void refundCredit; void seed; void provenance; void bytes;

// @ts-expect-error this source-pinned planner is INSTANT only; ASYNC retains its existing separate API
normalizeEntropyInstantPolicyInput({ ...input, mode: 2n });
// @ts-expect-error INSTANT cannot claim HIGH_ASSURANCE
normalizeEntropyInstantPolicyInput({ ...input, securityClass: 0n });
// @ts-expect-error only source-delayed profile1 is admitted
normalizeEntropyInstantProviderProfile({ mode: 2n, assumptionsHash: hash });
// @ts-expect-error runtime evidence is not an additional original PolicyInput field
normalizeEntropyInstantPolicyInput({ ...input, providerCodeHash: hash });
// @ts-expect-error direct numeric widths are bigint, not JS safe-integer assumptions
normalizeEntropyInstantPolicyInput({ ...input, timeoutBlocks: 0 });
// @ts-expect-error explicit resolution must include the observed delayed mode/assumptions
prepareEntropyInstantPolicyConfigure(snapshot, input, { providerCodeHash: hash, providerConfigHash: hash, recoveryPolicyHash: hash });
// @ts-expect-error a terminal freeze cannot smuggle a replacement input
normalizeEntropyInstantPolicyPlan({ ...freeze, input });
// @ts-expect-error original freeze action class is2
normalizeEntropyInstantPolicyPlan({ ...freeze, actionClass: 1n });
// @ts-expect-error caller and signer are independent required inputs
prepareEntropyInstantPolicyArtistConsent(configure, registry, signer, authorization);
// @ts-expect-error nonce remains uint256 bigint
prepareEntropyInstantPolicyArtistConsent(configure, registry, caller, signer, { ...authorization, nonce: 0 });
// @ts-expect-error mined Artist record time is not signed deadline
entropyInstantPolicyArtistRecordHash(configure, { ...recordInput, deadline: 100n });
// @ts-expect-error original governance scope only uses configure1/freeze2
assertEntropyInstantPolicyGovernanceWindow(3n, window, 0n);
// @ts-expect-error governance nonce remains full-width bigint
entropyInstantPolicyGovernanceBatch(configure, 1, window);
// @ts-expect-error mutable derivation of next policy is prohibited
configure.next.entry.policyHash = hash;
// @ts-expect-error reviewed nested input is immutable
configure.input.reveal.declared = true;
// @ts-expect-error external facts do not establish verification
configure.factsVerified = true;
// @ts-expect-error original request is token-only, no invented scope parameter
normalizeEntropyInstantRequestCoordinates({ ...requestCoordinates, scopeId: hash });
// @ts-expect-error original uint256 token ID remains bigint
normalizeEntropyInstantRequestCoordinates({ ...requestCoordinates, tokenId: 1 });
// @ts-expect-error original context retains epoch32 bigint
normalizeEntropyInstantRequestPolicySnapshot({ ...requestPolicy, providerEpoch: 1 });
// @ts-expect-error provider assumptions are not appended to the original stored seven-field snapshot
normalizeEntropyInstantRequestPolicySnapshot({ ...requestPolicy, assumptionsHash: hash });
// @ts-expect-error actual subject status is numeric, not inferred terminal boolean
normalizeEntropyInstantSubject({ ...subject, status: true });
// @ts-expect-error the original mint commitment belongs in Subject, not as a new snapshot field
normalizeEntropyInstantRequestSnapshot({ ...requestSnapshot, mintCommitment: hash });
// @ts-expect-error request eligibility block number must be explicit bigint
prepareEntropyInstantRequest({ ...requestSnapshot, blockNumber: 100 }, caller, 0n);
// @ts-expect-error msg.value is exact uint256 bigint
prepareEntropyInstantRequest(requestSnapshot, caller, 1);
// @ts-expect-error a caller must be explicit even for public requests
prepareEntropyInstantRequest(requestSnapshot, 0n);
// @ts-expect-error source block must be exact bigint
entropyInstantRawResult(hash, bytes, 100, hash, hash, hash);
// @ts-expect-error raw input is original bytes32, not a narrowed random number
entropyInstantSeed(request, 10n);
// @ts-expect-error seed helper requires a complete reconstructed request, not just an arbitrary key
entropyInstantSeed(request.requestKey, hash);
// @ts-expect-error credit estimate is immutable and belongs to the supplied actual caller
request.callerCredit = 0n;
// @ts-expect-error nested original mint commitment must remain immutable
request.snapshot.subject.inputsHash = hash;
// @ts-expect-error provider receives no value for this profile
request.providerFee = 1n;
// @ts-expect-error terminal getter carries the complete original twelve-field policy
normalizeEntropyInstantTerminalFacts({ ...facts, policy: state.entry });
// @ts-expect-error sixteen-word read has no invented finalized/finality property
normalizeEntropyInstantTerminalFacts({ ...facts, finalized: true });
// @ts-expect-error actual status remains an original integer
normalizeEntropyInstantTerminalFacts({ ...facts, status: "FINALIZED" });
// @ts-expect-error returned codec snapshot is deeply readonly
decodedFacts.policy.mode = 2n;
