# Fork/Testnet Marketplace And Indexer Query Transcript

## Scope

This transcript retains the reviewed fork/testnet marketplace and indexer
evidence package for issue #423 and requirement
`fork_testnet_marketplace_indexer_evidence`.

Public OpenSea, Reservoir, Blur, and Manifold systems do not index local Anvil
fork deployments. This transcript therefore uses equivalent collector/indexer
tooling evidence from committed fork artifacts, integration docs, event-topic
catalogs, and focused Foundry replay tests. It is fork/testnet evidence, not
live marketplace proof and not release readiness proof.

## Source References

| Source | Hash |
| --- | --- |
| `release-artifacts/evidence/fork-metadata-browser/browser-summary.json` | `sha256:499a0d489ca98a1b680d664a81159686f6cf50561e4b7a007f7eea1bf5c6e040` |
| `release-artifacts/evidence/fork-metadata-browser/token-uri.txt` | `sha256:012fb045321c07f79d98e57dd15c0126912e5dd25bdf8836033336fc07c60c5f` |
| `release-artifacts/evidence/fork-metadata-browser/browser-transcript.md` | `sha256:e890afb15afc48c740401894477183901a821d386af5211ae558be97e3c70487` |
| `release-artifacts/evidence/fork-metadata-browser/fork-metadata-browser-evidence.json` | `sha256:1b74ef25cb3bf52a7dcc4bd91afee3ce559b3e044b0bfb0ca73eaeed286d6fb3` |
| `deployments/examples/fork-mainnet-6529stream-v0.1.0-001-broadcast.json` | `sha256:9e6f9b71f1f78d8dc48c79288135f32eb56f5c9580a1fb423dc10786eaab8cde` |
| `deployments/address-books/fork-mainnet-6529stream-v0.1.0-001-broadcast.json` | `sha256:9f6c5c4d88f3786fd571411ee858dc175ddd68b281c2ad2a851288f95e77276d` |
| `release-artifacts/latest/event-topic-catalog.json` | `sha256:6c5ceb13e21bf9c43239f9bd802d5f7f76424519e1a3777a1c6eabe065e63907` |

## Environment

- Repository: `https://github.com/6529-Collections/6529Stream`
- Source commit: `e99b87e7f18ae1554b4fffa0bf812ec99df5de2c`
- Referenced fork capture commit: `c992105512b56d6619cfbf1684583f018a303bb1`
- Environment: `fork`
- Chain ID: `1`
- Fork block: `25344872`
- Fork block hash: `0x7a9a84994a33d6fca15111b924faae8e1c21d29bcc7e4102d6cd44f5b82420d4`
- Token ID: `10000000000`
- Collection ID: `1`

## Contract Metadata Result

- `StreamContractMetadata` was retained in the metadata-browser fork capture at
  `0x00ea87e5acca4e9921b64bbb488fa5017a986301`.
- `StreamContractMetadata.t.sol` proves `contractURI()` reads,
  `contractURIHash()` reads, exact URI byte hashing, `ContractURIUpdated`
  emission, unsafe URI rejection, and metadata-mutation pause handling.
- `release-artifacts/latest/event-topic-catalog.json` includes
  `ContractURIUpdated` and the ERC-4906 `MetadataUpdate` and
  `BatchMetadataUpdate` event surfaces expected by collector tools.

## Token Metadata And Animation Result

- `browser-summary.json` retained a fork token result for token
  `10000000000`, collection `1`, with deployed-contract metadata fetch,
  dependency loading, draw-function detection, parent-frame isolation, and no
  console, page, or unexpected-request errors.
- `token-uri.txt` retained the generated tokenURI data URI. Its decoded JSON
  contains the fork/testnet rehearsal description, a `Fork/Testnet` attribute,
  an image reference, and an `animation_url` data URI.
- `browser-transcript.md` retained the sandbox execution transcript proving the
  browser path executed the animation bootstrap without unexpected outbound
  fetches.

## ERC-4906 And Cache Invalidation Result

- `StreamMetadataEvents.t.sol` proves `supportsInterface(0x49064906)`,
  `MetadataUpdate` on randomness fulfillment and token metadata mutation, and
  `BatchMetadataUpdate` on collection-level metadata mutation.
- The same test proves mint-only and burn paths do not emit misleading
  ERC-4906 refresh events when JSON metadata is not expected to change.
- `docs/integrations/metadata-rendering.md` and
  `docs/integrations/events-and-indexing.md` document cache invalidation,
  state refresh, and indexer replay expectations.

## Royalty Display Result

- `StreamRoyalty.t.sol` proves ERC-2981 support, `royaltyInfo()` receiver and
  amount behavior, zero-sale behavior, and checked overflow behavior.
- `docs/royalty-policy.md` retains the marketplace-facing boundary: ERC-2981
  exposes royalty display information; it does not enforce secondary-sale
  payment.
- No production-readiness claim depends on marketplaces honoring royalties.

## Transfer Listing Sale And Replay Result

- `StreamEventReconstructability.t.sol` proves fixed-price drop logs can
  reconstruct mint transfer, drop authorization, minter range, poster credit,
  protocol credit, curator reserve credit, total owed, token ownership, and
  consumed-drop state.
- `StreamEventReconstructability.t.sol` also proves an auction path can
  reconstruct drop consumption, bridge mint, auction registration, custody
  confirmation, active status, outbid credit, highest bidder, settlement,
  proceeds credits, claim amount, owner transfer, and authoritative state
  reads.
- `docs/integrations/examples/typescript-event-decoding-and-indexer-ingestion.md`
  retains TypeScript-oriented event decoding and ingestion guidance for
  equivalent collector/indexer tooling.

## Stale Failed Frozen Burned States

- `StreamMetadataGolden.t.sol` proves final, pending, stale, and failed
  metadata-state tokenURI fixtures.
- `StreamMetadataFreeze.t.sol` proves freeze manifests, final supply handling,
  frozen metadata write rejection, pending-token freeze rejection, and burned
  pending-token freeze handling.
- `StreamCoreBurn.t.sol` proves burn events, retained audit state, tokenURI
  unavailability after burn, and post-burn randomness recording without
  misleading metadata refresh.

## Platform Review Notes

- OpenSea-compatible fields reviewed: contract metadata, token metadata,
  animation URL, ERC-2981 royalty display, ERC-4906 refresh events, ERC-721
  transfers, and sale-path event surfaces.
- Reservoir-compatible fields reviewed: event replay, ownership, mint,
  transfer, royalty display, and cache invalidation surfaces.
- Blur-compatible fields reviewed: token metadata, ownership transfer, royalty
  display boundary, and sale-path event surfaces.
- Manifold-compatible fields reviewed: metadata rendering, animation
  bootstrap, contract metadata, token refresh, and collector display surfaces.
- Equivalent collector/indexer tooling reviewed the retained fork artifacts and
  tests because public marketplaces do not ingest local fork deployments.

## Redaction

The retained transcript contains no signing material, credentialed endpoints,
marketplace account credentials, indexer credentials, private customer data, or
unreleased drop payloads.

## Validation Commands

```sh
python scripts/test_marketplace_indexer_evidence.py
python scripts/check_marketplace_indexer_evidence.py
python scripts/check_public_beta_evidence.py
python scripts/check_non_local_release_evidence.py
forge test --match-path test/StreamContractMetadata.t.sol --match-path test/StreamMetadataEvents.t.sol --match-path test/StreamRoyalty.t.sol --match-path test/StreamMetadataGolden.t.sol --match-path test/StreamMetadataFreeze.t.sol --match-path test/StreamCoreBurn.t.sol --match-path test/StreamEventReconstructability.t.sol
```
