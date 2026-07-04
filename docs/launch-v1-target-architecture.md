# Stream Protocol v1 Specification

Specification status: Draft. This document follows
[`docs/spec-policy.md`](spec-policy.md); the decisions formerly tracked
inline are resolved by
[ADR 0009](adr/0009-protocol-v1-open-question-resolutions.md) and recorded
in [`docs/spec-open-questions.md`](spec-open-questions.md).

This document is the normative protocol v1 specification for 6529Stream. It
reconciles the revenue, mint, metadata, and entropy specs into one protocol
scope. 6529Stream is permanent infrastructure for the 6529 network: the
first production deployment is the permanent system, and these requirements
are the standard that deployment must satisfy — there is no lower
provisional bar for a first version and no deferred-quality tier after it.

The current repository contracts predate this specification and do not yet
conform. [`docs/launch-conformance-matrix.md`](launch-conformance-matrix.md)
is the enforcement point: it blocks any production deployment on the full
gate set, and [`docs/architecture.md`](architecture.md) maps the as-built
baseline honestly until the implementation conforms.

## Protocol v1 Scope

Requirements [PV1-SCOPE]:

Protocol v1 is the smallest system consistent with the owner-ratified
permanence and flexibility posture (ADR 0010 decision D9.1). That is an
honest claim, not a minimalism claim: every subsystem below is
genesis-mandatory because a permanence guarantee, an artist-authority
guarantee, or a ratified flexibility decision depends on it, and the
resulting audit surface is large. The full genesis contract inventory with
an exact count, and the published subsystem-by-subsystem audit plan that
makes the surface reviewable, are carried by
[`docs/launch-conformance-matrix.md`](launch-conformance-matrix.md)
(Genesis Deployment Profile). The system remains extensible over a 50+
year contract life through the frozen extension mechanisms only:

| Area | Protocol v1 requirement | Extension surface (Permanent from v1) |
| --- | --- | --- |
| Core | ERC-721 ownership, token identity, collection identity, supply invariants, minimal router/resolver/coordinator hooks, and Core-native ERC-2981 | None. Core gains no new semantics after deployment; no mutable policy or rendering logic in Core. Changing Core surfaces means a successor Core line |
| Revenue | Immutable split profiles, deterministic split wallets, resolver assignments, native ETH primary settlement, approved-standard ERC-20 primary settlement through outside-Core adapters, passive royalty receipt, and native/approved-asset revenue escrow | New settlement or recovery adapters are new Replaceable modules with their own accepted specs; non-standard ERC-20 behavior stays excluded until a spec accepts it |
| Royalties | Core-native ERC-2981 that calls a resolver for receiver and bps, then computes amount in Core | Resolver implementations rotate behind the frozen resolver interface; marketplace registry overrides remain integration extras outside the protocol |
| Minting | `StreamMintManager` policy plus `StreamMintLedger` accounting with many counters, aggregate-only consumption, signed tickets, and module-checked gates/resolvers | New counter resolvers and gates register through the frozen module registry and gate/resolver interfaces |
| Metadata | `StreamMetadataRouter`, `StreamRendererV1`, `StreamCollectionMetadata`, and genesis preservation/attestation/view satellites for identity, rights, media, scripts, dependencies, custom fields, locks, schemas, C2PA, IIIF, PREMIS-style records, preservation, and museum-grade catalogue material | Additional legal, rights, VC/DID, EAS, or institution-specific modules extend the same Permanent manifest and record model |
| Entropy | `StreamEntropyCoordinator`, Chainlink VRF primary provider, one reviewed fallback provider (ARRNG preferred, Pyth as the reviewed alternate), and a mock provider for local validation; VRF-only deployment is not conformant (ADR 0009 decision 21) | New providers are adapters behind the same Permanent provider interface, added through registry approval and provider epochs |
| Sales and auctions | Sale adapter conformance profile, registry-governed genesis adapters (fixed price/open edition with refund-window mode, English auction with anti-snipe, Dutch auction with clearing rebates, private sale/offers), burn-to-mint and delegate gate modules, and signed sale authorizations, per [`docs/stream-sales-and-auctions.md`](stream-sales-and-auctions.md) (ADR 0010 decision D5) | New mechanics are new Replaceable adapters behind the frozen `IStreamSaleAdapter`-family interfaces; sealed-bid and ranked auctions are frozen extension profiles without genesis bytecode |
| Artist authority | Two-sided artist binding, consent modes in the mint path, artist sanction as a finality component, economics consent and royalty freeze rights, and the key rotation/estate/dormancy lifecycle, per [`docs/stream-artist-authority.md`](stream-artist-authority.md) (ADR 0010 decision D2) | Delegation scopes, successor kinds, and arbiter policies extend behind the frozen registry interfaces with their own accepted specs |

Every implementation requirement in the Stream specs carries a permanence
class as defined in [`docs/spec-policy.md`](spec-policy.md): Permanent,
Replaceable, or Operational. Spec documents may describe extension points,
but a module outside the genesis deployment set must never become an
implicit dependency of a Permanent or genesis surface merely because it
appears in a design appendix.

## Canonical Token Identity

Requirements [PV1-IDENTITY]:

Protocol v1 uses explicit Core-owned token identity. This is Permanent
semantics:

1. Core allocates sequential global ERC-721 `tokenId` values from one
   counter starting at 1 (ADR 0009 decision 1).
2. Core writes `tokenId -> collectionId`.
3. Core writes `tokenId -> collectionSerial`.
4. Core exposes a non-reverting authoritative identity read — the
   `mappingExists` result of `tokenCollectionIdentity` — used by royalty,
   metadata, burn, and audit reads. This is distinct from ERC-721 minted
   ownership existence; a reserved token identity is not transferable until
   final mint. The read semantics are Permanent; whether Core stores a
   discrete identity flag or derives it from ownership, burned-token audit
   state, and prepared-mint state is implementation-defined, provided the
   read is authoritative and never reverts.
5. Core owns collection supply mode, status, max supply when applicable,
   minted-ever counts, burned counts, and next serial.
6. Core is the only source of truth for token existence and collection
   membership.

Token ID arithmetic is never authority and carries no meaning. The reserved
range formula in the baseline code, `collectionId * 10_000_000_000`, must be
removed from the allocator (ADR 0009 decision 1): token IDs are sequential
and global, `collectionId` and `collectionSerial` are stored explicitly in
the token identity record, and no serial or collection value may be derived
from the shape of a token ID. Packing `collectionId` and `collectionSerial`
into one storage slot with bounded widths is an implementation choice; the
read surface returns `uint256` values.

Identity, burn audit, royalty, resolver, and router resolution reads must
use the authoritative identity read and stored collection mapping, not
ERC-721 ownership existence or `_requireMinted`. `tokenURI()` may keep
normal ERC-721 metadata behavior for unminted tokens, but metadata routing
must not infer collection identity from token ID ranges.

### Mint Ordering Invariants

Requirements [PV1-MINT-ORDER]. This section is the normative home of
protocol v1 mint ordering (ADR 0010 decision D3.6). The ordering is a set
of per-path invariants, not one total order: the two blessed paid-path
realizations are defined once in
[`docs/revenue-splits-and-royalties.md`](revenue-splits-and-royalties.md)
([RSR-ORCHESTRATION]), and sale adapters bind to them under
[`docs/stream-sales-and-auctions.md`](stream-sales-and-auctions.md)
([SSA-ADAPTER]). Every conformant mint execution must satisfy all of the
following invariants:

1. Validation before effects. Executor, payment, signature, gate, and
   mint policy validation must complete before any state-changing effect
   of the mint transaction.
2. Ledger before Core execution. Mint ledger counters, authorization IDs,
   and any nullifiers must be consumed before Core token allocation for
   the same operation (`mintFromManager` or `prepareMintFromManager`).
3. Identity at allocation. Core writes `tokenId -> collectionId` and
   `tokenId -> collectionSerial` and emits `TokenCollectionRegistered`
   (ADR 0010 decision D10.1; ABI and event home
   [`docs/mint-policy-and-accounting.md`](mint-policy-and-accounting.md)
   [MPA-CORE-ABI]) at the moment identity is allocated, before any
   dependent snapshot, entropy registration, or ERC-721 transfer.
4. Revenue before transferability. Official revenue must be recorded in
   the verified split wallet or protocol escrow before the minted token
   becomes transferable. Paths that require token-level assignment
   snapshots must read Core's authoritative identity after allocation and
   write the snapshot before mint completion.
5. Entropy before callbacks. The token's entropy request context must be
   registered before any untrusted recipient callback; the
   conformance-matrix entropy gate enforces this ordering at deployment.
6. No untrusted callback may observe an unpaid, unregistered,
   unsnapshotted, or unaccounted mint (conformance-matrix paid-mint
   deployment test 1). If recipient callback timing would violate these
   invariants, the implementation must mint to custody first or use an
   internal mint followed by a separate safe transfer.

Two-path realization rule: a transaction that mints a token against
payment must use exactly one of the two blessed realizations of these
invariants — `PRE_REVENUE_SINGLE_STEP` or `PREPARED_MINT` — as specified
in [RSR-ORCHESTRATION]. Adapter custody of buyer funds before official
settlement is not a third mint order ([SSA-ADAPTER]), and paid transfer
of an already-minted custody-held token is a settlement ordering
(`CUSTODY_SETTLEMENT_TRANSFER`, [RSR-SETTLEMENT-BOUNDARY]; realized by
`AUCTION_SETTLEMENT_TRANSFER` in the sales spec), never a mint order.
Point-in-time implementation caveats do not belong in this section;
as-built deviations are recorded as labeled non-normative evidence in the
documents that own the affected path.

## Core Hook Budget

Requirements [PV1-HOOKS]:

Core-native ERC-2981 is mandatory. Core may stay small only by moving other
logic out.

The implementation must provide one measured Core hook proof before the
implementation PR is accepted. The proof must be produced by:

```bash
forge build --sizes --via-ir --skip test --skip script --force
python scripts/check_contract_size_budget.py
```

The measured Core must include every mandatory hook with final call shapes,
not placeholders that omit calldata, returndata, storage, or external call
paths:

| Hook | Selector owner | Required caller/user |
| --- | --- | --- |
| `royaltyInfo(uint256,uint256)` | Core | Marketplaces and indexers |
| `supportsInterface(bytes4)` with ERC-721, ERC-4906, ERC-2981, and any accepted enumerable interface | Core | Marketplaces and indexers |
| `mintFromManager(...)` and the prepared-mint pair, per the manager-only mint ABI home ([`docs/mint-policy-and-accounting.md`](mint-policy-and-accounting.md) [MPA-CORE-ABI]) | Core | `StreamMintManager` only |
| `TokenCollectionRegistered(tokenId, collectionId, serial)` emission at identity write (ADR 0010 decision D10.1) | Core | Indexers and archive reconstruction |
| token identity reads: collection ID, collection serial, authoritative identity read, burn audit as needed | Core | Resolver, router, indexers |
| metadata router pointer read and update | Core | Admin and `tokenURI()` path |
| minimal `tokenURI()` delegation to router | Core | ERC-721 metadata callers |
| minimal `contractURI()` delegation to the contract-metadata satellite (ADR 0009 decision 4) | Core | Marketplaces and indexers (ERC-7572) |
| collection metadata pointer read and update | Core | Router and admin tooling |
| entropy coordinator pointer read and update | Core | Mint and entropy lifecycle |
| entropy registration call during mint | Core to coordinator | Mint path |
| Core-originated ERC-4906 refresh emitters callable by authorized satellites (ADR 0009 decision 5) | Core | Metadata router, finality registry, entropy coordinator |

This hook table is the normative home of the Core refresh-emitter caller
set (ADR 0010 decision D3.6): the restricted ERC-4906 helpers are callable
by exactly three satellites — the metadata router, the artwork finality
registry, and the entropy coordinator — each authorized by resolving
Core's cached satellite pointers at call time, never through a separately
mutable allowlist.
[`docs/metadata-router-and-renderer.md`](metadata-router-and-renderer.md)
([MRR-REFRESH-EMITTERS]) and the entropy coordinator spec cite this set,
and a conformance-matrix golden test pins the exact caller list. Token
data ownership is likewise single-sourced: V1 Core stores the
renderer-visible `tokenData` bytes and their `tokenDataHash` per the mint
ABI home ([MPA-CORE-ABI]); no other document may redefine that storage
split.

The implementation PR must report:

1. Previous `StreamCore` runtime size.
2. New `StreamCore` runtime size.
3. EIP-170 margin.
4. Whether the margin remains above the release floor and warning threshold.
5. Which non-essential Core logic was moved out if the first attempt failed.

The governing size rule is the conformance-matrix headroom target
(ADR 0009 decision 2): `StreamCore` runtime must retain at least 2,000
bytes of EIP-170 margin at the deployment gate, proven by one
post-extraction measured build that includes every mandatory hook in the
table above. The bytecode-spend baseline and exception ledger in
`release-artifacts/contracts.json` remain the pre-deployment development
control; interim exceptions cannot survive to the deployment gate.

Implementation evidence (non-normative). Measured Core hook proof at the
time of the CON-012 slice:

1. Approved `StreamCore` bytecode-spend baseline: 22,184 bytes.
2. New measured `StreamCore` runtime: 24,150 bytes.
3. EIP-170 margin: 426 bytes.
4. The margin remains above the 384-byte release floor but below the
   512-byte warning threshold.
5. The Core hook keeps the immediate manager mint ABI minimal and leaves
   beneficiary/payment evidence, batch commitments, operation events, and
   richer mint policy to the manager, ledger, sale adapter, and settlement
   satellites.

Implementation evidence (non-normative). CON-013 slice:

1. `StreamMintLedger` is release-tracked as the first outside-Core durable
   mint accounting satellite.
2. The ledger supports owner-authorized deployed-contract writers, one
   active registered `policyHash` per `(manager, collectionId, phaseId)`,
   deployment-safe static counter policies, canonical manager-scoped
   value-key derivation, cap-checked counter consumption, durable values
   across policy re-registration, and manager-scoped authorization replay
   protection.
3. Resolver caps/deltas, custom gates, callable nullifier systems, sale/drop
   routing, payment collection, and Core mint execution remain outside this
   ledger-only slice.

Implementation evidence (non-normative). CON-014 slice:

1. `StreamMintManager` is release-tracked as the outside-Core phase policy
   and prepared-mint execution surface paired with `StreamMintLedger`.
2. The manager supports owner-configured static phase policies, ordered
   counters, executor allowlists, pause/start/end guards, active
   `policyHash` registration in the ledger, bounded batch counter
   consumption construction, ledger cap enforcement with nonzero
   authorization IDs, stale-policy rejection through a required expected
   policy hash, and Core prepare/complete execution.
3. Dynamic resolver counters, custom gates, callable nullifiers,
   primary-sale settlement routing, existing drop/auction routing, and
   royalty resolver integration remain follow-up slices.

No conformant implementation may drop Core-native ERC-2981 to solve size
pressure. Refactor metadata, collection metadata, entropy, mint policy, or
other non-Core behavior out first.

## Royalty Resolver Contract

Core must not trust a resolver-supplied royalty amount. The resolver returns
receiver and bps; Core computes the amount. The interface and selector are
Permanent:

```solidity
interface IStreamRevenueResolver {
    function royaltyReceiverAndBps(
        address core,
        uint256 tokenId,
        uint256 salePrice,
        uint256 mappedCollectionId,
        bool hasMappedCollection
    )
        external
        view
        returns (address receiver, uint16 royaltyBps);
}

bytes4 constant ROYALTY_RECEIVER_AND_BPS_SELECTOR = 0x54f77a09;
// royaltyReceiverAndBps(address,uint256,uint256,uint256,bool)
```

Core requirements [PV1-2981]:

1. Use an immutable or tightly governed resolver address. The read gas
   cap is the `ROYALTY_RESOLVER_GAS_LIMIT` Governed Gas Parameter with an
   immutable per-parameter floor (ADR 0010 decision D1), never a
   deploy-time immutable; its floors, raise/lower governance, probes, and
   genesis values are owned by
   [`docs/revenue-splits-and-royalties.md`](revenue-splits-and-royalties.md)
   ([RSR-2981-GAS], [RSR-GGP]).
2. Own an immutable `maxRoyaltyBps` cap of 1000 (ADR 0009 decision 7). The
   resolver may enforce the same cap, but Core is the final guard.
3. Perform a `staticcall` forwarding the current
   `ROYALTY_RESOLVER_GAS_LIMIT` value only when parent gas is sufficient
   under EIP-150's 63/64 forwarding rule plus a fixed return/decode
   overhead. If parent gas is insufficient, return `(address(0), 0)`
   without reverting.
4. Use capped assembly returndata handling, copy at most 64 bytes, and
   require `returndatasize() == 64`; undersized or oversized returndata
   returns `(address(0), 0)`.
5. Decode `(address receiver, uint16 royaltyBps)` from the 64-byte result.
6. Return `(address(0), 0)` when the call fails, returns malformed data,
   returns excess data, returns `receiver == address(0)`, returns
   `royaltyBps == 0`, returns `royaltyBps > maxRoyaltyBps`, or otherwise
   fails Core's cheap return-shape checks.
7. Compute `amount = mulDiv(salePrice, royaltyBps, 10_000)` or equivalent
   full-precision checked math in Core for every `uint256 salePrice`.
8. Never call `_requireMinted` from `royaltyInfo()`.
9. Treat fallback-to-zero as a monitorable incident, not as normal healthy
   operation.

The resolver may use Core token identity reads, but Core remains the
authority for token-to-collection mapping and existence.
The resolver must be deployed for exactly one Core and must revert or return
zero if the `core` argument differs from that bound Core. Core cannot prove
that logic from returndata alone; deployment conformance must enforce it
through resolver code-hash approval, static analysis, tests, and by always
passing `address(this)`.
Core intentionally falls back to zero rather than a stale default
receiver/bps because a Core-local fallback would become a second royalty
source of truth. This accepts temporary royalty-disclosure loss during
resolver incidents in exchange for avoiding silent payment to a wrong or
superseded wallet. Deployment readiness must include resolver-health probes
that use the same selector, gas cap, parent-gas precheck, returndata-size
rule, and decode path as `royaltyInfo()`.

Primary-sale deposits and escrow credits must account for the full received
amount. Split-wallet per-recipient floors may leave bounded rounding dust,
but that dust is not emergency surplus and has no ordinary sweep path in
protocol v1. A final dust sweep, if ever wanted, requires its own accepted
decommission spec; none exists in v1.

## Assignment And Freeze State

Revenue and royalty assignment freezes use one canonical state machine.
Freeze semantics are Permanent:

```solidity
enum FreezeState {
    UNFROZEN,
    EXACT_FROZEN,
    INHERITED_FROZEN,
    GLOBAL_FROZEN,
    PERMANENT_FROZEN
}
```

Rules [PV1-FREEZE]:

1. `UNFROZEN` assignments can be set or cleared by authorized policy admins.
2. `EXACT_FROZEN` freezes exactly one assignment key.
3. `INHERITED_FROZEN` freezes a scope and all realized descendants.
4. `GLOBAL_FROZEN` freezes an entire revenue class across default,
   collection, and token scopes; a deployment-wide global freeze also blocks
   creation of new revenue classes (ADR 0009 decision 8).
5. `PERMANENT_FROZEN` cannot be loosened or unfrozen.
6. Freezes are one-way by default, and the single loosening rule for the
   entire spec set is owned by the freeze-model home,
   [`docs/stream-long-term-architecture.md`](stream-long-term-architecture.md)
   [LTA-FREEZE] rule 1 (timelocked loosening only for non-permanent freeze
   states, only where loosening was advertised at assignment time, only
   through the ADR 0004 `DELAYED_LOOSENING` class); this document restates
   nothing beyond that citation (ADR 0010 decision D3.6). The exact-key
   frozen bit is bound into the canonical `assignmentHash` (ADR 0009
   decision 9; home
   [`docs/revenue-splits-and-royalties.md`](revenue-splits-and-royalties.md),
   Assignment Semantics), so freezing a scope changes its resolved policy
   hash and invalidates outstanding `STRICT_MATCH` authorizations signed
   over the pre-freeze hash; loosening and byte-identical re-freeze
   effects on hash-bound payloads follow [LTA-FREEZE] rule 3 — hash
   equality, never freeze-transition history.
7. Token-scope assignments may be created only after Core has written the
   token's collection mapping and authoritative identity. Otherwise the
   resolver must revert with a typed error such as `TokenCollectionUnmapped`.
8. Inherited-freeze descendant counters are keyed only by realized ancestry.
9. If the implementation cannot enumerate lower descendants, inherited
   freeze must either revert when descendant counters are nonzero or use a
   lazy epoch model that blocks later descendant mutation without
   enumeration.

## Domain Constants And Schema Versions

Requirements [PV1-DOMAINS]:

Every domain constant used in hashing is Permanent and must be recorded in
one release artifact or checked spec table before implementation. Each
domain family has exactly one normative home document (ADR 0010 decision
D3.1); the tables in this document are checker-verified mirrors of those
homes, never second homes, and a conflict between a mirror row and its
home is a defect resolved in the home's favor
([`docs/spec-policy.md`](spec-policy.md), Normative Precedence And Single
Sourcing). Every table must include:

| Field | Meaning |
| --- | --- |
| Constant name | Solidity constant name |
| String preimage | Human-readable preimage |
| Hash value | Expected `keccak256` |
| Owner | Contract or module that owns the domain |
| Schema version | Numeric or string schema version |
| Inputs | Ordered `abi.encode` fields |

This table covers profile IDs, template IDs, materialized profile metadata,
sale context if retained, counter keys, counter value keys, policy hashes,
authorization IDs, nullifiers, entropy request keys, entropy seeds, metadata
record hashes, freeze manifests, schema commitments, public interface
selectors, and module capability selectors.
CI must include a checked test that recomputes every listed `keccak256`
preimage and fails on drift between Solidity constants, docs, and release
artifacts.

### StreamMintManager Domain Constants

The CON-014 manager slice records these static phase policy domains in this
checked spec table, which CI verifies row-for-row against
`StreamMintManager.sol`. The normative home of the mint-manager hash
family is [`docs/mint-policy-and-accounting.md`](mint-policy-and-accounting.md)
([MPA-POLICY-HASH], [MPA-OPERATION]); this table mirrors the as-built
constants and must match that home. `operationId` values are derived from
`OPERATION_DOMAIN` through `operationRoot` and then bind
`operationRoot`, `operationNonce`, `tokenIndex`, `tokenDataHash`, and `salt`.
Three input labels below are historical aliases pinned by the CI
checker: `tokenDataHash` and `saltsHash` inside `requestCommitmentHash`,
and the per-token `salt`, name the values the mint spec calls
`tokenDataArrayHash`, `mintCommitmentsHash`, and `mintCommitment`
respectively ([MPA-OPERATION] rule 1). `gateGasLimit` inside
`GATE_CONFIG_DOMAIN` has
exactly one deterministic meaning, pinned in the mint spec ([MPA-GATES]
rule 6): the manager forwards `max(gateGasLimit, MINT_GATE_GAS_LIMIT)` to
the gate, so a value hashed into policy identity commits to real behavior
(ADR 0010 decision D10.3).

| Constant name | String preimage | Hash value | Owner | Schema version | Inputs |
| --- | --- | --- | --- | --- | --- |
| `POLICY_DOMAIN` | `6529STREAM_MINT_MANAGER_POLICY_V1` | `0xc3928662f6dd05b602479c5be22fc277fb478ed810da87911760b8087dee9ddd` | `StreamMintManager` | `1` | `POLICY_DOMAIN; uint256(block.chainid); address(this); address(mintLedger); address(moduleRegistry); SCHEMA_VERSION; collectionId; phaseId; _phaseConfigHash(config); _gateConfigHash(gateConfig); _orderedCounterConfigHash(collectionId, phaseId); _executorSetHash(collectionId, phaseId)` |
| `PHASE_CONFIG_DOMAIN` | `6529STREAM_MINT_MANAGER_PHASE_CONFIG_V1` | `0x1c5e8dc70f273da26541082173dc2bd209ef4595e274f79551a7d9087fb7bef1` | `StreamMintManager` | `1` | `PHASE_CONFIG_DOMAIN; config.paused; config.startTime; config.endTime; config.maxBatchQuantity; config.configHash; config.metadataHash` |
| `COUNTER_CONFIG_DOMAIN` | `6529STREAM_MINT_MANAGER_COUNTER_CONFIG_V1` | `0x3d47766144eb889472dec1a66a3ddf3da1b3025f01a572a61f342c3730bd6577` | `StreamMintManager` | `1` | `COUNTER_CONFIG_DOMAIN; counterId; config.enabled; config.keyMode; config.capMode; config.deltaMode; config.staticCap; config.staticIncrement; config.counterConfigHash` |
| `GATE_CONFIG_DOMAIN` | `6529STREAM_MINT_MANAGER_GATE_CONFIG_V1` | `0x15a68f7139c7b9a8c4ec3f0e85e7e14eb68b03d746241a4f872dc1d6e1e5fdee` | `StreamMintManager` | `1` | `GATE_CONFIG_DOMAIN; gateConfig.gate; gateConfig.gateConfigHash; gateConfig.gateCodehash; gateConfig.gateMetadataHash; gateConfig.gateSemanticVersion; gateConfig.gateGasLimit` |
| `EXECUTOR_SET_DOMAIN` | `6529STREAM_MINT_MANAGER_EXECUTOR_SET_V1` | `0x4dad062b9c5507613f6c9369756e27d94df429cf5650fe9b9d375032d1d5397a` | `StreamMintManager` | `1` | `EXECUTOR_SET_DOMAIN; sorted phase executor addresses` |
| `SUBJECT_DOMAIN` | `6529STREAM_MINT_COUNTER_SUBJECT_V1` | `0x5028c63429e55461bc7922fe859628bd9266f6b029ad3e4124268a4877151a05` | `StreamMintManager` | `1` | `SUBJECT_DOMAIN; uint256(block.chainid); address(mintLedger); keyMode; constant mode: collectionId, phaseId, counterId; address modes: account; context mode: contextHash` |
| `RESOLUTION_DOMAIN` | `6529STREAM_MINT_COUNTER_RESOLUTION_V1` | `0x3503c231385e25d95f9119b4e72118f42b0c7c1e7854b990a249a44c64f6a196` | `StreamMintManager` | `1` | `RESOLUTION_DOMAIN; uint256(block.chainid); address(this); address(mintLedger); collectionId; phaseId; counterId; subjectKey; tokenIndex; counterConfigHash` |
| `OPERATION_DOMAIN` | `6529STREAM_PREPARED_MINT_OPERATION_V1` | `0x7ae97476527ee55636a9869c4580294d9b3d15d19fa357df5e2e41301584d0d9` | `StreamMintManager` | `1` | `OPERATION_DOMAIN; uint256(block.chainid); address(this); address(core); address(mintLedger); collectionId; phaseId; policyHash; authorizationId; requestCommitmentHash(payer, authorizer, initialRecipientsHash, beneficiariesHash, tokenDataHash, saltsHash); contextHash; msg.sender; operationNonce; quantity` |

Reserved derivation constants documented with the rows above:
`COLLECTION_SCOPE_PHASE_ID = 0` (ADR 0009 decision 11) and
`GLOBAL_SCOPE_COLLECTION_ID = 0` (ADR 0010 decision D5.9), both golden
tested; real phases and collections register from 1. Every other domain
family — the extended mint/ledger domains, sales, revenue, artist
authority, metadata, and entropy — is mirrored in the
[Domain-Constants Mirror](#domain-constants-mirror) section below, outside
this checker-scoped table.

## Domain-Constants Mirror

Requirements [PV1-MIRROR]:

The tables below are checker-verified mirrors (ADR 0010 decision D3.1) of
every hash domain and EIP-712 typehash defined by the subsystem homes.
Rules:

1. Each row's normative home is the document and section named in its
   subsection heading and Inputs cell; ordered `abi.encode` field lists
   live only at the home. Mirrors carry the constant name, exact string
   preimage, hash value, owner, and schema version for the CI
   recomputation test, which must fail on drift between Solidity
   constants, the home tables, these mirrors, and release artifacts.
2. Every hash value is computed from the adjacent string preimage and
   pinned; CI recomputes each one and fails on drift. Rows carrying
   `keccak256` values were verified at
   authoring time and are re-verified by the same CI test.
3. Adding a hash domain anywhere in the spec set without a mirror row
   here is a conformance defect; the release-artifact generator builds
   the deployed domain-constants manifest from these mirrors plus the
   checked manager table above.

### Mint Manager And Ledger Extension Mirror Rows

Home: [`docs/mint-policy-and-accounting.md`](mint-policy-and-accounting.md)
([MPA-POLICY-HASH], [MPA-MERKLE], [MPA-TICKET], [MPA-CONTINUITY]).

| Constant name | String preimage | Hash value | Owner | Schema version | Inputs |
| --- | --- | --- | --- | --- | --- |
| `COUNTER_BINDING_DOMAIN` | `6529STREAM_MINT_COUNTER_BINDING_V1` | 0xa65eb27407554a2e0a17dd2a689b804493f9d1cb88054b68066f10134ceb300b | `StreamMintManager` | `1` | mint spec `[MPA-POLICY-HASH]` |
| `ALLOWLIST_LEAF_DOMAIN` | `6529STREAM_MINT_ALLOWLIST_LEAF_V1` | 0x451c28449774ca808fa1b5c7df7e81572f7f4e8b59b1be20222058f75c496159 | `StreamMintManager` | `1` | double-hashed leaf; mint spec `[MPA-MERKLE]` |
| `TICKET_AUTHORIZATION_DOMAIN` | `6529STREAM_MINT_TICKET_AUTHORIZATION_V1` | 0x255ffcce76be6ac89667675f1a7d2fb20ee56b101da7daddc9d13697a1217d97 | `StreamMintTicketGate` | `1` | mint spec `[MPA-TICKET]` |
| `MINT_TICKET_TYPEHASH` | `MintTicket(uint256 chainId,address manager,address ledger,uint256 collectionId,bytes32 phaseId,address executor,address payer,address authorizer,uint8 authorizerKind,bytes32 initialRecipientsHash,bytes32 beneficiariesHash,bytes32 tokenDataArrayHash,bytes32 mintCommitmentsHash,uint256 quantity,bytes32 contextHash,bytes32 policyHash,bytes32 nonce,uint64 deadline)` | 0x8bebeeccaa47d5cdada1485a88dfd7933c17ca5dde68b2d549dcf1bd38e0bfa8 | `StreamMintTicketGate` | `1` | EIP-712 struct fields as listed; mint spec `[MPA-TICKET]` |
| `MINT_TICKET_REVOCATION_TYPEHASH` | `MintTicketRevocation(uint256 chainId,address manager,address ledger,bytes32 authorizationId)` | 0xdbe06065e5132b7c1a8d3c3351245e27c1d3708e694c3e79fcdc491e22f3d7aa | `StreamMintTicketGate` | `1` | EIP-712 struct fields as listed; mint spec `[MPA-TICKET]` |
| `COUNTER_IMPORT_ROOT_DOMAIN` | `6529STREAM_MINT_COUNTER_IMPORT_V1` | 0x6dd9e27258df6de7d90e2f57379fe4a494122e64fa53a60c20c4ba3c8b0115aa | `StreamMintLedger` | `1` | mint spec `[MPA-CONTINUITY]` |
| `COUNTER_IMPORT_LEAF_DOMAIN` | `6529STREAM_MINT_COUNTER_IMPORT_LEAF_V1` | 0x90ddadcf5f0f075c58161de017414ee881fad42cba07129ddde22e8526e76964 | `StreamMintLedger` | `1` | double-hashed leaf; mint spec `[MPA-CONTINUITY]` |
| `NULLIFIER_IMPORT_LEAF_DOMAIN` | `6529STREAM_MINT_NULLIFIER_IMPORT_LEAF_V1` | 0x27d76ee5cfde14d2fcba9ae951193a9e841809b974e387704313fcd83f75f54d | `StreamMintLedger` | `1` | double-hashed leaf; mint spec `[MPA-CONTINUITY]` |

### Sales And Auctions Mirror Rows

Home: [`docs/stream-sales-and-auctions.md`](stream-sales-and-auctions.md)
(Domain Constants And Typehashes). EIP-712 domain:
`("6529Stream Sales", "1", chainId, verifyingContract)` with ERC-5267.

| Constant name | String preimage | Hash value | Owner | Schema version | Inputs |
| --- | --- | --- | --- | --- | --- |
| `STREAM_SALE_V1` | `6529STREAM_SALE_V1` | 0x1167dd961e7616f9b2d1ebaa10110b8970558783a3c1b03e031c28fc3ed185d0 | sale adapters | `1` | sales spec `[SSA-IDENTITY]` |
| `STREAM_AUCTION_V1` | `6529STREAM_AUCTION_V1` | 0x747a8af1003df51f6ec4340fba0c00dcacb2f277d75387d56e4a811b90ffa645 | auction adapters | `1` | sales spec `[SSA-IDENTITY]` |
| `STREAM_DUTCH_SCHEDULE_V1` | `6529STREAM_DUTCH_SCHEDULE_V1` | 0xf22d2e97f1de4a74f3f96b4bd6c3dc8bd6a378980328e92785afa57f0c3957ad | Dutch adapter | `1` | sales spec `[SSA-DUTCH]` |
| `STREAM_BURN_NULLIFIER_V1` | `6529STREAM_BURN_NULLIFIER_V1` | 0x678dd864ff303f21860e7aa38ee53d87e022b7bd7355b933e19d75019bba9d32 | burn gate | `1` | sales spec `[SSA-BURN]` |
| `STREAM_REDEMPTION_V1` | `6529STREAM_REDEMPTION_V1` | 0xe816b2cd9b695f515fad3c02582641b600d22416fe39f7c071eae91eda5d20df | redeem adapter | `1` | sales spec `[SSA-REDEEM]` |
| `STREAM_CONTENT_LEAF_V1` | `6529STREAM_CONTENT_LEAF_V1` | 0xfb3574a94e8672231a1ca6961a82ed077548322500d152474645664cb781b3e3 | content-selection adapters | `1` | double-hashed leaf; sales spec `[SSA-CONTENT]` |
| `STREAM_CONTENT_CONTEXT_V1` | `6529STREAM_CONTENT_CONTEXT_V1` | 0xc8ed10e43ef466bc9a26cbf502bbe6560cc53fc75b5f48650849304775459c68 | content-selection adapters | `1` | sales spec `[SSA-CONTENT]` |
| `STREAM_SEALED_BID_V1` | `6529STREAM_SEALED_BID_V1` | 0x3f5199758c189f6205a065046fe5778bc3e349f7c373fa5c9f419b0718e3e3c6 | sealed-bid extension | `1` | sales spec `[SSA-SEALED]` |
| `SALE_AUTHORIZATION_TYPEHASH` | `SaleAuthorization(uint256 chainId,address saleAdapter,address mintManager,uint256 collectionId,bytes32 phaseId,bytes32 saleId,uint8 saleKind,uint8 revenueClass,bytes32 expectedPrimaryPolicyHash,uint8 primaryPolicyMode,bytes32 initialRecipientsHash,bytes32 beneficiariesHash,address payer,address executor,address asset,uint256 unitPrice,uint256 quantity,bytes32 contentSelectionHash,bytes32 policyHash,bytes32 nonce,uint64 deadline)` | 0x4d5722102337c13f9eba7b02dbdf7f716ab0ff4ef71d1c35a4bc2864461f64bc | sale adapters | `1` | EIP-712 struct fields as listed; sales spec `[SSA-AUTH]` |
| `SALE_OFFER_TYPEHASH` | `SaleOffer(uint256 chainId,address saleAdapter,address core,uint256 collectionId,uint256 tokenId,bytes32 contentSelectionHash,address buyer,address asset,uint256 price,bytes32 nonce,uint64 deadline)` | 0x76d0c5e2d6bb4b74d8cbfcb3cb7228fa182deee45e6053f070eced61b486b8eb | sale adapters | `1` | EIP-712 struct fields as listed; sales spec `[SSA-OFFER]` |

### Revenue Mirror Rows

Home: [`docs/revenue-splits-and-royalties.md`](revenue-splits-and-royalties.md)
([RSR-DOMAINS]). EIP-712 domains:
`("6529StreamSplitWallet", "1", chainId, wallet)` and
`("6529StreamPrimarySaleSettlement", "1", chainId, verifier)` with
ERC-5267.

| Constant name | String preimage | Hash value | Owner | Schema version | Inputs |
| --- | --- | --- | --- | --- | --- |
| `PROFILE_DOMAIN` | `6529STREAM_SPLIT_PROFILE_V1` | 0xb53022be9545b47b00a7734af5a745b97c90c992af3e767f478a185fc8f16819 | `StreamSplitFactory` | `1` | revenue spec `[RSR-DOMAINS]` (Split Profile Model) |
| `PRIMARY_TEMPLATE_DOMAIN` | `6529STREAM_PRIMARY_TEMPLATE_V1` | 0x1ebb9a3ca8927ebbb825122e47537ab869c305e8890801a106585bb8c22b3418 | `StreamRevenueResolver` | `1` | revenue spec `[RSR-DOMAINS]` (Primary Sales) |
| `MATERIALIZED_PRIMARY_PROFILE_METADATA_DOMAIN` | `6529STREAM_MATERIALIZED_PRIMARY_PROFILE_METADATA_V1` | 0x822635189d2b2692303c74e15626423b71b5c9b37ec5edc48509fb84c3deb16c | `StreamRevenueResolver` | `1` | revenue spec `[RSR-DOMAINS]` (Primary Sales) |
| `SETTLEMENT_KEY_DOMAIN` | `6529STREAM_PRIMARY_SETTLEMENT_KEY_V1` | 0x4945dcd8f47145aa24f651df85cfa03bab9d532e51bf130ada9ed9b6426676af | `StreamPrimarySaleSettlement` | `1` | revenue spec `[RSR-DOMAINS]` (Primary Sales) |
| `SALE_CONTEXT_DOMAIN` | `6529STREAM_PRIMARY_SALE_CONTEXT_V1` | 0x0cd71db86a370c54e870584c8b64e50ed454640a3e0a81601d3db439a5c27de4 | `StreamPrimarySaleSettlement` | `1` | revenue spec `[RSR-DOMAINS]` (Primary Sales) |
| `ASSIGNMENT_RESOLVER_CONTEXT_DOMAIN` | `6529STREAM_PRIMARY_ASSIGNMENT_RESOLVER_CONTEXT_V1` | 0xa691283227162c15f9cd2977f1e5995b03b315a3da9086cc469559e3d2e0889b | `StreamRevenueResolver` | `1` | revenue spec `[RSR-DOMAINS]` (Assignment Semantics) |
| `ASSIGNMENT_SCOPE_CONTEXT_DOMAIN` | `6529STREAM_PRIMARY_ASSIGNMENT_SCOPE_CONTEXT_V1` | 0x607a80155d92fe41598bff2f18342fe5510a5d77533ae17b87774f1a511ea1ba | `StreamRevenueResolver` | `1` | revenue spec `[RSR-DOMAINS]` (Assignment Semantics) |
| `ASSIGNMENT_PROFILE_CONTEXT_DOMAIN` | `6529STREAM_PRIMARY_ASSIGNMENT_PROFILE_CONTEXT_V1` | 0xbad938700010817dc9392e428003b03d8d16eaf6b5e0bf35dc03f60ec5eba4a1 | `StreamRevenueResolver` | `1` | revenue spec `[RSR-DOMAINS]` (Assignment Semantics) |
| `ASSIGNMENT_TEMPLATE_CONTEXT_DOMAIN` | `6529STREAM_PRIMARY_ASSIGNMENT_TEMPLATE_CONTEXT_V1` | 0x6f884400dcd82040221802f0143cae9405afe344a8471b8e4be6c57e87af3443 | `StreamRevenueResolver` | `1` | revenue spec `[RSR-DOMAINS]` (Assignment Semantics) |
| `ASSIGNMENT_POINTER_CONTEXT_DOMAIN` | `6529STREAM_PRIMARY_ASSIGNMENT_POINTER_CONTEXT_V1` | 0xc96172afc4e32013f5189d2ac0fb5758ee908ce97051d18f5043370a090a0b97 | `StreamRevenueResolver` | `1` | revenue spec `[RSR-DOMAINS]` (Assignment Semantics) |
| `ROYALTY_ASSIGNMENT_POINTER_CONTEXT_DOMAIN` | `6529STREAM_ROYALTY_ASSIGNMENT_POINTER_CONTEXT_V1` | 0xe02b9a1db06245707414f3be94c4005d9332ede9187a9fe5baacf54853ab4ba0 | `StreamRevenueResolver` | `1` | revenue spec `[RSR-DOMAINS]` (Assignment Semantics; binds `royaltyBps` per [RSR-ROYALTY-HASH]) |
| `ASSIGNMENT_DOMAIN` | `6529STREAM_PRIMARY_ASSIGNMENT_V1` | 0x3d35bd72bf32163018d9b660465fde3bf2bc092b1fb09047dd0621fc6b8d7164 | `StreamRevenueResolver` | `1` | revenue spec `[RSR-DOMAINS]` (Assignment Semantics) |
| `PRIMARY_POLICY_DOMAIN` | `STREAM_PRIMARY_POLICY_V1` | 0x2941bd2c0a4be5ec8f3bd231f745531af7bb0afddad77d202946040b45268480 | `StreamRevenueResolver` | `1` | revenue spec `[RSR-DOMAINS]` (Assignment Semantics) |
| `ROYALTY_POLICY_DOMAIN` | `STREAM_ROYALTY_POLICY_V1` | 0x55e698bf6cd62ba4aab67a2aaad4a6a24be5d65e0582e13502ae30927c32e5a6 | `StreamRevenueResolver` | `1` | revenue spec `[RSR-ROYALTY-HASH]` |
| `ESCROW_RECOVERY_DOMAIN` | `STREAM_ESCROW_RECOVERY_V1` | 0xdd098be4056d58b3ee63a02422ba5f2ad2fb95296e759be20a1af466ab9aced9 | revenue escrow | `1` | revenue spec `[RSR-DOMAINS]` (escrow recovery) |
| `RELEASE_AUTHORIZATION_TYPEHASH` | `StreamReleaseAuthorization(address asset,address account,address recipient,bytes32 nonce,uint64 deadline)` | 0xfc0465fe58ded163aac5c6c38a2171d353d941f9fbc8a1af61e5c309f87f680c | `StreamSplitWallet` | `1` | EIP-712 struct fields as listed; revenue spec `[RSR-RELEASE-AUTH]` |
| `PAYMENT_INTENT_TYPEHASH` | `StreamPaymentIntent(address payer,address asset,uint256 maxAmount,bytes32 saleRef,bytes32 expectedPrimaryPolicyHash,bytes32 nonce,uint64 deadline)` | 0x72c99e6f6f9e2422510a5dd5c2dc2f9ffd83c776670a8de4ffab990e45f825cd | ERC-20 settlement verifier | `1` | EIP-712 struct fields as listed; revenue spec `[RSR-PAYMENT-INTENT]` |
| `GGP_ERC_1271_GAS_LIMIT` | `6529STREAM_GGP_ERC_1271_GAS_LIMIT` | 0xa0c8ff821dc961fbadc34e975a6ca4d3e499b23388ea86883bae7cd5a1d84157 | split factory parameter store | `1` | GGP key; revenue spec `[RSR-GGP]` |
| `GGP_ASSET_POLICY_GAS_LIMIT` | `6529STREAM_GGP_ASSET_POLICY_GAS_LIMIT` | 0xbfc1f824948b8dc9573791fa40eeb403e7322af41d0967f90518dbbb531bf648 | split factory parameter store | `1` | GGP key; revenue spec `[RSR-GGP]` |

### Artist Authority Mirror Rows

Home: [`docs/stream-artist-authority.md`](stream-artist-authority.md)
([AA-DOMAINS]). EIP-712 domain:
`("6529StreamArtistRegistry", "1", chainId, registry)` with ERC-5267.

| Constant name | String preimage | Hash value | Owner | Schema version | Inputs |
| --- | --- | --- | --- | --- | --- |
| `ARTIST_ID_DOMAIN` | `6529STREAM_ARTIST_ID_V1` | 0x17025ea630b7c9d1ea5b6bf0e6375e9190581d7ef45b70c5244b82e48143e3df | `StreamArtistRegistry` | `1` | artist spec `[AA-IDENTITY]` |
| `ARTIST_BINDING_DOMAIN` | `6529STREAM_ARTIST_BINDING_V1` | 0x2ecc91c2aabdb535f25312ccca9a9f7f4ccda08dbaff9fac0423f236562918a0 | `StreamArtistRegistry` | `1` | artist spec `[AA-BINDING]` |
| `COLLABORATOR_SET_DOMAIN` | `6529STREAM_ARTIST_COLLABORATOR_SET_V1` | 0x8e6d305019215c4390d1d804fef71d54d3b43e361f66837f5476ecfaf83c4289 | `StreamArtistRegistry` | `1` | artist spec `[AA-COLLAB]` |
| `SANCTION_SUBJECT_DOMAIN` | `6529STREAM_ARTIST_SANCTION_SUBJECT_V1` | 0x47c9894872096248b3971f1551b555619aea8b63903f526c2da354a7286bb473 | `StreamArtistRegistry` | `1` | artist spec `[AA-SANCTION]` |
| `SANCTION_RECORD_DOMAIN` | `6529STREAM_ARTIST_SANCTION_RECORD_V1` | 0xc41417c9bc70713f2cd138ca6fa362e0868076b835d53f51e6d710a2be40dc6b | `StreamArtistRegistry` | `1` | artist spec `[AA-SANCTION]` |
| `PLATFORM_WORKS_DOMAIN` | `6529STREAM_PLATFORM_WORKS_DECLARATION_V1` | 0x6e2c16c800cfbfb61e5796751c487517f39063218731ac94bdf06929ec6c4441 | `StreamArtistRegistry` | `1` | artist spec `[AA-PLATFORM]` |
| `POLICY_CONSENT_RECORD_DOMAIN` | `6529STREAM_ARTIST_POLICY_CONSENT_RECORD_V1` | 0x2eebbe574cd30197850ff70c0036755a29224da718226068ffc4d1ea2f1f45a6 | `StreamArtistRegistry` | `1` | artist spec `[AA-CONSENT]` |
| `ECONOMICS_CONSENT_RECORD_DOMAIN` | `6529STREAM_ARTIST_ECONOMICS_CONSENT_RECORD_V1` | 0xc8480bd8b314f13ce90d2a190a53f2b0423cd8325d1080113867b79b79ed6fd3 | `StreamArtistRegistry` | `1` | artist spec `[AA-ECON]` |
| `ROYALTY_FREEZE_RECORD_DOMAIN` | `6529STREAM_ARTIST_ROYALTY_FREEZE_RECORD_V1` | 0x4008ba56591f508aff1cc667a65013859ee45bb7abd5506a6176389b97e32b9c | `StreamArtistRegistry` | `1` | artist spec `[AA-ECON]` |
| `DELEGATION_RECORD_DOMAIN` | `6529STREAM_ARTIST_DELEGATION_RECORD_V1` | 0xf6aa4346269e975cd2ca6f06c3e610c53b2e6f6505d0707ed8c3661300151bbb | `StreamArtistRegistry` | `1` | artist spec `[AA-DELEG]` |
| `ATTESTATION_RECORD_DOMAIN` | `6529STREAM_ARTIST_ATTESTATION_RECORD_V1` | 0xa5320c9a6c82fac30567d7843275acca4cb9f68fd5bccff12411115bd197e512 | `StreamArtistRegistry` | `1` | artist spec `[AA-ATTEST]` |
| `DISPUTE_RECORD_DOMAIN` | `6529STREAM_ARTIST_DISPUTE_RECORD_V1` | 0xcd966414757b448743dc1228e0170513508888b6305f277d658bb84f40946c8f | `StreamArtistRegistry` | `1` | artist spec `[AA-DISPUTE]` |
| `SUCCESSION_RECORD_DOMAIN` | `6529STREAM_ARTIST_SUCCESSION_RECORD_V1` | 0xe72b08eca38f3231b67e0fa8daba2f1d5daf1953d4b91f8c8e698d14f0ed2b0a | `StreamArtistRegistry` | `1` | artist spec `[AA-ESTATE]` |
| `DIRECTIVE_RECORD_DOMAIN` | `6529STREAM_ARTIST_ESTATE_DIRECTIVE_RECORD_V1` | 0x993e7562ac3c0f8eddb70e4c49c42ef750a52133056061d419fdbe9ee7236f50 | `StreamArtistRegistry` | `1` | artist spec `[AA-ESTATE]` |
| `RECORD_CHAIN_DOMAIN` | `6529STREAM_ARTIST_RECORD_CHAIN_V1` | 0x2eac9cfc5ca84fbeed56ef1741255e2ec7e45f48bc5c5ceda94397aa23d2f23e | `StreamArtistRegistry` | `1` | artist spec `[AA-RECORDS]` |
| `STREAM_ARTIST_ACCEPTANCE_TYPEHASH` | `StreamArtistAcceptance(address core,uint256 collectionId,uint64 bindingGeneration,bytes32 bindingHash,bytes32 identityRecordHash,uint256 nonce,uint64 deadline)` | 0x863408883ac6994b06f1a735545fd486c6a1a53866fb8851488d56d1b54f92af | `StreamArtistRegistry` | `1` | EIP-712; artist spec `[AA-BINDING]` |
| `STREAM_COLLABORATOR_ACCEPTANCE_TYPEHASH` | `StreamCollaboratorAcceptance(address core,uint256 collectionId,uint64 bindingGeneration,bytes32 bindingHash,address collaborator,bytes32 role,bytes32 shareLabelId,uint256 nonce,uint64 deadline)` | 0x636ddaeeea1f3879203e4707eba02a65484041c3869c8a04560af9a57886343b | `StreamArtistRegistry` | `1` | EIP-712; artist spec `[AA-COLLAB]` |
| `STREAM_ARTIST_SANCTION_TYPEHASH` | `StreamArtistSanction(address core,uint8 scopeType,uint256 collectionId,uint256 tokenId,bytes32 scopeId,bytes32 sanctionSubjectHash,bytes32 statementHash,uint256 nonce,uint64 deadline)` | 0x0651c04c186a25456f0dc9ca0a4a29a5537f2aeb0fe7e69cb2d3d202b41549b3 | `StreamArtistRegistry` | `1` | EIP-712; artist spec `[AA-SANCTION]` |
| `STREAM_ARTIST_POLICY_CONSENT_TYPEHASH` | `StreamArtistPolicyConsent(address core,address mintManager,uint256 collectionId,bytes32 phaseId,bytes32 policyHash,uint256 nonce,uint64 deadline)` | 0xbb408425c14bb658b72c5c6d190446d6d3cce65e6cb127239882bff780982c2b | `StreamArtistRegistry` | `1` | EIP-712; artist spec `[AA-CONSENT]` |
| `STREAM_ARTIST_ECONOMICS_CONSENT_TYPEHASH` | `StreamArtistEconomicsConsent(address core,address resolver,bytes32 revenueClass,uint8 scope,uint256 scopeId,bytes32 assignmentHash,uint256 nonce,uint64 deadline)` | 0x38c2c794170472cc1bbd6385664d7d8a409ce16455caa0db97392b80fbc4b434 | `StreamArtistRegistry` | `1` | EIP-712; artist spec `[AA-ECON]` |
| `STREAM_ARTIST_ROYALTY_FREEZE_TYPEHASH` | `StreamArtistRoyaltyFreeze(address core,address resolver,uint256 collectionId,bytes32 revenueClass,bytes32 expectedAssignmentHash,uint256 nonce,uint64 deadline)` | 0x34f54304a829e6bd32c4bcd8d63f31f7652adf9d1d653b874107a0a93eee73c4 | `StreamArtistRegistry` | `1` | EIP-712; artist spec `[AA-ECON]` |
| `STREAM_ARTIST_DELEGATION_TYPEHASH` | `StreamArtistDelegation(address core,address delegate,uint256 collectionId,uint32 capabilities,uint64 notBefore,uint64 expiresAt,uint64 maxUses,bytes32 constraintsHash,uint256 nonce)` | 0x259b01d4bf9aa04d6f900a2f85548eebdbb07661fdf1eac68031895cadae6d0d | `StreamArtistRegistry` | `1` | EIP-712; artist spec `[AA-DELEG]` |
| `STREAM_ARTIST_ATTESTATION_TYPEHASH` | `StreamArtistAttestation(address core,uint256 collectionId,uint8 subjectKind,bytes32 subjectId,bytes32 subjectStateHash,bytes32 schemaId,bytes32 statementHash,bytes32 statementURIHash,uint256 nonce,uint64 signedAt)` | 0x74b9521f5d5caa162fb97b3a7f8e6aa5352156e3a1ff7c8e8103092eaaeaaa08 | `StreamArtistRegistry` | `1` | EIP-712; artist spec `[AA-ATTEST]` |
| `STREAM_ARTIST_KEY_ROTATION_TYPEHASH` | `StreamArtistKeyRotation(bytes32 artistId,address oldAddress,address newAddress,bytes32 reasonHash,uint256 nonce,uint64 deadline)` | 0x5b4e68760703787cefafa5c70864d397b1de70e70818739680256a123fe7a184 | `StreamArtistRegistry` | `1` | EIP-712; artist spec `[AA-ROTATE]` |
| `STREAM_ARTIST_ROTATION_ACCEPTANCE_TYPEHASH` | `StreamArtistRotationAcceptance(bytes32 artistId,address oldAddress,address newAddress,uint256 nonce,uint64 deadline)` | 0x87eea3b0d5e1275bbdc74e691b4e19a12e9e76b634bac03ae439ae584859ecd0 | `StreamArtistRegistry` | `1` | EIP-712; artist spec `[AA-ROTATE]` |
| `STREAM_ARTIST_SUCCESSOR_DESIGNATION_TYPEHASH` | `StreamArtistSuccessorDesignation(bytes32 artistId,address successor,uint8 successorKind,uint32 grantedCapabilities,bytes32 conditionsHash,bytes32 directiveHash,uint256 nonce,uint64 signedAt)` | 0x978b9dfcca0968239ea043e735357728a9489fe40067fea6673256206c83de15 | `StreamArtistRegistry` | `1` | EIP-712; artist spec `[AA-ESTATE]` |
| `STREAM_ARTIST_ESTATE_DIRECTIVE_TYPEHASH` | `StreamArtistEstateDirective(bytes32 artistId,uint32 grantedCapabilities,uint32 forbiddenCapabilities,bytes32 directivePayloadHash,uint256 nonce,uint64 signedAt)` | 0xa1f146b360069294c6453e91242bb36bb0245545d57b3c89e1cc73c25e953d31 | `StreamArtistRegistry` | `1` | EIP-712; artist spec `[AA-ESTATE]` |
| `STREAM_ARTIST_ATTRIBUTION_DISPUTE_TYPEHASH` | `StreamArtistAttributionDispute(address core,uint256 collectionId,uint64 bindingGeneration,uint8 disputeAction,bytes32 evidenceHash,bytes32 reasonHash,uint256 nonce,uint64 deadline)` | 0x8b535108c442947650eb1dec541e1e10f715f240a1554e488f2d4a51afb31541 | `StreamArtistRegistry` | `1` | EIP-712; artist spec `[AA-DISPUTE]` |
| `STREAM_ARTIST_AUTHORIZATION_REVOCATION_TYPEHASH` | `StreamArtistAuthorizationRevocation(bytes32 artistId,bytes32 revokedDigest,uint256 revokedNonce,uint256 nonce,uint64 deadline)` | 0xd1d93f1d81c2c2b5353543093ebfca89c460de55b540dfed4a019c7ac448f214 | `StreamArtistRegistry` | `1` | EIP-712; artist spec `[AA-REVOKE]` |
| `ARTIST_SANCTION` finality component type | `ARTIST_SANCTION` | 0x1e14b418e60392f62e7baf2e6edfcfb6dfeab92fb4428eff216b492ed5cef047 | finality registry | `1` | component type constant; artist spec `[AA-SANCTION]` |
| `PLATFORM_WORKS_DECLARATION` finality component type | `PLATFORM_WORKS_DECLARATION` | 0x9b732a2be945a9747de080e93cd0a83076acad44dca7585847960ffebdb0d29d | finality registry | `1` | component type constant; artist spec `[AA-PLATFORM]` |
| `STREAM_ARTIST_REGISTRY` module type | `STREAM_ARTIST_REGISTRY` | 0x2a9dd22d7225a4cc60f5a64aa47d28addaea744116b324a22149faadac0b090a | `StreamArtistRegistry` | `1` | module type constant; artist spec `[AA-MODULE]` |
| `artist` beneficiary label | `artist` | 0xf8c87671fe259c56f53406842c278dbf0d49073ecc39fc38bfc052a1b1a125cb | split profiles/templates | `1` | label constant; artist spec `[AA-ECON]`, revenue spec `[RSR-TEMPLATES]` |

### Collection And Preservation Metadata Mirror Rows

Home: [`docs/collection-metadata-contract.md`](collection-metadata-contract.md)
([CMC-SUBJECT-ID], [CMC-CONTENT-ROOT], [CMC-RECORD-CHAIN],
[CMC-OWNER-RECORDS]). EIP-712 domain for owner records:
`("6529StreamOwnerRecords", "1", chainId, ownerRecords)` with ERC-5267.

| Constant name | String preimage | Hash value | Owner | Schema version | Inputs |
| --- | --- | --- | --- | --- | --- |
| `STREAM_SUBJECT_TOKEN_V1` | `6529STREAM_SUBJECT_TOKEN_V1` | `0x1e576f27850d12bc1ec9255ca277dbecfbc84fb3a9a34c474640dfca89811d7e` | metadata satellites | `1` | CM spec `[CMC-SUBJECT-ID]` |
| `STREAM_SUBJECT_MEDIA_V1` | `6529STREAM_SUBJECT_MEDIA_V1` | `0x030f2701e9035fcb711b3acc44ec0bf14b4f4e344e231cdaadce7d14e590994b` | metadata satellites | `1` | CM spec `[CMC-SUBJECT-ID]` |
| `STREAM_SUBJECT_SCOPE_V1` | `6529STREAM_SUBJECT_SCOPE_V1` | `0x748002ff892f4748f1544a8191da460ca6d167aa2e13eeced354e4f66f636394` | metadata satellites | `1` | CM spec `[CMC-SUBJECT-ID]` |
| `STREAM_SUBJECT_COLLECTION_V1` | `6529STREAM_SUBJECT_COLLECTION_V1` | `0x3a882a22dad9915c9193738f63216234155080ed4c4fc9bfae446e90f1df6e16` | metadata satellites | `1` | CM spec `[CMC-SUBJECT-ID]` |
| `STREAM_TOKEN_CONTENT_LEAF_V1` | `6529STREAM_TOKEN_CONTENT_LEAF_V1` | `0x61d75cd1a57d24657b860f99f77c15e5f8556fb725b56a96dd770205f9352b0d` | `StreamCollectionMetadata` | `1` | CM spec `[CMC-CONTENT-ROOT]` |
| `STREAM_TOKEN_CONTENT_NODE_V1` | `6529STREAM_TOKEN_CONTENT_NODE_V1` | `0x7239fc0713b7ccc92b7eef3087150a1f32037aff6ab05f5bf78db4f8ab71a6ea` | `StreamCollectionMetadata` | `1` | CM spec `[CMC-CONTENT-ROOT]` |
| `STREAM_RECORD_CHAIN_V1` | `6529STREAM_RECORD_CHAIN_V1` | `0x0e7a0feb85d4a4a3e90074703c19de35786e11afaae8f9868aa2a911bcfa1609` | record-lane satellites | `1` | CM spec `[CMC-RECORD-CHAIN]` |
| `STREAM_OWNER_RECORD_TYPEHASH` | `StreamOwnerRecord(address owner,uint256 tokenId,bytes32 subjectId,bytes32 recordType,bytes32 schemaId,uint16 algorithmId,bytes digest,bytes32 canonicalizationId,string uri,bytes payload,uint64 effectiveAt,uint256 nonce,uint64 deadline)` | `0x9c8c4f8b7ec1e8731277f53e36271ebf92fc96425f0c082143042400814c6b05` | `StreamOwnerRecords` | `1` | EIP-712; CM spec `[CMC-OWNER-RECORDS]` |

### Entropy Mirror Rows

Homes: [`docs/stream-entropy-coordinator.md`](stream-entropy-coordinator.md)
(Domain Constants) and
[`docs/stream-entropy-providers.md`](stream-entropy-providers.md)
(Raw Randomness Compression).

| Constant name | String preimage | Hash value | Owner | Schema version | Inputs |
| --- | --- | --- | --- | --- | --- |
| `STREAM_ENTROPY_REQUEST_V1` | `6529STREAM_ENTROPY_REQUEST_V1` | 0xf8ea7ebca4196e280c0b42e55e16736c8e836382a8859d151eb826edbecb7106 | `StreamEntropyCoordinator` | `1` | coordinator spec (Request Flow) |
| `STREAM_ENTROPY_SEED_V1` | `6529STREAM_ENTROPY_SEED_V1` | 0x88e816cf6b63abe50b33fdfd5033b9e0f12b8e8ba3925c57c3954ecf8caca69f | `StreamEntropyCoordinator` | `1` | coordinator spec (Fulfillment Flow) |
| `FRESH_RECOVERY_POLICY_DOMAIN` | `6529STREAM_ENTROPY_FRESH_RECOVERY_POLICY_V1` | 0x903ca537e686c7d615b886dbd8d81e240e58123e9918bc89ccabb64f2fe9a327 | `StreamEntropyCoordinator` | `1` | coordinator spec (Storage Model; binds `incidentDeclarerRole`) |
| `STREAM_PROVIDER_RAW_V1` | `6529STREAM_PROVIDER_RAW_V1` | 0x9d25920cde651730cff9eacf736aaa7aa2f6d1f22e948f5d5e362fb181a5bee1 | provider adapters (generic) | `1` | providers spec (Raw Randomness Compression) |
| `STREAM_VRF_RAW_V1` | `6529STREAM_VRF_RAW_V1` | 0x9aec1af5d92901527f48ea05f0779a6d6cd5153a45cb99ffa4383b1b4beea311 | `StreamEntropyProviderVRF` | `1` | providers spec (Raw Randomness Compression) |
| `STREAM_ARRNG_RAW_V1` | `6529STREAM_ARRNG_RAW_V1` | 0xa7c608806995e034e71d26ec44e96245b593a47fe673f8f1d8e33cde02c3bf86 | `StreamEntropyProviderARRNG` | `1` | providers spec (Raw Randomness Compression) |
| `STREAM_PYTH_RAW_V1` | `6529STREAM_PYTH_RAW_V1` | 0x904dfcae5221db62594fb78af05341a66a4e8d649ec151a90cee174eecf6e246 | `StreamEntropyProviderPyth` | `1` | providers spec (Raw Randomness Compression) |
| `STREAM_DRAND_RAW_V1` | `6529STREAM_DRAND_RAW_V1` | 0x81d2ca2a7da654d7cfe760fac3c357e03fc212d4790b5277459b5717b3f46201 | `StreamEntropyProviderDrand` (extension) | `1` | providers spec (Raw Randomness Compression) |
| `STREAM_MULTI_SOURCE_RAW_V1` | `6529STREAM_MULTI_SOURCE_RAW_V1` | 0x94257c55589ad53441c332497f043fbe4820fe5089152303939a0aaba1f8f4f0 | multi-source mixer adapters (extension) | `1` | providers spec (Raw Randomness Compression) |

### Umbrella Architecture Mirror Rows

Home: [`docs/stream-long-term-architecture.md`](stream-long-term-architecture.md)
([LTA-DOMAINS]; ordered inputs pinned by the Artwork Finality Freeze and
State Export And Archival Operations code blocks).

| Constant name | String preimage | Hash value | Owner | Schema version | Inputs |
| --- | --- | --- | --- | --- | --- |
| `STREAM_FINALITY_COMPONENTS_V1` | `6529STREAM_FINALITY_COMPONENTS_V1` | 0xf57efb77611ea13bd3a60968beee86ec330159736aa5d42707a9c0676dbc8898 | finality registry | `1` | domain; sorted `FinalityComponentExpectation[]` (Artwork Finality Freeze) |
| `STREAM_CORE_COLLECTION_FACTS_V1` | `6529STREAM_CORE_COLLECTION_FACTS_V1` | 0x387b66c3b8fdca5febff2a13faa7057fef7f711c4155493c8c8087e48b28c764 | finality registry | `1` | domain; chainid; core; collectionId; `CoreCollectionFinalityFacts` fields (Artwork Finality Freeze) |
| `STREAM_CORE_COLLECTION_CONFIG_EMPTY_V1` | `6529STREAM_CORE_COLLECTION_CONFIG_EMPTY_V1` | 0x6adebabfe6f92286e8678fc5f206cacb6b1a3b912afc80b6039e9240567e7f26 | `StreamCore` | `1` | domain; chainid; core; collectionId (Artwork Finality Freeze) |
| `STREAM_FINALITY_V1` | `6529STREAM_FINALITY_V1` | 0x569714204c899f0d33a0f98879ce85708169a5f1e11f763f2897f64e5d6c8493 | finality registry | `1` | domain; chainid; core; collectionId; coreCollectionFactsHash; componentsHash; manifest uriHash/contentHash/schemaId/canonicalizationHash |
| `STREAM_FINALITY_RECOVERY_V1` | `6529STREAM_FINALITY_RECOVERY_V1` | 0x521e8df5a00a793a5b47409e1e7711b4b8857ba9e6c833fe59a48dfa865b19ac | finality registry | `1` | domain; chainid; finalityRegistry; collectionId; expectedOldFinalityRecordHash; recoveryManifest.contentHash; recoveryRouteHash; executeAfter; artworkBytesChanged; reasonHash |
| `STREAM_SCOPED_FINALITY_V1` | `6529STREAM_SCOPED_FINALITY_V1` | 0x5b56313142e6381659f9d10163ccfa5ea22cb437617c8e69b37c31ecda6f3a50 | finality registry | `1` | domain; chainid; core; scopeType; collectionId; tokenId; scopeId; scopedCoreFactsHash; componentsHash; manifest uriHash/contentHash/schemaId/canonicalizationHash |
| `STREAM_SCOPED_CORE_FINALITY_FACTS_V1` | `6529STREAM_SCOPED_CORE_FINALITY_FACTS_V1` | 0x5c6390c543248a4d63630061d67c3d2245df223d9ac586deccabf40620b43f6e | finality registry | `1` | domain; chainid; core; scope fields; `ScopedCoreFinalityFacts` fields (Scoped Finality For Open Series) |
| `STREAM_SCOPED_FINALITY_RECOVERY_V1` | `6529STREAM_SCOPED_FINALITY_RECOVERY_V1` | 0x7111cd2afae740dbddcd349ab0b8b9269b6a81c331cef7ca8d542e87308bc54a | finality registry | `1` | domain; chainid; finalityRegistry; scope fields; expectedOldFinalityRecordHash; recoveryManifest.contentHash; recoveryRouteHash; executeAfter; artworkBytesChanged; reasonHash |
| `STREAM_EXPORT_TOKEN_COLLECTION_LEAF_V1` | `6529STREAM_EXPORT_TOKEN_COLLECTION_LEAF_V1` | 0x584f047f88b167145486935a02a69e85bf86fdaa6200d84996b4b03124922beb | `STATE_EXPORT_V1` profile | `1` | leaf schema in [LTA-EXPORT] |
| `STREAM_EXPORT_COLLECTION_SERIAL_LEAF_V1` | `6529STREAM_EXPORT_COLLECTION_SERIAL_LEAF_V1` | 0x8868a51be1bdbae4624466a9fa15a9c14b03dd877a0d62e9fca92a2651a8ee2d | `STATE_EXPORT_V1` profile | `1` | leaf schema in [LTA-EXPORT] |
| `STREAM_EXPORT_ENTROPY_LEAF_V1` | `6529STREAM_EXPORT_ENTROPY_LEAF_V1` | 0x0160b86ab41aa57205650b067fbed4e57e8e346b664d01f1a4595213af403c73 | `STATE_EXPORT_V1` profile | `1` | leaf schema in [LTA-EXPORT] |
| `STREAM_EXPORT_FINALITY_LEAF_V1` | `6529STREAM_EXPORT_FINALITY_LEAF_V1` | 0xe1aa59240cbf23c892175f79140c47438ec2db63500bb3c43dc2cddf36ed92c7 | `STATE_EXPORT_V1` profile | `1` | leaf schema in [LTA-EXPORT] |
| `STREAM_EXPORT_SPLIT_PROFILE_LEAF_V1` | `6529STREAM_EXPORT_SPLIT_PROFILE_LEAF_V1` | 0xa105567cd79aeddb669b7f22370bd8e375e8b74c131b5305b8fd5a0e614505e4 | `STATE_EXPORT_V1` profile | `1` | leaf schema in [LTA-EXPORT] |
| `STREAM_EXPORT_SPLIT_ENTRY_LEAF_V1` | `6529STREAM_EXPORT_SPLIT_ENTRY_LEAF_V1` | 0x63ac827ee22adfd396ab63e6c8e4a3bca7e4a645c6141abeb1bd36805095cc42 | `STATE_EXPORT_V1` profile | `1` | leaf schema in [LTA-EXPORT] |
| `STREAM_EXPORT_REVENUE_ASSIGNMENT_LEAF_V1` | `6529STREAM_EXPORT_REVENUE_ASSIGNMENT_LEAF_V1` | 0x063c43d4dce1eebd74b009c22e301aa2d76fdc560665c8bbc24daa19a801a2ad | `STATE_EXPORT_V1` profile | `1` | leaf schema in [LTA-EXPORT] |
| `STREAM_EXPORT_ESCROW_CREDIT_LEAF_V1` | `6529STREAM_EXPORT_ESCROW_CREDIT_LEAF_V1` | 0x943bff9afcadeec1628590d3b88f68d5aea504c1ba5256b4333f3a7dd1db7af2 | `STATE_EXPORT_V1` profile | `1` | leaf schema in [LTA-EXPORT] |
| `STREAM_EXPORT_MINT_COUNTER_LEAF_V1` | `6529STREAM_EXPORT_MINT_COUNTER_LEAF_V1` | 0xda394087539bfc7283e4d78855493bf4c1ef26a24f2074a930b51aff26cf2bf9 | `STATE_EXPORT_V1` profile | `1` | leaf schema in [LTA-EXPORT] |
| `STREAM_EXPORT_AUTHORIZATION_LEAF_V1` | `6529STREAM_EXPORT_AUTHORIZATION_LEAF_V1` | 0x8feca7dbfefa49f93018dd146f49b466753e8d55d2cfe1ddd455b87875411edf | `STATE_EXPORT_V1` profile | `1` | leaf schema in [LTA-EXPORT] |
| `STREAM_EXPORT_REGISTRY_RECORD_LEAF_V1` | `6529STREAM_EXPORT_REGISTRY_RECORD_LEAF_V1` | 0x65511c163de32ba01544ff43eb9f587576c93f3682cf25798d4b19155ad5a338 | `STATE_EXPORT_V1` profile | `1` | leaf schema in [LTA-EXPORT] |
| `STREAM_EXPORT_CATALOG_LEAF_V1` | `6529STREAM_EXPORT_CATALOG_LEAF_V1` | 0xbfc5b9ed3abb2d26d65422468bd303f67c4ad17adc9a4cc71fbaefd97d880d17 | `STATE_EXPORT_V1` profile | `1` | leaf schema in [LTA-EXPORT] |
| `STREAM_EXPORT_RECOVERY_LEAF_V1` | `6529STREAM_EXPORT_RECOVERY_LEAF_V1` | 0xb325dd3c363b686878389fab871ec0303eb41e984e1856d9632cf3ff0b312160 | `STATE_EXPORT_V1` profile | `1` | leaf schema in [LTA-EXPORT] |
| `STREAM_EXPORT_RECORD_CHAIN_LEAF_V1` | `6529STREAM_EXPORT_RECORD_CHAIN_LEAF_V1` | 0xc0ec93115d32e7633c13d7414f7f77c5a20edf8a4c512bfbb1a0b8dbeaa6ace0 | `STATE_EXPORT_V1` profile | `1` | leaf schema in [LTA-EXPORT]; lane values per [CMC-RECORD-CHAIN] |
| `STREAM_EXPORT_ARTWORK_MANIFEST_LEAF_V1` | `6529STREAM_EXPORT_ARTWORK_MANIFEST_LEAF_V1` | 0x75a6b72b058ed053bc42e32ee8ed32283b8f973f455854e870e1c1a3727ea984 | `STATE_EXPORT_V1` profile | `1` | leaf schema in [LTA-EXPORT] |
| `STREAM_EXPORT_LOCK_LEAF_V1` | `6529STREAM_EXPORT_LOCK_LEAF_V1` | 0x2439a59cd6c4a767eefacdb9d4397317f88ac30c996c1c5dae92821f7159536b | `STATE_EXPORT_V1` profile | `1` | leaf schema in [LTA-EXPORT] |
| `GGP_FINALITY_COMPONENT_READ_GAS_ID` | `6529STREAM_GGP_FINALITY_COMPONENT_READ_GAS` | 0xbf54fb4ba4a0942771e26fe4b1f829f8324f6f98ef66e080fd6885b75bdf3221 | finality registry | `1` | `keccak256` of the string preimage; no `abi.encode` inputs ([LTA-GGP]) |

## Event Reconstruction

Requirements [PV1-RECON]:

Every genesis module must have an event-only reconstruction test plan. The
implementation test suite must include at least one harness that rebuilds
the following from emitted events and compares against direct reads:

1. Split profile entries and wallet address.
2. Revenue assignments and freeze state.
3. Escrow credits and flushes.
4. Per-recipient owed and released balances without reading aggregate owed
   counters, proving owed funds cannot be swept as surplus.
5. Mint counter values and authorization/nullifier consumption.
6. Entropy request, fulfillment, stale, failure, and retry state.
7. Collection metadata field values, locks, and schema/view commitments.
8. Metadata refresh events.
9. Token identity: the complete `tokenId -> (collectionId,
   collectionSerial)` mapping from `TokenCollectionRegistered` replay
   alone (ADR 0010 decision D10.1), including prepared-then-completed and
   burned tokens, without reading token IDs' arithmetic shape. The
   token-identity conformance gate covers this harness.
10. Sale, auction, refund, rebate, burn-proof, and redemption state
    ([`docs/stream-sales-and-auctions.md`](stream-sales-and-auctions.md),
    conformance gate 11).
11. Artist identities, bindings, consents, sanctions, delegations,
    successions, disputes, and both artist record-chain accumulators
    ([`docs/stream-artist-authority.md`](stream-artist-authority.md)
    [AA-RECON]).
12. Owner records and every per-lane `recordChainHash` accumulator,
    proving record-stream completeness for any replica
    ([`docs/collection-metadata-contract.md`](collection-metadata-contract.md)
    [CMC-OWNER-RECORDS], [CMC-RECORD-CHAIN]).

State reads remain useful for live tooling, but event replay must be
sufficient for long-lived indexers and archive reconstruction.

## Module Identity Surface

Requirements [PV1-MODULE-ID]:

Every genesis satellite must expose the canonical module identity surface
(ADR 0009 decision 3), defined once in
[`stream-long-term-architecture.md`](stream-long-term-architecture.md)
(Satellite Versioning) and golden-tested by selector:

```solidity
function streamModuleType() external pure returns (bytes32);
function streamModuleVersion() external pure returns (bytes32);
function streamModuleInterfaceId() external pure returns (bytes4);
function streamModuleSchemaHash() external view returns (bytes32);
function streamModuleSupersedes() external view returns (address);
function streamModuleCodeHash() external view returns (bytes32);
function streamModuleDeploymentManifestHash() external view returns (bytes32);
function streamModuleManifest() external view returns (string memory uri, bytes32 hash);
```

This mirrors the existing contract metadata release-hash posture and gives
future indexers a way to discover module families without frontend-specific
knowledge.
`streamModuleSupersedes()` returns the immediate predecessor in the same
module family, not the latest known descendant. Indexers reconstruct longer
successor chains by following the predecessor links and matching module
type/schema hashes.

## Protocol v1 Exclusions

Requirements [PV1-EXCL]:

The following are excluded from protocol v1. Exclusion is intentional
absence, not deferral: the semantics below do not exist in v1. Items
marked "successor line only" are permanently impossible on this Core line
because they would change Permanent Core surfaces — no module spec can
ever add them to this deployment. Every other item can arrive only
through a new accepted module spec against the frozen extension
mechanisms.

1. Transfer-restricting royalty enforcement — successor line only.
   ERC-721 transfer openness is a Permanent Core surface with no transfer
   hook or validator, so enforcement can never be added to this
   deployment by any module (ADR 0010 decision D9.2). Royalty behavior on
   this Core line is disclosure-only — Core-native ERC-2981 plus the
   resolver — and that is a deliberate, permanent, artist-facing term
   stated before binding, not an open roadmap item.
2. Non-transferable, soulbound, or lockable tokens (ERC-5192-class
   locks) — successor line only, precluded by the same transfer-openness
   invariant. Exhibition mementos, attendance artifacts, and artist-proof
   soulbounds must be modeled as separate contracts or as attestation
   records, never as Core token properties.
3. Rental and user-role mechanics (ERC-4907-class) and any other
   transfer-conditioned or transfer-hooked token behavior — successor
   line only, same invariant.
4. General onchain policy VM behavior.
5. Transfer of arbitrary museum, rights, legal, VC/DID, EAS, or
   institution-specific graph logic into `StreamCore`.
6. Multi-source entropy mixers, VDFs, timelock reveal, drand, Randcast,
   Supra, Witnet, or API3 provider implementations.
7. Same-transaction instant entropy fulfillment during mint. The instant
   interface stays frozen; a future reviewed instant provider is
   restricted to collections that declare
   `EntropySecurityClass.LOW_SECURITY` (ADR 0010 decision D8.8; home
   [`docs/stream-entropy-coordinator.md`](stream-entropy-coordinator.md)).
8. Arbitrary sweep authority over split-wallet or escrow owed funds.

Sale-mechanic exclusions (orderbooks, bonding curves, secondary-market
listings, cross-chain execution, ERC-2771 forwarders in sale paths) are
owned by [`docs/stream-sales-and-auctions.md`](stream-sales-and-auctions.md)
(Protocol v1 Exclusions); artist-authority exclusions are owned by
[`docs/stream-artist-authority.md`](stream-artist-authority.md)
([AA-EXCL]).

## Genesis Requirements Outside Core

Requirements [PV1-GENESIS]:

The following are protocol v1 requirements or ratified genesis decisions,
but they must remain outside Core:

1. ERC-20 primary-sale settlement for approved standard assets through a
   payment adapter or primary-sale settlement module, gated by the
   payer-signed `PaymentIntent` boundary
   ([`docs/revenue-splits-and-royalties.md`](revenue-splits-and-royalties.md)
   [RSR-PAYMENT-INTENT]; ADR 0010 decision D8.2). Non-standard ERC-20
   behavior remains unsupported unless a separate adapter spec accepts it.
2. C2PA, IIIF, and PREMIS-style records, richer preservation modules, and
   museum-grade metadata depth through collection metadata, preservation,
   attestation, and view satellites, plus the owner-writable registrar
   records satellite
   ([`docs/collection-metadata-contract.md`](collection-metadata-contract.md)
   [CMC-OWNER-RECORDS]; ADR 0010 decision D6.2).
3. Dual entropy providers (ADR 0009 decision 21): Chainlink VRF primary
   plus one reviewed fallback provider, with ARRNG as the preferred
   candidate and Pyth as the reviewed alternate. A VRF-only deployment is
   not conformant. The checksum-covered `StreamEntropyLaunchDecision`
   manifest records which fallback shipped, its review evidence, and the
   coordinator failure posture.
4. The full scoped-finality surface (ADR 0009 decision 6):
   `StreamArtworkFinalityRegistry` ships with all five scopes —
   `COLLECTION`, `TOKEN`, `RELEASE`, `SEASON`, and `VIEW` — fully
   specified, fully tested, and gate-covered, trading audit surface for
   permanent flexibility by protocol-owner decision.
5. The genesis sale layer (ADR 0010 decision D5): the registry-governed
   fixed-price/open-edition, English auction, Dutch auction, and private
   sale adapters plus the burn-to-mint and delegate-registry gate
   modules, per
   [`docs/stream-sales-and-auctions.md`](stream-sales-and-auctions.md).
6. The artist authority registry (ADR 0010 decision D2): binding,
   consent, sanction, economics-consent, and lifecycle surfaces per
   [`docs/stream-artist-authority.md`](stream-artist-authority.md).
7. Permissionless recipient claim aggregation preserving pull semantics
   (`claimMany`-style periphery; ADR 0010 decision D10.6; home
   [`docs/revenue-splits-and-royalties.md`](revenue-splits-and-royalties.md)
   [RSR-CLAIM-ROUTER]).

The complete deployable inventory, with the exact contract count and the
mandatory/conditional flag for every gate, is the Genesis Deployment
Profile in
[`docs/launch-conformance-matrix.md`](launch-conformance-matrix.md).
