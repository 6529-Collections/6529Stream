# Live Deployment Manifest Retained Artifact

> Template only. This file is not completion evidence.

## Evidence Status

- Requirement ID: `live_deployment_manifest`
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
- Command or source system: `TBD`

## Required Retained Artifacts

- Broadcast manifest input: `TBD`
- Generated live deployment manifest: `TBD`
- Generated live address book: `TBD`
- Source verification inputs: `TBD`
- Release manifest/checksum digests: `TBD`

## Deployment Manifest Results

- Manifest generated from production inputs: `TBD`
- Chain ID matches live: `TBD`
- Contract addresses finalized: `TBD`
- Runtime bytecode hashes retained: `TBD`
- Constructor arguments retained: `TBD`
- Release digest references retained: `TBD`

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
python scripts/test_live_deployment_manifest_evidence.py
python scripts/check_live_deployment_manifest_evidence.py
python scripts/generate_non_local_release_evidence.py --template release-artifacts/evidence/production-release-templates/live-deployment-manifest-template.json --retained-artifact release-artifacts/evidence/live-deployment-manifest/live-deployment-manifest-retained-artifact-template.md --output release-artifacts/evidence/live-deployment-manifest/live-deployment-manifest-evidence.json --environment live --chain-id 1 --block-or-reference "<production block, deployment version, or manifest reference>" --command-or-source-system "<operator transcript or manifest generator source>" --owner "<operator>" --reviewer "<reviewer>" --source-git-commit "<release commit>" --source-ci-run "<ci run>"
python scripts/check_non_local_release_evidence.py
python scripts/check_public_beta_evidence.py
python scripts/generate_release_manifest.py --check
python scripts/generate_release_checksums.py --check
```

## Operator Notes

- Replace every `TBD` field before requesting review.
- Keep #227 open until reviewed retained evidence is linked from the shared
  production-release evidence manifest.
- The retained deployment manifest must be generated from production inputs and
  live broadcast evidence, not from a fork, local Anvil run, or template.
- Do not retain private RPC URLs, private keys, API keys, signing material,
  unreleased drop payloads, or unredacted operator logs in this repository.
- Replace private RPC or provider URLs with `<redacted>` before review; the
  checker fails closed on provider/API-token-shaped URLs.
