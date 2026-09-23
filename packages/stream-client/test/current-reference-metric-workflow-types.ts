import type { Address, Hex } from "../src/generated/contracts.js";
import type {
  ReferenceMetricOriginalContext,
  ReferenceMetricSupplement,
} from "../src/current-reference-metric.js";
import {
  inspectCurrentReferenceMetricSupplement,
  inspectReferenceMetricChunkAvailability,
  prepareReferenceMetricSupplementPlan,
  simulateReferenceMetricChunkUpload,
  simulateReferenceMetricSupplementPublication,
} from "../src/current-reference-metric-workflow.js";

declare const address: Address;
declare const hash: Hex;
declare const original: ReferenceMetricOriginalContext;
declare const supplement: ReferenceMetricSupplement;

const plan = prepareReferenceMetricSupplementPlan(
  1n,
  address,
  address,
  address,
  address,
  address,
  { collectionId: 1n, revision: 1n },
  original,
  supplement,
  1n,
);

declare const chunkProvider: Parameters<typeof inspectReferenceMetricChunkAvailability>[0];
declare const publicationProvider: Parameters<typeof simulateReferenceMetricSupplementPublication>[0];
declare const currentProvider: Parameters<typeof inspectCurrentReferenceMetricSupplement>[0];

inspectReferenceMetricChunkAvailability(chunkProvider, plan, { blockTag: 1 });
simulateReferenceMetricChunkUpload(chunkProvider, plan, 0, { blockTag: 1 });
simulateReferenceMetricSupplementPublication(publicationProvider, plan, { blockTag: 1 });
inspectCurrentReferenceMetricSupplement(
  currentProvider,
  plan,
  { recorder: address, authorizationClass: 3n, grantRevision: 1n },
  { blockTag: 1 },
);

prepareReferenceMetricSupplementPlan(1n, address, address, address, address, address,
  {
    // @ts-expect-error locator identities are exact bigints
    collectionId: 1,
    revision: 1n,
  }, original, supplement, 1n);
// @ts-expect-error chunk index is a number into an in-memory plan
simulateReferenceMetricChunkUpload(chunkProvider, plan, 0n, { blockTag: 1 });
