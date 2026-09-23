import type { Address, Hex } from "../src/generated/contracts.js";
import {
  type CurrentViewRetrievalV1Coordinates,
  type CurrentViewRetrievalV1Configuration,
  type CurrentViewRetrievalV1Request,
  type CurrentViewRetrievalV1Observation,
  type CurrentViewRetrievalV1Source,
  type CurrentViewRetrievalV1Receipt,
  type CurrentViewRetrievalV1Admission,
  type CurrentViewRetrievalV1CurrentPair,
  type CurrentViewRetrievalV1CallRequest,
  type CurrentViewRetrievalV1ReadRequest,
  type CurrentViewRetrievalV1ManifestEvidence,
  type CurrentViewRetrievalV1TransactionEvidence,
  type CurrentViewRetrievalV1WriterEvidence,
  type CurrentViewRetrievalV1SignatureRoute,
  prepareCurrentViewRetrievalV1Call,
  prepareCurrentViewRetrievalV1Read,
  normalizeCurrentViewRetrievalV1Call,
  normalizeCurrentViewRetrievalV1Read,
  normalizeCurrentViewRetrievalV1Observation,
  currentViewRetrievalV1ConfigurationHash,
  currentViewRetrievalV1SourceKey,
  currentViewRetrievalV1Digest,
  currentViewRetrievalV1NonceKey,
  currentViewRetrievalV1ScopeKey,
  currentViewRetrievalV1Payload,
  decodeCurrentViewRetrievalV1Payload,
  currentViewRetrievalV1Chunks,
  currentViewRetrievalV1RecordHash,
  currentViewRetrievalV1PreviewReceipt,
  authenticateCurrentViewRetrievalV1History,
  validateCurrentViewRetrievalV1Prepared,
  validateCurrentViewRetrievalV1ArchiveAdmission,
  validateCurrentViewRetrievalV1CurrentPair,
  validateCurrentViewRetrievalV1WriterEvidence,
  validateCurrentViewRetrievalV1RouteEvidence,
  validateCurrentViewRetrievalV1Revocation,
  currentViewRetrievalV1SignatureRoute,
  validateCurrentViewRetrievalV1ERC1271Result,
} from "../src/current-view-retrieval-v1.js";

declare const c: CurrentViewRetrievalV1Coordinates;
declare const d: CurrentViewRetrievalV1Configuration;
declare const request: CurrentViewRetrievalV1Request;
declare const o: CurrentViewRetrievalV1Observation;
declare const source: CurrentViewRetrievalV1Source;
declare const receipt: CurrentViewRetrievalV1Receipt;
declare const admission: CurrentViewRetrievalV1Admission;
declare const pair: CurrentViewRetrievalV1CurrentPair;
declare const caller: Address;
declare const signature: Hex;
declare const payload: Hex;
declare const hash: Hex;
declare const writerCode: Hex;
declare const manifestEvidence: readonly CurrentViewRetrievalV1ManifestEvidence[];
declare const finalTransaction: CurrentViewRetrievalV1TransactionEvidence;
declare const writerEvidence: CurrentViewRetrievalV1WriterEvidence;

const writes: readonly CurrentViewRetrievalV1CallRequest[] = [
  { kind: "publish", request, signature },
  { kind: "revoke", recordHash: receipt.recordHash, reasonHash: hash },
];
for (const input of writes) {
  const plan = prepareCurrentViewRetrievalV1Call(c, caller, input);
  const target: Address = plan.call.to;
  const data: Hex = plan.call.data;
  const value: bigint = plan.call.value;
  const unverified: false = plan.factsVerified;
  normalizeCurrentViewRetrievalV1Call(plan);
  void [target, data, value, unverified];
}
const reads: readonly CurrentViewRetrievalV1ReadRequest[] = [
  { kind: "configuration" }, { kind: "configurationHash" }, { kind: "retrievalProfile" },
  { kind: "supportsInterface", interfaceId: "0x01ffc9a7" },
  { kind: "prepare", request },
  { kind: "record", recordHash: hash }, { kind: "encoded", recordHash: hash },
  { kind: "requireCurrent", recordHash: hash }, { kind: "requireCorrespondence", recordHash: hash },
  { kind: "revoked", recordHash: hash }, { kind: "revocationEpoch", scope: source.scope },
  { kind: "nonceUsed", nonceKey: currentViewRetrievalV1NonceKey(o.writer, 0n) },
];
for (const input of reads) normalizeCurrentViewRetrievalV1Read(prepareCurrentViewRetrievalV1Read(c, caller, input));

const digest: Hex = currentViewRetrievalV1Digest(c, d, o);
const hashes: readonly Hex[] = [currentViewRetrievalV1ConfigurationHash(d), currentViewRetrievalV1SourceKey(source),
  currentViewRetrievalV1ScopeKey(source.scope), currentViewRetrievalV1RecordHash(c, d, receipt)];
const canonical: Hex = currentViewRetrievalV1Payload(o, signature);
const decoded: CurrentViewRetrievalV1Observation = decodeCurrentViewRetrievalV1Payload(canonical).observation;
const projected: CurrentViewRetrievalV1Receipt = currentViewRetrievalV1PreviewReceipt(c, d, o, signature, 20n);
const history = authenticateCurrentViewRetrievalV1History(c, d, projected, canonical);
const noCurrentness: false = history.currentnessVerified;
const noFreshSignature: false = history.signatureVerified;
validateCurrentViewRetrievalV1Prepared(c, d, request, o, digest, { timestamp: 20n, adoptedAt: 10n, institutionalObservedAt: 11n });
validateCurrentViewRetrievalV1ArchiveAdmission(o, admission);
validateCurrentViewRetrievalV1CurrentPair(o.coverage, pair);
const derived = validateCurrentViewRetrievalV1WriterEvidence(d, o.coverage, writerEvidence);
const noAdmission: false = derived.originalAdmissionVerified;
validateCurrentViewRetrievalV1RouteEvidence(d, o, manifestEvidence, finalTransaction);
validateCurrentViewRetrievalV1RouteEvidence(d, o, [], null);
validateCurrentViewRetrievalV1Revocation(caller, receipt, hash, false, 0n);
const route: CurrentViewRetrievalV1SignatureRoute = currentViewRetrievalV1SignatureRoute(caller, o.writer, digest, signature, writerCode);
const noRuntime: false = route.runtimeVerified;
if (route.requiresContractValidation) validateCurrentViewRetrievalV1ERC1271Result(true, payload);
for (const chunk of currentViewRetrievalV1Chunks(canonical)) {
  const data: Hex = chunk.data;
  const index: bigint = chunk.index;
  void [data, index];
}
void [hashes, decoded, noCurrentness, noFreshSignature, noAdmission, noRuntime];

// @ts-expect-error Immutable configuration.
d.archive = caller;
// @ts-expect-error Deep immutable scope.
source.scope.scopeId = hash;
// @ts-expect-error Deep immutable route array.
o.steps.push(o.steps[0]!);
// @ts-expect-error Deep immutable step.
o.steps[0]!.manifestBytes = payload;
// @ts-expect-error Original ABI numeric values use bigint.
normalizeCurrentViewRetrievalV1Observation({ ...o, nonce: 0 });
// @ts-expect-error Publisher cannot substitute the derived writer into original Request.
const extraWriter: CurrentViewRetrievalV1Request = { ...request, writer: caller };
// @ts-expect-error Scope epoch is local; no external coordinates in revoke.
prepareCurrentViewRetrievalV1Call(c, caller, { kind: "revoke", recordHash: hash, reasonHash: hash, scope: source.scope });
// @ts-expect-error Revoke has no relayed signature.
prepareCurrentViewRetrievalV1Call(c, caller, { kind: "revoke", recordHash: hash, reasonHash: hash, signature });
// @ts-expect-error Publish requires the original Request object and signature bytes.
prepareCurrentViewRetrievalV1Call(c, caller, { kind: "publish", observation: o, signature });
// @ts-expect-error Consumer write is outside the bounded witness client.
prepareCurrentViewRetrievalV1Call(c, caller, { kind: "coverRetrievalNext", witnessHash: hash });
// @ts-expect-error No inherited EIP712 endpoint.
prepareCurrentViewRetrievalV1Read(c, caller, { kind: "eip712Domain" });
// @ts-expect-error Write method is not a read request.
prepareCurrentViewRetrievalV1Read(c, caller, { kind: "revoke", recordHash: hash, reasonHash: hash });
// @ts-expect-error Read method is not a wallet mutation.
prepareCurrentViewRetrievalV1Call(c, caller, { kind: "prepare", request });
// @ts-expect-error Original request nonce is required and may be zero.
const missingNonce: CurrentViewRetrievalV1Request = { scope: source.scope, coverageHash: hash, steps: [], resolvedURI: "https://x", observedAt: 1n, deadline: 2n };
void [extraWriter, missingNonce];
