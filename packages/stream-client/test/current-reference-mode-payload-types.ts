import type { Address, Hex } from "../src/generated/contracts.js";
import { prepareReferenceModePublication, prepareReferenceModePayload, prepareReferenceModePublicationCall, prepareReferenceModePayloadCall,
  normalizeReferenceModePublication, normalizeReferenceModeReceipt, normalizeReferenceModeSourceFacts, normalizeReferenceModeEvidence,
  normalizeReferenceModeFacts, normalizeReferenceModePayloadInput, normalizeReferenceModePublicationSnapshot,
  normalizeReferenceModePayloadSnapshot, normalizeReferenceModePreparationCall, decodeReferenceModePayload,
  type ReferenceModePublication, type ReferenceModePayloadInput, type ReferenceModePublicationSnapshot,
  type ReferenceModePayloadSnapshot, type ReferenceModePreparationCall, type ReferenceModeKind } from "../src/current-reference-mode-payload.js";

declare const chain: bigint, host: Address, caller: Address, hash: Hex;
declare const publication: ReferenceModePublication, input: ReferenceModePayloadInput;
const p: ReferenceModePublicationSnapshot = prepareReferenceModePublication(chain, host, publication);
const s: ReferenceModePayloadSnapshot = prepareReferenceModePayload(p, input);
const call: ReferenceModePreparationCall = prepareReferenceModePayloadCall(s, caller);
const length: bigint = s.byteLength, kind: ReferenceModeKind = s.input.evidence.mode;
const raw: Hex = s.canonical, identity: Hex = p.publicationPreparationId;
prepareReferenceModePublicationCall(p, caller); normalizeReferenceModePublication(publication);
normalizeReferenceModeReceipt(input.receipt); normalizeReferenceModeSourceFacts(input.source);
normalizeReferenceModeEvidence(input.evidence); normalizeReferenceModeFacts(input.facts); normalizeReferenceModePayloadInput(input);
normalizeReferenceModePublicationSnapshot(p); normalizeReferenceModePayloadSnapshot(s); normalizeReferenceModePreparationCall(call);
decodeReferenceModePayload(chain, host, s.canonical);
void length; void kind; void raw; void identity;

// @ts-expect-error uint256 chain coordinates require exact bigint
prepareReferenceModePublication(1, host, publication);
// @ts-expect-error full original publication cannot be replaced by a hash
prepareReferenceModePublication(chain, host, hash);
// @ts-expect-error original uint64 revision is not a number
normalizeReferenceModePublication({ ...publication, expectedRevision: 1 });
// @ts-expect-error no caller-chosen preparation ID in original Publication
normalizeReferenceModePublication({ ...publication, publicationPreparationId: hash });
// @ts-expect-error full arrays remain required even if the application only stores a projection
normalizeReferenceModePublication({ ...publication, captures: [{ tokenId: 1n }] });
// @ts-expect-error fixed original repeat pair has exactly two hashes
normalizeReferenceModePublication({ ...publication, captures: [{ ...publication.captures[0]!, repeatCaptureSha256: [hash] }] });
// @ts-expect-error a separate signature is not part of preparation calldata
prepareReferenceModePayload(p, { ...input, signature: hash });
// @ts-expect-error full supplied facts are required; a preparation ID is not a replacement
prepareReferenceModePayload(p, hash);
// @ts-expect-error original Mode enum is bounded
normalizeReferenceModeEvidence({ ...input.evidence, mode: 3n });
// @ts-expect-error signed int64 threshold requires exact bigint
normalizeReferenceModeEvidence({ ...input.evidence, perceptual: { ...input.evidence.perceptual, threshold: 1 } });
// @ts-expect-error signed scores also require bigint
normalizeReferenceModeEvidence({ ...input.evidence, perceptual: { ...input.evidence.perceptual, scores: [1] } });
// @ts-expect-error nested original statement origin enum is bounded
normalizeReferenceModeEvidence({ ...input.evidence, curated: { ...input.evidence.curated, intent: { ...input.evidence.curated.intent, artist: { ...input.evidence.curated.intent.artist, origin: 2n } } } });
// @ts-expect-error uint8 receipt authorization class remains bigint
normalizeReferenceModeReceipt({ ...input.receipt, authorizationClass: 3 });
// @ts-expect-error no publication transaction helper in the permissionless call union
normalizeReferenceModePreparationCall({ ...call, kind: "publish" });
// @ts-expect-error original publication snapshot and payload snapshot are distinct
prepareReferenceModePayloadCall(p, caller);
// @ts-expect-error explicit caller is required
prepareReferenceModePublicationCall(p);
// @ts-expect-error nested original arrays are immutable
s.input.evidence.curated.properties.push({ id: hash, name: "property", significantValue: "value" });
// @ts-expect-error normalized retained recorder remains immutable
s.input.receipt.recorder = caller;
// @ts-expect-error prepared ID labels cannot be replaced after review
p.publicationPreparationId = hash;
// @ts-expect-error no authority or finality assertion is returned
s.authorized = true;
