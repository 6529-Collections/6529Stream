# Selected-work offer manifests

Use `buildCuratedManifest` with the predicted kind-6 sale ID to publish every
ordered `(contentId, tokenDataHash, previewURI)` row for a native primary offer.
The original content leaf, context, proof construction and publication bytes
are shared with the [curated manifest helpers](current-curated-content.md).
Pass its exact three-field `selections` entry into the offer acceptance.

The offer gate has a distinct capability. `primaryOfferGateConfigHash` uses
`6529STREAM_NATIVE_PRIMARY_OFFER_GATE_V1`; `inspectPrimaryOfferManifest` reads
`offerPurchaseVersion`. The curated purchase gate helper cannot validate it.
Neither helper changes or reinterprets kind-5 private-sale semantics.

```ts
const publication = await inspectPrimaryOfferManifest(provider, offerGate, manifest, {
  blockTag: reviewedBlockNumber,
});
```

The inspector snapshots the complete rows before RPC work, compares all stored
manifest bytes, publication fields and row count, then checks saved Manager and
carrier runtime hashes against code observed at that numeric block. It bounds
and canonically decodes all seven getter responses. It does not detect reorgs
or establish canonical deployment, preview availability, phase admission or
remaining counter capacity. Exact purchase simulation checks the live contract
path and is still only an `eth_call` observation.

Collection-level offers require zero manifest and selected-content fields and
no phase gate. They use no synthetic manifest or selected-work reservation.
See the [primary offer workflow](current-primary-offer.md) for registration,
original signatures, executor-funded acceptance, refunds and revocation.
