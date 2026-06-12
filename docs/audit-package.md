# External Audit Package

This is the auditor-facing index for the current 6529Stream repository state.
It is a pre-audit local baseline, not production-ready, and not a security claim.
It exists so reviewers can find the current scope, decisions, evidence, known
blockers, and local verification commands without reconstructing them from the
full repository history.

## Maturity And Scope

Current maturity:

- Repository status: pre-audit and not production-ready.
- Evidence status: local baseline only.
- Release status: no production deployment, no public release signature, and no
  completed third-party audit.
- Security status: current tests, Slither disposition, and release artifacts
  are review inputs, not protocol correctness proofs.

In-scope review surfaces for this package:

- Solidity contracts under [`smart-contracts/`](../smart-contracts).
- Foundry tests and local deployment rehearsals under [`test/`](../test) and
  [`script/`](../script).
- Accepted protocol decisions in [`docs/adr/`](adr/README.md).
- Operational docs, release artifacts, generated manifests, and retained local
  evidence linked below.

Explicitly out of scope for this package:

- Fork, testnet, or mainnet deployment evidence.
- Production signer identity, detached checksum signatures, or signed release
  tags.
- A completed external audit report.
- Any private key, mnemonic, RPC URL, API key, or unreleased drop payload.
- A claim that the current local gates prove production safety.

## Reviewer Entry Points

| Purpose | Entry point |
| --- | --- |
| Project overview | [`README.md`](../README.md) |
| Architecture map | [`docs/architecture.md`](architecture.md) |
| Threat model | [`docs/threat-model.md`](threat-model.md) |
| Current maturity and evidence | [`docs/status.md`](status.md) |
| Known unresolved blockers | [`docs/known-blockers.md`](known-blockers.md) |
| Release-readiness dashboard | [`docs/release-readiness.md`](release-readiness.md) |
| Gated execution roadmap | [`ops/ROADMAP.md`](../ops/ROADMAP.md) |
| Autonomous execution state | [`ops/AUTONOMOUS_RUN.md`](../ops/AUTONOMOUS_RUN.md) |
| Contributor workflow | [`CONTRIBUTING.md`](../CONTRIBUTING.md) |
| Private security reporting | [`SECURITY.md`](../SECURITY.md) |
| Toolchain and local gates | [`docs/tooling.md`](tooling.md) |
| Release artifact guide | [`release-artifacts/README.md`](../release-artifacts/README.md) |

## Protocol Decisions

Accepted ADRs are part of the audit scope. They define intended behavior that
tests, deployment evidence, and future audit findings should be traced against.

| Decision area | ADR |
| --- | --- |
| ADR process and index | [`docs/adr/README.md`](adr/README.md) |
| Drop authorization | [`docs/adr/0001-drop-authorization.md`](adr/0001-drop-authorization.md) |
| Auction custody | [`docs/adr/0002-auction-custody.md`](adr/0002-auction-custody.md) |
| Payment accounting | [`docs/adr/0003-payment-accounting.md`](adr/0003-payment-accounting.md) |
| Admin and governance | [`docs/adr/0004-admin-governance.md`](adr/0004-admin-governance.md) |
| Randomness | [`docs/adr/0005-randomness.md`](adr/0005-randomness.md) |
| Metadata freeze | [`docs/adr/0006-metadata-freeze.md`](adr/0006-metadata-freeze.md) |
| Upgrade and redeployment | [`docs/adr/0007-upgrade-redeployment.md`](adr/0007-upgrade-redeployment.md) |

Protocol-specific docs that are useful during review:

- [`docs/auction-custody.md`](auction-custody.md)
- [`docs/metadata.md`](metadata.md)
- [`docs/dependency-operations.md`](dependency-operations.md)
- [`docs/randomizer-operations.md`](randomizer-operations.md)
- [`docs/deployment.md`](deployment.md)
- [`docs/release-policy.md`](release-policy.md)
- [`docs/release-signatures.md`](release-signatures.md)
- [`docs/release-readiness.md`](release-readiness.md)

## Invariants And Test Evidence

The current tests are regression tripwires and local invariant baselines. They
should be treated as audit evidence to inspect, not as exhaustive proof.

| Evidence area | Current evidence |
| --- | --- |
| Payment accounting and reserves | [`test/StreamPaymentsInvariant.t.sol`](../test/StreamPaymentsInvariant.t.sol) |
| Supply, replay, burn, and freeze state | [`test/StreamSupplyReplayFreezeInvariant.t.sol`](../test/StreamSupplyReplayFreezeInvariant.t.sol) |
| Auction custody and proceeds consistency | [`test/StreamAuctionInvariant.t.sol`](../test/StreamAuctionInvariant.t.sol) |
| Randomizer reserve lifecycle | [`test/StreamRandomizerPayments.t.sol`](../test/StreamRandomizerPayments.t.sol) |
| Deployment, manifest, and ceremony smoke tests | [`test/StreamDeploymentManifest.t.sol`](../test/StreamDeploymentManifest.t.sol) |
| Full status summary | [`docs/status.md`](status.md) |
| Test matrix and remaining test work | [`ops/ROADMAP.md`](../ops/ROADMAP.md) |

Reviewers should verify that every future accepted audit finding is mapped to a
direct regression test, invariant, or documented non-code acceptance decision.

## Static Analysis

Static-analysis review inputs:

- [`docs/slither.md`](slither.md) documents the pinned Slither toolchain and
  local command.
- [`ops/SLITHER_BASELINE.md`](../ops/SLITHER_BASELINE.md) tracks high and
  medium findings, resolutions, false-positive dispositions, and test links.
- [`docs/vendored-libraries.md`](vendored-libraries.md) documents retained
  vendored OpenZeppelin utility provenance and accepted Slither dispositions.

Slither is currently a diagnostic input. Low, informational, and optimization
findings remain outside the current CI gate unless a future roadmap item
promotes them.

## Deployment And Release Evidence

Local deployment and release evidence:

- [`docs/deployment.md`](deployment.md) documents local deployment, auction,
  metadata browser, and emergency redeployment rehearsals.
- [`deployments/ceremony-evidence/anvil-6529stream-v0.1.0-001-local.json`](../deployments/ceremony-evidence/anvil-6529stream-v0.1.0-001-local.json)
  records no-secret local ceremony evidence.
- [`deployments/randomizer-operations/anvil-6529stream-v0.1.0-001-local.json`](../deployments/randomizer-operations/anvil-6529stream-v0.1.0-001-local.json)
  records no-secret local randomizer operations evidence.
- [`release-artifacts/latest/release-manifest.json`](../release-artifacts/latest/release-manifest.json)
  is the generated top-level release evidence index.
- [`release-artifacts/latest/SHA256SUMS`](../release-artifacts/latest/SHA256SUMS)
  is the signable checksum bundle for covered release and deployment artifacts.
- [`release-artifacts/latest/release-checksums.json`](../release-artifacts/latest/release-checksums.json)
  is the machine-readable checksum bundle.
- [`release-artifacts/signatures/anvil-6529stream-v0.1.0-001-local.json`](../release-artifacts/signatures/anvil-6529stream-v0.1.0-001-local.json)
  records local placeholder signature evidence and the self-referential
  manifest/checksum boundary.

The release manifest includes this audit package as a governance document. The
release manifest also includes the architecture map and threat model as
governance documents. The checksum bundle covers the release manifest, so
changes to the audit package, architecture map, or threat model must refresh
release evidence before a release-oriented PR can pass.

## Known Blockers And Accepted Risks

Known unresolved blockers are tracked in
[`docs/known-blockers.md`](known-blockers.md) and
[`ops/ROADMAP.md`](../ops/ROADMAP.md). Current major unresolved categories
include fork/testnet/live deployment ceremonies, production broadcast retention,
live explorer verification, production address books, production release
signatures, non-local randomizer operations evidence, non-local metadata browser
evidence, and external audit completion.

Accepted local-baseline dispositions are separate from unresolved production
blockers:

- Some Slither rows are accepted as test-only helper findings or documented
  vendored-library false positives in
  [`ops/SLITHER_BASELINE.md`](../ops/SLITHER_BASELINE.md).
- Local Anvil ceremony, randomizer operations, and release signature evidence
  use no-secret placeholders and do not claim production status.
- Runtime size remains under the current release floor but close enough to the
  EIP-170 limit that large future `StreamCore` changes need explicit size
  review.

No production risk is accepted for public launch by this audit package.

## Security Reporting

Report suspected vulnerabilities privately through
[`SECURITY.md`](../SECURITY.md). Do not disclose exploitable security issues in
public issues, public PRs, or social channels. Normal non-security contribution
workflow lives in [`CONTRIBUTING.md`](../CONTRIBUTING.md).

Security reports should include affected commit, contract(s), issue impact,
reproduction steps, expected result, actual result, and any suggested tests or
invariant changes. Public remediation PRs should link the advisory only after
maintainers confirm disclosure timing.

## Local Verification Commands

Run the audit-package checks directly:

```sh
python scripts/test_audit_package.py
python scripts/check_audit_package.py
python scripts/test_architecture_threat_model.py
python scripts/check_architecture_threat_model.py
python scripts/test_release_readiness.py
python scripts/check_release_readiness.py
```

Run the release evidence checks that include this package:

```sh
python scripts/generate_release_manifest.py --check
python scripts/generate_release_checksums.py --check
```

Run the full local gate when changing audit scope, release artifacts, or
protocol behavior:

```sh
make check
```

Windows contributors can use the platform wrapper:

```powershell
powershell -ExecutionPolicy Bypass -File scripts\check.ps1
```

## Package Maintenance

Update this package when any of the following changes:

- audit scope, contract scope, or launch gate status;
- accepted ADRs or protocol decisions;
- static-analysis baseline disposition;
- invariant, gas, deployment, release, or ceremony evidence;
- known blockers or accepted local-baseline risk dispositions;
- security reporting process or release signing process.

After editing this file, run:

The `generate_*` calls below regenerate tracked output files; the `--check`
calls verify that those tracked files are current.

```sh
python scripts/test_audit_package.py
python scripts/check_audit_package.py
python scripts/test_architecture_threat_model.py
python scripts/check_architecture_threat_model.py
python scripts/test_release_readiness.py
python scripts/check_release_readiness.py
python scripts/generate_release_manifest.py
python scripts/generate_release_checksums.py
python scripts/generate_release_manifest.py --check
python scripts/generate_release_checksums.py --check
```
