import type { Address, Hex } from "../src/generated/contracts.js";
import type { UnsignedCall } from "../src/binding.js";
import { metadataWorkCitation, normalizeMetadataCitationCoordinates, normalizeMetadataCitationSnapshot,
  normalizeMetadataCitationRegistration, normalizeMetadataCitationAnalysis, normalizeMetadataCitationVersion,
  normalizeMetadataCitationRecord, normalizeMetadataCitationRenderRequest, normalizeMetadataCitationReads,
  normalizeMetadataCitationTargets, normalizeMetadataCitationGoldenVectors, encodeMetadataCitationAnalysis,
  decodeMetadataCitationAnalysis, encodeMetadataCitationGoldenVectors, decodeMetadataCitationGoldenVectors,
  encodeMetadataCitationRecord, decodeMetadataCitationRecord, metadataCitationTargetSetHash, metadataCitationReadSetHash,
  metadataCitationDeclarationHash, metadataCitationScopeHash, metadataCitationStateHash, metadataCitationTransition,
  prepareMetadataCitationRegistration, normalizeMetadataCitationPlan, validateMetadataCitationEvidence,
  prepareMetadataCitationRenderCall, normalizeMetadataCitationGovernanceWindow, assertMetadataCitationGovernanceWindow,
  metadataCitationGovernanceBatch, normalizeMetadataCitationGovernanceBatch,
  type MetadataCitationSnapshot, type MetadataCitationRegistration, type MetadataCitationAnalysis,
  type MetadataCitationGoldenVector, type MetadataCitationRead, type MetadataCitationRenderRequest,
  type MetadataCitationRecord, type MetadataCitationGovernanceWindow, type MetadataCitationPlan,
  type MetadataCitationGovernanceBatch, type MetadataCitationEvidence } from "../src/current-metadata-citation.js";

declare const s: MetadataCitationSnapshot, r: MetadataCitationRegistration, analysis: MetadataCitationAnalysis;
declare const goldens: readonly MetadataCitationGoldenVector[], reads: readonly MetadataCitationRead[], q: MetadataCitationRenderRequest;
declare const record: MetadataCitationRecord, window: MetadataCitationGovernanceWindow, account: Address, hash: Hex;
const citation: string = metadataWorkCitation(s.chainId, account, 0n);
normalizeMetadataCitationCoordinates({ chainId: s.chainId, registry: s.registry, schemaRegistry: s.schemaRegistry,
  schemaRegistryCodeHash: s.schemaRegistryCodeHash, governanceExecutor: s.governanceExecutor });
normalizeMetadataCitationSnapshot(s); normalizeMetadataCitationRegistration(r); normalizeMetadataCitationAnalysis(analysis);
normalizeMetadataCitationVersion(s.originalVersion); normalizeMetadataCitationRecord(record); normalizeMetadataCitationRenderRequest(q);
normalizeMetadataCitationReads(reads); normalizeMetadataCitationTargets(s.targets); normalizeMetadataCitationGoldenVectors(goldens);
const analysisRoundtrip: MetadataCitationAnalysis = decodeMetadataCitationAnalysis(encodeMetadataCitationAnalysis(analysis));
const goldenRoundtrip: readonly MetadataCitationGoldenVector[] = decodeMetadataCitationGoldenVectors(encodeMetadataCitationGoldenVectors(goldens));
const recordRoundtrip: MetadataCitationRecord = decodeMetadataCitationRecord(encodeMetadataCitationRecord(record));
const targetHash: Hex = metadataCitationTargetSetHash(s.targets), readHash: Hex = metadataCitationReadSetHash(s.targets, reads);
metadataCitationDeclarationHash(s, r, reads); metadataCitationScopeHash(s.chainId, s.registry, r.versionKey); metadataCitationStateHash(record.registrationHash);
metadataCitationTransition(s, r, reads);
const plan: MetadataCitationPlan = prepareMetadataCitationRegistration(s, r, reads);
normalizeMetadataCitationPlan(plan);
const evidence: MetadataCitationEvidence = validateMetadataCitationEvidence(plan, analysis, goldens);
const unverified: false = evidence.factsVerified, classOne: 1n = plan.actionClass;
const jsonCall: UnsignedCall = prepareMetadataCitationRenderCall(account, q, 0n), htmlCall: UnsignedCall = prepareMetadataCitationRenderCall(account, q, 3n);
normalizeMetadataCitationGovernanceWindow(window); assertMetadataCitationGovernanceWindow(window, 0n);
const batch: MetadataCitationGovernanceBatch = metadataCitationGovernanceBatch(plan, 0n, window);
normalizeMetadataCitationGovernanceBatch(batch);
void citation; void analysisRoundtrip; void goldenRoundtrip; void recordRoundtrip; void targetHash; void readHash;
void unverified; void classOne; void jsonCall; void htmlCall;

// @ts-expect-error display coordinates preserve exact fullwidth integer values
metadataWorkCitation(1, account, 1n);
// @ts-expect-error global token ID cannot be replaced by an untyped decimal string
metadataWorkCitation(1n, account, "1");
// @ts-expect-error supplied coordinates need the actual Schema runtime pin
normalizeMetadataCitationCoordinates({ chainId: 1n, registry: account, schemaRegistry: account, governanceExecutor: account });
// @ts-expect-error factsVerified is not a supplied snapshot authority flag
normalizeMetadataCitationSnapshot({ ...s, factsVerified: true });
// @ts-expect-error original CurrentRegistration has no renderer or Core substitution field
normalizeMetadataCitationRegistration({ ...r, renderer: account });
// @ts-expect-error CurrentAnalysis passed is a bool, not a truthy integer
normalizeMetadataCitationAnalysis({ ...analysis, passed: 1n });
// @ts-expect-error Solidity uint8 stays bigint even where not an enum
normalizeMetadataCitationRenderRequest({ ...q, collectionSupplyMode: 1 });
// @ts-expect-error metadata state is an original numeric field
normalizeMetadataCitationRenderRequest({ ...q, state: "active" });
// @ts-expect-error original read uint16 index remains bigint
normalizeMetadataCitationReads([{ ...reads[0]!, targetIndex: 0 }]);
// @ts-expect-error exact-return property is a bool
normalizeMetadataCitationReads([{ ...reads[0]!, exact: 1n }]);
// @ts-expect-error target pins cannot be abbreviated to address-only declarations
normalizeMetadataCitationTargets([{ target: account }]);
// @ts-expect-error mode3 HTML exists on renderer but is outside current golden admission
normalizeMetadataCitationGoldenVectors([{ request: q, mode: 3n, outputHash: hash }]);
// @ts-expect-error current golden vector includes its explicit mode (old golden schema is distinct)
encodeMetadataCitationGoldenVectors([{ request: q, outputHash: hash }]);
// @ts-expect-error generic current renderer modes remain original0..3 only
prepareMetadataCitationRenderCall(account, q, 4n);
// @ts-expect-error supplied outputs are commitments, not inferred strings from a renderer
validateMetadataCitationEvidence(plan, analysis, [{ request: q, mode: 0n, output: "json" }]);
// @ts-expect-error canonical decoding requires bytes, not decoded caller objects
decodeMetadataCitationAnalysis(analysis);
// @ts-expect-error action class is fixed to original class1
normalizeMetadataCitationPlan({ ...plan, actionClass: 2n });
// @ts-expect-error immutable supplied facts never upgrade themselves to verification
normalizeMetadataCitationPlan({ ...plan, factsVerified: true });
// @ts-expect-error exact Governance nonce is bigint
metadataCitationGovernanceBatch(plan, 0, window);
// @ts-expect-error scheduling timestamp is explicit bigint
assertMetadataCitationGovernanceWindow(window, 1);
// @ts-expect-error uint64 dates remain bigint
normalizeMetadataCitationGovernanceWindow({ ...window, expiresAfter: 100 });
// @ts-expect-error read roster is immutable
plan.reads.push(reads[0]!);
// @ts-expect-error nested runtime pins cannot mutate after planning
plan.snapshot.targets[0]!.codeHash = hash;
// @ts-expect-error independently supplied golden requests are frozen in the result
evidence.goldens[0]!.request.core = account;
// @ts-expect-error governance transport is immutable
batch.executionCall.data = hash;
