# Marketplace And Indexer Retained Artifact

> Template only. This file is not completion evidence.

## Evidence Status

- Requirement ID: `live_marketplace_indexer_evidence`
- Review status: `template`
- Readiness claim: `blocked`
- Environment: `live`
- Chain ID: `1`

## Source And Contract References

- Repository: `https://github.com/6529-Collections/6529Stream`
- Git commit: `TBD`
- Release manifest/checksum digests: `TBD`
- Deployment manifest: `TBD`
- Address book: `TBD`
- Contract addresses: `TBD`
- Token IDs: `TBD`
- Collection IDs: `TBD`
- Marketplace/indexer tools: `OpenSea, Reservoir, Blur, Manifold, and equivalent collector/indexer tooling`
- Command or source system: `TBD`

## Coverage

- Contract metadata discovery: `TBD`
- ContractURI read: `TBD`
- ContractURIHash read: `TBD`
- ContractURIUpdated event observed: `TBD`
- Token metadata refresh: `TBD`
- ERC-4906 event observed: `TBD`
- Animation rendering: `TBD`
- Royalty display: `TBD`
- Royalty disclosure boundary: `royalty disclosure, not payment enforcement`
- Transfer/listing/sale path: `TBD`
- Event replay: `TBD`
- Cache invalidation: `TBD`
- Stale/failed/frozen/burned states: `TBD`

## Platform Results

- OpenSea: `TBD`
- Reservoir: `TBD`
- Blur: `TBD`
- Manifold: `TBD`
- Equivalent collector/indexer tooling: `TBD`
- Contract metadata: `contractURI()`, `contractURIHash()`, and `ContractURIUpdated`
- Token refresh event references: `ERC-4906`, `MetadataUpdate`, and `BatchMetadataUpdate`
- Readiness boundary: `ONE-005 retained marketplace/indexer evidence is fork/testnet/live evidence, not release readiness proof. No production-readiness claim depends on marketplaces honoring royalties.`

## Required Retained Artifacts

- Screenshot or public reference: `TBD`
- Query or transcript reference: `TBD`

## Review

- Operator: `TBD`
- Reviewer: `TBD`
- Review decision: `template`

## Redaction

- No secrets retained: `TBD`
- Private RPC URLs removed: `TBD`
- Private keys removed: `TBD`
- API keys removed: `TBD`
- Unreleased drop payloads removed: `TBD`

## Validation Commands

```sh
python scripts/test_marketplace_indexer_evidence.py
python scripts/check_marketplace_indexer_evidence.py
python scripts/generate_non_local_release_evidence.py --template release-artifacts/evidence/production-release-templates/live-marketplace-indexer-evidence-template.json --retained-artifact release-artifacts/evidence/marketplace-indexer/live-marketplace-indexer-retained-artifact-template.md --output release-artifacts/evidence/marketplace-indexer/live-marketplace-indexer-evidence.json --environment live --chain-id 1 --block-or-reference "<live block, token ID, collection ID, and deployment reference>" --command-or-source-system "<marketplace/indexer transcript>" --owner "<operator>" --reviewer "<reviewer>" --source-git-commit "<release commit>" --source-ci-run "<release CI run>"
python scripts/check_non_local_release_evidence.py
python scripts/check_public_beta_evidence.py
python scripts/generate_release_manifest.py --check
python scripts/generate_release_checksums.py --check
```

## Operator Notes

- Replace every `TBD` field before requesting review.
- Keep issue #424 open until reviewed retained live marketplace/indexer
  evidence is linked from the shared public-beta evidence manifest.
- Do not retain private RPC URLs, private keys, API keys, marketplace account
  credentials, indexer credentials, or unreleased drop payloads in this
  repository.
