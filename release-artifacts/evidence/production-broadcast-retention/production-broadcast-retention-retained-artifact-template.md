# Production Broadcast Retention Retained Artifact

> Template only. This file is not completion evidence.

## Evidence Status

- Requirement ID: `production_broadcast_retention`
- Review status: `template`
- Readiness claim: `blocked`
- Environment: `live`
- Chain ID: `1`

## Source And Production Reference

- Repository: `https://github.com/6529-Collections/6529Stream`
- Git commit: `TBD`
- CI run or operator transcript: `TBD`
- Production block or reference: `TBD`
- Deployment transaction references: `TBD`
- Command: `forge script script/RehearseDeployment.s.sol:RehearseDeployment --rpc-url <redacted> --broadcast --verify --via-ir`

## Required Retained Artifacts

- Sanitized command transcript: `TBD`
- Sanitized Foundry broadcast: `TBD`
- Derived broadcast manifest input: `TBD`
- Generated live deployment manifest: `TBD`
- Generated live address book: `TBD`
- Release manifest/checksum digests: `TBD`

## Broadcast Results

- Broadcast completed: `TBD`
- Manifest input generated: `TBD`
- Deployment manifest generated: `TBD`
- Address book generated: `TBD`
- Transaction references retained: `TBD`

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
python scripts/test_production_broadcast_retention.py
python scripts/check_production_broadcast_retention.py
python scripts/generate_non_local_release_evidence.py --template release-artifacts/evidence/production-release-templates/production-broadcast-retention-template.json --retained-artifact release-artifacts/evidence/production-broadcast-retention/production-broadcast-retention-retained-artifact-template.md --output release-artifacts/evidence/production-broadcast-retention/production-broadcast-retention-evidence.json --environment live --chain-id 1 --block-or-reference "<production block or transaction reference>" --command-or-source-system "<operator transcript>" --owner "<operator>" --reviewer "<reviewer>" --source-git-commit "<release commit>" --source-ci-run "<ci run>"
python scripts/check_non_local_release_evidence.py
python scripts/check_public_beta_evidence.py
python scripts/generate_release_manifest.py --check
python scripts/generate_release_checksums.py --check
```

## Operator Notes

- Replace every `TBD` field before requesting review.
- Keep #226 open until reviewed retained evidence is linked from the shared
  public-beta evidence manifest.
- Do not retain private RPC URLs, private keys, API keys, signing material,
  unreleased drop payloads, or unredacted operator logs in this repository.
- Replace private RPC or provider URLs with `<redacted>` before review; the
  checker fails closed on provider/API-token-shaped URLs.
