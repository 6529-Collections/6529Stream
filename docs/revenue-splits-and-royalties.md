# Revenue Splits And Royalties

Specification status: Draft. This document follows
[`docs/spec-policy.md`](spec-policy.md); the decisions formerly tracked
inline are resolved by
[ADR 0009](adr/0009-protocol-v1-open-question-resolutions.md),
[ADR 0010](adr/0010-world-class-spec-pass.md), and
[ADR 0011](adr/0011-world-class-pass-round-2.md) and recorded in
[`docs/spec-open-questions.md`](spec-open-questions.md).

This document is the normative revenue and royalty specification for
6529Stream. 6529Stream is permanent infrastructure for the 6529 network: the
first production deployment is the permanent system, and this architecture
is that system's revenue and royalty layer from genesis, not a retrofit.
Requirements are classified by permanence class — Permanent, Replaceable, or
Operational — as defined in `docs/spec-policy.md`.

Under the single-sourcing rule (ADR 0010 decision D3), this document is the
normative home for every revenue, royalty, settlement, and escrow
definition: split profile and template preimages, assignment and policy
hashes, `saleContextHash`, settlement keys, release and payment typehashes,
asset-policy semantics, escrow lifecycle, and the revenue event schemas.
Other documents — including ADR 0008 — cite these definitions and must not
restate them. Where an older document conflicts, this document wins and the
conflict is a defect to fix (ADR 0010 decision D3.2).

The architecture decision record is
`docs/adr/0008-revenue-splits-and-royalty-resolver.md`, Accepted, amended by
`docs/adr/0009-protocol-v1-open-question-resolutions.md` decisions 8 and 9,
by [ADR 0010](adr/0010-world-class-spec-pass.md) decisions D1, D2.5,
D5, D7.3, D8.2, D8.6, D9.2, and D10.6, and by
[ADR 0011](adr/0011-world-class-pass-round-2.md) decisions R6, R9, R10,
and R12.
The cross-cutting 50+ year architecture principles, including the Governed
Gas Parameter model, live in `docs/stream-long-term-architecture.md`. Sale
and auction mechanics live in `docs/stream-sales-and-auctions.md` (ADR 0010
decision D5). The artist identity, consent, and sanction model lives in
[`docs/stream-artist-authority.md`](stream-artist-authority.md) (ADR 0010 decision D2).

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
  - primary sale templates with COLLECTION_ARTIST and SALE_POSTER
    materialization
  - royalty profile and bps resolution

StreamPrimarySaleSettlement
  - authorized primary-sale settlement evidence
  - native ETH and approved-standard ERC-20 deposits
  - official revenue counters distinct from passive wallet receipts

StreamSplitFactory
  - deterministic split wallet deployment
  - profile hash and profile ID validation
  - immutable asset policy registry pin

StreamSplitWallet
  - immutable arbitrary split profile
  - native ETH and ERC-20 pull release
  - passive royalty receipt support

StreamAssetPolicyRegistry
  - deployment-wide approved ERC-20 asset status
  - policy evidence hashes and effective timestamps

StreamLabelRegistry
  - optional human-readable label metadata
  - no accounting authority

StreamClaimRouter
  - permissionless batched release-to-self across wallets
  - stateless, holds no funds, preserves pull semantics
```

Every external-call gas bound in this layer is a Governed Gas Parameter
(ADR 0010 decision D1): a governed storage value above an immutable floor,
never an immutable cap. See
[Governed Gas Parameters In The Revenue Layer](#governed-gas-parameters-in-the-revenue-layer).

The design uses immutable split profiles and mutable assignments. Profiles say
who gets paid. Assignments say which profile applies to a default, collection,
or token scope.

## Protocol v1 Scope

Protocol v1 scope is deliberately narrower than the long-term design surface:

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
9. Payer-signed EIP-712 `PaymentIntent` verification at the ERC-20
   settlement adapter boundary (ADR 0010 decision D8.2), with the
   payer-is-caller by-construction intent of [RSR-PAYMENT-INTENT].5
   (ADR 0011 decision R10).
10. A permissionless claim-aggregation periphery preserving pull semantics
    (ADR 0010 decision D10.6).

Excluded from protocol v1 — intentional absence, not deferral. Adding any of
these requires a separately accepted module or adapter spec that accepts the
added risk against the frozen interfaces, or a successor Core line where
Permanent surfaces are affected:

1. Fee-on-transfer, rebasing, callback, pausable-without-standard-reason, or
   other non-standard ERC-20 primary-sale adapters.
2. Merkle/accounting adapters for very large split distributions.
3. Ordinary dust sweeps or decommission withdrawals.
4. Royalty enforcement by transfer restriction. This exclusion is permanent
   for this Core line, not module-addressable: ERC-721 transfer is a
   Permanent Core surface with no transfer validator hook, so no module,
   adapter, or registry can ever add enforcement to this deployment. The
   only path to enforced royalties is a declared successor Core line
   (ADR 0010 decision D9.2); the transfer-openness preclusions and the
   successor-line enforcement path are owned by
   `docs/stream-long-term-architecture.md` [LTA-STANDARDS]. Disclosure-only
   ERC-2981 is a deliberate, permanent, artist-facing term of this protocol
   and must be presented as such wherever royalty expectations are set,
   under the artist-acknowledgment and marketplace royalty-resolution
   gates of [RSR-MARKETPLACE-ROYALTY] (ADR 0011 decision R12).
5. Marketplace registry override as the primary royalty path.
6. Post-mint refunds of officially settled primary revenue (see
   [Normative Paid Mint Orchestration](#normative-paid-mint-orchestration)).

## Implementation Status

This section is non-normative implementation evidence per
[`docs/spec-policy.md`](spec-policy.md); it records point-in-time as-built
state and does not weaken any requirement in this spec.

The v1 split and primary-settlement implementation adds `StreamSplitFactory`,
`StreamSplitWallet`, `StreamAssetPolicyRegistry`, `StreamRevenueResolver`, and
`StreamPrimarySaleSettlement` as outside-Core satellites. The implemented slice
supports fixed split profiles, dynamic primary-sale templates, native ETH
primary deposits, approved standard ERC-20 primary deposits, and native/ERC-20
pull release from split wallets:

- `StreamSplitFactory` validates and canonicalizes immutable split entries,
  computes the ADR 0008 profile ID with `abi.encode`, stores reconstructable
  profile metadata, and deploys or discovers deterministic wallets with
  `CREATE2`. It immutably pins the deployment-wide
  `StreamAssetPolicyRegistry` and includes that registry address in the
  `WALLET_VERSION = 2` profile ID preimage.
- `StreamSplitWallet` has factory-bound one-shot initialization, stores
  immutable entries and aggregate account shares, accepts passive native ETH
  and ERC-20 receipts, computes releasable funds from cumulative observed
  receipts, and releases native ETH or approved ERC-20 balances through pull
  payments.
- `StreamAssetPolicyRegistry` is default-deny, owned by the deployment admin
  safe after rehearsal, records asset status plus evidence hash, and gives
  wallets a fail-closed production surface for approved standard ERC-20s.
- `StreamRevenueResolver` records deterministic default, collection, and token
  scoped primary assignments. Assignments point to an already verified split
  profile or to a primary split template. Template materialization currently
  supports the `SALE_POSTER` dynamic source and creates deterministic fixed
  split profiles through the split factory. The current resolver implements
  exact-key assignment freezes only; inherited freezes, global freezes, and
  descendant override counters remain outstanding resolver work required by
  this spec before product-level permanent economics can be promised.
- `StreamPrimarySaleSettlement` accepts calls only from owner-authorized sale
  adapters, verifies the resolved primary policy hash under strict or
  allow-current policy mode, deposits exact native ETH or approved-standard
  ERC-20 value into the verified split wallet, records official primary
  settlement counters, and emits reconstruction events. ERC-20 settlement uses
  the factory-pinned asset policy registry, rejects inactive or malformed
  assets, and requires exact transfer deltas.
- The slice spends no `StreamCore` bytecode and does not wire into fixed-price
  drops, auctions, escrow, or ERC-2981.
- The implemented `StreamPrimarySaleSettlement` slice does not yet verify a
  payer-signed `PaymentIntent` or an EIP-712/ERC-1271 sale authorization at
  the adapter boundary; it trusts enabled settlement callers to supply the
  `expectedPrimaryPolicyHash` from the upstream authorization flow. That
  slice is not deployment-conformant against the payer-intent requirements
  of this spec until the `PaymentIntent` boundary lands.
- Fixed-price adapter integration, auction adapter integration, escrow
  fallback, Core-native resolver-backed ERC-2981, Governed Gas Parameter
  hosts, deprecated-asset release-grace reads, the claim router, artist
  account-source resolution, and the release-authorization/`PaymentIntent`
  typed-data surfaces remain outstanding implementation work.

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
11. Core-native ERC-2981 is mandatory from genesis; royalty registry overrides
    are not a substitute.
12. Collections may be fixed-size, capped-open, or uncapped-open. Revenue policy
    must not require final collection size to be known at collection creation.
13. The production Core must not keep a second royalty source of truth through
    OpenZeppelin `ERC2981` storage.
14. Every contract pointer that can affect revenue resolution must follow ADR
    0004 pointer governance before it can be changed or frozen.
15. External-call gas bounds in the revenue layer are Governed Gas
    Parameters with immutable floors, never immutable caps (ADR 0010
    decision D1). Gas retuning is Operational-layer and never touches
    artwork or economic identity.

## Governed Gas Parameters In The Revenue Layer

The Governed Gas Parameter (GGP) model — storage-backed governed values,
immutable per-parameter floors, staged raise/lower classes, health probes,
change events, release-manifest recording, and exclusion from finality and
frozen-route identity — is defined once in
`docs/stream-long-term-architecture.md` (ADR 0010 decision D1). This
section applies that model to the revenue layer; it does not restate the
model.

Revenue-layer GGPs and their hosts:

| Parameter | Host | Guards | Genesis planning value |
| --- | --- | --- | --- |
| `ROYALTY_RESOLVER_GAS_LIMIT` | `StreamCore` storage | resolver `staticcall` in `royaltyInfo()` | 50,000 |
| `ROYALTY_RETURN_GAS_BUFFER` | `StreamCore` storage | parent-side decode reserve in `royaltyInfo()` | 15,000 |
| `ERC_1271_GAS_LIMIT` | split factory parameter store | `isValidSignature` staticcalls for release authorizations, sale authorizations, and `PaymentIntent`s | 400,000 |
| `ASSET_POLICY_GAS_LIMIT` | split factory parameter store | asset-policy registry staticcalls from wallets, adapters, and escrow | 30,000 |
| `WALLET_DEPOSIT_GAS_LIMIT` | split factory parameter store | gas-bounded split-wallet deposits from settlement and escrow flush | 50,000 |
| `FLUSH_GAS_FLOOR` | revenue escrow storage | minimum `gasleft()` before escrow flush zeroes owed credit | 300,000–500,000 |

Requirements [RSR-GGP]:

1. Each parameter above is a Governed Gas Parameter exactly as defined by
   the model home, `docs/stream-long-term-architecture.md` [LTA-GGP]. No
   revenue-layer contract may hard-code an external-call gas cap, and this
   document adds no pattern rules of its own — rules 2, 3, 4, 7, 8, and 10
   below bind the model's rules to this layer by citation.
2. Raise and lower governance follows [LTA-GGP] requirements 1–2 unchanged
   (ADR 0011 decision R5): every raise is bounded to at most 2x the
   current value per action and staged raises use the normal delay class;
   the emergency path is raise-only and executes only against a recorded
   failing probe run at the current value; lowers use the normal delay
   class with a recorded passing probe run at the proposed value and
   revert below the immutable floor. Lowers stage through
   [RSR-STAGED-GOVERNANCE] rule 1.
3. GGP values are Operational-layer per [LTA-GGP] requirement 3; in this
   layer the exclusion covers `assignmentHash` and every economic preimage
   in this document.
4. Every revenue-layer GGP change emits the canonical change event and
   records genesis value and floor in the release manifest per [LTA-GGP]
   requirement 4.
5. Health probes are parameter-specific and must be recorded as release or
   governance evidence: `probeRoyaltyInfo` runs for
   `ROYALTY_RESOLVER_GAS_LIMIT` and `ROYALTY_RETURN_GAS_BUFFER`; a
   maximum-supported-class ERC-1271 verification (rule [RSR-1271].2) for
   `ERC_1271_GAS_LIMIT`; an all-cold `assetStatus` read for
   `ASSET_POLICY_GAS_LIMIT`; and a measured worst-case undeployed-wallet
   flush for `FLUSH_GAS_FLOOR`. Each probe above lives in the named
   per-parameter probe contract recorded in the release manifest with its
   `probeMaxAgeBlocks` ([LTA-GGP] definition item 6; ADR 0011 decision
   R5), emitting the canonical `GasParameterProbed` record that gates
   lowering, emergency raising, and the permissionless conditional raise.
   Probe placement follows [LTA-GGP] requirement 2.
6. Split wallets, settlement adapters, and the escrow must read the current
   values of `ERC_1271_GAS_LIMIT`, `ASSET_POLICY_GAS_LIMIT`, and
   `WALLET_DEPOSIT_GAS_LIMIT` from the
   split factory parameter store of their deployment line through the
   factory pointer they already immutably pin. That read is a
   trusted-infrastructure read of immutable protocol code: it may forward
   unrestricted gas, must be a `staticcall`, and must fail closed for only
   the guarded operation if it reverts or returns malformed data. Untrusted
   external calls remain capped; only the parameter fetch from the pinned
   factory is uncapped.
7. Every EIP-150 63/64 parent-gas precheck in this layer reads the current
   GGP value per [LTA-GGP] requirement 5.
8. Each revenue-layer GGP is a named member of the hard-fork/repricing
   review checklist with the model home's monitoring threshold ([LTA-GGP]
   requirement 6).
9. Genesis sizing gates. For the read-path caps —
   `ROYALTY_RESOLVER_GAS_LIMIT`, `ROYALTY_RETURN_GAS_BUFFER`,
   `ASSET_POLICY_GAS_LIMIT`, and `WALLET_DEPOSIT_GAS_LIMIT` — the genesis
   value must be at least four times the deepest measured all-cold guarded
   path, and the immutable floor must be at least twice that measured path
   and at most the genesis value. `ERC_1271_GAS_LIMIT` is sized against
   the heaviest named wallet class per [RSR-1271].2, and
   `FLUSH_GAS_FLOOR` against measured worst-case flush, each with recorded
   margin rather than the 4x multiple. All measurements, multiples, and
   floors are release artifacts.
10. Remediation for a guarded path outgrowing its cap follows the
    [LTA-GGP] requirement 7 order (raise first, compressed successor
    second, new deployment line last): cap exhaustion is a recoverable
    operational incident, never a permanent outage of royalty disclosure,
    release, or flush.

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

The v1 wallet limit is 64 entries and 64 unique accounts.
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
// PROFILE_DOMAIN string preimage and hash: [RSR-DOMAINS]
bytes32 profileId = keccak256(abi.encode(
    PROFILE_DOMAIN,
    uint256(block.chainid),
    address(factory),
    uint16(schemaVersion),
    uint16(walletVersion),
    bytes32(splitWalletInitCodeHash),
    bytes32(splitWalletRuntimeCodeHash),
    address(assetPolicyRegistry),
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
A final dust sweep needs its own separately accepted decommissioning spec
because later marketplace or forced receipts can still arrive.

Releases use checks-effects-interactions. If a native ETH or ERC-20 transfer
fails, the transaction reverts and the entitlement remains claimable. The
native asset sentinel in events and views is `address(0)`.
Native ETH and each ERC-20 asset are independently keyed in release, observed,
and escrow accounting. No asset balance may be used to satisfy another asset's
release or escrow obligation.
The wallet uses one release reentrancy guard across all assets and recipients,
not a per-asset lock. A native ETH recipient cannot reenter to release ERC-20s,
and an ERC-20 callback cannot reenter to release native ETH or another token.

### Release Authorization

Requirements [RSR-RELEASE-AUTH]:

1. Anyone may call `release(asset, account, account)` to move an entitled
   account's releasable funds to that same account. This supports keepers
   and recipient discovery without creating theft risk.
2. Releasing to any alternate recipient must require `msg.sender == account`
   or a valid EIP-712/ERC-1271 `ReleaseAuthorization` signed by the entitled
   account. The pinned typed-data surface is:

   ```solidity
   bytes32 constant RELEASE_AUTHORIZATION_TYPEHASH = keccak256(
       "StreamReleaseAuthorization(address asset,address account,"
       "address recipient,bytes32 nonce,uint64 deadline)"
   );
   ```

   Field inventory: `asset` (native sentinel `address(0)` allowed),
   `account` (the entitled account and required signer), `recipient`
   (non-zero payout destination), `nonce` (single-use per signer:
   consumed-nonce state is keyed by `(account, nonce)`, ADR 0011 decision
   R10), and
   `deadline` (unix seconds; expired authorizations revert). The EIP-712
   domain is `name = "6529StreamSplitWallet"`, `version = "1"`,
   `chainId = block.chainid`, `verifyingContract = address(wallet)`, so the
   destination wallet and chain are bound by the domain separator rather
   than duplicated in the struct. Wallets must expose ERC-5267 domain
   introspection. The typehash and domain are recorded in
   [Revenue Domain Constants And Typehashes](#revenue-domain-constants-and-typehashes).
3. The wallet must consume the release-authorization nonce before transfer
   under CEI. Consumed-nonce state is keyed by `(account, nonce)` — the
   entitled signing account plus the nonce, never a bare wallet-wide nonce
   set — so no account can consume, revoke, or invalidate another
   account's nonce value (ADR 0011 decision R10). A consumed or revoked
   `(account, nonce)` pair is invalid forever. The wallet must expose the
   explicit-address replay view
   `isReleaseAuthorizationNonceUsed(address account, bytes32 nonce)`;
   caller-relative (`msg.sender`-scoped) replay views are nonconformant
   (ADR 0011 decision R12).
4. A relayer cannot change the asset, account, recipient, nonce, deadline,
   or destination wallet named by the authorization. Releases in this
   wallet version always release the full releasable amount computed at
   execution time; there is no partial-release mode, so the authorization
   deliberately binds no amount field and no amount can drift between
   signature and execution.
5. The entitled account must be able to revoke an unused authorization
   before its deadline, either by calling
   `revokeReleaseAuthorization(nonce)` from the account or by any caller
   presenting an account-signed EIP-712/ERC-1271 revocation over the same
   nonce (ADR 0010 decision D10.4). Revocation is signer-scoped: the
   direct call consumes `(msg.sender, nonce)` and a signed revocation
   consumes the signer's own `(account, nonce)` pair, so revocation can
   never consume a nonce outside the caller's or signer's own scope
   (ADR 0011 decision R10). Revocation emits
   `ReleaseAuthorizationRevoked`.
6. `syncAsset` shares the same wallet-wide reentrancy guard as `release`.
   Operators should sync before release when they want a clean observation
   transaction; reentrant sync during an active release reverts.

### ERC-1271 Verification Class

Requirements [RSR-1271]:

1. Every ERC-1271 `isValidSignature` staticcall in the revenue layer —
   alternate-recipient release, sale authorization, `PaymentIntent`, and
   revocation verification — must forward exactly the current
   `ERC_1271_GAS_LIMIT` Governed Gas Parameter
   ([RSR-GGP]), use `staticcall`, and use bounded returndata decoding. A
   failed, out-of-gas, malformed, or wrong-magic-value staticcall reverts
   the guarded operation before nonce consumption or transfer. Recovered
   EOA signatures must recover to a nonzero address that exactly matches
   the required signer; `ecrecover` returning `address(0)` is always
   invalid (ADR 0010 decision D8.3).
2. The supported contract-wallet class posture and its named class set
   have exactly one home: ADR 0004 [GOV-1271-CLASS] (ADR 0010 decision
   D7.3; ADR 0011 decision R10). This layer cites that home and defines no
   wallet-class prose of its own. The `ERC_1271_GAS_LIMIT` genesis value
   must cover the measured heaviest class named by that home with margin —
   hence the 400,000 gas planning value — the immutable floor must be at
   least the measured heaviest named class, and the measured classes,
   genesis value, and floor must be recorded in the release manifest.
3. Conformance tests must prove that a maximum-supported legitimate wallet
   of each class named by ADR 0004 [GOV-1271-CLASS] verifies successfully
   at the deployed genesis value,
   and that a malicious gas-consuming wallet cannot grief past the cap.
   Testing only a malicious wallet is nonconformant.
4. Because `ERC_1271_GAS_LIMIT` is a GGP, a future heavier legitimate
   scheme (post-quantum verifiers, deeper nesting) is handled by a staged
   raise, not a new wallet line. Entitlements can therefore never be
   permanently stranded by signature-verification cost.
5. Cap-independent path: the ERC-1271 relay path is a convenience, not the
   only escape for contract accounts. Any entitled contract account that
   can execute calls releases to an arbitrary recipient with
   `msg.sender == account` and no signature verification at all, and
   `release(asset, account, account)` remains permissionless. The release
   manifest and recipient documentation must state this cap-independent
   path explicitly so ETH-rejecting contract recipients know the
   self-execution recipe.

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
That is a safety freeze for the affected asset, not a sweep or recovery path:
funds remain in the wallet, native ETH and other active assets remain usable,
and the asset becomes syncable/releasable again only if the observed cumulative
balance recovers to the previous high-water mark or a separately accepted
adapter/recovery spec accepts the non-standard behavior.
`lastObservedReceived(asset)` is initialized at first detection through
`syncAsset`, official deposit, or release; operator and recipient tools should
sync ERC-20 assets before presenting claimable balances.
Unknown ERC-20s sent directly before first observation are unsupported for
historical guarantees; the wallet can only account from the first observed
balance. If governance later approves that asset and `syncAsset(asset)` first
observes a positive wallet balance, that observed balance becomes the starting
cumulative balance for future releases; the wallet cannot prove who funded
pre-observation transfers or apply historical source attribution before that
first observation. ERC-20 releases must also prove exact wallet and recipient
balance deltas: the wallet balance must decrease by exactly the released
amount and the recipient balance must increase by exactly the released amount.
No-return tokens, no-op transfers, fee-on-transfer behavior, rebases,
callbacks, and other non-standard behavior are unsupported unless a
separately accepted adapter spec accepts them.
This deliberately excludes USDT-style no-return transfer tokens from the v1
split-wallet ERC-20 path even if their `balanceOf` surface is otherwise
readable; listing them requires a separate accepted adapter or wallet version.

### Asset Policy

Requirements [RSR-ASSET-POLICY]:

1. ERC-20 assets are default-deny. Asset policy is deployment-wide, not per
   wallet. The split factory records the immutable `assetPolicyRegistry`
   for its wallet line, and v1 wallets consult that registry during
   non-native `syncAsset` and `release`. Native ETH is always supported
   without a registry read. If the registry is unavailable or an asset is
   `UNKNOWN`, non-native sync/release reverts safely for that asset only;
   native ETH and other active assets remain unaffected.
2. The registry read is a bounded external read. Each registry `staticcall`
   forwards the current `ASSET_POLICY_GAS_LIMIT` Governed Gas Parameter
   ([RSR-GGP]; genesis planning value 30,000 gas for an all-cold lookup,
   deployed value from measured gas plus margin under the [RSR-GGP].9
   multiples) and requires exactly 32 bytes of return data per view read.
   Malformed return data, no code at the registry, registry revert, or
   under-forwarded gas makes the specific non-native `syncAsset` or
   `release` revert before ledger mutation. The wallet must not substitute
   "active" or "native" semantics when the asset policy read fails.
3. Because `ASSET_POLICY_GAS_LIMIT` is a GGP, a gas-schedule change that
   outgrows the read budget is remediated by a staged (or emergency
   raise-only) GGP raise on the factory parameter store — no wallet
   redeployment. A new split-wallet/factory deployment line is required
   only if the registry code itself no longer satisfies future EVM
   constraints; existing wallet balances remain in the old wallet line, and
   there is no hidden mutable registry pointer inside deployed wallets.
   Accepted residual risk: if a repricing outruns the read budget while
   governance quorum is simultaneously lost, non-native release in
   deployed wallets stays frozen (fail closed, funds intact, native ETH
   unaffected) until quorum or a social successor process restores the
   raise path. Monitoring must alert on read-gas margin per [RSR-GGP].8,
   and operators must publish pre-emptive migration guidance for
   recipients if margin decays.
   The registry read surface is the canonical
   `IStreamAssetPolicyRegistry` interface in
   [Canonical v1 Interfaces](#canonical-v1-interfaces); wallets use its
   `assetStatus` and `assetReleaseGraceUntil` views.
4. Asset state is explicit and five-valued. The numeric IDs below are the
   normative v1 assignment and must be recorded in the numeric ID catalog:

   ```text
   0 UNKNOWN       never configured; fail closed for adapters, sync, release
   1 ACTIVE        official adapters may accept; sync/release allowed
   2 INACTIVE      under review or temporarily disabled; fail closed
   3 DEPRECATED    retired for new official acceptance; releasable under
                   the observation and grace rules below
   4 UNSUPPORTED   incident freeze; sync/release disabled until a
                   separately accepted adapter or recovery spec accepts
                   the asset; creates no sweep right, blocks no other asset
   ```

5. `DEPRECATED` semantics (ADR 0010 decision D8.6, resolving the
   ADR 0008/spec contradiction in favor of releasable-under-grace):
   deprecation retires an asset for new official acceptance — adapters must
   reject new primary payments and the escrow must reject new credits —
   but it does not strand owed funds. A wallet must allow `syncAsset` and
   `release` for a `DEPRECATED` asset when either condition holds:
   `lastObservedReceived(asset)` was initialized in that wallet (observed
   balances and their later passive receipts stay releasable forever under
   the same monotonic-token assumptions), or
   `block.timestamp < assetReleaseGraceUntil(asset)` (the per-wallet
   release grace, letting never-observed wallets — including wallets
   receiving escrow flushes of credits created while the asset was
   `ACTIVE` — initialize observation after deprecation). After the grace
   expires, a wallet that never observed the asset fails closed for it.
6. Every deprecation action must set
   `releaseGraceUntil >= effectiveAt + 180 days`. Operations must flush or
   pre-sync all outstanding non-native escrow credits and notify indexed
   recipients within the grace window, so no officially settled funds
   arrive at a wallet that can no longer initialize observation.
7. Asset-status transitions away from `ACTIVE` (to `INACTIVE`,
   `DEPRECATED`, or `UNSUPPORTED`) are economically material governance
   actions and must use the ADR 0004 staged action-ID model with timelock
   or two-step staging, exactly like default-scope assignment changes
   (ADR 0010 decision D8.6). One exception: marking an asset `UNSUPPORTED`
   in response to detected unsupported behavior may use the narrower
   emergency class, and must publish an incident reason hash/URI in the
   same action. Approvals to `ACTIVE` follow normal asset-policy review.
   The registry must be operated under the same ADR 0004 action-ID and
   staging events as other economically material changes; a bare
   single-transaction admin write for a tightening transition is
   nonconformant.
8. Moving an ERC-20 asset to `ACTIVE` is an asset-policy decision, not an
   automatic token-interface check. The policy admin must record evidence
   that the token has no transfer fees, rebases, confiscation mechanics,
   balance-decreasing hooks, callback surprises, no-return transfer
   semantics, or no-op transfer behavior that would violate the
   monotonic-balance and exact-delta assumptions.
   Unsupported-asset recoverability is excluded from v1 and requires a
   separately accepted state-transition, adapter, or recovery spec; the v1
   unsupported state is not a sweep authority.
9. If an ERC-20 moves back to `ACTIVE` after a period of inactive,
   deprecated, or unsupported operation, equality conservation is
   re-established only after the next successful `syncAsset(asset)`
   observation. Between transitions, the required safety property is no
   over-release; exact equality to external ground truth may require
   indexer/operator reconciliation.

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
and sync for that asset until a separate asset-specific adapter or recovery
spec is accepted.

## Open-Ended Collections And Revenue Epochs

The permanent Stream contract must support collections whose final size is not
known in advance. A photographer may create a named subcollection inside
Stream, add works over many years, pause it, resume it, and eventually close it
or leave it ongoing.

Revenue and royalty policy must therefore be independent of final collection
supply.

### Token ID Model

Core allocates global sequential ERC-721 token IDs and stores explicit
mappings (ADR 0009 decision 1):

```solidity
mapping(uint256 tokenId => uint256 collectionId) tokenCollectionId;
mapping(uint256 tokenId => uint256 collectionSerial) tokenCollectionSerial;
// `tokenCollectionIdentity` returns mappingExists from live, burned, or prepared state.
```

The current namespaced `collectionId * 10_000_000_000 + serial` formula should
be removed before production deployment. It is useful historical context
from the current code, but it is not the target identity model.

Rules:

1. `StreamCore` owns token ID allocation.
2. Minter, drop, and auction contracts do not pass arbitrary token IDs into
   Core.
3. Collection-local serials are stable display/accounting facts, not token ID
   codecs.
4. `royaltyInfo()` uses the explicit mapping when it needs collection-scope
   resolution. CON-012 only exposes Core's canonical
   `tokenCollectionIdentity` read; wiring that read into the resolver-backed
   `royaltyInfo()` implementation remains outstanding resolver work.
5. Unmapped token IDs fall back only to default royalty assignment or zero.
6. Burned tokens keep their last token-to-collection mapping for historical
   royalty disclosure. Burning removes ERC-721 ownership and enumerable
   membership, but Core must not clear retained collection identity or burned
   audit state.

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
   collection; sale identity is owned by `docs/stream-sales-and-auctions.md`
   [SSA-IDENTITY]. They are not collection IDs and must not imply final
   supply.
8. Assignment and revenue events must include both `collectionId` and `tokenId`
   when a token is known. For collection-level sale events before token
   allocation, the event must include a later token allocation event or a
   same-transaction allocation reference. Protocol v1 does not define a
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
    bytes32 expectedRoyaltyAssignmentHash
) external returns (bytes32 tokenRoyaltyAssignmentHash);
```

`expectedRoyaltyAssignmentHash` and the returned
`tokenRoyaltyAssignmentHash` are canonical `royaltyAssignmentHash` values
under [RSR-ROYALTY-HASH]; the hook reverts if the resolved
collection/default royalty policy hash does not equal the expected value.

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

### Sale Authorization

Requirements [RSR-SALE-AUTH]:

1. Signed sale authority must bind the economic policy being used. The
   pinned `SALE_AUTHORIZATION_TYPEHASH`, its full field inventory —
   including asset, unit price, quantity, nonce, and deadline — its
   EIP-712 domain, its ERC-1271/ECDSA verification rules, its
   mint-ledger `authorizationId` derivation, and its revocation surface
   are owned by `docs/stream-sales-and-auctions.md` [SSA-AUTH]
   (ADR 0010 decisions D3.5 and D5); this document defines no second sale
   payload. Every primary sale program — fixed price, auction, private
   sale, refund window — must use that authorization, and the sale adapter
   must verify it, recompute every hash from calldata and chain state, and
   consume the nonce before settlement effects. This section owns the
   revenue-policy semantics the payload's `expectedPrimaryPolicyHash` and
   `primaryPolicyMode` fields carry.
2. `expectedPrimaryPolicyHash` is the resolved primary policy hash expected
   by the signer at authorization time. It binds the resolver, revenue
   class, collection/token context, template/profile, verified wallet, and
   resolver assignment hash through the canonical
   `resolvedPrimaryPolicyHash` preimage in
   [Assignment Semantics](#assignment-semantics).
3. `primaryPolicyMode` must be one of:

   ```text
   STRICT_MATCH      settlement reverts unless the resolved policy hash matches
   ALLOW_CURRENT     signer explicitly accepts settlement-time current policy
   ```

   The v1 default is `STRICT_MATCH` for economically material sales that
   settle in the authorization's own flow.
   `ALLOW_CURRENT` is for intentionally mutable sale programs and for the
   envelope-bounded deferred leg of escrow-holding sale modes (rule 5),
   and must be visible in the signed payload and settlement event. This
   prevents governance or operators from changing primary-sale economics
   between signature and settlement without the signer having opted into
   that mutability.
   If a scope freezes between signature and settlement, `ALLOW_CURRENT`
   resolves the then-current frozen assignment. That is acceptable only
   because the signer explicitly chose current-policy drift.
4. `StreamPrimarySaleSettlement` accepts calls only from enabled settlement
   callers, and each enabled caller must be a sale adapter that performed
   the rule 1 verification in the same call frame as settlement. For
   ERC-20 settlement, the adapter must additionally satisfy the
   payer-intent requirement of [RSR-PAYMENT-INTENT] — a payer-signed
   `PaymentIntent` or a rule 5 by-construction intent — before any
   allowance pull.
   `STRICT_MATCH` at the settlement contract is a resolver-drift check
   against the adapter-supplied expected hash; the payer-intent, price,
   quantity, deadline, and nonce enforcement lives at the adapter boundary
   and is mandatory, not operational advice.
5. Deferred-settlement drift envelopes (ADR 0011 decision R6). The
   `STRICT_MATCH` default of rule 3 applies to settlements that execute in
   the authorization's own flow, where a drift revert is recoverable by
   re-signing. Escrow-holding sale modes — refund-window sales, Dutch
   uniform clearing, mint-at-settlement auctions, and accepted offers —
   settle later against an immutable sale record that no party can
   re-sign, so they must not bind `STRICT_MATCH` for the deferred leg.
   Instead the buyer's signed sale surface binds a drift envelope —
   maximum price, sale reference, and finalize-by deadline; the envelope
   payload and the mode state machines are owned by
   `docs/stream-sales-and-auctions.md` — and the deferred official
   settlement executes under `ALLOW_CURRENT` within that envelope with
   the observed `policyDrift` evented. Past the finalize-by deadline, a
   permissionless sale-side refund path unlocks the escrowed funds.
   Resolved-policy drift between purchase and finalization — including an
   assignment change or a freeze flipping the `assignmentHash` frozen bit
   — is therefore never a terminal settlement failure and can never
   strand escrowed buyer funds.
Settlement events must expose whether drift was observed between the signed
`expectedPrimaryPolicyHash` and the resolved settlement policy.
The resolved primary policy hash binds the assignment's frozen bit through
the canonical `assignmentHash` preimage (ADR 0009 decision 9); it does not
bind `freezeMode` or `permanentFreeze`, because freeze-mode transitions
between frozen states do not change economics and must not invalidate
outstanding signed authorizations. The settlement contract binds the
resolver assignment hash, and that assignment hash changes when its exact-key
frozen bit changes.
Therefore a freeze between signature and settlement changes the resolved policy
hash and makes `STRICT_MATCH` revert unless the upstream authorization supplied
the frozen policy hash. `ALLOW_CURRENT` is the explicit opt-in to that drift.

No production sale path may use `tx.origin` as payer, recipient, executor, or
authorizer. The current `StreamDrops` authorization model must be rewritten
before production deployment so the signed sale authorization binds the
actual recipient or recipient batch, payer, executor, collection,
phase/drop/auction ID, quantity, price, nonce, deadline, and policy hash.
Settlement recomputes those hashes from calldata and chain state. A
static-analysis CI gate must fail the build if any sale, drop, auction, or
mint path reads `tx.origin`.

### Normative Paid Mint Orchestration

Requirements [RSR-ORCHESTRATION]:

1. The two-path rule governs the transaction in which a token is minted
   against payment: every such transaction must use exactly one of the two
   v1 paths below, and no third paid mint order is deployment-conformant
   for minting against payment. Paid transfer of an already-minted
   custody-held token is a settlement order, not a mint order, and uses
   `CUSTODY_SETTLEMENT_TRANSFER` under
   [Sale And Auction Settlement Boundary](#sale-and-auction-settlement-boundary).
2. Both paths must satisfy the canonical protocol v1 mint ordering
   invariants defined once in `docs/launch-v1-target-architecture.md`
   [PV1-MINT-ORDER]. This section does not restate that
   ordering; the per-step lists below are the two blessed realizations of
   it, and the [PV1-MINT-ORDER] invariants — validation before effects,
   identity and required accounting before entropy registration, entropy
   registration before any untrusted recipient callback — govern where the
   lists are silent (ADR 0010 decision D3.6).
3. A collection configured for `ROYALTY_SNAPSHOT_AT_MINT` must reject
   binding to a sale adapter that supports only `PRE_REVENUE_SINGLE_STEP`.
   Snapshot-at-mint collections require `PREPARED_MINT` or a separately
   accepted orchestration that writes the snapshot before any untrusted
   receiver callback.
4. Sale adapters may custody buyer funds before official settlement:
   holding payments in adapter custody — for refund-window sales, Dutch
   uniform-clearing rebates, or delayed acceptance — and settling the
   official sale later (minting at settlement through one of the two
   paths) is conformant and is not a third paid mint order. Custodial
   adapters must bind the buyer's drift envelope — maximum price, sale
   reference, and finalize-by deadline — plus the refund path in the
   signed sale surface (ADR 0011 decision R6), the deferred official
   settlement follows [RSR-SALE-AUTH].5, and the escrow-holding sale
   modes themselves are specified in `docs/stream-sales-and-auctions.md`
   (ADR 0010 decision D5.4).
5. Post-mint refunds of officially settled revenue are impossible by
   design: both paths deposit revenue to the split wallet or protocol
   escrow before mint completion, and escrow is permissionlessly
   flushable, so there is no refundable-revenue state after settlement.
   Refundability must be implemented adapter-side before official
   settlement per rule 4; changing this requires a new accepted
   orchestration spec.

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
7. Core executes `mintFromManager`, writes token identity, registers the
   token's entropy request context with the entropy coordinator, and only
   then `_safeMint`s to the initial recipient. Entropy registration must
   precede any untrusted recipient callback; the conformance-matrix entropy
   gate enforces this ordering at deployment.

Non-normative implementation evidence: the current direct-randomizer Core
slice reaches its legacy randomizer/hash boundary after `_safeMint`. That
interim ordering is as-built evidence only — it is not a permitted variant
of this sequence, is purged from every normative sequence (ADR 0010
decision D10.6), and fails the matrix entropy gate until the
entropy-coordinator boundary lands.

`PREPARED_MINT`:

1. Sale adapter validates payment, sale authorization, price, quantity, payer,
   recipients, beneficiaries, deadline, nonce, and `expectedPrimaryPolicyHash`.
2. Mint manager validates the phase, computes active `policyHash`, verifies the
   signed `MintTicket` or equivalent sale authorization, and binds the exact
   `mintCommitmentsHash`.
3. Mint ledger verifies the manager-registered policy hash and consumes
   counters, authorization IDs, and nullifiers.
4. Core executes `prepareMintFromManager`, creating authoritative token identity
   but no entropy/randomizer request and no ERC-721 transfer.
5. Resolver snapshots any required token-level primary or royalty assignment
   from Core's authoritative mapping.
6. Sale adapter deposits the accepted settlement asset into the verified split
   wallet or records escrowed revenue under
   `(revenueClass, profileId, wallet, asset)`.
7. Core executes `completePreparedMintFromManager`, clears the prepared record,
   `_safeMint`s to the initial recipient while keeping the Core completion
   sentinel active, and clears that sentinel only after the token's normal
   entropy/randomizer boundary returns.

Token-level economic snapshots written during `PREPARED_MINT` must be
derivable solely from Core token identity, collection/default assignment state,
the signed sale or mint authorization, and the active policy hashes. They must
not read, branch on, or depend on entropy seed, entropy request status,
provider result status, or renderer output, because entropy is unavailable
or not finalized when the snapshot is written. For a collection using
`ROYALTY_SNAPSHOT_AT_MINT`, the snapshot records the economic policy that was
authorized for the token; it does not wait for or incorporate randomness.

All steps in either path happen in one top-level transaction. A revert at any
step reverts ledger consumption, token identity, assignment snapshots, revenue
accounting, and any entropy/randomizer state reached during completion. No
untrusted recipient callback, randomness provider callback, refund callback,
split-wallet release, or arbitrary external hook may execute before the path's
required ledger consumption, token identity mapping, assignment snapshots, and
revenue accounting are complete.
`PREPARED_MINT` uses the canonical `STREAM_PREPARED_MINT_OPERATION_V1`
`operationId` defined in `docs/mint-policy-and-accounting.md`; the sale
adapter, manager, ledger, Core prepare/complete, resolver snapshot hook,
completion-time entropy/randomizer boundary, and escrow/deposit path must
reject mismatched operation IDs.

The v1 primary settlement surface includes native ETH and approved standard
ERC-20 assets. ERC-20 settlement must live in a payment adapter or
primary-sale settlement module outside Core, with exact token-transfer
accounting, allowance/payment failure handling, and escrow flush rules. Split
wallets can also release approved standard ERC-20 assets received passively.
Fee-on-transfer, rebasing, callback, or otherwise non-standard ERC-20 behavior
is unsupported unless a separate adapter spec accepts it.

### ERC-20 Payer Intent Binding

Requirements [RSR-PAYMENT-INTENT]:

1. ERC-20 primary adapters must read the same deployment-wide
   `IStreamAssetPolicyRegistry` pinned by the split factory and accept new
   primary payments only for `ACTIVE` assets. The adapter must perform
   safe-transfer handling, measure its own asset balance before and after
   payer transfer, and revert unless the received amount exactly equals the
   expected sale amount.
2. A standing ERC-20 allowance alone is never spendable as official
   revenue (ADR 0010 decision D8.2). Before pulling any payer allowance,
   the settlement path must verify — in the same call frame — a
   payer-signed EIP-712/ERC-1271 `PaymentIntent`, unless a rule 5
   by-construction intent applies:

   ```solidity
   bytes32 constant PAYMENT_INTENT_TYPEHASH = keccak256(
       "StreamPaymentIntent(address payer,address asset,"
       "uint256 maxAmount,bytes32 saleRef,"
       "bytes32 expectedPrimaryPolicyHash,bytes32 nonce,uint64 deadline)"
   );
   ```

   Field inventory: `payer` (the account whose allowance is pulled and the
   required signer); `asset`; `maxAmount` (the pull must not exceed it);
   `saleRef` (exactly the `settlementKey` preimage's `settlementId` — the
   sales-spec `saleId` under the [RSR-SETTLEMENT-BOUNDARY].5 mapping rule
   — binding the intent to one sale; no alternate derivation is
   conformant, ADR 0011 decision R9);
   `expectedPrimaryPolicyHash` (the payer's view of the economics being
   paid into); `nonce` (single-use per signer: consumed-intent state is
   keyed by `(payer, nonce)` in the verifying contract, ADR 0011 decision
   R10); `deadline`.
   The EIP-712 domain is `name = "6529StreamPrimarySaleSettlement"`,
   `version = "1"`, `chainId`, `verifyingContract` = the contract that
   performs the allowance pull, with ERC-5267 introspection. The typehash
   and domain are recorded in
   [Revenue Domain Constants And Typehashes](#revenue-domain-constants-and-typehashes).
3. The verifier must consume the `PaymentIntent` `(payer, nonce)` pair
   before the allowance
   pull under CEI, verify contract-wallet signatures under [RSR-1271],
   reject expired deadlines, reject pulls above `maxAmount`, and reject a
   `saleRef` or `expectedPrimaryPolicyHash` that does not match the sale
   being settled. Consumed-intent state is keyed by `(payer, nonce)`,
   never by a bare contract-wide nonce set, so no payer can consume,
   revoke, or invalidate another payer's nonce value (ADR 0011 decision
   R10). The payer must be able to revoke an unused intent by
   nonce (payer-sent revocation consumes `(msg.sender, nonce)`;
   payer-signed revocation consumes the signer's own pair; evented;
   ADR 0010 decision D10.4). The verifier must expose the
   explicit-address replay view
   `isPaymentIntentNonceUsed(address payer, bytes32 nonce)`;
   caller-relative replay views are nonconformant (ADR 0011 decision
   R12).
4. Exact-amount Permit2 or EIP-2612 permits signed over the same sale
   reference may satisfy rule 2 only when the permit's signed payload
   binds payer, asset, exact amount, spender, and deadline and the adapter
   binds the remaining `PaymentIntent` fields in the same call frame; a
   permit that merely sets a standing allowance does not.
5. Two intents exist by construction and need no signed `PaymentIntent`.
   Native ETH settlement: the payer's `msg.value`
   in the settlement transaction is the intent by construction, and the
   sale authorization under [RSR-SALE-AUTH] binds its amount.
   Payer-is-caller ERC-20 settlement (ADR 0011 decision R10): a pull from
   `payer == msg.sender` within the settlement call frame is consent by
   construction, exactly like `msg.value`, and satisfies the payer-intent
   requirement without a signed `PaymentIntent`, provided the pull is
   bounded by the asset and amount of the [RSR-SALE-AUTH] authorization
   for the sale being settled. The exemption never extends further:
   whenever the pull is initiated by a relayer, executor, or any caller
   other than the payer itself in the same call frame, the signed
   `PaymentIntent` remains mandatory.
6. Enabled settlement callers remain a governed trust boundary and the
   caller set must stay minimal, but caller discipline is defense in
   depth, not the defense: with rules 2–4, a compromised or buggy enabled
   caller cannot convert any standing allowance into official settlement
   without a matching payer signature. Conformance tests must prove that
   settlement initiated by any caller other than the payer itself without
   a valid `PaymentIntent` reverts before any allowance
   pull, template materialization, escrow credit, or mint effect, and
   that the rule 5 payer-is-caller path cannot pull an asset or amount
   beyond the sale authorization's binding.
7. Allowance failure, transfer failure, no-op transfer, fee-on-transfer
   behavior, rebasing balance movement, callback-dependent behavior,
   malformed token return data, or an unavailable asset-policy registry
   all revert before minting or revenue recording. Passive split-wallet
   ERC-20 receipts can be observed and released under the split-wallet
   accounting rules, but they are not primary-sale settlement evidence and
   do not relax the adapter's exact-delta requirement.

### Primary Split Templates And The Artist Take

Primary assignments support primary split templates because some recipients
are dynamic sale participants known only at settlement. A template entry
has either a static account or an open `bytes32 accountSource`. At
settlement, the sale contract resolves supported account sources from sale
context, materializes a fixed split profile, and then funds or escrows that
profile's wallet. Royalty assignments do not use dynamic account sources
because ERC-2981 does not pass sale context to the receiver.

Requirements [RSR-TEMPLATES]:

1. `ARTIST` is a first-class beneficiary class (ADR 0010 decision D2.5),
   identified in profiles and templates by the `keccak256("artist")` label
   class ([`docs/stream-artist-authority.md`](stream-artist-authority.md) [AA-ECON] rule 1). The dynamic
   account source `keccak256("COLLECTION_ARTIST")` resolves to the
   collection's accepted artist payout address recorded under
   [`docs/stream-artist-authority.md`](stream-artist-authority.md), and entries it materializes carry an
   `artist`-class label. Resolution must use the accepted binding only: a
   proposed-but-unaccepted, disputed, or revoked binding must revert
   artist-sourced materialization before any settlement effect.
   Multi-artist collections resolve through the typed collaborator list
   and its share references defined in the artist authority spec.
2. `keccak256("SALE_POSTER")` remains a supported dynamic source paying
   the poster attached to a specific drop or auction. Where the poster is
   the collection's accepted artist, the `COLLECTION_ARTIST` source and
   the artist-take posture below apply instead.
3. Genesis artist-take posture: the genesis default primary template for
   artist-bound collections is:

   ```text
   900000 ppm dynamic COLLECTION_ARTIST
   100000 ppm static protocol
   ```

   The genesis default template carries no curators bucket (ADR 0011
   decision R12). Curator classes are deployment configuration, never a
   protocol default: a template or profile may carry curator-class
   entries only when the deployment manifest names the receiving curator
   pool contract and that contract satisfies the
   [StreamCuratorsPool](#streamcuratorspool) conformance rules.
   For any artist-bound collection, the aggregate share of ARTIST-class
   entries (the accepted artist plus typed collaborators) must be at least
   500,000 ppm unless the accepted artist has co-signed the assignment
   under [RSR-ARTIST-ECONOMICS]. Artist-less default splits are not a
   normalized posture: a collection without a bound artist must carry the
   immutable `PLATFORM_WORKS` declaration from
   [`docs/stream-artist-authority.md`](stream-artist-authority.md), and only `PLATFORM_WORKS`
   collections may use templates with no ARTIST-class entry.
4. Protocol fee posture: the static protocol share in genesis default
   templates is 100,000 ppm (10%) and must not exceed that value in any
   default template without a recorded governance rationale. Per-sale
   templates may choose lower protocol shares freely.
5. Disclosure: every collection's resolved primary split — entries, shares,
   template or profile ID, and artist share — must be surfaced through the
   collection metadata surface (`docs/collection-metadata-contract.md`)
   and operator UX before its first public sale starts. Selling against an
   undisclosed split is nonconformant.
6. Historical context (non-normative): the pre-specification three-bucket
   deployment used `500000 ppm dynamic SALE_POSTER / 250000 ppm static
   protocol / 250000 ppm static curators pool`. That mapping is retained
   here only as history for event archaeology; it is not a genesis
   default and must not be presented as the protocol's economics.

The protocol does not need a new Solidity struct to express a new policy —
an estate share, a preservation fund, a museum endowment. It only needs a
new split profile or primary split template and assignment.

Template IDs are deterministic:

```solidity
// PRIMARY_TEMPLATE_DOMAIN string preimage and hash: [RSR-DOMAINS]
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
// MATERIALIZED_PRIMARY_PROFILE_METADATA_DOMAIN string preimage
// and hash: [RSR-DOMAINS]
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

The consumed settlement key is the canonical replay domain for official primary
revenue settlement:

```solidity
bytes32 settlementKey = keccak256(abi.encode(
    SETTLEMENT_KEY_DOMAIN, // string preimage and hash: [RSR-DOMAINS]
    uint256(block.chainid),
    address(settlementContract),
    bytes32(settlementId),
    bytes32(revenueClass),
    uint256(collectionId),
    uint256(tokenId),
    uint256(saleNonce),
    address(payer),
    address(poster),
    address(beneficiary),
    uint256(amount)
));
```

Sale-identity mapping rule (ADR 0011 decision R9): `settlementId` is
exactly the sales-spec `bytes32 saleId` of the sale being settled,
computed under `docs/stream-sales-and-auctions.md` [SSA-IDENTITY], and
`saleNonce` is the adapter-local `saleNonce` bound inside that same
[SSA-IDENTITY] preimage. This document defines no sale-identity preimage
of its own, and no other value may be supplied for either field; an
earlier draft's `uint256 saleId` field ("drop ID", "may be the token ID")
is renamed and retyped by this rule.

`primaryPolicyMode`, `expectedPrimaryPolicyHash`, resolved policy evidence,
settlement caller, and asset address are deliberately excluded from
`settlementKey`; they are validation inputs and emitted evidence, not alternate
replay domains for the same sale.

Sale context is emitted for reconstruction only:

```solidity
bytes32 saleContextHash = keccak256(abi.encode(
    SALE_CONTEXT_DOMAIN, // string preimage and hash: [RSR-DOMAINS]
    uint256(block.chainid),
    address(settlementContract),
    bytes32(revenueClass),
    keccak256(abi.encode(
        bytes32(settlementId),
        uint256(collectionId),
        uint256(tokenId),
        uint256(saleNonce)
    )),
    keccak256(abi.encode(
        address(settlementCaller),
        address(payer),
        address(poster),
        address(beneficiary)
    )),
    address(asset),
    uint256(amount),
    keccak256(abi.encode(
        uint8(primaryPolicyMode),
        bytes32(expectedPrimaryPolicyHash),
        bytes32(resolvedPrimaryPolicyHash),
        bytes32(resolvedAssignmentHash)
    )),
    bytes32(templateId),
    bytes32(profileId),
    address(wallet)
));
```

`saleContextHash` is an event reconstruction and replay aid, not a source of
on-chain payment authority. Consumers should verify the emitted sale fields and
chain state; they must not treat arbitrary off-chain context as authenticated
merely because it hashes to the emitted value.
If a later sale adapter needs a `saleKind` or additional signed fields in this
hash, it must use a new versioned context domain instead of reusing the v1
preimage.
Likewise, event fields such as `poster`, `payer`, and `beneficiary` are
informational for reconstruction and UX. The actual payee set is the fixed
profile entry materialized from supported account sources such as
`SALE_POSTER`; indexers reconstructing who was paid must read the profile
entries and wallet deposits, not the display-only event fields alone.

Materialization resolves all dynamic sources before mint or settlement state
changes. Zero or unsupported dynamic accounts revert. Entries that materialize
to the same `(account, labelId)` pair are aggregated before fixed-profile
validation; same-account entries under different labels remain separate.
Template materialization is a public deterministic cache: any caller can
materialize a template for a concrete poster, but `PrimaryTemplateMaterialized`
is resolver state evidence only. It is not official sale settlement evidence
unless paired with a same-key `PrimaryRevenueSettled` event from the settlement
adapter.
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
accepted settlement revenue may be escrowed against the deterministic wallet
only after the profile preimage has been validated, the profile exists in the
factory, the predicted wallet has no code, and
`wallet == factory.walletFor(profileId)`.
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
unflushable. Recipients of a flushed `DEPRECATED` asset release under the
observation and grace rules of [RSR-ASSET-POLICY].5, and operations must
flush or pre-sync outstanding non-native credits within the grace window
per [RSR-ASSET-POLICY].6.
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
runtime code hash, and that revocation must come with a spec-defined recovery
plan for the owed funds.

Escrow and wallet accounting are separate until flush succeeds:

```text
walletObservedReceived(asset) =
  walletCurrentBalance(asset) + walletTotalAccountReleased(asset)

escrowOwed(revenueClass, profileId, wallet, asset) =
  settlement-asset value owed by protocol escrow but not yet deposited into wallet
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
before zeroing owed credit unless `gasleft()` is above a deployment-pinned
`FLUSH_GAS_FLOOR` sized to cover worst-case `deployWallet`, code-hash
verification, and native deposit with margin. CI should record the measured
worst-case gas for deployed-wallet flush and undeployed-wallet flush. If the
wallet version or factory changes, the floor and measurements must be updated
in the release manifest. Callers may always pre-deploy the wallet through the
factory and then flush the already-deployed path.
Initial target range is 300,000 to 500,000 gas for the undeployed-wallet path,
but the deployed artifact must use measured gas plus margin rather than this
rough planning range.
`FLUSH_GAS_FLOOR` is a Governed Gas Parameter hosted in escrow storage
under [RSR-GGP] (ADR 0010 decision D1): its deploy-time immutable floor is
the genesis measured minimum, raises use the service-restoring class when a
gas-schedule change makes the current value insufficient, and lowers
require a recorded passing worst-case flush measurement at the proposed
value. Every change publishes the new value and gas evidence in the release
manifest.
The floor calculation must account for EIP-150's 63/64 gas forwarding rule for
each external subcall. Tests must measure the actual gas delivered to
`deployWallet` and to the wallet deposit/receive path, not merely the parent
`gasleft()` value.
After owed credit is zeroed, any deployment, code-hash check, or transfer
failure must bubble as a revert of the entire `flushEscrow` call so EVM rollback
restores the owed balance. Production code must not swallow post-zeroing
failures in `try/catch`, return `false` while leaving credit zeroed, or emit
success after a failed subcall. Tests must simulate a subcall out-of-gas
after the zeroing point and prove the parent call reverts with owed credit
intact.

Escrow accounting is log-reconstructable but chain-finality-sensitive. Indexers
and accounting exports should treat escrow deposits, flushes, and recovery
events as provisional until their normal confirmation depth, and then reconcile
against onchain owed balances. A reorg cannot create or destroy contractual owed
balances on the canonical chain, but offchain reports must be able to roll back
or replay escrow events deterministically.
If a future gas-schedule change makes the current `FLUSH_GAS_FLOOR`
insufficient, the correction path is a staged (or emergency) GGP raise on
the deployed escrow — not a new deployment line. Successor-wallet or
escrow-credit recovery remains reserved for incident-class failures.
Monitoring must alert when measured flush gas approaches the current value
with insufficient margin: production operations alert when measured
worst-case undeployed-wallet flush gas exceeds two-thirds of the current
`FLUSH_GAS_FLOOR` or when the margin falls below the release-manifest SLO,
whichever is stricter ([RSR-GGP].8).
Accepted residual risk: if a gas-schedule change outruns the current floor
while governance quorum is simultaneously lost so no raise can execute, and
a credit's wallet was never deployed, that owed escrow may be unavailable
until quorum or a social successor process outside the old escrow contract
is restored. This risk is bounded by the raise-only emergency path, by
encouraging permissionless pre-deployment of split wallets, and by the
already-deployed best-effort flush path above; it is not solved by hidden
admin sweep power.
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
9. `recoveryId` is `keccak256(abi.encode(ESCROW_RECOVERY_DOMAIN,
   block.chainid, address(escrow), creditKey.revenueClass, creditKey.profileId,
   creditKey.wallet, creditKey.asset, successorWallet, successorProfileId,
   successorRuntimeCodeHash, expectedAmount, recoveryManifest.contentHash,
   executeAfter, reasonHash))`. The `ESCROW_RECOVERY_DOMAIN` string
   preimage and hash are pinned in [RSR-DOMAINS].
10. Execution rechecks status `SCHEDULED`, delay, current owed amount equals
    `expectedAmount`, the credit's stored factory, incident status, successor
    profile/wallet/codehash validity, and whether the recovery manifest claims
    identical or changed economics before moving escrow-held owed funds.

### Sale And Auction Settlement Boundary

Sale and auction mechanics — the English auction state machine with
reserve, minimum bid increments, and anti-snipe extension; Dutch decay and
uniform-clearing rebates; offers and private/direct sales; refund-window
escrow modes; burn-to-mint gates; allowlists; delegated minting; sealed-bid
extension profiles; and the sale adapter conformance profile and registry —
are owned by `docs/stream-sales-and-auctions.md` (ADR 0010 decision D5).
This document does not define auction mechanics; the sketch auction model
formerly in this section is superseded by that spec, which also carries
forward and re-decides the legacy `StreamAuctions` behavioral surface
(increments, anti-snipe, cancellation, no-bid claims). This section defines
only the revenue-side settlement boundary every sale adapter must satisfy.

Requirements [RSR-SETTLEMENT-BOUNDARY]:

1. Settlement of any sale or auction must first mark the sale settled and
   record the winning payer, beneficiary, amount, policy hash, and sale ID,
   then record primary revenue into a verified split wallet or the owed
   escrow, before any external NFT recipient callback executes.
2. Minting to a contract recipient uses the same rule as fixed-price
   primary sales: revenue is recorded before safe recipient callbacks, or
   the token is minted to custody and transferred after settlement effects.
3. Failed split-wallet deposit uses the same owed escrow path as
   fixed-price primary sales. A split-recipient receive hook cannot revert
   settlement.
4. Bid custody, losing-bid pull refunds, cancellation, reserve failure,
   and no-bid expiry live sale-side per `docs/stream-sales-and-auctions.md`
   and must never push value to recipients from the settlement path.
   Refund credits are sale-contract liabilities, are never split-wallet or
   revenue-escrow balances, and remain claimable forever unless a
   separately accepted decommissioning spec handles uneconomic dust.
5. Sale and auction identity is owned by
   `docs/stream-sales-and-auctions.md` [SSA-IDENTITY]; this document does
   not restate those preimages. The pinned mapping rule into the revenue
   layer (ADR 0011 decision R9) is: the `settlementKey` preimage's
   `settlementId` is the [SSA-IDENTITY] `bytes32 saleId` of the sale
   being settled; its `saleNonce` is the adapter-local `saleNonce` bound
   inside that `saleId`; and the [RSR-PAYMENT-INTENT] `saleRef` equals
   `settlementId` exactly. Supplying any divergent sale reference on any
   of the three surfaces is nonconformant.
6. Settlement must reject if the signed policy hash, payer, recipient,
   executor, asset, or amount does not match the sale state and the
   [RSR-SALE-AUTH] authorization.
7. `CUSTODY_SETTLEMENT_TRANSFER` is the named settlement order for paid
   transfer of an already-minted custody-held token (for example a token
   minted to auction custody at auction start and sold at settlement).
   Order: validate the [RSR-SALE-AUTH] authorization and sale state; mark
   settled and debit sale-side custody; resolve the primary assignment and
   materialize any template; deposit to the verified split wallet or
   record owed escrow; emit settlement evidence; and only then transfer
   the token from custody to the recipient. No mint-ledger consumption
   occurs — token identity already exists — and the transfer callback is
   the last external interaction. Sale-side realizations, such as the
   `AUCTION_SETTLEMENT_TRANSFER` order of
   `docs/stream-sales-and-auctions.md` [SSA-ENGLISH], are conformant
   exactly when they preserve this ordering. The custody mint itself
   (minting into sale custody before bidding) is an unpaid custody mint —
   `AUCTION_START_CUSTODY` in the sales spec — with the custody contract
   as both initial recipient and beneficiary; its counter semantics are
   owned by `docs/mint-policy-and-accounting.md` and
   `docs/stream-sales-and-auctions.md`.
8. Until a sale adapter passes the conformance profile in
   `docs/stream-sales-and-auctions.md` and the gates above, that adapter
   is not production-ready. Fixed-price primary sales can enter production
   independently if their native ETH pull-payment path satisfies this
   spec.
9. Escrow-holding sale modes settle their deferred leg under the
   [RSR-SALE-AUTH].5 drift envelope (ADR 0011 decision R6): the
   settlement contract must accept `ALLOW_CURRENT` finalization within
   the buyer's envelope — maximum price, sale reference, finalize-by
   deadline — must emit the observed `policyDrift`, and must not treat
   resolved-policy-hash drift as a terminal failure for those modes.
   After the finalize-by deadline, the permissionless sale-side refund
   path of `docs/stream-sales-and-auctions.md` unlocks the escrowed
   funds under rule 4's refund-liability accounting; no escrow-holding
   mode may leave buyer funds with neither a finalization nor a refund
   exit.

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

### Canonical Royalty Policy Hash

Requirements [RSR-ROYALTY-HASH]:

1. The canonical royalty policy hash for a resolved royalty assignment is:

   ```solidity
   // ROYALTY_POLICY_DOMAIN string preimage and hash: [RSR-DOMAINS]
   bytes32 royaltyAssignmentHash = keccak256(abi.encode(
       keccak256("6529STREAM_ROYALTY_POLICY_V1"),
       uint256(block.chainid),
       address(resolver),
       uint256(collectionId),
       uint256(tokenId),
       bytes32(profileId),
       address(splitWallet),
       uint16(royaltyBps),
       bytes32(assignmentHash)
   ));
   ```

   `collectionId` and `tokenId` are the resolution context (zero where the
   resolved scope binds no token or collection), and `assignmentHash` is
   the canonical per-key assignment hash of the resolved royalty
   assignment computed under
   [Assignment Semantics](#assignment-semantics) with
   `revenueClass = ROYALTY_ERC2981` scope context. Because `royaltyBps` is
   bound here, any bps change — even one that keeps the same profile and
   wallet — changes the royalty policy hash.
2. `probeRoyaltyInfo`, mint-time royalty snapshots, royalty-side signed
   surfaces, and royalty assignment events must use this preimage or a
   later versioned replacement. The `assignmentHash` returned by
   `probeRoyaltyInfo` is this `royaltyAssignmentHash`.
3. The mint-time snapshot hook's expected-hash argument is this
   `royaltyAssignmentHash` of the resolved collection/default assignment;
   the hook must revert on mismatch so royalty economics cannot drift
   between sale authorization and mint (see
   [Mint-Time Royalty Snapshots](#mint-time-royalty-snapshots)).
4. This section is the single normative home for the royalty policy hash
   (ADR 0010 decision D3; GOOD-02 election). ADR 0008 cites it and defines
   no preimage of its own.

### StreamCore ERC-2981 Implementation

Core should not inherit OpenZeppelin `ERC2981` storage. The inherited
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

    (bool hasMappedCollection, uint256 mappedCollectionId,,) =
        tokenCollectionIdentity(tokenId);

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

The production implementation must use capped assembly returndata copying
instead of high-level `bytes memory` decode to avoid unbounded returndata
allocation. The call copies at most 64 bytes and requires
`returndatasize() == 64`.

`mappedCollectionId` and `hasMappedCollection` come from Core's authoritative
token identity read, not from a token ID range heuristic. Core derives
`mappingExists` from live ownership, burned-token audit state, and
prepared-mint state, then passes `mappedCollectionId` and
`hasMappedCollection` into the resolver. For minted, same-transaction allocated,
custody-held, or burned tokens with retained identity, `hasMappedCollection =
true`. For premint or nonexistent tokens without authoritative Core identity,
`hasMappedCollection = false` and `mappedCollectionId = 0`; the resolver falls
back to default assignment or zero. The resolver must not call Core, re-read
token mapping, or infer a collection from token ID arithmetic.
For external diagnostics and satellite reads, the canonical Core read is
`tokenCollectionIdentity(tokenId) -> (mappingExists, collectionId,
collectionSerial, burned)`, with burned tokens returning their retained mapping
and `burned = true`.

If a resolver-backed Core cannot reach the resolver, receives malformed return
data, or receives a zero receiver or zero bps, it should return
`(address(0), 0)` rather than revert. Wallet/code-hash validity is enforced at
assignment time by the resolver; Core's read path validates only cheap return
shape and zero-value conditions. Monitoring must treat fallback-to-zero as an
incident with a defined remediation: gas-margin incidents resolve through the
[RSR-GGP].10 raise chain, and resolver-fault incidents resolve through
pointer governance. Fallback-to-zero is never a permanent state on this Core
line.
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
operators. It is not used by marketplaces, but it is a deployment gate so
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

A resolver-backed Core path must use explicit gas and return-shape limits.

Requirements [RSR-2981-GAS]:

1. Gas and return-shape parameters:

   ```text
   ROYALTY_RESOLVER_GAS_LIMIT   Governed Gas Parameter, genesis planning 50,000
   ROYALTY_RETURN_GAS_BUFFER    Governed Gas Parameter, genesis planning 15,000
   resolver.staticcall{gas: current ROYALTY_RESOLVER_GAS_LIMIT}
   expected return length = 64 bytes
   failure fallback = (address(0), 0)
   ```

2. The parent gas precheck must account for EIP-150's 63/64 gas forwarding
   rule so a caller cannot pass the precheck while the resolver receives
   less than the current `ROYALTY_RESOLVER_GAS_LIMIT`, and the precheck
   must read the current GGP values, not compiled-in constants. CI must
   test calls just below, at, and above the precheck threshold and prove
   ordinary all-cold resolver reads do not fallback-to-zero because of
   under-forwarded gas.
3. `ROYALTY_RESOLVER_GAS_LIMIT` and `ROYALTY_RETURN_GAS_BUFFER` are
   Governed Gas Parameters hosted in `StreamCore` storage under [RSR-GGP]
   (ADR 0010 decision D1): staged raise with a raise-only emergency path,
   probe-gated lower, immutable floors, change events, and manifest
   recording. They are not deploy-time immutables and there is no
   unreviewed runtime setter: every change flows through the GGP
   governance classes, is evented, and never changes economic or artwork
   identity because GGP values are excluded from every economic preimage
   ([RSR-GGP].3). Frozen and finalized collections keep answering
   marketplace reads under any future gas schedule because the cap can
   always be raised; a gas repricing can therefore never permanently zero
   royalty disclosure for this Core line.
4. The health probe for both parameters is `probeRoyaltyInfo` run against
   representative default, collection, token, premint, burned, and
   malformed cases; a lower executes only after a recorded passing probe
   run at the proposed value ([RSR-GGP].5).
5. The resolver must keep the default-scope royalty assignment readable
   from a single packed storage slot so the deepest default-fallback
   answer stays servable at the immutable floor even if intermediate-scope
   reads outgrow the current value between repricing and the corrective
   raise.

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
Static analysis must fail CI if `royaltyReceiverAndBps` or any internal
function reachable only from that path contains `CALL`, `DELEGATECALL`,
`STATICCALL`, `CREATE`, or `CREATE2` opcodes. The Core staticcall gas cap is
defense in depth, not the primary proof that the deployed resolver is pure.

Worst-case cold-access gas must be budgeted before deployment. Target v1
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
token, collection, and default fallback cases, and the genesis cap must
satisfy the [RSR-GGP].9 sizing gates: genesis `ROYALTY_RESOLVER_GAS_LIMIT`
at least four times the deepest measured all-cold resolver path, immutable
floor at least twice that measured path. If the deepest cold path exceeds
35,000 gas inside the resolver on the target compiler/EVM, the
implementation must compress assignment storage, set a higher genesis cap
that preserves the required multiple, or reduce resolver work. It must not
deploy with a cap that causes ordinary cold reads to silently return
`(address(0), 0)`. After deployment, the remediation order for margin decay
is the [RSR-GGP].10 chain: staged or emergency GGP raise first,
compressed-storage successor resolver second, successor Core line never
required for gas alone.

Production Core must use capped assembly returndata handling, not a
high-level `bytes memory` decode that can allocate unbounded returndata. The
call copies at most 64 bytes, requires `returndatasize() == 64`, and returns
`(address(0), 0)` for malformed size. Core uses checked arithmetic or
`mulDiv`-style math for `salePrice * royaltyBps / 10_000` after decoding bps
from the resolver and does not rely on overflow reverts for normal fallback
behavior.

`royaltyInfo()` must not require the token to be minted. In the v1
resolver-backed design, token IDs for which `tokenCollectionIdentity` reports
`mappingExists == false` always fall back to the default assignment or zero.
Collection-scope
royalty resolution requires Core to pass both
`hasMappedCollection = tokenCollectionIdentity(tokenId).mappingExists` and
`mappedCollectionId = tokenCollectionIdentity(tokenId).collectionId`. Core must
not infer a collection receiver for unmapped tokens; an exact token ID codec
and storage-free collection existence gate are excluded from protocol v1 and
would require a successor Core line.
The mapping used by `royaltyInfo()` is written only when Core has an
authoritative token assignment, such as mint, same-transaction allocation, or a
custody-held token path. Burned tokens retain their last stored mapping for
royalty disclosure history, with `tokenCollectionIdentity` deriving
`mappingExists = true` from burned audit state after burn. `royaltyInfo()`
therefore still resolves token,
collection, then default scope for burned tokens, while `tokenURI()` may revert
under normal ERC-721 metadata semantics. Protocol v1 does not define
standalone premint reservations; premint or nonexistent tokens without the
Core mapping are unmapped for royalty resolution.

This is still disclosure. Royalty enforcement is excluded from protocol v1;
marketplaces can ignore the royalty. That exclusion is permanent for this
Core line — ERC-721 transfer carries no validator hook, so no later module
can add enforcement, and a successor Core line is the only enforcement path
(ADR 0010 decision D9.2). Artist-facing materials must present
disclosure-only royalties as a deliberate, permanent term, never as a
temporary limitation, with the recorded onboarding acknowledgment of
[RSR-MARKETPLACE-ROYALTY].3.

Marketplaces may cache receiver or bps results, may ignore token-varying
receivers, or may only honor a default receiver. The production contract
still must expose Core-native ERC-2981 because it is the most broadly
portable royalty disclosure surface.
There is no Core-local fixed receiver fallback in the v1 architecture. If
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

Canonical v1 primary assignment hashes:

```solidity
// Every *_DOMAIN constant below has its string preimage and hash
// pinned in [RSR-DOMAINS].
bytes32 resolverContextHash = keccak256(abi.encode(
    ASSIGNMENT_RESOLVER_CONTEXT_DOMAIN,
    address(resolver),
    address(splitFactory),
    address(assetPolicyRegistry),
    bytes32(splitWalletRuntimeCodeHash)
));

bytes32 scopeContextHash = keccak256(abi.encode(
    ASSIGNMENT_SCOPE_CONTEXT_DOMAIN,
    bytes32(revenueClass),
    uint8(scope),
    uint256(scopeId),
    uint8(assignmentType)
));

bytes32 profileContextHash = assignmentType == ASSIGNMENT_TYPE_PROFILE
    ? keccak256(abi.encode(
        ASSIGNMENT_PROFILE_CONTEXT_DOMAIN,
        address(splitWallet),
        bytes32(profileEntriesHash),
        bytes32(profileMetadataURIHash)
    ))
    : bytes32(0);

bytes32 templateContextHash = assignmentType == ASSIGNMENT_TYPE_TEMPLATE
    ? keccak256(abi.encode(
        ASSIGNMENT_TEMPLATE_CONTEXT_DOMAIN,
        bytes32(templateEntriesHash),
        bytes32(templateMetadataURIHash)
    ))
    : bytes32(0);

bytes32 pointerContextHash = keccak256(abi.encode(
    ASSIGNMENT_POINTER_CONTEXT_DOMAIN,
    bytes32(profileId),
    bytes32(profileContextHash),
    bytes32(templateId),
    bytes32(templateContextHash)
));

bytes32 assignmentHash = keccak256(abi.encode(
    ASSIGNMENT_DOMAIN,
    uint256(block.chainid),
    bytes32(resolverContextHash),
    bytes32(scopeContextHash),
    bytes32(pointerContextHash),
    bytes32(policyHash),
    bool(frozen)
));

// PRIMARY_POLICY_DOMAIN string preimage and hash: [RSR-DOMAINS]
bytes32 resolvedPrimaryPolicyHash = keccak256(abi.encode(
    keccak256("6529STREAM_PRIMARY_POLICY_V1"),
    uint256(block.chainid),
    address(resolver),
    bytes32(revenueClass),
    uint256(collectionId),
    uint256(tokenId),
    bytes32(templateId),
    bytes32(profileId),
    address(splitWallet),
    bytes32(assignmentHash)
));
```

`expectedPrimaryPolicyHash`, primary resolver probes, and assignment events must
all use these preimages or a later versioned replacement.
Event-only display fields, human labels, and mutable URIs are excluded from
economic authority unless their hashes are explicitly included above.

The `assignmentHash` family above is class-generic: it computes the per-key
assignment hash for every revenue class, including `ROYALTY_ERC2981`,
because `scopeContextHash` binds the actual `revenueClass`. The `PRIMARY`
token in the domain strings is historical naming, not a scope restriction.
Royalty assignments always use `ASSIGNMENT_TYPE_PROFILE` (zero
`templateId`/`templateContextHash`) and substitute a royalty pointer
context that additionally binds the bps economics, so a bps-only change
always changes the per-key hash — and therefore invalidates outstanding
artist economics consents signed over it
([`docs/stream-artist-authority.md`](stream-artist-authority.md) [AA-ECON]):

```solidity
// ROYALTY_ASSIGNMENT_POINTER_CONTEXT_DOMAIN string preimage and
// hash: [RSR-DOMAINS]
bytes32 royaltyPointerContextHash = keccak256(abi.encode(
    ROYALTY_ASSIGNMENT_POINTER_CONTEXT_DOMAIN,
    bytes32(profileId),
    bytes32(profileContextHash),
    uint16(royaltyBps)
));
// Royalty-class keys use royaltyPointerContextHash as the
// pointerContextHash input of the assignmentHash preimage above.
```

The full resolution context (collection, token) and the per-key hash are
bound together one level up by the canonical `royaltyAssignmentHash`
([RSR-ROYALTY-HASH]). This section is the single normative home for the
assignment-hash and resolved-policy-hash preimages; ADR 0008 cites it
(GOOD-02 election, ADR 0010 decision D3).

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
inherited frozen, global frozen, and permanent states, plus the
advertised-loosening marker recorded at assignment time — the only state
eligible for the one loosening rule in the spec set, owned by
`docs/stream-long-term-architecture.md` [LTA-FREEZE] rule 1.
Frozen assignments cannot be changed or cleared.

Primary assignments may resolve to a fixed profile or a primary split template.
Template assignments materialize into fixed profiles during settlement; royalty
assignments always resolve to fixed profiles.

Requirements [RSR-STAGED-GOVERNANCE]:

1. The following actions must use the ADR 0004 staged action-ID model with
   timelock or two-step staging: default-scope assignment changes, default
   royalty changes, global freezes, resolver pointer replacement,
   asset-policy status transitions away from `ACTIVE`
   ([RSR-ASSET-POLICY].7), Governed Gas Parameter lowers ([RSR-GGP].2),
   and escrow recovery scheduling.
2. Irreversible freezes — permanent global freezes and any
   `permanentFreeze` — must additionally pass through the ADR 0004
   `TERMINAL_FREEZE` veto/guardian delay class per
   `docs/stream-long-term-architecture.md` [LTA-FREEZE] rule 4, so one
   compromised key cannot instantly and permanently freeze economics
   (ADR 0010 decision D8.9). A permanent global freeze is terminal and must
   be used only when that irreversibility is part of the product promise.
3. Loosening any non-permanent freeze is governed exclusively by the
   one-way freeze home, `docs/stream-long-term-architecture.md`
   [LTA-FREEZE] rule 1 (advertised at assignment time, ADR 0004
   `DELAYED_LOOSENING` class, before/after policy hashes in the execution
   event). This spec defines no loosening path of its own.
4. For artist-bound collections, economically material changes to the
   artist's assignments additionally require artist co-signature under
   [RSR-ARTIST-ECONOMICS].

Freezes use `freezeMode`: `EXACT` blocks only the exact key, while `INHERITED`
blocks lower-scope set and clear operations under the frozen ancestor. In
protocol v1, applying an `INHERITED` freeze with any mutable lower-scope
override under that ancestor must revert. A separately accepted resolver spec
may add a bounded batch operation that freezes descendants in the same
governance action, but v1 must not pretend it can enumerate arbitrary
token-level descendants.
The resolver must maintain O(1) descendant override counters or dirty bits per
`(revenueClass, scope, scopeId)` so inherited-freeze checks do not require
enumerating token-level assignments. Counter updates are part of set and clear:
setting a collection override increments the default ancestor counter; setting a
token override increments its authoritative collection ancestor and the default
ancestor; clearing decrements the same ancestors. Applying an inherited freeze
with existing lower overrides reverts in protocol v1.

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
collection, and token scope for the affected revenue class. While it is in
effect it blocks set, clear, and loosening operations for any assignment in
that revenue class, including creation of new assignments after the freeze;
whether the global freeze itself can ever loosen is governed solely by
`docs/stream-long-term-architecture.md` [LTA-FREEZE] rule 1.
A deployment-wide global freeze blocks both all existing keys and the
creation of entirely new revenue classes (ADR 0009 decision 8);
`freezeAllRevenue()` must enforce both, because a global freeze bypassable
by minting a new class is not a credible freeze.

## Artist Economics Binding

The artist identity model — proposal and acceptance, consent modes
(`ARTIST_SIGNED_POLICY`, `ARTIST_DELEGATED`, `PLATFORM_WORKS`),
collaborator lists, key lifecycle, sanction, and onchain signature
verification — is owned by [`docs/stream-artist-authority.md`](stream-artist-authority.md) (ADR 0010
decision D2). This section defines what the revenue layer must enforce for
collections with a bound artist, so artist economics never rest on platform
goodwill alone (ADR 0010 decision D2.5).

Requirements [RSR-ARTIST-ECONOMICS]:

1. An artist-bound collection is one whose artist binding has been accepted
   under [`docs/stream-artist-authority.md`](stream-artist-authority.md) [AA-BINDING]. Collections
   without a bound artist carry the immutable `PLATFORM_WORKS`
   declaration; this section does not apply to them.
2. Setting, clearing, or replacing a primary or royalty assignment at
   collection or token scope for an artist-bound collection requires a
   verified `StreamArtistEconomicsConsent` over the exact resulting
   per-key `assignmentHash`, satisfying the collaborator policy: the
   resolver must call the artist registry's `requireEconomicsConsent`
   before applying the change ([`docs/stream-artist-authority.md`](stream-artist-authority.md)
   [AA-ECON] rule 3, which owns the consent payload and verification).
   Because royalty-class keys bind `royaltyBps` in their pointer context
   ([Assignment Semantics](#assignment-semantics)), a bps-only change also
   requires fresh consent. Governance staging remains
   ([RSR-STAGED-GOVERNANCE]); artist consent is additive, never a
   replacement for it, and governance cannot repoint an artist-bound
   collection's economics unilaterally.
3. Public mint of an artist-bound collection additionally requires
   recorded economics consent for the active primary revenue class
   assignment and the `ROYALTY_ERC2981` assignment that will govern its
   tokens ([`docs/stream-artist-authority.md`](stream-artist-authority.md) [AA-ECON] rule 4 and
   [AA-CONSENT]). Sale adapters and the resolver must refuse to open
   public mint without those records: economics are artist-ratified
   before the first sale, not after.
4. The artist authority may unilaterally freeze the royalty assignment for
   their own collection: a verified `StreamArtistRoyaltyFreeze` is
   relayable by any caller, and the resolver must verify
   `isRoyaltyFreezeAuthorized` and apply an `EXACT` freeze on the
   `ROYALTY_ERC2981` collection-scope assignment whose current hash equals
   the authorized `expectedAssignmentHash`. The right is freeze-only —
   it cannot change the receiver, cannot unfreeze, and cannot touch other
   collections ([`docs/stream-artist-authority.md`](stream-artist-authority.md) [AA-ECON] rule 5).
5. The collection's royalty policy mode (`ROYALTY_SNAPSHOT_AT_MINT`
   versus `ROYALTY_LIVE_COLLECTION`) must be configured before the rule 3
   consents are recorded, so the choice between live and snapshotted
   economics is artist-visible and artist-ratified for artist-bound
   collections, not an operator-only configuration.

## Estate And Succession For Entitled Accounts

Split entitlements bind addresses forever: profiles are immutable, and the
release ledger is keyed by the entitled account. Over a 50+ year horizon,
key loss and death are certainties, so the succession posture must be
explicit (ADR 0010 decision D2.2). Artist identity succession — key
rotation, successor designation, estate directives, dormancy — is owned by
[`docs/stream-artist-authority.md`](stream-artist-authority.md); this section covers the revenue-side
consequences for any entitled account.

Requirements [RSR-ESTATE]:

1. Operator tooling and profile-creation UX must default to recommending
   rotatable smart-contract accounts (Safe-class, ERC-1271-capable under
   [RSR-1271]) for artist, estate, museum, and institutional entries, and
   must record in the profile metadata manifest whether each entry is a
   rotatable account. An EOA entry is allowed but must be an explicit,
   recorded choice.
2. Future receipts are repointable: the estate flow for a lost or
   deceased recipient is a new split profile (successor entries) plus a
   staged assignment repoint for future receipts, subject to freeze state
   and, for artist-bound collections, to the artist authority spec's
   successor verification. For artists, the accepted successor or estate
   authority inherits the [RSR-ARTIST-ECONOMICS] co-signature and freeze
   rights.
3. Funds already attributable to an entitled account in existing wallets
   follow the account: a rotatable contract account continues to release
   through self-execution or rotated keys ([RSR-1271].5). For an EOA whose
   key is lost, that account's entitlements in existing wallets are
   permanently unclaimable — anyone may still push them to the dead
   address via `release(asset, account, account)`, but no authority,
   including governance, can redirect them. This irrecoverability is a
   deliberate consequence of immutable profiles and the no-sweep rule.
4. Disclosure: recipient onboarding and the release manifest must state
   rule 3 plainly so artists and institutions consent to the EOA risk
   knowingly, and must document the succession recipe (successor profile
   plus repoint for future receipts; smart-account rotation for existing
   entitlements).
5. Frozen assignments interact with succession as frozen: a frozen
   assignment's future receipts cannot be repointed to a successor
   profile. Products that promise frozen economics to recipients with
   EOA entries must disclose that combination as doubly irrecoverable.

## Canonical v1 Interfaces

Implementation PRs should converge on selector-stable ABI targets for
the payment surface:

```solidity
interface IStreamSplitFactory {
    function assetPolicyRegistry() external view returns (IStreamAssetPolicyRegistry);
    function walletFor(bytes32 profileId) external view returns (address);
    function deployWallet(bytes32 profileId) external returns (address wallet);
    function profileExists(bytes32 profileId) external view returns (bool);
    function profileEntriesHash(bytes32 profileId) external view returns (bytes32);
    function splitWalletRuntimeCodeHash() external view returns (bytes32);
    // Governed Gas Parameter store for the wallet line ([RSR-GGP]).
    function gasParameter(bytes32 parameterId) external view returns (uint256);
    function gasParameterFloor(bytes32 parameterId) external view returns (uint256);
}

interface IStreamSplitWallet {
    function profileId() external view returns (bytes32);
    function assetPolicyRegistry() external view returns (address);
    function release(address asset, address account, address payable recipient)
        external
        returns (uint256);
    function releasable(address asset, address account) external view returns (uint256);
    function observedReceived(address asset) external view returns (uint256);
    function accountReleased(address asset, address account) external view returns (uint256);
    function totalReleased(address asset) external view returns (uint256);
    function syncAsset(address asset) external returns (uint256);
    // Consumes the caller's own (account, nonce) pair
    // ([RSR-RELEASE-AUTH].5).
    function revokeReleaseAuthorization(bytes32 nonce) external;
    // Explicit-address replay view keyed by (account, nonce); never
    // caller-relative ([RSR-RELEASE-AUTH].3).
    function isReleaseAuthorizationNonceUsed(address account, bytes32 nonce)
        external
        view
        returns (bool);
}

interface IStreamAssetPolicyRegistry {
    function assetStatus(address asset) external view returns (uint8);
    function assetPolicyHash(address asset) external view returns (bytes32);
    function assetPolicyEffectiveAt(address asset) external view returns (uint64);
    function assetReleaseGraceUntil(address asset) external view returns (uint64);
    function assetPolicy(address asset)
        external
        view
        returns (
            uint8 status,
            bytes32 policyHash,
            uint64 effectiveAt,
            uint64 releaseGraceUntil
        );
    function isAssetActive(address asset) external view returns (bool);
    // Executes a staged asset-policy action ([RSR-ASSET-POLICY].7).
    function setAssetStatus(
        address asset,
        uint8 status,
        bytes32 policyHash,
        uint64 releaseGraceUntil
    ) external;
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

The implemented split and primary-settlement signatures are pinned through
`IStreamSplitFactory`, `IStreamSplitWallet`, `IStreamAssetPolicyRegistry`,
`IStreamRevenueResolver`, and `IStreamPrimarySaleSettlement` in the release
artifact surface. Later royalty, escrow, and fixed-price or auction adapter
interfaces must remain selector-stable when they are promoted from this target
sketch into code. The interfaces above are intentionally value-type heavy; rich
display metadata stays in manifests and events.

## Claim Aggregation Periphery

Recipients accumulate entitlements across many wallets: every distinct
concrete recipient set materializes its own immutable split wallet, and
economically identical concrete splits from different templates resolve to
different wallets. Per-wallet, per-asset pull claims are the correct
invariant, but claim friction must not be left to unspecified frontends
(ADR 0010 decision D10.6).

Requirements [RSR-CLAIM-ROUTER]:

1. The genesis deployment set must include a permissionless, stateless
   claim-router satellite:

   ```solidity
   interface IStreamClaimRouter {
       struct ClaimCall {
           address wallet;
           address asset;
           address account;
       }

       function claimMany(
           ClaimCall[] calldata claims,
           bool continueOnFailure
       ) external returns (uint256[] memory releasedAmounts);

       function syncAndClaimMany(
           ClaimCall[] calldata claims,
           bool continueOnFailure
       ) external returns (uint256[] memory releasedAmounts);
   }
   ```

2. The router preserves pull semantics exactly: it holds no funds, takes no
   approvals, has no owner, and may call only
   `wallet.release(asset, account, account)` (release to the entitled
   account itself) and `wallet.syncAsset(asset)`. Alternate-recipient
   release stays wallet-level under [RSR-RELEASE-AUTH] and is deliberately
   not routable.
3. `continueOnFailure = false` reverts the whole batch on the first failed
   item; `continueOnFailure = true` records a zero released amount for a
   failed item and continues, so one paused asset or unsynced wallet
   cannot block a recipient's other claims. Per-item failures must be
   evented with wallet, asset, account, and a bounded failure reason.
4. Batch size must be bounded by calldata and the block gas limit only;
   the router adds no per-item storage.
5. Entitlement discovery is an indexer requirement: recipient tooling must
   enumerate a recipient's wallets from `SplitProfileCreated`/
   `SplitProfileEntry` events and ERC-20 `Transfer` logs, then feed
   `claimMany`. Recipient UX conformance gates on one-transaction
   aggregated claiming across at least 20 wallets.
6. Recipient-experience gate (ADR 0011 decision R12). Deployment gates on
   a rehearsed recipient claim flow recorded as release evidence:
   starting from events alone, discover every wallet where a test
   recipient is entitled, sync at least one directly received ERC-20
   through `syncAsset`, and claim across at least 20 wallets in one
   `claimMany` transaction. The funding/endowment manifest required by
   ADR 0010 decision D4.8 must name the party operating the recipient
   entitlement indexer and its coverage horizon. An unrehearsed claim
   flow or an unnamed indexer operator is nonconformant; the matching
   gate lives in `docs/launch-conformance-matrix.md`.

## Events

This section is the single normative home for the revenue event schemas
(ADR 0010 decision D10.6). The event surface is indexer-first and applies
the genesis-wide one-event-per-fact policy: optional mirror events are
banned uniformly at genesis across every subsystem, and that ban is owned
by the conformance-matrix event policy in
`docs/launch-conformance-matrix.md` (ADR 0011 decision R12), not stated
here as a revenue-local rule. Accordingly v1 defines no optional mirror
events, and a duplicated name, a second event family, or an
implementation-optional mirror for the same fact is a defect.
Every non-standard event carries `uint16 schemaVersion`; only the
standard-signature events named in the conformance-matrix exemption list
(ERC-721, ERC-4906, ERC-7572 `ContractURIUpdated()`, and peers) omit it.

Requirements [RSR-EVENTS]:

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
    uint16 indexed index,
    address indexed account,
    uint16 schemaVersion,
    uint32 sharePpm,
    bytes32 labelId
);

event SplitWalletDeployed(
    bytes32 indexed profileId,
    address indexed wallet,
    uint16 indexed walletVersion,
    uint16 schemaVersion,
    bytes32 initCodeHash,
    bytes32 runtimeCodeHash
);

event SplitWalletDiscovered(
    bytes32 indexed profileId,
    address indexed wallet,
    uint16 indexed walletVersion,
    uint16 schemaVersion,
    bytes32 initCodeHash,
    bytes32 runtimeCodeHash
);

event AssetObservationInitialized(
    bytes32 indexed profileId,
    address indexed asset,
    uint16 schemaVersion,
    uint256 observedReceived
);

event AssetSynced(
    bytes32 indexed profileId,
    address indexed asset,
    uint16 schemaVersion,
    uint256 previousObservedReceived,
    uint256 observedReceived
);

event NativeReleased(
    bytes32 indexed profileId,
    address indexed account,
    address indexed recipient,
    uint16 schemaVersion,
    uint256 amount,
    uint256 totalReleased,
    uint256 observedReceived
);

event ERC20Released(
    bytes32 indexed profileId,
    address indexed asset,
    address indexed account,
    uint16 schemaVersion,
    address recipient,
    uint256 amount,
    uint256 totalReleased,
    uint256 observedReceived
);

event ReleaseAuthorizationRevoked(
    address indexed account,
    bytes32 indexed nonce,
    uint16 schemaVersion
);

event AssetPolicyUpdated(
    address indexed asset,
    uint8 indexed previousStatus,
    uint8 indexed status,
    uint16 schemaVersion,
    bytes32 previousPolicyHash,
    bytes32 policyHash,
    uint64 effectiveAt,
    uint64 releaseGraceUntil,
    bytes32 actionId,
    address admin
);

event RevenueAssignmentSet(
    bytes32 indexed revenueClass,
    uint8 indexed scope,
    uint256 indexed scopeId,
    uint16 schemaVersion,
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
    uint16 schemaVersion,
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
    uint16 schemaVersion,
    bool permanent,
    uint8 freezeMode
);

event PrimaryRevenueSettled(
    bytes32 indexed settlementKey,
    bytes32 indexed revenueClass,
    bytes32 indexed profileId,
    uint16 schemaVersion,
    address wallet,
    address asset,
    address payer,
    uint256 amount,
    bytes32 saleContextHash,
    bool policyDrift,
    uint8 assignmentType
);

event PrimaryRevenueSettlementContext(
    bytes32 indexed settlementKey,
    bytes32 indexed revenueClass,
    bytes32 indexed profileId,
    uint16 schemaVersion,
    address settlementCaller,
    bytes32 settlementId,
    uint8 policyMode,
    uint256 collectionId,
    uint256 tokenId,
    uint256 saleNonce,
    address poster,
    address beneficiary,
    bytes32 templateId
);

event PrimaryRevenueSettlementPolicy(
    bytes32 indexed settlementKey,
    bytes32 indexed revenueClass,
    bytes32 indexed profileId,
    uint16 schemaVersion,
    bytes32 expectedPrimaryPolicyHash,
    bytes32 resolvedPrimaryPolicyHash,
    bytes32 resolvedAssignmentHash,
    bytes32 templateId
);

event PaymentIntentConsumed(
    address indexed payer,
    bytes32 indexed saleRef,
    bytes32 indexed nonce,
    uint16 schemaVersion,
    address asset,
    uint256 amount
);

event PaymentIntentRevoked(
    address indexed payer,
    bytes32 indexed nonce,
    uint16 schemaVersion
);

event PrimaryTemplateMaterialized(
    bytes32 indexed templateId,
    bytes32 indexed profileId,
    address indexed wallet,
    uint16 schemaVersion,
    bytes32 entriesHash,
    bytes32 metadataURIHash,
    address salePoster
);

event EscrowCreditCreated(
    bytes32 indexed revenueClass,
    bytes32 indexed profileId,
    address indexed wallet,
    uint16 schemaVersion,
    address asset,
    uint256 amount,
    uint256 totalOwed,
    bytes32 escrowRuntimeCodeHash
);

event EscrowFlushed(
    bytes32 indexed revenueClass,
    bytes32 indexed profileId,
    address indexed wallet,
    uint16 schemaVersion,
    address asset,
    uint256 amount,
    uint256 remainingOwed
);

event WalletCodeHashApprovalSet(
    bytes32 indexed runtimeCodeHash,
    address indexed actor,
    uint16 schemaVersion,
    uint8 state
);

event GlobalRevenueFreezeSet(
    bytes32 indexed revenueClass,
    address indexed actor,
    uint16 schemaVersion,
    bool permanent,
    uint8 freezeMode
);
```

1. Each event has at most three indexed fields, and the indexed fields
   shown above are the normative v1 allocation. Changing an indexed field
   after deployment is an indexer-breaking event schema change and
   requires a new event name or a new accepted ADR. Implementations must
   not "optimize" event indexing after downstream tooling has been built.
2. Superseded event families from earlier drafts — `SplitReleased`,
   `SplitAssetObserved`, `AssetApprovalSet`, `AssetMarkedUnsupported`, the
   four-field `AssetObservationInitialized` variant, and ADR 0008's
   `PrimaryRevenueDeposited` sketch — are removed, not optional: release
   facts are `NativeReleased`/`ERC20Released`, observation facts are
   `AssetObservationInitialized`/`AssetSynced`, asset-policy facts are
   `AssetPolicyUpdated`, and settlement facts are the
   `PrimaryRevenueSettled` family.
3. Fields that are not indexed must still be present where needed for
   wallets, indexers, operator tools, and release evidence to reconstruct
   policy. The intended escrow query path is to index escrow credit/flush
   events by `revenueClass`, `profileId`, and `wallet`; `asset`, amount,
   and remaining owed balance remain present as unindexed event data.
   Indexers that need asset-first lookup maintain a secondary index from
   the full event stream.
4. Profile creation must emit `SplitProfileCreated`, then entries in
   canonical index order, then `SplitWalletDeployed` if deployment happens
   in the same transaction.
5. Sale identity in settlement events follows the
   [RSR-SETTLEMENT-BOUNDARY].5 mapping rule (ADR 0011 decision R9):
   `settlementId` is the sales-spec `saleId` and `saleNonce` is that
   identity's adapter-local nonce. This document defines no second
   sale-identity vocabulary. `beneficiary` is the token recipient.
   Sale-kind discriminators and sale-side event schemas are owned by
   `docs/stream-sales-and-auctions.md`; the v1 `saleContextHash` preimage
   deliberately binds no `saleKind`.
6. Governed Gas Parameter changes emit the canonical GGP change event
   defined in the model home ([RSR-GGP].4); this document defines no
   duplicate event for them.

## Revenue Domain Constants And Typehashes

Requirements [RSR-DOMAINS]:

1. This table is the single normative home for every revenue-layer hash
   domain and EIP-712 typehash (ADR 0010 decisions D3.1 and D3.5). The
   domain-constants table in `docs/launch-v1-target-architecture.md`
   carries a checker-verified mirror, never a second home. CI must include
   a checked test that recomputes every hash below from its string
   preimage and fails on drift between Solidity constants, this table, and
   release artifacts. Every hash value is pinned from its string preimage
   and recomputed by CI.

| Constant name | String preimage | Hash value | Owner | Schema version | Inputs |
| --- | --- | --- | --- | --- | --- |
| `PROFILE_DOMAIN` | `6529STREAM_SPLIT_PROFILE_V1` | `0xb53022be9545b47b00a7734af5a745b97c90c992af3e767f478a185fc8f16819` | `StreamSplitFactory` | `1` | see [Split Profile Model](#split-profile-model) |
| `PRIMARY_TEMPLATE_DOMAIN` | `6529STREAM_PRIMARY_TEMPLATE_V1` | `0x1ebb9a3ca8927ebbb825122e47537ab869c305e8890801a106585bb8c22b3418` | `StreamRevenueResolver` | `1` | see [Primary Sales](#primary-sales) |
| `MATERIALIZED_PRIMARY_PROFILE_METADATA_DOMAIN` | `6529STREAM_MATERIALIZED_PRIMARY_PROFILE_METADATA_V1` | `0x822635189d2b2692303c74e15626423b71b5c9b37ec5edc48509fb84c3deb16c` | `StreamRevenueResolver` | `1` | see [Primary Sales](#primary-sales) |
| `SETTLEMENT_KEY_DOMAIN` | `6529STREAM_PRIMARY_SETTLEMENT_KEY_V1` | `0x4945dcd8f47145aa24f651df85cfa03bab9d532e51bf130ada9ed9b6426676af` | `StreamPrimarySaleSettlement` | `1` | see [Primary Sales](#primary-sales) |
| `SALE_CONTEXT_DOMAIN` | `6529STREAM_PRIMARY_SALE_CONTEXT_V1` | `0x0cd71db86a370c54e870584c8b64e50ed454640a3e0a81601d3db439a5c27de4` | `StreamPrimarySaleSettlement` | `1` | see [Primary Sales](#primary-sales) |
| `ASSIGNMENT_RESOLVER_CONTEXT_DOMAIN` | `6529STREAM_PRIMARY_ASSIGNMENT_RESOLVER_CONTEXT_V1` | `0xa691283227162c15f9cd2977f1e5995b03b315a3da9086cc469559e3d2e0889b` | `StreamRevenueResolver` | `1` | see [Assignment Semantics](#assignment-semantics) |
| `ASSIGNMENT_SCOPE_CONTEXT_DOMAIN` | `6529STREAM_PRIMARY_ASSIGNMENT_SCOPE_CONTEXT_V1` | `0x607a80155d92fe41598bff2f18342fe5510a5d77533ae17b87774f1a511ea1ba` | `StreamRevenueResolver` | `1` | see [Assignment Semantics](#assignment-semantics) |
| `ASSIGNMENT_PROFILE_CONTEXT_DOMAIN` | `6529STREAM_PRIMARY_ASSIGNMENT_PROFILE_CONTEXT_V1` | `0xbad938700010817dc9392e428003b03d8d16eaf6b5e0bf35dc03f60ec5eba4a1` | `StreamRevenueResolver` | `1` | see [Assignment Semantics](#assignment-semantics) |
| `ASSIGNMENT_TEMPLATE_CONTEXT_DOMAIN` | `6529STREAM_PRIMARY_ASSIGNMENT_TEMPLATE_CONTEXT_V1` | `0x6f884400dcd82040221802f0143cae9405afe344a8471b8e4be6c57e87af3443` | `StreamRevenueResolver` | `1` | see [Assignment Semantics](#assignment-semantics) |
| `ASSIGNMENT_POINTER_CONTEXT_DOMAIN` | `6529STREAM_PRIMARY_ASSIGNMENT_POINTER_CONTEXT_V1` | `0xc96172afc4e32013f5189d2ac0fb5758ee908ce97051d18f5043370a090a0b97` | `StreamRevenueResolver` | `1` | see [Assignment Semantics](#assignment-semantics) |
| `ROYALTY_ASSIGNMENT_POINTER_CONTEXT_DOMAIN` | `6529STREAM_ROYALTY_ASSIGNMENT_POINTER_CONTEXT_V1` | `0xe02b9a1db06245707414f3be94c4005d9332ede9187a9fe5baacf54853ab4ba0` | `StreamRevenueResolver` | `1` | see [Assignment Semantics](#assignment-semantics) |
| `ASSIGNMENT_DOMAIN` | `6529STREAM_PRIMARY_ASSIGNMENT_V1` | `0x3d35bd72bf32163018d9b660465fde3bf2bc092b1fb09047dd0621fc6b8d7164` | `StreamRevenueResolver` | `1` | see [Assignment Semantics](#assignment-semantics) |
| `PRIMARY_POLICY_DOMAIN` | `6529STREAM_PRIMARY_POLICY_V1` | 0x53c5c8e8dcd97f4f6a66557a6ede68c0798afd999c1cce5807f27d151fb50f12 | `StreamRevenueResolver` | `1` | see [Assignment Semantics](#assignment-semantics) |
| `ROYALTY_POLICY_DOMAIN` | `6529STREAM_ROYALTY_POLICY_V1` | 0x672cda40f3f95b129db3b9262cfb581cbe26ea0e95cb09b958ca58ebf62ba54a | `StreamRevenueResolver` | `1` | see [Canonical Royalty Policy Hash](#canonical-royalty-policy-hash) |
| `ESCROW_RECOVERY_DOMAIN` | `6529STREAM_ESCROW_RECOVERY_V1` | 0xd2477116ef00eff9b80dc97ae00c04faec607b7609301cced9041de52f32243c | revenue escrow | `1` | see [Primary Sales](#primary-sales) escrow recovery rule 9 |
| `RELEASE_AUTHORIZATION_TYPEHASH` | struct type string pinned in [RSR-RELEASE-AUTH].2 | `0xfc0465fe58ded163aac5c6c38a2171d353d941f9fbc8a1af61e5c309f87f680c` | `StreamSplitWallet` | `1` | see [RSR-RELEASE-AUTH].2 |
| `PAYMENT_INTENT_TYPEHASH` | struct type string pinned in [RSR-PAYMENT-INTENT].2 | `0x72c99e6f6f9e2422510a5dd5c2dc2f9ffd83c776670a8de4ffab990e45f825cd` | ERC-20 settlement verifier | `1` | see [RSR-PAYMENT-INTENT].2 |
| `GGP_ERC_1271_GAS_LIMIT` | `6529STREAM_GGP_ERC_1271_GAS_LIMIT` | `0xa0c8ff821dc961fbadc34e975a6ca4d3e499b23388ea86883bae7cd5a1d84157` | split factory parameter store | `1` | `gasParameter`/`gasParameterFloor` key ([RSR-GGP]) |
| `GGP_ASSET_POLICY_GAS_LIMIT` | `6529STREAM_GGP_ASSET_POLICY_GAS_LIMIT` | `0xbfc1f824948b8dc9573791fa40eeb403e7322af41d0967f90518dbbb531bf648` | split factory parameter store | `1` | `gasParameter`/`gasParameterFloor` key ([RSR-GGP]) |
| `GGP_ROYALTY_RESOLVER_GAS_LIMIT` | `6529STREAM_GGP_ROYALTY_RESOLVER_GAS_LIMIT` | `0x9bae92ab1dd0c5535c65125ea4ee7cff3d55fc31fc2555096c2b5eabceb5bcda` | `StreamCore` | `1` | `gasParameter`/`gasParameterFloor` key ([RSR-GGP], [RSR-2981-GAS]) |
| `GGP_ROYALTY_RETURN_GAS_BUFFER` | `6529STREAM_GGP_ROYALTY_RETURN_GAS_BUFFER` | `0x0af6f5a1a5059e398191fa0af185be12fee6d609933826603244c7f247793be7` | `StreamCore` | `1` | `gasParameter`/`gasParameterFloor` key ([RSR-GGP]) |
| `GGP_WALLET_DEPOSIT_GAS_LIMIT` | `6529STREAM_GGP_WALLET_DEPOSIT_GAS_LIMIT` | `0xd208e16b8676adecbbdd17f529a9effcb9153af90ac08886fb2906298206ff45` | split factory parameter store | `1` | `gasParameter`/`gasParameterFloor` key ([RSR-GGP]) |
| `GGP_FLUSH_GAS_FLOOR` | `6529STREAM_GGP_FLUSH_GAS_FLOOR` | `0x99168b87a7d39f5ba4862568c012ad3b51c552ec78108b88c6be5f5a6426ebe6` | revenue escrow | `1` | `gasParameter`/`gasParameterFloor` key ([RSR-GGP]) |

2. EIP-712 domains for the two typehashes above are pinned as: split
   wallets use `("6529StreamSplitWallet", "1", chainId, wallet)`; the
   ERC-20 settlement verifier uses
   `("6529StreamPrimarySaleSettlement", "1", chainId, verifier)`. Every
   verifying contract must expose ERC-5267 `eip712Domain()`.
3. The `MintTicket` typehash and domain are owned by
   `docs/mint-policy-and-accounting.md`; artist consent, sanction,
   economics-consent, royalty-freeze, and delegation typehashes are owned
   by [`docs/stream-artist-authority.md`](stream-artist-authority.md); the sale authorization and
   sale-side bid/offer payloads are owned by
   `docs/stream-sales-and-auctions.md` [SSA-AUTH]. They are deliberately
   absent here.
4. Namespace rule (ADR 0011 decision R12): every revenue-layer domain
   string carries the `6529STREAM_` namespace prefix. The three formerly
   `STREAM_`-prefixed constants — `PRIMARY_POLICY_DOMAIN`
   (`6529STREAM_PRIMARY_POLICY_V1`), `ROYALTY_POLICY_DOMAIN`
   (`6529STREAM_ROYALTY_POLICY_V1`), and `ESCROW_RECOVERY_DOMAIN`
   (`6529STREAM_ESCROW_RECOVERY_V1`) — are renamed to the namespaced
   preimages above with their hashes recomputed and re-pinned. The
   domain-constants checker must reject any new revenue-layer domain
   string that does not start with `6529STREAM_`.

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
- ERC-20 releases limited to approved standard assets or separately accepted
  adapters.
- Evented asset approval, approval deprecation, and unsupported marking
  through the single `AssetPolicyUpdated` fact ([RSR-EVENTS]).
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
- Core owns the hard immutable `maxRoyaltyBps` of 1000
  (ADR 0009 decision 7). A resolver may impose the same or a lower cap,
  but it cannot raise the Core cap. `maxRoyaltyBps` is an economic promise,
  not a gas bound, so it is deliberately outside the Governed Gas Parameter
  model: raising the Core cap after deployment requires a new Core
  deployment line and explicit rollout plan; lowering resolver policy can
  use a new resolver deployment and rollout plan.
- Gas-limit retuning is a GGP action under [RSR-GGP] and [RSR-2981-GAS];
  it never requires a resolver redeploy.
- Resolver replacement runbook (for implementation or storage changes, not
  gas retuning): deploy new resolver, register and approve its module
  identity/code hash/manifest hash, stage the Core resolver pointer update,
  replay or intentionally remap default and collection assignments, run
  `probeRoyaltyInfo` against representative default, collection, token,
  premint, burned, and malformed cases, emit a manifest-backed reason,
  execute after the delay, monitor fallback-to-zero diagnostics, and
  optionally freeze the new pointer after operational confidence.
  Replacement must not mutate old resolver state in place and must satisfy
  the frozen-economic continuity rules above.
- Assignment-time wallet deployment, factory, profile ID, and code-hash
  validation.
- Direct view for `primaryRevenueWallet(collectionId, tokenId, revenueClass)`.
- Direct view for `royaltyInfo(tokenId, salePrice)`.
- Direct view for `royaltyReceiver(collectionId)` for marketplace and operator
  diagnostics; this is a convenience view, not an ERC-2981 replacement.
- Factory view `splitWalletExists(profileId)` that returns true only when the
  deterministic wallet is deployed with the expected profile and active or
  historically eligible runtime code hash.
- Core-side `tokenCollectionIdentity(tokenId).mappingExists` read, passed as
  `hasMappedCollection`, for collection-scope royalty resolution.

### StreamDrops And StreamAuctions

- Replace three-bucket local split policy with resolver-backed profiles only
  after the split wallet and resolver have dedicated tests.
- Preserve current pull-payment and owed/surplus behavior in the v1 design.
- Assignments may point only to verified official split wallets or a
  protocol-owned revenue escrow with ADR 0003 owed/surplus guarantees.
- Use deterministic direct-deposit-then-escrow fallback so split wallet deposit
  failure cannot revert minting or auction settlement.
- Do not ship auction settlement until the sale contract passes the
  conformance profile of `docs/stream-sales-and-auctions.md` and the
  [RSR-SETTLEMENT-BOUNDARY] gates. The current drop-side auction
  placeholder is not a production settlement path.
- Keep v1 primary settlement limited to native ETH and approved standard ERC-20
  adapters; non-standard ERC-20 behavior requires a separate accepted adapter
  spec.
- Emit source revenue events only after funds are accepted by the split wallet
  or recorded as owed by the revenue escrow.

### StreamCuratorsPool

Resolved (ADR 0011 decision R12): the legacy curators pool is excluded
from protocol v1. It sits outside the Stream payment conformance boundary,
is not part of the genesis contract inventory in
`docs/launch-conformance-matrix.md`, and no genesis default template
routes revenue to it ([RSR-TEMPLATES].3). Curator classes are deployment
configuration when a conformant pool contract exists: a curator reward or
pool contract may receive template or profile revenue only when all of
the following hold:

1. It follows the same owed/surplus boundary as the primary splitter
   architecture — push payments and unrestricted emergency sweeps are not
   deployment-conformant for owed rewards.
2. It enters through its own accepted module spec with pull accounting
   and explicit surplus proofs.
3. The deployment manifest names it as the receiving contract.

Until such a contract exists, curator-class labels remain usable on
ordinary split profile entries (a curator's account is simply an entry);
no pool recipient exists in the genesis economics.

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
- artist economics attestation status, artist share, and artist freeze
  state for artist-bound collections;
- policy history from events.

Operator tools must not imply that ERC-2981 royalties are enforced.

## Recipient UX

Recipient tools should show:

- every split wallet where the connected account has releasable funds;
- source profile and labels for each entitlement;
- the possibility that economically identical concrete splits from different
  templates resolve to different wallets, with one-transaction aggregated
  claiming across them through the [RSR-CLAIM-ROUTER] `claimMany` surface;
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

The display guidance above is should-level; the rehearsed claim flow and
the named entitlement-indexer operator are must-gated under
[RSR-CLAIM-ROUTER].6 (ADR 0011 decision R12), so recipient discovery
cannot silently decay into an unfunded, unowned dependency.

## Marketplace And Indexer UX

Marketplace and indexer integrations should:

- read `supportsInterface(0x2a55205a)`;
- call `royaltyInfo(tokenId, salePrice)`;
- display receiver and amount as royalty disclosure;
- recognize split wallet receivers where supported;
- avoid claims that payment is guaranteed;
- retain platform-specific evidence before public release claims.

Requirements [RSR-MARKETPLACE-ROYALTY]:

1. Marketplace royalty-resolution coverage is a named deployment gate,
   not an integration extra (ADR 0011 decision R12). Before the first
   public sale, release evidence must record, for each marketplace named
   in the release manifest's marketplace evidence list, where that
   marketplace actually resolves royalties for shared multi-collection
   contracts — direct ERC-2981 read, marketplace-side royalty
   configuration, or the community Royalty Registry — and proof that
   this deployment resolves correctly there: a Royalty Registry entry
   where the marketplace consults one (the entry must mirror Core-native
   ERC-2981 and never diverge from it), and per-marketplace royalty
   configuration verification for the majors. Core-native ERC-2981
   remains the base truth; registry and config entries are plumbing to
   it, never a second source.
2. The coverage evidence must be re-verified on the recurring
   post-launch obligation cadence of `docs/launch-conformance-matrix.md`;
   a missed cadence is a monitored incident (ADR 0011 decision R12).
3. Artist acknowledgment: the artist onboarding artifact of
   [`docs/stream-artist-authority.md`](stream-artist-authority.md) must
   present the disclosure-only, permanently unenforceable royalty
   posture of this Core line as an explicit term, and a recorded artist
   acknowledgment of that term is required before an artist-bound
   collection's first public sale (ADR 0011 decision R12). Setting
   royalty expectations without that acknowledgment is nonconformant.
4. The transfer-openness preclusions behind this posture and the
   successor-line enforcement path — including what a declared successor
   Core line with enforcement preserves — are owned by
   `docs/stream-long-term-architecture.md` [LTA-STANDARDS]; this
   document does not restate them.

## Pre-Deployment Implementation Sequence

1. Implement the split wallet factory and immutable split wallets.
2. Add exhaustive split-profile, canonicalization, dust, release, ERC-20, and
   deterministic deployment tests.
3. Implement resolver assignment storage, set/clear/freeze/read functions, and
   event reconstruction.
4. Wire fixed-price primary settlement through resolver-backed fixed profiles
   or primary split templates.
5. Wire auction primary settlement only after the sale contract passes the
   `docs/stream-sales-and-auctions.md` conformance profile and the
   [RSR-SETTLEMENT-BOUNDARY] gates.
6. Implement royalty assignments and split-wallet royalty receiver resolution.
7. Add minimal resolver-backed `royaltyInfo()` to `StreamCore` before
   production deployment.
8. Prove the Core size budget with measured bytecode output. If the size budget
   fails, refactor non-essential Core logic into satellites or compress helper
   code until Core-native ERC-2981 fits.
9. Retain marketplace/indexer evidence for Core-native ERC-2981 behavior and
   split-wallet receiver display, including the [RSR-MARKETPLACE-ROYALTY]
   royalty-resolution coverage gate.
10. Update docs, release artifacts, event catalogs, ABI checksums, and retained
   marketplace evidence.

## Known Risks

- Pull-based split wallets require recipients to claim; the claim router
  reduces but does not remove that responsibility.
- Passive royalty receipts can create tiny bounded rounding dust that remains
  in the wallet under v1 accounting.
- Forced ETH sent to a counterfactual wallet before deployment is attributed to
  the immutable profile eventually deployed at that deterministic address.
- Unsupported rebasing-down ERC-20 behavior can skew entitlements before the
  balance-decrease guard detects it; approved assets must exclude that class.
- Incident-revoking a wallet runtime code hash can freeze owed escrow for that
  hash until the timelocked successor-wallet recovery path is executed.
- Governed Gas Parameters reintroduce a governance dependency into read and
  release paths that were fully static; accepted for survivability, bounded
  by immutable floors, staged delays, and health probes (ADR 0010
  decision D1).
- Entitlements of lost-key EOA accounts in existing wallets are permanently
  unclaimable ([RSR-ESTATE].3); disclosed, not mitigated.
- Marketplace royalty behavior remains external, uneven, and cache-prone;
  the [RSR-MARKETPLACE-ROYALTY] coverage gate keeps resolution verified
  where marketplaces actually look, without promising payment.

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
- Applying inherited freeze with existing lower overrides reverts in
  protocol v1.
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
- All-cold deepest-scope resolver gas is measured against the genesis
  `ROYALTY_RESOLVER_GAS_LIMIT` value and floor, satisfying the [RSR-GGP].9
  multiples with documented margin.
- Static analysis proves the production resolver royalty path contains no
  external-call or creation opcodes.
- Core royalty resolver gas parameters are Governed Gas Parameters:
  raise, emergency raise, probe-gated lower, below-floor rejection, change
  events, and manifest recording are all tested, and fallback behavior is
  deterministic just below and above the current limit.
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
- Static analysis fails CI if `tx.origin` appears in any
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
- Settlement surfaces carry `settlementId` equal to the sales-spec
  `saleId` and `saleNonce` equal to its adapter-local nonce per the
  [RSR-SETTLEMENT-BOUNDARY].5 mapping rule; divergent sale references
  fail conformance.
- Escrow flush is permissionless, idempotent, cannot double-credit, and cannot
  make owed funds emergency-withdrawable.
- Escrow flush sets owed credit to zero before factory deployment or transfer,
  and EVM revert restores the credit on failure.
- Escrow flush tests include a wallet/factory harness that reverts on the Nth
  deposit or deployment step and proves the cached owed amount is restored.
- Escrow flush rejects early when `gasleft()` is below the current
  `FLUSH_GAS_FLOOR` Governed Gas Parameter value, and floor raise/lower
  governance is tested against the immutable minimum.
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
- `ACTIVE` ERC-20 assets are syncable and releasable; `UNKNOWN`,
  `INACTIVE`, and `UNSUPPORTED` assets fail closed without mutating wallet
  accounting; `DEPRECATED` assets sync and release exactly per the
  [RSR-ASSET-POLICY].5 observation and grace rules, including the
  escrow-flush-then-release case inside the grace window and the fail-closed
  case after it.
- Asset-status transitions away from `ACTIVE` execute only through the
  ADR 0004 staged action-ID model; emergency `UNSUPPORTED` marking carries a
  published incident reason.
- ERC-20 activation records evidence for standard monotonic-balance behavior.
- ERC-20 asset policy is read from the factory-bound deployment-wide asset
  policy registry; registry failure blocks only non-native assets.
- Release-before-explicit-sync computes from cumulative balance and updates
  `lastObservedReceived` only after transfer/delta checks.
- `syncAsset` on first zero balance initializes observation state.
- `syncAsset` ordering is initialize, revert on decrease, skip unchanged,
  update on increase.
- Collection-scope royalty resolution requires
  `tokenCollectionIdentity(tokenId).mappingExists == true`; unmapped tokens return
  default or zero.
- Royalty policy mode is configured and frozen with collection economics before
  public mint when collection economics are promised immutable.
- Royalty resolver ABI, selector, gas cap, and malformed-return fallback are
  fixed and tested.
- `royaltyInfo()` fallback-to-zero is paired with a non-view diagnostic probe
  and deployment readiness gate.
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
- ERC-20 settlement initiated by any caller other than the payer itself
  without a valid payer-signed `PaymentIntent` reverts
  before any allowance pull, template materialization, escrow credit, or
  mint effect; replayed, expired, over-`maxAmount`, wrong-`saleRef`, and
  revoked intents all revert; the payer-is-caller path
  ([RSR-PAYMENT-INTENT].5) cannot pull an asset or amount beyond the sale
  authorization's binding.
- Release-authorization and `PaymentIntent` consumed-nonce state is keyed
  per signer: one account cannot consume, revoke, or invalidate another
  account's nonce value, and the explicit-address replay views report
  consumption correctly for any queried signer.
- Escrow-holding sale modes finalize under `ALLOW_CURRENT` within the
  buyer's drift envelope after resolved-policy drift, and past the
  finalize-by deadline the permissionless sale-side refund path unlocks
  escrowed funds; drift can never strand deferred-settlement buyer funds
  ([RSR-SALE-AUTH].5, [RSR-SETTLEMENT-BOUNDARY].9).
- Sale authorization signatures bind every field of the
  `docs/stream-sales-and-auctions.md` [SSA-AUTH] payload; changing asset,
  price, quantity, program, recipients, nonce, or deadline invalidates the
  signature, and revocation consumes the ledger authorization ID.
- Release authorizations verify under the pinned
  `RELEASE_AUTHORIZATION_TYPEHASH` and domain; revocation consumes the
  nonce before any later use.
- CI recomputes every hash and typehash in
  [Revenue Domain Constants And Typehashes](#revenue-domain-constants-and-typehashes)
  from its string preimage and fails on drift.
- ERC-1271 verification passes for a maximum-supported wallet of each
  class named by ADR 0004 [GOV-1271-CLASS] ([RSR-1271].2) at the deployed
  genesis `ERC_1271_GAS_LIMIT`
  and fails cleanly for a malicious gas-consuming wallet.
- The claim router batches release-to-self across at least 20 wallets in
  one transaction, holds no funds, cannot route alternate-recipient
  releases, and isolates per-item failures under `continueOnFailure`.
- The rehearsed recipient claim flow of [RSR-CLAIM-ROUTER].6 is recorded
  as release evidence and the funding/endowment manifest names the
  entitlement-indexer operator.
- Marketplace royalty-resolution coverage evidence exists for every
  marketplace in the release manifest's evidence list, and the artist
  onboarding acknowledgment of the disclosure-only royalty term is
  recorded before an artist-bound collection's first public sale
  ([RSR-MARKETPLACE-ROYALTY]).
- Artist-bound collections cannot open public mint without the
  [RSR-ARTIST-ECONOMICS].2 artist economics attestation; artist-share
  reductions without artist co-signature revert; the artist royalty
  freeze right executes without platform countersignature.
- `CUSTODY_SETTLEMENT_TRANSFER` records settlement state and revenue
  before the custody-to-recipient transfer callback.
- Golden event tests cover the deduplicated [RSR-EVENTS] surface: one
  signature per event name, `schemaVersion` on every non-standard event,
  and the normative indexed allocation.
- Core size-budget gate is run for any Core change.
