# Deployment Artifacts

Deployment manifests are canonical release artifacts for public 6529Stream
deployments. A manifest binds contract addresses, constructor inputs, toolchain
versions, ABI hashes, verification inputs, admin ceremony decisions, and
external dependencies to a specific git commit and chain.

The current baseline includes:

- `schema/deployment-manifest.schema.json`: the required manifest shape.
- `examples/anvil-6529stream-v0.1.0-001.json`: a non-production local example.

Do not commit private keys, RPC credentials, unreleased drop payloads, or signer
material in this directory. Public deployment manifests, ABI hashes, checksums,
and verification references are intentionally public release artifacts.
