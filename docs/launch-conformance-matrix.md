# Deployment Conformance Matrix

Specification status: Draft; the gate set tracks the Draft specs it
enforces. This document follows [`docs/spec-policy.md`](spec-policy.md).

This document turns the Stream protocol specification into deployment gates.
It is not a roadmap. A production deployment is conformant only when every
gate below maps to code, tests, events, and release artifacts. A failed or
unmapped gate is a specification violation that blocks deployment, not a
roadmap item.

## Scope

Requirements [LCM-SCOPE]:

The current contracts predate the protocol specification and do not yet
conform. A specs-only PR may merge before implementation, but a deployment,
audit handoff, or release branch must treat any failed gate as blocking.

## Review-Entry Conditions

Requirements [LCM-REVIEW-ENTRY]:

No specification in the inventory may move from `Draft` to `Review` until
the conditions below hold; this matrix is the tracking point named by
[`docs/spec-policy.md`](spec-policy.md) (Requirement Anchors):

1. Requirement-anchor backfill is complete: every normative section in
   every inventory document carries a stable bracketed anchor, and every
   binding requirement is numbered within its section.
2. A machine-checked traceability artifact maps every anchored `must` to
   at least one named gate row, test, static check, or release artifact
   in this matrix, and CI fails on unmapped requirements (ADR 0010
   decision D3.3).
3. The v1 machine-readable event catalog exists with final production
   signatures — including `schemaVersion` positions and `topic0` values —
   for every non-standard event, generated from the spec set and checked
   by the golden event tests. Event snippets in spec prose remain
   illustrative; this catalog is the authority
   ([`docs/spec-policy.md`](spec-policy.md), Normative Precedence And
   Single Sourcing).
4. Every hash value in the domain-constants homes and the protocol v1
   mirror tables is pinned from its string preimage, and the CI
   recomputation test passes.

## Forbidden Production Patterns

Requirements [LCM-FORBIDDEN]:

Production contracts must not contain:

1. `tx.origin` in mint, sale, drop, auction, authorization, or payment paths.
2. `abi.encodePacked` or string concatenation for authority, sale, assignment,
   policy, profile, pointer, entropy, or finality hashes.
   Standard CREATE2 address derivation is the explicit exception because the
   EVM formula itself uses packed bytes; those packed bytes must not be reused
   as authority or policy hashes.
3. OpenZeppelin `ERC2981` storage or any second Core royalty source of truth.
4. Core-owned collection metadata, script assembly, dependency assembly,
   randomizer state, token hash storage, or primary-sale split policy.
5. Push primary-sale payments to artists, posters, curators, protocol, bidders,
   or split recipients.
6. Casual `emergencyWithdraw` from any contract that can hold owed funds,
   escrowed funds, refunds, or recipient balances.
7. Magic critical-pointer switches such as `updateContracts(uint8,address)`.
8. Selector-alias authorization such as reusing `this.X.selector` for an
   unrelated protected operation.
9. Token ID range heuristics for collection identity, burn validation, royalty
   resolution, metadata routing, or inherited freeze checks.
10. `bytes32(0)` as an entropy pending/finalized sentinel.
11. Multi-source entropy mixers, timelock reveal schemes, or instant entropy
    finalization inside sale settlement as default production behavior.
12. `address(0)` as a blessed-authorizer convention anywhere a signed
    authorization is verified; authorization surfaces carry an explicit
    `AuthorizerKind` and reject zero `ecrecover` results
    ([`docs/mint-policy-and-accounting.md`](mint-policy-and-accounting.md)
    [MPA-AUTHZ]; ADR 0010 decision D8.3).
13. Zero-as-sentinel counter increments: counter increments are explicit
    `>= 1` values, and zero is invalid at configuration and consumption
    (ADR 0010 decision D8.4).

## Required Gates

Requirements [LCM-GATES]:

Every gate row carries a Genesis flag: `mandatory` gates block the genesis
deployment ceremony outright; a `conditional` gate binds the named surface
and blocks any deployment that ships that surface. All genesis-inventory
surfaces are `mandatory` (ADR 0010 decision D5.10) — the optional-at-genesis
list in the Genesis Deployment Profile is the only source of conditional
surfaces, and shipping one without its activated gate row fails this
matrix.

| Gate | Code Surface | Required Tests | Release Artifact | Genesis |
|---|---|---|---|---|
| Core-native ERC-2981 | `StreamCore.royaltyInfo`, revenue resolver | canonical `0x54f77a09` resolver selector; malformed/OOG/external-call resolver fallback; all-cold gas; precheck and staticcall read current `ROYALTY_RESOLVER_GAS_LIMIT` GGP value ([RSR-2981-GAS]) | Core bytecode size, resolver gas report | mandatory |
| Pull split wallets | split factory, split wallet, revenue escrow | conservation fuzz, forced ETH, approved-standard ERC-20 release/sync, unsupported ERC-20 denial, reentrancy, `DEPRECATED` release-under-grace ([RSR-ASSET-POLICY]); ERC-1271 named-class verification — heaviest legitimate wallet class passes within the `ERC_1271_GAS_LIMIT` GGP, malicious wallet rejected ([RSR-1271]) | profile schema, wallet code hashes | mandatory |
| Primary native ETH and approved-standard ERC-20 settlement | fixed-price sale adapter, ERC-20 primary settlement adapter, `StreamPrimarySaleSettlement`, asset policy registry, revenue escrow | no `tx.origin`, policy hash binding, escrow fallback, adapter and escrow both enforce `ACTIVE` asset policy, exact ERC-20 transfer accounting, allowance/payment failure handling; payer-signed `PaymentIntent` verified before any allowance pull with expired/replayed/revoked/over-cap negative tests ([RSR-PAYMENT-INTENT]) | sale authorization schema, approved asset and adapter manifests | mandatory |
| Sales and auctions | genesis sale adapters and gate modules per [`docs/stream-sales-and-auctions.md`](stream-sales-and-auctions.md) | the full [SSA-GATES] suite: English auction (reserve, increment floor, anti-snipe extension and cap, CEI, idempotent settlement, pull refunds), Dutch (schedule determinism, clearing, rebate conservation), refund-window custody, burn-to-mint (retained-identity proof, manager-scoped nullifiers, finality interaction refusals), delegate gate, content selection, registry governance, ERC-4337 + paymaster end-to-end run, custody-held settlement ordering (`CUSTODY_SETTLEMENT_TRANSFER`, [RSR-SETTLEMENT-BOUNDARY]), event reconstruction | sale/auction state-machine manifests, adapter registry manifest | mandatory |
| Collection management | Core collection boundary | create/status/max-supply events and transitions | collection facts schema | mandatory |
| Token identity | Core mint boundary, `tokenCollectionIdentity` | Core-owned token allocation, collection serial mapping, mapping-existence read, prepared-incomplete identity read, burn retained mapping; `TokenCollectionRegistered` emitted at identity write and event-only replay rebuilds the full mapping (ADR 0010 decision D10.1; protocol v1 [PV1-RECON].9) | token identity schema | mandatory |
| Token-level metadata | collection metadata satellite | token data/field overrides, token locks, burned archival reads | token metadata schema | mandatory |
| Burn | Core burn boundary | owner/approved, mapping retained, finalized burn blocked, one-way collection burn block readable for finality ([CMC-BURN]; ADR 0010 decision D10.5) | burn policy manifest | mandatory |
| Mint accounting | mint manager, ledger, `StreamMintTicketGate` | duplicate-key aggregation, static caps, signed ticket binding; reentrancy guard on `mint()` and prepared entrypoints; `registerPhasePolicy` binds `msg.sender` to its manager argument; gate calls forward `max(gateGasLimit, MINT_GATE_GAS_LIMIT)` with returndata/nullifier bounds ([MPA-GATES]); `AuthorizerKind` enforcement with zero-`ecrecover` and non-canonical-signature negatives ([MPA-AUTHZ]); zero-increment rejection; manager-scoped nullifiers; Merkle allowlist cap mode ([MPA-MERKLE]); `GLOBAL` counter scope with reserved-constant `(0, 0)` derivation goldens ([MPA-SCOPES]); counter-continuity import ([MPA-CONTINUITY]); policy grace windows ([MPA-GRACE]); ticket revocation | policy hash schema | mandatory |
| Artist authority | `StreamArtistRegistry` plus consuming satellites | the nine [AA-GATES] suites: two-sided binding, sanction-required finality, consent modes, economics consent and royalty freeze, signature verification (ERC-1271, GGP probes), key lifecycle (rotation/succession/dormancy), disputes, attribution display, record-family write authority | artist registry manifest, consent/sanction schema hashes | mandatory |
| Entropy lifecycle | entropy coordinator, provider | identity written and entropy registered before `_safeMint` callback; non-reentrant request/fulfill; single active request; no instant provider calls from mint path; `ENTROPY_REGISTRATION_GAS_LIMIT` GGP semantics ([EC-REGGAS]); `maxFeeWei` binding with pull-credit refunds ([EC-FEEBIND]); callback persistence and retry ([EP-CALLBACK]); `INSTANT` restricted to declared `LOW_SECURITY` collections; lifecycle mapping matches [EC-LIFECYCLE] | entropy policy manifest; measured `fulfillEntropy` gas envelope with callback margin and `VRF_CALLBACK_GAS_FLOOR` record | mandatory |
| Metadata routing | metadata router, renderer | escaping, size limits, router failure behavior, ERC-4906 auth; renderer determinism static gate and pinned golden render vectors ([MRR-DETERMINISM]); full-view and paged-chunk byte identity ([MRR-FULL-VIEW]) | renderer and context manifests, golden render vector artifact | mandatory |
| Contract metadata | Core `contractURI()` delegation, contract-metadata satellite | ERC-7572 `contractURI()` bounded delegated read, satellite pointer, failure fallback, `ContractURIUpdated()` emitter auth (ADR 0009 decision 4) | contract-metadata manifest, selector test | mandatory |
| Marketplace collection display | collection discovery machine path ([MRR-COLLECTION-DISCOVERY]) | retained evidence that each artist series resolves as its own collection on the major marketplaces/indexers targeted at launch, exercised through the published machine path; the standards-track signal remains reserved as OQ-X8 in [`docs/spec-open-questions.md`](spec-open-questions.md) and this gate does not resolve it | marketplace/indexer display evidence bundle | mandatory |
| Collection metadata | metadata contract plus metadata satellites | typed v1 fields, generic records, locks, snapshots, aggregate function-count and bytecode ceiling; token content roots publishable and verified pre-finality ([CMC-CONTENT-ROOT]); per-lane record-chain accumulators ([CMC-RECORD-CHAIN]) | schema and snapshot manifests, metadata aggregate ABI/bytecode report | mandatory |
| Owner records | `StreamOwnerRecords` | ownerOf-gated, signature-verified, append-only owner families (`ACCESSION`, `CONDITION_REPORT`, `EXHIBITION`, `LOAN`, `DEACCESSION`, `CITATION`), `TITLE_BINDING` schema, firewalled from render/finality/economics ([CMC-OWNER-RECORDS]); record-family grant-set verification across all genesis satellites — the CON-015 whole-module writer exception is retired ([CMC-AUTHZ], [AA-RECORDS]; ADR 0010 decision D2.8) | owner-records module manifest, grant map artifact | mandatory |
| Preservation records | `StreamPreservationRecords` | PREMIS-style event/object/agent/right records, fixity hash validation, event reconstruction, post-freeze record behavior | preservation module manifest, schema hashes, code hash | mandatory |
| Collection attestations | `StreamCollectionAttestations` | C2PA/EIP-712/ERC-1271-compatible attestations, onchain verification at write for signer-verified classes, signer authority, supersession, event reconstruction ([CMC-ATTESTATIONS]) | attestation module manifest, schema hashes, code hash | mandatory |
| Collection views | `StreamCollectionViews` | IIIF/view URI commitments, accessibility/display view references, bounded reads, event reconstruction | view module manifest, schema hashes, code hash | mandatory |
| Entropy fallback provider | entropy coordinator, reviewed fallback provider | reviewed ARRNG or Pyth fallback provider shipped alongside VRF (ADR 0009 decision 21); VRF-only deployment fails this gate; coordinator failure mode matches the retained decision manifest | checksum-covered `release-artifacts/latest/entropy-launch-decision.json` or equivalent release-manifest record | mandatory |
| Artwork finality | Core plus satellites | typed finality preimage, pointer race, `verifyFinality`; token content root recorded before any finality in every metadata mode ([CMC-CONTENT-ROOT]); `REFERENCE_RENDER` component with capture-environment manifest for script-based works ([MRR-FINALITY]); `ARTIST_SANCTION` or `PLATFORM_WORKS_DECLARATION` component verified ([AA-SANCTION], [AA-PLATFORM]); artist intent record or recorded waiver ([CMC-ARTIST-INTENT]); dual-family archival receipts plus passing per-family fixity records for every finality-referenced offchain payload ([LTA-ARCHIVE]); collection scope requires `CLOSED` plus the one-way burn block (ADR 0010 decision D10.5) | finality manifest | mandatory |
| Governed gas parameters | every GGP host (Core, factories, coordinator, router, registries) | per parameter: immutable floor enforced; staged raise plus raise-only emergency path; lower requires a recorded passing health probe at the proposed value and can never cross the floor; change events with old/new values; excluded from finality manifests, frozen-route identity, and economic preimages — all per the pattern home ([LTA-GGP]; ADR 0010 decision D1) and its full inventory | GGP inventory with genesis values and floors in the release manifest, repricing review checklist | mandatory |
| Governance | governance/timelock, role registry | no single EOA, role map cardinality, delays; canonical action ID and atomic batch execution ([GOV-ACTION-ID], [GOV-BATCH]); window floors and dedicated unpause role ([GOV-WINDOWS]); long-lived authorities are role references resolved through the admin registry, not raw addresses (ADR 0010 decision D7.4); entropy-provider operational authorities contract-held with rehearsed rotation ([EP-CUSTODY]) | genesis governance manifest, governance action policy catalog | mandatory |
| Collector gas budget | both paid mint paths, genesis sale adapters | measured all-cold end-to-end collector transaction gas for `PRE_REVENUE_SINGLE_STEP` and `PREPARED_MINT` (single and batch of 10), free allowlisted mint, fixed-price and Dutch purchases, each inside its stated envelope ([MPA-GAS-BUDGET]; ADR 0010 decision D5.10); measured ERC-721 enumerable per-mint and per-transfer overhead recorded per [LTA-TRADEOFFS] item 2 (ADR 0010 decision D9.3) | checksum-covered gas budget artifact | mandatory |
| Fixity program | preservation records, operations | mandated fixity schedule (annual full sweep, quarterly sampling), `FIXITY_CYCLE_COMPLETED`/`FIXITY_FAILURE` records, repair-from-mirror and escalation policy ([CMC-FIXITY-PROGRAM]; ADR 0010 decision D6.3) | deployment-gated fixity operations manifest | mandatory |
| Reconstruction client | archival reconstruction client | client exists at genesis and rebuilds every [PV1-RECON] item from events alone; source-archive hash matches `streamSystemManifest().reconstructionClientHash`; replay test vectors pass in CI; reproducible-build instructions verified (ADR 0010 decision D4.8) | client source archive hash, replay vector artifact, drill cadence in ops runbook hashes | mandatory |
| Funding manifest | operations | published funding/endowment manifest naming the source, coverage horizon, and exhaustion alarms for keepers, entropy fees, storage mirrors, fixity cycles, and drills; each recurring obligation names its funded operational owner (ADR 0010 decision D4.8) | checksum-covered funding manifest | mandatory |
| Claim aggregation | claim router periphery | permissionless `claimMany`/`syncAndClaimMany`, release-to-self only, continue-on-failure mode, one-transaction aggregated claiming across at least 20 wallets ([RSR-CLAIM-ROUTER]; ADR 0010 decision D10.6) | claim router manifest | mandatory |
| Events | every subsystem | event reconstruction, supersession map | event catalog hash | mandatory |
| Operations | monitoring/export/storage | degraded-admin test, state export with metadata/record-chain roots, storage redundancy, export cadence per the umbrella schedule | ops runbook hashes | mandatory |

## Genesis Deployment Profile

Requirements [LCM-GENESIS]:

Genesis is the smallest system consistent with the owner-ratified
permanence and flexibility posture (ADR 0010 decision D9.1); it is not a
minimal system, and this profile states the full cost honestly. Every
entry below names the concrete genesis deployment; a parenthesized
interface is the Permanent surface that deployment must satisfy. An
interface with no concrete deployment, or a required gate whose contract
is absent from this list, is a matrix violation. This inventory is
exhaustive: 33 deployable production contracts, plus per-collection split
wallets created on demand by `CREATE2` through the factory. Governed Gas
Parameter stores are storage surfaces of the listed contracts (Core and
the split factory parameter store), not separate deployments; the mock
entropy provider exists only in local validation and never deploys to
production.

Mandatory genesis contracts:

```text
 1 StreamCore
 2 StreamGovernance or equivalent ADR 0004 timelock/role layer
 3 StreamModuleRegistry (canonical IStreamModuleRegistry)
 4 StreamRevenueResolver (IStreamRevenueResolver)
 5 StreamSplitFactory (IStreamSplitFactory)
 6 StreamSplitWallet clone implementation (IStreamSplitWallet)
 7 StreamRevenueEscrow (IStreamRevenueEscrow)
 8 StreamAssetPolicyRegistry (pinned immutably by the split factory)
 9 StreamPrimarySaleSettlement
10 StreamClaimRouter (IStreamClaimRouter, [RSR-CLAIM-ROUTER])
11 StreamMintManager
12 StreamMintLedger
13 StreamMintTicketGate (signed mint-ticket gate module, [MPA-TICKET]
   EIP-712 verifier)
14 StreamFixedPriceSaleAdapter
15 StreamEnglishAuctionHouse
16 StreamDutchAuctionAdapter
17 StreamPrivateSaleAdapter
18 StreamBurnMintGate
19 StreamDelegateRegistryGate
20 ERC-20 primary settlement adapter for approved standard assets
21 StreamArtistRegistry
22 StreamMetadataRouter
23 StreamRendererV1
24 StreamCollectionMetadata
25 StreamSchemaRegistry (schema and canonicalization registry satellite,
   [CMC-SCHEMA-REGISTRY])
26 StreamOwnerRecords
27 StreamPreservationRecords
28 StreamCollectionAttestations
29 StreamCollectionViews
30 StreamEntropyCoordinator
31 StreamEntropyProviderVRF (Chainlink VRF primary provider adapter)
32 StreamEntropyProviderARRNG or StreamEntropyProviderPyth (reviewed
   fallback provider adapter; VRF-only deployment is not conformant)
33 StreamArtworkFinalityRegistry with the full scope set: COLLECTION,
   TOKEN, RELEASE, SEASON, VIEW (ADR 0009 decision 6)
```

`StreamModuleRegistry` is the single module registry instance (ADR 0010
decision D10.2): it implements the canonical merged record shape defined
once in [`docs/stream-long-term-architecture.md`](stream-long-term-architecture.md)
(Registry Pattern) and serves satellite pointer eligibility, mint gate and
counter-resolver registration, and sale adapter/executor registration
([SSA-REGISTRY]); the mint spec's per-module `gasLimit` read is an
extension record on the same registry, not a second registry contract.
The auction contracts are inside the genesis conformance boundary: no
deployment may defer them, and no auction may run anywhere except through
the gate-covered genesis adapters.

Genesis audit plan (ADR 0010 decision D9.1): the release manifest must
include a published subsystem-by-subsystem audit plan artifact covering
every contract above — per-subsystem scope, audit ordering, auditor
identity or class, and completion evidence — and the deployment ceremony
fails while any subsystem lacks recorded audit completion. Recurring
operational obligations (fixity cycles, state exports, drills, funding)
each name their funded operational owner in the funding manifest gate.

Specified but optional-at-genesis surfaces (the only `conditional`
surfaces; each activates its own gate rows through its accepted ADR):

```text
Custom counter resolvers
Resolver-defined caps/deltas
Privacy nullifiers
CCIP Read and future onchain web adapters
Non-standard ERC-20 primary adapters
Sealed-bid and ranked auction implementations (frozen extension profiles)
StreamLabelRegistry (display-only label metadata; no accounting authority)
Additional institution-specific preservation, rights, VC/DID, EAS, or legal modules
```

Optional surfaces may be specified and reserved, but production bytecode must
not include callable dead paths for them before their ADR/test suite exists.
Scoped finality is not in the optional list: by protocol-owner decision
(ADR 0009 decision 6), the genesis finality registry ships every scope —
`COLLECTION`, `TOKEN`, `RELEASE`, `SEASON`, and `VIEW` — and each scope must
arrive with complete write/read/recovery tests, scopeId schema publication,
numeric-ID catalog entries, and event-catalog coverage. A scoped surface
without its full gate coverage fails this matrix exactly as a dead path
would.

The deployed Core should also publish a Core surface report: runtime bytecode size,
external/public function count, ERC-165 interface set, and selector manifest.
Target Core headroom is at least 2,000 bytes below the EIP-170 limit and a
function count small enough that every selector is permanent, documented, and
covered by a golden interface test. If Core cannot fit with Core-native
ERC-2981 and enumerable, move mutable policy to satellites rather than
expanding Core.

Core planning budget before implementation:

```text
Function group                                      priority    planning runtime bytes
ERC-721 ownership/approval/metadata/enumerable      permanent   7,000-9,000
Mint/burn/token identity/collection serials         permanent   3,000-4,500
Collection facts/status/supply reads and writes     permanent   2,000-3,000
Core-native ERC-2981 resolver read                  permanent     700-1,200
Bounded tokenURI router read/fallback/status        permanent   1,400-2,400
Bounded contractURI delegated read (ERC-7572)       permanent     300-600
Satellite pointer cached reads and governance hooks permanent   1,200-2,000
Core finality fact reads and lifecycle reads        permanent     700-1,200
Core-originated ERC-4906 refresh emitters           permanent     300-700
streamSystemManifest storage-only read              permanent     500-1,000
Successor declaration history                       medium        500-1,000
latestStateExport storage-only read                 medium        300-700
Prepared mint prepare/complete                      permanent     900-1,800
```

The 2,000-byte headroom target above is the governing deployment rule
(ADR 0009 decision 2); the bytecode-spend baseline and exception ledger in
`release-artifacts/contracts.json` remain the pre-deployment development
control, and interim exceptions cannot survive to the deployment gate.

If the measured build loses the 2,000-byte headroom, the priority order is:
every `permanent` row stays in Core — including `streamSystemManifest()` and
the prepared-mint pair, which are never relocation candidates (ADR 0010
decision D10.6; [MPA-CORE-ABI]) — then successor history and state export
publication move into a thin immutable discovery satellite that Core points
to through the same cached pointer policy.

Additional paid-mint/finality/escrow deployment tests:

1. Malicious ERC-721 receiver cannot observe an unpaid, unregistered,
   unsnapshotted, or unaccounted paid mint in either `PRE_REVENUE_SINGLE_STEP`
   or `PREPARED_MINT`.
2. Signed policy expecting token-level economics cannot use
   `PRE_REVENUE_SINGLE_STEP`.
3. A collection configured `ROYALTY_SNAPSHOT_AT_MINT` cannot bind to a
   single-step-only sale adapter.
4. Finality rejects mismatched manifest content hash, URI hash, component code
   hash, unsorted components, duplicate components, and missing `hasMaxSupply`.
5. Pointer replacement is blocked for frozen/finalized routes unless the new
   target proves frozen-route support or a recovery manifest has executed.
6. Escrow credits created before factory replacement flush through their stored
   factory.
7. ERC-1271 alternate-recipient release authorization is gas-capped and tested
   against a malicious contract wallet.
8. `PREPARED_MINT` exposes and verifies one canonical `operationId` across sale
   adapter, manager, ledger, Core prepare/complete, resolver snapshot, entropy
   registration, and escrow/deposit path.
9. Token-level primary and royalty snapshots taken during `PREPARED_MINT` are
   independent of entropy seed/status and renderer output.
10. Open-ended collections can finalize a token, release, season, or view scope
    without closing the parent collection, and frozen-route checks include the
    full scoped finality key.
11. Collection-level finality is impossible unless `CLOSED` makes
    `mintedSupply`, `burnedSupply`, and `nextCollectionSerial` immutable and
    the one-way collection burn block is set (ADR 0010 decision D10.5).
12. `royaltyInfo()` and `tokenURI()` gas budgets are independent top-level
    reads; no production helper combines both in one bounded staticcall frame.
13. Degraded-mode escrow tests document the condition that `flushEscrow`
    remains possible only while the current `FLUSH_GAS_FLOOR` Governed Gas
    Parameter is satisfiable; the parameter is raisable with an immutable
    floor ([RSR-GGP]), so the degraded condition is recoverable by
    governance rather than permanent.

## Static Analysis Gates

Requirements [LCM-STATIC]:

CI must fail if any production contract violates these checks:

1. `tx.origin` appears outside tests or explicit non-production mocks.
2. Core inherits `ERC2981` or contains `_setDefaultRoyalty`,
   `_setTokenRoyalty`, or equivalent royalty storage.
3. Authority or identity hashes use `abi.encodePacked` where the spec requires
   `abi.encode`.
4. A contract that can hold owed funds exposes unrestricted
   `emergencyWithdraw`.
5. Core stores script chunks, dependency chunks, randomizer pointers, token hash
   status, or primary-sale split percentages.
6. Resolver `royaltyReceiverAndBps` or any function it can reach contains
   `CALL`, `DELEGATECALL`, `STATICCALL`, `CREATE`, or `CREATE2` opcodes.
7. Any production instant entropy provider reachable from `requestEntropy`
   contains `CALL`, `DELEGATECALL`, `STATICCALL`, `CREATE`, or `CREATE2`,
   performs state writes, or exposes non-`view` `instantEntropy`.
8. Permissioned functions share a durable authorization selector or role key
   unless the shared role is intentionally documented in the role map.
9. Production interface selectors differ from the release selector manifest
   without an intentional manifest update and test review.
10. Production satellites that promise immutability or bounded reads contain
   `SELFDESTRUCT`, unrestricted `DELEGATECALL`, mutable proxy upgrade hooks, or
   unbounded returndata copies outside explicitly allowed test/migration mocks.
11. Production mint contracts compile callable `CUSTOM_RESOLVER`,
    resolver-defined cap/delta, or nullifier execution paths before the
    accepted ADR enables them. Reserved enum values may exist in manifests, but
    excluded call paths must be physically absent from production bytecode or
    blocked before any external call/state write by static checks.
12. The renderer or router `tokenURI` path contains environment or context
    opcodes — `TIMESTAMP`, `NUMBER`, `PREVRANDAO`, `BLOCKHASH`,
    `COINBASE`, `BASEFEE`, `GASLIMIT`, `GASPRICE`, `BALANCE`,
    `SELFBALANCE` — or any external read outside the pinned allowlist of
    Core identity, entropy view, and metadata storage reads
    ([MRR-DETERMINISM]; ADR 0010 decision D4.3). Renderer output must be a
    pure function of contract state and the render request; the pinned
    golden render vectors re-verify this at every preservation drill.

## Golden Interface Tests

Requirements [LCM-GOLDEN]:

CI must include small deterministic tests for production interfaces whose
accidental drift would break indexers, marketplaces, or satellite contracts:

1. `IStreamRevenueResolver.royaltyReceiverAndBps` has selector `0x54f77a09`
   for the exact signature
   `royaltyReceiverAndBps(address,uint256,uint256,uint256,bool)`.
2. Core reports `supportsInterface(0x2a55205a) == true` because the production
   build includes Core-native ERC-2981, and `royaltyInfo()` uses the same capped
   resolver path as `probeRoyaltyInfo()`.
3. `tokenCollectionIdentity(tokenId)` returns
   `(mappingExists, collectionId, collectionSerial, burned)` from Core storage,
   returns the retained collection mapping after burn, and never reconstructs
   collection identity from token ID ranges.
4. Safe mint receiver callbacks can observe a registered token with pending
   entropy, but cannot observe finalized entropy caused by the mint path.
5. `requestEntropy()` writes `REQUESTED` before touching any provider, rejects
   reentrant or duplicate requests, and finalizes synchronous `INSTANT` entropy
   only from the provider return data.
6. `fulfillEntropy()` rejects inactive, stale, wrong-provider, wrong-request,
   already-finalized, and reentrant fulfillment attempts before any external
   refresh or notification.
7. Every production external/public selector appears exactly once in the
   selector manifest with owner subsystem, interface name, mutability, and
   authorization model. Selector collisions are allowed only for standard
   interface overrides that intentionally share the same signature.
8. Event catalog CI proves every replacement event has `supersedes` /
   `replacedBy` links, every archived event remains present forever, and no
   indexed field set changes without a replacement event.
9. Governance tests prove the production contracts enforce only the ADR 0004
   two-tier model plus named exception floors; the richer action-class taxonomy
   is manifest/runbook vocabulary until a later ADR implements it onchain.
10. Governance tests cover `governanceAction(actionId)`, virtual or materialized
    expiry, the terminal-freeze veto path ([LTA-FREEZE] rule 4;
    [GOV-WINDOWS]), complete scheduled/executed/cancelled/vetoed
    event payloads, and replay protection through nonce/action ID.
11. `IStreamCorePointerView.getSatellitePointer` returns target, code hash,
    freeze state, module type, interface ID, registry address, registry status,
    module manifest hash, and deployment manifest hash.
12. `IStreamModuleRegistry` rejects unknown, deprecated-for-new-use, malformed,
    and incident-revoked modules for new pointer assignments.
13. Cross-contract authority selectors are pinned with golden ABI tests, and
    selector-stable value-type or `bytes32` parameters are preferred for
    authority-critical interfaces.
14. The deployment manifest contains `compatibilityMatrixHash`, event catalog
    hash, numeric ID allocation hash, and reproducible-build artifact hashes for
    every deployed satellite.
15. A collection on a single-step-only mint path cannot select a renderer that
    requires renderer-visible `tokenData` bytes before the recipient callback.
16. `PRE_REVENUE_SINGLE_STEP` with any `RECIPIENT`-keyed counter requires
    `initialRecipients[i] == beneficiaries[i]` for each element and
    otherwise reverts with `MintSingleStepRecipientMismatch(index)`. This
    golden test exercises `StreamMintManager`: the manager is the single
    enforcement point for recipient-owner equality
    ([`docs/mint-policy-and-accounting.md`](mint-policy-and-accounting.md)
    [MPA-SINGLE-STEP]); sale adapters may pre-screen but their checks are
    not the conformance locus.
17. A finalized collection-scope artwork recovery that affects more than
    `MAX_REFRESH_RANGE` tokens emits chunked `BatchMetadataUpdate` events with
    the same recovery reason hash and never emits one oversized range.
18. A minted token whose pinned entropy coordinator has no code, reverts, is
    incident-revoked, or returns malformed data renders pending/unknown
    metadata rather than reverting `tokenURI()`.
19. Core calls `onTokenMinted` forwarding the current
    `ENTROPY_REGISTRATION_GAS_LIMIT` Governed Gas Parameter — immutable
    floor, staged raise with a raise-only emergency path, probe-gated
    lower, change events, per
    [`docs/stream-entropy-coordinator.md`](stream-entropy-coordinator.md)
    [EC-REGGAS] — with an EIP-150-aware parent gas precheck that reads the
    live value, measured deployment margin, and mint revert on
    registration failure; the GGP raise plus replaceable coordinator
    pointer recovery chain is tested (ADR 0010 decision D1.5).
20. CI asserts every production event in the event catalog has at most three
    `indexed` fields, matching the Solidity log topic limit.
21. Golden tests assert numeric enum values for `TokenURIReadStatus`,
    `StreamTokenLifecycle`, `EntropyStatus`, `EntropyFulfillmentOutcome`,
    `EntropySecurityClass`, `ProviderResultStatus`,
    `ModuleRegistryStatus`, `AuthorizerKind`, asset policy statuses,
    `AttributionState`, `ArtistConsentMode`, `ArtistAuthorityClass`,
    `CollabPolicyMode`, `SaleKind`, `DutchDecayKind`, finality scope
    types, and recovery statuses match the manifest-pinned Numeric ID
    Catalog.
22. Any satellite function reachable during `PREPARED_MINT`, including resolver
    snapshot hooks, escrow/deposit paths, and entropy registration helpers,
    reads or re-verifies Core `preparedMint(tokenId).operationId` and reverts
    on mismatch before any state write or external call.
23. Catalog or pointer updates that change `streamSystemManifest()` fields must
    update Core's cached manifest/catalog hashes atomically in the same
    governed execution; tests fail if registry/catalog publisher state drifts
    from Core's cached discovery fields.
24. Core's restricted ERC-4906 refresh emitters accept exactly the
    caller set pinned by the protocol v1 Core hook table — the metadata
    router, the artwork finality registry, and the entropy coordinator,
    each resolved through Core's cached satellite pointers — and revert
    for every other caller, including admins and superseded pointer
    values (ADR 0010 decision D3.6).
25. Every enum literal named in this matrix — including the lifecycle
    reconciliation matrix and the Numeric ID Catalog coverage list —
    appears verbatim in the owning spec's enum definition; CI fails on
    any literal (such as a status name) that no home document defines.

## Current-Code Contradictions

The baseline code must be rewritten or replaced before any production
deployment where it conflicts with this matrix:

1. `StreamCore` inherits OZ `ERC2981` and sets a hardcoded default royalty.
2. `StreamDrops` uses `tx.origin`, push payments, and packed/string hashes.
3. `StreamMinter` participates in token ID construction through namespaced
   ranges.
4. Core metadata/script/randomizer logic remains embedded in Core.
5. Entropy is registered after `_safeMint` and uses zero hash sentinel state.
6. `StreamAdmins` is selector-based and lacks timelocks, staging, and role
   constants.
7. Emergency withdraw functions can sweep balances without owed/surplus proof.
8. `freezeCollection` is not cross-module artwork finality.
9. `StreamCuratorsPool` push payments or unrestricted sweeps are not
   deployment-conformant if the pool holds owed rewards.

## Event Catalog Schema

Requirements [LCM-EVENTS]:

Every release must include a machine-readable event catalog canonicalized with
RFC 8785/JCS. The catalog is generated before any document enters Review
(Review-Entry Conditions above), not at deployment time, so golden event
tests always have an authoritative target:

```json
{
  "schema": "6529.stream.event-catalog.v1",
  "chainId": 1,
  "deployment": "0x...",
  "events": [
    {
      "signature": "EventName(uint16,uint256,bytes32)",
      "topic0": "0x...",
      "schemaVersion": 1,
      "owner": "revenue",
      "status": "active",
      "indexed": ["collectionId", "profileId"],
      "unindexed": ["schemaVersion", "amount"],
      "supersedes": [],
      "replacedBy": null,
      "semanticsURI": "ipfs://...",
      "semanticsHash": {
        "algorithm": "KECCAK256",
        "digest": "0x..."
      }
    }
  ]
}
```

New events either include `uint16 schemaVersion` or have immutable v1 semantics
pinned in this catalog. Event replacements must use `supersedes` and
`replacedBy`; old events remain in the catalog forever with `status: archived`
and are never reinterpreted.
The v1 catalog must explicitly list standard-event exemptions where the event
signature cannot include `schemaVersion`, including ERC-721 `Transfer`,
`Approval`, `ApprovalForAll`,
ERC-4906 `MetadataUpdate` / `BatchMetadataUpdate` if emitted with their
standard signatures, and ERC-7572 `ContractURIUpdated()` (ADR 0010
decision D10.6).
Any non-standard event snippet elsewhere in the specs that omits
`schemaVersion` is shorthand, not permission to omit it from the production ABI. The
event catalog and golden event tests are authoritative.

## Numeric ID Catalog

Requirements [LCM-IDS]:

Every enum-like numeric value that crosses contract, indexer, or manifest
boundaries must be assigned in a manifest-pinned numeric ID catalog. The v1
catalog must cover at least module registry states, governance action classes
and statuses, freeze modes, collection statuses, supply modes, entropy
statuses, entropy fulfillment outcomes (including
`REJECTED_PROVIDER_REVOKED = 5`), entropy security classes
(`HIGH_ASSURANCE = 0`, `LOW_SECURITY = 1`), provider result statuses,
asset policy statuses (`UNKNOWN = 0`, `ACTIVE = 1`, `INACTIVE = 2`,
`DEPRECATED = 3`, `UNSUPPORTED = 4`, home [RSR-ASSET-POLICY]),
authorizer kinds ([MPA-AUTHZ]), sale and Dutch-decay kinds (sales spec),
English-auction lifecycle states and refund-window purchase states
(sales spec [SSA-ENGLISH] state machine and [SSA-REFUND]),
attribution states, artist consent modes, artist authority classes, and
collaborator policy modes
([`docs/stream-artist-authority.md`](stream-artist-authority.md)),
owner-record family constants (`ACCESSION`, `CONDITION_REPORT`,
`EXHIBITION`, `LOAN`, `DEACCESSION`, `CITATION`; home
[CMC-OWNER-RECORDS]), schema statuses, hash algorithms, canonicalization
IDs, source/storage types, token URI read statuses, finality scope types,
and recovery statuses. IDs may be deprecated but not reinterpreted.
The Numeric ID Catalog has its own schema version, schema URI/hash,
canonicalization ID, and supersedes-catalog hash. Updating the catalog format
is a catalog supersession, not a mutation of old IDs.

Lifecycle reconciliation matrix — a checker-verified mirror of the
lifecycle mapping home in
[`docs/stream-entropy-coordinator.md`](stream-entropy-coordinator.md)
([EC-LIFECYCLE]); on any conflict the home wins (ADR 0010 decision D3.1):

```text
Token condition        StreamTokenLifecycle     TokenURIReadStatus     EntropyStatus
nonexistent            UNKNOWN                  NONEXISTENT            NONE
prepared incomplete    PREPARED_INCOMPLETE      PREPARED_INCOMPLETE    NONE (no record)
minted pending         MINTED                   OK                     REGISTERED/REQUESTED/STALE/FAILED
minted non-random      MINTED                   OK                     terminal DISABLED/NOT_REQUIRED
minted finalized       MINTED                   OK                     FINALIZED
burned                 BURNED                   BURNED                 retained last written entropy status
```

`EntropyStatus` has no `UNKNOWN` member. `REGISTERED` and the terminal
`DISABLED`/`NOT_REQUIRED` records are written only by `onTokenMinted` at
completion, so a prepared-incomplete token has no coordinator record:
`tokenEntropy` discloses that condition or reverts, and consumers treat
either as pending ([EC-LIFECYCLE]). Mirrors and indexers must not invent
values. Golden test 25 enforces that every literal above exists in the
owning enum definition. The numeric ID catalog pins values independently
for each enum; indexers must not assume the same word has the same
numeric value across different enum families.

## Indexed Field Policy

Requirements [LCM-INDEXED]:

Indexed event fields are part of Stream's long-term query contract. Every
production event must classify each field as indexed or unindexed in the event
catalog and explain the reconstruction purpose for indexed fields. Required
indexed field families:

1. `collectionId` on collection, metadata, mint, entropy, finality, and
   collection-scoped revenue events.
2. `tokenId` on token identity, token metadata, entropy, burn, and
   token-scoped revenue events.
3. `profileId` or `wallet` on split-wallet, escrow, release, and revenue
   events where the payee profile is material.
4. `revenueClass` on primary and royalty assignment, escrow, and settlement
   events.
5. `operationId` or `actionId` on governance staging, cancellation, execution,
   and recovery events.

Changing an indexed field set after deployment is an event replacement, not a
semantic edit. The new event must supersede the old one in the event catalog.
