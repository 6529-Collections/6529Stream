import type { Provider } from "ethers";
import type { Address, Hex } from "../src/generated/contracts.js";
import type { CurrentArtistOperationRequest } from "../src/current-artist-operation.js";
import {
  captureCurrentArtistOperation, simulateCurrentArtistCall, createCurrentArtistSafePlan,
  inspectCurrentArtistReceipt, type CurrentArtistCapture, type CurrentArtistDeployment,
  type CurrentArtistReceipt,
} from "../src/current-artist-workflow.js";

declare const provider: Provider;
declare const deployment: CurrentArtistDeployment;
declare const request: CurrentArtistOperationRequest;
declare const capture: CurrentArtistCapture;
declare const receipt: CurrentArtistReceipt;
declare const address: Address;
declare const hash: Hex;

const captured: Promise<CurrentArtistCapture> = captureCurrentArtistOperation(provider, deployment, request, { blockTag: 100 });
const simulated = simulateCurrentArtistCall(provider, capture, { blockTag: 101 });
const plan = createCurrentArtistSafePlan([capture], "Reviewed Artist actions");
const inspected: Promise<CurrentArtistReceipt> = inspectCurrentArtistReceipt(provider, capture, { transactionHash: hash, execution: "safe" });
const required: true = capture.simulationRequired;
const nonce: bigint = capture.replay.nextUnusedNonce;
const block: number = receipt.blockNumber;
void captured; void simulated; void plan; void inspected; void required; void nonce; void block;

// @ts-expect-error captures require a concrete numeric block
captureCurrentArtistOperation(provider, deployment, request, { blockTag: "latest" });
// @ts-expect-error protocol-only and delegated operations are outside this family
captureCurrentArtistOperation(provider, deployment, { ...request, kind: "delegatedRoyaltyFreeze" }, { blockTag: 100 });
// @ts-expect-error transaction execution is a direct call or ordinary Safe CALL
inspectCurrentArtistReceipt(provider, capture, { transactionHash: hash, execution: "delegatecall" });
// @ts-expect-error no broadcast method or signer enters a read helper
simulateCurrentArtistCall(provider, capture, { blockTag: 101, signer: address });
// @ts-expect-error the deployment's runtime pins are immutable
capture.deployment.components[0]!.codeHash = hash;
// @ts-expect-error captured caller is immutable
capture.action.request.caller = address;
// @ts-expect-error replay evidence is immutable
capture.replay.nonceConsumed = false;
// @ts-expect-error receipt event references are immutable
receipt.events.push({ address, event: "fake", logIndex: 0, transactionHash: hash, blockHash: hash });
