# ADR 0011: World-Class Pass Round 2

## Status

Accepted.

Accepted 2026-07-04 under the same protocol-owner direction as ADR 0010.
The nine-lens review re-ran against the ADR 0010 spec set and returned 98
findings (every lens improved; none yet at the owner's 9.5 bar). This ADR
records the round-2 resolutions. One finding — the round's only blocker —
restates OQ-X8, which the owner has explicitly reserved; it remains open in
the register, now enriched with the reviewer's layered candidate
resolution, and is not decided here.

## Problem

Round-2 findings are second-order refinements of the ADR 0010 models: the
onchain-bytes rule admits log data its own EIP-4444 posture says can
expire; permanence machinery binds only at an optional finality ceremony;
execution environments are named but not archived; archival receipts are
operator-asserted; escrow-holding sale modes can strand buyer funds under
policy drift; artist identity lacks compromise recovery and
platform-independent estate activation; several typehash, nonce-scoping,
vocabulary, and mirror-completeness defects; and the museum layer names
schemas it never pins.

## Decisions

Cited from the specs as "(ADR 0011 decision R<n>)".

### R1. Onchain bytes means contract storage

The event-embedded alternative is struck for interpretation-critical
catalogs, finality/snapshot manifest canonical bytes, meaning-bearing
record-family payloads, and onchain signature bundles: these must live in
contract storage or SSTORE2 (state trie), never only in log data. Events
remain discovery pointers. The with-operators-gone guarantee may only cite
state-trie carriers.

### R2. Mint-time content binding for offchain collections

An OFFCHAIN-mode collection must record per-token metadata and media
HashRefs (or an incrementally committed content root) before tokens are
sold, or declare the existing service-backed-mutable collection class at
creation. Undeclared unbound sales are nonconformant. A
preservation-coverage deadline (content root plus dual-family receipts
within a pinned window after collection close) becomes a monitored gate.

### R3. Execution environment and acceptance modes

The REFERENCE_RENDER component must archive the execution environment as an
artifact (container image or browser/engine build) under the dual-family
rule with fixity coverage — not merely name it. Re-render acceptance is a
per-work mode pinned at finality: BYTE_EXACT, PERCEPTUAL_TOLERANCE (named
metric and threshold), or CURATED_EQUIVALENCE (conservator attestation),
matching variable-media practice. Dynamic works use a declared DYNAMIC
renderer class whose external reads are declared and frozen per version and
which is excluded from BYTE_EXACT.

### R4. Verifiable archival receipts and endowed storage

Dual-family archival proof requires at least one cryptographically
verifiable receipt class (content-addressed inclusion proof such as an
Arweave data-root path, or an attested possession proof audited by the
fixity program). Operator-asserted receipts alone are nonconformant. At
least one family for render-critical payloads must be a pay-once endowed
class; renewal-funded families cannot satisfy both slots.

### R5. GGP raise bounds, probe locus, and lost-governance posture

GGP raises are bounded per action (at most 2x current value) under the
normal delay class; the emergency path is raise-only, health-probe-gated,
and service-restoring. Each parameter family names its probe contract in
the release manifest (the verification locus for lowering and emergency
raising). For lost-governance survivability, pre-approved conditional
raises are registered as permissionless guardian actions executable by
anyone when the named probe proves reads failing at the current value.

### R6. Deferred-settlement drift envelopes — buyer funds never strand

Every escrow-holding sale mode (refund windows, Dutch uniform clearing,
mint-at-settlement, accepted offers) binds a drift envelope at purchase:
the buyer's signed authorization pins maximum price, sale reference, and a
finalize-by deadline. Finalization may execute under ALLOW_CURRENT within
the envelope; past the deadline, a permissionless refund path unlocks
escrowed funds. Dutch purchases send maxPrice and are charged the current
price with the excess returned as a pull credit (no exact-payment race).
Phase pause state moves out of the policy hash into a separate operational
flag: emergency pause never requires artist signature and is never blocked
by attribution disputes; the spec defines the V2 phase-config preimage
without the pause field, required at deployment, while the checker-pinned
V1 table row remains as-built evidence.

### R7. Artist identity resilience

1. Rotation executes after a contest window during which a pre-registered
   artist guardian set (or the artist's other keys) can veto — a stolen key
   cannot instantly and permanently take the identity.
2. Artists hold a standing content veto between mint and finality:
   content-affecting record families for artist-bound collections require
   artist co-signature or are freezable by the artist, per consent mode.
3. Artwork-bytes-affecting post-finality recovery requires artist or estate
   signature where bound, or a recorded unavailability finding plus arbiter
   approval under a long delay.
4. Estate activation via artist-pre-signed directive executes
   permissionlessly after its public-notice window — no live platform
   governance required. The governed dormancy path remains as fallback.
5. PLATFORM_WORKS declarations stay immutable, but append-only third-party
   attribution claims and an arbiter CONTESTED display state provide the
   dispute path for misappropriated art.
6. One normative attribution JSON schema (artist-authority home) including
   the sanction linkage fields; the renderer and CM specs cite it.
7. Arbiter actions carry a delay class, an artist counter-statement right,
   and a governance-class appeal tier. Sanction ceremonies require
   artist-tooling evidence that the canonical statement was rendered
   human-readable before signing.
8. Collaborator sets support M-of-N and per-capability designation so
   primary incapacity does not stall artist-gated actions.
9. C2PA authorship assertions must reconcile with registry attribution
   state and key history or carry an explicit divergence flag.
10. The artist identity document joins the onchain-bytes/dual-family rule
    (R1/R4). Artist-registry signatures adopt the low-s/canonical-v rule.

### R8. Sale-scoped randomness and reveal operations

The coordinator gains a sale/collection-scoped request kind with its own
request-key domain, giving raffles, random assignment, and reveal offsets a
blessed pattern. Reveal operations are owned: collections declare a reveal
owner with an SLO, sales escrow a per-mint reveal fee funding the requests,
and a permissionless request fallback engages after the SLO lapses.

### R9. Sales vocabulary, growth, and coverage completions

SaleKind is an append-only numeric-catalog vocabulary; extension profiles
pin interfaces and safety invariants only, never auction economics. The
purchase-record domain becomes its own constant (no domain reuse). The
sales-spec saleId and the revenue settlementKey are explicitly linked by a
pinned mapping rule. Zero-price claims and pay-what-you-want bands are
first-class sale kinds; custody-inventory fixed-price (pre-minted gallery
sales) is added; English auctions gain the first-bid-starts reserve knob;
ERC-20 bidding is an extension profile with escrowed-funds invariants;
offer/custody settlements pin their nonce-consumption locus;
mint-at-settlement pins the contract-winner delivery branch
(winner-directed claim). Serial selection stays excluded on this Core line
(the reservation-ADR hint is removed); pick-your-piece uses commit-reveal
by default for differentiated content; sealed-bid profiles require
deposit-bonded bids with abort slashing and uniform deposit sizing.
Held-token entitlements get a documented HOLDER_ENTITLEMENT gate recipe
(manager-scoped nullifier keyed by entitlement and held token). Mementos
and wallet-bound artist proofs are served by an attestation-based pattern
documented in-ecosystem rather than soulbound transfers.

### R10. Governance and signature hygiene

"Material actions" is defined by list in ADR 0004; EOA-class holders are
restricted to time-boxed bootstrap with a sunset gate. The batch ABI is
made explicit (scheduleGovernanceBatch/executeGovernanceBatch over
GovernanceCall[]). The ERC-1271 supported-wallet-class posture gets one
home cited by every verifying layer, and the owner-records/attestation
satellites instantiate their own GGP for verification gas. All signed
authorizations scope nonces per signer (bitmap/unordered pinned for the
artist registry). SALE_AUTHORIZATION_TYPEHASH types revenueClass as
bytes32. PaymentIntent gains a payer-is-caller exemption. The terminal
freeze veto floor rises to 72 hours. Genesis requires at least one
registered pre-approved fallback target per critical pointer family.
Deterministic deployment (CREATE2, pinned salts, factory) is recorded in
the deployment manifest.

### R11. Museum schemas pinned

Registrar and conservation record families get pinned typed schemas
(condition report, loan, exhibition minimal fields); PREMIS conformance
gains a data-dictionary mapping table; rights records get a pinned schema
with a rights-statement vocabulary and a finality existence requirement for
museum-grade collections; artist interviews (or a recorded waiver) join
ARTIST_INTENT for museum-grade finality; an INDEPENDENT_ATTESTOR class
lets any institution run its own preservation/fixity lane without operator
involvement, keeping preservation evidence alive past the operator; the
IIIF profile splits into the pinned archival profile plus non-normative
live-service guidance; the citation record-state hash qualifier is pinned.

### R12. Meta, mirrors, and honesty completions

Mirror tables must carry every domain including governance and all GGP
parameter IDs; the two unfalsifiable deployment gates are rewritten with
falsifiable acceptance criteria; TokenCollectionRegistered carries
schemaVersion; decision-citation format is unified; interior composite
hashes gain domains; the three unprefixed revenue domain strings adopt the
6529 namespace (hashes recomputed); optional event mirrors are banned
uniformly at genesis; caller-relative replay views gain explicit-address
variants; the event-history snapshot serialization is pinned (JCS-ordered
JSONL leaf rule); the content-root manifest-bytes location follows R1; the
planning-budget arithmetic is reconciled with the 2,000-byte headroom rule;
a spec-level collector mint gas ceiling becomes a gate with measured proof;
artist onboarding tooling and rehearsal become a gate; recurring
post-launch obligations get teeth (a missed cadence is a monitored
incident); the honest narrative states the curated-onboarding posture and
the marketplace-royalty plumbing gate; LOW_SECURITY entropy class is
disclosed in default token JSON; the genesis default template drops the
unresolved curators bucket (curator classes are deployment config when a
pool contract exists); fresh-entropy recovery proof requires
coordinator-state evidence, not adapter testimony; a legal/compliance
posture statement joins Accepted Tradeoffs (deliberately out of protocol
scope, rights records informational); the EntropyFulfillmentOutcome and
sanction-subject drift between decision records and homes is corrected.

## Alternatives, Security, Release, Test, Rollout

As ADR 0010, applied to the round-2 delta: no deployed artifacts change;
every decision maps to matrix gates (drift-envelope refund tests, rotation
contest-window tests, environment-artifact fixity gates, probe-locus tests,
schema-pinning golden tests); the nine-lens review re-runs after
application and merge remains gated on the owner's 9.5 bar.

## Non-Goals

OQ-X8 stays reserved to the owner. No secondary-market mechanics.

## Accepted Risks

Drift envelopes add signature fields to escrow-mode purchases (accepted:
funds can never strand); artist guardian sets add ceremony (accepted:
identity theft is worse); endowed-storage requirement narrows family
choices (accepted: renewal-funded permanence is not permanence).
