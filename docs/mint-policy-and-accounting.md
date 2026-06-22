# Mint Policy And Accounting

This document is a pre-launch target specification for moving mint limits and
mint accounting out of `StreamCore` into a dedicated mint subsystem made of
`StreamMintManager` and `StreamMintLedger`. `StreamCore` should remain the
canonical ERC-721 contract, keep `ERC721Enumerable`, and mint only after an
authorized mint manager has validated policy and consumed allowance through the
ledger.
The cross-cutting 50+ year architecture principles live in
`docs/stream-long-term-architecture.md`.

## Design Summary

`StreamCore` should own ERC-721 state and final token creation. It should not
own sale phase policy, public/allowlist/drop counters, signed mint authorization,
or durable mint counter logic.

```text
StreamCore
  - ERC-721 ownership and enumeration
  - token existence
  - token to collection identity
  - collection supply invariants
  - one authorized mint-manager entrypoint

StreamMintManager
  - open-vocabulary phase IDs
  - phase start/end and pause policy
  - open-vocabulary counter IDs
  - many simultaneous counters per phase
  - phase, collection, and global counter scopes
  - launch counter keys for recipient, payer, executor, constant, and context
  - future resolver-backed profile, delegation, and custom counter keys
  - batch quantity limits
  - policy fingerprint computation
  - executor authorization
  - optional mint gate validation
  - counter-consumption preparation and mint events

StreamMintLedger
  - durable monotonic counter values
  - authorization/nullifier consumption
  - manager-only write boundary
  - counter accounting events

StreamMintModuleRegistry
  - allowed gate and resolver modules
  - ERC-165 interface checks
  - semantic module versions
  - module codehash and metadata records
  - active, deprecated, and blocked module status

Mint Executors
  - fixed-price sale adapters
  - drop executors
  - auction settlement executors
  - allowlist or signed-claim executors

Optional Gate/Resolver Contracts
  - Merkle allowlist validation
  - EIP-712 ticket validation
  - ERC-1271 smart-wallet signature validation
  - future 6529 profile/delegation counter-key resolution
  - privacy-preserving nullifier resolution
```

The manager is the only contract authorized to call the Core mint function. The
ledger accepts writes only from authorized managers. Sale and drop contracts call
the manager; the manager validates mint policy, consumes allowance through the
ledger, and then calls Core.

## Launch Scope

Launch mint scope should be auditable and intentionally smaller than the full
future counter system:

1. Core-owned global token ID allocation.
2. Fixed-size, capped-open, and uncapped-open collection minting.
3. Explicit recipient and payer binding; no `tx.origin`.
4. Static phase caps, static counter caps, and static counter deltas.
5. Counter key modes for recipient, payer, executor, constant, and explicit
   context hash where needed.
6. EIP-712/ERC-1271 signed mint tickets.
7. Module registry with interface and codehash checks for approved gates.
8. One durable ledger for counter and authorization consumption.

Non-launch unless separately approved:

1. Resolver-defined caps.
2. Resolver-defined deltas.
3. Privacy-preserving nullifier systems.
4. General-purpose custom policy VMs.
5. ERC-20 primary payment adapters.
6. Delegated-profile, consolidated-identity, or other resolver-backed counter
   subjects unless a concrete resolver interface, gas cap, registry status, and
   test suite are accepted with that launch branch.

## Current Implementation Baseline

Today `StreamCore` stores three per-address counters:

```solidity
mapping(uint256 => mapping(address => uint256)) private tokensMintedPerAddress;
mapping(uint256 => mapping(address => uint256)) private tokensMintedAllowlistAddress;
mapping(uint256 => mapping(address => uint256)) private tokensAirdropPerAddress;
```

It also stores `maxCollectionPurchases` inside collection additional data and
exposes it through `viewMaxAllowance()`.

Only `tokensAirdropPerAddress` is incremented during `StreamCore.mint()`, and
that happens for every mint routed through the current minter. Public and
allowlist counters are exposed but are not currently connected to enforcement.

`StreamMinter` currently enforces collection mint windows and total collection
supply. It does not enforce per-wallet maximums and does not update public or
allowlist counters.

The scratch compile showed that removing these counters and getters from Core
saves about `324` runtime bytes. The primary reason for this refactor is not
bytecode size; it is correctness, extensibility, and clean contract ownership.

## Goals

1. Keep Core focused on ERC-721 ownership, enumeration, and final minting.
2. Remove public, allowlist, and airdrop mint counters from Core.
3. Remove `maxCollectionPurchases` from Core collection data.
4. Support arbitrary phase IDs instead of hardcoding public, allowlist, or
   airdrop forever.
5. Allow the same collection to have many independent mint phases.
6. Support many counters per phase from the beginning.
7. Track consumed allowance by configurable counter keys.
8. Support wallet, payer, recipient, and context counter-key models at launch,
   while leaving resolver-backed delegated profile and custom identity models
   for explicitly approved extensions.
9. Support phase-scoped, collection-scoped, and global counters.
10. Support batch mints without allowing duplicate-recipient or duplicate-key
   bypasses.
11. Support executor contracts for paid sales, drops, auctions, reserves, and
   future mint mechanisms.
12. Expose clear read APIs for frontend, indexers, and operator tooling.
13. Use typed errors and events that make policy history reconstructable.
14. Avoid `tx.origin`.
15. Keep durable accounting in a small ledger that can outlive individual
    policy modules.
16. Fingerprint every active phase policy with a canonical `policyHash`.
17. Support signed mint tickets using EIP-712, ERC-1271, and ERC-5267.
18. Treat smart accounts, delegated wallets, and future identity systems as
    first-class participants.
19. Register gates and resolvers through an interface-aware module registry.
20. Expose explainable previews that show every counter, projected increment,
    cap, and failure reason.
21. Support privacy-ready nullifier counters without assuming every future
    eligibility system reveals the recipient identity.

## Non-Goals

1. `StreamMintManager` does not own ERC-721 balances or approvals.
2. `StreamMintManager` does not render metadata.
3. `StreamMintManager` does not split proceeds.
4. `StreamMintManager` does not implement ERC-2981 royalties.
5. `StreamMintManager` does not push ETH to recipients.
6. `StreamMintManager` does not hardcode the complete set of phase labels.
7. `StreamMintManager` does not require an upgradeable proxy.
8. `StreamMintManager` does not implement a general-purpose onchain policy VM.
9. `StreamMintLedger` does not decide eligibility, prices, or mint timing.
10. Gate and resolver display metadata is not accounting authority.

Primary-sale payment collection and revenue splitting belong in the revenue
settlement contracts. The mint manager may be called atomically by those
contracts after they validate and settle payment.

## Standards Alignment

The mint subsystem should intentionally align with these standards:

1. ERC-721 remains implemented by `StreamCore`.
2. EIP-712 is the typed-data format for signed mint tickets.
3. ERC-1271 is required for contract-wallet ticket signatures.
4. ERC-5267 is required for ticket gates that own an EIP-712 domain.
5. ERC-165 is required for gate and resolver module detection.
6. ERC-4337 informs the account model: payer, executor, recipient, and
   authorizer are distinct.
7. ERC-2771-style forwarding is optional and only through explicit trusted
   forwarders.
8. ERC-2309-style consecutive minting should not be used for live mint paths.

## Core Contract Changes

`StreamCore` should expose a single mint-manager pointer:

```solidity
interface IStreamMintManager {
    function isStreamMintManager() external view returns (bool);
}
```

Core should store:

```solidity
address public mintManager;
uint256 private nextTokenId;
mapping(uint256 tokenId => uint256 collectionId) tokenCollectionId;
mapping(uint256 tokenId => uint256 collectionSerial) tokenCollectionSerial;
mapping(uint256 tokenId => bool mappingExists) tokenCollectionMappingExists;
```

Core should expose the canonical read shared by royalties, metadata, finality,
and indexers:

```solidity
function tokenCollectionIdentity(uint256 tokenId)
    external
    view
    returns (
        bool mappingExists,
        uint256 collectionId,
        uint256 collectionSerial,
        bool burned
    );
```

For burned tokens this read returns the retained mapping and `burned = true`;
for premint or nonexistent unmapped tokens it returns `(false, 0, 0, false)`.

Core should expose a manager-only mint entrypoint:

```solidity
function mintFromManager(
    uint256 collectionId,
    address initialRecipient,
    address beneficiary,
    bytes32 tokenDataHash,
    bytes32 mintCommitment
) external returns (uint256 tokenId);
```

Launch should not include persistent standalone token reservations. When another
spec says a token is "reserved," it means either:

1. the token identity is prepared and completed inside the same top-level
   transaction by the mint manager, so any later failure reverts the mapping and
   serial allocation; or
2. a later reservation ADR has defined expiry, cancellation, serial-gap,
   revenue, and royalty-snapshot rules.

If same-transaction prepared mints are needed for token-level primary policy,
Core may expose a manager-only two-step internal launch surface:

```solidity
function prepareMintFromManager(
    uint256 collectionId,
    address beneficiary,
    bytes32 tokenDataHash,
    bytes32 mintCommitment
) external returns (uint256 tokenId, uint256 collectionSerial);

function completePreparedMintFromManager(
    uint256 tokenId,
    address initialRecipient
) external;
```

`prepareMintFromManager` writes identity, serial, existence status, and entropy
registration but does not emit an ERC-721 transfer or call the recipient.
`completePreparedMintFromManager` must be called by the same manager flow after
revenue is recorded and before the transaction returns. Persistent prepared
tokens are forbidden in launch unless the later reservation ADR exists.

Prepared-mint safety rules:

1. The two-step surface is optional and should be used only when token-level
   primary policy truly needs a token ID before revenue recording.
2. `prepareMintFromManager` and `completePreparedMintFromManager` must share the
   same non-reentrant manager execution path; no unrelated external Core mint,
   burn, transfer, or second prepare may interleave while a prepared token is
   pending.
3. Core must bind a prepared token to `msg.sender`, `tokenId`, `collectionId`,
   `beneficiary`, `tokenDataHash`, `mintCommitment`, the batch
   `mintCommitmentsHash`, and an operation ID or equivalent manager-supplied
   context hash.
4. `completePreparedMintFromManager` must verify and clear the pending prepared
   record before `_safeMint` or any external receiver callback.
5. If any later step in the top-level transaction reverts, the prepared mapping,
   collection serial, entropy registration, and revenue/royalty snapshot all
   revert with the transaction.
6. A prepared token that is not completed in the same top-level manager flow is
   a bug; launch Core must not expose a durable prepared-token or reservation
   state.
7. `prepareMintFromManager` invokes the same entropy registration boundary as
   `mintFromManager`, but Core marks the token as prepared-incomplete until
   `completePreparedMintFromManager` clears the pending record. Public
   `requestEntropy(tokenId)`, metadata finalization, transfer, burn, and any
   other token operation outside the manager flow must revert for
   prepared-incomplete tokens.
8. The per-token `mintCommitment` supplied to Core must equal the corresponding
   element already committed by the signed `MintTicket.mintCommitmentsHash` or
   by the equivalent sale authorization hash. A prepared mint cannot introduce a
   new commitment after the signed authorization or sale policy was accepted.

Canonical prepared-mint operation boundary:

```solidity
bytes32 operationId = keccak256(abi.encode(
    STREAM_PREPARED_MINT_OPERATION_V1,
    block.chainid,
    address(mintManager),
    address(mintLedger),
    address(core),
    address(primarySaleAdapter),
    uint256(collectionId),
    bytes32(phaseId),
    address(executor),
    address(payer),
    bytes32(initialRecipientsHash),
    bytes32(beneficiariesHash),
    bytes32(tokenDataHashesHash),
    bytes32(mintCommitmentsHash),
    bytes32(primaryPolicyHash),
    bytes32(royaltySnapshotPolicyHash),
    bytes32(policyHash),
    bytes32(authorizationId),
    uint256(quantity),
    uint256(nonce),
    uint64(deadline)
));

struct PreparedMintRecord {
    bool exists;
    bytes32 operationId;
    address manager;
    uint256 collectionId;
    uint256 collectionSerial;
    address beneficiary;
    bytes32 tokenDataHash;
    bytes32 mintCommitment;
    bytes32 mintCommitmentsHash;
    uint64 preparedAt;
}

function prepareMintFromManager(
    uint256 collectionId,
    address beneficiary,
    bytes32 tokenDataHash,
    bytes32 mintCommitment,
    bytes32 mintCommitmentsHash,
    bytes32 operationId
) external returns (uint256 tokenId, uint256 collectionSerial);

function completePreparedMintFromManager(
    uint256 tokenId,
    address initialRecipient,
    bytes32 operationId
) external;

function preparedMint(uint256 tokenId)
    external
    view
    returns (PreparedMintRecord memory);

function executePreparedMint(
    MintBatch calldata batch,
    bytes calldata gateData,
    bytes calldata settlementData
) external payable returns (uint256[] memory tokenIds, bytes32 operationId);
```

Every state-changing contract participating in `PREPARED_MINT` must receive or
derive the same `operationId`: sale adapter, mint manager, ledger, Core
prepare/complete, revenue resolver snapshot hook, entropy registration
boundary, and escrow/deposit path. A contract must reject a prepared-mint call
whose operation ID does not match the operation currently locked by the mint
manager. The operation lock is non-reentrant and cannot be reused for a
different token, batch, payer, phase, policy hash, or sale adapter.

Launch control-flow owner: `StreamMintManager`. User-facing sale adapters call
one manager-owned prepared-mint entrypoint or a sale adapter entrypoint that
immediately delegates to the manager. Core `prepareMintFromManager` and
`completePreparedMintFromManager` are restricted to `msg.sender == mintManager`
and are never independent user flows. The manager calls the restricted
settlement adapter hook between Core prepare and Core complete. If settlement,
resolver snapshot, escrow/deposit, entropy registration, or completion fails,
the whole manager call reverts and no prepared state persists.

The manager's non-reentrant operation lock must be externally verifiable
through Core state. Core's `PreparedMintRecord.operationId` is the canonical
shared lock state for each prepared token. Every satellite participating in a
prepared mint, including resolver snapshot hooks, escrow/deposit paths, and
entropy registration helpers, must read `preparedMint(tokenId).operationId`
from Core or receive it from the manager and re-verify against Core. No
satellite may rely solely on a manager-internal private flag it cannot read.

Operation propagation table:

```text
Sale adapter          derives operationId from signed sale/mint authorization and rejects payment settlement mismatch
Mint manager          owns non-reentrant operation lock and rejects nested or different operationId
Mint ledger           consumes counters/authorization only for the manager-supplied operationId
Core prepare          stores operationId in PreparedMintRecord for each allocated token
Resolver snapshot     reads PreparedMintRecord and rejects missing or mismatched operationId
Entropy registration  records prepared-incomplete state under the same operationId or manager context
Escrow/deposit path    emits or stores operationId with the payment settlement record where applicable
Core complete         clears PreparedMintRecord only when operationId matches
```

Recommended events:

```solidity
event PreparedMintStarted(
    uint16 schemaVersion,
    bytes32 indexed operationId,
    uint256 indexed tokenId,
    uint256 indexed collectionId,
    uint256 collectionSerial,
    address beneficiary,
    bytes32 tokenDataHash,
    bytes32 mintCommitment
);

event PreparedMintCompleted(
    uint16 schemaVersion,
    bytes32 indexed operationId,
    uint256 indexed tokenId,
    uint256 indexed collectionId,
    address initialRecipient
);
```

Successful launch transactions leave no persistent prepared state after
completion: `preparedMint(tokenId).exists` returns false once
`completePreparedMintFromManager` clears the record. The read exists so other
contracts in the same top-level operation can prove they are snapshotting the
same prepared token, not so operators can create durable reservations.

Required Core behavior:

1. Revert unless `msg.sender == mintManager`.
2. Revert unless the collection exists, is active for minting, is not closed or
   artwork-finality-blocked for new supply, and data needed for supply exists.
3. Allocate `tokenId = nextTokenId++` inside Core.
4. Allocate the next stable collection-local serial inside Core.
5. Revert if collection supply is exhausted for fixed or capped-open
   collections.
6. Store `tokenDataHash`, token-to-collection identity, collection-local
   serial, and mapping-existence bit. Core stores no renderer-visible
   `tokenData` bytes.
7. Register token entropy state through the entropy subsystem before any
   external receiver callback can observe the token.
8. Mint to `initialRecipient`.
9. Return the minted token ID.

The entropy registration hook must be bounded and must not call external
randomness providers from the mint path. If safe minting to a contract recipient
reverts, the full transaction reverts and both Core identity writes and entropy
registration unwind.

`initialRecipient` is the address that receives the ERC-721 mint event and the
first ownership state. `beneficiary` is the intended economic/final recipient
known to the manager or sale executor. For ordinary direct mints they are the
same address. For custody-based settlement, `initialRecipient` is the custody or
settlement contract and `beneficiary` is the buyer, claimant, artist, or other
intended final owner. Both fields must be nonzero, and custody flows must emit
the later transfer normally so event consumers can reconstruct the whole path.

Core should emit:

```solidity
event MintManagerUpdated(address indexed oldManager, address indexed newManager);
event StreamTokenMinted(
    uint256 indexed collectionId,
    uint256 indexed tokenId,
    address indexed initialRecipient,
    address operator,
    address beneficiary
);
```

The existing `StreamCore.mint(uint256,address,string,uint256,uint256)` entrypoint
should be replaced by `mintFromManager` before launch.

Burn behavior must preserve the identity mapping used by royalties and audits.
If a token is burned, Core removes ERC-721 ownership and enumerable membership
but must not clear `tokenCollectionId`, `tokenCollectionSerial`, or
`tokenCollectionMappingExists`. Burned-token `tokenURI()` may revert under
normal ERC-721 metadata semantics, while `royaltyInfo()` can still disclose the
last token, collection, then default royalty policy.

## Phase IDs

Mint phases use open-vocabulary `bytes32` IDs. They are not a closed enum.

Examples:

```text
keccak256("public")
keccak256("allowlist")
keccak256("poster-drop")
keccak256("auction-settlement")
keccak256("artist-reserve")
keccak256("collaborator-claim")
keccak256("curator-reward")
keccak256("museum-allocation-2040")
```

These examples are not hardcoded protocol constants. They are examples of
operator-chosen IDs.

For UI display, the manager should emit event metadata. It should not store
large mutable display strings as authoritative accounting state.

```solidity
event MintPhaseMetadata(
    uint256 indexed collectionId,
    bytes32 indexed phaseId,
    bytes32 metadataHash,
    string metadataURI
);
```

`metadataURI` is optional event data for indexers and UIs. The authoritative
phase identity is `phaseId`.

## Counter Model

The manager should be designed around a generic counter engine, not around one
hardcoded "mints per wallet" mapping. A phase may attach many counters, and all
attached counters must pass before the mint succeeds.

Counter IDs are open-vocabulary `bytes32` values:

```text
keccak256("phase-supply")
keccak256("phase-per-recipient")
keccak256("phase-per-payer")
keccak256("phase-per-6529-profile")
keccak256("collection-lifetime-per-payer")
keccak256("collection-lifetime-per-profile")
keccak256("drop-context-once")
keccak256("artist-reserve-allocation")
keccak256("curator-claim-round-2042")
```

These are examples, not a closed list. The contract should not need a redeploy
to add a new counter ID.

Counters have two separable concepts:

1. Scope: where the value is shared.
2. Key: who or what is being counted inside that scope.

Recommended scopes:

```solidity
enum CounterScope {
    GLOBAL,
    COLLECTION,
    PHASE
}
```

Recommended key modes:

```solidity
enum CounterKeyMode {
    CONSTANT,
    RECIPIENT,
    PAYER,
    EXECUTOR,
    CONTEXT,
    CUSTOM_RESOLVER
}
```

Recommended update modes:

```solidity
enum CounterUpdateMode {
    PER_TOKEN,
    PER_BATCH
}
```

Recommended cap modes:

```solidity
enum CounterCapMode {
    NONE,
    STATIC,
    RESOLVER
}
```

`CounterCapMode.NONE` is the only no-cap state. `CounterCapMode.STATIC` uses
the configured static cap exactly; `staticCap = 0` means zero allowed unless a
phase validator rejects zero as an invalid configuration for that counter.
Implementations must not treat `STATIC cap = 0` as unlimited.

Recommended delta modes:

```solidity
enum CounterDeltaMode {
    STATIC,
    RESOLVER
}
```

`CounterCapMode.RESOLVER` lets a counter derive the effective cap from a Merkle
leaf, signed ticket, profile score, delegation graph, or future identity system.
`CounterDeltaMode.RESOLVER` lets a counter consume something other than a flat
`1`, such as auction lots, weighted claims, profile-weighted credits, or a
batch-level nullifier.

Launch implementations must reject `CounterCapMode.RESOLVER`,
`CounterDeltaMode.RESOLVER`, `CUSTOM_RESOLVER`, and non-empty nullifier
consumption unless the corresponding extension has been accepted by a later ADR
and enabled in the module registry. Future enum values are allowed in the
schema so policy hashes can evolve, but dead enum surface must not become
dead-but-callable launch code. Tests should configure each deferred mode and
prove it reverts before any counter or mint state is written.

Launch-permitted counter combinations are finite:

```text
scope             key mode                  update mode   cap mode   delta mode
PHASE             CONSTANT                  PER_TOKEN     STATIC     STATIC
COLLECTION        CONSTANT                  PER_TOKEN     STATIC     STATIC
PHASE             RECIPIENT                 PER_TOKEN     STATIC     STATIC
PHASE             PAYER                     PER_TOKEN     STATIC     STATIC
COLLECTION        RECIPIENT                 PER_TOKEN     STATIC     STATIC
COLLECTION        PAYER                     PER_TOKEN     STATIC     STATIC
PHASE             CONTEXT                   PER_BATCH     STATIC     STATIC
COLLECTION        CONTEXT                   PER_BATCH     STATIC     STATIC
```

Any other combination reverts at configuration time unless a later ADR expands
the allowed set. This table bounds the launch test matrix.
There is no separate `BENEFICIARY` enum in launch: `RECIPIENT` means the
intended beneficiary as defined below, not the temporary initial recipient.

Examples:

```text
phase supply cap
  scope      = PHASE
  key mode   = CONSTANT
  update     = PER_TOKEN
  cap        = phase max supply

one mint per recipient in allowlist phase
  scope      = PHASE
  key mode   = RECIPIENT
  update     = PER_TOKEN
  cap        = 1

five lifetime mints per 6529 profile across a collection
  scope      = COLLECTION
  key mode   = CUSTOM_RESOLVER
  update     = PER_TOKEN
  cap mode   = STATIC
  cap        = 5

one execution per signed drop context
  scope      = PHASE
  key mode   = CONTEXT
  update     = PER_BATCH
  cap mode   = STATIC
  cap        = 1

allowlist cap from a Merkle leaf
  scope      = PHASE
  key mode   = CUSTOM_RESOLVER
  update     = PER_TOKEN
  cap mode   = RESOLVER
  delta mode = STATIC

private claim nullifier
  scope      = GLOBAL
  key mode   = CUSTOM_RESOLVER
  update     = PER_BATCH
  cap mode   = STATIC
  cap        = 1
```

## Counter Key Derivation

Allowance accounting must not assume that the recipient address is always the
right identity. Every counter derives a counter key.

Counter derivation separates the subject from the counter scope. The subject key
answers "who or what is being counted"; the value key answers "where is that
subject counted."

Default address-based subject-key derivation:

```solidity
bytes32 subjectKey = keccak256(abi.encode(
    COUNTER_SUBJECT_DOMAIN,
    uint256(block.chainid),
    address(mintLedger),
    uint8(keyMode),
    accountAddress
));
```

`CONSTANT` uses a deterministic key for the counter:

```solidity
bytes32 subjectKey = keccak256(abi.encode(
    COUNTER_SUBJECT_DOMAIN,
    uint256(block.chainid),
    address(mintLedger),
    uint8(CounterKeyMode.CONSTANT),
    "CONSTANT"
));
```

`CONTEXT` uses `batch.contextHash`. If a context counter is configured, the
manager must require a nonzero `contextHash`.

The durable ledger value key is scoped separately:

```solidity
bytes32 valueKey = keccak256(abi.encode(
    COUNTER_VALUE_DOMAIN,
    uint256(block.chainid),
    address(mintLedger),
    uint8(scope),
    scope == CounterScope.GLOBAL ? uint256(0) : collectionId,
    scope == CounterScope.PHASE ? phaseId : bytes32(0),
    counterId,
    subjectKey
));
```

For `GLOBAL`, both collection and phase are zeroed. For `COLLECTION`, phase is
zeroed. For `PHASE`, both collection and phase are included. Tests must prove
GLOBAL counters share across collections/phases and COLLECTION counters share
across phases within the same collection.

For `CUSTOM_RESOLVER`, the counter points to a resolver:

```solidity
struct CounterKeyContext {
    uint256 collectionId;
    bytes32 phaseId;
    bytes32 counterId;
    address payer;
    address initialRecipient;
    address beneficiary;
    address executor;
    address authorizer;
    uint256 tokenIndex;
    bytes32 contextHash;
    bytes resolverData;
}

struct CounterResolution {
    bytes32 subjectKey;
    uint64 effectiveCap;
    uint64 increment;
    bytes32 resolutionHash;
}

interface IStreamMintCounterResolver {
    function resolveCounter(CounterKeyContext calldata context)
        external
        view
        returns (CounterResolution memory);
}
```

`CounterKeyMode.RECIPIENT` means the intended `beneficiary`, not the temporary
`initialRecipient`, so custody-based settlement cannot bypass per-recipient
limits by minting first to a custody contract. A phase that intentionally needs
to count the custody address should use `EXECUTOR`, `CONTEXT`, or an explicit
`CUSTOM_RESOLVER` policy that names that behavior.

Resolver output rules:

1. `subjectKey` must be nonzero.
2. `effectiveCap` is used only when `capMode == RESOLVER`.
3. `increment` is used only when `deltaMode == RESOLVER`.
4. `increment` must be nonzero for every enabled counter consumption.
5. `resolutionHash` should commit to offchain or external evidence, such as a
   Merkle leaf, signed allocation, profile snapshot, or nullifier commitment.

Resolver examples:

1. Recipient wallet address.
2. Payer wallet address.
3. 6529 profile ID.
4. Delegation-aware owner account.
5. Consolidated wallet identity.
6. Signed claim beneficiary.
7. Offchain-authorized allocation bucket.
8. Privacy-preserving nullifier.
9. Merkle allocation leaf with a per-subject cap.

Resolvers must be read-only. If a resolver returns `bytes32(0)` as the subject
key, the manager must revert.

## Data Model

Recommended phase configuration:

```solidity
struct MintPhaseConfig {
    bool exists;
    bool paused;
    uint64 startTime;
    uint64 endTime;
    address gate;
    uint32 maxBatchQuantity;
    uint16 maxCounters;
    bytes32 configHash;
}
```

Field semantics:

```text
exists             phase has been configured
paused             admin pause for this phase
startTime          zero means no lower time bound
endTime            zero means no upper time bound
gate               optional validation module
maxBatchQuantity   zero means no per-call cap
maxCounters        maximum enabled counters this phase may evaluate
configHash         optional hash of offchain/operator config
```

Recommended counter configuration:

```solidity
struct MintCounterConfig {
    bool exists;
    bool enabled;
    CounterScope scope;
    CounterKeyMode keyMode;
    CounterUpdateMode updateMode;
    CounterCapMode capMode;
    CounterDeltaMode deltaMode;
    uint64 cap;
    uint64 increment;
    address resolver;
    bytes32 configHash;
}
```

Field semantics:

```text
exists      counter has been configured for the phase
enabled     disabled counters are ignored but remain in history
scope       whether value is shared globally, by collection, or by phase
keyMode     key derivation method
updateMode  whether to add quantity or one per batch
capMode     whether the cap is absent, static, or resolver-provided
deltaMode   whether increment is static or resolver-provided
cap         static cap; ignored when capMode is NONE; exact cap when capMode is STATIC, where zero means zero allowed
increment   static increment; zero means default one unit
resolver    required for CUSTOM_RESOLVER, RESOLVER cap, or RESOLVER delta
configHash  optional hash of offchain/operator config
```

Primary manager state:

```solidity
address public mintLedger;
address public moduleRegistry;

mapping(uint256 => mapping(bytes32 => MintPhaseConfig)) public phases;
mapping(uint256 => mapping(bytes32 => bytes32[])) private _phaseCounterIds;
mapping(uint256 => mapping(bytes32 => mapping(bytes32 => MintCounterConfig))) public counterConfigs;
mapping(uint256 => mapping(bytes32 => mapping(address => bool))) public phaseExecutors;
mapping(uint256 => mapping(bytes32 => bytes32)) public phasePolicyHashes;
```

Primary ledger state:

```solidity
struct LedgerCounterPolicy {
    bool enabled;
    CounterCapMode capMode;
    CounterDeltaMode deltaMode;
    uint64 staticCap;
    uint64 staticIncrement;
    bytes32 counterConfigHash;
}

mapping(address => bool) public ledgerWriters;
mapping(address manager => mapping(uint256 collectionId => mapping(bytes32 phaseId => bytes32 policyHash)))
    public registeredPhasePolicyHashes;
mapping(address manager => mapping(uint256 collectionId => mapping(bytes32 phaseId => mapping(bytes32 counterId => LedgerCounterPolicy))))
    public registeredCounterPolicies;
mapping(bytes32 => uint64) public counterValues;
mapping(bytes32 => bool) public authorizationUsed;
mapping(bytes32 => bool) public nullifierUsed;
```

The ledger must not depend on an arbitrary manager callback to "discover" the
active policy hash during consumption. The manager registers or updates
`registeredPhasePolicyHashes[manager][collectionId][phaseId]` through an
authorized configuration path before the phase can mint. During consumption the
ledger verifies that the supplied `policyHash` equals that registered value and
then repeats cap checks against `registeredCounterPolicies`. In launch v1, the
ledger rejects resolver cap/delta modes and verifies supplied `cap` equals
`staticCap` for `STATIC`, `cap` is ignored for `NONE`, and supplied `increment`
equals `staticIncrement`. This keeps ledger verification implementable and
auditable while still ensuring events bind to the active manager policy.

Launch v1 has one active registered policy hash per
`(manager, collectionId, phaseId)`. Multiple concurrently valid policy hashes
are not allowed unless a later ADR defines a ticket-transition window. Any
phase configuration change that changes `policyHash` must update the manager
state, registered phase hash, and registered counter policies atomically in the
same governance execution before the new phase can mint. Tightening changes may
execute through the
immediate path; loosening changes and ledger replacement are
`DELAYED_LOOSENING` actions under ADR 0004. Frozen phases cannot move to a
different ledger, and a ledger replacement cannot reset or bypass counters for
that frozen policy.

`counterValues` is keyed by:

```solidity
bytes32 valueKey = keccak256(abi.encode(
    COUNTER_VALUE_DOMAIN,
    uint256(block.chainid),
    address(mintLedger),
    counterScope,
    effectiveCollectionId,
    effectivePhaseId,
    counterId,
    subjectKey
));
```

For `GLOBAL`, `effectiveCollectionId` and `effectivePhaseId` are zero. For
`COLLECTION`, `effectivePhaseId` is zero. For `PHASE`, both are included.

`authorizationUsed` is for signed tickets, drop IDs, or other external mint
authorizations returned by a gate.

`nullifierUsed` is for privacy-preserving or commitment-based claim systems
where replay protection should not depend on a public recipient address.
Authorization IDs and nullifiers must be separately domain-separated even if
they share an internal storage pattern.

## Durable Mint Ledger

`StreamMintLedger` should be deliberately small. It owns the irreversible
accounting facts and little else:

1. Counter values are monotonic.
2. Authorization IDs are consumed at most once.
3. Nullifiers are consumed at most once.
4. Only authorized manager contracts can write.
5. Every write emits enough data for indexers to reconstruct the accounting
   trail.

Recommended ledger interface:

```solidity
struct CounterConsumption {
    bytes32 valueKey;
    uint256 collectionId;
    bytes32 phaseId;
    bytes32 counterId;
    bytes32 subjectKey;
    address payer;
    address recipient;
    address authorizer;
    address executor;
    uint64 increment;
    uint64 cap;
    bytes32 contextHash;
    bytes32 resolutionHash;
}

interface IStreamMintLedger {
    function registerPhasePolicy(
        address manager,
        uint256 collectionId,
        bytes32 phaseId,
        bytes32 policyHash,
        bytes32[] calldata counterIds,
        LedgerCounterPolicy[] calldata counterPolicies
    ) external;

    function consume(
        CounterConsumption[] calldata consumptions,
        bytes32 authorizationId,
        bytes32[] calldata nullifiers,
        bytes32 policyHash
    ) external;

    function counterValue(bytes32 valueKey) external view returns (uint64);

    function isAuthorizationUsed(bytes32 authorizationId)
        external
        view
        returns (bool);

    function isNullifierUsed(bytes32 nullifier)
        external
        view
        returns (bool);
}
```

The manager computes projected counter values before calling the ledger. The
ledger repeats the final cap checks before writing so that the durable
accounting contract is not a blind event recorder.

Ledger events:

```solidity
event MintLedgerCounterConsumed(
    bytes32 indexed valueKey,
    uint256 indexed collectionId,
    bytes32 indexed phaseId,
    bytes32 counterId,
    bytes32 subjectKey,
    address payer,
    address recipient,
    address authorizer,
    address executor,
    uint64 increment,
    uint64 newValue,
    uint64 cap,
    bytes32 contextHash,
    bytes32 resolutionHash,
    bytes32 policyHash
);

event MintLedgerAuthorizationConsumed(
    bytes32 indexed authorizationId,
    bytes32 indexed policyHash
);

event MintLedgerNullifierConsumed(
    bytes32 indexed nullifier,
    bytes32 indexed policyHash
);

event MintLedgerWriterUpdated(address indexed writer, bool allowed);
```

The ledger should not know about ETH, ERC-721 ownership, sale prices, display
labels, or UI metadata.

## Policy Fingerprints

Every configured phase should have a canonical `policyHash`. The hash should
commit to the complete active policy that affects whether a mint can happen:

1. `collectionId` and `phaseId`.
2. Phase timing, pause state, gate, and batch limits.
3. Ordered counter IDs and all enabled counter configs.
4. Resolver and gate module addresses.
5. Pinned module codehashes if configured.
6. Executor set hash.
7. Phase metadata hash.
8. The manager and ledger addresses.
9. Chain ID.

Recommended view:

```solidity
function phasePolicyHash(uint256 collectionId, bytes32 phaseId)
    public
    view
    returns (bytes32);
```

Normative preimage:

```solidity
bytes32 policyHash = keccak256(abi.encode(
    POLICY_DOMAIN,
    uint256(block.chainid),
    address(this),
    address(ledger),
    address(moduleRegistry),
    uint16(schemaVersion),
    uint256(collectionId),
    bytes32(phaseId),
    bytes32(phaseConfigHash),
    bytes32(orderedCounterConfigHash),
    bytes32(executorSetHash),
    bytes32(modulePinSetHash),
    bytes32(phaseMetadataHash)
));
```

All component hashes must themselves use `abi.encode` with explicit field order
and type widths. Packed encodings and JSON/string concatenation are not valid
for authority hashes.

Every mint event, ledger consumption event, signed ticket, and preview response
should include the active `policyHash`. If a signed ticket was issued against an
older hash, the state-changing mint must reject it unless the phase explicitly
supports that older hash through a stricter configured gate.

Policy hashes make long-lived operation easier because users, artists, operators,
indexers, and auditors can tie a mint to the exact policy that was active at the
time.

## Mint Requests

Batch mints should be first-class. The manager should not rely on callers to
pre-split single mints.

```solidity
struct MintBatch {
    uint256 collectionId;
    bytes32 phaseId;
    address payer;
    address authorizer;
    address[] initialRecipients;
    address[] beneficiaries;
    bytes[] tokenData;
    bytes32[] mintCommitments;
    bytes32 contextHash;
    bytes resolverData;
}
```

Launch token-data ownership decision:

```text
Core role: HASH_ONLY_CORE_FACT
Metadata role: renderer-visible tokenData bytes
```

Core stores only `tokenDataHash = keccak256(abi.encode(tokenData))` or an
equivalent manager-supplied hash already committed by the signed ticket. It
does not store renderer-visible token data bytes. If a collection's renderer
requires token data before the ERC-721 receiver callback can observe the token,
the `PREPARED_MINT` path must write the bytes or a hash-bound URI/ref into
`StreamCollectionMetadata` before `completePreparedMintFromManager`. If the
collection does not require renderer-visible token data at mint, the hash is
still part of the mint commitment and event trail.

Rules:

1. `beneficiaries.length > 0`.
2. `initialRecipients.length == beneficiaries.length`.
3. `beneficiaries.length == tokenData.length`.
4. `beneficiaries.length == mintCommitments.length`.
5. No initial recipient or beneficiary may be `address(0)`.
6. For ordinary direct mints, `initialRecipients[i] == beneficiaries[i]`.
7. For custody-based sale settlement, `initialRecipients[i]` is the custody or
   settlement contract and `beneficiaries[i]` is the intended final owner or
   economic recipient.
8. `payer` may be `address(0)` only for executor-only flows that do not need a
   payer counter key.
9. `authorizer` may be `address(0)` unless the phase gate or resolver requires
   a known signer, contract wallet, profile authority, or settlement authority.
10. `tokenData` is opaque bytes. Renderer/schema code may interpret it as
    UTF-8, JSON, CBOR, or another format, but Core and the mint manager do not
    parse it.
11. Each `tokenData[i]` must satisfy the collection metadata launch limit
    `MAX_TOKEN_DATA_BYTES`, and the batch must satisfy any manager-level total
    calldata/gas cap. Oversized token data reverts before ledger consumption,
    Core prepare, payment settlement, or entropy registration.
12. `contextHash` is optional, but should be nonzero for signed/drop/auction
   flows that need a stable external reference.

### Recipient Binding

No live mint path may use `tx.origin` as payer, recipient, executor, or
authorizer. These roles are explicit:

```text
executor   msg.sender calling StreamMintManager
payer      account whose payment/counter identity is used
initialRecipient  account receiving each ERC-721 mint
beneficiary       intended final owner or economic recipient
authorizer signer, contract wallet, profile authority, or sale adapter
```

Signed or drop-authorized mints must bind initial recipients and beneficiaries
through canonical hashes:

```solidity
bytes32 initialRecipientsHash = keccak256(abi.encode(batch.initialRecipients));
bytes32 beneficiariesHash = keccak256(abi.encode(batch.beneficiaries));
bytes32 tokenDataHash = keccak256(abi.encode(batch.tokenData));
bytes32 mintCommitmentsHash = keccak256(abi.encode(batch.mintCommitments));
```

Canonical signed ticket payload:

```solidity
struct MintTicket {
    uint256 chainId;
    address manager;
    address ledger;
    uint256 collectionId;
    bytes32 phaseId;
    address executor;
    address payer;
    address authorizer;
    bytes32 initialRecipientsHash;
    bytes32 beneficiariesHash;
    bytes32 tokenDataHash;
    bytes32 mintCommitmentsHash;
    uint256 quantity;
    bytes32 contextHash;
    bytes32 policyHash;
    bytes32 nonce;
    uint64 deadline;
}
```

Rules:

1. The state-changing mint recomputes every hash from calldata.
2. A ticket is invalid if chain ID, manager, ledger, collection ID, phase ID,
   initial recipient set, beneficiary set, token data, mint commitment, payer,
   executor, authorizer, quantity, context hash, policy hash, nonce, or
   deadline differs from the signed payload.
3. Contract-wallet signatures use ERC-1271.
4. Sale/drop adapters that do not use signed tickets must still pass explicit
   `payer`, `initialRecipients`, and `beneficiaries` and must emit the
   authority source used.

The manager entrypoint should be non-payable:

```solidity
function mint(
    MintBatch calldata batch,
    bytes calldata gateData
) external returns (uint256 firstTokenId, uint256 quantity);
```

ETH and ERC-20 payments should be handled by a sale or settlement adapter that
calls this function after its own checks.

## Executor Authorization

The manager should only accept mints from authorized executors for the specific
collection and phase:

```solidity
function setPhaseExecutor(
    uint256 collectionId,
    bytes32 phaseId,
    address executor,
    bool allowed
) external;
```

Examples of executors:

1. Primary sale settlement contract.
2. Drop execution contract.
3. Auction settlement contract.
4. Artist reserve allocator.
5. Future claim contract.

This makes the manager a policy and accounting layer, not a public payment
router. Public mint UX can still exist through a public sale adapter.

## Gate Contracts

Some phases need validation beyond simple counters and time windows. Examples:

1. Merkle allowlists.
2. EIP-712 signed mint tickets.
3. TDH signer approvals.
4. Auction settlement proofs.
5. Curator reward claims.

The manager should support an optional gate per phase:

```solidity
interface IStreamMintGate {
    struct GateResult {
        bytes32 authorizationId;
        bytes32[] nullifiers;
        address authorizer;
        uint64 maxQuantity;
        bytes32 gateHash;
    }

    function validateMint(
        address manager,
        address executor,
        uint256 collectionId,
        bytes32 phaseId,
        address payer,
        address authorizer,
        address[] calldata initialRecipients,
        address[] calldata beneficiaries,
        bytes32 contextHash,
        bytes32 policyHash,
        bytes calldata gateData
    ) external view returns (GateResult memory);
}
```

Gate behavior:

1. If `authorizationId != bytes32(0)`, the manager must ensure it has not been
   used before and then ask the ledger to consume it before calling Core.
2. If `nullifiers` is non-empty, the manager must ensure each nullifier has not
   been used before and then ask the ledger to consume them before calling Core.
3. If `authorizer != address(0)`, the manager should pass it into counter
   resolution and emit it in mint events.
4. If `maxQuantity != 0`, the batch quantity must be less than or equal to that
   gate limit.
5. `gateHash` should commit to gate-specific evidence, such as a Merkle root,
   ticket digest, settlement digest, or privacy proof public inputs.

Gate validation is view-only. Nonce consumption and replay protection live in
the ledger so the final accounting source is centralized.

Gates should validate eligibility, signatures, proofs, and external context.
Durable allowance consumption should use configured counters. If a gate needs a
special accounting identity, the phase should configure a `CUSTOM_RESOLVER`
counter for that identity rather than letting the gate silently override durable
counter keys.

## Signed Mint Tickets

Signed tickets should be a first-class gate type, not a one-off custom branch in
the manager. The recommended ticket gate uses EIP-712 typed data, supports
ERC-1271 smart-wallet signatures, and exposes ERC-5267 domain information.

Signed mint gates must use the canonical `MintTicket` shape defined in
`Recipient Binding`. This section does not define a second struct. The ticket
binds chain ID, manager, ledger, collection ID, phase ID, executor, payer,
authorizer, initial-recipient hash, beneficiary hash, token data hash, mint
commitment hash, quantity, context hash, policy hash, nonce, and deadline.

Ticket rules:

1. `policyHash` must equal the active phase policy hash.
2. `deadline` must be enforced in the state-changing mint path.
3. `authorizationId` should be derived from the full canonical ticket hash,
   including chain ID, manager, ledger, collection ID, phase ID, executor,
   authorizer, payer, initial-recipients hash, beneficiaries hash, token data
   hash, mint commitments hash, quantity, context hash, policy hash, nonce, and
   deadline.
4. EOA signatures should use ECDSA recovery.
5. Contract-wallet signatures should use ERC-1271.
6. The gate should expose ERC-5267 domain introspection when it owns the typed
   data domain.
7. Replay protection belongs in the ledger, not only in the ticket gate.

EIP-712 provides typed-data structure and signing UX, but it does not provide
replay protection by itself. Nonces, authorization IDs, deadlines, chain ID,
manager address, ledger address, and policy hash must all be part of the
design.

## Smart Account Posture

The mint subsystem should treat account abstraction as normal:

1. Do not use `tx.origin`.
2. Keep `executor`, `payer`, `recipient`, `authorizer`, and counter subject as
   separate concepts.
3. Allow ERC-1271 signatures anywhere a user authorization may come from a
   wallet.
4. Include the actual executor in policy checks and events.
5. If trusted forwarders are supported, use an explicit trusted-forwarder list
   and include the resolved sender in events and policy evaluation.
6. Counter resolvers should be able to map a transaction to a wallet, profile,
   delegation root, signed beneficiary, or privacy-preserving subject without
   changing the manager.

## Module Registry

Gates and resolvers should be registered before a phase can use them. This
keeps the manager generic while still making module risk visible.

Recommended registry model:

```solidity
enum ModuleStatus {
    UNKNOWN,
    ACTIVE,
    DEPRECATED,
    BLOCKED
}

struct MintModuleInfo {
    ModuleStatus status;
    bytes4 interfaceId;
    uint32 semanticVersion;
    bytes32 codehash;
    bytes32 metadataHash;
    uint32 gasLimit;
}

interface IStreamMintModuleRegistry {
    function moduleInfo(address module)
        external
        view
        returns (MintModuleInfo memory);

    function isModuleActive(address module, bytes4 interfaceId)
        external
        view
        returns (bool);
}

event MintModuleMetadata(
    address indexed module,
    bytes32 metadataHash,
    string metadataURI
);
```

Registry requirements:

1. A gate must support the gate interface ID through ERC-165.
2. A counter resolver must support the resolver interface ID through ERC-165.
3. `ACTIVE` modules may be configured for new phase policy.
4. `DEPRECATED` modules remain readable but should not be configured for newly
   opened policy unless governance explicitly allows it.
5. `BLOCKED` modules must not be configured and should cause state-changing
   mints to revert if they are still referenced.
6. If `codehash` is nonzero, the manager should verify the module codehash when
   configuring policy and while minting.
7. `metadataURI` is event/UI data; `metadataHash`, `interfaceId`, `status`, and
   `codehash` are the durable security signals.
8. `gasLimit` may be used to bound module calls where the implementation elects
   to use limited-gas `staticcall`.

A frozen `policyHash` may continue to reference a module that later becomes
`DEPRECATED` if the module codehash still matches the hash pinned in the phase
policy and the registry has not marked it `BLOCKED`. New phases cannot choose a
deprecated module unless an explicit delayed governance action allows that
module for a named phase. If a module is `BLOCKED` because of an incident,
state-changing mints revert even for frozen or previously signed policy hashes.
This makes deprecation a forward-looking lifecycle signal and blocking a safety
stop.

This registry should be intentionally boring. It is not a plugin VM; it is a
typed allowlist with versioning, code identity, and lifecycle status.

## Mint Execution Order

Canonical state-changing mint sequence:

1. Load phase config.
2. Check phase exists.
3. Check `msg.sender` is an allowed executor.
4. Check phase is not paused.
5. Check time bounds.
6. Check array lengths and nonzero initial recipients and beneficiaries.
7. Check `maxBatchQuantity`.
8. Compute active `policyHash`.
9. Check configured gate and resolver modules against the module registry.
10. Call optional gate and validate returned constraints.
11. Load all enabled counters for the phase.
12. Resolve counter keys, dynamic caps, and dynamic increments for every counter
    and every relevant token or batch.
13. Aggregate projected increments by `(counterId, valueKey)`.
14. Check every projected counter value against its cap using current ledger
    values.
15. Ask `StreamMintLedger` to verify `policyHash` against the ledger's
    registered hash for `(manager, collectionId, phaseId)`, repeat cap checks,
    and consume counter increments, authorization ID, and nullifiers.
16. For each token, Core writes token identity, collection serial,
    `tokenDataHash`, and mapping-existence status.
17. Core registers entropy state through the coordinator. This registration
    cannot call external randomness providers.
18. The authorized mint manager, sale adapter, or resolver hook records any
    required token-level primary or royalty snapshot after Core has created
    authoritative token identity and before any untrusted receiver callback.
    Core stores no revenue assignment or snapshot state.
19. Core calls `_safeMint(initialRecipient, tokenId)`. This is the first point
    where an untrusted recipient callback can run.
20. Emit manager mint events with `policyHash`.

Ledger accounting should happen before the Core mint calls. If any Core mint
reverts, EVM rollback reverts the ledger updates too.
The invariant is: no external untrusted callback executes before counter
consumption, identity mapping, entropy registration, and required royalty
snapshot are complete for that token.

For paid primary mints, launch must use exactly one of the named orchestration
paths in `docs/revenue-splits-and-royalties.md`:

1. `PRE_REVENUE_SINGLE_STEP`: sale adapter records split-wallet deposit or
   escrow before calling the mint manager, and token-level primary overrides or
   required mint-time royalty snapshots are unavailable. If the phase configures
   a `RECIPIENT`-keyed counter, every `initialRecipient` must equal its
   corresponding `beneficiary`, or the mint reverts with
   `MintSingleStepRecipientMismatch`. Custody settlement that needs a differing
   initial recipient must use `PREPARED_MINT`.
2. `PREPARED_MINT`: mint manager and ledger validate/consume policy, Core
   `prepareMintFromManager` allocates token identity without an ERC-721
   transfer, resolver snapshots required token-level economics, sale adapter
   deposits or escrows native ETH, and Core `completePreparedMintFromManager`
   performs `_safeMint`.

No paid mint may call `_safeMint` to an untrusted recipient before ledger
consumption, Core identity mapping, entropy registration, required assignment
snapshots for the chosen path, and revenue accounting are complete.
The mint manager owns the top-level non-reentrant operation lock for
`PREPARED_MINT`; Core prepare/complete, resolver snapshot hooks, ledger
consumption, and sale-adapter callbacks must all run under that manager-owned
operation context or an equivalent shared operation ID that prevents
interleaving with another mint, transfer, burn, release, escrow flush, or
snapshot for the prepared token.

Duplicate beneficiaries, duplicate initial recipients, or duplicate counter keys
in a batch must not bypass caps. Launch implementation must aggregate projected
increments before writing state so all counters are evaluated against the
complete batch. Sequential fallback is not launch-conformant unless a later ADR
defines and tests it.

## Events

Configuration events:

```solidity
event MintPhaseConfigured(
    uint256 indexed collectionId,
    bytes32 indexed phaseId,
    bytes32 configHash,
    bytes32 policyHash
);

event MintPhasePaused(
    uint256 indexed collectionId,
    bytes32 indexed phaseId,
    bool paused
);

event MintPhaseExecutorUpdated(
    uint256 indexed collectionId,
    bytes32 indexed phaseId,
    address indexed executor,
    bool allowed
);

event MintPhaseGateUpdated(
    uint256 indexed collectionId,
    bytes32 indexed phaseId,
    address indexed gate,
    bytes32 policyHash
);

event MintCounterConfigured(
    uint256 indexed collectionId,
    bytes32 indexed phaseId,
    bytes32 indexed counterId,
    CounterScope scope,
    CounterKeyMode keyMode,
    CounterUpdateMode updateMode,
    CounterCapMode capMode,
    CounterDeltaMode deltaMode,
    uint64 cap,
    uint64 increment,
    address resolver,
    bytes32 configHash,
    bytes32 policyHash
);

event MintCounterEnabled(
    uint256 indexed collectionId,
    bytes32 indexed phaseId,
    bytes32 indexed counterId,
    bool enabled,
    bytes32 policyHash
);

event MintCounterResolverUpdated(
    uint256 indexed collectionId,
    bytes32 indexed phaseId,
    bytes32 indexed counterId,
    address resolver,
    bytes32 policyHash
);

event MintLedgerUpdated(
    address indexed oldLedger,
    address indexed newLedger
);

event MintModuleRegistryUpdated(
    address indexed oldRegistry,
    address indexed newRegistry
);
```

Mint events:

```solidity
// Optional mirror if the implementation emits consumption from the manager in
// addition to the ledger event.
event MintCounterConsumed(
    uint256 indexed collectionId,
    bytes32 indexed phaseId,
    bytes32 indexed counterId,
    bytes32 subjectKey,
    address payer,
    address recipient,
    address authorizer,
    address executor,
    uint256 tokenId,
    uint64 increment,
    uint64 newValue,
    uint64 cap,
    bytes32 contextHash,
    bytes32 resolutionHash,
    bytes32 policyHash
);

event MintBatchExecuted(
    uint256 indexed collectionId,
    bytes32 indexed phaseId,
    address indexed executor,
    address payer,
    address authorizer,
    uint256 firstTokenId,
    uint256 quantity,
    bytes32 contextHash,
    bytes32 gateHash,
    bytes32 policyHash
);

event MintAuthorizationConsumed(
    uint256 indexed collectionId,
    bytes32 indexed phaseId,
    bytes32 indexed authorizationId,
    bytes32 policyHash
);
```

These events should be sufficient for offchain systems to reconstruct phase
policy, executor rights, counter configuration, module status, and allowance
consumption.

## Errors

Use typed errors:

```solidity
error MintPhaseDoesNotExist(uint256 collectionId, bytes32 phaseId);
error MintPhasePaused(uint256 collectionId, bytes32 phaseId);
error MintPhaseNotStarted(uint256 collectionId, bytes32 phaseId, uint256 startTime);
error MintPhaseEnded(uint256 collectionId, bytes32 phaseId, uint256 endTime);
error MintExecutorNotAllowed(uint256 collectionId, bytes32 phaseId, address executor);
error MintArrayLengthMismatch();
error MintZeroQuantity();
error MintZeroRecipient(uint256 index);
error MintPayerRequired();
error MintSingleStepRecipientMismatch(uint256 index);
error MintBatchQuantityLimitExceeded(uint256 requested, uint256 maxAllowed);
error MintTooManyCounters(uint256 configured, uint256 maxAllowed);
error MintCounterDoesNotExist(uint256 collectionId, bytes32 phaseId, bytes32 counterId);
error MintCounterLimitExceeded(bytes32 counterId, bytes32 subjectKey, uint256 requestedTotal, uint256 cap);
error MintInvalidCounterSubject(bytes32 counterId);
error MintInvalidCounterIncrement(bytes32 counterId);
error MintContextHashRequired(bytes32 counterId);
error MintInvalidGate();
error MintInvalidCounterResolver(bytes32 counterId);
error MintModuleNotActive(address module, bytes4 interfaceId);
error MintModuleCodehashChanged(address module, bytes32 expected, bytes32 actual);
error MintPolicyHashMismatch(bytes32 expected, bytes32 actual);
error MintAuthorizationAlreadyUsed(bytes32 authorizationId);
error MintNullifierAlreadyUsed(bytes32 nullifier);
error MintGateQuantityExceeded(uint256 requested, uint256 maxAllowed);
error MintSignatureExpired(uint256 deadline);
error MintInvalidSignature();
```

## Read API

Operator and frontend reads:

```solidity
function phaseConfig(uint256 collectionId, bytes32 phaseId)
    external
    view
    returns (MintPhaseConfig memory);

function isPhaseExecutor(uint256 collectionId, bytes32 phaseId, address executor)
    external
    view
    returns (bool);

function phaseCounterIds(uint256 collectionId, bytes32 phaseId)
    external
    view
    returns (bytes32[] memory);

function counterConfig(
    uint256 collectionId,
    bytes32 phaseId,
    bytes32 counterId
) external view returns (MintCounterConfig memory);

function counterValue(
    uint256 collectionId,
    bytes32 phaseId,
    bytes32 counterId,
    bytes32 subjectKey
) external view returns (uint64);

function rawCounterValue(bytes32 valueKey) external view returns (uint64);

function remainingForCounter(
    uint256 collectionId,
    bytes32 phaseId,
    bytes32 counterId,
    bytes32 subjectKey
) external view returns (uint64);

function resolveCounter(CounterKeyContext calldata context)
    external
    view
    returns (CounterResolution memory);

function phasePolicyHash(uint256 collectionId, bytes32 phaseId)
    external
    view
    returns (bytes32);

function isAuthorizationUsed(bytes32 authorizationId)
    external
    view
    returns (bool);

function isNullifierUsed(bytes32 nullifier)
    external
    view
    returns (bool);
```

Preview reads:

```solidity
struct CounterPreview {
    bytes32 counterId;
    bytes32 subjectKey;
    bytes32 valueKey;
    uint64 current;
    uint64 increment;
    uint64 projected;
    uint64 cap;
    bool allowed;
    bytes32 resolutionHash;
}

struct MintPreview {
    bool allowed;
    bytes4 reason;
    bytes32 policyHash;
    bytes32 gateHash;
    uint256 quantity;
    CounterPreview[] counters;
}

function canMint(
    MintBatch calldata batch,
    address executor,
    bytes calldata gateData
) external view returns (MintPreview memory);
```

`canMint()` should never be the source of truth. It is a frontend/operator
helper. The state-changing `mint()` function must repeat all checks.

## Admin Model

Configuration writes should use the same admin authority model as the rest of
Stream:

1. Global admin can configure any phase.
2. Collection admin can configure phases only for that collection if the admin
   system exposes collection-scoped permissions for this contract.
3. Function-specific admins can be authorized for narrow operations such as
   pausing a phase or updating metadata.

Admin writes:

```solidity
function configurePhase(
    uint256 collectionId,
    bytes32 phaseId,
    MintPhaseConfig calldata config
) external;

function configureCounter(
    uint256 collectionId,
    bytes32 phaseId,
    bytes32 counterId,
    MintCounterConfig calldata config
) external;

function setCounterEnabled(
    uint256 collectionId,
    bytes32 phaseId,
    bytes32 counterId,
    bool enabled
) external;

function setPhasePaused(
    uint256 collectionId,
    bytes32 phaseId,
    bool paused
) external;

function setPhaseMetadata(
    uint256 collectionId,
    bytes32 phaseId,
    bytes32 metadataHash,
    string calldata metadataURI
) external;

function setMintLedger(address newLedger) external;

function setModuleRegistry(address newRegistry) external;
```

Admin checks must use explicit role constants or action IDs for each protected
operation. If selectors are retained for compatibility, every permissioned
function must use its own exact selector and deployment tests must prove that no
two distinct protected operations share an authorization selector. This avoids
the current pattern where unrelated selectors can accidentally gate a function.

For long-lived operation, admin changes should distinguish tightening from
loosening:

1. Immediate changes may pause a phase, reduce caps, shorten end times, remove
   executors, block modules, or freeze policy.
2. Delayed changes should be required to increase caps, extend windows, add
   executors, loosen gates, change resolver identity, or point at a new ledger.
   Ledger replacement is always a delayed loosening because it can otherwise
   reset durable counter values.
   Any policy change whose strictness is ambiguous, including equal-looking
   resolver swaps or module replacements, defaults to delayed governance unless
   the implementation has a formal tightening classifier and emits the before
   and after `policyHash`.
3. The delay mechanism should emit schedule and execute events that include the
   before and after `policyHash`.
4. Collection-scoped admins should not be able to weaken global or cross-phase
   counters unless explicitly authorized.
5. A phase can opt into stricter one-way freeze rules that make later loosening
   impossible.

## Freeze Policy

The manager should support optional one-way phase freezes:

```solidity
mapping(uint256 => mapping(bytes32 => bool)) public phaseFrozen;
```

Once frozen:

1. Counters cannot be removed.
2. Counters cannot be disabled.
3. Counter caps cannot increase.
4. Counter scope, key mode, update mode, and resolver cannot change.
5. New counters cannot be added.
6. Time windows cannot be extended.
7. Gate cannot be loosened.
8. Executors cannot be added.
9. Pause may still be allowed if the product wants emergency stops.
10. Cap mode and delta mode cannot be loosened.
11. Module codehash pins cannot be removed.
12. Policy cannot move to a different ledger.

Counter values must never be decremented. If an operator needs a different
policy, the correct answer is a new phase ID or a stricter future counter, not
rewriting history.

The exact freeze posture should be conservative: freezing should only make a
phase stricter or permanently closed.

## Security Requirements

1. No `tx.origin`.
2. No ETH push payments.
3. No external value movement in the manager.
4. No unbounded loops except over caller-provided mint batch length and a
   bounded counter list.
5. Batch length and enabled counter count should have configurable hard caps.
6. Counter resolvers and gates must not be able to reenter mint execution.
7. `mint()` should use a reentrancy guard if it calls external gates/resolvers
   and then Core.
8. Gate validation must be repeated in the state-changing path.
9. Signed authorization IDs must be domain-separated by chain ID, manager
   address, ledger address, collection ID, phase ID, signer, payer, initial
   recipients, beneficiaries, quantity, nonce, and deadline.
10. The manager must not trust display labels, metadata URIs, or event-only
    strings for accounting authority.
11. `quantity`, collection serials, and counters should use at least `uint64`
    so long-running open collections are not artificially constrained by small
    integer widths.
12. All arithmetic should be checked by Solidity 0.8+.
13. Counter storage keys must be domain-separated by chain ID and ledger
    address.
14. All configured counters must be checked against the complete projected batch
    before minting.
15. Ledger writes must be restricted to authorized manager contracts.
16. The ledger must repeat cap checks and verify the supplied `policyHash`
    against the ledger-registered `(manager, collectionId, phaseId)` hash
    before writing counter values.
17. Policy hashes must be emitted with mint and accounting events.
18. Signed tickets must include the active policy hash and must fail if it does
    not match.
19. ERC-1271 contract-wallet signatures must be supported where signed tickets
    are used.
20. Gate and resolver modules must be checked against ERC-165 and the module
    registry before use.
21. Module codehash pins must be enforced if configured.
22. Authorization IDs and nullifiers must be domain-separated from one another.
23. Resolver-provided increments must be nonzero.
24. Preview APIs must not be trusted for authorization.
25. No live mint path should use ERC-2309-style consecutive minting; normal
    per-token ERC-721 transfer events remain the indexer and marketplace
    friendly path.
26. Recipient reentrancy cannot observe an unregistered token or bypass
    counters because `_safeMint` happens only after ledger consumption,
    identity mapping, entropy registration, and required royalty snapshots.

## Formal Invariants

The implementation should be tested and reviewed against these invariants:

1. Counter values never decrease.
2. A counter value never exceeds its effective cap after a successful mint.
3. Duplicate counter keys in one batch cannot bypass caps.
4. Every successful mint has a corresponding counter-consumption trace unless
   the phase intentionally has no enabled counters.
5. Every successful signed or gated mint has a consumed authorization ID or
   nullifier when the gate returns one.
6. `StreamCore` never mints except through the authorized mint manager.
7. The `policyHash` emitted in mint and ledger events matches the active policy.
8. A stale signed ticket cannot mint under a materially different policy.
9. A blocked module cannot be used for state-changing mint execution.
10. No external recipient callback executes before the token's identity mapping,
    entropy registration, and required royalty snapshot are complete.
10. A frozen phase cannot be loosened.

## Interactions With Existing Contracts

`StreamDrops` should become a mint executor, not a direct caller of Core.

Current fixed-price flow:

```text
StreamDrops -> StreamMinter -> StreamCore
```

Target fixed-price flow:

```text
StreamPrimarySale or StreamDrops
  -> validate signer/drop/payment
  -> execute PRE_REVENUE_SINGLE_STEP or PREPARED_MINT exactly as defined in the revenue spec
  -> StreamMintManager.mint(...)
  -> StreamMintLedger.consume(...)
  -> StreamCore.mintFromManager(...) or prepare/complete pair
```

Current auction-start flow:

```text
StreamDrops -> StreamMinter.mintAndAuction -> StreamCore
```

Target auction-start flow:

```text
StreamDrops or Auction adapter
  -> validate auction/drop context
  -> StreamMintManager.mint(phaseId = auction-settlement or auction-start)
  -> StreamMintLedger.consume(...)
  -> StreamCore.mintFromManager(...)
```

`StreamMinter` can be replaced by `StreamMintManager` before launch. The
preferred launch design is one mint manager contract for phase policy and one
mint ledger contract for durable accounting.

## Implementation Sequence

### Phase 1: Core Mint Boundary

1. Add `mintManager` to Core.
2. Add `mintFromManager()`.
3. Make Core compute the next token ID internally.
4. Remove per-address mint counters from Core.
5. Remove `maxCollectionPurchases` from Core collection data.

### Phase 2: Manager Policy And Accounting

1. Implement `StreamMintLedger`.
2. Implement `StreamMintManager`.
3. Add phase configuration.
4. Add executor authorization.
5. Add generic counter configuration.
6. Add phase, collection, and global counter scopes.
7. Add counter-key derivation modes.
8. Add static caps.
9. Add static increments.
10. Add canonical `policyHash` computation.
11. Add direct read APIs.
12. Add typed errors and events.

### Phase 3: Gates And Counter Resolvers

1. Add optional gate interface support.
2. Add module registry checks.
3. Add signed authorization replay protection in the ledger.
4. Add custom counter resolver support only after the static launch path is
   audited.
5. Add EIP-712 signed ticket gate.
6. Add ERC-1271 smart-wallet signature support.
7. Add TDH/drop gate if needed.
8. Add Merkle gates where product flows require them.
9. Add nullifier support for privacy-preserving claim systems as a future
   extension.

### Phase 4: Integration And Tooling

1. Route fixed-price drops through the manager.
2. Route auction minting through the manager.
3. Connect primary-sale settlement before manager minting.
4. Add admin/operator phase inspection tools.
5. Add explainable preview views.
6. Add indexer docs for phase, policy-hash, module, and counter-consumption
   events.

## Test Requirements

Core tests:

1. Only `mintManager` can call `mintFromManager()`.
2. Core computes global sequential token IDs correctly across collections.
3. Core reverts when the collection is unknown, paused, closed, not yet active
   for minting, or artwork-finality-blocked for new supply.
4. Core reverts when collection supply is exhausted.
5. Core emits `StreamTokenMinted`.
6. Core stores token-to-collection and token-to-collection-serial mappings.

Manager tests:

1. Unknown phase reverts.
2. Unauthorized executor reverts.
3. Paused phase reverts.
4. Start and end times are enforced.
5. Batch quantity cap is enforced.
6. Phase-supply counter is enforced.
7. Recipient counter is enforced.
8. Payer counter is enforced.
9. Collection-scoped counter is shared across phases.
10. Context counter can enforce one execution per context hash.
11. Multiple counters can apply to the same batch simultaneously.
12. Duplicate counter keys in one batch cannot bypass limits.
13. Duplicate counter-key batches are checked by aggregate projected increments,
    not sequential optimistic writes.
14. `CounterCapMode.NONE` is unlimited; `CounterCapMode.STATIC` with
    `staticCap = 0` allows zero mints or is rejected at configuration, never
    treated as unlimited.
15. Batch length mismatches revert.
16. Zero initial recipients or beneficiaries revert.
17. Gate authorization IDs cannot be reused.
18. Gate quantity limits are enforced.
19. Custom counter resolver returning zero reverts.
20. State rolls back if Core mint reverts.
21. Events contain enough data to reconstruct counter consumption.
22. `policyHash` changes when material phase policy changes.
23. Mint rejects a signed ticket with a stale policy hash.
24. Mint rejects a signed ticket when initial recipients, beneficiaries, payer,
    executor, authorizer, token data, mint commitments, quantity, context hash,
    or policy hash differ.
25. ERC-1271 ticket signatures are accepted when valid.
26. Blocked modules cannot be used.
27. Module codehash pins are enforced.
28. `canMint()` returns counter previews with current, increment, projected, and
    cap values.
29. A malicious `onERC721Received` recipient cannot observe a token before
    identity mapping and entropy registration exist, and cannot reenter mint or
    entropy request paths to bypass counters.

Future resolver/nullifier tests:

1. Before a resolver/nullifier ADR is accepted, configuring
   `CounterCapMode.RESOLVER`, `CounterDeltaMode.RESOLVER`, `CUSTOM_RESOLVER`,
   or non-empty nullifier consumption reverts before state changes.
2. After a resolver/nullifier ADR is accepted, dynamic resolver caps are
   enforced.
3. Dynamic resolver increments are enforced.
4. Resolver-based accounting is used when configured.
5. Nullifiers cannot be reused.

Ledger tests:

1. Only authorized ledger writers can consume counters.
2. Counter values never decrease.
3. Ledger rejects any projected value above cap.
4. Authorization IDs cannot be reused.
5. Nullifiers cannot be reused.
6. Ledger events include `policyHash`.
7. Multiple consumptions for the same value key aggregate correctly.
8. Ledger verifies the active `policyHash` before writing consumption.

Integration tests:

1. Fixed-price drop executor can mint through manager.
2. Auction executor can mint through manager.
3. Public and allowlist phases can coexist for one collection.
4. Different phase IDs maintain independent counters.
5. Shared collection counters can intentionally span multiple phases.
6. Same account across phases has separate allowance consumption when counters
   are phase-scoped.
7. Revenue settlement can atomically settle funds before mint manager minting.
8. Ledger accounting rolls back if Core minting fails.
9. Smart-account signed tickets can mint through an authorized executor.
10. Fixed-price/drop executors pass explicit payer, initial recipients, and
    beneficiaries and never depend on `tx.origin`.

## Acceptance Criteria

1. `StreamCore` no longer stores public, allowlist, or airdrop per-address
   counters.
2. `StreamCore` no longer stores per-collection max purchase limits.
3. `StreamMintManager` is the only mint policy source.
4. `StreamMintLedger` is the only durable mint accounting source.
5. Phase IDs are arbitrary `bytes32` values.
6. Counter IDs are arbitrary `bytes32` values.
7. A phase can enforce many counters at once.
8. Counter values can be scoped to a phase, collection, or the whole manager.
9. Per-account limits are enforced by counter key, not always by recipient.
10. Batch mints cannot bypass limits through duplicate beneficiaries, duplicate
    initial recipients, or counter resolver behavior.
11. No mint path uses `tx.origin`.
12. No mint policy path pushes ETH.
13. Existing fixed-price and auction product flows can be represented as phase
    IDs plus authorized executors.
14. Frontend/indexer/operator tools can read phase config, counter config,
    counter values, remaining allowance, executor status, and phase metadata.
15. Every phase exposes a canonical `policyHash`.
16. Signed mint tickets include policy hash, nonce, deadline, and domain
    separation.
17. ERC-1271 smart-wallet signatures are supported for signed tickets.
18. Gate and resolver modules are checked through the module registry.
19. Resolver-provided dynamic caps and increments are future extensions unless
    accepted in a later launch-scope decision.
20. Nullifier-based claim replay protection is a future extension unless
    accepted in a later launch-scope decision.
21. `canMint()` returns explainable counter previews, not just a boolean.
22. Freeze policy prevents later loosening of frozen phases.
