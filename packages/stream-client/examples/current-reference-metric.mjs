import { getAddress } from "ethers";
import {
  createSafeCallPlan,
  inspectCurrentReferenceMetricSupplement,
  inspectHistoricalReferenceMetricSupplement,
  inspectReferenceMetricPublicationReceipt,
  inspectReferenceMetricSupplementPublication,
  prepareReferenceMetricSupplementPlan,
  simulateReferenceMetricChunkUpload,
  simulateReferenceMetricSupplementPublication,
} from "../dist/index.js";

/** Offline preparation: supplied artifacts are data, never executable programs. */
export function prepareMetricExample({ deployment, writer, locator, original, supplement, maximumExecutedAt }) {
  return prepareReferenceMetricSupplementPlan(
    deployment.chainId, deployment.producer, deployment.store, deployment.core,
    deployment.metadata, writer, locator, original, supplement, maximumExecutedAt,
  );
}

/**
 * Keep permissionless uploads and writer publication as separate, ordered CALLs.
 * Supply both exact compiled ABIs; there are no addresses or provider defaults.
 */
export function prepareMetricSafeExample({ deployment, uploaderSafe, writerSafe, locator, original,
  supplement, maximumExecutedAt, storeAbi, publicationAbi }) {
  const input = { deployment, locator, original, supplement, maximumExecutedAt };
  const uploads = prepareMetricExample({ ...input, writer: getAddress(uploaderSafe) });
  const publication = prepareMetricExample({ ...input, writer: getAddress(writerSafe) });
  const abis = Object.freeze([...uploads.chunks.map(() => storeAbi), publicationAbi]);
  const safePlan = createSafeCallPlan(deployment.chainId, "Retain and publish reference metric supplement", [
    ...uploads.chunks.map(chunk => ({
      safe: uploads.caller,
      intent: `Retain metric chunk ${chunk.index + 1} of ${uploads.chunks.length}`,
      call: chunk.call,
      abi: storeAbi,
    })),
    { safe: publication.caller, intent: "Publish the original reference's metric supplement",
      call: publication.publication, abi: publicationAbi },
  ]);
  return Object.freeze({ uploads, publication, safePlan, abis });
}

/** Simulate one upload; a returned pointer does not mean it has been mined. */
export async function simulateMetricUploadExample({ provider, uploads, chunkIndex, blockTag }) {
  return simulateReferenceMetricChunkUpload(provider, uploads, chunkIndex, { blockTag });
}

/** Call only after uploads are mined. No submission, signing or automatic retry. */
export async function inspectMetricPublicationExample({ provider, publication, blockTag }) {
  const inspection = await inspectReferenceMetricSupplementPublication(provider, publication, { blockTag });
  const simulatedHash = await simulateReferenceMetricSupplementPublication(provider, inspection.plan, { blockTag });
  return Object.freeze({ chunks: inspection.chunks, inspection, simulatedHash });
}

/** Verify exact transaction/event evidence using the actual recording block. */
export async function verifyMetricPublicationExample({ provider, publication, evidence }) {
  return inspectReferenceMetricPublicationReceipt(provider, publication, evidence);
}

/** Historical retention and current eligibility are explicitly selected reads. */
export async function readMetricExample({ provider, publication, authority, blockTag, requireCurrent = false }) {
  return requireCurrent
    ? inspectCurrentReferenceMetricSupplement(provider, publication, authority, { blockTag })
    : inspectHistoricalReferenceMetricSupplement(provider, publication, authority, { blockTag });
}
