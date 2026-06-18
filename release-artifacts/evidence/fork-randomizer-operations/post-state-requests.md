# Fork Randomizer Post-State Request Views

## Scope

- Evidence ID: `fork-mainnet-6529stream-v0.1.0-001-randomizer-post-state`
- Environment: `fork`
- Chain ID: `1`
- Fork reference: `fork block 25316366 / 0xb7c7a456e0f1246fa4ee52de6fca99cc16628ce1eafd85b65b0f3d22f3933ee7`
- Deployment version: `fork-mainnet-6529stream-v0.1.0-001-broadcast`

## Deployment Views

- StreamCore: `0x74ff318d8c72a9343d465ef1a8725f4fe20b6015`
- StreamAdmins: `0x9bb78cb0ab5960e9c0db0d8ac2391d15db3f1f5f`
- NextGenRandomizerVRF: `0x9e3b3fd0017753ceb467036cf605a94660aae126`
- NextGenRandomizerRNG: `0x1e26a8b0cbccbb460bc208799a703a35bf287b67`
- Collection ID: `1`
- Collection randomizer: `0x9e3b3fd0017753ceb467036cf605a94660aae126`
- Randomizer epoch: `0`

## Request Health

- Pending request count: `0`
- Request tracking: `passed`
- Callback validation: `passed`
- Pending request migration block: `passed`
- Stale request handling: `passed`
- Failed request handling: `passed`
- Retry handling: `passed`
- Provider migration status: `passed`

## Reserve And Controls

- Randomizer reserve status: `funded_and_reconciled`
- VRF funding status: `funded`
- arRNG funding status: `funded`
- Pause policy: `passed`
- Emergency withdrawal boundary: `passed`
- Monitoring handoff: `docs/monitoring.md and docs/randomizer-operations.md`

## Evidence Boundaries

- The retained fork broadcast proves adapter deployment, provider wiring, and
  collection randomizer assignment.
- The retained local test suite proves request lifecycle, callback binding,
  stale and failed handling, retry behavior, reserve accounting, pause scope,
  and emergency-withdrawal boundaries.
- This file does not claim live provider account health. Live provider health
  remains a production-release evidence requirement.
