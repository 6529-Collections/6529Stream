import type { Address, Hex } from "../src/generated/contracts.js";
import {
  normalizeMintCounterKeyContext, normalizeMintCounterResolution, normalizeMintCounterReadBinding, normalizeMintCounterReadPolicy,
  normalizeMintCounterAllowlistProof, encodeMintCounterAllowlistProof, decodeMintCounterAllowlistProof, mintCounterAllowlistLeaf,
  verifyMintCounterAllowlistProof, mintCounterReadScope, mintCounterReadValueKey, resolveMintCounterRead, mintCounterReadRemaining,
  mintCounterProoflessRemaining, normalizeMintCounterReadRequest, prepareMintCounterReadCall, normalizeMintCounterReadCall,
  type MintCounterKeyContext, type MintCounterResolution, type MintCounterReadBinding, type MintCounterReadPolicy,
  type MintCounterAllowlistProof, type MintCounterReadRequest, type MintCounterReadCall, type MintCounterReadResolution
} from "../src/current-mint-counter-reads.js";

declare const manager: Address, caller: Address, hash: Hex;
declare const context: MintCounterKeyContext, binding: MintCounterReadBinding, policy: MintCounterReadPolicy;
const original: MintCounterKeyContext = normalizeMintCounterKeyContext(context);
const observedPolicy: MintCounterReadPolicy = normalizeMintCounterReadPolicy(policy);
const observedBinding: MintCounterReadBinding = normalizeMintCounterReadBinding(binding);
const proof: MintCounterAllowlistProof = normalizeMintCounterAllowlistProof({ maxCount: (1n << 60n) + 1n,
  hasPriceOverride: true, priceOverride: (1n << 230n) + 1n, proof: [hash] });
const proofBytes: Hex = encodeMintCounterAllowlistProof(proof);
const decodedProof: MintCounterAllowlistProof = decodeMintCounterAllowlistProof(proofBytes);
const leaf: Hex = mintCounterAllowlistLeaf(binding, context.collectionId, context.phaseId, context.counterId, context.beneficiary, proof);
const valid: boolean = verifyMintCounterAllowlistProof(hash, leaf, decodedProof.proof);
const resolution: MintCounterReadResolution = resolveMintCounterRead(observedBinding, observedPolicy, original);
const fields: MintCounterResolution = normalizeMintCounterResolution(resolution.resolution);
const key: Hex = mintCounterReadValueKey(binding, policy, { collectionId: context.collectionId, phaseId: context.phaseId,
  counterId: context.counterId, subjectKey: resolution.resolution.subjectKey });
const scopedCid: bigint = mintCounterReadScope(policy, context.collectionId, context.phaseId).collectionId;
const remaining: bigint = mintCounterReadRemaining(policy.config.capMode, fields.effectiveCap, 0n);
const proofless: bigint = mintCounterProoflessRemaining(policy, 0n);
const requests: readonly MintCounterReadRequest[] = [
  { method: "rawCounterValue", valueKey: hash },
  { method: "counterValue", collectionId: context.collectionId, phaseId: context.phaseId, counterId: context.counterId, subjectKey: hash },
  { method: "remainingForCounter", collectionId: context.collectionId, phaseId: context.phaseId, counterId: context.counterId, subjectKey: hash },
  { method: "resolveCounter", context }, { method: "remainingForResolvedCounter", context }
];
for (const request of requests) {
  const prepared: MintCounterReadCall = prepareMintCounterReadCall(manager, caller, normalizeMintCounterReadRequest(request));
  const rebuilt: MintCounterReadCall = normalizeMintCounterReadCall(prepared);
  const target: Address = rebuilt.call.to, actor: Address = rebuilt.caller, data: Hex = rebuilt.call.data;
  const amount: bigint = rebuilt.call.value;
  if ("context" in rebuilt.request) {
    const originalExecutor: Address = rebuilt.request.context.executor;
    // @ts-expect-error Snapshot preserves readonly context actors.
    rebuilt.request.context.executor = caller;
    void originalExecutor;
  } else if (rebuilt.request.method === "rawCounterValue") {
    const raw: Hex = rebuilt.request.valueKey;
    // @ts-expect-error A raw read has no phase/subject context.
    rebuilt.request.context;
    void raw;
  }
  // @ts-expect-error A view call has no signature bundle.
  rebuilt.signature;
  // @ts-expect-error Caller is an immutable separate field.
  rebuilt.caller = manager;
  void [target, actor, data, amount];
}

// @ts-expect-error Context integers are bigint, even below Number.MAX_SAFE_INTEGER.
normalizeMintCounterKeyContext({ ...context, tokenIndex: 9 });
// @ts-expect-error Original context contains exactly eleven fields and does not accept a signer.
normalizeMintCounterKeyContext({ ...context, signer: caller });
// @ts-expect-error A signature cannot be substituted for original resolverData bytes.
normalizeMintCounterKeyContext({ ...context, resolverData: proof });
// @ts-expect-error Binding chain is uint256 bigint.
normalizeMintCounterReadBinding({ ...binding, chainId: 1 });
// @ts-expect-error Policy includes an explicit observed existence flag.
normalizeMintCounterReadPolicy({ phaseExists: true, config: policy.config, definition: policy.definition });
// @ts-expect-error Explicit flags are boolean rather than integer truthiness.
normalizeMintCounterReadPolicy({ ...policy, definitionExists: 1n });
// @ts-expect-error Proof price uses original uint256 bigint.
normalizeMintCounterAllowlistProof({ ...proof, priceOverride: 1 });
// @ts-expect-error Single proof tuple does not accept nested batch proof arrays.
encodeMintCounterAllowlistProof([[proof]]);
// @ts-expect-error Frozen proof path cannot be mutated.
decodedProof.proof.push(hash);
// @ts-expect-error Returned resolution is immutable.
resolution.resolution.effectiveCap = 0n;
// @ts-expect-error Structural policy snapshot is deeply readonly.
observedPolicy.definition.scope = 2n;
// @ts-expect-error Remaining is integer accounting, not a boolean admission flag.
const admitted: boolean = remaining;
// @ts-expect-error Proofless method takes configured policy, not a signed proof.
mintCounterProoflessRemaining(proof, 0n);
// @ts-expect-error No write method is accepted by this interface.
prepareMintCounterReadCall(manager, caller, { method: "mint", context });
// @ts-expect-error A resolved read requires its original context tuple.
prepareMintCounterReadCall(manager, caller, { method: "resolveCounter", valueKey: hash });
// @ts-expect-error Scalar subject read has no resolverData field.
prepareMintCounterReadCall(manager, caller, { method: "counterValue", collectionId: 1n, phaseId: hash, counterId: hash, subjectKey: hash, resolverData: "0x" });
// @ts-expect-error Original resolution has no new mint-authorization result.
normalizeMintCounterResolution({ ...fields, authorized: true });
void [valid, key, scopedCid, remaining, proofless, admitted];
