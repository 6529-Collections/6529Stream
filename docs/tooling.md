# Tooling

6529Stream uses pinned Foundry and Slither toolchains for its checked baseline.

## Versions

| Tool | Version |
| --- | --- |
| Foundry | `v1.7.1` |
| Solidity compiler | `0.8.19` |
| Python (Linux CI/release) | `3.12.13` |
| Slither | `0.11.5` |
| Crytic Compile | `0.3.11` |
| solc-select | `1.2.0` |
| eth-hash | `0.8.0` |
| Playwright | `1.60.0` |

## Reproducible Python Audit And Release Toolchain

[`requirements-tools.txt`](../requirements-tools.txt) is the short,
human-maintained list of direct tool intent. The generated
[`requirements-tools.lock`](../requirements-tools.lock) is the complete Linux
CI/release dependency graph. Every direct and transitive package is pinned to
one version and has one or more reviewed SHA-256 artifact hashes. Ordinary CI
and manual release mode both select CPython `3.12.13` through the full-SHA
pinned `actions/setup-python` action and install exactly the same lock with:

```bash
python -m pip install --disable-pip-version-check --require-hashes --only-binary=:all: -r requirements-tools.lock
python -m pip check
```

There is no live `pip --upgrade` step. The exact Python tool-cache artifact
provides pip, and `--require-hashes` fails if an artifact differs or dependency
resolution needs a package absent from the lock. `--only-binary=:all:` also
keeps unreviewed source builds out of the Linux evidence path.

`scripts/bootstrap-ec2.sh` and `scripts/bootstrap-windows.ps1` remain
contributor conveniences for heterogeneous local Python installations. They
consume the readable direct requirements and do not upgrade pip, but they are
not release-evidence install paths. A release or audit run must use the exact
Linux runtime and hashed lock above.

### Refresh And Review

Refresh the lock only in a clean Linux x86-64 environment running CPython
`3.12.13`. Use the reviewed generator and vulnerability-scanner versions, then
run the policy checks:

```bash
python -m venv .venv-lock-refresh
source .venv-lock-refresh/bin/activate
python -m pip install "pip-tools==7.6.0" "pip-audit==2.10.1"
CUSTOM_COMPILE_COMMAND='python -m piptools compile --generate-hashes --strip-extras --no-emit-index-url requirements-tools.txt' \
  python -m piptools compile --generate-hashes --strip-extras --no-emit-index-url \
  --output-file=requirements-tools.lock requirements-tools.txt
python -m pip_audit --require-hashes -r requirements-tools.lock
python scripts/test_python_toolchain.py
python scripts/check_python_toolchain.py
```

Review the full package/version change and every added or removed hash, not
only the five direct pins. The generated lock must not contain index URLs,
trusted-host settings, credentials, or private package references. Record or
remediate vulnerability findings before acceptance. Update the deliberately
maintained `EXPECTED_LOCKED_NAMES` closure in
`scripts/check_python_toolchain.py` in the same reviewed diff; the checker
rejects either missing or extra resolved distributions. The expected generated
diff is the lock plus the downstream release manifest/checksum bundle after the
normal generator sequence; changes to direct intent also update
`requirements-tools.txt`. Update the pinned Python, setup action, compiler, or
scanner deliberately in the same focused PR when one of those inputs changes.

The Playwright Python package is inside the hashed lock. Chromium itself is a
separate runtime download: `python -m playwright install --with-deps chromium`
uses the browser revision encoded by locked Playwright `1.60.0`, while the
runner's operating-system packages installed by `--with-deps` are outside the
Python package lock. Both workflows invoke that same locked module and command;
the Python lock does not claim to checksum Chromium or Ubuntu packages.

Python toolchain provenance is part of release evidence: the checksum bundle
covers the direct requirements, hashed lock, both consuming workflows, and the
checker plus its tests. This binds the reviewed install policy without storing
credentials or private-index configuration. It improves reproducibility only
and does not promote release maturity.

The checker is a static declaration guard for the reviewed workflow grammar,
canonical installer commands, lock closure, and workflow inventory. It is not
a shell sandbox and does not prove the absence of commands assembled dynamically
through variables, `eval`, or equivalent runtime construction. Full-workflow
checksum binding and PR review remain the controls for arbitrary command changes.

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
python scripts/test_external_call_gas_inventory.py
python scripts/check_external_call_gas_inventory.py
forge build --sizes --via-ir --skip test --skip script --force
python scripts/test_release_build_artifacts.py
python scripts/build_release_artifacts.py
python scripts/build_release_artifacts.py --check
python scripts/test_contract_size_budget.py
python scripts/check_contract_size_budget.py
python scripts/test_solidity_formatting.py
python scripts/check_solidity_formatting.py
python scripts/test_python_toolchain.py
python scripts/check_python_toolchain.py
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
python scripts/generate_deployment_manifest.py --config deployments/config/fork-mainnet-6529stream-v0.1.0-001.json --check
python scripts/generate_deployment_manifest.py --config deployments/config/fork-mainnet-6529stream-v0.1.0-001-broadcast.json --check
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
python scripts/test_production_release_signing_evidence.py
python scripts/check_production_release_signing_evidence.py
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
python scripts/test_mint_manager_domain_constants.py
python scripts/check_mint_manager_domain_constants.py
python scripts/test_audit_package.py
python scripts/check_audit_package.py
python scripts/test_audit_finding_workflow.py
python scripts/check_audit_finding_workflow.py
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
python scripts/test_autonomous_state.py
python scripts/check_autonomous_state.py
python scripts/test_markdown_links.py
python scripts/check_markdown_links.py
python scripts/test_curator_rewards_flow.py
python scripts/check_curator_rewards_flow.py
python scripts/test_withdrawals_credits_flow.py
python scripts/check_withdrawals_credits_flow.py
python scripts/test_release_readiness.py
python scripts/check_release_readiness.py
python scripts/test_genesis_deployment_profile.py
python scripts/check_genesis_deployment_profile.py
python scripts/test_system_manifest_payload_vector.py
python scripts/check_system_manifest_payload_vector.py
python scripts/test_system_manifest_payload_vector_reference.py
python scripts/check_system_manifest_payload_vector_reference.py
python scripts/test_slither_baseline.py
python scripts/check_slither_baseline.py --baseline-only
python scripts/test_release_manifest.py
python scripts/generate_release_manifest.py --check
python scripts/test_release_checksums.py
python scripts/generate_release_checksums.py --check
python scripts/test_changelog_check.py
python scripts/check_changelog.py
python scripts/test_deployment_rehearsal_gate.py
python scripts/check_deployment_rehearsal_gate.py
forge script script/RehearseDeploymentSuite.s.sol:RehearseDeploymentSuite --sig "run()" --via-ir
forge script script/RehearseDeployment.s.sol:RehearseDeployment --sig "run()" --via-ir
forge script script/RehearseAuctionCeremony.s.sol:RehearseAuctionCeremony --sig "run()" --via-ir
forge script script/RehearseEmergencyRedeployment.s.sol:RehearseEmergencyRedeployment --sig "run()" --via-ir
```

The deployment rehearsal gate parity step is a static guard over `Makefile`,
`scripts/check.sh`, `scripts/check.ps1`, and `.github/workflows/ci.yml`. It
fails if the aggregate suite command, any standalone rehearsal command, or the
CI retained log names drift out of the local/CI smoke path; it does not replace
the actual Forge rehearsal scripts that run immediately afterward.

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
reason. The current baseline has 648 explicit exclusions, so it is a checked
burn-down queue rather than proof that API documentation is complete. See
[`natspec-coverage.md`](natspec-coverage.md).

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
`python scripts/check_core_bytecode_spend_policy.py` will pass.
Accepted headroom-recovery records use `measured_delta_bytes` as
`runtime_size_bytes - baseline_runtime_size_bytes`, which makes reductions
negative and bytecode spend positive.
The current approved `StreamCore` runtime baseline is 22,184 bytes with
2,392 bytes of EIP-170 margin. The current measured proof is above that baseline
under the accepted CON-012 exception:
`release-artifacts/latest/bytecode-release-proof.json` records 24,152 bytes
with 424 bytes of EIP-170 margin.
This CON-014 branch also refreshes via-IR bytecode hashes for contracts whose
source files are otherwise unchanged in the diff. `StreamCore` changes because
its imported `IStreamMintManager` source expands from the prior marker-only
interface to the full launch manager ABI while preserving Core's external ABI
method identifiers; Core storage changes include the prepared-mint manager
tracking added for this slice. `StreamPrimarySaleSettlement` has
unchanged source, ABI method identifiers, and storage layout; the regenerated
proof refreshes the stale prior via-IR release artifact baseline to the current
compiled output. These changes are release-evidence changes, not hidden source
edits to those contracts.

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
Its bytecode authority is `python scripts/build_release_artifacts.py`, not the
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
likewise derived from the same captured bytes. The builder stages only
configured named artifacts alongside retained compiler inputs and the build
receipt, then replaces
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
settings, toolchain, and artifact bindings. Tests and scripts are excluded from
those source closures. The deterministic ignored build receipt binds the
config, Foundry config, exact Forge version output, explicit normalized Forge
argv, compiler policy, target, complete metadata source universe and hashes,
compiler-settings hash, canonical build-input hash, and artifact hash. The
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
`scripts/materialize_canonical_deployment_plan.py`. It consumes, but never
rebuilds, the validated `out-release/release-build-manifest.json` receipt and
the exact configured artifacts produced by the canonical builder. Before
materializing any bytecode, it runs the builder's complete
`validate_release_output(...)` path, then checks the candidate's pinned receipt,
catalog, release-config, Foundry-config, and artifact hashes. It derives the
constructor ABI from each receipt-bound artifact, ABI-encodes the declared
arguments, resolves the artifact's exact creation/runtime library positions
and runtime immutable positions, and emits ordered full initcode plus expected
runtime bytecode and Keccak-256 hashes.

Version 1 accepts only `candidate_kind: non_production_fixture` with both
`production_candidate` and `readiness_evidence` set to `false`. The committed
fixture at
`deployments/config/canonical-deployment-candidate-non-production.json`
materializes one `DependencyRegistry` instance with literal Anvil-only admin
and library addresses. Its `profile_entry_id` is deliberately `null`; it is not
the strict instance-aware genesis candidate required by issue #656. Candidate
and output shapes are documented by
`deployments/schema/canonical-deployment-candidate.schema.json` and
`deployments/schema/canonical-deployment-plan.schema.json`.

After producing the canonical isolated build, run the focused tool as follows:

```bash
python scripts/test_materialize_canonical_deployment_plan.py
python scripts/materialize_canonical_deployment_plan.py \
  --candidate deployments/config/canonical-deployment-candidate-non-production.json \
  --output tmp/canonical-deployment-plan.json
python scripts/materialize_canonical_deployment_plan.py \
  --candidate deployments/config/canonical-deployment-candidate-non-production.json \
  --output tmp/canonical-deployment-plan.json \
  --check
```

Materialized plans are ephemeral operator inputs and may only be written below
the repository `tmp/` directory. They are not generated release evidence.
Candidate, receipt, artifact, and output paths reject repository escapes and
symlink, junction, or reparse components. Duplicate JSON members, floats,
non-I-JSON integers, stale or mutated receipts/artifacts, constructor ABI or
argument-hash drift, missing/extra/unresolved/wrong/overlapping links, missing
or overlapping immutables, target mismatches, forward dependencies, and
non-ephemeral output paths fail closed.

This materializer does not derive salts or deployment addresses, broadcast
transactions, inspect deployed code, retain ceremony evidence, or modify the
existing Forge scripts. A broadcaster and the issue #656 strict instance-aware
production candidate are still required before issue #677 can supply
production broadcast-bytecode parity. This slice therefore does not close
issue #656 or #677 and does not change release maturity.

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
`2513151416a7fc01753226120b415de67ba4f1e5ebf79e6e7ae8a1a3e8aefdc4`.
A separate reviewer-pinned canonical-JSON lock covers every target semantic,
including all top-level metadata, authorization and ownership policy, normative
homes, coverage counts, bytecode-budget groups, required-absence and bootstrap
policy, and every ordered active or retired function/event row, at SHA-256
`18992066d0c6b22c27d37112b13e6b7d3d7efe5d8e46b4ded9fa25d6d0652f55`.
Implementation `--check` also closes the retirement catalog in both directions:
every current baseline Core function/event shape must have exactly one active or
retired disposition, and every retired row must match a current-baseline shape.
The target, contract config, and ABI baseline are loaded as strict UTF-8,
duplicate-free, schema-restricted I-JSON; invalid UTF-8, duplicate members,
non-finite or floating-point values, and integers outside the I-JSON safe range
fail closed. Validate the target without reading `out/` or the implementation
baseline with:

```bash
python scripts/check_abi_compatibility.py --target-only
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
lowercase, and are regenerated with `python scripts/generate_address_books.py`.
The default drift check includes the Anvil placeholder, Anvil broadcast-derived,
and current fork-mainnet broadcast-derived address books.

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

The release-candidate lockfile step writes
`release-artifacts/latest/release-candidate-lockfile.json` after the bytecode
release proof and before the checksum bundle:

```sh
python scripts/test_release_candidate_lockfile.py
python scripts/generate_release_candidate_lockfile.py --check
```

The lockfile ties the release manifest, bytecode release proof, public-beta
evidence, risk register, release notes, blocker reports, release evidence issue
outputs, and release-signature evidence into one deterministic review artifact.
The committed local baseline explicitly keeps the final commit/tag/signature
lock in `not_locked_until_signed_release_tag` status until a real release
ceremony supplies production signatures and a signed tag.

The production release-signing evidence step validates the dedicated no-secret
retained artifact template at
`release-artifacts/evidence/production-release-signing/production-release-signing-retained-artifact-template.md`:

```sh
python scripts/test_production_release_signing_evidence.py
python scripts/check_production_release_signing_evidence.py
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
`python scripts/generate_release_manifest.py` after any covered input changes.
The optional live audit report bundle records the repository target, selected
issue-audit profiles, retained snapshot paths, snapshot digests, command
provenance, checker outcomes, explicit snapshot freshness/currentness claims,
and the unchanged blocked-readiness warning.

The architecture/threat-model step validates [`architecture.md`](architecture.md)
and [`threat-model.md`](threat-model.md), the auditor-facing map of system
components, trust boundaries, value/custody flows, threat categories, residual
risks, and evidence links.

The mint-manager domain constants step validates the checked
[`launch-v1-target-architecture.md`](launch-v1-target-architecture.md)
`StreamMintManager` domain table against `StreamMintManager.sol` and recomputes
each listed `keccak256` preimage with `cast`, failing on source, spec, or hash
drift.

The audit-package step validates [`audit-package.md`](audit-package.md), the
single auditor-facing index over maturity, scope, ADRs, tests, static analysis,
deployment/release evidence, known blockers, accepted local-baseline
dispositions, and security reporting.

The audit-finding-workflow step validates
[`audit-finding-workflow.md`](audit-finding-workflow.md), the public-safe
external audit finding intake, triage, remediation, retest, accepted-risk, and
closure workflow that stays aligned with the checked audit finding issue form
and post-audit remediation evidence handoff.

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
The failed randomness drill evidence step validates the narrower checked
retained artifact template under
[`release-artifacts/evidence/incident-drills/failed-randomness-drill-retained-artifact-template.md`](../release-artifacts/evidence/incident-drills/failed-randomness-drill-retained-artifact-template.md)
for request identity, provider type, provider epoch, pending/stale/failed/final
request state, metadata state, invalid callback handling, retry or stale
marking, provider migration boundaries, monitoring handoff, review, and
redaction. It is source-aware and checks that randomizer lifecycle events,
stale marking, retry, failed post-processing, provider-specific fulfillment,
metadata-state docs, and randomizer operations docs still exist.
The bad metadata/dependency drill evidence step validates the narrower checked
retained artifact template under
[`release-artifacts/evidence/incident-drills/bad-metadata-dependency-drill-retained-artifact-template.md`](../release-artifacts/evidence/incident-drills/bad-metadata-dependency-drill-retained-artifact-template.md)
for metadata schema/state, token URI snapshots, URI/UTF-8/raw-attribute or
browser-sandbox failure, dependency key/version/content hash, freeze manifest,
repin boundaries, ERC-4906/cache invalidation, marketplace/indexer handoff,
review, and redaction. It is source-aware and checks that `StreamCore`,
`DependencyRegistry`, `StreamMetadataRenderer`, metadata/freeze/dependency
tests, incident-response docs, dependency operations docs, and metadata docs
still expose the controls the retained artifact references.

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
The strict release-mode decision remains opt-in rather than part of the default
`make check` baseline, which runs the structural
`genesis-deployment-profile-check` and `python scripts/test_release_mode.py`.
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
no deployment addresses, instance identity, probe-parameter bindings, or
on-chain manifest reconciliation and therefore can never clear production
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
first-party production High/Medium row that remains Open. The current 38-row
set is a non-waivable technical blocker under issue #658; exact analyzer drift
parity is not acceptance. Production mode then reads the checksum-covered
`release-artifacts/latest/abi-checksums.json` measurement, rejects missing,
malformed, boolean-as-integer, or arithmetically inconsistent `StreamCore` size
fields, and requires at least 2,000 bytes of EIP-170 runtime headroom. That
mode also invokes the genesis checker in strict completeness mode: missing,
extra, duplicate, ambiguous, wrong-scope, wrong-interface, wrong-marker,
unapproved-alias, fallback, and probe gaps are production blockers. Even a v1
catalog with no mapping gaps remains categorically insufficient. Production
stays fail-closed until a checked schema for an instance-aware genesis
deployment candidate reconciles deployment manifests, address books,
source-verification inputs, the on-chain system-manifest payload, retained
rehearsal/live evidence, and the release candidate lockfile. That remaining
work is tracked by
[issue #656](https://github.com/6529-Collections/6529Stream/issues/656). The
checked `release-artifacts/system-manifest-payload-vector.json` is deliberately
only a `target_abi_lock_fixture`: it consumes all 60 planning entries and proves
RFC8785/I-JSON, fixed-chunk, commitment, and canonical root-descriptor mechanics,
including one synthetic release-wide deployment-identity digest reused by every
payload occurrence under the production outer domain. Its deterministic
synthetic addresses and hashes are not deployment or readiness evidence.
Regenerate it with
`python scripts/generate_system_manifest_payload_vector.py`; validate drift with
`python scripts/test_system_manifest_payload_vector.py` followed by
`python scripts/check_system_manifest_payload_vector.py`, then run
`python scripts/test_system_manifest_payload_vector_reference.py` and
`python scripts/check_system_manifest_payload_vector_reference.py`. The reference
oracle deliberately imports neither the generator nor the primary checker: it
independently encodes the audited JCS/ABI preimages and hard-pins the reviewed
profile, payload, deployment-identity, chunk, commitment, and root-descriptor
goldens. Update those goldens only after an independent recomputation and review.
The generator has no `--check` mode; both checkers are fail-closed check commands.

The non-waivable Core headroom threshold comes from the
[`Genesis Deployment Profile`](launch-conformance-matrix.md#genesis-deployment-profile)
and [`Core Hook Budget`](launch-v1-target-architecture.md#core-hook-budget), and
is tracked by [issue #654](https://github.com/6529-Collections/6529Stream/issues/654).
The current 424-byte margin intentionally leaves production release mode red
until the tracked slimming work lands; ordinary `make check` remains usable for
development.

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

For a direct live sync gate against the exact tracker issues linked in
`release-artifacts/latest/release-evidence-issue-links.json`, run:

```bash
python scripts/fetch_release_evidence_issue_snapshot.py --output tmp/release-evidence-live-issues.json
python scripts/check_release_evidence_issue_bodies.py --live-json tmp/release-evidence-live-issues.json
python scripts/check_release_evidence_issue_closure.py --live-json tmp/release-evidence-live-issues.json
```

The equivalent Make target is `make release-evidence-live-issue-sync-check`.
This target is intentionally not part of default CI because it requires
authenticated GitHub access. It fetches each linked issue with `gh issue view`
instead of relying on a paginated `gh issue list` export, so stale tracker
bodies and premature closures cannot hide behind missing list rows.

To audit live GitHub label drift manually, export a snapshot and pass it to the
checker:

```bash
python scripts/export_release_evidence_issue_snapshot.py --profile labels --exact-linked-issues --issue-links release-artifacts/latest/release-evidence-issue-links.json
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
network access to CI, fetch the exact linked issues and pass the snapshot to
the checker:

```bash
python scripts/fetch_release_evidence_issue_snapshot.py --output tmp/release-evidence-live-issues.json
python scripts/check_release_evidence_issue_bodies.py --live-json tmp/release-evidence-live-issues.json
```

If drift is reported, generate deterministic remediation files and update the
affected issue with the body-file command printed by the checker:

```bash
python scripts/check_release_evidence_issue_bodies.py --write-body-files tmp/release-evidence-issue-bodies
gh issue edit ISSUE_NUMBER --repo 6529-Collections/6529Stream --body-file tmp/release-evidence-issue-bodies/issue-ISSUE_NUMBER.md
```

The autonomous state checker validates `ops/AUTONOMOUS_RUN.md` against
`ops/EXECUTION_BACKLOG.md` without network access. It fails if more than one
backlog row claims an active PR, if the active PR/issue/branch disagrees with
the current-state table, or if the current-state table omits fields needed for
thread resumes.

Run `python scripts/check_release_evidence_issue_closure.py` to verify the
committed tracker map, `release-evidence-issue-backlog.json` backlog artifact,
body-sync artifact, packet index, and shared release evidence status manifest
agree on which tracker issues may close. To audit live GitHub closure state
without adding network access to CI, reuse the exact linked-issue snapshot:

```bash
python scripts/fetch_release_evidence_issue_snapshot.py --output tmp/release-evidence-live-issues.json
python scripts/check_release_evidence_issue_closure.py --live-json tmp/release-evidence-live-issues.json
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
When exact provenance contains shell-significant quotes, put it in the retained
Markdown artifact as exactly one inline-code `Command` field and pass
`--command-or-source-system-from-retained`. This file-backed transport keeps
the quote bytes out of native argv on Windows and POSIX systems. The checker
requires exact retained-command fidelity for fork deployment, fork ceremony,
and fork randomizer evidence, including the quotes around replay signatures.
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
the metadata envelope. The committed file contains mainnet-fork rehearsal
evidence captured at fork block `25316366`, with private RPC details redacted.
The CON-014 manager branch changed the retained deployment artifact set, so the
shared public-beta evidence row is currently `pending` and issue #216 is back
in the release-evidence issue-link set until this PR's updated artifact set is
reviewed. Public-beta readiness remains blocked.
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
linked artifact because the checker enforces the same no-secret policy. Pending
or reviewed retained references must be repo-relative files and may include one
optional `sha256:<64 lowercase hex>` digest; path escapes, missing files, stale
hashes, duplicate hashes, and bare 64-hex strings fail closed.
The Sepolia setup template lives at
`deployments/config/sepolia-6529stream-v0.1.0-001.template.json`; use it with
`docs/deployment.md#sepolia-deployment-rehearsal-runbook` and
`script/RehearseDeployment.s.sol:RehearseDeployment --sig "runSepolia()"`
when preparing future reviewed testnet evidence.
Public-beta verified-addresses evidence has a dedicated no-secret retained
artifact template at
`release-artifacts/evidence/public-beta-verified-addresses/public-beta-verified-addresses-retained-artifact-template.md`.
Run `python scripts/test_public_beta_verified_addresses.py` and
`python scripts/check_public_beta_verified_addresses.py` before generating
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
Run `python scripts/test_production_broadcast_retention.py` and
`python scripts/check_production_broadcast_retention.py` before generating the
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
Run `python scripts/test_live_deployment_manifest_evidence.py` and
`python scripts/check_live_deployment_manifest_evidence.py` before generating
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
Run `python scripts/test_production_verified_addresses.py` and
`python scripts/check_production_verified_addresses.py` before generating
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
`python scripts/test_generate_fork_metadata_browser_evidence_draft.py`,
`python scripts/test_fork_metadata_browser_evidence.py`, and
`python scripts/check_fork_metadata_browser_evidence.py` before generating or
reviewing a `fork_testnet_metadata_browser_evidence` retained artifact. The
generator copies a browser summary, generated `tokenURI`, and redacted
transcript into a self-contained pending-review bundle, requires an explicit
deployed-contract assertion, and preserves the blocked public-beta posture until
reviewed evidence is linked from the public-beta manifest.

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
future reviewed live metadata browser evidence is accepted. Pending-review or
reviewed retained references must be repo-relative files and may include one
optional `sha256:<64 lowercase hex>` digest; path escapes, missing files, stale
hashes, duplicate hashes, provider/API-token-shaped URLs, credentialed URLs,
and bare 64-hex strings fail closed. Normalize any `sha256sum`-style retained
digest output to the explicit `sha256:<hex>` form before review. Retained
evidence must be UTF-8 text and must not be symlinked.

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
Run `python scripts/test_fork_randomizer_operations_evidence.py`,
`python scripts/check_fork_randomizer_operations_evidence.py`, and
`python scripts/check_randomizer_operations.py` before generating the non-local
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
Run `python scripts/test_live_randomizer_operations_evidence.py`,
`python scripts/check_live_randomizer_operations_evidence.py`, and
`python scripts/check_randomizer_operations.py` before generating the non-local
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
address-book, schema, ceremony evidence, release-manifest, bytecode proof, and
release-candidate lockfile outputs, plus the checked mint-manager domain
constant spec and Python toolchain provenance. This
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

## External-Call Gas Inventory

Run the deterministic external-call gas policy gate with:

```bash
make external-call-gas-inventory-check
```

The gate runs `scripts/test_external_call_gas_inventory.py` and
`scripts/check_external_call_gas_inventory.py` across every Solidity source
under `smart-contracts/`. It masks comments and strings, inventories every
high-level Solidity call-option gas expression, and inventories every Yul call
gas argument except the exact Yul `gas()` builtin. A high-level function named
`gas` or `gasleft`, and a Yul helper named `gasleft`, therefore cannot imitate
the builtin exception. The checker exact-matches literal integer `constant` or
`immutable` gas-cap/reserve declarations, including constructor-assigned
immutables. It also rejects direct numeric assignments and numeric
struct-literal fields that feed an inventoried identifier or member-valued
call-gas argument. Parentheses and integer casts around one literal are
normalized; arithmetic literal initializers fail closed because their
effective value cannot be represented by the exact lexical inventory.
Solidity `.transfer(...)` and `.send(...)` calls, including whitespace- or
comment-separated spellings, are rejected because their implicit native-value
stipend is another fixed external-call gas policy. New sites, added uses,
removed sites whose inventory row was not retired, literal-value drift, and
missing inventory all fail.

The canonical inventory is
[`ops/EXTERNAL_CALL_GAS_INVENTORY.json`](../ops/EXTERNAL_CALL_GAS_INVENTORY.json).
Its finality, minting, and revenue rows are temporary open remediation work
tied to issue #669. They are not accepted-risk exceptions and must be removed
or connected to the Global Gas Parameter system in later focused slices. The
inventory is strict duplicate-free I-JSON: object keys are exact, floats,
non-finite values, unsafe integers, and Unicode surrogates fail closed. The
separate exception is pinned to the sole exact
`StreamGasProbe._provedStaticcall` use and the normative
`[LTA-GGP-PROBES]` authority; local, moved, or additional probe rationales
cannot create waivers. That row records deliberate probe-under-test semantics,
not a production-path immutable gas policy. Because this is a lexical policy
gate rather than a Solidity data-flow engine, normal review and focused
behavioral tests remain required when gas is computed through helper functions
or structured state.

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

After changing any production contract ABI or event surface, optionally run the
aggregate diagnostic, then build the canonical target-isolated artifacts and
regenerate the tracked release baseline with:

```bash
forge build --sizes --via-ir --skip test --skip script --force
python scripts/test_release_build_artifacts.py
python scripts/build_release_artifacts.py
python scripts/build_release_artifacts.py --check
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
python scripts/test_production_release_signing_evidence.py
python scripts/check_production_release_signing_evidence.py
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
python scripts/check_mint_manager_domain_constants.py
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
python scripts/test_genesis_deployment_profile.py
python scripts/check_genesis_deployment_profile.py
python scripts/generate_system_manifest_payload_vector.py
python scripts/test_system_manifest_payload_vector_reference.py
python scripts/check_system_manifest_payload_vector_reference.py
python scripts/generate_risk_register.py
python scripts/generate_release_notes.py
python scripts/generate_release_manifest.py
python scripts/generate_bytecode_release_proof.py
python scripts/generate_release_candidate_lockfile.py
python scripts/generate_release_checksums.py
python scripts/check_changelog.py
```

The check mode is:

```bash
python scripts/build_release_artifacts.py --check
python scripts/generate_release_artifacts.py --check
forge snapshot --match-path test/StreamGasSnapshot.t.sol --check release-artifacts/baselines/v0.1.0/gas-snapshot.snap
python scripts/generate_source_verification_inputs.py --check
python scripts/check_abi_compatibility.py --check
python scripts/generate_broadcast_manifest_input.py --check
python scripts/generate_deployment_manifest.py --check
python scripts/generate_deployment_manifest.py --config deployments/config/anvil-6529stream-v0.1.0-001-broadcast.json --check
python scripts/generate_deployment_manifest.py --config deployments/config/fork-mainnet-6529stream-v0.1.0-001.json --check
python scripts/generate_deployment_manifest.py --config deployments/config/fork-mainnet-6529stream-v0.1.0-001-broadcast.json --check
python scripts/generate_address_books.py --check
python scripts/test_ceremony_evidence.py
python scripts/check_ceremony_evidence.py
python scripts/check_randomizer_operations.py
python scripts/check_release_signatures.py
python scripts/test_production_release_signing_evidence.py
python scripts/check_production_release_signing_evidence.py
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
python scripts/check_mint_manager_domain_constants.py
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
python scripts/test_genesis_deployment_profile.py
python scripts/check_genesis_deployment_profile.py
python scripts/test_system_manifest_payload_vector.py
python scripts/check_system_manifest_payload_vector.py
python scripts/test_system_manifest_payload_vector_reference.py
python scripts/check_system_manifest_payload_vector_reference.py
python scripts/generate_risk_register.py --check
python scripts/generate_release_notes.py --check
python scripts/generate_release_manifest.py --check
python scripts/generate_bytecode_release_proof.py --check
python scripts/generate_release_candidate_lockfile.py --check
python scripts/generate_release_checksums.py --check
python scripts/check_changelog.py
```

The generator uses `release-artifacts/contracts.json` to define the production
contract and interface surface. Standard ERC interface IDs are pinned there when
the advertised ERC ID differs from a raw XOR over the artifact ABI.

The ABI compatibility baseline uses the production contract and published
interface sets from the same config file. Refresh it only when maintainers
intentionally accept a release surface change; removed or changed entries
should also update the breaking change documentation and release notes.
Checker diagnostics identify the changed production contract or published
interface with canonical `subject`; `contract` is retained as a deprecated
compatibility alias with the same value.

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
`requirements-tools.txt`, `requirements-tools.lock`, the ordinary CI and
release-mode workflows, the Python toolchain checker and its tests, the
canonical `release-artifacts/genesis-deployment-profile.json` and its checker,
tests, release-mode integration, and normative inventory mirrors,
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

## Slither Gates And Raw Diagnostics

The default `make check` path includes the fast
`slither-baseline-metadata-check`. It runs the checker tests plus
`scripts/check_slither_baseline.py --baseline-only`, validating the normalized
baseline and dispositions without launching Slither. The dedicated Ubuntu CI
job runs `make slither-baseline-check` with the pinned Foundry and Python
toolchain. That target invokes `scripts/check_slither_baseline.py --run-slither`
and fails when the live normalized first-party High/Medium set adds a new row or
leaves a tracked row stale.

The current checked baseline has 38 open findings: 4 High and 34 Medium. The
compact normalized JSON lives at
[`ops/SLITHER_BASELINE.json`](../ops/SLITHER_BASELINE.json), with reviewer-facing
classifications, rationales, and open proof requirements in
[`ops/SLITHER_BASELINE.md`](../ops/SLITHER_BASELINE.md). The approximately
128 MB raw Slither JSON is temporary analyzer output and is never committed.
After a production-source edit intentionally stales the strict provenance hash,
use the diagnostic `--candidate-slither-json` plus `--candidate-output` mode to
materialize semantic identities and scope counts in an OS temporary directory
or ignored `cache/`. Candidate output has no triage or
proof fields, cannot overwrite the canonical JSON/Markdown pair, is never
release evidence, and must not be committed. After reviewed JSON/provenance
updates, regenerate the mirror with `--render-markdown` before rerunning both
gates.

`make slither` remains the raw diagnostic:

```bash
slither . --config-file slither.config.json --foundry-compile-all
```

It can exit non-zero while baseline findings remain open. Likewise,
`forge fmt --check smart-contracts` is a raw formatting diagnostic because it
still prints the vendored/provenance exemption diff; the scoped
`make fmt-check` gate is part of `make check` and CI. Passing either Slither
baseline gate proves consistency with the committed checked inventory only. It
does not prove the findings harmless, complete an external audit, or promote
public-beta or production readiness. See [`docs/slither.md`](slither.md) for the
full workflow.
