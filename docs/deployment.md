# Deployment

Baseline record — not a specification. This document describes as-built
or operational state; the normative target is the specification set
indexed in [`docs/spec-policy.md`](spec-policy.md), and where this
document conflicts with a specification home, the specification wins.


6529Stream uses immutable, versioned redeployments for the current public-beta
plan. Deployment manifests are mandatory release artifacts and follow ADR 0007.

## Local Rehearsal

Run the local deployment rehearsal with:

```sh
forge script script/RehearseDeploymentSuite.s.sol:RehearseDeploymentSuite --sig "run()" --via-ir
```

The suite runs the local deployment, auction ceremony, and emergency
redeployment rehearsals as one aggregate evidence command. The broader local
and CI gates also keep the standalone script entrypoints automated, so the
aggregate path cannot mask a regression in a standalone `forge script` run. The
`make deployment-rehearsal-gate-check` target statically proves that the
aggregate command, standalone commands, and CI retained log names remain wired
across Make, Bash, PowerShell, and CI before the scripts execute. The
deployment rehearsal deploys and wires a local stack:

- `StreamAdmins`
- `DependencyRegistry`
- `StreamCore`
- `StreamContractMetadata`
- `StreamCuratorsPool`
- `StreamMinter`
- `StreamDrops`
- `StreamAuctions`
- `NextGenRandomizerVRF`
- `NextGenRandomizerRNG`

It also configures the ERC-7572-style contract-level metadata adapter with the
deployment `contractMetadataURI`, creates a sample collection, pins a sample
dependency version, assigns the VRF randomizer, sets mint phases, registers the
Safe placeholder as global admin, configures pause/signer emergency roles,
revokes the temporary deployment admin, and transfers Ownable control for
`StreamAdmins` and `StreamCore` to the configured Safe placeholder.

The rehearsal is not a production broadcast. It uses non-secret placeholder
addresses and local-only external dependency addresses.

For targeted debugging, retained evidence capture, and standalone-entrypoint
coverage, the individual local rehearsal scripts remain runnable and are also
exercised by the full local/CI check gate:

```sh
forge script script/RehearseDeployment.s.sol:RehearseDeployment --sig "run()" --via-ir
forge script script/RehearseAuctionCeremony.s.sol:RehearseAuctionCeremony --sig "run()" --via-ir
forge script script/RehearseEmergencyRedeployment.s.sol:RehearseEmergencyRedeployment --sig "run()" --via-ir
```

`script/RehearseAuctionCeremony.s.sol` adds the local auction ceremony layer on
top of the deployed stack. It configures a local deterministic randomizer,
signs an auction drop with the configured EIP-712 signer, mints the auction
drop, proves NFT custody is held by `StreamAuctions` while active, funds and
places a bid, settles after the auction end, withdraws poster/protocol/curator
proceeds, and asserts the auction contract returns to zero owed funds. The
returned evidence is local Anvil evidence only; fork, testnet, and production
broadcast ceremonies must still retain their own manifests and transaction
evidence.

`script/RehearseEmergencyRedeployment.s.sol` adds the local emergency
redeployment layer required by ADR 0007. It deploys an impacted historical
stack and a replacement stack with a distinct deployment version, proves the
manifest hashes, drop EIP-712 domains, and core/drops/auction addresses differ,
confirms both ceremonies transfer ownership to the configured Safe placeholder
and remove temporary deployer admin authority, then mints a fixed-price drop on
the replacement stack through the EIP-712 authorization path with a deterministic
randomizer. This is local Anvil evidence only; fork, testnet, and production
emergency redeployments still need their own retained manifests, broadcast
evidence, verification evidence, and incident/runbook records.

Run the local metadata browser rehearsal with:

```sh
python scripts/test_rehearsal_metadata_browser_sandbox.py
python scripts/check_rehearsal_metadata_browser_sandbox.py
```

To retain deterministic local capture artifacts for review, write the browser
summary, generated `tokenURI`, and redacted transcript to an ignored or
release-evidence staging directory:

```sh
python scripts/check_rehearsal_metadata_browser_sandbox.py \
  --summary-json /tmp/metadata-browser-summary.json \
  --token-uri-output /tmp/metadata-browser-token-uri.txt \
  --transcript-output /tmp/metadata-browser-transcript.md
```

When those capture outputs come from deployed fork or testnet contracts, use
the draft generator to assemble a checker-compatible pending-review evidence
bundle. The command requires the operator to assert that the metadata was
fetched from deployed fork/testnet contracts; it does not close
`fork_testnet_metadata_browser_evidence`, and the shared public-beta evidence
manifest remains blocked until the retained draft is reviewed and linked:

```sh
python scripts/generate_fork_metadata_browser_evidence_draft.py \
  --capture-summary-json /tmp/metadata-browser-summary.json \
  --token-uri-output /tmp/metadata-browser-token-uri.txt \
  --transcript-output /tmp/metadata-browser-transcript.md \
  --summary-output release-artifacts/evidence/fork-metadata-browser/browser-summary.json \
  --output release-artifacts/evidence/fork-metadata-browser/metadata-browser-evidence.md \
  --environment fork \
  --chain-id 1 \
  --git-commit <release commit> \
  --ci-run-or-operator-transcript <ci run or transcript id> \
  --block-or-reference <fork block or testnet reference> \
  --deployment-version <deployment version> \
  --contract StreamCore=<deployed address> \
  --operator <operator> \
  --reviewer <reviewer> \
  --metadata-fetched-from-deployed-contract
```

`script/RehearseMetadataBrowser.s.sol` builds on the deployment rehearsal by
deploying the local stack, registering a deterministic metadata dependency,
minting through the EIP-712 drop authorization path, finalizing token
randomness/image/attribute inputs, and returning the generated on-chain
`tokenURI`. The Python checker executes the generated final animation in the
same Playwright/Chromium sandbox policy used for committed metadata fixtures.
The optional retained outputs make the local run reviewable without adding RPC
secrets. This is a local Anvil release gate; fork, testnet, and production
broadcasts should still retain their own manifest and browser evidence during
the release ceremony.

## Canonical Initcode Materialization (Non-Production Only)

The current issue #677 tooling foundation can deterministically materialize
constructor arguments, linked creation bytecode, full initcode, and expected
linked/immutable runtime bytecode from the issue #674 canonical isolated
release build. It does not broadcast.

First produce `out-release/` with the canonical builder described in
[`docs/tooling.md`](tooling.md). Then run:

```sh
python scripts/test_materialize_canonical_deployment_plan.py
python scripts/materialize_canonical_deployment_plan.py \
  --candidate deployments/config/canonical-deployment-candidate-non-production.json \
  --output tmp/canonical-deployment-plan.json
python scripts/materialize_canonical_deployment_plan.py \
  --candidate deployments/config/canonical-deployment-candidate-non-production.json \
  --output tmp/canonical-deployment-plan.json \
  --check
```

The committed candidate is a deliberately narrow Anvil fixture. It binds one
canonical `DependencyRegistry` artifact to literal non-secret placeholder
addresses, has no genesis-profile entry, and sets both production/readiness
flags to false. The materializer performs actual Draft 2020-12 validation of
the committed candidate and every generated plan, revalidates the complete
canonical build, and checks exact receipt, catalog, config, artifact,
constructor, link, immutable, initcode, and runtime hashes before emitting the
ordered plan below `tmp/`. The build validator carries the exact receipt,
release-config, Foundry-config, and artifact byte snapshots into the
materializer. Paths and SHA-256 digests are rechecked, carried JSON is strictly
decoded for the receipt and artifacts, and those files are not reopened while
the plan is assembled. A shared target artifact is read once and reused across
instances, and a post-validation filesystem replacement cannot change the
validated snapshot used for the plan. Generator version 3 retains the
canonical build's restricted-source-root and portable compiler-path policies
in the validated plan.
Full creation bytecode plus ABI-encoded constructor arguments must fit the
49,152-byte EIP-3860 initcode limit. Treat any mismatch or limit breach as a
stop condition; do not weaken or bypass a binding to make a stale candidate
pass.

Every repository-relative path in the candidate and plan uses the same
runtime/schema portable policy. It rejects controls, Windows-invalid
characters and device names (including device names with extensions),
backslashes, drive or alternate-stream syntax, empty or dot-alias segments,
and segments ending in a dot or space.

Supplied immutable values are candidate assertions. The materializer checks
their artifact-declared byte widths and positions and the resulting expected
runtime hash; it does not derive the intended values from constructor
semantics, execute creation code, or prove that constructor execution returns
that runtime. Those semantic and deployed-runtime proofs remain required for a
production candidate.

The ordinary `make check`, `scripts/check.sh`, `scripts/check.ps1`, and Linux
CI paths run the focused unit suite, materialize this exact committed fixture,
and reparse/check the ephemeral output immediately after the canonical release
build. This is regression coverage for the tooling foundation, not deployment
or readiness evidence.

The output is ephemeral operator input, not a deployment manifest or release
artifact. The v1 candidate schema refuses production candidates. The
materializer does not derive deployment addresses or salts, prove constructor
semantics, execute creation code, or compare deployed runtime, and it has no
broadcaster. The strict instance-aware issue #656 candidate, the reusable
broadcaster, retained receipts, and constructor/deployed-runtime comparison
remain outstanding. Nothing in this workflow closes issue #656 or #677,
authorizes a testnet or mainnet broadcast, or establishes public-beta or
production readiness.

## Sepolia Deployment Rehearsal Runbook

The Sepolia rehearsal path is a no-secret public-beta evidence workflow. It does
not claim production readiness and it does not close
`testnet_deployment_rehearsal` until the retained artifact is reviewed.

Use the committed template at
`deployments/config/sepolia-6529stream-v0.1.0-001.template.json` as the
source-of-truth checklist for required public addresses, environment variables,
and retained outputs. Do not edit the template into a real manifest in place.
After a real broadcast, copy it to a non-template config path and replace every
placeholder with reviewed broadcast output.

Required operator environment variables:

| Variable | Retain In Repo | Purpose |
| --- | --- | --- |
| `SEPOLIA_RPC_URL` | No, redact value | Sepolia RPC endpoint used by the operator shell. |
| `SEPOLIA_CONTRACT_METADATA_URI` | Yes | Reviewed `StreamContractMetadata` constructor URI for contract-level metadata. |
| `SEPOLIA_DEPLOYER_ADDRESS` | Yes | Public Forge broadcaster address. Must match the approved signing backend used by the operator shell. |
| `SEPOLIA_ADMIN_SAFE` | Yes | Safe or multisig that receives ownership/admin authority. |
| `SEPOLIA_PAUSE_GUARDIAN` | Yes | Pause guardian address. |
| `SEPOLIA_EMERGENCY_RECIPIENT` | Yes | Emergency recipient address. |
| `SEPOLIA_DROP_SIGNER` | Yes | Drop authorization signer address. |
| `SEPOLIA_PAYOUT` | Yes | Payout recipient used by rehearsal drops and auctions. |
| `SEPOLIA_DELEGATION_REGISTRY` | Yes | Delegation registry dependency. |
| `SEPOLIA_VRF_COORDINATOR` | Yes | Sepolia VRF coordinator dependency. |
| `SEPOLIA_ARRNG_CONTROLLER` | Yes | Sepolia arRNG controller dependency. |
| `SEPOLIA_VRF_SUBSCRIPTION_ID` | Yes | VRF subscription or billing identifier. |
| `ETHERSCAN_API_KEY` | No, redact value | Explorer verification token used by the operator shell. |

Use an approved Foundry signing backend outside the repository for
`SEPOLIA_DEPLOYER_ADDRESS`: hardware wallet, keystore, cloud signer, or CI
secret approved for testnet. `SEPOLIA_ADMIN_SAFE` is the Safe or multisig that
receives ownership/admin authority; it is not automatically the transaction
broadcaster for the command below. If a Safe transaction pipeline is used for
deployment instead of Forge broadcasting, retain that as a separate reviewed
operator flow. Do not commit private keys, mnemonics, raw signatures, RPC
endpoint values, API tokens, signer-service credentials, local keystore paths,
or unreleased drop payloads. If a local command uses sensitive values, the
retained transcript must replace them with `<redacted>`.

Preflight from a clean checkout:

```sh
forge build --sizes --via-ir --skip test --skip script --force
forge test -vvv
python scripts/test_release_build_artifacts.py
python scripts/build_release_artifacts.py
python scripts/build_release_artifacts.py --check
python scripts/generate_release_artifacts.py --check
python scripts/generate_source_verification_inputs.py --check
python scripts/test_deployment_manifest.py
python scripts/check_testnet_deployment_rehearsal_evidence.py
python scripts/test_sepolia_evidence_preflight.py
python scripts/check_sepolia_evidence_preflight.py
```

The first aggregate Forge command is a warning and whole-tree size diagnostic;
its skip flags do not make it canonical production evidence. The subsequent
target-isolated builder validates the canonical receipt, artifacts, and retained
compiler inputs. The separate source-verification generator check validates the
explorer-verification inputs; neither command proves live explorer verification
or deployed-address parity, and they do not yet make the Forge deployment
scripts or broadcasts consume the same isolated initcode. Do not treat this
preflight as production broadcast-bytecode proof until
[issue #677](https://github.com/6529-Collections/6529Stream/issues/677) is
resolved.

Before the operator shell spends Sepolia gas, run the same preflight in
environment-required mode and retain only the redacted report. The checker
validates committed templates, runbook commands, checker scripts, and presence
of required environment variable names. It never writes or prints the
environment variable values:

```sh
python scripts/check_sepolia_evidence_preflight.py \
  --require-env \
  --output-json /tmp/sepolia-evidence-preflight.json
```

If this command reports `operator_env_missing`, do not broadcast yet. Configure
the missing variables in the operator shell, keep private values out of the
repository, and rerun the preflight before recording the deployment transcript.

Broadcast the Sepolia rehearsal from the operator shell:

```sh
forge script script/RehearseDeployment.s.sol:RehearseDeployment \
  --sig "runSepolia()" \
  --rpc-url "$SEPOLIA_RPC_URL" \
  --sender "$SEPOLIA_DEPLOYER_ADDRESS" \
  <approved Foundry signer flags> \
  --broadcast \
  --verify \
  --via-ir
```

The committed transcript must redact the RPC endpoint and any signer or API
material. Retain the command as:

```sh
forge script script/RehearseDeployment.s.sol:RehearseDeployment --sig "runSepolia()" --rpc-url <redacted> --sender <deployer> <approved Foundry signer flags redacted> --broadcast --verify --via-ir
```

Retain and sanitize the Foundry broadcast:

1. Copy `broadcast/RehearseDeployment.s.sol/11155111/run-latest.json` to
   `deployments/broadcasts/sepolia-6529stream-v0.1.0-001-run-latest.json`.
2. Remove or redact any private RPC endpoint, signer material, API token,
   local filesystem secret path, or unreleased drop payload.
3. Keep public transaction hashes, deployed addresses, chain ID, receipt status,
   block references, and constructor args.
4. Copy the template to an operator-reviewed non-template config path such as
   `deployments/config/sepolia-6529stream-v0.1.0-001-reviewed.json`.
5. In that copied config, replace placeholder constructor/admin/dependency
   values, set `manifest.lifecycle_state` to `Rehearsed`, set
   `manifest.git.commit` to the deployed commit, set
   `manifest.verification.contract_verification` and per-contract
   `verification_status` to `not_started`, `submitted`, or `verified`, set
   `manifest.verification.constructor_args_retained` to `true` once the
   constructor arguments are retained, and set
   `manifest.rehearsal.testnet_passed` to `true` only after the broadcast and
   retained transcript are complete.
6. Run the broadcast-derived manifest input generator with the copied
   non-template config:

```sh
python scripts/generate_broadcast_manifest_input.py \
  --template deployments/config/sepolia-6529stream-v0.1.0-001-reviewed.json \
  --broadcast deployments/broadcasts/sepolia-6529stream-v0.1.0-001-run-latest.json \
  --output deployments/config/sepolia-6529stream-v0.1.0-001-broadcast.json \
  --manifest-output deployments/examples/sepolia-6529stream-v0.1.0-001-broadcast.json
python scripts/generate_deployment_manifest.py \
  --config deployments/config/sepolia-6529stream-v0.1.0-001-broadcast.json
python scripts/generate_address_books.py \
  --manifest deployments/examples/sepolia-6529stream-v0.1.0-001-broadcast.json
python scripts/generate_source_verification_inputs.py --check
```

Then replace the template fields in
`release-artifacts/evidence/testnet-deployment-rehearsal/testnet-deployment-rehearsal-retained-artifact-template.md`
or a copied reviewed artifact with:

- Sepolia chain ID `11155111`, block reference, and deployment transaction
  references.
- Redacted command transcript path.
- Sanitized Foundry broadcast path.
- Generated deployment manifest path and SHA-256 digest.
- Generated address book path and SHA-256 digest.
- Explorer verification status and links.
- Gas or invariant summary.
- Reviewer, review decision, and no-secret redaction confirmations.

Validate and regenerate release evidence:

```sh
python scripts/test_testnet_deployment_rehearsal_evidence.py
python scripts/check_testnet_deployment_rehearsal_evidence.py
python scripts/generate_non_local_release_evidence.py \
  --template release-artifacts/evidence/public-beta-templates/testnet-deployment-rehearsal-template.json \
  --retained-artifact release-artifacts/evidence/testnet-deployment-rehearsal/testnet-deployment-rehearsal-retained-artifact-template.md \
  --output release-artifacts/evidence/testnet-deployment-rehearsal/testnet-deployment-rehearsal-evidence.json \
  --environment testnet \
  --chain-id 11155111 \
  --block-or-reference "<sepolia block or deployment transaction reference>" \
  --command-or-source-system "<redacted Sepolia deployment transcript>" \
  --owner "<evidence owner>" \
  --reviewer "<reviewer>" \
  --review-status pending_review \
  --source-git-commit "<40 hex commit>" \
  --source-ci-run "<CI run URL or operator transcript>"
python scripts/check_non_local_release_evidence.py
python scripts/check_public_beta_evidence.py
python scripts/generate_release_evidence_packet_index.py --check
python scripts/generate_release_manifest.py
python scripts/generate_release_checksums.py
python scripts/generate_release_manifest.py --check
python scripts/generate_release_checksums.py --check
```

Only after reviewer acceptance should the public-beta evidence row move from
`missing` to `complete`. Until then, commit only the template/runbook/checker
updates and keep public-beta readiness blocked.

## Manifest Requirements

Deployment manifests live under `deployments/` and must include:

- manifest schema version
- protocol version
- deployment version and lifecycle state
- network name, chain ID, RPC environment variable, and confirmation depth
- repository and 40-character commit hash
- Foundry, Solidity, optimizer, and `via-ir` settings
- deployed contract addresses, constructor args, ABI hashes, and bytecode hashes
- deployer, Safe/multisig, emergency recipient, pause guardians, unpause admins,
  signer managers, and drop signers
- external dependency addresses
- verification status and commands
- manifest checksum, ABI checksum map, and event topic catalog reference
- rehearsal command and Anvil/fork pass status

The current schema is
`deployments/schema/deployment-manifest.schema.json`; the non-production local
example is generated from
`deployments/config/anvil-6529stream-v0.1.0-001.json` into
`deployments/examples/anvil-6529stream-v0.1.0-001.json`.

The local rehearsal script also returns a Solidity `manifestHash` for the
deployed stack. Its preimage binds each deployed contract address and code hash;
for `StreamCollectionMetadata` and `StreamPreservationRecords`, it additionally
binds `streamCore()`, `adminsContract()`, and `streamModuleSupersedes()` so a
satellite dependency-pointer change alters the rehearsal manifest hash.

The first broadcast-ingestion baseline is generated from the sanitized Foundry
fixture at `deployments/broadcasts/anvil-6529stream-v0.1.0-001-run-latest.json`.
`scripts/generate_broadcast_manifest_input.py` validates the fixture chain ID,
expected contract names, deployed addresses, transaction hashes, receipt
success, duplicate deployments, missing deployments, unexpected deployments,
and secret-like keys, then writes
`deployments/config/anvil-6529stream-v0.1.0-001-broadcast.json`. That generated
config produces `deployments/examples/anvil-6529stream-v0.1.0-001-broadcast.json`.
This is deterministic public test evidence only; a live fork/testnet or
production broadcast must still be run and retained during the deployment
ceremony.

Compact address books live under `deployments/address-books/` and are generated
from committed deployment manifests. They are meant for integrators and scripts
that need network, release, manifest checksum, contract address, source path,
ABI hash, runtime bytecode hash, and verification-status data without parsing
constructor arguments or admin ceremony details. They follow
`deployments/schema/address-book.schema.json`, normalize addresses to
lowercase, and should be regenerated from manifests rather than edited by hand.

ABI checksum, bytecode checksum, interface ID, event topic catalog, and
protocol surface report inputs are generated from the canonical target-isolated
`via-ir` Foundry artifacts. The aggregate command shown first is diagnostic
only:

```sh
forge build --sizes --via-ir --skip test --skip script --force
python scripts/test_release_build_artifacts.py
python scripts/build_release_artifacts.py
python scripts/build_release_artifacts.py --check
python scripts/check_contract_size_budget.py
python scripts/generate_release_artifacts.py
python scripts/generate_release_artifacts.py --check
python scripts/generate_protocol_surface_report.py
python scripts/generate_protocol_surface_report.py --check
python scripts/generate_source_verification_inputs.py
python scripts/generate_source_verification_inputs.py --check
python scripts/generate_broadcast_manifest_input.py
python scripts/generate_broadcast_manifest_input.py --check
python scripts/generate_deployment_manifest.py
python scripts/generate_deployment_manifest.py --check
python scripts/generate_deployment_manifest.py --config deployments/config/anvil-6529stream-v0.1.0-001-broadcast.json
python scripts/generate_deployment_manifest.py --config deployments/config/anvil-6529stream-v0.1.0-001-broadcast.json --check
python scripts/generate_address_books.py
python scripts/generate_address_books.py --check
python scripts/test_ceremony_evidence.py
python scripts/check_ceremony_evidence.py
python scripts/test_admin_ceremony_evidence.py
python scripts/check_admin_ceremony_evidence.py
python scripts/test_randomizer_operations.py
python scripts/check_randomizer_operations.py
python scripts/generate_release_manifest.py
python scripts/generate_release_manifest.py --check
python scripts/generate_release_checksums.py
python scripts/generate_release_checksums.py --check
```

These generated artifacts do not prove that Forge broadcasts consume the same
canonical isolated initcode; that production deployment binding remains
blocked by
[issue #677](https://github.com/6529-Collections/6529Stream/issues/677).

The committed baseline is under `release-artifacts/latest/`. `StreamCore`
currently links `StreamMetadataRenderer`, so its bytecode hash entries are
explicitly marked as `unlinked_artifact_object` until a broadcast or linked
verification artifact supplies the final deployed bytecode. Runtime size budget
checks still count those placeholders as 20-byte library addresses, matching the
deployed linked bytecode shape for EIP-170 budgeting.

Deployment manifest generation reads the committed manifest input, fills ABI and
runtime bytecode hashes from `release-artifacts/latest/abi-checksums.json`, and
writes `release_artifacts.manifest_sha256` as the SHA-256 of the canonical JSON
manifest after normalizing that checksum field to `sha256:` plus 64 zeroes.
This makes the checksum deterministic without making the manifest depend on its
own final checksum value.

Address book generation validates the deployment manifest contract set against
the release artifact baseline, rejects invalid or duplicate deployed contract
addresses, and fails check mode when the committed address-book JSON drifts.
The default address-book set includes both the placeholder Anvil manifest and
the sanitized broadcast-derived manifest, plus the pending-review
fork-mainnet broadcast-derived manifest retained for issue #216.

Source verification input generation writes
`release-artifacts/latest/source-verification-inputs.json` from the production
Foundry artifacts, Solidity source files, compiler settings, ABI/bytecode
checksums, constructor ABI, and link references. It retains verification
command templates for each production contract without claiming live explorer
verification before a broadcast deployment supplies real addresses, linked
library addresses, and encoded constructor args.

Protocol surface report generation writes
`release-artifacts/latest/protocol-surface-report.json` from the production
contract set and Foundry artifacts. It records functions, selectors, events,
topic0 values, custom errors, ABI hashes, bytecode hashes, and runtime sizes
for integrators and reviewers without claiming protocol correctness or live
deployment parity.

Bytecode-to-release proof generation writes
`release-artifacts/latest/bytecode-release-proof.json` after the release
manifest. It ties each committed local/fork deployment address to its
deployment manifest, address book, ABI hash, runtime bytecode hash, creation
bytecode hash, compiler settings, source verification record, chain ID, and the
current release manifest hash. It is a deterministic no-secret proof over
committed artifacts only; live production bytecode proof still requires
reviewed RPC or explorer evidence before any public release claim.

Release manifest generation writes
`release-artifacts/latest/release-manifest.json` as the top-level machine-readable
index over the release artifact catalog, ABI compatibility baseline, deployment
manifests, address books, schemas, changelog, governance docs, and unavailable
release-ceremony outputs. It gives deployment reviewers one deterministic file
that ties the generated release evidence together.

Release checksum generation writes `release-artifacts/latest/SHA256SUMS` and
`release-artifacts/latest/release-checksums.json` over the committed release
artifact, deployment manifest, address-book, config, schema, and release
manifest files. These checksums are the deterministic source for future
detached signatures; this repo does not commit maintainer private-key material
or produce signatures in the local gate. Because the checksum bundle covers the
release manifest, the release manifest lists checksum-bundle outputs without
embedding their final digests.

## Ceremony Evidence

Deployment ceremony evidence bundles live under
`deployments/ceremony-evidence/` and follow
`deployments/schema/ceremony-evidence.schema.json`. They are no-secret public
release artifacts that bind a deployment version to:

- network environment, chain ID, confirmation depth, source commit, and CI run;
- deployer, Safe/multisig, signer, and emergency-recipient addresses;
- deployment manifest, address book, ABI checksum, and release checksum bundle
  references;
- admin ceremony, signer setup, metadata browser, auction ceremony, and
  emergency redeployment results;
- source/explorer verification status and retained artifact references;
- redaction policy proving private keys, mnemonics, RPC URLs, API keys, and
  unreleased drop payloads are not committed.

Validate the committed local evidence with:

```sh
python scripts/test_ceremony_evidence.py
python scripts/check_ceremony_evidence.py
```

`deployments/ceremony-evidence/anvil-6529stream-v0.1.0-001-local.json` is local
Anvil evidence only. Fork, testnet, and production ceremonies must produce
their own evidence bundles from real broadcast manifests, retained transaction
logs, source/explorer verification submissions, admin/signer/dependency
operator notes, and incident or deprecation records where relevant.

The reviewed fork-mainnet rehearsal retained for issue #216 is a
broadcast/manifest/address-book evidence slice, not a complete ceremony bundle.
Its sanitized broadcast records the linked `StreamMetadataRenderer` deployment
under `broadcast_evidence.ignored_deployments` because the library is a helper
deployment used to link `StreamCore`, while the release contract set remains the
core/drops/auction/curator/randomizer/delegation surface.

## Admin Ceremony Evidence

Admin ceremony evidence lives under `deployments/admin-ceremony/` and follows
`deployments/schema/admin-ceremony-evidence.schema.json`. It is a no-secret
public evidence shape for proving post-deployment control of the deployed
system, including deployer ownership transfer, Safe or multisig ownership,
temporary admin revocation, role grants, signer setup, pause/emergency setup,
post-state reads, source/explorer verification status, approval, and retained
artifact hashes.

The committed
`deployments/admin-ceremony/admin-ceremony-evidence-template.json` is template
evidence only. Reviewed fork, testnet, mainnet, or production evidence must
replace template placeholders with retained transaction references, reviewed
addresses, completed or intentionally blocked statuses, and non-placeholder
rationale where work remains incomplete. It must not include private keys,
mnemonics, API keys, private RPC URLs, Safe signing secrets, raw signatures, or
unreleased drop payloads.

Validate admin ceremony evidence with:

```sh
python scripts/test_admin_ceremony_evidence.py
python scripts/check_admin_ceremony_evidence.py
```

The release manifest catalogs checked admin ceremony evidence as a deployment
artifact, and the release checksum bundle covers the retained template and any
future no-secret evidence files under `deployments/admin-ceremony/`.

## Randomizer Operations Evidence

Randomizer operations evidence bundles live under
`deployments/randomizer-operations/` and follow
`deployments/schema/randomizer-operations-evidence.schema.json`. They are
no-secret public release artifacts that bind a deployment version to:

- deployed VRF and arRNG adapter addresses;
- VRF coordinator and arRNG controller addresses;
- provider epoch and provider funding status;
- arRNG refund-recipient and reserve policy;
- request tracking, callback validation, migration, stale request, failed
  request, retry, reserve-accounting, pause, and emergency-withdrawal controls;
- retained artifact references and redaction policy.

Validate the committed local evidence with:

```sh
python scripts/test_randomizer_operations.py
python scripts/check_randomizer_operations.py
```

`deployments/randomizer-operations/anvil-6529stream-v0.1.0-001-local.json` is
local Anvil evidence only. Fork, testnet, and production releases must produce
their own randomizer operations evidence from real provider configuration,
funding/billing records, request-health checks, retained transaction evidence,
and operator notes. See `docs/randomizer-operations.md`.

## Admin Ceremony Checklist

Before a deployment can become public-beta eligible:

- Confirm the deployer address.
- Confirm the Safe/multisig address.
- Configure global admin and function-admin policy.
- Confirm that `StreamCollectionMetadata` writer grants for
  `setCollectionRecord`, `setCollectionRecordWithRevision`, and
  `publishCollectionSnapshot`, plus `StreamPreservationRecords`
  `recordCollectionRecord`, are intentionally whole-module grants for trusted
  metadata or preservation operators in protocol v1. Treat those grants as
  custody-sensitive: a compromised writer can publish any accepted metadata,
  preservation, C2PA/PREMIS, rights, or snapshot record in the target module.
- Configure pause guardians and unpause admins.
- Configure emergency recipient.
- Configure signer manager and drop signer.
- Wire minter, drops, auctions, randomizers, dependency registry, payout, and
  curator pool.
- Confirm production dependency source packages, pins, and deprecation plans
  follow `docs/dependency-operations.md`.
- Transfer Ownable control where applicable.
- Revoke temporary deployment admin grants.
- Run a dry-run fixed-price mint.
- Run a dry-run auction drop, bid, settlement, and withdrawal.
- Run the local emergency redeployment rehearsal.
- Retain constructor args and verification inputs.
- Generate and check source verification inputs.
- Generate and check dependency artifact manifests.
- Generate and check broadcast-derived manifest input from sanitized Foundry
  output.
- Generate and checksum the deployment manifest.
- Generate and check the address book.
- Generate and check the ceremony evidence bundle.
- Generate and check the randomizer operations evidence bundle.
- Generate and check the release manifest.
- Generate and check the bytecode-to-release proof.
- Generate and check the release checksum bundle.

Live fork/testnet broadcast, production broadcast retention, contract
verification, event topic catalog publication against a live deployment,
fork/testnet/live ceremony evidence contents, and fork/testnet/live emergency
redeployment evidence contents, and fork/testnet/live randomizer operations
evidence contents remain Gate E follow-up work.
