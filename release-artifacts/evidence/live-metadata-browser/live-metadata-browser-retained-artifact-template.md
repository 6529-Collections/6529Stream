# Live Metadata Browser Retained Artifact

> Template only. This file is not completion evidence.

## Evidence Status

- Requirement ID: `live_metadata_browser_evidence`
- Evidence type: `live_metadata_browser_evidence`
- Review status: `template`
- Readiness claim: `blocked`
- Environment: `live`
- Chain ID: `1`

## Source And Production Reference

- Repository: `https://github.com/6529-Collections/6529Stream`
- Git commit: `TBD`
- CI run or operator transcript: `TBD`
- Production block or reference: `TBD`
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

- Metadata fetched from live contracts: `TBD`
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
python scripts/test_live_metadata_browser_evidence.py
python scripts/check_live_metadata_browser_evidence.py
python scripts/generate_non_local_release_evidence.py --template release-artifacts/evidence/production-release-templates/live-metadata-browser-evidence-template.json --retained-artifact release-artifacts/evidence/live-metadata-browser/live-metadata-browser-retained-artifact-template.md --output release-artifacts/evidence/live-metadata-browser/live-metadata-browser-evidence.json --environment live --chain-id 1 --block-or-reference "<production block, token ID, collection ID, or browser transcript reference>" --command-or-source-system "<metadata browser transcript or CI job>" --owner "<operator>" --reviewer "<reviewer>" --source-git-commit "<release commit>" --source-ci-run "<ci run>"
python scripts/check_non_local_release_evidence.py
python scripts/check_public_beta_evidence.py
python scripts/generate_release_manifest.py --check
python scripts/generate_release_checksums.py --check
```

## Operator Notes

- Replace every `TBD` field before requesting review.
- Keep #473 open until reviewed retained evidence is linked from the shared
  production-release evidence manifest row for live metadata browser evidence.
- This artifact is the live production version of metadata browser proof. It
  should use metadata fetched from deployed mainnet contracts, not only local,
  fork, or fixture-generated tokenURI output.
- Do not retain private RPC URLs, private keys, API keys, signing material,
  unreleased drop payloads, or unredacted operator logs in this repository.
- Replace private RPC or provider URLs with `<redacted>` before review; the
  checker fails closed on provider/API-token-shaped URLs.
- For pending-review or reviewed evidence, `Browser summary JSON`, `Generated
  tokenURI or digest`, and `Browser transcript or screenshot` must be
  repo-relative retained files. Absolute paths, `..` escapes, Windows
  backslashes, ambiguous whitespace in paths, placeholders, and missing files
  fail validation.
- Retained file references may append one declared digest as
  `path/to/file sha256:<64 lowercase hex>` or
  `path/to/file / sha256:<64 lowercase hex>`. Stale hashes, duplicate hashes,
  trailing hash text, and bare 64-hex strings fail closed.
