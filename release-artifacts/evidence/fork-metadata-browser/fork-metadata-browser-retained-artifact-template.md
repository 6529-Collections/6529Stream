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
- Git commit: `c992105512b56d6619cfbf1684583f018a303bb1`
- CI run or operator transcript: `mainnet-fork metadata browser capture on 2026-06-18 from committed source c992105512b56d6619cfbf1684583f018a303bb1; retained browser transcript validates execution; PR CI validates artifacts`
- Fork/testnet block or reference: `fork block 25344872 / 0x7a9a84994a33d6fca15111b924faae8e1c21d29bcc7e4102d6cd44f5b82420d4`
- Network and deployment version: `fork-mainnet-6529stream-v0.1.0-001-metadata-browser-capture`
- Contract addresses: `DependencyRegistry=0x74ff318d8c72a9343d465ef1a8725f4fe20b6015, MetadataRehearsalRandomizer=0x743679aa2bd7a994bb8b4ccb36eb9a28480b66f7, StreamContractMetadata=0x00ea87e5acca4e9921b64bbb488fa5017a986301, StreamCore=0xb428b2fee79734fc66ccffba969e18f8ff7edd7d, StreamDrops=0x9e3b3fd0017753ceb467036cf605a94660aae126`
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
python scripts/generate_non_local_release_evidence.py --template release-artifacts/evidence/public-beta-templates/fork-testnet-metadata-browser-evidence-template.json --retained-artifact release-artifacts/evidence/fork-metadata-browser/fork-metadata-browser-retained-artifact-template.md --output release-artifacts/evidence/fork-metadata-browser/fork-metadata-browser-evidence.json --environment fork --chain-id 1 --block-or-reference "fork block 25344872 / 0x7a9a84994a33d6fca15111b924faae8e1c21d29bcc7e4102d6cd44f5b82420d4" --command-or-source-system "mainnet-fork metadata browser capture on 2026-06-18 from committed source c992105512b56d6619cfbf1684583f018a303bb1; retained browser transcript validates execution; PR CI validates artifacts" --owner "Codex autonomous implementer" --reviewer "Codex autonomous maintainer second-pass review for branch codex/fork-metadata-browser-reviewed-evidence" --review-status reviewed --source-git-commit c992105512b56d6619cfbf1684583f018a303bb1 --source-ci-run "mainnet-fork metadata browser capture on 2026-06-18 from committed source c992105512b56d6619cfbf1684583f018a303bb1; retained browser transcript validates execution; PR CI validates artifacts"
python scripts/check_non_local_release_evidence.py
python scripts/check_public_beta_evidence.py
python scripts/generate_release_manifest.py --check
python scripts/generate_release_checksums.py --check
```

## Operator Notes

- Generated from retained metadata-browser capture outputs for issue #218.
- This reviewed file is completion evidence only when the shared public-beta evidence manifest links the reviewed retained evidence.
- This generator requires an explicit deployed-contract assertion; do not use local-only capture outputs for public-beta readiness claims.
