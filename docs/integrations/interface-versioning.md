# Interface And Version Compatibility

Baseline record — not a specification. This document describes as-built
or operational state; the normative target is the specification set
indexed in [`docs/spec-policy.md`](../spec-policy.md), and where this
document conflicts with a specification home, the specification wins.

This document describes the `CON-007` compatibility surface for frontend,
mobile, Electron, indexer, and operator UI consumers. It is a pre-audit local
baseline, not production-ready, and not a security claim. Local compatibility
checks do not replace fork/testnet/live evidence, explorer verification, audit
evidence, or release signatures.

## Source Of Truth

Use this guide with:

- [docs/integrations/README.md](README.md)
- [docs/integrations/frontend-reference-architecture.md](frontend-reference-architecture.md)
- [docs/integrations/events-and-indexing.md](events-and-indexing.md)
- [docs/metadata.md](../metadata.md)
- [docs/release-policy.md](../release-policy.md)
- [release-artifacts/latest/release-manifest.json](../../release-artifacts/latest/release-manifest.json)
- [release-artifacts/latest/interface-ids.json](../../release-artifacts/latest/interface-ids.json)
- [release-artifacts/latest/abi-checksums.json](../../release-artifacts/latest/abi-checksums.json)
- [release-artifacts/latest/bytecode-release-proof.json](../../release-artifacts/latest/bytecode-release-proof.json)
- [deployments/address-books/anvil-6529stream-v0.1.0-001.json](../../deployments/address-books/anvil-6529stream-v0.1.0-001.json)
- [smart-contracts/IStreamCompatibility.sol](../../smart-contracts/IStreamCompatibility.sol)
- [smart-contracts/StreamContractMetadata.sol](../../smart-contracts/StreamContractMetadata.sol)
- [test/StreamContractMetadata.t.sol](../../test/StreamContractMetadata.t.sol)

## Compatibility Adapter

`StreamContractMetadata` is the release-tracked compatibility entrypoint. The
adapter already exists outside `StreamCore`, so `CON-007` adds compatibility
views without spending `StreamCore` EIP-170 headroom.

The adapter supports `IStreamCompatibility` through ERC-165 and exposes:

| View | Integration use |
| --- | --- |
| `isStreamCompatibility()` | Marker that the address is the 6529Stream compatibility adapter |
| `streamProtocolName()` | Stable protocol family name, currently `6529Stream` |
| `streamProtocolVersion()` | Protocol version for release artifacts, currently `0.1.0` |
| `streamMetadataSchemaVersion()` | Token JSON metadata schema, currently `6529stream-v1` |
| `streamReleaseTag()` | Release artifact tag expected for ABI/event decoding, currently `v0.1.0` |
| `streamReleaseHash()` | `keccak256(bytes(streamReleaseTag()))` for compact comparisons |
| `supportsStreamInterface(bytes4)` | True when the adapter or linked `StreamCore` supports the interface |

`supportsStreamInterface(bytes4)` checks the adapter first, then asks
`StreamCore.supportsInterface(bytes4)`. Frontends can use one address from the
address book to verify adapter capabilities and core NFT capabilities such as
ERC-721, ERC-2981, and ERC-4906. Unsupported interface IDs, including
`0xffffffff`, must fail closed.

## Frontend Fail-Closed Flow

At app startup for a selected deployment:

1. Load the address book and release manifest for the selected chain ID.
2. Read the `StreamContractMetadata` address from the address book.
3. Call `supportsInterface(type(IStreamCompatibility).interfaceId)` on the
   adapter.
4. Call `isStreamCompatibility()` and require `true`.
5. Read `streamProtocolName()`, `streamProtocolVersion()`,
   `streamMetadataSchemaVersion()`, `streamReleaseTag()`, and
   `streamReleaseHash()`.
6. Compare those values to the artifact bundle used by the app build.
7. Probe required interface IDs through `supportsStreamInterface(bytes4)`.
8. Disable writes and show an unsupported-deployment state if any required
   check fails.

The browser bundle may contain public ABIs, interface IDs, release tags, and
addresses. It must not contain private keys, signer-service credentials, Safe
secrets, admin secrets, privileged RPC credentials, or unreleased signed drop
payloads.

## Required Interface Probes

Suggested minimum probes for the current release baseline:

| Interface | ID | Required for |
| --- | --- | --- |
| ERC-165 | `0x01ffc9a7` | Interface discovery |
| ERC-721 | `0x80ac58cd` | Core NFT ownership and transfers |
| ERC-721 Metadata | `0x5b5e139f` | `name`, `symbol`, `tokenURI` |
| ERC-2981 | `0x2a55205a` | Royalty disclosure |
| ERC-4906 | `0x49064906` | Metadata update events |
| ERC-7572-style contract metadata | generated in `interface-ids.json` | `contractURI()` |
| IStreamCompatibility | generated in `interface-ids.json` | Version and capability probe |

Do not infer production support from a local adapter call alone. Public beta and
production support still require reviewed deployment manifests, explorer
verification, retained evidence, release checksums, and release readiness
status.

## Validation Commands

```sh
forge test --match-path test/StreamContractMetadata.t.sol -vvv
python scripts/generate_release_artifacts.py --check
python scripts/generate_protocol_surface_report.py --check
python scripts/check_natspec_coverage.py
python scripts/generate_release_manifest.py --check
python scripts/generate_release_checksums.py --check
```
