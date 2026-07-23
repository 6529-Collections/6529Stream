# Deployment Artifacts

Deployment manifests are canonical release artifacts for public 6529Stream
deployments. A manifest binds contract addresses, constructor inputs, toolchain
versions, ABI hashes, verification inputs, admin ceremony decisions, and
external dependencies to a specific git commit and chain.

The current baseline includes:

- `schema/deployment-manifest.schema.json`: the required manifest shape.
- `schema/address-book.schema.json`: the compact address-book shape.
- `schema/ceremony-evidence.schema.json`: the retained deployment ceremony
  evidence shape.
- `schema/randomizer-operations-evidence.schema.json`: the retained
  randomizer operations evidence shape.
- `broadcasts/anvil-6529stream-v0.1.0-001-run-latest.json`: a sanitized
  Foundry broadcast fixture used to prove broadcast-derived manifest ingestion
  without committing RPC credentials or private material.
- `config/anvil-6529stream-v0.1.0-001.json`: the source input for the
  generated local example.
- `config/anvil-6529stream-v0.1.0-001-broadcast.json`: the generated source
  input derived from the sanitized Foundry broadcast fixture.
- `config/sepolia-6529stream-v0.1.0-001.template.json`: a no-secret Sepolia
  rehearsal template. It is not completion evidence and must be copied to a
  non-template config only after a real reviewed Sepolia broadcast replaces
  placeholders with public addresses, transaction references, and redacted
  command evidence.
- `examples/anvil-6529stream-v0.1.0-001.json`: a non-production local example.
- `examples/anvil-6529stream-v0.1.0-001-broadcast.json`: the generated
  deployment manifest for the sanitized broadcast fixture.
- `address-books/anvil-6529stream-v0.1.0-001.json`: a compact address-book
  projection of the local example for scripts, docs, wallets, and indexers.
- `address-books/anvil-6529stream-v0.1.0-001-broadcast.json`: the compact
  address-book projection of the broadcast-derived manifest.
- `ceremony-evidence/anvil-6529stream-v0.1.0-001-local.json`: a no-secret local
  Anvil evidence bundle tying the deployment manifest, address book, ABI
  checksums, admin ceremony, signer setup, metadata-browser check, auction
  ceremony, emergency redeployment rehearsal, verification status, retained
  artifacts, and redaction policy together.
- `randomizer-operations/anvil-6529stream-v0.1.0-001-local.json`: a no-secret
  local Anvil randomizer operations bundle tying provider configuration,
  provider funding status, lifecycle controls, reserve policy, retained
  artifacts, and redaction policy together.

Do not commit private keys, RPC credentials, unreleased drop payloads, or signer
material in this directory. Public deployment manifests, ABI hashes, checksums,
and verification references are intentionally public release artifacts.

The local ABI checksum, bytecode checksum, interface ID, and event topic catalog
baseline is generated under `release-artifacts/latest/` from the canonical
target-isolated build with:

```sh
python scripts/test_release_build_artifacts.py
python scripts/build_release_artifacts.py
python scripts/build_release_artifacts.py --check
python scripts/generate_release_artifacts.py
python scripts/generate_broadcast_manifest_input.py
python scripts/generate_deployment_manifest.py
python scripts/generate_deployment_manifest.py --config deployments/config/anvil-6529stream-v0.1.0-001-broadcast.json
python scripts/generate_address_books.py
python scripts/test_ceremony_evidence.py
python scripts/check_ceremony_evidence.py
python scripts/test_randomizer_operations.py
python scripts/check_randomizer_operations.py
python scripts/generate_release_checksums.py
```

The aggregate `forge build --sizes --via-ir --skip test --skip script --force`
command is diagnostic only and must not supply deployment-manifest bytecode or
compiler inputs.

Deployment manifests should reference those outputs, then replace any unlinked
placeholder-bytecode hashes with broadcast or verification hashes once a live
deployment exists.

`RehearseDeployment.s.sol` also emits a Solidity `manifestHash` for rehearsal
tests. That hash binds the deployed contract addresses and code hashes, plus
the `streamCore()`, `adminsContract()`, and `streamModuleSupersedes()` values
for the collection metadata and preservation satellites, so dependency-pointer
drift changes the rehearsal identity hash.

Broadcast-derived manifest input generation reads a sanitized Foundry
`run-latest.json`, validates the expected contract set, chain ID, transaction
hashes, receipt success, deployed addresses, duplicates, and missing or
unexpected deployments, then writes a deterministic manifest input under
`deployments/config/`. The committed fixture is public test evidence only. Live
fork/testnet and production broadcasts must still be generated during the
deployment ceremony and must not include secrets.

For Sepolia rehearsals, start from
`config/sepolia-6529stream-v0.1.0-001.template.json` and
`docs/deployment.md#sepolia-deployment-rehearsal-runbook`. The template may
name environment variables such as `SEPOLIA_RPC_URL`, but retained command
transcripts and broadcast artifacts must redact endpoint values, signer
material, API tokens, and unreleased drop payloads before commit.

`release_artifacts.manifest_sha256` is generated by hashing the canonical JSON
manifest with that field normalized to `sha256:` followed by 64 zeroes. This
avoids a self-referential checksum loop while still making any manifest drift
machine-detectable.

Address books are generated from committed deployment manifests and
`release-artifacts/latest/abi-checksums.json`. They intentionally omit
constructor arguments, admin ceremony details, and verification commands while
retaining network/release metadata, the source manifest checksum, contract
addresses, source paths, ABI hashes, runtime bytecode hashes, and verification
status. Address-book JSON files are generated outputs; update the source
manifest or release artifacts, then rerun `python scripts/generate_address_books.py`
instead of editing address books by hand.

Ceremony evidence bundles are retained under `deployments/ceremony-evidence/`
and validated by `scripts/check_ceremony_evidence.py`. The committed local
bundle is Anvil-only evidence. Fork, testnet, and production bundles must retain
real broadcast manifests, address books, checksum references, source/explorer
verification status, admin/signer/dependency/auction/emergency ceremony
results, and operator notes without private keys, RPC URLs, API keys, mnemonics,
or unreleased drop payloads.

Randomizer operations evidence bundles are retained under
`deployments/randomizer-operations/` and validated by
`scripts/check_randomizer_operations.py`. The committed local bundle is
Anvil-only evidence. Fork, testnet, and production bundles must retain real VRF
and arRNG provider configuration, funding or billing proof, provider health,
pending/stale/failed request state, migration controls, emergency controls, and
operator notes without private keys, RPC URLs, API keys, mnemonics, provider
account credentials, or unreleased drop payloads.

After broadcast, manifest, schema, config, address-book, ceremony evidence, or
randomizer operations evidence outputs change, regenerate
`release-artifacts/latest/SHA256SUMS` and
`release-artifacts/latest/release-checksums.json` with
`python scripts/generate_release_checksums.py`.
