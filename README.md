# 6529Stream

6529Stream is a Solidity protocol for 6529 NFT drops. It covers fixed-price
minting, auction flows, curator rewards, TDH-authorized execution, metadata
generation, one-of-one provenance and permanence artifacts, royalty disclosure,
and randomizer adapter flows.

## Current Maturity

This repository has a serious pre-audit local baseline, but it is not
production-ready and not a security claim.

`make check` currently proves compilation, Foundry test execution, production
runtime size limits, local deployment rehearsal, deterministic release artifact
generation, ABI compatibility checks, source-verification inputs, protocol
surface reports, release manifests, checksum bundles, integration docs,
security docs, and public-beta/production blocker reports. It does not prove
protocol correctness by itself, and it does not replace public beta or
production release evidence.

Public beta remains blocked until retained evidence exists for reviewed
fork/testnet or live deployment rehearsal, signed release artifacts, verified
addresses, explorer verification, signer custody readiness, production signing,
and live metadata/indexer/marketplace evidence. Production release also remains
blocked on external audit, post-audit remediation, signed tag ceremony, and
accepted release-mode evidence.

Start with:

- [docs/first-30-minutes.md](docs/first-30-minutes.md)
- [docs/status.md](docs/status.md)
- [docs/release-readiness.md](docs/release-readiness.md)
- [docs/public-beta-evidence.md](docs/public-beta-evidence.md)
- [release-artifacts/latest/public-beta-blockers.md](release-artifacts/latest/public-beta-blockers.md)
- [release-artifacts/latest/production-release-blockers.md](release-artifacts/latest/production-release-blockers.md)
- [docs/known-blockers.md](docs/known-blockers.md)
- [ops/ROADMAP.md](ops/ROADMAP.md)
- [ops/EXECUTION_BACKLOG.md](ops/EXECUTION_BACKLOG.md)

## First 30 Minutes

1. Install Foundry `v1.7.1`, Solidity compiler `0.8.19`, Python 3.8+, and
   Slither `0.11.5` if you need static-analysis parity.
2. Run the canonical local gate:

```bash
make check
```

3. On Windows, run the PowerShell wrapper:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\check.ps1
```

4. If dependencies are missing, use the bootstrap helpers:

```bash
bash scripts/bootstrap-ec2.sh
```

```powershell
powershell -ExecutionPolicy Bypass -File scripts\bootstrap-windows.ps1
```

5. Read [docs/first-30-minutes.md](docs/first-30-minutes.md) for the checked
   fresh-contributor path, [docs/tooling.md](docs/tooling.md) for the full
   command inventory, and [docs/release-readiness.md](docs/release-readiness.md)
   for what the local gate does and does not prove.

## Find Your Path

| Role | Start Here | What To Verify |
| --- | --- | --- |
| Auditor or security reviewer | [docs/audit-package.md](docs/audit-package.md), [docs/architecture.md](docs/architecture.md), [docs/threat-model.md](docs/threat-model.md), [docs/adr/README.md](docs/adr/README.md), [docs/slither.md](docs/slither.md), [ops/SLITHER_BASELINE.md](ops/SLITHER_BASELINE.md), [SECURITY.md](SECURITY.md) | Scope, trust boundaries, accepted ADRs, known blockers, Slither dispositions, risk register, and reporting path |
| Integrator, frontend, mobile, Electron, or indexer engineer | [docs/integrations/README.md](docs/integrations/README.md), [docs/integrations/contract-flows.md](docs/integrations/contract-flows.md), [docs/integrations/auction-flows.md](docs/integrations/auction-flows.md), [docs/integrations/wallets-and-signatures.md](docs/integrations/wallets-and-signatures.md), [docs/integrations/events-and-indexing.md](docs/integrations/events-and-indexing.md), [docs/integrations/metadata-rendering.md](docs/integrations/metadata-rendering.md), [docs/integrations/frontend-reference-architecture.md](docs/integrations/frontend-reference-architecture.md), [docs/integrations/mobile-walletconnect.md](docs/integrations/mobile-walletconnect.md), [docs/integrations/electron-security-wallets.md](docs/integrations/electron-security-wallets.md), [docs/integrations/operator-admin-ui.md](docs/integrations/operator-admin-ui.md), [docs/monitoring.md](docs/monitoring.md), [docs/operator-dashboard-query-model.md](docs/operator-dashboard-query-model.md) | ABIs, address books, deployment manifests, EIP-712 and ERC-1271 rules, event reconstruction, monitoring, operator dashboard query panels, metadata rendering, and app security boundaries |
| Operator or deployer | [docs/deployment.md](docs/deployment.md), [deployments/README.md](deployments/README.md), [release-artifacts/README.md](release-artifacts/README.md), [docs/release-signatures.md](docs/release-signatures.md), [docs/incident-response.md](docs/incident-response.md), [docs/randomizer-operations.md](docs/randomizer-operations.md) | Admin ceremony, Safe/multisig handoff, signer setup, verification, dry-run mint, dry-run auction, and incident evidence |
| Contributor | [docs/first-30-minutes.md](docs/first-30-minutes.md), [CONTRIBUTING.md](CONTRIBUTING.md), [docs/tooling.md](docs/tooling.md), [docs/status.md](docs/status.md), [docs/known-blockers.md](docs/known-blockers.md), [ops/ROADMAP.md](ops/ROADMAP.md), [ops/EXECUTION_BACKLOG.md](ops/EXECUTION_BACKLOG.md) | Fresh setup, local checks, maturity boundaries, issue-ready backlog entries, and changelog policy |
| Protocol maintainer | [ops/ROADMAP.md](ops/ROADMAP.md), [ops/EXECUTION_BACKLOG.md](ops/EXECUTION_BACKLOG.md), [docs/release-policy.md](docs/release-policy.md), [docs/release-readiness.md](docs/release-readiness.md), [release-artifacts/latest/release-manifest.json](release-artifacts/latest/release-manifest.json), [release-artifacts/latest/SHA256SUMS](release-artifacts/latest/SHA256SUMS), [release-artifacts/latest/release-checksums.json](release-artifacts/latest/release-checksums.json) | Gate order, release-impacting changes, generated evidence, checksum coverage, and blocker status |

GitHub issue intake uses checked issue forms for [integration reports](.github/ISSUE_TEMPLATE/integration_report.yml),
[audit findings](.github/ISSUE_TEMPLATE/audit_finding.yml), and
[release evidence](.github/ISSUE_TEMPLATE/release_evidence.yml). Use
[SECURITY.md](SECURITY.md) instead of public issues for exploitable
vulnerabilities. Pull request intake uses a checked
[PR template](.github/PULL_REQUEST_TEMPLATE.md) for roadmap linkage, validation
evidence, release-impact classification, generated-artifact impact, and
breaking-change approval references.

## Drop Flow

1. TDH holders provide reputation to drops.
2. If a drop clears the selected network hurdle, it enters a pool.
3. Once a drop is in a pool, the configured TDH signer authorizes execution with
   EIP-712 typed data through EOA or ERC-1271 contract signatures.
4. A valid authorization can mint through fixed-price purchase or create an
   auction, subject to the remaining P0 safety blockers.

## Quickstart

Install Foundry `v1.7.1`, then run:

```bash
make check
```

The production-size step skips Foundry test and script contracts, compiles via
IR, and fails if deployable contracts exceed EIP-170 or EIP-3860 limits. The
local deployment rehearsal uses placeholder addresses; it proves the
deploy-and-wire ceremony can execute without production secrets, not that a
live deployment is ready.

The root README itself is part of the gate:

```bash
python scripts/test_readme.py
python scripts/check_readme.py
```

The checked fresh-contributor guide is also part of the gate:

```bash
python scripts/test_first_30_minutes.py
python scripts/check_first_30_minutes.py
```

The checked issue-template surface is part of the gate:

```bash
python scripts/test_issue_templates.py
python scripts/check_issue_templates.py
```

The checked PR-template surface is part of the gate:

```bash
python scripts/test_pr_template.py
python scripts/check_pr_template.py
```

The repository Markdown link surface is part of the gate:

```bash
python scripts/test_markdown_links.py
python scripts/check_markdown_links.py
```

The changelog gate requires release-impacting PRs to update
[CHANGELOG.md](CHANGELOG.md) under `Unreleased`; see
[docs/release-policy.md](docs/release-policy.md).

## Tooling

Tool versions, local checks, generated artifacts, and non-gating diagnostic
commands are documented in [docs/tooling.md](docs/tooling.md).

| Tool | Version |
| --- | --- |
| Foundry | `v1.7.1` |
| Solidity compiler | `0.8.19` |
| Slither | `0.11.5` |

## Repository Layout

| Path | Purpose |
| --- | --- |
| `smart-contracts/` | Solidity source |
| `test/` | Foundry tests |
| `script/` | Foundry scripts and local rehearsal tooling |
| `deployments/` | Deployment configs, schemas, example manifests, address books, ceremony evidence, and broadcast-retention templates |
| `release-artifacts/` | ABIs, bytecode checksums, interface IDs, event topic catalog, protocol surface report, source-verification inputs, ABI compatibility baseline, risk register, evidence reports, release manifest, and checksum bundle |
| `docs/` | Protocol, security, ADR, integration, deployment, release, and operator documentation |
| `ops/` | Roadmap, execution backlog, autonomous run state, and Slither baseline |

## Important Docs

- [CONTRIBUTING.md](CONTRIBUTING.md)
- [SECURITY.md](SECURITY.md)
- [ops/ROADMAP.md](ops/ROADMAP.md)
- [ops/EXECUTION_BACKLOG.md](ops/EXECUTION_BACKLOG.md)
- [ops/SLITHER_BASELINE.md](ops/SLITHER_BASELINE.md)
- [ops/AUTONOMOUS_RUN.md](ops/AUTONOMOUS_RUN.md)
- [docs/status.md](docs/status.md)
- [docs/first-30-minutes.md](docs/first-30-minutes.md)
- [docs/known-blockers.md](docs/known-blockers.md)
- [docs/tooling.md](docs/tooling.md)
- [docs/architecture.md](docs/architecture.md)
- [docs/threat-model.md](docs/threat-model.md)
- [docs/audit-package.md](docs/audit-package.md)
- [docs/adr/README.md](docs/adr/README.md)
- [docs/slither.md](docs/slither.md)
- [docs/deployment.md](docs/deployment.md)
- [docs/release-policy.md](docs/release-policy.md)
- [docs/release-signatures.md](docs/release-signatures.md)
- [docs/release-readiness.md](docs/release-readiness.md)
- [docs/monitoring.md](docs/monitoring.md)
- [docs/operator-dashboard-query-model.md](docs/operator-dashboard-query-model.md)
- [docs/public-beta-evidence.md](docs/public-beta-evidence.md)
- [docs/integrations/README.md](docs/integrations/README.md)
- [release-artifacts/README.md](release-artifacts/README.md)
- [release-artifacts/latest/release-manifest.json](release-artifacts/latest/release-manifest.json)
- [release-artifacts/latest/release-checksums.json](release-artifacts/latest/release-checksums.json)
- [.github/ISSUE_TEMPLATE/integration_report.yml](.github/ISSUE_TEMPLATE/integration_report.yml)
- [.github/ISSUE_TEMPLATE/audit_finding.yml](.github/ISSUE_TEMPLATE/audit_finding.yml)
- [.github/ISSUE_TEMPLATE/release_evidence.yml](.github/ISSUE_TEMPLATE/release_evidence.yml)
- [.github/PULL_REQUEST_TEMPLATE.md](.github/PULL_REQUEST_TEMPLATE.md)

## Security

Do not use these contracts for production drops until the public-beta and
production blocker reports are cleared or explicitly risk-accepted, the external
audit package is complete, release artifacts are signed, deployment addresses
are verified, and signer custody is operationally ready.

Report vulnerabilities through [SECURITY.md](SECURITY.md).
