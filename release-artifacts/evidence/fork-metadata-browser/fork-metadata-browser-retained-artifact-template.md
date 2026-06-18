# Fork/Testnet Metadata Browser Retained Artifact

## Evidence Status

- Requirement ID: `fork_testnet_metadata_browser_evidence`
- Evidence type: `fork_testnet_metadata_browser_evidence`
- Review status: `reviewed`
- Readiness claim: `blocked`
- Environment: `fork`
- Chain ID: `1`

## Source And Fork/Testnet Reference

- Repository: `https://github.com/6529-Collections/6529Stream`
- Git commit: `2fb29578413541ecda5fe2732dad21ed06093366`
- CI run or operator transcript: `local mainnet-fork metadata browser capture on 2026-06-18; PR latest-head CI required before merge`
- Fork/testnet block or reference: `fork block 25344439 / 0x8cd898e49e50cfcda9b4e0ca2ccba33043a2a8c4d23df486479acffb1130af2b`
- Network and deployment version: `fork-mainnet-6529stream-v0.1.0-001-metadata-browser-capture`
- Contract addresses: `DependencyRegistry=0x0040f056e64e8c21d97d6f28a850a1c636ac361f, MetadataRehearsalRandomizer=0xe3fb8dbbac8a84a97b6ebf9de19819c48b35efc9, StreamContractMetadata=0x9a79881f8b168dbc02b2e720898031e3e78a0ffd, StreamCore=0x03695c275fcfa9f6c95ad370edf9eaa7e480d902, StreamDrops=0x1ec75e6f8d9dea73746285c49cdd091fd9733aa2`
- Token IDs: `10000000000`
- Collection IDs: `1`

## Required Retained Artifacts

- Browser summary JSON: `release-artifacts/evidence/fork-metadata-browser/browser-summary.json`
- Generated tokenURI or digest: `release-artifacts/evidence/fork-metadata-browser/token-uri.txt`
- Browser transcript or screenshot: `release-artifacts/evidence/fork-metadata-browser/browser-transcript.md`
- Release manifest/checksum digests: `release-artifacts/latest/release-manifest.json and release-artifacts/latest/SHA256SUMS regenerated in this PR`

## Browser Results

- Metadata fetched from deployed contracts: `yes`
- Browser sandbox executed: `yes`
- Unexpected outbound requests blocked: `yes`
- Console and page errors absent: `yes`
- Animation bootstrap verified: `yes`
- Parent frame isolation verified: `yes`
- Token and collection IDs retained: `yes`

## Review

- Operator: `Codex autonomous implementer`
- Reviewer: `Codex autonomous maintainer second-pass review for branch codex/fork-metadata-browser-reviewed-evidence`
- Review decision: `reviewed`

## Redaction

- No secrets retained: `yes`
- Private RPC URLs removed: `yes`
- Private keys removed: `yes`
- API keys removed: `yes`
- Unreleased drop payloads removed: `yes`

## Validation Commands

```sh
python scripts/test_generate_fork_metadata_browser_evidence_draft.py
python scripts/test_fork_metadata_browser_evidence.py
python scripts/check_fork_metadata_browser_evidence.py
python scripts/generate_non_local_release_evidence.py --template release-artifacts/evidence/public-beta-templates/fork-testnet-metadata-browser-evidence-template.json --retained-artifact release-artifacts/evidence/fork-metadata-browser/fork-metadata-browser-retained-artifact-template.md --output release-artifacts/evidence/fork-metadata-browser/fork-metadata-browser-evidence.json --environment fork --chain-id 1 --block-or-reference "fork block 25344439 / 0x8cd898e49e50cfcda9b4e0ca2ccba33043a2a8c4d23df486479acffb1130af2b" --command-or-source-system "local mainnet-fork metadata browser capture on 2026-06-18; PR latest-head CI required before merge" --owner "Codex autonomous implementer" --reviewer "Codex autonomous maintainer second-pass review for branch codex/fork-metadata-browser-reviewed-evidence"  --review-status reviewed --source-git-commit 2fb29578413541ecda5fe2732dad21ed06093366 --source-ci-run "local mainnet-fork metadata browser capture on 2026-06-18; PR latest-head CI required before merge"
python scripts/check_non_local_release_evidence.py
python scripts/check_public_beta_evidence.py
python scripts/generate_release_manifest.py --check
python scripts/generate_release_checksums.py --check
```

## Operator Notes

- Generated from retained metadata-browser capture outputs for issue #218.
- This reviewed file is completion evidence only when the shared public-beta evidence manifest links the reviewed retained evidence.
- This generator requires an explicit deployed-contract assertion; do not use local-only capture outputs for public-beta readiness claims.
