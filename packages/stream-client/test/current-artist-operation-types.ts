import type { Address, Hex } from "../src/generated/contracts.js";
import { currentArtistOperationTypedData, normalizeCurrentArtistAction, normalizeCurrentArtistOperationRequest,
  prepareCurrentArtistAction, type CurrentArtistOperationRequest, type CurrentArtistContentFreeze,
  type CurrentArtistSaleConsent, type PreparedCurrentArtistAction } from "../src/current-artist-operation.js";

declare const address: Address;
declare const hash: Hex;
declare const content: CurrentArtistContentFreeze;
declare const sale: CurrentArtistSaleConsent;
const request: CurrentArtistOperationRequest<"contentFreeze"> = {
  kind: "contentFreeze", chainId: 1n, registry: address, caller: address, signer: address, artistId: hash,
  mode: "signature", signature: "0x", message: content, details: {},
};
const plan: PreparedCurrentArtistAction<"contentFreeze"> = prepareCurrentArtistAction(request);
const operationId: bigint = plan.operationId;
const classes: readonly Hex[] = plan.payload.message.lockClasses;
const normalized: CurrentArtistOperationRequest<"contentFreeze"> = normalizeCurrentArtistOperationRequest(request);
normalizeCurrentArtistAction(plan);
currentArtistOperationTypedData("saleConsent", 1n, address, sale);
void operationId; void classes; void normalized;

// @ts-expect-error messages remain correlated with the selected original schema
currentArtistOperationTypedData("contentFreeze", 1n, address, sale);
// @ts-expect-error exact uint256 chain ID is bigint
currentArtistOperationTypedData("saleConsent", 1, address, sale);
// @ts-expect-error nonce is a uint256 bigint
currentArtistOperationTypedData("saleConsent", 1n, address, { ...sale, nonce: 2 });
// @ts-expect-error supplemental URI is not part of the content signature
currentArtistOperationTypedData("contentFreeze", 1n, address, { ...content, reasonURI: "" });
// @ts-expect-error no unsigned supplemental URI belongs to content-freeze calldata
prepareCurrentArtistAction({ ...request, details: { reasonURI: "" } });
// @ts-expect-error old ceremony's relayed spelling is not a lane here
prepareCurrentArtistAction({ ...request, mode: "relayed" });
// @ts-expect-error one opaque byte string, not signature-kind objects
prepareCurrentArtistAction({ ...request, signature: { kind: "erc1271", value: "0x" } });
// @ts-expect-error original principal variants are explicit; delegated variants are separate
prepareCurrentArtistAction({ ...request, kind: "delegatedRoyaltyFreeze" });
// @ts-expect-error call-bound caller is required
prepareCurrentArtistAction({ kind: "contentFreeze", chainId: 1n, registry: address, signer: address, artistId: hash, mode: "direct", signature: "0x", message: content, details: {} });
// @ts-expect-error normalized nested arrays are immutable
plan.payload.message.lockClasses.push(hash);
// @ts-expect-error reviewed execution coordinates are immutable
plan.request.caller = address;
// @ts-expect-error prepared calldata is immutable
plan.call.data = hash;
// @ts-expect-error full requests retain the discriminator/message association
const wrong: CurrentArtistOperationRequest = { ...request, message: sale };
void wrong;
