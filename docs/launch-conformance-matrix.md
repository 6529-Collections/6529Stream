# Launch Conformance Matrix

This document turns the Stream target architecture into launch gates. It is not
a roadmap. A deployment is launch-conformant only when every gate below maps to
code, tests, events, and release artifacts.

## Scope

The current contracts are implementation baseline only. They are not
launch-conformant until the gates in this document pass. A specs-only PR may
merge before implementation, but a deployment, audit handoff, or launch branch
must treat any failed gate as blocking.

## Forbidden Launch Patterns

Production launch contracts must not contain:

1. `tx.origin` in mint, sale, drop, auction, authorization, or payment paths.
2. `abi.encodePacked` or string concatenation for authority, sale, assignment,
   policy, profile, pointer, entropy, or finality hashes.
   Standard CREATE2 address derivation is the explicit exception because the
   EVM formula itself uses packed bytes; those packed bytes must not be reused
   as authority or policy hashes.
3. OpenZeppelin `ERC2981` storage or any second Core royalty source of truth.
4. Core-owned collection metadata, script assembly, dependency assembly,
   randomizer state, token hash storage, or primary-sale split policy.
5. Push primary-sale payments to artists, posters, curators, protocol, bidders,
   or split recipients.
6. Casual `emergencyWithdraw` from any contract that can hold owed funds,
   escrowed funds, refunds, or recipient balances.
7. Magic critical-pointer switches such as `updateContracts(uint8,address)`.
8. Selector-alias authorization such as reusing `this.X.selector` for an
   unrelated protected operation.
9. Token ID range heuristics for collection identity, burn validation, royalty
   resolution, metadata routing, or inherited freeze checks.
10. `bytes32(0)` as an entropy pending/finalized sentinel.
11. Multi-source entropy mixers, timelock reveal schemes, or instant entropy
    finalization inside sale settlement as default launch behavior.

## Required Gates

| Gate | Code Surface | Required Tests | Release Artifact |
|---|---|---|---|
| Core-native ERC-2981 | `StreamCore.royaltyInfo`, revenue resolver | canonical `0x3d5d0e9e` resolver selector; malformed/OOG/external-call resolver fallback; all-cold gas | Core bytecode size, resolver gas report |
| Pull split wallets | split factory, split wallet, revenue escrow | conservation fuzz, forced ETH, approved-standard ERC-20 release/sync, unsupported ERC-20 denial, reentrancy | profile schema, wallet code hashes |
| Primary native ETH and approved-standard ERC-20 settlement | fixed-price sale adapter, ERC-20 primary settlement adapter, asset policy registry, revenue escrow | no `tx.origin`, policy hash binding, escrow fallback, adapter and escrow both enforce `ACTIVE` asset policy, exact ERC-20 transfer accounting, allowance/payment failure handling | sale authorization schema, approved asset and adapter manifests |
| Auction settlement | auction contract | bid custody, pull refunds, settlement CEI | auction state-machine manifest |
| Collection management | Core collection boundary | create/status/max-supply events and transitions | collection facts schema |
| Token identity | Core mint boundary, `tokenCollectionIdentity` | Core-owned token allocation, collection serial mapping, mapping-existence read, burn retained mapping | token identity schema |
| Token-level metadata | collection metadata satellite | token data/field overrides, token locks, burned archival reads | token metadata schema |
| Burn | Core burn boundary | owner/approved, mapping retained, finalized burn blocked | burn policy manifest |
| Mint accounting | mint manager, ledger | duplicate-key aggregation, static caps, signed ticket binding | policy hash schema |
| Entropy lifecycle | entropy coordinator, provider | identity written and entropy registered before `_safeMint` callback; non-reentrant request/fulfill; single active request; no instant provider calls from mint path | entropy policy manifest |
| Metadata routing | metadata router, renderer | escaping, size limits, router failure behavior, ERC-4906 auth | renderer and context manifests |
| Collection metadata | metadata contract plus metadata satellites | typed launch fields, generic records, locks, snapshots, aggregate function-count and bytecode ceiling | schema and snapshot manifests, metadata aggregate ABI/bytecode report |
| Preservation records | `StreamPreservationRecords` | PREMIS-style event/object/agent/right records, fixity hash validation, event reconstruction, post-freeze record behavior | preservation module manifest, schema hashes, code hash |
| Collection attestations | `StreamCollectionAttestations` | C2PA/EIP-712/ERC-1271-compatible attestations, signer authority, supersession, event reconstruction | attestation module manifest, schema hashes, code hash |
| Collection views | `StreamCollectionViews` | IIIF/view URI commitments, accessibility/display view references, bounded reads, event reconstruction | view module manifest, schema hashes, code hash |
| Entropy fallback decision | entropy coordinator, retained provider decision | reviewed ARRNG fallback, reviewed Pyth fallback, or reviewed VRF-only exception; coordinator failure mode matches retained decision | checksum-covered `release-artifacts/latest/entropy-launch-decision.json` or equivalent release-manifest record |
| Artwork finality | Core plus satellites | typed finality preimage, pointer race, `verifyFinality` | finality manifest |
| Governance | governance/timelock, role registry | no single EOA, role map cardinality, delays | genesis governance manifest |
| Events | every subsystem | event reconstruction, supersession map | event catalog hash |
| Operations | monitoring/export/storage | degraded-admin test, state export, storage redundancy | ops runbook hashes |

## Minimum Launch Profile

Mandatory launch contracts/interfaces:

```text
StreamCore
StreamGovernance or equivalent ADR 0004 timelock/role layer
IStreamModuleRegistry
IStreamRevenueResolver
IStreamSplitFactory
IStreamSplitWallet
IStreamRevenueEscrow
StreamMintManager
StreamMintLedger
StreamMetadataRouter
StreamCollectionMetadata
StreamPreservationRecords
StreamCollectionAttestations
StreamCollectionViews
StreamEntropyCoordinator
At least one approved entropy provider or explicit NOT_REQUIRED entropy mode
Reviewed ARRNG/Pyth fallback provider or explicit reviewed VRF-only exception
ERC-20 primary settlement adapter for approved standard assets
StreamArtworkFinalityRegistry if any collection launches with finality promises
```

Schema/future or optional-at-launch surfaces:

```text
Custom counter resolvers
Resolver-defined caps/deltas
Privacy nullifiers
Scoped release/season/view finality if no launch collection needs it
CCIP Read and future onchain web adapters
Non-standard ERC-20 primary adapters
Additional institution-specific preservation, rights, VC/DID, EAS, or legal modules
```

Optional surfaces may be specified and reserved, but launch bytecode should not
include callable dead paths for them before their ADR/test suite exists.
Scoped finality write/read/recovery functions for `RELEASE`, `SEASON`, and
`VIEW` must be physically absent from launch bytecode unless a launch collection
needs that scope and the corresponding tests/manifests are included. `TOKEN`
scope may ship with collection finality only if a launch use case requires it.

Launch Core should also publish a Core surface report: runtime bytecode size,
external/public function count, ERC-165 interface set, and selector manifest.
Target Core headroom is at least 2,000 bytes below the EIP-170 limit and a
function count small enough that every selector is permanent, documented, and
covered by a golden interface test. If Core cannot fit with Core-native
ERC-2981 and enumerable, move mutable policy to satellites rather than
expanding Core.

Core planning budget before implementation:

```text
Function group                                      priority    planning runtime bytes
ERC-721 ownership/approval/metadata/enumerable      permanent   7,000-9,000
Mint/burn/token identity/collection serials         permanent   3,000-4,500
Collection facts/status/supply reads and writes     permanent   2,000-3,000
Core-native ERC-2981 resolver read                  permanent     700-1,200
Bounded tokenURI router read/fallback/status        permanent   1,400-2,400
Satellite pointer cached reads and governance hooks permanent   1,200-2,000
Core finality fact reads and lifecycle reads        permanent     700-1,200
ERC-4906 helper emissions                           high          300-700
streamSystemManifest storage-only read              high          500-1,000
Successor declaration history                       medium        500-1,000
latestStateExport storage-only read                 medium        300-700
Prepared mint prepare/complete                      conditional   900-1,800
```

If the measured build exceeds the 22,000-byte CI ceiling or loses the 2,000-byte
headroom, the priority order is: keep ERC-721/enumerable, token identity,
Core-native ERC-2981, and bounded `tokenURI`; then move successor history,
state export publication, rich manifest discovery, and optional prepared-mint
convenience into a thin immutable discovery or mint satellite that Core points
to through the same cached pointer policy.

Additional paid-mint/finality/escrow launch tests:

1. Malicious ERC-721 receiver cannot observe an unpaid, unregistered,
   unsnapshotted, or unaccounted paid mint in either `PRE_REVENUE_SINGLE_STEP`
   or `PREPARED_MINT`.
2. Signed policy expecting token-level economics cannot use
   `PRE_REVENUE_SINGLE_STEP`.
2. A collection configured `ROYALTY_SNAPSHOT_AT_MINT` cannot bind to a
   single-step-only sale adapter.
3. Finality rejects mismatched manifest content hash, URI hash, component code
   hash, unsorted components, duplicate components, and missing `hasMaxSupply`.
4. Pointer replacement is blocked for frozen/finalized routes unless the new
   target proves frozen-route support or a recovery manifest has executed.
5. Escrow credits created before factory replacement flush through their stored
   factory.
6. ERC-1271 alternate-recipient release authorization is gas-capped and tested
   against a malicious contract wallet.
7. `PREPARED_MINT` exposes and verifies one canonical `operationId` across sale
   adapter, manager, ledger, Core prepare/complete, resolver snapshot, entropy
   registration, and escrow/deposit path.
8. Token-level primary and royalty snapshots taken during `PREPARED_MINT` are
   independent of entropy seed/status and renderer output.
9. Open-ended collections can finalize a token, release, season, or view scope
   without closing the parent collection, and frozen-route checks include the
   full scoped finality key.
10. Collection-level finality is impossible unless `CLOSED` makes
    `mintedSupply`, `burnedSupply`, and `nextCollectionSerial` immutable.
11. `royaltyInfo()` and `tokenURI()` gas budgets are independent top-level
    reads; no launch helper combines both in one bounded staticcall frame.
12. Degraded-mode escrow tests document the condition that `flushEscrow`
    remains possible only while the immutable gas floor is satisfiable.

## Static Analysis Gates

CI must fail if any production launch contract violates these checks:

1. `tx.origin` appears outside tests or explicit non-production mocks.
2. Core inherits `ERC2981` or contains `_setDefaultRoyalty`,
   `_setTokenRoyalty`, or equivalent royalty storage.
3. Authority or identity hashes use `abi.encodePacked` where the spec requires
   `abi.encode`.
4. A contract that can hold owed funds exposes unrestricted
   `emergencyWithdraw`.
5. Core stores script chunks, dependency chunks, randomizer pointers, token hash
   status, or primary-sale split percentages.
6. Resolver `royaltyInfoForToken` or any function it can reach contains
   `CALL`, `DELEGATECALL`, `STATICCALL`, `CREATE`, or `CREATE2` opcodes.
7. Any production instant entropy provider reachable from `requestEntropy`
   contains `CALL`, `DELEGATECALL`, `STATICCALL`, `CREATE`, or `CREATE2`,
   performs state writes, or exposes non-`view` `instantEntropy`.
8. Permissioned functions share a durable authorization selector or role key
   unless the shared role is intentionally documented in the role map.
9. Production interface selectors differ from the release selector manifest
   without an intentional manifest update and test review.
10. Launch satellites that promise immutability or bounded reads contain
   `SELFDESTRUCT`, unrestricted `DELEGATECALL`, mutable proxy upgrade hooks, or
   unbounded returndata copies outside explicitly allowed test/migration mocks.
11. Launch mint contracts compile callable `CUSTOM_RESOLVER`,
    resolver-defined cap/delta, or nullifier execution paths before the
    accepted ADR enables them. Reserved enum values may exist in manifests, but
    dead deferred call paths must be physically absent from launch bytecode or
    blocked before any external call/state write by static checks.

## Golden Interface Tests

CI must include small deterministic tests for launch interfaces whose accidental
drift would break indexers, marketplaces, or satellite contracts:

1. `IStreamRevenueResolver.royaltyInfoForToken` has selector `0x3d5d0e9e`
   for the exact signature
   `royaltyInfoForToken(address,uint256,uint256,uint256,bool)`.
2. Core reports `supportsInterface(0x2a55205a) == true` when the launch build
   includes Core-native ERC-2981, and `royaltyInfo()` uses the same capped
   resolver path as `probeRoyaltyInfo()`.
3. `tokenCollectionIdentity(tokenId)` returns
   `(mappingExists, collectionId, collectionSerial, burned)` from Core storage,
   returns the retained collection mapping after burn, and never reconstructs
   collection identity from token ID ranges.
4. Safe mint receiver callbacks can observe a registered token with pending
   entropy, but cannot observe finalized entropy caused by the mint path.
5. `requestEntropy()` writes `REQUESTED` before touching any provider, rejects
   reentrant or duplicate requests, and finalizes synchronous `INSTANT` entropy
   only from the provider return data.
6. `fulfillEntropy()` rejects inactive, stale, wrong-provider, wrong-request,
   already-finalized, and reentrant fulfillment attempts before any external
   refresh or notification.
7. Every production external/public selector appears exactly once in the
   selector manifest with owner subsystem, interface name, mutability, and
   authorization model. Selector collisions are allowed only for standard
   interface overrides that intentionally share the same signature.
8. Event catalog CI proves every replacement event has `supersedes` /
   `replacedBy` links, every archived event remains present forever, and no
   indexed field set changes without a replacement event.
9. Governance tests prove the launch contracts enforce only the ADR 0004
   two-tier model plus named exception floors; the richer action-class taxonomy
   is manifest/runbook vocabulary until a later ADR implements it onchain.
10. Governance tests cover `governanceAction(actionId)`, virtual or materialized
    expiry, terminal-freeze veto, complete scheduled/executed/cancelled/vetoed
    event payloads, and replay protection through nonce/action ID.
11. `IStreamCorePointerView.getSatellitePointer` returns target, code hash,
    freeze state, module type, interface ID, registry address, registry status,
    module manifest hash, and deployment manifest hash.
12. `IStreamModuleRegistry` rejects unknown, deprecated-for-new-use, malformed,
    and incident-revoked modules for new pointer assignments.
13. Cross-contract authority selectors are pinned with golden ABI tests, and
    selector-stable value-type or `bytes32` parameters are preferred for
    authority-critical interfaces.
14. The deployment manifest contains `compatibilityMatrixHash`, event catalog
    hash, numeric ID allocation hash, and reproducible-build artifact hashes for
    every deployed satellite.
15. A collection on a single-step-only mint path cannot select a renderer that
    requires renderer-visible `tokenData` bytes before the recipient callback.
16. `PRE_REVENUE_SINGLE_STEP` with any `RECIPIENT`-keyed counter requires
    `initialRecipient == beneficiary` for each element and otherwise reverts.
17. A finalized collection-scope artwork recovery that affects more than
    `MAX_REFRESH_RANGE` tokens emits chunked `BatchMetadataUpdate` events with
    the same recovery reason hash and never emits one oversized range.
18. A minted token whose pinned entropy coordinator has no code, reverts, is
    incident-revoked, or returns malformed data renders pending/unknown
    metadata rather than reverting `tokenURI()`.
19. Core calls `onTokenMinted` with immutable `ENTROPY_REGISTRATION_GAS_LIMIT`,
    an EIP-150-aware parent gas precheck, measured launch margin, and mint
    revert on registration failure.
20. CI asserts every production event in the event catalog has at most three
    `indexed` fields, matching the Solidity log topic limit.
21. Golden tests assert numeric enum values for `TokenURIReadStatus`,
    `StreamTokenLifecycle`, `EntropyStatus`, `ProviderResultStatus`,
    `ModuleRegistryStatus`, finality scope types, and recovery statuses match
    the manifest-pinned Numeric ID Catalog.
22. Any satellite function reachable during `PREPARED_MINT`, including resolver
    snapshot hooks, escrow/deposit paths, and entropy registration helpers,
    reads or re-verifies Core `preparedMint(tokenId).operationId` and reverts
    on mismatch before any state write or external call.
23. Catalog or pointer updates that change `streamSystemManifest()` fields must
    update Core's cached manifest/catalog hashes atomically in the same
    governed execution; tests fail if registry/catalog publisher state drifts
    from Core's cached discovery fields.

## Current-Code Contradictions

The baseline code must be rewritten or replaced before launch where it conflicts
with this matrix:

1. `StreamCore` inherits OZ `ERC2981` and sets a hardcoded default royalty.
2. `StreamDrops` uses `tx.origin`, push payments, and packed/string hashes.
3. `StreamMinter` participates in token ID construction through namespaced
   ranges.
4. Core metadata/script/randomizer logic remains embedded in Core.
5. Entropy is registered after `_safeMint` and uses zero hash sentinel state.
6. `StreamAdmins` is selector-based and lacks timelocks, staging, and role
   constants.
7. Emergency withdraw functions can sweep balances without owed/surplus proof.
8. `freezeCollection` is not cross-module artwork finality.
9. `StreamCuratorsPool` push payments or unrestricted sweeps are not
   launch-conformant if the pool holds owed rewards.

## Event Catalog Schema

Every release must include a machine-readable event catalog canonicalized with
RFC 8785/JCS:

```json
{
  "schema": "6529.stream.event-catalog.v1",
  "chainId": 1,
  "deployment": "0x...",
  "events": [
    {
      "signature": "EventName(uint16,uint256,bytes32)",
      "topic0": "0x...",
      "schemaVersion": 1,
      "owner": "revenue",
      "status": "active",
      "indexed": ["collectionId", "profileId"],
      "unindexed": ["schemaVersion", "amount"],
      "supersedes": [],
      "replacedBy": null,
      "semanticsURI": "ipfs://...",
      "semanticsHash": {
        "algorithm": "KECCAK256",
        "digest": "0x..."
      }
    }
  ]
}
```

New events either include `uint16 schemaVersion` or have immutable v1 semantics
pinned in this catalog. Event replacements must use `supersedes` and
`replacedBy`; old events remain in the catalog forever with `status: archived`
and are never reinterpreted.
The v1 catalog must explicitly list standard-event exemptions where the event
signature cannot include `schemaVersion`, including ERC-721 `Transfer`,
`Approval`, `ApprovalForAll`, ERC-2981 interface discovery through ERC-165, and
ERC-4906 `MetadataUpdate` / `BatchMetadataUpdate` if emitted with their
standard signatures.
Any non-standard event snippet elsewhere in the specs that omits
`schemaVersion` is shorthand, not permission to omit it from launch ABI. The
event catalog and golden event tests are authoritative.

## Numeric ID Catalog

Every enum-like numeric value that crosses contract, indexer, or manifest
boundaries must be assigned in a manifest-pinned numeric ID catalog. The launch
catalog must cover at least module registry states, governance action classes
and statuses, freeze modes, collection statuses, supply modes, entropy
statuses, provider result statuses, asset policy statuses, schema statuses,
hash algorithms, canonicalization IDs, source/storage types, token URI read
statuses, finality scope types, and recovery statuses. IDs may be deprecated
but not reinterpreted.
The Numeric ID Catalog has its own schema version, schema URI/hash,
canonicalization ID, and supersedes-catalog hash. Updating the catalog format
is a catalog supersession, not a mutation of old IDs.

Lifecycle reconciliation matrix:

```text
Token condition        StreamTokenLifecycle     TokenURIReadStatus     EntropyStatus
nonexistent            UNKNOWN                  NONEXISTENT            NONE/UNKNOWN
prepared incomplete    PREPARED_INCOMPLETE      PREPARED_INCOMPLETE    REGISTERED or terminal DISABLED/NOT_REQUIRED
minted pending         MINTED                   OK                     REGISTERED/REQUESTED/STALE/FAILED
minted finalized       MINTED                   OK                     FINALIZED
burned                 BURNED                   BURNED                 retained last entropy status or terminal archive status
```

The numeric ID catalog pins values independently for each enum; indexers must
not assume the same word has the same numeric value across different enum
families.

## Indexed Field Policy

Indexed event fields are part of Stream's long-term query contract. Every
launch event must classify each field as indexed or unindexed in the event
catalog and explain the reconstruction purpose for indexed fields. Required
indexed field families:

1. `collectionId` on collection, metadata, mint, entropy, finality, and
   collection-scoped revenue events.
2. `tokenId` on token identity, token metadata, entropy, burn, and
   token-scoped revenue events.
3. `profileId` or `wallet` on split-wallet, escrow, release, and revenue
   events where the payee profile is material.
4. `revenueClass` on primary and royalty assignment, escrow, and settlement
   events.
5. `operationId` or `actionId` on governance staging, cancellation, execution,
   and recovery events.

Changing an indexed field set after launch is an event replacement, not a
semantic edit. The new event must supersede the old one in the event catalog.
