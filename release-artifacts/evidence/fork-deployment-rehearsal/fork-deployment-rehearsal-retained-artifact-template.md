# Fork Deployment Rehearsal Retained Artifact

## Evidence Status

- Requirement ID: `fork_deployment_rehearsal`
- Review status: `pending_review`
- Readiness claim: `blocked`
- Environment: `fork`
- Chain ID: `1`

## Source And Fork Reference

- Repository: `https://github.com/6529-Collections/6529Stream`
- Git commit: `a35c24a4f3bcbf61db73c78f2e98822f09d17d59`
- CI run or operator transcript: `local transcript captured 2026-06-14T14:39Z; PR #347 CI run 27503447725 passed; PR #349 CI run 27504228132 passed; permanent-Core PR review pending for the changed deployment artifacts`
- Fork block number: `25316366`
- Fork block hash: `0xb7c7a456e0f1246fa4ee52de6fca99cc16628ce1eafd85b65b0f3d22f3933ee7`
- Command: `forge script script/RehearseDeployment.s.sol:RehearseDeployment --sig "run()" --rpc-url REDACTED_LOCAL_ANVIL_FORK --broadcast --unlocked --via-ir`

## Required Retained Artifacts

- Sanitized command transcript: `release-artifacts/evidence/fork-deployment-rehearsal/fork-deployment-rehearsal-retained-artifact-template.md`
- Sanitized Foundry broadcast: `deployments/broadcasts/fork-mainnet-6529stream-v0.1.0-001-run-latest.json` / `sha256:d09f1f684722e9d6a22e9f316d106b7f01d22e053bba5cf555dbe5221fecc387`
- Generated deployment manifest: `deployments/examples/fork-mainnet-6529stream-v0.1.0-001-broadcast.json` / `sha256:c6ba73493133cd7c6dce976646e8d5489eacc27fd2ea1dc6be2c946b803262c3`
- Generated address book: `deployments/address-books/fork-mainnet-6529stream-v0.1.0-001-broadcast.json` / `sha256:c5c7d94da0b12acb5719092453dd77c05ae614c6d71a80a782b9ea9d89f85893`
- Verification status: `not_applicable_for_local_fork; source verification inputs remain retained separately and explorer verification remains a separate public-beta blocker`
- Gas or invariant summary: `estimated_total_gas_used=32521731; all retained deployment receipts status=0x1; release CI will rerun build, tests, gas snapshot, size, and deployment rehearsal gates`
- Release manifest/checksum digests: `release-artifacts/latest/release-manifest.json and release-artifacts/latest/SHA256SUMS regenerated in this PR`

## Rehearsal Results

- Deployment completed: `yes`
- Manifest generated: `yes`
- Address book generated: `yes`
- Verification checked: `not_applicable_for_local_fork`
- Gas or invariant summary checked: `yes`

## Review

- Operator: `Codex autonomous operator`
- Reviewer: `pending permanent-Core PR review; historical CodeRabbit status success on PR #347 and PR #349`
- Review decision: `pending_review`

## Redaction

- No secrets retained: `yes`
- Private RPC URLs removed: `yes`
- Private keys removed: `yes`
- Unreleased drop payloads removed: `yes`

## Validation Commands

```sh
python scripts/test_fork_deployment_rehearsal_evidence.py
python scripts/check_fork_deployment_rehearsal_evidence.py
python scripts/generate_non_local_release_evidence.py --template release-artifacts/evidence/public-beta-templates/fork-deployment-rehearsal-template.json --retained-artifact release-artifacts/evidence/fork-deployment-rehearsal/fork-deployment-rehearsal-retained-artifact-template.md --output release-artifacts/evidence/fork-deployment-rehearsal/fork-deployment-rehearsal-evidence.json --environment fork --chain-id 1 --block-or-reference "fork block 25316366 / 0xb7c7a456e0f1246fa4ee52de6fca99cc16628ce1eafd85b65b0f3d22f3933ee7" --command-or-source-system-from-retained --owner "Codex autonomous operator" --reviewer "pending permanent-Core PR review; historical CodeRabbit status success on PR #347 and PR #349" --review-status pending_review --source-git-commit a35c24a4f3bcbf61db73c78f2e98822f09d17d59 --source-ci-run "PR #347 CI run 27503447725; PR #349 CI run 27504228132; permanent-Core PR review pending" --operator-notes "Fork rehearsal retained from source commit a35c24a4f3bcbf61db73c78f2e98822f09d17d59; PR #347 retained the sanitized fork broadcast, deployment manifest, and address book with CodeRabbit status success and passing CI, and PR #349 reconciled the live issue body/audit state with CodeRabbit status success and passing CI. The permanent-Core metadata/router cutover changes the retained deployment manifest and address book, so this artifact is pending review before the row can return to complete. Public beta remains blocked."
python scripts/check_non_local_release_evidence.py
python scripts/check_public_beta_evidence.py
python scripts/generate_release_manifest.py --check
python scripts/generate_release_checksums.py --check
```

## Operator Notes

- The rehearsal used a local Anvil fork of Ethereum mainnet at block
  `25316366`; the public RPC endpoint and local Anvil URL are intentionally not
  retained.
- The placeholder deployer address
  `0x0000000000000000000000000000000000006537` was funded only inside the
  local fork before `--broadcast --unlocked` execution.
- Foundry reported `ONCHAIN EXECUTION COMPLETE & SUCCESSFUL`, produced the
  retained broadcast JSON, and the generated fork manifest/address book were
  derived from that broadcast.
- The public-beta requirement row remains `pending` until the changed CON-015
  deployment manifest and address book are reviewed in the collection
  metadata/preservation PR. Public beta as a release phase remains blocked on
  the remaining missing evidence rows in the shared evidence manifest.
