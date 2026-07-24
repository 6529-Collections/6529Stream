# Stream Protocol v1 Specification

Specification status: Draft. This document follows
[`docs/spec-policy.md`](spec-policy.md); the decisions formerly tracked
inline are resolved by
[ADR 0009](adr/0009-protocol-v1-open-question-resolutions.md),
[ADR 0010](adr/0010-world-class-spec-pass.md),
[ADR 0011](adr/0011-world-class-pass-round-2.md),
[ADR 0012](adr/0012-world-class-pass-round-3.md), and
[ADR 0013](adr/0013-world-class-pass-round-4.md),
[ADR 0014](adr/0014-world-class-pass-round-5.md), and
[ADR 0017](adr/0017-raise-only-parameter-governance.md), and are recorded in
[`docs/spec-open-questions.md`](spec-open-questions.md).

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
| Core | ERC-721 ownership and approvals, token identity, collection identity, supply invariants, minimal router/resolver/coordinator hooks, and Core-native ERC-2981; every token is `CORE_NATIVE` under ADR 0016 | None. Core gains no new semantics after deployment; no mutable policy or rendering logic in Core. Changing Core surfaces means a successor Core line |
| Revenue | Immutable split profiles, deterministic split wallets, resolver assignments, native ETH primary settlement, approved-standard ERC-20 primary settlement through outside-Core adapters, passive royalty receipt, and native/approved-asset revenue escrow | New settlement or recovery adapters are new Replaceable modules with their own accepted specs; non-standard ERC-20 behavior stays excluded until a spec accepts it |
| Royalties | Core-native ERC-2981 that calls a resolver for receiver and bps, then computes amount in Core | Resolver implementations rotate behind the frozen resolver interface; marketplace registry overrides remain outside protocol semantics, but launch royalty-resolution coverage is deployment-gated release evidence ([`docs/launch-conformance-matrix.md`](launch-conformance-matrix.md) [LCM-MARKETPLACE]; ADR 0011 decision R12) |
| Minting | `StreamMintManager` policy plus `StreamMintLedger` accounting with many counters, aggregate-only consumption, signed tickets, and module-checked gates/resolvers | New counter resolvers and gates register through the frozen module registry and gate/resolver interfaces |
| Metadata | `StreamMetadataRouter`, `StreamRendererV1`, `StreamCollectionMetadata`, and genesis preservation/attestation/view satellites for identity, rights, media, scripts, dependencies, custom fields, locks, schemas, C2PA, IIIF, PREMIS-style records, preservation, and museum-grade catalogue material | Additional legal, rights, VC/DID, EAS, or institution-specific modules extend the same Permanent manifest and record model |
| Entropy | `StreamEntropyCoordinator`, Chainlink VRF primary provider, one reviewed fallback provider (ARRNG preferred, Pyth as the reviewed alternate), and a mock provider for local validation; VRF-only deployment is not conformant (ADR 0009 decision 21) | New providers are adapters behind the same Permanent provider interface, added through registry approval and provider epochs |
| Sales and auctions | Sale adapter conformance profile, registry-governed genesis adapters (fixed price/open edition with refund-window mode, English auction with anti-snipe, Dutch auction with clearing rebates, private sale/offers), burn-to-mint and delegate gate modules, and signed sale authorizations, per [`docs/stream-sales-and-auctions.md`](stream-sales-and-auctions.md) (ADR 0010 decision D5) | New mechanics are new Replaceable adapters behind the frozen `IStreamSaleAdapter`-family interfaces; sealed-bid and ranked auctions are frozen extension profiles without genesis bytecode |
| Artist authority | Two-sided artist binding, consent modes in the mint path, artist sanction as a finality component, economics consent and royalty freeze rights, and the key rotation/estate/dormancy lifecycle, per [`docs/stream-artist-authority.md`](stream-artist-authority.md) (ADR 0010 decision D2) | Delegation scopes, successor kinds, and arbiter policies extend behind the frozen registry interfaces with their own accepted specs |

Deployment chain posture (ADR 0012 decision T9). Protocol v1 deploys on
Ethereum mainnet — L1, `block.chainid == 1` — and on no other chain.
Every quantified promise in this spec set is sized against L1
settlement: the museum-mode read-survival guarantees, the state-trie
carrier rules and the history-expiry bridge ([LTA-EXPORT],
[LTA-EVENT-HISTORY]), the collector gas ceilings ([MPA-GAS-BUDGET]),
the storage-growth economics, and the pinned marketplace evidence all
assume Ethereum L1 client diversity, state availability, and social
permanence, and every domain preimage binds `block.chainid`. An L2,
sidechain, or alternate-L1 deployment of this Core line is
nonconformant; any future chain move is a successor-line decision
recorded through the successor declaration surface
([`docs/stream-long-term-architecture.md`](stream-long-term-architecture.md)
[LTA-MANIFEST]), never a second deployment of this line. The
conformance matrix fails a deployment ceremony on any other chain.

Collector cost position (ADR 0013 decision U9). L1 settlement prices
every mint, and gas is part of this platform's collector-facing price:
the pinned not-to-exceed ceilings ([MPA-GAS-BUDGET]) are honest all-cold
maxima, several times the per-mint cost of the leanest minimal-mint
platforms, and the spec set publishes that comparison instead of hiding
it. The position is deliberate. This line is sized for 1/1s and small
editions, where L1 permanence dominates per-unit cost; an edition of N
is N sequential ERC-721 serials ([PV1-EXCL] item 11; posture home
[`docs/stream-sales-and-auctions.md`](stream-sales-and-auctions.md)
[SSA-EDITIONS]), so high-volume, low-price edition economics are a
successor-line or L2 posture by construction, never a claim this
deployment makes. The collector gas budget gate
([`docs/launch-conformance-matrix.md`](launch-conformance-matrix.md))
publishes the measured ceilings, the expected all-warm costs most
minters in a drop actually pay, the per-unit editions cost, and the
competitor comparison, so the cost position is stated in numbers rather
than narrative.

Non-normative sizing guidance for edition planning: at the pinned batch
marginal ceiling (`MAX_COLLECTOR_GAS_BATCH_MARGINAL`, [MPA-GAS-BUDGET])
an edition of 100 is roughly 15M gas of marginal minting — about half
of one L1 block — and an edition of 1,000 is roughly 150M gas, several
full blocks, so the envelope this line is sized for ends at 1/1s
through editions in the low hundreds, and thousands-unit timed open
editions are out of economic envelope by construction. The sanctioned
home for beyond-envelope editions is a declared successor or companion
line, never this deployment ([SSA-EDITIONS]; [PV1-EXCL] item 11). That
concession is stated, not hedged: the major volume-edition venues run
that business on L2 or multichain lanes, this Core line never will,
and the volume-collector acquisition funnel is deliberately ceded — a
future cheap-mint lane for the 6529 network arrives only as its own
declared line through the successor declaration surface
([LTA-MANIFEST]), with artist history portable through the registry
import machinery ([AA-IMPORT]).

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
7. Core allocates collection IDs densely and sequentially from one
   counter starting at 1 and exposes a Permanent
   `lastAllocatedCollectionId()` storage read — the collection-space
   high-water mark, equal under dense allocation to the count of
   created collections — so a state-only client bounds the
   collection-ID space and discovers created-but-unminted collections
   without log replay, mirroring the token-ID rules of the enumeration
   posture home ([LTA-ENUMERATION]) (ADR 0013 decision U2). The
   allocator ABI home is the mint spec
   ([`docs/mint-policy-and-accounting.md`](mint-policy-and-accounting.md),
   Core Contract Changes); the conformance-matrix collection-management
   gate carries the golden coverage.

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

1. Validation before effects, scoped per layer and per observability
   (ADR 0012 decision T7). Each layer's executor, payment, signature,
   gate, and mint policy validation must complete before that layer's
   own state-changing effects; no effect of the mint transaction may be
   observable by an untrusted party before every layer's validation has
   completed; and no state-changing effect may survive a later
   validation failure — the transaction is atomic, so a manager,
   ledger, or Core validation failure reverts every earlier effect,
   including the `PRE_REVENUE_SINGLE_STEP` step 3 deposit, which
   [RSR-ORCHESTRATION] deliberately places before manager and ledger
   validation. Cross-layer ordering is governed by invariants 2–7.
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
7. Consent precedes creation (ADR 0013 decision U6). Every mint
   execution calls the artist authority registry's
   `requireMintConsent(collectionId, phaseId, policyHash)` read exactly
   once per mint transaction — a bounded read under the
   `ARTIST_AUTHORITY_GAS_LIMIT` Governed Gas Parameter — and reverts on
   refusal before that transaction's ledger counter, authorization, and
   nullifier consumption (invariant 2) and before any Core token
   allocation, so no token is ever created against a refused, disputed,
   contested, or unset consent state ([AA-CONSENT] requirements 5–6;
   [MPA-CONSENT]). The canonical state-changing sequence in the mint
   spec (Mint Execution Order) places this step explicitly; the
   [RSR-ORCHESTRATION] step lists do not restate it — they bind it
   through [RSR-ORCHESTRATION] rule 2, which subordinates both blessed
   realizations to these invariants wherever their lists are silent
   (ADR 0014 decision V9) — and the conformance-matrix
   artist-authority consent suite enforces it.

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

## Core-Native-Only Launch Rule

Requirements [PV1-FACADE-READINESS], [PV1-IDENTITY-MODE], and
[PV1-TRANSFER-CONTROLLER]:

ADR 0016
([core-native-only ERC-721](adr/0016-core-native-only-erc721.md))
supersedes the launch meanings previously carried by these three legacy
aliases. The aliases remain only so older cross-references resolve; they do
not define a launch ABI or dormant extension surface.

1. The launch Core is `CORE_NATIVE` only. Every allocated token uses the
   same Core ERC-721 ownership, approval, transfer, safe-transfer, mint-event,
   and burn-event semantics for the life of this deployment line.
2. The target Core ABI excludes `collectionIdentityMode(uint256)`,
   `collectionTransferController(uint256)`,
   `declareCollectionIdentityMode(uint256,bytes32)`,
   `registerCollectionTransferController(uint256,address)`, and
   `controlledOwnershipChange(uint256,uint256,address,address,bytes)`.
   No launch storage or mutation path may depend on those selectors.
3. The target Core event surface excludes
   `CollectionIdentityModeDeclared(uint16,uint256,bytes32,bytes32)`,
   `CollectionTransferControllerRegistered(uint16,uint256,address,bytes32)`,
   and
   `ControlledOwnershipChanged(uint16,address,address,uint256,uint256,uint256)`.
   Core emits the standard ERC-721 `Transfer` event for every mint, transfer,
   and burn.
4. A facade or address-per-collection design is successor-line research. It
   requires a new accepted ADR and threat model with an explicitly
   standards-conformant asset model; it cannot reactivate dormant launch-Core
   branches.
5. ADR 0015 decisions W1 and W2 remain in force. W1's Permanent
   collection-identity reads and JSON signal remain launch requirements, and
   W2's marketplace/indexer commitment evidence remains a release go/no-go
   gate. Failure of that gate never activates an alternate ownership path.
6. `totalSupplyOfCollection(uint256)` remains a Permanent Core supply-fact
   read under [PV1-IDENTITY] item 5. It is not facade readiness.

## Core Hook Budget

Requirements [PV1-HOOKS]:

Core-native ERC-2981 is mandatory. Core may stay small only by moving other
logic out.

The checksum-covered
[`stream-core-permanent-interface.json`](../release-artifacts/stream-core-permanent-interface.json)
is the normative complete list of Core Permanent functions and events. Its
closed `bytecode_budget_groups` catalog assigns every active entry to exactly
one implementation-requirement group and rejects phantom groups. This hook
table groups those requirements for implementation review; it cannot add an
ABI entry omitted from the manifest or make a manifest entry optional. Budget
groups carry no additive byte estimates.

The implementation must provide one measured Core hook proof before the
implementation PR is accepted. The proof must be produced by:

```bash
python scripts/build_release_artifacts.py
python scripts/check_contract_size_budget.py
```

The aggregate `forge build --sizes --via-ir --skip test --skip script --force`
output is diagnostic only and cannot replace this isolated canonical
measurement.

The measured Core must include every mandatory hook with final call shapes,
not placeholders that omit calldata, returndata, storage, or external call
paths:

| Hook | Selector owner | Required caller/user |
| --- | --- | --- |
| Complete Permanent Core function/event lock and closed bytecode-budget-group coverage | Release tooling | Implementers, reviewers, and auditors use the machine-readable manifest as the exhaustive surface |
| `royaltyInfo(uint256,uint256)` | Core | Marketplaces and indexers |
| `supportsInterface(bytes4)` with ERC-721, ERC-721 Metadata, ERC-4906, ERC-2981, and mandatory ERC-7572 (`0xe8a3d485`); the ERC-721 Enumerable interface (`0x780e9d63`) is not advertised and its per-transfer index storage does not exist in Core (ADR 0012 decision T10) | Core | Marketplaces and indexers |
| `totalSupply()` and `lastAllocatedTokenId()` storage reads with no enumerable index storage, per the enumeration posture home ([`docs/stream-long-term-architecture.md`](stream-long-term-architecture.md) [LTA-ENUMERATION]); `tokenOfOwnerByIndex`/`tokenByIndex` do not exist on Core, and live reads are served by the periphery enumeration lens (ADR 0012 decision T10) | Core | Marketplaces, indexers, and museum-mode iteration |
| Complete manager-only mint surface: `mintFromManager(uint256,address,bytes,bytes32,bytes32)` (`0xc4e32ca9`), `prepareMintFromManager(uint256,bytes,bytes32,bytes32)` (`0x67c6528b`), `completePreparedMintFromManager(uint256,address,bytes32,bytes32)` (`0xabf5d45f`), incident-only `abortPreparedMintFromManager(uint256,bytes32)` (`0xd9251657`), `preparedMint(uint256)` (`0x06d25065`), `pendingPreparedMintTokenId()` (`0xa767d50e`), and retained opaque-byte read `tokenData(uint256)` (`0xb4b5b48f`), per the exact ABI and same-transaction prepared-mint semantics at [MPA-CORE-ABI]; Core verifies the supplied `tokenDataHash` against the bytes but stores no second per-token hash slot | Core | `StreamMintManager`, renderers, finality, archival tools, and incident monitoring |
| `TokenCollectionRegistered` emission at identity write, carrying `uint16 schemaVersion` (ADR 0010 decision D10.1; ADR 0011 decision R12); the production signature is pinned once at the event home ([`docs/mint-policy-and-accounting.md`](mint-policy-and-accounting.md) [MPA-CORE-ABI]) | Core | Indexers and archive reconstruction |
| token identity reads: collection ID, collection serial, authoritative identity read, burn audit as needed | Core | Resolver, router, indexers |
| `blockCollectionBurns(uint256)` (`0xfcfc7b26`), `collectionBurnsBlocked(uint256)` (`0x5923b379`), and `collectionBurnsBlockedAtBlock(uint256)` (`0x74a5ded9`) with one activation-height storage slot, terminal-freeze governance binding, and no duplicate boolean state, per the production-exact burn-block home ([`docs/collection-metadata-contract.md`](collection-metadata-contract.md) [CMC-BURN]; ADR 0013 decision U4) | Core | Finality registry, artist registry steward minted-before checks, governance, indexers |
| One-way `freezeCollection(uint256)` (`0xbcc405d0`) and derived `collectionFreezeStatus(uint256)` (`0x2ed330f7`), backed by one private activation-height slot with no height getter; terminal-governance class and exact per-call scope/state checks plus schema-v1 `CollectionFrozen(uint16,uint256,bytes32)` action-ID event; executes after the burn block and before registry finality, per [CMC-FREEZE] | Core | Finality registry, satellites, governance, monitoring, indexers |
| Unified Core satellite-pointer ABI: `getSatellitePointer(bytes32)` (`0x3528d53c`), `updateSatellitePointer(bytes32,address)` (`0xac1e5708`), and one-way `freezeSatellitePointer(bytes32)` (`0xcdcdb71e`), with the exact ten-word return including monotonic per-family revision, private cached storage, live-`MODULE_REGISTRY`/executor-context/hash rechecks, old-registry bootstrap for a registry successor, same-target registry revalidation, exact-state no-op rejection, and no individual pointer getters or second staging state machine, per [LTA-POINTERS] | Core | Satellites, governance, `tokenURI()`/`contractURI()`, finality, monitoring, indexers |
| Core-minimal raise-only GGP ABI: four-return `gasParameterInfo(bytes32)` (`0xec2ef90a`) with exactly `(value, floor, failureClass, revision)`; governed `raiseGasParameter(bytes32,uint256)` (`0x5c0df7da`) only; canonical `GasParameterUpdated` with `schemaVersion = 2`; exact V2 scope/state hashes, immutable Governance V2 authority, class `1`, 48-hour minimum delay, an overflow-safe 2x step bound, and same-parameter duplicate-action rejection pinned at [LTA-GGP-CORE]; no action-ID calldata, lower, emergency, probe, rebind, conditional writer, convenience read, public constant getter, or subsystem alias event | Core | Governance, monitoring, bounded Core call paths |
| minimal `tokenURI()` delegation to router | Core | ERC-721 metadata callers |
| minimal `contractURI()` delegation to the contract-metadata satellite (ADR 0009 decision 4) | Core | Marketplaces and indexers (ERC-7572) |
| entropy registration call during mint | Core to coordinator | Mint path |
| Core-originated `emitMetadataUpdate(uint256,bytes32)` (`0xb826aa0c`) and `emitBatchMetadataUpdate(uint256,uint256,bytes32)` (`0x908c18bd`) restricted ERC-4906 helpers, emitting the standard event plus `StreamMetadataRefresh(uint16,bytes32,uint256,uint256)`, with O(1) lifecycle/range checks and `MAX_REFRESH_RANGE = 5_000` (ADR 0009 decision 5; [MRR-REFRESH-EMITTERS]) | Core | Current metadata router and finality registry; the registry's permissionless stored-plan continuation uses exactly one batch call per transaction; the exact nonzero `coordinatorAtMint(tokenId)` additionally for the single-token helper only, never for batch |
| Core-originated `emitContractURIUpdated()` (`0x7f377036`) restricted ERC-7572 helper; no calldata or return value (ADR 0012 decision T9) | Core | Metadata router only |
| `totalSupplyOfCollection(uint256)` per-collection live-supply storage read — minted-ever minus burned and non-reverting — per [PV1-IDENTITY] item 5 | Core | Marketplaces and indexers |
| Complete linked via-IR runtime measurement through the checked production build | Release tooling | Sole authority for EIP-170 headroom; row or group estimates never substitute for the linked measurement |

The system-manifest aggregate is deliberately absent from this Core table.
Protocol v1 deploys the governance executor first with no downstream-derived
constructor inputs, then deploys immutable Permanent `StreamSystemManifest`
bound to this Core and executor. ADR 0004's authority-only one-way bootstrap
bind proves Core's executor through the locked writer's exact staticcall revert
order, verifies the satellite's two immutable binding getters and interface,
records live Core/satellite code hashes and stable content/inventory/trigger
commitments, and enables governance; no action is available before that bind.
The deployment registers module type
`0x47fd79d5a6e9b1d75dcedf141a46e2e8f6d95d5a5be2b88f197fa98a1436fec6`
(`keccak256("STREAM_SYSTEM_MANIFEST")`) with full interface ID `0x37660ede`,
sets Core's `SYSTEM_MANIFEST` pointer to it, and terminal-freezes that family at
genesis. The satellite owns `streamSystemManifest()` (`0x97c93f10`),
the binding reads `core()` (`0xf2f4eb26`) and `governanceExecutor()`
(`0x8fc98386`),
`streamSystemManifestPointer()` (`0x7b3a36b1`),
`streamSystemManifestPointerCount()` (`0x5b1e1cba`),
`streamSystemManifestPointerAt(uint256)` (`0x893aae03`), and
`publishStreamSystemManifest(address,(bytes32,string,bytes32,bytes32,bytes32,bytes32,bytes32,bytes32,bytes32))`
(`0x09b1b5c6`), plus the schema-v1 publication event, bounded
SSTORE2 root-descriptor history over RFC8785-JCS canonical payload chunks,
exact leaf/list/root commitments, at most `32` canonical `24_575`-byte chunks
(`786_400` total bytes), a nonempty `manifestURI` of at most `2_048` UTF-8
bytes, and [GOV-MANIFEST-TAIL] enforcement at [LTA-MANIFEST-PUBLISH]. The
returned `payloadPointer` is the descriptor root. The five-function
`IStreamSystemManifest` interface ID remains `0x37660ede`; the two binding reads
are mandatory outside it, for seven protocol-specific selectors plus
`supportsInterface(bytes4)`—eight external functions total—and no function
assumes a single data blob. Its cached aggregate read is storage-only;
its governed writer derives the post-batch address set from Core's generic
pointer reads. Root/chunk data carriers are excluded from their own payload and
deploy only after every inventoried address and canonical byte is fixed; the
actual root is recorded at atomic seal/publication, never pinned in executor
initcode or the bootstrap bind. ABI lock requires a deterministic non-production
canonical-profile fixture proving canonical bytes, chunk/root mechanics, profile-drift
detection, and decoded/RPC wire-size arithmetic. Measured maximum-size writer
gas/RPC fixtures remain mandatory implementation and deployment gates once the
writer exists; the target fixture is not that evidence. Live semantic equality to the
cached addresses/discovery hashes remains a separate production blocker until
the instance-aware deployment candidate is reconciled under issue #656.

Every `deploymentManifestHash` in that payload and in module/registry/pointer
identity is the same release-wide pre-publication deployment-identity digest
defined at [LTA-DEPLOYMENT-IDENTITY]. It is
`keccak256(abi.encode(STREAM_DEPLOYMENT_IDENTITY_V1,
keccak256(rfc8785JcsUtf8(identityView))))` over the exact address-free symbolic
inventory and zeroed deployment-template view. Actual protocol addresses,
init/runtime hashes, system payload/root/publication facts, and later release,
checksum, signature, address-book, or evidence artifacts are excluded. After
the digest is fixed, deployment resolves constructor/library bindings and
CREATE2 addresses; the system payload then commits those actual facts plus the
stable digest, and later release evidence may reference both only in that
one-way direction. The full deployment/release file's normalized SHA-256 is a
different downstream checksum.

Artwork-finality aggregates are likewise absent from the Permanent Core target.
Genesis instead deploys singleton immutable Permanent
`StreamCoreFinalityAdapter`, module type
`0xc61967911fb81a81bc2ac526bef1f8ca6b1acc696ffc230763d9d36e6e5ccfb4`.
Its four-function interface ID is `0xebf35615`: `core()` (`0xf2f4eb26`),
`collectionMetadata()` (`0x89ed2edf`),
`coreCollectionFinalityFacts(uint256)` (`0x4eb4b6dc`), and
`scopedCoreFinalityFacts((uint8,uint256,uint256,bytes32))` (`0xde5e2530`).
It supports ERC-165, binds Core and collection metadata immutably, and has no
owner, writer, upgrade, selfdestruct, funds, facade, or controller surface. It
composes facts from the granular target-Core ABI, uses `uint256` supply fields
with no `createdAt`, derives burned supply as checked `minted - live`, and reads
`scopeManifest(uint256,bytes32)` (`0x862fdecd`) only for release/season/view
scope manifests; token-scope manifest hash is zero in V1. The finality registry
stores actual Core separately, verifies both adapter bindings, and hashes the
actual Core address. This adapter adds zero selectors and zero bytecode to
Core; the obsolete Core aggregate/facade seam is not a launch compatibility
surface ([LTA-CORE-FINALITY-ADAPTER]).

Artwork-recovery invalidation is also satellite-first and adds zero Core
delta. The finality registry requires a nonzero recovery-manifest content hash,
snapshots Core's existing global token high-water mark when an artwork-changing
route executes, and stores an enumerable-free monotonic refresh plan. A newer
route also replaces any incomplete predecessor plan with a fresh snapshot plan
under its own stored manifest hash, even when the newer recovery says bytes are
unchanged, so invalidation is never stranded. The exact
permissionless continuations are
`continueFinalityRecoveryRefresh(uint256,bytes32)` (`0x617c9142`) and
`continueScopedFinalityRecoveryRefresh((uint8,uint256,uint256,bytes32),bytes32)`
(`0x12ffdb0d`); each advances one stored chunk and calls the existing Core batch
helper exactly once for at most 5,000 global IDs. Collection and
release/season/view changes use `[1, executionSnapshot]` as a safe invalidation
superset, token changes use their one token ID, Core failure rolls progress
back, and post-snapshot mints already use the recovered route. The exact plan
reads, progress events, errors, supersession rule, and golden tests are owned by
[LTA-FINALITY] and conformance golden 17.
The registry exposes the exact active-incomplete count
`incompleteFinalityRecoveryRefreshPlanCount()` (`0xa76ed63d`) and assertion
`assertNoIncompleteFinalityRecoveryRefreshPlans()` (`0x955d14fb`). Because Core
authorizes only the current finality registry, the governance/module transition
validator requires the old registry's zero-count assertion immediately before
the Core finality-pointer update in the same atomic batch. Operators and
permissionless keepers drain active plans before cutover; omission, intervening
calls, generic-path bypass, or a nonzero count fail without changing Core.

Governance V2 removes the legacy caller-supplied `actionId` argument from every
GGP/GTP host, not only Core. GGP hosts use the four-return info read and
two-argument raise selector in [LTA-GGP-CORE]. GTP hosts use four-return
`timeParameterInfo(bytes32)` (`0x5f2463b8`) and
`raiseTimeParameter(bytes32,uint256)` (`0x046e1fd5`). Each host accepts only its
immutable authority, derives the emitted action ID from `currentAction()`, and
validates class `1` plus exact V2 scope/old/new state. No constructor authority
shape or deployment equivalent may omit the published
`IStreamGovernedParameterAuthority` marker-and-context seam required by the
genesis `GOVERNANCE_LAYER` profile. No alternate writer, lower, emergency path,
conditional action, or probe rebind survives cutover.
Canonical gas and time parameter change events use `schemaVersion = 2`.

Rich standalone GGP/GTP hosts fix their inventory and authority at
construction. They do not depend on Core, the module registry, a probe row, or
a runtime registry lookup. A zero authority permanently disables raises
(ADR 0017).

This hook table is the normative home of the Core refresh-emitter caller
set (ADR 0010 decision D3.6). Both restricted ERC-4906 helpers accept the
current metadata router and current artwork finality registry resolved from
Core's cached pointers. The single-token helper additionally accepts exactly
the nonzero `coordinatorAtMint(tokenId)` retained in Core, including a prior
coordinator after pointer replacement; the batch helper does not accept an
entropy coordinator. This token-pinned exception is required so delayed
fulfillment can refresh a token after coordinator replacement. No helper uses a
separately mutable allowlist.
[`docs/metadata-router-and-renderer.md`](metadata-router-and-renderer.md)
([MRR-REFRESH-EMITTERS]) and the entropy coordinator spec cite this set,
and a conformance-matrix golden test pins the exact caller list.
This table is likewise the normative home of the Core
`ContractURIUpdated()` emitter caller set (ADR 0012 decision T9): the
restricted ERC-7572 helper is callable by exactly one satellite — the
current metadata router, resolved through Core's cached
`METADATA_ROUTER` pointer at call time, never through a separately
mutable allowlist. The metadata spec's contract-metadata events section
cites this set instead of restating it, and conformance-matrix golden
test 24 enumerates acceptance and rejection for this helper alongside
the ERC-4906 helpers. Token
data ownership is likewise single-sourced: V1 Core stores the
renderer-visible `tokenData` bytes per the mint ABI home
([MPA-CORE-ABI]). Core verifies the supplied `tokenDataHash` commitment at
mint or prepare time but stores no second per-token hash slot; no other
document may redefine that storage split.

The unified pointer row is likewise production-exact. The three pointer
selectors cover every Core pointer family; protocol v1 adds no
`metadataRouter()`, `collectionMetadata()`, `entropyCoordinator()`, or other
per-family public getter. `streamSystemManifest()` remains the required
aggregate discovery read on the terminal-frozen `SYSTEM_MANIFEST` satellite,
which caches the addresses derived from these generic records; Core does not
implement or proxy that selector. Pointer staging, cancellation, and
role-gated expiring class-3 incident replacement live in the governance layer,
with authorized scheduling required within four hours of
`INCIDENT_REVOKED` and permissionless execution available only after the
normal class-3 delay. Core exposes only the execution update and one-way freeze
entries and independently rechecks the in-flight action, registry, and pointer-
state commitments ([LTA-POINTERS]).

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

Implementation evidence (non-normative). Current artifact-backed
CON-012-lineage Core hook proof:

1. Approved `StreamCore` bytecode-spend baseline: 22,184 bytes.
2. New measured `StreamCore` runtime: 24,152 bytes.
3. EIP-170 margin: 424 bytes.
4. The margin remains above the interim 384-byte development floor but below
   the 512-byte warning threshold and the normative 2,000-byte production
   deployment requirement.
5. The Core hook keeps the immediate manager mint ABI minimal and leaves
   beneficiary/payment evidence, batch commitments, operation events, and
   richer mint policy to the manager, ledger, sale adapter, and settlement
   satellites.
6. This build inherits plain, non-enumerable `ERC721` and contains no
   `ERC721Enumerable` index storage. ADR 0012 decision T10 is already reflected
   and offers no remaining implementation savings.
7. The current build is 1,576 bytes above the 22,576-byte deployment ceiling
   and 3,152 bytes above the 21,000-byte planning allocation. The Core size
   reconciliation workstream in
   [`docs/launch-conformance-matrix.md`](launch-conformance-matrix.md)
   (Genesis Deployment Profile), tracked by
   [issue #654](https://github.com/6529-Collections/6529Stream/issues/654), must
   recover real bytes through compression, actual extraction, or authorized
   relocation while retaining every mandatory hook.

Pre-genesis Core cutover [PV1-CORE-CUTOVER]:

1. This repository has no production Stream deployment whose ABI must be
   preserved in place. The target-Core implementation is therefore an
   intentional pre-genesis MAJOR ABI cutover under ADR 0007 and the release
   policy: callers, deployment inputs, interface artifacts, golden selector
   tests, and the ABI baseline move atomically before a release candidate is
   named. Transitional source compatibility is not a reason to keep legacy
   selectors in the permanent Core.
2. While measured Core is above the 22,576-byte deployment ceiling, no PR may
   land an additive Core-only mandatory hook. A Core-changing PR must be
   satellite-first with zero Core delta, or pair the hook with actual removal
   and produce a net-negative measured Core delta. The final implementation PR
   must compile every mandatory hook in [PV1-HOOKS] together; a partial build
   below the ceiling is not the passing proof.
3. From the current 24,152-byte evidence, the minimum full-stack recovery is
   `1,576 + A` bytes, where `A` is the measured net runtime cost of all
   mandatory Core hooks absent from that evidence after any same-PR removals.
   Scratch deletions and individually measured experiments are non-additive
   under via-IR and never satisfy this equation. Only the final linked runtime
   from the pinned production build does.
4. The implementation order is binding because it prevents a dead caller,
   unsafe receiver-callback ordering, or a temporary Core-size regression:

   | Order | Cutover slice | Required result before the next slice |
   | --- | --- | --- |
   | 1 | Complete ADR 0004 [GOV-V2-CUTOVER] as amended by ADR 0017 before any new Core writer | Executor and interfaces use the seven-word `GovernanceCall` and six-return per-call context; published calldata is SSTORE2-backed and decoded at schedule/execute; active action classes are exactly `0..5`, class ID `6` is retired/forbidden/never-reuse, every GGP/GTP host independently verifies the raise-only class/context, and [GOV-MANIFEST-TAIL] is enforced; executor-first deployment plus the irreversible downstream bind has no CREATE2 fixed point and rejects every action before bind; V1 is rejected/retired; Safe/governor tooling, monitoring, golden/adversarial tests, rehearsal evidence, ABI/event/numeric-ID/domain catalogs, deployment inputs, manifest, and checksums agree |
   | 2 | Deploy and test Permanent `StreamSystemManifest` plus the collection-metadata/router/renderer and entropy-coordinator/provider satellites without changing Core | Satellite ABIs, including system-manifest module type/interface, bounded calls, failure posture, governance, SSTORE2/history/tail behavior, and focused tests are complete; Core delta is zero |
   | 3 | Move `StreamDrops`, auction-start timing/state, and every other live mint caller to the manager/ledger/sale-adapter path | No production caller reaches legacy `StreamMinter` or Core `mint(...)`; the operation-bound prepared settlement seam records all required economics before `_safeMint` |
   | 4 | Replace Core's rich metadata state and rendering with packed collection facts, cached satellite pointers, bounded `tokenURI`, and bounded `contractURI` | Output/fallback golden tests pass and the measured Core delta is net-negative |
   | 5 | Retire the legacy minter pointer, legacy mint selector, Core airdrop/max-purchase accounting, and old collection tuples after step 3 | Manager/ledger/adapters are the only mint-policy and product-accounting owners |
   | 6 | Replace direct randomizer/hash state with the entropy-coordinator pointer, `coordinatorAtMint`, and bounded registration using the final `bytes32 mintCommitment` ABI | Identity and entropy registration settle before `_safeMint`; no provider call can brick mint |
   | 7 | Land the governed collection burn-block writer and guards in a net-negative Core slice | [CMC-BURN] selector, event, terminal-freeze, scope/value hash, veto, replay, height, boolean-equivalence, and controlled-burn tests pass |
   | 8 | Land any remaining Permanent hooks, remove superseded ABI, and refresh release artifacts once against the complete target | Full production size proof is at or below 22,576 bytes and all interface/event/manifest gates agree |

   In particular, the target contains no
   `emergencyRaiseGasParameter(bytes32,uint256)` selector or class-`6`
   eligibility registry. The executor rejects ID `6`, every parameter host
   accepts only class `1`, and the target harness proves missing/non-executing,
   same-value, lower-value, over-2x, stale, wrong-class, and forged-context
   rejection (ADR 0017).

5. Rich legacy Core responsibilities are expressly retirement candidates after
   their prerequisite cutovers: display strings, script/dependency chunks,
   token image/attribute overrides, artist signature/approval state, direct
   randomizer and token-hash state, legacy minter and airdrop accounting,
   `changeTokenData`, metadata-heavy tuple reads, and the option-coded
   `updateContracts` surface. Their replacement owners are respectively the
   metadata/router satellites, artist registry, entropy coordinator/providers,
   manager/ledger/sale adapters, and typed governed pointer interfaces.
6. Permanent Core responsibilities cannot be removed to make the number pass:
   ERC-721 ownership and approvals, global and collection supply facts,
   sequential token/collection high-water marks, retained token identity and
   opaque `tokenData` bytes, prepared-mint replay/sentinel state, collection
   status/freeze/burn-block facts, ERC-2981, thin metadata reads, generic
   satellite-pointer discovery and restricted
   refresh emitters remain in the complete measurement. Medium aggregate
   successor/export/finality views may use only the pre-authorized relocation
   order in the conformance matrix; granular facts remain Core-owned.

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
   deploy-time immutable; its floor, raise-only governance, sizing evidence,
   and genesis value are owned by
   [`docs/revenue-splits-and-royalties.md`](revenue-splits-and-royalties.md)
   ([RSR-2981-GAS], [RSR-GGP]).
2. Own an immutable `maxRoyaltyBps` cap of 1000 (ADR 0009 decision 7). The
   resolver may enforce the same cap, but Core is the final guard.
3. Perform a `staticcall` forwarding the current
   `ROYALTY_RESOLVER_GAS_LIMIT` value only when parent gas is sufficient
   under EIP-150's 63/64 forwarding rule — the multiplicative precheck
   shape pinned at [RSR-2981-GAS].2, reading the live GGP values — plus
   the `ROYALTY_RETURN_GAS_BUFFER` return/decode buffer, which is
   host-coupled to the limit as it raises ([RSR-2981-GAS].6; ADR 0013
   decision U7). If parent gas is insufficient, return `(address(0), 0)`
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
superseded wallet. Deployment readiness must include reproducible
resolver-health rehearsals that use the same selector, gas cap, parent-gas
precheck, returndata-size rule, and decode path as `royaltyInfo()`. Those
measurements are evidence only and have no parameter-mutation authority.

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
| Constant name | Solidity constant name where one exists; for GGP/GTP identifier mirrors, the checked `GGP_`/`GTP_` catalog label derived from the parameter name |
| String preimage | Human-readable preimage |
| Hash value | Expected `keccak256` |
| Owner | Contract or module that owns the domain |
| Schema version | Numeric or string schema version |
| Inputs | Ordered `abi.encode` fields |

This table covers profile IDs, template IDs, materialized profile metadata,
sale context if retained, counter keys, counter value keys, policy hashes,
authorization IDs, nullifiers, entropy request keys, entropy seeds, metadata
record hashes, freeze manifests, schema commitments, governance action and
batch-call domains, Governed Gas Parameter identifiers, public interface
selectors, and module capability selectors (ADR 0011 decision R12).
CI must include checked tests that recompute every listed `keccak256`
preimage and fail on drift between Solidity constants where they exist, docs,
and release artifacts. GGP/GTP identifiers have no row-specific Solidity
constants: their checker instead proves exact generic host prefix derivation
plus the closed-world LTA inventory and mirror rows.

In-struct chainId discipline (ADR 0013 decision U7). This paragraph is
the one cross-cutting rule for domain-material duplication inside signed
payloads; family homes record postures, they do not restate the rule.
Every EIP-712 domain and bare hash domain in this spec set binds
`block.chainid` and the verifying or owning contract, and that domain
binding — never a struct field — is the normative replay boundary.
Duplicating the chain ID (or any other domain material) inside a signed
struct is optional defense-in-depth for payload families whose one
signing shape is consumed across chain-scoped adapter deployments; it is
never a substitute for the domain binding, and a verifier must reject
any payload whose in-struct value differs from the live domain value at
verification time. Each payload family records its posture once at its
home: the mint ticket family ([MPA-TICKET]) and the sale
authorization/offer/custody-grant/revocation families ([SSA-AUTH],
[SSA-OFFER], [SSA-CUSTODY-ENTRY]) are the recorded duplicating families;
every other genesis family — release authorization, payment intent, the
artist-authority payloads, and the owner-record/attestor payloads — is
domain-only. A new payload family must record which posture it takes in
its home section when it is defined; copying a struct shape from a
neighboring family is not a posture record.

### StreamMintManager Domain Constants

The CON-014 manager slice records these static phase policy domains in this
checked spec table, which CI verifies row-for-row against
`StreamMintManager.sol`. The normative home of the mint-manager hash
family is [`docs/mint-policy-and-accounting.md`](mint-policy-and-accounting.md)
([MPA-POLICY-HASH], [MPA-OPERATION]); this table pins the as-built CON-014
constants — the home's labeled non-normative implementation evidence,
including the V1 phase-config row that still hashes `paused` — and must
match that evidence exactly. The deployment-required V2 preimages, which
move pause out of policy identity and add the codehash pin modes
(ADR 0011 decisions R6 and R12), are defined at the home and mirrored in
the extension mirror rows below; the as-built rows here re-pin to the V2
values together with the manager constants and this checker at
implementation time. `operationId` values are derived from
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
   recomputation test, which must fail on drift between Solidity constants
   where they exist, the home tables, these mirrors, and release artifacts.
   Governed-parameter identifier rows are the exception to the per-row
   Solidity-constant expectation: the generic hosts derive IDs from the exact
   checked prefixes and configured names.
2. Every hash value is computed from the adjacent string preimage and
   pinned, and CI recomputes each one, failing on drift between Solidity
   constants where they exist, generic host derivation where applicable, the
   home tables, these mirrors, and release artifacts
   (ADR 0013 decision U9). A newly added domain may carry an unpinned hash
   placeholder — always with its exact string preimage adjacent, at the
   home and in its mirror row alike — only between the ADR that adds the
   domain and the CI recomputation run that pins its value from that
   preimage; an unpinned hash value fails Review-Entry condition 4 of
   [`docs/launch-conformance-matrix.md`](launch-conformance-matrix.md)
   ([LCM-REVIEW-ENTRY]).
3. Adding a hash domain anywhere in the spec set without a mirror row
   here is a conformance defect. Completeness is closed-world across
   every domain family — including the ADR 0004 governance action and
   batch-call domains and every Governed Gas or Time Parameter identifier in
   the [LTA-GGP]/[LTA-GTP] inventories (ADR 0011 decision R12; ADR 0013
   decision U9) — and the
   release-artifact generator builds the deployed domain-constants
   manifest from these mirrors plus the checked manager table above.

### Mint Manager And Ledger Extension Mirror Rows

Home: [`docs/mint-policy-and-accounting.md`](mint-policy-and-accounting.md)
([MPA-POLICY-HASH], [MPA-OPERATION], Recipient Binding, [MPA-MERKLE],
[MPA-TICKET], [MPA-CONTINUITY]). The `*_V2` rows are the
deployment-required preimages of [MPA-POLICY-HASH] (pause-free
phase-config identity and explicit codehash pin modes; ADR 0011 decisions
R6 and R12); the corresponding `*_V1` rows in the checked manager table
above remain as-built CON-014 evidence only.

| Constant name | String preimage | Hash value | Owner | Schema version | Inputs |
| --- | --- | --- | --- | --- | --- |
| `PHASE_CONFIG_DOMAIN_V2` | `6529STREAM_MINT_MANAGER_PHASE_CONFIG_V2` | 0xeed4fdd645ef6b511e1f03d00fb1a56f4978ecb2af721e40599609aab4c988b3 | `StreamMintManager` | `1` | mint spec `[MPA-POLICY-HASH]` (pause-free; ADR 0011 decision R6) |
| `GATE_CONFIG_DOMAIN_V2` | `6529STREAM_MINT_MANAGER_GATE_CONFIG_V2` | 0xf4e6498f6418d2366655c59c7d35ae06469289fe2aed030e292f700ec8f3bcb7 | `StreamMintManager` | `1` | mint spec `[MPA-POLICY-HASH]` (adds `gateCodehashPinMode`; ADR 0011 decision R12) |
| `COUNTER_BINDING_DOMAIN_V2` | `6529STREAM_MINT_COUNTER_BINDING_V2` | 0xd7ec90fda31887c4e19d4b086ce826d3696cead8f764c2ff30b7e270a7984aa4 | `StreamMintManager` | `1` | mint spec `[MPA-POLICY-HASH]` (adds `resolverCodehashPinMode`; ADR 0011 decision R12) |
| `COUNTER_SET_DOMAIN` | `6529STREAM_MINT_MANAGER_COUNTER_SET_V1` | 0x9f547260725c60c0f995ca79086156721bb77e52911472b28d1da7fd2dcc1c39 | `StreamMintManager` | `1` | mint spec `[MPA-POLICY-HASH]` (`orderedCounterConfigHash`; ADR 0011 decision R12) |
| `REQUEST_COMMITMENT_DOMAIN` | `6529STREAM_PREPARED_MINT_REQUEST_COMMITMENT_V1` | 0x789a9a34af13467a6c8515b149f7ee0c2af1291710bba4b4d2cc2e47b58dba92 | `StreamMintManager` | `1` | interior composite; mint spec `[MPA-OPERATION]` (ADR 0011 decision R12) |
| `BATCH_RECIPIENTS_DOMAIN` | `6529STREAM_MINT_BATCH_RECIPIENTS_V1` | 0x4324becaa6aa4425a98ab5655b06dc69742271052ab6945737af6b60d6165d37 | `StreamMintManager` | `1` | interior composite; mint spec Recipient Binding (ADR 0011 decision R12) |
| `BATCH_BENEFICIARIES_DOMAIN` | `6529STREAM_MINT_BATCH_BENEFICIARIES_V1` | 0x0a6973855e884044cad2078ec0474c97f36787e5da302fce966608e212c3a0eb | `StreamMintManager` | `1` | interior composite; mint spec Recipient Binding (ADR 0011 decision R12) |
| `BATCH_TOKEN_DATA_DOMAIN` | `6529STREAM_MINT_BATCH_TOKEN_DATA_V1` | 0x1fe692f6c80a4afdd93c4053f730e1d47a294a2e89853b4abb4decd686e48d36 | `StreamMintManager` | `1` | interior composite; mint spec Recipient Binding (ADR 0011 decision R12) |
| `BATCH_COMMITMENTS_DOMAIN` | `6529STREAM_MINT_BATCH_COMMITMENTS_V1` | 0x80ee07d8d78cb77fa33d888adf252a80cc966ea113512b8000b714df1c4394d2 | `StreamMintManager` | `1` | interior composite; mint spec Recipient Binding (ADR 0011 decision R12) |
| `COUNTER_BINDING_DOMAIN` | `6529STREAM_MINT_COUNTER_BINDING_V1` | 0xa65eb27407554a2e0a17dd2a689b804493f9d1cb88054b68066f10134ceb300b | `StreamMintManager` | `1` | superseded by `COUNTER_BINDING_DOMAIN_V2` for deployment; retained as-built evidence; mint spec `[MPA-POLICY-HASH]` |
| `ALLOWLIST_LEAF_DOMAIN` | `6529STREAM_MINT_ALLOWLIST_LEAF_V1` | 0x451c28449774ca808fa1b5c7df7e81572f7f4e8b59b1be20222058f75c496159 | `StreamMintManager` | `1` | double-hashed leaf; mint spec `[MPA-MERKLE]` |
| `TICKET_AUTHORIZATION_DOMAIN` | `6529STREAM_MINT_TICKET_AUTHORIZATION_V1` | 0x255ffcce76be6ac89667675f1a7d2fb20ee56b101da7daddc9d13697a1217d97 | `StreamMintTicketGate` | `1` | mint spec `[MPA-TICKET]` |
| `MINT_TICKET_TYPEHASH` | `MintTicket(uint256 chainId,address manager,address ledger,uint256 collectionId,bytes32 phaseId,address executor,address payer,address authorizer,uint8 authorizerKind,bytes32 initialRecipientsHash,bytes32 beneficiariesHash,bytes32 tokenDataArrayHash,bytes32 mintCommitmentsHash,uint256 quantity,bytes32 contextHash,bytes32 policyHash,bytes32 nonce,uint64 deadline)` | 0x8bebeeccaa47d5cdada1485a88dfd7933c17ca5dde68b2d549dcf1bd38e0bfa8 | `StreamMintTicketGate` | `1` | EIP-712 struct fields as listed; mint spec `[MPA-TICKET]` |
| `MINT_TICKET_REVOCATION_TYPEHASH` | `MintTicketRevocation(uint256 chainId,address manager,address ledger,bytes32 authorizationId)` | 0xdbe06065e5132b7c1a8d3c3351245e27c1d3708e694c3e79fcdc491e22f3d7aa | `StreamMintTicketGate` | `1` | EIP-712 struct fields as listed; mint spec `[MPA-TICKET]` |
| `COUNTER_IMPORT_ROOT_DOMAIN` | `6529STREAM_MINT_COUNTER_IMPORT_V1` | 0x6dd9e27258df6de7d90e2f57379fe4a494122e64fa53a60c20c4ba3c8b0115aa | `StreamMintLedger` | `1` | mint spec `[MPA-CONTINUITY]` |
| `COUNTER_IMPORT_LEAF_DOMAIN` | `6529STREAM_MINT_COUNTER_IMPORT_LEAF_V1` | 0x90ddadcf5f0f075c58161de017414ee881fad42cba07129ddde22e8526e76964 | `StreamMintLedger` | `1` | double-hashed leaf; mint spec `[MPA-CONTINUITY]` |
| `NULLIFIER_IMPORT_LEAF_DOMAIN` | `6529STREAM_MINT_NULLIFIER_IMPORT_LEAF_V1` | 0x27d76ee5cfde14d2fcba9ae951193a9e841809b974e387704313fcd83f75f54d | `StreamMintLedger` | `1` | double-hashed leaf; mint spec `[MPA-CONTINUITY]` |
| `OPERATION_ID_DOMAIN` | `6529STREAM_PREPARED_MINT_OPERATION_ID_V1` | 0x27132a6bc16b13ba532007a4c4bdd0cd97cb70232de3b1ec8b779ae8358d0c98 | `StreamMintManager` | `1` | per-token interior composite; mint spec `[MPA-OPERATION]` rule 1 (ADR 0012 decision T6) |
| `VALUE_KEY_DOMAIN` | `6529STREAM_MINT_COUNTER_VALUE_KEY_V1` | 0x7d176e04f80e4c60917bbf81304af356dc3c9316698808f36eac4eff01a4e39e | `StreamMintLedger` | `1` | exported counter value-key identity; mint spec `[MPA-COUNTERS]` (ADR 0012 decision T6) |

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
| `STREAM_EXTERNAL_BURN_NULLIFIER_V1` | `6529STREAM_EXTERNAL_BURN_NULLIFIER_V1` | 0x2006bdd49aec002acb0c643da251ae60d42b5d5214a833559fe5d58d90e34f95 | external-burn extension | `1` | sales spec `[SSA-BURN-EXTERNAL]` (ADR 0013 decision U6) |
| `STREAM_REDEMPTION_V1` | `6529STREAM_REDEMPTION_V1` | 0xe816b2cd9b695f515fad3c02582641b600d22416fe39f7c071eae91eda5d20df | redeem adapter | `1` | sales spec `[SSA-REDEEM]` |
| `STREAM_CONTENT_LEAF_V1` | `6529STREAM_CONTENT_LEAF_V1` | 0xfb3574a94e8672231a1ca6961a82ed077548322500d152474645664cb781b3e3 | content-selection adapters | `1` | double-hashed leaf; sales spec `[SSA-CONTENT]` |
| `STREAM_CONTENT_CONTEXT_V1` | `6529STREAM_CONTENT_CONTEXT_V1` | 0xc8ed10e43ef466bc9a26cbf502bbe6560cc53fc75b5f48650849304775459c68 | content-selection adapters | `1` | sales spec `[SSA-CONTENT]` |
| `STREAM_SEALED_BID_V1` | `6529STREAM_SEALED_BID_V1` | 0x3f5199758c189f6205a065046fe5778bc3e349f7c373fa5c9f419b0718e3e3c6 | sealed-bid extension | `1` | sales spec `[SSA-SEALED]` |
| `STREAM_SALE_PURCHASE_V1` | `6529STREAM_SALE_PURCHASE_V1` | 0x47c000df4b149f6f8f2ecb12a836c6fc38b7e5379a3a433ad3d20a83eda821b1 | sale adapters | `1` | sales spec `[SSA-IDENTITY]` (ADR 0011 decision R9) |
| `STREAM_HOLDER_ENTITLEMENT_V1` | `6529STREAM_HOLDER_ENTITLEMENT_V1` | 0x19dbbfcae28a5b8eac83eed3c9053dd7ab7af833cc61cfa94fe866d6a9e256f4 | hold-to-claim extension | `1` | sales spec `[SSA-HOLDER]` (ADR 0011 decision R9) |
| `STREAM_CONTENT_COMMIT_V1` | `6529STREAM_CONTENT_COMMIT_V1` | 0xd88e9c12d31ba2cd7a471bef88ad88216822842af7e38c0aef854486de420941 | content-selection adapters | `1` | sales spec `[SSA-CONTENT]` (ADR 0011 decision R9) |
| `SALE_AUTHORIZATION_TYPEHASH` | `SaleAuthorization(uint256 chainId,address saleAdapter,address mintManager,uint256 collectionId,bytes32 phaseId,bytes32 saleId,uint8 saleKind,bytes32 revenueClass,bytes32 expectedPrimaryPolicyHash,uint8 primaryPolicyMode,bytes32 initialRecipientsHash,bytes32 beneficiariesHash,address payer,address executor,address asset,uint256 unitPrice,uint256 quantity,bytes32 contentSelectionHash,bytes32 policyHash,bytes32 nonce,uint64 deadline,uint64 finalizeBy)` | 0xffd150d67de6a2619775f6cb884eadc8802d3d37fbd584d32ad0ff83ceddb098 | sale adapters | `1` | EIP-712 struct fields as listed; sales spec `[SSA-AUTH]` (`bytes32 revenueClass` and trailing `uint64 finalizeBy`; ADR 0011 decisions R6 and R10; superseded predecessor hashes are recorded only in the home's supersession note) |
| `SALE_OFFER_TYPEHASH` | `SaleOffer(uint256 chainId,address saleAdapter,address core,uint256 collectionId,uint256 tokenId,bytes32 contentSelectionHash,address buyer,address asset,uint256 price,bytes32 nonce,uint64 deadline,uint64 finalizeBy)` | 0x5befc984e6ca9dc13fb8238b12d2d8c7f77bcfbe46489470a66bbdda2b482d1b | sale adapters | `1` | EIP-712 struct fields as listed; sales spec `[SSA-OFFER]` (trailing `uint64 finalizeBy`; ADR 0011 decision R6) |
| `SALE_CUSTODY_GRANT_TYPEHASH` | `SaleCustodyGrant(uint256 chainId,address saleAdapter,address core,uint256 tokenId,address owner,bytes32 saleRef,bytes32 nonce,uint64 deadline)` | 0xb829ff4936e00a75578357cfc3d855c59e780debb698eb3e8c8e9aff1b013041 | sale adapters | `1` | EIP-712 struct fields as listed; sales spec `[SSA-CUSTODY-ENTRY]` (ADR 0012 decision T6) |
| `SALE_OFFER_REVOCATION_TYPEHASH` | `SaleOfferRevocation(uint256 chainId,address saleAdapter,bytes32 offerDigest)` | 0xb80f6e5d7ac663ccfb28bbcfae73c4b3111804ebe80d7ac845e1eb88a44d191c | sale adapters | `1` | EIP-712 struct fields as listed; sales spec `[SSA-OFFER]` rule 5 (ADR 0012 decision T6) |
| `SALE_AUTHORIZATION_REVOCATION_TYPEHASH` | `SaleAuthorizationRevocation(uint256 chainId,address saleAdapter,address authorizer,bytes32 authorizationDigest)` | 0x41d0d127fea4cbca0630f242fe7375e83ff775d8215636ae1fdd92b3d481a455 | sale adapters | `1` | EIP-712 struct fields as listed; sales spec `[SSA-OFFER]` rule 5 (ADR 0012 decision T6; `authorizer` field added by ADR 0013 decision U6 — the authorizer-less predecessor hash is recorded only in the home's supersession note) |
| `SALE_CUSTODY_GRANT_REVOCATION_TYPEHASH` | `SaleCustodyGrantRevocation(uint256 chainId,address saleAdapter,address owner,bytes32 grantDigest)` | 0x56747c6d524c5e2b5568c382f06c2f3c787067868f362f65933656e7a67e8344 | sale adapters | `1` | EIP-712 struct fields as listed; sales spec `[SSA-CUSTODY-ENTRY]` rule 4 (ADR 0014 decision V6) |
| `STREAM_CONTENT_CONSUMED_V1` | `6529STREAM_CONTENT_CONSUMED_V1` | 0x4a1bb00019fd08daa7e378b30312e4fdceb2c209f31effa024f891745f97f84a | content-consumption extension | `1` | sales spec `[SSA-CONTENT-UNIQUE]` (ADR 0012 decision T6) |
| `STREAM_RAFFLE_DRAW_V1` | `6529STREAM_RAFFLE_DRAW_V1` | 0x7bac77537b9b49e1c88e29e0fac9da7b983e54a03de6f7327c4eed66b617622c | raffle extension | `1` | sales spec `[SSA-RAFFLE]` (ADR 0012 decision T6) |

The sales-hosted Governed Gas Parameter identifiers
(`SALE_ERC1271_GAS_LIMIT`, `DELEGATE_REGISTRY_GAS_LIMIT`,
`SALE_ARTIST_AUTHORITY_GAS_LIMIT`, `REVEAL_ATTEMPT_GAS_LIMIT`, and
`SALE_NFT_DELIVERY_GAS_LIMIT`) are mirrored in the consolidated
[GGP identifier table](#governed-gas-parameter-identifier-mirror-rows)
below (ADR 0011 decision R12).

### Revenue Mirror Rows

Home: [`docs/revenue-splits-and-royalties.md`](revenue-splits-and-royalties.md)
([RSR-DOMAINS]). EIP-712 domains:
`("6529StreamSplitWallet", "1", chainId, wallet)`,
`("6529StreamPrimarySaleSettlement", "1", chainId, verifier)`, and
`("6529StreamRevenueEscrow", "1", chainId, escrow)` (ADR 0013 decision
U7) with ERC-5267.

| Constant name | String preimage | Hash value | Owner | Schema version | Inputs |
| --- | --- | --- | --- | --- | --- |
| `PROFILE_DOMAIN` | `6529STREAM_SPLIT_PROFILE_V1` | 0xb53022be9545b47b00a7734af5a745b97c90c992af3e767f478a185fc8f16819 | `StreamSplitFactory` | `1` | revenue spec `[RSR-DOMAINS]` (Split Profile Model) |
| `PRIMARY_TEMPLATE_DOMAIN` | `6529STREAM_PRIMARY_TEMPLATE_V1` | 0x1ebb9a3ca8927ebbb825122e47537ab869c305e8890801a106585bb8c22b3418 | `StreamRevenueResolver` | `1` | revenue spec `[RSR-DOMAINS]` (Primary Sales) |
| `MATERIALIZED_PRIMARY_PROFILE_METADATA_DOMAIN` | `6529STREAM_MATERIALIZED_PRIMARY_PROFILE_METADATA_V1` | 0x822635189d2b2692303c74e15626423b71b5c9b37ec5edc48509fb84c3deb16c | `StreamRevenueResolver` | `1` | revenue spec `[RSR-DOMAINS]` (Primary Sales) |
| `SETTLEMENT_KEY_DOMAIN` | `6529STREAM_PRIMARY_SETTLEMENT_KEY_V1` | 0x4945dcd8f47145aa24f651df85cfa03bab9d532e51bf130ada9ed9b6426676af | `StreamPrimarySaleSettlement` | `1` | revenue spec `[RSR-DOMAINS]` (Primary Sales) |
| `SALE_CONTEXT_DOMAIN` | `6529STREAM_PRIMARY_SALE_CONTEXT_V1` | 0x0cd71db86a370c54e870584c8b64e50ed454640a3e0a81601d3db439a5c27de4 | `StreamPrimarySaleSettlement` | `1` | revenue spec `[RSR-DOMAINS]` (Primary Sales) |
| `SALE_CONTEXT_IDENTITY_DOMAIN` | `6529STREAM_PRIMARY_SALE_CONTEXT_IDENTITY_V1` | 0xff655a4bf4a6f80e629e6b7994c540c884a357bd7b65a4127393355251839a53 | `StreamPrimarySaleSettlement` | `1` | interior composite; revenue spec `[RSR-DOMAINS]` (Primary Sales; ADR 0012 decision T6) |
| `SALE_CONTEXT_PARTIES_DOMAIN` | `6529STREAM_PRIMARY_SALE_CONTEXT_PARTIES_V1` | 0x6a7cdc3c00b80957b7e85d8bd3e0e021e1940978b85f248da33876cab8696629 | `StreamPrimarySaleSettlement` | `1` | interior composite; revenue spec `[RSR-DOMAINS]` (Primary Sales; ADR 0012 decision T6) |
| `SALE_CONTEXT_POLICY_DOMAIN` | `6529STREAM_PRIMARY_SALE_CONTEXT_POLICY_V1` | 0xcb4c73505e4f884f11c829537d12700446d6d2ad309a822b0929fc6ccdf2c795 | `StreamPrimarySaleSettlement` | `1` | interior composite; revenue spec `[RSR-DOMAINS]` (Primary Sales; ADR 0012 decision T6) |
| `ASSIGNMENT_RESOLVER_CONTEXT_DOMAIN` | `6529STREAM_PRIMARY_ASSIGNMENT_RESOLVER_CONTEXT_V1` | 0xa691283227162c15f9cd2977f1e5995b03b315a3da9086cc469559e3d2e0889b | `StreamRevenueResolver` | `1` | revenue spec `[RSR-DOMAINS]` (Assignment Semantics) |
| `ASSIGNMENT_SCOPE_CONTEXT_DOMAIN` | `6529STREAM_PRIMARY_ASSIGNMENT_SCOPE_CONTEXT_V1` | 0x607a80155d92fe41598bff2f18342fe5510a5d77533ae17b87774f1a511ea1ba | `StreamRevenueResolver` | `1` | revenue spec `[RSR-DOMAINS]` (Assignment Semantics) |
| `ASSIGNMENT_PROFILE_CONTEXT_DOMAIN` | `6529STREAM_PRIMARY_ASSIGNMENT_PROFILE_CONTEXT_V1` | 0xbad938700010817dc9392e428003b03d8d16eaf6b5e0bf35dc03f60ec5eba4a1 | `StreamRevenueResolver` | `1` | revenue spec `[RSR-DOMAINS]` (Assignment Semantics) |
| `ASSIGNMENT_TEMPLATE_CONTEXT_DOMAIN` | `6529STREAM_PRIMARY_ASSIGNMENT_TEMPLATE_CONTEXT_V1` | 0x6f884400dcd82040221802f0143cae9405afe344a8471b8e4be6c57e87af3443 | `StreamRevenueResolver` | `1` | revenue spec `[RSR-DOMAINS]` (Assignment Semantics) |
| `ASSIGNMENT_POINTER_CONTEXT_DOMAIN` | `6529STREAM_PRIMARY_ASSIGNMENT_POINTER_CONTEXT_V1` | 0xc96172afc4e32013f5189d2ac0fb5758ee908ce97051d18f5043370a090a0b97 | `StreamRevenueResolver` | `1` | revenue spec `[RSR-DOMAINS]` (Assignment Semantics) |
| `ROYALTY_ASSIGNMENT_POINTER_CONTEXT_DOMAIN` | `6529STREAM_ROYALTY_ASSIGNMENT_POINTER_CONTEXT_V1` | 0xe02b9a1db06245707414f3be94c4005d9332ede9187a9fe5baacf54853ab4ba0 | `StreamRevenueResolver` | `1` | revenue spec `[RSR-DOMAINS]` (Assignment Semantics; binds `royaltyBps` per [RSR-ROYALTY-HASH]) |
| `ASSIGNMENT_DOMAIN` | `6529STREAM_PRIMARY_ASSIGNMENT_V1` | 0x3d35bd72bf32163018d9b660465fde3bf2bc092b1fb09047dd0621fc6b8d7164 | `StreamRevenueResolver` | `1` | revenue spec `[RSR-DOMAINS]` (Assignment Semantics) |
| `PRIMARY_POLICY_DOMAIN` | `6529STREAM_PRIMARY_POLICY_V1` | 0x53c5c8e8dcd97f4f6a66557a6ede68c0798afd999c1cce5807f27d151fb50f12 | `StreamRevenueResolver` | `1` | revenue spec `[RSR-DOMAINS]` (Assignment Semantics; namespaced rename per `[RSR-DOMAINS]` rule 4, ADR 0011 decision R12) |
| `ROYALTY_POLICY_DOMAIN` | `6529STREAM_ROYALTY_POLICY_V1` | 0x672cda40f3f95b129db3b9262cfb581cbe26ea0e95cb09b958ca58ebf62ba54a | `StreamRevenueResolver` | `1` | revenue spec `[RSR-ROYALTY-HASH]` (namespaced rename per `[RSR-DOMAINS]` rule 4, ADR 0011 decision R12) |
| `ESCROW_RECOVERY_DOMAIN` | `6529STREAM_ESCROW_RECOVERY_V1` | 0xd2477116ef00eff9b80dc97ae00c04faec607b7609301cced9041de52f32243c | revenue escrow | `1` | revenue spec `[RSR-DOMAINS]` (escrow recovery; namespaced rename per `[RSR-DOMAINS]` rule 4, ADR 0011 decision R12) |
| `RELEASE_AUTHORIZATION_TYPEHASH` | `StreamReleaseAuthorization(address asset,address account,address recipient,uint256 releasableSnapshot,bytes32 nonce,uint64 deadline)` | 0x6d1a151c75313442dbdc6436c69f78a6976bd8aa729b510f6e538487f3b93109 | `StreamSplitWallet` | `1` | EIP-712 struct fields as listed; revenue spec `[RSR-RELEASE-AUTH]` (`releasableSnapshot` field added by ADR 0014 decision V5 — the snapshot-less predecessor hash is recorded only in the home's supersession note) |
| `RELEASE_AUTHORIZATION_REVOCATION_TYPEHASH` | `StreamReleaseAuthorizationRevocation(address account,bytes32 nonce,uint64 deadline)` | 0xb4240d33db7140e28e850f33c2d22b71ae26cea8a0a8dafdce603a056c81e295 | `StreamSplitWallet` | `1` | EIP-712 struct fields as listed; revenue spec `[RSR-RELEASE-AUTH]` rule 5 (ADR 0014 decision V6) |
| `PAYMENT_INTENT_TYPEHASH` | `StreamPaymentIntent(address payer,address asset,uint256 maxAmount,bytes32 saleRef,bytes32 expectedPrimaryPolicyHash,bytes32 nonce,uint64 deadline)` | 0x72c99e6f6f9e2422510a5dd5c2dc2f9ffd83c776670a8de4ffab990e45f825cd | ERC-20 settlement verifier | `1` | EIP-712 struct fields as listed; revenue spec `[RSR-PAYMENT-INTENT]` |
| `PAYMENT_INTENT_REVOCATION_TYPEHASH` | `StreamPaymentIntentRevocation(address payer,bytes32 nonce,uint64 deadline)` | 0x3a5991afab010b2aa3f78362da982cf536e46d406a9e205c1f27b0f0e4c42e50 | ERC-20 settlement verifier | `1` | EIP-712 struct fields as listed; revenue spec `[RSR-PAYMENT-INTENT]` rule 3 (ADR 0014 decision V6) |
| `ASSIGNMENT_LOOSENING_POLICY_CONTEXT_DOMAIN` | `6529STREAM_PRIMARY_ASSIGNMENT_LOOSENING_POLICY_CONTEXT_V1` | 0x61951eb6d957b0ebe19a5f808b9a9925046a1cd43b22a3a55e012c60b09d7638 | `StreamRevenueResolver` | `1` | revenue spec `[RSR-DOMAINS]` (Assignment Semantics; `assignmentPolicyHash` branch derivation; ADR 0012 decision T7) |
| `ESCROW_RECOVERY_CONSENT_TYPEHASH` | `StreamEscrowRecoveryConsent(address account,bytes32 recoveryId,bytes32 nonce,uint64 deadline)` | 0xff4cafe3ce3dbf31056d40511f4344d6c8070efc8f6eaf284d2c5366514ede2e | revenue escrow | `1` | EIP-712 struct fields as listed; revenue spec `[RSR-ESCROW-RECOVERY]` rule 6 (ADR 0013 decision U7) |

The revenue-hosted Governed Gas Parameter identifiers
(`ERC_1271_GAS_LIMIT`, `ASSET_POLICY_GAS_LIMIT`, and their siblings) are
mirrored in the consolidated
[GGP identifier table](#governed-gas-parameter-identifier-mirror-rows)
below (ADR 0011 decision R12).

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
| `CAPABILITY_POLICY_SET_DOMAIN` | `6529STREAM_ARTIST_CAPABILITY_POLICY_SET_V1` | 0x87c9af42ac310f72fd69d92f1c290288dcf159f63ed2a1fc75c7e66cc55704d0 | `StreamArtistRegistry` | `1` | artist spec `[AA-COLLAB]` (ADR 0011 decision R7.8) |
| `ACCEPTANCE_RECORD_DOMAIN` | `6529STREAM_ARTIST_ACCEPTANCE_RECORD_V1` | 0x4b6ab2e018b05a2ca441cf6b0bc3e12a4674b70fd785051a0536faf074f995b4 | `StreamArtistRegistry` | `1` | artist spec `[AA-BINDING]`, `[AA-RECORDS]` |
| `GUARDIAN_SET_RECORD_DOMAIN` | `6529STREAM_ARTIST_GUARDIAN_SET_RECORD_V1` | 0xfb979fce9edd361cf23ba8baee900f7054451db7b563ba0ab11a5ef3621cd297 | `StreamArtistRegistry` | `1` | artist spec `[AA-GUARD]` (ADR 0011 decision R7.1) |
| `ROTATION_RECORD_DOMAIN` | `6529STREAM_ARTIST_ROTATION_RECORD_V1` | 0x8d7c32ae357c27253fd4480fe9d411cefc64a5634952ed8c8ebe7dcf63257ea5 | `StreamArtistRegistry` | `1` | artist spec `[AA-ROTATE]` (ADR 0011 decision R7.1) |
| `IDENTITY_CONTEST_RECORD_DOMAIN` | `6529STREAM_ARTIST_IDENTITY_CONTEST_RECORD_V1` | 0x26a4221cd1625ab88b1ac279e1708a73efa176e486242b26832cdc94fe25e6bb | `StreamArtistRegistry` | `1` | artist spec `[AA-GUARD]` (ADR 0011 decision R7.1) |
| `IDENTITY_RECOVERY_RECORD_DOMAIN` | `6529STREAM_ARTIST_IDENTITY_RECOVERY_RECORD_V1` | 0x459749364fd07c3a8f1998b82d893d33ef0942c30d94666b42dac1e37ba5feff | `StreamArtistRegistry` | `1` | artist spec `[AA-GUARD]` (ADR 0011 decision R7.1) |
| `IDENTITY_RECOVERY_SUPERSESSION_DOMAIN` | `6529STREAM_ARTIST_IDENTITY_RECOVERY_SUPERSESSION_V1` | 0x0c8573762967a1af597f2a7afc4b655a87b3e22d2b11fbab6cf13c6f7b1396ae | `StreamArtistRegistry` | `1` | artist spec `[AA-GUARD]` (ADR 0011 decision R7.1) |
| `CONTENT_CONSENT_RECORD_DOMAIN` | `6529STREAM_ARTIST_CONTENT_CONSENT_RECORD_V1` | 0x85ea98da8f1f57787fd3dc784129c3f4f4d4ac889735761822ba32cec9de0bee | `StreamArtistRegistry` | `1` | artist spec `[AA-CONTENT]` (ADR 0011 decision R7.2) |
| `CONTENT_FREEZE_RECORD_DOMAIN` | `6529STREAM_ARTIST_CONTENT_FREEZE_RECORD_V1` | 0xdd3e1d6b06c6a49f0da1f66064526a5535238b6a1c258233a419aed42a968354 | `StreamArtistRegistry` | `1` | artist spec `[AA-CONTENT]` (ADR 0011 decision R7.2) |
| `RECOVERY_APPROVAL_RECORD_DOMAIN` | `6529STREAM_ARTIST_RECOVERY_APPROVAL_RECORD_V1` | 0xe60e6ec1d140fa0166261169322ac5c58d77797094a2b68866f812d1172e89b9 | `StreamArtistRegistry` | `1` | artist spec `[AA-RECOVERY]` (ADR 0011 decision R7.3) |
| `UNAVAILABILITY_FINDING_RECORD_DOMAIN` | `6529STREAM_ARTIST_UNAVAILABILITY_FINDING_RECORD_V1` | 0xc087b73d3ef4933341423d2630b88eca87257e38716a129b316ebc148a7fa1f5 | `StreamArtistRegistry` | `1` | artist spec `[AA-RECOVERY]` (ADR 0011 decision R7.3) |
| `ESTATE_ACTIVATION_RECORD_DOMAIN` | `6529STREAM_ARTIST_ESTATE_ACTIVATION_RECORD_V1` | 0x2bd396eef0a5daaf54fe3c6b7a3888c3d7f7a237c3c4eb69f2848677ee96302f | `StreamArtistRegistry` | `1` | artist spec `[AA-ESTATE]` (ADR 0011 decision R7.4) |
| `PLATFORM_WORKS_CLAIM_RECORD_DOMAIN` | `6529STREAM_PLATFORM_WORKS_CLAIM_RECORD_V1` | 0x4b566ba07bf420b345ba4618b1dd0721da12c22766a8024791d4d651a170b0e6 | `StreamArtistRegistry` | `1` | artist spec `[AA-PLATFORM]` (ADR 0011 decision R7.5) |
| `AUTH_REVOCATION_RECORD_DOMAIN` | `6529STREAM_ARTIST_AUTH_REVOCATION_RECORD_V1` | 0x52beeaf4afc420319e9e3d55d092b732ea0ad2a3407f22b60918c0acb7c7d1e5 | `StreamArtistRegistry` | `1` | artist spec `[AA-REVOKE]` |
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
| `STREAM_ARTIST_GUARDIAN_SET_TYPEHASH` | `StreamArtistGuardianSet(bytes32 artistId,address[] guardians,uint32 approvalThreshold,uint64 minContestSeconds,uint256 nonce,uint64 signedAt)` | 0x397aa6a887bb93367eab618ebf56732031f29da75f932c71ea556746542ebafe | `StreamArtistRegistry` | `1` | EIP-712; artist spec `[AA-GUARD]` (ADR 0011 decision R7.1; `minContestSeconds` field added by ADR 0013 decision U4) |
| `STREAM_ARTIST_CONTENT_CONSENT_TYPEHASH` | `StreamArtistContentConsent(address core,address metadataContract,uint256 collectionId,bytes32 familyId,bytes32 newStateHash,uint256 nonce,uint64 deadline)` | 0x7908964dc70554ffd5c82353690255d1a8c338be77ffc0f8fb925a27d890587d | `StreamArtistRegistry` | `1` | EIP-712; artist spec `[AA-CONTENT]` (ADR 0011 decision R7.2) |
| `STREAM_ARTIST_CONTENT_FREEZE_TYPEHASH` | `StreamArtistContentFreeze(address core,address metadataContract,uint256 collectionId,bytes32[] lockClasses,bytes32 expectedStateHash,uint256 nonce,uint64 deadline)` | 0xfcb15d96b29996a5852bf06058ae82a7e8acaf7d7601b13fe881ada5d30fc63b | `StreamArtistRegistry` | `1` | EIP-712; artist spec `[AA-CONTENT]` (ADR 0011 decision R7.2) |
| `STREAM_ARTIST_RECOVERY_APPROVAL_TYPEHASH` | `StreamArtistRecoveryApproval(address core,address finalityRegistry,uint256 collectionId,bytes32 finalityRecordHash,bytes32 recoveryManifestHash,uint256 nonce,uint64 deadline)` | 0x242bffdf15416a6743c57bd362683aa2933edcd42a4ef176f4e983a745eee511 | `StreamArtistRegistry` | `1` | EIP-712; artist spec `[AA-RECOVERY]` (ADR 0011 decision R7.3) |
| `STREAM_ARTIST_ESTATE_ACTIVATION_TYPEHASH` | `StreamArtistEstateActivation(bytes32 artistId,address successor,bytes32 evidenceHash,uint256 nonce,uint64 deadline)` | 0x35ad5d0278eb067119334d7d4fddd596cad723598851900a95e6ad9a94e51a8a | `StreamArtistRegistry` | `1` | EIP-712; artist spec `[AA-ESTATE]` (ADR 0011 decision R7.4) |
| `ARTIST_SANCTION` finality component type | `ARTIST_SANCTION` | 0x1e14b418e60392f62e7baf2e6edfcfb6dfeab92fb4428eff216b492ed5cef047 | finality registry | `1` | component type constant; artist spec `[AA-SANCTION]` |
| `PLATFORM_WORKS_DECLARATION` finality component type | `PLATFORM_WORKS_DECLARATION` | 0x9b732a2be945a9747de080e93cd0a83076acad44dca7585847960ffebdb0d29d | finality registry | `1` | component type constant; artist spec `[AA-PLATFORM]` |
| `STREAM_ARTIST_REGISTRY` module type | `STREAM_ARTIST_REGISTRY` | 0x2a9dd22d7225a4cc60f5a64aa47d28addaea744116b324a22149faadac0b090a | `StreamArtistRegistry` | `1` | module type constant; artist spec `[AA-MODULE]` |
| `artist` beneficiary label | `artist` | 0xf8c87671fe259c56f53406842c278dbf0d49073ecc39fc38bfc052a1b1a125cb | split profiles/templates | `1` | label constant; artist spec `[AA-ECON]`, revenue spec `[RSR-TEMPLATES]` |
| sanction ceremony schema ID | `6529STREAM_ARTIST_SANCTION_CEREMONY_V1` | 0xa7222b7835606e613ba5eee0ebc23654b567e946e997bb27e127e24ed9534c44 | `StreamArtistRegistry` | `1` | pinned schema identifier; artist spec `[AA-SANCTION]` requirement 9 (ADR 0011 decision R7.7) |
| C2PA credentials schema ID | `6529STREAM_ARTIST_C2PA_CREDENTIALS_V1` | 0x89276c3535c7321ce7f36b8228b64a1b1b9667d531786d9d68df290f9bd0768a | `StreamArtistRegistry` | `1` | pinned schema identifier; artist spec `[AA-C2PA]` (ADR 0011 decision R7.9) |
| `IDENTITY_REVISION_RECORD_DOMAIN` | `6529STREAM_ARTIST_IDENTITY_REVISION_RECORD_V1` | 0x1b7518e9d16da358d15957ec43218eb0b017fbd017e60c75b3126110006034a4 | `StreamArtistRegistry` | `1` | artist spec `[AA-IDENTITY]` (ADR 0012 decision T4) |
| `SALE_CONSENT_RECORD_DOMAIN` | `6529STREAM_ARTIST_SALE_CONSENT_RECORD_V1` | 0xf30702786801bdda286e4555272eb70024e76bd156af98fab2513886e5bdcfd1 | `StreamArtistRegistry` | `1` | artist spec `[AA-SALE-CONSENT]` (ADR 0012 decision T4) |
| `DEPLOYMENT_FACTS_DOMAIN` | `6529STREAM_ARTIST_DEPLOYMENT_FACTS_V1` | 0x4ee364f5ea4a8329db8f1dd8aa0877f59a6c2c9878f7239266911d7b56dd3bd7 | `StreamArtistRegistry` | `1` | artist spec `[AA-DEPLOY]` (ADR 0012 decision T9) |
| `ARTIST_HISTORY_IMPORT_LEAF_DOMAIN` | `6529STREAM_ARTIST_HISTORY_IMPORT_LEAF_V1` | 0xea04da6644046a7c731e99312c32df311e81aa7e137dfc2a49c2116bb325195d | `StreamArtistRegistry` | `1` | double-hashed leaf; artist spec `[AA-IMPORT]` (ADR 0012 decision T4) |
| `STREAM_ARTIST_IDENTITY_REVISION_TYPEHASH` | `StreamArtistIdentityRevision(bytes32 artistId,bytes32 previousRecordHash,bytes32 revisedRecordHash,uint256 nonce,uint64 signedAt)` | 0xbfb7a5d3bc248c8eefbe4f8dfc2ea7d75d18c5cb3f2ab0d56000fd87f4b58603 | `StreamArtistRegistry` | `1` | EIP-712; artist spec `[AA-IDENTITY]` (ADR 0012 decision T4) |
| `STREAM_ARTIST_SALE_CONSENT_TYPEHASH` | `StreamArtistSaleConsent(address core,address saleAdapter,uint256 collectionId,bytes32 saleId,bytes32 saleConfigHash,uint256 nonce,uint64 deadline)` | 0x5a0d2fee9c2248ad2b0735d54beb28b1decdd1adeb65c63c4016da70ec399045 | `StreamArtistRegistry` | `1` | EIP-712; artist spec `[AA-SALE-CONSENT]` (ADR 0012 decision T4) |
| `ARTIST_IDENTITY_DOCUMENT` payload tag | `ARTIST_IDENTITY_DOCUMENT` | 0x2126d55680e8526a6a1e238576c0df654dc008fde816e8c1fcb0a5070cf3d1b9 | `StreamArtistRegistry` | `1` | stored-payload tag constant; artist spec `[AA-RECORDS]` (ADR 0012 decision T3) |
| `ARTIST_SIGNATURE_BUNDLE` payload tag | `ARTIST_SIGNATURE_BUNDLE` | 0xbd380808b17a372ab9b9615f35de4cad0deb88a5d9f98fe339cfb976c708005e | `StreamArtistRegistry` | `1` | stored-payload tag constant; artist spec `[AA-RECORDS]` (ADR 0012 decision T3) |
| `ARTIST_DIRECTIVE_PAYLOAD` payload tag | `ARTIST_DIRECTIVE_PAYLOAD` | 0x5e503d7bdc75ceeed4f572354ae0b08d6d8d3033937d6a8b5d8aa9a2489694c5 | `StreamArtistRegistry` | `1` | stored-payload tag constant; artist spec `[AA-RECORDS]` (ADR 0012 decision T3) |
| `ARTIST_RECORD_PREIMAGE` payload tag | `ARTIST_RECORD_PREIMAGE` | 0xfbd53a6faaa3bc868c95acd12b889bf40dbdda94077ea2fcf8cd6cf29b75427d | `StreamArtistRegistry` | `1` | stored-payload tag constant; artist spec `[AA-RECORDS]` (ADR 0012 decision T3) |
| deployment attestation schema ID | `6529STREAM_ARTIST_DEPLOYMENT_ATTESTATION_V1` | 0x033054525a5800f9c570932b5b51ed66f5e8a0f1e7622b490ea3d5611bd08025 | `StreamArtistRegistry` | `1` | pinned schema identifier; artist spec `[AA-DEPLOY]` (ADR 0012 decision T9) |
| `PAYOUT_DESIGNATION_RECORD_DOMAIN` | `6529STREAM_ARTIST_PAYOUT_DESIGNATION_RECORD_V1` | 0x522d15b3feccd38d699443377aff30a2f429ead391a74f9106313a0fd900379b | `StreamArtistRegistry` | `1` | artist spec `[AA-PAYOUT]` (ADR 0013 decision U1) |
| `STEWARD_SANCTION_GRANT_RECORD_DOMAIN` | `6529STREAM_ARTIST_STEWARD_SANCTION_GRANT_RECORD_V1` | 0x8e938520f64582e71a67db13c1e692945f6168798f060033fffca4ad733798b4 | `StreamArtistRegistry` | `1` | artist spec `[AA-ESTATE]` requirement 7 (ADR 0013 decision U4) |
| `ATTRIBUTION_CLAIM_RECORD_DOMAIN` | `6529STREAM_ARTIST_ATTRIBUTION_CLAIM_RECORD_V1` | 0x1680e7a03051474bbcc02fca6246f1703a2728f81a8997930877a706e2eae063 | `StreamArtistRegistry` | `1` | artist spec `[AA-DISPUTE]` requirement 10 (ADR 0013 decision U4) |
| `STREAM_ARTIST_PAYOUT_DESIGNATION_TYPEHASH` | `StreamArtistPayoutDesignation(bytes32 artistId,address payoutAccount,bytes32 previousDesignationRecordHash,uint256 nonce,uint64 signedAt)` | 0xfd30c946c20c3c9415f06991c291231ff12c255c9cc849164de44f91cb72c213 | `StreamArtistRegistry` | `1` | EIP-712; artist spec `[AA-PAYOUT]` (ADR 0013 decision U1) |
| `STREAM_STEWARD_SANCTION_GRANT_TYPEHASH` | `StreamStewardSanctionGrant(bytes32 artistId,bool granted,bytes32 statementHash,uint256 nonce,uint64 signedAt)` | 0xb48c9f264543966930485ab31e707d91b18c4f9e8644f8dd4a8cbb38c2aea9f2 | `StreamArtistRegistry` | `1` | EIP-712; artist spec `[AA-ESTATE]` requirement 7 (ADR 0013 decision U4) |
| `STREAM_COLLABORATOR_IDENTITY_ACCEPTANCE_TYPEHASH` | `StreamCollaboratorIdentityAcceptance(address account,bytes32 identityRecordHash,uint256 nonce,uint64 deadline)` | 0x9a40f74dcb1bb82d3fa4b33ed2dedc82fab75d7dd6c4b04f86cf263a0b867380 | `StreamArtistRegistry` | `1` | EIP-712; artist spec `[AA-COLLAB]` requirement 7 (ADR 0013 decision U4) |
| artist identity document schema ID | `6529STREAM_ARTIST_IDENTITY_V1` | 0x513c1691fa38db92e21766dd1b22bc43dfb88d3f422917796fba5bcec0bb4c17 | `StreamArtistRegistry` | `1` | pinned schema identifier; artist spec `[AA-IDENTITY]` requirement 2 (ADR 0013 decision U4) |
| `ATTRIBUTION_REPUDIATION_RECORD_DOMAIN` | `6529STREAM_ARTIST_ATTRIBUTION_REPUDIATION_RECORD_V1` | 0x295c6fc296e56beb850b55533c6c5d2f45548cda45bb255d9b94a54b4884a4aa | `StreamArtistRegistry` | `1` | artist spec `[AA-DISPUTE]` requirement 5 (ADR 0014 decision V3) |
| `STANDING_REVOCATION_RECORD_DOMAIN` | `6529STREAM_ARTIST_STANDING_REVOCATION_RECORD_V1` | 0xc62769083037c111cec5a5f8d100e5c4064db79bec694312e35e53acc7256d0e | `StreamArtistRegistry` | `1` | artist spec `[AA-GUARD]` requirement 11 (ADR 0014 decision V3) |
| `CONTENT_RATIFICATION_RECORD_DOMAIN` | `6529STREAM_ARTIST_CONTENT_RATIFICATION_RECORD_V1` | 0x90a8ba640de3b545eba38c55a60ece1dc76395a2147d2d2045d8591fad19a730 | `StreamArtistRegistry` | `1` | artist spec `[AA-CONTENT]` requirement 6 (ADR 0014 decision V3) |
| `PLATFORM_WORKS_CORRECTION_RECORD_DOMAIN` | `6529STREAM_PLATFORM_WORKS_CORRECTION_RECORD_V1` | 0x57109180107392289f9aa5aeb40ff031eccfd6b90246bd6c4a1f5c24df62df16 | `StreamArtistRegistry` | `1` | artist spec `[AA-PLATFORM]` requirement 8 (ADR 0014 decision V3) |
| `STREAM_ARTIST_CONTENT_RATIFICATION_TYPEHASH` | `StreamArtistContentRatification(address core,address metadataContract,uint256 collectionId,bytes32 contentStateHash,uint256 nonce,uint64 deadline)` | 0x56c622946d6da26c6684a8bfd94e3142562ae44e7da904bebe454f049c01b1f5 | `StreamArtistRegistry` | `1` | EIP-712; artist spec `[AA-CONTENT]` requirement 6 (ADR 0014 decision V3) |
| `STREAM_ARTIST_STANDING_REVOCATION_TYPEHASH` | `StreamArtistStandingRevocation(bytes32 artistId,address revokedAddress,bytes32 reasonHash,uint256 nonce,uint64 deadline)` | 0xc3782eba55027b9bef1f60b09cfbcfa48bbd834194f743ae92029711ae18f936 | `StreamArtistRegistry` | `1` | EIP-712; artist spec `[AA-GUARD]` requirement 11 (ADR 0014 decision V3) |
| personhood evidence-reference schema ID | `6529STREAM_ARTIST_PERSONHOOD_EVIDENCE_V1` | 0xbd2c70c3ca64561289cb94739dc105b9f0197370aa78d71850a414840f49d488 | `StreamArtistRegistry` | `1` | pinned schema identifier; artist spec `[AA-IDENTITY]` requirement 8 (ADR 0014 decision V3) |
| personhood waiver schema ID | `6529STREAM_ARTIST_PERSONHOOD_WAIVER_V1` | 0xb7fae8632a4a5e5d691710e74a3e1e7ea5fd33638e689d90a7a9aa1f4442fb85 | `StreamArtistRegistry` | `1` | pinned schema identifier; artist spec `[AA-IDENTITY]` requirement 8 (ADR 0014 decision V3) |

### Collection And Preservation Metadata Mirror Rows

Home: [`docs/collection-metadata-contract.md`](collection-metadata-contract.md)
([CMC-SUBJECT-ID], [CMC-CONTENT-ROOT], [CMC-RECORD-CHAIN],
[CMC-OWNER-RECORDS], [CMC-INDEPENDENT-ATTESTOR]). EIP-712 domains: owner
records use `("6529StreamOwnerRecords", "1", chainId, ownerRecords)`;
relayed independent preservation records use
`("6529StreamCollectionAttestations", "1", chainId, attestations)` — both
with ERC-5267.

| Constant name | String preimage | Hash value | Owner | Schema version | Inputs |
| --- | --- | --- | --- | --- | --- |
| `STREAM_SUBJECT_TOKEN_V1` | `6529STREAM_SUBJECT_TOKEN_V1` | `0x1e576f27850d12bc1ec9255ca277dbecfbc84fb3a9a34c474640dfca89811d7e` | metadata satellites | `1` | CM spec `[CMC-SUBJECT-ID]` |
| `STREAM_SUBJECT_MEDIA_V1` | `6529STREAM_SUBJECT_MEDIA_V1` | `0x030f2701e9035fcb711b3acc44ec0bf14b4f4e344e231cdaadce7d14e590994b` | metadata satellites | `1` | CM spec `[CMC-SUBJECT-ID]` |
| `STREAM_SUBJECT_SCOPE_V1` | `6529STREAM_SUBJECT_SCOPE_V1` | `0x748002ff892f4748f1544a8191da460ca6d167aa2e13eeced354e4f66f636394` | metadata satellites | `1` | CM spec `[CMC-SUBJECT-ID]` |
| `STREAM_SUBJECT_COLLECTION_V1` | `6529STREAM_SUBJECT_COLLECTION_V1` | `0x3a882a22dad9915c9193738f63216234155080ed4c4fc9bfae446e90f1df6e16` | metadata satellites | `1` | CM spec `[CMC-SUBJECT-ID]` |
| `STREAM_COLLECTION_CONFIG_STATE_V1` | `6529STREAM_COLLECTION_CONFIG_STATE_V1` | `0x854c83f82b7677e58c61a2482a7a430a8318d765d99a95d3fbce5c84be6cc2b5` | `StreamCore` | `1` | CM spec `[CMC-MANAGEMENT]`; complete collection configuration old/new state hash |
| `STREAM_COLLECTION_BURNS_BLOCKED_STATE_V1` | `6529STREAM_COLLECTION_BURNS_BLOCKED_STATE_V1` | `0x0a834b49bdbe94b7d08a85a25431e3405b397e5f84bf90a90107edb2a58013ec` | `StreamCore` | `1` | CM spec `[CMC-BURN]`; old/new burn-block state hash |
| `STREAM_COLLECTION_FROZEN_STATE_V1` | `6529STREAM_COLLECTION_FROZEN_STATE_V1` | `0xa54d2564d797e7eec4b1cd68d067d7c297bfae640f401ff3b8fde47441079692` | `StreamCore` | `1` | CM spec `[CMC-FREEZE]`; old/new collection-freeze state hash |
| `STREAM_CORE_SATELLITE_POINTER_SCOPE_V1` | `6529STREAM_CORE_SATELLITE_POINTER_SCOPE_V1` | `0xf4a381d3d4c51db07c19830799ea01c544326118ea1db1fb59d54af5f637bdbb` | `StreamCore` | `1` | Umbrella `[LTA-POINTERS]`; pointer action scope hash |
| `STREAM_CORE_SATELLITE_POINTER_STATE_V1` | `6529STREAM_CORE_SATELLITE_POINTER_STATE_V1` | `0x1fdde0a7122d0fc7c237e721e372e43082581dcc6bd2babca4e09bb1e6b3d043` | `StreamCore` | `1` | Umbrella `[LTA-POINTERS]`; old/new cached pointer state plus monotonic revision |
| `STREAM_MODULE_REGISTRATION_SCOPE_V1` | `6529STREAM_MODULE_REGISTRATION_SCOPE_V1` | `0x5277bfb240fc6ff036a86dc964a11dd9db1c1fa99403fc75261e01e39314a274` | module registry | `1` | Umbrella `[LTA-REGISTRY-GOVERNANCE]`; chainid, registry, module |
| `STREAM_MODULE_REGISTRATION_STATE_V1` | `6529STREAM_MODULE_REGISTRATION_STATE_V1` | `0x93088f9512a50b047b7d8d85dff50b75c0477b2100b7faa95e140bdfdeb20b0a` | module registry | `1` | Umbrella `[LTA-REGISTRY-GOVERNANCE]`; absent/full record/revision plus enumeration/chain state |
| `STREAM_MODULE_STATUS_SCOPE_V1` | `6529STREAM_MODULE_STATUS_SCOPE_V1` | `0x104af01db40b16330febbabdcb5564c94185b428a7c45b9ebfedbc16b0e31924` | module registry | `1` | Umbrella `[LTA-REGISTRY-GOVERNANCE]`; chainid, registry, module |
| `STREAM_MODULE_STATUS_STATE_V1` | `6529STREAM_MODULE_STATUS_STATE_V1` | `0x6f5722acd3286491268d034cc0bc3af67af3b10ce36c277911e48af850e23139` | module registry | `1` | Umbrella `[LTA-REGISTRY-GOVERNANCE]`; complete record/status/revision and invariant chain state |
| `STREAM_MODULE_REGISTRY_MANIFEST_SCOPE_V1` | `6529STREAM_MODULE_REGISTRY_MANIFEST_SCOPE_V1` | `0x5feb32edce5c714adb3bee16efa1716d2dc85cb717441aa69cfd15a6b192399b` | module registry | `1` | Umbrella `[LTA-REGISTRY-GOVERNANCE]`; chainid and registry |
| `STREAM_MODULE_REGISTRY_MANIFEST_STATE_V1` | `6529STREAM_MODULE_REGISTRY_MANIFEST_STATE_V1` | `0x2bf0ed54c30fe5b785759f01b7aa59991c942125ff19ccbc12912111aaeb9c62` | module registry | `1` | Umbrella `[LTA-REGISTRY-GOVERNANCE]`; manifest hash, URI hash, revision |
| `STREAM_SYSTEM_MANIFEST_SCOPE_V1` | `6529STREAM_SYSTEM_MANIFEST_SCOPE_V1` | `0xf73b4d7b4d260fce0823707f836fdf29a1767a2a2a9cfbce14ec8c5e49e47841` | `StreamSystemManifest` | `1` | Umbrella `[LTA-MANIFEST-PUBLISH]`; domain, chainid, system-manifest satellite |
| `STREAM_SYSTEM_MANIFEST_STATE_V1` | `6529STREAM_SYSTEM_MANIFEST_STATE_V1` | `0x3764ccb415d0aac07f1bddb8d4841ad6d4c2f9b2fe7ce7d221c586bc056aaf60` | `StreamSystemManifest` | `1` | Umbrella `[LTA-MANIFEST-PUBLISH]`; old/new cached aggregate state plus append-only revision |
| `STREAM_DEPLOYMENT_IDENTITY_V1` | `6529STREAM_DEPLOYMENT_IDENTITY_V1` | `0xabba888804ef35beb44d732a5f39abc2609bd065f98a99779289a9e9c2a4059a` | release tooling / module identity | `1` | Umbrella `[LTA-DEPLOYMENT-IDENTITY]`; domain plus Keccak-256 of the RFC8785-JCS address-free identity view |
| `STREAM_SYSTEM_MANIFEST` module type | `STREAM_SYSTEM_MANIFEST` | `0x47fd79d5a6e9b1d75dcedf141a46e2e8f6d95d5a5be2b88f197fa98a1436fec6` | module registry / `StreamSystemManifest` | `1` | `keccak256` of the ASCII module-type name; no `abi.encode` inputs; Umbrella `[LTA-POINTERS]`, `[LTA-MANIFEST]` |
| `STREAM_CORE_FINALITY_ADAPTER` module type | `STREAM_CORE_FINALITY_ADAPTER` | `0xc61967911fb81a81bc2ac526bef1f8ca6b1acc696ffc230763d9d36e6e5ccfb4` | module registry / `StreamCoreFinalityAdapter` | `1` | immutable Core/collection-metadata bindings, interface `0xebf35615`; Umbrella `[LTA-CORE-FINALITY-ADAPTER]` |
| `STREAM_SYSTEM_MANIFEST_PAYLOAD_V1` schema ID | `STREAM_SYSTEM_MANIFEST_PAYLOAD_V1` | `0x8844b744a67cdcdb84ea3c6e3d686883da175820b9ff07a19cffa14bf62e6e81` | schema catalog / `StreamSystemManifest` | `1` | exact JSON payload schema; Umbrella `[LTA-MANIFEST]` |
| `RFC8785_JCS` canonicalization ID | `RFC8785_JCS` | `0x886c7c89c308c459ca8a626e0ef36a5ea9f4c7a7b56aaf86c71a2ddf3b4f9044` | canonicalization catalog / `StreamSystemManifest` | `1` | RFC 8785 JCS plus pinned I-JSON/NFC restrictions; Umbrella `[LTA-MANIFEST]` |
| `STREAM_SYSTEM_MANIFEST_PAYLOAD_LEAF_V1` | `6529STREAM_SYSTEM_MANIFEST_PAYLOAD_LEAF_V1` | `0x852f4811a2eb32694863d94ba41b545a65ef4c76086a32c35881f0c4e250a7b5` | `StreamSystemManifest` | `1` | chunk index, length, payload hash; Umbrella `[LTA-MANIFEST]` |
| `STREAM_SYSTEM_MANIFEST_PAYLOAD_LIST_V1` | `6529STREAM_SYSTEM_MANIFEST_PAYLOAD_LIST_V1` | `0xa93750a5551ac5668c8f24cca85acaf1d5f8334fac9406f845fce1ce35548839` | `StreamSystemManifest` | `1` | total bytes and ordered leaf hashes; Umbrella `[LTA-MANIFEST]` |
| `STREAM_SYSTEM_MANIFEST_PAYLOAD_ROOT_V1` | `6529STREAM_SYSTEM_MANIFEST_PAYLOAD_ROOT_V1` | `0xd6ab89b077c61a288c7168cf8f1c9a7a19464b10475735dae37cb46a0c94c40b` | `StreamSystemManifest` | `1` | schema/canonicalization IDs, total/count, list hash; Umbrella `[LTA-MANIFEST]` |
| `STREAM_GAS_PARAMETER_SCOPE_V2` | `6529STREAM_GAS_PARAMETER_SCOPE_V2` | `0x9533611d402c2b44cf950a4a8900d25f6829bfac541dc4d5353094f966bb1a71` | GGP hosts | `2` | Umbrella `[LTA-GGP-CORE]`; domain, chainid, host, parameterId |
| `STREAM_GAS_PARAMETER_STATE_V2` | `6529STREAM_GAS_PARAMETER_STATE_V2` | `0x5059a253d3f7dd63b5d9fd1f0568caf72967f501a3db678b31cefe911334159c` | GGP hosts | `2` | Umbrella `[LTA-GGP-CORE]`; value, immutable floor/class, monotonic revision |
| `STREAM_TIME_PARAMETER_SCOPE_V2` | `6529STREAM_TIME_PARAMETER_SCOPE_V2` | `0xd14cc3d71aa1ccb50b6f723d516042b10a7ef31958f86ccb049a09dbcfefff24` | GTP hosts | `2` | Umbrella `[LTA-GTP]`; domain, chainid, host, parameterId |
| `STREAM_TIME_PARAMETER_STATE_V2` | `6529STREAM_TIME_PARAMETER_STATE_V2` | `0x26290762a61f3dda3fad05a62e5a95dcb1c59db2eaf506cb363c2aa2ab7b8384` | GTP hosts | `2` | Umbrella `[LTA-GTP]`; value, immutable block/wall-clock floors, monotonic revision |
| `STREAM_TOKEN_CONTENT_LEAF_V1` | `6529STREAM_TOKEN_CONTENT_LEAF_V1` | `0x61d75cd1a57d24657b860f99f77c15e5f8556fb725b56a96dd770205f9352b0d` | `StreamCollectionMetadata` | `1` | CM spec `[CMC-CONTENT-ROOT]` |
| `STREAM_TOKEN_CONTENT_NODE_V1` | `6529STREAM_TOKEN_CONTENT_NODE_V1` | `0x7239fc0713b7ccc92b7eef3087150a1f32037aff6ab05f5bf78db4f8ab71a6ea` | `StreamCollectionMetadata` | `1` | CM spec `[CMC-CONTENT-ROOT]` |
| `STREAM_RECORD_CHAIN_V1` | `6529STREAM_RECORD_CHAIN_V1` | `0x0e7a0feb85d4a4a3e90074703c19de35786e11afaae8f9868aa2a911bcfa1609` | record-lane satellites | `1` | CM spec `[CMC-RECORD-CHAIN]` |
| `STREAM_OWNER_RECORD_TYPEHASH` | `StreamOwnerRecord(address owner,uint256 tokenId,bytes32 subjectId,bytes32 recordType,bytes32 schemaId,uint16 algorithmId,bytes digest,bytes32 canonicalizationId,string uri,bytes payload,uint64 effectiveAt,uint256 nonce,uint64 deadline)` | `0x9c8c4f8b7ec1e8731277f53e36271ebf92fc96425f0c082143042400814c6b05` | `StreamOwnerRecords` | `1` | EIP-712; CM spec `[CMC-OWNER-RECORDS]` |
| `STREAM_INDEPENDENT_PRESERVATION_TYPEHASH` | `StreamIndependentPreservationRecord(address attestor,uint256 scopeKey,bytes32 subjectId,bytes32 recordType,bytes32 schemaId,uint16 algorithmId,bytes digest,bytes32 canonicalizationId,string uri,bytes payload,uint64 effectiveAt,uint256 nonce,uint64 deadline)` | `0xcb13914f7a4c90b3e2d3d1513c3009284117ccab71b2a60935a620486947c768` | `StreamCollectionAttestations` | `1` | EIP-712; CM spec `[CMC-INDEPENDENT-ATTESTOR]` (ADR 0011 decision R11) |
| `STREAM_OWNER_RECORD_REVOCATION_TYPEHASH` | `StreamOwnerRecordRevocation(address owner,uint256 nonce,uint64 deadline)` | `0x11a07172744cbac614966ef944b190ff3c1b4a7076ab4483c69e48ba2b9ee49c` | `StreamOwnerRecords` | `1` | EIP-712; CM spec `[CMC-OWNER-RECORDS]` rule 9 (ADR 0012 decision T7) |
| `STREAM_INDEPENDENT_PRESERVATION_REVOCATION_TYPEHASH` | `StreamIndependentPreservationRevocation(address attestor,uint256 nonce,uint64 deadline)` | `0x4522059fc24afcc4dadcbf6fc6e0c577c17c5faf11aa8d03b270af3369d3359c` | `StreamCollectionAttestations` | `1` | EIP-712; CM spec `[CMC-INDEPENDENT-ATTESTOR]` nonce-revocation lane ([CMC-OWNER-RECORDS] rule 9; ADR 0012 decision T7) |

### Entropy Mirror Rows

Homes: [`docs/stream-entropy-coordinator.md`](stream-entropy-coordinator.md)
([EC-DOMAINS], Domain Constants) and
[`docs/stream-entropy-providers.md`](stream-entropy-providers.md)
([EP-RAW], Raw Randomness Compression) (ADR 0013 decision U9).

| Constant name | String preimage | Hash value | Owner | Schema version | Inputs |
| --- | --- | --- | --- | --- | --- |
| `STREAM_ENTROPY_REQUEST_V1` | `6529STREAM_ENTROPY_REQUEST_V1` | 0xf8ea7ebca4196e280c0b42e55e16736c8e836382a8859d151eb826edbecb7106 | `StreamEntropyCoordinator` | `1` | coordinator spec `[EC-DOMAINS]` (Request Flow) |
| `STREAM_ENTROPY_SEED_V1` | `6529STREAM_ENTROPY_SEED_V1` | 0x88e816cf6b63abe50b33fdfd5033b9e0f12b8e8ba3925c57c3954ecf8caca69f | `StreamEntropyCoordinator` | `1` | coordinator spec `[EC-DOMAINS]` (Fulfillment Flow) |
| `STREAM_ENTROPY_SCOPE_SUBJECT_V1` | `6529STREAM_ENTROPY_SCOPE_SUBJECT_V1` | 0xef9a2afab4bd9a15841ca37c46b3cdb891a47121a1bfab0201f386d0a7b77490 | `StreamEntropyCoordinator` | `1` | coordinator spec `[EC-SCOPE]` (Scope Entropy Requests; ADR 0011 decision R8) |
| `STREAM_ENTROPY_SCOPE_REQUEST_V1` | `6529STREAM_ENTROPY_SCOPE_REQUEST_V1` | 0xda5ba2e7e598a368f9e05c751fa0bbce4620c6fe030d47737c9eeb15099a3b81 | `StreamEntropyCoordinator` | `1` | coordinator spec `[EC-SCOPE]` (Scope Entropy Requests; ADR 0011 decision R8) |
| `STREAM_ENTROPY_SCOPE_SEED_V1` | `6529STREAM_ENTROPY_SCOPE_SEED_V1` | 0x6111edc8a4ae25589e49af170892e9083107d07df6b48b7201458e32ba38365b | `StreamEntropyCoordinator` | `1` | coordinator spec `[EC-SCOPE]` (Scope Entropy Requests; ADR 0011 decision R8) |
| `FRESH_RECOVERY_POLICY_DOMAIN` | `6529STREAM_ENTROPY_FRESH_RECOVERY_POLICY_V1` | 0x903ca537e686c7d615b886dbd8d81e240e58123e9918bc89ccabb64f2fe9a327 | `StreamEntropyCoordinator` | `1` | coordinator spec `[EC-DOMAINS]` (Storage Model; binds `incidentDeclarerRole`) |
| `FRESH_RECOVERY_STEPS_DOMAIN` | `6529STREAM_ENTROPY_FRESH_RECOVERY_STEPS_V1` | 0x8a9c948a061bd07713c5f797237b5d213f2f7cd133ea20f9e7a51af3fb204b9e | `StreamEntropyCoordinator` | `1` | interior composite; coordinator spec `[EC-DOMAINS]` (Storage Model; ADR 0013 decision U7) |
| `STREAM_PROVIDER_RAW_V1` | `6529STREAM_PROVIDER_RAW_V1` | 0x9d25920cde651730cff9eacf736aaa7aa2f6d1f22e948f5d5e362fb181a5bee1 | provider adapters (generic) | `1` | providers spec `[EP-RAW]` (Raw Randomness Compression) |
| `STREAM_VRF_RAW_V1` | `6529STREAM_VRF_RAW_V1` | 0x9aec1af5d92901527f48ea05f0779a6d6cd5153a45cb99ffa4383b1b4beea311 | `StreamEntropyProviderVRF` | `1` | providers spec `[EP-RAW]` (Raw Randomness Compression) |
| `STREAM_ARRNG_RAW_V1` | `6529STREAM_ARRNG_RAW_V1` | 0xa7c608806995e034e71d26ec44e96245b593a47fe673f8f1d8e33cde02c3bf86 | `StreamEntropyProviderARRNG` | `1` | providers spec `[EP-RAW]` (Raw Randomness Compression) |
| `STREAM_PYTH_RAW_V1` | `6529STREAM_PYTH_RAW_V1` | 0x904dfcae5221db62594fb78af05341a66a4e8d649ec151a90cee174eecf6e246 | `StreamEntropyProviderPyth` | `1` | providers spec `[EP-RAW]` (Raw Randomness Compression) |
| `STREAM_ENTROPY_SCOPE_RANKING_V1` | `6529STREAM_ENTROPY_SCOPE_RANKING_V1` | 0x395f4d0c11d290e3bb32531f328ce6129c034100a89d45d65d1c55d248a6b0d3 | fair-allocation consumers | `1` | coordinator spec `[EC-SCOPE-RAFFLE]` (ADR 0012 decision T6) |
| `STREAM_DRAND_RAW_V1` | `6529STREAM_DRAND_RAW_V1` | 0x81d2ca2a7da654d7cfe760fac3c357e03fc212d4790b5277459b5717b3f46201 | `StreamEntropyProviderDrand` (extension) | `1` | providers spec `[EP-RAW]` (Raw Randomness Compression) |
| `STREAM_MULTI_SOURCE_RAW_V1` | `6529STREAM_MULTI_SOURCE_RAW_V1` | 0x94257c55589ad53441c332497f043fbe4820fe5089152303939a0aaba1f8f4f0 | multi-source mixer adapters (extension) | `1` | providers spec `[EP-RAW]` (Raw Randomness Compression) |

### Umbrella Architecture Mirror Rows

Home: [`docs/stream-long-term-architecture.md`](stream-long-term-architecture.md)
([LTA-DOMAINS]; ordered inputs pinned by the Artwork Finality Freeze and
State Export And Archival Operations code blocks).

| Constant name | String preimage | Hash value | Owner | Schema version | Inputs |
| --- | --- | --- | --- | --- | --- |
| `STREAM_FINALITY_COMPONENTS_V1` | `6529STREAM_FINALITY_COMPONENTS_V1` | 0xf57efb77611ea13bd3a60968beee86ec330159736aa5d42707a9c0676dbc8898 | finality registry | `1` | domain; sorted `FinalityComponentExpectation[]` (Artwork Finality Freeze) |
| `STREAM_CORE_COLLECTION_FACTS_V1` | `6529STREAM_CORE_COLLECTION_FACTS_V1` | 0x387b66c3b8fdca5febff2a13faa7057fef7f711c4155493c8c8087e48b28c764 | `StreamCoreFinalityAdapter` / finality registry | `1` | domain; chainid; actual Core; collectionId; adapter-derived facts with no `createdAt` and `uint256` supply fields; Umbrella `[LTA-CORE-FINALITY-ADAPTER]` |
| `STREAM_CORE_COLLECTION_CONFIG_EMPTY_V1` | `6529STREAM_CORE_COLLECTION_CONFIG_EMPTY_V1` | 0x6adebabfe6f92286e8678fc5f206cacb6b1a3b912afc80b6039e9240567e7f26 | `StreamCoreFinalityAdapter` | `1` | domain; chainid; actual Core; collectionId; adapter-computed empty-config fact; Umbrella `[LTA-CORE-FINALITY-ADAPTER]` |
| `STREAM_FINALITY_V1` | `6529STREAM_FINALITY_V1` | 0x569714204c899f0d33a0f98879ce85708169a5f1e11f763f2897f64e5d6c8493 | finality registry | `1` | domain; chainid; core; collectionId; coreCollectionFactsHash; componentsHash; manifest uriHash/contentHash/schemaId/canonicalizationHash |
| `STREAM_FINALITY_RECOVERY_V1` | `6529STREAM_FINALITY_RECOVERY_V1` | 0x521e8df5a00a793a5b47409e1e7711b4b8857ba9e6c833fe59a48dfa865b19ac | finality registry | `1` | domain; chainid; finalityRegistry; collectionId; expectedOldFinalityRecordHash; recoveryManifest.contentHash; recoveryRouteHash; executeAfter; artworkBytesChanged; reasonHash |
| `STREAM_SCOPED_FINALITY_V1` | `6529STREAM_SCOPED_FINALITY_V1` | 0x5b56313142e6381659f9d10163ccfa5ea22cb437617c8e69b37c31ecda6f3a50 | finality registry | `1` | domain; chainid; core; scopeType; collectionId; tokenId; scopeId; scopedCoreFactsHash; componentsHash; manifest uriHash/contentHash/schemaId/canonicalizationHash |
| `STREAM_SCOPED_CORE_FINALITY_FACTS_V1` | `6529STREAM_SCOPED_CORE_FINALITY_FACTS_V1` | 0x5c6390c543248a4d63630061d67c3d2245df223d9ac586deccabf40620b43f6e | `StreamCoreFinalityAdapter` / finality registry | `1` | domain; chainid; actual Core; raw scope tuple; adapter-derived Core/metadata facts; Umbrella `[LTA-CORE-FINALITY-ADAPTER]` |
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
| `STREAM_EXPORT_TOKEN_DATA_LEAF_V1` | `6529STREAM_EXPORT_TOKEN_DATA_LEAF_V1` | 0x0c586b41736dd3049878e98663002a07e79c06ab6ab5f49c09f03c0e44fa4610 | `STATE_EXPORT_V1` profile | `1` | leaf schema in [LTA-EXPORT]; retention per [MPA-CORE-ABI]/[CMC-BURN] (ADR 0011 decision R12) |
| `STREAM_EXPORT_EVENT_HISTORY_V1` | `6529STREAM_EXPORT_EVENT_HISTORY_V1` | 0xde2f44be2a232fbd4b086150b751c9483f78c1de4779a09d9d2acc84d4ac76ae | `STATE_EXPORT_V1` profile | `1` | event-history snapshot hash; [LTA-EVENT-HISTORY] (ADR 0011 decision R12) |
| `STREAM_EXPORT_SALE_CREDIT_LEAF_V1` | `6529STREAM_EXPORT_SALE_CREDIT_LEAF_V1` | 0x4713509255935af0a6981e3a2eb9948df2dc272218d10db479716667ca9c280b | `STATE_EXPORT_V1` profile | `1` | leaf schema in [LTA-EXPORT]; sale-adapter owed pull credits — outbid refunds, clearing rebates, drift-envelope refunds, maximum-price excess (ADR 0012 decision T3) |
| `STREAM_GUARDIAN_SCOPE_V1` | `6529STREAM_GUARDIAN_SCOPE_V1` | 0x411f2ec1515973db8ec5774ffd6b9e7fbcd8e9c0fb9ffc2b8de7eab7f4325433 | guardian module | `1` | umbrella `[LTA-GUARDIAN]` (ADR 0012 decision T5) |
| `STREAM_GUARDIAN_AUTHORIZATION_V1` | `6529STREAM_GUARDIAN_AUTHORIZATION_V1` | 0x1d7c055e54305625ad501d8d2766e4a0af244277f03ea3ce785360e63ef118fd | guardian module | `1` | umbrella `[LTA-GUARDIAN]` (ADR 0012 decision T5) |
| `STREAM_MODULE_REGISTRATION_RECORD_V1` | `6529STREAM_MODULE_REGISTRATION_RECORD_V1` | 0x4b5b157069f454a5c1b78a95a28e2016af2d428d4eb4037917b271a668490869 | module registry | `1` | umbrella `[LTA-REGISTRY]` requirement 7 (ADR 0013 decision U2) |

The umbrella-hosted `FINALITY_COMPONENT_READ_GAS` parameter identifier is
mirrored in the consolidated
[GGP identifier table](#governed-gas-parameter-identifier-mirror-rows)
below (ADR 0011 decision R12).

### Governance Mirror Rows

Home: [`docs/adr/0004-admin-governance.md`](adr/0004-admin-governance.md)
([GOV-ACTION-ID], [GOV-BATCH], [GOV-MANIFEST-TAIL]), as amended by
[ADR 0017](adr/0017-raise-only-parameter-governance.md). ADR 0004 is the owner-designated
normative home of the canonical governance action identity (ADR 0010
decision D3.4); these rows complete the mirror for the most-executed
preimages in the system — every staged governance action, batch, and GGP
change binds them (ADR 0011 decision R12). The hosting question is
settled (ADR 0014 decision V6): the ADR 0004 home stands, visibly
partitioned so its owner-designated normative sections are
unmistakable against its baseline-era evidence (ADR 0014 decision V9),
and these mirror rows close the outside-the-reviewed-set gap by
placing the governance action and manifest-tail preimages inside the spec inventory's
checker-verified mirror surface and the CI recomputation test — the
inventory reviews them here, and the home's anchors own the ordered
inputs, replay semantics, and window floors.

| Constant name | String preimage | Hash value | Owner | Schema version | Inputs |
| --- | --- | --- | --- | --- | --- |
| `STREAM_GOVERNANCE_ACTION_V2` | `6529STREAM_GOVERNANCE_ACTION_V2` | 0x214cd728538bb3775a7106caff5c761bace11866a984d4a4d97a98f51971ac4b | ADR 0004 governance timelock layer | `2` | ADR 0004 `[GOV-ACTION-ID]`; per-call transition commitments |
| `STREAM_GOVERNANCE_CALLS_V2` | `6529STREAM_GOVERNANCE_CALLS_V2` | 0x10f09566fb70f7947b61639c2a53b3aec872069a8b46edd08ba14eb2b5942b70 | ADR 0004 governance timelock layer | `2` | ADR 0004 `[GOV-ACTION-ID]`, `[GOV-BATCH]`; per-call transition commitments |
| `STREAM_GOVERNANCE_BATCH_SCOPE_V2` | `6529STREAM_GOVERNANCE_BATCH_SCOPE_V2` | 0x6cfd5dfd67f064adac45602c05057edddda810734779c0ebe11b447e6985e31c | ADR 0004 governance timelock layer | `2` | ADR 0004 `[GOV-ACTION-ID]`; callsHash and ordered per-call scope hashes |
| `STREAM_GOVERNANCE_BATCH_OLD_STATE_V2` | `6529STREAM_GOVERNANCE_BATCH_OLD_STATE_V2` | 0xc5029f937b44065c2ad92d9253e07f06117567480206189fcc1409d5509222b7 | ADR 0004 governance timelock layer | `2` | ADR 0004 `[GOV-ACTION-ID]`; callsHash and ordered per-call old-state hashes |
| `STREAM_GOVERNANCE_BATCH_NEW_STATE_V2` | `6529STREAM_GOVERNANCE_BATCH_NEW_STATE_V2` | 0xce958009248d20d9574439fa374bc00c142940af2b496896b5bdbc00b882e98b | ADR 0004 governance timelock layer | `2` | ADR 0004 `[GOV-ACTION-ID]`; callsHash and ordered per-call new-state hashes |
| `STREAM_ROLE_MUTATION_V1` | `6529STREAM_ROLE_MUTATION_V1` | 0xa8dba5d6fcfd6e5b3cd0487118fc42e1d598c9ba0fb59aefad69b419212bc91e | `StreamRoleRegistry` | `1` | prior role chain; chain ID; registry; role; holder; new membership; next role revision |
| `STREAM_GLOBAL_ROLE_MUTATION_V1` | `6529STREAM_GLOBAL_ROLE_MUTATION_V1` | 0x2da8f94be4b1e85c976aae097d48589ff562492679ebc2842c866ba5b986d39c | `StreamRoleRegistry` | `1` | prior global chain; chain ID; registry; role; holder; new membership; next global revision |
| `STREAM_ROLE_MUTATION_SCOPE_V1` | `6529STREAM_ROLE_MUTATION_SCOPE_V1` | 0x51943e9f337cf7f50fc89b1f37701a670f4477d8d6e3efbd34d986b27f35d271 | `StreamRoleRegistry` | `1` | chain ID; registry; role; holder |
| `STREAM_ROLE_MUTATION_STATE_V1` | `6529STREAM_ROLE_MUTATION_STATE_V1` | 0xf80e0ae6730f5e4e48b5a6c1b46bfb06af297aefb0eaa569f87f095a7f99153d | `StreamRoleRegistry` | `1` | scope; membership; role chain/revision; global chain/revision |
| `STREAM_ROLE_MANAGER_CONFIG_V1` | `6529STREAM_ROLE_MANAGER_CONFIG_V1` | 0x6b7160b8472382fb5a6b7cad94720fd10007c4124b0b0d405aa6523763ad0fe7 | `StreamRoleRegistry` | `1` | closed pseudo-role key for manager configuration audit history |
| `STREAM_ROLE_MANAGER_CONFIG_STATE_V1` | `6529STREAM_ROLE_MANAGER_CONFIG_STATE_V1` | 0x00ef486fa9550ecdc9851c2df1073c1c991e7d56e6a0d388357ba5f5a89c4263 | `StreamRoleRegistry` | `1` | chain ID; registry; scope; enabled bit; account-scoped config chain/revision |
| `STREAM_ROLE_MANAGER_CONFIG_MUTATION_V1` | `6529STREAM_ROLE_MANAGER_CONFIG_MUTATION_V1` | 0xbd1ca24b4e56b656dee2d7ca30433716550c54ab67aab3e6b9eba46ac0ff79d6 | `StreamRoleRegistry` | `1` | prior account config chain; chain ID; registry; manager account; new enabled bit; next account revision |
| `STREAM_SYSTEM_MANIFEST_TAIL_TRIGGER_SCOPE_V1` | `6529STREAM_SYSTEM_MANIFEST_TAIL_TRIGGER_SCOPE_V1` | 0x2c9b0dbea692b77bd1679258ca569c13c24eb261671f5a6b78b9fa59cd29c7f1 | ADR 0004 governance executor | `1` | ADR 0004 `[GOV-MANIFEST-TAIL]`; domain, chainid, executor, trigger target, trigger selector |
| `STREAM_SYSTEM_MANIFEST_TAIL_TRIGGER_STATE_V1` | `6529STREAM_SYSTEM_MANIFEST_TAIL_TRIGGER_STATE_V1` | 0xd41313fe7ee9b51221beebf9c314d67aebec3677907eb1365fff4caa4248f493 | ADR 0004 governance executor | `1` | ADR 0004 `[GOV-MANIFEST-TAIL]`; scope, registered bit, trigger code hash, allowed-class mask, append-only count/chain, immutable tail facts |
| `STREAM_SYSTEM_MANIFEST_TAIL_TRIGGER_RECORD_V1` | `6529STREAM_SYSTEM_MANIFEST_TAIL_TRIGGER_RECORD_V1` | 0xe52b2b6e65acb1eae2c217c4b26e893c7d0e7f32afc148867b79c133b3a134fa | ADR 0004 governance executor | `1` | ADR 0004 `[GOV-MANIFEST-TAIL]`; index, exact pair, code hash, mask |
| `STREAM_SYSTEM_MANIFEST_TAIL_TRIGGER_CHAIN_V1` | `6529STREAM_SYSTEM_MANIFEST_TAIL_TRIGGER_CHAIN_V1` | 0xdf8c3b0d7ebdd491123b988924db55f8fd11251d7e88e5d76722331928dd4951 | ADR 0004 governance executor | `1` | ADR 0004 `[GOV-MANIFEST-TAIL]`; chainid, executor, prior chain, record, index |
| `STREAM_SYSTEM_MANIFEST_BOOTSTRAP_SCOPE_V1` | `6529STREAM_SYSTEM_MANIFEST_BOOTSTRAP_SCOPE_V1` | 0xace275f08856e822491961304b01cdc9423d7d16c05518327353df5cd02e33f8 | ADR 0004 governance executor | `1` | ADR 0004 `[GOV-MANIFEST-TAIL]`; chainid and executor bootstrap scope |
| `STREAM_SYSTEM_MANIFEST_BOOTSTRAP_STATE_V1` | `6529STREAM_SYSTEM_MANIFEST_BOOTSTRAP_STATE_V1` | 0x96decef116f307400b4d1826658d33976ec923ce136ead67b736b8becbe781ef | ADR 0004 governance executor | `1` | ADR 0004 `[GOV-MANIFEST-TAIL]`; bound/sealed bits, recorded Core/satellite/code hashes, observed/expected trigger set, content/inventory commitments, actual sealed root |
| `STREAM_SYSTEM_MANIFEST_BOOTSTRAP_TRIGGER_V1` | `6529STREAM_SYSTEM_MANIFEST_BOOTSTRAP_TRIGGER_V1` | 0x9927dc0a368efe3d99880bb180d83938664a29ad399291c4544e4cab70c84548 | ADR 0004 governance executor | `1` | ADR 0004 `[GOV-MANIFEST-TAIL]`; ordered rolling genesis trigger commitment |
| `STREAM_SYSTEM_MANIFEST_BOOTSTRAP_INVENTORY_LEAF_V1` | `6529STREAM_SYSTEM_MANIFEST_BOOTSTRAP_INVENTORY_LEAF_V1` | 0x389d432187327bb28628b23403c9b3c549d0cf950e480ad6d69b7d9fa7b48b9d | ADR 0004 governance executor | `1` | ADR 0004 `[GOV-MANIFEST-TAIL]`; typed Core-pointer, registry-header, or registry-module live-state leaf |
| `STREAM_SYSTEM_MANIFEST_BOOTSTRAP_INVENTORY_CHAIN_V1` | `6529STREAM_SYSTEM_MANIFEST_BOOTSTRAP_INVENTORY_CHAIN_V1` | 0x9efe6891a30e5198982f60b2d916e3275b866addbee37b7d4b875e52d5251e89 | ADR 0004 governance executor | `1` | ADR 0004 `[GOV-MANIFEST-TAIL]`; prior chain, global leaf index, inventory leaf hash |
| `STREAM_SYSTEM_MANIFEST_BOOTSTRAP_INVENTORY_ROOT_V1` | `6529STREAM_SYSTEM_MANIFEST_BOOTSTRAP_INVENTORY_ROOT_V1` | 0xb524bfb9f69adc6c2d0e07003dd39a76b1d6a728dd95dbd495f709428d21b4ec | ADR 0004 governance executor | `1` | ADR 0004 `[GOV-MANIFEST-TAIL]`; chainid, executor, bound Core, leaf count, final inventory chain |
Governance action-class numeric IDs are catalog values, not enum ordinals that
may be reordered. The protocol-v1 mirror is append-only:

| Numeric ID | Name | Status |
| --- | --- | --- |
| `0` | `IMMEDIATE_TIGHTENING` | retained |
| `1` | `DELAYED_LOOSENING` | retained |
| `2` | `TERMINAL_FREEZE` | retained |
| `3` | `POINTER_REPLACEMENT` | retained |
| `4` | `FUNDS_RECOVERY` | retained |
| `5` | `SUCCESSOR_DECLARATION` | retained |
| `6` | `EMERGENCY_RESTORATION` | `retired_pre_genesis`; forbidden for scheduling and execution; reserved and never reusable (ADR 0017) |

### Governed Gas Parameter Identifier Mirror Rows

Pattern home:
[`docs/stream-long-term-architecture.md`](stream-long-term-architecture.md)
([LTA-GGP]). Every `parameterId` is the `keccak256` of the string
preimage — `"6529STREAM_GGP_" || <constant name>` per [LTA-GGP] rule 5 —
with no `abi.encode` inputs; the per-parameter host, genesis value,
floor, failure class, and sizing evidence are owned by the subsystem home named in each Inputs
cell. This table carries exactly one row per [LTA-GGP] inventory entry
(ADR 0011 decision R12): an inventory entry without a row here, or a row
without an inventory entry, is a conformance defect, and inventory
growth by spec amendment must land with its mirror row in the same
change. Governed Time Parameters — the entropy lifecycle block-count
windows governed under the raise-only discipline of their own
pattern home ([LTA-GTP]; ADR 0017) — are consolidated in
this same table under the same closed-world rule: one row per [LTA-GTP]
genesis instantiation, with `parameterId` computed as
`keccak256("6529STREAM_GTP_" || <constant name>)` per [LTA-GTP] rule 3
and the per-parameter host, genesis value, floors, and sizing evidence
owned by the subsystem home named in each Inputs cell. Identifier
constant names are uniform (ADR 0013 decision U9): exactly `GGP_` or
`GTP_` followed by the parameter constant name, with no additional
suffix — the CI checker verifies these labels row-for-row against the exact
closed-world LTA inventories and verifies the generic hosts' exact GGP/GTP
prefix derivations, so a stray suffix is a naming defect, never a style
choice. There are no row-specific Solidity identifier constants.

| Constant name | String preimage | Hash value | Owner | Schema version | Inputs |
| --- | --- | --- | --- | --- | --- |
| `GGP_ROYALTY_RESOLVER_GAS_LIMIT` | `6529STREAM_GGP_ROYALTY_RESOLVER_GAS_LIMIT` | 0x9bae92ab1dd0c5535c65125ea4ee7cff3d55fc31fc2555096c2b5eabceb5bcda | `StreamCore` | `1` | GGP key; revenue spec `[RSR-GGP]`, `[RSR-2981-GAS]` |
| `GGP_ROYALTY_RETURN_GAS_BUFFER` | `6529STREAM_GGP_ROYALTY_RETURN_GAS_BUFFER` | 0x0af6f5a1a5059e398191fa0af185be12fee6d609933826603244c7f247793be7 | `StreamCore` | `1` | GGP key; revenue spec `[RSR-GGP]` |
| `GGP_ERC_1271_GAS_LIMIT` | `6529STREAM_GGP_ERC_1271_GAS_LIMIT` | 0xa0c8ff821dc961fbadc34e975a6ca4d3e499b23388ea86883bae7cd5a1d84157 | split factory parameter store | `1` | GGP key; revenue spec `[RSR-GGP]`, `[RSR-1271]` |
| `GGP_ASSET_POLICY_GAS_LIMIT` | `6529STREAM_GGP_ASSET_POLICY_GAS_LIMIT` | 0xbfc1f824948b8dc9573791fa40eeb403e7322af41d0967f90518dbbb531bf648 | split factory parameter store | `1` | GGP key; revenue spec `[RSR-GGP]`, `[RSR-ASSET-POLICY]` |
| `GGP_WALLET_DEPOSIT_GAS_LIMIT` | `6529STREAM_GGP_WALLET_DEPOSIT_GAS_LIMIT` | 0xd208e16b8676adecbbdd17f529a9effcb9153af90ac08886fb2906298206ff45 | split factory parameter store | `1` | GGP key; revenue spec `[RSR-GGP]` |
| `GGP_FLUSH_GAS_FLOOR` | `6529STREAM_GGP_FLUSH_GAS_FLOOR` | 0x99168b87a7d39f5ba4862568c012ad3b51c552ec78108b88c6be5f5a6426ebe6 | revenue escrow | `1` | GGP key; revenue spec `[RSR-GGP]` |
| `GGP_MINT_GATE_GAS_LIMIT` | `6529STREAM_GGP_MINT_GATE_GAS_LIMIT` | 0xf896db78d4fb703c92d45856189181cb6daa113dada9718f74206095d4fbf817 | `StreamMintManager` | `1` | GGP key; mint spec `[MPA-GATES]` |
| `GGP_TICKET_ERC1271_GAS_LIMIT` | `6529STREAM_GGP_TICKET_ERC1271_GAS_LIMIT` | 0x6a05447612b16e61c6b274125ccdfb6545e058d195b5d82128b41a7205e4a5b6 | `StreamMintTicketGate` | `1` | GGP key; mint spec `[MPA-TICKET]` |
| `GGP_ARTIST_AUTHORITY_GAS_LIMIT` | `6529STREAM_GGP_ARTIST_AUTHORITY_GAS_LIMIT` | 0x194fce9f57e4e64ea539858df133e20abf69979b77fd4c2556f7c185ac391fe3 | `StreamMintManager` | `1` | GGP key; mint spec `[MPA-CONSENT]` |
| `GGP_SALE_ERC1271_GAS_LIMIT` | `6529STREAM_GGP_SALE_ERC1271_GAS_LIMIT` | 0x17b207440a43ce0136b5ee0bc3becf37652825825d88c68e1e0750bf59ec914c | sale adapters | `1` | GGP key; sales spec `[SSA-GAS]` |
| `GGP_DELEGATE_REGISTRY_GAS_LIMIT` | `6529STREAM_GGP_DELEGATE_REGISTRY_GAS_LIMIT` | 0xd75b7f96fae550dd69de8ac7536a203e30ec57da63811df1559129479b5ef185 | delegate gate | `1` | GGP key; sales spec `[SSA-GAS]` |
| `GGP_SALE_ARTIST_AUTHORITY_GAS_LIMIT` | `6529STREAM_GGP_SALE_ARTIST_AUTHORITY_GAS_LIMIT` | 0xe8a88819edeabf6e6327f815980331deea6ed50c446b74f1a24055fbc65ad4d0 | sale adapters | `1` | GGP key; sales spec `[SSA-GAS]`, `[SSA-CONTEST-STOP]` (ADR 0012 decision T4) |
| `GGP_REVEAL_ATTEMPT_GAS_LIMIT` | `6529STREAM_GGP_REVEAL_ATTEMPT_GAS_LIMIT` | 0xd96deb8f5aad0fd19d6d79b209801e838cb0342c6967312895db5450ba01f01b | sale adapters | `1` | GGP key; sales spec `[SSA-REVEAL]`, coordinator spec `AT_MINT` attempt bound (ADR 0013 decision U7) |
| `GGP_SALE_NFT_DELIVERY_GAS_LIMIT` | `6529STREAM_GGP_SALE_NFT_DELIVERY_GAS_LIMIT` | 0xaccd7fad510e0ff312662187cf184397c8d9baaf0a6bb18dc3b804cc3ae3b372 | sale adapters | `1` | GGP key; sales spec `[SSA-GAS]` (ADR 0013 decision U6) |
| `GGP_METADATA_ROUTER_GAS_LIMIT` | `6529STREAM_GGP_METADATA_ROUTER_GAS_LIMIT` | 0x02ad62929eaa837b9d1704745193125454925fd11a6bf273d7bb1faa23272e93 | `StreamCore` | `1` | GGP key; metadata spec `[MRR-ROUTER-GGP]` |
| `GGP_ENTROPY_VIEW_GAS_LIMIT` | `6529STREAM_GGP_ENTROPY_VIEW_GAS_LIMIT` | 0x2bef811c095d83c93627f797c5c71bc97b747ab91fba78266f8f86513f50f5f6 | metadata router | `1` | GGP key; metadata spec `[MRR-ENTROPY-READ]` |
| `GGP_ENTROPY_REGISTRATION_GAS_LIMIT` | `6529STREAM_GGP_ENTROPY_REGISTRATION_GAS_LIMIT` | 0x51125071e3dfb233a2711689d4cc377bbda429f1356ebc09a58d763548541e17 | `StreamCore` | `1` | GGP key; coordinator spec `[EC-REGGAS]` |
| `GGP_ENTROPY_RESULT_PROBE_GAS_LIMIT` | `6529STREAM_GGP_ENTROPY_RESULT_PROBE_GAS_LIMIT` | 0xaf00713aa70c259c23836c61245814e6e3b5fab1fe61b8879c0bd5450f23537c | `StreamEntropyCoordinator` | `1` | GGP key; coordinator spec `[EC-INCIDENT-ROLE]` |
| `GGP_VRF_CALLBACK_GAS_LIMIT` | `6529STREAM_GGP_VRF_CALLBACK_GAS_LIMIT` | 0xb54bc37de6ab63d94434a3fb47e0b24ad67118105c91c59db7b1c58d482f5491 | provider adapters | `1` | GGP key; providers spec `[EP-VRF-CONFIG]` |
| `GGP_ARTIST_ERC1271_VERIFY_GAS` | `6529STREAM_GGP_ARTIST_ERC1271_VERIFY_GAS` | 0x04bd88d7a1b04a4fc7476b74a962c2fea893f8ad4e6711b1c13e828f151458b5 | `StreamArtistRegistry` | `1` | GGP key; artist spec `[AA-SIGVER]` |
| `GGP_METADATA_ERC1271_VERIFY_GAS` | `6529STREAM_GGP_METADATA_ERC1271_VERIFY_GAS` | 0x3ca324ef8262b1ff4cb8753a082cd8780e50f754c1a323a433e0e7665a5ec9f9 | verifying metadata satellites | `1` | GGP key; CM spec `[CMC-SIGVER-GGP]` (ADR 0011 decision R10; `_ID` suffix retired, ADR 0013 decision U9) |
| `GGP_FINALITY_COMPONENT_READ_GAS` | `6529STREAM_GGP_FINALITY_COMPONENT_READ_GAS` | 0xbf54fb4ba4a0942771e26fe4b1f829f8324f6f98ef66e080fd6885b75bdf3221 | finality registry | `1` | GGP key; umbrella `[LTA-GGP]` (Artwork Finality Freeze; `_ID` suffix retired, ADR 0013 decision U9) |
| `GTP_ENTROPY_REQUEST_TIMEOUT_BLOCKS` | `6529STREAM_GTP_ENTROPY_REQUEST_TIMEOUT_BLOCKS` | 0x63722ca7b016ab346b7839fe4e01fa7e0627bd5fb99531f7dbe5ec8c34e35c8d | `StreamEntropyCoordinator` | `1` | GTP key ([LTA-GTP]; ADR 0012 decision T1); coordinator spec `[EC-TIME]` |
| `GTP_ENTROPY_REVEAL_SLO_BLOCKS` | `6529STREAM_GTP_ENTROPY_REVEAL_SLO_BLOCKS` | 0x823057688d7c18dca4c528004d7912dfe0a32c36528a2cff1eb0e2a9164ab5e0 | `StreamEntropyCoordinator` | `1` | GTP key ([LTA-GTP]; ADR 0012 decision T1); coordinator spec `[EC-TIME]` |
| `GTP_ENTROPY_RECOVERY_STEP_DELAY_BLOCKS` | `6529STREAM_GTP_ENTROPY_RECOVERY_STEP_DELAY_BLOCKS` | 0x0be33ccf48a79079b125936b770c51cdd786fd29d574ce9071323b86838bccd8 | `StreamEntropyCoordinator` | `1` | GTP key ([LTA-GTP]; ADR 0012 decision T1); coordinator spec `[EC-TIME]` |

### Pinned-Name Glossary

Three pinned name families read irregularly to a future maintainer and
are glossed here rather than renamed, because the names and values are
Permanent surface (ADR 0014 decision V9):

1. The `GGP_`/`GTP_` identifier prefixes abbreviate Governed Gas
   Parameter and Governed Time Parameter; the pattern homes are
   [LTA-GGP] and [LTA-GTP], and the expansion appears wherever the
   table above is consumed so the abbreviation never travels alone.
2. The sales EIP-712 domain name `6529Stream Sales` is the single
   spaced name among the `6529Stream*` domain names. The space is part
   of the pinned Permanent name (home
   [`docs/stream-sales-and-auctions.md`](stream-sales-and-auctions.md),
   Domain Constants And Typehashes); integration code must copy it
   byte-exactly, and no CamelCase alias exists or ever will.
3. The `STREAM_ADMINS_OR_GOVERNANCE` deployment-inventory label records that
   its holder may be the admin Safe layer early in the line's life or the ADR
   0004 governance layer later; the `OR` is part of the pinned vocabulary word,
   not an unresolved design choice. It is not a Core pointer family: Core and
   `StreamSystemManifest` bind the executor immutably, and the satellite derives
   the aggregate field from that binding. The genesis inventory's
   governance-layer entry carries the matching deployment-side note
   ([`docs/launch-conformance-matrix.md`](launch-conformance-matrix.md)
   [LCM-GENESIS]).

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
    conformance gate 11), including outstanding sale-layer pull
    credits — outbid refunds, clearing rebates, drift-envelope refunds,
    and maximum-price excess — the owed-funds surface carried by the
    sale-credit state-export leaf ([LTA-EXPORT]; ADR 0012 decision T3).
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

Renderer-input `tokenData` bytes are the one deliberate state-recovered
surface in this plan, never an event-replay surface (ADR 0011 decisions
R1 and R12): Core retains them for burned tokens
([`docs/mint-policy-and-accounting.md`](mint-policy-and-accounting.md)
[MPA-CORE-ABI]; [CMC-BURN]), and reconstruction reads them from Core
state, verified against the `STREAM_EXPORT_TOKEN_DATA_LEAF_V1` leaves
of the state export ([LTA-EXPORT]). The export leaf carries
`(tokenId, tokenDataHash, burned)` — an attestation of the bytes,
never the bytes — so no export artifact is a `tokenData` carrier, and
log data is not a carrier for them either; a consumer without live
state reads the bytes from an archival node or a state snapshot and
proves them against the leaf hashes.

## Module Identity Surface

Requirements [PV1-MODULE-ID]:

Every genesis satellite must expose the canonical module identity surface
(ADR 0009 decision 3), defined once in
[`stream-long-term-architecture.md`](stream-long-term-architecture.md)
([LTA-MODULE-ID], Satellite Versioning; anchor per ADR 0013 decision U9)
and golden-tested by selector:

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
`streamModuleDeploymentManifestHash()` returns the release-wide digest above,
not a per-contract file hash. It is identical across the deployment and may be
injected only after the address-free view has been hashed; its constructor word
is zero in the committed template, so neither its own value nor resolved
protocol addresses feed back into its preimage.
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
   stated before binding, not an open roadmap item. Two consequences are
   deployment-gated rather than implied (ADR 0011 decision R12): the
   artist's recorded acknowledgment of the disclosure-only term is
   release evidence in the artist ceremony rehearsal gate, and royalty
   resolution on the pinned launch marketplaces — shared royalty-registry
   entries and per-marketplace royalty configuration included — is
   release evidence in the marketplace royalty-resolution gate (both
   [`docs/launch-conformance-matrix.md`](launch-conformance-matrix.md),
   [LCM-MARKETPLACE] and Required Gates). The acknowledgment is paired
   with the affirmative case in the same rehearsal artifact: the
   artist's unilateral royalty-freeze right and economics-consent
   standing ([AA-ECON]) and the deployment-gated marketplace
   royalty-resolution coverage ([LCM-MARKETPLACE]) are presented
   beside the disclosed term, so the term reads as a considered
   posture with compensating artist protections, never a bare waiver.
2. Non-transferable, soulbound, or lockable tokens (ERC-5192-class
   locks) — successor line only, precluded by the same transfer-openness
   invariant. Exhibition mementos, attendance artifacts, and artist-proof
   soulbounds must be modeled as separate contracts or as attestation
   records — the documented pattern is
   [`docs/collection-metadata-contract.md`](collection-metadata-contract.md)
   [CMC-MEMENTO] (ADR 0011 decision R9) — never as Core token properties.
3. Rental and user-role mechanics (ERC-4907-class), facade-controlled
   mutation, and any other transfer-conditioned or transfer-hooked token
   behavior — successor line only, under the same invariant and ADR 0016.
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
9. Permissionless artist onboarding and permissionless collection
   creation. Protocol v1 is a curated platform, and that is a
   deliberate, stated posture of this deployment, not an accident of
   scope (ADR 0011 decision R12): every collection and every artist
   binding originates from governed platform roles
   ([`docs/stream-artist-authority.md`](stream-artist-authority.md)
   [AA-ROLES];
   [`docs/collection-metadata-contract.md`](collection-metadata-contract.md)),
   so the platform's willingness to onboard is a disclosed liveness
   assumption — with governance gone, every existing work keeps every
   permanence guarantee, but no new collection or binding can ever be
   created on this deployment. Artist-initiated binding-proposal
   surfaces may arrive later as Replaceable modules behind the frozen
   registry interfaces through their own accepted specs, but creation
   and binding execution authority remains governed on this Core line
   for its whole life. That relief valve is pre-shaped, not open-ended:
   a binding-proposal module binds only to surfaces this line already
   freezes — proposal records against the [AA-BINDING] binding
   identity, execution through [AA-ROLES] platform authority, module
   registration through the [LTA-REGISTRY] pattern — so adding one
   later is an accepted Replaceable module spec against frozen
   interfaces, never a new Permanent surface and never a successor
   line, and a willing future governance is not blocked by missing
   Permanent machinery. The artist-departure posture is likewise
   stated rather than implied: an artist who leaves the platform keeps
   every already-shipped guarantee — verified attribution, the royalty
   freeze right and economics-consent standing ([AA-ECON]), and
   consent refusal that blocks every future mint of their bound
   collections ([AA-CONSENT]) — but the existing corpus remains hosted
   on this shared, operator-governed Core for the life of the line;
   there is no artist-owned contract to take along, and the
   artist-owned-contract segment served by artist-deployment platforms
   is deliberately ceded by this line. The designed departure path for
   future work is a declared successor or companion line with the
   artist's registry history imported ([AA-IMPORT]; [LTA-MANIFEST]),
   never a migration of existing tokens.
10. Serial-number and token-ID selection, and durable serial
    reservations — successor line only. v1 Core allocates collection
    serials sequentially with no durable reservation state; the single
    home for the reservation posture is
    [`docs/mint-policy-and-accounting.md`](mint-policy-and-accounting.md)
    (Core Contract Changes; ADR 0009 decision 1; ADR 0011 decision R9),
    and content selection binds artwork content only, never serials
    ([`docs/stream-sales-and-auctions.md`](stream-sales-and-auctions.md)
    [SSA-CONTENT]).
11. ERC-1155 and every semi-fungible token semantic — successor line
    only, never on this Core line (ADR 0012 decision T6). An edition of
    N is N sequential ERC-721 serials in one collection; the editions
    posture home is
    [`docs/stream-sales-and-auctions.md`](stream-sales-and-auctions.md)
    [SSA-EDITIONS].

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
2. C2PA, IIIF, and PREMIS records — the pinned PREMIS v3 crosswalk
   profile lives at
   [`docs/collection-metadata-contract.md`](collection-metadata-contract.md)
   [CMC-PREMIS-PROFILE] (ADR 0011 decision R11) — richer preservation
   modules, and museum-grade metadata depth through collection metadata,
   preservation, attestation, and view satellites, plus the
   owner-writable registrar records satellite ([CMC-OWNER-RECORDS];
   ADR 0010 decision D6.2).
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
