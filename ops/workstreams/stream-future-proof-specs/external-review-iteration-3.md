# External Review Iteration 3

Generated: 2026-06-22 19:01:12 UTC

Packet: compact blocker audit over current specs, with origin/main contract context excerpts. Full spec files are in `docs/`; prior review files are iterations 1 and 2 in this directory.

## Verdict Summary

- Claude Opus 4.8 (`anthropic/claude-opus-4.8`), iteration 3 compact blocker audit: `REQUEST_CHANGES`; ok=True; finish=stop; elapsed=40.0s
- GLM 5.2 (`z-ai/glm-5.2`), iteration 3 compact blocker audit: `NO_CONTENT`; ok=True; finish=length; elapsed=62.5s
- GPT-5.5 Pro (`openai/gpt-5.5-pro`), iteration 3 compact blocker audit: `NO_CONTENT`; ok=True; finish=length; elapsed=72.9s
- GLM 5.2 (`z-ai/glm-5.2`), iteration 3 retry tiny verdict audit: `NO_CONTENT`; ok=True; finish=length; elapsed=35.4s
- GPT-5.5 Pro (`openai/gpt-5.5-pro`), iteration 3 retry tiny verdict audit: `NO_CONTENT`; ok=True; finish=length; elapsed=95.8s

## Claude Opus 4.8 - iteration 3 compact blocker audit

Response:
```json
{
  "verdict": "REQUEST_CHANGES",
  "blockers": [
    {
      "title": "Same-transaction INSTANT entropy contradicts the hard pre-callback registration ordering",
      "severity": "major",
      "location": "docs/stream-entropy-coordinator.md (Token Registration Flow / onTokenMinted) and docs/stream-entropy-providers.md (StreamEntropyProviderInstant Request Flow)",
      "issue": "Core spec mandates onTokenMinted registration completes before any _safeMint receiver callback, and that onTokenMinted must not call external randomness providers from the mint path. The INSTANT same-transaction path says the coordinator must store active request state before calling the provider, and the resolution note allows same-transaction INSTANT with pure/bounded/no-callback providers. It is unspecified whether the INSTANT requestEntropy+fulfillEntropy occurs inside mintFromManager (before _safeMint) or after _safeMint. If inside, it violates 'onTokenMinted must not depend on/ call external randomness providers from the mint path'; if after _safeMint, the receiver callback observes an unfinalized seed, which other sections forbid for entropy-affecting artwork. The ordering interface between Core mint, coordinator registration, and instant provider call is contradictory.",
      "required_fix": "Specify exactly where same-transaction INSTANT fulfillment executes relative to _safeMint and mintFromManager. State normatively that (a) onTokenMinted only performs bounded REGISTERED-state writes and never calls a provider, and (b) any INSTANT provider call happens after registration but, if it must precede the receiver callback, define the precise call order inside Core/manager and prove no receiver callback can observe REGISTERED-but-unfinalized state for entropy-affecting collections. Otherwise require INSTANT to always be a separate post-registration transaction."
    },
    {
      "title": "royaltyInfo collection-scope existence gate is underspecified and internally inconsistent with stated Core storage",
      "severity": "major",
      "location": "docs/revenue-splits-and-royalties.md (royaltyInfo rules) and docs/adr/0008 (Royalty Resolution) vs docs/mint-policy-and-accounting.md (Core storage: tokenCollectionMappingExists)",
      "issue": "The royalty spec repeatedly requires 'a stored token-to-collection mapping plus an explicit existence bit or equivalent non-reverting existence check' for collection-scope resolution, but never defines which Core read the resolver/Core uses, who reads it (Core before staticcall vs resolver), or how the existence bit maps to tokenCollectionMappingExists. The resolver safety invariant forbids the resolver from making external calls, yet collection-scope resolution depends on a Core-held mapping/existence bit; the spec does not state whether Core passes hasMappedCollection/mappedCollectionId into royaltyInfoForToken (the signature includes them) or whether the resolver must independently read Core (which would be an external call). This is an ambiguous/contradictory interface that blocks safe implementation.",
      "required_fix": "Define normatively that Core reads tokenCollectionId/tokenCollectionMappingExists before the staticcall and passes mappedCollectionId and hasMappedCollection into royaltyInfoForToken, and that the resolver performs storage-and-arithmetic only with no Core re-read. Specify the exact fallback when hasMappedCollection is false (default-or-zero) and confirm the existence bit is tokenCollectionMappingExists."
    },
    {
      "title": "Burned-token collection mapping retention conflicts with the 'mapping written only for authoritative assignments' rule for royalty disclosure",
      "severity": "major",
      "location": "docs/stream-long-term-architecture.md (Token Identity Model 5) and docs/revenue-splits-and-royalties.md / docs/adr/0008 (burned tokens retain last mapping)",
      "issue": "Specs state burned tokens retain their last authoritative collection mapping for royalty disclosure, and royaltyInfo must not revert. But Core's mintFromManager-set mapping plus burn semantics are not reconciled with ERC721Enumerable burn: it is unspecified whether burning clears tokenCollectionMappingExists, and whether royaltyInfo for a burned token resolves to collection scope (existence bit set) or falls back to default. If the existence bit remains true after burn, collection-scope royalty still resolves; if cleared, it silently degrades to default/zero. The disclosure promise and the existence-gate rule are not jointly specified for the burned state.",
      "required_fix": "State explicitly whether burn preserves or clears tokenCollectionMappingExists, and define the exact royaltyInfo resolution scope (token/collection/default) for burned tokens so the 'retain mapping for disclosure' promise is consistent with the existence-gate fallback rule."
    }
  ],
  "non_blocking": [
    "streamSystemManifest lists six fixed satellite fields but pointer families include MINT_MANAGER, MINT_LEDGER, ARTWORK_FINALITY_REGISTRY; consider expanding the aggregate read or documenting why those are excluded.",
    "EntropyMode INSTANT vs the recommendation that production instant fulfillment 'should be split into a second transaction' could be tightened into a single normative rule rather than 'if awkward'.",
    "FLUSH_GAS_FLOOR is 'launch-configured' but its governance/setting authority and immutability posture are not pinned; recommend specifying who sets it and whether it is frozen at deploy.",
    "probeRoyaltyInfo is non-view/state-changing but returns values; clarify it emits an event (it cannot return to off-chain callers usefully without a tx) so monitoring tooling has a defined consumption path.",
    "Consider explicitly stating the interfaceId/selector that Core uses for royaltyInfoForToken to remove any drift between Core and resolver ABIs."
  ],
  "approval_conditions": [
    "Resolve the same-transaction INSTANT entropy ordering so registration-before-callback and no-provider-call-in-mint-path are jointly satisfiable, with explicit call order.",
    "Pin the royaltyInfo collection-scope existence-gate interface: which Core fields are read, that Core passes mappedCollectionId/hasMappedCollection into the resolver, and that the resolver makes no external Core read.",
    "Reconcile burned-token mapping retention with the existence-gate fallback by specifying whether burn preserves tokenCollectionMappingExists and the exact royaltyInfo scope for burned tokens."
  ]
}
```

Usage:
```json
{
  "completion_tokens": 2302,
  "completion_tokens_details": {
    "audio_tokens": 0,
    "image_tokens": 0,
    "reasoning_tokens": 0
  },
  "cost": 1.29133,
  "cost_details": {
    "upstream_inference_completions_cost": 0.05755,
    "upstream_inference_cost": 1.29133,
    "upstream_inference_prompt_cost": 1.23378
  },
  "is_byok": false,
  "prompt_tokens": 246756,
  "prompt_tokens_details": {
    "audio_tokens": 0,
    "cache_write_tokens": 0,
    "cached_tokens": 0,
    "video_tokens": 0
  },
  "total_tokens": 249058
}
```

## GLM 5.2 - iteration 3 compact blocker audit

Response: [No final content returned]

Usage:
```json
{
  "completion_tokens": 3502,
  "completion_tokens_details": {
    "audio_tokens": 0,
    "image_tokens": 0,
    "reasoning_tokens": 3501
  },
  "cost": 0.209733,
  "cost_details": {
    "upstream_inference_completions_cost": 0.0154088,
    "upstream_inference_cost": 0.209733,
    "upstream_inference_prompt_cost": 0.1943242
  },
  "is_byok": false,
  "prompt_tokens": 138803,
  "prompt_tokens_details": {
    "audio_tokens": 0,
    "cache_write_tokens": 0,
    "cached_tokens": 0,
    "video_tokens": 0
  },
  "total_tokens": 142305
}
```

## GPT-5.5 Pro - iteration 3 compact blocker audit

Response: [No final content returned]

Usage:
```json
{
  "completion_tokens": 3500,
  "completion_tokens_details": {
    "audio_tokens": 0,
    "image_tokens": 0,
    "reasoning_tokens": 3500
  },
  "cost": 4.75998,
  "cost_details": {
    "upstream_inference_completions_cost": 0.63,
    "upstream_inference_cost": 4.75998,
    "upstream_inference_prompt_cost": 4.12998
  },
  "is_byok": false,
  "prompt_tokens": 137666,
  "prompt_tokens_details": {
    "audio_tokens": 0,
    "cache_write_tokens": 0,
    "cached_tokens": 0,
    "video_tokens": 0
  },
  "total_tokens": 141166
}
```

## GLM 5.2 - iteration 3 retry tiny verdict audit

Response: [No final content returned]

Usage:
```json
{
  "completion_tokens": 3500,
  "completion_tokens_details": {
    "audio_tokens": 0,
    "image_tokens": 0,
    "reasoning_tokens": 4326
  },
  "cost": 0.0166628,
  "cost_details": {
    "upstream_inference_completions_cost": 0.0154,
    "upstream_inference_cost": 0.0166628,
    "upstream_inference_prompt_cost": 0.0012628
  },
  "is_byok": false,
  "prompt_tokens": 902,
  "prompt_tokens_details": {
    "audio_tokens": 0,
    "cache_write_tokens": 0,
    "cached_tokens": 0,
    "video_tokens": 0
  },
  "total_tokens": 4402
}
```

## GPT-5.5 Pro - iteration 3 retry tiny verdict audit

Response: [No final content returned]

Usage:
```json
{
  "completion_tokens": 3500,
  "completion_tokens_details": {
    "audio_tokens": 0,
    "image_tokens": 0,
    "reasoning_tokens": 3500
  },
  "cost": 0.65661,
  "cost_details": {
    "upstream_inference_completions_cost": 0.63,
    "upstream_inference_cost": 0.65661,
    "upstream_inference_prompt_cost": 0.02661
  },
  "is_byok": false,
  "prompt_tokens": 887,
  "prompt_tokens_details": {
    "audio_tokens": 0,
    "cache_write_tokens": 0,
    "cached_tokens": 0,
    "video_tokens": 0
  },
  "total_tokens": 4387
}
```
