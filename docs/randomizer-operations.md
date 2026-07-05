# Randomizer Operations

Baseline record — not a specification. This document describes as-built
or operational state; the normative target is the specification set
indexed in [`docs/spec-policy.md`](spec-policy.md), and where this
document conflicts with a specification home, the specification wins. For
target entropy behavior this document is superseded by
[`docs/stream-entropy-coordinator.md`](stream-entropy-coordinator.md).

6529Stream treats randomizer configuration as deployment evidence, not as a
tribal-knowledge checklist. Every fork, testnet, and production release should
retain a public, no-secret randomizer operations evidence bundle under
`deployments/randomizer-operations/`.

The bundle complements `docs/adr/0005-randomness.md`. It records the concrete
provider configuration and operational checks used for a deployment version:

- deployed `NextGenRandomizerVRF` and `NextGenRandomizerRNG` adapter addresses;
- VRF coordinator and arRNG controller addresses;
- provider epoch at the time of evidence capture;
- provider funding or billing status;
- arRNG refund-recipient and adapter reserve policy;
- request tracking, callback validation, migration, stale request, failed
  request, retry, reserve-accounting, pause, and emergency-withdrawal checks;
- retained artifact references and hashes;
- redaction policy proving no private keys, mnemonics, RPC URLs, API keys, or
  unreleased drop payloads are committed.

If a live request becomes stale, fails post-processing, receives an invalid
callback, or is affected by provider migration, follow the randomizer section
of [`docs/incident-response.md`](incident-response.md) before changing public
readiness status.

Validate the committed local evidence with:

```sh
python scripts/test_randomizer_operations.py
python scripts/check_randomizer_operations.py
```

The committed
`deployments/randomizer-operations/anvil-6529stream-v0.1.0-001-local.json`
bundle is Anvil-only evidence. It is allowed to mark provider funding as
`not_applicable_local` because it uses placeholder provider addresses from the
local deployment manifest.

Non-local evidence must not use `not_applicable_local` funding status. Mainnet
or production evidence must include retained `provider_configuration`,
`provider_funding`, and `provider_health` artifacts, and all lifecycle controls
must pass before the bundle can be accepted.

## Evidence Capture

For each fork, testnet, or production deployment, operators should capture:

- deployment manifest and address book for the exact deployment version;
- ABI checksum file used by the release;
- VRF coordinator, subscription or billing account identifier, balance/funding
  state, and request health notes;
- arRNG controller, request-cost/funding state, refund recipient, and provider
  payment notes;
- current provider epoch and any planned migration window;
- pending request count and any open stale or failed request IDs;
- pause and emergency-control status;
- source/explorer verification links or retained submissions;
- CI run, commit, and confirmation depth used for the evidence;
- public operator notes, with secrets redacted before commit.

The evidence file should reference retained files by path and SHA-256. Do not
paste credentials, endpoint URLs, private transaction payloads, or unreleased
drop authorization payloads into the JSON. If live provider dashboards or
explorers are used, retain sanitized screenshots, text exports, or transaction
references as public artifacts and record their hashes.
Incident recovery evidence should use the same retained-artifact and redaction
rules.

## Release Integration

Randomizer operations evidence is part of the deterministic release surface.
After changing randomizer evidence, schemas, or docs, regenerate and check the
top-level release files:

```sh
python scripts/generate_release_manifest.py
python scripts/generate_release_manifest.py --check
python scripts/generate_release_checksums.py
python scripts/generate_release_checksums.py --check
```

The local evidence does not prove provider readiness for public beta. It proves
the repository has a concrete, reviewable format for retaining that evidence
when fork, testnet, and production ceremonies are run.
