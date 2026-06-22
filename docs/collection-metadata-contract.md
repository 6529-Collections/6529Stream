# Collection Metadata Contract

This document is a pre-launch target specification for moving collection
metadata storage out of `StreamCore` into a dedicated
`StreamCollectionMetadata` contract.

`StreamCore` should remain the canonical ERC-721 contract with
`ERC721Enumerable`. Collection identity, ownership, transfers, approvals,
balances, and token existence stay in Core. Human-facing collection metadata,
script manifests, dependency configuration, and long-lived collection display
state should live outside Core.

## Design Summary

```text
StreamCore
  - ERC-721 ownership and enumeration
  - collection ID allocation
  - token to collection identity
  - collection supply mode and status
  - collection-local token serial assignment
  - minimal pointer to collection metadata contract
  - minimal pointer to metadata router

StreamCollectionMetadata
  - collection descriptive metadata
  - artist identity and artist-facing attestations
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
   not necessarily a separate launch contract.
3. `StreamCollectionAttestations`: artist, curator, estate, institution,
   preservation, C2PA, EAS, VC, EIP-712, and ERC-1271-compatible attestation
   records. This can start inside `StreamCollectionMetadata` and split out if
   it grows.
4. `StreamPreservationRegistry`: archive receipts, PREMIS-style preservation
   records, fixity checks, storage/migration events, and media-provenance
   references. This should remain outside Core even if implemented at launch.

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
   understand from launch.
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
   relationship modeling, useful as inspiration for future token-linked
   archives or companion assets without changing Stream's ERC-721 ownership
   model at launch.
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
13. Keep the launch implementation simple enough to audit.

## Non-Goals

1. `StreamCollectionMetadata` does not mint, burn, transfer, or approve NFTs.
2. It does not replace `StreamCore` as the ERC-721 contract.
3. It does not enforce primary-sale or royalty payments.
4. It does not decide royalty splits.
5. It does not need to be an upgradeable proxy.
6. It does not store marketplace secrets or private data.
7. It does not rely on hardcoded field labels as a complete permanent schema.

## Launch Scope Reduction

The collection metadata architecture is a 50-year knowledge system, but launch
ABI must stay small enough to audit. The launch contract should implement the
first column, treat the second column as schema/manifest guidance, and reserve
the third column for later companion contracts.

| Launch ABI | Schema-Only Or Offchain | Future Companion Contract |
|---|---|---|
| `CollectionIdentity` | PREMIS object/event/agent/right payload schemas | `StreamSchemaRegistry` |
| `CollectionPeople` | C2PA assertion, ingredient, action schemas | `StreamCollectionAttestations` |
| `CollectionMedia` | IIIF Presentation manifests | `StreamPreservationRegistry` |
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

Launch must not implement typed PREMIS structs, typed C2PA structs, typed IIIF
structs, typed fixity structs, typed media-relationship structs, or a separate
schema-registry contract unless a later implementation ADR explicitly promotes
one of those surfaces. Use `CollectionRecord` plus `schemaId`, `HashRef`, and
URI commitments for those records at launch.

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

The launch architecture should allocate global sequential ERC-721 token IDs and
store explicit `tokenId -> collectionId` plus `tokenId -> collectionSerial`
mappings. The current namespaced token ID formula is current-code context, not
the target model. Collection-local serials remain stable display and accounting
facts without being encoded into the token ID.

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
5. Status transitions are `ACTIVE`, `PAUSED`, and `CLOSED`. Reopening a closed
   collection requires delayed governance unless the collection was explicitly
   configured as ongoing/open.
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

Rules:

1. Caller must be owner or approved.
2. Core validates the token's collection through `tokenCollectionId[tokenId]`,
   never through token ID range arithmetic.
3. Burn removes ERC-721 ownership and enumerable membership.
4. Burn retains `tokenCollectionId`, `tokenCollectionSerial`, and the mapping
   existence bit for royalty disclosure, archives, and state exports.
5. A frozen or artwork-finalized collection is non-burnable unless the
   collection's pre-finality policy and finality manifest explicitly preserve a
   burn path and state the archival consequences.
6. Burn emits `StreamTokenBurned` with collection ID and serial.

```solidity
event StreamTokenBurned(
    uint256 indexed tokenId,
    uint256 indexed collectionId,
    uint256 collectionSerial,
    uint16 schemaVersion
);
```

## Open-Ended Collections

Open-ended collections are a first-class launch requirement.

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
10. A frozen or artwork-finalized collection is non-burnable by default. A burn
    path may survive a freeze only if the pre-freeze policy and finality
    manifest explicitly preserve it and prove that burning cannot change the
    promised artwork, supply semantics, entropy interpretation, or
    revenue/royalty history.
11. When a burn is allowed, Core removes ERC-721 ownership and enumerable
    membership but preserves token-to-collection mapping, collection-local
    serial, and mapping-existence state for historical royalty and audit reads.

Recommended Core mint shape:

```solidity
function mintNext(
    uint256 collectionId,
    address initialRecipient,
    address beneficiary,
    bytes calldata tokenData,
    bytes32 mintCommitment
) external returns (uint256 tokenId, uint256 collectionSerial);
```

Core should allocate the token ID and local serial. Sale contracts should not
need to precompute token IDs by hand. If a sale path needs a token-level primary
or royalty override, it should allocate the token through Core before external
recipient callbacks, write the authoritative token-to-collection mapping, and
then settle revenue. Launch v1 does not define a standalone premint reservation
API; unknown future token IDs are not valid collection authority for metadata,
revenue, royalty, entropy, or freeze rules.

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

The contract should ship with a rich typed metadata model from launch. The
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
    string symbol;
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
4. `symbol` is an optional collection-scoped symbol for contract metadata. If it
   is empty, `contractURI(collectionId)` uses the Core ERC-721 symbol.
5. `subtitle` is optional short supporting text.
6. `description` is the canonical collection description.
7. `category` is display data, not a closed enum. Examples may include art,
   photography, generative, edition, poster, artifact, or experiment.
8. `tagsURI` and `tagsHash` allow richer tag vocabularies without hardcoding
   them onchain.

```solidity
struct CollectionPeople {
    address artistAddress;
    string artistDisplayName;
    string artistProfileURI;
    string artistWebsiteURI;
    string artistENS;
    string collaboratorsURI;
    bytes32 collaboratorsHash;
}
```

People guidance:

1. `artistAddress` is the authoritative artist identity for artist-gated
   metadata actions.
2. `artistDisplayName`, `artistProfileURI`, `artistWebsiteURI`, and `artistENS`
   are display fields only.
3. Collaborators are intentionally represented by URI plus hash rather than a
   fixed onchain array. Collections can have artists, studios, curators,
   estates, institutions, software contributors, fabricators, publishers, and
   future roles we should not attempt to hardcode forever.

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
   does not itself compel offchain actors unless a separate legal agreement or
   future enforcement ADR says so.

```solidity
struct CollectionDisplay {
    bytes32 displayProfileId;
    string displayProfileURI;
    bytes32 rendererCompatibility;
    string locale;
    string exhibitionURI;
    bytes32 exhibitionHash;
}
```

Display guidance:

1. `displayProfileId` is an open-ended display/profile key, not a hardcoded
   enum.
2. `displayProfileURI` can point to theme, layout, color, or rendering
   preferences understood by 6529 frontends.
3. `rendererCompatibility` declares the renderer or render-context family the
   collection expects.

## Token-Level Metadata

Core must not store token display metadata, token image JSON, attributes JSON,
or renderer overrides. Token-level metadata lives in
`StreamCollectionMetadata` and is read by the metadata router/renderer.

Canonical token data passed through minting is opaque `bytes tokenData`. If a
collection treats it as UTF-8, JSON, CBOR, or another format, the active
renderer/schema declares that interpretation. In the render context, token data
is exposed as bytes plus an optional decoded view chosen by the renderer; Core
does not parse it.

Recommended token-level launch API:

```solidity
struct TokenMetadata {
    bytes tokenData;
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

Rules:

1. The metadata contract verifies token existence or burned-token archival
   policy through Core reads.
2. Token metadata merges over collection metadata only where the renderer schema
   says token-level overrides are allowed.
3. Token field locks are one-way and survive collection metadata replacement.
4. Token-level metadata cannot modify revenue assignments, ownership, entropy
   seed, or collection identity.
5. Burned-token archival metadata may remain readable through metadata contract
   views even when Core `tokenURI()` reverts under ERC-721 semantics.
4. `locale` is a default locale hint for display metadata.
5. `exhibitionURI` and `exhibitionHash` support collection placement in a show,
   release, season, or other context without embedding that whole model in
   Core.

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

Typed metadata should be extensive enough to make launch collections feel
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
    WEB3_CALL,
    OTHER
}
```

Rules:

1. `INLINE_CHUNKS` is the preferred launch path for collection scripts.
2. `DEPENDENCY_REGISTRY` is the preferred launch path for shared JavaScript
   dependencies already supported by the protocol.
3. `IPFS`, `ARWEAVE`, `HTTPS`, and `OTHER` require a hash commitment for
   payloads that affect rendering, provenance, or collector display.
4. `SSTORE2` and `ETHFS` are not required at launch, but the manifest model
   must be able to represent them.
5. `WEB3_CALL` leaves room for ERC-4804-style onchain JSON or HTML reads.
6. Source type additions should be additive. Unknown source types in future
   schemas must not change Core behavior.

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
closed vocabulary.

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
reconstruct it. The preferred launch design is:

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

The launch implementation does not need a universal type registry, but it
should leave room for one.

### Field Families

Known custom fields should be documented as families rather than as a closed
list. Suggested launch families:

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

Launch behavior:

1. `libraryURI` replaces the current `collectionLibrary`.
2. Onchain script chunks replace the current `collectionScript`.
3. `scriptHash` commits to the canonical script payload.
4. `rendererCompatibility` states the renderer/API version expected by the
   script.
5. `scriptURI` is an optional offchain mirror or source reference.
6. `sourceType` should be `INLINE_CHUNKS` for launch onchain scripts.
7. `sourcePointer` can later point to a blob contract, EthFS path, Arweave ID,
   IPFS CID, or another storage-specific identifier.
8. `mimeType` should normally be `application/javascript` for executable
   scripts.
9. `executable` must be false for manifests that describe source archives or
   documentation rather than renderer-executed JavaScript.

The contract may store chunks directly:

```solidity
mapping(uint256 collectionId => string[] chunks) scriptChunks;
```

For larger scripts, the implementation may use SSTORE2-style blob contracts.
The public interface should hide that storage choice from renderers.

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

1. Launch dependency manifests can use `DEPENDENCY_REGISTRY` when the existing
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
ERC-721 ownership. It should move into this contract.

Recommended model:

```solidity
struct ArtistAttestation {
    address signer;
    string statement;
    bytes32 statementHash;
    uint64 signedAt;
}
```

Rules:

1. Only `artistAddress` or an authorized admin can set the initial artist
   address.
2. Only `artistAddress` can submit an artist attestation unless the collection
   uses an explicit delegated artist signer.
3. Artist attestations are append-only or one-time depending on collection
   policy.
4. A one-time attestation should be lockable forever.

Events should make artist attestations easy to index.

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

Rules:

1. Attestations should be append-only unless explicitly marked invalid by a
   later attestation.
2. `statementHash` commits to the canonical payload. `statementURI` is a
   locator, not the source of truth by itself.
3. EOA signers can use EIP-712-style typed payloads in admin tooling.
4. Contract signers should be compatible with ERC-1271-style signature checks
   when signature verification is added.
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

Launch can store the latest attestation hash per type plus emit append-only
events. Full onchain attestation arrays are optional if gas becomes annoying;
events plus explicit read slots for important latest hashes are enough for the
first version.

## Preservation Receipts

Collections that matter for 50 years need preservation records, not just
current display URLs.

Recommended model:

```solidity
struct ArchiveReceipt {
    bytes32 archiveType;
    bytes32 objectId;
    bytes32 contentHash;
    string uri;
    bytes32 receiptHash;
    bytes32 agentId;
    bytes32 schemaId;
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

### Launch Onchain Record Primitive

The detailed structs below define Stream's preservation schema vocabulary. They
should not all become separate launch ABI methods or storage layouts.

Launch should use one generic record primitive for preservation, provenance,
attestation, relationship, fixity, C2PA, IIIF, rights, and archive records:

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
KECCAK256
SHA256
BLAKE3
MULTIHASH
IPFS_CID
ARWEAVE_TX
OTHER
```

`canonicalizationId` identifies how the external payload was serialized before
hashing, such as `ABI_V1`, `RFC8785_JCS`, `DET_CBOR`, `RAW_BYTES`, `PREMIS_XML`,
`IIIF_JSON`, or `C2PA_MANIFEST`. Protocol identity hashes may still use fixed
`bytes32 keccak256` fields elsewhere, but preservation-critical records need
algorithm-tagged fixity.

Recommended launch write:

```solidity
function recordCollectionRecord(
    uint256 collectionId,
    CollectionRecord calldata record
) external;
```

Recommended launch event:

```solidity
event CollectionRecordRecorded(
    uint256 indexed collectionId,
    bytes32 indexed recordType,
    bytes32 indexed subjectId,
    uint16 contentHashAlgorithm,
    bytes contentHashDigest,
    bytes32 contentHashCanonicalizationId,
    string uri,
    bytes32 schemaId,
    bytes32 signatureScheme,
    uint16 signatureHashAlgorithm,
    bytes signatureHashDigest,
    bytes32 signatureHashCanonicalizationId,
    uint64 effectiveAt
);
```

Rules:

1. `recordType` is an open `bytes32` vocabulary.
2. `subjectId` identifies the collection, token, media object, preservation
   object, actor, rights record, snapshot, or relationship subject.
3. `contentHash` commits to the canonical external payload with an explicit
   algorithm and canonicalization profile.
4. `schemaId` defines how to interpret the payload.
5. `signatureScheme` and `signatureHash` are optional commitments to EIP-712,
   ERC-1271, W3C VC, EAS, C2PA, DID-linked, or future verification bundles.
6. The typed records below are recommended offchain schema profiles and
   optional future companion-contract interfaces, not mandatory launch storage.
7. This keeps the launch metadata contract auditable while preserving the
   50-year knowledge-system model.

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
   manifests, C2PA manifests, and archive packages should have fixity records
   before final freeze.
2. Repeated fixity checks over time should append events rather than overwriting
   older checks.
3. If a payload is intentionally migrated, the old object, new object,
   migration event, agent, and reason should all be linked.

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

Rules:

1. The NFT metadata should reference C2PA manifests by URI/hash and active
   manifest ID when known.
2. Claims, assertions, ingredients, actions, and signatures should be recorded
   in offchain manifests and committed by hashes onchain.
3. C2PA validation status should identify who validated it, when, with what
   validator version, and where the validation report lives.
4. Redactions should be explicit. A redacted C2PA record can still be useful if
   the redaction is documented.
5. Sensitive camera, location, or personal metadata should not be pushed onchain.
   Use private/offchain payloads with hashes when preservation requires a
   commitment.
6. C2PA should coexist with artist attestations, curator attestations, W3C VCs,
   DIDs, EIP-712 signatures, and ERC-1271 contract-wallet signatures.
7. Redaction-aware manifests should separate public hash, optional redacted
   replacement hash, redaction reason URI/hash, and whether the original
   unredacted payload remains available to authorized archives. Redaction must
   not silently rewrite finalized artwork bytes.

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
   relationships at launch, not as Core ownership nesting.
2. If future Stream modules add token-linked companion assets, they should use
   explicit relationship records and not infer relationships from naming.
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

Rules:

1. IIIF manifests should be optional but strongly supported for serious image
   collections.
2. The IIIF manifest should describe canvases, annotation pages, annotations,
   image services, labels, summaries, required statements, rights, and viewing
   hints where relevant.
3. IIIF annotations can carry curator notes, translations, transcriptions,
   accessibility notes, conservation notes, crop/region commentary, or
   exhibition-specific interpretation.
4. The default marketplace `tokenURI()` should only reference IIIF data; it
   should not inline large IIIF manifests.

## Lock Model

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
4. Core collection freeze may imply metadata freeze if the launch policy wants
   that, but this should be explicit.
5. Script and dependency locks should be strongly encouraged before final
   collection freeze.
6. Preservation receipts may remain appendable after display metadata is frozen
   if the collection policy wants ongoing archive maintenance.

## Mutation API

Avoid magic indexes. Use explicit functions.

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
    string calldata statement,
    bytes32 statementHash
) external;

function recordCollectionAttestation(
    uint256 collectionId,
    CollectionAttestation calldata attestation
) external;

function recordCollectionRecord(
    uint256 collectionId,
    CollectionRecord calldata record
) external;

function publishCollectionSnapshot(
    uint256 collectionId,
    bytes32 snapshotId,
    bytes32 schemaId,
    string calldata manifestURI,
    bytes32 manifestHash,
    uint64 effectiveFrom
) external;

function lockCollectionField(
    uint256 collectionId,
    bytes32 lockId
) external;
```

If script chunks use external blob contracts, script write functions can accept
blob pointers instead of strings.

Typed convenience writes such as `recordArchiveReceipt`,
`recordPreservationEvent`, `recordFixityCheck`, `recordC2PAReference`, and
`recordMediaRelationship` may be added in a later companion contract. For launch
they should be represented through `recordCollectionRecord` with a schema ID and
content hash.

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

function latestArchiveReceiptHash(
    uint256 collectionId,
    bytes32 archiveType
) external view returns (bytes32);

function latestPreservationEventHash(
    uint256 collectionId,
    bytes32 eventType
) external view returns (bytes32);

function latestFixityCheckHash(
    uint256 collectionId,
    bytes32 objectId
) external view returns (bytes32);

function latestC2PAReferenceHash(uint256 collectionId)
    external
    view
    returns (bytes32);

function latestSnapshotHash(uint256 collectionId)
    external
    view
    returns (bytes32);

function snapshotHash(uint256 collectionId, bytes32 snapshotId)
    external
    view
    returns (bytes32);
```

Launch does not need to expose every historical attestation or receipt in
storage. Events are the canonical append-only history. Read slots should focus
on latest hashes, active snapshots, and values renderers or frontends need in a
single call.

## Events

Events are part of the product surface. They let frontends and indexers track
metadata over decades.

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
    bytes32 statementHash
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
    uint16 contentHashAlgorithm,
    bytes contentHashDigest,
    bytes32 contentHashCanonicalizationId,
    string uri,
    bytes32 schemaId,
    bytes32 signatureScheme,
    uint16 signatureHashAlgorithm,
    bytes signatureHashDigest,
    bytes32 signatureHashCanonicalizationId,
    uint64 effectiveAt
);

event CollectionArchiveReceiptRecorded(
    uint256 indexed collectionId,
    bytes32 indexed archiveType,
    bytes32 indexed objectId,
    bytes32 contentHash,
    string uri,
    bytes32 receiptHash,
    bytes32 agentId,
    bytes32 schemaId
);

event CollectionPreservationEventRecorded(
    uint256 indexed collectionId,
    bytes32 indexed eventId,
    bytes32 indexed eventType,
    bytes32 outcome,
    bytes32 eventHash,
    bytes32 agentId
);

event CollectionFixityCheckRecorded(
    uint256 indexed collectionId,
    bytes32 indexed objectId,
    bytes32 indexed algorithm,
    bytes32 digest,
    bytes32 outcome,
    bytes32 agentId
);

event CollectionC2PAReferenceRecorded(
    uint256 indexed collectionId,
    bytes32 indexed activeManifestId,
    bytes32 manifestHash,
    bytes32 claimHash,
    bytes32 validationStatus
);

event CollectionMediaRelationshipRecorded(
    uint256 indexed collectionId,
    bytes32 indexed subjectId,
    bytes32 indexed relationshipType,
    bytes32 objectId,
    bytes32 relationshipHash
);

event CollectionSnapshotPublished(
    uint256 indexed collectionId,
    bytes32 indexed snapshotId,
    bytes32 indexed schemaId,
    string manifestURI,
    bytes32 manifestHash,
    uint64 effectiveFrom
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

event ContractURIUpdated();
```

`CollectionArchiveReceiptRecorded`, `CollectionPreservationEventRecorded`,
`CollectionFixityCheckRecorded`, `CollectionC2PAReferenceRecorded`, and
`CollectionMediaRelationshipRecorded` are useful future typed events or
companion-contract events. The launch metadata contract can emit only
`CollectionRecordRecorded` for those record families and still preserve the same
offchain schema semantics through `recordType`, `subjectId`, and `schemaId`.

The metadata router or Core should also emit ERC-4906-style events where token
metadata may change:

```solidity
event MetadataUpdate(uint256 _tokenId);
event BatchMetadataUpdate(uint256 _fromTokenId, uint256 _toTokenId);
```

## Admin And Authorization

Use the existing `StreamAdmins` model rather than inventing a second admin
system.

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
submitArtistAttestation     artist address or delegated artist signer
recordCollectionAttestation attester, collection metadata admin, or global admin
recordCollectionRecord      preservation/admin/attester according to recordType
publishCollectionSnapshot   collection metadata admin or global admin
lockCollectionField         freeze admin or global admin
```

Every mutation must check:

1. The collection exists in Core.
2. The caller has authority.
3. The relevant lock is not active.
4. The input is structurally valid.

## Validation

Recommended launch validations:

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
    media should have nonzero hash commitments before final freeze.
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
19. Attestation types must be nonzero, and attestation hashes should commit to
    the canonical signed or referenced payload.
20. Preservation manifests should identify object, event, agent, rights, fixity,
    relationship, and C2PA records through schema IDs and hashes.

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

Collection contract URI updates should emit collection-specific metadata events
and should cause the router or Core to emit `ContractURIUpdated()` when the
global Core `contractURI()` output changes.

If marketplaces need a contract-level `contractURI()` on Core, Core or the
router can expose a default collection-independent URI separately. That should
not block collection-level contract metadata.

## Open Series Display

For open-ended collections, metadata should make the collection's public status
legible without pretending to be the minting authority.

Recommended display fields:

```text
CollectionIdentity.category = "photography" or another open category
CollectionIdentity.subtitle = "An ongoing photographic series"
CollectionDisplay.exhibitionURI = optional release, exhibition, or season context
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

## Launch Limits

The metadata contract must choose finite launch limits before implementation.
Recommended v1 hard maxima:

```text
MAX_SHORT_STRING_BYTES       1,024
MAX_URI_BYTES                2,048
MAX_LONG_TEXT_BYTES         16,384
MAX_TOKEN_DATA_BYTES        16,384
MAX_ATTRIBUTES_JSON_BYTES   65,536
MAX_PROPERTIES_JSON_BYTES   65,536
MAX_CUSTOM_FIELDS              128
MAX_SCRIPT_CHUNK_BYTES      24,576
MAX_SCRIPT_CHUNKS              256
MAX_TOTAL_SCRIPT_BYTES   1,048,576
MAX_BATCH_MUTATIONS             50
```

The exact constants can change during implementation if tests prove better
values, but "unbounded" is not an acceptable v1 policy. Mutation functions
should revert with specific errors when a write exceeds the relevant limit.
Admin tooling should dry-run renderer output against
`MAX_RENDER_JSON_BYTES = 65,536` and `MAX_RENDER_HTML_BYTES = 1,048,576` before
activation or final artwork freeze.

Batch mutation limits apply to arrays of field updates, script chunks, custom
fields, locks, attestations, and snapshot records. Larger updates should be
split across transactions so event reconstruction remains practical.

## Schema Registry

`schemaId` should resolve to enough information for humans, indexers, renderers,
and agents to understand a payload years later.

Preferred architecture:

1. Launch can store schema URI/hash directly in collection metadata.
2. If schema usage grows, add a small `StreamSchemaRegistry` companion contract
   rather than baking every schema into Core.
3. The registry should be append-friendly and deprecation-aware, not mutable in
   a way that silently changes what an old schema meant.

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
3. `manifestHash` should commit to a canonical JSON or CBOR payload.
4. Snapshot manifests should include typed metadata, custom fields, script and
   dependency manifests, media manifests, rights data, attestation references,
   archive receipts, and active view manifests.
5. `CollectionFieldRevision` should be emitted for field changes where the old
   hash is known. Reason codes should be open `bytes32` values such as
   `TYPO_FIX`, `ARTIST_UPDATE`, `RIGHTS_UPDATE`, `ARCHIVE_UPDATE`,
   `SCHEMA_MIGRATION`, or `ADMIN_CORRECTION`.
6. `effectiveAt` should be explicit. It may equal the block timestamp, but the
   event should not force indexers to infer the intended effective time.
7. Freezing metadata should not erase the revision trail. It should make future
   unauthorized revisions impossible.

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
8. post-finality exception policy, if any.

The `dataHash` must be reproducible from onchain reads and hash-committed
manifests. It is the value the finality registry compares against the submitted
`FinalityComponentExpectation`.

Finality rules:

1. A collection cannot be finalized while any artwork-affecting metadata field
   remains mutable outside the declared exception policy.
2. Finality emits a metadata-side event and should be paired with the
   finality-registry `CollectionArtworkFinalized` event, including the same
   `componentsHash`.
3. Frozen onchain collections must publish an assembled snapshot manifest hash
   over script, dependency, media, renderer context, metadata roots, and entropy
   policy before Core-linked finality can execute.
4. Deprecated metadata schemas or storage modules may keep serving finalized
   collections. They must not reinterpret historical snapshot hashes.
5. Preservation-only records may remain appendable after finality if the
   finality manifest explicitly allows that surface and those records cannot
   change artwork bytes.

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

1. Keep the stable typed fields in `CollectionRights`.
2. Use custom fields for policy surfaces likely to evolve:
   `COMMERCIAL_RIGHTS_URI`, `AI_TRAINING_PERMISSION`,
   `DERIVATIVE_RIGHTS_URI`, `PRINT_RIGHTS_URI`, `EXHIBITION_RIGHTS_URI`,
   `ATTRIBUTION_REQUIREMENTS_URI`, `ESTATE_CONTACT_URI`, and related future
   keys.
3. Require hashes for policy documents that materially affect collectors,
   artists, licenses, or institutional usage.
4. Use snapshots when a rights policy materially changes so older policy states
   remain inspectable.
5. Treat rights fields as metadata and notice, not as a full legal enforcement
   engine.
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

## Reserved Future Metadata Surfaces

The launch metadata contract should leave clear extension points for future
modules without implementing them in Core:

1. Post-mint parameters may use custom fields such as
   `POST_MINT_PARAMS_SCHEMA_URI`, `POST_MINT_PARAMS_SCHEMA_HASH`, and
   `POST_MINT_PARAMS_MODULE`.
2. Dynamic onchain traits may use custom fields such as
   `DYNAMIC_TRAITS_MODULE` and `DYNAMIC_TRAITS_SCHEMA_URI`, but ordinary display
   traits should remain in token `attributes`.
3. Specialized future view modules may extend launch view manifests with
   token-specific views, live views, programmable view negotiation, or raw
   onchain HTML/JSON reads. They should build on `CollectionViewManifest`
   rather than changing `StreamCore.tokenURI()`.
4. Token-bound account integration may use `TOKEN_BOUND_ACCOUNT_REGISTRY` and
   token-level metadata fields when a concrete product use case exists.
5. Agent-readable metadata may use `AGENT_MANIFEST_URI`,
   `AGENT_MANIFEST_HASH`, and schema fields that describe how tools should
   inspect, render, validate, or explain a collection.

Except for the launch view-manifest support specified above, these are reserved
conventions rather than launch requirements. They should be implemented as
separate modules that read Core and metadata interfaces.

## Bytecode Impact

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
8. Keep PREMIS/C2PA/IIIF typed structs as schema guidance or future companion
   interfaces, not launch ABI requirements.
9. Add IIIF/view manifest conventions.
10. Add snapshot publication.
11. Add rich events and metadata refresh hooks.

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
4. `ERC721Enumerable` behavior is unchanged.

Metadata write tests:

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

## Recommended Launch Position

For launch, implement a dedicated `StreamCollectionMetadata` contract rather
than storing collection metadata inside `StreamMetadataRouter`.

Core should keep `ERC721Enumerable` and token behavior. The metadata contract
should own the launch ABI listed in `Launch Scope Reduction`: typed collection
metadata, arbitrary fields, script manifests, dependency manifests, media
manifests, schema commitments, view manifests, snapshot events, revision
events, generic collection records, and field locks. PREMIS-style preservation
records, C2PA references, IIIF manifest references, media relationship records,
fixity records, artist attestations, and generalized attestations should be
represented through `CollectionRecord` and schema/hash commitments at launch
unless a companion contract is explicitly accepted. The metadata router should
read from the metadata contract and focus on `tokenURI()` routing and renderer
selection.

This gives Stream enough room to support Core-native ERC-2981 while making
collection metadata more durable, explicit, and extensible than the current
Core-embedded string model. It also gives long-lived collections a credible
path for schema evolution, preservation, provenance, accessibility, and
multiple canonical presentations without changing ERC-721 token identity.
