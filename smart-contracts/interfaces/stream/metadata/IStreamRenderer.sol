// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import { IERC165 } from "../../../vendor/openzeppelin/IERC165.sol";

/// @notice Versioned renderer request and manifest from MRR Renderer Responsibilities.
/// @dev An interface claim is not opcode, source authority, or finality acceptance.
interface IStreamRenderer is IERC165 {
    enum MetadataMode {
        OFFCHAIN,
        ONCHAIN,
        HYBRID
    }
    enum OffchainURIIdMode {
        TOKEN_ID,
        COLLECTION_SERIAL
    }
    enum TokenRenderState {
        PENDING_RANDOMNESS,
        ACTIVE,
        FROZEN,
        BURNED
    }

    struct MetadataConfig {
        MetadataMode mode;
        address renderer;
        string baseURI;
        string pendingURI;
        OffchainURIIdMode offchainURIIdMode;
        bool frozen;
    }

    struct RendererManifest {
        bytes32 rendererId;
        bytes32 rendererVersion;
        bytes32 contextVersion;
        bytes32 rendererClass;
        bytes32 schemaHash;
        string schemaURI;
        string manifestURI;
        bytes32 manifestHash;
        uint32 maxJSONBytes;
        uint32 maxHTMLBytes;
        bool deprecated;
    }

    struct RenderRequest {
        address core;
        uint256 tokenId;
        uint256 collectionId;
        uint256 collectionSerial;
        bytes32 tokenHash;
        TokenRenderState state;
        MetadataMode mode;
        uint8 collectionSupplyMode;
        uint8 collectionStatus;
        bytes32 viewId;
        bytes32 viewManifestHash;
        bytes32 metadataSnapshotHash;
    }
    function rendererVersion() external pure returns (bytes32);
    function renderContextVersion() external pure returns (bytes32);
    function rendererManifest() external view returns (RendererManifest memory);
    function tokenURI(RenderRequest calldata request) external view returns (string memory);
}
