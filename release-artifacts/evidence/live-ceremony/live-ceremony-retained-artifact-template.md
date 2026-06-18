# Live Ceremony Retained Artifact

> Template only. This file is not completion evidence.

## Evidence Status

- Requirement ID: `live_ceremony_evidence`
- Review status: `template`
- Readiness claim: `blocked`
- Environment: `live`
- Chain ID: `1`

## Live Deployment Context

- Repository: `https://github.com/6529-Collections/6529Stream`
- Release commit: `TBD`
- Deployment version: `TBD`
- Live block or reference: `TBD`

## Participants And Governance

- Deployer: `TBD`
- Admin Safe or multisig: `TBD`
- Pause guardian: `TBD`
- Emergency recipient: `TBD`
- Drop signer: `TBD`
- Signer manager: `TBD`

## Ceremony Transactions

- Ownership transfer transaction: `TBD`
- Role grant and revoke transactions: `TBD`
- Signer setup transactions: `TBD`
- Metadata and freeze ceremony: `TBD`
- Auction ceremony: `TBD`
- Emergency controls ceremony: `TBD`

## Dry Runs And Monitoring

- Dry-run mint evidence: `TBD`
- Dry-run auction evidence: `TBD`
- Monitoring handoff: `TBD`

## Required Retained Artifacts

- Live deployment manifest: `TBD`
- Live address book: `TBD`
- Safe or multisig export: `TBD`
- Explorer transaction bundle: `TBD`
- Post-state views: `TBD`
- Release manifest/checksum digests: `TBD`

## Review

- Operator: `TBD`
- Reviewer: `TBD`
- Review decision: `template`

## Redaction

- No secrets retained: `TBD`
- Private RPC URLs removed: `TBD`
- Private keys removed: `TBD`
- Signer-service secrets removed: `TBD`
- Unreleased drop payloads removed: `TBD`

## Validation Commands

```sh
python scripts/test_live_ceremony_evidence.py
python scripts/check_live_ceremony_evidence.py
python scripts/generate_non_local_release_evidence.py --template release-artifacts/evidence/production-release-templates/live-ceremony-evidence-template.json --retained-artifact release-artifacts/evidence/live-ceremony/live-ceremony-retained-artifact-template.md --output release-artifacts/evidence/live-ceremony/live-ceremony-evidence.json --environment live --chain-id 1 --block-or-reference "<mainnet block, ceremony transcript, or deployment version>" --command-or-source-system "<safe export, explorer source, or reviewer source>" --owner "<operator>" --reviewer "<reviewer>" --source-git-commit "<release commit>" --source-ci-run "<release CI run>"
python scripts/check_non_local_release_evidence.py
python scripts/check_public_beta_evidence.py
python scripts/generate_release_manifest.py --check
python scripts/generate_release_checksums.py --check
```

## Operator Notes

- Replace every `TBD` field before requesting review.
- Keep issue #228 open until reviewed retained evidence is linked from the
  shared production-release evidence manifest.
- Do not commit private keys, private RPC URLs, signer-service credentials,
  raw unreleased drop payloads, or private Safe session material.
- For pending-review or reviewed evidence, ceremony transcript fields and
  required retained artifact fields must be repo-relative retained files.
  Absolute paths, `..` escapes, Windows backslashes, ambiguous whitespace in
  paths, placeholders, missing files, stale hashes, duplicate hashes,
  provider/API-token-shaped URLs, credentialed URLs, bearer tokens, bare
  64-hex strings, symlinked files, and non-UTF-8 files fail validation.
- Retained file references may append one declared digest as
  `path/to/file sha256:<64 lowercase hex>` or
  `path/to/file / sha256:<64 lowercase hex>`. Normalize `sha256sum`-style
  retained digest output to the explicit `sha256:<hex>` form before review.
