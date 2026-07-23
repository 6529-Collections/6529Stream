# Production Readiness Execution Packet

This packet records the current production-readiness execution state starting
from the remote `main` baseline identified below. It is not a frozen or
approved release candidate, it is not a production-readiness claim, and it does
not replace the generated release evidence status manifest in
[`release-artifacts/latest/public-beta-evidence.json`](../release-artifacts/latest/public-beta-evidence.json).

## Candidate Baseline

| Field | Value |
| --- | --- |
| Candidate source | `https://github.com/6529-Collections/6529Stream` |
| Candidate commit | `b77e2338df10f223a0b892a58af4497d156d8576` |
| Candidate summary | Current remote `main` after PR #660: locked Python audit/release toolchain, canonical genesis-profile and Slither drift gates, and unchanged blocked production posture |
| Execution date | 2026-07-22 |
| Readiness posture | Public beta blocked; production release blocked |
| No-secret posture | No private keys, RPC URLs, API keys, signer-service secrets, or unreleased drop payloads were used or retained in this packet |

This commit is the comparison baseline for the next remediation PR, not a
freeze. Any contract or release-artifact change after this point must rerun the
relevant focused checks, the full candidate gate, and the deterministic
artifact generators in canonical order.

## Local Candidate Results

| Gate | Result | Evidence |
| --- | --- | --- |
| Full ordinary repository gate | Passed on PR #660 before merge | `powershell -NoProfile -ExecutionPolicy Bypass -File scripts\check.ps1`; Foundry, Slither, and Windows CI passed on the reviewed final head |
| Production size build | Measured, release-blocking | `python scripts/build_release_artifacts.py` followed by `python scripts/check_contract_size_budget.py` records canonical `StreamCore` at 24,152 runtime bytes; the aggregate all-source size build is diagnostic only |
| `StreamCore` production headroom | Blocked | 424 bytes of EIP-170 margin, 1,576 bytes below the non-waivable 2,000-byte production minimum; issue #654 owns remediation |
| Genesis deployment profile | Blocked | The active target specification expands the checked profile to 60 entries, including Permanent `StreamSystemManifest` entry 36 and immutable Permanent `StreamCoreFinalityAdapter` entry 37, but the current v1 implementation catalog cannot prove deployment-instance identity, fallback distinctness, or parameterized probe bindings; issue #656 owns reconciliation |
| Slither first-party High/Medium | Blocked | Pinned Slither 0.11.5 analysis records 38 Open production rows (4 High, 34 Medium): one confirmed gap, six design-review rows, and 31 pending dispositions; issue #658 owns remediation and reviewed disposition |
| Slither exact drift automation | Implemented on `main` by PR #662 | `python scripts/test_slither_baseline.py`, `python scripts/check_slither_baseline.py --baseline-only`, and `python scripts/check_slither_baseline.py --run-slither`; matching the baseline is not acceptance |
| Production release mode | Blocked | External evidence, Core headroom, genesis completeness, and open Slither findings must all fail closed before production release |

The successful local gates are regression evidence only. They do not replace
external audit, reviewed testnet evidence, production signatures, signed tags,
verified deployed addresses, explorer verification, live ceremony evidence, or
post-audit remediation evidence.

## Public Beta Blockers

The generated public-beta blocker report is authoritative for its
external-evidence requirement set:
[`release-artifacts/latest/public-beta-blockers.md`](../release-artifacts/latest/public-beta-blockers.md).
The following external-evidence rows must be completed or explicitly
risk-accepted before public beta can be claimed. Technical blockers such as
open Slither findings are enforced and tracked separately; passing this report
alone is insufficient.

| Issue | Requirement | Required evidence |
| --- | --- | --- |
| #215 | `external_audit_report` | Completed external audit report, audited commit, finding IDs, remediation links, accepted-risk references where applicable, retest status, and reviewer confirmation |
| #217 | `testnet_deployment_rehearsal` | Testnet deployment transcript, chain ID, transaction references, sanitized broadcast, generated manifest, address book, explorer status, and reviewer confirmation |
| #221 | `verified_deployed_addresses` | Reviewed non-local address-book evidence, deployment manifest references, independent address verification sources, chain ID, contract names, and reviewer confirmation |
| #222 | `explorer_verification_status` | Explorer verification submissions or verified-source links for non-local contracts, compiler settings source, verification result, and reviewer confirmation |

## Production Release Blockers

The generated production blocker report is authoritative for its
external-evidence requirement set:
[`release-artifacts/latest/production-release-blockers.md`](../release-artifacts/latest/production-release-blockers.md).
Production release cannot proceed until public beta readiness is complete, all
technical release blockers are resolved, and the following production evidence
rows are complete. Every production requirement is non-waivable:

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
   on the proposed candidate commit.
3. Run `python scripts/check_slither_baseline.py --run-slither`; remediate or
   produce issue-linked reviewed proof for every first-party production
   High/Medium row. Baseline equality alone is not acceptance.
4. Restore at least 2,000 bytes of `StreamCore` EIP-170 margin under issue #654
   and complete instance-aware genesis reconciliation under issue #656.
5. Complete the public-beta evidence rows in the generated blocker report.
6. Run `python scripts/check_release_mode.py --phase public-beta`; it must pass
   before production-release execution starts.
7. Complete external audit remediation and regenerate affected release artifacts
   if audit work changes code, ABI, bytecode, manifests, or release evidence.
8. Complete production signatures, signed tag, live deployment, retained
   broadcasts, address books, explorer verification, ceremony evidence,
   randomizer operations evidence, metadata-browser evidence, marketplace/indexer
   evidence, and post-audit remediation evidence.
9. Run `python scripts/check_release_mode.py --phase production-release`; it must
   pass before publishing a production release.
