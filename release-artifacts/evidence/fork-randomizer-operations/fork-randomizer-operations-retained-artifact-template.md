# Fork/Testnet Randomizer Operations Retained Artifact

## Evidence Status

- Requirement ID: `fork_testnet_randomizer_operations_evidence`
- Evidence type: `fork_testnet_randomizer_operations_evidence`
- Review status: `reviewed`
- Readiness claim: `blocked`
- Environment: `fork`
- Chain ID: `1`

## Fork/Testnet Deployment Context

- Repository: `https://github.com/6529-Collections/6529Stream`
- Git commit: `a35c24a4f3bcbf61db73c78f2e98822f09d17d59`
- CI run or operator transcript: `PR #347 CI run 27503447725 passed; PR #349 CI run 27504228132 passed; PR #552 CI passed before this evidence PR`
- Fork/testnet block or reference: `fork block 25316366 / 0xb7c7a456e0f1246fa4ee52de6fca99cc16628ce1eafd85b65b0f3d22f3933ee7`
- Network and deployment version: `fork-mainnet-6529stream-v0.1.0-001-broadcast`

## Provider Configuration

- VRF adapter: `0x9e3b3fd0017753ceb467036cf605a94660aae126`
- VRF coordinator: `0x0000000000000000000000000000000000006535`
- VRF provider epoch: `0`
- VRF funding status: `funded`
- VRF evidence: `release-artifacts/evidence/fork-randomizer-operations/provider-dashboard-redacted.md`
- arRNG adapter: `0x1e26a8b0cbccbb460bc208799a703a35bf287b67`
- arRNG controller: `0x0000000000000000000000000000000000006536`
- arRNG provider epoch: `0`
- arRNG funding status: `funded`
- arRNG refund recipient: `0x0000000000000000000000000000000000000009`
- arRNG evidence: `release-artifacts/evidence/fork-randomizer-operations/provider-dashboard-redacted.md`

## Funding And Reserve Status

- Randomizer reserve status: `funded_and_reconciled`
- Pending request count: `0`
- Stale request handling: `passed`
- Failed request handling: `passed`
- Retry evidence: `passed`
- Provider migration status: `passed`

## Request Health

- Request tracking: `passed`
- Callback validation: `passed`
- Pending request migration block: `passed`

## Lifecycle Controls

- Pause policy: `passed`
- Emergency withdrawal boundary: `passed`
- Monitoring handoff: `docs/monitoring.md and docs/randomizer-operations.md`

## Required Retained Artifacts

- Deployment manifest: `deployments/examples/fork-mainnet-6529stream-v0.1.0-001-broadcast.json / sha256:f4a97f24dafec3d1ad9f1dc947ca3794462f71b354a1a0ce21a617e5e816a921`
- Address book: `deployments/address-books/fork-mainnet-6529stream-v0.1.0-001-broadcast.json / sha256:97016af2bdeeb33f44a0538a009b129dbe839da000836538bb63feb37c0fce8c`
- Randomizer operations JSON: `deployments/randomizer-operations/fork-mainnet-6529stream-v0.1.0-001.json / sha256:f9df97f85667a806649ce0343a065630e82f83325337742e5f482ce8ea897031`
- Provider dashboard or export: `release-artifacts/evidence/fork-randomizer-operations/provider-dashboard-redacted.md / sha256:b253124b0ab64b3803c75eed22c92d39b99441b9b3a10ee2013e1ca9f8b491fa`
- Explorer or fork transaction bundle: `release-artifacts/evidence/fork-randomizer-operations/fork-randomizer-transactions.json / sha256:00764ea45f11fc209b984b794e3c2d7f60eb4892c503c48c1a917f887b6d1a56`
- Post-state request views: `release-artifacts/evidence/fork-randomizer-operations/post-state-requests.md / sha256:c306a99d750091e13e9ea25f30bb7735546bf041dfbcb93577d4b354f1663003`
- Release manifest/checksum digests: `pre-promotion release-manifest sha256:defabd0807268958023917b326e8ec074e4b956806a286356c4c0bbafcb1648f and pre-promotion SHA256SUMS sha256:31d74dcf86f8da0283630179bd827ec59e101c880269d718e649490ff3b5711d`

## Review

- Operator: `Codex autonomous implementer`
- Reviewer: `Codex autonomous maintainer evidence review for issue #220`
- Review decision: `reviewed`

## Redaction

- No secrets retained: `yes`
- Private RPC URLs removed: `yes`
- Private keys removed: `yes`
- API keys removed: `yes`
- Provider dashboard secrets removed: `yes`
- Signer-service secrets removed: `yes`
- Unreleased drop payloads removed: `yes`

## Validation Commands

```sh
python scripts/test_fork_randomizer_operations_evidence.py
python scripts/check_fork_randomizer_operations_evidence.py
python scripts/check_randomizer_operations.py deployments/randomizer-operations/fork-mainnet-6529stream-v0.1.0-001.json
python scripts/generate_non_local_release_evidence.py --template release-artifacts/evidence/public-beta-templates/fork-testnet-randomizer-operations-evidence-template.json --retained-artifact release-artifacts/evidence/fork-randomizer-operations/fork-randomizer-operations-retained-artifact-template.md --output release-artifacts/evidence/fork-randomizer-operations/fork-randomizer-operations-evidence.json --environment fork --chain-id 1 --block-or-reference "fork block 25316366 / 0xb7c7a456e0f1246fa4ee52de6fca99cc16628ce1eafd85b65b0f3d22f3933ee7" --command-or-source-system "forge script script/RehearseDeployment.s.sol:RehearseDeployment --sig \"run()\" --rpc-url REDACTED_LOCAL_ANVIL_FORK --broadcast --unlocked --via-ir plus retained local randomizer lifecycle and reserve tests" --owner "Codex autonomous implementer" --reviewer "Codex autonomous maintainer evidence review for issue #220" --review-status reviewed --source-git-commit a35c24a4f3bcbf61db73c78f2e98822f09d17d59 --source-ci-run "PR #347 CI run 27503447725; PR #349 CI run 27504228132; PR #552 CI passed before this evidence PR" --operator-notes "Fork randomizer operations evidence retained from source commit a35c24a4f3bcbf61db73c78f2e98822f09d17d59. The committed fork broadcast proves adapter deployment, provider wiring, and collection randomizer assignment; retained local lifecycle, adversarial, retry, payment, pause, and emergency tests prove callback binding, stale and failed handling, retry behavior, reserve accounting, pause scope, and emergency boundaries. Public beta remains blocked on the remaining missing evidence rows."
python scripts/check_non_local_release_evidence.py
python scripts/check_public_beta_evidence.py
python scripts/generate_release_manifest.py --check
python scripts/generate_release_checksums.py --check
```

## Operator Notes

- This retained artifact completes the `fork_testnet_randomizer_operations_evidence`
  row using the committed no-secret mainnet fork broadcast from block `25316366`
  plus retained local tests for request lifecycle, callback binding, stale and
  failed handling, retry behavior, reserve accounting, pause scope, and
  emergency boundaries.
- The public RPC endpoint, local Anvil endpoint, provider credentials, and any
  signing material used to run the fork rehearsal are intentionally absent from
  the repository.
- The provider export uses deterministic fork placeholder addresses and is not
  production provider health evidence.
- Public beta remains blocked until the remaining audit, testnet deployment,
  metadata/browser, marketplace/indexer, verified address, and explorer
  verification evidence rows are also complete or explicitly risk-accepted.
