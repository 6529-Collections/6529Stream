# Fork/Testnet Metadata Browser Retained Artifact

> Template only. This file is not completion evidence.

## Evidence Status

- Requirement ID: `fork_testnet_metadata_browser_evidence`
- Evidence type: `fork_testnet_metadata_browser_evidence`
- Review status: `template`
- Readiness claim: `blocked`
- Environment: `fork`
- Chain ID: `1`

## Source And Fork/Testnet Reference

- Repository: `https://github.com/6529-Collections/6529Stream`
- Git commit: `TBD`
- CI run or operator transcript: `TBD`
- Fork/testnet block or reference: `TBD`
- Network and deployment version: `TBD`
- Contract addresses: `TBD`
- Token IDs: `TBD`
- Collection IDs: `TBD`

## Required Retained Artifacts

- Browser summary JSON: `TBD`
- Generated tokenURI or digest: `TBD`
- Browser transcript or screenshot: `TBD`
- Release manifest/checksum digests: `TBD`

## Browser Results

- Metadata fetched from deployed contracts: `TBD`
- Browser sandbox executed: `TBD`
- Unexpected outbound requests blocked: `TBD`
- Console and page errors absent: `TBD`
- Animation bootstrap verified: `TBD`
- Parent frame isolation verified: `TBD`
- Token and collection IDs retained: `TBD`

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
python scripts/test_fork_metadata_browser_evidence.py
python scripts/check_fork_metadata_browser_evidence.py
python scripts/generate_non_local_release_evidence.py --template release-artifacts/evidence/public-beta-templates/fork-testnet-metadata-browser-evidence-template.json --retained-artifact release-artifacts/evidence/fork-metadata-browser/fork-metadata-browser-retained-artifact-template.md --output release-artifacts/evidence/fork-metadata-browser/fork-metadata-browser-evidence.json --environment fork --chain-id 1 --block-or-reference "<fork/testnet block, token ID, collection ID, or browser transcript reference>" --command-or-source-system "<metadata browser transcript or CI job>" --owner "<operator>" --reviewer "<reviewer>" --source-git-commit "<release commit>" --source-ci-run "<ci run>"
python scripts/check_non_local_release_evidence.py
python scripts/check_public_beta_evidence.py
python scripts/generate_release_manifest.py --check
python scripts/generate_release_checksums.py --check
```

## Operator Notes

- Replace every `TBD` field before requesting review.
- Keep #530 open until reviewed retained evidence is linked from the shared
  public-beta evidence manifest row for fork/testnet metadata browser evidence.
- This artifact is the public-beta fork/testnet version of metadata browser
  proof. It should use metadata fetched from deployed fork or testnet contracts,
  not only local fixtures or static tokenURI output.
- Do not retain private RPC URLs, private keys, API keys, signing material,
  unreleased drop payloads, or unredacted operator logs in this repository.
- Replace private RPC or provider URLs with `<redacted>` before review; the
  checker fails closed on provider/API-token-shaped URLs.
