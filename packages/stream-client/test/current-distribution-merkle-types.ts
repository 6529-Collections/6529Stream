import type { Address, Hex } from "../src/generated/contracts.js";
import type {
  OperatorDistributionContext,
  OperatorDistributionManifest,
  OperatorDistributionProgram,
} from "../src/current-distribution.js";
import {
  buildDistributionMerkleAllowanceTree,
  decodeDistributionMerkleProofs,
  distributionMerkleAllowanceLeaf,
  distributionMerkleProgramHash,
  distributionMerkleProjectedCaps,
  distributionMerkleResolverData,
  encodeDistributionMerkleProofs,
  normalizeDistributionMerklePreparedCall,
  prepareDistributionMerkleCall,
  prepareDistributionMerkleClaim,
  prepareDistributionMerkleProgram,
  prepareDistributionMerkleProgramRead,
} from "../src/current-distribution-merkle.js";
import type {
  DistributionMerkleCallInput,
  DistributionMerkleContext,
  DistributionMerkleCounterObservation,
  DistributionMerkleDefinitionSelection,
  DistributionMerklePreparedCall,
  DistributionMerkleProof,
} from "../src/current-distribution-merkle.js";

declare const context: DistributionMerkleContext;
declare const originalContext: OperatorDistributionContext;
declare const manifest: OperatorDistributionManifest;
declare const originalProgram: OperatorDistributionProgram;
declare const selection: DistributionMerkleDefinitionSelection;
declare const caller: Address;
declare const receiver: Address;
declare const hash: Hex;
declare const counters: readonly DistributionMerkleCounterObservation[];

const proof: DistributionMerkleProof = {
  maxCount: 2n,
  hasPriceOverride: false,
  priceOverride: 0n,
  proof: [hash],
};
const program = prepareDistributionMerkleProgram(manifest, selection);
const input: DistributionMerkleCallInput = {
  program,
  sliceIndex: 0,
  counters,
  proofs: [[proof, proof]],
  expectedPolicyHash: hash,
  gateData: "0x",
  revealFeePerTokenWei: 7n,
};
const distribute = prepareDistributionMerkleCall(context, caller, input);
const ownClaim = prepareDistributionMerkleClaim(context, caller, {
  kind: "claimNft", tokenId: 1n << 200n, receiver,
});
const delegatedClaim = prepareDistributionMerkleClaim(context, caller, {
  kind: "claimNftFor", tokenId: 1n, walletWide: false, delegationIndex: 1n << 180n,
});
const prepared: readonly DistributionMerklePreparedCall[] = [distribute, ownClaim, delegatedClaim];
for (const call of prepared) {
  const normalized = normalizeDistributionMerklePreparedCall(call);
  const suppliedFactsOnly: false = normalized.factsVerified;
  const value: bigint = normalized.call.value;
  const target: Address = normalized.call.to;
  if (normalized.kind === "distribute") {
    const orderedRecipients: readonly Address[] = normalized.batch.beneficiaries;
    const orderedProofGroups: readonly (readonly DistributionMerkleProof[])[] = normalized.input.proofs;
    void [orderedRecipients, orderedProofGroups];
  } else if (normalized.input.kind === "claimNft") {
    const ownReceiver: Address = normalized.input.receiver;
    void ownReceiver;
  } else {
    const delegationIndex: bigint = normalized.input.delegationIndex;
    void delegationIndex;
  }
  void [suppliedFactsOnly, value, target];
}
const getter = prepareDistributionMerkleProgramRead(originalContext, 0n, hash, originalProgram, hash);
const applicationHash: Hex = distributionMerkleProgramHash(originalContext, 0n, hash, originalProgram, selection);
const tree = buildDistributionMerkleAllowanceTree(context, 1n, hash, hash, 4n, [
  { beneficiary: caller, maxCount: 2n },
  { beneficiary: caller, maxCount: 4n },
]);
const leaf: Hex = distributionMerkleAllowanceLeaf(context, 1n, hash, hash, caller, proof);
const encoded: Hex = encodeDistributionMerkleProofs([[proof]]);
const decoded = decodeDistributionMerkleProofs(encoded);
const resolverData: Hex = distributionMerkleResolverData(context, 1n, hash, [caller, caller], counters, [[proof, proof]]);
const projected = distributionMerkleProjectedCaps([
  { valueKey: hash, current: 1n, increment: 1n, cap: 3n },
  { valueKey: hash, current: 1n, increment: 1n, cap: 4n },
]);
const total: bigint = projected[0]!.projected;

// @ts-expect-error token IDs retain exact uint256 precision
prepareDistributionMerkleClaim(context, caller, { kind: "claimNft", tokenId: 1, receiver });
// @ts-expect-error delegated claim cannot redirect the beneficiary's token
prepareDistributionMerkleClaim(context, caller, { kind: "claimNftFor", tokenId: 1n, walletWide: true, delegationIndex: 0n, receiver });
// @ts-expect-error this profile has no arbitrary sweep or administrative mutation
prepareDistributionMerkleClaim(context, caller, { kind: "sweep", tokenId: 1n, receiver });
// @ts-expect-error claim transport accepts no caller-selected transaction value
prepareDistributionMerkleClaim(context, caller, { kind: "claimNft", tokenId: 1n, receiver, value: 1n });
// @ts-expect-error allowance count is an exact uint64 bigint
const roundedProof: DistributionMerkleProof = { ...proof, maxCount: 2 };
// @ts-expect-error free-distribution profile intentionally excludes price overrides
const pricedProof: DistributionMerkleProof = { ...proof, hasPriceOverride: true };
// @ts-expect-error source price field is retained but fixed to zero in this profile
const nonzeroPrice: DistributionMerkleProof = { ...proof, priceOverride: 1n };
// @ts-expect-error full original resolver encoding is proof groups, not a single proof row
encodeDistributionMerkleProofs([proof]);
// @ts-expect-error actual Ledger coordinate is required for workflow/proof context
prepareDistributionMerkleCall(originalContext, caller, input);
// @ts-expect-error fees retain uint256 bigint precision
prepareDistributionMerkleCall(context, caller, { ...input, revealFeePerTokenWei: 7 });
// @ts-expect-error immutable caller
distribute.caller = receiver;
// @ts-expect-error immutable nested proof groups
distribute.input.proofs[0]!.push(proof);
// @ts-expect-error original manifest contents are retained immutably
program.manifest.tokens[0]!.beneficiary = receiver;
// @ts-expect-error immutable decoded sibling sequence
decoded[0]![0]!.proof.push(hash);
// @ts-expect-error immutable ordered allowance entries, including duplicate accounts
tree.entries.push(tree.entries[0]!);
// @ts-expect-error projection is supplied-fact arithmetic, not a Number result
const roundedTotal: number = projected[0]!.projected;
// @ts-expect-error normalization does not attest RPC provenance
const verifiedFacts: true = program.factsVerified;

void [getter, applicationHash, leaf, resolverData, total];
