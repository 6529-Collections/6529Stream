# Validation reference

This is detailed maintainer reference. Start everyday work with the
[developer commands](../../tooling.md); run aggregate release validation only when
preparing the corresponding evidence. Commands below run from the repository root.

## Local Checks

For the supported current stack, run `make current-stack-check`, or on Windows:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\check.ps1 -CurrentStack
```

This selects the `current` Foundry profile: global via-IR compilation with the
same Solidity 0.8.19, optimizer 200, Paris and metadata settings as the canonical
release build. It compiles the contracts and current deployment scripts, runs
the cross-domain tests in `test/current`, and checks release target coverage,
formatting, source layout and the permanent Core ABI. Outputs remain under
ignored `out/current` and `cache/current`. The default profile and full release
checks retain their historical scope. This focused command does not regenerate
release evidence or replace the broader domain and release validation.

Fresh contributors should start with
[`first-30-minutes.md`](../../first-30-minutes.md). That checked guide explains the
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
forge snapshot --match-path test/gas/StreamGasSnapshot.t.sol --check release-artifacts/baselines/v0.1.0/gas-snapshot.snap
python -m tools.protocol.test_external_call_gas_inventory
python -m tools.protocol.check_external_call_gas_inventory
forge build --sizes --via-ir --skip test --skip script --force
python -m tools.build.test_release_build_artifacts
python -m tools.build.build_release_artifacts
python -m tools.build.build_release_artifacts --check
python -m tools.build.test_contract_size_budget
python -m tools.build.check_contract_size_budget
python -m tools.build.test_solidity_formatting
python -m tools.build.check_solidity_formatting
python -m tools.build.test_solidity_source_layout
python -m tools.build.check_solidity_source_layout
python -m tools.build.test_solidity_layout_equivalence
python -m tools.build.check_solidity_layout_equivalence --check-receipt
python -m tools.development.test_python_toolchain
python -m tools.development.check_python_toolchain
python -m tools.security.test_warning_dispositions
python -m tools.build.run_forge_size_log --log cache/forge-size.log
python -m tools.security.check_warning_dispositions --solc-warnings-log cache/forge-size.log
python -m tools.protocol.test_drop_authorization_payload_generator
python -m tools.protocol.generate_drop_authorization_payload --input test/fixtures/drop-authorization/payload-generator/fixed-price-input.json --output test/fixtures/drop-authorization/payload-generator/fixed-price-output.json --check
python -m tools.protocol.generate_drop_authorization_payload --input test/fixtures/drop-authorization/payload-generator/auction-input.json --output test/fixtures/drop-authorization/payload-generator/auction-output.json --check
python -m tools.protocol.test_drop_authorization_fixtures
python -m tools.protocol.check_drop_authorization_fixtures
python -m tools.release.test_drop_authorization_signing_evidence
python -m tools.release.check_drop_authorization_signing_evidence
python -m tools.release.test_signer_custody_readiness
python -m tools.release.check_signer_custody_readiness
python -m tools.deployment.test_admin_ceremony_evidence
python -m tools.deployment.check_admin_ceremony_evidence
python -m tools.build.test_release_artifacts
python -m tools.build.generate_release_artifacts --check
python -m tools.build.test_protocol_surface_report
python -m tools.build.generate_protocol_surface_report --check
python -m tools.build.test_custom_error_catalog
python -m tools.build.generate_custom_error_catalog --check
python -m tools.build.test_natspec_coverage
python -m tools.build.check_natspec_coverage
python -m tools.build.test_source_verification_inputs
python -m tools.build.generate_source_verification_inputs --check
python -m tools.build.test_abi_compatibility
python -m tools.build.check_abi_compatibility --check
python -m tools.deployment.test_broadcast_manifest_input
python -m tools.deployment.generate_broadcast_manifest_input --check
python -m tools.deployment.test_deployment_manifest
python -m tools.deployment.generate_deployment_manifest --check
python -m tools.deployment.generate_deployment_manifest --config deployments/config/anvil-6529stream-v0.1.0-001-broadcast.json --check
python -m tools.deployment.generate_deployment_manifest --config deployments/config/fork-mainnet-6529stream-v0.1.0-001.json --check
python -m tools.deployment.generate_deployment_manifest --config deployments/config/fork-mainnet-6529stream-v0.1.0-001-broadcast.json --check
python -m tools.deployment.test_address_books
python -m tools.deployment.generate_address_books --check
python -m tools.deployment.test_ceremony_evidence
python -m tools.deployment.check_ceremony_evidence
python -m tools.deployment.test_randomizer_operations
python -m tools.deployment.check_randomizer_operations
python -m tools.release.test_release_signatures
python -m tools.release.check_release_signatures
python -m tools.release.test_signed_release_tag
python -m tools.release.check_signed_release_tag
python -m tools.release.test_production_release_signing_evidence
python -m tools.release.check_production_release_signing_evidence
python -m tools.release.test_non_local_release_evidence_generator
python -m tools.release.test_non_local_release_evidence
python -m tools.release.check_non_local_release_evidence
python -m tools.release.test_external_audit_report_evidence
python -m tools.release.check_external_audit_report_evidence
python -m tools.deployment.test_fork_deployment_rehearsal_evidence
python -m tools.deployment.check_fork_deployment_rehearsal_evidence
python -m tools.release.test_public_beta_evidence
python -m tools.release.check_public_beta_evidence
python -m tools.release.test_public_beta_blocker_report
python -m tools.release.generate_public_beta_blocker_report --check
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
python -m tools.docs.test_architecture_threat_model
python -m tools.docs.check_architecture_threat_model
python -m tools.protocol.test_artist_semantic_owner_matrix
python -m tools.protocol.check_artist_semantic_owner_matrix
python -m tools.protocol.test_mint_manager_domain_constants
python -m tools.protocol.check_mint_manager_domain_constants
python -m tools.docs.test_audit_package
python -m tools.docs.check_audit_package
python -m tools.docs.test_audit_finding_workflow
python -m tools.docs.check_audit_finding_workflow
python -m tools.docs.test_incident_response
python -m tools.docs.check_incident_response
python -m tools.docs.test_readme
python -m tools.docs.check_readme
python -m tools.docs.test_first_30_minutes
python -m tools.docs.check_first_30_minutes
python -m tools.docs.test_issue_templates
python -m tools.docs.check_issue_templates
python -m tools.docs.test_pr_template
python -m tools.docs.check_pr_template
python -m tools.development.test_autonomous_state
python -m tools.development.check_autonomous_state
python -m tools.docs.test_markdown_links
python -m tools.docs.check_markdown_links
python -m tools.docs.test_curator_rewards_flow
python -m tools.docs.check_curator_rewards_flow
python -m tools.docs.test_withdrawals_credits_flow
python -m tools.docs.check_withdrawals_credits_flow
python -m tools.release.test_release_readiness
python -m tools.release.check_release_readiness
python -m tools.protocol.test_genesis_deployment_profile
python -m tools.protocol.check_genesis_deployment_profile
python -m tools.protocol.test_governed_parameter_identifiers
python -m tools.protocol.check_governed_parameter_identifiers
python -m tools.protocol.test_governed_parameter_inventory
python -m tools.protocol.check_governed_parameter_inventory
python -m tools.protocol.test_system_manifest_payload_vector
python -m tools.protocol.check_system_manifest_payload_vector
python -m tools.protocol.test_system_manifest_payload_vector_reference
python -m tools.protocol.check_system_manifest_payload_vector_reference
python -m tools.security.test_slither_baseline
python -m tools.security.check_slither_baseline --baseline-only
python -m tools.release.test_release_manifest
python -m tools.release.generate_release_manifest --check
python -m tools.release.test_release_checksums
python -m tools.release.generate_release_checksums --check
python -m tools.docs.test_changelog_check
python -m tools.docs.check_changelog
python -m tools.deployment.test_deployment_rehearsal_gate
python -m tools.deployment.check_deployment_rehearsal_gate
forge script script/legacy/RehearseDeploymentSuite.s.sol:RehearseDeploymentSuite --sig "run()" --via-ir
forge script script/legacy/RehearseDeployment.s.sol:RehearseDeployment --sig "run()" --via-ir
forge script script/legacy/RehearseAuctionCeremony.s.sol:RehearseAuctionCeremony --sig "run()" --via-ir
forge script script/legacy/RehearseEmergencyRedeployment.s.sol:RehearseEmergencyRedeployment --sig "run()" --via-ir
```

The deployment rehearsal gate parity step is a static guard over `Makefile`,
`scripts/check.sh`, `scripts/check.ps1`, and `.github/workflows/ci.yml`. It
fails if the aggregate suite command, any standalone rehearsal command, or the
CI retained log names drift out of the local/CI smoke path; it does not replace
the actual Forge rehearsal scripts that run immediately afterward.

The protocol surface report step checks
[`release-artifacts/latest/protocol-surface-report.json`](../../../release-artifacts/latest/protocol-surface-report.json)
against the current production Foundry artifacts. It is an integrator and audit
review index over functions, selectors, events, topic0 values, custom errors,
ABI hashes, bytecode hashes, and runtime sizes; it is not a production-readiness
claim.

The custom error catalog step checks
[`release-artifacts/latest/custom-error-catalog.json`](../../../release-artifacts/latest/custom-error-catalog.json)
against the protocol surface report. It classifies release-relevant custom
errors by category and severity, records selector/signature data, and keeps
test traceability plus caller-action guidance visible for auditors and
integrators. It is documentation and traceability evidence, not a replacement
for the Solidity tests or external audit.

The NatSpec coverage step checks
[`release-artifacts/natspec-coverage.json`](../../../release-artifacts/natspec-coverage.json)
against the protocol surface report and first-party Solidity sources. It
requires nearby NatSpec for release-surface functions, public variable getters,
events, and custom errors unless the current gap is listed with an explicit
reason. The current baseline has 948 explicit exclusions, so it is a checked
burn-down queue rather than proof that API documentation is complete. See
[`natspec-coverage.md`](../../natspec-coverage.md).

The aggregate size step is a warning-collection and whole-tree size diagnostic,
not a deployability or release-evidence gate. It uses `via_ir` because the
current deployable `StreamCore` profile needs the IR optimizer, but Foundry
compilation restrictions can still admit `test/` helpers despite the command's
`--skip test --skip script` flags. The artifact-backed budget checker therefore
validates the canonical build receipt and retained compiler inputs, then hashes
the exact target-isolated `out-release/` artifact bytes it reads against that
in-memory receipt before decoding them. For every artifact metadata source,
including imports, the size and Core-spend consumers require a regular
non-reparse checkout file and compare one read against both the receipt
SHA-256/Keccak record and artifact metadata Keccak; deletion or non-file
replacement after receipt validation fails closed. The checker reads
`release-artifacts/contracts.json`, treats unlinked Solidity library
placeholders as their 20-byte deployed addresses for size counting, fails below
the 384-byte `StreamCore` minimum margin, and reports a warning below the
512-byte future-work threshold. The checker also validates artifact compiler
metadata, optimizer settings, EVM version, compilation target, and
current-source Keccak hashes before trusting any reported runtime size. Missing
or stale canonical artifacts in `out-release/` therefore fail validation;
aggregate artifacts in `out/` remain diagnostic-only and are not consumed by
the checker. Its 384-byte floor is an interim development control, not the
governing production deployment threshold.

The Core bytecode-spend policy is stricter than the EIP-170 floor. It reads the
same canonical target-isolated artifacts and pins the currently approved
`StreamCore` runtime baseline from `release-artifacts/contracts.json`. A future
PR may reduce Core runtime size without an exception, but any increase above
the approved baseline must add an accepted exception record with an issue, rationale,
measured delta, maximum approved runtime size, and mitigation before
`python -m tools.build.check_core_bytecode_spend_policy` will pass.
Accepted headroom-recovery records use `measured_delta_bytes` as
`runtime_size_bytes - baseline_runtime_size_bytes`, which makes reductions
negative and bytecode spend positive.
The policy retains its historically approved spend ceiling; this is not a claim
about the current compiled runtime. The approved `StreamCore` runtime baseline is 22,184 bytes; its approved
baseline EIP-170 margin is 2,392 bytes. Mutable runtime and margin are owned by the
`StreamCore` row in
`release-artifacts/latest/bytecode-release-proof.json`, not by copied tooling
prose. The architecture/status preflight and risk generation step both read the
cycle-free pre-tail `abi-checksums.json` measurement, so an honest Core-size
change can update the single marked `docs/status.md` projection before the new
manifest and proof exist. `tools/security/generate_risk_register.py --check` then
validates the final proof's up-to-date release-manifest and ABI-checksum bindings,
requires every `StreamCore` proof row to agree, and requires exact ABI/proof
parity against the non-waivable 2,000-byte production margin. Missing, stale,
malformed, duplicate-owner, orphan, or internally inconsistent measurements
fail closed without creating a `risk -> manifest -> proof` dependency cycle. This
artifact-backed local size result does not replace concrete
candidate integration, independent audit, deployment, or reviewed live-bytecode
evidence.

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
The public-beta, non-local, drop-authorization signing, and signer-custody JSON
evidence checkers share `tools/shared/no_secret_scanner.py` for recursive key/value
scanning. The helper reports nested object/list paths, permits only the explicit
no-secret policy keys, and applies the strict union of the migrated
secret-shaped key and assignment-looking value patterns. Each checker wraps
helper failures in its existing checker-specific exception type.
The admin ceremony evidence checker validates the no-secret template under
`deployments/admin-ceremony/`, ties the retained artifact checklist and schema
to current hashes, and rejects reviewed evidence that still contains template
placeholders, invalid environment/chain pairs, zero privileged addresses,
secret-shaped values, path escapes, stale retained hashes, or incomplete
approval state.

The release artifact step is the first Gate G machine-readable artifact gate.
Its bytecode authority is `python -m tools.build.build_release_artifacts`, not the
aggregate all-source size build. The helper compiles each unique configured
production or interface source exactly once with only that source and its
import closure, an isolated temporary output/cache pair, pinned Foundry
`v1.7.1` with the explicit `default` profile, Solidity `0.8.19`, Paris EVM,
optimizer runs `200`, via-IR, and metadata bytecode disabled. Real Forge
subprocesses discard inherited `FOUNDRY_*` and `DAPP_*` settings, then set only
the controlled `FOUNDRY_PROFILE=default` override supported by the pinned Forge
version. It reads each configured artifact once, validates and hashes that
captured byte snapshot, writes those exact bytes into a staged aggregate, and
derives retained compiler-input bytes and hashes from one in-memory encoding.
The config and Foundry-config target/policy validation and receipt hashes are
likewise derived from the same captured bytes. At the canonical validator
boundary, config, receipt, every configured artifact, retained compiler input,
and string-form embedded metadata JSON are decoded from those captured bytes
under a strict UTF-8, duplicate-free, non-floating-point I-JSON policy with
safe integers and Unicode scalar values. The builder stages only configured
named artifacts alongside retained compiler inputs and the build receipt, then
replaces
dedicated ignored `out-release/` with rollback on caught replacement failures.
The output option is restricted to the literal repo-root `out-release/`, while
ordinary Forge builds and scripts continue to use `out/`. Config, receipt,
artifact, and compiler-input paths reject symlink, junction, and reparse
components before resolution. The builder requires Forge's raw `basePath`,
`includePaths`, and `allowPaths` to identify exactly the active repository root
and its `lib/` directory, then retains those four worktree-specific values as
the stable relative policy `basePath="."`, `includePaths=["."]`, and
`allowPaths=[".", "lib"]`. Any missing, reordered, duplicate, aliased, or extra
path fails before retention. This makes compiler-input bytes and the complete
receipt hash portable across checkouts while preserving the exact source,
settings, toolchain, and artifact bindings. Forge's platform packaging
timestamp is the sole normalized version-output field; the receipt retains the
exact semantic version, commit, build profile, and canonical identity self-hash,
so official Windows and POSIX binaries for the same pinned Forge release produce
the same receipt. Tests and scripts are excluded from those source closures. The
deterministic ignored build receipt binds the config, Foundry config, canonical
Forge identity, explicit normalized Forge argv, compiler policy, target,
complete metadata source universe and hashes, compiler-settings hash, canonical
build-input hash, and artifact hash. The
release-artifact, source-verification, protocol-surface, and ABI-compatibility
CLIs retain the validated receipt while consuming `out-release/`. Each matches
the exact target kind, name, source, relative path, normalized path, and hash,
then hashes and decodes one artifact byte snapshot; source-verification also
carries that parsed snapshot into metadata collection, binds every checkout
source read to the receipt's matching metadata/compiler-input SHA-256 and
Keccak records, and reuses one snapshot per source instead of reopening files.
Receipt validation first requires every occurrence of a source path to carry
one identical SHA-256/Keccak identity across metadata and compiler-input
records for all production and interface targets, so alternating a shared
checkout source between target validations cannot yield a valid receipt.
Source records must use their resolved canonical repository-relative spelling;
Windows identity keys are case-folded after resolution to reject case and
short/long aliases, while Linux receipt paths retain case-sensitive filesystem
semantics.
Stale source inputs or mutation after initial receipt validation therefore fail
closed.

The official Make target and repository check wrappers order the canonical
builder before its size, Core-policy, release-artifact, source-verification, and
ABI consumers within one invocation. Direct concurrent build, check, consumer,
or clean invocations in the same worktree are unsupported and may fail
transiently while `out-release/` is replaced.

The aggregate `forge build --sizes --via-ir --skip test --skip script --force`
run remains useful for compiler warning collection and whole-tree diagnostic
size output, but it is not release bytecode or explorer-verification evidence.
This separation addresses
[issue #674](https://github.com/6529-Collections/6529Stream/issues/674).
The canonical builder additionally rejects any configured target, retained
build-info compiler-input source, or artifact-metadata source whose resolved
repository path starts under `test/` or `script/`. This fail-closed guard
addresses the noncausal aggregate leakage tracked by
[issue #675](https://github.com/6529-Collections/6529Stream/issues/675) without
changing `foundry.toml` or the via-IR test compilation behavior. Two-root
regressions require byte-identical retained compiler inputs and full receipts.
This helper canonicalizes release and verification evidence only. The current
Forge deployment scripts can still recompile a larger script import universe
and do not yet prove that broadcasts consume this canonical initcode;
[issue #677](https://github.com/6529-Collections/6529Stream/issues/677) remains
a production blocker for that deployment binding.

The first issue #677 tooling slice is
`tools/deployment/materialize_canonical_deployment_plan.py`. It consumes, but never
rebuilds, the validated `out-release/release-build-manifest.json` receipt and
the exact configured artifacts produced by the canonical builder. Before
materializing any bytecode, it runs the builder's complete
`validate_release_output_with_snapshots(...)` path, then checks the candidate's
pinned receipt, catalog, release-config, Foundry-config, and artifact hashes.
That validator carries the exact validated receipt, config, Foundry config, and
artifact bytes plus their paths and SHA-256 digests into the materializer.
The materializer recomputes every carried digest, requires an exact
receipt-to-artifact snapshot set, strictly decodes the carried receipt and
release-config JSON plus every carried artifact before candidate target
selection, and does not reopen those files. Parsed artifact snapshots are
reused when multiple candidate instances target them. A filesystem replacement
after validation therefore cannot change the plan being constructed from the
validated snapshot. It derives the constructor ABI from each receipt-bound
artifact, ABI-encodes the declared arguments, resolves the artifact's exact
creation/runtime library positions and runtime immutable positions, and emits
ordered full initcode plus expected runtime bytecode and Keccak-256 hashes.
`eth-abi==5.2.0` is a reviewed direct toolchain pin because this encoder is part
of the materialization boundary.
`jsonschema==4.25.1` is a reviewed direct pin because the checked path performs
actual Draft 2020-12 validation rather than treating the schema documents as
descriptive references.
The complete creation bytecode plus encoded constructor arguments fails closed
above the 49,152-byte EIP-3860 initcode limit.

The materializer dispatches between the retained v1 fixture and a
checker-complete v2 candidate. The v1 candidate schema accepts only
`candidate_kind: non_production_fixture` with both `production_candidate` and
`readiness_evidence` set to `false`. The committed fixture at
`deployments/config/canonical-deployment-candidate-non-production.json`
materializes one `DependencyRegistry` instance with literal Anvil-only admin
and library addresses. Its `profile_entry_id` is deliberately `null`; it is not
the strict instance-aware genesis candidate required by issue #656. Candidate
and output shapes are documented by
`deployments/schema/canonical-deployment-candidate.schema.json` and
`deployments/schema/canonical-deployment-plan.schema.json`. A v2 input must
first pass the complete
`deployments/schema/canonical-deployment-candidate.v2.schema.json` and
`tools/deployment/check_canonical_deployment_candidate.py` decision. Generator version
4 then projects linked libraries first and instances second, preserves each
candidate expected address, and binds the candidate's cycle-free SHA-256 and
Keccak-256 identities into the existing plan schema. The identity excludes only
the retained-evidence binding; retained evidence must bind that projected
identity and cannot contain the raw candidate-artifact SHA-256. The materializer
checks each applicable schema as valid Draft 2020-12, validates the strictly
decoded candidate, and validates every in-memory generated plan before it can
be written or compared in `--check` mode. It also retains the issue #680
restricted-source-root and portable compiler-path policies in the materialized
plan.

The committed v2 planning document at
`deployments/config/canonical-deployment-candidate-v2-planning.json` has 37
profile rows, zero linked libraries, zero instances, and 44 completeness
blockers. The planning document now binds only the completed canonical Solidity
source-layout manifest and the unchanged 37-entry genesis profile by exact
repository path and SHA-256. Source commit, dependency inventories, canonical
build, concrete instances, linked libraries, and retained evidence remain
unavailable. Its ordinary structural check succeeds; `--require-complete`
fails. It cannot reach plan materialization, RPC, Forge, or broadcast, and it
is not a frozen candidate or readiness evidence.

This bounded two-pin packet was selected because both inputs are stable merged
authorities and can close stale planning blockers without choosing deployment
facts. An early partial build recipe was rejected because the incomplete target
catalog and legacy revenue implementation would create review churn and could
misstate the eventual candidate source set. A monolithic candidate packet was
also rejected because waiting for every protocol and live-input dependency
would stall the independently verifiable layout/profile progress and create a
larger review surface.

The source-layout pin was taken from the merged manifest's direct SHA-256,
`a4a8be3df18da217e4efc3d4d09b151807bdc152125f524f1493dd39690d9f65`.
An earlier 63-hex transcription omitted the `d` in `...807bdc...` and was
rejected by the unchanged digest schema before generation. Relaxing the schema
was rejected because it would weaken the fail-closed binding; stopping the
packet was unnecessary once the exact merged bytes independently reproduced
the valid 64-hex digest.

After producing the canonical isolated build, run the focused tool as follows:

```bash
python -m tools.deployment.test_canonical_deployment_candidate
python -m tools.deployment.check_canonical_deployment_candidate
# Expected to fail with exit 1 while the committed planning candidate has blockers.
python -m tools.deployment.check_canonical_deployment_candidate --require-complete
python -m tools.deployment.test_materialize_canonical_deployment_plan
python -m tools.deployment.materialize_canonical_deployment_plan \
  --candidate deployments/config/canonical-deployment-candidate-non-production.json \
  --output tmp/canonical-deployment-plan.json
python -m tools.deployment.materialize_canonical_deployment_plan \
  --candidate deployments/config/canonical-deployment-candidate-non-production.json \
  --output tmp/canonical-deployment-plan.json \
  --check
```

The ordinary Make, Bash, PowerShell, and Linux CI aggregate gates first run the
candidate-v2 19-test suite, require the committed planning check to report
37 profile rows, zero libraries, zero instances, and 44 blockers, and require
strict completion to fail with exit 1. They then run the
unit/materialize/reparse-check sequence immediately after they create and
validate `out-release/`. Both candidate enforcement files are members of the
canonical checksum trust set, so the release tail and wrapper cannot remain
green after unreviewed checker or test drift. The materialized candidate
remains the same narrow non-production fixture; gate inclusion does not turn
the ephemeral plan into a release artifact or deployment authorization.
Because Draft validation is inside the materializer, both the committed
candidate and the real generated
plan are schema-checked in every one of those gate paths.

Candidate-supplied immutable values are assertions, not values derived from
constructor semantics. The materializer enforces the artifact-declared widths
and positions and checks the resulting expected-runtime hash, but it does not
execute creation code or prove that constructor execution returns that runtime.
That semantic/runtime equivalence remains outside this non-production
foundation.

Materialized plans are ephemeral operator inputs and may only be written below
the repository `tmp/` directory. They are not generated release evidence.
Candidate, receipt, artifact, and output paths reject repository escapes and
symlink, junction, or reparse components. Repository-relative JSON paths use
one runtime/schema-identical portable policy: no C0/DEL controls, Windows
invalid characters, drive or alternate-stream colons, backslashes, empty or
dot-alias segments, trailing dot/space segments, or case-insensitive
`CON`/`PRN`/`AUX`/`NUL`/`COM1`-`COM9`/`LPT1`-`LPT9` device segments (including
extensions). Duplicate JSON members, floats, non-I-JSON integers or Unicode
surrogate values, invalid Draft 2020-12 candidate/plan shapes, stale or mutated
receipts/artifacts, constructor ABI or argument-hash drift,
missing/extra/unresolved/wrong/overlapping links, missing, wrong-width, or
overlapping immutables, EIP-3860 overflow, runtime-hash drift, target
mismatches, forward dependencies, and non-ephemeral output paths fail closed.

The issue #677A generic executor is
`tools/deployment/execute_canonical_deployment_plan.py`. It re-materializes the supplied
plan and requires byte-for-byte equality before execution. The
production-import-free `deployment-script/DeployCanonicalInitcode.s.sol` reads
only that plan, checks the plan and entry hashes, and deploys its raw initcode.
The dedicated `deployment-script/foundry.toml` isolates the broadcaster output,
cache, and broadcast directories; the executor rejects a compiler build-info
closure containing any second source.

Before constructing Forge or any broadcast submission for a v2 plan, executor
generator 2 obtains the uncontended starting nonce and derives every CREATE
address from the selected sender in the plan's exact library-first then
instance order. Every result must equal the candidate-bound expected address.
It then simulates the complete ordered plan, probes block-by-number,
block-by-hash, and exact EIP-1898 runtime reads,
strictly decodes every JSON-RPC byte response with the same duplicate-free
UTF-8/I-JSON, safe-integer, and Unicode-scalar policy as trusted files, requires
an exact non-boolean safe-integer response ID, accepts only the exact
`{jsonrpc,id,result}` success envelope, uses a separate repository-local
chain/sender lock across all plans, and requires a contiguous uncontended nonce
range. The lock cannot serialize another clone, worktree, machine, or external
wallet; repeated latest/pending nonce checks fail closed on those external
interleavings, but cannot undo an already submitted transaction.
Verified successful external journals are terminal, as are unresolved journals.
Only a preflight or failed-preflight journal with an exact matching schema,
network, execution identity, false success flag, null active deployment, empty
verified set, and coherent optional preflight evidence is immediately
retry-safe. An executor-owned ephemeral journal becomes retry-safe only after
its Anvil process has stopped and the executor records that destruction.
The executor rechecks the starting nonce after simulation and before
submission. Postflight independently checks the actual transaction input,
sender/nonce-derived CREATE address,
receipt and canonical block, and expected runtime. Every final-sweep runtime
read uses the captured final-tip EIP-1898 block-hash selector. Before publishing
the schema-validated ephemeral receipt, the executor rereads both
`eth_blockNumber` and that height's hash and rejects tip advancement, regression,
or reorganization.

Run the bounded offline unit suite and local proof with:

```bash
python -m tools.deployment.test_execute_canonical_deployment_plan
python -m tools.deployment.execute_canonical_deployment_plan \
  --mode anvil \
  --candidate deployments/config/canonical-deployment-candidate-non-production.json \
  --plan tmp/canonical-deployment-plan.json \
  --ephemeral-output \
  --local-anvil
```

Execution-receipt paths reuse the candidate/plan schema's exact portable
repository-path policy, including device-name and trailing-dot/space rejection.
`--output` and `--ephemeral-output` are mutually exclusive. External local and
fork modes require a chain-31337 plan and a loopback RPC. Sepolia mode requires
chain 11155111, `--authorize-live-broadcast`, and an endpoint whose exact
normalized IPv4/IPv6 resolution set is entirely globally routable. That set is
pinned into the execution context and must re-resolve unchanged immediately
before every executor-owned JSON-RPC request and Forge invocation. This is a DNS
alias/rebinding drift check, not actual-peer binding; retained evidence states
`actual_peer_verified: false`. This slice has no rehearsal mode alias. External
execution requires an explicit reviewed `unlocked`, `ledger`, `trezor`, or
`keystore` signer transport; raw
private-key CLI input is unsupported and the Forge child environment is
sanitized.
Checker-complete v2 candidates remain tooling-only: production execution is
explicitly disabled even when candidate completeness, identity, retained
evidence, and expected-address checks pass. The executor does not freeze a
candidate, retain ceremony evidence, close issue #656, authorize deployment,
or change release maturity. Concrete candidate reconciliation and any shared
release/deployment wiring remain deferred.

The artifact generator verifies that `release-artifacts/latest/` matches the
canonical isolated build, including ABI checksums, bytecode checksums, interface
IDs, and the event topic catalog. Each generated JSON output is serialized once;
its manifest hash is derived from those exact in-memory bytes, which are staged
and atomically installed. Before reporting success, the generator rereads every
installed output and requires byte-for-byte equality with its in-memory
snapshot. It automatically finds Foundry's `cast` in `~/.foundry/bin` when the
shell has not added it to `PATH`.

The source-verification step generates and checks
`release-artifacts/latest/source-verification-inputs.json` from the production
Foundry artifacts, source files, compiler settings, and contract config. It
retains source hashes, constructor ABI, bytecode/linking status, and
`forge verify-contract` command templates without claiming live explorer
verification before a broadcast deployment exists.

The ABI compatibility step compares the current production contract and
published interface ABI surfaces against
`release-artifacts/baselines/v0.1.0/abi-surface.json`. It fails on removed or
changed functions, events, custom errors, constructors, fallback, or receive
entries. Additive entries are reported as compatible for this first baseline so
maintainers can pair them with release notes and version policy.

Before that implementation comparison, the same checker validates
`release-artifacts/stream-core-permanent-interface.json`. This normative target
locks every Permanent `StreamCore` function selector, return shape, mutability,
event topic, and indexed-field shape, plus the explicit disposition of each
pre-genesis Core function or event that does not survive the cutover. Every
active entry maps to exactly one member of the closed
`bytecode_budget_groups` catalog; retired entries map to none, and a catalog
group with no active entry fails validation. Groups organize implementation
requirements only: they contain no additive byte estimate, and the complete
linked via-IR runtime measurement is the sole bytecode-size authority. Its
checked scope is deliberately functions and events: custom errors and the
constructor remain in the generated ABI baseline rather than being mislabeled
Permanent. Fallback and receive are instead locked as `required_absent`; target
validation checks that policy declaration, and implementation `--check` fails
if either ABI category appears even though ordinary additive ABI changes remain
compatible. A transparent active-surface lock pins the ordered function/event
shapes to SHA-256
`sha256:8ed0f91ed4f96b18f7b2c1cf4328e0a125cc54d870e6ba49ff30c07dd3e6a701`.
A separate reviewer-pinned canonical-JSON lock covers every target semantic,
including all top-level metadata, authorization and ownership policy, normative
homes, coverage counts, bytecode-budget groups, required-absence and bootstrap
policy, and every ordered active or retired function/event row, at SHA-256
`sha256:7303445a540a0eb0fb70e64b77fa317be6e68369ec38a5adadf3f282040ead98`.
Implementation `--check` compares the live ABI against the current
`baselines/v0.1.0/abi-surface.json` and separately closes the retirement
catalog against the immutable
`baselines/pre-permanent-core/abi-surface.json`: every pre-cutover Core
function/event shape must have exactly one active or retired disposition, and
every retired row must match that pre-cutover snapshot. This separation prevents
the permanent implementation baseline from erasing the evidence for its own
pre-genesis retirements.
The target, contract config, and ABI baseline are loaded as strict UTF-8,
duplicate-free, schema-restricted I-JSON; invalid UTF-8, duplicate members,
non-finite or floating-point values, and integers outside the I-JSON safe range
fail closed. Validate the target without reading `out/` or the implementation
baseline with:

```bash
python -m tools.build.check_abi_compatibility --target-only
```

ABI diagnostic records use `subject` as the canonical contract or interface
identifier and retain `contract` as a deprecated compatibility alias with the
same value. New tooling should read `subject`; existing consumers can keep
reading `contract` until they migrate.

The broadcast manifest input step parses the sanitized Foundry fixtures under
`deployments/broadcasts/`, rejects wrong-chain, failed-receipt,
missing-contract, unexpected-contract, duplicate, invalid-address, and
secret-like-key inputs, and checks the generated broadcast-derived configs
under `deployments/config/`. The default check covers both the local Anvil
fixture and the current mainnet-fork rehearsal fixture for issue #216, whose
changed CON-014 artifact set is pending PR review.
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
lowercase, and are regenerated with `python -m tools.deployment.generate_address_books`.
The default drift check includes the Anvil placeholder, Anvil broadcast-derived,
and current fork-mainnet broadcast-derived address books.

The bytecode-to-release proof step writes
`release-artifacts/latest/bytecode-release-proof.json` after release manifest
generation:

```sh
python -m tools.build.test_bytecode_release_proof
python -m tools.build.generate_bytecode_release_proof --check
```

The proof cross-checks address books, deployment manifests, ABI/runtime
bytecode hashes, source verification inputs, compiler settings, chain IDs, and
the current release manifest hash. It is checksum-covered and no-secret, but it
does not query live chain bytecode; live production bytecode proof remains a
reviewed non-local evidence requirement.

The release-candidate lockfile step writes
`release-artifacts/latest/release-candidate-lockfile.json` after the bytecode
release proof and before the checksum bundle:

```sh
python -m tools.release.test_release_candidate_lockfile
python -m tools.release.generate_release_candidate_lockfile --check
```

The lockfile ties the release manifest, bytecode release proof, public-beta
evidence, risk register, release notes, blocker reports, release evidence issue
outputs, and release-signature evidence into one deterministic review artifact.
The committed local baseline explicitly keeps the final commit/tag/signature
lock in `not_locked_until_signed_release_tag` status until a real release
ceremony supplies production signatures and a signed tag.

The record-family authorization source and evidence package validates:

```sh
python -m tools.protocol.test_record_family_authorization
python -m tools.protocol.check_record_family_authorization
```

The Proposed artist semantic-domain ownership packet validates with:

```sh
python -m tools.protocol.test_artist_semantic_owner_matrix
python -m tools.protocol.check_artist_semantic_owner_matrix
```

The strict checker binds the matrix, schema, frozen 57-operation source, seven
sole semantic owners, five immutable external providers, and the pre-audit
implementation stops. The release manifest independently validates and binds
the matrix and schema, while the checksum bundle binds the ADR, matrix, schema,
checker, and hostile tests as exact roots. These bindings do not authorize
Solidity implementation, a deployment candidate, audit credit, or any
readiness advance.

The checker reads
`release-artifacts/record-family-authorization-source-catalog.json` against
`release-artifacts/schema/record-family-authorization-source-catalog.v1.schema.json`,
binding the active source and import paths to checkpoint `7b4ef22b`. The previous
`f5c7164f` source catalog is preserved unchanged at
`release-artifacts/baselines/record-family-authorization-source-catalog-f5c7164f.json`.
The immutable annotated tag `evidence/source-layout-2026-09-10` retains the active
checkpoint across a squash merge and branch deletion. It is an evidence reference,
not a release tag. A normal full clone fetches it; existing, shallow, or no-tags
checkouts can fetch the required reference explicitly before running the checker:

```sh
git fetch origin refs/tags/evidence/source-layout-2026-09-10:refs/tags/evidence/source-layout-2026-09-10
```

That historical catalog and the `063605ea` historical inventory are evidence of
their original revisions, not current implementation claims. The checker
reads the retained historical baseline in
`release-artifacts/record-family-authorization-inventory.json` against
`release-artifacts/schema/record-family-authorization-inventory.v1.schema.json`
and reads
`deployments/record-family-authorization/record-family-authorization-evidence-template.json`
against
`deployments/schema/record-family-authorization-evidence.v1.schema.json`. A
future candidate-specific grant map is separately validated against
`deployments/schema/record-family-authorization-grant-map.v1.schema.json`. The
source catalog pins the implementation commit/digests, exact fourteen family
IDs, eight authorization classes, immutable host bindings, strict snapshot
intersection, family-authorized record locking, independent-family routing to
the append-only Preservation host without pause/freeze blocking, and
undeclared-type rejection before capacity consumption. Preservation hashes and
latest pointers are recorder-scoped: the convenience derive/latest methods use
the caller, while the explicit `For` methods require a nonzero recorder. The
catalog also pins the additive pre-genesis interface IDs: registry
`0x679dcd40`, collection metadata `0x2c2422f4`, and Preservation
`0xa30cfc7c`. The inventory
preserves the five pre-remediation mutation selectors and eight historical
fail-open behaviors. A future complete grant map must hash-bind that exact
source catalog and enumerate the numeric class/mode catalog, live-provider
address/codehash/revision rows, exact family IDs, each admitted record type's
ordered class mask and lock policy, the active family grants, exactly the
metadata and preservation hosts, and both hosts' shared record-family registry
address. The classifier, grant map, and both host-support records must agree on
the registry-wide configuration revision, commitment hash, record-type count,
stored current and pending configuration authorities, chain ID, and finalized
observation block number/hash. The current authority must be nonzero. The
stored current value is initialized once from the `StreamAdmins` owner and is
thereafter changed only by the two-step propose/accept flow; it is not a live
owner alias. Release evidence normally requires a zero pending value. A
nonzero pending value is accepted only with an explicit reviewed disposition.
Lifecycle support separately binds proposed, accepted, and cancelled address
transitions and each event's configuration revision/hash. It also names the
same registry and finalized chain/block identity, repeats the observed
current/pending authority and configuration revision/hash, and carries a
reviewed terminal-to-observation commitment-linkage reference. The checker
requires the observation to be at or after the terminal lifecycle revision
and the observed current authority to equal the accepted/cancellation
authority. Any later admission,
provider change, or family-grant change advances that commitment and invalidates
the retained map until it is regenerated and re-reviewed. A future complete
evidence envelope must use its schema-governed `grant_map.path` to bind the
separate phase- and candidate-specific
`deployments/record-family-authorization/public-beta-record-family-authorization-grant-map.json`
or
`deployments/record-family-authorization/production-release-record-family-authorization-grant-map.json`;
the inventory or template cannot stand in for those artifacts. Production
evidence additionally hash-binds and fully revalidates the canonical
public-beta retained envelope.

Release-manifest generation records the source catalog and schema, historical
inventory and schema, evidence schema, grant-map schema, and template; the
release-candidate lockfile independently binds the same seven records.
Canonical checksum generation covers the package plus its checker, hostile
tests, and exactly twelve source-semantic
inputs:

- `smart-contracts/interfaces/stream/records/IStreamRecordFamilyAuthorityProvider.sol`
- `smart-contracts/interfaces/stream/records/IStreamRecordFamilyRegistry.sol`
- `smart-contracts/domains/records/StreamRecordFamilyRegistry.sol`
- `smart-contracts/domains/metadata/StreamCollectionMetadata.sol`
- `smart-contracts/interfaces/stream/metadata/IStreamCollectionMetadata.sol`
- `smart-contracts/domains/preservation/StreamPreservationRecords.sol`
- `smart-contracts/interfaces/stream/preservation/IStreamPreservationRecords.sol`
- `script/legacy/RehearseDeployment.s.sol`
- `test/regression/legacy/records/StreamRecordFamilyAuthorization.t.sol`
- `test/regression/legacy/metadata/StreamCollectionMetadata.t.sol`
- `test/regression/legacy/preservation/StreamPreservationRecords.t.sol`
- `test/regression/legacy/protocol/StreamDeploymentManifest.t.sol`

These are twelve exact file roots, not broad `smart-contracts/` directory
coverage. The offline verifier reconstructs the required trust set, acquires
immutable snapshots for every covered file, materializes those snapshots in a
temporary root, and loads the record-family checker plus all twelve semantic
inputs from that root. Record-family semantic revalidation has no live-path
fallback after snapshot acquisition. It then checks exact
manifest/lockfile/hash/size agreement. Both public-beta and production release
mode consume the checker's candidate-evidence completion blocker. No CLI flag,
environment variable, JSON status, risk acceptance, evidence template, or
admin ceremony can clear it. Source enforcement is present, but
`RISK-GOV-002` remains `open_blocker`, and issue #690 stays open until exact
candidate-bound admission/provider/grant/runtime/lifecycle evidence and
independent review are merged. This tooling proves the source slice, not
deployment completeness or readiness.

The post-entropy completion-gas as-built source gate runs:

```sh
make post-entropy-completion-gas-check
```

The target validates the generated planning artifact and its hostile tests,
runs the focused target fixture under the pinned via-IR compiler profile, and
checks the dedicated one-test snapshot:

```sh
python -m tools.protocol.test_post_entropy_completion_gas
python -m tools.protocol.generate_post_entropy_completion_gas --check
python -m tools.protocol.check_post_entropy_completion_gas
forge test --via-ir --match-path test/gas/StreamPostEntropyCompletionGas.t.sol -vvv
forge snapshot --via-ir --match-path test/gas/StreamPostEntropyCompletionGas.t.sol --match-test testMeasureWorstCaseEoaPostCoordinatorTail --check release-artifacts/baselines/v0.1.0/post-entropy-completion-gas.snap
```

The artifact records the measured EOA-recipient post-coordinator tail, the
measurement-derived parent reserve, the permanent-Core source and linked
via-IR runtime, and the executable exact-threshold/full-stipend regression.
Calldata encoding occurs before admission and the threshold includes the
cold-call upfront reserve. It is source evidence, not a candidate-instance
measurement; #656/#670 candidate binding and #684 governed-parameter
completeness remain separate blockers.

The shared royalty/metadata completion-buffer as-built source gate runs:

```sh
make royalty-return-gas-buffer-check
```

It executes the hostile evidence tests, checks deterministic generation, runs
the focused via-IR Solidity suite, and verifies the six-scenario snapshot:

```sh
python -m tools.protocol.test_royalty_return_gas_buffer
python -m tools.protocol.generate_royalty_return_gas_buffer --check
python -m tools.protocol.check_royalty_return_gas_buffer
forge test --via-ir --match-path test/gas/StreamRoyaltyReturnGasBuffer.t.sol -vvv
forge snapshot --via-ir --match-path test/gas/StreamRoyaltyReturnGasBuffer.t.sol --match-test testMeasure --check release-artifacts/baselines/v0.1.0/royalty-return-gas-buffer.snap
```

The generated
[`royalty-return-gas-buffer.json`](../../../release-artifacts/evidence/royalty-return-gas-buffer.json)
binds the reusable overflow-safe admission source, the authenticated
permanent-Core three-row implementation, maximum bounded metadata ABI return,
actual `tokenURI()` and `contractURI()` boundary tests, six completion
measurements, measurement-derived planning floor/genesis values, independent
raise-chain tests, and the exact linked permanent-Core runtime. It has no
onchain authority and adds no 23rd GGP. The governed inventory deliberately
keeps candidate and fixed-stipend facts incomplete; issues #656, #670, and
#684 remain production gates.

The production release-signing evidence step validates the dedicated no-secret
retained artifact template at
`release-artifacts/evidence/production-release-signing/production-release-signing-retained-artifact-template.md`:

```sh
python -m tools.release.test_production_release_signing_evidence
python -m tools.release.check_production_release_signing_evidence
```

It prepares future reviewed `production_signatures` and `signed_git_tag`
evidence by checking retained file paths, optional declared `sha256:` hashes,
signer fingerprint/custody/rotation fields, release-signature JSON alignment,
signed-tag checker handoff, and no-secret redaction. It does not create
production signatures, trust a local keyring, or close issues #223 and #224
without real reviewed release ceremony evidence.

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
`python -m tools.release.generate_release_manifest` after any covered input changes.
The optional live audit report bundle records the repository target, selected
issue-audit profiles, retained snapshot paths, snapshot digests, command
provenance, checker outcomes, explicit snapshot freshness/currentness claims,
and the unchanged blocked-readiness warning.

The architecture/threat-model step validates [`architecture.md`](../../architecture.md)
and [`threat-model.md`](../../threat-model.md), the auditor-facing map of system
components, trust boundaries, value/custody flows, threat categories, residual
risks, and evidence links.

The mint-manager domain constants step validates the checked
[`launch-v1-target-architecture.md`](../../launch-v1-target-architecture.md)
`StreamMintManager` domain table against `StreamMintManager.sol` and recomputes
each listed `keccak256` preimage with `cast`, failing on source, spec, or hash
drift. It also checks the accepted ADR 0018 target operation-domain mirrors;
the full normalized request/result/root/token `abi.encode` term order; exact
`MintBatch`, `CounterConsumption`, and `GateResult` field layouts; selector,
return, and replay-read ABI goldens; nonpayable manager ownership with no
generic callback or co-live legacy `mint` entry; the sale-authorization
typehash and content-hash fields; one-root/`N`-token-operation-ID cardinality,
caller binding, zero/reused-root and rollback semantics; exact event field
layouts/topics; and Core/entropy/settlement-blocker boundary statements. Those
target checks are spec-first: they do not treat the current CON-014 Solidity or
generated as-built event catalog as already aligned.

The audit-package step validates [`audit-package.md`](../../audit-package.md), the
single auditor-facing index over maturity, scope, ADRs, tests, static analysis,
deployment/release evidence, known blockers, accepted local-baseline
dispositions, and security reporting.

The audit-finding-workflow step validates
[`audit-finding-workflow.md`](../../audit-finding-workflow.md), the public-safe
external audit finding intake, triage, remediation, retest, accepted-risk, and
closure workflow that stays aligned with the checked audit finding issue form
and post-audit remediation evidence handoff.

The incident-response step validates
[`incident-response.md`](../../incident-response.md), the no-secret operator runbook
for stuck auctions, failed randomness, bad Merkle roots, bad metadata or
dependency configuration, signer compromise, and release artifact/evidence
mistakes.
The incident drill evidence step validates the checked no-secret retained
artifact template under
[`release-artifacts/evidence/incident-drills/incident-drill-retained-artifact-template.md`](../../../release-artifacts/evidence/incident-drills/incident-drill-retained-artifact-template.md)
for mint pause, bid pause, settlement pause, withdrawal policy, failed
randomness, stuck auction, bad metadata/dependency, bad Merkle root, and signer
compromise drill evidence.
The signer compromise drill evidence step validates the narrower checked
retained artifact template under
[`release-artifacts/evidence/incident-drills/signer-compromise-drill-retained-artifact-template.md`](../../../release-artifacts/evidence/incident-drills/signer-compromise-drill-retained-artifact-template.md)
for drop-execution pause, signer rotation or revocation, signer epoch
invalidation, per-drop cancellation, stale/cancelled/wrong-domain payload
rejection, recovered fixed-price and auction payloads, monitoring handoff,
review, and redaction. It is source-aware and checks that the documented
response controls still exist in `StreamDrops`, `StreamPauseDomains`, and the
signer compromise/pause regression tests.
The stuck auction drill evidence step validates the narrower checked retained
artifact template under
[`release-artifacts/evidence/incident-drills/stuck-auction-drill-retained-artifact-template.md`](../../../release-artifacts/evidence/incident-drills/stuck-auction-drill-retained-artifact-template.md)
for auction identity, stuck condition, custody, pause/unpause, terminal
settlement or cancellation, bidder/proceeds credits, withdrawal availability,
surplus boundaries, monitoring handoff, review, and redaction. It is
source-aware and checks that auction settlement, no-bid recovery, cancellation,
pause, credit withdrawal, and surplus-boundary controls still exist in the
auction contract, pause domains, auction/pause tests, protocol state-machine
tests, and auction-flow integration docs.
The failed randomness drill evidence step validates the narrower checked
retained artifact template under
[`release-artifacts/evidence/incident-drills/failed-randomness-drill-retained-artifact-template.md`](../../../release-artifacts/evidence/incident-drills/failed-randomness-drill-retained-artifact-template.md)
for request identity, provider type, provider epoch, pending/stale/failed/final
request state, metadata state, invalid callback handling, retry or stale
marking, provider migration boundaries, monitoring handoff, review, and
redaction. It is source-aware and checks that randomizer lifecycle events,
stale marking, retry, failed post-processing, provider-specific fulfillment,
metadata-state docs, and randomizer operations docs still exist.
The bad metadata/dependency drill evidence step validates the narrower checked
retained artifact template under
[`release-artifacts/evidence/incident-drills/bad-metadata-dependency-drill-retained-artifact-template.md`](../../../release-artifacts/evidence/incident-drills/bad-metadata-dependency-drill-retained-artifact-template.md)
for metadata schema/state, token URI snapshots, URI/UTF-8/raw-attribute or
browser-sandbox failure, dependency key/version/content hash, freeze manifest,
repin boundaries, ERC-4906/cache invalidation, marketplace/indexer handoff,
review, and redaction. It is source-aware and checks that `StreamCore`,
`DependencyRegistry`, `StreamMetadataRenderer`, metadata/freeze/dependency
tests, incident-response docs, dependency operations docs, and metadata docs
still expose the controls the retained artifact references.

The drop-authorization fixture step validates
[`drop-authorization-signing.md`](../../drop-authorization-signing.md) and the
deterministic no-secret fixtures under
[`test/fixtures/drop-authorization/`](../../../test/fixtures/drop-authorization).
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
[`release-readiness.md`](../../release-readiness.md), the Gate G dashboard that
separates passing local evidence and reviewed fork evidence from missing
testnet/live evidence, production signatures, signed Git tags, verified
deployed addresses, explorer verification, external audit, and post-audit
remediation blockers.
The monitoring specification step validates
[`monitoring.md`](../../monitoring.md), the checked `GOV-009` operations reference
for admin, signer, auction, randomizer, payment/credit, metadata/dependency,
release-evidence, alert-severity, dashboard-query, and incident-handoff
monitoring. It is not a maintained monitoring service, hosted dashboard, alert
provider integration, production indexer, public beta implementation, or
production readiness claim.
The operator dashboard query model step validates
[`operator-dashboard-query-model.md`](../../operator-dashboard-query-model.md), the
checked `GOV-010` operations reference that turns monitoring categories into
dashboard panels, query inputs, source artifacts, freshness states, severity
mapping, and no-secret telemetry boundaries. It is not a maintained dashboard,
hosted monitoring service, alert-provider integration, RPC provider, production
indexer, public beta implementation, or production readiness claim.
The strict release-mode decision remains opt-in rather than part of the default
`make check` baseline, which runs the structural
`genesis-deployment-profile-check` and `python -m tools.release.test_release_mode`.
The canonical
`release-artifacts/genesis-deployment-profile.json` derives the exhaustive
`[LCM-GENESIS]` entry count from its contiguous entries, keeps unreviewed
legacy names non-satisfying, and reports class-level mapping gaps against the
v1 `release-artifacts/contracts.json` catalog without making ordinary
development unusable. Both the profile and candidate catalog use the same
strict UTF-8, duplicate-free, schema-restricted I-JSON input rules. The complete
canonical rows for `StreamCore`, the governance layer,
`StreamSystemManifest`, and `StreamCoreFinalityAdapter` pin their reviewed
identity, requirement, implementation, scope, multiplicity, interfaces,
markers, aliases, normative anchors, parameters, and distinctness policy.
Candidate matching requires exact implementation/interface/marker sets for the
three safety-critical Core, system-manifest, and finality-adapter entries. The
governance entry remains intentionally composite but requires its exact
structured state-export publisher ABI proof; every non-governance candidate is
forbidden from presenting that proof. That catalog is diagnostic only: it has
  no deployment addresses, instance identity, or on-chain manifest
  reconciliation and therefore can never clear production
mode. The
local `make release-mode-public-beta-check` and
`make release-mode-production-release-check` targets run the aggregate `check`
gate and `slither-baseline-check` before the strict evidence decision. The
manual GitHub `workflow_dispatch` profile likewise requires the protected
default branch and runs the aggregate plus live Slither gates before the selected
release phase. Release mode accepts
only active, correctly ordered risk-acceptance windows, permits them only for
waivable public-beta rows, requires completed external-audit evidence and every
production evidence row, and requires public-beta readiness before production
release readiness. Both phases validate the canonical normalized
`ops/SLITHER_BASELINE.json` plus its checked Markdown mirror and reject any
first-party production High/Medium row that remains Open. The current 30-row
set is a non-waivable technical blocker under issue #658; exact analyzer drift
parity is not acceptance. Release mode also fails closed on the separately
tracked record-family authorization gap in `RISK-GOV-002` and the High
Governance Executor native-value authority in `RISK-GOV-003`, which bounded
assembly makes invisible to Slither. The record-family stop applies to both
release phases and is not risk-waivable. Production mode then reads the
checksum-covered
`release-artifacts/latest/abi-checksums.json` measurement, rejects missing,
malformed, boolean-as-integer, or arithmetically inconsistent `StreamCore` size
fields, and requires at least 2,000 bytes of EIP-170 runtime headroom. That
mode also invokes the genesis checker in strict completeness mode: missing,
extra, duplicate, ambiguous, wrong-scope, wrong-interface, wrong-marker,
unapproved-alias, and fallback gaps are production blockers. Even a v1
catalog with no mapping gaps remains categorically insufficient. Production
stays fail-closed until a checked schema for an instance-aware genesis
deployment candidate reconciles deployment manifests, address books,
source-verification inputs, the on-chain system-manifest payload, retained
rehearsal/live evidence, and the release candidate lockfile. That remaining
work is tracked by
[issue #656](https://github.com/6529-Collections/6529Stream/issues/656). The
checked `release-artifacts/system-manifest-payload-vector.json` is deliberately
only a `target_abi_lock_fixture`: it consumes all 37 contract entries, retains
the payload-v1 `gasParameterProbes` compatibility member as exactly empty, and
proves RFC8785/I-JSON, fixed-chunk, commitment, and canonical root-descriptor
mechanics, including one synthetic release-wide deployment-identity digest
reused by every payload occurrence under the production outer domain. Its
deterministic synthetic addresses and hashes are not deployment or readiness
evidence.
Regenerate it with
`python -m tools.protocol.generate_system_manifest_payload_vector`; validate drift with
`python -m tools.protocol.test_system_manifest_payload_vector` followed by
`python -m tools.protocol.check_system_manifest_payload_vector`, then run
`python -m tools.protocol.test_system_manifest_payload_vector_reference` and
`python -m tools.protocol.check_system_manifest_payload_vector_reference`. The reference
oracle deliberately imports neither the generator nor the primary checker: it
independently encodes the audited JCS/ABI preimages and hard-pins the reviewed
profile, payload, deployment-identity, chunk, commitment, and root-descriptor
goldens. Update those goldens only after an independent recomputation and review.
The generator has no `--check` mode; both checkers are fail-closed check commands.
`make system-manifest-payload-vector` first validates the genesis profile and
governed-parameter identifier catalog, regenerates the vector, and then runs
both validator pairs. The non-writing
`make system-manifest-payload-vector-check` runs the same prerequisites and
validators. Release-manifest generation and check targets depend on the
corresponding vector target, so a stale or invalid profile-to-vector chain
cannot feed the release manifest.

The non-waivable Core headroom threshold comes from the
[`Genesis Deployment Profile`](../../launch-conformance-matrix.md#genesis-deployment-profile)
and [`Core Hook Budget`](../../launch-v1-target-architecture.md#core-hook-budget), and
is tracked by [issue #654](https://github.com/6529-Collections/6529Stream/issues/654).
Runtime and margin are read from
`release-artifacts/latest/bytecode-release-proof.json`; copied tooling prose is
not a measurement authority. Passing the local Core-size requirement does not
clear the independent candidate, audit, deployment, and retained-live-evidence
requirements that keep production release mode red. Ordinary `make check`
remains usable for development.

The public-beta evidence step validates
[`public-beta-evidence.md`](../../public-beta-evidence.md) and
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
`python -m tools.release.generate_release_evidence_issue_backlog` to refresh it and
`python -m tools.release.generate_release_evidence_issue_backlog --check` to verify
it. It does not create GitHub issues automatically or change readiness claims.
The release evidence issue-link map is committed at
`release-artifacts/latest/release-evidence-issue-links.json`; run
`python -m tools.release.check_release_evidence_issue_links` to verify each generated
backlog entry has a durable tracker issue without querying GitHub during CI.
Run `python -m tools.release.check_release_evidence_issue_labels` to verify committed
`applied_labels` are unique and drawn from the generated suggested label set.
To audit live GitHub tracker drift without adding network access to CI, run the
operator-only orchestrator:

```bash
python -m tools.release.audit_release_evidence_issue_snapshots
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
python -m tools.release.audit_release_evidence_issue_snapshots --report-json tmp/release-evidence-live-audit-report.json --report-md tmp/release-evidence-live-audit-report.md
```

Use `--generated-at` with an ISO timestamp, release ceremony ID, or other
operator-selected evidence run ID when the report needs a retained run label.
The default is `TBD` so deterministic tests and dry runs do not invent
completion evidence.

Retained JSON report bundles are validated offline with
`release-artifacts/schema/release-evidence-live-audit-report.schema.json` and
`tools/release/check_release_evidence_live_audit_report.py`. The default checker
target is the no-secret template report at
`release-artifacts/evidence/release-evidence-live-audit-report-template.json`.
The paired Markdown template at
`release-artifacts/evidence/release-evidence-live-audit-report-template.md`
is validated for exact parity against the JSON report source by
`tools/release/check_release_evidence_live_audit_markdown.py`. Operator-generated
reports can be checked without GitHub network access:

```bash
python -m tools.release.check_release_evidence_live_audit_report --report-json tmp/release-evidence-live-audit-report.json
python -m tools.release.check_release_evidence_live_audit_markdown --report-json tmp/release-evidence-live-audit-report.json --report-md tmp/release-evidence-live-audit-report.md
python -m tools.release.generate_release_evidence_live_audit_archive --check
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

`tools/release/generate_release_evidence_live_audit_archive.py` indexes
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
python -m tools.release.audit_release_evidence_issue_snapshots --generated-at YYYYMMDDTHHMMSSZ --report-json release-artifacts/evidence/live-audit-reports/YYYYMMDDTHHMMSSZ-release-evidence-live-audit-report.json --report-md release-artifacts/evidence/live-audit-reports/YYYYMMDDTHHMMSSZ-release-evidence-live-audit-report.md
python -m tools.release.check_release_evidence_live_audit_report --report-json release-artifacts/evidence/live-audit-reports/YYYYMMDDTHHMMSSZ-release-evidence-live-audit-report.json
python -m tools.release.check_release_evidence_live_audit_markdown --report-json release-artifacts/evidence/live-audit-reports/YYYYMMDDTHHMMSSZ-release-evidence-live-audit-report.json --report-md release-artifacts/evidence/live-audit-reports/YYYYMMDDTHHMMSSZ-release-evidence-live-audit-report.md
python -m tools.release.generate_release_evidence_live_audit_archive --archive-dir release-artifacts/evidence/live-audit-reports
python -m tools.release.generate_release_evidence_live_audit_archive --archive-dir release-artifacts/evidence/live-audit-reports --check
```

For a direct live sync gate against the exact tracker issues linked in
`release-artifacts/latest/release-evidence-issue-links.json`, run:

```bash
python -m tools.release.fetch_release_evidence_issue_snapshot --output tmp/release-evidence-live-issues.json
python -m tools.release.check_release_evidence_issue_bodies --live-json tmp/release-evidence-live-issues.json
python -m tools.release.check_release_evidence_issue_closure --live-json tmp/release-evidence-live-issues.json
```

The equivalent Make target is `make release-evidence-live-issue-sync-check`.
This target is intentionally not part of default CI because it requires
authenticated GitHub access. It fetches each linked issue with `gh issue view`
instead of relying on a paginated `gh issue list` export, so stale tracker
bodies and premature closures cannot hide behind missing list rows.

To audit live GitHub label drift manually, export a snapshot and pass it to the
checker:

```bash
python -m tools.release.export_release_evidence_issue_snapshot --profile labels --exact-linked-issues --issue-links release-artifacts/latest/release-evidence-issue-links.json
python -m tools.release.check_release_evidence_issue_labels --live-json tmp/release-evidence-issue-labels.json
```

The release evidence issue body sync artifact is generated as
`release-artifacts/latest/release-evidence-issue-body-sync.json` and
`release-artifacts/latest/release-evidence-issue-body-sync.md`; run
`python -m tools.release.generate_release_evidence_issue_body_sync` to refresh the
exact GitHub issue body payloads and
`python -m tools.release.generate_release_evidence_issue_body_sync --check` to verify
they still match the current backlog and issue-link map. It remains tracker-only
and does not mark retained evidence complete.
Run `python -m tools.release.check_release_evidence_issue_bodies` to validate the
committed body-sync payloads. To audit live GitHub body drift without adding
network access to CI, fetch the exact linked issues and pass the snapshot to
the checker:

```bash
python -m tools.release.fetch_release_evidence_issue_snapshot --output tmp/release-evidence-live-issues.json
python -m tools.release.check_release_evidence_issue_bodies --live-json tmp/release-evidence-live-issues.json
```

If drift is reported, generate deterministic remediation files and update the
affected issue with the body-file command printed by the checker:

```bash
python -m tools.release.check_release_evidence_issue_bodies --write-body-files tmp/release-evidence-issue-bodies
gh issue edit ISSUE_NUMBER --repo 6529-Collections/6529Stream --body-file tmp/release-evidence-issue-bodies/issue-ISSUE_NUMBER.md
```

The autonomous state checker validates `ops/AUTONOMOUS_RUN.md` against
`ops/EXECUTION_BACKLOG.md` without network access. It fails if more than one
backlog row claims an active PR, if the active PR/issue/branch disagrees with
the current-state table, or if the current-state table omits fields needed for
thread resumes.

Run `python -m tools.release.check_release_evidence_issue_closure` to verify the
committed tracker map, `release-evidence-issue-backlog.json` backlog artifact,
body-sync artifact, packet index, and shared release evidence status manifest
agree on which tracker issues may close. To audit live GitHub closure state
without adding network access to CI, reuse the exact linked-issue snapshot:

```bash
python -m tools.release.fetch_release_evidence_issue_snapshot --output tmp/release-evidence-live-issues.json
python -m tools.release.check_release_evidence_issue_closure --live-json tmp/release-evidence-live-issues.json
```

If premature closure is reported, reopen the issue with the remediation command
printed by the checker and keep the requirement row open until the committed
evidence status is `complete` or `accepted_risk`.

The non-local release evidence intake runbook in
[`non-local-release-evidence.md`](../../non-local-release-evidence.md) defines the
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
use `python -m tools.release.generate_non_local_release_evidence` to generate the
metadata envelope from the matching committed requirement template and retained
artifact path. The helper computes the artifact digest, validates the output
with the canonical checker, and supports `--check` for drift detection. It does
not unblock a release row until the generated evidence is independently
reviewed and linked from `release-artifacts/latest/public-beta-evidence.json`.
When exact provenance contains shell-significant quotes, put it in the retained
Markdown artifact as exactly one inline-code `Command` field and pass
`--command-or-source-system-from-retained`. This file-backed transport keeps
the quote bytes out of native argv on Windows and POSIX systems. The checker
requires exact retained-command fidelity for fork deployment, fork ceremony,
and fork randomizer evidence, including the quotes around replay signatures.
External audit report evidence for issue #215 has a Markdown retained artifact
path at
`release-artifacts/evidence/external-audit-report/external-audit-report-retained-artifact-template.md`.
Run `python -m tools.release.test_external_audit_report_evidence` and
`python -m tools.release.check_external_audit_report_evidence` before generating the
metadata envelope. The committed file is template-only and keeps
`external_audit_report` missing until a final reviewed audit report, scope,
finding/remediation map, retest status, and reviewer confirmation are retained.
Post-audit remediation evidence for issue #231 has a Markdown retained artifact
path at
`release-artifacts/evidence/post-audit-remediation/post-audit-remediation-retained-artifact-template.md`.
Run `python -m tools.release.test_post_audit_remediation_evidence` and
`python -m tools.release.check_post_audit_remediation_evidence` before generating the
metadata envelope. The committed file is template-only and keeps
`post_audit_remediation` missing until finding-by-finding remediation status,
fix PRs or commits, regression tests, retest evidence, accepted-risk records,
release-note mapping, and reviewer confirmation are retained.
Fork deployment rehearsal evidence for issue #216 also has a Markdown retained
artifact path at
`release-artifacts/evidence/fork-deployment-rehearsal/fork-deployment-rehearsal-retained-artifact-template.md`.
Run `python -m tools.deployment.test_fork_deployment_rehearsal_evidence` and
`python -m tools.deployment.check_fork_deployment_rehearsal_evidence` before generating
the metadata envelope. The committed file contains mainnet-fork rehearsal
evidence captured at fork block `25316366`, with private RPC details redacted.
The CON-014 manager branch changed the retained deployment artifact set, so the
shared public-beta evidence row is currently `pending` and issue #216 is back
in the release-evidence issue-link set until this PR's updated artifact set is
reviewed. Public-beta readiness remains blocked.
Testnet deployment rehearsal evidence for issue #217 has its own Markdown
retained artifact path at
`release-artifacts/evidence/testnet-deployment-rehearsal/testnet-deployment-rehearsal-retained-artifact-template.md`.
Run `python -m tools.deployment.test_testnet_deployment_rehearsal_evidence` and
`python -m tools.deployment.check_testnet_deployment_rehearsal_evidence` before
generating the metadata envelope. The committed file is template-only and keeps
`testnet_deployment_rehearsal` missing until a reviewed testnet transcript,
transaction references, sanitized broadcast, generated manifest/address book,
explorer status, and reviewer confirmation are retained. Operators must redact
or omit private keys, tokens, private RPC URLs, bearer credentials, and other
sensitive values before retaining any transcript, command line, broadcast, or
linked artifact because the checker enforces the same no-secret policy. Pending
or reviewed retained references must be repo-relative files and may include one
optional `sha256:<64 lowercase hex>` digest; path escapes, missing files, stale
hashes, duplicate hashes, and bare 64-hex strings fail closed.
The Sepolia setup template lives at
`deployments/config/sepolia-6529stream-v0.1.0-001.template.json`; use it with
`docs/deployment.md#sepolia-deployment-rehearsal-runbook` and
`script/legacy/RehearseDeployment.s.sol:RehearseDeployment --sig "runSepolia()"`
when preparing future reviewed testnet evidence.
Public-beta verified-addresses evidence has a dedicated no-secret retained
artifact template at
`release-artifacts/evidence/public-beta-verified-addresses/public-beta-verified-addresses-retained-artifact-template.md`.
Run `python -m tools.release.test_public_beta_verified_addresses` and
`python -m tools.release.check_public_beta_verified_addresses` before generating
non-local evidence envelopes for `verified_deployed_addresses` or
`explorer_verification_status`. The checker requires Sepolia address-book and
deployment-manifest agreement, verified explorer rows, runtime bytecode,
constructor-argument, linked-library, release manifest/checksum, reviewer
metadata, and explicit redaction confirmations before a reviewed artifact can
pass. The committed file is template-only and keeps public beta blocked until
future reviewed testnet address evidence is accepted. Pending-review or
reviewed retained references must be repo-relative UTF-8 files and may include
one optional `sha256:<64 lowercase hex>` digest. Path escapes, missing files,
stale hashes, duplicate hashes, symlinked retained files, provider/API-token
URLs, credentialed URLs, bearer tokens or placeholders, CLI secret flags, and
bare 64-hex strings fail closed.
Production broadcast retention evidence has a dedicated no-secret retained
artifact template at
`release-artifacts/evidence/production-broadcast-retention/production-broadcast-retention-retained-artifact-template.md`.
Run `python -m tools.release.test_production_broadcast_retention` and
`python -m tools.release.check_production_broadcast_retention` before generating the
metadata envelope for `production_broadcast_retention`. The checker requires
sanitized command transcripts, sanitized Foundry broadcasts, derived
broadcast-manifest inputs, generated live deployment manifests, generated live
address books, release manifest/checksum digests, reviewer metadata, and
explicit redaction confirmations before a reviewed artifact can pass. The
committed file is template-only and keeps production release blocked until a
future reviewed production deployment retention record is accepted.

Live deployment manifest evidence has a dedicated no-secret retained artifact
template at
`release-artifacts/evidence/live-deployment-manifest/live-deployment-manifest-retained-artifact-template.md`.
Run `python -m tools.release.test_live_deployment_manifest_evidence` and
`python -m tools.release.check_live_deployment_manifest_evidence` before generating
the metadata envelope for `live_deployment_manifest`. The checker requires live
chain ID 1 manifest data, finalized contract addresses, bytecode hashes,
constructor arguments, address-book agreement, release digest references,
reviewer metadata, and explicit redaction confirmations before a pending-review
or reviewed artifact can pass. Referenced retained files must be ordinary
repo-relative UTF-8 files, not symlinks. The committed file is template-only and
keeps production release blocked until future reviewed live manifest evidence is
accepted. Normalize transaction hashes to `0x...`, content digests to
`sha256:<hex>`, and label the release manifest plus SHA256SUMS or
release-checksums digest lines in the retained release digest file.

Production verified-addresses evidence has a dedicated no-secret retained
artifact template at
`release-artifacts/evidence/production-verified-addresses/production-verified-addresses-retained-artifact-template.md`.
Run `python -m tools.release.test_production_verified_addresses` and
`python -m tools.release.check_production_verified_addresses` before generating
non-local evidence envelopes for `production_address_books` or
`live_explorer_verification`. The checker requires live address-book and
deployment-manifest agreement, verified explorer rows, runtime bytecode,
constructor-argument, linked-library, release manifest/checksum, reviewer
metadata, and explicit redaction confirmations before a reviewed artifact can
pass. The committed file is template-only and keeps production release blocked
until future reviewed live address evidence is accepted. Pending-review or
reviewed retained references must be repo-relative UTF-8 files and may include
one optional `sha256:<64 lowercase hex>` digest. Path escapes, missing files,
stale hashes, duplicate hashes, symlinked retained files, provider/API-token
URLs, credentialed URLs, bearer tokens or placeholders, CLI secret flags, and
bare 64-hex strings fail closed. Normalize any `sha256sum`-style retained
digest output, including the contents of retained release digest files, to the
explicit `sha256:<hex>` form before review.

Fork/testnet metadata-browser evidence has a draft generator for retained
capture outputs. Run
`python -m tools.release.test_generate_fork_metadata_browser_evidence_draft`,
`python -m tools.release.test_fork_metadata_browser_evidence`, and
`python -m tools.release.check_fork_metadata_browser_evidence` before generating or
reviewing a `fork_testnet_metadata_browser_evidence` retained artifact. The
generator copies a browser summary, generated `tokenURI`, and redacted
transcript into a self-contained pending-review bundle, requires an explicit
deployed-contract assertion, and preserves the blocked public-beta posture until
reviewed evidence is linked from the public-beta manifest.

Live metadata-browser evidence has a dedicated no-secret retained artifact
template at
`release-artifacts/evidence/live-metadata-browser/live-metadata-browser-retained-artifact-template.md`.
Run `python -m tools.release.test_live_metadata_browser_evidence` and
`python -m tools.release.check_live_metadata_browser_evidence` before generating the
non-local evidence envelope for `live_metadata_browser_evidence`. The checker
requires retained browser-summary JSON, generated tokenURI output or digest,
browser transcript or screenshot, live mainnet chain ID, deployed contract
addresses, token and collection IDs, empty unexpected-request/error arrays,
animation bootstrap success, parent-frame isolation, reviewer metadata, and
explicit redaction confirmations before a reviewed artifact can pass. The
committed file is template-only and keeps production release blocked until
future reviewed live metadata browser evidence is accepted. Pending-review or
reviewed retained references must be repo-relative files and may include one
optional `sha256:<64 lowercase hex>` digest; path escapes, missing files, stale
hashes, duplicate hashes, provider/API-token-shaped URLs, credentialed URLs,
and bare 64-hex strings fail closed. Normalize any `sha256sum`-style retained
digest output to the explicit `sha256:<hex>` form before review. Retained
evidence must be UTF-8 text and must not be symlinked.

Live ceremony evidence has a dedicated no-secret retained artifact template at
`release-artifacts/evidence/live-ceremony/live-ceremony-retained-artifact-template.md`.
Run `python -m tools.deployment.test_live_ceremony_evidence` and
`python -m tools.deployment.check_live_ceremony_evidence` before generating the
non-local evidence envelope for `live_ceremony_evidence`. The checker requires
live deployment context, governance participant identities, ownership transfer,
role grant/revoke, signer setup, metadata/freeze, auction, emergency-control,
dry-run, monitoring handoff, generated live artifact references, reviewer
metadata, and explicit redaction confirmations before a reviewed artifact can
pass. The committed file is template-only and keeps production release blocked
until future reviewed live ceremony evidence is accepted. Pending-review or
reviewed retained references must be repo-relative files and may include one
optional `sha256:<64 lowercase hex>` digest; path escapes, missing files, stale
hashes, duplicate hashes, provider/API-token-shaped URLs, credentialed URLs,
bearer tokens, and bare 64-hex strings fail closed. Normalize any
`sha256sum`-style retained digest output to the explicit `sha256:<hex>` form
before review.

Fork/testnet randomizer operations evidence has a dedicated no-secret retained
artifact template at
`release-artifacts/evidence/fork-randomizer-operations/fork-randomizer-operations-retained-artifact-template.md`.
Run `python -m tools.deployment.test_fork_randomizer_operations_evidence`,
`python -m tools.deployment.check_fork_randomizer_operations_evidence`, and
`python -m tools.deployment.check_randomizer_operations` before generating the non-local
evidence envelope for `fork_testnet_randomizer_operations_evidence`. The
checker requires fork or testnet provider configuration, funding status,
reserve status, request health, lifecycle controls, monitoring handoff,
repo-relative retained artifact references, optional declared `sha256:`
hashes, reviewer metadata, and explicit redaction confirmations before a
pending-review or reviewed artifact can pass. The committed file contains fork
randomizer operations evidence, but the CON-014 manager branch changed the
retained artifact set, so the shared public-beta evidence row is currently
`pending` and issue #220 is back in the release-evidence issue-link set until
this PR's updated artifact set is reviewed. Public beta remains blocked.

Live randomizer operations evidence has a dedicated no-secret retained artifact
template at
`release-artifacts/evidence/live-randomizer-operations/live-randomizer-operations-retained-artifact-template.md`.
Run `python -m tools.deployment.test_live_randomizer_operations_evidence`,
`python -m tools.deployment.check_live_randomizer_operations_evidence`, and
`python -m tools.deployment.check_randomizer_operations` before generating the non-local
evidence envelope for `live_randomizer_operations_evidence`. The checker
requires live provider configuration, funding status, reserve status, request
health, lifecycle controls, monitoring handoff, generated live artifact
references, reviewer metadata, and explicit redaction confirmations before a
reviewed artifact can pass. The committed file is template-only and keeps
production release blocked until future reviewed live randomizer operations
evidence is accepted. Pending-review or reviewed retained references must be
repo-relative files and may include one optional `sha256:<64 lowercase hex>`
digest; path escapes, missing files, stale hashes, duplicate hashes,
provider/API-token-shaped URLs, credentialed URLs, bearer tokens, and bare
64-hex strings fail closed. Normalize any `sha256sum`-style retained digest
output to the explicit `sha256:<hex>` form before review. Retained evidence
must be UTF-8 text and must not be symlinked.

The release-checksum step builds `release-artifacts/latest/SHA256SUMS` and
`release-artifacts/latest/release-checksums.json` from the committed release
artifact, public-beta evidence, release evidence issue backlog, release
evidence issue-link map, release evidence issue body sync, deployment manifest,
address-book, schema, ceremony evidence, governed-parameter inventory,
record-family authorization source/inventory/evidence package, release-manifest,
bytecode proof, and release-candidate lockfile outputs, plus the checked
governed-parameter and record-family authorization checker/tests, the canonical
non-generated release-tool call policy and its schema, mint-manager domain
constant spec, post-entropy completion-gas planning package, and Python
toolchain provenance. The release manifest and
candidate lockfile bind the policy and schema by exact path, SHA-256, byte size,
and schema identity/version before the checksum bundle binds both files. This
gives maintainers a deterministic, signable checksum bundle. The
release manifest intentionally marks checksum-bundle digests as
`not_available_self_referential` because the checksum bundle covers
`release-manifest.json`; embedding the final bundle digest in that covered file
would create a hash cycle. Detached signatures and signed git tags still
require a release ceremony and are not produced by the local smoke gate.

Canonical checksum generation uses the exact reviewed covered-path inventory
and independently pins the seven release-tool roots, 24-file runtime closure,
and ten focused trust-policy tests as ordinary, in-repository files. The
canonical, manually reviewed
`release-artifacts/release-tool-call-policy.json` records exactly those 34
runtime and focused-test paths, including each source SHA-256 and byte size plus
its import, member, and call multisets. Its schema is
`release-artifacts/schema/release-tool-call-policy.v1.schema.json`. The
generator and offline verifier independently retain the exact root/runtime/test
sets and the allowed dangerous-capability names and path memberships; neither
accepts the policy as authority to redefine its own scope. Manifest, lockfile,
checksum, offline-verifier, and both release-mode paths fail closed on missing,
substituted, stale, or semantically invalid policy/schema bytes.

The revised canonical projection contains exactly 301 configured roots,
expanding to exactly 477 covered-file entries in each checksum index. The current
collection artist registry and its interface are explicit roots so the immutable
verifier sees the same artist source inventory as the working checkout. This
does not authorize the unimplemented V2 artist suite. The Windows
CI wrapper policy test is an exact covered root so its native builder-authority
wiring cannot drift outside the release checksum bundle. The twelve
record-family source-semantic inputs above account for twelve exact roots and
twelve exact entries; they do not imply coverage of any other file under
`smart-contracts/` or `script/`. The #672 package adds seven exact roots
for its artifact, generator/checker/tests, and three Solidity target-fixture
sources; its dedicated via-IR snapshot is the eighth new record under the
already covered baseline directory. The Governance V2 policy artifact, checker,
and tests add three exact roots; those files plus the policy schema under the
already covered schema directory add four exact entries. The additional exact
root binds `tools/build/check_contract_size_budget.py`, which is executed directly
by `RISK-SIZE-001`. The #670 publication adds fourteen exact roots for its Proposed
ADR, strict matrix, schema, checker, hostile tests, frozen operation source,
four existing immutable-provider interfaces read by the checker, and the
reviewed ArchiveV2 and RegistryV2 implementation/interface source pairs.
The record/event reconstruction historical Git-object archive is one further
exact root and file. It makes the compatibility-only 12/21 and 27/2 source/event
projections reproducible in a fresh checkout by binding raw commit, tree, and
deduplicated blob payloads; its checker recomputes object IDs and traverses the
archived trees without requiring a Git ref or Git subprocess. This archive does
not authorize those historical sources or add deployment or readiness credit.
The owner-record continuity prerequisite adds five exact roots for its packet,
rationale, schema, independent checker, and hostile tests. It preserves each
retained semantic record hash while binding a separate owner-V2 commitment and
fixed zero/one/two record-delta envelope; it does not select physical owner
storage, accept any shared root row, authorize source, or add deployment,
audit, or readiness credit.

The deliberately narrow Python dependency grammar supports ordinary
`Import`/`ImportFrom` and direct string-literal `importlib.import_module`,
`__import__`, or `builtins.__import__` calls only. This is explicitly a
first-party Python **import closure**, not a claim that arbitrary process or
data dependencies can be inferred from Python source. Importer objects may not
escape those direct call sites. `exec`, `eval`, `compile`, `runpy`, `operator`,
`pkgutil`, `pydoc`, serialization-backed module loaders, `importlib.util` or
`importlib.machinery` loader APIs, `exec_module`, `load_module`,
frame-introspection importer recovery, and unreviewed subprocess use fail
closed; new alternate execution mechanisms require an explicit policy review.
Reviewed dangerous exceptions remain limited to their code-owned capability
and path allowlists. Those process commands do not add files to the first-party
import closure. Broad directory entries do not stand in for reviewed tool
files. Test-only subset
bundles require the explicit `custom-subset` policy and a noncanonical output
directory, and cannot overwrite or masquerade as `release-artifacts/latest`.

The canonical inventory includes the root `.gitattributes` policy itself.
Before hashing, generation and offline verification resolve every expanded
covered file against that policy and reject ambiguous or undeclared text line
endings. Files declared `eol=lf` may contain no carriage returns; files
declared `eol=crlf` may contain only complete CRLF pairs; explicitly binary
files remain byte-for-byte inputs. Mixed line endings, nested attribute-policy
overrides, path redirection, and a missing or substituted `.gitattributes`
binding fail closed in both checksum indexes. Hash and size are derived from
the same validated byte snapshot so checkout-specific newline conversion
cannot produce a different canonical bundle.

The changelog gate checks release-impacting paths against `CHANGELOG.md`. If a
branch changes contract surfaces, release artifacts, deployment artifacts, or
release workflow files, `CHANGELOG.md` must be part of the change and its
`Unreleased` section must contain a non-placeholder bullet. The release-impact
rules are documented in [`release-policy.md`](../../release-policy.md).
