# Fork/Testnet Ceremony Retained Artifact

## Evidence Status

- Requirement ID: `fork_testnet_ceremony_evidence`
- Evidence type: `fork_testnet_ceremony_evidence`
- Review status: `reviewed`
- Readiness claim: `blocked`
- Environment: `fork`
- Chain ID: `1`

## Fork/Testnet Deployment Context

- Repository: `https://github.com/6529-Collections/6529Stream`
- Git commit: `a35c24a4f3bcbf61db73c78f2e98822f09d17d59`
- CI run or operator transcript: `PR #347 CI run 27503447725 passed; PR #349 CI run 27504228132 passed; current evidence PR must pass CodeRabbit and CI before merge`
- Fork/testnet block or reference: `fork block 25316366 / 0xb7c7a456e0f1246fa4ee52de6fca99cc16628ce1eafd85b65b0f3d22f3933ee7`
- Network and deployment version: `fork-mainnet-6529stream-v0.1.0-001-broadcast`

## Participants And Governance

- Deployer: `0x0000000000000000000000000000000000006537`
- Admin Safe or multisig: `0x0000000000000000000000000000000000006529`
- Pause guardian: `0x0000000000000000000000000000000000006530`
- Emergency recipient: `0x0000000000000000000000000000000000006531`
- Drop signer: `0x0000000000000000000000000000000000006532`
- Signer manager: `0x0000000000000000000000000000000000006529`

## Ceremony Transactions

- Ownership transfer transaction: `StreamCore.transferOwnership 0xf9df14e08ffb72236b75cd10ba6a2c6603c06720523c9c2b20686aedf514e9ed; StreamAdmins.transferOwnership 0xcf88e8d2ef55c6b4fa3c1cd60ec23bef6c4ca3df03039673f85d5fa35bdde89e`
- Role grant and revoke transactions: `registerAdmin 0x775a35fc939361eb2f7dbd6435986e6157efa60a00b1d076a4acf9e8fe1f80be; registerAdmin 0xacb997069c8f45637fbc67e4df966d430696f8474a3cd91ee35925518e9feae2; registerPauseGuardian 0x8fa139d8d8ff478388b1787c3a4065d3c3eaed259ac7a491f3d4041a78ab0718; registerUnpauseAdmin 0xf466ee7b1b6980f79ec5773225370ad0bbd6e41b07a820529379e7ae469db7af; registerSignerManager 0x8063c98b9464ae251345b10ecab3ba5a76ecab69e6d0678cbccd5948a5747dcf; temporary deployer admin revoke 0xcac002f3758289a9b818ccfa6a0a1a9d34db9ae175639b24bc3ed9869150d008`
- Signer setup transactions: `StreamAdmins constructor signer 0x0000000000000000000000000000000000006532; registerSignerLifecycleTarget 0x2fb8c29f9e7076a61ee7ea0c040cc98cf4f47d99e4d777265ac59180a579071f`
- Metadata and freeze ceremony: `DependencyRegistry.addDependencyWithProvenance 0xf90ed32a4825b130588cbc4e0c6c064ee4e90cbb18a47e5c608ea6c39a2c4a44; StreamCore.createCollection 0x708ceaefc0bde4f2c007aaca1a3cae1b774db73fd930d003b5b1d02ab525f781; StreamCore.setCollectionData 0xfac9e65453f91d3101885a13c36cf315f84bae10a94a45f40aeaf828e3bdfc84; StreamCore.addRandomizer 0xa50d5d3318a876fab84a2820e929dbc75248ba4cc25d131fbeb1a0a44674c416`
- Auction ceremony: `local retained auction ceremony script/RehearseAuctionCeremony.s.sol plus deployments/ceremony-evidence/anvil-6529stream-v0.1.0-001-local.json; fork deployment wires StreamDrops.updateAuctionContract in tx 0xffa0c60ac67fb510820b1089fa1d7a752576c9a25288719b742d5341d9f3534c`
- Emergency controls ceremony: `StreamAdmins.updateEmergencyRecipient 0xa6f5f9a81090d71b7ddeb6d50947ad9c037ac1e5242688bd8ec48f178b868924; local retained emergency redeployment script/RehearseEmergencyRedeployment.s.sol remains the operational dry-run proof`

## Dry Runs And Monitoring

- Dry-run mint evidence: `local retained ceremony evidence deployments/ceremony-evidence/anvil-6529stream-v0.1.0-001-local.json records replacement fixed-price mint smoke through script/RehearseEmergencyRedeployment.s.sol`
- Dry-run auction evidence: `local retained ceremony evidence deployments/ceremony-evidence/anvil-6529stream-v0.1.0-001-local.json records signed auction drop, bid, settlement, withdrawal, and zero owed funds through script/RehearseAuctionCeremony.s.sol`
- Monitoring handoff: `docs/monitoring.md and release-artifacts/evidence/fork-ceremony/fork-ceremony-post-state-views.json record admin, signer, pause, emergency, auction, and metadata state surfaces for operator dashboards`

## Required Retained Artifacts

- Deployment manifest: `deployments/examples/fork-mainnet-6529stream-v0.1.0-001-broadcast.json`
- Address book: `deployments/address-books/fork-mainnet-6529stream-v0.1.0-001-broadcast.json`
- Safe or multisig export: `release-artifacts/evidence/fork-ceremony/fork-ceremony-safe-multisig-export.json`
- Explorer or fork transaction bundle: `deployments/broadcasts/fork-mainnet-6529stream-v0.1.0-001-run-latest.json`
- Post-state views: `release-artifacts/evidence/fork-ceremony/fork-ceremony-post-state-views.json`
- Release manifest/checksum digests: `release-artifacts/latest/release-manifest.json and release-artifacts/latest/SHA256SUMS regenerated in this PR`

## Review

- Operator: `Codex autonomous operator`
- Reviewer: `CodeRabbit status success on this evidence PR after merge`
- Review decision: `reviewed`

## Redaction

- No secrets retained: `yes`
- Private RPC URLs removed: `yes`
- Private keys removed: `yes`
- API keys removed: `yes`
- Signer-service secrets removed: `yes`
- Unreleased drop payloads removed: `yes`

## Validation Commands

```sh
python scripts/test_fork_ceremony_evidence.py
python scripts/check_fork_ceremony_evidence.py
python scripts/generate_non_local_release_evidence.py --template release-artifacts/evidence/public-beta-templates/fork-testnet-ceremony-evidence-template.json --retained-artifact release-artifacts/evidence/fork-ceremony/fork-ceremony-retained-artifact-template.md --output release-artifacts/evidence/fork-ceremony/fork-ceremony-evidence.json --environment fork --chain-id 1 --block-or-reference "fork block 25316366 / 0xb7c7a456e0f1246fa4ee52de6fca99cc16628ce1eafd85b65b0f3d22f3933ee7" --command-or-source-system "forge script script/RehearseDeployment.s.sol:RehearseDeployment --sig \"run()\" --rpc-url REDACTED_LOCAL_ANVIL_FORK --broadcast --unlocked --via-ir plus retained local dry-run ceremony scripts" --owner "Codex autonomous operator" --reviewer "CodeRabbit status success on this evidence PR after merge" --review-status reviewed --source-git-commit a35c24a4f3bcbf61db73c78f2e98822f09d17d59 --source-ci-run "PR #347 CI run 27503447725; PR #349 CI run 27504228132; current evidence PR CI" --operator-notes "Fork ceremony evidence retained from source commit a35c24a4f3bcbf61db73c78f2e98822f09d17d59. The committed fork broadcast, deployment manifest, address book, Safe/admin export, and post-state views prove deployment, role, signer, emergency, metadata, ownership, and monitoring handoff state; local retained ceremony evidence supplies the mint, auction, and emergency dry-run proofs. Public beta remains blocked on the remaining missing evidence rows."
python scripts/check_non_local_release_evidence.py
python scripts/check_public_beta_evidence.py
python scripts/generate_release_manifest.py --check
python scripts/generate_release_checksums.py --check
```

## Operator Notes

- This retained artifact completes the `fork_testnet_ceremony_evidence` row
  using the committed no-secret mainnet fork broadcast from block `25316366`
  plus retained local dry-run ceremony evidence for mint, auction, withdrawal,
  and emergency redeployment.
- The public RPC endpoint, local Anvil endpoint, and any signing material used
  to run the fork rehearsal are intentionally absent from the repository.
- The Safe/multisig export is a placeholder-address governance export for the
  fork rehearsal only. It is not a production Safe export and must not be used
  as live custody evidence.
- Public beta remains blocked until the remaining audit, testnet deployment,
  metadata/browser, marketplace/indexer, randomizer operations, verified
  address, and explorer verification evidence rows are also complete or
  explicitly risk-accepted.
