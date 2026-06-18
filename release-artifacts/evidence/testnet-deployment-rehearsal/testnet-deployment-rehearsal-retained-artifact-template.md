# Testnet Deployment Rehearsal Retained Artifact

> Template only. This file is not completion evidence.

## Evidence Status

- Requirement ID: `testnet_deployment_rehearsal`
- Review status: `template`
- Readiness claim: `blocked`
- Environment: `testnet`
- Testnet name: `sepolia`
- Chain ID: `11155111`

## Source And Testnet Reference

- Repository: `https://github.com/6529-Collections/6529Stream`
- Git commit: `TBD`
- CI run or operator transcript: `TBD`
- Testnet block or reference: `TBD`
- Deployment transaction references: `TBD`
- Command: `forge script script/RehearseDeployment.s.sol:RehearseDeployment --rpc-url <redacted> --broadcast --via-ir`

## Required Retained Artifacts

- Sanitized command transcript: `TBD`
- Sanitized Foundry broadcast: `TBD`
- Generated deployment manifest: `TBD`
- Generated address book: `TBD`
- Explorer verification status: `TBD`
- Gas or invariant summary: `TBD`
- Release manifest/checksum digests: `TBD`

## Rehearsal Results

- Deployment completed: `TBD`
- Manifest generated: `TBD`
- Address book generated: `TBD`
- Transaction references retained: `TBD`
- Explorer status checked: `TBD`
- Gas or invariant summary checked: `TBD`

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
python scripts/test_testnet_deployment_rehearsal_evidence.py
python scripts/check_testnet_deployment_rehearsal_evidence.py
python scripts/generate_non_local_release_evidence.py --template release-artifacts/evidence/public-beta-templates/testnet-deployment-rehearsal-template.json --retained-artifact release-artifacts/evidence/testnet-deployment-rehearsal/testnet-deployment-rehearsal-retained-artifact-template.md --output release-artifacts/evidence/testnet-deployment-rehearsal/testnet-deployment-rehearsal-evidence.json --environment testnet --chain-id 11155111 --block-or-reference "<testnet block or transaction reference>" --command-or-source-system "<operator transcript>" --owner "<operator>" --reviewer "<reviewer>" --source-git-commit "<release commit>" --source-ci-run "<ci run>"
python scripts/check_non_local_release_evidence.py
python scripts/check_public_beta_evidence.py
python scripts/generate_release_manifest.py --check
python scripts/generate_release_checksums.py --check
```

## Operator Notes

- Replace every `TBD` field before requesting review.
- Keep #217 open until reviewed retained evidence is linked from the shared
  public-beta evidence manifest.
- Do not retain private RPC URLs, private keys, API keys, signer-service
  secrets, or unreleased drop payloads in this repository.
- Retained artifact references must be repo-relative paths. Add one optional
  `sha256:<64 lowercase hex>` digest after the path when review should prove
  the referenced artifact bytes have not drifted.
- Do not paste bare 64-hex strings; use the `sha256:` prefix for retained
  artifact digests. Bare 64-hex strings fail the no-secret scan.
