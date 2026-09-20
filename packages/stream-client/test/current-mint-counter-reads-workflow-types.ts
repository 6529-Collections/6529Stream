import type { Provider } from "ethers";
import type { Address, Hex } from "../src/generated/contracts.js";
import { prepareMintCounterReadCall, type MintCounterReadRequest, type MintCounterKeyContext } from "../src/current-mint-counter-reads.js";
import { inspectMintCounterRead, type MintCounterReadDeployment, type MintCounterReadObservation,
  type MintCounterDefinitionObservation, type MintCounterReadCodePin } from "../src/current-mint-counter-reads-workflow.js";

declare const provider: Pick<Provider, "getNetwork" | "getCode" | "getBlock" | "call">;
declare const manager: Address, caller: Address, hash: Hex, context: MintCounterKeyContext;
const pin: MintCounterReadCodePin = { address: manager, codeHash: hash };
const deployment: MintCounterReadDeployment = { chainId: (1n << 160n) + 1n, manager: pin, ledger: pin };
const requests: readonly MintCounterReadRequest[] = [
  { method: "rawCounterValue", valueKey: hash },
  { method: "counterValue", collectionId: context.collectionId, phaseId: context.phaseId, counterId: context.counterId, subjectKey: hash },
  { method: "remainingForCounter", collectionId: context.collectionId, phaseId: context.phaseId, counterId: context.counterId, subjectKey: hash },
  { method: "resolveCounter", context }, { method: "remainingForResolvedCounter", context }
];
for (const request of requests) {
  const prepared = prepareMintCounterReadCall(manager, caller, request);
  const response: Promise<MintCounterReadObservation> = inspectMintCounterRead(provider, deployment, prepared, { blockTag: 10 });
  void response;
}
declare const observation: MintCounterReadObservation;
const expectedChain: bigint = observation.deployment.chainId;
const retainedActor: Address = observation.prepared.caller;
const returnData: Hex = observation.returnData;
const current: bigint = observation.current;
const scalar: bigint | null = observation.value;
const remaining: bigint | null = observation.remainingConsumptions;
const accountingOnly: true = observation.accountingOnly;
const unit: "unknown" | "per-token" | "per-batch" = observation.consumptionUnit;
// Raw reads carry no inferred phase, policy, definition or resolution facts.
if (observation.policy !== null) {
  const staticIncrement: bigint = observation.policy.config.staticIncrement;
  // @ts-expect-error Observed nested config is immutable.
  observation.policy.config.staticIncrement = 1n;
  void staticIncrement;
}
if (observation.resolution !== null) {
  const effectiveCap: bigint = observation.resolution.effectiveCap;
  // @ts-expect-error Resolution data is not a token quantity or JS number.
  const tokenQuantity: number = effectiveCap;
  void tokenQuantity;
}
if (observation.definition !== null) {
  const d: MintCounterDefinitionObservation = observation.definition;
  const scope: "direct-ledger-observation" = d.scope;
  const caveat: true = d.noNestedGasEquivalence;
  const rawScope: bigint = d.returnedDefinition.scope, effectiveScope: bigint = d.candidateDefinition.scope;
  const probe: "supported" | "legacy-not-supported" | "legacy-call-reverted" | "legacy-noncanonical" = d.probe;
  // @ts-expect-error Direct observation cannot assert metered nested-call equivalence.
  const equivalent: false = d.noNestedGasEquivalence;
  // @ts-expect-error Raw source observation cannot be rewritten into the candidate branch.
  d.returnedDefinition.scope = effectiveScope;
  void [scope, caveat, rawScope, probe, equivalent];
}
const rawPrepared = prepareMintCounterReadCall(manager, caller, { method: "rawCounterValue", valueKey: hash });
// @ts-expect-error Observer requires original immutable prepared call, not request-only input.
inspectMintCounterRead(provider, deployment, { method: "rawCounterValue", valueKey: hash }, { blockTag: 10 });
// @ts-expect-error Pinned inspection needs a concrete numeric block.
inspectMintCounterRead(provider, deployment, rawPrepared, { blockTag: "latest" });
// @ts-expect-error Block tag API is a JS safe block number, not protocol uint256 bigint.
inspectMintCounterRead(provider, deployment, rawPrepared, { blockTag: 10n });
// @ts-expect-error A caller is already bound into the prepared read, not an override option.
inspectMintCounterRead(provider, deployment, rawPrepared, { blockTag: 10, caller });
// @ts-expect-error Code hash is required for each pinned deployment address.
inspectMintCounterRead(provider, { ...deployment, manager: { address: manager } }, rawPrepared, { blockTag: 10 });
// @ts-expect-error Original chainId must preserve bigint width.
inspectMintCounterRead(provider, { ...deployment, chainId: 1 }, rawPrepared, { blockTag: 10 });
// @ts-expect-error Raw observations require explicit null handling.
const assumedPhase = observation.phase.startTime;
// @ts-expect-error Exposed current value is immutable.
observation.current = 0n;
// @ts-expect-error Observed actor cannot be rewritten after inspection.
observation.prepared.caller = manager;
// @ts-expect-error Pin snapshots are immutable.
observation.deployment.ledger.codeHash = hash;
// @ts-expect-error This accounting-only module has no mint authorization property.
observation.authorized;
// @ts-expect-error Views have no execution or transaction receipt.
observation.receipt;
void [expectedChain, retainedActor, returnData, current, scalar, remaining, accountingOnly, unit, assumedPhase];
