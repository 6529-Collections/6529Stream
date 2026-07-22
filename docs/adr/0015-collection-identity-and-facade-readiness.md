# ADR 0015: Collection Identity Resolution and Facade Readiness

## Status

Superseded in part by
[`ADR 0016`](0016-core-native-only-erc721.md) for the pre-genesis launch line.
Decisions W1 and W2 remain accepted. Decisions W3, W4, and W5 are historical
and must not be implemented in the launch Core: the contract-wide ERC-721
review proved that selective per-token shutdown of Core approval/transfer/event
semantics is nonconformant. W6 remains historical register context.

Accepted 2026-07-05 by the protocol owner. This ADR resolves OQ-X8 — the
single question the owner reserved through five review rounds (ADR 0010
decision D11) — and decides the facade-readiness posture that makes the
resolution's fallback real. Unlike the delegated round ADRs, every
decision here was ratified explicitly by the protocol owner in direct
review.

## Problem

Sequential global token IDs (ADR 0009 decision 1) plus a shared
multi-collection Core leave marketplaces and indexers no standard signal
for grouping tokens into collections. Ethereum has no sub-collection
identity standard: address-per-collection is the ecosystem's only native
grouping key. The interim machine path (per-collection `contractURI`
through the router, `properties.stream.collection` token-JSON fields, a
collection-display evidence gate) shipped as posture, not resolution.

The candidate resolutions were not equally contained (ADR 0014 decision
V9): the additive options ride the shipped path, while the per-collection
ERC-721 facade line — the only option that hands address-keyed venues
their native grouping key — relocates the protocol's ERC-721 identity
surface and touches Core mint delivery, approvals, royalty addressing,
finality identity, and the export/event-history model. Prior art exists
for every mechanism the facade composes (ERC-7631/DN404 mirror emission,
ENS registry-fronting) but no production deployment composes them at
per-collection cardinality; the facade is a first-of-kind composite.

A tripwire fallback is only real if the Permanent layer preserves its
possibility: if Core ships at genesis without the surfaces a facade
needs, "fall back to facades" means redeploying Core. The facade's
Core-side preconditions are therefore genesis-binding even though the
facade itself is not a launch component.

## Decisions

Cited from the specs as "(ADR 0015 decision W<n>)".

### W1. Normative collection identity signal: reads plus token JSON

The interim machine path is promoted to the normative, Permanent
collection-identity signal:

- the deployment-level ERC-7572 `contractURI()` on Core and the
  per-collection collection-metadata read exposed through the metadata
  router, with
  [`docs/metadata-router-and-renderer.md`](../metadata-router-and-renderer.md)
  as home;
- the `properties.stream.collection` token-JSON member set (collection
  ID, collection name, artist attribution, collection-local serial, and
  the global catalog number), pinned as a normative schema with
  [`docs/collection-metadata-contract.md`](../collection-metadata-contract.md)
  as home;
- the Core identity reads (`tokenCollectionIdentity`, collection
  allocation and count reads) plus documented indexer integration
  guidance, already normative in the umbrella and integrations set.

ERC-7496 dynamic traits are explicitly not adopted for collection
identity: a token-trait standard used off-label for identity adds
surface without adding capability beyond the token-JSON member set.

### W2. Marketplace commitment gate

The collection-display evidence gate hardens from "evidence of display
capability" to named, signed integration commitments: before the first
public sale, at least two major marketplaces or indexers must have
recorded, attributable, written commitments to consume the W1 signal and
render per-collection identity. The commitments join the release
evidence set with a pinned evidence class (named counterparty qualified
against the matrix's pinned marketplace-target manifest, dated artifact,
verifiable authenticity); the conformance matrix owns the gate row.
Best-effort outreach does not satisfy the gate; a commitment
memorialized only in conversation does not satisfy the gate.

### W3. Facade tripwire

The per-collection ERC-721 facade line is a named extension profile,
never a launch dependency. If the W2 gate cannot be satisfied before the
public-sale boundary, the facade profile advances automatically to a
deployment decision: a dedicated adversarial review round against
then-current marketplace reality, then a protocol-owner go/no-go. The
tripwire fires before public sale by construction, while facade adoption
for the deployment's collections is still clean. A no-go — or a go with
no facade yet bound for the launch collections — does not waive the
exposure: the release evidence must then additionally carry an
owner-signed risk acceptance naming the unmet commitment count and the
accepted per-collection display exposure. The tripwire review's
mandatory scope includes the sales/custody seam: custody-settling sale
kinds and Stream-source burn-to-mint programs are excluded for
`EXTERNAL_FACADE` collections — configuration reverts — until
facade-aware adapter profiles are accepted in that review.

Retrofit is excluded: identity mode is one-way and pre-first-mint (W4),
so a collection that minted under Core-native identity can never migrate
to a facade. If facades ever ship, they apply to collections created
after the decision.

### W4. Facade-readiness genesis surfaces

Core ships the following Permanent surfaces at genesis, dormant, so the
W3 fallback never requires a Core redeployment. The umbrella owns the
doctrine; the protocol v1 spec owns the surface shapes and constants.

1. Per-collection identity mode. Every collection carries an identity
   mode from the closed vocabulary `CORE_NATIVE` (default) and
   `EXTERNAL_FACADE`. Declaration is one-way, allowed only before the
   collection's first mint, immutable from that mint onward, and evented.
   An undeclared collection is `CORE_NATIVE` by construction. For
   artist-bound collections the declaration joins the artist
   consent/veto surface of
   [`docs/stream-artist-authority.md`](../stream-artist-authority.md) —
   the mode changes the marketplace identity of the work. Because the
   facade address is the thing that actually fixes that marketplace
   identity, an `EXTERNAL_FACADE` declaration on an artist-bound
   collection binds the mode and the controller together in the consent
   state, and the declaration and controller registration execute in
   one atomic governed batch.
2. Transfer-controller registry. An `EXTERNAL_FACADE` collection binds
   exactly one transfer controller — its facade — before its first mint;
   the binding is one-way and immutable. Registration for a
   `CORE_NATIVE` collection reverts, permanently. The controller must be
   a Permanent-class contract conforming to the facade profile (W5) and
   already registered in the module registry at binding time.
3. Controlled mutation path. For `EXTERNAL_FACADE` collections, Core's
   native per-token entries (`approve`, `transferFrom`,
   `safeTransferFrom`, and any native burn entry) revert per token;
   contract-wide operator grants (`setApprovalForAll`) remain
   recordable — the entry is owner-scoped and contract-wide, so it
   cannot revert per collection without breaking `CORE_NATIVE` use —
   but convey no authority over `EXTERNAL_FACADE` tokens because every
   consuming native entry reverts. The sole ownership-mutation entry is
   the controller-called path, which enforces exactly the native
   ownership-mutation invariant set — current-owner match and a nonzero
   recipient for transfers, and the native burn-precondition suite for
   the `to == address(0)` burn case — and conditions nothing more:
   locks, finality components, and pause never gate ownership transfer
   on this Core line, in either mode (transfer openness per the
   umbrella standards doctrine; anything stricter would make facade
   tokens soulbound where native tokens transfer freely). The path
   settles all Core state and record-chain writes before any call back
   into the controller — the ownership-change notification to the
   controller is the terminal step of the mutation
   (checks-effects-interactions, no exceptions). Exactly one live
   mutation path exists per collection in either mode.
4. Event doctrine carve-out. `EXTERNAL_FACADE` collections emit a
   controlled-ownership-change event family at Core in place of ERC-721
   `Transfer`; the facade is the exclusive ERC-721 `Transfer` emitter
   for its tokens. `CORE_NATIVE` collections are unchanged. State reads
   (`ownerOf`, `totalSupply`, lifecycle, identity) answer identically in
   both modes; record chains and state exports are mode-independent.
5. Finality identity binding. For `EXTERNAL_FACADE` collections the
   facade address and its local-ID rule are bound into the collection's
   finality components through a pinned record family, so the
   two-address identity is part of the work's permanent identity, not an
   offchain convention.
6. Facade token identity. The facade-local ERC-721 token ID is the
   collection-local serial; the global sequential token ID remains the
   protocol catalog number, readable through the facade and carried in
   token JSON and state exports. The facade's `totalSupply()` reads the
   collection's live count from a pinned per-collection supply read
   Core exposes from genesis. Global allocation order (ADR 0009
   decision 1) is untouched in both modes.
7. Zero-governance posture. Mode declaration and controller registration
   are governed actions; with governance lost neither is possible, and
   the dormant surfaces are inert — the zero-signer museum-mode drill
   proves a `CORE_NATIVE`-only deployment is identical on every
   pre-ADR-0015 surface, with the facade-readiness reads answering
   their dormant defaults and the governed entries reverting for every
   caller.

### W5. Facade extension profile document

The facade line is specified now, in full, as a dormant extension
profile: a new specification,
[`docs/stream-collection-facade-profile.md`](../stream-collection-facade-profile.md)
(Draft), joins the specification inventory covering the facade
interface, local-serial identity and catalog-number read, exclusive
emission rules, facade-local approval model, a conditional burn entry
(present exactly when the collection's burn posture permits — with
native burn closed under W4.3, the facade is the only possible burn
origin for its collection), delegation of
`tokenURI`/`royaltyInfo`/`contractURI` and metadata-refresh signaling to
Core and the router, per-facade Permanent-class requirements, the threat
model (controller authority abuse, reentrancy through the routed
mutation, event-exclusivity violations, per-collection containment), and
the W3 deployment-decision procedure. Physically absent at genesis;
deployable at tripwire without a design sprint.

### W6. Register hygiene and lifecycle effect

OQ-X8 moves to Resolved citing this ADR. The register's lettering defect
is corrected: the blast-radius note referenced the layered
recommendation's facade item as "(c)" while the register's own option
(c) was an additive registry read; the resolved entry restates the
adopted signal, the rejected options, and the tripwire without ambiguous
lettering. Closing X8 removes the Review-entry blocker for
[`docs/metadata-router-and-renderer.md`](../metadata-router-and-renderer.md)
and
[`docs/collection-metadata-contract.md`](../collection-metadata-contract.md);
their entry into Review remains subject to the ordinary conditions of
[`docs/spec-policy.md`](../spec-policy.md).

## Alternatives

- Facade at genesis: rejected — first-of-kind composite with
  undemonstrated containment as a launch dependency (ADR 0014 decision
  V9).
- Bare tripwire with no genesis surfaces: rejected — the fallback would
  require a Core redeployment, making it decorative exactly when needed.
- ERC-7496 traits as the identity signal: rejected (W1).
- Custody-wrap facades (lock in Core, mint mirror): rejected — breaks
  the state-trie ownership doctrine; Core state must record real owners.

## Security Impact

W4 adds a dormant standing authority surface to Core — the most
security-sensitive invariant in the system (ownership mutation).
Mitigations are structural: empty at genesis; registrable only
pre-first-mint on collections explicitly declared `EXTERNAL_FACADE`;
one-way bindings; identical invariant enforcement on the controlled
path; terminal-step-only controller callbacks; per-collection
containment (a compromised or defective facade affects exactly its own
collection); zero-governance inertness. The facade profile's threat
model (W5) and the conformance gates (matrix) carry the adversarial
detail.

## Release Impact

New domain constants (the identity-mode vocabulary, the consent family
identifier, the controller callback selector, the facade module type,
and the finality binding record type) enter the pinned tables with
hashes recomputed from their adjacent preimages under the mirror-table
discipline; the new event signatures
(`CollectionIdentityModeDeclared`, `CollectionTransferControllerRegistered`,
and the controlled-ownership-change family) enter the event catalogs
with golden tests. The matrix gains the W2 commitment-gate row and W4
positive/negative gates. The release evidence set gains the commitment
evidence class.

## Test Plan

Golden tests for the identity-mode and controller reads; negative gates:
mode declaration reverts after first mint, controller registration
reverts for `CORE_NATIVE` collections and after first mint, native
transfer entries revert for `EXTERNAL_FACADE` collections, controlled
path reverts for unregistered callers; CEI-ordering test on the
controlled mutation; event-exclusivity assertions per mode; zero-signer
drill extension proving dormant-surface inertness.

## Rollout Plan

Spec-only in this change: the genesis surfaces land in the protocol v1
spec and umbrella, the profile document enters the inventory at Draft,
and the matrix gates land. Implementation follows the conformance
matrix; no facade deploys at genesis.

## Non-Goals

No facade deployment at genesis; no retrofit path for `CORE_NATIVE`
collections; no commitment to fire the tripwire — W2 success retires it
to a permanent dormant option.

## Accepted Risks

Marketplace cooperation is outside protocol control; W2 converts hope
into evidence but cannot compel venue-primitive integration
(address-keyed collection bids remain integrator work). If the tripwire
fires, the facade remains a first-of-kind composite; the dedicated
review round is the mitigation, and the genesis surfaces cap the cost of
that path at "deploy and review" rather than "redesign Core".
