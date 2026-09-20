import type { Address, Hex } from "../src/generated/contracts.js";
import { normalizeSplitFactorySnapshot, normalizeSplitProfile, prepareSplitFactoryCall, prepareSplitProfile,
  splitWalletReleaseRevocationTypedData, splitWalletReleaseTypedData,
  type SplitEntry, type SplitFactoryContext, type SplitFactorySnapshot, type SplitProfile,
  type SplitWalletReleaseAuthorization, type SplitWalletReleaseRevocation } from "../src/current-split-factory.js";

declare const snapshot: SplitFactorySnapshot;
declare const context: SplitFactoryContext;
declare const entries: readonly SplitEntry[];
declare const address: Address;
declare const hash: Hex;
declare const release: SplitWalletReleaseAuthorization;
declare const revocation: SplitWalletReleaseRevocation;
const profile: SplitProfile = prepareSplitProfile(context, entries, hash);
normalizeSplitFactorySnapshot(snapshot);
normalizeSplitProfile(profile);
const plan = prepareSplitFactoryCall(snapshot, address, { kind: "create-profile", profile });
const payload = splitWalletReleaseTypedData(snapshot, profile, release);
splitWalletReleaseRevocationTypedData(snapshot, profile, revocation);
const predicted: Address = profile.wallet;
const identity: Hex = profile.profileId;
const onlyPrediction: true = plan.predictionOnly;
const amount: bigint = payload.message.releasableSnapshot;
void predicted; void identity; void onlyPrediction; void amount;

// @ts-expect-error original uint256/uint16 coordinates must remain bigint
prepareSplitProfile({ ...context, walletVersion: 4 }, entries, hash);
// @ts-expect-error split shares are exact uint32 bigint values
prepareSplitProfile(context, [{ account: address, sharePpm: 1000000, labelId: hash }], hash);
// @ts-expect-error no clone initializer target is exposed as a factory action
prepareSplitFactoryCall(snapshot, address, { kind: "initialize", profile });
// @ts-expect-error a profile hash alone cannot stand in for the full reviewed profile
prepareSplitFactoryCall(snapshot, address, { kind: "deploy-wallet", profile: hash });
// @ts-expect-error implementation pins cannot be bare addresses
normalizeSplitFactorySnapshot({ ...snapshot, implementation: address });
// @ts-expect-error predicted wallet is immutable and does not establish deployment
profile.wallet = address;
// @ts-expect-error profile entries cannot mutate after preparation
profile.entries.push({ account: address, sharePpm: 1n, labelId: hash });
// @ts-expect-error nested entry shares are immutable
profile.entries[0]!.sharePpm = 1n;
// @ts-expect-error supplied runtime pins are immutable
plan.snapshot.context.runtimeCodeHash = hash;
// @ts-expect-error release verifier is derived from the profile rather than a caller-selected address
splitWalletReleaseTypedData(snapshot, address, release);
// @ts-expect-error original signing deadline is uint64 bigint
splitWalletReleaseTypedData(snapshot, profile, { ...release, deadline: 1 });
// @ts-expect-error factory verifier is not a signed release message field
splitWalletReleaseTypedData(snapshot, profile, { ...release, verifyingContract: address });
// @ts-expect-error revocation does not authorize a recipient or amount
splitWalletReleaseRevocationTypedData(snapshot, profile, { ...revocation, recipient: address });
// @ts-expect-error release message is immutable after normalization
payload.message.recipient = address;
