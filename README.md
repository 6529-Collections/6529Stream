# 6529Stream

6529Stream is a set of Solidity smart contracts for 6529 NFT drops, including
fixed-price minting, auction flows, curator rewards, metadata generation, and
randomness adapters.

## Status

This repository is pre-audit and not production-ready.

The current CI and local smoke checks prove compilation, test command execution,
the production size gate, a local deployment rehearsal, deterministic
release-artifact catalog checks, ABI compatibility baseline checks, and
deterministic local deployment manifest/address-book/checksum-bundle checks,
plus retained source-verification inputs, a machine-readable release manifest,
architecture/threat-model checks, an audit-package check, a release-readiness
dashboard check, a public-beta evidence status check, and changelog gate for
release-impacting changes.
They do not prove protocol correctness or production deployment readiness.
Known P0 blockers, the execution roadmap, the release-readiness dashboard, and
the public-beta evidence status are tracked in
[`ops/ROADMAP.md`](ops/ROADMAP.md),
[`docs/release-readiness.md`](docs/release-readiness.md), and
[`docs/public-beta-evidence.md`](docs/public-beta-evidence.md).

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

The canonical smoke check runs:

```bash
forge build
forge test -vvv
forge build --sizes --via-ir --skip test --skip script --force
python scripts/test_release_artifacts.py
python scripts/generate_release_artifacts.py --check
python scripts/test_source_verification_inputs.py
python scripts/generate_source_verification_inputs.py --check
python scripts/test_abi_compatibility.py
python scripts/check_abi_compatibility.py --check
python scripts/test_deployment_manifest.py
python scripts/generate_deployment_manifest.py --check
python scripts/test_address_books.py
python scripts/generate_address_books.py --check
python scripts/test_ceremony_evidence.py
python scripts/check_ceremony_evidence.py
python scripts/test_randomizer_operations.py
python scripts/check_randomizer_operations.py
python scripts/test_release_signatures.py
python scripts/check_release_signatures.py
python scripts/test_public_beta_evidence.py
python scripts/check_public_beta_evidence.py
python scripts/test_public_beta_blocker_report.py
python scripts/generate_public_beta_blocker_report.py --check
python scripts/test_production_release_blocker_report.py
python scripts/generate_production_release_blocker_report.py --check
python scripts/test_architecture_threat_model.py
python scripts/check_architecture_threat_model.py
python scripts/test_audit_package.py
python scripts/check_audit_package.py
python scripts/test_release_readiness.py
python scripts/check_release_readiness.py
python scripts/test_release_manifest.py
python scripts/generate_release_manifest.py --check
python scripts/test_release_checksums.py
python scripts/generate_release_checksums.py --check
python scripts/test_changelog_check.py
python scripts/check_changelog.py
forge script script/RehearseDeployment.s.sol:RehearseDeployment --sig "run()" --via-ir
```

The size step is production-only: it skips Foundry test and script contracts,
compiles via IR, and fails if deployable contracts exceed EIP-170/EIP-3860
limits.

The deployment rehearsal step is local-only and uses placeholder addresses; it
proves the deploy-and-wire ceremony can execute without production secrets.

The release-artifact step verifies the committed ABI checksums, bytecode
checksums, interface IDs, and event topic catalog under
`release-artifacts/latest/` against the production `via-ir` build profile.

The source-verification step verifies
`release-artifacts/latest/source-verification-inputs.json`, which retains
production contract source hashes, compiler settings, constructor ABI,
bytecode/linking status, and verification command templates for future live
deployment verification.

The ABI compatibility step compares the current production contract ABI surface
against the committed baseline under `release-artifacts/baselines/` and fails on
removed or changed ABI entries while reporting additive entries.

The deployment manifest step verifies the generated local Anvil manifest under
`deployments/examples/` against committed manifest inputs and the current
release-artifact hashes.

The address-book step verifies compact generated address books under
`deployments/address-books/` against the committed deployment manifests.

The architecture/threat-model step verifies the auditor-facing system map and
trust-boundary model under [`docs/architecture.md`](docs/architecture.md) and
[`docs/threat-model.md`](docs/threat-model.md).

The release-manifest step verifies a deterministic top-level release manifest
under `release-artifacts/latest/release-manifest.json`. The manifest ties the
release-artifact catalog, ABI compatibility baseline, deployment manifests,
address books, governance docs including the architecture map, threat model,
and audit package, public-beta evidence status, and release-ceremony status
together for integrators and maintainers.

The audit-package step verifies the auditor-facing index under
[`docs/audit-package.md`](docs/audit-package.md). The package links scope,
accepted ADRs, invariants, Slither disposition, local deployment/release
evidence, known blockers, and security reporting in one place.

The release-readiness step verifies the Gate G dashboard under
[`docs/release-readiness.md`](docs/release-readiness.md). The dashboard
separates passing local evidence from missing fork/testnet/live evidence,
production signatures, signed tags, verified addresses, explorer verification,
external audit, and post-audit remediation blockers.

The public-beta evidence step verifies
[`release-artifacts/latest/public-beta-evidence.json`](release-artifacts/latest/public-beta-evidence.json)
against [`docs/public-beta-evidence.md`](docs/public-beta-evidence.md), keeping
public beta and production release blocked until retained non-local evidence or
explicit risk acceptance exists.
The generated blocker reports under
[`release-artifacts/latest/public-beta-blockers.md`](release-artifacts/latest/public-beta-blockers.md)
and
[`release-artifacts/latest/production-release-blockers.md`](release-artifacts/latest/production-release-blockers.md)
render the incomplete evidence rows into deterministic Markdown without
changing readiness claims.

The release-checksum step verifies the signable checksum bundle under
`release-artifacts/latest/` against the committed release artifacts,
deployment manifests, address books, artifact schemas, and release manifest.
The checksum bundle covers `release-manifest.json`; the manifest therefore
lists checksum-bundle digests as self-referentially unavailable instead of
embedding an impossible hash cycle. Detached signatures and signed tags remain
a release-ceremony follow-up.

The changelog step requires release-impacting PRs to update `CHANGELOG.md`
under `Unreleased`; see [`docs/release-policy.md`](docs/release-policy.md).

On Windows, install Python 3.8+ or the `py` launcher, then bootstrap and verify
with:

```powershell
powershell -ExecutionPolicy Bypass -File scripts\bootstrap-windows.ps1
powershell -ExecutionPolicy Bypass -File scripts\check.ps1
```

On Linux or EC2, bootstrap and verify with:

```bash
bash scripts/bootstrap-ec2.sh
make check
```

## Tooling

Tool versions and non-gating diagnostic commands are documented in
[`docs/tooling.md`](docs/tooling.md). The current Slither high/medium baseline
is tracked in [`ops/SLITHER_BASELINE.md`](ops/SLITHER_BASELINE.md).

Current pinned versions:

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
| `script/` | Foundry scripts |
| `deployments/` | Deployment manifest schema and examples |
| `release-artifacts/` | ABI checksum, bytecode checksum, interface ID, event topic catalog, source verification inputs, ABI compatibility baseline, public-beta evidence status, generated blocker reports, release manifest, and release checksum bundle |
| `docs/` | Project, security, ADR, and operational docs |
| `ops/` | Roadmap and execution state |

## Important Docs

- [`CONTRIBUTING.md`](CONTRIBUTING.md)
- [`SECURITY.md`](SECURITY.md)
- [`ops/ROADMAP.md`](ops/ROADMAP.md)
- [`ops/SLITHER_BASELINE.md`](ops/SLITHER_BASELINE.md)
- [`ops/AUTONOMOUS_RUN.md`](ops/AUTONOMOUS_RUN.md)
- [`docs/architecture.md`](docs/architecture.md)
- [`docs/threat-model.md`](docs/threat-model.md)
- [`docs/audit-package.md`](docs/audit-package.md)
- [`docs/release-readiness.md`](docs/release-readiness.md)
- [`docs/public-beta-evidence.md`](docs/public-beta-evidence.md)
- [`docs/status.md`](docs/status.md)
- [`docs/known-blockers.md`](docs/known-blockers.md)
- [`docs/tooling.md`](docs/tooling.md)
- [`docs/deployment.md`](docs/deployment.md)
- [`docs/release-policy.md`](docs/release-policy.md)
- [`docs/slither.md`](docs/slither.md)
