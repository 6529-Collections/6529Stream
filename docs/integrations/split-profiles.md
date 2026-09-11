# Registering and deploying split profiles

This guide describes the full-v1 development factory. It is not a claim that
these changes are installed in the earlier supported release candidate.

`registerProfile(entries, metadataURIHash)` validates and stores immutable
canonical split terms, returning the profile ID and predicted wallet address.
It does not deploy the wallet, accept value, transfer tokens, or create official
sale accounting. Anyone, including a Safe, can register the same terms; repeated
canonical registration returns the same result without another index or event.

`deployWallet(profileId)` deploys and initializes the official deterministic
wallet for a registered profile. `createProfile(entries, metadataURIHash)` remains
the atomic convenience operation: register the terms and deploy the wallet in
one transaction. If first-time creation fails, its registration also rolls back.
If a separately registered profile later fails deployment, its stored terms and
enumeration position remain available.

Check `profileExists(profileId)` to determine whether terms are registered.
Check `splitWalletExists(profileId)` to verify the deployed wallet's code and
profile identity. A predicted address with no code, an address holding funds,
or a poisoned address with unrelated code is not a verified wallet. Primary
resolver assignment still requires a verified deployed wallet.

```solidity
(bytes32 profileId, address predicted) = factory.registerProfile(entries, metadataHash);
assert(factory.profileExists(profileId));
// Deployment can occur in a later transaction.
address wallet = factory.deployWallet(profileId);
assert(wallet == predicted && factory.splitWalletExists(profileId));
```

Native currency and standard ERC-20 tokens sent to a predicted address remain
there when the wallet is deployed and become observable wallet receipts. They
are donations/direct receipts, not evidence of an official sale. Token release
still follows the wallet's asset-policy rules. A failed deployment does not
provide another destination or a recovery authority for those funds.

Enumerate profiles at a pinned block using `profileCount()`, then `profileAt(i)`
and `walletAt(i)` for `0 <= i < count`. The index is append-only and includes
profiles whose wallet is undeployed. `walletAt(i)` always equals
`walletFor(profileAt(i))`; out-of-range access reverts. No logs are needed for
this complete profile/address inventory. `SplitProfileCreated` emits once per
registration. `SplitProfileEntry`, `SplitWalletDeployed`, and
`SplitWalletDiscovered` include the normative `uint16 schemaVersion` field;
indexers must use the ABI for this factory deployment line.

The factory constructor takes the asset-policy registry, the actual governed
parameter authority, and three `GasParameterConfig` entries in this exact order:

1. `ERC_1271_GAS_LIMIT`
2. `ASSET_POLICY_GAS_LIMIT`
3. `WALLET_DEPOSIT_GAS_LIMIT`

Each uses `FAIL_CLOSED_PRECHECK`; values and positive immutable floors are
explicit constructor inputs. Raises retain the existing exact delayed
Governance-V2 authorization. Operational gas values are excluded from profile
and wallet-address preimages. Registering the deposit parameter does not by
itself migrate settlement/escrow callers to it. The test fixture's 50,000 genesis
value and 25,000 floor are planning inputs, not the all-cold release sizing
evidence required by [RSR-GGP](../revenue-splits-and-royalties.md).

Focused tests are in
[StreamSplitFactoryRegistration.t.sol](../../test/unit/revenue/StreamSplitFactoryRegistration.t.sol).
They include actual Safe 1.4.1 execution of the new selectors and real wallet
payouts; the target-side authority fixture does not replace current-stack Safe
and Executor timelock integration tests.
