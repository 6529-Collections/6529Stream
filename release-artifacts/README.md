# Release Artifacts

This directory contains the deterministic local release-artifact baseline for
6529Stream.

Integrator-facing consumers should start from
[`docs/integrations/README.md`](../docs/integrations/README.md). That page maps
this directory's generated ABI checksums, address books, deployment manifests,
event topics, interface IDs, release manifest, source verification inputs, risk
register, protocol surface report, and readiness artifacts into a single
source-of-truth view without claiming public beta or production readiness.

Run after the production build profile:

```sh
forge build --sizes --via-ir --skip test --skip script --force
python scripts/check_contract_size_budget.py
forge snapshot --match-path test/StreamGasSnapshot.t.sol --snap release-artifacts/baselines/v0.1.0/gas-snapshot.snap
python scripts/generate_release_artifacts.py
python scripts/generate_protocol_surface_report.py
python scripts/generate_source_verification_inputs.py
python scripts/generate_dependency_artifact_manifest.py
python scripts/generate_dependency_provenance_attestation.py
python scripts/check_abi_compatibility.py
python scripts/generate_deployment_manifest.py
python scripts/generate_address_books.py
python scripts/check_ceremony_evidence.py
python scripts/check_randomizer_operations.py
python scripts/check_release_signatures.py
python scripts/check_signed_release_tag.py
python scripts/check_non_local_release_evidence.py
python scripts/check_drop_authorization_signing_evidence.py
python scripts/check_signer_custody_readiness.py
python scripts/generate_one_of_one_provenance_manifest.py
python scripts/generate_one_of_one_permanence_manifest.py
python scripts/check_public_beta_evidence.py
python scripts/generate_risk_register.py
python scripts/generate_public_beta_blocker_report.py
python scripts/generate_production_release_blocker_report.py
python scripts/generate_release_evidence_packet_index.py
python scripts/generate_release_evidence_issue_backlog.py
python scripts/check_release_evidence_issue_links.py
python scripts/check_release_evidence_issue_labels.py
python scripts/check_release_evidence_live_audit_report.py
python scripts/generate_release_evidence_issue_body_sync.py
python scripts/check_release_evidence_issue_bodies.py
python scripts/check_release_evidence_issue_closure.py
python scripts/check_architecture_threat_model.py
python scripts/check_audit_package.py
python scripts/check_integrations_readme.py
python scripts/check_contract_flows.py
python scripts/check_auction_flows.py
python scripts/check_wallet_signature_flows.py
python scripts/check_events_and_indexing.py
python scripts/check_metadata_rendering.py
python scripts/check_react_next_reference.py
python scripts/check_mobile_walletconnect.py
python scripts/check_electron_security_wallets.py
python scripts/check_operator_admin_ui.py
python scripts/check_release_readiness.py
python scripts/test_release_mode.py
python scripts/generate_release_notes.py
python scripts/generate_release_manifest.py
python scripts/generate_bytecode_release_proof.py
python scripts/generate_release_checksums.py
```

Check the committed artifacts without rewriting them:

```sh
python scripts/test_contract_size_budget.py
python scripts/check_contract_size_budget.py
python scripts/test_release_artifacts.py
python scripts/generate_release_artifacts.py --check
python scripts/test_protocol_surface_report.py
python scripts/generate_protocol_surface_report.py --check
forge snapshot --match-path test/StreamGasSnapshot.t.sol --check release-artifacts/baselines/v0.1.0/gas-snapshot.snap
python scripts/test_source_verification_inputs.py
python scripts/generate_source_verification_inputs.py --check
python scripts/test_dependency_artifact_manifest.py
python scripts/generate_dependency_artifact_manifest.py --check
python scripts/test_dependency_provenance_attestation.py
python scripts/generate_dependency_provenance_attestation.py --check
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
python scripts/test_signed_release_tag.py
python scripts/check_signed_release_tag.py
python scripts/test_non_local_release_evidence.py
python scripts/check_non_local_release_evidence.py
python scripts/test_drop_authorization_signing_evidence.py
python scripts/check_drop_authorization_signing_evidence.py
python scripts/test_signer_custody_readiness.py
python scripts/check_signer_custody_readiness.py
python scripts/test_one_of_one_provenance_manifest.py
python scripts/check_one_of_one_provenance_manifest.py
python scripts/generate_one_of_one_provenance_manifest.py --check
python scripts/test_public_beta_evidence.py
python scripts/check_public_beta_evidence.py
python scripts/test_risk_register.py
python scripts/check_risk_register.py
python scripts/generate_risk_register.py --check
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
python scripts/test_integrations_readme.py
python scripts/check_integrations_readme.py
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
python scripts/test_react_next_reference.py
python scripts/check_react_next_reference.py
python scripts/test_mobile_walletconnect.py
python scripts/check_mobile_walletconnect.py
python scripts/test_electron_security_wallets.py
python scripts/check_electron_security_wallets.py
python scripts/test_operator_admin_ui.py
python scripts/check_operator_admin_ui.py
python scripts/test_release_readiness.py
python scripts/check_release_readiness.py
python scripts/test_release_mode.py
python scripts/test_production_broadcast_retention.py
python scripts/check_production_broadcast_retention.py
python scripts/test_release_notes.py
python scripts/generate_release_notes.py --check
python scripts/test_release_manifest.py
python scripts/generate_release_manifest.py --check
python scripts/test_bytecode_release_proof.py
python scripts/generate_bytecode_release_proof.py --check
python scripts/test_release_checksums.py
python scripts/generate_release_checksums.py --check
python scripts/test_verify_release_artifacts.py
python scripts/verify_release_artifacts.py
```

The generated files under `latest/` are intentionally tracked. They give
deployment manifests stable ABI checksum, bytecode checksum, interface ID, and
event topic catalog inputs before any live network broadcast exists.

`latest/protocol-surface-report.json` is generated from the production contract
set and Foundry artifacts. It records functions, selectors, events, topic0
values, custom errors, ABI hashes, bytecode hashes, and runtime sizes for
integrators and auditors. It is deterministic local evidence only; it does not
claim protocol correctness, production readiness, or live deployment parity.

`latest/source-verification-inputs.json` is generated from the production
Foundry artifacts, source files, compiler settings, and contract config. It
retains source hashes, compiler settings, constructor ABI, bytecode/linking
status, and `forge verify-contract` command templates so live deployment
verification can be checked against committed release inputs once broadcast
addresses and encoded constructor args exist.

`latest/dependency-artifact-manifest.json` is generated from descriptors under
`dependencies/`. It records release-packaged dependency source files, dependency
registry key/version metadata, provenance, and SHA-256 file integrity so the
release bundle does not depend on registry provenance strings alone.
Dependency artifact source files are hashed byte-for-byte, so `.gitattributes`
pins JavaScript and other release text artifacts to LF line endings. Keep new
packaged dependency files under that policy so Windows and Linux checkouts
produce the same manifest hashes.
Production dependency version changes must follow
`docs/dependency-operations.md` before public release.

`latest/dependency-provenance-attestation.json` is generated from the checked
dependency artifact manifest. It re-validates descriptor/source hashes, records
dependency identity and provenance strings, lists release validation commands,
and preserves the boundary that the current committed bundle is local
pre-audit evidence only. It does not prove live dependency registration,
collection pin transactions, public-beta readiness, production readiness, or
external audit acceptance. Validate it with
`python scripts/test_dependency_provenance_attestation.py` and
`python scripts/generate_dependency_provenance_attestation.py --check`.

The release-mode gate is not part of the default artifact refresh path because
the committed baseline is intentionally blocked. Use
`python scripts/check_release_mode.py --phase public-beta`,
`python scripts/check_release_mode.py --phase production-release`, or the manual
Release Mode GitHub workflow only when reviewing a release candidate with
retained live evidence. Those commands are expected to fail until every row
for the selected phase is `complete` or `accepted_risk`; production release
mode also requires public-beta readiness.

`latest/one-of-one-provenance-manifest.json` is generated from schemaed
descriptors under `provenance/`. It catalogs 1/1 provenance records, descriptor
hashes, token scope, artwork summary fields, authenticity status, append-only
entry count, mutability boundaries, and reviewer status. The current checked
template is an artifact-only model for artist/story/authenticity context; it is
not `tokenURI` metadata, not `contractURI()` metadata, not included in
`collectionFreezeManifestHash(collectionId)`, not marketplace readiness proof,
not royalty enforcement, and not ownership proof beyond chain state. Validate
it with `python scripts/test_one_of_one_provenance_manifest.py`,
`python scripts/check_one_of_one_provenance_manifest.py`, and
`python scripts/generate_one_of_one_provenance_manifest.py --check`.

`latest/one-of-one-permanence-manifest.json` is generated from schemaed
descriptors under `permanence/`. It catalogs collector-verifiable permanence
package records, descriptor hashes, token scope, renderer/dependency/source
bindings, replay command status, output hash status, browser proof status, and
fully on-chain versus decentralized storage boundaries. The current checked
template is an artifact-only model for replayability requirements; it is not
final collector proof, not marketplace readiness proof, not ownership proof
beyond chain state, and not production release approval until reviewed
non-local or final-drop evidence exists. Validate it with
`python scripts/test_one_of_one_permanence_package.py`,
`python scripts/check_one_of_one_permanence_package.py`, and
`python scripts/generate_one_of_one_permanence_manifest.py --check`.

`latest/release-manifest.json` is a generated top-level release manifest. It
records release metadata, release artifact hashes, ABI compatibility baseline
hashes, deployment manifest/address-book hashes, ceremony evidence hashes,
public-beta evidence status, schema hashes, governance doc hashes including
`docs/architecture.md`, `docs/threat-model.md`, `docs/audit-package.md`,
`docs/incident-response.md`, `docs/public-beta-evidence.md`,
`docs/non-local-release-evidence.md`,
`docs/integrations/frontend-reference-architecture.md`,
`docs/integrations/mobile-walletconnect.md`,
`docs/integrations/electron-security-wallets.md`,
`docs/integrations/operator-admin-ui.md`,
`docs/permanence-packages.md`,
`docs/integrations/examples/react-viem.md`, and
`docs/release-readiness.md`, and the release-ceremony items that are not yet
available for this pre-audit local baseline.

`latest/bytecode-release-proof.json` is generated after the release manifest.
It cross-checks committed deployment manifests, address books, ABI/runtime
bytecode checksums, source verification inputs, compiler settings, deployed
addresses, chain IDs, and the current release manifest hash into one
auditor-facing proof. It does not query live chain bytecode and does not make a
production verification claim; production completion still requires reviewed
live RPC or explorer evidence. The proof is checksum-covered, but it is not
embedded into the release manifest to avoid a manifest/proof hash cycle.

`latest/public-beta-evidence.json` is the no-secret status manifest for
public-beta and production-release evidence. It stays blocked in the committed
local baseline until fork/testnet/live evidence, audit evidence, production
signatures, signed tags, explorer verification, and address evidence are
retained or explicitly risk-accepted.

`latest/risk-register.json` is generated from committed roadmap, blocker,
audit-package, Slither, release, and evidence inputs. It records launch
blockers, accepted local-baseline risks, planned mitigations, source-document
hashes, evidence hashes, required checks, and tracking references. The register
is validated by `scripts/check_risk_register.py`, refreshed by
`scripts/generate_risk_register.py`, and backed by
`schema/risk-register.schema.json`. It is checksum-covered and included in the
top-level release manifest, but it is not itself launch approval.

`latest/release-notes.json` and `latest/release-notes.md` are generated from
`CHANGELOG.md`, the committed release manifest, bytecode release proof, and risk
register. They provide deterministic operator/auditor release notes for the
current local baseline: protocol and deployment versions, readiness boundary,
Unreleased changelog entries, bytecode-proof status, risk status/area counts,
and validation commands. They are review aids only; they do not prove live
deployment, public-beta readiness, production readiness, signed tags, detached
signatures, or explorer verification. Validate them with
`python scripts/test_release_notes.py` and
`python scripts/generate_release_notes.py --check`.

`latest/public-beta-blockers.md` is generated from
`latest/public-beta-evidence.json`. It lists incomplete public-beta and
production rows, evidence posture, future external evidence categories, and
validation commands without changing the intentionally blocked readiness
status.

`latest/production-release-blockers.md` is generated from
`latest/public-beta-evidence.json` and the checked templates under
`evidence/production-release-templates/`. It lists only production-release
requirements, their evidence posture, matching template paths, future external
evidence categories, and validation commands without changing the intentionally
blocked production readiness status.

`latest/release-evidence-packet-index.json` and
`latest/release-evidence-packet-index.md` are generated from the evidence
manifest, blocker reports, and checked public-beta and production-release
templates. They map every evidence row to its blocker report, template,
retained-artifact expectation, validation commands, and current readiness
posture without treating templates as completion evidence.

`latest/release-evidence-issue-backlog.json` and
`latest/release-evidence-issue-backlog.md` are generated from
`latest/release-evidence-packet-index.json`. They turn every incomplete
public-beta and production-release packet row into an issue-ready title, label
set, body, retained-artifact completion gate, and validation command list.
They do not create issues automatically and do not change public-beta or
production-release readiness claims.

`latest/release-evidence-issue-links.json` is a committed no-secret tracker map
from each issue-backlog entry to its GitHub issue. It lets maintainers audit
that every incomplete evidence requirement has a durable issue without making
the issue itself completion evidence. The
`scripts/check_release_evidence_issue_labels.py` checker validates committed
`applied_labels` deterministically and can audit an exported live GitHub issue
JSON snapshot with `--live-json` before a release ceremony.
All retained-evidence tracker issues should carry `release`, `roadmap`, and
`evidence`; public-beta rows also carry `public-beta`, and production-release
rows also carry `production-release`.
Use `scripts/export_release_evidence_issue_snapshot.py` to write label, body,
or closure snapshots as UTF-8 JSON without relying on shell redirection.
Use `scripts/audit_release_evidence_issue_snapshots.py` as the operator-only
one-command live audit for label, body, and closure drift; CI runs only its
mocked unit tests and never requires GitHub network access.
When operators pass `--report-json` or `--report-md`, the live audit
orchestrator writes a retained no-secret report bundle with selected profiles,
repo target, snapshot paths, snapshot SHA-256 digests, command provenance,
checker outcomes, explicit snapshot freshness/currentness markers, and the
unchanged blocked-readiness warning. The report schema lives at
`schema/release-evidence-live-audit-report.schema.json`; the default no-secret
template report lives at
`evidence/release-evidence-live-audit-report-template.json`, with the paired
human-readable template at
`evidence/release-evidence-live-audit-report-template.md` and template snapshots
under `evidence/live-audit-report-template/`. Run
`scripts/check_release_evidence_live_audit_report.py` to validate retained JSON
report bundles offline against snapshot digests, command provenance, profile
coverage, freshness/currentness claims, and the blocked-readiness posture. Run
`scripts/check_release_evidence_live_audit_markdown.py` with the retained JSON
and Markdown paths to prove the human-readable report is the canonical render of
the validated JSON source and still contains no secret-shaped values. Report
bundles are ceremony evidence for review; they do not make any retained
public-beta or production evidence row complete.

`latest/release-evidence-live-audit-report-archive.json` and
`latest/release-evidence-live-audit-report-archive.md` are generated by
`scripts/generate_release_evidence_live_audit_archive.py`; they index the
committed template pair plus any future no-secret bundles retained under
`evidence/live-audit-reports/`, record JSON/Markdown digests and validation
commands, and keep CI network-free.

Future live audit report bundles must be retained as paired JSON/Markdown files
under `evidence/live-audit-reports/`. Use a stable lowercase archive ID that
starts with the UTC run label, for example
`20260614T010000Z-release-evidence-live-audit-report.json` and
`20260614T010000Z-release-evidence-live-audit-report.md`, and pass the same
label to the report generator with `--generated-at`. The paired files must be
no-secret review evidence only; they cannot contain tokens, private exports, or
unredacted operator credentials. They must include `snapshot_freshness`,
`currentness_claim`, and per-profile `profile_generated_at` values so retained
label, body, and closure snapshots are never implied to be current after the
fact. They do not make public-beta or production-release readiness true by
themselves. See
`evidence/live-audit-reports/README.md` for the exact retention workflow and
validation command sequence.

`latest/release-evidence-issue-body-sync.json` and
`latest/release-evidence-issue-body-sync.md` join the generated backlog and
committed issue-link map into exact GitHub issue body payloads plus a Markdown
review view. They are no-secret, tracker-only artifacts; they do not update
GitHub automatically and do not make tracker closure retained evidence. The
`scripts/check_release_evidence_issue_bodies.py` checker validates committed
body payloads deterministically, can audit an exported live GitHub issue JSON
snapshot with `--live-json`, and can write deterministic per-issue body files
with `--write-body-files` for operator-run `gh issue edit --body-file`
remediation.

`scripts/check_release_evidence_issue_closure.py` validates the committed
tracker map, `release-evidence-issue-backlog.json` backlog artifact, body-sync
artifact, packet index, and shared release evidence status manifest agree on
tracker closure readiness. Its optional `--live-json` mode audits a
closure snapshot written by `scripts/export_release_evidence_issue_snapshot.py`
and fails if a linked tracker issue is closed while the committed evidence
status is still `missing`, `pending`, `blocked`, or `not_applicable`.

`evidence/non-local-release-evidence-template.json` is the checked no-secret
template for future reviewed non-local release evidence metadata. Its schema
lives at `schema/non-local-release-evidence.schema.json`, and the template
points at `evidence/non-local-template-retained-artifact.txt` to prove retained
artifact hash validation without claiming public-beta or production readiness.
`evidence/public-beta-templates/` contains one checked template JSON for each
public-beta requirement ID plus a shared retained-artifact placeholder. These
templates are release artifacts and checksum-covered operator starting points,
not completion evidence.

`evidence/production-release-templates/` contains one checked template JSON for
each production-release requirement ID plus a shared retained-artifact
placeholder. These templates are release artifacts and checksum-covered
operator starting points, not completion evidence.

`drop-authorization-signing/drop-authorization-signing-evidence-template.json`
is the checked no-secret template for future reviewed drop authorization
signing ceremonies. Its schema lives at
`schema/drop-authorization-signing-evidence.schema.json`, and the template
points at `drop-authorization-signing/drop-authorization-signing-retained-artifact.txt`
plus the generated unsigned payload output to prove payload/hash/reviewer
validation without claiming public-beta or production readiness.

`signer-custody-readiness/signer-custody-readiness-template.json` is the
checked no-secret template for future reviewed signer custody readiness
evidence. Its schema lives at `schema/signer-custody-readiness.schema.json`,
and the template points at
`signer-custody-readiness/signer-custody-readiness-retained-artifact.txt`,
`docs/signer-custody-readiness.md`, and `docs/incident-response.md` to prove
retained artifact and runbook hash validation without claiming public-beta or
production readiness.

`provenance/one-of-one-provenance-template.provenance.json` is the checked
no-secret template for future reviewed 1/1 provenance evidence. Its schema lives
at `schema/one-of-one-provenance-manifest.schema.json`, and the template points
at `provenance/one-of-one-provenance-retained-artifact-template.md` and
`docs/provenance-manifests.md` to prove retained artifact and runbook hash
validation without claiming public beta, production, marketplace, or collector
readiness.

`permanence/one-of-one-permanence-template.permanence.json` is the checked
no-secret template for future reviewed collector-verifiable permanence package
evidence. Its schema lives at
`schema/one-of-one-permanence-package.schema.json`, and the template points at
`permanence/one-of-one-permanence-retained-artifact-template.md`,
`docs/permanence-packages.md`, the dependency artifact manifest, and the 1/1
provenance manifest to prove retained artifact and runbook hash validation
without claiming public beta, production, marketplace, or final collector
readiness.

Deployment admin ceremony evidence is retained under
`../deployments/admin-ceremony/` and cataloged by
`latest/release-manifest.json` as a deployment artifact. Its schema lives at
`../deployments/schema/admin-ceremony-evidence.schema.json`, and the checked
template points at
`../deployments/admin-ceremony/admin-ceremony-retained-artifact-template.md`
to prove retained artifact hash validation without claiming fork, testnet, or
production admin ceremony completion.

`docs/architecture.md`, `docs/threat-model.md`, `docs/audit-package.md`,
`docs/incident-response.md`, `docs/public-beta-evidence.md`,
`docs/non-local-release-evidence.md`, `docs/signer-custody-readiness.md`,
`docs/integrations/frontend-reference-architecture.md`,
`docs/integrations/mobile-walletconnect.md`,
`docs/integrations/electron-security-wallets.md`,
`docs/integrations/operator-admin-ui.md`, and
`docs/release-readiness.md` are the
auditor-facing architecture, trust-boundary, package, incident-response,
evidence-status, non-local evidence intake, signer custody readiness, frontend
reference, mobile/WalletConnect reference, Electron security/wallet reference,
operator/admin UI reference, and Gate G readiness indexes for the current local
baseline. They are validated before release manifest generation, and the
release manifest records their hashes as governance documents.

`evidence/external-audit-report/external-audit-report-retained-artifact-template.md`
is the checked no-secret retained-artifact template for future
`external_audit_report` evidence. Validate it with
`python scripts/test_external_audit_report_evidence.py` and
`python scripts/check_external_audit_report_evidence.py` before generating a
non-local evidence envelope. The committed template is not audit evidence and
does not change public-beta readiness.

`evidence/testnet-deployment-rehearsal/testnet-deployment-rehearsal-retained-artifact-template.md`
is the checked no-secret retained-artifact template for future
`testnet_deployment_rehearsal` evidence. Validate it with
`python scripts/test_testnet_deployment_rehearsal_evidence.py` and
`python scripts/check_testnet_deployment_rehearsal_evidence.py` before
generating a non-local evidence envelope. The committed template is not testnet
evidence and does not change public-beta readiness.

`evidence/production-broadcast-retention/production-broadcast-retention-retained-artifact-template.md`
is the checked no-secret retained-artifact template for future
`production_broadcast_retention` evidence. Validate it with
`python scripts/test_production_broadcast_retention.py` and
`python scripts/check_production_broadcast_retention.py` before generating a
non-local evidence envelope. The committed template is not production broadcast
evidence and does not change production-release readiness.

`latest/SHA256SUMS` and `latest/release-checksums.json` are also generated
outputs. They cover the committed release artifact config, generated release
artifacts, dependency artifact descriptors/source files, ABI compatibility
baseline, the third-party release verifier script, deployment manifest
config/examples, address books, ceremony evidence
bundles, randomizer operations evidence, release signature evidence, drop
authorization signing evidence, signer custody readiness evidence, artifact
schemas, non-local release evidence metadata and templates, public-beta
evidence status, release evidence packet index, release evidence issue backlog,
and release manifest. Treat
`SHA256SUMS` as the signable checksum file for a release; the committed local
signature evidence records that production detached signatures and signed tags
remain a maintainer release-ceremony step.

Third-party consumers can run `python scripts/verify_release_artifacts.py` from
the repository root to verify the committed release bundle without regenerating
artifacts, rebuilding Solidity, using RPC, or contacting explorers. The
verifier checks that `latest/SHA256SUMS`, `latest/release-checksums.json`,
`latest/release-manifest.json`, and `latest/bytecode-release-proof.json` agree
with the files on disk; that checksum-covered files exist and match their
hashes; that canonical manifest/proof file records match current file hashes
and sizes; and that the bytecode release proof is bound to the current release
manifest hash. It is an offline integrity and consistency check only. It does
not prove live deployed bytecode, explorer verification, production signatures,
public-beta readiness, or production-release readiness.

Because the checksum bundle covers `latest/release-manifest.json`, the release
manifest cannot also embed the final checksum-bundle digests without creating a
self-referential hash cycle. It therefore lists the checksum bundle outputs and
marks their digests as `not_available_self_referential`.
Release signature evidence uses the same self-referential digest status for
`latest/release-manifest.json` and `latest/SHA256SUMS` because both generated
files cover the signature evidence file.

The generated ABI compatibility baseline under `baselines/` is also tracked.
It captures the current production contract function, event, custom error,
constructor, fallback, and receive surface. The check fails on removed or
changed entries and reports additive entries as compatible for this first
release baseline.

`contracts.json` also carries the production runtime size budget. The local and
CI size-budget checker reads the production Foundry artifacts, computes linked
runtime size even when Solidity library placeholders are still unlinked, checks
every production contract against EIP-170, and enforces the configured
`StreamCore` minimum margin before release artifacts can be considered current.

`baselines/v0.1.0/gas-snapshot.snap` is the local Foundry gas snapshot for the
Gate D operations. It is generated with `forge snapshot --match-path
test/StreamGasSnapshot.t.sol --snap
release-artifacts/baselines/v0.1.0/gas-snapshot.snap` and checked with the same
command's `--check` form. The snapshot intentionally covers deterministic local
tests only; fork/testnet/mainnet gas measurements remain a later release step.
`baselines/v0.1.0/gas-envelopes.json` adds named release envelopes for those
snapshot rows. Check it with `python scripts/check_gas_envelopes.py`; the
checker requires every snapshot row to have exactly one envelope and fails when
any measured flow exceeds its documented ceiling.

The generator uses Foundry's `cast sig-event` for Ethereum event topics and
Foundry artifact `methodIdentifiers` for function selectors and interface IDs.
Known ERC interface IDs are pinned in `contracts.json` where the advertised
standard ID differs from a raw selector XOR over an artifact ABI that includes
inherited `supportsInterface` or event-only declarations.

After any covered artifact changes, refresh the checksum bundle with:

```sh
python scripts/check_contract_size_budget.py
python scripts/generate_deployment_manifest.py
python scripts/generate_address_books.py
python scripts/generate_source_verification_inputs.py
python scripts/generate_dependency_artifact_manifest.py
python scripts/generate_dependency_provenance_attestation.py
python scripts/check_ceremony_evidence.py
python scripts/check_randomizer_operations.py
python scripts/check_release_signatures.py
python scripts/check_non_local_release_evidence.py
python scripts/check_drop_authorization_signing_evidence.py
python scripts/check_signer_custody_readiness.py
python scripts/generate_one_of_one_provenance_manifest.py
python scripts/generate_one_of_one_permanence_manifest.py
python scripts/check_public_beta_evidence.py
python scripts/generate_public_beta_blocker_report.py
python scripts/generate_production_release_blocker_report.py
python scripts/generate_release_evidence_packet_index.py
python scripts/generate_release_evidence_live_audit_archive.py
python scripts/check_architecture_threat_model.py
python scripts/check_audit_package.py
python scripts/check_react_next_reference.py
python scripts/check_mobile_walletconnect.py
python scripts/check_release_readiness.py
python scripts/generate_release_manifest.py
python scripts/generate_bytecode_release_proof.py
python scripts/generate_release_checksums.py
```

If only `release-artifacts/` changed, the manifest and address-book commands
should still be safe no-ops, and their `--check` modes will catch stale
deployment-derived inputs before the checksum bundle is refreshed.
