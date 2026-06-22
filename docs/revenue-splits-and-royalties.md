# Revenue Splits And Royalties

This document is a pre-launch target specification for 6529Stream revenue
splits and royalties. 6529Stream has not launched, so this architecture should
be implemented as the initial production revenue and royalty system rather than
as a later retrofit layer.

The proposed architecture is captured as ADR
`docs/adr/0008-revenue-splits-and-royalty-resolver.md`.

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
initialization attempt.

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
balance. ERC-20 releases must also prove exact wallet balance deltas: the wallet
balance must decrease by exactly the released amount. Recipient balance-delta
checks belong in asset-specific adapters when reliable; they are not a generic
ERC-20 requirement. No-op transfers, fee-on-transfer behavior, rebases,
callbacks, and other non-standard behavior are unsupported unless a later
adapter accepts them.

ERC-20 assets are default-deny. An asset admin can approve a standard ERC-20,
deprecate approval for future receipts, or mark an observed asset unsupported.
Asset state is explicit:

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
   deterministic reservation reference.

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

The v1 primary adapter is native ETH only. ERC-20 primary sales require a later
asset-specific primary adapter with exact token-transfer accounting and escrow
flush rules. Split wallets can still release approved standard ERC-20 assets
received passively or through later adapters.

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

Templates do not have split wallet addresses. `walletFor(profileId)` applies to
fixed profiles only. A template must first materialize into a concrete
`profileId`; callers must not conflate `templateId` with the materialized
profile identity.

Primary settlement must preserve the current pull-payment invariant that
recipient behavior cannot block minting or auction settlement. The deterministic
funding path is:

1. Resolve the assignment. Token-level fixed-price primary overrides are
   available only when the token ID can be reserved or predicted before any
   external callback; otherwise fixed-price primary resolution is
   collection/default for that transaction. A missing or malformed primary
   assignment reverts before minting or other external effects.
2. If the assignment is a template, materialize a fixed split profile from sale
   context such as the actual poster account.
3. Reserve or mint the token without invoking an external recipient callback
   before revenue is recorded. If safe minting to a contract recipient is
   required, mint to custody or record revenue first.
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

Escrowed revenue must have a permissionless retry path:

```text
flushEscrow(revenueClass, profileId, wallet, asset)
  -> verify wallet == factory.walletFor(profileId)
  -> deploy wallet through factory.deployWallet(profileId) if absent
  -> verify wallet code hash matches the escrow runtime code hash or is active
  -> decrement owed credit
  -> transfer owed balance to wallet
  -> emit flushed amount and remaining owed balance
```

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

`flushEscrow` is the reverting path in v1. If deployment, code-hash validation,
or transfer fails, the transaction reverts and the owed balance remains in
escrow by EVM revert semantics. The escrow should not duplicate split-recipient
withdrawal logic; its job is to forward owed primary revenue to the verified
split wallet.
The wallet argument is the wallet captured when the escrow credit was created;
later assignment repointing does not move existing escrow credits. Escrow keys
include `revenueClass` for attribution. `flushEscrow` must be non-reentrant and
use checks-effects-interactions so reentrant or racing flush attempts cannot
double-transfer.
In v1, escrow credits use `asset = address(0)` only. Non-native escrow assets
revert until an ERC-20 primary adapter ADR is accepted.
Escrow credits may only be created for a deployed correct wallet or for an
undeployed deterministic wallet whose profile was created through the factory,
whose predicted address has no code, and whose expected runtime code hash is
active at credit time. This keeps the captured wallet flushable even after
later assignment repoints. Escrow credits store `escrowRuntimeCodeHash`, the
runtime code hash accepted at credit time. For an undeployed deterministic
wallet, this is the expected runtime code hash from the profile's wallet
version; for a deployed wallet, it is the observed code hash. Deprecating a code
hash later does not block flushing credits created while that hash was active.
Only an explicit incident revocation can block normal flush for an escrow
runtime code hash, and that revocation must come with a recovery plan for the
owed funds. In v1, incident revocation is a fund-freeze state, not an automatic
reroute: recovery requires a later accepted escrow recovery or successor-wallet
reroute path, or explicit re-enablement of the hash after the incident is
resolved.

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

If a resolver-backed Core cannot reach the resolver, receives malformed return
data, or receives a zero receiver or zero amount, it should return
`(address(0), 0)` rather than revert. Wallet/code-hash validity is enforced at
assignment time by the resolver; Core's read path validates only cheap return
shape and zero-value conditions. Monitoring should treat fallback-to-zero as an
incident.
Because `royaltyInfo()` is `view`, it cannot emit fallback events. Monitoring
must use off-chain calls, indexer comparisons, or an optional non-view
diagnostic probe in a satellite contract.

A resolver-backed Core path must use explicit gas and return-shape limits:

```text
ROYALTY_RESOLVER_GAS_LIMIT = 50_000
ROYALTY_RETURN_GAS_BUFFER = 15_000
resolver.staticcall{gas: ROYALTY_RESOLVER_GAS_LIMIT}
expected return length = 64 bytes
failure fallback = (address(0), 0)
```

`ROYALTY_RESOLVER_GAS_LIMIT` should be a deploy-time immutable for a Core
release, not mutable governance state. A new Core deployment may choose a new
immutable gas limit for a new resolver implementation, but there should be no
runtime setter that changes marketplace read behavior after deployment.

The resolver read must be O(1). Wallet deployment, `walletFor(profileId)`,
`wallet.profileId()`, and runtime-code-hash checks happen when assignments are
set, not during every marketplace `royaltyInfo()` call.

Core should use capped assembly returndata handling, not a high-level
`bytes memory` decode that can allocate unbounded returndata. The call copies at
most 64 bytes, requires `returndatasize() == 64`, and returns `(address(0), 0)`
for malformed size. The resolver uses checked arithmetic or `mulDiv`-style math
for `salePrice * royaltyBps / 10_000` and does not rely on overflow reverts for
normal fallback behavior.

`royaltyInfo()` must not require the token to be minted. In the v1
resolver-backed design, token IDs without a stored token-to-collection mapping
always fall back to the default assignment or zero. Collection-scope royalty
resolution requires a stored token-to-collection mapping plus an explicit
existence bit or equivalent non-reverting existence check. Core must not infer a
collection receiver for unmapped tokens unless a later ADR defines an exact
token ID codec and storage-free collection existence gate.
The mapping used by `royaltyInfo()` is written only when Core has an
authoritative token assignment, such as mint or explicit reservation. Burned
tokens retain their last stored mapping for royalty disclosure history. Premint
reservations count only if they write the same stored mapping and existence bit.

This is still disclosure. Unless a future enforcement ADR changes the product
posture, marketplaces can ignore the royalty.

Marketplaces may cache receiver or bps results, may ignore token-varying
receivers, or may only honor a default receiver. The launch contract still must
expose Core-native ERC-2981 because it is the most broadly portable royalty
disclosure surface.
There is no Core-local fixed receiver fallback in the launch architecture. If
the resolver returns zero, malformed data, or no configured default assignment,
`royaltyInfo()` returns `(address(0), 0)`.

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

For open-ended collections, collection scope remains valid even when max supply
is unknown. The resolver never needs final supply to resolve an assignment.
Collection-level assignments apply to future tokens until changed or frozen.
Token-level assignments are used when a specific token needs a different or
snapshotted policy.

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
blocks lower-scope set and clear operations under the frozen ancestor. Applying
an `INHERITED` freeze requires no configured lower-scope overrides under that
ancestor, unless the same governance action explicitly freezes those descendants
too.
The resolver must maintain O(1) descendant override counters or dirty bits per
`(revenueClass, scope, scopeId)` so inherited-freeze checks do not require
enumerating token-level assignments. Counter updates are part of set and clear:
setting a collection override increments the default ancestor counter; setting a
token override increments its collection ancestor when known and the default
ancestor; clearing decrements the same ancestors. Applying an inherited freeze
with existing lower overrides either reverts or atomically freezes all lower
configured descendants in the same governance action and leaves the ancestor's
mutable descendant count at zero.

A global freeze is implicitly `freezeMode = INHERITED` across every default,
collection, and token scope for the affected revenue class. It blocks set,
clear, and unfreeze operations for existing assignments in that revenue class.
Whether it also blocks creation of entirely new revenue classes must be an
explicit release decision; a deployment-wide global freeze should block both.

## Events

The future event surface should be indexer-first. At minimum:

```solidity
event SplitProfileCreated(
    bytes32 indexed profileId,
    address indexed wallet,
    bytes32 entriesHash,
    bytes32 metadataURIHash,
    uint16 schemaVersion,
    uint16 walletVersion,
    string metadataURI
);

event SplitProfileEntry(
    bytes32 indexed profileId,
    address indexed account,
    bytes32 indexed labelId,
    uint16 index,
    uint32 sharePpm
);

event SplitWalletDeployed(
    bytes32 indexed profileId,
    address indexed wallet,
    address indexed factory,
    uint16 walletVersion,
    bytes32 initCodeHash,
    bytes32 runtimeCodeHash
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
    bool escrowed
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
- Royalty bps cap.
- Immutable `maxRoyaltyBps`, recommended at 1000 for new resolver deployments
  unless a future accepted ADR chooses otherwise. Raising or lowering the cap
  later requires a new resolver deployment and rollout plan.
- Assignment-time wallet deployment, factory, profile ID, and code-hash
  validation.
- Direct view for `primaryRevenueWallet(collectionId, tokenId, revenueClass)`.
- Direct view for `royaltyInfo(tokenId, salePrice)`.
- Stored token-to-collection existence bit or equivalent non-reverting existence
  check for collection-scope royalty resolution.

### StreamDrops And StreamAuctions

- Replace three-bucket local split policy with resolver-backed profiles only
  after the split wallet and resolver have dedicated tests.
- Preserve current pull-payment and owed/surplus behavior in the launch design.
- Assignments may point only to verified official split wallets or a
  protocol-owned revenue escrow with ADR 0003 owed/surplus guarantees.
- Use deterministic direct-deposit-then-escrow fallback so split wallet deposit
  failure cannot revert minting or auction settlement.
- Keep v1 primary settlement native ETH only unless a later ERC-20 primary
  adapter is accepted.
- Emit source revenue events only after funds are accepted by the split wallet
  or recorded as owed by the revenue escrow.

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
4. Wire fixed-price and auction primary settlement through resolver-backed fixed
   profiles or primary split templates.
5. Implement royalty assignments and split-wallet royalty receiver resolution.
6. Add minimal resolver-backed `royaltyInfo()` to `StreamCore` before launch.
7. Prove the Core size budget with measured bytecode output. If the size budget
   fails, refactor non-essential Core logic into satellites or compress helper
   code until Core-native ERC-2981 fits.
8. Retain marketplace/indexer evidence for Core-native ERC-2981 behavior and
   split-wallet receiver display.
9. Update docs, release artifacts, event catalogs, ABI checksums, and retained
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
  hash until a recovery or successor-wallet reroute spec is accepted.
- Marketplace royalty behavior remains external, uneven, and cache-prone.

## Validation Checklist

- Profile ID is deterministic.
- Profile ID binds factory, wallet version, init code hash, and runtime code
  hash.
- Profile entries are immutable.
- Labels are arbitrary.
- Duplicate `(account, labelId)` pairs are rejected.
- Same account with different labels is supported.
- Same account under multiple labels cannot release more than its aggregate
  share.
- Profile sum must equal `1_000_000`.
- Entry and unique-account maxima are enforced.
- Releasable math is monotonic.
- Unsupported balance-decreasing ERC-20 behavior reverts rather than
  underflowing or reducing entitlements.
- Failed release preserves claimable funds.
- Reentrant release cannot over-withdraw.
- Forced ETH cannot be swept as surplus.
- ERC-20 releases are tested.
- ERC-20 direct receipt can be observed with explicit asset sync.
- Fee-on-transfer and rebasing token behavior cannot over-release funds.
- Rounding dust is bounded, non-negative, and non-withdrawable in v1.
- Release-to alternate recipient debits the entitled account.
- Assignment resolution follows token, collection, default.
- Dynamic poster primary templates materialize the current poster into a fixed
  split profile at settlement.
- Template ID preimage, canonicalization, max entries, max account sources, and
  materialized metadata hash are deterministic.
- Materialized profile identity excludes sale-specific context; `saleContextHash`
  is event-only and uses a documented preimage.
- `saleContextHash` is not used as on-chain payment authority.
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
- Applying inherited freeze with existing lower overrides either reverts or
  freezes the descendants in the same governance action.
- Global freeze is inherited across all scopes for its revenue class.
- Royalty bps is capped.
- `royaltyInfo()` returns the resolved split wallet.
- Resolver failure, malformed data, excess data, out-of-gas, and low-parent-gas
  reads return `(address(0), 0)` and are monitorable.
- Core royalty resolver gas limit is deploy-time immutable and fallback
  behavior is deterministic just below and above that limit.
- Huge resolver returndata cannot make Core OOG.
- Royalty math overflow returns `(address(0), 0)` or a documented safe cap
  without reverting Core.
- `royaltyInfo()` for premint or nonexistent token IDs does not revert and does
  not return collection receivers from heuristic range guesses.
- `royaltyBps = 0` returns `(address(0), 0)`.
- Profile ID, factory salt, wallet address, and wallet code hash are bound.
- Primary-sale split wallet deposit failure falls back to owed escrow without
  reverting minting or auction settlement.
- Wrong code at the deterministic split wallet address reverts before sale
  effects and is not routed to normal escrow.
- Missing or malformed primary assignment reverts before minting or auction
  state changes.
- V1 primary settlement rejects or excludes ERC-20 payments until an adapter is
  accepted.
- Auction settlement records settlement state and revenue before external NFT
  recipient callbacks.
- Fixed-price token-level primary overrides are used only when token ID is known
  before external callbacks.
- Open-ended collection primary settlement succeeds without a configured final
  collection supply.
- If token-level royalty snapshots are used for an open-ended collection, a
  later collection royalty change does not affect those tokens.
- If token-level royalty snapshots are not used, open-ended collection tokens
  follow the current collection assignment at `royaltyInfo()` time.
- Auction `saleId` is unique per primary auction or includes an auction nonce.
- Escrow flush is permissionless, idempotent, cannot double-credit, and cannot
  make owed funds emergency-withdrawable.
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
- Release-before-explicit-sync computes from cumulative balance and updates
  `lastObservedReceived` only after transfer/delta checks.
- `syncAsset` on first zero balance initializes observation state.
- `syncAsset` ordering is initialize, revert on decrease, skip unchanged,
  update on increase.
- Collection-scope royalty resolution requires stored token mapping plus
  existence bit; unmapped tokens return default or zero.
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
