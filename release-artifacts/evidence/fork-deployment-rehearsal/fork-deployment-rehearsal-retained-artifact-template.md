# Fork Deployment Rehearsal Retained Artifact

> Template only. This file is not completion evidence.

## Evidence Status

- Requirement ID: `fork_deployment_rehearsal`
- Review status: `template`
- Readiness claim: `blocked`
- Environment: `fork`
- Chain ID: `1`

## Source And Fork Reference

- Repository: `https://github.com/6529-Collections/6529Stream`
- Git commit: `TBD`
- CI run or operator transcript: `TBD`
- Fork block number: `TBD`
- Fork block hash: `TBD`
- Command: `forge script script/RehearseDeployment.s.sol:RehearseDeployment --rpc-url <redacted> --via-ir`

## Required Retained Artifacts

- Sanitized command transcript: `TBD`
- Sanitized Foundry broadcast: `TBD`
- Generated deployment manifest: `TBD`
- Generated address book: `TBD`
- Verification status: `TBD`
- Gas or invariant summary: `TBD`
- Release manifest/checksum digests: `TBD`

## Rehearsal Results

- Deployment completed: `TBD`
- Manifest generated: `TBD`
- Address book generated: `TBD`
- Verification checked: `TBD`
- Gas or invariant summary checked: `TBD`

## Review

- Operator: `TBD`
- Reviewer: `TBD`
- Review decision: `template`

## Redaction

- No secrets retained: `TBD`
- Private RPC URLs removed: `TBD`
- Private keys removed: `TBD`
- Unreleased drop payloads removed: `TBD`

## Validation Commands

```sh
python scripts/test_fork_deployment_rehearsal_evidence.py
python scripts/check_fork_deployment_rehearsal_evidence.py
python scripts/generate_non_local_release_evidence.py --template release-artifacts/evidence/public-beta-templates/fork-deployment-rehearsal-template.json --retained-artifact release-artifacts/evidence/fork-deployment-rehearsal/fork-deployment-rehearsal-retained-artifact-template.md --output release-artifacts/evidence/fork-deployment-rehearsal/fork-deployment-rehearsal-evidence.json --environment fork --chain-id 1 --block-or-reference "<fork block>" --command-or-source-system "<operator transcript>" --owner "<operator>" --reviewer "<reviewer>" --source-git-commit "<release commit>" --source-ci-run "<ci run>"
python scripts/check_non_local_release_evidence.py
python scripts/check_public_beta_evidence.py
python scripts/generate_release_manifest.py --check
python scripts/generate_release_checksums.py --check
```

## Operator Notes

- Replace every `TBD` field before requesting review.
- Keep issue #216 open until reviewed retained evidence is linked from the
  shared public-beta evidence manifest.
