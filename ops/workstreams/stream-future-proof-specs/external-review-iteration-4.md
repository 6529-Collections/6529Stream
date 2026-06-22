# External Review Iteration 4

Generated: 2026-06-22 19:11:44 UTC

Packet: iteration-4 blocker audit with updated spec excerpts and origin/main contract context excerpts.

## Verdict Summary

- GLM 5.2 (`z-ai/glm-5.2`): `APPROVE`; ok=True; finish=stop; elapsed=19.9s
- Claude Opus 4.8 (`anthropic/claude-opus-4.8`): `REQUEST_CHANGES`; ok=True; finish=stop; elapsed=29.3s
- GPT-5.5 Pro (`openai/gpt-5.5-pro`): `NO_CONTENT`; ok=True; finish=length; elapsed=100.6s

## GLM 5.2

Response:
```json
{"verdict":"APPROVE","blockers":[],"non_blocking":["The spec describes a two-step prepareMintFromManager/completePreparedMintFromManager flow for token-level primary policy, but does not specify a reentrancy guard or caller binding between the two steps. An implementation could accidentally allow a different manager transaction to complete a prepared mint. This is an implementation detail to enforce, not a spec contradiction.","The entropy coordinator spec allows INSTANT mode providers to finalize synchronously inside requestEntropy after mint registration completes. While the spec states this is safe because onTokenMinted only registers, an implementation must ensure requestEntropy is not callable from within onTokenMinted's execution context (e.g., via a reentrancy path through Core). The spec implies this but does not explicitly forbid the coordinator from calling requestEntropy during onTokenMinted.","The artwork finality registry spec defines FinalityComponentExpectation with bytes32 interfaceId, but the satellite versioning section uses bytes4 moduleInterfaceId. An adapter or mapping between these is implied but not explicitly specified.","The collection metadata contract spec defines launch limits (MAX_SCRIPT_CHUNKS=256, MAX_TOTAL_SCRIPT_BYTES=1MB) that differ from the current StreamCore constants (MAX_COLLECTION_SCRIPT_CHUNKS=32, MAX_COLLECTION_SCRIPT_CHUNK_BYTES=8192). This is expected since metadata is moving out of Core, but the migration path for existing collections is not specified.","The spec references ADR 0004 for SUCCESSOR_DECLARATION governance class and ADR 0003 for escrow invariants, but these ADRs are not included in the provided excerpts. The spec is self-consistent in referencing them, but implementation readiness depends on those ADRs being complete."],"approval_conditions":["Implement Core-native ERC-2981 royaltyInfo() with bounded staticcall to resolver, capped returndata handling (64 bytes), and (address(0),0) fallback for all resolver failure modes","Implement explicit tokenCollectionMappingExists and tokenCollectionId reads before resolver staticcall, passing hasMappedCollection/mappedCollectionId per spec","Ensure burn does not clear tokenCollectionId, tokenCollectionSerial, or tokenCollectionMappingExists","Implement RoyaltyInfoProbed event and probeRoyaltyInfo diagnostic function in a satellite or Core","Deploy FLUSH_GAS_FLOOR as immutable or manifest-pinned constant","Implement streamSystemManifest() with all specified fields including mintManager, mintLedger, governance, artworkFinalityRegistry, and eventCatalogHash","Ensure onTokenMinted only registers entropy state and does not call external providers or finalize seeds","Implement two-step pointer staging with operationId, registry eligibility recheck, and emergency bypass limited to incident-revoked-to-pre-approved-compatible-target","Verify Core bytecode remains under 22,000 bytes with documented headroom after all extractions and ERC-2981 addition"]}
```

Usage:
```json
{
  "completion_tokens": 591,
  "completion_tokens_details": {
    "audio_tokens": 0,
    "image_tokens": 0,
    "reasoning_tokens": 0
  },
  "cost": 0.2210228,
  "cost_details": {
    "upstream_inference_completions_cost": 0.0026004,
    "upstream_inference_cost": 0.2210228,
    "upstream_inference_prompt_cost": 0.2184224
  },
  "is_byok": false,
  "prompt_tokens": 156016,
  "prompt_tokens_details": {
    "audio_tokens": 0,
    "cache_write_tokens": 0,
    "cached_tokens": 0,
    "video_tokens": 0
  },
  "total_tokens": 156607
}
```

## Claude Opus 4.8

Response:
```json
{"verdict":"REQUEST_CHANGES","blockers":[{"title":"INSTANT synchronous finalize reentrancy ordering not fully pinned against counter/entropy bypass","severity":"major","location":"docs/stream-entropy-coordinator.md (requestEntropy/onTokenMinted INSTANT) + docs/stream-entropy-providers.md (StreamEntropyProviderInstant request flow)","issue":"INSTANT now finalizes synchronously inside requestEntropy after mint registration, and the provider may call back the coordinator in the same transaction. The spec says the coordinator must store active request state before calling the provider and must be non-reentrant, but it does not normatively require requestEntropy to be nonReentrant nor define behavior if a safe-receiver callback earlier in the same top-level transaction (mint) triggers a request, nor whether requestEntropy can be invoked re-entrantly from within fulfillEntropy. Without an explicit reentrancy/CEI rule on requestEntropy and a single-active-request invariant keyed by tokenId, a malicious instant provider or receiver path can attempt double-finalize or status race.","required_fix":"Specify that requestEntropy is nonReentrant, sets REQUESTED state and request key before any provider call (CEI), rejects if token status is already REQUESTED/FINALIZED, and that fulfillEntropy cannot re-enter requestEntropy for the same token. State the exact transition guard for synchronous INSTANT finalize."},{"title":"royaltyInfoForToken resolver interface signature not normatively fixed across docs","severity":"major","location":"docs/revenue-splits-and-royalties.md (Core staticcall) vs docs/adr/0008 (IStreamRevenueResolver) ","issue":"Core encodes royaltyInfoForToken(address core, uint256 tokenId, uint256 salePrice, uint256 mappedCollectionId, bool hasMappedCollection) via abi.encodeWithSelector, but no doc gives the canonical IStreamRevenueResolver.royaltyInfoForToken declaration with that exact parameter order/types. ADR 0008 references the selector without defining the full signature. An implementer cannot guarantee selector agreement between Core and resolver from the specs as written; a mismatch silently yields !ok/length!=64 fallback to (0,0), suppressing royalties.","required_fix":"Publish the exact IStreamRevenueResolver interface (function name, ordered params, return tuple) in ADR 0008 and reference it from the revenue doc so Core and resolver selectors are provably identical."},{"title":"Core read interface for token->collection mapping is inconsistent between metadata view and royalty path","severity":"major","location":"docs/metadata-router-and-renderer.md (IStreamCoreMetadataView.viewColIDforTokenID/collectionSerialForToken) vs docs/mint-policy-and-accounting.md (tokenCollectionId/tokenCollectionSerial/tokenCollectionMappingExists) vs origin/main StreamCore (tokenIdsToCollectionIds)","issue":"Three different authoritative-mapping accessor names exist (tokenCollectionId / tokenIdsToCollectionIds / viewColIDforTokenID) and the metadata view lacks a mappingExists getter equivalent to tokenCollectionMappingExists. The finality dataHash and royalty path both depend on a single authoritative mapping; without one normative read surface and existence getter, satellites and Core can diverge on what 'mapped' means, especially for burned tokens where the metadata view's viewColIDforTokenID behavior post-burn is unspecified.","required_fix":"Define one canonical Core read surface for (collectionId, collectionSerial, mappingExists) consumed by royalty resolver, metadata router, and finality registry, and specify its post-burn return values to match the burn-retention rule."}],"non_blocking":["FLUSH_GAS_FLOOR immutable/manifest-pinned resolution is now consistent across revenue doc and ADR 0008.","Burn retention of tokenCollectionId/Serial/MappingExists is now consistently stated across mint, royalty, and long-term docs.","RoyaltyInfoProbed event and probe function are aligned between revenue doc and ADR 0008.","streamSystemManifest now includes mintManager, mintLedger, governance, artworkFinalityRegistry, and eventCatalogHash as required."],"approval_conditions":["Pin requestEntropy reentrancy/CEI and single-active-request invariant for synchronous INSTANT finalize.","Publish the exact IStreamRevenueResolver.royaltyInfoForToken signature and reference it from Core's staticcall path.","Define a single canonical Core token->collection read surface (including existence and post-burn semantics) used by royalty, metadata, and finality components."]}
```

Usage:
```json
{
  "completion_tokens": 1664,
  "completion_tokens_details": {
    "audio_tokens": 0,
    "image_tokens": 0,
    "reasoning_tokens": 0
  },
  "cost": 1.426085,
  "cost_details": {
    "upstream_inference_completions_cost": 0.0416,
    "upstream_inference_cost": 1.426085,
    "upstream_inference_prompt_cost": 1.384485
  },
  "is_byok": false,
  "prompt_tokens": 276897,
  "prompt_tokens_details": {
    "audio_tokens": 0,
    "cache_write_tokens": 0,
    "cached_tokens": 0,
    "video_tokens": 0
  },
  "total_tokens": 278561
}
```

## GPT-5.5 Pro

Response: [No final content returned]

Usage:
```json
{
  "completion_tokens": 6000,
  "completion_tokens_details": {
    "audio_tokens": 0,
    "image_tokens": 0,
    "reasoning_tokens": 6000
  },
  "cost": 5.7219,
  "cost_details": {
    "upstream_inference_completions_cost": 1.08,
    "upstream_inference_cost": 5.7219,
    "upstream_inference_prompt_cost": 4.6419
  },
  "is_byok": false,
  "prompt_tokens": 154730,
  "prompt_tokens_details": {
    "audio_tokens": 0,
    "cache_write_tokens": 0,
    "cached_tokens": 0,
    "video_tokens": 0
  },
  "total_tokens": 160730
}
```
