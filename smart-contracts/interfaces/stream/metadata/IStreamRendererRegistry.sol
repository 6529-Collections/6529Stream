// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import { IStreamRenderer as R } from "./IStreamRenderer.sol";

/// @notice Immutable renderer versions, exact read declarations and retained gate evidence.
/// @dev Deprecation closes new mutable assignment only. No ordinary removal or runtime replacement.
interface IStreamRendererRegistry {
    struct Target {
        address target;
        bytes32 codeHash;
        bytes32 role;
    }

    struct Read {
        uint16 targetIndex;
        bytes4 selector;
        uint32 maxReturnBytes;
        bool exact;
    }

    struct Registration {
        address renderer;
        R.RendererManifest manifest;
        bytes32 schemaDocument;
        bytes32 contextDocument;
        bytes32 manifestDocument;
        bytes32 analysisDocument;
        bytes32 goldenDocument;
    }

    /// @dev Registered ABI-encoded CATALOG. The report remains the named publisher's analysis assertion.
    struct Analysis {
        bytes32 profile;
        address renderer;
        bytes32 runtimeHash;
        bytes32 readSetHash;
        bytes32 rendererVersion;
        bytes32 contextVersion;
        bytes32 schemaHash;
        bytes32 toolHash;
        bytes32 findingsHash;
        bool passed;
    }

    struct GoldenVector {
        R.RenderRequest request;
        bytes32 outputHash;
    }

    struct Version {
        bool exists;
        bool deprecated;
        address renderer;
        bytes32 runtimeHash;
        bytes32 registrationHash;
        bytes32 readSetHash;
        bytes32 analysisHash;
        bytes32 goldenHash;
        bytes32 actionId;
    }
    error InvalidRendererRegistration();
    error UnknownRenderer(bytes32 key);
    error RendererAlreadyRegistered(bytes32 key);
    error RendererGovernanceRequired();
    error RendererUnavailable(bytes32 key);
    error InvalidRendererEvidence(bytes32 document);
    event RendererRegistered(
        uint16 schemaVersion,
        bytes32 indexed key,
        address indexed renderer,
        bytes32 indexed actionId,
        bytes32 registrationHash,
        Registration registration,
        Read[] reads
    );
    event RendererDeprecated(uint16 schemaVersion, bytes32 indexed key, bytes32 indexed actionId);
    function registerRenderer(Registration calldata registration, Read[] calldata reads)
        external
        returns (bytes32 key);
    function deprecateRenderer(bytes32 key) external;
    function version(bytes32 key) external view returns (Version memory);
    function registration(bytes32 key) external view returns (Registration memory);
    function reads(bytes32 key) external view returns (Read[] memory);
    function targetCount() external view returns (uint256);
    function targetAt(uint256 index) external view returns (Target memory);
    function versionCount() external view returns (uint256);
    function versionAt(uint256 index) external view returns (bytes32);
    function requireAssignable(bytes32 key)
        external
        view
        returns (address renderer, bytes32 runtimeHash);
    function requireRetained(bytes32 key)
        external
        view
        returns (address renderer, bytes32 runtimeHash);
    function registrationTransition(Registration calldata registration, Read[] calldata reads)
        external
        view
        returns (bytes32 scope, bytes32 previous, bytes32 next);
    function deprecationTransition(bytes32 key)
        external
        view
        returns (bytes32 scope, bytes32 previous, bytes32 next);
}
