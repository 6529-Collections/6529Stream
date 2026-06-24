# Launch V1 Target Architecture

This document is the normative pre-launch target for the expanded Stream
specification set. It reconciles the revenue, mint, metadata, and entropy specs
into one launch scope. The current contracts remain the implementation
baseline, not the final launch architecture.

6529Stream has not launched. These requirements are therefore implementation
targets for the initial production system.

## Launch Scope

Launch v1 should ship the smallest auditable system that preserves 50-year
optionality:

| Area | Launch v1 requirement | Future extension posture |
| --- | --- | --- |
| Core | ERC-721 ownership, token identity, collection identity, supply invariants, minimal router/resolver/coordinator hooks, and Core-native ERC-2981 | No mutable policy or rendering logic in Core |
| Revenue | Immutable split profiles, deterministic split wallets, resolver assignments, native ETH primary settlement, approved-standard ERC-20 primary settlement through outside-Core adapters, passive royalty receipt, and native/approved-asset revenue escrow | Non-standard ERC-20 behavior and special recovery adapters require accepted follow-up specs |
| Royalties | Core-native ERC-2981 that calls a resolver for receiver and bps, then computes amount in Core | Marketplace registry overrides are integration extras, not the launch path |
| Minting | `StreamMintManager` policy plus `StreamMintLedger` accounting with many counters, aggregate-only consumption, signed tickets, and module-checked gates/resolvers | New counter resolvers and gates can be added through the registry |
| Metadata | `StreamMetadataRouter`, `StreamRendererV1`, `StreamCollectionMetadata`, and launch preservation/attestation/view satellites for identity, rights, media, scripts, dependencies, custom fields, locks, schemas, C2PA, IIIF, PREMIS-style records, preservation, and museum-grade catalogue material | Additional specialized legal, rights, VC/DID, EAS, or institution-specific modules can extend the same manifest and record model |
| Entropy | `StreamEntropyCoordinator`, Chainlink VRF provider, mock provider, and a v1 fallback decision for reviewed ARRNG or Pyth versus an explicit VRF-only exception | Other providers remain future adapters behind the same interface |

The launch docs may describe future extension points, but implementation
requirements must be labeled launch v1 or future module. A future module must
not become an implicit launch dependency merely because it appears in a design
appendix.

## Canonical Token Identity

Launch v1 uses explicit Core-owned token identity:

1. Core allocates globally unique ERC-721 `tokenId` values.
2. Core writes `tokenId -> collectionId`.
3. Core writes `tokenId -> collectionSerial`.
4. Core writes a non-reverting token identity bit used by royalty, metadata,
   burn, and audit reads. This is distinct from ERC-721 minted ownership
   existence; a reserved token identity is not transferable until final mint.
5. Core owns collection supply mode, status, max supply when applicable,
   minted-ever counts, burned counts, and next serial.
6. Core is the only source of truth for token existence and collection
   membership.

The current reserved range formula, `collectionId * 10_000_000_000`, is a
baseline implementation detail and should not be the launch v1 identity model.
If implementation chooses to retain namespaced ranges, it must still expose the
explicit mapping and token identity bit above, and the range capacity must not be
misrepresented as final collection supply.

Identity, burn audit, royalty, resolver, and router resolution reads must use
the explicit token identity bit and stored collection mapping, not ERC-721
ownership existence or `_requireMinted`. `tokenURI()` may keep normal ERC-721
metadata behavior for unminted tokens, but metadata routing must not infer
collection identity from token ID ranges.

Mint ordering must be:

1. Validate executor, payment, signature, gate, and mint policy.
2. Resolve primary revenue assignment.
3. Reserve or allocate token ID and write collection identity in Core.
4. Record or escrow revenue.
5. Consume mint ledger counters, authorization IDs, and any nullifiers.
6. Register entropy request context.
7. Mint or transfer to the final recipient only after required accounting and
   entropy registration are durable.

Any safe recipient callback must happen after the accounting and entropy steps
above. If the final recipient is a contract and callback timing would violate
that order, the launch design should mint to custody first or use an internal
mint followed by a separate safe transfer.

## Core Hook Budget

Core-native ERC-2981 is mandatory. Core may stay small only by moving other
logic out.

The launch implementation must provide one measured Core hook proof before the
implementation PR is accepted. The proof must be produced by:

```bash
forge build --sizes --via-ir --skip test --skip script --force
python scripts/check_contract_size_budget.py
```

The measured Core must include every mandatory launch hook with final call
shapes, not placeholders that omit calldata, returndata, storage, or external
call paths:

| Hook | Selector owner | Required caller/user |
| --- | --- | --- |
| `royaltyInfo(uint256,uint256)` | Core | Marketplaces and indexers |
| `supportsInterface(bytes4)` with ERC-721, ERC-4906, ERC-2981, and any accepted enumerable interface | Core | Marketplaces and indexers |
| `mintFromManager(...)` or equivalent manager-only mint boundary | Core | `StreamMintManager` only |
| token identity reads: collection ID, collection serial, token identity bit, burn audit as needed | Core | Resolver, router, indexers |
| metadata router pointer read and update | Core | Admin and `tokenURI()` path |
| minimal `tokenURI()` delegation to router | Core | ERC-721 metadata callers |
| collection metadata pointer read and update | Core | Router and admin tooling |
| entropy coordinator pointer read and update | Core | Mint and entropy lifecycle |
| entropy registration call during mint | Core to coordinator | Mint path |
| ERC-4906 event emission authority or Core-originated metadata refresh path | Core | Metadata/admin paths |

The implementation PR must report:

1. Previous `StreamCore` runtime size.
2. New `StreamCore` runtime size.
3. EIP-170 margin.
4. Whether the margin remains above the release floor and warning threshold.
5. Which non-essential Core logic was moved out if the first attempt failed.

Current CON-012 implementation proof:

1. Approved `StreamCore` bytecode-spend baseline: 22,184 bytes.
2. New measured `StreamCore` runtime: 24,154 bytes.
3. EIP-170 margin: 422 bytes.
4. The margin remains above the 384-byte release floor but below the 512-byte
   warning threshold.
5. The Core hook keeps the immediate manager mint ABI minimal and leaves
   beneficiary/payment evidence, batch commitments, operation events, and richer
   mint policy to the manager, ledger, sale adapter, and settlement satellites.

No launch v1 implementation may drop Core-native ERC-2981 to solve size
pressure. Refactor metadata, collection metadata, entropy, mint policy, or
other non-Core behavior out first.

## Royalty Resolver Contract

Core must not trust a resolver-supplied royalty amount. The resolver returns
receiver and bps; Core computes the amount:

```solidity
interface IStreamRevenueResolver {
    function royaltyReceiverAndBps(
        address core,
        uint256 tokenId,
        uint256 salePrice,
        uint256 mappedCollectionId,
        bool hasMappedCollection
    )
        external
        view
        returns (address receiver, uint16 royaltyBps);
}

bytes4 constant ROYALTY_RECEIVER_AND_BPS_SELECTOR = 0x54f77a09;
// royaltyReceiverAndBps(address,uint256,uint256,uint256,bool)
```

Core requirements:

1. Use an immutable or tightly governed resolver address and immutable
   `royaltyResolverGasLimit`.
2. Own an immutable `maxRoyaltyBps` cap, recommended at 1000 for launch unless
   a later accepted spec chooses another cap before deployment. The cap must
   not exceed 10,000. The resolver may enforce the same cap, but Core is the
   final guard.
3. Perform a `staticcall` with the explicit gas limit only when parent gas is
   sufficient under EIP-150's 63/64 forwarding rule plus a fixed return/decode
   overhead. If parent gas is insufficient, return `(address(0), 0)` without
   reverting.
4. Use capped assembly returndata handling, copy at most 64 bytes, and require
   `returndatasize() == 64`; undersized or oversized returndata returns
   `(address(0), 0)`.
5. Decode `(address receiver, uint16 royaltyBps)` from the 64-byte result.
6. Return `(address(0), 0)` when the call fails, returns malformed data,
   returns `receiver == address(0)`, returns `royaltyBps == 0`, returns
   `royaltyBps > maxRoyaltyBps`, or otherwise fails Core's cheap return-shape
   checks.
7. Compute `amount = mulDiv(salePrice, royaltyBps, 10_000)` or equivalent
   full-precision checked math in Core for every `uint256 salePrice`.
8. Never call `_requireMinted` from `royaltyInfo()`.
9. Treat fallback-to-zero as a monitorable incident, not as normal healthy
   operation.

The resolver may use Core token identity reads, but Core remains the authority
for token-to-collection mapping and existence.
The resolver must be deployed for exactly one Core and must revert or return
zero if the `core` argument differs from that bound Core. Core cannot prove that
logic from returndata alone; launch conformance must enforce it through
resolver code-hash approval, static analysis, tests, and by always passing
`address(this)`.
Core intentionally falls back to zero rather than a stale default receiver/bps
because a Core-local fallback would become a second royalty source of truth.
This accepts temporary royalty-disclosure loss during resolver incidents in
exchange for avoiding silent payment to a wrong or superseded wallet. Launch
readiness must include resolver-health probes that use the same selector, gas
cap, parent-gas precheck, returndata-size rule, and decode path as
`royaltyInfo()`.

Primary-sale deposits and escrow credits must account for the full received
amount. Split-wallet per-recipient floors may leave bounded rounding dust, but
that dust is not emergency surplus and has no ordinary sweep path in launch v1.
Any future final dust sweep requires its own accepted decommission spec.

## Assignment And Freeze State

Revenue and royalty assignment freezes use one canonical state machine:

```solidity
enum FreezeState {
    UNFROZEN,
    EXACT_FROZEN,
    INHERITED_FROZEN,
    GLOBAL_FROZEN,
    PERMANENT_FROZEN
}
```

Rules:

1. `UNFROZEN` assignments can be set or cleared by authorized policy admins.
2. `EXACT_FROZEN` freezes exactly one assignment key.
3. `INHERITED_FROZEN` freezes a scope and all realized descendants.
4. `GLOBAL_FROZEN` freezes an entire revenue class across default, collection,
   and token scopes.
5. `PERMANENT_FROZEN` cannot be loosened or unfrozen.
6. Timelocked loosening is allowed only for non-permanent freezes and must emit
   before/after policy hashes.
7. Token-scope assignments may be created only after Core has written the
   token's collection mapping and token identity bit. Otherwise the resolver must
   revert with a typed error such as `TokenCollectionUnmapped`.
8. Inherited-freeze descendant counters are keyed only by realized ancestry.
9. If the implementation cannot enumerate lower descendants, inherited freeze
   must either revert when descendant counters are nonzero or use a lazy epoch
   model that blocks later descendant mutation without enumeration.

## Domain Constants And Schema Versions

Every domain constant used in hashing must be recorded in one release artifact
or checked spec table before implementation. The table must include:

| Field | Meaning |
| --- | --- |
| Constant name | Solidity constant name |
| String preimage | Human-readable preimage |
| Hash value | Expected `keccak256` |
| Owner | Contract or module that owns the domain |
| Schema version | Numeric or string schema version |
| Inputs | Ordered `abi.encode` fields |

This table covers profile IDs, template IDs, materialized profile metadata,
sale context if retained, counter keys, counter value keys, policy hashes,
authorization IDs, nullifiers, entropy request keys, entropy seeds, metadata
record hashes, freeze manifests, schema commitments, public interface
selectors, and module capability selectors.
CI must include a checked test that recomputes every listed `keccak256`
preimage and fails on drift between Solidity constants, docs, and release
artifacts.

## Event Reconstruction

Every launch module must have an event-only reconstruction test plan. The
implementation test suite must include at least one harness that rebuilds the
following from emitted events and compares against direct reads:

1. Split profile entries and wallet address.
2. Revenue assignments and freeze state.
3. Escrow credits and flushes.
4. Per-recipient owed and released balances without reading aggregate owed
   counters, proving owed funds cannot be swept as surplus.
5. Mint counter values and authorization/nullifier consumption.
6. Entropy request, fulfillment, stale, failure, and retry state.
7. Collection metadata field values, locks, and schema/view commitments.
8. Metadata refresh events.

State reads remain useful for live tooling, but event replay must be sufficient
for long-lived indexers and archive reconstruction.

## Capability Beacons

Every launch satellite should expose a small capability surface:

```solidity
function streamModuleFamily() external pure returns (bytes32);
function streamModuleVersion() external pure returns (bytes32);
function streamModuleSchemaHash() external view returns (bytes32);
function streamModuleSupersedes() external view returns (address);
```

This mirrors the existing contract metadata release-hash posture and gives
future indexers a way to discover module families without frontend-specific
knowledge.
`streamModuleSupersedes()` returns the immediate predecessor in the same module
family, not the latest known descendant. Indexers reconstruct longer successor
chains by following the predecessor links and matching module family/schema
hashes.

## Launch Deferrals

The following are intentionally not launch v1 requirements:

1. Transfer-restricting royalty enforcement.
2. General onchain policy VM behavior.
3. Transfer of arbitrary museum, rights, legal, VC/DID, EAS, or
   institution-specific graph logic into `StreamCore`.
4. Multi-source entropy mixers, VDFs, timelock reveal, drand, Randcast, Supra,
   Witnet, or API3 provider implementations.
5. Same-transaction instant entropy fulfillment during mint.
6. Arbitrary sweep authority over split-wallet or escrow owed funds.

The following are v1 requirements or v1 launch decisions, but they must remain
outside Core:

1. ERC-20 primary-sale settlement for approved standard assets through a
   payment adapter or primary-sale settlement module. Non-standard ERC-20
   behavior remains unsupported unless a separate adapter spec accepts it.
2. C2PA, IIIF, and PREMIS-style records, richer preservation modules, and
   museum-grade metadata depth through collection metadata, preservation,
   attestation, and view satellites.
3. A reviewed entropy fallback decision: either ship a reviewed ARRNG or Pyth
   fallback provider, with ARRNG as the lower-complexity initial candidate, or
   record an explicit reviewed VRF-only launch exception in a checksum-covered
   `StreamEntropyLaunchDecision` manifest with coordinator failure behavior.
