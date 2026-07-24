# ADR 0013: World-Class Pass Round 4

## Status

Accepted.

Accepted 2026-07-05 under the same protocol-owner direction as ADR 0010
through ADR 0012. The fourth nine-lens review returned 92 findings (six
lenses at 9.0; average 8.78). One finding is a genuine mechanical blocker
in the newest seam (artist payout resolution); the OQ-X8 family of
findings remains owner-reserved and is not decided here. This ADR resolves
the 90 non-reserved findings.

## Problem

Round-4 findings live almost entirely in the seams between the newest
subsystems: the artist-economics/template seam is mechanically
unimplementable (no typed payout read); the module registry violates the
set's own state-only enumeration standard; steward authority contradicts
itself for heirless artists; two incompatible regimes share the "Governed
Time Parameter" name; the museum conservation floor is still gated on
optional ceremonies; and a crop of event-schema, precheck-shape, and
vocabulary drifts landed with the round-3 text.

## Decisions

Cited from the specs as "(ADR 0013 decision U<n>)".

### U1. Typed artist payout resolution (fixes the blocker)

The artist registry gains a Permanent typed payout surface:
`artistPayoutAccount(artistId)` and `collaboratorPayoutAccount(artistId,
collaborator)` reads backed by an identity-revision-class, artist-signed
payout designation record. `COLLECTION_ARTIST` and collaborator template
sources resolve through these reads at settlement time; the economics
consent recorded under [AA-ECON] binds the designation revision in force
at consent, and a later designation revision re-points future settlements
without re-consent (revisions are themselves artist-signed).
`authorityAddress` is never a payout fallback; an unset designation makes
artist-bound templates unresolvable and settlement reverts. ADR 0008, the
revenue templates home, and [AA-ECON] all cite this one surface and one
resolution moment.

### U2. Registry and manifest state-onlyness

Amended by [ADR 0017](0017-raise-only-parameter-governance.md): the registry,
manifest, allocation, enumeration, and export decisions remain; GGP/GTP host
reads now expose only live value, immutable registration facts, and monotonic
revision. Probe binding and probe-age fields are removed.

The module registry interface gains append-only enumeration
(`moduleCount()`/`moduleAt(index)`) and a record-chain accumulator lane for
registrations, exported as a record-chain leaf and cited as the state-side
address-set derivation for event-history reproduction. The system-manifest
payload joins the onchain-bytes catalog class (SSTORE2 bytes with a
state-readable pointer), so state-only payload discovery no longer
bootstraps through an offchain document; the genesis deployment profile
remains the human mirror. Each GGP/GTP parameter gains pinned host reads for
live value, immutable registration facts, and monotonic revision so governed
raises depend on state, not mirrors. Collection-ID allocation and enumeration
are pinned (sequential from 1, count read).
Between-snapshot history loss is answered by an export-on-material-change
rule for assignment/pointer families in addition to the cadence.

### U3. ENDOWED means cryptoeconomic storage

The mandatory ENDOWED archival slot is satisfiable only by
cryptoeconomically endowed storage classes (Arweave-class pay-once with
protocol-verifiable receipts); institutional promises, however credible,
count as the second family at most. Sold-work coverage windows tighten:
the sale-time preservation lane's window floor drops to 30 days and the
operator-infrastructure-only period is a monitored state from day one.

### U4. Artist authority seam repairs

Heirless-artist posthumous finality is unblocked: steward authority for
ARTIST_INTENT and attestation families is harmonized across [AA-ATTEST],
[AA-INTENT], and [AA-DORMANCY] (stewards may complete conservation
documentation with authority-class marking; sanction remains
estate/successor-only unless the artist pre-signed a steward sanction
grant). Arbiter supersession cannot strip lifetime guardians of the
identity-recovery veto (guardian veto survives unless the guardians
themselves are the disputed party, which requires the appeal tier).
Artist-bound collections gain the same permissionless third-party
attribution-claim surface PLATFORM_WORKS has. The artist identity document
gets a pinned schema (required members, canonicalization, revision rules)
in the domain-constants discipline. Entropy configuration changes and
fresh-entropy redraws for artist-bound collections join the artist
consent/veto surface (they change the work). Collaborator identity
registration is specified (same propose/accept flow, collaborator-scoped).
Reinstatement of arbiter-revoked attributions requires the same procedure
class as revocation. The attribution object pins a registry-read failure
posture (`attribution_unavailable`, never a silent default). Steward
recovery approval for scoped finality is disambiguated (scoped records
follow the same authority table as collection records). The burn-block
naming drift is fixed against [CMC-BURN], and a Core burn-height read is
added so minted-before enforcement is implementable (with [CMC-BURN] as
home). Artists may elect registry-immutability per binding (recorded
election obligates the pointer-freeze path). Guardian sets gain a
holder-latency rule sized against the rotation-contest window.

### U5. Governance closure

Batch execution pins payable-value semantics (per-call values, sum equals
msg.value). Guardian-module authorizations gain renewal obligations and
staleness monitoring. The ROLE_* vocabulary is completed for every
authority the machinery references (reveal owner, arbiter tiers, fixity
operator, export publisher, claim-router operator, emergency recipient —
now a role reference, not a raw address). The Role Model table admits
governor contracts wherever Safe/multisig appears. "Role-redundant
holders" is defined testably (at least two independent holders, neither a
single EOA). The two schedule ABIs are reconciled (single-call schedule is
defined as the batch of one; one canonical entrypoint). Scheduled-action
calldata preimages must be published onchain (SSTORE2 pointer in the
action record) for the open-to-execute window. The ADR 0004 internal
24h/72h terminal-freeze contradiction resolves to 72 hours everywhere.

### U6. Sales and mint seam repairs

Reveal-fee line items are specified for every escrow-holding/deferred sale
kind (escrowed at purchase, reconciled at finalization; live-read fee
drift handled by the maxFee/pull-credit pattern, closing the reintroduced
exact-payment griefing). Standard Dutch schedules require
`restingPrice >= minClearingPrice > 0` unless the sale kind is explicitly
declared a free-mint class. External-collection burn-to-mint gets a frozen
recipe (external-burn proof adapter profile with per-collection trust
declaration). Multi-unit edition auctions and bundle/lot sales are
declared explicit exclusions with extension profiles named. A genesis
adapter is named as the pick-your-piece carrier. Merkle `priceOverride`
semantics under time-varying kinds are pinned (override = ceiling, never
below clearing floor). Airdrop batches gain per-recipient failure
isolation (failed receiver diverts to a pull claim, batch never reverts).
Delegated authority extends to bidding, offers, and claims via the same
delegate-registry gate class. Dual-digest replay consumption for
mint-executing offer acceptance is pinned (offer digest and sale
authorization consumed atomically). Custody-path revocation for
ERC-1271-signed authorizations is made implementable (revocation keyed by
digest plus authorizer account, with an ERC-1271 revocation verification
path). Settlement NFT delivery attempts become bounded external calls with
a GGP, consistent with every other adapter call. Account-type branching
never keys on code-presence alone (EIP-7702-safe: explicit claim paths
instead of code-size heuristics), and wallet-class rules note 7702
delegated EOAs. Anti-snipe/increment floors become per-sale-kind defaults
that a collection may explicitly waive at creation (recorded, displayed),
restoring curatorial choice without silent footguns. A consignment-sale
collector disclosure requirement is added.

### U7. Pattern and event hygiene

Mint and entropy event homes re-pin production signatures with
schemaVersion (and the coordinator/provider stragglers add it). The
reference royaltyInfo precheck is corrected to the EIP-150 shape with a
coupling invariant tying the return buffer to the resolver GGP as it
raises. Capped-returndata discipline is stated for delegate-registry and
artist-registry read surfaces. A forbidden-pattern row bans upgrade
proxies and selfdestruct across the genesis inventory unconditionally.
In-struct chainId duplication gets a cross-cutting rule (typed domains
carry chainId; structs repeat it only where the domain is shared across
chains-scoped adapters — one rule, applied per family). Primary-settlement
contracts get an explicit reentrancy-guard mandate. The sorted-pair Merkle
node exception to the encodePacked ban is documented where the ban lives.
FreshRecoveryPolicy stepsHash gains a domain. The VRF reference
constructor matches the recommended VRF version's subscription-ID width.
AT_MINT reveal attempts name their bound (GGP). Escrow recovery
strengthens: redirecting owed funds requires the affected recipient's
consent signature or the full terminal-delay class with artist/recipient
notice — never a hedged short path.

### U8. Museum floor de-ceremonied

Museum-grade collections must record artist intent, interview (pinned
minimal instrument schema), preservation masters (a must for time-based
media — display derivatives never satisfy the master slot), and rights
records before the first sale, not at optional ceremonies. The acquisition
packet includes the artist-intent/interview record, token-scoped rights
variance, hash-committed condition-report captures, and the latest drill
outcome. Reference-render capture semantics are defined for time-based and
interactive works (duration, frame-rate, input-script capture classes)
and the PERCEPTUAL_TOLERANCE metric names a concrete default (SSIM
threshold pinned per work). Dossier bags must embed render-critical
payload bytes (fetch-only packaging is nonconformant for them). The
independent-attestor vocabulary widens for post-operator stewardship
(condition, exhibition, conservation-treatment, environment-migration
record kinds). An institutional-validation evidence gate is added: a named
external repository ingest test and at least one named conservation
review of the dossier profile before Review status. artistId-to-legal-
person binding at acquisition standard gets a named verification pattern
(notarized attestation record class). Tombstone and rights records get
ingest crosswalks like PREMIS.

### U9. Register and process hygiene

The open-questions register is refreshed against rounds 2-4 (superseded
posture text corrected; OQ-X8's lifecycle gate is restated decidably:
X8 blocks Review entry for the metadata specs only, and the register says
exactly that). Status-header citation drift, residual scaffolding
language, stray unpinned constants, and missing bracketed anchors flagged
by the meta lens are corrected. The operations-and-competitiveness
hygiene items ride under this decision id: the funding manifest gains
the [LTA-FUNDING] coverage-horizon viability floor with an
automation-first posture and one consolidated obligation calendar; the
protocol v1 scope records the honest collector cost position; and the
matrix gains the collector interaction budget, the staged audit waves,
and the hardened marketplace-commitment evidence rules. The GTP naming collision is resolved: the
umbrella pattern keeps the name Governed Time Parameters; the
per-collection artist-elected timing fields are renamed collection timing
policies and removed from the GTP closed world.

## Non-Goals

OQ-X8 and its dependent findings (marketplace collection identity, its
secondary-market implications, and the identity-verification gap that
rides on it) remain owner-reserved.

## Accepted Risks

U3 narrows acceptable storage families (accepted: endowment is the point);
U6's waivable auction floors trade a footgun back for curatorial freedom
(accepted: recorded and displayed waivers); U8 raises artist onboarding
work for museum-grade collections (accepted: that is what the tier means —
and the tier is optional per collection).
