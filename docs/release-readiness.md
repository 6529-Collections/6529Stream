# Release Readiness

This dashboard is the Gate G release-readiness entry point for 6529Stream.
It is a pre-audit local baseline, not production-ready, and not a security claim.
Local evidence does not replace fork/testnet/live evidence for public beta or
production release.

The canonical requirement inventory is
[`release-artifacts/genesis-deployment-profile.json`](../release-artifacts/genesis-deployment-profile.json).
Its default checker keeps the 37 numbered `[LCM-GENESIS]` roles structurally
synchronized and rejects every probe row or binding under ADR 0017; production
release mode additionally requires
the current candidate to satisfy every entry exactly once. The committed
implementation catalog remains incomplete and does not yet constitute a
concrete deployment-instance manifest, so this gate is red without changing
the public-beta decision.

Use this file to answer one question before any release claim: what is already
proved by committed local evidence, and what still blocks a public beta or
production release?
Use [`docs/production-readiness-execution.md`](production-readiness-execution.md)
for the current remote-main release-candidate execution packet: frozen commit,
locally executed gates, environment-blocked gates, and the public-beta and
production evidence rows that still prevent release claims.
Use [`docs/non-local-release-evidence.md`](non-local-release-evidence.md) as
the intake runbook for any fork, testnet, live, audit, gas, invariant,
verification, or signing evidence that updates the public-beta evidence status.
Use [`docs/incident-response.md`](incident-response.md) for no-secret triage,
containment, recovery, evidence retention, and reopening procedures when an
operational incident affects release readiness.
Use [`docs/audit-finding-workflow.md`](audit-finding-workflow.md) for
public-safe external audit finding intake, severity/status triage, remediation
PR requirements, retest, accepted-risk decisions, closure gates, and
post-audit evidence handoff.
Use [`docs/drop-authorization-signing.md`](drop-authorization-signing.md) for
the local no-secret drop authorization signing fixtures, unsigned payload
generator templates, drop authorization signing evidence template, and the
EIP-712 / ERC-1271 evidence they cover.
Use [`docs/signer-custody-readiness.md`](signer-custody-readiness.md) for the
no-secret production signer custody readiness evidence model that must
accompany reviewed non-local signing evidence.
Use [`docs/release-signatures.md`](release-signatures.md) for release signature
evidence, signed release tag gate boundaries, and the production
release-signing checker and retained artifact that future reviewed
`production_signatures` and `signed_git_tag` evidence must satisfy.
Use the public-beta verified-addresses checker and public-beta
verified-addresses retained artifact under
[`release-artifacts/evidence/public-beta-verified-addresses/public-beta-verified-addresses-retained-artifact-template.md`](../release-artifacts/evidence/public-beta-verified-addresses/public-beta-verified-addresses-retained-artifact-template.md)
for future reviewed `verified_deployed_addresses` and
`explorer_verification_status` evidence before those public-beta rows can move
out of missing or blocked status.
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
[`docs/reference/legacy-stack/integrations/frontend-reference-architecture.md`](reference/legacy-stack/integrations/frontend-reference-architecture.md)
as the React/Next frontend reference architecture for current INT-007
integration work, including artifact import, client layering, query/cache,
transaction, wallet, metadata, indexer, environment, and testing boundaries
without adding a maintained frontend package or generated SDK.
Use
[`docs/reference/legacy-stack/integrations/mobile-walletconnect.md`](reference/legacy-stack/integrations/mobile-walletconnect.md)
as the mobile and WalletConnect integration guide for current INT-008
integration work, including mobile browser, native shell, WalletConnect session
lifecycle, foreground wallet handoff, deep links, reconnect, offline/background,
telemetry, and no-secret boundaries without adding a maintained mobile SDK,
React Native app, or WalletConnect dependency recommendation.
Use
[`docs/reference/legacy-stack/integrations/electron-security-wallets.md`](reference/legacy-stack/integrations/electron-security-wallets.md)
as the Electron security and wallet integration guide for current INT-009
integration work, including Electron main/renderer/preload boundaries,
BrowserWindow hardening, context isolation, IPC allowlists, wallet-provider
boundaries, metadata animation sandboxing, local cache/secrets policy, signed
updates, code signing, autoUpdater caveats, telemetry, and no-secret boundaries
without adding a maintained Electron app, native desktop app, desktop SDK,
code-signing implementation, or signed-update implementation.
Use
[`docs/reference/legacy-stack/integrations/operator-admin-ui.md`](reference/legacy-stack/integrations/operator-admin-ui.md)
as the operator admin UI specification for current INT-010 integration work,
including operator personas, Safe/multisig ceremony, role grants, signer
lifecycle, pause domains, metadata freeze, dependency updates, randomizer
operations, emergency-withdrawable surplus, monitoring, incident links, and
no-secret evidence boundaries without adding a maintained operator dashboard,
Safe app, multisig transaction builder, monitoring service, or production
signer custody implementation.
Use [`docs/monitoring.md`](monitoring.md) as the `GOV-009` protocol monitoring
specification covering admin, signer, auction, randomness, credits, metadata,
dependency, release evidence, alert severity, dashboard queries, and incident
handoff without adding a maintained monitoring service, hosted dashboard, alert
provider integration, or production indexer.
Use
[`docs/operator-dashboard-query-model.md`](operator-dashboard-query-model.md)
as the `GOV-010` operator dashboard query model, mapping environment/release,
admin, signer, fixed-price, auction, randomizer, payment, metadata/dependency,
release blocker, and incident drill panels to query inputs, source artifacts,
freshness, severity, and no-secret telemetry boundaries without adding a
maintained dashboard, hosted monitoring service, alert provider, RPC provider,
or production indexer.
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
`python -m tools.release.check_release_evidence_issue_closure` before closing any
linked tracker issue; that release evidence issue closure readiness check loads
the tracker map, `release-evidence-issue-backlog.json` backlog artifact,
body-sync artifact, packet index, and evidence manifest, then keeps issues open
until committed evidence is `complete` or `accepted_risk`. For live GitHub
state, run `make release-evidence-live-issue-sync-check` with authenticated
`gh` access; it fetches each linked tracker issue, then validates live issue
bodies and closure state against the committed release evidence artifacts.

## Maturity And Scope

Current maturity:

- Repository status: pre-audit and not production-ready.
- Evidence status: local baseline plus reviewed fork metadata and marketplace
  evidence; current CON-015 fork deployment, fork ceremony, and fork randomizer
  artifacts are pending re-review after deployment/release artifacts changed.
- Public beta status: blocked by 30 Open first-party production Slither
  High/Medium findings, open record-family authorization risk `RISK-GOV-002`,
  High open Governance risk `RISK-GOV-003`, missing external audit, pending fork
  deployment review, missing testnet deployment evidence, pending fork ceremony
  review, pending fork randomizer review, verified deployed addresses, and
  explorer verification.
- Production release status: blocked by the same 30 Open Slither findings and
  `RISK-GOV-002` / `RISK-GOV-003`, incomplete #670 pointer integration and
  candidate remeasurement, incomplete instance-aware genesis evidence, an honestly incomplete
  checked governed-parameter inventory whose concrete
  host/value/floor/evidence bindings remain unavailable under #684 and
  `RISK-GOV-004`, missing production signatures, signed Git tags, verified
  deployed addresses, explorer verification, non-local retained evidence, and
  post-audit remediation evidence.

This dashboard covers release-readiness evidence only. It does not perform a
real release, does not create production signatures, and does not assert that
local tests prove protocol correctness.

The release-mode CI profile is the opt-in hard gate for public-beta or
production-release claims. It is exposed as a manual workflow_dispatch workflow
and local `make release-mode-public-beta-check` /
`make release-mode-production-release-check` targets. The local targets run the
aggregate `check` gate plus the pinned live exact Slither comparison first; the
manual workflow fails unless it runs from the protected default branch, then
runs both before evaluating release evidence. The gate is expected to fail
until retained evidence is complete; an active accepted-risk record may satisfy
only a waivable public-beta row. External-audit evidence and every production
requirement are non-waivable. Release mode requires public-beta readiness before
production-release readiness, so a production run validates both phases. It
also validates the checksum-covered current `StreamCore` size against the
normative 2,000-byte EIP-170 deployment headroom rule from the
[`Genesis Deployment Profile`](launch-conformance-matrix.md#genesis-deployment-profile)
and [`Core Hook Budget`](launch-v1-target-architecture.md#core-hook-budget).
Missing, malformed, inconsistent, or sub-threshold size fields fail closed.
The permanent target measurement in
[`release-artifacts/latest/bytecode-release-proof.json`](../release-artifacts/latest/bytecode-release-proof.json)
passes the non-waivable 2,000-byte production margin and the approved
22,184-byte objective. This resolves the Core-size row only; concrete #670 pointer
contracts, candidate-instance reconciliation, governed-parameter evidence,
audit, and live release evidence remain independently blocking.

Both release phases validate the canonical normalized
[`ops/SLITHER_BASELINE.json`](../ops/SLITHER_BASELINE.json) and its checked
Markdown mirror. Any Open first-party production High/Medium row blocks the
release decision even when the live analyzer exactly matches the baseline. The
current 30 Open rows therefore keep public beta and production red under
[issue #658](https://github.com/6529-Collections/6529Stream/issues/658).

The bounded assembly call in `StreamGovernanceExecutor` prevents returndata
bombs but makes proposal-selected native-value authority invisible to Slither's
`arbitrary-send-eth` detector. The Executor now binds and revalidates a
checksum-covered closed-world action/target/selector/value catalog at scheduling
and execution, with zero value as the default and explicit typed semantics for
any nonzero row. `RISK-GOV-003` remains a separate High open blocker until issue
[#656](https://github.com/6529-Collections/6529Stream/issues/656) provides exact
candidate addresses and code hashes and the deployment, system-manifest,
non-local rehearsal, monitoring, and independent-review evidence is complete.
The Governance V2 foundation is pre-audit and not production-ready.

Both release phases also run the record-family authorization checker and
consume its code-owned hard completion blocker. The retained historical
inventory records the former `as_built_fail_open` five-selector writer model;
the current source instead enforces a closed-world record-family registry,
typed writer authority, all-family snapshot intersection, family-authorized
locks, independent-family routing to an append-only Preservation path that
bypasses metadata pause and Core freeze, recorder-scoped hashes/latest pointers
with caller-scoped convenience reads and explicit nonzero-recorder reads, and
undeclared-type rejection before capacity consumption. The source ABI now adds
the registry configuration-authority lifecycle (`0x679dcd40`) and
Preservation's explicit-recorder reads (`0xa30cfc7c`), while collection metadata
remains `0x2c2422f4`; these pre-genesis additions do not prove a candidate or
deployment. The source catalog, planning inventory,
retained-evidence and exact grant-map schemas, and template make the still
missing candidate-bound evidence explicit, and no JSON edit, environment
variable, accepted risk, template, or admin ceremony can waive the stop.

The registry's stored current configuration authority is initialized from the
`StreamAdmins` owner but does not track later owner changes; a separate stored
pending authority mediates propose/accept/cancel. Candidate evidence must bind
both values at the same finalized observation across the classifier, grant
map, and both host rows. The current value must be nonzero. A pending value
must be zero unless its takeover state has an explicit reviewed disposition,
and lifecycle evidence must bind the exact address transition plus emitted
revision/hash for propose, accept, and cancel. That support must name the same
registry and finalized chain/block observation, reconcile the terminal
accepted/cancellation authority to the observed current authority, and bind
the terminal commitment to the observed revision/hash through a reviewed
linkage reference.
[Issue #690](https://github.com/6529-Collections/6529Stream/issues/690) and
`RISK-GOV-002` therefore block both public beta and production.

Strict release mode now proves whether the implementation catalog satisfies the
canonical
[`Genesis Deployment Profile`](launch-conformance-matrix.md#genesis-deployment-profile)
as a closed world. The committed catalog fails that check, and the current
manifest model still cannot prove every required distinct deployment instance
for the 37-entry, no-probe target. That reconciliation remains an independent
production blocker tracked by
[issue #656](https://github.com/6529-Collections/6529Stream/issues/656); the
structural profile gate is not concrete deployment evidence.

Production mode also runs the governed-parameter inventory checker with
`--require-complete`. The ordinary aggregate gate validates the schema-validated
22-GGP/3-GTP planning artifact and permits explicitly `not_available`
candidate bindings so development can continue without fabricated values.
Production mode permits no such placeholder: every logical row and every
required host profile must bind an exact candidate instance, genesis value,
immutable floor, exhaustive guarded-consumer inventory, reviewed measurement
or cadence evidence, and fixed-stipend compatibility. Until issue #656 adds a
structured production-candidate model and reconciliation checker, the
inventory checker also rejects any self-reported `complete` candidate rather
than trusting an opaque artifact. The committed artifact intentionally fails
that stricter decision, so #684 and `RISK-GOV-004` remain open.

## Readiness Summary

| Area | Current state | Blocks public beta | Blocks production release |
| --- | --- | --- | --- |
| CI and local gates | Passing local/CI baseline exists for build, tests, size, local deployment rehearsals, incident response, release artifacts, architecture/threat model, audit package, release manifest, checksums, and changelog | No | No, but release commit CI must be green |
| StreamCore deployment headroom | The canonical bytecode proof passes the 2,000-byte production margin and approved 22,184-byte objective without an exception; this does not clear candidate, audit, or live evidence rows | No | No |
| Genesis inventory completeness | The canonical 37-entry no-probe launch profile and fail-closed production checker exist, but the current implementation catalog is incomplete and the manifest model cannot yet prove every required distinct deployment instance; issue #656 tracks reconciliation | No | Yes |
| Governed parameter completeness | The schema-validated 22-GGP/3-GTP inventory pins exact 50-binding host-profile policy, failure/cadence rules, evidence obligations, and the shared Core completion buffer. Issue #671 binds the as-built permanent Core, actual royalty/metadata boundaries, independent raise-chain tests, six via-IR measurements, and inventory-bound 1,460,000 floor / 2,910,000 genesis planning values without adding a 23rd GGP. Candidate bindings remain honestly `not_available`; concrete #670 artist/revenue rows, exhaustive consumer review, candidate-bound sizing/cadence evidence, fixed-stipend compatibility, and instance-aware addresses are incomplete. #656/#684 and `RISK-GOV-004` keep this non-waivable production gate red | No | Yes |
| Record-family authorization | The checked source catalog pins closed-world record-type admission, fourteen family IDs, eight typed authority classes, family-scoped writes and locks, independent-family routing to append-only Preservation without pause/freeze blocking, a registry-wide configuration commitment, stored current/pending two-step configuration authority, snapshot intersection, and undeclared-type capacity protection. The historical inventory retains the former five selector/global-admin surfaces and eight fail-open behaviors. The exact candidate admission/provider/grant map, shared host-registry address, same-block finalized current/pending authority observation, deployed runtime, lifecycle event tuples, phase, and independent-review evidence remain unavailable; issue #690 and `RISK-GOV-002` stay open | Yes | Yes |
| Protocol maturity | Pre-audit, not production-ready, local baseline only | Yes | Yes |
| External audit | Audit package and external audit retained-artifact template/checker exist; completed external audit report and post-audit remediation do not exist | Yes | Yes |
| Deployment evidence | Local Anvil deployment, auction, metadata-browser, and emergency redeployment rehearsals exist; fork deployment rehearsal evidence is retained but pending re-review for the CON-015 artifact set; fork ceremony evidence is retained but pending re-review for the CON-015 artifact set; testnet rehearsal retained-artifact template/checker and admin ceremony evidence template/checker exist | Pending CON-015 fork deployment review, reviewed testnet/live evidence, reviewed admin ceremony evidence, pending CON-015 fork ceremony review, verified deployed addresses, explorer verification, and pending fork/testnet randomizer evidence | Production broadcast retention, production admin ceremony evidence, verified deployed addresses, and explorer verification missing |
| Release artifacts | Release manifest, checksum bundle, bytecode-to-release proof, release-candidate lockfile, risk register, ABI baseline, gas snapshot, gas envelope baseline, protocol surface report, source verification inputs, address books, ceremony evidence, admin ceremony evidence schema/template/checker, randomizer operations evidence, release-signature evidence, production release-signing checker and retained artifact, drop authorization signing fixtures, unsigned payload-generator examples, drop authorization signing evidence schema/template/checker, signer custody readiness schema/template/checker, 1/1 provenance manifest schema/template/checker/generated catalog, collector-verifiable permanence package schema/template/checker/generated one-of-one permanence manifest, public-beta evidence status, generated public-beta and production-release blocker reports, release evidence packet index, release evidence issue backlog, release evidence issue links, release evidence issue body sync, release evidence issue closure readiness, non-local release evidence runbook/schema/generic template, external audit retained-artifact template/checker, testnet deployment retained-artifact template/checker, public-beta verified-addresses checker and retained artifact, reviewed fork retained artifact/evidence envelope, per-requirement public-beta and production-release templates, and checker exist for the local baseline | Live release artifacts, live bytecode proof, production signing evidence, reviewed 1/1 provenance evidence where used for collector-facing claims, reviewed permanence packages with browser proof and output hashes where used for collector-facing claims, reviewed signer custody readiness, reviewed admin ceremony evidence, reviewed testnet/live retained evidence, verified deployed addresses, explorer verification, and completed external audit evidence missing | Production signatures, signed Git tags, reviewed 1/1 provenance evidence and reviewed collector permanence evidence where used for production collector-facing claims, and reviewed live bytecode proof missing |
| Static analysis and tests | The normalized first-party production Slither baseline contains 44 retained findings (4 High and 40 Medium): 30 remain Open (2 High, 28 Medium) and 14 rows (2 High, 12 Medium) have focused, source-traced False Positive dispositions; `RISK-GOV-003` separately preserves the Governance Executor native-value authority hidden from Slither by bounded assembly; an exact metadata/drift gate, warning disposition baseline, NatSpec coverage baseline, test matrix, invariants, local gas snapshot, and local gas envelope ceilings are tracked | Yes: 30 Slither rows and `RISK-GOV-003` remain Open, and testnet/live invariant and gas evidence is missing | Yes: open Slither findings, `RISK-GOV-003`, external audit, and production evidence are missing |

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
  and [`tools/release/check_drop_authorization_signing_evidence.py`](../tools/release/check_drop_authorization_signing_evidence.py);
- signer custody readiness guidance, schema, checked template, and checker in
  [`docs/signer-custody-readiness.md`](signer-custody-readiness.md),
  [`release-artifacts/schema/signer-custody-readiness.schema.json`](../release-artifacts/schema/signer-custody-readiness.schema.json),
  [`release-artifacts/signer-custody-readiness/signer-custody-readiness-template.json`](../release-artifacts/signer-custody-readiness/signer-custody-readiness-template.json),
  [`release-artifacts/signer-custody-readiness/signer-custody-readiness-retained-artifact.txt`](../release-artifacts/signer-custody-readiness/signer-custody-readiness-retained-artifact.txt),
  and [`tools/release/check_signer_custody_readiness.py`](../tools/release/check_signer_custody_readiness.py);
- 1/1 provenance manifest guidance, schema, checked template, retained-artifact
  checklist, generated release catalog, and checker in
  [`docs/provenance-manifests.md`](provenance-manifests.md),
  [`release-artifacts/schema/one-of-one-provenance-manifest.schema.json`](../release-artifacts/schema/one-of-one-provenance-manifest.schema.json),
  [`release-artifacts/provenance/one-of-one-provenance-template.provenance.json`](../release-artifacts/provenance/one-of-one-provenance-template.provenance.json),
  [`release-artifacts/provenance/one-of-one-provenance-retained-artifact-template.md`](../release-artifacts/provenance/one-of-one-provenance-retained-artifact-template.md),
  [`release-artifacts/latest/one-of-one-provenance-manifest.json`](../release-artifacts/latest/one-of-one-provenance-manifest.json),
  [`tools/protocol/check_one_of_one_provenance_manifest.py`](../tools/protocol/check_one_of_one_provenance_manifest.py),
  and
  [`tools/protocol/generate_one_of_one_provenance_manifest.py`](../tools/protocol/generate_one_of_one_provenance_manifest.py),
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
  [`tools/protocol/check_one_of_one_permanence_package.py`](../tools/protocol/check_one_of_one_permanence_package.py),
  and
  [`tools/protocol/generate_one_of_one_permanence_manifest.py`](../tools/protocol/generate_one_of_one_permanence_manifest.py),
  which establish the artifact-only replay command, renderer/dependency/source
  hash, browser proof, output hash, and fully on-chain versus decentralized
  storage boundary without claiming final collector proof until reviewed
  non-local or final-drop evidence exists;
- royalty policy guidance in
  [`docs/royalty-policy.md`](royalty-policy.md), covered by
  `python -m tools.docs.test_royalty_policy` and
  `python -m tools.docs.check_royalty_policy`, which documents current ERC-2981
  disclosure, governance and enforcement boundaries, marketplace display
  guidance, and the rule that No production-readiness claim depends on
  marketplaces honoring royalties;
- warning disposition guidance in
  [`docs/warning-dispositions.md`](warning-dispositions.md), covered by
  `python -m tools.security.test_warning_dispositions`,
  `python -m tools.build.run_forge_size_log --log cache/forge-size.log`, and
  `python -m tools.security.check_warning_dispositions --solc-warnings-log cache/forge-size.log`, which documents fixed NatSpec
  warning noise and accepted solc, documentation, linter, vendored, test-only,
  ABI-compatibility, and `StreamCore` size-tradeoff warning decisions without
  treating warning quietness as protocol correctness proof;
- release manifest and checksum bundle outputs under
  [`release-artifacts/latest/release-manifest.json`](../release-artifacts/latest/release-manifest.json),
  [`release-artifacts/latest/SHA256SUMS`](../release-artifacts/latest/SHA256SUMS),
  and [`release-artifacts/latest/release-checksums.json`](../release-artifacts/latest/release-checksums.json);
  ADR 0017 is a direct release-manifest governance document and a direct
  checksum-generator input, so any change to the raise-only target invalidates
  both artifacts until their canonical regeneration;
- the canonical, non-generated release-tool call policy and schema under
  `release-artifacts/release-tool-call-policy.json`
  and
  [`release-artifacts/schema/release-tool-call-policy.v1.schema.json`](../release-artifacts/schema/release-tool-call-policy.v1.schema.json).
  The policy binds the exact 22 runtime and nine focused-test source rows by
  role, hash, size, and reviewed import/member/call multisets. Code separately
  pins the seven roots, those exact 31 paths, and allowed dangerous-capability
  membership, so the policy cannot expand its own authority. The release
  manifest and candidate lockfile bind both files by exact path, SHA-256, byte
  size, and schema identity/version; both checksum indexes cover them, the
  offline verifier consumes immutable covered-file snapshots, and public-beta
  plus production release mode fail closed when validation fails. The revised
  canonical projection is exactly 263 configured roots and 432 covered-file
  entries in each checksum index;
- the schema-validated governed-parameter inventory under
  [`release-artifacts/governed-parameter-inventory.json`](../release-artifacts/governed-parameter-inventory.json),
  its
  [`v1 schema`](../release-artifacts/schema/governed-parameter-inventory.v1.schema.json),
  and the `tools/protocol/test_governed_parameter_inventory.py` /
  `tools/protocol/check_governed_parameter_inventory.py` pair. The ordinary check
  proves exact policy and honest incompleteness; it does not satisfy the
  production-only `--require-complete` decision;
- the record-family authorization source implementation catalog, retained
  historical inventory, schemas, and template under
  [`release-artifacts/record-family-authorization-source-catalog.json`](../release-artifacts/record-family-authorization-source-catalog.json),
  [`release-artifacts/schema/record-family-authorization-source-catalog.v1.schema.json`](../release-artifacts/schema/record-family-authorization-source-catalog.v1.schema.json),
  [`release-artifacts/record-family-authorization-inventory.json`](../release-artifacts/record-family-authorization-inventory.json),
  [`release-artifacts/schema/record-family-authorization-inventory.v1.schema.json`](../release-artifacts/schema/record-family-authorization-inventory.v1.schema.json),
  [`deployments/schema/record-family-authorization-evidence.v1.schema.json`](../deployments/schema/record-family-authorization-evidence.v1.schema.json),
  [`deployments/schema/record-family-authorization-grant-map.v1.schema.json`](../deployments/schema/record-family-authorization-grant-map.v1.schema.json),
  and
  [`deployments/record-family-authorization/record-family-authorization-evidence-template.json`](../deployments/record-family-authorization/record-family-authorization-evidence-template.json).
  Run `python -m tools.protocol.test_record_family_authorization` and
  `python -m tools.protocol.check_record_family_authorization`. A future complete
  envelope must bind its `grant_map.path` to the separate phase- and
  candidate-bound `public-beta-record-family-authorization-grant-map.json` or
  `production-release-record-family-authorization-grant-map.json` artifact in
  `deployments/record-family-authorization/`; production evidence also
  hash-binds and fully revalidates the canonical public-beta retained envelope.
  Each grant map must also hash-bind the source catalog and enumerate its exact
  numeric class/mode and family-ID maps, live providers, per-type class masks
  and lock policy, active family grants, the two runtime hosts, and
  both hosts' exact shared record-family registry address. The classifier and
  both host-support rows must agree on configuration revision/hash,
  record-type count, chain ID, and finalized observation block; any later
  admission/provider/grant mutation invalidates the map and requires a new
  retained observation and review.
  Preservation record hashes and latest pointers include recorder identity.
  `deriveCollectionRecordHash` and `latestCollectionRecordHash` use the caller,
  while their `For` variants accept an explicit nonzero recorder; evidence and
  indexers must not interpret the convenience latest read as a global
  collection/type/subject pointer.
  Record-family semantic revalidation binds exactly twelve source inputs:
  `smart-contracts/interfaces/stream/records/IStreamRecordFamilyAuthorityProvider.sol`,
  `smart-contracts/interfaces/stream/records/IStreamRecordFamilyRegistry.sol`,
  `smart-contracts/domains/records/StreamRecordFamilyRegistry.sol`,
  `smart-contracts/domains/metadata/StreamCollectionMetadata.sol`,
  `smart-contracts/interfaces/stream/metadata/IStreamCollectionMetadata.sol`,
  `smart-contracts/domains/preservation/StreamPreservationRecords.sol`,
  `smart-contracts/interfaces/stream/preservation/IStreamPreservationRecords.sol`,
  `script/legacy/RehearseDeployment.s.sol`, plus the catalog-named suites
  `test/regression/legacy/records/StreamRecordFamilyAuthorization.t.sol`,
  `test/regression/legacy/metadata/StreamCollectionMetadata.t.sol`,
  `test/regression/legacy/preservation/StreamPreservationRecords.t.sol`, and
  `test/regression/legacy/protocol/StreamDeploymentManifest.t.sol`. These are twelve exact
  checksum roots and entries, not broad `smart-contracts/` coverage. The
  offline verifier snapshots the complete canonical set, materializes
  it under a temporary root, and loads the checker and all twelve inputs there;
  record-family semantic validation has no live-path fallback after snapshot
  acquisition.
  The release manifest and candidate lockfile both bind the source catalog,
  source-catalog schema, historical inventory, inventory schema, evidence
  schema, grant-map schema, and template records.
  The checksum bundle binds the package plus checker/tests, and the
  offline verifier revalidates both semantic and cross-artifact bindings. These
  prove source implementation but are not candidate-bound deployment or
  readiness evidence;
- protocol surface report guidance and generated output under
  [`docs/protocol-surface.md`](protocol-surface.md) and
  [`release-artifacts/latest/protocol-surface-report.json`](../release-artifacts/latest/protocol-surface-report.json),
  covered by `python -m tools.build.test_protocol_surface_report` and
  `python -m tools.build.generate_protocol_surface_report --check`;
- NatSpec coverage guidance and checked baseline under
  [`docs/natspec-coverage.md`](natspec-coverage.md) and
  [`release-artifacts/natspec-coverage.json`](../release-artifacts/natspec-coverage.json),
  covered by `python -m tools.build.test_natspec_coverage` and
  `python -m tools.build.check_natspec_coverage`, which keeps new undocumented
  release-surface entries from entering silently without claiming the current
  API documentation is complete;
- bytecode-to-release proof under
  [`release-artifacts/latest/bytecode-release-proof.json`](../release-artifacts/latest/bytecode-release-proof.json),
  covered by `python -m tools.build.test_bytecode_release_proof` and
  `python -m tools.build.generate_bytecode_release_proof --check`, which tie
  committed local/fork addresses and runtime bytecode hashes to the release
  manifest without claiming live production bytecode verification;
- release-candidate lockfile under
  [`release-artifacts/latest/release-candidate-lockfile.json`](../release-artifacts/latest/release-candidate-lockfile.json),
  covered by `python -m tools.release.test_release_candidate_lockfile` and
  `python -m tools.release.generate_release_candidate_lockfile --check`, which ties
  release manifest, bytecode proof, evidence status, risk register, blocker
  reports, release notes, release-signature evidence, the release-tool call
  policy/schema records, and explicit non-release commit/tag/signature status
  without claiming launch readiness;
- generated risk register under
  [`release-artifacts/latest/risk-register.json`](../release-artifacts/latest/risk-register.json),
  backed by
  [`release-artifacts/schema/risk-register.schema.json`](../release-artifacts/schema/risk-register.schema.json),
  `python -m tools.security.test_risk_register`,
  `python -m tools.security.check_risk_register`, and
  `python -m tools.security.generate_risk_register --check`, which summarize launch
  blockers, accepted local-baseline risks, planned mitigations, source-document
  hashes, and evidence links without changing readiness claims;
- canonical normalized Slither evidence under
  [`ops/SLITHER_BASELINE.json`](../ops/SLITHER_BASELINE.json) and its
  [`ops/SLITHER_BASELINE.md`](../ops/SLITHER_BASELINE.md) reviewer mirror,
  checked by
  [`tools/security/check_slither_baseline.py`](../tools/security/check_slither_baseline.py)
  and [`tools/security/test_slither_baseline.py`](../tools/security/test_slither_baseline.py)
  with `python -m tools.security.test_slither_baseline`,
  `python -m tools.security.check_slither_baseline --baseline-only`, and
  `python -m tools.security.check_slither_baseline --run-slither`; the 2 High and 30
  Medium first-party production rows remain Open and block release;
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
  `python -m tools.release.test_signed_release_tag` and
  `python -m tools.release.check_signed_release_tag`; the default non-release mode
  runs in local and CI gates without claiming release status, while strict
  release mode requires a matching signed tag, current checksum bundle, and
  post-bundle release-signature evidence outside the `SHA256SUMS` coverage set;
- production release-signing retained artifact coverage through
  [`release-artifacts/evidence/production-release-signing/production-release-signing-retained-artifact-template.md`](../release-artifacts/evidence/production-release-signing/production-release-signing-retained-artifact-template.md),
  [`tools/release/test_production_release_signing_evidence.py`](../tools/release/test_production_release_signing_evidence.py),
  and
  [`tools/release/check_production_release_signing_evidence.py`](../tools/release/check_production_release_signing_evidence.py),
  which validates future retained `production_signatures` and `signed_git_tag`
  references, optional declared `sha256:` hashes, no-secret redaction, release
  signature evidence JSON alignment, and signed-tag checker handoff without
  claiming issues #223 or #224 are complete;
- no-secret admin ceremony evidence schema, template, retained-artifact
  checklist, and checker under
  [`deployments/schema/admin-ceremony-evidence.schema.json`](../deployments/schema/admin-ceremony-evidence.schema.json),
  [`deployments/admin-ceremony/admin-ceremony-evidence-template.json`](../deployments/admin-ceremony/admin-ceremony-evidence-template.json),
  [`deployments/admin-ceremony/admin-ceremony-retained-artifact-template.md`](../deployments/admin-ceremony/admin-ceremony-retained-artifact-template.md),
  and [`tools/deployment/check_admin_ceremony_evidence.py`](../tools/deployment/check_admin_ceremony_evidence.py);
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
  `python -m tools.release.test_release_evidence_issue_snapshot` and
  `python -m tools.release.test_release_evidence_issue_snapshot_audit`, including
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
  `python -m tools.release.test_release_evidence_live_audit_report` and
  `python -m tools.release.check_release_evidence_live_audit_report`,
  `python -m tools.release.test_release_evidence_live_audit_markdown`, and
  `python -m tools.release.check_release_evidence_live_audit_markdown`, plus the
  release evidence live audit report archive at
  [`release-artifacts/latest/release-evidence-live-audit-report-archive.json`](../release-artifacts/latest/release-evidence-live-audit-report-archive.json)
  and
  [`release-artifacts/latest/release-evidence-live-audit-report-archive.md`](../release-artifacts/latest/release-evidence-live-audit-report-archive.md),
  checked with `python -m tools.release.test_release_evidence_live_audit_archive` and
  `python -m tools.release.generate_release_evidence_live_audit_archive --check`,
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
  validated with `python -m tools.release.test_production_broadcast_retention` and
  `python -m tools.release.check_production_broadcast_retention`,
  plus the live deployment manifest checker and retained artifact template
  under
  [`release-artifacts/evidence/live-deployment-manifest/live-deployment-manifest-retained-artifact-template.md`](../release-artifacts/evidence/live-deployment-manifest/live-deployment-manifest-retained-artifact-template.md),
  validated with `python -m tools.release.test_live_deployment_manifest_evidence`
  and `python -m tools.release.check_live_deployment_manifest_evidence`,
  plus the public-beta verified-addresses checker and public-beta
  verified-addresses retained artifact template under
  [`release-artifacts/evidence/public-beta-verified-addresses/public-beta-verified-addresses-retained-artifact-template.md`](../release-artifacts/evidence/public-beta-verified-addresses/public-beta-verified-addresses-retained-artifact-template.md),
  validated with
  [`tools/release/test_public_beta_verified_addresses.py`](../tools/release/test_public_beta_verified_addresses.py)
  and
  [`tools/release/check_public_beta_verified_addresses.py`](../tools/release/check_public_beta_verified_addresses.py),
  plus the Sepolia evidence preflight checker for no-secret public-beta
  rehearsal prerequisites, validated with
  [`tools/deployment/test_sepolia_evidence_preflight.py`](../tools/deployment/test_sepolia_evidence_preflight.py)
  and
  [`tools/deployment/check_sepolia_evidence_preflight.py`](../tools/deployment/check_sepolia_evidence_preflight.py),
  plus the production verified-addresses checker and production
  verified-addresses retained artifact template under
  [`release-artifacts/evidence/production-verified-addresses/production-verified-addresses-retained-artifact-template.md`](../release-artifacts/evidence/production-verified-addresses/production-verified-addresses-retained-artifact-template.md),
  validated with `python -m tools.release.test_production_verified_addresses` and
  `python -m tools.release.check_production_verified_addresses`,
  plus fork/testnet metadata-browser evidence for
  `fork_testnet_metadata_browser_evidence` under
  [`release-artifacts/evidence/fork-metadata-browser/fork-metadata-browser-retained-artifact-template.md`](../release-artifacts/evidence/fork-metadata-browser/fork-metadata-browser-retained-artifact-template.md),
  validated offline with `python -m tools.release.test_fork_metadata_browser_evidence`
  and `python -m tools.release.check_fork_metadata_browser_evidence`,
  plus fork/testnet ceremony evidence for `fork_testnet_ceremony_evidence`
  under
  [`release-artifacts/evidence/fork-ceremony/fork-ceremony-retained-artifact-template.md`](../release-artifacts/evidence/fork-ceremony/fork-ceremony-retained-artifact-template.md),
  validated offline with `python -m tools.deployment.test_fork_ceremony_evidence` and
  `python -m tools.deployment.check_fork_ceremony_evidence`; the current CON-015
  artifact set is pending re-review before this row can return to complete,
  plus fork/testnet randomizer operations evidence for
  `fork_testnet_randomizer_operations_evidence` under
  [`release-artifacts/evidence/fork-randomizer-operations/fork-randomizer-operations-retained-artifact-template.md`](../release-artifacts/evidence/fork-randomizer-operations/fork-randomizer-operations-retained-artifact-template.md),
  validated offline with
  `python -m tools.deployment.test_fork_randomizer_operations_evidence` and
  `python -m tools.deployment.check_fork_randomizer_operations_evidence`,
  plus live metadata-browser evidence for `live_metadata_browser_evidence`
  under
  [`release-artifacts/evidence/live-metadata-browser/live-metadata-browser-retained-artifact-template.md`](../release-artifacts/evidence/live-metadata-browser/live-metadata-browser-retained-artifact-template.md),
  validated offline with `python -m tools.release.test_live_metadata_browser_evidence`
  and `python -m tools.release.check_live_metadata_browser_evidence`,
  plus live ceremony evidence for `live_ceremony_evidence` under
  [`release-artifacts/evidence/live-ceremony/live-ceremony-retained-artifact-template.md`](../release-artifacts/evidence/live-ceremony/live-ceremony-retained-artifact-template.md),
  validated offline with `python -m tools.deployment.test_live_ceremony_evidence` and
  `python -m tools.deployment.check_live_ceremony_evidence`,
  plus live randomizer operations evidence for
  `live_randomizer_operations_evidence` under
  [`release-artifacts/evidence/live-randomizer-operations/live-randomizer-operations-retained-artifact-template.md`](../release-artifacts/evidence/live-randomizer-operations/live-randomizer-operations-retained-artifact-template.md),
  validated offline with
  `python -m tools.deployment.test_live_randomizer_operations_evidence` and
  `python -m tools.deployment.check_live_randomizer_operations_evidence`,
  plus incident drill evidence for `incident_drill_evidence` under
  [`release-artifacts/evidence/incident-drills/incident-drill-retained-artifact-template.md`](../release-artifacts/evidence/incident-drills/incident-drill-retained-artifact-template.md),
  validated offline with `python -m tools.release.test_incident_drill_evidence` and
  `python -m tools.release.check_incident_drill_evidence`,
  plus signer compromise drill evidence for
  `signer_compromise_drill_evidence` under
  [`release-artifacts/evidence/incident-drills/signer-compromise-drill-retained-artifact-template.md`](../release-artifacts/evidence/incident-drills/signer-compromise-drill-retained-artifact-template.md),
  validated offline with
  `python -m tools.release.test_signer_compromise_drill_evidence` and
  `python -m tools.release.check_signer_compromise_drill_evidence`,
  plus stuck auction drill evidence for `stuck_auction_drill_evidence` under
  [`release-artifacts/evidence/incident-drills/stuck-auction-drill-retained-artifact-template.md`](../release-artifacts/evidence/incident-drills/stuck-auction-drill-retained-artifact-template.md),
  validated offline with
  `python -m tools.release.test_stuck_auction_drill_evidence` and
  `python -m tools.release.check_stuck_auction_drill_evidence`,
  plus failed randomness drill evidence for `failed_randomness_drill_evidence`
  under
  [`release-artifacts/evidence/incident-drills/failed-randomness-drill-retained-artifact-template.md`](../release-artifacts/evidence/incident-drills/failed-randomness-drill-retained-artifact-template.md),
  validated offline with
  `python -m tools.release.test_failed_randomness_drill_evidence` and
  `python -m tools.release.check_failed_randomness_drill_evidence`,
  plus bad metadata/dependency drill evidence for
  `bad_metadata_dependency_drill_evidence` under
  [`release-artifacts/evidence/incident-drills/bad-metadata-dependency-drill-retained-artifact-template.md`](../release-artifacts/evidence/incident-drills/bad-metadata-dependency-drill-retained-artifact-template.md),
  validated offline with
  `python -m tools.protocol.test_bad_metadata_dependency_drill_evidence` and
  `python -m tools.protocol.check_bad_metadata_dependency_drill_evidence`,
  plus post-audit remediation evidence for `post_audit_remediation` under
  [`release-artifacts/evidence/post-audit-remediation/post-audit-remediation-retained-artifact-template.md`](../release-artifacts/evidence/post-audit-remediation/post-audit-remediation-retained-artifact-template.md),
  validated offline with
  `python -m tools.release.test_post_audit_remediation_evidence` and
  `python -m tools.release.check_post_audit_remediation_evidence`,
  plus deterministic tracker-label checks with
  `python -m tools.release.test_release_evidence_issue_labels` and
  `python -m tools.release.check_release_evidence_issue_labels`,
  plus the generated exact issue body payloads at
  [`release-artifacts/latest/release-evidence-issue-body-sync.json`](../release-artifacts/latest/release-evidence-issue-body-sync.json)
  and
  [`release-artifacts/latest/release-evidence-issue-body-sync.md`](../release-artifacts/latest/release-evidence-issue-body-sync.md),
  plus deterministic tracker-body checks with
  `python -m tools.release.test_release_evidence_issue_bodies` and
  `python -m tools.release.check_release_evidence_issue_bodies`, plus release
  evidence issue closure readiness checks with
  `python -m tools.release.test_release_evidence_issue_closure` and
  `python -m tools.release.check_release_evidence_issue_closure`, plus an
  authenticated live tracker sync gate with
  `python -m tools.release.fetch_release_evidence_issue_snapshot` and
  `make release-evidence-live-issue-sync-check`;
- non-local release evidence intake requirements, schema, checked template, and
  checker under [`docs/non-local-release-evidence.md`](non-local-release-evidence.md),
  [`release-artifacts/schema/non-local-release-evidence.schema.json`](../release-artifacts/schema/non-local-release-evidence.schema.json),
  [`release-artifacts/evidence/non-local-release-evidence-template.json`](../release-artifacts/evidence/non-local-release-evidence-template.json),
  [`release-artifacts/evidence/fork-deployment-rehearsal/fork-deployment-rehearsal-retained-artifact-template.md`](../release-artifacts/evidence/fork-deployment-rehearsal/fork-deployment-rehearsal-retained-artifact-template.md),
  [`release-artifacts/evidence/public-beta-templates/`](../release-artifacts/evidence/public-beta-templates/),
  [`release-artifacts/evidence/production-release-templates/`](../release-artifacts/evidence/production-release-templates/),
  [`tools/release/check_non_local_release_evidence.py`](../tools/release/check_non_local_release_evidence.py),
  and
  [`tools/deployment/check_fork_deployment_rehearsal_evidence.py`](../tools/deployment/check_fork_deployment_rehearsal_evidence.py);
- Slither baseline evidence in
  [`ops/SLITHER_BASELINE.json`](../ops/SLITHER_BASELINE.json),
  [`ops/SLITHER_BASELINE.md`](../ops/SLITHER_BASELINE.md), and
  [`docs/slither.md`](slither.md);
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
- reviewed incident drill evidence for mint pause, bid pause, settlement pause,
  withdrawal policy, failed randomness, stuck auction, bad metadata or
  dependency configuration, bad Merkle root, and signer compromise drills;
- reviewed signer compromise drill evidence for drop-execution pause, signer
  rotation or revocation, signer epoch invalidation, per-drop cancellation,
  stale payload rejection, recovered payload execution, monitoring
  confirmation, reviewer approval, and redaction;
- reviewed stuck auction drill evidence for auction identity, stuck condition,
  custody, pause/unpause, settlement or cancellation outcome, bidder and
  proceeds credits, withdrawal availability, emergency-surplus boundary,
  monitoring handoff, reviewer approval, and redaction;
- reviewed bad metadata/dependency drill evidence for metadata schema/state,
  token URI snapshots, URI/UTF-8/raw-attributes or browser-sandbox failure,
  dependency key/version/content hash, freeze and repin boundary, ERC-4906/cache
  invalidation, marketplace/indexer handoff, reviewer approval, and redaction;
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
- [docs/production-readiness-execution.md](production-readiness-execution.md)

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
- [ops/SLITHER_BASELINE.json](../ops/SLITHER_BASELINE.json)
- [tools/security/check_slither_baseline.py](../tools/security/check_slither_baseline.py)
- [tools/security/test_slither_baseline.py](../tools/security/test_slither_baseline.py)
- [docs/integrations/README.md](integrations/README.md)
- [docs/integrations/contract-flows.md](integrations/contract-flows.md)
- [docs/integrations/auction-flows.md](integrations/auction-flows.md)
- [docs/integrations/wallets-and-signatures.md](integrations/wallets-and-signatures.md)
- [docs/integrations/events-and-indexing.md](integrations/events-and-indexing.md)
- [docs/integrations/metadata-rendering.md](integrations/metadata-rendering.md)
- [docs/integrations/marketplace-indexer-evidence.md](integrations/marketplace-indexer-evidence.md)
- [docs/reference/legacy-stack/integrations/frontend-reference-architecture.md](reference/legacy-stack/integrations/frontend-reference-architecture.md)
- [docs/reference/legacy-stack/integrations/mobile-walletconnect.md](reference/legacy-stack/integrations/mobile-walletconnect.md)
- [docs/reference/legacy-stack/integrations/electron-security-wallets.md](reference/legacy-stack/integrations/electron-security-wallets.md)
- [docs/reference/legacy-stack/integrations/operator-admin-ui.md](reference/legacy-stack/integrations/operator-admin-ui.md)
- [docs/monitoring.md](monitoring.md)
- [docs/operator-dashboard-query-model.md](operator-dashboard-query-model.md)
- [docs/reference/legacy-stack/integrations/examples/react-viem.md](reference/legacy-stack/integrations/examples/react-viem.md)

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
- [release-artifacts/evidence/public-beta-verified-addresses/public-beta-verified-addresses-retained-artifact-template.md](../release-artifacts/evidence/public-beta-verified-addresses/public-beta-verified-addresses-retained-artifact-template.md)
- [release-artifacts/evidence/production-release-templates/](../release-artifacts/evidence/production-release-templates/)
- [release-artifacts/baselines/v0.1.0/abi-surface.json](../release-artifacts/baselines/v0.1.0/abi-surface.json)
- [release-artifacts/baselines/v0.1.0/gas-snapshot.snap](../release-artifacts/baselines/v0.1.0/gas-snapshot.snap)
- [release-artifacts/baselines/v0.1.0/gas-envelopes.json](../release-artifacts/baselines/v0.1.0/gas-envelopes.json)
- [release-artifacts/natspec-coverage.json](../release-artifacts/natspec-coverage.json)
- [deployments/ceremony-evidence/anvil-6529stream-v0.1.0-001-local.json](../deployments/ceremony-evidence/anvil-6529stream-v0.1.0-001-local.json)
- [deployments/randomizer-operations/anvil-6529stream-v0.1.0-001-local.json](../deployments/randomizer-operations/anvil-6529stream-v0.1.0-001-local.json)
- [release-artifacts/signatures/anvil-6529stream-v0.1.0-001-local.json](../release-artifacts/signatures/anvil-6529stream-v0.1.0-001-local.json)

## Release Commands

Run the dashboard checker directly:

```sh
python -m tools.release.test_release_readiness
python -m tools.release.check_release_readiness
python -m tools.release.test_release_mode
python -m tools.release.check_release_mode --phase public-beta
python -m tools.release.check_release_mode --phase production-release
python -m tools.release.test_production_broadcast_retention
python -m tools.release.check_production_broadcast_retention
python -m tools.release.test_public_beta_verified_addresses
python -m tools.release.check_public_beta_verified_addresses
python -m tools.deployment.test_sepolia_evidence_preflight
python -m tools.deployment.check_sepolia_evidence_preflight
python -m tools.release.test_production_verified_addresses
python -m tools.release.check_production_verified_addresses
python -m tools.release.test_signed_release_tag
python -m tools.release.check_signed_release_tag
python -m tools.release.test_production_release_signing_evidence
python -m tools.release.check_production_release_signing_evidence
python -m tools.docs.test_incident_response
python -m tools.docs.check_incident_response
python -m tools.release.test_stuck_auction_drill_evidence
python -m tools.release.check_stuck_auction_drill_evidence
python -m tools.release.test_failed_randomness_drill_evidence
python -m tools.release.check_failed_randomness_drill_evidence
python -m tools.protocol.test_bad_metadata_dependency_drill_evidence
python -m tools.protocol.check_bad_metadata_dependency_drill_evidence
python -m tools.docs.test_contract_flows
python -m tools.docs.check_contract_flows
python -m tools.docs.test_auction_flows
python -m tools.docs.check_auction_flows
python -m tools.docs.test_wallet_signature_flows
python -m tools.docs.check_wallet_signature_flows
python -m tools.docs.test_events_and_indexing
python -m tools.docs.check_events_and_indexing
python -m tools.docs.test_metadata_rendering
python -m tools.docs.check_metadata_rendering
python -m tools.release.test_marketplace_indexer_evidence
python -m tools.release.check_marketplace_indexer_evidence
python -m tools.docs.test_react_next_reference
python -m tools.docs.check_react_next_reference
python -m tools.docs.test_mobile_walletconnect
python -m tools.docs.check_mobile_walletconnect
python -m tools.docs.test_electron_security_wallets
python -m tools.docs.check_electron_security_wallets
python -m tools.docs.test_operator_admin_ui
python -m tools.docs.check_operator_admin_ui
python -m tools.docs.test_operator_dashboard_query_model
python -m tools.docs.check_operator_dashboard_query_model
python -m tools.docs.test_monitoring_spec
python -m tools.docs.check_monitoring_spec
python -m tools.protocol.test_drop_authorization_payload_generator
python -m tools.protocol.generate_drop_authorization_payload --input test/fixtures/drop-authorization/payload-generator/fixed-price-input.json --output test/fixtures/drop-authorization/payload-generator/fixed-price-output.json --check
python -m tools.protocol.generate_drop_authorization_payload --input test/fixtures/drop-authorization/payload-generator/auction-input.json --output test/fixtures/drop-authorization/payload-generator/auction-output.json --check
python -m tools.protocol.test_drop_authorization_fixtures
python -m tools.protocol.check_drop_authorization_fixtures
python -m tools.release.test_drop_authorization_signing_evidence
python -m tools.release.check_drop_authorization_signing_evidence
python -m tools.release.test_signer_custody_readiness
python -m tools.release.check_signer_custody_readiness
python -m tools.protocol.test_one_of_one_provenance_manifest
python -m tools.protocol.check_one_of_one_provenance_manifest
python -m tools.protocol.generate_one_of_one_provenance_manifest --check
python -m tools.protocol.test_one_of_one_permanence_package
python -m tools.protocol.check_one_of_one_permanence_package
python -m tools.protocol.generate_one_of_one_permanence_manifest --check
python -m tools.docs.test_royalty_policy
python -m tools.docs.check_royalty_policy
python -m tools.security.test_warning_dispositions
python -m tools.build.run_forge_size_log --log cache/forge-size.log
python -m tools.security.check_warning_dispositions --solc-warnings-log cache/forge-size.log
python -m tools.build.test_natspec_coverage
python -m tools.build.check_natspec_coverage
python -m tools.protocol.test_gas_envelopes
python -m tools.protocol.check_gas_envelopes
python -m tools.release.test_public_beta_evidence
python -m tools.release.check_public_beta_evidence
python -m tools.security.test_risk_register
python -m tools.security.check_risk_register
python -m tools.security.generate_risk_register --check
python -m tools.release.test_production_release_blocker_report
python -m tools.release.generate_production_release_blocker_report --check
python -m tools.release.test_release_evidence_packet_index
python -m tools.release.generate_release_evidence_packet_index --check
python -m tools.release.test_release_evidence_issue_backlog
python -m tools.release.generate_release_evidence_issue_backlog --check
python -m tools.release.test_release_evidence_issue_links
python -m tools.release.check_release_evidence_issue_links
python -m tools.release.test_release_evidence_issue_snapshot
python -m tools.release.test_release_evidence_issue_snapshot_audit
python -m tools.release.test_release_evidence_live_audit_report
python -m tools.release.check_release_evidence_live_audit_report
python -m tools.release.test_release_evidence_live_audit_markdown
python -m tools.release.check_release_evidence_live_audit_markdown
python -m tools.release.test_release_evidence_live_audit_archive
python -m tools.release.generate_release_evidence_live_audit_archive --check
python -m tools.release.test_release_evidence_issue_labels
python -m tools.release.check_release_evidence_issue_labels
python -m tools.release.test_release_evidence_issue_body_sync
python -m tools.release.generate_release_evidence_issue_body_sync --check
python -m tools.release.test_release_evidence_issue_bodies
python -m tools.release.check_release_evidence_issue_bodies
python -m tools.release.test_release_evidence_issue_closure
python -m tools.release.check_release_evidence_issue_closure
python -m tools.release.test_non_local_release_evidence
python -m tools.release.check_non_local_release_evidence
```

Run the release evidence drift checks:

The release-tool call policy and schema are manually reviewed upstream inputs,
not generated outputs. Review any required policy update before running the
canonical generated tail in dependency order: risk register, release notes,
release manifest, bytecode proof, candidate lockfile, then checksum bundle.

```sh
python -m tools.release.audit_release_evidence_issue_snapshots --report-json tmp/release-evidence-live-audit-report.json --report-md tmp/release-evidence-live-audit-report.md
python -m tools.release.audit_release_evidence_issue_snapshots --generated-at YYYYMMDDTHHMMSSZ --report-json release-artifacts/evidence/live-audit-reports/YYYYMMDDTHHMMSSZ-release-evidence-live-audit-report.json --report-md release-artifacts/evidence/live-audit-reports/YYYYMMDDTHHMMSSZ-release-evidence-live-audit-report.md
python -m tools.release.check_release_evidence_live_audit_report --report-json tmp/release-evidence-live-audit-report.json
python -m tools.release.check_release_evidence_live_audit_report --report-json release-artifacts/evidence/live-audit-reports/YYYYMMDDTHHMMSSZ-release-evidence-live-audit-report.json
python -m tools.release.check_release_evidence_live_audit_markdown --report-json tmp/release-evidence-live-audit-report.json --report-md tmp/release-evidence-live-audit-report.md
python -m tools.release.check_release_evidence_live_audit_markdown --report-json release-artifacts/evidence/live-audit-reports/YYYYMMDDTHHMMSSZ-release-evidence-live-audit-report.json --report-md release-artifacts/evidence/live-audit-reports/YYYYMMDDTHHMMSSZ-release-evidence-live-audit-report.md
python -m tools.release.generate_release_evidence_live_audit_archive --archive-dir release-artifacts/evidence/live-audit-reports
python -m tools.release.generate_release_evidence_live_audit_archive --archive-dir release-artifacts/evidence/live-audit-reports --check
python -m tools.release.generate_release_evidence_live_audit_archive --check
python -m tools.release.check_signed_release_tag --mode release --tag vX.Y.Z --evidence path/to/post-bundle-release-signature-evidence.json
python -m tools.release.generate_release_manifest --check
python -m tools.release.generate_release_candidate_lockfile --check
python -m tools.release.generate_release_checksums --check
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
