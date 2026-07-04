# Mint Policy And Accounting

Specification status: Draft. This document follows
[`docs/spec-policy.md`](spec-policy.md); the decisions formerly tracked
inline are resolved by
[ADR 0009](adr/0009-protocol-v1-open-question-resolutions.md) and
[ADR 0010](adr/0010-world-class-spec-pass.md) and recorded in
[`docs/spec-open-questions.md`](spec-open-questions.md).

This document is the normative home (ADR 0010 decision D3.1) for the Core
mint ABI and token-data ownership, the mint-manager and mint-ledger
interfaces, mint policy hashes and their component domains, counter and
subject-key derivations, the prepared-mint operation identity, the
`MintTicket` typed payload, policy grace windows, and counter continuity
across manager/ledger succession. Other documents — including the protocol
v1 domain-constants mirror table — cite these definitions and must not
restate them; where an older document conflicts, this document wins and
the conflict is a defect to fix (ADR 0010 decision D3.2).

This document specifies moving mint limits and mint accounting out of
`StreamCore` into a dedicated mint subsystem made of `StreamMintManager` and
`StreamMintLedger`. 6529Stream is permanent infrastructure for the 6529
network: the first production deployment is the permanent system, and every
requirement here is classified by what can ever change about it — Permanent,
Replaceable, or Operational per [`docs/spec-policy.md`](spec-policy.md) —
rather than by launch phase. `StreamCore` should remain the canonical ERC-721
contract, keep `ERC721Enumerable`, and mint only after an authorized mint
manager has validated policy and consumed allowance through the ledger.
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
  - v1 counter keys for recipient, payer, executor, constant, and context
  - extension resolver-backed profile, delegation, and custom counter keys
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

Mint Executors (registry-governed sale adapters; see
docs/stream-sales-and-auctions.md)
  - fixed-price sale adapters
  - drop executors
  - auction settlement executors
  - allowlist or signed-claim executors

Optional Gate/Resolver Contracts
  - Merkle allowlist validation
  - EIP-712 ticket validation
  - ERC-1271 smart-wallet signature validation
  - burn-to-mint and delegate-registry gates
  - extension 6529 profile/delegation counter-key resolution
  - privacy-preserving nullifier resolution (extension)
```

The manager is the only contract authorized to call the Core mint function. The
ledger accepts writes only from authorized managers. Sale and drop contracts call
the manager; the manager validates mint policy, consumes allowance through the
ledger, and then calls Core.

## Protocol v1 Scope

Protocol v1 mint scope should be auditable and intentionally smaller than the
full counter model this document defines:

1. Core-owned global token ID allocation.
2. Fixed-size, capped-open, and uncapped-open collection minting.
3. Explicit recipient and payer binding; no `tx.origin`.
4. Static phase caps, static counter caps, and static counter deltas.
5. Counter key modes for recipient, payer, executor, constant, and explicit
   context hash where needed.
6. The Merkle allowlist static cap mode (`MERKLE_STATIC`): per-wallet
   differentiated allocations proven against a pinned root, with no
   resolver (ADR 0010 decision D5.3).
7. Phase, collection, and `GLOBAL` counter scopes (ADR 0010 decision D5.9).
8. EIP-712/ERC-1271 signed mint tickets with pinned typehashes, an
   explicit `authorizerKind` model, and a signer-side revocation surface.
9. Module registry with interface and codehash checks for approved gates,
   resolvers, and sale-adapter executors.
10. One durable ledger for counter, authorization, and gate-supplied
    nullifier consumption, with policy grace windows and Merkle-proofed
    counter continuity across manager/ledger succession.

Excluded from protocol v1 — intentional absence, not deferral; each item
requires its own accepted spec or ADR through the frozen extension mechanisms
before it can exist:

1. Resolver-defined caps (`CounterCapMode.RESOLVER`). The `MERKLE_STATIC`
   cap mode is not a resolver: it is verified inline by the manager with
   no external call.
2. Resolver-defined deltas.
3. Privacy-preserving (zero-knowledge or commitment-scheme) claim systems
   and nullifier resolvers. Plain gate-supplied nullifier consumption is a
   v1 ledger capability used by accepted gate specs such as the
   burn-to-mint gate in
   [`docs/stream-sales-and-auctions.md`](stream-sales-and-auctions.md).
4. General-purpose custom policy VMs.
5. ERC-20 primary payment adapters inside the mint subsystem. Approved-standard
   ERC-20 primary settlement is a protocol v1 requirement, but it lives in the
   revenue and settlement satellites per
   [`docs/revenue-splits-and-royalties.md`](revenue-splits-and-royalties.md);
   the mint manager and ledger stay non-payable and asset-agnostic.
6. Delegated-profile, consolidated-identity, or other resolver-backed counter
   subjects unless a concrete resolver interface, gas cap, registry status, and
   test suite are accepted in that extension's own spec. The genesis
   delegated-minting patterns that need no resolver are specified in
   [`docs/stream-sales-and-auctions.md`](stream-sales-and-auctions.md).
7. ERC-2771 trusted forwarders in mint paths (see Smart Account Posture).

## Current Implementation Baseline

This section is non-normative implementation evidence (spec policy,
Evidence Inside Specs); it records point-in-time slice state and never
weakens a requirement.

The first outside-Core implementation slices now exist:

- CON-012 added Core's `mintManager` pointer, manager-only immediate and
  prepared mint hooks, prepared abort/recovery, and `tokenCollectionIdentity`
  reads in PR #633.
- CON-013 adds `StreamMintLedger` as a static v1 counter and authorization
  replay ledger. It records one active policy hash per
  `(manager, collectionId, phaseId)`, owner-authorized ledger writers,
  deployment-safe static counter policies, monotonic counter values, and
  authorization consumption. It intentionally does not execute phase policy,
  call Core, route `StreamDrops`, collect payment, validate custom gates, or
  support resolver caps/deltas/nullifiers. Until the concrete
  `StreamMintManager` lands, writer authorization is owner-managed and limited
  to deployed contracts; the manager integration PR should add the reviewed
  manager capability check.

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
8. Support wallet, payer, recipient, and context counter-key models from
   genesis, while leaving resolver-backed delegated profile and custom identity
   models to separately accepted extension specs.
9. Support phase-scoped, collection-scoped, and global counters.
10. Support batch mints without allowing duplicate-recipient or duplicate-key
   bypasses.
11. Support executor contracts for paid sales, drops, auctions, reserves, and
   new mint mechanisms.
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
6. ERC-4337 is a supported execution environment, not only an influence:
   payer, executor, recipient, and authorizer are distinct roles, and
   paymaster-sponsored mints are a supported executor pattern (ADR 0010
   decision D5.11; see Smart Account Posture).
7. ERC-2771 forwarding is excluded from the genesis mint subsystem: the
   manager, ledger, gates, and Core mint hooks have no trusted-forwarder
   code path. A forwarder class, if ever wanted, requires its own accepted
   spec.
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
mapping(uint256 tokenId => uint256 collectionId) tokenCollectionId; // current Core name: tokenIdsToCollectionIds
mapping(uint256 tokenId => PreparedMintRecord) preparedMintRecords;
```

V1 Core allocates sequential global token IDs and stores the collection ID
and collection-local serial explicitly in the token identity record
(ADR 0009 decision 1); no serial or collection value is derived from token
ID arithmetic, and the baseline reserved-range derivation must be removed.
Core may still
derive the canonical mapping-exists read from live ownership, burned-token
audit state, and prepared-mint state instead of storing a separate boolean.

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

Core should expose a manager-only mint entrypoint. This block is the
normative home for the Core mint ABI and token-data ownership (ADR 0010
decision D3.1); the collection-metadata and entropy specs cite it and must
not define alternative Core mint shapes.

```solidity
function mintFromManager(
    uint256 collectionId,
    address initialRecipient,
    bytes calldata tokenData,
    bytes32 tokenDataHash,
    bytes32 mintCommitment
) external returns (uint256 tokenId, uint256 collectionSerial);
```

Requirements [MPA-CORE-ABI]:

1. `tokenData` is opaque `bytes` end to end: `MintBatch.tokenData[i]`,
   the Core parameter, and Core storage use the same `bytes` typing.
   Renderer/schema code may interpret it as UTF-8, JSON, CBOR, or another
   format; Core and the manager never parse it.
2. `tokenDataHash` must equal `keccak256(tokenData)`; Core must verify and
   revert on mismatch. V1 Core stores the renderer-visible `tokenData`
   bytes because the genesis metadata renderer consumes them; the hash is
   the sale/manager commitment that prevents a later caller from swapping
   renderer input after policy acceptance. A hash-only or externalized
   token-data storage design needs a separate accepted migration spec
   because it changes renderer and finality assumptions.
3. `mintCommitment` is the typed per-token entropy/mint salt defined by
   the entropy coordinator spec. It replaces the legacy `saltfunO`
   parameter everywhere; no Core mint surface takes `saltfunO`.
4. Core must not take or store `beneficiary` in any mint hook (rule
   restated below); the superseded `mintNext` shape with a beneficiary
   parameter is invalid.
5. Core must emit `TokenCollectionRegistered(tokenId, collectionId,
   serial)` at identity write so event-only identity reconstruction is
   normative (ADR 0010 decision D10.1).

The immediate single-step hook is intentionally minimal. Beneficiary,
mint-commitment, operation ID, price, asset, and authorization evidence belong
to the manager, ledger, sale adapter, and settlement adapter records for that
path. When another satellite needs a Core-observable operation ID before the
ERC-721 receiver callback, the manager must use the prepared path below.
Core enforces collection existence, freeze state, token-data bounds, token-data
hash binding, and supply exhaustion on the manager path. Phase windows,
drop/sale pause policy, eligibility, price, asset, settlement, beneficiary, and
authorization checks are trusted manager responsibilities and must be evidenced
in the manager, ledger, sale adapter, or settlement adapter records.

Protocol v1 should not include persistent standalone token reservations. When
another spec says a token is "reserved," it means either:

1. the token identity is prepared and completed inside the same top-level
   transaction by the mint manager, so any later failure reverts the mapping and
   serial allocation; or
2. a separate accepted reservation ADR has defined expiry, cancellation,
   serial-gap, revenue, and royalty-snapshot rules.

Same-transaction prepared mints carry token-level primary policy, and the
capability is required at genesis: Core must expose the manager-only
two-step internal surface below. It is classified `permanent` in the Core
bytecode planning budget and mandatory conformance gates exercise it (the
`PREPARED_MINT` deployment tests and the collector gas budget artifact in
[`docs/launch-conformance-matrix.md`](launch-conformance-matrix.md)):

```solidity
function prepareMintFromManager(
    uint256 collectionId,
    bytes calldata tokenData,
    bytes32 tokenDataHash,
    bytes32 operationId
) external returns (uint256 tokenId, uint256 collectionSerial);

function completePreparedMintFromManager(
    uint256 tokenId,
    address initialRecipient,
    bytes32 operationId,
    bytes32 mintCommitment
) external;
```

`prepareMintFromManager` writes identity, serial, and existence status but does
not emit an ERC-721 transfer, call the recipient, or reserve entropy/randomizer
state.
`completePreparedMintFromManager` must be called by the same manager flow after
revenue is recorded and before the transaction returns. Completion clears the
prepared record before minting, keeps the global Core completion sentinel active
through the ERC-721 receiver callback, then clears that sentinel only after the
normal mint entropy/randomizer boundary returns for the now-complete token.
Persistent prepared tokens are forbidden in protocol v1 unless the separate
reservation ADR above is accepted. As a recovery escape for a stranded
prepared mint, Core allows the
admin to replace only the `mintManager` pointer while the sentinel is active so
a reviewed replacement manager can call the existing abort hook; other critical
contract pointers remain locked.

Prepared-mint safety rules:

1. The two-step surface is a required genesis Core capability; choosing it
   for a given mint is policy-driven and should happen only when
   token-level primary policy truly needs a token ID before revenue
   recording.
2. `prepareMintFromManager` and `completePreparedMintFromManager` must share the
   same non-reentrant manager execution path; no unrelated external Core mint,
   burn, transfer, or second prepare may interleave while a prepared token is
   pending.
3. Core must bind a prepared token to `tokenId`, `collectionId`, the verified
   renderer-visible `tokenData`, an operation ID or equivalent manager-supplied
   context hash, and the manager address that prepared it. The manager address
   may be retained as private pending Core state rather than exposed through the
   public prepared-record view. Beneficiary, token-data hash, mint-commitment,
   and batch-level commitment hashes remain manager, ledger, sale adapter, or
   settlement evidence and should feed the operation ID.
4. `completePreparedMintFromManager` must verify and clear the
   `PreparedMintRecord` before `_safeMint` or any external receiver callback,
   while retaining a Core-level completion sentinel that blocks unrelated Core
   mint, burn, transfer, approval, admin mutation, and second-prepare paths
   until the completion-time entropy/randomizer boundary finishes. The only
   v1 recovery exception is mint-manager replacement, which lets a
   replacement manager abort a stranded prepared mint without changing admin,
   minter, dependency, randomizer, metadata, or token state.
5. If any later step in the top-level transaction reverts, the prepared mapping,
   collection serial, revenue/royalty snapshot, and any entropy/randomizer state
   reached during completion all revert with the transaction.
6. A prepared token that is not completed in the same top-level manager flow is
   a bug; v1 Core must not expose a durable prepared-token or reservation
   state. If a manager bug strands one anyway, replacing the mint manager and
   aborting through the new manager is an incident-recovery path, not a normal
   reservation lifecycle.
7. `prepareMintFromManager` deliberately does not invoke the entropy
   registration or randomizer request boundary. `completePreparedMintFromManager`
   invokes that boundary only after the pending record is cleared and the token
   is no longer prepared-incomplete, but before Core drops the global completion
   sentinel. Public `requestEntropy(tokenId)`, metadata finalization, transfer,
   burn, and any other token operation outside the manager flow must revert for
   prepared-incomplete tokens or a token whose completion sentinel is still
   active.
8. The per-token `mintCommitment` recorded by the manager or settlement
   satellite must equal the corresponding element already committed by the
   signed `MintTicket.mintCommitmentsHash` or by the equivalent sale
   authorization hash. A prepared mint cannot introduce a new commitment after
   the signed authorization or sale policy was accepted.

Canonical prepared-mint operation boundary. This is the single normative
`OPERATION_DOMAIN` prepared-mint operation derivation (ADR 0010 decision
D3.6); it is the two-level operation-root model implemented by the CON-014
manager, and the earlier flat single-preimage variant of this section is
deleted. The protocol v1 domain-constants table mirrors this derivation
and pins the domain's string preimage and hash.

```solidity
// Level 1: the static request commitment binds the request contents.
bytes32 requestCommitmentHash = keccak256(abi.encode(
    address(payer),
    address(authorizer),
    bytes32(initialRecipientsHash),
    bytes32(beneficiariesHash),
    bytes32(tokenDataArrayHash),
    bytes32(mintCommitmentsHash)
));

// Level 2: the operation root binds the request to chain, contracts,
// phase, policy, replay key, executor, and nonce.
bytes32 operationRoot = keccak256(abi.encode(
    OPERATION_DOMAIN, // keccak256("6529STREAM_PREPARED_MINT_OPERATION_V1")
    uint256(block.chainid),
    address(this),      // mint manager
    address(core),
    address(mintLedger),
    uint256(collectionId),
    bytes32(phaseId),
    bytes32(policyHash),
    bytes32(authorizationId),
    bytes32(requestCommitmentHash),
    bytes32(contextHash),
    address(msg.sender), // executor
    uint256(operationNonce),
    uint256(quantity)
));

// Per-token operation IDs bind each prepared token to the root.
bytes32 operationId = keccak256(abi.encode(
    bytes32(operationRoot),
    uint256(operationNonce),
    uint256(tokenIndex),
    bytes32(tokenDataHash),   // per-token: keccak256(tokenData[i])
    bytes32(mintCommitment)   // per-token: mintCommitments[i]
));

struct PreparedMintRecord {
    bool exists;
    bytes32 operationId;
    uint256 collectionId;
}

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

Requirements [MPA-OPERATION]:

1. Every input term is defined in this document: `initialRecipientsHash`,
   `beneficiariesHash`, `tokenDataArrayHash`, and `mintCommitmentsHash`
   are the canonical batch hashes of `Recipient Binding`;
   `policyHash` is the active phase policy hash; `authorizationId` is the
   ledger replay key; `contextHash` is `MintBatch.contextHash`;
   `operationNonce` is a manager-local monotonic counter;
   `tokenDataHash` and `mintCommitment` are the per-token values for
   `tokenIndex`. The per-token `mintCommitment` is the value the protocol
   v1 mirror table's inputs column labels `salt`, and
   `mintCommitmentsHash` is the value it labels `saltsHash`.
2. Deadline, sale adapter identity, price, asset, and the primary/royalty
   policy hashes are bound transitively, not restated at the root: they
   are inside the signed payload from which `authorizationId` must be
   derived (`MintTicket` per `[MPA-TICKET]`, or the sale authorization per
   `docs/stream-sales-and-auctions.md` `[SSA-AUTH]`). The manager enforces
   `deadline` before consuming the authorization; the sale adapter rejects
   settlement whose sale authorization digest does not map to the
   `authorizationId` it supplied; the resolver snapshot hook re-verifies
   the primary/royalty policy hashes it snapshots. A participant must
   reject any prepared-mint call whose component it owns does not match.
3. The same `operationRoot` must never be reused for a different batch,
   payer, phase, policy hash, or executor; `operationNonce` must increase
   per prepared operation.

Every state-changing contract participating in `PREPARED_MINT` must receive or
derive the same `operationId`: sale adapter, mint manager, ledger, Core
prepare/complete, revenue resolver snapshot hook, completion-time
entropy/randomizer boundary, and escrow/deposit path. A contract must reject a
prepared-mint call
whose operation ID does not match the operation currently locked by the mint
manager. The operation lock is non-reentrant and cannot be reused for a
different token, batch, payer, phase, policy hash, or sale adapter.

Control-flow owner: `StreamMintManager`. User-facing sale adapters call
one manager-owned prepared-mint entrypoint or a sale adapter entrypoint that
immediately delegates to the manager. Core `prepareMintFromManager` and
`completePreparedMintFromManager` are restricted to `msg.sender == mintManager`
and are never independent user flows. Completion must come from the same manager
address that prepared the token; a replacement manager may abort a stranded
prepared mint but cannot redirect completion. The manager calls the restricted
settlement adapter hook between Core prepare and Core complete. If settlement,
resolver snapshot, escrow/deposit, the completion-time entropy/randomizer
boundary, or completion fails inside an all-in-one manager transaction, the
whole transaction reverts and no prepared state persists. If a manager commits
`prepareMintFromManager` in an earlier transaction, or intentionally pauses
after prepare for an out-of-band settlement or review step, the prepared record
persists until the preparing manager completes it or the active manager aborts
it.
The recovery flow below applies only to those already-committed prepared
records, not to rolled-back all-in-one calls.

The manager's non-reentrant operation lock must be externally verifiable
through Core state. Core's `PreparedMintRecord.operationId` is the canonical
shared lock state for each prepared token. Every satellite participating in a
prepared mint, including resolver snapshot hooks, escrow/deposit paths, and
entropy/randomizer helpers, must read `preparedMint(tokenId).operationId` from
Core or receive it from the manager and re-verify against Core. No
satellite may rely solely on a manager-internal private flag it cannot read.

Operation propagation table:

```text
Sale adapter          derives operationId from signed sale/mint authorization and rejects payment settlement mismatch
Mint manager          owns non-reentrant operation lock and rejects nested or different operationId
Mint ledger           consumes counters/authorization only for the manager-supplied operationId
Core prepare          stores operationId in PreparedMintRecord for each allocated token
Resolver snapshot     reads PreparedMintRecord and rejects missing or mismatched operationId
Entropy/randomizer     runs only from completion after the prepared record clears
Escrow/deposit path    emits or stores operationId with the payment settlement record where applicable
Core complete         clears PreparedMintRecord only when operationId matches; clears completion sentinel after entropy/randomizer boundary
```

Recommended manager, ledger, or settlement events:

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

Successful v1 transactions leave no persistent prepared state after
completion: `preparedMint(tokenId).exists` returns false once
`completePreparedMintFromManager` clears the record. During the receiver
callback, the token is live and `preparedMint(tokenId).exists == false`, but
`pendingPreparedMintTokenId` remains set as a completion lock until the
completion-time entropy/randomizer boundary returns. The read exists so other
contracts in the same top-level operation can prove they are snapshotting the
same prepared token, not so operators can create durable reservations.

Required Core behavior [MPA-CORE-MINT]:

1. Revert unless `msg.sender == mintManager`.
2. Revert unless the collection exists, is active for minting, is not closed or
   artwork-finality-blocked for new supply, and data needed for supply exists.
3. Allocate the next token ID inside Core from the single global sequential
   token ID counter (ADR 0009 decision 1). No reserved ranges, namespaces,
   or token ID arithmetic exist; `collectionId` and `collectionSerial` are
   stored explicitly in the token identity record.
4. Allocate the next stable collection-local serial inside Core and store
   it in the token identity record.
5. Revert if collection supply is exhausted for fixed or capped-open
   collections.
6. Store renderer-visible `tokenData`, verify it matches `tokenDataHash`, and
   store token-to-collection identity. The collection-local serial is
   returned from the stored identity record — never derived from the token
   ID — and mapping existence is derived by `tokenCollectionIdentity`.
7. Register bounded entropy state through the entropy coordinator boundary
   before `_safeMint` and before any external receiver callback can
   observe the token. This ordering is the only normative one; the matrix
   entropy-lifecycle gate enforces it at deployment.
8. Mint to `initialRecipient`.
9. Emit `TokenCollectionRegistered` at identity write and return the minted
   token ID and collection-local serial.

The entropy registration hook must be bounded and must not call external
randomness providers from the mint path.

Implementation evidence (non-normative). The current direct-randomizer
Core slice still reaches the legacy randomizer/hash boundary after
`_safeMint`. That interim ordering is not deployment-conformant: the
matrix entropy gate requires identity written and entropy registered
before the `_safeMint` callback, and paid flows that need token-level
economic state before a receiver callback must use `PREPARED_MINT` and
must not depend on entropy state during the callback. The evidence here
exists only to keep the as-built divergence honest until the
entropy-coordinator integration lands.

`initialRecipient` is the address that receives the ERC-721 mint event and the
first ownership state. `beneficiary` is the intended economic/final recipient
known to the manager or sale executor. For ordinary direct mints they are the
same address. For custody-based settlement, `initialRecipient` is the custody or
settlement contract and `beneficiary` is the buyer, claimant, artist, or other
intended final owner. Core does not store `beneficiary` in either manager hook;
the manager, ledger, and sale adapter must keep beneficiary and payment
evidence. Custody flows must emit the later transfer normally so event consumers
can reconstruct the whole path.

The bytecode-constrained v1 Core intentionally does not emit manager-specific
mint or prepared-mint events. Indexers can observe ERC-721
`Transfer`, call `tokenCollectionIdentity`, and consume the richer manager,
ledger, settlement, and prepared-operation events emitted by the satellites.

The existing `StreamCore.mint(uint256,address,string,uint256,uint256)` entrypoint
should be replaced by `mintFromManager` before production deployment.

Burn behavior must preserve the identity mapping used by royalties and audits.
If a token is burned, Core removes ERC-721 ownership and enumerable membership
but must not clear `tokenCollectionId`, the stored collection-local serial,
or burned-token audit identity. The serial is read from the retained
identity record — no range or token-ID arithmetic exists to derive it
(ADR 0009 decision 1) — and `tokenCollectionIdentity` reports mapping
existence from the burned audit state. Burned-token `tokenURI()` may revert
under normal ERC-721 metadata semantics, while `royaltyInfo()` can still
disclose the last token, collection, then default royalty policy. The
retained burn identity is also the burn proof consumed by burn-to-mint and
burn-to-redeem programs
([`docs/stream-sales-and-auctions.md`](stream-sales-and-auctions.md)).

Deployed v1 Core must not expose range-model error selectors on identity
paths: the baseline `TokenOutsideCollectionRange()` selector must be
renamed to a sequential-identity error (for example
`TokenIdentityUnknown()`) before the deployment gate, because no reserved
range exists to be outside of.

Implementation evidence (non-normative). The interim slice retains the
legacy `BurnedTokenRemintNotAllowed(uint256)` selector for catalog/ABI
continuity (the optimized build is smaller with the selector present), and
its burned-remint regression path currently reverts through the legacy
range-named error slated for rename above.

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

## Counter Model [MPA-COUNTERS]

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
    RESOLVER,
    MERKLE_STATIC
}
```

`CounterCapMode.NONE` is the only no-cap state. `CounterCapMode.STATIC` uses
the configured static cap exactly; `staticCap = 0` means zero allowed unless a
phase validator rejects zero as an invalid configuration for that counter.
Implementations must not treat `STATIC cap = 0` as unlimited.
`CounterCapMode.MERKLE_STATIC` is the industry-standard allowlist shape
(ADR 0010 decision D5.3): the per-subject cap comes from a Merkle leaf
`(account, maxCount, optional priceOverride)` proven at mint time against a
root pinned in the counter configuration. It is verified inline by the
manager — no resolver, no external call — and is specified in
`Merkle Allowlist Cap Mode` below.

Recommended delta modes:

```solidity
enum CounterDeltaMode {
    STATIC,
    RESOLVER
}
```

`CounterCapMode.RESOLVER` lets a counter derive the effective cap from a
signed ticket, profile score, delegation graph, or future identity system.
`CounterDeltaMode.RESOLVER` lets a counter consume something other than a flat
static increment, such as auction lots, weighted claims, or profile-weighted
credits.

V1 implementations must reject `CounterCapMode.RESOLVER`,
`CounterDeltaMode.RESOLVER`, and `CUSTOM_RESOLVER` unless the corresponding
extension has its own accepted ADR and is enabled in the module registry;
until then these modes are excluded from v1 bytecode as intentional absence,
not deferral. Non-empty nullifier consumption is accepted only from a
registry-`ACTIVE` gate module whose accepted specification defines its
nullifier domain — the burn-to-mint gate of
[`docs/stream-sales-and-auctions.md`](stream-sales-and-auctions.md) is the
genesis example; privacy-preserving nullifier resolvers remain excluded.
Reserved enum values are allowed in the schema so policy hashes can evolve,
but reserved enum surface must not become dead-but-callable production code.
Tests should configure each excluded mode and prove it reverts before any
counter or mint state is written.

The v1-permitted counter combinations are finite:

```text
scope             key mode                  update mode   cap mode        delta mode
PHASE             CONSTANT                  PER_TOKEN     STATIC          STATIC
COLLECTION        CONSTANT                  PER_TOKEN     STATIC          STATIC
GLOBAL            CONSTANT                  PER_TOKEN     STATIC          STATIC
PHASE             RECIPIENT                 PER_TOKEN     STATIC          STATIC
PHASE             PAYER                     PER_TOKEN     STATIC          STATIC
COLLECTION        RECIPIENT                 PER_TOKEN     STATIC          STATIC
COLLECTION        PAYER                     PER_TOKEN     STATIC          STATIC
GLOBAL            RECIPIENT                 PER_TOKEN     STATIC          STATIC
GLOBAL            PAYER                     PER_TOKEN     STATIC          STATIC
PHASE             RECIPIENT                 PER_TOKEN     MERKLE_STATIC   STATIC
PHASE             PAYER                     PER_TOKEN     MERKLE_STATIC   STATIC
COLLECTION        RECIPIENT                 PER_TOKEN     MERKLE_STATIC   STATIC
COLLECTION        PAYER                     PER_TOKEN     MERKLE_STATIC   STATIC
PHASE             CONTEXT                   PER_BATCH     STATIC          STATIC
COLLECTION        CONTEXT                   PER_BATCH     STATIC          STATIC
```

Any other combination reverts at configuration time unless a separate accepted
ADR expands the allowed set. This table bounds the v1 test matrix.
`GLOBAL` scope is a supported v1 static scope (ADR 0010 decision D5.9);
its value-key derivation is pinned in `Counter Key Derivation`.
There is no separate `BENEFICIARY` enum in v1: `RECIPIENT` means the
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

one mint per wallet across a season spanning collections
  scope      = GLOBAL
  key mode   = RECIPIENT
  update     = PER_TOKEN
  cap mode   = STATIC
  cap        = 1

one execution per signed drop context
  scope      = PHASE
  key mode   = CONTEXT
  update     = PER_BATCH
  cap mode   = STATIC
  cap        = 1

tiered allowlist from a Merkle leaf (v1, no resolver)
  scope      = PHASE
  key mode   = RECIPIENT
  update     = PER_TOKEN
  cap mode   = MERKLE_STATIC   cap from proven (account, maxCount) leaf
  delta mode = STATIC

pick-your-piece content selection (one sale per content ID; see
docs/stream-sales-and-auctions.md)
  scope      = PHASE
  key mode   = CONTEXT         contextHash = content context hash
  update     = PER_BATCH
  cap mode   = STATIC
  cap        = 1

five lifetime mints per 6529 profile across a collection (extension:
CUSTOM_RESOLVER requires its own accepted ADR)
  scope      = COLLECTION
  key mode   = CUSTOM_RESOLVER
  update     = PER_TOKEN
  cap mode   = STATIC
  cap        = 5

private claim nullifier (extension: privacy-preserving resolvers are
excluded from protocol v1)
  scope      = GLOBAL
  key mode   = CUSTOM_RESOLVER
  update     = PER_BATCH
  cap mode   = STATIC
  cap        = 1
```

### Merkle Allowlist Cap Mode

Requirements [MPA-MERKLE]:

1. A `MERKLE_STATIC` counter pins `capRoot` in its configuration: the
   sorted-pair keccak Merkle root over double-hashed leaves

   ```solidity
   bytes32 leaf = keccak256(bytes.concat(keccak256(abi.encode(
       ALLOWLIST_LEAF_DOMAIN, // keccak256("6529STREAM_MINT_ALLOWLIST_LEAF_V1")
       uint256(block.chainid),
       address(mintManager),
       uint256(collectionId),
       bytes32(phaseId),
       bytes32(counterId),
       address(account),
       uint64(maxCount),
       bool(hasPriceOverride),
       uint256(priceOverride)
   ))));
   ```

   Double hashing prevents second-preimage/internal-node confusion;
   packed encoding is invalid.
2. `leaf.account` must equal the counter's subject account for the
   configured key mode (`RECIPIENT` = beneficiary, `PAYER` = payer). The
   caller supplies `(maxCount, hasPriceOverride, priceOverride, proof)`
   per `MERKLE_STATIC` counter through `MintBatch.resolverData`, ordered
   by the phase's configured counter order.
3. The manager must verify the proof against `capRoot` inline and use
   `maxCount` as the effective cap for that subject. An invalid proof
   reverts with `MintAllowlistProofInvalid` before any state write.
4. The ledger bounds the manager: for `MERKLE_STATIC` the registered
   `staticCap` is the ceiling — the maximum `maxCount` in the published
   list — and the ledger rejects any consumption whose supplied cap
   exceeds it or is zero. Cap checks then run against the supplied leaf
   cap exactly as for `STATIC`.
5. `priceOverride` is sale policy, not accounting: when
   `hasPriceOverride` is true, the sale adapter must charge
   `priceOverride` after verifying the same leaf
   (`docs/stream-sales-and-auctions.md` `[SSA-AUTH]`); the manager and
   ledger ignore price.
6. `capRoot` is bound into the counter's binding commitment and therefore
   into `policyHash`; changing the allowlist is a policy change
   (loosening rules apply), and a frozen phase pins its allowlist
   forever.
7. The full allowlist file is an Operational artifact that must be
   published and hash-committed (its content hash belongs in the phase
   `configHash`) before the phase opens, so every wallet can verify its
   own allocation offline. Signed-ticket allowlisting remains available,
   but it requires live signing infrastructure and trusts the signer;
   the Merkle mode is offline-verifiable and signer-free. These are the
   two supported genesis allowlist patterns.

## Counter Key Derivation

Allowance accounting must not assume that the recipient address is always the
right identity. Every counter derives a counter key.

Counter derivation separates the subject from the counter scope. The subject key
answers "who or what is being counted"; the value key answers "where is that
subject counted."

Default address-based subject-key derivation:

```solidity
// SUBJECT_DOMAIN = keccak256("6529STREAM_MINT_COUNTER_SUBJECT_V1")
bytes32 subjectKey = keccak256(abi.encode(
    SUBJECT_DOMAIN,
    uint256(block.chainid),
    address(mintLedger),
    uint8(keyMode),
    accountAddress
));
```

`CONSTANT` uses a deterministic key for the collection, phase, and counter:

```solidity
bytes32 subjectKey = keccak256(abi.encode(
    SUBJECT_DOMAIN,
    uint256(block.chainid),
    address(mintLedger),
    uint8(CounterKeyMode.CONSTANT),
    collectionId,
    phaseId,
    counterId
));
```

`CONTEXT` uses `batch.contextHash`. If a context counter is configured, the
manager must require a nonzero `contextHash`. V1 `CONTEXT` counters are
batch-scoped: one prepared mint request consumes the configured static
increment once for that context, even when the request mints multiple tokens.
The ledger context event should therefore be treated as batch evidence rather
than recipient-specific evidence for this key mode.

The durable ledger value key is scoped separately. For the CON-013 genesis
ledger, the canonical key is manager-scoped and uses the resolved phase/counter
subject:

```solidity
bytes32 valueKey = keccak256(abi.encode(
    manager,
    collectionId,
    phaseId,
    counterId,
    subjectKey
));
```

Cross-collection and cross-phase sharing use documented reserved
constants, never inferred sentinels [MPA-SCOPES]:

1. `COLLECTION_SCOPE_PHASE_ID = 0` (ADR 0009 decision 11): collection- and
   global-scoped counters derive value keys with `phaseId = 0`; real
   phases must register with `phaseId >= 1`, and the manager and ledger
   reject phase registration at 0.
2. `GLOBAL_SCOPE_COLLECTION_ID = 0` (ADR 0010 decision D5.9): `GLOBAL`
   scoped counters derive value keys with `collectionId = 0` and
   `phaseId = 0`. Real collections must have `collectionId >= 1`, and the
   manager and ledger must reject phase or counter registration for
   collection 0. One derivation function serves all three scopes.
3. Both reserved constants are documented in the protocol v1
   domain-constants table inputs and covered by a golden test.

Any other cross-scope sharing must be explicit in the subject resolver or
in a separately accepted ledger design.

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
4. `increment` must be `>= 1` for every counter consumption in every mode
   — static, resolver, or Merkle. Zero is invalid at configuration time
   and at consumption time; there is no zero-means-default sentinel
   (ADR 0010 decision D8.4).
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

Recommended phase configuration. The struct fields align one-for-one with
the hashed `PHASE_CONFIG_DOMAIN` and `GATE_CONFIG_DOMAIN` preimages in
`Policy Fingerprints` (ADR 0010 decision D3.6): the gate lives in its own
hashed config struct, phase metadata is a real config field, and the
per-phase counter-count bound is the reviewed manager constant
`MAX_PHASE_COUNTERS` rather than per-phase state (the ordered counter set
is already fully committed by the policy hash).

```solidity
struct MintPhaseConfig {
    bool exists;
    bool paused;
    uint64 startTime;
    uint64 endTime;
    uint32 maxBatchQuantity;
    bytes32 configHash;
    bytes32 metadataHash;
}

struct MintGateConfig {
    address gate;
    bytes32 gateConfigHash;
    bytes32 gateCodehash;
    bytes32 gateMetadataHash;
    uint32 gateSemanticVersion;
    uint32 gateGasLimit;
}
```

Field semantics:

```text
exists             phase has been configured
paused             admin pause for this phase
startTime          zero means no lower time bound
endTime            zero means no upper time bound
maxBatchQuantity   nonzero per-call cap; v1 managers must also enforce a reviewed hard maximum
configHash         hash of offchain/operator config (allowlist file, sale terms); zero when unused
metadataHash       phase display metadata commitment (see MintPhaseMetadata)
gate               optional validation module; address(0) disables gating
gateConfigHash     gate-specific policy commitment (roots, source sets, terms)
gateCodehash       pinned gate codehash; zero skips the pin
gateMetadataHash   gate display metadata commitment
gateSemanticVersion registry semantic version expected at configuration
gateGasLimit       minimum gas forwarded to the gate call; see [MPA-GATES]
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
    bytes32 capRoot;
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
capMode     whether the cap is absent, static, Merkle-proven, or resolver-provided
deltaMode   whether increment is static or resolver-provided
cap         must be zero when capMode is NONE; exact cap when STATIC, where
            zero means zero allowed; ceiling (maximum leaf cap) when
            MERKLE_STATIC
increment   static increment; must be >= 1 for every enabled counter; zero
            is invalid and reverts at configuration (ADR 0010 decision D8.4)
resolver    required for CUSTOM_RESOLVER, RESOLVER cap, or RESOLVER delta
capRoot     required nonzero for MERKLE_STATIC; zero otherwise
configHash  optional hash of offchain/operator config
```

Primary manager state:

```solidity
address public mintLedger;
address public moduleRegistry;

mapping(uint256 => mapping(bytes32 => MintPhaseConfig)) public phases;
mapping(uint256 => mapping(bytes32 => MintGateConfig)) public gateConfigs;
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

struct LedgerPolicyGrace {
    bytes32 previousPolicyHash;
    uint64 graceUntil;
}

mapping(address => bool) public ledgerWriters;
mapping(address manager => mapping(uint256 collectionId => mapping(bytes32 phaseId => bytes32 policyHash)))
    public registeredPhasePolicyHashes;
mapping(address manager => mapping(uint256 collectionId => mapping(bytes32 phaseId => LedgerPolicyGrace)))
    public policyGraceWindows;
mapping(address manager => mapping(uint256 collectionId => mapping(bytes32 phaseId => mapping(bytes32 counterId => LedgerCounterPolicy))))
    public registeredCounterPolicies;
mapping(bytes32 => uint64) public counterValues;
mapping(address manager => mapping(bytes32 authorizationId => bool)) public authorizationUsed;
mapping(address manager => mapping(bytes32 nullifier => bool)) public nullifierUsed;
```

`nullifierUsed` is manager-scoped exactly like `authorizationUsed`
(ADR 0010 decision D8.5): an authorized writer can only consume nullifiers
inside its own scope, so a second — or compromised — manager cannot
pre-consume arbitrary `bytes32` values and censor another manager's future
claims. A future nullifier extension may relax scoping only through an
explicit shared-domain registration recorded in its own accepted ADR,
never by reintroducing a flat global mapping.

The ledger must not depend on an arbitrary manager callback to "discover" the
active policy hash during consumption. The manager registers or updates
`registeredPhasePolicyHashes[manager][collectionId][phaseId]` through an
authorized configuration path before the phase can mint. During consumption the
ledger verifies that the supplied `policyHash` equals that registered value
(or the grace-window predecessor under `[MPA-GRACE]`) and
then repeats cap checks against `registeredCounterPolicies`. In protocol v1,
the ledger rejects resolver cap/delta modes; verifies supplied `cap` equals
`staticCap` for `STATIC`, is zero for `NONE`, and is in `[1, staticCap]` for
`MERKLE_STATIC`; verifies supplied `increment` equals `staticIncrement`; and
rejects any consumption with `increment == 0` regardless of mode
(ADR 0010 decision D8.4). Because `staticIncrement` must itself be `>= 1`
at registration, the exact-equality check and the nonzero rule can never
disagree. This keeps ledger verification implementable and auditable while
still ensuring events bind to the active manager policy.

Protocol v1 has one active registered policy hash per
`(manager, collectionId, phaseId)`, plus at most one bounded grace-window
predecessor hash under `[MPA-GRACE]` (ADR 0010 decision D5.5). Any
phase configuration change that changes `policyHash` must update the manager
state, registered phase hash, and registered counter policies atomically in the
same governance execution before the new phase can mint. Tightening changes may
execute through the
immediate path; loosening changes and ledger replacement are
`DELAYED_LOOSENING` actions under ADR 0004. Frozen phases cannot move to a
different ledger, and a ledger replacement cannot reset or bypass counters for
that frozen policy (see `Counter Continuity Across Succession`).

`counterValues` are durable and are not reset when a phase policy is
re-registered. For the CON-013 genesis ledger, the canonical value key is keyed
by the authorized manager and the resolved phase/counter subject:

```solidity
bytes32 valueKey = keccak256(abi.encode(
    manager,
    collectionId,
    phaseId,
    counterId,
    subjectKey
));
```

The ledger exposes `deriveCounterValueKey` and rejects any supplied `valueKey`
that does not match this derivation. Manager-level scopes such as
`GLOBAL`, `COLLECTION`, and resolver-backed subjects must resolve to the
effective `(collectionId, phaseId, counterId, subjectKey)` tuple before calling
the ledger. The canonical cross-phase tuple is defined by
ADR 0009 decision 11: `phaseId = 0` is the reserved, named collection-scope
value (`COLLECTION_SCOPE_PHASE_ID = 0`). Real phases must register with
`phaseId >= 1`, and the manager and ledger reject phase registration at 0.
`GLOBAL` and `COLLECTION` scoped counters derive their value keys with the
reserved value, keeping one derivation function; the reserved constant is
documented in the domain-constant table's inputs and covered by a golden
test.

`authorizationUsed` is for signed tickets, drop IDs, or other external mint
authorizations returned by a gate. The CON-013 genesis ledger scopes consumed
authorization IDs by manager so two authorized managers cannot collide on the
same raw replay ID. Managers should still domain-separate authorization IDs by
chain, ledger, manager, and signed payload so replay evidence remains portable
across deployments and indexers.

`nullifierUsed` is for gate-supplied replay keys whose protection should
not depend on a public recipient address: the genesis consumer is the
burn-to-mint gate's `STREAM_BURN_NULLIFIER_V1` domain
([`docs/stream-sales-and-auctions.md`](stream-sales-and-auctions.md)), and
future privacy-preserving claim systems reuse the same manager-scoped
storage through their own accepted specs. Authorization IDs and nullifiers
must be separately domain-separated even though they share the
manager-scoped storage pattern.

## Durable Mint Ledger

`StreamMintLedger` should be deliberately small. It owns the irreversible
accounting facts and little else:

1. Counter values are monotonic.
2. Authorization IDs are consumed or voided at most once per manager.
3. Nullifiers are consumed at most once per manager.
4. Only authorized manager contracts can write, and only inside their own
   manager scope.
5. Supplied counter value keys match the ledger's canonical key derivation.
6. Counter increments are `>= 1` in every mode; a zero increment reverts
   before any state write.
7. Every write emits enough data for indexers to reconstruct the accounting
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
        LedgerCounterPolicy[] calldata counterPolicies,
        uint64 graceUntil
    ) external;

    function consume(
        CounterConsumption[] calldata consumptions,
        bytes32 authorizationId,
        bytes32[] calldata nullifiers,
        bytes32 policyHash
    ) external;

    function voidAuthorization(
        address manager,
        bytes32 authorizationId
    ) external;

    function counterValue(bytes32 valueKey) external view returns (uint64);

    function deriveCounterValueKey(
        address manager,
        uint256 collectionId,
        bytes32 phaseId,
        bytes32 counterId,
        bytes32 subjectKey
    ) external pure returns (bytes32);

    function policyGrace(
        address manager,
        uint256 collectionId,
        bytes32 phaseId
    ) external view returns (bytes32 previousPolicyHash, uint64 graceUntil);

    function isAuthorizationUsed(bytes32 authorizationId)
        external
        view
        returns (bool);

    function isManagerAuthorizationUsed(address manager, bytes32 authorizationId)
        external
        view
        returns (bool);

    function isNullifierUsed(bytes32 nullifier)
        external
        view
        returns (bool);

    function isManagerNullifierUsed(address manager, bytes32 nullifier)
        external
        view
        returns (bool);
}
```

Requirements [MPA-LEDGER]:

1. `registerPhasePolicy` must revert unless `msg.sender == manager` and
   `manager` is an authorized ledger writer. An authorized writer can
   never register, grace, or void under another manager's key; the ledger
   rejects cross-manager registration with a typed error and a test
   proves it (ADR 0010 decision D10.3).
2. `consume` and `voidAuthorization` are scoped the same way:
   `msg.sender` must equal the `manager` whose storage is written.
3. `voidAuthorization` marks an unused authorization ID consumed and emits
   `MintLedgerAuthorizationVoided` — a distinct event from consumption —
   giving signers durable revocation (ADR 0010 decision D10.4). The
   manager exposes the signer-facing path in `Signed Mint Tickets`; the
   ledger only requires that the void request arrives through the
   authorization's own manager.
4. Voiding an already-consumed or already-voided ID reverts; voiding is
   one-way and permanent.

External tools should prefer the manager-scoped reads
(`isManagerAuthorizationUsed`, `isManagerNullifierUsed`) when checking
replay state. The shorter helpers are caller-relative and only answer for
`msg.sender`.

The manager builds bounded counter consumptions before calling the ledger. The
ledger owns the final cap checks and writes, so counter accounting has a single
durable enforcement point and any later revert rolls the whole transaction
back.

The CON-014 genesis manager implements this static path as
`StreamMintManager`: owners configure phase policy and ordered static counters,
grant per-phase executors, optionally pause phases, register each active
`policyHash` with `StreamMintLedger`, build bounded batch counter consumptions,
enforce named v1 hard caps for batch size and counter count, require callers
to bind the active `policyHash`, consume a nonzero authorization ID with the
ledger, derive operation roots from the static request commitment, then execute
Core's prepared mint pair atomically. The implemented manager slice does not
yet route existing `StreamDrops` or auction flows, execute payment settlement,
or consult gates; dynamic resolver caps/deltas and callable nullifiers are
protocol v1 exclusions until their own ADRs are accepted.

Ledger events:

```solidity
event MintLedgerCounterConsumed(
    bytes32 indexed valueKey,
    uint256 indexed collectionId,
    bytes32 indexed phaseId,
    address manager,
    bytes32 counterId,
    bytes32 subjectKey,
    uint64 increment,
    uint64 newValue,
    uint64 cap,
    bytes32 policyHash
);

event MintLedgerCounterConsumptionContext(
    bytes32 indexed valueKey,
    bytes32 indexed counterId,
    bytes32 indexed subjectKey,
    address manager,
    address payer,
    address recipient,
    address authorizer,
    address executor,
    bytes32 contextHash,
    bytes32 resolutionHash
);

event MintLedgerAuthorizationConsumed(
    bytes32 indexed authorizationId,
    bytes32 indexed policyHash,
    address indexed manager
);

event MintLedgerNullifierConsumed(
    bytes32 indexed nullifier,
    bytes32 indexed policyHash,
    address indexed manager
);

event MintLedgerAuthorizationVoided(
    uint16 schemaVersion,
    bytes32 indexed authorizationId,
    address indexed manager
);

event MintLedgerPolicyGraceSet(
    uint16 schemaVersion,
    uint256 indexed collectionId,
    bytes32 indexed phaseId,
    address indexed manager,
    bytes32 previousPolicyHash,
    bytes32 newPolicyHash,
    uint64 graceUntil
);

event MintLedgerImportRootCommitted(
    uint16 schemaVersion,
    bytes32 indexed importRoot,
    address indexed predecessorManager,
    address indexed successorManager,
    address predecessorLedger,
    uint64 snapshotBlock,
    bytes32 manifestHash
);

event MintLedgerCounterImported(
    uint16 schemaVersion,
    bytes32 indexed importRoot,
    bytes32 indexed valueKey,
    bytes32 indexed subjectKey,
    uint256 collectionId,
    bytes32 phaseId,
    bytes32 counterId,
    uint64 importedValue,
    uint64 resultingValue
);

event MintLedgerNullifierImported(
    uint16 schemaVersion,
    bytes32 indexed importRoot,
    bytes32 indexed nullifier,
    address indexed successorManager
);

event MintLedgerWriterUpdated(address indexed writer, bool allowed);
```

Indexers reconstruct one consumption from the adjacent primary and context
events in the same transaction. `MintLedgerCounterConsumed` carries the
`policyHash` and cap/accounting values; `MintLedgerCounterConsumptionContext`
carries payer, recipient, authorizer, executor, and context hashes under the
same `valueKey`, `counterId`, and `subjectKey`.

The ledger should not know about ETH, ERC-721 ownership, sale prices, display
labels, or UI metadata.

## Counter Continuity Across Succession

Durable accounting must outlive individual policy modules (Goal 15). Value
keys embed the manager address, and subject keys embed the ledger address,
so replacing either contract would silently zero every consumed allowance —
an unacceptable reset for perpetual open collections mid-drop. Protocol v1
therefore ships a governed, Merkle-proofed import path (ADR 0010 decision
D5.8) instead of retracting the goal or forbidding succession.

```solidity
struct CounterImportLeaf {
    uint256 collectionId;
    bytes32 phaseId;
    bytes32 counterId;
    uint8 keyMode;
    bytes32 subjectBasis; // account as bytes32, contextHash, or constant marker
    bytes32 predecessorSubjectKey;
    uint64 value;
}

interface IStreamMintLedgerImport {
    function commitCounterImportRoot(
        address predecessorLedger,
        address predecessorManager,
        address successorManager,
        uint64 snapshotBlock,
        bytes32 importRoot,
        bytes32 manifestHash
    ) external;

    function importCounterValue(
        bytes32 importRoot,
        CounterImportLeaf calldata leaf,
        bytes32 successorSubjectKey,
        bytes32[] calldata proof
    ) external;

    function importNullifier(
        bytes32 importRoot,
        bytes32 nullifier,
        bytes32[] calldata proof
    ) external;
}
```

Requirements [MPA-CONTINUITY]:

1. Snapshot: succession tooling exports the predecessor's counter values
   and consumed nullifiers at a pinned `snapshotBlock` into a Merkle tree.
   Counter leaves use
   `keccak256(bytes.concat(keccak256(abi.encode(COUNTER_IMPORT_LEAF_DOMAIN,
   uint256(block.chainid), address(predecessorLedger),
   address(predecessorManager), leaf...))))`; nullifier leaves use
   `NULLIFIER_IMPORT_LEAF_DOMAIN` over
   `(chainid, predecessorLedger, predecessorManager, nullifier)`. Trees
   are sorted-pair keccak with double-hashed leaves.
2. Freeze-before-snapshot: the snapshot block must be at or after the
   block in which the predecessor manager's ledger-writer authorization
   was revoked (or, for ledger succession, the predecessor ledger's
   writers were revoked). A snapshot that can undercount live consumption
   is invalid, and the committing governance action must verify the
   ordering. A conformance gate tests continuity across a live swap.
3. Commitment: `commitCounterImportRoot` is a `DELAYED_LOOSENING`
   governance action on the successor ledger binding
   `(predecessorLedger, predecessorManager, successorManager,
   snapshotBlock, importRoot, manifestHash)` and emitting
   `MintLedgerImportRootCommitted`. The manifest hash commits the full
   exported dataset so any replica can audit completeness.
4. Import: `importCounterValue` must be called by `successorManager`
   (an authorized writer importing only into its own scope). The ledger
   verifies the proof against the committed root, derives
   `valueKey(successorManager, collectionId, phaseId, counterId,
   successorSubjectKey)`, and writes
   `max(currentValue, leaf.value)` — imports can never lower a value and
   never double-apply (each leaf imports at most once per root).
5. Subject re-derivation: the successor manager derives
   `successorSubjectKey` from `leaf.keyMode` and `leaf.subjectBasis`
   using the canonical subject derivation against the successor ledger
   address. The leaf carries both the basis and the predecessor subject
   key so offchain auditors can verify every mapping; the ledger trusts
   the successor manager for subject derivation exactly as it does during
   normal consumption.
6. Lazy or bulk: imports may run eagerly after commitment or lazily —
   any subject's floor can be proven immediately before its first
   successor-side consumption. A successor manager must not consume for a
   subject whose predecessor value is provably higher than the
   successor-side current value while an applicable committed root
   exists; managers should enforce this by requiring the import call
   before first consumption per subject.
7. Nullifiers: `importNullifier` marks the nullifier consumed in the
   successor manager's scope. Authorization IDs are intentionally not
   imported: they bind the manager address by derivation, so predecessor
   authorizations cannot replay against a successor, and outstanding
   unused tickets die at succession (re-issue under the successor, or use
   `[MPA-GRACE]` timing to drain them first).
8. Phase identity is preserved: imports never remap
   `(collectionId, phaseId, counterId)`. Succession that also restructures
   phases is a new-phase design decision, not an import feature.

## Policy Fingerprints [MPA-POLICY-HASH]

Every configured phase has a canonical `policyHash` committing to the
complete active policy that affects whether a mint can happen. This section
is the normative home for the mint-manager hash family (ADR 0010 decision
D3.6); the protocol v1 domain-constants table is the checker-verified
mirror. The earlier variant that listed `modulePinSetHash` and
`phaseMetadataHash` as top-level inputs is deleted: module pins bind inside
the gate and counter component hashes, and phase metadata binds inside the
phase config hash, exactly as below.

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
    POLICY_DOMAIN, // keccak256("6529STREAM_MINT_MANAGER_POLICY_V1")
    uint256(block.chainid),
    address(this),            // manager
    address(mintLedger),
    address(moduleRegistry),
    uint16(SCHEMA_VERSION),
    uint256(collectionId),
    bytes32(phaseId),
    bytes32(phaseConfigHash),
    bytes32(gateConfigHash),
    bytes32(orderedCounterConfigHash),
    bytes32(executorSetHash)
));
```

Component domains, each hashed with `abi.encode`, explicit field order, and
explicit type widths (packed encodings and JSON/string concatenation are
never valid for authority hashes):

```solidity
// PHASE_CONFIG_DOMAIN = keccak256("6529STREAM_MINT_MANAGER_PHASE_CONFIG_V1")
bytes32 phaseConfigHash = keccak256(abi.encode(
    PHASE_CONFIG_DOMAIN,
    config.paused,
    config.startTime,
    config.endTime,
    config.maxBatchQuantity,
    config.configHash,
    config.metadataHash
));

// GATE_CONFIG_DOMAIN = keccak256("6529STREAM_MINT_MANAGER_GATE_CONFIG_V1")
bytes32 gateConfigHash = keccak256(abi.encode(
    GATE_CONFIG_DOMAIN,
    gateConfig.gate,
    gateConfig.gateConfigHash,
    gateConfig.gateCodehash,
    gateConfig.gateMetadataHash,
    gateConfig.gateSemanticVersion,
    gateConfig.gateGasLimit
));

// COUNTER_CONFIG_DOMAIN = keccak256("6529STREAM_MINT_MANAGER_COUNTER_CONFIG_V1")
bytes32 counterConfigLeaf = keccak256(abi.encode(
    COUNTER_CONFIG_DOMAIN,
    counterId,
    config.enabled,
    config.keyMode,
    config.capMode,
    config.deltaMode,
    config.staticCap,
    config.staticIncrement,
    config.counterConfigHash
));

// COUNTER_BINDING_DOMAIN = keccak256("6529STREAM_MINT_COUNTER_BINDING_V1")
// counterConfigHash is a mandatory binding commitment, not optional
// operator data: it commits the remaining policy-relevant counter fields.
bytes32 counterConfigHash = keccak256(abi.encode(
    COUNTER_BINDING_DOMAIN,
    uint8(config.scope),
    uint8(config.updateMode),
    address(config.resolver),
    bytes32(resolverCodehash), // pinned registry codehash; zero when unpinned
    bytes32(config.capRoot),
    bytes32(config.configHash) // operator/offchain config commitment
));

// orderedCounterConfigHash commits the exact enabled counter order:
bytes32 orderedCounterConfigHash =
    keccak256(abi.encode(counterConfigLeaves)); // bytes32[] in phase order

// EXECUTOR_SET_DOMAIN = keccak256("6529STREAM_MINT_MANAGER_EXECUTOR_SET_V1")
bytes32 executorSetHash = keccak256(abi.encode(
    EXECUTOR_SET_DOMAIN,
    sortedExecutorAddresses // ascending, deduplicated
));
```

Requirements (continued):

1. Every value hashed into `policyHash` must have deterministic runtime
   meaning; `gateGasLimit` semantics are pinned in `[MPA-GATES]` so two
   implementations honoring one `policyHash` behave identically.
2. Governed Gas Parameter values are never inputs to `policyHash`
   (ADR 0010 decision D1.3): retuning gas must not rotate policy identity
   or invalidate outstanding tickets.
3. Every mint event, ledger consumption event, signed ticket, and preview
   response must include the active `policyHash`.
4. A signed ticket issued against an older hash must be rejected by the
   state-changing mint unless that older hash is the registered
   grace-window predecessor under `[MPA-GRACE]`.

Policy hashes make long-lived operation easier because users, artists, operators,
indexers, and auditors can tie a mint to the exact policy that was active at the
time.

## Policy Grace Windows

Any phase configuration change rotates `policyHash` and would strand every
outstanding signed ticket and sale authorization bound to the previous
hash. Re-issuing thousands of allowlist tickets because an end time moved
is an operational trap, so re-registration may carry a bounded continuity
window (ADR 0010 decision D5.5).

Requirements [MPA-GRACE]:

1. `registerPhasePolicy` accepts `graceUntil`. When nonzero, the ledger
   records the immediately preceding registered hash as
   `previousPolicyHash` with the supplied `graceUntil`; when zero, no
   grace exists and any prior grace is cleared.
2. Bound: `graceUntil <= block.timestamp + MAX_POLICY_GRACE_SECONDS`,
   with `MAX_POLICY_GRACE_SECONDS = 2_592_000` (30 days) as a reviewed
   named constant. Registration reverts beyond the bound.
3. During the window, `consume` accepts `policyHash` equal to either the
   registered hash or `previousPolicyHash`; after `graceUntil`, only the
   registered hash. At most one predecessor hash is ever valid; a new
   registration replaces any existing grace record.
4. Grace relaxes only the policy-hash equality check. Cap and increment
   verification always run against the currently registered counter
   policies, so a tightening change tightens immediately even for tickets
   consumed under the predecessor hash.
5. Because loosening changes are `DELAYED_LOOSENING` governance actions,
   a grace window on a loosening change extends the old hash's validity,
   never the old (looser) limits.
6. Every grace registration emits `MintLedgerPolicyGraceSet` with both
   hashes and the deadline; consumption events carry the hash actually
   bound, so indexers can distinguish grace-window mints.
7. Managers and gates must apply the same two-hash acceptance to ticket
   validation (`[MPA-TICKET-RULES]`), and sale adapters must emit the
   bound hash per `docs/stream-sales-and-auctions.md` `[SSA-GRACE]`.
8. Operational guidance: issue long-lived tickets as late as practical;
   a change that must not honor old tickets sets `graceUntil = 0`.

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

Token-data ownership and typing are pinned once in `[MPA-CORE-ABI]`
(Core Contract Changes): Core stores the renderer-visible `tokenData`
bytes plus the `tokenDataHash` commitment, `tokenData` is opaque `bytes`
in `MintBatch` and the Core hook alike, and no other document may define a
different Core mint shape.

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
9. Authorizer presence is governed by the explicit `AuthorizerKind` model
   of `[MPA-AUTHZ]`, never by an `address(0)` convention: `authorizer`
   must be `address(0)` exactly when the effective authorizer kind is
   `NONE`, and must be nonzero for every other kind.
10. `tokenData` is opaque bytes. Renderer/schema code may interpret it as
    UTF-8, JSON, CBOR, or another format, but Core and the mint manager do not
    parse it.
11. Each `tokenData[i]` must satisfy the collection metadata v1 limit
     `MAX_TOKEN_DATA_BYTES`, and the batch must satisfy any manager-level total
     calldata/gas cap. In the mint-manager path, Core validates token data after
     manager ledger consumption and before prepared mint state, payment
     settlement, or the completion-time entropy/randomizer boundary; an
     oversized token-data revert rolls back the whole transaction, including
     ledger counters and authorization usage.
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
through canonical hashes. `tokenDataArrayHash` is the batch-level hash;
the per-token commitment `keccak256(tokenData[i])` keeps the singular
`tokenDataHash` name — the two are distinct values and must never be
conflated:

```solidity
bytes32 initialRecipientsHash = keccak256(abi.encode(batch.initialRecipients));
bytes32 beneficiariesHash = keccak256(abi.encode(batch.beneficiaries));
bytes32 tokenDataArrayHash = keccak256(abi.encode(batch.tokenData));
bytes32 mintCommitmentsHash = keccak256(abi.encode(batch.mintCommitments));
```

### Authorizer Kinds

The `address(0)`-as-blessed-authorizer convention is retired (ADR 0010
decision D8.3). Every authorization surface declares an explicit kind:

```solidity
enum AuthorizerKind {
    NONE,        // no authorizer exists; authorizer must be address(0)
    EOA_712,     // EIP-712 digest verified by ECDSA recovery
    ERC1271_712, // EIP-712 digest verified via ERC-1271 isValidSignature
    CALLER_ADAPTER // authorizer is the verified registry-ACTIVE adapter
                   // supplying the authorization as msg.sender
}
```

Requirements [MPA-AUTHZ]:

1. Signed-ticket gates must reject `authorizerKind == NONE` and must
   reject `authorizer == address(0)` for every kind other than `NONE`.
2. `EOA_712` verification must treat an `ecrecover` result of
   `address(0)` as invalid, must require the recovered address to equal
   the ticket's `authorizer` exactly, and must reject non-canonical
   signatures: `s` above the secp256k1 half-order (EIP-2) or `v` outside
   `{27, 28}`. A garbage signature can therefore never validate against
   any authorizer value.
3. `ERC1271_712` verification is a bounded `staticcall` to
   `isValidSignature` under the `TICKET_ERC1271_GAS_LIMIT` Governed Gas
   Parameter with the 63/64 parent-gas precheck; anything but the exact
   magic value is invalid.
4. `CALLER_ADAPTER` requires `authorizer == msg.sender` and that the
   caller is a registry-`ACTIVE` sale adapter per
   `docs/stream-sales-and-auctions.md` `[SSA-REGISTRY]`.
5. Both rejection cases in rule 2 (zero recovery, non-canonical s/v) are
   golden negative tests in the conformance matrix mint-accounting gate.

### Canonical Signed Ticket

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
    uint8 authorizerKind;
    bytes32 initialRecipientsHash;
    bytes32 beneficiariesHash;
    bytes32 tokenDataArrayHash;
    bytes32 mintCommitmentsHash;
    uint256 quantity;
    bytes32 contextHash;
    bytes32 policyHash;
    bytes32 nonce;
    uint64 deadline;
}
```

Requirements [MPA-TICKET] (pinned EIP-712 surface, ADR 0010 decision D3.5):

1. The pinned type string is:

   ```text
   MINT_TICKET_TYPEHASH = keccak256(
       "MintTicket(uint256 chainId,address manager,address ledger,"
       "uint256 collectionId,bytes32 phaseId,address executor,"
       "address payer,address authorizer,uint8 authorizerKind,"
       "bytes32 initialRecipientsHash,bytes32 beneficiariesHash,"
       "bytes32 tokenDataArrayHash,bytes32 mintCommitmentsHash,"
       "uint256 quantity,bytes32 contextHash,bytes32 policyHash,"
       "bytes32 nonce,uint64 deadline)"
   );
   ```

2. The EIP-712 domain is `(name = "6529Stream Mint Tickets",
   version = "1", chainId, verifyingContract = ticket gate)`, exposed
   through ERC-5267. The genesis ticket-gate deployment is named
   `StreamMintTicketGate`; every inventory, mirror-table, and gate-row
   reference to the signed mint-ticket gate contract uses that name. The
   in-struct `chainId`, `manager`, and `ledger` fields are deliberate
   defense-in-depth duplication of domain material.
3. The state-changing mint recomputes every hash from calldata and chain
   state; a ticket is invalid if any field — including `authorizerKind`
   — differs from the signed payload, if `deadline` has passed, or if
   `policyHash` fails `[MPA-GRACE]` acceptance.
4. `authorizationId` derivation is a must, not a should:

   ```solidity
   bytes32 authorizationId = keccak256(abi.encode(
       TICKET_AUTHORIZATION_DOMAIN,
       // keccak256("6529STREAM_MINT_TICKET_AUTHORIZATION_V1")
       bytes32(eip712Digest) // full domain-separated EIP-712 digest
   ));
   ```

   Consuming the ticket and consuming the ledger replay key are the same
   fact; sale authorizations derive theirs identically
   (`docs/stream-sales-and-auctions.md` `[SSA-AUTH]`).
5. Ticket revocation (`[MPA-LEDGER]` rule 3) uses a pinned payload the
   authorizer signs or sends:

   ```text
   MINT_TICKET_REVOCATION_TYPEHASH = keccak256(
       "MintTicketRevocation(uint256 chainId,address manager,"
       "address ledger,bytes32 authorizationId)"
   );
   ```

   The manager must void the authorization when called by the ticket's
   `authorizer` directly, or by anyone presenting the authorizer's valid
   EIP-712/ERC-1271 revocation signature; verification follows
   `[MPA-AUTHZ]`.
6. Sale/drop adapters that do not use signed tickets must still pass
   explicit `payer`, `initialRecipients`, and `beneficiaries` and must
   emit the authority source used.
7. Typehashes and domains in this section are recorded in the protocol v1
   domain-constants mirror table with CI recomputation coverage.

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
5. New claim contracts.

Requirements [MPA-EXECUTORS]:

1. Executors are the highest-value trust boundary in the mint subsystem —
   a granted executor can consume authorizations and trigger mints — so
   they get the same onchain vetting as gates and resolvers: any contract
   executor that settles payment, consumes signed sale authorizations, or
   holds sale custody must be registered `ACTIVE` in the module registry
   as a sale adapter under
   [`docs/stream-sales-and-auctions.md`](stream-sales-and-auctions.md)
   `[SSA-REGISTRY]` before `setPhaseExecutor` may grant it rights.
2. The manager must refuse executor grants that violate rule 1 and must
   refuse EOA executors on any phase whose sale policy declares payment
   settlement.
3. Executor additions are `DELAYED_LOOSENING` governance actions and are
   folded into `policyHash` through the executor set hash.

This makes the manager a policy and accounting layer, not a public payment
router. Public mint UX can still exist through a registered public sale
adapter.

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
        uint8 authorizerKind;
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

Gate behavior [MPA-GATES]:

1. If `authorizationId != bytes32(0)`, the manager must ensure it has not been
   used before and then ask the ledger to consume it before calling Core.
2. If `nullifiers` is non-empty, the manager must ensure each nullifier has not
   been used before and then ask the ledger to consume them before calling
   Core. A gate may return nullifiers only when its accepted specification
   defines their domain (Protocol v1 Scope, exclusion 3).
3. Authorizer handling follows `[MPA-AUTHZ]`: the gate returns the
   explicit `authorizerKind`, the manager verifies the kind/address pairing,
   passes the authorizer into counter resolution when the kind is not
   `NONE`, and emits it in mint events.
4. If `maxQuantity != 0`, the batch quantity must be less than or equal to that
   gate limit.
5. `gateHash` should commit to gate-specific evidence, such as a Merkle root,
   ticket digest, settlement digest, or privacy proof public inputs.
6. Gate call gas is deterministic and governed (ADR 0010 decisions D1 and
   D10.3): the manager must call the gate with a limited-gas `staticcall`
   forwarding exactly `max(gateGasLimit, MINT_GATE_GAS_LIMIT)`, where
   `gateGasLimit` is the policy-pinned per-phase minimum from
   `MintGateConfig` and `MINT_GATE_GAS_LIMIT` is a manager Governed Gas
   Parameter (genesis value `400_000`, immutable floor from measured
   need). The pinned value keeps its deterministic meaning — the gate
   always receives at least it — while the GGP lets governance restore
   service after opcode repricing without touching policy identity. The
   63/64 parent-gas precheck applies; insufficient parent gas reverts
   (fail closed).
7. Gate returndata is bounded: the manager must reject returndata larger
   than `MAX_GATE_RETURNDATA_BYTES = 2_048` or more than
   `MAX_GATE_NULLIFIERS = 16` nullifiers, with typed errors. A failed,
   reverting, malformed, or oversized gate call reverts the mint
   (`MintGateCallFailed`); gates are fail-closed by construction.

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

Signed mint gates must use the canonical `MintTicket` shape and pinned
typehash defined in `Recipient Binding` (`[MPA-TICKET]`). This section does
not define a second struct or a second preimage.

Ticket rules [MPA-TICKET-RULES]:

1. `policyHash` must equal the active phase policy hash or the registered
   grace-window predecessor within its bound (`[MPA-GRACE]`).
2. `deadline` must be enforced in the state-changing mint path.
3. `authorizationId` must be derived from the full EIP-712 ticket digest
   per `[MPA-TICKET]` rule 4.
4. EOA signatures must use ECDSA recovery under the `[MPA-AUTHZ]` rules:
   zero recovery is invalid, the recovered address must match
   `authorizer`, and non-canonical `s`/`v` values are invalid.
5. Contract-wallet signatures must use ERC-1271 under the
   `TICKET_ERC1271_GAS_LIMIT` Governed Gas Parameter.
6. A gate that owns the typed-data domain must expose ERC-5267 domain
   introspection.
7. Replay protection belongs in the ledger, not only in the ticket gate.
8. An authorizer can durably revoke an unused ticket through the
   revocation surface (`[MPA-TICKET]` rule 5 and `[MPA-LEDGER]` rule 3);
   pause and policy churn are operational stops, not revocation.

EIP-712 provides typed-data structure and signing UX, but it does not provide
replay protection by itself. Nonces, authorization IDs, deadlines, chain ID,
manager address, ledger address, and policy hash must all be part of the
design.

## Smart Account Posture

The mint subsystem treats account abstraction as normal (ADR 0010 decision
D5.11).

Requirements [MPA-ACCOUNTS]:

1. No mint path reads `tx.origin` (static-analysis gate).
2. `executor`, `payer`, `recipient`, `authorizer`, and counter subject are
   separate concepts; executor/sponsor separation is ERC-4337-compatible,
   and paymaster-sponsored mints are a supported executor pattern — gas
   sponsorship never changes accounting identity, which always keys the
   configured subject.
3. ERC-1271 signatures are accepted anywhere a user authorization may come
   from a wallet, under Governed Gas Parameter bounds.
4. The actual executor is included in policy checks and events.
5. ERC-2771 trusted forwarders are excluded from the genesis mint
   subsystem (Standards Alignment rule 7); the recorded decision is out,
   not optional. Smart-account UX flows through ERC-4337, and the genesis
   public sale adapter is validated end-to-end from a smart account with
   a sponsoring paymaster
   ([`docs/stream-sales-and-auctions.md`](stream-sales-and-auctions.md)
   `[SSA-AA]`).
6. Counter resolvers (extension) should be able to map a transaction to a
   wallet, profile, delegation root, signed beneficiary, or
   privacy-preserving subject without changing the manager.
7. Genesis delegated minting uses the patterns pinned in
   [`docs/stream-sales-and-auctions.md`](stream-sales-and-auctions.md)
   `[SSA-DELEGATE]`: deliver-to-vault (counters key the vault) or
   signer-verified tickets. Keying per-holder counters to the acting hot
   wallet is non-conformant for per-holder limits — one vault could
   multiply allowance across delegates — and counting a vault while
   delivering elsewhere requires the excluded delegation counter-resolver
   extension.

## Module Registry [MPA-REGISTRY]

Gates and resolvers must be registered before a phase can use them. This
keeps the manager generic while still making module risk visible. The
registry interface, record shape, status vocabulary, and lifecycle
governance are owned by
[`docs/stream-long-term-architecture.md`](stream-long-term-architecture.md)
`[LTA-REGISTRY]` (ADR 0010 decision D10.2): the mint layer consumes
`IStreamModuleRegistry`, `StreamModuleRecord`, and `ModuleRegistryStatus`
and defines no registry surface of its own. The draft mint-layer names —
`IStreamMintModuleRegistry`, `MintModuleInfo`, `ModuleStatus`, the
`BLOCKED` status, and `isModuleActive` — are superseded aliases per
`[LTA-REGISTRY]` rule 1; `BLOCKED` denotes `INCIDENT_REVOKED`, and callers
that named `isModuleActive(module, interfaceId)` read
`isModuleEligible(module, moduleType, interfaceId)` with the relevant
module type.

Consumption requirements:

1. A gate must support the gate interface ID through ERC-165 and be
   registered with the mint-gate module type; a counter resolver must
   support the resolver interface ID through ERC-165 and be registered
   with the counter-resolver module type.
2. `ACTIVE` modules may be configured for new phase policy.
3. `DEPRECATED` modules remain readable but must not be configured for
   newly opened policy unless an explicit `DELAYED_LOOSENING` governance
   action allows that module for a named phase.
4. `INCIDENT_REVOKED` modules must not be configured, and state-changing
   mints must revert while a referenced module holds that status.
5. If `StreamModuleRecord.runtimeCodeHash` is nonzero, the manager must
   verify the module codehash when configuring policy and while minting.
6. `moduleManifestURI` is event/UI data; `moduleManifestHash`,
   `interfaceId`, `status`, and `runtimeCodeHash` are the durable security
   signals.
7. The registry record's `moduleGasLimit` and `moduleVersion` are
   configuration metadata per `[LTA-REGISTRY]` rule 3: configuration reads
   them (or an operator override) into the policy-pinned `gateGasLimit`
   and `gateSemanticVersion` fields of `GATE_CONFIG_DOMAIN`. Runtime
   enforcement is normative, not elective: the manager forwards
   `max(gateGasLimit, MINT_GATE_GAS_LIMIT)` per `[MPA-GATES]` rule 6, so a
   value hashed into policy identity has one deterministic meaning across
   implementations, and the registry field is never a live gas read.
8. Registered sale-adapter executors follow the same lifecycle rules as
   gates and resolvers; the conformance profile lives in
   [`docs/stream-sales-and-auctions.md`](stream-sales-and-auctions.md)
   `[SSA-REGISTRY]`.
9. Module registration and lifecycle events are the registry's
   schema-versioned `StreamModuleRegistered` and
   `StreamModuleStatusChanged` events (`[LTA-REGISTRY]`); the mint layer
   defines no parallel module-metadata event.

A frozen `policyHash` may continue to reference a module that later becomes
`DEPRECATED` if the module codehash still matches the hash pinned in the
phase policy and the registry has not marked it `INCIDENT_REVOKED`. New
phases cannot choose a deprecated module unless an explicit delayed
governance action allows that module for a named phase. If a module is
`INCIDENT_REVOKED`, state-changing mints revert even for frozen or
previously signed policy hashes. This makes deprecation a forward-looking
lifecycle signal and incident revocation a safety stop.

This registry consumption is intentionally boring. The registry is not a
plugin VM; it is a typed allowlist with versioning, code identity, and
lifecycle status.

## Artist Consent Modes

The platform can never extend an artist-bound series without a verifiable
artist authorization chain (ADR 0010 decision D2.4). Collection creation
pins one of three consent modes — `ARTIST_SIGNED_POLICY`,
`ARTIST_DELEGATED`, or `PLATFORM_WORKS` — whose definitions, artist
acceptance ceremony, key lifecycle, delegation payloads, and dispute states
are owned by the artist authority specification,
[`docs/stream-artist-authority.md`](stream-artist-authority.md) (ADR 0010 decision D2). This section
binds those modes into the mint path; it does not restate their home.

Requirements [MPA-CONSENT]:

1. For a collection whose pinned mode is not `PLATFORM_WORKS`, the manager
   must refuse `configurePhase` and every policy re-registration —
   including executor-set changes and gate changes — unless artist
   authorization over the exact resulting `policyHash` is verifiable:
   under `ARTIST_SIGNED_POLICY`, an EIP-712/ERC-1271 co-signature by the
   accepted artist (or estate) over the policy consent payload defined in
   the artist authority spec; under `ARTIST_DELEGATED`, a signature by a
   platform signer inside a live, scoped, unexpired artist delegation.
2. Verification is a bounded read against the artist authority registry
   under the `ARTIST_AUTHORITY_GAS_LIMIT` Governed Gas Parameter (genesis
   value `150_000`); an unavailable registry fails closed for
   consent-bound configuration.
3. Consent evidence is evented: the manager emits
   `MintPhaseConsentRecorded` (Events) binding the consent mode, the
   consent evidence hash, and the consented `policyHash`, so every
   token's artist sanction is reconstructable as
   token -> phase -> policyHash -> consent record.
4. `PLATFORM_WORKS` collections carry the immutable declaration made at
   creation (artist authority spec); the manager treats them as
   consent-unconstrained and surfaces the class in phase metadata.
5. Per-token content commitment under a consented policy comes from the
   existing bindings: tickets bind `tokenDataArrayHash` and
   `mintCommitmentsHash`, and content manifests
   ([`docs/stream-sales-and-auctions.md`](stream-sales-and-auctions.md)
   `[SSA-CONTENT]`) pin curated sets, all under the consented
   `policyHash`. An operator cannot swap content without rotating the
   hash and re-triggering rule 1.
6. Artist standing over live phases follows the artist authority spec's
   pause/dispute surfaces; nothing in the mint path may bypass a
   registry-recorded `DISPUTED` or `REVOKED` state for consent-bound
   configuration.

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
16. For each token, Core writes token identity, collection serial, and
    renderer-visible `tokenData` verified against `tokenDataHash`, and
    emits `TokenCollectionRegistered`.
17. The authorized mint manager, sale adapter, or resolver hook records any
    required token-level primary or royalty snapshot after Core has created
    authoritative token identity and before any untrusted receiver callback.
    Core stores no revenue assignment or snapshot state.
18. Core registers bounded entropy state through the entropy coordinator
    boundary, without calling external randomness providers.
19. Core calls `_safeMint(initialRecipient, tokenId)`. This is the first point
    where an untrusted recipient callback can run.
20. Emit manager mint events with `policyHash`.

Ledger accounting should happen before the Core mint calls. If any Core mint
reverts, EVM rollback reverts the ledger updates too.
This sequence and the two paid paths below satisfy the protocol v1
per-path ordering invariants
([`docs/launch-v1-target-architecture.md`](launch-v1-target-architecture.md)
[PV1-MINT-ORDER]):
no untrusted callback before counter consumption, identity mapping,
required snapshots, revenue accounting, and entropy registration are
complete for that token. Entropy registration before `_safeMint` is
normative; the matrix entropy gate enforces it at deployment.

Implementation evidence (non-normative). The current direct-randomizer
slice still reaches its hash boundary after `_safeMint` and therefore
fails the entropy gate; see the labeled evidence block in Core Contract
Changes. Normative sequences in this document describe only the
entropy-coordinator ordering.

For paid primary mints, protocol v1 must use exactly one of the named
orchestration paths in
[`docs/revenue-splits-and-royalties.md`](revenue-splits-and-royalties.md)
for the transaction in which a token is minted against payment (adapter
custody before official settlement, and paid transfer of custody-held
minted tokens, are governed by
[`docs/stream-sales-and-auctions.md`](stream-sales-and-auctions.md)):

1. `PRE_REVENUE_SINGLE_STEP`: sale adapter records split-wallet deposit or
   escrow before calling the mint manager, and token-level primary overrides or
   required mint-time royalty snapshots are unavailable. In v1 manager
   accounting, a `RECIPIENT`-keyed counter is keyed to `beneficiary`, not the
   temporary `initialRecipient`, and the manager is the enforcement point
   for recipient-owner equality [MPA-SINGLE-STEP]: when any
   `RECIPIENT`-keyed counter is enabled on the phase, the manager must
   require `initialRecipients[i] == beneficiaries[i]` for each element and
   otherwise revert with `MintSingleStepRecipientMismatch(index)`. Matrix
   golden test 16 exercises the manager. Custody settlement that needs
   custody delivery or richer token-level snapshots must use
   `PREPARED_MINT`.
2. `PREPARED_MINT`: mint manager and ledger validate/consume policy, Core
   `prepareMintFromManager` allocates token identity without an ERC-721
   transfer, resolver snapshots required token-level economics, sale adapter
   deposits or escrows native ETH, and Core `completePreparedMintFromManager`
   performs `_safeMint`.

No paid mint may call `_safeMint` to an untrusted recipient before ledger
consumption, Core identity mapping, required assignment snapshots for the chosen
path, and revenue accounting are complete. Phases that require pre-callback
token-level snapshots must use `PREPARED_MINT` and keep snapshots independent of
randomness.
The mint manager owns the top-level non-reentrant operation lock for
`PREPARED_MINT`; Core prepare/complete, resolver snapshot hooks, ledger
consumption, and sale-adapter callbacks must all run under that manager-owned
operation context or an equivalent shared operation ID that prevents
interleaving with another mint, transfer, burn, release, escrow flush, or
snapshot for the prepared token.

Duplicate beneficiaries, duplicate initial recipients, or duplicate counter keys
in a batch must not bypass caps. The v1 implementation must aggregate projected
increments before writing state so all counters are evaluated against the
complete batch. Sequential fallback is not deployment-conformant unless a
separate accepted ADR defines and tests it.

## Events

Configuration events:

```solidity
event MintPhaseConfigured(
    uint256 indexed collectionId,
    bytes32 indexed phaseId,
    bytes32 configHash,
    bytes32 policyHash
);

event MintPhasePausedEvent(
    uint256 indexed collectionId,
    bytes32 indexed phaseId,
    bool paused,
    bytes32 policyHash,
    address admin
);

event MintPhaseFrozen(
    uint256 indexed collectionId,
    bytes32 indexed phaseId,
    bool frozen,
    bytes32 policyHash
);

event MintPhaseExecutorUpdated(
    uint256 indexed collectionId,
    bytes32 indexed phaseId,
    address indexed executor,
    bool allowed,
    bytes32 policyHash,
    address admin
);

event MintPhaseGateUpdated(
    uint256 indexed collectionId,
    bytes32 indexed phaseId,
    address indexed gate,
    bytes32 policyHash
);

event MintPhaseConsentRecorded(
    uint16 schemaVersion,
    uint256 indexed collectionId,
    bytes32 indexed phaseId,
    bytes32 indexed policyHash,
    uint8 consentMode,
    bytes32 consentEvidenceHash
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
    bytes32 capRoot,
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
error MintInvalidAuthorizerKind(uint8 kind, address authorizer);
error MintGateCallFailed(address gate);
error MintGateReturndataOverflow(address gate, uint256 size);
error MintAllowlistProofInvalid(bytes32 counterId, address account);
error MintZeroIncrementConfigured(bytes32 counterId);
error MintPolicyGraceBoundExceeded(uint64 graceUntil, uint64 maxAllowed);
error MintLedgerCrossManagerWrite(address manager, address caller);
error MintAuthorizationVoidUnauthorized(bytes32 authorizationId);
error MintImportProofInvalid(bytes32 importRoot);
error MintImportLeafAlreadyApplied(bytes32 importRoot, bytes32 leafHash);
error MintConsentMissing(uint256 collectionId, bytes32 policyHash);
error MintReservedScopeCollision(uint256 collectionId, bytes32 phaseId);
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

function phasePolicyGrace(uint256 collectionId, bytes32 phaseId)
    external
    view
    returns (bytes32 previousPolicyHash, uint64 graceUntil);
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
    MintPhaseConfig calldata config,
    MintGateConfig calldata gateConfig,
    bytes32[] calldata counterIds,
    MintCounterConfig[] calldata counterConfigs,
    bytes calldata consentEvidence // empty for PLATFORM_WORKS collections
) external;

function setPhaseExecutor(
    uint256 collectionId,
    bytes32 phaseId,
    address executor,
    bool allowed
) external;

function setPhasePaused(
    uint256 collectionId,
    bytes32 phaseId,
    bool paused
) external;
```

Mutable-manager implementations accepted in their own specs may add separate
counter, metadata, ledger, or registry administration:

```solidity
function configureCounter(
    uint256 collectionId,
    bytes32 phaseId,
    bytes32 counterId,
    MintCounterConfig calldata config
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
4. Counter scope, key mode, update mode, resolver, and `capRoot` cannot
   change.
5. New counters cannot be added.
6. Time windows cannot be extended.
7. Gate cannot be loosened.
8. Executors cannot be added.
9. Pause may still be allowed if the product wants emergency stops.
10. Cap mode and delta mode cannot be loosened.
11. Module codehash pins cannot be removed.
12. Policy cannot move to a different ledger.

Every phase freeze transition must emit `MintPhaseFrozen` with the resulting
state and the policy hash that was frozen, so event replay can reconstruct when
the phase became permanently stricter.

Counter values must never be decremented. If an operator needs a different
policy, the correct answer is a new phase ID or a new stricter counter, not
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
7. `mint()` and the `PREPARED_MINT` entrypoint must use a reentrancy guard
   or the manager operation lock (ADR 0010 decision D10.3); this maps to
   the conformance-matrix mint-accounting gate, matching the split wallet,
   escrow flush, and coordinator guards, which are also musts.
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
13. Full manager-level counter storage keys should be domain-separated by chain
    ID and ledger address. The CON-013 genesis ledger intentionally uses a
    phase-scoped in-ledger key derived from manager, collection ID, phase ID,
    counter ID, and subject key; managers must still bind chain ID and ledger
    address into policy hashes and authorization IDs.
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
22. Authorization IDs and nullifiers must be domain-separated from one
    another, and both are manager-scoped in ledger storage.
23. Counter increments must be `>= 1` in every mode — static, Merkle, and
    resolver — at configuration and at consumption (ADR 0010 decision
    D8.4).
24. Preview APIs must not be trusted for authorization.
25. No live mint path should use ERC-2309-style consecutive minting; normal
    per-token ERC-721 transfer events remain the indexer and marketplace
    friendly path.
26. Recipient reentrancy cannot observe a token before ledger consumption,
    identity mapping, required royalty snapshots, and entropy registration
    are complete.
27. Signature verification follows `[MPA-AUTHZ]`: zero `ecrecover` results
    and non-canonical `s`/`v` values are invalid everywhere, and no
    surface treats `address(0)` as a blessed authorizer.
28. Ledger writes, voids, grace registrations, and imports are bound to
    `msg.sender == manager`; cross-manager writes revert.

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
10. No external recipient callback executes before the token's identity
    mapping, required royalty snapshot, and entropy registration are
    complete.
11. A frozen phase cannot be loosened.
12. A counter value never decreases through succession import; imports
    merge by maximum and each import leaf applies at most once.
13. An authorized ledger writer can never consume, void, grace, or import
    under another manager's scope.
14. A voided authorization can never mint.

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

Target auction flows are owned by
[`docs/stream-sales-and-auctions.md`](stream-sales-and-auctions.md): the
English auction house is a registered sale adapter and phase executor, the
auction-start custody mint uses the `AUCTION_START_CUSTODY` pattern
(custody as recipient and beneficiary; `CONSTANT`/`EXECUTOR`/`CONTEXT`
counters only), mint-at-settlement uses `PREPARED_MINT`, and settlement of
a custody-held minted token uses the named
`AUCTION_SETTLEMENT_TRANSFER` order:

```text
StreamEnglishAuctionHouse (registered sale adapter)
  -> validate auction context and signed sale authorization
  -> StreamMintManager.mint(...) or prepare/complete pair
  -> StreamMintLedger.consume(...)
  -> StreamCore mint hooks
  -> settlement per stream-sales-and-auctions.md [SSA-ENGLISH]
```

`StreamMinter` can be replaced by `StreamMintManager` before production
deployment. The preferred genesis design is one mint manager contract for
phase policy and one mint ledger contract for durable accounting.

## Implementation Sequence

### Phase 1: Core Mint Boundary

1. Add `mintManager` to Core.
2. Add `mintFromManager()`.
3. Make Core compute the next token ID internally.
4. Remove per-address mint counters from Core.
5. Remove `maxCollectionPurchases` from Core collection data.

### Phase 2: Manager Policy And Accounting

Status: CON-013 and CON-014 implement the static v1 foundation:

1. `StreamMintLedger` owns deployed manager writers, phase policy hashes,
   static counter policies, counter values, and authorization replay
   state.
2. `StreamMintManager` owns phase configuration, executor authorization,
   pause/window guards, canonical `policyHash` computation, counter subject
   derivation, batch cap validation, ledger consumption, and Core
   prepare/complete execution.
3. The implemented manager supports static counter increments, static or
   uncapped counters, and subject modes for constant, payer, recipient,
   executor, authorizer, and context-derived keys.
4. `mintPrepared` requires a nonzero `expectedPolicyHash` and nonzero
   `authorizationId` so production execution cannot bypass stale-policy
   detection or ledger replay protection. `authorizationId` is a replay key
   supplied by the allowlisted executor; it is not, by itself, cryptographic
   signature verification. A buggy or compromised allowlisted executor can
   choose the request contents for any unused `authorizationId`, so untrusted
   sale, drop, or gate flows must bind `authorizationId` to their own reviewed
   signed commitment before they receive executor rights.
5. Gates, payment settlement, sale/auction routing, `GLOBAL` scope
   derivation, the `MERKLE_STATIC` cap mode, grace windows, revocation,
   succession import, and burn-gate nullifier consumption remain later
   implementation slices of this specification; dynamic resolver
   caps/deltas and privacy-preserving nullifier resolvers are protocol v1
   exclusions until their own ADRs are accepted.

`configurePhase` is initial-only in the genesis manager. Reconfiguration that
changes a phase's counter set must use a new phase ID or a separately accepted
explicit reconfiguration path with reviewed migration semantics. Executor-set
changes and pause changes are intentionally folded into `policyHash`; they
refresh the registered ledger policy and invalidate in-flight requests bound
to the prior `expectedPolicyHash`. Returning to the same executor set and
pause/config state may restore the same deterministic hash, but replay
protection still comes from the ledger-scoped `authorizationId`. Phase pause
is therefore an operational stop switch, not durable revocation for an
unused authorization; durable revocation is the signer-side
`voidAuthorization` surface (`[MPA-LEDGER]` rule 3 and `[MPA-TICKET]`
rule 5), which burns exactly the bad replay key without churning policy
for every other in-flight request. Policy-hash churn additionally strands
outstanding tickets only up to the `[MPA-GRACE]` window when one is set.

### Phase 3: Gates And Counter Resolvers

1. Add optional gate interface support.
2. Add module registry checks.
3. Add signed authorization replay protection in the ledger.
4. Add custom counter resolver support only after the static v1 path is
   audited.
5. Add EIP-712 signed ticket gate.
6. Add ERC-1271 smart-wallet signature support.
7. Add TDH/drop gate if needed.
8. Add Merkle gates where product flows require them.
9. Add nullifier support for privacy-preserving claim systems as a separately
   accepted extension.

### Phase 4: Integration And Tooling

1. Route fixed-price drops through the manager.
2. Route auction minting through the manager.
3. Connect primary-sale settlement before manager minting.
4. Add admin/operator phase inspection tools.
5. Add explainable preview views.
6. Add indexer docs for phase, policy-hash, module, and counter-consumption
   events.

## Gas Budget Artifact

A collector's mint cost is a product fact, and this pipeline is the deepest
paid-mint path in the field, so the budget is measured and published, not
discovered by competitors (ADR 0010 decision D5.10).

Requirements [MPA-GAS-BUDGET]:

1. The release manifest must include a measured all-cold end-to-end gas
   report for the collector-facing transaction of both paid paths —
   `PRE_REVENUE_SINGLE_STEP` and `PREPARED_MINT` — for a single mint and
   a batch of 10, plus the free allowlisted mint, the genesis fixed-price
   purchase, and the Dutch standard purchase
   ([`docs/stream-sales-and-auctions.md`](stream-sales-and-auctions.md)
   gate 10).
2. The report states an acceptable envelope per path; the deployment gate
   fails if a measured path exceeds its envelope, and envelope changes are
   reviewed release-artifact changes.
3. The measurement harness is reproducible from the repository (foundry
   gas snapshots over the rehearsal deployment) and the artifact is
   checksum-covered like every other release manifest entry.

## Test Requirements

Core tests:

1. Only `mintManager` can call `mintFromManager()`.
2. Core computes the next token ID from the global sequential counter and
   stores the collection-local serial explicitly in the token identity
   record (ADR 0009 decision 1).
3. Core reverts when the collection is unknown, paused, closed, not yet active
   for minting, or artwork-finality-blocked for new supply.
4. Core reverts when collection supply is exhausted.
5. Core stores token-to-collection identity and returns the collection-local
   serial through `tokenCollectionIdentity`.
6. Core retains identity after burn.

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
    identity mapping, required snapshots, and entropy registration exist,
    and cannot reenter mint paths to bypass counters.
30. Configuring an enabled counter with `increment == 0` reverts, and a
    consumption supplying `increment == 0` reverts before any counter or
    mint state is written (golden test, ADR 0010 decision D8.4).
31. A ticket with a garbage signature and `authorizer == address(0)` is
    rejected; a zero `ecrecover` result never validates; high-`s` and
    invalid-`v` signatures are rejected (golden negative tests).
32. `MERKLE_STATIC`: valid leaf proofs enforce per-subject caps; invalid
    proofs revert; leaf caps above the registered ceiling revert; the
    sale-side `priceOverride` binds from the same leaf.
33. `GLOBAL` scope counters share one value across collections and phases
    using the reserved `(0, 0)` derivation; registration for collection 0
    or phase 0 reverts (golden reserved-constant test).
34. `PRE_REVENUE_SINGLE_STEP` with any `RECIPIENT`-keyed counter requires
    `initialRecipient == beneficiary` per element in the manager and
    reverts `MintSingleStepRecipientMismatch` otherwise (matrix golden
    test 16, manager-targeted).
35. Gate calls forward exactly `max(gateGasLimit, MINT_GATE_GAS_LIMIT)`;
    oversized returndata and nullifier counts revert; a reverting gate
    fails the mint closed.
36. Consent-bound collections: phase configuration without valid artist
    authorization over the resulting `policyHash` reverts; consent
    evidence events reconstruct the sanction chain.

Resolver/nullifier extension tests:

1. Before a resolver ADR is accepted, configuring
   `CounterCapMode.RESOLVER`, `CounterDeltaMode.RESOLVER`, or
   `CUSTOM_RESOLVER` reverts before state changes; nullifier consumption
   from any gate that is not registry-`ACTIVE` with an accepted nullifier
   domain reverts before state changes.
2. After a resolver/nullifier ADR is accepted, dynamic resolver caps are
   enforced.
3. Dynamic resolver increments are enforced.
4. Resolver-based accounting is used when configured.
5. Nullifiers cannot be reused.

Ledger tests:

1. Only authorized manager contracts can consume counters, and only in
   their own manager scope.
2. Counter values never decrease.
3. Ledger rejects any projected value above cap.
4. Authorization IDs cannot be reused; voided IDs cannot be consumed;
   voiding emits the distinct revocation event.
5. Nullifiers cannot be reused within a manager scope, and one manager
   cannot consume or pre-consume another manager's nullifier scope
   (cross-manager griefing test).
6. Primary counter and authorization ledger events include `policyHash`; context
   events are correlated by indexed key topics in the same transaction.
7. Multiple consumptions for the same value key aggregate correctly.
8. Ledger verifies the active `policyHash` before writing consumption,
   accepting the grace-window predecessor only until `graceUntil` and
   always applying current counter policies.
9. `registerPhasePolicy` with `msg.sender != manager` reverts
   (cross-manager registration rejection).
10. Grace registration beyond `MAX_POLICY_GRACE_SECONDS` reverts; expired
    grace hashes are rejected at consumption.
11. Zero-increment registration and zero-increment consumption revert.
12. Succession import: committed root required; proofs verified; imports
    merge by maximum and never lower values; each leaf applies once;
    imports write only the successor manager's scope; a counter consumed
    mid-drop retains its consumed allowance across a manager swap
    (continuity gate).

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
19. Resolver-provided dynamic caps and increments are excluded from protocol
    v1 unless admitted by their own accepted ADR; the `MERKLE_STATIC`
    allowlist cap mode ships at genesis without a resolver.
20. Nullifier consumption is manager-scoped and live at genesis for
    registry-`ACTIVE` gates with accepted nullifier domains;
    privacy-preserving nullifier resolvers remain excluded until their own
    accepted ADR.
21. `canMint()` returns explainable counter previews, not just a boolean.
22. Freeze policy prevents later loosening of frozen phases.
23. Every counter increment is `>= 1`; no zero-sentinel exists.
24. Signers can durably revoke unused authorizations, and policy changes
    can carry a bounded grace window instead of stranding every ticket.
25. Counter values and consumed nullifiers survive manager and ledger
    succession through the governed Merkle import path.
26. Artist-bound collections cannot gain or change phases without
    verifiable artist authorization over the exact policy hash.
27. The release manifest carries the measured end-to-end collector mint
    gas budget within its stated envelope.
