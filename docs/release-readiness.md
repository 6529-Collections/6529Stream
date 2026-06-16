# Release Readiness

This dashboard is the Gate G release-readiness entry point for 6529Stream.
It is a pre-audit local baseline, not production-ready, and not a security claim.
Local evidence does not replace fork/testnet/live evidence for public beta or
production release.

Use this file to answer one question before any release claim: what is already
proved by committed local evidence, and what still blocks a public beta or
production release?
Use [`docs/non-local-release-evidence.md`](non-local-release-evidence.md) as
the intake runbook for any fork, testnet, live, audit, gas, invariant,
verification, or signing evidence that updates the public-beta evidence status.
Use [`docs/incident-response.md`](incident-response.md) for no-secret triage,
containment, recovery, evidence retention, and reopening procedures when an
operational incident affects release readiness.
Use [`docs/drop-authorization-signing.md`](drop-authorization-signing.md) for
the local no-secret drop authorization signing fixtures, unsigned payload
generator templates, drop authorization signing evidence template, and the
EIP-712 / ERC-1271 evidence they cover.
Use [`docs/signer-custody-readiness.md`](signer-custody-readiness.md) for the
no-secret production signer custody readiness evidence model that must
accompany reviewed non-local signing evidence.
Use [`docs/provenance-manifests.md`](provenance-manifests.md) for the checked
1/1 provenance manifest model, generated provenance artifact catalog, and
frontend/indexer display boundaries for artist/story/authenticity context.
Use [`docs/permanence-packages.md`](permanence-packages.md) for the checked
`ONE-004` collector-verifiable permanence package model, generated
one-of-one permanence manifest, replay commands, browser proof, output hashes,
and fully on-chain versus decentralized storage boundaries.
Use [`docs/royalty-policy.md`](royalty-policy.md) for the checked `ONE-003`
royalty policy, current ERC-2981 disclosure, governance boundary, marketplace
display guidance, and royalty disclosure, not payment enforcement caveat.
Use [`docs/warning-dispositions.md`](warning-dispositions.md) for the checked
`ONE-007` warning disposition baseline covering fixed NatSpec warning noise and
accepted solc, documentation, linter, vendored, test-only, ABI-compatibility,
and `StreamCore` size-tradeoff warning decisions, including the plain-language
StreamCore size-tradeoff warning decisions phrase used by the checker.
Use [`docs/protocol-surface.md`](protocol-surface.md) for the generated
function, selector, event, topic0, custom-error, ABI hash, bytecode hash, and
runtime-size report over release-tracked contracts.
Use [`docs/natspec-coverage.md`](natspec-coverage.md) for the checked
`CON-006` NatSpec coverage baseline over release-surface functions, public
variable getters, events, and custom errors. The baseline is a burn-down queue,
not proof that current API documentation is complete.
Use [`docs/deployment.md`](deployment.md#admin-ceremony-evidence) for the
no-secret admin ceremony evidence model that must accompany reviewed ownership,
role, signer, pause, emergency, and post-state proof for non-local deployments.
Use [`docs/integrations/README.md`](integrations/README.md) as the integration entrypoint
for frontend, mobile, Electron, indexer, operator UI, and backend
signing service teams that need to find canonical ABIs, address books,
deployment manifests, event catalogs, metadata docs, signing docs, and release
artifacts without treating local evidence as public beta or production proof.
Use [`docs/integrations/contract-flows.md`](integrations/contract-flows.md) as
the fixed-price mint and drop authorization flow spec for current INT-002
frontend/backend-signing integration work.
Use [`docs/integrations/auction-flows.md`](integrations/auction-flows.md) as
the auction frontend and indexer flow spec for current INT-003 integration
work.
Use
[`docs/integrations/wallets-and-signatures.md`](integrations/wallets-and-signatures.md)
as the wallet, EIP-712, ERC-1271, and Safe signing guide for current INT-004
integration work.
Use
[`docs/integrations/events-and-indexing.md`](integrations/events-and-indexing.md)
as the event and indexer reconstruction spec for current INT-005 integration
work.
Use
[`docs/integrations/metadata-rendering.md`](integrations/metadata-rendering.md)
as the metadata rendering, cache, animation sandbox, and marketplace
integration guide for current INT-006 integration work.
Use
[`docs/integrations/marketplace-indexer-evidence.md`](integrations/marketplace-indexer-evidence.md)
as the `ONE-005` retained marketplace/indexer evidence guide for OpenSea,
Reservoir, Blur, Manifold, equivalent collector/indexer tooling, contract
metadata, token metadata refresh, animation rendering, royalty display,
transfer/listing/sale paths, event replay, and cache invalidation.
Use
[`docs/integrations/frontend-reference-architecture.md`](integrations/frontend-reference-architecture.md)
as the React/Next frontend reference architecture for current INT-007
integration work, including artifact import, client layering, query/cache,
transaction, wallet, metadata, indexer, environment, and testing boundaries
without adding a maintained frontend package or generated SDK.
Use
[`docs/integrations/mobile-walletconnect.md`](integrations/mobile-walletconnect.md)
as the mobile and WalletConnect integration guide for current INT-008
integration work, including mobile browser, native shell, WalletConnect session
lifecycle, foreground wallet handoff, deep links, reconnect, offline/background,
telemetry, and no-secret boundaries without adding a maintained mobile SDK,
React Native app, or WalletConnect dependency recommendation.
Use
[`docs/integrations/electron-security-wallets.md`](integrations/electron-security-wallets.md)
as the Electron security and wallet integration guide for current INT-009
integration work, including Electron main/renderer/preload boundaries,
BrowserWindow hardening, context isolation, IPC allowlists, wallet-provider
boundaries, metadata animation sandboxing, local cache/secrets policy, signed
updates, code signing, autoUpdater caveats, telemetry, and no-secret boundaries
without adding a maintained Electron app, native desktop app, desktop SDK,
code-signing implementation, or signed-update implementation.
Use
[`docs/integrations/operator-admin-ui.md`](integrations/operator-admin-ui.md)
as the operator admin UI specification for current INT-010 integration work,
including operator personas, Safe/multisig ceremony, role grants, signer
lifecycle, pause domains, metadata freeze, dependency updates, randomizer
operations, emergency-withdrawable surplus, monitoring, incident links, and
no-secret evidence boundaries without adding a maintained operator dashboard,
Safe app, multisig transaction builder, monitoring service, or production
signer custody implementation.
Use
[`release-artifacts/latest/public-beta-blockers.md`](../release-artifacts/latest/public-beta-blockers.md)
and
[`release-artifacts/latest/production-release-blockers.md`](../release-artifacts/latest/production-release-blockers.md)
as the generated blocker reports for the current evidence manifest, and use
[`release-artifacts/latest/release-evidence-packet-index.md`](../release-artifacts/latest/release-evidence-packet-index.md)
as the release evidence packet index that maps blocker rows to templates,
retained-artifact expectations, validation commands, and current readiness
posture. Use
[`release-artifacts/latest/release-evidence-issue-backlog.md`](../release-artifacts/latest/release-evidence-issue-backlog.md)
as the generated issue-preparation backlog for the same incomplete evidence
rows without creating issues automatically or changing readiness claims. Use
[`release-artifacts/latest/release-evidence-issue-links.json`](../release-artifacts/latest/release-evidence-issue-links.json)
as the committed tracker map from those generated backlog entries to GitHub
issues. Use
[`release-artifacts/latest/release-evidence-issue-body-sync.md`](../release-artifacts/latest/release-evidence-issue-body-sync.md)
as the generated no-secret review view for exact GitHub issue body payloads
derived from that backlog and tracker map. Use
[`release-artifacts/latest/risk-register.json`](../release-artifacts/latest/risk-register.json)
as the generated risk register for launch blockers, accepted local-baseline
risks, planned mitigations, source-document hashes, and evidence links.
Run
`python scripts/check_release_evidence_issue_closure.py` before closing any
linked tracker issue; that release evidence issue closure readiness check loads
the tracker map, `release-evidence-issue-backlog.json` backlog artifact,
body-sync artifact, packet index, and evidence manifest, then keeps issues open
until committed evidence is `complete` or `accepted_risk`.

## Maturity And Scope

Current maturity:

- Repository status: pre-audit and not production-ready.
- Evidence status: local baseline plus reviewed mainnet-fork deployment
  rehearsal evidence.
- Public beta status: blocked by missing external audit, testnet/live evidence,
  verified deployed addresses, explorer verification, and fork/testnet ceremony,
  metadata browser, and randomizer operations evidence.
- Production release status: blocked by missing production signatures, signed
  Git tags, verified deployed addresses, explorer verification, non-local
  retained evidence, and post-audit remediation evidence.

This dashboard covers release-readiness evidence only. It does not perform a
real release, does not create production signatures, and does not assert that
local tests prove protocol correctness.

The release-mode CI profile is the opt-in hard gate for public-beta or
production-release claims. It is exposed as a manual workflow_dispatch workflow
and local `make release-mode-public-beta-check` /
`make release-mode-production-release-check` targets, and it is expected to
fail until retained evidence is complete or explicitly accepted as risk.
Release mode requires public-beta readiness before production-release
readiness, so a production run validates both phases.

## Readiness Summary

| Area | Current state | Blocks public beta | Blocks production release |
| --- | --- | --- | --- |
| CI and local gates | Passing local/CI baseline exists for build, tests, size, local deployment rehearsals, incident response, release artifacts, architecture/threat model, audit package, release manifest, checksums, and changelog | No | No, but release commit CI must be green |
| Protocol maturity | Pre-audit, not production-ready, local baseline only | Yes | Yes |
| External audit | Audit package and external audit retained-artifact template/checker exist; completed external audit report and post-audit remediation do not exist | Yes | Yes |
| Deployment evidence | Local Anvil deployment, auction, metadata-browser, and emergency redeployment rehearsals exist; reviewed mainnet-fork deployment rehearsal evidence is retained; testnet rehearsal retained-artifact template/checker and admin ceremony evidence template/checker exist | Reviewed testnet/live evidence, reviewed admin ceremony evidence, verified deployed addresses, explorer verification, and fork/testnet ceremony/randomizer/metadata-browser evidence missing | Production broadcast retention, production admin ceremony evidence, verified deployed addresses, and explorer verification missing |
| Release artifacts | Release manifest, checksum bundle, bytecode-to-release proof, risk register, ABI baseline, gas snapshot, gas envelope baseline, protocol surface report, source verification inputs, address books, ceremony evidence, admin ceremony evidence schema/template/checker, randomizer operations evidence, release-signature evidence, drop authorization signing fixtures, unsigned payload-generator examples, drop authorization signing evidence schema/template/checker, signer custody readiness schema/template/checker, 1/1 provenance manifest schema/template/checker/generated catalog, collector-verifiable permanence package schema/template/checker/generated one-of-one permanence manifest, public-beta evidence status, generated public-beta and production-release blocker reports, release evidence packet index, release evidence issue backlog, release evidence issue links, release evidence issue body sync, release evidence issue closure readiness, non-local release evidence runbook/schema/generic template, external audit retained-artifact template/checker, testnet deployment retained-artifact template/checker, reviewed fork retained artifact/evidence envelope, per-requirement public-beta and production-release templates, and checker exist for the local baseline | Live release artifacts, live bytecode proof, production signing evidence, reviewed 1/1 provenance evidence where used for collector-facing claims, reviewed permanence packages with browser proof and output hashes where used for collector-facing claims, reviewed signer custody readiness, reviewed admin ceremony evidence, reviewed testnet/live retained evidence, verified deployed addresses, explorer verification, and completed external audit evidence missing | Production signatures, signed Git tags, reviewed 1/1 provenance evidence and reviewed collector permanence evidence where used for production collector-facing claims, and reviewed live bytecode proof missing |
| Static analysis and tests | Slither baseline, warning disposition baseline, NatSpec coverage baseline, test matrix, invariants, local gas snapshot, and local gas envelope ceilings are tracked | Testnet/live invariant and gas evidence missing, and NatSpec baseline remains a burn-down queue | External audit and production evidence missing |

## Local Evidence Already Passing

The current local baseline includes:

- deterministic build, test, production size, gas snapshot, gas envelope, and deployment
  rehearsal gates through [`Makefile`](../Makefile), [`scripts/check.sh`](../scripts/check.sh),
  [`scripts/check.ps1`](../scripts/check.ps1), and GitHub CI;
- auditor-facing architecture, threat model, and audit package docs under
  [`docs/architecture.md`](architecture.md), [`docs/threat-model.md`](threat-model.md),
  and [`docs/audit-package.md`](audit-package.md);
- incident response procedures in
  [`docs/incident-response.md`](incident-response.md);
- drop authorization signing fixtures, unsigned payload-generator examples, and
  checked drop authorization signing evidence template in
  [`docs/drop-authorization-signing.md`](drop-authorization-signing.md) and
  [`test/fixtures/drop-authorization/`](../test/fixtures/drop-authorization/),
  [`release-artifacts/schema/drop-authorization-signing-evidence.schema.json`](../release-artifacts/schema/drop-authorization-signing-evidence.schema.json),
  [`release-artifacts/drop-authorization-signing/drop-authorization-signing-evidence-template.json`](../release-artifacts/drop-authorization-signing/drop-authorization-signing-evidence-template.json),
  and [`scripts/check_drop_authorization_signing_evidence.py`](../scripts/check_drop_authorization_signing_evidence.py);
- signer custody readiness guidance, schema, checked template, and checker in
  [`docs/signer-custody-readiness.md`](signer-custody-readiness.md),
  [`release-artifacts/schema/signer-custody-readiness.schema.json`](../release-artifacts/schema/signer-custody-readiness.schema.json),
  [`release-artifacts/signer-custody-readiness/signer-custody-readiness-template.json`](../release-artifacts/signer-custody-readiness/signer-custody-readiness-template.json),
  [`release-artifacts/signer-custody-readiness/signer-custody-readiness-retained-artifact.txt`](../release-artifacts/signer-custody-readiness/signer-custody-readiness-retained-artifact.txt),
  and [`scripts/check_signer_custody_readiness.py`](../scripts/check_signer_custody_readiness.py);
- 1/1 provenance manifest guidance, schema, checked template, retained-artifact
  checklist, generated release catalog, and checker in
  [`docs/provenance-manifests.md`](provenance-manifests.md),
  [`release-artifacts/schema/one-of-one-provenance-manifest.schema.json`](../release-artifacts/schema/one-of-one-provenance-manifest.schema.json),
  [`release-artifacts/provenance/one-of-one-provenance-template.provenance.json`](../release-artifacts/provenance/one-of-one-provenance-template.provenance.json),
  [`release-artifacts/provenance/one-of-one-provenance-retained-artifact-template.md`](../release-artifacts/provenance/one-of-one-provenance-retained-artifact-template.md),
  [`release-artifacts/latest/one-of-one-provenance-manifest.json`](../release-artifacts/latest/one-of-one-provenance-manifest.json),
  [`scripts/check_one_of_one_provenance_manifest.py`](../scripts/check_one_of_one_provenance_manifest.py),
  and
  [`scripts/generate_one_of_one_provenance_manifest.py`](../scripts/generate_one_of_one_provenance_manifest.py),
  which establish the artifact-only artist/story/authenticity model without
  claiming token finality, marketplace readiness, royalty enforcement, or
  ownership proof beyond chain state;
- collector-verifiable permanence package guidance, schema, checked template,
  retained-artifact checklist, generated one-of-one permanence manifest, and
  checker in [`docs/permanence-packages.md`](permanence-packages.md),
  [`release-artifacts/schema/one-of-one-permanence-package.schema.json`](../release-artifacts/schema/one-of-one-permanence-package.schema.json),
  [`release-artifacts/permanence/one-of-one-permanence-template.permanence.json`](../release-artifacts/permanence/one-of-one-permanence-template.permanence.json),
  [`release-artifacts/permanence/one-of-one-permanence-retained-artifact-template.md`](../release-artifacts/permanence/one-of-one-permanence-retained-artifact-template.md),
  [`release-artifacts/latest/one-of-one-permanence-manifest.json`](../release-artifacts/latest/one-of-one-permanence-manifest.json),
  [`scripts/check_one_of_one_permanence_package.py`](../scripts/check_one_of_one_permanence_package.py),
  and
  [`scripts/generate_one_of_one_permanence_manifest.py`](../scripts/generate_one_of_one_permanence_manifest.py),
  which establish the artifact-only replay command, renderer/dependency/source
  hash, browser proof, output hash, and fully on-chain versus decentralized
  storage boundary without claiming final collector proof until reviewed
  non-local or final-drop evidence exists;
- royalty policy guidance in
  [`docs/royalty-policy.md`](royalty-policy.md), covered by
  `python scripts/test_royalty_policy.py` and
  `python scripts/check_royalty_policy.py`, which documents current ERC-2981
  disclosure, governance and enforcement boundaries, marketplace display
  guidance, and the rule that No production-readiness claim depends on
  marketplaces honoring royalties;
- warning disposition guidance in
  [`docs/warning-dispositions.md`](warning-dispositions.md), covered by
  `python scripts/test_warning_dispositions.py` and
  `python scripts/check_warning_dispositions.py`, which documents fixed NatSpec
  warning noise and accepted solc, documentation, linter, vendored, test-only,
  ABI-compatibility, and `StreamCore` size-tradeoff warning decisions without
  treating warning quietness as protocol correctness proof;
- release manifest and checksum bundle outputs under
  [`release-artifacts/latest/release-manifest.json`](../release-artifacts/latest/release-manifest.json),
  [`release-artifacts/latest/SHA256SUMS`](../release-artifacts/latest/SHA256SUMS),
  and [`release-artifacts/latest/release-checksums.json`](../release-artifacts/latest/release-checksums.json);
- protocol surface report guidance and generated output under
  [`docs/protocol-surface.md`](protocol-surface.md) and
  [`release-artifacts/latest/protocol-surface-report.json`](../release-artifacts/latest/protocol-surface-report.json),
  covered by `python scripts/test_protocol_surface_report.py` and
  `python scripts/generate_protocol_surface_report.py --check`;
- NatSpec coverage guidance and checked baseline under
  [`docs/natspec-coverage.md`](natspec-coverage.md) and
  [`release-artifacts/baselines/v0.1.0/natspec-coverage.json`](../release-artifacts/baselines/v0.1.0/natspec-coverage.json),
  covered by `python scripts/test_natspec_coverage.py` and
  `python scripts/check_natspec_coverage.py`, which keeps new undocumented
  release-surface entries from entering silently without claiming the current
  API documentation is complete;
- bytecode-to-release proof under
  [`release-artifacts/latest/bytecode-release-proof.json`](../release-artifacts/latest/bytecode-release-proof.json),
  covered by `python scripts/test_bytecode_release_proof.py` and
  `python scripts/generate_bytecode_release_proof.py --check`, which tie
  committed local/fork addresses and runtime bytecode hashes to the release
  manifest without claiming live production bytecode verification;
- generated risk register under
  [`release-artifacts/latest/risk-register.json`](../release-artifacts/latest/risk-register.json),
  backed by
  [`release-artifacts/schema/risk-register.schema.json`](../release-artifacts/schema/risk-register.schema.json),
  `python scripts/test_risk_register.py`,
  `python scripts/check_risk_register.py`, and
  `python scripts/generate_risk_register.py --check`, which summarize launch
  blockers, accepted local-baseline risks, planned mitigations, source-document
  hashes, and evidence links without changing readiness claims;
- source verification inputs under
  [`release-artifacts/latest/source-verification-inputs.json`](../release-artifacts/latest/source-verification-inputs.json);
- ABI compatibility and gas baselines under
  [`release-artifacts/baselines/v0.1.0/abi-surface.json`](../release-artifacts/baselines/v0.1.0/abi-surface.json)
  [`release-artifacts/baselines/v0.1.0/gas-snapshot.snap`](../release-artifacts/baselines/v0.1.0/gas-snapshot.snap),
  and [`release-artifacts/baselines/v0.1.0/gas-envelopes.json`](../release-artifacts/baselines/v0.1.0/gas-envelopes.json);
- no-secret local ceremony evidence, randomizer operations evidence, and
  release-signature evidence under
  [`deployments/ceremony-evidence/anvil-6529stream-v0.1.0-001-local.json`](../deployments/ceremony-evidence/anvil-6529stream-v0.1.0-001-local.json),
  [`deployments/randomizer-operations/anvil-6529stream-v0.1.0-001-local.json`](../deployments/randomizer-operations/anvil-6529stream-v0.1.0-001-local.json),
  and [`release-artifacts/signatures/anvil-6529stream-v0.1.0-001-local.json`](../release-artifacts/signatures/anvil-6529stream-v0.1.0-001-local.json);
- signed release tag gate coverage through
  `python scripts/test_signed_release_tag.py` and
  `python scripts/check_signed_release_tag.py`; the default non-release mode
  runs in local and CI gates without claiming release status, while strict
  release mode requires a matching signed tag, current checksum bundle, and
  post-bundle release-signature evidence outside the `SHA256SUMS` coverage set;
- no-secret admin ceremony evidence schema, template, retained-artifact
  checklist, and checker under
  [`deployments/schema/admin-ceremony-evidence.schema.json`](../deployments/schema/admin-ceremony-evidence.schema.json),
  [`deployments/admin-ceremony/admin-ceremony-evidence-template.json`](../deployments/admin-ceremony/admin-ceremony-evidence-template.json),
  [`deployments/admin-ceremony/admin-ceremony-retained-artifact-template.md`](../deployments/admin-ceremony/admin-ceremony-retained-artifact-template.md),
  and [`scripts/check_admin_ceremony_evidence.py`](../scripts/check_admin_ceremony_evidence.py);
- no-secret public-beta evidence status under
  [`release-artifacts/latest/public-beta-evidence.json`](../release-artifacts/latest/public-beta-evidence.json)
  following [`docs/public-beta-evidence.md`](public-beta-evidence.md), plus the
  generated blocker reports at
  [`release-artifacts/latest/public-beta-blockers.md`](../release-artifacts/latest/public-beta-blockers.md)
  and
  [`release-artifacts/latest/production-release-blockers.md`](../release-artifacts/latest/production-release-blockers.md),
  plus the no-secret release evidence packet index at
  [`release-artifacts/latest/release-evidence-packet-index.json`](../release-artifacts/latest/release-evidence-packet-index.json)
  and
  [`release-artifacts/latest/release-evidence-packet-index.md`](../release-artifacts/latest/release-evidence-packet-index.md),
  plus the generated release evidence issue backlog at
  [`release-artifacts/latest/release-evidence-issue-backlog.json`](../release-artifacts/latest/release-evidence-issue-backlog.json)
  and
  [`release-artifacts/latest/release-evidence-issue-backlog.md`](../release-artifacts/latest/release-evidence-issue-backlog.md),
  plus the committed GitHub tracker map at
  [`release-artifacts/latest/release-evidence-issue-links.json`](../release-artifacts/latest/release-evidence-issue-links.json),
  plus deterministic live issue snapshot exporter tests with
  `python scripts/test_release_evidence_issue_snapshot.py` and
  `python scripts/test_release_evidence_issue_snapshot_audit.py`, including
  release evidence live audit report bundle coverage for retained no-secret
  JSON/Markdown audit summaries,
  plus the release evidence live audit report schema at
  [`release-artifacts/schema/release-evidence-live-audit-report.schema.json`](../release-artifacts/schema/release-evidence-live-audit-report.schema.json),
  the checked no-secret JSON template at
  [`release-artifacts/evidence/release-evidence-live-audit-report-template.json`](../release-artifacts/evidence/release-evidence-live-audit-report-template.json),
  the checked no-secret Markdown template at
  [`release-artifacts/evidence/release-evidence-live-audit-report-template.md`](../release-artifacts/evidence/release-evidence-live-audit-report-template.md),
  and offline report validation plus release evidence live audit Markdown parity
  with
  `python scripts/test_release_evidence_live_audit_report.py` and
  `python scripts/check_release_evidence_live_audit_report.py`,
  `python scripts/test_release_evidence_live_audit_markdown.py`, and
  `python scripts/check_release_evidence_live_audit_markdown.py`, plus the
  release evidence live audit report archive at
  [`release-artifacts/latest/release-evidence-live-audit-report-archive.json`](../release-artifacts/latest/release-evidence-live-audit-report-archive.json)
  and
  [`release-artifacts/latest/release-evidence-live-audit-report-archive.md`](../release-artifacts/latest/release-evidence-live-audit-report-archive.md),
  checked with `python scripts/test_release_evidence_live_audit_archive.py` and
  `python scripts/generate_release_evidence_live_audit_archive.py --check`,
  plus the future live audit archive retention workflow under
  [`release-artifacts/evidence/live-audit-reports/README.md`](../release-artifacts/evidence/live-audit-reports/README.md)
  for paired JSON/Markdown reports in
  `release-artifacts/evidence/live-audit-reports/`, `YYYYMMDDTHHMMSSZ`
  `--generated-at` run labels, no secrets, explicit `snapshot_freshness`,
  `currentness_claim`, and per-profile `profile_generated_at` markers, and the
  rule that retained reports are not readiness proof by themselves,
  plus the production broadcast retention checker and production broadcast
  retention retained artifact template under
  [`release-artifacts/evidence/production-broadcast-retention/production-broadcast-retention-retained-artifact-template.md`](../release-artifacts/evidence/production-broadcast-retention/production-broadcast-retention-retained-artifact-template.md),
  validated with `python scripts/test_production_broadcast_retention.py` and
  `python scripts/check_production_broadcast_retention.py`,
  plus the production verified-addresses checker and production
  verified-addresses retained artifact template under
  [`release-artifacts/evidence/production-verified-addresses/production-verified-addresses-retained-artifact-template.md`](../release-artifacts/evidence/production-verified-addresses/production-verified-addresses-retained-artifact-template.md),
  validated with `python scripts/test_production_verified_addresses.py` and
  `python scripts/check_production_verified_addresses.py`,
  plus live metadata-browser evidence for `live_metadata_browser_evidence`
  under
  [`release-artifacts/evidence/live-metadata-browser/live-metadata-browser-retained-artifact-template.md`](../release-artifacts/evidence/live-metadata-browser/live-metadata-browser-retained-artifact-template.md),
  validated offline with `python scripts/test_live_metadata_browser_evidence.py`
  and `python scripts/check_live_metadata_browser_evidence.py`,
  plus post-audit remediation evidence for `post_audit_remediation` under
  [`release-artifacts/evidence/post-audit-remediation/post-audit-remediation-retained-artifact-template.md`](../release-artifacts/evidence/post-audit-remediation/post-audit-remediation-retained-artifact-template.md),
  validated offline with
  `python scripts/test_post_audit_remediation_evidence.py` and
  `python scripts/check_post_audit_remediation_evidence.py`,
  plus deterministic tracker-label checks with
  `python scripts/test_release_evidence_issue_labels.py` and
  `python scripts/check_release_evidence_issue_labels.py`,
  plus the generated exact issue body payloads at
  [`release-artifacts/latest/release-evidence-issue-body-sync.json`](../release-artifacts/latest/release-evidence-issue-body-sync.json)
  and
  [`release-artifacts/latest/release-evidence-issue-body-sync.md`](../release-artifacts/latest/release-evidence-issue-body-sync.md),
  plus deterministic tracker-body checks with
  `python scripts/test_release_evidence_issue_bodies.py` and
  `python scripts/check_release_evidence_issue_bodies.py`, plus release
  evidence issue closure readiness checks with
  `python scripts/test_release_evidence_issue_closure.py` and
  `python scripts/check_release_evidence_issue_closure.py`;
- non-local release evidence intake requirements, schema, checked template, and
  checker under [`docs/non-local-release-evidence.md`](non-local-release-evidence.md),
  [`release-artifacts/schema/non-local-release-evidence.schema.json`](../release-artifacts/schema/non-local-release-evidence.schema.json),
  [`release-artifacts/evidence/non-local-release-evidence-template.json`](../release-artifacts/evidence/non-local-release-evidence-template.json),
  [`release-artifacts/evidence/fork-deployment-rehearsal/fork-deployment-rehearsal-retained-artifact-template.md`](../release-artifacts/evidence/fork-deployment-rehearsal/fork-deployment-rehearsal-retained-artifact-template.md),
  [`release-artifacts/evidence/public-beta-templates/`](../release-artifacts/evidence/public-beta-templates/),
  [`release-artifacts/evidence/production-release-templates/`](../release-artifacts/evidence/production-release-templates/),
  [`scripts/check_non_local_release_evidence.py`](../scripts/check_non_local_release_evidence.py),
  and
  [`scripts/check_fork_deployment_rehearsal_evidence.py`](../scripts/check_fork_deployment_rehearsal_evidence.py);
- Slither baseline evidence in [`ops/SLITHER_BASELINE.md`](../ops/SLITHER_BASELINE.md)
  and [`docs/slither.md`](slither.md);
- the test matrix in [`ops/ROADMAP.md`](../ops/ROADMAP.md#appendix-b-test-matrix);
- the ADR index in [`docs/adr/README.md`](adr/README.md).

These items are release evidence, not launch approval.

## Public Beta Blockers

Public beta remains blocked until maintainers add or explicitly accept evidence
for:

- completed external audit report and issue-linked remediation status;
- testnet/live deployment rehearsal evidence plus fork/testnet/live metadata
  browser execution, ceremony evidence, randomizer operations evidence,
  emergency redeployment evidence, and invariant/gas checks following
  [`docs/non-local-release-evidence.md`](non-local-release-evidence.md);
- production address books generated from retained broadcast artifacts;
- verified deployed addresses and explorer verification status;
- production signer and admin ceremony evidence with secrets redacted;
- reviewed signer custody readiness evidence with custody owner, signer
  manager, signer epoch source, signer-service integration, ERC-1271 status,
  rotation/revocation drills, monitoring, and incident-response references;
- production drop authorization signing evidence and approved signer
  integration beyond the no-secret local fixtures and unsigned payload
  generator;
- a final review that known blockers in [`docs/known-blockers.md`](known-blockers.md)
  and [`ops/ROADMAP.md`](../ops/ROADMAP.md) have either been resolved or
  explicitly deferred outside public beta.

## Production Release Blockers

Production release remains blocked until maintainers add or explicitly accept:

- production signatures over the checksum bundle;
- signed Git tags for the release commit;
- production release-signature evidence following
  [`docs/release-signatures.md`](release-signatures.md);
- retained production broadcast outputs and generated live deployment manifests;
- production broadcast retention retained artifact review following the
  production broadcast retention checker;
- verified deployed addresses and explorer verification output following the
  production verified-addresses checker;
- post-audit remediation evidence for every accepted audit finding;
- dependency source retention and migration evidence following
  [`docs/dependency-operations.md`](dependency-operations.md);
- randomizer provider configuration, funding, lifecycle, and request-health
  evidence following [`docs/randomizer-operations.md`](randomizer-operations.md).
- no-secret non-local release evidence intake records following
  [`docs/non-local-release-evidence.md`](non-local-release-evidence.md).

## Required Evidence Links

Core project and governance:

- [README.md](../README.md)
- [CONTRIBUTING.md](../CONTRIBUTING.md)
- [SECURITY.md](../SECURITY.md)
- [CHANGELOG.md](../CHANGELOG.md)
- [ops/ROADMAP.md](../ops/ROADMAP.md)
- [ops/AUTONOMOUS_RUN.md](../ops/AUTONOMOUS_RUN.md)
- [docs/status.md](status.md)
- [docs/known-blockers.md](known-blockers.md)
- [docs/release-readiness.md](release-readiness.md)

Audit and protocol evidence:

- [docs/audit-package.md](audit-package.md)
- [docs/incident-response.md](incident-response.md)
- [docs/drop-authorization-signing.md](drop-authorization-signing.md)
- [docs/signer-custody-readiness.md](signer-custody-readiness.md)
- [docs/provenance-manifests.md](provenance-manifests.md)
- [docs/permanence-packages.md](permanence-packages.md)
- [docs/royalty-policy.md](royalty-policy.md)
- [docs/warning-dispositions.md](warning-dispositions.md)
- [docs/natspec-coverage.md](natspec-coverage.md)
- [docs/architecture.md](architecture.md)
- [docs/threat-model.md](threat-model.md)
- [docs/deployment.md](deployment.md)
- [docs/release-policy.md](release-policy.md)
- [docs/release-signatures.md](release-signatures.md)
- [docs/public-beta-evidence.md](public-beta-evidence.md)
- [docs/non-local-release-evidence.md](non-local-release-evidence.md)
- [docs/randomizer-operations.md](randomizer-operations.md)
- [docs/dependency-operations.md](dependency-operations.md)
- [docs/slither.md](slither.md)
- [docs/tooling.md](tooling.md)
- [docs/adr/README.md](adr/README.md)
- [ops/SLITHER_BASELINE.md](../ops/SLITHER_BASELINE.md)
- [docs/integrations/README.md](integrations/README.md)
- [docs/integrations/contract-flows.md](integrations/contract-flows.md)
- [docs/integrations/auction-flows.md](integrations/auction-flows.md)
- [docs/integrations/wallets-and-signatures.md](integrations/wallets-and-signatures.md)
- [docs/integrations/events-and-indexing.md](integrations/events-and-indexing.md)
- [docs/integrations/metadata-rendering.md](integrations/metadata-rendering.md)
- [docs/integrations/marketplace-indexer-evidence.md](integrations/marketplace-indexer-evidence.md)
- [docs/integrations/frontend-reference-architecture.md](integrations/frontend-reference-architecture.md)
- [docs/integrations/mobile-walletconnect.md](integrations/mobile-walletconnect.md)
- [docs/integrations/electron-security-wallets.md](integrations/electron-security-wallets.md)
- [docs/integrations/operator-admin-ui.md](integrations/operator-admin-ui.md)
- [docs/integrations/examples/react-viem.md](integrations/examples/react-viem.md)

Release artifacts:

- [release-artifacts/README.md](../release-artifacts/README.md)
- [release-artifacts/latest/release-manifest.json](../release-artifacts/latest/release-manifest.json)
- [release-artifacts/latest/protocol-surface-report.json](../release-artifacts/latest/protocol-surface-report.json)
- [release-artifacts/latest/SHA256SUMS](../release-artifacts/latest/SHA256SUMS)
- [release-artifacts/latest/release-checksums.json](../release-artifacts/latest/release-checksums.json)
- [release-artifacts/latest/risk-register.json](../release-artifacts/latest/risk-register.json)
- [release-artifacts/latest/public-beta-evidence.json](../release-artifacts/latest/public-beta-evidence.json)
- [release-artifacts/latest/public-beta-blockers.md](../release-artifacts/latest/public-beta-blockers.md)
- [release-artifacts/latest/production-release-blockers.md](../release-artifacts/latest/production-release-blockers.md)
- [release-artifacts/latest/release-evidence-packet-index.json](../release-artifacts/latest/release-evidence-packet-index.json)
- [release-artifacts/latest/release-evidence-packet-index.md](../release-artifacts/latest/release-evidence-packet-index.md)
- [release-artifacts/latest/release-evidence-issue-backlog.json](../release-artifacts/latest/release-evidence-issue-backlog.json)
- [release-artifacts/latest/release-evidence-issue-backlog.md](../release-artifacts/latest/release-evidence-issue-backlog.md)
- [release-artifacts/latest/release-evidence-issue-links.json](../release-artifacts/latest/release-evidence-issue-links.json)
- [release-artifacts/latest/release-evidence-issue-body-sync.json](../release-artifacts/latest/release-evidence-issue-body-sync.json)
- [release-artifacts/latest/release-evidence-issue-body-sync.md](../release-artifacts/latest/release-evidence-issue-body-sync.md)
- [release-artifacts/latest/source-verification-inputs.json](../release-artifacts/latest/source-verification-inputs.json)
- [release-artifacts/schema/public-beta-evidence.schema.json](../release-artifacts/schema/public-beta-evidence.schema.json)
- [release-artifacts/schema/risk-register.schema.json](../release-artifacts/schema/risk-register.schema.json)
- [release-artifacts/schema/release-evidence-live-audit-report.schema.json](../release-artifacts/schema/release-evidence-live-audit-report.schema.json)
- [release-artifacts/evidence/release-evidence-live-audit-report-template.json](../release-artifacts/evidence/release-evidence-live-audit-report-template.json)
- [release-artifacts/evidence/release-evidence-live-audit-report-template.md](../release-artifacts/evidence/release-evidence-live-audit-report-template.md)
- [release-artifacts/evidence/live-audit-reports/README.md](../release-artifacts/evidence/live-audit-reports/README.md)
- [release-artifacts/latest/release-evidence-live-audit-report-archive.json](../release-artifacts/latest/release-evidence-live-audit-report-archive.json)
- [release-artifacts/latest/release-evidence-live-audit-report-archive.md](../release-artifacts/latest/release-evidence-live-audit-report-archive.md)
- [release-artifacts/schema/drop-authorization-signing-evidence.schema.json](../release-artifacts/schema/drop-authorization-signing-evidence.schema.json)
- [release-artifacts/drop-authorization-signing/drop-authorization-signing-evidence-template.json](../release-artifacts/drop-authorization-signing/drop-authorization-signing-evidence-template.json)
- [release-artifacts/drop-authorization-signing/drop-authorization-signing-retained-artifact.txt](../release-artifacts/drop-authorization-signing/drop-authorization-signing-retained-artifact.txt)
- [release-artifacts/schema/signer-custody-readiness.schema.json](../release-artifacts/schema/signer-custody-readiness.schema.json)
- [release-artifacts/signer-custody-readiness/signer-custody-readiness-template.json](../release-artifacts/signer-custody-readiness/signer-custody-readiness-template.json)
- [release-artifacts/signer-custody-readiness/signer-custody-readiness-retained-artifact.txt](../release-artifacts/signer-custody-readiness/signer-custody-readiness-retained-artifact.txt)
- [release-artifacts/schema/one-of-one-provenance-manifest.schema.json](../release-artifacts/schema/one-of-one-provenance-manifest.schema.json)
- [release-artifacts/provenance/one-of-one-provenance-template.provenance.json](../release-artifacts/provenance/one-of-one-provenance-template.provenance.json)
- [release-artifacts/provenance/one-of-one-provenance-retained-artifact-template.md](../release-artifacts/provenance/one-of-one-provenance-retained-artifact-template.md)
- [release-artifacts/latest/one-of-one-provenance-manifest.json](../release-artifacts/latest/one-of-one-provenance-manifest.json)
- [release-artifacts/schema/one-of-one-permanence-package.schema.json](../release-artifacts/schema/one-of-one-permanence-package.schema.json)
- [release-artifacts/permanence/one-of-one-permanence-template.permanence.json](../release-artifacts/permanence/one-of-one-permanence-template.permanence.json)
- [release-artifacts/permanence/one-of-one-permanence-retained-artifact-template.md](../release-artifacts/permanence/one-of-one-permanence-retained-artifact-template.md)
- [release-artifacts/latest/one-of-one-permanence-manifest.json](../release-artifacts/latest/one-of-one-permanence-manifest.json)
- [release-artifacts/schema/non-local-release-evidence.schema.json](../release-artifacts/schema/non-local-release-evidence.schema.json)
- [release-artifacts/evidence/non-local-release-evidence-template.json](../release-artifacts/evidence/non-local-release-evidence-template.json)
- [release-artifacts/evidence/non-local-template-retained-artifact.txt](../release-artifacts/evidence/non-local-template-retained-artifact.txt)
- [release-artifacts/evidence/public-beta-templates/](../release-artifacts/evidence/public-beta-templates/)
- [release-artifacts/evidence/production-release-templates/](../release-artifacts/evidence/production-release-templates/)
- [release-artifacts/baselines/v0.1.0/abi-surface.json](../release-artifacts/baselines/v0.1.0/abi-surface.json)
- [release-artifacts/baselines/v0.1.0/gas-snapshot.snap](../release-artifacts/baselines/v0.1.0/gas-snapshot.snap)
- [release-artifacts/baselines/v0.1.0/gas-envelopes.json](../release-artifacts/baselines/v0.1.0/gas-envelopes.json)
- [release-artifacts/baselines/v0.1.0/natspec-coverage.json](../release-artifacts/baselines/v0.1.0/natspec-coverage.json)
- [deployments/ceremony-evidence/anvil-6529stream-v0.1.0-001-local.json](../deployments/ceremony-evidence/anvil-6529stream-v0.1.0-001-local.json)
- [deployments/randomizer-operations/anvil-6529stream-v0.1.0-001-local.json](../deployments/randomizer-operations/anvil-6529stream-v0.1.0-001-local.json)
- [release-artifacts/signatures/anvil-6529stream-v0.1.0-001-local.json](../release-artifacts/signatures/anvil-6529stream-v0.1.0-001-local.json)

## Release Commands

Run the dashboard checker directly:

```sh
python scripts/test_release_readiness.py
python scripts/check_release_readiness.py
python scripts/test_release_mode.py
python scripts/check_release_mode.py --phase public-beta
python scripts/check_release_mode.py --phase production-release
python scripts/test_production_broadcast_retention.py
python scripts/check_production_broadcast_retention.py
python scripts/test_production_verified_addresses.py
python scripts/check_production_verified_addresses.py
python scripts/test_signed_release_tag.py
python scripts/check_signed_release_tag.py
python scripts/test_incident_response.py
python scripts/check_incident_response.py
python scripts/test_contract_flows.py
python scripts/check_contract_flows.py
python scripts/test_auction_flows.py
python scripts/check_auction_flows.py
python scripts/test_wallet_signature_flows.py
python scripts/check_wallet_signature_flows.py
python scripts/test_events_and_indexing.py
python scripts/check_events_and_indexing.py
python scripts/test_metadata_rendering.py
python scripts/check_metadata_rendering.py
python scripts/test_marketplace_indexer_evidence.py
python scripts/check_marketplace_indexer_evidence.py
python scripts/test_react_next_reference.py
python scripts/check_react_next_reference.py
python scripts/test_mobile_walletconnect.py
python scripts/check_mobile_walletconnect.py
python scripts/test_electron_security_wallets.py
python scripts/check_electron_security_wallets.py
python scripts/test_operator_admin_ui.py
python scripts/check_operator_admin_ui.py
python scripts/test_drop_authorization_payload_generator.py
python scripts/generate_drop_authorization_payload.py --input test/fixtures/drop-authorization/payload-generator/fixed-price-input.json --output test/fixtures/drop-authorization/payload-generator/fixed-price-output.json --check
python scripts/generate_drop_authorization_payload.py --input test/fixtures/drop-authorization/payload-generator/auction-input.json --output test/fixtures/drop-authorization/payload-generator/auction-output.json --check
python scripts/test_drop_authorization_fixtures.py
python scripts/check_drop_authorization_fixtures.py
python scripts/test_drop_authorization_signing_evidence.py
python scripts/check_drop_authorization_signing_evidence.py
python scripts/test_signer_custody_readiness.py
python scripts/check_signer_custody_readiness.py
python scripts/test_one_of_one_provenance_manifest.py
python scripts/check_one_of_one_provenance_manifest.py
python scripts/generate_one_of_one_provenance_manifest.py --check
python scripts/test_one_of_one_permanence_package.py
python scripts/check_one_of_one_permanence_package.py
python scripts/generate_one_of_one_permanence_manifest.py --check
python scripts/test_royalty_policy.py
python scripts/check_royalty_policy.py
python scripts/test_warning_dispositions.py
python scripts/check_warning_dispositions.py
python scripts/test_natspec_coverage.py
python scripts/check_natspec_coverage.py
python scripts/test_gas_envelopes.py
python scripts/check_gas_envelopes.py
python scripts/test_public_beta_evidence.py
python scripts/check_public_beta_evidence.py
python scripts/test_risk_register.py
python scripts/check_risk_register.py
python scripts/generate_risk_register.py --check
python scripts/test_production_release_blocker_report.py
python scripts/generate_production_release_blocker_report.py --check
python scripts/test_release_evidence_packet_index.py
python scripts/generate_release_evidence_packet_index.py --check
python scripts/test_release_evidence_issue_backlog.py
python scripts/generate_release_evidence_issue_backlog.py --check
python scripts/test_release_evidence_issue_links.py
python scripts/check_release_evidence_issue_links.py
python scripts/test_release_evidence_issue_snapshot.py
python scripts/test_release_evidence_issue_snapshot_audit.py
python scripts/test_release_evidence_live_audit_report.py
python scripts/check_release_evidence_live_audit_report.py
python scripts/test_release_evidence_live_audit_markdown.py
python scripts/check_release_evidence_live_audit_markdown.py
python scripts/test_release_evidence_live_audit_archive.py
python scripts/generate_release_evidence_live_audit_archive.py --check
python scripts/test_release_evidence_issue_labels.py
python scripts/check_release_evidence_issue_labels.py
python scripts/test_release_evidence_issue_body_sync.py
python scripts/generate_release_evidence_issue_body_sync.py --check
python scripts/test_release_evidence_issue_bodies.py
python scripts/check_release_evidence_issue_bodies.py
python scripts/test_release_evidence_issue_closure.py
python scripts/check_release_evidence_issue_closure.py
python scripts/test_non_local_release_evidence.py
python scripts/check_non_local_release_evidence.py
```

Run the release evidence drift checks:

```sh
python scripts/audit_release_evidence_issue_snapshots.py --report-json tmp/release-evidence-live-audit-report.json --report-md tmp/release-evidence-live-audit-report.md
python scripts/audit_release_evidence_issue_snapshots.py --generated-at YYYYMMDDTHHMMSSZ --report-json release-artifacts/evidence/live-audit-reports/YYYYMMDDTHHMMSSZ-release-evidence-live-audit-report.json --report-md release-artifacts/evidence/live-audit-reports/YYYYMMDDTHHMMSSZ-release-evidence-live-audit-report.md
python scripts/check_release_evidence_live_audit_report.py --report-json tmp/release-evidence-live-audit-report.json
python scripts/check_release_evidence_live_audit_report.py --report-json release-artifacts/evidence/live-audit-reports/YYYYMMDDTHHMMSSZ-release-evidence-live-audit-report.json
python scripts/check_release_evidence_live_audit_markdown.py --report-json tmp/release-evidence-live-audit-report.json --report-md tmp/release-evidence-live-audit-report.md
python scripts/check_release_evidence_live_audit_markdown.py --report-json release-artifacts/evidence/live-audit-reports/YYYYMMDDTHHMMSSZ-release-evidence-live-audit-report.json --report-md release-artifacts/evidence/live-audit-reports/YYYYMMDDTHHMMSSZ-release-evidence-live-audit-report.md
python scripts/generate_release_evidence_live_audit_archive.py --archive-dir release-artifacts/evidence/live-audit-reports
python scripts/generate_release_evidence_live_audit_archive.py --archive-dir release-artifacts/evidence/live-audit-reports --check
python scripts/generate_release_evidence_live_audit_archive.py --check
python scripts/check_signed_release_tag.py --mode release --tag vX.Y.Z --evidence path/to/post-bundle-release-signature-evidence.json
python scripts/generate_release_manifest.py --check
python scripts/generate_release_checksums.py --check
```

Run the full local release gate:

```sh
make check
powershell -ExecutionPolicy Bypass -File scripts\check.ps1
```

## Maintenance

Update this dashboard whenever a release gate, launch gate, evidence artifact,
production blocker, or accepted risk changes.

Required maintenance rules:

- New release evidence must be linked here before it can be treated as part of
  the public release baseline.
- New blockers must be added here, [`docs/known-blockers.md`](known-blockers.md),
  or [`ops/ROADMAP.md`](../ops/ROADMAP.md) before a PR claims readiness.
- Any public beta or production-ready claim must point to the CI run, release
  manifest, checksum bundle, signatures, signed tag, deployment evidence,
  explorer verification, audit report, and post-audit remediation evidence that
  justify it.
- Any fork/testnet/live evidence that changes public-beta or production status
  must follow the non-local release evidence intake runbook and include a
  reviewer before the related requirement is marked `complete`.
- Regenerate the release manifest and checksum bundle after changing this file,
  because it is a governance document in the release evidence package.
