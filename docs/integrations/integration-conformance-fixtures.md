# Integration Conformance Fixtures

Baseline record — not a specification. This document describes as-built
or operational state; the normative target is the specification set
indexed in [`docs/spec-policy.md`](../spec-policy.md), and where this
document conflicts with a specification home, the specification wins.

## Maturity And Scope

These INT-016 integration conformance fixtures are a pre-audit local baseline
for frontend, mobile, Electron, indexer, operator UI, and backend signing
service teams. They are not production-ready, not a security claim, not a
generated SDK, not an indexer service, and not retained marketplace/indexer
evidence. They help consumers prove that they can load committed artifacts,
build a fail-closed chain config, construct EIP-712 domain expectations, decode
known events, reject unknown logs, handle idempotency, and model reorg rollback
without leaking private keys, raw signatures, RPC secrets, WalletConnect
secrets, unreleased token data, or production signer material.

The canonical fixture bundle is
[`docs/integrations/fixtures/integration-conformance-fixtures.json`](fixtures/integration-conformance-fixtures.json).

## Source Of Truth

Use these fixtures as examples around the canonical repository artifacts, not
as a replacement for those artifacts:

- [`deployments/address-books/anvil-6529stream-v0.1.0-001.json`](../../deployments/address-books/anvil-6529stream-v0.1.0-001.json)
- [`deployments/examples/anvil-6529stream-v0.1.0-001.json`](../../deployments/examples/anvil-6529stream-v0.1.0-001.json)
- [`release-artifacts/latest/event-topic-catalog.json`](../../release-artifacts/latest/event-topic-catalog.json)
- [`release-artifacts/latest/abi-checksums.json`](../../release-artifacts/latest/abi-checksums.json)
- [`release-artifacts/latest/release-manifest.json`](../../release-artifacts/latest/release-manifest.json)
- [`release-artifacts/latest/release-checksums.json`](../../release-artifacts/latest/release-checksums.json)
- [`test/fixtures/drop-authorization/payload-generator/fixed-price-output.json`](../../test/fixtures/drop-authorization/payload-generator/fixed-price-output.json)
- [`test/fixtures/drop-authorization/payload-generator/auction-output.json`](../../test/fixtures/drop-authorization/payload-generator/auction-output.json)
- [`docs/integrations/examples/typescript-artifacts-and-chain-config.md`](examples/typescript-artifacts-and-chain-config.md)
- [`docs/integrations/examples/typescript-eip712-drop-authorization.md`](examples/typescript-eip712-drop-authorization.md)
- [`docs/integrations/examples/typescript-event-decoding-and-indexer-ingestion.md`](examples/typescript-event-decoding-and-indexer-ingestion.md)
- [`docs/integrations/frontend-reference-architecture.md`](frontend-reference-architecture.md)
- [`docs/integrations/events-and-indexing.md`](events-and-indexing.md)
- [`docs/integrations/README.md`](README.md)
- [`docs/release-readiness.md`](../release-readiness.md)
- [`docs/non-local-release-evidence.md`](../non-local-release-evidence.md)

## Fixture Bundle Contract

The fixture schema is `6529stream.integration-conformance-fixtures.v1`. The
bundle is intentionally schema-light JSON so React, React Native, Electron,
Node indexers, and operator tooling can consume it without a generated package.
It contains:

- `maturity`: explicit flags that the bundle is pre-audit, not production-ready,
  not a generated SDK, and not external evidence.
- `source_artifacts`: repository paths for the address book, deployment
  manifest, event topic catalog, ABI checksums, release manifest, release
  checksums, and local unsigned drop authorization payloads.
- `artifact_chain_config_case`: a local Anvil happy path with required contract
  addresses plus wrong-chain, wrong-deployment, and missing-contract negative
  cases.
- `drop_authorization_cases`: fixed-price and auction EIP-712 expectations,
  including runtime domain name, version, chain ID, verifying contract, payload
  template domain, sale mode, and negative cases for wrong domain, stale signer
  epoch, expired deadline, token-data substitution, auction custody mismatch,
  zero-address signer, and replayed drop ID.
- `event_decoding_cases`: event topic dispatch cases for `Transfer`,
  `DropAuthorizationConsumed`, and `AuctionRegistered`; each case binds
  `topic0`, event signature, emitter address, log identity fields, read-after-event
  calls, idempotent ingestion, unknown emitter, unknown topic, and reorg rollback.
- `indexer_behaviour_cases`: cross-cutting log identity, confirmation depth,
  unknown log, and no-secret redaction expectations.

## Artifact Loading Case

Consumers should use the Anvil case to verify chain config construction before
they render a mint or auction UI. A passing implementation loads the address
book, checks `chain_id` equals `31337`, checks the deployment version equals
`anvil-6529stream-v0.1.0-001`, verifies each required contract address, and
rejects missing contracts. It must fail closed on wrong chain ID, wrong
deployment version, and missing contract address.

This mirrors the TypeScript artifact loading and chain config snippets in
[`docs/integrations/examples/typescript-artifacts-and-chain-config.md`](examples/typescript-artifacts-and-chain-config.md).

## Drop Authorization Cases

The fixed-price and auction cases reference unsigned local payload generator
outputs. They do not contain signatures, private keys, mnemonics, production
payloads, raw signer credentials, or unreleased token data. Consumers should
use the cases to assert EIP-712 domain construction and message routing only.

The expected domain is:

```json
{
  "name": "6529StreamDrops",
  "version": "1",
  "chainId": 31337,
  "verifyingContract": "0x0000000000000000000000000000000000000006"
}
```

The unsigned payload generator fixtures retain their own local template
verifying contract, `0x100000000000000000000000000000000000dead`; the checker
asserts that payload template domain separately from the Anvil runtime domain
above.

EIP-712 is encoding/signing only. Integration code must still account for
replay protection through drop ID, signer epoch, deadline, chain ID, verifying
contract, consumed-state storage, and cancellation views. EOA, ERC-1271, and
Safe signing boundaries remain governed by
[`docs/integrations/examples/typescript-eip712-drop-authorization.md`](examples/typescript-eip712-drop-authorization.md)
and [`docs/integrations/wallets-and-signatures.md`](wallets-and-signatures.md).

## Event Dispatch Cases

Each event case proves that a consumer can join the address book and event topic
catalog into a dispatch key of `lowercaseEmitter:topic0`. A consumer should:

1. Reject a known `topic0` emitted by the wrong contract.
2. Reject an unknown `topic0`.
3. Treat duplicate confirmed log identity keys as idempotent.
4. Roll back optimistic or confirmed rows when a reorg replaces the block hash.
5. Enqueue the documented read-after-event call at the source block number.

The event cases intentionally cover a token event, a drop execution event, and
an auction event so React, mobile, Electron, indexer, and operator UI surfaces
can test common routing without needing a live RPC node.

## No-Secret Policy

The fixture bundle is safe to commit and safe to include in release artifacts.
Consumers must still redact secret-shaped diagnostics before logging. The
checker rejects secret-shaped keys or values such as `privateKey`, `mnemonic`,
`apiToken`, `bearer`, `password`, raw signature fields, and private key-shaped
hex strings. The fixture may mention `tokenDataHash`, `tokenId`, and unreleased
token-data policy text, but it must not include raw unreleased token data.

## Validation Commands

Run the focused fixture checks before relying on these examples:

```sh
python scripts/test_integration_conformance_fixtures.py
python scripts/check_integration_conformance_fixtures.py
python scripts/test_integrations_readme.py
python scripts/check_integrations_readme.py
python scripts/test_events_and_indexing.py
python scripts/check_events_and_indexing.py
python scripts/test_react_next_reference.py
python scripts/check_react_next_reference.py
python scripts/test_typescript_artifact_chain_config.py
python scripts/check_typescript_artifact_chain_config.py
python scripts/test_typescript_eip712_drop_authorization.py
python scripts/check_typescript_eip712_drop_authorization.py
python scripts/test_typescript_event_decoding_indexer.py
python scripts/check_typescript_event_decoding_indexer.py
python scripts/test_release_manifest.py
python scripts/generate_release_manifest.py --check
python scripts/test_release_checksums.py
python scripts/generate_release_checksums.py --check
python scripts/check_changelog.py
make integration-conformance-fixtures-check
make check
powershell -ExecutionPolicy Bypass -File scripts\check.ps1
```

## Maintenance

Update this guide and
[`docs/integrations/fixtures/integration-conformance-fixtures.json`](fixtures/integration-conformance-fixtures.json)
whenever the address book, deployment version, EIP-712 domain, drop
authorization payload fixtures, event topic catalog, ABI checksums, release
manifest, release checksums, or event indexing rules change. Regenerate release
artifacts and checksums after fixture changes so consumers can detect drift from
the public release packet.
