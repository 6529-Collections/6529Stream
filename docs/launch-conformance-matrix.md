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
   binding requirement is numbered within its section. The
   normative-language sweep is likewise complete (ADR 0014 decision
   V9): no load-bearing `should` remains in a Permanent or Replaceable
   section whose anchor a gate row cites unless it states its intended
   deviation license explicitly; the normative-language lint in the
   Verification Tooling Backlog ([LCM-TOOLING]) flags candidates.
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
5. The genesis audit plan's critical-path schedule exists as a dated,
   checksum-covered release artifact — named audit waves with
   auditor-week sizing, the audit dependency graph, and the ordered
   ceremony steps from final audit to public sale ([LCM-GENESIS],
   Genesis audit plan) — so the audit-and-ship runway is priced before
   any document carries Review status (ADR 0013 decision U9).
6. For the museum-facing metadata documents —
   [`docs/collection-metadata-contract.md`](collection-metadata-contract.md)
   and the satellite record surfaces it owns — the
   institutional-validation evidence of the Institutional validation
   gate exists with findings dispositioned: the two named-repository
   dossier ingest reports and the two named external practitioner
   reviews of the genesis museum schema set required by that gate's
   raised floor (ADR 0013 decision U8; ADR 0014 decision V8). Review
   entry for the other inventory documents does not wait on this
   condition. The dependency is deliberately fallback-free and
   asymmetric to the marketplace gates: [LCM-MARKETPLACE] rule 6
   admits an owner-signed risk acceptance because its evidence guards
   display behavior on third-party venues, while this condition
   substantiates the museum claim itself, so no synthetic or
   risk-accepted substitute exists — the schedule cost is carried by
   starting institutional outreach as a tracked pre-Review workstream
   with dated milestones in the critical-path schedule (condition 5),
   never by weakening the floor.
7. Every checker in the Verification Tooling Backlog ([LCM-TOOLING])
   exists and passes across the full document set and release-artifact
   chain (ADR 0014 decision V9). Review entry asserts a passing run,
   never a promise to build: a named-but-unbuilt checker is itself a
   failing condition, because the defect classes those checkers catch —
   count drift, citation-shape drift, mirror drift, unmapped
   requirements — are exactly the classes hand-editing keeps
   reintroducing. A checker whose subject exists only at deployment
   time — the spec-bundle Final-status checker and the metadata
   aggregate release checker — satisfies this condition by existing
   and passing against rehearsal fixtures; its gate row binds the
   production run.

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

## Verification Tooling Backlog

Requirements [LCM-TOOLING]:

This table is the single tracking point for every checker the spec set
names over its own documents, catalogs, and release artifacts
(ADR 0014 decision V9). The set's consistency claims — checker-verified
mirrors, closed-world catalogs, counted inventories — are only as good
as these tools, and the round-5 review demonstrated that the defect
classes they catch (count drift, citation-shape drift, a false
cross-document placement claim) recur while editing outpaces tooling.
Rules:

1. Closed-world membership: a checker named anywhere in the spec set
   whose subject is the documents, catalogs, or release artifacts and
   that is absent from this table is a defect; growth is same-change —
   a spec amendment that names a new checker lands with its row here.
   Implementation-facing test suites (golden interface tests, static
   analysis over Solidity, conformance suites) are tracked by their
   gate rows, not by this table.
2. Review-entry teeth: [LCM-REVIEW-ENTRY] condition 7 requires every
   row to exist and pass before any inventory document enters Review.
   Building a checker earlier and wiring it PR-blocking for docs
   changes is Operational discretion; the condition binds existence
   and a passing run, never the wiring.
3. Honest status: the Status column says `exists` only for a checker
   that runs today against this repository; everything else is
   `to build`, and editing a Status cell without landing the tool is a
   defect.

| Checker | Verifies | Named by | Status |
|---|---|---|---|
| Markdown link checker (`scripts/check_markdown_links.py`) | every relative link and heading anchor across the docs tree resolves | spec-policy inventory hygiene | exists |
| Mint-manager domain-constants checker (`scripts/check_mint_manager_domain_constants.py`) | the checked manager table row-for-row against `StreamMintManager.sol` — constants, string preimages, hash values, and the pinned historical input aliases | protocol v1, StreamMintManager Domain Constants | exists |
| Domain recomputation checker | every `keccak256` and EIP-712 typehash in every domain home and every protocol v1 mirror row recomputed from its adjacent string preimage; drift across Solidity constants, home tables, mirrors, and release artifacts fails; an unpinned hash placeholder fails | [PV1-DOMAINS], [PV1-MIRROR] rule 2; [LCM-REVIEW-ENTRY] condition 4 | to build |
| GGP/GTP identifier completeness checker | exactly one identifier mirror row per [LTA-GGP]/[LTA-GTP] inventory entry and no orphan rows; uniform `GGP_`/`GTP_` constant names row-for-row against the Solidity constants | protocol v1 GGP identifier mirror (ADR 0011 decision R12; ADR 0013 decision U9) | to build |
| Probe-definition checker | exactly one probe definition and one pinned failure-direction class per [LTA-GGP] inventory row at its home — what the probe executes, the permissioned-path equivalent, and what `evidenceHash` commits to | Governed gas and time parameters gate (ADR 0012 decision T1) | to build |
| Traceability extractor | every anchored `must` in every inventory document maps to at least one named gate row, test, static check, or release artifact; CI fails on unmapped requirements | [LCM-REVIEW-ENTRY] condition 2 (ADR 0010 decision D3.3) | to build |
| Anchor-resolution checker | every bracketed anchor cited anywhere in the set resolves to exactly one home section, and anchor backfill is complete | [LCM-REVIEW-ENTRY] condition 1; spec-policy Requirement Anchors (ADR 0014 decision V9) | to build |
| Citation-format checker | every decision citation matches `(ADR <number> decision <id>)` with the owning ADR's id shape — `D`/`R`/`T`/`U`/`V`/`W` prefixes, with ADR 0009's plain numerals exempt by construction — and the cited id exists in the cited ADR | spec-policy Decision Citation Format (ADR 0014 decision V9) | to build |
| Prose-count checker | asserted counts derive from counted sources: the [LCM-GENESIS] owning inventory count against its numbered and probe entries, the no-restated-numeral rule everywhere else, and the named suite and schema counts (the [AA-GATES] suite list, the [CMC-GENESIS-SCHEMAS] schema table) against their homes' lists | [LCM-GENESIS] (ADR 0014 decision V9) | to build |
| Normative-language lint | flags `should` inside Permanent or Replaceable sections whose anchors this matrix cites, enforcing the must-ward sweep: each flagged `should` either becomes `must` or states its deviation license | spec-policy Normative Language; [LCM-REVIEW-ENTRY] condition 1 (ADR 0014 decision V9) | to build |
| Enum-literal cross-check (docs-side lint for golden test 25) | every enum literal named in this matrix, the lifecycle reconciliation matrix, and the mirrors exists verbatim in its owning spec's enum definition | [LCM-GOLDEN] test 25 | to build |
| Numeric ID Catalog closed-world checker | every enum named in any domain-table Inputs cell, hashed into any Permanent preimage, or crossing a contract/indexer/manifest boundary has a catalog entry | [LCM-IDS] (ADR 0012 decision T9) | to build |
| Event-catalog checkers | the machine-readable catalog generates from the spec set with final signatures and `topic0` values; production-exact event homes match the catalog field-for-field; at most three indexed fields; supersession links complete; every governed-configuration event carries `actionId` | [LCM-REVIEW-ENTRY] condition 3; [LCM-EVENTS]; [LCM-GOLDEN] tests 8 and 20 (ADR 0014 decision V6) | to build |
| Cross-document mirror checkers | the named checker rows comparing mirror tables and field inventories to their homes: the [MRR-ATTRIBUTION]/[AA-DISPLAY] attribution mirror, the [CMC-ARTIST-ATTESTATION] attestation mirror, the record-family event mirror rows, and the [CMC-RECONSTRUCTION] tooling row | the owning rows in the metadata and artist homes | to build |
| Baseline-record header checker | every repository document outside the spec inventory carries the required baseline-record header block | spec-policy (ADR 0012 decision T9) | to build |
| Spec-bundle Final-status checker | the genesis spec bundle named by the deployment manifest's `specBundleHash` enumerates every inventory document at Final status with per-document content hashes, and the bundle hash recomputes | Operations gate; [LCM-GOLDEN] test 14 ([LTA-MANIFEST]; ADR 0014 decision V9) | to build |
| Metadata aggregate ABI/bytecode release checker | the deployment candidate's aggregate metadata function count and bytecode stay under the pinned ceilings | Collection metadata gate ([`docs/collection-metadata-contract.md`](collection-metadata-contract.md) release checker rule) | to build |
| Commitment-evidence checker | every recorded collection-identity integration commitment in the release evidence set validates against the [LCM-MARKETPLACE] rule 7 evidence class and its pinned counterparty qualification — named counterparty from the rule 1 pinned marketplace-target manifest, signer identity, date, W1-signal scope, verifiable authenticity, hash coverage — and the marketplace integration commitments gate counts at least two qualifying commitments with at least one from a rule 1 top-two target or a named major independent indexer, or, where the tripwire fired, the recorded [FCP-DEPLOYMENT] decision record plus, on a no-go or a go with no facade yet bound, the rule 6-pattern owner-signed risk-acceptance record; a best-effort-outreach, conversation-only, or unqualified-counterparty artifact fails as unqualifying | Marketplace integration commitments gate ([LCM-MARKETPLACE] rule 7; ADR 0015 decision W2) | to build |

## Forbidden Production Patterns

Requirements [LCM-FORBIDDEN]:

Production contracts must not contain:

1. `tx.origin` in mint, sale, drop, auction, authorization, or payment paths.
2. `abi.encodePacked` or string concatenation for authority, sale, assignment,
   policy, profile, pointer, entropy, or finality hashes.
   Exactly two named exceptions exist. Standard CREATE2 address
   derivation is the first, because the EVM formula itself uses packed
   bytes; those packed bytes must not be reused as authority or policy
   hashes. Fixed-width sorted-pair Merkle node combination is the second
   (ADR 0013 decision U7): interior nodes of the pinned allowlist,
   counter/nullifier continuity-import, content-manifest, raffle-entry,
   and artist history-import trees hash the packed concatenation of
   exactly two 32-byte child nodes, ordered low-high, above
   double-hashed domain-separated leaves ([MPA-MERKLE],
   [MPA-CONTINUITY], [SSA-CONTENT] rule 1, [SSA-RAFFLE] rule 2,
   [AA-IMPORT]) — fixed-width, type-unambiguous inputs whose leaf
   domains already exclude node/leaf confusion, which is the property
   this ban protects, and the construction every published
   proof-generation toolchain assumes ([MPA-MERKLE] rule 7). The
   semantic rule the static gate checks: packed encodings are forbidden
   wherever any input is variable-length or type-ambiguous, and packed
   bytes may never double as an authority or policy hash preimage
   outside these two named shapes.
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
14. `SELFDESTRUCT`, delegatecall-based upgradeability, or mutable
    implementation pointers in any contract of the genesis deployment
    profile or in any registry-registered module — unconditionally, with
    no bounded-reads or immutability-promise qualifier (ADR 0013
    decision U7). Every deployed implementation in this architecture is
    itself immutable by permanence class
    ([`docs/spec-policy.md`](spec-policy.md)); replacement happens only
    through governed, evented registry and pointer assignment, so
    upgrade-in-place machinery of any kind — proxy upgrade hooks,
    beacon pointers, or self-destructing redeploy slots — is a
    forbidden pattern for the life of the line, in genesis bytecode and
    in every successor module a registry ever admits. Fixed-target
    minimal-proxy clones of an immutable implementation (the split
    wallet) are not upgradeability and remain conformant.
    [LCM-STATIC] rule 10 is the static enforcement of this row.

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
| Core-native ERC-2981 | `StreamCore.royaltyInfo`, revenue resolver | canonical `0x54f77a09` resolver selector; malformed/OOG/external-call resolver fallback; all-cold gas; precheck and staticcall read current `ROYALTY_RESOLVER_GAS_LIMIT` GGP value through the EIP-150 multiplicative precheck shape with the host-coupled `ROYALTY_RETURN_GAS_BUFFER` ([RSR-2981-GAS]); the coupling-invariant threshold suite replayed across simulated staged 2x raise chains ([RSR-2981-GAS].6; ADR 0013 decision U7); probe parity through the two Permanent-class royalty probe contracts, `GasParameterProbed` the sole gate record and `RoyaltyInfoProbed` the catalog-tagged probe-family alias ([RSR-2981-PROBE]; ADR 0013 decision U7) | Core bytecode size, resolver gas report | mandatory |
| Pull split wallets | split factory, split wallet, revenue escrow | conservation fuzz, forced ETH, approved-standard ERC-20 release/sync, unsupported ERC-20 denial, reentrancy, `DEPRECATED` release-under-grace ([RSR-ASSET-POLICY]); ERC-1271 named-class verification — heaviest legitimate wallet class passes within the `ERC_1271_GAS_LIMIT` GGP, malicious wallet rejected ([RSR-1271]) | profile schema, wallet code hashes | mandatory |
| Primary native ETH and approved-standard ERC-20 settlement | fixed-price sale adapter, ERC-20 primary settlement adapter, `StreamPrimarySaleSettlement`, asset policy registry, revenue escrow | no `tx.origin`, policy hash binding, escrow fallback, adapter and escrow both enforce `ACTIVE` asset policy, exact ERC-20 transfer accounting, allowance/payment failure handling; payer-signed `PaymentIntent` verified before any allowance pull with expired/replayed/revoked/over-cap negative tests ([RSR-PAYMENT-INTENT]); every settlement entry point on `StreamPrimarySaleSettlement` and every ERC-20 primary settlement adapter that writes official-revenue counters, consumes a `settlementKey`, or moves assets is non-reentrant with checks-effects-interactions per surface, verified by the double-record/double-deposit conformance test ([RSR-SETTLEMENT-BOUNDARY].11; ADR 0013 decision U7) | sale authorization schema, approved asset and adapter manifests | mandatory |
| Sales and auctions | genesis sale adapters and gate modules per [`docs/stream-sales-and-auctions.md`](stream-sales-and-auctions.md) | the full [SSA-GATES] suite set — the home owns the authoritative suite count and membership, and a row naming fewer suites than the home defines is a defect: English auction (reserve, increment floor, anti-snipe extension and cap, CEI, idempotent settlement, pull refunds, first-bid-starts, mint-at-settlement custody branch with the auction-creation artwork commitment, ADR 0012 decision T6), Dutch (schedule determinism, clearing, rebate conservation, maximum-price purchase with pull-credited excess), refund-window custody with drift-envelope refund unlock ([SSA-ENVELOPE]; ADR 0011 decision R6), burn-to-mint (retained-identity proof, manager-scoped nullifiers, finality interaction refusals), delegate gate, content selection (commit-reveal default), ERC-4337 + paymaster end-to-end run, registry governance, static analysis, gas budget, event reconstruction, pause tolling and no-confiscation, price kinds (zero-price, pay-what-you-want, custody inventory with `CUSTODY_SETTLEMENT_TRANSFER` ordering, [RSR-SETTLEMENT-BOUNDARY]), reveal fees, replay locus with custody-path offer/authorization revocation mechanics (ADR 0011 decision R9; ADR 0012 decision T6), the adapter escrow conservation suite (ADR 0012 decision T7), the contest-stop suite (ADR 0012 decision T4), the consignment and custody-grant suite — owner-signed single-use grants revocable until sale, settling as secondary transfers with itemized royalty delivery, never as primary revenue (ADR 0012 decision T6) — the artist sale-parameter consent suite (ADR 0012 decision T4), and the identity-mode configuration gate suite — configuration of each excluded custody or burn flow against an `EXTERNAL_FACADE` collection reverts `SaleFlowClosedForFacadeCollection`, identical configurations succeed for `CORE_NATIVE` collections, and mint-delivery kinds configure and settle identically in both modes ([SSA-IDENTITY] rule 9; ADR 0015 decision W3); airdrop batch distribution runs inside the price-kind suite and the by-construction standing envelope for public at-price purchases inside the refund-window suite ([SSA-ENVELOPE] rule 6; ADR 0012 decision T6); raffle allocation and the content-consumption registry remain frozen extension recipes without genesis bytecode (sales spec exclusions) | sale/auction state-machine manifests, adapter registry manifest | mandatory |
| Collection management | Core collection boundary | create/status/max-supply events and transitions; dense sequential collection-ID allocation from 1 with the Permanent `lastAllocatedCollectionId()` high-water-mark storage read bounding the collection-ID space — created-but-unminted collections discoverable from state, golden coverage mirroring the token-ID allocation rules (protocol v1 [PV1-IDENTITY] item 7, [LTA-ENUMERATION]; ADR 0013 decision U2) | collection facts schema | mandatory |
| Collection identity mode | Core collection boundary, `collectionIdentityMode` read and identity-mode declaration path (ADR 0015 decision W4; [PV1-FACADE-READINESS]) | golden read coverage per golden test 29; identity-mode declaration event asserted schemaVersioned against the event catalog with its `actionId` binding ([LCM-EVENTS]); one-way pre-first-mint discipline as negative gates, as load-bearing as the positive ones (ADR 0015 decision W4): declaration at or after the collection's first mint reverts, redeclaration of a declared collection reverts, and a declaration naming a mode ID outside the closed vocabulary reverts; for artist-bound collections the declaration's join to the artist consent/veto surface is exercised per its home ([`docs/stream-artist-authority.md`](stream-artist-authority.md)); the dormant-surface inertness proof runs inside the zero-signer museum-mode drill per the umbrella roster ([LTA-IDENTITY-MODE]; [LTA-GGP-PROBES] rule 9): with zero governance signers no governance signer can be replaced, no identity-mode declaration and no controller registration is possible, and a `CORE_NATIVE`-only deployment is identical on every pre-ADR-0015 surface — the facade-readiness reads answer their dormant defaults (`CORE_NATIVE`, zero controller) and the governed entries revert for every caller — with [PV1-FACADE-READINESS] requirement 1 the single scoping home of that claim (ADR 0015 decision W4) | identity-mode vocabulary mirror rows in the protocol v1 domain-constants mirror, recomputed from their adjacent preimages by the domain recomputation checker ([PV1-IDENTITY-MODE] requirement 1; [PV1-MIRROR] rule 2); drill record in the zero-signer drill artifact | mandatory |
| Transfer controller and controlled mutation | Core transfer-controller registry, controlled mutation path, and controlled-ownership-change event family (ADR 0015 decision W4; [PV1-FACADE-READINESS]) | golden read coverage per golden test 29; controller-registration event asserted schemaVersioned against the event catalog with its `actionId` binding ([LCM-EVENTS]); controlled-mutation invariant parity (ADR 0015 decision W4): the controller-called path enforces exactly the native ownership-mutation invariant set — for transfers, the open-transfer set of current-owner match and a nonzero recipient, nothing more, because native transfers on this Core line are unconditioned and locks, finality components, and pause never gate ownership transfer in either mode ([LTA-STANDARDS]; [PV1-TRANSFER-CONTROLLER] requirement 6) — verified by running the native open-transfer invariant suite against the controlled path, plus the controlled-path burn parity gate: the native burn precondition suite — the owner/approved authorization analog, the finalized-burn block, and the one-way collection burn block ([CMC-BURN]) — executed against `controlledOwnershipChange` with `to == address(0)` ([PV1-TRANSFER-CONTROLLER] requirement 7); CEI ordering verified adversarially with a reentrant controller test double: every Core state and record-chain write settles before the ownership-change notification to the controller, the notification is the terminal step of the mutation, and the test double observes fully settled state and cannot reenter any ownership-mutation entry; negative gates, as load-bearing as the positive ones (ADR 0015 decision W4): controller registration reverts for `CORE_NATIVE` collections permanently — no path exists that later admits one — reverts at or after the collection's first mint, and reverts on re-registration (the binding is one-way); native per-token entries (`approve`/`transferFrom`/`safeTransferFrom`/the native burn entry) revert for `EXTERNAL_FACADE` collections and contract-wide `setApprovalForAll` grants convey no authority over their tokens ([PV1-TRANSFER-CONTROLLER] requirement 8); the controlled path reverts for any caller other than the registered controller and for every `CORE_NATIVE` collection; event exclusivity asserted in both modes: per ownership mutation Core emits exactly one of ERC-721 `Transfer` (`CORE_NATIVE`) or the controlled-ownership-change event (`EXTERNAL_FACADE`), the facade is the exclusive ERC-721 `Transfer` emitter for its tokens, and the assertion set includes a native-burn-attempt case — a native burn attempt on an `EXTERNAL_FACADE` token reverts with no state settlement and no Core-side event emission; the sales-seam exclusion runs as a configuration-time negative gate (ADR 0015 decision W3): sale, gate, and distribution configuration binding a custody-settling sale kind or a Stream-source burn program to an `EXTERNAL_FACADE` collection reverts with the typed error `SaleFlowClosedForFacadeCollection` at configuration time, never discovered at settlement — the exclusion scopes exactly to flows that execute native Core ERC-721 mutation entries on already-minted facade tokens or `Core.burn` on facade-mode sources, and mint-delivery kinds configure and settle identically in both modes — per the sale-layer home ([SSA-IDENTITY] rule 9), exercised by the [SSA-GATES] item 22 suite, with facade-aware adapter profiles a mandatory scope item of the tripwire review ([FCP-DEPLOYMENT]); a registered controller is a Permanent-class contract conforming to the facade profile ([`docs/stream-collection-facade-profile.md`](stream-collection-facade-profile.md)) | controller-registration and controlled-ownership-change event families in the event catalog; controller registrations in the deployment manifest | mandatory |
| Token identity | Core mint boundary, `tokenCollectionIdentity` | Core-owned token allocation, collection serial mapping, mapping-existence read, prepared-incomplete identity read, burn retained mapping; `TokenCollectionRegistered` — schemaVersioned, production signature pinned at its home [MPA-CORE-ABI] (ADR 0011 decision R12) — emitted at identity write and event-only replay rebuilds the full mapping (ADR 0010 decision D10.1; protocol v1 [PV1-RECON].9) | token identity schema | mandatory |
| Token-level metadata | collection metadata satellite | token data/field overrides, token locks, burned archival reads | token metadata schema | mandatory |
| Burn | Core burn boundary | owner/approved, mapping retained, finalized burn blocked, one-way collection burn block readable for finality ([CMC-BURN]; ADR 0010 decision D10.5) | burn policy manifest | mandatory |
| Mint accounting | mint manager, ledger, `StreamMintTicketGate` | duplicate-key aggregation, static caps, signed ticket binding; reentrancy guard on `mint()` and prepared entrypoints; `registerPhasePolicy` binds `msg.sender` to its manager argument; gate calls forward `max(gateGasLimit, MINT_GATE_GAS_LIMIT)` with returndata/nullifier bounds ([MPA-GATES]); `AuthorizerKind` enforcement with zero-`ecrecover` and non-canonical-signature negatives ([MPA-AUTHZ]); zero-increment rejection; manager-scoped nullifiers; Merkle allowlist cap mode ([MPA-MERKLE]); `GLOBAL` counter scope with reserved-constant `(0, 0)` derivation goldens ([MPA-SCOPES]); counter-continuity import ([MPA-CONTINUITY]); policy grace windows ([MPA-GRACE]); ticket revocation | policy hash schema | mandatory |
| Artist authority | `StreamArtistRegistry` plus consuming satellites | the fourteen [AA-GATES] suites: two-sided binding, sanction-required finality, consent modes (including signature-free pause in every attribution state, ADR 0011 decision R6), economics consent and royalty freeze, signature verification (ERC-1271, GGP probes, per-identity unordered nonces), key lifecycle (rotation contest windows, guardians, identity recovery, permissionless estate activation, dormancy), disputes and platform-works contests, attribution display, record-family write authority, identity archival, content authority, recovery approval, ceremony tooling, and history import (the [AA-IMPORT] commit-verify-cutover round-trip; ADR 0012 decision T4) — the ceremony-tooling suite (gate 13) is verified through the Artist ceremony rehearsal gate row below | artist registry manifest, consent/sanction schema hashes | mandatory |
| Artist ceremony rehearsal | artist signing tool and rehearsal deployment over `StreamArtistRegistry` plus consuming satellites | the full [AA-TOOLING] suite (ADR 0011 decisions R7.7 and R12): named signing tool renders a human-readable summary of every typed payload family before signature; rehearsed end-to-end onboarding through mint and finality sanction with total ceremony count and per-ceremony signing latency recorded and verified at or below the normative ceremony budget pinned at [AA-TOOLING] rule 6 — `ARTIST_CEREMONY_MAX_SIGNATURES` and `ARTIST_CEREMONY_MAX_ACTIVE_SIGNING_MINUTES` for the canonical single-artist collection's EOA leg, release-evidence ceilings the gate fails on exceeding and only an ADR may raise (ADR 0012 decision T9); the rehearsal includes at least one artist identity held by a Safe-class ERC-1271 contract wallet completing the full ceremony chain from acceptance through sanction, with its per-ceremony latency recorded separately and verified at or below the Safe-class ceremony ceiling pinned at [AA-TOOLING] rule 6 — the signature budget is shared, and the contract-wallet leg carries its own active-coordination-time ceiling, raisable only by ADR like the EOA ceilings (ADR 0014 decision V4) — and the signing tool's supported wallet classes stated in the artifact (ADR 0012 decision T5); consent-churn drift detection and stale-ceremony invalidation; independent operator-free hash recomputation tool; estate/dormancy paths exercised to staging; plus the artist's recorded acknowledgment of the disclosure-only royalty term captured during rehearsal and presented beside the affirmative-case summary — royalty-freeze right, economics-consent standing, and marketplace royalty-resolution coverage (protocol v1 [PV1-EXCL] item 1) | checksum-covered artist ceremony rehearsal artifact per [AA-TOOLING]: tool name, version, and build hash; payload summaries; ceremony-count and latency measurements with budget compliance on both legs; end-to-end time-to-first-drop record for the canonical single-artist collection — signing sessions, cumulative active signing minutes, and calendar span from binding acceptance to first public mint — with the same side-by-side competitor-comparison treatment as the collector budget artifacts, so onboarding friction is published in numbers rather than narrative; contract-wallet ceremony record and supported wallet classes; acknowledgment record with the affirmative-case summary | mandatory |
| Entropy lifecycle | entropy coordinator, provider | identity written and entropy registered before `_safeMint` callback; non-reentrant request/fulfill; single active request; no instant provider calls from mint path; `ENTROPY_REGISTRATION_GAS_LIMIT` GGP semantics ([EC-REGGAS]); `maxFeeWei` binding with pull-credit refunds ([EC-FEEBIND]); callback persistence and retry ([EP-CALLBACK]); `INSTANT` restricted to declared `LOW_SECURITY` collections; lifecycle mapping matches [EC-LIFECYCLE]; the scope-request suite ([EC-SCOPE]: registration, async-only lifecycle parity, incident recovery, commitment finality) and the reveal suite ([EC-REVEAL]: mandatory `ASYNC` reveal policy at freeze, `AT_MINT` attempt-and-catch never unwinding a mint, SLO-lapse permissionless fallback, escrow-first fee draw) per ADR 0011 decision R8; incident evidence gate ([EC-INCIDENT] rule 3 three-part check) | entropy policy manifest; measured `fulfillEntropy` gas envelope with callback margin and `VRF_CALLBACK_GAS_FLOOR` record; reveal operations manifest (owner, float, exhaustion alarms, keeper obligation, latency target — the reveal SLO and every subsystem obligation window sized against the holder's recorded worst-case latency per the [LTA-GOV] rule 6 discipline, ADR 0012 decision T5 — plus the live escrow-versus-quoted-fee margin alarm with its named top-up obligation and the post-freeze `updateRevealFeePerToken` remedy path, [EC-REVEAL] rules 8–9, ADR 0012 decision T7; rehearsal evidence) | mandatory |
| Metadata routing | metadata router, renderer | escaping, size limits, router failure behavior, ERC-4906 auth; renderer determinism static gate against each renderer version's declared read set — `STATIC` default or declared `DYNAMIC` class — and pinned golden render vectors ([MRR-DETERMINISM]; ADR 0011 decision R3); full-view and paged-chunk byte identity ([MRR-FULL-VIEW]); attribution-mirror checker — the rendered `properties.provenance.attribution` object matches the [AA-DISPLAY] home field-for-field through the [MRR-ATTRIBUTION] citation mirror, retired flat fields absent (ADR 0011 decision R7.6); offchain-mode pre-sale content binding and the coverage-deadline monitored gates ([MRR-OFFCHAIN-BINDING]; ADR 0011 decision R2) — the close-out lane under `OFFCHAIN_PRESERVATION_COVERAGE_SECONDS` and the sold-token lane of open collections under its own `OFFCHAIN_SOLD_TOKEN_COVERAGE_SECONDS` deadline (30-day genesis floor; ADR 0013 decision U3): preservation attaches to the sale itself (ADR 0014 decision V1) — at or before each token's first-sale settlement, one archive receipt of a cryptographically verifiable evidence class from an `ENDOWED` family exists for every render-critical payload, and the pinned window, running from each token's sale and never from collection close (ADR 0012 decision T2), covers only the second family and the first fixity record — with the in-window population published as a monitored operational artifact from the first sale onward | renderer and context manifests, golden render vector artifact | mandatory |
| Contract metadata | Core `contractURI()` delegation, contract-metadata satellite | ERC-7572 `contractURI()` bounded delegated read, satellite pointer, failure fallback, `ContractURIUpdated()` emitter caller set exactly as pinned at the protocol v1 Core hook table — the current metadata router resolved through Core's cached pointer, enumerated by golden test 24 (ADR 0012 decision T9; ADR 0009 decision 4) | contract-metadata manifest, selector test | mandatory |
| Marketplace collection display | collection discovery machine path ([MRR-COLLECTION-DISCOVERY]) | evidence bundle validates against [LCM-MARKETPLACE]: one schema-valid entry per pinned target per launch artist series, each demonstrating own-collection resolution (rule 3) through the published machine path; every entry backed by a standing signed integration commitment or a dated re-verification cadence (rule 6; ADR 0012 decision T9); any missing pair or mismatched entry fails the gate (ADR 0011 decision R12); the machine path this gate exercises is the normative collection-identity signal (ADR 0015 decision W1), with the contract-level and router reads owned by [`docs/metadata-router-and-renderer.md`](metadata-router-and-renderer.md) and the token-JSON member set owned by [`docs/collection-metadata-contract.md`](collection-metadata-contract.md) | checksum-covered marketplace-target manifest and display evidence bundle ([LCM-MARKETPLACE]) | mandatory |
| Marketplace royalty resolution | Core-native ERC-2981 read path plus per-target royalty plumbing ([LCM-MARKETPLACE] rule 4) | per pinned target per launch artist series: hash-pinned evidence that the target's resolved receiver and bps match a live `royaltyInfo()` read at capture time; the shared royalty-registry entry is recorded (address and registration transaction) for targets that resolve shared contracts through it, and per-marketplace royalty configuration state is recorded for targets that do not (ADR 0011 decision R12); caller-stipend compatibility recorded per entry — the pinned integrator's forwarded gas proven above the [RSR-2981-GAS] precheck threshold at genesis and modeled raise-chain values ([LCM-MARKETPLACE] rule 4; ADR 0014 decision V7); every entry backed by a standing signed integration commitment or a dated re-verification cadence (rule 6; ADR 0012 decision T9) | royalty-resolution entries in the marketplace evidence bundle ([LCM-MARKETPLACE]) | mandatory |
| Marketplace integration commitments | release evidence set over the collection-identity signal (ADR 0015 decision W2; [LCM-MARKETPLACE] rule 7) | before the first public sale, at least two commitments from named major marketplaces or indexers to consume the ADR 0015 decision W1 collection-identity signal and render per-collection identity, each satisfying the [LCM-MARKETPLACE] rule 7 evidence class and its pinned counterparty qualification — a named counterparty from the rule 1 pinned marketplace-target manifest, a dated written artifact, verifiable authenticity, recorded in the release evidence set, with at least one of the two commitments from a rule 1 top-two target or a named major independent indexer; best-effort outreach and commitments memorialized only in conversation explicitly do not satisfy this gate, and the [LCM-MARKETPLACE] rule 6 owner-signed risk acceptance does not substitute here; if the gate is unmet at the public-sale boundary the facade tripwire fires (ADR 0015 decision W3): the facade profile advances automatically to its deployment-decision procedure ([FCP-DEPLOYMENT], [`docs/stream-collection-facade-profile.md`](stream-collection-facade-profile.md)), and a public sale may open under an unmet commitment count only with the tripwire outcome — the dedicated adversarial review record and the recorded protocol-owner go/no-go — in the release evidence set; a no-go outcome, or a go with no facade yet bound for the launch collections, does not waive the exposure: the release evidence must then additionally carry an owner-signed risk-acceptance record following the rule 6 pattern, naming the unmet commitment count, the outreach record, and the accepted per-collection display exposure (ADR 0015 decision W3) | commitment artifacts per [LCM-MARKETPLACE] rule 7 and, where the tripwire fired, the [FCP-DEPLOYMENT] decision record — plus, on a no-go or a go with no facade yet bound, the rule 6-pattern owner-signed risk-acceptance record — hash-covered in the release evidence set | mandatory |
| Collection metadata | metadata contract plus metadata satellites | typed v1 fields, generic records, locks, snapshots, aggregate function-count and bytecode ceiling; token content roots publishable and verified pre-finality ([CMC-CONTENT-ROOT]); per-lane record-chain accumulators ([CMC-RECORD-CHAIN]); every schema in the pinned genesis set — the [CMC-GENESIS-SCHEMAS] table owns the list — present with matching IDs and hashes, worked examples validating (ADR 0011 decision R11; ADR 0012 decision T8; ADR 0013 decision U8; ADR 0014 decision V9); PREMIS crosswalk export round-trip ([CMC-PREMIS-PROFILE]); artist content-consent and content-freeze enforcement on content-affecting families ([CMC-ARTIST-CONTENT-VETO]; ADR 0011 decision R7.2); conservation tier declared at collection creation, one-way and immutable from first mint, with undeclared collections defaulting to museum-grade-lite — intent, rights record, and preservation masters for the media class, interview waivable — so floor absence is a declared choice, never a silent default (ADR 0014 decision V8); the pre-first-sale conservation floor — intent or waiver, interview entry, rights record, and preservation masters for the media class, still-image works included for museum-grade and display derivatives never satisfying the master slot for any media class (ADR 0014 decision V1) — verified at the sale boundary and a floorless settlement a monitored incident ([CMC-MUSEUM-GRADE]; ADR 0013 decision U8) | schema and snapshot manifests, metadata aggregate ABI/bytecode report | mandatory |
| Owner records | `StreamOwnerRecords` | ownerOf-gated, signature-verified, append-only owner families (`ACCESSION`, `CONDITION_REPORT`, `EXHIBITION`, `LOAN`, `DEACCESSION`, `CITATION`, plus the ADR 0014 additions pinned at the home — `VALUATION`, `STEWARD_DESIGNATION`, and `RECOVERY_RESPONSE` (ADR 0014 decision V8) and `REDEMPTION_CLAIM` (ADR 0014 decision V5)), `TITLE_BINDING` schema, firewalled from render/finality/economics ([CMC-OWNER-RECORDS]); record-family grant-set verification across all genesis satellites — the CON-015 whole-module writer exception is retired ([CMC-AUTHZ], [AA-RECORDS]; ADR 0010 decision D2.8) | owner-records module manifest, grant map artifact | mandatory |
| Preservation records | `StreamPreservationRecords` | PREMIS-style event/object/agent/right records, fixity hash validation, event reconstruction, post-freeze record behavior | preservation module manifest, schema hashes, code hash | mandatory |
| Collection attestations | `StreamCollectionAttestations` | C2PA/EIP-712/ERC-1271-compatible attestations, onchain verification at write for signer-verified classes, signer authority, supersession, event reconstruction ([CMC-ATTESTATIONS]); artist-attestation surface field inventory matches the [AA-ATTEST] home through the [CMC-ARTIST-ATTESTATION] checker row; independent-attestor lanes — permissionless entry, signer-verified writes under `STREAM_INDEPENDENT_PRESERVATION_TYPEHASH`, firewall, unblockability with locks/freezes/finality present, and the `INDEPENDENT_EXPORT_MIRROR` record type carrying archive-receipt-shape payloads with registered-family resolution so post-operator export reproductions are locatable from state ([CMC-INDEPENDENT-ATTESTOR]; ADR 0011 decision R11; ADR 0014 decision V2); `METADATA_ERC1271_VERIFY_GAS` floor/raise/lower/probe tests on every verifying metadata satellite ([CMC-SIGVER-GGP]; ADR 0011 decision R10) | attestation module manifest, schema hashes, code hash | mandatory |
| Collection views | `StreamCollectionViews` | IIIF/view URI commitments, accessibility/display view references, bounded reads, event reconstruction | view module manifest, schema hashes, code hash | mandatory |
| Institutional validation | dossier and acquisition-packet generation over the metadata, owner-records, preservation, attestation, and view satellites ([CMC-OBJECT-DOSSIER], [CMC-ACQUISITION-PACKET], [CMC-PREMIS-PROFILE]) | registrar-rehearsal evidence mirroring the artist ceremony rehearsal gate (ADR 0013 decision U8): (a) end-to-end ingest of a generated `OBJECT_DOSSIER_V1` bag into two independent named open-source OAIS-modeled repository stacks — one OCFL/Fedora-class and one Archivematica-class AIP path (ADR 0014 decision V8) — through each stack's normal ingest path, with the stack names, versions, ingest configurations, and ingest reports hash-committed as release evidence — synthetic checks alone (PREMIS validator round-trips, BagIt profile validation, packet regeneration) do not satisfy this gate; (b) a recorded review of the genesis museum schema set, the PREMIS crosswalk, and the acquisition-packet workflow by two named external practitioners spanning both professional roles — registrar/collection-management and time-based-media conservation (ADR 0014 decision V8) — or a standing institutional commitment following the [LCM-MARKETPLACE] rule 6 pattern covering the same two roles, with every review finding dispositioned before the museum-facing metadata specs enter Review ([LCM-REVIEW-ENTRY] condition 6) | checksum-covered institutional-validation bundle: ingest report hashes for both stacks, reviewer identities and review record hashes for both roles, disposition log | mandatory |
| Entropy fallback provider | entropy coordinator, reviewed fallback provider | reviewed ARRNG or Pyth fallback provider shipped alongside VRF (ADR 0009 decision 21); VRF-only deployment fails this gate; coordinator failure mode matches the retained decision manifest | checksum-covered `release-artifacts/latest/entropy-launch-decision.json` or equivalent release-manifest record | mandatory |
| Artwork finality | Core plus satellites | typed finality preimage, pointer race, `verifyFinality`; token content root recorded before any finality in every metadata mode ([CMC-CONTENT-ROOT]); `REFERENCE_RENDER` component for script-based works with capture-environment manifest, archived runnable execution-environment artifact under dual-family fixity coverage, and exactly one pinned acceptance mode — `BYTE_EXACT` only with pinned software rasterization, `DYNAMIC`-class renderers excluded from `BYTE_EXACT` ([LTA-FINALITY] requirement 12, [CMC-FINALITY-INPUTS], [MRR-FINALITY]; ADR 0011 decision R3); the reference-render capture set and the archived execution-environment artifact ride the script-work sale-follows preservation lane for `ONCHAIN` and hybrid script collections — recorded within the pinned `SCRIPT_SOLD_WORK_COVERAGE_SECONDS` window of first-sale settlement ([MRR-SCRIPT-COVERAGE]) — so finality verifies these artifacts rather than first creating them, and the museum-grade pre-first-sale floor requires them, environment artifact included, before the first sale (ADR 0014 decision V1); `ARTIST_SANCTION` or `PLATFORM_WORKS_DECLARATION` component verified ([AA-SANCTION], [AA-PLATFORM]); artist intent record with interview reference or recorded waiver ([CMC-ARTIST-INTENT]; ADR 0011 decision R11), with the work-description (tombstone) record and the interview entry or its recorded waiver blocking at finality for every collection, not only museum-grade — absence fails finality rather than logging a warning ([CMC-TOMBSTONE]; ADR 0014 decision V8); rights record present for artist-bound collections ([CMC-RIGHTS-SCHEMA]; ADR 0011 decision R11); dual-family archival receipts with schema-valid evidence classes — at least one cryptographically verifiable receipt per payload, operator assertion alone rejected, at least one `ENDOWED` family per render-critical payload — plus passing per-family fixity records from a verifier distinct from the writer ([LTA-ARCHIVE], [CMC-RECEIPTS]; ADR 0011 decision R4); collection scope requires `CLOSED` plus the one-way burn block (ADR 0010 decision D10.5) | finality manifest | mandatory |
| Governed gas and time parameters | every GGP/GTP host (Core, factories, coordinator, router, registries, satellites) plus the Permanent-class probe contracts ([LTA-GGP-PROBES]) | per gas parameter, the [LTA-GGP] requirement 9 suite (ADR 0011 decision R5; ADR 0012 decision T1): immutable floor enforced; staged raise on the normal delay class with the 2x per-action raise bound rejected above it; emergency raise probe-gated (healthy probe record blocks, recorded failing run at the current value admits); lower requires a recorded passing probe run at exactly the proposed value within `probeMaxAgeBlocks` through the named probe contract and can never cross the floor; permissionless conditional raise and permissionless conditional re-lower each executed with no governance signer for every `FORWARDING_CAP` parameter — the raise gated on a recorded failing probe run at the current value, the re-lower on a recorded passing probe run at exactly the proposed lower value, both bounded per action (ADR 0014 decision V7) — plus the scope-rejection test proving no conditional-raise or conditional-re-lower action exists — or that its execution reverts — for every `FAIL_CLOSED_PRECHECK` and `MIN_GAS_GATE` parameter, whose raises are governance-only, with the [LTA-GGP] requirement 10 reclassification rule extending that set to every parameter whose precheck shortfall reverts a user entry or settlement call (ADR 0014 decision V7); the forged-failure probe-integrity test — an under-funded or input-shaped probe call reverts without recording a failing run, probes execute only their pinned per-parameter input corpus, and probe-run records live on the probe contract ([LTA-GGP-PROBES] rules 3–5); the zero-governance-signer museum-mode drill executing the probe-gated conditional-raise and conditional-re-lower chains end to end against the deployed probes ([LTA-GGP-PROBES] rule 9; ADR 0014 decision V7); per Governed Time Parameter, the [LTA-GTP] discipline suite — floor rejection against both block and wall-clock floors, per-action raise and lower bounds, cadence-probe-gated lower, change events, and the negative test that no emergency or permissionless conditional path exists (ADR 0012 decision T1); a spec checker asserts exactly one probe definition and one pinned failure-direction class per [LTA-GGP] inventory row at its home — what the probe executes, the faithful equivalent for permissioned paths, and what `evidenceHash` commits to — mirroring the GGP-identifier completeness rule (ADR 0012 decision T1); change events with old/new values; excluded from finality manifests, frozen-route identity, and economic preimages — all per the pattern homes ([LTA-GGP], [LTA-GTP]; ADR 0010 decision D1) and their full inventories | GGP/GTP inventory with genesis values, floors, named Permanent-class probe contracts, `probeMaxAgeBlocks` at or above `PROBE_MAX_AGE_FLOOR_BLOCKS` ([LTA-GGP-PROBES] rule 6; ADR 0012 decision T1), failure-direction classes (`FORWARDING_CAP`/`FAIL_CLOSED_PRECHECK`/`MIN_GAS_GATE`), and `FORWARDING_CAP`-only conditional-raise and conditional-re-lower registrations plus per-row fixed-stipend inventories in the release manifest (ADR 0014 decision V7); zero-signer drill artifact; repricing review checklist | mandatory |
| Governance | governance/timelock, role registry | no single EOA, role map cardinality, delays; canonical action ID and atomic batch execution ([GOV-ACTION-ID], [GOV-BATCH]); material-action holder classes with the time-boxed EOA bootstrap sunset recorded in ceremony evidence ([GOV-MATERIAL]; ADR 0011 decision R10); material-action executability rehearsal (ADR 0012 decision T5): on the rehearsal deployment a Safe and the pinned reference governor — a named governor implementation of the [GOV-MATERIAL]/[GOV-1271-CLASS] holder class with a timelock executor, a declared ERC-1271 posture, and nonzero voting delay and period, never an instant-execution mock, its implementation name and code hash recorded in the release manifest (ADR 0014 decision V4) — each execute one action of every material class end to end — schedule, cancel, execute including a nonzero-`msg.value` payable call, veto a terminal freeze, pause and unpause, one GGP raise and one probe-gated lower, one pointer move, one role grant — recorded as checksum-covered release evidence, with the artifact recording the reference governor's full proposal-to-execution latency as the presumptive governor-class latency seeding the deployment-manifest latency records ([LTA-GOV] rule 6; ADR 0014 decision V4) and including a nonzero-value native ETH transfer to the resolved holder of every role designated as a native-value recipient — `ROLE_EMERGENCY_RECIPIENT` and the reveal-fee residual destination included ([GOV-ROLES]) — so value-receiving roles are rehearsed as recipients, never only as senders (ADR 0014 decision V4); window floors, the 72-hour terminal-freeze veto floor, and dedicated unpause role ([GOV-WINDOWS]) with pause/unpause holder disjointness keyed on the durable `ROLE_PAUSE_GUARDIAN` and unpause role constants ([GOV-ROLES]; ADR 0012 decision T5); window/latency compatibility is a standing obligation, never only a ceremony check (ADR 0014 decision V4): every post-genesis grant or transfer of a window-obligated role ([LTA-GOV] rule 6) records the new holder's worst-case execution latency in the action manifest and re-runs this compatibility check at execution — every window and SLO the role must meet satisfies latency plus margin, or a live guardian-module authorization covering the capability lands in the same atomic batch ([LTA-GUARDIAN]) — a handover without a passing latency proof is nonconformant, ETH receivability is rechecked at role-grant execution for value-receiving roles, and recorded holder latencies join the recurring-obligation calendar so holder drift (a Safe raising its threshold, a governor lengthening its pipeline) re-triggers review; every governor-held defensive role is exercised through its registered guardian module in rehearsal or held by a Safe with recorded latency inside the emergency assumption ([LTA-GUARDIAN]; ADR 0012 decision T5); long-lived authorities are role references resolved through the admin registry, not raw addresses (ADR 0010 decision D7.4), and named-executor entries in the action policy catalog are [GOV-ROLES] role references — a raw-address executor entry fails catalog validation (ADR 0012 decision T5); non-material operational grants held by EOAs carry a declared sunset review cadence (ADR 0012 decision T5); entropy-provider operational authorities contract-held with rehearsed rotation ([EP-CUSTODY]); at least one registry-`ACTIVE` pre-approved fallback target registered per critical pointer family at genesis with a rehearsed permissionless move recorded as release evidence, the fallback-target inventory artifact enumerating exactly the genesis profile's fallback entries ([LTA-POINTERS] rule 11; ADR 0011 decision R10; ADR 0012 decision T1) | genesis governance manifest, governance action policy catalog, material-action rehearsal evidence, fallback-target inventory | mandatory |
| Collector gas budget | both paid mint paths, genesis sale adapters | measured all-cold end-to-end collector transaction gas for `PRE_REVENUE_SINGLE_STEP` and `PREPARED_MINT` (single and batch of 10), free allowlisted mint, fixed-price and Dutch purchases, each at or below the normative not-to-exceed ceiling pinned per path in [MPA-GAS-BUDGET] (ADR 0011 decision R12; ADR 0010 decision D5.10) — the ceilings are spec values, not report values, so exceedance forces path slimming before deployment and is never remediable by editing the report; side-by-side measured comparison against the named competitor mint paths listed in [MPA-GAS-BUDGET] recorded in the artifact; measured all-cold per-mint and wallet-to-wallet per-transfer gas for the enumerable-free Core recorded per [LTA-TRADEOFFS] item 2 (ADR 0012 decision T10, superseding the ADR 0010 decision D9.3 enumerable-overhead artifact); the artifact also records the expected all-warm collector gas per path beside the all-cold ceilings — warm-path cost is what most minters in a drop pay — and an editions-cost line stating the measured per-unit cost of an edition of N minted as N sequential ERC-721 serials at the batch marginal rate, citing the [SSA-EDITIONS] posture and the protocol v1 collector cost position ([PV1-SCOPE]) beside the numbers (ADR 0013 decision U9) | checksum-covered gas budget artifact with per-path ceiling compliance, all-warm and editions-cost lines, and competitor comparison | mandatory |
| Collector interaction budget | genesis sale adapters, both paid mint paths, claim router | per-sale-kind collector interaction inventory measured end to end on the rehearsal deployment (ADR 0013 decision U9): onchain transactions and typed signatures per purchase for every genesis sale kind and mint path — including refund-window finalization ([SSA-REFUND]), commit-reveal second transactions ([SSA-CONTENT] rule 7), auction settlement and pull-credit claims, ERC-20 `PaymentIntent` signatures ([RSR-PAYMENT-INTENT]), and delegated flows — published with the same side-by-side competitor comparison treatment as the collector gas artifact; the inventory is release-evidence measurement with the parallel role of [MPA-GAS-BUDGET] for checkout friction, and reducing a step count never bypasses a specified consent, refund, or commit-reveal protection; the inventory is deliberately measured, not ceilinged, at genesis — the consent, refund, and commit-reveal protections set the step floor, and pinning per-sale-kind not-to-exceed interaction ceilings in the [MPA-GAS-BUDGET] pattern is reserved to a later ADR once rehearsal measurements exist, so the friction position is published and compared rather than silently drifting or prematurely frozen | checksum-covered collector interaction budget artifact with competitor comparison | mandatory |
| Fixity program | preservation records, operations | mandated fixity schedule (annual full sweep, quarterly sampling), `FIXITY_CYCLE_COMPLETED`/`FIXITY_FAILURE` records, repair-from-mirror and escalation policy ([CMC-FIXITY-PROGRAM]; ADR 0010 decision D6.3); the sold-token coverage lane of open collections is inside the mandated schedule and the monitored-incident regime (ADR 0012 decision T2) | deployment-gated fixity operations manifest | mandatory |
| Reconstruction client | archival reconstruction client | client exists at genesis and rebuilds every [PV1-RECON] item — event-only where the home requires event replay, state-recovered for the renderer-input `tokenData` surface exactly as [PV1-RECON] carves it out; source-archive hash matches `streamSystemManifest().reconstructionClientHash`; replay test vectors pass in CI; reproducible-build instructions verified (ADR 0010 decision D4.8); registrar tooling scope (ADR 0012 decision T8): the gated client (or a dedicated registrar tool archived and hash-recorded exactly like it, per [CMC-OBJECT-DOSSIER]) regenerates an `OBJECT_DOSSIER_V1` dossier and a `STREAM_ACQUISITION_PACKET_V1` packet from chain state with zero operator involvement and verifies every pinned component — record-chain heads, the content-root proof, the ownership-provenance chain, and the drill outcome — never only static worked-example schema validation ([CMC-OBJECT-DOSSIER], [CMC-ACQUISITION-PACKET]), and a packet-regeneration step joins the museum-mode and preservation drill lists ([CMC-OBJECT-DOSSIER] rule 2) | client source archive hash, replay vector artifact, dossier/packet regeneration vectors, drill cadence in ops runbook hashes | mandatory |
| Funding manifest | operations | published funding/endowment manifest naming the source, coverage horizon, and exhaustion alarms for keepers, entropy fees, storage mirrors, fixity cycles, and drills; each recurring obligation names its funded operational owner (ADR 0010 decision D4.8); every storage family carries its economics class (`ENDOWED`/`RENEWAL_FUNDED`) and the gate fails if any render-critical payload has no `ENDOWED` family ([LTA-FUNDING] rule 1, [LTA-ARCHIVE] requirement 3; ADR 0011 decision R4); every storage family carries its independence classification under the pinned storage-family taxonomy, and the manifest carries the family-extinction migration reserve line — the funded successor-family election, re-upload-with-receipts, and fixity re-baseline obligation that triggers within its pinned window when a family's viability indicator fails ([LTA-FUNDING], [LTA-ARCHIVE]; ADR 0014 decision V2); the protocol-endowment decision is stated explicitly either way ([LTA-FUNDING] rule 3); the entitlement-indexer operator for recipient claim discovery is named ([RSR-CLAIM-ROUTER] rule 6); the manifest carries a costed operating model — estimated person-hours and fees per recurring obligation per year — and the coverage horizon is measured against that computed annual cost, so exhaustion alarms guard a number that was actually computed (ADR 0012 decision T9); the stated coverage horizon meets the viability floor pinned at [LTA-FUNDING] against that costed annual total, and the consolidated obligation-calendar artifact — every recurring obligation with its cadence, maximum staleness, funded owner, automation-or-manual posture, and estimated annual cost, summing the annual load to one reviewable number — is present and consistent with the gated manifests (ADR 0013 decision U9) | checksum-covered funding manifest and consolidated obligation-calendar artifact | mandatory |
| Claim aggregation | claim router periphery | permissionless `claimMany`/`syncAndClaimMany`, release-to-self only, continue-on-failure mode, one-transaction aggregated claiming across at least 20 wallets ([RSR-CLAIM-ROUTER]; ADR 0010 decision D10.6); rehearsed end-to-end recipient claim flow recorded as release evidence — event-only entitlement discovery, `syncAsset`, and the 20-wallet `claimMany` run ([RSR-CLAIM-ROUTER] rule 6; ADR 0011 decision R12) | claim router manifest, recipient claim rehearsal artifact | mandatory |
| Events | every subsystem | event reconstruction, supersession map | event catalog hash | mandatory |
| Operations | monitoring/export/storage | degraded-admin test, state export with metadata/record-chain roots, storage redundancy, export cadence per the umbrella schedule; recurring-obligation staleness monitoring computes latest export age from `latestStateExport()` ([LTA-EXPORT]), latest fixity-cycle age from `FIXITY_CYCLE_COMPLETED` records ([CMC-FIXITY-PROGRAM]), and guardian-module authorization age against the recorded renewal cadence with the alarm at or before 80% of authorization lifetime ([LTA-GUARDIAN] rule 7; ADR 0013 decision U5), and the published missed-cadence policy declares a monitored incident on any exceeded maximum staleness ([LCM-GENESIS] recurring obligations; ADR 0011 decision R12); state exports and event-history snapshot chunks carry dual-family archival receipts — at least one `ENDOWED` family — with fixity coverage, as the designated EIP-4444 bridge ([LTA-ARCHIVE]; ADR 0012 decision T3); the genesis spec bundle is verified (ADR 0014 decision V9): the published content-addressed bundle named by the deployment manifest's `specBundleHash` ([LTA-MANIFEST]) enumerates every specification-inventory document at Final status with per-document content hashes, the bundle hash recomputes from the enumerated contents, and the bundle carries dual-family archival receipts with fixity coverage as the preservation object it is declared to be ([LTA-ARCHIVE]); a standing vulnerability-disclosure policy is published and hash-committed — security contact, response SLO, and the explicit bounty/no-bounty decision — with its funded owner named in the funding manifest (ADR 0012 decision T9) | ops runbook hashes, missed-cadence policy hash, disclosure-policy hash | mandatory |

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
   records that configuration state. Each target's entry additionally
   records the caller-stipend compatibility check (ADR 0014 decision
   V7): the gas the target's onchain `royaltyInfo()` read path
   forwards — fixed 2300-gas-class stipends and capped `staticcall`
   wrappers included, per the fixed-stipend inventory the [LTA-GGP]
   release-manifest rows carry for `ROYALTY_RESOLVER_GAS_LIMIT` and
   `ROYALTY_RETURN_GAS_BUFFER` — proven to exceed the minimum parent
   gas the [RSR-2981-GAS] precheck implies at genesis values and at
   the maximum raise-chain values the repricing review models, so a
   raised threshold never silently zeroes a pinned integrator's
   onchain royalty read while `eth_call` readers see service restored.
5. Either gate fails on any missing (target, series) pair, any
   schema-invalid entry, or any mismatch between an entry and its pinned
   expectation. The collection-identity signal itself is owned by its
   ADR 0015 decision W1 homes; this section pins evidence, not the
   signal.
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
   The two highest-volume pinned targets must each carry a standing
   integration commitment — a named-target letter per (a) — before
   public sale (ADR 0013 decision U9); where a top-two commitment is
   not obtained, the gate passes only with both the dated
   re-verification cadence of (b) for that target and an owner-signed
   risk-acceptance record — a named ceremony artifact in the release
   evidence recording the target, the outreach attempts, and the
   accepted exposure — never a bare deviation note. A target carrying
   neither a commitment nor a cadence fails the gate.
7. W1-signal commitment evidence class (ADR 0015 decision W2). A
   qualifying collection-identity integration commitment is a named,
   signed, dated written artifact from the counterparty — recording the
   counterparty, the signer identity, the date, and a scope covering
   consumption of the ADR 0015 decision W1 collection-identity signal
   and per-collection identity rendering — with verifiable
   authenticity: a signature or an equally attributable channel record
   whose verification method the entry names, hash-covered in the
   release evidence set. Best-effort outreach, intent statements
   without a named signer, and conversations memorialized only by the
   operator do not qualify. Counterparty qualification is pinned, never
   judged at gate time (ADR 0015 decision W2): a qualifying commitment
   must come from a counterparty named in the rule 1 pinned
   marketplace-target manifest — adding a counterparty is the reviewed
   release-artifact change rule 1 defines, never a gate-time
   substitution — and at least one of the two required commitments must
   come from a rule 1 top-two target or a named major independent
   indexer in that manifest, so two schema-perfect commitments from
   negligible venues can never satisfy the gate. The commitment-evidence
   checker ([LCM-TOOLING]) validates every recorded commitment against
   this class and this qualification, and the marketplace integration
   commitments gate row consumes it.

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
exhaustive: 58 deployable production contracts — the 35 numbered
entries below plus the twenty-three Permanent-class probe contracts of
entries 36–58: one probe per [LTA-GGP] inventory row (twenty-two at
this revision, `REVEAL_ATTEMPT_GAS_LIMIT` and
`SALE_NFT_DELIVERY_GAS_LIMIT` included; ADR 0013 decisions U6 and
U7) and the shared entropy cadence probe serving the three
[LTA-GTP] genesis instantiations ([EC-TIME]) — plus per-collection
split wallets created on demand by `CREATE2` through the factory.
That sentence is the single owning statement of the inventory count
(ADR 0014 decision V9): every other mention — in this document, the
other specs, and the release artifacts — cites this profile without
restating a numeral, so the count can never self-contradict, and the
prose-count checker ([LCM-TOOLING]) asserts the numbered entries, the
probe entries, and the stated total against each other.
Growth is same-change: a spec amendment that adds an [LTA-GGP]
inventory row or an [LTA-GTP] instantiation (ADR 0012 decision T1), or
a deployment manifest that names an additional critical pointer family
([LTA-POINTERS] rule 11), lands with its probe or fallback entry here
and the updated count. Governed Gas Parameter stores are storage
surfaces of the listed contracts (Core and the split factory parameter
store), not separate deployments. The facade-readiness surfaces —
per-collection identity mode, the transfer-controller registry, the
controlled mutation path, and the controlled-ownership-change event
family (ADR 0015 decision W4) — are likewise storage, interface, and
event surfaces of `StreamCore` (entry 1), not separate deployments;
the per-collection ERC-721 facade line is a dormant extension profile
([`docs/stream-collection-facade-profile.md`](stream-collection-facade-profile.md);
ADR 0015 decision W5), physically absent at genesis, so this
inventory's count is unchanged by ADR 0015. Probe contracts are Permanent-class
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
36-57 Per-parameter GGP probe contracts, one per [LTA-GGP] inventory
   row (twenty-two at this revision, REVEAL_ATTEMPT_GAS_LIMIT and
   SALE_NFT_DELIVERY_GAS_LIMIT included; ADR 0013 decisions U6 and
   U7), Permanent-class under
   [LTA-GGP-PROBES] (ADR 0012 decision T1)
58 Shared entropy cadence probe for the three [LTA-GTP] genesis
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

Entry 2 is the one deliberately disjunctive inventory entry (ADR 0014
decision V9): the governance layer is named by its ADR 0004 obligation
because the concrete contract name is a deployment-manifest fact — the
deployment manifest and the onchain system-manifest payload name the
single deployed governance contract, this entry pins what that
deployment must satisfy (the ADR 0004 timelock/role layer), and the
protocol v1 pinned-name glossary records the matching
`STREAM_ADMINS_OR_GOVERNANCE` vocabulary note. Every other entry names
its concrete genesis deployment directly.

Entries 34–35 are the standing incident path required by
[LTA-POINTERS] rule 11: the Governance gate's fallback-target inventory
artifact enumerates exactly these entries (plus any critical family the
deployment manifest adds), each with its registry status and the
rehearsed permissionless emergency move recorded as release evidence,
and the deployment manifest's critical-family list and this profile
must name the same families (ADR 0012 decision T1).

This profile document is the human mirror of the canonical onchain
system-manifest payload, never the bootstrap (ADR 0013 decision U2):
the full deployment inventory — every genesis contract, probe binding,
fallback target, and registry instance — is stored as onchain bytes
under the [LTA-CATALOGS] onchain-bytes regime, named by
`streamSystemManifest()` through a state-readable pointer
([LTA-MANIFEST]), so a state-only archivist locates the inventory with
no document on the discovery path (golden test 28). Where this profile
and the onchain payload diverge, the onchain payload wins and the
divergence is a release-blocking defect.

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
production inventory, whose count is owned solely by the inventory
statement above (ADR 0014 decision V9); every identity preimage
continues to bind deployed addresses and code hashes, so determinism
is an auditability property of
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
audit to public sale. The plan is staged in named audit waves
(ADR 0013 decision U9): every inventory contract is assigned to exactly
one wave; each wave is sized in auditor-weeks with entry and exit
criteria; and subsystem staging is explicit — the revenue, mint, and
Core wave may enter audit while the museum satellites finish
specification, with cross-wave interface freezes recorded so a later
wave cannot move an earlier wave's audited surfaces. The critical-path
schedule with dated wave milestones is published as a checksum-covered
release artifact at Review entry ([LCM-REVIEW-ENTRY] condition 5), not
assembled at the deployment ceremony. Every gate in this matrix stays
launch-blocking —
the owner-ratified posture accepts shipping later over shipping unproven
(ADR 0010 decision D5.10) — and the critical-path schedule is how that
shipping risk is managed, never a mechanism to defer or downgrade gates.

Recurring post-launch obligations have teeth (ADR 0011 decision R12).
Fixity cycles, state exports, preservation and reconstruction drills,
funding-manifest renewals, marketplace display and royalty
re-verification for cadence-backed targets ([LCM-MARKETPLACE] rule 6;
ADR 0012 decision T9), the sunset reviews of non-material
operational grants held by EOAs (ADR 0012 decision T5), the
holder-latency records of window-obligated roles — re-verified on
every handover and reviewed for drift on a declared cadence (ADR 0014
decision V4) — and the storage-family viability review of the
family-extinction rule ([LTA-FUNDING]; ADR 0014 decision V2) each
declare a cadence and a maximum staleness in their gated manifests,
and each names its funded
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

Two disciplines keep the recurring load carryable (ADR 0013 decision
U9). First, every recurring obligation appears in the consolidated
obligation-calendar artifact gated with the funding manifest — cadence,
maximum staleness, funded owner, automation posture, and estimated
annual cost per obligation — so the total annual load is one reviewable
number rather than facts scattered across the gated manifests, and the
funding manifest's coverage horizon is measured against that number
([LTA-FUNDING]). Second, computable obligations — export publication,
fixity sampling, staleness monitoring, re-verification reminders —
should run through keeper-class Operational automation, with each
obligation's automation-or-manual posture recorded in the calendar and
any manual-only posture carrying a recorded rationale.

Specified but optional-at-genesis surfaces (the only `conditional`
surfaces; each activates its own gate rows through its accepted ADR):

```text
Custom counter resolvers
Resolver-defined caps/deltas
Privacy nullifiers
CCIP Read and future onchain web adapters
Non-standard ERC-20 primary adapters
Sealed-bid and ranked auction implementations (frozen extension profiles)
Per-collection ERC-721 facade contracts (dormant extension profile,
  [`docs/stream-collection-facade-profile.md`](stream-collection-facade-profile.md);
  deployable only through the ADR 0015 decision W3 procedure at
  [FCP-DEPLOYMENT])
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
would. The facade-readiness Core surfaces are likewise not in the
optional list: ADR 0015 decision W4 ships them at genesis, dormant, as
mandatory Core surfaces with full gate coverage (the collection
identity mode and transfer controller and controlled mutation gate
rows), so the ADR 0015 decision W3 fallback never requires a Core
redeployment. Only the facade contracts themselves are conditional:
a facade deployment without the [FCP-DEPLOYMENT] decision record and
the facade profile's activated gate coverage fails this matrix.

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
10. Any contract in the genesis deployment profile, or any module
   registered in the module registry, contains `SELFDESTRUCT`,
   unrestricted `DELEGATECALL`, or mutable proxy upgrade hooks — the
   immutability leg is unconditional across the production inventory
   ([LCM-FORBIDDEN] item 14; ADR 0013 decision U7), with no
   per-contract "promises immutability" qualifier, because every
   deployed implementation is itself immutable by permanence class
   ([`docs/spec-policy.md`](spec-policy.md)) — or any production
   read surface performs unbounded returndata copies outside explicitly
   allowed test/migration mocks.
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
    hash, numeric ID allocation hash, `specBundleHash` — the
    content-addressed hash of the published genesis spec bundle
    ([LTA-MANIFEST]; ADR 0014 decision V9) — and reproducible-build
    artifact hashes for every deployed satellite, plus the
    deterministic-deployment record — deployer factory address,
    per-contract `CREATE2` salts, and init-code hashes sufficient to
    recompute every genesis address from the manifest alone (ADR 0011
    decision R10).
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
    `SaleConsentScope`, `RegistryImmutabilityElection` (a `uint8`
    input to `ARTIST_BINDING_DOMAIN`; ADR 0013 decision U4), the
    [LTA-GGP] failure-direction class IDs (ADR 0013 decision U2), the
    [LTA-GUARDIAN] capability bits, and
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
    `lastAllocatedCollectionId()` is the same-shape Permanent storage
    read over dense sequential collection-ID allocation from 1, and a
    state-only walk over `1..lastAllocatedCollectionId()` reaches every
    created collection, minted or not (protocol v1 [PV1-IDENTITY]
    item 7; ADR 0013 decision U2).
28. State-only payload discovery ([LTA-PAYLOAD-DISCOVERY]; ADR 0012
    decision T3): every SSTORE2/storage payload family exposes its
    host's storage-backed discovery surface — the enumerable pointer
    registry (count plus paged pointer/family/hash rows,
    [CMC-PAYLOAD-POINTERS]) or the typed pointer field on an
    exhaustively keyed record read — and a state-only client locates
    every onchain payload byte through those reads without consulting
    any log. The system-manifest payload is itself a member of this
    rule (ADR 0013 decision U2): the full genesis inventory payload is
    onchain bytes behind the state-readable pointer named by
    `streamSystemManifest()` ([LTA-MANIFEST], [LTA-CATALOGS]), and the
    test bootstraps the complete payload set from
    `streamSystemManifest()` and storage-backed reads alone — no
    offchain document, the genesis deployment profile included, sits on
    the discovery path. The module registry's append-only enumeration
    index is part of the same state-only walk (ADR 0013 decision U2):
    the test enumerates every registered module through
    `moduleCount()`/`moduleAt(index)` ([LTA-REGISTRY] requirement 6),
    and verifies that `registrationChainHash()` returns
    `recordCount == moduleCount()` with a chain hash equal to the
    accumulator recomputed over that walk under
    `STREAM_MODULE_REGISTRATION_RECORD_V1` ([LTA-REGISTRY]
    requirement 7).
29. `collectionIdentityMode(collectionId)` returns a member of the
    closed identity-mode vocabulary — `CORE_NATIVE` (default) or
    `EXTERNAL_FACADE` — with an undeclared collection reading
    `CORE_NATIVE` by construction,
    `collectionTransferController(collectionId)` returns the one
    registered controller for an `EXTERNAL_FACADE` collection and the
    zero value otherwise, and
    `totalSupplyOfCollection(collectionId)` returns the collection's
    live token count — minted minus burned — identically in both
    modes; all three are Core storage reads, never reconstructed from
    token ID ranges or offchain convention ([PV1-FACADE-READINESS];
    ADR 0015 decision W4). The mode-independence assertions run beside
    them per the umbrella doctrine ([LTA-IDENTITY-MODE]): `ownerOf`,
    `totalSupply`, lifecycle, and identity reads answer identically in
    both modes, and record chains and state exports are
    mode-independent.

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

Governed-configuration events bind their authorizing action uniformly
(ADR 0014 decision V6). Every production event that announces a
configuration change executed through an ADR 0004 staged action —
pointer moves, GGP and GTP changes, ledger writer and phase-executor
updates, module-registry and asset-policy updates, and every other
governed-configuration family — carries the `bytes32 actionId` of the
authorizing action as a field of the host event ([GOV-ACTION-ID]), so
authority history reconstructs from the host event stream alone,
without transaction-level correlation against the separate governance
events. The event catalog records the `actionId` position for each
such event, and a governed-configuration event without one fails the
Events gate; the mint-layer configuration events adopt this convention
at their home, which owns the exact signatures.
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
Any non-standard event snippet outside a declared production-exact
event home that omits
`schemaVersion` is shorthand, not permission to omit it from the production ABI. The
event catalog and golden event tests are authoritative. A subsystem
event home that declares its blocks production-exact — the mint and
sales event sections and the entropy homes [EC-EVENTS]/[EP-EVENTS]
(ADR 0013 decision U7) — is outside the shorthand escape: its
signatures must match the catalog field-for-field, and drift there is
a defect at the home, never shorthand. For newly added events the
`uint16 schemaVersion` field is the leading declaration field; the
pinned signatures of existing event homes are authoritative for their
deployed field positions and are not re-ordered by this convention
(ADR 0013 decision U7).

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
subject kinds, sale consent scopes, and registry-immutability
elections (`ArtistIdentityStatus`,
`AttestationSubjectKind` — `SUBJECT_DEPLOYMENT = 9` included —
`SaleConsentScope`, a `uint8` input to `ARTIST_BINDING_DOMAIN`, and
`RegistryImmutabilityElection` — `REGISTRY_MUTABLE_OK = 0`,
`REGISTRY_FREEZE_REQUIRED = 1`, likewise a `uint8` input to
`ARTIST_BINDING_DOMAIN`;
ADR 0012 decisions T4 and T9; ADR 0013 decision U4)
([`docs/stream-artist-authority.md`](stream-artist-authority.md)),
the Governed Gas Parameter failure-direction classes (`NONE = 0`,
`FORWARDING_CAP = 1`, `FAIL_CLOSED_PRECHECK = 2`, `MIN_GAS_GATE = 3`;
home [LTA-GGP] requirement 12 in
[`docs/stream-long-term-architecture.md`](stream-long-term-architecture.md);
ADR 0013 decision U2),
governance action statuses (`GovernanceActionStatus`; home
[`docs/adr/0004-admin-governance.md`](adr/0004-admin-governance.md)
[GOV-ACTION-ID]),
guardian capability bits (`PAUSE = bit 0`, `VETO_TERMINAL_FREEZE =
bit 1`, `CANCEL_STAGED_ACTION = bit 2`, `INCIDENT_REVOKE = bit 3`;
home [LTA-GUARDIAN] rule 2 in
[`docs/stream-long-term-architecture.md`](stream-long-term-architecture.md);
ADR 0012 decision T5),
owner-record family constants (`ACCESSION`, `CONDITION_REPORT`,
`EXHIBITION`, `LOAN`, `DEACCESSION`, `CITATION`, and the
valuation/insurance family constant pinned at the home — ADR 0014
decision V8; home
[CMC-OWNER-RECORDS]), schema statuses, hash algorithms, canonicalization
IDs, source/storage types, token URI read statuses, finality scope types,
and recovery statuses. IDs may be deprecated but not reinterpreted.
Coverage is closed-world across hash preimages (ADR 0012 decision T9):
every enum whose numeric values are inputs to any domain-constants home
or protocol v1 mirror row — every enum hashed into a Permanent
preimage — and every enum that crosses a contract, indexer, or manifest
boundary must have a catalog entry, and a checker fails on any enum
named in a domain-table Inputs cell that has none.
The catalog assigns numeric vocabularies only. `bytes32` keccak name
vocabularies — the conservation tiers ([CMC-MUSEUM-GRADE]) and the
collection identity modes ([PV1-IDENTITY-MODE] requirement 1; ADR 0015
decision W4) — are not catalog members: no Solidity enum exists for
them, they are pinned at their homes and in the protocol v1
domain-constants mirror rows under the CI recomputation discipline
([PV1-MIRROR] rule 2), and assigning them a parallel numeric alias
would create exactly the second boundary-crossing ID space this
catalog exists to prevent.
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
