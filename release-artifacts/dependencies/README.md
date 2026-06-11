# Dependency Artifacts

This directory stores release-packaged source artifacts for dependency registry
versions. Descriptors are generated into
`release-artifacts/latest/dependency-artifact-manifest.json` so auditors,
operators, and indexers can verify dependency source files without relying on
on-chain provenance strings alone.

Each descriptor uses a `.dependency.json` suffix and must:

- use schema `6529stream.dependency-artifact.v1`
- identify the protocol and deployment version that registered the dependency
- record the dependency registry key, version, registry contract label, and
  provenance string
- reference only repo-relative files under `release-artifacts/dependencies/`
- keep source files free of production secrets or live RPC details

Run `python scripts/generate_dependency_artifact_manifest.py --check` or
`make dependency-artifacts-check` to verify the generated manifest is current.
