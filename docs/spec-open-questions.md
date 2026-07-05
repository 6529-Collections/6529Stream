# Stream Specification Open Questions

Specification status: living register. Conventions are defined in
[`docs/spec-policy.md`](spec-policy.md).

This register tracks every decision that is genuinely open across the Stream
specification set. Each open entry has an inline `**[OQ-…]**` marker at the
decision site in the owning spec. A spec that defines Permanent surfaces
cannot reach `Final` while any entry here still blocks it.

Namespaces: `X` cross-cutting, `R` revenue/royalties, `M` mint
policy/accounting, `MR` metadata router/renderer, `CM` collection metadata,
`E` entropy coordinator, `EP` entropy providers.

## Open

### OQ-X8: Marketplace-consumable collection identity signal

The one question the protocol owner has reserved (ADR 0010 decision D11).
Sequential global token IDs (ADR 0009 decision 1) plus a shared
multi-collection Core contract leave marketplaces and indexers no
consumable signal for grouping tokens into collections — the range
heuristic is gone by design, and nothing standard replaced it.

- Why it blocks: collector-facing collection pages, marketplace search,
  and third-party analytics all need a grouping signal; without a specified
  one, every integrator invents their own and the ecosystem fragments.
- Lifecycle gate (restated decidably per ADR 0013 decision U9): OQ-X8
  blocks Review entry for
  [`docs/metadata-router-and-renderer.md`](metadata-router-and-renderer.md)
  and [`docs/collection-metadata-contract.md`](collection-metadata-contract.md)
  only. Every other document may enter Review with X8 open; no document
  reaches `Final` while a question it depends on is open, per
  [`spec-policy.md`](spec-policy.md).
- Reserved-scope satellites (round-3/4 review findings that ride on X8 and
  are reserved with it): the secondary-market life of every drop pattern
  under a shared contract, marketplace-native artist identity verification
  insofar as it depends on collection pages, and the per-collection facade
  option. The machine path shipped so far (per-collection `contractURI`
  through the router, `properties.stream.collection` fields, the
  collection-display evidence gate with standing-commitment hardening) is
  the interim posture, not the resolution.
- Blast-radius honesty (ADR 0014 decision V9): the candidate resolutions
  are not equally contained. Options (a), (b), and (d) are additive to the
  shipped machine path. Option (c) — the per-collection ERC-721 facade
  line — is invasive: it would touch Core mint delivery, marketplace
  approvals, royalty resolution addressing, finality component identity,
  and the export/event-history model, and its containment has not been
  demonstrated. If (c) is the owner's direction, a dedicated design spec
  and a fresh review round precede any adoption.
- Options: (a) per-collection contract-metadata surfaces (an ERC-7572-style
  collection-scoped `contractURI` read exposed through the router);
  (b) ERC-7496 dynamic traits carrying collection identity; (c) a pinned
  indexer-facing collection registry read plus documented integration
  guidance; (d) marketplace-standard sub-collection metadata in token JSON
  (`properties.stream.collection`) plus outreach to major marketplaces.
- Recommendation: none recorded — reserved to the protocol owner. For the
  owner's consideration, the round-2 best-in-world reviewer proposed a
  layered resolution: (a) commit the per-collection ERC-7572 `contractURI`
  read plus `properties.stream.collection` fields as the normative signal;
  (b) pursue a standards-track EIP for sub-collection identity with named
  marketplace co-sponsors; (c) evaluate a thin immutable per-collection
  ERC-721 facade line (address-per-series fronting Core identity) as an
  extension profile; (d) convert the display-evidence gate into named,
  signed integration commitments from at least two major
  marketplaces/indexers before public sale.
- Decision owner: protocol owner.

All 25 other questions raised by the permanence reframe were resolved on
2026-07-04 through
[ADR 0009](adr/0009-protocol-v1-open-question-resolutions.md) (count
corrected from 24 per ADR 0010). The successive nine-lens review rounds
were resolved through [ADR 0010](adr/0010-world-class-spec-pass.md)
(round 1, 112 findings), [ADR 0011](adr/0011-world-class-pass-round-2.md)
(round 2, 98), [ADR 0012](adr/0012-world-class-pass-round-3.md)
(round 3, 86), and [ADR 0013](adr/0013-world-class-pass-round-4.md)
(round 4, 92) — every finding resolved except the OQ-X8 family above.

## Resolved

The 25 entries below were resolved 2026-07-04. The decision record is
[ADR 0009: Protocol V1 Open-Question Resolutions](adr/0009-protocol-v1-open-question-resolutions.md);
decision numbers refer to it. OQ-X5 and OQ-X6 were ratified explicitly by
the protocol owner; the rest were delegated under the review lens "the most
world-class approach, not the most convenient for us now." The subsequent
nine-lens review findings were resolved through
[ADR 0010: World-Class Specification Pass](adr/0010-world-class-spec-pass.md),
which also opened OQ-X8 above as the single reserved question.

### Cross-cutting

- OQ-X1 — Canonical module identity read surface. Resolved (decision 3):
  one merged, `stream`-prefixed eight-function surface
  (`streamModuleType` … `streamModuleManifest`), canonical in
  [`stream-long-term-architecture.md`](stream-long-term-architecture.md),
  golden-tested selectors; both prior variants replaced.
- OQ-X2 — StreamCore size policy. Resolved (decision 2): the governing
  deployment rule is at least 2,000 bytes of EIP-170 margin, proven by one
  post-extraction measured build with the full hook set; the 22,000-byte CI
  constant is retired; the bytecode-spend exception ledger remains the
  pre-deployment control and exceptions cannot survive to the deployment
  gate.
- OQ-X3 — Entropy fallback posture. Resolved (decision 21): genesis ships
  Chainlink VRF primary plus one reviewed fallback provider (ARRNG
  preferred, Pyth alternate); VRF-only deployment is not conformant; the
  `StreamEntropyLaunchDecision` manifest records the shipped fallback and
  failure posture.
- OQ-X4 — `maxRoyaltyBps`. Resolved (decision 7): 1000, immutable in Core.
- OQ-X5 — Token ID allocation (protocol-owner decision). Resolved
  (decision 1): sequential global token IDs from one counter starting
  at 1; explicit stored `collectionId` and `collectionSerial`; the
  namespaced-range formula is removed and token ID arithmetic carries no
  meaning.
- OQ-X6 — Scoped-finality surfaces (protocol-owner decision). Resolved
  (decision 6): the genesis finality registry ships all five scopes —
  `COLLECTION`, `TOKEN`, `RELEASE`, `SEASON`, `VIEW` — fully specified,
  fully tested, and gate-covered.
- OQ-X7 — ADR 0008 status. Resolved (decision 10): ADR 0008 is Accepted,
  amended by decisions 8 and 9.

### Revenue and royalties

- OQ-R1 — Global freeze scope. Resolved (decision 8): a deployment-wide
  global freeze blocks both existing keys and the creation of new revenue
  classes.
- OQ-R2 — Assignment-hash freeze binding. Resolved (decision 9): the
  canonical `assignmentHash` preimage binds `bool(frozen)` only; the prose
  in the revenue spec and ADR 0008 was corrected to match.

### Mint policy and accounting

- OQ-M1 — Cross-phase counter derivation. Resolved (decision 11):
  `COLLECTION_SCOPE_PHASE_ID = 0` is the reserved collection-scope value;
  real phases register with `phaseId >= 1`; one derivation function,
  golden-tested.

### Metadata router and renderer

- OQ-MR1 — Core `contractURI()`. Resolved (decision 4): included as a
  mandatory Core hook — a thin bounded delegated read (ERC-7572) covered by
  the size proof.
- OQ-MR2 — JSON fragment validation. Resolved (decision 12): admin-trusted
  fragments with stored hash and schema ID, evented, tooling-validated;
  onchain JSON validation rejected.
- OQ-MR3 — Renderer compatibility variables. Resolved (decision 13):
  exactly `stream`, `hash`, `tokenId`, `tokenData`, pinned and
  golden-tested.
- OQ-MR4 — Size-limit table. Resolved (decision 14): listed maxima
  ratified; deployed constants pinned by pre-deployment measurement.
- OQ-MR5 — Refresh range. Resolved (decision 15):
  `MAX_REFRESH_RANGE = 5_000`, confirmed by marketplace/indexer evidence.
- OQ-MR6 — Freeze bypass. Resolved (decision 16): no token-level exception
  may bypass Core collection freeze, absolutely and permanently; the
  escape-hatch phrasing was deleted.
- OQ-MR7 — Hybrid rendering mode. Resolved (decision 17): dormant enum
  value at genesis; hybrid arrives, if ever, as a new renderer version
  through the registry.
- OQ-MR8 — Protocol attributes. Resolved (decision 18): opt-in per
  collection.
- OQ-MR9 — Token-scope router config. Resolved (decision 19): ships in the
  genesis router.

### Collection metadata

- OQ-CM1 — Implied metadata lock. Resolved (decision 20): Core collection
  freeze never implies a metadata lock; locks are explicit only and
  required locks/snapshots precede Core freeze.

### Entropy

- OQ-E1 — `requestEntropy` access. Resolved (decision 22): minter path,
  entropy admins, and global admins; public requests opt-in per collection.
- OQ-E2 — Entropy configuration. Resolved (decision 23): per-collection
  config required and set before sale start; no coordinator-level global
  default provider.
- OQ-E3 — Refresh event emitter. Resolved (decision 5): Core-originated
  restricted ERC-4906 emitters callable by authorized satellites.
- OQ-E4 — Instant provider. Resolved (decision 24): excluded from genesis;
  addable later as a reviewed Replaceable module behind the frozen
  interface.
- OQ-EP1 — Stale-result signal. Resolved (decision 25): `fulfillEntropy`
  returns a pinned `EntropyFulfillmentOutcome` code; adapters may mark
  results `TERMINAL_STALE` only on `REJECTED_STALE_EPOCH`,
  `REJECTED_INACTIVE_REQUEST`, or the equivalent request-status
  comparison.
