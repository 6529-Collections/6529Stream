import type { Address, Hex } from "../src/generated/contracts.js";
import {
  prepareRevenuePullCall, normalizeRevenuePullCall, revenuePullSafePlan,
  revenuePullEntitlement,
} from "../src/current-revenue-pull.js";
import type { RevenuePullRequest } from "../src/current-revenue-pull.js";

declare const address: Address;
declare const hash: Hex;
const requests: readonly RevenuePullRequest[] = [
  { kind: "syncAsset", asset: address },
  { kind: "release", asset: address, account: address, recipient: address },
  { kind: "releaseWithAuthorization", authorization: { asset: address, account: address,
    recipient: address, releasableSnapshot: 1n, nonce: hash, deadline: 1n }, signature: hash },
  { kind: "revokeReleaseAuthorization", nonce: hash },
  { kind: "revokeReleaseAuthorizationBySignature", account: address, nonce: hash, deadline: 1n, signature: hash },
  { kind: "claimMany", claims: [], continueOnFailure: true },
  { kind: "syncAndClaimMany", claims: [{ wallet: address, asset: address, account: address }], continueOnFailure: false },
];
const prepared = normalizeRevenuePullCall(prepareRevenuePullCall(address, address, requests[0]!));
const verified: false = prepared.factsVerified;
const safe = revenuePullSafePlan(1n, prepared, "Review");
const operation: 0 = safe.steps[0]!.transaction.operation;
const owed: bigint = revenuePullEntitlement(1n, 0n, 1000000n, 0n).releasable;
// @ts-expect-error no public factory-only initialize route
prepareRevenuePullCall(address, address, { kind: "initialize" });
// @ts-expect-error signed deadline uses exact bigint
prepareRevenuePullCall(address, address, { kind: "revokeReleaseAuthorizationBySignature", account: address, nonce: hash, deadline: 1, signature: hash });
// @ts-expect-error immutable actual caller
prepared.caller = address;
// @ts-expect-error no arbitrary recipient in a router claim
prepareRevenuePullCall(address, address, { kind: "claimMany", claims: [{ wallet: address, asset: address, account: address, recipient: address }], continueOnFailure: true });
// @ts-expect-error no native value parameter
prepareRevenuePullCall(address, address, { kind: "syncAsset", asset: address, value: 1n });
void [verified, operation, owed];
