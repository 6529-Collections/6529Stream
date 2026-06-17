# Tooling

6529Stream currently uses a pinned Foundry smoke baseline.

## Versions

| Tool | Version |
| --- | --- |
| Foundry | `v1.7.1` |
| Solidity compiler | `0.8.19` |
| Slither | `0.11.5` |
| solc-select | `1.2.0` |
| eth-hash | `0.8.0` |

## Local Checks

Fresh contributors should start with
[`first-30-minutes.md`](first-30-minutes.md). That checked guide explains the
minimal setup path, `forge` not being on `PATH`, Windows wrapper usage, known
warning noise, generated artifact drift, docs-only validation, Solidity/test
validation, and no-secret maturity boundaries.

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
python scripts/test_contract_size_budget.py
python scripts/check_contract_size_budget.py
python scripts/test_solidity_formatting.py
python scripts/check_solidity_formatting.py
python scripts/test_warning_dispositions.py
python scripts/run_forge_size_log.py --log cache/forge-size.log
python scripts/check_warning_dispositions.py --solc-warnings-log cache/forge-size.log
python scripts/test_drop_authorization_payload_generator.py
python scripts/generate_drop_authorization_payload.py --input test/fixtures/drop-authorization/payload-generator/fixed-price-input.json --output test/fixtures/drop-authorization/payload-generator/fixed-price-output.json --check
python scripts/generate_drop_authorization_payload.py --input test/fixtures/drop-authorization/payload-generator/auction-input.json --output test/fixtures/drop-authorization/payload-generator/auction-output.json --check
python scripts/test_drop_authorization_fixtures.py
python scripts/check_drop_authorization_fixtures.py
python scripts/test_drop_authorization_signing_evidence.py
python scripts/check_drop_authorization_signing_evidence.py
python scripts/test_signer_custody_readiness.py
python scripts/check_signer_custody_readiness.py
python scripts/test_admin_ceremony_evidence.py
python scripts/check_admin_ceremony_evidence.py
python scripts/test_release_artifacts.py
python scripts/generate_release_artifacts.py --check
python scripts/test_protocol_surface_report.py
python scripts/generate_protocol_surface_report.py --check
python scripts/test_custom_error_catalog.py
python scripts/generate_custom_error_catalog.py --check
python scripts/test_natspec_coverage.py
python scripts/check_natspec_coverage.py
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
python scripts/test_signed_release_tag.py
python scripts/check_signed_release_tag.py
python scripts/test_non_local_release_evidence_generator.py
python scripts/test_non_local_release_evidence.py
python scripts/check_non_local_release_evidence.py
python scripts/test_external_audit_report_evidence.py
python scripts/check_external_audit_report_evidence.py
python scripts/test_fork_deployment_rehearsal_evidence.py
python scripts/check_fork_deployment_rehearsal_evidence.py
python scripts/test_public_beta_evidence.py
python scripts/check_public_beta_evidence.py
python scripts/test_public_beta_blocker_report.py
python scripts/generate_public_beta_blocker_report.py --check
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
python scripts/test_architecture_threat_model.py
python scripts/check_architecture_threat_model.py
python scripts/test_audit_package.py
python scripts/check_audit_package.py
python scripts/test_incident_response.py
python scripts/check_incident_response.py
python scripts/test_readme.py
python scripts/check_readme.py
python scripts/test_first_30_minutes.py
python scripts/check_first_30_minutes.py
python scripts/test_issue_templates.py
python scripts/check_issue_templates.py
python scripts/test_pr_template.py
python scripts/check_pr_template.py
python scripts/test_markdown_links.py
python scripts/check_markdown_links.py
python scripts/test_curator_rewards_flow.py
python scripts/check_curator_rewards_flow.py
python scripts/test_withdrawals_credits_flow.py
python scripts/check_withdrawals_credits_flow.py
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

The protocol surface report step checks
[`release-artifacts/latest/protocol-surface-report.json`](../release-artifacts/latest/protocol-surface-report.json)
against the current production Foundry artifacts. It is an integrator and audit
review index over functions, selectors, events, topic0 values, custom errors,
ABI hashes, bytecode hashes, and runtime sizes; it is not a production-readiness
claim.

The custom error catalog step checks
[`release-artifacts/latest/custom-error-catalog.json`](../release-artifacts/latest/custom-error-catalog.json)
against the protocol surface report. It classifies release-relevant custom
errors by category and severity, records selector/signature data, and keeps
test traceability plus caller-action guidance visible for auditors and
integrators. It is documentation and traceability evidence, not a replacement
for the Solidity tests or external audit.

The NatSpec coverage step checks
[`release-artifacts/baselines/v0.1.0/natspec-coverage.json`](../release-artifacts/baselines/v0.1.0/natspec-coverage.json)
against the protocol surface report and first-party Solidity sources. It
requires nearby NatSpec for release-surface functions, public variable getters,
events, and custom errors unless the current gap is listed with an explicit
reason. The current baseline has 485 explicit exclusions, so it is a checked
burn-down queue rather than proof that API documentation is complete. See
[`natspec-coverage.md`](natspec-coverage.md).

The size step is the production deployability gate. It skips test and script
contracts so non-production artifacts do not pollute EIP-170/EIP-3860 evidence,
and it uses `via_ir` because the current deployable `StreamCore` release profile
needs the IR optimizer to fit under the runtime limit. The artifact-backed
budget checker reads `release-artifacts/contracts.json`, treats unlinked
Solidity library placeholders as their 20-byte deployed addresses for size
counting, fails below the 384-byte `StreamCore` minimum margin, and reports a
warning below the 512-byte future-work threshold. The checker also validates
artifact compiler metadata, optimizer settings, EVM version, compilation target,
and current-source Keccak hashes before trusting any reported runtime size, so
stale artifacts from earlier local commands fail before they can become release
evidence.

The Core bytecode-spend policy is stricter than the EIP-170 floor. It reads the
same production-size artifacts and pins the currently approved `StreamCore`
runtime baseline from `release-artifacts/contracts.json`. A future PR may reduce
Core runtime size without an exception, but any increase above the approved
baseline must add an accepted exception record with an issue, rationale,
measured delta, maximum approved runtime size, and mitigation before
`python scripts/check_core_bytecode_spend_policy.py` will pass.
The current approved `StreamCore` runtime baseline is 22,184 bytes with
2,392 bytes of EIP-170 margin.

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
The admin ceremony evidence checker validates the no-secret template under
`deployments/admin-ceremony/`, ties the retained artifact checklist and schema
to current hashes, and rejects reviewed evidence that still contains template
placeholders, invalid environment/chain pairs, zero privileged addresses,
secret-shaped values, path escapes, stale retained hashes, or incomplete
approval state.

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

The broadcast manifest input step parses the sanitized Foundry fixtures under
`deployments/broadcasts/`, rejects wrong-chain, failed-receipt,
missing-contract, unexpected-contract, duplicate, invalid-address, and
secret-like-key inputs, and checks the generated broadcast-derived configs
under `deployments/config/`. The default check covers both the local Anvil
fixture and the reviewed mainnet-fork rehearsal fixture for issue #216.
If a broadcast contains a linked library or helper deployment that is not part
of the public release contract set, list it explicitly in
`broadcast_evidence.ignored_deployments`; the generator records those ignored
deployments in the derived config instead of silently hiding them.

The deployment manifest step generates the local Anvil example from
`deployments/config/anvil-6529stream-v0.1.0-001.json`, fills contract ABI and
runtime bytecode hashes from `release-artifacts/latest/abi-checksums.json`,
generates the sanitized broadcast-derived manifest from
`deployments/config/anvil-6529stream-v0.1.0-001-broadcast.json`, generates the
reviewed fork broadcast manifest from
`deployments/config/fork-mainnet-6529stream-v0.1.0-001-broadcast.json`, and
checks that all committed examples have not drifted.

The address-book step projects committed deployment manifests into compact
integrator-facing JSON under `deployments/address-books/`. Address books keep
network/release metadata, source manifest checksums, contract addresses, source
paths, ABI hashes, runtime bytecode hashes, and verification status without the
full ceremony and constructor-argument details from deployment manifests. They
follow `deployments/schema/address-book.schema.json`, normalize addresses to
lowercase, and are regenerated with `python scripts/generate_address_books.py`.
The default drift check includes the Anvil placeholder, Anvil broadcast-derived,
and reviewed fork-mainnet broadcast-derived address books.

The bytecode-to-release proof step writes
`release-artifacts/latest/bytecode-release-proof.json` after release manifest
generation:

```sh
python scripts/test_bytecode_release_proof.py
python scripts/generate_bytecode_release_proof.py --check
```

The proof cross-checks address books, deployment manifests, ABI/runtime
bytecode hashes, source verification inputs, compiler settings, chain IDs, and
the current release manifest hash. It is checksum-covered and no-secret, but it
does not query live chain bytecode; live production bytecode proof remains a
reviewed non-local evidence requirement.

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
The optional live audit report bundle records the repository target, selected
issue-audit profiles, retained snapshot paths, snapshot digests, command
provenance, checker outcomes, explicit snapshot freshness/currentness claims,
and the unchanged blocked-readiness warning.

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
The incident drill evidence step validates the checked no-secret retained
artifact template under
[`release-artifacts/evidence/incident-drills/incident-drill-retained-artifact-template.md`](../release-artifacts/evidence/incident-drills/incident-drill-retained-artifact-template.md)
for mint pause, bid pause, settlement pause, withdrawal policy, failed
randomness, stuck auction, bad metadata/dependency, bad Merkle root, and signer
compromise drill evidence.
The signer compromise drill evidence step validates the narrower checked
retained artifact template under
[`release-artifacts/evidence/incident-drills/signer-compromise-drill-retained-artifact-template.md`](../release-artifacts/evidence/incident-drills/signer-compromise-drill-retained-artifact-template.md)
for drop-execution pause, signer rotation or revocation, signer epoch
invalidation, per-drop cancellation, stale/cancelled/wrong-domain payload
rejection, recovered fixed-price and auction payloads, monitoring handoff,
review, and redaction. It is source-aware and checks that the documented
response controls still exist in `StreamDrops`, `StreamPauseDomains`, and the
signer compromise/pause regression tests.
The stuck auction drill evidence step validates the narrower checked retained
artifact template under
[`release-artifacts/evidence/incident-drills/stuck-auction-drill-retained-artifact-template.md`](../release-artifacts/evidence/incident-drills/stuck-auction-drill-retained-artifact-template.md)
for auction identity, stuck condition, custody, pause/unpause, terminal
settlement or cancellation, bidder/proceeds credits, withdrawal availability,
surplus boundaries, monitoring handoff, review, and redaction. It is
source-aware and checks that auction settlement, no-bid recovery, cancellation,
pause, credit withdrawal, and surplus-boundary controls still exist in the
auction contract, pause domains, auction/pause tests, protocol state-machine
tests, and auction-flow integration docs.

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
separates passing local evidence and reviewed fork evidence from missing
testnet/live evidence, production signatures, signed Git tags, verified
deployed addresses, explorer verification, external audit, and post-audit
remediation blockers.
The monitoring specification step validates
[`monitoring.md`](monitoring.md), the checked `GOV-009` operations reference
for admin, signer, auction, randomizer, payment/credit, metadata/dependency,
release-evidence, alert-severity, dashboard-query, and incident-handoff
monitoring. It is not a maintained monitoring service, hosted dashboard, alert
provider integration, production indexer, public beta implementation, or
production readiness claim.
The operator dashboard query model step validates
[`operator-dashboard-query-model.md`](operator-dashboard-query-model.md), the
checked `GOV-010` operations reference that turns monitoring categories into
dashboard panels, query inputs, source artifacts, freshness states, severity
mapping, and no-secret telemetry boundaries. It is not a maintained dashboard,
hosted monitoring service, alert-provider integration, RPC provider, production
indexer, public beta implementation, or production readiness claim.
The release-mode CI profile is intentionally separate from `make check`: run
`python scripts/test_release_mode.py` in the default baseline, then use
`make release-mode-public-beta-check`,
`make release-mode-production-release-check`, or the manual GitHub
`workflow_dispatch` release-mode workflow only for release-candidate evidence
reviews. Those release-mode commands are expected to fail until retained
evidence is complete or explicitly accepted as risk, and production release
mode requires public-beta readiness before production-release readiness.

The public-beta evidence step validates
[`public-beta-evidence.md`](public-beta-evidence.md) and
`release-artifacts/latest/public-beta-evidence.json`, the no-secret status
manifest that keeps public beta and production release blocked until retained
non-local evidence or explicit risk acceptance exists.
The generated public-beta and production-release blocker reports render that
manifest into deterministic Markdown under `release-artifacts/latest/`, with
the production-focused report linking each production requirement to its
checked template under `release-artifacts/evidence/production-release-templates/`.
The release evidence packet index maps every public-beta and production-release
row to its blocker report, template, retained-artifact expectation, validation
commands, and current readiness posture without treating templates as
completion evidence.
The release evidence issue backlog turns those incomplete packet rows into a
deterministic issue-preparation artifact with suggested issue titles, labels,
bodies, retained-evidence completion gates, and validation commands. Run
`python scripts/generate_release_evidence_issue_backlog.py` to refresh it and
`python scripts/generate_release_evidence_issue_backlog.py --check` to verify
it. It does not create GitHub issues automatically or change readiness claims.
The release evidence issue-link map is committed at
`release-artifacts/latest/release-evidence-issue-links.json`; run
`python scripts/check_release_evidence_issue_links.py` to verify each generated
backlog entry has a durable tracker issue without querying GitHub during CI.
Run `python scripts/check_release_evidence_issue_labels.py` to verify committed
`applied_labels` are unique and drawn from the generated suggested label set.
To audit live GitHub tracker drift without adding network access to CI, run the
operator-only orchestrator:

```bash
python scripts/audit_release_evidence_issue_snapshots.py
```

Use `--profile labels`, `--profile bodies`, or `--profile closure` to run one
live audit profile. The orchestrator exports UTF-8 JSON snapshots with the
existing exporter and then runs the matching checker. To retain a no-secret
JSON and Markdown report bundle with the repo target, snapshot paths, snapshot
SHA-256 digests, profile results, command provenance, and the unchanged
blocked-readiness warning. Generated reports mark live snapshots as current at
generation time only; retained template or dry-run reports must explicitly mark
themselves historical and not current. To retain a bundle, pass explicit report
paths:

```bash
python scripts/audit_release_evidence_issue_snapshots.py --report-json tmp/release-evidence-live-audit-report.json --report-md tmp/release-evidence-live-audit-report.md
```

Use `--generated-at` with an ISO timestamp, release ceremony ID, or other
operator-selected evidence run ID when the report needs a retained run label.
The default is `TBD` so deterministic tests and dry runs do not invent
completion evidence.

Retained JSON report bundles are validated offline with
`release-artifacts/schema/release-evidence-live-audit-report.schema.json` and
`scripts/check_release_evidence_live_audit_report.py`. The default checker
target is the no-secret template report at
`release-artifacts/evidence/release-evidence-live-audit-report-template.json`.
The paired Markdown template at
`release-artifacts/evidence/release-evidence-live-audit-report-template.md`
is validated for exact parity against the JSON report source by
`scripts/check_release_evidence_live_audit_markdown.py`. Operator-generated
reports can be checked without GitHub network access:

```bash
python scripts/check_release_evidence_live_audit_report.py --report-json tmp/release-evidence-live-audit-report.json
python scripts/check_release_evidence_live_audit_markdown.py --report-json tmp/release-evidence-live-audit-report.json --report-md tmp/release-evidence-live-audit-report.md
python scripts/generate_release_evidence_live_audit_archive.py --check
```

The checker verifies the schema version, repo target, blocked-readiness posture,
profile coverage, snapshot freshness/currentness markers, retained snapshot
paths, snapshot SHA-256 digests, command provenance, passed checker statuses,
and secret-shaped keys/values. The
Markdown parity checker reuses that JSON validation, scans the retained
Markdown for secret-shaped values, and fails if the profile table, command
provenance, freshness/currentness summary, no-secret notice, or
blocked-readiness warning drift from the canonical renderer. It expects the
referenced snapshots to remain in the retained bundle and does not rerun GitHub
exports or mark any tracker issue complete.

`scripts/generate_release_evidence_live_audit_archive.py` indexes
the committed template pair plus future no-secret report bundles retained under
`release-artifacts/evidence/live-audit-reports/`, records JSON/Markdown
digests and validation commands, and keeps CI network-free.

Future retained bundles should live in paired files under
`release-artifacts/evidence/live-audit-reports/` using a stable lowercase
archive ID, for example
`20260614T010000Z-release-evidence-live-audit-report.json` and
`20260614T010000Z-release-evidence-live-audit-report.md`. Pass the same UTC run
label to `--generated-at` so the archive row, retained report, and operator
notes agree. Before committing a future bundle, confirm the report contains no
secrets, tokens, private exports, or unredacted operator credentials; the
checker also scans for secret-shaped keys and values. The report must include
`snapshot_freshness`, `currentness_claim`, and per-profile
`profile_generated_at` values so old label, body, or closure snapshots are not
presented as current. A valid retained bundle is review evidence only and is
not readiness proof by itself.

The canonical future-bundle workflow is:

```bash
python scripts/audit_release_evidence_issue_snapshots.py --generated-at YYYYMMDDTHHMMSSZ --report-json release-artifacts/evidence/live-audit-reports/YYYYMMDDTHHMMSSZ-release-evidence-live-audit-report.json --report-md release-artifacts/evidence/live-audit-reports/YYYYMMDDTHHMMSSZ-release-evidence-live-audit-report.md
python scripts/check_release_evidence_live_audit_report.py --report-json release-artifacts/evidence/live-audit-reports/YYYYMMDDTHHMMSSZ-release-evidence-live-audit-report.json
python scripts/check_release_evidence_live_audit_markdown.py --report-json release-artifacts/evidence/live-audit-reports/YYYYMMDDTHHMMSSZ-release-evidence-live-audit-report.json --report-md release-artifacts/evidence/live-audit-reports/YYYYMMDDTHHMMSSZ-release-evidence-live-audit-report.md
python scripts/generate_release_evidence_live_audit_archive.py --archive-dir release-artifacts/evidence/live-audit-reports
python scripts/generate_release_evidence_live_audit_archive.py --archive-dir release-artifacts/evidence/live-audit-reports --check
```

To audit live GitHub label drift manually, export a snapshot and pass it to the
checker:

```bash
python scripts/export_release_evidence_issue_snapshot.py --profile labels
python scripts/check_release_evidence_issue_labels.py --live-json tmp/release-evidence-issue-labels.json
```

The release evidence issue body sync artifact is generated as
`release-artifacts/latest/release-evidence-issue-body-sync.json` and
`release-artifacts/latest/release-evidence-issue-body-sync.md`; run
`python scripts/generate_release_evidence_issue_body_sync.py` to refresh the
exact GitHub issue body payloads and
`python scripts/generate_release_evidence_issue_body_sync.py --check` to verify
they still match the current backlog and issue-link map. It remains tracker-only
and does not mark retained evidence complete.
Run `python scripts/check_release_evidence_issue_bodies.py` to validate the
committed body-sync payloads. To audit live GitHub body drift without adding
network access to CI, export a snapshot and pass it to the checker:

```bash
python scripts/export_release_evidence_issue_snapshot.py --profile bodies
python scripts/check_release_evidence_issue_bodies.py --live-json tmp/release-evidence-issue-bodies.json
```

If drift is reported, generate deterministic remediation files and update the
affected issue with the body-file command printed by the checker:

```bash
python scripts/check_release_evidence_issue_bodies.py --write-body-files tmp/release-evidence-issue-bodies
gh issue edit ISSUE_NUMBER --repo 6529-Collections/6529Stream --body-file tmp/release-evidence-issue-bodies/issue-ISSUE_NUMBER.md
```

Run `python scripts/check_release_evidence_issue_closure.py` to verify the
committed tracker map, `release-evidence-issue-backlog.json` backlog artifact,
body-sync artifact, packet index, and shared release evidence status manifest
agree on which tracker issues may close. To audit live GitHub closure state
without adding network access to CI, export all linked issue states and pass
the snapshot to the checker:

```bash
python scripts/export_release_evidence_issue_snapshot.py --profile closure
python scripts/check_release_evidence_issue_closure.py --live-json tmp/release-evidence-issue-closure.json
```

If premature closure is reported, reopen the issue with the remediation command
printed by the checker and keep the requirement row open until the committed
evidence status is `complete` or `accepted_risk`.

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
When a retained fork, testnet, live, audit, or release-signing artifact exists,
use `python scripts/generate_non_local_release_evidence.py` to generate the
metadata envelope from the matching committed requirement template and retained
artifact path. The helper computes the artifact digest, validates the output
with the canonical checker, and supports `--check` for drift detection. It does
not unblock a release row until the generated evidence is independently
reviewed and linked from `release-artifacts/latest/public-beta-evidence.json`.
External audit report evidence for issue #215 has a Markdown retained artifact
path at
`release-artifacts/evidence/external-audit-report/external-audit-report-retained-artifact-template.md`.
Run `python scripts/test_external_audit_report_evidence.py` and
`python scripts/check_external_audit_report_evidence.py` before generating the
metadata envelope. The committed file is template-only and keeps
`external_audit_report` missing until a final reviewed audit report, scope,
finding/remediation map, retest status, and reviewer confirmation are retained.
Post-audit remediation evidence for issue #231 has a Markdown retained artifact
path at
`release-artifacts/evidence/post-audit-remediation/post-audit-remediation-retained-artifact-template.md`.
Run `python scripts/test_post_audit_remediation_evidence.py` and
`python scripts/check_post_audit_remediation_evidence.py` before generating the
metadata envelope. The committed file is template-only and keeps
`post_audit_remediation` missing until finding-by-finding remediation status,
fix PRs or commits, regression tests, retest evidence, accepted-risk records,
release-note mapping, and reviewer confirmation are retained.
Fork deployment rehearsal evidence for issue #216 also has a Markdown retained
artifact path at
`release-artifacts/evidence/fork-deployment-rehearsal/fork-deployment-rehearsal-retained-artifact-template.md`.
Run `python scripts/test_fork_deployment_rehearsal_evidence.py` and
`python scripts/check_fork_deployment_rehearsal_evidence.py` before generating
the metadata envelope. The committed file now contains reviewed
mainnet-fork rehearsal evidence captured at fork block `25316366`, with
private RPC details redacted and public-beta readiness still blocked. Issue
#216 closed completed after review accepted the retained artifact, non-local
evidence envelope, public-beta evidence row, and generated
manifest/address-book references.
Testnet deployment rehearsal evidence for issue #217 has its own Markdown
retained artifact path at
`release-artifacts/evidence/testnet-deployment-rehearsal/testnet-deployment-rehearsal-retained-artifact-template.md`.
Run `python scripts/test_testnet_deployment_rehearsal_evidence.py` and
`python scripts/check_testnet_deployment_rehearsal_evidence.py` before
generating the metadata envelope. The committed file is template-only and keeps
`testnet_deployment_rehearsal` missing until a reviewed testnet transcript,
transaction references, sanitized broadcast, generated manifest/address book,
explorer status, and reviewer confirmation are retained. Operators must redact
or omit private keys, tokens, private RPC URLs, bearer credentials, and other
sensitive values before retaining any transcript, command line, broadcast, or
linked artifact because the checker enforces the same no-secret policy.
The Sepolia setup template lives at
`deployments/config/sepolia-6529stream-v0.1.0-001.template.json`; use it with
`docs/deployment.md#sepolia-deployment-rehearsal-runbook` and
`script/RehearseDeployment.s.sol:RehearseDeployment --sig "runSepolia()"`
when preparing future reviewed testnet evidence.
Production broadcast retention evidence has a dedicated no-secret retained
artifact template at
`release-artifacts/evidence/production-broadcast-retention/production-broadcast-retention-retained-artifact-template.md`.
Run `python scripts/test_production_broadcast_retention.py` and
`python scripts/check_production_broadcast_retention.py` before generating the
metadata envelope for `production_broadcast_retention`. The checker requires
sanitized command transcripts, sanitized Foundry broadcasts, derived
broadcast-manifest inputs, generated live deployment manifests, generated live
address books, release manifest/checksum digests, reviewer metadata, and
explicit redaction confirmations before a reviewed artifact can pass. The
committed file is template-only and keeps production release blocked until a
future reviewed production deployment retention record is accepted.

Production verified-addresses evidence has a dedicated no-secret retained
artifact template at
`release-artifacts/evidence/production-verified-addresses/production-verified-addresses-retained-artifact-template.md`.
Run `python scripts/test_production_verified_addresses.py` and
`python scripts/check_production_verified_addresses.py` before generating
non-local evidence envelopes for `production_address_books` or
`live_explorer_verification`. The checker requires live address-book and
deployment-manifest agreement, verified explorer rows, runtime bytecode,
constructor-argument, linked-library, release manifest/checksum, reviewer
metadata, and explicit redaction confirmations before a reviewed artifact can
pass. The committed file is template-only and keeps production release blocked
until future reviewed live address evidence is accepted.

Live metadata-browser evidence has a dedicated no-secret retained artifact
template at
`release-artifacts/evidence/live-metadata-browser/live-metadata-browser-retained-artifact-template.md`.
Run `python scripts/test_live_metadata_browser_evidence.py` and
`python scripts/check_live_metadata_browser_evidence.py` before generating the
non-local evidence envelope for `live_metadata_browser_evidence`. The checker
requires retained browser-summary JSON, generated tokenURI output or digest,
browser transcript or screenshot, live mainnet chain ID, deployed contract
addresses, token and collection IDs, empty unexpected-request/error arrays,
animation bootstrap success, parent-frame isolation, reviewer metadata, and
explicit redaction confirmations before a reviewed artifact can pass. The
committed file is template-only and keeps production release blocked until
future reviewed live metadata browser evidence is accepted.

Live ceremony evidence has a dedicated no-secret retained artifact template at
`release-artifacts/evidence/live-ceremony/live-ceremony-retained-artifact-template.md`.
Run `python scripts/test_live_ceremony_evidence.py` and
`python scripts/check_live_ceremony_evidence.py` before generating the
non-local evidence envelope for `live_ceremony_evidence`. The checker requires
live deployment context, governance participant identities, ownership transfer,
role grant/revoke, signer setup, metadata/freeze, auction, emergency-control,
dry-run, monitoring handoff, generated live artifact references, reviewer
metadata, and explicit redaction confirmations before a reviewed artifact can
pass. The committed file is template-only and keeps production release blocked
until future reviewed live ceremony evidence is accepted.

Live randomizer operations evidence has a dedicated no-secret retained artifact
template at
`release-artifacts/evidence/live-randomizer-operations/live-randomizer-operations-retained-artifact-template.md`.
Run `python scripts/test_live_randomizer_operations_evidence.py`,
`python scripts/check_live_randomizer_operations_evidence.py`, and
`python scripts/check_randomizer_operations.py` before generating the non-local
evidence envelope for `live_randomizer_operations_evidence`. The checker
requires live provider configuration, funding status, reserve status, request
health, lifecycle controls, monitoring handoff, generated live artifact
references, reviewer metadata, and explicit redaction confirmations before a
reviewed artifact can pass. The committed file is template-only and keeps
production release blocked until future reviewed live randomizer operations
evidence is accepted.

The release-checksum step builds `release-artifacts/latest/SHA256SUMS` and
`release-artifacts/latest/release-checksums.json` from the committed release
artifact, public-beta evidence, release evidence issue backlog, release
evidence issue-link map, release evidence issue body sync, deployment manifest,
address-book, schema, ceremony evidence, and release-manifest outputs. This
gives maintainers a deterministic, signable checksum bundle. The
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

## Solidity Formatting

The canonical formatting gate is:

```bash
make fmt-check
```

`make fmt-check` runs `scripts/test_solidity_formatting.py` and
`scripts/check_solidity_formatting.py`. The checker enforces a scoped policy:

- formatting-required non-exempt Solidity files must pass `forge fmt --check`;
- the raw all-files diagnostic `forge fmt --check smart-contracts` may fail
  only for the 17 explicit vendored/provenance exemptions listed in the
  checker;
- any new unformatted Solidity file outside that exemption set fails the gate;
- if an exempt file becomes formatted, the checker fails until the exemption
  list and provenance docs are updated.

The current exemption set is intentionally limited to OpenZeppelin-style
vendored utilities and legacy ERC interfaces with retained provenance notes in
[`vendored-libraries.md`](vendored-libraries.md). The first-party interfaces
`INextGenCore2.sol`, `IStreamDrops.sol`, and `IStreamMinter.sol`, plus the
arRNG/VRF provider and legacy delegation integration files `ArrngConsumer.sol`,
`IArrngConsumer.sol`, `IArrngController.sol`,
`IDelegationManagementContract.sol`, `IRandomizer.sol`,
`VRFConsumerBaseV2.sol`, and `VRFCoordinatorV2Interface.sol`, are formatted and
enforced by the scoped gate. Do not mechanically reformat exempt vendored files
in feature PRs. Change the exemption set only in focused provenance PRs that
also update release source-verification expectations when applicable.

Windows contributors can run:

```powershell
powershell -ExecutionPolicy Bypass -File scripts\check.ps1
```

The Windows script prepends `%USERPROFILE%\.foundry\bin` to the current process
`PATH` so a fresh shell can find `forge` after bootstrap. It also routes
`forge` and the selected Python interpreter through checked native-command
wrappers so Windows PowerShell 5.1 fails fast when a tool exits non-zero; this
behavior is covered by `scripts/test_windows_check_wrapper.py` and the
executable harness in `scripts/test_windows_check_helpers.ps1`.

To run only the executable Windows wrapper harness:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\test_windows_check_helpers.ps1
```

On systems with PowerShell Core installed as `pwsh`, the same harness is also
available through:

```bash
make windows-check-wrapper-runtime
```

CI runs the harness twice: once in the Linux Foundry job under PowerShell Core,
and once in a lightweight `windows-latest` job under Windows PowerShell so
native-command exit handling is covered in the environment that motivated the
wrapper. The workflow wiring is protected by
`scripts/test_windows_ci_wrapper.py`.

## Warning Dispositions

The warning disposition gate is:

```bash
make warning-dispositions-check
```

It runs:

```bash
python scripts/test_warning_dispositions.py
python scripts/run_forge_size_log.py --log cache/forge-size.log
python scripts/check_warning_dispositions.py --solc-warnings-log cache/forge-size.log
```

[`warning-dispositions.md`](warning-dispositions.md) is the checked `ONE-007`
baseline for compiler, NatSpec, documentation, linter, vendored, test-only,
ABI-compatibility, and `StreamCore` size-tradeoff warning decisions. The
checker verifies that invalid first-party NatSpec header tags are gone, that
accepted solc warnings remain anchored to the exact current source signatures,
and that retained warning rows name an owner, disposition class, and follow-up.
The live warning parser is pinned to the current Foundry v1.7.1 / Solidity
0.8.19 output shape with a captured forge-size fixture, and the checked solc
identity is warning code plus source file plus source excerpt rather than raw
line number.

Do not change external ABI names, function `stateMutability`, or Core bytecode
shape only to quiet cosmetic warning suggestions. Any such change needs the
normal production evidence: focused tests, ABI compatibility checks, production
size proof, release artifact regeneration, and changelog coverage.

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
python scripts/test_core_bytecode_spend_policy.py
python scripts/check_core_bytecode_spend_policy.py
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
python scripts/test_non_local_release_evidence_generator.py
python scripts/test_non_local_release_evidence.py
python scripts/check_non_local_release_evidence.py
python scripts/test_fork_deployment_rehearsal_evidence.py
python scripts/check_fork_deployment_rehearsal_evidence.py
python scripts/check_public_beta_evidence.py
python scripts/generate_public_beta_blocker_report.py
python scripts/generate_production_release_blocker_report.py
python scripts/generate_release_evidence_packet_index.py
python scripts/generate_release_evidence_issue_backlog.py
python scripts/check_release_evidence_issue_links.py
python scripts/check_release_evidence_issue_labels.py
python scripts/check_release_evidence_live_audit_report.py
python scripts/generate_release_evidence_live_audit_archive.py
python scripts/generate_release_evidence_issue_body_sync.py
python scripts/check_release_evidence_issue_bodies.py
python scripts/check_release_evidence_issue_closure.py
python scripts/check_architecture_threat_model.py
python scripts/check_audit_package.py
python scripts/test_natspec_coverage.py
python scripts/check_natspec_coverage.py
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
python scripts/test_admin_ceremony_evidence.py
python scripts/check_admin_ceremony_evidence.py
python scripts/test_monitoring_spec.py
python scripts/check_monitoring_spec.py
python scripts/test_operator_dashboard_query_model.py
python scripts/check_operator_dashboard_query_model.py
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
python scripts/test_non_local_release_evidence_generator.py
python scripts/test_non_local_release_evidence.py
python scripts/check_non_local_release_evidence.py
python scripts/test_fork_deployment_rehearsal_evidence.py
python scripts/check_fork_deployment_rehearsal_evidence.py
python scripts/check_public_beta_evidence.py
python scripts/generate_public_beta_blocker_report.py --check
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
python scripts/check_architecture_threat_model.py
python scripts/check_audit_package.py
python scripts/test_natspec_coverage.py
python scripts/check_natspec_coverage.py
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
python scripts/test_admin_ceremony_evidence.py
python scripts/check_admin_ceremony_evidence.py
python scripts/test_monitoring_spec.py
python scripts/check_monitoring_spec.py
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
`deployments/admin-ceremony/`, `deployments/randomizer-operations/`,
`deployments/schema/`, and `test/fixtures/drop-authorization/`, excluding its
own generated checksum files to avoid self-referential hashes. Refresh the
release manifest before refreshing the checksum bundle after changing any
covered artifact.

## Non-Gating Diagnostics

These commands are intentionally not part of `make check` yet:

```bash
make slither
forge fmt --check smart-contracts
```

`make slither` runs:

```bash
slither . --config-file slither.config.json --foundry-compile-all
```

The current Slither high/medium baseline is tracked in
[`ops/SLITHER_BASELINE.md`](../ops/SLITHER_BASELINE.md). Slither exits non-zero
while findings exist; that is expected until the baseline is accepted as a CI
gate.

`forge fmt --check smart-contracts` is intentionally listed as a raw diagnostic
because it still prints the vendored/provenance exemption diff. The scoped
`make fmt-check` gate is part of `make check` and CI. Slither still has a known
baseline and should become a fail-on-new-finding gate only after Slither
baseline acceptance lands. See [`docs/slither.md`](slither.md) for the full
Slither workflow.
