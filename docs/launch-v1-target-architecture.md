# Stream Protocol v1 Specification

Specification status: Draft. This document follows
[`docs/spec-policy.md`](spec-policy.md); the decisions formerly tracked
inline are resolved by
[ADR 0009](adr/0009-protocol-v1-open-question-resolutions.md) and recorded
in [`docs/spec-open-questions.md`](spec-open-questions.md).

This document is the normative protocol v1 specification for 6529Stream. It
reconciles the revenue, mint, metadata, and entropy specs into one protocol
scope. 6529Stream is permanent infrastructure for the 6529 network: the
first production deployment is the permanent system, and these requirements
are the standard that deployment must satisfy — there is no lower
provisional bar for a first version and no deferred-quality tier after it.

The current repository contracts predate this specification and do not yet
conform. [`docs/launch-conformance-matrix.md`](launch-conformance-matrix.md)
is the enforcement point: it blocks any production deployment on the full
gate set, and [`docs/architecture.md`](architecture.md) maps the as-built
baseline honestly until the implementation conforms.

## Protocol v1 Scope

Protocol v1 is the smallest auditable system that remains extensible over a
50+ year contract life:

| Area | Protocol v1 requirement | Extension surface (Permanent from v1) |
| --- | --- | --- |
| Core | ERC-721 ownership, token identity, collection identity, supply invariants, minimal router/resolver/coordinator hooks, and Core-native ERC-2981 | None. Core gains no new semantics after deployment; no mutable policy or rendering logic in Core. Changing Core surfaces means a successor Core line |
| Revenue | Immutable split profiles, deterministic split wallets, resolver assignments, native ETH primary settlement, approved-standard ERC-20 primary settlement through outside-Core adapters, passive royalty receipt, and native/approved-asset revenue escrow | New settlement or recovery adapters are new Replaceable modules with their own accepted specs; non-standard ERC-20 behavior stays excluded until a spec accepts it |
| Royalties | Core-native ERC-2981 that calls a resolver for receiver and bps, then computes amount in Core | Resolver implementations rotate behind the frozen resolver interface; marketplace registry overrides remain integration extras outside the protocol |
| Minting | `StreamMintManager` policy plus `StreamMintLedger` accounting with many counters, aggregate-only consumption, signed tickets, and module-checked gates/resolvers | New counter resolvers and gates register through the frozen module registry and gate/resolver interfaces |
| Metadata | `StreamMetadataRouter`, `StreamRendererV1`, `StreamCollectionMetadata`, and genesis preservation/attestation/view satellites for identity, rights, media, scripts, dependencies, custom fields, locks, schemas, C2PA, IIIF, PREMIS-style records, preservation, and museum-grade catalogue material | Additional legal, rights, VC/DID, EAS, or institution-specific modules extend the same Permanent manifest and record model |
| Entropy | `StreamEntropyCoordinator`, Chainlink VRF primary provider, one reviewed fallback provider (ARRNG preferred, Pyth as the reviewed alternate), and a mock provider for local validation; VRF-only deployment is not conformant (ADR 0009 decision 21) | New providers are adapters behind the same Permanent provider interface, added through registry approval and provider epochs |

Every implementation requirement in the Stream specs carries a permanence
class as defined in [`docs/spec-policy.md`](spec-policy.md): Permanent,
Replaceable, or Operational. Spec documents may describe extension points,
but a module outside the genesis deployment set must never become an
implicit dependency of a Permanent or genesis surface merely because it
appears in a design appendix.

## Canonical Token Identity

Protocol v1 uses explicit Core-owned token identity. This is Permanent
semantics:

1. Core allocates sequential global ERC-721 `tokenId` values from one
   counter starting at 1 (ADR 0009 decision 1).
2. Core writes `tokenId -> collectionId`.
3. Core writes `tokenId -> collectionSerial`.
4. Core exposes a non-reverting authoritative identity read — the
   `mappingExists` result of `tokenCollectionIdentity` — used by royalty,
   metadata, burn, and audit reads. This is distinct from ERC-721 minted
   ownership existence; a reserved token identity is not transferable until
   final mint. The read semantics are Permanent; whether Core stores a
   discrete identity flag or derives it from ownership, burned-token audit
   state, and prepared-mint state is implementation-defined, provided the
   read is authoritative and never reverts.
5. Core owns collection supply mode, status, max supply when applicable,
   minted-ever counts, burned counts, and next serial.
6. Core is the only source of truth for token existence and collection
   membership.

Token ID arithmetic is never authority and carries no meaning. The reserved
range formula in the baseline code, `collectionId * 10_000_000_000`, must be
removed from the allocator (ADR 0009 decision 1): token IDs are sequential
and global, `collectionId` and `collectionSerial` are stored explicitly in
the token identity record, and no serial or collection value may be derived
from the shape of a token ID. Packing `collectionId` and `collectionSerial`
into one storage slot with bounded widths is an implementation choice; the
read surface returns `uint256` values.

Identity, burn audit, royalty, resolver, and router resolution reads must
use the authoritative identity read and stored collection mapping, not
ERC-721 ownership existence or `_requireMinted`. `tokenURI()` may keep
normal ERC-721 metadata behavior for unminted tokens, but metadata routing
must not infer collection identity from token ID ranges.

Mint ordering must be:

1. Validate executor, payment, signature, gate, and mint policy.
2. Resolve primary revenue assignment.
3. Reserve or allocate token ID and write collection identity in Core.
4. Record or escrow revenue.
5. Consume mint ledger counters, authorization IDs, and any nullifiers.
6. Register entropy request context.
7. Mint or transfer to the final recipient only after required accounting
   and entropy registration are durable.

Any safe recipient callback must happen after the accounting and entropy
steps above. If the final recipient is a contract and callback timing would
violate that order, the implementation should mint to custody first or use
an internal mint followed by a separate safe transfer.

## Core Hook Budget

Core-native ERC-2981 is mandatory. Core may stay small only by moving other
logic out.

The implementation must provide one measured Core hook proof before the
implementation PR is accepted. The proof must be produced by:

```bash
forge build --sizes --via-ir --skip test --skip script --force
python scripts/check_contract_size_budget.py
```

The measured Core must include every mandatory hook with final call shapes,
not placeholders that omit calldata, returndata, storage, or external call
paths:

| Hook | Selector owner | Required caller/user |
| --- | --- | --- |
| `royaltyInfo(uint256,uint256)` | Core | Marketplaces and indexers |
| `supportsInterface(bytes4)` with ERC-721, ERC-4906, ERC-2981, and any accepted enumerable interface | Core | Marketplaces and indexers |
| `mintFromManager(...)` or equivalent manager-only mint boundary | Core | `StreamMintManager` only |
| token identity reads: collection ID, collection serial, authoritative identity read, burn audit as needed | Core | Resolver, router, indexers |
| metadata router pointer read and update | Core | Admin and `tokenURI()` path |
| minimal `tokenURI()` delegation to router | Core | ERC-721 metadata callers |
| minimal `contractURI()` delegation to the contract-metadata satellite (ADR 0009 decision 4) | Core | Marketplaces and indexers (ERC-7572) |
| collection metadata pointer read and update | Core | Router and admin tooling |
| entropy coordinator pointer read and update | Core | Mint and entropy lifecycle |
| entropy registration call during mint | Core to coordinator | Mint path |
| Core-originated ERC-4906 refresh emitters callable by authorized satellites (ADR 0009 decision 5) | Core | Metadata router, finality registry, entropy lifecycle |

The implementation PR must report:

1. Previous `StreamCore` runtime size.
2. New `StreamCore` runtime size.
3. EIP-170 margin.
4. Whether the margin remains above the release floor and warning threshold.
5. Which non-essential Core logic was moved out if the first attempt failed.

The governing size rule is the conformance-matrix headroom target
(ADR 0009 decision 2): `StreamCore` runtime must retain at least 2,000
bytes of EIP-170 margin at the deployment gate, proven by one
post-extraction measured build that includes every mandatory hook in the
table above. The bytecode-spend baseline and exception ledger in
`release-artifacts/contracts.json` remain the pre-deployment development
control; interim exceptions cannot survive to the deployment gate.

Implementation evidence (non-normative). Measured Core hook proof at the
time of the CON-012 slice:

1. Approved `StreamCore` bytecode-spend baseline: 22,184 bytes.
2. New measured `StreamCore` runtime: 24,150 bytes.
3. EIP-170 margin: 426 bytes.
4. The margin remains above the 384-byte release floor but below the
   512-byte warning threshold.
5. The Core hook keeps the immediate manager mint ABI minimal and leaves
   beneficiary/payment evidence, batch commitments, operation events, and
   richer mint policy to the manager, ledger, sale adapter, and settlement
   satellites.

Implementation evidence (non-normative). CON-013 slice:

1. `StreamMintLedger` is release-tracked as the first outside-Core durable
   mint accounting satellite.
2. The ledger supports owner-authorized deployed-contract writers, one
   active registered `policyHash` per `(manager, collectionId, phaseId)`,
   deployment-safe static counter policies, canonical manager-scoped
   value-key derivation, cap-checked counter consumption, durable values
   across policy re-registration, and manager-scoped authorization replay
   protection.
3. Resolver caps/deltas, custom gates, callable nullifier systems, sale/drop
   routing, payment collection, and Core mint execution remain outside this
   ledger-only slice.

Implementation evidence (non-normative). CON-014 slice:

1. `StreamMintManager` is release-tracked as the outside-Core phase policy
   and prepared-mint execution surface paired with `StreamMintLedger`.
2. The manager supports owner-configured static phase policies, ordered
   counters, executor allowlists, pause/start/end guards, active
   `policyHash` registration in the ledger, bounded batch counter
   consumption construction, ledger cap enforcement with nonzero
   authorization IDs, stale-policy rejection through a required expected
   policy hash, and Core prepare/complete execution.
3. Dynamic resolver counters, custom gates, callable nullifiers,
   primary-sale settlement routing, existing drop/auction routing, and
   royalty resolver integration remain follow-up slices.

No conformant implementation may drop Core-native ERC-2981 to solve size
pressure. Refactor metadata, collection metadata, entropy, mint policy, or
other non-Core behavior out first.

## Royalty Resolver Contract

Core must not trust a resolver-supplied royalty amount. The resolver returns
receiver and bps; Core computes the amount. The interface and selector are
Permanent:

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
2. Own an immutable `maxRoyaltyBps` cap of 1000 (ADR 0009 decision 7). The
   resolver may enforce the same cap, but Core is the final guard.
3. Perform a `staticcall` with the explicit gas limit only when parent gas
   is sufficient under EIP-150's 63/64 forwarding rule plus a fixed
   return/decode overhead. If parent gas is insufficient, return
   `(address(0), 0)` without reverting.
4. Use capped assembly returndata handling, copy at most 64 bytes, and
   require `returndatasize() == 64`; undersized or oversized returndata
   returns `(address(0), 0)`.
5. Decode `(address receiver, uint16 royaltyBps)` from the 64-byte result.
6. Return `(address(0), 0)` when the call fails, returns malformed data,
   returns excess data, returns `receiver == address(0)`, returns
   `royaltyBps == 0`, returns `royaltyBps > maxRoyaltyBps`, or otherwise
   fails Core's cheap return-shape checks.
7. Compute `amount = mulDiv(salePrice, royaltyBps, 10_000)` or equivalent
   full-precision checked math in Core for every `uint256 salePrice`.
8. Never call `_requireMinted` from `royaltyInfo()`.
9. Treat fallback-to-zero as a monitorable incident, not as normal healthy
   operation.

The resolver may use Core token identity reads, but Core remains the
authority for token-to-collection mapping and existence.
The resolver must be deployed for exactly one Core and must revert or return
zero if the `core` argument differs from that bound Core. Core cannot prove
that logic from returndata alone; deployment conformance must enforce it
through resolver code-hash approval, static analysis, tests, and by always
passing `address(this)`.
Core intentionally falls back to zero rather than a stale default
receiver/bps because a Core-local fallback would become a second royalty
source of truth. This accepts temporary royalty-disclosure loss during
resolver incidents in exchange for avoiding silent payment to a wrong or
superseded wallet. Deployment readiness must include resolver-health probes
that use the same selector, gas cap, parent-gas precheck, returndata-size
rule, and decode path as `royaltyInfo()`.

Primary-sale deposits and escrow credits must account for the full received
amount. Split-wallet per-recipient floors may leave bounded rounding dust,
but that dust is not emergency surplus and has no ordinary sweep path in
protocol v1. A final dust sweep, if ever wanted, requires its own accepted
decommission spec; none exists in v1.

## Assignment And Freeze State

Revenue and royalty assignment freezes use one canonical state machine.
Freeze semantics are Permanent:

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
4. `GLOBAL_FROZEN` freezes an entire revenue class across default,
   collection, and token scopes; a deployment-wide global freeze also blocks
   creation of new revenue classes (ADR 0009 decision 8).
5. `PERMANENT_FROZEN` cannot be loosened or unfrozen.
6. Timelocked loosening is allowed only for non-permanent freezes and must
   emit before/after policy hashes.
7. Token-scope assignments may be created only after Core has written the
   token's collection mapping and authoritative identity. Otherwise the
   resolver must revert with a typed error such as `TokenCollectionUnmapped`.
8. Inherited-freeze descendant counters are keyed only by realized ancestry.
9. If the implementation cannot enumerate lower descendants, inherited
   freeze must either revert when descendant counters are nonzero or use a
   lazy epoch model that blocks later descendant mutation without
   enumeration.

## Domain Constants And Schema Versions

Every domain constant used in hashing is Permanent and must be recorded in
one release artifact or checked spec table before implementation. The table
must include:

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

### StreamMintManager Domain Constants

The CON-014 manager slice records these static phase policy domains in this
checked spec table. `operationId` values are derived from
`OPERATION_DOMAIN` through `operationRoot` and then bind
`operationRoot`, `operationNonce`, `tokenIndex`, `tokenDataHash`, and `salt`.

| Constant name | String preimage | Hash value | Owner | Schema version | Inputs |
| --- | --- | --- | --- | --- | --- |
| `POLICY_DOMAIN` | `6529STREAM_MINT_MANAGER_POLICY_V1` | `0xc3928662f6dd05b602479c5be22fc277fb478ed810da87911760b8087dee9ddd` | `StreamMintManager` | `1` | `POLICY_DOMAIN; uint256(block.chainid); address(this); address(mintLedger); SCHEMA_VERSION; collectionId; phaseId; _phaseConfigHash(config); _orderedCounterConfigHash(collectionId, phaseId); _executorSetHash(collectionId, phaseId)` |
| `PHASE_CONFIG_DOMAIN` | `6529STREAM_MINT_MANAGER_PHASE_CONFIG_V1` | `0x1c5e8dc70f273da26541082173dc2bd209ef4595e274f79551a7d9087fb7bef1` | `StreamMintManager` | `1` | `PHASE_CONFIG_DOMAIN; config.paused; config.startTime; config.endTime; config.maxBatchQuantity; config.configHash; config.metadataHash` |
| `COUNTER_CONFIG_DOMAIN` | `6529STREAM_MINT_MANAGER_COUNTER_CONFIG_V1` | `0x3d47766144eb889472dec1a66a3ddf3da1b3025f01a572a61f342c3730bd6577` | `StreamMintManager` | `1` | `COUNTER_CONFIG_DOMAIN; counterId; config.enabled; config.keyMode; config.capMode; config.deltaMode; config.staticCap; config.staticIncrement; config.counterConfigHash` |
| `EXECUTOR_SET_DOMAIN` | `6529STREAM_MINT_MANAGER_EXECUTOR_SET_V1` | `0x4dad062b9c5507613f6c9369756e27d94df429cf5650fe9b9d375032d1d5397a` | `StreamMintManager` | `1` | `EXECUTOR_SET_DOMAIN; sorted phase executor addresses` |
| `SUBJECT_DOMAIN` | `6529STREAM_MINT_COUNTER_SUBJECT_V1` | `0x5028c63429e55461bc7922fe859628bd9266f6b029ad3e4124268a4877151a05` | `StreamMintManager` | `1` | `SUBJECT_DOMAIN; uint256(block.chainid); address(mintLedger); keyMode; constant mode: collectionId, phaseId, counterId; address modes: account; context mode: contextHash` |
| `RESOLUTION_DOMAIN` | `6529STREAM_MINT_COUNTER_RESOLUTION_V1` | `0x3503c231385e25d95f9119b4e72118f42b0c7c1e7854b990a249a44c64f6a196` | `StreamMintManager` | `1` | `RESOLUTION_DOMAIN; uint256(block.chainid); address(this); address(mintLedger); collectionId; phaseId; counterId; subjectKey; tokenIndex; counterConfigHash` |
| `OPERATION_DOMAIN` | `6529STREAM_PREPARED_MINT_OPERATION_V1` | `0x7ae97476527ee55636a9869c4580294d9b3d15d19fa357df5e2e41301584d0d9` | `StreamMintManager` | `1` | `OPERATION_DOMAIN; uint256(block.chainid); address(this); address(core); address(mintLedger); collectionId; phaseId; policyHash; authorizationId; requestCommitmentHash(payer, authorizer, initialRecipientsHash, beneficiariesHash, tokenDataHash, saltsHash); contextHash; msg.sender; operationNonce; quantity` |

## Event Reconstruction

Every genesis module must have an event-only reconstruction test plan. The
implementation test suite must include at least one harness that rebuilds
the following from emitted events and compares against direct reads:

1. Split profile entries and wallet address.
2. Revenue assignments and freeze state.
3. Escrow credits and flushes.
4. Per-recipient owed and released balances without reading aggregate owed
   counters, proving owed funds cannot be swept as surplus.
5. Mint counter values and authorization/nullifier consumption.
6. Entropy request, fulfillment, stale, failure, and retry state.
7. Collection metadata field values, locks, and schema/view commitments.
8. Metadata refresh events.

State reads remain useful for live tooling, but event replay must be
sufficient for long-lived indexers and archive reconstruction.

## Module Identity Surface

Every genesis satellite must expose the canonical module identity surface
(ADR 0009 decision 3), defined once in
[`stream-long-term-architecture.md`](stream-long-term-architecture.md)
(Satellite Versioning) and golden-tested by selector:

```solidity
function streamModuleType() external pure returns (bytes32);
function streamModuleVersion() external pure returns (bytes32);
function streamModuleInterfaceId() external pure returns (bytes4);
function streamModuleSchemaHash() external view returns (bytes32);
function streamModuleSupersedes() external view returns (address);
function streamModuleCodeHash() external view returns (bytes32);
function streamModuleDeploymentManifestHash() external view returns (bytes32);
function streamModuleManifest() external view returns (string memory uri, bytes32 hash);
```

This mirrors the existing contract metadata release-hash posture and gives
future indexers a way to discover module families without frontend-specific
knowledge.
`streamModuleSupersedes()` returns the immediate predecessor in the same
module family, not the latest known descendant. Indexers reconstruct longer
successor chains by following the predecessor links and matching module
type/schema hashes.

## Protocol v1 Exclusions

The following are excluded from protocol v1. Exclusion is intentional
absence, not deferral: the semantics below do not exist in v1, and adding
any of them later requires a new accepted module spec against the frozen
extension mechanisms, or a successor Core line where Permanent surfaces are
affected.

1. Transfer-restricting royalty enforcement.
2. General onchain policy VM behavior.
3. Transfer of arbitrary museum, rights, legal, VC/DID, EAS, or
   institution-specific graph logic into `StreamCore`.
4. Multi-source entropy mixers, VDFs, timelock reveal, drand, Randcast,
   Supra, Witnet, or API3 provider implementations.
5. Same-transaction instant entropy fulfillment during mint.
6. Arbitrary sweep authority over split-wallet or escrow owed funds.

## Genesis Requirements Outside Core

The following are protocol v1 requirements or ratified genesis decisions,
but they must remain outside Core:

1. ERC-20 primary-sale settlement for approved standard assets through a
   payment adapter or primary-sale settlement module. Non-standard ERC-20
   behavior remains unsupported unless a separate adapter spec accepts it.
2. C2PA, IIIF, and PREMIS-style records, richer preservation modules, and
   museum-grade metadata depth through collection metadata, preservation,
   attestation, and view satellites.
3. Dual entropy providers (ADR 0009 decision 21): Chainlink VRF primary
   plus one reviewed fallback provider, with ARRNG as the preferred
   candidate and Pyth as the reviewed alternate. A VRF-only deployment is
   not conformant. The checksum-covered `StreamEntropyLaunchDecision`
   manifest records which fallback shipped, its review evidence, and the
   coordinator failure posture.
4. The full scoped-finality surface (ADR 0009 decision 6):
   `StreamArtworkFinalityRegistry` ships with all five scopes —
   `COLLECTION`, `TOKEN`, `RELEASE`, `SEASON`, and `VIEW` — fully
   specified, fully tested, and gate-covered, trading audit surface for
   permanent flexibility by protocol-owner decision.
