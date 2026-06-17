# Live Randomizer Operations Retained Artifact

> Template only. This file is not completion evidence.

## Evidence Status

- Requirement ID: `live_randomizer_operations_evidence`
- Review status: `template`
- Readiness claim: `blocked`
- Environment: `live`
- Chain ID: `1`

## Live Deployment Context

- Repository: `https://github.com/6529-Collections/6529Stream`
- Release commit: `TBD`
- Deployment version: `TBD`
- Live block or reference: `TBD`

## Provider Configuration

- VRF adapter: `TBD`
- VRF coordinator: `TBD`
- VRF provider epoch: `TBD`
- VRF funding status: `TBD`
- VRF evidence: `TBD`
- arRNG adapter: `TBD`
- arRNG controller: `TBD`
- arRNG provider epoch: `TBD`
- arRNG funding status: `TBD`
- arRNG refund recipient: `TBD`
- arRNG evidence: `TBD`

## Funding And Reserve Status

- Randomizer reserve status: `TBD`
- Pending request count: `TBD`
- Stale request handling: `TBD`
- Failed request handling: `TBD`
- Retry evidence: `TBD`
- Provider migration status: `TBD`

## Request Health

- Request tracking: `TBD`
- Callback validation: `TBD`
- Pending request migration block: `TBD`

## Lifecycle Controls

- Pause policy: `TBD`
- Emergency withdrawal boundary: `TBD`
- Monitoring handoff: `TBD`

## Required Retained Artifacts

- Live deployment manifest: `TBD`
- Live address book: `TBD`
- Randomizer operations JSON: `TBD`
- Provider dashboard or export: `TBD`
- Explorer transaction bundle: `TBD`
- Release manifest/checksum digests: `TBD`

## Review

- Operator: `TBD`
- Reviewer: `TBD`
- Review decision: `template`

## Redaction

- No secrets retained: `TBD`
- Private RPC URLs removed: `TBD`
- Private keys removed: `TBD`
- Provider dashboard secrets removed: `TBD`
- Signer-service secrets removed: `TBD`
- Unreleased drop payloads removed: `TBD`

## Validation Commands

```sh
python scripts/test_live_randomizer_operations_evidence.py
python scripts/check_live_randomizer_operations_evidence.py
python scripts/check_randomizer_operations.py
python scripts/generate_non_local_release_evidence.py --template release-artifacts/evidence/production-release-templates/live-randomizer-operations-evidence-template.json --retained-artifact release-artifacts/evidence/live-randomizer-operations/live-randomizer-operations-retained-artifact-template.md --output release-artifacts/evidence/live-randomizer-operations/live-randomizer-operations-evidence.json --environment live --chain-id 1 --block-or-reference "<mainnet block, provider epoch, request-health reference, or deployment version>" --command-or-source-system "<provider export, explorer source, operations JSON, or reviewer source>" --owner "<operator>" --reviewer "<reviewer>" --source-git-commit "<release commit>" --source-ci-run "<release CI run>"
python scripts/check_non_local_release_evidence.py
python scripts/check_public_beta_evidence.py
python scripts/generate_release_manifest.py --check
python scripts/generate_release_checksums.py --check
```

## Operator Notes

- Replace every `TBD` field before requesting review.
- Keep issue #229 open until reviewed retained evidence is linked from the
  shared production-release evidence manifest.
- The referenced randomizer operations JSON should also pass
  `python scripts/check_randomizer_operations.py` against retained live
  deployment manifests, address books, provider funding evidence, request
  health evidence, lifecycle control evidence, and redaction policy.
- Do not commit private keys, private RPC URLs, provider dashboard secrets,
  signer-service credentials, raw unreleased drop payloads, or private
  provider billing session material.
