import type { Address, Hex } from "../src/generated/contracts.js";
import type { MintContinuityArtifact, MintStateImportBatch } from "../src/current-mint-continuity.js";
import { mintFallbackActivationCalls, mintFallbackGovernanceBatch, mintFallbackIncidentActivationCalls,
  mintFallbackImportCommitCall, mintFallbackImportStateCall, mintFallbackRawImportStateCall,
  normalizeMintFallbackConfiguration, normalizeMintFallbackGovernanceBatch, normalizeMintFallbackPlan,
  prepareMintFallbackPlan, type MintFallbackActivation, type MintFallbackConfiguration,
  type MintFallbackIncident, type MintFallbackGovernanceWindow } from "../src/current-mint-fallback.js";
declare const c: MintFallbackConfiguration;
declare const a: MintFallbackActivation;
declare const i: MintFallbackIncident;
declare const artifact: MintContinuityArtifact;
declare const rawBatch: MintStateImportBatch;
declare const window: MintFallbackGovernanceWindow;
declare const address: Address;
declare const hash: Hex;
const plan = mintFallbackIncidentActivationCalls(c, a, i);
mintFallbackActivationCalls(c, a);
mintFallbackImportCommitCall(c, artifact);
mintFallbackImportStateCall(c, artifact, [0], [1]);
mintFallbackRawImportStateCall(c, rawBatch);
prepareMintFallbackPlan(c, { kind: "incident-activation", activation: a, incident: i });
normalizeMintFallbackPlan(plan);
const batch = mintFallbackGovernanceBatch(plan, 0n, window);
normalizeMintFallbackGovernanceBatch(batch);
const actionId: Hex = batch.actionId;
const actualActor: Address | null = plan.actor;
void actionId; void actualActor;
// @ts-expect-error chain IDs cannot be lossy numbers
normalizeMintFallbackConfiguration({ ...c, chainId: 1 });
// @ts-expect-error caller is not an original Configuration field
normalizeMintFallbackConfiguration({ ...c, caller: address });
// @ts-expect-error recovery state uses full-width bigint counters
mintFallbackIncidentActivationCalls(c, a, { ...i, state: { ...i.state, supply: 1 } });
// @ts-expect-error no guessed import selector or authorization route
prepareMintFallbackPlan(c, { kind: "synthetic-import" });
// @ts-expect-error the raw import route requires real original batch fields
mintFallbackRawImportStateCall(c, { importRoot: hash });
// @ts-expect-error reviewed target data is immutable
plan.data.push(hash);
// @ts-expect-error per-call transition hashes are immutable
plan.calls[0]!.scopeHash = hash;
// @ts-expect-error the actor comes from original Executor coordinates
plan.actor = address;
// @ts-expect-error the wrapper preserves exact uint256 nonce values
mintFallbackGovernanceBatch(plan, 1, window);
// @ts-expect-error scheduling does not establish verified runtime facts
plan.factsVerified = true;
