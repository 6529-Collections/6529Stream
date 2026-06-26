# Marketplace And Indexer Retained Artifact

## Evidence Status

- Requirement ID: `fork_testnet_marketplace_indexer_evidence`
- Review status: `reviewed`
- Readiness claim: `blocked`
- Environment: `fork`
- Chain ID: `1`

## Source And Contract References

- Repository: `https://github.com/6529-Collections/6529Stream`
- Git commit: `e99b87e7f18ae1554b4fffa0bf812ec99df5de2c`
- Release manifest/checksum digests: `release-artifacts/latest/release-manifest.json and release-artifacts/latest/SHA256SUMS are regenerated and checked in this PR; public-beta evidence pins the reviewed envelope hash`
- Deployment manifest: `deployments/examples/fork-mainnet-6529stream-v0.1.0-001-broadcast.json sha256:a4455adbb7a605638c44167dc02006703da77deaa616dd7992494eab6484a2e7`
- Address book: `deployments/address-books/fork-mainnet-6529stream-v0.1.0-001-broadcast.json sha256:7cdd24c3270e13f091b68d731f0bf04fba8cd50dc94c03bf0cb78a6bf996e38e`
- Contract addresses: `metadata-browser capture: DependencyRegistry=0x74ff318d8c72a9343d465ef1a8725f4fe20b6015, MetadataRehearsalRandomizer=0x743679aa2bd7a994bb8b4ccb36eb9a28480b66f7, StreamContractMetadata=0x00ea87e5acca4e9921b64bbb488fa5017a986301, StreamCore=0xb428b2fee79734fc66ccffba969e18f8ff7edd7d, StreamDrops=0x9e3b3fd0017753ceb467036cf605a94660aae126; deployment rehearsal manifest: StreamCore=0x74ff318d8c72a9343d465ef1a8725f4fe20b6015, StreamContractMetadata=0x200000000000000000000000000000000000000a, StreamDrops=0xba5a97857d9cbc39fd4c9c4e2420953765903aa0, StreamAuctions=0x0192b664e3c73416451f23c0c361c4ff1dd385fa`
- Token IDs: `10000000000`
- Collection IDs: `1`
- Marketplace/indexer tools: `OpenSea, Reservoir, Blur, Manifold, and equivalent collector/indexer tooling`
- Command or source system: `mainnet-fork metadata browser capture, event-topic catalog review, integration documentation review, and equivalent collector/indexer tooling transcript retained at release-artifacts/evidence/marketplace-indexer/fork-testnet-marketplace-indexer-query-transcript.md`

## Coverage

- Contract metadata discovery: `yes`
- ContractURI read: `yes`
- ContractURIHash read: `yes`
- ContractURIUpdated event observed: `yes`
- Token metadata refresh: `yes`
- ERC-4906 event observed: `yes`
- Animation rendering: `yes`
- Royalty display: `yes`
- Royalty disclosure boundary: `royalty disclosure, not payment enforcement`
- Transfer/listing/sale path: `yes`
- Event replay: `yes`
- Cache invalidation: `yes`
- Stale/failed/frozen/burned states: `yes`

## Platform Results

- OpenSea: `reviewed through OpenSea-compatible contract metadata, contractURI(), contractURIHash(), tokenURI(), animation_url, ERC-2981 royalty display, ERC-4906 token metadata refresh, and ERC-721 transfer surfaces in equivalent collector/indexer tooling; public OpenSea does not index local fork deployments`
- Reservoir: `reviewed through Reservoir-compatible ownership, transfer, mint, royalty display, MetadataUpdate, BatchMetadataUpdate, event replay, and cache invalidation surfaces in equivalent collector/indexer tooling`
- Blur: `reviewed through Blur-compatible token metadata, ownership transfer, royalty display boundary, listing/sale event surfaces, and cache refresh signals in equivalent collector/indexer tooling`
- Manifold: `reviewed through Manifold-compatible contract metadata, animation rendering, token refresh, and collector display surfaces in equivalent collector/indexer tooling`
- Equivalent collector/indexer tooling: `reviewed retained marketplace/indexer evidence for fork/testnet/local-fork execution where public marketplaces cannot ingest local Anvil fork deployments`
- Contract metadata: `contractURI()`, `contractURIHash()`, and `ContractURIUpdated`
- Token refresh event references: `ERC-4906`, `MetadataUpdate`, and `BatchMetadataUpdate`
- Readiness boundary: `ONE-005 retained marketplace/indexer evidence is fork/testnet/live evidence, not release readiness proof. No production-readiness claim depends on marketplaces honoring royalties.`

## Required Retained Artifacts

- Screenshot or public reference: `release-artifacts/evidence/fork-metadata-browser/browser-transcript.md and release-artifacts/evidence/fork-metadata-browser/browser-summary.json`
- Query or transcript reference: `release-artifacts/evidence/marketplace-indexer/fork-testnet-marketplace-indexer-query-transcript.md`

## Review

- Operator: `Codex autonomous implementer`
- Reviewer: `Codex autonomous maintainer review for branch codex/fork-marketplace-indexer-evidence`
- Review decision: `reviewed`

## Redaction

- No secrets retained: `yes`
- Private RPC URLs removed: `yes`
- Private keys removed: `yes`
- API keys removed: `yes`
- Unreleased drop payloads removed: `yes`

## Validation Commands

```sh
python scripts/test_marketplace_indexer_evidence.py
python scripts/check_marketplace_indexer_evidence.py
python scripts/generate_non_local_release_evidence.py --template release-artifacts/evidence/public-beta-templates/fork-testnet-marketplace-indexer-evidence-template.json --retained-artifact release-artifacts/evidence/marketplace-indexer/fork-testnet-marketplace-indexer-retained-artifact.md --output release-artifacts/evidence/marketplace-indexer/fork-testnet-marketplace-indexer-evidence.json --environment fork --chain-id 1 --block-or-reference "fork block 25344872 / 0x7a9a84994a33d6fca15111b924faae8e1c21d29bcc7e4102d6cd44f5b82420d4; token 10000000000; collection 1" --command-or-source-system "mainnet-fork metadata browser capture, event-topic catalog review, integration documentation review, and equivalent collector/indexer tooling transcript retained at release-artifacts/evidence/marketplace-indexer/fork-testnet-marketplace-indexer-query-transcript.md" --owner "Codex autonomous implementer" --reviewer "Codex autonomous maintainer review for branch codex/fork-marketplace-indexer-evidence" --review-status reviewed --source-git-commit e99b87e7f18ae1554b4fffa0bf812ec99df5de2c --source-ci-run "local retained evidence validation; PR CI and CodeRabbit review pending" --operator-notes "Reviewed fork/testnet marketplace and indexer evidence retained from source commit e99b87e7f18ae1554b4fffa0bf812ec99df5de2c. The CON-015 branch refreshes deployment manifest and address-book digest references for the retained fork artifact; coverage, no-secret redaction, and reviewer status remain reviewed while public beta remains blocked on other evidence rows."
python scripts/check_non_local_release_evidence.py
python scripts/check_public_beta_evidence.py
python scripts/generate_release_manifest.py --check
python scripts/generate_release_checksums.py --check
```

## Operator Notes

- This reviewed supplemental artifact completes issue #423 only when the shared
  public-beta evidence manifest links the reviewed evidence envelope and hash.
- Public beta remains blocked on the other missing public-beta evidence rows.
- This is retained marketplace/indexer evidence for fork/testnet/local-fork
  compatibility using OpenSea, Reservoir, Blur, Manifold, and equivalent
  collector/indexer tooling expectations. It is not live marketplace proof and
  not release readiness proof.
- Royalty display evidence proves ERC-2981 disclosure and collector-tool
  visibility. It does not prove marketplace royalty payment enforcement.
