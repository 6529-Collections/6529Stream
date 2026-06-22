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

## Required Gates

| Gate | Code Surface | Required Tests | Release Artifact |
|---|---|---|---|
| Core-native ERC-2981 | `StreamCore.royaltyInfo`, revenue resolver | canonical `0x3d5d0e9e` resolver selector; malformed/OOG/external-call resolver fallback; all-cold gas | Core bytecode size, resolver gas report |
| Pull split wallets | split factory, split wallet, revenue escrow | conservation fuzz, forced ETH, ERC-20 denial, reentrancy | profile schema, wallet code hashes |
| Primary native ETH settlement | fixed-price sale adapter | no `tx.origin`, policy hash binding, escrow fallback | sale authorization schema |
| Auction settlement | auction contract | bid custody, pull refunds, settlement CEI | auction state-machine manifest |
| Collection management | Core collection boundary | create/status/max-supply events and transitions | collection facts schema |
| Token identity | Core mint boundary, `tokenCollectionIdentity` | collection serial mapping, mapping-existence read, burn retained mapping | token identity schema |
| Token-level metadata | collection metadata satellite | token data/field overrides, token locks, burned archival reads | token metadata schema |
| Burn | Core burn boundary | owner/approved, mapping retained, finalized burn blocked | burn policy manifest |
| Mint accounting | mint manager, ledger | duplicate-key aggregation, static caps, signed ticket binding | policy hash schema |
| Entropy lifecycle | entropy coordinator, provider | identity written and entropy registered before `_safeMint` callback; non-reentrant request/fulfill; single active request; no instant provider calls from mint path | entropy policy manifest |
| Metadata routing | metadata router, renderer | escaping, size limits, router failure behavior, ERC-4906 auth | renderer and context manifests |
| Collection metadata | metadata contract | typed launch fields, generic records, locks, snapshots | schema and snapshot manifests |
| Artwork finality | Core plus satellites | typed finality preimage, pointer race, `verifyFinality` | finality manifest |
| Governance | governance/timelock, role registry | no single EOA, role map cardinality, delays | genesis governance manifest |
| Events | every subsystem | event reconstruction, supersession map | event catalog hash |
| Operations | monitoring/export/storage | degraded-admin test, state export, storage redundancy | ops runbook hashes |

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
7. Permissioned functions share a durable authorization selector or role key
   unless the shared role is intentionally documented in the role map.

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
`replacedBy`; old events are archived, never reinterpreted.
