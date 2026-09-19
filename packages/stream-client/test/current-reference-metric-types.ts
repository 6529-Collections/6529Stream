import type { Address, Hex } from "../src/generated/contracts.js";
import {
  decodeReferenceMetricSupplement,
  decodeReferenceMetricTranscript,
  encodeReferenceMetricSupplement,
  referenceMetricImplementationIndex,
  referenceMetricInputManifest,
  referenceMetricPayloadHash,
  referenceMetricReplayHash,
  referenceMetricRuntimeHash,
  referenceMetricSupplementChunks,
  referenceMetricSupplementHash,
  referenceMetricTranscriptBytes,
  validateReferenceMetricReceipt,
  validateReferenceMetricSupplement,
  type ReferenceMetricAuthority,
  type ReferenceMetricCanonicalSupplement,
  type ReferenceMetricOriginalContext,
  type ReferenceMetricReceipt,
  type ReferenceMetricReceiptCoordinates,
  type ReferenceMetricSupplement,
  type ReferenceMetricTranscript,
} from "../src/current-reference-metric.js";

declare const address: Address;
declare const hash: Hex;
declare const supplement: ReferenceMetricSupplement;
declare const original: ReferenceMetricOriginalContext;
declare const transcript: ReferenceMetricTranscript;
declare const canonical: ReferenceMetricCanonicalSupplement;
declare const receipt: ReferenceMetricReceipt;
declare const coordinates: ReferenceMetricReceiptCoordinates;
declare const authority: ReferenceMetricAuthority;

const bytes = encodeReferenceMetricSupplement(supplement);
decodeReferenceMetricSupplement(bytes);
referenceMetricImplementationIndex(supplement.sources);
referenceMetricInputManifest(original);
referenceMetricTranscriptBytes(transcript);
decodeReferenceMetricTranscript(supplement.replay.transcript);
referenceMetricRuntimeHash(supplement.runtime);
referenceMetricReplayHash(supplement.replay);
referenceMetricPayloadHash(supplement);
referenceMetricSupplementChunks(bytes);
validateReferenceMetricSupplement(original, supplement, 1n);
referenceMetricSupplementHash(coordinates, receipt);
validateReferenceMetricReceipt(coordinates, canonical, receipt, authority);

const typedCoordinates: ReferenceMetricReceiptCoordinates = {
  chainId: 1n,
  producer: address,
  core: address,
  metadata: address,
  referenceRecordHash: hash,
};
void typedCoordinates;

// @ts-expect-error timestamps remain bigint at the public boundary
validateReferenceMetricSupplement(original, supplement, 1);
// @ts-expect-error source content is byte Hex rather than Uint8Array
encodeReferenceMetricSupplement({ ...supplement, parameters: new Uint8Array() });
