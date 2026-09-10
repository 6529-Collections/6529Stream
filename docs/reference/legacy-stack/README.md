# Legacy stack reference

This material describes the earlier StreamDrops / StreamMinter / StreamAuctions
and randomizer stack. It is retained for historical understanding, regression
tests, and evidence interpretation. It is not the integration API of the current
permanent Core. Start new work with the [current walkthrough](../../current-stack.md).

The preserved architecture and integration guides below come from commit
`330ac1d40b1a0d385399ca68423503c892ea0c04`; internal “current” statements belong
to that historical context. Relative links were repaired for this reference home.

- [Architecture](architecture.md)
- [Integration overview](integrations/README.md)
- [Fixed-price drops](integrations/contract-flows.md)
- [Auctions](integrations/auction-flows.md)
- [Signatures](integrations/wallets-and-signatures.md)
- [Events and indexing](integrations/events-and-indexing.md)
- [Metadata rendering](integrations/metadata-rendering.md)
- [Withdrawals and credits](integrations/withdrawals-and-credits.md)

Normative specifications and accepted ADRs remain in their existing homes.
Historical deployment compiler snapshots also remain byte-for-byte independent
of new source paths. A source-file move does not revise a past deployment.

## Historical client designs

These platform guides and examples describe earlier or uninstalled components:

- [frontend-reference-architecture.md](integrations/frontend-reference-architecture.md)
- [integration-conformance-fixtures.md](integrations/integration-conformance-fixtures.md)
- [electron-security-wallets.md](integrations/electron-security-wallets.md)
- [mobile-walletconnect.md](integrations/mobile-walletconnect.md)
- [operator-admin-ui.md](integrations/operator-admin-ui.md)
- [curator-rewards.md](integrations/curator-rewards.md)
- [interface-versioning.md](integrations/interface-versioning.md)
- [examples/react-viem.md](integrations/examples/react-viem.md)
- [examples/typescript-artifacts-and-chain-config.md](integrations/examples/typescript-artifacts-and-chain-config.md)
- [examples/typescript-eip712-drop-authorization.md](integrations/examples/typescript-eip712-drop-authorization.md)
- [examples/typescript-event-decoding-and-indexer-ingestion.md](integrations/examples/typescript-event-decoding-and-indexer-ingestion.md)
