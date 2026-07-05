# Metadata Renderer Research Notes

Baseline record — not a specification. This document describes as-built
or operational state; the normative target is the specification set
indexed in [`docs/spec-policy.md`](spec-policy.md), and where this
document conflicts with a specification home, the specification wins. This
document is research material, not target behavior.

This note collects external patterns worth borrowing for the Stream metadata
router, renderer, and collection metadata contracts. It is not a final spec.
It is a source-backed idea bank for deciding what to fold into the production
architecture.

## Executive Summary

Stream should copy the following ideas immediately:

1. Keep `StreamCore.tokenURI()` native, but move rendering behind a configurable
   metadata router and renderer contracts.
2. Treat the artist script, token hash, dependencies, and render context as the
   durable artwork primitive, not merely as metadata decoration.
3. Add a rich default JSON schema with conservative top-level marketplace
   fields and deeper Stream-native data under `properties.stream`.
4. Add `contractURI()` / collection-level metadata using the ERC-7572 shape.
5. Emit ERC-4906 metadata refresh events from Core when token JSON changes.
6. Support default, collection, and token renderer overrides.
7. Support renderer manifests and renderer version IDs.
8. Store script/dependency integrity hashes.
9. Support onchain, offchain, and hybrid assets.
10. Add an optional parameter system for artist-approved post-mint evolution.
11. Add explicit extension namespaces and "ignore unknown fields" rules.
12. Build validation tooling for JSON fragments, metadata URI limits, and schema
    hashes.

Stream should investigate, but not necessarily implement at launch:

1. ERC-7160-style multiple metadata URIs per token.
2. ERC-5773-style multi-asset / context-dependent assets.
3. ERC-7496-style dynamic onchain traits.
4. ERC-7280-style linked data.
5. ERC-4804 `web3://` raw JSON endpoints.
6. ERC-3668 CCIP Read for large verified offchain metadata.
7. ERC-6551 token-bound accounts for token-owned archives, editions, or
   collector additions.
8. ERC-8257-style agent-facing manifests for Stream-native tools.

## Standards And Marketplace Baseline

ERC-721's formal metadata JSON schema is intentionally tiny: `name`,
`description`, and `image`. The token URI method may point to JSON that
conforms to that schema.

OpenSea and other marketplaces also understand wider de facto fields:
`external_url`, `animation_url`, `attributes`, and `background_color`.
OpenSea explicitly supports onchain Base64 JSON data URIs and ERC-4804
`web3://` metadata URIs.

ERC-4906 standardizes metadata update events:

```solidity
event MetadataUpdate(uint256 _tokenId);
event BatchMetadataUpdate(uint256 _fromTokenId, uint256 _toTokenId);
```

ERC-7572 standardizes `contractURI()` for collection-level metadata and
`ContractURIUpdated()`. Its schema includes `name`, `symbol`, `description`,
`image`, `banner_image`, `featured_image`, `external_link`, and
`collaborators`.

Recommended Stream adoption:

1. Keep the top-level token JSON boring and broadly compatible.
2. Put Stream-specific protocol data under `properties.stream`.
3. Put media details under `properties.media`.
4. Put rights and licensing details under `properties.rights`.
5. Put script, dependency, and attestation facts under `properties.provenance`.
6. Add `contractURI()` at Core or router level, with Core-originated update
   events if possible.

Sources:

- ERC-721: <https://eips.ethereum.org/EIPS/eip-721>
- ERC-4906: <https://eips.ethereum.org/EIPS/eip-4906>
- ERC-7572: <https://eips.ethereum.org/EIPS/eip-7572>
- OpenSea metadata standards: <https://docs.opensea.io/docs/metadata-standards>

## Art Blocks Patterns To Borrow

Art Blocks is the highest-signal reference for onchain generative art. Its core
premise is that the algorithm is the artwork: the script, token hash, and
dependency data can reconstruct the work without the company or API existing.

Useful patterns:

1. Store the generative script and token hash as first-class provenance.
2. Inject deterministic token data into the script.
3. Use a stable script context. Art Blocks exposes `tokenData.hash` and
   `tokenData.tokenId`; Stream should expose a richer `window.__STREAM_TOKEN__`.
4. Keep dependency libraries durable. Art Blocks has a Dependency Registry for
   fully onchain JavaScript libraries.
5. Separate core NFT state from a generator/renderer that assembles browser HTML.
6. Support hybrid projects. Engine Flex can combine onchain code with IPFS,
   Arweave, BytecodeStorage, Dependency Registry entries, and post-mint
   parameters.
7. Support configurable post-mint parameters with explicit artist-defined
   bounds, update authority, and lock dates.
8. Support augmentation hooks that inject live onchain data into a render
   context.
9. Provide artist staging and preview tooling so the exact onchain render path
   can be tested before activation.
10. Consider an agent-facing API and docs layer; Art Blocks now exposes an MCP
    server for AI agents.

Recommended Stream adoption:

1. Add `RenderContext` as a first-class concept.
2. Add `RendererManifest` with compatible context versions.
3. Add `ScriptManifest` with `scriptHash`, chunks, optional script URI, and
   renderer compatibility.
4. Add `DependencyManifest` with dependency ID, dependency hash, dependency URI,
   and source type.
5. Add a future `StreamTokenParams` module inspired by PostParams.
6. Add render preview tools before mainnet collection activation.

Sources:

- Art Blocks protocol overview: <https://docs.artblocks.io/protocol/overview/>
- Art Blocks on-chain storage: <https://docs.artblocks.io/protocol/on-chain-storage/>
- Art Blocks PostParams: <https://docs.artblocks.io/protocol/postparams/>
- Art Blocks technical requirements: <https://help.artblocks.io/Technical-Requirements-7f9a9aaf39ea4f20b2d5b948cf08d5aa>
- Art Blocks docs / MCP server: <https://docs.artblocks.io/>

## Renderer Modularity Patterns

Several platforms converge on renderer modularity.

Highlight allows creators to point a collection to a custom metadata renderer
contract. It can optionally pass mint data to that renderer, so the renderer can
store or process a seed at mint time.

Zora's older NFT contracts used a flexible metadata renderer architecture, with
different renderers for drops and editions. Zora's current Coin metadata docs
also include a useful `content` object with MIME type and URI, which is more
indexer-friendly than relying only on `animation_url`.

Manifold's Creator model uses extensions. Extensions can own token URI logic,
minting logic, hooks, and royalty overrides while the base creator contract
preserves token provenance.

Recommended Stream adoption:

1. Keep `StreamCore` as the base provenance contract.
2. Route `tokenURI()` to a metadata router.
3. Let the router resolve default, collection, and token renderers.
4. Add optional renderer hooks for mint data, but make them explicit and
   permissioned.
5. Add a `content` object beside `animation_url` for MIME-aware indexing:

```json
{
  "animation_url": "ipfs://...",
  "content": {
    "mime": "text/html",
    "uri": "ipfs://..."
  }
}
```

Sources:

- Highlight custom renderers: <https://support.highlight.xyz/knowledge-base/for-developers/custom-metadata-renderers>
- Zora legacy renderer architecture: <https://github.com/ourzora/zora-721-contracts>
- Zora metadata format: <https://docs.zora.co/coins/contracts/metadata>
- Manifold Creator extensions: <https://docs.manifold.xyz/manifold-for-developers/smart-contracts/manifold-creator>

## Onchain Storage And Assembly Patterns

For fully or mostly onchain generative art, plain Solidity storage is not the
only option.

Useful patterns:

1. SSTORE2 / bytecode-as-storage stores large blobs in deployed bytecode and
   reads with `EXTCODECOPY`. This can be cheaper than ordinary storage for
   write-once data.
2. EthFS is an onchain file system for reusable assets such as JavaScript
   libraries, fonts, GIFs, and other files.
3. scripty.sol provides gas-aware HTML assembly and is storage-agnostic.
4. Art Blocks' Dependency Registry shows how reusable JS libraries can become
   durable shared infrastructure.
5. IPFS and Arweave remain useful for large media, but Stream should record
   hashes and source manifests so "offchain" does not mean "unverifiable."

Recommended Stream adoption:

1. Keep the first implementation simple with chunked strings if audit velocity
   matters.
2. Design `ScriptManifest` and `DependencyManifest` so they can later point to
   bytecode storage, EthFS, IPFS, Arweave, or Dependency Registry entries.
3. Store hashes for every script, dependency, and media manifest.
4. Avoid locking the system to one storage substrate.

Sources:

- scripty.sol: <https://int-art.gitbook.io/scripty.sol>
- scripty.sol GitHub: <https://github.com/intartnft/scripty.sol>
- EthFS: <https://github.com/frolic/ethfs>
- SSTORE2 overview: <https://doc.confluxnetwork.org/docs/general/build/smart-contracts/gas-optimization/sstore2/>
- ethereum.org decentralized storage: <https://ethereum.org/developers/docs/storage/>

## Frontier ERC Ideas

### ERC-7160: Multiple Metadata URIs

ERC-7160 lets each ERC-721 token have multiple metadata URIs and a pinned
primary URI. The motivation includes metadata revision history, different aspect
ratios, evolving metadata, and collaborative tokens.

Stream idea:

1. Do not implement full ERC-7160 in Core at launch.
2. Borrow the concept for the metadata router: store alternate token views and a
   pinned/default view.
3. Use it for "live", "archive", "print", "mobile", "museum", and "raw JSON"
   views.

Source: <https://eips.ethereum.org/EIPS/eip-7160>

### ERC-5773: Context-Dependent Multi-Asset NFTs

ERC-5773 lets an NFT expose multiple assets and choose outputs by context:
marketplace image, e-book PDF, game model, IoT payload, etc. It also has an
issuer/owner consent model for asset changes.

Stream idea:

1. Borrow the vocabulary of asset roles and priorities.
2. Add `properties.media.alternates`.
3. Consider a later `assetURI(tokenId, role)` view outside Core.
4. Do not overload ordinary `tokenURI()` with too many context semantics.

Source: <https://eips.ethereum.org/EIPS/eip-5773>

### ERC-7496: Dynamic Onchain Traits

ERC-7496 defines onchain dynamic traits so contracts can read and enforce trait
state, including use cases like redeemables and marketplace orders that depend
on traits.

Stream idea:

1. Separate display attributes from enforceable onchain traits.
2. If Stream adds post-mint parameters, consider making selected parameters
   queryable as onchain traits.
3. Keep art traits in JSON unless another contract needs to enforce them.

Source: <https://eips.ethereum.org/EIPS/eip-7496>

### ERC-7498: Redeemables

ERC-7498 composes redeemable campaigns with ERC-7496 dynamic traits. It is not
a metadata spec, but it is relevant if NFTs unlock physical prints, books,
events, or partner benefits.

Stream idea:

1. Add optional `properties.rights.redeemables_uri`.
2. Keep redemption state out of metadata unless it is enforceable onchain.
3. If redeemables become core to Stream, use a separate module.

Source: <https://eips.ethereum.org/EIPS/eip-7498>

### ERC-7280: Linked Data

ERC-7280 proposes a `linked_data` key for JSON-LD-like semantic metadata. This
is useful for richer institutional, museum, rights, provenance, and archival
metadata.

Stream idea:

1. Add optional `linked_data` support in renderer output.
2. Use it for museum-grade provenance and rights context.
3. Keep this optional because marketplace support is immature.

Source: <https://eips.ethereum.org/EIPS/eip-7280>

### ERC-4804: web3:// Onchain Resources

ERC-4804 maps `web3://` URLs to EVM calls and enables direct onchain web
content access. OpenSea now documents support for ERC-4804 metadata URIs.

Stream idea:

1. Keep ordinary `tokenURI()` returning marketplace-friendly JSON/data URIs.
2. Add optional `tokenJSON(uint256)` and `tokenHTML(uint256)` views so
   `web3://.../tokenJSON/123?returns=(string)` can resolve raw onchain JSON.
3. Add `properties.stream.web3_uri`.

Sources:

- ERC-4804: <https://eips.ethereum.org/EIPS/eip-4804>
- OpenSea metadata standards: <https://docs.opensea.io/docs/metadata-standards>

### ERC-3668: CCIP Read

ERC-3668 lets contracts request offchain data with an onchain verification
callback. It is useful when data is too large for L1 but can be verified by a
hash, Merkle proof, signature, or L2 state proof.

Stream idea:

1. Do not put CCIP Read in Core.
2. Consider a future renderer mode for verified offchain manifests.
3. Use it for very large metadata or L2-hosted collection state when provenance
   can be verified.

Source: <https://eips.ethereum.org/EIPS/eip-3668>

### ERC-6551: Token-Bound Accounts

ERC-6551 gives NFTs deterministic accounts that can hold assets and interact
with contracts without changing the original NFT contract.

Stream idea:

1. Add optional `properties.stream.token_bound_account`.
2. Consider token-bound accounts for collector-added archives, exhibition
   history, owned editions, or participatory works.
3. Do not make token-bound accounts part of launch metadata unless there is a
   concrete product use case.

Source: <https://eips.ethereum.org/EIPS/eip-6551>

### ERC-8257: Agent Tool Registry

ERC-8257 is a 2026 draft for onchain AI agent tools. It has useful metadata
discipline: URI plus onchain hash commitment, origin binding, creator binding,
namespaced extensions, unknown-field handling, manifest size limits, URL
normalization, and parser hardening.

Stream idea:

1. Make metadata schemas agent-readable.
2. Add `schemaURI` and `schemaHash`.
3. Namespace extensions.
4. Require consumers to ignore unknown fields.
5. Enforce size caps in tooling.
6. Consider an MCP/API layer for agents to inspect collections, render tokens,
   check mint eligibility, and build purchase transactions.

Source: <https://eips.ethereum.org/EIPS/eip-8257>

## Agent-Readable Metadata Ideas

AI agents are becoming real consumers of metadata. Art Blocks has an MCP server.
OpenSea documentation exposes agent-oriented discovery links. ERC-8257 creates
an onchain registry for agent tools.

Recommended Stream adoption:

1. Publish schemas in both human-readable Markdown and machine-readable JSON
   Schema.
2. Add `schemaURI` and `schemaHash` to collection metadata.
3. Add `properties.stream.schema`.
4. Add an `llms.txt` or equivalent docs index for Stream metadata and contract
   APIs.
5. Later, expose an MCP server or agent skill for:
   - inspect collection metadata
   - render token HTML
   - validate renderer output
   - explain provenance
   - build mint or purchase transactions

This is not a launch blocker, but it is a 50-year architecture concern.

## Security And Correctness Ideas To Copy

1. Unknown fields must be ignored by consumers and namespaced by authors.
2. Top-level extension keys should not shadow standard keys.
3. JSON fragments should be validated by tooling and ideally by contract where
   cheap enough.
4. Store hashes for offchain schemas, scripts, media manifests, and extension
   JSON.
5. Emit explicit events for config and metadata changes.
6. Set practical URI and JSON size limits in tooling.
7. Use lowercase hex and canonical JSON when hashes commit to JSON bytes.
8. Avoid injecting raw strings into JavaScript; encode the render context.
9. Treat renderers as powerful: assignment must be permissioned and freeze-aware.
10. Keep marketplace traits clean; put machine data in `properties`.

## Recommended Stream Backlog

### Add To Metadata Specs Now

1. `RendererManifest`
   - renderer address
   - renderer version
   - supported context version
   - supported modes
   - schema URI/hash
   - max JSON size hint
   - max HTML size hint

2. `ScriptManifest`
   - script hash
   - script storage mode
   - script URI
   - chunk count
   - renderer compatibility

3. `DependencyManifest`
   - dependency source type
   - dependency ID
   - dependency URI
   - dependency hash
   - dependency version string

4. `MediaManifest`
   - primary image URI/hash/MIME
   - animation URI/hash/MIME
   - alternate media
   - content object compatible with Zora's pattern

5. `properties.stream`
   - schema
   - chain ID
   - core address
   - token ID
   - collection ID
   - collection-local token number
   - token hash
   - renderer
   - renderer version
   - metadata mode
   - render state
   - script hash
   - dependency hash

### Add As Phase 2 Or 3

1. `tokenJSON(uint256)` and `tokenHTML(uint256)` raw views for ERC-4804.
2. `contractURI()` and `ContractURIUpdated()`.
3. Metadata validation scripts in CI.
4. Artist preview tooling that renders from the exact contract path.
5. Optional protocol traits toggle.

### Keep As Future Modules

1. `StreamTokenParams`, inspired by Art Blocks PostParams.
2. `StreamDynamicTraits`, inspired by ERC-7496.
3. `StreamMultiAssetView`, inspired by ERC-5773.
4. `StreamMetadataHistory`, inspired by ERC-7160.
5. Agent-facing Stream MCP/tool registry integration.

## Things Not To Copy Blindly

1. Do not implement every ERC in Core.
2. Do not make `tokenURI()` context-dependent in a way marketplaces cannot
   understand.
3. Do not dump every protocol fact into marketplace `attributes`.
4. Do not rely on a single CDN dependency without a hash and archival plan.
5. Do not make renderer contracts effectively owner-upgradeable after collection
   freeze.
6. Do not accept arbitrary JSON/HTML fragments without tooling, size caps, and
   escaping rules.
7. Do not put CCIP Read into launch unless there is a concrete verified-offchain
   data requirement.
