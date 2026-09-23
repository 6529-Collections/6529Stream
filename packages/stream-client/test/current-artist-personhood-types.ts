import { prepareArtistPersonhoodCall, prepareArtistPersonhoodRead, artistPersonhoodNativeRecordHash, type ArtistPersonhoodRequest } from "../src/current-artist-personhood.js";
import { createSafeCallPlan } from "../src/safe-plan.js";
import { CURRENT_ARTIST_PERSONHOOD_ABI } from "../src/current-artist-personhood.js";
import { inspectArtistPersonhood, type ArtistPersonhoodReader, type ArtistPersonhoodReadDeployment } from "../src/current-artist-personhood-workflow.js";
declare const request: ArtistPersonhoodRequest;
const prepared = prepareArtistPersonhoodCall(request);
artistPersonhoodNativeRecordHash(prepared, request.caller, 1n, 123n);
prepareArtistPersonhoodRead(request.registry, "personhoodEvidence", [request.collectionId, request.reference.artistId]);
createSafeCallPlan(request.chainId, "Personhood", [{ safe: request.caller, intent: "Original operation24", call: prepared.call, abi: CURRENT_ARTIST_PERSONHOOD_ABI }]);
// @ts-expect-error Protocol integers are bigint.
prepareArtistPersonhoodCall({ ...request, nonce: 1 });
// @ts-expect-error There is no new personhood mutation selector.
prepareArtistPersonhoodRead(request.registry, "setPersonhood", []);
// @ts-expect-error Fresh reference cannot omit its original Registry domain.
prepareArtistPersonhoodCall({ ...request, reference: { version: 1n } });
declare const provider: ArtistPersonhoodReader;
declare const deployment: ArtistPersonhoodReadDeployment;
inspectArtistPersonhood(provider, deployment, { method: "personhoodEvidence", collectionId: request.collectionId, artistId: request.reference.artistId }, { blockTag: 10, gasLimit: 500000n });
inspectArtistPersonhood(provider, deployment, { method: "auditPersonhoodEvidence", nativeRecordHash: request.reference.notarizationRecordHash }, { blockTag: 10, gasLimit: 500000n });
// @ts-expect-error An audit uses the original native record key, not a subject query.
inspectArtistPersonhood(provider, deployment, { method: "auditPersonhoodEvidence", collectionId: 1n, artistId: request.reference.artistId }, { blockTag: 10, gasLimit: 500000n });
