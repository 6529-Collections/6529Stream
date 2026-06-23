# Architecture

6529Stream is a pre-audit local baseline for 6529 NFT drops. This document is
not a security claim and is not production-ready documentation. It gives
auditors a single map of the current contract system, trust boundaries, value
flows, and evidence links without replacing the source code, ADRs, or tests.

Read this document together with the [threat model](threat-model.md), the
[external audit package](audit-package.md), the [project status](status.md),
the [known blockers](known-blockers.md), and the canonical roadmap in
[`ops/ROADMAP.md`](../ops/ROADMAP.md).

## Pre-Launch Target Specs

This page maps the current local baseline. The intended pre-launch architecture
for the expanded Stream modules is specified separately:

- [Launch v1 target architecture](launch-v1-target-architecture.md)
- [Revenue splits and royalties](revenue-splits-and-royalties.md)
- [Mint policy and accounting](mint-policy-and-accounting.md)
- [Metadata router and renderer](metadata-router-and-renderer.md)
- [Collection metadata contract](collection-metadata-contract.md)
- [Entropy coordinator](stream-entropy-coordinator.md)
- [Entropy providers](stream-entropy-providers.md)
- [ADR 0008: revenue splits and royalty resolver](adr/0008-revenue-splits-and-royalty-resolver.md)

## Maturity And Scope

The current architecture covers the local Anvil baseline only. It includes:

- first-party production Solidity contracts under `smart-contracts/`;
- accepted ADRs under [`docs/adr/`](adr/README.md);
- local deployment, metadata-browser, auction, emergency-redeployment,
  ceremony-evidence, randomizer-operations, release-signature, release-manifest,
  and checksum evidence;
- local Foundry, Python, browser, and release-artifact checks.

The architecture does not yet include fork, testnet, or mainnet broadcast
evidence, production contract verification, production signer identities,
detached production signatures, live provider funding evidence, or a completed
external audit report. Those remain blockers in
[`docs/known-blockers.md`](known-blockers.md) and
[`ops/ROADMAP.md`](../ops/ROADMAP.md).

## System Components

The current local deployment rehearsal wires the following contracts:

| Component | Responsibility | Primary evidence |
| --- | --- | --- |
| `StreamAdmins` | Root admin, global/function admin, pause guardian, unpause admin, signer manager, and emergency-recipient registry | [`docs/adr/0004-admin-governance.md`](adr/0004-admin-governance.md), `test/StreamAdmins.t.sol` |
| `DependencyRegistry` | Versioned generative dependency source, content hashes, provenance, and deprecation state | [`docs/dependency-operations.md`](dependency-operations.md), `test/StreamDependencyRegistry.t.sol` |
| `StreamCore` | ERC-721 ownership, collection configuration, metadata generation, dependency pins, burns, freeze manifests, and randomizer registration | [`docs/metadata.md`](metadata.md), `test/StreamMetadataFreeze.t.sol` |
| `StreamMinter` | Mint phase gating and mint authority bridge into `StreamCore` | [`docs/adr/0001-drop-authorization.md`](adr/0001-drop-authorization.md), `test/StreamCoreMinting.t.sol`, `test/StreamEmergencyWithdraw.t.sol` |
| `StreamDrops` | EIP-712 drop authorization, fixed-price mint execution, auction-drop creation, pull-payment credits, and consumed/cancelled drop IDs | [`docs/adr/0001-drop-authorization.md`](adr/0001-drop-authorization.md), `test/StreamDropAuthorization.t.sol` |
| `StreamAuctions` | Auction escrow custody, bidding, settlement, cancellation, bidder/proceeds credits, and auction-local accounting | [`docs/auction-custody.md`](auction-custody.md), `test/StreamAuctionInvariant.t.sol` |
| `StreamCuratorsPool` | Curator Merkle reward claims, delegation checks, reward credits, and curator-pool surplus boundaries | [`docs/adr/0003-payment-accounting.md`](adr/0003-payment-accounting.md), `test/StreamCuratorsPool.t.sol` |
| `NextGenRandomizerVRF` | VRF request lifecycle adapter, callback validation, raw-output hash storage, retry, stale, and failed post-processing state | [`docs/randomizer-operations.md`](randomizer-operations.md), `test/StreamRandomizerLifecycle.t.sol` |
| `NextGenRandomizerRNG` | arRNG request lifecycle adapter, reserve accounting boundary, callback validation, retry, stale, and failed post-processing state | [`docs/randomizer-operations.md`](randomizer-operations.md), `test/StreamRandomizerPayments.t.sol` |

OpenZeppelin utility files retained in the repo are tracked separately in
[`docs/vendored-libraries.md`](vendored-libraries.md) and
[`ops/SLITHER_BASELINE.md`](../ops/SLITHER_BASELINE.md).

In this document, `arRNG` means the external randomness controller consumed
through `ArrngConsumer` by `NextGenRandomizerRNG`. Its concrete provider
configuration is release evidence, not hard-coded protocol trust.

## Product Extension And Size-Budget Policy

Future 1/1 product work is satellite-first by default. New collector-facing
features should use satellite contracts, read adapters, linked libraries,
release artifacts, or documentation-only evidence unless the feature is a
Core invariant, token-ownership rule, or security boundary that must live in
`StreamCore`.

The current production size thresholds are recorded in
[`release-artifacts/contracts.json`](../release-artifacts/contracts.json). The
current measured `StreamCore` runtime and EIP-170 margin source of truth is the
bytecode release proof
[`release-artifacts/latest/bytecode-release-proof.json`](../release-artifacts/latest/bytecode-release-proof.json)
plus the artifact-backed checker
[`scripts/check_contract_size_budget.py`](../scripts/check_contract_size_budget.py).
Run `python scripts/check_contract_size_budget.py` after the production size
build before relying on any size-budget claim.
The stricter bytecode-spend policy is checked by
[`scripts/check_core_bytecode_spend_policy.py`](../scripts/check_core_bytecode_spend_policy.py):
the current approved `StreamCore` runtime may decrease without review, but any
increase above the approved baseline requires an accepted exception record in
[`release-artifacts/contracts.json`](../release-artifacts/contracts.json).
The current production profile is:

- command: `forge build --sizes --via-ir --skip test --skip script --force`;
- current `StreamCore` runtime: 21,824 bytes;
- current EIP-170 margin: 2,752 bytes;
- approved `StreamCore` bytecode-spend baseline: 22,184 bytes;
- approved baseline EIP-170 margin: 2,392 bytes;
- minimum release floor: 384-byte minimum runtime margin;
- warning threshold: 512-byte warning runtime margin.

Any PR that spends non-trivial `StreamCore` bytecode must include:

- a linked GitHub issue or ADR explaining why a satellite contract, read
  adapter, library, release artifact, or docs-only path is insufficient;
- a measured before/after `StreamCore` runtime bytecode delta from the
  production profile;
- the resulting EIP-170 margin and whether it remains above the 384-byte
  minimum release floor and 512-byte warning threshold;
- an explicit size-budget exception note in `CHANGELOG.md`,
  `docs/release-policy.md`, or the affected ADR when the change is
  non-critical product functionality;
- updated release artifacts when ABI, bytecode, deployment, manifest, checksum,
  or bytecode-to-release proof outputs change; and
- tests or retained evidence proving behavior did not move across trust
  boundaries accidentally.

The current rejected-experiment history in `release-artifacts/contracts.json`
records measured attempts that did not recover headroom, including externalizing
unused public views, moving freeze-manifest hash assembly into the renderer, and
hand-writing metadata constant getters. Contributors should prefer new measured
architecture changes over repeating those no-gain or negative-gain refactors.

The default classification for future feature work is:

| Feature type | Default path | Core spend posture |
| --- | --- | --- |
| Ownership, transfer, mint authority, burn, and token-existence invariants | `StreamCore` only when required by ERC-721 semantics | Allowed with measured delta and release-risk review |
| Metadata rendering helpers, contract-level metadata, provenance, permanence, marketplace/indexer proof, and collector evidence | Satellite contracts, read adapters, release artifacts, or docs | Avoid Core unless an ADR accepts the exception |
| Royalty display, policy, enforcement experiments, and marketplace compatibility | Current fixed ERC-2981 Core surface plus satellite policy/enforcement contracts if needed | Avoid Core for mutable policy or enforcement experiments |
| Frontend, mobile, Electron, SDK, analytics, and indexer behavior | Integration docs, generated artifacts, release manifests, and off-chain code | No Core spend |
| Deployment, ceremony, audit, release, signature, and evidence workflows | Release artifacts, deployment manifests, address books, runbooks, and retained evidence | No Core spend |

This policy is intentionally conservative even with 2,752 bytes of current
headroom after moving script assembly, metadata validation profiles,
tokenURI dispatch helpers into the linked renderer library, and measured
CON-008 micro-optimizations into `StreamCore`. The approved bytecode-spend
baseline remains 22,184 bytes with 2,392 bytes of EIP-170 margin, so future
Core growth above that ceiling still needs an accepted exception. The goal is to keep
`StreamCore` deployable, auditable, and stable while allowing world-class 1/1
drop surfaces to evolve through explicit, versioned extension points.

## Actor And Role Boundaries

The current role model separates operational duties:

- `owner`: owns `StreamAdmins` and `StreamCore` after the deployment ceremony.
- Global admins: broad protocol operators registered through `StreamAdmins`.
- Function admins: target-scoped permission grants for specific selectors.
- Pause guardians: can pause configured operational domains.
- Unpause admins: can unpause configured domains.
- Signer managers: can rotate approved drop-signing identities on approved
  signer-lifecycle targets.
- Drop signers: sign EIP-712 drop authorizations but do not manage their own
  lifecycle authority.
- Posters: submit signed fixed-price or auction drop executions.
- Buyers and bidders: pay for fixed-price mints or auction bids.
- Curators: claim Merkle rewards through pull credits.
- Randomizer providers: fulfill VRF or arRNG requests through configured
  adapters.
- Dependency operators: add and deprecate generative dependency versions.
- Release operators: generate manifests, address books, checksums, ceremony
  evidence, and future signatures.

Production deployments are expected to transfer ownership and high-impact
authority to a Safe or equivalent multisig, as described in
[`docs/deployment.md`](deployment.md). The local baseline uses placeholder
addresses only.

## Protocol Flows

### Fixed-Price Drop

1. A drop signer signs an EIP-712 authorization in the `StreamDrops` domain.
2. A poster submits the authorization, token data, and signature.
3. `StreamDrops` validates signer authority, deadline, domain, fields, and
   consumed/cancelled drop state.
4. `StreamMinter` mints through `StreamCore`.
5. Poster, protocol, and curator-reserve value is recorded as pull credits.
6. The token starts with pending metadata until randomness or metadata state
   produces a final, stale, or failed result.

Key evidence: [`docs/adr/0001-drop-authorization.md`](adr/0001-drop-authorization.md),
[`docs/adr/0003-payment-accounting.md`](adr/0003-payment-accounting.md),
`test/StreamDropAuthorization.t.sol`, `test/StreamFixedPricePayments.t.sol`,
and `test/StreamPaymentsInvariant.t.sol`.

### Auction Drop

1. A drop signer signs an auction authorization.
2. `StreamDrops` mints the NFT directly to `StreamAuctions`.
3. `StreamAuctions.registerAuction` confirms escrow custody and enters `Active`.
4. Bidders place bids while the auction is active.
5. Outbid bidders receive withdrawable credits.
6. Settlement transfers the NFT and converts active escrow into proceeds
   credits, or returns custody to the poster under the no-bid path.

Key evidence: [`docs/auction-custody.md`](auction-custody.md),
[`docs/adr/0002-auction-custody.md`](adr/0002-auction-custody.md),
`test/StreamAuctionPayments.t.sol`, and `test/StreamAuctionInvariant.t.sol`.

### Randomness And Metadata

1. Collections choose an approved randomizer.
2. Minted tokens start as pending metadata.
3. VRF or arRNG adapters record request lifecycle state.
4. Fulfillment validates request ID, token, collection, provider, and collection
   randomizer epoch before setting token hash.
5. Failed deterministic post-processing becomes observable state and can be
   retried without requesting new provider output.
6. Metadata exposes pending, stale, failed, or final schema-v1 state.
7. Collection freeze requires final live-token metadata and records a freeze
   manifest hash.

Key evidence: [`docs/adr/0005-randomness.md`](adr/0005-randomness.md),
[`docs/metadata.md`](metadata.md),
[`docs/randomizer-operations.md`](randomizer-operations.md),
`test/StreamRandomizerLifecycle.t.sol`, `test/StreamMetadataGolden.t.sol`, and
`test/StreamMetadataFreeze.t.sol`.

### Dependency And Release Evidence

Dependency source is versioned in `DependencyRegistry`, packaged under
`release-artifacts/dependencies/`, and documented in
[`docs/dependency-operations.md`](dependency-operations.md). Release evidence is
generated into `release-artifacts/latest/` and tied together by
[`release-artifacts/latest/release-manifest.json`](../release-artifacts/latest/release-manifest.json).
The signable checksum bundle lives at
[`release-artifacts/latest/SHA256SUMS`](../release-artifacts/latest/SHA256SUMS).

## Value And Custody Boundaries

The current architecture avoids synchronous ETH push payments in core user
flows:

- fixed-price mint proceeds are recorded as poster/protocol/curator-reserve
  credits in `StreamDrops`;
- outbid refunds become bidder credits in `StreamAuctions`;
- with-bid auction settlement converts active escrow into poster/protocol/curator
  proceeds credits;
- curator rewards become `StreamCuratorsPool` credits;
- failed withdrawals do not erase credit;
- emergency withdrawal views expose surplus boundaries for current value-holding
  contracts.

Payment accounting is local to each value-holding contract rather than a shared
protocol-wide ledger. A unified shared ledger remains optional future
architecture if a later ADR chooses it.

## Randomness And Metadata Boundaries

Randomness providers are external trust boundaries. The contract adapters
validate provider, request, token, collection, and epoch context before
accepting output, but fork/testnet/live provider funding and request-health
evidence remains future Gate E work.

Generated animation HTML intentionally executes artist/dependency code in the
token experience. Contract and release tooling protects the wrapper structure,
validates committed fixtures, checks UTF-8/URI/attribute constraints, and runs
local browser sandbox evidence, but it does not certify arbitrary artist code as
safe for every consumer environment.

## Deployment And Release Boundaries

The current deployment posture follows
[`docs/adr/0007-upgrade-redeployment.md`](adr/0007-upgrade-redeployment.md):

- contracts are treated as immutable for the public-beta plan;
- emergency recovery is modeled as versioned redeployment rather than proxy
  upgrade;
- deployment manifests, address books, ceremony evidence, randomizer operations
  evidence, release signature evidence, source verification inputs, and checksum
  bundles are deterministic local artifacts;
- production broadcasts, live explorer verification, production address books,
  detached signatures, signed tags, and fork/testnet/live ceremony evidence
  remain open.

## Invariants And Evidence

Important local invariant evidence includes:

- payment owed/reserved/surplus coherence in `test/StreamPaymentsInvariant.t.sol`;
- supply, replay, burn, and freeze coherence in
  `test/StreamSupplyReplayFreezeInvariant.t.sol`;
- auction custody, bid escrow, settlement, and credit coherence in
  `test/StreamAuctionInvariant.t.sol`;
- randomizer reserve lifecycle boundaries in
  `test/StreamRandomizerPayments.t.sol`;
- deployment manifest parsing and ceremony evidence in
  `test/StreamDeploymentManifest.t.sol`;
- metadata golden fixtures and browser checks in
  `test/StreamMetadataGolden.t.sol`, `scripts/check_metadata_fixtures.py`, and
  `scripts/check_metadata_browser_sandbox.py`.

The current tests are strong regression tripwires, not a formal proof of
protocol correctness.

## Known Gaps

The main architecture gaps before public beta are:

- fork/testnet/live deployment rehearsal and retained broadcast evidence;
- live explorer verification and verified live addresses;
- production release signatures and signed Git tags;
- production address books and release ceremony evidence contents;
- fork/testnet/live metadata browser evidence;
- fork/testnet/live randomizer provider funding and request-health evidence;
- external audit completion and remediation tracking.

See [`docs/known-blockers.md`](known-blockers.md) for the public blocker
summary and [`ops/ROADMAP.md`](../ops/ROADMAP.md) for the full execution plan.

## Maintenance

Update this document when a PR changes contract responsibilities, authority
boundaries, value custody, randomness lifecycle, metadata lifecycle, deployment
artifacts, release artifacts, or accepted ADR decisions. If this file changes,
run:

```sh
python scripts/test_architecture_threat_model.py
python scripts/check_architecture_threat_model.py
python scripts/generate_release_manifest.py --check
python scripts/generate_release_checksums.py --check
```
