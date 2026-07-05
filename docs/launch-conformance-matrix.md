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

These conditions are also the honesty boundary of the spec set's own
claims (ADR 0012 decision T9): until they hold — and until the gates
below pass on a measured implementation — every best-in-class statement
in these documents is a design-complete, pending-verification claim,
never a verified-in-production one, and the documents must say so
wherever they compare themselves to deployed systems. The traceability
artifact and the event catalog are inputs to review, generated while
the documents are still Draft; they are never deployment-ceremony
outputs. The Core planning-budget arithmetic is proven the same way:
the named Core size reconciliation workstream (Genesis Deployment
Profile below) publishes its first passing measured build as release
evidence rather than deferring the proof to the deployment gate.

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
| Sales and auctions | genesis sale adapters and gate modules per [`docs/stream-sales-and-auctions.md`](stream-sales-and-auctions.md) | the full [SSA-GATES] suite set — the home owns the authoritative suite count and membership, and a row naming fewer suites than the home defines is a defect: English auction (reserve, increment floor, anti-snipe extension and cap, CEI, idempotent settlement, pull refunds, first-bid-starts, mint-at-settlement custody branch with the auction-creation artwork commitment, ADR 0012 decision T6), Dutch (schedule determinism, clearing, rebate conservation, maximum-price purchase with pull-credited excess), refund-window custody with drift-envelope refund unlock ([SSA-ENVELOPE]; ADR 0011 decision R6), burn-to-mint (retained-identity proof, manager-scoped nullifiers, finality interaction refusals), delegate gate, content selection (commit-reveal default), ERC-4337 + paymaster end-to-end run, registry governance, static analysis, gas budget, event reconstruction, pause tolling and no-confiscation, price kinds (zero-price, pay-what-you-want, custody inventory with `CUSTODY_SETTLEMENT_TRANSFER` ordering, [RSR-SETTLEMENT-BOUNDARY]), reveal fees, replay locus with custody-path offer/authorization revocation mechanics (ADR 0011 decision R9; ADR 0012 decision T6), the adapter escrow conservation suite (ADR 0012 decision T7), the contest-stop suite (ADR 0012 decision T4), the consignment and custody-grant suite — owner-signed single-use grants revocable until sale, settling as secondary transfers with itemized royalty delivery, never as primary revenue (ADR 0012 decision T6) — and the artist sale-parameter consent suite (ADR 0012 decision T4); airdrop batch distribution runs inside the price-kind suite and the by-construction standing envelope for public at-price purchases inside the refund-window suite ([SSA-ENVELOPE] rule 6; ADR 0012 decision T6); raffle allocation and the content-consumption registry remain frozen extension recipes without genesis bytecode (sales spec exclusions) | sale/auction state-machine manifests, adapter registry manifest | mandatory |
| Collection management | Core collection boundary | create/status/max-supply events and transitions | collection facts schema | mandatory |
| Token identity | Core mint boundary, `tokenCollectionIdentity` | Core-owned token allocation, collection serial mapping, mapping-existence read, prepared-incomplete identity read, burn retained mapping; `TokenCollectionRegistered` — schemaVersioned, production signature pinned at its home [MPA-CORE-ABI] (ADR 0011 decision R12) — emitted at identity write and event-only replay rebuilds the full mapping (ADR 0010 decision D10.1; protocol v1 [PV1-RECON].9) | token identity schema | mandatory |
| Token-level metadata | collection metadata satellite | token data/field overrides, token locks, burned archival reads | token metadata schema | mandatory |
| Burn | Core burn boundary | owner/approved, mapping retained, finalized burn blocked, one-way collection burn block readable for finality ([CMC-BURN]; ADR 0010 decision D10.5) | burn policy manifest | mandatory |
| Mint accounting | mint manager, ledger, `StreamMintTicketGate` | duplicate-key aggregation, static caps, signed ticket binding; reentrancy guard on `mint()` and prepared entrypoints; `registerPhasePolicy` binds `msg.sender` to its manager argument; gate calls forward `max(gateGasLimit, MINT_GATE_GAS_LIMIT)` with returndata/nullifier bounds ([MPA-GATES]); `AuthorizerKind` enforcement with zero-`ecrecover` and non-canonical-signature negatives ([MPA-AUTHZ]); zero-increment rejection; manager-scoped nullifiers; Merkle allowlist cap mode ([MPA-MERKLE]); `GLOBAL` counter scope with reserved-constant `(0, 0)` derivation goldens ([MPA-SCOPES]); counter-continuity import ([MPA-CONTINUITY]); policy grace windows ([MPA-GRACE]); ticket revocation | policy hash schema | mandatory |
| Artist authority | `StreamArtistRegistry` plus consuming satellites | the fourteen [AA-GATES] suites: two-sided binding, sanction-required finality, consent modes (including signature-free pause in every attribution state, ADR 0011 decision R6), economics consent and royalty freeze, signature verification (ERC-1271, GGP probes, per-identity unordered nonces), key lifecycle (rotation contest windows, guardians, identity recovery, permissionless estate activation, dormancy), disputes and platform-works contests, attribution display, record-family write authority, identity archival, content authority, recovery approval, ceremony tooling, and history import (the [AA-IMPORT] commit-verify-cutover round-trip; ADR 0012 decision T4) — the ceremony-tooling suite (gate 13) is verified through the Artist ceremony rehearsal gate row below | artist registry manifest, consent/sanction schema hashes | mandatory |
| Artist ceremony rehearsal | artist signing tool and rehearsal deployment over `StreamArtistRegistry` plus consuming satellites | the full [AA-TOOLING] suite (ADR 0011 decisions R7.7 and R12): named signing tool renders a human-readable summary of every typed payload family before signature; rehearsed end-to-end onboarding through mint and finality sanction with total ceremony count and per-ceremony signing latency recorded and verified at or below the normative ceremony budget pinned at [AA-TOOLING] rule 6 — `ARTIST_CEREMONY_MAX_SIGNATURES` and `ARTIST_CEREMONY_MAX_ACTIVE_SIGNING_MINUTES` for the canonical single-artist collection's EOA leg, release-evidence ceilings the gate fails on exceeding and only an ADR may raise (ADR 0012 decision T9); the rehearsal includes at least one artist identity held by a Safe-class ERC-1271 contract wallet completing the full ceremony chain from acceptance through sanction, with its per-ceremony latency recorded separately and the signing tool's supported wallet classes stated in the artifact (ADR 0012 decision T5); consent-churn drift detection and stale-ceremony invalidation; independent operator-free hash recomputation tool; estate/dormancy paths exercised to staging; plus the artist's recorded acknowledgment of the disclosure-only royalty term (protocol v1 [PV1-EXCL] item 1) captured during rehearsal | checksum-covered artist ceremony rehearsal artifact per [AA-TOOLING]: tool name, version, and build hash; payload summaries; ceremony-count and latency measurements with budget compliance; contract-wallet ceremony record and supported wallet classes; acknowledgment record | mandatory |
| Entropy lifecycle | entropy coordinator, provider | identity written and entropy registered before `_safeMint` callback; non-reentrant request/fulfill; single active request; no instant provider calls from mint path; `ENTROPY_REGISTRATION_GAS_LIMIT` GGP semantics ([EC-REGGAS]); `maxFeeWei` binding with pull-credit refunds ([EC-FEEBIND]); callback persistence and retry ([EP-CALLBACK]); `INSTANT` restricted to declared `LOW_SECURITY` collections; lifecycle mapping matches [EC-LIFECYCLE]; the scope-request suite ([EC-SCOPE]: registration, async-only lifecycle parity, incident recovery, commitment finality) and the reveal suite ([EC-REVEAL]: mandatory `ASYNC` reveal policy at freeze, `AT_MINT` attempt-and-catch never unwinding a mint, SLO-lapse permissionless fallback, escrow-first fee draw) per ADR 0011 decision R8; incident evidence gate ([EC-INCIDENT] rule 3 three-part check) | entropy policy manifest; measured `fulfillEntropy` gas envelope with callback margin and `VRF_CALLBACK_GAS_FLOOR` record; reveal operations manifest (owner, float, exhaustion alarms, keeper obligation, latency target — the reveal SLO and every subsystem obligation window sized against the holder's recorded worst-case latency per the [LTA-GOV] rule 6 discipline, ADR 0012 decision T5 — plus the live escrow-versus-quoted-fee margin alarm with its named top-up obligation and the post-freeze `updateRevealFeePerToken` remedy path, [EC-REVEAL] rules 8–9, ADR 0012 decision T7; rehearsal evidence) | mandatory |
| Metadata routing | metadata router, renderer | escaping, size limits, router failure behavior, ERC-4906 auth; renderer determinism static gate against each renderer version's declared read set — `STATIC` default or declared `DYNAMIC` class — and pinned golden render vectors ([MRR-DETERMINISM]; ADR 0011 decision R3); full-view and paged-chunk byte identity ([MRR-FULL-VIEW]); attribution-mirror checker — the rendered `properties.provenance.attribution` object matches the [AA-DISPLAY] home field-for-field through the [MRR-ATTRIBUTION] citation mirror, retired flat fields absent (ADR 0011 decision R7.6); offchain-mode pre-sale content binding and the `OFFCHAIN_PRESERVATION_COVERAGE_SECONDS` coverage-deadline monitored gate ([MRR-OFFCHAIN-BINDING]; ADR 0011 decision R2) including the sold-token lane of open collections — dual-family receipts (one `ENDOWED`) plus fixity coverage within the pinned window of each token's sale, not of collection close (ADR 0012 decision T2) | renderer and context manifests, golden render vector artifact | mandatory |
| Contract metadata | Core `contractURI()` delegation, contract-metadata satellite | ERC-7572 `contractURI()` bounded delegated read, satellite pointer, failure fallback, `ContractURIUpdated()` emitter caller set exactly as pinned at the protocol v1 Core hook table — the current metadata router resolved through Core's cached pointer, enumerated by golden test 24 (ADR 0012 decision T9; ADR 0009 decision 4) | contract-metadata manifest, selector test | mandatory |
| Marketplace collection display | collection discovery machine path ([MRR-COLLECTION-DISCOVERY]) | evidence bundle validates against [LCM-MARKETPLACE]: one schema-valid entry per pinned target per launch artist series, each demonstrating own-collection resolution (rule 3) through the published machine path; every entry backed by a standing signed integration commitment or a dated re-verification cadence (rule 6; ADR 0012 decision T9); any missing pair or mismatched entry fails the gate (ADR 0011 decision R12); the standards-track signal remains reserved as OQ-X8 in [`docs/spec-open-questions.md`](spec-open-questions.md) and this gate does not resolve it | checksum-covered marketplace-target manifest and display evidence bundle ([LCM-MARKETPLACE]) | mandatory |
| Marketplace royalty resolution | Core-native ERC-2981 read path plus per-target royalty plumbing ([LCM-MARKETPLACE] rule 4) | per pinned target per launch artist series: hash-pinned evidence that the target's resolved receiver and bps match a live `royaltyInfo()` read at capture time; the shared royalty-registry entry is recorded (address and registration transaction) for targets that resolve shared contracts through it, and per-marketplace royalty configuration state is recorded for targets that do not (ADR 0011 decision R12); every entry backed by a standing signed integration commitment or a dated re-verification cadence (rule 6; ADR 0012 decision T9) | royalty-resolution entries in the marketplace evidence bundle ([LCM-MARKETPLACE]) | mandatory |
| Collection metadata | metadata contract plus metadata satellites | typed v1 fields, generic records, locks, snapshots, aggregate function-count and bytecode ceiling; token content roots publishable and verified pre-finality ([CMC-CONTENT-ROOT]); per-lane record-chain accumulators ([CMC-RECORD-CHAIN]); the sixteen pinned genesis schemas present with matching IDs and hashes, worked examples validating ([CMC-GENESIS-SCHEMAS]; ADR 0011 decision R11; ADR 0012 decision T8); PREMIS crosswalk export round-trip ([CMC-PREMIS-PROFILE]); artist content-consent and content-freeze enforcement on content-affecting families ([CMC-ARTIST-CONTENT-VETO]; ADR 0011 decision R7.2) | schema and snapshot manifests, metadata aggregate ABI/bytecode report | mandatory |
| Owner records | `StreamOwnerRecords` | ownerOf-gated, signature-verified, append-only owner families (`ACCESSION`, `CONDITION_REPORT`, `EXHIBITION`, `LOAN`, `DEACCESSION`, `CITATION`), `TITLE_BINDING` schema, firewalled from render/finality/economics ([CMC-OWNER-RECORDS]); record-family grant-set verification across all genesis satellites — the CON-015 whole-module writer exception is retired ([CMC-AUTHZ], [AA-RECORDS]; ADR 0010 decision D2.8) | owner-records module manifest, grant map artifact | mandatory |
| Preservation records | `StreamPreservationRecords` | PREMIS-style event/object/agent/right records, fixity hash validation, event reconstruction, post-freeze record behavior | preservation module manifest, schema hashes, code hash | mandatory |
| Collection attestations | `StreamCollectionAttestations` | C2PA/EIP-712/ERC-1271-compatible attestations, onchain verification at write for signer-verified classes, signer authority, supersession, event reconstruction ([CMC-ATTESTATIONS]); artist-attestation surface field inventory matches the [AA-ATTEST] home through the [CMC-ARTIST-ATTESTATION] checker row; independent-attestor lanes — permissionless entry, signer-verified writes under `STREAM_INDEPENDENT_PRESERVATION_TYPEHASH`, firewall, unblockability with locks/freezes/finality present ([CMC-INDEPENDENT-ATTESTOR]; ADR 0011 decision R11); `METADATA_ERC1271_VERIFY_GAS` floor/raise/lower/probe tests on every verifying metadata satellite ([CMC-SIGVER-GGP]; ADR 0011 decision R10) | attestation module manifest, schema hashes, code hash | mandatory |
| Collection views | `StreamCollectionViews` | IIIF/view URI commitments, accessibility/display view references, bounded reads, event reconstruction | view module manifest, schema hashes, code hash | mandatory |
| Entropy fallback provider | entropy coordinator, reviewed fallback provider | reviewed ARRNG or Pyth fallback provider shipped alongside VRF (ADR 0009 decision 21); VRF-only deployment fails this gate; coordinator failure mode matches the retained decision manifest | checksum-covered `release-artifacts/latest/entropy-launch-decision.json` or equivalent release-manifest record | mandatory |
| Artwork finality | Core plus satellites | typed finality preimage, pointer race, `verifyFinality`; token content root recorded before any finality in every metadata mode ([CMC-CONTENT-ROOT]); `REFERENCE_RENDER` component for script-based works with capture-environment manifest, archived runnable execution-environment artifact under dual-family fixity coverage, and exactly one pinned acceptance mode — `BYTE_EXACT` only with pinned software rasterization, `DYNAMIC`-class renderers excluded from `BYTE_EXACT` ([LTA-FINALITY] requirement 12, [CMC-FINALITY-INPUTS], [MRR-FINALITY]; ADR 0011 decision R3); `ARTIST_SANCTION` or `PLATFORM_WORKS_DECLARATION` component verified ([AA-SANCTION], [AA-PLATFORM]); artist intent record with interview reference or recorded waiver ([CMC-ARTIST-INTENT]; ADR 0011 decision R11); rights record present for artist-bound collections ([CMC-RIGHTS-SCHEMA]; ADR 0011 decision R11); dual-family archival receipts with schema-valid evidence classes — at least one cryptographically verifiable receipt per payload, operator assertion alone rejected, at least one `ENDOWED` family per render-critical payload — plus passing per-family fixity records from a verifier distinct from the writer ([LTA-ARCHIVE], [CMC-RECEIPTS]; ADR 0011 decision R4); collection scope requires `CLOSED` plus the one-way burn block (ADR 0010 decision D10.5) | finality manifest | mandatory |
| Governed gas and time parameters | every GGP/GTP host (Core, factories, coordinator, router, registries, satellites) plus the Permanent-class probe contracts ([LTA-GGP-PROBES]) | per gas parameter, the [LTA-GGP] requirement 9 suite (ADR 0011 decision R5; ADR 0012 decision T1): immutable floor enforced; staged raise on the normal delay class with the 2x per-action raise bound rejected above it; emergency raise probe-gated (healthy probe record blocks, recorded failing run at the current value admits); lower requires a recorded passing probe run at exactly the proposed value within `probeMaxAgeBlocks` through the named probe contract and can never cross the floor; permissionless conditional raise executed with no governance signer for every `FORWARDING_CAP` parameter, plus the scope-rejection test proving no conditional-raise action exists — or that its execution reverts — for every `FAIL_CLOSED_PRECHECK` and `MIN_GAS_GATE` parameter, whose raises are governance-only; the forged-failure probe-integrity test — an under-funded or input-shaped probe call reverts without recording a failing run, probes execute only their pinned per-parameter input corpus, and probe-run records live on the probe contract ([LTA-GGP-PROBES] rules 3–5); the zero-governance-signer museum-mode drill executing the probe-and-conditional-raise chain end to end against the deployed probes ([LTA-GGP-PROBES] rule 9); per Governed Time Parameter, the [LTA-GTP] discipline suite — floor rejection against both block and wall-clock floors, per-action raise and lower bounds, cadence-probe-gated lower, change events, and the negative test that no emergency or permissionless conditional path exists (ADR 0012 decision T1); a spec checker asserts exactly one probe definition and one pinned failure-direction class per [LTA-GGP] inventory row at its home — what the probe executes, the faithful equivalent for permissioned paths, and what `evidenceHash` commits to — mirroring the GGP-identifier completeness rule (ADR 0012 decision T1); change events with old/new values; excluded from finality manifests, frozen-route identity, and economic preimages — all per the pattern homes ([LTA-GGP], [LTA-GTP]; ADR 0010 decision D1) and their full inventories | GGP/GTP inventory with genesis values, floors, named Permanent-class probe contracts, `probeMaxAgeBlocks` at or above `PROBE_MAX_AGE_FLOOR_BLOCKS` ([LTA-GGP-PROBES] rule 6; ADR 0012 decision T1), failure-direction classes (`FORWARDING_CAP`/`FAIL_CLOSED_PRECHECK`/`MIN_GAS_GATE`), and `FORWARDING_CAP`-only conditional-raise registrations in the release manifest; zero-signer drill artifact; repricing review checklist | mandatory |
| Governance | governance/timelock, role registry | no single EOA, role map cardinality, delays; canonical action ID and atomic batch execution ([GOV-ACTION-ID], [GOV-BATCH]); material-action holder classes with the time-boxed EOA bootstrap sunset recorded in ceremony evidence ([GOV-MATERIAL]; ADR 0011 decision R10); material-action executability rehearsal (ADR 0012 decision T5): on the rehearsal deployment a Safe and a reference governor contract each execute one action of every material class end to end — schedule, cancel, execute including a nonzero-`msg.value` payable call, veto a terminal freeze, pause and unpause, one GGP raise and one probe-gated lower, one pointer move, one role grant — recorded as checksum-covered release evidence; window floors, the 72-hour terminal-freeze veto floor, and dedicated unpause role ([GOV-WINDOWS]) with pause/unpause holder disjointness keyed on the durable `ROLE_PAUSE_GUARDIAN` and unpause role constants ([GOV-ROLES]; ADR 0012 decision T5); every governor-held defensive role is exercised through its registered guardian module in rehearsal or held by a Safe with recorded latency inside the emergency assumption ([LTA-GUARDIAN]; ADR 0012 decision T5); long-lived authorities are role references resolved through the admin registry, not raw addresses (ADR 0010 decision D7.4), and named-executor entries in the action policy catalog are [GOV-ROLES] role references — a raw-address executor entry fails catalog validation (ADR 0012 decision T5); non-material operational grants held by EOAs carry a declared sunset review cadence (ADR 0012 decision T5); entropy-provider operational authorities contract-held with rehearsed rotation ([EP-CUSTODY]); at least one registry-`ACTIVE` pre-approved fallback target registered per critical pointer family at genesis with a rehearsed permissionless move recorded as release evidence, the fallback-target inventory artifact enumerating exactly the genesis profile's fallback entries ([LTA-POINTERS] rule 11; ADR 0011 decision R10; ADR 0012 decision T1) | genesis governance manifest, governance action policy catalog, material-action rehearsal evidence, fallback-target inventory | mandatory |
| Collector gas budget | both paid mint paths, genesis sale adapters | measured all-cold end-to-end collector transaction gas for `PRE_REVENUE_SINGLE_STEP` and `PREPARED_MINT` (single and batch of 10), free allowlisted mint, fixed-price and Dutch purchases, each at or below the normative not-to-exceed ceiling pinned per path in [MPA-GAS-BUDGET] (ADR 0011 decision R12; ADR 0010 decision D5.10) — the ceilings are spec values, not report values, so exceedance forces path slimming before deployment and is never remediable by editing the report; side-by-side measured comparison against the named competitor mint paths listed in [MPA-GAS-BUDGET] recorded in the artifact; measured all-cold per-mint and wallet-to-wallet per-transfer gas for the enumerable-free Core recorded per [LTA-TRADEOFFS] item 2 (ADR 0012 decision T10, superseding the ADR 0010 decision D9.3 enumerable-overhead artifact) | checksum-covered gas budget artifact with per-path ceiling compliance and competitor comparison | mandatory |
| Fixity program | preservation records, operations | mandated fixity schedule (annual full sweep, quarterly sampling), `FIXITY_CYCLE_COMPLETED`/`FIXITY_FAILURE` records, repair-from-mirror and escalation policy ([CMC-FIXITY-PROGRAM]; ADR 0010 decision D6.3); the sold-token coverage lane of open collections is inside the mandated schedule and the monitored-incident regime (ADR 0012 decision T2) | deployment-gated fixity operations manifest | mandatory |
| Reconstruction client | archival reconstruction client | client exists at genesis and rebuilds every [PV1-RECON] item — event-only where the home requires event replay, state-recovered for the renderer-input `tokenData` surface exactly as [PV1-RECON] carves it out; source-archive hash matches `streamSystemManifest().reconstructionClientHash`; replay test vectors pass in CI; reproducible-build instructions verified (ADR 0010 decision D4.8); registrar tooling scope (ADR 0012 decision T8): the gated client (or a dedicated registrar tool archived and hash-recorded exactly like it, per [CMC-OBJECT-DOSSIER]) regenerates an `OBJECT_DOSSIER_V1` dossier and a `STREAM_ACQUISITION_PACKET_V1` packet from chain state with zero operator involvement and verifies every pinned component — record-chain heads, the content-root proof, the ownership-provenance chain, and the drill outcome — never only static worked-example schema validation ([CMC-OBJECT-DOSSIER], [CMC-ACQUISITION-PACKET]), and a packet-regeneration step joins the museum-mode and preservation drill lists ([CMC-OBJECT-DOSSIER] rule 2) | client source archive hash, replay vector artifact, dossier/packet regeneration vectors, drill cadence in ops runbook hashes | mandatory |
| Funding manifest | operations | published funding/endowment manifest naming the source, coverage horizon, and exhaustion alarms for keepers, entropy fees, storage mirrors, fixity cycles, and drills; each recurring obligation names its funded operational owner (ADR 0010 decision D4.8); every storage family carries its economics class (`ENDOWED`/`RENEWAL_FUNDED`) and the gate fails if any render-critical payload has no `ENDOWED` family ([LTA-FUNDING] rule 1, [LTA-ARCHIVE] requirement 3; ADR 0011 decision R4); the protocol-endowment decision is stated explicitly either way ([LTA-FUNDING] rule 3); the entitlement-indexer operator for recipient claim discovery is named ([RSR-CLAIM-ROUTER] rule 6); the manifest carries a costed operating model — estimated person-hours and fees per recurring obligation per year — and the coverage horizon is measured against that computed annual cost, so exhaustion alarms guard a number that was actually computed (ADR 0012 decision T9) | checksum-covered funding manifest | mandatory |
| Claim aggregation | claim router periphery | permissionless `claimMany`/`syncAndClaimMany`, release-to-self only, continue-on-failure mode, one-transaction aggregated claiming across at least 20 wallets ([RSR-CLAIM-ROUTER]; ADR 0010 decision D10.6); rehearsed end-to-end recipient claim flow recorded as release evidence — event-only entitlement discovery, `syncAsset`, and the 20-wallet `claimMany` run ([RSR-CLAIM-ROUTER] rule 6; ADR 0011 decision R12) | claim router manifest, recipient claim rehearsal artifact | mandatory |
| Events | every subsystem | event reconstruction, supersession map | event catalog hash | mandatory |
| Operations | monitoring/export/storage | degraded-admin test, state export with metadata/record-chain roots, storage redundancy, export cadence per the umbrella schedule; recurring-obligation staleness monitoring computes latest export age from `latestStateExport()` ([LTA-EXPORT]) and latest fixity-cycle age from `FIXITY_CYCLE_COMPLETED` records ([CMC-FIXITY-PROGRAM]), and the published missed-cadence policy declares a monitored incident on any exceeded maximum staleness ([LCM-GENESIS] recurring obligations; ADR 0011 decision R12); state exports and event-history snapshot chunks carry dual-family archival receipts — at least one `ENDOWED` family — with fixity coverage, as the designated EIP-4444 bridge ([LTA-ARCHIVE]; ADR 0012 decision T3); a standing vulnerability-disclosure policy is published and hash-committed — security contact, response SLO, and the explicit bounty/no-bounty decision — with its funded owner named in the funding manifest (ADR 0012 decision T9) | ops runbook hashes, missed-cadence policy hash, disclosure-policy hash | mandatory |

### Marketplace Evidence Requirements [LCM-MARKETPLACE]

The marketplace collection display and marketplace royalty resolution
gates are falsifiable against this section, never against reviewer
judgment (ADR 0011 decision R12):

1. The release manifest must include a checksum-covered marketplace-target
   manifest pinning the launch marketplace/indexer set before the
   deployment ceremony: at least three named targets, including the two
   highest-volume general-purpose Ethereum NFT marketplaces (measured by
   trailing-90-day secondary volume at pinning time) and at least one
   major independent NFT indexer/API, each with the resolution mechanism
   the evidence must exercise (contract-metadata read, registry read, or
   marketplace API).
   Changing the pinned target set is a reviewed release-artifact change,
   never a gate-time substitution.
2. Evidence entries follow a pinned schema, one entry per
   (target, launch artist series): `{targetId, collectionId,
   captureTimestamp, captureToolVersion, screenshotHash,
   apiResponseHash, resolutionKind}`, canonicalized with RFC 8785/JCS
   and checksum-covered in the evidence bundle.
3. "Resolves as its own collection" means, concretely: the target
   displays the series as a distinct collection object whose displayed
   name matches the pinned series name, whose item set corresponds to
   the series token list (the entry records a spot check of the first
   and last collection serials), and which is not merged with any other
   Stream series; the hashed API response must demonstrate that
   grouping.
4. Royalty-resolution evidence, per target and series: the hashed API
   response or settlement-configuration state showing the resolved
   receiver and bps matching a live `royaltyInfo()` read at capture
   time; for targets that resolve shared-contract royalties through the
   shared community royalty registry, the bundle records the registry
   entry (registry address and registration transaction hash); for
   targets that use per-marketplace royalty configuration, the bundle
   records that configuration state.
5. Either gate fails on any missing (target, series) pair, any
   schema-invalid entry, or any mismatch between an entry and its pinned
   expectation. The standards-track collection-identity signal remains
   reserved as OQ-X8 in
   [`docs/spec-open-questions.md`](spec-open-questions.md); this section
   pins evidence, not the signal.
6. Standing commitments or dated re-verification (ADR 0012 decision
   T9). Capture-time evidence alone satisfies neither marketplace gate:
   a launch-day capture proves nothing about year three of a
   re-indexing, API-deprecating marketplace. Every (target, series)
   evidence entry must be backed by at least one of: (a) a standing
   integration commitment — a named, signed statement from the target
   recording the signer identity, the date, and a scope covering
   collection-level display and royalty resolution through the pinned
   mechanism — hash-covered in the evidence bundle; or (b) a dated
   re-verification cadence — the entry declares its cadence and maximum
   staleness, display and royalty evidence join the recurring
   post-launch obligations ([LCM-GENESIS]) with the same
   monitored-incident teeth as fixity, and an entry older than its
   declared maximum staleness is a monitored incident until re-verified
   through the same machine path and schema as the original capture.
   The two highest-volume pinned targets should carry standing
   commitments before public sale, with any deviation recorded in the
   release evidence; a target carrying neither a commitment nor a
   cadence fails the gate.

## Genesis Deployment Profile

Requirements [LCM-GENESIS]:

Genesis is the smallest system consistent with the owner-ratified
permanence and flexibility posture (ADR 0010 decision D9.1); it is not a
minimal system, and this profile states the full cost honestly. Genesis
targets Ethereum mainnet — the normative chain posture is owned by
protocol v1 [PV1-SCOPE] (ADR 0012 decision T9) — and a deployment
ceremony on any other chain fails this matrix. Every
entry below names the concrete genesis deployment; a parenthesized
interface is the Permanent surface that deployment must satisfy. An
interface with no concrete deployment, or a required gate whose contract
is absent from this list, is a matrix violation. This inventory is
exhaustive: 56 deployable production contracts — the 35 numbered
entries below plus the twenty-one Permanent-class probe contracts of
entries 36–56: one probe per [LTA-GGP] inventory row (twenty at this
revision) and the shared entropy cadence probe serving the three
[LTA-GTP] genesis instantiations ([EC-TIME]) — plus per-collection
split wallets created on demand by `CREATE2` through the factory.
Growth is same-change: a spec amendment that adds an [LTA-GGP]
inventory row or an [LTA-GTP] instantiation (ADR 0012 decision T1), or
a deployment manifest that names an additional critical pointer family
([LTA-POINTERS] rule 11), lands with its probe or fallback entry here
and the updated count. Governed Gas Parameter stores are storage
surfaces of the listed contracts (Core and the split factory parameter
store), not separate deployments. Probe contracts are Permanent-class
production-inventory members, not operator tooling: their recorded
probe runs gate value-changing raise, lower, and conditional-raise
actions, so they carry the full [LTA-GGP-PROBES] permanence discipline
(ADR 0012 decision T1) — no owner, no upgrade path, no selfdestruct,
probe-run records hosted on the probe, permissionless callability with
pinned per-parameter inputs, and no pointer, funds, or other
authority — and are covered by the [LCM-STATIC] rule 10 permanence
checks, golden test 26, the deterministic-deployment record, and the
genesis audit plan. Only the deployer factory — no authority, no
pointer, no funds, identity-independent — sits outside this production
inventory; the mock entropy provider exists only in local validation
and never deploys to production.

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
34 Pre-approved ENTROPY_COORDINATOR fallback target: a registry-ACTIVE,
   write-capable safe-mode coordinator ([LTA-POINTERS] rules 6 and 11)
35 Pre-approved MINT_MANAGER fallback target: a registry-ACTIVE
   replacement mint manager instance ([LTA-POINTERS] rule 11)
36-55 Per-parameter GGP probe contracts, one per [LTA-GGP] inventory
   row (twenty at this revision), Permanent-class under
   [LTA-GGP-PROBES] (ADR 0012 decision T1)
56 Shared entropy cadence probe for the three [LTA-GTP] genesis
   instantiations, Permanent-class under [LTA-GGP-PROBES]
   ([EC-TIME]; ADR 0012 decision T1)
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

Entries 34–35 are the standing incident path required by
[LTA-POINTERS] rule 11: the Governance gate's fallback-target inventory
artifact enumerates exactly these entries (plus any critical family the
deployment manifest adds), each with its registry status and the
rehearsed permissionless emergency move recorded as release evidence,
and the deployment manifest's critical-family list and this profile
must name the same families (ADR 0012 decision T1).

The genesis ceremony should also deploy and register one stateless
enumeration lens (module type `STREAM_ENUMERATION_LENS`;
[LTA-ENUMERATION], ADR 0012 decision T10); a deployment that omits it
records the rationale in the deployment manifest. The lens holds no
pointer, no funds, and no authority, is never a dependency of any
Permanent surface, and sits outside the mandatory count above under
its home's should-deploy posture.

Genesis deployment is deterministic (ADR 0011 decision R10; home
[`docs/stream-long-term-architecture.md`](stream-long-term-architecture.md)
[LTA-DEPLOY]): every contract in the inventory above — fallback targets
and probe contracts included (ADR 0012 decision T1) — deploys through
the deterministic deployment factory named in the deployment manifest,
with the factory address, per-contract `CREATE2` salts, and init-code
hashes recorded so every genesis address is recomputable from the
release manifest alone. The deployer factory holds no protocol
authority, no pointer, and no funds, and is therefore outside the
56-contract production inventory; every identity preimage continues to
bind deployed addresses and code hashes, so determinism is an
auditability property of
the ceremony and of successor-line address planning, never an identity
dependency.

Genesis audit plan (ADR 0010 decision D9.1): the release manifest must
include a published subsystem-by-subsystem audit plan artifact covering
every contract above — the probe contracts and fallback targets
included (ADR 0012 decision T1) — per-subsystem scope, audit ordering,
auditor identity or class, and completion evidence — and the deployment
ceremony fails while any subsystem lacks recorded audit completion. The audit
plan must include a critical-path launch schedule: the audit dependency
graph, the parallelism plan, and the ordered ceremony steps from final
audit to public sale. Every gate in this matrix stays launch-blocking —
the owner-ratified posture accepts shipping later over shipping unproven
(ADR 0010 decision D5.10) — and the critical-path schedule is how that
shipping risk is managed, never a mechanism to defer or downgrade gates.

Recurring post-launch obligations have teeth (ADR 0011 decision R12).
Fixity cycles, state exports, preservation and reconstruction drills,
funding-manifest renewals, marketplace display and royalty
re-verification for cadence-backed targets ([LCM-MARKETPLACE] rule 6;
ADR 0012 decision T9), and the sunset reviews of non-material
operational grants held by EOAs (ADR 0012 decision T5) each declare a
cadence and a maximum staleness in their gated manifests, and each
names its funded
operational owner in the funding manifest gate. Exceeding a declared
maximum staleness is a monitored incident, not a lapsed intention:
monitoring must alert, the incident must be declared and recorded in the
preservation record lane naming the missed obligation and its recovery
plan, and the hash-committed missed-cadence policy in the operations
runbook names the escalation path and the response owner. Obligation
ages are verifiable without operator testimony: latest export age reads
from `latestStateExport()` ([LTA-EXPORT]) and latest fixity-cycle age
reads from `FIXITY_CYCLE_COMPLETED` records ([CMC-FIXITY-PROGRAM]), so
any third party can compute staleness from chain state alone; the
Operations gate verifies that monitoring computes these ages from those
onchain reads. Marketplace re-verification and grant-sunset ages read
from the dated, hash-committed artifacts their gates require, so those
staleness computations need the published bundles but never operator
testimony. The deployment gate is the floor of the obligation, never
the whole of it.

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
ERC-2981, move mutable policy to satellites rather than expanding Core;
enumerable index storage is no longer a Core surface (ADR 0012 decision
T10).

Core planning budget before implementation. The upper bound of each range
is a binding per-group allocation, not an estimate (ADR 0011 decision
R12): the allocations sum to 21,000 runtime bytes, 1,576 bytes below the
22,576-byte ceiling the governing headroom rule implies (EIP-170's 24,576
bytes minus the 2,000-byte deployment-gate margin, ADR 0009 decision 2),
so meeting every per-group allocation satisfies the gate by arithmetic
rather than by hope. The 1,576 bytes of unallocated slack were recovered
by removing enumerable index storage from the ERC-721 group (ADR 0012
decision T10) and stay unallocated as planning margin:

```text
Function group                                      priority    planning allocation bytes
ERC-721 ownership/approval/metadata (no enumerable) permanent   5,600-6,400
Mint/burn/token identity/collection serials         permanent   3,000-3,600
Collection facts/status/supply reads and writes     permanent   2,000-2,400
Core-native ERC-2981 resolver read                  permanent     700-900
Bounded tokenURI router read/fallback/status        permanent   1,400-1,600
Bounded contractURI delegated read (ERC-7572)       permanent     300-400
Satellite pointer cached reads and governance hooks permanent   1,200-1,500
Core finality fact and lifecycle view assembly      medium        700-900
Core-originated ERC-4906 refresh emitters           permanent     300-400
streamSystemManifest storage-only read              permanent     500-600
Successor declaration history                       medium        500-600
latestStateExport storage-only read                 medium        300-400
Prepared mint prepare/complete                      permanent     900-1,300
```

The 2,000-byte headroom target above is the governing deployment rule
(ADR 0009 decision 2); the bytecode-spend baseline and exception ledger in
`release-artifacts/contracts.json` remain the pre-deployment development
control, and interim exceptions cannot survive to the deployment gate.
A group that cannot fit its allocation sheds bytes through the named
compression strategies first — custom errors replacing revert strings,
packed token-identity and collection-facts storage records, shared
guard/read helpers, and satellite-side assembly of aggregate views —
before any relocation is considered.

If the measured build still loses the 2,000-byte headroom, the
pre-authorized relocation order is decided now, not at the deployment
gate (ADR 0011 decision R12): first, successor declaration history and
state-export publication (`latestStateExport`) move into a thin
immutable discovery satellite that Core points to through the same
cached pointer policy; second, the aggregated finality-fact and
lifecycle view assembly moves into the same satellite, with Core
permanently retaining the granular collection facts, supply, status,
burn-block, and token-identity storage reads those views are assembled
from. Every `permanent` row stays in Core — including
`streamSystemManifest()` and the prepared-mint pair, which are never
relocation candidates (ADR 0010 decision D10.6; [MPA-CORE-ABI]). A
measured build that exceeds the ceiling after both relocations and the
named compression strategies is a design failure that blocks deployment;
editing the allocation table is a spec amendment through the normal
process, never a gate-time remediation.

Non-normative reconciliation note: the CON-012 measured baseline (24,150
runtime bytes; protocol v1 [PV1-HOOKS] implementation evidence) predates
ADR 0012 decision T10 — it was compiled with the since-removed
`ERC721Enumerable` extension — and exceeds the 22,576-byte ceiling by
1,574 bytes and the post-T10 allocation total by 3,150 bytes. Closing
that gap is a named engineering workstream with its own measured
milestone, not a deployment-eve hope (ADR 0012 decision T9): the Core
size reconciliation workstream removes enumerable index storage
(1,500 bytes at the planning allocation), applies the named compression
strategies, and draws on the pre-authorized relocations above (bounded
up to 1,900 bytes of relief) — together bounding more relief than the
overage — and publishes the first passing measured build as release
evidence rather than waiting for the deployment gate to force it.

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
   Probe contracts are inside this rule's production scope as
   Permanent-class inventory members ([LTA-GGP-PROBES]), and
   additionally fail on any owner or upgrade path (ADR 0012 decision
   T1).
11. Production mint contracts compile callable `CUSTOM_RESOLVER`,
    resolver-defined cap/delta, or nullifier execution paths before the
    accepted ADR enables them. Reserved enum values may exist in manifests, but
    excluded call paths must be physically absent from production bytecode or
    blocked before any external call/state write by static checks.
12. The renderer or router `tokenURI` path contains environment or context
    opcodes — `TIMESTAMP`, `NUMBER`, `PREVRANDAO`, `BLOCKHASH`,
    `COINBASE`, `BASEFEE`, `GASLIMIT`, `GASPRICE`, `BALANCE`,
    `SELFBALANCE` — or any external read outside the renderer version's
    declared read set pinned by [MRR-DETERMINISM] (ADR 0010 decision
    D4.3; ADR 0011 decision R3): for the default `STATIC` class that set
    is Core identity, entropy view, and metadata storage reads; a
    declared `DYNAMIC`-class renderer version extends it only with its
    own declared, per-version-frozen external reads, and the gate re-runs
    against the declared set. Renderer output must be a pure function of
    contract state, the render request, and (for `DYNAMIC`) the declared
    reads; the pinned golden render vectors re-verify this at every
    preservation drill.

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
9. Governance tests prove the production contracts enforce the launch
   enforcement model exactly as pinned at the governance home
   ([`docs/adr/0004-admin-governance.md`](adr/0004-admin-governance.md):
   the two-tier delay model plus named exception floors, with the richer
   action-class taxonomy as manifest/runbook vocabulary until a later
   ADR implements it onchain); this row is a citation of that home's
   definitive statement, and on any drift the home wins.
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
    every deployed satellite, plus the deterministic-deployment record —
    deployer factory address, per-contract `CREATE2` salts, and init-code
    hashes sufficient to recompute every genesis address from the manifest
    alone (ADR 0011 decision R10).
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
    `EntropySecurityClass`, `EntropyScopeKind`, `RevealRequestMode`,
    `ProviderResultStatus`,
    `ModuleRegistryStatus`, `AuthorizerKind`, `CodehashPinMode`, asset
    policy statuses,
    `AttributionState`, `ArtistConsentMode`, `ArtistAuthorityClass`,
    `CollabPolicyMode`, `SaleKind`, `DutchDecayKind`, finality scope
    types, recovery statuses, and — every enum whose numeric values are
    hashed into a Permanent preimage or cross an ABI/manifest boundary
    (ADR 0012 decision T9) — `CounterScope`, `CounterKeyMode`,
    `CounterUpdateMode`, `CounterCapMode`, `CounterDeltaMode` (inputs
    to `COUNTER_CONFIG_DOMAIN`/`COUNTER_BINDING_DOMAIN_V2` and
    therefore to every `policyHash`), `MetadataMode`,
    `OffchainURIIdMode`, `TokenRenderState`, `PayloadSourceType`,
    `ArtistIdentityStatus`, `AttestationSubjectKind`,
    `SaleConsentScope`, the [LTA-GUARDIAN] capability bits, and
    `GovernanceActionStatus` match the manifest-pinned Numeric ID
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
    values (ADR 0010 decision D3.6). Core's restricted ERC-7572
    `ContractURIUpdated()` helper accepts exactly the one caller pinned
    by the same hook-table home — the current metadata router resolved
    through Core's cached pointer — and reverts for every other caller,
    including the finality registry and the entropy coordinator, which
    are authorized only for the ERC-4906 helpers (ADR 0012 decision
    T9).
25. Every enum literal named in this matrix — including the lifecycle
    reconciliation matrix and the Numeric ID Catalog coverage list —
    appears verbatim in the owning spec's enum definition; CI fails on
    any literal (such as a status name) that no home document defines.
26. Every deployed probe contract — the per-parameter GGP probes and
    the shared entropy cadence probe — exposes the canonical
    [LTA-GGP-PROBES] probe surface (`lastProbeRun(bytes32,uint256)` and
    the schemaVersioned `GasParameterProbed`/`TimeParameterProbed`
    event), hosts its own probe-run records, executes only its pinned
    per-parameter probe inputs with no caller-supplied gas shaping, is
    permissionlessly callable with no role, allowlist, or fee, and
    passes the [LCM-STATIC] rule 10 permanence checks: no owner, no
    upgrade path, no selfdestruct (ADR 0012 decision T1).
27. Core reports `supportsInterface(0x780e9d63) == false` (ERC-721
    Enumerable is not advertised), `totalSupply()` and
    `lastAllocatedTokenId()` remain storage reads over dense sequential
    allocation ([LTA-ENUMERATION]), and
    `tokenOfOwnerByIndex`/`tokenByIndex` selectors are absent from the
    Core selector manifest (ADR 0012 decision T10).
28. State-only payload discovery ([LTA-PAYLOAD-DISCOVERY]; ADR 0012
    decision T3): every SSTORE2/storage payload family exposes its
    host's storage-backed discovery surface — the enumerable pointer
    registry (count plus paged pointer/family/hash rows,
    [CMC-PAYLOAD-POINTERS]) or the typed pointer field on an
    exhaustively keyed record read — and a state-only client locates
    every onchain payload byte through those reads without consulting
    any log.

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

One fact, one owning event (ADR 0011 decision R12). This is the
genesis-wide event policy that the subsystem specs apply: every
production fact is emitted by exactly one owning event, and
implementation-optional duplicate or mirror emissions are banned at
genesis — an optional mirror is a conformance defect, not a convenience.
Where a spec requires a same-execution mirror (for example the router's
required `MetadataRouterUpdated` mirror, [MRR-ROUTER-EVENTS], or a
parameter-named GGP or GTP alias event, [LTA-GGP] requirement 4 and
[LTA-GTP] change rule 4), the catalog
must tag the mirror as a member of its fact family so indexers
reconstruct each fact from exactly one declared event set; an emission
that is neither the owner nor a catalog-tagged required mirror fails the
Events gate.
The v1 catalog must explicitly list standard-event exemptions where the event
signature cannot include `schemaVersion`, including ERC-721 `Transfer`,
`Approval`, `ApprovalForAll`,
ERC-4906 `MetadataUpdate` / `BatchMetadataUpdate` if emitted with their
standard signatures, and ERC-7572 `ContractURIUpdated()` (ADR 0010
decision D10.6).
`TokenCollectionRegistered` is not exempt: its production signature
carries `uint16 schemaVersion`, pinned once at its home
([`docs/mint-policy-and-accounting.md`](mint-policy-and-accounting.md)
[MPA-CORE-ABI]; ADR 0011 decision R12), and any snippet without it is
shorthand under the rule below.
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
authorizer kinds ([MPA-AUTHZ]), counter scopes and counter
key/update/cap/delta modes (`CounterScope`, `CounterKeyMode`,
`CounterUpdateMode`, `CounterCapMode`, `CounterDeltaMode` — `uint8`
inputs to `COUNTER_CONFIG_DOMAIN` and `COUNTER_BINDING_DOMAIN_V2` and
therefore to every `policyHash`; home the mint spec Data Model;
ADR 0012 decision T9), sale and Dutch-decay kinds (sales spec;
`SaleKind` is an append-only catalog vocabulary whose genesis values
`0`–`14` — including the reserved extension values — are pinned at
[SSA-IDENTITY] and never renumbered, with new kinds allocated append-only
from `15`, ADR 0011 decision R9; `DutchDecayKind` is likewise an
append-only vocabulary pinned at its home, [SSA-DUTCH], ADR 0012
decision T6),
English-auction lifecycle states and refund-window purchase states
(sales spec [SSA-ENGLISH] state machine and [SSA-REFUND]),
codehash pin modes (`CodehashPinMode`; enum home the mint spec Data
Model with its pin rules at [MPA-REGISTRY] rule 5, ADR 0011 decision
R12), entropy scope kinds and reveal request modes
(`EntropyScopeKind`, `RevealRequestMode`; homes [EC-SCOPE] and
[EC-REVEAL], ADR 0011 decision R8),
metadata modes, offchain URI ID modes, token render states, and payload
source types (`MetadataMode`, `OffchainURIIdMode`, `TokenRenderState`,
`PayloadSourceType`; home
[`docs/metadata-router-and-renderer.md`](metadata-router-and-renderer.md);
ADR 0012 decision T9),
attribution states, artist consent modes, artist authority classes,
collaborator policy modes, artist identity statuses, attestation
subject kinds, and sale consent scopes (`ArtistIdentityStatus`,
`AttestationSubjectKind` — `SUBJECT_DEPLOYMENT = 9` included — and
`SaleConsentScope`, a `uint8` input to `ARTIST_BINDING_DOMAIN`;
ADR 0012 decisions T4 and T9)
([`docs/stream-artist-authority.md`](stream-artist-authority.md)),
governance action statuses (`GovernanceActionStatus`; home
[`docs/adr/0004-admin-governance.md`](adr/0004-admin-governance.md)
[GOV-ACTION-ID]),
guardian capability bits (`PAUSE = bit 0`, `VETO_TERMINAL_FREEZE =
bit 1`, `CANCEL_STAGED_ACTION = bit 2`, `INCIDENT_REVOKE = bit 3`;
home [LTA-GUARDIAN] rule 2 in
[`docs/stream-long-term-architecture.md`](stream-long-term-architecture.md);
ADR 0012 decision T5),
owner-record family constants (`ACCESSION`, `CONDITION_REPORT`,
`EXHIBITION`, `LOAN`, `DEACCESSION`, `CITATION`; home
[CMC-OWNER-RECORDS]), schema statuses, hash algorithms, canonicalization
IDs, source/storage types, token URI read statuses, finality scope types,
and recovery statuses. IDs may be deprecated but not reinterpreted.
Coverage is closed-world across hash preimages (ADR 0012 decision T9):
every enum whose numeric values are inputs to any domain-constants home
or protocol v1 mirror row — every enum hashed into a Permanent
preimage — and every enum that crosses a contract, indexer, or manifest
boundary must have a catalog entry, and a checker fails on any enum
named in a domain-table Inputs cell that has none.
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
