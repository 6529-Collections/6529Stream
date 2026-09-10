# Metadata and rendering

This describes current `StreamMetadataRouter` and permanent Core. It is
**pre-audit and not production-ready**. Earlier entrypoints remain in the
[legacy reference](../reference/legacy-stack/integrations/metadata-rendering.md).

## Read through Core

Use ERC-721 `core.tokenURI(tokenId)` as the client entrypoint. Core bounds router
gas and ABI return size and applies fallback behavior if the extension read fails.
A successful direct router call alone does not establish a successful Core response.
The current router allocation is 12,000,000 gas; allow 16,000,000 gas for the full
outer `eth_call` when testing maximum onchain content. A lower RPC call cap may fail
even when the contract's bounded path works.

The URI is `data:application/json;base64,...`. Decode as UTF-8 and parse JSON.
Output includes name, description, image, accepted-artist information and properties
`metadata_schema_version`, `metadata_state`, `token_id`, `collection_id`,
`collection_serial` and `hash`. IDs are not array indices. Burnt and nonexistent
tokens do not yield ordinary minted metadata.

The maximum-content regression checks router and complete Core response, full
equality and the 65,536-byte ABI bound. It exercises a 63,193-byte URI. These bounds
constrain payload design, not just transport.

## Pending and final entropy

Minting registers entropy without requiring same-transaction VRF fulfillment.
Read Core's `coordinatorAtMint` and use its
[entropy view](../../smart-contracts/interfaces/stream/entropy/IStreamEntropyView.sol).
A later coordinator pointer replacement must not reroute existing tokens to a new
seed source. A client can call the bound coordinator's `requestEntropy(tokenId)`
with its quoted fee and monitor the bound request.

`metadata_state` is `pending`, `final`, `stale` or `failed`. Finalization supplies
the immutable seed; stale/failed tracking does not authorize a reroll. Scope
requests are a separate approved-caller API and cannot overwrite token subjects.
A retained provider result may be delivered when the coordinator becomes eligible
again. Do not fabricate final seeds from request IDs or timestamps.

The local demo's controller-fed provider is not secure randomness. Configured
Sepolia uses subscription-funded Chainlink VRF; consumer registration and funding
are operational prerequisites. See [deployment](../../script/current/README.md).

## Artwork and browser isolation

Final onchain animation embeds token bytes inside the Base64 HTML `animation_url`.
JSON then declares `token_data_location: "animation_url:tokenDataBase64"` instead of
duplicating them. Other responses expose `token_data_base64`. An absent animation
while entropy is pending is expected; refresh after finalization.

Treat artwork HTML and scripts as untrusted. Render in a sandboxed frame or separate
origin with no application credentials, wallet provider, parent DOM or privileged
bridge. Never insert artwork into an authenticated app page. Use declared bytes
and seed; substituting external content is not proof of onchain rendering. Report
malformed metadata with token identity, block, raw URI and public decoded JSON.

Listen for Core `MetadataUpdate` and `BatchMetadataUpdate`, and also read entropy
state: failed notification does not undo finalization. Follow the
[event guide](events-and-indexing.md) for reorgs and cache invalidation.

Implementation: [router](../../smart-contracts/domains/metadata/StreamMetadataRouter.sol),
[renderer](../../smart-contracts/domains/metadata/StreamMetadataRenderer.sol),
[coordinator](../../smart-contracts/domains/entropy/StreamEntropyCoordinator.sol).
For planned preservation/finality guarantees use the [specification index](../spec-policy.md);
current rendering does not establish full production finality readiness.
