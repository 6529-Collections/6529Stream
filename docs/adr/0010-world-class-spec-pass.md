# ADR 0010: World-Class Specification Pass

## Status

Accepted.

Accepted 2026-07-04 by protocol-owner direction. A nine-lens independent
review of the specification set (permanence, artist provenance, Safe/TDH
operability, minting coverage, best-in-world comparison, good patterns,
anti-patterns, meta-consistency, museum practice) produced 112 findings.
The owner directed that every finding be addressed — first-, second-, and
third-tier alike — with all decisions taken in the "most world-class, not
most convenient" direction, that gas caps gain maximum flexibility, and
that exactly one question remain open: the marketplace-consumable
collection identity signal under sequential token IDs (OQ-X8). This ADR is
the decision record for that pass. The full findings ledger is retained as
review evidence.

## Problem

The reviewed specs have two weak pillars — artist authority (operators can
mint, finalize, and monetize an artist's series with no artist consent
anywhere) and internal consistency (duplicated Permanent definitions that
have already drifted five times) — plus systematic holes: immutable gas
caps that future opcode repricing can turn into permanent outages,
offchain-by-hash gaps in the finality and export models, a sale/auction
layer that is a sketch inside an EIP-grade spec set, and museum-grade
claims whose genesis substance is an operator-writable log.

## Decisions

Decision numbers below are cited from the specs as "(ADR 0010 decision N)".

### D1. Governed Gas Parameters (GGP) — no immutable gas caps anywhere

1. Every external-call gas cap in the protocol (royalty resolver read,
   metadata router read, entropy registration, ERC-1271 verification,
   finality component reads, gate calls, asset-policy checks, escrow flush
   floors, and any future cap) is a **Governed Gas Parameter**: a storage
   value with an immutable per-parameter FLOOR set at deployment from
   measured need plus margin.
2. Raising a GGP is a service-restoring action: staged governance with a
   raise-only emergency path permitted. Lowering a GGP requires the
   normal delay class plus a passing health-probe run at the proposed
   value, and can never go below the floor. [Superseded in part by
   ADR 0011 decision R5: staged raises use the normal delay class with a
   2x per-action bound, and the emergency path is health-probe-gated;
   the current model is the [LTA-GGP] home in
   [`docs/stream-long-term-architecture.md`](../stream-long-term-architecture.md).]
3. GGP values are Operational-layer: they are excluded from finality
   manifests and frozen-route identity, so retuning gas never touches
   artwork identity. Frozen collections keep working because the cap can
   always be raised.
4. Every GGP has a named constant, a genesis value and floor recorded in
   the release manifest, a change event with old/new values, and membership
   in the hard-fork/repricing review checklist. The 63/64 EIP-150 parent
   precheck pattern remains mandatory and reads the current GGP value.
5. Consequence for the mint path: entropy registration failure can no
   longer permanently brick minting — the registration cap is raisable and
   the coordinator pointer is replaceable; the specs must state this
   recovery chain explicitly.

### D2. Artist authority model (new spec: docs/stream-artist-authority.md)

1. **Two-sided artist identity.** An operator proposes an artist binding
   (address plus identity record); the artist ACCEPTS onchain from that
   address or via verified EIP-712/ERC-1271 signature. Until accepted,
   every surface must render the attribution as unverified. Multi-artist
   works bind a typed onchain collaborator list (address, role, share
   reference), each collaborator accepting individually.
2. **Artist key lifecycle.** Artists can rotate their bound address
   (old-key-signed rotation), designate a successor/estate address or
   contract, and pre-sign estate directives. A governed dormancy procedure
   with long public-notice delay handles lost keys; every transition is
   evented and append-only.
3. **Artist sanction is a finality component.** For any collection with a
   bound artist, `finalizeCollectionArtwork` / scoped finality requires an
   `ARTIST_SANCTION` component: an EIP-712/ERC-1271 signature by the
   accepted artist (or estate) over the finality record preimage, verified
   onchain. Collections without an artist declare a `PLATFORM_WORKS` class
   at creation; that declaration is immutable and displayed.
4. **Consent in the mint path.** Collection creation pins one of three
   consent modes: `ARTIST_SIGNED_POLICY` (every phase policy hash requires
   artist co-signature), `ARTIST_DELEGATED` (artist signs a scoped, expiring
   delegation to named platform signers), or `PLATFORM_WORKS`. The platform
   can never extend an artist-bound series without a verifiable artist
   authorization chain.
5. **Artist economics.** Primary split templates gain a first-class
   `ARTIST` beneficiary class; the spec set must state the artist-take
   posture explicitly and stop normalizing artist-less default splits.
   Where consent mode binds an artist, changes to that artist's revenue or
   royalty assignments require artist co-signature, and the artist can
   unilaterally freeze the royalty receiver assignment for their own works.
6. **Genesis signature verification.** `ARTIST_SANCTION`,
   `ARTIST_STATEMENT`, artist acceptance, and institutional attestations
   are verified onchain (EIP-712 + ERC-1271 with GGP-governed gas) at
   genesis — not committed-but-unverified. Signature bundles referenced by
   attestations must be mirrored under the dual-family archival rule (D4).
7. **Disputes.** Attribution can be marked `DISPUTED` or `REVOKED` by the
   artist or a governed arbiter role; append-only with reasons, and token
   JSON must expose attribution state:
   `claimed | artist_accepted | artist_sanctioned | disputed | revoked`.
8. The CON-015 whole-module writer exception is retired: genesis uses
   record-family-scoped writer authorization, including artist-scoped and
   owner-scoped families (D6).

### D3. Single-sourcing and requirement identity

1. **One normative home per definition.** Every Permanent definition —
   hash preimage, interface, enum, event schema, canonical ordering — has
   exactly one owning document section; every other document cites the home
   instead of restating it. The domain-constants tables in the protocol v1
   spec are checker-verified mirrors, not second homes.
2. **Precedence rule** (added to spec-policy): if documents conflict, the
   owning home wins; a conflict is a defect to fix, never an
   interpretation choice. ADRs are decision records; the specs they amend
   are the homes.
3. **Requirement anchors.** Normative sections carry stable bracketed
   anchors (for example `[MPA-COUNTERS]`), and edited musts are numbered
   within their section so gates, tests, and reviews can cite requirements
   precisely. Full backfill across all documents is a Review-entry
   condition tracked in the conformance matrix.
4. **Canonical governance action ID.** ADR 0004 gains the definition every
   spec already cites: the `STREAM_GOVERNANCE_ACTION_V1` preimage, defined
   once in ADR 0004 [GOV-ACTION-ID] (the authoritative field list lives
   there, not here). One preimage, one home.
5. **Pinned EIP-712 surfaces.** Every signed payload that moves value or
   mints (mint tickets, sale authorizations, payment intents, release
   authorizations, artist consents/sanctions, delegations) gets a pinned
   typehash string, full field inventory, and domain separator recorded in
   the domain-constants table with a CI recomputation test.
6. The five duplicated-preimage instances and the eight identified
   contradiction clusters (mint ordering, ERC-4906 emitter authority,
   freeze loosening, DEPRECATED asset semantics, registry interface,
   reserved-range remnant, single-step counter locus, lifecycle matrix) are
   resolved by electing homes and rewriting all non-home statements as
   citations.

### D4. Permanence hardening

1. **Per-token content binding for every metadata mode.** Before any
   finality (token or collection scope, any mode including OFFCHAIN), a
   token content root must be recorded: a Merkle root over
   (tokenId, metadataHash, mediaHash...) with its leaf schema pinned.
   Finality without content binding is nonconformant.
2. **Reference render capture.** Finality for script-based works requires a
   `REFERENCE_RENDER` component: output hashes for a pinned sample (or all
   tokens), plus an execution-environment manifest (renderer version,
   context version, capture toolchain) so 2075 can verify a re-render.
3. **Renderer determinism is a must** with an explicit nondeterminism ban
   list (no network, no time, no float hazards, no unseeded randomness) and
   golden output vectors as a deployment gate.
4. **State export covers the art.** STATE_EXPORT gains leaves/roots for
   collection metadata records, script/dependency/media manifests, locks,
   snapshots, attestations, and preservation records. Exports are produced
   on a mandated cadence (deployment-gated operational schedule), and the
   per-collection record stream carries an onchain rolling
   `recordChainHash` accumulator so completeness of any replica is provable.
5. **Interpretation-critical catalogs live onchain as bytes** (numeric ID
   catalog, schema/canonicalization registries, event catalog): SSTORE2 or
   equivalent onchain payloads, not hash-plus-URI.
6. **Dual-family archival proof before finality** for every offchain
   render-critical payload: two independent storage families with fixity
   attestations recorded before finality executes.
7. **Onchain scale.** SSTORE2-backed chunked script storage is a genesis
   capability; `MAX_TOTAL_ONCHAIN_SCRIPT_BYTES` rises to 786,432 (32
   chunks), with the per-read paging path (`scriptChunk`) and a documented
   full-view route; the default `tokenURI` byte cap stays marketplace-sized
   with an explicit over-cap serving story. The example HTML shell is
   corrected to hash-pinned inline/onchain sources only.
8. **Reconstruction client and funding become gates.** The archival
   reconstruction client gets a conformance gate (build + replay + render
   proof), and genesis requires a published funding/endowment manifest
   (source, coverage horizon, exhaustion alarms) for keepers, storage, and
   drills.

### D5. Sales and auctions layer (new spec: docs/stream-sales-and-auctions.md)

1. New EIP-grade spec owning: sale adapter conformance profile and registry
   governance; English auction state machine (reserve, minimum increment
   bps, anti-snipe extension window and cap, settlement CEI, pull refunds);
   Dutch auction (linear/stepped decay, optional uniform-clearing rebate
   mode with escrowed rebates); private/direct sale (allowlist-of-one);
   burn-to-mint and burn-to-redeem gate modules (burn proof via Core
   retained identity, nullifier = burned tokenId, and the finality
   interaction rule: burn-to-mint collections use scoped finality or a
   declared burn-compatible supply mode).
2. Sealed-bid and ranked auctions are specified as extension profiles
   (interface + conformance requirements) without genesis implementations.
3. Allowlists support the industry-standard Merkle leaf
   (address, maxCount, optional priceOverride) as a static counter cap mode
   — no resolver needed.
4. Refund-window sales: an escrow-holding mode where funds release only
   after the window closes; posted rebates via the Dutch clearing mode.
   Post-flush refunds remain impossible by design and the spec says so.
5. Signed-ticket continuity: policy re-registration may set a bounded
   `graceUntil` honoring the previous policy hash, so a config fix does not
   strand every outstanding ticket.
6. Delegated minting is stated at genesis: delegate-registry gate module
   (delegate.xyz-class) named, with the delegation-check conformance
   profile.
7. Curated pick-your-piece drops: content selection binds
   `tokenDataHash` chosen from a published content manifest; serials stay
   sequential; the pattern is documented.
8. Counter continuity across manager/ledger succession: a governed
   migration path imports prior counter values into a successor ledger via
   Merkle-proofed snapshot of the predecessor's state.
9. `GLOBAL` counter scope is a supported static scope (advertise/exclude
   contradiction resolved in favor of support).
10. The genesis contract inventory (conformance matrix) is completed to
    include the sale layer and every contract its gates reference; an
    end-to-end collector mint gas budget becomes a release artifact gate.
11. Account-abstraction posture stated: executor/sponsor separation is
    ERC-4337-compatible; no tx.origin anywhere; paymaster-sponsored mints
    are a supported executor pattern.

### D6. Museum object dossier

1. **Pinned object subject identity.**
   `STREAM_SUBJECT_TOKEN_V1 = keccak256(abi.encode(domain, chainid, core,
   tokenId))` (and sibling domains for media objects and scopes) enters the
   domain-constants table; every preservation/attestation/fixity/rights
   surface keys token-scoped records with it.
2. **Owner-writable registrar records.** A new `OWNER_RECORDS` family —
   ACCESSION, CONDITION_REPORT, EXHIBITION, LOAN, DEACCESSION, CITATION —
   writable by the current token owner (ownerOf-gated, signature-verified),
   append-only, HashRef-disciplined. Institutions can document custody
   without platform involvement.
3. **Fixity program, not primitives.** A mandated fixity schedule (annual
   full sweep, quarterly sampling) with `FixityCycleCompleted` attestations
   and a repair/escalation policy; deployment-gated operational manifest.
4. **Artist intent and acceptable variability.** An `ARTIST_INTENT` record
   family (display parameters, variability tolerances, migration/emulation
   guidance, artist interview references); finality for artist-bound
   collections requires the record or an explicit recorded waiver.
5. **C2PA binds to actual media.** C2PA references must bind the token's
   media hash(es), and validation status must name a verifiable signer
   class rather than self-report.
6. **IIIF, exhibitions, citations.** A pinned minimal IIIF Presentation 3
   profile; the EXHIBITION/LOAN record schema replaces loose URI fields;
   a canonical citation profile (chainId:core:tokenId plus record-chain
   hash) for scholarly reference.
7. Institutional custody guidance (Safe-based custody, succession,
   loss handling for owner keys) is documented as Operational guidance.

### D7. Safe multisig and TDH-governor operability

1. **Governance actions are atomic call batches.** The canonical action
   schema carries an array of (target, selector, args-hash) with a batch
   hash in the action ID; cross-contract pointer/catalog updates that must
   land together execute as one staged batch.
2. **Windows sized for real governance.** Execution windows get floors
   (≥ 7 days open-to-execute for normal class), emergency classes assume
   multisig latency (≥ 4 hours, role-redundant), and unpause is classified:
   a dedicated no-timelock UNPAUSE role distinct from pause guardians, with
   evented rationale.
3. **ERC-1271 everywhere signatures are verified**, with the supported
   wallet class named (any wallet completing verification within the
   GGP-governed cap; floor sized by measured Safe n-of-m verification) —
   applied to mint tickets, sale authorizations, releases, artist flows.
4. `FreshRecoveryPolicy.incidentDeclarer` and similar long-lived
   authorities become role references resolved through the admin registry,
   not raw frozen addresses.
5. Entropy-provider operational authorities (VRF subscription owner,
   funding, withdrawal destinations) must be contract-holdable and recorded
   as governed configuration, not merely documented.

### D8. Anti-pattern closures

1. VRF (and every callback adapter) must wrap `fulfillEntropy` in
   try/catch, persist the raw randomness on failure, and support retry —
   provider randomness can never be lost to a coordinator revert.
2. ERC-20 primary settlement requires a payer-signed EIP-712
   `PaymentIntent` (payer, asset, amount cap, sale reference, deadline)
   verified at the adapter boundary; standing allowances alone are never
   spendable as official revenue.
3. `ecrecover` results must be nonzero and matched; the
   `address(0)`-as-blessed-authorizer convention is replaced by an explicit
   `authorizerKind` enum.
4. Counter `increment` zero-sentinel is removed: increments are explicit
   `>= 1`; zero is invalid.
5. Ledger nullifiers become manager-scoped (same scoping as authorization
   IDs) to kill cross-manager pre-consumption griefing.
6. Asset-policy status changes join the staged/timelocked class, with a
   per-wallet release grace for already-observed balances (aligning the
   DEPRECATED semantics contradiction in favor of releasable-under-grace).
7. Entropy request payment binds a caller-supplied `maxFeeWei` against the
   provider quote, with excess refunded as a pull credit — fee drift cannot
   grief requests.
8. The instant-entropy interface documents its structural timing-grinding
   exposure and restricts instant mode to collections that declare a
   low-security entropy class; genesis exclusion stands.
9. The veto/guardian delay on irreversible freezes is a must.
10. Minimum bid increments and anti-snipe semantics are normative auction
    requirements (D5), not omissions.

### D9. Honest genesis narrative

1. The "smallest auditable system" claim is restated honestly: genesis is
   the smallest system consistent with the owner-ratified permanence and
   flexibility posture, with a published subsystem-by-subsystem audit plan
   and the full genesis contract inventory enumerated in the matrix.
2. Royalty enforcement is documented as impossible on this Core line
   (no transfer hooks) — the exclusions list stops implying a module could
   add it; a successor line is the only path.
3. The ERC721Enumerable per-transfer cost is quantified in Accepted
   Tradeoffs with measured numbers and the retention rationale.
   (Superseded by ADR 0012 decision T10: `ERC721Enumerable` is removed
   from Core, and the enumeration posture home is [LTA-ENUMERATION] in
   `docs/stream-long-term-architecture.md`; the retention rationale no
   longer applies.)

### D10. Cross-cutting corrections

1. Core emits `TokenCollectionRegistered(tokenId, collectionId, serial)`
   at identity write, making event-only identity reconstruction normative.
2. One module-registry interface (the merged record shape) everywhere; the
   matrix genesis profile names it.
3. Mint-manager reentrancy guard becomes a must; `registerPhasePolicy`
   binds `msg.sender` to its manager argument; `gateGasLimit` enforcement
   is a must through GGP.
4. Signers get a revocation surface for unused signed authorizations
   (authorizer-signed or authorizer-sent revocation, ledger-recorded).
5. Collection-scope finality requires Core status `CLOSED` **and** an
   immutable no-burn policy read; otherwise scoped finality only — the
   CLOSED-invariant contradiction is resolved by making the burn-path
   freeze explicit.
6. The interim randomizer-after-mint ordering is purged from normative
   sequences; the lifecycle matrix aligns with coordinator terminal states;
   `streamSystemManifest()` is confirmed Core-required (removed from the
   relocation-candidate list); duplicate revenue event definitions are
   deduplicated and ERC-7572's event joins the schemaVersion exemption
   list; recipient-claim aggregation gets a permissionless
   `claimMany`-style periphery surface preserving pull semantics.
7. The decision-count miscount in ADR 0009 and the register is corrected
   (25 decisions resolving the 25 questions raised alongside the one
   reserved question, OQ-X8).

### D11. The single open flag — OQ-X8

Sequential token IDs plus a shared multi-collection contract leave no
marketplace-consumable collection-identity signal, and that gap is the one
question the owner reserved. OQ-X8 is opened in the register with the
candidate directions (per-collection contract-metadata surfaces, ERC-7496
traits, an indexer-facing collection registry read, marketplace-standard
sub-collection metadata) and explicitly does not block Draft-stage work,
but must be resolved before the metadata specs reach Final.

## Alternatives Considered

Immutable gas caps with larger margins (rejected: any fixed margin is a
bet against 50 years of repricing; the owner directed maximum flexibility);
operator-custody artist model with offchain agreements (rejected: provenance
that decays to trust); keeping the auction layer as an integration concern
(rejected: primary sales are protocol-core for a 1/1 platform); museum
records as documentation-only (rejected: registrar-writable onchain records
are the differentiator the museum lens demands).

## Security Impact

D1 converts bricking risks into governed-recovery paths while floors
prevent griefing-by-lowering. D2/D6 replace whole-module writer authority
with family-scoped, signature-verified authority — a strict reduction in
operator power. D8 closes concrete attack/griefing surfaces (allowance
drain, forged-ticket near-miss, nullifier griefing, randomness loss). New
surfaces (owner records, artist flows, sale adapters) are append-only or
escrowed and inherit the existing staged-governance and event disciplines.

## Release Impact

Specs only; no deployed artifacts. Two new spec documents enter the
inventory (artist authority; sales and auctions). The conformance matrix
gains gates (golden render vectors, gas budget artifact, fixity program,
reconstruction client, funding manifest, artist signature verification,
GGP floors). Release artifacts regenerate through the full chain.

## Test Plan

Every decision maps to matrix gates: GGP floor/raise/lower and probe tests;
artist acceptance/sanction/consent-mode and estate-transition tests; content
root and reference-render finality gates; export root and record-chain
reconstruction tests; auction increment/anti-snipe/Dutch-rebate and
burn-to-mint suites; PaymentIntent and ecrecover-nonzero negative tests;
manager-scoped nullifier tests; owner-record and fixity-cycle tests;
batch-action governance execution tests.

## Rollout Plan

1. This ADR merges with the spec pass that applies all 112 findings.
2. The nine-lens review re-runs on the updated tree; iterate until every
   lens rates at least 9.5/10 (owner-set bar), then merge.
3. Implementation alignment follows the updated conformance matrix.

## Non-Goals

No deployed-contract changes; no secondary-market or marketplace-side
mechanics beyond the stated primary-sale scope; no resolution of OQ-X8
(explicitly reserved to the owner).

## Accepted Risks

1. Governed gas parameters reintroduce a governance dependency into read
   paths that were fully static; mitigated by immutable floors, staged
   delays, and probes — accepted for survivability.
2. Artist authority adds signature ceremonies to finality and policy flows;
   accepted — consent is the product.
3. The genesis surface grows further (sale spec, artist flows, owner
   records); accepted under the owner's flexibility-over-minimalism
   posture, with the honest-narrative and audit-plan requirements of D9.
