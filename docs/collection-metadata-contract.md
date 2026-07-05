# Collection Metadata Contract

Specification status: Draft. This document follows
[`docs/spec-policy.md`](spec-policy.md); its formerly open decisions are
resolved by [ADR 0009](adr/0009-protocol-v1-open-question-resolutions.md)
and recorded in the `Resolved` section of
[`docs/spec-open-questions.md`](spec-open-questions.md). It is amended by
[ADR 0010](adr/0010-world-class-spec-pass.md): record-family-scoped
authorization replaces the CON-015 whole-module exception, the museum
object dossier (pinned subject identity, owner records, fixity program,
artist intent, C2PA binding, IIIF profile, citation profile) enters
genesis, and permanence hardening adds token content roots, record-chain
accumulators, onchain catalog bytes, and SSTORE2 script scale. It is
further amended by
[ADR 0011](adr/0011-world-class-pass-round-2.md): onchain bytes mean
contract storage, execution environments are archived artifacts with
pinned re-render acceptance modes, museum schemas are pinned (registrar
records, PREMIS crosswalk, rights, interviews), an operator-independent
preservation lane and a metadata ERC-1271 gas parameter enter genesis,
and artists hold a standing content veto between mint and finality. It
is further amended by
[ADR 0012](adr/0012-world-class-pass-round-3.md): the sold-token
preservation lane joins the fixity program, the record write gains a
payload-bytes carrier and every payload host a state-readable pointer
registry, owner-record and independent-lane nonces become unordered with
revocation and replay views, the independent lane gains exhibition and
condition types, and the museum dossier completes (ownership-provenance
chain, tombstone schema, BagIt/OCFL packaging, rights floor for platform
works, equivalence attestor class, drill outcomes, gated registrar
tooling, environment remediation).

This document specifies moving collection metadata storage out of
`StreamCore` into a dedicated `StreamCollectionMetadata` contract.
6529Stream is permanent infrastructure for the 6529 network; the first
production deployment is the permanent system. Requirements here are
classified by permanence class per the spec policy — Permanent interfaces,
Replaceable genesis modules, Operational practice — not by delivery phase.

`StreamCore` should remain the canonical ERC-721 contract; per-transfer
`ERC721Enumerable` storage is removed from Core — `totalSupply()` stays,
and enumeration derives from `Transfer` events (ADR 0012 decision T10).
Collection identity, ownership, transfers, approvals,
balances, and token existence stay in Core. Human-facing collection metadata,
script manifests, dependency configuration, and long-lived collection display
state should live outside Core.

## Design Summary

```text
StreamCore
  - ERC-721 ownership and totalSupply()
  - collection ID allocation
  - token to collection identity
  - collection supply mode and status
  - collection-local token serial assignment
  - minimal pointer to collection metadata contract
  - minimal pointer to metadata router

StreamCollectionMetadata
  - collection descriptive metadata
  - artist identity mirror and state-bound artist attestations
    (authority: docs/stream-artist-authority.md)
  - offchain base URI config
  - media manifest and content hash commitments
  - onchain script manifest
  - dependency manifest
  - schema URI/hash commitments
  - arbitrary typed key/value metadata
  - one-way field and collection locks
  - metadata update events

StreamMetadataRouter
  - tokenURI mode resolution
  - renderer resolution
  - pending/offchain/onchain/hybrid routing
  - calls StreamCollectionMetadata for collection metadata

StreamRendererV1
  - JSON construction
  - HTML construction
  - script and dependency assembly from manifests
```

This contract is not a renderer. It is the durable metadata source that
renderers and indexers can read.

Recommended companion responsibilities:

1. `StreamSchemaRegistry`: schema IDs, schema URIs, schema hashes,
   supersession, and schema status.
2. `StreamCollectionSnapshot`: canonical collection manifest snapshots and
   revision-oriented publication events. This can be a module or event surface,
   not necessarily a separate genesis contract.
3. `StreamCollectionAttestations`: artist, curator, estate, institution,
   preservation, C2PA, EAS, VC, EIP-712, and ERC-1271-compatible attestation
   records, including the operator-independent preservation lane
   [CMC-INDEPENDENT-ATTESTOR]. This can start inside
   `StreamCollectionMetadata` and split out if it grows.
4. `StreamPreservationRecords`: archive receipts, PREMIS-style preservation
   records, fixity checks, storage/migration events, and media-provenance
   references. This should remain outside Core even if implemented at genesis.
5. `StreamOwnerRecords`: the owner-writable registrar surface — accession,
   condition report, exhibition, loan, deaccession, and citation records
   written by the current token owner (ADR 0010 decision 6). Genesis module,
   specified in Owner Records below.

Artist identity, acceptance, collaborator, consent-mode, sanction, estate,
and dispute authority is owned by the artist authority registry specified in
[`docs/stream-artist-authority.md`](stream-artist-authority.md) (ADR 0010 decision 2). This contract
mirrors and displays those states; it never defines a second artist
authority.

## Collection Knowledge System

The long-term target is not just a larger collection struct. It is a collection
knowledge system that can keep serving artists, collectors, museums,
marketplaces, agents, and future renderers for decades.

The architecture should have four layers:

1. Core facts: collection existence, supply mode, status, token-to-collection
   assignment, collection-local serials, mint counts, burns, and freezes. These
   remain in `StreamCore`.
2. Typed public metadata: identity, people, media, URIs, rights, display, and
   other fields that wallets, marketplaces, 6529 frontends, and renderers should
   understand from genesis.
3. Extensible knowledge graph: arbitrary `bytes32` keys, field types, hashes,
   URIs, schemas, attestations, view manifests, and open vocabularies that can
   grow without redeploying Core or hardcoding labels forever.
4. Preservation and provenance layer: archive manifests, fixity receipts,
   content-addressed mirrors, source/provenance attestations, exhibition and
   conservation records, and schema snapshots that let the collection remain
   intelligible long after today's frontend stack changes.

The key design rule: Core owns token truth, while `StreamCollectionMetadata`
owns collection meaning. Renderers, agents, and indexers can compose both
without either contract becoming a monolith.

## Research Signals

This architecture should deliberately borrow from existing public standards
without forcing `StreamCore` to implement all of them.

External signals to use:

1. [ERC-4906](https://eips.ethereum.org/EIPS/eip-4906): standard
   `MetadataUpdate` and `BatchMetadataUpdate` events for marketplace refresh.
2. [ERC-7160](https://eips.ethereum.org/EIPS/eip-7160): multiple metadata URIs
   per token and the idea that one view may be primary while others remain
   discoverable.
3. [ERC-5773](https://eips.ethereum.org/EIPS/eip-5773): context-dependent
   multi-asset output for different display environments.
4. [ERC-7401](https://eips.ethereum.org/EIPS/eip-7401): parent/child NFT
   relationship modeling, useful as inspiration for token-linked archive or
   companion-asset modules added through separate accepted specs, without
   changing Stream's ERC-721 ownership model.
5. [ERC-7496](https://eips.ethereum.org/EIPS/eip-7496): dynamic onchain traits
   when another contract needs enforceable traits rather than ordinary display
   attributes.
6. [ERC-6596](https://eips.ethereum.org/EIPS/eip-6596): cultural and
   historical asset metadata, especially context, provenance, institutions,
   discovery, and interoperability.
7. [IPFS content addressing](https://docs.ipfs.eth.link/concepts/content-addressing/):
   content-addressed payloads and CIDs for durable references.
8. [PREMIS](https://www.loc.gov/standards/premis/): preservation metadata
   organized around Objects, Events, Agents, and Rights.
9. [IIIF Presentation API](https://iiif.io/api/presentation/3.0/): museum-grade
   manifests, canvases, annotation pages, and annotations for visual culture.
10. [W3C Verifiable Credentials](https://www.w3.org/TR/vc-data-model-2.0/),
    [DIDs](https://www.w3.org/TR/did-1.1/),
    [C2PA](https://c2pa.org/),
    [EIP-712](https://eips.ethereum.org/EIPS/eip-712), and
    [ERC-1271](https://eips.ethereum.org/EIPS/eip-1271): identity,
    provenance, signatures, attestations, and contract-wallet validation.

The Stream interpretation is: store minimal authoritative commitments onchain,
emit rich events, and let manifests carry detailed schemas. The NFT contract
should know that serious preservation/provenance data exists, where it lives,
how to verify it, and what schema interprets it. It should not try to store a
museum archive directly in ERC-721 Core.

## Current Implementation Baseline

This section is non-normative implementation evidence per
[`docs/spec-policy.md`](spec-policy.md); it records point-in-time as-built
state and does not weaken any requirement in this spec.

Current `origin/main` already includes a safer metadata helper layer and
metadata refresh events, but `StreamCore` still stores collection display and
script metadata directly:

```solidity
struct collectionInfoStructure {
    string collectionName;
    string collectionArtist;
    string collectionDescription;
    string collectionWebsite;
    string collectionLicense;
    string collectionBaseURI;
    string collectionLibrary;
    bytes32 collectionDependencyScript;
    string[] collectionScript;
}
```

Core also exposes broad tuple getters and mutation functions:

1. `createCollection(...)` writes all descriptive fields and script chunks.
2. `updateCollectionInfo(...)` mutates descriptive fields, base URI, or one
   script chunk depending on magic indexes.
3. `retrieveCollectionInfo(...)` returns six strings.
4. `retrieveCollectionLibraryAndScript(...)` returns library, dependency ID,
   and all script chunks.

The current implementation has better validation than the original prototype:
collection text fields, base URIs, script chunk sizes, raw attributes, generated
token URI size, dependency registry markers, and randomizer lifecycle checks are
guarded through `StreamMetadataRenderer`. Metadata changes can also emit
ERC-4906-compatible refresh events.

Those improvements should be preserved. The remaining problem is boundary
placement: Core still mixes ERC-721 ownership state with long-lived collection
meaning, renderer policy, artist display state, script storage, dependency
configuration, and preservation concerns. It also makes Core carry dynamic
string and dynamic array storage that is expensive in bytecode and likely to
grow over a 50-year metadata roadmap.

The scratch compile showed that after renderer extraction, moving collection
metadata storage out saves about `3.6 KB` more runtime bytecode. Renderer
extraction plus collection metadata extraction saved about `7.4 KB` total.
These numbers should be remeasured against current `origin/main`, but the
boundary conclusion remains unchanged: collection metadata and scripts should
not live in ERC-721 Core.

## Goals

1. Keep collection metadata out of the ERC-721 core.
2. Keep Core-native `tokenURI()` by routing through the metadata router.
3. Support a 50-year metadata model with versioned schemas and open
   vocabulary fields.
4. Avoid hardcoded forever-labels or forever-field lists.
5. Make field mutability explicit and freeze-aware.
6. Make collection scripts and dependencies first-class manifests.
7. Emit enough events for indexers, marketplaces, and 6529 frontends to
   reconstruct collection metadata history.
8. Give renderers a clean read API without exposing Core storage layout.
9. Support fixed-size, capped-open, and uncapped-open collections.
10. Support storage pluralism for scripts, dependencies, media, and schemas
    without requiring future Core changes.
11. Support snapshots, revision trails, and archive receipts for long-term
    stewardship.
12. Support multiple canonical views of the same collection without changing
    the default marketplace `tokenURI()` path.
13. Keep the genesis implementation simple enough to audit.

## Non-Goals

1. `StreamCollectionMetadata` does not mint, burn, transfer, or approve NFTs.
2. It does not replace `StreamCore` as the ERC-721 contract.
3. It does not enforce primary-sale or royalty payments.
4. It does not decide royalty splits.
5. It does not need to be an upgradeable proxy.
6. It does not store marketplace secrets or private data.
7. It does not rely on hardcoded field labels as a complete permanent schema.

## V1 Scope Reduction

The collection metadata architecture is a 50-year knowledge system, but the v1
ABI must stay small enough to audit. The genesis contract should implement the
first column, treat the second column as schema/manifest guidance, and use the
third column as v1 outside-Core companion surface where the main v1 ABI would
become too large.

| V1 ABI | Schema/Manifest Guidance | V1 Outside-Core Companion Surface |
|---|---|---|
| `CollectionIdentity` | PREMIS object/event/agent/right payload schemas | `StreamSchemaRegistry` |
| `CollectionPeople` | C2PA assertion, ingredient, action schemas | `StreamCollectionAttestations` |
| `CollectionMedia` | IIIF Presentation manifests | `StreamPreservationRecords` |
| `CollectionURIs` | detailed fixity reports | typed C2PA verifier/registry |
| `CollectionRights` | rights policy text and legal terms | rights-policy resolver, if ever accepted |
| `CollectionDisplay` | accessibility, gallery, print, AR/VR view documents | specialized view registry |
| `ScriptManifest` with inline chunks | full script source maps/build manifests | dependency mirroring registry |
| `DependencyManifest` with dependency-registry source | detailed dependency SBOMs | dependency replacement/recovery registry |
| `MediaManifest` | high-resolution master manifests | media preservation registry |
| generic `CollectionField` | arbitrary field display schemas | field schema registry |
| generic `CollectionRecord` | PREMIS, C2PA, IIIF, fixity, relationship records | typed preservation modules |
| field locks | operator UX copy and legal disclaimers | terminal legal/estate registry |
| append-only snapshots | museum/catalogue manifests | snapshot attestation network |
| revision/events | event catalog JSON | indexer checkpoint service |

Protocol v1 must support C2PA, IIIF, PREMIS-style, fixity,
media-relationship, archive, owner-registrar, and museum/catalogue records as
real metadata and preservation surfaces. The default implementation path is
`CollectionRecord` plus `schemaId`, `HashRef`, URI commitments, and genesis
companion satellites: `StreamPreservationRecords`,
`StreamCollectionAttestations`, `StreamCollectionViews`, and
`StreamOwnerRecords`. Typed PREMIS/C2PA/IIIF structs can be promoted into a
companion ABI when they pass the same function-count, event-reconstruction,
schema-hash, and audit-scope gates; they must not be embedded in `StreamCore`.

The genesis implementation slice should keep the audited onchain ABI
compact by storing schema-bound generic records instead of one setter per
museum field. In that shape, `recordType` identifies typed v1 groups such
as identity, rights, IIIF views, C2PA references, catalogue records, script or
media manifests, and custom-gate metadata; `schemaId`, URI, content hash,
auxiliary hash, revision, snapshot, and event payloads provide the stable
reconstruction surface. Field-specific ABIs remain candidates for companion
satellites only after they clear the aggregate function-count and audit-scope
ceiling.

Genesis metadata surfaces must also have a hard aggregate function-count,
bytecode, and audit-scope ceiling across `StreamCollectionMetadata` and any v1
metadata companion satellites. Before audit handoff, the release manifest must
publish the external/public function count, interface IDs, selectors, owner
subsystem, runtime bytecode size, module manifest, and code hash for
`StreamCollectionMetadata`, `StreamPreservationRecords`,
`StreamCollectionAttestations`, `StreamCollectionViews`, and
`StreamOwnerRecords`. The initial aggregate ceiling is 80 external/public
functions across those genesis metadata surfaces, including inherited views,
with a v1 soft target of 60 or fewer.
Exceeding the soft target requires an audit-scope note; exceeding the hard
ceiling requires a new ADR that either removes v1 surface or moves a
responsibility to a separate accepted module. This keeps "world-class metadata"
from quietly turning into an unauditable cluster of monoliths.
The release checker for the deployment candidate must fail if the aggregate
function count, selector catalog, bytecode report, or code-hash manifest for
these metadata surfaces is missing or exceeds the accepted ceiling.

## Core Boundary

Core should keep the collection facts required to preserve token behavior:

```solidity
enum CollectionSupplyMode {
    FIXED,
    CAPPED_OPEN,
    UNCAPPED_OPEN
}

enum CollectionStatus {
    ACTIVE,
    PAUSED,
    CLOSED
}

struct CoreCollection {
    bool exists;
    CollectionSupplyMode supplyMode;
    CollectionStatus status;
    bool hasMaxSupply;
    uint256 maxSupply;
    uint256 mintedEver;
    uint256 burned;
    uint256 nextSerial;
    bool frozen;
}
```

This is illustrative, not a required storage layout. The point is the boundary:

Core keeps facts needed for minting, burning, token identity, collection-local
serial assignment, collection status, and collection existence.
`StreamCollectionMetadata` keeps metadata, scripts, dependencies, artist display
state, and display freezes.

`maxSupply` is required only when `hasMaxSupply` is true. A collection can be
created without knowing its final size. This is required for permanent Stream
subcollections such as an ongoing photographic series where the artist does not
know how many works will be added over time.

Core allocates sequential global ERC-721 token IDs from one global counter
starting at 1 and stores explicit `tokenId -> collectionId` plus
`tokenId -> collectionSerial` mappings (ADR 0009 decision 1). Token ID
arithmetic carries no meaning: no serial or collection value may be derived
from the token ID, and the namespaced-range formula is removed from the
allocator. The current namespaced token ID formula is current-code context,
not the target model. Collection-local serials remain stable display and
accounting facts without being encoded into the token ID.

Core should expose a read interface:

```solidity
interface IStreamCoreCollectionView {
    function collectionExists(uint256 collectionId) external view returns (bool);
    function collectionSupplyMode(uint256 collectionId) external view returns (uint8);
    function collectionStatus(uint256 collectionId) external view returns (uint8);
    function collectionHasMaxSupply(uint256 collectionId) external view returns (bool);
    function collectionMaxSupply(uint256 collectionId) external view returns (uint256);
    function collectionMintedEver(uint256 collectionId) external view returns (uint256);
    function collectionNextSerial(uint256 collectionId) external view returns (uint256);
    function tokenCollectionIdentity(uint256 tokenId)
        external
        view
        returns (
            bool mappingExists,
            uint256 collectionId,
            uint256 collectionSerial,
            bool burned
        );
    function viewCirSupply(uint256 collectionId) external view returns (uint256);
    function totalSupplyOfCollection(uint256 collectionId) external view returns (uint256);
    function collectionFreezeStatus(uint256 collectionId) external view returns (bool);
}
```

The metadata contract should not depend on private Core mappings.

### Core Collection Management Interface

Collection creation belongs in Core only for authoritative supply/status facts.
Display metadata belongs in `StreamCollectionMetadata`.

```solidity
function createCollection(
    CollectionSupplyMode supplyMode,
    bool hasMaxSupply,
    uint256 maxSupply,
    CollectionStatus initialStatus
) external returns (uint256 collectionId);

function setCollectionStatus(
    uint256 collectionId,
    CollectionStatus status
) external;

function setCollectionMaxSupply(
    uint256 collectionId,
    uint256 newMaxSupply
) external;
```

Rules:

1. `createCollection` allocates a collection ID, initializes supply facts,
   emits `StreamCollectionCreated`, and does not write display strings, scripts,
   randomizer config, royalty config, or sale config.
2. `hasMaxSupply = false` is allowed only for `UNCAPPED_OPEN`.
3. `maxSupply` cannot be lowered below `mintedEver - burned`.
4. Fixed collections cannot increase max supply after activation unless the
   collection was explicitly configured as capped-open.
5. V1 status transitions are `ACTIVE <-> PAUSED`, `ACTIVE -> CLOSED`, and
   `PAUSED -> CLOSED`. `CLOSED` is terminal and cannot be reopened. Ongoing
   collections should use `PAUSED` for temporary pauses; a reopenable state
   such as `SUSPENDED` is excluded from protocol v1 and, because Core owns
   collection status, would require a successor Core line.
6. Metadata, revenue, mint, and entropy satellites listen to collection events
   but do not create collection identity.

Recommended events:

```solidity
event StreamCollectionCreated(
    uint256 indexed collectionId,
    uint8 supplyMode,
    bool hasMaxSupply,
    uint256 maxSupply,
    uint8 initialStatus,
    uint16 schemaVersion
);

event StreamCollectionStatusUpdated(
    uint256 indexed collectionId,
    uint8 oldStatus,
    uint8 newStatus,
    uint16 schemaVersion
);

event StreamCollectionMaxSupplyUpdated(
    uint256 indexed collectionId,
    uint256 oldMaxSupply,
    uint256 newMaxSupply,
    uint16 schemaVersion
);
```

### Core Burn Interface

Burning is an ownership action, not a metadata or royalty deletion action:

```solidity
function burn(uint256 tokenId) external;
```

Core also exposes a one-way, collection-scoped burn block so
collection-scope artwork finality has a Core-verifiable no-burn invariant
(ADR 0010 decision 10). `CLOSED` alone only ends minting; it never blocks
burns, so `CLOSED` by itself can never guarantee an immutable
`burnedSupply`:

```solidity
function blockCollectionBurns(uint256 collectionId) external;
function collectionBurnsBlocked(uint256 collectionId)
    external
    view
    returns (bool);

event CollectionBurnsBlocked(
    uint256 indexed collectionId,
    bytes32 indexed reasonHash,
    uint16 schemaVersion
);
```

Burn rules [CMC-BURN]:

1. Caller must be owner or approved.
2. Core validates the token's collection through `tokenCollectionId[tokenId]`,
   never through token ID range arithmetic.
3. Burn removes ERC-721 ownership; enumeration is event-derived, so no
   enumerable storage exists to update (ADR 0012 decision T10).
4. Burn retains `tokenCollectionId`, `tokenCollectionSerial`, and the mapping
   existence bit for royalty disclosure, archives, and state exports. Core
   also retains the token's renderer-visible `tokenData` bytes after burn
   (ADR 0011 decision R12): burn never deletes them, the burned token's
   archival metadata read stays reproducible from state, and the retained
   bytes are exported through the `STREAM_EXPORT_TOKEN_DATA_LEAF_V1`
   state-export leaf. The token-data ownership and retention home is
   [`docs/mint-policy-and-accounting.md`](mint-policy-and-accounting.md)
   [MPA-CORE-ABI]; this rule is its burn-boundary application.
5. A frozen collection is non-burnable unless the collection's pre-freeze
   policy explicitly preserves a burn path and states the archival
   consequences.
6. `blockCollectionBurns` is one-way and irreversible, requires Core status
   `CLOSED`, and executes only through ADR 0004 staged governance. After it
   executes, `burn` reverts for every token of the collection, so
   `mintedEver`, `burned`, and `nextSerial` are immutable thereafter.
7. Collection-scope artwork finality requires `CLOSED` and
   `collectionBurnsBlocked(collectionId) == true`, verified by the finality
   registry in the same staged action that records finality. Burns between
   `CLOSED` and the burn block are allowed; the Core supply facts captured
   in the finality facts hash are read at finality execution time, after
   the burn block, so late burns are bound, not raced. A collection that
   needs post-finality burns must never set the burn block and must use
   token, release, season, or view scoped finality instead of
   collection-scope finality. This is the Core-side invariant behind
   finality requirement 7 in
   [`docs/stream-long-term-architecture.md`](stream-long-term-architecture.md).
8. Burn emits `StreamTokenBurned` with collection ID and serial.

```solidity
event StreamTokenBurned(
    uint256 indexed tokenId,
    uint256 indexed collectionId,
    uint256 collectionSerial,
    uint16 schemaVersion
);
```

## Open-Ended Collections

Open-ended collections are a first-class protocol v1 requirement.

Examples:

1. A permanent photography series inside the 6529 Stream contract.
2. A long-running artist practice that may add work for decades.
3. A collection that starts uncapped and is later closed by the artist or
   governance.
4. A capped-open collection where the cap exists but the final minted count may
   be lower.

Supply modes:

```text
FIXED         max supply is known and locked before or at collection activation
CAPPED_OPEN   max supply exists, but the collection can close below the cap
UNCAPPED_OPEN no max supply is known; collection can continue until closed
```

Status:

```text
ACTIVE  minting may proceed according to the current sale/minter rules
PAUSED  minting is temporarily disabled but may resume
CLOSED  minting is permanently disabled and final supply is mintedEver - burned
```

Rules:

1. A collection does not need a final supply at creation.
2. Core must assign a stable collection-local serial number at mint time or
   same-transaction allocation time.
3. Collection-local serial numbers never change, even if tokens burn.
4. Closing a collection is one-way.
5. Pausing a collection is reversible unless another freeze policy forbids it.
6. A closed collection's final minted count is `mintedEver`.
7. A closed collection's live supply is `mintedEver - burned`.
8. Metadata may describe a collection as ongoing, seasonal, paused, or complete,
   but Core status is the authoritative mintability state.
9. Metadata fields must not be used as supply authority.
10. A frozen collection is non-burnable by default. A burn path may survive a
    freeze only if the pre-freeze policy explicitly preserves it and proves
    that burning cannot change the promised artwork, supply semantics, entropy
    interpretation, or revenue/royalty history.
11. Collection-scope artwork finality is incompatible with any surviving burn
    path: it requires the one-way Core burn block of [CMC-BURN] in addition
    to `CLOSED`. Scoped finality is the required model for finalized tokens,
    releases, seasons, or views that coexist with later burns elsewhere in
    an open collection.
12. When a burn is allowed, Core removes ERC-721 ownership but preserves
    token-to-collection mapping, collection-local serial, and
    mapping-existence state for historical royalty and audit reads.

Core mint ABI ownership [CMC-MINT-ABI]:

1. The Core mint entrypoints — `mintFromManager` and the
   `prepareMintFromManager`/`completePreparedMintFromManager` pair — their
   exact parameter types, the `tokenData`/`tokenDataHash` binding, and the
   mint-commitment evidence model are owned by
   [`docs/mint-policy-and-accounting.md`](mint-policy-and-accounting.md)
   (ADR 0010 decision 3). This document cites that home and defines no
   second mint shape. The `mintNext(collectionId, initialRecipient,
   beneficiary, tokenData, mintCommitment)` shape formerly recommended here
   is superseded and must not be implemented: Core takes no beneficiary
   parameter, and beneficiary/commitment evidence belongs to the manager,
   ledger, and settlement records.
2. Core allocates the token ID and collection-local serial; sale contracts
   never precompute token IDs by hand. A sale path that needs a token-level
   primary or royalty override allocates the token through the mint spec's
   prepared path before external recipient callbacks, writes the
   authoritative token-to-collection mapping, and then settles revenue.
3. Protocol v1 does not define a standalone premint reservation API;
   unknown future token IDs are not valid collection authority for
   metadata, revenue, royalty, entropy, or freeze rules.

## Contract Identity

Recommended contract name:

```solidity
contract StreamCollectionMetadata
```

Recommended interface:

```solidity
interface IStreamCollectionMetadata {
    function collectionMetadata(uint256 collectionId)
        external
        view
        returns (CollectionMetadataView memory);

    function collectionField(uint256 collectionId, bytes32 key)
        external
        view
        returns (CollectionFieldValue memory);

    function scriptManifest(uint256 collectionId)
        external
        view
        returns (ScriptManifestView memory);

    function scriptChunk(uint256 collectionId, uint256 index)
        external
        view
        returns (string memory);

    function scriptChunkCount(uint256 collectionId)
        external
        view
        returns (uint256);

    function dependencyManifest(uint256 collectionId)
        external
        view
        returns (DependencyManifestView memory);

    function mediaManifest(uint256 collectionId)
        external
        view
        returns (MediaManifest memory);

    function collectionViewManifest(uint256 collectionId, bytes32 viewId)
        external
        view
        returns (CollectionViewManifest memory);

    function latestSnapshotHash(uint256 collectionId)
        external
        view
        returns (bytes32);

    function isLocked(uint256 collectionId, bytes32 lockId)
        external
        view
        returns (bool);
}
```

Exact return structs may be adjusted during implementation to reduce stack
depth, gas, or ABI complexity.

## Typed Metadata

The contract should ship with a rich typed metadata model from genesis. The
typed model is the stable, first-class API for fields that renderers,
marketplaces, wallets, indexers, and 6529 frontends are expected to understand
without collection-specific interpretation.

The typed model should be grouped. This avoids one giant calldata tuple, lets
admins update one area without rewriting unrelated fields, and gives locks
clean boundaries.

```solidity
struct CollectionIdentity {
    bytes32 schemaId;
    string schemaURI;
    bytes32 schemaHash;
    string slug;
    string name;
    string subtitle;
    string description;
    string category;
    string tagsURI;
    bytes32 tagsHash;
}
```

Identity guidance:

1. `schemaId`, `schemaURI`, and `schemaHash` identify and commit to the metadata
   schema understood by frontends and indexers.
2. `slug` is a human-readable collection slug. It is not a unique security
   primitive unless uniqueness is explicitly enforced.
3. `name` is the canonical collection display name.
4. `subtitle` is optional short supporting text.
5. `description` is the canonical collection description.
6. `category` is display data, not a closed enum. Examples may include art,
   photography, generative, edition, poster, artifact, or experiment.
7. `tagsURI` and `tagsHash` allow richer tag vocabularies without hardcoding
   them onchain.

```solidity
struct CollectionPeople {
    bytes32 artistRecordId;
    address artistAddress;
    string artistDisplayName;
    string artistProfileURI;
    string artistWebsiteURI;
    string artistENS;
    string collaboratorsURI;
    bytes32 collaboratorsHash;
}
```

People guidance [CMC-PEOPLE]:

1. Artist authority does not live in this struct. `artistRecordId` and
   `artistAddress` mirror the collection's binding in the artist authority
   registry ([`docs/stream-artist-authority.md`](stream-artist-authority.md), ADR 0010 decision 2), where
   an operator proposes the binding and the artist must accept onchain or
   via verified EIP-712/ERC-1271 signature before it is authoritative.
   Every artist-gated action in this document resolves the current accepted
   artist (or estate successor) through that registry at call time — never
   through a stored address in this contract — so key rotation, estate
   succession, and dormancy transitions defined there apply automatically.
2. Until the binding is accepted, every rendering surface must present the
   attribution as unverified
   (`properties.provenance.attribution.state = "claimed"` in token JSON,
   per the attribution schema home cited by [MRR-ATTRIBUTION] in
   [`docs/metadata-router-and-renderer.md`](metadata-router-and-renderer.md)),
   and no artist-gated write is possible for the collection.
3. `artistDisplayName`, `artistProfileURI`, `artistWebsiteURI`, and
   `artistENS` are display fields only. Writing display fields that
   contradict the registry binding is an operator error surfaced by
   tooling; the registry wins.
4. Multi-artist and collaborative works bind a typed onchain collaborator
   list — address, role, share reference, individual acceptance state — in
   the artist authority registry, with each collaborator accepting
   individually. The collection's artist-gated action policy (any-one, all,
   or k-of-n threshold of accepted collaborators) is declared there at
   binding time and frozen with the collection's promises.
   `collaboratorsURI` plus `collaboratorsHash` remain a display supplement
   for narrative credits (studios, fabricators, publishers, future roles);
   they confer no authority.
5. Attribution history is append-only: binding proposals, acceptances,
   rotations, successions, disputes, and revocations are evented in the
   registry with reason hashes, and this contract's mirror fields must
   never be the only record of a change.

```solidity
struct CollectionMedia {
    string imageURI;
    string imageAltText;
    string bannerImageURI;
    string featuredImageURI;
    string thumbnailURI;
    string animationURI;
    string previewURI;
    string mediaURI;
    bytes32 mediaHash;
    string backgroundColor;
}
```

Media guidance:

1. `imageURI` is the primary collection image.
2. `imageAltText` gives accessibility tools and frontends first-class alt text.
3. `bannerImageURI`, `featuredImageURI`, `thumbnailURI`, and `previewURI`
   support marketplace, exhibition, mobile, and social surfaces without
   overloading one image.
4. `animationURI` supports collection-level animated or interactive previews.
5. `mediaURI` and `mediaHash` support richer media manifests.
6. `backgroundColor` must be a six-character hex string without `#` when used
   in token metadata.

```solidity
struct CollectionURIs {
    string baseURI;
    string contractURI;
    string externalURI;
    string websiteURI;
    string canonicalMetadataURI;
    string offchainMirrorURI;
    string archiveURI;
}
```

URI guidance:

1. `baseURI` is the offchain token metadata base.
2. `contractURI` is collection-level marketplace metadata.
3. `externalURI` is the primary external URL for the collection.
4. `websiteURI` is a collection or artist website if distinct from
   `externalURI`.
5. `canonicalMetadataURI` can point to a full collection metadata document.
6. `offchainMirrorURI` lets onchain metadata have an indexed offchain mirror.
7. `archiveURI` supports long-term preservation records.

```solidity
struct CollectionRights {
    string licenseURI;
    string rightsURI;
    string termsURI;
    string attributionURI;
    string provenanceURI;
    bytes32 provenanceHash;
}
```

Rights and provenance guidance:

1. `licenseURI` is the human/legal license reference.
2. `rightsURI` can describe rights not captured by the license alone.
3. `termsURI` can capture sale, usage, mint, or exhibition terms.
4. `attributionURI` can describe required attribution.
5. `provenanceURI` and `provenanceHash` support canonical provenance records.
6. Rights fields are disclosure and evidence surfaces, not onchain legal
   enforcement. Operator UX and rights schemas must state that commercial,
   derivative, AI-training, print, exhibition, estate, or attribution metadata
   does not itself compel offchain actors unless a separate legal agreement
   or a separately accepted enforcement ADR says so. Collections using legal
   or estate fields should obtain offchain legal review before publication,
   because immutable notice can outlive changes in law, ownership, or estate
   administration.
7. The machine-readable rights baseline beneath these URI fields is the
   pinned `STREAM_RIGHTS_V1` record schema [CMC-RIGHTS-SCHEMA]
   (ADR 0011 decision R11); bare URI-plus-hash pairs are a display
   supplement, never the rights record a registrar catalogues.
8. Moral-rights posture, stated explicitly alongside attribution: the
   protocol records attribution, integrity, and artist-intent claims as
   permanent cryptographic notice; it neither waives, transfers, nor
   enforces moral rights, which remain jurisdiction-dependent offchain
   law. Integrity disputes route through the attribution dispute and
   artist content veto surfaces, not through rights fields.

```solidity
struct CollectionDisplay {
    bytes32 displayProfileId;
    string displayProfileURI;
    bytes32 rendererCompatibility;
    string locale;
}
```

Display guidance:

1. `displayProfileId` is an open-ended display/profile key, not a hardcoded
   enum.
2. `displayProfileURI` can point to theme, layout, color, or rendering
   preferences understood by 6529 frontends.
3. `rendererCompatibility` declares the renderer or render-context family the
   collection expects.
4. Exhibition and loan context is not a loose URI pair: it uses the typed
   `EXHIBITION`/`LOAN` record schema of the object dossier
   ([CMC-OWNER-RECORDS] and [CMC-EXHIBITION-LOAN]) with collection- or
   token-scoped subjects (ADR 0010 decision 6), replacing the former
   `exhibitionURI`/`exhibitionHash` fields.

## Token-Level Metadata

Core must not store token display metadata, token image JSON, attributes JSON,
or renderer overrides. Token-level display metadata lives in
`StreamCollectionMetadata` and is read by the metadata router/renderer.

Mint-time token data is the one exception, and its home is the mint
spec [CMC-MINT-ABI]: `tokenData` is opaque `bytes` end to end — V1 Core
stores the renderer-visible `tokenData` bytes and their `tokenDataHash`
commitment, written by the Core mint path
([`docs/mint-policy-and-accounting.md`](mint-policy-and-accounting.md)
[MPA-CORE-ABI], ADR 0010 decision 3; typing drift repaired by ADR 0012
decision T7). If a collection treats token data as UTF-8, JSON,
CBOR, or another format, the active renderer/schema declares that
interpretation; the renderer reads the bytes from Core and never parses
them. This contract must
not store a second authoritative copy of mint-time token data — token-level
records here may only reference it by hash.

Recommended token-level v1 API:

```solidity
struct TokenMetadata {
    string imageURI;
    bytes32 imageHash;
    string animationURI;
    bytes32 animationHash;
    bytes32 attributesHash;
    string attributesURI;
    bytes32 rendererOverrideId;
    bytes32 metadataHash;
}

function setTokenMetadata(
    uint256 tokenId,
    TokenMetadata calldata metadata
) external;

function setTokenField(
    uint256 tokenId,
    bytes32 key,
    bytes calldata value,
    bytes32 valueHash,
    bytes32 schemaId
) external;

function lockTokenField(uint256 tokenId, bytes32 key) external;
```

Token metadata rules [CMC-TOKEN-METADATA]:

1. The metadata contract verifies token existence or burned-token archival
   policy through Core reads.
2. Token metadata merges over collection metadata only where the renderer schema
   says token-level overrides are allowed.
3. Token field locks are one-way and survive collection metadata replacement.
4. Token-level metadata cannot modify revenue assignments, ownership, entropy
   seed, or collection identity.
5. Burned-token archival metadata may remain readable through metadata contract
   views even when Core `tokenURI()` reverts under ERC-721 semantics.
6. Mint-time `tokenData` is renderer-visible from the mint transaction
   itself, because the Core mint path stores it before any ERC-721 receiver
   callback [CMC-MINT-ABI]. A collection whose renderer additionally
   requires token-level metadata from this contract before first render —
   a per-token image URI, for example — must not mint through
   `PRE_REVENUE_SINGLE_STEP` unless that metadata is precommitted (written
   or hash-bound) before the receiver callback; otherwise it must use the
   prepared path or accept pending display until the metadata write lands.
   The single-step renderer-visibility golden test in the conformance
   matrix evaluates exactly this rule.

Additional display semantics: `locale` is a default locale hint. Show,
release, season, and loan placement uses the typed `EXHIBITION`/`LOAN`
record schema [CMC-EXHIBITION-LOAN] rather than loose URI fields.

Recommended aggregate view:

```solidity
struct CollectionMetadataView {
    CollectionIdentity identity;
    CollectionPeople people;
    CollectionMedia media;
    CollectionURIs uris;
    CollectionRights rights;
    CollectionDisplay display;
}
```

Typed metadata should be extensive enough to make genesis collections feel
complete in marketplaces, galleries, wallets, and 6529 frontends. It should not
try to predict every future field. That is the job of open metadata fields.

## Default Schema Tiers

The metadata contract should support rich typed fields by default, but it should
not pretend that today's field list is the final field list for the next 50
years.

Use three tiers:

1. Rich typed default fields for values that renderers, marketplaces, and frontends
   need constantly.
2. Known custom fields for Stream conventions that are useful but not worth
   permanent Solidity struct slots.
3. Arbitrary custom fields for collection-specific, future, or experimental
   metadata.

Typed default fields should feed the default token JSON:

```json
{
  "name": "...",
  "description": "...",
  "image": "...",
  "animation_url": "...",
  "external_url": "...",
  "background_color": "...",
  "attributes": [],
  "properties": {
    "stream": {},
    "media": {},
    "rights": {},
    "provenance": {},
    "extensions": {}
  }
}
```

The first-class fields are intentionally a compatibility layer. Deeper protocol,
archival, curatorial, exhibition, rights, and provenance data should live in
namespaced properties or custom fields.

## Payload Source Types

Scripts, dependencies, media, schemas, and large metadata fragments should use a
shared source vocabulary so the system can evolve without redeploying Core.

```solidity
enum PayloadSourceType {
    NONE,
    INLINE_CHUNKS,
    SSTORE2,
    ETHFS,
    DEPENDENCY_REGISTRY,
    IPFS,
    ARWEAVE,
    HTTPS,
    WEB3_CALL
}
```

Rules:

1. `INLINE_CHUNKS` is the preferred v1 path for collection scripts.
2. `DEPENDENCY_REGISTRY` is the preferred v1 path for shared JavaScript
   dependencies already supported by the protocol.
3. `IPFS`, `ARWEAVE`, and `HTTPS` require a hash commitment for payloads that
   affect rendering, provenance, or collector display.
4. `SSTORE2` is a genesis capability required for large scripts and for
   onchain catalog/snapshot bytes (ADR 0010 decision 4); `ETHFS` is not
   required at genesis, but the manifest model must be able to represent
   it.
5. `WEB3_CALL` leaves room for ERC-4804-style onchain JSON or HTML reads.
6. Source type additions should be additive. Unknown source types in future
   schemas must not change Core behavior.
7. Protocol v1 should not include an `OTHER` source type because it has no
   resolution semantics. New source types must be added through explicit
   enum values or versioned extension modules with resolver rules.

## Open Metadata Fields

The typed struct should not be the only metadata surface. The contract should
support arbitrary future fields:

```solidity
mapping(uint256 collectionId => mapping(bytes32 key => bytes value)) customData;
```

Recommended custom field shape:

```solidity
struct CollectionFieldValue {
    bytes value;
    bytes32 valueHash;
    bytes32 fieldType;
    string uri;
}
```

`fieldType` is an open vocabulary. Examples:

```text
keccak256("string")
keccak256("uri")
keccak256("json")
keccak256("cbor")
keccak256("bytes32")
keccak256("address")
keccak256("uint256")
```

These are examples, not a closed type system. A field may store a compact value
directly, point to a URI, or do both. `valueHash` commits to the canonical
payload and is useful even when the field is too large to store fully onchain.

Examples of field keys:

```text
keccak256("ARTIST_STATEMENT")
keccak256("PROVENANCE_HASH")
keccak256("PROVENANCE_URI")
keccak256("EXHIBITION_ID")
keccak256("EXHIBITION_URI")
keccak256("CURATOR_NOTE")
keccak256("CURATORIAL_CONTEXT_URI")
keccak256("DISPLAY_THEME")
keccak256("OFFCHAIN_MIRROR_URI")
keccak256("RIGHTS_URI")
keccak256("ROYALTY_CONTEXT_URI")
keccak256("CONTENT_WARNING")
keccak256("LOCALE_DEFAULT")
keccak256("PROPERTIES_JSON")
keccak256("ATTRIBUTES_JSON")
keccak256("PRESS_KIT_URI")
keccak256("MUSEUM_LABEL_URI")
keccak256("CONSERVATION_NOTES_URI")
keccak256("CHAIN_OF_TITLE_URI")
keccak256("COLLABORATOR_MANIFEST_URI")
keccak256("ACCESSIBILITY_NOTES_URI")
keccak256("COLLECTION_KIND")
keccak256("SERIES_STATUS")
keccak256("OPEN_SERIES_CONTEXT_URI")
keccak256("INTENDED_CADENCE")
keccak256("SEASON_MANIFEST_URI")
keccak256("SEASON_MANIFEST_HASH")
keccak256("RELEASE_MANIFEST_URI")
keccak256("RELEASE_MANIFEST_HASH")
keccak256("SCHEMA_URI")
keccak256("SCHEMA_HASH")
keccak256("MEDIA_MANIFEST_URI")
keccak256("MEDIA_MANIFEST_HASH")
keccak256("ALTERNATE_VIEWS_URI")
keccak256("ALTERNATE_VIEWS_HASH")
keccak256("IIIF_MANIFEST_URI")
keccak256("IIIF_MANIFEST_HASH")
keccak256("HIGH_RES_MASTER_URI")
keccak256("HIGH_RES_MASTER_HASH")
keccak256("PRINT_PROFILE_URI")
keccak256("EXHIBITION_WALL_LABEL_URI")
keccak256("ANNOTATION_COLLECTION_URI")
keccak256("ANNOTATION_COLLECTION_HASH")
keccak256("MARKETPLACE_VIEW_URI")
keccak256("GALLERY_VIEW_URI")
keccak256("ARCHIVE_VIEW_URI")
keccak256("PRINT_VIEW_URI")
keccak256("ACCESSIBILITY_VIEW_URI")
keccak256("AR_VIEW_URI")
keccak256("ARCHIVE_MANIFEST_URI")
keccak256("ARCHIVE_MANIFEST_HASH")
keccak256("IPFS_CID")
keccak256("ARWEAVE_TX")
keccak256("FILECOIN_DEAL_URI")
keccak256("FIXITY_CHECK_URI")
keccak256("FIXITY_CHECK_HASH")
keccak256("PRESERVATION_EVENT_LOG_URI")
keccak256("PRESERVATION_EVENT_LOG_HASH")
keccak256("PREMIS_OBJECT_URI")
keccak256("PREMIS_OBJECT_HASH")
keccak256("PREMIS_EVENT_URI")
keccak256("PREMIS_EVENT_HASH")
keccak256("PREMIS_AGENT_URI")
keccak256("PREMIS_AGENT_HASH")
keccak256("PREMIS_RIGHTS_URI")
keccak256("PREMIS_RIGHTS_HASH")
keccak256("SIGNIFICANT_PROPERTIES_URI")
keccak256("SIGNIFICANT_PROPERTIES_HASH")
keccak256("C2PA_MANIFEST_URI")
keccak256("C2PA_MANIFEST_HASH")
keccak256("C2PA_CLAIM_HASH")
keccak256("C2PA_CLAIM_SIGNATURE_HASH")
keccak256("C2PA_VALIDATION_STATUS")
keccak256("C2PA_VALIDATION_REPORT_URI")
keccak256("CAMERA_PROVENANCE_URI")
keccak256("EDIT_HISTORY_URI")
keccak256("SOURCE_MEDIA_RELATIONSHIPS_URI")
keccak256("DERIVED_MEDIA_RELATIONSHIPS_URI")
keccak256("PARENT_CHILD_RELATIONSHIPS_URI")
keccak256("ARTIST_ATTESTATION_HASH")
keccak256("CURATOR_ATTESTATION_HASH")
keccak256("INSTITUTION_ATTESTATION_HASH")
keccak256("COMMERCIAL_RIGHTS_URI")
keccak256("AI_TRAINING_PERMISSION")
keccak256("DERIVATIVE_RIGHTS_URI")
keccak256("PRINT_RIGHTS_URI")
keccak256("EXHIBITION_RIGHTS_URI")
keccak256("ATTRIBUTION_REQUIREMENTS_URI")
keccak256("ESTATE_CONTACT_URI")
keccak256("POST_MINT_PARAMS_SCHEMA_URI")
keccak256("DYNAMIC_TRAITS_MODULE")
keccak256("TOKEN_BOUND_ACCOUNT_REGISTRY")
keccak256("AGENT_MANIFEST_URI")
keccak256("AGENT_MANIFEST_HASH")
```

These are examples only. The contract must not treat the example list as a
closed vocabulary. Registrar-shaped keys — `CHAIN_OF_TITLE_URI`,
`EXHIBITION_*`, deaccession references — are display supplements; the
normative homes for accession, title binding, condition, exhibition, loan,
and deaccession documentation are the typed owner-record and
exhibition/loan schemas [CMC-OWNER-RECORDS] [CMC-EXHIBITION-LOAN].

Field values should be bytes so future values can be:

1. UTF-8 strings.
2. ABI-encoded typed data.
3. Content hashes.
4. Packed flags.
5. URI bytes.
6. JSON fragments.
7. CBOR or other future machine-readable formats.

For discoverability, the contract should either keep an enumerable list of
custom field keys per collection or emit enough events for indexers to
reconstruct it. The preferred v1 design is:

```solidity
mapping(uint256 collectionId => bytes32[] keys) collectionFieldKeys;
mapping(uint256 collectionId => mapping(bytes32 key => uint256 indexPlusOne)) fieldIndex;
```

This costs some gas on writes but makes the metadata contract self-describing
without relying on a centralized indexer.

Frontends should use events, schema docs, optional field definition metadata,
and optional offchain metadata to display human-readable labels.

Custom fields that are intended for direct renderer inclusion should identify
their expected format through either:

1. A known key convention such as `PROPERTIES_JSON`.
2. A schema ID in `CollectionIdentity`.
3. A companion format key such as `keccak256("FIELD_FORMAT:<fieldKey>")`.

The v1 implementation does not need a universal type registry, but it
should leave room for one as a separate accepted module.

### Field Families

Known custom fields should be documented as families rather than as a closed
list. Suggested v1 families:

1. Curatorial fields: artist statements, curator notes, museum labels,
   exhibition context, season/release context, and collection narratives.
2. Media fields: high-resolution masters, print profiles, thumbnails, captions,
   alternates, accessibility notes, and IIIF manifests.
3. Preservation fields: archive manifests, content-addressed mirrors, fixity
   checks, preservation event logs, and storage receipts.
4. Provenance fields: source media records, edit history, C2PA-style manifests,
   artist attestations, curator attestations, institution attestations, and
   chain-of-title references.
5. Rights fields: licenses, commercial rights, AI-training policy, derivative
   rights, print rights, exhibition rights, attribution requirements, and estate
   or successor contact policies.
6. View fields: marketplace, gallery, archive, print, accessibility, mobile,
   AR/VR, raw JSON, raw HTML, and agent-readable views.

These families should be reflected in schema docs and admin tooling. The
contract itself only needs stable keys, field types, hashes, URIs, and events.

## Script Manifest

Collection script storage should move out of Core. The metadata contract should
store or point to a manifest:

```solidity
struct ScriptManifest {
    bytes32 scriptHash;
    bytes32 rendererCompatibility;
    PayloadSourceType sourceType;
    string libraryURI;
    string scriptURI;
    string sourcePointer;
    string mimeType;
    uint256 chunkCount;
    bool executable;
}
```

V1 behavior:

1. `libraryURI` replaces the current `collectionLibrary`.
2. Onchain script chunks replace the current `collectionScript`.
3. `scriptHash` commits to the canonical script payload.
4. `rendererCompatibility` states the renderer/API version expected by the
   script.
5. `scriptURI` is an optional offchain mirror or source reference.
6. `sourceType` should be `INLINE_CHUNKS` for v1 onchain scripts.
7. `sourcePointer` can later point to a blob contract, EthFS path, Arweave ID,
   IPFS CID, or another storage-specific identifier.
8. `mimeType` should normally be `application/javascript` for executable
   scripts.
9. `executable` must be false for manifests that describe source archives or
   documentation rather than renderer-executed JavaScript.

The contract may store small scripts as inline chunks:

```solidity
mapping(uint256 collectionId => string[] chunks) scriptChunks;
```

For larger scripts, SSTORE2-backed chunked storage is the genesis path
(ADR 0010 decision 4): up to `MAX_SCRIPT_CHUNKS = 32` write-once blob
chunks of `MAX_SSTORE2_CHUNK_BYTES = 24,576` bytes each, for a total
`MAX_TOTAL_ONCHAIN_SCRIPT_BYTES = 786,432` per collection script.
`scriptChunk(collectionId, index)` serves both storage forms so the public
interface hides the storage choice from renderers, and the paged chunk
reads double as the reconstruction path for works whose assembled output
exceeds RPC response limits
([`docs/metadata-router-and-renderer.md`](metadata-router-and-renderer.md)).

## Dependency Manifest

The current `collectionDependencyScript` should become a dependency manifest:

```solidity
struct DependencyManifest {
    bytes32 dependencyId;
    bytes32 dependencyHash;
    PayloadSourceType sourceType;
    string dependencyURI;
    string sourcePointer;
    string version;
    string mimeType;
    bool useDependencyRegistry;
}
```

If `useDependencyRegistry` is true, the renderer should retrieve dependency
chunks from the existing `DependencyRegistry` using `dependencyId`. If false,
the renderer may use `dependencyURI`, `sourcePointer`, and `sourceType` to
resolve the dependency.

`dependencyHash` lets frontends and collectors verify the intended dependency
payload even if the source is external.

Guidance:

1. V1 dependency manifests can use `DEPENDENCY_REGISTRY` when the existing
   registry contains the dependency.
2. `version` is a human-readable version string. It is not a security
   primitive.
3. `dependencyHash` is the security commitment for the canonical dependency
   payload.
4. `mimeType` should identify JavaScript, CSS, font, image, or other reusable
   asset types.
5. Shared dependencies should be reusable across collections without copying
   their bytes into every collection.

## Media Manifest

`CollectionMedia` stores the common display URIs that marketplaces and frontends
need constantly. `MediaManifest` stores richer integrity and format facts for
the renderer and long-term archival tools.

```solidity
struct MediaManifest {
    PayloadSourceType imageSourceType;
    string imageURI;
    bytes32 imageHash;
    string imageMimeType;
    PayloadSourceType animationSourceType;
    string animationURI;
    bytes32 animationHash;
    string animationMimeType;
    PayloadSourceType contentSourceType;
    string contentURI;
    bytes32 contentHash;
    string contentMimeType;
    string manifestURI;
    bytes32 manifestHash;
    string alternatesURI;
    bytes32 alternatesHash;
}
```

Guidance:

1. `imageURI` and `animationURI` should normally mirror the corresponding
   display fields in `CollectionMedia` when the collection has a single shared
   collection-level asset.
2. Token-specific media may override collection media in token metadata, but it
   should use the same manifest shape.
3. `contentURI`, `contentHash`, and `contentMimeType` identify the canonical
   rich media payload used for the optional token JSON `content` object.
4. `manifestURI` and `manifestHash` can point to a larger media manifest with
   dimensions, aspect ratios, poster frames, captions, accessibility data, and
   archival mirrors.
5. `alternatesURI` and `alternatesHash` can describe additional media roles
   such as `live`, `archive`, `print`, `mobile`, `museum`, or `social`.
6. Empty hash fields mean no hash commitment is available. Tooling should warn
   before final freeze when externally hosted rendering-critical media lacks a
   hash.

## Artist Attestations

The current `artistsSignatures` and `artistSigned` behavior is metadata, not
ERC-721 ownership. It moves into this contract as a state-bound,
signature-verified record family — strictly stronger than the baseline it
replaces, never weaker (ADR 0010 decision 2).

Recommended storage model (a pure storage mirror of the [AA-ATTEST]
payload; the field inventory is owned there and drift is a checker-gated
defect):

```solidity
struct ArtistAttestation {
    uint8 subjectKind;          // AttestationSubjectKind [AA-ATTEST]
    bytes32 subjectId;
    bytes32 subjectStateHash;   // the exact state the artist approved
    bytes32 statementHash;
    bytes32 statementURIHash;
    bytes32 schemaId;
    address signer;
    uint8 authorityClass;       // ArtistAuthorityClass [AA-ROLES]
    uint64 signedAt;
}
```

Attestation rules [CMC-ARTIST-ATTESTATION]:

1. An artist attestation is a typed EIP-712 payload, not a bare string.
   The `StreamArtistAttestation` type — pinned typehash string, full field
   inventory (`core`, `collectionId`, `subjectKind`, `subjectId`,
   `subjectStateHash`, `schemaId`, `statementHash`, `statementURIHash`,
   `nonce`, `signedAt`), and the artist registry's EIP-712 domain — is
   owned by [`docs/stream-artist-authority.md`](stream-artist-authority.md)
   [AA-ATTEST] and [AA-DOMAINS] (ADR 0010 decisions 2 and 3): the payload
   binds `address core` under the registry as `verifyingContract`, never
   this metadata contract's address. This contract stores and events the
   record; it defines no second payload shape, and a conformance checker
   row asserts this document's attestation field inventory matches
   [AA-ATTEST], failing on drift (ADR 0011 decision R7).
2. Submission verifies the signature onchain at write time — EIP-712
   recovery for EOAs with a nonzero, exact-match recovered address, and
   ERC-1271 for contract signers under the metadata verification gas
   parameter [CMC-SIGVER-GGP] (ADR 0010 decisions 1 and 2). Committed-but
   -unverified signatures are nonconformant for this family. There is no
   deferred "when signature verification is added" state.
3. The eligible signer set is resolved through the artist authority
   registry at submission time: the accepted artist, an accepted
   collaborator authorized under the collection's declared threshold
   policy, an artist-granted delegated signer, or the recorded estate
   successor. Delegated-signer grant, scope, expiry, and revocation are
   artist-signed actions defined in [`docs/stream-artist-authority.md`](stream-artist-authority.md) —
   never admin-granted. `authorityClass` records the acting
   `ArtistAuthorityClass` ([AA-ROLES]) in storage and events, so
   artist-signed, delegated, estate, and steward attestations stay
   permanently distinguishable; a single boolean is nonconformant. Both
   direct (`msg.sender` is the signer) and relayed (anyone submits the
   signed payload) submission are supported, so Safe- and estate-held
   artist identities can attest without self-executing.
4. Staleness is first-class: `artistAttestationCurrent(collectionId)`
   returns whether the latest attestation's `subjectStateHash` still
   matches current collection state. Any render-affecting metadata,
   script, dependency, or media mutation after an attestation makes it
   stale; the renderer reports it stale and surfaces the mismatch rather
   than presenting the attestation as current.
5. Artist attestations are append-only or one-time depending on collection
   policy; a one-time attestation is lockable forever through
   `ARTIST_ATTESTATION`.
6. The canonical signed payload and its 65-byte-class signature bytes are
   preserved under the signature-bundle rule of [CMC-ATTESTATIONS] rule 10,
   so verification never decays to trust in a URI host.

Events must make artist attestations easy to index, including the subject
kind, subject state hash, and authority class.

### Artist Intent Records [CMC-ARTIST-INTENT]

Bits without intent cannot support a defensible migration decision. The
`ARTIST_INTENT` record family captures the behavior envelope of a work —
what may vary, what must not — while the artist can still say so
(ADR 0010 decision 6).

1. `ARTIST_INTENT` records are artist-scoped writes (signed by the accepted
   artist, collaborator threshold, delegate, or estate per
   [CMC-ARTIST-ATTESTATION] rule 3) using the pinned Variable Media
   Questionnaire-derived schema `STREAM_ARTIST_INTENT_V1` of
   [CMC-GENESIS-SCHEMAS], covering: acceptable display parameters (scale,
   timing, color, interaction, motion, frame rate), variability tolerances,
   dependency-aging preferences (migration versus emulation versus
   reinterpretation), significant properties, and the artist interview
   entry — each as URI-plus-`HashRef` entries with small canonical
   payloads onchain. The interview entry is a named schema field, not an
   optional attachment: it carries either an archived, dual-family
   mirrored interview reference or an explicit `interview_waived`
   statement, so its absence is always a visible, deliberate choice
   (ADR 0011 decision R11).
2. Finality for a collection with a bound artist requires either a recorded
   `ARTIST_INTENT` record or an explicit artist-signed
   `ARTIST_INTENT_WAIVER` record; `finalizeCollectionArtwork` and scoped
   finality verify one exists for the finality scope (ADR 0010 decision 6).
   Pre-finality tooling warns whenever intent is missing, well before the
   ceremony.
3. Recovery manifests for works with an intent record must state
   conformance or documented deviation from the recorded intent, field by
   field, so a 2075 migration decision is judged against the artist's own
   envelope rather than a single `artworkBytesChanged` boolean.
4. Intent records are append-only and staleness-aware like attestations:
   the artist may supersede intent while alive and unlocked; after
   `ARTIST_INTENT` records lock or the artist's authority passes to an
   estate, estate-signed additions are recorded as estate statements,
   never as retroactive artist intent.
5. Pre-finality tooling must warn distinctly — separately from the
   missing-intent warning — when an artist-bound script-based collection
   approaches finality with `interview_waived` or with no interview entry,
   because fifty years out the interview is usually the only document that
   explains why the tolerances are what they are (ADR 0011 decision R11).

### Attribution Disputes [CMC-ATTRIBUTION-DISPUTES]

Art history is full of misattribution; a permanent record system will face
it. Dispute authority — who may file, arbiter roles, evidence and appeal
semantics — is owned by [`docs/stream-artist-authority.md`](stream-artist-authority.md) (ADR 0010
decision 2). This contract's side:

1. Dispute state is mirrored as `ATTRIBUTION_DISPUTE` records with pinned
   statuses `ACTIVE`, `SUPERSEDED`, `DISPUTED`, `REPUDIATED_BY_ARTIST`, and
   `REVOKED`, filed per the authority spec by the accepted artist, a
   previously attributed address, or the governed arbiter role, with
   required evidence hashes and supersession links.
2. Dispute records are append-only with reasons; nobody — including the
   platform — can delete an attribution narrative, only supersede it with
   linked evidence.
3. Renderers must surface dispute state through
   `properties.provenance.attribution.state`
   (`disputed`/`revoked` per the attribution JSON schema whose normative
   home is [AA-DISPLAY] in
   [`docs/stream-artist-authority.md`](stream-artist-authority.md), cited
   by [MRR-ATTRIBUTION] in
   [`docs/metadata-router-and-renderer.md`](metadata-router-and-renderer.md));
   a standing dispute is never hidden from the default token JSON.

## General Attestations And Provenance

Artist attestations are a special product surface. The metadata contract should
also support generalized provenance attestations for other actors and systems.

Recommended model:

```solidity
struct CollectionAttestation {
    bytes32 attestationType;
    address attester;
    string attesterDID;
    bytes32 statementHash;
    string statementURI;
    bytes32 signatureScheme;
    bytes32 signatureHash;
    bytes32 schemaId;
    uint64 attestedAt;
}
```

Examples of `attestationType`:

```text
keccak256("ARTIST_STATEMENT")
keccak256("CURATORIAL_STATEMENT")
keccak256("INSTITUTIONAL_VERIFICATION")
keccak256("ESTATE_VERIFICATION")
keccak256("MEDIA_PROVENANCE")
keccak256("ARCHIVE_FIXITY")
keccak256("RIGHTS_STATEMENT")
keccak256("C2PA_REFERENCE")
keccak256("W3C_VERIFIABLE_CREDENTIAL")
```

Attestation rules [CMC-ATTESTATIONS]:

1. Attestations are append-only; invalidation is a later attestation or
   dispute record with supersession links, never an overwrite.
2. `statementHash` commits to the canonical payload. `statementURI` is a
   locator, not the source of truth by itself.
3. Attestation verification classes are explicit per attestation type
   (ADR 0010 decisions 2 and 6). `SIGNER_VERIFIED` types —
   `ARTIST_STATEMENT`, `ESTATE_VERIFICATION`, and
   `INSTITUTIONAL_VERIFICATION` at genesis — verify EIP-712 (nonzero,
   exact-match `ecrecover`) or ERC-1271 signatures onchain at write time
   under the metadata verification gas parameter [CMC-SIGVER-GGP].
   `OPERATOR_ASSERTED` types record an authorized writer's claim without
   cryptographic verification of a third-party signer. There is no
   deferred verification state in this specification.
4. The release manifest must state, for every attestation type and record
   family, whether it is `SIGNER_VERIFIED` or `OPERATOR_ASSERTED`, so
   future consumers can weight evidence correctly without reading Solidity.
5. W3C Verifiable Credentials, EAS attestations, C2PA manifests, or future
   attestation systems should be referenced by URI/hash rather than hardcoded
   into Core.
6. Attestation schemas should be versioned through `schemaId`.
7. `attesterDID` is optional and should be used when the attesting identity is
   better represented by a DID, institution record, estate record, or VC issuer
   than by a single Ethereum address.
8. `signatureScheme` should be an open key such as `EIP712`, `ERC1271`,
   `W3C_VC`, `EAS`, `C2PA`, or a future signature suite. `signatureHash`
   commits to the signature or verification bundle.
9. ENS, DID, VC, and institution identifiers are evidence, not permanent
   availability guarantees. Attestations should include address-level,
   key-level, or content-hash commitments where possible so a defunct ENS
   resolver or DID method does not erase provenance.
10. A hash whose preimage is lost proves nothing, so signature bundles are
    never hash-only-and-hope (ADR 0010 decision 2). Any attestation whose
    `signatureHash` is recorded onchain must either (a) store the canonical
    signed payload and signature bytes in contract storage or an SSTORE2
    blob — state-trie bytes, within `MAX_SIGNATURE_BUNDLE_BYTES` — which
    is the required path for EIP-712/ERC-1271 bundles, or (b) for bundle
    classes that cannot fit onchain (VC, C2PA, EAS exports), be bound into
    a preservation record covered by the dual-family archival mirroring
    rule and included in finality manifests and state exports. Event data
    is never the only carrier for a bundle: EIP-4444-class history expiry
    can remove logs from serving nodes while state survives, so an
    event-embedded-only bundle would decay verification back to mirror
    trust exactly when operators are gone (ADR 0011 decision R1). Events
    remain discovery pointers to the stored bytes. A conformance gate
    enforces this; it is not optional operational practice.

The genesis implementation stores the latest attestation hash per type plus
append-only events carrying the payload commitments above. Full onchain
attestation arrays are unnecessary; events, the record-chain accumulator
[CMC-RECORD-CHAIN], and explicit read slots for latest hashes are the v1
surface.

## Preservation Receipts

Collections that matter for 50 years need preservation records, not just
current display URLs. This section is the delegated home for archive
receipt shapes, the receipt evidence-class vocabulary, and the
family-identifier validation rules consumed by the dual-family archival
rule ([LTA-ARCHIVE] requirement 2 in
[`docs/stream-long-term-architecture.md`](stream-long-term-architecture.md);
ADR 0011 decision R4).

Receipt model:

```solidity
struct ArchiveReceipt {
    bytes32 archiveType;
    bytes32 objectId;
    bytes32 contentHash;
    string uri;
    bytes32 receiptHash;
    bytes32 agentId;
    bytes32 schemaId;
    bytes32 evidenceClass;
    uint64 recordedAt;
}
```

Examples of `archiveType`:

```text
keccak256("IPFS")
keccak256("ARWEAVE")
keccak256("FILECOIN")
keccak256("INSTITUTIONAL_ARCHIVE")
keccak256("IIIF")
keccak256("FIXITY_CHECK")
keccak256("PRESERVATION_EVENT")
```

Rules:

1. Receipts should identify what was archived, where it can be found, and how
   to verify it.
2. A collection can have many receipts over time as storage networks, museums,
   mirrors, and preservation tooling change.
3. Receipts should not be treated as rendering inputs unless the active
   metadata config explicitly uses them.
4. Archive receipts should survive metadata freezes when the collection policy
   wants ongoing preservation updates. If a final archive lock is desired, it
   should use an explicit preservation lock.

Evidence classes and validation requirements [CMC-RECEIPTS] (ADR 0011
decision R4):

1. `evidenceClass` is mandatory on every archive receipt and takes one
   pinned value (`keccak256` of the ASCII name; this vocabulary is
   append-only through spec amendment):
   `CONTENT_ADDRESSED_INCLUSION` — the receipt binds the storage
   identifier to the committed bytes cryptographically;
   `ATTESTED_POSSESSION` — a possession proof signed by the storing
   agent, auditable by the fixity program [CMC-FIXITY-PROGRAM];
   `OPERATOR_ASSERTED` — an operator claim with no independent proof.
2. Family-identifier validation is schema-enforced per `archiveType`
   before a receipt can satisfy any preservation-coverage or finality
   precondition: an IPFS-family `CONTENT_ADDRESSED_INCLUSION` receipt
   must carry a CID whose digest equals the committed content hash; an
   Arweave-class receipt must carry the transaction identifier and the
   data-root inclusion path; an `ATTESTED_POSSESSION` receipt must carry
   the storing agent's signature reference and the fixity-audit record
   it is audited under. A receipt whose identifier fields fail its
   family schema is invalid evidence.
3. Of the two families required for any render-critical or
   preservation-critical payload, at least one receipt must be
   `CONTENT_ADDRESSED_INCLUSION` or `ATTESTED_POSSESSION`;
   `OPERATOR_ASSERTED` receipts alone never satisfy the dual-family rule
   ([LTA-ARCHIVE] requirement 2), and fixity records for finality
   preconditions must be produced by a verifier distinct from the
   receipt writer ([LTA-FINALITY] requirement 11).

## Stream Preservation And Provenance Profile

Stream should define its own preservation profile that is PREMIS-aware,
C2PA-aware, and IIIF-aware, without trying to store full archival records
directly onchain.

The onchain contract should store:

1. Identifiers.
2. URIs.
3. Hash commitments.
4. Schema IDs.
5. Minimal latest hashes for cheap verification.
6. Events that let indexers reconstruct history.

The detailed preservation payload should live in canonical JSON, CBOR, IIIF,
PREMIS XML/JSON, C2PA manifests, W3C VC payloads, or future formats referenced
by URI/hash.

### V1 Onchain Record Primitive

The detailed structs below define Stream's preservation schema vocabulary. They
should not all become separate v1 ABI methods or storage layouts.

Protocol v1 should use one generic record primitive for preservation,
provenance, attestation, relationship, fixity, C2PA, IIIF, rights, and
archive records:

```solidity
struct HashRef {
    uint16 algorithm;
    bytes digest;
    bytes32 canonicalizationId;
}

struct CollectionRecord {
    bytes32 recordType;
    bytes32 subjectId;
    HashRef contentHash;
    string uri;
    bytes32 schemaId;
    bytes32 signatureScheme;
    HashRef signatureHash;
    uint64 effectiveAt;
}
```

Recommended hash algorithms include:

```text
HASH_KECCAK256
HASH_SHA256
HASH_BLAKE3
HASH_MULTIHASH
HASH_IPFS_CID
HASH_ARWEAVE_TX
```

`canonicalizationId` identifies how the external payload was serialized before
hashing, such as `ABI_V1`, `RFC8785_JCS`, `DET_CBOR`, `RAW_BYTES`, `PREMIS_XML`,
`IIIF_JSON`, or `C2PA_MANIFEST`. Protocol identity hashes may still use fixed
`bytes32 keccak256` fields elsewhere, but preservation-critical records need
algorithm-tagged fixity.

Protocol v1 must define numeric IDs for every hash algorithm and
canonicalization profile in the release manifest. Unknown hash algorithms are
not accepted in v1 writes; new algorithms require an explicit registry
or contract version rather than a generic `OTHER` bucket.

Algorithm, canonicalization, record-type, and schema identifiers should be
allocated through an append-only registry with reserved governance ranges.
Existing IDs must never be reused with different meaning. New hash families,
canonicalization profiles, record families, or schema families require explicit
new IDs and do not require any change to Core token identity assumptions.

Each `algorithmId` must define expected digest length and validation rules.
Malformed, empty, or oversized digests revert before storage or event emission.
Variable-length formats such as multihash must define their maximum byte length
and inner algorithm validation in the release manifest or schema registry.

Recommended v1 write:

```solidity
function recordCollectionRecord(
    uint256 collectionId,
    CollectionRecord calldata record
) external;
```

Every accepted record emits `CollectionRecordRecorded`, whose schema —
carrying the record, `recordHash`, `recordChainHash`, `recorder`,
`authorizationClass`, and `schemaVersion` — is defined once in the
[Events](#events-cmc-events) section of this document.

`recorder` and `authorizationClass` (the record-family authority under which
the write was accepted: `ARTIST_SIGNER`, `OWNER_SIGNER`, `CURATOR_SIGNER`,
`INSTITUTION_SIGNER`, `INDEPENDENT_ATTESTOR`, `PRESERVATION_ADMIN`,
`METADATA_ADMIN`, `GLOBAL_ADMIN`) are mandatory in every record event so
consumers can permanently distinguish artist-authored, owner-authored,
independent, and operator-authored provenance (ADR 0010 decision 2).

#### Record Payload Carrier [CMC-RECORD-PAYLOAD]

The meaning-bearing record families of [CMC-RECONSTRUCTION] rule 2 need a
state carrier in the specified ABI, not just a hash field — otherwise
implementers ship hash-plus-URI and the 2075 state trie holds proofs of
payloads it cannot produce (ADR 0012 decision T3). The generic record
write therefore has a payload-carrying form:

```solidity
function recordCollectionRecordWithPayload(
    uint256 collectionId,
    CollectionRecord calldata record,
    bytes calldata payload
) external returns (bytes32 recordHash);

function collectionRecordPayload(
    uint256 collectionId,
    bytes32 recordType,
    bytes32 subjectId
) external view returns (address pointer, bytes memory payload);
```

Payload rules:

1. `payload` is the full canonical record payload — the exact bytes
   `record.contentHash` commits to. The write verifies the digest
   against the submitted bytes under the declared algorithm and
   canonicalization (`HASH_KECCAK256` over canonical bytes in v1),
   stores them in an SSTORE2 blob (direct contract storage permitted
   for small payloads), registers the pointer in the payload pointer
   registry [CMC-PAYLOAD-POINTERS], and reverts on digest mismatch,
   empty payload, or `payload.length > MAX_RECORD_PAYLOAD_BYTES`.
2. Meaning-bearing families must use it: a record family named by
   [CMC-RECONSTRUCTION] rule 2 — rights notices, view manifests, the
   content-root reference record, `REFERENCE_RENDER`, `ARTIST_INTENT`,
   work descriptions, and their siblings — must be written through this
   form, or through a surface with its own pinned bytes path (snapshot
   `manifestData`, artist attestation `statement`, owner-record
   `payload`). Writing such a family hash-plus-URI-only through the
   bytes-less form is nonconformant, and a conformance checker row
   verifies that every rule-2 family write path carries
   state-recoverable bytes.
3. Everything else is the ordinary record machinery: authorization per
   family [CMC-AUTHZ], `CollectionRecordRecorded` emission, record-chain
   accumulation [CMC-RECORD-CHAIN], and the v1 byte limits. The payload
   form differs from `recordCollectionRecord` only in carrying and
   storing the bytes.
4. The pattern is host-generic: every record-hosting satellite in the
   spec set — this contract, `StreamCollectionAttestations`,
   `StreamOwnerRecords` (via `OwnerRecord.payload`), and the artist
   authority registry's record surfaces — satisfies its own
   meaning-bearing-payload obligations through this mechanism or an
   equivalent pinned bytes-plus-pointer path; sibling specs cite this
   section rather than defining second carriers.

#### Payload Pointer Registry [CMC-PAYLOAD-POINTERS]

Logs expire; state survives. An onchain payload that only an event can
locate is unrecoverable by a state-only archivist after EIP-4444-class
history expiry — the bytes survive while recoverability by strangers
does not — so every payload-hosting contract in this specification
exposes an enumerable, storage-backed pointer surface (ADR 0012
decision T3):

1. Every contract that stores SSTORE2 or contract-storage payload bytes
   under this specification — snapshot manifest bytes, schema-registry
   and catalog document bytes, record payload blobs
   [CMC-RECORD-PAYLOAD], signature bundles ([CMC-ATTESTATIONS]
   rule 10), and owner-record/independent-lane payload blobs — must
   expose on the hosting contract a count read plus a paged row read
   returning, per payload: the blob pointer (or storage locus), the
   payload family, and the committed content hash:

   ```solidity
   function payloadPointerCount(uint256 scopeKey)
       external
       view
       returns (uint256);

   function payloadPointerAt(uint256 scopeKey, uint256 index)
       external
       view
       returns (address pointer, bytes32 payloadFamily, bytes32 contentHash);
   ```

   `scopeKey` is the hosting lane's scope key (collection ID; token ID
   in owner-record lanes). Named convenience reads are additionally
   required where a sibling rule names one —
   `snapshotManifestPointer(collectionId, snapshotId)` for snapshot
   bytes, `collectionRecordPayload` for record payloads — and the paged
   script-chunk reads (`scriptChunkCount`/`scriptChunk`) already
   satisfy this rule for script storage.
2. Events remain discovery pointers for indexer convenience; the
   storage-backed pointer reads are the conformance carrier. A
   state-only archivist holding no logs must be able to enumerate and
   fetch every onchain payload byte this specification mandates, and a
   golden conformance test walks every payload family from state reads
   alone.
3. State exports include the pointer-registry rows of each hosting
   contract; the dual-family archival mandate for exports and
   event-history snapshot chunks — the EIP-4444 bridge — is owned by
   [`docs/stream-long-term-architecture.md`](stream-long-term-architecture.md)
   ([LTA-EXPORT], [LTA-EVENT-HISTORY]). This section owns only the
   host-side pointer surface.

#### Subject Identity [CMC-SUBJECT-ID]

`subjectId` is never free-form. Every preservation, attestation, fixity,
rights, C2PA, owner-record, and dossier surface keys token-, media-, scope-,
and collection-scoped records with pinned, domain-separated derivations
(ADR 0010 decision 6), so independent archives resolve the same subject
identically decades apart. This section is the normative home of the
subject domains; the protocol v1 domain-constants table mirrors them.

```solidity
bytes32 constant STREAM_SUBJECT_TOKEN_V1 =
    0x1e576f27850d12bc1ec9255ca277dbecfbc84fb3a9a34c474640dfca89811d7e;
    // keccak256("6529STREAM_SUBJECT_TOKEN_V1")

bytes32 tokenSubject = keccak256(abi.encode(
    STREAM_SUBJECT_TOKEN_V1,
    uint256(block.chainid),
    address(core),
    uint256(tokenId)
));

bytes32 constant STREAM_SUBJECT_MEDIA_V1 =
    0x030f2701e9035fcb711b3acc44ec0bf14b4f4e344e231cdaadce7d14e590994b;
    // keccak256("6529STREAM_SUBJECT_MEDIA_V1")

bytes32 mediaSubject = keccak256(abi.encode(
    STREAM_SUBJECT_MEDIA_V1,
    uint256(block.chainid),
    address(core),
    uint256(collectionId),
    bytes32(objectId)
));

bytes32 constant STREAM_SUBJECT_SCOPE_V1 =
    0x748002ff892f4748f1544a8191da460ca6d167aa2e13eeced354e4f66f636394;
    // keccak256("6529STREAM_SUBJECT_SCOPE_V1")

bytes32 scopeSubject = keccak256(abi.encode(
    STREAM_SUBJECT_SCOPE_V1,
    uint256(block.chainid),
    address(core),
    uint256(collectionId),
    uint8(scopeType),      // FinalityScopeType numeric ID
    bytes32(scopeId)
));

bytes32 constant STREAM_SUBJECT_COLLECTION_V1 =
    0x3a882a22dad9915c9193738f63216234155080ed4c4fc9bfae446e90f1df6e16;
    // keccak256("6529STREAM_SUBJECT_COLLECTION_V1")

bytes32 collectionSubject = keccak256(abi.encode(
    STREAM_SUBJECT_COLLECTION_V1,
    uint256(block.chainid),
    address(core),
    uint256(collectionId)
));
```

Subject rules:

1. Writes for token-scoped records must derive `subjectId` with
   `STREAM_SUBJECT_TOKEN_V1`; media objects, finality scopes, and
   collection-scope records use their sibling domains. Tooling and reads
   reject records whose declared scope class does not match the recomputed
   subject ID.
2. `objectId` for media subjects is the `PreservationObjectRef.objectId` of
   the referenced object; `scopeId` matches the scoped-finality model in
   [`docs/stream-long-term-architecture.md`](stream-long-term-architecture.md).
3. The per-object dossier query path is
   `latestCollectionRecordHash(collectionId, recordType, subjectId)` plus
   event replay filtered by the indexed `subjectId`, both keyed by these
   pinned derivations.

#### Record Chain Accumulator [CMC-RECORD-CHAIN]

Logs alone cannot prove completeness: a pruned archive can silently omit
records. Every record lane therefore carries an O(1) onchain rolling
accumulator (ADR 0010 decision 4):

```solidity
bytes32 constant STREAM_RECORD_CHAIN_V1 =
    0x0e7a0feb85d4a4a3e90074703c19de35786e11afaae8f9868aa2a911bcfa1609;
    // keccak256("6529STREAM_RECORD_CHAIN_V1")

newChainHash = keccak256(abi.encode(
    STREAM_RECORD_CHAIN_V1,
    uint256(block.chainid),
    address(this),              // the lane-hosting contract
    uint256(scopeKey),          // collectionId; tokenId in owner-record lanes
    bytes32(recordType),
    bytes32(previousChainHash), // bytes32(0) for the first record
    bytes32(recordHash),
    uint64(recordIndex)         // zero-based per (scopeKey, recordType)
));

function recordChainHash(uint256 collectionId, bytes32 recordType)
    external
    view
    returns (bytes32 chainHash, uint64 recordCount);
```

Accumulator rules:

1. Every accepted record, attestation, revision, and snapshot write updates
   the accumulator for its `(collectionId, recordType)` lane before its
   event is emitted, and the event carries the updated `recordChainHash`.
2. A recovered event set for a lane is complete exactly when replaying it
   reproduces the stored `chainHash` and `recordCount`; anything else
   proves omission or forgery. This is the completeness proof behind
   state-export and citation record-state references.
3. The accumulator is storage, so completeness remains provable even under
   full log-history expiry with operators gone.
4. State exports include per-lane `(chainHash, recordCount)` leaves, and a
   state export is produced at every finality event; the export root
   schema and cadence gates are owned by
   [`docs/stream-long-term-architecture.md`](stream-long-term-architecture.md)
   and the conformance matrix.

Record rules:

1. `recordType` is an open `bytes32` vocabulary.
2. `subjectId` identifies the collection, token, media object, preservation
   object, actor, rights record, snapshot, or relationship subject through
   the pinned derivations of [CMC-SUBJECT-ID]; free-form subject IDs are
   nonconformant.
3. `contentHash` commits to the canonical external payload with an explicit
   algorithm and canonicalization profile.
4. `schemaId` defines how to interpret the payload.
5. `signatureScheme` and `signatureHash` are commitments to EIP-712,
   ERC-1271, W3C VC, EAS, C2PA, DID-linked, or future verification bundles;
   for `SIGNER_VERIFIED` families they are verified at write time and
   preserved under [CMC-ATTESTATIONS] rule 10.
6. The typed records below are recommended offchain schema profiles and
   optional companion-contract interfaces under separate accepted specs, not
   mandatory v1 storage.
7. This keeps the genesis metadata contract auditable while preserving the
   50-year knowledge-system model.
8. `contentHash.digest`, `signatureHash.digest`, and `uri` must respect v1
   byte limits. Oversized records revert before emitting events.
9. New record families are admitted through registry governance and explicit
   authorization policy updates. They cannot change tokenURI, renderer output,
   royalties, minting, ownership, or Core identity unless a separate versioned
   module is approved.
10. Writes are authorized per record family [CMC-AUTHZ]; whole-module writer
    authority does not exist in protocol v1 (ADR 0010 decision 2).

### PREMIS-Inspired Preservation Records

PREMIS v3 organizes preservation metadata around Objects, Events, Agents, and
Rights. Stream should mirror that shape in its manifest schemas.

Recommended manifest records:

```solidity
struct PreservationObjectRef {
    bytes32 objectId;
    bytes32 objectRole;
    string uri;
    bytes32 contentHash;
    string mimeType;
    uint256 byteSize;
    bytes32 formatId;
    bytes32 schemaId;
}

struct PreservationEventRef {
    bytes32 eventId;
    bytes32 eventType;
    bytes32 outcome;
    string eventURI;
    bytes32 eventHash;
    uint64 eventTime;
    bytes32 schemaId;
}

struct PreservationAgentRef {
    bytes32 agentId;
    bytes32 agentRole;
    address account;
    string did;
    string uri;
    bytes32 agentHash;
}

struct PreservationRightsRef {
    bytes32 rightsId;
    bytes32 rightsBasis;
    string rightsURI;
    bytes32 rightsHash;
    uint64 validFrom;
    uint64 validUntil;
}
```

Example `objectRole` values:

```text
SOURCE_CAPTURE
SOURCE_MASTER
EDIT_MASTER
DISPLAY_DERIVATIVE
PRINT_MASTER
TOKEN_METADATA_JSON
ONCHAIN_SCRIPT
DEPENDENCY_SCRIPT
IIIF_MANIFEST
C2PA_MANIFEST
ARCHIVE_PACKAGE
ACCESSIBILITY_TRANSCRIPT
```

Example `eventType` values:

```text
INGEST
FIXITY_CHECK
REPLICATION
MIGRATION
NORMALIZATION
VALIDATION
MEDIA_DERIVATION
C2PA_VALIDATION
SCHEMA_MIGRATION
RIGHTS_REVIEW
CONSERVATION_NOTE
REDACTION
DEACCESSION_REFERENCE
```

Example `outcome` values:

```text
SUCCESS
WARNING
FAILED
INCONCLUSIVE
SUPERSEDED
REDACTED
```

Rules:

1. Preservation records should be append-only and schema-identified.
2. The profile should distinguish source files, master files, display
   derivatives, print masters, token metadata, scripts, and archive packages.
3. A preservation event should identify the object(s), agent(s), outcome,
   timestamp, and evidence URI/hash.
4. Agent records should support Ethereum addresses, DIDs, institution URIs,
   software agents, and preservation services.
5. Rights records should capture preservation rights separately from collector
   display rights.
6. Significant properties should be represented explicitly for works where
   preservation depends on behavior, color profile, dimensions, timing,
   interaction, dependency versions, or execution environment.

#### PREMIS Data-Dictionary Mapping [CMC-PREMIS-PROFILE]

"PREMIS-inspired" shapes that cannot round-trip into a real preservation
system are a permanent translation burden on every acquiring institution.
The crosswalk to actual PREMIS is therefore pinned (ADR 0011 decision
R11):

1. `STREAM_PREMIS_V3_PROFILE` is a genesis schema registered with onchain
   document bytes [CMC-GENESIS-SCHEMAS] [CMC-SCHEMA-REGISTRY]. It defines
   the complete field-level crosswalk from `CollectionRecord`,
   `PreservationObjectRef`, `PreservationEventRef`, `PreservationAgentRef`,
   `PreservationRightsRef`, and `FixityCheckRef` — and from the Stream
   event-type and outcome vocabularies — to PREMIS v3 semantic units and
   the Library of Congress preservation vocabularies. The table below is
   the normative skeleton; the registered profile document carries the
   full unit-by-unit crosswalk, including declared profile-local terms
   with `skos:closeMatch` links where no LoC term exists.

   | Stream surface | PREMIS v3 semantic unit |
   | --- | --- |
   | `PreservationObjectRef.objectId` (subject derivation) | `objectIdentifier` (type `6529STREAM_SUBJECT`) |
   | `PreservationObjectRef.contentHash` | `objectCharacteristics/fixity` (`messageDigestAlgorithm`, `messageDigest`) |
   | `PreservationObjectRef.byteSize` | `objectCharacteristics/size` |
   | `PreservationObjectRef.formatId`/`mimeType` | `objectCharacteristics/format` |
   | `objectRole` values | `significantProperties` plus structural `relationship`, per the profile enumeration |
   | `PreservationEventRef.eventId`/`eventTime` | `eventIdentifier`, `eventDateTime` |
   | `eventType` values | LoC `preservationEventType`: `INGEST` → `ingestion`, `FIXITY_CHECK` → `fixity check`, `REPLICATION` → `replication`, `MIGRATION` → `migration`, `NORMALIZATION` → `normalization`, `VALIDATION` → `validation`, `MEDIA_DERIVATION` → `creation`, `C2PA_VALIDATION` → `digital signature validation`, `SCHEMA_MIGRATION` → `metadata modification`, `RIGHTS_REVIEW` → `policy assignment`, `REDACTION` → `redaction`, `DEACCESSION_REFERENCE` → `deaccession`, `CONSERVATION_NOTE` → profile-local term |
   | `outcome` values | `eventOutcomeInformation/eventOutcome`: `SUCCESS` → `success`, `WARNING` → `warning`, `FAILED` → `fail`; `INCONCLUSIVE`, `SUPERSEDED`, `REDACTED` → profile-local outcomes with `eventOutcomeDetail` |
   | `PreservationAgentRef.agentId`/`account`/`did`/`uri` | `agentIdentifier`; `agentRole` → `linkingAgentRole`; person/organization/software classes → LoC `agentType` |
   | `PreservationRightsRef` | `rightsStatement`: `rightsBasis` → `rightsBasis`, `validFrom`/`validUntil` → `startDate`/`endDate`, `rightsURI`/`rightsHash` → `rightsStatementIdentifier` and `licenseDocumentationIdentifier` |
   | `FixityCheckRef` | `fixity` inside `objectCharacteristics` plus a `fixity check` event |

2. Dossier export tooling ([CMC-OBJECT-DOSSIER]) and the `STATE_EXPORT`
   preservation surfaces must be able to emit valid PREMIS v3 (XML or
   JSON serialization) from Stream records through this profile, so an
   OAIS-modeled repository ingests the dossier without bespoke
   translation. Round-trip validation — Stream records to PREMIS export
   to a PREMIS validator — is a conformance gate.
3. Every "PREMIS-style" claim in the spec set means conformance to this
   profile; the protocol v1 scope table cites it (mirror note in
   [`docs/launch-v1-target-architecture.md`](launch-v1-target-architecture.md)).
4. Format identification is registry-linked, never free-form (ADR 0012
   decision T2): `PreservationObjectRef.formatId` for any
   render-critical or preservation-critical object must carry either a
   PRONOM PUID reference — `keccak256("PRONOM:<PUID>")`, for example
   `keccak256("PRONOM:fmt/199")` for an MP4 container — or an identifier
   from the Stream format catalog, a schema-registry document
   ([CMC-SCHEMA-REGISTRY]) mapping each catalog entry to a PRONOM PUID
   or, where none exists, to a full format-specification reference.
   Automated repository ingest resolves every format without human
   research; a zero or free-form `formatId` on such objects fails the
   dossier export and the finality tooling checks, and for time-based
   media it blocks finality under [CMC-FINALITY-INPUTS] rule 12.

### Fixity Profile

Fixity checks should be first-class because they answer whether a preserved
payload is still the payload the artist or archive intended.

Recommended manifest record:

```solidity
struct FixityCheckRef {
    bytes32 objectId;
    bytes32 algorithm;
    bytes32 digest;
    uint256 byteSize;
    uint64 checkedAt;
    bytes32 outcome;
    bytes32 agentId;
    string reportURI;
    bytes32 reportHash;
}
```

Example `algorithm` values:

```text
SHA256
SHA512
KECCAK256
BLAKE3
IPFS_CID_V1
ARWEAVE_TX_ID
```

Rules:

1. Rendering-critical scripts, dependencies, schemas, media masters, IIIF
   manifests, C2PA manifests, and archive packages must have fixity records
   before final freeze.
2. Repeated fixity checks over time should append events rather than overwriting
   older checks.
3. If a payload is intentionally migrated, the old object, new object,
   migration event, agent, and reason should all be linked.

#### Fixity Program [CMC-FIXITY-PROGRAM]

Fixity is a program — schedule, coverage, and repair — not a record shape
(ADR 0010 decision 6). Silent bit-rot of offchain mirrors is the most
probable long-term loss mode, and "should schedule periodic drills" does not
survive staff turnover; the program is therefore normative and
deployment-gated:

1. Schedule: every payload of every finalized work and every
   render-critical payload of every sold token (the sold-token lane of
   rule 6; ADR 0012 decision T2), in every declared
   storage family, is fixity-verified at least annually (full sweep), and a
   quarterly random sample of at least 5% of the covered payloads per
   storage family is verified between sweeps.
2. Coverage and cadence are published per storage family in the release
   manifest's fixity operational manifest, and the deployment gate fails if
   the manifest is missing, stale, or narrower than rule 1.
3. Each completed cycle records a `FIXITY_CYCLE_COMPLETED` record —
   token/media subjects covered, cycle window, per-family coverage counts,
   failure count, and report hash — through the record primitive, so cycle
   evidence is onchain, chained by [CMC-RECORD-CHAIN], and inspectable by
   any auditor without operator cooperation.
4. Failure workflow: a failed check records a `FIXITY_FAILURE` record naming
   the object, family, expected and observed digests; repair is
   re-replication from a healthy mirror followed by a fresh fixity record;
   an unrepairable payload records a supersession-lineage record linking
   the corrupted artifact, its replacement route, and the reason. Failures
   escalate through the incident-response runbook, and the machine-checkable
   drill artifact pattern extends to fixity cycles.
5. The conformance matrix Operations gate verifies the program: published
   cadence and coverage, at least one completed cycle record before public
   sale, and the failure-workflow drill artifact. The umbrella monitoring
   requirements in
   [`docs/stream-long-term-architecture.md`](stream-long-term-architecture.md)
   consume the same cycle records.
6. Sold-token lane (ADR 0012 decision T2): preservation follows the
   sale, not the ceremony. Each sold token of a `HASH_BOUND`
   `OFFCHAIN`-mode collection — open or closed — joins the program when
   its coverage deadline starts: dual-family archive receipts (at least
   one from an `ENDOWED`-economics storage family, [LTA-ARCHIVE]
   requirements 2-3) plus a first passing fixity record for its
   render-critical payloads, within
   `OFFCHAIN_PRESERVATION_COVERAGE_SECONDS` of its first sale
   settlement, per token or per release batch where a release sells
   together ([MRR-OFFCHAIN-BINDING] rule 6 in
   [`docs/metadata-router-and-renderer.md`](metadata-router-and-renderer.md)
   owns the deadline parameter and its ceiling). Coverage status is
   typed per token — `covered`, `uncovered_within_window`,
   `uncovered_overdue` — and `uncovered_overdue` is a monitored incident
   with an alert under the same regime as a missed close-out deadline.
   The per-token status is a required acquisition-packet field
   ([CMC-ACQUISITION-PACKET] item 8), so a registrar sees the exposure
   as typed data, never as an absence, and a work sold from year six of
   an open series carries the same replication guarantee as a finalized
   edition.

#### Environment Artifact Remediation [CMC-ENV-REMEDIATION]

A drill that detects an unbootable execution environment without a
mandated re-hosting deliverable converts detection into documentation of
loss — and environment decay is the boot-failure mode most likely to
occur within fifty years as container runtimes and instruction sets age
(ADR 0012 decision T8). When a preservation drill's boot check fails for
an archived execution-environment artifact ([CMC-FINALITY-INPUTS]
rule 5(c); the drill duty itself is owned by [LTA-RECON] requirements 4
and 5 in
[`docs/stream-long-term-architecture.md`](stream-long-term-architecture.md)):

1. Remediation is mandatory, mirroring the reconstruction-client
   replacement rule: a migrated or re-hosted runnable environment
   artifact — re-containerized, emulator-wrapped, or rebuilt — must be
   produced that boots and reproduces a reference capture under the
   work's pinned acceptance mode. Post-operator, any institution may
   produce and record one through the independent lane
   [CMC-INDEPENDENT-ATTESTOR].
2. The replacement is a preservation object: hash-committed,
   fixity-covered, mirrored under the dual-family archival rule
   ([LTA-ARCHIVE]), and linked to the original by a `MIGRATION`
   preservation event (PREMIS `migration` per [CMC-PREMIS-PROFILE])
   recording both artifact hashes and the reason — the emulation
   substrate is itself a preserved, migrating chain of artifacts, not a
   once-archived binary.
3. Where re-hosting is genuinely infeasible, a recorded infeasibility
   finding stands in its place: a preservation event with outcome
   `FAILED`, referencing the attempts and evidence. Silence is
   nonconformant.
4. The drill report references the remediation record or infeasibility
   finding, and the next drill's boot check runs against the replacement
   artifact.

### C2PA Profile

C2PA records should be treated as provenance signals, not as the only source of
truth. They are especially valuable for photography, video, AI-assisted media,
and source-to-derivative workflows.

Recommended manifest record:

```solidity
struct C2PAReference {
    string manifestURI;
    bytes32 manifestHash;
    bytes32 activeManifestId;
    bytes32 claimHash;
    bytes32 claimSignatureHash;
    bytes32 signerId;
    string signerDID;
    bytes32 certificateChainHash;
    uint64 signedAt;
    bytes32 validationStatus;
    string validationReportURI;
    bytes32 validationReportHash;
}
```

Recommended companion records:

```solidity
struct C2PAAssertionRef {
    bytes32 assertionId;
    bytes32 assertionType;
    bytes32 assertionHash;
}

struct C2PAIngredientRef {
    bytes32 ingredientId;
    string ingredientURI;
    bytes32 ingredientHash;
    bytes32 ingredientManifestHash;
    bytes32 relationship;
}

struct C2PAActionRef {
    bytes32 actionType;
    uint64 actionTime;
    bytes32 softwareAgentId;
    bytes32[] ingredientIds;
    bytes32 actionHash;
}
```

Example `validationStatus` values:

```text
VALID
INVALID
PARTIAL
MANIFEST_NOT_FOUND
UNSUPPORTED
EXPIRED_OR_REVOKED
REDACTED
UNKNOWN
```

C2PA rules [CMC-C2PA]:

1. The NFT metadata should reference C2PA manifests by URI/hash and active
   manifest ID when known.
2. Claims, assertions, ingredients, actions, and signatures should be recorded
   in offchain manifests and committed by hashes onchain.
3. C2PA binds to the token's actual media or it binds nothing (ADR 0010
   decision 6). For any collection or token opting into C2PA provenance,
   the referenced C2PA manifest's hard-binding asset hash must equal the
   committed media hash (`MediaManifest.imageHash`, `contentHash`, or the
   token-level media hash it documents). Pre-freeze tooling and the
   collection attestations conformance gate verify this equality as a
   validity condition; a `C2PA_REFERENCE` whose asset binding does not
   match the committed media hashes is invalid and must be recorded as
   `INVALID`, not `VALID`.
4. Validation is never self-reported. A `validationStatus` record is valid
   only when it carries the validator identity resolved to a verifiable
   signer class — `CONFIGURED_PROVENANCE_VERIFIER` (the operator-configured
   verifier role of [CMC-AUTHZ]), `INSTITUTION_SIGNER`, or a future
   registry-admitted validator class — plus the validator software version
   and the validation report URI and hash. Records missing any of these are
   structurally invalid and revert.
5. Collections claiming capture-time C2PA provenance (photography, video)
   must have the C2PA manifest recorded at or before mint of the tokens it
   covers; later manifests are supplemental provenance, recorded as such.
6. Redactions should be explicit. A redacted C2PA record can still be useful if
   the redaction is documented.
7. Sensitive camera, location, or personal metadata should not be pushed onchain.
   Use private/offchain payloads with hashes when preservation requires a
   commitment.
8. C2PA should coexist with artist attestations, curator attestations, W3C VCs,
   DIDs, EIP-712 signatures, and ERC-1271 contract-wallet signatures.
9. Redaction-aware manifests should separate public hash, optional redacted
   replacement hash, redaction reason URI/hash, and whether the original
   unredacted payload remains available to authorized archives. Redaction must
   not silently rewrite finalized artwork bytes.
10. Certificate-chain aging is handled by re-attestation: a fresh validation
    record with a current validator class supersedes (never rewrites) an
    older one, preserving the original binding evidence.
11. C2PA authorship must reconcile with registry attribution
    (ADR 0011 decision R7). When a C2PA manifest carries authorship
    assertions for an artist-bound collection, the artist identity record
    ([AA-IDENTITY] in
    [`docs/stream-artist-authority.md`](stream-artist-authority.md))
    should enumerate the artist's C2PA signing credentials in its
    public-key history references, and validation must verify the claim
    signer against that credential set and the registry's attribution
    state and key history. A mismatch never coexists silently as `VALID`
    provenance: it is recorded as a `C2PA_ATTRIBUTION_DIVERGENCE` record
    (append-only, evidence-hashed, superseding-aware) and surfaced through
    the token JSON attribution disclosure
    (`properties.provenance.c2pa_attribution_divergence`,
    [MRR-ATTRIBUTION] rule 6 in
    [`docs/metadata-router-and-renderer.md`](metadata-router-and-renderer.md)).
    Divergence resolution routes through the attribution dispute surface
    [CMC-ATTRIBUTION-DISPUTES]; the C2PA record itself is never rewritten.

### Media Relationships

A collection should be able to explain how source files, generated files,
metadata documents, scripts, dependencies, archive packages, and companion NFTs
relate to each other.

Recommended manifest record:

```solidity
struct MediaRelationshipRef {
    bytes32 subjectId;
    bytes32 relationshipType;
    bytes32 objectId;
    string relationshipURI;
    bytes32 relationshipHash;
}
```

Example `relationshipType` values:

```text
IS_SOURCE_OF
IS_DERIVED_FROM
HAS_DERIVATIVE
HAS_THUMBNAIL
HAS_PRINT_MASTER
HAS_IIIF_MANIFEST
HAS_C2PA_MANIFEST
HAS_ARCHIVE_PACKAGE
HAS_ACCESSIBILITY_TRANSCRIPT
HAS_PARENT_TOKEN
HAS_CHILD_TOKEN
HAS_COMPANION_ASSET
```

Rules:

1. ERC-7401-style parent/child ideas should be represented as metadata
   relationships, not as Core ownership nesting.
2. Stream modules that later add token-linked companion assets through
   separate accepted specs should use explicit relationship records and not
   infer relationships from naming.
3. Relationship payloads should include enough chain ID, contract address, token
   ID, object ID, URI, and hash data to survive migrations and mirrors.

### IIIF And Museum Manifests

For visual art, photography, editions, and institutional display, Stream should
support IIIF-style manifests as first-class references.

Recommended IIIF-related fields:

```text
IIIF_MANIFEST_URI
IIIF_MANIFEST_HASH
HIGH_RES_MASTER_URI
HIGH_RES_MASTER_HASH
PRINT_PROFILE_URI
EXHIBITION_WALL_LABEL_URI
ANNOTATION_COLLECTION_URI
ANNOTATION_COLLECTION_HASH
```

IIIF rules [CMC-IIIF]:

1. IIIF manifests should be optional but strongly supported for serious image
   collections.
2. Stream pins a minimal IIIF Presentation 3 profile,
   `STREAM_IIIF_P3_MIN_V1`, registered as a schema ID (ADR 0010
   decision 6). A conformant manifest is a IIIF Presentation 3 Manifest
   whose painting-annotation content resources are content-addressed
   (`ipfs://` or `ar://`, never bare HTTPS), each carrying a
   cross-reference to the committed media hash it depicts
   (`MediaManifest`/token media hashes), with `label`, `summary`,
   `requiredStatement` (attribution), `rights`, at least one `Canvas` per
   depicted media object, and no embedded executable content. Fields
   outside the profile are permitted; the profile fields are the
   verifiable core.
3. The IIIF manifest may additionally describe annotation pages,
   annotations, image services, and viewing hints; annotations can carry
   curator notes, translations, transcriptions, accessibility notes,
   conservation notes, crop/region commentary, or exhibition-specific
   interpretation.
4. IIIF manifests are supersedable preservation records, not mutable
   documents: a revised manifest is a new record with supersession lineage
   under [CMC-RECORD-CHAIN]; the hash-committed manifest bytes never
   change. URL rot inside a frozen manifest is cured by supersession, never
   by mutation.
5. Live IIIF Image API endpoints and tile services are Operational
   services outside the permanence guarantee; the permanence claim covers
   only the hash-committed manifest and its content-addressed resources.
   Institutions running live services do so under their own service
   contracts.
6. The default marketplace `tokenURI()` should only reference IIIF data; it
   should not inline large IIIF manifests.
7. The profile is deliberately dual (ADR 0011 decision R11): the pinned
   archival profile above is the permanence surface, and a live-service
   companion keeps it usable by the working IIIF ecosystem without
   fragmenting the record. An institution serving Mirador/Universal
   Viewer-class stacks records an `IIIF_SERVICE_MANIFEST` companion — an
   operational HTTPS/IIIF-Image-API rendition manifest, recorded as a
   supersedable record whose payload must cross-reference the conformant
   archival manifest's hash — so the exhibition-usable manifest and the
   permanence-grade manifest stay provably linked. Service manifests are
   non-normative Operational-layer guidance outside the permanence claim
   (rule 5), never a substitute for the archival profile, and never a
   finality input; a stale or dead service manifest is superseded, and
   the archival manifest stands.

## Owner Records And The Object Dossier

A museum acquires one token, and registrar practice requires the acquiring
institution to control its own object documentation. The `OWNER_RECORDS`
family gives the current token owner a writable, append-only registrar
surface that needs no platform cooperation for the life of the system
(ADR 0010 decision 6). It is hosted by the genesis `StreamOwnerRecords`
satellite.

### Owner Records [CMC-OWNER-RECORDS]

```solidity
struct OwnerRecord {
    bytes32 recordType;
    bytes32 subjectId;      // STREAM_SUBJECT_TOKEN_V1 derivation
    bytes32 schemaId;
    HashRef contentHash;
    string uri;
    bytes payload;          // small canonical payload bytes, may be empty
    uint64 effectiveAt;
}

function recordOwnerRecord(
    uint256 tokenId,
    OwnerRecord calldata record
) external;

function recordOwnerRecordFor(
    uint256 tokenId,
    OwnerRecord calldata record,
    address owner,
    uint256 nonce,
    uint64 deadline,
    bytes calldata signature
) external;

// Explicit-address replay view keyed by (owner, nonce); never
// caller-relative (ADR 0011 decision R12; ADR 0012 decision T7).
function isOwnerRecordNonceUsed(address owner, uint256 nonce)
    external
    view
    returns (bool);

// Consumes the caller's own (owner, nonce) pair (rule 9).
function revokeOwnerRecordNonce(uint256 nonce) external;

// Relayed revocation: verifies the owner's signature over
// STREAM_OWNER_RECORD_REVOCATION_TYPEHASH (rule 9).
function revokeOwnerRecordNonceFor(
    address owner,
    uint256 nonce,
    uint64 deadline,
    bytes calldata signature
) external;

event OwnerRecordNonceRevoked(
    address indexed owner,
    uint256 indexed nonce,
    bool relayed,
    uint16 schemaVersion
);

event OwnerRecordRecorded(
    uint256 indexed tokenId,
    bytes32 indexed recordType,
    address indexed owner,
    OwnerRecord record,
    bytes32 recordHash,
    bytes32 recordChainHash,
    bool relayed,
    uint16 schemaVersion
);
```

The relayed path verifies a pinned EIP-712 payload (ADR 0010 decision 3):

```solidity
bytes32 constant STREAM_OWNER_RECORD_TYPEHASH =
    0x9c8c4f8b7ec1e8731277f53e36271ebf92fc96425f0c082143042400814c6b05;
    // keccak256("StreamOwnerRecord(address owner,uint256 tokenId,
    //   bytes32 subjectId,bytes32 recordType,bytes32 schemaId,
    //   uint16 algorithmId,bytes digest,bytes32 canonicalizationId,
    //   string uri,bytes payload,uint64 effectiveAt,uint256 nonce,
    //   uint64 deadline)")
    // (typehash string contains no whitespace or line breaks)
```

Field inventory: `owner` (the signing owner), `tokenId`, `subjectId`,
`recordType`, `schemaId`, the `HashRef` fields (`algorithmId`, `digest`,
`canonicalizationId`), `uri`, `payload`, `effectiveAt`, an unordered
per-owner `nonce` (any never-used `uint256` value; rule 9), and a
`deadline`. The relayed revocation of rule 9 verifies its own pinned
payload:

```solidity
bytes32 constant STREAM_OWNER_RECORD_REVOCATION_TYPEHASH =
    0x11a07172744cbac614966ef944b190ff3c1b4a7076ab4483c69e48ba2b9ee49c;
    // keccak256("StreamOwnerRecordRevocation(address owner,
    //   uint256 nonce,uint64 deadline)")
    // (typehash string contains no whitespace or line breaks)
```

The EIP-712 domain is
`name = "6529StreamOwnerRecords"`, `version = "1"`, the chain ID, and the
satellite address as `verifyingContract`; both typehashes (record and
revocation), the domain, and CI recomputation tests enter the protocol
v1 domain-constants table.

Owner record rules:

1. Authorization is `ownerOf(tokenId)` at execution time — no operator
   configuration, no platform role. The direct path requires
   `msg.sender == ownerOf(tokenId)`; the relayed path verifies the EIP-712
   signature (nonzero, exact-match recovery) or ERC-1271 approval of
   `owner` under the metadata verification gas parameter
   [CMC-SIGVER-GGP], requires `owner == ownerOf(tokenId)`, consumes the
   named `(owner, nonce)` pair (rule 9), and enforces the deadline — so
   Safe-held and estate-held institutional custody can document works
   without self-executing transactions.
2. `recordType` is one of the pinned owner families — `ACCESSION`,
   `CONDITION_REPORT`, `EXHIBITION`, `LOAN`, `DEACCESSION`, `CITATION`
   (each the keccak256 of its name, catalogued in the record-type catalog)
   — or a future family admitted through registry governance.
3. Records are append-only and HashRef-disciplined: corrections are new
   records with supersession references inside their schema payloads, never
   overwrites. `subjectId` must recompute from `STREAM_SUBJECT_TOKEN_V1`
   for the named token [CMC-SUBJECT-ID].
4. Owner records are firewalled from artwork and economics: they cannot
   change default `tokenURI()` output, renderer resolution, artwork
   finality, royalties, minting, transfers, or ownership. Archive,
   gallery, and cultural views may reference them; the marketplace default
   view must not depend on them.
5. Each `(tokenId, recordType)` lane maintains a `STREAM_RECORD_CHAIN_V1`
   accumulator hosted in `StreamOwnerRecords` (its own address separates
   its lanes), with `tokenId` as the lane scope key, so a token's dossier
   is completeness-provable exactly like collection record lanes
   [CMC-RECORD-CHAIN].
6. A transfer does not erase history: prior owners' records stand as that
   owner's statements from their custody period, permanently attributed via
   the event's `owner` field. The current owner cannot edit or remove a
   predecessor's records.
7. Owner records are never lockable by platform operators: no collection
   metadata lock, freeze, or finality state blocks the owner surface,
   because post-finality custody documentation is evidence about the frozen
   object, not a mutation of it.
8. Title binding uses the `TITLE_BINDING` schema inside `ACCESSION` and
   `DEACCESSION` payloads: the hash of the offchain legal instrument
   (invoice, deed of gift, estate transfer), the specific ERC-721
   `Transfer` it corresponds to (block number, transaction hash, `from`,
   `to`), and the instrument's custodian reference — binding paper title to
   a single onchain custody event.
9. Nonces are per-signer and unordered, aligned with the keyed-nonce
   model of the sibling signed surfaces ([AA-IDENTITY] requirement 4 in
   [`docs/stream-artist-authority.md`](stream-artist-authority.md);
   [RSR-RELEASE-AUTH] rule 3 in
   [`docs/revenue-splits-and-royalties.md`](revenue-splits-and-royalties.md))
   — a Safe or estate DAO holding several outstanding signed records
   must never deadlock on relay order, which is exactly the signer class
   this surface exists for (ADR 0012 decision T7). The satellite keeps a
   per-owner consumed-value map (bitmap representation permitted) and
   consumes exactly the value a verified payload names; any unused value
   may be consumed in any order, and a consumed or revoked
   `(owner, nonce)` pair is invalid forever. The explicit-address replay
   view `isOwnerRecordNonceUsed(address owner, uint256 nonce)` reports
   consumption for any queried signer; caller-relative replay views are
   nonconformant (ADR 0011 decision R12). A signed-but-unsubmitted
   record is revocable before use: `revokeOwnerRecordNonce(nonce)`
   consumes the caller's own pair, and `revokeOwnerRecordNonceFor` lets
   any caller present the owner's EIP-712/ERC-1271 revocation under
   `STREAM_OWNER_RECORD_REVOCATION_TYPEHASH`, deadline-bounded and
   verified exactly like the record path. Both emit
   `OwnerRecordNonceRevoked`. Revocation is signer-scoped: no caller can
   consume, revoke, or invalidate another owner's nonce value.

Acquisition packet [CMC-ACQUISITION-PACKET]: acquisition due diligence is
a pinned artifact, not a prose checklist (ADR 0011 decision R11). The
`STREAM_ACQUISITION_PACKET_V1` schema [CMC-GENESIS-SCHEMAS] defines the
schema-identified, hash-committed packet a registrar verifies at closing:

1. the canonical citation string with its record-state qualifier at
   examination time [CMC-CITATION];
2. the token subject ID [CMC-SUBJECT-ID];
3. the finality record (or explicit not-finalized status) and the token
   content-root proof [CMC-CONTENT-ROOT];
4. the entropy provenance record;
5. the current record-chain heads for the token's lanes
   [CMC-RECORD-CHAIN];
6. the attribution state — binding generation, attestation status, and
   sanction record where one exists, each with its signing authority
   class (ADR 0012 decision T4);
7. the collection's rights record under `STREAM_RIGHTS_V1`
   [CMC-RIGHTS-SCHEMA], with the typed rights-completeness status
   (`specified | partially_specified | unspecified | absent`) derived
   from its per-use-class grants (ADR 0012 decision T8);
8. the latest fixity-cycle status covering the token's payloads
   [CMC-FIXITY-PROGRAM], including the token's typed
   preservation-coverage status (`covered | uncovered_within_window |
   uncovered_overdue`, the sold-token lane of [CMC-FIXITY-PROGRAM]
   rule 6; ADR 0012 decision T2) and, for time-based media, the
   preservation-master presence status ([CMC-FINALITY-INPUTS] rule 12);
9. the legal instrument hash recorded (or to be recorded) in
   `ACCESSION`;
10. the ownership-provenance chain: the token's complete ERC-721
    `Transfer` history from mint to present — `from`, `to`, block
    number, and transaction hash per hop — cross-referenced to the
    covering event-history snapshot hash ([LTA-EVENT-HISTORY] in
    [`docs/stream-long-term-architecture.md`](stream-long-term-architecture.md))
    and to any `ACCESSION`/`DEACCESSION` `TITLE_BINDING` records bound
    to specific hops, so title continuity is a verifiable packet field
    rather than external research, and remains reconstructable after
    log-history expiry (ADR 0012 decision T8);
11. for script works, the latest preservation-drill render-verification
    outcome for the work's collection — the drill report hash plus the
    `MATCH | TOLERABLE_VARIANCE | DIVERGENT` classification under the
    work's pinned acceptance mode ([LTA-RECON] requirement 4) — or an
    explicit never-drilled status, so a committee sees renderability as
    well as byte integrity (ADR 0012 decision T8); and
12. the work-description (tombstone) record reference [CMC-TOMBSTONE],
    or its explicit absence (ADR 0012 decision T8).

Dossier tooling [CMC-OBJECT-DOSSIER] emits the packet, a registrar can
regenerate and verify it against chain state with no operator involvement,
and the owner-records conformance gate references it. Institutional key
custody, Safe configuration, succession, and owner key-loss handling are
Operational guidance in
[`docs/stream-long-term-architecture.md`](stream-long-term-architecture.md)
(ADR 0010 decision 6).

### Independent Preservation Lane [CMC-INDEPENDENT-ATTESTOR]

Long-term stewardship transfers to institutions precisely when platforms
die, so preservation evidence must be recordable without any platform role
(ADR 0011 decision R11). The `INDEPENDENT_ATTESTOR` class gives any
institution — owner or not — its own onchain preservation and fixity lane
that needs no operator configuration, no registry admission, and no live
governance, so the onchain preservation history of a work never terminates
at operator death.

1. Hosting and entry: `StreamCollectionAttestations` hosts the lane. Any
   address may write append-only `INDEPENDENT_FIXITY`,
   `INDEPENDENT_PRESERVATION_EVENT`, `INDEPENDENT_EXHIBITION`, and
   `INDEPENDENT_CONDITION` records (record types catalogued in
   the record-type catalog; the exhibition and condition types added by
   ADR 0012 decision T8) against any token, media, or collection
   subject derived per [CMC-SUBJECT-ID]. Entry is permissionless by
   design: no role grant, allowlist, collection policy, lock, freeze, or
   finality state can block the lane, and it keeps working in read-only
   museum mode with governance gone.
2. Every write is `SIGNER_VERIFIED` in the attestor's own name: a direct
   call (`attestor == msg.sender`) or a relayed submission verifying the
   named attestor's EIP-712 signature (nonzero, exact-match recovery) or
   ERC-1271 approval under [CMC-SIGVER-GGP], with an unordered
   per-attestor nonce and deadline. Attestor nonces follow the
   owner-record keyed-nonce model verbatim ([CMC-OWNER-RECORDS] rule 9;
   ADR 0012 decision T7): a per-attestor consumed-value map (bitmap
   permitted) consuming exactly the named value in any order, the
   explicit-address replay view
   `isIndependentAttestorNonceUsed(address attestor, uint256 nonce)`,
   and signer-scoped revocation —
   `revokeIndependentAttestorNonce(nonce)` from the attestor, or a
   relayed attestor-signed revocation under the pinned revocation
   typehash below — emitting `IndependentAttestorNonceRevoked`
   (schemaVersioned, at most three indexed fields). The pinned relayed
   typehashes are:

   ```solidity
   bytes32 constant STREAM_INDEPENDENT_PRESERVATION_TYPEHASH =
       0xcb13914f7a4c90b3e2d3d1513c3009284117ccab71b2a60935a620486947c768;
       // keccak256("StreamIndependentPreservationRecord(address attestor,
       //   uint256 scopeKey,bytes32 subjectId,bytes32 recordType,
       //   bytes32 schemaId,uint16 algorithmId,bytes digest,
       //   bytes32 canonicalizationId,string uri,bytes payload,
       //   uint64 effectiveAt,uint256 nonce,uint64 deadline)")
       // (typehash string contains no whitespace or line breaks)

   bytes32 constant STREAM_INDEPENDENT_PRESERVATION_REVOCATION_TYPEHASH =
       0x4522059fc24afcc4dadcbf6fc6e0c577c17c5faf11aa8d03b270af3369d3359c;
       // keccak256("StreamIndependentPreservationRevocation(
       //   address attestor,uint256 nonce,uint64 deadline)")
       // (typehash string contains no whitespace or line breaks)
   ```

   The EIP-712 domain is `name = "6529StreamCollectionAttestations"`,
   `version = "1"`, the chain ID, and the hosting satellite address as
   `verifyingContract`; both typehashes, the domain, and CI recomputation
   tests enter the protocol v1 domain-constants table.
3. Attribution and weighting: each record is emitted through
   `IndependentPreservationRecordRecorded` (schemaVersioned, at most three
   indexed fields, carrying the record, record hash, chain hash, attestor
   address, and `authorizationClass = INDEPENDENT_ATTESTOR`). The payload
   carries the attestor's own identity evidence (institution record, DID,
   or key references). Consumers weight independent evidence by attestor
   identity; it is never operator-vouched truth, and no quality gate
   exists by design — filtering is a consumer concern, spam costs gas and
   affects nothing.
4. Payload schemas: fixity payloads use the fixity profile shape
   (`FixityCheckRef` semantics); preservation events use the PREMIS
   profile [CMC-PREMIS-PROFILE]; exhibition payloads use the
   `STREAM_EXHIBITION_V1` schema and condition payloads the
   `STREAM_CONDITION_REPORT_V1` schema ([CMC-GENESIS-SCHEMAS]),
   attestor-attributed (ADR 0012 decision T8). A museum running its own
   fixity program on mirrored payloads has a protocol home for the
   results, the evidence round-trips into OAIS-modeled repositories, and
   a borrowing or post-operator institution documents its own display
   and examination of a work in its own lane — no owner cooperation, no
   operator-configured `INSTITUTION_SIGNER` grant, and no live
   governance required for exhibition history to keep accruing.
5. Firewall: independent records are firewalled exactly like owner records
   ([CMC-OWNER-RECORDS] rule 4) — they cannot change default `tokenURI()`
   output, renderer resolution, artwork finality, royalties, minting,
   transfers, or ownership, and no renderer read set serving the default
   view may include them.
6. Completeness: independent lanes maintain `STREAM_RECORD_CHAIN_V1`
   accumulators per subject scope key and record type in the hosting
   satellite [CMC-RECORD-CHAIN], their heads join the `STATE_EXPORT` leaf
   set, and the object dossier export includes independent records keyed
   by the token's subject ID [CMC-OBJECT-DOSSIER].

### Exhibition And Loan Records [CMC-EXHIBITION-LOAN]

`EXHIBITION` and `LOAN` are typed record schemas, not loose URI fields
(ADR 0010 decision 6). They are documentation-only: no display
authorization, no custody transfer, no return enforcement.

1. The `EXHIBITION` schema records: exhibiting institution (address, DID,
   or institution record reference), venue and location reference,
   exhibition title reference, opening and closing dates, the display
   parameters used (referencing the `ARTIST_INTENT` record where one
   exists), and catalogue/wall-label references — each as URI plus
   `HashRef`.
2. The `LOAN` schema records: lender and borrower identities, loan window,
   insurance and condition references, an outbound and a return
   `CONDITION_REPORT` reference, and return conditions. A loan record
   documents custody context; ERC-721 ownership is unaffected.
3. Token-scoped exhibition and loan history is written by the current owner
   through [CMC-OWNER-RECORDS]. Collection-scoped exhibition context
   (a whole series in a show) is written through the collection record
   primitive under the `CURATOR_*`/`INSTITUTION_*` families [CMC-AUTHZ].
   A non-owner institution — a borrower, or any museum documenting its
   own display or examination — writes in its own name through the
   independent lane's `INDEPENDENT_EXHIBITION`/`INDEPENDENT_CONDITION`
   types [CMC-INDEPENDENT-ATTESTOR], with the same schemas, so
   exhibition documentation never requires owner mediation or an
   operator-configured role (ADR 0012 decision T8).
4. Lender and borrower may each countersign through general attestations
   referencing the loan record's hash, giving both sides durable evidence
   that outlives either institution.

### Mementos And Attendance Artifacts [CMC-MEMENTO]

Soulbound and lockable tokens are successor-line-only, so exhibition
mementos, attendance artifacts, and wallet-bound artist proofs have one
blessed in-ecosystem pattern instead of improvised external contracts
(ADR 0011 decision R9): they are attestation records, not transfers.

1. Exhibition and attendance mementos are `StreamCollectionAttestations`
   records (or owner-record `EXHIBITION` entries where the owner writes
   them) against the existing token, collection, or exhibition scope
   subject, carrying the recipient address, occasion reference, and
   artifact payload hash — inside the event catalog, record-chain, export,
   and preservation guarantees every other record enjoys.
2. Wallet-bound artist proofs are artist-signed attestations naming the
   honored address, written under artist authority per
   [CMC-ARTIST-ATTESTATION]; they bind identity by signature, not by a
   non-transferable token.
3. The pattern is documentation-plus-records at the Operational layer: it
   mints nothing, transfers nothing, and cannot affect `tokenURI()`,
   finality, royalties, or ownership. A future memento token contract, if
   ever wanted, is a separate accepted non-Core module spec; its absence
   at genesis is intentional
   ([`docs/launch-v1-target-architecture.md`](launch-v1-target-architecture.md)
   exclusions).

### Object Dossier Export [CMC-OBJECT-DOSSIER]

The per-object dossier is exportable without bespoke tooling: the
`OBJECT_DOSSIER_V1` export profile is a schema-identified, hash-committed
manifest for one token bundling: canonical identity (chain ID, Core,
token ID, collection ID, serial, citation string), finality and
content-root proofs, entropy provenance, the token's collection-level
manifests (script, dependency, media), all records and attestations keyed
by the token's subject ID with their record-chain heads, owner records,
independent-lane records, the ownership-provenance chain
([CMC-ACQUISITION-PACKET] item 10), the work-description (tombstone)
record [CMC-TOMBSTONE], the latest drill outcome for script works
([CMC-ACQUISITION-PACKET] item 11), and
attribution state. Dossier exports are produced by the same Operational
export tooling as `STATE_EXPORT`, packaged per [CMC-PACKAGING], and are
part of the museum-mode read
story; a registrar can regenerate and verify one against chain state with
no operator involvement.

That operator-independence claim is gated, not aspirational (ADR 0012
decision T8):

1. The dossier and packet emission/verification tool is a preservation
   artifact under the reconstruction-client discipline: its source
   archive, reproducible build instructions, and test vectors are
   mirrored under the dual-family archival rule with its hash recorded
   in `streamSystemManifest()`, and the conformance-matrix Operations
   gate verifies presence and hash equality exactly as it does for the
   reconstruction client ([LTA-RECON] requirement 2 and [LTA-ARCHIVE]
   in
   [`docs/stream-long-term-architecture.md`](stream-long-term-architecture.md)).
   Folding dossier and packet emission into the gated reconstruction
   client itself also satisfies this rule.
2. The museum-mode and preservation drill lists include a
   packet-regeneration step: regenerate a `STREAM_ACQUISITION_PACKET_V1`
   from chain state with zero operator involvement, verify every pinned
   component, and reference the result in the drill report.
3. A conformance-matrix row tests packet regeneration end to end —
   generation from chain state, then component-by-component
   verification including record-chain heads, the content-root proof,
   the ownership-provenance chain, and the drill outcome — never only
   static worked-example schema validation.

### Dossier And Export Packaging [CMC-PACKAGING]

Repository ingest pipelines validate packages before they read
semantics; a dossier with pinned record schemas but no pinned packaging
makes every acquiring institution write bespoke glue, and fifty years of
institution-specific bundles defeats the interoperability the pinned
schemas buy (ADR 0012 decision T8). `STREAM_BAGIT_PROFILE_V1` is the
pinned genesis packaging profile [CMC-GENESIS-SCHEMAS] for
`OBJECT_DOSSIER_V1` bundles and `STATE_EXPORT` artifacts:

1. Serialization: an RFC 8493 BagIt bag. `manifest-sha256.txt` is
   required over every payload file (SHA-256 for repository-tool
   compatibility) along with `tagmanifest-sha256.txt`; Stream-native
   keccak256 digests ride in an additional `manifest-keccak256.txt`.
2. Required tag files: `bag-info.txt` carries `External-Identifier`
   (the canonical citation with its record-state qualifier
   [CMC-CITATION]), `Bagging-Date`, `Payload-Oxum`, and
   `Stream-Schema-Id`/`Stream-Schema-Hash` naming the bundle schema;
   `stream-manifest.json` (RFC 8785-canonical) carries the dossier or
   export manifest hash, the record-chain heads at packaging time, and
   the packaging tool reference.
3. `fetch.txt` may reference content-addressed payloads (`ipfs://`,
   `ar://`) instead of embedding them only where each entry's bytes are
   committed in the payload manifest rows and covered by the
   dual-family archival rule; the packaged work's render-critical
   payloads must be embedded or dual-family mirrored, never fetch-only
   against a single storage family.
4. OCFL mapping: one dossier bag maps to one OCFL object whose object
   ID is the canonical citation; each superseding dossier export is a
   new OCFL version whose content is the bag payload, so registrars on
   OCFL storage roots ingest without translation:

   | Stream artifact | BagIt element | OCFL element |
   | --- | --- | --- |
   | canonical citation [CMC-CITATION] | `bag-info.txt` `External-Identifier` | OCFL object id |
   | dossier/export manifest hash | `stream-manifest.json` | version state commitment |
   | payload files | `data/` plus `manifest-sha256.txt` | version content plus inventory digests |
   | record-chain heads [CMC-RECORD-CHAIN] | `stream-manifest.json` | inventory `fixity` supplement |
   | superseding export | new bag | new OCFL version |

5. The registered profile document ([CMC-GENESIS-SCHEMAS] rule 1)
   carries the full element-by-element profile with a worked example
   bag, and the packet-regeneration matrix row ([CMC-OBJECT-DOSSIER])
   validates emitted bags against the profile.

### Canonical Citation Profile [CMC-CITATION]

Scholarly and registrar reference needs one blessed citation form
(ADR 0010 decision 6). This section is its normative home.

1. The canonical work citation is the CAIP-19-shaped string
   `eip155:<chainId>/erc721:<coreAddress>/<tokenId>`, with `coreAddress`
   in lowercase hex and both numbers in decimal. Example:
   `eip155:1/erc721:0xabc...def/123`.
2. A record-state citation appends `@` plus a pinned type prefix plus a
   hex `bytes32`, so a future reader resolves the hash in one namespace
   instead of searching three (ADR 0011 decision R11): `@fin:0x...` is a
   finality record hash, `@snap:0x...` a snapshot manifest hash, and
   `@chain:0x...` a record-chain head. Example:
   `eip155:1/erc721:0xabc...def/123@fin:0x5e4d...`. The three prefixes
   are the closed v1 qualifier vocabulary; an untyped `@0x...` qualifier
   is nonconformant. The qualifier is mirrored in
   `properties.stream.citation` and covered by the renderer citation test
   ([`docs/metadata-router-and-renderer.md`](metadata-router-and-renderer.md)).
3. Successor declarations never re-identify works: the original
   `chainId:core:tokenId` triple remains the permanent citation forever,
   and successor lines carry a cross-reference from the successor back to
   the original citation. A 2070 citation of a 2026 work cites the 2026
   contract.
4. Recovered routes are cited as the original citation plus the recovery
   manifest hash as the record state — a recovery never mints a new
   citation identity.
5. The default token JSON exposes the work citation as
   `properties.stream.citation`
   ([`docs/metadata-router-and-renderer.md`](metadata-router-and-renderer.md)),
   and the spec bundle republishes this profile for offline use.

## Genesis Museum Schema Set [CMC-GENESIS-SCHEMAS]

The registrar surface is only as durable as its schemas: two institutions
writing against unpinned families produce mutually unintelligible dossiers,
and a 2075 archivist must inherit a data dictionary, not a list of family
names. Every named museum record family therefore ships pinned
(ADR 0011 decision R11):

1. For each family below, genesis pins: a schema ID (the `keccak256` of
   the listed name string, entering the record-type and numeric ID
   catalogs), the canonical JSON Schema document (RFC 8785 canonicalized,
   registered as onchain document bytes in the schema registry
   [CMC-SCHEMA-REGISTRY]), and at least one worked example in the spec
   bundle. A family whose genesis schema document is missing cannot be
   written ([CMC-AUTHZ] rule 6 applies), and a conformance-matrix row
   verifies the presence and document hashes of the full set at genesis.
2. The genesis set and each schema's minimal required fields:

   | Schema name | Minimal required fields (home) |
   | --- | --- |
   | `STREAM_ACCESSION_V1` | accession identifier, acquiring-institution reference, and the `TITLE_BINDING` instrument binding of [CMC-OWNER-RECORDS] rule 8 |
   | `STREAM_CONDITION_REPORT_V1` | the protocol-verifiable condition core of rule 3 below |
   | `STREAM_EXHIBITION_V1` | the exhibition fields of [CMC-EXHIBITION-LOAN] rule 1 |
   | `STREAM_LOAN_V1` | the loan fields of [CMC-EXHIBITION-LOAN] rule 2, including outbound and return `CONDITION_REPORT` references |
   | `STREAM_DEACCESSION_V1` | deaccession reason class, disposition reference, and the `TITLE_BINDING` instrument binding |
   | `STREAM_CITATION_RECORD_V1` | the cited work's canonical citation with typed record-state qualifier [CMC-CITATION], citing-work reference, and context note |
   | `STREAM_ARTIST_INTENT_V1` | the intent fields of [CMC-ARTIST-INTENT] rule 1, including the interview entry |
   | `STREAM_ARTIST_INTENT_WAIVER_V1` | waiver statement hash and scope, per [CMC-ARTIST-INTENT] rule 2 |
   | `STREAM_OBJECT_DOSSIER_V1` | the dossier bundle of [CMC-OBJECT-DOSSIER] |
   | `STREAM_ACQUISITION_PACKET_V1` | the packet contents of [CMC-ACQUISITION-PACKET] |
   | `STREAM_RIGHTS_V1` | the rights record of [CMC-RIGHTS-SCHEMA] |
   | `STREAM_PREMIS_V3_PROFILE` | the crosswalk of [CMC-PREMIS-PROFILE] |
   | `STREAM_REFERENCE_RENDER_V1` | the reference-render record of [CMC-FINALITY-INPUTS] rule 5: captures, execution-environment manifest, archived environment artifact references, and the pinned acceptance mode |
   | `STREAM_IIIF_P3_MIN_V1` | the archival IIIF profile of [CMC-IIIF] |
   | `STREAM_WORK_DESCRIPTION_V1` | the tombstone fields of [CMC-TOMBSTONE] rule 1 (ADR 0012 decision T8) |
   | `STREAM_BAGIT_PROFILE_V1` | the packaging profile of [CMC-PACKAGING] (ADR 0012 decision T8) |

3. `STREAM_CONDITION_REPORT_V1` anchors every condition report to
   reproducible protocol state, so outbound and return condition records
   are comparable across institutions and usable in a dispute
   (ADR 0011 decision R11). Required fields: examination date and
   examiner reference; the work citation with its record-state qualifier
   at examination time; the `verifyFinality`/route-match result at
   examination; the latest fixity-cycle status covering the token's
   payloads [CMC-FIXITY-PROGRAM]; the render-verification outcome and
   method under the work's pinned acceptance mode
   ([CMC-FINALITY-INPUTS] rule 5), or an explicit not-verified statement;
   and the free-text condition narrative. A digital condition report that
   omits the verifiable state is a free-text opinion, not a conformant
   record.
4. Schema documents are versioned and superseded through the schema
   registry lineage rules; a revised family is a new schema ID, and old
   payloads keep verifying under the schema they named.

### Rights Records [CMC-RIGHTS-SCHEMA]

Reproduction and publication rights are a mandatory line on every
acquisition checklist and loan agreement; a registrar cannot catalogue
"see licenseURI" as a rights status. `STREAM_RIGHTS_V1` is the pinned,
machine-readable genesis rights schema (ADR 0011 decision R11), written as
`RIGHTS_STATEMENT` records through the record primitive under the
`RIGHTS_*` authority family [CMC-AUTHZ]:

1. Required fields: a rights basis from the closed vocabulary
   `copyright | license | statute | public_domain | contract |
   unspecified`; a licensor identity reference (artist ID, estate,
   institution, or address, with instrument reference); one grant entry
   per use class for each of `reproduction`, `publication`, `exhibition`,
   `print`, `derivative`, and `ai_training`; effective dates; and the
   legal instrument URI plus `HashRef` where an instrument exists.
2. Each per-use-class grant carries a value from the closed vocabulary
   `granted | granted_with_conditions | denied | unspecified`, an optional
   conditions text or URI-plus-hash, and optional free-text extensions.
   The `AI_TRAINING_PERMISSION` custom field, where used, must carry the
   same closed vocabulary; prose-only values are nonconformant.
3. Finality existence rule: finality at any scope, for every works
   class — artist-bound and `PLATFORM_WORKS` alike — requires a recorded
   `RIGHTS_STATEMENT` under this
   schema for the finality scope ([CMC-FINALITY-INPUTS] rule 11;
   platform-works inclusion by ADR 0012 decision T8). Museums acquire
   artist-less and estate works constantly, and reproduction rights
   status is a mandatory acquisition and loan line regardless of works
   class; for platform works the licensor identity names the platform
   or rights-holding entity. A
   record declaring every grant `unspecified` satisfies the rule: the
   requirement makes reserved rights an explicit, dated declaration
   rather than an absence a 2075 estate — or a museum acquiring an
   artist-less work — must litigate around. The acquisition packet
   carries the derived rights-completeness status
   ([CMC-ACQUISITION-PACKET] item 7).
4. Rights records are notice and evidence, never onchain enforcement; the
   posture and moral-rights statement of the Rights And Provenance
   guidance apply unchanged, and material changes publish superseding
   records with snapshot coverage rather than overwrites.

### Work Description (Tombstone) Records [CMC-TOMBSTONE]

Registrar events reference a work; a catalogue raisonné and a museum
tombstone describe one, and descriptive metadata is what they are built
on first. Without a pinned descriptive schema, two institutions
cataloguing the same Stream work produce non-interoperable records — the
exact mutually-unintelligible-dossiers failure the genesis set exists to
prevent (ADR 0012 decision T8). `STREAM_WORK_DESCRIPTION_V1` is the
pinned, CDWA-Lite/LIDO-informed tombstone schema, written as
`WORK_DESCRIPTION` records through the record primitive against token-
or collection-scoped subjects [CMC-SUBJECT-ID]:

1. Required fields: work-level title (which may differ from the display
   default of collection name plus serial); artist/creator reference
   (the registry `artistId` where one exists, otherwise a named-creator
   statement); creation date or date range; medium/format statement
   (for digital objects, the registry-linked format identification of
   [CMC-PREMIS-PROFILE] rule 4 plus a human-readable medium line);
   dimensions or duration (pixel dimensions, aspect ratio, runtime, or
   an explicit `dimensionless_generative` statement); edition statement
   (unique, serial N of M, or an open-series statement); and credit
   line. Optional fields: inscription/signature description, alternate
   titles, and language-tagged variants.
2. Authority: `WORK_DESCRIPTION` records are writable under artist
   authority (the `ARTIST_*` rules — artist-signed, so the artist's own
   tombstone is first-class evidence) or curatorial authority (the
   `CURATOR_*` rules) [CMC-AUTHZ]; the event's `authorizationClass`
   permanently distinguishes the two. Records are append-only with
   supersession lineage, and owner or independent lanes may carry their
   own descriptive statements in their own names, never edits of
   another's. As a meaning-bearing family, tombstones are written
   through the payload-carrying record write [CMC-RECORD-PAYLOAD].
3. The record is a named component of the object dossier
   [CMC-OBJECT-DOSSIER] and the acquisition packet
   ([CMC-ACQUISITION-PACKET] item 12), and pre-finality tooling warns
   when an artist-bound collection approaches finality without one.

## Lock Model [CMC-LOCKS]

The current single `collectionFreeze` is too broad for a 50-year metadata
system. `StreamCollectionMetadata` should support one-way locks by key.

Recommended lock IDs:

```text
keccak256("METADATA_ALL")
keccak256("DISPLAY_METADATA")
keccak256("MEDIA_MANIFEST")
keccak256("BASE_URI")
keccak256("SCRIPT")
keccak256("DEPENDENCIES")
keccak256("ARTIST_IDENTITY")
keccak256("ARTIST_ATTESTATION")
keccak256("GENERAL_ATTESTATIONS")
keccak256("PRESERVATION_RECEIPTS")
keccak256("SCHEMA_REGISTRY")
keccak256("SNAPSHOTS")
keccak256("VIEWS")
keccak256("CUSTOM_FIELD:<fieldKey>")
```

Implementation can represent locks as:

```solidity
mapping(uint256 collectionId => mapping(bytes32 lockId => bool locked)) locks;
```

Rules:

1. Locks are one-way.
2. `METADATA_ALL` blocks all mutable metadata updates.
3. Field-specific locks block only that field or group.
4. Core collection freeze never implies a metadata lock (ADR 0009
   decision 20). Locks are explicit only, and the locks or snapshots a
   collection's policy promises (`SNAPSHOTS`, and `METADATA_ALL` where
   promised) must be in place before Core freeze, per rules 7 and 8.
   Implied side effects are hidden coupling; the architecture forbids them
   everywhere else.
5. Script and dependency locks should be strongly encouraged before final
   collection freeze.
6. Preservation receipts may remain appendable after display metadata is frozen
   if the collection policy wants ongoing archive maintenance.
7. In the v1 generic metadata satellite, locking an ordinary `recordType`
   also blocks snapshots that declare the same `recordType`. `SNAPSHOTS` and
   `METADATA_ALL` block snapshot publication across all record families.
8. After Core collection freeze, the v1 generic satellite still permits
   ordinary `recordType` locks so an operator can seal the specific final
   metadata family that was just snapshotted. Broad `SNAPSHOTS` and
   `METADATA_ALL` locks are freeze-specific terminal controls and must be set
   before Core freeze if the collection policy requires them.
9. `ARTIST_IDENTITY` locks the collection's binding reference into the
   artist authority registry — which artist record this collection is bound
   to — not the artist's keys. Key rotation, delegated signers, estate
   succession, and dormancy transitions continue inside the bound artist
   record per [`docs/stream-artist-authority.md`](stream-artist-authority.md), so a locked identity plus
   a lost key never orphans the artist-gated surface. Post-lock authority
   transitions are registry events, clearly dated, and never rewrite
   pre-transition attestations; posthumous estate statements are recorded
   as estate statements, never as retroactive artist acts.
10. No collection lock — including `METADATA_ALL` — blocks the owner-record
    surface of [CMC-OWNER-RECORDS], the independent preservation lane
    [CMC-INDEPENDENT-ATTESTOR], or the artist authority registry's own
    lifecycle: operators cannot lock owners out of their object files,
    institutions out of their preservation lanes, or artists out of their
    identity records.
11. Content locks are not operator-exclusive: the bound artist holds the
    content freeze of [CMC-ARTIST-CONTENT-VETO], which applies the
    `SCRIPT`, `DEPENDENCIES`, and `MEDIA_MANIFEST` locks under artist
    authority.

### Artist Content Veto [CMC-ARTIST-CONTENT-VETO]

Between mint and finality the artwork's bytes must not be
operator-mutable against the artist's will: policy consent binds
mintability, and this section binds content (ADR 0011 decision R7). Who
can change the art is answered "not the platform alone" for every
artist-bound collection.

1. Scope: the content-affecting surfaces of an artist-bound collection are
   the script manifest and chunks, the dependency manifest, the media
   manifest and render-affecting media fields, render-affecting view
   manifests, and — on the router side — renderer assignment, metadata
   mode, and render-context selection
   ([`docs/metadata-router-and-renderer.md`](metadata-router-and-renderer.md)
   [MRR-ADMIN]).
2. Standing co-signature, per consent mode: from the first mint of the
   collection (or of the affected scope) until executed finality,
   content-affecting mutations for an `ARTIST_SIGNED_POLICY` collection
   require a verified artist co-signature — a state-bound authorization
   over the exact resulting content state, verified through the artist
   authority registry under the authority chain and collaborator policy
   of [`docs/stream-artist-authority.md`](stream-artist-authority.md);
   operator-only mutation of these surfaces is nonconformant. For
   `ARTIST_DELEGATED` collections the co-signature may come from an
   active delegation with the content capability; the standing freeze
   right of rule 3 applies in both modes. Before first mint, operator
   iteration remains free: nothing sold can yet be rewritten, and the
   artist's attestation staleness and refusal levers already cover the
   pre-sale window.
3. Artist content freeze: the artist authority may unilaterally seal their
   collection's content at any time after binding acceptance — the
   defensive analog of the royalty freeze. A verified artist-signed
   content-freeze authorization (typed payload and authority chain owned
   by [`docs/stream-artist-authority.md`](stream-artist-authority.md))
   is relayable by any caller to this contract, which must verify it
   against the registry and apply the `SCRIPT`, `DEPENDENCIES`, and
   `MEDIA_MANIFEST` locks, recording the freeze with the artist's
   authority class. The right is freeze-only: it cannot unfreeze, cannot
   alter content, and cannot touch other collections.
4. Firewall and precedence: the veto never blocks non-content surfaces —
   preservation records, owner records, attestations, rights records, and
   the independent lane continue under their own rules — and it never
   blocks a hash-bound recovery executed under a public recovery manifest,
   which for artist-bound collections requires artist or estate
   participation per the recovery rules of the umbrella spec. Locks
   applied under this section are ordinary one-way locks of this Lock
   Model.
5. Every veto surface is evented: co-signed mutations record the artist
   authorization reference in the mutation event, and artist-applied
   locks emit `CollectionMetadataLocked` with the artist's authority
   class, so a 2075 reader can distinguish operator-sealed from
   artist-sealed content.

## Mutation API [CMC-MUTATIONS]

Avoid magic indexes. Use explicit functions. For artist-bound collections,
content-affecting writes in this ABI are additionally subject to the
artist content veto [CMC-ARTIST-CONTENT-VETO].

```solidity
function setCollectionIdentity(
    uint256 collectionId,
    CollectionIdentity calldata identity
) external;

function setCollectionPeople(
    uint256 collectionId,
    CollectionPeople calldata people
) external;

function setCollectionMedia(
    uint256 collectionId,
    CollectionMedia calldata media
) external;

function setMediaManifest(
    uint256 collectionId,
    MediaManifest calldata manifest
) external;

function setCollectionURIs(
    uint256 collectionId,
    CollectionURIs calldata uris
) external;

function setCollectionRights(
    uint256 collectionId,
    CollectionRights calldata rights
) external;

function setCollectionDisplay(
    uint256 collectionId,
    CollectionDisplay calldata display
) external;

function setCollectionField(
    uint256 collectionId,
    bytes32 key,
    CollectionFieldValue calldata field
) external;

function setCollectionFieldWithRevision(
    uint256 collectionId,
    bytes32 key,
    CollectionFieldValue calldata field,
    bytes32 reasonCode,
    uint64 effectiveAt
) external;

function setCollectionViewManifest(
    uint256 collectionId,
    bytes32 viewId,
    CollectionViewManifest calldata manifest
) external;

function setBaseURI(
    uint256 collectionId,
    string calldata baseURI
) external;

function setScriptManifest(
    uint256 collectionId,
    ScriptManifest calldata manifest
) external;

function replaceScriptChunks(
    uint256 collectionId,
    string[] calldata chunks,
    bytes32 scriptHash
) external;

function setScriptChunk(
    uint256 collectionId,
    uint256 index,
    string calldata chunk,
    bytes32 scriptHash
) external;

function setDependencyManifest(
    uint256 collectionId,
    DependencyManifest calldata manifest
) external;

function submitArtistAttestation(
    uint256 collectionId,
    uint8 subjectKind,
    bytes32 subjectId,
    bytes32 subjectStateHash,
    bytes32 statementHash,
    bytes32 statementURIHash,
    bytes32 schemaId,
    bytes calldata statement
) external;

function submitArtistAttestationFor(
    uint256 collectionId,
    uint8 subjectKind,
    bytes32 subjectId,
    bytes32 subjectStateHash,
    bytes32 statementHash,
    bytes32 statementURIHash,
    bytes32 schemaId,
    bytes calldata statement,
    address signer,
    bytes calldata signature
) external;

function recordCollectionAttestation(
    uint256 collectionId,
    CollectionAttestation calldata attestation
) external;

function setCollectionRecord(
    uint256 collectionId,
    CollectionRecord calldata record
) external returns (bytes32 recordHash);

function setCollectionRecordWithRevision(
    uint256 collectionId,
    CollectionRecord calldata record,
    uint64 expectedRevision
) external returns (bytes32 recordHash);

function recordCollectionRecord(
    uint256 collectionId,
    CollectionRecord calldata record
) external;

function recordCollectionRecordWithPayload(
    uint256 collectionId,
    CollectionRecord calldata record,
    bytes calldata payload
) external returns (bytes32 recordHash);

function publishCollectionSnapshot(
    uint256 collectionId,
    bytes32 snapshotId,
    bytes32 schemaId,
    string calldata manifestURI,
    bytes32 manifestHash,
    bytes calldata manifestData,
    uint64 effectiveFrom
) external;

function publishTokenContentRoot(
    uint256 collectionId,
    bytes32 scopeSubject,
    bytes32 contentRoot,
    uint64 leafCount,
    bytes32 schemaId,
    string calldata manifestURI,
    bytes32 manifestHash
) external;

function lockCollectionField(
    uint256 collectionId,
    bytes32 lockId
) external;
```

`manifestData` is the canonical snapshot manifest bytes: the contract stores
them in an SSTORE2 blob, verifies `keccak256(manifestData)` against
`manifestHash` for the v1 `HASH_KECCAK256` default, exposes the blob
pointer through the storage-backed `snapshotManifestPointer` read
[CMC-PAYLOAD-POINTERS], and emits it, so every snapshot that can feed a
finality `dataHash` is reconstructable — and locatable — from chain state
alone (ADR 0010 decision 4; ADR 0012 decision T3). Owner-record
writes live in `StreamOwnerRecords` [CMC-OWNER-RECORDS], not in this ABI.

If script chunks use external blob contracts, script write functions can accept
blob pointers instead of strings.

Typed convenience writes such as `recordArchiveReceipt`,
`recordPreservationEvent`, `recordFixityCheck`, `recordC2PAReference`, and
`recordMediaRelationship` may be added in a companion module under its own
accepted spec. In v1 they should be represented through
`recordCollectionRecord` with a schema ID and content hash — or through
`recordCollectionRecordWithPayload` where the family is meaning-bearing
[CMC-RECORD-PAYLOAD].

## Read API

The renderer needs efficient reads. The frontend needs human-friendly reads.
Both should be supported without forcing every caller to decode huge tuples.

Recommended read functions:

```solidity
function collectionIdentity(uint256 collectionId)
    external
    view
    returns (CollectionIdentity memory);

function collectionPeople(uint256 collectionId)
    external
    view
    returns (CollectionPeople memory);

function collectionMedia(uint256 collectionId)
    external
    view
    returns (CollectionMedia memory);

function mediaManifest(uint256 collectionId)
    external
    view
    returns (MediaManifest memory);

function collectionURIs(uint256 collectionId)
    external
    view
    returns (CollectionURIs memory);

function collectionRights(uint256 collectionId)
    external
    view
    returns (CollectionRights memory);

function collectionDisplay(uint256 collectionId)
    external
    view
    returns (CollectionDisplay memory);

function name(uint256 collectionId) external view returns (string memory);
function description(uint256 collectionId) external view returns (string memory);
function artistAddress(uint256 collectionId) external view returns (address);
function artistDisplayName(uint256 collectionId) external view returns (string memory);
function imageURI(uint256 collectionId) external view returns (string memory);
function baseURI(uint256 collectionId) external view returns (string memory);
function contractURI(uint256 collectionId) external view returns (string memory);
function collectionMetadata(uint256 collectionId)
    external
    view
    returns (CollectionMetadataView memory);
```

Script reads:

```solidity
function scriptManifest(uint256 collectionId)
    external
    view
    returns (ScriptManifestView memory);

function scriptChunkCount(uint256 collectionId) external view returns (uint256);
function scriptChunk(uint256 collectionId, uint256 index)
    external
    view
    returns (string memory);
```

Custom reads:

```solidity
function collectionField(uint256 collectionId, bytes32 key)
    external
    view
    returns (CollectionFieldValue memory);

function collectionFieldHash(uint256 collectionId, bytes32 key)
    external
    view
    returns (bytes32);

function collectionFieldKeyCount(uint256 collectionId)
    external
    view
    returns (uint256);

function collectionFieldKeyAt(uint256 collectionId, uint256 index)
    external
    view
    returns (bytes32);

function collectionViewManifest(uint256 collectionId, bytes32 viewId)
    external
    view
    returns (CollectionViewManifest memory);
```

The hash read is useful for cheap verification and indexer checks.

Stewardship reads:

```solidity
function latestAttestationHash(
    uint256 collectionId,
    bytes32 attestationType,
    address attester
) external view returns (bytes32);

function latestCollectionRecordHash(
    uint256 collectionId,
    bytes32 recordType,
    bytes32 subjectId
) external view returns (bytes32);

function latestSnapshotHash(uint256 collectionId)
    external
    view
    returns (bytes32);

function snapshotHash(uint256 collectionId, bytes32 snapshotId)
    external
    view
    returns (bytes32);

function recordChainHash(uint256 collectionId, bytes32 recordType)
    external
    view
    returns (bytes32 chainHash, uint64 recordCount);

function artistAttestationCurrent(uint256 collectionId)
    external
    view
    returns (
        bool current,
        bytes32 attestationRecordHash,
        bytes32 attestedSubjectStateHash
    );

function tokenContentRoot(uint256 collectionId, bytes32 scopeSubject)
    external
    view
    returns (bytes32 contentRoot, uint64 leafCount, bytes32 schemaId);
```

Protocol v1 does not need typed storage reads for every historical attestation,
archive receipt, preservation event, fixity check, C2PA reference, or media
relationship. Events are the canonical append-only history, and the per-lane
record-chain accumulators [CMC-RECORD-CHAIN] make any recovered event set
provably complete against state. Read slots should focus on latest generic
record hashes, chain heads, active snapshots, and values renderers or
frontends need in a single call.

## Events [CMC-EVENTS]

Events are part of the product surface. They let frontends and indexers track
metadata over decades. Exactly one event exists per fact; optional mirror
events are banned at genesis under the matrix-owned event policy
([`docs/launch-conformance-matrix.md`](launch-conformance-matrix.md)
[LCM-EVENTS]; ADR 0011 decision R12), and every mirror relationship is
mandatory and tagged in the event catalog.

Recommended events:

```solidity
event CollectionMetadataContractUpdated(address indexed oldContract, address indexed newContract);

event CollectionMetadataSet(
    uint256 indexed collectionId,
    bytes32 indexed schemaId
);

event CollectionIdentitySet(
    uint256 indexed collectionId,
    bytes32 indexed schemaId,
    string slug
);

event CollectionPeopleSet(
    uint256 indexed collectionId,
    address indexed artistAddress
);

event CollectionMediaSet(
    uint256 indexed collectionId,
    bytes32 mediaHash
);

event CollectionMediaManifestSet(
    uint256 indexed collectionId,
    bytes32 imageHash,
    bytes32 animationHash,
    bytes32 contentHash,
    bytes32 manifestHash
);

event CollectionURIsSet(
    uint256 indexed collectionId,
    string baseURI,
    string contractURI
);

event CollectionRightsSet(
    uint256 indexed collectionId,
    bytes32 provenanceHash
);

event CollectionDisplaySet(
    uint256 indexed collectionId,
    bytes32 indexed displayProfileId,
    bytes32 indexed rendererCompatibility
);

event CollectionFieldSet(
    uint256 indexed collectionId,
    bytes32 indexed key,
    bytes32 indexed fieldType,
    bytes32 valueHash
);

event CollectionFieldRevision(
    uint256 indexed collectionId,
    bytes32 indexed key,
    bytes32 oldValueHash,
    bytes32 newValueHash,
    bytes32 indexed reasonCode,
    address actor,
    uint64 effectiveAt
);

event CollectionViewManifestSet(
    uint256 indexed collectionId,
    bytes32 indexed viewId,
    bytes32 indexed schemaId,
    bytes32 contentHash
);

event CollectionBaseURISet(
    uint256 indexed collectionId,
    string baseURI
);

event CollectionScriptManifestSet(
    uint256 indexed collectionId,
    bytes32 indexed scriptHash,
    bytes32 indexed rendererCompatibility
);

event CollectionScriptChunkSet(
    uint256 indexed collectionId,
    uint256 indexed index,
    bytes32 chunkHash
);

event CollectionDependencyManifestSet(
    uint256 indexed collectionId,
    bytes32 indexed dependencyId,
    bytes32 dependencyHash
);

event ArtistAttestationSubmitted(
    uint256 indexed collectionId,
    address indexed signer,
    uint8 indexed subjectKind,
    bytes32 subjectId,
    bytes32 subjectStateHash,
    bytes32 statementHash,
    bytes32 statementURIHash,
    bytes32 schemaId,
    uint8 authorityClass,
    bool relayed,
    uint16 schemaVersion
);

event CollectionAttestationRecorded(
    uint256 indexed collectionId,
    bytes32 indexed attestationType,
    address indexed attester,
    bytes32 attestationId,
    bytes32 statementHash,
    string statementURI,
    bytes32 signatureScheme,
    bytes32 signatureHash,
    bytes32 schemaId
);

event CollectionRecordRecorded(
    uint256 indexed collectionId,
    bytes32 indexed recordType,
    bytes32 indexed subjectId,
    CollectionRecord record,
    bytes32 recordHash,
    bytes32 recordChainHash,
    address recorder,
    bytes32 authorizationClass,
    uint16 schemaVersion
);

event CollectionSnapshotPublished(
    uint256 indexed collectionId,
    bytes32 indexed snapshotId,
    bytes32 indexed schemaId,
    string manifestURI,
    bytes32 manifestHash,
    address manifestPointer,
    uint64 effectiveFrom,
    uint16 schemaVersion
);

event TokenContentRootPublished(
    uint256 indexed collectionId,
    bytes32 indexed scopeSubject,
    bytes32 indexed contentRoot,
    uint64 leafCount,
    bytes32 schemaId,
    bytes32 manifestHash,
    uint16 schemaVersion
);

event CollectionMetadataLocked(
    uint256 indexed collectionId,
    bytes32 indexed lockId
);

event CollectionCoreStatusObserved(
    uint256 indexed collectionId,
    uint8 supplyMode,
    uint8 status,
    bool hasMaxSupply,
    uint256 maxSupply,
    uint256 mintedEver
);
```

The global `ContractURIUpdated()` is emitted by Core only, through the
restricted emitter posture of
[`docs/metadata-router-and-renderer.md`](metadata-router-and-renderer.md)
[MRR-EVENTS]; this contract emits no duplicate of that fact
(ADR 0011 decision R12). Collection-scoped contract metadata changes emit
`CollectionURIsSet`.

Event-only reconstruction rules [CMC-RECONSTRUCTION]:

1. Every v1 event that mutates a typed metadata group must emit enough
   payload data for event-only reconstruction, by emitting all changed
   fields directly or a deterministic delta record with schema ID,
   canonicalization ID, URI, and content hash.
2. The hash-and-URI loophole is closed for meaning-bearing families
   (ADR 0010 decision 4): identity- and render-affecting record families —
   collection identity, people, script manifests, dependency manifests,
   rights notices, view manifests, artist attestations and their signature
   bundles, and the content-root reference record (root, leaf count,
   schema ID, manifest URI, manifest hash) — must place the full canonical
   payload bytes in contract storage or SSTORE2 blobs (state-trie bytes),
   within the v1 byte limits, written through the payload-carrying record
   write [CMC-RECORD-PAYLOAD] or a surface with its own pinned bytes
   path; event-embedded copies never satisfy this
   rule, because EIP-4444-class history expiry can remove log data from
   serving nodes while state survives (ADR 0011 decision R1). Events
   remain the discovery pointers to the stored bytes. A hash of a
   collection's meaning is not the meaning; with operators gone and
   mirrors decayed, the state trie itself must still carry it. The
   per-token leaf-listing manifest behind a content root is not in this
   class: its home is [CMC-CONTENT-ROOT] rule 4 (dual-family archival),
   and it is recomputable from onchain per-token hashes wherever all leaf
   fields are onchain.
3. Hash-plus-URI-only records remain acceptable solely for payload classes
   that cannot fit on chain — media masters, archive packages,
   high-resolution captures — which must instead satisfy the dual-family
   archival mirroring rule before any finality that references them.
4. The recoverability condition applies to every emission form, including
   delta records: a hash-only or delta emission for a meaning-bearing
   family is conformant only when the full payload is recoverable from an
   immutable onchain read (contract storage or SSTORE2) named by a
   storage-backed pointer read [CMC-PAYLOAD-POINTERS], with the event as
   indexer convenience (ADR 0011 decision R1; ADR 0012 decision T3).
   Same-transaction event copies are
   indexer convenience, never the conformance carrier: "recoverable from
   an immutable onchain read" means state, the only carrier the
   with-operators-gone guarantee may cite — and locatable from state,
   because a pointer that only an expirable log names is not a
   with-operators-gone carrier either.
5. Every record lane's completeness is provable against the
   [CMC-RECORD-CHAIN] accumulator, so reconstruction can prove it missed
   nothing.

`CollectionArchiveReceiptRecorded`, `CollectionPreservationEventRecorded`,
`CollectionFixityCheckRecorded`, `CollectionC2PAReferenceRecorded`, and
`CollectionMediaRelationshipRecorded` are candidate typed events for
companion modules under separate accepted specs. The genesis metadata
contract can emit only `CollectionRecordRecorded` for those record families
and still preserve the same offchain schema semantics through `recordType`,
`subjectId`, and `schemaId`. `OwnerRecordRecorded` and
`OwnerRecordNonceRevoked` are emitted by
`StreamOwnerRecords` [CMC-OWNER-RECORDS],
`IndependentPreservationRecordRecorded` and
`IndependentAttestorNonceRevoked` by the independent-lane host
[CMC-INDEPENDENT-ATTESTOR], and `CollectionBurnsBlocked` by Core
[CMC-BURN]; all five join the event catalog.

The metadata router or Core should also emit ERC-4906-style events where token
metadata may change:

```solidity
event MetadataUpdate(uint256 _tokenId);
event BatchMetadataUpdate(uint256 _fromTokenId, uint256 _toTokenId);
```

## Admin And Authorization

Use ADR 0004 governance/action roles rather than inventing a second admin
system. Legacy selector-map `StreamAdmins` authorization is nonconformant for
protocol v1.

Recommended permissions:

```text
setCollectionIdentity       collection metadata admin or global admin
setCollectionPeople         collection metadata admin or global admin
setCollectionMedia          collection metadata admin or global admin
setMediaManifest            collection metadata admin or global admin
setCollectionURIs           collection metadata admin or global admin
setCollectionRights         collection metadata admin or global admin
setCollectionDisplay        collection metadata admin or global admin
setCollectionField          collection metadata admin or global admin
setCollectionFieldWithRevision collection metadata admin or global admin
setCollectionViewManifest   collection metadata admin or global admin
setBaseURI                  collection metadata admin or global admin
setScriptManifest           script admin or global admin
replaceScriptChunks         script admin or global admin
setScriptChunk              script admin or global admin
setDependencyManifest       script admin or global admin
submitArtistAttestation     artist-scoped signer per [CMC-ARTIST-ATTESTATION]
recordCollectionAttestation record-family authority per [CMC-AUTHZ]
setCollectionRecord         record-family authority per [CMC-AUTHZ]
setCollectionRecordWithRevision record-family authority per [CMC-AUTHZ]
recordCollectionRecord      record-family authority per [CMC-AUTHZ]
recordCollectionRecordWithPayload record-family authority per [CMC-AUTHZ]
publishCollectionSnapshot   collection metadata admin with authority over
                            every snapshotted family per [CMC-AUTHZ]
publishTokenContentRoot     collection metadata admin or global admin
recordOwnerRecord           current token owner per [CMC-OWNER-RECORDS]
recordOwnerRecordFor        anyone, with the owner's verified signature
lockCollectionField         freeze admin or global admin
```

Record-family-scoped authorization [CMC-AUTHZ]:

The CON-015 whole-module writer exception is retired (ADR 0010 decision 2).
Genesis record writes — `setCollectionRecord`,
`setCollectionRecordWithRevision`, `recordCollectionRecord`, and
`publishCollectionSnapshot` — are authorized per record family, in the
generic satellites themselves, not through whole-module safe-operator
grants. A single writer role that can publish identity, rights, C2PA/PREMIS,
snapshot, and archive records for every collection in the module does not
exist in protocol v1; the shared-durable-authorization static gate applies
with no metadata exception.

The genesis record-family authority table is normative:

```text
ARTIST_*                  accepted artist, authorized collaborator threshold,
                          artist-granted delegate, or estate successor —
                          resolved through the artist authority registry;
                          admins are rejected
OWNER_*                   current token owner (ownerOf-gated,
                          signature-verified); admins are rejected
INDEPENDENT_*             any attestor writing in its own name
                          (permissionless entry, SIGNER_VERIFIED,
                          attestor-attributed) [CMC-INDEPENDENT-ATTESTOR];
                          no role can block or impersonate the lane
CURATOR_*                 configured curator signer/admin or global admin
INSTITUTION_*             configured institution signer (SIGNER_VERIFIED)
RIGHTS_*                  rights admin or global admin
ARCHIVE_*                 preservation admin or global admin
FIXITY_*                  preservation admin, configured verifier, or global admin
C2PA_*                    configured provenance verifier/admin or global admin
IIIF_*                    preservation admin, collection metadata admin, or global admin
MEDIA_RELATIONSHIP_*      preservation admin or collection metadata admin
IDENTITY_* / DISPLAY_*    collection metadata admin or global admin
SNAPSHOT_*                collection metadata admin or global admin, and only
                          over record families the caller may write
AGENT_*                   agent metadata admin or global admin
```

Authorization rules:

1. `ARTIST_*` and `OWNER_*` families reject every admin and operator role,
   including the global admin: artist-scoped writes verify the signer
   through the artist authority registry
   ([`docs/stream-artist-authority.md`](stream-artist-authority.md)), and owner-scoped writes verify
   `ownerOf` [CMC-OWNER-RECORDS]. `INDEPENDENT_*` writes verify the named
   attestor's own signature [CMC-INDEPENDENT-ATTESTOR]. Operator
   compromise can therefore never fabricate artist-, owner-, or
   independent-authored provenance — the append-only corpus stays
   classifiable by authority even under a hostile writer.
2. Content-affecting families and writes for artist-bound collections are
   additionally subject to the artist content veto between first mint and
   executed finality [CMC-ARTIST-CONTENT-VETO] (ADR 0011 decision R7):
   holding a script, media, or metadata admin role is necessary but not
   sufficient on those surfaces.
3. Snapshot publication over a record family requires write authority over
   that family, because snapshots feed finality `dataHash` inputs; there is
   no snapshot super-role.
4. Every record event carries `recorder` and `authorizationClass` so
   consumers can permanently weight each record by who could have written
   it, and the release manifest states per family whether records are
   `SIGNER_VERIFIED` or `OPERATOR_ASSERTED` [CMC-ATTESTATIONS].
5. The record-family permission map is deployment configuration verified by
   a conformance gate: the ceremony evidence enumerates each family's
   granted signers, and drift between the map and this table fails the
   gate.
6. New record families are admitted through registry governance with their
   authority class declared at admission; a family without a declared
   class cannot be written.

No record family is writable without verified authority in protocol v1 —
`OWNER_*` is owner-permissioned, not open, and the independent
preservation lane is open-entry but strictly attestor-attributed and
signer-verified: nobody writes in anyone else's name, and no independent
record can affect consensus surfaces [CMC-INDEPENDENT-ATTESTOR]. If a
collection later wants public collector notes or community annotations,
that should be a separate moderated module, under its own accepted spec,
whose records cannot affect tokenURI, renderer output, artwork finality,
rights, royalties, minting, or ownership.

Every mutation must check:

1. The collection exists in Core.
2. The caller holds record-family authority for the written family per the
   table above (whole-module authority does not exist).
3. The relevant lock is not active.
4. The input is structurally valid.

### Metadata Signature Verification Gas [CMC-SIGVER-GGP]

`StreamCollectionMetadata`, `StreamCollectionAttestations`, and
`StreamOwnerRecords` verify ERC-1271 signatures onchain at write time
(artist attestations, `SIGNER_VERIFIED` attestation families, relayed
owner records, the independent lane). Sibling subsystems each instantiate
a named verification-gas parameter; the metadata satellites instantiate
theirs here (ADR 0011 decision R10), so the repricing checklist and the
matrix GGP gate cover this surface instead of leaving it to a hard-coded
cap:

1. `METADATA_ERC1271_VERIFY_GAS` is a Governed Gas Parameter under the
   model home,
   [`docs/stream-long-term-architecture.md`](stream-long-term-architecture.md)
   [LTA-GGP] (ADR 0010 decision D1): floors, raise/lower classes, probes,
   change events, release-manifest recording, repricing-checklist
   membership, and the Operational-layer exclusion follow the home
   unchanged. Each verifying metadata satellite hosts its own
   storage-backed value of the parameter; the shared immutable floor is
   `METADATA_ERC1271_VERIFY_GAS_FLOOR`.
2. The floor and genesis value are sized from the measured supported
   wallet class — the one home for that class is
   [GOV-1271-CLASS] in
   [`docs/adr/0004-admin-governance.md`](adr/0004-admin-governance.md);
   this document defines no wallet class of its own. Initial planning
   values match the artist registry's measured Safe n-of-m class: a
   90,000-gas floor and a 150,000-gas genesis value, with deployment
   recording measured values per host in the release manifest.
3. Every ERC-1271 verification in these satellites uses the EIP-150 63/64
   parent-gas precheck against the current parameter value, capped
   returndata copying (32 bytes), and exact magic-value comparison;
   failure, out-of-gas, malformed returndata, or a wrong magic value
   reverts the submission before any state change. EOA verification
   (`ecrecover`, nonzero exact-match) does not consume the parameter.
4. The health probe for lowering is a recorded verification sweep over
   the heaviest named wallet classes at the proposed value, per host.
5. The parameter identifier follows [LTA-GGP]:

   ```solidity
   bytes32 constant GGP_METADATA_ERC1271_VERIFY_GAS_ID =
       0x3ca324ef8262b1ff4cb8753a082cd8780e50f754c1a323a433e0e7665a5ec9f9;
       // keccak256("6529STREAM_GGP_METADATA_ERC1271_VERIFY_GAS")
   ```

   The parameter joins the [LTA-GGP] inventory (hosts: the three
   verifying metadata satellites; normative home: this section) and the
   protocol v1 domain-constants mirror table, and the matrix GGP gate's
   floor/raise/lower/probe tests run against every host.
6. The parameter's release-manifest failure-direction class is
   `FAIL_CLOSED_PRECHECK` ([LTA-GGP] requirement 10): rule 3
   verification failure reverts the submission, so raises are
   governance-only and registering a permissionless conditional raise
   is nonconformant (ADR 0012 decision T1). The rule 4 probe is a
   Permanent-class probe contract ([LTA-GGP-PROBES]) proving a
   maximum-supported-class ([GOV-1271-CLASS]) verification completes
   with the magic value under exactly the probed cap for pinned fixture
   inputs, per host, with run records hosted on the probe and
   `evidenceHash` committing to the measurement artifact.

## Validation

Recommended v1 validations:

1. `collectionId` must exist in Core.
2. `schemaId` should be nonzero after final metadata setup.
3. `name` should be nonempty after final metadata setup.
4. `artistAddress` cannot be zero when setting artist identity.
5. URI fields should be syntactically valid enough for frontend use, or empty
   only when the relevant mode supports empty values.
6. `scriptHash` cannot be zero when onchain script chunks are set.
7. Stored script chunk hash must match the manifest hash policy.
8. `dependencyId` or `dependencyURI` must be present when dependency use is
   enabled.
9. Source type must be compatible with the populated URI, pointer, or chunk
   data.
10. Externally hosted rendering-critical scripts, dependencies, schemas, and
    media must have nonzero hash commitments before any final freeze or
    finality at any scope, and the finality scope must have a recorded
    token content root [CMC-CONTENT-ROOT]. This is a finality gate, not
    tooling advice.
11. Media MIME types should be present when the renderer emits `content` or
    media-specific properties.
12. Field keys cannot be zero.
13. `fieldType` should be nonzero for custom fields unless the field is being
    explicitly cleared.
14. `valueHash` should equal the canonical hash of `value` or the canonical
    external payload.
15. Locked fields cannot be mutated.
16. View manifests must have nonzero `viewId` and `schemaId` when active.
17. Snapshot IDs must be nonzero and unique for a collection.
18. Generic records must include nonzero `recordType`, nonzero `subjectId`, and
    either `contentHash`, URI, or both.
19. Attestation types must be nonzero, and attestation hashes must commit to
    the canonical signed or referenced payload.
20. Preservation manifests should identify object, event, agent, rights, fixity,
    relationship, and C2PA records through schema IDs and hashes.
21. `SIGNER_VERIFIED` attestation and record writes revert unless the
    EIP-712/ERC-1271 verification of [CMC-ATTESTATIONS] rule 3 passes.
22. Record `subjectId` values must recompute from the pinned subject
    domains for their declared scope class [CMC-SUBJECT-ID].
23. `C2PA_REFERENCE` validation records revert without validator identity,
    validator version, and report URI/hash; binding to the committed media
    hash is checked by the attestation gate [CMC-C2PA].
24. Snapshot publication reverts when `manifestData` is empty or does not
    match `manifestHash` under the declared v1 algorithm.
25. Independent-lane writes verify the named attestor (direct call or
    relayed signature under [CMC-SIGVER-GGP]), consume the named
    unordered `(attestor, nonce)` pair, and enforce the deadline and
    revocation state [CMC-INDEPENDENT-ATTESTOR].
26. `RIGHTS_STATEMENT` records must carry the closed rights-basis and
    grant vocabularies of [CMC-RIGHTS-SCHEMA]; unknown vocabulary values
    revert.
27. Content-affecting writes for artist-bound collections enforce the
    artist content veto between first mint and executed finality
    [CMC-ARTIST-CONTENT-VETO].
28. Payload-carrying record writes verify `contentHash` against the
    submitted bytes, respect `MAX_RECORD_PAYLOAD_BYTES`, and register
    the blob pointer; meaning-bearing families reject bytes-less writes
    [CMC-RECORD-PAYLOAD].

JSON and JavaScript escaping should happen in the renderer, not in this storage
contract. This contract should store canonical values.

## Renderer Integration

`StreamMetadataRouter` should call `StreamCollectionMetadata` for collection
metadata and then pass a compact context to the renderer.

Expected read path:

```text
StreamCore.tokenURI(tokenId)
  -> StreamMetadataRouter.tokenURI(core, tokenId)
  -> Core view reads collectionId and token facts
  -> StreamCollectionMetadata reads collection metadata and manifests
  -> StreamRendererV1 builds final JSON/HTML
```

Renderers should not read private Core storage, and Core should not rebuild
metadata strings.

Renderer-visible manifests include script, dependency, media, and schema
commitments. Token-level overrides may add their own media or properties, but
collection-level manifests are the default source for shared collection facts.
Alternate view manifests should be discoverable from collection metadata, but
the default renderer should only include them in token JSON as references unless
the active metadata mode explicitly renders that view.

## Contract URI

`contractURI` should be collection-scoped metadata, not a global-only string.
The metadata contract should expose:

```solidity
function contractURI(uint256 collectionId)
    external
    view
    returns (string memory);
```

The returned JSON should follow the ERC-7572 collection metadata shape where
possible:

```json
{
  "name": "...",
  "symbol": "...",
  "description": "...",
  "image": "...",
  "banner_image": "...",
  "featured_image": "...",
  "external_link": "...",
  "collaborators": []
}
```

Stream-specific collection facts should live under `properties.stream` or
another namespaced object rather than replacing the standard fields. If the
contract URI is an offchain URI rather than an onchain JSON data URI, the
metadata contract should store the URI and an optional schema/hash commitment.

Collection contract URI updates should emit collection-specific metadata events.
Protocol v1 adds `contractURI()` to Core as the canonical ERC-7572 hook — a
thin, bounded read delegated to the contract-metadata satellite through the
cached pointer policy (ADR 0009 decision 4). `ContractURIUpdated()` is
Core-originated through the same restricted emitter posture as the ERC-4906
refresh events (ADR 0009 decision 5). Collection-level contract metadata
remains available through `StreamCollectionMetadata.contractURI(collectionId)`
and token JSON references.

## Open Series Display

For open-ended collections, metadata should make the collection's public status
legible without pretending to be the minting authority.

Recommended display fields:

```text
CollectionIdentity.category = "photography" or another open category
CollectionIdentity.subtitle = "An ongoing photographic series"
EXHIBITION record = optional release, exhibition, or season context
  (typed schema per [CMC-EXHIBITION-LOAN], collection-scoped subject)
custom COLLECTION_KIND = "open-series"
custom SERIES_STATUS = "ongoing" | "paused" | "complete"
custom OPEN_SERIES_CONTEXT_URI = richer artist or curatorial statement
custom INTENDED_CADENCE = optional human-readable cadence such as "periodic"
custom SEASON_MANIFEST_URI = optional season-level manifest
custom SEASON_MANIFEST_HASH = hash of the season manifest
custom RELEASE_MANIFEST_URI = optional release/drop/chapter manifest
custom RELEASE_MANIFEST_HASH = hash of the release/drop/chapter manifest
```

These values are descriptive. Core `CollectionStatus` remains authoritative for
whether new tokens can mint.

Open-ended collections should not pretend every collection is an edition. A
long-running photographic practice can remain `ACTIVE`, publish periodic
season/release manifests, and later become `CLOSED` without rewriting the local
serials or historical season context.

## Schema And Longevity

The contract should treat schemas as versioned metadata, not as Solidity
redeployment requirements.

Recommended approach:

1. Use `bytes32 schemaId` in typed metadata.
2. Publish schema docs as both human-readable documentation and
   machine-readable JSON Schema.
3. Store schema URI/hash in typed metadata and, when useful, companion custom
   fields.
4. Let frontends, indexers, and agents understand known schemas while ignoring
   unknown fields.
5. Keep unknown `bytes32` keys queryable forever.
6. Namespace extensions so future fields do not shadow standard fields.
7. Set parser and payload size limits in tooling before collection activation.
8. Archive deprecated schemas rather than deleting or reinterpreting them.
9. Historical payloads continue to verify under the schema hash and
   canonicalization ID that were active when they were recorded.
10. A successor schema should publish `supersedesSchemaId`, schema URI/hash,
    canonicalization ID, migration notes URI/hash, and whether old fields are
    mapped, abandoned, or preserved only for history.

This gives the system room to evolve without hardcoding every future metadata
field in Solidity.

## V1 ABI Partitioning

`StreamCollectionMetadata` is the authoritative collection knowledge system,
but it does not have to place every long-term feature in one v1 ABI. If the
main metadata contract approaches its function-count, bytecode, or auditability
ceiling, these responsibilities should move to companion contracts named in the
system manifest and linked by schema/manifest hashes:

```text
StreamSchemaRegistry
StreamCollectionSnapshots
StreamCollectionAttestations
StreamCollectionViews
StreamPreservationRecords
```

The governing invariant is discoverability and integrity, not monolith size.
Core does not care which companion serves a snapshot, attestation, or
alternate view, as long as the collection metadata root, finality manifest,
event catalog, and system manifest identify the responsible module, interface
ID, code hash, schema ID, URI, and content hash.

## Canonical Hash Serialization

Hashes are only useful over decades if independent tools can reproduce them.

Default rules:

1. JSON payloads should use RFC 8785 JSON Canonicalization Scheme unless a
   schema explicitly defines a different canonical form.
2. CBOR payloads should use deterministic CBOR encoding.
3. Binary payloads hash the exact bytes as stored or transferred.
4. String payloads hash UTF-8 bytes with no BOM and no implicit trailing
   newline.
5. Structured onchain data uses `abi.encode` with explicit field order and type
   widths.
6. Authority hashes must not use `abi.encodePacked`, string concatenation, or
   display-order-dependent encodings.
7. The default hash algorithm is `keccak256` unless the field explicitly names
   another algorithm such as SHA-256 for external archive compatibility.
8. Empty or unknown payloads should omit the hash rather than emit a zero hash.
9. If a URI points to mutable transport such as HTTPS, a nonzero content hash is
   required before final freeze when the payload is render-critical,
   preservation-critical, or rights-critical.

Schemas may define additional canonicalization rules, but they must be
identified by `schemaId`, `schemaURI`, and `schemaHash`.

## V1 Limits

The metadata contract must choose finite v1 limits before implementation.
Recommended v1 hard maxima:

```text
MAX_SHORT_STRING_BYTES       1,024
MAX_URI_BYTES                2,048
MAX_LONG_TEXT_BYTES         16,384
MAX_TOKEN_DATA_BYTES        16,384
MAX_DIGEST_BYTES               128
MAX_ATTRIBUTES_JSON_BYTES   65,536
MAX_PROPERTIES_JSON_BYTES   65,536
MAX_CUSTOM_FIELDS              128
MAX_SIGNATURE_BUNDLE_BYTES   8,192
MAX_RECORD_PAYLOAD_BYTES    24,576   (one SSTORE2 blob; [CMC-RECORD-PAYLOAD])
MAX_SCRIPT_CHUNK_BYTES       8,192   (INLINE_CHUNKS storage)
MAX_SSTORE2_CHUNK_BYTES     24,576   (SSTORE2 chunk payload)
MAX_SCRIPT_CHUNKS               32
MAX_TOTAL_ONCHAIN_SCRIPT_BYTES 786,432
MAX_BATCH_MUTATIONS             50
```

`MAX_TOTAL_ONCHAIN_SCRIPT_BYTES` is 32 SSTORE2 chunks of 24,576 bytes
(ADR 0010 decision 4); the cap covers the per-collection artist script, and
dependency payloads resolved through the dependency registry are excluded.
The over-cap serving story and default `tokenURI()` byte cap are owned by
[`docs/metadata-router-and-renderer.md`](metadata-router-and-renderer.md).

The exact constants can change during implementation if tests prove better
values, but "unbounded" is not an acceptable v1 policy. Mutation functions
should revert with specific errors when a write exceeds the relevant limit.
Admin tooling should dry-run renderer output against
`MAX_DEFAULT_TOKEN_URI_BYTES = 24,576` before activation or final artwork
freeze. Larger archive/raw HTML/raw JSON outputs must use explicit alternate
views and must not be served through the default marketplace `tokenURI()` path.

Batch mutation limits apply to arrays of field updates, script chunks, custom
fields, locks, attestations, and snapshot records. Larger updates should be
split across transactions so event reconstruction remains practical.

## Schema Registry

`schemaId` should resolve to enough information for humans, indexers, renderers,
and agents to understand a payload years later.

Registry architecture [CMC-SCHEMA-REGISTRY]:

1. The append-only `StreamSchemaRegistry` satellite is the required genesis
   posture (ADR 0010 decision 4), not an optional upgrade: every
   verification path bottoms out in schema and canonicalization documents,
   and a manifest-pinned offchain file leaves the system's Rosetta stone to
   social mirroring.
2. Interpretation-critical catalog payloads — schema documents,
   canonicalization profile definitions, and the record-type catalog used
   by this specification — are stored as onchain bytes in contract storage
   or SSTORE2 blobs (state-trie bytes, never only event data — EIP-4444
   history expiry can remove logs while state survives; ADR 0011 decision
   R1), referenced from the registry and from `streamSystemManifest()`;
   hash-plus-URI alone is nonconformant for these catalogs, and events are
   discovery pointers only; document and catalog blob pointers are
   enumerable through the storage-backed pointer surface of
   [CMC-PAYLOAD-POINTERS] (ADR 0012 decision T3). The numeric ID and
   event catalogs follow the
   same onchain-bytes rule under their homes in
   [`docs/stream-long-term-architecture.md`](stream-long-term-architecture.md)
   and the conformance matrix.
3. Collections additionally store schema URI/hash in collection metadata for
   convenient reads; the registry bytes are authoritative.
4. The registry is append-only and deprecation-aware, never mutable in a way
   that silently changes what an old schema meant.

Recommended model:

```solidity
enum SchemaStatus {
    ACTIVE,
    DEPRECATED,
    ARCHIVED
}

struct CollectionSchema {
    bytes32 schemaId;
    string schemaURI;
    bytes32 schemaHash;
    bytes32 supersedesSchemaId;
    SchemaStatus status;
}
```

Recommended events:

```solidity
event CollectionSchemaRegistered(
    bytes32 indexed schemaId,
    bytes32 indexed supersedesSchemaId,
    bytes32 schemaHash,
    string schemaURI
);

event CollectionSchemaStatusChanged(
    bytes32 indexed schemaId,
    SchemaStatus status
);
```

Rules:

1. `schemaHash` commits to the canonical schema document.
2. `supersedesSchemaId` creates an explicit lineage without rewriting old
   collection metadata.
3. Deprecating a schema must not change old payload interpretation.
4. Schemas should describe typed fields, known custom fields, JSON fragments,
   attestation payloads, archive receipts, and view manifests.
5. Frontends and agents should ignore unknown fields they cannot understand,
   but they should surface unknown required fields when a schema declares them.

## Snapshots And Revision History

Collection metadata should be current and historical. A future collector,
museum, or estate should be able to answer: what did this collection claim at a
given point in time, and who changed it?

Recommended snapshot model:

```solidity
struct CollectionSnapshot {
    bytes32 snapshotId;
    bytes32 schemaId;
    string manifestURI;
    bytes32 manifestHash;
    uint64 effectiveFrom;
}
```

Rules:

1. A snapshot is a signed or admin-published manifest of collection metadata at
   a point in time. It should include enough URIs, hashes, and schema IDs to
   reconstruct the state without relying on one frontend.
2. Snapshots are append-only. Publishing a new snapshot does not mutate old
   snapshots.
3. `manifestHash` must commit to a canonical JSON or CBOR payload, and the
   canonical manifest bytes are stored onchain at publication — an SSTORE2
   blob whose pointer is exposed through the storage-backed
   `snapshotManifestPointer(collectionId, snapshotId)` read
   [CMC-PAYLOAD-POINTERS] and evented — so snapshot meaning never depends
   on offchain availability or on expirable logs (ADR 0010 decision 4;
   ADR 0012 decision T3).
4. Snapshot manifests should include typed metadata, custom fields, script and
   dependency manifests, media manifests, rights data, attestation references,
   archive receipts, and active view manifests.
5. `latestSnapshotId` and `latestSnapshotHash` are append-only history pointers,
   not a token rendering authority. If a Core-frozen collection needs
   collector-facing finality, operators must publish the final display snapshot
   before finality and then lock `SNAPSHOTS` or `METADATA_ALL` before Core
   freeze, or lock the relevant ordinary `recordType` after the final snapshot
   under the collection policy.
6. `CollectionFieldRevision` should be emitted for field changes where the old
   hash is known. Reason codes should be open `bytes32` values such as
   `TYPO_FIX`, `ARTIST_UPDATE`, `RIGHTS_UPDATE`, `ARCHIVE_UPDATE`,
   `SCHEMA_MIGRATION`, or `ADMIN_CORRECTION`.
7. `effectiveAt` should be explicit. It may equal the block timestamp, but the
   event should not force indexers to infer the intended effective time.
8. Freezing metadata should not erase the revision trail. It should make future
   unauthorized revisions impossible.

## Token Content Root

Finality without per-token content binding is nonconformant in every
metadata mode (ADR 0010 decision 4). A frozen `baseURI` proves which URI
was promised, not which artwork; the token content root is the per-token
proof.

Content root requirements [CMC-CONTENT-ROOT]:

1. Before any artwork finality at any scope — collection, token, release,
   season, or view, in `OFFCHAIN`, `ONCHAIN`, or hybrid mode — a token
   content root must be recorded covering every token in the finality
   scope: a Merkle root over one leaf per token.
2. The leaf preimage is pinned and domain-separated; this section is its
   normative home and the protocol v1 domain-constants table mirrors it:

   ```solidity
   bytes32 constant STREAM_TOKEN_CONTENT_LEAF_V1 =
       0x61d75cd1a57d24657b860f99f77c15e5f8556fb725b56a96dd770205f9352b0d;
       // keccak256("6529STREAM_TOKEN_CONTENT_LEAF_V1")

   bytes32 leaf = keccak256(abi.encode(
       STREAM_TOKEN_CONTENT_LEAF_V1,
       uint256(block.chainid),
       address(core),
       uint256(tokenId),
       bytes32(metadataHash),   // canonical token metadata JSON hash
       bytes32(imageHash),
       bytes32(animationHash),
       bytes32(contentHash),
       bytes32(tokenDataHash)
   ));

   bytes32 constant STREAM_TOKEN_CONTENT_NODE_V1 =
       0x7239fc0713b7ccc92b7eef3087150a1f32037aff6ab05f5bf78db4f8ab71a6ea;
       // keccak256("6529STREAM_TOKEN_CONTENT_NODE_V1")

   bytes32 node = keccak256(abi.encode(
       STREAM_TOKEN_CONTENT_NODE_V1, left, right
   ));
   ```

   Leaves are ordered by ascending `tokenId` with no duplicates; interior
   nodes pair left-to-right, an unpaired node is promoted unchanged to the
   next level, and a single-leaf tree's root is the leaf. The distinct node
   domain prevents leaf/node second-preimage confusion.
3. Hash semantics per field are declared by the content-root manifest's
   `schemaId`: for `OFFCHAIN` collections, `metadataHash` commits to the
   canonical per-token JSON bytes and the media hashes to the exact media
   payload bytes; for `ONCHAIN`/hybrid collections, `metadataHash` commits
   to the canonical rendered JSON (consistent with the golden render
   vectors) and media hashes to the committed media payloads. A leaf field
   with no corresponding asset is zero, and the schema states which fields
   are bound; every render-critical field must be nonzero at finality.
   For seed-dependent works — any work whose rendered output consumes
   the token seed — a leaf's `metadataHash` must commit to the
   finalized-entropy render; a leaf bound over a pending-entropy render
   is invalid (ADR 0012 decision T3). Finality at any scope is blocked
   while any token in the scope has a non-terminal entropy status under
   the `EntropyStatus` vocabulary of
   [`docs/stream-entropy-coordinator.md`](stream-entropy-coordinator.md),
   unless the finality manifest's allowed post-finality entropy state
   ([LTA-FINALITY] manifest item 8 in
   [`docs/stream-long-term-architecture.md`](stream-long-term-architecture.md))
   explicitly enumerates the affected tokens and pins the acceptance
   semantics under which their later entropy finalization is verified
   against the bound leaves. `verifyFinality` passing while the served
   artwork diverges from its bound leaf is the exact self-contradiction
   this rule closes.
4. The root is recorded through:

   ```solidity
   function publishTokenContentRoot(
       uint256 collectionId,
       bytes32 scopeSubject,     // [CMC-SUBJECT-ID] scope derivation
       bytes32 contentRoot,
       uint64 leafCount,
       bytes32 schemaId,
       string calldata manifestURI,
       bytes32 manifestHash
   ) external;

   // TokenContentRootPublished (schema defined once in the Events
   // section of this document) is emitted on every accepted publish.

   function tokenContentRoot(uint256 collectionId, bytes32 scopeSubject)
       external
       view
       returns (bytes32 contentRoot, uint64 leafCount, bytes32 schemaId);
   ```

   The onchain-bytes item for reconstruction is the content-root
   reference record itself — root, leaf count, schema ID, manifest URI,
   manifest hash — per [CMC-RECONSTRUCTION] rule 2. The leaf-listing
   manifest (URI plus hash, canonical bytes preserved under the
   dual-family archival rule; this rule is its home) lists every leaf's
   field values so any tool can recompute the root, and it is
   recomputable from onchain per-token hashes wherever all leaf fields
   are onchain; `leafCount` must equal the token count of the scope at
   finality execution.
5. Content roots are append-only per scope subject: a corrected root for a
   not-yet-final scope supersedes with lineage; the root bound by an
   executed finality record is immutable, and the finality registry
   verifies the recorded root and leaf count during
   `finalizeCollectionArtwork` or scoped finality.
6. Collection-scope finality is forbidden while any render-critical payload
   of the collection resolves through mutable transport without a content
   hash bound in the root — hash-committing the URI string alone does not
   satisfy this rule.
7. Roots may be committed incrementally, well before any finality
   ceremony: an `OFFCHAIN`-mode collection selling while open publishes
   superseding roots (rule 5 lineage) so that every minted token is
   covered by the latest root at sale time, satisfying the mint-time
   binding rule of [MRR-OFFCHAIN-BINDING] in
   [`docs/metadata-router-and-renderer.md`](metadata-router-and-renderer.md)
   (ADR 0011 decision R2). Token-level `HashRef`s under
   [CMC-TOKEN-METADATA] are the per-token alternative carrier for the
   same commitment.

## Artwork Finality Inputs

`StreamCollectionMetadata` should expose the metadata-side facts required by
the `StreamArtworkFinalityRegistry.finalizeCollectionArtwork` flow in
`docs/stream-long-term-architecture.md`.

At minimum, the metadata contract should implement `IStreamFinalityComponent`
or expose a finality-ready read that a small finality adapter can translate
into `FinalityComponentState`. That state must include the metadata contract
address, interface ID, code hash, module version, manifest hash, and one
`dataHash` committing to:

1. collection metadata root or latest snapshot hash;
2. script source type, script chunk count, script bytes hash, and script
   manifest hash;
3. dependency source identity, dependency version, and dependency payload hash;
4. media manifest URI/hash and primary image/animation/content hashes;
5. active schema ID, schema URI, and schema hash;
6. view manifest hashes for views included in the finality manifest;
7. lock/freeze state for artwork-affecting fields;
8. the token content root, leaf count, and content-root schema for the
   finality scope [CMC-CONTENT-ROOT];
9. post-finality exception policy, if any.

The `dataHash` must be reproducible from onchain reads and hash-committed
manifests. It is the value the finality registry compares against the submitted
`FinalityComponentExpectation`.

Finality rules [CMC-FINALITY-INPUTS]:

1. A collection cannot be finalized while any artwork-affecting metadata field
   remains mutable outside the declared exception policy.
2. Finality emits a metadata-side event and should be paired with the
   finality-registry `CollectionArtworkFinalized` event, including the same
   `componentsHash`.
3. Frozen onchain collections must publish an assembled snapshot manifest hash
   over script, dependency, media, renderer context, metadata roots, and entropy
   policy before Core-linked finality can execute.
4. Every finality scope, in every metadata mode, requires the recorded
   token content root of [CMC-CONTENT-ROOT] covering the scope's tokens;
   the finality registry verifies root and leaf count at execution.
5. Script-based works (`ONCHAIN` and hybrid) require a recorded
   `REFERENCE_RENDER` record — pinned schema `STREAM_REFERENCE_RENDER_V1`
   [CMC-GENESIS-SCHEMAS] — before finality (ADR 0010 decision 6;
   ADR 0011 decision R3). The record binds four things:

   (a) Captures: at least one hash-committed reference output capture per
   pinned token sample (or all tokens), mirrored across two storage
   families.

   (b) Execution-environment manifest: renderer build, render context
   version, browser/engine version, viewport, device pixel ratio, color
   space, and capture toolchain.

   (c) Archived environment artifact: the manifest must reference a
   hash-committed, runnable execution-environment archive — a container
   image or the browser/engine build plus capture toolchain it names —
   recorded as a preservation object with fixity coverage and mirrored
   under the dual-family archival rule. A version string without a
   preserved binary is a citation, not an environment: re-render
   verification and the emulation strategies contemplated by
   `ARTIST_INTENT` depend on obtaining the named runtime decades out.

   (d) Acceptance mode: exactly one per-work re-render acceptance mode,
   pinned at finality, drawn from the acceptance-mode vocabulary whose
   home is [LTA-FINALITY] requirement 12 in
   [`docs/stream-long-term-architecture.md`](stream-long-term-architecture.md)
   (ADR 0011 decision R3) — `BYTE_EXACT`, `PERCEPTUAL_TOLERANCE`, or
   `CURATED_EQUIVALENCE`. The record stores the mode plus its
   parameters: the named perceptual/structural metric and threshold for
   `PERCEPTUAL_TOLERANCE`, and the conservator-attestation reference
   against the `ARTIST_INTENT` significant properties for
   `CURATED_EQUIVALENCE`. The `CURATED_EQUIVALENCE` conservator
   attestation carries a pinned evidentiary class (ADR 0012 decision
   T8): it is `SIGNER_VERIFIED`, recorded either as an
   `INSTITUTIONAL_VERIFICATION` attestation under a configured
   `INSTITUTION_SIGNER` ([CMC-ATTESTATIONS] rule 3) or as an
   `INDEPENDENT_CONDITION` record in the independent lane
   [CMC-INDEPENDENT-ATTESTOR], and its schema payload must carry
   examiner identity evidence — institution reference, examiner name,
   and credential reference (DID, registry, or professional-body
   identifier) — plus the field-by-field evaluation against the
   `ARTIST_INTENT` significant properties. An `OPERATOR_ASSERTED`
   equivalence record never satisfies this mode, at finality or in a
   drill; drill outcome classification under this mode references the
   verifying attestation. Mode semantics — including the pinned
   software-rasterization precondition for `BYTE_EXACT` and the
   `DYNAMIC`-renderer-class exclusion from `BYTE_EXACT`
   ([`docs/metadata-router-and-renderer.md`](metadata-router-and-renderer.md)
   [MRR-DETERMINISM]) — are owned by [LTA-FINALITY] requirement 12 and
   are not restated here; a record violating them is rejected at
   finality.

   Preservation drills verify re-renders under the pinned mode and
   classify each outcome `MATCH`, `TOLERABLE_VARIANCE`, or `DIVERGENT`
   per the drill-outcome vocabulary of [LTA-RECON] requirement 4 —
   never bare pass/fail on bytes — and at least one drill step must boot
   an archived environment artifact and reproduce a reference capture.
   For `OFFCHAIN` collections the record is tooling-warned, not
   required.
6. Collections with a bound artist require the `ARTIST_SANCTION` finality
   component defined in [`docs/stream-artist-authority.md`](stream-artist-authority.md) (ADR 0010
   decision 2) and an `ARTIST_INTENT` record or artist-signed waiver
   [CMC-ARTIST-INTENT].
7. Collection-scope finality additionally requires Core status `CLOSED`
   plus the one-way burn block, verified through
   `collectionBurnsBlocked(collectionId)` [CMC-BURN].
8. Every attestation and signature bundle referenced by the finality
   manifest must satisfy the bundle-preservation rule of
   [CMC-ATTESTATIONS] rule 10 before finality executes.
9. Deprecated metadata schemas or storage modules may keep serving finalized
   collections. They must not reinterpret historical snapshot hashes.
10. Preservation-only records may remain appendable after finality if the
    finality manifest explicitly allows that surface and those records cannot
    change artwork bytes; owner records and the independent preservation
    lane remain appendable regardless [CMC-OWNER-RECORDS]
    [CMC-INDEPENDENT-ATTESTOR].
11. Finality for every collection — artist-bound and `PLATFORM_WORKS`
    alike (ADR 0012 decision T8) — requires a recorded
    `RIGHTS_STATEMENT` record under the pinned
    `STREAM_RIGHTS_V1` schema for the finality scope
    [CMC-RIGHTS-SCHEMA] (ADR 0011 decision R11). A record declaring every
    grant `unspecified` satisfies the requirement; absence blocks
    finality, so rights status is always an explicit dated declaration,
    and the acquisition packet types the completeness status
    ([CMC-ACQUISITION-PACKET] item 7).
12. Non-script media works receive conservation gating, not only byte
    fixity (ADR 0012 decision T2) — codec and container obsolescence,
    not bit-rot, is their dominant fifty-year loss mode, and byte-exact
    fixity of an unplayable file preserves nothing a visitor can see.
    For any finality scope containing time-based media (video, audio,
    interactive capture) or other non-script render-critical media:
    (a) each such object's `formatId` must satisfy the
    registry-linked format identification of [CMC-PREMIS-PROFILE]
    rule 4; (b) a significant-properties record — the
    `SIGNIFICANT_PROPERTIES_URI`/`SIGNIFICANT_PROPERTIES_HASH` fields
    backed by a schema-identified payload naming frame rate, color
    space, audio characteristics, duration, interaction affordances,
    and display parameters — must be recorded before finality, so the
    "should" of the PREMIS guidance is a "must" for time-based media at
    finality; and (c) the collection should record a
    preservation-master object (`SOURCE_MASTER`/`PRINT_MASTER` role)
    distinct from the display derivative, with its presence or absence
    surfaced as a typed acquisition-packet field
    ([CMC-ACQUISITION-PACKET] item 8).

## Multiple Canonical Views

The default `tokenURI()` response should remain marketplace-friendly and
deterministic. That should not be the only view of a serious collection.

The metadata contract should support view manifests that describe alternative
canonical presentations without changing the ERC-721 identity model.

Recommended model:

```solidity
struct CollectionViewManifest {
    bytes32 viewId;
    bytes32 schemaId;
    string uri;
    bytes32 contentHash;
    string mimeType;
    bool defaultForView;
}
```

Example `viewId` values:

```text
keccak256("MARKETPLACE")
keccak256("GALLERY")
keccak256("ARCHIVE")
keccak256("PRINT")
keccak256("ACCESSIBILITY")
keccak256("MOBILE")
keccak256("AR")
keccak256("VR")
keccak256("RAW_JSON")
keccak256("RAW_HTML")
keccak256("AGENT")
```

Rules:

1. `StreamCore.tokenURI()` returns the default marketplace-compatible view.
2. Alternate views should be discovered through metadata fields, manifests, or
   future view-specific read functions rather than by overloading `tokenURI()`.
3. View manifests should include schema IDs and hashes so clients can validate
   them without trusting a URL.
4. A view can point to onchain renderer output, IPFS, Arweave, HTTPS, IIIF, or
   another source type if the payload has a suitable integrity commitment.
5. Accessibility views are first-class, not afterthoughts. They can include alt
   text, captions, transcripts, reduced-motion variants, high-contrast variants,
   or language-specific metadata.
6. Archive and print views may be more detailed than marketplace metadata and
   may expose high-resolution or conservation-specific material according to
   the collection's rights policy.

## Rights And Future Policy

Rights metadata should be explicit but not brittle. A collection can live across
changes in law, marketplaces, AI norms, licensing standards, artist estates, and
institutional custody.

Recommended approach:

1. Keep the stable typed fields in `CollectionRights`, and record the
   machine-readable rights baseline as `RIGHTS_STATEMENT` records under
   the pinned `STREAM_RIGHTS_V1` schema [CMC-RIGHTS-SCHEMA]
   (ADR 0011 decision R11).
2. Use custom fields for policy surfaces likely to evolve:
   `COMMERCIAL_RIGHTS_URI`, `AI_TRAINING_PERMISSION`,
   `DERIVATIVE_RIGHTS_URI`, `PRINT_RIGHTS_URI`, `EXHIBITION_RIGHTS_URI`,
   `ATTRIBUTION_REQUIREMENTS_URI`, `ESTATE_CONTACT_URI`, and related future
   keys — as display supplements to the schema'd record, with
   `AI_TRAINING_PERMISSION` carrying the closed grant vocabulary of
   [CMC-RIGHTS-SCHEMA] rule 2.
3. Require hashes for policy documents that materially affect collectors,
   artists, licenses, or institutional usage.
4. Use snapshots when a rights policy materially changes so older policy states
   remain inspectable.
5. Treat rights fields as metadata and notice, not as a full legal enforcement
   engine; the moral-rights posture is stated in the Rights And Provenance
   guidance.
6. Allow collection policies to freeze rights fields independently from archive
   receipts, so preserved facts can continue to accumulate without rewriting the
   license.

## 50-Year Stewardship Requirements

The implementation should optimize for graceful aging:

1. Unknown fields must remain queryable and non-breaking.
2. Important external payloads should have hashes.
3. Every schema used by a collection should be recoverable by URI/hash.
4. Every render-critical script, dependency, media object, and schema should be
   representable by a manifest with source type and integrity data.
5. Old snapshots and old schema IDs should never be reinterpreted silently.
6. Events should let independent indexers reconstruct metadata state even if
   6529 frontends change.
7. Preservation receipts should be appendable over time unless explicitly
   locked.
8. Admin tooling should warn before freezing metadata that lacks schema hashes,
   script hashes, media hashes, archive records, or a published snapshot.
9. The contract should avoid assuming today's marketplaces, URI schemes,
   storage networks, signature standards, or display devices are final.

## Reserved Extension Surfaces

The genesis metadata contract should leave clear extension points for
Replaceable-layer modules added through separate accepted specs, without
implementing them in Core:

1. Post-mint parameters may use custom fields such as
   `POST_MINT_PARAMS_SCHEMA_URI`, `POST_MINT_PARAMS_SCHEMA_HASH`, and
   `POST_MINT_PARAMS_MODULE`.
2. Dynamic onchain traits may use custom fields such as
   `DYNAMIC_TRAITS_MODULE` and `DYNAMIC_TRAITS_SCHEMA_URI`, but ordinary display
   traits should remain in token `attributes`.
3. Specialized view modules added through separate accepted specs may extend
   v1 view manifests with token-specific views, live views, programmable view
   negotiation, or raw onchain HTML/JSON reads. They should build on
   `CollectionViewManifest` rather than changing `StreamCore.tokenURI()`.
4. Token-bound account integration may use `TOKEN_BOUND_ACCOUNT_REGISTRY` and
   token-level metadata fields when a concrete product use case exists.
5. Agent-readable metadata may use `AGENT_MANIFEST_URI`,
   `AGENT_MANIFEST_HASH`, and schema fields that describe how tools should
   inspect, render, validate, or explain a collection.

Except for the v1 view-manifest support specified above, these are reserved
conventions excluded from protocol v1, not v1 requirements. They should be
implemented as separate accepted modules that read Core and metadata
interfaces.

## Bytecode Impact

This section is non-normative implementation evidence per
[`docs/spec-policy.md`](spec-policy.md); measurements are point-in-time and
superseded by the release-artifact size proofs.

Measured scratch compile:

```text
Current StreamCore runtime:                       23,398 bytes
After renderer/script extraction:                 19,568 bytes
After renderer + collection metadata extraction:  15,973 bytes
Incremental collection metadata savings:           3,595 bytes
Total savings after #1 and #2:                     7,425 bytes
```

The exact deployed savings will change after final implementation, but the
direction is clear: dynamic collection metadata and script storage should not
live in Core.

## Implementation Phases

### Phase 1: Contract Skeleton

1. Add `IStreamCollectionMetadata`.
2. Add `StreamCollectionMetadata`.
3. Add Core pointer to the metadata contract.
4. Add rich typed metadata groups.
5. Add schema ID, schema URI, and schema hash commitments.
6. Add registry-compatible schema events or a companion registry interface.
7. Add group-specific reads and writes.
8. Add collection existence checks through Core.

### Phase 2: Script, Dependency, And Media Manifests

1. Move library URI and dependency ID out of Core.
2. Move script chunks out of Core.
3. Add script hash and compatibility metadata.
4. Add payload source types.
5. Add dependency hash, source, MIME, and version metadata.
6. Add media manifest URI/hash/MIME data.
7. Update the metadata router/renderer to read manifests.

### Phase 3: Open Fields And Locks

1. Add typed custom field values.
2. Add custom field key enumeration.
3. Add field-level locks.
4. Add view manifests.
5. Add artist attestations.
6. Add generalized attestations.
7. Add generic collection records for archive, preservation, fixity, C2PA,
   relationship, rights, and cultural records.
8. Add genesis companion contracts for preservation records, attestations, and
   view references when those surfaces would push `StreamCollectionMetadata`
   past its function-count, bytecode, or auditability ceiling.
9. Keep PREMIS/C2PA/IIIF typed structs out of Core; represent them through
   schema/hash commitments or companion ABIs with explicit module manifests.
10. Add IIIF/view manifest conventions.
11. Add snapshot publication.
12. Add rich events and metadata refresh hooks.

### Phase 4: Core Cleanup

1. Remove `collectionInfo` from Core.
2. Remove `retrieveCollectionInfo` from Core or replace with compatibility-free
   new reads through `StreamCollectionMetadata`.
3. Remove `retrieveCollectionLibraryAndScript` from Core.
4. Move artist signature state out of Core.
5. Keep only Core collection facts required by mint/burn/token behavior,
   including supply mode, collection status, and collection-local serials.

## Test Plan

Core integration tests:

1. Core can set the collection metadata contract only by authorized admin.
2. Core tokenURI still works through router after metadata extraction.
3. Collection existence and token collection IDs remain Core-owned.
4. `totalSupply()` remains correct across mint and burn; Core exposes no
   `tokenOfOwnerByIndex`/`tokenByIndex` (ADR 0012 decision T10).
5. `blockCollectionBurns` requires `CLOSED` and staged governance, is
   one-way, and makes `burn` revert for the collection [CMC-BURN].
6. Collection-scope finality is rejected without the burn block; burns
   between `CLOSED` and the burn block are captured in finality facts.

Metadata write tests:

The genesis implementation exercises typed v1 groups through generic
schema-bound records. The field-specific tests below apply directly to any
typed ABI promotion under a separate accepted spec and indirectly to v1
records by mapping each field group to a `recordType`/`schemaId` pair.

1. Admin can set collection identity.
2. Admin can set collection people.
3. Admin can set collection media.
4. Admin can set collection URIs.
5. Admin can set collection rights.
6. Admin can set collection display.
7. Admin can set custom fields.
8. Admin can enumerate custom field keys.
9. Admin can set base URI.
10. Admin can set script manifest and chunks.
11. Admin can set dependency manifest.
12. Admin can set media manifest.
13. Artist can submit attestation.
14. Unauthorized callers cannot mutate metadata.
15. Writes fail for nonexistent collections.
16. Writes fail after relevant locks.
17. Open-ended collection display fields can be set without setting a max supply
    in metadata.
18. Metadata cannot make a Core-closed collection mintable.
19. Admin can set alternate view manifests.
20. Admin can publish a collection snapshot with schema ID and manifest hash.
21. Authorized attesters can record generalized attestations.
22. Preservation admin can record generic archive/preservation records after
    display metadata is frozen when preservation records remain unlocked.
23. Snapshot IDs cannot be reused for the same collection.
24. Locked view, attestation, archive, and snapshot surfaces reject writes.
25. Preservation admin can record PREMIS-style preservation records through
    `recordCollectionRecord`.
26. Preservation admin can record fixity checks for source, master, derivative,
    script, schema, IIIF, C2PA, and archive-package objects through generic
    records.
27. Preservation admin can record C2PA references with manifest, claim,
    signature, validation status, and validation report hashes through generic
    records.
28. Preservation admin can record source-to-derivative and parent/child-style
    media relationships without changing Core ownership.
29. Open-series fields include season and release manifest URIs and hashes.
30. Rights fields include commercial, AI, derivative, print, exhibition,
    attribution, and estate/contact policy references.
31. Operator UX and schema docs explicitly state that rights metadata is notice
    and evidence, not automatic onchain legal enforcement.
32. Record-family authorization negatives: global admin writes to
    `ARTIST_*` and `OWNER_*` families revert; a curator signer cannot
    write `FIXITY_*`; snapshot publication over an unauthorized family
    reverts [CMC-AUTHZ].
33. Artist attestation submission verifies EIP-712 (nonzero exact-match
    recovery) and ERC-1271 signatures, binds the state hash, and both
    direct and relayed paths succeed for authorized signers only
    [CMC-ARTIST-ATTESTATION].
34. `artistAttestationCurrent` flips to stale after any render-affecting
    mutation.
35. Owner records: current owner writes directly and via relayed
    signature; non-owners and admins revert; unordered nonces consume in
    any order (reverse-order two-payload test) and deadlines are
    enforced; direct and relayed revocation block a signed record, are
    signer-scoped, and emit `OwnerRecordNonceRevoked`; the
    explicit-address replay view reports consumption for any queried
    owner; records survive transfer with original attribution; no
    collection lock blocks the surface [CMC-OWNER-RECORDS].
36. Token content roots: leaf and node hashes recompute per the pinned
    domains; finality at every scope reverts without a covering root;
    `leafCount` mismatches revert [CMC-CONTENT-ROOT].
37. Record-chain accumulators: replaying a lane's events reproduces
    `(chainHash, recordCount)`; a withheld event is detectable
    [CMC-RECORD-CHAIN].
38. Fixity program: `FIXITY_CYCLE_COMPLETED` and `FIXITY_FAILURE` records
    round-trip with coverage counts and repair lineage
    [CMC-FIXITY-PROGRAM].
39. C2PA: records missing validator identity/version/report revert; an
    asset-binding mismatch is recorded `INVALID` and fails the attestation
    gate [CMC-C2PA].
40. Signature bundles for `SIGNER_VERIFIED` writes are recoverable from
    chain data (event or storage) within `MAX_SIGNATURE_BUNDLE_BYTES`
    [CMC-ATTESTATIONS].
41. Snapshot publication stores canonical manifest bytes onchain and the
    evented pointer serves them back byte-identically.
42. `ARTIST_INTENT`: finality for artist-bound collections reverts without
    an intent record or signed waiver [CMC-ARTIST-INTENT].
43. Independent lane: any address writes fixity, preservation-event,
    exhibition, and condition records in its own name, direct and
    relayed, with the exhibition/condition payloads validating against
    `STREAM_EXHIBITION_V1`/`STREAM_CONDITION_REPORT_V1`; impersonation
    reverts; attestor nonces are unordered with signer-scoped
    revocation and the explicit-address replay view;
    no lock, freeze, finality state, or admin role blocks or forges the
    lane; lane chain heads replay [CMC-INDEPENDENT-ATTESTOR].
44. Rights: finality for any collection — artist-bound or
    `PLATFORM_WORKS` — reverts without a
    `STREAM_RIGHTS_V1` record; closed-vocabulary validation rejects
    unknown grant values; the packet derives the rights-completeness
    status [CMC-RIGHTS-SCHEMA].
45. Reference render: finality reverts without the archived
    execution-environment artifact and a pinned acceptance mode;
    `BYTE_EXACT` without pinned software rasterization is rejected;
    `DYNAMIC`-class works cannot pin `BYTE_EXACT`; the drill artifact
    classifies outcomes `MATCH`/`TOLERABLE_VARIANCE`/`DIVERGENT` and
    boots an archived environment [CMC-FINALITY-INPUTS].
46. Genesis schema set: every schema named in [CMC-GENESIS-SCHEMAS]
    resolves to registered onchain document bytes whose hashes match the
    release manifest (schema-pinning golden test).
47. Artist content veto: post-first-mint content-affecting writes for an
    `ARTIST_SIGNED_POLICY` collection revert without verified artist
    co-signature; the relayed artist content freeze applies the `SCRIPT`,
    `DEPENDENCIES`, and `MEDIA_MANIFEST` locks and records the artist
    authority class [CMC-ARTIST-CONTENT-VETO].
48. Attestation mirror: the checker row comparing this document's artist
    attestation field inventory against [AA-ATTEST] passes, and the
    metadata GGP tests (floor/raise/lower/probe) run for
    `METADATA_ERC1271_VERIFY_GAS` on every hosting satellite
    [CMC-SIGVER-GGP].
49. Record payload carrier: payload-carrying writes store, verify, and
    serve back byte-identical payloads; digest mismatches, empty
    payloads, and oversized payloads revert; meaning-bearing families
    reject bytes-less writes (checker row over every rule-2 family
    write path) [CMC-RECORD-PAYLOAD].
50. Payload pointer walk: a state-only client with no logs enumerates
    and fetches every mandated onchain payload byte — snapshots,
    schema/catalog documents, record payloads, signature bundles,
    script chunks, owner-record and independent-lane payloads — through
    the pointer registry reads alone [CMC-PAYLOAD-POINTERS].
51. Sold-token lane: a sale in an open `OFFCHAIN` collection starts the
    coverage window; receipts (one `ENDOWED` family) plus a passing
    fixity record inside the window yield `covered`; a lapsed window
    yields `uncovered_overdue`, fires the monitored-incident alert, and
    surfaces in the acquisition packet [CMC-FIXITY-PROGRAM].
52. Packet and dossier regeneration: `STREAM_ACQUISITION_PACKET_V1` and
    `OBJECT_DOSSIER_V1` regenerate from chain state with no operator
    involvement and verify component by component, including the
    ownership-provenance chain, rights-completeness status, coverage
    status, drill outcome, and tombstone reference
    [CMC-ACQUISITION-PACKET] [CMC-OBJECT-DOSSIER].
53. Media conservation gate: finality over time-based media reverts
    without registry-linked `formatId` and a significant-properties
    record; the preservation-master presence status round-trips into
    the packet [CMC-FINALITY-INPUTS] [CMC-PREMIS-PROFILE].
54. Environment remediation: a failed drill boot check without a
    recorded migrated artifact or infeasibility finding fails the drill
    gate; a recorded remediation links old and new artifact hashes
    through a `MIGRATION` event [CMC-ENV-REMEDIATION].
55. Tombstone records: `WORK_DESCRIPTION` writes validate the required
    field set, accept artist and curator authority, reject others, and
    carry payload bytes [CMC-TOMBSTONE].

Renderer integration tests:

1. Offchain URI uses metadata contract `baseURI`.
2. Onchain render uses metadata contract script chunks.
3. Dependency manifest is read correctly.
4. Script hash is stable for stored chunks.
5. Media manifest is read correctly for image, animation, content, and
   alternates.
6. Alternate view manifests are exposed as references without changing the
   default marketplace `tokenURI()` output.
7. Metadata update events are emitted when renderer-visible fields change.

Event/indexing tests:

1. Every mutation emits a specific event.
2. Event hashes match stored field hashes.
3. Lock events are one-way and reconstructable.
4. Field revision events include old hash, new hash, reason code, actor, and
   effective timestamp.
5. Snapshot, archive receipt, and attestation histories are reconstructable from
   events.
6. Preservation event, fixity, C2PA reference, and media relationship histories
   are reconstructable from `CollectionRecordRecorded` events.

## Recommended V1 Position

For protocol v1, implement a dedicated `StreamCollectionMetadata` contract
rather than storing collection metadata inside `StreamMetadataRouter`.

Core keeps `totalSupply()` and token behavior without per-transfer
enumeration storage (ADR 0012 decision T10). The metadata contract
and v1 companion satellites should own the v1 ABI listed in `V1 Scope
Reduction`: compact schema-bound collection records for typed metadata groups,
script/dependency/media manifest commitments, schema commitments, view
manifests, snapshot events with onchain manifest bytes, revision events,
generic collection records with record-family authorization, record-chain
accumulators, the payload-bytes carrier, and the payload pointer
registry, token content roots, field locks, PREMIS-style preservation
records under the pinned PREMIS profile, the fixity program with the
sold-token lane and environment remediation,
media-hash-bound C2PA references with attribution reconciliation, the
pinned IIIF profiles, media relationship records, owner records and the
object dossier with its packaging profile, the independent preservation
lane with exhibition and condition types, the genesis museum
schema set with pinned rights and tombstone records, state-bound artist
attestations
and intent records with interview coverage, the artist content veto,
generalized attestations under the metadata verification gas parameter,
and museum-grade catalogue material. The metadata router should read from
those outside-Core surfaces and focus on `tokenURI()` routing and renderer
selection.

This gives Stream enough room to support Core-native ERC-2981 while making
collection metadata more durable, explicit, and extensible than the current
Core-embedded string model. It also gives long-lived collections a credible
path for schema evolution, preservation, provenance, accessibility, and
multiple canonical presentations without changing ERC-721 token identity.
