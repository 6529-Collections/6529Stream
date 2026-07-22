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

None. Every question this register has tracked is resolved. The 25
permanence-reframe questions were resolved on 2026-07-04 through
[ADR 0009](adr/0009-protocol-v1-open-question-resolutions.md) (count
corrected from 24 per ADR 0010). The successive nine-lens review rounds
were resolved through [ADR 0010](adr/0010-world-class-spec-pass.md)
(round 1, 112 findings), [ADR 0011](adr/0011-world-class-pass-round-2.md)
(round 2, 98), [ADR 0012](adr/0012-world-class-pass-round-3.md)
(round 3, 86), [ADR 0013](adr/0013-world-class-pass-round-4.md)
(round 4, 92), and [ADR 0014](adr/0014-world-class-pass-round-5.md)
(round 5, 83). OQ-X8, the single question the protocol owner reserved,
was resolved on 2026-07-05 through
[ADR 0015](adr/0015-collection-identity-and-facade-readiness.md). Its
W3-W5 launch-facade posture was superseded before genesis by
[ADR 0016](adr/0016-core-native-only-erc721.md); W1/W2 remain in force.

## Resolved

### OQ-X8: Marketplace-consumable collection identity signal

Resolved 2026-07-05 by explicit protocol-owner ratification through
[ADR 0015](adr/0015-collection-identity-and-facade-readiness.md). The
question: sequential global token IDs (ADR 0009 decision 1) plus a
shared multi-collection Core leave marketplaces and indexers no standard
signal for grouping tokens into collections.

- Adopted (ADR 0015 decision W1): the on-chain collection-metadata reads
  — deployment-level ERC-7572 `contractURI()` plus the per-collection
  collection-metadata read through the router — and the
  `properties.stream.collection` token-JSON member set are the
  normative, Permanent collection-identity signal, together with the
  Core identity reads and documented indexer integration guidance.
- Adopted (ADR 0015 decision W2): the collection-display evidence gate
  hardens to at least two named, signed marketplace/indexer integration
  commitments recorded in the release evidence set before the first
  public sale.
- Superseded before genesis (ADR 0016): ADR 0015 decisions W3-W5 do not
  authorize launch facade-readiness storage, selectors, events, branches,
  callbacks, or finality components. Every launch token has Core as its sole
  ERC-721 identity. The former facade profile is historical successor-line
  research only; any future wrapper or successor asset model requires a new
  accepted ADR and cannot weaken the W2 evidence gate.
- Rejected: ERC-7496 dynamic traits as an identity carrier (off-label;
  adds no capability beyond the token-JSON member set); a facade line or
  dormant facade preconditions at genesis (first-of-kind composite and
  contract-wide ERC-721 conformance cost); a bare tripwire with no genesis
  surfaces (the fallback would be decorative).
- Lettering note: earlier revisions of this entry used two conflicting
  option letterings — the register's option list labeled an additive
  indexer-registry read "(c)" while the blast-radius note (ADR 0014
  decision V9) used "(c)" for the facade line from the layered
  recommendation. The resolution above names options outright instead of
  by letter; the V9 blast-radius finding applies to the facade line.
- Lifecycle effect: the Review-entry blocker on
  [`docs/metadata-router-and-renderer.md`](metadata-router-and-renderer.md)
  and
  [`docs/collection-metadata-contract.md`](collection-metadata-contract.md)
  is removed; ordinary Review-entry conditions of
  [`spec-policy.md`](spec-policy.md) continue to apply.

The 25 entries below were resolved earlier, on 2026-07-04. Their decision
record is
[ADR 0009: Protocol V1 Open-Question Resolutions](adr/0009-protocol-v1-open-question-resolutions.md);
decision numbers refer to it. OQ-X5 and OQ-X6 were ratified explicitly by
the protocol owner; the rest were delegated under the review lens "the most
world-class approach, not the most convenient for us now." The subsequent
nine-lens review findings were resolved through
[ADR 0010: World-Class Specification Pass](adr/0010-world-class-spec-pass.md),
which also opened OQ-X8 as the single reserved question, resolved above.

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
