// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/// @notice Shared vocabulary for the artwork finality registry ([LTA-FINALITY], [LTA-FREEZE]).
/// @dev Type names carry the `Stream` prefix so this wave's declarations never collide with
///      sibling worktrees; ABI shapes follow the spec code blocks in
///      docs/stream-long-term-architecture.md exactly (struct names never enter selectors).

/// @notice Finality scope vocabulary (Artwork Finality Freeze, Scoped Finality For Open Series).
/// @dev Numeric IDs are pinned by declaration order: COLLECTION = 0, TOKEN = 1, RELEASE = 2,
///      SEASON = 3, VIEW = 4. `COLLECTION = 0` is additionally load-bearing in the sanction
///      subject preimage ([AA-SANCTION]: "COLLECTION=0 for collection finality").
enum StreamFinalityScopeType {
    COLLECTION,
    TOKEN,
    RELEASE,
    SEASON,
    VIEW
}

/// @notice Freeze-mode vocabulary pinned by [LTA-FREEZE] (Freeze Model).
/// @dev NONE = mutable subject to governance; EXACT freezes only the exact scope key;
///      INHERITED freezes the exact key and blocks lower-scope changes; GLOBAL freezes every
///      key in a policy family. The finality registry reports NONE/EXACT/INHERITED; GLOBAL is
///      part of the shared vocabulary for policy-family hosts and is never emitted here.
enum StreamArtworkFreezeMode {
    NONE,
    EXACT,
    INHERITED,
    GLOBAL
}

/// @notice Status machine for the registry's staged TERMINAL_FREEZE path
///         ([LTA-FREEZE] rule 4; ADR 0004 [GOV-WINDOWS] transition table).
enum StreamTerminalFreezeStatus {
    NONE,
    SCHEDULED,
    VETOED,
    CANCELLED,
    EXECUTED,
    EXPIRED
}

/// @notice Scope identity tuple (Scoped Finality For Open Series).
struct StreamFinalityScope {
    StreamFinalityScopeType scopeType;
    uint256 collectionId;
    uint256 tokenId;
    bytes32 scopeId;
}

/// @notice Live component read shape returned by every participating satellite.
struct StreamFinalityComponentState {
    bool frozen;
    bytes32 componentType;
    address component;
    bytes4 interfaceId;
    bytes32 codeHash;
    bytes32 moduleVersion;
    bytes32 manifestHash;
    bytes32 dataHash;
}

/// @notice Submitted component expectation verified against live reads at execution.
struct StreamFinalityComponentExpectation {
    bytes32 componentType;
    address component;
    bytes4 interfaceId;
    bytes32 codeHash;
    bytes32 moduleVersion;
    bytes32 manifestHash;
    bytes32 dataHash;
}

/// @notice Finality manifest reference; `contentHash` commits the canonical manifest bytes.
struct StreamFinalityManifestRef {
    string uri;
    bytes32 uriHash;
    bytes32 contentHash;
    bytes32 schemaId;
    bytes32 canonicalizationHash;
}

/// @notice Stored collection-scope finality record ([LTA-FINALITY] storage block).
struct StreamCollectionFinalityRecord {
    bool finalized;
    bytes32 finalityRecordHash;
    bytes32 manifestContentHash;
    bytes32 manifestURIHash;
    string finalityManifestURI;
    bytes32 componentsHash;
    address manifestPointer;
    uint64 finalizedAt;
}

/// @notice Stored scoped finality record (Scoped Finality For Open Series).
struct StreamScopedFinalityRecord {
    bool finalized;
    StreamFinalityScope scope;
    bytes32 finalityRecordHash;
    bytes32 manifestContentHash;
    bytes32 manifestURIHash;
    bytes32 componentsHash;
    string finalityManifestURI;
    address manifestPointer;
    uint64 finalizedAt;
}

/// @notice Typed Core collection facts consumed at collection-scope finality
///         (IStreamCoreFinalityFacts shape in [LTA-FINALITY]).
struct StreamCoreCollectionFinalityFacts {
    bool exists;
    bool hasMaxSupply;
    uint8 status;
    uint8 supplyMode;
    uint64 createdAt;
    uint64 maxSupply;
    uint64 mintedSupply;
    uint64 burnedSupply;
    uint64 nextCollectionSerial;
    bytes32 collectionConfigHash;
}

/// @notice Typed scoped Core facts consumed at scoped finality
///         (ScopedCoreFinalityFacts shape in Scoped Finality For Open Series).
struct StreamScopedCoreFinalityFacts {
    bool scopeExists;
    uint8 scopeType;
    uint256 collectionId;
    uint256 tokenId;
    bytes32 scopeId;
    bool tokenMappingExists;
    uint256 collectionSerial;
    uint8 tokenLifecycle;
    bool burned;
    uint8 collectionStatus;
    uint8 collectionSupplyMode;
    bytes32 collectionConfigHash;
    bytes32 scopeManifestHash;
}

/// @notice Staged terminal-freeze action record hosted by the finality registry.
/// @dev The veto window is `[scheduledAt, notBefore)` and `notBefore - scheduledAt` is
///      floored at 72 hours ([GOV-WINDOWS] rule 2; ADR 0011 decision R10); the
///      open-to-execute window `[notBefore, expiresAfter]` is floored at 7 days
///      ([GOV-WINDOWS] rule 1).
struct StreamTerminalFreezeAction {
    StreamTerminalFreezeStatus status;
    StreamFinalityScope scope;
    bytes32 expectedFinalityRecordHash;
    uint64 scheduledAt;
    uint64 notBefore;
    uint64 expiresAfter;
    address scheduler;
    address vetoGuardianAtScheduling;
}

/// @notice previewFinality result: the same comparisons finalization performs, plus the
///         computed sanction subject hash the artist signs ([AA-SANCTION] requirement 2).
struct StreamFinalityPreview {
    bool wouldExecute;
    bool notAlreadyFinalized;
    bool stagedFreezeReady;
    bool coreGatesSatisfied;
    bool contentRootSatisfied;
    bool manifestSatisfied;
    bool componentsWellFormed;
    bool componentsMatchLive;
    bool sanctionSatisfied;
    bool facadeBindingSatisfied;
    bool discoveryMatches;
    bytes32 computedCoreFactsHash;
    bytes32 computedComponentsHash;
    bytes32 computedNonSanctionComponentsHash;
    bytes32 computedSanctionSubjectHash;
    bytes32 computedFinalityRecordHash;
}

/// @notice Pinned domain constants for the artwork finality registry.
/// @dev Every value is `keccak256` of the string preimage in the trailing comment and is
///      mirrored in docs/launch-v1-target-architecture.md (Umbrella Architecture Mirror Rows,
///      artist rows, subject rows). test/StreamFinalityDomainsGolden.t.sol recomputes each one.
library StreamFinalityDomains {
    // ---- Finality record domains (home: [LTA-FINALITY] / [LTA-DOMAINS]) ----

    /// @dev keccak256("6529STREAM_FINALITY_V1")
    bytes32 internal constant STREAM_FINALITY_V1 =
        0x569714204c899f0d33a0f98879ce85708169a5f1e11f763f2897f64e5d6c8493;

    /// @dev keccak256("6529STREAM_FINALITY_COMPONENTS_V1")
    bytes32 internal constant STREAM_FINALITY_COMPONENTS_V1 =
        0xf57efb77611ea13bd3a60968beee86ec330159736aa5d42707a9c0676dbc8898;

    /// @dev keccak256("6529STREAM_CORE_COLLECTION_FACTS_V1")
    bytes32 internal constant STREAM_CORE_COLLECTION_FACTS_V1 =
        0x387b66c3b8fdca5febff2a13faa7057fef7f711c4155493c8c8087e48b28c764;

    /// @dev keccak256("6529STREAM_CORE_COLLECTION_CONFIG_EMPTY_V1"); Core owns the preimage,
    ///      the registry pins it for golden coverage and integration mocks.
    bytes32 internal constant STREAM_CORE_COLLECTION_CONFIG_EMPTY_V1 =
        0x6adebabfe6f92286e8678fc5f206cacb6b1a3b912afc80b6039e9240567e7f26;

    /// @dev keccak256("6529STREAM_FINALITY_RECOVERY_V1"); recovery machinery ships in a later
    ///      slice, the domain is pinned now so preimage discipline never drifts.
    bytes32 internal constant STREAM_FINALITY_RECOVERY_V1 =
        0x521e8df5a00a793a5b47409e1e7711b4b8857ba9e6c833fe59a48dfa865b19ac;

    /// @dev keccak256("6529STREAM_SCOPED_FINALITY_V1")
    bytes32 internal constant STREAM_SCOPED_FINALITY_V1 =
        0x5b56313142e6381659f9d10163ccfa5ea22cb437617c8e69b37c31ecda6f3a50;

    /// @dev keccak256("6529STREAM_SCOPED_CORE_FINALITY_FACTS_V1")
    bytes32 internal constant STREAM_SCOPED_CORE_FINALITY_FACTS_V1 =
        0x5c6390c543248a4d63630061d67c3d2245df223d9ac586deccabf40620b43f6e;

    /// @dev keccak256("6529STREAM_SCOPED_FINALITY_RECOVERY_V1"); pinned ahead of the recovery
    ///      slice, same as STREAM_FINALITY_RECOVERY_V1.
    bytes32 internal constant STREAM_SCOPED_FINALITY_RECOVERY_V1 =
        0x7111cd2afae740dbddcd349ab0b8b9269b6a81c331cef7ca8d542e87308bc54a;

    // ---- Subject derivation domains (home: [CMC-SUBJECT-ID]) ----

    /// @dev keccak256("6529STREAM_SUBJECT_TOKEN_V1")
    bytes32 internal constant STREAM_SUBJECT_TOKEN_V1 =
        0x1e576f27850d12bc1ec9255ca277dbecfbc84fb3a9a34c474640dfca89811d7e;

    /// @dev keccak256("6529STREAM_SUBJECT_SCOPE_V1")
    bytes32 internal constant STREAM_SUBJECT_SCOPE_V1 =
        0x748002ff892f4748f1544a8191da460ca6d167aa2e13eeced354e4f66f636394;

    /// @dev keccak256("6529STREAM_SUBJECT_COLLECTION_V1")
    bytes32 internal constant STREAM_SUBJECT_COLLECTION_V1 =
        0x3a882a22dad9915c9193738f63216234155080ed4c4fc9bfae446e90f1df6e16;

    // ---- Artist sanction domain (home: [AA-DOMAINS] / [AA-SANCTION]) ----

    /// @dev keccak256("6529STREAM_ARTIST_SANCTION_SUBJECT_V1")
    bytes32 internal constant SANCTION_SUBJECT_DOMAIN =
        0x47c9894872096248b3971f1551b555619aea8b63903f526c2da354a7286bb473;

    // ---- Component type vocabulary (home: [LTA-FINALITY] required component types) ----

    /// @dev keccak256("COLLECTION_METADATA")
    bytes32 internal constant COMPONENT_COLLECTION_METADATA =
        0xd90b9e0160ba8e56a77078d6022d52bf0cd862ba5a5adfb6f792287e31399f90;

    /// @dev keccak256("METADATA_ROUTER")
    bytes32 internal constant COMPONENT_METADATA_ROUTER =
        0x7024d3e2544fc48a261933c43d901dca0ee3fc26ea2b857748ab0c295a16f20a;

    /// @dev keccak256("RENDERER")
    bytes32 internal constant COMPONENT_RENDERER =
        0x7df206a0c907b7474a3b59ec39322d07f5cc76c424145fa560ae864e2c8334b1;

    /// @dev keccak256("RENDER_CONTEXT")
    bytes32 internal constant COMPONENT_RENDER_CONTEXT =
        0x9ec0296f9ec64a61db0ff3a5efd1294b47d2978c32c1aecb076f216525c6d1c5;

    /// @dev keccak256("SCRIPT_SOURCE")
    bytes32 internal constant COMPONENT_SCRIPT_SOURCE =
        0x01bcbf3ae47218f940ddca3bf4e7d92baf29ddecea1c38e63350d55b4aa53d73;

    /// @dev keccak256("DEPENDENCY_SOURCE")
    bytes32 internal constant COMPONENT_DEPENDENCY_SOURCE =
        0xa1e40ff39c7b676a717e91c20b2ab7b7f502965d6cc6bd8b37d7ce772f8c8586;

    /// @dev keccak256("MEDIA_MANIFEST")
    bytes32 internal constant COMPONENT_MEDIA_MANIFEST =
        0xa094a8a85bb1f5c4c5c7fa7dad9d83cdba21c78ccef9ae708217cd64dbea7c9a;

    /// @dev keccak256("ENTROPY_COORDINATOR")
    bytes32 internal constant COMPONENT_ENTROPY_COORDINATOR =
        0xb3b3ef20764c647bdeda70b21ab009ff2783106d6995be14389ec6f42ea6dfbb;

    /// @dev keccak256("ARTIST_SANCTION"); pinned in the protocol v1 artist mirror rows.
    bytes32 internal constant COMPONENT_ARTIST_SANCTION =
        0x1e14b418e60392f62e7baf2e6edfcfb6dfeab92fb4428eff216b492ed5cef047;

    /// @dev keccak256("PLATFORM_WORKS_DECLARATION"); pinned in the protocol v1 artist mirror rows.
    bytes32 internal constant COMPONENT_PLATFORM_WORKS_DECLARATION =
        0x9b732a2be945a9747de080e93cd0a83076acad44dca7585847960ffebdb0d29d;

    /// @dev keccak256("REFERENCE_RENDER")
    bytes32 internal constant COMPONENT_REFERENCE_RENDER =
        0xa814b1b6f6e0b07c5330893efc29545d7b6c242616f50f8aaf7942305569a8ca;

    /// @dev keccak256("OPTIONAL_SNAPSHOT_ROUTE")
    bytes32 internal constant COMPONENT_OPTIONAL_SNAPSHOT_ROUTE =
        0x31768727f16bb21bf296353a211441c524fc19d478fe73d886555c8a2150ae40;

    // ---- Facade identity binding (home: [CMC-FACADE-BINDING]; [LTA-FINALITY] req 16) ----

    /// @dev keccak256("IDENTITY_FACADE_BINDING")
    bytes32 internal constant RECORD_IDENTITY_FACADE_BINDING =
        0xb3454197cb151b3305cae7757ccaa671e791eb40902d3aefe6cbaa64d6695087;

    // ---- Identity mode vocabulary (home: [PV1-IDENTITY-MODE]) ----

    /// @dev keccak256("CORE_NATIVE")
    bytes32 internal constant IDENTITY_MODE_CORE_NATIVE =
        0x54ea3b5903aef88b4d2ec4097ea15a9ba68b09b27cc9423d519cb1d7486e61d1;

    /// @dev keccak256("EXTERNAL_FACADE")
    bytes32 internal constant IDENTITY_MODE_EXTERNAL_FACADE =
        0xc7dd233bcf9b505ac7e2ab434d9e6af7bc663d64e2d983f1dd6d77668b578656;

    // ---- Role vocabulary references (home: ADR 0004 [GOV-ROLES]) ----

    /// @dev keccak256("ROLE_COLLECTION_FINALITY_ADMIN")
    bytes32 internal constant ROLE_COLLECTION_FINALITY_ADMIN =
        0x3ba602f38b556566e93e274f3c25565b5efa75d4084fb99bdf6ddc5adb423226;

    /// @dev keccak256("ROLE_TERMINAL_FREEZE_VETO")
    bytes32 internal constant ROLE_TERMINAL_FREEZE_VETO =
        0x7c0cf05bbab982f1ecb8f528f1921326b0f24dfd9baf5beabba3ebbf59a6e61c;

    // ---- Governed gas parameter key (home: [LTA-GGP] mirror rows) ----

    /// @dev keccak256("6529STREAM_GGP_FINALITY_COMPONENT_READ_GAS")
    bytes32 internal constant GGP_FINALITY_COMPONENT_READ_GAS =
        0xbf54fb4ba4a0942771e26fe4b1f829f8324f6f98ef66e080fd6885b75bdf3221;

    // ---- Cross-contract numeric IDs (home: Numeric ID Catalog rows in the umbrella spec) ----

    /// @dev CollectionStatus CLOSED per the ACTIVE/PAUSED/CLOSED vocabulary
    ///      (docs/collection-metadata-contract.md, Open-Ended Collections).
    uint8 internal constant CORE_COLLECTION_STATUS_CLOSED = 2;

    /// @dev tokenLifecycle numeric IDs ([LTA-IDENTITY]: UNKNOWN=0, PREPARED_INCOMPLETE=1,
    ///      MINTED=2, BURNED=3).
    uint8 internal constant TOKEN_LIFECYCLE_MINTED = 2;
    uint8 internal constant TOKEN_LIFECYCLE_BURNED = 3;
}
