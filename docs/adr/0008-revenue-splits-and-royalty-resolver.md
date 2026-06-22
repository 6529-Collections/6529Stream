# ADR 0008: Revenue Splits And Royalty Resolver

## Status

Proposed.

This ADR is a pre-launch target design record. 6529Stream has not launched, so
the revenue and royalty architecture should be implemented before launch as the
initial production architecture.
The cross-cutting 50+ year architecture principles live in
`docs/stream-long-term-architecture.md`.

## Metadata

| Field | Value |
| --- | --- |
| Date | 2026-06-22 |
| Issue | TBD |
| Related ADRs | `0003-payment-accounting.md`, `0004-admin-governance.md`, `0007-upgrade-redeployment.md` |
| Affected contracts | `StreamDrops`, `StreamAuctions`, `StreamCore`, new revenue resolver, new split wallets, optional label registry |
| Work type | `DESIGN` |

## Problem

The current `origin/main` payment architecture already moved primary-sale value
flows to pull-payment credits and already supports default, collection, and
token-level primary proceeds splits. The current split model is intentionally
small: poster, protocol, and curator buckets. That is useful implementation
context, but it is not expressive enough for a protocol expected to handle many
decades of artist, estate, collaborator, museum, protocol, curator,
restoration, legal, and public-goods revenue policies.

The current royalty architecture is narrower. `StreamCore.royaltyInfo()` returns
a fixed 690 bps ERC-2981 royalty to a fixed receiver. There are no runtime
royalty setters, no collection-specific royalty configs, no token-specific
royalty configs, and no royalty split wallet. Because Stream is pre-launch,
this should be replaced before launch with Core-native ERC-2981 backed by a
resolver and split wallets.

6529Stream needs a durable design that can run for 50 years without hardcoding
today's revenue labels, today's collaborator categories, or today's marketplace
assumptions into the NFT core.

## Decision

Adopt a satellite-first revenue architecture before launch, with mandatory
Core-native ERC-2981 royalty disclosure.

The target architecture has four conceptual components:

| Component | Responsibility |
| --- | --- |
| `StreamCore` | Own ERC-721 state, token-to-collection identity, and mandatory minimal resolver-backed ERC-2981. Mutable revenue policy stays outside Core, but Core must expose native ERC-2981 from launch. If bytecode pressure appears, refactor non-essential Core responsibilities out rather than dropping Core-native ERC-2981. |
| `StreamRevenueResolver` | Resolve primary-sale and royalty assignments by revenue class, default scope, collection scope, and token scope. |
| `StreamSplitWallet` | Hold native ETH and ERC-20 revenue for one immutable split profile and expose pull-based release functions. |
| `StreamLabelRegistry` | Optional human-readable label and URI metadata for arbitrary `bytes32` label IDs. Labels are descriptive only and never control accounting. |

Launch Core must implement `IERC2981` directly. It must not inherit or retain
OpenZeppelin `ERC2981` storage, because that would create a second royalty
source of truth and waste bytecode. `supportsInterface` must advertise ERC-2981
through the custom resolver-backed implementation.

Launch Core should allocate global sequential ERC-721 token IDs and store
explicit `tokenId -> collectionId` and `tokenId -> collectionSerial` mappings.
The existing namespaced token formula is current-code context, not the target
pre-launch architecture.
No revenue, royalty, freeze, or metadata rule may infer collection identity
from token ID ranges. The authoritative source is the explicit Core mapping for
minted, same-transaction allocated, custody-held, and burned tokens that retain
collection identity.
Burning removes ERC-721 ownership and enumerable membership, but it must not
clear `tokenCollectionId`, `tokenCollectionSerial`, or
`tokenCollectionMappingExists`; royalty disclosure for burned tokens continues
to resolve token, collection, then default scope.

The architecture separates immutable split profiles from mutable assignments:

- A split profile is immutable once created.
- A profile contains an arbitrary recipient list subject to explicit gas-bounded
  maxima for the wallet version.
- Each recipient entry has an account, a split fraction, and an arbitrary
  `bytes32 labelId`.
- Labels are open vocabulary. The protocol never hardcodes a permanent enum of
  labels such as artist, poster, protocol, curator, collaborator, or estate.
- A revenue assignment chooses which immutable profile applies to a revenue
  class and scope.
- Primary-sale assignments and royalty assignments are separate even when they
  happen to point to the same profile.
- Assignments may be changed only through explicit governance authority, clear
  events, and freeze policy.

## Current Implementation Baseline

Current primary-sale implementation baseline:

- `StreamDrops` has a `ProceedsSplit` with `posterBps`, `protocolBps`, and
  `curatorBps`.
- `StreamAuctions` has the same three-bucket split model.
- Each has a contract default plus collection and token overrides.
- Fixed-price and auction proceeds become pull credits instead of synchronous
  push payments.
- Integer remainders accrue to the protocol credit.
- Emergency withdrawals are surplus-only.
- The live `tx.origin` buyer/recipient pattern and push-payment remnants are
  not launch-acceptable. Launch sale contracts must bind payer and recipient in
  signed authorization and settle through resolver-backed pull accounting.

Current royalty implementation baseline:

- `StreamCore.royaltyInfo()` reports ERC-2981 support.
- The fixed receiver is `0xC8ed02aFEBD9aCB14c33B5330c803feacAF01377`.
- The fixed royalty rate is 690 bps.
- `tokenId` does not affect the royalty result.
- There is no royalty split profile, royalty resolver, runtime setter, or
  enforcement mechanism.

## Goals

1. Preserve ERC-721 transfer composability and keep royalty enforcement out of
   the default design.
2. Preserve pull-payment accounting and emergency surplus boundaries.
3. Support arbitrary recipient counts subject to explicit gas-bounded maxima,
   with larger future distributions handled by a new wallet version or adapter
   rather than unbounded loops.
4. Support arbitrary labels without freezing today's vocabulary into the
   protocol.
5. Support native ETH and ERC-20 releases for both primary and royalty revenue.
6. Support default, collection, and token-level assignment hierarchy.
7. Support separate primary-sale and royalty economics.
8. Make every policy mutation reconstructable through events and direct reads.
9. Keep `StreamCore` small, stable, and satellite-first.
10. Launch with Core-native resolver-backed ERC-2981 instead of relying on a
    royalty registry override.
11. Support fixed-size, capped-open, and uncapped-open collections without
    requiring final collection size at collection creation.
12. Use ADR 0004 governance classes for revenue resolver pointers, split
    factory replacement, assignment changes, freezes, and funds recovery.

## Non-Goals

- Enforcing secondary-sale royalties through transfer validators, operator
  filters, or marketplace allowlists.
- Guaranteeing that marketplaces pay ERC-2981 royalties.
- Replacing the curator Merkle reward policy.
- Making human-readable labels part of accounting correctness.
- Guaranteeing that future legal, tax, or estate arrangements can be inferred
  from labels alone.
- Hiding governance mutability. Mutability must be visible, bounded, and
  eventually freezable where the product promise requires it.
- Using a marketplace royalty registry override as the launch royalty path.
  Registry overrides may be documented as marketplace-specific integrations,
  but they are not a substitute for Core-native ERC-2981.

## Split Profiles

### Profile Identity

Each split profile has a deterministic profile ID. The profile ID is a
deployment-line identifier, not merely an economic-policy hash: it binds the
chain, factory, wallet version, wallet code, entries, and metadata hash so
events remain reconstructable decades later.

```solidity
bytes32 constant PROFILE_DOMAIN =
    keccak256("6529STREAM_SPLIT_PROFILE_V1");

bytes32 entriesHash = keccak256(abi.encode(canonicalEntries));
bytes32 metadataURIHash = keccak256(bytes(metadataURI));

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

This ADR intentionally uses `abi.encode`, a fixed field order, and explicit
integer widths. Implementations must not use packed encodings for the profile
ID. If a later factory or wallet implementation changes the profile preimage,
it must use a new `PROFILE_DOMAIN`, `schemaVersion`, or `walletVersion`.

`canonicalEntries` are sorted by `(account, labelId, sharePpm)` before hashing
and encoded as an `abi.encode` array of `SplitEntry` values. Implementations
must not use packed encodings, string encodings, or event display order for the
entries hash. Display order belongs in metadata, not in accounting identity.

`metadataURIHash` is immutable profile metadata. Mutable UI naming belongs in
the optional label registry or off-chain indexer metadata. Changing immutable
profile metadata requires a new profile ID.

### Entry Shape

```solidity
struct SplitEntry {
    address account;
    uint32 sharePpm;
    bytes32 labelId;
}
```

Rules:

- `account` must be non-zero.
- `sharePpm` must be non-zero.
- The sum of all `sharePpm` values must be exactly `1_000_000`.
- The number of entries must be at least 1 and at most the configured wallet
  maximum. The recommended initial limit is 64 entries and 64 unique accounts.
  Larger distributions should use a later wallet version, a Merkle/accounting
  adapter, or another explicitly reviewed design.
- The exact `(account, labelId)` pair must be unique within a profile.
- The same account may appear under multiple labels when the governance action
  intentionally records multiple roles for the same recipient.
- Entries must be canonicalized as described above.
- The factory must derive a deduplicated account list from entries, aggregate
  `sharePpm` per account, and check that the aggregate sum is exactly
  `1_000_000`.
- The per-account aggregate is derived from entries only. It is not separately
  settable by governance, operators, or profile creators.

The split denominator is parts-per-million rather than basis points so
long-lived profiles can express small allocations across many recipients.
Royalty rates remain basis points because ERC-2981 royalty expectations are
already basis-point oriented.

### Labels

`labelId` is an arbitrary `bytes32` identifier. Examples may be derived from
strings, but examples are not protocol constants:

```solidity
bytes32 labelId = keccak256(bytes("artist-estate"));
```

Labels are not permissions. Labels do not affect math. Labels do not decide who
can withdraw. They are event and UI semantics.

An optional label registry may expose:

```solidity
event LabelMetadataSet(
    uint16 schemaVersion,
    bytes32 indexed labelId,
    bytes32 supersedesLabelMetadataHash,
    bytes32 labelMetadataHash,
    string label,
    string uri
);

event LabelMetadataSuperseded(
    uint16 schemaVersion,
    bytes32 indexed labelId,
    bytes32 indexed oldLabelMetadataHash,
    bytes32 indexed newLabelMetadataHash
);

function labelMetadata(bytes32 labelId)
    external
    view
    returns (string memory label, string memory uri);
```

The label registry can be replaced, ignored, mirrored off-chain, or expanded
without affecting split wallet accounting.

If implemented onchain, label metadata should be append-only and
supersession-aware rather than silently mutable. A newer display label or URI
may supersede an older label record, but an old `labelId` must never be
reinterpreted in place. Split math always uses only `(account, labelId,
sharePpm)` from the immutable profile.

### Primary Split Templates

Royalty profiles must contain fixed account addresses because ERC-2981 gives
the receiver no sale context. Primary sales are different: `StreamDrops` and
`StreamAuctions` currently include dynamic sale participants such as the
`poster`, and that dynamic account is known only at settlement time.

Primary revenue assignments may therefore resolve to either:

- a fixed split profile, when every recipient account is known ahead of time; or
- a primary split template, when one or more recipients are dynamic sale
  participants.

Template entries use open `bytes32 accountSource` identifiers, not hardcoded
label enums:

```solidity
struct PrimaryTemplateEntry {
    address staticAccount;
    bytes32 accountSource;
    uint32 sharePpm;
    bytes32 labelId;
}
```

Exactly one of `staticAccount` or `accountSource` must be set. The sale contract
materializes the template into a concrete split profile by resolving each
supported `accountSource` from settlement context. The launch implementation
can map poster-like proceeds to a documented dynamic source such as
`keccak256("SALE_POSTER")`; protocol and curator-pool shares map to static
accounts. Unsupported dynamic sources must revert before mint or settlement
state changes.

Templates have deterministic IDs:

```solidity
bytes32 constant PRIMARY_TEMPLATE_DOMAIN =
    keccak256("6529STREAM_PRIMARY_TEMPLATE_V1");

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
`(staticAccount, accountSource, labelId, sharePpm)`. A template must have at
least 1 entry, at most the wallet version's entry maximum, and at most 8 unique
dynamic `accountSource` values in v1. The sum of `sharePpm` values must be
exactly `1_000_000`. A revenue class can use a template only when its settlement
contract declares support for every `accountSource` in the template. The
template metadata hash is immutable. The materialized profile metadata hash is
derived only from the template and resolved concrete entries:

```solidity
bytes32 materializedMetadataURIHash = keccak256(abi.encode(
    MATERIALIZED_PRIMARY_PROFILE_METADATA_DOMAIN,
    uint256(block.chainid),
    address(resolver),
    bytes32(templateId),
    bytes32(concreteEntriesHash)
));
```

`concreteEntriesHash` is the canonical profile entries hash after dynamic
sources are resolved and duplicate `(account, labelId)` pairs are aggregated.
The materialized profile ID and wallet address must not include sale-specific
fields such as `saleId`, `tokenId`, payer, beneficiary, amount, or
`saleContextHash`. Those values belong in events for reconstruction, not in
wallet identity.

For primary revenue events, sale context is:

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
on-chain payment authority. Consumers should verify emitted sale fields and
chain state; arbitrary off-chain context is not authenticated merely because it
hashes to the emitted value.

The materialized profile contains only fixed account addresses and follows the
same profile ID, wallet, accounting, and event rules as any other split profile.
Materialization resolves all dynamic sources before mint or settlement mutation.
If any source resolves to zero or is unsupported, settlement reverts before
state changes. If multiple template entries materialize to the same
`(account, labelId)` pair, their shares are aggregated into one concrete entry
before profile validation. Same-account entries under different labels remain
separate entries and aggregate only for release accounting. Materialization must
be gas-bounded independently of resolved account values and must deploy or
discover the deterministic wallet when the settlement gas envelope allows it. A
`CREATE2` collision for an identical concrete profile resolves to the existing
wallet and must not revert settlement.

Templates do not have a split wallet address. `walletFor(profileId)` applies to
fixed profiles only. A template must first materialize into a concrete profile
ID; callers must not conflate `templateId` with the materialized `profileId`.

### Rounding And Release Accounting

Because passive royalty receipts cannot run per-recipient accounting at receipt
time, a split wallet computes releasable funds from cumulative received funds:

```text
observedReceived(asset) =
  currentBalance(asset) + totalAccountReleased(asset)

accountEntitlement(account, asset) =
  floor(observedReceived(asset) * aggregateSharePpm(account) / 1_000_000)

releasable(account, asset) =
  accountEntitlement(account, asset) - accountReleased(account, asset)
```

The release ledger is keyed by the entitled split `account`, not by the payout
recipient. If an account releases to an alternate recipient, the debit still
applies to the entitled account. If the same account appears under multiple
labels, `aggregateSharePpm(account)` is the aggregate share across all of that
account's entries.

Assignment repointing never mutates an existing split profile or moves balances
out of an old split wallet. Accounts entitled under an old wallet remain able
to claim from that wallet forever. New assignments affect only new receipts.

Wallets must maintain a deduplicated account index:

```text
uniqueAccounts[] = deduplicated accounts from canonicalEntries
aggregateSharePpm(account) = sum sharePpm for that account across entries
sum(aggregateSharePpm(account) for account in uniqueAccounts) = 1_000_000
```

Rounding dust is the current unallocated balance after all deduplicated account
entitlements are considered:

```text
roundingDust(asset) =
  currentBalance(asset)
  - sum(releasable(account, asset) for account in uniqueAccounts)
```

For approved standard assets after successful observation, `roundingDust(asset)`
should be non-negative and less than the number of unique accounts. The
normative safety property is no over-release:
`sum(released) + sum(releasable) <= externalReceived` in the test harness.
Here `externalReceived` is the harness/indexer ground truth from official
deposits, direct transfers, and forced ETH, while on-chain releasable values are
computed from `observedReceived = currentBalance + totalAccountReleased`. After
observation has caught up with the external ground truth for an approved
standard asset so `observedReceived == externalReceived`, tests should also
assert:
`externalReceived - sum(released) - sum(releasable) == roundingDust(asset)`.
Entitlements must always be recomputed from cumulative `observedReceived`;
incremental per-receipt allocation is not a valid implementation for this
wallet version. Because the floor is applied to cumulative observed receipts,
rounding dust does not accumulate across receipts.
Rounding dust is not emergency surplus, and the v1 split wallet should not
include an ordinary dust sweep. Leaving tiny rounding dust in the wallet
preserves cumulative-entitlement fairness for later passive receipts. Any future
final dust sweep requires a separate decommission spec that accepts the risk of
later marketplace, forced-ETH, or direct-token receipts arriving after
finalization.

Conservation proof obligation:

```text
sum(aggregateSharePpm(account)) = 1_000_000
sum(floor(observedReceived * aggregateSharePpm(account) / 1_000_000))
  <= observedReceived
```

Because entries are aggregated by unique account before flooring, multiple
labels for the same account do not create extra entitlement or extra rounding
loss. Rounding dust is bounded by `uniqueAccounts - 1` for an observed balance
snapshot. Release order does not change `observedReceived` because release
decreases balance and increases `totalAccountReleased` by the same amount.
Implementations must use `mulDiv`-style arithmetic for the multiplication.

An ordinary release increments `accountReleased(account, asset)` and
`totalAccountReleased(asset)`. Release accounting follows
checks-effects-interactions (CEI): compute the releasable amount, update the
ledger, execute the native or ERC-20 transfer, and rely on revert semantics to
restore the ledger if the transfer fails. A failed release leaves the account's
releasable amount claimable. Recipients whose own address rejects native ETH can
release to a non-zero alternate recipient.
The wallet uses one release reentrancy guard across all assets and recipients,
not a per-asset lock. A native ETH recipient cannot reenter to release ERC-20s,
and an ERC-20 callback cannot reenter to release native ETH or another token.

Anyone may call `release(asset, account, account)` to release to the entitled
account. Releasing to any alternate recipient requires `msg.sender == account`
or a valid EIP-712/ERC-1271 release authorization signed by the entitled
account. The authorization binds wallet, chain ID, asset, account, recipient,
nonce, and deadline. Nonces are consumed before transfer under CEI.
ERC-1271 verification for alternate-recipient release uses a deploy-time
immutable `ERC_1271_GAS_LIMIT`, `staticcall`, and bounded returndata decoding.
A failed, out-of-gas, malformed, or wrong-magic-value `isValidSignature`
staticcall reverts the alternate release before nonce consumption or transfer. The initial planning cap
is 50,000 gas, but launch uses measured gas plus margin and records it in the
release manifest.

The native asset sentinel for events and views is `address(0)`. ERC-20 assets
use the token contract address. Native ETH and each ERC-20 asset are
independently keyed in release, observed, and escrow accounting. No asset
balance may be used to satisfy another asset's release or escrow obligation.
`syncAsset` shares the wallet-wide reentrancy guard with `release`; reentrant
sync during an active release reverts, and operators should sync before release
when they want a separate observation transaction.

For native ETH, `receive()` must not update observation state. Observation is
lazy and happens only during `release(address(0), ...)` or
`syncAsset(address(0))`. The first observation initializes
`lastObservedReceived(address(0))` to
`address(this).balance + totalAccountReleased(address(0))` and emits an
initialization event even at zero balance. Later observations revert if the
cumulative observed value decreases, skip if unchanged, and update if
increased.

## Split Wallets

Each split profile should resolve to one wallet address. The v1 factory deploys
wallets using a fixed-runtime minimal proxy or equivalent clone pattern with
`CREATE2` so addresses are deterministic and discoverable before funds arrive.

In v1, profile entries are not constructor arguments. The wallet creation code
and runtime code hashes are release constants. The factory deploys the wallet,
then initializes profile storage exactly once in the same transaction. The
profile is immutable after initialization because the wallet exposes no mutator
for entries, aggregates, profile ID, or metadata hash.

The wallet `initialize` function must have a one-call initializer guard and
must revert on every call after the first successful initialization. It must be
callable only by the official factory during the deployment/initialization
flow; a directly deployed clone or externally called initializer is not a valid
split wallet.

The wallet binding must be explicit:

```text
salt = profileId
wallet = address(uint160(uint256(keccak256(abi.encodePacked(
    bytes1(0xff),
    address(factory),
    profileId,
    splitWalletInitCodeHash
)))))
```

The factory must expose `walletFor(profileId)` and a permissionless idempotent
`deployWallet(profileId)`. `deployWallet` must verify that the profile was
created through the factory, compute `walletFor(profileId)`, check for existing
code before attempting `CREATE2`, deploy and initialize when absent, return the
existing wallet when already deployed with the expected profile ID and runtime
code hash, and revert on wrong code. Unknown profiles and wrong-code predicted
addresses must use distinct custom errors so operators and indexers can
distinguish ordinary missing-profile mistakes from address-collision incidents.
Wrong code at the deterministic wallet address is
`ESCROW_ADDRESS_POISONED`. Normal `flushEscrow` must revert with a distinct
wrong-code error and leave owed credit intact. The intended wallet can never be
deployed at that poisoned address, so recovery may reroute only escrow-held
owed credit to a successor profile with a new profile ID and deterministic
wallet through the timelocked successor-wallet path. Funds already resident at
the poisoned address are not normal escrow assets.
The wallet must expose `profileId()`. A resolver assignment is valid only when:

```text
wallet == factory.walletFor(profileId)
wallet.profileId() == profileId
wallet.codehash == approved split wallet runtime codehash
```

This prevents governance or operator error from pairing a profile ID with a
wallet that uses different recipients.

A "verified split wallet" means all of the following are true: the wallet equals
`factory.walletFor(profileId)`, the profile was created by the factory, the
wallet was deployed through the bound factory init code, `wallet.profileId()`
equals the expected profile ID, and the runtime code hash is active or otherwise
eligible for the specific escrow credit being flushed.

Assignments must reference already-deployed wallets. Counterfactual addresses
are useful for prediction, but no active primary or royalty assignment should
return an undeployed wallet as its receiver. If a fixed assignment resolves to
an undeployed wallet, settlement treats the assignment as malformed and reverts
before sale effects. Undeployed-wallet escrow is allowed only for a materialized
primary template whose profile has been created through the factory and whose
predicted wallet address has no code.

If a later wallet version uses constructor arguments or immutable args instead
of clone storage initialization, that version must use a new `walletVersion` and
profile preimage that binds the full creation-code hash and argument hash. It
must not reuse the v1 profile ID rules.

Required behavior:

- Accept native ETH through `receive`.
- Keep `receive` non-reverting, storage-free, and recipient-code-free.
- Accept ERC-20 tokens by balance observation.
- Never execute recipient code during deposits.
- Release native ETH and ERC-20s through pull functions.
- Let a recipient release to self or to a non-zero alternate recipient.
- Emit events for release owner, recipient, asset, amount, profile ID, and new
  released total.
- Expose profile entries, deduplicated account aggregates, profile hash, total
  released per asset, released per account per asset, and releasable views.
- Expose paginated profile reads: `entryCount()`,
  `entries(uint256 start, uint256 limit)`, `accountCount()`, and
  `accounts(uint256 start, uint256 limit)`. Arbitrary split counts must not
  force one unbounded ABI return.
- Treat direct and forced ETH as received revenue, not as emergency surplus.
- Make rounding dust explicit, bounded, and non-withdrawable in v1.
- Provide an anyone-callable `syncAsset(asset)` that emits the observed balance
  and observed cumulative asset state for native ETH or a specific ERC-20.
  Passive ERC-20 transfers cannot be discovered on-chain without a token
  address, so operator and recipient tools must support explicit asset lookup
  and index ERC-20 `Transfer` logs. `syncAsset` is O(1): it does not compute
  per-account releasable amounts or rounding dust. Those views may be O(N)
  across the bounded unique account list. `syncAsset` skips emission when no
  observed value changed after the asset has already been initialized. The first
  `syncAsset(asset)` initializes `lastObservedReceived(asset)` and emits an
  observation event even when the observed balance is zero.
- Keep standard ERC-20 accounting balance-observed only for approved standard
  ERC-20 assets. ERC-20 assets are default-deny. Asset policy is
  deployment-wide, not per wallet. The split factory records the immutable
  `assetPolicyRegistry` for its wallet line, and wallets consult that registry
  during non-native `syncAsset` and `release`. Native ETH is always supported
  without registry reads. If the registry is unavailable or an asset is unknown,
  non-native sync/release reverts safely for that asset only; native ETH and
  other active assets remain unaffected. The asset-policy registry read is
  bounded: each wallet line pins `ASSET_POLICY_GAS_LIMIT`,
  `ASSET_POLICY_RETURN_BYTES`, and an EIP-150-aware parent gas precheck in its
  release manifest. Malformed return data, no code at the registry, registry
  revert, oversized returndata, or under-forwarded gas makes the specific
  non-native `syncAsset` or `release` revert before ledger mutation. The wallet
  must not substitute active semantics when the asset policy read fails. The
  initial planning target for `ASSET_POLICY_GAS_LIMIT` is 30,000 gas for an
  all-cold lookup, with the deployed value set from measured gas plus margin. If the
  immutable registry for a wallet line becomes incompatible under a future EVM
  or gas schedule, the recovery path is a new split-wallet/factory deployment
  line and governed assignment migration for future receipts, not a hidden
  registry pointer change inside deployed wallets. An asset admin can approve a
  standard ERC-20, deprecate approval for future
  receipts, or mark an observed asset unsupported. Asset state is explicit:
  `ACTIVE` assets may be accepted by
  official adapters and released; `DEPRECATED` assets should not be accepted by
  new official adapters but existing observed balances and later passive
  receipts remain syncable and releasable under the same monotonic-token
  assumption; `UNSUPPORTED` assets disable release and sync until a later
  adapter or recovery spec accepts them. Fee-on-transfer, rebasing, callback,
  no-op-transfer, and other non-standard accounting tokens are unsupported
  unless a later asset-specific adapter spec accepts them.
  Moving an ERC-20 asset to `ACTIVE` is an asset-policy decision. The policy
  admin should record evidence that the token has no transfer fees, rebases,
  confiscation mechanics, balance-decreasing hooks, callback surprises, or
  no-op transfer behavior that would violate monotonic-balance accounting.
  Unsupported-asset recoverability is deferred to a future state transition or
  adapter or recovery spec; unsupported state is not a sweep authority.
  If an ERC-20 moves `DEPRECATED -> ACTIVE`, equality conservation is
  re-established only after the next successful `syncAsset(asset)` observation;
  between transitions, no-over-release is the required safety property.
- ERC-20 releases must use safe transfer handling plus exact wallet
  balance-delta checks: the wallet balance must decrease by exactly the released
  amount. Recipient balance-delta checks belong in asset-specific adapters when
  reliable; they are not a generic ERC-20 requirement.
- Track `lastObservedReceived(asset)` on release or `syncAsset`. If
  `currentBalance(asset) + totalAccountReleased(asset)` falls below the last
  observed value, release and sync for that asset must revert with an
  unsupported-balance-decrease error instead of underflowing or silently
  reducing entitlements. `syncAsset(asset)` ordering is: initialize and emit on
  first call even at zero balance; otherwise revert on observed decrease;
  otherwise skip emission if unchanged; otherwise update and emit. During
  release, compute entitlement, update the release ledger, transfer with
  safe-transfer handling, prove exact wallet balance decrease for ERC-20s, and
  then update `lastObservedReceived(asset)` from the post-transfer balance plus
  updated release totals. Never update from an intermediate CEI state. If the
  transfer or delta check fails, the transaction reverts and restores the ledger
  and observed state.
  `lastObservedReceived(asset)` is initialized at the first asset detection
  through `syncAsset`, official deposit, or release; UIs and operators should
  sync an ERC-20 asset before presenting claimable amounts.
  Unknown ERC-20s sent directly before first observation are unsupported for
  historical guarantees; the wallet can only account from the first observed
  balance.
- A governance-gated `markUnsupportedAsset(asset)` path may freeze only that
  asset when an unsupported balance decrease is detected. It must not enable any
  sweep or admin withdrawal, and it must not block native ETH or other assets.
  Unsupported marking disables release and sync for that asset until a later
  asset-specific adapter or recovery spec is accepted.
- Avoid upgradeable wallet logic unless a later ADR accepts the long-term trust
  tradeoff.

The split wallet can be immutable and very small because profile changes are
represented by creating a new wallet and repointing assignments.

## Revenue Classes

Revenue assignments should use open `bytes32 revenueClass` identifiers instead
of a permanent enum. Known classes can be documented constants, but future
classes remain possible:

```text
PRIMARY_FIXED_PRICE
PRIMARY_AUCTION
ROYALTY_ERC2981
CURATOR_RESERVE_RELEASE
PRIMARY_DROP_2034
```

Implementations may provide helper constants for common classes, but the
storage model should not prevent new classes over a 50-year horizon.

## Open-Ended Collections And Revenue Epochs

The resolver must support permanent-contract collections whose final size is not
known in advance. A collection can be an ongoing artist series, add tokens over
many years, pause, resume, and eventually close without changing its collection
identity.

Revenue policy is independent of final supply:

Normative token ID model:

```text
global sequential ERC-721 token IDs
explicit tokenId -> collectionId mapping
explicit tokenId -> collectionSerial mapping
explicit mapping-existence bit for royalty resolution
```

The current namespaced token ID formula is removed before launch. Collection
serials remain stable local display/accounting facts, but `royaltyInfo()` and
metadata routing use explicit mappings rather than token ID arithmetic.

- Collection-scope assignments apply to all tokens in the collection unless a
  token-level assignment exists.
- Primary-sale economics are materialized at sale or mint settlement; historical
  primary proceeds do not change when a later collection assignment changes.
- Royalty assignments are read at `royaltyInfo()` time. If a token must preserve
  mint-time economics, the sale or mint path writes a token-level royalty
  assignment at mint.
- Without a token-level royalty snapshot, a token follows the current collection
  assignment, then default assignment.
- Closing a collection does not itself freeze revenue policy. Revenue freezes
  are explicit resolver actions.
- `saleId` identifies a drop, auction, or primary sale event inside a
  collection. It must not be treated as a collection ID or final-supply signal.
- Resolver reads never require final collection supply.

If mint-time royalty economics must persist, the authorized mint or sale path
must call the resolver to snapshot the resolved collection/default royalty
assignment into a token-level assignment after Core allocates the token ID and
before the transaction completes. The snapshot hook is O(1), idempotent for the
same expected assignment, and reverts on conflicting prior token assignment.

Each collection should declare its royalty policy mode before public mint:

```text
ROYALTY_LIVE_COLLECTION     tokens follow current token/collection/default assignment
ROYALTY_SNAPSHOT_AT_MINT    mint writes token-level royalty assignment snapshot
```

The policy mode is evented and frozen with collection economics when the
collection promises immutable economics. `ROYALTY_SNAPSHOT_AT_MINT` costs more
per mint but gives each token durable mint-time royalty policy.

## Assignment Hierarchy

Assignments resolve in this order:

1. token assignment;
2. collection assignment;
3. contract default assignment.

Assignments are keyed by:

```text
revenueClass
scope
scopeId
```

where `scope` is default, collection, or token.

For open-ended collections, collection scope remains valid even when max supply
is unknown. Collection-level assignments apply to future tokens until changed or
frozen. Token-level assignments are reserved for token-specific economics or
mint-time snapshots.

Canonical economic hashes:

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

Signed sale policy, royalty snapshots, resolver probes, and assignment events
must use these preimages or a later versioned replacement.

Primary-sale assignment:

```solidity
struct PrimaryRevenueAssignment {
    bytes32 profileOrTemplateId;
    address splitWallet;
    bool isTemplate;
    bool configured;
    uint8 freezeMode;
    bool permanentFreeze;
}
```

Royalty assignment:

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

Rules:

- Any assignment that stores a non-zero `splitWallet` must prove that the wallet
  is the factory wallet for the stored profile ID.
- Fixed primary assignments use `isTemplate = false` and resolve directly to a
  verified split wallet.
- Dynamic primary assignments use `isTemplate = true`; `splitWallet` is
  `address(0)` at assignment time, and the sale contract materializes a fixed
  profile and wallet during settlement.
- `royaltyBps` must be less than or equal to the resolver's immutable
  `maxRoyaltyBps`.
- The recommended initial `maxRoyaltyBps` is 1000 for a first resolver
  deployment. Some marketplaces warn on or reject royalties above 1000 bps. A
  later deployment line may raise or lower the cap through a new resolver and
  explicit rollout plan, but the cap is immutable within one resolver
  deployment.
- Assignment setters must validate wallet deployment, `walletFor(profileId)`,
  `wallet.profileId()`, and an active runtime code hash at assignment time.
  Core `royaltyInfo()` must not redo expensive wallet validation on every read.
- Clearing an assignment reverts resolution to the next lower scope unless the
  scope is frozen.
- Assignment storage must distinguish unfrozen, exact frozen, inherited frozen,
  global frozen, permanent, and timelocked-unfreezeable states; a single
  `bool frozen` is insufficient for implementation.
- Freezing a scope prevents future changes for that revenue class and scope.
- Freezes must specify `freezeMode`: `EXACT` freezes only that key, while
  `INHERITED` blocks lower-scope set and clear operations under the frozen
  scope. Product-level economic promises should use `INHERITED`.
- Setter and clearer rule: if the nearest frozen ancestor for
  `(revenueClass, scope, scopeId)` has `freezeMode = INHERITED`, all lower-scope
  set and clear operations for that ancestor revert. `EXACT` freezes do not
  block lower scopes. In launch v1, applying an `INHERITED` freeze with any
  mutable lower-scope override under that ancestor must revert. A later ADR may
  add a bounded descendant-freeze batch operation, but v1 must not rely on
  enumerating arbitrary token-level descendants.
- The resolver must maintain O(1) descendant override counters or dirty bits per
  `(revenueClass, scope, scopeId)` so inherited-freeze preconditions can be
  enforced without enumerating token-level assignments. Setting an override
  increments each relevant ancestor counter using Core's authoritative
  token-to-collection mapping for token-scope assignments; clearing decrements
  the same ancestors. A token-scope assignment cannot be created from a token ID
  range guess or unknown future token ID.
- A global freeze is implicitly `freezeMode = INHERITED` across default,
  collection, and token scopes for the affected revenue class. It can make all
  assignments immutable for a deployment line. Whether it also blocks entirely
  new revenue classes must be an explicit release decision; deployment-wide
  global freeze should block both.
- Every set, clear, and freeze action must emit enough data for indexers to
  reconstruct historical policy.

## Primary-Sale Settlement

Future `StreamDrops` and `StreamAuctions` should resolve primary-sale
assignments through the revenue resolver rather than storing only
poster/protocol/curator basis points locally.

The v1 primary adapter is native ETH only. ERC-20 primary sales require a later
asset-specific primary adapter with exact token-transfer accounting, escrow
flush rules, and tests. Split wallets may still release approved ERC-20 assets
received passively or through future adapters.

Signed primary-sale authorizations must bind the economic policy being used.
For fixed-price drops and any signed auction creation path, the signed payload
should include:

```solidity
bytes32 revenueClass;
bytes32 expectedPrimaryPolicyHash;
uint8 primaryPolicyMode; // STRICT_MATCH or ALLOW_CURRENT
bytes32 initialRecipientsHash;
bytes32 beneficiariesHash;
address payer;
address executor;
uint256 saleIdOrNonce;
```

`expectedPrimaryPolicyHash` commits to the resolved assignment or template
policy the signer expects. `STRICT_MATCH` is the launch default and reverts if
the resolver state has drifted. `ALLOW_CURRENT` is allowed only when the product
intentionally lets the current resolver assignment govern the sale, and that
choice must be visible in events. If a scope freezes before settlement,
`ALLOW_CURRENT` resolves the then-current frozen assignment. Silent drift is not
acceptable; `STRICT_MATCH` remains the default for economically material sales.
Settlement events must expose whether drift was observed between the signed
`expectedPrimaryPolicyHash` and the resolved settlement policy.
The resolved primary policy hash includes `freezeMode` and `permanentFreeze`.
A freeze between signature and settlement therefore changes the hash and makes
`STRICT_MATCH` revert unless the signer authorized the frozen policy hash.
`ALLOW_CURRENT` is the explicit opt-in to that drift.

No production sale path may use `tx.origin` as payer, recipient, executor, or
authorizer. The drop and auction authorization rewrites are hard launch gates:
the signed authorization must bind the actual payer, recipient or recipient
batch, executor, price, quantity, nonce, deadline, collection, sale program, and
policy hash. Settlement recomputes those values from calldata and chain state.
Static analysis must fail the launch build if `tx.origin` appears in a
production mint, sale, drop, auction, or authorization path.

Target fixed-price flow:

1. Validate the signed drop authorization and payment.
2. Resolve the primary split assignment for the revenue class and collection.
   Token-level fixed-price primary overrides are available only for mint paths
   that can authoritatively allocate `tokenId` and write the Core
   token-to-collection mapping before any external callback. Otherwise
   fixed-price primary resolution is collection/default for that transaction
   only when the signed `expectedPrimaryPolicyHash` did not require a token
   override. If the signed authorization expected a token-level override but the
   token ID is not authoritatively allocated, settlement reverts instead of
   silently downgrading. A missing or malformed primary assignment reverts
   before minting or other external effects.
3. If the assignment is a template, materialize it with the sale context
   including the actual poster account, then deploy or discover the concrete
   split wallet.
4. Allocate token identity only through `prepareMintFromManager` when token-level
   economics must be snapshotted before `_safeMint`; otherwise record revenue
   before calling the single-step mint path.
5. If the resolved wallet is deployed and still has the active or
   credit-eligible runtime code hash,
   attempt a gas-bounded native deposit to the official split wallet.
6. If the assignment was a materialized template, the wallet is undeployed, and
   the profile was created through the official factory, or if a deployed
   correct wallet rejects the gas-bounded deposit, record the amount in the
   protocol-owned revenue escrow under `(revenueClass, profileId, wallet,
   asset)`. A fixed assignment resolving to an undeployed wallet is malformed
   and reverts before sale effects. If the deterministic wallet address contains
   unexpected code, revert before sale effects; normal escrow must not be used
   for wrong-code addresses.
7. Emit a primary revenue event only after the sale amount is either held by the
   official split wallet or recorded as owed by the protocol-owned revenue
   escrow.
8. Include `saleKind`, `saleId`, collection ID, token ID, payer, poster,
   beneficiary, revenue class, profile ID, wallet, asset, amount, and whether
   the profile came from a template.

Launch paid primary mints must use exactly one of two atomic paths:

`PRE_REVENUE_SINGLE_STEP`: sale adapter validates payment and
`expectedPrimaryPolicyHash`, resolves only collection/default primary policy,
materializes the split profile if needed, deposits or escrows native ETH, then
calls the mint manager, ledger, and Core `mintFromManager`. Token-level primary
overrides and required mint-time royalty snapshots are unavailable in this path.

`PREPARED_MINT`: sale adapter validates payment and `expectedPrimaryPolicyHash`,
mint manager and ledger validate/consume policy, Core
`prepareMintFromManager` allocates authoritative token identity without an
ERC-721 transfer, resolver snapshots required token-level economics, the sale
adapter deposits or escrows native ETH, and Core
`completePreparedMintFromManager` performs `_safeMint`.

Token-level economic snapshots in `PREPARED_MINT` must be independent of
entropy seed and entropy status. They may read Core token identity, assignment
state, signed authorization fields, and active policy hashes, but they must not
read or branch on randomness, renderer output, or provider lifecycle state.

If any step reverts, all earlier state in the transaction reverts. No untrusted
callback may execute before ledger consumption, token identity mapping, required
assignment snapshots for the chosen path, and revenue accounting are complete.
`PREPARED_MINT` uses the canonical `STREAM_PREPARED_MINT_OPERATION_V1`
`operationId` defined in `docs/mint-policy-and-accounting.md`; the sale
adapter, manager, ledger, Core prepare/complete, resolver snapshot hook,
entropy registration boundary, and escrow/deposit path must reject mismatched
operation IDs.

Target auction settlement flow:

Launch auctions require a real `StreamAuctions` or equivalent settlement
contract with bid custody, pull refunds, cancellation/expiry handling, and the
settlement flow below. The current drop-side auction placeholder is not a
launch auction settlement path.

1. Keep active bids as auction escrow until settlement.
2. Resolve the primary auction split assignment.
   A missing or malformed primary assignment reverts before auction settlement
   state changes.
3. If the assignment is a template, materialize it with auction context
   including the actual poster account, then deploy or discover the concrete
   split wallet.
4. Mark the auction settled and debit bid escrow before any external recipient
   callback.
5. If the resolved wallet is deployed and still has the active or
   credit-eligible runtime code hash,
   attempt a gas-bounded native deposit to the official split wallet.
6. If the assignment was a materialized template, the wallet is undeployed, and
   the profile was created through the official factory, or if a deployed
   correct wallet rejects the gas-bounded deposit, record the amount in the
   protocol-owned revenue escrow under `(revenueClass, profileId, wallet,
   asset)`. A fixed assignment resolving to an undeployed wallet is malformed
   and reverts before sale effects. If the deterministic wallet address contains
   unexpected code, revert before sale effects; normal escrow must not be used
   for wrong-code addresses.
7. Emit an auction revenue event only after the winning bid is either held by
   the official split wallet or recorded as owed by the protocol-owned revenue
   escrow.
8. Transfer the NFT according to ADR 0002 after settlement state and revenue
   accounting are finalized. If the NFT transfer reverts, the transaction
   reverts atomically, but reentrant callbacks cannot observe an unsettled
   auction or unrecorded revenue.
9. Include `saleKind`, `saleId`, token ID, collection ID, bidder, poster,
   beneficiary, revenue class, profile ID, wallet, asset, amount, and whether
   the profile came from a template.

The direct-deposit gas limit must be a named release constant, measured against
the approved split wallet `receive`, and tested with a malicious wallet and an
out-of-gas receiver. Failure to fund the split wallet is not a sale failure; it
is an escrowed-revenue state.
The release manifest must also publish `MATERIALIZATION_GAS_BUDGET` for primary
template materialization plus separate measured gas for wallet deployment,
wallet discovery, and escrow-credit creation. If deployment cannot fit the
settlement envelope, settlement may use escrow only after deterministic
factory/profile preimage checks pass.

When settlement materializes a primary template, the settlement gas budget must
account for deploy-or-discover work. If deploying the materialized wallet cannot
fit within the bounded settlement path, the sale records native revenue in
escrow against the deterministic wallet only if the profile preimage has been
validated, the profile exists in the factory, the predicted wallet has no code,
and `wallet == factory.walletFor(profileId)`. Deployment or discovery then uses
the permissionless factory path before or during a later flush.
`factory.deployWallet(profileId)` remains permissionless even if the predicted
wallet address already received direct or forced ETH; that ETH becomes part of
the wallet's native balance after deployment and is distributed by the immutable
profile shares.
This must be tested as an adversarial pre-seeding condition. A predicted wallet
that receives ETH before deployment cannot cause over-release, cannot hide
official sale deposits, and should be displayed separately by indexers when
reconstructing sale economics.
The future deployment is non-malicious because the deterministic address binds
the factory address, profile ID salt, and factory-controlled init code hash. Any
different code at that address fails the existing-code check and is treated as
an address-collision incident.

Revenue escrow lifecycle:

- Escrow credits are keyed by `(revenueClass, profileId, wallet, asset)` and
  can only be created by approved sale or auction contracts.
- In v1, escrow credits must use `asset = address(0)` because primary
  settlement is native ETH only. Non-native assets revert until an ERC-20
  primary adapter ADR is accepted.
- The `wallet` in the escrow key is captured at credit time. Repointing a
  revenue assignment later does not move existing escrow credits to a new
  wallet.
- Escrow credits may be created only for a deployed correct wallet or for an
  undeployed deterministic wallet whose profile was created through the
  factory, whose predicted address has no code, and whose expected runtime code
  hash is active at credit time.
- Escrow credits store `factory` and `escrowRuntimeCodeHash`. For an undeployed
  deterministic wallet, the runtime hash is the expected runtime hash from the
  profile's wallet version; for a deployed wallet, it is the observed code hash
  accepted at credit time.
- Escrowed revenue is owed revenue, never emergency surplus.
- The escrow exposes permissionless
  `flushEscrow(revenueClass, profileId, wallet, asset)`.
- `flushEscrow` enters a non-reentrant guard, verifies
  `wallet == storedFactory.walletFor(profileId)`, reads the owed amount, sets
  the owed credit to zero, deploys the wallet through
  `storedFactory.deployWallet(profileId)` if absent, verifies that the wallet
  code hash either matches `escrowRuntimeCodeHash` or is currently active, and
  then transfers the cached amount. `flushEscrow` uses the factory stored with
  the credit, not a mutable resolver or factory pointer.
- The escrow also exposes a permissionless
  `flushToVerifiedWalletBestEffort(revenueClass, profileId, wallet, asset)`
  path that never calls `deployWallet`. It can flush only to an already
  deployed wallet whose profile ID and runtime code hash match the stored
  credit. It exists for degraded gas-schedule conditions and cannot recover
  credits whose wallets were never deployed.
- If deployment, validation, or transfer reverts, EVM revert semantics restore
  the owed credit.
- On successful flush, escrow emits an event with the flushed amount and
  remaining owed balance.
- `flushEscrow` is the reverting v1 path. If deployment, validation, or transfer
  fails, the transaction reverts and the escrowed credit remains owed. A failed
  flush must not double-credit or make funds sweepable.
- `flushEscrow` must reject before zeroing owed credit unless `gasleft()` is
  above a published `FLUSH_GAS_FLOOR` sized for worst-case deployment,
  validation, and native deposit with margin. The release manifest records
  measured deployed-wallet and undeployed-wallet flush gas for each wallet
  version and factory line.
- For v1, `FLUSH_GAS_FLOOR` must be a deploy-time immutable or equivalent
  manifest-pinned constant for the escrow implementation, not mutable
  governance state. A later escrow version may choose a different measured
  floor, but it must publish the new value, bytecode hash, factory line, and
  gas evidence in the release manifest before activation.
- The floor calculation must account for EIP-150's 63/64 gas forwarding rule
  for each external subcall. Tests must measure actual gas delivered to
  `deployWallet` and to the wallet deposit/receive path, not merely parent
  `gasleft()`.
- After owed credit is zeroed, any deployment, code-hash check, or transfer
  failure must bubble as a revert of the whole `flushEscrow` call, restoring
  owed credit through EVM rollback. Launch code must not swallow post-zeroing
  failures in `try/catch`, return a false success, or emit a flushed event
  after a failed subcall. Tests must include a subcall out-of-gas after the
  zeroing point and prove owed credit remains intact.
- Escrow events are chain-finality-sensitive reconstruction facts. Indexers and
  accounting exports should treat deposits, flushes, and recoveries as
  provisional until their normal confirmation depth, then reconcile against
  canonical onchain owed balances so reorgs can be replayed deterministically.
- If a future gas-schedule change makes the immutable `FLUSH_GAS_FLOOR`
  incorrect, the correction path is a new escrow deployment line plus governed
  successor-wallet or escrow-credit recovery for affected credits. Monitoring
  must alert when measured flush gas approaches the immutable floor with
  insufficient margin. Launch operations should alert when measured worst-case
  undeployed-wallet flush gas exceeds two-thirds of `FLUSH_GAS_FLOOR` or when
  the margin falls below the release-manifest SLO, whichever is stricter.
  If `FLUSH_GAS_FLOOR` becomes permanently unreachable while governance quorum
  is lost and a credit's wallet was never deployed, that credit is a known
  terminal availability risk until a social successor process outside the old
  escrow contract is accepted. The spec does not add hidden sweep authority to
  solve that combined failure.
- Deprecating a runtime code hash is forward-looking and does not block flushing
  credits created while that hash was active. Deprecating or replacing the
  active factory is also forward-looking and does not block credits created
  under an older stored factory. Only explicit incident revocation can block
  normal flush for an escrow factory or runtime hash.
- Incident-revoked escrow recovery is a launch primitive, not an unspecified
  future escape hatch. A timelocked successor-wallet recovery operation may
  reroute only escrow-held owed funds for an affected credit key. It must name
  `(revenueClass, profileId, wallet, asset)`, old wallet, successor wallet, old
  profile, successor profile, old and new runtime code hashes, amount, and
  reason URI/hash. The successor wallet must be deployed or deployable through
  an approved factory and active runtime code hash. The recovery cannot seize,
  sweep, or move funds already held by the old split wallet.
- Escrow recovery is ABI-shaped, not ad hoc governance:

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

  `recoveryId` is `keccak256(abi.encode(STREAM_ESCROW_RECOVERY_V1,
  block.chainid, address(escrow), creditKey.revenueClass, creditKey.profileId,
  creditKey.wallet, creditKey.asset, successorWallet, successorProfileId,
  successorRuntimeCodeHash, expectedAmount, recoveryManifest.contentHash,
  executeAfter, reasonHash))`. Execution rechecks status `SCHEDULED`, delay, current owed
  amount equals `expectedAmount`, stored factory, incident status, successor
  profile/wallet/codehash validity, and whether economics are identical or
  explicitly changed in the manifest.
- `ESCROW_ADDRESS_POISONED` recovery must use a new profile ID and new
  deterministic wallet address; the old poisoned destination remains part of
  the incident record and cannot receive normal flushes.
- Wallet-observed release accounting excludes escrow-owed balances until a
  flush or recovery transfer actually reaches a split wallet. System
  conservation includes both wallet-observed balances and escrow-owed balances.

The implementation must preserve current ADR 0003 invariants:

- rejecting recipients cannot block minting or settlement;
- failed recipient withdrawals do not erase credit;
- owed funds cannot be emergency-withdrawn as surplus;
- direct and forced ETH do not corrupt accounting;
- every wei is either claimable, reserved, dust-bounded, or explicitly surplus.

Assignments must not be able to point primary revenue at arbitrary receiver
contracts. They may point only at official split wallets verified by factory,
profile ID, and runtime code hash, or at a protocol-owned revenue escrow with
the same owed/surplus boundaries as ADR 0003. This keeps recipient contracts
from blocking minting or settlement.
Selector-stable launch interfaces for `IStreamSplitFactory`,
`IStreamSplitWallet`, `IStreamRevenueEscrow`, and assignment reads are defined
in `docs/revenue-splits-and-royalties.md` and must be pinned in the release
selector manifest.

## Royalty Resolution

ERC-2981 imposes a hard constraint:

```solidity
function royaltyInfo(uint256 tokenId, uint256 salePrice)
    external
    view
    returns (address receiver, uint256 royaltyAmount);
```

Marketplaces usually transfer funds to `receiver`. They do not pass `tokenId`,
collection ID, profile ID, or payer metadata to the receiver. Therefore, if
royalty splits vary by default, collection, or token, `receiver` must be the
already-resolved split wallet for that token's royalty assignment.

Required launch Core behavior:

```text
royaltyInfo(tokenId, salePrice)
  -> resolve token collection without requiring token mint status
  -> staticcall resolver for ROYALTY_ERC2981 assignment
  -> return splitWallet and salePrice * royaltyBps / 10_000
```

Core-native ERC-2981 is mandatory for launch. If the size budget does not pass,
the implementation should refactor non-essential Core logic into satellites,
compress internal helpers, or change the pre-launch deployment shape until the
minimal resolver-backed `royaltyInfo()` fits. A marketplace registry override
is not an acceptable launch substitute because support is uneven and it weakens
the contract-native royalty surface.

Launch Core must not inherit OpenZeppelin `ERC2981` or retain equivalent
default/token royalty storage. Core implements `IERC2981` directly and advertises
the ERC-2981 interface ID through custom `supportsInterface`. This avoids two
royalty sources of truth and keeps the bytecode budget focused on the resolver
path.

Resolver-backed Core integration must use a small, fixed read path:

```solidity
interface IStreamRevenueResolver {
    function royaltyInfoForToken(
        address core,
        uint256 tokenId,
        uint256 salePrice,
        uint256 mappedCollectionId,
        bool hasMappedCollection
    ) external view returns (address receiver, uint256 royaltyAmount);
}
```

This is the canonical resolver ABI for Core-native ERC-2981. It has no overload
in v1. Core and resolver implementations must use the exact selector:

```solidity
bytes4 constant ROYALTY_INFO_FOR_TOKEN_SELECTOR = 0x3d5d0e9e;
// royaltyInfoForToken(address,uint256,uint256,uint256,bool)
```

Core calls the resolver with
`IStreamRevenueResolver.royaltyInfoForToken.selector`. `mappedCollectionId` and
`hasMappedCollection` come from Core's authoritative token mapping, not from
token ID ranges. Core reads `tokenCollectionMappingExists[tokenId]` before the
staticcall; when it is true, Core passes
`mappedCollectionId = tokenCollectionId[tokenId]` and
`hasMappedCollection = true`; when it is false, Core passes
`mappedCollectionId = 0` and `hasMappedCollection = false`. For minted,
same-transaction allocated, custody-held, or burned tokens with retained
mapping, `hasMappedCollection = true`. For premint or nonexistent tokens
without an authoritative Core mapping, `hasMappedCollection = false` and
`mappedCollectionId = 0`; the resolver falls back to default assignment or
zero. The resolver must not call Core, re-read token mapping, or infer a
collection from token ID arithmetic.
The resolver is bound to exactly one Core address at deployment and must revert
or return `(address(0), 0)` if the `core` argument differs from that bound Core.
Resolver pointer replacement must preserve frozen economic state, mint-time
royalty snapshots, inherited/global freezes, and `maxRoyaltyBps` continuity as
specified in `docs/revenue-splits-and-royalties.md`; otherwise the change is an
economics-affecting recovery, not an ordinary pointer replacement.
For external diagnostics and satellite reads, the canonical Core read is
`tokenCollectionIdentity(tokenId) -> (mappingExists, collectionId,
collectionSerial, burned)`, with burned tokens returning their retained mapping
and `burned = true`.

```text
royaltyResolverGasLimit = immutable deploy-time value, e.g. 50_000
ROYALTY_RETURN_GAS_BUFFER = 15_000

if gasleft() <= royaltyResolverGasLimit + ROYALTY_RETURN_GAS_BUFFER:
    return (address(0), 0)

hasMappedCollection = tokenCollectionMappingExists[tokenId]
mappedCollectionId = hasMappedCollection ? tokenCollectionId[tokenId] : 0

(ok, data) = resolver.staticcall{gas: royaltyResolverGasLimit}(...)
if !ok or data.length != 64:
    return (address(0), 0)
decode(receiver, amount)
if receiver == address(0) or amount == 0:
    return (address(0), 0)
if amount > salePrice:
    return (address(0), 0)
return (receiver, amount)
```

`royaltyResolverGasLimit` should be immutable at Core deployment. A later Core
deployment may choose a new immutable gas limit for a new resolver
implementation, but there should be no runtime setter that changes marketplace
read behavior after deployment.
The parent gas precheck must account for EIP-150's 63/64 gas forwarding rule so
a caller cannot pass the precheck while the resolver receives less than
`royaltyResolverGasLimit`. CI must test calls just below, at, and above the
precheck threshold and prove ordinary all-cold resolver reads do not
fallback-to-zero because of under-forwarded gas.

The Solidity implementation must not allocate unbounded returndata before
checking its size. Launch Core must use an assembly staticcall pattern that caps
`returndatacopy` to 64 bytes, requires `returndatasize() == 64`, and returns
`(address(0), 0)` for malformed, oversized, or undersized returndata. The
resolver must use checked arithmetic or `mulDiv`-style math for
`salePrice * royaltyBps / 10_000` and must not rely on overflow reverts for
ordinary control flow.

The resolver read itself must be O(1): token mapping lookup, collection mapping
lookup, default lookup, and bps multiplication. Wallet/profile/code-hash checks
belong at assignment time, not in Core's marketplace read path.

Resolver `royaltyInfoForToken` must not make external calls, deploy wallets,
call ERC-20 contracts, or depend on receiver behavior. It is storage reads and
arithmetic only. A resolver that performs external calls in this path is an
incident and must not be activated as the production pointer.
Static analysis must fail launch if `royaltyInfoForToken` or any internal
function reachable only from that path contains `CALL`, `DELEGATECALL`,
`STATICCALL`, `CREATE`, or `CREATE2` opcodes. The Core staticcall gas cap is
defense in depth, not the primary proof that the deployed resolver is pure.

Worst-case cold-access gas must be measured before deployment. Target launch
shape with packed storage keeps the deepest cold resolver path below 35,000 gas
inside a 50,000 gas cap, and the parent Core path within the published buffer:

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

Core's token-to-collection mapping reads happen before the staticcall and must
be included in parent-call gas tests. If all-cold default fallback exceeds the
published target on the launch compiler/EVM, the implementation must compress
storage, raise the immutable cap before deployment, or reduce resolver work. It
must not launch with ordinary cold reads falling back to zero.

Royalty resolution rules:

- `royaltyInfo()` must not call `_requireMinted` or equivalent minted-only
  checks. Marketplaces and indexers may ask about premint or nonexistent token
  IDs. In the v1 resolver-backed design, collection-scope royalty resolution
  requires Core to pass `hasMappedCollection = true` and the stored
  `tokenCollectionId[tokenId]`. Tokens without
  `tokenCollectionMappingExists[tokenId] == true` always fall back to the
  contract default royalty assignment or zero. Core must not attempt collection
  derivation for unmapped token IDs unless a later ADR defines a deterministic
  token ID codec and storage-free collection existence gate.
- The token-to-collection mapping used for royalty resolution is written only
  when Core has an authoritative token assignment, such as mint,
  same-transaction allocation, or a custody-held token path. Burned tokens
  retain their last stored mapping for royalty disclosure history, with
  `tokenCollectionMappingExists[tokenId]` remaining true after burn.
  `royaltyInfo()` therefore still resolves token, collection, then default
  scope for burned tokens, while `tokenURI()` may revert under normal ERC-721
  metadata semantics. Launch v1 does not define standalone premint
  reservations; premint or nonexistent tokens without the Core mapping are
  unmapped for royalty resolution.
- A missing token assignment falls back to collection, then default.
- A missing collection assignment falls back to default.
- A missing default royalty assignment returns `(address(0), 0)`. There is no
  Core-local fixed receiver fallback in the launch architecture.
- A successor-Core declaration does not automatically change old-Core
  `royaltyInfo()` behavior. The old Core continues to answer through its
  configured resolver until governance explicitly freezes, deprecates, repoints,
  or zeroes that disclosure surface under normal pointer rules.
- `royaltyBps = 0` returns `(address(0), 0)`.
- `royaltyBps = 0` is allowed only when governance explicitly wants no royalty
  for the scope.
- Resolver-backed `royaltyInfo()` must not revert merely because the external
  resolver is unavailable, consumes its explicit staticcall gas limit, returns
  malformed data, or returns a zero receiver or zero amount. The safe fallback is
  `(address(0), 0)`. This avoids breaking marketplace sale paths and avoids
  silently paying the wrong receiver.
- `royaltyInfo()` must be total over every `uint256 salePrice`, including
  `type(uint256).max`. Resolver arithmetic must use full-precision `mulDiv` or
  an equivalent overflow-safe computation that cannot fail for
  `royaltyBps <= 10_000`. Returning `(address(0), 0)` for arithmetic failure is
  not conformant; fallback-to-zero is reserved for resolver unavailability,
  malformed return data, zero receiver, zero amount, or explicit no-royalty
  configuration.
- If the resolver returns `royaltyAmount > salePrice`, Core returns
  `(address(0), 0)` and diagnostics report
  `ROYALTY_AMOUNT_EXCEEDS_SALE_PRICE`.
- Monitoring must treat resolver fallback-to-zero as an incident because it can
  suppress royalty display or payment.
- `royaltyInfo()` is `view` and cannot emit a fallback event. Monitoring should
  detect fallback-to-zero through off-chain calls, indexer comparisons, and a
  required non-view diagnostic probe outside Core.
- Marketplaces may cache receiver or bps results, may only honor contract-level
  defaults, or may ignore token-varying receivers. Per-token or per-collection
  receiver changes are therefore best-effort disclosures, and retained
  marketplace evidence is required before public claims.
- Royalty payment remains voluntary unless a separate enforcement ADR is
  accepted.

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

`probeRoyaltyInfo` is hosted by the approved revenue diagnostics satellite or
by the resolver if that resolver line includes diagnostics. It is not a Core
function.

The probe is not a marketplace surface. It exists so operators can emit,
monitor, and archive evidence for resolver readiness, fallback-to-zero
incidents, gas behavior, and assignment hashes before and after launch.

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

## Governance

Revenue policy changes should be governed through ADR 0004 governance/action
roles with equivalent event and role clarity. Legacy selector-map
`StreamAdmins` authorization is nonconformant for launch.

Required roles:

| Role | Authority |
| --- | --- |
| Revenue config admin | Set or clear unfrozen assignments. |
| Revenue freeze admin | Freeze default, collection, token, or global revenue config. |
| Label metadata admin | Publish optional label metadata. |
| Emergency admin | Execute only documented surplus actions in contracts that can truly hold surplus. |
| Asset policy admin | Approve/deprecate ERC-20 assets and mark unsupported assets. |
| Wallet code admin | Approve or deprecate split wallet runtime code hashes. |

Recommended controls:

- Production roles should be Safes or equivalent multisigs.
- Default-scope assignments, default-scope royalty changes, global freezes, and
  resolver-cap replacement actions must use timelock or two-step staging.
- Resolver cap replacement runbook: deploy a new resolver with the new immutable
  cap, register and approve its module identity/code hash/manifest hash, stage
  the Core resolver pointer update, replay or intentionally remap default and
  collection assignments, run `probeRoyaltyInfo` against representative default,
  collection, token, premint, burned, and malformed cases, emit a
  manifest-backed reason, execute after the delay, monitor fallback-to-zero
  diagnostics, and optionally freeze or long-timelock the new pointer after
  launch confidence. Cap changes must not mutate old resolver state in place.
- Collection and token assignment changes should use timelock or two-step
  staging when economically material.
- Freeze operations are an economic product promise. A global freeze should be
  terminal and used only when that irreversibility is advertised. Non-global
  freezes may use a timelocked unfreeze path only if the product explicitly
  advertises mutable economics and the event history makes the change obvious.
- Admin actions should include reason URIs or content hashes when practical.

Wallet runtime code-hash approvals, deprecations, and incident revocations must
emit events. Deprecation is forward-looking: it prevents new assignments from
using the hash but does not invalidate already credited escrow or already
deployed split wallets. Incident revocation is stronger, blocks normal future
escrow flush for that runtime hash, and must come with a recovery or
successor-wallet reroute plan for affected owed funds.

Runtime code-hash behavior is:

- `ACTIVE`: new assignments and new escrow credits may use the hash.
- `DEPRECATED`: new assignments and credits may not use the hash, but existing
  wallets and escrow credits created while active remain releasable/flushable.
- `INCIDENT_REVOKED`: new use and normal escrow flush are blocked until an
  accepted recovery path exists.

## Events

The event catalog must support full historical reconstruction.

Required event families:

- split profile created;
- split profile entries emitted in canonical index order;
- split wallet deployed or discovered;
- primary template materialized;
- label metadata set;
- revenue assignment set;
- revenue assignment cleared;
- revenue assignment frozen;
- primary revenue deposited;
- escrow credit created;
- escrow flushed;
- royalty revenue received or observed when detectable;
- asset observed or synced;
- asset approved, approval deprecated, observation initialized, or marked
  unsupported;
- wallet runtime code hash approved, deprecated, or incident-revoked;
- global freeze set;
- native release;
- ERC-20 release;
- emergency surplus withdrawal, if any contract can hold surplus.

Profile creation events should be ordered as `SplitProfileCreated`, then one
`SplitProfileEntry` per canonical entry with an explicit `uint16 index`, then
`SplitWalletDeployed` if deployment occurs in the same transaction. Indexers
must be able to reconstruct `entriesHash` from event data and compare it to the
created profile.

`SplitWalletDeployed` and any later discovery event must be idempotent by
`(profileId, wallet, factory, walletVersion, initCodeHash, runtimeCodeHash)`.
Primary revenue and escrow events must include enough data to prove that each
sale amount is either in a split wallet or owed by escrow:

- `PrimaryRevenueDeposited(revenueClass, profileId, wallet, asset, amount,
  collectionId, tokenId, saleKind, saleId, payer, poster, beneficiary,
  isTemplate, escrowed)`;
- `PrimaryTemplateMaterialized(templateId, profileId, wallet, revenueClass,
  scope, scopeId, saleContextHash)`;
- `EscrowCreditCreated(revenueClass, profileId, wallet, asset, amount,
  totalOwed, escrowRuntimeCodeHash)`;
- `EscrowFlushed(revenueClass, profileId, wallet, asset, amount,
  remainingOwed)`;
  Failed v1 flushes revert, so there is no normative `EscrowFlushFailed` event.

Events should include the following query fields where relevant, but Solidity
permits at most three indexed fields per event. The companion spec declares the
normative v1 indexed fields; other query fields must still be present as
unindexed event data where needed. Changing an indexed field after launch is an
indexer-breaking schema change and requires a new event name or a new accepted
ADR.

- profile ID;
- wallet;
- revenue class;
- scope and scope ID;
- collection ID;
- token ID;
- account;
- label ID;
- asset;
- amount.

The intended escrow query path is: index by `revenueClass`, `profileId`, and
`wallet` on escrow credit/flush events, then read `asset`, amount, and remaining
owed balance from unindexed event data. Indexers that need asset-first lookup
must maintain their own secondary index from the full event stream.

`saleKind` is a `bytes32` discriminator such as `keccak256("FIXED_PRICE")` or
`keccak256("AUCTION")`. `saleId` is the drop ID for fixed-price drops. For
auctions, `saleId` may be the token ID only if a token can have at most one
primary auction in that sale contract; otherwise it must include or point to an
auction nonce.

## Pre-Launch Implementation Plan

### Phase 0: Specification And Evidence

- Add this ADR and the companion spec.
- Gather external review and audit feedback.
- Treat Core-native resolver-backed ERC-2981 as a launch requirement.

### Phase 1: Split Wallet Factory

- Implement immutable split wallets and deterministic factory deployment.
- Add native and ERC-20 release tests.
- Add profile hashing, label ID, dust, duplicate-entry, canonical encoding,
  canonical sorting, verified-wallet, and maximum-entry tests.

### Phase 2: Primary-Sale Adapter

- Add resolver-backed primary settlement while preserving ADR 0003 pull-payment
  invariants.
- Model poster-like proceeds through a primary split template because poster is
  a dynamic settlement-context account rather than a fixed profile recipient.
- Add default, collection, token, fixed-profile, and template assignment tests.

### Phase 3: Royalty Resolver

- Implement royalty assignments and split-wallet receiver resolution.
- Add tests for default, collection, token, zero royalty, invalid bps, frozen
  scopes, and marketplace-style passive receipts.

### Phase 4: Core-Native ERC-2981

- Add minimal resolver-backed `royaltyInfo()` to `StreamCore` before launch.
- Prove the Core size budget with measured bytecode output.
- If the size budget fails, refactor non-essential Core logic into satellites or
  reduce helper surface until Core-native ERC-2981 fits.
- Do not use a marketplace registry override as the launch substitute.

### Phase 5: Marketplace And Indexer Evidence

- Retain evidence for OpenSea, Reservoir, Manifold, Blur, and other relevant
  display/indexer paths before public claims.
- Keep wording conservative: ERC-2981 disclosure is not enforcement.

## Security Considerations

- Split wallets must be reentrancy-safe on release.
- Deposits must not execute recipient code.
- Profile creation must reject zero accounts, zero shares, invalid sums, and
  excessive entry counts.
- Profile creation must construct deduplicated aggregate shares from entries and
  reject any mismatch between entry sums and aggregate sums.
- Release functions must handle ERC-20 return-value variance safely.
- Fee-on-transfer tokens should either be explicitly unsupported or documented
  as balance-observed assets with no promise of exact sent amount.
- Rebasing tokens should be treated as unsupported unless a later spec accepts
  their accounting complexity.
- The v1 ERC-20 correctness guarantee applies only to approved standard
  monotonic-balance tokens whose wallet balance cannot decrease except through
  wallet-initiated releases.
- The balance-decrease guard is best-effort for non-standard assets. A
  rebasing-down token can skew early entitlements before detection; that risk is
  accepted only for assets outside the approved standard monotonic class.
- `selfdestruct` or forced ETH must not create emergency-withdrawable surplus
  in split wallets.
- Forced ETH sent to a counterfactual wallet before deployment belongs to the
  immutable profile that later owns that deterministic address.
- Incident-revoking a wallet runtime code hash can freeze owed escrow for that
  hash until the timelocked successor-wallet recovery path is executed.
- Resolver calls from Core must fail closed or fallback according to documented
  behavior; they must not break ERC-721 ownership or transfers.
- Resolver griefing tests must cover out-of-gas, malformed return data, excess
  return data, and low-parent-gas calls.
- Labels must not be used as permissions.
- Off-chain metadata URIs must not be required for payment correctness.

## Test Plan

Add tests for:

- deterministic profile ID and wallet address derivation;
- arbitrary label IDs;
- append-only label metadata and supersession without reinterpretation;
- same account under multiple labels;
- same account under three labels with aggregate release capped at the account
  aggregate share;
- duplicate `(account, labelId)` rejection;
- split denominator sum validation;
- maximum entry count enforcement;
- deduplicated account maximum enforcement;
- native ETH passive receipt and release;
- ERC-20 balance-observed release;
- ERC-20 asset sync event and explicit asset lookup;
- unknown ERC-20 balances first observed after approval become a starting
  cumulative balance and do not promise pre-observation attribution;
- unsupported ERC-20 balance decrease reverts rather than underflowing or
  reducing entitlements;
- unsupported asset marking is per-asset, blocks no other asset, and enables no
  sweep;
- first `syncAsset` initializes observation state even at zero balance;
- release-to alternate recipient;
- alternate-recipient release requires entitled-account caller or valid
  EIP-712/ERC-1271 authorization with nonce and deadline;
- failed native release preserves releasable accounting;
- reentrant release cannot drain more than releasable balance;
- rounding dust remains bounded, non-negative, and non-withdrawable;
- default, collection, and token primary assignment resolution;
- primary split template materialization with dynamic poster source;
- deterministic template ID, canonical template entries, source limits, and
  materialized metadata hash;
- materialized profile identity excludes sale-specific context, while
  `saleContextHash` uses the documented event-only preimage;
- `saleContextHash` is not used as on-chain payment authority;
- different templates with identical concrete recipient sets may produce
  different wallets when `templateId` changes materialized metadata; recipients
  can claim from both and conservation holds per wallet;
- `PrimaryTemplateMaterialized` event reconstruction;
- unsupported primary template account source rejection before state changes;
- template materialization gas independent of resolved account values;
- zero dynamic account and dynamic/static `(account, labelId)` collisions are
  handled by pre-state-change rejection or deterministic aggregation;
- default, collection, and token royalty assignment resolution;
- assignment resolution and inherited-freeze counters use Core's authoritative
  token-to-collection mapping, not token ID ranges;
- assignment set, clear, and freeze events;
- frozen assignment mutation rejection;
- global freeze blocks default, collection, and token assignment mutations for
  its revenue class;
- Core `royaltyInfo()` receiver and amount for each scope;
- zero royalty scope;
- royalty policy mode is configured and frozen before public mint when
  collection economics are promised immutable;
- Core royalty resolver gas limit is deploy-time immutable and fallback
  behavior is deterministic just below and above that limit;
- exact resolver selector and ABI are used by Core;
- `probeRoyaltyInfo` reports resolver health, assignment hash, and failure
  reason for operational monitoring;
- resolver unavailable, out-of-gas, malformed, excess-return-data, zero return,
  and low-parent-gas fallback to `(address(0), 0)`;
- resolver external-call attempts, all-gas consumption, too-little data,
  too-much data, zero receiver, zero amount, and incident-revoked pointer never
  make Core `royaltyInfo()` revert;
- all-cold deepest-scope resolver gas measured against the immutable cap with
  documented margin;
- static analysis proves the production resolver royalty path contains no
  external-call or creation opcodes;
- malicious resolver returning huge returndata cannot make Core OOG;
- resolver royalty math returns the exact
  `floor(salePrice * royaltyBps / 10_000)` for every `uint256 salePrice` and
  allowed bps using full-precision arithmetic; arithmetic overflow, safe caps,
  reverts, or fallback-to-zero are not conformant;
- `royaltyInfo()` for nonexistent and premint token IDs never reverts and never
  returns a collection wallet from a heuristic range guess;
- collection-scope royalty requires
  `tokenCollectionMappingExists[tokenId] == true`;
- passive marketplace-style royalty receipt by split wallet;
- direct and forced ETH behavior;
- forced ETH to a counterfactual split wallet before deployment;
- release-to alternate recipient debiting the entitled account;
- official split wallet factory/profile/codehash binding at assignment time;
- primary sale direct-deposit failure falls back to revenue escrow and does not
  revert minting or auction settlement;
- wrong code at the deterministic split wallet address reverts before sale
  effects and is not credited to normal escrow;
- pre-seeded wrong-code deterministic wallet address preserves escrow credit,
  emits/reverts with a distinct poisoned-address reason, and can be recovered
  only through timelocked successor-wallet reroute;
- missing or malformed primary assignment reverts before minting or auction
  state changes;
- signed primary sale authorizations bind `revenueClass` and
  `expectedPrimaryPolicyHash`, or explicitly choose current-policy drift;
- signed primary sale authorizations bind payer, initial-recipients hash,
  beneficiaries hash, executor, quantity, price, nonce, deadline, collection,
  and sale program;
- static analysis rejects `tx.origin` in production mint, sale, drop, auction,
  or authorization paths;
- auction settlement records revenue and final settlement state before external
  NFT recipient callbacks;
- fixed-price token-level primary overrides only when token ID is known before
  external callbacks;
- token-level primary policy expected by signed authorization reverts if the
  token ID is not authoritatively allocated by Core before settlement;
- open-ended collection primary settlement succeeds without configured final
  collection supply;
- token-level royalty snapshots, when used, preserve mint-time economics after a
  later collection assignment change;
- open-ended collection tokens without token-level royalty snapshots follow the
  current collection assignment at `royaltyInfo()` time;
- auction `saleId` is unique per primary auction or includes an auction nonce;
- v1 primary settlement excludes ERC-20 payments until an adapter is accepted;
- escrow-to-wallet flush is permissionless, idempotent, cannot double-credit,
  and cannot make owed funds emergency-withdrawable;
- escrow flush tests include reverting deployment/deposit harnesses and prove
  owed credit restoration; low gas below `FLUSH_GAS_FLOOR` rejects before
  zeroing;
- escrow against an undeployed official wallet, then permissionless
  `deployWallet(profileId)`, then successful flush;
- deprecated runtime code hash still allows escrow flush for credits created
  while the hash was active;
- incident-revoked escrow can reroute only escrow-held owed funds through the
  timelocked successor-wallet recovery operation;
- wallet-observed conservation excludes escrow-owed balances while system
  conservation includes them;
- escrow keys and events include `revenueClass`;
- inherited-freeze descendant counters or dirty bits enforce preconditions
  without enumeration;
- asset approval, deprecation, unsupported marking, and observation
  initialization events;
- `syncAsset` ordering: initialize, revert on observed decrease, skip
  unchanged, update on increase;
- deprecated assets remain syncable and releasable, while unsupported assets do
  not;
- ERC-20 asset policy is deployment-wide through the factory-bound asset policy
  registry; registry failure blocks only non-native assets;
- ERC-20 activation records evidence for standard monotonic-balance behavior;
- release-before-explicit-sync computes from cumulative balance and updates
  `lastObservedReceived` only after transfer/delta checks;
- receipts smaller than the unique account count produce bounded rounding dust
  and no over-release after later receipts;
- external-ground-truth conservation invariant: a test harness independently
  counts official deposits, direct transfers, and forced ETH, then asserts
  `sum(released) + sum(releasable) <= externalReceived`,
  `externalReceived - sum(released) - sum(releasable) == roundingDust`, and
  steady-state `roundingDust < uniqueAccounts` for approved standard assets;
- cross-receipt dust does not accumulate because entitlements are recomputed
  from cumulative observed receipts;
- monotonicity invariant: `observedReceived` never decreases after first
  observation for supported assets;
- fee-on-transfer or rebasing token rejection or no-overrelease invariant;
- emergency surplus boundaries;
- gas envelope for maximum entry count.

## Alternatives Considered

### Keep Three Hardcoded Buckets

Rejected for the long-term target. It is simple and already works, but it
cannot represent unknown future roles without repeated contract changes.

### Store Human-Readable Labels In Every Split Entry

Rejected as the default. Strings are useful for UI, but accounting should use
stable IDs. Human-readable text can live in events, a label registry, or
off-chain metadata.

### Mutable Split Profiles

Rejected. Mutable profiles make historical accounting harder. Create a new
profile and update the assignment instead.

### One Global Royalty Receiver For All Tokens

Accepted only as the current simple release behavior. It cannot support
collection or token-specific royalty splits unless every token shares one
royalty policy.

### Royalty Enforcement By Transfer Restriction

Rejected for this ADR. It is a separate product and governance decision with
major composability tradeoffs.

## Accepted Risks

- Pull-based split wallets require recipients to claim.
- Passive royalty receipts can create tiny bounded rounding dust that remains
  in the wallet under v1 accounting.
- Pre-deployment forced ETH is attributed to the immutable profile eventually
  deployed at that deterministic wallet address.
- Unsupported rebasing-down ERC-20 behavior can skew entitlements before the
  balance-decrease guard detects it; approved assets must exclude that class.
- Incident revocation of a split wallet runtime hash can strand owed escrow
  pending the timelocked successor-wallet recovery operation.
- Marketplace royalty behavior remains external and uneven.
- Satellite contracts add deployment and integration complexity.
- Resolver-backed Core royalties spend bytecode and require pre-launch size
  budget proof. If the budget fails, non-essential Core logic must be refactored
  out until Core-native ERC-2981 fits.
