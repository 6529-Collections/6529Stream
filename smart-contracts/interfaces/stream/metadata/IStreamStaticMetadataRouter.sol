// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import { IStreamRenderer as R } from "./IStreamRenderer.sol";
import { StreamCollectionManifestTypes as M } from "./StreamCollectionManifestTypes.sol";

/// @notice Explicit STATIC route activations and their original immutable selection records.
/// @dev Activation captures a default revision. Global defaults never rewrite an activated scope.
interface IStreamStaticMetadataRouter {
    struct ConfigInput {
        address registry;
        bytes32 versionKey;
        R.MetadataConfig config;
    }

    struct Selection {
        address registry;
        bytes32 registryCodeHash;
        bytes32 versionKey;
        address renderer;
        bytes32 rendererCodeHash;
        bytes32 rendererId;
        bytes32 rendererVersion;
        bytes32 contextVersion;
        bytes32 schemaHash;
        bytes32 readSetHash;
        bytes32 registrationHash;
    }

    struct Authorization {
        address metadata;
        bytes32 metadataCodeHash;
        address actor;
        uint8 authorityClass;
        uint256 grantCollectionId;
        uint64 grantRevision;
    }

    struct ConfigRecord {
        bytes32 recordHash;
        bytes32 previous;
        uint256 collectionId;
        uint256 tokenId;
        uint64 revision;
        uint64 defaultRevision;
        uint8 level;
        bytes32 sourceSnapshotHash;
        Selection selection;
        R.MetadataConfig config;
    }

    /// @notice Raw canonical Router-owned display inputs. Large selected payloads stay in Metadata.
    struct RawSource {
        uint256 chainId;
        bool configured;
        string name;
        string description;
        string imageURI;
        string animationBaseURI;
        string script;
        M.Selection scriptManifest;
        M.Selection mediaManifest;
    }
    error InvalidStaticMetadataConfig();
    error StaticMetadataNotActivated(uint256 collectionId);
    error StaticMetadataAlreadyActivated(uint256 collectionId);
    error StaticMetadataLocked(uint256 collectionId, uint256 tokenId);
    error StaticMetadataSourceChanged(address target);
    event MetadataDefaultConfigured(
        uint16 schemaVersion,
        bytes32 indexed recordHash,
        uint64 indexed revision,
        ConfigRecord record
    );
    event MetadataStaticActivated(
        uint16 schemaVersion,
        uint256 indexed collectionId,
        bytes32 indexed defaultRecord,
        bytes32 familyStateHash
    );
    event MetadataConfigRecorded(
        uint16 schemaVersion,
        uint256 indexed collectionId,
        uint256 indexed tokenId,
        bytes32 indexed recordHash,
        ConfigRecord record
    );
    function setDefaultMetadataConfig(ConfigInput calldata input) external returns (bytes32);
    function activateStaticMetadata(uint256 collectionId, bytes32 expectedDefaultRecord) external;
    function setCollectionMetadataConfig(uint256 collectionId, ConfigInput calldata input)
        external
        returns (bytes32);
    function setTokenMetadataConfig(uint256 tokenId, ConfigInput calldata input)
        external
        returns (bytes32);
    function defaultMetadataConfig() external view returns (ConfigRecord memory);
    function resolvedMetadataConfig(uint256 tokenId) external view returns (ConfigRecord memory);
    function collectionMetadataConfig(uint256 collectionId)
        external
        view
        returns (ConfigRecord memory);
    function metadataConfigAuthorization(bytes32 recordHash)
        external
        view
        returns (Authorization memory);
    function metadataConfigRecord(bytes32 recordHash) external view returns (ConfigRecord memory);
    function staticMetadataActivation(uint256 collectionId)
        external
        view
        returns (bytes32 defaultRecord, uint64 defaultRevision, bytes32 overridesHead);
    function previewStaticMetadataConfig(
        uint256 collectionId,
        uint256 tokenId,
        ConfigInput calldata input
    ) external view returns (bytes32);
    function previewStaticMetadataActivation(uint256 collectionId, bytes32 expectedDefaultRecord)
        external
        view
        returns (bytes32);
    function staticRenderSourceForConfig(uint256 collectionId, bytes32 recordHash)
        external
        view
        returns (RawSource memory, R.MetadataConfig memory);
    function staticRenderSource(uint256 collectionId) external view returns (RawSource memory);
}
