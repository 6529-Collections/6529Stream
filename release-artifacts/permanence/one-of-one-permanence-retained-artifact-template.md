# 1/1 Permanence Package Retained Artifact Template

This template describes the human-reviewed evidence that should accompany a
collector-verifiable permanence package. It is a no-secret local template and
not completion evidence.

## Package Identity

- Package ID: `TBD`
- Protocol version: `TBD`
- Deployment version: `TBD`
- Chain ID: `TBD`
- Core contract: `TBD`
- Collection ID: `TBD`
- Token ID: `TBD`
- Collection freeze manifest hash: `TBD`
- Contract URI hash: `TBD`

## Required Retained Inputs

- Renderer source archive and hash.
- Dependency artifact manifest and dependency source hashes.
- 1/1 provenance manifest binding, if collector-facing provenance is claimed.
- Metadata JSON output and hash.
- Animation HTML output and hash, when present.
- Image or rendered output hash, when present.
- Browser proof artifact and hash.
- No-secret replay commands and runtime versions.
- Storage guarantee statement distinguishing fully on-chain inputs,
  decentralized storage, gateway assumptions, and external service
  dependencies.

## Review Checklist

- [ ] No private keys, mnemonics, signer credentials, RPC URLs, API keys,
      bearer tokens, cookies, raw signatures, unreleased payloads, or private
      collector data are present.
- [ ] Every retained artifact hash matches bytes on disk.
- [ ] Replay commands are deterministic and do not require secrets.
- [ ] Browser proof uses the documented sandbox policy and reports no
      unexpected network requests or console/page errors.
- [ ] Dependency records match the generated dependency artifact manifest.
- [ ] Provenance binding matches the generated 1/1 provenance manifest.
- [ ] Release manifest and checksum bindings are current.
- [ ] The package remains blocked or pending until final reviewed output and
      browser proof evidence is retained.

## Operator Notes

Record reviewer, approval reference, reviewed timestamp, and any explicit
accepted-risk decision in the machine-readable permanence package descriptor.
