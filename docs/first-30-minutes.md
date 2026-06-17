# First 30 Minutes

This guide is the fresh-contributor path for 6529Stream. It turns a new
checkout into a useful local validation run without production secrets and
without overstating what the current repository proves.

6529Stream is pre-audit and not production-ready. The local gate proves that
the checked build, tests, scripts, documentation validators, release artifact
generators, and deployment rehearsals can execute from this checkout. It does
not prove protocol correctness, public-beta readiness, production readiness, or
external audit completion.

## What This Guide Proves

A successful first-30-minutes run proves:

- the pinned Foundry, Solidity, Python, and optional Slither expectations are
  visible to a new contributor;
- `forge build`, `forge test -vvv`, and the canonical local gate can run;
- Windows contributors have a PowerShell wrapper instead of needing a Unix
  `make` environment;
- known warning noise is documented before a contributor mistakes it for a new
  failure;
- generated artifact drift is visible before a PR reaches CI;
- docs-only and Solidity/test contributors can choose the smallest honest
  validation path for their change.

This guide does not authorize production drops, live deployment, private key
use, release signing, signer custody, or external audit claims. Those gates are
tracked in [docs/status.md](status.md), [docs/release-readiness.md](release-readiness.md),
[docs/known-blockers.md](known-blockers.md), [ops/ROADMAP.md](../ops/ROADMAP.md),
and [ops/EXECUTION_BACKLOG.md](../ops/EXECUTION_BACKLOG.md).

## Prerequisites

Install or verify:

- Git.
- Foundry `v1.7.1`, with `forge` and `cast` available either on `PATH` or under
  the normal Foundry install directory.
- Solidity compiler `0.8.19`, resolved through Foundry for this repo.
- Python 3.8 or newer.
- PowerShell for Windows local checks.
- Slither `0.11.5` only when you need static-analysis parity with the reviewed
  baseline.

Bootstrap helpers are available for common local setup:

```bash
bash scripts/bootstrap-ec2.sh
```

```powershell
powershell -ExecutionPolicy Bypass -File scripts\bootstrap-windows.ps1
```

The bootstrap helpers are convenience setup, not a substitute for reading the
current tool expectations in [docs/tooling.md](tooling.md).

## Clone And Verify Tools

Clone the repository and enter the checkout:

```bash
git clone https://github.com/6529-Collections/6529Stream.git
cd 6529Stream
```

Verify the tools before running the full gate:

```bash
forge --version
python --version
```

On Linux and macOS, `python3 --version` may be the available command instead:

```bash
python3 --version
```

If `forge` is not on `PATH`, install or update Foundry and reopen the shell:

```bash
curl -L https://foundry.paradigm.xyz | bash
foundryup --version v1.7.1
```

Review the upstream installer before piping it into a shell, or use the
installation method already approved by your development environment.

On Windows, also check the normal Foundry user-bin directory if the shell cannot
find `forge`:

```powershell
$env:USERPROFILE + "\.foundry\bin"
```

The repository `Makefile` prepends the usual Foundry install directory for
local gates, but a fresh contributor should still be able to explain which
Foundry version they are using in a PR.

## Run The Local Gate

Start with the direct Foundry smoke commands when diagnosing setup:

```bash
forge build
forge test -vvv
```

Then run the canonical local gate:

```bash
make check
```

On Windows PowerShell, run the checked wrapper:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\check.ps1
```

The Windows wrapper exists so Windows contributors do not need to prove a Unix
`make` environment before they can prove the repository gate. The Unix shell
entrypoint is [scripts/check.sh](../scripts/check.sh), and the PowerShell
entrypoint is [scripts/check.ps1](../scripts/check.ps1).

## Choose A Contribution Path

For docs-only changes, run the checker for the document you touched, then run
the shared documentation and release-impact checks:

```bash
python scripts/test_first_30_minutes.py
python scripts/check_first_30_minutes.py
python scripts/test_readme.py
python scripts/check_readme.py
python scripts/test_release_manifest.py
python scripts/generate_release_manifest.py --check
python scripts/test_release_checksums.py
python scripts/generate_release_checksums.py --check
python scripts/check_changelog.py
```

For Solidity or Foundry test changes, run the relevant focused test, the direct
Foundry smoke, and the size-sensitive gates:

```bash
forge test -vvv --match-path test/StreamCoreBurn.t.sol
forge build
forge test -vvv
forge snapshot --match-path test/StreamGasSnapshot.t.sol --check release-artifacts/baselines/v0.1.0/gas-snapshot.snap
python scripts/run_forge_size_log.py --log cache/forge-size.log
python scripts/check_contract_size_budget.py
python scripts/check_core_bytecode_spend_policy.py
```

For release-artifact or generated-evidence changes, regenerate and check the
affected artifacts in dependency order:

```bash
python scripts/generate_risk_register.py
python scripts/generate_public_beta_blocker_report.py
python scripts/generate_production_release_blocker_report.py
python scripts/generate_release_notes.py
python scripts/generate_release_manifest.py
python scripts/generate_bytecode_release_proof.py
python scripts/generate_release_checksums.py
```

When in doubt, finish with `make check` or the Windows wrapper before opening
a PR. Every PR should also update [CHANGELOG.md](../CHANGELOG.md) when it has
release impact, setup impact, public docs impact, generated-artifact impact, or
integration impact. The full contribution policy is in
[CONTRIBUTING.md](../CONTRIBUTING.md).

If you are opening an issue instead of a PR, use the checked GitHub forms for
[integration reports](../.github/ISSUE_TEMPLATE/integration_report.yml),
[audit findings](../.github/ISSUE_TEMPLATE/audit_finding.yml), or
[release evidence](../.github/ISSUE_TEMPLATE/release_evidence.yml) when one of
those scopes fits.

## Generated Artifact Drift

Many repository files are deterministic release evidence, not hand-written
notes. If a PR changes roadmap, risk, release, integration, ABI, bytecode,
deployment, signing, evidence, docs, or checker coverage, expect one or more of
these generated files to drift:

- `release-artifacts/latest/risk-register.json`
- `release-artifacts/latest/public-beta-blockers.md`
- `release-artifacts/latest/production-release-blockers.md`
- `release-artifacts/latest/release-notes.json`
- `release-artifacts/latest/release-notes.md`
- `release-artifacts/latest/release-manifest.json`
- `release-artifacts/latest/bytecode-release-proof.json`
- `release-artifacts/latest/SHA256SUMS`
- `release-artifacts/latest/release-checksums.json`

Regenerate the upstream artifact first, then regenerate the release manifest,
bytecode release proof, and checksum bundle last. A clean checker run is better
evidence than a manually edited generated file.

## Known Warning Noise

Current local runs can still show known and reviewed warning noise. Treat new
or changed warnings as real until the relevant checker or baseline proves
otherwise.

Known examples include:

- Solidity compiler warnings captured by [docs/warning-dispositions.md](warning-dispositions.md).
- Foundry trace-source warnings during some script and test execution.
- Missing Etherscan configuration warnings for local-only rehearsal commands.
- Predeploy-linked library warnings in deployment rehearsal output.
- An existing Windows line-ending warning from `git diff --check` on
  `scripts/check.ps1` in some local shells.

The warning-disposition gate checks reviewed compiler-warning rows against a
retained forge-size log:

```bash
python scripts/run_forge_size_log.py --log cache/forge-size.log
python scripts/check_warning_dispositions.py --solc-warnings-log cache/forge-size.log
```

## Troubleshooting

If `forge` is not found, install Foundry, run `foundryup --version v1.7.1`,
then reopen the shell or add the Foundry user-bin directory to `PATH`.

If `make` is not available on Windows, use the PowerShell wrapper instead of
rewriting Makefile commands by hand:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\check.ps1
```

If Python commands fail, verify whether the shell expects `python` or `python3`
and rerun the exact checker command with the available executable.

If release manifest or checksum checks fail after a docs or roadmap change,
regenerate in this order:

```bash
python scripts/generate_risk_register.py
python scripts/generate_release_notes.py
python scripts/generate_release_manifest.py
python scripts/generate_bytecode_release_proof.py
python scripts/generate_release_checksums.py
```

If CI reports a missing changelog entry, update the `Unreleased` section of
[CHANGELOG.md](../CHANGELOG.md) or explain why the PR is not release-impacting.

## No Secrets And Maturity Boundaries

Local Anvil, fork templates, retained evidence templates, integration fixtures,
and release-artifact examples are no-secret artifacts. Do not commit private
keys, seed phrases, RPC credentials, signer material, WalletConnect project
secrets, production deployment secrets, private marketplace credentials, or
unredacted transaction-broadcast material.

Public beta remains blocked until reviewed fork/testnet or live deployment
rehearsal, verified addresses, explorer verification, signer custody readiness,
production signing, signed release artifacts, and live metadata/indexer/
marketplace evidence exist. Production release remains blocked until external
audit, post-audit remediation, signed release tag ceremony, and release-mode
evidence are accepted. See [README.md](../README.md), [docs/status.md](status.md),
and [docs/release-readiness.md](release-readiness.md) before making any
readiness claim.
