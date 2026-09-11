# Verified Sepolia deployment

These records describe the actual 45 successful deployment transactions on Sepolia through block **11,678,063**, hash `0x08f49b98d8834c26e0ce4ad8a0b1f8c6c2a46c9a6b24dc7e5b77705c97c5d0dc`. Independent verification used public read-only RPC methods; no transaction was signed or sent by the verifier.

- `addresses.json`: named modules and all 40 runtime-verified addresses.
- `compiler-binding.json`: all 177 exact source hashes, compiler settings, and the identity of the 86-target export. The source is retained by the non-release Git tag `evidence/sepolia-deployment-2026-09-10`.
- `receipts.json`: all 45 transaction identities, reserved nonces, public calldata commitments, values, gas, successful receipts, and canonical block membership.
- `runtime-verification.json`: linked bytecode matches, exact compiler immutable spans and their observed values, and explicit internal-creation/runtime-only limitations.
- `configuration.json`: 81 named reads at the deployment-completion block, including dependencies, owner authorities, phase executors, current publisher pointer, and VRF configuration.
- `core-authority-binding.json`: separate semantic proof for Core's private immutable Executor authority and named constructor bindings.
- `summary.json`: counts, provenance and file hashes.

The historical block deliberately precedes activation: collection 1 has zero mints and artist acceptance is pending there. Consumer registration, subscription funding, actual paid mint, oracle fulfillment, final metadata, withdrawals, and transfer belong in the sibling demonstration evidence. This package does not assert audit completion, production readiness, or full storage coverage. Not every constructor or immutable value is semantically validated; the bytecode report identifies those limits.

The files contain public contract/state observations only. They omit accounts configuration, signer material, RPC credentials, and operational checkpoints. File hashes establish consistency, not trust in the author; verify the source tag and chain observations independently.
