# External Review Iteration 1

Generated: 2026-06-22T18:05:49.271694+00:00

## GPT 5.5 Pro

- Model id: openai/gpt-5.5-pro

1. Verdict: REQUEST_CHANGES.

2. Blocking issues:

1. **Core satellite pointer governance is underspecified.**
   The specs correctly move policy into satellites, but the Core pointers to the royalty resolver, metadata router, collection metadata contract, and entropy coordinator are themselves protocol-critical. A mutable pointer can redirect royalties, change artwork, or reinterpret entropy. Add a single Core-level satellite pointer policy covering registry eligibility, two-step/timelocked changes, reason hashes, incident behavior, one-way pointer freezes, old/new module identity events, and treatment of frozen collections/tokens.
   Affected: `stream-long-term-architecture.md` Registry Pattern / Governance; `revenue-splits-and-royalties.md` StreamCore / Royalties; `metadata-router-and-renderer.md` Core Contract Changes; `collection-metadata-contract.md` Core Boundary; `stream-entropy-coordinator.md` Core Contract Changes.

2. **Entropy mint/request ordering still permits external observation before entropy state is registered.**
   The entropy spec’s example calls `_safeMint` before `onTokenMinted`. Contract recipients can reenter during `onERC721Received` while token ownership exists but entropy registration/request commitment may not. Core should assign token ID, collection ID, serial, and register entropy before any external recipient callback; if necessary, use custody or a split mint/safe-check flow.
   Affected: `stream-entropy-coordinator.md` Core Contract Changes / Token Registration Flow; align with `revenue-splits-and-royalties.md` Primary-Sale Settlement.

3. **Fresh entropy recovery remains a reroll surface.**
   The specs say fresh recovery is exceptional, but the data model does not define a precommitted fallback list/order/deadline, does not prove that no raw randomness was received, and allows `maxFreshRecoveryAttempts`. For v1, fresh entropy after an accepted provider request should be disabled unless a complete pre-mint, frozen recovery policy is specified. Adapters also need a standard result-status interface so coordinator/governance cannot claim “unreceived” after partial outcomes are visible.
   Affected: `stream-entropy-coordinator.md` Retry And Failure Policy / Fresh Entropy Recovery; `stream-entropy-providers.md` Common Adapter Requirements / Coordinator Fulfillment Retry / Multi-Source Mixer.

4. **Royalty resolver ABI and Core resolver pointer semantics are not precise enough.**
   The specs require capped staticcall behavior, but they do not define the exact resolver selector, whether Core passes collection ID/existence status or the resolver calls Core, how premint/burned/unmapped tokens are represented in calldata, or how the resolver pointer itself is staged/frozen. This can produce wrong receivers or gas-fragile marketplace reads.
   Affected: `revenue-splits-and-royalties.md` Royalties / StreamCore / Revenue Resolver; `adr/0008-revenue-splits-and-royalty-resolver.md` Royalty Resolution.

5. **Primary-sale revenue class and expected policy are not bound to sale authorization.**
   The sale context/events include revenue facts, but the signed drop/auction authorization model is not required to bind `revenueClass`, and there is no optional expected assignment/profile/template hash. A mutable assignment could change primary-sale economics between signing and settlement. At minimum, signed sale authority must bind the revenue class and make settlement-time mutability explicit; preferably it can bind an expected assignment hash or policy version.
   Affected: `revenue-splits-and-royalties.md` Primary Sales / Open-Ended Collections And Revenue Epochs; `adr/0008...` Primary-Sale Settlement.

6. **Inherited freeze enforcement is ambiguous for token-level assignments before authoritative collection mapping.**
   The specs say counters update the collection ancestor “when known.” That is insufficient for economics and metadata freezes. Token-level revenue, royalty, metadata, and entropy overrides must require an authoritative minted or reserved token-to-collection mapping, or they can escape collection inherited freezes.
   Affected: `stream-long-term-architecture.md` Assignment Hierarchy / Freeze Model; `revenue-splits-and-royalties.md` Assignment Semantics; `metadata-router-and-renderer.md` Metadata Router Responsibilities / Freeze Policy.

7. **There is no atomic final-artwork freeze across metadata, renderer, storage, and entropy.**
   The umbrella states that final artwork freeze should freeze renderer choice, script/dependency/media manifests, and entropy policy, but the companion specs do not define a single enforceable cross-module freeze manifest or ordering. This creates metadata mutability confusion and preservation risk. Define a collection finalization action or manifest that binds Core supply facts, collection metadata state, router config, renderer identity/code/manifest, script/dependency/media manifests, entropy config, finalized/pending entropy policy, and allowed post-freeze preservation exceptions.
   Affected: `stream-long-term-architecture.md` Freeze Model / Metadata And Artwork Boundary; `metadata-router-and-renderer.md` Freeze Policy; `collection-metadata-contract.md` Lock Model / Snapshots; `stream-entropy-coordinator.md` Collection Configuration.

8. **Metadata failure and renderer deprecation behavior is not safe enough for frozen history.**
   `tokenURI()` forwarding to a mutable router can permanently break metadata if the router, renderer, or collection metadata contract is incident-revoked or deprecated. The specs need a predeclared failure model: frozen collections must keep serving through their frozen renderer or a hash-bound snapshot/legacy route, and incident revocation must freeze or route only according to published recovery rules, not silently swap artwork.
   Affected: `metadata-router-and-renderer.md` Core Contract Changes / Renderer Responsibilities / Security Considerations; `stream-long-term-architecture.md` Registry Pattern / Failure And Recovery.

9. **Durable hash and canonicalization decisions remain open where they are launch-critical.**
   Hash algorithm, JSON/CBOR canonicalization, manifest canonicalization, raw JSON fragment validation, and omit/null semantics cannot remain open for final artwork, snapshots, schema commitments, and freeze manifests. Without these, future clients cannot reliably verify what was frozen.
   Affected: `metadata-router-and-renderer.md` Open Decisions; `collection-metadata-contract.md` Validation / Schema And Longevity / Snapshots And Revision History; `stream-long-term-architecture.md` Hash And Manifest Discipline.

10. **Metadata storage and rendering limits are not normative enough for launchability.**
   The collection metadata spec proposes large typed structs, custom fields, attestations, preservation records, views, snapshots, and script chunks, but does not set v1 hard maxima for string bytes, custom field bytes, chunk counts, batch sizes, enumerable key growth, or renderer output/RPC envelopes. This can become bytecode/gas infeasible or make `tokenURI()` unreliable.
   Affected: `collection-metadata-contract.md` Mutation API / Read API / Validation / Implementation Phases; `metadata-router-and-renderer.md` Bytecode Impact / Required Tests.

11. **Governance staging is asserted but not specified as an implementable protocol.**
   The specs require timelock or two-step staging for economic defaults, renderer registries, entropy providers, global freezes, and resolver replacement, but do not define operation IDs, delays, cancellation, emergency bypass limits, role-admin hierarchy, or how `StreamAdmins` evolves. This is a blocking ambiguity for economic loss and irreversible governance mistakes.
   Affected: `stream-long-term-architecture.md` Governance And Operations; `revenue-splits-and-royalties.md` Assignment Semantics / Implementation Requirements; `adr/0008...` Governance; metadata and entropy admin sections.

3. Non-blocking improvements:

1. `docs/stream-long-term-architecture.md` → **Satellite Versioning**: add recommended `moduleInterfaceId()`, `implementationCodeHash()`, `deploymentManifestHash()`, and explicit manifest hash algorithm fields.

2. `docs/revenue-splits-and-royalties.md` → **Split Profile Model / Split Wallet**: require paginated reads for entries and unique accounts, e.g. `entryCount`, `entryAt`, `uniqueAccountCount`, `uniqueAccountAt`, to make wallets self-indexable without relying only on events.

3. `docs/revenue-splits


## Opus 4.8

- Model id: anthropic/claude-opus-4.8-fast

# 6529Stream Pre-Launch Design Review

## 1. Verdict

**REQUEST_CHANGES**

The architecture is strong, coherent, and unusually disciplined for a 50-year target. The boundary thesis (small permanent Core, versioned satellites, pull accounting, no-reroll entropy, open vocabularies) is correct and largely well-specified. However, several specification-level ambiguities could cause economic loss, stuck funds, or metadata-finality confusion at launch and must be resolved before implementation.

---

## 2. Blocking issues

1. **Core `royaltyInfo()` token→collection mapping vs. namespaced ID codec is unresolved, and the two specs assume different Core storage models.** The revenue spec says collection-scope royalty resolution requires "a stored token-to-collection mapping plus an explicit existence bit," and that Core "must not infer a collection receiver for unmapped tokens unless a later ADR defines an exact token ID codec." But `origin/main` Core derives collection membership from the namespaced `_COLLECTION_TOKEN_RANGE` formula, while the collection-metadata spec recommends abandoning namespaced IDs for global IDs + explicit mappings. The royalty read path's correctness (and its gas/O(1) claim) depends entirely on which model wins. This is blocking because an unmapped or wrongly-mapped token silently falls back to default or zero royalty — a permanent, per-token economic divergence. **Resolve the token-ID model (namespaced vs. global+mapping) before implementation and make the royalty existence-bit semantics normative against that decision.**

2. **Primary settlement orders "resolve assignment / revert on missing" before mint, but token-level overrides require the token ID to exist first — the spec permits a circular/ambiguous ordering.** Rules state token-level fixed-price overrides are available "only when token ID can be reserved or predicted before any external callback," otherwise resolution is "collection/default for that transaction." This silent downgrade from token-scope to collection-scope is an economic-policy substitution that is not evented as a downgrade. A configured token-level split could be silently bypassed at settlement, sending funds to a different recipient set than governance intended. **Require either (a) deterministic token-ID reservation before resolution so token overrides always apply, or (b) an explicit revert when a token-level override exists but the token ID is not yet known. Silent downgrade must be prohibited.**

3. **Escrow can be created against an undeployed deterministic wallet, but `flushEscrow` is the only (reverting) path and incident-revocation freezes owed funds with only a "later accepted recovery spec" as the exit.** The spec repeatedly defers the recovery/reroute mechanism for incident-revoked runtime code hashes to "a future accepted escrow recovery or successor-wallet reroute path." For a launch system this leaves a concrete, reachable state in which real owed ETH is permanently frozen with no specified recovery primitive. "We will spec recovery later" is not acceptable for a fund-custody state that exists at launch. **The recovery/reroute mechanism for incident-revoked escrow must be specified (even if conservative and timelocked) before launch, or incident-revocation must be defined to never apply to already-created escrow credits.**

4. **Materialized-template profile identity excludes `saleId`/`tokenId`, so two concurrent sales resolving to the same concrete recipient set share one wallet — but pull-accounting conservation across overlapping sales into a shared wallet is asserted, not proven, and "release-before-sync" + cumulative-from-balance accounting can mis-attribute across sales.** The wallet computes entitlements from `observedReceived = currentBalance + totalAccountReleased` per asset, profile-global. This is correct for a single immutable profile, but the spec also says identical concrete profiles from the *same* template dedupe to one wallet. That is fine. The risk is the interaction with escrow: an escrow credit is keyed `(revenueClass, profileId, wallet, asset)` and `totalOwed` is summed, but the wallet's own accounting is balance-derived and does not know about escrow. If escrowed funds and directly-deposited funds for the same wallet are both in flight, the conservation invariant `sum(released)+sum(releasable) <= externalReceived` holds only if `externalReceived` includes escrowed-but-not-yet-flushed funds correctly. The spec's harness defines `externalReceived` from deposits/transfers/forced ETH but escrowed funds are *not yet in the wallet*. **The conservation invariant and its `externalReceived` definition must explicitly account for the escrow-pending vs. wallet-resident boundary so there is no window where a recipient can over- or under-release relative to true owed.** As written this is a latent accounting ambiguity that could produce loss.

5. **`royaltyInfo()` fallback-to-zero on resolver failure is correct for marketplace safety, but combined with "marketplaces may cache" and "royaltyBps=0 returns (address(0),0)," there is no on-chain distinction between intentional zero royalty and resolver-incident zero royalty.** Monitoring is explicitly off-chain only because the function is `view`. For a 50-year contract this means a resolver outage during a high-volume sale window silently produces zero-royalty disclosure that marketplaces may cache durably. This is an economic-loss/incident vector that the spec acknowledges but does not gate. **Add a non-view on-chain diagnostic probe (satellite) requirement to the launch gate, and require the resolver to be deployed, configured, and frozen-or-timelocked before any public sale, so the incident surface is bounded.** Marking blocking because the spec treats this as routine monitoring rather than a launch-gating economic risk.

6. **Metadata "final artwork" freeze coupling is described but not made enforceable across the satellite boundary.** The architecture says freezing collection metadata "should also freeze renderer choice, script manifest, dependency manifest, media manifests, and entropy policy if those facts define the final artwork." But these live in *different* contracts (router, collection metadata, entropy coordinator) with independent lock models, and the only cross-contract trigger specified is "Core collection freeze freezes metadata for that collection." There is no specified mechanism ensuring entropy policy and renderer choice are actually frozen when artwork is declared final. A collector could be shown "frozen" artwork whose entropy provider epoch or renderer is still mutable. **Specify a single authoritative "artwork finality" freeze that atomically (or verifiably-jointly) locks renderer assignment, script/dependency/media manifests, and entropy config, with a read that proves all components are frozen. Per-contract independent freezes are insufficient for the product promise of permanence.**

---

## 3. Non-blocking improvements

1. **Event indexed-field budget conflicts are noted but not resolved per-event.** `docs/revenue-splits-and-royalties.md` "Events" and ADR 0008 "Events" both acknowledge the 3-indexed-field limit but leave several events (e.g. `RevenueAssignmentSet` with `revenueClass`, `scope`, `scopeId` already consuming all three) without a declared canonical indexed set. Specify the exact indexed fields per event in one normative table so indexers are deterministic.

2. **`maxRoyaltyBps` recommended at 1000 but cap-change requires full resolver redeploy.** This is sound, but document in ADR 0008 §Governance the migration runbook for a cap change (assignment re-pointing, Core resolver pointer update, marketplace re-cache) so it is not discovered during an incident.

3. **`syncAsset` first-call-at-zero initialization semantics interact subtly with "unknown ERC-20s sent before first observation are unsupported for historical guarantees."** Clarify in `docs/revenue-splits-and-royalties.md` §Payment Accounting whether a first `syncAsset` *after* a pre-sync direct transfer establishes the full balance as the baseline (and thus releasable) or only forward-looking. The current wording is contradictory between "can only account from first observed balance" and "computes from cumulative balance."

4. **Entropy `INSTANT` mode during mint is permitted with caveats but the reentrancy/uptime exception is under-specified.** In `docs/stream-entropy-coordinator.md` §Token Registration Flow rule 5, tighten to: instant providers must finalize in a separate transaction OR prove no external call during `onTokenMinted`. The current "may finalize immediately only if ... does not create reentrancy or provider-uptime risk" is a judgment call that should be a hard rule before launch.

5. **`contractURI()` global-vs-collection split has an event ambiguity.** In `docs/metadata-router-and-renderer.md` §Events and `docs/collection-metadata-contract.md` §Contract URI, the rule "collection-scoped updates trigger Core `ContractURIUpdated()` only when they affect global metadata" requires the router/Core to *know* whether a collection write affected global output. Specify how global contract metadata is sourced (dedicated default vs. derived) so this trigger is mechanical, not heuristic.

6. **Open-ended collection royalty snapshot policy is optional but its absence has a silent economic consequence.** In `docs/revenue-splits-and-royalties.md` §Open-Ended Collections rule 4, make it a launch decision recorded per-collection (snapshot-at-mint vs. live-collection-follow) and event it, rather than leaving it implicit. Collectors should be able to read which policy applies to their token.

7. **`StreamLabelRegistry` replaceability vs. historical label resolution.** Document in ADR 0008 §Labels that replacing the label registry must not orphan historical `labelId` meanings; recommend an append-only or supersession model mirroring the schema registry.

8. **Burned-token royalty mapping retention vs. metadata `_requireMinted` revert is inconsistent across specs.** Core `tokenURI` reverts for burned tokens, but `royaltyInfo()` retains the last mapping for burned tokens. Document this intentional asymmetry explicitly in both `docs/metadata-router-and-renderer.md` and `docs/revenue-splits-and-royalties.md` so it is not read as a bug.

9. **Recommended pre-launch order lists metadata/entropy extraction before revenue, but the bytecode gate that justifies ERC-2981 inclusion depends on those extractions.** State explicitly in `docs/stream-long-term-architecture.md` §Release Gates that the Core bytecode gate is re-run *after each* extraction, not only at the end, to avoid discovering infeasibility late.

---

## 4. Missing future-proofing dimensions

1. **No specified Core upgrade/replacement story for the satellite pointers themselves.** Every satellite is replaceable, but the *pointers* in Core (metadataRouter, entropyCoordinator, resolver) are admin-set with one-way freeze hooks "where product promises require them." There is no spec for what happens if Core itself must be retired (chain migration, EIP-170 successor, L2 move). For 50 years, specify a Core-level "successor declaration" event/read so off-chain consumers can follow identity across a Core replacement, even if no on-chain migration occurs.

2. **No canonical, machine-readable manifest of "which satellite addresses are authoritative right now."** Observability lists "active module addresses" but there is no single on-chain registry binding Core → {resolver, router, renderer, collection-metadata, entropy} with versions and freeze states in one call. A 50-year archivist needs one deterministic entrypoint. Add a `StreamSystemManifest` read (or Core aggregate view).

3. **Hash-algorithm agility is assumed (keccak/SHA/BLAKE3 appear in preservation), but durable identity hashes (profileId, requestKey, seed) are hardwired to keccak256.** That is fine for protocol identity, but document explicitly that protocol-identity hashes are intentionally keccak-fixed-forever while content/preservation hashes are algorithm-tagged. Otherwise a future engineer may wrongly "upgrade" identity hashing and break determinism.

4. **No specified behavior for ERC-2981 / ERC-165 interface-ID drift.** If a successor royalty standard emerges, the spec's "add a satellite" answer doesn't cover the case where the *Core* interface advertisement must change. Document that Core's `supportsInterface` set is part of the permanent surface and a new royalty standard is adopted via a new Core deployment + successor declaration, not a satellite.

5. **Governance key-compromise recovery for one-way freezes is absent.** "Freezes are one-way" plus "admin key compromise" as a listed failure class creates a scenario where a compromised freeze-admin permanently freezes economics/artwork maliciously. Specify a guardian/timelock veto window on freeze actions (especially `freezeAllRevenue` and artwork-finality freeze) so a single compromised key cannot irreversibly damage the system instantly.

6. **No preservation guarantee that inline on-chain scripts/chunks remain readable under future RPC/gas limits.** The specs warn tooling about size but do not require a fixity/snapshot record for the *on-chain* payload itself. Add a requirement that frozen on-chain collections publish a snapshot manifest hash covering the assembled script bytes, so the artwork is reconstructable even if `tokenURI` becomes too gas-heavy to call.

7. **Cross-satellite version-compatibility matrix is unspecified.** A renderer expects a `renderContextVersion`; the entropy coordinator emits a `seed`; the collection metadata declares `rendererCompatibility`. There is no normative rule preventing assignment of a renderer whose context version is incompatible with a collection's declared compatibility. Specify a compatibility check at assignment time.

---

## 5. Implementation/audit risks (need tests or bytecode/gas proof)

- **Core bytecode gate is the central existential risk.** ERC-2981 + ERC721Enumerable + resolver read path + token→collection storage must fit under EIP-170 with headroom. Require measured bytecode after *each* extraction, not a single end measurement. The `3.8KB`/`3.6KB`/`1KB` scratch numbers must be re-measured against the actual commit baseline.
- **`royaltyInfo()` assembly staticcall with capped 64-byte returndata, gas-limit immutable, and behavior just-below/just-above the gas threshold.** Needs differential fuzzing including a malicious resolver returning huge returndata, exactly-63/64/65 bytes, and out-of-gas at parent.
- **Split-wallet conservation invariant under interleaved deposits, forced ETH, escrow flush, passive royalties, and alternate-recipient release.** Property-test with the external-ground-truth harness across all four receipt sources concurrently, including escrow-pending windows (see Blocking #4).
- **CREATE2 determinism + idempotent permissionless `deployWallet` + wrong-code collision path.** Test distinct custom errors for unknown-profile vs. address-collision, and forced-ETH-before-deploy attribution.
- **Inherited-freeze O(1) descendant counters.** Fuzz set/clear/freeze sequences to prove counters never desync from actual descendant state, including the "freeze descendants atomically in same action" path.
- **No-reroll entropy lifecycle.** Test that delivery-retry never changes requestKey/epoch/attempt, fresh-recovery is incident-only, stale/wrong-epoch callbacks never finalize, and token→request binding survives fulfillment/stale/burn.
- **ERC-20 balance-decrease guard vs. fee-on-transfer/rebasing.** Test that unsupported tokens revert rather than under-release, and that one asset's unsupported state never blocks ETH or other assets.
- **Metadata `tokenURI` gas/RPC envelope for max-size inline scripts.** Prove the assembled output either renders or fails predictably at the 65,536-byte cap.
- **Artwork-finality cross-contract freeze (Blocking #6).** Test that a single finality action provably locks renderer + manifests + entropy together.

---

## 6. Comfort statement

After the six blocking issues are resolved — specifically (1) deciding and normatively documenting the token-ID model underpinning royalty resolution, (2) prohibiting silent token→collection scope downgrade at settlement, (3) specifying a concrete launch-time recovery primitive for incident-frozen escrow, (4) closing the escrow-pending vs. wallet-resident conservation gap, (5) gating resolver readiness/finality before public sale and adding an on-chain diagnostic probe, and (6) specifying an atomic, verifiable artwork-finality freeze across satellites — I would be comfortable using these specs as the basis for implementation.

The non-blocking items and missing future-proofing dimensions should be folded in during implementation but do not need to gate the start of work. The overall design philosophy is sound and I would endorse building on it once the fund-safety and metadata-finality ambiguities above are made normative rather than deferred.


## GLM 5.2

- Model id: z-ai/glm-5.2

[Reasoning-only response; no final content returned. Visible reasoning was not recorded as the review verdict.]
