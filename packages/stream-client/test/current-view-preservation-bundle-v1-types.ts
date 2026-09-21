import type { Address, Hex } from "../src/generated/contracts.js";
import {
  prepareCurrentViewPreservationBundleV1Call,
  prepareCurrentViewPreservationBundleV1Read,
  currentViewPreservationBundleV1Evidence,
  currentViewPreservationBundleV1RefreshStep,
  currentViewPreservationBundleV1CurrentRoute,
  validateCurrentViewPreservationBundleV1RetainedAdmission,
  authenticateCurrentViewPreservationBundleV1History,
  type CurrentViewPreservationBundleV1Coordinates,
  type CurrentViewPreservationBundleV1Dependencies,
  type CurrentViewPreservationBundleV1Request,
  type CurrentViewPreservationBundleV1Item,
  type CurrentViewPreservationBundleV1Proof,
  type CurrentViewPreservationBundleV1Admission,
  type CurrentViewPreservationBundleV1Evidence,
  type CurrentViewPreservationBundleV1InventoryEvidence,
  type CurrentViewPreservationBundleV1Refresh,
  type CurrentViewPreservationBundleV1StoredItem,
  type CurrentViewPreservationBundleV1Segment,
} from "../src/current-view-preservation-bundle-v1.js";

declare const c: CurrentViewPreservationBundleV1Coordinates;
declare const d: CurrentViewPreservationBundleV1Dependencies;
declare const actor: Address;
declare const key: Hex;
declare const item: CurrentViewPreservationBundleV1Item;
declare const proof: CurrentViewPreservationBundleV1Proof;
declare const admission: CurrentViewPreservationBundleV1Admission;
declare const original: CurrentViewPreservationBundleV1InventoryEvidence;
declare const evidence: CurrentViewPreservationBundleV1Evidence;
declare const refresh: CurrentViewPreservationBundleV1Refresh;
declare const rows: readonly CurrentViewPreservationBundleV1StoredItem[];
declare const segments: readonly Readonly<{ segment: CurrentViewPreservationBundleV1Segment; items: readonly CurrentViewPreservationBundleV1Item[] }>[];
const requests: readonly CurrentViewPreservationBundleV1Request[] = [
  { method: "beginCoverage", id: key },
  { method: "coverNext", id: key, item, nextLink: key, proof },
  { method: "coverRetrievalNext", id: key, item, nextLink: key, witnessHash: key },
  { method: "coverEmptySegment", id: key },
  { method: "beginRefresh", id: key },
  { method: "refreshNext", id: key, expectedIndex: 0n },
];
for (const request of requests) prepareCurrentViewPreservationBundleV1Call(c, actor, request);
prepareCurrentViewPreservationBundleV1Read(c, { method: "retrievalWitnessForItem", id: key, index: 0n });
prepareCurrentViewPreservationBundleV1Read(c, { method: "requireCoverage", scope: original.scope, id: key, expectedHash: key });
const result = authenticateCurrentViewPreservationBundleV1History(c, d, key, original, evidence, segments, rows);
const noCurrent: false = result.currentnessVerified;
const noInitialPrivateChain: false = result.initialObservationIndependentlyReconstructed;
const noFreshCorrespondence: false = result.retrievalCorrespondenceIndependentlyReconstructed;
const route: "generic" | "retrieval" = currentViewPreservationBundleV1CurrentRoute(key);
currentViewPreservationBundleV1Evidence(c, key, original, key);
currentViewPreservationBundleV1RefreshStep(refresh, 0n, 1n, item, key);
validateCurrentViewPreservationBundleV1RetainedAdmission(original.inventory.artistId, item, admission, key);
void [noCurrent, noInitialPrivateChain, noFreshCorrespondence, route];

// @ts-expect-error Stored witness mapping and nested rows are immutable.
result.rows[0]!.witnessHash = key;
// @ts-expect-error Admission record is immutable.
admission.externalOriginal.artistId = key;
// @ts-expect-error Retrieval uses an explicit witness coordinate, not an Archive Proof.
prepareCurrentViewPreservationBundleV1Call(c, actor, { method: "coverRetrievalNext", id: key, item, nextLink: key, proof });
// @ts-expect-error Generic admission requires Proof, not a witness coordinate.
prepareCurrentViewPreservationBundleV1Call(c, actor, { method: "coverNext", id: key, item, nextLink: key, witnessHash: key });
// @ts-expect-error Refresh cursor uses exact bigint width.
prepareCurrentViewPreservationBundleV1Call(c, actor, { method: "refreshNext", id: key, expectedIndex: 0 });
// @ts-expect-error No nominal library mutation target is exposed.
prepareCurrentViewPreservationBundleV1Call(c, actor, { method: "admit", item, proof });
// @ts-expect-error Witness publication remains a separate original host.
prepareCurrentViewPreservationBundleV1Call(c, actor, { method: "publish", item, witnessHash: key });
