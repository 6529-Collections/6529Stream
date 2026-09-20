import type { Address, Hex } from "../src/generated/contracts.js";
import { normalizeMintPhasePolicyInput, mintPhasePolicyHash, normalizeMintPolicySnapshot, prepareMintPolicyGraceChange,
  normalizeMintPolicyGracePlan, mintPolicyGraceGovernanceBatch, normalizeMintPolicyGraceGovernanceBatch,
  assertMintPolicyGraceDeadline, type MintPhasePolicyInput, type MintPolicySnapshot, type MintPolicyGraceRequest,
  type MintPolicyGraceGovernanceWindow } from "../src/current-mint-policy-grace.js";
declare const input: MintPhasePolicyInput;
declare const snapshot: MintPolicySnapshot;
declare const request: MintPolicyGraceRequest;
declare const window: MintPolicyGraceGovernanceWindow;
declare const address: Address;
declare const hash: Hex;
normalizeMintPhasePolicyInput(input);
const policy: Hex = mintPhasePolicyHash(input);
normalizeMintPolicySnapshot(snapshot);
const plan = prepareMintPolicyGraceChange(snapshot,request);
normalizeMintPolicyGracePlan(plan);
const actionClass: 1n = plan.actionClass;
const unverified: false = plan.factsVerified;
const batch = mintPolicyGraceGovernanceBatch(plan,address,1n,window);
normalizeMintPolicyGraceGovernanceBatch(batch);
assertMintPolicyGraceDeadline(request.graceUntil,1n);
void policy; void actionClass; void unverified;
// @ts-expect-error hashing the preview does not supply the required current hash
prepareMintPolicyGraceChange(input,request);
// @ts-expect-error source timestamps are exact bigints
prepareMintPolicyGraceChange(snapshot,{...request,graceUntil:1});
// @ts-expect-error no expected-policy compare-and-swap parameter exists
prepareMintPolicyGraceChange(snapshot,{...request,expectedPolicyHash:hash});
// @ts-expect-error Core is not an original policy preimage coordinate
mintPhasePolicyHash({...input,core:address});
// @ts-expect-error grace never enters policy identity
mintPhasePolicyHash({...input,graceUntil:1n});
// @ts-expect-error original collection IDs retain uint256 precision
mintPhasePolicyHash({...input,collectionId:1});
// @ts-expect-error immutable nested snapshots cannot be mutated after construction
plan.snapshot.counterConfigs[0]!.staticCap = 1n;
// @ts-expect-error no caller can replace the sorted reviewed executor set
plan.prospectiveExecutors.push(address);
// @ts-expect-error preparation does not assert verified live facts
plan.factsVerified = true;
// @ts-expect-error original governance nonce is uint256 bigint
mintPolicyGraceGovernanceBatch(plan,address,1,window);
// @ts-expect-error scheduling parameters cannot alter the fixed class1
mintPolicyGraceGovernanceBatch(plan,address,1n,{...window,actionClass:0n});
// @ts-expect-error execution time is explicit full-width bigint
assertMintPolicyGraceDeadline(1n,1);
// @ts-expect-error governance envelope remains immutable
batch.window.reasonURI = "changed";
