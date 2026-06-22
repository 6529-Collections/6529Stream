# External Review Iteration 2

Generated: 2026-06-22T18:30:53.882017+00:00


## GPT 5.5 Pro

- Model id: `openai/gpt-5.5-pro`

[No final content returned]
{
  "id": "gen-1782153054-JzjmEHeGZkWxarU14M81",
  "object": "chat.completion",
  "created": 1782153054,
  "model": "openai/gpt-5.5-pro-20260423",
  "provider": "OpenAI",
  "system_fingerprint": null,
  "service_tier": "default",
  "usage": {
    "prompt_tokens": 141505,
    "completion_tokens": 6000,
    "total_tokens": 147505,
    "cost": 5.32515,
    "is_byok": false,
    "prompt_tokens_details": {
      "cached_tokens": 0,
      "cache_write_tokens": 0,
      "audio_tokens": 0,
      "video_tokens": 0
    },
    "cost_details": {
      "upstream_inference_cost": 5.32515,
      "upstream_inference_prompt_cost": 4.24515,
      "upstream_inference_completions_cost": 1.08
    },
    "completion_tokens_details": {
      "reasoning_tokens": 6000,
      "image_tokens": 0,
      "audio_tokens": 0
    }
  }
}
[TRUNCATED raw choice payload]

The raw GPT `choice` payload ended mid-string in the saved capture and is intentionally not presented as valid JSON. The useful visible reasoning themes are summarized in the run log and later review iterations.

## Opus 4.8

- Model id: `anthropic/claude-opus-4.8-fast`

[No final content returned]
{
  "id": "gen-1782153221-1BYYKu8iIe4IKStubUx5",
  "object": "chat.completion",
  "created": 1782153221,
  "model": "anthropic/claude-4.8-opus-fast-20260528",
  "provider": "Anthropic",
  "system_fingerprint": null,
  "service_tier": "default",
  "usage": {
    "prompt_tokens": 250064,
    "completion_tokens": 6000,
    "total_tokens": 256064,
    "cost": 2.80064,
    "is_byok": false,
    "prompt_tokens_details": {
      "cached_tokens": 0,
      "cache_write_tokens": 0,
      "audio_tokens": 0,
      "video_tokens": 0
    },
    "cost_details": {
      "upstream_inference_cost": 2.80064,
      "upstream_inference_prompt_cost": 2.50064,
      "upstream_inference_completions_cost": 0.3
    },
    "completion_tokens_details": {
      "reasoning_tokens": 2200,
      "image_tokens": 0,
      "audio_tokens": 0
    },
    "speed": "fast"
  }
}
choice={
  "index": 0,
  "logprobs": null,
  "finish_reason": "length",
  "native_finish_reason": "max_tokens",
  "message": {
    "role": "assistant",
    "content": null,
    "refusal": null,
    "reasoning": "I'm reviewing the iteration 2 specs to see if they've addressed the blockers from iteration 1, and I need to identify any remaining gaps or contradictions that could impact launch. Let me work through the key areas systematically, starting with the Hash and Manifest Discipline section.\n\nThere's a documentation defect in the numbered list\u2014items 4 and 5 appear after an inserted paragraph about the event catalog, breaking the flow. It's a clarity issue but probably not blocking. The royalty resolver overflow handling looks solid: when the resolver reverts on overflow via staticcall, it returns (0,0) safely without cascading failures. The entropy ordering blocker appears resolved\u2014the spec now correctly sequences onTokenMinted registration before _safeMint, and the reference implementation confirms this order. However, there's a subtle architectural tension I need to examine: the spec says token identity and entropy registration must happen before _safeMint receiver callbacks and must not call providers, but INSTANT mode allows instant fulfillment, which could create a conflict depending on how that's implemented.\n\nFresh entropy recovery is resolved through providerResultStatus and frozen pre-mint policy. The descendant counter logic for inherited freeze looks thorough, and token-scope counters should work fine since the token-to-collection mapping exists at mint time. The ERC-2981 implementation in Core is custom assembly-based rather than using OpenZeppelin's ERC2981, which aligns with the spec's requirement for resolver-backed royalties. The tokenURI function correctly reverts for burned or unminted tokens, maintaining consistency with the burned-token asymmetry model.\n\nNow checking the royalty resolver gas constraints \u2014 the Core code checks if remaining gas exceeds 65k (50k resolver cap plus 15k buffer) before making the staticcall with 50k gas, which matches the spec's budget table. The resolver ABI includes mappedCollectionId and hasMappedCollection parameters that Core passes through, though the reference snippet doesn't show where these are read \u2014 that's an implementation detail. Looking at the system-level conservation equation, there's a potential issue: escrowOwed funds are held in the escrow contract itself, not in the wallet, but the conservation formula counts deposits to the wallet on the right side.\n\nThe spec addresses this as an accounting model that's internally consistent. Checking the mint-policy deferred enum modes, the spec requires launch to reject RESOLVER cap/delta, CUSTOM_RESOLVER, and nullifiers, but the gate interface can return nullifiers and CounterKeyContext supports CUSTOM_RESOLVER \u2014 the spec says this rejection happens at config time, which addresses the gap. However, there's a critical issue with the MintTicket struct: the spec defines it twice with conflicting fields. The first definition in the \"Recipient Binding\" section includes chainId, manager, ledger, and a uint256 nonce, while the \"Signed Mint Tickets\" section defines it with collectionId, a bytes32 nonce, and no chainId/manager/ledger. This is a genuine contradiction within the spec itself.\n\nThis is blocking because signed ticket replay binding is security-critical and the nonce type differs along with the domain fields. The spec does explain domain separation via authorizationId derivation including chainId, manager, and ledger, but having two conflicting authoritative struct definitions for the signed authorization makes implementation ambiguous on a security path. I'm flagging this as blocking since it must be reconciled before the spec is implementation-ready.\n\nThe event catalog interleaving in Hash And Manifest Discipline is malformed with numbered items 1,2,3 then prose then 4,5, but the cont


## GLM 5.2

- Model id: `z-ai/glm-5.2`

1. Verdict: REQUEST_CHANGES.

2. Blocking issues:
   1. **`probeRoyaltyInfo` return signature contradiction.** `stream-long-term-architecture.md` specifies a 4-field return `(bool, address, uint256, bytes32)`. `revenue-splits-and-royalties.md` specifies a 5-field return adding `bytes32 failureReason`. These must be reconciled to a single canonical signature before implementation, since the spec declares indexed/return fields normative and post-launch changes breaker-class.
   2. **Fresh entropy recovery policy storage undefined.** The spec requires a "complete recovery policy" (fallback provider list, provider order, provider epochs/config hashes, who can declare incidents, late-fulfillment acceptance, reason URI/hash) to be "configured and frozen before mint" when `maxFreshRecoveryAttempts > 0`. But `CollectionEntropyConfig` only stores `maxFreshRecoveryAttempts` — none of the other required policy fields exist in the struct or in any defined satellite storage. The spec simultaneously says fresh recovery is possible if the policy is frozen and provides no mechanism to store or verify the policy. Either define the storage/interface or explicitly forbid `maxFreshRecoveryAttempts > 0` in v1.
   3. **`finalizeCollectionArtwork` per-component hash verification mechanism underspecified.** The spec says the action "reverts unless every component reports `frozen = true` and the returned component manifest hashes match the supplied finality manifest." But `finalizeCollectionArtwork` takes only `finalityManifestHash` and `finalityManifestURI`. The contract cannot read an off-chain manifest URI on-chain, so it has no way to know the expected per-component `componentManifestHash` values to compare against. The spec also requires a post-finality read function that checks "whether all component modules still match it" — this requires storing per-component expected hashes on-chain, but no storage layout is defined. The `IStreamFinalityComponent.finalityState()` return tuple `(bool, bytes32, bytes32)` is insufficient to verify renderer code hash, render context version, script bytes hash, dependency payload hashes, or media manifest hashes that the finality manifest must bind.
   4. **`finalizeCollectionArtwork` host contract and component discovery undefined.** The spec does not specify which contract hosts this function. It must query collection metadata, metadata router, resolved renderer, dependency registry, and entropy coordinator in one transaction. Core has direct pointers to some but not all of these (renderer is resolved via the router; dependency registry location is unspecified). The spec must define the host contract and the address discovery path for each component.
   5. **`onTokenMinted` as mint-blocking external call with no defined degraded-mode path.** The spec requires Core to call `entropyCoordinator.onTokenMinted()` before `_safeMint`, making the coordinator a single point of failure for all minting. The Core Satellite Pointer Policy defines emergency bypass only for incident-revoked targets moving to a pre-approved compatible target or "safe read-only fallback" — but an entropy coordinator has no meaningful read-only fallback since it must accept writes. The spec must either (a) require a pre-approved backup coordinator as a launch gate with explicit emergency-bypass eligibility for the ENTROPY_COORDINATOR pointer family, or (b) define a try/catch degraded path where minting proceeds with a `NONE` entropy status and deferred registration, or (c) explicitly state that coordinator availability is a hard mint prerequisite and bind this as a launch gate with a documented operational runbook.

3. Non-blocking improvements:
   1. **Token reservation/premint flow referenced but undefined.** The spec says "Premint reservations count only if the reservation writes the same stored mapping and existence bit that `royaltyInfo()` reads" but defines no Core function for creating a premint reservation. For launch, custody-based mint (mint to sale contract, record revenue, transfer to buyer) appears sufficient, but the spec should either define the reservation interface or explicitly defer it.
   2. **Metadata router pointer event overlap.** `MetadataRouterUpdated(address oldRouter, address newRouter)` overlaps with the shared `CoreSatellitePointerUpdated` event. Clarify whether per-family events are supplementary convenience events or should be subsumed by the shared pointer event set.
   3. **Successor declaration access control undefined.** `StreamCoreSuccessorDeclared` event is specified but no emitting function, access control, or caller restriction is defined.
   4. **Mint gate interface undefined.** The mint policy spec references gates (Merkle, EIP-712, ERC-1271) but defines no gate interface. Needs a minimal `IStreamMintGate` interface for implementation readiness.
   5. **`mintFromManager` parameter naming inconsistency.** The mint spec calls the fourth parameter `salt`; the entropy spec calls it `mintCommitment` (`bytes32`). The mint spec types it as `uint256`. Reconcile the name and type.
   6. **`StreamTokenMinted` event `recipient` field ambiguity.** When using custody-based mint (mint to sale contract, then transfer to buyer), the event's `recipient` field would show the custody address, not the final buyer. Clarify whether `recipient` is the initial mint recipient or the intended final owner, and whether a separate `beneficiary` field is needed.
   7. **Burn behavior on frozen collections unspecified.** Current code blocks burns on frozen collections via `_requireCollectionNotFrozen`. The spec doesn't state whether this is the intended long-term policy. Clarify.
   8. **Excess ETH handling in `requestEntropy` unspecified.** The spec says "forward only the amount needed" and "refund logic must be explicit and evented" but doesn't specify whether excess is rejected or refunded, or by what mechanism.
   9. **`FLUSH_GAS_FLOOR` and direct-deposit gas limit values unspecified.** The spec requires these as named constants but doesn't recommend values. These should be measured and documented before launch.
   10. **`markEntropyRequestUnrecoverable` cross-contract gas to `providerResultStatus` unbounded.** The spec requires calling the provider adapter's `providerResultStatus` before allowing fresh recovery, but doesn't specify a gas limit for this call. A malicious or buggy adapter could consume all gas.
   11. **`contractURI()` global semantics for multi-collection Core.** The spec says `contractURI()` returns global/default Stream contract metadata, but ERC-7572 marketplaces may expect per-collection contract metadata. Document the marketplace compatibility implications.

4. Blocker-resolution audit:
   1. Core satellite pointer governance: **PASS** — Staged operations, registry eligibility, code/manifest hash checks, emergency bypass limits, one-way freeze, and frozen-scope treatment are all defined with evented lifecycle.
   2. Entropy mint ordering: **PASS** — Token identity and entropy registration happen before `_safeMint` receiver callbacks; registration must not call providers.
   3. Fresh entropy recovery: **FAIL** — Disabled-by-default and `providerResultStatus` proof are specified, but the complete recovery policy storage required when `maxFreshRecoveryAttempts > 0` is undefined in any struct or satellite.
   4. Royalty resolver ABI: **PASS** — Selector, calldata, `mappedCollectionId`/`hasMappedCollection` semantics, bounded staticcall handling, and returndata size checks are fully specified; the `probeRoyaltyInfo` contradiction is a new issue, not a failure of the original blocker.
   5. Signed primary policy binding: **PASS** — `revenueClass` and `expectedPrimaryPolicyHash` are bound with `STRICT_MATCH` default and explicit `ALLOW_CURRENT` drift mode.
   6. Inherited freeze/token identity: **PASS** — Token-level assignments require authoritative Core token-to-collection mapping; range heuristics are explicitly rejected.
   7. Atomic artwork freeze: **FAIL** — `finalizeCollectionArtwork` and `IStreamFinalityComponent` are defined, but the on-chain verification mechanism for per-component manifest hashes against the finality manifest is underspecified with no defined storage for expected hashes.
   8. Frozen renderer failure: **PASS** — Frozen collections keep frozen renderer or hash-bound snapshot/recovery route; incident revocation cannot silently swap artwork.
   9. Hash canonicalization: **PASS** — `keccak256` protocol identity hashes, RFC 8785/JCS JSON manifests, `abi.encode` rules, raw JSON fragment policy, and omit/null semantics are specified.
   10. Metadata limits: **PASS** — v1 hard maxima are defined for all relevant string, URI, script, batch, and render output dimensions.
   11. Governance staging: **PASS** — Staged operation fields, events, cancellation, emergency limits, role hierarchy, and release gates are defined.
   12. Opus-specific blockers: **PASS** — Token ID model, no silent token-scope downgrade, escrow incident recovery, wallet vs system conservation, diagnostic probe, and cross-module artwork finality are addressed.
