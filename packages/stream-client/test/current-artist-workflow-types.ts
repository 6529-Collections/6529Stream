import type { Provider } from "ethers";
import type { Address, Hex } from "../src/generated/contracts.js";
import type { CurrentArtistOperationRequest } from "../src/current-artist-operation.js";
import {
  captureCurrentArtistOperation, simulateCurrentArtistCall, createCurrentArtistSafePlan,
  inspectCurrentArtistReceipt, type CurrentArtistCapture, type CurrentArtistDeployment,
  type CurrentArtistReceipt,
  inspectCurrentArtistRecordedConsent, type CurrentArtistRecordedConsentRequest,
  type CurrentArtistRecordedConsentObservation,
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
// @ts-expect-error delegated attestation is outside this family
captureCurrentArtistOperation(provider, deployment, { ...request, kind: "delegatedAttestation" }, { blockTag: 100 });
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

// The dated effective digest is block-specific, separate from the submitted payload.
const effectiveTime: bigint = capture.timing.effectiveTime;
const effectiveDigest: Hex = receipt.effectiveDigest;
const timeKind: "deadline" | "dated" | "nonce-only" = capture.timing.kind;
const operativeDocument: Hex | undefined = capture.revision?.operativeDocumentHash;
const grantor: Address | undefined = capture.delegation?.grantor;
const grantUses: bigint | undefined = capture.delegation?.uses;
void effectiveTime; void effectiveDigest; void timeKind; void operativeDocument; void grantor; void grantUses;
// @ts-expect-error observed effective timing is immutable
capture.timing.effectiveTime = 1n;
// @ts-expect-error retained delegation terms are immutable
capture.delegation!.grant.maxUses = 99n;
// @ts-expect-error a prepared capture cannot promise signing-time zero is the mined digest
const guaranteed: "submitted-digest-always-executed" = capture.timing.kind;
void guaranteed;

// A delegated creation retains its own nonce lane independently of Artist replay.
const delegateNonce: bigint | undefined = capture.delegated?.nextUnusedNonce;
const epoch: bigint | undefined = capture.delegated?.epochRecorded;
const used: boolean | undefined = receipt.observedDelegated?.nonceUsed;
void delegateNonce; void epoch; void used;
// @ts-expect-error delegated replay evidence is immutable
capture.delegated!.nextUnusedNonce = 99n;
// @ts-expect-error receipt nonce evidence is immutable
receipt.observedDelegated!.nonceUsed = false;

declare const recordedRequest: CurrentArtistRecordedConsentRequest;
declare const recorded: CurrentArtistRecordedConsentObservation;
const durable: Promise<CurrentArtistRecordedConsentObservation> = inspectCurrentArtistRecordedConsent(
  provider, deployment, recordedRequest, { blockTag: 100 }
);
const applicability: "policy-record-only" | "sale-consent-checked-for-adapter" = recorded.applicability;
const adapterCaller: Address | undefined = recorded.checkedCall?.from;
void durable; void applicability; void adapterCaller;
// @ts-expect-error no live creation grant is accepted by the durable lookup
inspectCurrentArtistRecordedConsent(provider, deployment, { ...recordedRequest, grant: hash }, { blockTag: 100 });
// @ts-expect-error the observation is pinned to a concrete block
inspectCurrentArtistRecordedConsent(provider, deployment, recordedRequest, { blockTag: "latest" });
// @ts-expect-error observed association is immutable
recorded.delegationRecordHash = hash;
// @ts-expect-error policy existence does not promise full mint admission
const mintReady: "mint-admission-verified" = recorded.applicability;
void mintReady;

const reads: Address | undefined = capture.deployment.reads?.address;
const payoutAccount: Address | undefined = capture.economics?.payout.account;
const candidateEvidence: Hex | undefined = receipt.economics?.candidateEvidence;
const originalEconomics: Hex | undefined = receipt.economics?.association.originalRecord;
void reads; void payoutAccount; void candidateEvidence; void originalEconomics;
// @ts-expect-error pinned Reads is immutable
capture.deployment.reads!.codeHash = hash;
// @ts-expect-error retained economics inputs are immutable
capture.economics!.payout.account = address;
// @ts-expect-error actual receipt association is immutable
receipt.economics!.association.bindingGeneration = 99n;
