import type { Address, Hex } from "../src/generated/contracts.js";
import { currentArtistOperationTypedData, normalizeCurrentArtistAction, normalizeCurrentArtistOperationRequest,
  prepareCurrentArtistAction, type CurrentArtistOperationRequest, type CurrentArtistContentFreeze,
  type CurrentArtistSaleConsent, type PreparedCurrentArtistAction, type CurrentArtistIdentityRevision,
  type CurrentArtistDelegationGrant, type CurrentArtistDelegationRevocation,
  type CurrentArtistDelegatedPolicyConsent, type CurrentArtistDelegatedSaleConsent,
  type CurrentArtistDelegatedEconomicsConsent, type CurrentArtistDelegatedRoyaltyFreeze,
  type CurrentArtistFixedEconomicsCandidate } from "../src/current-artist-operation.js";

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
// @ts-expect-error unimplemented operation variants are not guessed from their schema name
prepareCurrentArtistAction({ ...request, kind: "unsupportedArtistOperation" });
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

declare const delegatedPolicy: CurrentArtistDelegatedPolicyConsent;
const delegatedSale: CurrentArtistDelegatedSaleConsent = sale;
const delegatedPolicyRequest: CurrentArtistOperationRequest<"delegatedPolicyConsent"> = {
  ...request, kind: "delegatedPolicyConsent", message: delegatedPolicy, details: { grant: hash },
};
const policyPlan = prepareCurrentArtistAction(delegatedPolicyRequest);
const policyManager: Address = policyPlan.payload.message.mintManager;
const grantHash: Hex = policyPlan.request.details.grant;
prepareCurrentArtistAction({ ...request, kind: "delegatedSaleConsent", message: delegatedSale, details: { grant: hash } });
void policyManager; void grantHash;
// @ts-expect-error a grant is required to select the delegated public variant
prepareCurrentArtistAction({ ...delegatedPolicyRequest, details: {} });
// @ts-expect-error delegation does not introduce a signed grant field
currentArtistOperationTypedData("delegatedPolicyConsent", 1n, address, { ...delegatedPolicy, grant: hash });
// @ts-expect-error original sale schema is not the policy schema
currentArtistOperationTypedData("delegatedPolicyConsent", 1n, address, delegatedSale);
// @ts-expect-error original policy schema is not the sale schema
currentArtistOperationTypedData("delegatedSaleConsent", 1n, address, delegatedPolicy);
// @ts-expect-error scope mode is not an extra signed sale field
currentArtistOperationTypedData("delegatedSaleConsent", 1n, address, { ...delegatedSale, consentMode: 2n });
// @ts-expect-error grant details do not carry unverified authorization capabilities
prepareCurrentArtistAction({ ...delegatedPolicyRequest, details: { grant: hash, capabilities: 2n } });
// @ts-expect-error the reviewed grant selection is immutable
policyPlan.request.details.grant = hash;

declare const delegatedEconomics: CurrentArtistDelegatedEconomicsConsent;
declare const delegatedFreeze: CurrentArtistDelegatedRoyaltyFreeze;
const candidate: CurrentArtistFixedEconomicsCandidate = { profileHash: hash, policyHash: hash, royaltyBps: 0n, frozen: false };
const economicsRequest: CurrentArtistOperationRequest<"delegatedEconomicsConsent"> = {
  ...request, kind: "delegatedEconomicsConsent", message: delegatedEconomics, details: { collectionId: 1n, grant: hash },
};
const prospectiveRequest: CurrentArtistOperationRequest<"delegatedProspectiveEconomicsConsent"> = {
  ...request, kind: "delegatedProspectiveEconomicsConsent", message: delegatedEconomics,
  details: { collectionId: 1n, grant: hash, candidate },
};
const economicsPlan = prepareCurrentArtistAction(economicsRequest);
const prospectivePlan = prepareCurrentArtistAction(prospectiveRequest);
const fixed: CurrentArtistFixedEconomicsCandidate = prospectivePlan.request.details.candidate;
const royaltyBps: bigint = prospectivePlan.request.details.candidate.royaltyBps;
const scopeId: bigint = economicsPlan.payload.message.scopeId;
prepareCurrentArtistAction({ ...request, kind: "delegatedRoyaltyFreeze", message: delegatedFreeze, details: { grant: hash } });
currentArtistOperationTypedData("delegatedProspectiveEconomicsConsent", 1n, address, delegatedEconomics);
void fixed; void royaltyBps; void scopeId;
// @ts-expect-error collection context is not a field in the original signed economics schema
currentArtistOperationTypedData("delegatedEconomicsConsent", 1n, address, { ...delegatedEconomics, collectionId: 1n });
// @ts-expect-error the original fixed candidate is supplemental rather than EIP-712 input
currentArtistOperationTypedData("delegatedProspectiveEconomicsConsent", 1n, address, { ...delegatedEconomics, candidate });
// @ts-expect-error current assignment consent has no prospective candidate tuple
prepareCurrentArtistAction({ ...economicsRequest, details: { ...economicsRequest.details, candidate } });
// @ts-expect-error prospective fixed consent requires its candidate for exact calldata reconstruction
prepareCurrentArtistAction({ ...prospectiveRequest, details: { collectionId: 1n, grant: hash } });
// @ts-expect-error supplemental collection coordinates are uint256 bigints
prepareCurrentArtistAction({ ...economicsRequest, details: { collectionId: 1, grant: hash } });
// @ts-expect-error candidate royalty basis points retain the original uint16 bigint representation
prepareCurrentArtistAction({ ...prospectiveRequest, details: { ...prospectiveRequest.details, candidate: { ...candidate, royaltyBps: 10 } } });
// @ts-expect-error no delegated prospective template transport is synthesized
prepareCurrentArtistAction({ ...prospectiveRequest, details: { ...prospectiveRequest.details, candidate: { ...candidate, templateId: hash } } });
// @ts-expect-error royalty freeze's collection is signed and cannot be duplicated in details
prepareCurrentArtistAction({ ...request, kind: "delegatedRoyaltyFreeze", message: delegatedFreeze, details: { grant: hash, collectionId: 1n } });
// @ts-expect-error nested prepared candidate inputs are immutable
prospectivePlan.request.details.candidate.frozen = true;
// @ts-expect-error the reviewed supplemental collection cannot change after preparation
economicsPlan.request.details.collectionId = 2n;
