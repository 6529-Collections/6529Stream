# Fork/Testnet Randomizer Operations Retained Artifact

> Template only. This file is not completion evidence.

## Evidence Status

- Requirement ID: `fork_testnet_randomizer_operations_evidence`
- Evidence type: `fork_testnet_randomizer_operations_evidence`
- Review status: `template`
- Readiness claim: `blocked`
- Environment: `fork`
- Chain ID: `1`

## Fork/Testnet Deployment Context

- Repository: `https://github.com/6529-Collections/6529Stream`
- Git commit: `TBD`
- CI run or operator transcript: `TBD`
- Fork/testnet block or reference: `TBD`
- Network and deployment version: `TBD`

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

- Deployment manifest: `TBD`
- Address book: `TBD`
- Randomizer operations JSON: `TBD`
- Provider dashboard or export: `TBD`
- Explorer or fork transaction bundle: `TBD`
- Post-state request views: `TBD`
- Release manifest/checksum digests: `TBD`

## Review

- Operator: `TBD`
- Reviewer: `TBD`
- Review decision: `template`

## Redaction

- No secrets retained: `TBD`
- Private RPC URLs removed: `TBD`
- Private keys removed: `TBD`
- API keys removed: `TBD`
- Provider dashboard secrets removed: `TBD`
- Signer-service secrets removed: `TBD`
- Unreleased drop payloads removed: `TBD`

## Validation Commands

```sh
python scripts/test_fork_randomizer_operations_evidence.py
python scripts/check_fork_randomizer_operations_evidence.py
python scripts/check_randomizer_operations.py
python scripts/generate_non_local_release_evidence.py --template release-artifacts/evidence/public-beta-templates/fork-testnet-randomizer-operations-evidence-template.json --retained-artifact release-artifacts/evidence/fork-randomizer-operations/fork-randomizer-operations-retained-artifact-template.md --output release-artifacts/evidence/fork-randomizer-operations/fork-randomizer-operations-evidence.json --environment fork --chain-id 1 --block-or-reference "<fork/testnet block, provider epoch, request-health reference, or operations transcript>" --command-or-source-system "<provider export, explorer source, operations JSON, or reviewer source>" --owner "<operator>" --reviewer "<reviewer>" --source-git-commit "<release commit>" --source-ci-run "<ci run>"
python scripts/check_non_local_release_evidence.py
python scripts/check_public_beta_evidence.py
python scripts/generate_release_manifest.py --check
python scripts/generate_release_checksums.py --check
```

## Operator Notes

- Replace every `TBD` field before requesting review.
- Keep #220 open until reviewed retained evidence is linked from the shared
  public-beta evidence manifest row for fork/testnet randomizer operations.
- This artifact is the public-beta fork/testnet version of randomizer
  operations proof. It should use provider, funding, callback, reserve,
  request-health, lifecycle-control, and monitoring evidence from deployed fork
  or testnet contracts, not only local fixtures.
- The referenced randomizer operations JSON should also pass
  `python scripts/check_randomizer_operations.py` against retained fork/testnet
  deployment manifests, address books, provider funding evidence, request
  health evidence, lifecycle control evidence, and redaction policy.
- Do not commit private keys, private RPC URLs, provider API keys, signer
  credentials, private provider dashboard exports, unreleased drop payloads, or
  unredacted operator logs in this repository.
- Replace private RPC or provider URLs with `<redacted>` or a documented
  `REDACTED_*` token before review; the checker fails closed on
  provider/API-token-shaped URLs.
