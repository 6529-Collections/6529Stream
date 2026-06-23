# Revenue Splits And Royalties

This document is a pre-launch target specification for 6529Stream revenue
splits and royalties. 6529Stream has not launched, so this architecture should
be implemented as the initial production revenue and royalty system rather than
as a later retrofit layer.

The proposed architecture is captured as ADR
`docs/adr/0008-revenue-splits-and-royalty-resolver.md`.
The cross-cutting 50+ year architecture principles live in
`docs/stream-long-term-architecture.md`.

## Design Summary

6529Stream should keep the NFT core stable and move long-term revenue policy
into satellite contracts.

```text
StreamCore
  - ERC-721 ownership
  - token to collection identity
  - mandatory minimal resolver-backed ERC-2981

StreamRevenueResolver
  - default, collection, and token assignment resolution
  - primary sale profile resolution
  - royalty profile and bps resolution

StreamSplitFactory
  - deterministic split wallet deployment
  - profile hash and profile ID validation

StreamSplitWallet
  - immutable arbitrary split profile
  - native ETH and ERC-20 pull release
  - passive royalty receipt support

StreamLabelRegistry
  - optional human-readable label metadata
  - no accounting authority
```

The design uses immutable split profiles and mutable assignments. Profiles say
who gets paid. Assignments say which profile applies to a default, collection,
or token scope.

## Launch Scope

Launch scope is deliberately narrower than the long-term design surface:

1. Native ETH primary-sale settlement.
2. Native ETH ERC-2981 royalty receipts through split wallets.
3. Approved standard ERC-20 primary-sale settlement through outside-Core
   payment adapters.
4. Approved standard ERC-20 release support inside split wallets.
5. Default, collection, and token scoped revenue assignments.
6. Immutable split profiles up to the v1 entry/account limits.
7. Core-native resolver-backed ERC-2981.
8. Mint-time token royalty snapshots when a collection policy requires
   mint-time economics to persist.

Non-launch unless a later ADR accepts the added risk:

1. Fee-on-transfer, rebasing, callback, pausable-without-standard-reason, or
   other non-standard ERC-20 primary-sale adapters.
2. Merkle/accounting adapters for very large split distributions.
3. Ordinary dust sweeps or decommission withdrawals.
4. Royalty enforcement by transfer restriction.
5. Marketplace registry override as the primary royalty path.

## Implementation Status

The first v1 implementation slice adds `StreamSplitFactory` and
`StreamSplitWallet` as outside-Core satellites. This slice is intentionally
fixed-profile and native-ETH only:

- `StreamSplitFactory` validates and canonicalizes immutable split entries,
  computes the ADR 0008 profile ID with `abi.encode`, stores reconstructable
  profile metadata, and deploys or discovers deterministic wallets with
  `CREATE2`.
- `StreamSplitWallet` has factory-bound one-shot initialization, stores
  immutable entries and aggregate account shares, accepts passive native ETH,
  computes releasable funds from cumulative observed receipts, and releases
  native ETH through pull payments.
- The slice spends no `StreamCore` bytecode and does not wire into fixed-price
  drops, auctions, revenue resolver assignments, escrow, or ERC-2981.
- ERC-20 asset policy, ERC-20 observation/release, resolver assignments,
  primary-sale adapters, escrow, and Core-native resolver-backed ERC-2981
  remain subsequent launch work.

## Long-Term Principles

1. The NFT core should preserve ownership and metadata truth, not carry every
   future revenue policy.
2. Primary-sale and royalty economics are separate policies.
3. Labels are open vocabulary and must not be hardcoded forever.
4. Split profiles are immutable once created.
5. Assignments are mutable only until frozen.
6. All recipient payments are pull-based.
7. Passive royalty receipts must still be accountable.
8. Direct or forced ETH must not let admins sweep owed funds.
9. Events and reads must reconstruct historical policy.
10. Royalty disclosure is not royalty enforcement.
11. Core-native ERC-2981 is mandatory for launch; royalty registry overrides are
    not a launch substitute.
12. Collections may be fixed-size, capped-open, or uncapped-open. Revenue policy
    must not require final collection size to be known at collection creation.
13. The launch Core must not keep a second royalty source of truth through
    OpenZeppelin `ERC2981` storage.
14. Every contract pointer that can affect revenue resolution must follow ADR
    0004 pointer governance before it can be changed or frozen.

## Split Profile Model

Each profile has entries:

```solidity
struct SplitEntry {
    address account;
    uint32 sharePpm;
    bytes32 labelId;
}
```

`sharePpm` uses a denominator of `1_000_000`. The profile sum must be exactly
`1_000_000`.

Labels are arbitrary:

```text
keccak256("artist")
keccak256("artist-estate")
keccak256("collaborator-video")
keccak256("curator-round-2039")
keccak256("museum-endowment")
keccak256("restoration-fund")
```

These examples are not a closed set. A future label can be anything. The label
does not control payment rights; the account and split share do.

If a label registry is used, it should be append-only or supersession-based.
Replacing the registry must not orphan historical `labelId` meanings. A later
label display name can supersede an earlier display name, but accounting and
historical event interpretation remain bound to the original `bytes32 labelId`.
Label registry reads are never part of payment correctness. Registry
unavailability, revert, replacement, or stale metadata must not block
`release`, `syncAsset`, `flushEscrow`, primary settlement, or `royaltyInfo`.
Wallet math uses only immutable profile entries.

The same account may appear more than once under different labels when the
profile intentionally records multiple roles. The same `(account, labelId)`
pair must not appear twice.

The recommended initial wallet limit is 64 entries and 64 unique accounts.
That is an implementation limit, not a protocol philosophy limit: larger
future distributions should use a new wallet version, Merkle/accounting
adapter, or another reviewed mechanism instead of unbounded loops.

Entries are canonicalized by `(account, labelId, sharePpm)` before hashing and
encoded as an `abi.encode` array of `SplitEntry` values. Implementations must
not use packed encodings, string encodings, or display order for the entries
hash.
The wallet stores a deduplicated account index derived from the entries:

```text
uniqueAccounts[] = deduplicated accounts from entries
aggregateSharePpm(account) = sum sharePpm for that account
sum(aggregateSharePpm(account)) = 1_000_000
```

The profile ID preimage is fixed for this wallet version:

```solidity
bytes32 profileId = keccak256(abi.encode(
    PROFILE_DOMAIN,
    uint256(block.chainid),
    address(factory),
    uint16(schemaVersion),
    uint16(walletVersion),
    bytes32(splitWalletInitCodeHash),
    bytes32(splitWalletRuntimeCodeHash),
    bytes32(entriesHash),
    bytes32(metadataURIHash)
));
```

The profile ID intentionally binds the deployment line and wallet code, not
just the economic percentages.

For v1, entries are not constructor arguments. The factory uses a fixed-runtime
minimal proxy or equivalent clone. It deploys the wallet with `CREATE2`, then
initializes profile storage exactly once in the same transaction. The profile is
immutable after initialization because the wallet exposes no mutator for
entries, aggregates, profile ID, or metadata hash. A future constructor-args or
immutable-args wallet needs a new wallet version and profile preimage.
The wallet initializer must have a one-call guard and revert on any second
initialization attempt. It must be callable only by the official factory during
the deployment/initialization flow; a directly deployed clone or externally
called initializer is not a valid split wallet.

A verified split wallet means all of the following are true: the wallet equals
`factory.walletFor(profileId)`, the profile was created by the factory, the
wallet was deployed through the bound factory init code, `wallet.profileId()`
equals the expected profile ID, and the runtime code hash is active or otherwise
eligible for the specific escrow credit being flushed.

## Payment Accounting

Split wallets account from cumulative receipts:

```text
observedReceived(asset) = currentBalance(asset) + totalAccountReleased(asset)
aggregateShare(account) = sum sharePpm for entries with account
releasable(account, asset) =
  floor(observedReceived(asset) * aggregateShare(account) / 1_000_000)
  - released(account, asset)
```

`released(account, asset)` is keyed by the entitled account, not by the payout
recipient. Releasing to an alternate recipient still debits the entitled
account. If the same account appears under several labels, the wallet aggregates
that account's labels into one entitlement for release math.

Assignment repointing never mutates an existing split profile or moves balances
out of an old split wallet. If an account was entitled under an old wallet, that
account remains able to claim from that wallet forever, subject only to the
wallet's immutable accounting rules and any separately specified incident
recovery path for stranded escrow. New assignments affect only new receipts.

This supports:

- ordinary primary-sale deposits;
- passive ERC-2981 royalty transfers;
- direct ETH sends;
- forced ETH;
- ERC-20 receipts.

Rounding dust remains in the wallet. It is not emergency surplus and the v1
split wallet should not include an ordinary dust sweep. This preserves
cumulative entitlement fairness when later passive royalties, direct ETH, or
forced ETH arrive.

```text
roundingDust(asset) =
  currentBalance(asset)
  - sum(releasable(account, asset) for account in uniqueAccounts)
```

For approved standard assets after successful observation, rounding dust should
be non-negative and less than the number of unique accounts. The normative
safety property is no over-release:
`sum(released) + sum(releasable) <= externalReceived` in the test harness.
Here `externalReceived` is the harness/indexer ground truth from official
deposits, direct transfers, and forced ETH, while on-chain releasable values are
computed from `observedReceived = currentBalance + totalAccountReleased`. The
tighter equality
`externalReceived - sum(released) - sum(releasable) == roundingDust(asset)`
is required only after on-chain observation has caught up so
`observedReceived == externalReceived`. Entitlements must always be recomputed
from cumulative `observedReceived`; incremental per-receipt allocation is not a
valid implementation for this wallet version. Because the floor is applied to
cumulative observed receipts, rounding dust does not accumulate across receipts.
Any future final dust sweep needs its own decommissioning spec because later
marketplace or forced receipts can still arrive.

Releases use checks-effects-interactions. If a native ETH or ERC-20 transfer
fails, the transaction reverts and the entitlement remains claimable. The
native asset sentinel in events and views is `address(0)`.
Native ETH and each ERC-20 asset are independently keyed in release, observed,
and escrow accounting. No asset balance may be used to satisfy another asset's
release or escrow obligation.
The wallet uses one release reentrancy guard across all assets and recipients,
not a per-asset lock. A native ETH recipient cannot reenter to release ERC-20s,
and an ERC-20 callback cannot reenter to release native ETH or another token.

Release authorization:

1. Anyone may call `release(asset, account, account)` to move an entitled
   account's releasable funds to that same account. This supports keepers and
   recipient discovery without creating theft risk.
2. Releasing to any alternate recipient requires `msg.sender == account` or a
   valid EIP-712/ERC-1271 `ReleaseAuthorization` signed by the entitled account
   with asset, account, recipient, wallet, chain ID, nonce, and deadline.
3. The wallet consumes release-authorization nonces before transfer under CEI.
4. A relayer cannot change the asset, account, recipient, amount mode, nonce,
   deadline, or destination wallet named by the authorization.
5. ERC-1271 verification for alternate-recipient release uses a deploy-time
   immutable `ERC_1271_GAS_LIMIT`, `staticcall`, and bounded returndata
   decoding. A failed, out-of-gas, malformed, or wrong-magic-value
   `isValidSignature` staticcall reverts the alternate release before nonce
   consumption or transfer. The initial
   planning cap is 50,000 gas, but launch uses measured gas plus margin and
   records it in the release manifest.
6. `syncAsset` shares the same wallet-wide reentrancy guard as `release`.
   Operators should sync before release when they want a clean observation
   transaction; reentrant sync during an active release reverts.

### Native ETH Observation Lifecycle

The split wallet `receive()` function must not update
`lastObservedReceived(address(0))`. Native ETH observation is lazy:
`lastObservedReceived(address(0))` is updated only during
`release(address(0), ...)` or `syncAsset(address(0))`.

On the first release or sync for native ETH:

1. Compute `observedReceived = address(this).balance + totalAccountReleased`.
2. Initialize `lastObservedReceived(address(0))` to that value, even if it is
   zero.
3. Emit `AssetObservationInitialized`.

On later native ETH release or sync:

1. Compute `observedReceived = address(this).balance + totalAccountReleased`.
2. Revert if `observedReceived < lastObservedReceived(address(0))`.
3. Skip observation events if the value is unchanged.
4. Update `lastObservedReceived(address(0))` when the cumulative value
   increases.

During native ETH release, the wallet computes the pre-release observed value,
updates release state, performs the transfer, and then verifies that
`postBalance + updatedTotalAccountReleased` equals the same observed value.
This proves the release did not change cumulative receipts. Direct ETH,
royalty ETH, forced ETH, and official deposits all become part of the same
cumulative observed native balance once observed.

### Split Wallet Conservation Proof

For each asset, v1 split wallets compute account entitlement from cumulative
observed receipts, not from incremental per-receipt allocation:

```text
observedReceived = currentBalance + totalAccountReleased
entitlement(account) = floor(observedReceived * aggregateSharePpm(account) / 1_000_000)
releasable(account) = entitlement(account) - released(account)
```

Let `A` be the set of unique entitled accounts after aggregating all labels for
the same account. Let `S(a)` be each account's aggregate share. The profile
validates:

```text
sum(S(a) for a in A) = 1_000_000
```

Therefore:

```text
sum(floor(observedReceived * S(a) / 1_000_000) for a in A)
<= floor(observedReceived * sum(S(a)) / 1_000_000)
= observedReceived
```

The difference is rounding dust. Because each account receives at most one
floor operation after label aggregation, rounding dust is bounded by
`uniqueAccounts - 1` for an observed balance snapshot. The same account may
appear under multiple labels, but those labels are aggregated before the floor,
so a recipient cannot create extra rounding loss or extra entitlement by using
many labels.

Release order does not change entitlement. After a release, `currentBalance`
decreases and `totalAccountReleased` increases by the same amount, so
`observedReceived` is unchanged. Later passive royalties, direct ETH, forced
ETH, or approved standard ERC-20 receipts increase `currentBalance`, and every
account's entitlement is recomputed from the new cumulative value.

Normative invariant:

```text
sum(released(account)) + sum(releasable(account)) + roundingDust
= observedReceived
```

for standard assets after observation has caught up. Implementations must use
`mulDiv`-style arithmetic for `observedReceived * aggregateSharePpm` and must
not rely on unchecked multiplication or overflow reverts as ordinary control
flow.

For ERC-20s, v1 accounting is correct only for approved standard
monotonic-balance tokens whose wallet balance cannot decrease except through
wallet-initiated releases. The wallet tracks `lastObservedReceived(asset)`
during release and `syncAsset`; if
`currentBalance + totalAccountReleased` falls below the last observed value,
release and sync for that asset revert as unsupported instead of underflowing
or reducing entitlements.
`lastObservedReceived(asset)` is initialized at first detection through
`syncAsset`, official deposit, or release; operator and recipient tools should
sync ERC-20 assets before presenting claimable balances.
Unknown ERC-20s sent directly before first observation are unsupported for
historical guarantees; the wallet can only account from the first observed
balance. If governance later approves that asset and `syncAsset(asset)` first
observes a positive wallet balance, that observed balance becomes the starting
cumulative balance for future releases; the wallet cannot prove who funded
pre-observation transfers or apply historical source attribution before that
first observation. ERC-20 releases must also prove exact wallet balance deltas:
the wallet balance must decrease by exactly the released amount. Recipient
balance-delta checks belong in asset-specific adapters when reliable; they are
not a generic ERC-20 requirement. No-op transfers, fee-on-transfer behavior,
rebases, callbacks, and other non-standard behavior are unsupported unless a
later adapter accepts them.

ERC-20 assets are default-deny. Asset policy is deployment-wide, not per wallet.
The split factory records the immutable `assetPolicyRegistry` for its wallet
line, and v1 wallets consult that registry during non-native `syncAsset` and
`release`. Native ETH is always supported without a registry read. If the
registry is unavailable or an asset is unknown, non-native sync/release reverts
safely for that asset only; native ETH and other active assets remain
unaffected.

The registry read is a bounded external read. The wallet factory must pin
`ASSET_POLICY_GAS_LIMIT`, `ASSET_POLICY_RETURN_BYTES`, and an
EIP-150-aware parent gas precheck in the wallet-line manifest. Malformed
return data, no code at the registry, registry revert, oversized returndata,
or under-forwarded gas makes the specific non-native `syncAsset` or `release`
revert before ledger mutation. The wallet must not substitute "active" or
"native" semantics when the asset policy read fails.
Initial planning target for `ASSET_POLICY_GAS_LIMIT` is 30,000 gas for an
all-cold storage-read policy lookup, with the deployed value set from measured
gas plus margin.
Because the factory binds `assetPolicyRegistry` immutably for a wallet line, an
asset-policy registry that no longer satisfies future EVM or gas-schedule
constraints is handled by a new split-wallet/factory deployment line and
governed reassignment for future receipts. Existing wallet balances remain in
the old wallet line; there is no hidden mutable registry pointer inside
deployed wallets.

Recommended asset policy read:

```solidity
interface IStreamAssetPolicyRegistry {
    function assetPolicy(address asset)
        external
        view
        returns (
            uint8 status,
            bytes32 policyHash,
            uint64 effectiveAt
        );
}
```

An asset admin can approve a standard ERC-20, deprecate approval for future
receipts, or mark an observed asset unsupported. Asset state is explicit:

- `ACTIVE`: official adapters may accept the asset, and sync/release is allowed.
- `DEPRECATED`: new official adapters should not accept the asset, but existing
  observed balances and later passive receipts remain syncable and releasable
  under the same monotonic-token assumption.
- `UNSUPPORTED`: release and sync for that asset are disabled until a later
  adapter or recovery spec accepts the asset. Unsupported marking creates no
  sweep right and blocks no other asset.

Moving an ERC-20 asset to `ACTIVE` is an asset-policy decision, not an automatic
token-interface check. The policy admin should record evidence that the token
has no transfer fees, rebases, confiscation mechanics, balance-decreasing hooks,
callback surprises, or no-op transfer behavior that would violate the
monotonic-balance assumption. Unsupported-asset recoverability is deferred to a
future state transition or adapter or recovery spec; the v1 unsupported state is
not a sweep authority.

If an ERC-20 moves `DEPRECATED -> ACTIVE` after a period of unsupported or
deprecated operation, equality conservation is re-established only after the
next successful `syncAsset(asset)` observation. Between transitions, the
required safety property is no over-release; exact equality to external ground
truth may require indexer/operator reconciliation.

`syncAsset(asset)` uses this ordering: initialize and emit on the first call
even at zero balance; otherwise revert if
`currentBalance + totalAccountReleased < lastObservedReceived`; otherwise skip
emission if unchanged; otherwise update `lastObservedReceived` and emit the new
observed cumulative state.
During release, `lastObservedReceived(asset)` is updated only from the
pre-release observed value or the post-transfer balance plus updated release
totals, never from an intermediate CEI state. ERC-20 release ordering is:
compute entitlement, update the release ledger, transfer with safe-transfer
handling, prove the wallet balance decreased by exactly the released amount,
then set `lastObservedReceived` to the post-transfer observed value. If the
delta check fails, the transaction reverts and restores the ledger and observed
state. The balance-decrease guard is a best-effort detector for unsupported
tokens; the v1 correctness guarantee applies only to approved standard
monotonic-balance assets. A governance-gated
`markUnsupportedAsset(asset)` path may freeze only that asset without enabling
any sweep or blocking ETH and other assets. Unsupported marking disables release
and sync for that asset until a later asset-specific adapter or recovery spec
is accepted.

## Open-Ended Collections And Revenue Epochs

The permanent Stream contract must support collections whose final size is not
known in advance. A photographer may create a named subcollection inside
Stream, add works over many years, pause it, resume it, and eventually close it
or leave it ongoing.

Revenue and royalty policy must therefore be independent of final collection
supply.

### Token ID Model

For launch, Core should allocate global sequential ERC-721 token IDs and store
explicit mappings:

```solidity
mapping(uint256 tokenId => uint256 collectionId) tokenCollectionId;
mapping(uint256 tokenId => uint256 collectionSerial) tokenCollectionSerial;
mapping(uint256 tokenId => bool mappingExists) tokenCollectionMappingExists;
```

The current namespaced `collectionId * 10_000_000_000 + serial` formula should
be removed before launch. It is useful historical context from the current
code, but it is not the target identity model.

Rules:

1. `StreamCore` owns token ID allocation.
2. Minter, drop, and auction contracts do not pass arbitrary token IDs into
   Core.
3. Collection-local serials are stable display/accounting facts, not token ID
   codecs.
4. `royaltyInfo()` uses the explicit mapping when it needs collection-scope
   resolution.
5. Unmapped token IDs fall back only to default royalty assignment or zero.
6. Burned tokens keep their last token-to-collection mapping for historical
   royalty disclosure. Burning removes ERC-721 ownership and enumerable
   membership, but Core must not clear `tokenCollectionId`,
   `tokenCollectionSerial`, or `tokenCollectionMappingExists`.

Rules:

1. Collection-scope assignments apply to all tokens in the collection unless a
   token-level assignment exists.
2. A collection can receive new primary and royalty assignments while it remains
   open, unless the relevant assignment scope is frozen.
3. Primary-sale economics are materialized at sale or mint settlement. Historical
   primary proceeds never change when a collection assignment changes later.
4. Royalty assignments are read at `royaltyInfo()` time. If the product wants a
   token to preserve the economics that were active at mint, the minter or sale
   contract should write a token-level royalty assignment at mint.
5. If no token-level royalty snapshot exists, a token follows the current
   collection assignment, then default assignment.
6. Closing a collection does not itself freeze revenue policy. Revenue freezes
   are explicit resolver actions.
7. Sale IDs identify drops, auctions, or other primary events inside a
   collection. They are not collection IDs and must not imply final supply.
8. Assignment and revenue events must include both `collectionId` and `tokenId`
   when a token is known. For collection-level sale events before token
   allocation, the event must include a later token allocation event or a
   same-transaction allocation reference. Launch v1 does not define a
   standalone premint reservation API.

Each collection should declare its royalty policy mode before public mint:

```text
ROYALTY_LIVE_COLLECTION     tokens follow current token/collection/default assignment
ROYALTY_SNAPSHOT_AT_MINT    mint writes token-level royalty assignment snapshot
```

The policy mode is evented and frozen with collection economics when the
collection promises permanent economics. Collectors and indexers must be able to
read whether a token follows live collection policy or a mint-time snapshot.

### Mint-Time Royalty Snapshots

When a collection wants mint-time royalty economics to persist, the sale or mint
settlement path must atomically create a token-level royalty assignment after
Core allocates the token ID and before the transaction completes.

Recommended resolver hook:

```solidity
function snapshotTokenRoyaltyAtMint(
    uint256 tokenId,
    uint256 collectionId,
    bytes32 revenueClass,
    bytes32 expectedCollectionAssignmentHash
) external returns (bytes32 tokenAssignmentHash);
```

Rules:

1. Only the authorized mint manager, drop contract, auction contract, or Core
   mint boundary can call the snapshot hook.
2. The hook is idempotent for the same token and same expected assignment.
3. The hook reverts if a different token-level royalty assignment already
   exists.
4. The hook verifies that `tokenId` maps to `collectionId` in Core.
5. The hook snapshots the resolved collection/default assignment into a fixed
   token-level assignment.
6. The snapshot write is O(1).
7. A failed snapshot reverts the mint or sale if the active policy requires a
   mint-time royalty snapshot.
8. If the active policy does not require snapshots, the token follows current
   collection/default royalty assignment at `royaltyInfo()` time.
9. The hook targets only the configured revenue resolver pointer and is
   non-reentrant into mint manager, mint ledger, Core mint, and escrow paths.
10. Snapshot completion precedes `_safeMint` for tokens whose royalty policy
    requires mint-time economics. A malicious or replaced resolver cannot
    observe or reenter an in-progress mint before the recipient callback.

Recommended revenue-class examples for long-running collections:

```text
PRIMARY_FIXED_PRICE
PRIMARY_AUCTION
PRIMARY_DROP_2034
ROYALTY_ERC2981
CURATOR_RESERVE_RELEASE
```

The `PRIMARY_DROP_2034` example is not a required class. It illustrates that
future sale programs can use new open `bytes32` revenue classes without a Core
redeploy.

## Primary Sales

Primary-sale settlement should resolve a primary revenue assignment:

```text
token assignment
collection assignment
contract default assignment
```

Signed sale authority must bind the economic policy being used. For fixed-price
drops and auctions, the signed authorization should include:

```text
revenueClass
expectedPrimaryPolicyHash
primaryPolicyMode
initialRecipientsHash
beneficiariesHash
payer
executor
saleId or authorization nonce
```

`expectedPrimaryPolicyHash` is the resolver's hash of the assignment or
template expected by the signer at authorization time. `primaryPolicyMode`
should be one of:

```text
STRICT_MATCH      settlement reverts unless the resolved policy hash matches
ALLOW_CURRENT     signer explicitly accepts settlement-time current policy
```

Launch default should be `STRICT_MATCH` for economically material sales.
`ALLOW_CURRENT` is useful only for intentionally mutable sale programs and must
be visible in the signed payload and settlement event. This prevents governance
or operators from changing primary-sale economics between signature and
settlement without the signer having opted into that mutability.
If a scope freezes between signature and settlement, `ALLOW_CURRENT` resolves
the then-current frozen assignment. That is acceptable only because the signer
explicitly chose current-policy drift; `STRICT_MATCH` remains the default for
economically material sales.
Settlement events must expose whether drift was observed between the signed
`expectedPrimaryPolicyHash` and the resolved settlement policy.
The resolved primary policy hash includes `freezeMode` and `permanentFreeze`.
Therefore a freeze between signature and settlement changes the hash and makes
`STRICT_MATCH` revert unless the signer authorized the frozen policy hash.
`ALLOW_CURRENT` is the explicit opt-in to that drift.

No production sale path may use `tx.origin` as payer, recipient, executor, or
authorizer. The current `StreamDrops` authorization model must be rewritten
before launch so the signed sale authorization binds the actual recipient or
recipient batch, payer, executor, collection, phase/drop/auction ID, quantity,
price, nonce, deadline, and policy hash. Settlement recomputes those hashes
from calldata and chain state. A static-analysis launch gate must fail the
build if any sale, drop, auction, or mint path reads `tx.origin`.

### Normative Paid Mint Orchestration

Every paid primary mint must use exactly one of these launch paths. No third
paid mint order is launch-conformant.
A collection configured for `ROYALTY_SNAPSHOT_AT_MINT` must reject binding to a
sale adapter that supports only `PRE_REVENUE_SINGLE_STEP`. Snapshot-at-mint
collections require `PREPARED_MINT` or a later accepted orchestration that
writes the snapshot before any untrusted receiver callback.

`PRE_REVENUE_SINGLE_STEP`:

1. Sale adapter validates payment, sale authorization, price, quantity, payer,
   recipients, beneficiaries, deadline, nonce, and `expectedPrimaryPolicyHash`.
2. Sale adapter resolves only collection/default primary policy. Token-level
   primary overrides and required mint-time royalty snapshots are unavailable in
   this path.
3. Sale adapter materializes the split profile if needed and deposits native
   ETH into the verified split wallet or records escrowed revenue under
   `(revenueClass, profileId, wallet, asset)`.
4. Sale adapter calls the mint manager.
5. Mint manager validates the phase, computes active `policyHash`, verifies the
   signed `MintTicket` or equivalent sale authorization, and binds the exact
   `mintCommitmentsHash`.
6. Mint ledger verifies the manager-registered policy hash and consumes
   counters, authorization IDs, and nullifiers.
7. Core executes `mintFromManager`, registers entropy, and `_safeMint`s to the
   initial recipient.

`PREPARED_MINT`:

1. Sale adapter validates payment, sale authorization, price, quantity, payer,
   recipients, beneficiaries, deadline, nonce, and `expectedPrimaryPolicyHash`.
2. Mint manager validates the phase, computes active `policyHash`, verifies the
   signed `MintTicket` or equivalent sale authorization, and binds the exact
   `mintCommitmentsHash`.
3. Mint ledger verifies the manager-registered policy hash and consumes
   counters, authorization IDs, and nullifiers.
4. Core executes `prepareMintFromManager`, creating authoritative token identity
   and entropy registration but no ERC-721 transfer.
5. Resolver snapshots any required token-level primary or royalty assignment
   from Core's authoritative mapping.
6. Sale adapter deposits native ETH into the verified split wallet or records
   escrowed revenue under `(revenueClass, profileId, wallet, asset)`.
7. Core executes `completePreparedMintFromManager` and `_safeMint`s to the
   initial recipient.

Token-level economic snapshots written during `PREPARED_MINT` must be
derivable solely from Core token identity, collection/default assignment state,
the signed sale or mint authorization, and the active policy hashes. They must
not read, branch on, or depend on entropy seed, entropy request status, provider
result status, or renderer output, because entropy is registered but not
finalized when the snapshot is written. For a collection using
`ROYALTY_SNAPSHOT_AT_MINT`, the snapshot records the economic policy that was
authorized for the token; it does not wait for or incorporate randomness.

All steps in either path happen in one top-level transaction. A revert at any
step reverts ledger consumption, token identity, entropy registration,
assignment snapshots, and revenue accounting. No untrusted recipient callback,
randomness provider callback, refund callback, split-wallet release, or
arbitrary external hook may execute before the path's required ledger
consumption, token identity mapping, assignment snapshots, and revenue
accounting are complete.
`PREPARED_MINT` uses the canonical `STREAM_PREPARED_MINT_OPERATION_V1`
`operationId` defined in `docs/mint-policy-and-accounting.md`; the sale
adapter, manager, ledger, Core prepare/complete, resolver snapshot hook,
entropy registration boundary, and escrow/deposit path must reject mismatched
operation IDs.

The v1 primary settlement surface includes native ETH and approved standard
ERC-20 assets. ERC-20 settlement must live in a payment adapter or
primary-sale settlement module outside Core, with exact token-transfer
accounting, allowance/payment failure handling, and escrow flush rules. Split
wallets can also release approved standard ERC-20 assets received passively.
Fee-on-transfer, rebasing, callback, or otherwise non-standard ERC-20 behavior
is unsupported unless a separate adapter spec accepts it.

ERC-20 primary adapters must read the same deployment-wide
`IStreamAssetPolicyRegistry` pinned by the split factory and accept new primary
payments only for `ACTIVE` assets. The adapter must perform safe-transfer
handling, measure its own asset balance before and after payer transfer, and
revert unless the received amount exactly equals the expected sale amount.
Allowance failure, transfer failure, no-op transfer, fee-on-transfer behavior,
rebasing balance movement, callback-dependent behavior, malformed token return
data, or an unavailable asset-policy registry all revert before minting or
revenue recording. Passive split-wallet ERC-20 receipts can be observed and
released under the split-wallet accounting rules, but they are not primary-sale
settlement evidence and do not relax the adapter's exact-delta requirement.

The current three-bucket default maps naturally to a primary split template:

```text
500000 ppm dynamic SALE_POSTER
250000 ppm static protocol
250000 ppm static curators pool
```

For long-term flexibility, a future collection might instead use:

```text
700000 ppm artist
100000 ppm artist-estate
100000 ppm 6529
050000 ppm curator-pool
050000 ppm preservation-fund
```

The protocol should not need a new Solidity struct for that policy. It should
only need a new split profile or primary split template and assignment.

The current poster share is dynamic: it pays the poster attached to a specific
drop or auction, not a fixed address in a default profile. Primary assignments
therefore support primary split templates. A template entry has either a static
account or an open `bytes32 accountSource` such as `keccak256("SALE_POSTER")`.
At settlement, the sale contract resolves supported account sources from sale
context, materializes a fixed split profile, and then funds or escrows that
profile's wallet. Royalty assignments do not use dynamic account sources
because ERC-2981 does not pass sale context to the receiver.

Template IDs are deterministic:

```solidity
bytes32 templateId = keccak256(abi.encode(
    PRIMARY_TEMPLATE_DOMAIN,
    uint256(block.chainid),
    address(resolver),
    uint16(schemaVersion),
    uint16(templateVersion),
    bytes32(canonicalTemplateEntriesHash),
    bytes32(metadataURIHash)
));
```

Template entries are canonicalized by
`(staticAccount, accountSource, labelId, sharePpm)`. Exactly one of
`staticAccount` or `accountSource` must be set. V1 templates have at most 64
entries and at most 8 unique dynamic account sources. A revenue class can use a
template only when its settlement contract declares support for every
`accountSource`.

The materialized profile ID and wallet address must be deterministic from the
resolved recipient set, not from an individual sale. The materialized metadata
hash is:

```solidity
bytes32 materializedMetadataURIHash = keccak256(abi.encode(
    MATERIALIZED_PRIMARY_PROFILE_METADATA_DOMAIN,
    uint256(block.chainid),
    address(resolver),
    bytes32(templateId),
    bytes32(concreteEntriesHash)
));
```

`concreteEntriesHash` is the profile entries hash after dynamic sources are
resolved, same `(account, labelId)` pairs are aggregated, and entries are sorted
by the normal profile canonicalization rules. The materialized profile ID must
not include `saleId`, `tokenId`, payer, beneficiary, amount, or
`saleContextHash`; otherwise repeated sales with identical concrete recipients
would create unnecessary wallets.

Sale context is emitted for reconstruction only:

```solidity
bytes32 saleContextHash = keccak256(abi.encode(
    PRIMARY_SALE_CONTEXT_DOMAIN,
    uint16(saleContextVersion),
    uint256(block.chainid),
    address(settlementContract),
    bytes32(saleKind),
    uint256(saleId),
    uint256(collectionId),
    uint256(tokenId),
    address(payer),
    address(poster),
    address(beneficiary),
    address(asset),
    uint256(amount),
    bytes32(templateId)
));
```

`saleContextHash` is an event reconstruction and replay aid, not a source of
on-chain payment authority. Consumers should verify the emitted sale fields and
chain state; they must not treat arbitrary off-chain context as authenticated
merely because it hashes to the emitted value.
Likewise, event fields such as `poster`, `payer`, and `beneficiary` are
informational for reconstruction and UX. The actual payee set is the fixed
profile entry materialized from supported account sources such as
`SALE_POSTER`; indexers reconstructing who was paid must read the profile
entries and wallet deposits, not the display-only event fields alone.

Materialization resolves all dynamic sources before mint or settlement state
changes. Zero or unsupported dynamic accounts revert. Entries that materialize
to the same `(account, labelId)` pair are aggregated before fixed-profile
validation; same-account entries under different labels remain separate.
Materialization gas must be bounded independently of the resolved account
values. Zero or unsupported account sources revert before any mint, escrow, or
settlement write. Materialization must deploy-or-discover the deterministic
wallet when the settlement gas envelope allows it, so a `CREATE2` collision for
an identical concrete profile resolves to the existing wallet rather than
reverting settlement.
The release manifest must publish `MATERIALIZATION_GAS_BUDGET` for the
template materialization path and separate measured gas for wallet deployment,
wallet discovery, and escrow-credit creation. If deployment cannot fit the
settlement envelope, settlement uses escrow for the deterministic undeployed
wallet only after the factory/profile preimage checks below pass.

Templates do not have split wallet addresses. `walletFor(profileId)` applies to
fixed profiles only. A template must first materialize into a concrete
`profileId`; callers must not conflate `templateId` with the materialized
profile identity.

Primary settlement must preserve the current pull-payment invariant that
recipient behavior cannot block minting or auction settlement. The deterministic
funding path for fixed-price paid mints is the `PRE_REVENUE_SINGLE_STEP` or
`PREPARED_MINT` path defined above:

1. Resolve the assignment. Token-level fixed-price primary overrides are
   available only when Core can authoritatively allocate the token ID and write
   the token-to-collection mapping before any external callback. If a
   token-level override is expected by the signed
   `expectedPrimaryPolicyHash` but the token ID is not known, settlement must
   revert before minting or other external effects. Silent downgrade from token
   scope to collection/default scope is forbidden.
2. If the assignment is a template, materialize a fixed split profile from sale
   context such as the actual poster account.
3. Allocate token identity only through `prepareMintFromManager` when token-level
   economics must be snapshotted before `_safeMint`; otherwise record revenue
   before calling the single-step mint path.
4. If the official split wallet is deployed and still has the active or
   credit-eligible runtime code hash, attempt a gas-bounded deposit to that
   wallet.
5. If the assignment was a materialized template, the wallet is undeployed, and
   the profile was created through the official factory, or if a deployed
   correct wallet rejects the gas-bounded deposit, credit a protocol-owned
   revenue escrow under `(revenueClass, profileId, wallet, asset)`. A fixed
   assignment resolving to an undeployed wallet is malformed and reverts before
   sale effects. If the deterministic wallet address contains unexpected code,
   revert before sale effects; normal escrow must not be used for wrong-code
   addresses.
6. Emit the source revenue event only after funds are either in the split wallet
   or recorded as owed by the escrow.

The escrow must keep ADR 0003 owed/surplus boundaries: escrowed split revenue
is not emergency surplus.

When settlement materializes a template, the gas budget includes
deploy-or-discover work. If deployment cannot fit the bounded settlement path,
native revenue may be escrowed against the deterministic wallet only after the
profile preimage has been validated, the profile exists in the factory, the
predicted wallet has no code, and `wallet == factory.walletFor(profileId)`.
Deployment or discovery can then happen through a permissionless factory path
before or during a later flush.
`factory.deployWallet(profileId)` remains permissionless even if the predicted
wallet address already received direct or forced ETH; that ETH becomes part of
the wallet's native balance after deployment and is distributed by the immutable
profile shares.
This is intentional, but it is an adversarial condition, not a happy-path
assumption. Tests must pre-seed predicted wallet addresses before deployment and
prove that official sale revenue, pre-existing forced ETH, and later passive
receipts are all accounted as cumulative wallet receipts without over-release.
Indexers should display pre-existing counterfactual balances separately from
official primary-sale deposits when reconstructing sale economics.

Escrowed revenue must have a permissionless retry path:

```text
flushEscrow(revenueClass, profileId, wallet, asset)
  -> enter nonReentrant guard
  -> load the factory stored with the escrow credit
  -> verify wallet == storedFactory.walletFor(profileId)
  -> read owed credit into a local amount
  -> set owed credit to zero before external calls
  -> deploy wallet through storedFactory.deployWallet(profileId) if absent
  -> verify wallet code hash matches the escrow runtime code hash or is active
  -> transfer the cached owed amount to wallet
  -> emit flushed amount and remaining owed balance
```

Escrow should also expose a reduced path for degraded conditions:

```solidity
function flushToVerifiedWalletBestEffort(
    bytes32 revenueClass,
    bytes32 profileId,
    address wallet,
    address asset
) external;
```

This path never calls `deployWallet`. It verifies the stored credit key, checks
that `wallet` is already deployed with an active or credit-eligible runtime
code hash and the expected profile ID, zeroes owed credit, and transfers the
cached amount to that wallet with normal revert rollback. It is intended only
to keep already-deployed wallets flushable if a future gas-schedule change
makes the undeployed-wallet path too expensive. It cannot help credits whose
wallets were never deployed before the gas break.

The factory must expose a permissionless idempotent
`deployWallet(bytes32 profileId)` that verifies the profile was created through
the factory, computes `walletFor(profileId)`, checks for existing code before
attempting `CREATE2`, deploys and initializes when absent, and returns the
existing wallet when already deployed with the expected profile ID and code
hash. Existing wrong code at the predicted address reverts and requires a
separate incident recovery path, not normal escrow flush.
Unknown profiles and wrong-code predicted addresses should use distinct custom
errors so operators and indexers can distinguish missing-profile mistakes from
address-collision incidents. The future deployment is non-malicious because the
deterministic address binds the factory address, profile ID salt, and
factory-controlled init code hash; any different code at that address fails the
existing-code check.

If the deterministic address contains wrong code, the incident class is
`ESCROW_ADDRESS_POISONED`. `flushEscrow` must revert with a distinct
`WrongCodeAtWallet`-style error and leave owed credit intact. Normal flush can
never deploy the intended wallet at that address. Recovery may reroute only the
escrow-held owed credit to a successor profile with a new profile ID and new
deterministic wallet address through the timelocked successor-wallet recovery
operation below. Funds already resident in the poisoned address are outside
normal escrow accounting and require a separate public incident note.

`flushEscrow` is the reverting path in v1. It enters a non-reentrant guard,
sets the owed credit to zero before any external call, and relies on EVM revert
semantics to restore the owed balance if deployment, code-hash validation, or
transfer fails. The escrow should not duplicate split-recipient withdrawal
logic; its job is to forward owed primary revenue to the verified split wallet.
The wallet argument is the wallet captured when the escrow credit was created;
later assignment repointing does not move existing escrow credits. Escrow keys
include `revenueClass` for attribution. `flushEscrow` must be non-reentrant and
use checks-effects-interactions so reentrant or racing flush attempts cannot
double-transfer.
In v1, escrow credits may use `asset = address(0)` for native ETH or an approved
standard ERC-20 asset address for an accepted primary-sale adapter. Unsupported
or non-standard assets revert before revenue is recorded.
For non-native credits, the escrow credit function must independently re-read
the deployment-wide asset policy and accept new primary credits only when the
asset is `ACTIVE`, even if the calling adapter already checked the same asset.
This defense-in-depth check happens before owed-credit mutation. Existing escrow
credits keep their captured `asset`; later `DEPRECATED` status blocks new
official primary credits but does not by itself make already-recorded owed funds
unflushable.
Escrow credits may only be created for a deployed correct wallet or for an
undeployed deterministic wallet whose profile was created through the factory,
whose predicted address has no code, and whose expected runtime code hash is
active at credit time. This keeps the captured wallet flushable even after
later assignment repoints or factory replacement. Escrow credits store
`factory` and `escrowRuntimeCodeHash` at credit creation time. `flushEscrow`
uses the stored factory, not a mutable resolver or factory pointer. For an
undeployed deterministic wallet, `escrowRuntimeCodeHash` is the expected
runtime code hash from the profile's wallet version; for a deployed wallet, it
is the observed code hash. Deprecating a factory or code hash later does not
block flushing credits created while that factory and hash were active. Only an
explicit incident revocation can block normal flush for an escrow factory or
runtime code hash, and that revocation must come with a launch-defined recovery
plan for the owed funds.

Escrow and wallet accounting are separate until flush succeeds:

```text
walletObservedReceived(asset) =
  walletCurrentBalance(asset) + walletTotalAccountReleased(asset)

escrowOwed(revenueClass, profileId, wallet, asset) =
  native ETH owed by protocol escrow but not yet deposited into wallet
```

The wallet must not include escrow-pending funds in `observedReceived`.
Recipients can release only wallet-resident value. System-level conservation
tests must account for both wallet-resident value and escrow-pending value:

```text
sum(walletReleased)
  + sum(walletReleasable)
  + walletRoundingDust
  + escrowOwed
  <= officialDeposits + passiveReceipts + directTransfers + forcedETH
```

When `flushEscrow` succeeds, the escrow owed balance decreases and the wallet
balance increases. At that point the funds become part of the wallet's
cumulative release accounting.

`flushEscrow` is outside the public-sale settlement gas envelope, but it still
needs a published execution budget. The escrow contract should reject a flush
before zeroing owed credit unless `gasleft()` is above a launch-configured
`FLUSH_GAS_FLOOR` sized to cover worst-case `deployWallet`, code-hash
verification, and native deposit with margin. CI should record the measured
worst-case gas for deployed-wallet flush and undeployed-wallet flush. If the
wallet version or factory changes, the floor and measurements must be updated
in the release manifest. Callers may always pre-deploy the wallet through the
factory and then flush the already-deployed path.
Initial target range is 300,000 to 500,000 gas for the undeployed-wallet path,
but the deployed artifact must use measured gas plus margin rather than this
rough planning range.
For v1, `FLUSH_GAS_FLOOR` must be a deploy-time immutable or an equivalent
manifest-pinned constant for the escrow implementation, not mutable governance
state. A later escrow version may choose a different measured floor, but it must
publish the new value, bytecode hash, factory line, and gas evidence in the
release manifest before activation.
The floor calculation must account for EIP-150's 63/64 gas forwarding rule for
each external subcall. Tests must measure the actual gas delivered to
`deployWallet` and to the wallet deposit/receive path, not merely the parent
`gasleft()` value.
After owed credit is zeroed, any deployment, code-hash check, or transfer
failure must bubble as a revert of the entire `flushEscrow` call so EVM rollback
restores the owed balance. Launch code must not swallow post-zeroing failures in
`try/catch`, return `false` while leaving credit zeroed, or emit success after a
failed subcall. Tests must simulate a subcall out-of-gas after the zeroing point
and prove the parent call reverts with owed credit intact.

Escrow accounting is log-reconstructable but chain-finality-sensitive. Indexers
and accounting exports should treat escrow deposits, flushes, and recovery
events as provisional until their normal confirmation depth, and then reconcile
against onchain owed balances. A reorg cannot create or destroy contractual owed
balances on the canonical chain, but offchain reports must be able to roll back
or replay escrow events deterministically.
If a future gas-schedule change makes the immutable `FLUSH_GAS_FLOOR`
incorrect, the correction path is a new escrow deployment line plus governed
successor-wallet or escrow-credit recovery for affected credits. Monitoring
must alert when measured flush gas approaches the immutable floor with
insufficient margin. Launch operations should alert when measured worst-case
undeployed-wallet flush gas exceeds two-thirds of `FLUSH_GAS_FLOOR` or when
the margin falls below the release-manifest SLO, whichever is stricter.
Accepted terminal risk: if a future gas-schedule change makes
`FLUSH_GAS_FLOOR` permanently unreachable, a wallet was never deployed, and
governance quorum is also lost so escrow recovery cannot execute, that owed
escrow may be unavailable until a social successor process outside the old
escrow contract is accepted. This risk is bounded by encouraging
permissionless pre-deployment of split wallets and by the already-deployed
best-effort flush path above; it is not solved by hidden admin sweep power.
Operations should pre-deploy all materialized template wallets for sale programs
expected to create meaningful escrow, converting those credits to the
already-deployed best-effort flushable class before any future gas-schedule
break.

Incident-revoked escrow recovery:

```solidity
enum EscrowRecoveryStatus {
    NONE,
    SCHEDULED,
    CANCELLED,
    EXECUTED
}

struct EscrowCreditKey {
    bytes32 revenueClass;
    bytes32 profileId;
    address wallet;
    address asset;
}

struct EscrowRecoveryManifestRef {
    string uri;
    bytes32 uriHash;
    bytes32 contentHash;
    bytes32 schemaId;
    bytes32 canonicalizationHash;
}

struct EscrowRecoveryRecord {
    EscrowRecoveryStatus status;
    EscrowCreditKey creditKey;
    address storedFactory;
    address successorWallet;
    bytes32 successorProfileId;
    bytes32 successorRuntimeCodeHash;
    uint256 expectedAmount;
    EscrowRecoveryManifestRef recoveryManifest;
    uint64 executeAfter;
    bytes32 reasonHash;
    string reasonURI;
}

event EscrowRecoveryScheduled(
    uint16 schemaVersion,
    bytes32 indexed recoveryId,
    bytes32 indexed revenueClass,
    bytes32 indexed profileId,
    address wallet,
    address asset,
    address successorWallet,
    bytes32 successorProfileId,
    uint256 expectedAmount,
    bytes32 recoveryManifestContentHash,
    uint64 executeAfter,
    bytes32 reasonHash,
    string reasonURI
);

event EscrowRecoveryCancelled(
    uint16 schemaVersion,
    bytes32 indexed recoveryId,
    bytes32 indexed revenueClass,
    bytes32 indexed profileId,
    bytes32 reasonHash,
    string reasonURI
);

event EscrowRecoveryExecuted(
    uint16 schemaVersion,
    bytes32 indexed recoveryId,
    bytes32 indexed revenueClass,
    bytes32 indexed profileId,
    address oldWallet,
    address successorWallet,
    uint256 movedAmount,
    bytes32 recoveryManifestContentHash,
    bytes32 reasonHash,
    string reasonURI
);

function scheduleEscrowRecovery(
    EscrowCreditKey calldata creditKey,
    address successorWallet,
    bytes32 successorProfileId,
    bytes32 successorRuntimeCodeHash,
    uint256 expectedAmount,
    EscrowRecoveryManifestRef calldata recoveryManifest,
    uint64 executeAfter,
    bytes32 reasonHash,
    string calldata reasonURI
) external returns (bytes32 recoveryId);

function cancelEscrowRecovery(
    bytes32 recoveryId,
    bytes32 reasonHash,
    string calldata reasonURI
) external;

function executeEscrowRecovery(bytes32 recoveryId) external;

function escrowRecoveryRecord(bytes32 recoveryId)
    external
    view
    returns (EscrowRecoveryRecord memory);
```

1. Incident revocation blocks new credits and normal flush for the revoked
   runtime hash.
2. Escrow-held funds may be rerouted only through a timelocked
   successor-wallet recovery operation.
3. The recovery operation names the affected `(revenueClass, profileId, wallet,
   asset)` credit key, old wallet, successor wallet, old profile, successor
   profile, old and new runtime code hashes, amount, and reason URI/hash.
4. The successor wallet must be deployed or deployable through an approved
   factory and active runtime code hash.
5. For `ESCROW_ADDRESS_POISONED`, the successor profile ID must use a new salt
   and deterministic wallet address; the old poisoned wallet remains evented as
   the failed destination and cannot receive normal flushes.
6. If the successor profile has identical canonical entries, the normal
   recovery delay may be used. If economics change, the reason must be explicit
   and the delay should be longer than ordinary config changes.
7. Reroute moves only escrow-held owed funds and escrow accounting. It cannot
   seize or move funds already resident in the old split wallet.
8. A later re-enablement of the old runtime hash may restore normal flush, but
   it must be evented and reasoned.
9. `recoveryId` is `keccak256(abi.encode(STREAM_ESCROW_RECOVERY_V1,
   block.chainid, address(escrow), creditKey.revenueClass, creditKey.profileId,
   creditKey.wallet, creditKey.asset, successorWallet, successorProfileId,
   successorRuntimeCodeHash, expectedAmount, recoveryManifest.contentHash,
   executeAfter, reasonHash))`.
10. Execution rechecks status `SCHEDULED`, delay, current owed amount equals
    `expectedAmount`, the credit's stored factory, incident status, successor
    profile/wallet/codehash validity, and whether the recovery manifest claims
    identical or changed economics before moving escrow-held owed funds.

### Auction Settlement State Machine

Launch auctions are not allowed to rely on the current `StreamDrops` opt-in
auction placeholder. A production `StreamAuctions` or equivalent settlement
contract must own the full bid-custody state machine before auctions are
launch-ready.

Minimum auction model:

1. Each auction has a unique `auctionId`, collection ID, optional known token
   ID when the auction settles a pre-allocated or custody-held token,
   seller/beneficiary policy, accepted asset, reserve, start/end time,
   primary revenue class, and expected primary policy hash.
2. Bids are native ETH in v1 unless a reviewed auction-specific ERC-20 adapter
   is accepted. The approved-standard ERC-20 primary settlement launch
   requirement does not by itself make ERC-20 auction bidding launch-ready.
3. Losing-bid refunds are pull-based. Outbid funds become refundable credit;
   auction settlement never pushes ETH to losing bidders.
4. Settlement first marks the auction settled, records the winning payer,
   beneficiary, amount, policy hash, and sale ID, then records primary revenue
   into a split wallet or escrow before any external NFT recipient callback.
5. Minting to a contract recipient uses the same rule as fixed-price primary
   sales: revenue is recorded before safe recipient callbacks, or the token is
   minted to custody and transferred after settlement effects.
6. Failed split-wallet deposit uses the same owed escrow path as fixed-price
   primary sales. A split-recipient receive hook cannot revert settlement.
7. Refund claims use checks-effects-interactions, are non-reentrant, and remain
   claimable forever unless a future decommissioning spec handles uneconomic
   dust.
8. Auction cancellation, reserve failure, and no-bid expiry are evented and
   release any bidder credits through the same pull refund path.
9. `auctionId` and `saleId` are domain-separated by chain ID, auction contract,
   collection ID, local auction nonce, and token ID when known.
10. Settlement rejects if the signed policy hash, payer, recipient, executor,
    or amount does not match the auction state.

Until that state machine is implemented and tested, auctions are explicitly not
launch-ready. Fixed-price primary sales can launch independently if their
native ETH pull-payment path satisfies this spec.

## Royalties

Royalty configs resolve separately from primary-sale configs:

```solidity
struct RoyaltyRevenueAssignment {
    bytes32 profileId;
    address splitWallet;
    uint16 royaltyBps;
    bool configured;
    uint8 freezeMode;
    bool permanentFreeze;
}
```

ERC-2981 returns one receiver address. Therefore, the receiver returned by
`royaltyInfo(tokenId, salePrice)` must already be the split wallet for the
resolved token, collection, or default royalty assignment.

Target behavior:

```text
royaltyInfo(tokenId, salePrice)
  -> token royalty assignment, else collection, else default
  -> receiver = resolved split wallet
  -> amount = salePrice * royaltyBps / 10_000
```

If `royaltyBps` is zero, `royaltyInfo()` should return `(address(0), 0)`.

### StreamCore ERC-2981 Implementation

Launch Core should not inherit OpenZeppelin `ERC2981` storage. The inherited
default and token royalty mappings create a second source of truth and waste
bytecode. Core should implement `IERC2981` directly and route `royaltyInfo()`
through the resolver.

Normative Core posture:

1. Remove the OZ `ERC2981` base from `StreamCore`.
2. Keep direct `IERC2981` support.
3. Add a `revenueResolver` pointer governed by ADR 0004 pointer rules.
4. Implement `supportsInterface` for ERC-721, ERC-721 metadata,
   ERC-721 enumerable, ERC-2981, and ERC-4906 if Core-originated refresh events
   are implemented.
5. Do not keep `_setDefaultRoyalty`, `_setTokenRoyalty`, or equivalent Core
   royalty storage.

Reference shape:

The body below is selector and control-flow pseudocode. Production Core must
use capped assembly `staticcall` and must not allocate `bytes memory` for
resolver returndata before enforcing the 64-byte return-size rule.

```solidity
interface IStreamRevenueResolver {
    function royaltyReceiverAndBps(
        address core,
        uint256 tokenId,
        uint256 salePrice,
        uint256 mappedCollectionId,
        bool hasMappedCollection
    ) external view returns (address receiver, uint16 royaltyBps);
}

bytes4 constant ROYALTY_RECEIVER_AND_BPS_SELECTOR = 0x54f77a09;
// royaltyReceiverAndBps(address,uint256,uint256,uint256,bool)

function royaltyInfo(uint256 tokenId, uint256 salePrice)
    external
    view
    returns (address receiver, uint256 royaltyAmount)
{
    address resolver = revenueResolver;
    if (resolver == address(0)) {
        return (address(0), 0);
    }

    if (gasleft() <= ROYALTY_RESOLVER_GAS_LIMIT + ROYALTY_RETURN_GAS_BUFFER) {
        return (address(0), 0);
    }

    bool hasMappedCollection = tokenCollectionMappingExists[tokenId];
    uint256 mappedCollectionId =
        hasMappedCollection ? tokenCollectionId[tokenId] : 0;

    // Production implementation uses capped assembly staticcall helper:
    // - forwards exactly ROYALTY_RESOLVER_GAS_LIMIT
    // - copies at most 64 bytes
    // - returns returndata size without allocating unbounded memory
    (bool ok, bytes32 word0, bytes32 word1, uint256 returnSize) =
        _staticcallRoyaltyResolver64(
            resolver,
            IStreamRevenueResolver.royaltyReceiverAndBps.selector,
            address(this),
            tokenId,
            salePrice,
            mappedCollectionId,
            hasMappedCollection
        );

    if (!ok || returnSize != 64) {
        return (address(0), 0);
    }

    receiver = address(uint160(uint256(word0)));
    uint16 royaltyBps = uint16(uint256(word1));
    if (
        receiver == address(0)
            || royaltyBps == 0
            || royaltyBps > MAX_ROYALTY_BPS
    ) {
        return (address(0), 0);
    }
    royaltyAmount = Math.mulDiv(salePrice, royaltyBps, 10_000);
}
```

Launch implementation must use capped assembly returndata copying instead of
high-level `bytes memory` decode to avoid unbounded returndata allocation. The
call copies at most 64 bytes and requires `returndatasize() == 64`.

`mappedCollectionId` and `hasMappedCollection` come from Core's authoritative
token mapping, not from a token ID range heuristic. Core reads
`tokenCollectionMappingExists[tokenId]` before the staticcall; when it is true,
Core passes `mappedCollectionId = tokenCollectionId[tokenId]` and
`hasMappedCollection = true`; when it is false, Core passes
`mappedCollectionId = 0` and `hasMappedCollection = false`. For minted,
same-transaction allocated, custody-held, or burned tokens with retained
mapping, `hasMappedCollection = true`. For premint or nonexistent tokens
without an authoritative Core mapping, `hasMappedCollection = false` and
`mappedCollectionId = 0`; the resolver falls back to default assignment or
zero. The resolver must not call Core, re-read token mapping, or infer a
collection from token ID arithmetic.
For external diagnostics and satellite reads, the canonical Core read is
`tokenCollectionIdentity(tokenId) -> (mappingExists, collectionId,
collectionSerial, burned)`, with burned tokens returning their retained mapping
and `burned = true`.

If a resolver-backed Core cannot reach the resolver, receives malformed return
data, or receives a zero receiver or zero bps, it should return
`(address(0), 0)` rather than revert. Wallet/code-hash validity is enforced at
assignment time by the resolver; Core's read path validates only cheap return
shape and zero-value conditions. Monitoring should treat fallback-to-zero as an
incident.
`royaltyInfo()` must be total over every `uint256 salePrice`, including
`type(uint256).max`, and must not revert because of royalty multiplication.
The resolver never returns the final amount. Core computes
`floor(salePrice * royaltyBps / 10_000)` with full-precision checked math or an
equivalent `mulDiv` implementation after validating the returned bps. Returning
`(address(0), 0)` for Core arithmetic failure is not conformant; fallback-to-zero
is reserved for resolver unavailability, malformed return data, zero receiver,
zero bps, bps above `MAX_ROYALTY_BPS`, or explicit no-royalty configuration.
Because `royaltyInfo()` is `view`, it cannot emit fallback events. Monitoring
must use off-chain calls, indexer comparisons, and a non-view diagnostic probe
in a satellite contract.

Recommended diagnostic probe:

```solidity
function probeRoyaltyInfo(uint256 tokenId, uint256 salePrice)
    external
    returns (
        bool resolverCallSucceeded,
        address receiver,
        uint256 royaltyAmount,
        bytes32 assignmentHash,
        bytes32 failureReason
    );
```

`probeRoyaltyInfo` lives on the approved revenue diagnostics satellite or on
the revenue resolver if the resolver implementation includes diagnostics. It
does not live on Core. The probe emits resolver health and fallback evidence for
operators. It is not used by marketplaces, but it is a launch gate so
fallback-to-zero cannot remain invisible during public sale readiness checks.
The probe must use the exact same resolver selector, gas cap, parent gas
precheck, returndata-size limit, and decode rules as production
`royaltyInfo()`. A diagnostic path with a looser cap is not a valid readiness
signal.

```solidity
event RoyaltyInfoProbed(
    uint16 schemaVersion,
    uint256 indexed tokenId,
    address indexed receiver,
    uint256 royaltyAmount,
    bool resolverCallSucceeded,
    bytes32 assignmentHash,
    bytes32 failureReason
);
```

A resolver-backed Core path must use explicit gas and return-shape limits:

```text
ROYALTY_RESOLVER_GAS_LIMIT = 50_000
ROYALTY_RETURN_GAS_BUFFER = 15_000
resolver.staticcall{gas: ROYALTY_RESOLVER_GAS_LIMIT}
expected return length = 64 bytes
failure fallback = (address(0), 0)
```

The parent gas precheck must account for EIP-150's 63/64 gas forwarding rule so
a caller cannot pass the precheck while the resolver receives less than
`ROYALTY_RESOLVER_GAS_LIMIT`. CI must test calls just below, at, and above the
precheck threshold and prove ordinary all-cold resolver reads do not
fallback-to-zero because of under-forwarded gas.

`ROYALTY_RESOLVER_GAS_LIMIT` should be a deploy-time immutable for a Core
release, not mutable governance state. A new Core deployment may choose a new
immutable gas limit for a new resolver implementation, but there should be no
runtime setter that changes marketplace read behavior after deployment.

The resolver read must be O(1). Wallet deployment, `walletFor(profileId)`,
`wallet.profileId()`, and runtime-code-hash checks happen when assignments are
set, not during every marketplace `royaltyInfo()` call.

Resolver `royaltyReceiverAndBps` must be a storage-read path. It
must not make external calls, perform wallet deployment, call `balanceOf`, or
depend on any receiver behavior. A resolver implementation that performs
external calls in the marketplace royalty path is an incident and must be
blocked from production pointer activation.
The resolver is bound to exactly one Core address at deployment. If
`royaltyReceiverAndBps(core, ...)` receives any `core` argument other than that
bound Core, it must revert or return `(address(0), 0)`. A resolver must never
use a caller-supplied `core` argument to look up another deployment's
assignments.
Static analysis must fail launch if `royaltyReceiverAndBps` or any internal
function reachable only from that path contains `CALL`, `DELEGATECALL`,
`STATICCALL`, `CREATE`, or `CREATE2` opcodes. The Core staticcall gas cap is
defense in depth, not the primary proof that the deployed resolver is pure.

Worst-case cold-access gas must be budgeted before deployment. Target launch
shape with packed assignment storage:

```text
component                                      cold gas target
Core tokenCollectionId + mapping exists       <= 4,500
staticcall account access and call overhead    <= 4,000
resolver token assignment presence read        <= 2,300
resolver collection assignment presence read   <= 2,300
resolver default packed assignment reads       <= 4,600
math, branches, ABI return                     <= 8,000
margin                                         >= 20,000
total parent + resolver path                   < 50,000 resolver cap plus buffer
```

The exact deployed implementation must publish measured gas for all-cold
token, collection, and default fallback cases. If the deepest cold path exceeds
35,000 gas inside the resolver on the target compiler/EVM, the implementation
must either compress assignment storage, raise the immutable resolver gas cap
before deployment, or reduce resolver work. It must not launch with a cap that
causes ordinary cold reads to silently return `(address(0), 0)`.

Launch Core must use capped assembly returndata handling, not a high-level
`bytes memory` decode that can allocate unbounded returndata. The call copies at
most 64 bytes, requires `returndatasize() == 64`, and returns `(address(0), 0)`
for malformed size. Core uses checked arithmetic or `mulDiv`-style math for
`salePrice * royaltyBps / 10_000` after decoding bps from the resolver and does
not rely on overflow reverts for normal fallback behavior.

`royaltyInfo()` must not require the token to be minted. In the v1
resolver-backed design, token IDs without `tokenCollectionMappingExists[tokenId]
== true` always fall back to the default assignment or zero. Collection-scope
royalty resolution requires Core to pass both
`hasMappedCollection = true` and the stored `tokenCollectionId[tokenId]`. Core
must not infer a collection receiver for unmapped tokens unless a later ADR
defines an exact token ID codec and storage-free collection existence gate.
The mapping used by `royaltyInfo()` is written only when Core has an
authoritative token assignment, such as mint, same-transaction allocation, or a
custody-held token path. Burned tokens retain their last stored mapping for
royalty disclosure history, with `tokenCollectionMappingExists[tokenId]`
remaining true after burn. `royaltyInfo()` therefore still resolves token,
collection, then default scope for burned tokens, while `tokenURI()` may revert
under normal ERC-721 metadata semantics. Launch v1 does not define standalone
premint reservations; premint or nonexistent tokens without the Core mapping
are unmapped for royalty resolution.

This is still disclosure. Unless a future enforcement ADR changes the product
posture, marketplaces can ignore the royalty.

Marketplaces may cache receiver or bps results, may ignore token-varying
receivers, or may only honor a default receiver. The launch contract still must
expose Core-native ERC-2981 because it is the most broadly portable royalty
disclosure surface.
There is no Core-local fixed receiver fallback in the launch architecture. If
the resolver returns zero, malformed data, or no configured default assignment,
`royaltyInfo()` returns `(address(0), 0)`.

### Resolver Replacement And Frozen Economic Continuity

Replacing the Core `ROYALTY_RESOLVER` pointer must not weaken frozen economics.
Pointer governance alone is insufficient because revenue freezes, inherited
freezes, global freezes, mint-time royalty snapshots, and `maxRoyaltyBps`
posture live in the resolver family.

Continuity interface:

```solidity
interface IStreamRevenueResolverContinuity {
    function frozenEconomicStateHash(address core)
        external
        view
        returns (bytes32);

    function economicRouteHash(
        address core,
        bytes32 revenueClass,
        uint8 scope,
        uint256 scopeId
    ) external view returns (bytes32);

    function supportsEconomicContinuity(
        address oldResolver,
        bytes32 oldFrozenEconomicStateHash,
        bytes32 continuityManifestHash
    ) external view returns (bool);
}
```

Rules:

1. After any permanent freeze, inherited freeze, global freeze, mint-time
   royalty snapshot, or terminal `maxRoyaltyBps` reduction, a resolver pointer
   update is blocked unless the new resolver proves continuity.
2. Continuity means the new resolver returns the same
   `frozenEconomicStateHash(core)` and the same `economicRouteHash(...)` for
   every frozen or snapshotted route named by the continuity manifest.
3. The continuity manifest commits to old resolver, new resolver, Core, chain
   ID, affected revenue classes, route hashes, assignment hashes, snapshot
   hashes, freeze modes, `maxRoyaltyBps`, URI/hash, schema ID, and
   canonicalization ID.
4. If exact continuity is impossible, the change is an economics-affecting
   recovery. It must use delayed governance, publish a recovery manifest, and
   remain visible forever. Silent remapping of frozen economics is
   nonconformant.

A successor-Core declaration does not automatically change old-Core
`royaltyInfo()` behavior. The old Core keeps answering through its configured
resolver until governance explicitly freezes, deprecates, or repoints that
resolver under the normal pointer rules. The successor manifest must state
whether the old Core is still royalty-disclosure active, deprecated but
queryable, or intentionally returning zero for future marketplace reads.

## Assignment Semantics

Assignments are keyed by:

```text
revenueClass
scope
scopeId
```

`revenueClass` is a `bytes32`, not a permanent enum. Known classes can be
documented, but future classes remain possible.

Typical classes:

```text
PRIMARY_FIXED_PRICE
PRIMARY_AUCTION
ROYALTY_ERC2981
```

Scopes:

```text
default: scopeId = 0
collection: scopeId = collectionId
token: scopeId = tokenId
```

Resolution order:

```text
token -> collection -> default
```

Canonical assignment hashes:

```solidity
bytes32 assignmentHash = keccak256(abi.encode(
    STREAM_REVENUE_ASSIGNMENT_V1,
    block.chainid,
    address(resolver),
    bytes32(revenueClass),
    uint8(scope),
    uint256(scopeId),
    bytes32(profileId),
    address(splitWallet),
    uint16(royaltyBps),
    uint8(assignmentKind),
    uint8(freezeMode),
    bool(permanentFreeze),
    bytes32(metadataHash)
));

bytes32 resolvedPrimaryPolicyHash = keccak256(abi.encode(
    STREAM_PRIMARY_POLICY_V1,
    block.chainid,
    address(resolver),
    bytes32(revenueClass),
    uint256(collectionId),
    uint256(tokenId),
    bytes32(templateId),
    bytes32(profileId),
    address(splitWallet),
    bytes32(assignmentHash)
));

bytes32 royaltyAssignmentHash = keccak256(abi.encode(
    STREAM_ROYALTY_POLICY_V1,
    block.chainid,
    address(resolver),
    uint256(collectionId),
    uint256(tokenId),
    bytes32(profileId),
    address(splitWallet),
    uint16(royaltyBps),
    bytes32(assignmentHash)
));
```

`expectedPrimaryPolicyHash`, mint-time royalty snapshots, resolver probes, and
assignment events must all use these preimages or a later versioned replacement.
Event-only display fields, human labels, and mutable URIs are excluded from
economic authority unless their hashes are explicitly included above.

For open-ended collections, collection scope remains valid even when max supply
is unknown. The resolver never needs final supply to resolve an assignment.
Collection-level assignments apply to future tokens until changed or frozen.
Token-level assignments are used when a specific token needs a different or
snapshotted policy.

Token-level assignment writes require an authoritative Core token mapping. The
resolver must verify that the token is minted, burned with retained mapping, or
same-transaction allocated through the same explicit token-to-collection mapping
used by `royaltyInfo()`. Implementations must not create token-level assignments from a
collection range heuristic or unknown future token ID. This is required for
inherited freeze enforcement: a collection inherited freeze can block token
overrides only when the token's collection ancestor is known.

Freeze order can be per assignment or broader:

```text
freeze(revenueClass, token, tokenId)
freeze(revenueClass, collection, collectionId)
freeze(revenueClass, default, 0)
freezeAllRevenue()
```

Assignment storage must not collapse freeze state into a single `bool`.
Implementations need enough state to distinguish unfrozen, exact frozen,
inherited frozen, global frozen, permanent, and timelocked-unfreezeable states.
Frozen assignments cannot be changed or cleared.

Primary assignments may resolve to a fixed profile or a primary split template.
Template assignments materialize into fixed profiles during settlement; royalty
assignments always resolve to fixed profiles.

Default-scope assignment changes, default royalty changes, global freezes, and
resolver cap replacement actions must use timelock or two-step staging. A global freeze
is terminal and should be used only when that irreversibility is part of the
product promise. Non-global unfreeze should exist only if the product
explicitly advertises mutable economics and the event history makes the change
obvious.

Freezes use `freezeMode`: `EXACT` blocks only the exact key, while `INHERITED`
blocks lower-scope set and clear operations under the frozen ancestor. In
launch v1, applying an `INHERITED` freeze with any mutable lower-scope override
under that ancestor must revert. A later ADR may add a bounded batch operation
that freezes descendants in the same governance action, but v1 must not pretend
it can enumerate arbitrary token-level descendants.
The resolver must maintain O(1) descendant override counters or dirty bits per
`(revenueClass, scope, scopeId)` so inherited-freeze checks do not require
enumerating token-level assignments. Counter updates are part of set and clear:
setting a collection override increments the default ancestor counter; setting a
token override increments its authoritative collection ancestor and the default
ancestor; clearing decrements the same ancestors. Applying an inherited freeze
with existing lower overrides reverts in launch v1.

Formal descendant-counter invariant:

```text
mutableDescendants(default, revenueClass)
  = count(collection overrides under revenueClass that are not exact frozen)
  + count(token overrides under revenueClass that are not exact frozen)

mutableDescendants(collection, revenueClass, collectionId)
  = count(token overrides under collectionId/revenueClass that are not exact frozen)
```

`set`, `clear`, and `exactFreeze` update counters by comparing the old
configured/frozen state and new configured/frozen state, not by blindly
incrementing per call. A collection override set after an existing token
override increments only the default ancestor for the collection override; it
does not change the collection's token-descendant count. Clearing that
collection override decrements only the default ancestor if the collection
override was mutable. Token descendants remain counted under the collection
until they are cleared or exact-frozen. Inherited freeze can execute only when
the relevant mutable-descendant counter is zero, or when the same governance
operation exact-freezes every descendant whose mutability made the counter
nonzero.

A global freeze is implicitly `freezeMode = INHERITED` across every default,
collection, and token scope for the affected revenue class. It blocks set,
clear, and unfreeze operations for any assignment in that revenue class,
including creation of new assignments after the freeze.
Whether it also blocks creation of entirely new revenue classes must be an
explicit release decision; a deployment-wide global freeze should block both.

## Canonical Launch Interfaces

Launch implementation PRs should converge on selector-stable ABI targets for
the payment surface:

```solidity
interface IStreamSplitFactory {
    function walletFor(bytes32 profileId) external view returns (address);
    function deployWallet(bytes32 profileId) external returns (address wallet);
    function profileExists(bytes32 profileId) external view returns (bool);
    function profileEntriesHash(bytes32 profileId) external view returns (bytes32);
    function splitWalletRuntimeCodeHash() external view returns (bytes32);
}

interface IStreamSplitWallet {
    function profileId() external view returns (bytes32);
    function release(address asset, address account, address payable recipient)
        external
        returns (uint256);
    function releasable(address asset, address account) external view returns (uint256);
    function observedReceived(address asset) external view returns (uint256);
    function accountReleased(address asset, address account) external view returns (uint256);
    function totalReleased(address asset) external view returns (uint256);
    function syncAsset(address asset) external returns (uint256);
}

interface IStreamRevenueEscrow {
    function escrowOwed(
        bytes32 revenueClass,
        bytes32 profileId,
        address wallet,
        address asset
    ) external view returns (uint256);

    function flushEscrow(
        bytes32 revenueClass,
        bytes32 profileId,
        address wallet,
        address asset
    ) external;
}

interface IStreamRevenueAssignmentView {
    function assignmentHash(bytes32 revenueClass, uint8 scope, uint256 scopeId)
        external
        view
        returns (bytes32);

    function resolvedAssignment(
        address core,
        bytes32 revenueClass,
        uint256 tokenId,
        uint256 collectionId,
        bool hasMappedCollection
    ) external view returns (
        bytes32 profileOrTemplateId,
        address wallet,
        uint16 royaltyBps,
        bool isTemplate,
        bytes32 assignmentHash
    );
}
```

The implemented first-slice signatures are pinned through
`IStreamSplitFactory` and `IStreamSplitWallet` in the release artifact surface.
Later ERC-20, assignment, escrow, and resolver interfaces must remain
selector-stable when they are promoted from this target sketch into code. The
interfaces above are intentionally value-type heavy; rich display metadata
stays in manifests and events.

## Events

The future event surface should be indexer-first. At minimum:

```solidity
event SplitProfileCreated(
    bytes32 indexed profileId,
    bytes32 indexed entriesHash,
    bytes32 indexed metadataURIHash,
    uint16 schemaVersion,
    uint16 walletVersion,
    address wallet
);

event SplitProfileEntry(
    bytes32 indexed profileId,
    uint16 index,
    address indexed account,
    uint32 sharePpm,
    bytes32 labelId
);

event SplitWalletDeployed(
    bytes32 indexed profileId,
    address indexed wallet,
    uint16 indexed walletVersion,
    bytes32 initCodeHash,
    bytes32 runtimeCodeHash
);

event SplitWalletDiscovered(
    bytes32 indexed profileId,
    address indexed wallet,
    uint16 indexed walletVersion,
    bytes32 initCodeHash,
    bytes32 runtimeCodeHash
);

event AssetObservationInitialized(
    bytes32 indexed profileId,
    address indexed asset,
    uint256 observedReceived
);

event AssetSynced(
    bytes32 indexed profileId,
    address indexed asset,
    uint256 previousObservedReceived,
    uint256 observedReceived
);

event NativeReleased(
    bytes32 indexed profileId,
    address indexed account,
    address indexed recipient,
    uint256 amount,
    uint256 totalReleased,
    uint256 observedReceived
);

event RevenueAssignmentSet(
    bytes32 indexed revenueClass,
    uint8 indexed scope,
    uint256 indexed scopeId,
    address actor,
    bytes32 previousProfileOrTemplateId,
    address previousWallet,
    uint16 previousRoyaltyBps,
    bytes32 profileOrTemplateId,
    address wallet,
    uint16 royaltyBps,
    bool isTemplate
);

event RevenueAssignmentCleared(
    bytes32 indexed revenueClass,
    uint8 indexed scope,
    uint256 indexed scopeId,
    address actor,
    bytes32 previousProfileOrTemplateId,
    address previousWallet,
    uint16 previousRoyaltyBps,
    bool wasTemplate
);

event RevenueAssignmentFrozen(
    bytes32 indexed revenueClass,
    uint8 indexed scope,
    uint256 indexed scopeId,
    bool permanent,
    uint8 freezeMode
);

event PrimaryRevenueDeposited(
    bytes32 indexed revenueClass,
    bytes32 indexed profileId,
    address indexed wallet,
    address asset,
    uint256 amount,
    uint256 collectionId,
    uint256 tokenId,
    bytes32 saleKind,
    uint256 saleId,
    address payer,
    address poster,
    address beneficiary,
    bool isTemplate,
    bool escrowed,
    bool policyDriftObserved
);

event PrimaryTemplateMaterialized(
    bytes32 indexed templateId,
    bytes32 indexed profileId,
    address indexed wallet,
    bytes32 revenueClass,
    uint8 scope,
    uint256 scopeId,
    bytes32 saleContextHash
);

event EscrowCreditCreated(
    bytes32 indexed revenueClass,
    bytes32 indexed profileId,
    address indexed wallet,
    address asset,
    uint256 amount,
    uint256 totalOwed,
    bytes32 escrowRuntimeCodeHash
);

event EscrowFlushed(
    bytes32 indexed revenueClass,
    bytes32 indexed profileId,
    address indexed wallet,
    address asset,
    uint256 amount,
    uint256 remainingOwed
);

event SplitReleased(
    bytes32 indexed profileId,
    address indexed account,
    address indexed recipient,
    address asset,
    uint256 amount,
    uint256 accountReleased,
    uint256 totalAccountReleased
);

event SplitAssetObserved(
    bytes32 indexed profileId,
    address indexed wallet,
    address indexed asset,
    uint256 balance,
    uint256 totalAccountReleased
);

event AssetApprovalSet(
    address indexed asset,
    uint8 state,
    address indexed actor,
    string reason
);

event AssetMarkedUnsupported(
    address indexed asset,
    address indexed actor,
    string reason
);

event AssetObservationInitialized(
    bytes32 indexed profileId,
    address indexed wallet,
    address indexed asset,
    uint256 observedReceived
);

event WalletCodeHashApprovalSet(
    bytes32 indexed runtimeCodeHash,
    uint8 state,
    address indexed actor
);

event GlobalRevenueFreezeSet(
    bytes32 indexed revenueClass,
    address indexed actor,
    bool permanent,
    uint8 freezeMode
);
```

The implementation may refine names, but each event can have at most three
indexed fields. Fields that are not indexed must still be present where needed
for wallets, indexers, operator tools, and release evidence to reconstruct
policy.
The indexed fields shown above are the normative v1 allocation. Changing an
indexed field after launch is an indexer-breaking event schema change and
requires a new event name or a new accepted ADR. Do not "optimize" event
indexing per implementation after downstream tooling has been built.
The intended escrow query path is to index escrow credit/flush events by
`revenueClass`, `profileId`, and `wallet`; `asset`, amount, and remaining owed
balance remain present as unindexed event data. Indexers that need asset-first
lookup should maintain a secondary index from the full event stream.
Profile creation should emit `SplitProfileCreated`, then entries in canonical
index order, then `SplitWalletDeployed` if deployment happens in the same
transaction.

`saleKind` is a `bytes32` discriminator such as `keccak256("FIXED_PRICE")` or
`keccak256("AUCTION")`. `saleId` is the drop ID for fixed-price drops. For
auctions, `saleId` may be the token ID only if a token can have at most one
primary auction in that sale contract; otherwise it must include or point to an
auction nonce. `beneficiary` is the token recipient.

## Implementation Requirements

### Split Factory

- Deploy wallets deterministically.
- Use a v1 fixed-runtime clone deployment where profile data is initialized
  exactly once after `CREATE2` deployment.
- Use active runtime code hashes for new assignments; code-hash approval,
  deprecation, and incident revocation are evented.
- Track runtime code hash state as active, deprecated, or incident-revoked. New
  assignments require active hashes. Existing deployed wallets and escrow
  credits continue to use deprecated hashes. Incident revocation blocks new use
  and requires a documented recovery path for affected escrow.
- Runtime code-hash behavior:
  `ACTIVE` permits new assignments and new escrow credits; `DEPRECATED` blocks
  new assignments/credits but permits release and flush for already-created
  wallets and credits; `INCIDENT_REVOKED` blocks new use and normal escrow
  flush until recovery is accepted.
- Reject invalid profiles.
- Enforce the entry and unique-account maxima for the wallet version.
- Canonicalize entries and derive account aggregates from entries.
- Expose profile ID calculation.
- Expose wallet address prediction.
- Expose `walletFor(profileId)`.
- Expose permissionless idempotent `deployWallet(profileId)`. It must verify
  the profile was created by the factory, check existing code at `walletFor`
  before attempting `CREATE2`, deploy and initialize when absent, return the
  existing wallet when already valid, and revert on wrong code or wrong
  `profileId()`. Unknown profile and wrong-code address collision paths should
  use distinct custom errors.
- Emit profile and entry events.

### Split Wallet

- Immutable profile.
- Native ETH receive support.
- Non-reverting, storage-free, recipient-code-free `receive`.
- ERC-20 release support.
- ERC-20 releases limited to approved standard assets or later adapters.
- Evented asset approval, approval deprecation, and unsupported marking.
- Reentrancy protection on release.
- Alternate recipient release.
- Rounding dust bounded and non-withdrawable in v1.
- Paginated profile reads for both raw entries and unique-account aggregates.
  Required views:
  `entryCount()`, `entries(uint256 start, uint256 limit)`,
  `accountCount()`, and `accounts(uint256 start, uint256 limit)`. These reads
  let wallets support arbitrary split counts without one unbounded ABI return.
- Anyone-callable `syncAsset(asset)` for native ETH and explicit ERC-20 asset
  observation. `syncAsset` emits observed cumulative asset state only, is O(1),
  and does not compute per-account releasable amounts or rounding dust. The
  first sync initializes and emits even at zero balance; later unchanged syncs
  may skip emission.
- `lastObservedReceived(asset)` guard for unsupported balance-decreasing assets.
- No admin sweep of owed funds.
- Unsupported token policy for fee-on-transfer, rebasing, callback, and other
  non-standard ERC-20 behavior.

### Revenue Resolver

- Default, collection, and token assignment storage.
- Open `bytes32 revenueClass` keys.
- Separate primary and royalty assignment helpers.
- Set, clear, freeze, and read functions.
- Royalty bps cap mirrored from Core's immutable `maxRoyaltyBps`.
- Core owns the hard immutable `maxRoyaltyBps`, recommended at 1000 for launch
  unless a future accepted ADR chooses otherwise before deployment. The Core cap
  must not exceed 10,000. A resolver may impose the same or a lower cap, but it
  cannot raise the Core cap.
  Raising the Core cap after launch requires a new Core deployment line and
  explicit rollout plan; lowering resolver policy can use a new resolver
  deployment and rollout plan.
- Resolver cap rollout runbook: deploy new resolver, register and approve its
  module identity/code hash/manifest hash, stage the Core resolver pointer
  update, replay or intentionally remap default and collection assignments,
  run `probeRoyaltyInfo` against representative default, collection, token,
  premint, burned, and malformed cases, emit a manifest-backed reason, execute
  after the delay, monitor fallback-to-zero diagnostics, and optionally freeze
  the new pointer after launch confidence. Cap changes must not mutate old
  resolver state in place.
- Assignment-time wallet deployment, factory, profile ID, and code-hash
  validation.
- Direct view for `primaryRevenueWallet(collectionId, tokenId, revenueClass)`.
- Direct view for `royaltyInfo(tokenId, salePrice)`.
- Direct view for `royaltyReceiver(collectionId)` for marketplace and operator
  diagnostics; this is a convenience view, not an ERC-2981 replacement.
- Factory view `splitWalletExists(profileId)` that returns true only when the
  deterministic wallet is deployed with the expected profile and active or
  historically eligible runtime code hash.
- Core-side `tokenCollectionMappingExists[tokenId]` read, passed as
  `hasMappedCollection`, for collection-scope royalty resolution.

### StreamDrops And StreamAuctions

- Replace three-bucket local split policy with resolver-backed profiles only
  after the split wallet and resolver have dedicated tests.
- Preserve current pull-payment and owed/surplus behavior in the launch design.
- Assignments may point only to verified official split wallets or a
  protocol-owned revenue escrow with ADR 0003 owed/surplus guarantees.
- Use deterministic direct-deposit-then-escrow fallback so split wallet deposit
  failure cannot revert minting or auction settlement.
- Do not ship auction settlement until the full bid-custody, pull-refund, and
  settlement state machine above is implemented. The current drop-side auction
  placeholder is not a launch settlement path.
- Keep v1 primary settlement limited to native ETH and approved standard ERC-20
  adapters; non-standard ERC-20 behavior requires a separate accepted adapter
  spec.
- Emit source revenue events only after funds are accepted by the split wallet
  or recorded as owed by the revenue escrow.

### StreamCuratorsPool

Any curator reward or pool contract that can hold owed funds must follow the
same owed/surplus boundary as the primary splitter architecture. Push payments
and unrestricted emergency sweeps are not launch-conformant for owed rewards.
Either rewrite curator rewards to pull accounting with explicit surplus proofs
or mark the current pool as a non-launch component outside the Stream
payment conformance boundary.

### StreamCore

- Keep mutable revenue policy out of Core, but include Core-native ERC-2981.
- Implement the smallest resolver-backed `royaltyInfo()` path that can pass
  size-budget review.
- If the size budget fails, refactor non-essential Core logic into satellites or
  compress helper code until Core-native ERC-2981 fits.
- Use explicit resolver gas, return-shape checks, and fallback-to-zero for
  resolver failure.
- Never make `royaltyInfo()` depend on minted-token-only checks.
- Preserve ERC-721 transfer openness.

## Operator UX

Operator tools should show:

- active default, collection, and token assignments;
- whether each assignment is frozen;
- profile recipients, labels, and shares;
- predicted wallet address before deployment;
- wallet balances by asset;
- explicit ERC-20 asset search and sync;
- releasable amounts by account;
- royalty bps by scope;
- policy history from events.

Operator tools must not imply that ERC-2981 royalties are enforced.

## Recipient UX

Recipient tools should show:

- every split wallet where the connected account has releasable funds;
- source profile and labels for each entitlement;
- the possibility that economically identical concrete splits from different
  templates resolve to different wallets and require separate claims;
- asset type;
- explicit asset refresh for ERC-20s that were sent directly to a wallet;
- release-to-self and release-to-recipient actions;
- retryable state for failed releases;
- stale indexer warnings with direct RPC refresh.
- off-chain ERC-20 `Transfer` log indexing as a hard dependency for discovering
  unknown ERC-20 assets; on-chain `syncAsset` works only after a user or indexer
  supplies the asset address.

Recipient discovery must not depend on one frontend. The split factory exposes
profile and wallet creation events, `walletFor(profileId)`, and
`splitWalletExists(profileId)`. Indexers can enumerate wallets by profile
events and profile entries; recipients can verify membership from immutable
profile data and call release directly.

## Marketplace And Indexer UX

Marketplace and indexer integrations should:

- read `supportsInterface(0x2a55205a)`;
- call `royaltyInfo(tokenId, salePrice)`;
- display receiver and amount as royalty disclosure;
- recognize split wallet receivers where supported;
- avoid claims that payment is guaranteed;
- retain platform-specific evidence before public release claims.

## Pre-Launch Implementation Sequence

1. Implement the split wallet factory and immutable split wallets.
2. Add exhaustive split-profile, canonicalization, dust, release, ERC-20, and
   deterministic deployment tests.
3. Implement resolver assignment storage, set/clear/freeze/read functions, and
   event reconstruction.
4. Wire fixed-price primary settlement through resolver-backed fixed profiles
   or primary split templates.
5. Wire auction primary settlement only after the bid-custody and pull-refund
   state machine in this spec is implemented.
6. Implement royalty assignments and split-wallet royalty receiver resolution.
7. Add minimal resolver-backed `royaltyInfo()` to `StreamCore` before launch.
8. Prove the Core size budget with measured bytecode output. If the size budget
   fails, refactor non-essential Core logic into satellites or compress helper
   code until Core-native ERC-2981 fits.
9. Retain marketplace/indexer evidence for Core-native ERC-2981 behavior and
   split-wallet receiver display.
10. Update docs, release artifacts, event catalogs, ABI checksums, and retained
   marketplace evidence.

## Known Risks

- Pull-based split wallets require recipients to claim.
- Passive royalty receipts can create tiny bounded rounding dust that remains
  in the wallet under v1 accounting.
- Forced ETH sent to a counterfactual wallet before deployment is attributed to
  the immutable profile eventually deployed at that deterministic address.
- Unsupported rebasing-down ERC-20 behavior can skew entitlements before the
  balance-decrease guard detects it; approved assets must exclude that class.
- Incident-revoking a wallet runtime code hash can freeze owed escrow for that
  hash until the timelocked successor-wallet recovery path is executed.
- Marketplace royalty behavior remains external, uneven, and cache-prone.

## Validation Checklist

- Profile ID is deterministic.
- Profile ID binds factory, wallet version, init code hash, and runtime code
  hash.
- Profile entries are immutable.
- Labels are arbitrary.
- Label display names and supersession live in an append-only registry; old
  label IDs are never silently reinterpreted.
- Duplicate `(account, labelId)` pairs are rejected.
- Same account with different labels is supported.
- Same account under multiple labels cannot release more than its aggregate
  share.
- Same account under many labels cannot increase dust beyond the unique-account
  bound because labels aggregate before flooring.
- Profile sum must equal `1_000_000`.
- Entry and unique-account maxima are enforced.
- Releasable math is monotonic.
- Unsupported balance-decreasing ERC-20 behavior reverts rather than
  underflowing or reducing entitlements.
- Failed release preserves claimable funds.
- Reentrant release cannot over-withdraw.
- Anyone can release funds only to the entitled account; alternate-recipient
  release requires entitled-account caller or valid EIP-712/ERC-1271
  authorization with nonce and deadline.
- Forced ETH cannot be swept as surplus.
- ERC-20 releases are tested.
- ERC-20 direct receipt can be observed with explicit asset sync.
- Unknown ERC-20 balances first observed after approval become a starting
  cumulative balance; pre-observation attribution is unsupported.
- Fee-on-transfer and rebasing token behavior cannot over-release funds.
- Rounding dust is bounded, non-negative, and non-withdrawable in v1.
- Release-to alternate recipient debits the entitled account.
- Assignment resolution follows token, collection, default.
- Assignment resolution and inherited-freeze counters use Core's authoritative
  token-to-collection mapping, not token ID ranges.
- Dynamic poster primary templates materialize the current poster into a fixed
  split profile at settlement.
- Template ID preimage, canonicalization, max entries, max account sources, and
  materialized metadata hash are deterministic.
- Materialized profile identity excludes sale-specific context; `saleContextHash`
  is event-only and uses a documented preimage.
- `saleContextHash` is not used as on-chain payment authority.
- Event `poster`, `payer`, and `beneficiary` fields are informational; actual
  payees are the materialized split profile entries.
- Different templates with identical concrete recipient sets may produce
  different wallets when `templateId` changes materialized metadata; recipients
  can claim from both and conservation holds per wallet.
- `PrimaryTemplateMaterialized` links template ID to profile ID and wallet.
- Unsupported primary template account sources revert before state changes.
- Template materialization gas is bounded independently of resolved account
  values.
- Zero dynamic accounts and dynamic/static `(account, labelId)` collisions are
  handled by pre-state-change rejection or deterministic aggregation.
- Frozen assignments cannot mutate.
- Inherited freezes block lower-scope set and clear operations; exact freezes
  affect only their explicit key.
- Applying inherited freeze with existing lower overrides reverts in launch v1.
- Global freeze is inherited across all scopes for its revenue class.
- Royalty bps is capped.
- `royaltyInfo()` returns the resolved split wallet.
- Core does not inherit or use OpenZeppelin `ERC2981` royalty storage.
- Core advertises ERC-2981 through custom `supportsInterface`.
- Resolver failure, malformed data, excess data, out-of-gas, and low-parent-gas
  reads return `(address(0), 0)` and are monitorable.
- Core `royaltyInfo()` returns `(address(0), 0)` and never reverts when the
  resolver consumes all gas, returns too little data, returns too much data,
  returns a zero receiver, returns zero bps, attempts an external-call path,
  or is incident-revoked.
- All-cold deepest-scope resolver gas is measured against the immutable cap with
  documented margin.
- Static analysis proves the production resolver royalty path contains no
  external-call or creation opcodes.
- Core royalty resolver gas limit is deploy-time immutable and fallback
  behavior is deterministic just below and above that limit.
- Huge resolver returndata cannot make Core OOG.
- Core royalty math returns the exact `floor(salePrice * royaltyBps / 10_000)` for
  every `uint256 salePrice` and allowed bps using full-precision arithmetic;
  arithmetic overflow, truncated arithmetic, reverts, or fallback-to-zero are not
  conformant.
- `royaltyInfo()` for premint or nonexistent token IDs does not revert and does
  not return collection receivers from heuristic range guesses.
- `royaltyBps = 0` returns `(address(0), 0)`.
- Profile ID, factory salt, wallet address, and wallet code hash are bound.
- Primary-sale split wallet deposit failure falls back to owed escrow without
  reverting minting or auction settlement.
- Predicted split wallets pre-funded before deployment cannot cause
  over-release or hide official sale deposit accounting.
- Wrong code at the deterministic split wallet address reverts before sale
  effects and is not routed to normal escrow.
- A pre-seeded wrong-code deterministic wallet address preserves escrow credit,
  emits/reverts with a distinct poisoned-address reason, and can be recovered
  only through the timelocked successor-wallet reroute path.
- Primary sale paths do not use `tx.origin` for payer, recipient, or execution
  identity.
- Static analysis fails the launch build if `tx.origin` appears in any
  production mint, sale, drop, auction, or authorization path.
- Signed primary sale authorizations bind `revenueClass` and
  `expectedPrimaryPolicyHash`, or explicitly opt into current-policy drift.
- Drop and sale identity hashes use `abi.encode` with chain ID and authorized
  caller where relevant, never packed string concatenation.
- Missing or malformed primary assignment reverts before minting or auction
  state changes.
- V1 primary settlement accepts native ETH and only approved standard ERC-20
  payments through accepted outside-Core adapters; unsupported assets and
  non-standard ERC-20 behavior revert unless a separate accepted adapter spec
  covers them.
- Auction settlement records settlement state and revenue before external NFT
  recipient callbacks.
- Fixed-price token-level primary overrides are used only when token ID is known
  before external callbacks.
- If a signed sale authorization expects a token-level primary override but the
  token ID has not been allocated authoritatively by Core, settlement
  reverts instead of silently downgrading to collection/default policy.
- Open-ended collection primary settlement succeeds without a configured final
  collection supply.
- If token-level royalty snapshots are used for an open-ended collection, a
  later collection royalty change does not affect those tokens.
- Mint-time royalty snapshot writes are atomic, idempotent for the same
  expected assignment, and O(1).
- If token-level royalty snapshots are not used, open-ended collection tokens
  follow the current collection assignment at `royaltyInfo()` time.
- Auction `saleId` is unique per primary auction or includes an auction nonce.
- Escrow flush is permissionless, idempotent, cannot double-credit, and cannot
  make owed funds emergency-withdrawable.
- Escrow flush sets owed credit to zero before factory deployment or transfer,
  and EVM revert restores the credit on failure.
- Escrow flush tests include a wallet/factory harness that reverts on the Nth
  deposit or deployment step and proves the cached owed amount is restored.
- Escrow flush rejects early when `gasleft()` is below the published
  `FLUSH_GAS_FLOOR`.
- Escrow can be credited against an undeployed official wallet only when the
  profile exists in the factory, the predicted address has no code, and the
  factory exposes permissionless deployment.
- Escrow flush accepts the runtime code hash captured at credit time after that
  hash is deprecated, unless it has been explicitly incident-revoked.
- Escrow keys and events include `revenueClass`.
- Inherited-freeze descendant counters or dirty bits enforce preconditions
  without enumeration.
- Unsupported asset marking is per-asset, blocks no other asset, and enables no
  sweep.
- Asset approval, deprecation, unsupported marking, and observation
  initialization events are emitted.
- Deprecated assets remain syncable and releasable for existing and passive
  receipts; unsupported assets do not.
- ERC-20 activation records evidence for standard monotonic-balance behavior.
- ERC-20 asset policy is read from the factory-bound deployment-wide asset
  policy registry; registry failure blocks only non-native assets.
- Release-before-explicit-sync computes from cumulative balance and updates
  `lastObservedReceived` only after transfer/delta checks.
- `syncAsset` on first zero balance initializes observation state.
- `syncAsset` ordering is initialize, revert on decrease, skip unchanged,
  update on increase.
- Collection-scope royalty resolution requires
  `tokenCollectionMappingExists[tokenId] == true`; unmapped tokens return
  default or zero.
- Royalty policy mode is configured and frozen with collection economics before
  public mint when collection economics are promised immutable.
- Royalty resolver ABI, selector, gas cap, and malformed-return fallback are
  fixed and tested.
- `royaltyInfo()` fallback-to-zero is paired with a non-view diagnostic probe
  and launch readiness gate.
- `probeRoyaltyInfo` uses the same selector, gas cap, parent gas precheck,
  returndata cap, and decode rules as production `royaltyInfo()`.
- Receipts smaller than the unique-account count remain bounded rounding dust
  until later receipts make entitlements claimable.
- External-ground-truth conservation fuzz invariant holds: the test harness
  independently counts deposits, direct transfers, and forced ETH, then asserts
  `sum(released) + sum(releasable) <= externalReceived`,
  `externalReceived - sum(released) - sum(releasable) == roundingDust`, and
  steady-state `roundingDust < uniqueAccounts` for approved standard assets.
- Cross-receipt dust does not accumulate because entitlements are recomputed
  from cumulative observed receipts.
- `observedReceived` never decreases after first observation for supported
  assets.
- Existing primary-sale pull-payment invariants remain true.
- Core size-budget gate is run for any Core change.
