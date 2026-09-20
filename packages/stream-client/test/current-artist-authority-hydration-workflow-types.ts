import type { Provider } from "ethers";
import type { Address, Hex } from "../src/generated/contracts.js";
import type { ArtistAuthorityHydrationCall } from "../src/current-artist-authority-hydration.js";
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
