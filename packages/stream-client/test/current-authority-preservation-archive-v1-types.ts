import type { Address, Hex } from "../src/generated/contracts.js";
import {
  type CurrentAuthorityPreservationArchiveV1Coordinates,
  type CurrentAuthorityPreservationArchiveV1Dependencies,
  type CurrentAuthorityPreservationArchiveV1OriginDependencies,
  type CurrentAuthorityPreservationArchiveV1AuthorityDependencies,
  type CurrentAuthorityPreservationArchiveV1AuthorityCapture,
  type CurrentAuthorityPreservationArchiveV1Item,
  type CurrentAuthorityPreservationArchiveV1Proof,
  type CurrentAuthorityPreservationArchiveV1Admission,
  type CurrentAuthorityPreservationArchiveV1Request,
  type CurrentAuthorityPreservationArchiveV1CollectionEvidence,
  type CurrentAuthorityPreservationArchiveV1ScopedEvidence,
  type CurrentAuthorityPreservationArchiveV1HistoryInput,
  type CurrentAuthorityPreservationArchiveV1CurrentPair,
  type CurrentAuthorityPreservationArchiveV1Refresh,
  prepareCurrentAuthorityPreservationArchiveV1Call,
  normalizeCurrentAuthorityPreservationArchiveV1Call,
  prepareCurrentAuthorityPreservationArchiveV1Read,
  currentAuthorityPreservationArchiveV1DependencyHash,
  currentAuthorityPreservationArchiveV1EnvironmentHash,
  currentAuthorityPreservationArchiveV1CurrentObservation,
  validateCurrentAuthorityPreservationArchiveV1RefreshStep,
  authenticateCurrentAuthorityPreservationArchiveV1History,
} from "../src/current-authority-preservation-archive-v1.js";

declare const address: Address;
declare const hash: Hex;
declare const coordinates: CurrentAuthorityPreservationArchiveV1Coordinates;
declare const dependencies: CurrentAuthorityPreservationArchiveV1Dependencies;
declare const originDependencies: CurrentAuthorityPreservationArchiveV1OriginDependencies;
declare const authorityDependencies: CurrentAuthorityPreservationArchiveV1AuthorityDependencies;
declare const capture: CurrentAuthorityPreservationArchiveV1AuthorityCapture;
declare const item: CurrentAuthorityPreservationArchiveV1Item;
declare const proof: CurrentAuthorityPreservationArchiveV1Proof;
declare const admission: CurrentAuthorityPreservationArchiveV1Admission;
declare const pair: CurrentAuthorityPreservationArchiveV1CurrentPair;
declare const history: CurrentAuthorityPreservationArchiveV1HistoryInput;
declare const collection: CurrentAuthorityPreservationArchiveV1CollectionEvidence;
declare const scoped: CurrentAuthorityPreservationArchiveV1ScopedEvidence;
declare const refresh: CurrentAuthorityPreservationArchiveV1Refresh;

const requests = [
  { kind: "beginCoverage", id: hash },
  { kind: "coverNext", id: hash, item, nextLink: hash, proof },
  { kind: "coverEmptySegment", id: hash },
  { kind: "beginRefresh", id: hash },
  { kind: "refreshNext", id: hash, expectedIndex: 0n },
] as const satisfies readonly CurrentAuthorityPreservationArchiveV1Request[];
for (const scopeKind of ["collection", "scoped"] as const) {
  for (const request of requests) {
    const result = prepareCurrentAuthorityPreservationArchiveV1Call({ ...coordinates, scopeKind }, address, request);
    const unverified: false = result.factsVerified;
    normalizeCurrentAuthorityPreservationArchiveV1Call(result);
    void unverified;
  }
}
currentAuthorityPreservationArchiveV1DependencyHash("collection", dependencies, originDependencies, authorityDependencies);
currentAuthorityPreservationArchiveV1EnvironmentHash(hash, authorityDependencies, capture);
currentAuthorityPreservationArchiveV1CurrentObservation(hash, item, admission, pair);
currentAuthorityPreservationArchiveV1CurrentObservation(hash, item, admission, admission);
validateCurrentAuthorityPreservationArchiveV1RefreshStep("scoped", refresh, refresh, 0n, 1n, hash, hash);
const retained = authenticateCurrentAuthorityPreservationArchiveV1History(history);
const privateChainNotReconstructed: false = retained.initialObservationChainIndependentlyReconstructed;
const count: bigint = collection.itemCount;
const sameCount: bigint = scoped.coverage.itemCount;
void privateChainNotReconstructed; void count; void sameCount;
prepareCurrentAuthorityPreservationArchiveV1Read(coordinates, address, { kind: "admittedOriginHash", id: hash, index: 0n });
prepareCurrentAuthorityPreservationArchiveV1Read({ ...coordinates, scopeKind: "collection" }, address, { kind: "requireCoverage", id: hash, expectedHash: hash });
prepareCurrentAuthorityPreservationArchiveV1Read({ ...coordinates, scopeKind: "scoped" }, address,
  { kind: "requireCoverage", id: hash, expectedHash: hash, scope: scoped.scope });

// @ts-expect-error Caller-selected profile families are outside the closed host coordinates.
const arbitrary: CurrentAuthorityPreservationArchiveV1Coordinates = { ...coordinates, scopeKind: "view" };
// @ts-expect-error Archive methods do not include inventory or governance writes.
prepareCurrentAuthorityPreservationArchiveV1Call(coordinates, address, { kind: "sealInventory", id: hash });
// @ts-expect-error refreshNext requires the explicit original optimistic index.
prepareCurrentAuthorityPreservationArchiveV1Call(coordinates, address, { kind: "refreshNext", id: hash });
// @ts-expect-error ABI uint64 fields use bigint, not number.
prepareCurrentAuthorityPreservationArchiveV1Call(coordinates, address, { kind: "refreshNext", id: hash, expectedIndex: 0 });
// @ts-expect-error Structural Proof is a required three-field value.
const missingProof: CurrentAuthorityPreservationArchiveV1Proof = { backend: 0n, coverageHash: hash };
// @ts-expect-error The archive has no arbitrary wallet transaction request.
prepareCurrentAuthorityPreservationArchiveV1Call(coordinates, address, { kind: "execute", to: address, data: hash });
// @ts-expect-error Dependency rosters are readonly tuples.
dependencies.targets[0] = address;
// @ts-expect-error Nested original authority observations are immutable.
capture.selection.origin.environment.owners[0] = address;
// @ts-expect-error Retained row collections are readonly.
history.rows.push({ item, admission, originHash: hash, recordOrigin: null });
// @ts-expect-error Retained admissions are deeply readonly.
history.rows[0]!.admission.externalOriginal.firstReceiptHash = hash;
// @ts-expect-error Collection evidence has no scoped wrapper.
collection.scope;
// @ts-expect-error Scoped evidence retains its nested coverage tuple.
scoped.itemCount;
void arbitrary; void missingProof;
