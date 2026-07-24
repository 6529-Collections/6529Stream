# ADR 0014: World-Class Pass Round 5

## Status

Accepted.

Accepted 2026-07-05 under the same protocol-owner direction as ADR 0010
through ADR 0013. The fifth nine-lens review returned 83 findings (average
8.83; six lenses at 9.0; no lens below 8.5; the single blocker restates
owner-reserved OQ-X8). Five rounds of data show the review instrument
saturating at 9.0 per lens; this ADR resolves the 80 non-reserved round-5
findings and closes the autonomous iteration loop pending the owner's
decisions on OQ-X8 and the merge bar (recorded in the run report).

## Problem

Round-5 findings are tail refinements of the hardened design: sold-work
and execution-environment preservation still attach to windows or
ceremonies rather than the sale itself; the pay-once storage guarantee has
no family-extinction rule; artist attribution still has instant-revocation
and old-key griefing edges; two revocation typehashes are mandated but
unpinned; the FORWARDING_CAP classification has a purchase-path loophole;
citation-format drift crept back; and the museum floor is opt-in.

## Decisions

Cited from the specs as "(ADR 0014 decision V<n>)".

### V1. Preservation attaches to the sale, fully

At or before first sale settlement, every sold token's render-critical
payloads require one archive receipt of a cryptographically verifiable
evidence class from the ENDOWED family; the 30-day window covers only the
second family and the first fixity record. ONCHAIN and hybrid script
collections gain the same sale-follows lane for reference-render capture
sets and the archived execution-environment artifact; finality verifies
rather than first creates them, and the museum-grade pre-first-sale floor
includes the environment artifact. Preservation masters are required for
still-image works in museum-grade collections (display derivatives never
satisfy the master slot for any media class).

### V2. Storage-family resilience

A pinned storage-family taxonomy defines family independence (operator,
funding model, jurisdiction, protocol). A family-extinction rule is added:
when a family's economics or network viability fails a monitored
indicator, a governed migration obligation triggers (successor family
election, re-upload with receipts, fixity re-baseline) within a pinned
window; the funding manifest carries the migration reserve line.

### V3. Artist attribution hardening

`revokeAttribution` becomes staged with the arbiter delay class and
guardian veto (no instant irreversible path; a stolen key cannot destroy
verified attribution). Veto standing of prior authority addresses expires
on rotation-contest completion plus a pinned tail window, revocable by the
current authority thereafter (kills the perpetual old-key griefing lever
and the perpetual contest standing). Registry succession gains an
onchain-verified import commitment (successor validates the Merkle import
root against the predecessor's record-chain heads at activation).
Platform-works misappropriation gains a repair path: upon a sustained
arbiter finding, a governed rebinding flow can attach verified attribution
and route future artist economics without rewriting history (append-only
correction lineage). The attribution JSON carries the artist name and
identity-document linkage. The deployment attestation becomes required for
artist-bound collections at first sale. Steward appointment cannot
displace lifetime guardians by default (explicit artist pre-grant only).
The dead-governance-plus-undesignated-artist terminal state is documented
as an accepted consequence with its mitigation (pre-signed directives,
guardian sets) restated at the dormancy home. Personhood evidence
(notarized attestation class) joins the museum-grade and artist-bound
first-sale floor as a recorded-or-waived item. The first-minted content of
an artist-bound collection joins the consent scope: the artist ratifies
the content root (or its commitment) for the first release, and holds a
pre-mint freeze right on content-root changes.

### V4. Governance tail

Post-genesis role handover to a slower holder class re-runs the
window/latency compatibility gate as a standing obligation (handover
without a passing latency proof is nonconformant). Guardian-module agents
gain holder-class, redundancy, and sunset discipline mirroring
[GOV-MATERIAL]. Escrow-recovery consent adds a msg.sender-equals-account
recording path for contract accounts. The rehearsal governor is pinned (a
named reference implementation with its code hash in the release
manifest). The stale P0 accepted-risk paragraph permitting unstaged Safe
execution is superseded in place. The reveal-fee residual destination and
every value-receiving role gain role references plus a
capable-of-receiving-ETH rehearsal check. The coordinator's lowercase
admin vocabulary maps into [GOV-ROLES]. Ceremony budgets bind the
Safe-class leg with its own ceiling.

### V5. Sales and mint tail

Zero-value Merkle `priceOverride` on fixed-price kinds is pinned (explicit
free-claim declaration required; amount-0 settlement stays forbidden
otherwise). A genesis fair-allocation recipe is named (the raffle recipe
becomes a worked, gate-covered example rather than a pattern sketch).
Pick-your-piece composition with time-varying pricing is declared an
extension profile with its interaction invariants pinned. Physical
redemption without burning gets a claim-record primitive (owner-records
family, no transfer semantics). The 6529-network eligibility mechanics
(TDH-class gates) get a frozen gate-interface profile so genesis
trust-based fallbacks have a declared replacement path. A consolidated
pattern-coverage matrix (pattern -> mechanism -> gate) is added to the
sales spec appendix. Seller-side pre-bid cancellation and custody-grant
revocation become disclosed, evented, and rate-disclosed on the sale
surface; anti-snipe budget exhaustion switches the auction to a declared
hard-close state with an evented warning at budget half-life.
ReleaseAuthorization binds the wallet-accounting epoch (releasable-amount
snapshot reference) so the no-drift claim is true, and the
PRE_REVENUE_SINGLE_STEP deposit step gains its ERC-20 realization.

### V6. Unpinned surfaces closed

The mandated signed revocation payloads for ReleaseAuthorization,
PaymentIntent, and SaleCustodyGrant get pinned typehashes, domain rows,
and mirrors. The PaymentIntent EIP-712 domain names the verifying
settlement contract class generically (per-adapter domain binding rule)
instead of a wrong constant name. Governance-evidence binding is made
uniform: every governed-configuration event carries `actionId`. The
governance action-ID and batch-calls domains gain mirror rows in the
protocol v1 tables (the ADR 0004 home stands; the mirror closes the
outside-the-reviewed-set gap).

### V7. GGP/GTP refinements

Amended by [ADR 0017](0017-raise-only-parameter-governance.md):
failure-direction classification, fixed-stipend inventory, bidirectional
cadence review, and wall-clock intent remain. Permissionless re-lowering,
cadence probes, and every lower/emergency/conditional/rebinding path are
superseded; launch hosts are monotonic raise-only.

FORWARDING_CAP classification is tightened: parameters on purchase or
mint paths whose raise increases a revert threshold are reclassified
FAIL_CLOSED_PRECHECK regardless of read-path association (closing the
ratchet loophole); a permissionless re-lower to the last probe-passing
value is added for FORWARDING_CAP parameters (bounded, probe-gated,
symmetric with the raise); fixed caller stipends (2300-gas class) are
inventoried and their interaction with raises documented per parameter.
GTP cadence handles acceleration: faster block cadence triggers the same
review obligation, and wall-clock floors bind in both directions.

### V8. Museum floor and packet completion

The conservation floor's tier defaults flip: collections declare a
conservation tier at creation, and undeclared collections default to
museum-grade-lite (intent + rights + masters for the media class;
interview waivable) rather than floor-absent — full museum-grade stays
opt-in, absence becomes a declared choice, never a silent default.
Owning institutions gain notice-and-objection standing in post-finality
recovery (recovery notices route to the token owner and any registered
owner-records steward with a pinned objection window feeding the guardian
veto). Valuation/insurance joins the owner-records families. Tombstone and
interview escalate from warning to blocking at finality for every
collection (not only museum-grade). The citation profile crosswalks to
persistent-identifier practice (DOI/ARK mapping guidance). Preservation-
coverage status is defined for ONCHAIN and SERVICE_BACKED_MUTABLE
collections in the acquisition packet. The institutional-validation gate
floor rises to two independent repository ingests and two named
practitioner reviews. C2PA re-validation archives its trust anchors
(certificate chains join the dual-family rule). Legal reproducibility of
archived proprietary environments is addressed (open-source-preferred
environment rule; proprietary components require a preservation-license
note or a documented substitution). The entropy provenance packet item
cites its pinned schema anchor.

### V9. Meta hygiene

The genesis-inventory self-count contradiction is fixed by one countless
statement pattern (the matrix owns the number; every other mention cites
it without restating a numeral). ADR 0004 is partitioned visibly:
owner-designated Permanent anchors are grouped under a marked "Normative
Homes (current)" banner, and baseline-era content sits under the existing
non-normative evidence label. The 47 nonconformant citation shapes are
corrected and the citation rule gains the ADR 0009 numeric-id exemption
note (its ids are plain numerals by construction). [PV1-MINT-ORDER]
invariant 7's false placement claim is corrected. Residual should/must
confusion on the flagged Permanent surfaces is resolved must-ward. A gate
verifies the genesis specBundleHash pins the Final-status revision set.
The 2040-naming puzzles flagged (abbreviation-style constants) gain
glossary entries rather than renames (values are pinned). OQ-X8
blast-radius: the register documents the facade option's invasiveness
honestly instead of asserting containment. The unbuilt-checkers risk is
answered structurally: every checker named by the specs joins a single
"Verification Tooling Backlog" table in the matrix with a Review-entry
condition that they exist and pass before any spec enters Review.

## Non-Goals

OQ-X8 and its dependents (BEST5-01, MINT5-01, the marketplace-commitment
asymmetry insofar as it rides on X8) remain owner-reserved. The
iteration-loop meta-finding (BEST5-12) is answered by process, not spec:
the loop closes pending owner recalibration.

## Accepted Risks

V1 makes pre-sale Arweave-class uploads a hard sale dependency (accepted:
that is the product's promise); V3's rebinding flow introduces a governed
path that changes future economics of misappropriated platform works
(accepted: append-only, arbiter-gated, artist-verified); V8's default
floor raises baseline artist obligations (accepted: silence should not
mean nothing).
