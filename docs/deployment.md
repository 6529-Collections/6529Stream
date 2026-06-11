# Deployment

6529Stream uses immutable, versioned redeployments for the current public-beta
plan. Deployment manifests are mandatory release artifacts and follow ADR 0007.

## Local Rehearsal

Run the local deployment rehearsal with:

```sh
forge script script/RehearseDeployment.s.sol:RehearseDeployment --sig "run()" --via-ir
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
python scripts/generate_deployment_manifest.py
python scripts/generate_deployment_manifest.py --check
python scripts/generate_address_books.py
python scripts/generate_address_books.py --check
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
- Transfer Ownable control where applicable.
- Revoke temporary deployment admin grants.
- Run a dry-run fixed-price mint.
- Run a dry-run auction drop, bid, settlement, and withdrawal.
- Retain constructor args and verification inputs.
- Generate and checksum the deployment manifest.
- Generate and check the address book.

Fork/testnet broadcast, contract verification, event topic catalog publication
against a live deployment, and end-to-end dry-run mint/auction ceremonies remain
Gate E follow-up work.
