# Public Beta Verified Addresses Retained Artifact

> Template only. This file is not completion evidence.

## Evidence Status

- Requirement ID: `public_beta_verified_addresses`
- Review status: `template`
- Readiness claim: `blocked`
- Environment: `testnet`
- Chain ID: `11155111`

## Source And Public Beta Reference

- Repository: `https://github.com/6529-Collections/6529Stream`
- Git commit: `TBD`
- CI run or operator transcript: `TBD`
- Public beta block or reference: `TBD`
- Network and deployment version: `TBD`

## Required Retained Artifacts

- Generated public-beta address book: `TBD`
- Generated public-beta deployment manifest: `TBD`
- Source verification inputs: `TBD`
- Explorer verification evidence: `TBD`
- Bytecode release proof: `TBD`
- Release manifest/checksum digests: `TBD`

## Verified Address Results

- Address book covers public-beta deployment: `TBD`
- Explorer source verification confirmed: `TBD`
- Runtime bytecode matches release proof: `TBD`
- Constructor arguments verified: `TBD`
- Linked libraries verified: `TBD`
- Common explorer/indexer links retained: `TBD`

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
python scripts/test_public_beta_verified_addresses.py
python scripts/check_public_beta_verified_addresses.py
python scripts/generate_non_local_release_evidence.py --template release-artifacts/evidence/public-beta-templates/verified-deployed-addresses-template.json --retained-artifact release-artifacts/evidence/public-beta-verified-addresses/public-beta-verified-addresses-retained-artifact-template.md --output release-artifacts/evidence/public-beta-verified-addresses/verified-deployed-addresses-evidence.json --environment testnet --chain-id 11155111 --block-or-reference "<testnet block, deployment version, or address-book reference>" --command-or-source-system "<operator transcript or explorer verification source>" --owner "<operator>" --reviewer "<reviewer>" --source-git-commit "<release commit>" --source-ci-run "<ci run>"
python scripts/check_non_local_release_evidence.py
python scripts/check_public_beta_evidence.py
python scripts/generate_release_manifest.py --check
python scripts/generate_release_checksums.py --check
```

## Operator Notes

- Replace every `TBD` field before requesting review.
- Keep #221 and #222 open until reviewed retained evidence is linked from the
  shared public-beta evidence manifest rows for verified deployed addresses and
  explorer verification status.
- Generate separate non-local evidence envelopes for each public-beta
  requirement row that reuses this reviewed retained artifact.
- Do not retain private RPC URLs, private keys, API keys, signing material,
  unreleased drop payloads, or unredacted operator logs in this repository.
- Replace private RPC or provider URLs with `<redacted>` before review; the
  checker fails closed on provider/API-token-shaped URLs.
- For pending-review or reviewed evidence, required retained artifact fields
  must be repo-relative UTF-8 files. Absolute paths, `..` escapes, Windows
  backslashes, ambiguous whitespace in paths, placeholders, missing files,
  stale hashes, duplicate hashes, provider/API-token-shaped URLs, credentialed
  URLs, bearer tokens, CLI secret flags, bare 64-hex strings, symlinked files,
  and non-UTF-8 files fail validation.
- Retained file references may append one declared digest as
  `path/to/file sha256:<64 lowercase hex>` or
  `path/to/file / sha256:<64 lowercase hex>`. Normalize `sha256sum`-style
  retained digest output, including the contents of retained release digest
  files, to the explicit `sha256:<hex>` form before review.
