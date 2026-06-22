# External Review Iteration 7 - Metadata Delta Closure

Generated: 2026-06-22 20:22:58 UTC

Packet: compact metadata/rendering/collection-metadata delta after final broad future-proof approvals.

## Verdict Summary

- GPT-5.5 Pro (`openai/gpt-5.5-pro`): NO_CONTENT; finish=length; try=2; elapsed=57.4s
- Claude Opus 4.8 (`anthropic/claude-opus-4.8`): CONTENT; finish=stop; try=1; elapsed=13.2s
- GLM 5.2 (`z-ai/glm-5.2`): NO_CONTENT; finish=stop; try=1; elapsed=88.7s

## GPT-5.5 Pro

Response:
```json

```

Usage:
```json
{
    "prompt_tokens":  1265,
    "completion_tokens":  3500,
    "total_tokens":  4765,
    "cost":  0.66795,
    "is_byok":  false,
    "prompt_tokens_details":  {
                                  "cached_tokens":  0,
                                  "cache_write_tokens":  0,
                                  "audio_tokens":  0,
                                  "video_tokens":  0
                              },
    "cost_details":  {
                         "upstream_inference_cost":  0.66795,
                         "upstream_inference_prompt_cost":  0.03795,
                         "upstream_inference_completions_cost":  0.63
                     },
    "completion_tokens_details":  {
                                      "reasoning_tokens":  3500,
                                      "image_tokens":  0,
                                      "audio_tokens":  0
                                  }
}
```

## Claude Opus 4.8

Response:
```json
{"verdict":"APPROVE","blockers":[],"non_blocking":["Document the bounded staticcall gas/returndata-copy limits explicitly in the release manifest so future Core revisions and marketplace integrators can reason about deterministic tokenURI failure behavior; pin the fallback JSON schema shape too.","Since Core intentionally omits contractURI(), publish the router/StreamCollectionMetadata discovery path (contractURIForCore/contractURIForCollection + ContractURIUpdated emitter address) prominently for marketplaces that only probe ERC721 contractURI(); some indexers will not auto-discover the off-Core path.","Register/reserve HASH_KECCAK256, CANON_RFC8785_JCS, and schema IDs in a versioned, append-only registry with reserved-range governance so 50+ year algorithm/canonicalization migrations (e.g., post-quantum digests) cannot collide with launch IDs.","HashRef.digest is variable-length bytes; specify per-algorithmId expected digest lengths and validation to avoid malformed/oversized digest storage and ambiguous off-chain verification.","Clarify STREAM_CONTEXT_V1 emission/canonicalization rules (key ordering, omitted-optional semantics, string-encoding of large numeric IDs) so metadataSnapshotHash/viewManifestHash are reproducibly recomputable by third parties over the long term.","Define explicit interaction between ERC-4906 refresh events and the freeze lattice (post-freeze no further BatchMetadataUpdate for render-affecting fields) so indexers do not re-pull frozen tokens indefinitely.","State governance/version-bump process for adding future record families and source/hash IDs (item 9) since launch is intentionally closed; ensure adding families later does not require redeploying Core identity assumptions."],"approval_conditions":["Release manifest MUST record the off-Core contractURI discovery path and the ContractURIUpdated emitter location, as required by delta item 2.","Frozen STREAM_CONTEXT_V1 key set and HashRef/CollectionRecord launch ABI must ship exactly as specified, with future keys gated to extensions/new context version and no phase-2 typed PREMIS/C2PA/IIIF structs in launch ABI."]}
```

Usage:
```json
{
    "prompt_tokens":  2393,
    "completion_tokens":  781,
    "total_tokens":  3174,
    "cost":  0.03149,
    "is_byok":  false,
    "prompt_tokens_details":  {
                                  "cached_tokens":  0,
                                  "cache_write_tokens":  0,
                                  "audio_tokens":  0,
                                  "video_tokens":  0
                              },
    "cost_details":  {
                         "upstream_inference_cost":  0.03149,
                         "upstream_inference_prompt_cost":  0.011965,
                         "upstream_inference_completions_cost":  0.019525
                     },
    "completion_tokens_details":  {
                                      "reasoning_tokens":  0,
                                      "image_tokens":  0,
                                      "audio_tokens":  0
                                  }
}
```

## GLM 5.2

Response:
```json

```

Usage:
```json
{
    "prompt_tokens":  1282,
    "completion_tokens":  1600,
    "total_tokens":  2882,
    "cost":  0.0088348,
    "is_byok":  false,
    "prompt_tokens_details":  {
                                  "cached_tokens":  0,
                                  "cache_write_tokens":  0,
                                  "audio_tokens":  0,
                                  "video_tokens":  0
                              },
    "cost_details":  {
                         "upstream_inference_cost":  0.0088348,
                         "upstream_inference_prompt_cost":  0.0017948,
                         "upstream_inference_completions_cost":  0.00704
                     },
    "completion_tokens_details":  {
                                      "reasoning_tokens":  1898,
                                      "image_tokens":  0,
                                      "audio_tokens":  0
                                  }
}
```
