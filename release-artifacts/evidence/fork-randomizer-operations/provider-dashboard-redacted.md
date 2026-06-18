# Fork Randomizer Provider Export

## Scope

- Evidence ID: `fork-mainnet-6529stream-v0.1.0-001-randomizer-provider-export`
- Environment: `fork`
- Chain ID: `1`
- Fork reference: `fork block 25316366 / 0xb7c7a456e0f1246fa4ee52de6fca99cc16628ce1eafd85b65b0f3d22f3933ee7`
- Deployment version: `fork-mainnet-6529stream-v0.1.0-001-broadcast`

## Providers

- VRF adapter: `0x9e3b3fd0017753ceb467036cf605a94660aae126`
- VRF coordinator: `0x0000000000000000000000000000000000006535`
- VRF provider type: `chainlink_vrf`
- VRF provider epoch: `0`
- VRF funding status: `funded`
- VRF observed balance: `1000000000000000000`
- arRNG adapter: `0x1e26a8b0cbccbb460bc208799a703a35bf287b67`
- arRNG controller: `0x0000000000000000000000000000000000006536`
- arRNG provider type: `arrng`
- arRNG provider epoch: `0`
- arRNG funding status: `funded`
- arRNG observed balance: `1000000000000000000`
- arRNG refund recipient: `0x0000000000000000000000000000000000000009`

## Review Notes

- The fork deployment manifest records the randomizer adapters and external
  provider placeholders used for the retained fork rehearsal.
- Provider funding is treated as funded for the retained fork rehearsal because
  the fork harness uses deterministic placeholder providers with no external
  billing account dependency.
- Local lifecycle and reserve tests provide the request, callback, stale,
  failed, retry, reserve, pause, and emergency-boundary proof that cannot be
  observed from the fork broadcast alone.
- Production still requires live provider account, health, billing, request,
  and callback evidence before production-release readiness can advance.

## Omitted Operational Material

- Private endpoints are omitted.
- Provider account credentials are omitted.
- Operator workstation material is omitted.
- Unreleased drop payloads are omitted.
