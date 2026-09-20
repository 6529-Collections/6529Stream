import type { Address, Hex } from "../src/generated/contracts.js";
import type { ArtistHydrationSuite } from "../src/current-artist-authority-hydration.js";
import * as c from "../src/current-artist-recovered-consent-hydration.js";
import * as old from "../src/current-artist-recovered-hydration.js";

declare const actor: Address, registry: Address, raw: Hex;
declare const request: old.ArtistRecoveredHydrationRequest;
declare const prepared: c.ArtistRecoveredConsentHydrationPrepared;
declare const coordinates: c.ArtistRecoveredConsentHydrationCoordinates;
declare const suite: ArtistHydrationSuite;
declare const royalties: readonly c.ArtistRecoveredConsentHydrationRoyaltyFreeze[];
declare const bundle: c.ArtistRecoveredConsentHydrationContentBundle;
declare const local: c.ArtistRecoveredConsentHydrationOwnerProvenance;

const input: c.ArtistRecoveredConsentHydrationInput = { request, royaltyFreezes: royalties };
const draft = c.normalizeArtistRecoveredConsentHydrationInputDraft(input);
const preparationData: Hex = c.artistRecoveredConsentHydrationPreparationCalldata(suite, draft);
const finalInput = c.validateArtistRecoveredConsentHydrationInput(input, prepared);
const plan: c.ArtistRecoveredConsentHydrationCall = c.prepareArtistRecoveredConsentHydrationCall(registry, actor, finalInput);
c.normalizeArtistRecoveredConsentHydrationCall(plan);
const uncertainty: false = plan.factsVerified;
const finalRequest: old.ArtistRecoveredHydrationRequest = plan.request;
const nonceWidth: bigint = finalRequest.records.authority.expectedSource[0].nonceIndexCount;
const commitment: Hex = c.artistRecoveredConsentHydrationCommitment(coordinates, finalRequest, prepared);
const contentRaw = c.encodeArtistRecoveredConsentHydrationContentBundle(bundle, prepared.query, local);
const canonical: c.ArtistRecoveredConsentHydrationContentBundle = c.decodeArtistRecoveredConsentHydrationContentBundle(contentRaw, prepared.query, local);
const record: c.ArtistRecoveredConsentHydrationRoyaltyRecord = canonical.royalties[0]!.item;
const classes: readonly Hex[] = canonical.freezes[0]!.lockClasses;
const inventory: Hex = c.artistRecoveredConsentHydrationSemanticInventory(prepared);
const bytes: Hex = c.encodeArtistRecoveredConsentHydrationProfileEvidence(finalRequest, prepared);
const oldKnownShape: bigint = old.ARTIST_RECOVERED_HYDRATION_SHAPES.attestation;
const newKnownShape: bigint = c.ARTIST_RECOVERED_CONSENT_HYDRATION_SHAPES.content;

// @ts-expect-error Additional royalty witnesses do not change the original RH.Request fields.
const wrongRequest: old.ArtistRecoveredHydrationRequest = { ...request, royaltyFreezes: royalties };
// @ts-expect-error Separate explicit input requires the royalty witness array, including when empty.
c.prepareArtistRecoveredConsentHydrationCall(registry, actor, { request });
// @ts-expect-error Exact original collection width is bigint.
const badTerms: c.ArtistRecoveredConsentHydrationRoyaltyFreeze = { resolver: registry, collectionId: 1, revenueClass: raw, expectedAssignmentHash: raw };
// @ts-expect-error No profile/mask override is public.
c.normalizeArtistRecoveredConsentHydrationInput({ ...input, knownFeatures: 1023n });
// @ts-expect-error Old public profile cannot be widened by a caller argument.
old.normalizeArtistRecoveredHydrationPrepared(prepared, 511n);
// @ts-expect-error The fixed public511 adapter has no factory override either.
c.normalizeArtistRecoveredConsentHydrationPrepared(prepared, 1023n);
// @ts-expect-error Original royalty record lacks a signer preimage.
record.signer;
// @ts-expect-error Original royalty record lacks a retained deadline.
record.deadline;
// @ts-expect-error Prepared plan recursively freezes original witness terms.
plan.royaltyFreezes[0]!.expectedAssignmentHash = raw;
// @ts-expect-error Retained lock-class order is immutable.
classes.reverse();
// @ts-expect-error New readonly input cannot grant authority.
const live: true = plan.factsVerified;
// @ts-expect-error No synthetic op60 signing payload exists.
plan.signingPayload;
void [preparationData, uncertainty, nonceWidth, commitment, inventory, bytes, oldKnownShape, newKnownShape];
