# Tooling

6529Stream currently uses a pinned Foundry smoke baseline.

## Versions

| Tool | Version |
| --- | --- |
| Foundry | `v1.7.1` |
| Solidity compiler | `0.8.19` |
| Slither | `0.11.5` |
| solc-select | `1.2.0` |

## Local Checks

Run the canonical Gate A smoke check:

```bash
make check
```

This runs:

```bash
forge build
forge test -vvv
forge snapshot --match-path test/StreamGasSnapshot.t.sol --check release-artifacts/baselines/v0.1.0/gas-snapshot.snap
forge build --sizes --via-ir --skip test --skip script --force
python scripts/test_drop_authorization_payload_generator.py
python scripts/generate_drop_authorization_payload.py --input test/fixtures/drop-authorization/payload-generator/fixed-price-input.json --output test/fixtures/drop-authorization/payload-generator/fixed-price-output.json --check
python scripts/generate_drop_authorization_payload.py --input test/fixtures/drop-authorization/payload-generator/auction-input.json --output test/fixtures/drop-authorization/payload-generator/auction-output.json --check
python scripts/test_drop_authorization_fixtures.py
python scripts/check_drop_authorization_fixtures.py
python scripts/test_drop_authorization_signing_evidence.py
python scripts/check_drop_authorization_signing_evidence.py
python scripts/test_signer_custody_readiness.py
python scripts/check_signer_custody_readiness.py
python scripts/test_release_artifacts.py
python scripts/generate_release_artifacts.py --check
python scripts/test_source_verification_inputs.py
python scripts/generate_source_verification_inputs.py --check
python scripts/test_abi_compatibility.py
python scripts/check_abi_compatibility.py --check
python scripts/test_broadcast_manifest_input.py
python scripts/generate_broadcast_manifest_input.py --check
python scripts/test_deployment_manifest.py
python scripts/generate_deployment_manifest.py --check
python scripts/generate_deployment_manifest.py --config deployments/config/anvil-6529stream-v0.1.0-001-broadcast.json --check
python scripts/test_address_books.py
python scripts/generate_address_books.py --check
python scripts/test_ceremony_evidence.py
python scripts/check_ceremony_evidence.py
python scripts/test_randomizer_operations.py
python scripts/check_randomizer_operations.py
python scripts/test_release_signatures.py
python scripts/check_release_signatures.py
python scripts/test_non_local_release_evidence.py
python scripts/check_non_local_release_evidence.py
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
python scripts/test_incident_response.py
python scripts/check_incident_response.py
python scripts/test_release_readiness.py
python scripts/check_release_readiness.py
python scripts/test_release_manifest.py
python scripts/generate_release_manifest.py --check
python scripts/test_release_checksums.py
python scripts/generate_release_checksums.py --check
python scripts/test_changelog_check.py
python scripts/check_changelog.py
forge script script/RehearseDeployment.s.sol:RehearseDeployment --sig "run()" --via-ir
forge script script/RehearseAuctionCeremony.s.sol:RehearseAuctionCeremony --sig "run()" --via-ir
forge script script/RehearseEmergencyRedeployment.s.sol:RehearseEmergencyRedeployment --sig "run()" --via-ir
```

The size step is the production deployability gate. It skips test and script
contracts so non-production artifacts do not pollute EIP-170/EIP-3860 evidence,
and it uses `via_ir` because the current deployable `StreamCore` release profile
needs the IR optimizer to fit under the runtime limit.

The deployment rehearsal step is the first Gate E local ceremony gate. It uses
non-secret placeholder addresses, deploys the current contract stack, wires the
minter/drops/auction/randomizer surfaces, transfers Ownable control to the Safe
placeholder, and runs a local auction ceremony from signed auction drop through
bid, settlement, proceeds withdrawal, and zero-owed accounting. It also runs a
local emergency redeployment rehearsal that proves distinct old/replacement
deployment versions, manifests, drop domains, contract addresses, Safe ceremony
state, and replacement fixed-price mint smoke. It leaves fork/testnet
broadcasting and retained live ceremony evidence for later Gate E work.

The drop authorization tooling step validates both signed no-secret fixtures
and unsigned payload-generator examples. The generator produces canonical
EIP-712 typed data plus derived hashes for downstream signer comparison; it
does not accept key material, does not sign, does not broadcast, and does not
replace production signer custody or retained non-local signing evidence.
The drop authorization signing evidence checker validates the retained
evidence template under `release-artifacts/drop-authorization-signing/`, ties
it to the generated unsigned payload hash and derived digest fields, and
rejects placeholder signer/signature states for non-local evidence.
The signer custody readiness checker validates the no-secret template under
`release-artifacts/signer-custody-readiness/`, ties runbook and retained
artifact references to current hashes, and rejects non-local placeholder
signer custody, signer-service, lifecycle, monitoring, reviewer, path, and
secret-shaped states.

The release artifact step is the first Gate G machine-readable artifact gate.
It verifies that `release-artifacts/latest/` matches the production `via-ir`
Foundry build output, including ABI checksums, bytecode checksums, interface
IDs, and the event topic catalog. The generator automatically finds Foundry's
`cast` in `~/.foundry/bin` when the shell has not added it to `PATH`.

The source-verification step generates and checks
`release-artifacts/latest/source-verification-inputs.json` from the production
Foundry artifacts, source files, compiler settings, and contract config. It
retains source hashes, constructor ABI, bytecode/linking status, and
`forge verify-contract` command templates without claiming live explorer
verification before a broadcast deployment exists.

The ABI compatibility step compares the current production contract ABI surface
against `release-artifacts/baselines/v0.1.0/abi-surface.json`. It fails on
removed or changed functions, events, custom errors, constructors, fallback, or
receive entries. Additive entries are reported as compatible for this first
baseline so maintainers can pair them with release notes and version policy.

The broadcast manifest input step parses the sanitized Foundry fixture under
`deployments/broadcasts/`, rejects wrong-chain, failed-receipt,
missing-contract, unexpected-contract, duplicate, invalid-address, and
secret-like-key inputs, and checks the generated broadcast-derived config under
`deployments/config/`.

The deployment manifest step generates the local Anvil example from
`deployments/config/anvil-6529stream-v0.1.0-001.json`, fills contract ABI and
runtime bytecode hashes from `release-artifacts/latest/abi-checksums.json`,
generates the sanitized broadcast-derived manifest from
`deployments/config/anvil-6529stream-v0.1.0-001-broadcast.json`, and checks that
both committed examples have not drifted.

The address-book step projects committed deployment manifests into compact
integrator-facing JSON under `deployments/address-books/`. Address books keep
network/release metadata, source manifest checksums, contract addresses, source
paths, ABI hashes, runtime bytecode hashes, and verification status without the
full ceremony and constructor-argument details from deployment manifests. They
follow `deployments/schema/address-book.schema.json`, normalize addresses to
lowercase, and are regenerated with `python scripts/generate_address_books.py`.

The ceremony-evidence step validates retained no-secret deployment evidence
bundles under `deployments/ceremony-evidence/`. The committed Anvil bundle ties
local deployment/admin/signer, metadata-browser, auction, emergency
redeployment, verification, artifact-retention, and redaction evidence together
against `deployments/schema/ceremony-evidence.schema.json`; fork/testnet/live
evidence contents remain later Gate E work.

The release-manifest step builds
`release-artifacts/latest/release-manifest.json`, a deterministic top-level
index over the committed release artifact catalog, ABI compatibility baseline,
deployment manifests, address books, deployment schemas, ceremony evidence,
changelog, governance docs, incident-response runbook, the audit package, and
unavailable release-ceremony artifacts. It is regenerated with
`python scripts/generate_release_manifest.py` after any covered input changes.

The architecture/threat-model step validates [`architecture.md`](architecture.md)
and [`threat-model.md`](threat-model.md), the auditor-facing map of system
components, trust boundaries, value/custody flows, threat categories, residual
risks, and evidence links.

The audit-package step validates [`audit-package.md`](audit-package.md), the
single auditor-facing index over maturity, scope, ADRs, tests, static analysis,
deployment/release evidence, known blockers, accepted local-baseline
dispositions, and security reporting.

The incident-response step validates
[`incident-response.md`](incident-response.md), the no-secret operator runbook
for stuck auctions, failed randomness, bad Merkle roots, bad metadata or
dependency configuration, signer compromise, and release artifact/evidence
mistakes.

The drop-authorization fixture step validates
[`drop-authorization-signing.md`](drop-authorization-signing.md) and the
deterministic no-secret fixtures under
[`test/fixtures/drop-authorization/`](../test/fixtures/drop-authorization/).
It recomputes `dropId`, token-data hash, domain separator, struct hash, and
EIP-712 digest for the fixed-price EOA, auction EOA, and ERC-1271 mock
contract-signer examples.
The drop authorization signing evidence step validates the schema, checked
template, retained artifact hash, generated payload reference, signer epoch,
review metadata, signature status, path boundaries, and no-secret policy for
future signing ceremonies.
The signer custody readiness step validates the schema, checked template,
retained artifact hash, signer manager, signer epoch source, custody owner,
ERC-1271 support status, rotation/revocation drill status, monitoring/runbook
links, reviewer metadata, path boundaries, and no-secret policy for future
signer custody ceremonies.

The release-readiness step validates
[`release-readiness.md`](release-readiness.md), the Gate G dashboard that
separates passing local evidence from missing fork/testnet/live evidence,
production signatures, signed Git tags, verified deployed addresses, explorer
verification, external audit, and post-audit remediation blockers.

The public-beta evidence step validates
[`public-beta-evidence.md`](public-beta-evidence.md) and
`release-artifacts/latest/public-beta-evidence.json`, the no-secret status
manifest that keeps public beta and production release blocked until retained
non-local evidence or explicit risk acceptance exists.
The generated public-beta and production-release blocker reports render that
manifest into deterministic Markdown under `release-artifacts/latest/`, with
the production-focused report linking each production requirement to its
checked template under `release-artifacts/evidence/production-release-templates/`.
The non-local release evidence intake runbook in
[`non-local-release-evidence.md`](non-local-release-evidence.md) defines the
operator workflow, required retained fields, redaction rules, reviewer
expectations, and public-beta requirement mapping for the fork, testnet, live,
audit, explorer, gas, invariant, signature, and signed-tag evidence that will
eventually unblock those status rows.
The non-local release evidence checker validates
`release-artifacts/evidence/non-local-release-evidence-template.json` against
`release-artifacts/schema/non-local-release-evidence.schema.json`, validates
every checked public-beta template under
`release-artifacts/evidence/public-beta-templates/`, validates every checked
production-release template under
`release-artifacts/evidence/production-release-templates/`, confirms retained
artifact hashes, rejects secret-shaped metadata, and lets future reviewed
evidence become release-manifest and checksum inputs without treating templates
as completion evidence.

The release-checksum step builds `release-artifacts/latest/SHA256SUMS` and
`release-artifacts/latest/release-checksums.json` from the committed release
artifact, public-beta evidence, deployment manifest, address-book, schema,
ceremony-evidence, and release-manifest outputs. This gives maintainers a
deterministic, signable checksum bundle. The
release manifest intentionally marks checksum-bundle digests as
`not_available_self_referential` because the checksum bundle covers
`release-manifest.json`; embedding the final bundle digest in that covered file
would create a hash cycle. Detached signatures and signed git tags still
require a release ceremony and are not produced by the local smoke gate.

The changelog gate checks release-impacting paths against `CHANGELOG.md`. If a
branch changes contract surfaces, release artifacts, deployment artifacts, or
release workflow files, `CHANGELOG.md` must be part of the change and its
`Unreleased` section must contain a non-placeholder bullet. The release-impact
rules are documented in [`release-policy.md`](release-policy.md).

Windows contributors can run:

```powershell
powershell -ExecutionPolicy Bypass -File scripts\check.ps1
```

The Windows script prepends `%USERPROFILE%\.foundry\bin` to the current process
`PATH` so a fresh shell can find `forge` after bootstrap.

## Bootstrap

Linux or EC2:

```bash
bash scripts/bootstrap-ec2.sh
```

Windows PowerShell:

```powershell
powershell -ExecutionPolicy Bypass -File scripts\bootstrap-windows.ps1
```

Windows bootstrap requires Python 3.8+ or the `py` launcher for the local
Slither and `solc-select` tool environment. Foundry itself is downloaded from
the pinned release asset and verified with SHA256 before extraction.

## Release Artifacts

After changing any production contract ABI or event surface, run the production
build and regenerate the tracked release baseline with:

```bash
forge build --sizes --via-ir --skip test --skip script --force
forge snapshot --match-path test/StreamGasSnapshot.t.sol --snap release-artifacts/baselines/v0.1.0/gas-snapshot.snap
python scripts/generate_release_artifacts.py
python scripts/generate_source_verification_inputs.py
python scripts/check_abi_compatibility.py
python scripts/generate_broadcast_manifest_input.py
python scripts/generate_deployment_manifest.py
python scripts/generate_deployment_manifest.py --config deployments/config/anvil-6529stream-v0.1.0-001-broadcast.json
python scripts/generate_address_books.py
python scripts/test_ceremony_evidence.py
python scripts/check_ceremony_evidence.py
python scripts/check_randomizer_operations.py
python scripts/check_release_signatures.py
python scripts/test_non_local_release_evidence.py
python scripts/check_non_local_release_evidence.py
python scripts/check_public_beta_evidence.py
python scripts/generate_public_beta_blocker_report.py
python scripts/generate_production_release_blocker_report.py
python scripts/check_architecture_threat_model.py
python scripts/check_audit_package.py
python scripts/test_incident_response.py
python scripts/check_incident_response.py
python scripts/test_drop_authorization_payload_generator.py
python scripts/generate_drop_authorization_payload.py --input test/fixtures/drop-authorization/payload-generator/fixed-price-input.json --output test/fixtures/drop-authorization/payload-generator/fixed-price-output.json --check
python scripts/generate_drop_authorization_payload.py --input test/fixtures/drop-authorization/payload-generator/auction-input.json --output test/fixtures/drop-authorization/payload-generator/auction-output.json --check
python scripts/test_drop_authorization_fixtures.py
python scripts/check_drop_authorization_fixtures.py
python scripts/test_drop_authorization_signing_evidence.py
python scripts/check_drop_authorization_signing_evidence.py
python scripts/test_signer_custody_readiness.py
python scripts/check_signer_custody_readiness.py
python scripts/check_release_readiness.py
python scripts/generate_release_manifest.py
python scripts/generate_release_checksums.py
python scripts/check_changelog.py
```

The check mode is:

```bash
python scripts/generate_release_artifacts.py --check
forge snapshot --match-path test/StreamGasSnapshot.t.sol --check release-artifacts/baselines/v0.1.0/gas-snapshot.snap
python scripts/generate_source_verification_inputs.py --check
python scripts/check_abi_compatibility.py --check
python scripts/generate_broadcast_manifest_input.py --check
python scripts/generate_deployment_manifest.py --check
python scripts/generate_deployment_manifest.py --config deployments/config/anvil-6529stream-v0.1.0-001-broadcast.json --check
python scripts/generate_address_books.py --check
python scripts/test_ceremony_evidence.py
python scripts/check_ceremony_evidence.py
python scripts/check_randomizer_operations.py
python scripts/check_release_signatures.py
python scripts/test_non_local_release_evidence.py
python scripts/check_non_local_release_evidence.py
python scripts/check_public_beta_evidence.py
python scripts/generate_public_beta_blocker_report.py --check
python scripts/generate_production_release_blocker_report.py --check
python scripts/check_architecture_threat_model.py
python scripts/check_audit_package.py
python scripts/test_incident_response.py
python scripts/check_incident_response.py
python scripts/test_drop_authorization_payload_generator.py
python scripts/generate_drop_authorization_payload.py --input test/fixtures/drop-authorization/payload-generator/fixed-price-input.json --output test/fixtures/drop-authorization/payload-generator/fixed-price-output.json --check
python scripts/generate_drop_authorization_payload.py --input test/fixtures/drop-authorization/payload-generator/auction-input.json --output test/fixtures/drop-authorization/payload-generator/auction-output.json --check
python scripts/test_drop_authorization_fixtures.py
python scripts/check_drop_authorization_fixtures.py
python scripts/test_drop_authorization_signing_evidence.py
python scripts/check_drop_authorization_signing_evidence.py
python scripts/test_signer_custody_readiness.py
python scripts/check_signer_custody_readiness.py
python scripts/check_release_readiness.py
python scripts/generate_release_manifest.py --check
python scripts/generate_release_checksums.py --check
python scripts/check_changelog.py
```

The generator uses `release-artifacts/contracts.json` to define the production
contract and interface surface. Standard ERC interface IDs are pinned there when
the advertised ERC ID differs from a raw XOR over the artifact ABI.

The ABI compatibility baseline uses the production contract set from the same
config file. Refresh it only when maintainers intentionally accept a release
surface change; removed or changed entries should also update the breaking
change documentation and release notes.

The gas snapshot baseline lives at
`release-artifacts/baselines/v0.1.0/gas-snapshot.snap`. Refresh it only when
maintainers intentionally accept changed gas for the focused Gate D operations:
fixed-price mint, auction bid, auction settlement, curator claim, final
on-chain `tokenURI`, and dependency/script reads.

The deployment manifest generator uses committed inputs under
`deployments/config/`. The broadcast-derived input is generated first from the
sanitized Foundry broadcast fixture under `deployments/broadcasts/`. Manifest
checksums are the SHA-256 of canonical JSON with
`release_artifacts.manifest_sha256` normalized to `sha256:` plus 64 zeroes,
which avoids a self-referential checksum while making manifest drift
machine-detectable.

The address-book generator reads committed deployment manifests and
`release-artifacts/latest/abi-checksums.json`. Refresh address books after
deployment manifests change; the `--check` mode fails on stale output, invalid
or duplicate contract addresses, missing contract metadata, or mismatch against
the release artifact contract set.

The release-checksum generator covers `release-artifacts/contracts.json`,
`release-artifacts/evidence/`,
`release-artifacts/drop-authorization-signing/`,
`release-artifacts/signer-custody-readiness/`,
`release-artifacts/schema/`,
`release-artifacts/latest/public-beta-evidence.json`,
`release-artifacts/latest/`, `release-artifacts/baselines/`,
`deployments/broadcasts/`, `deployments/config/`, `deployments/examples/`,
`deployments/address-books/`, `deployments/ceremony-evidence/`,
`deployments/randomizer-operations/`, `deployments/schema/`, and
`test/fixtures/drop-authorization/`, excluding its own generated checksum files
to avoid self-referential hashes. Refresh the release manifest before
refreshing the checksum bundle after changing any covered artifact.

## Non-Gating Diagnostics

These commands are intentionally not part of `make check` yet:

```bash
make fmt-check
make slither
```

`make slither` runs:

```bash
slither . --config-file slither.config.json --foundry-compile-all
```

The current Slither high/medium baseline is tracked in
[`ops/SLITHER_BASELINE.md`](../ops/SLITHER_BASELINE.md). Slither exits non-zero
while findings exist; that is expected until the baseline is accepted as a CI
gate.

Formatting and Slither have known baselines and should become gates only after
the roadmap items for formatting triage and Slither baseline acceptance land.
See [`docs/slither.md`](slither.md) for the full Slither workflow.
