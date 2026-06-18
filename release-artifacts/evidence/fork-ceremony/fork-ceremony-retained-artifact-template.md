# Fork/Testnet Ceremony Retained Artifact

> Template only. This file is not completion evidence.

## Evidence Status

- Requirement ID: `fork_testnet_ceremony_evidence`
- Evidence type: `fork_testnet_ceremony_evidence`
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

- Deployment manifest: `TBD`
- Address book: `TBD`
- Safe or multisig export: `TBD`
- Explorer or fork transaction bundle: `TBD`
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
- API keys removed: `TBD`
- Signer-service secrets removed: `TBD`
- Unreleased drop payloads removed: `TBD`

## Validation Commands

```sh
python scripts/test_fork_ceremony_evidence.py
python scripts/check_fork_ceremony_evidence.py
python scripts/generate_non_local_release_evidence.py --template release-artifacts/evidence/public-beta-templates/fork-testnet-ceremony-evidence-template.json --retained-artifact release-artifacts/evidence/fork-ceremony/fork-ceremony-retained-artifact-template.md --output release-artifacts/evidence/fork-ceremony/fork-ceremony-evidence.json --environment fork --chain-id 1 --block-or-reference "<fork/testnet block, Safe transaction set, or ceremony transcript reference>" --command-or-source-system "<ceremony transcript, Safe export, explorer source, or CI job>" --owner "<operator>" --reviewer "<reviewer>" --source-git-commit "<release commit>" --source-ci-run "<ci run>"
python scripts/check_non_local_release_evidence.py
python scripts/check_public_beta_evidence.py
python scripts/generate_release_manifest.py --check
python scripts/generate_release_checksums.py --check
```

## Operator Notes

- Replace every `TBD` field before requesting review.
- Keep #219 open until reviewed retained evidence is linked from the shared
  public-beta evidence manifest row for fork/testnet ceremony evidence.
- This artifact is the public-beta fork/testnet version of the deployment,
  admin, signer, metadata, auction, emergency, and monitoring ceremony proof.
- Do not commit private keys, private RPC URLs, API keys, signer-service
  credentials, private Safe session material, unreleased drop payloads, or
  unredacted operator logs in this repository.
- Replace private RPC or provider URLs with `<redacted>` before review; the
  checker fails closed on provider/API-token-shaped URLs.
