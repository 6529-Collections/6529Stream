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
- Production signer identity or custody completion, detached checksum
  signatures, or signed release tags.
- A completed external audit report.
- Any private key, mnemonic, RPC URL, API key, or unreleased drop payload.
- A claim that the current local gates prove production safety.

## Current Protocol Snapshot

Use this snapshot to separate implemented local evidence from external evidence
gaps before reading the detailed roadmap.

| Area | Current local evidence | Still open before public beta or production |
| --- | --- | --- |
| Drop authorization | EIP-712 fixed-price and auction authorization, storage-backed replay controls, signer epochs, per-drop cancellation, EOA signatures, compact signatures, and ERC-1271 contract-signer paths are covered by Foundry tests and no-secret signing fixtures | Reviewed production signer custody, production signing service evidence, retained non-local signing evidence, and signed production payload ceremonies |
| Auction and payments | Auction escrow custody, active-bid accounting, outbid bidder credits, no-bid and with-bid settlement, failed withdrawal rollback, fixed-price pull credits, curator credits, emergency-withdrawable surplus, and forced-ETH invariants are covered locally | Fork/testnet/live auction, withdrawal, and value-flow evidence; any future shared-ledger ADR or production payment operations evidence |
| Randomness and metadata | VRF/arRNG request lifecycle, stale/failed/retry states, raw-output hashes, provider/epoch validation, metadata golden files, UTF-8/URI/attribute guards, ERC-4906 signaling, freeze manifests, burn semantics, and browser-sandbox fixture execution are covered locally | Fork/testnet/live randomizer provider funding, request-health, metadata browser, and final drop-output evidence |
| Deployment and release | Local Anvil deployment, auction ceremony, emergency redeployment, ceremony evidence, randomizer operations evidence, release manifest, source verification inputs, address books, checksum bundle, signed release tag gate, and bytecode-to-release proof exist | Testnet/live deployment rehearsal, live explorer verification, production address books, production checksum signatures, live bytecode proof, reviewed admin ceremony evidence, and post-audit remediation |
| 1/1 product excellence | Roadmap/backlog now track contract-level metadata, 1/1 provenance, royalty philosophy, collector-verifiable permanence, marketplace/indexer evidence, Core size discipline, and warning hygiene as explicit release work | Accepted design decisions, implementation where chosen, marketplace/indexer retained evidence, and final collector-facing release artifacts |

Reviewer note: the clean-main rebaseline confirmed the core "serious contract"
surfaces are largely implemented locally. The audit package should therefore
focus on validating correctness, adversarial completeness, external evidence
gaps, retained artifact integrity, and whether any accepted product/operations
deferrals are appropriate for launch.

## Reviewer Entry Points

| Purpose | Entry point |
| --- | --- |
| Project overview | [`README.md`](../README.md) |
| Architecture map | [`docs/architecture.md`](architecture.md) |
| Threat model | [`docs/threat-model.md`](threat-model.md) |
| Current maturity and evidence | [`docs/status.md`](status.md) |
| Known unresolved blockers | [`docs/known-blockers.md`](known-blockers.md) |
| Release-readiness dashboard | [`docs/release-readiness.md`](release-readiness.md) |
| Canonical release risk register | [`release-artifacts/latest/risk-register.json`](../release-artifacts/latest/risk-register.json) |
| Incident response runbook | [`docs/incident-response.md`](incident-response.md) |
| Drop authorization signing fixtures, unsigned payload tooling, and signing evidence | [`docs/drop-authorization-signing.md`](drop-authorization-signing.md) |
| Signer custody readiness evidence | [`docs/signer-custody-readiness.md`](signer-custody-readiness.md) |
| Public-beta evidence status | [`docs/public-beta-evidence.md`](public-beta-evidence.md) |
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
- [`docs/drop-authorization-signing.md`](drop-authorization-signing.md)
- [`docs/signer-custody-readiness.md`](signer-custody-readiness.md)
- [`docs/deployment.md`](deployment.md)
- [`docs/release-policy.md`](release-policy.md)
- [`docs/incident-response.md`](incident-response.md)
- [`docs/release-signatures.md`](release-signatures.md)
- [`docs/public-beta-evidence.md`](public-beta-evidence.md)
- [`docs/release-readiness.md`](release-readiness.md)

## Invariants And Test Evidence

The current tests are regression tripwires and local invariant baselines. They
should be treated as audit evidence to inspect, not as exhaustive proof.

| Evidence area | Current evidence |
| --- | --- |
| Payment accounting and reserves | [`test/StreamPaymentsInvariant.t.sol`](../test/StreamPaymentsInvariant.t.sol) |
| Supply, replay, burn, and freeze state | [`test/StreamSupplyReplayFreezeInvariant.t.sol`](../test/StreamSupplyReplayFreezeInvariant.t.sol) |
| Auction custody and proceeds consistency | [`test/StreamAuctionInvariant.t.sol`](../test/StreamAuctionInvariant.t.sol) |
| End-to-end protocol state machine | [`test/StreamProtocolStateMachine.t.sol`](../test/StreamProtocolStateMachine.t.sol) |
| Signer compromise and revocation sequences | [`test/StreamSignerCompromiseFuzz.t.sol`](../test/StreamSignerCompromiseFuzz.t.sol) |
| Pause and settlement matrix | [`test/StreamPauseControls.t.sol`](../test/StreamPauseControls.t.sol) |
| Randomizer reserve lifecycle | [`test/StreamRandomizerPayments.t.sol`](../test/StreamRandomizerPayments.t.sol) |
| Deployment, manifest, and ceremony smoke tests | [`test/StreamDeploymentManifest.t.sol`](../test/StreamDeploymentManifest.t.sol) |
| Bytecode proof and checksum coverage | [`scripts/generate_bytecode_release_proof.py`](../scripts/generate_bytecode_release_proof.py), [`scripts/check_signed_release_tag.py`](../scripts/check_signed_release_tag.py) |
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
- [`release-artifacts/latest/source-verification-inputs.json`](../release-artifacts/latest/source-verification-inputs.json)
  records source, artifact, compiler, constructor, and verification-command
  inputs for the current local/fork release artifacts.
- [`release-artifacts/latest/bytecode-release-proof.json`](../release-artifacts/latest/bytecode-release-proof.json)
  is the bytecode-to-release proof. It ties committed local/fork address books,
  deployment manifests, ABI checksums, source verification inputs, compiler
  settings, runtime bytecode hashes, and creation bytecode hashes to the current
  release manifest. It does not query live chain bytecode or claim production
  verification.
- [`release-artifacts/latest/SHA256SUMS`](../release-artifacts/latest/SHA256SUMS)
  is the signable checksum bundle for covered release and deployment artifacts.
- [`release-artifacts/latest/release-checksums.json`](../release-artifacts/latest/release-checksums.json)
  is the machine-readable checksum bundle and includes the bytecode-to-release
  proof even though the proof is intentionally not embedded into the release
  manifest to avoid a manifest/proof hash cycle.
- [`release-artifacts/latest/risk-register.json`](../release-artifacts/latest/risk-register.json)
  is the generated risk register for launch blockers, accepted local-baseline
  risks, and planned mitigations. Its source-document and evidence hashes are
  validated by [`scripts/check_risk_register.py`](../scripts/check_risk_register.py)
  and refreshed by
  [`scripts/generate_risk_register.py`](../scripts/generate_risk_register.py).
  The schema is retained at
  [`release-artifacts/schema/risk-register.schema.json`](../release-artifacts/schema/risk-register.schema.json),
  and the focused regression suite lives in
  [`scripts/test_risk_register.py`](../scripts/test_risk_register.py).
- [`release-artifacts/signatures/anvil-6529stream-v0.1.0-001-local.json`](../release-artifacts/signatures/anvil-6529stream-v0.1.0-001-local.json)
  records local placeholder signature evidence and the self-referential
  manifest/checksum boundary.
- [`scripts/check_signed_release_tag.py`](../scripts/check_signed_release_tag.py)
  is the signed release tag verifier. Ordinary local/CI runs stay in
  non-release mode, while production release mode requires a safe signed tag,
  tag-to-HEAD match, current checksum bundle, and matching reviewed signature
  evidence.
- [`release-artifacts/latest/public-beta-evidence.json`](../release-artifacts/latest/public-beta-evidence.json)
  records the no-secret public-beta evidence status and keeps public beta and
  production release blocked until non-local evidence is retained.
- [`release-artifacts/latest/public-beta-blockers.md`](../release-artifacts/latest/public-beta-blockers.md)
  and
  [`release-artifacts/latest/production-release-blockers.md`](../release-artifacts/latest/production-release-blockers.md)
  render the current public-beta and production blocker reports from
  machine-readable evidence status.
- [`docs/drop-authorization-signing.md`](drop-authorization-signing.md) and
  [`test/fixtures/drop-authorization/`](../test/fixtures/drop-authorization/)
  record no-secret local EIP-712 and ERC-1271 drop authorization signing
  examples, unsigned payload-generator templates, generated typed-data outputs,
  and deterministic digest fixtures.
- [`release-artifacts/schema/drop-authorization-signing-evidence.schema.json`](../release-artifacts/schema/drop-authorization-signing-evidence.schema.json)
  defines the retained drop authorization signing evidence format, and
  [`release-artifacts/drop-authorization-signing/drop-authorization-signing-evidence-template.json`](../release-artifacts/drop-authorization-signing/drop-authorization-signing-evidence-template.json)
  plus
  [`release-artifacts/drop-authorization-signing/drop-authorization-signing-retained-artifact.txt`](../release-artifacts/drop-authorization-signing/drop-authorization-signing-retained-artifact.txt)
  provide the checked no-secret local template.
- [`docs/signer-custody-readiness.md`](signer-custody-readiness.md) documents
  the no-secret signer custody readiness evidence model, and
  [`release-artifacts/schema/signer-custody-readiness.schema.json`](../release-artifacts/schema/signer-custody-readiness.schema.json)
  defines the retained signer custody readiness format. The checked local
  template and retained artifact live at
  [`release-artifacts/signer-custody-readiness/signer-custody-readiness-template.json`](../release-artifacts/signer-custody-readiness/signer-custody-readiness-template.json)
  and
  [`release-artifacts/signer-custody-readiness/signer-custody-readiness-retained-artifact.txt`](../release-artifacts/signer-custody-readiness/signer-custody-readiness-retained-artifact.txt).
- [`release-artifacts/schema/public-beta-evidence.schema.json`](../release-artifacts/schema/public-beta-evidence.schema.json)
  defines the retained status format.

The release manifest includes this audit package as a governance document. The
release manifest also includes the architecture map, threat model, incident
response runbook, drop authorization signing guide, and signer custody
readiness guide as governance documents, summarizes the public-beta evidence
status, and records the generated risk register. The bytecode-to-release proof records the release-manifest
hash and is covered by the checksum bundle; it is deliberately not embedded
back into the release manifest. The checksum bundle covers the release
manifest, proof, risk register, address books, retained evidence, and release artifacts, so
changes to the audit package, architecture map, threat model,
incident-response runbook, drop authorization signing guide, signer custody
readiness guide, public-beta evidence status, or release-proof artifacts must
refresh release evidence before a release-oriented PR can pass.

## Known Blockers And Accepted Risks

Known unresolved blockers are tracked in
[`docs/known-blockers.md`](known-blockers.md) and
[`ops/ROADMAP.md`](../ops/ROADMAP.md), then summarized in the generated
[`release-artifacts/latest/risk-register.json`](../release-artifacts/latest/risk-register.json).
Current major unresolved categories
include fork/testnet/live deployment ceremonies, production broadcast retention,
live explorer verification, production address books, production release
signatures, reviewed signer custody readiness evidence, non-local randomizer
operations evidence, non-local metadata browser evidence, live bytecode proof,
post-audit remediation, and external audit completion. The machine-readable
status for these categories lives in
[`release-artifacts/latest/public-beta-evidence.json`](../release-artifacts/latest/public-beta-evidence.json).

Accepted local-baseline dispositions are separate from unresolved production
blockers:

- Some Slither rows are accepted as test-only helper findings or documented
  vendored-library false positives in
  [`ops/SLITHER_BASELINE.md`](../ops/SLITHER_BASELINE.md).
- Local Anvil ceremony, randomizer operations, and release signature evidence
  use no-secret placeholders and do not claim production status.
- The bytecode-to-release proof is local/fork release-artifact proof; it does
  not replace live RPC or explorer bytecode verification.
- Runtime size remains under the EIP-170 limit and above the current release
  floor, but close enough to the limit that large future `StreamCore` changes
  need explicit size-budget review.

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
python scripts/test_release_readiness.py
python scripts/check_release_readiness.py
python scripts/test_public_beta_evidence.py
python scripts/check_public_beta_evidence.py
python scripts/test_risk_register.py
python scripts/check_risk_register.py
python scripts/generate_risk_register.py --check
python scripts/test_release_manifest.py
python scripts/generate_release_manifest.py --check
python scripts/test_bytecode_release_proof.py
python scripts/generate_bytecode_release_proof.py --check
python scripts/test_release_checksums.py
python scripts/generate_release_checksums.py --check
python scripts/test_signed_release_tag.py
python scripts/check_signed_release_tag.py
```

Run the release evidence generators if tracked artifacts need refreshing:

```sh
python scripts/generate_release_manifest.py
python scripts/generate_bytecode_release_proof.py
python scripts/generate_release_checksums.py
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

## Audit Submission Checklist

Before sending this package to an external auditor or publishing an audit-ready
branch, confirm each item below in the PR description or retained audit handoff
notes:

- The audited commit SHA and branch are named.
- The package still says pre-audit, not production-ready, and local baseline.
- `docs/architecture.md`, `docs/threat-model.md`, ADRs, and this package point
  at the same protocol boundaries.
- `ops/SLITHER_BASELINE.md` has no unexplained high/medium production finding.
- `docs/known-blockers.md`, `docs/release-readiness.md`, public-beta blocker
  report, production-release blocker report, and risk register agree on
  external evidence gaps and accepted local-baseline risks.
- Release manifest, bytecode-to-release proof, source verification inputs,
  checksum bundle, and signed release tag gate are current.
- Test evidence covers the state-machine, adversarial ordering, signer
  compromise, pause matrix, payment/forced-ETH invariants, metadata browser
  safety, randomizer lifecycle, deployment rehearsal, and release-proof checks.
- Any accepted local-baseline risk has an owner, rationale, and follow-up
  location.
- No private keys, mnemonics, RPC URLs, API keys, unreleased drop payloads, or
  private ceremony notes are present in retained artifacts.
- Any live/fork/testnet/mainnet evidence claim links to reviewed no-secret
  retained artifacts rather than local placeholders.

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
python scripts/test_drop_authorization_payload_generator.py
python scripts/generate_drop_authorization_payload.py --input test/fixtures/drop-authorization/payload-generator/fixed-price-input.json --output test/fixtures/drop-authorization/payload-generator/fixed-price-output.json --check
python scripts/generate_drop_authorization_payload.py --input test/fixtures/drop-authorization/payload-generator/auction-input.json --output test/fixtures/drop-authorization/payload-generator/auction-output.json --check
python scripts/test_drop_authorization_fixtures.py
python scripts/check_drop_authorization_fixtures.py
python scripts/test_drop_authorization_signing_evidence.py
python scripts/check_drop_authorization_signing_evidence.py
python scripts/test_signer_custody_readiness.py
python scripts/check_signer_custody_readiness.py
python scripts/test_public_beta_evidence.py
python scripts/check_public_beta_evidence.py
python scripts/test_risk_register.py
python scripts/check_risk_register.py
python scripts/generate_risk_register.py
python scripts/test_release_manifest.py
python scripts/generate_release_manifest.py
python scripts/test_bytecode_release_proof.py
python scripts/generate_bytecode_release_proof.py
python scripts/test_release_checksums.py
python scripts/generate_release_checksums.py
python scripts/generate_release_manifest.py --check
python scripts/generate_bytecode_release_proof.py --check
python scripts/generate_release_checksums.py --check
python scripts/test_signed_release_tag.py
python scripts/check_signed_release_tag.py
```
