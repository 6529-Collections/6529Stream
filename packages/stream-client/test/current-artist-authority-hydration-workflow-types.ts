import type { Provider } from "ethers";
import type { Address, Hex } from "../src/generated/contracts.js";
import { prepareArtistAuthorityHydrationCall, decodeArtistHydrationOwnerState, decodeArtistHydrationDelegationIdentity,
  type ArtistAuthorityHydrationCall, type ArtistMultipleHydrationRequest } from "../src/current-artist-authority-hydration.js";
import { captureArtistAuthorityHydration, simulateArtistAuthorityHydration, inspectArtistAuthorityHydrationReceipt,
  type ArtistAuthorityHydrationDeployment, type ArtistAuthorityHydrationCapture } from "../src/current-artist-authority-hydration-workflow.js";
import { createSafeCallPlan } from "../src/safe-plan.js";
declare const provider: Provider;
declare const deployment: ArtistAuthorityHydrationDeployment;
declare const call: ArtistAuthorityHydrationCall;
declare const hash: Hex;
declare const safe: Address;
declare const capture: ArtistAuthorityHydrationCapture;
const live = await captureArtistAuthorityHydration(provider, deployment, call, { blockTag: 12 });
const refreshed = await simulateArtistAuthorityHydration(provider, live, { blockTag: 13 });
const receipt = await inspectArtistAuthorityHydrationReceipt(provider, refreshed, hash, { execution: "safe" });
const revision: bigint = receipt.observedOwners[0]!.revision;
const verified: true = receipt.capture.simulated;
const nonceKind: bigint = live.nonceIndexes[0]!.kind;
const catalog: Hex = live.payloadCatalogs[0]!.rows[0]!.payloadHash;
void revision; void verified; void nonceKind; void catalog;
// @ts-expect-error The original hydration CALL needs an explicit caller.
captureArtistAuthorityHydration(provider, deployment, { input: call.input, call: call.call }, { blockTag: 12 });
// @ts-expect-error Moving tags are outside the pinned capture profile.
captureArtistAuthorityHydration(provider, deployment, call, { blockTag: "latest" });
// @ts-expect-error There is no delegatecall transport.
inspectArtistAuthorityHydrationReceipt(provider, capture, hash, { execution: "delegatecall" });
// @ts-expect-error Source pins are immutable.
deployment.source.components[0]!.codeHash = hash;
// @ts-expect-error Retained checkpoint arrays are immutable.
capture.checkpoints.push(capture.checkpoints[0]!);
// @ts-expect-error Actual actor is retained immutably.
capture.prepared.caller = safe;
// @ts-expect-error Payload catalog rows are immutable.
capture.payloadCatalogs[0]!.rows[0]!.pointer = safe;
void createSafeCallPlan;

declare const multipleRequest: ArtistMultipleHydrationRequest;
const combinedCall = prepareArtistAuthorityHydrationCall(deployment.destination.registry.address, safe,
  { kind: "multiple-delegation", request: multipleRequest });
const combined = await captureArtistAuthorityHydration(provider, deployment, combinedCall, { blockTag: 14 });
const combinedReceipt = await inspectArtistAuthorityHydrationReceipt(provider, combined, hash, { execution: "safe" });
const identities = decodeArtistHydrationOwnerState("multiple-delegation", 2, combinedReceipt.capture.ownerData[2]!.typedState);
const identity = decodeArtistHydrationDelegationIdentity(identities.rows[0]!.state);
const delegateLane: Hex = identity.delegateNonces[0]!.key;
const principalNonceWord: bigint = identities.rows[0]!.nonces[0]!.words[0]!;
void delegateLane; void principalNonceWord;
// @ts-expect-error The combined profile still requires the original complete multiple request.
prepareArtistAuthorityHydrationCall(safe, safe, { kind: "multiple-delegation", request: { artistId: hash, collectionId: 1n } });
// @ts-expect-error Canonical per-Artist record inventory is immutable.
identities.rows[0]!.records.push(hash);
// @ts-expect-error Nested historical grant uses cannot be edited through decoded observations.
identity.grants[0]!.item.uses = 2n;
// @ts-expect-error There is no independently selectable multiple/delegation boolean override.
prepareArtistAuthorityHydrationCall(safe, safe, { kind: "multiple", request: multipleRequest, withDelegations: true });
