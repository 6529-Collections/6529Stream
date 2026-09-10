# Sepolia native demonstration

A signed native-ETH purchase minted collection 1/token 1. The real Sepolia Chainlink coordinator fulfilled its own request in a later block, the provider delivered the result, Core emitted `MetadataUpdate`, and metadata contains the finalized seed. The 90/10 split was withdrawn and the NFT transferred to the dedicated artist.

All observations are pinned to the transfer block in `anchor-block.json`. `transaction-inventory.json`, receipts, canonical block headers and complete raw ABI readbacks support the assertions. Transaction inputs remain retrievable by public hashes; no private operational checkpoint or signer material is published.

`client-config.json` contains public addresses for the TypeScript client. `token.metadata.json` is the exact decoded on-chain JSON; `token.animation.html` is the on-chain HTML example and contains executable JavaScript. The metadata is a development protocol example, not a finished artwork or collection/pointer freeze. Stream remains pre-audit and not production-ready.
