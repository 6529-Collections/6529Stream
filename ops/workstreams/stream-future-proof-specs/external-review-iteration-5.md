# External Review Iteration 5

Generated: 2026-06-22 19:20:28 UTC

Packet: final targeted blocker audit over latest changed snippets plus small origin/main context.

## Verdict Summary

- GLM 5.2 (`z-ai/glm-5.2`): `APPROVE`; ok=True; finish=stop; elapsed=8.8s
- Claude Opus 4.8 (`anthropic/claude-opus-4.8`): `APPROVE`; ok=True; finish=stop; elapsed=25.0s
- GPT-5.5 Pro (`openai/gpt-5.5-pro`): `NO_CONTENT`; ok=True; finish=length; elapsed=116.5s

## GLM 5.2

Response:
```json
```json
{"verdict":"APPROVE","blockers":[],"non_blocking":["Spec uses high-level bytes memory decode in reference shape but recommends assembly returndatacopy; implementation must use the assembly path to avoid unbounded returndata allocation.","Core bytecode size budget (EIP-170, 22,000-byte CI gate) is a launch gate but cannot be verified from specs alone; implementation must confirm after extracting metadata, randomizer, and royalty storage from Core.","Auction settlement state machine is explicitly not launch-ready; fixed-price primary sales can launch independently, but auctions require the full bid-custody contract to be implemented and tested before activation.","Resolver static-analysis gate (no CALL/DELEGATECALL/STATICCALL/CREATE/CREATE2 reachable from royaltyInfoForToken) requires a CI tool to be configured; the spec constraint is correct but tooling setup is an implementation task."],"approval_conditions":["Core runtime bytecode must be measured below 22,000 bytes after all spec-mandated extractions (OZ ERC2981 removal, metadata/script/randomizer extraction, resolver-backed royaltyInfo).","Resolver royaltyInfoForToken must pass static-analysis CI gate proving no external-call opcodes are reachable from that path.","All-cold resolver gas path must be measured and published, confirming worst-case does not silently trigger fallback-to-zero under the 50,000 gas cap.","FLUSH_GAS_FLOOR must be set to measured worst-case gas plus margin, not the rough planning range, before deployment.","Prepared-mint two-step path, if implemented, must be operation-bound within a single non-reentrant manager transaction with no durable prepared state surviving the transaction."]}
```
```

Usage:
```json
{
  "completion_tokens": 343,
  "completion_tokens_details": {
    "audio_tokens": 0,
    "image_tokens": 0,
    "reasoning_tokens": 0
  },
  "cost": 0.06226136,
  "cost_details": {
    "upstream_inference_completions_cost": 0.00105644,
    "upstream_inference_cost": 0.06226136,
    "upstream_inference_prompt_cost": 0.06120492
  },
  "is_byok": false,
  "prompt_tokens": 62454,
  "prompt_tokens_details": {
    "audio_tokens": 0,
    "cache_write_tokens": 0,
    "cached_tokens": 0,
    "video_tokens": 0
  },
  "total_tokens": 62797
}
```

## Claude Opus 4.8

Response:
```json
{"verdict":"APPROVE","blockers":[],"non_blocking":["Resolver gas budget tables in revenue-splits-and-royalties.md and ADR 0008 differ slightly in line items (the former includes a 'Core tokenCollectionId + mapping exists <= 4,500' and 'staticcall account access <= 4,000' row; the ADR omits these from its resolver-internal table but notes parent-call reads separately). Harmonize the two budget tables to avoid implementer confusion.","prepareMintFromManager registers entropy at prepare time; confirm spec text consistently treats prepare+complete as the single non-reentrant manager flow so entropy registration cannot be observed by a recipient before completePreparedMintFromManager (spec rule 4 already requires clearing the pending record before _safeMint, so this is editorial).","StreamCore.sol, StreamMinter.sol, StreamDrops.sol baseline still contain OZ ERC2981, namespaced range constants (_COLLECTION_TOKEN_RANGE), tx.origin-era drop logic, and emergencyWithdraw patterns; these are already declared non-conformant in the launch matrix and must be rewritten, but the specs correctly gate this.","contractURI() forwarding is gated on Core bytecode headroom ('if bytecode remains comfortable'); make the launch decision explicit in the release manifest."],"approval_conditions":["No spec changes required to proceed to implementation. The five prior iteration-4 blockers (entropy request/fulfill guards and instant no-callback path, canonical resolver selector 0x3d5d0e9e with no overload, shared tokenCollectionIdentity identity view including burned semantics, same-transaction-only prepared mint with no persistent reservation state, and retained prior fixes) are each resolved consistently across stream-long-term-architecture.md, revenue-splits-and-royalties.md, ADR 0008, mint-policy-and-accounting.md, metadata-router-and-renderer.md, collection-metadata-contract.md, the entropy specs, and the conformance matrix.","Implementation must satisfy the launch-conformance-matrix gates and static-analysis checks (no tx.origin, no OZ ERC2981, no abi.encodePacked authority hashes, no range heuristics, resolver purity opcode scan, FLUSH_GAS_FLOOR and resolver gas immutables)."]}
```

Usage:
```json
{
  "completion_tokens": 815,
  "completion_tokens_details": {
    "audio_tokens": 0,
    "image_tokens": 0,
    "reasoning_tokens": 0
  },
  "cost": 0.557915,
  "cost_details": {
    "upstream_inference_completions_cost": 0.020375,
    "upstream_inference_cost": 0.557915,
    "upstream_inference_prompt_cost": 0.53754
  },
  "is_byok": false,
  "prompt_tokens": 107508,
  "prompt_tokens_details": {
    "audio_tokens": 0,
    "cache_write_tokens": 0,
    "cached_tokens": 0,
    "video_tokens": 0
  },
  "total_tokens": 108323
}
```

## GPT-5.5 Pro

Response:
```json

```

Usage:
```json
{
  "completion_tokens": 8000,
  "completion_tokens_details": {
    "audio_tokens": 0,
    "image_tokens": 0,
    "reasoning_tokens": 8000
  },
  "cost": 3.28917,
  "cost_details": {
    "upstream_inference_completions_cost": 1.44,
    "upstream_inference_cost": 3.28917,
    "upstream_inference_prompt_cost": 1.84917
  },
  "is_byok": false,
  "prompt_tokens": 61639,
  "prompt_tokens_details": {
    "audio_tokens": 0,
    "cache_write_tokens": 0,
    "cached_tokens": 0,
    "video_tokens": 0
  },
  "total_tokens": 69639
}
```
