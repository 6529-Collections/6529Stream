# ADR 0009: Protocol V1 Open-Question Resolutions

## Status

Accepted.

Accepted 2026-07-04 by protocol-owner direction: the token ID allocation
(OQ-X5) and scoped-finality (OQ-X6) decisions were ratified explicitly by the
protocol owner; the remaining resolutions were delegated with the review lens
"the most world-class approach, not the most convenient for us now" and are
recorded here as final. This ADR is the decision record referenced by the
`Resolved` section of [`docs/spec-open-questions.md`](../spec-open-questions.md).

## Problem

The Stream specification set was rewritten onto permanence classes
([`docs/spec-policy.md`](../spec-policy.md)). That rewrite surfaced 25 open
questions — genuine decisions, internal contradictions, and specification
gaps — each marked inline with `OQ-*` and tracked in the register. Under the
spec policy, no spec that defines Permanent surfaces can reach `Final` while
any of them is open. This ADR resolves all 25 through 25 numbered decisions
(count corrected per ADR 0010; earlier copies miscounted the set as 24).

## Current Behavior

The Draft specs carry inline `OQ-*` markers with stated defaults; several
documents state conflicting defaults for the same decision (token ID
allocation, module identity surface, Core size ceiling, royalty resolver
freeze binding); and two mechanisms (cross-phase mint counters, provider
stale-result handling) are obligated but not defined.

## Intended Behavior (Decisions)

### Identity and Core

1. OQ-X5 — Token ID allocation (protocol-owner decision): Core allocates
   sequential global ERC-721 token IDs from one global counter, starting at
   1, and stores `collectionId` and `collectionSerial` explicitly in the
   token identity record (packing them into one storage slot with bounded
   widths is an implementation choice; the read surface returns `uint256`).
   The namespaced-range formula (`collectionId * 10_000_000_000`) is removed
   from the allocator, and no serial or collection value may be derived from
   token ID arithmetic. Rationale: the identity model already mandates
   stored identity and forbids range heuristics for authority reads, so
   ranges had become cosmetic; sequential IDs remove a permanent
   range-inference temptation, stay inside every tooling ecosystem's safe
   integer ranges for centuries, and make the stream's global mint order
   readable from the ID.
2. OQ-X2 — Core size policy: the governing deployment rule is the
   conformance-matrix headroom target — `StreamCore` runtime must retain at
   least 2,000 bytes of EIP-170 margin at the deployment gate, proven by one
   post-extraction measured build that includes the full mandatory hook set.
   The 22,000-byte CI constant is retired as a governing number; the
   bytecode-spend baseline and exception ledger in
   `release-artifacts/contracts.json` remain the pre-deployment development
   control. The extraction priority order in the matrix stands; the pending
   extractions (renderer/script assembly, collection metadata storage,
   randomizer coordination) are the intended recovery path.
3. OQ-X1 — Module identity surface: one canonical, `stream`-prefixed
   on-module identity surface replaces both prior variants:

   ```solidity
   function streamModuleType() external pure returns (bytes32);
   function streamModuleVersion() external pure returns (bytes32);
   function streamModuleInterfaceId() external pure returns (bytes4);
   function streamModuleSchemaHash() external view returns (bytes32);
   function streamModuleSupersedes() external view returns (address);
   function streamModuleCodeHash() external view returns (bytes32);
   function streamModuleDeploymentManifestHash() external view returns (bytes32);
   function streamModuleManifest() external view returns (string memory uri, bytes32 hash);
   ```

   "Type" (not "family") is the canonical noun, matching the module
   registry's record fields and events. The prefix follows the
   `streamSystemManifest()` precedent and keeps the surface unambiguous in
   ABIs and explorers over decades. Selectors are golden-tested. Existing
   satellites implementing the unprefixed variant are rewritten during
   repo alignment.
4. OQ-MR1 — Core `contractURI()`: included as a mandatory Core hook.
   Marketplaces resolve ERC-7572 contract-level metadata from the ERC-721
   address, so the standards-correct permanent surface is a thin, bounded
   Core read that delegates to the contract-metadata satellite through the
   cached pointer policy, with the same fail-safe posture as `tokenURI()`.
   The hook is added to the Core hook budget and covered by the OQ-X2
   measured proof.
5. OQ-E3 — Metadata refresh events: Core-originated. Core exposes
   restricted ERC-4906 refresh emitters callable by authorized satellites
   (metadata router, finality registry, entropy coordinator paths);
   marketplaces watch the ERC-721 contract, so satellite-emitted refresh
   events do not reach them.

### Finality

6. OQ-X6 — Scoped finality (protocol-owner decision): the genesis
   `StreamArtworkFinalityRegistry` ships the full scope set — `COLLECTION`,
   `TOKEN`, `RELEASE`, `SEASON`, and `VIEW` — fully specified, fully tested,
   and gate-covered. The owner chose maximum flexibility over minimal
   surface: adding scopes later would require a successor registry version
   and split record history across registry generations. The
   conformance-matrix rule that scoped surfaces stay physically absent is
   replaced for finality scopes by full mandatory gate coverage: every
   scope ships with write/read/recovery tests, scopeId schema publication,
   numeric-ID catalog entries, and event-catalog coverage. The no-dead-path
   rule continues to apply to all other reserved surfaces.

### Revenue and Royalties

7. OQ-X4 — `maxRoyaltyBps` is 1000 (10%), immutable in Core. Market norms
   treat 10% as the royalty ceiling; a larger cap only increases the
   worst-case damage of a compromised resolver without a credible use.
8. OQ-R1 — A deployment-wide global freeze blocks both all existing keys
   and the creation of entirely new revenue classes for the frozen class
   family. A global freeze bypassable by minting a new class is not a
   credible freeze.
9. OQ-R2 — The canonical `assignmentHash` preimage binds `bool(frozen)`
   only, and the prose claim that the resolved policy hash includes
   `freezeMode` and `permanentFreeze` is corrected in both the revenue spec
   and ADR 0008. The frozen bit flips exactly on the economically
   meaningful edge (mutable to frozen) and forces `STRICT_MATCH` to revert;
   binding mode transitions (for example exact to permanent) would
   invalidate outstanding signed sales without changing economics.
10. OQ-X7 — ADR 0008 is accepted, amended by decisions 8 and 9. The
    revenue and royalty specs no longer depend on a `Proposed` ADR.

### Minting

11. OQ-M1 — Cross-phase counters: `phaseId = 0` is the reserved, named
    collection-scope value (`COLLECTION_SCOPE_PHASE_ID = 0`). Real phases
    must register with `phaseId >= 1`; the ledger and manager reject phase
    registration at 0. `GLOBAL` and `COLLECTION` scoped counters derive
    their value keys with the reserved value, keeping one derivation
    function. This is a documented reserved constant with a golden test,
    not a hidden sentinel.

### Metadata Router and Renderer

12. OQ-MR2 — Raw JSON fragments (`attributesJSON`, `propertiesJSON`) are
    admin-trusted: stored with a fragment hash and schema ID, evented, and
    validated by operator tooling before submission. Onchain JSON
    validation is rejected as gas-prohibitive security theater.
13. OQ-MR3 — `StreamRendererV1` exposes exactly four legacy compatibility
    variables — `stream`, `hash`, `tokenId`, `tokenData` — pinned for the
    renderer's life and golden-tested. No silent additions.
14. OQ-MR4 — The canonicalization and size-limit table values are ratified
    as the normative v1 limits, subject only to pre-deployment measurement
    that pins the deployed constants in the release manifest.
15. OQ-MR5 — `MAX_REFRESH_RANGE = 5_000` token IDs per
    `BatchMetadataUpdate` helper call, confirmed by marketplace/indexer
    review evidence before deployment.
16. OQ-MR6 — No token-level exception may bypass Core collection freeze,
    absolutely and permanently for this Core line. The former "unless a
    separately accepted spec introduces it" escape hatch is deleted: a
    later bypass would retroactively weaken every already-frozen
    collection's promise.
17. OQ-MR7 — Hybrid rendering mode is a dormant enum value at genesis;
    tests cover offchain and onchain modes. Renderers are Replaceable
    modules behind frozen interfaces, so hybrid arrives, if ever, as a new
    renderer version through the registry — the cheap extension path, in
    contrast to finality scopes (decision 6) where retrofit is expensive.
18. OQ-MR8 — Protocol-generated attributes are opt-in per collection.
    Default-on would change cached `tokenURI()` output for every
    collection.
19. OQ-MR9 — Token-scope metadata configuration ships in the genesis
    router. The resolution order, `TokenMetadataConfigUpdated` events, and
    router tests already assume it; shipping without it would change the
    Permanent resolution contract.

### Collection Metadata

20. OQ-CM1 — Core collection freeze never implies a metadata lock. Locks
    are explicit only, and required locks/snapshots (`SNAPSHOTS`,
    `METADATA_ALL` where promised) must be in place before Core freeze.
    Implied side effects are hidden coupling; the architecture forbids
    them everywhere else.

### Entropy

21. OQ-X3 — Genesis ships dual providers: Chainlink VRF primary plus one
    reviewed fallback provider, with ARRNG as the preferred candidate
    (existing operational experience) and Pyth as the reviewed alternate.
    A VRF-only deployment is not conformant; the former VRF-only exception
    path is removed. The `StreamEntropyLaunchDecision` manifest remains and
    records which fallback shipped, its review evidence, and the
    coordinator failure posture. If neither fallback review completes,
    deployment blocks; a single-vendor dependency for a provenance-critical
    subsystem is not acceptable for permanent infrastructure.
22. OQ-E1 — `requestEntropy` is callable by the minter path, entropy
    admins, and global admins; public requests are opt-in per collection.
23. OQ-E2 — Per-collection entropy configuration is required and must be
    configured (and frozen where promised) before sale start. There is no
    coordinator-level global default provider: a global default is an
    implicit dependency and changes the meaning of "unconfigured."
24. OQ-E4 — No instant entropy provider ships at genesis. The
    `IStreamInstantEntropyProvider` interface is Permanent and frozen, so
    an instant provider can be added later as a reviewed Replaceable
    module if a collection needs one (same cheap-extension contrast as
    decision 17).
25. OQ-EP1 — Stale-result signal: `fulfillEntropy` returns a pinned
    outcome code instead of reverting on benign rejection, so provider
    callbacks (including VRF callbacks that must not revert) receive a
    machine-readable verdict through
    `fulfillEntropy(bytes32 requestKey, bytes32 rawRandomness) returns
    (uint8 outcome)`.

    Errata (ADR 0011 decision R12): the `EntropyFulfillmentOutcome`
    member list originally restated inline here is owned by its
    normative home, the coordinator enum block in
    [`docs/stream-entropy-coordinator.md`](../stream-entropy-coordinator.md)
    (Fulfillment Flow), which pins the numeric values. This decision
    ratified the original five members; ADR 0010 decision D8.1 appended
    `REJECTED_PROVIDER_REVOKED = 5`. Cite the home, not this record, for
    the member set.

    Hard violations (unauthorized provider, reentrancy) still revert with
    typed errors. Adapters may mark a delivered result `TERMINAL_STALE`
    only on `REJECTED_STALE_EPOCH` or `REJECTED_INACTIVE_REQUEST`, or on
    the equivalent comparison through the coordinator's request-status
    read (stored epoch/attempt no longer active). The outcome values are
    pinned in the Numeric ID Catalog as an exact mirror of the home.

## Alternatives Considered

Recorded per decision in [`docs/spec-open-questions.md`](../spec-open-questions.md)
`Resolved` entries; the significant rejected alternatives are: namespaced
token ID ranges (cosmetic-only after conformance, permanent tooling
hazards); raising the Core size ceiling (headroom is the only budget that
ages well); VRF-only genesis entropy (single-vendor dependency);
minimal-scope finality registry (registry succession and split history);
mode-inclusive assignment-hash binding (invalidates signatures without
economic cause); onchain JSON validation (gas-prohibitive, no real trust
gain); default-on protocol attributes (mutates cached marketplace state).

## Security Impact

Decisions 2, 4, and 5 add bounded Core surface that the OQ-X2 measured
proof must cover. Decision 6 increases the audited surface of the finality
registry; every scope ships with full negative/recovery tests. Decision 21
removes a single-point-of-failure randomness posture. Decision 25 converts
silent stale-fulfillment swallowing into an explicit, testable outcome
contract without making provider callbacks revert. Decision 16 removes a
future bypass vector for freeze promises. No decision weakens an existing
invariant.

## Release Impact

The specs updated by this ADR are Draft; no deployed artifact changes.
Release-tracked docs regenerate the risk register, release manifest, and
checksum bundle. Implementation alignment (allocator, module identity
renames, `phaseId >= 1` enforcement, `fulfillEntropy` outcome return,
scoped finality registry build-out, Core `contractURI()` and refresh
emitters) is repo-alignment work tracked against the conformance matrix,
not part of this docs change.

## Test Plan

Each decision maps to conformance-matrix gates: golden selector tests for
the module identity surface and `royaltyReceiverAndBps`; allocator and
identity-slot tests plus range-arithmetic absence checks; `phaseId 0`
reservation and cross-phase counter tests; full scoped-finality
write/read/recovery suites for all five scopes; dual-provider lifecycle,
epoch-rotation, and fulfillment-outcome tests; freeze/no-bypass and
explicit-lock tests; renderer compatibility-variable and refresh-range
golden tests.

## Rollout Plan

1. This ADR merges with the spec edits that remove every inline `OQ-*`
   marker and move all register entries to `Resolved`.
2. The specs then proceed to external review (`Draft` to `Review`) under
   the spec policy.
3. Implementation alignment follows the conformance matrix; deployment is
   gated on the matrix, including the OQ-X2 measured proof.

## Non-Goals

This ADR does not change deployed contracts, does not accept audit or
production-readiness claims, does not finalize deployment parameters that
the specs already delegate to measured release manifests, and does not
alter the spec-policy lifecycle rules.

## Accepted Risks

1. Shipping all five finality scopes enlarges the genesis audit surface;
   accepted deliberately for flexibility by the protocol owner.
2. Requiring a reviewed fallback entropy provider can delay deployment if
   provider reviews stall; accepted — the alternative is a single-vendor
   randomness dependency.
3. Sequential token IDs forgo human-readable collection grouping in raw
   IDs; accepted — collection identity is a mapping read, and UIs display
   `collection / serial`.
4. Core `contractURI()` and refresh emitters spend Core bytecode inside
   the 2,000-byte headroom rule; accepted subject to the measured proof.
