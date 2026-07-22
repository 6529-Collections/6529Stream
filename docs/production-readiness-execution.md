# Production Readiness Execution Packet

This packet records the current production-readiness execution state for the
remote `main` release candidate. It is not a production-readiness claim and it
does not replace the generated release evidence status manifest in
[`release-artifacts/latest/public-beta-evidence.json`](../release-artifacts/latest/public-beta-evidence.json).

## Candidate Freeze

| Field | Value |
| --- | --- |
| Candidate source | `https://github.com/6529-Collections/6529Stream` |
| Candidate commit | `8d6a90f2539eb22dfa8d5c46d98ae704e5f73efa` |
| Candidate summary | PR #610 merge: configurable proceeds split, optional curator fund, stronger `StreamMinter.updateContracts` dependency checks, and Slither-outcome cleanup |
| Execution date | 2026-06-21 |
| Readiness posture | Public beta blocked; production release blocked |
| No-secret posture | No private keys, RPC URLs, API keys, signer-service secrets, or unreleased drop payloads were used or retained in this packet |

The public ABI, events, roles, deployment order, and release artifacts should
remain frozen from this commit unless external audit remediation requires a
documented change. Any contract or release-artifact change after this point must
rerun the full candidate gate and regenerate affected release artifacts.

## Local Candidate Results

| Gate | Result | Evidence |
| --- | --- | --- |
| Foundry test suite | Passed | `forge test -vvv`; 480 tests passed, 0 failed, 0 skipped |
| Production size build | Passed | `forge build --sizes --via-ir --skip test --skip script --force` |
| `StreamCore` runtime size | Passed | 21,824 bytes runtime, 2,752 bytes EIP-170 margin |
| Gas snapshot | Passed | `forge snapshot --match-path test/StreamGasSnapshot.t.sol --check release-artifacts/baselines/v0.1.0/gas-snapshot.snap`; 12 tests passed |
| Gas envelope checks | Passed | Direct `python scripts/test_gas_envelopes.py` and `python scripts/check_gas_envelopes.py` runs passed |
| Slither | Blocked locally | `slither` is not installed in the execution environment; run the pinned `slither-analyzer==0.11.5` toolchain from `requirements-tools.txt` before release approval |
| Size-budget Python checks | Blocked locally | `python scripts/test_contract_size_budget.py`, `python scripts/check_contract_size_budget.py`, and `python scripts/check_core_bytecode_spend_policy.py` require Ethereum Keccak support from the tools environment |
| Full local release gate | Not complete | `make check` was attempted and reached build/test/gas work, then stopped at a Windows sandbox `Access is denied` process-spawn failure on `python scripts/test_gas_envelopes.py`; direct gas-envelope commands passed, but `make check` and `powershell -ExecutionPolicy Bypass -File scripts\check.ps1` must be rerun in a normal shell after the pinned Python tools environment is installed |

The successful local gates are regression evidence only. They do not replace
external audit, reviewed testnet evidence, production signatures, signed tags,
verified deployed addresses, explorer verification, live ceremony evidence, or
post-audit remediation evidence.

## Public Beta Blockers

The generated public-beta blocker report remains authoritative:
[`release-artifacts/latest/public-beta-blockers.md`](../release-artifacts/latest/public-beta-blockers.md).
The following rows must be completed or explicitly risk-accepted before public
beta can be claimed:

| Issue | Requirement | Required evidence |
| --- | --- | --- |
| #215 | `external_audit_report` | Completed external audit report, audited commit, finding IDs, remediation links, accepted-risk references where applicable, retest status, and reviewer confirmation |
| #217 | `testnet_deployment_rehearsal` | Testnet deployment transcript, chain ID, transaction references, sanitized broadcast, generated manifest, address book, explorer status, and reviewer confirmation |
| #221 | `verified_deployed_addresses` | Reviewed non-local address-book evidence, deployment manifest references, independent address verification sources, chain ID, contract names, and reviewer confirmation |
| #222 | `explorer_verification_status` | Explorer verification submissions or verified-source links for non-local contracts, compiler settings source, verification result, and reviewer confirmation |

## Production Release Blockers

The generated production blocker report remains authoritative:
[`release-artifacts/latest/production-release-blockers.md`](../release-artifacts/latest/production-release-blockers.md).
Production release cannot proceed until public beta readiness is complete and
the following production rows are complete or explicitly risk-accepted:

| Issue | Requirement |
| --- | --- |
| #223 | `production_signatures` |
| #224 | `signed_git_tag` |
| #225 | `production_address_books` |
| #226 | `production_broadcast_retention` |
| #227 | `live_deployment_manifest` |
| #228 | `live_ceremony_evidence` |
| #229 | `live_randomizer_operations_evidence` |
| #473 | `live_metadata_browser_evidence` |
| #424 | `live_marketplace_indexer_evidence` |
| #230 | `live_explorer_verification` |
| #231 | `post_audit_remediation` |

Do not close the linked tracker issues until
`python scripts/check_release_evidence_issue_closure.py` passes. For live
GitHub state, run `make release-evidence-live-issue-sync-check` with
authenticated `gh` access.

## Required Next Execution

Before any public beta or production-release claim:

1. On Linux CPython `3.12.13`, install the hashed tools environment from
   `requirements-tools.lock` with the command in `docs/tooling.md`, without
   changing readiness claims.
2. Run `make check` and `powershell -ExecutionPolicy Bypass -File scripts\check.ps1`
   on the frozen candidate commit.
3. Run Slither with `slither . --config-file slither.config.json --foundry-compile-all`
   and retain the accepted baseline or remediation evidence.
4. Complete the public-beta evidence rows in the generated blocker report.
5. Run `python scripts/check_release_mode.py --phase public-beta`; it must pass
   before production-release execution starts.
6. Complete external audit remediation and regenerate affected release artifacts
   if audit work changes code, ABI, bytecode, manifests, or release evidence.
7. Complete production signatures, signed tag, live deployment, retained
   broadcasts, address books, explorer verification, ceremony evidence,
   randomizer operations evidence, metadata-browser evidence, marketplace/indexer
   evidence, and post-audit remediation evidence.
8. Run `python scripts/check_release_mode.py --phase production-release`; it must
   pass before publishing a production release.
