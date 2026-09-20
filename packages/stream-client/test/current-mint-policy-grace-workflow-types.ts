import type { Provider } from "ethers";
import type { Address, Hex } from "../src/generated/contracts.js";
import type { MintPolicyGraceRequest, MintPolicyGraceGovernanceWindow } from "../src/current-mint-policy-grace.js";
import {
  captureMintPolicyGrace, inspectMintPolicyGraceChange, prepareMintPolicyGraceGovernance,
  prepareMintPolicyGraceGovernanceOperation, simulateMintPolicyGraceOperation,
  inspectMintPolicyGraceOperationReceipt,
  type MintPolicyGraceDeployment, type MintPolicyGraceScope, type MintPolicyGraceCapture,
  type MintPolicyGraceInspection, type MintPolicyGraceOperationReceipt
} from "../src/current-mint-policy-grace-workflow.js";

declare const provider: Provider;
declare const deployment: MintPolicyGraceDeployment;
declare const scope: MintPolicyGraceScope;
declare const request: MintPolicyGraceRequest;
declare const window: MintPolicyGraceGovernanceWindow;
declare const capture: MintPolicyGraceCapture;
declare const inspection: MintPolicyGraceInspection;
declare const address: Address;
declare const hash: Hex;

const captured: Promise<MintPolicyGraceCapture> = captureMintPolicyGrace(provider, deployment, scope, { blockTag: 100 });
const checked: Promise<MintPolicyGraceInspection> = inspectMintPolicyGraceChange(provider, capture, request, { blockTag: 101 });
const prepared = prepareMintPolicyGraceGovernance(inspection, address, window);
const operation = prepareMintPolicyGraceGovernanceOperation(prepared, "execute", address);
const simulation = simulateMintPolicyGraceOperation(provider, operation, { blockTag: 1000 });
const receipt: Promise<MintPolicyGraceOperationReceipt> = inspectMintPolicyGraceOperationReceipt(provider, operation, {
  transactionHash: hash, execution: "safe"
});
const value: bigint = operation.call.value;
const readiness: boolean | undefined = inspection.artistConsent?.registrationReady;
const rowProof: "original-call-simulation-required" = capture.catalog.rowAdmission;
const originalManager: Address | undefined = inspection.artistConsent?.signingManager;
void captured; void checked; void simulation; void receipt; void value; void readiness; void rowProof; void originalManager;

// @ts-expect-error a current policy snapshot must be captured at a concrete block
captureMintPolicyGrace(provider, deployment, scope, { blockTag: "latest" });
// @ts-expect-error the reviewed complete executor inventory is immutable
capture.scope.executors.push(address);
// @ts-expect-error runtime pins are immutable
capture.deployment.manager.codeHash = hash;
// @ts-expect-error no signer enters read-only simulation
simulateMintPolicyGraceOperation(provider, operation, { blockTag: 100, signer: address });
// @ts-expect-error only the original three governance stages are supported
prepareMintPolicyGraceGovernanceOperation(prepared, "direct-owner-write", address);
// @ts-expect-error Safe receipts require ordinary CALL, not delegated execution
inspectMintPolicyGraceOperationReceipt(provider, operation, { transactionHash: hash, execution: "delegatecall" });
// @ts-expect-error observed consent is immutable
inspection.artistConsent!.registrationReady = true;
// @ts-expect-error this observation does not prove full catalog row admission
const proved: "catalog-row-verified" = capture.catalog.rowAdmission;
void proved;
