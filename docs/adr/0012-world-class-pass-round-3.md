# ADR 0012: World-Class Pass Round 3

## Status

Accepted.

Accepted 2026-07-05 under the same protocol-owner direction as ADR 0010 and
ADR 0011. The third nine-lens review returned 86 findings (down from 112
and 98; every lens at or above 8.0, three at 9.0). The single blocker
restates OQ-X8, which remains owner-reserved and is not decided here; the
other 85 findings are resolved by this ADR.

## Problem

Round-3 findings concentrate on the newest machinery's edges: the GGP
probe/conditional-raise chain is a lost-governance lifeline whose probe
contracts sit outside every permanence gate and whose raise path is a DoS
ratchet for fail-closed parameters; open offchain collections accrue no
mirroring obligation until optional ceremonies; SSTORE2 payloads are
discoverable only through expirable logs; artist estate flows still have
platform dependencies and display ambiguities; the sales layer misses a
handful of real patterns (airdrops, raffles, consignment, editions
statement); the museum dossier omits the ownership-provenance chain and a
tombstone schema; and the meta lens found the usual crop of drifts in the
newest text.

## Decisions

Cited from the specs as "(ADR 0012 decision T<n>)".

### T1. Probe contracts are Permanent-class; conditional raises are scoped

Superseded in full by
[ADR 0017](0017-raise-only-parameter-governance.md). No gas/time probe
contract, probe record, conditional mutation, or zero-signer repair path is a
launch member. This historical text remains review evidence only.

Probe contracts join the genesis inventory as Permanent-class members: no
owner, no upgrade path, no selfdestruct, permissionlessly callable forever,
covered by the static permanence checks, golden interface tests,
deterministic deployment, and a zero-signer museum-mode drill that
exercises probe-and-conditional-raise end to end. The probe-run record
lives on the probe; `probeMaxAgeBlocks` gets a generous pinned floor.
Permissionless conditional raises apply ONLY to read-survival
(`FORWARDING_CAP`) parameters; `MIN_GAS_GATE` and `FAIL_CLOSED_PRECHECK`
parameters are raisable through governance only, which removes the DoS
ratchet. Probe inputs are pinned per parameter (fixed corpus, no
caller-supplied gas shaping), and every GGP in the inventory carries a
probe definition. Entropy lifecycle block-count windows become Governed
Time Parameters under the same floor/raise/probe discipline as gas.

### T2. Preservation follows the sale, not the ceremony

Sold tokens in open OFFCHAIN collections require dual-family receipts (one
ENDOWED) plus fixity coverage within the pinned window of each token's
sale, not of collection close; the sold-token lane joins the fixity
program and the monitored-incident regime.
`OFFCHAIN_PRESERVATION_COVERAGE_SECONDS` gets a floor and a governance
change class. Non-script media works receive the same conservation gating
as script works (content roots, receipts, acceptance modes where
applicable).

### T3. State-readable discovery for every onchain payload

Every SSTORE2/storage payload family exposes an enumerable state read
(pointer registry on its host: count plus paged pointer/type/hash rows),
so a state-only archivist can locate every payload without logs. State
exports and event-history snapshot chunks — the EIP-4444 bridge — get
their own dual-family archival mandate with receipts. The v1 generic
record write gains an optional payload-bytes parameter (SSTORE2-backed)
so meaning-bearing record families have a state carrier; sale-layer owed
funds and a split-wallet/profile enumeration index join the STATE_EXPORT
leaf set; content-root leaves pin never-finalized-entropy semantics;
burned-token artwork gains a required serving surface (the full-view read
remains callable for burned tokens).

### T4. Artist estate and registry continuity hardening

Estate activation and dormancy gain a third-party contest path (guardian
or arbiter challenge window before effect); guardian sets survive
authority transitions (recordable under estate/steward authority, not only
AUTH_ARTIST); identity documents gain append-only revision semantics
(original immutable, revisions signed and chained) so payout address and
key history stay current without rewriting history; sanction records and
token JSON distinguish the signing authority class
(artist | steward | successor | delegate); platform-works misappropriation
remedies gain a sale-stop hook (arbiter CONTESTED state pauses further
primary sales of the contested collection) and automatic token-JSON
exposure; primary-sale price/mechanics join the optional artist consent
scope (consent modes may pin sale-parameter approval); identity recovery
and arbiter revocation acquire an independent veto with the
terminal-freeze floor; steward default capabilities exclude
CAP_ECONOMICS_CONSENT (explicit grant only); steward sanction validity is
enforced by a specified minted-before read. Successor-registry migrations
must import the full attribution/consent history with a Merkle-proofed
binding, and forward consent enforcement cites the pointer-freeze option
for artists who require registry immutability.

### T5. Governance operability closure

The pause guardian becomes a durable role (`ROLE_PAUSE_GUARDIAN`) in
[GOV-ROLES] with one consistent holder statement; the guardian-module
pattern is specified (interface, registration, gating) where governor-held
defensive roles depend on it; material-action executability gains a
verification hook (a deployment-gated rehearsal that executes one action
of every class from a Safe and from the governor); subsystem obligation
windows (reveal SLO and peers) join the holder-latency sizing rule;
non-material operational grants on EOAs get a sunset review cadence;
manifest-named executors must be role references; artist ceremony
rehearsals must include a contract-wallet artist.

### T6. Sales-layer completions

The EXECUTOR counter key mode joins the v1 combination table;
mint-at-settlement auctions bind an onchain artwork commitment
(contentSelectionHash or tokenDataHash committed at auction creation);
airdrops get a named operator batch-distribution pattern with gate
coverage; oversubscribed-drop fair allocation gets a frozen raffle recipe
built on sale-scoped randomness; cross-sale content uniqueness is
enforceable via an optional per-collection content-consumption registry
keyed by contentId; DutchDecayKind becomes an append-only vocabulary;
custody entry for offer acceptance and single-token consignment of
owner-held tokens is specified (owner-signed custody grant, revocable
until sale); the primary-sale-only boundary is restated against
consignment (consigned owner-held tokens settle as secondary transfers
with royalty disclosure, never as primary revenue); the editions posture
(N ERC-721 serials, never ERC-1155) is stated; dynamic/evolving art gets
one consolidated extension recipe section; buyer drift-envelope signing
gains a by-construction path for public sales (adapter-published standing
envelope incorporated into the purchase transaction, no separate typed
signature for at-price purchases); ticket/offer revocation call mechanics
and authorizer proofs are specified; per-token operationId composites and
the remaining interior hashes gain domain constants.

### T7. Revenue and pattern hygiene

`claimRefund` semantics are pinned (debit account, authorization,
recipient rules) as a Permanent interface; sale-adapter escrow adopts the
revenue-layer conservation invariant and forced-ETH posture; the
mint-ordering home's validation-before-effects wording is reconciled with
its blessed realizations; EIP-2 low-s/canonical-v checks are stated
uniformly for revenue-layer EOA signatures; the PaymentIntent EIP-712
domain binds the actual verifying contract; owner-records adopt unordered
per-signer nonces with revocation and replay views; the reveal fee gains a
top-up path under provider fee drift; the assignmentHash preimage's
undefined input is defined; tokenData typing and renderer-context
serialization are aligned across the storage-home boundary.

### T8. Museum dossier completions

The acquisition packet and object dossier include the ownership-provenance
chain (Transfer-derived custody history plus owner records); registrar
tooling is preserved and gated like the reconstruction client; a pinned
tombstone cataloguing schema (artist, title, date, medium, dimensions/
duration, edition, credit line) joins the typed record families; the
environment-artifact boot-failure remediation workflow is mandated;
borrowing institutions get an independent exhibition/condition lane via
INDEPENDENT_ATTESTOR; a BagIt/OCFL packaging mapping table is added for
dossier and export ingest; museum-grade collections require a minimum
rights floor (platform-works included); CURATED_EQUIVALENCE pins the
attestor class (named conservator credentials in the attestation); the
packet includes the latest render-verification drill outcome for script
works.

### T9. Honesty, chain posture, and disclosure

The world-class claims are reworded as design-complete-pending-
verification with the Review-entry conditions as the proof path; the
deployment chain posture is stated normatively (Ethereum mainnet L1 for
the Core line; anything else is a successor-line decision); marketplace
display/royalty evidence gates require standing commitments or dated
re-verification cadences rather than capture-time screenshots; artist
ceremony load gets a budgeted maximum (signature count and wall-clock)
as a gate; operational cost/staffing is sized in the funding manifest;
a vulnerability-disclosure and bounty posture joins the permanent
operational surface; the legacy-document quarantine list is completed and
the governance home's equivocal holder text is fixed; the numeric catalog
and golden test cover every enum hashed into Permanent preimages;
ContractURIUpdated's caller set is pinned at the hook-table home;
artist-deployment provenance is served by an artist-signed deployment
attestation record (the per-collection facade question remains inside
OQ-X8, untouched).

### T10. ERC721Enumerable is removed from Core

Supersedes the "keep ERC721Enumerable in Core" principle (pre-review
umbrella; restated in ADR 0009 context). No modern elite 1/1 contract
carries the per-transfer enumeration tax; indexers derive enumeration from
Transfer events, and the museum scenario is served by state exports, the
reconstruction client, and the token-identity iteration surface
(sequential IDs make totalSupply-style iteration trivial without
enumerable storage). Core keeps `totalSupply()` (cheap counter) and drops
`tokenOfOwnerByIndex`/`tokenByIndex` storage; a periphery enumerator
module is specified for integrators that want live reads. This recovers
permanent per-transfer gas and Core bytecode inside the 2,000-byte
headroom rule, and is taken now precisely because it becomes irreversible
at genesis. The protocol-owner is flagged on this supersession in the run
report.

## Alternatives, Security, Release, Test, Rollout

As prior rounds. Notable: T1 deliberately trades permissionless-raise
coverage (now FORWARDING_CAP-only) for DoS immunity on fail-closed paths —
governance retains the raise power there, and the museum-mode guarantee
only ever depended on read-survival parameters. T10 changes a Permanent
Core surface decision while everything is still Draft — the last cheap
moment to take it.

## Non-Goals

OQ-X8 remains reserved. No ERC-1155, no secondary marketplace mechanics.

## Accepted Risks

Sold-token preservation lanes raise operator storage costs on open series
(accepted: that is what permanence costs); scoped conditional raises mean
a dead governance cannot raise fail-closed mint-path parameters
(accepted: minting is not a museum-mode guarantee; reads are); removing
enumerable breaks integrators that called tokenOfOwnerByIndex on-chain
(accepted: none are known, the periphery module covers them, and the
alternative is a permanent tax on every transfer forever).
