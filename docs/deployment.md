# Deployment

6529Stream uses immutable, versioned redeployments for the current public-beta
plan. Deployment manifests are mandatory release artifacts and follow ADR 0007.

## Local Rehearsal

Run the local deployment rehearsal with:

```sh
forge script script/RehearseDeployment.s.sol:RehearseDeployment --sig "run()" --via-ir
forge script script/RehearseAuctionCeremony.s.sol:RehearseAuctionCeremony --sig "run()" --via-ir
forge script script/RehearseEmergencyRedeployment.s.sol:RehearseEmergencyRedeployment --sig "run()" --via-ir
```

The script deploys and wires a local stack:

- `StreamAdmins`
- `DependencyRegistry`
- `StreamCore`
- `StreamCuratorsPool`
- `StreamMinter`
- `StreamDrops`
- `StreamAuctions`
- `NextGenRandomizerVRF`
- `NextGenRandomizerRNG`

It also creates a sample collection, pins a sample dependency version, assigns
the VRF randomizer, sets mint phases, registers the Safe placeholder as global
admin, configures pause/signer emergency roles, revokes the temporary deployment
admin, and transfers Ownable control for `StreamAdmins` and `StreamCore` to the
configured Safe placeholder.

The rehearsal is not a production broadcast. It uses non-secret placeholder
addresses and local-only external dependency addresses.

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

`script/RehearseMetadataBrowser.s.sol` builds on the deployment rehearsal by
deploying the local stack, registering a deterministic metadata dependency,
minting through the EIP-712 drop authorization path, finalizing token
randomness/image/attribute inputs, and returning the generated on-chain
`tokenURI`. The Python checker executes the generated final animation in the
same Playwright/Chromium sandbox policy used for committed metadata fixtures.
This is a local Anvil release gate and does not require RPC secrets; fork,
testnet, and production broadcasts should still retain their own manifest and
browser evidence during the release ceremony.

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

ABI checksum, bytecode checksum, interface ID, and event topic catalog inputs
are generated from the production `via-ir` Foundry artifacts:

```sh
forge build --sizes --via-ir --skip test --skip script --force
python scripts/generate_release_artifacts.py
python scripts/generate_release_artifacts.py --check
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
python scripts/generate_release_manifest.py
python scripts/generate_release_manifest.py --check
python scripts/generate_release_checksums.py
python scripts/generate_release_checksums.py --check
```

The committed baseline is under `release-artifacts/latest/`. `StreamCore`
currently links `StreamMetadataRenderer`, so its bytecode hash entries are
explicitly marked as `unlinked_artifact_object` until a broadcast or linked
verification artifact supplies the final deployed bytecode.

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
the sanitized broadcast-derived manifest.

Source verification input generation writes
`release-artifacts/latest/source-verification-inputs.json` from the production
Foundry artifacts, Solidity source files, compiler settings, ABI/bytecode
checksums, constructor ABI, and link references. It retains verification
command templates for each production contract without claiming live explorer
verification before a broadcast deployment supplies real addresses, linked
library addresses, and encoded constructor args.

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

## Admin Ceremony Checklist

Before a deployment can become public-beta eligible:

- Confirm the deployer address.
- Confirm the Safe/multisig address.
- Configure global admin and function-admin policy.
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
- Generate and check the release manifest.
- Generate and check the release checksum bundle.

Live fork/testnet broadcast, production broadcast retention, contract
verification, event topic catalog publication against a live deployment,
fork/testnet/live ceremony evidence, and fork/testnet/live emergency
redeployment evidence remain Gate E follow-up work.
