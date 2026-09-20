import type { Address, Hex } from "../src/generated/contracts.js";
import { currentArtistOperationTypedData, normalizeCurrentArtistAction, normalizeCurrentArtistOperationRequest,
  prepareCurrentArtistAction, type CurrentArtistOperationRequest, type CurrentArtistContentFreeze,
  type CurrentArtistSaleConsent, type PreparedCurrentArtistAction, type CurrentArtistIdentityRevision,
  type CurrentArtistDelegationGrant, type CurrentArtistDelegationRevocation } from "../src/current-artist-operation.js";

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

declare const revision: CurrentArtistIdentityRevision;
declare const grant: CurrentArtistDelegationGrant;
declare const revocation: CurrentArtistDelegationRevocation;
const revisionRequest: CurrentArtistOperationRequest<"identityRevision"> = {
  ...request, kind: "identityRevision", message: revision,
  details: { identityRecordURI: "ipfs://identity", document: hash, displayName: "Artist" },
};
const revisionPlan = prepareCurrentArtistAction(revisionRequest);
const signedAt: bigint = revisionPlan.payload.message.signedAt;
const grantPlan = prepareCurrentArtistAction({ ...request, kind: "delegationGrant", message: grant });
const maximum: bigint = grantPlan.payload.message.maxUses;
prepareCurrentArtistAction({ ...request, kind: "delegationRevocation", message: revocation });
void signedAt; void maximum;
// @ts-expect-error revision uses signedAt, never an added signed deadline
currentArtistOperationTypedData("identityRevision", 1n, address, { ...revision, deadline: 1n });
// @ts-expect-error revision uint64 signedAt remains bigint
currentArtistOperationTypedData("identityRevision", 1n, address, { ...revision, signedAt: 1 });
// @ts-expect-error grant's artist locator is not an original signed field
currentArtistOperationTypedData("delegationGrant", 1n, address, { ...grant, artistId: hash });
// @ts-expect-error grant's forced authorization time is not a signed field
currentArtistOperationTypedData("delegationGrant", 1n, address, { ...grant, time: 0n });
// @ts-expect-error original grant capabilities are exact uint32 bigint
currentArtistOperationTypedData("delegationGrant", 1n, address, { ...grant, capabilities: 117 });
// @ts-expect-error revision requires original document/URI/name supplemental data
prepareCurrentArtistAction({ ...revisionRequest, details: {} });
// @ts-expect-error document bytes are hex, not an uncommitted JavaScript byte array
prepareCurrentArtistAction({ ...revisionRequest, details: { ...revisionRequest.details, document: new Uint8Array() } });
// @ts-expect-error grant cannot carry a caller-supplied authorization time
prepareCurrentArtistAction({ ...request, kind: "delegationGrant", message: grant, details: { time: 1n } });
// @ts-expect-error revised supplementary text is immutable after preparation
revisionPlan.request.details.displayName = "changed";
// @ts-expect-error revocation's message differs from the three-field authorization revocation target
currentArtistOperationTypedData("delegationRevocation", 1n, address, { artistId: hash, revokedDigest: hash, revokedNonce: 0n, nonce: 1n, deadline: 1n });
