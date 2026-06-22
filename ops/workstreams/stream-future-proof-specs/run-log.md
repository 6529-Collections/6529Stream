# Run Log

## 2026-06-22

- Started cross-cutting future-proof specs workstream at user request.
- Reloaded `6529-autonomous-manager`, `openrouter`, and local
  `6529stream-solidity` guidance.
- Confirmed no repo `AGENTS.md`; thread-provided local instructions apply.
- Confirmed branch `codex/stream-future-proof-specs` and remote
  `origin=https://github.com/6529-Collections/6529Stream.git`.
- Confirmed existing local worktree has unrelated tracked/untracked changes
  that must be preserved and left unstaged unless in owned spec paths.
- Ran OpenRouter review round 1 against GPT-5.5 Pro, Opus 4.8, and GLM 5.2.
  - GPT-5.5 Pro verdict: `REQUEST_CHANGES`.
  - Opus 4.8 verdict: `REQUEST_CHANGES`.
  - GLM 5.2 returned reasoning-only output with no final answer, so it must be
    retried with a more compact packet.
  - Blocking themes from GPT/Opus: Core satellite pointer governance,
    entropy registration before receiver callbacks, fresh entropy recovery
    reroll risk, exact royalty resolver ABI and diagnostics, signed primary
    sale policy binding, authoritative token-to-collection mapping for
    token-level overrides and inherited freezes, atomic artwork finality,
    frozen renderer failure/deprecation behavior, hash canonicalization, hard
    metadata/rendering limits, staged governance protocol, token ID model,
    silent token-scope downgrade, escrow incident recovery, escrow vs wallet
    conservation, and resolver fallback diagnostics.
- Patched specs after round 1:
  - Added/expanded umbrella Core satellite pointer policy, token identity model,
    artwork finality, governance staging, compatibility matrix, module identity
    reads, and system manifest guidance.
  - Tightened payment/royalty docs and ADR 0008 for exact resolver ABI,
    `probeRoyaltyInfo`, signed primary policy hash binding, no silent
    token-scope downgrade, royalty policy modes, paginated split reads,
    append-only labels, normative event indexes, resolver-cap rollout runbook,
    and timelocked successor-wallet escrow recovery.
  - Reordered mint/entropy specs so Core identity and entropy registration
    happen before `_safeMint` receiver callbacks.
  - Added provider result-status reads and disabled fresh entropy recovery by
    default unless a complete frozen pre-mint recovery policy exists.
  - Added metadata/router and collection-metadata canonicalization, hard v1
    limits, final artwork freeze, frozen renderer failure behavior, and
    snapshot requirements.
  - Aligned `mint-policy-and-accounting.md` with the entropy-before-safe-mint
    ordering.
- Ran `codex-diff-check -- docs ops/workstreams/stream-future-proof-specs`;
  no whitespace issues reported.
- Ran OpenRouter review round 3.
  - Opus 4.8 returned `REQUEST_CHANGES` with three blockers:
    `INSTANT` entropy ordering contradicted itself, `royaltyInfo()` token
    existence/burned-token behavior was underspecified, and burned-token
    collection mapping retention needed normative Core storage language.
  - GPT-5.5 Pro and GLM 5.2 again produced reasoning-heavy outputs without a
    useful final verdict, but their visible reasoning overlapped with the same
    entropy and resolver-boundary concerns.
- Patched specs after round 3:
  - Made `onTokenMinted` registration-only and moved provider interaction to
    `requestEntropy()`.
  - Defined `INSTANT` as synchronous finalization inside `requestEntropy()` from
    provider return data, not same-mint-path finality and not callback-based
    fulfillment.
  - Added burned-token retained mapping requirements to Core token identity,
    royalty resolution, mint accounting, collection metadata, and conformance
    docs.
  - Added canonical `tokenCollectionIdentity()` with explicit
    `mappingExists`, `collectionId`, `collectionSerial`, and `burned` returns.
- Ran OpenRouter review round 4.
  - GLM 5.2 returned `APPROVE`.
  - Opus 4.8 returned `REQUEST_CHANGES` with three remaining blockers:
    `requestEntropy()` / `INSTANT` reentrancy ordering needed to be pinned,
    the royalty resolver ABI/selector needed a normative exact selector, and
    Core needed a canonical token-to-collection read surface for external
    modules.
  - GPT-5.5 Pro did not return a useful final verdict on the full packet.
- Patched specs after round 4:
  - Added non-reentrant request/fulfill state-transition rules, including
    `REQUESTED` before provider touch, single active request, and
    finalize-before-refresh ordering.
  - Pinned resolver ABI to
    `royaltyInfoForToken(address,uint256,uint256,uint256,bool)` and selector
    `0x3d5d0e9e`.
  - Propagated `tokenCollectionIdentity()` as the canonical Core identity read
    across revenue, metadata, mint, and conformance specs.
- Ran OpenRouter review round 5.
  - Opus 4.8 returned `APPROVE`; non-blocking suggestions were to harmonize
    resolver gas tables, clarify the `contractURI()` launch-manifest decision,
    keep prepared-mint text aligned with non-reentrant manager flow, and ensure
    the conformance matrix clearly gates baseline nonconformance.
  - GLM 5.2 returned `APPROVE`; non-blocking suggestions were to require
    assembly-capped resolver returndata handling, record bytecode and gas
    measurements, keep auctions non-launch-ready until bid custody is
    implemented, and add resolver-opcode purity CI.
  - GPT-5.5 Pro still failed to produce a final verdict on the full packet.
- Ran compact GPT-5.5 Pro final audit in round 6.
  - GPT-5.5 Pro returned `APPROVE`.
  - Non-blocking suggestions were golden interface tests for resolver selector,
    ERC-2981 interface reporting, burned identity retention, instant entropy
    finalization, and conformance-matrix CI.
- Patched specs after final approvals:
  - Harmonized resolver gas tables and made capped assembly returndata handling
    a launch requirement.
  - Made `FLUSH_GAS_FLOOR` immutable or manifest-pinned.
  - Added the launch release-manifest requirement for including or excluding
    global Core `contractURI()`.
  - Added golden interface tests for resolver selector, ERC-2981
    `supportsInterface`, retained burned identity, pending entropy during safe
    receiver callbacks, `INSTANT` finalization, and fulfill rejection cases.
- Ran OpenRouter review round 2 against GPT-5.5 Pro, Opus 4.8, and GLM 5.2.
  - GPT-5.5 Pro and Opus 4.8 returned mostly hidden/reasoning output, but the
    visible reasoning still flagged mint pointer coverage, mint ticket shape,
    instant-entropy ordering, and reservation lifecycle clarity.
  - GLM 5.2 returned `REQUEST_CHANGES` with blockers around
    `probeRoyaltyInfo` signature consistency, fresh-recovery policy storage,
    artwork-finality component verification and host/discovery, and
    mint-blocking entropy registration degraded-mode policy.
  - GLM non-blocking items included standalone token reservation ambiguity,
    metadata-router event overlap, successor declaration access control,
    `mintFromManager` parameter consistency, `StreamTokenMinted` custody
    ambiguity, frozen-collection burn policy, and excess payment handling for
    entropy requests.
- Patched specs after round 2:
  - Reconciled `probeRoyaltyInfo` to the five-field diagnostic shape with
    `failureReason` in umbrella, revenue spec, and ADR 0008.
  - Added frozen `FreshRecoveryPolicy` storage, deterministic policy hashing,
    configuration/freeze functions, and collection-config binding for fresh
    entropy recovery.
  - Made `StreamArtworkFinalityRegistry` the finality host, with onchain
    component expectations, component discovery, stored `componentsHash`,
    finality component reads, and per-component hash verification.
  - Declared entropy registration a hard mint prerequisite and required
    pre-approved write-capable backup or safe-mode coordinators for emergency
    pointer fallback.
  - Removed implied standalone premint reservations from v1; token-level
    revenue, royalty, metadata, entropy, and freeze rules now require minted,
    custody-held, or same-transaction allocated Core mappings.
  - Split mint recipients into `initialRecipient`/`beneficiary` at the Core
    event, mint batch, signed ticket, gate, counter resolver, and primary-sale
    authorization levels.
  - Clarified metadata-router pointer events: the shared
    `CoreSatellitePointerUpdated` event is canonical and
    `MetadataRouterUpdated` is only an optional mirror.
  - Added successor declaration ABI/access control under ADR 0004
    `SUCCESSOR_DECLARATION`.
  - Made frozen or finalized collections non-burnable by default unless a
    pre-freeze/finality policy explicitly preserves a safe burn path.
  - Aligned payable entropy providers to exact-payment / reject-excess behavior
    for v1.
- Ran `codex-diff-check -- docs ops/workstreams/stream-future-proof-specs`;
  no whitespace issues reported.
